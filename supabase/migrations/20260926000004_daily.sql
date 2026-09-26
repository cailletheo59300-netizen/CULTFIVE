-- CULT FIVE — 0004 Daily (« 5 du jour »)
-- Série commune par date, une tentative officielle, réponses jamais envoyées avant validation,
-- temps mesuré côté serveur, série, percentile honnête (réel ou estimation étiquetée).

create type public.run_status as enum ('in_progress', 'finished', 'expired');

create table public.daily_sets (
  daily_date  date primary key,
  source      text not null default 'auto' check (source in ('auto', 'manual')),
  created_at  timestamptz not null default now()
);

create table public.daily_set_items (
  daily_date   date not null references public.daily_sets(daily_date) on delete cascade,
  position     smallint not null check (position between 1 and 5),
  slot         public.daily_slot not null,
  question_id  uuid not null references public.questions(id) on delete restrict,
  replaced_at  timestamptz,
  primary key (daily_date, position),
  unique (daily_date, question_id)
);
create index on public.daily_set_items (question_id);

create table public.daily_runs (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references public.profiles(id) on delete cascade,
  daily_date         date not null,
  status             public.run_status not null default 'in_progress',
  started_at         timestamptz not null,
  deadline_at        timestamptz not null,
  finished_at        timestamptz,
  score              smallint check (score between 0 and 5),
  total_ms           int,
  xp_awarded         int not null default 0,
  seeds_awarded      int not null default 0,
  achievements       text[] not null default '{}',
  streak_after       int,
  unique (user_id, daily_date)
);
create index daily_runs_rank on public.daily_runs (daily_date, status, score desc, total_ms);
create index daily_runs_open on public.daily_runs (deadline_at) where status = 'in_progress';

create table public.daily_answers (
  run_id         uuid not null references public.daily_runs(id) on delete cascade,
  position       smallint not null check (position between 1 and 5),
  question_id    uuid not null references public.questions(id),
  served_at      timestamptz not null,
  answered_at    timestamptz,
  given          jsonb,
  is_correct     bool,
  client_ms      int,
  counted_ms     int,
  domain_before  real,
  domain_after   real,
  primary key (run_id, position)
);

-- ─────────────────────────────────────────── Dates & fuseaux
create or replace function public._user_tz(p_user uuid) returns text
language sql stable as $$
  select coalesce((select timezone from public.profiles where id = p_user), 'Europe/Paris')
$$;

create or replace function public._user_today(p_user uuid) returns date
language sql stable as $$
  select (public._now() at time zone public._user_tz(p_user))::date
$$;

-- Fin de la journée d'un utilisateur, en timestamptz.
create or replace function public._day_end(p_date date, p_tz text) returns timestamptz
language sql stable as $$
  select ((p_date + 1)::timestamp) at time zone p_tz
$$;

-- Questions protégées : Daily d'hier (fuseaux en retard), d'aujourd'hui et à venir.
create or replace function public._protected_daily_questions() returns uuid[]
language sql stable as $$
  select coalesce(array_agg(question_id), '{}')
  from public.daily_set_items
  where daily_date >= (public._now() at time zone 'UTC')::date - 1
$$;

-- ─────────────────────────────────────────── Génération
create or replace function public._generate_daily_set(p_date date) returns void
language plpgsql as $$
declare
  v_slots    public.daily_slot[];
  v_targets  real[];
  v_types    public.question_type[] := '{}';
  v_used     uuid[] := '{}';
  v_concepts text[] := '{}';
  v_pick uuid; v_concept text; v_type public.question_type;
