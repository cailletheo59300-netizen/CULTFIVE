-- ─────────────────────────────────────────── 0050 · search_path fixé (contrôle de sécurité Supabase)
-- 0046 a redéfini ces fonctions sans leur `search_path` : on le remet, comme pour toutes les autres.
alter function public._rating_json(uuid, text) set search_path = public, pg_temp;
alter function public._mastery_cote(text) set search_path = public, pg_temp;
alter function public._mastery_sync(text) set search_path = public, pg_temp;
