-- Look du joueur (D-120) : avatars premium, contours d'avatar et titres sous le pseudo, achetés à la boutique.
-- Tout est rangé dans profiles.avatar (clés animal, ring, title) : chaque classement, duel, ligue et profil qui envoie
-- déjà l'avatar envoie donc aussi le contour et le titre. On ne pose que ce qu'on possède (user_looks) ; les 8
-- personnages de départ restent gratuits pour tous.
--   Avatars premium (0,99 € l'un, 2,49 € les 4) : Jeanne d'Arc, Victor Hugo, Galilée, Darwin.
--   Contours (0,99 €) : néon, or, arc-en-ciel animé. Titres (0,99 €) : Érudit, Encyclopédie vivante, Génie.
--   Pack Prestige (4,99 €), contenus exclusifs : Toutânkhamon, Athéna, contour Prestige animé, titre « Légende ».
--   Offre de bienvenue : en plus, l'avatar Hypatie et le contour Bienvenue (exclusifs).
-- Les décorations gagnées au classement (couronne du 1er, contours 2e, 3e, top 10) se dessinent dans l'app selon le
-- rang : elles ne s'achètent jamais.

create table public.user_looks (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  look       text not null check (look ~ '^(avatar|ring|title)\.[a-z]+$'),
  source     text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, look)
);
alter table public.user_looks enable row level security;
revoke all on public.user_looks from public, anon, authenticated;

create or replace function public._owns_look(p_user uuid, p_look text) returns bool
language sql stable set search_path = public, pg_temp as $$
  select exists (select 1 from public.user_looks where user_id = p_user and look = p_look)
$$;

-- Ce que donne chaque produit de la boutique en look.
create or replace function public._shop_looks(p_product text) returns text[]
language sql immutable set search_path = public, pg_temp as $$
  select case p_product
    when 'app.brainlix.avatar.joan' then array['avatar.joan']
    when 'app.brainlix.avatar.hugo' then array['avatar.hugo']
    when 'app.brainlix.avatar.galileo' then array['avatar.galileo']
    when 'app.brainlix.avatar.darwin' then array['avatar.darwin']
    when 'app.brainlix.avatars' then array['avatar.joan', 'avatar.hugo', 'avatar.galileo', 'avatar.darwin']
    when 'app.brainlix.ring.neon' then array['ring.neon']
    when 'app.brainlix.ring.gold' then array['ring.gold']
    when 'app.brainlix.ring.rainbow' then array['ring.rainbow']
    when 'app.brainlix.title.erudit' then array['title.erudit']
    when 'app.brainlix.title.encyclo' then array['title.encyclo']
    when 'app.brainlix.title.genie' then array['title.genie']
    when 'app.brainlix.prestige' then array['avatar.tut', 'avatar.athena', 'ring.prestige', 'title.legend']
    when 'app.brainlix.bienvenue' then array['avatar.hypatia', 'ring.welcome']
    else '{}'::text[]
  end
$$;

insert into public.shop_products (id, kind, label) values
  ('app.brainlix.avatar.joan', 'forever', 'Avatar Jeanne d''Arc'),
  ('app.brainlix.avatar.hugo', 'forever', 'Avatar Victor Hugo'),
  ('app.brainlix.avatar.galileo', 'forever', 'Avatar Galilée'),
  ('app.brainlix.avatar.darwin', 'forever', 'Avatar Darwin'),
  ('app.brainlix.avatars', 'forever', 'Les 4 avatars premium'),
  ('app.brainlix.ring.neon', 'forever', 'Contour Néon'),
  ('app.brainlix.ring.gold', 'forever', 'Contour Or'),
  ('app.brainlix.ring.rainbow', 'forever', 'Contour Arc-en-ciel'),
  ('app.brainlix.title.erudit', 'forever', 'Titre « Érudit »'),
  ('app.brainlix.title.encyclo', 'forever', 'Titre « Encyclopédie vivante »'),
  ('app.brainlix.title.genie', 'forever', 'Titre « Génie »'),
  ('app.brainlix.prestige', 'forever', 'Pack Prestige')
on conflict (id) do nothing;

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

-- Un achat donne aussi son look (avatars, contours, titres).
select pg_temp.patch('public._shop_grant(uuid, text)', array[
  '  v jsonb := public._shop_contents(p_product);
  v_item text;
begin
  if v is null then return; end if;',
  '  v jsonb := public._shop_contents(p_product);
  v_item text;
begin
  insert into public.user_looks (user_id, look, source, created_at)
  select p_user, l, p_product, public._now() from unnest(public._shop_looks(p_product)) l
  on conflict (user_id, look) do nothing;
  if v is null then return; end if;'
]);

-- Avatar : un des 8 gratuits, ou un avatar possédé.
create or replace function public.avatar_set(p_animal text) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user(); v_avatar jsonb;
begin
  if not (p_animal = any (public._animals())) and not public._owns_look(v_user, 'avatar.' || coalesce(p_animal, '')) then
    raise exception 'invalid_avatar';
  end if;
  update public.profiles set avatar = avatar || jsonb_build_object('animal', p_animal) where id = v_user
  returning avatar into v_avatar;
  return v_avatar;
end $$;

-- Contour ou titre : posé s'il est possédé ; nil le retire.
create or replace function public.look_set(p_kind text, p_value text) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user(); v_avatar jsonb;
begin
  if p_kind not in ('ring', 'title') then raise exception 'invalid_look'; end if;
  if p_value is not null and not public._owns_look(v_user, p_kind || '.' || p_value) then raise exception 'look_not_owned'; end if;
  update public.profiles
     set avatar = case when p_value is null then avatar - p_kind else avatar || jsonb_build_object(p_kind, p_value) end
   where id = v_user
  returning avatar into v_avatar;
  return v_avatar;
end $$;

-- L'app ne pose plus le personnage, le contour ni le titre par profile_update (seulement par avatar_set, look_set).
select pg_temp.patch('public.profile_update(jsonb)', array[
  'then avatar || (p -> ''avatar'') else avatar end,',
  'then avatar || ((p -> ''avatar'') - ''animal'' - ''ring'' - ''title'') else avatar end,'
]);

-- La boutique dit ce qu'on possède.
select pg_temp.patch('public.boutique_overview()', array[
  '    ''items'', public._boost_stock(v_user),',
  '    ''items'', public._boost_stock(v_user),
    ''looks'', coalesce((select jsonb_agg(look order by look) from public.user_looks where user_id = v_user), ''[]''::jsonb),'
]);

revoke execute on function public.look_set(text, text) from public, anon;
grant execute on function public.look_set(text, text) to authenticated;
revoke execute on function public._owns_look(uuid, text), public._shop_looks(text) from public, anon, authenticated;
