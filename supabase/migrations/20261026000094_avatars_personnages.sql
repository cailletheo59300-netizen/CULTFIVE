-- Avatars (D-115) : les 8 animaux deviennent 8 grandes figures de la culture (Léonard de Vinci, Marie Curie, Isaac
-- Newton, Napoléon, Mozart, Cléopâtre, Shakespeare, Socrate). Même clé `avatar.animal`, nouvelles valeurs ; chaque
-- joueur garde la « place » de son animal (renard → Vinci, panda → Curie…), donc la répartition reste au hasard.

create or replace function public._animals() returns text[] language sql immutable set search_path = public, pg_temp as $$
  select array['vinci', 'curie', 'newton', 'napoleon', 'mozart', 'cleopatra', 'shakespeare', 'socrates']
$$;

update public.profiles set avatar = avatar || jsonb_build_object('animal', case avatar ->> 'animal'
    when 'fox' then 'vinci' when 'panda' then 'curie' when 'cat' then 'newton' when 'owl' then 'socrates'
    when 'frog' then 'napoleon' when 'rabbit' then 'mozart' when 'bear' then 'shakespeare' when 'penguin' then 'cleopatra'
    else public._random_animal() end)
where not (avatar ->> 'animal' = any (public._animals())) or not (avatar ? 'animal');
