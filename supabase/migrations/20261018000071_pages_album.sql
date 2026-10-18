-- Objectifs d'album (D-075) : chaque page complétée (toutes ses cartes dans la collection du joueur) donne un coffre
-- en argent, une seule fois par page. L'app montre « Plus que N » sur la page, avec le coffre à gagner.
create or replace function public._album_page_reward(p_user uuid, p_page text) returns bool
language plpgsql set search_path = public, pg_temp as $$
begin
  if not exists (select 1 from public.album_cards c where c.page_key = p_page) then return false; end if;
  if exists (select 1 from public.album_cards c where c.page_key = p_page
               and not exists (select 1 from public.user_cards uc
                               where uc.user_id = p_user and uc.slot = 0 and uc.card_id = c.id)) then
    return false;
  end if;
  return public._give_chest(p_user, 'silver', 'album_page', p_page, 'album_page:' || p_page);
end $$;

-- Arrivée d'une carte (collection du joueur) : exploits (0064) et page complétée.
create or replace function public._exploits_on_card() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if new.slot = 0 then
    perform public._check_more_achievements(new.user_id);
    perform public._album_page_reward(new.user_id, (select page_key from public.album_cards where id = new.card_id));
  end if;
  return null;
end $$;

revoke execute on function public._album_page_reward(uuid, text) from public, anon, authenticated;

-- Rattrapage : les pages déjà complètes donnent leur coffre.
do $$
declare r record;
begin
  for r in select distinct uc.user_id, c.page_key from public.user_cards uc join public.album_cards c on c.id = uc.card_id
           where uc.slot = 0 loop
    perform public._album_page_reward(r.user_id, r.page_key);
  end loop;
end $$;
