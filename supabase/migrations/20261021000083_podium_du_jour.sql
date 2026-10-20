-- Podium du jour (D-091) : le classement du 5 du jour reste bien rempli (dernier 5 du jour de chaque vrai joueur sur
-- 3 jours), mais les joueurs du jour passent devant : le podium n'est fait que de joueurs d'aujourd'hui et change donc
-- chaque jour. Les autres suivent, avec l'ancienneté de leur partie (`ago` : 1 = hier, 2 = avant-hier), que l'app
-- affiche en petit, sans rang.
drop function if exists public._daily_ranks(uuid);
create or replace function public._daily_ranks(p_viewer uuid)
returns table (rank int, user_id uuid, score int, total_ms int, streak int, daily_date date, ago int)
language sql stable set search_path = public, pg_temp as $$
  with today as (select (public._now() at time zone 'Europe/Paris')::date as d),
  last as (
    select distinct on (r.user_id) r.*
    from public.daily_runs r join public.profiles p on p.id = r.user_id
    where r.status = 'finished' and p.banned_at is null
    order by r.user_id, r.daily_date desc, r.finished_at desc
  )
  select row_number() over (order by l.daily_date = t.d desc, l.score desc, l.total_ms, l.finished_at, l.id)::int,
         l.user_id, l.score::int, l.total_ms, l.streak_after, l.daily_date, greatest(t.d - l.daily_date, 0)::int
  from last l cross join today t
  where l.user_id = p_viewer
     or (l.daily_date >= t.d - 2 and public._real_player(l.user_id))
$$;

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
                                                 'streak', d.streak, 'ago', d.ago, 'me', d.user_id = p_user) order by d.rank), '[]'::jsonb)
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

revoke execute on function public._daily_ranks(uuid), public._leaderboard_json(uuid, text, text)
  from public, anon, authenticated;
