-- Recharge des coffres : montées tirées par le serveur, coffre Savant, compatibilité.
do $$
declare
  u uuid := tst.new_user();
  c uuid;
  r jsonb;
  n_up int := 0; n_gold int := 0; n_savant int := 0;
  first_savant jsonb;
begin
  perform tst.clock('2027-10-01 10:00:00+02');
  perform tst.login(u);

  -- 2 000 coffres en bois : ~25 % montent (tolérance large).
  for i in 1 .. 2000 loop
    insert into public.user_chests (user_id, tier, source, idempotency_key) values (u, 'wood', 'test', 'w' || i) returning id into c;
    r := public.chest_open(c);
    if r ->> 'final_tier' <> 'wood' then n_up := n_up + 1; end if;
    if r ->> 'final_tier' in ('gold', 'savant') then n_gold := n_gold + 1; end if;
    if i = 1 then
      perform tst.ok(r ->> 'tier' = 'wood', 'rang d''origine conservé');
      perform tst.ok((select contents ->> 'final_tier' from public.user_chests where id = c) = r ->> 'final_tier', 'rang obtenu enregistré');
    end if;
  end loop;
  perform tst.ok(n_up between 400 and 600, 'bois → argent ≈ 25 % (' || n_up || ' sur 2000)');
  perform tst.ok(n_gold between 50 and 160, 'bois → or ≈ 5 % (' || n_gold || ' sur 2000)');

  -- 600 coffres en or : ~5 % deviennent Savant.
  for i in 1 .. 600 loop
    insert into public.user_chests (user_id, tier, source, idempotency_key) values (u, 'gold', 'test', 'g' || i) returning id into c;
    r := public.chest_open(c);
    if r ->> 'final_tier' = 'savant' then
      n_savant := n_savant + 1;
      if first_savant is null then first_savant := r; end if;
      perform tst.ok((r ->> 'seeds')::int >= 120, 'Savant : au moins 120 graines');
      perform tst.ok((r -> 'tickets' ->> 'fifty_fifty')::int = 1 and (r -> 'tickets' ->> 'hint')::int = 1, 'Savant : 2 tickets');
      perform tst.ok((r ->> 'upgrades')::int = 1, 'Savant : une montée depuis l''or');
    end if;
  end loop;
  perform tst.ok(n_savant between 10 and 60, 'or → Savant ≈ 5 % (' || n_savant || ' sur 600)');
  perform tst.ok(exists (select 1 from public.user_items where user_id = u and item_id = 'mortarboard'), 'Mortier possédé');
  perform tst.ok((select count(*) from public.user_chests where user_id = u and contents -> 'bonus_item' ->> 'id' = 'mortarboard') = 1,
                 'Mortier donné une seule fois');

  -- Ouvrir deux fois : même contenu.
  r := public.chest_open(c);
  perform tst.ok((r ->> 'already_opened')::bool, 'coffre déjà ouvert');

  -- Le Mortier n'est jamais vendu.
  perform tst.ok(not exists (select 1 from public.items where id = 'mortarboard' and price is not null), 'Mortier jamais vendu');
end $$;
