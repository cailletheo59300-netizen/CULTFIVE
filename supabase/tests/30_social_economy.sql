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
  perform tst.ok(r ->> 'status' = 'claimed' and (r ->> 'seeds')::int = 30, 'invité : +30 graines');
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
  perform tst.ok((select sum(amount) from public.ledger where user_id = inviter and reason = 'referral_inviter') = 50,
                 'parrain récompensé au premier Daily du filleul');

  perform tst.login(late);
  update public.profiles set created_at = public._now() - interval '10 days' where id = late;
  perform tst.ok(public.referral_claim(v_code, 'device-late-22222222') ->> 'reason' = 'account_too_old', 'compte trop ancien');
end $$;

-- Ligues : création, aperçu et adhésion par code, quiz du jour de la ligue, classement (points puis temps), saisons,
-- départ du propriétaire.
create or replace function tst.league_play(p_league uuid, p_user uuid, p_correct int, p_ms int) returns void language plpgsql as $$
declare q jsonb; n int;
begin
  perform tst.login(p_user);
  n := (select question_count from public.leagues where id = p_league);
  for i in 1 .. n loop
    q := public.league_question(p_league, i);
    perform tst.tick((p_ms || ' milliseconds')::interval);
    perform public.league_answer(p_league, i, case when i <= p_correct then tst.correct_given((q ->> 'id')::uuid)
                                                   else tst.wrong_given() end, p_ms);
  end loop;
end $$;

do $$
declare a uuid := tst.new_user(); b uuid := tst.new_user(); l jsonb; st jsonb; pv jsonb; v_code text; v_league uuid; r jsonb;
begin
  perform tst.clock('2026-12-09 10:00:00+01');  -- mercredi
  perform tst.login(a);
  l := public.league_create('Les Curieux', 'week');  -- ancienne signature : 7 jours dès aujourd'hui
  v_league := (l ->> 'id')::uuid; v_code := l ->> 'invite_code';
  perform tst.ok((l ->> 'start_date')::date = '2026-12-09' and (l ->> 'end_date')::date = '2026-12-15', '7 jours à partir d''aujourd''hui');
  perform tst.ok(l ->> 'status' = 'active' and (l ->> 'day_index')::int = 1 and (l ->> 'days_left')::int = 6, 'jour 1 sur 7, 6 jours restants');
  perform tst.ok(length(v_code) = 8, 'code de 8 caractères');
  perform tst.throws('select public.league_create(''ab'', ''week'')', 'invalid_name');

  perform tst.login(b);
  perform tst.throws(format('select public.league_standings(%L, 0)', v_league), 'league_not_found');
  perform tst.throws(format('select public.league_question(%L, 1)', v_league), 'league_not_found');
  pv := public.league_preview(lower(v_code));
  perform tst.ok((pv ->> 'found')::bool and pv ->> 'name' = 'Les Curieux' and (pv ->> 'members')::int = 1
                 and not (pv ->> 'is_member')::bool, 'aperçu avant de rejoindre');
  perform tst.ok(not (public.league_preview('ZZZZZZZZ') ->> 'found')::bool, 'code inconnu : pas d''erreur, found = false');
  perform public.league_join(lower(v_code));

  -- Jour 1 : a 4/5 en 2 s, b 3/5 en 3 s. Jour 2 : a 3/5, b 4/5. Égalité 7 points : a plus rapide.
  perform tst.league_play(v_league, a, 4, 2000);
  perform tst.throws(format('select public.league_question(%L, 1)', v_league), 'league_out_of_order');
  perform tst.league_play(v_league, b, 3, 3000);
  r := public.league_day_result(v_league);
  perform tst.ok(jsonb_array_length(r -> 'members') = 2 and (r -> 'members' -> 0 ->> 'score')::int = 4, 'résultat du jour des membres');
  perform tst.tick('1 day');
  perform tst.league_play(v_league, a, 3, 2000);
  perform tst.league_play(v_league, b, 4, 3000);
  st := public.league_standings(v_league, 0);
  perform tst.ok(jsonb_array_length(st -> 'standings') = 2, '2 membres');
  perform tst.ok((st -> 'standings' -> 0 ->> 'handle') = (select handle from public.profiles where id = a), 'égalité 7 pts : départagé au temps');
  perform tst.ok((st -> 'standings' -> 0 ->> 'points')::int = 7 and (st -> 'standings' -> 1 ->> 'points')::int = 7
                 and (st -> 'standings' -> 0 ->> 'days')::int = 2, 'points et jours joués');
  perform tst.ok(st -> 'my_today' ->> 'state' = 'done', 'quiz du jour fait');
  -- Les questions changent chaque jour et ne sont jamais le 5 du jour.
  perform tst.ok((select count(*) from public.league_days where league_id = v_league) = 2
                 and not exists (select 1 from public.league_days d1 join public.league_days d2 on d1.league_id = d2.league_id
                                 and d1.day < d2.day and d1.question_ids && d2.question_ids where d1.league_id = v_league),
                 'un quiz différent chaque jour');
  -- Le quiz de ligue ne change pas l'Elo.
  perform tst.ok(not exists (select 1 from public.question_attempts where user_id = a and dom_mu_after is not null
                             and session_id = v_league), 'hors Elo');

  -- Nouvelle saison : seulement une fois la ligue finie, par le créateur.
  perform tst.login(a);
  perform tst.throws(format('select public.league_new_season(%L)', v_league), 'league_not_finished');
  perform tst.tick('6 days');   -- 16 décembre : terminée
  perform tst.ok(public.league_standings(v_league, 0) ->> 'status' = 'finished', 'ligue terminée');
  perform tst.login(b);
  perform tst.throws(format('select public.league_new_season(%L)', v_league), 'forbidden');
  perform tst.login(a);
  st := public.league_new_season(v_league, false);
  perform tst.ok((st ->> 'season')::int = 2 and st ->> 'status' = 'upcoming' and (st ->> 'starts_in')::int = 1, 'saison 2 demain');
  perform tst.ok((public.league_standings(v_league, -1) -> 'standings' -> 0 ->> 'points')::int = 7, 'saison précédente');

  -- Le créateur : nouveau code, retrait d'un membre.
  perform tst.ok(public.league_regenerate_code(v_league) ->> 'invite_code' <> v_code, 'nouveau code');
  perform tst.login(b);
  perform tst.throws(format('select public.league_join(%L)', v_code), 'league_not_found');
  perform tst.throws(format('select public.league_kick(%L, %L)', v_league, a), 'forbidden');

  perform tst.login(a);
  perform public.league_leave(v_league);
  perform tst.ok((select owner_id from public.leagues where id = v_league) = b, 'propriété transférée');
  perform tst.login(b);
  perform public.league_leave(v_league);
  perform tst.ok(not exists (select 1 from public.leagues where id = v_league), 'ligue vide supprimée');
