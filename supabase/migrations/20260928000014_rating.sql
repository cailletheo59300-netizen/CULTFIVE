-- CULT FIVE — 0014 Cote CULT, placement, parties plus exigeantes, points de partie
-- La cote est une vue lisible du niveau μ (0–100) : 1000 + 17,37 × (μ − 50). 17,37 = 400 / (10 · ln 10) : comme aux échecs,
-- 400 points d'écart = 10 contre 1. Tant que le domaine compte moins de 50 réponses classées (≈ 5 parties de 10),
-- le joueur est « en placement » : la cote n'est pas encore affichée et le niveau bouge deux fois plus vite.
-- Parties classées visées autour de 55 % de réussite (au lieu de ~70 %) : on joue à la limite de son niveau.

-- ─────────────────────────────────────────── Cote
create or replace function public._cote(p_mu real) returns int
language sql immutable as $$ select round(1000 + 17.37 * (coalesce(p_mu, 50) - 50))::int $$;

create or replace function public._c_placement() returns int language sql immutable as $$ select 50 $$;

-- {cote, answered, placement (0–5), placed} pour un domaine ou un thème. Un thème (20 à 300 questions) est placé
-- dès 15 réponses classées : son niveau part de celui du domaine, il n'a pas besoin d'un placement complet.
create or replace function public._rating_json(p_user uuid, p_scope text) returns jsonb
language sql stable as $$
  select jsonb_build_object(
    'cote', public._cote(k.mu),
    'answered', coalesce(s.n, 0),
    'placement', least(5, coalesce(s.n, 0) * 5 / t.threshold),
    'placed', coalesce(s.n, 0) >= t.threshold)
  from (select case when position('.' in p_scope) > 0 then 15 else public._c_placement() end as threshold) t
  cross join public._skill_peek(p_user, p_scope) k
  left join public.user_skills s on s.user_id = p_user and s.scope_id = p_scope
$$;

-- ─────────────────────────────────────────── Bandes de difficulté plus exigeantes
-- Classé : 55 % à la limite (50–65 % de chances), 25 % « défi » (35–50 %), 15 % de respiration (65–80 %), 5 % d'exploration.
-- Défi : 60 % à 30–45 %, 25 % à 45–60 %, 10 % à 20–30 %, 5 % d'exploration.
create or replace function public._band_bounds(p_mode text, out lo real, out hi real, out explore bool)
language plpgsql volatile as $$
declare r double precision := random();
begin
  explore := false;
  if p_mode = 'challenge' then
    if r < 0.60 then lo := 0.30; hi := 0.45;
    elsif r < 0.85 then lo := 0.45; hi := 0.60;
    elsif r < 0.95 then lo := 0.20; hi := 0.30;
    else explore := true; end if;
  else
    if r < 0.55 then lo := 0.50; hi := 0.65;
    elsif r < 0.80 then lo := 0.35; hi := 0.50;
    elsif r < 0.95 then lo := 0.65; hi := 0.80;
    else explore := true; end if;
  end if;
end $$;

-- ─────────────────────────────────────────── Placement : le niveau converge plus vite au début
create or replace function public._skill_update(
  p_user uuid, p_scope text, p_b real, p_var_b real, p_correct bool, p_ms int,
  out mu_before real, out var_before real, out mu_after real, out var_after real, out expected real)
language plpgsql as $$
declare
  v_g double precision := public._g(p_var_b);
  v_e double precision;
  v_i double precision;
  v_delta double precision;
  v_n int;
  v_step real;
