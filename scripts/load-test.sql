-- Test de charge local (jamais en prod) : 1 000 joueurs simulés, mesure des fonctions les plus appelées.
-- Usage : après scripts/test-db.sh (base cultfive_test), psql -d cultfive_test -f scripts/load-test.sql
\set QUIET on
create temp table timings (step text, n int, total_ms numeric);

create or replace function pg_temp.measure(p_step text, p_n int, p_started timestamptz) returns void language sql as $$
  insert into timings values (p_step, p_n, round(extract(epoch from clock_timestamp() - p_started) * 1000, 1))
$$;

do $$
declare
  users uuid[] := '{}';
  u uuid; t timestamptz; pack jsonb; atts jsonb; x jsonb; l jsonb; v_league uuid; q jsonb;
begin
  perform tst.clock('2027-09-15 12:00:00+02');
  for i in 1 .. 1000 loop users := users || tst.new_user(); end loop;
  update public.profiles set onboarded_at = public._now() where id = any (users);

  -- 300 parties classées de 10 questions (tirage + envoi).
  t := clock_timestamp();
  for i in 1 .. 300 loop
    perform tst.login(users[i]);
    pack := public.play_pack('training', (array['history','science','geography','arts','cinema'])[1 + i % 5], null, 10, true, null);
    atts := '[]'::jsonb;
    for x in select * from jsonb_array_elements(pack -> 'questions') loop
      atts := atts || jsonb_build_object('client_attempt_id', gen_random_uuid(), 'question_id', x ->> 'id',
                                         'given', case when random() < 0.6 then tst.correct_given((x ->> 'id')::uuid) else tst.wrong_given() end,
                                         'response_ms', 4000);
    end loop;
    perform public.play_submit((pack ->> 'session_id')::uuid, atts);
  end loop;
  perform pg_temp.measure('partie classée (tirage + envoi de 10 réponses)', 300, t);

  -- Une ligue de 50 membres : 50 quiz du jour, puis classements.
  perform tst.login(users[1]);
  l := public.league_create('Charge', 10, null, 'auto', '1m', true, 50);
  v_league := (l ->> 'id')::uuid;
  insert into public.league_members (league_id, user_id) select v_league, unnest(users[2:50]);
  t := clock_timestamp();
  for i in 1 .. 50 loop
    perform tst.login(users[i]);
    for p in 1 .. 10 loop
      q := public.league_question(v_league, p);
      perform public.league_answer(v_league, p, tst.correct_given((q ->> 'id')::uuid), 3000);
    end loop;
  end loop;
  perform pg_temp.measure('quiz de ligue (10 questions, par joueur)', 50, t);
  t := clock_timestamp();
  for i in 1 .. 50 loop perform tst.login(users[i]); perform public.league_standings(v_league, 0); end loop;
  perform pg_temp.measure('classement de ligue (50 membres)', 50, t);
  t := clock_timestamp();
  for i in 1 .. 50 loop perform tst.login(users[i]); perform public.leagues_mine(); end loop;
  perform pg_temp.measure('mes ligues', 50, t);

  -- 100 amis pour un joueur, écran Amis et profil d'ami.
  for i in 2 .. 101 loop perform public._befriend(users[1], users[i]); end loop;
  perform tst.login(users[1]);
  t := clock_timestamp();
  for i in 1 .. 20 loop perform public.friends_overview(); end loop;
  perform pg_temp.measure('écran Amis (100 amis)', 20, t);
  t := clock_timestamp();
  for i in 2 .. 21 loop perform public.friend_profile(users[i]); end loop;
  perform pg_temp.measure('profil d''un ami', 20, t);

  -- Profil et statut des pubs, écran le plus ouvert.
  t := clock_timestamp();
  for i in 1 .. 200 loop perform tst.login(users[i]); perform public.profile_me(); perform public.ad_status(); end loop;
  perform pg_temp.measure('profil + statut des pubs', 200, t);

  -- Admin : statistiques sur 1 000 joueurs.
  insert into public.app_admins (user_id) values (users[1]) on conflict do nothing;
  perform tst.login(users[1]);
  t := clock_timestamp();
  perform public.admin_kpis(30);
  perform pg_temp.measure('admin : statistiques (30 jours)', 1, t);
end $$;

\set QUIET off
select step as "étape", n as "appels", total_ms as "total (ms)", round(total_ms / n, 1) as "ms par appel" from timings;
