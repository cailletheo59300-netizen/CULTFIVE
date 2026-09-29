-- Brainlix — 0021 Règle de l'Elo
-- 1. Une partie ne fait bouger l'Elo que si elle couvre tout le domaine : dès que des thèmes sont choisis
--    (p_subdomain ou p_subdomains), c'est de l'entraînement libre, même si une ancienne version de l'app demande « classée ».
-- 2. « Mes erreurs » ne fait plus bouger l'Elo (sélection biaisée vers les points faibles), mais garde ses récompenses pleines.
-- Les fonctions sont réécrites à partir de leur définition en place ; chaque remplacement est vérifié.
do $$
declare
  f record;
  v_old text;
  v_new text;
begin
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = '_play_pack_base' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(v_old,
      'if p_ranked is distinct from false or p_mode = ''errors'' then p_ranked := true; p_level := null; end if;',
      'if p_mode = ''errors'' or p_subdomain is not null or p_subdomains is not null then p_ranked := false;
  elsif p_ranked is distinct from false then p_ranked := true; p_level := null;
  end if;');
    if v_new = v_old then raise exception '0021: _play_pack_base inchangée'; end if;
    execute v_new;
  end loop;

  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = '_play_submit_base' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(replace(v_old,
      'case when s.ranked then', 'case when s.ranked or s.mode = ''errors'' then'),
      'if s.ranked then', 'if s.ranked or s.mode = ''errors'' then');
    if v_new = v_old then raise exception '0021: _play_submit_base inchangée'; end if;
    execute v_new;
  end loop;
end $$;
