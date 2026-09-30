-- Duels personnalisés, revanche, hors Elo, profil d'un ami et face-à-face.
do $$
declare
  a uuid := tst.new_user(); b uuid := tst.new_user(); c uuid := tst.new_user();
  duel jsonb; did uuid; q jsonb; v jsonb; res jsonb; prof jsonb; mu_before real; n int;
begin
  perform tst.clock('2027-12-20 10:00:00+01');
  perform public._befriend(a, b);
  perform tst.login(a);

  -- Réglages : 10 questions d'histoire, difficiles.
  duel := public.duel_create(b, 10, array['history'], 'hard');
  did := (duel ->> 'id')::uuid;
  perform tst.ok((duel ->> 'total')::int = 10 and duel ->> 'difficulty' = 'hard', 'duel de 10 questions, difficile');
  perform tst.ok((select bool_and(q.domain_id = 'history') from public.questions q
                  where q.id in (select unnest(question_ids) from public.duels where id = did)), 'que de l''histoire');
  perform tst.ok((select count(*) from public.questions q where q.id in (select unnest(question_ids) from public.duels where id = did)
                    and q.difficulty_effective >= 55) >= 8, 'surtout des questions difficiles');
  perform tst.throws(format('select public.duel_create(%L, 7)', b), 'invalid_count');
  perform tst.throws(format('select public.duel_create(%L, 5, null, %L)', b, 'extreme'), 'invalid_difficulty');

  -- Tous les domaines cochés = tous les domaines.
  duel := public.duel_create(b, 20, (select array_agg(id) from public.domains where is_active), 'auto');
  perform tst.ok(duel -> 'domains' = 'null'::jsonb and (duel ->> 'total')::int = 20, '20 questions, tous les domaines');

  -- A joue le duel de 10 : l'Elo ne bouge pas.
  select mu into mu_before from public.user_skills where user_id = a and scope_id = 'history';
  for i in 1 .. 10 loop
    q := public.duel_question(did, i);
    perform tst.ok((q ->> 'total')::int = 10, 'total annoncé');
    v := public.duel_answer(did, i, tst.correct_given((q ->> 'id')::uuid), 3000);
  end loop;
  perform tst.ok((v ->> 'finished')::bool, 'fini à la 10e');
  perform tst.ok((select mu from public.user_skills where user_id = a and scope_id = 'history') is not distinct from mu_before,
                 'un duel ne change pas l''Elo');
  perform tst.throws(format('select public.duel_question(%L, 11)', did), 'duel_out_of_order');

  -- B perd 6/10.
  perform tst.login(b);
  for i in 1 .. 10 loop
    q := public.duel_question(did, i);
    v := public.duel_answer(did, i, case when i <= 6 then tst.correct_given((q ->> 'id')::uuid) else tst.wrong_given() end, 3000);
  end loop;
  res := public.duel_result(did);
  perform tst.ok(res ->> 'winner' = 'opponent' and (res -> 'opponent' ->> 'score')::int = 10, 'B perd 6–10');

  -- Revanche : mêmes réglages.
  duel := public.duel_rematch(did);
  perform tst.ok((duel ->> 'total')::int = 10 and duel ->> 'difficulty' = 'hard' and (duel -> 'opponent' ->> 'id')::uuid = a,
                 'revanche avec les mêmes réglages');

  -- Profil de A vu par B : face-à-face.
  prof := public.friend_profile(a);
  perform tst.ok((prof -> 'head_to_head' ->> 'played')::int = 1 and (prof -> 'head_to_head' ->> 'losses')::int = 1
                 and (prof -> 'head_to_head' ->> 'wins')::int = 0, 'bilan : 1 défaite');
  perform tst.ok((prof -> 'head_to_head' ->> 'my_rate')::int = 60 and (prof -> 'head_to_head' ->> 'their_rate')::int = 100, 'taux 60 % / 100 %');
  perform tst.ok(prof -> 'head_to_head' -> 'streak' ->> 'who' = 'friend', 'série de l''ami');
  perform tst.ok(jsonb_array_length(prof -> 'duels') = 3, 'derniers duels (dont revanche et duel de 20 en cours)');
  perform tst.ok(prof ? 'cote', 'Elo de l''ami');

  -- Réservé aux amis.
  perform tst.login(c);
  perform tst.throws(format('select public.friend_profile(%L)', a), 'not_friends');
  perform tst.throws(format('select public.duel_rematch(%L)', did), 'duel_not_found');
end $$;
