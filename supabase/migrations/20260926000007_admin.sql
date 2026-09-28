-- Brainlix — 0007 Admin
-- RPC réservées aux administrateurs (table app_admins). Pipeline : draft → review → published ; disabled = retiré.
-- Une question générée par IA (origin = 'ai') ne peut jamais être publiée sans passer par une validation humaine explicite.

create table public.generation_batches (
  id          uuid primary key default gen_random_uuid(),
  created_by  uuid references auth.users(id) on delete set null,
  domain_id   text references public.domains(id),
  subdomain_id text references public.subdomains(id),
  requested   int not null,
  model       text,
  notes       text,
  created_at  timestamptz not null default now()
);

create table public.question_reviews (
  id           bigint generated always as identity primary key,
  question_id  uuid not null references public.questions(id) on delete cascade,
  reviewer_id  uuid references auth.users(id) on delete set null,
  action       text not null check (action in ('approve', 'reject', 'edit', 'disable', 'publish')),
  note         text,
  created_at   timestamptz not null default now()
);

-- Insertion / mise à jour d'une question (clé : id ou external_key). Le concept est créé si besoin.
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
                                  difficulty_observed, difficulty_var, status, origin, batch_id)
    values (p ->> 'external_key', v_concept, '-', '-', (p ->> 'type')::public.question_type, p ->> 'prompt',
            coalesce(p -> 'payload', '{}'::jsonb), p -> 'answer', p ->> 'explanation',
            p ->> 'takeaway', p ->> 'hint', p ->> 'context_note', p ->> 'source', (p ->> 'fact_as_of')::date,
            v_init, coalesce((p ->> 'difficulty_min')::real, greatest(v_init - 10, 0)),
            coalesce((p ->> 'difficulty_max')::real, least(v_init + 10, 100)),
            v_init, case when p_origin = 'ai' then 144 else 100 end, v_status, p_origin, p_batch)
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
      status = case when origin = 'ai' and v_status = 'published' and status not in ('review', 'published') then 'review' else v_status end
    where id = v_id;
  end if;
  return v_id;
end $$;

create or replace function public.admin_question_upsert(p jsonb) returns uuid
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_admin uuid := public._require_admin(); v_id uuid;
begin
  v_id := public._upsert_question(p, 'human', null);
  insert into public.question_reviews (question_id, reviewer_id, action) values (v_id, v_admin, 'edit');
  return v_id;
end $$;

-- Import en masse (JSON du dépôt ou fichier externe). origin = 'import' ou 'ai' (lot généré).
create or replace function public.admin_import(p_questions jsonb, p_origin public.question_origin default 'import',
                                               p_batch uuid default null) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_admin uuid := public._require_admin(); v_n int := 0; q jsonb; v_errors jsonb := '[]'::jsonb;
begin
  for q in select * from jsonb_array_elements(p_questions) loop
    begin
      perform public._upsert_question(q, p_origin, p_batch);
      v_n := v_n + 1;
    exception when others then
      v_errors := v_errors || jsonb_build_object('external_key', q ->> 'external_key', 'error', sqlerrm);
    end;
  end loop;
  return jsonb_build_object('imported', v_n, 'errors', v_errors);
end $$;

create or replace function public.admin_question_set_status(p_id uuid, p_status public.question_status, p_note text default null)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare v_admin uuid := public._require_admin();
begin
  update public.questions set status = p_status,
    needs_review = case when p_status = 'published' then false else needs_review end,
    review_reason = case when p_status = 'published' then null else review_reason end
  where id = p_id;
  if not found then raise exception 'question_not_found'; end if;
  insert into public.question_reviews (question_id, reviewer_id, action, note)
  values (p_id, v_admin, case p_status when 'published' then 'publish' when 'disabled' then 'disable'
                                       when 'draft' then 'reject' else 'approve' end, p_note);
end $$;

