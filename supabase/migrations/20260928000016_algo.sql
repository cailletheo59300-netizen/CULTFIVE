-- CULT FIVE — 0016 Algo : hasard, thèmes équilibrés, révision espacée
-- 1. Hasard (modèle à 3 paramètres simplifié) : un QCM à n choix se réussit 1 fois sur n sans rien savoir, un Vrai/Faux
--    une fois sur 2. P(juste) = c + (1 − c) · logistique. Une bonne réponse devinable fait moins monter la cote,
--    une erreur sur une question devinable la fait davantage baisser ; la calibration des questions aussi.
-- 2. Thèmes équilibrés : chaque question d'une partie de domaine commence par tirer un thème (le moins servi, léger bonus
--    aux thèmes incertains), puis la question dans la fenêtre de cote du thème.
-- 3. Révision espacée des erreurs : échéances 1 j, 3 j, 7 j, 21 j ; maîtrisée à la 4e bonne réponse à l'heure.
--    Une révision due se glisse dans les parties adaptatives du domaine (au plus une), et dans « Mes erreurs ».

-- ─────────────────────────────────────────── Hasard
create or replace function public._guess_rate(p_type public.question_type, p_payload jsonb) returns real
language sql immutable as $$
  select case
    when p_type in ('mcq', 'map_pick') then 1.0 / greatest(coalesce(jsonb_array_length(p_payload -> 'options'), 4), 2)
    when p_type = 'true_false' then 0.5
    else 0 end::real
$$;

alter table public.questions add column guess_rate real generated always as (public._guess_rate(type, payload)) stored;

-- Probabilité de bonne réponse, hasard compris.
create or replace function public._expect_q(p_mu real, p_b real, p_var_opp real, p_guess real) returns double precision
language sql immutable as $$
  select coalesce(p_guess, 0) + (1 - coalesce(p_guess, 0)) * public._expect(p_mu, p_b, p_var_opp)
$$;

drop function public._skill_update(uuid, text, real, real, bool, int);
create or replace function public._skill_update(
  p_user uuid, p_scope text, p_b real, p_var_b real, p_correct bool, p_ms int, p_guess real default 0,
  out mu_before real, out var_before real, out mu_after real, out var_after real, out expected real)
language plpgsql as $$
declare
  v_g double precision := public._g(p_var_b);
  v_c double precision := coalesce(p_guess, 0);
  v_s double precision;   -- probabilité « sans hasard » (savoir)
  v_e double precision;   -- probabilité observable (avec hasard)
  v_dp double precision;  -- dérivée de v_e par rapport au niveau
  v_i double precision;
  v_delta double precision;
  v_n int;
  v_step real;
begin
  select k.mu, k.var into mu_before, var_before from public._skill_peek(p_user, p_scope) k;
  select coalesce((select n from public.user_skills where user_id = p_user and scope_id = p_scope), 0) into v_n;
  v_step := public._c('user_step') * case when v_n < public._c_placement() then 2 else 1 end;
  v_s := public._expect(mu_before, p_b, p_var_b);
  v_e := v_c + (1 - v_c) * v_s;
  -- Vraisemblance à 3 paramètres (c fixé) : information et pas de Newton. c = 0 redonne exactement Rasch/Glicko.
  v_dp := (1 - v_c) * v_s * (1 - v_s) * v_g / 10.0;
  v_i := v_dp ^ 2 / (v_e * (1 - v_e));
  var_after := greatest(1.0 / (1.0 / var_before + v_i), public._c('user_var_min'));
  v_delta := var_after * v_dp * ((case when p_correct then 1 else 0 end) - v_e) / (v_e * (1 - v_e));
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

-- Calibration des questions : même vraisemblance à 3 paramètres (hasard de la question).
create or replace function public._question_update(p_question uuid, p_mu_user real, p_var_user real, p_correct bool)
returns void language plpgsql as $$
declare
  q public.questions;
  v_g double precision := public._g(p_var_user);
  v_c double precision;
  v_s double precision;
  v_e double precision;
  v_dp double precision;
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
  v_c := coalesce(q.guess_rate, 0);
  v_s := 1.0 / (1.0 + exp(-v_g * (p_mu_user - q.difficulty_observed) / 10.0));
  v_e := v_c + (1 - v_c) * v_s;
  v_dp := (1 - v_c) * v_s * (1 - v_s) * v_g / 10.0;
  v_i := v_dp ^ 2 / (v_e * (1 - v_e));
  v_var := greatest(1.0 / (1.0 / q.difficulty_var + v_i), public._c('q_var_min'));
  v_delta := v_var * v_dp * (v_e - (case when p_correct then 1 else 0 end)) / (v_e * (1 - v_e));
  v_delta := least(greatest(v_delta, -public._c('q_step')), public._c('q_step'));
  v_b := least(greatest(q.difficulty_observed + v_delta, 0), 100);
  v_n := q.answer_count + 1;
  v_sd := sqrt(v_var);

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

