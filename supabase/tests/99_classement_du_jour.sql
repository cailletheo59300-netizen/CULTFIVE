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

-- 0074 : classement Elo d'un domaine (joueurs placés), le joueur qui regarde a sa ligne.
do $$
declare a uuid := tst.new_user(); b uuid := tst.new_user(); r jsonb;
begin
  insert into public.user_skills (user_id, scope_id, mu, var, n, correct, elo) values
    (a, 'sport', 50, 20, 60, 40, 1111), (b, 'sport', 50, 20, 60, 40, 1110);
  perform tst.login(b);
  r := public.domain_leaderboard('sport');
  perform tst.ok((r -> 'rows') @> '[{"me": true, "elo": 1110}]', 'ma ligne avec mon Elo');
  perform tst.ok((select rank from public._domain_ranks('sport', b) where user_id = a)
                 < (select rank from public._domain_ranks('sport', b) where user_id = b), 'meilleur Elo devant');
  -- 0075 : un joueur pas encore placé (quelques réponses) est aussi classé.
  insert into public.user_skills (user_id, scope_id, mu, var, n, correct, elo) values (tst.new_user(), 'sport', 50, 20, 3, 2, 520);
  perform tst.ok(exists (select 1 from public._domain_ranks('sport', b) where elo = 520), 'non placé : classé aussi');
  perform tst.throws('select public.domain_leaderboard(''nope'')', 'invalid_domain');
end $$;

-- 0083 : podium du jour — les joueurs d'aujourd'hui passent devant, même avec un moins bon score ; les autres suivent
-- avec l'ancienneté de leur partie.
do $$
declare
  me uuid := tst.new_user();
  old uuid := tst.new_user();
  r jsonb;
begin
  perform tst.clock('2027-05-10 12:00:00+02');
  insert into public.daily_runs (user_id, daily_date, status, started_at, deadline_at, finished_at, score, total_ms, streak_after)
  values (old, '2027-05-09', 'finished', '2027-05-09 08:00+00', '2027-05-09 09:00+00', '2027-05-09 08:01+00', 5, 20000, 4),
         (me, '2027-05-10', 'finished', '2027-05-10 08:00+00', '2027-05-10 09:00+00', '2027-05-10 08:05+00', 2, 60000, 1);
  perform tst.login(me);
  perform tst.ok((select rank from public._daily_ranks(me) where user_id = me)
                 < (select rank from public._daily_ranks(me) where user_id = old), 'joueur du jour devant un 5/5 d''hier');
  perform tst.ok((select ago from public._daily_ranks(me) where user_id = old) = 1
                 and (select ago from public._daily_ranks(me) where user_id = me) = 0, 'ancienneté : hier = 1, aujourd''hui = 0');
  r := public.daily_leaderboard();
  perform tst.ok((r -> 'rows') @> '[{"me": true, "ago": 0}]', 'ancienneté envoyée à l''app');
end $$;
