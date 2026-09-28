-- Cote CULT : placement, pack enrichi, points, variation de cote, et simulation de convergence.
do $$
declare
  u uuid := tst.new_user();
  pack jsonb; sub jsonb; atts jsonb; x jsonb; sk jsonb; ds jsonb;
begin
  perform tst.clock('2026-11-20 10:00:00+01');
  perform tst.login(u);

  perform tst.ok(public._cote(50) = 1000 and public._cote(73.03) = 1400 and public._cote(26.97) = 600, 'échelle de la cote');

  -- Nouveau joueur : placement 0/5, cote non « placée ».
  sk := (select s from jsonb_array_elements(public.skills_overview()) s where s ->> 'domain_id' = 'history');
  perform tst.ok((sk ->> 'placement')::int = 0 and not (sk ->> 'placed')::bool and (sk ->> 'cote')::int = 1000, 'placement initial');

  -- Pack : difficulté et chances de réussite par question.
  pack := public.play_pack('training', 'history', null, 10, true, null);
  perform tst.ok((select bool_and(q ? 'difficulty' and (q ->> 'expected')::real between 0 and 1)
                  from jsonb_array_elements(pack -> 'questions') q), 'pack : difficulty + expected');
  -- Plus exigeant : chances moyennes nettement sous 75 %.
  perform tst.ok((select avg((q ->> 'expected')::real) from jsonb_array_elements(pack -> 'questions') q) between 0.45 and 0.85, 'pack autour de la cote');

  -- Partie classée tout juste : points, cote qui monte, placement 1/5.
  atts := '[]'::jsonb;
  for x in select * from jsonb_array_elements(pack -> 'questions') loop
    atts := atts || jsonb_build_object('client_attempt_id', gen_random_uuid(), 'question_id', x ->> 'id',
                                       'given', tst.correct_given((x ->> 'id')::uuid), 'response_ms', 4000);
  end loop;
  sub := public.play_submit((pack ->> 'session_id')::uuid, atts);
  perform tst.ok((sub ->> 'points')::int between 10 * 50 and 10 * 180, 'points de partie');
  perform tst.ok((select bool_and((r ->> 'points')::int > 50) from jsonb_array_elements(sub -> 'results') r), 'points par question');
  perform tst.ok(jsonb_array_length(sub -> 'ratings') = 1 and sub -> 'ratings' -> 0 ->> 'domain_id' = 'history', 'variation de cote');
  perform tst.ok((sub -> 'ratings' -> 0 ->> 'cote_after')::int > (sub -> 'ratings' -> 0 ->> 'cote_before')::int, 'cote en hausse');
  perform tst.ok((sub -> 'ratings' -> 0 ->> 'placement')::int = 1, 'placement 1/5');
  -- Placement : pas doublé, 10 bonnes réponses font nettement monter.
  perform tst.ok((sub -> 'ratings' -> 0 ->> 'cote_after')::int - (sub -> 'ratings' -> 0 ->> 'cote_before')::int > 150, 'placement rapide');

  -- Renvoi identique (file hors-ligne) : mêmes points.
  perform tst.ok((public.play_submit((pack ->> 'session_id')::uuid, atts) ->> 'points')::int = (sub ->> 'points')::int, 'points idempotents');

  -- Statistiques du domaine : cote du domaine et des thèmes.
  ds := public.domain_stats('history');
  perform tst.ok(ds ? 'cote' and (ds ->> 'placement')::int = 1, 'domain_stats : cote');
  perform tst.ok((select bool_and(s ? 'cote' and s ? 'placed') from jsonb_array_elements(ds -> 'subdomains') s), 'domain_stats : thèmes');

  -- Entraînement libre : pas de variation de cote, mais des points.
  pack := public.play_pack('training', 'history', null, 5, false, 'beginner');
  atts := '[]'::jsonb;
  for x in select * from jsonb_array_elements(pack -> 'questions') loop
    atts := atts || jsonb_build_object('client_attempt_id', gen_random_uuid(), 'question_id', x ->> 'id',
                                       'given', tst.correct_given((x ->> 'id')::uuid), 'response_ms', 500);
  end loop;
  sub := public.play_submit((pack ->> 'session_id')::uuid, atts);
  perform tst.ok(jsonb_array_length(sub -> 'ratings') = 0 and (sub ->> 'points')::int > 0, 'libre : points sans cote');
  -- Réponse trop rapide : pas de bonus de vitesse.
  perform tst.ok(public._attempt_points(true, 0.5, 500) = 100 and public._attempt_points(true, 0.5, 800) > 100
                 and public._attempt_points(false, 0.1, 2000) = 0, 'bonus de vitesse');
