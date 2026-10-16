-- ─────────────────────────────────────────── 0058 · Ligues ouvertes (1.2)
-- Nouveau format de ligue, « ouverte », à côté du « quiz du jour » (inchangé) :
--   · le créateur choisit nom, domaines, difficulté, questions par quiz (5 à 20) et 1 à 10 quiz au départ ;
--   · les quiz sont les mêmes pour tout le monde ; chacun se joue une fois, quand on veut, sans chrono ;
--   · classement général = total de bonnes réponses ; à égalité, le premier à avoir fini passe devant ;
--   · le créateur ajoute un quiz quand il veut (30 au plus) ; pas de fin, sauf durée choisie ou « Terminer la ligue ».
-- Récompenses (tous formats) : plus de coffres (donc plus de neurones). Un podium (1er, 2e, 3e) gardé dans
-- league_results, et le trophée « Vainqueur de ligue » pour le 1er, dès 3 joueurs.
-- Technique : un quiz n d'une ligue ouverte est rangé comme un « jour » fictif (2000-01-01 + n) dans league_days et
-- league_answers ; les fonctions du quiz du jour refusent les ligues ouvertes, et inversement.

-- ─────────────────────────────────────────── Schéma
alter table public.leagues
  add column format   text not null default 'daily' check (format in ('daily', 'open')),
  add column ended_at timestamptz;
alter table public.leagues drop constraint leagues_duration_check;
alter table public.leagues add constraint leagues_duration_check check (duration in ('1w', '2w', '1m', 'open'));

create table public.league_results (
  league_id uuid not null references public.leagues(id) on delete cascade,
  season    int  not null,
  user_id   uuid not null references public.profiles(id) on delete cascade,
  place     int  not null check (place between 1 and 3),
  points    int  not null,
  awarded_at timestamptz not null default now(),
  primary key (league_id, season, user_id)
);
alter table public.league_results enable row level security;
revoke all on public.league_results from public, anon, authenticated;

insert into public.achievements (id, name, description, reward_seeds, sort, category)
values ('league_winner', 'Vainqueur de ligue', 'Finir 1er d''une ligue d''au moins 3 joueurs.', 0, 140, 'exploit')
on conflict (id) do nothing;

-- Podium dès 3 joueurs (4 avant).
create or replace function public._podium_min_players() returns int language sql immutable set search_path = public, pg_temp as $$ select 3 $$;

create or replace function public._league_quiz_day(p_quiz int) returns date
language sql immutable set search_path = public, pg_temp as $$ select date '2000-01-01' + p_quiz $$;

create or replace function public._league_quiz_count(p_league uuid) returns int
language sql stable set search_path = public, pg_temp as $$
  select count(*)::int from public.league_days where league_id = p_league and day < date '2001-01-01'
$$;

-- Terminée : à la main (ended_at) ou après le dernier jour.
create or replace function public._league_status(l public.leagues) returns text
language sql stable set search_path = public, extensions, pg_temp as $$
  select case when l.ended_at is not null then 'finished'
              when public._league_today(l) < l.starts_on then 'upcoming'
              when public._league_today(l) > l.ends_on then 'finished' else 'active' end
$$;

-- ─────────────────────────────────────────── Classement d'une ligue ouverte
create or replace function public._league_open_rows(p_league uuid)
returns table (user_id uuid, points int, answered int, quizzes_done int, finished_at timestamptz)
language sql stable set search_path = public, pg_temp as $$
  select m.user_id,
         count(a.*) filter (where a.is_correct)::int,
         count(a.*) filter (where a.answered_at is not null)::int,
         (select count(*)::int from public.league_days d
          where d.league_id = p_league and d.day < date '2001-01-01'
            and (select count(*) from public.league_answers x where x.league_id = p_league and x.day = d.day
                   and x.user_id = m.user_id and x.answered_at is not null) >= cardinality(d.question_ids)),
         max(a.answered_at)
  from public.league_members m
  left join public.league_answers a on a.league_id = m.league_id and a.user_id = m.user_id and a.day < date '2001-01-01'
  where m.league_id = p_league
  group by m.user_id
$$;

