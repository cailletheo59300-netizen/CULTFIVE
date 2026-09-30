-- Brainlix — 0027 Elo plus stable, difficulté cohérente, calibration prudente
--
-- Départ : tout le monde à 1000 (μ = 50) dans chaque domaine. Le niveau choisi à l'onboarding ne donne plus d'Elo :
--   il décale seulement les questions servies pendant le placement, et ce décalage s'efface sur les 50 premières réponses.
-- Plafond par partie : l'Elo d'un domaine (et d'un thème) ne bouge pas de plus de ±120 pendant le placement,
--   ±40 ensuite. Pas maximal par réponse réduit (≈ 43 Elo, le double en placement).
-- Partie classée : une seule fenêtre étroite, entre 190 et 30 points sous l'Elo du joueur (≈ 65 % de réussite) ;
--   l'app réordonne dans cette fenêtre (plus dur après une série, plus facile après deux erreurs) : adaptation douce.
-- 5 du jour : difficultés 44, 47, 50, 53, 56 dans cet ordre (pareil pour tous, montée douce).
-- Calibration : une question s'écarte d'au plus 5 points de sa difficulté d'origine avant 20 réponses, 15 avant 50.
-- Joueurs existants : Elo recalculé en rejouant leurs réponses classées avec ces règles (dates d'origine conservées).

-- ─────────────────────────────────────────── Constantes
create or replace function public._c(p_key text) returns real
language sql immutable as $$
  select case p_key
    when 'S'            then 10     -- points par logit
    when 'user_var0'    then 100    -- σ₀ = 10
    when 'user_var_min' then 9      -- σ ≥ 3
    when 'user_step'    then 2.5    -- variation max par réponse (≈ 43 Elo ; ×2 en placement)
    when 'q_var_min'    then 4      -- σ_b ≥ 2
    when 'q_step'       then 2
    when 'reinflate'    then 0.5    -- σ² ajouté par jour d'inactivité
  end::real
$$;

-- Plafond de variation par partie, en μ (17,37 Elo par point de μ).
create or replace function public._game_cap(p_n int) returns real language sql immutable as $$
  select (case when coalesce(p_n, 0) < public._c_placement() then 120 else 40 end) / 17.37::real
$$;

-- Décalage de sélection pendant le placement : le niveau annoncé à l'onboarding, qui s'efface en 50 réponses.
create or replace function public._placement_offset(p_user uuid, p_domain text) returns real
language sql stable as $$
  select ((coalesce(p.challenge_prior, 50) - 50)
          * greatest(0, 1 - coalesce(s.n, 0)::real / public._c_placement()))::real
  from public.profiles p
  left join public.user_skills s on s.user_id = p.id and s.scope_id = p_domain
  where p.id = p_user
$$;

do $$
declare
  f record;
  v_old text;
  v_new text;
begin
  -- Départ à 1000 : un domaine jamais joué part de μ = 50, quel que soit le niveau annoncé.
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = '_skill_peek' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(v_old,
      'select p.challenge_prior into mu from public.profiles p where p.id = p_user;',
      'mu := 50;  -- départ identique pour tous (1000) ; le niveau annoncé ne sert qu''à la sélection (_placement_offset)');
    if v_new = v_old then raise exception '0027: _skill_peek inchangée'; end if;
    execute v_new;
  end loop;

  -- L'onboarding ne décale plus les niveaux déjà créés.
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'complete_onboarding' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(v_old,
      'update public.user_skills set mu = least(greatest(mu + (v_prior - v_old), 0), 100) where user_id = v_user;',
      'null;  -- 0027 : le niveau annoncé ne modifie plus l''Elo');
    if v_new = v_old then raise exception '0027: complete_onboarding inchangée'; end if;
    execute v_new;
  end loop;

  -- Sélection : niveau du joueur + décalage de placement.
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = '_select_questions' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(v_old,
      'select k.mu, k.var into v_mu, v_var from public._skill_peek(p_user, v_scope) k;',
      'select k.mu, k.var into v_mu, v_var from public._skill_peek(p_user, v_scope) k;
    v_mu := least(greatest(v_mu + coalesce(public._placement_offset(p_user, v_domain), 0), 0), 100);');
    -- Repli « toute difficulté » : la plus proche de la fenêtre plutôt qu'une au hasard.
    v_new := replace(v_new,
      'order by case when v_band.explore then q.answer_count else 0 end, random()',
      'order by case when v_band.explore then q.answer_count else 0 end,
               case when lvl >= 4 then abs(q.difficulty_effective - (v_blo + v_bhi) / 2) else 0 end, random()');
    if v_new = v_old or v_new not like '%when lvl >= 4 then abs(q.difficulty_effective%' then
      raise exception '0027: _select_questions inchangée';
    end if;
    execute v_new;
  end loop;

  -- Partie classée : une seule fenêtre étroite.
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = '_band_bounds' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(v_old,
      'if r < 0.50 then g_lo := -250; g_hi := -75;
    elsif r < 0.80 then g_lo := -100; g_hi := 25;
    elsif r < 0.95 then g_lo := -400; g_hi := -250;
    else g_lo := 25; g_hi := 175; end if;',
      'g_lo := -190; g_hi := -30;  -- 0027 : fenêtre unique, ≈ 65 % de réussite');
    if v_new = v_old then raise exception '0027: _band_bounds inchangée'; end if;
    execute v_new;
  end loop;

  -- 5 du jour : montée douce et resserrée.
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = '_generate_daily_set' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(replace(v_old,
      'select array_agg(t order by random()) into v_targets from unnest(array[35, 45, 50, 55, 65]::real[]) t;',
      'v_targets := array[44, 47, 50, 53, 56]::real[];  -- 0027 : montée douce, dans cet ordre'),
      'abs(q.difficulty_effective - v_targets[i]) + random() * 8', 'abs(q.difficulty_effective - v_targets[i]) + random() * 3');
    -- Les questions sont d'abord choisies, puis rangées de la plus accessible à la plus dure.
    v_new := replace(v_new, 'v_families text[] := ''{}'';', 'v_families text[] := ''{}'';
  v_picks uuid[] := ''{}'';');
    v_new := replace(v_new,
      'insert into public.daily_set_items (daily_date, position, slot, question_id) values (p_date, i, v_slots[i], v_pick);',
      'v_picks := v_picks || v_pick;');
    v_new := replace(v_new,
      '    v_families := v_families || coalesce(v_family, '''');
  end loop;',
      '    v_families := v_families || coalesce(v_family, '''');
  end loop;
  insert into public.daily_set_items (daily_date, position, slot, question_id)
  select p_date, row_number() over (order by q.difficulty_effective, t.i), v_slots[t.i], t.id
  from unnest(v_picks) with ordinality t(id, i) join public.questions q on q.id = t.id;');
    if v_new = v_old or v_new not like '%v_picks := v_picks || v_pick;%' or v_new not like '%row_number() over (order by q.difficulty_effective%' then
      raise exception '0027: _generate_daily_set inchangée';
    end if;
    execute v_new;
  end loop;

  -- Calibration prudente : pas d'écart brutal avec la difficulté d'origine tant qu'il y a peu de réponses.
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = '_question_update' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(v_old,
      'v_n := q.answer_count + 1;',
      'v_n := q.answer_count + 1;
  v_b := least(greatest(v_b, q.difficulty_initial - (case when v_n < 20 then 5 when v_n < 50 then 15 else 100 end)),
               q.difficulty_initial + (case when v_n < 20 then 5 when v_n < 50 then 15 else 100 end));');
    if v_new = v_old then raise exception '0027: _question_update inchangée'; end if;
    execute v_new;
  end loop;
end $$;

-- ─────────────────────────────────────────── Plafond par partie
-- Ramène l'Elo de chaque domaine et thème touchés dans les bornes de la partie (niveau au début ± plafond),
-- et corrige les « après » renvoyés à l'app en conséquence.
create or replace function public._cap_game_skills(p_user uuid, p_session uuid, p_result jsonb) returns jsonb
language plpgsql as $$
declare
  r record;
  v_cap real;
  v_capped real;
  v_n0 int;
  v_results jsonb := p_result -> 'results';
begin
  for r in
    select scope_id, before from (
      -- Domaines : niveau avant la première réponse de la partie.
      select q.domain_id as scope_id, (array_agg((e ->> 'domain_before')::real order by i))[1] as before
      from jsonb_array_elements(v_results) with ordinality t(e, i)
      join public.questions q on q.id = (e ->> 'question_id')::uuid
      where e ->> 'domain_before' is not null
      group by q.domain_id
      union all
      -- Thèmes : niveau avant la première réponse de la partie dans ce thème.
      select q.subdomain_id, (array_agg(a.user_skill_before order by a.created_at, a.id))[1]
      from public.question_attempts a join public.questions q on q.id = a.question_id
      where a.session_id = p_session and a.user_id = p_user and a.user_skill_before is not null
      group by q.subdomain_id
    ) x
  loop
    select greatest(coalesce(s.n, 0) - (select count(*) from public.question_attempts a join public.questions q on q.id = a.question_id
                                          where a.session_id = p_session and a.user_id = p_user
                                            and (q.domain_id = r.scope_id or q.subdomain_id = r.scope_id))::int, 0)
      into v_n0 from public.user_skills s where s.user_id = p_user and s.scope_id = r.scope_id;
    v_cap := public._game_cap(v_n0);
    update public.user_skills s
       set mu = least(greatest(s.mu, r.before - v_cap), r.before + v_cap)
     where s.user_id = p_user and s.scope_id = r.scope_id
       and (s.mu > r.before + v_cap or s.mu < r.before - v_cap)
    returning s.mu into v_capped;
    if v_capped is not null then
      update public.user_skill_snapshots set mu = v_capped
       where user_id = p_user and scope_id = r.scope_id and day = (public._now() at time zone 'UTC')::date;
    end if;
    if v_capped is not null and position('.' in r.scope_id) = 0 then
      -- Le dernier « après » de ce domaine prend la valeur plafonnée (c'est lui qui sert à la variation affichée).
      v_results := (select jsonb_agg(case when i = (select max(i2) from jsonb_array_elements(v_results) with ordinality t2(e2, i2)
                                                    join public.questions q2 on q2.id = (e2 ->> 'question_id')::uuid
                                                    where q2.domain_id = r.scope_id and e2 ->> 'domain_after' is not null)
                                          then e || jsonb_build_object('domain_after', v_capped) else e end order by i)
                    from jsonb_array_elements(v_results) with ordinality t(e, i));
    end if;
    v_capped := null;
  end loop;
  return jsonb_set(p_result, '{results}', coalesce(v_results, '[]'::jsonb));
end $$;

do $$
declare
  f record;
  v_old text;
  v_new text;
begin
  -- Plafond appliqué avant la vérification des trophées (maîtrise) et avant le calcul des variations affichées.
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = '_play_submit_base' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(v_old,
      '  return jsonb_build_object(''recorded'', v_new,',
      '  v_results := public._cap_game_skills(v_user, s.id, jsonb_build_object(''results'', v_results)) -> ''results'';
  return jsonb_build_object(''recorded'', v_new,');
    if v_new = v_old then raise exception '0027: _play_submit_base inchangée'; end if;
    execute v_new;
  end loop;

  -- Objectif « Gagne 30 points d'Elo » et récap : tout le monde part de 1000, donc un domaine jamais joué avant
  -- la période part de 1000 (et non du niveau d'un thème avant la première réponse).
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = '_quest_progress' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(v_old,
      '               (select a2.user_skill_before from public.question_attempts a2 join public.questions q2 on q2.id = a2.question_id
                where a2.user_id = p_user and q2.domain_id = d.domain_id and a2.created_at >= v_from
                order by a2.created_at limit 1),
', '');
    if v_new = v_old then raise exception '0027: _quest_progress inchangée'; end if;
    execute v_new;
  end loop;
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'weekly_recap' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(v_old,
      '
                                             (select a.user_skill_before from public.question_attempts a join public.questions q on q.id = a.question_id
                                              where a.user_id = v_user and q.domain_id = d.domain_id and a.created_at >= v_from
                                              order by a.created_at limit 1), 50)) as delta',
      ' 50)) as delta');
    if v_new = v_old then raise exception '0027: weekly_recap inchangée'; end if;
    execute v_new;
  end loop;
end $$;

-- ─────────────────────────────────────────── Recalcul des joueurs existants
-- On rejoue toutes les réponses classées dans l'ordre, avec les nouvelles règles (départ 1000, pas réduit, plafond
-- par partie), à la date d'origine de chaque réponse (courbes conservées). La calibration des questions n'est pas rejouée.
do $$
declare
  a record;
  v_key text;
  v_before real;
  v_cap real;
  v_mu real;
begin
  create temp table replay_start (user_id uuid, game text, scope_id text, mu real, n0 int, primary key (user_id, game, scope_id))
    on commit drop;
  delete from public.user_skill_snapshots;
  delete from public.user_skills;

  for a in
    select qa.user_id, qa.question_id, qa.is_correct, qa.response_ms, qa.created_at,
           coalesce(qa.session_id::text, qa.created_at::date::text) as game,
           q.subdomain_id, q.domain_id, q.difficulty_effective, q.difficulty_var, q.guess_rate
    from public.question_attempts qa
    join public.questions q on q.id = qa.question_id
    left join public.play_sessions ps on ps.id = qa.session_id
    where coalesce(ps.ranked, true)
      and qa.context <> 'errors'
      and exists (select 1 from public.profiles p where p.id = qa.user_id)
    order by qa.created_at, qa.id
  loop
    perform set_config('app.now_override', a.created_at::text, true);
    foreach v_key in array array[a.subdomain_id, a.domain_id] loop
      insert into replay_start (user_id, game, scope_id, mu, n0)
      select a.user_id, a.game, v_key, k.mu,
             coalesce((select n from public.user_skills where user_id = a.user_id and scope_id = v_key), 0)
      from public._skill_peek(a.user_id, v_key) k
      on conflict do nothing;
      perform public._skill_update(a.user_id, v_key, a.difficulty_effective, a.difficulty_var, a.is_correct,
                                   a.response_ms, a.guess_rate);
      select mu, public._game_cap(n0) into v_before, v_cap from pg_temp.replay_start
       where user_id = a.user_id and game = a.game and scope_id = v_key;
      update public.user_skills set mu = least(greatest(mu, v_before - v_cap), v_before + v_cap)
       where user_id = a.user_id and scope_id = v_key
      returning mu into v_mu;
      update public.user_skill_snapshots set mu = v_mu
       where user_id = a.user_id and scope_id = v_key and day = (a.created_at at time zone 'UTC')::date;
    end loop;
  end loop;
  perform set_config('app.now_override', '', true);
end $$;

-- ─────────────────────────────────────────── Droits et chemin de recherche
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig from pg_proc p
    where p.pronamespace = 'public'::regnamespace and p.proname in ('_game_cap', '_placement_offset', '_cap_game_skills')
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', f.sig);
  end loop;
  for f in
    select p.oid::regprocedure as sig from pg_proc p
    where p.pronamespace = 'public'::regnamespace and p.prokind in ('f', 'p')
      and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%')
  loop
    execute format('alter function %s set search_path = public, extensions, pg_temp', f.sig);
  end loop;
end $$;
