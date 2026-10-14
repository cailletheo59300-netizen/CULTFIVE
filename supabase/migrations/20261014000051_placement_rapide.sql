-- ─────────────────────────────────────────── 0051 · Placement plus rapide (complément à D-051)
-- Un joueur qui ne fait que des parties rapides mettait ≈ 60 parties à placer un domaine (50 réponses par domaine,
-- ≈ 0,8 question par domaine et par partie rapide). Désormais :
--  · le placement d'un domaine demande 20 réponses classées (2 parties) au lieu de 50 ; tout ce qui en dépend suit
--    (Elo affiché qui monte de 500 au vrai niveau, pas doublé et plafond ±120 pendant le placement, trophées) ;
--  · dans les parties mélangées (rapide, Surprise), les domaines pas encore placés sortent ≈ 2,5 fois plus souvent.
-- Le calcul de l'Elo ne change pas : un seul Elo par domaine, même formule dans tous les modes.

create or replace function public._c_placement() returns int language sql immutable set search_path = public, pg_temp as $$
  select 20
$$;

-- Placement compté en parties de 10 réponses : 0, 1 ou 2.
create or replace function public._rating_json(p_user uuid, p_scope text) returns jsonb
language sql stable set search_path = public, pg_temp as $$
  select jsonb_build_object(
    'cote', public._cote_shown(k.mu, coalesce(s.n, 0)),
    'answered', coalesce(s.n, 0),
    'placement', least(2, coalesce(s.n, 0) * 2 / t.threshold),
    'placed', coalesce(s.n, 0) >= t.threshold)
  from (select case when position('.' in p_scope) > 0 then 15 else public._c_placement() end as threshold) t
  cross join public._skill_peek(p_user, p_scope) k
  left join public.user_skills s on s.user_id = p_user and s.scope_id = p_scope
$$;

-- Domaine de la prochaine question d'une partie mélangée : centres d'intérêt ×2, domaines pas encore placés ×2,5.
create or replace function public._pick_domain(p_user uuid, p_avoid text) returns text
language sql volatile set search_path = public, pg_temp as $$
  select d.id
  from public.domains d
  left join public.profiles p on p.id = p_user
  left join public.user_skills s on s.user_id = p_user and s.scope_id = d.id
  where d.is_active
    and d.id is distinct from p_avoid
    and exists (select 1 from public.questions q where q.domain_id = d.id and q.status = 'published')
  order by -ln(random()) / ((case when d.id = any(coalesce(p.interests, '{}')) then 2.0 else 1.0 end)
                          * (case when coalesce(s.n, 0) < public._c_placement() then 2.5 else 1.0 end))
  limit 1
$$;

revoke execute on function public._rating_json(uuid, text) from public, anon, authenticated;
