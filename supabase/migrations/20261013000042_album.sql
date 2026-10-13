-- ─────────────────────────────────────────── 0042 · Album de cartes (D-046, D-047, D-048)
-- 525 cartes rangées en 49 pages, chacune reliée aux notions (concepts) qu'elle résume.
-- Collection de chaque joueur, pochettes tirées par le serveur, fabrication, doublons, jeton Prestige, habillage,
-- maîtrise au quiz (étoiles et Chef-d'œuvre), mode admin réservé aux administrateurs.
-- Monnaie : les neurones sont les graines (même solde, même registre `ledger`, devise 'seeds') ; seul le nom change.

create type public.card_rarity as enum ('common', 'rare', 'epic', 'legend');

-- Référentiel, rempli par le seed (scripts/build-seed.mjs, depuis content/album).
create table public.album_pages (
  key        text primary key,
  title      text not null,
  domain_id  text not null references public.domains(id),
  sort       int  not null
);

create table public.album_cards (
  id        text primary key,
  page_key  text not null references public.album_pages(key) on delete cascade,
  n         int  not null check (n > 0),
  name      text not null,
  rarity    public.card_rarity not null,
  unique (page_key, n)
);
create index on public.album_cards (rarity);

create table public.album_card_concepts (
  card_id     text not null references public.album_cards(id) on delete cascade,
  concept_id  text not null references public.concepts(id) on delete cascade,
  primary key (card_id, concept_id)
);
create index on public.album_card_concepts (concept_id);

-- Habillage : un objet se possède une fois et se pose sur n'importe quelle carte.
-- Identifiants « genre.nom » (cadre.vitrail, finition.or, titre.curieux, dos.soleil, couv.automne, deco.vitrine…).
create table public.album_cosmetics (
  id    text primary key check (id ~ '^(cadre|finition|titre|dos|couv|socle|autoc|titrej|deco)\.[a-z0-9_]+$'),
  name  text not null
);
insert into public.album_cosmetics (id, name) values
  ('cadre.citrouille', 'Cadre Citrouille'), ('cadre.vitrail', 'Cadre Vitrail'), ('cadre.nuit', 'Cadre Nuit étoilée'),
  ('cadre.toile', 'Cadre « Toile d''araignée »'), ('cadre.marbre', 'Cadre Marbre'), ('cadre.anime', 'Cadre animé'),
  ('finition.givre', 'Finition Givre'), ('finition.or', 'Finition Poussière d''or'), ('finition.holo', 'Finition Holographique'),
  ('titre.curieux', 'Titre « Curieux »'), ('titre.erudit', 'Titre « Érudit »'), ('titre.grand_curieux', 'Titre « Grand curieux »'),
  ('titre.chasseur', 'Titre « Chasseur de légendes »'), ('titre.musee', 'Titre « Pièce de musée »'),
  ('dos.classique', 'Dos Classique'), ('dos.soleil', 'Dos Soleil'), ('dos.nuit', 'Dos Nuit étoilée'),
  ('dos.domaines', 'Dos « Les 12 domaines »'), ('dos.or', 'Dos Feuille d''or'), ('dos.citrouille', 'Dos Citrouille'),
  ('couv.classique', 'Couverture Brainlix'), ('couv.automne', 'Couverture « Automne »'), ('couv.grimoire', 'Couverture « Grimoire »'),
  ('couv.or', 'Couverture « Feuille d''or »'),
  ('socle.marbre', 'Socle Marbre'), ('socle.or', 'Socle Or'), ('socle.neon', 'Socle Néon'),
  ('autoc.s1', 'Autocollant « Saison 1 »'), ('autoc.halloween', 'Autocollant « Halloween »'),
  ('titrej.explorateur', 'Titre « Explorateur »'), ('titrej.batisseur', 'Titre « Bâtisseur »');

-- Collection. `slot` 0 : le jeu du joueur ; 1 : la collection à part du mode admin (le jeu normal n'y est jamais mêlé).
create table public.user_cards (
  user_id             uuid not null references public.profiles(id) on delete cascade,
  slot                smallint not null default 0 check (slot in (0, 1)),
  card_id             text not null references public.album_cards(id) on delete cascade,
  copies              int  not null default 1 check (copies >= 1),
  shiny               bool not null default false,
  prestige            bool not null default false,
  -- Admin seulement : Chef-d'œuvre imposé (null : calculé d'après la maîtrise au quiz).
  forced_masterpiece  bool,
  -- États obtenus que le joueur a choisi de ne pas afficher (ils restent gagnés).
  hidden              text[] not null default '{}' check (hidden <@ array['shiny', 'prestige', 'masterpiece']),
  frame               text,
  finish              text,
  title               text,
  first_at            timestamptz not null default now(),
  primary key (user_id, slot, card_id)
);

create table public.user_album (
  user_id              uuid primary key references public.profiles(id) on delete cascade,
  tickets              int  not null default 0 check (tickets >= 0),
  tokens               int  not null default 0 check (tokens >= 0),
  gold_packs           int  not null default 0 check (gold_packs >= 0),
  -- Pochettes ouvertes depuis la dernière légendaire : la 40e en donne une (jamais affiché au joueur).
  packs_since_legend   int  not null default 0,
  gold_week            date,
  back                 text not null default 'classique',
  cover                text not null default 'classique',
  admin                bool not null default false,
  forced_rarity        public.card_rarity,
  created_at           timestamptz not null default now()
);

create table public.user_cosmetics (
  user_id   uuid not null references public.profiles(id) on delete cascade,
  item_id   text not null references public.album_cosmetics(id) on delete cascade,
  source    text not null,
  added_at  timestamptz not null default now(),
  primary key (user_id, item_id)
);

-- Journal des ouvertures (et réponse rejouée si l'app renvoie la même demande).
create table public.album_openings (
  id         uuid primary key,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  slot       smallint not null,
  series     text not null,
  kind       text not null check (kind in ('neurones', 'ticket', 'gold', 'gold_pass')),
  result     jsonb not null,
  created_at timestamptz not null default now()
);
create index on public.album_openings (user_id, created_at desc);

alter table public.album_pages enable row level security;
alter table public.album_cards enable row level security;
alter table public.album_card_concepts enable row level security;
alter table public.album_cosmetics enable row level security;
alter table public.user_cards enable row level security;
alter table public.user_album enable row level security;
alter table public.user_cosmetics enable row level security;
alter table public.album_openings enable row level security;
revoke all on public.album_pages, public.album_cards, public.album_card_concepts, public.album_cosmetics,
              public.user_cards, public.user_album, public.user_cosmetics, public.album_openings
  from public, anon, authenticated;

-- ─────────────────────────────────────────── Règles (D-046)
create or replace function public._album_rule(p_key text) returns int language sql immutable as $$
  select case p_key
    when 'pack_price' then 150
    when 'gold_price' then 900
    when 'pity' then 40
    when 'welcome_tickets' then 3
    when 'stars_days' then 60
    when 'unlimited' then 999999
  end
$$;

create or replace function public._craft_cost(p public.card_rarity) returns int language sql immutable as $$
  select case p when 'common' then 50 when 'rare' then 150 when 'epic' then 400 else 1200 end
$$;

create or replace function public._dup_neurones(p public.card_rarity) returns int language sql immutable as $$
  select case p when 'common' then 5 when 'rare' then 15 when 'epic' then 40 else 100 end
$$;

-- Chances par carte : légendaire 1,5 %, épique 6,5 %, rare 22 %, commune 70 %.
create or replace function public._roll_rarity() returns public.card_rarity language plpgsql volatile as $$
declare r float8 := random() * 100;
begin
  if r < 1.5 then return 'legend'; end if;
  if r < 8 then return 'epic'; end if;
  if r < 30 then return 'rare'; end if;
  return 'common';
end $$;

-- Fiche album du joueur (créée à la première visite, avec les pochettes de bienvenue et l'habillage de départ).
create or replace function public._album_row(p_user uuid) returns public.user_album
language plpgsql as $$
declare r public.user_album;
begin
  select * into r from public.user_album where user_id = p_user for update;
  if found then return r; end if;
  insert into public.user_album (user_id, tickets) values (p_user, public._album_rule('welcome_tickets'))
  on conflict (user_id) do nothing;
  insert into public.user_cosmetics (user_id, item_id, source) values
    (p_user, 'dos.classique', 'start'), (p_user, 'couv.classique', 'start')
  on conflict do nothing;
  select * into r from public.user_album where user_id = p_user for update;
  return r;
end $$;

create or replace function public._album_can_admin(p_user uuid) returns bool language sql stable as $$
  select exists (select 1 from public.app_admins where user_id = p_user)
$$;

create or replace function public._album_slot(r public.user_album) returns smallint language sql immutable as $$
  select case when r.admin then 1 else 0 end::smallint
$$;

create or replace function public._album_has(p_user uuid, p_admin bool, p_item text) returns bool language sql stable as $$
  select p_admin and exists (select 1 from public.album_cosmetics where id = p_item)
      or exists (select 1 from public.user_cosmetics where user_id = p_user and item_id = p_item)
$$;

-- Étoiles de maîtrise : 1 = une notion de la carte réussie ; 2 = la moitié ; 3 = toutes (Chef-d'œuvre).
-- Seules comptent les réponses des 60 derniers jours : les étoiles pâlissent sans révision et se ravivent en rejouant.
create or replace function public._album_stars(p_user uuid)
returns table (card_id text, stars int) language sql stable as $$
  with total as (select acc.card_id, count(*) as n from public.album_card_concepts acc group by acc.card_id),
  done as (
    select acc.card_id, count(distinct qa.concept_id) as k
    from public.question_attempts qa
    join public.album_card_concepts acc on acc.concept_id = qa.concept_id
    where qa.user_id = p_user and qa.is_correct
      and qa.created_at >= public._now() - make_interval(days => public._album_rule('stars_days'))
    group by acc.card_id)
  select t.card_id,
         case when d.k is null then 0 when d.k >= t.n then 3 when d.k * 2 >= t.n then 2 else 1 end
  from total t left join done d on d.card_id = t.card_id
$$;

-- Une carte reçue : nouvelle ; le premier doublon la rend brillante ; ensuite des neurones (pochette).
create or replace function public._album_receive(p_user uuid, p_slot smallint, p_card text, p_key text) returns jsonb
language plpgsql as $$
declare
  c public.user_cards;
  v_rarity public.card_rarity;
  v_gain int;
begin
  select rarity into v_rarity from public.album_cards where id = p_card;
  select * into c from public.user_cards where user_id = p_user and slot = p_slot and card_id = p_card for update;
  if not found then
    insert into public.user_cards (user_id, slot, card_id, first_at) values (p_user, p_slot, p_card, public._now());
    return jsonb_build_object('card', p_card, 'rarity', v_rarity, 'outcome', 'new');
  end if;
  update public.user_cards set copies = copies + 1, shiny = true where user_id = p_user and slot = p_slot and card_id = p_card;
  if not c.shiny then
    return jsonb_build_object('card', p_card, 'rarity', v_rarity, 'outcome', 'shiny');
  end if;
  v_gain := public._dup_neurones(v_rarity);
  -- Le mode admin ne touche jamais au vrai solde.
  if p_slot = 0 then perform public._grant(p_user, 'seeds', v_gain, 'album_duplicate', p_card, p_key); end if;
  return jsonb_build_object('card', p_card, 'rarity', v_rarity, 'outcome', 'neurones', 'neurones', v_gain);
end $$;

-- Tirage de 5 cartes : au moins une rare, une légendaire si pochette dorée ou à la 40e sans légendaire, rareté imposée
-- par l'admin ; cartes de la série choisie (Encyclopédie : tout l'album), jamais deux fois la même dans une pochette.
create or replace function public._album_draw(p_user uuid, r public.user_album, p_series text, p_gold bool, p_id uuid)
returns jsonb language plpgsql as $$
declare
  v_slot smallint := public._album_slot(r);
  v_rarities public.card_rarity[] := array[public._roll_rarity(), public._roll_rarity(), public._roll_rarity(),
                                           public._roll_rarity(), public._roll_rarity()];
  v_picked text[] := '{}';
  v_pulls jsonb := '[]'::jsonb;
  v_card text;
  v_since int;
  i int;
begin
  if not v_rarities && array['rare', 'epic', 'legend']::public.card_rarity[] then v_rarities[5] := 'rare'; end if;
  select array_agg(x order by x) into v_rarities from unnest(v_rarities) x;
  if p_gold and not 'legend' = any(v_rarities) then v_rarities[5] := 'legend'; end if;
  v_since := r.packs_since_legend + 1;
  if 'legend' = any(v_rarities) then v_since := 0;
  elsif v_since >= public._album_rule('pity') then v_rarities[5] := 'legend'; v_since := 0;
  end if;
  if r.forced_rarity is not null then v_rarities[5] := r.forced_rarity; end if;
  select array_agg(x order by x) into v_rarities from unnest(v_rarities) x;
  update public.user_album set packs_since_legend = case when r.admin then packs_since_legend else v_since end,
                               forced_rarity = null
  where user_id = p_user;
  for i in 1..5 loop
    select c.id into v_card from public.album_cards c join public.album_pages p on p.key = c.page_key
    where c.rarity = v_rarities[i] and (p_series = 'encyclo' or p.domain_id = p_series) and c.id <> all(v_picked)
    order by random() limit 1;
    if v_card is null then
      select c.id into v_card from public.album_cards c
      where c.rarity = v_rarities[i] and c.id <> all(v_picked) order by random() limit 1;
    end if;
    v_picked := v_picked || v_card;
    v_pulls := v_pulls || public._album_receive(p_user, v_slot, v_card, 'album_dup:' || p_id || ':' || i);
  end loop;
  return v_pulls;
end $$;

-- ─────────────────────────────────────────── API de l'app
-- Vue d'ensemble : soldes, habillage, cartes possédées avec leurs états et leurs étoiles.
create or replace function public.album_overview() returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  r public.user_album := public._album_row(v_user);
  v_slot smallint := public._album_slot(r);
  v_unlimited int := public._album_rule('unlimited');
begin
  return jsonb_build_object(
    'admin', r.admin,
    'can_admin', public._album_can_admin(v_user),
    'neurones', case when r.admin then v_unlimited else (select seeds from public.profiles where id = v_user) end,
    'tickets', case when r.admin then v_unlimited else r.tickets end,
    'tokens', case when r.admin then v_unlimited else r.tokens end,
    'gold_packs', case when r.admin then v_unlimited else r.gold_packs end,
    'gold_available', r.admin or r.gold_week is null or r.gold_week < public._user_week_start(v_user),
    'forced_rarity', r.forced_rarity,
    'back', r.back,
    'cover', r.cover,
    'cosmetics', case when r.admin then (select coalesce(jsonb_agg(id order by id), '[]') from public.album_cosmetics)
                      else (select coalesce(jsonb_agg(item_id order by item_id), '[]') from public.user_cosmetics where user_id = v_user) end,
    'cards', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'id', c.card_id, 'copies', c.copies, 'shiny', c.shiny, 'prestige', c.prestige,
               'masterpiece', coalesce(c.forced_masterpiece, s.stars = 3), 'stars', coalesce(s.stars, 0),
               'hidden', to_jsonb(c.hidden), 'frame', c.frame, 'finish', c.finish, 'title', c.title) order by c.card_id), '[]')
      from public.user_cards c left join public._album_stars(v_user) s on s.card_id = c.card_id
      where c.user_id = v_user and c.slot = v_slot));