end $$;

-- Simulation : trois joueurs de vrai niveau 30, 50 et 72 (cotes 652, 1000, 1382) jouent 8 parties classées de 10 en géographie.
-- Ils savent avec la probabilité du modèle, et devinent sinon (hasard des QCM et Vrai/Faux). La cote doit retrouver l'ordre et s'approcher du vrai niveau,
-- et le joueur moyen doit réussir environ deux questions sur trois (questions autour de sa cote).
do $$
declare
  thetas real[] := array[30, 50, 72];
  users uuid[] := '{}';
  u uuid; pack jsonb; atts jsonb; x jsonb; b real; c real; ok bool; mu real;
  mus real[] := '{}';
  late_n int := 0; late_ok int := 0;
begin
  perform setseed(0.42);
  perform tst.clock('2026-12-01 10:00:00+01');
  for p in 1 .. 3 loop users := users || tst.new_user(); end loop;
  for g in 1 .. 8 loop
    for p in 1 .. 3 loop
      u := users[p];
      perform tst.login(u);
      pack := public.play_pack('training', 'geography', null, 10, true, null);
      atts := '[]'::jsonb;
      for x in select * from jsonb_array_elements(pack -> 'questions') loop
        -- Joueur réaliste : il sait avec la probabilité du modèle, sinon il devine (1 chance sur n au QCM).
        select difficulty_effective, guess_rate into b, c from public.questions where id = (x ->> 'id')::uuid;
        ok := random() < c + (1 - c) / (1 + exp(-(thetas[p] - b) / 10));
        if p = 2 and g > 4 then late_n := late_n + 1; late_ok := late_ok + ok::int; end if;
        atts := atts || jsonb_build_object('client_attempt_id', gen_random_uuid(), 'question_id', x ->> 'id',
                                           'given', case when ok then tst.correct_given((x ->> 'id')::uuid) else tst.wrong_given() end,
                                           'response_ms', 6000);
      end loop;
      perform public.play_submit((pack ->> 'session_id')::uuid, atts);
    end loop;
    perform tst.tick('1 day');
  end loop;
  for p in 1 .. 3 loop
    select k.mu into mu from public._skill_peek(users[p], 'geography') k;
    mus := mus || mu;
    raise notice 'simulation : vrai niveau % → μ % (cote %)', thetas[p], round(mu::numeric, 1), public._cote(mu);
    perform tst.ok(abs(mu - thetas[p]) < 12, format('convergence du joueur %s (μ = %s)', thetas[p], mu));
  end loop;
  perform tst.ok(mus[1] < mus[2] and mus[2] < mus[3], 'ordre des joueurs');
  raise notice 'simulation : réussite du joueur moyen après placement %/%', late_ok, late_n;
  perform tst.ok(late_ok::real / late_n between 0.52 and 0.78, 'réussite ~65 %');
  perform tst.ok((select bool_and((s ->> 'placed')::bool) from (
                    select (select s from jsonb_array_elements(public.skills_overview()) s where s ->> 'domain_id' = 'geography') s) t),
                 'placement terminé après 8 parties');
end $$;
