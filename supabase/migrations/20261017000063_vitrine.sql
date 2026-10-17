-- Vitrine du profil (D-067) : le joueur pose jusqu'à 3 de ses cartes sur un socle gagné dans le pass
-- (socle.marbre, socle.or, socle.neon, socle.glace ; aucun socle : présentoir simple). Ses amis la voient sur son profil.
-- Les cartes gardent leur habillage et leurs états affichés ; une carte ou un socle qui n'est plus possédé disparaît.
create table public.user_showcase (
  user_id     uuid primary key references public.profiles(id) on delete cascade,
  -- Nom du socle (« marbre », « or »…), sans le préfixe « socle. » ; null : présentoir simple.
  socle       text check (socle ~ '^[a-z0-9_]+$'),
  -- Identifiants serveur des cartes, dans l'ordre : la première au centre.
  cards       text[] not null default '{}' check (cardinality(cards) <= 3),
  updated_at  timestamptz not null default now()
);
alter table public.user_showcase enable row level security;
revoke all on public.user_showcase from public, anon, authenticated;

-- Vitrine d'un joueur : socle encore possédé, cartes encore possédées (collection normale) avec ce qu'elles affichent.
create or replace function public._showcase_json(p_user uuid) returns jsonb
language sql stable security definer set search_path = public, pg_temp as $$
  select jsonb_build_object(
    'socle', (select s.socle from public.user_cosmetics uc
              where uc.user_id = p_user and uc.item_id = 'socle.' || s.socle),
    'cards', coalesce((
      select jsonb_agg(jsonb_build_object(
               'card', c.card_id,
               'shiny', c.shiny and not 'shiny' = any(c.hidden),
               'prestige', c.prestige and not 'prestige' = any(c.hidden),
               'masterpiece', coalesce(c.forced_masterpiece, st.stars = 3, false) and not 'masterpiece' = any(c.hidden),
               'frame', c.frame, 'finish', c.finish, 'title', c.title) order by x.ord)
      from unnest(s.cards) with ordinality x(card_id, ord)
      join public.user_cards c on c.user_id = p_user and c.slot = 0 and c.card_id = x.card_id
      left join public._album_stars(p_user) st on st.card_id = c.card_id), '[]'::jsonb))
  from (select us.socle, coalesce(us.cards, '{}') cards
        from (select 1) one left join public.user_showcase us on us.user_id = p_user) s
$$;

create or replace function public.showcase_get() returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  return public._showcase_json(public._require_user());
end $$;

-- Enregistre la vitrine : socle possédé (ou null), 3 cartes possédées au plus, sans doublon.
create or replace function public.showcase_set(p_socle text, p_cards text[]) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  v_cards text[] := coalesce(p_cards, '{}');
begin
  if cardinality(v_cards) > 3 then raise exception 'too_many_cards'; end if;
  if (select count(distinct c) from unnest(v_cards) c) <> cardinality(v_cards) then raise exception 'duplicate_card'; end if;
  if exists (select 1 from unnest(v_cards) c
             where not exists (select 1 from public.user_cards uc where uc.user_id = v_user and uc.slot = 0 and uc.card_id = c)) then
    raise exception 'card_not_owned';
  end if;
  if p_socle is not null and not exists (select 1 from public.user_cosmetics
                                         where user_id = v_user and item_id = 'socle.' || p_socle) then
    raise exception 'socle_not_owned';
  end if;
  insert into public.user_showcase (user_id, socle, cards, updated_at) values (v_user, p_socle, v_cards, now())
  on conflict (user_id) do update set socle = excluded.socle, cards = excluded.cards, updated_at = excluded.updated_at;
  return public._showcase_json(v_user);
end $$;

revoke execute on function public._showcase_json(uuid) from public, anon, authenticated;
revoke execute on function public.showcase_get(), public.showcase_set(text, text[]) from public, anon;
grant execute on function public.showcase_get(), public.showcase_set(text, text[]) to authenticated;

-- Profil d'un ami : sa vitrine en plus.
do $$
declare f oid; v_old text; v_new text;
begin
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'friend_profile' loop
    v_old := pg_get_functiondef(f);
    v_new := replace(v_old, '''duels'', v_list);', '''duels'', v_list, ''showcase'', public._showcase_json(p.id));');
    if v_new = v_old then raise exception '0063: friend_profile inchangée'; end if;
    execute v_new;
  end loop;
end $$;
