-- CULT FIVE — 0002 Learning
-- Compétences adaptatives, calibration des questions, erreurs par concept, historique des tentatives.
-- Modèle : Rasch + mise à jour bayésienne approchée (Glicko-1). Voir docs/ADAPTIVE.md.

create table public.user_skills (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  scope_id   text not null,                                  -- id de domaine ou de sous-domaine
  is_domain  bool generated always as (position('.' in scope_id) = 0) stored,
  mu         real not null,
  var        real not null,
  n          int  not null default 0,
  correct    int  not null default 0,
  total_ms   bigint not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, scope_id)
);

-- Un point par jour et par domaine : courbe d'évolution sans rejouer l'historique.
create table public.user_skill_snapshots (
  user_id  uuid not null references public.profiles(id) on delete cascade,
  scope_id text not null,
  day      date not null,
  mu       real not null,
  var      real not null,
  primary key (user_id, scope_id, day)
);

create table public.user_concepts (
  user_id          uuid not null references public.profiles(id) on delete cascade,
  concept_id       text not null references public.concepts(id),
  seen             int  not null default 0,
  correct          int  not null default 0,
  last_seen_at     timestamptz,
  last_correct_at  timestamptz,
  last_wrong_at    timestamptz,
  error_state      public.error_state,
  error_since      timestamptz,
  corrected_at     timestamptz,
  error_count      int  not null default 0,
  primary key (user_id, concept_id)
);
create index user_concepts_active_errors on public.user_concepts (user_id, error_since)
  where error_state in ('failed', 'to_review');

create table public.question_attempts (
  id                   bigint generated always as identity primary key,
  client_attempt_id    uuid unique,
  user_id              uuid not null references public.profiles(id) on delete cascade,
  question_id          uuid not null references public.questions(id),
  concept_id           text not null,
  context              public.attempt_context not null,
  session_id           uuid,
  given                jsonb,
  is_correct           bool not null,
  response_ms          int,
  question_difficulty  real not null,
  user_skill_before    real not null,
  expected             real not null,
  seen_count           int  not null,
  created_at           timestamptz not null default now()
);
create index on public.question_attempts (user_id, created_at desc);
create index on public.question_attempts (user_id, question_id);
create index on public.question_attempts (question_id);

-- ─────────────────────────────────────────── Constantes du modèle
create or replace function public._c(p_key text) returns real
language sql immutable as $$
  select case p_key
    when 'S'            then 10     -- points par logit
    when 'user_var0'    then 100    -- σ₀ = 10
    when 'user_var_min' then 9      -- σ ≥ 3
    when 'user_step'    then 4      -- variation max par réponse
    when 'q_var_min'    then 4      -- σ_b ≥ 2
    when 'q_step'       then 4
    when 'reinflate'    then 0.5    -- σ² ajouté par jour d'inactivité
  end::real
$$;

create or replace function public._g(p_var real) returns double precision
language sql immutable as $$
  select 1.0 / sqrt(1.0 + 3.0 * p_var / (pi() ^ 2 * 100.0))
$$;

-- Probabilité que l'utilisateur (μ) réussisse la question (b, σ_b²).
create or replace function public._expect(p_mu real, p_b real, p_var_opp real) returns double precision
language sql immutable as $$
  select 1.0 / (1.0 + exp(-public._g(p_var_opp) * (p_mu - p_b) / 10.0))
$$;

-- ─────────────────────────────────────────── Évaluation d'une réponse
create or replace function public._evaluate(p_type public.question_type, p_answer jsonb, p_given jsonb) returns bool
language plpgsql immutable as $$
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
  end case;
  return coalesce(v, false);  -- réponse absente ou malformée ⇒ fausse
exception when others then
  return false;
end $$;

