-- Brainlix — 0022 Coffres, arbre de Léon, objets, trophées de maîtrise, niveaux, rééquilibrage des graines
--
-- Coffres (jamais achetables) : bois, argent, or. Contenu tiré par le serveur à l'ouverture, une seule fois.
--   bois   : 10–20 graines, 1 ticket d'aide, 10 % joker de série
--   argent : 30–50 graines, 2 tickets d'aide, 30 % joker, 25 % objet pour Léon
--   or     : 60–80 graines, 1 joker garanti, 1 objet pour Léon garanti
--   Joker impossible (déjà 2) → graines (10 / 20 / 40) ; plus d'objet à gagner → graines (argent 25, or 40).
-- Sources : 3 défis du jour (bois), 3 défis de la semaine (argent), chaque niveau (bois ; ×5 argent ; ×10 or),
--   trophées, étapes de l'arbre (or), parrainage (paliers 3 / 5 / 10 : argent / or / or), bienvenue (or, joueurs existants).
-- Arbre de Léon : on le nourrit de graines. Étapes à 0 / 150 / 600 / 1 800 / 4 000 / 9 000 (en fleurs, ~6 mois
--   pour un joueur actif), puis un fruit tous les 2 500 graines (4 fruits, chacun un objet rare introuvable ailleurs).
--   Arbre complet à 19 000 graines.
-- Trophées : exploits (succès existants + 3) et maîtrise par domaine (Elo classé 1 050 / 1 200 / 1 350 / 1 500),
--   chacun donne un coffre au lieu de graines directes.
-- Parrainage : 30 graines pour l'invité (100 avant), 50 pour le parrain (150 avant), paliers en coffres.

-- ─────────────────────────────────────────── Coffres
create type public.chest_tier as enum ('wood', 'silver', 'gold');

create table public.user_chests (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references public.profiles(id) on delete cascade,
  tier             public.chest_tier not null,
  source           text not null,        -- quests_day, quests_week, level, trophy, tree, referral, welcome
  ref              text,
  idempotency_key  text not null,
  created_at       timestamptz not null default now(),
  opened_at        timestamptz,
  contents         jsonb,
  unique (user_id, idempotency_key)
);
create index user_chests_unopened on public.user_chests (user_id, created_at) where opened_at is null;

-- Donne un coffre une fois par clé. Renvoie true si le coffre a été créé.
create or replace function public._give_chest(p_user uuid, p_tier public.chest_tier, p_source text, p_ref text, p_key text)
returns bool language plpgsql as $$
declare v_id uuid;
begin
  insert into public.user_chests (user_id, tier, source, ref, idempotency_key, created_at)
  values (p_user, p_tier, p_source, p_ref, p_key, public._now())
  on conflict (user_id, idempotency_key) do nothing
  returning id into v_id;
  return v_id is not null;
end $$;

-- ─────────────────────────────────────────── Objets : tenues de Léon et tickets d'aide
create table public.items (
  id      text primary key check (id ~ '^[a-z_]+$'),
  kind    text not null check (kind in ('cosmetic', 'ticket')),
  slot    text check (slot in ('hat', 'eyes', 'neck', 'back', 'skin')),
  rarity  text check (rarity in ('chest', 'fruit')),
  name    text not null,
  sort    int  not null default 0,
  check ((kind = 'cosmetic') = (slot is not null and rarity is not null))
);

insert into public.items (id, kind, slot, rarity, name, sort) values
  -- Dans les coffres
  ('beret',              'cosmetic', 'hat',  'chest', 'Béret',                10),
  ('party_hat',          'cosmetic', 'hat',  'chest', 'Chapeau de fête',      20),
  ('headphones',         'cosmetic', 'hat',  'chest', 'Casque audio',         30),
  ('round_glasses',      'cosmetic', 'eyes', 'chest', 'Lunettes rondes',      40),
  ('star_glasses',       'cosmetic', 'eyes', 'chest', 'Lunettes étoiles',     50),
  ('red_scarf',          'cosmetic', 'neck', 'chest', 'Écharpe rouge',        60),
  ('bow_tie',            'cosmetic', 'neck', 'chest', 'Nœud papillon',        70),
  ('skin_sunset',        'cosmetic', 'skin', 'chest', 'Coucher de soleil',    80),
  -- Fruits de l'arbre, dans cet ordre (le plus beau en dernier)
  ('leaf_crown',         'cosmetic', 'hat',  'fruit', 'Couronne de feuilles', 110),
  ('monocle',            'cosmetic', 'eyes', 'fruit', 'Monocle',              120),
  ('star_cape',          'cosmetic', 'back', 'fruit', 'Cape étoilée',         130),
  ('skin_gold',          'cosmetic', 'skin', 'fruit', 'Léon doré',            140),
  -- Tickets d'aide (utilisés à la place des graines)
  ('ticket_fifty_fifty', 'ticket',   null,   null,    'Ticket 50/50',         200),
  ('ticket_hint',        'ticket',   null,   null,    'Ticket indice',        210);

