-- CULT FIVE — 0010 Anti-répétition
-- « Famille » d'une question = son moule (capitale, drapeau, silhouette…). Les questions générées en ont une.
-- Jouer : jamais deux questions de la même famille d'affilée, au plus deux par série.
-- Daily : une seule question par famille.

alter table public.questions add column family text check (family ~ '^[a-z_]+$');
create index questions_family on public.questions (family) where family is not null;

create or replace function public._upsert_question(p jsonb, p_origin public.question_origin, p_batch uuid) returns uuid
language plpgsql as $$
declare
  v_id uuid := (p ->> 'id')::uuid;
  v_concept text := p ->> 'concept_id';
  v_status public.question_status := coalesce(p ->> 'status', 'draft')::public.question_status;
  v_init real := coalesce((p ->> 'difficulty')::real, 50);
begin
  if v_concept is null then raise exception 'concept_required'; end if;
  insert into public.concepts (id, subdomain_id, label)
  values (v_concept, split_part(v_concept, '.', 1) || '.' || split_part(v_concept, '.', 2), coalesce(p ->> 'concept_label', v_concept))
  on conflict (id) do update set label = coalesce(p ->> 'concept_label', public.concepts.label);

  if p_origin = 'ai' and v_status = 'published' then v_status := 'review'; end if;

  if v_id is null and p ? 'external_key' then
    select id into v_id from public.questions where external_key = p ->> 'external_key';
  end if;

  if v_id is null then
    insert into public.questions (external_key, concept_id, subdomain_id, domain_id, type, prompt, payload, answer, explanation,
                                  takeaway, hint, context_note, source, fact_as_of, difficulty_initial, difficulty_min, difficulty_max,
                                  difficulty_observed, difficulty_var, status, origin, batch_id, family)
    values (p ->> 'external_key', v_concept, '-', '-', (p ->> 'type')::public.question_type, p ->> 'prompt',
            coalesce(p -> 'payload', '{}'::jsonb), p -> 'answer', p ->> 'explanation',
            p ->> 'takeaway', p ->> 'hint', p ->> 'context_note', p ->> 'source', (p ->> 'fact_as_of')::date,
            v_init, coalesce((p ->> 'difficulty_min')::real, greatest(v_init - 10, 0)),
            coalesce((p ->> 'difficulty_max')::real, least(v_init + 10, 100)),
            v_init, case when p_origin = 'ai' then 144 else 100 end, v_status, p_origin, p_batch, p ->> 'family')
    returning id into v_id;
  else
    -- La calibration observée n'est jamais écrasée par une édition.
    update public.questions set
      concept_id = v_concept,
      type = coalesce((p ->> 'type')::public.question_type, type),
      prompt = coalesce(p ->> 'prompt', prompt),
      payload = coalesce(p -> 'payload', payload),
      answer = coalesce(p -> 'answer', answer),
      explanation = coalesce(p ->> 'explanation', explanation),
      takeaway = case when p ? 'takeaway' then p ->> 'takeaway' else takeaway end,
      hint = case when p ? 'hint' then p ->> 'hint' else hint end,
      context_note = case when p ? 'context_note' then p ->> 'context_note' else context_note end,
      source = case when p ? 'source' then p ->> 'source' else source end,
      fact_as_of = case when p ? 'fact_as_of' then (p ->> 'fact_as_of')::date else fact_as_of end,
      difficulty_min = coalesce((p ->> 'difficulty_min')::real, difficulty_min),
      difficulty_max = coalesce((p ->> 'difficulty_max')::real, difficulty_max),
      family = case when p ? 'family' then p ->> 'family' else family end,
      status = case when origin = 'ai' and v_status = 'published' and status not in ('review', 'published') then 'review' else v_status end
    where id = v_id;
  end if;
  return v_id;
end $$;


create or replace function public._select_questions(
  p_user uuid, p_mode text, p_domain text, p_subdomain text, p_count int, p_exclude uuid[] default '{}')
