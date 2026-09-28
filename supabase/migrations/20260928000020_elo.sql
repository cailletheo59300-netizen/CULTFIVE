-- Brainlix — 0020 La « cote » s'appelle « Elo » pour les joueurs : libellé de l'objectif de la semaine
-- La fonction est réécrite à partir de sa définition en place (seul le libellé change), puis les objectifs déjà tirés sont corrigés.
do $$
declare f record;
begin
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = '_quests_ensure' loop
    execute replace(pg_get_functiondef(f.oid), 'Gagne 30 points de cote dans un domaine', 'Gagne 30 points d''''Elo dans un domaine');
  end loop;
end $$;

update public.user_quests set label = 'Gagne 30 points d''Elo dans un domaine' where label = 'Gagne 30 points de cote dans un domaine';
