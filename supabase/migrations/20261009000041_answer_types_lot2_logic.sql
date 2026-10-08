-- 0041 : nouveaux types, lot 2 : le compte est bon, mot mystère (bonus selon l'indice), épingle sur la carte,
-- tri express et pyramide des âges (type « sort »). Mêmes règles que 0039 : difficulté et Elo comme les autres,
-- 1 ou 2 nouveaux types par 5 du jour, au plus un par partie classée, jamais pour l'app 1.0.

-- Distance à vol d'oiseau, en km.
create or replace function public._km(lat1 float8, lon1 float8, lat2 float8, lon2 float8) returns float8
language sql immutable set search_path = public, pg_temp as $$
  select 2 * 6371 * asin(sqrt(power(sin(radians(lat2 - lat1) / 2), 2)
                              + cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lon2 - lon1) / 2), 2)))
$$;

-- Le compte est bon : chaque étape {a, op, b} utilise deux nombres encore disponibles (+, -, *, / exacte, jamais négatif),
-- le résultat redevient disponible ; juste si la cible apparaît.
create or replace function public._number_target_ok(p_numbers jsonb, p_target int, p_steps jsonb) returns bool
language plpgsql immutable set search_path = public, pg_temp as $$
declare
  v_pool int[] := array(select x::int from jsonb_array_elements_text(p_numbers) x);
  s jsonb; a int; b int; r int; k int;
begin
  if jsonb_typeof(p_steps) <> 'array' or jsonb_array_length(p_steps) > 5 then return false; end if;
  for s in select * from jsonb_array_elements(p_steps) loop
    a := (s ->> 'a')::int; b := (s ->> 'b')::int;
    k := array_position(v_pool, a); if k is null then return false; end if;
    v_pool := v_pool[1:k - 1] || v_pool[k + 1:];
    k := array_position(v_pool, b); if k is null then return false; end if;
    v_pool := v_pool[1:k - 1] || v_pool[k + 1:];
    r := case s ->> 'op' when '+' then a + b when '-' then a - b when '*' then a * b
                         when '/' then case when b <> 0 and a % b = 0 then a / b end end;
    if r is null or r < 0 then return false; end if;
    v_pool := v_pool || r;
  end loop;
  return p_target = any (v_pool);
exception when others then
  return false;
end $$;

