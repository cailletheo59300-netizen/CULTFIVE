-- ─────────────────────────────────────────── 0087 · Pub entre les parties : toutes les 5 minutes (D-110)
-- Pub entre les parties permise 12 h après l'inscription (24 h avant), pour toutes les versions de l'app.
-- L'app 1.5 ne compte plus les parties : à la fin de n'importe quelle partie, une pub passe si `interstitial_gap_s`
-- secondes se sont écoulées depuis la dernière ; `interstitial_daily_max` nul = pas de maximum par jour.
-- Les versions 1.4 et avant ignorent ces deux champs (1 pub toutes les 3 parties, 3 par jour, réglé dans l'app).

create or replace function public.ad_status() returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  p public.profiles;
begin
  select * into p from public.profiles where id = v_user;
  return jsonb_build_object(
    'double_seeds', greatest(3 - public._ad_used(v_user, 'double_seeds'), 0),
    'boost_chest', greatest(2 - public._ad_used(v_user, 'boost_chest'), 0),
    'free_chest', greatest(1 - public._ad_used(v_user, 'free_chest'), 0),
    'free_pack', greatest(1 - public._ad_used(v_user, 'free_pack'), 0),
    'streak_rescue', case when public._ad_used(v_user, 'streak_rescue') = 0 then public._streak_rescuable(v_user) end,
    -- Pas de pub entre les parties les 12 premières heures.
    'interstitial', p.created_at <= public._now() - interval '12 hours' and not public._has_pass(v_user),
    'interstitial_gap_s', 300,
    'interstitial_daily_max', null,
    'pass_plus', public._has_pass(v_user),
    'admin', exists (select 1 from public.app_admins where user_id = v_user));
end $$;
