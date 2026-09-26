-- Adaptation : progression prudente, confiance, calibration bornée, sélection, erreurs.

-- Compétence : pas de saut brutal, steps décroissants, prior d'onboarding.
do $$
declare
  u uuid := tst.new_user();
  q public.questions;
  prev real := 50; cur real; step real; first_step real; last_step real;
  s record;
begin
  perform tst.clock('2026-11-01 10:00:00+01');
  select * into q from public.questions where external_key = 'geo-015';  -- facile (18)
  for i in 1 .. 25 loop
    perform public._record_attempt(u, q.id, tst.correct_given(q.id), 3000, 'training', null, gen_random_uuid());
    select mu into cur from public.user_skills where user_id = u and scope_id = 'geography';
    step := cur - prev;
    perform tst.ok(step >= 0 and step <= 4.0001, 'progression bornée à 4 points, obtenu ' || step);
    if i = 1 then first_step := step; end if;
    last_step := step;
    prev := cur;
  end loop;
  perform tst.ok(first_step between 0.1 and 3, 'une bonne réponse à une question facile bouge peu : ' || first_step);
  perform tst.ok(last_step < first_step, 'les pas diminuent avec la confiance');
  select * into s from public.user_skills where user_id = u and scope_id = 'geography';
  perform tst.ok(s.var < 100, 'incertitude réduite');
  perform tst.ok(s.n = 25 and s.correct = 25, 'compteurs');
  perform tst.ok(exists (select 1 from public.user_skills where user_id = u and scope_id = 'geography.countries'), 'sous-domaine suivi');

  -- Une bonne réponse à une question difficile, face à une incertitude forte, fait bouger davantage qu'une facile
  select * into q from public.questions where external_key = 'geo-018';  -- 65
  perform public._record_attempt(u, q.id, tst.correct_given(q.id), 3000, 'training', null, gen_random_uuid());
  select mu into cur from public.user_skills where user_id = u and scope_id = 'geography';
  perform tst.ok(cur - prev > last_step, 'réussir plus dur que son niveau rapporte plus');

  -- Réinflation après inactivité (bornée par le prior)
  perform tst.tick('100 days');
  perform tst.ok((select var from public._skill_peek(u, 'geography')) > s.var, 'incertitude remonte après inactivité');
  perform tst.ok((select var from public._skill_peek(u, 'geography')) <= 100, 'réinflation plafonnée');
end $$;

-- Onboarding : le choix de challenge est un prior, puis remplacé par les données.
do $$
declare u uuid := tst.new_user();
begin
  perform tst.login(u);
  perform public.complete_onboarding('expert', array['history', 'science', 'nope']);
  perform tst.ok((select challenge_prior from public.profiles where id = u) = 70, 'prior expert = 70');
  perform tst.ok((select interests from public.profiles where id = u) = array['history', 'science'], 'intérêts filtrés');
  perform tst.ok((select mu from public._skill_peek(u, 'calc')) = 70, 'domaine jamais joué : prior');
  perform tst.ok((select mu from public._skill_peek(u, 'calc.fractions')) = 70, 'sous-domaine hérite du domaine');
  perform tst.throws('select public.complete_onboarding(''legend'', ''{}'')', 'invalid_level');
end $$;

-- Calibration : bornée à [min, max] tant que la preuve n'est pas solide.
do $$
declare
  q public.questions;
  strong uuid;
begin
  perform tst.clock('2026-11-02 10:00:00+01');
  select * into q from public.questions where external_key = 'fr-002';  -- 32, plage [22, 42]
  for i in 1 .. 60 loop
    strong := tst.new_user();
    update public.user_skills set mu = 80 where user_id = strong;
    insert into public.user_skills (user_id, scope_id, mu, var) values (strong, 'french.vocabulary', 80, 16), (strong, 'french', 80, 16);
    perform public._record_attempt(strong, q.id, tst.wrong_given(), 3000, 'training', null, gen_random_uuid());
  end loop;
  select * into q from public.questions where id = q.id;
  perform tst.ok(q.difficulty_observed > q.difficulty_max, 'difficulté observée au-delà de la plage : ' || q.difficulty_observed);
  perform tst.ok(q.difficulty_effective = q.difficulty_max, 'difficulté effective plafonnée à max');
  perform tst.ok(q.difficulty_max = 42, 'plage non élargie avant 300 réponses');
  perform tst.ok(q.answer_count = 60 and q.correct_count = 0, 'compteurs de la question');
  perform tst.ok(q.needs_review and q.review_reason = 'success_rate_below_5', 'question signalée problématique');
  perform tst.ok(q.confidence > 0, 'confiance de calibration > 0');
end $$;

