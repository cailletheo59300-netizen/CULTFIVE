-- Brainlix — 0028 Seconde chance
-- Après une mauvaise réponse (partie Jouer, jamais au 5 du jour), le joueur peut réessayer avant de voir la réponse :
-- 15 graines ou un ticket « indice ». Réussite au 2e essai : moitié des points et de l'XP, demi-réussite pour l'Elo
-- en partie classée (score 0,5 dans la mise à jour bayésienne), pas de calibration de la question, et la notion
-- reste à revoir (le joueur ne la savait pas du premier coup).
-- L'app envoie « first_given » (1er essai) et « given » (2e) ; le serveur ne retient le 2e essai que si la Seconde
-- chance a bien été payée et que le 1er essai est faux. Sinon, c'est le 1er essai qui compte.

alter table public.question_attempts add column second_chance bool not null default false;

-- ─────────────────────────────────────────── Elo : résultat fractionnaire
do $$
declare
  v_old text;
  v_new text;
begin
  v_old := pg_get_functiondef('public._skill_update(uuid, text, real, real, bool, int, real)'::regprocedure);
  v_new := replace(replace(v_old,
    'p_guess real DEFAULT 0, OUT mu_before real',
    'p_guess real DEFAULT 0, p_score real DEFAULT NULL::real, OUT mu_before real'),
    '((case when p_correct then 1 else 0 end) - v_e)',
    '(coalesce(p_score, case when p_correct then 1 else 0 end) - v_e)');
  if v_new not like '%p_score real DEFAULT NULL%' or v_new not like '%coalesce(p_score,%' then
    raise exception '0028: _skill_update inchangée';
  end if;
  drop function public._skill_update(uuid, text, real, real, bool, int, real);
  execute v_new;
end $$;

-- ─────────────────────────────────────────── Enregistrement d'une réponse
drop function public._record_attempt(uuid, uuid, jsonb, int, public.attempt_context, uuid, uuid, bool);
create function public._record_attempt(p_user uuid, p_question uuid, p_given jsonb, p_ms integer, p_context public.attempt_context,
                                       p_session uuid, p_client_id uuid, p_ranked boolean default true,
                                       p_second_chance boolean default false)
returns jsonb
language plpgsql
set search_path to 'public', 'extensions', 'pg_temp'
as $$
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
                                        created_at, second_chance)
  values (p_client_id, p_user, q.id, q.concept_id, p_context, p_session, p_given,
          v_correct, p_ms, q.difficulty_effective, v_sub.mu_before, v_sub.expected, v_seen, v_now, coalesce(p_second_chance, false));

  update public.profiles set
    questions_answered = questions_answered + 1,
    questions_correct  = questions_correct + v_correct::int,
    errors_corrected   = errors_corrected + (v_transition is not distinct from 'corrected')::int
  where id = p_user;

  return jsonb_build_object(
    'duplicate', false,
    'is_correct', v_correct,
    'second_chance', coalesce(p_second_chance, false),
    'error_transition', v_transition,
    'error_since', v_uc.error_since,
    'domain_id', q.domain_id,
    'domain_before', round(v_dom.mu_before::numeric, 1),
    'domain_after', round(v_dom.mu_after::numeric, 1),
    'expected', round(v_sub.expected::numeric, 3));
end $$;

-- La Seconde chance est retenue si elle a été payée (graines ou ticket) et que le 1er essai est faux.
create or replace function public._second_chance_ok(p_user uuid, p_session uuid, p_question uuid, p_first_given jsonb)
returns bool language sql stable as $$
  select (exists (select 1 from public.ledger where user_id = p_user and idempotency_key = 'help:' || p_session || ':' || p_question || ':second_chance')
          or exists (select 1 from public.help_ticket_uses where user_id = p_user and key = 'help:' || p_session || ':' || p_question || ':second_chance'))
     and not coalesce((select public._evaluate(q.type, q.answer, p_first_given) from public.questions q where q.id = p_question), true)
$$;

do $$
declare
  f record;
  v_old text;
  v_new text;
