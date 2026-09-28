-- Brainlix — 0009 Équilibre
-- Le créneau « Surprise » du Daily tire d'abord un domaine au hasard (uniforme), puis une question dans ce domaine.
-- Sans cela, un domaine très fourni (ex. Arts après l'import Wikidata) serait presque toujours choisi.

create or replace function public._generate_daily_set(p_date date) returns void
language plpgsql as $$
declare
  v_slots    public.daily_slot[];
  v_targets  real[];
  v_types    public.question_type[] := '{}';
  v_used     uuid[] := '{}';
  v_concepts text[] := '{}';
  v_pick uuid; v_concept text; v_type public.question_type;
  v_surprise_domain text;
begin
  perform pg_advisory_xact_lock(hashtext('daily:' || p_date::text));
  if exists (select 1 from public.daily_sets where daily_date = p_date) then return; end if;

  select array_agg(s order by random()) into v_slots from unnest(enum_range(null::public.daily_slot)) s;
  select array_agg(t order by random()) into v_targets from unnest(array[35, 45, 50, 55, 65]::real[]) t;
  insert into public.daily_sets (daily_date) values (p_date);

  -- Surprise : on tire d'abord un domaine (uniforme), pour qu'un domaine très fourni ne l'emporte pas toujours.
  select d.id into v_surprise_domain from public.domains d
  where d.daily_slot is null and d.is_active
    and exists (select 1 from public.questions q where q.domain_id = d.id and q.status = 'published')
  order by random() limit 1;

  for i in 1 .. 5 loop
    v_pick := null;
    -- 0 : toutes contraintes · 1 : sans fenêtre 180/60 j (mais pas de question vue ces 14 j) · 2 : tout
    for lvl in 0 .. 2 loop
      select q.id, q.concept_id, q.type into v_pick, v_concept, v_type
      from public.questions q
      join public.domains d on d.id = q.domain_id
      where q.status = 'published'
        and (lvl >= 1 or not q.needs_review)
        and (case when v_slots[i] = 'surprise' then d.daily_slot is null else d.daily_slot = v_slots[i] end)
        and (v_slots[i] <> 'surprise' or lvl >= 2 or q.domain_id = v_surprise_domain)
        and q.id <> all (v_used)
        and q.concept_id <> all (v_concepts)
        and (lvl >= 1 or not exists (
              select 1 from public.daily_set_items i join public.questions q2 on q2.id = i.question_id
              where i.daily_date <> p_date and abs(i.daily_date - p_date) <= 180
                and (i.question_id = q.id or (q2.concept_id = q.concept_id and abs(i.daily_date - p_date) <= 60))))
        and (lvl >= 2 or not exists (
              select 1 from public.daily_set_items i
              where i.question_id = q.id and i.daily_date <> p_date and abs(i.daily_date - p_date) <= 14))
      -- Variété des types : pénalité douce (15 points par question déjà du même type), pas un filtre dur.
      order by abs(q.difficulty_effective - v_targets[i]) + random() * 8
               + 15 * (select count(*) from unnest(v_types) t where t = q.type)
      limit 1;
      exit when v_pick is not null;
    end loop;
    if v_pick is null then
      raise exception 'daily_generation_failed: no question for slot %', v_slots[i];
    end if;
    insert into public.daily_set_items (daily_date, position, slot, question_id) values (p_date, i, v_slots[i], v_pick);
    v_used := v_used || v_pick;
    v_concepts := v_concepts || v_concept;
    v_types := v_types || v_type;
  end loop;
end $$;
