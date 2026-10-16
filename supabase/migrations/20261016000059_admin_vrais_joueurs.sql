-- ─────────────────────────────────────────── 0059 · Admin : des vrais joueurs, sans les comptes de test
-- Demande du propriétaire : ses propres comptes invités (tests) et les invités qui n'ont presque pas joué faussaient
-- les chiffres. Partout dans l'admin, un joueur compté est désormais :
--   · un compte connecté (Apple ou e-mail) ;
--   · ou un invité qui a fini l'onboarding, pendant ses 3 premiers jours, puis seulement s'il a au moins 10 réponses ;
--   · jamais un compte admin, ni un compte créé sur le même appareil qu'un admin (comptes de test).
-- Rien n'est supprimé : ces comptes sont seulement retirés des statistiques (« Tous » les montre encore).

create or replace function public._real_player(p_user uuid) returns bool
language sql stable set search_path = public, pg_temp as $$
  select not exists (select 1 from public.app_admins a where a.user_id = p_user)
     and not exists (select 1 from public.user_devices d
                     join public.user_devices d2 on d2.device_hash = d.device_hash and d2.user_id <> d.user_id
                     join public.app_admins a on a.user_id = d2.user_id
                     where d.user_id = p_user)
     and (exists (select 1 from auth.users u where u.id = p_user and not coalesce(u.is_anonymous, true))
          or exists (select 1 from public.profiles p where p.id = p_user and p.onboarded_at is not null
                       and (p.created_at > public._now() - interval '3 days'
                            or (select count(*) from (select 1 from public.question_attempts q
                                                      where q.user_id = p_user limit 10) s) >= 10)))
$$;
revoke execute on function public._real_player(uuid) from public, anon, authenticated;