-- Difficulté b qui donne une chance réelle p (hasard c compris) à un joueur de niveau μ.
create or replace function public._b_for_p(p_mu real, p_p real, p_guess real) returns real
language sql immutable as $$
  select (p_mu - 10 * ln(k / (1 - k)))::real
  from (select least(greatest((p_p - coalesce(p_guess, 0)) / (1 - coalesce(p_guess, 0)), 0.02), 0.98) as k) t
$$;

-- ─────────────────────────────────────────── Révision espacée
alter table public.user_concepts
  add column review_step int not null default 0,
  add column review_due  timestamptz;
-- Erreurs existantes : dues tout de suite.
update public.user_concepts set review_due = coalesce(error_since, last_seen_at) + interval '1 day'
where error_state in ('failed', 'to_review');
update public.user_concepts set review_step = 1, review_due = corrected_at + interval '3 days'
where error_state = 'correct_once';
create index user_concepts_review_due on public.user_concepts (user_id, review_due) where review_due is not null;

-- ─────────────────────────────────────────── Tentative (hasard + révision espacée)
create or replace function public._record_attempt(
  p_user uuid, p_question uuid, p_given jsonb, p_ms int,
  p_context public.attempt_context, p_session uuid, p_client_id uuid, p_ranked bool default true)
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
  v_step int;
  v_due timestamptz;
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

  if p_ranked then
    -- Sous-domaine d'abord : son prior dérive du domaine *avant* cette réponse.
    select * into v_sub from public._skill_update(p_user, q.subdomain_id, q.difficulty_effective, q.difficulty_var, v_correct, p_ms, q.guess_rate);
    select * into v_dom from public._skill_update(p_user, q.domain_id,    q.difficulty_effective, q.difficulty_var, v_correct, p_ms, q.guess_rate);
    perform public._question_update(q.id, v_sub.mu_before, v_sub.var_before, v_correct);
  else
    -- Entraînement libre : le niveau ne bouge pas, la difficulté des questions non plus (échantillon biaisé par le choix du joueur).
    select k.mu as mu_before, k.var as var_before, k.mu as mu_after, k.var as var_after,
           public._expect_q(k.mu, q.difficulty_effective, q.difficulty_var, q.guess_rate)::real as expected
      into v_sub from public._skill_peek(p_user, q.subdomain_id) k;
    select k.mu as mu_before, k.var as var_before, k.mu as mu_after, k.var as var_after, null::real as expected
      into v_dom from public._skill_peek(p_user, q.domain_id) k;
  end if;

  -- Concept & erreurs
  select * into v_uc from public.user_concepts where user_id = p_user and concept_id = q.concept_id for update;
  v_state := v_uc.error_state;
  v_step := coalesce(v_uc.review_step, 0);
  v_due := v_uc.review_due;
  -- Révision espacée : une erreur revient 1 jour après, puis 3, 7 et 21 jours après chaque bonne réponse « à l'heure ».
  -- Réussir avant l'échéance ne fait pas avancer (on vérifie la mémoire, pas la mémoire immédiate).
  if not v_correct then
    if v_state = 'failed' and p_context = 'errors' then
      v_state := 'to_review'; v_transition := 'still_wrong';
    elsif v_state in ('failed', 'to_review') then
      v_transition := 'still_wrong';
    else
      v_state := 'failed'; v_transition := 'new_error';
    end if;
    v_step := 0; v_due := v_now + interval '1 day';
  else
    if v_state in ('failed', 'to_review') then
      v_state := 'correct_once'; v_transition := 'corrected';
      v_step := 1; v_due := v_now + interval '3 days';
    elsif v_state = 'correct_once' and (v_due is null or v_due <= v_now) then
      v_step := v_step + 1;
      if v_step >= 4 then
        v_state := 'mastered'; v_transition := 'mastered'; v_due := null;
      else
        v_due := v_now + case v_step when 2 then interval '7 days' else interval '21 days' end;
      end if;
    end if;
  end if;

  insert into public.user_concepts as uc (user_id, concept_id, seen, correct, last_seen_at, last_correct_at, last_wrong_at,
                                          error_state, error_since, corrected_at, error_count, review_step, review_due)
  values (p_user, q.concept_id, 1, v_correct::int, v_now,
          case when v_correct then v_now end, case when not v_correct then v_now end,
          v_state, case when v_transition = 'new_error' then v_now end, null,
          case when v_transition = 'new_error' then 1 else 0 end, v_step, v_due)
  on conflict (user_id, concept_id) do update set
    seen            = uc.seen + 1,
    correct         = uc.correct + v_correct::int,
    last_seen_at    = v_now,
    last_correct_at = case when v_correct then v_now else uc.last_correct_at end,
    last_wrong_at   = case when not v_correct then v_now else uc.last_wrong_at end,
    error_state     = v_state,
    error_since     = case when v_transition = 'new_error' then v_now else uc.error_since end,
    corrected_at    = case when v_transition = 'corrected' then v_now else uc.corrected_at end,
    error_count     = uc.error_count + (v_transition is not distinct from 'new_error')::int,
    review_step     = v_step,
    review_due      = v_due;

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

