-- Classement Elo d'un domaine (D-079, propriétaire) : tous les vrais joueurs (règle de l'admin) qui ont joué en
-- classé dans ce domaine, placement terminé ou non, sans limite de jours.
create or replace function public._domain_ranks(p_domain text, p_viewer uuid)
returns table (rank int, user_id uuid, elo int)
language sql stable set search_path = public, pg_temp as $$
  select row_number() over (order by s.elo desc nulls last, s.n desc, s.user_id)::int, s.user_id,
         round(coalesce(s.elo, 500))::int
  from public.user_skills s join public.profiles p on p.id = s.user_id
  where s.scope_id = p_domain and s.n > 0 and p.banned_at is null
    and (s.user_id = p_viewer or public._real_player(s.user_id))
$$;
