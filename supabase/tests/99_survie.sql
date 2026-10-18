-- Mode Survie (0069) : une question à la fois, jusqu'à la première erreur ; record, neurones, chrono.
do $$
declare
  u uuid := tst.new_user();
  s jsonb; q jsonb; a jsonb; r jsonb; v_run uuid; v_qid uuid; v_seeds int; v_doms text[] := '{}';
begin
  perform tst.clock('2027-03-10 10:00:00+01');
  perform tst.login(u);
  s := public.survival_start();
  v_run := (s ->> 'run_id')::uuid;
  perform tst.ok((s ->> 'record')::int = 0 and (s ->> 'seconds')::int = 20, 'départ : record 0, 20 s');
  perform tst.throws(format('select public.survival_question(%L, 2)', v_run), 'survival_out_of_order');

  -- 5 bonnes réponses, la question servie ne contient pas la réponse.
  for i in 1 .. 5 loop
    q := public.survival_question(v_run, i);
    perform tst.ok(not (q ? 'answer') and (q ->> 'position')::int = i, 'question ' || i || ' sans réponse');
    v_qid := (q ->> 'id')::uuid;
    v_doms := v_doms || (q ->> 'domain_id');
    perform tst.ok((public.survival_question(v_run, i) ->> 'id')::uuid = v_qid, 'renvoi : même question');
    a := public.survival_answer(v_run, i, tst.correct_given(v_qid), 4000);
    perform tst.ok((a ->> 'is_correct')::bool and not (a ->> 'finished')::bool and a ? 'answer', 'bonne réponse ' || i);
    perform tst.ok((public.survival_answer(v_run, i, tst.correct_given(v_qid), 4000) ->> 'duplicate')::bool, 'renvoi : même verdict');
  end loop;
  perform tst.ok(v_doms[1] <> v_doms[2] or v_doms[2] <> v_doms[3], 'domaines variés');

  -- Erreur : fin, 5 × 3 + 20 (record) = 35 neurones.
  select seeds into v_seeds from public.profiles where id = u;
  q := public.survival_question(v_run, 6);
  a := public.survival_answer(v_run, 6, tst.wrong_given(), 4000);
  perform tst.ok(not (a ->> 'is_correct')::bool and (a ->> 'finished')::bool, 'erreur : partie finie');
  r := public.survival_result(v_run);
  perform tst.ok((r ->> 'score')::int = 5 and (r ->> 'new_record')::bool and (r ->> 'reward')::int = 35, 'bilan : 5, record, 35 neurones');
  perform tst.ok((select seeds from public.profiles where id = u) = v_seeds + 35, 'neurones versés');
  perform tst.ok((public.survival_question(v_run, 7) ->> 'expired')::bool, 'partie finie : plus de question');
  perform tst.ok(not exists (select 1 from public.user_skills where user_id = u), 'hors Elo');

  -- Trop tard : faux, même avec la bonne réponse. Record inchangé (0 < 5), pas de bonus.
  v_run := (public.survival_start() ->> 'run_id')::uuid;
  q := public.survival_question(v_run, 1);
  perform tst.tick('30 seconds');
  a := public.survival_answer(v_run, 1, tst.correct_given((q ->> 'id')::uuid), 4000);
  perform tst.ok(not (a ->> 'is_correct')::bool and (a ->> 'late')::bool, 'temps écoulé : faux');
  r := public.survival_result(v_run);
  perform tst.ok((r ->> 'record')::int = 5 and not (r ->> 'new_record')::bool and (r ->> 'reward')::int = 0, 'record gardé');
  perform tst.ok((public.survival_overview() ->> 'record')::int = 5, 'aperçu : record 5');

  -- Partie abandonnée : close au départ suivant.
  v_run := (public.survival_start() ->> 'run_id')::uuid;
  perform public.survival_question(v_run, 1);
  perform public.survival_start();
  perform tst.ok((select ended_at is not null from public.survival_runs where id = v_run), 'abandon : partie close');

  -- Autre joueur : pas d'accès.
  perform tst.login(tst.new_user());
  perform tst.throws(format('select public.survival_result(%L)', v_run), 'survival_not_found');
end $$;