end $$;

-- Dates des ligues : mois de 28 à 31 jours, années bissextiles, changement d'année, fuseau du créateur.
do $$
declare u uuid := tst.new_user(); l jsonb;
begin
  perform tst.ok(public._league_last_day('2026-09-30', '1m') = '2026-10-29', '30 sept. + 1 mois → dernier jour 29 oct.');
  perform tst.ok(public._league_last_day('2027-01-31', '1m') = '2027-02-27', '31 janv. → 27 févr. (février de 28 jours)');
  perform tst.ok(public._league_last_day('2028-01-31', '1m') = '2028-02-28', '31 janv. 2028 → 28 févr. (année bissextile)');
  perform tst.ok(public._league_last_day('2026-12-20', '2w') = '2027-01-02', 'changement d''année');
  perform tst.ok(public._league_last_day('2028-02-29', '1w') = '2028-03-06', '29 févr. + 7 jours');
  -- Fuseau : à 3 h UTC le 9 décembre, il est encore le 8 à New York.
  update public.profiles set timezone = 'America/New_York' where id = u;
  perform tst.clock('2026-12-09 03:00:00+00');
  perform tst.login(u);
  l := public.league_create('Les Lève-tard', 5, null, 'auto', '1m', true, 20);
  perform tst.ok((l ->> 'start_date')::date = '2026-12-08' and (l ->> 'end_date')::date = '2027-01-07', 'jours comptés dans le fuseau de la ligue');
  perform tst.ok((l ->> 'ends_at')::timestamptz = '2027-01-08 05:00:00+00', 'fin à minuit, heure de New York');
  perform tst.ok((l -> 'settings' ->> 'max_members')::int = 20, 'membres max');
  perform tst.throws('select public.league_create(''Trop'', 7, null, ''auto'', ''1w'', true, 50)', 'invalid_count');
  perform tst.throws('select public.league_create(''Trop'', 5, null, ''auto'', ''3d'', true, 50)', 'invalid_duration');
end $$;

-- Invitations : essais de codes limités ; ligue pleine.
do $$
declare a uuid := tst.new_user(); b uuid := tst.new_user(); c uuid := tst.new_user(); l jsonb;
begin
  perform tst.clock('2026-12-20 10:00:00+01');
  perform tst.login(a);
  l := public.league_create('Petite', 5, null, 'auto', '1w', true, 2);
  perform tst.login(b);
  perform public.league_join(l ->> 'invite_code');
  perform tst.login(c);
  perform tst.throws(format('select public.league_join(%L)', l ->> 'invite_code'), 'league_full');
  for i in 1 .. 30 loop perform public.league_preview('XXXX' || i); end loop;
  perform tst.ok(public.league_preview(l ->> 'invite_code') ->> 'error' = 'rate_limited', 'aperçus limités à 30 par heure');
  perform tst.throws(format('select public.league_join(%L)', l ->> 'invite_code'), 'rate_limited');
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