CREATE OR REPLACE FUNCTION public._evaluate(p_type question_type, p_answer jsonb, p_given jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
declare v bool;
begin
  if p_given is null or jsonb_typeof(p_given) <> 'object' then return false; end if;
  case p_type
    when 'mcq', 'map_pick' then
      v := (p_given ->> 'option_id') = (p_answer ->> 'option_id');
    when 'true_false' then
      v := jsonb_typeof(p_given -> 'value') = 'boolean' and (p_given -> 'value') = (p_answer -> 'value');
    when 'numeric' then
      v := jsonb_typeof(p_given -> 'value') = 'number'
           and abs((p_given ->> 'value')::numeric - (p_answer ->> 'value')::numeric)
               <= coalesce((p_answer ->> 'tolerance')::numeric, 0);
    when 'ordering' then
      v := (p_given -> 'order') = (p_answer -> 'order');
    when 'pairs' then
      v := (p_given -> 'pairs') = (p_answer -> 'pairs');
    -- 0039 : nouveaux types.
    when 'counter', 'timeline', 'gauge' then
      v := jsonb_typeof(p_given -> 'value') = 'number'
           and abs((p_given ->> 'value')::numeric - (p_answer ->> 'value')::numeric)
               <= coalesce((p_answer ->> 'tolerance')::numeric, 0);
    when 'proportion' then
      v := jsonb_typeof(p_given -> 'value') = 'number'
           and abs((p_given ->> 'value')::numeric - (p_answer ->> 'value')::numeric)
               <= abs((p_answer ->> 'value')::numeric) * coalesce((p_answer ->> 'rel_tolerance')::numeric, 0);
    when 'letters' then
      v := upper(p_given ->> 'text') = (p_answer ->> 'word');
    when 'word_order' then
      -- On compare le texte (des mots peuvent se répéter : « un pour tous »).
      v := jsonb_typeof(p_given -> 'words') = 'array' and (p_given -> 'words') = (p_answer -> 'words');
    when 'image_choice', 'riddle' then
      v := (p_given ->> 'option_id') = (p_answer ->> 'option_id');
    -- 0041 : lot 2.
    when 'number_target' then
      v := public._number_target_ok(p_answer -> 'numbers', (p_answer ->> 'target')::int, p_given -> 'steps');
    when 'map_pin' then
      v := public._km((p_given ->> 'lat')::float8, (p_given ->> 'lon')::float8, (p_answer ->> 'lat')::float8, (p_answer ->> 'lon')::float8)
           <= (p_answer ->> 'tolerance_km')::float8;
    when 'sort' then
      v := jsonb_typeof(p_given -> 'groups') = 'object' and (p_given -> 'groups') = (p_answer -> 'groups');
  end case;
  return coalesce(v, false);  -- réponse absente ou malformée ⇒ fausse
exception when others then
  return false;
end $function$;

create or replace function public._guess_rate(p_type public.question_type, p_payload jsonb) returns real
language sql immutable set search_path = public, extensions, pg_temp as $$
  select case
    when p_type in ('mcq', 'map_pick', 'image_choice', 'riddle') then 1.0 / greatest(coalesce(jsonb_array_length(p_payload -> 'options'), 4), 2)
    when p_type = 'true_false' then 0.5
    else 0 end::real
$$;

-- « Pile ! » : valeur exacte sur un type à marge ; épingle à moins d'un dixième de la marge.
create or replace function public._is_exact(p_type public.question_type, p_answer jsonb, p_given jsonb) returns bool
language plpgsql immutable set search_path = public, pg_temp as $$
begin
  if p_type in ('counter', 'timeline', 'gauge') then
    return (p_given ->> 'value')::numeric = (p_answer ->> 'value')::numeric;
  elsif p_type = 'proportion' then
    return abs((p_given ->> 'value')::numeric - (p_answer ->> 'value')::numeric) <= abs((p_answer ->> 'value')::numeric) * 0.01;
  elsif p_type = 'map_pin' then
    return public._km((p_given ->> 'lat')::float8, (p_given ->> 'lon')::float8, (p_answer ->> 'lat')::float8, (p_answer ->> 'lon')::float8)
           <= (p_answer ->> 'tolerance_km')::float8 / 10;
  end if;
  return false;
exception when others then
  return false;
end $$;

-- Mot mystère : trouvé au 1er indice +3 graines, au 2e +1. Et préférences de type du 5 du jour.
do $$
declare v_old text; v_new text;
begin
  select pg_get_functiondef('public._record_attempt'::regproc) into v_old;
  v_new := replace(v_old,
    '  -- 0039 : « Pile ! » (valeur exacte sur un type à marge) : +5 graines, une seule fois par tentative.',
    '  -- 0041 : mot mystère trouvé tôt : +3 graines au 1er indice, +1 au 2e.
  if v_correct and q.type = ''riddle'' and coalesce((p_given ->> ''clues'')::int, 3) <= 2 then
    perform public._grant(p_user, ''seeds'', case when (p_given ->> ''clues'')::int <= 1 then 3 else 1 end, ''riddle_bonus'', q.id::text,
                          ''riddle:'' || coalesce(p_client_id::text, q.id::text || '':'' || p_user::text));
  end if;
  -- 0039 : « Pile ! » (valeur exacte sur un type à marge) : +5 graines, une seule fois par tentative.');
  if v_new = v_old then raise exception '0041: _record_attempt inchangée'; end if;
  execute v_new;

  select pg_get_functiondef('public._generate_daily_set'::regproc) into v_old;
  v_new := replace(replace(replace(replace(replace(v_old,
    'when ''calc'' then array[''counter'', ''gauge'']', 'when ''calc'' then array[''counter'', ''gauge'', ''number_target'']'),
    'when ''french'' then array[''letters'', ''word_order'']', 'when ''french'' then array[''letters'', ''word_order'', ''riddle'']'),
    'when ''geo'' then array[''image_choice'', ''proportion'', ''counter'']', 'when ''geo'' then array[''image_choice'', ''proportion'', ''counter'', ''map_pin'']'),
    'when ''history'' then array[''timeline'', ''word_order'']', 'when ''history'' then array[''timeline'', ''word_order'', ''sort'']'),
    'else array[''proportion'', ''gauge'', ''image_choice'', ''counter'', ''timeline'', ''letters'', ''word_order'']',
    'else array[''proportion'', ''gauge'', ''image_choice'', ''counter'', ''timeline'', ''letters'', ''word_order'', ''number_target'', ''riddle'', ''map_pin'', ''sort'']');
  if v_new not like '%''map_pin'']%' or v_new not like '%''number_target'', ''riddle'', ''map_pin'', ''sort'']%' then
    raise exception '0041: _generate_daily_set inchangée';
  end if;
  execute v_new;
end $$;

revoke execute on function public._km(float8, float8, float8, float8) from public, anon, authenticated;
revoke execute on function public._number_target_ok(jsonb, int, jsonb) from public, anon, authenticated;
