-- Boutique (D-118) : « Sans pub pour toujours » (7,99 €, achat unique), séparé du Pass+.
-- Les achats autres que le Pass+ sont notés dans `purchases` ; chaque produit est décrit dans `shop_products`
-- (les packs d'objets et l'offre de bienvenue s'y ajouteront). Le Pass+ garde sa table (season_passes) et son
-- « plus de pub pendant la saison ». Plus de pub = Pass+ de la saison, ou « Sans pub pour toujours », ou des heures
-- sans pub encore valables (`profiles.no_ads_until`, packs et bienvenue).
-- La fonction Edge `iap-verify` appelle désormais `iap_record` pour tous les produits.

create table public.shop_products (
  id    text primary key,
  -- forever : acheté une fois pour toujours (non consommable) ; consumable : peut se racheter.
  kind  text not null check (kind in ('forever', 'consumable')),
  label text not null
);
alter table public.shop_products enable row level security;
revoke all on public.shop_products from public, anon, authenticated;

insert into public.shop_products (id, kind, label) values ('app.brainlix.noads', 'forever', 'Sans pub pour toujours');

create table public.purchases (
  transaction_id          text primary key,
  original_transaction_id text,
  user_id                 uuid not null references public.profiles(id) on delete cascade,
  product_id              text not null references public.shop_products(id),
  environment             text not null check (environment in ('Production', 'Sandbox', 'Xcode', 'LocalTesting')),
  purchased_at            timestamptz not null,
  recorded_at             timestamptz not null default now(),
  revoked_at              timestamptz
);
create index on public.purchases (user_id) where revoked_at is null;
alter table public.purchases enable row level security;
revoke all on public.purchases from public, anon, authenticated;

alter table public.profiles add column if not exists no_ads_until timestamptz;

-- « Sans pub pour toujours » acheté (et pas remboursé).
create or replace function public._no_ads_forever(p_user uuid) returns bool
language sql stable set search_path = public, pg_temp as $$
  select exists (select 1 from public.purchases
                 where user_id = p_user and product_id = 'app.brainlix.noads' and revoked_at is null)
$$;

-- Plus aucune pub : Pass+ de la saison, sans pub pour toujours, ou heures sans pub encore valables.
create or replace function public._no_ads(p_user uuid) returns bool
language sql stable set search_path = public, pg_temp as $$
  select public._has_pass(p_user) or public._no_ads_forever(p_user)
      or coalesce((select no_ads_until > public._now() from public.profiles where id = p_user), false)
$$;

-- Modifie une fonction existante sur place : chaque remplacement doit trouver son texte.
create or replace function pg_temp.patch(p_fn regprocedure, p_pairs text[]) returns void language plpgsql as $$
declare v_def text := pg_get_functiondef(p_fn); v_new text; i int;
begin
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    v_new := replace(v_def, p_pairs[2 * i - 1], p_pairs[2 * i]);
    if v_new = v_def then raise exception 'patch % : texte % introuvable', p_fn, i; end if;
    v_def := v_new;
  end loop;
  execute v_def;
end $$;

-- Bonus « pub » donnés sans vidéo à tous ceux qui n'ont plus de pub (plus seulement au Pass+).
select pg_temp.patch('public._ad_take(uuid, text, text, boolean)', array[
  'if v_tx is null and public._has_pass(p_user) then', 'if v_tx is null and public._no_ads(p_user) then'
]);

-- Statut des pubs : `no_ads` (toutes les raisons), `no_ads_forever`, `no_ads_until`. `pass_plus` reste le Pass+
-- seul (les apps jusqu'à 1.5 le lisent comme « plus de pub » ; l'interstitiel, lui, suit `no_ads` pour tous).
select pg_temp.patch('public.ad_status()', array[
  'and not public._has_pass(v_user),', 'and not public._no_ads(v_user),',
  '''pass_plus'', public._has_pass(v_user),',
  '''pass_plus'', public._has_pass(v_user),
    ''no_ads'', public._no_ads(v_user),
    ''no_ads_forever'', public._no_ads_forever(v_user),
    ''no_ads_until'', case when p.no_ads_until > public._now() then p.no_ads_until end,'
]);

-- Un achat vérifié par `iap-verify` (clé de service), pour n'importe quel produit. Idempotent.
create or replace function public.iap_record(p_user uuid, p_transaction text, p_original text, p_product text,
                                             p_environment text, p_purchased_at timestamptz)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
  pr public.shop_products;
  x public.purchases;
begin
  if p_product = 'app.brainlix.pass' then
    return public.pass_plus_record(p_user, p_transaction, p_original, p_product, p_environment, p_purchased_at)
           || jsonb_build_object('product', p_product);
  end if;
  select * into pr from public.shop_products where id = p_product;
  if not found then raise exception 'wrong_product'; end if;
  select * into x from public.purchases where transaction_id = p_transaction;
  if found then
    if x.user_id <> p_user then raise exception 'transaction_other_user'; end if;
    return jsonb_build_object('product', p_product, 'active', x.revoked_at is null, 'recorded', false);
  end if;
  if not exists (select 1 from public.profiles where id = p_user) then raise exception 'user_not_found'; end if;
  -- Un achat « pour toujours » ne s'achète qu'une fois par compte (une restauration renvoie le même).
  if pr.kind = 'forever' and exists (select 1 from public.purchases where user_id = p_user and product_id = p_product
                                     and revoked_at is null) then
    return jsonb_build_object('product', p_product, 'active', true, 'recorded', false);
  end if;
  insert into public.purchases (transaction_id, original_transaction_id, user_id, product_id, environment, purchased_at, recorded_at)
  values (p_transaction, p_original, p_user, p_product, p_environment, p_purchased_at, public._now());
  return jsonb_build_object('product', p_product, 'active', true, 'recorded', true);
end $$;

-- Remboursement signalé par Apple : vaut aussi pour les achats de la boutique.
select pg_temp.patch('public.pass_plus_revoke(text)', array[
  '  return jsonb_build_object(''revoked'', found);',
  '  v_found := found;
  update public.purchases set revoked_at = coalesce(revoked_at, public._now())
  where transaction_id = p_transaction or original_transaction_id = p_transaction;
  return jsonb_build_object(''revoked'', v_found or found);',
  'begin
  update public.season_passes', 'declare v_found bool;
begin
  update public.season_passes'
]);

revoke execute on function public.iap_record(uuid, text, text, text, text, timestamptz) from public, anon, authenticated;
grant execute on function public.iap_record(uuid, text, text, text, text, timestamptz) to service_role;
revoke execute on function public._no_ads(uuid), public._no_ads_forever(uuid) from public, anon, authenticated;
