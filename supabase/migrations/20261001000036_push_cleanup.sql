-- Brainlix — 0036 Notifications push et nettoyage des comptes anonymes abandonnés
-- 1. Notifications push (Apple) : jetons des appareils, file d'envoi, envoi par la fonction Edge `push-send`
--    (appelée chaque minute par pg_cron tant qu'il reste des notifications dues).
--    Envoyées : duel reçu, défi par lien relevé, duel terminé, demande d'ami reçue / acceptée, quiz de la ligue à faire
--    (19 h, heure du joueur), ligue terminée (classement final).
--    Règles : interrupteurs « Duels et amis » et « Ligues » ; rien entre 22 h et 8 h (reporté à 8 h) ; 5 par jour au plus.
-- 2. Comptes anonymes jamais terminés (onboarding) et inactifs depuis 7 jours : supprimés chaque nuit.
-- 3. Admin : la liste des joueurs montre par défaut les vrais comptes.

-- ─────────────────────────────────────────── Préférences
alter table public.profiles
  add column notif_social  bool not null default true,
  add column notif_leagues bool not null default true;

do $$
declare v_old text; v_new text;
begin
  v_old := pg_get_functiondef('public.profile_me()'::regprocedure);
  v_new := replace(v_old, '''created_at'', p.created_at)',
                   '''created_at'', p.created_at, ''notif_social'', p.notif_social, ''notif_leagues'', p.notif_leagues)');
  if v_new = v_old then raise exception '0036: profile_me inchangée'; end if;
  execute v_new;
  v_old := pg_get_functiondef('public.profile_update(jsonb)'::regprocedure);
  v_new := replace(v_old, '    notif_reminder  = coalesce((p ->> ''notif_reminder'')::bool, notif_reminder)',
                   '    notif_reminder  = coalesce((p ->> ''notif_reminder'')::bool, notif_reminder),
    notif_social    = coalesce((p ->> ''notif_social'')::bool, notif_social),
    notif_leagues   = coalesce((p ->> ''notif_leagues'')::bool, notif_leagues)');
  if v_new = v_old then raise exception '0036: profile_update inchangée'; end if;
  execute v_new;
end $$;

-- ─────────────────────────────────────────── Jetons et file d'envoi
create table public.push_tokens (
  token       text primary key check (length(token) between 32 and 200),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  environment text not null default 'production' check (environment in ('production', 'sandbox')),
  updated_at  timestamptz not null default now()
);
create index on public.push_tokens (user_id);

create table public.push_outbox (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  category    text not null check (category in ('social', 'leagues')),
  title       text not null,
  body        text not null,
  data        jsonb not null default '{}'::jsonb,
  dedupe_key  text not null unique,
  created_at  timestamptz not null default now(),
  local_day   date not null,
  send_after  timestamptz not null,
  claimed_at  timestamptz,
  sent_at     timestamptz,
  error       text
);
create index on public.push_outbox (send_after) where claimed_at is null;
create index on public.push_outbox (user_id, local_day);
alter table public.push_tokens enable row level security;
alter table public.push_outbox enable row level security;
revoke all on public.push_tokens, public.push_outbox from public, anon, authenticated;

create or replace function public.push_register(p_token text, p_environment text default 'production') returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user();
begin
  if p_token !~ '^[0-9a-fA-F]{32,200}$' then raise exception 'invalid_token'; end if;
  insert into public.push_tokens (token, user_id, environment, updated_at)
  values (lower(p_token), v_user, case when p_environment = 'sandbox' then 'sandbox' else 'production' end, public._now())
  on conflict (token) do update set user_id = v_user, environment = excluded.environment, updated_at = public._now();
end $$;

create or replace function public.push_unregister(p_token text) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  delete from public.push_tokens where token = lower(p_token) and user_id = public._require_user();
end $$;

-- Mise en file : préférences, heures calmes (22 h – 8 h, heure du joueur), 5 par jour, jamais deux fois (clé).
create or replace function public._push(p_user uuid, p_category text, p_title text, p_body text, p_data jsonb, p_key text)
returns void language plpgsql as $$
declare
  p public.profiles;
  v_tz text;
  v_local timestamp;
  v_send timestamptz := public._now();
begin
  select * into p from public.profiles where id = p_user;
  if not found or p.banned_at is not null then return; end if;
  if (p_category = 'social' and not p.notif_social) or (p_category = 'leagues' and not p.notif_leagues) then return; end if;
  if not exists (select 1 from public.push_tokens where user_id = p_user) then return; end if;
  v_tz := coalesce(p.timezone, 'Europe/Paris');
  v_local := public._now() at time zone v_tz;
  if extract(hour from v_local) >= 22 then
    v_send := ((v_local::date + 1) + time '08:00') at time zone v_tz;
  elsif extract(hour from v_local) < 8 then
    v_send := (v_local::date + time '08:00') at time zone v_tz;
  end if;
  if (select count(*) from public.push_outbox where user_id = p_user and local_day = (v_send at time zone v_tz)::date) >= 5 then
    return;
  end if;
  insert into public.push_outbox (user_id, category, title, body, data, dedupe_key, created_at, local_day, send_after)
  values (p_user, p_category, left(p_title, 80), left(p_body, 200), coalesce(p_data, '{}'::jsonb), p_key, public._now(),
          (v_send at time zone v_tz)::date, v_send)
  on conflict (dedupe_key) do nothing;
end $$;

-- Pour la fonction d'envoi (clé de service) : prend les notifications dues, avec les jetons du joueur.
create or replace function public.push_claim(p_limit int default 100) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v jsonb;
begin
  with due as (
    select id from public.push_outbox
    where claimed_at is null and send_after <= public._now() and created_at > public._now() - interval '2 days'
    order by send_after limit least(greatest(p_limit, 1), 500)
    for update skip locked
  ), claimed as (
    update public.push_outbox o set claimed_at = public._now() from due where o.id = due.id returning o.*
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', c.id, 'title', c.title, 'body', c.body, 'data', c.data,
      'tokens', (select coalesce(jsonb_agg(jsonb_build_object('token', t.token, 'environment', t.environment)), '[]'::jsonb)
                 from public.push_tokens t where t.user_id = c.user_id))), '[]'::jsonb)
  into v from claimed c;
  return v;
