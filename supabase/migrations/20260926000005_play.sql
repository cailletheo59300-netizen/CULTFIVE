-- Brainlix — 0005 Play
-- Packs de questions (avec réponses : jeu hors-ligne possible), soumission groupée idempotente,
-- gains plafonnés, aides payantes en graines (jamais dans le Daily).

create table public.play_sessions (
  id          uuid primary key,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  mode        text not null check (mode in ('quick', 'training', 'surprise', 'errors', 'challenge', 'onboarding')),
  domain_id   text references public.domains(id),
  subdomain_id text references public.subdomains(id),
  question_ids uuid[] not null,
  created_at  timestamptz not null default now(),
  completed_at timestamptz
);
create index on public.play_sessions (user_id, created_at desc);

create or replace function public._mode_context(p_mode text) returns public.attempt_context
language sql immutable as $$
  select case p_mode
    when 'quick' then 'quick_play' when 'training' then 'training' when 'surprise' then 'surprise'
    when 'errors' then 'errors' when 'challenge' then 'challenge' when 'onboarding' then 'onboarding'
  end::public.attempt_context
$$;

-- Pack de jeu. Les réponses sont incluses (jeu fluide et hors-ligne) ; les questions de Daily en cours/à venir sont exclues.
create or replace function public.play_pack(p_mode text, p_domain text default null, p_subdomain text default null,
                                            p_count int default 10) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  v_ids uuid[];
  v_session uuid := gen_random_uuid();
  v_recent int;