begin
  -- Aide « second_chance » : 15 graines ou un ticket indice ; rien n'est dévoilé.
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'play_spend_help' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(v_old,
      'when ''context'' then 5 end;',
      'when ''context'' then 5 when ''second_chance'' then 15 end;');
    v_new := replace(v_new,
      '  elsif p_kind = ''hint'' then',
      '  elsif p_kind = ''second_chance'' then
    if q.type = ''true_false'' or (q.type in (''mcq'', ''map_pick'') and jsonb_array_length(q.payload -> ''options'') < 3) then
      raise exception ''help_unavailable'';
    end if;
    v_content := ''{}''::jsonb;
  elsif p_kind = ''hint'' then');
    v_new := replace(v_new, 'if p_kind in (''fifty_fifty'', ''hint'') then', 'if p_kind in (''fifty_fifty'', ''hint'', ''second_chance'') then');
    v_new := replace(v_new, 'item_id = ''ticket_'' || p_kind',
                            'item_id = ''ticket_'' || case when p_kind = ''second_chance'' then ''hint'' else p_kind end');
    if v_new not like '%when ''second_chance'' then 15%' or v_new not like '%elsif p_kind = ''second_chance'' then%'
       or v_new not like '%''hint'', ''second_chance'')%' or v_new like '%item_id = ''ticket_'' || p_kind%' then
      raise exception '0028: play_spend_help inchangée';
    end if;
    execute v_new;
  end loop;

  -- Envoi des réponses : 2e essai retenu si la Seconde chance est valable ; XP réduite de moitié.
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = '_play_submit_base' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(v_old, '  v_total_correct int;', '  v_total_correct int;
  v_sc bool;');
    v_new := replace(v_new,
      '    v_res := public._record_attempt(v_user, v_qid, a -> ''given'', v_ms, v_ctx, s.id, (a ->> ''client_attempt_id'')::uuid, s.ranked);',
      '    v_sc := a ? ''first_given'' and public._second_chance_ok(v_user, s.id, v_qid, a -> ''first_given'');
    v_res := public._record_attempt(v_user, v_qid, case when a ? ''first_given'' and not v_sc then a -> ''first_given'' else a -> ''given'' end,
                                    v_ms, v_ctx, s.id, (a ->> ''client_attempt_id'')::uuid, s.ranked, v_sc);');
    v_new := replace(v_new,
      '''error_transition'', v_res -> ''error_transition'',',
      '''error_transition'', v_res -> ''error_transition'', ''second_chance'', coalesce((v_res ->> ''second_chance'')::bool, false),');
    v_new := replace(v_new,
      'case when s.ranked or s.mode = ''errors'' then 5 else 3 end, 300',
      'case when (v_res ->> ''second_chance'')::bool then (case when s.ranked or s.mode = ''errors'' then 3 else 2 end)
                                                 when s.ranked or s.mode = ''errors'' then 5 else 3 end, 300');
    if v_new not like '%v_sc bool;%' or v_new not like '%s.ranked, v_sc);%' or v_new not like '%''second_chance'', coalesce(%'
       or v_new not like '%then 3 else 2 end)%' then
      raise exception '0028: _play_submit_base inchangée';
    end if;
    execute v_new;
  end loop;

  -- Points : moitié pour une Seconde chance réussie.
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = '_play_submit_rated' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(v_old,
      'public._attempt_points(a.is_correct, a.expected, a.response_ms)',
      'public._attempt_points(a.is_correct, a.expected, a.response_ms) / (case when a.second_chance then 2 else 1 end)');
    if v_new = v_old then raise exception '0028: _play_submit_rated inchangée'; end if;
    execute v_new;
  end loop;
end $$;

-- ─────────────────────────────────────────── Droits
revoke execute on function public._skill_update(uuid, text, real, real, bool, int, real, real) from public, anon, authenticated;
revoke execute on function public._record_attempt(uuid, uuid, jsonb, int, public.attempt_context, uuid, uuid, bool, bool) from public, anon, authenticated;
revoke execute on function public._second_chance_ok(uuid, uuid, uuid, jsonb) from public, anon, authenticated;
alter function public._second_chance_ok(uuid, uuid, uuid, jsonb) set search_path = public, pg_temp;