create or replace function public._league_open_podium(p_league uuid)
returns table (user_id uuid, place int, points int)
language sql stable set search_path = public, pg_temp as $$
  with r as (select * from public._league_open_rows(p_league))
  select r.user_id, (row_number() over (order by r.points desc, r.finished_at asc, r.user_id))::int, r.points
  from r
  where r.answered > 0 and (select count(*) from r x where x.answered > 0) >= public._podium_min_players()
  order by 2
  limit 3
$$;

-- Podium d'une saison, pour l'affichage.
create or replace function public._league_results_json(p_league uuid, p_season int) returns jsonb
language sql stable set search_path = public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object('place', r.place, 'id', p.id, 'handle', p.handle, 'points', r.points)
                            order by r.place), '[]'::jsonb)
  from public.league_results r join public.profiles p on p.id = r.user_id
  where r.league_id = p_league and r.season = p_season
$$;

-- ─────────────────────────────────────────── Récompenses : podium et trophée (plus de coffres)
create or replace function public._league_award(p_league uuid) returns int
language plpgsql set search_path = public, extensions, pg_temp as $$
declare
  l public.leagues;
  s record;
  w record;
  v_count int := 0;
begin
  select * into l from public.leagues where id = p_league;
  if not found then return 0; end if;
  for s in select * from public.league_seasons ls where ls.league_id = l.id
             and ((l.ended_at is not null and ls.season = l.season and l.ended_at > public._now() - interval '30 days')
                  or (public._league_end_at(ls.ends_on, l.timezone) <= public._now()
                      and public._league_end_at(ls.ends_on, l.timezone) > public._now() - interval '30 days')) loop
    for w in
      select o.user_id, o.place, o.points from public._league_open_podium(l.id) o where l.format = 'open'
      union all
      select d.user_id, d.place, r.points
      from public._league_podium(l.id, s.starts_on, s.ends_on, public._league_min_days(l.duration)) d
      join public._league_rows(l.id, s.starts_on, s.ends_on) r on r.user_id = d.user_id
      where l.format = 'daily'
    loop
      insert into public.league_results (league_id, season, user_id, place, points, awarded_at)
      values (l.id, s.season, w.user_id, w.place, w.points, public._now())
      on conflict do nothing;
      if found then
        v_count := v_count + 1;
        if w.place = 1 then perform public._unlock(w.user_id, 'league_winner'); end if;
      end if;
    end loop;
  end loop;
  return v_count;
end $$;

-- ─────────────────────────────────────────── Création, quiz, fin
create or replace function public.league_create_open(p_name text, p_count int, p_domains text[], p_difficulty text,
                                                     p_quizzes int, p_days int, p_max_members int) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  v_tz text := public._user_tz(v_user);
  v_today date := (public._now() at time zone v_tz)::date;
  v_domains text[];
  v_id uuid;
  l public.leagues;
begin
  if length(trim(coalesce(p_name, ''))) not between 3 and 40 then raise exception 'invalid_name'; end if;
  if p_count not in (5, 10, 15, 20) then raise exception 'invalid_count'; end if;
  if coalesce(p_difficulty, 'auto') not in ('auto', 'easy', 'medium', 'hard') then raise exception 'invalid_difficulty'; end if;
  if coalesce(p_quizzes, 0) not between 1 and 10 then raise exception 'invalid_quizzes'; end if;
  if p_days is not null and p_days not between 1 and 90 then raise exception 'invalid_duration'; end if;
  if coalesce(p_max_members, 50) not between 2 and 50 then raise exception 'invalid_max_members'; end if;
  if (select count(*) from public.league_members where user_id = v_user) >= 10 then raise exception 'too_many_leagues'; end if;
  if (select count(*) from public.leagues where owner_id = v_user and created_at > public._now() - interval '1 day') >= 5 then
    raise exception 'rate_limited';
  end if;
  select array_agg(id order by sort) into v_domains from public.domains where is_active and id = any (coalesce(p_domains, '{}'));
  if v_domains is not null and cardinality(v_domains) = (select count(*) from public.domains where is_active) then v_domains := null; end if;
  insert into public.leagues (name, owner_id, period, invite_code, created_at, question_count, domains, difficulty, duration,
                              timezone, max_members, season, starts_on, ends_on, format)
  values (trim(p_name), v_user, 'month', public._league_code(), public._now(), p_count, v_domains, coalesce(p_difficulty, 'auto'),
          'open', v_tz, coalesce(p_max_members, 50), 1, v_today,
          case when p_days is null then date '2999-12-31' else v_today + p_days - 1 end, 'open')
  returning * into l;
  v_id := l.id;
  insert into public.league_seasons (league_id, season, starts_on, ends_on) values (v_id, 1, l.starts_on, l.ends_on);
  insert into public.league_members (league_id, user_id, role, joined_at) values (v_id, v_user, 'owner', public._now());
  for n in 1 .. p_quizzes loop
    perform public._league_day_questions(l, public._league_quiz_day(n));
  end loop;
  return public.league_standings(v_id, 0);