create table public.user_items (
  user_id      uuid not null references public.profiles(id) on delete cascade,
  item_id      text not null references public.items(id),
  qty          int  not null default 1 check (qty >= 0),
  equipped     bool not null default false,
  acquired_at  timestamptz not null default now(),
  primary key (user_id, item_id)
);
-- Un seul objet porté par emplacement : vérifié par leon_equip.

create or replace function public._give_item(p_user uuid, p_item text, p_qty int default 1) returns void
language plpgsql as $$
begin
  insert into public.user_items as ui (user_id, item_id, qty, acquired_at) values (p_user, p_item, p_qty, public._now())
  on conflict (user_id, item_id) do update set qty = case
    when (select kind from public.items where id = p_item) = 'ticket' then ui.qty + excluded.qty else ui.qty end;
end $$;

-- Tickets utilisés (une aide déjà payée, en graines ou en ticket, n'est jamais repayée).
create table public.help_ticket_uses (
  user_id     uuid not null references public.profiles(id) on delete cascade,
  key         text not null,
  created_at  timestamptz not null default now(),
  primary key (user_id, key)
);

-- ─────────────────────────────────────────── Profil : arbre et niveaux déjà récompensés
alter table public.profiles
  add column tree_points          int not null default 0 check (tree_points between 0 and 19000),
  add column tree_stage_rewarded  int not null default 1,
  add column tree_fruits_rewarded int not null default 0,
  add column level_rewarded       int not null default 1;

create or replace function public._tree_max() returns int language sql immutable as $$ select 19000 $$;

create or replace function public._tree_stage(p_points int) returns int language sql immutable as $$
  select case when p_points >= 9000 then 6 when p_points >= 4000 then 5 when p_points >= 1800 then 4
              when p_points >= 600 then 3 when p_points >= 150 then 2 else 1 end
$$;

create or replace function public._tree_fruits(p_points int) returns int language sql immutable as $$
  select least(4, greatest(0, (p_points - 9000) / 2500))
$$;

-- Graines nécessaires pour la prochaine étape ou le prochain fruit (null : arbre complet).
create or replace function public._tree_next(p_points int) returns int language sql immutable as $$
  select case when p_points < 150 then 150 when p_points < 600 then 600 when p_points < 1800 then 1800
              when p_points < 4000 then 4000 when p_points < 9000 then 9000
              when p_points < 19000 then 9000 + 2500 * (public._tree_fruits(p_points) + 1) end
$$;

create or replace function public._tree_stage_name(p_stage int) returns text language sql immutable as $$
  select (array['Graine', 'Pousse', 'Jeune plant', 'Arbuste', 'Arbre', 'Arbre de Léon en fleurs'])[p_stage]
$$;

-- Niveau d'XP : seuil du niveau L = 50 · L · (L − 1) (même formule que l'app).
create or replace function public._xp_level(p_xp int) returns int language sql immutable as $$
  select greatest(1, floor((1 + sqrt(1 + 4 * greatest(coalesce(p_xp, 0), 0) / 50.0)) / 2)::int)
$$;

-- ─────────────────────────────────────────── Niveaux : un coffre par niveau gagné
create or replace function public._ledger_levels() returns trigger
language plpgsql as $$
declare
  v_level int;
  v_from int;
begin
  if new.currency <> 'xp' or new.amount <= 0 then return new; end if;
  select public._xp_level(xp_total), level_rewarded into v_level, v_from from public.profiles where id = new.user_id;
  if v_level <= v_from then return new; end if;
  for l in v_from + 1 .. v_level loop
    perform public._give_chest(new.user_id,
                               (case when l % 10 = 0 then 'gold' when l % 5 = 0 then 'silver' else 'wood' end)::public.chest_tier,
                               'level', l::text, 'level:' || l);
  end loop;
  update public.profiles set level_rewarded = v_level where id = new.user_id;
  return new;