-- ─────────────────────────────────────────── Compétences
-- Lecture sans écriture (prior hiérarchique : sous-domaine ← domaine ← choix d'onboarding).
create or replace function public._skill_peek(p_user uuid, p_scope text, out mu real, out var real)
language plpgsql stable as $$
declare
  v_days real;
begin
  select s.mu, s.var, extract(epoch from public._now() - s.updated_at) / 86400
    into mu, var, v_days
  from public.user_skills s where s.user_id = p_user and s.scope_id = p_scope;
  if found then
    var := least(var + public._c('reinflate') * greatest(v_days, 0), public._c('user_var0'));
    return;
  end if;
  if position('.' in p_scope) > 0 then
    select d.mu, d.var into mu, var from public._skill_peek(p_user, split_part(p_scope, '.', 1)) d;
    var := greatest(var, 64);
  else
    select p.challenge_prior into mu from public.profiles p where p.id = p_user;
    mu := coalesce(mu, 50);
    var := public._c('user_var0');
  end if;
end $$;

-- Met à jour une compétence après une réponse. Renvoie μ avant/après.
create or replace function public._skill_update(
  p_user uuid, p_scope text, p_b real, p_var_b real, p_correct bool, p_ms int,
  out mu_before real, out var_before real, out mu_after real, out var_after real, out expected real)
language plpgsql as $$
declare
  v_g double precision := public._g(p_var_b);
  v_e double precision;
  v_i double precision;
  v_delta double precision;
  v_step real := public._c('user_step');
begin
  select k.mu, k.var into mu_before, var_before from public._skill_peek(p_user, p_scope) k;
  v_e := public._expect(mu_before, p_b, p_var_b);
  v_i := v_g ^ 2 * v_e * (1 - v_e) / 100.0;
  var_after := greatest(1.0 / (1.0 / var_before + v_i), public._c('user_var_min'));
  v_delta := var_after * v_g * ((case when p_correct then 1 else 0 end) - v_e) / 10.0;
  v_delta := least(greatest(v_delta, -v_step), v_step);
  mu_after := least(greatest(mu_before + v_delta, 0), 100);
  expected := v_e;

  insert into public.user_skills as s (user_id, scope_id, mu, var, n, correct, total_ms, updated_at)
  values (p_user, p_scope, mu_after, var_after, 1, p_correct::int, coalesce(p_ms, 0), public._now())
  on conflict (user_id, scope_id) do update
    set mu = excluded.mu, var = excluded.var, n = s.n + 1, correct = s.correct + excluded.correct,
        total_ms = s.total_ms + excluded.total_ms, updated_at = excluded.updated_at;

  insert into public.user_skill_snapshots (user_id, scope_id, day, mu, var)
  values (p_user, p_scope, (public._now() at time zone 'UTC')::date, mu_after, var_after)
  on conflict (user_id, scope_id, day) do update set mu = excluded.mu, var = excluded.var;
end $$;

-- Calibration d'une question après une réponse (symétrique, pondérée par l'incertitude du joueur).
create or replace function public._question_update(p_question uuid, p_mu_user real, p_var_user real, p_correct bool)
returns void language plpgsql as $$
declare
  q public.questions;
  v_g double precision := public._g(p_var_user);
  v_e double precision;
  v_i double precision;
  v_var double precision;
  v_b double precision;
  v_delta double precision;
  v_n int;
  v_sd double precision;
  v_min real; v_max real; v_widen int;
  v_review bool; v_reason text;
begin
  select * into q from public.questions where id = p_question for update;
  -- E = probabilité de bonne réponse, calculée sur la difficulté observée (estimation propre de la question).
  v_e := 1.0 / (1.0 + exp(-v_g * (p_mu_user - q.difficulty_observed) / 10.0));
  v_i := v_g ^ 2 * v_e * (1 - v_e) / 100.0;
  v_var := greatest(1.0 / (1.0 / q.difficulty_var + v_i), public._c('q_var_min'));
  v_delta := v_var * v_g * (v_e - (case when p_correct then 1 else 0 end)) / 10.0;
  v_delta := least(greatest(v_delta, -public._c('q_step')), public._c('q_step'));
  v_b := least(greatest(q.difficulty_observed + v_delta, 0), 100);
  v_n := q.answer_count + 1;
  v_sd := sqrt(v_var);

  -- Élargissement prudent de la plage : n ≥ 300, hors plage de plus de 2σ, au plus une fois par 100 réponses.
  v_min := q.difficulty_min; v_max := q.difficulty_max; v_widen := q.last_widen_count;
  if v_n >= 300 and v_n - q.last_widen_count >= 100 then
    if v_b > v_max + 2 * v_sd then
      v_max := least(v_max + 5, 100); v_widen := v_n;
    elsif v_b < v_min - 2 * v_sd then
      v_min := greatest(v_min - 5, 0); v_widen := v_n;
    end if;
  end if;

  v_review := q.needs_review; v_reason := q.review_reason;
  if not v_review and v_n >= 50 then
    if (q.correct_count + p_correct::int)::real / v_n < 0.05 then
      v_review := true; v_reason := 'success_rate_below_5';
    elsif (q.correct_count + p_correct::int)::real / v_n > 0.99 then
      v_review := true; v_reason := 'success_rate_above_99';
    end if;
  end if;
  if not v_review and q.range_widenings + (v_widen <> q.last_widen_count)::int >= 3 then
    v_review := true; v_reason := 'range_widened_3_times';
  end if;

  update public.questions set
    difficulty_observed = v_b,
    difficulty_var      = v_var,
    difficulty_min      = v_min,
    difficulty_max      = v_max,
    answer_count        = v_n,
    correct_count       = correct_count + p_correct::int,
    range_widenings     = range_widenings + (v_widen <> q.last_widen_count)::int,
    last_widen_count    = v_widen,
    needs_review        = v_review,
    review_reason       = v_reason
  where id = p_question;
