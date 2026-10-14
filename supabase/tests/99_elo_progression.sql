-- Elo de progression (0054) : séparé du niveau, placement plafonné, gains et pertes par partie, asymétrie en haut,
-- mélange plus dur au-dessus de 1 200, recalcul de nuit des difficultés.

-- Une partie classée de 10 questions en histoire, toutes justes ou toutes fausses.
create or replace function tst.ranked_game(p_domain text, p_correct bool) returns jsonb language plpgsql as $$
declare pack jsonb; atts jsonb := '[]'::jsonb; x jsonb;
begin
  pack := public.play_pack('training', p_domain, null, 10, true, null);
  for x in select * from jsonb_array_elements(pack -> 'questions') loop
    atts := atts || jsonb_build_object('client_attempt_id', gen_random_uuid(), 'question_id', x ->> 'id',
                                       'given', case when p_correct then tst.correct_given((x ->> 'id')::uuid) else tst.wrong_given() end,
                                       'response_ms', 4000);
  end loop;
  return public.play_submit((pack ->> 'session_id')::uuid, atts);
end $$;

-- Placement : 800 au plus après 20 réponses parfaites ; le niveau caché, lui, monte vite.
do $$
declare u uuid := tst.new_user(); r jsonb; v_elo real; v_mu real;
begin
  perform tst.clock('2028-01-10 10:00:00+01');
  perform tst.login(u);
  r := tst.ranked_game('history', true);
  perform tst.ok((r -> 'ratings' -> 0 ->> 'cote_before')::int = 500 and (r -> 'ratings' -> 0 ->> 'cote_after')::int between 610 and 650,
                 'placement : 500 → 650 au plus (' || (r -> 'ratings' -> 0 ->> 'cote_after') || ')');
  r := tst.ranked_game('history', true);
  select elo, mu into v_elo, v_mu from public.user_skills where user_id = u and scope_id = 'history';
  perform tst.ok(round(v_elo) between 720 and 800 and (r -> 'ratings' -> 0 ->> 'placed')::bool, 'placement terminé : 800 au plus (' || round(v_elo) || ')');
  perform tst.ok(public._cote(v_mu) > 1100, 'niveau caché déjà haut (' || public._cote(v_mu) || ')');
  -- Après le placement : +30 au plus par partie.
  r := tst.ranked_game('history', true);
  perform tst.ok((r -> 'ratings' -> 0 ->> 'cote_after')::int - (r -> 'ratings' -> 0 ->> 'cote_before')::int between 1 and 30,
                 'après placement : +30 au plus (' || ((r -> 'ratings' -> 0 ->> 'cote_after')::int - (r -> 'ratings' -> 0 ->> 'cote_before')::int) || ')');
  perform tst.ok((public.skills_overview() -> 0) ? 'cote', 'Elo affiché');
  perform tst.ok((select (s ->> 'cote')::int from jsonb_array_elements(public.skills_overview()) s where s ->> 'domain_id' = 'history')
                 = (r -> 'ratings' -> 0 ->> 'cote_after')::int, 'skills_overview renvoie l''Elo');
end $$;

-- Pertes : −40 au plus par partie, −80 si la partie commence à 1 200 ou plus.
do $$
declare u uuid := tst.new_user(); r jsonb;
begin
  perform tst.clock('2028-01-11 10:00:00+01');
  insert into public.user_skills (user_id, scope_id, mu, var, n, correct, elo) values
    (u, 'history', 45, 16, 100, 70, 1100), (u, 'geography', 50, 16, 100, 70, 1300);
  perform tst.login(u);
  r := tst.ranked_game('history', false);
  perform tst.ok((r -> 'ratings' -> 0 ->> 'cote_after')::int = 1060, 'partie ratée à 1 100 : −40 (' || (r -> 'ratings' -> 0 ->> 'cote_after') || ')');
  r := tst.ranked_game('geography', false);
  perform tst.ok((r -> 'ratings' -> 0 ->> 'cote_after')::int = 1220, 'partie ratée à 1 300 : −80 (' || (r -> 'ratings' -> 0 ->> 'cote_after') || ')');
  -- Le niveau caché n'est pas plafonné de la même façon : il reste la mesure du vrai niveau.
  perform tst.ok((select mu from public.user_skills where user_id = u and scope_id = 'geography') < 50, 'niveau caché en baisse');
