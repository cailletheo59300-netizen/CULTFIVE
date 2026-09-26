-- CULT FIVE — 0011 Parties classées et entraînement libre
-- Partie classée : adaptative, fait bouger le niveau. Entraînement libre : nombre de questions (≤ 30), difficulté au choix,
-- niveau inchangé, moitié d'XP, pas de graines ; les erreurs restent suivies. Variété renforcée (une famille par partie si possible).
-- Sous-thèmes : le joueur en choisit un ou plusieurs (p_subdomains), ou mélange tout le domaine.

alter table public.play_sessions
  add column ranked bool not null default true,
  add column level text not null default 'adaptive' check (level in ('adaptive', 'beginner', 'intermediate', 'expert'));

drop function public._record_attempt(uuid, uuid, jsonb, int, public.attempt_context, uuid, uuid);
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
    select * into v_sub from public._skill_update(p_user, q.subdomain_id, q.difficulty_effective, q.difficulty_var, v_correct, p_ms);
    select * into v_dom from public._skill_update(p_user, q.domain_id,    q.difficulty_effective, q.difficulty_var, v_correct, p_ms);
    perform public._question_update(q.id, v_sub.mu_before, v_sub.var_before, v_correct);
  else
    -- Entraînement libre : le niveau ne bouge pas, la difficulté des questions non plus (échantillon biaisé par le choix du joueur).
    select k.mu as mu_before, k.var as var_before, k.mu as mu_after, k.var as var_after,
           public._expect(k.mu, q.difficulty_effective, q.difficulty_var)::real as expected
      into v_sub from public._skill_peek(p_user, q.subdomain_id) k;
    select k.mu as mu_before, k.var as var_before, k.mu as mu_after, k.var as var_after, null::real as expected
      into v_dom from public._skill_peek(p_user, q.domain_id) k;
  end if;

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


drop function public._select_questions(uuid, text, text, text, int, uuid[]);
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
begin
  for i in 1 .. least(greatest(p_count, 1), 30) loop
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
        and q.id <> all (v_result || v_banned)
        and q.concept_id <> all (v_concepts)
        -- Variété : une seule question par famille tant que possible (niveaux 0-1), puis au plus 2 et jamais deux de suite (niveau 2).
        and (lvl >= 3 or q.family is null or (
              q.family is distinct from v_families[cardinality(v_families)]
              and (select count(*) from unnest(v_families) f where f = q.family) < case when lvl <= 1 then 1 else 2 end))
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
    elsif p_domain is not null or p_subdomain is not null or p_subdomains is not null then
      exit;  -- domaine épuisé
    end if;
    v_last_dom := v_domain;
  end loop;
  return v_result;
end $$;



drop function public.play_pack(text, text, text, int);
-- Pack de jeu. Les réponses sont incluses (jeu fluide et hors-ligne) ; les questions de Daily en cours/à venir sont exclues.
create or replace function public.play_pack(p_mode text, p_domain text default null, p_subdomain text default null,
                                            p_count int default 10, p_ranked bool default true, p_level text default null,
                                            p_subdomains text[] default null) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  v_ids uuid[];
  v_session uuid := gen_random_uuid();
  v_recent int;
begin
  if p_mode not in ('quick', 'training', 'surprise', 'errors', 'challenge') then raise exception 'invalid_mode'; end if;
  if p_mode = 'training' and p_domain is null and p_subdomain is null then raise exception 'domain_required'; end if;
  -- Sous-thèmes choisis (un ou plusieurs) : tous dans le domaine demandé. Liste vide = tout le domaine.
  if cardinality(p_subdomains) = 0 then p_subdomains := null; end if;
  if p_subdomains is not null and (p_domain is null or exists (select 1 from unnest(p_subdomains) x where split_part(x, '.', 1) <> p_domain)) then
    raise exception 'invalid_scope';
  end if;
  if p_level is not null and p_level not in ('adaptive', 'beginner', 'intermediate', 'expert') then raise exception 'invalid_level'; end if;
  if p_count is null or p_count < 1 or p_count > 30 then raise exception 'invalid_count'; end if;
  -- Partie classée : toujours adaptative. Le choix de difficulté est réservé à l'entraînement libre ; les erreurs restent classées.
  if p_ranked is distinct from false or p_mode = 'errors' then p_ranked := true; p_level := null; end if;
  if p_level = 'adaptive' then p_level := null; end if;
  if p_subdomain is not null and p_domain is not null and split_part(p_subdomain, '.', 1) <> p_domain then
    raise exception 'invalid_scope';
  end if;

  -- Limite anti-aspiration de la banque : 60 packs / heure.
  select count(*) into v_recent from public.play_sessions where user_id = v_user and created_at > public._now() - interval '1 hour';
  if v_recent >= 60 then raise exception 'rate_limited'; end if;

  if p_mode = 'errors' then
    v_ids := public._select_error_questions(v_user, p_count);
  elsif p_mode = 'surprise' then
    v_ids := public._select_questions(v_user, 'surprise', null, null, p_count, '{}', p_level);
  else
    v_ids := public._select_questions(v_user, p_mode, p_domain, p_subdomain, p_count, '{}', p_level, p_subdomains);
  end if;

  insert into public.play_sessions (id, user_id, mode, domain_id, subdomain_id, question_ids, created_at, ranked, level)
  values (v_session, v_user, p_mode, coalesce(p_domain, nullif(split_part(p_subdomain, '.', 1), '')), p_subdomain, v_ids, public._now(),
          p_ranked, coalesce(p_level, 'adaptive'));

  return jsonb_build_object(
    'session_id', v_session,
    'mode', p_mode,
    'ranked', p_ranked,
    'level', coalesce(p_level, 'adaptive'),
    'questions', coalesce((
      select jsonb_agg(public._question_public(q, v_session::text) || public._question_reveal(q)
                       || jsonb_build_object('concept_id', q.concept_id,
                                             'has_hint', q.hint is not null, 'has_context', q.context_note is not null)
                       order by array_position(v_ids, q.id))
      from public.questions q where q.id = any (v_ids)), '[]'::jsonb));
