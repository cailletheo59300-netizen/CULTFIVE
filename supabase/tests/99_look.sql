-- Look du joueur (D-120) : avatars premium, contours, titres, Prestige, bienvenue.
do $$
declare
  u uuid := tst.new_user();
  a jsonb; o jsonb;
begin
  perform tst.clock('2026-11-12 10:00:00+01');
  perform tst.login(u);

  -- Rien de premium sans achat.
  perform tst.throws('select public.avatar_set(''joan'')', 'invalid_avatar');
  perform tst.throws('select public.look_set(''ring'', ''neon'')', 'look_not_owned');
  perform tst.throws('select public.look_set(''hat'', ''x'')', 'invalid_look');
  a := public.avatar_set('curie');
  perform tst.ok(a ->> 'animal' = 'curie', 'avatars gratuits toujours possibles');
  -- profile_update ne pose pas de look.
  perform public.profile_update('{"avatar": {"animal": "joan", "ring": "neon", "title": "genie", "hat": 1}}'::jsonb);
  a := (select avatar from public.profiles where id = u);
  perform tst.ok(a ->> 'animal' = 'curie' and not (a ? 'ring') and not (a ? 'title') and (a ? 'hat'), 'profile_update : look protégé');

  -- Lot des 4 avatars.
  perform public.iap_record(u, 'tx-look-lot', 'tx-look-lot', 'app.brainlix.avatars', 'Production', public._now());
  a := public.avatar_set('darwin');
  perform tst.ok(a ->> 'animal' = 'darwin', 'avatar premium posé');
  perform tst.throws('select public.avatar_set(''tut'')', 'invalid_avatar');

  -- Contour et titre.
  perform public.iap_record(u, 'tx-look-neon', 'tx-look-neon', 'app.brainlix.ring.neon', 'Production', public._now());
  perform public.iap_record(u, 'tx-look-genie', 'tx-look-genie', 'app.brainlix.title.genie', 'Production', public._now());
  a := public.look_set('ring', 'neon');
  a := public.look_set('title', 'genie');
  perform tst.ok(a ->> 'ring' = 'neon' and a ->> 'title' = 'genie', 'contour et titre posés');
  a := public.look_set('title', null);
  perform tst.ok(not (a ? 'title') and a ->> 'ring' = 'neon', 'titre retiré');

  -- Prestige et bienvenue : exclusifs.
  perform public.iap_record(u, 'tx-look-prestige', 'tx-look-prestige', 'app.brainlix.prestige', 'Production', public._now());
  perform public.iap_record(u, 'tx-look-bienvenue', 'tx-look-bienvenue', 'app.brainlix.bienvenue', 'Production', public._now());
  a := public.avatar_set('tut');
  a := public.look_set('ring', 'prestige');
  a := public.look_set('title', 'legend');
  perform tst.ok(a ->> 'animal' = 'tut' and a ->> 'ring' = 'prestige' and a ->> 'title' = 'legend', 'Prestige : avatar, contour, titre');
  perform public.avatar_set('hypatia');
  o := public.boutique_overview();
  perform tst.ok(o -> 'looks' ? 'avatar.hypatia' and o -> 'looks' ? 'ring.welcome' and jsonb_array_length(o -> 'looks') = 16,
                 format('looks possédés (%s)', jsonb_array_length(o -> 'looks')));
  -- Un classement envoie le look avec l'avatar.
  perform tst.ok((select avatar ->> 'ring' from public.profiles where id = u) = 'prestige', 'look dans profiles.avatar');
end $$;

-- Pack Prestige seul : tout le look.
do $$
declare u uuid := tst.new_user(); o jsonb;
begin
  perform tst.login(u);
  perform public.iap_record(u, 'tx-look-prestige-2', 'tx-look-prestige-2', 'app.brainlix.prestige', 'Production', public._now());
  o := public.boutique_overview();
  perform tst.ok(jsonb_array_length(o -> 'looks') = 14 and o -> 'looks' ? 'avatar.joan' and o -> 'looks' ? 'ring.rainbow'
                 and o -> 'looks' ? 'title.genie' and o -> 'looks' ? 'title.legend', 'Prestige : tout le look et les exclusifs');
end $$;