end $$;

-- 5 du jour : la variation renvoyée est celle de l'Elo (unité « niveau » : 500 ↔ 21,2).
do $$
declare u uuid := tst.new_user(); r jsonb; q jsonb; a jsonb;
begin
  perform tst.clock('2028-01-12 10:00:00+01');
  perform tst.login(u);
  r := public.daily_start();
  q := public.daily_question((r ->> 'run_id')::uuid, 1);
  a := public.daily_answer((r ->> 'run_id')::uuid, 1, tst.correct_given((q ->> 'id')::uuid), 4000);
  perform tst.ok(abs((a ->> 'domain_before')::real - public._elo_as_level(500)) < 0.01, '5 du jour : Elo avant = 500');
  perform tst.ok((a ->> 'domain_after')::real > (a ->> 'domain_before')::real
                 and public._cote((a ->> 'domain_after')::real) <= 515, '5 du jour : +15 au plus en placement');
end $$;

-- Asymétrie au-dessus de 1 000.
do $$
begin
  perform tst.ok(public._elo_mult(900, true) = 1 and public._elo_mult(900, false) = 1, 'sous 1 000 : symétrique');
  perform tst.ok(public._elo_mult(1200, true) = 0.75 and public._elo_mult(1200, false) = 1.25, '1 200 : ×0,75 / ×1,25');
  perform tst.ok(public._elo_mult(1500, true) = 0.5 and public._elo_mult(1500, false) = 1.5, 'dès 1 400 : ×0,5 / ×1,5');
end $$;

-- Mélange de la partie classée : 30 % de questions qui piquent au-dessus de 1 200 (niveau), 20 % en dessous.
do $$
declare v_hard_hi int := 0; v_hard_lo int := 0; v_easy_hi int := 0; b record;
begin
  perform setseed(0.11);
  for i in 1 .. 3000 loop
    select * into b from public._band_bounds('training', 70);   -- niveau ≈ 1 347
    v_hard_hi := v_hard_hi + (b.hi = public._p_of_gap(-60))::int;
    v_easy_hi := v_easy_hi + (b.lo = public._p_of_gap(-200))::int;
    select * into b from public._band_bounds('training', 55);   -- niveau ≈ 1 087
    v_hard_lo := v_hard_lo + (b.hi = public._p_of_gap(-60))::int;
  end loop;
  perform tst.ok(v_hard_hi between 810 and 990 and v_easy_hi between 510 and 690,
                 'au-dessus de 1 200 : 20 / 50 / 30 (' || v_easy_hi || ', ' || v_hard_hi || ')');
  perform tst.ok(v_hard_lo between 510 and 690, 'en dessous : 30 / 50 / 20 (' || v_hard_lo || ')');
end $$;