end $$;
-- Après ledger_apply (ordre alphabétique des triggers) : xp_total est déjà à jour.
create trigger ledger_levels after insert on public.ledger for each row execute function public._ledger_levels();

-- ─────────────────────────────────────────── Trophées : exploits et maîtrise
alter table public.achievements
  add column category  text not null default 'exploit' check (category in ('exploit', 'mastery')),
  add column chest     public.chest_tier,
  add column domain_id text references public.domains(id),
  add column tier      text check (tier in ('bronze', 'silver', 'gold', 'diamond'));

update public.achievements set reward_seeds = 0, chest = (case id
  when 'first_daily'    then 'wood'
  when 'first_perfect'  then 'wood'
  when 'first_friend'   then 'wood'
  when 'fast_perfect'   then 'silver'
  when 'streak_7'       then 'silver'
  else 'gold' end)::public.chest_tier;

insert into public.achievements (id, name, description, reward_seeds, sort, category, chest) values
  ('placed',         'Placé',             'Terminer ton premier placement dans un domaine.',          0, 110, 'exploit', 'wood'),
  ('ranked_perfect', 'Sans-faute classé', 'Réussir 10 questions sur 10 dans une partie classée.',     0, 120, 'exploit', 'silver'),
  ('globetrotter',   'Globe-trotter',     'Jouer en classé dans tous les domaines.',                  0, 130, 'exploit', 'gold');

create or replace function public._mastery_cote(p_tier text) returns int language sql immutable as $$
  select case p_tier when 'bronze' then 1050 when 'silver' then 1200 when 'gold' then 1350 when 'diamond' then 1500 end
$$;

-- Quatre trophées de maîtrise par domaine, tenus à jour avec les domaines (le seed les crée après les migrations).
create or replace function public._mastery_sync(p_domain text) returns void
language sql as $$
  insert into public.achievements (id, name, description, reward_seeds, sort, category, chest, domain_id, tier)
  select 'mastery_' || d.id || '_' || t.tier,
         d.name || ' · ' || t.label,
         'Atteindre ' || t.cote_text || ' d''Elo en ' || d.name || '.',
         0, 1000 + d.sort * 10 + t.n, 'mastery', t.chest::public.chest_tier, d.id, t.tier
  from public.domains d
  cross join (values (1, 'bronze', 'Bronze', '1 050', 'wood'), (2, 'silver', 'Argent', '1 200', 'silver'),
                     (3, 'gold', 'Or', '1 350', 'gold'), (4, 'diamond', 'Diamant', '1 500', 'gold'))
             as t(n, tier, label, cote_text, chest)
  where d.id = p_domain
  on conflict (id) do update set name = excluded.name, description = excluded.description, sort = excluded.sort
$$;

create or replace function public._domains_mastery() returns trigger
language plpgsql as $$
begin
  perform public._mastery_sync(new.id);
  return new;
end $$;
create trigger domains_mastery after insert or update of name, sort on public.domains
  for each row execute function public._domains_mastery();

select public._mastery_sync(id) from public.domains;

-- Débloque un trophée : un coffre au lieu de graines directes.
create or replace function public._unlock(p_user uuid, p_id text) returns bool
language plpgsql as $$
declare a public.achievements;
begin
  insert into public.user_achievements (user_id, achievement_id, unlocked_at) values (p_user, p_id, public._now())
  on conflict do nothing;
  if not found then return false; end if;
  select * into a from public.achievements where id = p_id;
  if a.reward_seeds > 0 then
    perform public._grant(p_user, 'seeds', a.reward_seeds, 'achievement', p_id, 'achievement:' || p_id);
  end if;
  if a.chest is not null then
    perform public._give_chest(p_user, a.chest, 'trophy', p_id, 'trophy:' || p_id);
  end if;
  return true;
end $$;

-- Conditions non liées à un événement précis (appelé après le Daily et chaque partie). Renvoie les nouveaux trophées.
create or replace function public._check_achievements(p_user uuid) returns text[]
language plpgsql as $$
declare
  p public.profiles;
  v_new text[] := '{}';
  m record;
