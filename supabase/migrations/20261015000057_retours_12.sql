-- ─────────────────────────────────────────── 0057 · Retours pour la 1.2
-- 1. Tickets de pochette : 5 au plus. Chaque ticket en trop devient 30 neurones (pass, coffres, pub, tout).
-- 2. Questions « carte » (map_pick : « Touche l'emplacement de X ») : retirées du 5 du jour (trop répétitives),
--    gardées dans les parties mais plus difficiles (+20 de difficulté).
-- 3. 5 du jour un peu plus original : 2 questions d'un nouveau type plus souvent (65 % au lieu de 35 %).
-- 4. Défis cliquables : chaque défi (jour, semaine, saison) dit où aller pour le faire.

-- ─────────────────────────────────────────── 1. Tickets : 5 au plus
create or replace function public._album_rule(p_key text) returns integer
language sql immutable set search_path = public, pg_temp as $$
  select case p_key
    when 'pack_price' then 150
    when 'gold_price' then 900
    when 'pity' then 40
    when 'welcome_tickets' then 3
    when 'stars_days' then 60
    when 'unlimited' then 999999
    when 'ticket_max' then 5
    when 'ticket_overflow' then 30
  end
$$;

-- Toute hausse au-delà de 5 est convertie au même moment : le surplus part en neurones (journal « ticket_overflow »).
create or replace function public._ticket_cap() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_extra int := new.tickets - public._album_rule('ticket_max');
begin
  if v_extra > 0 then
    new.tickets := public._album_rule('ticket_max');
    perform public._grant(new.user_id, 'seeds', v_extra * public._album_rule('ticket_overflow'), 'ticket_overflow',
                          v_extra::text, 'ticket_overflow:' || gen_random_uuid());
  end if;
  return new;
end $$;
revoke all on function public._ticket_cap() from public, anon, authenticated;

drop trigger if exists user_album_ticket_cap on public.user_album;
create trigger user_album_ticket_cap before insert or update of tickets on public.user_album
for each row execute function public._ticket_cap();

-- Les joueurs qui ont déjà plus de 5 tickets : conversion tout de suite (le déclencheur s'en charge).
update public.user_album set tickets = tickets where tickets > public._album_rule('ticket_max');

-- ─────────────────────────────────────────── 2 et 3. 5 du jour
do $$
declare v_old text; v_new text;
begin
  v_old := pg_get_functiondef('public._generate_daily_set'::regproc);
  v_new := replace(v_old, $o$where q.status = 'published'
        and (lvl >= 1 or not q.needs_review)$o$, $n$where q.status = 'published' and q.type <> 'map_pick'
        and (lvl >= 1 or not q.needs_review)$n$);
  v_new := replace(v_new, $o$where q.status = 'published' and public._is_classic(q.type)$o$,
                          $n$where q.status = 'published' and q.type <> 'map_pick' and public._is_classic(q.type)$n$);
  v_new := replace(v_new, 'v_fun_n := case when random() < 0.65 then 1 else 2 end',
                          'v_fun_n := case when random() < 0.35 then 1 else 2 end');
  if (length(v_new) - length(replace(v_new, 'map_pick', ''))) / length('map_pick') <> 2 or v_new not like '%< 0.35 then 1%' then
    raise exception '0057: _generate_daily_set inchangée';
  end if;
  execute v_new;
end $$;

-- Questions carte : +20 de difficulté (servies aux bons joueurs, rarement aux débutants).
update public.questions set
  difficulty_initial = least(difficulty_initial + 20, 95),
  difficulty_min = least(difficulty_min + 20, 95),
  difficulty_max = least(difficulty_max + 20, 100),
  difficulty_observed = least(difficulty_observed + 20, 100)
where type = 'map_pick';

-- ─────────────────────────────────────────── 4. Défis cliquables
-- Chaque défi dit où aller pour le faire (« goal ») : l'app y emmène le joueur quand il le touche.
-- daily : 5 du jour · play : Jouer · domain : un domaine (« param ») · errors : « Revoir mes erreurs »
-- · album : l'album · comptoir : le comptoir (pochettes) · duels : l'onglet Amis.
create or replace function public._quest_goal(p_metric text) returns text
language sql immutable set search_path = public, pg_temp as $$
  select case p_metric
    when 'daily_done' then 'daily'
    when 'daily_perfect' then 'daily'
    when 'correct_domain' then 'domain'
    when 'errors_corrected' then 'errors'
    else 'play' end
$$;

-- Missions de saison, par numéro (même liste pour toutes les saisons, voir _season_missions).
create or replace function public._mission_goal(p_slot int) returns text
language sql immutable set search_path = public, pg_temp as $$
  select case p_slot
    when 2 then 'comptoir' when 6 then 'comptoir'
    when 7 then 'duels'
    when 8 then 'daily' when 9 then 'daily'
    when 12 then 'play'
    else 'album' end
$$;

do $$
declare v_old text; v_new text;
begin
  v_old := pg_get_functiondef('public._quests_period(uuid, text, date, jsonb)'::regprocedure);
  v_new := replace(v_old, $o$jsonb_build_object('slot', q.slot, 'label', q.label,$o$,
                          $n$jsonb_build_object('slot', q.slot, 'goal', public._quest_goal(q.metric), 'param', q.param, 'label', q.label,$n$);
  if v_new = v_old then raise exception '0057: _quests_period inchangée'; end if;
  execute v_new;

  v_old := pg_get_functiondef('public.season_overview()'::regprocedure);
  v_new := replace(v_old, $o$jsonb_build_object('slot', m.slot, 'label', m.label,$o$,
                          $n$jsonb_build_object('slot', m.slot, 'goal', public._mission_goal(m.slot), 'label', m.label,$n$);
  if v_new = v_old then raise exception '0057: season_overview inchangée'; end if;
  execute v_new;
end $$;
