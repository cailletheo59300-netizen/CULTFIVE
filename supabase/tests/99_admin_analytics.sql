-- Espace admin : journal d'événements, statistiques, fiche joueur, renommage, bannissement.
do $$
declare
  adm uuid := tst.new_user();
  u uuid := tst.new_user();
  r jsonb; k jsonb; pack jsonb; atts jsonb := '[]'::jsonb; x jsonb;
begin
  perform tst.clock('2027-11-02 10:00:00+01');
  insert into public.app_admins (user_id) values (adm);

  -- Journal : noms inconnus ignorés, sans bloquer les autres.
  perform tst.login(u);
  r := public.track_events('[{"name":"app_open","app_version":"1.4.0"},{"name":"hack","props":{}},{"name":"share","props":{"what":"daily"}}]');
  perform tst.ok((r ->> 'recorded')::int = 2, 'deux événements valides enregistrés');
  pack := public.play_pack('training', 'history', null, 5, true, null);
  for x in select * from jsonb_array_elements(pack -> 'questions') loop
    atts := atts || jsonb_build_object('client_attempt_id', gen_random_uuid(), 'question_id', x ->> 'id',
                                       'given', tst.correct_given((x ->> 'id')::uuid), 'response_ms', 3000);
  end loop;
  perform public.play_submit((pack ->> 'session_id')::uuid, atts);

  -- Un joueur ordinaire n'a pas accès aux outils d'admin.
  perform tst.throws('select public.admin_kpis(30)', 'forbidden');
  perform tst.throws(format('select public.admin_user_ban(%L)', adm), 'forbidden');

  perform tst.login(adm);
  k := public.admin_kpis(30);
  perform tst.ok((k -> 'totals' ->> 'players')::int >= 2, 'joueurs comptés');
  perform tst.ok((k -> 'totals' ->> 'dau')::int >= 1, 'actifs du jour');
  perform tst.ok(jsonb_array_length(k -> 'series') = 30, '30 jours de série');
  perform tst.ok((k -> 'series' -> 29 ->> 'answers')::int >= 5, 'réponses du jour');
  perform tst.ok(k -> 'versions' ? '1.4.0', 'versions de l''app');
  perform tst.ok((k -> 'events' ->> 'share')::int >= 1, 'événements de la semaine');

  r := public.admin_users((select handle from public.profiles where id = u), 'recent', 10, 0);
  perform tst.ok((r ->> 'total')::int = 1 and (r -> 'items' -> 0 ->> 'id')::uuid = u, 'recherche par pseudo');
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
