-- Objets avant la partie (D-119) : 5 objets à utiliser avant une partie, rangés dans user_items (sorte « boost »).
--   Parties classées (partie rapide, partie classée d'un domaine) :
--     · energy  Boisson énergisante : l'Elo gagné dans la partie compte double (les pertes restent normales) ;
--     · shield  Bouclier d'Elo : aucune perte d'Elo dans la partie ;
--     · bet     Pari ×3 : 8 bonnes réponses sur 10 (80 %) ou plus, l'Elo gagné compte triple ; sinon aucun gain et
--               une perte doublée. Seul (ni Boisson ni Bouclier avec).
--   Survie :
--     · lifeline Bouclier de survie : une mauvaise réponse pardonnée ;
--     · hourglass Sablier : +10 s à chaque question.
-- Un objet se pose après le tirage de la partie et avant la première réponse ; il est retiré du stock à ce moment.
-- On en reçoit 1 de chaque au départ, rarement dans les coffres, et dans les packs de la boutique (heures sans pub en
-- plus) et l'offre de bienvenue (7 premiers jours, une seule fois).
-- Packs : Essai 1 de chaque + 1 h ; Joueur 2 Boissons, 2 Boucliers d'Elo, 1 de chaque autre + 6 h ; Big Pack 3 de
-- chaque + 24 h ; bienvenue 2 de chaque + 7 jours.

alter table public.items drop constraint items_kind_check;
alter table public.items add constraint items_kind_check check (kind in ('cosmetic', 'ticket', 'boost'));
insert into public.items (id, kind, name, sort) values
  ('energy', 'boost', 'Boisson énergisante', 200),
  ('shield', 'boost', 'Bouclier d''Elo', 201),
  ('bet', 'boost', 'Pari ×3', 202),
  ('lifeline', 'boost', 'Bouclier de survie', 203),
  ('hourglass', 'boost', 'Sablier', 204)
on conflict (id) do nothing;

-- Les objets s'additionnent sans plafond (les tickets d'aide restent plafonnés à 5).
create or replace function public._give_item(p_user uuid, p_item text, p_qty integer default 1) returns void
language plpgsql set search_path = public, extensions, pg_temp as $$
declare v_kind text := (select kind from public.items where id = p_item);
begin
  insert into public.user_items as ui (user_id, item_id, qty, acquired_at)
  values (p_user, p_item, case when v_kind = 'ticket' then least(p_qty, 5) else p_qty end, public._now())
  on conflict (user_id, item_id) do update set qty = case
    when v_kind = 'ticket' then least(ui.qty + excluded.qty, 5)
    when v_kind = 'boost' then ui.qty + excluded.qty
    else ui.qty end;
end $$;

-- Un de chaque objet, une fois par joueur (au premier passage).
alter table public.profiles add column if not exists starter_items_at timestamptz;

create or replace function public._starter_items(p_user uuid) returns void
language plpgsql set search_path = public, pg_temp as $$
declare v_item text;
begin
  update public.profiles set starter_items_at = public._now() where id = p_user and starter_items_at is null;
  if not found then return; end if;
  foreach v_item in array array['energy', 'shield', 'bet', 'lifeline', 'hourglass'] loop
    perform public._give_item(p_user, v_item, 1);
  end loop;
end $$;

create or replace function public._boost_stock(p_user uuid) returns jsonb
language sql stable set search_path = public, pg_temp as $$
  select jsonb_object_agg(i.id, coalesce(ui.qty, 0) order by i.sort)
  from public.items i left join public.user_items ui on ui.item_id = i.id and ui.user_id = p_user
  where i.kind = 'boost'
$$;

-- Retire un objet du stock (ou refuse).
create or replace function public._take_boost(p_user uuid, p_item text) returns void
language plpgsql set search_path = public, pg_temp as $$
begin
  update public.user_items set qty = qty - 1 where user_id = p_user and item_id = p_item and qty > 0;
  if not found then raise exception 'no_item'; end if;
end $$;

-- ─────────────────────────────────────────── Parties classées

alter table public.play_sessions add column if not exists boosts text[] not null default '{}';
alter table public.play_sessions add column if not exists boosts_done bool not null default false;

-- Objets posés sur une partie classée, avant la première réponse.
create or replace function public.play_boost(p_session uuid, p_items text[]) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  s public.play_sessions;
  v_item text;
  v_items text[] := array(select distinct unnest(coalesce(p_items, '{}')));