end $$;

-- Ouvre une pochette. p_pay : 'neurones' (150), 'ticket', 'gold' (900, une par semaine, une légendaire garantie),
-- 'gold_pass' (pochette dorée gagnée dans le pass). p_client_id : la même demande renvoyée ne compte qu'une fois.
create or replace function public.album_open_pack(p_series text, p_pay text, p_client_id uuid default gen_random_uuid())
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  r public.user_album;
  v_done jsonb;
  v_gold bool := p_pay in ('gold', 'gold_pass');
  v_pulls jsonb;
  v_result jsonb;
begin
  if p_pay not in ('neurones', 'ticket', 'gold', 'gold_pass') then raise exception 'invalid_payment'; end if;
  if p_series <> 'encyclo' and not exists (select 1 from public.album_pages where domain_id = p_series) then
    raise exception 'invalid_series';
  end if;
  if v_gold and p_series <> 'encyclo' then raise exception 'invalid_series'; end if;
  perform 1 from public.profiles where id = v_user for update;
  r := public._album_row(v_user);
  select result into v_done from public.album_openings where id = p_client_id and user_id = v_user;
  if found then return v_done; end if;
  if not r.admin then
    case p_pay
      when 'neurones' then
        if (select seeds from public.profiles where id = v_user) < public._album_rule('pack_price') then raise exception 'insufficient_seeds'; end if;
        perform public._grant(v_user, 'seeds', -public._album_rule('pack_price'), 'album_pack', p_series, 'album_pack:' || p_client_id);
      when 'ticket' then
        if r.tickets < 1 then raise exception 'no_ticket'; end if;
        update public.user_album set tickets = tickets - 1 where user_id = v_user;
      when 'gold' then
        if r.gold_week is not null and r.gold_week >= public._user_week_start(v_user) then raise exception 'gold_weekly_limit'; end if;
        if (select seeds from public.profiles where id = v_user) < public._album_rule('gold_price') then raise exception 'insufficient_seeds'; end if;
        perform public._grant(v_user, 'seeds', -public._album_rule('gold_price'), 'album_gold', null, 'album_gold:' || p_client_id);
        update public.user_album set gold_week = public._user_week_start(v_user) where user_id = v_user;
      else
        if r.gold_packs < 1 then raise exception 'no_gold_pack'; end if;
        update public.user_album set gold_packs = gold_packs - 1 where user_id = v_user;
    end case;
  end if;
  v_pulls := public._album_draw(v_user, r, p_series, v_gold, p_client_id);
  v_result := jsonb_build_object('id', p_client_id, 'series', p_series, 'gold', v_gold, 'pulls', v_pulls,
                                 'balance', (select seeds from public.profiles where id = v_user));
  insert into public.album_openings (id, user_id, slot, series, kind, result)
  values (p_client_id, v_user, public._album_slot(r), p_series, p_pay, v_result);
  return v_result;
