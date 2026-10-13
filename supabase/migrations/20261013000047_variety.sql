-- ─────────────────────────────────────────── 0047 · Moins de questions qui se ressemblent
-- Les questions sans famille qui commencent pareil (« Quel nombre suit… », « Quel est le contraire de… ») ont désormais une
-- famille automatique (scripts/build-seed.mjs). En plus de la règle existante (une famille par partie), les familles de la
-- partie précédente sont évitées tant que c'est possible : deux parties de suite ne se ressemblent plus.

do $$
declare f record; v_old text; v_new text;
begin
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = '_select_questions' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(replace(v_old,
      '  v_families text[] := ''{}'';',
      '  v_families text[] := ''{}'';
  -- 0047 : familles de la dernière partie terminée, évitées tant que possible.
  v_recent_families text[] := coalesce((
    select array_agg(distinct q0.family) from public.question_attempts a0 join public.questions q0 on q0.id = a0.question_id
    where a0.user_id = p_user and q0.family is not null
      and a0.session_id = (select s0.id from public.play_sessions s0
                           where s0.user_id = p_user and s0.completed_at is not null order by s0.completed_at desc limit 1)),
    ''{}'');'),
      '        and (lvl >= 4 or q.family is null or (',
      '        and (lvl >= 2 or q.family is null or q.family <> all (v_recent_families))
        and (lvl >= 4 or q.family is null or (');
    if v_new not like '%v_recent_families text[]%' or v_new not like '%q.family <> all (v_recent_families)%' then
      raise exception '0047: _select_questions inchangée';
    end if;
    execute v_new;
  end loop;
end $$;
