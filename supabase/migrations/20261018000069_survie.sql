-- Mode Survie (D-072) : on répond jusqu'à la première erreur. Une question à la fois, servie par le serveur sans sa
-- réponse (comme le 5 du jour) : impossible de lire les réponses à l'avance, le record est fiable. La difficulté monte
-- à chaque bonne réponse, en changeant de domaine. 20 s par question (temps compté par le serveur, 3 s de marge réseau).
-- Hors Elo : les réponses comptent pour les erreurs à revoir et les statistiques, pas pour le niveau.
-- Gain : 3 neurones par bonne réponse, +20 pour un nouveau record ; 150 neurones par jour au plus.
alter type public.attempt_context add value if not exists 'survival';

create table public.survival_runs (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles(id) on delete cascade,
  started_at    timestamptz not null,
  ended_at      timestamptz,
  -- Bonnes réponses.
  score         int  not null default 0,
  -- Questions servies, dans l'ordre (la dernière est celle en cours tant que la partie n'est pas finie).
  question_ids  uuid[] not null default '{}',
  served_at     timestamptz,
  -- Record battu à la fin de cette partie, et neurones gagnés.
  new_record    bool not null default false,
  reward        int  not null default 0
);
create index on public.survival_runs (user_id, score desc);
create index on public.survival_runs (user_id, started_at desc);
alter table public.survival_runs enable row level security;
revoke all on public.survival_runs from public, anon, authenticated;

create or replace function public._survival_rule(p_key text) returns int
language sql immutable set search_path = public, pg_temp as $$
  select case p_key when 'seconds' then 20 when 'grace' then 3 when 'per_correct' then 3 when 'record_bonus' then 20
                    when 'daily_cap' then 150 when 'per_hour' then 30 end
$$;

