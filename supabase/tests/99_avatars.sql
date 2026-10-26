-- Avatars (0091) : un animal au hasard pour chaque joueur, changeable, visible dans l'Arène et les classements.
do $$
declare a uuid := tst.new_user(); b uuid := tst.new_user(); r jsonb;
begin
  perform tst.ok((select avatar ->> 'animal' from public.profiles where id = a) = any (public._animals()), 'animal au hasard à l''inscription');
  perform tst.login(a);
  r := public.avatar_set('curie');
  perform tst.ok(r ->> 'animal' = 'curie' and (public.profile_me() -> 'avatar' ->> 'animal') = 'curie', 'avatar changé');
  perform tst.throws('select public.avatar_set(''dragon'')', 'invalid_avatar');
  -- Une ancienne app qui renvoie l'avatar de Léon ne perd pas l'animal.
  perform public.profile_update('{"avatar": {"color": "chloro", "pose": "rest"}}'::jsonb);
  perform tst.ok((public.profile_me() -> 'avatar' ->> 'animal') = 'curie', 'avatar gardé');
  perform tst.ok((public._arena_row(a, 1, 3, 1, 1, true, a, null) -> 'avatar' ->> 'animal') = 'curie', 'avatar dans le classement de l''Arène');
end $$;
