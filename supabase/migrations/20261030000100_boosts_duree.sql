-- Objets qui durent (D-122, propriétaire, 30/10) : la Boisson énergisante dure 30 minutes (toutes les parties classées
-- commencées pendant ce temps : Elo gagné ×2) et le Bouclier d'Elo protège les 3 parties classées suivantes. Activer
-- une Boisson pendant qu'une autre court ajoute 30 minutes ; un Bouclier ajoute 3 parties. Le Pari ×3 reste pour une
-- partie, et il prime : une partie avec Pari ne profite ni de la Boisson ni du Bouclier (le Bouclier n'est pas usé).
-- Les objets de Survie ne changent pas.

alter table public.profiles add column if not exists energy_until timestamptz;
alter table public.profiles add column if not exists shield_games int not null default 0 check (shield_games >= 0);

-- Ce qui est en cours pour un joueur.
create or replace function public._boost_timers(p_user uuid) returns jsonb
language sql stable set search_path = public, pg_temp as $$
  select jsonb_build_object(
    'energy_until', case when p.energy_until > public._now() then p.energy_until end,
    'shield_games', p.shield_games)
  from public.profiles p where p.id = p_user
$$;

-- Active une Boisson (30 min de plus) ou un Bouclier (3 parties de plus), objet retiré du stock.
create or replace function public._boost_start(p_user uuid, p_item text) returns void
language plpgsql set search_path = public, pg_temp as $$
begin
  perform public._take_boost(p_user, p_item);
  if p_item = 'energy' then
    update public.profiles set energy_until = greatest(coalesce(energy_until, public._now()), public._now()) + interval '30 minutes'
    where id = p_user;
  elsif p_item = 'shield' then
    update public.profiles set shield_games = shield_games + 3 where id = p_user;
  end if;
end $$;

-- Objets posés avant une partie classée : la Boisson et le Bouclier s'activent (et valent pour cette partie), le Pari
-- est noté sur la partie.
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
    if v_item = 'bet' then
      perform public._take_boost(v_user, 'bet');
      update public.play_sessions set boosts = array['bet'] where id = p_session;
    else
      perform public._boost_start(v_user, v_item);
    end if;
  end loop;
  return jsonb_build_object('boosts', to_jsonb(v_items), 'stock', public._boost_stock(v_user)) || public._boost_timers(v_user);
end $$;

-- Fin d'une partie classée : Pari noté sur la partie, sinon Boisson en cours (partie commencée avant la fin des 30
-- minutes) et Bouclier (une partie de moins). Une seule fois par partie.
create or replace function public._apply_play_boosts(p_user uuid, p_session uuid) returns jsonb
language plpgsql set search_path = public, pg_temp as $$
declare
  s public.play_sessions;
  p public.profiles;
  r record;
  v_boosts text[];
  v_rate real;
  v_won bool;
  v_delta real;
  v_new real;
  v_extra real := 0;
begin
  select * into s from public.play_sessions where id = p_session and user_id = p_user for update;
  if not found then return null; end if;
  if s.boosts_done then
    return case when cardinality(s.boosts) > 0 then jsonb_build_object('items', to_jsonb(s.boosts)) end;
  end if;
  update public.play_sessions set boosts_done = true where id = p_session;
  if s.mode not in ('quick', 'training') then return null; end if;
  select * into p from public.profiles where id = p_user for update;
  v_boosts := s.boosts;
  if not ('bet' = any(v_boosts)) then
    if p.energy_until > s.created_at then v_boosts := v_boosts || 'energy'::text; end if;
    if p.shield_games > 0 then
      v_boosts := v_boosts || 'shield'::text;
      update public.profiles set shield_games = shield_games - 1 where id = p_user;
    end if;
  end if;
  if cardinality(v_boosts) = 0 then return null; end if;
  update public.play_sessions set boosts = v_boosts where id = p_session;

  select avg(a.is_correct::int)::real into v_rate from public.question_attempts a where a.session_id = p_session and a.user_id = p_user;
  v_won := coalesce(v_rate, 0) >= 0.8;
  for r in
    select q.domain_id, (array_agg(a.dom_elo_before order by a.created_at, a.id))[1] as before
    from public.question_attempts a join public.questions q on q.id = a.question_id
    where a.session_id = p_session and a.user_id = p_user and a.dom_elo_before is not null
    group by q.domain_id
  loop
    select s2.elo - r.before into v_delta from public.user_skills s2
    where s2.user_id = p_user and s2.scope_id = r.domain_id for update;
    if v_delta is null then continue; end if;
    if 'bet' = any(v_boosts) then
      v_delta := case when v_won then case when v_delta > 0 then v_delta * 3 else v_delta end
                      else case when v_delta < 0 then v_delta * 2 else 0 end end;
    else
      if 'energy' = any(v_boosts) and v_delta > 0 then v_delta := v_delta * 2; end if;
      if 'shield' = any(v_boosts) and v_delta < 0 then v_delta := 0; end if;
    end if;
    v_new := greatest(r.before + v_delta, public._elo_c('floor'));
    v_extra := v_extra + (v_new - (select elo from public.user_skills where user_id = p_user and scope_id = r.domain_id));
    update public.user_skills set elo = v_new where user_id = p_user and scope_id = r.domain_id;
    update public.user_skill_snapshots set elo = v_new
     where user_id = p_user and scope_id = r.domain_id and day = (public._now() at time zone 'UTC')::date;
  end loop;
  return jsonb_build_object('items', to_jsonb(v_boosts), 'bet_won', case when 'bet' = any(v_boosts) then v_won end,
                            'elo_extra', round(v_extra)::int) || public._boost_timers(p_user);
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

-- La boutique dit ce qui court.
select pg_temp.patch('public.boutique_overview()', array[
  '    ''items'', public._boost_stock(v_user),',
  '    ''items'', public._boost_stock(v_user),
    ''energy_until'', case when p.energy_until > public._now() then p.energy_until end,
    ''shield_games'', p.shield_games,'
]);

revoke execute on function public._boost_timers(uuid), public._boost_start(uuid, text) from public, anon, authenticated;