begin
  select * into p from public.profiles where id = p_user;
  if p.streak_best >= 7   and public._unlock(p_user, 'streak_7')   then v_new := v_new || 'streak_7'::text; end if;
  if p.streak_best >= 30  and public._unlock(p_user, 'streak_30')  then v_new := v_new || 'streak_30'::text; end if;
  if p.streak_best >= 100 and public._unlock(p_user, 'streak_100') then v_new := v_new || 'streak_100'::text; end if;
  if p.errors_corrected >= 100 and public._unlock(p_user, 'errors_100') then v_new := v_new || 'errors_100'::text; end if;
  if p.questions_answered >= 1000 and public._unlock(p_user, 'questions_1000') then v_new := v_new || 'questions_1000'::text; end if;
  if (select count(*) from public.user_skills s
      where s.user_id = p_user and s.is_domain and s.mu >= 65 and s.var <= 36) >= 5
     and public._unlock(p_user, 'polymath') then
    v_new := v_new || 'polymath'::text;
  end if;

  -- Placement terminé dans au moins un domaine.
  if exists (select 1 from public.user_skills s where s.user_id = p_user and s.is_domain and s.n >= public._c_placement())
     and public._unlock(p_user, 'placed') then
    v_new := v_new || 'placed'::text;
  end if;
  -- 10/10 dans une partie classée récente.
  if exists (select 1 from public.play_sessions s
             where s.user_id = p_user and s.ranked and s.completed_at >= public._now() - interval '2 days'
               and cardinality(s.question_ids) >= 10
               and (select count(*) from public.question_attempts a where a.session_id = s.id and a.user_id = p_user and a.is_correct) >= 10)
     and public._unlock(p_user, 'ranked_perfect') then
    v_new := v_new || 'ranked_perfect'::text;
  end if;
  -- Du classé dans chaque domaine actif.
  if not exists (select 1 from public.domains d
                 where d.is_active and not exists (select 1 from public.user_skills s
                                                   where s.user_id = p_user and s.scope_id = d.id and s.n > 0))
     and public._unlock(p_user, 'globetrotter') then
    v_new := v_new || 'globetrotter'::text;
  end if;

  -- Maîtrise : Elo classé du domaine, une fois le placement terminé.
  for m in
    select a.id from public.achievements a
    join public.user_skills s on s.user_id = p_user and s.scope_id = a.domain_id
    where a.category = 'mastery' and s.n >= public._c_placement() and public._cote(s.mu) >= public._mastery_cote(a.tier)
      and not exists (select 1 from public.user_achievements ua where ua.user_id = p_user and ua.achievement_id = a.id)
    order by a.sort
  loop
    if public._unlock(p_user, m.id) then v_new := v_new || m.id; end if;
  end loop;
  return v_new;
end $$;

-- Le profil garde sa vitrine d'exploits ; la maîtrise a sa propre vue (trophies_overview).
create or replace function public.achievements_mine() returns jsonb
language sql security definer set search_path = public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', a.id, 'name', a.name, 'description', a.description,
                                               'unlocked_at', ua.unlocked_at) order by a.sort), '[]'::jsonb)
  from public.achievements a
  left join public.user_achievements ua on ua.achievement_id = a.id and ua.user_id = auth.uid()
  where a.category = 'exploit'
$$;

create or replace function public.trophies_overview() returns jsonb
language sql security definer set search_path = public, pg_temp as $$
  select jsonb_build_object(
    'exploits', (select coalesce(jsonb_agg(jsonb_build_object(
                   'id', a.id, 'name', a.name, 'description', a.description, 'chest', a.chest,
                   'unlocked_at', ua.unlocked_at) order by a.sort), '[]'::jsonb)
                 from public.achievements a
                 left join public.user_achievements ua on ua.achievement_id = a.id and ua.user_id = auth.uid()
                 where a.category = 'exploit'),
    'mastery', (select coalesce(jsonb_agg(jsonb_build_object(
                  'domain_id', d.id, 'name', d.name,
                  'placed', coalesce(s.n, 0) >= public._c_placement(),
                  'cote', case when coalesce(s.n, 0) >= public._c_placement() then public._cote(s.mu) end,
                  'tier', (select a.tier from public.achievements a join public.user_achievements ua
                             on ua.achievement_id = a.id and ua.user_id = auth.uid()
                           where a.domain_id = d.id and a.category = 'mastery' order by a.sort desc limit 1),
                  'next', (select jsonb_build_object('tier', a.tier, 'cote', public._mastery_cote(a.tier))
                           from public.achievements a
                           where a.domain_id = d.id and a.category = 'mastery'
                             and not exists (select 1 from public.user_achievements ua
                                             where ua.achievement_id = a.id and ua.user_id = auth.uid())
                           order by a.sort limit 1)) order by d.sort), '[]'::jsonb)
                from public.domains d
                left join public.user_skills s on s.user_id = auth.uid() and s.scope_id = d.id
                where d.is_active));
