-- Notifications push : jetons, préférences, heures calmes, limite par jour, évènements ; nettoyage des comptes anonymes.
do $$
declare
  a uuid := tst.new_user(); b uuid := tst.new_user(); c uuid := tst.new_user();
  d jsonb; r jsonb; n int;
begin
  perform tst.clock('2027-05-03 15:00:00+02');
  perform public._befriend(a, b);
  perform tst.login(b);
  perform public.push_register(repeat('ab', 32));
  perform tst.throws('select public.push_register(''pas-un-jeton'')', 'invalid_token');

  -- Duel reçu : B est prévenu ; A (sans jeton) ne l'est pas.
  perform tst.login(a);
  d := public.duel_create(b, 5);
  perform tst.ok(exists (select 1 from public.push_outbox where user_id = b and dedupe_key = 'duel_new:' || (d ->> 'id')),
                 'B prévenu du duel');
  perform tst.ok((select body from public.push_outbox where user_id = b limit 1) like '% te défie : 5 questions%', 'texte du duel');

  -- Envoi : la fonction d'envoi récupère la notification et ses jetons, une seule fois.
  r := public.push_claim(10);
  perform tst.ok(jsonb_array_length(r) = 1 and jsonb_array_length(r -> 0 -> 'tokens') = 1, 'notification prise avec son jeton');
  perform tst.ok(jsonb_array_length(public.push_claim(10)) = 0, 'jamais prise deux fois');
  perform public.push_done((r -> 0 ->> 'id')::bigint);

  -- Préférence « Duels et amis » coupée : plus rien.
  perform tst.login(b);
  perform public.profile_update('{"notif_social": false}'::jsonb);
  perform tst.ok(not (public.profile_me() ->> 'notif_social')::bool, 'préférence enregistrée');
  perform tst.login(a);
  d := public.duel_create(b, 5);
  perform tst.ok(not exists (select 1 from public.push_outbox where dedupe_key = 'duel_new:' || (d ->> 'id')), 'préférence respectée');
  update public.profiles set notif_social = true where id = b;

  -- Heures calmes : à 23 h, envoi reporté au lendemain 8 h (heure de Paris).
  perform tst.clock('2027-05-03 23:00:00+02');
  d := public.duel_create(b, 5);
  perform tst.ok((select send_after from public.push_outbox where dedupe_key = 'duel_new:' || (d ->> 'id'))
                 = '2027-05-04 08:00:00+02', 'reporté à 8 h');

  -- 5 par jour au plus.
  perform tst.clock('2027-05-05 10:00:00+02');
  for i in 1 .. 7 loop perform public.duel_create(b, 5); end loop;
  perform tst.ok((select count(*) from public.push_outbox where user_id = b and local_day = '2027-05-05') = 5, '5 par jour');

  -- Demande d'ami reçue, puis acceptée.
  perform public.push_register(repeat('cd', 32));   -- A a maintenant un jeton
  perform tst.login(c);
  perform public.push_register(repeat('ef', 32));
  perform public.friend_request((select handle from public.profiles where id = a));
  perform tst.ok(exists (select 1 from public.push_outbox where user_id = a and dedupe_key like 'friend_request:%'), 'demande reçue');
  perform tst.login(a);
  perform public.friend_respond((select id from public.friendships where requester_id = c and addressee_id = a), true);
  perform tst.ok(exists (select 1 from public.push_outbox where user_id = c and dedupe_key like 'friend_accept:%'), 'demande acceptée');

  -- Jeton invalide oublié ; sécurité.
  perform public.push_token_invalid(repeat('ef', 32));
  perform tst.ok(not exists (select 1 from public.push_tokens where user_id = c), 'jeton invalide oublié');
  perform tst.ok(not has_function_privilege('authenticated', 'public.push_claim(int)', 'execute'), 'envoi réservé au serveur');
end $$;

-- Ligues : rappel du quiz à 19 h, fin de saison.
do $$
declare a uuid := tst.new_user(); l jsonb;
begin
  perform tst.clock('2027-06-01 10:00:00+02');
  perform tst.login(a);
  perform public.push_register(repeat('12', 32));
  l := public.league_create('Les Soirs', 5, null, 'auto', '1w', true, 50);
  perform tst.clock('2027-06-01 19:10:00+02');
  perform public.cron_league_notifications();
  perform tst.ok(exists (select 1 from public.push_outbox where user_id = a and dedupe_key like 'league_quiz:%'), 'rappel du quiz à 19 h');
  perform tst.clock('2027-06-08 09:00:00+02');
  perform public.cron_league_notifications();
  perform tst.ok((select body from public.push_outbox where user_id = a and dedupe_key like 'league_end:%') = 'Tu finis 1er sur 1.',
                 'fin de ligue');
end $$;

-- Comptes anonymes abandonnés.
do $$
declare old uuid := tst.new_user(true); fresh uuid := tst.new_user(true); played uuid := tst.new_user(true);
begin
  perform tst.clock('2027-07-01 10:00:00+02');
  update public.profiles set created_at = public._now() - interval '10 days' where id in (old, played);
  update public.profiles set created_at = public._now() - interval '1 day' where id = fresh;
  update public.profiles set onboarded_at = public._now() - interval '9 days' where id = played;
  perform public.cron_cleanup_anonymous();
  perform tst.ok(not exists (select 1 from public.profiles where id = old), 'anonyme abandonné supprimé');
  perform tst.ok(exists (select 1 from public.profiles where id = fresh), 'compte récent gardé');
  perform tst.ok(exists (select 1 from public.profiles where id = played), 'compte qui a joué gardé');
end $$;
