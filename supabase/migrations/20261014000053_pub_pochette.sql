-- ─────────────────────────────────────────── 0053 · Pub récompensée « pochette gratuite » (propriétaire, 14/10)
-- Une pub par jour, vérifiée par Google comme les autres (ad_ssv_record) : elle donne 1 ticket de pochette, que l'app
-- utilise aussitôt pour ouvrir la pochette choisie au Comptoir.

do $$
declare
  v_con text;
  v_old text; v_new text;
  v_list_old constant text := '(''double_seeds'', ''boost_chest'', ''free_chest'', ''streak_rescue'', ''correction'')';
  v_list_new constant text := '(''double_seeds'', ''boost_chest'', ''free_chest'', ''free_pack'', ''streak_rescue'', ''correction'')';
begin
  -- Type de pub accepté par la table.
  select conname into v_con from pg_constraint
  where conrelid = 'public.ad_views'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%free_chest%';
  execute format('alter table public.ad_views drop constraint %I', v_con);
  alter table public.ad_views add constraint ad_views_kind_check
    check (kind in ('double_seeds', 'boost_chest', 'free_chest', 'free_pack', 'streak_rescue', 'correction'));

  -- Vue vérifiée par Google, puis contrôle avant la pub.
  foreach v_old in array array['public.ad_ssv_record(text, text, text, text)', 'public._ad_check(uuid, text, text)'] loop
    select pg_get_functiondef(v_old::regprocedure) into v_new;
    if position(v_list_old in v_new) = 0 then raise exception '0053: % inchangée', v_old; end if;
    execute replace(v_new, v_list_old, v_list_new);
  end loop;

  -- Une par jour.
  select pg_get_functiondef('public._ad_limit(text)'::regprocedure) into v_old;
  v_new := replace(v_old, 'when ''free_chest'' then 1', 'when ''free_chest'' then 1 when ''free_pack'' then 1');
  if v_new = v_old then raise exception '0053: _ad_limit inchangée'; end if;
  execute v_new;

  -- État des pubs : pochettes gratuites restantes aujourd'hui.
  select pg_get_functiondef('public.ad_status()'::regprocedure) into v_old;
  v_new := replace(v_old, '''free_chest'', greatest(1 - public._ad_used(v_user, ''free_chest''), 0),',
    '''free_chest'', greatest(1 - public._ad_used(v_user, ''free_chest''), 0),
    ''free_pack'', greatest(1 - public._ad_used(v_user, ''free_pack''), 0),');
  if v_new = v_old then raise exception '0053: ad_status inchangée'; end if;
  execute v_new;

  -- Récompense : 1 ticket de pochette.
  select pg_get_functiondef('public.ad_claim(text, text, boolean)'::regprocedure) into v_old;
  v_new := replace(v_old, '    when ''streak_rescue'' then
      v_streak := public._streak_rescuable(v_user);',
    '    when ''free_pack'' then
      perform public._album_row(v_user);
      update public.user_album set tickets = tickets + 1 where user_id = v_user;
      v_reward := jsonb_build_object(''pack_tickets'', 1);
    when ''streak_rescue'' then
      v_streak := public._streak_rescuable(v_user);');
  if v_new = v_old then raise exception '0053: ad_claim inchangée'; end if;
  execute v_new;
end $$;
