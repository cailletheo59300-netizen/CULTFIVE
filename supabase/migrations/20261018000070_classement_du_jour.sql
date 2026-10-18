-- Classement du 5 du jour (D-073) : à la fin du 5 du jour, le joueur voit sa place parmi tous ceux qui ont fini le même
-- jour (score, puis temps, puis le premier à finir). L'app montre le classement dès 5 joueurs ; avant, elle montre
-- la part des parties des 7 derniers jours que le joueur bat (jamais « pas assez de joueurs »).
-- Classement d'un jour : score, puis temps, puis le premier à finir ; sans les joueurs bannis.
create or replace function public._daily_ranks(p_date date)
returns table (rank int, user_id uuid, score int, total_ms int, streak int)
language sql stable set search_path = public, pg_temp as $$
  select row_number() over (order by r.score desc, r.total_ms, r.finished_at, r.id)::int, r.user_id, r.score::int,
         r.total_ms, r.streak_after
  from public.daily_runs r join public.profiles p on p.id = r.user_id
  where r.daily_date = p_date and r.status = 'finished' and p.banned_at is null
$$;

create or replace function public.daily_leaderboard(p_date date default null) returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  v_date date := coalesce(p_date, public._user_today(v_user));
  me public.daily_runs;
  v_rank int;
  v_total int;
  v_week_others int;
  v_week_beaten int;
begin
  select * into me from public.daily_runs where user_id = v_user and daily_date = v_date and status = 'finished';

  select count(*), max(rank) filter (where user_id = v_user) into v_total, v_rank from public._daily_ranks(v_date);

  -- 7 derniers jours (sans les parties du joueur) : celles qu'il bat (score plus bas, ou même score et plus lent).
  if me.id is not null then
    select count(*), count(*) filter (where r.score < me.score or (r.score = me.score and r.total_ms > me.total_ms))
      into v_week_others, v_week_beaten
    from public.daily_runs r
    where r.status = 'finished' and r.user_id <> v_user and r.daily_date between v_date - 6 and v_date;
  end if;

  return jsonb_build_object(
    'date', v_date,
    'participants', v_total,
    'rank', v_rank,
    'week_beaten_pct', case when coalesce(v_week_others, 0) > 0 then round(100.0 * v_week_beaten / v_week_others)::int end,
    -- Podium, puis le joueur et ses voisins.
    'rows', coalesce((
      select jsonb_agg(jsonb_build_object('rank', d.rank, 'handle', p.handle, 'score', d.score, 'total_ms', d.total_ms,
                                          'streak', d.streak, 'me', d.user_id = v_user) order by d.rank)
      from public._daily_ranks(v_date) d join public.profiles p on p.id = d.user_id
      where d.rank <= 3 or (v_rank is not null and d.rank between v_rank - 1 and v_rank + 1)), '[]'::jsonb));
end $$;

revoke execute on function public._daily_ranks(date) from public, anon, authenticated;
revoke execute on function public.daily_leaderboard(date) from public, anon;
grant execute on function public.daily_leaderboard(date) to authenticated;
