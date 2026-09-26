-- Économie (aides, ledger), pseudo, amis, parrainage, ligues, suppression de compte.

-- Aides : payées en graines, refusées sans solde, jamais pour le Daily, pas refacturées.
do $$
declare u uuid := tst.new_user(); pack jsonb; q jsonb; h jsonb; v_session uuid;
begin
  perform tst.clock('2026-12-01 10:00:00+01');
  perform tst.login(u);
  delete from public.daily_sets where daily_date > '2026-12-03';
  pack := public.play_pack('training', 'geography', 'geography.capitals', 5);
  v_session := (pack ->> 'session_id')::uuid;
  select x into q from jsonb_array_elements(pack -> 'questions') x where x ->> 'type' = 'mcq' limit 1;
  perform tst.throws(format('select public.play_spend_help(%L, %L, ''fifty_fifty'')', v_session, q ->> 'id'), 'insufficient_seeds');
  perform public._grant(u, 'seeds', 40, 'test', null, 'test-credit');
  h := public.play_spend_help(v_session, (q ->> 'id')::uuid, 'fifty_fifty');
  perform tst.ok(jsonb_array_length(h -> 'remove') = 2, '50/50 retire 2 options');
  perform tst.ok(not (h -> 'remove') ? (q -> 'answer' ->> 'option_id'), 'la bonne réponse n''est jamais retirée');
  perform tst.ok((h ->> 'balance')::int = 25, 'coût 15');
  h := public.play_spend_help(v_session, (q ->> 'id')::uuid, 'fifty_fifty');
  perform tst.ok((h ->> 'balance')::int = 25, 'pas refacturé');
  perform tst.throws(format('select public.play_spend_help(%L, %L, ''jackpot'')', v_session, q ->> 'id'), 'invalid_help');
  perform tst.ok((select sum(amount) from public.ledger where user_id = u and currency = 'seeds') = (select seeds from public.profiles where id = u),
                 'solde = somme du ledger');
end $$;

-- Pseudo : validation, unicité insensible à la casse, termes interdits, délai de changement.
do $$
declare a uuid := tst.new_user(); b uuid := tst.new_user();
begin
  perform tst.clock('2026-12-02 10:00:00+01');
  perform tst.login(a);
  perform public.set_handle('Theo_59');
  perform tst.login(b);
  perform tst.ok(not (public.handle_available('theo_59') ->> 'available')::bool, 'unicité insensible à la casse');
  perform tst.throws('select public.set_handle(''THEO_59'')', 'handle_taken');
  perform tst.ok(public.handle_available('ab') ->> 'reason' = 'invalid', 'trop court');
  perform tst.ok(public.handle_available('SuperAdmin') ->> 'reason' = 'not_allowed', 'terme réservé');
  perform tst.throws('select public.set_handle(''x y'')', 'handle_invalid');
  perform public.set_handle('Bea');
  perform tst.throws('select public.set_handle(''Bea2'')', 'handle_change_too_soon');
  perform public.set_handle('BEA');  -- simple changement de casse autorisé
  perform tst.tick('8 days');
  perform public.set_handle('Bea2');
  perform tst.ok(public.profile_me() ->> 'handle' = 'Bea2', 'changement après 7 jours');
end $$;

