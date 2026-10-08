-- 0039 : nouveaux types de réponses : correction, « Pile ! », choix des questions (5 du jour et parties classées)
-- et compatibilité avec les anciennes versions de l'app.
--
-- Une app à jour envoie l'en-tête « x-brainlix-types: 2 ». Sans lui (version 1.0), le serveur ne sert que des types classiques :
--  · 5 du jour : chaque question d'un nouveau type a une question classique de remplacement, choisie en même temps ;
--  · parties classées et entraînement : aucun nouveau type ;
--  · duels et ligues (partagés entre deux joueurs) : types classiques pour tout le monde.

create or replace function public._is_classic(p_type public.question_type) returns bool
language sql immutable set search_path = public, pg_temp as $$
  select p_type in ('mcq', 'true_false', 'numeric', 'ordering', 'pairs', 'map_pick')
$$;

-- L'app sait-elle afficher les nouveaux types ? (en-tête HTTP transmis par PostgREST ; absent hors requête ⇒ non)
create or replace function public._client_v2() returns bool
language sql stable set search_path = public, pg_temp as $$
  select coalesce(nullif(current_setting('request.headers', true), '')::jsonb ->> 'x-brainlix-types', '') >= '2'
$$;

create or replace function public._type_ok(p_type public.question_type) returns bool
language sql stable set search_path = public, pg_temp as $$
  select public._is_classic(p_type) or public._client_v2()
$$;

-- Réponse « pile » sur un type à marge : la valeur exacte (1 % près pour les proportions, curseur continu).
create or replace function public._is_exact(p_type public.question_type, p_answer jsonb, p_given jsonb) returns bool
language plpgsql immutable set search_path = public, pg_temp as $$
begin
  if p_type in ('counter', 'timeline', 'gauge') then
    return (p_given ->> 'value')::numeric = (p_answer ->> 'value')::numeric;
  elsif p_type = 'proportion' then
    return abs((p_given ->> 'value')::numeric - (p_answer ->> 'value')::numeric) <= abs((p_answer ->> 'value')::numeric) * 0.01;
  end if;
  return false;
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
    when 'image_choice' then
      v := (p_given ->> 'option_id') = (p_answer ->> 'option_id');
  end case;
  return coalesce(v, false);  -- réponse absente ou malformée ⇒ fausse
exception when others then
  return false;
end $function$;

CREATE OR REPLACE FUNCTION public._guess_rate(p_type question_type, p_payload jsonb)
 RETURNS real
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
  select case
    when p_type in ('mcq', 'map_pick', 'image_choice') then 1.0 / greatest(coalesce(jsonb_array_length(p_payload -> 'options'), 4), 2)
    when p_type = 'true_false' then 0.5
    else 0 end::real
$function$;

