-- Espace admin : journal d'événements, statistiques, fiche joueur, renommage, bannissement.
do $$
declare
  adm uuid := tst.new_user();
  u uuid := tst.new_user();
  w uuid := tst.new_user();
  r jsonb; k jsonb; k2 jsonb; ghost uuid; pack jsonb; atts jsonb := '[]'::jsonb; x jsonb;
begin
  perform tst.clock('2027-11-02 10:00:00+01');
  insert into public.app_admins (user_id) values (adm);

  -- Journal : noms inconnus ignorés, sans bloquer les autres.
  perform tst.login(u);
  r := public.track_events('[{"name":"app_open","app_version":"1.4.0"},{"name":"hack","props":{}},{"name":"share","props":{"what":"daily"}}]');
  perform tst.ok((r ->> 'recorded')::int = 2, 'deux événements valides enregistrés');
  perform tst.login(w);
  perform public.track_events('[{"name":"app_open"},{"name":"interstitial"},{"name":"interstitial"},{"name":"ad_fail","props":{"kind":"interstitial","reason":"no fill"}},{"name":"ad_offer","props":{"kind":"free_pack"}}]');
  perform tst.login(u);
  pack := public.play_pack('training', 'history', null, 5, true, null);
  for x in select * from jsonb_array_elements(pack -> 'questions') loop
    atts := atts || jsonb_build_object('client_attempt_id', gen_random_uuid(), 'question_id', x ->> 'id',
                                       'given', tst.correct_given((x ->> 'id')::uuid), 'response_ms', 3000);
  end loop;
  perform public.play_submit((pack ->> 'session_id')::uuid, atts);

  -- Un joueur ordinaire n'a pas accès aux outils d'admin.
  perform tst.throws('select public.admin_kpis(30)', 'forbidden');
  perform tst.throws('select public.admin_ads_daily(30)', 'forbidden');
  perform tst.throws(format('select public.admin_user_ads(%L)', u), 'forbidden');
  perform tst.throws(format('select public.admin_user_ban(%L)', adm), 'forbidden');

  perform tst.login(adm);
  k := public.admin_kpis(30);
  perform tst.ok((k -> 'totals' ->> 'players')::int >= 2, 'joueurs comptés');
  perform tst.ok((k -> 'totals' ->> 'dau')::int >= 1, 'actifs du jour');
  perform tst.ok(jsonb_array_length(k -> 'series') = 30, '30 jours de série');
  perform tst.ok((k -> 'series' -> 29 ->> 'answers')::int >= 5, 'réponses du jour');
  perform tst.ok(k -> 'versions' ? '1.4.0', 'versions de l''app');
  perform tst.ok((k -> 'events' ->> 'share')::int >= 1, 'événements de la semaine');

  -- Invité fantôme (app lancée, onboarding jamais fini) : compté seulement comme invité, jamais comme joueur ni actif.
  ghost := tst.new_user(true);
  perform tst.login(ghost);
  perform public.track_events('[{"name":"app_open","app_version":"9.9.9 (1)"}]');
  perform tst.login(adm);
  delete from public.admin_cache;  -- chiffres gardés 10 min (0095) : on force le recalcul
  k2 := public.admin_kpis(30);
  perform tst.ok((k2 -> 'totals' ->> 'players') = (k -> 'totals' ->> 'players')
                 and (k2 -> 'totals' ->> 'guests')::int = (k -> 'totals' ->> 'guests')::int + 1, 'fantôme : invité, pas joueur');
  perform tst.ok((k2 -> 'totals' ->> 'dau') = (k -> 'totals' ->> 'dau') and not (k2 -> 'versions' ? '9.9.9 (1)'), 'fantôme : ni actif ni version');
  perform tst.ok((k2 -> 'funnel' ->> 'created')::int = (k -> 'funnel' ->> 'created')::int + 1, 'fantôme : compté dans les installations');
  perform tst.ok((public.admin_dashboard() ->> 'users')::int = (k -> 'totals' ->> 'players')::int, 'même nombre de joueurs partout');
  perform tst.ok((public.admin_ads(30) ? 'rewarded_7d'), 'pubs : total de la semaine');
  r := public.admin_ads_daily(30);
  perform tst.ok(jsonb_array_length(r -> 'days') = 30 and (r -> 'days' -> 0 ->> 'day')::date = date '2027-11-02',
                 'pubs jour par jour : 30 jours, aujourd''hui en premier');
  perform tst.ok((r -> 'days' -> 0 ->> 'active')::int >= 1, 'pubs jour par jour : actifs du jour');
  perform tst.ok((r -> 'days' -> 0 ->> 'interstitial')::int >= 1 and (r -> 'days' -> 0 ->> 'interstitial_failed')::int >= 1
                 and (r -> 'days' -> 0 ->> 'viewers')::int >= 1, 'pubs jour par jour : entre les parties vue et ratée');
  r := public.admin_users(null, 'ads_interstitial', 200, 0, 'all');
  perform tst.ok(r -> 'items' -> 0 ? 'ads_rewarded' and (r -> 'items' -> 0 ->> 'ads_interstitial')::int >= 1, 'joueurs triés par pubs entre les parties');
  r := public.admin_user_ads(w);
  perform tst.ok((r -> 'total' ->> 'interstitial')::int = 1 and (r -> 'total' ->> 'interstitial_failed')::int = 1
                 and (r -> 'week' ->> 'offered')::int = 1 and (r -> 'today' ->> 'interstitial')::int = 1 and (r -> 'by_kind' -> 'free_pack' ->> 'offered')::int = 1
                 and (r -> 'fail_reasons' ->> 'Entre les parties : no fill')::int = 1, 'pubs d''un joueur (doublon d''envoi compté une fois)');
  r := public.admin_ads_daily(30);
  perform tst.ok((r -> 'days' -> 0 -> 'by_kind' -> 'free_pack' ->> 'offered')::int >= 1
                 and (r -> 'days' -> 0 -> 'fail_reasons' ->> 'Entre les parties : no fill')::int >= 1, 'pubs jour par jour : détail');

  r := public.admin_users((select handle from public.profiles where id = u), 'recent', 10, 0);
  perform tst.ok((r ->> 'total')::int = 1 and (r -> 'items' -> 0 ->> 'id')::uuid = u, 'recherche par pseudo');
  perform tst.ok(r -> 'items' -> 0 ->> 'app_version' = '1.4.0', 'version de l''app du joueur');
  r := public.admin_users(null, 'recent', 200, 0, 'all', '1.4.0');
  perform tst.ok(exists (select 1 from jsonb_array_elements(r -> 'items') i where (i ->> 'id')::uuid = u)
                 and not exists (select 1 from jsonb_array_elements(r -> 'items') i where (i ->> 'id')::uuid = w)
                 and r -> 'versions' @> '[{"version": "1.4.0"}]', 'filtre par version');
  r := public.admin_users(null, 'recent', 200, 0, 'all', 'none');
  perform tst.ok(exists (select 1 from jsonb_array_elements(r -> 'items') i where (i ->> 'id')::uuid = w)
                 and not exists (select 1 from jsonb_array_elements(r -> 'items') i where (i ->> 'id')::uuid = u), 'filtre : version inconnue');
  r := public.admin_user(u);
  perform tst.ok(jsonb_array_length(r -> 'games') = 1 and jsonb_array_length(r -> 'events') = 2, 'fiche joueur');

  -- Renommage.
  perform public.admin_user_rename(u, 'Pseudo_Propre');
  perform tst.ok((select handle from public.profiles where id = u) = 'Pseudo_Propre', 'pseudo renommé');
  perform tst.throws(format('select public.admin_user_rename(%L, %L)', u, 'a b'), 'invalid_handle');

  -- Bannissement : le joueur ne peut plus rien faire, puis retrouve l'accès.
  perform public.admin_user_ban(u, 'triche');
  perform tst.throws(format('select public.admin_user_ban(%L)', adm), 'cannot_ban_admin');
  perform tst.login(u);
  perform tst.throws('select public.daily_start()', 'banned');
  perform tst.login(adm);
  perform public.admin_user_unban(u);
  perform tst.login(u);
  perform tst.ok((public.daily_start() ->> 'run_id') is not null, 'accès rendu après débannissement');
end $$;

-- 0095 : les chiffres de l'admin sont gardés 10 minutes.
do $$
declare adm uuid := tst.new_user(); k jsonb;
begin
  insert into public.app_admins (user_id) values (adm);
  perform tst.login(adm);
  delete from public.admin_cache;
  k := public.admin_kpis(30);
  perform tst.ok(exists (select 1 from public.admin_cache where key = 'kpis:30'), 'chiffres gardés');
  update public.admin_cache set value = '{"cache": true}' where key = 'kpis:30';
  perform tst.ok(public.admin_kpis(30) ->> 'cache' = 'true', 'servis depuis la mémoire');
  update public.admin_cache set computed_at = now() - interval '11 minutes' where key = 'kpis:30';
  perform tst.ok(not (public.admin_kpis(30) ? 'cache'), 'recalculés après 10 minutes');
end $$;
