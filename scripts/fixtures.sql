\set ON_ERROR_STOP 1
select set_config('app.now_override', '2027-03-01 09:00:00+01', false) \g /dev/null
select tst.new_user() as a \gset
select tst.new_user() as b \gset
select tst.login(:'b') \g /dev/null
select public.set_handle('bruno_fx') \g /dev/null
select tst.login(:'a') \g /dev/null
select public.set_handle('alice_fx') \g /dev/null
select public.friend_request('bruno_fx') \g /dev/null
select tst.login(:'b') \g /dev/null
select public.friend_respond((select id from public.friendships where addressee_id = :'b'), true) \g /dev/null
select tst.login(:'a') \g /dev/null
select public.daily_status();
\echo @@@
select public.daily_start() as s \gset
select :'s';
\echo @@@
select public.daily_question((:'s'::jsonb->>'run_id')::uuid, 1) as q \gset
select :'q';
\echo @@@
select tst.tick('4 seconds') \g /dev/null
select public.daily_answer((:'s'::jsonb->>'run_id')::uuid, 1, tst.correct_given((:'q'::jsonb->>'id')::uuid), 3800);
\echo @@@
select public.daily_question((:'s'::jsonb->>'run_id')::uuid, 2) \g /dev/null
select tst.tick('6 seconds') \g /dev/null
select public.daily_answer((:'s'::jsonb->>'run_id')::uuid, 2, tst.wrong_given(), 5100) \g /dev/null
select public.daily_question((:'s'::jsonb->>'run_id')::uuid, 3) as q \gset
select tst.tick('7 seconds') \g /dev/null
select public.daily_answer((:'s'::jsonb->>'run_id')::uuid, 3, tst.correct_given((:'q'::jsonb->>'id')::uuid), 6400) \g /dev/null
select public.daily_question((:'s'::jsonb->>'run_id')::uuid, 4) \g /dev/null
select tst.tick('9 seconds') \g /dev/null
select public.daily_answer((:'s'::jsonb->>'run_id')::uuid, 4, '{"order": ["a","b"]}', 8200) \g /dev/null
select public.daily_question((:'s'::jsonb->>'run_id')::uuid, 5) as q \gset
select tst.tick('5 seconds') \g /dev/null
select public.daily_answer((:'s'::jsonb->>'run_id')::uuid, 5, tst.correct_given((:'q'::jsonb->>'id')::uuid), 4300) \g /dev/null
select public.daily_result();
\echo @@@
select public.daily_review();
\echo @@@
select public.play_pack('quick', null, null, 6) as p \gset
select :'p';
\echo @@@
select public.play_submit((:'p'::jsonb->>'session_id')::uuid, (select jsonb_agg(jsonb_build_object('client_attempt_id', gen_random_uuid(), 'question_id', x->>'id', 'given', tst.correct_given((x->>'id')::uuid), 'response_ms', 2000)) from jsonb_array_elements(:'p'::jsonb->'questions') x));
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
select public.league_create('Les Curieux', 'week');
\echo @@@
select public.leagues_mine();
\echo @@@
select public.achievements_mine();
\echo @@@
select public.daily_history(35);
\echo @@@
select jsonb_agg(jsonb_build_object('id', id, 'name', name, 'daily_slot', daily_slot, 'sort', sort) order by sort) from public.domains;
\echo @@@
select public.quests_overview();
\echo @@@
select public.weekly_recap(4);
