-- ─────────────────────────────────────────── 0052 · Moins de tickets d'aide dans les coffres (propriétaire, 14/10)
-- On gagnait trop de tickets 50/50 et indice (les coffres sont nombreux : pass, défis, niveaux). Désormais :
-- bois 1 ticket une fois sur 3 (au lieu de 1) · argent 1 (au lieu de 2) · or 1 (au lieu de 0) · Savant 1 (au lieu de 2).
-- Soit environ deux fois moins de tickets au total.

do $$
declare v_old text; v_new text;
begin
  select pg_get_functiondef('public.chest_open(uuid)'::regprocedure) into v_old;
  v_new := replace(v_old,
    '  if v_final = ''savant'' then
    v_fifty := 1; v_hint := 1;
  else
    v_tickets := case v_final when ''wood'' then 1 when ''silver'' then 2 else 0 end;',
    '  -- 0052 : un ticket au plus par coffre (bois : une fois sur 3).
  if v_final = ''savant'' then
    if random() < 0.5 then v_fifty := 1; else v_hint := 1; end if;
  else
    v_tickets := case v_final when ''wood'' then (random() < 1.0 / 3)::int else 1 end;');
  if v_new = v_old then raise exception '0052: chest_open inchangée'; end if;
  execute v_new;
end $$;
