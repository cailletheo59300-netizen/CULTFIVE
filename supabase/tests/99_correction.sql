-- « Corrige tes erreurs » : rejouer les questions ratées rembourse l'Elo perdu, sans jamais dépasser le niveau d'avant.
do $$
declare
  u uuid := tst.new_user();
  pack jsonb; atts jsonb := '[]'::jsonb; x jsonb; sid uuid;
  mu0 real; mu1 real; mu2 real; seeds1 int; xp1 int;
  r jsonb; ids jsonb; ans jsonb := '[]'::jsonb; q uuid;
begin
  perform tst.clock('2027-12-01 10:00:00+01');
  perform tst.login(u);

  -- Partie classée : 3 bonnes réponses puis 5 erreurs.
  pack := public.play_pack('training', 'history', null, 8, true, null);
  sid := (pack ->> 'session_id')::uuid;
  for x in select e from jsonb_array_elements(pack -> 'questions') with ordinality t(e, i) loop
    atts := atts || jsonb_build_object('client_attempt_id', gen_random_uuid(), 'question_id', x ->> 'id',
                                       'given', case when jsonb_array_length(atts) < 3 then tst.correct_given((x ->> 'id')::uuid) else tst.wrong_given() end,
                                       'response_ms', 3000);
  end loop;
  perform public.play_submit(sid, atts);
  mu0 := 50;  -- nouveau joueur : départ à 1000
  select mu into mu1 from public.user_skills where user_id = u and scope_id = 'history';
  select seeds, xp_total into seeds1, xp1 from public.profiles where id = u;

  -- Sans pub vérifiée : refusé ; le gratuit n'existe plus.
  perform tst.throws(format('select public.play_correction_start(%L)', sid), 'ad_pending');
  perform tst.throws(format('select public.play_correction_start(%L, ''free'')', sid), 'ad_required');
  perform public.ad_ssv_record('tx-corr-1', u::text, 'unit', 'correction:' || sid);
  r := public.ad_claim('correction', sid::text);
  ids := r -> 'question_ids';
  perform tst.ok(jsonb_array_length(ids) = 5, 'les 5 questions ratées sont proposées');

  -- On corrige 4 questions sur 5.
  for q in select (v #>> '{}')::uuid from jsonb_array_elements(ids) v limit 4 loop
    ans := ans || jsonb_build_object('question_id', q, 'given', tst.correct_given(q));
  end loop;
  ans := ans || jsonb_build_object('question_id', (ids ->> 4)::uuid, 'given', tst.wrong_given());
  r := public.play_correction_submit(sid, ans);
  perform tst.ok((r ->> 'corrected')::int = 4 and (r ->> 'total')::int = 5, '4 corrigées sur 5');
  select mu into mu2 from public.user_skills where user_id = u and scope_id = 'history';
  perform tst.ok(mu2 > mu1, 'Elo en partie récupéré (' || mu1 || ' → ' || mu2 || ')');
  perform tst.ok(mu2 <= mu0 + 0.001, 'jamais au-dessus du niveau d''avant la partie');
  perform tst.ok((r -> 'refunds' -> 0 ->> 'cote_refund')::int > 0, 'remboursement affiché en points d''Elo');
  perform tst.ok((select seeds from public.profiles where id = u) = seeds1 and (select xp_total from public.profiles where id = u) = xp1,
                 'ni graines ni XP');
  perform tst.ok((select count(*) from public.question_attempts where session_id = sid) = 8, 'statistiques inchangées');

  -- Une seule fois.
  r := public.play_correction_submit(sid, ans);
  perform tst.ok((r ->> 'duplicate')::bool, 'deuxième envoi ignoré');
  perform tst.throws(format('select public.play_correction_start(%L)', sid), 'correction_done');

  -- Plafond : une partie sans erreur ne se corrige pas ; une partie plus ancienne non plus.
  pack := public.play_pack('training', 'history', null, 3, true, null);
  perform tst.throws(format('select public.play_correction_start(%L)', sid), 'correction_done');
  perform tst.throws(format('select public.play_correction_start(%L)', pack ->> 'session_id'), 'nothing_to_correct');

  perform tst.throws(format('select public.ad_can(''correction'', %L)', pack ->> 'session_id'), 'nothing_to_correct');
end $$;

-- Délai : seulement dans l'heure, et pas de limite par jour (une pub par partie).
do $$
declare
  u uuid := tst.new_user();
  pack jsonb; x jsonb; atts jsonb;
begin
  perform tst.clock('2027-12-02 10:00:00+01');
  perform tst.login(u);
  for i in 1 .. 4 loop
    pack := public.play_pack('training', 'geography', null, 3, false, 'beginner');
    atts := '[]'::jsonb;
    for x in select * from jsonb_array_elements(pack -> 'questions') loop
      atts := atts || jsonb_build_object('client_attempt_id', gen_random_uuid(), 'question_id', x ->> 'id', 'given', tst.wrong_given(), 'response_ms', 3000);
    end loop;
    perform public.play_submit((pack ->> 'session_id')::uuid, atts);
    perform public.ad_ssv_record('tx-lim-' || i, u::text, 'unit', 'correction:' || (pack ->> 'session_id'));
    perform public.play_correction_start((pack ->> 'session_id')::uuid, 'ad');
  end loop;
  perform tst.ok(true, '4 corrections le même jour');
  pack := public.play_pack('training', 'geography', null, 3, false, 'beginner');
  atts := '[]'::jsonb;
  for x in select * from jsonb_array_elements(pack -> 'questions') loop
    atts := atts || jsonb_build_object('client_attempt_id', gen_random_uuid(), 'question_id', x ->> 'id', 'given', tst.wrong_given(), 'response_ms', 3000);
  end loop;
  perform public.play_submit((pack ->> 'session_id')::uuid, atts);
  perform tst.tick('2 hours');
  perform tst.throws(format('select public.ad_can(''correction'', %L)', pack ->> 'session_id'), 'correction_expired');
end $$;