$$;

-- ─────────────────────────────────────────── Ouverture d'un coffre
create or replace function public.chest_open(p_chest uuid) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  c public.user_chests;
  v_seeds int;
  v_tickets int;
  v_fifty int := 0;
  v_hint int := 0;
  v_joker bool := false;
  v_item public.items;
  v_want_joker bool;
  v_want_item bool;
  v_contents jsonb;
begin
  select * into c from public.user_chests where id = p_chest and user_id = v_user for update;
  if not found then raise exception 'chest_not_found'; end if;
  if c.opened_at is not null then
    return c.contents || jsonb_build_object('already_opened', true);
  end if;

  v_seeds := case c.tier when 'wood' then 10 + floor(random() * 11) when 'silver' then 30 + floor(random() * 21)
                         else 60 + floor(random() * 21) end;
  v_tickets := case c.tier when 'wood' then 1 when 'silver' then 2 else 0 end;
  for i in 1 .. v_tickets loop
    if random() < 0.5 then v_fifty := v_fifty + 1; else v_hint := v_hint + 1; end if;
  end loop;
  if v_fifty > 0 then perform public._give_item(v_user, 'ticket_fifty_fifty', v_fifty); end if;
  if v_hint > 0 then perform public._give_item(v_user, 'ticket_hint', v_hint); end if;

  v_want_joker := case c.tier when 'wood' then random() < 0.10 when 'silver' then random() < 0.30 else true end;
  if v_want_joker then
    update public.profiles set streak_freezes = streak_freezes + 1 where id = v_user and streak_freezes < 2;
    if found then v_joker := true;
    else v_seeds := v_seeds + case c.tier when 'wood' then 10 when 'silver' then 20 else 40 end;
    end if;
  end if;

  v_want_item := case c.tier when 'wood' then false when 'silver' then random() < 0.25 else true end;
  if v_want_item then
    select i.* into v_item from public.items i
    where i.kind = 'cosmetic' and i.rarity = 'chest'
      and not exists (select 1 from public.user_items ui where ui.user_id = v_user and ui.item_id = i.id)
    order by random() limit 1;
    if v_item.id is not null then perform public._give_item(v_user, v_item.id);
    else v_seeds := v_seeds + case c.tier when 'silver' then 25 else 40 end;
    end if;
  end if;

  perform public._grant(v_user, 'seeds', v_seeds, 'chest', c.id::text, 'chest:' || c.id);
  v_contents := jsonb_build_object(
    'tier', c.tier, 'seeds', v_seeds,
    'tickets', jsonb_build_object('fifty_fifty', v_fifty, 'hint', v_hint),
    'joker', v_joker,
    'item', case when v_item.id is not null then jsonb_build_object('id', v_item.id, 'name', v_item.name, 'slot', v_item.slot) end);
  update public.user_chests set opened_at = public._now(), contents = v_contents where id = c.id;
  return v_contents || jsonb_build_object('balance', (select seeds from public.profiles where id = v_user));
end $$;

-- ─────────────────────────────────────────── Arbre de Léon
create or replace function public._tree_json(p public.profiles) returns jsonb
language sql stable as $$
  select jsonb_build_object(
    'points', p.tree_points,
    'stage', public._tree_stage(p.tree_points),
    'stage_name', public._tree_stage_name(public._tree_stage(p.tree_points)),
    'fruits', public._tree_fruits(p.tree_points),
    'next_at', public._tree_next(p.tree_points),
    'max', public._tree_max(),
    'complete', p.tree_points >= public._tree_max())
$$;