begin
  perform public._starter_items(v_user);
  select * into s from public.play_sessions where id = p_session and user_id = v_user for update;
  if not found then raise exception 'session_not_found'; end if;
  if not s.ranked or s.mode not in ('quick', 'training') then raise exception 'not_ranked'; end if;
  if s.completed_at is not null or cardinality(s.boosts) > 0
     or exists (select 1 from public.question_attempts where session_id = p_session) then
    raise exception 'already_started';
  end if;
  if exists (select 1 from unnest(v_items) x where x not in ('energy', 'shield', 'bet')) then raise exception 'invalid_item'; end if;
  if 'bet' = any(v_items) and cardinality(v_items) > 1 then raise exception 'bet_alone'; end if;
  foreach v_item in array v_items loop
    perform public._take_boost(v_user, v_item);
  end loop;
  update public.play_sessions set boosts = v_items where id = p_session;
  return jsonb_build_object('boosts', to_jsonb(v_items), 'stock', public._boost_stock(v_user));
end $$;

-- Effet des objets à la fin d'une partie classée, une seule fois (un renvoi de la file hors ligne ne rejoue rien).
-- L'Elo est déjà à jour (réponse par réponse, puis plafonné par partie) : on reprend l'écart de chaque domaine.
create or replace function public._apply_play_boosts(p_user uuid, p_session uuid) returns jsonb
language plpgsql set search_path = public, pg_temp as $$
declare
  s public.play_sessions;
  r record;
  v_rate real;
  v_won bool;
  v_delta real;
  v_new real;
  v_extra real := 0;
begin
  select * into s from public.play_sessions where id = p_session and user_id = p_user for update;
  if not found or cardinality(s.boosts) = 0 then return null; end if;
  if s.boosts_done then return jsonb_build_object('items', to_jsonb(s.boosts)); end if;
  select avg(a.is_correct::int)::real into v_rate from public.question_attempts a where a.session_id = p_session and a.user_id = p_user;
  v_won := coalesce(v_rate, 0) >= 0.8;
  for r in
    select q.domain_id, (array_agg(a.dom_elo_before order by a.created_at, a.id))[1] as before
    from public.question_attempts a join public.questions q on q.id = a.question_id
    where a.session_id = p_session and a.user_id = p_user and a.dom_elo_before is not null
    group by q.domain_id
  loop
    select r.before, s2.elo - r.before into v_new, v_delta from public.user_skills s2
    where s2.user_id = p_user and s2.scope_id = r.domain_id for update;
    if v_delta is null then continue; end if;
    if 'bet' = any(s.boosts) then
      v_delta := case when v_won then case when v_delta > 0 then v_delta * 3 else v_delta end
                      else case when v_delta < 0 then v_delta * 2 else 0 end end;
    else
      if 'energy' = any(s.boosts) and v_delta > 0 then v_delta := v_delta * 2; end if;
      if 'shield' = any(s.boosts) and v_delta < 0 then v_delta := 0; end if;
    end if;
    v_new := greatest(r.before + v_delta, public._elo_c('floor'));
    v_extra := v_extra + (v_new - (select elo from public.user_skills where user_id = p_user and scope_id = r.domain_id));
    update public.user_skills set elo = v_new where user_id = p_user and scope_id = r.domain_id;
    update public.user_skill_snapshots set elo = v_new
     where user_id = p_user and scope_id = r.domain_id and day = (public._now() at time zone 'UTC')::date;
  end loop;
  update public.play_sessions set boosts_done = true where id = p_session;
  return jsonb_build_object('items', to_jsonb(s.boosts), 'bet_won', case when 'bet' = any(s.boosts) then v_won end,
                            'elo_extra', round(v_extra)::int);
end $$;

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

-- Les objets jouent avant le calcul des variations d'Elo affichées dans le bilan.
select pg_temp.patch('public._play_submit_rated(uuid, jsonb)', array[
  '  -- Variation d''Elo par domaine touché (partie classée) : avant la 1re réponse de la partie, maintenant.',
  '  v := v || jsonb_build_object(''boosts'', case when v_ranked then public._apply_play_boosts(v_user, p_session) end);
  -- Variation d''Elo par domaine touché (partie classée) : avant la 1re réponse de la partie, maintenant.'
]);

-- ─────────────────────────────────────────── Survie

alter table public.survival_runs add column if not exists boosts text[] not null default '{}';
alter table public.survival_runs add column if not exists lifeline_used bool not null default false;

create or replace function public._survival_seconds(r public.survival_runs) returns int
language sql stable set search_path = public, pg_temp as $$
  select public._survival_rule('seconds') + case when 'hourglass' = any(r.boosts) then 10 else 0 end
