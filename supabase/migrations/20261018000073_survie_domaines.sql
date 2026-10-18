-- Survie par domaine (D-078) : la Survie se joue aussi dans un seul domaine (fiche du domaine, à côté de la partie
-- classée et de l'entraînement libre). Un record par domaine, et le record « tous domaines » à part. La difficulté
-- part du niveau du joueur dans ce domaine. Le plafond de neurones (150 par jour) reste commun à toutes les Survies.
alter table public.survival_runs add column domain_id text references public.domains(id);
drop index if exists public.survival_runs_user_id_score_idx;
create index on public.survival_runs (user_id, domain_id, score desc);

drop function if exists public._survival_record(uuid);
create or replace function public._survival_record(p_user uuid, p_domain text) returns int
language sql stable set search_path = public, pg_temp as $$
  select coalesce(max(score), 0) from public.survival_runs
  where user_id = p_user and ended_at is not null and domain_id is not distinct from p_domain
$$;

-- Niveau de départ : celui du domaine joué (sinon le niveau général).
create or replace function public._survival_pick(r public.survival_runs) returns uuid
language plpgsql volatile set search_path = public, extensions, pg_temp as $$
declare
  v_base real := coalesce((select s.mu from public.user_skills s
                           where r.domain_id is not null and s.user_id = r.user_id and s.scope_id = r.domain_id),
                          public._overall_mu(r.user_id));
  v_target real := greatest(15, least(92, v_base - 10 + 3 * r.score));
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
    and (r.domain_id is null or q.domain_id = r.domain_id)
    and q.id <> all (v_protected) and q.id <> all (r.question_ids)
    and abs(q.difficulty_effective - v_target) <= 20
  order by abs(q.difficulty_effective - v_target) > 6, q.domain_id is not distinct from v_last,
           s.question_id is not null, random()
  limit 1;
  -- Domaine peu fourni : on élargit la fenêtre de difficulté plutôt que d'arrêter la partie.
  if v_id is null and r.domain_id is not null then
    select q.id into v_id from public.questions q
    where q.status = 'published' and q.type <> 'map_pick' and public._is_classic(q.type) and q.domain_id = r.domain_id
      and q.id <> all (v_protected) and q.id <> all (r.question_ids)
    order by abs(q.difficulty_effective - v_target), random()
    limit 1;
  end if;
  return v_id;
end $$;

create or replace function public._survival_end(p_run uuid) returns public.survival_runs
language plpgsql set search_path = public, pg_temp as $$
declare
  r public.survival_runs;
  v_record int;
  v_reward int;
begin
  select * into r from public.survival_runs where id = p_run for update;
  if r.ended_at is not null then return r; end if;
  v_record := public._survival_record(r.user_id, r.domain_id);
  v_reward := r.score * public._survival_rule('per_correct')
              + case when r.score > v_record and r.score > 0 then public._survival_rule('record_bonus') else 0 end;
  v_reward := public._grant_capped(r.user_id, 'seeds', v_reward, public._survival_rule('daily_cap'), 'survival',
                                   r.id::text, 'survival:' || r.id);
  update public.survival_runs set ended_at = public._now(), new_record = r.score > v_record and r.score > 0,
                                  reward = v_reward
  where id = r.id returning * into r;
  return r;
end $$;

drop function if exists public.survival_overview();
create or replace function public.survival_overview(p_domain text default null) returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user();
begin
  return jsonb_build_object(
    'record', public._survival_record(v_user, p_domain),
    'best_today', (select coalesce(max(score), 0) from public.survival_runs
                   where user_id = v_user and ended_at is not null and domain_id is not distinct from p_domain
                     and started_at >= public._now() - interval '1 day'),
    'seconds', public._survival_rule('seconds'));
end $$;

drop function if exists public.survival_start();
create or replace function public.survival_start(p_domain text default null) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  v_open uuid;
  r public.survival_runs;
begin
  if p_domain is not null and not exists (select 1 from public.domains where id = p_domain and is_active) then
    raise exception 'invalid_domain';
  end if;
  if (select count(*) from public.survival_runs where user_id = v_user and started_at > public._now() - interval '1 hour')
     >= public._survival_rule('per_hour') then
    raise exception 'rate_limited';
  end if;
  for v_open in select id from public.survival_runs where user_id = v_user and ended_at is null loop
    perform public._survival_end(v_open);
  end loop;
  insert into public.survival_runs (user_id, started_at, domain_id) values (v_user, public._now(), p_domain) returning * into r;
  return jsonb_build_object('run_id', r.id, 'record', public._survival_record(v_user, p_domain),
                            'seconds', public._survival_rule('seconds'));
end $$;

create or replace function public.survival_result(p_run uuid) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  r public.survival_runs := public._survival_for_player(p_run, v_user);
begin
  if r.ended_at is null then r := public._survival_end(r.id); end if;
  return jsonb_build_object('score', r.score, 'record', public._survival_record(v_user, r.domain_id),
                            'new_record', r.new_record, 'reward', r.reward);
end $$;

revoke execute on function public._survival_record(uuid, text) from public, anon, authenticated;
revoke execute on function public.survival_overview(text), public.survival_start(text) from public, anon;
grant execute on function public.survival_overview(text), public.survival_start(text) to authenticated;
