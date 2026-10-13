-- ─────────────────────────────────────────── 0048 · Difficulté revue à la main, appliquée aux questions déjà en base
-- Une question du seed marquée « reset_difficulty » (capitales et drapeaux revus pays par pays) remplace sa difficulté
-- d'origine et observée, tant qu'elle a moins de 20 réponses ; au-delà, ce sont les vraies réponses qui comptent.
do $$
declare f record; v_old text; v_new text;
begin
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = '_upsert_question' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(replace(v_old,
      'difficulty_min = coalesce((p ->> ''difficulty_min'')::real, difficulty_min),',
      'difficulty_initial = case when coalesce((p ->> ''reset_difficulty'')::bool, false) and answer_count < 20 then v_init else difficulty_initial end,
      difficulty_observed = case when coalesce((p ->> ''reset_difficulty'')::bool, false) and answer_count < 20 then v_init else difficulty_observed end,
      difficulty_min = case when coalesce((p ->> ''reset_difficulty'')::bool, false) and answer_count < 20 then greatest(v_init - 10, 0)
                            else coalesce((p ->> ''difficulty_min'')::real, difficulty_min) end,'),
      'difficulty_max = coalesce((p ->> ''difficulty_max'')::real, difficulty_max),',
      'difficulty_max = case when coalesce((p ->> ''reset_difficulty'')::bool, false) and answer_count < 20 then least(v_init + 10, 100)
                            else coalesce((p ->> ''difficulty_max'')::real, difficulty_max) end,');
    if v_new not like '%reset_difficulty%then least(v_init + 10, 100)%' then raise exception '0048: _upsert_question inchangée'; end if;
    execute v_new;
  end loop;
end $$;