-- Amis : demande, acceptation, demande croisée, refus, blocage invisible, suppression.
do $$
declare a uuid := tst.new_user(); b uuid := tst.new_user(); c uuid := tst.new_user(); o jsonb;
begin
  perform tst.clock('2026-12-03 10:00:00+01');
  perform tst.login(a); perform public.set_handle('alice_f');
  perform tst.login(b); perform public.set_handle('bruno_f');
  perform tst.login(c); perform public.set_handle('carla_f');

  perform tst.login(a);
  perform tst.ok(jsonb_array_length(public.search_handles('br')) = 0, 'recherche : 3 caractères minimum');
  perform tst.ok(public.search_handles('bru') -> 0 ->> 'handle' = 'bruno_f', 'recherche par préfixe');
  perform tst.ok(public.friend_request('bruno_f') ->> 'status' = 'pending', 'demande envoyée');
  perform tst.throws('select public.friend_request(''nobody_here'')', 'user_not_found');

  perform tst.login(b);
  o := public.friends_overview();
  perform tst.ok(jsonb_array_length(o -> 'incoming') = 1, 'demande reçue');
  perform public.friend_respond((o -> 'incoming' -> 0 ->> 'friendship_id')::uuid, true);
  perform tst.ok(jsonb_array_length(public.friends_overview() -> 'friends') = 1, 'amis');
  perform tst.ok(exists (select 1 from public.user_achievements where user_id = a and achievement_id = 'first_friend'), 'trophée premier ami');

  -- Demande croisée c → a puis a → c : acceptation automatique
  perform tst.login(c); perform public.friend_request('alice_f');
  perform tst.login(a);
  perform tst.ok(public.friend_request('carla_f') ->> 'status' = 'accepted', 'demande croisée acceptée');

  -- Blocage : invisible dans la recherche, demandes impossibles, sans révéler le blocage
  perform tst.login(c); perform public.friend_block(b);
  perform tst.login(b);
  perform tst.ok(jsonb_array_length(public.search_handles('car')) = 0, 'bloqué : invisible');
  perform tst.throws('select public.friend_request(''carla_f'')', 'user_not_found');
  perform public.friend_remove(c);  -- ne lève pas le blocage fait par c
  perform tst.ok(exists (select 1 from public.friendships where status = 'blocked' and blocked_by = c), 'le bloqué ne peut pas lever le blocage');

  perform tst.login(a); perform public.friend_remove(b);
  perform tst.ok(jsonb_array_length(public.friends_overview() -> 'friends') = 1, 'ami supprimé');
end $$;

-- Parrainage : récompenses, auto-parrainage, même appareil, compte anonyme, qualification au premier Daily.
do $$
declare
  inviter uuid := tst.new_user(); invitee uuid := tst.new_user(); anon uuid := tst.new_user(true);
  sneaky uuid := tst.new_user(); late uuid := tst.new_user();
  v_code text; r jsonb; q jsonb; v_run uuid;
begin
  perform tst.clock('2026-12-05 10:00:00+01');
  select referral_code into v_code from public.profiles where id = inviter;
  perform tst.login(inviter); perform public.register_device('device-inviter-000000');

  perform tst.login(inviter);
  perform tst.ok(public.referral_claim(v_code, 'device-inviter-000000') ->> 'reason' = 'self', 'auto-parrainage refusé');

  perform tst.login(anon);
  perform tst.throws(format('select public.referral_claim(%L, ''device-anon-0000000000'')', v_code), 'referral_requires_account');

  perform tst.login(sneaky);
  perform tst.ok(public.referral_claim(v_code, 'device-inviter-000000') ->> 'reason' = 'same_device', 'même appareil refusé');
  perform tst.ok((select seeds from public.profiles where id = sneaky) = 0, 'aucune graine si refusé');

  perform tst.login(invitee);
  r := public.referral_claim(lower(v_code), 'device-invitee-111111');
  perform tst.ok(r ->> 'status' = 'claimed' and (r ->> 'seeds')::int = 100, 'invité : +100 graines');
  perform tst.ok(public._are_friends(inviter, invitee), 'parrain et filleul deviennent amis');
  perform tst.throws(format('select public.referral_claim(%L, ''device-invitee-111111'')', v_code), 'referral_already_claimed');
  perform tst.ok((select coalesce(sum(amount), 0) from public.ledger where user_id = inviter and reason = 'referral_inviter') = 0,
                 'parrain pas encore récompensé');

  r := public.daily_start(); v_run := (r ->> 'run_id')::uuid;
  for i in 1 .. 5 loop
    q := public.daily_question(v_run, i);
    perform tst.tick('3 seconds');
    perform public.daily_answer(v_run, i, tst.wrong_given(), 3000);
  end loop;
  perform tst.ok((select sum(amount) from public.ledger where user_id = inviter and reason = 'referral_inviter') = 150,
                 'parrain récompensé au premier Daily du filleul');

  perform tst.login(late);
  update public.profiles set created_at = public._now() - interval '10 days' where id = late;
  perform tst.ok(public.referral_claim(v_code, 'device-late-22222222') ->> 'reason' = 'account_too_old', 'compte trop ancien');