begin
  perform pg_advisory_xact_lock(hashtext('daily:' || p_date::text));
  if exists (select 1 from public.daily_sets where daily_date = p_date) then return; end if;

  select array_agg(s order by random()) into v_slots from unnest(enum_range(null::public.daily_slot)) s;
  select array_agg(t order by random()) into v_targets from unnest(array[35, 45, 50, 55, 65]::real[]) t;
  insert into public.daily_sets (daily_date) values (p_date);

  for i in 1 .. 5 loop
    v_pick := null;
    -- 0 : toutes contraintes · 1 : sans fenêtre 180/60 j (mais pas de question vue ces 14 j) · 2 : tout
    for lvl in 0 .. 2 loop
      select q.id, q.concept_id, q.type into v_pick, v_concept, v_type
      from public.questions q
      join public.domains d on d.id = q.domain_id
      where q.status = 'published'
        and (lvl >= 1 or not q.needs_review)
        and (case when v_slots[i] = 'surprise' then d.daily_slot is null else d.daily_slot = v_slots[i] end)
        and q.id <> all (v_used)
        and q.concept_id <> all (v_concepts)
        and (lvl >= 1 or not exists (
              select 1 from public.daily_set_items i join public.questions q2 on q2.id = i.question_id
              where i.daily_date <> p_date and abs(i.daily_date - p_date) <= 180
                and (i.question_id = q.id or (q2.concept_id = q.concept_id and abs(i.daily_date - p_date) <= 60))))
        and (lvl >= 2 or not exists (
              select 1 from public.daily_set_items i
              where i.question_id = q.id and i.daily_date <> p_date and abs(i.daily_date - p_date) <= 14))
      -- Variété des types : pénalité douce (15 points par question déjà du même type), pas un filtre dur.
      order by abs(q.difficulty_effective - v_targets[i]) + random() * 8
               + 15 * (select count(*) from unnest(v_types) t where t = q.type)
      limit 1;
      exit when v_pick is not null;
    end loop;
    if v_pick is null then
      raise exception 'daily_generation_failed: no question for slot %', v_slots[i];
    end if;
    insert into public.daily_set_items (daily_date, position, slot, question_id) values (p_date, i, v_slots[i], v_pick);
    v_used := v_used || v_pick;
    v_concepts := v_concepts || v_concept;
    v_types := v_types || v_type;
  end loop;
end $$;

create or replace function public._ensure_daily_set(p_date date) returns void
language plpgsql as $$
begin
  if not exists (select 1 from public.daily_sets where daily_date = p_date) then
    perform public._generate_daily_set(p_date);
  end if;
end $$;

-- ─────────────────────────────────────────── Représentation publique d'une question (sans réponse)
-- Mélange déterministe (graine) : un rechargement renvoie le même ordre.
create or replace function public._question_public(q public.questions, p_seed text) returns jsonb
language plpgsql stable as $$
declare
  v_payload jsonb := q.payload;
begin
  if q.type = 'mcq' and not coalesce((q.payload ->> 'keep_order')::bool, false) then
    v_payload := jsonb_set(v_payload, '{options}',
      (select jsonb_agg(o order by md5(p_seed || (o ->> 'id'))) from jsonb_array_elements(q.payload -> 'options') o));
  elsif q.type = 'ordering' then
    v_payload := jsonb_set(v_payload, '{items}',
      (select jsonb_agg(o order by md5(p_seed || (o ->> 'id'))) from jsonb_array_elements(q.payload -> 'items') o));
  elsif q.type = 'pairs' then
    v_payload := jsonb_set(v_payload, '{right}',
      (select jsonb_agg(o order by md5(p_seed || (o ->> 'id'))) from jsonb_array_elements(q.payload -> 'right') o));
  end if;
  return jsonb_build_object(
    'id', q.id,
    'type', q.type,
    'domain_id', q.domain_id,
    'subdomain_id', q.subdomain_id,
    'prompt', q.prompt,
    'payload', v_payload);
end $$;

create or replace function public._question_reveal(q public.questions) returns jsonb
language sql stable as $$
  select jsonb_build_object('answer', q.answer, 'explanation', q.explanation, 'takeaway', q.takeaway,
                            'source', q.source, 'fact_as_of', q.fact_as_of)
$$;

-- ─────────────────────────────────────────── Série
create or replace function public._streak_on_finish(p_user uuid, p_date date) returns jsonb
language plpgsql as $$
declare
  p public.profiles;
  v_gap int;
  v_used int := 0;
  v_earned bool := false;
begin
  select * into p from public.profiles where id = p_user for update;
  if p.streak_last_date is not null and p_date <= p.streak_last_date then
    return jsonb_build_object('current', p.streak_current, 'best', p.streak_best, 'freeze_used', 0, 'freeze_earned', false);
  end if;
  v_gap := case when p.streak_last_date is null then null else p_date - p.streak_last_date - 1 end;
  if v_gap = 0 then
    p.streak_current := p.streak_current + 1;
  elsif v_gap is not null and v_gap <= p.streak_freezes and p.streak_current > 0 then
    v_used := v_gap;
    p.streak_freezes := p.streak_freezes - v_gap;
    p.streak_current := p.streak_current + 1;
  else
    p.streak_current := 1;
  end if;
  if p.streak_current % 7 = 0 and p.streak_freezes < 2 then
    p.streak_freezes := p.streak_freezes + 1; v_earned := true;
  end if;
  update public.profiles set
    streak_current = p.streak_current,
    streak_best = greatest(streak_best, p.streak_current),
    streak_last_date = p_date,
    streak_freezes = p.streak_freezes
  where id = p_user;
  return jsonb_build_object('current', p.streak_current, 'best', greatest(p.streak_best, p.streak_current),
                            'freeze_used', v_used, 'freeze_earned', v_earned);
