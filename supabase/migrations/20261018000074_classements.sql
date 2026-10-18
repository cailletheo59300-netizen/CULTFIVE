-- Classements (D-079). 5 du jour : seulement les vrais joueurs (même règle que l'admin, `_real_player`) qui ont fait
-- un 5 du jour dans les 3 derniers jours, chacun avec son dernier : un joueur qui ne joue plus sort du classement, le
-- podium se renouvelle. Le joueur qui regarde a toujours sa ligne, même s'il n'en fait pas partie.
-- Nouveau : classement Elo d'un domaine (fiche du domaine), vrais joueurs placés dans ce domaine.
drop function if exists public._daily_ranks();
create or replace function public._daily_ranks(p_viewer uuid)
returns table (rank int, user_id uuid, score int, total_ms int, streak int, daily_date date)
language sql stable set search_path = public, pg_temp as $$
  with last as (
    select distinct on (r.user_id) r.*
    from public.daily_runs r join public.profiles p on p.id = r.user_id
    where r.status = 'finished' and p.banned_at is null
    order by r.user_id, r.daily_date desc, r.finished_at desc
  )
  select row_number() over (order by l.score desc, l.total_ms, l.finished_at, l.id)::int, l.user_id, l.score::int,
         l.total_ms, l.streak_after, l.daily_date
  from last l
  where l.user_id = p_viewer
     or (l.daily_date >= (public._now() at time zone 'Europe/Paris')::date - 2 and public._real_player(l.user_id))
$$;

-- Lignes d'un classement : podium, puis le joueur et ses voisins.
create or replace function public._leaderboard_json(p_user uuid, p_kind text, p_domain text) returns jsonb
language plpgsql stable set search_path = public, pg_temp as $$
declare
  v_rank int;
  v_total int;
  v_rows jsonb;
begin
  if p_kind = 'daily' then
    select count(*), max(d.rank) filter (where d.user_id = p_user) into v_total, v_rank from public._daily_ranks(p_user) d;
    select coalesce(jsonb_agg(jsonb_build_object('rank', d.rank, 'handle', p.handle, 'score', d.score, 'total_ms', d.total_ms,
                                                 'streak', d.streak, 'me', d.user_id = p_user) order by d.rank), '[]'::jsonb)
      into v_rows
    from public._daily_ranks(p_user) d join public.profiles p on p.id = d.user_id
    where d.rank <= 3 or (v_rank is not null and d.rank between v_rank - 1 and v_rank + 1);
  else
    select count(*), max(d.rank) filter (where d.user_id = p_user) into v_total, v_rank from public._domain_ranks(p_domain, p_user) d;
    select coalesce(jsonb_agg(jsonb_build_object('rank', d.rank, 'handle', p.handle, 'elo', d.elo, 'me', d.user_id = p_user)
                              order by d.rank), '[]'::jsonb)
      into v_rows
    from public._domain_ranks(p_domain, p_user) d join public.profiles p on p.id = d.user_id
    where d.rank <= 3 or (v_rank is not null and d.rank between v_rank - 1 and v_rank + 1);
  end if;
  return jsonb_build_object('participants', v_total, 'rank', v_rank, 'rows', v_rows);
end $$;

-- Classement Elo d'un domaine : vrais joueurs placés dans ce domaine (et le joueur qui regarde s'il est placé).
create or replace function public._domain_ranks(p_domain text, p_viewer uuid)
returns table (rank int, user_id uuid, elo int)
language sql stable set search_path = public, pg_temp as $$
  select row_number() over (order by s.elo desc nulls last, s.n desc, s.user_id)::int, s.user_id,
         round(coalesce(s.elo, 500))::int
  from public.user_skills s join public.profiles p on p.id = s.user_id
  where s.scope_id = p_domain and s.n >= public._c_placement() and p.banned_at is null
    and (s.user_id = p_viewer or public._real_player(s.user_id))
$$;

create or replace function public.domain_leaderboard(p_domain text) returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user();
begin
  if not exists (select 1 from public.domains where id = p_domain) then raise exception 'invalid_domain'; end if;
  return public._leaderboard_json(v_user, 'domain', p_domain);
end $$;

create or replace function public.daily_leaderboard(p_date date default null) returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  return public._leaderboard_json(public._require_user(), 'daily', null);
end $$;

revoke execute on function public._daily_ranks(uuid), public._domain_ranks(text, uuid), public._leaderboard_json(uuid, text, text)
  from public, anon, authenticated;
revoke execute on function public.domain_leaderboard(text) from public, anon;
grant execute on function public.domain_leaderboard(text) to authenticated;
