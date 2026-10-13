-- Une carte commune en fin de partie classée, jamais deux pour la même partie, jamais en entraînement libre.
do $$
declare
  u uuid := tst.new_user();
  pack jsonb; atts jsonb; sub jsonb; sub2 jsonb; x jsonb;
begin
  perform tst.clock('2027-04-12 10:00:00+02');
  perform tst.login(u);
  pack := public.play_pack('training', 'history', null, 10, true, null);
  atts := '[]'::jsonb;
  for x in select * from jsonb_array_elements(pack -> 'questions') loop
    atts := atts || jsonb_build_object('client_attempt_id', gen_random_uuid(), 'question_id', x ->> 'id',
                                       'given', tst.correct_given((x ->> 'id')::uuid), 'response_ms', 4000);
  end loop;
  sub := public.play_submit((pack ->> 'session_id')::uuid, atts);
  perform tst.ok(sub -> 'album_card' ->> 'outcome' = 'new' and sub -> 'album_card' ->> 'rarity' = 'common', 'carte commune nouvelle');
  perform tst.ok((select count(*) from public.user_cards where user_id = u and slot = 0) = 1, 'une seule carte');
  perform tst.ok(exists (select 1 from public.album_card_concepts k join public.question_attempts qa on qa.concept_id = k.concept_id
                         where k.card_id = sub -> 'album_card' ->> 'card' and qa.session_id = (pack ->> 'session_id')::uuid and qa.is_correct),
                 'carte liée à une notion trouvée pendant la partie');
  sub2 := public.play_submit((pack ->> 'session_id')::uuid, atts);
  perform tst.ok(sub2 -> 'album_card' ->> 'card' = sub -> 'album_card' ->> 'card'
                 and (select count(*) from public.user_cards where user_id = u and slot = 0) = 1, 'fin de partie rejouée : rien de plus');

  -- Entraînement libre (non classé) : pas de carte.
  pack := public.play_pack('training', 'history', null, 5, false, 'beginner');
  atts := '[]'::jsonb;
  for x in select * from jsonb_array_elements(pack -> 'questions') loop
    atts := atts || jsonb_build_object('client_attempt_id', gen_random_uuid(), 'question_id', x ->> 'id',
                                       'given', tst.correct_given((x ->> 'id')::uuid), 'response_ms', 4000);
  end loop;
  sub := public.play_submit((pack ->> 'session_id')::uuid, atts);
  perform tst.ok(sub -> 'album_card' is null or sub -> 'album_card' = 'null'::jsonb, 'entraînement : pas de carte');
end $$;
