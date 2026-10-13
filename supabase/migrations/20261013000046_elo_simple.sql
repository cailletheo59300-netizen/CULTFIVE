-- ─────────────────────────────────────────── 0046 · Elo plus simple et plus juste (D-039, revu avec le propriétaire)
-- Un Elo par domaine (les Elo de thème ne sont plus affichés par l'app). Départ affiché à 500 : pendant le placement
-- (50 réponses classées ≈ 5 parties), l'Elo affiché monte de 500 jusqu'au vrai niveau ; ensuite il est le vrai niveau.
-- Rangs (app) et trophées de maîtrise : 600 / 750 / 900 / 1 050 / 1 200.
-- Difficulté : les estimations de départ étaient trop optimistes (≈ 11 points de réussite) → +5 sur les questions
-- encore peu jouées ; les vraies réponses prennent le dessus deux fois plus vite.
-- Partie classée : mélange ≈ 3 accessibles, 5 à son niveau, 2 qui piquent (≈ 70 % de réussite visée).

-- Elo affiché : 500 au départ, puis le vrai niveau, atteint à la fin du placement.
create or replace function public._cote_shown(p_mu real, p_n int) returns int language sql immutable as $$
  select round(500 + (public._cote(p_mu) - 500) * least(greatest(coalesce(p_n, 0), 0)::real / public._c_placement(), 1))::int
$$;

create or replace function public._rating_json(p_user uuid, p_scope text) returns jsonb
language sql stable as $$
  select jsonb_build_object(
    'cote', public._cote_shown(k.mu, coalesce(s.n, 0)),
    'answered', coalesce(s.n, 0),
    'placement', least(5, coalesce(s.n, 0) * 5 / t.threshold),
    'placed', coalesce(s.n, 0) >= t.threshold)
  from (select case when position('.' in p_scope) > 0 then 15 else public._c_placement() end as threshold) t
  cross join public._skill_peek(p_user, p_scope) k
  left join public.user_skills s on s.user_id = p_user and s.scope_id = p_scope
$$;

do $$
declare f record; v_old text; v_new text;
begin
  -- Fin de partie classée : Elo affiché avant et après (avec le nombre de réponses du domaine à chaque moment).
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = '_play_submit_rated' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(replace(replace(v_old,
      '''cote_before'', public._cote(d.before),',
      '''cote_before'', public._cote_shown(d.before, greatest(coalesce((select us.n from public.user_skills us
                                     where us.user_id = v_user and us.scope_id = d.domain_id), 0) - d.cnt, 0)),'),
      '''cote_after'', public._cote(d.after))',
      '''cote_after'', public._cote_shown(d.after, coalesce((select us.n from public.user_skills us
                                     where us.user_id = v_user and us.scope_id = d.domain_id), 0)))'),
      'select q.domain_id, min(i) first_i,',
      'select q.domain_id, min(i) first_i, count(*)::int cnt,');
    if v_new not like '%_cote_shown(d.before%' or v_new not like '%_cote_shown(d.after%' or v_new not like '%count(*)::int cnt%' then
      raise exception '0046: _play_submit_rated inchangée';
    end if;
    execute v_new;
  end loop;

  -- Partie classée : 30 % accessibles (≈ 85 %), 50 % à son niveau (≈ 70 %), 20 % qui piquent (≈ 45 %).
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = '_band_bounds' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(v_old,
      'g_lo := -190; g_hi := -30;  -- 0027 : fenêtre unique, ≈ 65 % de réussite',
      'if r < 0.30 then g_lo := -400; g_hi := -200;   -- 0046 : accessibles
    elsif r < 0.80 then g_lo := -200; g_hi := -60;  -- à son niveau
    else g_lo := -60; g_hi := 80; end if;            -- qui piquent');
    if v_new = v_old then raise exception '0046: _band_bounds inchangée'; end if;
    execute v_new;
  end loop;

  -- Calibration : les vraies réponses prennent le dessus deux fois plus vite (10 points avant 20 réponses, 25 avant 50).
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = '_question_update' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(v_old, 'case when v_n < 20 then 5 when v_n < 50 then 15 else 100 end',
                            'case when v_n < 20 then 10 when v_n < 50 then 25 else 100 end');
    if v_new = v_old then raise exception '0046: _question_update inchangée'; end if;
    execute v_new;
  end loop;
end $$;

-- Questions encore peu jouées (moins de 20 réponses) : +5 de difficulté (estimations trop optimistes).
-- Les nouvelles questions du seed reçoivent ce +5 dans scripts/build-seed.mjs.
update public.questions set
  difficulty_initial = least(difficulty_initial + 5, 95),
  difficulty_min = least(difficulty_min + 5, 95),
  difficulty_max = least(difficulty_max + 5, 100),
  difficulty_observed = least(difficulty_observed + 5, 100)
where answer_count < 20;

-- Trophées de maîtrise : 750 / 900 / 1 050 / 1 200.
create or replace function public._mastery_cote(p_tier text) returns int language sql immutable as $$
  select case p_tier when 'bronze' then 750 when 'silver' then 900 when 'gold' then 1050 when 'diamond' then 1200 end
$$;

create or replace function public._mastery_sync(p_domain text) returns void
language sql as $$
  insert into public.achievements (id, name, description, reward_seeds, sort, category, chest, domain_id, tier)
  select 'mastery_' || d.id || '_' || t.tier,
         d.name || ' · ' || t.label,
         'Atteindre ' || t.cote_text || ' d''Elo en ' || d.name || '.',
         0, 1000 + d.sort * 10 + t.n, 'mastery', t.chest::public.chest_tier, d.id, t.tier
  from public.domains d
  cross join (values (1, 'bronze', 'Bronze', '750', 'wood'), (2, 'silver', 'Argent', '900', 'silver'),
                     (3, 'gold', 'Or', '1 050', 'gold'), (4, 'diamond', 'Diamant', '1 200', 'gold'))
             as t(n, tier, label, cote_text, chest)
  where d.id = p_domain
  on conflict (id) do update set name = excluded.name, description = excluded.description, sort = excluded.sort
$$;
select public._mastery_sync(id) from public.domains;

revoke execute on function public._cote_shown(real, int) from public, anon, authenticated;
revoke execute on function public._rating_json(uuid, text) from public, anon, authenticated;
revoke execute on function public._mastery_cote(text) from public, anon, authenticated;
revoke execute on function public._mastery_sync(text) from public, anon, authenticated;
alter function public._cote_shown(real, int) set search_path = public, pg_temp;