-- ─────────────────────────────────────────── Sélection (thèmes équilibrés + révision due)
create or replace function public._select_questions(
  p_user uuid, p_mode text, p_domain text, p_subdomain text, p_count int, p_exclude uuid[] default '{}',
  p_level text default null, p_subdomains text[] default null)
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
  v_theme text;
  v_themes text[] := '{}';
  v_review uuid;
  v_target int := least(greatest(p_count, 1), 30);
begin
  -- Une révision due (erreur ou notion en cours de consolidation) glissée dans les parties adaptatives d'un domaine.
  if p_level is null and p_mode in ('training', 'quick') and p_domain is not null then
    select q.id into v_review
    from public.user_concepts uc
    join public.questions q on q.concept_id = uc.concept_id and q.status = 'published'
    where uc.user_id = p_user and uc.review_due <= public._now()
      and uc.error_state in ('failed', 'to_review', 'correct_once')
      and q.domain_id = p_domain
      and (p_subdomain is null or q.subdomain_id = p_subdomain)
      and (p_subdomains is null or q.subdomain_id = any (p_subdomains))
      and q.id <> all (v_banned)
    order by uc.review_due, random()
    limit 1;
    if v_review is not null then
      v_target := v_target - 1;
      v_concepts := v_concepts || (select concept_id from public.questions where id = v_review);
    end if;
  end if;

  for i in 1 .. v_target loop
    v_domain := coalesce(p_domain, split_part(p_subdomain, '.', 1));
    if v_domain is null or v_domain = '' then
      v_domain := public._pick_domain(p_user, v_last_dom);
      exit when v_domain is null;
    end if;
    -- Thème d'abord, à parts égales dans la partie (le moins servi jusqu'ici), avec un léger bonus aux thèmes
    -- où le niveau est le moins sûr ; puis la question dans la fenêtre de cote de ce thème.
    v_theme := p_subdomain;
    if v_theme is null then
      select sd.id into v_theme
      from public.subdomains sd
      cross join lateral public._skill_peek(p_user, sd.id) k
      where sd.domain_id = v_domain and sd.is_active
        and (p_subdomains is null or sd.id = any (p_subdomains))
        and (select count(*) from public.questions q2 where q2.subdomain_id = sd.id and q2.status = 'published') >= 5
      order by (select count(*) from unnest(v_themes) t where t = sd.id), random() * (0.5 + k.var / 100.0) desc
      limit 1;
    end if;
    v_scope := coalesce(v_theme, v_domain);
    select k.mu, k.var into v_mu, v_var from public._skill_peek(p_user, v_scope) k;
    select * into v_band from public._band_bounds(p_mode);
    v_pick := null;

    -- Niveaux de repli : 0 bande exacte, 1 ±5, 2 ±10, 3 toute difficulté, 4 sans filtre de récence.
    for lvl in 0 .. 4 loop
      v_level := lvl;
      v_widen := case lvl when 0 then 0 when 1 then 5 when 2 then 10 else 1000 end;
      -- Entraînement à difficulté choisie : bande fixe, indépendante du niveau.
      if p_level = 'beginner' then
        v_blo := 0; v_bhi := 40;
      elsif p_level = 'intermediate' then
        v_blo := 35; v_bhi := 65;
      elsif p_level = 'expert' then
        v_blo := 60; v_bhi := 100;
      elsif v_band.explore then
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
        and (p_subdomains is null or q.subdomain_id = any (p_subdomains))
        -- Le thème tiré tient jusqu'au niveau 2 ; ensuite tout le périmètre (thème épuisé à ce niveau).
        and (lvl >= 3 or v_theme is null or q.subdomain_id = v_theme)
        and q.id <> all (v_result || v_banned)
        and q.concept_id <> all (v_concepts)
        -- Variété : une seule question par famille tant que possible (niveaux 0-1), puis au plus 2 et jamais deux de suite (niveau 2).
        and (lvl >= 3 or q.family is null or (
              q.family is distinct from v_families[cardinality(v_families)]
              and (select count(*) from unnest(v_families) f where f = q.family) < case when lvl <= 1 then 1 else 2 end))
        -- Fenêtre adaptative : en chances réelles (hasard compris) pour chaque question ; difficulté fixe sinon.
        and (case when p_level is not null or v_band.explore
                  then q.difficulty_effective between v_blo - v_widen and v_bhi + v_widen
                  else q.difficulty_effective between public._b_for_p(v_mu, v_band.hi, q.guess_rate) - v_widen
                                                  and public._b_for_p(v_mu, v_band.lo, q.guess_rate) + v_widen end)
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
      v_themes := v_themes || (select subdomain_id from public.questions where id = v_pick);
    elsif p_domain is not null or p_subdomain is not null or p_subdomains is not null then
      exit;  -- domaine épuisé
    end if;
    v_last_dom := v_domain;
  end loop;
  if v_review is not null then
    -- Position au hasard, jamais en premier : on ne commence pas une partie par une révision.
    v_level := 2 + floor(random() * greatest(cardinality(v_result), 1))::int;
    v_result := v_result[1:v_level - 1] || v_review || v_result[v_level:];
  end if;
  return v_result;
