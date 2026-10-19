-- Admin, fiche d'un joueur : ses pubs aussi pour la journée en cours (heure de Paris), en plus du total et des 7 derniers
-- jours (D-083). Reste identique à 0077.

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
      from public.app_events e
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

revoke execute on function public.admin_user_ads(uuid) from public, anon;
grant execute on function public.admin_user_ads(uuid) to authenticated;