-- Nourrir l'arbre. p_client_id rend l'appel idempotent (renvoi réseau).
create or replace function public.tree_feed(p_amount int, p_client_id uuid default gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  p public.profiles;
  v_amount int;
  v_stage int;
  v_fruits int;
  v_chests int := 0;
  v_items jsonb := '[]'::jsonb;
  v_item public.items;
begin
  if p_amount is null or p_amount <= 0 then raise exception 'invalid_amount'; end if;
  select * into p from public.profiles where id = v_user for update;
  if p.tree_points >= public._tree_max() then raise exception 'tree_complete'; end if;
  v_amount := least(p_amount, public._tree_max() - p.tree_points, p.seeds);
  if v_amount <= 0 then raise exception 'insufficient_seeds'; end if;

  if public._grant(v_user, 'seeds', -v_amount, 'tree_feed', null, 'tree:' || p_client_id) then
    update public.profiles set tree_points = tree_points + v_amount where id = v_user returning * into p;
    -- Nouvelles étapes : un coffre d'or chacune.
    v_stage := public._tree_stage(p.tree_points);
    for s in p.tree_stage_rewarded + 1 .. v_stage loop
      if public._give_chest(v_user, 'gold', 'tree', s::text, 'tree_stage:' || s) then v_chests := v_chests + 1; end if;
    end loop;
    -- Fruits : un objet rare chacun, dans l'ordre.
    v_fruits := public._tree_fruits(p.tree_points);
    for f in p.tree_fruits_rewarded + 1 .. v_fruits loop
      select * into v_item from public.items where rarity = 'fruit' order by sort offset f - 1 limit 1;
      if v_item.id is not null then
        perform public._give_item(v_user, v_item.id);
        v_items := v_items || jsonb_build_object('id', v_item.id, 'name', v_item.name, 'slot', v_item.slot);
      end if;
    end loop;
    update public.profiles set tree_stage_rewarded = greatest(tree_stage_rewarded, v_stage),
                               tree_fruits_rewarded = greatest(tree_fruits_rewarded, v_fruits)
    where id = v_user returning * into p;
  else
    v_amount := 0;
  end if;

  return jsonb_build_object('fed', v_amount, 'new_chests', v_chests, 'new_items', v_items,
                            'tree', public._tree_json(p), 'balance', p.seeds);
end $$;

-- ─────────────────────────────────────────── Tenue de Léon
create or replace function public.leon_equip(p_slot text, p_item text default null) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user();
begin
  if p_slot not in ('hat', 'eyes', 'neck', 'back', 'skin') then raise exception 'invalid_slot'; end if;
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

create or replace function public._leon_outfit(p_user uuid) returns jsonb
language sql stable as $$
  select coalesce(jsonb_object_agg(i.slot, i.id), '{}'::jsonb)
  from public.user_items ui join public.items i on i.id = ui.item_id
  where ui.user_id = p_user and ui.equipped and i.kind = 'cosmetic'
$$;

-- ─────────────────────────────────────────── Vue d'ensemble de la progression (écran Léon, coffres)
create or replace function public.progression_overview() returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  p public.profiles;
begin
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
    'items', (select coalesce(jsonb_agg(jsonb_build_object(
                'id', i.id, 'name', i.name, 'slot', i.slot, 'rarity', i.rarity,
                'owned', ui.item_id is not null, 'equipped', coalesce(ui.equipped, false)) order by i.sort), '[]'::jsonb)
              from public.items i
              left join public.user_items ui on ui.item_id = i.id and ui.user_id = v_user
              where i.kind = 'cosmetic'));
end $$;

-- ─────────────────────────────────────────── Aides : un ticket remplace les graines
create or replace function public.play_spend_help(p_session uuid, p_question uuid, p_kind text) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  s public.play_sessions;
  q public.questions;
  v_cost int;
  v_content jsonb;
  v_key text;
  v_ticket bool := false;
begin
  select * into s from public.play_sessions where id = p_session and user_id = v_user;
  if not found or not (p_question = any (s.question_ids)) then raise exception 'session_not_found'; end if;
  if p_question = any (public._protected_daily_questions()) then raise exception 'not_allowed'; end if;
  select * into q from public.questions where id = p_question;

  v_cost := case p_kind when 'fifty_fifty' then 15 when 'hint' then 10 when 'context' then 5 end;
  if v_cost is null then raise exception 'invalid_help'; end if;

  if p_kind = 'fifty_fifty' then
    if q.type not in ('mcq', 'map_pick') or jsonb_array_length(q.payload -> 'options') < 3 then raise exception 'help_unavailable'; end if;
    v_content := jsonb_build_object('remove', (
      select jsonb_agg(o ->> 'id') from (
        select o from jsonb_array_elements(q.payload -> 'options') o
        where o ->> 'id' <> q.answer ->> 'option_id' order by random()
        limit jsonb_array_length(q.payload -> 'options') - 2) t));
  elsif p_kind = 'hint' then
    if q.hint is null then raise exception 'help_unavailable'; end if;
    v_content := jsonb_build_object('hint', q.hint);
  else
    if q.context_note is null then raise exception 'help_unavailable'; end if;
    v_content := jsonb_build_object('context', q.context_note);
  end if;

  -- Une aide déjà obtenue pour cette question dans cette session n'est pas refacturée.
  v_key := 'help:' || s.id || ':' || q.id || ':' || p_kind;
  if not exists (select 1 from public.ledger where user_id = v_user and idempotency_key = v_key)
     and not exists (select 1 from public.help_ticket_uses where user_id = v_user and key = v_key) then
    if p_kind in ('fifty_fifty', 'hint') then
      update public.user_items set qty = qty - 1
      where user_id = v_user and item_id = 'ticket_' || p_kind and qty > 0;
      v_ticket := found;
    end if;
    if v_ticket then
      insert into public.help_ticket_uses (user_id, key, created_at) values (v_user, v_key, public._now());
    else
      perform public._grant(v_user, 'seeds', -v_cost, 'spend_' || p_kind, q.id::text, v_key);
    end if;
  end if;
  return v_content || jsonb_build_object(
    'balance', (select seeds from public.profiles where id = v_user),
    'ticket_used', v_ticket,
    'tickets_left', coalesce((select qty from public.user_items where user_id = v_user and item_id = 'ticket_' || p_kind), 0));
