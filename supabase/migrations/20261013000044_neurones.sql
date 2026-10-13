-- ─────────────────────────────────────────── 0044 · Neurones, fin de l'arbre et des tenues de Léon (D-040, D-046)
-- Les graines s'appellent désormais neurones dans l'app (même solde, même registre, devise 'seeds').
-- Les coffres ne donnent plus d'objets de Léon (ni d'objet exclusif du Savant) : tickets de pochette, cartes et jeton Prestige.
-- Reprend le coffre boosté de 0032 (chances de montée doublées, graines +50 %).
-- L'arbre et la boutique restent en service côté serveur pour les anciennes versions de l'app, qui disparaîtront.

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
  v_want_joker bool;
  v_packs int := 0;
  v_card_rarity public.card_rarity;
  v_card text;
  v_pull jsonb;
  v_token bool := false;
  v_contents jsonb;
begin
  select * into c from public.user_chests where id = p_chest and user_id = v_user for update;
  if not found then raise exception 'chest_not_found'; end if;
  if c.opened_at is not null then
    return c.contents || jsonb_build_object('already_opened', true);
  end if;

  -- Recharge : une montée possible à chaque rang, tirée une seule fois.
  v_final := c.tier::text;
  if v_final = 'wood' and random() < (case when c.boosted then 0.50 else 0.25 end) then v_final := 'silver'; v_upgrades := v_upgrades + 1; end if;
  if v_final = 'silver' and random() < (case when c.boosted then 0.40 else 0.20 end) then v_final := 'gold'; v_upgrades := v_upgrades + 1; end if;
  if v_final = 'gold' and random() < (case when c.boosted then 0.10 else 0.05 end) then v_final := 'savant'; v_upgrades := v_upgrades + 1; end if;

  v_seeds := case v_final when 'wood' then 10 + floor(random() * 11) when 'silver' then 30 + floor(random() * 21)
                          when 'gold' then 60 + floor(random() * 21) else 120 + floor(random() * 41) end;
  if c.boosted then v_seeds := round(v_seeds * 1.5); end if;
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

  -- Plus d'objets de Léon : l'album à la place. Argent : 1 ticket de pochette 1 fois sur 3. Or : 1 ticket et une carte
  -- surprise rare ou mieux. Savant : 2 tickets, une carte épique ou mieux (nouvelle si possible), 1 chance sur 10 d'un jeton Prestige.
  perform public._album_row(v_user);
  v_packs := case v_final when 'wood' then 0 when 'silver' then case when random() < 1.0 / 3 then 1 else 0 end
                          when 'gold' then 1 else 2 end;
  if v_packs > 0 then update public.user_album set tickets = tickets + v_packs where user_id = v_user; end if;
  if v_final in ('gold', 'savant') then
    v_card_rarity := case
      when v_final = 'gold' then case when random() < 0.03 then 'legend' when random() < 0.18 then 'epic' else 'rare' end
      else case when random() < 0.15 then 'legend' else 'epic' end end::public.card_rarity;
    select ac.id into v_card from public.album_cards ac
    where ac.rarity = v_card_rarity
    order by (exists (select 1 from public.user_cards uc where uc.user_id = v_user and uc.slot = 0 and uc.card_id = ac.id)), random()
    limit 1;
    if v_card is not null then v_pull := public._album_receive(v_user, 0::smallint, v_card, 'chest_card:' || c.id); end if;
  end if;
  if v_final = 'savant' and random() < 0.10 then
    update public.user_album set tokens = tokens + 1 where user_id = v_user;
    v_token := true;
  end if;

  perform public._grant(v_user, 'seeds', v_seeds, 'chest', c.id::text, 'chest:' || c.id);
  v_contents := jsonb_build_object(
    'tier', c.tier, 'boosted', c.boosted, 'final_tier', v_final, 'upgrades', v_upgrades, 'seeds', v_seeds,
    'tickets', jsonb_build_object('fifty_fifty', v_fifty, 'hint', v_hint),
    'joker', v_joker,
    'pack_tickets', v_packs,
    'card', v_pull,
    'prestige_token', v_token);
  update public.user_chests set opened_at = public._now(), contents = v_contents where id = c.id;
  return v_contents || jsonb_build_object('balance', (select seeds from public.profiles where id = v_user));
end $$;

revoke execute on function public.chest_open(uuid) from public, anon;
grant execute on function public.chest_open(uuid) to authenticated;
