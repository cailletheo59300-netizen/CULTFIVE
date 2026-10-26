-- Avatars (D-113) : 8 animaux en 3D (renard, panda, chat, hibou, grenouille, lapin, ours, pingouin), rangés dans
-- profiles.avatar sous la clé « animal ». Un au hasard pour chacun (anciens et nouveaux joueurs), changeable
-- gratuitement depuis le profil (avatar_set). L'avatar est ajouté partout où un pseudo d'un autre joueur est montré
-- (Arène, classements du jour) ; les amis, profils, duels et ligues l'envoyaient déjà.

create or replace function public._animals() returns text[] language sql immutable set search_path = public, pg_temp as $$
  select array['fox', 'panda', 'cat', 'owl', 'frog', 'rabbit', 'bear', 'penguin']
$$;

create or replace function public._random_animal() returns text language sql volatile set search_path = public, pg_temp as $$
  select (public._animals())[1 + floor(random() * 8)::int]
$$;

update public.profiles set avatar = avatar || jsonb_build_object('animal', public._random_animal())
where not (avatar ? 'animal') or not (avatar ->> 'animal' = any (public._animals()));

-- Nouveaux joueurs : un animal au hasard dès la création du profil.
create or replace function public._profile_animal() returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if not (coalesce(new.avatar, '{}'::jsonb) ? 'animal') then
    new.avatar := coalesce(new.avatar, '{}'::jsonb) || jsonb_build_object('animal', public._random_animal());
  end if;
  return new;
end $$;
drop trigger if exists profiles_animal on public.profiles;
create trigger profiles_animal before insert or update of avatar on public.profiles
  for each row execute function public._profile_animal();

-- Changer d'avatar : gratuit, un des 8 seulement.
create or replace function public.avatar_set(p_animal text) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user(); v_avatar jsonb;
begin
  if not (p_animal = any (public._animals())) then raise exception 'invalid_avatar'; end if;
  update public.profiles set avatar = avatar || jsonb_build_object('animal', p_animal) where id = v_user
  returning avatar into v_avatar;
  return v_avatar;
end $$;
revoke execute on function public.avatar_set(text) from public, anon;
grant execute on function public.avatar_set(text) to authenticated;

-- Modifie une fonction existante sur place : chaque remplacement doit trouver son texte.
create or replace function pg_temp.patch(p_fn regprocedure, p_pairs text[]) returns void language plpgsql as $$
declare v_def text := pg_get_functiondef(p_fn); v_new text; i int;
begin
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    v_new := replace(v_def, p_pairs[2 * i - 1], p_pairs[2 * i]);
    if v_new = v_def then raise exception 'patch % : texte % introuvable', p_fn, i; end if;
    v_def := v_new;
  end loop;
  execute v_def;
end $$;

-- Une ancienne app qui renverrait un avatar sans animal ne l'efface pas.
select pg_temp.patch('public.profile_update(jsonb)', array[
  'then p -> ''avatar'' else avatar end,',
  'then avatar || (p -> ''avatar'') else avatar end,'
]);

select pg_temp.patch('public._arena_json(public.duels, uuid)', array[
  '''id'', v_other, ''handle'', (select handle from public.profiles where id = v_other),',
  '''id'', v_other, ''handle'', (select handle from public.profiles where id = v_other),
        ''avatar'', (select avatar from public.profiles where id = v_other),'
]);

select pg_temp.patch('public._arena_row(uuid, int, int, int, int, bool, uuid, uuid)', array[
  '''handle'', p.handle,', '''handle'', p.handle, ''avatar'', p.avatar,'
]);

select pg_temp.patch('public.arena_overview()', array[
  'jsonb_build_object(''id'', v_champion, ''handle'', (select handle from public.profiles where id = v_champion))',
  'jsonb_build_object(''id'', v_champion, ''handle'', (select handle from public.profiles where id = v_champion),
                                        ''avatar'', (select avatar from public.profiles where id = v_champion))'
]);

select pg_temp.patch('public._leaderboard_json(uuid, text, text)', array[
  '''rank'', d.rank, ''handle'', p.handle, ''score''', '''rank'', d.rank, ''handle'', p.handle, ''avatar'', p.avatar, ''score''',
  '''rank'', d.rank, ''handle'', p.handle, ''elo''', '''rank'', d.rank, ''handle'', p.handle, ''avatar'', p.avatar, ''elo'''
]);