-- Recalcul de nuit : une question ratée par 12 joueurs de bon niveau devient bien plus dure ; une question
-- réussie par 12 joueurs faibles devient bien plus facile ; moins de 10 réponses : rien ne bouge.
do $$
declare v_hard uuid; v_easy uuid; v_few uuid; u uuid; v_b0 real; v_e0 real; v_f0 real;
begin
  select id, difficulty_observed into v_hard, v_b0 from public.questions
   where status = 'published' and type = 'mcq' and difficulty_initial between 40 and 60
     and not exists (select 1 from public.question_attempts a where a.question_id = questions.id) order by id limit 1;
  select id, difficulty_observed into v_easy, v_e0 from public.questions
   where status = 'published' and type = 'mcq' and difficulty_initial between 40 and 60
     and not exists (select 1 from public.question_attempts a where a.question_id = questions.id) and id <> v_hard order by id limit 1;
  select id, difficulty_observed into v_few, v_f0 from public.questions
   where status = 'published' and type = 'mcq' and difficulty_initial between 40 and 60
     and not exists (select 1 from public.question_attempts a where a.question_id = questions.id) and id not in (v_hard, v_easy) order by id limit 1;
  for i in 1 .. 12 loop
    u := tst.new_user();
    insert into public.question_attempts (user_id, question_id, concept_id, context, is_correct, question_difficulty, user_skill_before, expected, seen_count)
    select u, q.id, q.concept_id, 'training', false, q.difficulty_effective, 65, 0.8, 1 from public.questions q where q.id = v_hard;
    insert into public.question_attempts (user_id, question_id, concept_id, context, is_correct, question_difficulty, user_skill_before, expected, seen_count)
    select u, q.id, q.concept_id, 'training', true, q.difficulty_effective, 35, 0.3, 1 from public.questions q where q.id = v_easy;
    if i <= 9 then
      insert into public.question_attempts (user_id, question_id, concept_id, context, is_correct, question_difficulty, user_skill_before, expected, seen_count)
      select u, q.id, q.concept_id, 'training', false, q.difficulty_effective, 65, 0.8, 1 from public.questions q where q.id = v_few;
    end if;
  end loop;
  perform public.cron_recalibrate_questions();
  perform tst.ok((select difficulty_effective from public.questions where id = v_hard) > v_b0 + 15,
                 'question ratée par des bons joueurs : plus dure (' || v_b0 || ' → ' || (select difficulty_effective from public.questions where id = v_hard) || ')');
  perform tst.ok((select difficulty_effective from public.questions where id = v_easy) < v_e0 - 10,
                 'question réussie par des joueurs faibles : plus facile (' || v_e0 || ' → ' || (select difficulty_effective from public.questions where id = v_easy) || ')');
  perform tst.ok((select difficulty_observed from public.questions where id = v_few) = v_f0, 'moins de 10 réponses : inchangée');
  perform tst.ok((select difficulty_var from public.questions where id = v_hard) < 100, 'difficulté plus sûre');
end $$;

-- Simulation : un joueur fort (vrai niveau 75, ≈ 1 434) et un joueur moyen (50, 1 000) jouent 12 parties classées
-- en géographie. Le fort ne peut pas dépasser 800 au placement ni 800 + 10 × 30 ensuite ; le moyen monte sans dépasser
-- son vrai niveau de beaucoup ; l'ordre est respecté.
do $$
declare
  thetas real[] := array[75, 50];
  users uuid[] := array[tst.new_user(), tst.new_user()];
  pack jsonb; atts jsonb; x jsonb; b real; c real; ok bool;
  elos real[] := '{}'; v_elo real;
begin
  perform setseed(0.7);
  perform tst.clock('2028-02-01 10:00:00+01');
  for g in 1 .. 12 loop
    for p in 1 .. 2 loop
      perform tst.login(users[p]);
      pack := public.play_pack('training', 'geography', null, 10, true, null);
      atts := '[]'::jsonb;
      for x in select * from jsonb_array_elements(pack -> 'questions') loop
        select difficulty_effective, guess_rate into b, c from public.questions where id = (x ->> 'id')::uuid;
        ok := random() < c + (1 - c) / (1 + exp(-(thetas[p] - b) / 10));
        atts := atts || jsonb_build_object('client_attempt_id', gen_random_uuid(), 'question_id', x ->> 'id',
                                           'given', case when ok then tst.correct_given((x ->> 'id')::uuid) else tst.wrong_given() end,
                                           'response_ms', 6000);
      end loop;
      perform public.play_submit((pack ->> 'session_id')::uuid, atts);
      if g = 2 then
        select elo into v_elo from public.user_skills where user_id = users[p] and scope_id = 'geography';
        perform tst.ok(v_elo <= 800.5, format('joueur %s : 800 au plus après le placement (%s)', thetas[p], round(v_elo)));
      end if;
    end loop;
    perform tst.tick('1 day');
  end loop;
  for p in 1 .. 2 loop
    select elo into v_elo from public.user_skills where user_id = users[p] and scope_id = 'geography';
    elos := elos || v_elo;
    raise notice 'simulation Elo : vrai niveau % → Elo % après 12 parties', thetas[p], round(v_elo);
  end loop;
  perform tst.ok(elos[1] between 850 and 1100.5, 'joueur fort : progression limitée (' || round(elos[1]) || ')');
  perform tst.ok(elos[2] between 600 and 1080, 'joueur moyen : monte vers son niveau (' || round(elos[2]) || ')');
  perform tst.ok(elos[1] > elos[2], 'ordre des joueurs');
end $$;

drop function tst.ranked_game(text, bool);