end $$;

-- Ligues : création, adhésion par code, classement (score puis temps), départ du propriétaire.
do $$
declare a uuid := tst.new_user(); b uuid := tst.new_user(); l jsonb; st jsonb; v_code text; v_league uuid;
begin
  perform tst.clock('2026-12-09 10:00:00+01');  -- mercredi
  perform tst.login(a);
  l := public.league_create('Les Curieux', 'week');
  v_league := (l ->> 'id')::uuid; v_code := l ->> 'invite_code';
  perform tst.ok((l ->> 'start_date')::date = '2026-12-07' and (l ->> 'end_date')::date = '2026-12-13', 'semaine ISO lundi–dimanche');
  perform tst.throws('select public.league_create(''ab'', ''week'')', 'check');

  perform tst.login(b);
  perform tst.throws(format('select public.league_standings(%L, 0)', v_league), 'league_not_found');
  perform public.league_join(lower(v_code));
  -- Scores de la semaine
  insert into public.daily_runs (user_id, daily_date, status, started_at, deadline_at, score, total_ms) values
    (a, '2026-12-07', 'finished', now(), now(), 4, 60000), (a, '2026-12-08', 'finished', now(), now(), 3, 50000),
    (b, '2026-12-07', 'finished', now(), now(), 5, 90000), (b, '2026-12-08', 'finished', now(), now(), 2, 40000),
    (b, '2026-11-30', 'finished', now(), now(), 5, 10000);  -- semaine précédente
  st := public.league_standings(v_league, 0);
  perform tst.ok(jsonb_array_length(st -> 'standings') = 2, '2 membres');
  perform tst.ok((st -> 'standings' -> 0 ->> 'handle') = (select handle from public.profiles where id = a), 'égalité 7 pts : départagé au temps (110 s < 130 s)');
  perform tst.ok((st -> 'standings' -> 0 ->> 'points')::int = 7 and (st -> 'standings' -> 1 ->> 'points')::int = 7, 'points');
  perform tst.ok((public.league_standings(v_league, -1) -> 'standings' -> 0 ->> 'points')::int = 5, 'semaine précédente');

  perform tst.login(a);
  perform public.league_leave(v_league);
  perform tst.ok((select owner_id from public.leagues where id = v_league) = b, 'propriété transférée');
  perform tst.login(b);
  perform public.league_leave(v_league);
  perform tst.ok(not exists (select 1 from public.leagues where id = v_league), 'ligue vide supprimée');
end $$;

-- Suppression de compte : tout disparaît en cascade ; les agrégats des questions restent.
do $$
declare u uuid := tst.new_user(); v_answers int;
begin
  perform tst.clock('2026-12-10 10:00:00+01');
  perform tst.login(u);
  perform public.play_submit((public.play_pack('quick', null, null, 3) ->> 'session_id')::uuid, '[]'::jsonb);
  perform public._record_attempt(u, (select id from public.questions where external_key = 'calc-001'), '{"value":102}', 3000, 'training', null, gen_random_uuid());
  select answer_count into v_answers from public.questions where external_key = 'calc-001';
  perform public.delete_account();
  perform tst.ok(not exists (select 1 from auth.users where id = u), 'utilisateur supprimé');
  perform tst.ok(not exists (select 1 from public.profiles where id = u), 'profil supprimé');
  perform tst.ok(not exists (select 1 from public.question_attempts where user_id = u), 'tentatives supprimées');
  perform tst.ok(not exists (select 1 from public.ledger where user_id = u), 'ledger supprimé');
  perform tst.ok((select answer_count from public.questions where external_key = 'calc-001') = v_answers, 'calibration conservée');
  perform tst.ok(public.profile_me() is null, 'plus de profil');
end $$;
