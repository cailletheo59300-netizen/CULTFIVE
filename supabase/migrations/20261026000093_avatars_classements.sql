-- Avatars (D-113) dans les derniers classements qui ne les envoyaient pas : résultats d'une ligue (podium de fin),
-- résultat d'un jour de ligue et d'un quiz de ligue. Le classement des ligues, du 5 du jour et des domaines les a déjà.

create or replace function pg_temp.patch(p_fn regprocedure, p_pairs text[]) returns void language plpgsql as $$
declare v_def text := pg_get_functiondef(p_fn); v_new text; i int;
begin
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    v_new := replace(v_def, p_pairs[2 * i - 1], p_pairs[2 * i]);
    if v_new = v_def then raise exception 'patch % : texte % introuvable', p_fn, i; end if;
    v_def := v_new;
  end loop;
  execute v_def;
end $$;

select pg_temp.patch('public._league_results_json(uuid, int)', array[
  '''handle'', p.handle, ''points'', r.points', '''handle'', p.handle, ''avatar'', p.avatar, ''points'', r.points'
]);
select pg_temp.patch('public.league_day_result(uuid, date)', array[
  '''id'', p.id, ''handle'', p.handle, ''is_me''', '''id'', p.id, ''handle'', p.handle, ''avatar'', p.avatar, ''is_me'''
]);
select pg_temp.patch('public.league_quiz_result(uuid, int)', array[
  '''id'', p.id, ''handle'', p.handle, ''is_me''', '''id'', p.id, ''handle'', p.handle, ''avatar'', p.avatar, ''is_me'''
]);