$$;

-- Objets posés sur une Survie, avant la première question.
create or replace function public.survival_boost(p_run uuid, p_items text[]) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  r public.survival_runs;
  v_item text;
  v_items text[] := array(select distinct unnest(coalesce(p_items, '{}')));
begin
  perform public._starter_items(v_user);
  select * into r from public.survival_runs where id = p_run and user_id = v_user for update;
  if not found then raise exception 'survival_not_found'; end if;
  if r.ended_at is not null or cardinality(r.question_ids) > 0 or cardinality(r.boosts) > 0 then raise exception 'already_started'; end if;
  if exists (select 1 from unnest(v_items) x where x not in ('lifeline', 'hourglass')) then raise exception 'invalid_item'; end if;
  foreach v_item in array v_items loop
    perform public._take_boost(v_user, v_item);
  end loop;
  update public.survival_runs set boosts = v_items where id = p_run returning * into r;
  return jsonb_build_object('boosts', to_jsonb(v_items), 'seconds', public._survival_seconds(r), 'stock', public._boost_stock(v_user));
end $$;

-- Sablier : le temps de la question. Bouclier de survie : la première erreur ne termine pas la partie (la question
-- suivante prend la place suivante ; le score ne compte que les bonnes réponses).
select pg_temp.patch('public.survival_answer(uuid, integer, jsonb, integer)', array[
  'v_late := v_server_ms > (public._survival_rule(''seconds'') + public._survival_rule(''grace'')) * 1000;',
  'v_late := v_server_ms > (public._survival_seconds(r) + public._survival_rule(''grace'')) * 1000;',
  '''is_correct'', v_prev.is_correct and p_position <= r.score,',
  '''is_correct'', v_prev.is_correct and p_position <= r.score + r.lifeline_used::int,',
  '  else
    update public.survival_runs set served_at = null where id = r.id;
    perform public._survival_end(r.id);
  end if;
  return jsonb_build_object(''position'', p_position, ''is_correct'', v_correct, ''duplicate'', false, ''counted_ms'', v_counted,
                            ''finished'', not v_correct, ''late'', v_late,',
  '  elsif ''lifeline'' = any(r.boosts) and not r.lifeline_used then
    update public.survival_runs set served_at = null, lifeline_used = true where id = r.id;
    return jsonb_build_object(''position'', p_position, ''is_correct'', false, ''duplicate'', false, ''counted_ms'', v_counted,
                              ''finished'', false, ''late'', v_late, ''lifeline_used'', true, ''error_transition'', v_res -> ''error_transition'')
           || public._question_reveal(q);
  else
    update public.survival_runs set served_at = null where id = r.id;
    perform public._survival_end(r.id);
  end if;
  return jsonb_build_object(''position'', p_position, ''is_correct'', v_correct, ''duplicate'', false, ''counted_ms'', v_counted,
                            ''finished'', not v_correct, ''late'', v_late,'
]);

select pg_temp.patch('public.survival_question(uuid, integer)', array[
  'elsif p_position = cardinality(r.question_ids) + 1 and p_position = r.score + 1 then',
  'elsif p_position = cardinality(r.question_ids) + 1 and p_position = r.score + 1 + r.lifeline_used::int then',
  'return public._question_public(q, r.id::text) || jsonb_build_object(''position'', p_position);',
  'return public._question_public(q, r.id::text) || jsonb_build_object(''position'', p_position, ''seconds'', public._survival_seconds(r));'
]);

-- ─────────────────────────────────────────── Coffres : un objet, rarement

select pg_temp.patch('public.chest_open(uuid)', array[
  '  v_contents jsonb;
begin',
  '  v_contents jsonb;
  v_boost text;
begin',
  '  perform public._grant(v_user, ''seeds'', v_seeds, ''chest'', c.id::text, ''chest:'' || c.id);',
  '  -- 0097 : un objet de temps en temps (bois 3 %, argent 8 %, or 20 %, savant 40 %).
  if random() < (case v_final when ''wood'' then 0.03 when ''silver'' then 0.08 when ''gold'' then 0.20 else 0.40 end) then
    v_boost := (array[''energy'', ''shield'', ''bet'', ''lifeline'', ''hourglass''])[1 + floor(random() * 5)::int];
    perform public._give_item(v_user, v_boost, 1);
  end if;
  perform public._grant(v_user, ''seeds'', v_seeds, ''chest'', c.id::text, ''chest:'' || c.id);',
  '    ''prestige_token'', v_token);',
  '    ''prestige_token'', v_token,
    ''boost'', v_boost);'
]);

-- ─────────────────────────────────────────── Boutique : packs et bienvenue

insert into public.shop_products (id, kind, label) values
  ('app.brainlix.pack.essai', 'consumable', 'Pack Essai'),
  ('app.brainlix.pack.joueur', 'consumable', 'Pack Joueur'),
  ('app.brainlix.pack.big', 'consumable', 'Big Pack'),
  ('app.brainlix.bienvenue', 'consumable', 'Offre de bienvenue')
on conflict (id) do nothing;

-- Contenu d'un produit : nombre de chaque objet et heures sans pub (propriétaire, 29/10).
create or replace function public._shop_contents(p_product text) returns jsonb
language sql immutable set search_path = public, pg_temp as $$
  select case p_product
    when 'app.brainlix.pack.essai' then
      '{"items": {"energy": 1, "shield": 1, "bet": 1, "lifeline": 1, "hourglass": 1}, "no_ads_hours": 1}'
    when 'app.brainlix.pack.joueur' then
      '{"items": {"energy": 2, "shield": 2, "bet": 1, "lifeline": 1, "hourglass": 1}, "no_ads_hours": 6}'
    when 'app.brainlix.pack.big' then
      '{"items": {"energy": 3, "shield": 3, "bet": 3, "lifeline": 3, "hourglass": 3}, "no_ads_hours": 24}'
    when 'app.brainlix.bienvenue' then
      '{"items": {"energy": 2, "shield": 2, "bet": 2, "lifeline": 2, "hourglass": 2}, "no_ads_hours": 168}'
  end::jsonb
$$;

-- Donne le contenu d'un achat (une fois par transaction). Un achat payé est toujours livré, même hors délai.
create or replace function public._shop_grant(p_user uuid, p_product text) returns void
language plpgsql set search_path = public, pg_temp as $$
declare
  v jsonb := public._shop_contents(p_product);
  v_item text;
begin
  if v is null then return; end if;
  perform public._starter_items(p_user);
  for v_item in select jsonb_object_keys(v -> 'items') loop
    perform public._give_item(p_user, v_item, (v -> 'items' ->> v_item)::int);
  end loop;
  update public.profiles
     set no_ads_until = greatest(coalesce(no_ads_until, public._now()), public._now()) + make_interval(hours => (v ->> 'no_ads_hours')::int)
   where id = p_user;
end $$;

select pg_temp.patch('public.iap_record(uuid, text, text, text, text, timestamp with time zone)', array[
  '  insert into public.purchases (transaction_id, original_transaction_id, user_id, product_id, environment, purchased_at, recorded_at)
  values (p_transaction, p_original, p_user, p_product, p_environment, p_purchased_at, public._now());',
  '  insert into public.purchases (transaction_id, original_transaction_id, user_id, product_id, environment, purchased_at, recorded_at)
  values (p_transaction, p_original, p_user, p_product, p_environment, p_purchased_at, public._now());
  perform public._shop_grant(p_user, p_product);'
]);

-- La boutique d'un joueur (boutique en argent réel, D-118 ; shop_overview reste la boutique en neurones) : objets, sans pub, offre de bienvenue (7 premiers jours, si pas déjà prise).
create or replace function public.boutique_overview() returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  p public.profiles;
  v_welcome_ends timestamptz;
begin
  perform public._starter_items(v_user);
  select * into p from public.profiles where id = v_user;
  v_welcome_ends := p.created_at + interval '7 days';
  return jsonb_build_object(
    'items', public._boost_stock(v_user),
    'no_ads', public._no_ads(v_user),
    'no_ads_forever', public._no_ads_forever(v_user),
    'no_ads_until', case when p.no_ads_until > public._now() then p.no_ads_until end,
    'welcome_until', case when v_welcome_ends > public._now()
                           and not exists (select 1 from public.purchases where user_id = v_user and product_id = 'app.brainlix.bienvenue')
                          then v_welcome_ends end);
end $$;

revoke execute on function public.play_boost(uuid, text[]), public.survival_boost(uuid, text[]), public.boutique_overview()
  from public, anon;
grant execute on function public.play_boost(uuid, text[]), public.survival_boost(uuid, text[]), public.boutique_overview()
  to authenticated;
revoke execute on function public._starter_items(uuid), public._boost_stock(uuid), public._take_boost(uuid, text),
  public._apply_play_boosts(uuid, uuid), public._survival_seconds(public.survival_runs), public._shop_contents(text),
  public._shop_grant(uuid, text)
  from public, anon, authenticated;