end $$;

-- Série « vivante » affichable : 0 si elle est rompue et qu'aucun joker ne peut la sauver.
create or replace function public._streak_effective(p_user uuid) returns int
language sql stable as $$
  select case
    when p.streak_last_date is null then 0
    when public._user_today(p_user) - p.streak_last_date <= 1 then p.streak_current
    when public._user_today(p_user) - p.streak_last_date - 1 <= p.streak_freezes then p.streak_current
    else 0 end
  from public.profiles p where p.id = p_user
$$;

-- ─────────────────────────────────────────── Récompenses liées à une tentative
-- Erreur corrigée : récompensée seulement si l'erreur date d'au moins 1 h (anti-farm), plafond 10/jour.
create or replace function public._reward_correction(p_user uuid, p_res jsonb, p_key text) returns jsonb
language plpgsql as $$
declare v_xp int := 0; v_seeds int := 0;
begin
  if p_res ->> 'error_transition' = 'corrected'
     and (p_res ->> 'error_since') is not null
     and (p_res ->> 'error_since')::timestamptz <= public._now() - interval '1 hour' then
    v_xp    := public._grant_capped(p_user, 'xp', 15, 150, 'error_corrected', p_key, 'corr:xp:' || p_key);
    v_seeds := public._grant_capped(p_user, 'seeds', 3, 30, 'error_corrected', p_key, 'corr:seeds:' || p_key);
  end if;
  return jsonb_build_object('xp', v_xp, 'seeds', v_seeds);
end $$;

-- Stub remplacé par la migration sociale.
create or replace function public._referral_on_first_daily(p_user uuid) returns void
language sql as $$ select $$;

-- ─────────────────────────────────────────── Clôture
create or replace function public._daily_finish(p_run uuid, p_expired bool) returns void
language plpgsql as $$
declare
  r public.daily_runs;
  v_score int; v_total int;
  v_xp int := 0; v_seeds int := 0;
  v_ach text[] := '{}';
  v_streak jsonb;
begin
  select * into r from public.daily_runs where id = p_run for update;
  if r.status <> 'in_progress' then return; end if;

  select count(*) filter (where is_correct), coalesce(sum(counted_ms) filter (where answered_at is not null), 0)
    into v_score, v_total
  from public.daily_answers where run_id = p_run;

  if p_expired then
    update public.daily_runs set status = 'expired', finished_at = public._now(), score = v_score, total_ms = v_total
    where id = p_run;
    return;
  end if;

  v_streak := public._streak_on_finish(r.user_id, r.daily_date);

  if public._grant(r.user_id, 'xp', 30, 'daily_complete', p_run::text, 'daily_complete:' || p_run) then v_xp := v_xp + 30; end if;
  if public._grant(r.user_id, 'seeds', 10, 'daily_complete', p_run::text, 'daily_complete_seeds:' || p_run) then v_seeds := v_seeds + 10; end if;
  if v_score = 5 then
    if public._grant(r.user_id, 'xp', 20, 'daily_perfect', p_run::text, 'daily_perfect:' || p_run) then v_xp := v_xp + 20; end if;
    if public._grant(r.user_id, 'seeds', 10, 'daily_perfect', p_run::text, 'daily_perfect_seeds:' || p_run) then v_seeds := v_seeds + 10; end if;
  end if;
  v_xp := v_xp + 10 * v_score;  -- déjà crédité réponse par réponse ; total affiché

  if public._unlock(r.user_id, 'first_daily') then v_ach := v_ach || 'first_daily'::text; end if;
  if v_score = 5 and public._unlock(r.user_id, 'first_perfect') then v_ach := v_ach || 'first_perfect'::text; end if;
  if v_score = 5 and v_total < 60000 and public._unlock(r.user_id, 'fast_perfect') then v_ach := v_ach || 'fast_perfect'::text; end if;
  v_ach := v_ach || public._check_achievements(r.user_id);

  update public.daily_runs set
    status = 'finished', finished_at = public._now(), score = v_score, total_ms = v_total,
    xp_awarded = v_xp, seeds_awarded = v_seeds, achievements = v_ach,
    streak_after = (v_streak ->> 'current')::int
  where id = p_run;

  perform public._referral_on_first_daily(r.user_id);
