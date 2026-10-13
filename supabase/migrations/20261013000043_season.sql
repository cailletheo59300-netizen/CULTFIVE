-- ─────────────────────────────────────────── 0043 · Pass de saison, piste gratuite (D-049)
-- 30 paliers de 150 points sur 61 jours. Points calculés à la lecture à partir de ce qui est déjà enregistré (jamais
-- comptés deux fois) : défis du jour (15, bonus 15), défis de la semaine (40, bonus 60), 12 missions de saison (75).
-- Récompenses récupérées palier par palier ; après le 30, un coffre en bois tous les 150 points (10 au plus).
-- Le Pass+ (piste payante) viendra plus tard.

create table public.seasons (
  id         int  primary key,
  name       text not null,
  starts_on  date not null,
  ends_on    date not null check (ends_on > starts_on)
);

-- Récompenses de la piste gratuite. kind : chest (item = wood|silver|gold), ticket, token, cosmetic (item = id d'habillage),
-- gold_pack (pochette dorée), final (dos Nuit étoilée + pochette dorée).
create table public.season_rewards (
  season_id  int  not null references public.seasons(id) on delete cascade,
  tier       int  not null check (tier between 1 and 30),
  kind       text not null check (kind in ('chest', 'ticket', 'token', 'cosmetic', 'final')),
  item       text,
  qty        int  not null default 1 check (qty > 0),
  label      text not null,
  icon       text not null,
  primary key (season_id, tier)
);

create table public.season_claims (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  season_id  int  not null references public.seasons(id) on delete cascade,
  tier       int  not null,            -- 1 à 30 ; 31 et plus : coffres en bois après le pass
  claimed_at timestamptz not null default now(),
  primary key (user_id, season_id, tier)
);

alter table public.seasons enable row level security;
alter table public.season_rewards enable row level security;
alter table public.season_claims enable row level security;
revoke all on public.seasons, public.season_rewards, public.season_claims from public, anon, authenticated;

-- Saison 1 : à partir du jour du déploiement, 61 jours (date ajustable à la mise en ligne).
insert into public.seasons (id, name, starts_on, ends_on) values (1, 'Saison 1', current_date, current_date + 61);

insert into public.season_rewards (season_id, tier, kind, item, qty, label, icon) values
  (1, 1, 'chest', 'wood', 1, 'Coffre en bois', 'chest_wood'),
  (1, 2, 'cosmetic', 'autoc.s1', 1, 'Autocollant « Saison 1 »', 'autoc_s1'),
  (1, 3, 'ticket', null, 1, 'Ticket de pochette', 'ticket_pochette'),
  (1, 4, 'chest', 'wood', 1, 'Coffre en bois', 'chest_wood'),
  (1, 5, 'cosmetic', 'titre.curieux', 1, 'Titre « Curieux »', 'titre_curieux'),
  (1, 6, 'ticket', null, 1, 'Ticket de pochette', 'ticket_pochette'),
  (1, 7, 'chest', 'silver', 1, 'Coffre en argent', 'chest_silver'),
  (1, 8, 'cosmetic', 'cadre.citrouille', 1, 'Cadre Citrouille', 'cadre_citrouille'),
  (1, 9, 'ticket', null, 1, 'Ticket de pochette', 'ticket_pochette'),
  (1, 10, 'cosmetic', 'dos.soleil', 1, 'Dos Soleil', 'dos_soleil'),
  (1, 11, 'chest', 'silver', 1, 'Coffre en argent', 'chest_silver'),
  (1, 12, 'cosmetic', 'titrej.explorateur', 1, 'Titre « Explorateur »', 'titrej_explorateur'),
  (1, 13, 'ticket', null, 1, 'Ticket de pochette', 'ticket_pochette'),
  (1, 14, 'chest', 'silver', 1, 'Coffre en argent', 'chest_silver'),
  (1, 15, 'cosmetic', 'socle.marbre', 1, 'Socle Marbre', 'socle_marbre'),
  (1, 16, 'ticket', null, 1, 'Ticket de pochette', 'ticket_pochette'),
  (1, 17, 'chest', 'silver', 1, 'Coffre en argent', 'chest_silver'),
  (1, 18, 'cosmetic', 'autoc.halloween', 1, 'Autocollant « Halloween »', 'autoc_halloween'),
  (1, 19, 'ticket', null, 1, 'Ticket de pochette', 'ticket_pochette'),
  (1, 20, 'token', null, 1, 'Jeton Prestige', 'jeton'),
  (1, 21, 'chest', 'gold', 1, 'Coffre en or', 'chest_gold'),
  (1, 22, 'cosmetic', 'titre.erudit', 1, 'Titre « Érudit »', 'titre_erudit'),
  (1, 23, 'ticket', null, 1, 'Ticket de pochette', 'ticket_pochette'),
  (1, 24, 'chest', 'gold', 1, 'Coffre en or', 'chest_gold'),
  (1, 25, 'cosmetic', 'titrej.batisseur', 1, 'Titre « Bâtisseur »', 'titrej_batisseur'),
  (1, 26, 'ticket', null, 1, 'Ticket de pochette', 'ticket_pochette'),
  (1, 27, 'chest', 'gold', 1, 'Coffre en or', 'chest_gold'),
  (1, 28, 'cosmetic', 'couv.automne', 1, 'Couverture « Automne »', 'couv_automne'),
  (1, 29, 'chest', 'gold', 2, 'Deux coffres en or', 'chest_savant'),
  (1, 30, 'final', 'dos.nuit', 1, 'Dos Nuit étoilée + pochette dorée', 'final_gratuit');

create or replace function public._season_rule(p_key text) returns int language sql immutable as $$
  select case p_key
    when 'tier_points' then 150 when 'tiers' then 30 when 'extra_chests' then 10
    when 'day' then 15 when 'day_bonus' then 15 when 'week' then 40 when 'week_bonus' then 60 when 'mission' then 75
  end
$$;

-- Saison en cours (la plus récente déjà commencée).
create or replace function public._season_current() returns public.seasons language sql stable as $$
  select * from public.seasons where starts_on <= (public._now() at time zone 'UTC')::date order by starts_on desc limit 1
$$;

-- Les 12 missions de saison : progression mesurée sur la saison (ou sur l'album pour ce qui se possède).
create or replace function public._season_missions(p_user uuid, s public.seasons)
returns table (slot int, label text, progress int, target int) language plpgsql stable as $$
#variable_conflict use_column
declare
  v_tz text := public._user_tz(p_user);
  v_from timestamptz := (s.starts_on::timestamp) at time zone v_tz;
  v_to timestamptz := (s.ends_on::timestamp) at time zone v_tz;
begin
  return query
  select m.slot, m.label, least(m.progress, m.target), m.target from (values
    (1, 'Finis une page de l''album', (
       select count(*)::int from public.album_pages p
       where not exists (select 1 from public.album_cards c where c.page_key = p.key
                         and not exists (select 1 from public.user_cards uc where uc.user_id = p_user and uc.slot = 0 and uc.card_id = c.id))), 1),
    (2, 'Ouvre 5 pochettes Histoire', (select count(*)::int from public.album_openings
       where user_id = p_user and slot = 0 and series = 'history' and created_at >= v_from and created_at < v_to), 5),
    (3, 'Fabrique une carte dans l''album', (select count(*)::int from public.ledger
       where user_id = p_user and reason = 'album_craft' and created_at >= v_from and created_at < v_to), 1),
    (4, 'Obtiens une carte brillante', (select count(*)::int from public.user_cards where user_id = p_user and slot = 0 and shiny), 1),
    (5, 'Trouve une légendaire', (select count(*)::int from public.user_cards uc join public.album_cards c on c.id = uc.card_id
       where uc.user_id = p_user and uc.slot = 0 and c.rarity = 'legend'), 1),
    (6, 'Ouvre 10 pochettes', (select count(*)::int from public.album_openings
       where user_id = p_user and slot = 0 and created_at >= v_from and created_at < v_to), 10),
    (7, 'Gagne 3 duels', (select count(*)::int from public.duels
       where winner_id = p_user and status = 'finished' and finished_at >= v_from and finished_at < v_to), 3),
    (8, 'Fais 7 jours de suite', (select coalesce(max(streak_after), 0)::int from public.daily_runs
       where user_id = p_user and daily_date >= s.starts_on and daily_date < s.ends_on), 7),
    (9, 'Réussis un 5 du jour parfait', public._quest_progress(p_user, 'daily_perfect', null, s.starts_on, s.ends_on), 1),
    (10, 'Obtiens 3 étoiles sur 3 cartes', (select count(*)::int from public._album_stars(p_user) st
       join public.user_cards uc on uc.card_id = st.card_id and uc.user_id = p_user and uc.slot = 0 where st.stars = 3), 3),
    (11, 'Complète 10 cartes Nature', (select count(*)::int from public.user_cards uc
       join public.album_cards c on c.id = uc.card_id join public.album_pages p on p.key = c.page_key
       where uc.user_id = p_user and uc.slot = 0 and p.domain_id = 'nature'), 10),
    (12, 'Joue dans 8 domaines différents', public._quest_progress(p_user, 'domains_played', null, s.starts_on, s.ends_on), 8)
  ) as m(slot, label, progress, target);
end $$;

-- Points de saison : défis remplis pendant la saison, bonus des périodes complètes, missions remplies.
create or replace function public._season_points(p_user uuid, s public.seasons) returns int language sql stable as $$
  select
    coalesce((select sum(case when q.period = 'day' then public._season_rule('day') else public._season_rule('week') end)
              from public.user_quests q
              where q.user_id = p_user and q.completed_at is not null
                and q.period_start >= s.starts_on and q.period_start < s.ends_on), 0)::int
  + coalesce((select sum(case when g.period = 'day' then public._season_rule('day_bonus') else public._season_rule('week_bonus') end)
              from (select q.period, q.period_start from public.user_quests q
                    where q.user_id = p_user and q.period_start >= s.starts_on and q.period_start < s.ends_on
                    group by q.period, q.period_start having bool_and(q.completed_at is not null)) g), 0)::int
  + (select count(*)::int from public._season_missions(p_user, s) m where m.progress >= m.target) * public._season_rule('mission')
$$;

-- Donne une récompense de palier.
create or replace function public._season_give(p_user uuid, rw public.season_rewards) returns void language plpgsql as $$
declare
  v_key text := 'season:' || rw.season_id || ':' || rw.tier;
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
      insert into public.user_cosmetics (user_id, item_id, source) values (p_user, rw.item, 'season') on conflict do nothing;
    when 'final' then
      insert into public.user_cosmetics (user_id, item_id, source) values (p_user, rw.item, 'season') on conflict do nothing;
      update public.user_album set gold_packs = gold_packs + 1 where user_id = p_user;
  end case;
end $$;

-- ─────────────────────────────────────────── API de l'app
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
                  'claimed', exists (select 1 from public.season_claims c where c.user_id = v_user and c.season_id = s.id and c.tier = rw.tier))
                  order by rw.tier), '[]') from public.season_rewards rw where rw.season_id = s.id),
    'extra_chests', jsonb_build_object('earned', v_extra,
                    'claimed', (select count(*) from public.season_claims c where c.user_id = v_user and c.season_id = s.id and c.tier > 30)),
    'points_rules', jsonb_build_object('day', public._season_rule('day'), 'day_bonus', public._season_rule('day_bonus'),
                    'week', public._season_rule('week'), 'week_bonus', public._season_rule('week_bonus'), 'mission', public._season_rule('mission')),
    'missions', (select coalesce(jsonb_agg(jsonb_build_object('slot', m.slot, 'label', m.label, 'progress', m.progress,
                  'target', m.target, 'done', m.progress >= m.target) order by m.slot), '[]') from public._season_missions(v_user, s) m));
