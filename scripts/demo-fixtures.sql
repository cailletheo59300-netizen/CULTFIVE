-- Jeu de données de démonstration réaliste (vraies réponses RPC) pour le mode démo / captures d'écran.
-- Simule 3 semaines de jeu d'un joueur et de ses amis. Usage : scripts/gen-demo-fixtures.sh
\set ON_ERROR_STOP 1
select setseed(0.4242) \g /dev/null

create or replace function tst.demo_daily(p_user uuid, p_accuracy double precision) returns void language plpgsql as $$
declare r jsonb; q jsonb;
begin
  perform tst.login(p_user);
  r := public.daily_start();
  for i in 1 .. 5 loop
    q := public.daily_question((r ->> 'run_id')::uuid, i);
    perform tst.tick(make_interval(secs => 5 + floor(random() * 14)));
    perform public.daily_answer((r ->> 'run_id')::uuid, i,
      case when random() < p_accuracy then tst.correct_given((q ->> 'id')::uuid) else tst.wrong_given() end, null);
  end loop;
end $$;

create or replace function tst.demo_play(p_user uuid, p_mode text, p_domain text, p_accuracy double precision) returns void language plpgsql as $$
declare p jsonb;
begin
  perform tst.login(p_user);
  p := public.play_pack(p_mode, p_domain, null, 8);
  perform public.play_submit((p ->> 'session_id')::uuid, (
    select coalesce(jsonb_agg(jsonb_build_object('client_attempt_id', gen_random_uuid(), 'question_id', x ->> 'id',
             'given', case when random() < p_accuracy then tst.correct_given((x ->> 'id')::uuid) else tst.wrong_given() end,
             'response_ms', 3000 + floor(random() * 6000))), '[]'::jsonb)
    from jsonb_array_elements(p -> 'questions') x));
end $$;

select tst.clock('2026-09-04 20:00:00+02') \g /dev/null
select tst.new_user() as me \gset
select tst.new_user() as f1 \gset
select tst.new_user() as f2 \gset
select tst.new_user() as f3 \gset
select tst.new_user() as f4 \gset
select tst.new_user() as f5 \gset
select tst.login(:'f1') \g /dev/null
select public.set_handle('Margaux') \g /dev/null
select tst.login(:'f2') \g /dev/null
select public.set_handle('Yanis_59') \g /dev/null
select tst.login(:'f3') \g /dev/null
select public.set_handle('leo_b') \g /dev/null
select tst.login(:'f4') \g /dev/null
select public.set_handle('Camille') \g /dev/null
select tst.login(:'f5') \g /dev/null
select public.set_handle('Nours') \g /dev/null
select tst.login(:'me') \g /dev/null
select public.set_handle('Theo') \g /dev/null
select public.complete_onboarding('balanced', array['history','geography','science']) \g /dev/null
select public.friend_request(h) from unnest(array['Margaux','Yanis_59','leo_b','Camille']) h \g /dev/null
select tst.login(u), public.friend_respond((select id from public.friendships where addressee_id = u), true)
  from unnest(array[:'f1', :'f2', :'f3', :'f4']::uuid[]) u \g /dev/null
select tst.login(:'f5') \g /dev/null
select public.friend_request('Theo') \g /dev/null
select tst.login(:'me') \g /dev/null
select public.league_create('Les Curieux du jeudi', 'week') as league \gset
select tst.login(u), public.league_join(:'league'::jsonb ->> 'invite_code') from unnest(array[:'f1', :'f2', :'f3']::uuid[]) u \g /dev/null

-- 21 jours de jeu (dont un jour manqué, sauvé par rien : la série repart)
do $$
declare
  me uuid := (select id from public.profiles where handle = 'Theo');
  friends uuid[] := array(select id from public.profiles where handle in ('Margaux','Yanis_59','leo_b','Camille') order by handle);
  domains text[] := array['history','geography','science','french','calc','arts','sport','logic'];
begin
  for d in 0 .. 20 loop
    perform tst.clock(('2026-09-05 08:30:00+02'::timestamptz + make_interval(days => d)));
    perform tst.demo_daily(me, 0.55 + d * 0.012);
    for i in 1 .. 4 loop
      if random() < 0.85 then perform tst.demo_daily(friends[i], 0.5 + random() * 0.35); end if;
    end loop;
    perform tst.clock(('2026-09-05 19:00:00+02'::timestamptz + make_interval(days => d)));
    perform tst.demo_play(me, 'training', domains[1 + (d % 8)], 0.6 + d * 0.01);
    if d % 3 = 0 then perform tst.demo_play(me, 'quick', null, 0.65); end if;
  end loop;
end $$;

-- Aujourd'hui, 9 h : le 5 du jour m'attend ; certains amis ont déjà joué.
select tst.clock('2026-09-26 07:40:00+02') \g /dev/null
select tst.demo_daily(u, 0.7) from unnest(array[:'f1', :'f3']::uuid[]) u \g /dev/null
select tst.clock('2026-09-26 09:05:00+02') \g /dev/null
select tst.login(:'me') \g /dev/null
select public.daily_status();
\echo @@@
select public.daily_start() as s \gset
select :'s';
\echo @@@
select public.daily_question((:'s'::jsonb->>'run_id')::uuid, 1);
\echo @@@
select public.daily_result('2026-09-25');
\echo @@@
select public.daily_review('2026-09-25');
\echo @@@
select public.play_pack('training', 'geography', null, 8);
\echo @@@
select public.profile_me();
\echo @@@
select public.skills_overview();
\echo @@@
select public.domain_stats('geography');
\echo @@@
select public.errors_overview();
\echo @@@
select public.friends_overview();
\echo @@@
select public.league_standings((:'league'::jsonb->>'id')::uuid, 0);
\echo @@@
select public.leagues_mine();
\echo @@@
select public.achievements_mine();
\echo @@@
select public.daily_history(35);
\echo @@@
select public.referral_overview();
\echo @@@
select jsonb_agg(jsonb_build_object('id', id, 'name', name, 'daily_slot', daily_slot, 'sort', sort) order by sort) from public.domains;
\echo @@@
select jsonb_agg(jsonb_build_object('id', id, 'domain_id', domain_id, 'name', name, 'sort', sort) order by domain_id, sort) from public.subdomains;