begin
  if p_mode not in ('quick', 'training', 'surprise', 'errors', 'challenge') then raise exception 'invalid_mode'; end if;
  if p_mode = 'training' and p_domain is null and p_subdomain is null then raise exception 'domain_required'; end if;
  if p_subdomain is not null and p_domain is not null and split_part(p_subdomain, '.', 1) <> p_domain then
    raise exception 'invalid_scope';
  end if;

  -- Limite anti-aspiration de la banque : 60 packs / heure.
  select count(*) into v_recent from public.play_sessions where user_id = v_user and created_at > public._now() - interval '1 hour';
  if v_recent >= 60 then raise exception 'rate_limited'; end if;

  if p_mode = 'errors' then
    v_ids := public._select_error_questions(v_user, p_count);
  elsif p_mode = 'surprise' then
    v_ids := public._select_questions(v_user, 'surprise', null, null, p_count);
  else
    v_ids := public._select_questions(v_user, p_mode, p_domain, p_subdomain, p_count);
  end if;

  insert into public.play_sessions (id, user_id, mode, domain_id, subdomain_id, question_ids, created_at)
  values (v_session, v_user, p_mode, coalesce(p_domain, nullif(split_part(p_subdomain, '.', 1), '')), p_subdomain, v_ids, public._now());

  return jsonb_build_object(
    'session_id', v_session,
    'mode', p_mode,
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
    v_res := public._record_attempt(v_user, v_qid, a -> 'given', v_ms, v_ctx, s.id, (a ->> 'client_attempt_id')::uuid);
    v_results := v_results || jsonb_build_object('question_id', v_qid, 'is_correct', v_res -> 'is_correct',
                                                 'error_transition', v_res -> 'error_transition',
                                                 'domain_before', v_res -> 'domain_before', 'domain_after', v_res -> 'domain_after');
    continue when (v_res ->> 'duplicate')::bool;
    v_new := v_new + 1;
    if (v_res ->> 'is_correct')::bool then
      v_correct := v_correct + 1;
      -- Réponse trop rapide pour être lue : comptée, non récompensée.
      if v_ms >= 800 then
        v_xp := v_xp + public._grant_capped(v_user, 'xp', 5, 300, 'play_correct', s.id::text,
                                            'play_correct:' || (a ->> 'client_attempt_id'));
      end if;
    end if;
    v_rew := public._reward_correction(v_user, v_res, a ->> 'client_attempt_id');
    v_xp := v_xp + (v_rew ->> 'xp')::int;
    v_seeds := v_seeds + (v_rew ->> 'seeds')::int;
    if v_res ->> 'error_transition' = 'corrected' then
      v_corrected := v_corrected || to_jsonb(v_qid);
    end if;
  end loop;

  -- Graines de jeu : 2 par tranche de 5 bonnes réponses dans la session, plafond 20/jour.
  select count(*) into v_total_correct from public.question_attempts
  where session_id = s.id and user_id = v_user and is_correct;
  for k in 1 .. (v_total_correct / 5) loop
    v_seeds := v_seeds + public._grant_capped(v_user, 'seeds', 2, 20, 'play_correct', s.id::text,
                                              'play_seeds:' || s.id || ':' || k);
  end loop;

  -- Partie terminée (≥ 8 réponses) : bonus unique.
  if s.completed_at is null and (select count(*) from public.question_attempts where session_id = s.id and user_id = v_user) >= least(8, cardinality(s.question_ids)) then
    update public.play_sessions set completed_at = public._now() where id = s.id;
    if public._grant(v_user, 'xp', 10, 'play_complete', s.id::text, 'play_complete:' || s.id) then v_xp := v_xp + 10; end if;
  end if;

  return jsonb_build_object('recorded', v_new, 'correct', v_correct, 'xp', v_xp, 'seeds', v_seeds,
                            'corrected', v_corrected, 'results', v_results,
                            'achievements', to_jsonb(public._check_achievements(v_user)),
                            'balance', (select seeds from public.profiles where id = v_user));
end $$;

-- Aides (mode Jouer uniquement). Le serveur délivre le contenu de l'aide : rien de caché côté client.
-- kinds : fifty_fifty (15), hint (10), context (5)
create or replace function public.play_spend_help(p_session uuid, p_question uuid, p_kind text) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  s public.play_sessions;
  q public.questions;
  v_cost int;
  v_content jsonb;
begin
  select * into s from public.play_sessions where id = p_session and user_id = v_user;
  if not found or not (p_question = any (s.question_ids)) then raise exception 'session_not_found'; end if;
  if p_question = any (public._protected_daily_questions()) then raise exception 'not_allowed'; end if;
  select * into q from public.questions where id = p_question;

  v_cost := case p_kind when 'fifty_fifty' then 15 when 'hint' then 10 when 'context' then 5 end;
  if v_cost is null then raise exception 'invalid_help'; end if;

  if p_kind = 'fifty_fifty' then
    if q.type not in ('mcq', 'map_pick') or jsonb_array_length(q.payload -> 'options') < 3 then raise exception 'help_unavailable'; end if;
    v_content := jsonb_build_object('remove', (
      select jsonb_agg(o ->> 'id') from (
        select o from jsonb_array_elements(q.payload -> 'options') o
        where o ->> 'id' <> q.answer ->> 'option_id' order by random()
        limit jsonb_array_length(q.payload -> 'options') - 2) t));
  elsif p_kind = 'hint' then
    if q.hint is null then raise exception 'help_unavailable'; end if;
    v_content := jsonb_build_object('hint', q.hint);
  else
    if q.context_note is null then raise exception 'help_unavailable'; end if;
    v_content := jsonb_build_object('context', q.context_note);
  end if;

  -- Une aide déjà achetée pour cette question dans cette session n'est pas refacturée.
  perform public._grant(v_user, 'seeds', -v_cost, 'spend_' || p_kind, q.id::text,
                        'help:' || s.id || ':' || q.id || ':' || p_kind);
  return v_content || jsonb_build_object('balance', (select seeds from public.profiles where id = v_user));
end $$;

-- ─────────────────────────────────────────── Onboarding : 3 vraies questions, faciles à moyennes, domaines variés.
create or replace function public.onboarding_pack() returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  v_session uuid := gen_random_uuid();
  v_ids uuid[];
begin
  select array_agg(id) into v_ids from (
    select distinct on (q.domain_id) q.id, q.domain_id
    from public.questions q
    where q.status = 'published' and q.type in ('mcq', 'true_false', 'numeric')
      and q.difficulty_effective between 25 and 50
      and q.domain_id in ('geography', 'history', 'french', 'science', 'calc')
      and q.id <> all (public._protected_daily_questions())
    order by q.domain_id, random()
  ) t order by random() limit 3;

  insert into public.play_sessions (id, user_id, mode, question_ids, created_at)
  values (v_session, v_user, 'onboarding', coalesce(v_ids, '{}'), public._now());

  return jsonb_build_object('session_id', v_session, 'questions', coalesce((
    select jsonb_agg(public._question_public(q, v_session::text) || public._question_reveal(q)
                     || jsonb_build_object('concept_id', q.concept_id) order by array_position(v_ids, q.id))
    from public.questions q where q.id = any (v_ids)), '[]'::jsonb));
end $$;
