-- Pubs (D-064) : Unity Ads entre dans les enchères AdMob (côté app). Le journal d'usage note pourquoi une pub
-- récompensée n'a pas pu s'afficher (« ad_fail » : pas de pub en stock, consentement refusé…) et l'ouverture des
-- choix de confidentialité des pubs depuis les réglages (« ad_privacy »).
alter table public.app_events drop constraint app_events_name_check;
alter table public.app_events add constraint app_events_name_check check (name in (
  'app_open', 'onboarding_step', 'onboarding_done', 'share', 'reminder_optin', 'notif_permission',
  'ad_offer', 'ad_view', 'ad_reward', 'interstitial', 'campaign', 'client_error',
  'pass_view', 'pass_buy', 'pass_bonus', 'ad_fail', 'ad_privacy'));