end $$;

create or replace function public.league_add_quiz(p_league uuid) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  l public.leagues := public._league_for_member(p_league, v_user);
  v_n int;
begin
  if l.owner_id <> v_user then raise exception 'forbidden'; end if;
  if l.format <> 'open' then raise exception 'league_not_open'; end if;
  if public._league_status(l) <> 'active' then raise exception 'league_not_active'; end if;
  v_n := public._league_quiz_count(l.id);
  if v_n >= 30 then raise exception 'too_many_quizzes'; end if;
  perform public._league_day_questions(l, public._league_quiz_day(v_n + 1));
  return public.league_standings(l.id, 0);
end $$;

-- Le créateur termine la ligue : classement final, podium et trophée tout de suite.
create or replace function public.league_end(p_league uuid) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  l public.leagues := public._league_for_member(p_league, v_user);
  v_today date;
begin
  if l.owner_id <> v_user then raise exception 'forbidden'; end if;
  if l.format <> 'open' then raise exception 'league_not_open'; end if;
  if public._league_status(l) <> 'active' then raise exception 'league_not_active'; end if;
  v_today := greatest(public._league_today(l), l.starts_on);
  update public.leagues set ended_at = public._now(), ends_on = v_today where id = l.id;
  update public.league_seasons set ends_on = v_today where league_id = l.id and season = l.season;
  perform public._league_award(l.id);
  return public.league_standings(l.id, 0);
end $$;

-- ─────────────────────────────────────────── Jouer un quiz (sans chrono, une fois, quand on veut)
create or replace function public.league_quiz_question(p_league uuid, p_quiz int, p_position int) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  l public.leagues := public._league_for_member(p_league, v_user);
  v_day date := public._league_quiz_day(p_quiz);
  v_ids uuid[];
  st record;
  q public.questions;
begin
  if l.format <> 'open' then raise exception 'league_not_open'; end if;
  if public._league_status(l) <> 'active' then raise exception 'league_not_active'; end if;
  select question_ids into v_ids from public.league_days where league_id = l.id and day = v_day;
  if v_ids is null or p_quiz < 1 then raise exception 'quiz_not_found'; end if;
  select * into st from public._league_day_state(l.id, v_day, v_user);
  if p_position <> st.answered + 1 or p_position > cardinality(v_ids) then raise exception 'league_out_of_order'; end if;
  insert into public.league_answers (league_id, day, user_id, position, question_id, served_at)
  values (l.id, v_day, v_user, p_position, v_ids[p_position], public._now())
  on conflict (league_id, day, user_id, position) do nothing;
  select * into q from public.questions where id = v_ids[p_position];
  return public._question_public(q, l.id::text || v_day)
         || jsonb_build_object('position', p_position, 'total', cardinality(v_ids), 'quiz', p_quiz);
end $$;

create or replace function public.league_quiz_answer(p_league uuid, p_quiz int, p_position int, p_given jsonb) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  l public.leagues := public._league_for_member(p_league, v_user);
  v_day date := public._league_quiz_day(p_quiz);
  a public.league_answers;
  q public.questions;
  v_ms int;
  v_res jsonb;
  v_total int;
