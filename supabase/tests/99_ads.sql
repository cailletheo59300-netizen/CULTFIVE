-- Pubs récompensées : vue vérifiée par Google, limites, récompenses.
do $$
declare
  u uuid := tst.new_user();
  pack jsonb; atts jsonb := '[]'::jsonb; x jsonb; sid uuid;
  r jsonb; seeds0 int; st jsonb; chest uuid;
begin
  perform tst.clock('2027-12-05 10:00:00+01');
  perform tst.login(u);
  update public.profiles set created_at = public._now() where id = u;

  -- Vues ignorées : joueur ou type inconnus.
  perform tst.ok(not (public.ad_ssv_record('tx-x', gen_random_uuid()::text, 'unit', 'free_chest:') ->> 'recorded')::bool, 'joueur inconnu ignoré');
  perform tst.ok(not (public.ad_ssv_record('tx-y', u::text, 'unit', 'jackpot:') ->> 'recorded')::bool, 'type inconnu ignoré');

  -- Partie classée gagnante, puis graines doublées.
  pack := public.play_pack('training', 'history', null, 8, true, null);
  sid := (pack ->> 'session_id')::uuid;
  for x in select * from jsonb_array_elements(pack -> 'questions') loop
    atts := atts || jsonb_build_object('client_attempt_id', gen_random_uuid(), 'question_id', x ->> 'id',
                                       'given', tst.correct_given((x ->> 'id')::uuid), 'response_ms', 3000);
  end loop;
  perform public.play_submit(sid, atts);
  seeds0 := (select seeds from public.profiles where id = u);
  perform public.ad_can('double_seeds', 'play:' || sid);
  perform tst.throws(format('select public.ad_claim(''double_seeds'', %L)', 'play:' || sid), 'ad_pending');
  perform public.ad_ssv_record('tx-1', u::text, 'unit', 'double_seeds:play:' || sid);
  perform public.ad_ssv_record('tx-1', u::text, 'unit', 'double_seeds:play:' || sid);  -- Google peut renvoyer
  r := public.ad_claim('double_seeds', 'play:' || sid);
  perform tst.ok((r ->> 'seeds')::int > 0 and (select seeds from public.profiles where id = u) = seeds0 + (r ->> 'seeds')::int,
                 'graines doublées (+' || (r ->> 'seeds') || ')');
  perform tst.throws(format('select public.ad_can(''double_seeds'', %L)', 'play:' || sid), 'ad_already_used');

  -- Coffre offert : 1 par jour, en bois.
  perform public.ad_ssv_record('tx-2', u::text, 'unit', 'free_chest:');
  r := public.ad_claim('free_chest');
  chest := (r ->> 'chest_id')::uuid;
  perform tst.ok((select tier::text from public.user_chests where id = chest) = 'wood', 'coffre en bois offert');
  perform tst.throws('select public.ad_can(''free_chest'')', 'ad_limit');

  -- Coffre boosté : graines +50 % au moins 15 pour un bois.
  perform public.ad_ssv_record('tx-3', u::text, 'unit', 'boost_chest:' || chest);
  perform public.ad_claim('boost_chest', chest::text);
  r := public.chest_open(chest);
  perform tst.ok((r ->> 'boosted')::bool and (r ->> 'seeds')::int >= 15, 'coffre boosté (' || (r ->> 'seeds') || ' graines)');
  perform tst.throws(format('select public.ad_can(''boost_chest'', %L)', chest), 'chest_opened');

  -- Limite quotidienne des graines doublées (3), statut.
  st := public.ad_status();
  perform tst.ok((st ->> 'double_seeds')::int = 2 and (st ->> 'free_chest')::int = 0 and (st ->> 'boost_chest')::int = 1, 'statut : restes du jour');
  perform tst.ok(not (st ->> 'interstitial')::bool, 'pas de pub entre les parties les 3 premiers jours');
  perform tst.tick('3 days');
  perform tst.ok((public.ad_status() ->> 'interstitial')::bool, 'pub entre les parties après 3 jours');
  perform tst.ok((public.ad_status() ->> 'free_chest')::int = 1, 'nouveau jour : coffre offert de nouveau');

  -- Mode test : réservé aux admins.
  perform tst.throws('select public.ad_claim(''free_chest'', null, true)', 'ad_pending');
  insert into public.app_admins (user_id) values (u);
  r := public.ad_claim('free_chest', null, true);
  perform tst.ok(r ->> 'chest_id' is not null, 'admin : récompense de test sans vue vérifiée');
  perform tst.ok((select test from public.ad_views where reward ->> 'chest_id' = r ->> 'chest_id'), 'vue de test marquée');
end $$;

-- Série sauvée : dans les 48 h, une fois par mois.
do $$
declare
  u uuid := tst.new_user();
  r jsonb;
begin
  perform tst.clock('2027-12-10 10:00:00+01');
  perform tst.login(u);
  update public.profiles set streak_current = 12, streak_best = 12, streak_last_date = '2027-12-07', streak_freezes = 0 where id = u;
  perform tst.ok((public.ad_status() ->> 'streak_rescue')::int = 12, 'série de 12 à sauver (2 jours manqués)');
  perform public.ad_ssv_record('tx-s1', u::text, 'unit', 'streak_rescue:');
  r := public.ad_claim('streak_rescue');
  perform tst.ok(public._streak_effective(u) = 12, 'série sauvée');
  perform tst.ok(public.ad_status() -> 'streak_rescue' = 'null'::jsonb, 'plus rien à sauver');
  -- Nouvelle perte le même mois : pas de seconde sauvegarde.
  update public.profiles set streak_last_date = '2027-12-08' where id = u;
  perform tst.tick('2 days');
  perform tst.throws('select public.ad_can(''streak_rescue'')', 'ad_limit');
  -- Trop tard (3 jours manqués) le mois suivant.
  perform tst.clock('2028-01-10 10:00:00+01');
  update public.profiles set streak_last_date = '2028-01-06' where id = u;
  perform tst.throws('select public.ad_can(''streak_rescue'')', 'streak_not_rescuable');
end $$;

-- Sécurité : l'enregistrement des vues est réservé à la clé de service.
do $$
begin
  perform tst.ok(not has_function_privilege('authenticated', 'public.ad_ssv_record(text, text, text, text)', 'execute'), 'joueur : pas d''enregistrement de vue');
  perform tst.ok(not has_function_privilege('anon', 'public.ad_claim(text, text, bool)', 'execute'), 'anonyme : pas de récompense');
end $$;