end $$;

-- Soumission groupée (fin de partie ou vidage de la file hors-ligne). Idempotente par client_attempt_id.
-- attempts : [{client_attempt_id, question_id, given, response_ms}]
create or replace function public.play_submit(p_session uuid, p_attempts jsonb) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  s public.play_sessions;
  a jsonb;
  v_res jsonb;
  v_rew jsonb;
  v_ctx public.attempt_context;
  v_protected uuid[] := public._protected_daily_questions();
  v_correct int := 0;
  v_new int := 0;
  v_xp int := 0; v_seeds int := 0;
  v_corrected jsonb := '[]'::jsonb;
  v_results jsonb := '[]'::jsonb;
  v_qid uuid;
  v_ms int;
  v_total_correct int;
begin
  select * into s from public.play_sessions where id = p_session and user_id = v_user for update;
  if not found then raise exception 'session_not_found'; end if;
  if jsonb_typeof(p_attempts) <> 'array' or jsonb_array_length(p_attempts) > 40 then raise exception 'invalid_attempts'; end if;
  v_ctx := public._mode_context(s.mode);

  for a in select * from jsonb_array_elements(p_attempts) loop
    v_qid := (a ->> 'question_id')::uuid;
    -- Seules les questions effectivement servies dans cette session sont acceptées.
    continue when not (v_qid = any (s.question_ids)) or v_qid = any (v_protected);
    v_ms := least(greatest(coalesce((a ->> 'response_ms')::int, 0), 0), 600000);
    v_res := public._record_attempt(v_user, v_qid, a -> 'given', v_ms, v_ctx, s.id, (a ->> 'client_attempt_id')::uuid, s.ranked);
    v_results := v_results || jsonb_build_object('question_id', v_qid, 'is_correct', v_res -> 'is_correct',
                                                 'error_transition', v_res -> 'error_transition',
                                                 'domain_before', v_res -> 'domain_before', 'domain_after', v_res -> 'domain_after');
    continue when (v_res ->> 'duplicate')::bool;
    v_new := v_new + 1;
    if (v_res ->> 'is_correct')::bool then
      v_correct := v_correct + 1;
      -- Réponse trop rapide pour être lue : comptée, non récompensée.
      -- Entraînement libre : moitié d'XP (arrondie), pas de graines.
      if v_ms >= 800 then
        v_xp := v_xp + public._grant_capped(v_user, 'xp', case when s.ranked then 5 else 3 end, 300, 'play_correct', s.id::text,
                                            'play_correct:' || (a ->> 'client_attempt_id'));
      end if;
    end if;
    if s.ranked then
      v_rew := public._reward_correction(v_user, v_res, a ->> 'client_attempt_id');
      v_xp := v_xp + (v_rew ->> 'xp')::int;
      v_seeds := v_seeds + (v_rew ->> 'seeds')::int;
    end if;
    if v_res ->> 'error_transition' = 'corrected' then
      v_corrected := v_corrected || to_jsonb(v_qid);
    end if;
  end loop;

  -- Graines de jeu : 2 par tranche de 5 bonnes réponses dans la session, plafond 20/jour.
  select count(*) into v_total_correct from public.question_attempts
  where session_id = s.id and user_id = v_user and is_correct;
  for k in 1 .. (case when s.ranked then v_total_correct / 5 else 0 end) loop
    v_seeds := v_seeds + public._grant_capped(v_user, 'seeds', 2, 20, 'play_correct', s.id::text,
                                              'play_seeds:' || s.id || ':' || k);
  end loop;

  -- Partie terminée (≥ 8 réponses) : bonus unique.
  if s.completed_at is null and (select count(*) from public.question_attempts where session_id = s.id and user_id = v_user) >= least(8, cardinality(s.question_ids)) then
    update public.play_sessions set completed_at = public._now() where id = s.id;
    if public._grant(v_user, 'xp', case when s.ranked then 10 else 5 end, 'play_complete', s.id::text, 'play_complete:' || s.id) then
      v_xp := v_xp + case when s.ranked then 10 else 5 end;
    end if;
  end if;

  return jsonb_build_object('recorded', v_new, 'correct', v_correct, 'xp', v_xp, 'seeds', v_seeds, 'ranked', s.ranked,
                            'corrected', v_corrected, 'results', v_results,
                            'achievements', to_jsonb(public._check_achievements(v_user)),
                            'balance', (select seeds from public.profiles where id = v_user));
end $$;


revoke execute on function public._record_attempt(uuid, uuid, jsonb, int, public.attempt_context, uuid, uuid, bool) from public, anon, authenticated;
revoke execute on function public._select_questions(uuid, text, text, text, int, uuid[], text, text[]) from public, anon, authenticated;
revoke execute on function public.play_pack(text, text, text, int, bool, text, text[]) from public, anon;
grant execute on function public.play_pack(text, text, text, int, bool, text, text[]) to authenticated;
