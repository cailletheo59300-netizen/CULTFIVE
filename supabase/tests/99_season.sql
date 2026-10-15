-- Pass de saison (piste gratuite) : points depuis les défis et les missions, paliers, récompenses une seule fois.
do $$
declare
  u uuid := tst.new_user();
  o jsonb; v_pts int; v_card text;
begin
  perform tst.clock('2027-04-12 10:00:00+02');
  update public.seasons set starts_on = '2027-04-01', ends_on = '2027-06-01' where id = 1;
  perform tst.login(u);

  o := public.season_overview();
  perform tst.ok(o -> 'season' ->> 'name' = 'Saison 1', 'saison en cours');
  perform tst.ok((o ->> 'points')::int = 0 and (o ->> 'tier')::int = 0, 'départ à 0');
  perform tst.ok(jsonb_array_length(o -> 'rewards') = 30 and jsonb_array_length(o -> 'missions') = 12, '30 paliers, 12 missions');
  perform tst.throws('select public.season_claim(1)', 'tier_not_reached');

  -- Défis : 15 par défi du jour, +15 si les 3 ; 40 par défi de la semaine, +60 si les 3.
  insert into public.user_quests (user_id, period, period_start, slot, metric, target, label, xp, seeds, completed_at) values
    (u, 'day', '2027-04-12', 1, 'answers', 1, 'a', 0, 0, public._now()),
    (u, 'day', '2027-04-12', 2, 'answers', 1, 'b', 0, 0, public._now()),
    (u, 'day', '2027-04-12', 3, 'answers', 1, 'c', 0, 0, public._now()),
    (u, 'week', '2027-04-12', 1, 'answers', 1, 'd', 0, 0, public._now()),
    (u, 'week', '2027-04-12', 2, 'answers', 1, 'e', 0, 0, null),
    (u, 'day', '2027-03-20', 1, 'answers', 1, 'avant la saison', 0, 0, public._now());
  o := public.season_overview();
  perform tst.ok((o ->> 'points')::int = 3 * 15 + 15 + 40, format('points des défis (%s)', o ->> 'points'));
  perform tst.ok((o ->> 'tier')::int = 0, 'pas encore de palier');

  -- Missions : une légendaire et une brillante (75 chacune).
  select id into v_card from public.album_cards where rarity = 'legend' limit 1;
  perform public._album_row(u);
  insert into public.user_cards (user_id, slot, card_id, shiny) values (u, 0, v_card, true);
  o := public.season_overview();
  perform tst.ok((o ->> 'points')::int = 100 + 2 * 75, 'missions comptées');
  perform tst.ok((select bool_and((m ->> 'done')::bool) from jsonb_array_elements(o -> 'missions') m where (m ->> 'slot')::int in (4, 5)),
                 'brillante et légendaire remplies');
  perform tst.ok((o ->> 'tier')::int = 1, 'palier 1 atteint');

  -- Une carte de la collection admin ne compte pas.
  insert into public.user_cards (user_id, slot, card_id) select u, 1, id from public.album_cards where rarity = 'legend' and id <> v_card limit 1;
  perform tst.ok((public.season_overview() ->> 'points')::int = 250, 'collection admin ignorée');

  -- Récompenses : une seule fois, seulement les paliers atteints.
  perform public.season_claim(1);
  perform tst.ok((select count(*) from public.user_chests where user_id = u and source = 'season') = 1, 'coffre en bois du palier 1');
  perform tst.throws('select public.season_claim(1)', 'already_claimed');
  perform tst.throws('select public.season_claim(2)', 'tier_not_reached');
  perform tst.throws('select public.season_claim(31)', 'invalid_tier');

  -- Toute la saison : tickets, jeton, habillage, final (dos + pochette dorée), puis coffres en bois après le 30.
  insert into public.user_quests (user_id, period, period_start, slot, metric, target, label, xp, seeds, completed_at)
  select u, 'day', d::date, s, 'answers', 1, 'x', 0, 0, public._now()
  from generate_series('2027-04-01'::date, '2027-05-31'::date, interval '1 day') d, generate_series(1, 3) s
  where d::date <> '2027-04-12';
  insert into public.user_quests (user_id, period, period_start, slot, metric, target, label, xp, seeds, completed_at)
  select u, 'week', d::date, s, 'answers', 1, 'y', 0, 0, public._now()
  from generate_series('2027-04-19'::date, '2027-05-31'::date, interval '7 days') d, generate_series(1, 3) s;
  v_pts := (public.season_overview() ->> 'points')::int;
  perform tst.ok(v_pts >= 30 * 150 + 3 * 150, format('assez de points pour tout (%s)', v_pts));
  for i in 2..30 loop perform public.season_claim(i); end loop;
  perform tst.ok((select tickets from public.user_album where user_id = u) = 5
                 and (select sum(amount) from public.ledger where user_id = u and reason = 'ticket_overflow') = (3 + 8 - 5) * 30,
                 '8 tickets gagnés (+3 de bienvenue) : 5 gardés, le reste en neurones (0057)');
  perform tst.ok((select tokens from public.user_album where user_id = u) = 1, '1 jeton Prestige');
  perform tst.ok((select gold_packs from public.user_album where user_id = u) = 1, 'pochette dorée finale');
  perform tst.ok(exists (select 1 from public.user_cosmetics where user_id = u and item_id = 'dos.nuit'), 'dos Nuit étoilée');
  perform tst.ok(exists (select 1 from public.user_cosmetics where user_id = u and item_id = 'cadre.citrouille'), 'cadre Citrouille');
  perform tst.ok((public.season_claim_extra() ->> 'claimed')::int = least(v_pts / 150 - 30, 10), 'coffres en bois après le 30');
  perform tst.ok((public.season_claim_extra() ->> 'claimed')::int = 0, 'jamais deux fois');

  -- Sécurité.
  perform tst.ok(not has_function_privilege('authenticated', 'public._season_points(uuid, public.seasons)', 'execute'), 'points : interne');
  perform tst.ok(has_function_privilege('authenticated', 'public.season_claim(int, text)', 'execute'), 'récupérer : connectés');
  perform tst.ok(not has_function_privilege('anon', 'public.season_overview()', 'execute'), 'fermé aux anonymes');
end $$;
