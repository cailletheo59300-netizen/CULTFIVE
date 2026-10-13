-- Album : référentiel, pochettes (chances, au moins une rare, garantie à la 40e, dorée), doublons, fabrication,
-- jeton Prestige, états masqués, habillage, maîtrise au quiz, mode admin, idempotence et sécurité.
do $$
declare
  u uuid := tst.new_user();
  o jsonb; r jsonb; p jsonb;
  seeds0 int; v_card text; v_legend text; v_common text; v_concepts int;
  n_rare int := 0; n_legend int := 0; n_total int := 0;
  v_id uuid;
  i int;
begin
  perform tst.clock('2027-04-12 10:00:00+02');
  perform tst.login(u);

  -- Référentiel chargé par le seed : 49 pages, 525 cartes, toutes reliées à des notions.
  perform tst.ok((select count(*) from public.album_pages) = 49, '49 pages');
  perform tst.ok((select count(*) from public.album_cards) = 525, '525 cartes');
  perform tst.ok(not exists (select 1 from public.album_cards c
                             where not exists (select 1 from public.album_card_concepts k where k.card_id = c.id)),
                 'chaque carte a au moins une notion');

  -- Première visite : album vide, 3 pochettes de bienvenue, dos et couverture de départ.
  o := public.album_overview();
  perform tst.ok(jsonb_array_length(o -> 'cards') = 0, 'album vide au départ');
  perform tst.ok((o ->> 'tickets')::int = 3, '3 pochettes de bienvenue');
  perform tst.ok(o -> 'cosmetics' ? 'dos.classique' and o -> 'cosmetics' ? 'couv.classique', 'habillage de départ');
  perform tst.ok(not (o ->> 'can_admin')::bool and not (o ->> 'admin')::bool, 'pas admin');

  -- Ticket : 5 cartes, au moins une rare, triées de la plus commune à la plus rare.
  r := public.album_open_pack('history', 'ticket');
  perform tst.ok(jsonb_array_length(r -> 'pulls') = 5, '5 cartes');
  perform tst.ok(exists (select 1 from jsonb_array_elements(r -> 'pulls') x where x ->> 'rarity' <> 'common'), 'au moins une rare');
  perform tst.ok((select bool_and(c.page_key like 'history.%') from jsonb_array_elements(r -> 'pulls') x
                  join public.album_cards c on c.id = x ->> 'card'), 'série Histoire : seulement des cartes d''Histoire');
  perform tst.ok((select count(distinct x ->> 'card') from jsonb_array_elements(r -> 'pulls') x) = 5, 'jamais deux fois la même');
  perform tst.ok((public.album_overview() ->> 'tickets')::int = 2, 'ticket utilisé');
  -- Même demande renvoyée : rien de plus.
  v_id := gen_random_uuid();
  p := public.album_open_pack('encyclo', 'ticket', v_id);
  perform tst.ok(public.album_open_pack('encyclo', 'ticket', v_id) = p, 'demande rejouée : même résultat');
  perform tst.ok((public.album_overview() ->> 'tickets')::int = 1, 'un seul ticket pour une demande rejouée');

  -- Neurones : 150 par pochette, refus sans assez.
  perform tst.throws('select public.album_open_pack(''encyclo'', ''neurones'')', 'insufficient_seeds');
  perform public._grant(u, 'seeds', 100000, 'test', null, 'test:album');
  select seeds into seeds0 from public.profiles where id = u;
  perform public.album_open_pack('encyclo', 'neurones');
  perform tst.ok((select seeds from public.profiles where id = u) <= seeds0 - 150 + 500, 'pochette payée 150 (doublons en plus possibles)');
  perform tst.ok(exists (select 1 from public.ledger where user_id = u and reason = 'album_pack' and amount = -150), 'débit de 150');
  perform tst.throws('select public.album_open_pack(''nimportequoi'', ''neurones'')', 'invalid_series');
  perform tst.throws('select public.album_open_pack(''encyclo'', ''gratuit'')', 'invalid_payment');

  -- Garantie : la 40e pochette sans légendaire en donne une.
  update public.user_album set packs_since_legend = 39 where user_id = u;
  r := public.album_open_pack('encyclo', 'neurones');
  perform tst.ok(exists (select 1 from jsonb_array_elements(r -> 'pulls') x where x ->> 'rarity' = 'legend'), 'légendaire garantie à la 40e');
  perform tst.ok((select packs_since_legend from public.user_album where user_id = u) = 0, 'compteur remis à zéro');

  -- Pochette dorée : 900, une légendaire, une par semaine.
  r := public.album_open_pack('encyclo', 'gold');
  perform tst.ok(exists (select 1 from jsonb_array_elements(r -> 'pulls') x where x ->> 'rarity' = 'legend'), 'dorée : une légendaire');
  perform tst.ok(not (public.album_overview() ->> 'gold_available')::bool, 'dorée achetée cette semaine');
  perform tst.throws('select public.album_open_pack(''encyclo'', ''gold'')', 'gold_weekly_limit');
  perform tst.throws('select public.album_open_pack(''history'', ''gold'')', 'invalid_series');
  perform tst.tick('7 days');
  perform tst.ok((public.album_overview() ->> 'gold_available')::bool, 'de retour la semaine suivante');
  perform tst.throws('select public.album_open_pack(''encyclo'', ''gold_pass'')', 'no_gold_pack');

  -- Chances sur beaucoup de pochettes (seuils larges) : environ 22 % de rares, 1,5 % de légendaires.
  for i in 1..300 loop
    r := public.album_open_pack('encyclo', 'neurones');
    select n_total + 5, n_rare + count(*) filter (where x ->> 'rarity' = 'rare'), n_legend + count(*) filter (where x ->> 'rarity' = 'legend')
    into n_total, n_rare, n_legend from jsonb_array_elements(r -> 'pulls') x;
  end loop;
  perform tst.ok(n_rare::float / n_total between 0.18 and 0.32, format('part de rares plausible (%s / %s)', n_rare, n_total));
  perform tst.ok(n_legend::float / n_total between 0.003 and 0.05, format('part de légendaires plausible (%s / %s)', n_legend, n_total));

  -- Doublons : brillante d'abord, puis neurones (5 / 15 / 40 / 100).
  select id into v_common from public.album_cards where rarity = 'common' order by id limit 1;
  delete from public.user_cards where user_id = u and card_id = v_common;
  perform tst.ok(public._album_receive(u, 0::smallint, v_common, 'k1') ->> 'outcome' = 'new', 'nouvelle');
  perform tst.ok(public._album_receive(u, 0::smallint, v_common, 'k2') ->> 'outcome' = 'shiny', 'premier doublon : brillante');
  r := public._album_receive(u, 0::smallint, v_common, 'k3');
  perform tst.ok(r ->> 'outcome' = 'neurones' and (r ->> 'neurones')::int = 5, 'ensuite : 5 neurones pour une commune');
  perform tst.ok((select copies from public.user_cards where user_id = u and card_id = v_common) = 3, '3 exemplaires');

  -- Fabrication : 50 / 150 / 400 / 1 200, jamais une carte déjà possédée.
  select id into v_legend from public.album_cards c where rarity = 'legend'
    and not exists (select 1 from public.user_cards uc where uc.user_id = u and uc.card_id = c.id) order by id limit 1;
  select seeds into seeds0 from public.profiles where id = u;
  r := public.album_craft(v_legend);
  perform tst.ok((r ->> 'cost')::int = 1200 and (select seeds from public.profiles where id = u) = seeds0 - 1200, 'légendaire fabriquée pour 1 200');
  perform tst.throws(format('select public.album_craft(%L)', v_legend), 'card_owned');
  perform tst.throws('select public.album_craft(''pas.une_carte'')', 'invalid_card');

  -- Jeton Prestige : il en faut un, définitif.
  perform tst.throws(format('select public.album_prestige(%L)', v_legend), 'no_token');
  update public.user_album set tokens = 1 where user_id = u;
  perform public.album_prestige(v_legend);
  perform tst.ok((select prestige from public.user_cards where user_id = u and card_id = v_legend), 'Prestige posé');
  perform tst.ok((select tokens from public.user_album where user_id = u) = 0, 'jeton utilisé');
  perform tst.throws(format('select public.album_prestige(%L)', v_legend), 'already_prestige');

  -- États masqués : gardés, juste pas affichés.
  perform public.album_set_hidden(v_legend, 'prestige', true);
  o := public.album_overview();
  perform tst.ok((select (c ->> 'prestige')::bool and c -> 'hidden' ? 'prestige' from jsonb_array_elements(o -> 'cards') c
                  where c ->> 'id' = v_legend), 'Prestige masqué mais gardé');
  perform public.album_set_hidden(v_legend, 'prestige', false);
  perform tst.ok(not exists (select 1 from public.user_cards where user_id = u and card_id = v_legend and 'prestige' = any(hidden)), 'réaffiché');
  perform tst.throws(format('select public.album_set_hidden(%L, ''volant'', true)', v_legend), 'invalid_state');

  -- Habillage : seulement ce qu'on possède.
  perform tst.throws(format('select public.album_dress(%L, ''vitrail'', null, null)', v_legend), 'item_not_owned');
  insert into public.user_cosmetics (user_id, item_id, source) values (u, 'cadre.vitrail', 'test');
  perform public.album_dress(v_legend, 'vitrail', null, null);
  perform tst.ok((select frame from public.user_cards where user_id = u and card_id = v_legend) = 'vitrail', 'cadre posé');
  perform tst.throws('select public.album_set_look(''or'', null)', 'item_not_owned');
  perform tst.ok(public.album_set_look('classique', null) ->> 'back' = 'classique', 'dos possédé');

  -- Maîtrise : étoiles d'après les notions réussies, Chef-d'œuvre à 3 étoiles, et elles pâlissent après 60 jours.
  select count(*) into v_concepts from public.album_card_concepts where card_id = v_legend;
  insert into public.question_attempts (user_id, question_id, concept_id, context, is_correct, question_difficulty, user_skill_before,
                                        expected, seen_count, created_at)
  select u, q.id, q.concept_id, 'quick_play', true, 0, 0, 0.5, 1, public._now()
  from public.album_card_concepts k
  join lateral (select id, concept_id from public.questions where concept_id = k.concept_id limit 1) q on true
  where k.card_id = v_legend
  limit 1;
  o := public.album_overview();
  perform tst.ok((select (c ->> 'stars')::int from jsonb_array_elements(o -> 'cards') c where c ->> 'id' = v_legend) = case when v_concepts = 1 then 3 when v_concepts = 2 then 2 else 1 end,
                 'une notion réussie : première étoile');
  insert into public.question_attempts (user_id, question_id, concept_id, context, is_correct, question_difficulty, user_skill_before,
                                        expected, seen_count, created_at)
  select u, q.id, q.concept_id, 'quick_play', true, 0, 0, 0.5, 1, public._now()
  from public.album_card_concepts k
  join lateral (select id, concept_id from public.questions where concept_id = k.concept_id limit 1) q on true
  where k.card_id = v_legend;
  o := public.album_overview();
  perform tst.ok((select (c ->> 'stars')::int = 3 and (c ->> 'masterpiece')::bool from jsonb_array_elements(o -> 'cards') c
                  where c ->> 'id' = v_legend), 'toutes les notions : 3 étoiles et Chef-d''œuvre');
  perform tst.tick('61 days');
  o := public.album_overview();
  perform tst.ok((select (c ->> 'stars')::int = 0 and not (c ->> 'masterpiece')::bool from jsonb_array_elements(o -> 'cards') c
                  where c ->> 'id' = v_legend), 'sans révision depuis 60 jours : les étoiles pâlissent');

  -- Mode admin : réservé aux administrateurs.
  perform tst.throws('select public.album_admin(true)', 'forbidden');
  perform tst.throws('select public.album_admin_tool(''own_all'')', 'forbidden');
  insert into public.app_admins (user_id) values (u);
  select seeds into seeds0 from public.profiles where id = u;
  o := public.album_admin(true);
  perform tst.ok((o ->> 'admin')::bool and (o ->> 'neurones')::int = 999999 and (o ->> 'tickets')::int = 999999, 'admin : tout illimité');
  perform tst.ok(jsonb_array_length(o -> 'cards') = 0, 'admin : collection à part');
  o := public.album_admin_tool('own_all_shiny');
  perform tst.ok(jsonb_array_length(o -> 'cards') = 525, 'admin : toutes les cartes');
  perform public.album_admin_tool('force', 'legend');
  r := public.album_open_pack('sport', 'ticket');
  perform tst.ok(exists (select 1 from jsonb_array_elements(r -> 'pulls') x where x ->> 'rarity' = 'legend'), 'rareté imposée');
  perform public.album_admin_state(v_legend, 'masterpiece', true);
  perform public.album_admin_state(v_legend, 'prestige', true);
  perform tst.ok((select forced_masterpiece and prestige from public.user_cards where user_id = u and slot = 1 and card_id = v_legend),
                 'admin : états posés librement');
  perform public.album_open_pack('encyclo', 'gold');
  perform public.album_admin_tool('empty');
  perform public.album_craft(v_common);
  perform tst.ok((select seeds from public.profiles where id = u) = seeds0, 'admin : le vrai solde ne bouge jamais');
  o := public.album_admin(false);
  perform tst.ok(not (o ->> 'admin')::bool and jsonb_array_length(o -> 'cards') = (select count(*) from public.user_cards where user_id = u and slot = 0),
                 'admin quitté : on retrouve sa collection');
  perform tst.ok((select not forced_masterpiece is true from public.user_cards where user_id = u and slot = 0 and card_id = v_legend),
                 'le jeu normal n''est pas touché par l''admin');
  perform tst.throws(format('select public.album_admin_state(%L, ''shiny'', true)', v_legend), 'forbidden');

  -- Sécurité.
  perform tst.ok(not has_function_privilege('authenticated', 'public._album_draw(uuid, public.user_album, text, bool, uuid)', 'execute'), 'tirage : interne');
  perform tst.ok(not has_function_privilege('authenticated', 'public._album_receive(uuid, smallint, text, text)', 'execute'), 'réception : interne');
  perform tst.ok(has_function_privilege('authenticated', 'public.album_open_pack(text, text, uuid)', 'execute'), 'pochette ouverte aux connectés');
  perform tst.ok(not has_function_privilege('anon', 'public.album_open_pack(text, text, uuid)', 'execute'), 'fermée aux anonymes');
  perform tst.ok(not has_table_privilege('authenticated', 'public.user_cards', 'select'), 'collection : pas d''accès direct');
end $$;
