-- Pass+ : achat vérifié, piste payante (refus sans Pass+, rattrapage), plus de pub (bonus sans vidéo, mêmes limites),
-- remboursement, coffret de catégorie.
do $$
declare
  u uuid := tst.new_user();
  v uuid := tst.new_user();
  o jsonb; r jsonb; st jsonb; x jsonb; k text;
  v_pts int; v_tickets int; v_tokens int;
  v_coffret uuid; v_domain text; v_cards text[];
begin
  -- Saison 1 aux dates de la production (15 octobre 2026 → 3 janvier 2027).
  update public.seasons set starts_on = '2026-10-15', ends_on = '2027-01-03' where id = 1;
  perform tst.clock('2026-11-25 10:00:00+01');
  perform tst.login(u);
  update public.profiles set created_at = public._now() - interval '10 days' where id = u;

  -- Saison 1 : en vente, piste payante visible mais verrouillée.
  o := public.season_overview();
  perform tst.ok(o -> 'season' ->> 'name' = 'Saison 1', 'saison 1 en cours');
  perform tst.ok((o -> 'pass_plus' ->> 'on_sale')::bool and not (o -> 'pass_plus' ->> 'active')::bool, 'Pass+ en vente, pas actif');
  perform tst.ok(jsonb_array_length(o -> 'rewards') = 30 and jsonb_array_length(o -> 'pass_plus' -> 'rewards') = 30, '30 + 30 paliers');
  perform tst.ok(o -> 'pass_plus' -> 'rewards' -> 0 ->> 'kind' = 'perk', 'palier 1 : plus de pub');
  perform tst.ok((select count(*) from jsonb_array_elements(o -> 'pass_plus' -> 'rewards') e where e ->> 'kind' = 'token') = 3
                 and (select count(*) from jsonb_array_elements(o -> 'pass_plus' -> 'rewards') e where e ->> 'kind' = 'coffret') = 3,
                 '3 jetons et 3 coffrets');
  perform tst.ok(not (public.ad_status() ->> 'pass_plus')::bool and (public.ad_status() ->> 'interstitial')::bool, 'pubs pour un joueur sans Pass+');

  -- Des points : toute la saison de défis du jour.
  insert into public.user_quests (user_id, period, period_start, slot, metric, target, label, xp, seeds, completed_at)
  select u, 'day', d::date, s, 'answers', 1, 'x', 0, 0, public._now()
  from generate_series('2026-10-15'::date, '2026-11-25'::date, interval '1 day') d, generate_series(1, 3) s;
  insert into public.user_quests (user_id, period, period_start, slot, metric, target, label, xp, seeds, completed_at)
  select u, 'week', d::date, s, 'answers', 1, 'y', 0, 0, public._now()
  from generate_series('2026-10-26'::date, '2026-11-23'::date, interval '7 days') d, generate_series(1, 3) s;
  v_pts := (public.season_overview() ->> 'points')::int;
  perform tst.ok(v_pts between 18 * 150 and 24 * 150 - 1, format('entre 18 et 23 paliers (%s points)', v_pts));
  perform tst.throws('select public.season_claim(2, ''paid'')', 'pass_required');
  perform tst.throws('select public.season_claim_all(''paid'')', 'pass_required');
  -- L'ancienne app (un seul argument) récupère toujours la piste gratuite.
  perform public.season_claim(1);
  perform tst.ok(exists (select 1 from public.season_claims where user_id = u and season_id = 1 and track = 'free' and tier = 1),
                 'piste gratuite comme avant');

  -- Achat (clé de service), idempotent.
  r := public.pass_plus_record(u, 'tx-pass-1', 'tx-pass-1', 'app.brainlix.passplus', 'Production', public._now());
  perform tst.ok((r ->> 'season_id')::int = 1 and (r ->> 'recorded')::bool, 'achat enregistré sur la saison 1');
  r := public.pass_plus_record(u, 'tx-pass-1', 'tx-pass-1', 'app.brainlix.passplus', 'Production', public._now());
  perform tst.ok(not (r ->> 'recorded')::bool, 'achat renvoyé : une seule fois');
  perform tst.throws(format('select public.pass_plus_record(%L, ''tx-pass-1'', ''tx-pass-1'', ''p'', ''Production'', now())', v),
                     'transaction_other_user');
  o := public.season_overview();
  perform tst.ok((o -> 'pass_plus' ->> 'active')::bool, 'Pass+ actif');
  perform tst.ok((o -> 'pass_plus' -> 'rewards' -> 0 ->> 'claimed')::bool, 'plus de pub : acquis dès l''achat');

  -- Rattrapage : tous les paliers payants atteints d'un coup.
  select tickets, tokens into v_tickets, v_tokens from public.user_album where user_id = u;
  r := public.season_claim_all('paid');
  perform tst.ok(jsonb_array_length(r -> 'claimed') = least(v_pts / 150, 30), format('rattrapage (%s paliers)', jsonb_array_length(r -> 'claimed')));
  perform tst.ok((select tokens from public.user_album where user_id = u) = v_tokens + 2, 'jetons des paliers 6 et 15');
  perform tst.ok((select count(*) from public.user_coffrets where user_id = u and opened_at is null) = 2, 'coffrets des paliers 7 et 18');
  -- Un autre joueur Pass+ reçoit aussi les siens (clé propre à chaque joueur).
  perform public.pass_plus_record(v, 'tx-pass-v', 'tx-pass-v', 'app.brainlix.passplus', 'Production', public._now());
  perform tst.login(v);
  insert into public.user_quests (user_id, period, period_start, slot, metric, target, label, xp, seeds, completed_at)
  select v, 'day', d::date, s, 'answers', 1, 'x', 0, 0, public._now()
  from generate_series('2026-10-15'::date, '2026-11-08'::date, interval '1 day') d, generate_series(1, 3) s;
  perform public.season_claim_all('paid');
  perform tst.ok((select count(*) from public.user_coffrets where user_id = v) = 1, 'coffret du palier 7 pour un 2e joueur');
  perform public.pass_plus_revoke('tx-pass-v');
  perform tst.login(u);
  perform tst.ok(exists (select 1 from public.user_cosmetics where user_id = u and item_id = 'cadre.vitrail'), 'cadre Vitrail');
  perform tst.ok(jsonb_array_length(public.season_claim_all('paid') -> 'claimed') = 0, 'rien à reprendre');
  perform tst.throws('select public.season_claim(6, ''paid'')', 'already_claimed');
  perform tst.throws('select public.season_claim(30, ''paid'')', 'tier_not_reached');
  -- Les deux pistes ne se mélangent pas (même palier, coffres distincts).
  perform public.season_claim(4);
  perform tst.ok((select count(*) from public.user_chests where user_id = u and source = 'season') >= 2, 'coffres des deux pistes');

  -- Plus de pub : pas de pub plein écran, bonus sans vidéo avec les mêmes limites.
  st := public.ad_status();
  perform tst.ok((st ->> 'pass_plus')::bool and not (st ->> 'interstitial')::bool, 'pas de pub plein écran');
  v_tickets := (select tickets from public.user_album where user_id = u);
  r := public.ad_claim('free_pack', null);
  perform tst.ok((r ->> 'pack_tickets')::int = 1 and (select tickets from public.user_album where user_id = u) = v_tickets + 1,
                 'pochette gratuite sans pub');
  perform tst.throws('select public.ad_can(''free_pack'', null)', 'ad_limit');
  perform tst.throws('select public.ad_claim(''free_pack'', null)', 'ad_limit');
  r := public.ad_claim('free_chest', null);
  perform tst.ok(r ? 'chest_id', 'coffre offert sans pub');
  perform tst.ok((select bool_and(test and ad_unit = 'pass_plus') from public.ad_views where user_id = u),
                 'notés « pass_plus », hors statistiques des vraies pubs');

  -- Coffret de catégorie : 12 domaines au plus, 3 cartes, jamais de légendaire, au plus une épique.
  o := public.album_overview();
  perform tst.ok(jsonb_array_length(o -> 'coffrets') = 2, 'coffrets dans l''album');
  v_coffret := (o -> 'coffrets' -> 0 ->> 'id')::uuid;
  for k, x in select * from jsonb_each(o -> 'coffrets' -> 0 -> 'offers') loop
    perform tst.ok(jsonb_array_length(x) = 3, 'trois cartes par domaine');
    perform tst.ok((select count(*) from public.album_cards c where c.id in (select jsonb_array_elements_text(x)) and c.rarity = 'legend') = 0
                   and (select count(*) from public.album_cards c where c.id in (select jsonb_array_elements_text(x)) and c.rarity = 'epic') <= 1,
                   'pas de légendaire, une épique au plus');
  end loop;
  select key, array(select jsonb_array_elements_text(value)) into v_domain, v_cards
  from jsonb_each(o -> 'coffrets' -> 0 -> 'offers') limit 1;
  -- La première carte est déjà brillante : elle ne donne rien ; la deuxième est un doublon : elle devient brillante.
  insert into public.user_cards (user_id, slot, card_id, shiny) values (u, 0, v_cards[1], true), (u, 0, v_cards[2], false)
  on conflict (user_id, slot, card_id) do update set shiny = excluded.shiny;
  perform tst.throws(format('select public.album_open_coffret(%L, ''nope'')', v_coffret), 'invalid_series');
  r := public.album_open_coffret(v_coffret, v_domain);
  perform tst.ok(r -> 'pulls' -> 0 ->> 'outcome' = 'nothing' and r -> 'pulls' -> 1 ->> 'outcome' = 'shiny'
                 and r -> 'pulls' -> 2 ->> 'outcome' = 'new', 'rien, brillante, nouvelle');
  perform tst.ok(public.album_open_coffret(v_coffret, v_domain) = r, 'même demande renvoyée : même résultat');
  perform tst.throws(format('select public.album_open_coffret(%L, ''history'')', v_coffret), 'coffret_opened');
  perform tst.login(v);
  perform tst.throws(format('select public.album_open_coffret(%L, %L)', v_coffret, v_domain), 'coffret_not_found');
  perform tst.login(u);

  -- Remboursement : le Pass+ s'arrête, les pubs reviennent.
  perform tst.ok((public.pass_plus_revoke('tx-pass-1') ->> 'revoked')::bool, 'remboursement');
  perform tst.ok(not (public.ad_status() ->> 'pass_plus')::bool and (public.ad_status() ->> 'interstitial')::bool, 'pubs de retour');
  perform tst.throws('select public.season_claim(25, ''paid'')', 'pass_required');
  perform tst.tick('1 day');
  perform tst.throws('select public.ad_claim(''free_chest'', null)', 'ad_pending');  -- de nouveau une vraie pub à regarder

  -- Saison 2 (sa piste Pass+ viendra en décembre) : pas en vente ; refusé en production, accepté pour un achat de test
  -- (TestFlight, examen d'Apple).
  perform tst.clock('2027-02-01 10:00:00+01');
  perform tst.throws(format('select public.pass_plus_record(%L, ''tx-pass-2'', ''tx-pass-2'', ''p'', ''Production'', public._now())', v),
                     'pass_not_on_sale');
  r := public.pass_plus_record(v, 'tx-pass-3', 'tx-pass-3', 'p', 'Sandbox', public._now());
  perform tst.ok((r ->> 'season_id')::int = 2, 'achat de test accepté sur la saison 2');
  perform tst.login(v);
  perform tst.ok(not (public.season_overview() -> 'pass_plus' ->> 'on_sale')::bool, 'pas en vente en saison 2 pour l''instant');
  perform tst.ok(jsonb_array_length(public.season_overview() -> 'pass_plus' -> 'rewards') = 0, 'pas encore de piste Pass+ d''hiver');
  perform tst.ok((public.ad_status() ->> 'pass_plus')::bool, 'le testeur n''a plus de pub');
  -- Un achat de la saison 1 restauré plus tard ne donne pas la saison 2.
  r := public.pass_plus_record(v, 'tx-pass-4', 'tx-pass-4', 'p', 'Production', '2026-12-10 12:00:00+01');
  perform tst.ok((r ->> 'season_id')::int = 1, 'saison de la date d''achat');

  -- Droits : l'app ne peut ni enregistrer ni retirer un achat.
  perform tst.ok(not has_function_privilege('authenticated', 'public.pass_plus_record(uuid, text, text, text, text, timestamptz)', 'execute')
                 and not has_function_privilege('authenticated', 'public.pass_plus_revoke(text)', 'execute'), 'achats : clé de service seulement');
  perform tst.ok(not has_table_privilege('authenticated', 'public.season_passes', 'select'), 'table des achats fermée');
end $$;
