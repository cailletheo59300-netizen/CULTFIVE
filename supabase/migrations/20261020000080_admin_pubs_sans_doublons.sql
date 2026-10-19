-- Admin : pubs comptées sans doublons (D-085). Les versions 1.1 et 1.2 de l'app enregistrent parfois le même
-- événement de pub 2 à 4 fois (nouvel essai d'envoi quand le réseau est lent juste après la pub). Un même événement
-- (joueur, nom, type) moins de 10 s après le précédent n'est donc compté qu'une fois, pour toutes les statistiques de pubs.
-- Rien ne change pour les joueurs : ces événements ne servent qu'à l'admin.

create or replace function public._ad_events(p_since timestamptz)
returns table (user_id uuid, created_at timestamptz, name text, props jsonb, app_version text)
language sql stable set search_path = public, pg_temp as $$
  select e.user_id, e.created_at, e.name, e.props, e.app_version
  from (select a.*, lag(a.created_at) over (partition by a.user_id, a.name, coalesce(a.props ->> 'kind', '')
                                            order by a.created_at) as prev
        from public.app_events a
        where a.name in ('ad_offer', 'ad_view', 'ad_reward', 'ad_fail', 'interstitial')
          and (p_since is null or a.created_at >= p_since - interval '10 seconds')) e
  where (e.prev is null or e.created_at - e.prev > interval '10 seconds')
    and (p_since is null or e.created_at >= p_since)
$$;
revoke execute on function public._ad_events(timestamptz) from public, anon, authenticated;

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
          'interstitial', (select count(*) from public._ad_events(null) e where e.name = 'interstitial'
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
    'interstitial_7d', (select count(*) from public._ad_events(null) e where e.name = 'interstitial'
                          and e.created_at > public._now() - interval '7 days' and public._real_player(e.user_id)),
    'viewers_7d', (select count(distinct user_id) from public.ad_views where not test
                     and created_at > public._now() - interval '7 days'));
end $$;

create or replace function public.admin_ads_daily(p_days int default 30) returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare
  v_days int := least(greatest(coalesce(p_days, 30), 7), 90);
  v_today date := public._paris_day(public._now());
  v_from date := v_today - (v_days - 1);
  v_start timestamptz := v_from::timestamp at time zone 'Europe/Paris';
begin
  perform public._require_admin();
  return (
    with real as materialized (
      select p.id from public.profiles p where public._real_player(p.id)
    ), ev as materialized (
      select public._paris_day(e.created_at) as day, e.user_id, e.name,
             coalesce(e.props ->> 'kind', '') as kind, coalesce(nullif(e.props ->> 'reason', ''), 'inconnue') as reason
      from public._ad_events(v_start) e join real r on r.id = e.user_id
    ), vw as materialized (
      select public._paris_day(v.created_at) as day, v.user_id, v.kind, v.claimed_at is not null as claimed
      from public.ad_views v join real r on r.id = v.user_id
      where not v.test and v.created_at >= v_start
    ), act as materialized (
      select a.day, count(distinct a.user_id) as n
      from public._activity_days(v_from) a join real r on r.id = a.user_id
      group by a.day
    )
    select jsonb_build_object('days', coalesce(jsonb_agg(jsonb_build_object(
      'day', d.day,
      'active', coalesce((select act.n from act where act.day = d.day), 0),
      'interstitial', (select count(*) from ev where ev.day = d.day and ev.name = 'interstitial'),
      'interstitial_failed', (select count(*) from ev where ev.day = d.day and ev.name = 'ad_fail' and ev.kind = 'interstitial'),
      'offered', (select count(*) from ev where ev.day = d.day and ev.name = 'ad_offer'),
      'launched', (select count(*) from ev where ev.day = d.day and ev.name = 'ad_view'),
      'rewarded_failed', (select count(*) from ev where ev.day = d.day and ev.name = 'ad_fail' and ev.kind <> 'interstitial'),
      'verified', (select count(*) from vw where vw.day = d.day),
      'claimed', (select count(*) from vw where vw.day = d.day and vw.claimed),
      'viewers', (select count(*) from (
                    select vw.user_id from vw where vw.day = d.day
                    union select ev.user_id from ev where ev.day = d.day and ev.name = 'interstitial') x),
      'by_kind', (select coalesce(jsonb_object_agg(k.kind, jsonb_build_object(
                    'offered', (select count(*) from ev where ev.day = d.day and ev.name = 'ad_offer' and ev.kind = k.kind),
                    'launched', (select count(*) from ev where ev.day = d.day and ev.name = 'ad_view' and ev.kind = k.kind),
                    'verified', (select count(*) from vw where vw.day = d.day and vw.kind = k.kind),
                    'failed', (select count(*) from ev where ev.day = d.day and ev.name = 'ad_fail' and ev.kind = k.kind))),
                  '{}'::jsonb)
                  from (select ev.kind from ev where ev.day = d.day and ev.name in ('ad_offer', 'ad_view', 'ad_fail')
                          and ev.kind not in ('', 'interstitial')
                        union select vw.kind from vw where vw.day = d.day) k),
      'fail_reasons', (select coalesce(jsonb_object_agg(f.label, f.n), '{}'::jsonb) from (
                         select (case when ev.kind = 'interstitial' then 'Entre les parties' else 'Récompensée' end)
                                || ' : ' || left(ev.reason, 80) as label, count(*) as n
                         from ev where ev.day = d.day and ev.name = 'ad_fail' group by 1) f)
    ) order by d.day desc), '[]'::jsonb))
    from (select generate_series(v_from, v_today, interval '1 day')::date as day) d
  );
end $$;

create or replace function public.admin_user_ads(p_user uuid) returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare
  v_week timestamptz := public._now() - interval '7 days';
  v_today timestamptz := public._paris_day(public._now())::timestamp at time zone 'Europe/Paris';
begin
  perform public._require_admin();
  return (
    with ev as materialized (
      select e.name, coalesce(e.props ->> 'kind', '') as kind, coalesce(nullif(e.props ->> 'reason', ''), 'inconnue') as reason,
             e.created_at >= v_week as recent, e.created_at >= v_today as today
      from public._ad_events(null) e
      where e.user_id = p_user and e.name in ('ad_offer', 'ad_view', 'ad_fail', 'interstitial')
    ), vw as materialized (
      select v.kind, v.created_at >= v_week as recent, v.created_at >= v_today as today from public.ad_views v where v.user_id = p_user and not v.test
    ), counts as (
      select r.period,
        (select count(*) from ev where ev.name = 'ad_offer' and (r.period = 'total' or (r.period = 'week' and ev.recent) or (r.period = 'today' and ev.today))) as offered,
        (select count(*) from ev where ev.name = 'ad_view' and (r.period = 'total' or (r.period = 'week' and ev.recent) or (r.period = 'today' and ev.today))) as launched,
        (select count(*) from vw where r.period = 'total' or (r.period = 'week' and vw.recent) or (r.period = 'today' and vw.today)) as verified,
        (select count(*) from ev where ev.name = 'ad_fail' and ev.kind <> 'interstitial' and (r.period = 'total' or (r.period = 'week' and ev.recent) or (r.period = 'today' and ev.today))) as rewarded_failed,
        (select count(*) from ev where ev.name = 'interstitial' and (r.period = 'total' or (r.period = 'week' and ev.recent) or (r.period = 'today' and ev.today))) as interstitial,
        (select count(*) from ev where ev.name = 'ad_fail' and ev.kind = 'interstitial' and (r.period = 'total' or (r.period = 'week' and ev.recent) or (r.period = 'today' and ev.today))) as interstitial_failed
      from (values ('total'), ('week'), ('today')) as r(period)
    )
    select jsonb_build_object(
      'total', (select to_jsonb(c) - 'period' from counts c where c.period = 'total'),
      'week', (select to_jsonb(c) - 'period' from counts c where c.period = 'week'),
      'today', (select to_jsonb(c) - 'period' from counts c where c.period = 'today'),
      'by_kind', (select coalesce(jsonb_object_agg(k.kind, jsonb_build_object(
                    'offered', (select count(*) from ev where ev.name = 'ad_offer' and ev.kind = k.kind),
                    'launched', (select count(*) from ev where ev.name = 'ad_view' and ev.kind = k.kind),
                    'verified', (select count(*) from vw where vw.kind = k.kind))), '{}'::jsonb)
                  from (select ev.kind from ev where ev.name in ('ad_offer', 'ad_view') and ev.kind <> ''
                        union select vw.kind from vw) k),
      'fail_reasons', (select coalesce(jsonb_object_agg(f.label, f.n), '{}'::jsonb) from (
                         select (case when ev.kind = 'interstitial' then 'Entre les parties' else 'Récompensée' end)
                                || ' : ' || left(ev.reason, 80) as label, count(*) as n
                         from ev where ev.name = 'ad_fail' group by 1) f),
      'test_claims', (select count(*) from public.ad_views v where v.user_id = p_user and v.test),
      'app_version', (select e.app_version from public.app_events e
                      where e.user_id = p_user and e.name = 'app_open' and e.app_version is not null
                      order by e.created_at desc limit 1))
  );
end $$;

create or replace function public.admin_users(p_search text default null, p_sort text default 'recent',
                                              p_limit int default 50, p_offset int default 0, p_scope text default 'real')
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  perform public._require_admin();
  return (with base as (
      select p.id, p.handle, p.created_at, p.onboarded_at, p.streak_current, p.streak_best, p.questions_answered, p.seeds,
             p.xp_total, p.banned_at, p.timezone,
             coalesce(u.is_anonymous, true) as anonymous, public._real_player(p.id) as real_player,
             greatest((select max(a.created_at) from public.question_attempts a where a.user_id = p.id),
                      (select max(e.created_at) from public.app_events e where e.user_id = p.id and e.name = 'app_open')) as last_active,
             (select count(*) from public.ad_views v where v.user_id = p.id and not v.test)::int as ads_rewarded,
             (select count(*) from public._ad_events(null) e where e.user_id = p.id and e.name = 'interstitial')::int as ads_interstitial
      from public.profiles p left join auth.users u on u.id = p.id
      where (p_search is null or p_search = '' or p.handle ilike '%' || p_search || '%' or p.id::text = p_search)
        and (case coalesce(p_scope, 'real')
               when 'all' then true
               when 'connected' then not coalesce(u.is_anonymous, true)
               else public._real_player(p.id) end))
    select jsonb_build_object(
      'total', (select count(*) from base),
      'items', coalesce((select jsonb_agg(to_jsonb(t)) from (
          select * from base
          order by
            case when p_sort = 'active' then last_active end desc nulls last,
            case when p_sort = 'answers' then questions_answered end desc nulls last,
            case when p_sort = 'streak' then streak_current end desc nulls last,
            case when p_sort = 'ads' then ads_rewarded + ads_interstitial end desc nulls last,
            case when p_sort = 'ads_rewarded' then ads_rewarded end desc nulls last,
            case when p_sort = 'ads_interstitial' then ads_interstitial end desc nulls last,
            created_at desc
          limit least(greatest(p_limit, 1), 200) offset greatest(p_offset, 0)) t), '[]'::jsonb)));
end $$;
