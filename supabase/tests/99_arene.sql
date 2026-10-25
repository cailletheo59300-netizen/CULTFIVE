-- Arène (0088) : file commune, duel côte à côte, chrono, points de la semaine, récompenses, fin de semaine.

-- Joue un duel classé entier pour un joueur : `p_correct` bonnes réponses d'abord, puis des erreurs.
create or replace function tst.arena_play(p_user uuid, p_correct int) returns jsonb language plpgsql as $$
declare r jsonb; v_duel uuid; q jsonb; i int;
begin
  perform tst.login(p_user);
  r := public.arena_find();
  v_duel := (r -> 'duel' ->> 'id')::uuid;
  for i in 1 .. 7 loop
    q := public.arena_question(v_duel, i);
    perform public.arena_answer(v_duel, i, case when i <= p_correct then tst.correct_given((q ->> 'id')::uuid)
                                                else tst.wrong_given() end, 4000);
    perform tst.tick('5 seconds');
  end loop;
  return r;
end $$;

do $$
declare
  a uuid := tst.new_user(); b uuid := tst.new_user(); c uuid := tst.new_user();
  r jsonb; rb jsonb; v_duel uuid; q jsonb; ans jsonb; res jsonb;
begin
  perform tst.clock('2027-05-10 10:00:00+02');
  update public.profiles set onboarded_at = public._now() where id in (a, b, c);

  -- A ouvre un duel : personne n'attend encore.
  r := tst.arena_play(a, 5);
  perform tst.ok(not (r ->> 'matched')::bool and (r -> 'duel' -> 'opponent') = 'null'::jsonb, 'premier duel : ouvert à l''Arène');
  v_duel := (r -> 'duel' ->> 'id')::uuid;
  perform tst.ok(cardinality((select question_ids from public.duels where id = v_duel)) = 7, '7 questions');
  perform tst.ok((select bool_and(q.type in ('mcq', 'true_false', 'numeric')) from public.duels d, unnest(d.question_ids) x
                  join public.questions q on q.id = x where d.id = v_duel), 'questions à réponse rapide');

  -- B tombe sur le duel de A (le plus ancien ouvert), voit son temps puis sa réponse après la sienne.
  perform tst.login(b);
  rb := public.arena_find();
  perform tst.ok((rb ->> 'matched')::bool and (rb -> 'duel' ->> 'id')::uuid = v_duel
                 and (rb -> 'duel' -> 'opponent' ->> 'id')::uuid = a, 'B affronte le duel de A');
  q := public.arena_question(v_duel, 1);
  perform tst.ok((q ->> 'them_ms') is not null and (q ->> 'seconds')::int = 15, 'temps de l''adversaire, sans sa réponse');
  perform tst.ok(not (q ? 'answer'), 'pas de réponse dans la question');
  ans := public.arena_answer(v_duel, 1, tst.correct_given((q ->> 'id')::uuid), 3000);
  perform tst.ok((ans ->> 'is_correct')::bool and (ans -> 'them' ->> 'is_correct')::bool, 'côte à côte : sa réponse après la mienne');
  -- Trop tard (15 s + 3 s) : faux, même avec la bonne réponse.
  q := public.arena_question(v_duel, 2);
  perform tst.tick('19 seconds');
  ans := public.arena_answer(v_duel, 2, tst.correct_given((q ->> 'id')::uuid), 3000);
  perform tst.ok(not (ans ->> 'is_correct')::bool and (ans ->> 'late')::bool, 'chrono dépassé : faux');
  for i in 3 .. 7 loop
    q := public.arena_question(v_duel, i);
    perform public.arena_answer(v_duel, i, tst.wrong_given(), 3000);
  end loop;
  res := public.arena_result(v_duel);
  perform tst.ok(res ->> 'status' = 'finished' and res ->> 'winner' = 'opponent', 'A gagne 5 à 1');
  perform tst.ok((res -> 'result' ->> 'points')::int = 0 and res -> 'result' ->> 'outcome' = 'loss', 'défaite : 0 point, rien de perdu');
  perform tst.ok((select points from public.arena_results where duel_id = v_duel and user_id = a) = 3, 'victoire : +3');
  perform tst.ok((select 'daily_chest' = any (bonus) from public.arena_results where duel_id = v_duel and user_id = a),
                 'coffre du 1er duel gagné du jour');
  perform tst.ok(exists (select 1 from public.push_outbox where user_id = a and dedupe_key like 'arena_end:%') or
                 not exists (select 1 from public.push_tokens where user_id = a), 'A prévenu (s''il a les notifications)');

  -- Les fonctions des duels entre amis refusent les duels classés.
  perform tst.throws(format('select public.duel_join(%L)', (select code from public.duels where id = v_duel)), 'duel_not_found');
  perform tst.throws(format('select public.duel_question(%L, 1)', v_duel), 'duel_not_found');

  -- C : plus aucun duel ouvert, il ouvre le sien ; A, qui relance, tombe sur celui de C.
  r := tst.arena_play(c, 3);
  perform tst.ok(not (r ->> 'matched')::bool, 'C ouvre un nouveau duel');
  perform tst.login(a);
  r := public.arena_find();
  perform tst.ok((r ->> 'matched')::bool and (r -> 'duel' -> 'opponent' ->> 'id')::uuid = c, 'A tombe sur C');

  -- Abandon : un duel ouvert à moitié joué est pris au bout de 15 min, ses questions manquantes comptent fausses.
  perform tst.login(b);
  r := public.arena_find();
  v_duel := (r -> 'duel' ->> 'id')::uuid;
  q := public.arena_question(v_duel, 1);
  perform public.arena_answer(v_duel, 1, tst.correct_given((q ->> 'id')::uuid), 3000);
  perform tst.tick('16 minutes');
  perform tst.login(c);
  r := public.arena_find();
  perform tst.ok((r ->> 'matched')::bool and (r -> 'duel' ->> 'id')::uuid = v_duel, 'duel abandonné repris par un autre');
  perform tst.ok((select count(*) from public.duel_answers where duel_id = v_duel and user_id = b and answered_at is not null) = 7,
                 'questions manquantes de B comptées fausses');

  -- Vue d'ensemble et classements.
  perform tst.login(a);
  r := public.arena_overview();
  perform tst.ok((r -> 'me' ->> 'points')::int >= 3 and (r -> 'me' ->> 'min_duels')::int = 5
                 and jsonb_array_length(r -> 'prizes') = 7 and jsonb_array_length(r -> 'duels') >= 1, 'vue d''ensemble');
  perform tst.ok(jsonb_array_length(public.arena_leaderboard('week') -> 'rows') >= 2
                 and public.arena_leaderboard('friends') -> 'me' is not null
                 and public.arena_leaderboard('all') -> 'me' is not null, 'classements semaine, amis, depuis toujours');
