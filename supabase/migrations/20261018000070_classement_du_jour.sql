-- Classement du 5 du jour (D-073) : à la fin du 5 du jour, le joueur voit sa place parmi tous les joueurs, chacun avec
-- son **dernier** 5 du jour fini, quelle que soit sa date (décision du propriétaire tant qu'il y a peu de joueurs : un
-- classement toujours plein). Ordre : score, puis temps, puis le premier à finir.
-- Classement : le dernier 5 du jour fini de chaque joueur (sans les bannis).
create or replace function public._daily_ranks()
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
$$;

-- p_date : réservé au futur classement du jour seul (ignoré tant que le classement prend le dernier 5 du jour).
create or replace function public.daily_leaderboard(p_date date default null) returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  v_rank int;
  v_total int;
begin
  select count(*), max(rank) filter (where user_id = v_user) into v_total, v_rank from public._daily_ranks();
  return jsonb_build_object(
    'participants', v_total,
    'rank', v_rank,
    -- Podium, puis le joueur et ses voisins.
    'rows', coalesce((
      select jsonb_agg(jsonb_build_object('rank', d.rank, 'handle', p.handle, 'score', d.score, 'total_ms', d.total_ms,
                                          'streak', d.streak, 'me', d.user_id = v_user) order by d.rank)
      from public._daily_ranks() d join public.profiles p on p.id = d.user_id
      where d.rank <= 3 or (v_rank is not null and d.rank between v_rank - 1 and v_rank + 1)), '[]'::jsonb));
end $$;

revoke execute on function public._daily_ranks() from public, anon, authenticated;
revoke execute on function public.daily_leaderboard(date) from public, anon;
grant execute on function public.daily_leaderboard(date) to authenticated;