end $$;

create or replace function public._expire_user_runs(p_user uuid) returns void
language plpgsql as $$
declare v_id uuid;
begin
  for v_id in select id from public.daily_runs
              where user_id = p_user and status = 'in_progress' and deadline_at < public._now() loop
    perform public._daily_finish(v_id, true);
  end loop;
end $$;

-- Tâche planifiée (pg_cron) : clôture des runs abandonnés + génération anticipée.
create or replace function public.cron_daily_maintenance() returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_id uuid; v_d date := (public._now() at time zone 'UTC')::date;
begin
  for v_id in select id from public.daily_runs where status = 'in_progress' and deadline_at < public._now() loop
    perform public._daily_finish(v_id, true);
  end loop;
  for i in -1 .. 2 loop
    perform public._ensure_daily_set(v_d + i);
  end loop;
end $$;

-- ─────────────────────────────────────────── Percentile
-- Estimation de référence : population μ ~ N(50, 15²), quadrature 21 points, Poisson-binomiale sur 5 questions.
create or replace function public._daily_estimate_top(p_date date, p_score int) returns int
language plpgsql stable as $$
declare
  v_b real[];
  v_dist double precision[] := array[0,0,0,0,0,0];
  v_local double precision[];
  v_w double precision; v_wsum double precision := 0;
  v_mu double precision; v_p double precision;
  v_above double precision := 0;
begin
  select array_agg(q.difficulty_effective order by i.position) into v_b
  from public.daily_set_items i join public.questions q on q.id = i.question_id where i.daily_date = p_date;
  if v_b is null then return null; end if;

  for k in 0 .. 20 loop
    v_mu := 50 + 15 * (-3 + k * 0.3);
    v_w := exp(-0.5 * ((v_mu - 50) / 15) ^ 2);
    v_wsum := v_wsum + v_w;
    v_local := array[1,0,0,0,0,0];
    foreach v_p in array (select array_agg(1.0 / (1.0 + exp(-(v_mu - b) / 10.0))) from unnest(v_b) b) loop
      for s in reverse 6 .. 1 loop  -- indices 1..6 ⇔ scores 0..5
        v_local[s] := v_local[s] * (1 - v_p) + case when s > 1 then v_local[s - 1] * v_p else 0 end;
      end loop;
    end loop;
    for s in 1 .. 6 loop v_dist[s] := v_dist[s] + v_w * v_local[s]; end loop;
  end loop;

  for s in (p_score + 2) .. 6 loop v_above := v_above + v_dist[s]; end loop;
  return least(greatest(ceil(100 * (v_above + 0.5 * v_dist[p_score + 1]) / v_wsum), 1), 99)::int;
end $$;

create or replace function public._daily_percentile(p_run uuid) returns jsonb
language plpgsql stable as $$
declare
  r public.daily_runs;
  v_n int; v_better int;
begin
  select * into r from public.daily_runs where id = p_run;
  if r.status <> 'finished' then return null; end if;
  select count(*) into v_n from public.daily_runs where daily_date = r.daily_date and status = 'finished';
  if v_n >= 100 then
    select count(*) into v_better from public.daily_runs
    where daily_date = r.daily_date and status = 'finished'
      and (score > r.score or (score = r.score and total_ms < r.total_ms));
    return jsonb_build_object('top', least(ceil(100.0 * (v_better + 1) / v_n), 100)::int, 'source', 'live', 'participants', v_n);
  end if;
  return jsonb_build_object('top', public._daily_estimate_top(r.daily_date, r.score), 'source', 'estimate', 'participants', v_n);
end $$;

-- ─────────────────────────────────────────── RPC publiques
create or replace function public.daily_status() returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  v_today date;
  v_tz text := public._user_tz(v_user);
  r public.daily_runs;
  v_next int;
  p public.profiles;
