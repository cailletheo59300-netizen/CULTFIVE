-- Duels : création entre amis, mêmes questions, ordre imposé, temps serveur, vainqueur, lien ouvert, refus, expiration.
do $$
declare
  a uuid := tst.new_user(); b uuid := tst.new_user(); c uuid := tst.new_user();
  duel jsonb; did uuid; q jsonb; v jsonb; res jsonb; xp_before int;
begin
  perform tst.clock('2026-11-20 10:00:00+01');
  perform public._befriend(a, b);

  perform tst.login(a);
  perform tst.throws(format('select public.duel_create(%L)', c), 'not_friends');
  duel := public.duel_create(b);
  did := (duel ->> 'id')::uuid;
  perform tst.ok(duel ->> 'status' = 'active' and (duel -> 'opponent' ->> 'id')::uuid = b, 'duel créé contre un ami');
  perform tst.ok((select count(distinct domain_id) from public.questions where id in (select unnest(question_ids) from public.duels where id = did)) = 5,
                 'cinq domaines différents');
  perform tst.throws(format('select public.duel_question(%L, 2)', did), 'duel_out_of_order');

  -- A répond juste à tout, en 4 s par question.
  for i in 1 .. 5 loop
    q := public.duel_question(did, i);
    perform tst.tick('4 seconds');
    v := public.duel_answer(did, i, tst.correct_given((q ->> 'id')::uuid), 4000);
    perform tst.ok((v ->> 'is_correct')::bool, 'A juste');
  end loop;
  perform tst.ok((v ->> 'finished')::bool, 'A a fini');
  res := public.duel_result(did);
  perform tst.ok(res ->> 'status' = 'active' and res -> 'opponent' ->> 'score' is not null and (res -> 'opponent' ->> 'answered')::int = 0,
                 'A voit que B n''a pas joué');

  -- C (non joueur) ne voit rien.
  perform tst.login(c);
  perform tst.throws(format('select public.duel_result(%L)', did), 'duel_not_found');

  -- B : ne voit pas le score de A avant d'avoir fini, puis perd (3/5).
  perform tst.login(b);
  res := public.duel_result(did);
  perform tst.ok(res -> 'opponent' ->> 'score' is null, 'score adverse caché avant de jouer');
  select coalesce(sum(amount), 0) into xp_before from public.ledger where user_id = a and currency = 'xp';
  for i in 1 .. 5 loop
    q := public.duel_question(did, i);
    perform tst.tick('3 seconds');
    v := public.duel_answer(did, i, case when i <= 3 then tst.correct_given((q ->> 'id')::uuid) else tst.wrong_given() end, 3000);
  end loop;
  res := public.duel_result(did);
  perform tst.ok(res ->> 'status' = 'finished' and res ->> 'winner' = 'opponent', 'B perd');
  perform tst.ok((res -> 'me' ->> 'score')::int = 3 and (res -> 'opponent' ->> 'score')::int = 5, 'scores');
  perform tst.ok(jsonb_array_length(res -> 'their_answers') = 5, 'réponses adverses visibles à la fin');
  perform tst.ok((select coalesce(sum(amount), 0) from public.ledger where user_id = a and currency = 'xp') = xp_before + 20, 'A gagne 20 XP');
  perform tst.ok((select count(*) from public.ledger where user_id = a and reason = 'duel_win' and currency = 'seeds') = 1, 'A gagne des graines');

  -- Double soumission : verdict identique, pas de double gain.
  v := public.duel_answer(did, 5, tst.wrong_given(), 1000);
  perform tst.ok((v ->> 'duplicate')::bool, 'doublon');

  -- Lien ouvert : C rejoint le défi de A ; B refuse un autre défi.
  perform tst.login(a);
  duel := public.duel_create(null);
  perform tst.ok(duel ->> 'status' = 'open' and duel -> 'opponent' = 'null'::jsonb, 'défi par lien');
  perform tst.login(c);
  duel := public.duel_join(duel ->> 'code');
  perform tst.ok(duel ->> 'status' = 'active' and not (duel ->> 'i_am_challenger')::bool, 'C a rejoint');
  perform tst.login(b);
  perform tst.throws(format('select public.duel_join(%L)', duel ->> 'code'), 'duel_taken');

  perform tst.login(a);
  duel := public.duel_create(b);
  perform tst.login(b);
  perform public.duel_decline((duel ->> 'id')::uuid);
  perform tst.ok((select status from public.duels where id = (duel ->> 'id')::uuid) = 'declined', 'refus');

  -- Expiration : A joue seul, 48 h passent → A gagne.
  perform tst.login(a);
  duel := public.duel_create(b);
  did := (duel ->> 'id')::uuid;
  for i in 1 .. 5 loop
    q := public.duel_question(did, i);
    v := public.duel_answer(did, i, tst.wrong_given(), 2000);
  end loop;
  perform tst.tick('49 hours');
  perform tst.login(b);
  perform tst.ok((public.duel_question(did, 1) ->> 'expired')::bool, 'duel expiré');
  res := public.duel_result(did);
  perform tst.ok(res ->> 'status' = 'finished' and res ->> 'winner' = 'opponent', 'celui qui a joué gagne à l''expiration');
  perform tst.ok(jsonb_array_length(public.duels_mine()) >= 2, 'liste des duels');
end $$;