end $$;

-- ─────────────────────────────────────────── Enregistrement d'une tentative (point d'entrée unique)
-- Utilisé par le Daily, Jouer, Erreurs, Défi, onboarding. Idempotent via p_client_id.
-- Renvoie : is_correct, duplicate, error_transition (new_error | still_wrong | corrected | mastered | null),
--           domain_before/after, expected.
create or replace function public._record_attempt(
  p_user uuid, p_question uuid, p_given jsonb, p_ms int,
  p_context public.attempt_context, p_session uuid, p_client_id uuid)
returns jsonb language plpgsql as $$
declare
  q public.questions;
  v_prev public.question_attempts;
  v_correct bool;
  v_dom record;
  v_sub record;
  v_uc public.user_concepts;
  v_state public.error_state;
  v_transition text;
  v_now timestamptz := public._now();
  v_seen int;
begin
  if p_client_id is not null then
    select * into v_prev from public.question_attempts where client_attempt_id = p_client_id;
    if found then
      if v_prev.user_id <> p_user then raise exception 'attempt_conflict'; end if;
      return jsonb_build_object('duplicate', true, 'is_correct', v_prev.is_correct);
    end if;
  end if;

  select * into q from public.questions where id = p_question;
  if not found then raise exception 'question_not_found'; end if;

  v_correct := public._evaluate(q.type, q.answer, p_given);

  -- Sous-domaine d'abord : son prior dérive du domaine *avant* cette réponse.
  select * into v_sub from public._skill_update(p_user, q.subdomain_id, q.difficulty_effective, q.difficulty_var, v_correct, p_ms);
  select * into v_dom from public._skill_update(p_user, q.domain_id,    q.difficulty_effective, q.difficulty_var, v_correct, p_ms);
  perform public._question_update(q.id, v_sub.mu_before, v_sub.var_before, v_correct);

  -- Concept & erreurs
  select * into v_uc from public.user_concepts where user_id = p_user and concept_id = q.concept_id for update;
  v_state := v_uc.error_state;
  if not v_correct then
    if v_state = 'failed' and p_context = 'errors' then
      v_state := 'to_review'; v_transition := 'still_wrong';
    elsif v_state in ('failed', 'to_review') then
      v_transition := 'still_wrong';
    else
      v_state := 'failed'; v_transition := 'new_error';
    end if;
  else
    if v_state in ('failed', 'to_review') then
      v_state := 'correct_once'; v_transition := 'corrected';
    elsif v_state = 'correct_once' and v_uc.corrected_at < v_now - interval '3 days' then
      v_state := 'mastered'; v_transition := 'mastered';
    end if;
  end if;

  insert into public.user_concepts as uc (user_id, concept_id, seen, correct, last_seen_at, last_correct_at, last_wrong_at,
                                          error_state, error_since, corrected_at, error_count)
  values (p_user, q.concept_id, 1, v_correct::int, v_now,
          case when v_correct then v_now end, case when not v_correct then v_now end,
          v_state, case when v_transition = 'new_error' then v_now end, null,
          case when v_transition = 'new_error' then 1 else 0 end)
  on conflict (user_id, concept_id) do update set
    seen            = uc.seen + 1,
    correct         = uc.correct + v_correct::int,
    last_seen_at    = v_now,
    last_correct_at = case when v_correct then v_now else uc.last_correct_at end,
    last_wrong_at   = case when not v_correct then v_now else uc.last_wrong_at end,
    error_state     = v_state,
    error_since     = case when v_transition = 'new_error' then v_now else uc.error_since end,
    corrected_at    = case when v_transition = 'corrected' then v_now else uc.corrected_at end,
    error_count     = uc.error_count + (v_transition is not distinct from 'new_error')::int;

  select count(*) + 1 into v_seen from public.question_attempts where user_id = p_user and question_id = q.id;

  insert into public.question_attempts (client_attempt_id, user_id, question_id, concept_id, context, session_id, given,
                                        is_correct, response_ms, question_difficulty, user_skill_before, expected, seen_count, created_at)
  values (p_client_id, p_user, q.id, q.concept_id, p_context, p_session, p_given,
          v_correct, p_ms, q.difficulty_effective, v_sub.mu_before, v_sub.expected, v_seen, v_now);

  update public.profiles set
    questions_answered = questions_answered + 1,
    questions_correct  = questions_correct + v_correct::int,
    errors_corrected   = errors_corrected + (v_transition is not distinct from 'corrected')::int
  where id = p_user;

  return jsonb_build_object(
    'duplicate', false,
    'is_correct', v_correct,
    'error_transition', v_transition,
    'error_since', v_uc.error_since,
    'domain_id', q.domain_id,
    'domain_before', round(v_dom.mu_before::numeric, 1),
    'domain_after', round(v_dom.mu_after::numeric, 1),
    'expected', round(v_sub.expected::numeric, 3));
