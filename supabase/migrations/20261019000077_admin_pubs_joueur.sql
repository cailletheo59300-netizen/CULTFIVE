-- Admin : pubs d'un joueur (D-083), pour sa fiche. Totaux et 7 derniers jours : pubs récompensées demandées (appui),
-- vues jusqu'au bout (journal de l'app), validées par Google (ad_views, sans les pubs de test) ; pubs entre les parties
-- vues et ratées ; détail par type ; raisons des erreurs (1.3 et plus) ; dernière version de l'app.

create or replace function public.admin_user_ads(p_user uuid) returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare
  v_week timestamptz := public._now() - interval '7 days';
begin
  perform public._require_admin();
  return (
    with ev as materialized (
      select e.name, coalesce(e.props ->> 'kind', '') as kind, coalesce(nullif(e.props ->> 'reason', ''), 'inconnue') as reason,
             e.created_at >= v_week as recent
      from public.app_events e
      where e.user_id = p_user and e.name in ('ad_offer', 'ad_view', 'ad_fail', 'interstitial')
    ), vw as materialized (
      select v.kind, v.created_at >= v_week as recent from public.ad_views v where v.user_id = p_user and not v.test
    ), counts as (
      select r.recent_only,
        (select count(*) from ev where ev.name = 'ad_offer' and (ev.recent or not r.recent_only)) as offered,
        (select count(*) from ev where ev.name = 'ad_view' and (ev.recent or not r.recent_only)) as launched,
        (select count(*) from vw where vw.recent or not r.recent_only) as verified,
        (select count(*) from ev where ev.name = 'ad_fail' and ev.kind <> 'interstitial' and (ev.recent or not r.recent_only)) as rewarded_failed,
        (select count(*) from ev where ev.name = 'interstitial' and (ev.recent or not r.recent_only)) as interstitial,
        (select count(*) from ev where ev.name = 'ad_fail' and ev.kind = 'interstitial' and (ev.recent or not r.recent_only)) as interstitial_failed
      from (values (false), (true)) as r(recent_only)
    )
    select jsonb_build_object(
      'total', (select to_jsonb(c) - 'recent_only' from counts c where not c.recent_only),
      'week', (select to_jsonb(c) - 'recent_only' from counts c where c.recent_only),
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
