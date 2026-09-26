-- Parties classées / entraînement libre, difficulté choisie, variété des familles.
do $$
declare
  u uuid := tst.new_user();
  pack jsonb; sub jsonb; ids uuid[]; atts jsonb := '[]'::jsonb; x jsonb;
  mu_before real; mu_after real; seeds_before int; seeds_after int;
begin
  perform tst.clock('2026-11-10 10:00:00+01');
  perform tst.login(u);

  -- Classée par défaut ; la difficulté demandée est ignorée en classé.
  pack := public.play_pack('training', 'history', null, 10, true, 'beginner');
  perform tst.ok((pack ->> 'ranked')::bool and pack ->> 'level' = 'adaptive', 'classé = adaptatif');

  -- Entraînement libre débutant : questions faciles du seul domaine choisi.
  pack := public.play_pack('training', 'history', null, 12, false, 'beginner');
  perform tst.ok(not (pack ->> 'ranked')::bool and pack ->> 'level' = 'beginner', 'entraînement libre débutant');
  select array_agg((q ->> 'id')::uuid) into ids from jsonb_array_elements(pack -> 'questions') q;
  perform tst.ok(cardinality(ids) = 12, 'nombre de questions choisi');
  perform tst.ok((select bool_and(domain_id = 'history') from public.questions where id = any (ids)), 'uniquement le domaine choisi');
  perform tst.ok((select avg(difficulty_effective) from public.questions where id = any (ids)) < 45, 'difficulté débutant');

  -- Plusieurs sous-thèmes choisis : uniquement ceux-là.
  pack := public.play_pack('training', 'geography', null, 10, true, null, array['geography.flags', 'geography.capitals']);
  perform tst.ok((select bool_and(z ->> 'subdomain_id' in ('geography.flags', 'geography.capitals'))
                  from jsonb_array_elements(pack -> 'questions') z), 'sous-thèmes choisis');
  perform tst.ok(jsonb_array_length(pack -> 'questions') >= 2, 'sous-thèmes : des questions');
  perform tst.throws('select public.play_pack(''training'', ''history'', null, 10, true, null, array[''geography.flags''])', 'invalid_scope');

  -- Expert : nettement plus dur.
  pack := public.play_pack('training', 'geography', null, 10, false, 'expert');
  perform tst.ok((select avg(difficulty_effective) from public.questions q
                  where q.id in (select (y ->> 'id')::uuid from jsonb_array_elements(pack -> 'questions') y)) > 55, 'difficulté expert');

  -- 30 questions possibles, pas plus.
  pack := public.play_pack('training', 'geography', null, 30, false, null);
  perform tst.ok(jsonb_array_length(pack -> 'questions') = 30, '30 questions');
  perform tst.throws('select public.play_pack(''training'', ''geography'', null, 31, false, null)', 'invalid_count');
  perform tst.throws('select public.play_pack(''training'', ''geography'', null, 10, false, ''legend'')', 'invalid_level');

  -- Entraînement libre : le niveau ne bouge pas, pas de graines, XP réduite ; les erreurs restent suivies.
  pack := public.play_pack('training', 'science', null, 10, false, 'intermediate');
  select mu into mu_before from public._skill_peek(u, 'science');
  select seeds into seeds_before from public.profiles where id = u;
  for x in select * from jsonb_array_elements(pack -> 'questions') loop
    atts := atts || jsonb_build_object('client_attempt_id', gen_random_uuid(), 'question_id', x ->> 'id',
                                       'given', case when jsonb_array_length(atts) = 0 then tst.wrong_given()
                                                     else tst.correct_given((x ->> 'id')::uuid) end, 'response_ms', 5000);
  end loop;
  sub := public.play_submit((pack ->> 'session_id')::uuid, atts);
  select mu into mu_after from public._skill_peek(u, 'science');
  select seeds into seeds_after from public.profiles where id = u;
  perform tst.ok(mu_after = mu_before, 'entraînement : niveau inchangé');
  perform tst.ok(not exists (select 1 from public.user_skills where user_id = u and scope_id like 'science%'), 'aucune compétence écrite');
  perform tst.ok(seeds_after = seeds_before and (sub ->> 'seeds')::int = 0, 'entraînement : pas de graines');
  perform tst.ok((sub ->> 'xp')::int between 1 and 9 * 3 + 5, 'entraînement : XP réduite');
  perform tst.ok(sub -> 'results' -> 0 ->> 'error_transition' = 'new_error', 'entraînement : erreur suivie');

  -- Partie classée : le niveau bouge.
  pack := public.play_pack('training', 'science', null, 5, true, null);
  atts := '[]'::jsonb;
  for x in select * from jsonb_array_elements(pack -> 'questions') loop
    atts := atts || jsonb_build_object('client_attempt_id', gen_random_uuid(), 'question_id', x ->> 'id',
                                       'given', tst.correct_given((x ->> 'id')::uuid), 'response_ms', 5000);
  end loop;
  sub := public.play_submit((pack ->> 'session_id')::uuid, atts);
  select mu into mu_after from public._skill_peek(u, 'science');
  perform tst.ok(mu_after > mu_before, 'classé : le niveau monte');
end $$;

-- Variété : en géographie (très fournie), une seule question par famille dans une partie de 10.
do $$
declare u uuid := tst.new_user(); pack jsonb;
begin
  perform tst.clock('2026-11-11 10:00:00+01');
  perform tst.login(u);
  for i in 1 .. 5 loop
    pack := public.play_pack('training', 'geography', null, 10, true, null);
    perform tst.ok((select max(n) from (select count(*) n from public.questions q
                    where q.id in (select (y ->> 'id')::uuid from jsonb_array_elements(pack -> 'questions') y) and q.family is not null
                    group by q.family) t) <= 1, 'une question par famille');
  end loop;
end $$;
