-- Classement du 5 du jour (0070) : rang par score puis temps, podium + voisins, part des 7 derniers jours battue.
do $$
declare
  v_date date := '2027-04-02';
  me uuid := tst.new_user();
  others uuid[] := '{}';
  u uuid;
  r jsonb;
begin
  for i in 1 .. 7 loop
    u := tst.new_user(); others := others || u;
    insert into public.daily_runs (user_id, daily_date, status, started_at, deadline_at, finished_at, score, total_ms, streak_after)
    values (u, v_date, 'finished', '2027-04-02 08:00+00', '2027-04-02 09:00+00', '2027-04-02 08:05+00'::timestamptz + i * interval '1 minute',
            case when i <= 3 then 5 else 2 end, 30000 + i * 1000, i);
  end loop;
  -- Moi : 4/5 → 4e (après les trois 5/5).
  insert into public.daily_runs (user_id, daily_date, status, started_at, deadline_at, finished_at, score, total_ms, streak_after)
  values (me, v_date, 'finished', '2027-04-02 08:00+00', '2027-04-02 09:00+00', '2027-04-02 08:30+00', 4, 40000, 3);
  perform tst.login(me);
  r := public.daily_leaderboard(v_date);
  perform tst.ok((r ->> 'participants')::int = 8 and (r ->> 'rank')::int = 4, 'rang 4 sur 8');
  perform tst.ok(jsonb_array_length(r -> 'rows') = 5, 'podium + moi + voisins (3, 4, 5)');
  perform tst.ok((r -> 'rows' -> 3 ->> 'me')::bool and (r -> 'rows' -> 3 ->> 'streak')::int = 3, 'ma ligne, avec ma série');
  perform tst.ok((r ->> 'week_beaten_pct')::int = 57, 'je bats 4 parties sur 7 (57 %)');
  -- Égalité de score : le plus rapide devant.
  perform tst.ok((r -> 'rows' -> 0 ->> 'total_ms')::int = 31000, 'à score égal, le plus rapide');
  -- Joueur sans partie ce jour-là : pas de rang.
  perform tst.login(tst.new_user());
  r := public.daily_leaderboard(v_date);
  perform tst.ok(r ->> 'rank' is null and r ->> 'week_beaten_pct' is null and (r ->> 'participants')::int = 8, 'sans partie : pas de rang');
end $$;
