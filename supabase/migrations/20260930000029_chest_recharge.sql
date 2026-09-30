-- Brainlix — 0029 Coffres : la Recharge et le coffre Savant
-- À l'ouverture, le coffre peut monter de rang (l'app le montre en 3 touchers). Tirage unique par le serveur :
-- bois → argent 25 %, puis argent → or 20 %, puis or → Savant 5 %. Un bois finit donc argent 1 fois sur 4, or 1 sur 20,
-- Savant 1 sur 400 ; un argent finit or 1 fois sur 5 ; un or finit Savant 1 fois sur 20.
-- Le rang d'origine reste dans `user_chests.tier` et dans `contents.tier` (compatibilité des anciennes versions de l'app) ;
-- le rang obtenu est dans `contents.final_tier`.
-- Coffre Savant : 120–160 graines, un joker (ou 40 graines), 2 tickets (un de chaque), un objet des coffres garanti,
-- et au premier Savant le « Mortier de savant », jamais vendu.

alter table public.items drop constraint items_rarity_check;
alter table public.items add constraint items_rarity_check check (rarity in ('chest', 'fruit', 'shop', 'tree', 'savant'));
insert into public.items (id, kind, slot, rarity, name, sort) values
  ('mortarboard', 'cosmetic', 'hat', 'savant', 'Mortier de savant', 150)
on conflict (id) do nothing;

create or replace function public.chest_open(p_chest uuid) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  c public.user_chests;
  v_final text;
  v_upgrades int := 0;
  v_seeds int;
  v_tickets int;
  v_fifty int := 0;
  v_hint int := 0;
  v_joker bool := false;
  v_item public.items;
  v_bonus public.items;
  v_want_joker bool;
  v_want_item bool;
  v_contents jsonb;
begin
  select * into c from public.user_chests where id = p_chest and user_id = v_user for update;
  if not found then raise exception 'chest_not_found'; end if;
  if c.opened_at is not null then
    return c.contents || jsonb_build_object('already_opened', true);
  end if;

  -- Recharge : une montée possible à chaque rang, tirée une seule fois.
  v_final := c.tier::text;
  if v_final = 'wood' and random() < 0.25 then v_final := 'silver'; v_upgrades := v_upgrades + 1; end if;
  if v_final = 'silver' and random() < 0.20 then v_final := 'gold'; v_upgrades := v_upgrades + 1; end if;
  if v_final = 'gold' and random() < 0.05 then v_final := 'savant'; v_upgrades := v_upgrades + 1; end if;

  v_seeds := case v_final when 'wood' then 10 + floor(random() * 11) when 'silver' then 30 + floor(random() * 21)
                          when 'gold' then 60 + floor(random() * 21) else 120 + floor(random() * 41) end;
  if v_final = 'savant' then
    v_fifty := 1; v_hint := 1;
  else
    v_tickets := case v_final when 'wood' then 1 when 'silver' then 2 else 0 end;
    for i in 1 .. v_tickets loop
      if random() < 0.5 then v_fifty := v_fifty + 1; else v_hint := v_hint + 1; end if;
    end loop;
  end if;
  if v_fifty > 0 then perform public._give_item(v_user, 'ticket_fifty_fifty', v_fifty); end if;
  if v_hint > 0 then perform public._give_item(v_user, 'ticket_hint', v_hint); end if;

  v_want_joker := case v_final when 'wood' then random() < 0.10 when 'silver' then random() < 0.30 else true end;
  if v_want_joker then
    update public.profiles set streak_freezes = streak_freezes + 1 where id = v_user and streak_freezes < 2;
    if found then v_joker := true;
    else v_seeds := v_seeds + case v_final when 'wood' then 10 when 'silver' then 20 else 40 end;
    end if;
  end if;

  v_want_item := case v_final when 'wood' then false when 'silver' then random() < 0.25 else true end;
  if v_want_item then
    select i.* into v_item from public.items i
    where i.kind = 'cosmetic' and i.rarity = 'chest'
      and not exists (select 1 from public.user_items ui where ui.user_id = v_user and ui.item_id = i.id)
    order by random() limit 1;
    if v_item.id is not null then perform public._give_item(v_user, v_item.id);
    else v_seeds := v_seeds + case v_final when 'silver' then 25 else 40 end;
    end if;
  end if;

  -- Premier Savant : l'objet exclusif.
  if v_final = 'savant' then
    select i.* into v_bonus from public.items i
    where i.rarity = 'savant'
      and not exists (select 1 from public.user_items ui where ui.user_id = v_user and ui.item_id = i.id)
    order by i.sort limit 1;
    if v_bonus.id is not null then perform public._give_item(v_user, v_bonus.id); end if;
  end if;

  perform public._grant(v_user, 'seeds', v_seeds, 'chest', c.id::text, 'chest:' || c.id);
  v_contents := jsonb_build_object(
    'tier', c.tier, 'final_tier', v_final, 'upgrades', v_upgrades, 'seeds', v_seeds,
    'tickets', jsonb_build_object('fifty_fifty', v_fifty, 'hint', v_hint),
    'joker', v_joker,
    'item', case when v_item.id is not null then jsonb_build_object('id', v_item.id, 'name', v_item.name, 'slot', v_item.slot) end,
    'bonus_item', case when v_bonus.id is not null then jsonb_build_object('id', v_bonus.id, 'name', v_bonus.name, 'slot', v_bonus.slot) end);
  update public.user_chests set opened_at = public._now(), contents = v_contents where id = c.id;
  return v_contents || jsonb_build_object('balance', (select seeds from public.profiles where id = v_user));
end $$;

revoke execute on function public.chest_open(uuid) from public, anon;
grant execute on function public.chest_open(uuid) to authenticated;
