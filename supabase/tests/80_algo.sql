-- Algo 0016 : hasard, thèmes équilibrés, révision espacée injectée dans les parties.
do $$
declare
  u1 uuid := tst.new_user(); u2 uuid := tst.new_user();
  r1 record; r2 record;
  q_mcq public.questions; q_num public.questions;
begin
  perform tst.clock('2027-04-01 10:00:00+02');

  -- Taux de hasard par type.
  select * into q_mcq from public.questions where type = 'mcq' and jsonb_array_length(payload -> 'options') = 4 limit 1;
  select * into q_num from public.questions where type = 'numeric' limit 1;
  perform tst.ok(q_mcq.guess_rate = 0.25 and q_num.guess_rate = 0, 'hasard : QCM 1/4, numérique 0');
  perform tst.ok((select bool_and(guess_rate = 0.5) from public.questions where type = 'true_false'), 'hasard : Vrai/Faux 1/2');

  -- Même difficulté : une bonne réponse devinable fait moins monter, une erreur devinable fait plus baisser.
  select * into r1 from public._skill_update(u1, 'history', 50, 20, true, 4000, 0.25);
  select * into r2 from public._skill_update(u2, 'history', 50, 20, true, 4000, 0);
  perform tst.ok(r1.mu_after - r1.mu_before < r2.mu_after - r2.mu_before, 'QCM juste < numérique juste');
  perform tst.ok(r1.expected > r2.expected, 'chances plus hautes avec le hasard');
  select * into r1 from public._skill_update(u1, 'sport', 50, 20, false, 4000, 0.5);
  select * into r2 from public._skill_update(u2, 'sport', 50, 20, false, 4000, 0);
  perform tst.ok(r1.mu_before - r1.mu_after > r2.mu_before - r2.mu_after, 'Vrai/Faux raté > numérique raté');
  -- Sans hasard, le modèle est inchangé (Rasch/Glicko d'origine).
  perform tst.ok(abs(public._expect_q(55, 50, 20, 0) - public._expect(55, 50, 20)) < 1e-9, 'c = 0 : modèle d''origine');
end $$;

-- Thèmes équilibrés : une partie de 10 en géographie (5 thèmes) → 2 questions par thème.
do $$
declare u uuid := tst.new_user(); pack jsonb;
begin
  perform tst.clock('2027-04-02 10:00:00+02');
  perform tst.login(u);
  for i in 1 .. 3 loop
    pack := public.play_pack('training', 'geography', null, 10, true, null);
    perform tst.ok((select max(n) from (select count(*) n from jsonb_array_elements(pack -> 'questions') z
                                         group by z ->> 'subdomain_id') t) <= 3, 'thèmes équilibrés');
    perform tst.ok((select count(distinct z ->> 'subdomain_id') from jsonb_array_elements(pack -> 'questions') z) >= 4, 'plusieurs thèmes');
  end loop;
end $$;

-- Révision due : l'erreur d'hier revient dans une partie classée du domaine, jamais en première question.
do $$
declare u uuid := tst.new_user(); pack jsonb; q public.questions; pos int;
begin
  perform tst.clock('2027-04-03 10:00:00+02');
  perform tst.login(u);
  select * into q from public.questions where domain_id = 'history' and status = 'published' and type = 'mcq' limit 1;
  perform public._record_attempt(u, q.id, tst.wrong_given(), 3000, 'training', null, gen_random_uuid());
  -- Pas encore due.
  pack := public.play_pack('training', 'history', null, 10, true, null);
  perform tst.ok(not exists (select 1 from jsonb_array_elements(pack -> 'questions') z where z ->> 'concept_id' = q.concept_id), 'pas avant l''échéance');
  perform tst.tick('25 hours');
  pack := public.play_pack('training', 'history', null, 10, true, null);
  select i into pos from jsonb_array_elements(pack -> 'questions') with ordinality t(z, i) where z ->> 'concept_id' = q.concept_id;
  perform tst.ok(pos is not null and pos > 1, 'révision glissée dans la partie (position ' || coalesce(pos, 0) || ')');
  perform tst.ok(jsonb_array_length(pack -> 'questions') = 10, 'toujours 10 questions');
  -- Entraînement libre à difficulté fixe : pas d'injection.
  pack := public.play_pack('training', 'history', null, 10, false, 'beginner');
  perform tst.ok(not exists (select 1 from jsonb_array_elements(pack -> 'questions') z where z ->> 'concept_id' = q.concept_id), 'pas en difficulté fixe');
  -- « Mes erreurs » : une notion en consolidation arrivée à échéance revient aussi.
  perform public._record_attempt(u, q.id, tst.correct_given(q.id), 3000, 'errors', null, gen_random_uuid());
  perform tst.ok((select error_state = 'correct_once' from public.user_concepts where user_id = u and concept_id = q.concept_id), 'corrigée');
  perform tst.ok(cardinality(public._select_error_questions(u, 5)) = 0, 'rien à revoir avant 3 jours');
  perform tst.tick('3 days 1 hour');
  perform tst.ok(cardinality(public._select_error_questions(u, 5)) = 1, 'révision due dans Mes erreurs');
end $$;
