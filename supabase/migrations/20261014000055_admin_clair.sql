-- ─────────────────────────────────────────── 0055 · Admin : des chiffres justes et cohérents
-- Les tests iOS de la CI démarraient l'app sur le vrai serveur et créaient un compte invité à chaque passage
-- (≈ 100 « joueurs » fantômes). Désormais, partout dans l'admin, un joueur = un vrai joueur : onboarding fini ou
-- compte Apple / e-mail (même règle que l'onglet Joueurs, « Vrais comptes »). Les invités qui n'ont jamais fini
-- l'onboarding ne comptent que dans la première ligne du parcours (« installations »).
-- Économie en neurones (devise interne « seeds »), avec les pochettes et les cartes de l'album.

create or replace function public._real_player(p_user uuid) returns bool
language sql stable set search_path = public, pg_temp as $$
  select exists (select 1 from public.profiles p where p.id = p_user and p.onboarded_at is not null)
      or exists (select 1 from auth.users u where u.id = p_user and not coalesce(u.is_anonymous, true))
$$;

create or replace function public.admin_kpis(p_days int default 30) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_days int := least(greatest(coalesce(p_days, 30), 7), 180);
  v_today date := public._paris_day(public._now());
  v_from date := v_today - (v_days - 1);
  v_week timestamptz := public._now() - interval '7 days';
begin
  perform public._require_admin();
  create temp table if not exists pg_temp.adm_real (user_id uuid primary key, created_day date) on commit drop;
  truncate pg_temp.adm_real;
  insert into pg_temp.adm_real select p.id, public._paris_day(p.created_at) from public.profiles p where public._real_player(p.id);
  -- Jours d'activité de tout le monde (pour le parcours), puis des vrais joueurs seulement.
  create temp table if not exists pg_temp.adm_all (user_id uuid, day date) on commit drop;
  truncate pg_temp.adm_all;
  insert into pg_temp.adm_all select * from public._activity_days(least(v_from, v_today - 60));
  create temp table if not exists pg_temp.adm_act (user_id uuid, day date) on commit drop;
  truncate pg_temp.adm_act;
  insert into pg_temp.adm_act select a.* from pg_temp.adm_all a
    where exists (select 1 from pg_temp.adm_real r where r.user_id = a.user_id);

  return jsonb_build_object(
    'today', v_today,
    'totals', jsonb_build_object(
      'players', (select count(*) from pg_temp.adm_real),
      'guests', (select count(*) from public.profiles p where not exists (select 1 from pg_temp.adm_real r where r.user_id = p.id)),
      'onboarded', (select count(*) from public.profiles where onboarded_at is not null),
      'linked', (select count(*) from auth.users u join public.profiles p on p.id = u.id where not u.is_anonymous),
      'banned', (select count(*) from public.profiles where banned_at is not null),
      'answers', (select count(*) from public.question_attempts),
      'answers_7d', (select count(*) from public.question_attempts where created_at > v_week),
      'new_7d', (select count(*) from pg_temp.adm_real where created_day > v_today - 7),
      'dau', (select count(distinct user_id) from pg_temp.adm_act where day = v_today),
      'wau', (select count(distinct user_id) from pg_temp.adm_act where day > v_today - 7),
      'mau', (select count(distinct user_id) from pg_temp.adm_act where day > v_today - 30)),
    -- Une ligne par jour : nouveaux joueurs, actifs, 5 du jour finis, parties terminées, réponses.
    'series', (select coalesce(jsonb_agg(jsonb_build_object(
          'day', d.day,
          'new_players', (select count(*) from pg_temp.adm_real r where r.created_day = d.day),
          'active', (select count(distinct user_id) from pg_temp.adm_act a where a.day = d.day),
          'daily_finished', (select count(*) from public.daily_runs r where r.daily_date = d.day and r.status = 'finished'),
          'games', (select count(*) from public.play_sessions s where s.completed_at is not null
                      and public._paris_day(s.completed_at) = d.day),
          'answers', (select count(*) from public.question_attempts q where public._paris_day(q.created_at) = d.day)
        ) order by d.day), '[]'::jsonb)
      from (select generate_series(v_from, v_today, interval '1 day')::date as day) d),
    -- Rétention : part des vrais joueurs revenus exactement N jours après leur arrivée (cohortes assez anciennes).
    'retention', (select coalesce(jsonb_object_agg(k, jsonb_build_object('cohort', c, 'returned', r,
                                                                  'rate', case when c > 0 then round(r::numeric / c, 3) end)), '{}'::jsonb)
      from (select k, count(*) c,
                   count(*) filter (where exists (select 1 from pg_temp.adm_act a
                                                  where a.user_id = p.user_id and a.day = p.created_day + k)) r
            from unnest(array[1, 7, 30]) k
            join pg_temp.adm_real p on p.created_day <= v_today - k and p.created_day > v_today - k - 60
            group by k) t),
    -- Parcours des arrivées sur la période : toutes les installations, puis les étapes.
    'funnel', (select jsonb_build_object(
          'created', count(*),
          'onboarded', count(*) filter (where p.onboarded_at is not null),
          'first_answer', count(*) filter (where exists (select 1 from public.question_attempts a where a.user_id = p.id)),
          'first_daily', count(*) filter (where exists (select 1 from public.daily_runs r where r.user_id = p.id and r.status = 'finished')),
          'came_back', count(*) filter (where exists (select 1 from pg_temp.adm_all a
                                                      where a.user_id = p.id and a.day > public._paris_day(p.created_at))),
          'linked', count(*) filter (where exists (select 1 from auth.users u where u.id = p.id and not u.is_anonymous)))
      from public.profiles p where public._paris_day(p.created_at) >= v_from),
    -- Économie sur 7 jours (neurones, devise interne « seeds »), coffres, album.
    'economy', jsonb_build_object(
      'seeds_earned', (select coalesce(sum(amount), 0) from public.ledger
                       where currency = 'seeds' and amount > 0 and created_at > v_week),
      'seeds_spent', (select coalesce(-sum(amount), 0) from public.ledger
                      where currency = 'seeds' and amount < 0 and created_at > v_week),
      'by_reason', (select coalesce(jsonb_object_agg(reason, n), '{}'::jsonb) from (
                      select reason, sum(amount) n from public.ledger
                      where currency = 'seeds' and created_at > v_week
                      group by reason order by abs(sum(amount)) desc limit 15) t),
      'chests_opened', (select coalesce(jsonb_object_agg(t, n), '{}'::jsonb) from (
                          select coalesce(contents ->> 'final_tier', tier::text) t, count(*) n from public.user_chests
                          where opened_at > v_week group by 1) x),
      'packs_opened', (select coalesce(jsonb_object_agg(kind, n), '{}'::jsonb) from (
                         select kind, count(*) n from public.album_openings
                         where slot = 0 and created_at > v_week group by 1) x),
      'cards_new', (select count(*) from public.user_cards where slot = 0 and first_at > v_week),
      'game_cards', (select count(*) from public.album_game_cards where card_id is not null and created_at > v_week)),
    'domains', (select coalesce(jsonb_agg(jsonb_build_object('domain_id', domain_id, 'answers', n) order by n desc), '[]'::jsonb)
      from (select q.domain_id, count(*) n from public.question_attempts a join public.questions q on q.id = a.question_id
            where a.created_at > public._now() - interval '30 days' group by 1) t),
    -- Versions de l'app des vrais joueurs (30 jours).
    'versions', (select coalesce(jsonb_object_agg(v, n), '{}'::jsonb) from (
                   select e.app_version v, count(distinct e.user_id) n from public.app_events e
                   where e.name = 'app_open' and e.app_version is not null and e.created_at > public._now() - interval '30 days'
                     and exists (select 1 from pg_temp.adm_real r where r.user_id = e.user_id)
                   group by 1) t),
    'events', (select coalesce(jsonb_object_agg(name, n), '{}'::jsonb) from (
                 select e.name, count(*) n from public.app_events e
                 where e.created_at > v_week and exists (select 1 from pg_temp.adm_real r where r.user_id = e.user_id)
                 group by 1) t));
end $$;

-- Pubs : vues confirmées par Google, des vrais joueurs ; pubs entre les parties comptées par l'app.
create or replace function public.admin_ads(p_days int default 30) returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare
  v_days int := least(greatest(coalesce(p_days, 30), 7), 180);
  v_today date := public._paris_day(public._now());
  v_from date := v_today - (v_days - 1);
begin
  perform public._require_admin();
  return jsonb_build_object(
    'series', (select coalesce(jsonb_agg(jsonb_build_object(
          'day', d.day,
          'rewarded', (select count(*) from public.ad_views v where not v.test and public._paris_day(v.created_at) = d.day),
          'interstitial', (select count(*) from public.app_events e where e.name = 'interstitial'
                             and public._paris_day(e.created_at) = d.day and public._real_player(e.user_id)),
          'viewers', (select count(distinct user_id) from public.ad_views v where not v.test and public._paris_day(v.created_at) = d.day)
        ) order by d.day), '[]'::jsonb)
      from (select generate_series(v_from, v_today, interval '1 day')::date as day) d),
    'by_kind', (select coalesce(jsonb_object_agg(kind, jsonb_build_object('views', n, 'claimed', c)), '{}'::jsonb) from (
                  select kind, count(*) n, count(*) filter (where claimed_at is not null) c from public.ad_views
                  where not test and created_at > public._now() - interval '7 days' group by kind) t),
    'rewarded_7d', (select count(*) from public.ad_views where not test and created_at > public._now() - interval '7 days'),
    'seeds_doubled', (select coalesce(sum(amount), 0) from public.ledger
                      where reason = 'ad_double_seeds' and created_at > public._now() - interval '7 days'),
    'interstitial_7d', (select count(*) from public.app_events e where e.name = 'interstitial'
                          and e.created_at > public._now() - interval '7 days' and public._real_player(e.user_id)),
    'viewers_7d', (select count(distinct user_id) from public.ad_views where not test
                     and created_at > public._now() - interval '7 days'));
end $$;

-- Contenu (onglet Questions) : plus de chiffres de joueurs ici, ils sont au tableau de bord.
create or replace function public.admin_dashboard() returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  perform public._require_admin();
  return jsonb_build_object(
    'questions_by_status', (select jsonb_object_agg(status, n) from (select status, count(*) n from public.questions group by 1) t),
    'published_by_domain', (select jsonb_object_agg(domain_id, n) from (select domain_id, count(*) n from public.questions
                                                                         where status = 'published' group by 1) t),
    'published_by_subdomain', (select jsonb_object_agg(subdomain_id, n) from (select subdomain_id, count(*) n from public.questions
                                                                               where status = 'published' group by 1) t),
    'needs_review', (select count(*) from public.questions where needs_review),
    'open_reports', (select count(*) from public.question_reports where resolved_at is null),
    'users', (select count(*) from public.profiles p where public._real_player(p.id)),
    'daily_players_today', (select count(*) from public.daily_runs where daily_date = public._paris_day(public._now()) and status = 'finished'),
    'answers_7d', (select count(*) from public.question_attempts where created_at > public._now() - interval '7 days'),
    'upcoming_dailies', (select coalesce(jsonb_agg(daily_date order by daily_date), '[]'::jsonb) from public.daily_sets
                         where daily_date >= public._paris_day(public._now())));
end $$;

revoke execute on function public._real_player(uuid) from public, anon, authenticated;
revoke execute on function public.admin_kpis(int), public.admin_ads(int), public.admin_dashboard() from public, anon;
grant execute on function public.admin_kpis(int), public.admin_ads(int), public.admin_dashboard() to authenticated;
