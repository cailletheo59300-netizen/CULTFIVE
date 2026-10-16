-- Ligues ouvertes (0058) : quiz identiques pour tous, sans chrono, une fois chacun ; classement général ; ajout de quiz ;
-- fin par le créateur ; podium et trophée.
create or replace function tst.open_play(p_league uuid, p_quiz int, p_correct int) returns void language plpgsql as $$
declare q jsonb; n int;
begin
  n := (select question_count from public.leagues where id = p_league);
  for i in 1 .. n loop
    q := public.league_quiz_question(p_league, p_quiz, i);
    perform public.league_quiz_answer(p_league, p_quiz, i,
      case when i <= p_correct then tst.correct_given((q ->> 'id')::uuid) else tst.wrong_given() end);
  end loop;
end $$;

do $$
declare
  a uuid := tst.new_user(); b uuid := tst.new_user(); c uuid := tst.new_user(); d uuid := tst.new_user();
  st jsonb; r jsonb; v_league uuid; v_code text; q1 jsonb; q2 jsonb; v_seeds int;
begin
  perform tst.clock('2027-04-20 10:00:00+02');
  perform tst.login(a);
  perform tst.throws('select public.league_create_open(''Ouverte'', 5, null, ''auto'', 0, null, 50)', 'invalid_quizzes');
  perform tst.throws('select public.league_create_open(''Ouverte'', 5, null, ''auto'', 11, null, 50)', 'invalid_quizzes');
  st := public.league_create_open('Les Libres', 5, null, 'auto', 3, null, 50);
  v_league := (st ->> 'id')::uuid; v_code := st ->> 'invite_code';
  perform tst.ok(st ->> 'format' = 'open' and (st ->> 'open_ended')::bool and st ->> 'status' = 'active', 'ligue ouverte, sans fin');
  perform tst.ok(jsonb_array_length(st -> 'quizzes') = 3 and st -> 'quizzes' -> 0 ->> 'state' = 'todo', '3 quiz à jouer');
  perform tst.ok(st -> 'settings' ->> 'duration' = 'open' and st ->> 'days_left' is null, 'pas de compte à rebours');

  -- Rejoindre : l'aperçu dit le format.
  perform tst.login(b);
  perform tst.ok((public.league_preview(v_code) ->> 'format') = 'open' and (public.league_preview(v_code) ->> 'quizzes')::int = 3,
                 'aperçu : ligue ouverte, 3 quiz');
  perform public.league_join(v_code);
  perform tst.login(c); perform public.league_join(v_code);
  perform tst.login(d); perform public.league_join(v_code);

  -- Mêmes questions pour tous ; le quiz du jour est refusé.
  perform tst.login(a);
  q1 := public.league_quiz_question(v_league, 1, 1);
  perform tst.login(b);
  q2 := public.league_quiz_question(v_league, 1, 1);
  perform tst.ok(q1 ->> 'id' = q2 ->> 'id', 'même question pour tous');
  perform tst.throws(format('select public.league_question(%L, 1)', v_league), 'league_open');
  perform tst.throws(format('select public.league_quiz_question(%L, 1, 3)', v_league), 'league_out_of_order');
  perform tst.throws(format('select public.league_quiz_question(%L, 9, 1)', v_league), 'quiz_not_found');

  -- Les scores des autres seulement après avoir fini le quiz.
  perform tst.login(a);
  perform tst.open_play(v_league, 1, 4);
  perform tst.login(b);
  r := public.league_quiz_result(v_league, 1);
  perform tst.ok(r -> 'members' = 'null'::jsonb, 'scores cachés avant de finir');
  perform tst.open_play(v_league, 1, 5);
  r := public.league_quiz_result(v_league, 1);
  perform tst.ok(jsonb_array_length(r -> 'members') = 4 and (r -> 'me' ->> 'score')::int = 5, 'scores visibles après');

  -- Une fois chacun : rejouer est refusé.
  perform tst.throws(format('select public.league_quiz_question(%L, 1, 1)', v_league), 'league_out_of_order');

  -- Quand on veut : b joue le quiz 2 trois jours plus tard ; c en joue deux.
  perform tst.clock('2027-04-23 21:00:00+02');
  perform tst.open_play(v_league, 2, 3);
  perform tst.login(c);
  perform tst.open_play(v_league, 1, 5);
  perform tst.open_play(v_league, 3, 1);
  st := public.league_standings(v_league, 0);
  -- b : 8 · c : 6 · a : 4 · d : 0
  perform tst.ok(st -> 'standings' -> 0 ->> 'id' = b::text and (st -> 'standings' -> 0 ->> 'points')::int = 8, '1er : b, 8 points');
  perform tst.ok(st -> 'standings' -> 1 ->> 'id' = c::text and st -> 'standings' -> 2 ->> 'id' = a::text, 'puis c, puis a');
  perform tst.ok(st -> 'quizzes' -> 0 ->> 'state' = 'done' and st -> 'quizzes' -> 1 ->> 'state' = 'todo', 'mes quiz');
  perform tst.ok((select e ->> 'today_state' from jsonb_array_elements(public.leagues_mine()) e
                  where e ->> 'id' = v_league::text) = 'todo', 'mes ligues : il reste un quiz');

  -- Égalité : le premier à avoir fini passe devant (a et d à 4, a avant).
  perform tst.login(d);
  perform tst.clock('2027-04-24 10:00:00+02');
  perform tst.open_play(v_league, 1, 4);
  perform tst.open_play(v_league, 2, 0);
  st := public.league_standings(v_league, 0);
  perform tst.ok((select (e ->> 'rank')::int from jsonb_array_elements(st -> 'standings') e where e ->> 'id' = a::text)
                 < (select (e ->> 'rank')::int from jsonb_array_elements(st -> 'standings') e where e ->> 'id' = d::text),
                 'égalité : le premier fini devant');

  -- Seul le créateur ajoute un quiz et termine la ligue.
  perform tst.throws(format('select public.league_add_quiz(%L)', v_league), 'forbidden');
  perform tst.throws(format('select public.league_end(%L)', v_league), 'forbidden');
  perform tst.login(a);
  st := public.league_add_quiz(v_league);
  perform tst.ok(jsonb_array_length(st -> 'quizzes') = 4, 'quiz ajouté');
  perform tst.ok(not exists (
    select 1 from public.league_days x join public.league_days y on y.league_id = x.league_id and y.day < x.day
    where x.league_id = v_league and x.question_ids && y.question_ids), 'jamais deux fois la même question');

  -- Fin : podium, trophée, plus de neurones ni de coffre.
  perform tst.login(b);
  v_seeds := (select seeds from public.profiles where id = b);
  perform tst.login(a);
  st := public.league_end(v_league);
  perform tst.ok(st ->> 'status' = 'finished', 'ligue terminée');
  perform tst.ok(jsonb_array_length(st -> 'results') = 3 and st -> 'results' -> 0 ->> 'id' = b::text, 'podium : b 1er');
  perform tst.ok(exists (select 1 from public.user_achievements where user_id = b and achievement_id = 'league_winner'),
                 'trophée Vainqueur de ligue');
  perform tst.ok((select seeds from public.profiles where id = b) = v_seeds
                 and not exists (select 1 from public.user_chests where user_id = b and source = 'league'), 'pas de neurones');
  perform tst.throws(format('select public.league_quiz_question(%L, 4, 1)', v_league), 'league_not_active');
  perform tst.throws(format('select public.league_add_quiz(%L)', v_league), 'league_not_active');
  perform tst.throws(format('select public.league_new_season(%L, true)', v_league), 'league_open');

  -- Durée choisie : fin automatique.
  st := public.league_create_open('Une semaine', 5, array['history'], 'easy', 1, 7, 10);
  perform tst.ok(not (st ->> 'open_ended')::bool and (st ->> 'days_left')::int = 6, 'durée : 7 jours');

  -- Droits.
  perform tst.ok(has_function_privilege('authenticated', 'public.league_create_open(text,int,text[],text,int,int,int)', 'execute')
                 and not has_function_privilege('anon', 'public.league_quiz_answer(uuid,int,int,jsonb)', 'execute')
                 and not has_function_privilege('authenticated', 'public._league_open_rows(uuid)', 'execute'), 'droits');
end $$;
