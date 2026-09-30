-- Podium des ligues : coffres or / argent / bois, conditions anti-triche, versement unique ; coffre de bienvenue.
do $$
declare
  a uuid := tst.new_user(); b uuid := tst.new_user(); c uuid := tst.new_user(); d uuid := tst.new_user(); e uuid := tst.new_user();
  l jsonb; v_league uuid; st jsonb; n int;
begin
  perform tst.clock('2027-03-03 10:00:00+01');   -- mercredi, semaine du 1er au 7 mars
  perform tst.login(a);
  l := public.league_create('Les Podiums', 'week');
  v_league := (l ->> 'id')::uuid;
  insert into public.league_members (league_id, user_id) values (v_league, b), (v_league, c), (v_league, d), (v_league, e);

  -- Semaine : a 3 jours (12 pts), b 3 jours (10 pts), c 3 jours (10 pts, plus lent), d 4 jours (8 pts), e 1 jour (5 pts).
  insert into public.daily_runs (user_id, daily_date, status, started_at, deadline_at, score, total_ms) values
    (a, '2027-03-01', 'finished', now(), now(), 4, 60000), (a, '2027-03-02', 'finished', now(), now(), 4, 60000),
    (a, '2027-03-03', 'finished', now(), now(), 4, 60000),
    (b, '2027-03-01', 'finished', now(), now(), 4, 50000), (b, '2027-03-02', 'finished', now(), now(), 3, 50000),
    (b, '2027-03-03', 'finished', now(), now(), 3, 50000),
    (c, '2027-03-01', 'finished', now(), now(), 4, 90000), (c, '2027-03-02', 'finished', now(), now(), 3, 90000),
    (c, '2027-03-03', 'finished', now(), now(), 3, 90000),
    (d, '2027-03-01', 'finished', now(), now(), 2, 40000), (d, '2027-03-02', 'finished', now(), now(), 2, 40000),
    (d, '2027-03-03', 'finished', now(), now(), 2, 40000), (d, '2027-03-04', 'finished', now(), now(), 2, 40000),
    (e, '2027-03-01', 'finished', now(), now(), 5, 10000);

  -- Pendant la semaine : rien n'est versé.
  perform tst.ok(public.cron_league_podiums() = 0, 'semaine en cours : pas de podium');

  -- Lundi 8 mars à 10 h : la journée du dimanche n'est pas finie partout (UTC−12) → toujours rien.
  perform tst.clock('2027-03-08 10:00:00+01');
  perform tst.ok(public.cron_league_podiums() = 0, 'attente de la fin du dimanche dans tous les fuseaux');

  -- Lundi 14 h : or pour a, argent pour b (plus rapide que c), bois pour c ; d et e hors podium.
  perform tst.clock('2027-03-08 14:00:00+01');
  perform tst.ok(public.cron_league_podiums() = 3, '3 coffres versés');
  perform tst.ok((select tier from public.user_chests where user_id = a and source = 'league') = 'gold', '1er : or');
  perform tst.ok((select tier from public.user_chests where user_id = b and source = 'league') = 'silver', '2e : argent (départage au temps)');
  perform tst.ok((select tier from public.user_chests where user_id = c and source = 'league') = 'wood', '3e : bois');
  perform tst.ok(not exists (select 1 from public.user_chests where user_id in (d, e) and source = 'league'), 'hors podium : rien');
  perform tst.ok(public.cron_league_podiums() = 0, 'jamais deux fois');

  -- Le classement de la semaine passée annonce le coffre gagné.
  perform tst.login(b);
  st := public.league_standings(v_league, -1);
  perform tst.ok(st -> 'my_reward' ->> 'tier' = 'silver' and (st -> 'my_reward' ->> 'place')::int = 2, 'classement : ton coffre');
  perform tst.ok((st -> 'podium' ->> 'min_players')::int = 4 and (st -> 'podium' ->> 'min_days')::int = 3, 'règles du podium');
  perform tst.ok((st -> 'podium' ->> 'active_players')::int = 5, 'joueurs actifs');
  perform tst.ok(public.league_standings(v_league, 0) -> 'my_reward' = 'null'::jsonb, 'semaine en cours : pas encore de coffre');

  -- Semaine suivante : seulement 3 joueurs actifs → pas de podium.
  perform tst.clock('2027-03-10 10:00:00+01');
  insert into public.daily_runs (user_id, daily_date, status, started_at, deadline_at, score, total_ms)
  select u, dd, 'finished', now(), now(), 5, 30000
  from unnest(array[a, b, c]) u cross join unnest(array['2027-03-08', '2027-03-09', '2027-03-10']::date[]) dd;
  perform tst.clock('2027-03-15 14:00:00+01');
  select count(*) into n from public.user_chests where source = 'league' and ref like v_league || ':2027-03-08:%';
  perform public.cron_league_podiums();
  perform tst.ok((select count(*) from public.user_chests where source = 'league' and ref like v_league || ':2027-03-08:%') = n,
                 'moins de 4 joueurs actifs : pas de podium');

  -- Secours : un membre qui ouvre ses ligues reçoit le coffre même si la tâche planifiée n'est pas passée.
  delete from public.user_chests where user_id = a and source = 'league';
  perform tst.clock('2027-03-09 09:00:00+01');
  perform tst.login(a);
  perform public.leagues_mine();
  perform tst.ok((select tier from public.user_chests where user_id = a and source = 'league') = 'gold', 'versement à l''ouverture des ligues');

  -- Sécurité.
  perform tst.ok(not has_function_privilege('authenticated', 'public.cron_league_podiums()', 'execute'), 'tâche planifiée protégée');
  perform tst.ok(not has_function_privilege('authenticated', 'public._league_award(uuid, int)', 'execute'), 'versement protégé');
end $$;

-- Coffre de bienvenue à la fin de l'onboarding, une seule fois.
do $$
declare u uuid := tst.new_user();
begin
  perform tst.login(u);
  perform public.complete_onboarding('balanced', array['history']);
  perform public.complete_onboarding('challenge', array['science']);
  perform tst.ok((select count(*) from public.user_chests where user_id = u and source = 'welcome' and tier = 'gold') = 1,
                 'un coffre d''or de bienvenue, une seule fois');
end $$;
