-- Podium des ligues : 1er, 2e, 3e en fin de saison (trophée pour le 1er), conditions anti-triche, une seule fois.
create or replace function tst.league_score(p_league uuid, p_user uuid, p_day date, p_correct int, p_ms int) returns void
language sql as $$
  insert into public.league_answers (league_id, day, user_id, position, question_id, served_at, answered_at, is_correct, counted_ms)
  select p_league, p_day, p_user, i, (select id from public.questions order by id limit 1), now(), now(), i <= p_correct, p_ms
  from generate_series(1, 5) i
$$;

do $$
declare
  a uuid := tst.new_user(); b uuid := tst.new_user(); c uuid := tst.new_user(); d uuid := tst.new_user(); e uuid := tst.new_user();
  l jsonb; v_league uuid; st jsonb; n int;
begin
  perform tst.clock('2027-03-03 10:00:00+01');   -- saison du mercredi 3 au mardi 9 mars
  perform tst.login(a);
  l := public.league_create('Les Podiums', 'week');
  v_league := (l ->> 'id')::uuid;
  insert into public.league_members (league_id, user_id) values (v_league, b), (v_league, c), (v_league, d), (v_league, e);

  -- a 3 jours (12 pts), b 3 jours (10 pts), c 3 jours (10 pts, plus lent), d 4 jours (8 pts), e 1 jour (5 pts).
  perform tst.league_score(v_league, a, dd, 4, 12000) from unnest(array['2027-03-03', '2027-03-04', '2027-03-05']::date[]) dd;
  perform tst.league_score(v_league, b, '2027-03-03', 4, 10000);
  perform tst.league_score(v_league, b, dd, 3, 10000) from unnest(array['2027-03-04', '2027-03-05']::date[]) dd;
  perform tst.league_score(v_league, c, '2027-03-03', 4, 18000);
  perform tst.league_score(v_league, c, dd, 3, 18000) from unnest(array['2027-03-04', '2027-03-05']::date[]) dd;
  perform tst.league_score(v_league, d, dd, 2, 8000) from unnest(array['2027-03-03', '2027-03-04', '2027-03-05', '2027-03-06']::date[]) dd;
  perform tst.league_score(v_league, e, '2027-03-03', 5, 2000);

  perform tst.ok(public.cron_league_podiums() = 0, 'saison en cours : pas de podium');
  perform tst.clock('2027-03-09 23:30:00+01');
  perform tst.ok(public.cron_league_podiums() = 0, 'dernier jour pas fini : rien');

  -- Mercredi 0 h 30 (heure de la ligue) : 1er a, 2e b (plus rapide que c), 3e c. Plus de coffres (0058) : podium et trophée.
  perform tst.clock('2027-03-10 00:30:00+01');
  perform tst.ok(public.cron_league_podiums() = 3, '3 places de podium');
  perform tst.ok((select place from public.league_results where league_id = v_league and user_id = a) = 1, '1er : a');
  perform tst.ok((select place from public.league_results where league_id = v_league and user_id = b) = 2, '2e : b (départage au temps)');
  perform tst.ok((select place from public.league_results where league_id = v_league and user_id = c) = 3, '3e : c');
  perform tst.ok(not exists (select 1 from public.league_results where league_id = v_league and user_id in (d, e)), 'hors podium : rien');
  perform tst.ok(not exists (select 1 from public.user_chests where source = 'league' and user_id in (a, b, c)), 'plus de coffre de ligue');
  perform tst.ok(exists (select 1 from public.user_achievements where user_id = a and achievement_id = 'league_winner'),
                 'trophée Vainqueur de ligue');
  perform tst.ok(not exists (select 1 from public.user_achievements where user_id = b and achievement_id = 'league_winner'),
                 'pas de trophée pour le 2e');
  perform tst.ok(public.cron_league_podiums() = 0, 'jamais deux fois');

  perform tst.login(b);
  st := public.league_standings(v_league, 0);
  perform tst.ok(st ->> 'status' = 'finished' and (st ->> 'my_place')::int = 2 and st -> 'my_reward' = 'null'::jsonb,
                 'classement : ta place');
  perform tst.ok(jsonb_array_length(st -> 'results') = 3 and st -> 'results' -> 0 ->> 'id' = a::text, 'classement : le podium');
  perform tst.ok((st -> 'podium' ->> 'min_players')::int = 3 and (st -> 'podium' ->> 'min_days')::int = 3, 'règles du podium');
  perform tst.ok((st -> 'podium' ->> 'active_players')::int = 5, 'joueurs actifs');

  -- Saison 2 : seulement 2 joueurs actifs → pas de podium.
  perform tst.login(a);
  st := public.league_new_season(v_league, true);
  perform tst.league_score(v_league, u, dd, 5, 5000)
    from unnest(array[a, b]) u cross join unnest(array['2027-03-10', '2027-03-11', '2027-03-12']::date[]) dd;
  perform tst.clock('2027-03-17 01:00:00+01');
  perform public.cron_league_podiums();
  perform tst.ok(not exists (select 1 from public.league_results where league_id = v_league and season = 2),
                 'moins de 3 joueurs actifs : pas de podium');

  -- Secours : un membre qui ouvre ses ligues déclenche le podium même si la tâche planifiée n'est pas passée.
  delete from public.league_results where league_id = v_league and season = 1;
  perform tst.login(a);
  perform public.leagues_mine();
  perform tst.ok((select place from public.league_results where league_id = v_league and season = 1 and user_id = a) = 1,
                 'podium à l''ouverture des ligues');

  perform tst.ok(not has_function_privilege('authenticated', 'public.cron_league_podiums()', 'execute'), 'tâche planifiée protégée');
  perform tst.ok(not has_function_privilege('authenticated', 'public._league_award(uuid)', 'execute'), 'versement protégé');
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
