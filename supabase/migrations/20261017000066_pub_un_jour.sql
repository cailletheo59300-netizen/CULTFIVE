-- Pub entre les parties (D-069) : dès 1 jour après la création du compte, au lieu de 3.
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
    -- Pas de pub entre les parties le premier jour.
    'interstitial', p.created_at <= public._now() - interval '1 day' and not public._has_pass(v_user),
    'pass_plus', public._has_pass(v_user),
    'admin', exists (select 1 from public.app_admins where user_id = v_user));
end $$;
