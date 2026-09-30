-- Brainlix — 0023 Coffres du podium des ligues, coffre de bienvenue des nouveaux joueurs
--
-- Podium : à la fin de chaque période (semaine du lundi au dimanche, ou mois), les 3 premiers d'une ligue gagnent
-- un coffre : or (1er), argent (2e), bois (3e). Anti-triche : la période compte seulement si au moins 4 membres
-- ont joué le 5 du jour, et un joueur n'est classé sur le podium qu'avec au moins 3 jours joués (10 pour un mois).
-- Versé par une tâche planifiée (toutes les heures), une fois la période terminée dans tous les fuseaux (lendemain 12 h UTC),
-- et en secours à l'ouverture des ligues (leagues_mine). Un coffre par ligue, par période et par joueur (clé unique).

create or replace function public._podium_min_players() returns int language sql immutable as $$ select 4 $$;

create or replace function public._podium_min_days(p_period public.league_period) returns int language sql immutable as $$
  select case p_period when 'week' then 3 else 10 end
$$;

-- Podium d'une période : les 3 premiers parmi les joueurs assez présents (même ordre que le classement).
create or replace function public._league_podium(p_league uuid, p_period public.league_period, p_start date, p_end date)
returns table (user_id uuid, place int)
language sql stable as $$
  with scores as (
    select m.user_id, coalesce(sum(r.score), 0) as points, coalesce(sum(r.total_ms), 0) as total_ms, count(r.id) as days
    from public.league_members m
    left join public.daily_runs r on r.user_id = m.user_id and r.status in ('finished', 'expired')
                                 and r.daily_date between p_start and p_end
    where m.league_id = p_league
    group by m.user_id
  )
  select s.user_id, (row_number() over (order by s.points desc, s.total_ms asc, s.days desc, s.user_id))::int
  from scores s
  where s.days >= public._podium_min_days(p_period)
    and (select count(*) from scores x where x.days > 0) >= public._podium_min_players()
  order by 2
  limit 3
$$;

-- Verse les coffres du podium d'une période terminée. Renvoie le nombre de coffres créés.
create or replace function public._league_award(p_league uuid, p_offset int) returns int
language plpgsql as $$
declare
  l public.leagues;
  b record;
  w record;
  v_count int := 0;
begin
  select * into l from public.leagues where id = p_league;
  if not found then return 0; end if;
  select * into b from public._period_bounds(l.period, (public._now() at time zone 'UTC')::date, p_offset);
  -- Période finie partout : le dernier fuseau (UTC−12) termine sa journée le lendemain à 12 h UTC.
  if public._now() < ((b.end_date + 1)::timestamp + interval '12 hours') at time zone 'UTC' then return 0; end if;
  for w in select * from public._league_podium(l.id, l.period, b.start_date, b.end_date) loop
    if public._give_chest(w.user_id, (case w.place when 1 then 'gold' when 2 then 'silver' else 'wood' end)::public.chest_tier,
                          'league', l.id || ':' || b.start_date || ':' || w.place,
                          'league:' || l.id || ':' || b.start_date) then
      v_count := v_count + 1;
    end if;
  end loop;
  return v_count;
end $$;

-- Tâche planifiée : les deux dernières périodes de chaque ligue (rattrape une heure manquée).
create or replace function public.cron_league_podiums() returns int
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  l record;
  v_total int := 0;
begin
  for l in select id from public.leagues loop
    v_total := v_total + public._league_award(l.id, -1) + public._league_award(l.id, -2);
  end loop;
  return v_total;
end $$;

-- Ligues du joueur (+ versement de secours des podiums de ses ligues).
create or replace function public.leagues_mine() returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  l record;
begin
  for l in select league_id from public.league_members where user_id = v_user loop
    perform public._league_award(l.league_id, -1);
  end loop;
  return (select coalesce(jsonb_agg(jsonb_build_object('id', g.id, 'name', g.name, 'period', g.period,
                                                       'members', (select count(*) from public.league_members x where x.league_id = g.id),
                                                       'invite_code', g.invite_code) order by m.joined_at), '[]'::jsonb)
          from public.league_members m join public.leagues g on g.id = m.league_id
          where m.user_id = v_user);
end $$;

-- Classement : + règles du podium et coffre gagné par le joueur sur cette période.
alter function public.league_standings(uuid, int) rename to _league_standings_base;
revoke execute on function public._league_standings_base(uuid, int) from public, anon, authenticated;
create or replace function public.league_standings(p_league uuid, p_offset int default 0) returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  v jsonb := public._league_standings_base(p_league, p_offset);
begin
  return v || jsonb_build_object(
    'podium', jsonb_build_object(
      'min_players', public._podium_min_players(),
      'min_days', public._podium_min_days((v ->> 'period')::public.league_period),
      'active_players', (select count(*) from jsonb_array_elements(v -> 'standings') e where (e ->> 'days')::int > 0)),
    'my_reward', (select jsonb_build_object('tier', c.tier, 'place', split_part(c.ref, ':', 3)::int)
                  from public.user_chests c
                  where c.user_id = v_user and c.idempotency_key = 'league:' || p_league || ':' || (v ->> 'start_date')));
end $$;

-- ─────────────────────────────────────────── Coffre de bienvenue des nouveaux joueurs (fin de l'onboarding)
do $$
declare
  f record;
  v_old text;
  v_new text;
begin
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'complete_onboarding' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(v_old, '  return public.profile_me();',
                     '  perform public._give_chest(v_user, ''gold'', ''welcome'', null, ''welcome'');
  return public.profile_me();');
    if v_new = v_old then raise exception '0023: complete_onboarding inchangée'; end if;
    execute v_new;
  end loop;
end $$;

-- ─────────────────────────────────────────── Droits, tâche planifiée
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and p.proname in ('_podium_min_players', '_podium_min_days', '_league_podium', '_league_award', 'cron_league_podiums',
                        '_league_standings_base')
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', f.sig);
  end loop;
end $$;
revoke execute on function public.leagues_mine() from public, anon;
grant execute on function public.leagues_mine() to authenticated;
revoke execute on function public.league_standings(uuid, int) from public, anon;
grant execute on function public.league_standings(uuid, int) to authenticated;

do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig from pg_proc p
    where p.pronamespace = 'public'::regnamespace and p.prokind in ('f', 'p')
      and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%')
  loop
    execute format('alter function %s set search_path = public, extensions, pg_temp', f.sig);
  end loop;
end $$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('brainlix-league-podiums', '7 * * * *', 'select public.cron_league_podiums()');
  end if;
exception when others then
  raise notice 'pg_cron indisponible : podiums versés à l''ouverture des ligues seulement (%)', sqlerrm;
end $$;
