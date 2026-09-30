-- Brainlix — 0030 Espace admin : suivi des joueurs, statistiques, modération
-- 1. Journal d'événements de l'app (ouverture, étapes de l'onboarding, partage…), écrit par le joueur lui-même via
--    track_events, liste blanche de noms, taille et débit limités. Aucune donnée ne quitte la base (pas d'outil tiers).
-- 2. Statistiques pour l'admin : joueurs, actifs par jour, rétention J1/J7/J30, entonnoir d'arrivée, économie.
-- 3. Fiche joueur et modération : renommer un pseudo, bannir / débannir (un joueur banni ne peut plus rien faire).
-- Un « jour » est compté à l'heure de Paris.

-- ─────────────────────────────────────────── Journal d'événements
create table public.app_events (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  name        text not null check (name in ('app_open', 'onboarding_step', 'onboarding_done', 'share', 'reminder_optin',
                                              'notif_permission', 'ad_offer', 'ad_view', 'ad_reward', 'interstitial', 'campaign')),
  props       jsonb not null default '{}'::jsonb check (pg_column_size(props) <= 1024),
  app_version text check (length(app_version) <= 20),
  created_at  timestamptz not null default now()
);
create index on public.app_events (name, created_at);
create index on public.app_events (user_id, created_at desc);
alter table public.app_events enable row level security;
revoke all on public.app_events from public, anon, authenticated;

create index if not exists question_attempts_created_at_idx on public.question_attempts (created_at);
create index if not exists profiles_created_at_idx on public.profiles (created_at);

-- Envoi groupé par l'app (au plus 20 événements par appel, 300 par jour et par joueur ; le surplus est ignoré).
create or replace function public.track_events(p_events jsonb) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  e jsonb;
  v_today int;
  v_n int := 0;
begin
  if jsonb_typeof(p_events) <> 'array' then raise exception 'invalid_events'; end if;
  select count(*) into v_today from public.app_events
  where user_id = v_user and created_at > public._now() - interval '1 day';
  for e in select * from jsonb_array_elements(p_events) limit 20 loop
    exit when v_today + v_n >= 300;
    begin
      insert into public.app_events (user_id, name, props, app_version, created_at)
      values (v_user, e ->> 'name', coalesce(e -> 'props', '{}'::jsonb), left(e ->> 'app_version', 20), public._now());
      v_n := v_n + 1;
    exception when check_violation then
      null;  -- nom inconnu ou propriétés trop lourdes : ignoré, sans bloquer les autres
    end;
  end loop;
  return jsonb_build_object('recorded', v_n);
end $$;

-- ─────────────────────────────────────────── Bannissement
alter table public.profiles add column banned_at timestamptz, add column ban_reason text check (length(ban_reason) <= 200);

create or replace function public._is_banned(p_user uuid) returns bool
language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce((select banned_at is not null from public.profiles where id = p_user), false)
$$;

create or replace function public._require_user() returns uuid
language plpgsql stable as $$
declare v uuid := auth.uid();
begin
  if v is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
  if public._is_banned(v) then raise exception 'banned' using errcode = '42501'; end if;
  return v;
end $$;

-- ─────────────────────────────────────────── Outils communs
create or replace function public._paris_day(p_ts timestamptz) returns date
language sql immutable as $$ select (p_ts at time zone 'Europe/Paris')::date $$;

-- Jours d'activité (une ligne par joueur et par jour) : une réponse ou une ouverture de l'app.
create or replace function public._activity_days(p_from date) returns table (user_id uuid, day date)
language sql stable as $$
  select distinct a.user_id, public._paris_day(a.created_at) from public.question_attempts a
  where a.created_at >= (p_from::timestamp at time zone 'Europe/Paris')
  union
  select distinct e.user_id, public._paris_day(e.created_at) from public.app_events e
  where e.name = 'app_open' and e.created_at >= (p_from::timestamp at time zone 'Europe/Paris')
$$;

-- ─────────────────────────────────────────── Statistiques
create or replace function public.admin_kpis(p_days int default 30) returns jsonb
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare
  v_days int := least(greatest(coalesce(p_days, 30), 7), 180);
  v_today date := public._paris_day(public._now());
  v_from date := v_today - (v_days - 1);
begin
  perform public._require_admin();
  create temp table if not exists pg_temp.adm_act (user_id uuid, day date) on commit drop;
  truncate pg_temp.adm_act;
  insert into pg_temp.adm_act select * from public._activity_days(least(v_from, v_today - 60));

  return jsonb_build_object(
    'today', v_today,
    'totals', jsonb_build_object(
      'players', (select count(*) from public.profiles),
      'onboarded', (select count(*) from public.profiles where onboarded_at is not null),
      'linked', (select count(*) from auth.users u join public.profiles p on p.id = u.id where not u.is_anonymous),
      'banned', (select count(*) from public.profiles where banned_at is not null),
      'answers', (select count(*) from public.question_attempts),
      'dau', (select count(distinct user_id) from pg_temp.adm_act where day = v_today),
      'wau', (select count(distinct user_id) from pg_temp.adm_act where day > v_today - 7),
      'mau', (select count(distinct user_id) from pg_temp.adm_act where day > v_today - 30)),
    -- Une ligne par jour : nouveaux joueurs, actifs, 5 du jour finis, parties terminées, réponses.
    'series', (select coalesce(jsonb_agg(jsonb_build_object(
          'day', d.day,
          'new_players', (select count(*) from public.profiles p where public._paris_day(p.created_at) = d.day),
          'active', (select count(distinct user_id) from pg_temp.adm_act a where a.day = d.day),
          'daily_finished', (select count(*) from public.daily_runs r where r.daily_date = d.day and r.status = 'finished'),
          'games', (select count(*) from public.play_sessions s where s.completed_at is not null
                      and public._paris_day(s.completed_at) = d.day),
          'answers', (select count(*) from public.question_attempts q where public._paris_day(q.created_at) = d.day)
        ) order by d.day), '[]'::jsonb)
      from (select generate_series(v_from, v_today, interval '1 day')::date as day) d),
    -- Rétention : part des joueurs revenus exactement N jours après leur arrivée (cohortes assez anciennes).
    'retention', (select jsonb_object_agg(k, jsonb_build_object('cohort', c, 'returned', r,
                                                                  'rate', case when c > 0 then round(r::numeric / c, 3) end))
      from (select k, count(*) c,
                   count(*) filter (where exists (select 1 from pg_temp.adm_act a
                                                  where a.user_id = p.id and a.day = public._paris_day(p.created_at) + k)) r
            from unnest(array[1, 7, 30]) k
            join public.profiles p on public._paris_day(p.created_at) <= v_today - k
                                  and public._paris_day(p.created_at) > v_today - k - 60
            group by k) t),
    -- Entonnoir des joueurs arrivés sur la période.
    'funnel', (select jsonb_build_object(
          'created', count(*),
          'onboarded', count(*) filter (where p.onboarded_at is not null),
          'first_answer', count(*) filter (where exists (select 1 from public.question_attempts a where a.user_id = p.id)),
          'first_daily', count(*) filter (where exists (select 1 from public.daily_runs r where r.user_id = p.id and r.status = 'finished')),
          'came_back', count(*) filter (where exists (select 1 from pg_temp.adm_act a
                                                      where a.user_id = p.id and a.day > public._paris_day(p.created_at))),
          'linked', count(*) filter (where exists (select 1 from auth.users u where u.id = p.id and not u.is_anonymous)))
      from public.profiles p where public._paris_day(p.created_at) >= v_from),
    -- Économie sur 7 jours.
    'economy', jsonb_build_object(
      'seeds_earned', (select coalesce(sum(amount), 0) from public.ledger
                       where currency = 'seeds' and amount > 0 and created_at > public._now() - interval '7 days'),
      'seeds_spent', (select coalesce(-sum(amount), 0) from public.ledger
                      where currency = 'seeds' and amount < 0 and created_at > public._now() - interval '7 days'),
      'by_reason', (select coalesce(jsonb_object_agg(reason, n), '{}'::jsonb) from (
                      select reason, sum(amount) n from public.ledger
                      where currency = 'seeds' and created_at > public._now() - interval '7 days'
                      group by reason order by abs(sum(amount)) desc limit 12) t),
      'chests_opened', (select coalesce(jsonb_object_agg(t, n), '{}'::jsonb) from (
                          select coalesce(contents ->> 'final_tier', tier::text) t, count(*) n from public.user_chests
                          where opened_at > public._now() - interval '7 days' group by 1) x)),
    'domains', (select coalesce(jsonb_agg(jsonb_build_object('domain_id', domain_id, 'answers', n) order by n desc), '[]'::jsonb)
      from (select q.domain_id, count(*) n from public.question_attempts a join public.questions q on q.id = a.question_id
            where a.created_at > public._now() - interval '30 days' group by 1) t),
    'versions', (select coalesce(jsonb_object_agg(v, n), '{}'::jsonb) from (
                   select app_version v, count(distinct user_id) n from public.app_events
                   where name = 'app_open' and app_version is not null and created_at > public._now() - interval '30 days'
                   group by 1) t),
    'events', (select coalesce(jsonb_object_agg(name, n), '{}'::jsonb) from (
                 select name, count(*) n from public.app_events where created_at > public._now() - interval '7 days' group by 1) t));
end $$;

-- ─────────────────────────────────────────── Joueurs
create or replace function public.admin_users(p_search text default null, p_sort text default 'recent',
                                              p_limit int default 50, p_offset int default 0) returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  perform public._require_admin();
  return (with base as (
      select p.id, p.handle, p.created_at, p.onboarded_at, p.streak_current, p.streak_best, p.questions_answered, p.seeds,
             p.xp_total, p.banned_at, p.timezone,
             coalesce(u.is_anonymous, true) as anonymous,
             greatest((select max(a.created_at) from public.question_attempts a where a.user_id = p.id),
                      (select max(e.created_at) from public.app_events e where e.user_id = p.id and e.name = 'app_open')) as last_active
      from public.profiles p left join auth.users u on u.id = p.id
      where p_search is null or p_search = '' or p.handle ilike '%' || p_search || '%' or p.id::text = p_search)
    select jsonb_build_object(
      'total', (select count(*) from base),
      'items', coalesce((select jsonb_agg(to_jsonb(t)) from (
          select * from base
          order by
            case when p_sort = 'active' then last_active end desc nulls last,
            case when p_sort = 'answers' then questions_answered end desc nulls last,
            case when p_sort = 'streak' then streak_current end desc nulls last,
            created_at desc
          limit least(greatest(p_limit, 1), 200) offset greatest(p_offset, 0)) t), '[]'::jsonb)));
end $$;

create or replace function public.admin_user(p_user uuid) returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare p public.profiles;
begin
  perform public._require_admin();
  select * into p from public.profiles where id = p_user;
  if not found then raise exception 'user_not_found'; end if;
  return jsonb_build_object(
    'profile', to_jsonb(p) - 'referral_code',
    'anonymous', coalesce((select is_anonymous from auth.users where id = p_user), true),
    'providers', (select coalesce(jsonb_agg(distinct provider), '[]'::jsonb) from auth.identities where user_id = p_user),
    'skills', (select coalesce(jsonb_agg(jsonb_build_object('domain_id', s.scope_id, 'cote', public._cote(s.mu), 'n', s.n,
                                                            'correct', s.correct) order by s.n desc), '[]'::jsonb)
               from public.user_skills s where s.user_id = p_user and s.is_domain),
    'games', (select coalesce(jsonb_agg(t order by t.created_at desc), '[]'::jsonb) from (
                select s.created_at, s.mode, s.domain_id, s.completed_at is not null as completed,
                       (select count(*) from public.question_attempts a where a.session_id = s.id) as answers,
                       (select count(*) filter (where a.is_correct) from public.question_attempts a where a.session_id = s.id) as correct
                from public.play_sessions s where s.user_id = p_user order by s.created_at desc limit 20) t),
    'dailies', (select coalesce(jsonb_agg(jsonb_build_object('date', r.daily_date, 'status', r.status, 'score', r.score)
                                          order by r.daily_date desc), '[]'::jsonb)
                from (select * from public.daily_runs where user_id = p_user order by daily_date desc limit 14) r),
    'ledger', (select coalesce(jsonb_agg(jsonb_build_object('at', l.created_at, 'currency', l.currency, 'amount', l.amount,
                                                            'reason', l.reason) order by l.created_at desc), '[]'::jsonb)
               from (select * from public.ledger where user_id = p_user order by created_at desc limit 25) l),
    'chests', jsonb_build_object(
      'waiting', (select count(*) from public.user_chests where user_id = p_user and opened_at is null),
      'opened', (select count(*) from public.user_chests where user_id = p_user and opened_at is not null)),
    'devices', (select count(*) from public.user_devices where user_id = p_user),
    'reports', (select count(*) from public.question_reports where user_id = p_user),
    'events', (select coalesce(jsonb_agg(jsonb_build_object('at', e.created_at, 'name', e.name, 'props', e.props,
                                                            'app_version', e.app_version) order by e.created_at desc), '[]'::jsonb)
               from (select * from public.app_events where user_id = p_user order by created_at desc limit 30) e));
end $$;

-- Renommer un pseudo (choquant, usurpation…) : même validation que pour le joueur, sans le délai de 30 jours.
create or replace function public.admin_user_rename(p_user uuid, p_handle text) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  perform public._require_admin();
  if p_handle !~ '^[A-Za-z0-9_]{3,20}$' then raise exception 'invalid_handle'; end if;
  if exists (select 1 from public.profiles where lower(handle) = lower(p_handle) and id <> p_user) then
    raise exception 'handle_taken';
  end if;
  update public.profiles set handle = p_handle where id = p_user;
  if not found then raise exception 'user_not_found'; end if;
  return jsonb_build_object('handle', p_handle);
end $$;

create or replace function public.admin_user_ban(p_user uuid, p_reason text default null) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  perform public._require_admin();
  if exists (select 1 from public.app_admins where user_id = p_user) then raise exception 'cannot_ban_admin'; end if;
  update public.profiles set banned_at = coalesce(banned_at, public._now()), ban_reason = left(p_reason, 200) where id = p_user;
  if not found then raise exception 'user_not_found'; end if;
  -- Il quitte ses ligues : il ne doit plus apparaître chez les autres.
  delete from public.league_members where user_id = p_user;
  return jsonb_build_object('banned', true);
end $$;

create or replace function public.admin_user_unban(p_user uuid) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  perform public._require_admin();
  update public.profiles set banned_at = null, ban_reason = null where id = p_user;
  if not found then raise exception 'user_not_found'; end if;
  return jsonb_build_object('banned', false);
end $$;

-- ─────────────────────────────────────────── Droits
-- _is_banned reste exécutable : _require_user (appelé avec les droits du joueur) en a besoin.
revoke execute on function public._activity_days(date), public._paris_day(timestamptz) from public, anon, authenticated;
revoke execute on function public.track_events(jsonb), public.admin_kpis(int), public.admin_users(text, text, int, int),
  public.admin_user(uuid), public.admin_user_rename(uuid, text), public.admin_user_ban(uuid, text), public.admin_user_unban(uuid)
  from public, anon;
grant execute on function public.track_events(jsonb), public.admin_kpis(int), public.admin_users(text, text, int, int),
  public.admin_user(uuid), public.admin_user_rename(uuid, text), public.admin_user_ban(uuid, text), public.admin_user_unban(uuid)
  to authenticated;
