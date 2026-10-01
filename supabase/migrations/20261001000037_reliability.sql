-- Brainlix — 0037 Fiabilité
-- 1. Diagnostics de l'app (plantages et blocages, via MetricKit d'Apple) et erreurs vues par les joueurs.
-- 2. Version minimale de l'app (numéro de build), réglable depuis l'admin : en dessous, l'app demande la mise à jour.
-- 3. Admin « Santé » : plantages, erreurs, tâches planifiées, notifications, pubs.
-- 4. Sécurité et vitesse (alertes Supabase) : chemin de recherche fixe partout, _is_banned fermé aux anonymes,
--    règles d'accès évaluées une fois par requête, index des clés étrangères, tables de sauvegarde ponctuelles supprimées.

-- ─────────────────────────────────────────── Diagnostics
create table public.app_diagnostics (
  id          bigint generated always as identity primary key,
  user_id     uuid references public.profiles(id) on delete set null,
  kind        text not null check (kind in ('crash', 'hang', 'cpu', 'disk', 'launch')),
  app_version text check (length(app_version) <= 20),
  os_version  text check (length(os_version) <= 20),
  payload     jsonb not null default '{}'::jsonb check (pg_column_size(payload) <= 16384),
  created_at  timestamptz not null default now()
);
create index on public.app_diagnostics (created_at desc);
alter table public.app_diagnostics enable row level security;
revoke all on public.app_diagnostics from public, anon, authenticated;

create or replace function public.report_diagnostic(p_kind text, p_payload jsonb, p_app_version text, p_os_version text)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user();
begin
  if p_kind not in ('crash', 'hang', 'cpu', 'disk', 'launch') then return; end if;
  if (select count(*) from public.app_diagnostics where user_id = v_user and created_at > public._now() - interval '1 day') >= 20 then
    return;
  end if;
  begin
    insert into public.app_diagnostics (user_id, kind, app_version, os_version, payload, created_at)
    values (v_user, p_kind, left(p_app_version, 20), left(p_os_version, 20), coalesce(p_payload, '{}'::jsonb), public._now());
  exception when check_violation then
    insert into public.app_diagnostics (user_id, kind, app_version, os_version, payload, created_at)
    values (v_user, p_kind, left(p_app_version, 20), left(p_os_version, 20), jsonb_build_object('truncated', true), public._now());
  end;
end $$;

-- Erreurs vues par les joueurs : un événement « client_error » dans le journal d'usage.
alter table public.app_events drop constraint app_events_name_check;
alter table public.app_events add constraint app_events_name_check check (name in (
  'app_open', 'onboarding_step', 'onboarding_done', 'share', 'reminder_optin', 'notif_permission',
  'ad_offer', 'ad_view', 'ad_reward', 'interstitial', 'campaign', 'client_error'));

-- ─────────────────────────────────────────── Version minimale
create table public.app_config (
  key        text primary key,
  value      jsonb not null,
  updated_at timestamptz not null default now()
);
alter table public.app_config enable row level security;
revoke all on public.app_config from public, anon, authenticated;
insert into public.app_config (key, value) values ('min_build', '0'::jsonb) on conflict do nothing;

