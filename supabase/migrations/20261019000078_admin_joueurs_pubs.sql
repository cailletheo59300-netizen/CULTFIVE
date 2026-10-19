-- Admin, liste des joueurs : pubs vues par joueur, et tri par pubs (D-084). Pubs récompensées = vues validées par
-- Google (ad_views, sans les pubs de test) ; entre les parties = vues comptées par l'app. Reste identique à 0061.

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
             (select count(*) from public.app_events e where e.user_id = p.id and e.name = 'interstitial')::int as ads_interstitial
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