returns uuid[] language plpgsql volatile as $$
declare
  v_result   uuid[] := '{}';
  v_concepts text[] := '{}';
  v_banned   uuid[] := public._protected_daily_questions() || coalesce(p_exclude, '{}');
  v_domain   text;
  v_last_dom text;
  v_scope    text;
  v_mu real; v_var real;
  v_band record;
  v_blo real; v_bhi real;
  v_widen real;
  v_pick uuid; v_concept text;
  v_level int;
  v_family text;
  v_families text[] := '{}';
begin
  for i in 1 .. least(greatest(p_count, 1), 20) loop
    v_domain := coalesce(p_domain, split_part(p_subdomain, '.', 1));
    if v_domain is null or v_domain = '' then
      v_domain := public._pick_domain(p_user, v_last_dom);
      exit when v_domain is null;
    end if;
    v_scope := coalesce(p_subdomain, v_domain);
    select k.mu, k.var into v_mu, v_var from public._skill_peek(p_user, v_scope) k;
    select * into v_band from public._band_bounds(p_mode);
    v_pick := null;

    -- Niveaux de repli : 0 bande exacte, 1 ±5, 2 ±10, 3 toute difficulté, 4 sans filtre de récence.
    for lvl in 0 .. 4 loop
      v_level := lvl;
      v_widen := case lvl when 0 then 0 when 1 then 5 when 2 then 10 else 1000 end;
      if v_band.explore then
        v_blo := v_mu - 25; v_bhi := v_mu + 25;
      else
        v_blo := v_mu - 10 * ln(v_band.hi / (1 - v_band.hi));
        v_bhi := v_mu - 10 * ln(v_band.lo / (1 - v_band.lo));
      end if;

      select q.id, q.concept_id, q.family into v_pick, v_concept, v_family
      from public.questions q
      where q.status = 'published'
        and q.domain_id = v_domain
        and (p_subdomain is null or q.subdomain_id = p_subdomain)
        and q.id <> all (v_result || v_banned)
        and q.concept_id <> all (v_concepts)
        -- Anti-répétition (niveaux 0 à 2) : pas la même famille que la question précédente, au plus 2 par série.
        and (lvl >= 3 or q.family is null or (
              q.family is distinct from v_families[cardinality(v_families)]
              and (select count(*) from unnest(v_families) f where f = q.family) < 2))
        and q.difficulty_effective between v_blo - v_widen and v_bhi + v_widen
        and (lvl = 4 or not exists (
              select 1 from public.user_concepts uc
              where uc.user_id = p_user and uc.concept_id = q.concept_id
                and uc.last_seen_at > public._now() - case when uc.last_correct_at = uc.last_seen_at
                                                      then interval '7 days' else interval '3 days' end))
      order by case when v_band.explore then q.answer_count else 0 end, random()
      limit 1;
      exit when v_pick is not null;
    end loop;

    if v_pick is not null then
      v_result := v_result || v_pick;
      v_concepts := v_concepts || v_concept;
      v_families := v_families || coalesce(v_family, '');
    elsif p_domain is not null or p_subdomain is not null then
      exit;  -- domaine épuisé
    end if;
    v_last_dom := v_domain;
  end loop;
  return v_result;
end $$;


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
  v_family text;
  v_families text[] := '{}';
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
      select q.id, q.concept_id, q.type, q.family into v_pick, v_concept, v_type, v_family
      from public.questions q
      join public.domains d on d.id = q.domain_id
      where q.status = 'published'
        and (lvl >= 1 or not q.needs_review)
        and (case when v_slots[i] = 'surprise' then d.daily_slot is null else d.daily_slot = v_slots[i] end)
        and (v_slots[i] <> 'surprise' or lvl >= 2 or q.domain_id = v_surprise_domain)
        and q.id <> all (v_used)
        and q.concept_id <> all (v_concepts)
        and (lvl >= 1 or q.family is null or q.family <> all (v_families))
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
               + 25 * (select count(*) from unnest(v_families) f where f = q.family)
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
    v_families := v_families || coalesce(v_family, '');
  end loop;
end $$;