CREATE OR REPLACE FUNCTION public._record_attempt(p_user uuid, p_question uuid, p_given jsonb, p_ms integer, p_context attempt_context, p_session uuid, p_client_id uuid, p_ranked boolean DEFAULT true, p_second_chance boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
declare
  q public.questions;
  v_prev public.question_attempts;
  v_correct bool;
  v_known bool;     -- su du premier coup (une Seconde chance réussie n'en est pas)
  v_score real;
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
      return jsonb_build_object('duplicate', true, 'is_correct', v_prev.is_correct, 'second_chance', v_prev.second_chance);
    end if;
  end if;

  select * into q from public.questions where id = p_question;
  if not found then raise exception 'question_not_found'; end if;

  v_correct := public._evaluate(q.type, q.answer, p_given);
  -- 0039 : « Pile ! » (valeur exacte sur un type à marge) : +5 graines, une seule fois par tentative.
  if v_correct and public._is_exact(q.type, q.answer, p_given) then
    perform public._grant(p_user, 'seeds', 5, 'pile', q.id::text, 'pile:' || coalesce(p_client_id::text, q.id::text || ':' || p_user::text));
  end if;
  v_known := v_correct and not coalesce(p_second_chance, false);
  v_score := case when v_correct and p_second_chance then 0.5 end;

  if p_ranked then
    -- Sous-domaine d'abord : son prior dérive du domaine *avant* cette réponse.
    select * into v_sub from public._skill_update(p_user, q.subdomain_id, q.difficulty_effective, q.difficulty_var, v_correct, p_ms, q.guess_rate, v_score);
    select * into v_dom from public._skill_update(p_user, q.domain_id,    q.difficulty_effective, q.difficulty_var, v_correct, p_ms, q.guess_rate, v_score);
    -- Une Seconde chance ne dit rien de fiable sur la difficulté de la question.
    if not coalesce(p_second_chance, false) then
      perform public._question_update(q.id, v_sub.mu_before, v_sub.var_before, v_correct);
    end if;
  else
    -- Entraînement libre : le niveau ne bouge pas, la difficulté des questions non plus (échantillon biaisé par le choix du joueur).
    select k.mu as mu_before, k.var as var_before, k.mu as mu_after, k.var as var_after,
           public._expect_q(k.mu, q.difficulty_effective, q.difficulty_var, q.guess_rate)::real as expected
      into v_sub from public._skill_peek(p_user, q.subdomain_id) k;
    select k.mu as mu_before, k.var as var_before, k.mu as mu_after, k.var as var_after, null::real as expected
      into v_dom from public._skill_peek(p_user, q.domain_id) k;
  end if;

  -- Concept & erreurs (une Seconde chance réussie compte comme une erreur à revoir)
  select * into v_uc from public.user_concepts where user_id = p_user and concept_id = q.concept_id for update;
  v_state := v_uc.error_state;
  v_step := coalesce(v_uc.review_step, 0);
  v_due := v_uc.review_due;
  -- Révision espacée : une erreur revient 1 jour après, puis 3, 7 et 21 jours après chaque bonne réponse « à l'heure ».
  -- Réussir avant l'échéance ne fait pas avancer (on vérifie la mémoire, pas la mémoire immédiate).
  if not v_known then
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
  values (p_user, q.concept_id, 1, v_known::int, v_now,
          case when v_known then v_now end, case when not v_known then v_now end,
          v_state, case when v_transition = 'new_error' then v_now end, null,
          case when v_transition = 'new_error' then 1 else 0 end, v_step, v_due)
  on conflict (user_id, concept_id) do update set
    seen            = uc.seen + 1,
    correct         = uc.correct + v_known::int,
    last_seen_at    = v_now,
    last_correct_at = case when v_known then v_now else uc.last_correct_at end,
    last_wrong_at   = case when not v_known then v_now else uc.last_wrong_at end,
    error_state     = v_state,
    error_since     = case when v_transition = 'new_error' then v_now else uc.error_since end,
    corrected_at    = case when v_transition = 'corrected' then v_now else uc.corrected_at end,
    error_count     = uc.error_count + (v_transition is not distinct from 'new_error')::int,
    review_step     = v_step,
    review_due      = v_due;

  select count(*) + 1 into v_seen from public.question_attempts where user_id = p_user and question_id = q.id;

  insert into public.question_attempts (client_attempt_id, user_id, question_id, concept_id, context, session_id, given,
                                        is_correct, response_ms, question_difficulty, user_skill_before, expected, seen_count,
                                        created_at, second_chance, dom_mu_before, dom_mu_after, sub_mu_after)
  values (p_client_id, p_user, q.id, q.concept_id, p_context, p_session, p_given,
          v_correct, p_ms, q.difficulty_effective, v_sub.mu_before, v_sub.expected, v_seen, v_now, coalesce(p_second_chance, false),
          case when p_ranked then v_dom.mu_before end, case when p_ranked then v_dom.mu_after end,
          case when p_ranked then v_sub.mu_after end);

  update public.profiles set
    questions_answered = questions_answered + 1,
    questions_correct  = questions_correct + v_correct::int,
    errors_corrected   = errors_corrected + (v_transition is not distinct from 'corrected')::int
  where id = p_user;

  return jsonb_build_object(
    'duplicate', false,
    'is_correct', v_correct,
    'exact', v_correct and public._is_exact(q.type, q.answer, p_given),
    'second_chance', coalesce(p_second_chance, false),
    'error_transition', v_transition,
    'error_since', v_uc.error_since,
    'domain_id', q.domain_id,
    'domain_before', round(v_dom.mu_before::numeric, 1),
    'domain_after', round(v_dom.mu_after::numeric, 1),
    'expected', round(v_sub.expected::numeric, 3));
end $function$;

CREATE OR REPLACE FUNCTION public._select_questions(p_user uuid, p_mode text, p_domain text, p_subdomain text, p_count integer, p_exclude uuid[] DEFAULT '{}'::uuid[], p_level text DEFAULT NULL::text, p_subdomains text[] DEFAULT NULL::text[])
 RETURNS uuid[]
 LANGUAGE plpgsql
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
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
  -- 0039 : au plus une question d'un nouveau type, dans environ une partie sur deux (app à jour seulement).
  v_fun_left int := case when public._client_v2() and random() < 0.5 then 1 else 0 end;
begin
  -- Une révision due (erreur ou notion en cours de consolidation) glissée dans les parties adaptatives d'un domaine.
  if p_level is null and p_mode in ('training', 'quick') and p_domain is not null then
    select q.id into v_review
    from public.user_concepts uc
    join public.questions q on q.concept_id = uc.concept_id and q.status = 'published' and public._is_classic(q.type)
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
    v_mu := least(greatest(v_mu + coalesce(public._placement_offset(p_user, v_domain), 0), 0), 100);
    select * into v_band from public._band_bounds(p_mode);
    v_pick := null;

    -- Niveaux de repli : 0 thème + bande exacte, 1 thème ± 5, 2 tout le domaine ± 10 (une question par famille),
    -- 3 ± 10 (deux par famille), 4 toute difficulté, 5 sans filtre de récence. Le thème cède avant la variété des familles.
    for lvl in 0 .. 5 loop
      v_level := lvl;
      v_widen := case lvl when 0 then 0 when 1 then 5 when 2 then 10 when 3 then 10 else 1000 end;
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
        and (public._is_classic(q.type) or v_fun_left > 0)
        and (p_subdomain is null or q.subdomain_id = p_subdomain)
        and (p_subdomains is null or q.subdomain_id = any (p_subdomains))
        -- Le thème tiré tient aux niveaux 0 et 1 ; ensuite tout le domaine.
        and (lvl >= 2 or v_theme is null or q.subdomain_id = v_theme)
        and q.id <> all (v_result || v_banned)
        and q.concept_id <> all (v_concepts)
        -- Variété : une seule question par famille tant que possible (niveaux 0-1), puis au plus 2 et jamais deux de suite (niveau 2).
        and (lvl >= 4 or q.family is null or (
              q.family is distinct from v_families[cardinality(v_families)]
              and (select count(*) from unnest(v_families) f where f = q.family) < case when lvl <= 2 then 1 else 2 end))
        -- Fenêtre adaptative : en chances réelles (hasard compris) pour chaque question ; difficulté fixe sinon.
        and (case when p_level is not null or v_band.explore
                  then q.difficulty_effective between v_blo - v_widen and v_bhi + v_widen
                  else q.difficulty_effective between public._b_for_p(v_mu, v_band.hi, q.guess_rate) - v_widen
                                                  and public._b_for_p(v_mu, v_band.lo, q.guess_rate) + v_widen end)
        and (lvl = 5 or not exists (
              select 1 from public.user_concepts uc
              where uc.user_id = p_user and uc.concept_id = q.concept_id
                and uc.last_seen_at > public._now() - case when uc.last_correct_at = uc.last_seen_at
                                                      then interval '7 days' else interval '3 days' end))
      order by case when v_band.explore then q.answer_count else 0 end,
               case when lvl >= 4 then abs(q.difficulty_effective - (v_blo + v_bhi) / 2) else 0 end, random()
      limit 1;
      exit when v_pick is not null;
    end loop;

    if v_pick is not null then
      v_result := v_result || v_pick;
      if not public._is_classic((select type from public.questions where id = v_pick)) then v_fun_left := 0; end if;
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
end $function$;

CREATE OR REPLACE FUNCTION public._select_error_questions(p_user uuid, p_count integer)
 RETURNS uuid[]
 LANGUAGE sql
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
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
    join public.questions q on q.concept_id = a.concept_id and q.status = 'published' and public._type_ok(q.type)
    where q.id <> all (public._protected_daily_questions())
    order by a.concept_id,
             (select max(qa.created_at) from public.question_attempts qa
              where qa.user_id = p_user and qa.question_id = q.id) nulls first,
             random()
  )
  select coalesce(array_agg(id order by is_error desc, due), '{}') from pick
$function$;

CREATE OR REPLACE FUNCTION public._duel_pick(p_a uuid, p_b uuid, p_count integer, p_domains text[], p_difficulty text)
 RETURNS uuid[]
 LANGUAGE plpgsql
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
declare
  v_target real := case when p_b is null then public._overall_mu(p_a)
                        else (public._overall_mu(p_a) + public._overall_mu(p_b)) / 2 end;
  v_lo real;
  v_hi real;
  v_ids uuid[];
begin
  select lo, hi into v_lo, v_hi from (values
    ('easy', 15::real, 40::real), ('medium', 38, 62), ('hard', 60, 92),
    ('auto', greatest(v_target - 12, 15), least(v_target + 12, 90))) t(k, lo, hi)
  where k = p_difficulty;
  select array_agg(id order by d, id) into v_ids from (
    select id, d from (
      select q.id, q.difficulty_effective as d,
             row_number() over (partition by q.domain_id
                                order by (q.difficulty_effective between v_lo and v_hi) desc,
                                         exists (select 1 from public.question_attempts a
                                                 where a.question_id = q.id and a.user_id in (p_a, p_b)),
                                         abs(q.difficulty_effective - (v_lo + v_hi) / 2) > (v_hi - v_lo) / 2,
                                         random()) as rn
      from public.questions q
      where q.status = 'published' and q.type <> 'map_pick' and public._is_classic(q.type)
        and (p_domains is null or q.domain_id = any (p_domains))
        and q.id <> all (public._protected_daily_questions())
    ) t
    order by rn, random()
    limit p_count
  ) s;
  return v_ids;
end $function$;

CREATE OR REPLACE FUNCTION public._league_day_questions(l leagues, p_day date)
 RETURNS uuid[]
 LANGUAGE plpgsql
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
declare
  v_ids uuid[];
  v_target real;
  v_lo real; v_hi real;
begin
  select question_ids into v_ids from public.league_days where league_id = l.id and day = p_day;
  if v_ids is not null then return v_ids; end if;
  select coalesce(avg(public._overall_mu(m.user_id)), 50) into v_target from public.league_members m where m.league_id = l.id;
  select lo, hi into v_lo, v_hi from (values
    ('easy', 15::real, 40::real), ('medium', 38, 62), ('hard', 60, 92),
    ('auto', greatest(v_target - 12, 15), least(v_target + 12, 90))) t(k, lo, hi)
  where k = l.difficulty;
  select array_agg(id order by d, id) into v_ids from (
    select id, d from (
      select q.id, q.difficulty_effective as d,
             row_number() over (partition by q.domain_id
                                order by (q.difficulty_effective between v_lo and v_hi) desc, random()) as rn
      from public.questions q
      where q.status = 'published' and q.type <> 'map_pick' and public._is_classic(q.type)
        and (l.domains is null or q.domain_id = any (l.domains))
        and q.id <> all (public._protected_daily_questions())
        and not exists (select 1 from public.league_days ld where ld.league_id = l.id and q.id = any (ld.question_ids))
    ) t
    order by rn, random()
    limit l.question_count
  ) s;
  if coalesce(cardinality(v_ids), 0) < l.question_count then raise exception 'not_enough_questions'; end if;
  insert into public.league_days (league_id, day, question_ids) values (l.id, p_day, v_ids)
  on conflict (league_id, day) do nothing;
  select question_ids into v_ids from public.league_days where league_id = l.id and day = p_day;
  return v_ids;
end $function$;


-- ─────────────── 5 du jour
alter table public.daily_set_items add column if not exists fallback_question_id uuid references public.questions(id) on delete set null;
comment on column public.daily_set_items.fallback_question_id is
  'Question classique servie à la place quand l''app ne sait pas afficher le type de question_id (version 1.0).';

-- Question réellement servie à ce joueur pour cet élément du 5 du jour.
create or replace function public._daily_served(i public.daily_set_items) returns uuid
language sql stable set search_path = public, pg_temp as $$
  select case when i.fallback_question_id is not null and not public._client_v2() then i.fallback_question_id else i.question_id end
$$;

create or replace function public._protected_daily_questions() returns uuid[]
language sql stable set search_path = public, extensions, pg_temp as $$
  select coalesce(array_agg(x), '{}')
  from public.daily_set_items i, unnest(array[i.question_id, i.fallback_question_id]) x
  where i.daily_date >= (public._now() at time zone 'UTC')::date - 1 and x is not null
$$;

CREATE OR REPLACE FUNCTION public.daily_question(p_run uuid, p_position integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_user uuid := public._require_user();
  r public.daily_runs;
  q public.questions;
  v_next int;
  v_qid uuid;
begin
  select * into r from public.daily_runs where id = p_run and user_id = v_user for update;
  if not found then raise exception 'daily_run_not_found'; end if;
  -- Pas d'exception ici : elle annulerait la clôture. On renvoie un état explicite.
  if r.status = 'in_progress' and r.deadline_at < public._now() then
    perform public._daily_finish(r.id, true);
    return jsonb_build_object('expired', true);
  end if;
  if r.status <> 'in_progress' then raise exception 'daily_closed'; end if;

  select count(*) + 1 into v_next from public.daily_answers where run_id = r.id and answered_at is not null;
  if p_position <> v_next then raise exception 'daily_out_of_order'; end if;

  select public._daily_served(i) into v_qid from public.daily_set_items i where i.daily_date = r.daily_date and i.position = p_position;
  -- served_at n'est posé qu'une fois : rouvrir l'app ne remet pas l'horloge à zéro.
  insert into public.daily_answers (run_id, position, question_id, served_at)
  values (r.id, p_position, v_qid, public._now())
  on conflict (run_id, position) do nothing;
  -- Déjà servie : on garde la même question (changer d'app en cours de route ne la remplace pas).
  select question_id into v_qid from public.daily_answers where run_id = r.id and position = p_position;

  select * into q from public.questions where id = v_qid;
  return public._question_public(q, r.id::text) || jsonb_build_object('position', p_position, 'total', 5);
end $function$;


create or replace function public.daily_review(p_date date default null) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  r public.daily_runs;
begin
  select * into r from public.daily_runs
  where user_id = v_user and daily_date = coalesce(p_date, public._user_today(v_user));
  if not found or r.status = 'in_progress' then raise exception 'daily_not_finished'; end if;
  return (
    select jsonb_agg(public._question_public(q, r.id::text) || public._question_reveal(q)
                     || jsonb_build_object('position', i.position, 'given', da.given,
                                           'is_correct', coalesce(da.is_correct, false), 'counted_ms', da.counted_ms)
                     order by i.position)
    from public.daily_set_items i
    left join public.daily_answers da on da.run_id = r.id and da.position = i.position
    join public.questions q on q.id = coalesce(da.question_id, public._daily_served(i))
    where i.daily_date = r.daily_date);
end $$;

-- Le 5 du jour : 5 thèmes comme avant, dont 1 ou 2 questions d'un nouveau type (au hasard), jamais deux du même type,
-- et pas un type déjà servi la veille. Chaque question d'un nouveau type reçoit une question classique de remplacement
-- (même thème, difficulté proche) pour les anciennes versions de l'app.
create or replace function public._generate_daily_set(p_date date) returns void
language plpgsql set search_path = public, extensions, pg_temp as $$
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
  v_picks uuid[] := '{}';
  v_fun bool[];
  v_fun_n int;
  v_fun_types public.question_type[] := '{}';
  v_yesterday public.question_type[];
  v_pref public.question_type[];
  v_fallbacks uuid[] := '{}';
  v_fb uuid;
  v_fb_concept text;
begin
  perform pg_advisory_xact_lock(hashtext('daily:' || p_date::text));
  if exists (select 1 from public.daily_sets where daily_date = p_date) then return; end if;

  select array_agg(s order by random()) into v_slots from unnest(enum_range(null::public.daily_slot)) s;
  v_targets := array[44, 47, 50, 53, 56]::real[];  -- 0027 : montée douce, dans cet ordre
  insert into public.daily_sets (daily_date) values (p_date);

  -- 1 question « fun » deux jours sur trois, 2 le troisième ; places tirées au hasard.
  v_fun_n := case when random() < 0.65 then 1 else 2 end;
  select array_agg(x order by random()) into v_fun from (select g <= v_fun_n as x from generate_series(1, 5) g) s;
  select coalesce(array_agg(distinct q.type), '{}') into v_yesterday
  from public.daily_set_items i join public.questions q on q.id = i.question_id
  where i.daily_date = p_date - 1 and not public._is_classic(q.type);

  -- Surprise : on tire d'abord un domaine (uniforme), pour qu'un domaine très fourni ne l'emporte pas toujours.
  select d.id into v_surprise_domain from public.domains d
  where d.daily_slot is null and d.is_active
    and exists (select 1 from public.questions q where q.domain_id = d.id and q.status = 'published')
  order by random() limit 1;

  for i in 1 .. 5 loop
    v_pick := null;
    -- Types qui vont le mieux avec chaque thème (simple préférence).
    v_pref := case v_slots[i]
      when 'calc' then array['counter', 'gauge']
      when 'french' then array['letters', 'word_order']
      when 'geo' then array['image_choice', 'proportion', 'counter']
      when 'history' then array['timeline', 'word_order']
      else array['proportion', 'gauge', 'image_choice', 'counter', 'timeline', 'letters', 'word_order'] end::public.question_type[];
    -- 0 : toutes contraintes · 1 : sans fenêtre 180/60 j (mais pas de question vue ces 14 j) · 2 : tout
    -- · 3 : type libre (si le thème n'a aucune question du type voulu).
    for lvl in 0 .. 3 loop
      select q.id, q.concept_id, q.type, q.family into v_pick, v_concept, v_type, v_family
      from public.questions q
      join public.domains d on d.id = q.domain_id
      where q.status = 'published'
        and (lvl >= 1 or not q.needs_review)
        and (case when v_slots[i] = 'surprise' then d.daily_slot is null else d.daily_slot = v_slots[i] end)
        and (v_slots[i] <> 'surprise' or lvl >= 2 or q.domain_id = v_surprise_domain)
        and (case when lvl = 3 then public._is_classic(q.type) or q.type <> all (v_fun_types)
                  when v_fun[i] then not public._is_classic(q.type) and q.type <> all (v_fun_types)
                                     and (lvl >= 2 or q.type <> all (v_yesterday))
                  else public._is_classic(q.type) end)
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
      order by abs(q.difficulty_effective - v_targets[i]) + random() * 3
               + 15 * (select count(*) from unnest(v_types) t where t = q.type)
               + 25 * (select count(*) from unnest(v_families) f where f = q.family)
               + case when v_fun[i] and q.type <> all (v_pref) then 10 else 0 end
      limit 1;
      exit when v_pick is not null;
    end loop;
    if v_pick is null then
      raise exception 'daily_generation_failed: no question for slot %', v_slots[i];
    end if;
    v_picks := v_picks || v_pick;
    v_used := v_used || v_pick;
    v_concepts := v_concepts || v_concept;
    v_types := v_types || v_type;
    v_families := v_families || coalesce(v_family, '');

    -- Remplaçant classique pour les anciennes versions de l'app.
    v_fb := null;
    if not public._is_classic(v_type) then
      v_fun_types := v_fun_types || v_type;
      for lvl in 0 .. 1 loop
        select q.id, q.concept_id into v_fb, v_fb_concept
        from public.questions q
        join public.domains d on d.id = q.domain_id
        where q.status = 'published' and public._is_classic(q.type)
          and (case when v_slots[i] = 'surprise' then d.daily_slot is null else d.daily_slot = v_slots[i] end)
          and q.id <> all (v_used)
          and q.concept_id <> all (v_concepts)
          and (lvl >= 1 or not exists (
                select 1 from public.daily_set_items i
                where (i.question_id = q.id or i.fallback_question_id = q.id) and abs(i.daily_date - p_date) <= 60))
        order by abs(q.difficulty_effective - (select difficulty_effective from public.questions where id = v_pick)) + random() * 3
        limit 1;
        exit when v_fb is not null;
      end loop;
      if v_fb is null then raise exception 'daily_generation_failed: no fallback for slot %', v_slots[i]; end if;
      v_used := v_used || v_fb;
      v_concepts := v_concepts || v_fb_concept;
    end if;
    v_fallbacks := array_append(v_fallbacks, v_fb);
  end loop;
  insert into public.daily_set_items (daily_date, position, slot, question_id, fallback_question_id)
  select p_date, row_number() over (order by q.difficulty_effective, t.i), v_slots[t.i], t.id, v_fallbacks[t.i]
  from unnest(v_picks) with ordinality t(id, i) join public.questions q on q.id = t.id;
end $$;

revoke execute on function public._is_classic(public.question_type) from public, anon, authenticated;
revoke execute on function public._client_v2() from public, anon, authenticated;
revoke execute on function public._type_ok(public.question_type) from public, anon, authenticated;
revoke execute on function public._is_exact(public.question_type, jsonb, jsonb) from public, anon, authenticated;
revoke execute on function public._daily_served(public.daily_set_items) from public, anon, authenticated;