end $$;

-- Fabrique une carte manquante (50 / 150 / 400 / 1 200 neurones).
create or replace function public.album_craft(p_card text) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  r public.user_album;
  v_rarity public.card_rarity;
  v_cost int;
begin
  select rarity into v_rarity from public.album_cards where id = p_card;
  if not found then raise exception 'invalid_card'; end if;
  perform 1 from public.profiles where id = v_user for update;
  r := public._album_row(v_user);
  if exists (select 1 from public.user_cards where user_id = v_user and slot = public._album_slot(r) and card_id = p_card) then
    raise exception 'card_owned';
  end if;
  v_cost := public._craft_cost(v_rarity);
  if not r.admin then
    if (select seeds from public.profiles where id = v_user) < v_cost then raise exception 'insufficient_seeds'; end if;
    perform public._grant(v_user, 'seeds', -v_cost, 'album_craft', p_card, 'album_craft:' || p_card);
  end if;
  insert into public.user_cards (user_id, slot, card_id, first_at) values (v_user, public._album_slot(r), p_card, public._now());
  return jsonb_build_object('card', p_card, 'cost', v_cost, 'balance', (select seeds from public.profiles where id = v_user));
end $$;

-- Pose un jeton Prestige sur une carte possédée : définitif.
create or replace function public.album_prestige(p_card text) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  r public.user_album := public._album_row(v_user);
  c public.user_cards;