end $$;

-- ─────────────────────────────────────────── Défis : les bonus deviennent des coffres
create or replace function public._quests_period(p_user uuid, p_period text, p_start date, p_newly_in jsonb,
                                                 out result jsonb, out newly jsonb)
language plpgsql as $$
declare
  v_to date := p_start + case when p_period = 'day' then 1 else 7 end;
  q public.user_quests;
  v_progress int;
  v_quests jsonb := '[]'::jsonb;
  v_all bool := true;
  v_chest public.chest_tier := case when p_period = 'day' then 'wood' else 'silver' end;
  v_key text;
begin
  newly := p_newly_in;
  perform public._quests_ensure(p_user, p_period, p_start);
  for q in select * from public.user_quests where user_id = p_user and period = p_period and period_start = p_start order by slot loop
    v_progress := least(public._quest_progress(p_user, q.metric, q.param, p_start, v_to), q.target);
    if v_progress >= q.target and q.completed_at is null then
      update public.user_quests set completed_at = public._now()
      where user_id = p_user and period = p_period and period_start = p_start and slot = q.slot;
      q.completed_at := public._now();
      v_key := 'quest:' || p_period || ':' || p_start || ':' || q.slot;
      perform public._grant(p_user, 'xp', q.xp, 'quest', v_key, v_key || ':xp');
      if public._grant(p_user, 'seeds', q.seeds, 'quest', v_key, v_key || ':seeds') then
        newly := newly || jsonb_build_object('label', q.label, 'xp', q.xp, 'seeds', q.seeds);
      end if;
    end if;
    v_all := v_all and q.completed_at is not null;
    v_quests := v_quests || jsonb_build_object('slot', q.slot, 'label', q.label, 'target', q.target, 'progress', v_progress,
                                               'done', q.completed_at is not null, 'xp', q.xp, 'seeds', q.seeds);
  end loop;
  if v_all and jsonb_array_length(v_quests) > 0 then
    v_key := 'quest_bonus:' || p_period || ':' || p_start;
    -- Une période dont le bonus a déjà été versé en graines (avant les coffres) ne donne pas de coffre en plus.
    if not exists (select 1 from public.ledger where user_id = p_user and idempotency_key = v_key || ':seeds')
       and public._give_chest(p_user, v_chest, 'quests_' || p_period, p_start::text, v_key) then
      newly := newly || jsonb_build_object('label', case when p_period = 'day' then 'Tous les défis du jour'
                                                              else 'Tous les défis de la semaine' end,
                                           'xp', 0, 'seeds', 0, 'bonus', true, 'chest', v_chest);
    end if;
  end if;
  result := jsonb_build_object(
    'period_start', p_start,
    'ends_at', public._day_end(v_to - 1, public._user_tz(p_user)),
    'quests', v_quests,
    'bonus', jsonb_build_object('xp', 0, 'seeds', 0, 'chest', v_chest, 'done', v_all and jsonb_array_length(v_quests) > 0));
end $$;

-- ─────────────────────────────────────────── Parrainage rééquilibré
do $$
declare
  f record;
  v_old text;
  v_new text;