-- Élargissement : seulement avec n ≥ 300 et écart > 2σ, par pas de 5.
do $$
declare q public.questions; u uuid := tst.new_user();
begin
  select * into q from public.questions where external_key = 'fr-003';
  update public.questions set answer_count = 299, difficulty_observed = 90, difficulty_var = 4, last_widen_count = 0 where id = q.id;
  perform public._question_update(q.id, 90, 16, false);
  select * into q from public.questions where id = q.id;
  perform tst.ok(q.difficulty_max = 65 + 5, 'borne max élargie de 5 : ' || q.difficulty_max);
  perform tst.ok(q.range_widenings = 1 and q.last_widen_count = 300, 'élargissement tracé');
  perform public._question_update(q.id, 90, 16, false);
  select * into q from public.questions where id = q.id;
  perform tst.ok(q.difficulty_max = 70, 'pas de second élargissement avant 100 réponses de plus');
end $$;

-- Sélection : filtres, pas de doublon de concept, questions du Daily protégées.
do $$
declare u uuid := tst.new_user(); pack jsonb; ids uuid[]; protected uuid[];
begin
  perform tst.clock('2026-11-03 10:00:00+01');
  perform tst.login(u);
  delete from public.daily_sets where daily_date > '2026-11-05';  -- séries futures créées par d'autres tests
  perform public.daily_start();  -- génère le Daily du jour (questions protégées)
  protected := public._protected_daily_questions();
  perform tst.ok(cardinality(protected) >= 5, 'questions protégées');

  pack := public.play_pack('training', 'geography', null, 10);
  select array_agg((x ->> 'id')::uuid) into ids from jsonb_array_elements(pack -> 'questions') x;
  perform tst.ok(cardinality(ids) = 10, 'pack de 10');
  perform tst.ok(not (ids && protected), 'aucune question du Daily dans un pack');
  perform tst.ok((select count(distinct concept_id) from public.questions where id = any (ids)) = 10, 'concepts distincts');
  perform tst.ok((select bool_and(domain_id = 'geography') from public.questions where id = any (ids)), 'filtre domaine');
  perform tst.ok(pack -> 'questions' -> 0 ? 'answer', 'pack Jouer contient les réponses (hors-ligne)');

  pack := public.play_pack('training', 'geography', 'geography.capitals', 20);
  perform tst.ok((select bool_and(x ->> 'subdomain_id' = 'geography.capitals') from jsonb_array_elements(pack -> 'questions') x), 'filtre sous-domaine');
  perform tst.ok(jsonb_array_length(pack -> 'questions') <= 7, 'sous-domaine épuisé : pas de remplissage hors filtre');

  pack := public.play_pack('quick', null, null, 10);
  perform tst.ok(jsonb_array_length(pack -> 'questions') = 10, 'partie rapide multi-domaines');
  perform tst.ok((select count(distinct x ->> 'domain_id') from jsonb_array_elements(pack -> 'questions') x) >= 4, 'partie rapide variée');
  pack := public.play_pack('challenge', null, null, 10);
  perform tst.ok(jsonb_array_length(pack -> 'questions') = 10, 'défi');
  perform tst.throws('select public.play_pack(''training'', null, null, 10)', 'domain_required');
  perform tst.throws('select public.play_pack(''training'', ''calc'', ''geography.capitals'', 10)', 'invalid_scope');
end $$;

-- Erreurs : raté → actif → corrigé (récompensé après 1 h) → maîtrisé (≥ 3 jours plus tard) ; historique conservé.
do $$
declare
  u uuid := tst.new_user();
  pack jsonb; sub jsonb; q jsonb; v_qid uuid; v_concept text;
