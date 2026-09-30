-- Brainlix — 0034 Ligues v2 : un quiz quotidien propre à chaque ligue
-- Une ligue n'utilise plus le 5 du jour général. Son créateur choisit : questions par jour (5, 10, 15, 20), domaines,
-- difficulté (auto ou choisie), durée (1 semaine, 2 semaines, 1 mois), début (aujourd'hui ou demain), membres max.
-- Chaque jour, tous les membres ont le même quiz de la ligue (servi dans l'ordre, temps officiel serveur, hors Elo).
-- Points : 1 par bonne réponse ; départage au temps total, puis aux jours joués. Jour manqué : 0, sans rattrapage.
--
-- Dates : tout est calculé ici, dans le fuseau de la ligue (celui du créateur). Un « jour de ligue » va de minuit à
-- minuit dans ce fuseau, pour tous les membres. Durées :
--   1 semaine = 7 jours ; 2 semaines = 14 jours ;
--   1 mois = jusqu'à la veille du même jour le mois suivant ; si ce jour n'existe pas, dernier jour du mois
--   (30 sept. → 29 oct. inclus ; 31 janv. → 27 févr. inclus, ou 28 en année bissextile). PostgreSQL gère les mois
--   de 28 à 31 jours, les années bissextiles et le changement d'année.
-- Fin de ligue : « Nouvelle saison » relance avec les mêmes membres et réglages. Podium : coffres comme avant.
-- Invitations : aperçu avant d'entrer (league_preview), codes de 8 caractères, essais limités, nouveau code et retrait
-- d'un membre par le créateur.

-- ─────────────────────────────────────────── Schéma
alter table public.leagues
  add column question_count int  not null default 5 check (question_count in (5, 10, 15, 20)),
  add column domains        text[],
  add column difficulty     text not null default 'auto' check (difficulty in ('auto', 'easy', 'medium', 'hard')),
  add column duration       text not null default '1w' check (duration in ('1w', '2w', '1m')),
  add column timezone       text not null default 'Europe/Paris',
  add column max_members    int  not null default 50 check (max_members between 2 and 50),
  add column season         int  not null default 1,
  add column starts_on      date,
  add column ends_on        date;

create table public.league_seasons (
  league_id uuid not null references public.leagues(id) on delete cascade,
  season    int  not null,
  starts_on date not null,
  ends_on   date not null,
  primary key (league_id, season),
  check (ends_on >= starts_on)
);

create table public.league_days (
  league_id    uuid not null references public.leagues(id) on delete cascade,
  day          date not null,
  question_ids uuid[] not null,
  primary key (league_id, day)
);

create table public.league_answers (
  league_id   uuid not null references public.leagues(id) on delete cascade,
  day         date not null,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  position    int  not null check (position between 1 and 20),
  question_id uuid not null references public.questions(id),
  served_at   timestamptz not null,
  answered_at timestamptz,
  given       jsonb,
  is_correct  bool,
  counted_ms  int,
  primary key (league_id, day, user_id, position)
);
create index on public.league_answers (league_id, user_id, day);

create table public.league_code_attempts (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);
create index on public.league_code_attempts (user_id, created_at);

alter table public.league_seasons enable row level security;
alter table public.league_days enable row level security;
alter table public.league_answers enable row level security;
alter table public.league_code_attempts enable row level security;
revoke all on public.league_seasons, public.league_days, public.league_answers, public.league_code_attempts
  from public, anon, authenticated;

-- ─────────────────────────────────────────── Dates
-- Dernier jour d'une saison qui commence p_start (inclus).
create or replace function public._league_last_day(p_start date, p_duration text) returns date
language sql immutable as $$
  select case p_duration
    when '1w' then p_start + 6
    when '2w' then p_start + 13
    else ((p_start + interval '1 month')::date - 1) end
$$;

create or replace function public._league_today(l public.leagues) returns date
language sql stable as $$ select (public._now() at time zone l.timezone)::date $$;

-- upcoming · active · finished
create or replace function public._league_status(l public.leagues) returns text
language sql stable as $$
  select case when public._league_today(l) < l.starts_on then 'upcoming'
              when public._league_today(l) > l.ends_on then 'finished' else 'active' end
$$;

-- Fin exacte d'une saison : minuit après le dernier jour, dans le fuseau de la ligue.
create or replace function public._league_end_at(p_last date, p_tz text) returns timestamptz
language sql immutable as $$ select ((p_last + 1)::timestamp) at time zone p_tz $$;

-- Conversion des ligues existantes : nouvelle saison à partir de demain, 5 questions, tous domaines, même durée.
update public.leagues l set
  timezone = coalesce((select p.timezone from public.profiles p where p.id = l.owner_id), 'Europe/Paris'),
  duration = case l.period when 'week' then '1w' else '1m' end;
update public.leagues l set starts_on = (public._now() at time zone l.timezone)::date + 1;
update public.leagues l set ends_on = public._league_last_day(l.starts_on, l.duration);
insert into public.league_seasons (league_id, season, starts_on, ends_on) select id, 1, starts_on, ends_on from public.leagues;
alter table public.leagues alter column starts_on set not null, alter column ends_on set not null;

-- ─────────────────────────────────────────── Quiz du jour de la ligue
-- Questions du jour : tirées une fois (au premier membre qui joue), identiques pour tous. Jamais une question du 5 du
-- jour protégé ni déjà servie dans cette ligue ; difficulté auto = niveau moyen des membres.
create or replace function public._league_day_questions(l public.leagues, p_day date) returns uuid[]
language plpgsql as $$
declare
  v_ids uuid[];
  v_target real;
  v_lo real; v_hi real;
begin
  select question_ids into v_ids from public.league_days where league_id = l.id and day = p_day;
  if v_ids is not null then return v_ids; end if;
  select coalesce(avg(public._overall_mu(m.user_id)), 50) into v_target from public.league_members m where m.league_id = l.id;
  select lo, hi into v_lo, v_hi from (values
    ('easy', 15::real, 40::real), ('medium', 38, 62), ('hard', 60, 92),
    ('auto', greatest(v_target - 12, 15), least(v_target + 12, 90))) t(k, lo, hi)
  where k = l.difficulty;
  select array_agg(id order by d, id) into v_ids from (
    select id, d from (
      select q.id, q.difficulty_effective as d,
             row_number() over (partition by q.domain_id
                                order by (q.difficulty_effective between v_lo and v_hi) desc, random()) as rn
      from public.questions q
      where q.status = 'published' and q.type <> 'map_pick'
        and (l.domains is null or q.domain_id = any (l.domains))
        and q.id <> all (public._protected_daily_questions())
        and not exists (select 1 from public.league_days ld where ld.league_id = l.id and q.id = any (ld.question_ids))
    ) t
    order by rn, random()
    limit l.question_count
  ) s;
  if coalesce(cardinality(v_ids), 0) < l.question_count then raise exception 'not_enough_questions'; end if;
  insert into public.league_days (league_id, day, question_ids) values (l.id, p_day, v_ids)
  on conflict (league_id, day) do nothing;
  select question_ids into v_ids from public.league_days where league_id = l.id and day = p_day;
  return v_ids;
end $$;

create or replace function public._league_day_state(p_league uuid, p_day date, p_user uuid,
                                                    out answered int, out score int, out total_ms int)
language sql stable as $$
  select count(*) filter (where answered_at is not null)::int,
         count(*) filter (where is_correct)::int,
         coalesce(sum(counted_ms) filter (where answered_at is not null), 0)::int
  from public.league_answers where league_id = p_league and day = p_day and user_id = p_user
$$;

create or replace function public._league_for_member(p_league uuid, p_user uuid) returns public.leagues
language plpgsql stable as $$
declare l public.leagues;
begin
  select * into l from public.leagues where id = p_league;
  if not found or not public._is_member(p_league, p_user) then raise exception 'league_not_found'; end if;
  return l;
end $$;

create or replace function public.league_question(p_league uuid, p_position int) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  l public.leagues := public._league_for_member(p_league, v_user);
  v_day date := public._league_today(l);
  v_ids uuid[];
  st record;
  q public.questions;
begin
  if public._league_status(l) <> 'active' then raise exception 'league_not_active'; end if;
  v_ids := public._league_day_questions(l, v_day);
  select * into st from public._league_day_state(l.id, v_day, v_user);
  if p_position <> st.answered + 1 or p_position > cardinality(v_ids) then raise exception 'league_out_of_order'; end if;
  insert into public.league_answers (league_id, day, user_id, position, question_id, served_at)
  values (l.id, v_day, v_user, p_position, v_ids[p_position], public._now())
  on conflict (league_id, day, user_id, position) do nothing;
  select * into q from public.questions where id = v_ids[p_position];
  return public._question_public(q, l.id::text || v_day) || jsonb_build_object('position', p_position, 'total', cardinality(v_ids));
end $$;

create or replace function public.league_answer(p_league uuid, p_position int, p_given jsonb, p_client_ms int) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  l public.leagues := public._league_for_member(p_league, v_user);
  a public.league_answers;
  q public.questions;
  v_server_ms int; v_counted int;
  v_res jsonb;
  v_total int;
begin
  -- La question servie la plus récente à cette position (une question servie à 23 h 59 se répond après minuit).
  select * into a from public.league_answers
  where league_id = l.id and user_id = v_user and position = p_position and day >= public._league_today(l) - 1
  order by day desc limit 1 for update;
  if not found then raise exception 'league_not_served'; end if;
  select * into q from public.questions where id = a.question_id;
  v_total := cardinality((select question_ids from public.league_days where league_id = l.id and day = a.day));
  if a.answered_at is not null then
    return jsonb_build_object('position', p_position, 'is_correct', a.is_correct, 'duplicate', true, 'counted_ms', a.counted_ms,
                              'finished', p_position = v_total) || public._question_reveal(q);
  end if;
  v_server_ms := floor(extract(epoch from public._now() - a.served_at) * 1000)::int;
  v_counted := least(v_server_ms, greatest(coalesce(p_client_ms, v_server_ms), v_server_ms - 2000));
  v_counted := least(greatest(v_counted, 300), 120000);
  v_res := public._record_attempt(v_user, q.id, p_given, v_counted, 'challenge', l.id,
                                  md5(l.id::text || ':' || a.day || ':' || v_user || ':' || p_position)::uuid, false);
  update public.league_answers set answered_at = public._now(), given = p_given,
    is_correct = (v_res ->> 'is_correct')::bool, counted_ms = v_counted
  where league_id = l.id and day = a.day and user_id = v_user and position = p_position;
  if (v_res ->> 'is_correct')::bool then
    perform public._grant_capped(v_user, 'xp', 5, 300, 'league_correct', l.id::text,
                                 'league_correct:' || l.id || ':' || a.day || ':' || p_position);
  end if;
  return jsonb_build_object('position', p_position, 'is_correct', (v_res ->> 'is_correct')::bool, 'duplicate', false,
                            'counted_ms', v_counted, 'finished', p_position = v_total,
                            'error_transition', v_res -> 'error_transition')
         || public._question_reveal(q);
end $$;

-- Résultat du jour : mes réponses, et les scores des membres (visibles une fois mon quiz fini, ou le jour passé).
create or replace function public.league_day_result(p_league uuid, p_day date default null) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  l public.leagues := public._league_for_member(p_league, v_user);
  v_day date := coalesce(p_day, public._league_today(l));
  v_total int := coalesce(cardinality((select question_ids from public.league_days where league_id = l.id and day = v_day)),
                          l.question_count);
  me record;
  v_open bool;
begin
  select * into me from public._league_day_state(l.id, v_day, v_user);
  v_open := me.answered >= v_total or v_day < public._league_today(l);
  return jsonb_build_object(
    'day', v_day, 'total', v_total,
    'me', jsonb_build_object('answered', me.answered, 'score', me.score, 'total_ms', me.total_ms),
    'my_answers', coalesce((select jsonb_agg(jsonb_build_object('position', position, 'is_correct', is_correct,
                                                                'counted_ms', counted_ms) order by position)
                            from public.league_answers
                            where league_id = l.id and day = v_day and user_id = v_user and answered_at is not null), '[]'::jsonb),
    'members', case when v_open then (select coalesce(jsonb_agg(jsonb_build_object(
                  'id', p.id, 'handle', p.handle, 'is_me', p.id = v_user,
                  'answered', s.answered, 'score', s.score, 'total_ms', s.total_ms)
                  order by s.score desc, s.total_ms asc, lower(p.handle)), '[]'::jsonb)
                from public.league_members m join public.profiles p on p.id = m.user_id
                cross join lateral public._league_day_state(l.id, v_day, m.user_id) s
                where m.league_id = l.id) end);
end $$;

-- ─────────────────────────────────────────── Classement et podium
create or replace function public._league_rows(p_league uuid, p_start date, p_end date)
returns table (user_id uuid, points int, days int, total_ms int)
language sql stable as $$
  select m.user_id,
         count(a.*) filter (where a.is_correct)::int,
         count(distinct a.day) filter (where a.answered_at is not null)::int,
         coalesce(sum(a.counted_ms) filter (where a.answered_at is not null), 0)::int
  from public.league_members m
  left join public.league_answers a on a.league_id = m.league_id and a.user_id = m.user_id and a.day between p_start and p_end
  where m.league_id = p_league
  group by m.user_id
$$;

create or replace function public._league_min_days(p_duration text) returns int language sql immutable as $$
  select case p_duration when '1w' then 3 when '2w' then 6 else 10 end
$$;

drop function if exists public._league_podium(uuid, public.league_period, date, date);
create or replace function public._league_podium(p_league uuid, p_start date, p_end date, p_min_days int)
returns table (user_id uuid, place int)
language sql stable as $$
  with scores as (select * from public._league_rows(p_league, p_start, p_end))
  select s.user_id, (row_number() over (order by s.points desc, s.total_ms asc, s.days desc, s.user_id))::int
  from scores s
  where s.days >= p_min_days and (select count(*) from scores x where x.days > 0) >= public._podium_min_players()
  order by 2
  limit 3
$$;

-- Coffres du podium des saisons terminées (une fois par saison et par joueur).
drop function if exists public._league_award(uuid, int);
create or replace function public._league_award(p_league uuid) returns int
language plpgsql as $$
declare
  l public.leagues;
  s record;
  w record;
  v_count int := 0;
begin
  select * into l from public.leagues where id = p_league;
  if not found then return 0; end if;
  for s in select * from public.league_seasons where league_id = l.id
             and public._league_end_at(ends_on, l.timezone) <= public._now()
             and public._league_end_at(ends_on, l.timezone) > public._now() - interval '30 days' loop
    for w in select * from public._league_podium(l.id, s.starts_on, s.ends_on, public._league_min_days(l.duration)) loop
      if public._give_chest(w.user_id, (case w.place when 1 then 'gold' when 2 then 'silver' else 'wood' end)::public.chest_tier,
                            'league', l.id || ':' || s.starts_on || ':' || w.place,
                            'league:' || l.id || ':' || s.starts_on) then
        v_count := v_count + 1;
      end if;
    end loop;
  end loop;
  return v_count;
end $$;

create or replace function public.cron_league_podiums() returns int
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  l record;
  v_total int := 0;
begin
  for l in select id from public.leagues loop
    v_total := v_total + public._league_award(l.id);
  end loop;
  return v_total;
end $$;

-- Classement d'une saison (0 : actuelle, -1 : précédente). Garde les champs lus par les anciennes versions de l'app.
drop function if exists public._league_standings_base(uuid, int);
create or replace function public.league_standings(p_league uuid, p_offset int default 0) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  l public.leagues := public._league_for_member(p_league, v_user);
  s public.league_seasons;
  v_today date := public._league_today(l);
  v_status text;
  v_rows jsonb;
  me record;
  v_count int;
begin
  perform public._league_award(l.id);
  select * into s from public.league_seasons where league_id = l.id and season = l.season + least(p_offset, 0);
  if not found then select * into s from public.league_seasons where league_id = l.id and season = l.season; end if;
  v_status := case when s.season < l.season then 'finished'
                   when v_today < s.starts_on then 'upcoming' when v_today > s.ends_on then 'finished' else 'active' end;
  select coalesce(jsonb_agg(row_to_json(t)::jsonb order by t.rank, lower(t.handle)), '[]'::jsonb) into v_rows from (
    select rank() over (order by r.points desc, r.total_ms asc, r.days desc) as rank,
           p.id, p.handle, p.avatar, r.points, r.days, r.total_ms, p.id = v_user as is_me,
           p.id = l.owner_id as is_owner
    from public._league_rows(l.id, s.starts_on, s.ends_on) r join public.profiles p on p.id = r.user_id) t;
  v_count := coalesce(cardinality((select question_ids from public.league_days where league_id = l.id and day = v_today)),
                      l.question_count);
  select * into me from public._league_day_state(l.id, v_today, v_user);
  return jsonb_build_object(
    'id', l.id, 'name', l.name, 'invite_code', l.invite_code, 'is_owner', l.owner_id = v_user,
    -- Compatibilité : « period » et bornes de la saison affichée.
    'period', case l.duration when '1w' then 'week' else 'month' end,
    'start_date', s.starts_on, 'end_date', s.ends_on,
    'season', s.season, 'current_season', l.season, 'has_previous', s.season > 1 or l.season > 1,
    'status', v_status, 'today', v_today, 'timezone', l.timezone,
    'total_days', s.ends_on - s.starts_on + 1,
    'day_index', case when v_status = 'active' then v_today - s.starts_on + 1 end,
    'days_left', case when v_status = 'active' then s.ends_on - v_today end,
    'starts_in', case when v_status = 'upcoming' then s.starts_on - v_today end,
    'ends_at', public._league_end_at(s.ends_on, l.timezone),
    'members', (select count(*) from public.league_members where league_id = l.id),
    'settings', jsonb_build_object('question_count', l.question_count, 'domains', to_jsonb(l.domains),
                                   'difficulty', l.difficulty, 'duration', l.duration, 'max_members', l.max_members),
    'my_today', case when v_status = 'active' and s.season = l.season then jsonb_build_object(
                  'answered', me.answered, 'score', me.score, 'total', v_count,
                  'state', case when me.answered = 0 then 'todo' when me.answered < v_count then 'in_progress' else 'done' end) end,
    'standings', v_rows,
    'podium', jsonb_build_object(
      'min_players', public._podium_min_players(),
      'min_days', public._league_min_days(l.duration),
      'active_players', (select count(*) from jsonb_array_elements(v_rows) e where (e ->> 'days')::int > 0)),
    'my_reward', (select jsonb_build_object('tier', c.tier, 'place', split_part(c.ref, ':', 3)::int)
                  from public.user_chests c
                  where c.user_id = v_user and c.idempotency_key = 'league:' || l.id || ':' || s.starts_on));
end $$;

create or replace function public.leagues_mine() returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  m record;
  l public.leagues;
  v_out jsonb := '[]'::jsonb;
  v_status text;
  v_today date;
  me record;
  v_rank int;
begin
  for m in select league_id from public.league_members where user_id = v_user order by joined_at loop
    perform public._league_award(m.league_id);
    select * into l from public.leagues where id = m.league_id;
    v_status := public._league_status(l);
    v_today := public._league_today(l);
    select * into me from public._league_day_state(l.id, v_today, v_user);
    select r.rank into v_rank from (
      select x.user_id, rank() over (order by x.points desc, x.total_ms asc, x.days desc) as rank
      from public._league_rows(l.id, l.starts_on, l.ends_on) x) r where r.user_id = v_user;
    v_out := v_out || jsonb_build_object(
      'id', l.id, 'name', l.name, 'period', case l.duration when '1w' then 'week' else 'month' end,
      'members', (select count(*) from public.league_members x where x.league_id = l.id),
      'invite_code', l.invite_code, 'status', v_status, 'my_rank', v_rank,
      'days_left', case when v_status = 'active' then l.ends_on - v_today end,
      'starts_in', case when v_status = 'upcoming' then l.starts_on - v_today end,
      'question_count', l.question_count,
      'today_state', case when v_status <> 'active' then null
                          when me.answered = 0 then 'todo' when me.answered < l.question_count then 'in_progress' else 'done' end);
  end loop;
  return v_out;
end $$;

-- ─────────────────────────────────────────── Création, saisons, invitations
create or replace function public._league_code() returns text
language plpgsql volatile as $$
declare v_code text;
begin
  loop
    v_code := public._random_code(8);
    exit when not exists (select 1 from public.leagues where invite_code = v_code);
  end loop;
  return v_code;
end $$;

create or replace function public.league_create(p_name text, p_count int, p_domains text[], p_difficulty text, p_duration text,
                                                p_start_today bool, p_max_members int) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  v_tz text := public._user_tz(v_user);
  v_start date;
  v_domains text[];
  v_id uuid;
begin
  if length(trim(coalesce(p_name, ''))) not between 3 and 40 then raise exception 'invalid_name'; end if;
  if p_count not in (5, 10, 15, 20) then raise exception 'invalid_count'; end if;
  if coalesce(p_difficulty, 'auto') not in ('auto', 'easy', 'medium', 'hard') then raise exception 'invalid_difficulty'; end if;
  if p_duration not in ('1w', '2w', '1m') then raise exception 'invalid_duration'; end if;
  if coalesce(p_max_members, 50) not between 2 and 50 then raise exception 'invalid_max_members'; end if;
  if (select count(*) from public.league_members where user_id = v_user) >= 10 then raise exception 'too_many_leagues'; end if;
  if (select count(*) from public.leagues where owner_id = v_user and created_at > public._now() - interval '1 day') >= 5 then
    raise exception 'rate_limited';
  end if;
  select array_agg(id order by sort) into v_domains from public.domains where is_active and id = any (coalesce(p_domains, '{}'));
  if v_domains is not null and cardinality(v_domains) = (select count(*) from public.domains where is_active) then v_domains := null; end if;
  v_start := (public._now() at time zone v_tz)::date + case when coalesce(p_start_today, true) then 0 else 1 end;
  insert into public.leagues (name, owner_id, period, invite_code, created_at, question_count, domains, difficulty, duration,
                              timezone, max_members, season, starts_on, ends_on)
  values (trim(p_name), v_user, case p_duration when '1w' then 'week' else 'month' end::public.league_period, public._league_code(),
          public._now(), p_count, v_domains, coalesce(p_difficulty, 'auto'), p_duration, v_tz, coalesce(p_max_members, 50), 1,
          v_start, public._league_last_day(v_start, p_duration))
  returning id into v_id;
  insert into public.league_seasons (league_id, season, starts_on, ends_on)
  select id, 1, starts_on, ends_on from public.leagues where id = v_id;
  insert into public.league_members (league_id, user_id, role, joined_at) values (v_id, v_user, 'owner', public._now());
  return public.league_standings(v_id, 0);
end $$;

-- Ancienne signature (versions précédentes de l'app) : 5 questions, tous domaines, début aujourd'hui.
create or replace function public.league_create(p_name text, p_period public.league_period) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  return public.league_create(p_name, 5, null, 'auto', case p_period when 'week' then '1w' else '1m' end, true, 50);
end $$;

-- Nouvelle saison, mêmes membres et réglages (créateur, ligue terminée).
create or replace function public.league_new_season(p_league uuid, p_start_today bool default true) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  l public.leagues := public._league_for_member(p_league, v_user);
  v_start date;
begin
  if l.owner_id <> v_user then raise exception 'forbidden'; end if;
  if public._league_status(l) <> 'finished' then raise exception 'league_not_finished'; end if;
  v_start := public._league_today(l) + case when coalesce(p_start_today, true) then 0 else 1 end;
  update public.leagues set season = season + 1, starts_on = v_start, ends_on = public._league_last_day(v_start, duration)
  where id = l.id returning * into l;
  insert into public.league_seasons (league_id, season, starts_on, ends_on) values (l.id, l.season, l.starts_on, l.ends_on);
  return public.league_standings(l.id, 0);
end $$;

-- Essais de codes : au plus 30 par heure et par joueur (aperçus et adhésions).
create or replace function public._league_code_attempt(p_user uuid) returns bool
language plpgsql as $$
begin
  if (select count(*) from public.league_code_attempts where user_id = p_user and created_at > public._now() - interval '1 hour') >= 30 then
    return false;
  end if;
  insert into public.league_code_attempts (user_id, created_at) values (p_user, public._now());
  return true;
end $$;

-- Aperçu avant de rejoindre (jamais d'erreur : un code faux renvoie found = false, et compte comme un essai).
create or replace function public.league_preview(p_code text) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  l public.leagues;
begin
  if not public._league_code_attempt(v_user) then return jsonb_build_object('found', false, 'error', 'rate_limited'); end if;
  select * into l from public.leagues where invite_code = upper(trim(coalesce(p_code, '')));
  if not found then return jsonb_build_object('found', false, 'error', 'league_not_found'); end if;
  return jsonb_build_object(
    'found', true, 'code', l.invite_code, 'name', l.name,
    'owner', (select handle from public.profiles where id = l.owner_id),
    'members', (select count(*) from public.league_members where league_id = l.id), 'max_members', l.max_members,
    'is_member', public._is_member(l.id, v_user),
    'status', public._league_status(l), 'starts_on', l.starts_on, 'ends_on', l.ends_on,
    'days_left', case when public._league_status(l) = 'active' then l.ends_on - public._league_today(l) end,
    'settings', jsonb_build_object('question_count', l.question_count, 'domains', to_jsonb(l.domains),
                                   'difficulty', l.difficulty, 'duration', l.duration, 'max_members', l.max_members));
end $$;

create or replace function public.league_join(p_code text) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  l public.leagues;
begin
  if (select count(*) from public.league_code_attempts where user_id = v_user and created_at > public._now() - interval '1 hour') >= 30 then
    raise exception 'rate_limited';
  end if;
  select * into l from public.leagues where invite_code = upper(trim(coalesce(p_code, '')));
  if not found then
    perform pg_sleep(0.3);  -- freine les essais de codes au hasard
    raise exception 'league_not_found';
  end if;
  if not public._is_member(l.id, v_user) then
    if (select count(*) from public.league_members where league_id = l.id) >= l.max_members then raise exception 'league_full'; end if;
    if (select count(*) from public.league_members where user_id = v_user) >= 10 then raise exception 'too_many_leagues'; end if;
    insert into public.league_members (league_id, user_id, joined_at) values (l.id, v_user, public._now());
  end if;
  return public.league_standings(l.id, 0);
end $$;

-- Le créateur : nouveau code (l'ancien lien ne marche plus) et retrait d'un membre.
create or replace function public.league_regenerate_code(p_league uuid) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user(); v_code text := public._league_code();
begin
  update public.leagues set invite_code = v_code where id = p_league and owner_id = v_user;
  if not found then raise exception 'forbidden'; end if;
  return jsonb_build_object('invite_code', v_code);
end $$;

create or replace function public.league_kick(p_league uuid, p_user uuid) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user();
begin
  if p_user = v_user or not exists (select 1 from public.leagues where id = p_league and owner_id = v_user) then
    raise exception 'forbidden';
  end if;
  delete from public.league_members where league_id = p_league and user_id = p_user;
end $$;

-- ─────────────────────────────────────────── Droits
revoke execute on function public._league_last_day(date, text), public._league_today(public.leagues),
  public._league_status(public.leagues), public._league_end_at(date, text),
  public._league_day_questions(public.leagues, date), public._league_day_state(uuid, date, uuid),
  public._league_for_member(uuid, uuid), public._league_rows(uuid, date, date), public._league_min_days(text),
  public._league_podium(uuid, date, date, int), public._league_award(uuid), public.cron_league_podiums(),
  public._league_code(), public._league_code_attempt(uuid)
  from public, anon, authenticated;
do $$
declare f text;
begin
  foreach f in array array['league_question(uuid,int)', 'league_answer(uuid,int,jsonb,int)', 'league_day_result(uuid,date)',
                           'league_standings(uuid,int)', 'leagues_mine()',
                           'league_create(text,int,text[],text,text,bool,int)', 'league_create(text,public.league_period)',
                           'league_new_season(uuid,bool)', 'league_preview(text)', 'league_join(text)',
                           'league_regenerate_code(uuid)', 'league_kick(uuid,uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
