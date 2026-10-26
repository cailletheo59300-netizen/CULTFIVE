-- Duels entre amis (0092) : chrono au choix, revanche au même format, suppression d'un défi pas commencé.
do $$
declare a uuid := tst.new_user(); b uuid := tst.new_user(); duel jsonb; did uuid; q jsonb;
begin
  perform tst.clock('2027-09-13 10:00:00+02');
  perform public._befriend(a, b);
  perform tst.login(a);
  perform tst.ok((public.duel_create(b, 10, null, 'auto', 25) ->> 'seconds')::int = 25, 'format libre : 10 questions avec chrono');
  perform tst.ok(public.duel_create(b, 7, null, 'auto', 0) -> 'seconds' = 'null'::jsonb, '7 questions sans chrono');
  perform tst.ok((public.duel_create(b, 7) ->> 'seconds')::int = 25, 'ancienne app : 7 questions = 25 s');
  perform tst.throws(format('select public.duel_create(%L, 5, null, %L, 12)', b, 'auto'), 'invalid_seconds');

  -- Défi lancé puis abandonné tout de suite : supprimable.
  duel := public.duel_create(b, 5, null, 'auto', 25);
  did := (duel ->> 'id')::uuid;
  q := public.duel_question(did, 1);
  perform public.duel_cancel(did);
  perform tst.ok((select status from public.duels where id = did) = 'declined', 'défi supprimé');
  perform tst.ok(not exists (select 1 from jsonb_array_elements(public.duels_mine()) x where (x ->> 'id')::uuid = did), 'disparu de la liste');

  -- Une réponse donnée : il faut finir.
  duel := public.duel_create(b, 5, null, 'auto', 0);
  did := (duel ->> 'id')::uuid;
  q := public.duel_question(did, 1);
  perform public.duel_answer(did, 1, tst.wrong_given(), 2000);
  perform tst.throws(format('select public.duel_cancel(%L)', did), 'duel_not_found');

  -- Revanche au même format (sans chrono).
  for i in 2 .. 5 loop q := public.duel_question(did, i); perform public.duel_answer(did, i, tst.wrong_given(), 2000); end loop;
  perform tst.login(b);
  for i in 1 .. 5 loop q := public.duel_question(did, i); perform public.duel_answer(did, i, tst.wrong_given(), 2000); end loop;
  duel := public.duel_rematch(did);
  perform tst.ok((duel ->> 'total')::int = 5 and duel -> 'seconds' = 'null'::jsonb, 'revanche sans chrono');
  -- B ne peut pas supprimer le défi de A.
  perform tst.login(a);
  perform tst.throws(format('select public.duel_cancel(%L)', (duel ->> 'id')), 'duel_not_found');
end $$;
