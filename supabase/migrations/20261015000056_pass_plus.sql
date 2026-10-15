-- ─────────────────────────────────────────── 0056 · Pass+ : plus de pub + piste payante du pass (propriétaire, 15/10)
-- Achat intégré Apple (3,99 €, une saison). Le Pass+ donne, pour toute la saison où il est acheté :
--   · plus aucune pub : pas de pub plein écran, et les récompenses « bonus » (pochette gratuite, neurones doublés,
--     coffre offert, « Corrige tes erreurs », série sauvée) sont données sans vidéo, avec les mêmes limites par jour ;
--   · la piste payante du pass (30 paliers), récupérable d'un coup pour les paliers déjà atteints (rattrapage).
-- L'achat est vérifié par la fonction Edge `iap-verify` (transaction signée par Apple), qui appelle `pass_plus_record`
-- avec la clé de service. Un remboursement (notification d'Apple) retire le Pass+ (`pass_plus_revoke`).
-- Nouvelle récompense « coffret de catégorie » : le joueur choisit un domaine parmi ceux proposés et voit les 3 cartes
-- avant d'ouvrir (au plus une épique, jamais de légendaire) ; un doublon devient brillant, une carte déjà brillante
-- ne donne rien (affiché).

-- ─────────────────────────────────────────── Saisons : vente du Pass+
alter table public.seasons add column pass_plus bool not null default false;

create table public.season_passes (
  transaction_id          text primary key,
  original_transaction_id text,
  user_id                 uuid not null references public.profiles(id) on delete cascade,
  season_id               int  not null references public.seasons(id) on delete cascade,
  product_id              text not null,
  environment             text not null check (environment in ('Production', 'Sandbox', 'Xcode', 'LocalTesting')),
  purchased_at            timestamptz not null,
  recorded_at             timestamptz not null default now(),
  revoked_at              timestamptz
);
create index on public.season_passes (user_id, season_id) where revoked_at is null;
alter table public.season_passes enable row level security;
revoke all on public.season_passes from public, anon, authenticated;

-- Pass+ actif pour la saison en cours.
create or replace function public._has_pass(p_user uuid) returns bool language sql stable as $$
  select exists (select 1 from public.season_passes sp
                 where sp.user_id = p_user and sp.revoked_at is null and sp.season_id = (public._season_current()).id)
$$;

-- ─────────────────────────────────────────── Pistes gratuite et payante
alter table public.season_rewards drop constraint season_rewards_kind_check;
alter table public.season_rewards add constraint season_rewards_kind_check
  check (kind in ('chest', 'ticket', 'token', 'cosmetic', 'final', 'perk', 'coffret'));
alter table public.season_rewards add column track text not null default 'free' check (track in ('free', 'paid'));
alter table public.season_rewards drop constraint season_rewards_pkey;
alter table public.season_rewards add primary key (season_id, track, tier);

alter table public.season_claims add column track text not null default 'free' check (track in ('free', 'paid'));
alter table public.season_claims drop constraint season_claims_pkey;
alter table public.season_claims add primary key (user_id, season_id, track, tier);

-- ─────────────────────────────────────────── Coffrets de catégorie
create table public.user_coffrets (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  source      text not null,
  -- Domaine → les 3 cartes proposées (tirées à l'obtention : ce qu'on voit est ce qu'on aura).
  offers      jsonb not null,
  domain      text,
  result      jsonb,
  created_at  timestamptz not null default now(),
  opened_at   timestamptz,
  idempotency_key text unique
);
create index on public.user_coffrets (user_id) where opened_at is null;
alter table public.user_coffrets enable row level security;
revoke all on public.user_coffrets from public, anon, authenticated;

-- 3 cartes par domaine : une commune, une rare, une rare ou épique (3 chances sur 10) ; jamais de légendaire.
-- Les cartes que le joueur n'a pas encore passent en premier.
create or replace function public._coffret_offers(p_user uuid) returns jsonb language plpgsql volatile as $$
declare
  v_offers jsonb := '{}'::jsonb;
  v_domain text;
  v_cards text[];
  v_card text;
  v_rarity public.card_rarity;
begin
  for v_domain in select distinct domain_id from public.album_pages where domain_id is not null order by 1 loop
    v_cards := '{}';
    foreach v_rarity in array array['common', 'rare',
                                    case when random() < 0.3 then 'epic' else 'rare' end]::public.card_rarity[] loop
      select c.id into v_card from public.album_cards c join public.album_pages p on p.key = c.page_key
      where p.domain_id = v_domain and c.rarity = v_rarity and c.id <> all(v_cards)
      order by exists (select 1 from public.user_cards uc where uc.user_id = p_user and uc.slot = 0 and uc.card_id = c.id),
               random()
      limit 1;
      if v_card is not null then v_cards := v_cards || v_card; end if;
    end loop;
    if cardinality(v_cards) = 3 then v_offers := v_offers || jsonb_build_object(v_domain, to_jsonb(v_cards)); end if;
  end loop;
  return v_offers;
end $$;

create or replace function public._give_coffret(p_user uuid, p_source text, p_key text) returns uuid language plpgsql as $$
declare v_id uuid;
begin
  insert into public.user_coffrets (user_id, source, offers, created_at, idempotency_key)
  values (p_user, p_source, public._coffret_offers(p_user), public._now(), p_key)
  on conflict (idempotency_key) do nothing
  returning id into v_id;
  return v_id;
end $$;

-- Ouvre un coffret sur le domaine choisi.
create or replace function public.album_open_coffret(p_coffret uuid, p_domain text) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  r public.user_album;
  x public.user_coffrets;
  v_slot smallint;
  v_card text;
  v_rarity public.card_rarity;
  c public.user_cards;
  v_pulls jsonb := '[]'::jsonb;
  v_result jsonb;
begin
  perform 1 from public.profiles where id = v_user for update;
  r := public._album_row(v_user);
  v_slot := public._album_slot(r);
  select * into x from public.user_coffrets where id = p_coffret and user_id = v_user for update;
  if not found then raise exception 'coffret_not_found'; end if;
  if x.opened_at is not null then
    if x.domain = p_domain then return x.result; end if;  -- même demande renvoyée
    raise exception 'coffret_opened';
  end if;
  if not x.offers ? p_domain then raise exception 'invalid_series'; end if;
  for v_card in select jsonb_array_elements_text(x.offers -> p_domain) loop
    select rarity into v_rarity from public.album_cards where id = v_card;
    select * into c from public.user_cards where user_id = v_user and slot = v_slot and card_id = v_card for update;
    if not found then
      insert into public.user_cards (user_id, slot, card_id, first_at) values (v_user, v_slot, v_card, public._now());
      v_pulls := v_pulls || jsonb_build_object('card', v_card, 'rarity', v_rarity, 'outcome', 'new');
    elsif not c.shiny then
      update public.user_cards set copies = copies + 1, shiny = true where user_id = v_user and slot = v_slot and card_id = v_card;
      v_pulls := v_pulls || jsonb_build_object('card', v_card, 'rarity', v_rarity, 'outcome', 'shiny');
    else
      v_pulls := v_pulls || jsonb_build_object('card', v_card, 'rarity', v_rarity, 'outcome', 'nothing');
    end if;
  end loop;
  v_result := jsonb_build_object('id', p_coffret, 'series', p_domain, 'gold', false, 'pulls', v_pulls,
                                 'balance', (select seeds from public.profiles where id = v_user));
  update public.user_coffrets set opened_at = public._now(), domain = p_domain, result = v_result where id = p_coffret;
  return v_result;
end $$;

-- Coffrets à ouvrir, dans la vue de l'album.
do $$
declare v_old text; v_new text;
begin
  v_old := pg_get_functiondef('public.album_overview()'::regprocedure);
  v_new := replace(v_old, '    ''cards'', (',
    '    ''coffrets'', (select coalesce(jsonb_agg(jsonb_build_object(''id'', x.id, ''offers'', x.offers) order by x.created_at), ''[]'')
                   from public.user_coffrets x where x.user_id = v_user and x.opened_at is null),
    ''cards'', (');
  if v_new = v_old then raise exception '0056: album_overview inchangée'; end if;
  execute v_new;
end $$;

-- ─────────────────────────────────────────── Récompenses de palier (les deux pistes)
create or replace function public._season_give(p_user uuid, rw public.season_rewards) returns void language plpgsql as $$
declare
  v_key text := 'season:' || rw.season_id || ':' || case when rw.track = 'paid' then 'p' else '' end || rw.tier;
  v_item text;
  i int;
begin
  perform public._album_row(p_user);
  case rw.kind
    when 'chest' then
      for i in 1..rw.qty loop
        perform public._give_chest(p_user, rw.item::public.chest_tier, 'season', rw.tier::text, v_key || ':' || i);
      end loop;
    when 'ticket' then update public.user_album set tickets = tickets + rw.qty where user_id = p_user;
    when 'token' then update public.user_album set tokens = tokens + rw.qty where user_id = p_user;
    when 'cosmetic' then
      -- Plusieurs objets possibles (« dos.or,cadre.anime »).
      foreach v_item in array string_to_array(rw.item, ',') loop
        insert into public.user_cosmetics (user_id, item_id, source) values (p_user, v_item, 'season') on conflict do nothing;
      end loop;
    when 'final' then
      insert into public.user_cosmetics (user_id, item_id, source) values (p_user, rw.item, 'season') on conflict do nothing;
      update public.user_album set gold_packs = gold_packs + 1 where user_id = p_user;
    when 'coffret' then
      for i in 1..rw.qty loop perform public._give_coffret(p_user, 'season', v_key || ':' || i); end loop;
    when 'perk' then null;  -- « Plus de pub » : actif dès l'achat, le palier ne fait que l'afficher.
  end case;
end $$;

-- Un palier : contrôles communs aux deux pistes.
create or replace function public._season_claim_one(p_user uuid, s public.seasons, p_track text, p_tier int, p_points int)
returns jsonb language plpgsql as $$
declare rw public.season_rewards;
begin
  select * into rw from public.season_rewards where season_id = s.id and track = p_track and tier = p_tier;
  if not found then raise exception 'invalid_tier'; end if;
  if p_track = 'paid' and not public._has_pass(p_user) then raise exception 'pass_required'; end if;
  if p_points < p_tier * public._season_rule('tier_points') then raise exception 'tier_not_reached'; end if;
  insert into public.season_claims (user_id, season_id, track, tier, claimed_at) values (p_user, s.id, p_track, p_tier, public._now())
  on conflict do nothing;
  if not found then raise exception 'already_claimed'; end if;
  perform public._season_give(p_user, rw);
  return jsonb_build_object('tier', p_tier, 'track', p_track, 'kind', rw.kind, 'label', rw.label, 'icon', rw.icon);
end $$;

drop function public.season_claim(int);
create or replace function public.season_claim(p_tier int, p_track text default 'free') returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  s public.seasons := public._season_current();
begin
  if s.id is null then raise exception 'no_season'; end if;
  if p_track not in ('free', 'paid') then raise exception 'invalid_tier'; end if;
  perform 1 from public.profiles where id = v_user for update;
  return public._season_claim_one(v_user, s, p_track, p_tier, public._season_points(v_user, s));
end $$;

-- Rattrapage : récupère d'un coup tous les paliers atteints et pas encore pris d'une piste.
create or replace function public.season_claim_all(p_track text default 'paid') returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  s public.seasons := public._season_current();
  v_points int;
  v_list jsonb := '[]'::jsonb;
  t int;
begin
  if s.id is null then raise exception 'no_season'; end if;
  if p_track not in ('free', 'paid') then raise exception 'invalid_tier'; end if;
  if p_track = 'paid' and not public._has_pass(v_user) then raise exception 'pass_required'; end if;
  perform 1 from public.profiles where id = v_user for update;
  v_points := public._season_points(v_user, s);
  for t in select rw.tier from public.season_rewards rw
           where rw.season_id = s.id and rw.track = p_track
             and rw.tier * public._season_rule('tier_points') <= v_points
             and not exists (select 1 from public.season_claims c where c.user_id = v_user and c.season_id = s.id
                             and c.track = p_track and c.tier = rw.tier)
           order by rw.tier loop
    v_list := v_list || public._season_claim_one(v_user, s, p_track, t, v_points);
  end loop;
  return jsonb_build_object('claimed', v_list);
end $$;

-- Coffres en bois après le palier 30 : piste gratuite seulement.
do $$
declare v_old text; v_new text;
begin
  v_old := pg_get_functiondef('public.season_claim_extra()'::regprocedure);
  v_new := replace(replace(v_old,
    'where user_id = v_user and season_id = s.id and tier > 30;',
    'where user_id = v_user and season_id = s.id and track = ''free'' and tier > 30;'),
    'insert into public.season_claims (user_id, season_id, tier, claimed_at) values (v_user, s.id, 30 + i, public._now());',
    'insert into public.season_claims (user_id, season_id, track, tier, claimed_at) values (v_user, s.id, ''free'', 30 + i, public._now());');
  if v_new not like '%track = ''free'' and tier > 30%' or v_new not like '%''free'', 30 + i%' then
    raise exception '0056: season_claim_extra inchangée';
  end if;
  execute v_new;
end $$;

-- Vue du pass : piste gratuite (comme avant), piste payante et état du Pass+.
create or replace function public.season_overview() returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  s public.seasons := public._season_current();
  v_points int;
  v_tier int;
  v_extra int;
begin
  if s.id is null then return jsonb_build_object('season', null); end if;
  v_points := public._season_points(v_user, s);
  v_tier := least(v_points / public._season_rule('tier_points'), public._season_rule('tiers'));
  v_extra := least(greatest(v_points / public._season_rule('tier_points') - public._season_rule('tiers'), 0), public._season_rule('extra_chests'));
  return jsonb_build_object(
    'season', jsonb_build_object('id', s.id, 'name', s.name, 'starts_on', s.starts_on, 'ends_on', s.ends_on),
    'points', v_points,
    'tier', v_tier,
    'tier_points', public._season_rule('tier_points'),
    'tiers', public._season_rule('tiers'),
    'rewards', (select coalesce(jsonb_agg(jsonb_build_object('tier', rw.tier, 'kind', rw.kind, 'label', rw.label, 'icon', rw.icon,
                  'claimed', exists (select 1 from public.season_claims c where c.user_id = v_user and c.season_id = s.id
                                     and c.track = 'free' and c.tier = rw.tier))
                  order by rw.tier), '[]') from public.season_rewards rw where rw.season_id = s.id and rw.track = 'free'),
    'extra_chests', jsonb_build_object('earned', v_extra,
                    'claimed', (select count(*) from public.season_claims c where c.user_id = v_user and c.season_id = s.id
                                and c.track = 'free' and c.tier > 30)),
    'points_rules', jsonb_build_object('day', public._season_rule('day'), 'day_bonus', public._season_rule('day_bonus'),
                    'week', public._season_rule('week'), 'week_bonus', public._season_rule('week_bonus'), 'mission', public._season_rule('mission')),
    'missions', (select coalesce(jsonb_agg(jsonb_build_object('slot', m.slot, 'label', m.label, 'progress', m.progress,
                  'target', m.target, 'done', m.progress >= m.target) order by m.slot), '[]') from public._season_missions(v_user, s) m),
    'pass_plus', jsonb_build_object(
      'on_sale', s.pass_plus,
      'active', public._has_pass(v_user),
      'rewards', (select coalesce(jsonb_agg(jsonb_build_object('tier', rw.tier, 'kind', rw.kind, 'label', rw.label, 'icon', rw.icon,
                    'claimed', rw.kind = 'perk' and public._has_pass(v_user)
                               or exists (select 1 from public.season_claims c where c.user_id = v_user and c.season_id = s.id
                                          and c.track = 'paid' and c.tier = rw.tier))
                    order by rw.tier), '[]') from public.season_rewards rw where rw.season_id = s.id and rw.track = 'paid')));
end $$;

-- ─────────────────────────────────────────── Plus de pub
-- Joueur Pass+ : la récompense « bonus » est donnée sans vue de pub. Elle est notée dans ad_views (ad_unit « pass_plus »,
-- `test` vrai pour ne pas compter comme une vraie pub dans l'admin) : les limites par jour restent les mêmes.
do $$
declare v_old text; v_new text;
begin
  v_old := pg_get_functiondef('public._ad_take(uuid, text, text, boolean)'::regprocedure);
  v_new := replace(v_old, '  if v_tx is null then
    if coalesce(p_test, false)',
    '  if v_tx is null and public._has_pass(p_user) then
    v_tx := ''pass:'' || gen_random_uuid();
    insert into public.ad_views (transaction_id, user_id, ad_unit, kind, ref, test, created_at)
    values (v_tx, p_user, ''pass_plus'', p_kind, coalesce(p_ref, ''''), true, public._now());
  end if;
  if v_tx is null then
    if coalesce(p_test, false)');
  if v_new = v_old then raise exception '0056: _ad_take inchangée'; end if;
  execute v_new;

  v_old := pg_get_functiondef('public.ad_status()'::regprocedure);
  v_new := replace(v_old, '''interstitial'', p.created_at <= public._now() - interval ''3 days'',',
    '''interstitial'', p.created_at <= public._now() - interval ''3 days'' and not public._has_pass(v_user),
    ''pass_plus'', public._has_pass(v_user),');
  if v_new = v_old then raise exception '0056: ad_status inchangée'; end if;
  execute v_new;
end $$;

-- ─────────────────────────────────────────── Achats (fonction Edge iap-verify, clé de service)
-- Enregistre un achat vérifié. Idempotent par transaction. Renvoie la saison couverte.
create or replace function public.pass_plus_record(p_user uuid, p_transaction text, p_original text, p_product text,
                                                   p_environment text, p_purchased_at timestamptz)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_season int;
  sp public.season_passes;
begin
  select * into sp from public.season_passes where transaction_id = p_transaction;
  if found then
    if sp.user_id <> p_user then raise exception 'transaction_other_user'; end if;
    return jsonb_build_object('season_id', sp.season_id, 'active', sp.revoked_at is null, 'recorded', false);
  end if;
  if not exists (select 1 from public.profiles where id = p_user) then raise exception 'user_not_found'; end if;
  -- La saison de la date d'achat (un vieil achat restauré plus tard ne donne pas la saison suivante).
  select s.id into v_season from public.seasons s
  where s.pass_plus and (p_purchased_at at time zone 'UTC')::date >= s.starts_on and (p_purchased_at at time zone 'UTC')::date < s.ends_on;
  -- Achats de test (TestFlight, examen d'Apple) : acceptés hors période de vente, sur la saison en cours.
  if v_season is null and p_environment <> 'Production' then v_season := (public._season_current()).id; end if;
  if v_season is null then raise exception 'pass_not_on_sale'; end if;
  insert into public.season_passes (transaction_id, original_transaction_id, user_id, season_id, product_id, environment, purchased_at, recorded_at)
  values (p_transaction, p_original, p_user, v_season, p_product, p_environment, p_purchased_at, public._now());
  return jsonb_build_object('season_id', v_season, 'active', true, 'recorded', true);
end $$;

-- Remboursement ou annulation signalés par Apple : le Pass+ est retiré.
create or replace function public.pass_plus_revoke(p_transaction text) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  update public.season_passes set revoked_at = coalesce(revoked_at, public._now())
  where transaction_id = p_transaction or original_transaction_id = p_transaction;
  return jsonb_build_object('revoked', found);
end $$;

-- ─────────────────────────────────────────── Saison 2 : hiver (3 janvier → 28 mars 2027), première avec le Pass+
insert into public.album_cosmetics (id, name) values
  ('autoc.s2', 'Autocollant « Saison 2 »'), ('titre.polaire', 'Titre « Esprit polaire »'), ('cadre.flocons', 'Cadre Flocons'),
  ('dos.hiver', 'Dos « Nuit d''hiver »'), ('titrej.givre', 'Titre « Givré du savoir »'), ('socle.glace', 'Socle Glace'),
  ('autoc.bonhomme', 'Autocollant « Bonhomme de neige »'), ('titre.flocon', 'Titre « Flocon savant »'),
  ('titrej.banquise', 'Titre « Explorateur polaire »'), ('couv.hiver', 'Couverture « Hiver »'), ('dos.aurore', 'Dos Aurore boréale'),
  ('autoc.fondateur', 'Autocollant « Fondateur »'), ('titrej.savant', 'Titre « Savant »'), ('autoc.flocon', 'Autocollant « Flocon »'),
  ('cadre.aurore', 'Cadre Aurore'), ('titrej.legende', 'Titre « Légende vivante »'), ('autoc.yeti', 'Autocollant « Yéti »')
on conflict (id) do nothing;

insert into public.seasons (id, name, starts_on, ends_on, pass_plus) values (2, 'Saison 2', '2027-01-03', '2027-03-28', true)
on conflict (id) do nothing;

insert into public.season_rewards (season_id, track, tier, kind, item, qty, label, icon) values
  (2, 'free', 1, 'chest', 'wood', 1, 'Coffre en bois', 'chest_wood'),
  (2, 'free', 2, 'cosmetic', 'autoc.s2', 1, 'Autocollant « Saison 2 »', 'autoc_s2'),
  (2, 'free', 3, 'ticket', null, 1, 'Ticket de pochette', 'ticket_pochette'),
  (2, 'free', 4, 'chest', 'wood', 1, 'Coffre en bois', 'chest_wood'),
  (2, 'free', 5, 'cosmetic', 'titre.polaire', 1, 'Titre « Esprit polaire »', 'titre_polaire'),
  (2, 'free', 6, 'ticket', null, 1, 'Ticket de pochette', 'ticket_pochette'),
  (2, 'free', 7, 'chest', 'silver', 1, 'Coffre en argent', 'chest_silver'),
  (2, 'free', 8, 'cosmetic', 'cadre.flocons', 1, 'Cadre Flocons', 'cadre_flocons'),
  (2, 'free', 9, 'ticket', null, 1, 'Ticket de pochette', 'ticket_pochette'),
  (2, 'free', 10, 'cosmetic', 'dos.hiver', 1, 'Dos « Nuit d''hiver »', 'dos_hiver'),
  (2, 'free', 11, 'chest', 'silver', 1, 'Coffre en argent', 'chest_silver'),
  (2, 'free', 12, 'cosmetic', 'titrej.givre', 1, 'Titre « Givré du savoir »', 'titrej_givre'),
  (2, 'free', 13, 'ticket', null, 1, 'Ticket de pochette', 'ticket_pochette'),
  (2, 'free', 14, 'chest', 'silver', 1, 'Coffre en argent', 'chest_silver'),
  (2, 'free', 15, 'cosmetic', 'socle.glace', 1, 'Socle Glace', 'socle_glace'),
  (2, 'free', 16, 'ticket', null, 1, 'Ticket de pochette', 'ticket_pochette'),
  (2, 'free', 17, 'chest', 'silver', 1, 'Coffre en argent', 'chest_silver'),
  (2, 'free', 18, 'cosmetic', 'autoc.bonhomme', 1, 'Autocollant « Bonhomme de neige »', 'autoc_bonhomme'),
  (2, 'free', 19, 'ticket', null, 1, 'Ticket de pochette', 'ticket_pochette'),
  (2, 'free', 20, 'token', null, 1, 'Jeton Prestige', 'jeton'),
  (2, 'free', 21, 'chest', 'gold', 1, 'Coffre en or', 'chest_gold'),
  (2, 'free', 22, 'cosmetic', 'titre.flocon', 1, 'Titre « Flocon savant »', 'titre_flocon'),
  (2, 'free', 23, 'ticket', null, 1, 'Ticket de pochette', 'ticket_pochette'),
  (2, 'free', 24, 'chest', 'gold', 1, 'Coffre en or', 'chest_gold'),
  (2, 'free', 25, 'cosmetic', 'titrej.banquise', 1, 'Titre « Explorateur polaire »', 'titrej_banquise'),
  (2, 'free', 26, 'ticket', null, 1, 'Ticket de pochette', 'ticket_pochette'),
  (2, 'free', 27, 'chest', 'gold', 1, 'Coffre en or', 'chest_gold'),
  (2, 'free', 28, 'cosmetic', 'couv.hiver', 1, 'Couverture « Hiver »', 'couv_hiver'),
  (2, 'free', 29, 'chest', 'gold', 2, 'Deux coffres en or', 'chest_savant'),
  (2, 'free', 30, 'final', 'dos.aurore', 1, 'Dos Aurore boréale + pochette dorée', 'final_gratuit_s2'),

  (2, 'paid', 1, 'perk', null, 1, 'Plus de pub toute la saison', 'sans_pub'),
  (2, 'paid', 2, 'cosmetic', 'dos.domaines', 1, 'Dos « Les 12 domaines »', 'dos_domaines'),
  (2, 'paid', 3, 'cosmetic', 'autoc.fondateur', 1, 'Autocollant « Fondateur »', 'autoc_fondateur'),
  (2, 'paid', 4, 'cosmetic', 'titre.grand_curieux', 1, 'Titre « Grand curieux »', 'titre_grand_curieux'),
  (2, 'paid', 5, 'token', null, 1, 'Jeton Prestige', 'jeton'),
  (2, 'paid', 6, 'cosmetic', 'cadre.vitrail', 1, 'Cadre Vitrail', 'cadre_vitrail'),
  (2, 'paid', 7, 'coffret', null, 1, 'Coffret de catégorie', 'coffret'),
  (2, 'paid', 8, 'cosmetic', 'finition.givre', 1, 'Finition Givre', 'finition_givre'),
  (2, 'paid', 9, 'cosmetic', 'titrej.savant', 1, 'Titre « Savant »', 'titrej_savant'),
  (2, 'paid', 10, 'cosmetic', 'cadre.nuit', 1, 'Cadre Nuit étoilée', 'cadre_nuit'),
  (2, 'paid', 11, 'cosmetic', 'socle.or', 1, 'Socle Or', 'socle_or'),
  (2, 'paid', 12, 'cosmetic', 'autoc.flocon', 1, 'Autocollant « Flocon »', 'autoc_flocon'),
  (2, 'paid', 13, 'cosmetic', 'couv.grimoire', 1, 'Couverture « Grimoire »', 'couv_grimoire'),
  (2, 'paid', 14, 'cosmetic', 'titre.chasseur', 1, 'Titre « Chasseur de légendes »', 'titre_chasseur'),
  (2, 'paid', 15, 'token', null, 1, 'Jeton Prestige', 'jeton'),
  (2, 'paid', 16, 'cosmetic', 'finition.or', 1, 'Finition Poussière d''or', 'finition_or'),
  (2, 'paid', 17, 'cosmetic', 'cadre.aurore', 1, 'Cadre Aurore', 'cadre_aurore'),
  (2, 'paid', 18, 'coffret', null, 1, 'Coffret de catégorie', 'coffret'),
  (2, 'paid', 19, 'cosmetic', 'socle.neon', 1, 'Socle Néon', 'socle_neon'),
  (2, 'paid', 20, 'cosmetic', 'titrej.legende', 1, 'Titre « Légende vivante »', 'titrej_legende'),
  (2, 'paid', 21, 'cosmetic', 'cadre.marbre', 1, 'Cadre Marbre', 'cadre_marbre'),
  (2, 'paid', 22, 'chest', 'gold', 1, 'Coffre en or', 'chest_gold'),
  (2, 'paid', 23, 'cosmetic', 'autoc.yeti', 1, 'Autocollant « Yéti »', 'autoc_yeti'),
  (2, 'paid', 24, 'cosmetic', 'finition.holo', 1, 'Finition Holographique', 'finition_holo'),
  (2, 'paid', 25, 'token', null, 1, 'Jeton Prestige', 'jeton'),
  (2, 'paid', 26, 'coffret', null, 1, 'Coffret de catégorie', 'coffret'),
  (2, 'paid', 27, 'cosmetic', 'titre.musee', 1, 'Titre « Pièce de musée »', 'titre_musee'),
  (2, 'paid', 28, 'cosmetic', 'couv.or', 1, 'Couverture « Feuille d''or »', 'couv_or'),
  (2, 'paid', 29, 'chest', 'gold', 2, 'Deux coffres en or', 'chest_savant'),
  (2, 'paid', 30, 'cosmetic', 'dos.or,cadre.anime', 1, 'Dos Feuille d''or + cadre animé', 'final_payant')
on conflict do nothing;

-- ─────────────────────────────────────────── Droits
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and p.proname in ('_has_pass', '_coffret_offers', '_give_coffret', '_season_give', '_season_claim_one')
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', f.sig);
    execute format('alter function %s set search_path = public, pg_temp', f.sig);
  end loop;
end $$;

revoke execute on function public.pass_plus_record(uuid, text, text, text, text, timestamptz), public.pass_plus_revoke(text)
  from public, anon, authenticated;
grant execute on function public.pass_plus_record(uuid, text, text, text, text, timestamptz), public.pass_plus_revoke(text)
  to service_role;

do $$
declare f text;
begin
  foreach f in array array['season_claim(int, text)', 'season_claim_all(text)', 'album_open_coffret(uuid, text)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