begin
  perform tst.clock('2026-11-04 10:00:00+01');
  perform tst.login(u);
  pack := public.play_pack('training', 'history', null, 3);
  q := pack -> 'questions' -> 0; v_qid := (q ->> 'id')::uuid; v_concept := q ->> 'concept_id';
  sub := public.play_submit((pack ->> 'session_id')::uuid, jsonb_build_array(
    jsonb_build_object('client_attempt_id', gen_random_uuid(), 'question_id', v_qid, 'given', tst.wrong_given(), 'response_ms', 4000)));
  perform tst.ok(sub -> 'results' -> 0 ->> 'error_transition' = 'new_error', 'nouvelle erreur');
  perform tst.ok((select error_state from public.user_concepts where user_id = u and concept_id = v_concept) = 'failed', 'état failed');
  perform tst.ok((public.errors_overview() -> 'active' -> 0 ->> 'concept_id') = v_concept, 'visible dans Mes erreurs');

  -- Échec répété en mode Erreurs → « à revoir »
  pack := public.play_pack('errors', null, null, 5);
  perform tst.ok(pack -> 'questions' -> 0 ->> 'concept_id' = v_concept, 'le pack Erreurs sert le concept raté');
  sub := public.play_submit((pack ->> 'session_id')::uuid, jsonb_build_array(
    jsonb_build_object('client_attempt_id', gen_random_uuid(), 'question_id', pack -> 'questions' -> 0 ->> 'id', 'given', tst.wrong_given(), 'response_ms', 4000)));
  perform tst.ok((select error_state from public.user_concepts where user_id = u and concept_id = v_concept) = 'to_review', 'état to_review');

  -- Correction immédiate : corrigée mais non récompensée (anti-farm)
  pack := public.play_pack('errors', null, null, 5);
  v_qid := (pack -> 'questions' -> 0 ->> 'id')::uuid;
  sub := public.play_submit((pack ->> 'session_id')::uuid, jsonb_build_array(
    jsonb_build_object('client_attempt_id', gen_random_uuid(), 'question_id', v_qid, 'given', tst.correct_given(v_qid), 'response_ms', 4000)));
  perform tst.ok(sub -> 'results' -> 0 ->> 'error_transition' = 'corrected', 'ERREUR CORRIGÉE');
  perform tst.ok(jsonb_array_length(public.errors_overview() -> 'active') = 0, 'sort des erreurs actives');
  perform tst.ok(not exists (select 1 from public.ledger where user_id = u and reason = 'error_corrected'), 'pas de récompense si corrigée < 1 h');

  -- Nouvel échec plus tard : revient ; correction 2 h après : récompensée ; puis maîtrise 4 jours plus tard
  pack := public.play_pack('training', 'history', null, 20);
  select x into q from jsonb_array_elements(pack -> 'questions') x where x ->> 'concept_id' = v_concept;
  if q is null then
    -- le concept peut être filtré par la récence ; on force via le pack Erreurs après un échec direct
    perform public._record_attempt(u, v_qid, tst.wrong_given(), 3000, 'training', null, gen_random_uuid());
  else
    perform public.play_submit((pack ->> 'session_id')::uuid, jsonb_build_array(
      jsonb_build_object('client_attempt_id', gen_random_uuid(), 'question_id', q ->> 'id', 'given', tst.wrong_given(), 'response_ms', 4000)));
  end if;
  perform tst.ok((select error_state from public.user_concepts where user_id = u and concept_id = v_concept) = 'failed', 'l''erreur revient');
  perform tst.tick('2 hours');
  pack := public.play_pack('errors', null, null, 5);
  v_qid := (pack -> 'questions' -> 0 ->> 'id')::uuid;
  sub := public.play_submit((pack ->> 'session_id')::uuid, jsonb_build_array(
    jsonb_build_object('client_attempt_id', gen_random_uuid(), 'question_id', v_qid, 'given', tst.correct_given(v_qid), 'response_ms', 4000)));
  perform tst.ok((sub ->> 'xp')::int >= 15, 'correction récompensée (XP) : ' || (sub ->> 'xp'));
  perform tst.tick('4 days');
  perform public._record_attempt(u, v_qid, tst.correct_given(v_qid), 3000, 'training', null, gen_random_uuid());
  perform tst.ok((select error_state from public.user_concepts where user_id = u and concept_id = v_concept) = 'mastered', 'maîtrisée');
  perform tst.ok((select count(*) from public.question_attempts where user_id = u and concept_id = v_concept) >= 5, 'historique conservé');
  perform tst.ok((select errors_corrected from public.profiles where id = u) = 2, 'compteur d''erreurs corrigées');
end $$;

-- Idempotence : rejouer un lot de tentatives n'a aucun effet.
do $$
declare u uuid := tst.new_user(); pack jsonb; batch jsonb; s1 jsonb; s2 jsonb; xp int;
begin
  perform tst.clock('2026-11-10 10:00:00+01');
  perform tst.login(u);
  pack := public.play_pack('quick', null, null, 10);
  select jsonb_agg(jsonb_build_object('client_attempt_id', gen_random_uuid(), 'question_id', x ->> 'id',
                                      'given', tst.correct_given((x ->> 'id')::uuid), 'response_ms', 2500))
    into batch from jsonb_array_elements(pack -> 'questions') x;
  s1 := public.play_submit((pack ->> 'session_id')::uuid, batch);
  xp := (select xp_total from public.profiles where id = u);
  s2 := public.play_submit((pack ->> 'session_id')::uuid, batch);
  perform tst.ok((s1 ->> 'recorded')::int = 10 and (s2 ->> 'recorded')::int = 0, 'second envoi ignoré');
  perform tst.ok((select xp_total from public.profiles where id = u) = xp, 'aucune XP en double');
  perform tst.ok(xp = 10 * 5 + 10, 'XP partie : 10 × 5 + bonus 10, obtenu ' || xp);
  perform tst.ok((select seeds from public.profiles where id = u) = 4, '2 graines par tranche de 5 bonnes réponses');
  -- Une question non servie dans la session est refusée
  s2 := public.play_submit((pack ->> 'session_id')::uuid, jsonb_build_array(jsonb_build_object(
          'client_attempt_id', gen_random_uuid(), 'question_id', (select id from public.questions where external_key = 'calc-001'), 'given', '{}', 'response_ms', 3000)));
  perform tst.ok((s2 ->> 'recorded')::int = 0 or (pack -> 'questions') @> jsonb_build_array(jsonb_build_object('id', (select id from public.questions where external_key = 'calc-001'))), 'question hors session ignorée');
end $$;
