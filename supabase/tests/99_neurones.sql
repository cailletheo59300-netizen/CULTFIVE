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