begin
  select k.mu, k.var into mu_before, var_before from public._skill_peek(p_user, p_scope) k;
  select coalesce((select n from public.user_skills where user_id = p_user and scope_id = p_scope), 0) into v_n;
  -- Placement (< 50 réponses) : pas maximal doublé, pour trouver le vrai niveau en ~5 parties.
  v_step := public._c('user_step') * case when v_n < public._c_placement() then 2 else 1 end;
  v_e := public._expect(mu_before, p_b, p_var_b);
  v_i := v_g ^ 2 * v_e * (1 - v_e) / 100.0;
  var_after := greatest(1.0 / (1.0 / var_before + v_i), public._c('user_var_min'));
  v_delta := var_after * v_g * ((case when p_correct then 1 else 0 end) - v_e) / 10.0;
  v_delta := least(greatest(v_delta, -v_step), v_step);
  mu_after := least(greatest(mu_before + v_delta, 0), 100);
  expected := v_e;

  insert into public.user_skills as s (user_id, scope_id, mu, var, n, correct, total_ms, updated_at)
  values (p_user, p_scope, mu_after, var_after, 1, p_correct::int, coalesce(p_ms, 0), public._now())
  on conflict (user_id, scope_id) do update
    set mu = excluded.mu, var = excluded.var, n = s.n + 1, correct = s.correct + excluded.correct,
        total_ms = s.total_ms + excluded.total_ms, updated_at = excluded.updated_at;

  insert into public.user_skill_snapshots (user_id, scope_id, day, mu, var)
  values (p_user, p_scope, (public._now() at time zone 'UTC')::date, mu_after, var_after)
  on conflict (user_id, scope_id, day) do update set mu = excluded.mu, var = excluded.var;
end $$;

-- ─────────────────────────────────────────── Compétences : cote et placement
create or replace function public.skills_overview() returns jsonb
language sql security definer set search_path = public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'domain_id', d.id, 'name', d.name,
      'level', round(k.mu::numeric, 0),
      'reliability', round(greatest(0, 1 - sqrt(k.var) / 10)::numeric, 2),
      'answered', coalesce(s.n, 0), 'correct', coalesce(s.correct, 0))
      || public._rating_json(auth.uid(), d.id)
    order by coalesce(s.n, 0) desc, d.sort), '[]'::jsonb)
  from public.domains d
  left join public.user_skills s on s.user_id = auth.uid() and s.scope_id = d.id
  cross join lateral public._skill_peek(auth.uid(), d.id) k
  where d.is_active
$$;

alter function public.domain_stats(text) rename to _domain_stats_base;
revoke execute on function public._domain_stats_base(text) from public, anon, authenticated;
create or replace function public.domain_stats(p_domain text) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  v jsonb := public._domain_stats_base(p_domain);
begin
  -- Cote de chaque thème (même règle de placement, sur les réponses classées du thème).
  v := jsonb_set(v, '{subdomains}', coalesce((
         select jsonb_agg(e || public._rating_json(v_user, e ->> 'id') order by i)
         from jsonb_array_elements(v -> 'subdomains') with ordinality t(e, i)), '[]'::jsonb));
  return v || public._rating_json(v_user, p_domain);
end $$;
revoke execute on function public.domain_stats(text) from public, anon;
grant execute on function public.domain_stats(text) to authenticated;

-- ─────────────────────────────────────────── Pack : difficulté et chances de réussite de chaque question
-- `difficulty` (0–100, absolue) et `expected` (probabilité de bonne réponse pour ce joueur) : pastille Facile/Moyen/Difficile
-- et ordre adaptatif dans la partie (le client pioche plus dur après une série, plus facile après deux erreurs).
alter function public.play_pack(text, text, text, int, bool, text, text[]) rename to _play_pack_base;
revoke execute on function public._play_pack_base(text, text, text, int, bool, text, text[]) from public, anon, authenticated;
create or replace function public.play_pack(p_mode text, p_domain text default null, p_subdomain text default null,
                                            p_count int default 10, p_ranked bool default true, p_level text default null,
                                            p_subdomains text[] default null) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  v jsonb := public._play_pack_base(p_mode, p_domain, p_subdomain, p_count, p_ranked, p_level, p_subdomains);
