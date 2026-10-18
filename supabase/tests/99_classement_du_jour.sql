-- Classement du 5 du jour (0070) : le dernier 5 du jour fini de chaque joueur, quelle que soit sa date ; rang par
-- score puis temps ; podium + voisins.
do $$
declare
  me uuid := tst.new_user();
  u uuid;
  r jsonb;
  v_before int;
begin
  perform tst.login(me);
  v_before := (public.daily_leaderboard() ->> 'participants')::int;
  for i in 1 .. 7 loop
    u := tst.new_user();
    -- Une vieille partie ratée, puis la dernière (celle qui compte), à des dates différentes selon les joueurs.
    insert into public.daily_runs (user_id, daily_date, status, started_at, deadline_at, finished_at, score, total_ms, streak_after)
    values (u, date '2027-03-20' + i, 'finished', '2027-03-20 08:00+00', '2027-03-20 09:00+00', '2027-03-20 08:05+00', 0, 90000, 1),
           (u, date '2027-04-01' + i, 'finished', '2027-04-01 08:00+00', '2027-04-01 09:00+00',
            '2027-04-01 08:05+00'::timestamptz + i * interval '1 minute', case when i <= 3 then 5 else 2 end, 30000 + i * 1000, i);
  end loop;
  insert into public.daily_runs (user_id, daily_date, status, started_at, deadline_at, finished_at, score, total_ms, streak_after)
  values (me, '2027-04-12', 'finished', '2027-04-12 08:00+00', '2027-04-12 09:00+00', '2027-04-12 08:30+00', 4, 40000, 3);
  r := public.daily_leaderboard();
  perform tst.ok((r ->> 'participants')::int = v_before + 8, 'un joueur = une ligne (sa dernière partie)');
  perform tst.ok((r -> 'rows') @> '[{"me": true, "streak": 3, "score": 4}]', 'ma ligne, avec ma série');
  perform tst.ok(not ((r -> 'rows') @> '[{"score": 0, "total_ms": 90000}]'), 'les vieilles parties ne comptent pas');
  -- Joueur sans partie : pas de rang.
  perform tst.login(tst.new_user());
  r := public.daily_leaderboard();
  perform tst.ok(r ->> 'rank' is null and (r ->> 'participants')::int = v_before + 8, 'sans partie : pas de rang');
end $$;
