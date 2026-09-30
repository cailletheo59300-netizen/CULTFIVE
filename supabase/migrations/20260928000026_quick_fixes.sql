-- Brainlix — 0026 Corrections après une heure de jeu réelle
-- 1. Fuseau horaire : la vérification parcourait pg_timezone_names (≈ 800 ms à chaque lancement). Conversion directe à la place.
-- 2. Aides : deux touchers rapprochés sur la même aide sont traités l'un après l'autre (verrou par aide) ; le second
--    voit l'aide déjà obtenue et ne coûte rien, au lieu de finir en erreur.
-- 3. Indices « La réponse commence par X » retirés : ils donnaient la réponse. Restent les indices écrits à la main
--    et les fourchettes de nombres.
do $$
declare
  f record;
  v_old text;
  v_new text;
begin
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'set_timezone' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(v_old,
      'if not exists (select 1 from pg_timezone_names where name = p_tz) then raise exception ''invalid_timezone''; end if;',
      'begin
    perform now() at time zone p_tz;
  exception when others then
    raise exception ''invalid_timezone'';
  end;');
    if v_new = v_old then raise exception '0026: set_timezone inchangée'; end if;
    execute v_new;
  end loop;

  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'play_spend_help' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(v_old,
      '  v_key := ''help:'' || s.id || '':'' || q.id || '':'' || p_kind;',
      '  v_key := ''help:'' || s.id || '':'' || q.id || '':'' || p_kind;
  perform pg_advisory_xact_lock(hashtext(v_user::text || v_key));');
    if v_new = v_old then raise exception '0026: play_spend_help inchangée'; end if;
    execute v_new;
  end loop;
end $$;

update public.questions set hint = null where hint like 'La réponse commence par%';
