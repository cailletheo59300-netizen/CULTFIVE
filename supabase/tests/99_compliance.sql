-- Conformité : signalements, filtre des noms de ligue, export des données, conservation.
do $$
declare
  a uuid := tst.new_user(); b uuid := tst.new_user(); c uuid := tst.new_user(); admin uuid := tst.new_user();
  l jsonb; ex jsonb;
begin
  perform tst.clock('2027-04-01 10:00:00+02');
  perform public._befriend(a, b);
  perform tst.login(a);

  -- Noms de ligue.
  perform tst.throws('select public.league_create(''Les salopes'', 5, null, ''auto'', ''1w'', true, 50)', 'name_not_allowed');
  l := public.league_create('Ligue technique', 5, null, 'auto', '1w', true, 50);
  perform tst.ok(l ->> 'name' = 'Ligue technique', 'mot anodin accepté (pas de faux positif)');
  perform tst.ok(public._text_is_clean('Les supporters') and public._text_is_clean('On habite ici'), 'pas de faux positifs');
  perform tst.throws(format('select public.league_rename(%L, ''Nique tout'')', l ->> 'id'), 'name_not_allowed');

  -- Signalements : seulement ce qu'on voit.
  perform public.report_content('user', b, 'name', 'pseudo choquant');
  perform public.report_content('league', (l ->> 'id')::uuid, 'name');
  perform tst.throws(format('select public.report_content(''user'', %L, ''name'')', c), 'user_not_found');
  perform tst.throws(format('select public.report_content(''user'', %L, ''name'')', a), 'user_not_found');
  perform tst.throws(format('select public.report_content(''user'', %L, ''insulte'')', b), 'invalid');
  insert into public.app_admins (user_id) values (admin);
  perform tst.login(admin);
  perform tst.ok(jsonb_array_length(public.admin_content_reports()) = 2, 'admin : 2 signalements ouverts');
  perform public.admin_content_resolve(b);
  perform tst.ok(jsonb_array_length(public.admin_content_reports()) = 1, 'signalement clos');
  perform tst.login(a);
  perform tst.throws('select public.admin_content_reports()', 'forbidden');

  -- Export : mes données, pas celles des autres.
  ex := public.my_data_export();
  perform tst.ok((ex -> 'profile' ->> 'id')::uuid = a and jsonb_array_length(ex -> 'friends') = 1
                 and jsonb_array_length(ex -> 'leagues') = 1, 'export de mes données');

  -- Conservation : journal d'usage de plus de 13 mois supprimé.
  insert into public.app_events (user_id, name, created_at) values (a, 'app_open', public._now() - interval '14 months'),
                                                                   (a, 'app_open', public._now() - interval '1 month');
  perform public.cron_retention();
  perform tst.ok((select count(*) from public.app_events where user_id = a) = 1, 'journal de plus de 13 mois purgé');
  perform tst.ok(not has_function_privilege('authenticated', 'public.cron_retention()', 'execute'), 'purge protégée');
end $$;
