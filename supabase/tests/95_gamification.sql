-- Coffres, arbre de Léon, objets, tickets d'aide, niveaux, trophées de maîtrise, fin de partie.
do $$
declare
  u uuid := tst.new_user();
  c uuid; r jsonb; r2 jsonb; o jsonb; seeds0 int; pack jsonb; x jsonb; atts jsonb; v_q uuid;
begin
  perform tst.clock('2027-06-02 10:00:00+02');
  perform tst.login(u);

  -- Niveaux : un coffre par niveau gagné (bois ; argent au 5 ; or au 10), jamais deux fois.
  perform public._grant(u, 'xp', 1000, 'test', null, 'test:xp1');          -- niveau 5
  perform tst.ok((select count(*) from public.user_chests where user_id = u and source = 'level') = 4, 'niveaux 2 à 5 : 4 coffres');
  perform tst.ok((select tier from public.user_chests where user_id = u and idempotency_key = 'level:5') = 'silver', 'niveau 5 : argent');
  perform public._grant(u, 'xp', 3500, 'test', null, 'test:xp2');          -- 4 500 XP : niveau 10
  perform tst.ok((select tier from public.user_chests where user_id = u and idempotency_key = 'level:10') = 'gold', 'niveau 10 : or');
  perform tst.ok((select count(*) from public.user_chests where user_id = u and source = 'level') = 9, 'un coffre par niveau');
  perform tst.ok((select level_rewarded from public.profiles where id = u) = 10, 'niveaux récompensés mémorisés');
  perform tst.ok((public.progression_overview() ->> 'level')::int = 10, 'niveau calculé (même formule que l''app)');

  -- Coffre d'or : graines 60–80, joker garanti, objet garanti ; une seule ouverture.
  select id into c from public.user_chests where user_id = u and idempotency_key = 'level:10';
  select seeds into seeds0 from public.profiles where id = u;
  r := public.chest_open(c);
  -- (1 fois sur 20, la Recharge le fait passer Savant : 120 à 160 graines.)
  perform tst.ok((r ->> 'seeds')::int between 60 and 80 or (r ->> 'final_tier' = 'savant' and (r ->> 'seeds')::int between 120 and 160),
                 'or : 60 à 80 graines (' || (r ->> 'seeds') || ')');
  perform tst.ok((r ->> 'joker')::bool and (select streak_freezes from public.profiles where id = u) = 1, 'or : joker garanti');
  perform tst.ok(r -> 'item' ->> 'id' is not null
                 and exists (select 1 from public.items where id = r -> 'item' ->> 'id' and rarity = 'chest'), 'or : un objet des coffres');
  perform tst.ok((select seeds from public.profiles where id = u) = seeds0 + (r ->> 'seeds')::int, 'graines versées');
  r2 := public.chest_open(c);
  perform tst.ok((r2 ->> 'already_opened')::bool and r2 ->> 'seeds' = r ->> 'seeds', 'deuxième ouverture : même contenu, rien de plus');
  perform tst.ok((select seeds from public.profiles where id = u) = seeds0 + (r ->> 'seeds')::int, 'pas de double versement');

  -- Coffre de bois : 10–20 graines (+10 si un joker tombe mais qu'on en a déjà 2), 1 ticket.
  select id into c from public.user_chests where user_id = u and idempotency_key = 'level:2';
  r := public.chest_open(c);
  -- (La Recharge peut faire monter le coffre : on ne vérifie le contenu « bois » que s'il est resté en bois.)
  if r ->> 'final_tier' = 'wood' then
    perform tst.ok((r ->> 'seeds')::int between 10 and 30, 'bois : graines');
    perform tst.ok((r -> 'tickets' ->> 'fifty_fifty')::int + (r -> 'tickets' ->> 'hint')::int = 1, 'bois : 1 ticket');
    perform tst.ok(r -> 'item' = 'null'::jsonb or r -> 'item' is null, 'bois : pas d''objet');
  else
    perform tst.ok((r ->> 'seeds')::int >= 30, 'coffre monté : plus de graines');
  end if;

  -- Jokers plafonnés à 2 : un joker en trop devient des graines.
  update public.profiles set streak_freezes = 2 where id = u;
  select id into c from public.user_chests where user_id = u and idempotency_key = 'level:5';
  r := public.chest_open(c);
  perform tst.ok(not (r ->> 'joker')::bool and (select streak_freezes from public.profiles where id = u) = 2, 'jamais plus de 2 jokers');
  if r ->> 'final_tier' = 'silver' then
    perform tst.ok((r ->> 'seeds')::int between 30 and 95, 'argent : graines (+ compensations)');
    perform tst.ok((r -> 'tickets' ->> 'fifty_fifty')::int + (r -> 'tickets' ->> 'hint')::int = 2, 'argent : 2 tickets');
  end if;

  -- Tous les objets des coffres possédés : l'objet est remplacé par des graines.
  insert into public.user_items (user_id, item_id) select u, id from public.items where rarity = 'chest' on conflict do nothing;
  perform public._give_chest(u, 'gold', 'test', null, 'test:gold');
  select id into c from public.user_chests where user_id = u and idempotency_key = 'test:gold';
  r := public.chest_open(c);
  perform tst.ok(r -> 'item' = 'null'::jsonb or r -> 'item' is null, 'plus d''objet à gagner');
  if r ->> 'final_tier' = 'gold' then
    perform tst.ok((r ->> 'seeds')::int between 100 and 160, 'objet remplacé par 40 graines');
  end if;

  -- Coffre d'un autre joueur : introuvable.
  perform tst.throws(format('select public.chest_open(%L)', gen_random_uuid()), 'chest_not_found');

  -- Tenue de Léon : seulement ce qu'on possède, un objet par emplacement.
  o := public.leon_equip('hat', 'beret');
  perform tst.ok(o ->> 'hat' = 'beret', 'béret porté');
  o := public.leon_equip('hat', 'party_hat');
  perform tst.ok(o ->> 'hat' = 'party_hat' and (select count(*) from public.user_items ui join public.items i on i.id = ui.item_id
                                                 where ui.user_id = u and ui.equipped and i.slot = 'hat') = 1, 'un seul chapeau');
  o := public.leon_equip('hat', null);
  perform tst.ok(not o ? 'hat', 'chapeau retiré');
  perform tst.throws('select public.leon_equip(''skin'', ''skin_gold'')', 'item_not_owned');
  perform tst.throws('select public.leon_equip(''eyes'', ''beret'')', 'item_not_owned');

  -- Arbre : étapes → coffre d'or, fruits → objets rares, arbre complet à 19 000.
  update public.profiles set tree_points = 0, tree_stage_rewarded = 1, tree_fruits_rewarded = 0 where id = u;
  perform public._grant(u, 'seeds', 30000, 'test', null, 'test:seeds');
  perform tst.throws('select public.tree_feed(0)', 'invalid_amount');
  r := public.tree_feed(149);
  perform tst.ok((r -> 'tree' ->> 'stage')::int = 1 and (r ->> 'new_chests')::int = 0, 'encore une graine');
  r := public.tree_feed(1);
  perform tst.ok((r -> 'tree' ->> 'stage')::int = 2 and (r ->> 'new_chests')::int = 1, 'pousse : un coffre d''or');
  perform tst.ok(r -> 'tree' ->> 'stage_name' = 'Pousse' and (r -> 'tree' ->> 'next_at')::int = 600, 'prochaine étape à 600');
  -- Idempotence : même identifiant client, rien de plus.
  c := gen_random_uuid();
  select seeds into seeds0 from public.profiles where id = u;
  perform public.tree_feed(100, c);
  r := public.tree_feed(100, c);
  perform tst.ok((r ->> 'fed')::int = 0 and (select seeds from public.profiles where id = u) = seeds0 - 100, 'renvoi réseau sans effet');
  -- Saut de plusieurs étapes d'un coup : un coffre par étape.
  r := public.tree_feed(9000 - 250);
  perform tst.ok((r -> 'tree' ->> 'stage')::int = 6 and (r ->> 'new_chests')::int = 4, 'en fleurs : 4 coffres (étapes 3 à 6)');
  perform tst.ok((r -> 'tree' ->> 'next_at')::int = 11500 and (r -> 'tree' ->> 'fruits')::int = 0, 'premier fruit à 11 500');
  r := public.tree_feed(2500);
  perform tst.ok(r -> 'new_items' -> 0 ->> 'id' = 'leaf_crown', 'premier fruit : couronne de feuilles');
  r := public.tree_feed(10000);
  perform tst.ok((r ->> 'fed')::int = 7500 and (r -> 'tree' ->> 'complete')::bool, 'arbre complet, le surplus reste en poche');
  perform tst.ok(jsonb_array_length(r -> 'new_items') = 3 and r -> 'new_items' -> 2 ->> 'id' = 'skin_gold', 'trois derniers fruits');
  perform tst.ok((select count(*) from public.user_chests where user_id = u and source = 'tree') = 5, 'un coffre par étape, jamais pour les fruits');
  perform tst.throws('select public.tree_feed(10)', 'tree_complete');

  -- Graines insuffisantes.
  update public.profiles set tree_points = 0, tree_stage_rewarded = 1, tree_fruits_rewarded = 0 where id = u;
  perform public._grant(u, 'seeds', -(select seeds from public.profiles where id = u), 'test', null, 'test:empty');
  perform tst.throws('select public.tree_feed(10)', 'insufficient_seeds');

  -- Tickets d'aide : utilisés avant les graines, jamais deux fois pour la même aide.
  perform public._grant(u, 'seeds', 100, 'test', null, 'test:seeds2');
  pack := public.play_pack('training', 'geography', null, 10, false, 'beginner');
  select (y ->> 'id')::uuid into v_q from jsonb_array_elements(pack -> 'questions') y
  join public.questions q on q.id = (y ->> 'id')::uuid
  where q.type in ('mcq', 'map_pick') and jsonb_array_length(q.payload -> 'options') >= 3 limit 1;
  update public.user_items set qty = 1 where user_id = u and item_id = 'ticket_fifty_fifty';
  insert into public.user_items (user_id, item_id, qty) values (u, 'ticket_fifty_fifty', 1) on conflict do nothing;
  select seeds into seeds0 from public.profiles where id = u;
  r := public.play_spend_help((pack ->> 'session_id')::uuid, v_q, 'fifty_fifty');
  perform tst.ok((r ->> 'ticket_used')::bool and (r ->> 'tickets_left')::int = 0, 'ticket 50/50 utilisé');
  perform tst.ok((select seeds from public.profiles where id = u) = seeds0, 'pas de graines dépensées');
  r := public.play_spend_help((pack ->> 'session_id')::uuid, v_q, 'fifty_fifty');
  perform tst.ok(not (r ->> 'ticket_used')::bool and (select seeds from public.profiles where id = u) = seeds0, 'même aide redemandée : gratuite');
  -- Sans ticket : graines.
  select (y ->> 'id')::uuid into v_q from jsonb_array_elements(pack -> 'questions') y
  join public.questions q on q.id = (y ->> 'id')::uuid
  where q.type in ('mcq', 'map_pick') and jsonb_array_length(q.payload -> 'options') >= 3 and q.id <> v_q limit 1;
  r := public.play_spend_help((pack ->> 'session_id')::uuid, v_q, 'fifty_fifty');
  perform tst.ok(not (r ->> 'ticket_used')::bool and (select seeds from public.profiles where id = u) = seeds0 - 15, 'sans ticket : 15 graines');

  -- Vue d'ensemble.
  o := public.progression_overview();
  perform tst.ok(jsonb_array_length(o -> 'items') = (select count(*) from public.items where kind = 'cosmetic') and o ? 'tree' and o ? 'chests' and o ? 'tickets', 'progression : tout y est');
  perform tst.ok((select bool_and((i ->> 'owned')::bool) from jsonb_array_elements(o -> 'items') i where i ->> 'rarity' = 'chest'), 'objets possédés');

  -- Sécurité : pas d'accès direct.
  perform tst.ok(not has_function_privilege('authenticated', 'public._give_chest(uuid, public.chest_tier, text, text, text)', 'execute'), '_give_chest protégée');
  perform tst.ok(not has_function_privilege('authenticated', 'public._give_item(uuid, text, int)', 'execute'), '_give_item protégée');
  perform tst.ok(not has_table_privilege('authenticated', 'public.user_chests', 'select'), 'coffres : pas de lecture directe');
  perform tst.ok(not has_table_privilege('authenticated', 'public.user_items', 'update'), 'objets : pas d''écriture directe');
  perform tst.ok(has_function_privilege('authenticated', 'public.chest_open(uuid)', 'execute'), 'chest_open ouverte aux connectés');
  perform tst.ok(not has_function_privilege('anon', 'public.chest_open(uuid)', 'execute'), 'chest_open fermée aux anonymes');
end $$;

-- Coffre d'un autre joueur : refusé.
do $$
declare a uuid := tst.new_user(); b uuid := tst.new_user(); c uuid;
begin
  perform public._give_chest(a, 'wood', 'test', null, 'test:a');
  select id into c from public.user_chests where user_id = a;
  perform tst.login(b);
  perform tst.throws(format('select public.chest_open(%L)', c), 'chest_not_found');
end $$;

-- Trophées : maîtrise d'un domaine (Elo classé, après placement), exploits, noms en fin de partie.
do $$
declare
  u uuid := tst.new_user();
  pack jsonb; atts jsonb; x jsonb; r jsonb; t jsonb;
begin
  perform tst.clock('2027-06-10 10:00:00+02');
  perform tst.login(u);
  -- Placement terminé, Elo ≈ 1 250 en histoire (μ ≈ 64,4).
  insert into public.user_skills (user_id, scope_id, mu, var, n, correct)
  values (u, 'history', 64.4, 20, 60, 40)
  on conflict (user_id, scope_id) do update set mu = excluded.mu, var = excluded.var, n = excluded.n;
  perform tst.ok(public._cote(64.4) between 1200 and 1349, 'Elo de test entre argent et or');

  -- Une partie classée parfaite (10/10) : sans-faute, placé, maîtrise bronze + argent.
  pack := public.play_pack('training', 'history', null, 10, true, null);
  atts := '[]'::jsonb;
  for x in select * from jsonb_array_elements(pack -> 'questions') loop
    atts := atts || jsonb_build_object('client_attempt_id', gen_random_uuid(), 'question_id', x ->> 'id',
                                       'given', tst.correct_given((x ->> 'id')::uuid), 'response_ms', 4000);
  end loop;
  r := public.play_submit((pack ->> 'session_id')::uuid, atts);
  perform tst.ok(r -> 'achievements' ? 'Sans-faute classé', 'fin de partie : nom du trophée, pas son identifiant');
  perform tst.ok(r -> 'achievements' ? 'Placé', 'placé');
  perform tst.ok(exists (select 1 from public.user_achievements where user_id = u and achievement_id = 'mastery_history_bronze')
                 and exists (select 1 from public.user_achievements where user_id = u and achievement_id = 'mastery_history_silver'),
                 'maîtrise bronze et argent');
  perform tst.ok(not exists (select 1 from public.user_achievements where user_id = u and achievement_id = 'mastery_history_gold')
                 or public._cote((select mu from public.user_skills where user_id = u and scope_id = 'history')) >= 1350,
                 'pas d''or sans 1 350');
  perform tst.ok((select tier from public.user_chests where user_id = u and idempotency_key = 'trophy:mastery_history_silver') = 'silver',
                 'maîtrise argent : coffre d''argent');
  perform tst.ok((select tier from public.user_chests where user_id = u and idempotency_key = 'trophy:ranked_perfect') = 'silver',
                 'sans-faute : coffre d''argent');
  perform tst.ok(not exists (select 1 from public.ledger where user_id = u and reason = 'achievement'), 'plus de graines directes pour les trophées');

  -- Vitrine.
  t := public.trophies_overview();
  perform tst.ok(jsonb_array_length(t -> 'exploits') = 13, '13 exploits');
  perform tst.ok(jsonb_array_length(t -> 'mastery') = 12, 'un domaine par ligne');
  perform tst.ok((select m ->> 'tier' from jsonb_array_elements(t -> 'mastery') m where m ->> 'domain_id' = 'history') in ('silver', 'gold'),
                 'histoire : palier atteint');
  perform tst.ok((select (m ->> 'placed')::bool from jsonb_array_elements(t -> 'mastery') m where m ->> 'domain_id' = 'geography') = false,
                 'géographie : pas encore placé');
  perform tst.ok(jsonb_array_length(public.achievements_mine()) = 13, 'profil : exploits seulement');
end $$;

-- Parrainage rééquilibré : paliers en coffres.
do $$
declare inviter uuid := tst.new_user(); v_count int;
begin
  perform tst.login(inviter);
  -- On simule 2 filleuls déjà qualifiés, puis un 3e.
  for i in 1 .. 3 loop
    insert into public.referrals (inviter_id, invitee_id, status, device_hash, created_at)
    values (inviter, tst.new_user(), 'claimed', 'dev-' || i || '-' || inviter, public._now());
  end loop;
  update public.referrals set status = 'qualified', qualified_at = public._now()
  where inviter_id = inviter and device_hash like 'dev-1-%' or (inviter_id = inviter and device_hash like 'dev-2-%');
  insert into public.daily_runs (user_id, daily_date, status, started_at, deadline_at, score, total_ms)
  select invitee_id, '2027-06-10', 'finished', now(), now(), 3, 60000 from public.referrals
  where inviter_id = inviter and status = 'claimed';
  perform public._referral_on_first_daily((select invitee_id from public.referrals where inviter_id = inviter and status = 'claimed'));
  perform tst.ok((select tier from public.user_chests where user_id = inviter and idempotency_key = 'referral_tier:3') = 'silver',
                 '3 filleuls : coffre d''argent');
  perform tst.ok(not exists (select 1 from public.ledger where user_id = inviter and reason = 'referral_tier'), 'palier : plus de graines directes');
end $$;
