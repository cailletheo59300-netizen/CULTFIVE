-- Variété : familles automatiques, une famille par partie, et pas les familles de la partie précédente.
do $$
declare
  u uuid := tst.new_user();
  pack jsonb; pack2 jsonb; atts jsonb; x jsonb; v_overlap int;
begin
  perform tst.clock('2027-04-12 10:00:00+02');
  perform tst.login(u);
  perform tst.ok((select count(*) from public.questions where family like 'auto_%') > 500, 'familles automatiques posées');
  perform tst.ok((select count(*) from public.questions where family = 'auto_logic_quel_nombre_suit_n') > 50, '« Quel nombre suit… » regroupées');
  pack := public.play_pack('training', 'logic', null, 10, true, null);
  perform tst.ok((select count(*) - count(distinct q.family) from jsonb_array_elements(pack -> 'questions') e
                  join public.questions q on q.id = (e ->> 'id')::uuid where q.family is not null) = 0, 'une famille par partie');
  atts := '[]'::jsonb;
  for x in select * from jsonb_array_elements(pack -> 'questions') loop
    atts := atts || jsonb_build_object('client_attempt_id', gen_random_uuid(), 'question_id', x ->> 'id',
                                       'given', tst.correct_given((x ->> 'id')::uuid), 'response_ms', 4000);
  end loop;
  perform public.play_submit((pack ->> 'session_id')::uuid, atts);
  pack2 := public.play_pack('training', 'logic', null, 10, true, null);
  select count(*) into v_overlap
  from jsonb_array_elements(pack2 -> 'questions') e join public.questions q on q.id = (e ->> 'id')::uuid
  where q.family is not null and q.family in (select q1.family from jsonb_array_elements(pack -> 'questions') e1
                                              join public.questions q1 on q1.id = (e1 ->> 'id')::uuid);
  perform tst.ok(v_overlap <= 1, format('partie suivante : familles différentes (%s en commun)', v_overlap));
end $$;

-- Capitales revues pays par pays : Rome facile, Minsk et Bichkek difficiles ; une question déjà en base est mise à jour.
do $$
declare v_q uuid; v_rome real; v_minsk real; v_bichkek real;
begin
  select difficulty_initial into v_rome from public.questions where prompt = 'De quel pays Rome est-elle la capitale ?';
  select difficulty_initial into v_minsk from public.questions where prompt = 'De quel pays Minsk est-elle la capitale ?';
  select difficulty_initial into v_bichkek from public.questions where prompt = 'De quel pays Bichkek est-elle la capitale ?';
  perform tst.ok(v_rome < 25 and v_minsk > 50 and v_bichkek > v_minsk, format('capitales : Rome %s, Minsk %s, Bichkek %s', v_rome, v_minsk, v_bichkek));
  select id into v_q from public.questions where prompt = 'De quel pays Minsk est-elle la capitale ?';
  update public.questions set difficulty_initial = 27, difficulty_observed = 27, difficulty_min = 17, difficulty_max = 37 where id = v_q;
  perform public._upsert_question(jsonb_build_object('external_key', external_key, 'concept_id', concept_id, 'type', type, 'prompt', prompt,
            'difficulty', v_minsk, 'reset_difficulty', true), 'import', null) from public.questions where id = v_q;
  perform tst.ok((select difficulty_initial from public.questions where id = v_q) = v_minsk, 'question déjà en base mise à jour');
end $$;