-- Record du joueur (meilleur score d'une partie finie).
create or replace function public._survival_record(p_user uuid) returns int
language sql stable set search_path = public, pg_temp as $$
  select coalesce(max(score), 0) from public.survival_runs where user_id = p_user and ended_at is not null
$$;

-- Prochaine question : autour d'une difficulté qui monte avec le score (départ un peu sous le niveau du joueur),
-- jamais déjà servie dans la partie, d'un autre domaine que la précédente si possible, jamais vue de préférence.
create or replace function public._survival_pick(r public.survival_runs) returns uuid
language plpgsql volatile set search_path = public, extensions, pg_temp as $$
declare
  v_target real := greatest(15, least(92, public._overall_mu(r.user_id) - 10 + 3 * r.score));
  v_last text := (select domain_id from public.questions where id = r.question_ids[cardinality(r.question_ids)]);
  v_protected uuid[] := coalesce(public._protected_daily_questions(), '{}');
  v_id uuid;
begin
  with seen as materialized (
    select distinct question_id from public.question_attempts where user_id = r.user_id
  )
  select q.id into v_id
  from public.questions q left join seen s on s.question_id = q.id
  where q.status = 'published' and q.type <> 'map_pick' and public._is_classic(q.type)
    and q.id <> all (v_protected) and q.id <> all (r.question_ids)
    and abs(q.difficulty_effective - v_target) <= 20
  order by abs(q.difficulty_effective - v_target) > 6, q.domain_id is not distinct from v_last,
           s.question_id is not null, random()
  limit 1;
  return v_id;
end $$;

-- Ferme une partie : score définitif, record, neurones.
create or replace function public._survival_end(p_run uuid) returns public.survival_runs
language plpgsql set search_path = public, pg_temp as $$
declare
  r public.survival_runs;
  v_record int;
  v_reward int;
begin
  select * into r from public.survival_runs where id = p_run for update;
  if r.ended_at is not null then return r; end if;
  v_record := public._survival_record(r.user_id);
  v_reward := r.score * public._survival_rule('per_correct')
              + case when r.score > v_record and r.score > 0 then public._survival_rule('record_bonus') else 0 end;
  v_reward := public._grant_capped(r.user_id, 'seeds', v_reward, public._survival_rule('daily_cap'), 'survival',
                                   r.id::text, 'survival:' || r.id);
  update public.survival_runs set ended_at = public._now(), new_record = r.score > v_record and r.score > 0,
                                  reward = v_reward
  where id = r.id returning * into r;
  return r;
end $$;

create or replace function public._survival_for_player(p_run uuid, p_user uuid) returns public.survival_runs
language plpgsql set search_path = public, pg_temp as $$
declare r public.survival_runs;
begin
  select * into r from public.survival_runs where id = p_run and user_id = p_user;
  if not found then raise exception 'survival_not_found'; end if;
  return r;
end $$;

-- ─────────────────────────────────────────── API de l'app

-- Carte « Survie » de Jouer : record et meilleure partie du jour.
create or replace function public.survival_overview() returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user();
begin
  return jsonb_build_object(
    'record', public._survival_record(v_user),
    'best_today', (select coalesce(max(score), 0) from public.survival_runs
                   where user_id = v_user and ended_at is not null and started_at >= public._now() - interval '1 day'),
    'seconds', public._survival_rule('seconds'));
end $$;

-- Nouvelle partie (une partie restée ouverte est close au passage).
create or replace function public.survival_start() returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  v_open uuid;
  r public.survival_runs;
begin
  if (select count(*) from public.survival_runs where user_id = v_user and started_at > public._now() - interval '1 hour')
     >= public._survival_rule('per_hour') then
    raise exception 'rate_limited';
  end if;
  for v_open in select id from public.survival_runs where user_id = v_user and ended_at is null loop
    perform public._survival_end(v_open);
  end loop;
  insert into public.survival_runs (user_id, started_at) values (v_user, public._now()) returning * into r;
  return jsonb_build_object('run_id', r.id, 'record', public._survival_record(v_user),
                            'seconds', public._survival_rule('seconds'));
end $$;

-- Question n° p_position (1, 2, 3…) : servie une seule fois, le chrono du serveur part à l'envoi.
create or replace function public.survival_question(p_run uuid, p_position int) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  r public.survival_runs := public._survival_for_player(p_run, v_user);
  v_id uuid;
  q public.questions;
begin
  if r.ended_at is not null then return jsonb_build_object('expired', true); end if;
  if p_position = cardinality(r.question_ids) and r.served_at is not null then
    v_id := r.question_ids[p_position];               -- renvoi (réseau) : la même question, le chrono continue
  elsif p_position = cardinality(r.question_ids) + 1 and p_position = r.score + 1 then
    v_id := public._survival_pick(r);
    if v_id is null then
      perform public._survival_end(r.id);
      return jsonb_build_object('expired', true);
    end if;
    update public.survival_runs set question_ids = question_ids || v_id, served_at = public._now() where id = r.id;
  else
    raise exception 'survival_out_of_order';
  end if;
  select * into q from public.questions where id = v_id;
  return public._question_public(q, r.id::text) || jsonb_build_object('position', p_position);
end $$;

-- Réponse à la question en cours (p_given nul : temps écoulé). Fausse ou trop tardive : la partie s'arrête.
create or replace function public.survival_answer(p_run uuid, p_position int, p_given jsonb, p_client_ms int)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  r public.survival_runs := public._survival_for_player(p_run, v_user);
  q public.questions;
  v_key uuid := md5(r.id::text || ':' || p_position)::uuid;
  v_prev public.question_attempts;
  v_server_ms int;
  v_counted int;
  v_late bool;
  v_res jsonb;
  v_correct bool;
begin
  if p_position < 1 or p_position > cardinality(r.question_ids) then raise exception 'survival_not_served'; end if;
  select * into q from public.questions where id = r.question_ids[p_position];
  -- Renvoi de la même réponse (réseau) : même verdict.
  select * into v_prev from public.question_attempts where client_attempt_id = v_key;
  if found then
    return jsonb_build_object('position', p_position, 'is_correct', v_prev.is_correct and p_position <= r.score,
                              'duplicate', true, 'finished', r.ended_at is not null) || public._question_reveal(q);
  end if;
  if r.ended_at is not null then raise exception 'survival_closed'; end if;
  if p_position <> cardinality(r.question_ids) or r.served_at is null then raise exception 'survival_not_served'; end if;

  v_server_ms := floor(extract(epoch from public._now() - r.served_at) * 1000)::int;
  v_late := v_server_ms > (public._survival_rule('seconds') + public._survival_rule('grace')) * 1000;
  v_counted := least(v_server_ms, greatest(coalesce(p_client_ms, v_server_ms), v_server_ms - 2000));
  v_counted := least(greatest(v_counted, 300), 120000);
  v_res := public._record_attempt(v_user, q.id, case when v_late then null else p_given end, v_counted, 'survival',
                                  r.id, v_key, false);
  v_correct := (v_res ->> 'is_correct')::bool and not v_late;
  if v_correct then
    update public.survival_runs set score = score + 1, served_at = null where id = r.id;
  else
    update public.survival_runs set served_at = null where id = r.id;
    perform public._survival_end(r.id);
  end if;
  return jsonb_build_object('position', p_position, 'is_correct', v_correct, 'duplicate', false, 'counted_ms', v_counted,
                            'finished', not v_correct, 'late', v_late, 'error_transition', v_res -> 'error_transition')
         || public._question_reveal(q);
end $$;

-- Bilan d'une partie finie (le joueur peut aussi l'abandonner : elle est close ici).
create or replace function public.survival_result(p_run uuid) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  r public.survival_runs := public._survival_for_player(p_run, v_user);
begin
  if r.ended_at is null then r := public._survival_end(r.id); end if;
  return jsonb_build_object('score', r.score, 'record', public._survival_record(v_user), 'new_record', r.new_record,
                            'reward', r.reward);
end $$;

revoke execute on function public._survival_rule(text), public._survival_record(uuid),
  public._survival_pick(public.survival_runs), public._survival_end(uuid), public._survival_for_player(uuid, uuid)
  from public, anon, authenticated;
revoke execute on function public.survival_overview(), public.survival_start(), public.survival_question(uuid, int),
  public.survival_answer(uuid, int, jsonb, int), public.survival_result(uuid) from public, anon;
grant execute on function public.survival_overview(), public.survival_start(), public.survival_question(uuid, int),
  public.survival_answer(uuid, int, jsonb, int), public.survival_result(uuid) to authenticated;