begin
  if l.format <> 'open' then raise exception 'league_not_open'; end if;
  select * into a from public.league_answers
  where league_id = l.id and day = v_day and user_id = v_user and position = p_position for update;
  if not found then raise exception 'league_not_served'; end if;
  select * into q from public.questions where id = a.question_id;
  v_total := cardinality((select question_ids from public.league_days where league_id = l.id and day = v_day));
  if a.answered_at is not null then
    return jsonb_build_object('position', p_position, 'is_correct', a.is_correct, 'duplicate', true, 'counted_ms', a.counted_ms,
                              'finished', p_position = v_total) || public._question_reveal(q);
  end if;
  if public._league_status(l) <> 'active' then raise exception 'league_not_active'; end if;
  -- Pas de chrono : le temps est seulement noté (statistiques), il ne compte pas dans le classement.
  v_ms := least(greatest(floor(extract(epoch from public._now() - a.served_at) * 1000)::int, 300), 120000);
  v_res := public._record_attempt(v_user, q.id, p_given, v_ms, 'challenge', l.id,
                                  md5(l.id::text || ':' || v_day || ':' || v_user || ':' || p_position)::uuid, false);
  update public.league_answers set answered_at = public._now(), given = p_given,
    is_correct = (v_res ->> 'is_correct')::bool, counted_ms = v_ms
  where league_id = l.id and day = v_day and user_id = v_user and position = p_position;
  if (v_res ->> 'is_correct')::bool then
    perform public._grant_capped(v_user, 'xp', 5, 300, 'league_correct', l.id::text,
                                 'league_correct:' || l.id || ':' || v_day || ':' || p_position);
  end if;
  return jsonb_build_object('position', p_position, 'is_correct', (v_res ->> 'is_correct')::bool, 'duplicate', false,
                            'counted_ms', v_ms, 'finished', p_position = v_total,
                            'error_transition', v_res -> 'error_transition')
         || public._question_reveal(q);
end $$;

-- Résultat d'un quiz : mes réponses ; les scores des autres une fois mon quiz fini (ou la ligue terminée).
create or replace function public.league_quiz_result(p_league uuid, p_quiz int) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  l public.leagues := public._league_for_member(p_league, v_user);
  v_day date := public._league_quiz_day(p_quiz);
  v_total int := cardinality((select question_ids from public.league_days where league_id = l.id and day = v_day));
  me record;
  v_open bool;
begin
  if l.format <> 'open' then raise exception 'league_not_open'; end if;
  if v_total is null then raise exception 'quiz_not_found'; end if;
  select * into me from public._league_day_state(l.id, v_day, v_user);
  v_open := me.answered >= v_total or public._league_status(l) = 'finished';
  return jsonb_build_object(
    'day', v_day, 'quiz', p_quiz, 'total', v_total,
    'me', jsonb_build_object('answered', me.answered, 'score', me.score, 'total_ms', 0),
    'my_answers', coalesce((select jsonb_agg(jsonb_build_object('position', position, 'is_correct', is_correct,
                                                                'counted_ms', 0) order by position)
                            from public.league_answers
                            where league_id = l.id and day = v_day and user_id = v_user and answered_at is not null), '[]'::jsonb),
    'members', case when v_open then (select coalesce(jsonb_agg(jsonb_build_object(
                  'id', p.id, 'handle', p.handle, 'is_me', p.id = v_user,
                  'answered', s.answered, 'score', s.score, 'total_ms', 0)
                  order by s.score desc, s.answered desc, lower(p.handle)), '[]'::jsonb)
                from public.league_members m join public.profiles p on p.id = m.user_id
                cross join lateral public._league_day_state(l.id, v_day, m.user_id) s
                where m.league_id = l.id) end);
end $$;

-- ─────────────────────────────────────────── Classement (ligue ouverte)
create or replace function public._league_open_standings(l public.leagues, p_user uuid) returns jsonb
language plpgsql set search_path = public, pg_temp as $$
declare
  v_today date := public._league_today(l);
  v_status text := public._league_status(l);
  v_open_ended bool := l.ends_on >= date '2999-01-01';
  v_rows jsonb;