begin
  perform public._expire_user_runs(v_user);
  v_today := public._user_today(v_user);
  select * into p from public.profiles where id = v_user;
  select * into r from public.daily_runs where user_id = v_user and daily_date = v_today;
  if found and r.status = 'in_progress' then
    select count(*) + 1 into v_next from public.daily_answers where run_id = r.id and answered_at is not null;
  end if;
  return jsonb_build_object(
    'date', v_today,
    'state', case when r.id is null then 'available' when r.status = 'in_progress' then 'in_progress' else 'done' end,
    'run_id', r.id,
    'next_position', v_next,
    'score', r.score,
    'answers', (select coalesce(jsonb_agg(is_correct order by position), '[]'::jsonb)
                from public.daily_answers where run_id = r.id and answered_at is not null),
    'streak', public._streak_effective(v_user),
    'streak_freezes', p.streak_freezes,
    'seconds_until_next', greatest(0, floor(extract(epoch from public._day_end(v_today, v_tz) - public._now())))::int);
end $$;

create or replace function public.daily_start() returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  v_today date;
  v_tz text := public._user_tz(v_user);
  r public.daily_runs;
  v_next int;
begin
  perform public._expire_user_runs(v_user);
  v_today := public._user_today(v_user);
  perform public._ensure_daily_set(v_today);

  insert into public.daily_runs (user_id, daily_date, status, started_at, deadline_at)
  values (v_user, v_today, 'in_progress', public._now(), public._day_end(v_today, v_tz) + interval '30 minutes')
  on conflict (user_id, daily_date) do nothing;

  select * into r from public.daily_runs where user_id = v_user and daily_date = v_today;
  select count(*) + 1 into v_next from public.daily_answers where run_id = r.id and answered_at is not null;
  return jsonb_build_object('run_id', r.id, 'date', r.daily_date, 'status', r.status,
                            'next_position', case when r.status = 'in_progress' then v_next end,
                            'deadline_at', r.deadline_at, 'total', 5);
end $$;

create or replace function public.daily_question(p_run uuid, p_position int) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  r public.daily_runs;
  q public.questions;
  v_next int;
  v_qid uuid;
begin
  select * into r from public.daily_runs where id = p_run and user_id = v_user for update;
  if not found then raise exception 'daily_run_not_found'; end if;
  -- Pas d'exception ici : elle annulerait la clôture. On renvoie un état explicite.
  if r.status = 'in_progress' and r.deadline_at < public._now() then
    perform public._daily_finish(r.id, true);
    return jsonb_build_object('expired', true);
  end if;
  if r.status <> 'in_progress' then raise exception 'daily_closed'; end if;

  select count(*) + 1 into v_next from public.daily_answers where run_id = r.id and answered_at is not null;
  if p_position <> v_next then raise exception 'daily_out_of_order'; end if;

  select question_id into v_qid from public.daily_set_items where daily_date = r.daily_date and position = p_position;
  -- served_at n'est posé qu'une fois : rouvrir l'app ne remet pas l'horloge à zéro.
  insert into public.daily_answers (run_id, position, question_id, served_at)
  values (r.id, p_position, v_qid, public._now())
  on conflict (run_id, position) do nothing;

  select * into q from public.questions where id = v_qid;
  return public._question_public(q, r.id::text) || jsonb_build_object('position', p_position, 'total', 5);
end $$;

create or replace function public.daily_answer(p_run uuid, p_position int, p_given jsonb, p_client_ms int) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  r public.daily_runs;
  a public.daily_answers;
  q public.questions;
  v_server_ms int;
  v_counted int;
  v_res jsonb;
  v_reward jsonb;
  v_finished bool := false;
