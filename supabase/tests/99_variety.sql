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
