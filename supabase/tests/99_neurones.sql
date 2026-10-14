-- Coffres sans objets de Léon : tickets de pochette et carte surprise (or et Savant).
do $$
declare
  u uuid := tst.new_user();
  r jsonb; v_chest uuid;
begin
  perform tst.clock('2027-04-12 10:00:00+02');
  perform tst.login(u);
  for i in 1..20 loop
    perform public._give_chest(u, 'gold', 'test', null, 'test:gold:' || i);
  end loop;
  for v_chest in select id from public.user_chests where user_id = u loop
    r := public.chest_open(v_chest);
    perform tst.ok((r ->> 'pack_tickets')::int >= 1, 'or : au moins un ticket de pochette');
    perform tst.ok(r -> 'card' ->> 'card' is not null and r -> 'card' ->> 'rarity' in ('rare', 'epic', 'legend'), 'or : carte rare ou mieux');
    perform tst.ok(r -> 'item' is null and r -> 'bonus_item' is null, 'plus d''objet de Léon');
  end loop;
  perform tst.ok((select tickets from public.user_album where user_id = u) >= 3 + 20, 'tickets ajoutés à l''album');
  perform tst.ok((select count(*) from public.user_cards where user_id = u and slot = 0) >= 1, 'cartes ajoutées à l''album');
  perform tst.ok(not exists (select 1 from public.user_items ui join public.items i on i.id = ui.item_id
                             where ui.user_id = u and i.kind = 'cosmetic'), 'aucune tenue reçue');
end $$;

-- Tickets d'aide (0052) : un au plus par coffre ; en bois, environ une fois sur 3 ; en or, toujours un.
do $$
declare u uuid := tst.new_user(); c uuid; r jsonb; n_wood int := 0; t_wood int := 0; n int;
begin
  perform tst.login(u);
  for i in 1 .. 300 loop
    insert into public.user_chests (user_id, tier, source, idempotency_key) values (u, 'wood', 'test', 'tk' || i) returning id into c;
    r := public.chest_open(c);
    n := (r -> 'tickets' ->> 'fifty_fifty')::int + (r -> 'tickets' ->> 'hint')::int;
    perform tst.ok(n <= 1, 'un ticket au plus par coffre') where n > 1;
    if r ->> 'final_tier' = 'wood' then n_wood := n_wood + 1; t_wood := t_wood + n; end if;
  end loop;
  perform tst.ok(t_wood::real / n_wood between 0.22 and 0.45, 'bois : un ticket une fois sur 3 (' || t_wood || ' sur ' || n_wood || ')');
  insert into public.user_chests (user_id, tier, source, idempotency_key) values (u, 'gold', 'test', 'tk-or') returning id into c;
  r := public.chest_open(c);
  perform tst.ok((r -> 'tickets' ->> 'fifty_fifty')::int + (r -> 'tickets' ->> 'hint')::int = 1, 'or : 1 ticket');
end $$;