end $$;

-- Récupère la récompense d'un palier atteint (une seule fois).
create or replace function public.season_claim(p_tier int) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  s public.seasons := public._season_current();
  rw public.season_rewards;
begin
  if s.id is null then raise exception 'no_season'; end if;
  select * into rw from public.season_rewards where season_id = s.id and tier = p_tier;
  if not found then raise exception 'invalid_tier'; end if;
  perform 1 from public.profiles where id = v_user for update;
  if public._season_points(v_user, s) < p_tier * public._season_rule('tier_points') then raise exception 'tier_not_reached'; end if;
  insert into public.season_claims (user_id, season_id, tier, claimed_at) values (v_user, s.id, p_tier, public._now())
  on conflict do nothing;
  if not found then raise exception 'already_claimed'; end if;
  perform public._season_give(v_user, rw);
  return jsonb_build_object('tier', p_tier, 'kind', rw.kind, 'label', rw.label);
end $$;

-- Après le palier 30 : un coffre en bois tous les 150 points (10 au plus). Récupère ceux qui sont gagnés.
create or replace function public.season_claim_extra() returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  s public.seasons := public._season_current();
  v_earned int;
  v_claimed int;
  i int;
begin
  if s.id is null then raise exception 'no_season'; end if;
  perform 1 from public.profiles where id = v_user for update;
  v_earned := least(greatest(public._season_points(v_user, s) / public._season_rule('tier_points') - public._season_rule('tiers'), 0),
                    public._season_rule('extra_chests'));
  select count(*) into v_claimed from public.season_claims where user_id = v_user and season_id = s.id and tier > 30;
  for i in v_claimed + 1 .. v_earned loop
    insert into public.season_claims (user_id, season_id, tier, claimed_at) values (v_user, s.id, 30 + i, public._now());
    perform public._give_chest(v_user, 'wood', 'season_extra', i::text, 'season:' || s.id || ':extra:' || i);
  end loop;
  return jsonb_build_object('claimed', greatest(v_earned - v_claimed, 0));
end $$;

-- ─────────────────────────────────────────── Droits
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and p.proname in ('_season_rule', '_season_current', '_season_missions', '_season_points', '_season_give')
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', f.sig);
    execute format('alter function %s set search_path = public, pg_temp', f.sig);
  end loop;
end $$;

do $$
declare f text;
begin
  foreach f in array array['season_overview()', 'season_claim(int)', 'season_claim_extra()'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