end $$;

create or replace function public.push_done(p_id bigint, p_error text default null) returns void
language sql security definer set search_path = public, pg_temp as $$
  update public.push_outbox set sent_at = public._now(), error = left(p_error, 300) where id = p_id
$$;

-- Jeton refusé par Apple (app désinstallée…) : oublié.
create or replace function public.push_token_invalid(p_token text) returns void
language sql security definer set search_path = public, pg_temp as $$
  delete from public.push_tokens where token = lower(p_token)
$$;

-- ─────────────────────────────────────────── Évènements
-- Duels : reçu (création), défi relevé (lien), terminé (à chacun son résultat).
do $$
declare v_old text; v_new text;
begin
  v_old := pg_get_functiondef('public._duel_new(uuid, uuid, int, text[], text, uuid)'::regprocedure);
  v_new := replace(v_old, '  returning * into d;
  return d;',
'  returning * into d;
  if p_opponent is not null then
    perform public._push(p_opponent, ''social'', ''Nouveau duel'',
      (select handle from public.profiles where id = p_user) || '' te défie : '' || p_count || '' questions. À toi de jouer !'',
      jsonb_build_object(''type'', ''duel'', ''id'', d.id), ''duel_new:'' || d.id);
  end if;
  return d;');
  if v_new = v_old then raise exception '0036: _duel_new inchangée'; end if;
  execute v_new;

  v_old := pg_get_functiondef('public.duel_join(text)'::regprocedure);
  v_new := replace(v_old, '  update public.duels set opponent_id = v_user, status = ''active'' where id = d.id returning * into d;',
'  update public.duels set opponent_id = v_user, status = ''active'' where id = d.id returning * into d;
  perform public._push(d.challenger_id, ''social'', ''Défi relevé'',
    (select handle from public.profiles where id = v_user) || '' a relevé ton défi. Qui va gagner ?'',
    jsonb_build_object(''type'', ''duel'', ''id'', d.id), ''duel_join:'' || d.id);');
  if v_new = v_old then raise exception '0036: duel_join inchangée'; end if;
  execute v_new;

  -- Fin de duel : on prévient chaque joueur qui n'est pas celui qui vient de finir (lui voit déjà le résultat).
  v_old := pg_get_functiondef('public._duel_close(uuid)'::regprocedure);
  v_new := replace(v_old, '  update public.duels set status = ''finished'', finished_at = public._now(), winner_id = v_winner where id = d.id;',
'  update public.duels set status = ''finished'', finished_at = public._now(), winner_id = v_winner where id = d.id;
  perform public._duel_notify_end(d.id);');
  if v_new = v_old then raise exception '0036: _duel_close inchangée'; end if;
  execute v_new;
end $$;

create or replace function public._duel_notify_end(p_duel uuid) returns void
language plpgsql as $$
declare
  d public.duels;
  u uuid;
  v_other uuid;
  me record; them record;
begin
  select * into d from public.duels where id = p_duel;
  if d.opponent_id is null then return; end if;
  foreach u in array array[d.challenger_id, d.opponent_id] loop
    continue when u = auth.uid();
    v_other := case when u = d.challenger_id then d.opponent_id else d.challenger_id end;
    select * into me from public._duel_state(d.id, u);
    select * into them from public._duel_state(d.id, v_other);
    perform public._push(u, 'social', 'Duel terminé',
      case when d.winner_id = u then 'Victoire contre ' when d.winner_id is null then 'Égalité contre ' else 'Défaite contre ' end
        || (select handle from public.profiles where id = v_other) || ' : ' || me.score || '–' || them.score || '.',
      jsonb_build_object('type', 'duel', 'id', d.id), 'duel_end:' || d.id || ':' || u);
  end loop;
end $$;

-- Amis : demande reçue, demande acceptée.
do $$
declare v_old text; v_new text;
begin
  v_old := pg_get_functiondef('public.friend_request(text)'::regprocedure);
  v_new := replace(v_old, '    insert into public.friendships (requester_id, addressee_id, created_at) values (v_user, v_target, public._now());
    return jsonb_build_object(''status'', ''pending'');',
'    insert into public.friendships (requester_id, addressee_id, created_at) values (v_user, v_target, public._now());
    perform public._push(v_target, ''social'', ''Demande d''''ami'',
      (select handle from public.profiles where id = v_user) || '' veut être ton ami sur Brainlix.'',
      jsonb_build_object(''type'', ''friends''), ''friend_request:'' || v_user || '':'' || v_target || '':'' || public._now()::date);
    return jsonb_build_object(''status'', ''pending'');');
  if v_new = v_old then raise exception '0036: friend_request inchangée'; end if;
  execute v_new;

  v_old := pg_get_functiondef('public.friend_respond(uuid, boolean)'::regprocedure);
  v_new := replace(v_old, '    perform public._befriend(f.requester_id, v_user);',
'    perform public._befriend(f.requester_id, v_user);
    perform public._push(f.requester_id, ''social'', ''Nouvel ami'',
      (select handle from public.profiles where id = v_user) || '' a accepté ta demande. Lance-lui un duel !'',
      jsonb_build_object(''type'', ''friend'', ''id'', v_user), ''friend_accept:'' || f.id);');
  if v_new = v_old then raise exception '0036: friend_respond inchangée'; end if;
  execute v_new;
end $$;

-- Ligues : quiz à faire (19 h, heure du joueur), ligue terminée (classement final). Tâche horaire.
create or replace function public.cron_league_notifications() returns int
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  r record;
  v_n int := 0;
begin
  -- Rappel du quiz du jour, une fois, entre 19 h et 20 h (heure du joueur), s'il ne l'a pas fini.
  for r in
    select l.id, l.name, l.question_count, m.user_id, public._league_today(l) as day
    from public.leagues l join public.league_members m on m.league_id = l.id
    join public.profiles p on p.id = m.user_id
    where public._league_status(l) = 'active'
      and extract(hour from public._now() at time zone coalesce(p.timezone, 'Europe/Paris')) = 19
  loop
    continue when (select answered from public._league_day_state(r.id, r.day, r.user_id)) >= r.question_count;
    perform public._push(r.user_id, 'leagues', r.name, 'Le quiz de la ligue t''attend : ' || r.question_count
                         || ' questions, avant minuit.', jsonb_build_object('type', 'league', 'id', r.id),
                         'league_quiz:' || r.id || ':' || r.day || ':' || r.user_id);
    v_n := v_n + 1;
  end loop;

  -- Fin de saison (dans les 2 derniers jours) : classement final de chacun.
  for r in
    select l.id, l.name, s.season, s.starts_on, s.ends_on, x.user_id, x.rank, count(*) over (partition by l.id, s.season) as players
    from public.leagues l join public.league_seasons s on s.league_id = l.id
    cross join lateral (
      select y.user_id, rank() over (order by y.points desc, y.total_ms asc, y.days desc) as rank
      from public._league_rows(l.id, s.starts_on, s.ends_on) y) x
    where public._league_end_at(s.ends_on, l.timezone) <= public._now()
      and public._league_end_at(s.ends_on, l.timezone) > public._now() - interval '2 days'
  loop
    perform public._push(r.user_id, 'leagues', r.name || ' est terminée',
                         'Tu finis ' || case when r.rank = 1 then '1er' else r.rank || 'e' end || ' sur ' || r.players || '.',
                         jsonb_build_object('type', 'league', 'id', r.id),
                         'league_end:' || r.id || ':' || r.season || ':' || r.user_id);
    v_n := v_n + 1;
  end loop;
  return v_n;
end $$;

-- ─────────────────────────────────────────── Comptes anonymes abandonnés
-- Jamais terminés (onboarding), sans compte Apple ni e-mail, sans ami, ligue ni duel, inactifs depuis 7 jours.
create or replace function public.cron_cleanup_anonymous() returns int
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_n int;
begin
  with targets as (
    select u.id from auth.users u join public.profiles p on p.id = u.id
    where coalesce(u.is_anonymous, false) and u.email is null and p.onboarded_at is null
      and p.created_at < public._now() - interval '7 days'
      and not exists (select 1 from public.app_admins a where a.user_id = u.id)
      and not exists (select 1 from public.friendships f where u.id in (f.requester_id, f.addressee_id))
      and not exists (select 1 from public.league_members m where m.user_id = u.id)
      and not exists (select 1 from public.duels d where u.id in (d.challenger_id, d.opponent_id))
      and not exists (select 1 from public.app_events e where e.user_id = u.id and e.created_at > public._now() - interval '7 days')
      and not exists (select 1 from public.question_attempts a where a.user_id = u.id and a.created_at > public._now() - interval '7 days')
  )
  delete from auth.users where id in (select id from targets);
  get diagnostics v_n = row_count;
  return v_n;
end $$;

-- ─────────────────────────────────────────── Admin : vrais comptes par défaut
create or replace function public.admin_users(p_search text default null, p_sort text default 'recent',
                                              p_limit int default 50, p_offset int default 0, p_scope text default 'real')
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  perform public._require_admin();
  return (with base as (
      select p.id, p.handle, p.created_at, p.onboarded_at, p.streak_current, p.streak_best, p.questions_answered, p.seeds,
             p.xp_total, p.banned_at, p.timezone,
             coalesce(u.is_anonymous, true) as anonymous,
             greatest((select max(a.created_at) from public.question_attempts a where a.user_id = p.id),
                      (select max(e.created_at) from public.app_events e where e.user_id = p.id and e.name = 'app_open')) as last_active
      from public.profiles p left join auth.users u on u.id = p.id
      where (p_search is null or p_search = '' or p.handle ilike '%' || p_search || '%' or p.id::text = p_search)
        and (coalesce(p_scope, 'real') = 'all' or p.onboarded_at is not null or not coalesce(u.is_anonymous, true)))
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
drop function if exists public.admin_users(text, text, int, int);

-- ─────────────────────────────────────────── Droits et tâches planifiées
revoke execute on function public._push(uuid, text, text, text, jsonb, text), public._duel_notify_end(uuid),
  public.push_claim(int), public.push_done(bigint, text), public.push_token_invalid(text),
  public.cron_league_notifications(), public.cron_cleanup_anonymous() from public, anon, authenticated;
grant execute on function public.push_claim(int), public.push_done(bigint, text), public.push_token_invalid(text) to service_role;
revoke execute on function public.push_register(text, text), public.push_unregister(text),
  public.admin_users(text, text, int, int, text) from public, anon;
grant execute on function public.push_register(text, text), public.push_unregister(text),
  public.admin_users(text, text, int, int, text) to authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('brainlix-league-notifications', '2 * * * *', 'select public.cron_league_notifications()');
    perform cron.schedule('brainlix-cleanup-anonymous', '37 3 * * *', 'select public.cron_cleanup_anonymous()');
    if exists (select 1 from pg_extension where extname = 'http') then
      -- Envoi : chaque minute, seulement s'il reste des notifications dues.
      perform cron.schedule('brainlix-push-send', '* * * * *', $job$
        select extensions.http_post('https://sibpncsjsdtjcjxbfryk.supabase.co/functions/v1/push-send', '{}', 'application/json')
        where exists (select 1 from public.push_outbox where claimed_at is null and send_after <= now())
      $job$);
    end if;
  end if;
exception when others then
  raise notice 'pg_cron indisponible : notifications non planifiées (%)', sqlerrm;
end $$;