end $$;

-- ─────────────────────────────────────────── Sélection adaptative
-- Questions des Daily en cours ou à venir : jamais servies ailleurs (fuite de réponses).
-- (définie ici en stub, remplacée dans la migration Daily)
create or replace function public._protected_daily_questions() returns uuid[]
language sql stable as $$ select '{}'::uuid[] $$;

create or replace function public._band_bounds(p_mode text, out lo real, out hi real, out explore bool)
language plpgsql volatile as $$
declare r double precision := random();
begin
  explore := false;
  if p_mode = 'challenge' then
    if r < 0.60 then lo := 0.45; hi := 0.65;
    elsif r < 0.85 then lo := 0.30; hi := 0.45;
    elsif r < 0.95 then lo := 0.65; hi := 0.80;
    else explore := true; end if;
  else
    if r < 0.60 then lo := 0.60; hi := 0.80;
    elsif r < 0.80 then lo := 0.80; hi := 0.93;
    elsif r < 0.95 then lo := 0.40; hi := 0.60;
    else explore := true; end if;
  end if;
end $$;

-- Choisit un domaine pour une partie mixte : pondéré par les centres d'intérêt, sans répéter le précédent.
create or replace function public._pick_domain(p_user uuid, p_avoid text) returns text
language sql volatile as $$
  select d.id
  from public.domains d
  left join public.profiles p on p.id = p_user
  where d.is_active
    and d.id is distinct from p_avoid
    and exists (select 1 from public.questions q where q.domain_id = d.id and q.status = 'published')
  order by -ln(random()) / (case when d.id = any(coalesce(p.interests, '{}')) then 2.0 else 1.0 end)
  limit 1
$$;

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

      select q.id, q.concept_id into v_pick, v_concept
      from public.questions q
      where q.status = 'published'
        and q.domain_id = v_domain
        and (p_subdomain is null or q.subdomain_id = p_subdomain)
        and q.id <> all (v_result || v_banned)
        and q.concept_id <> all (v_concepts)
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
    elsif p_domain is not null or p_subdomain is not null then
      exit;  -- domaine épuisé
    end if;
    v_last_dom := v_domain;
  end loop;
  return v_result;
end $$;

-- Mes erreurs : une question par concept actif, de préférence une autre formulation que la dernière vue.
create or replace function public._select_error_questions(p_user uuid, p_count int) returns uuid[]
language sql volatile as $$
  with active as (
    select uc.concept_id, uc.error_since
    from public.user_concepts uc
    where uc.user_id = p_user and uc.error_state in ('failed', 'to_review')
    order by uc.error_since
    limit least(greatest(p_count, 1), 20)
  ), pick as (
    select distinct on (a.concept_id) a.concept_id, a.error_since, q.id
    from active a
    join public.questions q on q.concept_id = a.concept_id and q.status = 'published'
    where q.id <> all (public._protected_daily_questions())
    order by a.concept_id,
             (select max(qa.created_at) from public.question_attempts qa
              where qa.user_id = p_user and qa.question_id = q.id) nulls first,
             random()
  )
  select coalesce(array_agg(id order by error_since), '{}') from pick
$$;
