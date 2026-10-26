-- Vitesse du serveur (D-116).
-- 1. Questions « protégées » du 5 du jour : la liste était recalculée pour CHAQUE question candidate (des milliers de
--    fois par appel : recherche d'adversaire de l'Arène jusqu'à 3,4 s, création de duel 0,6 à 0,9 s, Survie, parties…).
--    Elle passe en sous-requête, calculée une seule fois par requête. Même résultat, beaucoup plus vite.
do $$
declare r record; v_def text;
begin
  for r in select p.oid from pg_proc p
           where p.pronamespace = 'public'::regnamespace and p.prokind = 'f' and p.proname <> '_protected_daily_questions'
             and pg_get_functiondef(p.oid) like '%public._protected_daily_questions()%'
             and pg_get_functiondef(p.oid) not like '%(select public._protected_daily_questions())%' loop
    v_def := replace(pg_get_functiondef(r.oid), 'public._protected_daily_questions()', '(select public._protected_daily_questions())::uuid[]');
    execute v_def;
  end loop;
end $$;

-- 2. Tableau de bord admin : admin_kpis (2,3 s en moyenne, jusqu'à 8 s, appelé à chaque ouverture) et admin_ads
--    occupaient la base pendant que les joueurs jouaient. Résultat gardé 10 minutes ; « rafraîchir » au-delà.
create table if not exists public.admin_cache (
  key text primary key,
  value jsonb not null,
  computed_at timestamptz not null default now()
);
alter table public.admin_cache enable row level security;
revoke all on public.admin_cache from public, anon, authenticated;

alter function public.admin_kpis(int) rename to _admin_kpis_compute;
alter function public.admin_ads(int) rename to _admin_ads_compute;
revoke execute on function public._admin_kpis_compute(int), public._admin_ads_compute(int) from public, anon, authenticated;

create or replace function public._admin_cached(p_key text, p_days int) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v jsonb; v_key text := p_key || ':' || least(greatest(coalesce(p_days, 30), 7), 180);
begin
  perform public._require_admin();
  select value into v from public.admin_cache where key = v_key and computed_at > now() - interval '10 minutes';
  if v is not null then return v; end if;
  v := case p_key when 'kpis' then public._admin_kpis_compute(p_days) else public._admin_ads_compute(p_days) end;
  insert into public.admin_cache (key, value, computed_at) values (v_key, v, now())
  on conflict (key) do update set value = excluded.value, computed_at = excluded.computed_at;
  return v;
end $$;
revoke execute on function public._admin_cached(text, int) from public, anon, authenticated;

create or replace function public.admin_kpis(p_days int default 30) returns jsonb
language sql security definer set search_path = public, pg_temp as $$ select public._admin_cached('kpis', p_days) $$;
create or replace function public.admin_ads(p_days int default 30) returns jsonb
language sql security definer set search_path = public, pg_temp as $$ select public._admin_cached('ads', p_days) $$;
revoke execute on function public.admin_kpis(int), public.admin_ads(int) from public, anon;
grant execute on function public.admin_kpis(int), public.admin_ads(int) to authenticated;