begin
  select * into r from public.daily_runs where id = p_run and user_id = v_user for update;
  if not found then raise exception 'daily_run_not_found'; end if;
  select * into a from public.daily_answers where run_id = p_run and position = p_position for update;
  if not found then raise exception 'daily_not_served'; end if;
  select * into q from public.questions where id = a.question_id;

  -- Double soumission : on renvoie le verdict déjà enregistré.
  if a.answered_at is not null then
    return jsonb_build_object('position', p_position, 'is_correct', a.is_correct, 'duplicate', true,
                              'finished', r.status <> 'in_progress', 'counted_ms', a.counted_ms)
           || public._question_reveal(q);
  end if;
  if r.status <> 'in_progress' then raise exception 'daily_closed'; end if;
  if r.deadline_at < public._now() then
    perform public._daily_finish(r.id, true);
    return jsonb_build_object('expired', true, 'position', p_position);
  end if;

  -- Temps officiel : le client peut retrancher jusqu'à 2 s de latence réseau, jamais plus ; borné [0,3 s ; 120 s].
  v_server_ms := floor(extract(epoch from public._now() - a.served_at) * 1000)::int;
  v_counted := least(v_server_ms, greatest(coalesce(p_client_ms, v_server_ms), v_server_ms - 2000));
  v_counted := least(greatest(v_counted, 300), 120000);

  v_res := public._record_attempt(v_user, q.id, p_given, v_counted, 'daily', r.id,
                                  md5(r.id::text || ':' || p_position)::uuid);
  update public.daily_answers set
    answered_at = public._now(), given = p_given, is_correct = (v_res ->> 'is_correct')::bool,
    client_ms = p_client_ms, counted_ms = v_counted,
    domain_before = (v_res ->> 'domain_before')::real, domain_after = (v_res ->> 'domain_after')::real
  where run_id = p_run and position = p_position;

  if (v_res ->> 'is_correct')::bool then
    perform public._grant(v_user, 'xp', 10, 'daily_correct', r.id::text, 'daily_correct:' || r.id || ':' || p_position);
  end if;
  v_reward := public._reward_correction(v_user, v_res, r.id || ':' || p_position);

  if (select count(*) from public.daily_answers where run_id = p_run and answered_at is not null) = 5 then
    perform public._daily_finish(r.id, false);
    v_finished := true;
  end if;

  return jsonb_build_object(
      'position', p_position,
      'is_correct', (v_res ->> 'is_correct')::bool,
      'duplicate', false,
      'counted_ms', v_counted,
      'error_transition', v_res -> 'error_transition',
      'domain_id', q.domain_id,
      'domain_before', v_res -> 'domain_before',
      'domain_after', v_res -> 'domain_after',
      'correction_reward', v_reward,
      'finished', v_finished)
    || public._question_reveal(q);
end $$;

create or replace function public.daily_result(p_date date default null) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  r public.daily_runs;
begin
  select * into r from public.daily_runs
  where user_id = v_user and daily_date = coalesce(p_date, public._user_today(v_user));
  if not found or r.status = 'in_progress' then raise exception 'daily_not_finished'; end if;
  return jsonb_build_object(
    'run_id', r.id,
    'date', r.daily_date,
    'status', r.status,
    'score', r.score,
    'total_ms', r.total_ms,
    'xp', r.xp_awarded,
    'seeds', r.seeds_awarded,
    'streak', coalesce(r.streak_after, public._streak_effective(v_user)),
    'achievements', (select coalesce(jsonb_agg(jsonb_build_object('id', a.id, 'name', a.name, 'description', a.description)
                                               order by a.sort), '[]'::jsonb)
                     from public.achievements a where a.id = any (r.achievements)),
    'answers', (select coalesce(jsonb_agg(jsonb_build_object(
                    'position', da.position, 'is_correct', coalesce(da.is_correct, false), 'counted_ms', da.counted_ms,
                    'domain_id', q.domain_id, 'domain_before', da.domain_before, 'domain_after', da.domain_after)
                  order by da.position), '[]'::jsonb)
                from public.daily_answers da join public.questions q on q.id = da.question_id where da.run_id = r.id),
    'percentile', public._daily_percentile(r.id));
end $$;

-- Revue : seulement après la fin officielle. Toutes les questions, même celles non servies (run expiré).
create or replace function public.daily_review(p_date date default null) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  r public.daily_runs;
begin
  select * into r from public.daily_runs
  where user_id = v_user and daily_date = coalesce(p_date, public._user_today(v_user));
  if not found or r.status = 'in_progress' then raise exception 'daily_not_finished'; end if;
  return (
    select jsonb_agg(public._question_public(q, r.id::text) || public._question_reveal(q)
                     || jsonb_build_object('position', i.position, 'given', da.given,
                                           'is_correct', coalesce(da.is_correct, false), 'counted_ms', da.counted_ms)
                     order by i.position)
    from public.daily_set_items i
    join public.questions q on q.id = i.question_id
    left join public.daily_answers da on da.run_id = r.id and da.position = i.position
    where i.daily_date = r.daily_date);
end $$;

-- Historique compact (profil, calendrier de série).
create or replace function public.daily_history(p_days int default 35) returns jsonb
language sql security definer set search_path = public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object('date', daily_date, 'status', status, 'score', score, 'total_ms', total_ms)
                            order by daily_date desc), '[]'::jsonb)
  from public.daily_runs
  where user_id = auth.uid() and daily_date >= public._user_today(auth.uid()) - least(greatest(p_days, 1), 400)
$$;