begin
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'referral_claim' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(v_old, '''seeds'', 100', '''seeds'', 30');
    if v_new = v_old then raise exception '0022: referral_claim inchangée'; end if;
    execute v_new;
  end loop;
end $$;

create or replace function public._referral_on_first_daily(p_user uuid) returns void
language plpgsql as $$
declare
  r public.referrals;
  v_count int;
begin
  select * into r from public.referrals where invitee_id = p_user and status = 'claimed' for update;
  if not found then return; end if;
  if (select count(*) from public.daily_runs where user_id = p_user and status = 'finished') < 1 then return; end if;

  update public.referrals set status = 'qualified', qualified_at = public._now() where id = r.id;
  if (select count(*) from public.referrals where inviter_id = r.inviter_id and status = 'qualified'
        and qualified_at > public._now() - interval '30 days') <= 20 then
    perform public._grant(r.inviter_id, 'seeds', 50, 'referral_inviter', r.id::text, 'referral_inviter:' || r.id);
  end if;
  select count(*) into v_count from public.referrals where inviter_id = r.inviter_id and status = 'qualified';
  if v_count in (3, 5, 10) then
    perform public._give_chest(r.inviter_id, (case v_count when 3 then 'silver' else 'gold' end)::public.chest_tier,
                               'referral', v_count::text, 'referral_tier:' || v_count);
  end if;
end $$;

-- ─────────────────────────────────────────── Fin de partie : noms des trophées (et plus leurs identifiants)
alter function public.play_submit(uuid, jsonb) rename to _play_submit_rated;
revoke execute on function public._play_submit_rated(uuid, jsonb) from public, anon, authenticated;
create or replace function public.play_submit(p_session uuid, p_attempts jsonb) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v jsonb := public._play_submit_rated(p_session, p_attempts);
begin
  return jsonb_set(v, '{achievements}', coalesce((
    select jsonb_agg(a.name order by a.sort) from public.achievements a
    where a.id in (select jsonb_array_elements_text(v -> 'achievements'))), '[]'::jsonb));
end $$;

-- ─────────────────────────────────────────── Sécurité : tables sans accès direct, RPC ouvertes aux connectés
alter table public.user_chests enable row level security;
alter table public.items enable row level security;
alter table public.user_items enable row level security;
alter table public.help_ticket_uses enable row level security;
revoke all on public.user_chests, public.items, public.user_items, public.help_ticket_uses from public, anon, authenticated;

-- Fonctions internes créées ici : jamais appelables directement (Supabase accorde l'exécution par défaut).
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and p.proname in ('_give_chest', '_give_item', '_tree_max', '_tree_stage', '_tree_fruits', '_tree_next',
                        '_tree_stage_name', '_xp_level', '_ledger_levels', '_mastery_cote', '_unlock', '_check_achievements',
                        '_tree_json', '_leon_outfit', '_quests_period', '_referral_on_first_daily', '_play_submit_rated',
                        '_mastery_sync', '_domains_mastery')
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', f.sig);
  end loop;
end $$;

do $$
declare f text;
begin
  foreach f in array array[
    'play_submit(uuid,jsonb)', 'play_spend_help(uuid,uuid,text)', 'achievements_mine()',
    'trophies_overview()', 'chest_open(uuid)', 'tree_feed(int,uuid)', 'leon_equip(text,text)', 'progression_overview()'
  ] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- Chemin de recherche figé pour les fonctions (re)créées ici (voir 0018).
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

-- ─────────────────────────────────────────── Joueurs existants
-- Arbre : 1 graine pour 10 XP déjà gagnés, au plus « Jeune plant » (600). Étapes et niveaux déjà atteints : pas de coffre.
update public.profiles set
  tree_points = least(xp_total / 10, 600),
  tree_stage_rewarded = public._tree_stage(least(xp_total / 10, 600)),
  level_rewarded = public._xp_level(xp_total);

-- Trophées déjà mérités : débloqués d'office, sans coffre.
insert into public.user_achievements (user_id, achievement_id, unlocked_at)
select s.user_id, a.id, now()
from public.achievements a
join public.user_skills s on s.scope_id = a.domain_id
where a.category = 'mastery' and s.n >= public._c_placement() and public._cote(s.mu) >= public._mastery_cote(a.tier)
on conflict do nothing;
insert into public.user_achievements (user_id, achievement_id, unlocked_at)
select distinct s.user_id, 'placed', now() from public.user_skills s where s.is_domain and s.n >= public._c_placement()
on conflict do nothing;

-- Un coffre d'or de bienvenue pour chaque joueur existant.
insert into public.user_chests (user_id, tier, source, idempotency_key)
select id, 'gold', 'welcome', 'welcome' from public.profiles
on conflict do nothing;
