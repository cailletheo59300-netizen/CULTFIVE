-- Admin, onglet Joueurs (D-095) : version de l'app de chaque joueur (celle de son dernier événement, « 1.3.0 (52) »)
-- et filtre par version (p_version = « 1.3.0 » : tous les builds de la 1.3 ; « none » : version inconnue).
-- La liste des versions présentes est renvoyée pour remplir le filtre.

drop function if exists public.admin_users(text, text, int, int, text);

create or replace function public.admin_users(p_search text default null, p_sort text default 'recent',
                                              p_limit int default 50, p_offset int default 0, p_scope text default 'real',
                                              p_version text default null)
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  perform public._require_admin();
  return (with scoped as (
      select p.id, p.handle, p.created_at, p.onboarded_at, p.streak_current, p.streak_best, p.questions_answered, p.seeds,
             p.xp_total, p.banned_at, p.timezone,
             coalesce(u.is_anonymous, true) as anonymous, public._real_player(p.id) as real_player,
             (select e.app_version from public.app_events e
              where e.user_id = p.id and e.app_version is not null
              order by e.created_at desc limit 1) as app_version
      from public.profiles p left join auth.users u on u.id = p.id
      where (p_search is null or p_search = '' or p.handle ilike '%' || p_search || '%' or p.id::text = p_search)
        and (case coalesce(p_scope, 'real')
               when 'all' then true
               when 'connected' then not coalesce(u.is_anonymous, true)
               else public._real_player(p.id) end)
    ), base as (
      select s.*,
             greatest((select max(a.created_at) from public.question_attempts a where a.user_id = s.id),
                      (select max(e.created_at) from public.app_events e where e.user_id = s.id and e.name = 'app_open')) as last_active,
             (select count(*) from public.ad_views v where v.user_id = s.id and not v.test)::int as ads_rewarded,
             (select count(*) from public._ad_events(null) e where e.user_id = s.id and e.name = 'interstitial')::int as ads_interstitial
      from scoped s
      where p_version is null or p_version = ''
         or (p_version = 'none' and s.app_version is null)
         or split_part(s.app_version, ' ', 1) = p_version
    )
    select jsonb_build_object(
      'total', (select count(*) from base),
      'versions', coalesce((select jsonb_agg(jsonb_build_object('version', v.version, 'count', v.n)
                                             order by string_to_array(v.version, '.')::int[] desc nulls last)
                            from (select split_part(app_version, ' ', 1) as version, count(*) as n
                                  from scoped where app_version is not null group by 1) v
                            where v.version ~ '^[0-9]+(\.[0-9]+)*$'), '[]'::jsonb),
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

revoke execute on function public.admin_users(text, text, int, int, text, text) from public, anon;
grant execute on function public.admin_users(text, text, int, int, text, text) to authenticated;
