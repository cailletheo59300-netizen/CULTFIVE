-- Admin (0059, 0060) : un joueur compté = compte connecté (même admin), ou invité récent (3 jours) ou actif
-- (10 réponses) ; jamais un invité venu de l'appareil d'un admin.
do $$
declare
  connected uuid := tst.new_user(false);
  fresh uuid := tst.new_user(true);
  idle uuid := tst.new_user(true);
  active uuid := tst.new_user(true);
  never uuid := tst.new_user(true);
  admin uuid := tst.new_user(false);
  test_guest uuid := tst.new_user(true);
  test_connected uuid := tst.new_user(false);
  v_u uuid;
begin
  perform tst.clock('2027-05-10 12:00:00+02');
  -- Profils créés comme dans l'app, puis datés.
  for v_u in select unnest(array[connected, fresh, idle, active, never, admin, test_guest, test_connected]) loop
    perform tst.login(v_u);
    perform public.profile_me();
  end loop;
  update public.profiles p set created_at = v.t, onboarded_at = case when p.id = never then null else v.t end
  from (values (connected, '2027-04-01'::timestamptz), (fresh, '2027-05-09'), (idle, '2027-05-01'), (active, '2027-05-01'),
               (never, '2027-05-09'), (admin, '2027-04-01'), (test_guest, '2027-05-01'), (test_connected, '2027-05-01')) v(u, t)
  where p.id = v.u;
  insert into public.question_attempts (user_id, question_id, concept_id, given, is_correct, response_ms, context, client_attempt_id,
                                        question_difficulty, user_skill_before, expected, seen_count, created_at)
  select x.u, q.id, q.concept_id, '{}'::jsonb, true, 3000, 'training', gen_random_uuid(), 50, 50, 0.5, 1, '2027-05-02'
  from (select a.u, n from unnest(array[active, test_guest]) a(u) cross join generate_series(1, 12) n
        union all select idle, n from generate_series(1, 4) n) x(u, n)
  cross join (select id, concept_id from public.questions where status = 'published' limit 1) q;
  insert into public.app_admins (user_id) values (admin);
  insert into public.user_devices (user_id, device_hash, first_seen)
  values (admin, repeat('a', 64), now()), (test_guest, repeat('a', 64), now()), (test_connected, repeat('a', 64), now()),
         (active, repeat('b', 64), now());

  perform tst.ok(public._real_player(connected), 'compte connecté : compté');
  perform tst.ok(public._real_player(fresh), 'invité de moins de 3 jours : compté');
  perform tst.ok(not public._real_player(idle), 'invité de plus de 3 jours, 4 réponses : retiré');
  perform tst.ok(public._real_player(active), 'invité de plus de 3 jours, 12 réponses : compté');
  perform tst.ok(not public._real_player(never), 'invité sans onboarding : retiré');
  perform tst.ok(public._real_player(admin), 'admin connecté : compté (il joue comme un joueur)');
  perform tst.ok(not public._real_player(test_guest), 'invité sur l''appareil de l''admin : retiré');
  perform tst.ok(public._real_player(test_connected), 'compte connecté sur l''appareil de l''admin : compté');
end $$;

-- Liste des joueurs (0061) : « Vrais joueurs » suit la même règle ; « Comptes connectés » ; « Tous ».
do $$
declare a uuid := tst.new_user(false); g uuid := tst.new_user(true); r jsonb;
begin
  insert into public.app_admins (user_id) values (a) on conflict do nothing;
  perform tst.login(a); perform public.profile_me();
  perform tst.login(g); perform public.profile_me();
  update public.profiles set created_at = public._now() - interval '10 days', onboarded_at = public._now() - interval '10 days'
  where id = g;
  perform tst.login(a);
  r := public.admin_users((select handle from public.profiles where id = g), 'recent', 10, 0, 'real');
  perform tst.ok((r ->> 'total')::int = 0, 'vrais joueurs : invité inactif retiré');
  r := public.admin_users((select handle from public.profiles where id = g), 'recent', 10, 0, 'all');
  perform tst.ok((r ->> 'total')::int = 1 and (r -> 'items' -> 0 ->> 'real_player')::bool = false, 'tous : visible, marqué hors stats');
  r := public.admin_users((select handle from public.profiles where id = a), 'recent', 10, 0, 'connected');
  perform tst.ok((r ->> 'total')::int = 1, 'comptes connectés : l''admin est là');
end $$;
