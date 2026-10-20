-- Classement du 5 du jour : seulement les joueurs du jour (D-094, choix du propriétaire). Les joueurs des jours
-- précédents n'y sont plus : rangs et scores toujours cohérents, sans date à afficher. Le joueur qui regarde garde
-- sa ligne. `ago` reste envoyé (0 pour tous, sauf la ligne du joueur s'il n'a pas joué aujourd'hui).
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
  select row_number() over (order by l.daily_date desc, l.score desc, l.total_ms, l.finished_at, l.id)::int,
         l.user_id, l.score::int, l.total_ms, l.streak_after, l.daily_date, greatest(t.d - l.daily_date, 0)::int
  from last l cross join today t
  where l.user_id = p_viewer
     or (l.daily_date = t.d and public._real_player(l.user_id))
$$;

revoke execute on function public._daily_ranks(uuid) from public, anon, authenticated;
