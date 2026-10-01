-- Fiabilité : diagnostics, version minimale, santé, règles d'accès réécrites.
do $$
declare u uuid := tst.new_user(); admin uuid := tst.new_user(); h jsonb;
begin
  perform tst.clock('2027-08-01 10:00:00+02');
  perform tst.login(u);
  perform public.report_diagnostic('crash', '{"signal": "SIGSEGV"}'::jsonb, '1.0 (42)', '18.1');
  perform public.report_diagnostic('unknown', '{}'::jsonb, '1.0 (42)', '18.1');
  perform tst.ok((select count(*) from public.app_diagnostics where user_id = u) = 1, 'diagnostic enregistré, type inconnu ignoré');
  for i in 1 .. 30 loop perform public.report_diagnostic('hang', '{}'::jsonb, '1.0', '18'); end loop;
  perform tst.ok((select count(*) from public.app_diagnostics where user_id = u) = 20, '20 par jour au plus');
  perform public.track_events('[{"name": "client_error", "props": {"function": "daily_start", "code": "offline"}}]'::jsonb);

  perform tst.ok((public.app_settings() ->> 'min_build')::int = 0, 'version minimale par défaut');
  perform tst.throws('select public.admin_set_min_build(50)', 'forbidden');
  insert into public.app_admins (user_id) values (admin);
  perform tst.login(admin);
  perform public.admin_set_min_build(50);
  perform tst.ok((public.app_settings() ->> 'min_build')::int = 50, 'version minimale réglée');
  h := public.admin_health();
  perform tst.ok(jsonb_array_length(h -> 'diagnostics_7d') >= 2 and jsonb_array_length(h -> 'errors_7d') = 1, 'santé : diagnostics et erreurs');
  perform public.admin_set_min_build(0);
  perform tst.ok(not exists (select 1 from pg_policy where pg_get_expr(polqual, polrelid) ~ '(^|[^T] )auth\.uid\(\)'
                             and polrelid::regclass::text like 'public.%' and pg_get_expr(polqual, polrelid) !~ 'SELECT auth\.uid'),
                 'règles d''accès : auth.uid() évalué une fois');
end $$;

-- Les règles d'accès réécrites marchent toujours : chacun ne lit que son profil.
do $$
declare a uuid := tst.new_user(); b uuid := tst.new_user(); n int;
begin
  perform tst.login(a);
  set local role authenticated;
  select count(*) into n from public.profiles;
  reset role;
  perform tst.ok(n = 1, 'RLS : un seul profil visible');
end $$;
