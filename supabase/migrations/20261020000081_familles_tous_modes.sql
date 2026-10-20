-- Familles de questions dans tous les modes (D-086). Les parties Jouer et le 5 du jour limitaient déjà les questions
-- d'une même famille (0010, 0047), mais pas les défis, les ligues ni la Survie : un défi d'histoire pouvait aligner
-- plusieurs « En quel siècle est né… » (famille person_era, plus de la moitié des QCM d'histoire). Désormais :
--   défis et ligues : 2 questions au plus par famille, jamais deux à la suite ;
--   Survie : jamais deux à la suite, 2 au plus sur les 10 dernières questions.

-- Réordonne une liste pour que deux questions d'une même famille ne se suivent pas (quand c'est possible).
create or replace function public._spread_families(p_ids uuid[]) returns uuid[]
language plpgsql stable set search_path = public, pg_temp as $$
declare
  v_ids uuid[] := p_ids;
  v_fams text[];
  v_tmp uuid;
  v_tf text;
begin
  if coalesce(cardinality(p_ids), 0) < 3 then return p_ids; end if;
  select array_agg(q.family order by x.ord) into v_fams
  from unnest(p_ids) with ordinality x(id, ord) left join public.questions q on q.id = x.id;
  for i in 2 .. cardinality(v_ids) loop
    if v_fams[i] is not null and v_fams[i] = v_fams[i - 1] then
      for j in i + 1 .. cardinality(v_ids) loop
        if v_fams[j] is distinct from v_fams[i - 1] then
          v_tmp := v_ids[i]; v_ids[i] := v_ids[j]; v_ids[j] := v_tmp;
          v_tf := v_fams[i]; v_fams[i] := v_fams[j]; v_fams[j] := v_tf;
          exit;
        end if;
      end loop;
    end if;
  end loop;
  return v_ids;
end $$;

create or replace function public._duel_pick(p_a uuid, p_b uuid, p_count integer, p_domains text[], p_difficulty text)
returns uuid[] language plpgsql set search_path = public, extensions, pg_temp as $$
declare
  v_target real := case when p_b is null then public._overall_mu(p_a)
                        else (public._overall_mu(p_a) + public._overall_mu(p_b)) / 2 end;
  v_lo real;
  v_hi real;
  v_ids uuid[];
begin
  select lo, hi into v_lo, v_hi from (values
    ('easy', 15::real, 40::real), ('medium', 38, 62), ('hard', 60, 92),
    ('auto', greatest(v_target - 12, 15), least(v_target + 12, 90))) t(k, lo, hi)
  where k = p_difficulty;
  select array_agg(id order by d, id) into v_ids from (
    select id, d from (
      select q.id, q.difficulty_effective as d,
             row_number() over (partition by q.domain_id
                                order by (q.difficulty_effective between v_lo and v_hi) desc,
                                         exists (select 1 from public.question_attempts a
                                                 where a.question_id = q.id and a.user_id in (p_a, p_b)),
                                         abs(q.difficulty_effective - (v_lo + v_hi) / 2) > (v_hi - v_lo) / 2,
                                         random()) as rn
      from (select q0.*, row_number() over (partition by coalesce(q0.family, q0.id::text) order by random()) as fr
            from public.questions q0
            where q0.status = 'published' and q0.type <> 'map_pick' and public._is_classic(q0.type)
              and (p_domains is null or q0.domain_id = any (p_domains))
              and q0.id <> all ((select public._protected_daily_questions())::uuid[])) q
      where q.fr <= 2
    ) t
    order by rn, random()
    limit p_count
  ) s;
  return public._spread_families(v_ids);
end $$;

create or replace function public._league_day_questions(l leagues, p_day date)
returns uuid[] language plpgsql set search_path = public, extensions, pg_temp as $$
declare
  v_ids uuid[];
  v_target real;
  v_lo real; v_hi real;
begin
  select question_ids into v_ids from public.league_days where league_id = l.id and day = p_day;
  if v_ids is not null then return v_ids; end if;
  select coalesce(avg(public._overall_mu(m.user_id)), 50) into v_target from public.league_members m where m.league_id = l.id;
  select lo, hi into v_lo, v_hi from (values
    ('easy', 15::real, 40::real), ('medium', 38, 62), ('hard', 60, 92),
    ('auto', greatest(v_target - 12, 15), least(v_target + 12, 90))) t(k, lo, hi)
  where k = l.difficulty;
  select array_agg(id order by d, id) into v_ids from (
    select id, d from (
      select q.id, q.difficulty_effective as d,
             row_number() over (partition by q.domain_id
                                order by (q.difficulty_effective between v_lo and v_hi) desc, random()) as rn
      from (select q0.*, row_number() over (partition by coalesce(q0.family, q0.id::text) order by random()) as fr
            from public.questions q0
            where q0.status = 'published' and q0.type <> 'map_pick' and public._is_classic(q0.type)
              and (l.domains is null or q0.domain_id = any (l.domains))
              and q0.id <> all ((select public._protected_daily_questions())::uuid[])
              and not exists (select 1 from public.league_days ld where ld.league_id = l.id and q0.id = any (ld.question_ids))) q
      where q.fr <= 2
    ) t
    order by rn, random()
    limit l.question_count
  ) s;
  if coalesce(cardinality(v_ids), 0) < l.question_count then raise exception 'not_enough_questions'; end if;
  v_ids := public._spread_families(v_ids);
  insert into public.league_days (league_id, day, question_ids) values (l.id, p_day, v_ids)
  on conflict (league_id, day) do nothing;
  select question_ids into v_ids from public.league_days where league_id = l.id and day = p_day;
  return v_ids;
end $$;

create or replace function public._survival_pick(r survival_runs)
returns uuid language plpgsql set search_path = public, extensions, pg_temp as $$
declare
  v_base real := coalesce((select s.mu from public.user_skills s
                           where r.domain_id is not null and s.user_id = r.user_id and s.scope_id = r.domain_id),
                          public._overall_mu(r.user_id));
  v_target real := greatest(15, least(92, v_base - 10 + 3 * r.score));
  v_last text := (select domain_id from public.questions where id = r.question_ids[cardinality(r.question_ids)]);
  v_last_family text := (select family from public.questions where id = r.question_ids[cardinality(r.question_ids)]);
  -- Familles des 10 dernières questions (avec répétitions) : 2 au plus par famille sur cette fenêtre.
  v_recent text[] := (select array_agg(q.family) from unnest(r.question_ids[greatest(1, cardinality(r.question_ids) - 9):]) x(id)
                      join public.questions q on q.id = x.id where q.family is not null);
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
    and (q.family is null or (q.family is distinct from v_last_family
         and (select count(*) from unnest(coalesce(v_recent, '{}')) f where f = q.family) < 2))
  order by abs(q.difficulty_effective - v_target) > 6, q.domain_id is not distinct from v_last,
           s.question_id is not null, random()
  limit 1;
  -- Domaine peu fourni : on élargit la fenêtre de difficulté plutôt que d'arrêter la partie.
  if v_id is null and r.domain_id is not null then
    select q.id into v_id from public.questions q
    where q.status = 'published' and q.type <> 'map_pick' and public._is_classic(q.type) and q.domain_id = r.domain_id
      and q.id <> all (v_protected) and q.id <> all (r.question_ids)
    order by q.family is not null and q.family is not distinct from v_last_family,
             abs(q.difficulty_effective - v_target), random()
    limit 1;
  end if;
  return v_id;
end $$;

revoke execute on function public._spread_families(uuid[]) from public, anon, authenticated;
