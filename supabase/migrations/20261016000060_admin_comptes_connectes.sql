-- ─────────────────────────────────────────── 0060 · Admin : tous les comptes connectés comptent
-- Correction de 0059 demandée par le propriétaire : il joue comme un joueur avec ses comptes connectés, qui doivent
-- compter. Seuls les **invités** sont filtrés : comptés 3 jours, puis seulement avec au moins 10 réponses, et jamais
-- s'ils viennent d'un appareil d'admin (comptes invités de test).

create or replace function public._real_player(p_user uuid) returns bool
language sql stable set search_path = public, pg_temp as $$
  select exists (select 1 from auth.users u where u.id = p_user and not coalesce(u.is_anonymous, true))
      or (not exists (select 1 from public.app_admins a where a.user_id = p_user)
          and not exists (select 1 from public.user_devices d
                          join public.user_devices d2 on d2.device_hash = d.device_hash and d2.user_id <> d.user_id
                          join public.app_admins a on a.user_id = d2.user_id
                          where d.user_id = p_user)
          and exists (select 1 from public.profiles p where p.id = p_user and p.onboarded_at is not null
                        and (p.created_at > public._now() - interval '3 days'
                             or (select count(*) from (select 1 from public.question_attempts q
                                                       where q.user_id = p_user limit 10) s) >= 10)))
$$;
revoke execute on function public._real_player(uuid) from public, anon, authenticated;
