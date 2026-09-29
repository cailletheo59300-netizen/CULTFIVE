-- Objectifs du jour / de la semaine, récap des semaines, historique du 5 du jour.
do $$
declare
  u uuid := tst.new_user();
  o jsonb; o2 jsonb; pack jsonb; atts jsonb; x jsonb; seeds0 int; seeds1 int; r jsonb;
begin
  perform tst.clock('2027-05-05 10:00:00+02');   -- un mercredi
  perform tst.login(u);

  o := public.quests_overview();
  perform tst.ok(jsonb_array_length(o -> 'day' -> 'quests') = 3 and jsonb_array_length(o -> 'week' -> 'quests') = 3, '3 + 3 objectifs');
  perform tst.ok(o -> 'day' -> 'quests' -> 0 ->> 'label' = 'Fais le 5 du jour', 'le 5 du jour toujours proposé');
  perform tst.ok(o -> 'week' ->> 'period_start' = '2027-05-03', 'semaine du lundi');
  perform tst.ok((o -> 'day' ->> 'ends_at')::timestamptz = '2027-05-06 00:00:00+02', 'fin de journée dans le fuseau du joueur');
  -- Tirage stable.
  perform tst.ok(public.quests_overview() -> 'day' -> 'quests' = o -> 'day' -> 'quests', 'mêmes objectifs à chaque lecture');

  -- On impose des objectifs connus pour tester progression et récompenses.
  update public.user_quests set metric = 'answers', target = 5, label = 'Réponds à 5 questions' where user_id = u and period = 'day' and slot = 2;
  update public.user_quests set metric = 'ranked_games', target = 1, label = 'Joue 1 partie classée' where user_id = u and period = 'day' and slot = 3;
  select seeds into seeds0 from public.profiles where id = u;

  pack := public.play_pack('training', 'history', null, 10, true, null);
  atts := '[]'::jsonb;
  for x in select * from jsonb_array_elements(pack -> 'questions') loop
    atts := atts || jsonb_build_object('client_attempt_id', gen_random_uuid(), 'question_id', x ->> 'id',
                                       'given', tst.wrong_given(), 'response_ms', 3000);
  end loop;
  perform public.play_submit((pack ->> 'session_id')::uuid, atts);

  o := public.quests_overview();
  perform tst.ok((o -> 'day' -> 'quests' -> 1 ->> 'done')::bool and (o -> 'day' -> 'quests' -> 1 ->> 'progress')::int = 5, 'réponses comptées (plafonnées à l''objectif)');
  perform tst.ok((o -> 'day' -> 'quests' -> 2 ->> 'done')::bool, 'partie classée comptée');
  perform tst.ok(jsonb_array_length(o -> 'newly') = 2, 'deux objectifs annoncés');
  select seeds into seeds1 from public.profiles where id = u;
  perform tst.ok(seeds1 - seeds0 = 4, 'graines : 2 par objectif');
  -- Relecture : rien de plus.
  o2 := public.quests_overview();
  perform tst.ok(jsonb_array_length(o2 -> 'newly') = 0 and (select seeds from public.profiles where id = u) = seeds1, 'pas de double récompense');
  perform tst.ok(not (o2 -> 'day' -> 'bonus' ->> 'done')::bool, 'bonus pas encore');

  -- Bonus des trois objectifs : on remplace le 5 du jour par un objectif déjà atteint.
  update public.user_quests set metric = 'answers', target = 1, label = 'Réponds à 1 question' where user_id = u and period = 'day' and slot = 1;
  o := public.quests_overview();
  perform tst.ok((o -> 'day' -> 'bonus' ->> 'done')::bool, 'bonus du jour');
  perform tst.ok(exists (select 1 from jsonb_array_elements(o -> 'newly') n where (n ->> 'bonus')::bool), 'bonus annoncé');
  perform tst.ok((select seeds from public.profiles where id = u) = seeds1 + 2, 'bonus : pas de graines directes');
  perform tst.ok((select count(*) from public.user_chests where user_id = u and source = 'quests_day' and tier = 'wood') = 1, 'bonus : un coffre en bois');
  -- Plafond de la journée : 9 graines au plus.
  perform tst.ok((select sum(amount) from public.ledger where user_id = u and reason = 'quest' and currency = 'seeds') <= 9, 'au plus 9 graines par jour');

  -- Le lendemain : nouveaux objectifs, ceux d'hier restent acquis.
  perform tst.tick('1 day');
  o := public.quests_overview();
  perform tst.ok(o -> 'day' ->> 'period_start' = '2027-05-06' and not (o -> 'day' -> 'quests' -> 0 ->> 'done')::bool, 'nouveau jour');
  perform tst.ok(o -> 'week' ->> 'period_start' = '2027-05-03', 'même semaine');

  -- Progression de cote : mesurée sur la période.
  perform tst.ok(public._quest_progress(u, 'cote_gain', null, '2027-05-03', '2027-05-10') >= 0, 'cote_gain calculé');
  perform tst.ok(public._quest_progress(u, 'domains_played', null, '2027-05-03', '2027-05-10') = 1, 'un domaine joué');

  -- Récap des semaines.
  r := public.weekly_recap(4);
  perform tst.ok(jsonb_array_length(r) >= 1 and r -> 0 ->> 'week_start' = '2027-05-03', 'récap : semaine en cours');
  perform tst.ok((r -> 0 ->> 'answers')::int = 10 and (r -> 0 ->> 'games')::int = 1, 'récap : réponses et parties');
  perform tst.ok((r -> 0 ->> 'quests_done')::int >= 3, 'récap : objectifs remplis');
  perform tst.ok(jsonb_array_length(r -> 0 -> 'cote_moves') = 1 and (r -> 0 -> 'cote_moves' -> 0 ->> 'delta')::int < 0, 'récap : cote en baisse après 10 erreurs');

  -- Sécurité : pas d'accès direct aux fonctions internes.
  perform tst.ok(not has_function_privilege('authenticated', 'public._quests_ensure(uuid, text, date)', 'execute'), 'fonctions internes protégées');
end $$;
