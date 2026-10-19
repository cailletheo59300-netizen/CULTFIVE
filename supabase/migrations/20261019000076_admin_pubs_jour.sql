-- Admin : pubs jour par jour (D-081). Une ligne par jour (Europe/Paris), des vrais joueurs seulement (_real_player) :
-- joueurs actifs ; pubs entre les parties affichées et ratées (journal de l'app) ; pubs récompensées proposées et
-- lancées (journal de l'app), vérifiées par Google et récompensées (ad_views, sans les pubs de test) ; joueurs qui ont
-- vu au moins une pub ; détail par type et raisons des pubs ratées. Les revenus restent dans la console AdMob.

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
      from public.app_events e join real r on r.id = e.user_id
      where e.created_at >= v_start and e.name in ('ad_offer', 'ad_view', 'ad_reward', 'ad_fail', 'interstitial')
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

revoke execute on function public.admin_ads_daily(int) from public, anon;
grant execute on function public.admin_ads_daily(int) to authenticated;
