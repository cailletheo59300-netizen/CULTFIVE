-- Objets de départ pour tous (D-119, propriétaire, 30/10) : chaque compte existant reçoit tout de suite 1 objet de
-- chaque, sans attendre d'ouvrir la boutique ou l'écran d'avant-partie (une seule fois : _starter_items le note).
do $$
declare v_user uuid;
begin
  for v_user in select id from public.profiles where starter_items_at is null loop
    perform public._starter_items(v_user);
  end loop;
end $$;