create or replace function public.admin_questions(p_filter jsonb default '{}'::jsonb, p_limit int default 50, p_offset int default 0)
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  perform public._require_admin();
  return (select jsonb_build_object(
    'total', (select count(*) from public.questions q where
                (p_filter ->> 'domain_id' is null or q.domain_id = p_filter ->> 'domain_id')
            and (p_filter ->> 'subdomain_id' is null or q.subdomain_id = p_filter ->> 'subdomain_id')
            and (p_filter ->> 'status' is null or q.status::text = p_filter ->> 'status')
            and (p_filter ->> 'type' is null or q.type::text = p_filter ->> 'type')
            and (p_filter ->> 'needs_review' is null or q.needs_review = (p_filter ->> 'needs_review')::bool)
            and (p_filter ->> 'search' is null or q.prompt ilike '%' || (p_filter ->> 'search') || '%')
            and (p_filter ->> 'min_difficulty' is null or q.difficulty_effective >= (p_filter ->> 'min_difficulty')::real)
            and (p_filter ->> 'max_difficulty' is null or q.difficulty_effective <= (p_filter ->> 'max_difficulty')::real)
            and (p_filter ->> 'created_after' is null or q.created_at >= (p_filter ->> 'created_after')::timestamptz)),
    'items', coalesce((select jsonb_agg(to_jsonb(t) order by t.created_at desc) from (
        select q.* from public.questions q where
                (p_filter ->> 'domain_id' is null or q.domain_id = p_filter ->> 'domain_id')
            and (p_filter ->> 'subdomain_id' is null or q.subdomain_id = p_filter ->> 'subdomain_id')
            and (p_filter ->> 'status' is null or q.status::text = p_filter ->> 'status')
            and (p_filter ->> 'type' is null or q.type::text = p_filter ->> 'type')
            and (p_filter ->> 'needs_review' is null or q.needs_review = (p_filter ->> 'needs_review')::bool)
            and (p_filter ->> 'search' is null or q.prompt ilike '%' || (p_filter ->> 'search') || '%')
            and (p_filter ->> 'min_difficulty' is null or q.difficulty_effective >= (p_filter ->> 'min_difficulty')::real)
            and (p_filter ->> 'max_difficulty' is null or q.difficulty_effective <= (p_filter ->> 'max_difficulty')::real)
            and (p_filter ->> 'created_after' is null or q.created_at >= (p_filter ->> 'created_after')::timestamptz)
        order by q.created_at desc limit least(p_limit, 200) offset p_offset) t), '[]'::jsonb)));
end $$;

create or replace function public.admin_dashboard() returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  perform public._require_admin();
  return jsonb_build_object(
    'questions_by_status', (select jsonb_object_agg(status, n) from (select status, count(*) n from public.questions group by 1) t),
    'published_by_domain', (select jsonb_object_agg(domain_id, n) from (select domain_id, count(*) n from public.questions
                                                                         where status = 'published' group by 1) t),
    'needs_review', (select count(*) from public.questions where needs_review),
    'users', (select count(*) from public.profiles),
    'daily_players_today', (select count(*) from public.daily_runs where daily_date = current_date and status = 'finished'),
    'upcoming_dailies', (select coalesce(jsonb_agg(daily_date order by daily_date), '[]'::jsonb) from public.daily_sets where daily_date >= current_date));
end $$;

create or replace function public.admin_daily_get(p_date date) returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  perform public._require_admin();
  return (select jsonb_build_object('date', p_date,
            'runs_started', (select count(*) from public.daily_runs where daily_date = p_date),
            'items', coalesce(jsonb_agg(jsonb_build_object('position', i.position, 'slot', i.slot, 'replaced_at', i.replaced_at,
                                                           'question', to_jsonb(q)) order by i.position), '[]'::jsonb))
          from public.daily_set_items i join public.questions q on q.id = i.question_id where i.daily_date = p_date);
end $$;

create or replace function public.admin_daily_generate(p_date date) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  perform public._require_admin();
  perform public._ensure_daily_set(p_date);
  return public.admin_daily_get(p_date);
end $$;

-- Remplacement manuel : interdit dès qu'un joueur a commencé cette date (équité), sauf p_force.
create or replace function public.admin_daily_replace(p_date date, p_position int, p_question uuid, p_force bool default false)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
begin
  perform public._require_admin();
  if not p_force and exists (select 1 from public.daily_runs where daily_date = p_date) then
    raise exception 'daily_already_started';
  end if;
  if not exists (select 1 from public.questions where id = p_question and status = 'published') then
    raise exception 'question_not_published';
  end if;
  update public.daily_set_items set question_id = p_question, replaced_at = now() where daily_date = p_date and position = p_position;
  if not found then raise exception 'daily_item_not_found'; end if;
  update public.daily_sets set source = 'manual' where daily_date = p_date;
  return public.admin_daily_get(p_date);
end $$;

create or replace function public.admin_batch_create(p_domain text, p_subdomain text, p_requested int, p_model text, p_notes text)
returns uuid language plpgsql security definer set search_path = public, pg_temp as $$
declare v_id uuid;
begin
  insert into public.generation_batches (created_by, domain_id, subdomain_id, requested, model, notes)
  values (public._require_admin(), p_domain, p_subdomain, p_requested, p_model, p_notes) returning id into v_id;
  return v_id;
end $$;
