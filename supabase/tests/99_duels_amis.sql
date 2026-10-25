-- Duels entre amis (0090) : format 7 questions à 25 s, chrono, revanche, historique, pas de points d'Arène.
do $$
declare
  a uuid := tst.new_user(); b uuid := tst.new_user();
  duel jsonb; did uuid; q jsonb; v jsonb; res jsonb; h jsonb;
begin
  perform tst.clock('2027-08-02 10:00:00+02');
  perform public._befriend(a, b);
  perform tst.login(a);

  duel := public.duel_create(b, 7);
  did := (duel ->> 'id')::uuid;
  perform tst.ok((duel ->> 'total')::int = 7 and (duel ->> 'seconds')::int = 25, '7 questions, 25 s');
  perform tst.ok((duel -> 'opponent' ? 'avatar'), 'avatar de l''adversaire');

  -- A : la 2e question arrive trop tard (25 s + 3 s) : fausse, même juste.
  for i in 1 .. 7 loop
    q := public.duel_question(did, i);
    perform tst.ok((q ->> 'seconds')::int = 25, 'chrono annoncé');
    if i = 2 then perform tst.tick('29 seconds'); end if;
    v := public.duel_answer(did, i, tst.correct_given((q ->> 'id')::uuid), 3000);
    if i = 2 then perform tst.ok(not (v ->> 'is_correct')::bool and (v ->> 'late')::bool, 'trop tard : faux'); end if;
    if i = 1 then perform tst.ok((v ->> 'is_correct')::bool and not (v ->> 'late')::bool, 'à temps : juste'); end if;
  end loop;
  res := public.duel_result(did);
  perform tst.ok((res -> 'me' ->> 'score')::int = 6 and res -> 'opponent' -> 'score' = 'null'::jsonb, 'A : 6/7, score de B caché');

  -- B gagne 7–6 : A reçoit « Revanche ? ».
  perform tst.login(b);
  for i in 1 .. 7 loop
    q := public.duel_question(did, i);
    perform public.duel_answer(did, i, tst.correct_given((q ->> 'id')::uuid), 2000);
  end loop;
  res := public.duel_result(did);
  perform tst.ok(res ->> 'winner' = 'me' and res ->> 'finished_at' is not null, 'B gagne');
  perform tst.ok(not exists (select 1 from public.push_tokens where user_id = a)
                 or exists (select 1 from public.push_outbox where user_id = a and body like '%Revanche ?'), 'défaite : Revanche ?');
  perform tst.ok(not exists (select 1 from public.arena_results where duel_id = did), 'pas de points de la semaine');

  -- Revanche : même format.
  perform tst.login(a);
  duel := public.duel_rematch(did);
  perform tst.ok((duel ->> 'total')::int = 7 and (duel ->> 'seconds')::int = 25, 'revanche en 7 × 25 s');

  -- Ancien format : pas de chrono.
  duel := public.duel_create(b, 10);
  perform tst.ok(duel -> 'seconds' = 'null'::jsonb, '10 questions : sans chrono');

  -- Historique.
  h := public.duels_history();
  perform tst.ok(jsonb_array_length(h -> 'duels') = 1 and h -> 'duels' -> 0 ->> 'winner' = 'opponent', 'historique : 1 duel perdu');
  perform tst.ok((h -> 'summary' ->> 'played')::int = 1 and (h -> 'summary' ->> 'losses')::int = 1
                 and (h -> 'summary' -> 'rivals' -> 0 ->> 'id')::uuid = b, 'bilan et rival');
  perform tst.ok(h -> 'next' = 'null'::jsonb, 'une seule page');
  perform tst.ok(public.duels_history(public._now() - interval '1 day') -> 'duels' = '[]'::jsonb
                 and public.duels_history(public._now() - interval '1 day') -> 'summary' = 'null'::jsonb, 'page suivante vide');
end $$;
