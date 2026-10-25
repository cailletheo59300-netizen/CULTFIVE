-- ─────────────────────────────────────────── 0089 · Arène : 25 s par question (D-111, propriétaire, 25/10)
create or replace function public._arena_rule(p_key text) returns int
language sql immutable set search_path = public, pg_temp as $$
  select case p_key
    when 'questions' then 7 when 'seconds' then 25 when 'grace' then 3
    when 'win' then 3 when 'draw' then 1 when 'loss' then 0
    when 'streak_from' then 3 when 'streak_bonus' then 1 when 'streak_chest' then 5
    when 'chest_every' then 10 when 'min_duels' then 5
    when 'queue_hours' then 48 when 'play_minutes' then 30 when 'abandon_minutes' then 15
    when 'daily_limit' then 80 end
$$;
