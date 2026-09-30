-- Brainlix — 0024 Boutique de Léon, formes de Léon, nouveaux objets
--
-- Boutique (graines uniquement, jamais d'argent réel) : 12 couleurs de peau (200–600), 4 motifs (800–1 500),
-- 12 objets (300–1 200). Vitrine du jour : 3 objets par joueur et par jour, le premier à −30 %.
-- Les objets des coffres et des fruits ne sont jamais en boutique.
-- Formes de Léon, débloquées par l'arbre : Bébé (dès le départ), Jeune (Jeune plant), Adulte (Arbre), Sage (en fleurs).
-- Sans forme choisie, l'app affiche la plus avancée débloquée ; on peut revenir à une ancienne forme.

alter table public.items drop constraint if exists items_slot_check;
alter table public.items drop constraint if exists items_rarity_check;
alter table public.items drop constraint if exists items_check;
alter table public.items
  add column price int check (price > 0),
  add column unlock_stage int check (unlock_stage between 1 and 6),
  add constraint items_slot_check check (slot in ('hat', 'eyes', 'neck', 'back', 'skin', 'pattern', 'effect', 'form')),
  add constraint items_rarity_check check (rarity in ('chest', 'fruit', 'shop', 'tree')),
  add constraint items_cosmetic_check check ((kind = 'cosmetic') = (slot is not null and rarity is not null)),
  add constraint items_shop_price_check check ((rarity = 'shop') = (price is not null)),
  add constraint items_tree_stage_check check ((rarity = 'tree') = (unlock_stage is not null));

insert into public.items (id, kind, slot, rarity, name, sort, price, unlock_stage) values
  -- Formes (arbre)
  ('form_baby',        'cosmetic', 'form',    'tree', 'Bébé',                  300, null, 1),
  ('form_young',       'cosmetic', 'form',    'tree', 'Jeune',                 310, null, 3),
  ('form_adult',       'cosmetic', 'form',    'tree', 'Adulte',                320, null, 5),
  ('form_sage',        'cosmetic', 'form',    'tree', 'Sage',                  330, null, 6),
  -- Couleurs de peau
  ('skin_mint',        'cosmetic', 'skin',    'shop', 'Menthe',                400, 200, null),
  ('skin_peach',       'cosmetic', 'skin',    'shop', 'Pêche',                 401, 200, null),
  ('skin_sky',         'cosmetic', 'skin',    'shop', 'Ciel',                  402, 200, null),
  ('skin_coral',       'cosmetic', 'skin',    'shop', 'Corail',                403, 200, null),
  ('skin_ocean',       'cosmetic', 'skin',    'shop', 'Océan',                 404, 250, null),
  ('skin_lavender',    'cosmetic', 'skin',    'shop', 'Lavande',               405, 250, null),
  ('skin_lemon',       'cosmetic', 'skin',    'shop', 'Citron',                406, 250, null),
  ('skin_raspberry',   'cosmetic', 'skin',    'shop', 'Framboise',             407, 300, null),
  ('skin_forest',      'cosmetic', 'skin',    'shop', 'Forêt',                 408, 300, null),
  ('skin_cocoa',       'cosmetic', 'skin',    'shop', 'Cacao',                 409, 350, null),
  ('skin_night',       'cosmetic', 'skin',    'shop', 'Nuit',                  410, 400, null),
  ('skin_snow',        'cosmetic', 'skin',    'shop', 'Neige',                 411, 600, null),
  -- Motifs
  ('pattern_stripes',  'cosmetic', 'pattern', 'shop', 'Rayures',               500, 800, null),
  ('pattern_dots',     'cosmetic', 'pattern', 'shop', 'Pois',                  501, 800, null),
  ('pattern_stars',    'cosmetic', 'pattern', 'shop', 'Étoiles',               502, 1200, null),
  ('pattern_rainbow',  'cosmetic', 'pattern', 'shop', 'Arc-en-ciel',           503, 1500, null),
  -- Objets
  ('cap',              'cosmetic', 'hat',     'shop', 'Casquette',             600, 300, null),
  ('beanie',           'cosmetic', 'hat',     'shop', 'Bonnet',                601, 300, null),
  ('wizard_hat',       'cosmetic', 'hat',     'shop', 'Chapeau de magicien',   602, 900, null),
  ('crown',            'cosmetic', 'hat',     'shop', 'Couronne',              603, 1200, null),
  ('sunglasses',       'cosmetic', 'eyes',    'shop', 'Lunettes de soleil',    610, 400, null),
  ('hero_mask',        'cosmetic', 'eyes',    'shop', 'Masque de héros',       611, 700, null),
  ('medal',            'cosmetic', 'neck',    'shop', 'Médaille',              620, 500, null),
  ('flower_necklace',  'cosmetic', 'neck',    'shop', 'Collier de fleurs',     621, 450, null),
  ('backpack',         'cosmetic', 'back',    'shop', 'Sac à dos',             630, 500, null),
  ('wings',            'cosmetic', 'back',    'shop', 'Ailes',                 631, 1200, null),
  ('aura_stars',       'cosmetic', 'effect',  'shop', 'Aura étoilée',          640, 1000, null),
  ('bubbles',          'cosmetic', 'effect',  'shop', 'Bulles',                641, 600, null);

-- Formes débloquées selon l'étape de l'arbre (appelé à chaque lecture de la progression).
create or replace function public._grant_forms(p_user uuid) returns void
language plpgsql as $$
declare v_stage int;
begin
  select public._tree_stage(tree_points) into v_stage from public.profiles where id = p_user;
  insert into public.user_items (user_id, item_id, acquired_at)
  select p_user, i.id, public._now() from public.items i
  where i.rarity = 'tree' and i.unlock_stage <= coalesce(v_stage, 1)
  on conflict do nothing;
end $$;

-- Vitrine du jour : 3 objets de boutique (pas encore possédés d'abord), tirage stable par joueur et par jour.
create or replace function public._shop_featured(p_user uuid) returns text[]
language sql stable as $$
  select coalesce(array_agg(id order by n), '{}') from (
    select i.id, row_number() over (order by (ui.item_id is not null), md5(i.id || public._user_today(p_user)::text || p_user::text)) n
    from public.items i
    left join public.user_items ui on ui.user_id = p_user and ui.item_id = i.id
    where i.rarity = 'shop'
  ) t where n <= 3
$$;

-- Prix pour ce joueur aujourd'hui : −30 % (arrondi à la dizaine) sur le premier objet de la vitrine.
create or replace function public._shop_price(p_user uuid, p_item text) returns int
language sql stable as $$
  select case when (public._shop_featured(p_user))[1] = p_item then (round(i.price * 0.7 / 10) * 10)::int else i.price end
  from public.items i where i.id = p_item and i.rarity = 'shop'
$$;

create or replace function public.shop_overview() returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user();
begin
  return jsonb_build_object(
    'featured', (select coalesce(jsonb_agg(jsonb_build_object('id', f.id, 'price', public._shop_price(v_user, f.id),
                                                              'original', i.price) order by f.n), '[]'::jsonb)
                 from unnest(public._shop_featured(v_user)) with ordinality f(id, n)
                 join public.items i on i.id = f.id),
    'resets_at', public._day_end(public._user_today(v_user), public._user_tz(v_user)),
    'balance', (select seeds from public.profiles where id = v_user));
end $$;

-- Achat (une fois par objet) : débit en graines puis objet ajouté. Idempotent : un objet possédé n'est jamais repayé.
create or replace function public.shop_buy(p_item text) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  v_price int;
begin
  if not exists (select 1 from public.items where id = p_item and rarity = 'shop') then raise exception 'item_not_for_sale'; end if;
  perform 1 from public.profiles where id = v_user for update;
  if exists (select 1 from public.user_items where user_id = v_user and item_id = p_item) then
    return jsonb_build_object('bought', false, 'item', p_item, 'balance', (select seeds from public.profiles where id = v_user));
  end if;
  v_price := public._shop_price(v_user, p_item);
  if (select seeds from public.profiles where id = v_user) < v_price then raise exception 'insufficient_seeds'; end if;
  perform public._grant(v_user, 'seeds', -v_price, 'shop', p_item, 'shop:' || p_item);
  perform public._give_item(v_user, p_item);
  return jsonb_build_object('bought', true, 'item', p_item, 'price', v_price,
                            'balance', (select seeds from public.profiles where id = v_user));
end $$;

-- Tenue : nouveaux emplacements (motif, effet, forme).
create or replace function public.leon_equip(p_slot text, p_item text default null) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user();
begin
  if p_slot not in ('hat', 'eyes', 'neck', 'back', 'skin', 'pattern', 'effect', 'form') then raise exception 'invalid_slot'; end if;
  if p_item is not null and not exists (
       select 1 from public.user_items ui join public.items i on i.id = ui.item_id
       where ui.user_id = v_user and ui.item_id = p_item and i.kind = 'cosmetic' and i.slot = p_slot) then
    raise exception 'item_not_owned';
  end if;
  update public.user_items ui set equipped = (ui.item_id is not distinct from p_item)
  from public.items i
  where ui.user_id = v_user and i.id = ui.item_id and i.slot = p_slot;
  return public._leon_outfit(v_user);
end $$;

-- Progression : formes débloquées à la lecture, prix et forme la plus avancée.
create or replace function public.progression_overview() returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  p public.profiles;
begin
  perform public._grant_forms(v_user);
  select * into p from public.profiles where id = v_user;
  return jsonb_build_object(
    'xp', p.xp_total,
    'level', public._xp_level(p.xp_total),
    'seeds', p.seeds,
    'streak_freezes', p.streak_freezes,
    'tree', public._tree_json(p),
    'chests', (select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'tier', c.tier, 'source', c.source, 'ref', c.ref,
                                                            'created_at', c.created_at) order by c.created_at), '[]'::jsonb)
               from public.user_chests c where c.user_id = v_user and c.opened_at is null),
    'tickets', jsonb_build_object(
      'fifty_fifty', coalesce((select qty from public.user_items where user_id = v_user and item_id = 'ticket_fifty_fifty'), 0),
      'hint', coalesce((select qty from public.user_items where user_id = v_user and item_id = 'ticket_hint'), 0)),
    'outfit', public._leon_outfit(v_user),
    'best_form', (select i.id from public.user_items ui join public.items i on i.id = ui.item_id
                  where ui.user_id = v_user and i.slot = 'form' order by i.unlock_stage desc limit 1),
    'items', (select coalesce(jsonb_agg(jsonb_build_object(
                'id', i.id, 'name', i.name, 'slot', i.slot, 'rarity', i.rarity, 'price', i.price, 'unlock_stage', i.unlock_stage,
                'owned', ui.item_id is not null, 'equipped', coalesce(ui.equipped, false)) order by i.sort), '[]'::jsonb)
              from public.items i
              left join public.user_items ui on ui.item_id = i.id and ui.user_id = v_user
              where i.kind = 'cosmetic'));
end $$;

-- Droits
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig from pg_proc p
    where p.pronamespace = 'public'::regnamespace and p.proname in ('_grant_forms', '_shop_featured', '_shop_price')
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', f.sig);
  end loop;
end $$;
do $$
declare f text;
begin
  foreach f in array array['shop_overview()', 'shop_buy(text)', 'leon_equip(text,text)', 'progression_overview()'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig from pg_proc p
    where p.pronamespace = 'public'::regnamespace and p.prokind in ('f', 'p')
      and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%')
  loop
    execute format('alter function %s set search_path = public, extensions, pg_temp', f.sig);
  end loop;
end $$;