end $$;

-- « Mes erreurs » : les erreurs actives, puis les révisions arrivées à échéance (notions en cours de consolidation).
create or replace function public._select_error_questions(p_user uuid, p_count int) returns uuid[]
language sql volatile as $$
  with active as (
    select uc.concept_id, uc.error_state in ('failed', 'to_review') as is_error,
           coalesce(uc.review_due, uc.error_since) as due
    from public.user_concepts uc
    where uc.user_id = p_user
      and (uc.error_state in ('failed', 'to_review')
           or (uc.error_state = 'correct_once' and uc.review_due <= public._now()))
    order by 2 desc, 3
    limit least(greatest(p_count, 1), 20)
  ), pick as (
    select distinct on (a.concept_id) a.concept_id, a.is_error, a.due, q.id
    from active a
    join public.questions q on q.concept_id = a.concept_id and q.status = 'published'
    where q.id <> all (public._protected_daily_questions())
    order by a.concept_id,
             (select max(qa.created_at) from public.question_attempts qa
              where qa.user_id = p_user and qa.question_id = q.id) nulls first,
             random()
  )
  select coalesce(array_agg(id order by is_error desc, due), '{}') from pick
$$;

-- Pack : chances de réussite hasard compris.
create or replace function public.play_pack(p_mode text, p_domain text default null, p_subdomain text default null,
                                            p_count int default 10, p_ranked bool default true, p_level text default null,
                                            p_subdomains text[] default null) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  v jsonb := public._play_pack_base(p_mode, p_domain, p_subdomain, p_count, p_ranked, p_level, p_subdomains);
begin
  return jsonb_set(v, '{questions}', coalesce((
    select jsonb_agg(e || jsonb_build_object(
             'difficulty', round(q.difficulty_effective::numeric, 0),
             'expected', round(public._expect_q(k.mu, q.difficulty_effective, q.difficulty_var, q.guess_rate)::numeric, 2))
           order by i)
    from jsonb_array_elements(v -> 'questions') with ordinality t(e, i)
    join public.questions q on q.id = (e ->> 'id')::uuid
    cross join lateral public._skill_peek(v_user, q.subdomain_id) k), '[]'::jsonb));
end $$;

revoke execute on function public._record_attempt(uuid, uuid, jsonb, int, public.attempt_context, uuid, uuid, bool) from public, anon, authenticated;
revoke execute on function public._select_questions(uuid, text, text, text, int, uuid[], text, text[]) from public, anon, authenticated;
revoke execute on function public._skill_update(uuid, text, real, real, bool, int, real) from public, anon, authenticated;