begin
  return jsonb_set(v, '{questions}', coalesce((
    select jsonb_agg(e || jsonb_build_object(
             'difficulty', round(q.difficulty_effective::numeric, 0),
             'expected', round(public._expect(k.mu, q.difficulty_effective, q.difficulty_var)::numeric, 2))
           order by i)
    from jsonb_array_elements(v -> 'questions') with ordinality t(e, i)
    join public.questions q on q.id = (e ->> 'id')::uuid
    cross join lateral public._skill_peek(v_user, q.subdomain_id) k), '[]'::jsonb));
end $$;
revoke execute on function public.play_pack(text, text, text, int, bool, text, text[]) from public, anon;
grant execute on function public.play_pack(text, text, text, int, bool, text, text[]) to authenticated;

-- ─────────────────────────────────────────── Points de partie et variation de cote
-- Points (bonne réponse seulement) : 50 + 100 × (1 − chances de réussite) + bonus de vitesse (≤ 30, sous 15 s ;
-- rien sous 0,8 s, réponse trop rapide pour être lue). Une question « à 30 % » juste et rapide rapporte ~150 points.
create or replace function public._attempt_points(p_correct bool, p_expected real, p_ms int) returns int
language sql immutable as $$
  select case when not coalesce(p_correct, false) then 0
              else 50 + round(100 * (1 - least(greatest(coalesce(p_expected, 0.5), 0), 1)))::int
                   + case when p_ms is null or p_ms < 800 then 0 else greatest(0, round(30 * (15000 - p_ms) / 15000.0))::int end
         end
$$;

alter function public.play_submit(uuid, jsonb) rename to _play_submit_base;
revoke execute on function public._play_submit_base(uuid, jsonb) from public, anon, authenticated;
create or replace function public.play_submit(p_session uuid, p_attempts jsonb) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  v jsonb := public._play_submit_base(p_session, p_attempts);
  v_ranked bool := coalesce((v ->> 'ranked')::bool, true);
begin
  -- Points par question (sur toute la session : un renvoi de la file hors-ligne donne le même total).
  v := jsonb_set(v, '{results}', coalesce((
         select jsonb_agg(e || jsonb_build_object('points', coalesce((
                  select public._attempt_points(a.is_correct, a.expected, a.response_ms)
                  from public.question_attempts a
                  where a.session_id = p_session and a.user_id = v_user and a.question_id = (e ->> 'question_id')::uuid
                  limit 1), 0))
                order by i)
         from jsonb_array_elements(v -> 'results') with ordinality t(e, i)), '[]'::jsonb));
  v := v || jsonb_build_object('points', (
         select coalesce(sum(public._attempt_points(a.is_correct, a.expected, a.response_ms)), 0)
         from public.question_attempts a where a.session_id = p_session and a.user_id = v_user));

  -- Variation de cote par domaine touché (partie classée) : avant la 1re réponse, après la dernière.
  v := v || jsonb_build_object('ratings', case when not v_ranked then '[]'::jsonb else coalesce((
         select jsonb_agg(jsonb_build_object(
                  'domain_id', d.domain_id,
                  'cote_before', public._cote(d.before),
                  'cote_after', public._cote(d.after))
                || (public._rating_json(v_user, d.domain_id) - 'cote')
                order by d.first_i)
         from (select q.domain_id, min(i) first_i,
                      (array_agg((e ->> 'domain_before')::real order by i))[1] before,
                      (array_agg((e ->> 'domain_after')::real order by i desc))[1] after
               from jsonb_array_elements(v -> 'results') with ordinality t(e, i)
               join public.questions q on q.id = (e ->> 'question_id')::uuid
               where e ->> 'domain_before' is not null and e ->> 'domain_after' is not null
               group by q.domain_id) d), '[]'::jsonb) end);
  return v;
end $$;
revoke execute on function public.play_submit(uuid, jsonb) from public, anon;
grant execute on function public.play_submit(uuid, jsonb) to authenticated;

revoke execute on function public._rating_json(uuid, text) from public, anon, authenticated;
