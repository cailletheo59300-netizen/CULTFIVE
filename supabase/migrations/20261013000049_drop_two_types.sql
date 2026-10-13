-- ─────────────────────────────────────────── 0049 · Proportions et mot mystère abandonnés (choix du propriétaire)
-- Les deux types ne sont plus proposés dans le 5 du jour et le bonus du mot mystère disparaît. Leurs questions deviennent
-- des QCM (mêmes clés, même notion : scripts/build-seed.mjs). Les valeurs d'énumération restent (impossible de les retirer).

do $$
declare v_old text; v_new text;
begin
  select pg_get_functiondef('public._generate_daily_set'::regproc) into v_old;
  v_new := replace(replace(replace(v_old,
    'when ''french'' then array[''letters'', ''word_order'', ''riddle'']', 'when ''french'' then array[''letters'', ''word_order'']'),
    'when ''geo'' then array[''image_choice'', ''proportion'', ''counter'', ''map_pin'']', 'when ''geo'' then array[''image_choice'', ''counter'', ''map_pin'']'),
    'else array[''proportion'', ''gauge'', ''image_choice'', ''counter'', ''timeline'', ''letters'', ''word_order'', ''number_target'', ''riddle'', ''map_pin'', ''sort'']',
    'else array[''gauge'', ''image_choice'', ''counter'', ''timeline'', ''letters'', ''word_order'', ''number_target'', ''map_pin'', ''sort'']');
  if v_new like '%''proportion''%' or v_new like '%''riddle''%' then
    raise exception '0049: _generate_daily_set inchangée';
  end if;
  execute v_new;

  select pg_get_functiondef('public._record_attempt'::regproc) into v_old;
  v_new := replace(v_old,
    '  -- 0041 : mot mystère trouvé tôt : +3 graines au 1er indice, +1 au 2e.
  if v_correct and q.type = ''riddle'' and coalesce((p_given ->> ''clues'')::int, 3) <= 2 then
    perform public._grant(p_user, ''seeds'', case when (p_given ->> ''clues'')::int <= 1 then 3 else 1 end, ''riddle_bonus'', q.id::text,
                          ''riddle:'' || coalesce(p_client_id::text, q.id::text || '':'' || p_user::text));
  end if;
', '');
  if v_new = v_old then raise exception '0049: _record_attempt inchangée'; end if;
  execute v_new;
end $$;

-- Au cas où : plus aucune question de ces deux types n'est servie.
update public.questions set status = 'disabled' where type in ('proportion', 'riddle') and status = 'published';
