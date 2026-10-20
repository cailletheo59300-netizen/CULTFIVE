-- Frise des siècles (D-087). Les QCM dont les 4 choix sont des siècles (« XVIIIe siècle »…) gardent leurs choix pour
-- les anciennes versions de l'app, et gagnent une frise : payload.century_scale (bornes, du Ier au XXIe siècle) et
-- answer.century (le bon siècle, en nombre). La 1.4 affiche la frise et envoie {"century": n} ; un choix classique
-- ({"option_id": …}) reste accepté. Un déclencheur pose ces champs sur les questions ajoutées ou modifiées plus tard.

create or replace function public._roman_to_int(p text) returns int
language plpgsql immutable set search_path = public, pg_temp as $$
declare
  v int := 0;
  cur int;
  prev int := 0;
begin
  if p is null or p !~ '^[IVXLC]+$' then return null; end if;
  for i in reverse length(p) .. 1 loop
    cur := case substr(p, i, 1) when 'I' then 1 when 'V' then 5 when 'X' then 10 when 'L' then 50 else 100 end;
    if cur < prev then v := v - cur; else v := v + cur; prev := cur; end if;
  end loop;
  return v;
end $$;

-- « XVIIIe siècle », « XVIIIᵉ siècle », « Ier siècle » → 18, 18, 1 ; sinon null (av. J.-C. non pris en charge).
create or replace function public._century_of(p text) returns int
language sql immutable set search_path = public, pg_temp as $$
  select public._roman_to_int((regexp_match(btrim(p), '^([IVXLC]+)(?:e|ᵉ|er|ᵉʳ) siècle$'))[1])
$$;

create or replace function public._century_fields() returns trigger
language plpgsql set search_path = public, pg_temp as $$
declare
  v_all bool;
  v_answer int;
begin
  if new.type <> 'mcq' or jsonb_typeof(new.payload -> 'options') <> 'array'
     or jsonb_array_length(new.payload -> 'options') < 2 then
    return new;
  end if;
  select bool_and(public._century_of(o ->> 'text') between 1 and 21) into v_all
  from jsonb_array_elements(new.payload -> 'options') o;
  select public._century_of(o ->> 'text') into v_answer
  from jsonb_array_elements(new.payload -> 'options') o where o ->> 'id' = new.answer ->> 'option_id';
  if coalesce(v_all, false) and v_answer is not null then
    new.payload := new.payload || '{"century_scale": {"min": 1, "max": 21}}'::jsonb;
    new.answer := new.answer || jsonb_build_object('century', v_answer);
  else
    new.payload := new.payload - 'century_scale';
    new.answer := new.answer - 'century';
  end if;
  return new;
end $$;

drop trigger if exists questions_century_fields on public.questions;
create trigger questions_century_fields before insert or update of type, payload, answer on public.questions
  for each row execute function public._century_fields();

-- Les questions existantes : le déclencheur fait le travail.
update public.questions set payload = payload
where type = 'mcq' and payload::text ~ 'siècle';

-- Correction : une frise envoie {"century": n}, juste si c'est le bon siècle.
create or replace function public._evaluate(p_type question_type, p_answer jsonb, p_given jsonb)
returns boolean language plpgsql immutable set search_path = public, extensions, pg_temp as $$
declare v bool;
begin
  if p_given is null or jsonb_typeof(p_given) <> 'object' then return false; end if;
  case p_type
    when 'mcq', 'map_pick' then
      if p_given ? 'century' then
        v := p_type = 'mcq' and jsonb_typeof(p_given -> 'century') = 'number' and p_answer ? 'century'
             and (p_given ->> 'century')::numeric = (p_answer ->> 'century')::numeric;
      else
        v := (p_given ->> 'option_id') = (p_answer ->> 'option_id');
      end if;
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
end $$;

revoke execute on function public._roman_to_int(text), public._century_of(text), public._century_fields()
  from public, anon, authenticated;