begin
  perform public._league_award(l.id);
  select coalesce(jsonb_agg(row_to_json(t)::jsonb order by t.rank, lower(t.handle)), '[]'::jsonb) into v_rows from (
    select rank() over (order by r.points desc, r.finished_at asc nulls last) as rank,
           p.id, p.handle, p.avatar, r.points, r.quizzes_done as days, 0 as total_ms, r.answered, r.quizzes_done,
           p.id = p_user as is_me, p.id = l.owner_id as is_owner
    from public._league_open_rows(l.id) r join public.profiles p on p.id = r.user_id) t;
  return jsonb_build_object(
    'id', l.id, 'name', l.name, 'invite_code', l.invite_code, 'is_owner', l.owner_id = p_user,
    'format', 'open', 'period', 'month', 'start_date', l.starts_on, 'end_date', l.ends_on, 'open_ended', v_open_ended,
    'season', l.season, 'current_season', l.season, 'has_previous', false,
    'status', v_status, 'today', v_today, 'timezone', l.timezone,
    'days_left', case when v_status = 'active' and not v_open_ended then l.ends_on - v_today end,
    'ends_at', case when not v_open_ended and l.ended_at is null then public._league_end_at(l.ends_on, l.timezone) end,
    'ended_at', l.ended_at,
    'members', (select count(*) from public.league_members where league_id = l.id),
    'settings', jsonb_build_object('question_count', l.question_count, 'domains', to_jsonb(l.domains),
                                   'difficulty', l.difficulty, 'duration', 'open', 'max_members', l.max_members),
    'quizzes', (select coalesce(jsonb_agg(jsonb_build_object(
                  'n', (d.day - date '2000-01-01'), 'total', cardinality(d.question_ids),
                  'answered', s.answered, 'score', s.score,
                  'state', case when s.answered = 0 then 'todo' when s.answered < cardinality(d.question_ids) then 'in_progress'
                                else 'done' end) order by d.day), '[]'::jsonb)
                from public.league_days d cross join lateral public._league_day_state(l.id, d.day, p_user) s
                where d.league_id = l.id and d.day < date '2001-01-01'),
    'quiz_max', 30,
    'standings', v_rows,
    'podium', jsonb_build_object(
      'min_players', public._podium_min_players(), 'min_days', 0,
      'active_players', (select count(*) from jsonb_array_elements(v_rows) e where (e ->> 'answered')::int > 0)),
    'results', public._league_results_json(l.id, l.season),
    'my_place', (select place from public.league_results where league_id = l.id and season = l.season and user_id = p_user));
end $$;

