-- ─────────────────────────────────────────── 0054 · Elo de progression, séparé du niveau (D-055)
-- Deux notions par domaine :
--  · le niveau μ (caché), rapide et précis : il sert seulement à choisir les questions et à calibrer leur difficulté ;
--  · l'Elo (affiché), une vraie progression : départ à 500, il monte à son rythme et coûte cher à garder tout en haut.
-- Règles de l'Elo (par réponse classée du domaine, puis plafond par partie) :
--  · attendu = hasard + (1 − hasard) / (1 + 10^((difficulté en Elo − Elo) / 400)) ; variation = K × (résultat − attendu) ;
--  · placement (20 premières réponses) : K = 40, au plus +15 par réponse et ±150 par partie → 800 au plus à la fin ;
--  · ensuite : K = 16, au plus +30 par partie, −40 (−80 si l'Elo était déjà à 1 200 ou plus au début de la partie) ;
--  · au-dessus de 1 000, les gains diminuent et les pertes augmentent : ×0,5 / ×1,5 à 1 200, ×0,35 / ×1,75 dès 1 400.
-- Au-dessus de 1 200 (niveau μ), la partie classée mélange 20 % d'accessibles, 50 % à son niveau, 30 % qui piquent.
-- Joueurs actuels : leur Elo est recalculé en rejouant leurs réponses classées avec ces règles (niveau caché inchangé).
-- Difficulté des questions : en plus de l'ajustement à chaque réponse, un recalcul chaque nuit pour les questions
-- d'au moins 10 premières réponses classées : la difficulté qui explique le mieux les résultats, compte tenu du niveau
-- de chaque joueur au moment de répondre (avec un léger rappel vers l'estimation de départ).

-- ─────────────────────────────────────────── Colonnes
alter table public.user_skills add column elo real;
alter table public.user_skill_snapshots add column elo real;
alter table public.question_attempts add column dom_elo_before real, add column dom_elo_after real;
alter table public.questions add column difficulty_batch real;

-- ─────────────────────────────────────────── Constantes et calcul
create or replace function public._elo_c(p_key text) returns real
language sql immutable set search_path = public, pg_temp as $$
  select case p_key
    when 'start'          then 500
    when 'k_placement'    then 40
    when 'k'              then 16
    when 'answer_max_pl'  then 15    -- gain max par réponse pendant le placement (20 × 15 = 300 → 800 au plus)
    when 'game_placement' then 150   -- ± par partie pendant le placement
    when 'game_gain'      then 30
    when 'game_loss'      then 40
    when 'game_loss_high' then 80    -- partie commencée à 1 200 ou plus
    when 'high'           then 1200
    when 'floor'          then 100
  end::real
$$;

-- Multiplicateurs au-dessus de 1 000 : gains ×0,5 et pertes ×1,5 à 1 200, gains ×0,35 et pertes ×1,75 dès 1 400 (linéaire entre).
create or replace function public._elo_mult(p_elo real, p_gain bool) returns real
language sql immutable set search_path = public, pg_temp as $$
  select (case when p_gain then 1 - 0.5 * t1 - 0.15 * t2 else 1 + 0.5 * t1 + 0.25 * t2 end)::real
  from (select least(greatest((p_elo - 1000) / 200.0, 0), 1) as t1, least(greatest((p_elo - 1200) / 200.0, 0), 1) as t2) t
$$;

-- Elo après une réponse classée (avant le plafond de la partie). p_n_before : réponses classées du domaine avant celle-ci.
create or replace function public._elo_step(p_elo real, p_n_before int, p_b real, p_guess real, p_score real) returns real
language plpgsql immutable set search_path = public, pg_temp as $$
declare
  v_c double precision := coalesce(p_guess, 0);
  v_e double precision;
  v_d double precision;
  v_placing bool := p_n_before < public._c_placement();
begin
  v_e := v_c + (1 - v_c) / (1 + power(10, (public._cote(p_b) - p_elo) / 400.0));
  v_d := (case when v_placing then public._elo_c('k_placement') else public._elo_c('k') end) * (p_score - v_e);
  v_d := v_d * public._elo_mult(p_elo, v_d > 0);
  if v_placing then v_d := least(v_d, public._elo_c('answer_max_pl')); end if;
  return greatest(p_elo + v_d, public._elo_c('floor'))::real;
end $$;

-- Elo exprimé dans l'unité « niveau » (l'app 1.0 convertit : Elo = 1 000 + 17,37 × (niveau − 50)).
create or replace function public._elo_as_level(p_elo real) returns real
language sql immutable set search_path = public, pg_temp as $$
  select ((p_elo - 1000) / 17.37 + 50)::real
$$;

-- Mise à jour de l'Elo d'un domaine après une réponse classée (la ligne user_skills existe déjà : n compte cette réponse).
create or replace function public._elo_update(p_user uuid, p_domain text, p_b real, p_guess real, p_score real,
                                              out elo_before real, out elo_after real)
language plpgsql set search_path = public, pg_temp as $$
declare
  v_n int;
begin
  select coalesce(s.elo, public._elo_c('start')), s.n into elo_before, v_n
  from public.user_skills s where s.user_id = p_user and s.scope_id = p_domain for update;
  if not found then return; end if;
  elo_after := public._elo_step(elo_before, v_n - 1, p_b, p_guess, p_score);

  update public.user_skills set elo = elo_after where user_id = p_user and scope_id = p_domain;
  update public.user_skill_snapshots set elo = elo_after
   where user_id = p_user and scope_id = p_domain and day = (public._now() at time zone 'UTC')::date;
end $$;

-- Plafond par partie : l'Elo de chaque domaine reste dans [début − perte max, début + gain max].
create or replace function public._cap_game_elo(p_user uuid, p_session uuid) returns void
language plpgsql set search_path = public, pg_temp as $$
declare
  r record;
  v_n0 int;
  v_up real; v_down real;
  v_capped real;
begin
  for r in
    select q.domain_id, (array_agg(a.dom_elo_before order by a.created_at, a.id))[1] as before, count(*)::int as cnt
    from public.question_attempts a join public.questions q on q.id = a.question_id
    where a.session_id = p_session and a.user_id = p_user and a.dom_elo_before is not null
    group by q.domain_id
  loop
    select greatest(s.n - r.cnt, 0) into v_n0 from public.user_skills s where s.user_id = p_user and s.scope_id = r.domain_id;
    if v_n0 < public._c_placement() then
      v_up := public._elo_c('game_placement'); v_down := public._elo_c('game_placement');
    else
      v_up := public._elo_c('game_gain');
      v_down := case when r.before >= public._elo_c('high') then public._elo_c('game_loss_high') else public._elo_c('game_loss') end;
    end if;
    v_capped := null;
    update public.user_skills s
       set elo = least(greatest(s.elo, r.before - v_down), r.before + v_up)
     where s.user_id = p_user and s.scope_id = r.domain_id
       and (s.elo > r.before + v_up or s.elo < r.before - v_down)
    returning s.elo into v_capped;
    if v_capped is not null then
      update public.user_skill_snapshots set elo = v_capped
       where user_id = p_user and scope_id = r.domain_id and day = (public._now() at time zone 'UTC')::date;
    end if;
  end loop;
end $$;

-- Elo affiché d'un domaine.
create or replace function public._rating_json(p_user uuid, p_scope text) returns jsonb
language sql stable set search_path = public, pg_temp as $$
  select jsonb_build_object(
    'cote', round(coalesce(s.elo, public._elo_c('start')))::int,
    'answered', coalesce(s.n, 0),
    'placement', least(2, coalesce(s.n, 0) * 2 / t.threshold),
    'placed', coalesce(s.n, 0) >= t.threshold)
  from (select case when position('.' in p_scope) > 0 then 15 else public._c_placement() end as threshold) t
  left join public.user_skills s on s.user_id = p_user and s.scope_id = p_scope
$$;

-- Mélange de la partie classée selon le niveau : au-dessus de 1 200, 20 % accessibles, 50 % à son niveau, 30 % qui piquent.
create or replace function public._band_bounds(p_mode text, p_mu real, out lo real, out hi real, out explore boolean)
language plpgsql set search_path = public, pg_temp as $$
declare
  r double precision;
  g_lo real; g_hi real;
begin
  if p_mode = 'challenge' or coalesce(public._cote(p_mu), 0) < public._elo_c('high') then
    select b.lo, b.hi, b.explore into lo, hi, explore from public._band_bounds(p_mode) b;
    return;
  end if;
  explore := false;
  r := random();
  if r < 0.20 then g_lo := -400; g_hi := -200;     -- accessibles
  elsif r < 0.70 then g_lo := -200; g_hi := -60;   -- à son niveau
  else g_lo := -60; g_hi := 80; end if;             -- qui piquent
  lo := public._p_of_gap(g_hi);
  hi := public._p_of_gap(g_lo);
end $$;

-- Fin de partie classée : Elo avant la 1re réponse de la partie dans le domaine, et Elo actuel (plafonné).
create or replace function public._play_submit_rated(p_session uuid, p_attempts jsonb) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  v jsonb := public._play_submit_base(p_session, p_attempts);
  v_ranked bool := coalesce((v ->> 'ranked')::bool, true);
begin
  -- Points par question (sur toute la session : un renvoi de la file hors-ligne donne le même total).
  v := jsonb_set(v, '{results}', coalesce((
         select jsonb_agg(e || jsonb_build_object('points', coalesce((
                  select public._attempt_points(a.is_correct, a.expected, a.response_ms) / (case when a.second_chance then 2 else 1 end)
                  from public.question_attempts a
                  where a.session_id = p_session and a.user_id = v_user and a.question_id = (e ->> 'question_id')::uuid
                  limit 1), 0))
                order by i)
         from jsonb_array_elements(v -> 'results') with ordinality t(e, i)), '[]'::jsonb));
  v := v || jsonb_build_object('points', (
         select coalesce(sum(public._attempt_points(a.is_correct, a.expected, a.response_ms) / (case when a.second_chance then 2 else 1 end)), 0)
         from public.question_attempts a where a.session_id = p_session and a.user_id = v_user));

  -- Variation d'Elo par domaine touché (partie classée) : avant la 1re réponse de la partie, maintenant.
  v := v || jsonb_build_object('ratings', case when not v_ranked then '[]'::jsonb else coalesce((
         select jsonb_agg(jsonb_build_object(
                  'domain_id', d.domain_id,
                  'cote_before', round(coalesce((select a.dom_elo_before from public.question_attempts a
                                                 join public.questions q2 on q2.id = a.question_id
                                                 where a.session_id = p_session and a.user_id = v_user
                                                   and q2.domain_id = d.domain_id and a.dom_elo_before is not null
                                                 order by a.created_at, a.id limit 1), public._elo_c('start')))::int,
                  'cote_after', round(coalesce((select us.elo from public.user_skills us
                                                where us.user_id = v_user and us.scope_id = d.domain_id), public._elo_c('start')))::int)
                || (public._rating_json(v_user, d.domain_id) - 'cote')
                order by d.first_i)
         from (select q.domain_id, min(i) first_i
               from jsonb_array_elements(v -> 'results') with ordinality t(e, i)
               join public.questions q on q.id = (e ->> 'question_id')::uuid
               where e ->> 'domain_before' is not null and e ->> 'domain_after' is not null
               group by q.domain_id) d), '[]'::jsonb) end);
  return v;
end $$;

-- Correction des erreurs : rend l'Elo perdu sur les questions corrigées, sans dépasser l'Elo d'avant la partie.
-- (Les thèmes gardent l'ancien remboursement de niveau ; le niveau du domaine n'est plus touché.)
create or replace function public.play_correction_submit(p_session uuid, p_answers jsonb) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  s public.play_sessions;
  c public.play_corrections;
  a jsonb;
  q public.questions;
  v_corrected uuid[] := '{}';
  r record;
  v_now real;
  v_refund real;
  v_refunds jsonb := '[]'::jsonb;
begin
  select * into s from public.play_sessions where id = p_session and user_id = v_user;
  if not found then raise exception 'session_not_found'; end if;
  select * into c from public.play_corrections where session_id = p_session for update;
  if not found then raise exception 'correction_not_started'; end if;
  if c.finished_at is not null then
    return jsonb_build_object('corrected', c.corrected, 'total', cardinality(c.question_ids), 'refunds', c.refunds, 'duplicate', true);
  end if;
  if jsonb_typeof(p_answers) <> 'array' then raise exception 'invalid_answers'; end if;

  for a in select * from jsonb_array_elements(p_answers) loop
    continue when not ((a ->> 'question_id')::uuid = any (c.question_ids)) or (a ->> 'question_id')::uuid = any (v_corrected);
    select * into q from public.questions where id = (a ->> 'question_id')::uuid;
    if public._evaluate(q.type, q.answer, a -> 'given') then v_corrected := v_corrected || q.id; end if;
  end loop;

  if s.ranked and cardinality(v_corrected) > 0 then
    -- Domaines (Elo) puis thèmes (niveau) : pertes des questions corrigées, plafonnées à la valeur d'avant la partie.
    for r in
      select scope_id, sum(loss) as losses, max(start) as start, bool_or(is_domain) as is_domain from (
        select q2.domain_id as scope_id, greatest(a2.dom_elo_before - a2.dom_elo_after, 0) as loss,
               (select a3.dom_elo_before from public.question_attempts a3 join public.questions q3 on q3.id = a3.question_id
                where a3.session_id = p_session and a3.user_id = v_user and q3.domain_id = q2.domain_id and a3.dom_elo_before is not null
                order by a3.created_at, a3.id limit 1) as start, true as is_domain
        from public.question_attempts a2 join public.questions q2 on q2.id = a2.question_id
        where a2.session_id = p_session and a2.user_id = v_user and a2.question_id = any (v_corrected) and a2.dom_elo_before is not null
        union all
        select q2.subdomain_id, greatest(a2.user_skill_before - a2.sub_mu_after, 0),
               (select a3.user_skill_before from public.question_attempts a3 join public.questions q3 on q3.id = a3.question_id
                where a3.session_id = p_session and a3.user_id = v_user and q3.subdomain_id = q2.subdomain_id
                order by a3.created_at, a3.id limit 1), false
        from public.question_attempts a2 join public.questions q2 on q2.id = a2.question_id
        where a2.session_id = p_session and a2.user_id = v_user and a2.question_id = any (v_corrected) and a2.sub_mu_after is not null
      ) x group by scope_id
    loop
      select case when r.is_domain then elo else mu end into v_now
      from public.user_skills where user_id = v_user and scope_id = r.scope_id for update;
      continue when v_now is null or r.start is null;
      v_refund := least(r.losses, greatest(r.start - v_now, 0));
      continue when v_refund <= 0;
      if r.is_domain then
        update public.user_skills set elo = elo + v_refund where user_id = v_user and scope_id = r.scope_id;
        update public.user_skill_snapshots set elo = elo + v_refund
         where user_id = v_user and scope_id = r.scope_id and day = (public._now() at time zone 'UTC')::date;
        v_refunds := v_refunds || jsonb_build_object('domain_id', r.scope_id,
          'cote_refund', round(v_now + v_refund)::int - round(v_now)::int,
          'cote_after', round(v_now + v_refund)::int);
      else
        update public.user_skills set mu = mu + v_refund where user_id = v_user and scope_id = r.scope_id;
        update public.user_skill_snapshots set mu = mu + v_refund
         where user_id = v_user and scope_id = r.scope_id and day = (public._now() at time zone 'UTC')::date;
      end if;
    end loop;
  end if;

  update public.play_corrections set finished_at = public._now(), corrected = cardinality(v_corrected), refunds = v_refunds
  where session_id = p_session;
  return jsonb_build_object('corrected', cardinality(v_corrected), 'total', cardinality(c.question_ids),
                            'corrected_ids', to_jsonb(v_corrected), 'refunds', v_refunds, 'duplicate', false);
end $$;

-- ─────────────────────────────────────────── Branchements dans les fonctions existantes
do $$
declare f record; v_old text; v_new text;
begin
  -- Chaque réponse classée met aussi à jour l'Elo du domaine (et le garde dans la réponse, pour le plafond et la correction).
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = '_record_attempt' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(replace(replace(replace(replace(v_old,
      '  v_sub record;
', '  v_sub record;
  v_elo record;
'),
      '    select * into v_dom from public._skill_update(p_user, q.domain_id,    q.difficulty_effective, q.difficulty_var, v_correct, p_ms, q.guess_rate, v_score);
',
      '    select * into v_dom from public._skill_update(p_user, q.domain_id,    q.difficulty_effective, q.difficulty_var, v_correct, p_ms, q.guess_rate, v_score);
    select * into v_elo from public._elo_update(p_user, q.domain_id, q.difficulty_effective, q.guess_rate, coalesce(v_score, v_correct::int));
'),
      '      into v_dom from public._skill_peek(p_user, q.domain_id) k;
',
      '      into v_dom from public._skill_peek(p_user, q.domain_id) k;
    select null::real as elo_before, null::real as elo_after into v_elo;
'),
      'created_at, second_chance, dom_mu_before, dom_mu_after, sub_mu_after)',
      'created_at, second_chance, dom_mu_before, dom_mu_after, sub_mu_after, dom_elo_before, dom_elo_after)'),
      'case when p_ranked then v_sub.mu_after end);',
      'case when p_ranked then v_sub.mu_after end, v_elo.elo_before, v_elo.elo_after);');
    v_new := replace(v_new,
      '''domain_after'', round(v_dom.mu_after::numeric, 1),',
      '''domain_after'', round(v_dom.mu_after::numeric, 1),
    ''elo_before'', round(v_elo.elo_before::numeric, 1),
    ''elo_after'', round(v_elo.elo_after::numeric, 1),');
    if v_new not like '%v_elo record;%' or v_new not like '%from public._elo_update(%' or v_new not like '%null::real as elo_after into v_elo;%'
       or v_new not like '%dom_elo_before, dom_elo_after)%' or v_new not like '%v_elo.elo_before, v_elo.elo_after);%'
       or v_new not like '%''elo_after'', round(v_elo.elo_after::numeric, 1),%' then
      raise exception '0054: _record_attempt inchangée';
    end if;
    execute v_new;
  end loop;

  -- Plafond de l'Elo par partie, avant la vérification des trophées.
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = '_play_submit_base' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(v_old,
      '  v_results := public._cap_game_skills(v_user, s.id, jsonb_build_object(''results'', v_results)) -> ''results'';',
      '  v_results := public._cap_game_skills(v_user, s.id, jsonb_build_object(''results'', v_results)) -> ''results'';
  perform public._cap_game_elo(v_user, s.id);');
    if v_new = v_old then raise exception '0054: _play_submit_base inchangée'; end if;
    execute v_new;
  end loop;

  -- Sélection : le mélange dépend du niveau.
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = '_select_questions' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(v_old, 'select * into v_band from public._band_bounds(p_mode);',
                            'select * into v_band from public._band_bounds(p_mode, v_mu);');
    if v_new = v_old then raise exception '0054: _select_questions inchangée'; end if;
    execute v_new;
  end loop;

  -- Trophées de maîtrise : sur l'Elo.
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = '_check_achievements' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(v_old, 'public._cote(s.mu) >= public._mastery_cote(a.tier)', 'coalesce(s.elo, 500) >= public._mastery_cote(a.tier)');
    if v_new = v_old then raise exception '0054: _check_achievements inchangée'; end if;
    execute v_new;
  end loop;
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'trophies_overview' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(v_old, 'then public._cote(s.mu) end', 'then round(coalesce(s.elo, 500))::int end');
    if v_new = v_old then raise exception '0054: trophies_overview inchangée'; end if;
    execute v_new;
  end loop;

  -- Profil d'un ami : Elo moyen (pondéré par les réponses) et placement au bon seuil.
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'friend_profile' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(replace(v_old,
      'round(sum(public._cote(s.mu) * s.n)', 'round(sum(coalesce(s.elo, 500) * s.n)'),
      'bool_or(s.n >= 50)', 'bool_or(s.n >= public._c_placement())');
    if v_new not like '%coalesce(s.elo, 500) * s.n%' or v_new not like '%bool_or(s.n >= public._c_placement())%' then
      raise exception '0054: friend_profile inchangée';
    end if;
    execute v_new;
  end loop;

  -- Fiche joueur (admin) : Elo affiché et niveau caché, en Elo.
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'admin_user' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(v_old, '''cote'', public._cote(s.mu),', '''cote'', round(coalesce(s.elo, 500))::int, ''level_cote'', public._cote(s.mu),');
    if v_new = v_old then raise exception '0054: admin_user inchangée'; end if;
    execute v_new;
  end loop;

  -- Objectif « Gagne N points d'Elo » : Elo actuel contre Elo à la fin de la période précédente (500 sinon).
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = '_quest_progress' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := regexp_replace(replace(replace(replace(v_old,
      'public._cote(k.mu) - public._cote(coalesce(', 'round(coalesce(k.elo, 500)) - round(coalesce('),
      'select s.mu from public.user_skill_snapshots s', 'select s.elo from public.user_skill_snapshots s'),
      'cross join lateral public._skill_peek(p_user, d.domain_id) k',
      'left join public.user_skills k on k.user_id = p_user and k.scope_id = d.domain_id'),
      E'\\n(\\s*)50\\)\\)\\)', E'\n\\1500)))');
    if v_new not like '%round(coalesce(k.elo, 500))%' or v_new not like '%select s.elo from%' or v_new not like '%left join public.user_skills k%'
       or v_new not like '%500)))%' then
      raise exception '0054: _quest_progress inchangée';
    end if;
    execute v_new;
  end loop;

  -- Bilan de la semaine : variation d'Elo par domaine.
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'weekly_recap' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(replace(replace(v_old,
      'public._cote((select s.mu from public.user_skill_snapshots s', 'round((select s.elo from public.user_skill_snapshots s'),
      '- public._cote(coalesce((select s.mu from public.user_skill_snapshots s', '- round(coalesce((select s.elo from public.user_skill_snapshots s'),
      'order by s.day desc limit 1), 50)) as delta', 'order by s.day desc limit 1), 500)) as delta');
    if v_new not like '%round((select s.elo%' or v_new not like '%- round(coalesce((select s.elo%' or v_new not like '%limit 1), 500)) as delta%' then
      raise exception '0054: weekly_recap inchangée';
    end if;
    execute v_new;
  end loop;

  -- 5 du jour : la variation affichée est celle de l'Elo (dans l'unité « niveau » que l'app convertit en Elo).
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'daily_answer' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(replace(replace(replace(v_old,
      'domain_before = (v_res ->> ''domain_before'')::real',
      'domain_before = coalesce(public._elo_as_level((v_res ->> ''elo_before'')::real), (v_res ->> ''domain_before'')::real)'),
      'domain_after = (v_res ->> ''domain_after'')::real',
      'domain_after = coalesce(public._elo_as_level((v_res ->> ''elo_after'')::real), (v_res ->> ''domain_after'')::real)'),
      '''domain_before'', v_res -> ''domain_before'',',
      '''domain_before'', coalesce(to_jsonb(round(public._elo_as_level((v_res ->> ''elo_before'')::real)::numeric, 2)), v_res -> ''domain_before''),'),
      '''domain_after'', v_res -> ''domain_after'',',
      '''domain_after'', coalesce(to_jsonb(round(public._elo_as_level((v_res ->> ''elo_after'')::real)::numeric, 2)), v_res -> ''domain_after''),');
    if (length(v_new) - length(replace(v_new, '_elo_as_level(', ''))) / length('_elo_as_level(') <> 4 then
      raise exception '0054: daily_answer inchangée';
    end if;
    execute v_new;
  end loop;

  -- Courbe d'un domaine : l'Elo (renvoyé dans l'unité « niveau » que l'app convertit : 1 000 + 17,37 × (niveau − 50)).
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = '_domain_stats_base' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(v_old,
      'jsonb_build_object(''day'', day, ''level'', round(mu::numeric, 1))',
      'jsonb_build_object(''day'', day, ''level'', round(((coalesce(elo, public._cote(mu)) - 1000) / 17.37 + 50)::numeric, 2))');
    if v_new = v_old then raise exception '0054: _domain_stats_base inchangée'; end if;
    execute v_new;
  end loop;

  -- Ajustement à chaque réponse : prudent autour de la dernière difficulté recalculée la nuit (sinon celle de départ).
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = '_question_update' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(replace(v_old,
      'least(greatest(v_b, q.difficulty_initial - (case', 'least(greatest(v_b, coalesce(q.difficulty_batch, q.difficulty_initial) - (case'),
      '               q.difficulty_initial + (case', '               coalesce(q.difficulty_batch, q.difficulty_initial) + (case');
    if v_new not like '%greatest(v_b, coalesce(q.difficulty_batch%' or v_new not like '%coalesce(q.difficulty_batch, q.difficulty_initial) + (case%' then
      raise exception '0054: _question_update inchangée';
    end if;
    execute v_new;
  end loop;
end $$;

-- ─────────────────────────────────────────── Recalcul de nuit des difficultés
-- Pour chaque question d'au moins 10 premières réponses classées (hors Seconde chance et révision des erreurs) :
-- difficulté b la plus probable sachant le niveau de chaque joueur au moment de répondre et le hasard de la question,
-- avec un rappel doux vers l'estimation de départ (écart-type 12). Recherche par pas de 0,5 entre 0 et 100.
create or replace function public.cron_recalibrate_questions() returns int
language plpgsql set search_path = public, pg_temp as $$
declare v_count int;
begin
  drop table if exists recal_obs, recal_fit;
  create temp table recal_obs on commit drop as
    select a.question_id, a.user_skill_before::double precision as mu, a.is_correct,
           coalesce(q.guess_rate, 0)::double precision as c, q.difficulty_initial::double precision as b0
    from public.question_attempts a
    join public.questions q on q.id = a.question_id
    left join public.play_sessions ps on ps.id = a.session_id
    where a.seen_count = 1 and not a.second_chance and a.context <> 'errors'
      and a.user_skill_before is not null and coalesce(ps.ranked, true);
  delete from recal_obs o where o.question_id in (select question_id from recal_obs group by 1 having count(*) < 10);

  -- Vraisemblance de chaque difficulté candidate, plus le rappel vers l'estimation de départ ; on garde la meilleure.
  create temp table recal_fit on commit drop as
    select distinct on (question_id) question_id, b
    from (select o.question_id, g.b,
                 sum(ln(case when o.is_correct then p else 1 - p end)) - (g.b - min(o.b0)) ^ 2 / (2 * 144.0) as score
          from recal_obs o
          cross join (select gs * 0.5::double precision as b from generate_series(0, 200) gs) g
          cross join lateral (select least(greatest(o.c + (1 - o.c) / (1 + exp(-(o.mu - g.b) / 10.0)), 1e-6), 1 - 1e-6) as p) pp
          group by o.question_id, g.b) t
    order by question_id, score desc;

  -- Précision : information de Fisher au point trouvé (plus il y a de réponses, plus la difficulté est sûre).
  update public.questions q set
    difficulty_observed = f.b,
    difficulty_batch = f.b,
    difficulty_min = least(q.difficulty_min, f.b),
    difficulty_max = greatest(q.difficulty_max, f.b),
    difficulty_var = greatest(1.0 / (1.0 / 144 + f.info), public._c('q_var_min'))
  from (select r.question_id, r.b,
               sum(((1 - o.c) * s * (1 - s) / 10.0) ^ 2 / greatest((o.c + (1 - o.c) * s) * (1 - o.c) * (1 - s), 1e-9)) as info
        from recal_fit r
        join recal_obs o on o.question_id = r.question_id
        cross join lateral (select 1 / (1 + exp(-(o.mu - r.b) / 10.0)) as s) ss
        group by r.question_id, r.b) f
  where q.id = f.question_id;
  get diagnostics v_count = row_count;
  return v_count;
end $$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('brainlix-recalibrate', '23 3 * * *', 'select public.cron_recalibrate_questions()');
  end if;
exception when others then
  raise notice 'pg_cron indisponible : recalcul des difficultés non planifié (%)', sqlerrm;
end $$;

-- ─────────────────────────────────────────── Joueurs actuels : Elo recalculé
-- On rejoue dans l'ordre les réponses qui ont fait bouger le niveau d'un domaine (difficulté de la question au moment de
-- répondre), avec le plafond de chaque partie classée. Le 5 du jour n'a pas de plafond de partie (comme en direct).
do $$
declare
  a record;
  v_n int; v_elo real; v_new real;
  g record;
  v_up real; v_down real;
begin
  create temp table rp_state (user_id uuid, domain_id text, n int, elo real, primary key (user_id, domain_id)) on commit drop;
  create temp table rp_game (user_id uuid, game uuid, domain_id text, elo real, n0 int, primary key (user_id, game, domain_id)) on commit drop;
  update public.user_skill_snapshots set elo = null;
  for a in
    select qa.id, qa.user_id, q.domain_id, qa.question_difficulty, q.guess_rate, qa.is_correct, qa.second_chance, qa.created_at,
           case when qa.context = 'daily' then null else qa.session_id end as game
    from public.question_attempts qa
    join public.questions q on q.id = qa.question_id
    left join public.play_sessions ps on ps.id = qa.session_id
    where (qa.dom_mu_before is not null
           or (qa.context in ('onboarding', 'daily', 'quick_play', 'training') and coalesce(ps.ranked, true)
               and qa.created_at < '2026-10-01'))
      and exists (select 1 from public.user_skills us where us.user_id = qa.user_id and us.scope_id = q.domain_id)
    order by qa.created_at, qa.id
  loop
    select s.n, s.elo into v_n, v_elo from rp_state s where s.user_id = a.user_id and s.domain_id = a.domain_id;
    if not found then
      v_n := 0; v_elo := public._elo_c('start');
      insert into rp_state values (a.user_id, a.domain_id, 0, v_elo);
    end if;
    v_new := public._elo_step(v_elo, v_n, a.question_difficulty, a.guess_rate,
                              case when a.is_correct and a.second_chance then 0.5 when a.is_correct then 1 else 0 end);
    if a.game is not null then
      insert into rp_game values (a.user_id, a.game, a.domain_id, v_elo, v_n) on conflict do nothing;
      select * into g from rp_game where user_id = a.user_id and game = a.game and domain_id = a.domain_id;
      if g.n0 < public._c_placement() then
        v_up := public._elo_c('game_placement'); v_down := public._elo_c('game_placement');
      else
        v_up := public._elo_c('game_gain');
        v_down := case when g.elo >= public._elo_c('high') then public._elo_c('game_loss_high') else public._elo_c('game_loss') end;
      end if;
      v_new := least(greatest(v_new, g.elo - v_down), g.elo + v_up);
    end if;
    update rp_state set n = v_n + 1, elo = v_new where user_id = a.user_id and domain_id = a.domain_id;
    update public.question_attempts set dom_elo_before = v_elo, dom_elo_after = v_new where id = a.id;
    update public.user_skill_snapshots set elo = v_new
     where user_id = a.user_id and scope_id = a.domain_id and day = (a.created_at at time zone 'UTC')::date;
  end loop;

  update public.user_skills us set elo = coalesce((select s.elo from rp_state s where s.user_id = us.user_id and s.domain_id = us.scope_id),
                                                  public._elo_c('start'))
   where us.is_domain;
  -- Jours sans réponse rejouée : dernier Elo connu (500 avant).
  update public.user_skill_snapshots sn
     set elo = coalesce((select p.elo from public.user_skill_snapshots p
                         where p.user_id = sn.user_id and p.scope_id = sn.scope_id and p.day < sn.day and p.elo is not null
                         order by p.day desc limit 1), public._elo_c('start'))
    from public.user_skills us
   where us.user_id = sn.user_id and us.scope_id = sn.scope_id and us.is_domain and sn.elo is null;
end $$;

-- ─────────────────────────────────────────── Droits
revoke execute on function public._elo_c(text) from public, anon, authenticated;
revoke execute on function public._elo_mult(real, bool) from public, anon, authenticated;
revoke execute on function public._elo_step(real, int, real, real, real) from public, anon, authenticated;
revoke execute on function public._elo_as_level(real) from public, anon, authenticated;
revoke execute on function public._elo_update(uuid, text, real, real, real) from public, anon, authenticated;
revoke execute on function public._cap_game_elo(uuid, uuid) from public, anon, authenticated;
revoke execute on function public._rating_json(uuid, text) from public, anon, authenticated;
revoke execute on function public._band_bounds(text, real) from public, anon, authenticated;
revoke execute on function public._play_submit_rated(uuid, jsonb) from public, anon, authenticated;
revoke execute on function public.cron_recalibrate_questions() from public, anon, authenticated;
