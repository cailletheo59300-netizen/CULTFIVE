-- CULT FIVE — 0018 Chemin de recherche figé pour toutes les fonctions du schéma public
-- Recommandation du contrôle de sécurité Supabase (lint 0011) : une fonction sans search_path fixe résout les noms
-- selon le rôle appelant. Les fonctions SECURITY DEFINER l'avaient déjà ; on l'étend à toutes les autres.
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig
    from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and p.prokind in ('f', 'p')
      and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%')
  loop
    execute format('alter function %s set search_path = public, extensions, pg_temp', f.sig);
  end loop;
end $$;