-- ─────────────────────────────────────────── Fonctions existantes adaptées
do $$
declare v_old text; v_new text;
begin
  -- Classement : une ligue ouverte a le sien ; le podium (places) remplace les coffres.
  v_old := pg_get_functiondef('public.league_standings(uuid, int)'::regprocedure);
  v_new := replace(v_old, $o$begin
  perform public._league_award(l.id);$o$, $n$begin
  if l.format = 'open' then return public._league_open_standings(l, v_user); end if;
  perform public._league_award(l.id);$n$);
  v_new := replace(v_new, $o$'my_reward', (select$o$,
    $n$'format', 'daily', 'results', public._league_results_json(l.id, s.season),
    'my_place', (select place from public.league_results r where r.league_id = l.id and r.season = s.season and r.user_id = v_user),
    'my_reward', (select$n$);
  if (length(v_new) - length(v_old)) < 200 then raise exception '0058: league_standings inchangée'; end if;
  execute v_new;

  -- Quiz du jour : pas pour une ligue ouverte.
  v_old := pg_get_functiondef('public.league_question(uuid, int)'::regprocedure);
  v_new := replace(v_old, $o$if public._league_status(l) <> 'active' then raise exception 'league_not_active'; end if;$o$,
    $n$if l.format = 'open' then raise exception 'league_open'; end if;
  if public._league_status(l) <> 'active' then raise exception 'league_not_active'; end if;$n$);
  if v_new = v_old then raise exception '0058: league_question inchangée'; end if;
  execute v_new;

  v_old := pg_get_functiondef('public.league_new_season(uuid, bool)'::regprocedure);
  v_new := replace(v_old, $o$if l.owner_id <> v_user then raise exception 'forbidden'; end if;$o$,
    $n$if l.owner_id <> v_user then raise exception 'forbidden'; end if;
  if l.format = 'open' then raise exception 'league_open'; end if;$n$);
  if v_new = v_old then raise exception '0058: league_new_season inchangée'; end if;
  execute v_new;

  v_old := pg_get_functiondef('public.league_preview(text)'::regprocedure);
  v_new := replace(v_old, $o$'found', true, 'code', l.invite_code,$o$,
    $n$'found', true, 'format', l.format, 'quizzes', public._league_quiz_count(l.id),
    'open_ended', l.format = 'open' and l.ends_on >= date '2999-01-01', 'code', l.invite_code,$n$);
  if v_new = v_old then raise exception '0058: league_preview inchangée'; end if;
  execute v_new;

  -- Rappels : seulement le quiz du jour ; la fin d'une ligue ouverte n'envoie pas l'avis « saison terminée ».
  v_old := pg_get_functiondef('public.cron_league_notifications()'::regprocedure);
  v_new := replace(v_old, $o$where public._league_status(l) = 'active'$o$,
                          $n$where public._league_status(l) = 'active' and l.format = 'daily'$n$);
  v_new := replace(v_new, $o$where public._league_end_at(s.ends_on, l.timezone) <= public._now()$o$,
                          $n$where l.format = 'daily' and public._league_end_at(s.ends_on, l.timezone) <= public._now()$n$);
  if (length(v_new) - length(v_old)) <> 2 * length(' and l.format = ''daily''') then
    raise exception '0058: cron_league_notifications inchangée';
  end if;
  execute v_new;
end $$;

-- Mes ligues : le format, et pour une ligue ouverte, s'il reste un quiz à jouer.
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
  v_state text;
  v_quizzes int;
begin
  for m in select league_id from public.league_members where user_id = v_user order by joined_at loop
    perform public._league_award(m.league_id);
    select * into l from public.leagues where id = m.league_id;
    v_status := public._league_status(l);
    v_today := public._league_today(l);
    v_quizzes := null;
    if l.format = 'open' then
      v_quizzes := public._league_quiz_count(l.id);
      select r.rank into v_rank from (
        select x.user_id, rank() over (order by x.points desc, x.finished_at asc nulls last) as rank
        from public._league_open_rows(l.id) x) r where r.user_id = v_user;
      select case when v_status <> 'active' then null
                  when count(*) filter (where s.answered < cardinality(d.question_ids)) = 0 then 'done'
                  when count(*) filter (where s.answered > 0 and s.answered < cardinality(d.question_ids)) > 0 then 'in_progress'
                  else 'todo' end
      into v_state
      from public.league_days d cross join lateral public._league_day_state(l.id, d.day, v_user) s
      where d.league_id = l.id and d.day < date '2001-01-01';
    else
      select * into me from public._league_day_state(l.id, v_today, v_user);
      select r.rank into v_rank from (
        select x.user_id, rank() over (order by x.points desc, x.total_ms asc, x.days desc) as rank
        from public._league_rows(l.id, l.starts_on, l.ends_on) x) r where r.user_id = v_user;
      v_state := case when v_status <> 'active' then null
                      when me.answered = 0 then 'todo' when me.answered < l.question_count then 'in_progress' else 'done' end;
    end if;
    v_out := v_out || jsonb_build_object(
      'id', l.id, 'name', l.name, 'period', case l.duration when '1w' then 'week' else 'month' end,
      'format', l.format, 'quizzes', v_quizzes,
      'members', (select count(*) from public.league_members x where x.league_id = l.id),
      'invite_code', l.invite_code, 'status', v_status, 'my_rank', v_rank,
      'days_left', case when v_status = 'active' and l.ends_on < date '2999-01-01' then l.ends_on - v_today end,
      'starts_in', case when v_status = 'upcoming' then l.starts_on - v_today end,
      'question_count', l.question_count,
      'today_state', v_state);
  end loop;
  return v_out;
end $$;

-- ─────────────────────────────────────────── Droits
revoke execute on function public._league_quiz_day(int), public._league_quiz_count(uuid), public._league_open_rows(uuid),
  public._league_open_podium(uuid), public._league_results_json(uuid, int), public._league_award(uuid),
  public._league_open_standings(public.leagues, uuid), public._league_status(public.leagues)
  from public, anon, authenticated;
do $$
declare f text;
begin
  foreach f in array array['league_create_open(text,int,text[],text,int,int,int)', 'league_add_quiz(uuid)', 'league_end(uuid)',
                           'league_quiz_question(uuid,int,int)', 'league_quiz_answer(uuid,int,int,jsonb)',
                           'league_quiz_result(uuid,int)', 'leagues_mine()'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