-- Lu au lancement (même avant connexion).
create or replace function public.app_settings() returns jsonb
language sql stable security definer set search_path = public, pg_temp as $$
  select jsonb_build_object('min_build', coalesce((select (value #>> '{}')::int from public.app_config where key = 'min_build'), 0))
$$;

create or replace function public.admin_set_min_build(p_build int) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  perform public._require_admin();
  if p_build < 0 then raise exception 'invalid'; end if;
  insert into public.app_config (key, value, updated_at) values ('min_build', to_jsonb(p_build), public._now())
  on conflict (key) do update set value = excluded.value, updated_at = excluded.updated_at;
  return public.app_settings();
end $$;

-- ─────────────────────────────────────────── Santé (admin)
create or replace function public.admin_health() returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare v_cron jsonb := '[]'::jsonb;
begin
  perform public._require_admin();
  begin
    execute $q$
      select coalesce(jsonb_agg(jsonb_build_object(
          'job', j.jobname, 'schedule', j.schedule,
          'last_run', (select max(d.start_time) from cron.job_run_details d where d.jobid = j.jobid),
          'last_status', (select d.status from cron.job_run_details d where d.jobid = j.jobid order by d.start_time desc limit 1),
          'failures_24h', (select count(*) from cron.job_run_details d where d.jobid = j.jobid and d.status = 'failed'
                             and d.start_time > now() - interval '1 day'),
          'last_error', (select left(d.return_message, 200) from cron.job_run_details d where d.jobid = j.jobid and d.status = 'failed'
                           order by d.start_time desc limit 1)) order by j.jobname), '[]'::jsonb)
      from cron.job j $q$ into v_cron;
  exception when others then
    v_cron := '[]'::jsonb;  -- pg_cron absent (tests locaux)
  end;
  return jsonb_build_object(
    'min_build', (public.app_settings() ->> 'min_build')::int,
    'diagnostics_7d', (select coalesce(jsonb_agg(jsonb_build_object('kind', kind, 'app_version', app_version, 'count', n)
                                                 order by n desc), '[]'::jsonb)
                       from (select kind, app_version, count(*) n from public.app_diagnostics
                             where created_at > public._now() - interval '7 days' group by 1, 2) t),
    'recent_crashes', (select coalesce(jsonb_agg(jsonb_build_object('at', created_at, 'kind', kind, 'app_version', app_version,
                                                                     'os_version', os_version, 'payload', payload)
                                                 order by created_at desc), '[]'::jsonb)
                       from (select * from public.app_diagnostics where kind in ('crash', 'hang')
                             order by created_at desc limit 10) t),
    'errors_7d', (select coalesce(jsonb_agg(jsonb_build_object('function', f, 'code', c, 'count', n, 'players', u)
                                            order by n desc), '[]'::jsonb)
                  from (select props ->> 'function' f, props ->> 'code' c, count(*) n, count(distinct user_id) u
                        from public.app_events where name = 'client_error' and created_at > public._now() - interval '7 days'
                        group by 1, 2 order by 3 desc limit 25) t),
    'cron', v_cron,
    'push', jsonb_build_object(
      'tokens', (select count(*) from public.push_tokens),
      'sent_24h', (select count(*) from public.push_outbox where sent_at > public._now() - interval '1 day' and error is null),
      'errors_24h', (select count(*) from public.push_outbox where sent_at > public._now() - interval '1 day' and error is not null),
      'waiting', (select count(*) from public.push_outbox where claimed_at is null),
      'last_error', (select error from public.push_outbox where error is not null order by sent_at desc limit 1)),
    'ads_24h', (select count(*) from public.ad_views where created_at > public._now() - interval '1 day' and not test),
    'db_size', pg_size_pretty(pg_database_size(current_database())));
end $$;

-- Conservation : diagnostics 13 mois (ajouté à la purge quotidienne).
do $$
declare v_old text; v_new text;
begin
  v_old := pg_get_functiondef('public.cron_retention()'::regprocedure);
  v_new := replace(v_old, '  delete from public.league_code_attempts where created_at < public._now() - interval ''1 day'';',
                   '  delete from public.app_diagnostics where created_at < public._now() - interval ''13 months'';
  delete from public.league_code_attempts where created_at < public._now() - interval ''1 day'';');
  if v_new = v_old then raise exception '0037: cron_retention inchangée'; end if;
  execute v_new;
end $$;

-- ─────────────────────────────────────────── Sécurité et vitesse
-- Règles d'accès : auth.uid() évalué une fois par requête, pas à chaque ligne.
do $$
declare
  p record;
  v_using text; v_check text;
begin
  for p in select pol.polname, c.relname, pg_get_expr(pol.polqual, pol.polrelid) as qual,
                  pg_get_expr(pol.polwithcheck, pol.polrelid) as wcheck
           from pg_policy pol join pg_class c on c.oid = pol.polrelid join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'public'
             and (pg_get_expr(pol.polqual, pol.polrelid) ~ 'auth\.uid\(\)' or pg_get_expr(pol.polwithcheck, pol.polrelid) ~ 'auth\.uid\(\)')
  loop
    v_using := regexp_replace(p.qual, '(?<!SELECT )auth\.uid\(\)', '(select auth.uid())', 'g');
    v_check := regexp_replace(p.wcheck, '(?<!SELECT )auth\.uid\(\)', '(select auth.uid())', 'g');
    if p.qual is not null then
      execute format('alter policy %I on public.%I using (%s)', p.polname, p.relname, v_using);
    end if;
    if p.wcheck is not null then
      execute format('alter policy %I on public.%I with check (%s)', p.polname, p.relname, v_check);
    end if;
  end loop;
end $$;

-- Index des clés étrangères (suppressions en cascade et jointures).
create index if not exists achievements_domain_id_idx on public.achievements (domain_id);
create index if not exists content_reports_reporter_idx on public.content_reports (reporter_id);
create index if not exists daily_answers_question_idx on public.daily_answers (question_id);
create index if not exists duel_answers_question_idx on public.duel_answers (question_id);
create index if not exists duel_answers_user_idx on public.duel_answers (user_id);
create index if not exists duels_rematch_of_idx on public.duels (rematch_of);
create index if not exists friendships_blocked_by_idx on public.friendships (blocked_by);
create index if not exists generation_batches_created_by_idx on public.generation_batches (created_by);
create index if not exists generation_batches_domain_idx on public.generation_batches (domain_id);
create index if not exists generation_batches_subdomain_idx on public.generation_batches (subdomain_id);
create index if not exists league_answers_question_idx on public.league_answers (question_id);
create index if not exists league_answers_user_idx on public.league_answers (user_id);
create index if not exists leagues_owner_idx on public.leagues (owner_id);
create index if not exists play_sessions_domain_idx on public.play_sessions (domain_id);
create index if not exists play_sessions_subdomain_idx on public.play_sessions (subdomain_id);
create index if not exists profiles_referred_by_idx on public.profiles (referred_by);
create index if not exists question_reports_user_idx on public.question_reports (user_id);
create index if not exists question_reviews_question_idx on public.question_reviews (question_id);
create index if not exists question_reviews_reviewer_idx on public.question_reviews (reviewer_id);
create index if not exists user_achievements_achievement_idx on public.user_achievements (achievement_id);
create index if not exists user_concepts_concept_idx on public.user_concepts (concept_id);
create index if not exists user_items_item_idx on public.user_items (item_id);
create index if not exists app_diagnostics_user_idx on public.app_diagnostics (user_id);
alter table public.league_code_attempts add column id bigint generated always as identity primary key;

-- Tables de sauvegarde ponctuelles (refonte de l'Elo du 30/09) : plus utiles.
drop schema if exists backup cascade;

-- Droits.
revoke execute on function public._is_banned(uuid) from anon;
revoke execute on function public.report_diagnostic(text, jsonb, text, text), public.admin_set_min_build(int),
  public.admin_health() from public, anon;
grant execute on function public.report_diagnostic(text, jsonb, text, text), public.admin_set_min_build(int),
  public.admin_health() to authenticated;
revoke execute on function public.app_settings() from public;
grant execute on function public.app_settings() to anon, authenticated;

-- Chemin de recherche fixe pour toutes les fonctions qui n'en ont pas (alerte Supabase).
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