begin
  select * into c from public.user_cards where user_id = v_user and slot = public._album_slot(r) and card_id = p_card for update;
  if not found then raise exception 'card_not_owned'; end if;
  if c.prestige then raise exception 'already_prestige'; end if;
  if not r.admin then
    if r.tokens < 1 then raise exception 'no_token'; end if;
    update public.user_album set tokens = tokens - 1 where user_id = v_user;
  end if;
  update public.user_cards set prestige = true, hidden = array_remove(hidden, 'prestige')
  where user_id = v_user and slot = c.slot and card_id = p_card;
  return jsonb_build_object('card', p_card, 'tokens', case when r.admin then public._album_rule('unlimited') else r.tokens - 1 end);
end $$;

-- Affiche ou masque un état obtenu (il reste gagné ; le jeton Prestige n'est pas rendu).
create or replace function public.album_set_hidden(p_card text, p_state text, p_hidden bool) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  r public.user_album := public._album_row(v_user);
begin
  if p_state not in ('shiny', 'prestige', 'masterpiece') then raise exception 'invalid_state'; end if;
  update public.user_cards
  set hidden = case when p_hidden then array_append(array_remove(hidden, p_state), p_state) else array_remove(hidden, p_state) end
  where user_id = v_user and slot = public._album_slot(r) and card_id = p_card;
  if not found then raise exception 'card_not_owned'; end if;
end $$;

-- Habillage d'une carte : cadre, finition, titre (null : aucun). Seulement ce que le joueur possède.
create or replace function public.album_dress(p_card text, p_frame text, p_finish text, p_title text) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  r public.user_album := public._album_row(v_user);
begin
  if p_frame is not null and not public._album_has(v_user, r.admin, 'cadre.' || p_frame)
     or p_finish is not null and not public._album_has(v_user, r.admin, 'finition.' || p_finish)
     or p_title is not null and not public._album_has(v_user, r.admin, 'titre.' || p_title) then
    raise exception 'item_not_owned';
  end if;
  update public.user_cards set frame = p_frame, finish = p_finish, title = p_title
  where user_id = v_user and slot = public._album_slot(r) and card_id = p_card;
  if not found then raise exception 'card_not_owned'; end if;
end $$;

-- Dos des cartes et couverture de l'album.
create or replace function public.album_set_look(p_back text, p_cover text) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  r public.user_album := public._album_row(v_user);
begin
  if p_back is not null and not public._album_has(v_user, r.admin, 'dos.' || p_back)
     or p_cover is not null and not public._album_has(v_user, r.admin, 'couv.' || p_cover) then
    raise exception 'item_not_owned';
  end if;
  update public.user_album set back = coalesce(p_back, back), cover = coalesce(p_cover, cover) where user_id = v_user
  returning * into r;
  return jsonb_build_object('back', r.back, 'cover', r.cover);
end $$;

-- ─────────────────────────────────────────── Mode admin (administrateurs seulement)
-- Active ou quitte le mode admin : collection à part, tout illimité. En le quittant, on retrouve son jeu tel quel.
create or replace function public.album_admin(p_on bool) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user();
begin
  if not public._album_can_admin(v_user) then raise exception 'forbidden' using errcode = '42501'; end if;
  perform public._album_row(v_user);
  update public.user_album set admin = p_on, forced_rarity = null where user_id = v_user;
  return public.album_overview();
end $$;

-- Outils admin : 'own_all', 'own_all_shiny', 'empty', 'force' (p_arg = rareté de la prochaine pochette).
create or replace function public.album_admin_tool(p_tool text, p_arg text default null) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  r public.user_album := public._album_row(v_user);
begin
  if not r.admin then raise exception 'forbidden' using errcode = '42501'; end if;
  case p_tool
    when 'own_all', 'own_all_shiny' then
      insert into public.user_cards (user_id, slot, card_id, shiny)
      select v_user, 1, c.id, p_tool = 'own_all_shiny' from public.album_cards c
      on conflict (user_id, slot, card_id) do update set shiny = user_cards.shiny or excluded.shiny;
    when 'empty' then
      delete from public.user_cards where user_id = v_user and slot = 1;
    when 'force' then
      update public.user_album set forced_rarity = p_arg::public.card_rarity where user_id = v_user;
    else raise exception 'invalid_tool';
  end case;
  return public.album_overview();
end $$;

-- Admin : poser ou retirer un état librement (brillante, Prestige, Chef-d'œuvre), sans jeton ni condition.
create or replace function public.album_admin_state(p_card text, p_state text, p_on bool) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  r public.user_album := public._album_row(v_user);
begin
  if not r.admin then raise exception 'forbidden' using errcode = '42501'; end if;
  update public.user_cards set
    shiny = case when p_state = 'shiny' then p_on else shiny end,
    prestige = case when p_state = 'prestige' then p_on else prestige end,
    forced_masterpiece = case when p_state = 'masterpiece' then p_on else forced_masterpiece end,
    hidden = array_remove(hidden, p_state)
  where user_id = v_user and slot = 1 and card_id = p_card;
  if not found then raise exception 'card_not_owned'; end if;
end $$;

-- Le propriétaire (pseudo du compte de test) devient administrateur de l'album s'il existe déjà sur ce serveur.
insert into public.app_admins (user_id)
select p.id from public.profiles p where lower(p.handle) = 'rudyc14ezz'
on conflict do nothing;

-- ─────────────────────────────────────────── Droits
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and p.proname in ('_album_rule', '_craft_cost', '_dup_neurones', '_roll_rarity', '_album_row', '_album_can_admin',
                        '_album_slot', '_album_has', '_album_stars', '_album_receive', '_album_draw')
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', f.sig);
    execute format('alter function %s set search_path = public, pg_temp', f.sig);
  end loop;
end $$;

do $$
declare f text;
begin
  foreach f in array array[
    'album_overview()', 'album_open_pack(text,text,uuid)', 'album_craft(text)', 'album_prestige(text)',
    'album_set_hidden(text,text,bool)', 'album_dress(text,text,text,text)', 'album_set_look(text,text)',
    'album_admin(bool)', 'album_admin_tool(text,text)', 'album_admin_state(text,text,bool)'
  ] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