end $$;

-- Fin de semaine : classés (5 duels) devant, récompenses par place, coffre en bois pour les autres, versées une fois.
do $$
declare
  w uuid := tst.new_user(); l uuid := tst.new_user(); casual uuid := tst.new_user();
  r jsonb; v_week date;
begin
  perform tst.clock('2027-06-07 09:00:00+02');
  update public.profiles set onboarded_at = public._now() where id in (w, l, casual);
  -- Vider la file des tests précédents.
  update public.duels set status = 'expired' where arena and status = 'open';
  for i in 1 .. 5 loop
    perform tst.arena_play(w, 7);
    perform tst.arena_play(l, 2);
    perform tst.tick('2 minutes');
  end loop;
  perform tst.arena_play(w, 7);
  perform tst.arena_play(casual, 7);
  v_week := public._arena_week(public._now());
  perform tst.ok((select max(streak) from public.arena_results where user_id = w) = 5, 'série de 5 victoires');
  perform tst.ok((select count(*) from public.user_chests where user_id = w and source = 'arena_streak') = 1, 'coffre de la série de 5');
  perform tst.tick('7 days');
  perform tst.login(l);
  r := public.arena_overview();
  perform tst.ok((select rank from public.arena_week_rewards where week = v_week and user_id = w) = 1, 'W 1er');
  perform tst.ok((select count(*) from public.user_chests where user_id = w and source = 'arena_week' and tier = 'gold') = 3,
                 '1er : 3 coffres en or');
  perform tst.ok(exists (select 1 from public.user_achievements where user_id = w and achievement_id = 'arena_champion')
                 and exists (select 1 from public.user_cosmetics where user_id = w and item_id = 'cadre.champion'),
                 '1er : trophée et cadre Champion');
  perform tst.ok((select eligible from public.arena_week_rewards where week = v_week and user_id = casual) = false
                 and exists (select 1 from public.user_chests where user_id = casual and source = 'arena_week' and tier = 'wood'),
                 'moins de 5 duels : coffre en bois');
  perform tst.ok((r -> 'reward' ->> 'rank')::int = (select rank from public.arena_week_rewards where week = v_week and user_id = l),
                 'récompense affichée à l''ouverture');
  perform public.arena_reward_seen(v_week);
  perform tst.ok(public.arena_overview() -> 'reward' = 'null'::jsonb, 'vue une fois');
  perform tst.ok(public._arena_close_week(v_week) = 0, 'versée une seule fois');
  perform tst.ok((public.arena_overview() -> 'champion' ->> 'id')::uuid = w, 'couronne du champion');
end $$;

-- Missions d'Arène : seulement pour une app qui envoie l'en-tête « x-brainlix-arena » (1.5 et après).
do $$
declare u uuid := tst.new_user(); v_start date;
begin
  perform tst.clock('2027-07-05 10:00:00+02');
  perform set_config('request.headers', '{}', false);
  perform tst.ok(not public._client_arena(), 'ancienne app : pas d''Arène');
  for i in 1 .. 40 loop
    v_start := date '2027-07-05' + i * 7;
    perform public._quests_ensure(u, 'week', v_start);
  end loop;
  perform tst.ok(not exists (select 1 from public.user_quests where user_id = u and metric like 'arena%'), 'ancienne app : aucune mission d''Arène');
  perform set_config('request.headers', '{"x-brainlix-arena": "1"}', false);
  perform tst.ok(public._client_arena(), 'app 1.5 : Arène');
  for i in 41 .. 80 loop
    v_start := date '2027-07-05' + i * 7;
    perform public._quests_ensure(u, 'week', v_start);
  end loop;
  perform tst.ok(exists (select 1 from public.user_quests where user_id = u and metric = 'arena_wins'), 'app 1.5 : missions d''Arène');
  perform set_config('request.headers', '', false);
end $$;
