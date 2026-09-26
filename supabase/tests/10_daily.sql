-- Daily : parcours complet, score, temps, double soumission, série, minuit, expiration, fuseaux.
do $$
declare
  u uuid := tst.new_user();
  s jsonb; r jsonb; q jsonb; a jsonb; res jsonb;
  v_run uuid;
  v_qid uuid;
  p public.profiles;
begin
  perform tst.clock('2026-09-26 10:00:00+02');
  perform tst.login(u);

  s := public.daily_status();
  perform tst.ok(s ->> 'state' = 'available', 'daily disponible au départ');
  perform tst.ok((s ->> 'date')::date = '2026-09-26', 'date du jour dans le fuseau du profil');

  r := public.daily_start();
  v_run := (r ->> 'run_id')::uuid;
  perform tst.ok((r ->> 'next_position')::int = 1, 'commence à la question 1');
  perform tst.ok(public.daily_start() ->> 'run_id' = v_run::text, 'daily_start idempotent');

  perform tst.throws(format('select public.daily_question(%L, 2)', v_run), 'daily_out_of_order');
  perform tst.throws(format('select public.daily_answer(%L, 1, ''{}'', 1000)', v_run), 'daily_not_served');

  for i in 1 .. 5 loop
    q := public.daily_question(v_run, i);
    perform tst.ok(not (q ? 'answer') and not (q ? 'explanation'), 'la réponse ne fuit pas avant validation');
    perform tst.ok((q ->> 'position')::int = i, 'position renvoyée');
    v_qid := (q ->> 'id')::uuid;
    -- Re-servir ne remet pas l'horloge à zéro
    perform tst.tick('3 seconds');
    perform public.daily_question(v_run, i);
    perform tst.tick('2 seconds');
    a := public.daily_answer(v_run, i, case when i < 5 then tst.correct_given(v_qid) else tst.wrong_given() end, 4800);
    perform tst.ok((a ->> 'is_correct')::bool = (i < 5), 'verdict attendu Q' || i);
    perform tst.ok(a ? 'answer' and a ? 'explanation', 'révélation après réponse');
    perform tst.ok((a ->> 'counted_ms')::int = 4800, 'temps client retenu (dans la tolérance de 2 s) : ' || (a ->> 'counted_ms'));
    perform tst.ok((a ->> 'finished')::bool = (i = 5), 'fin après la 5e');
  end loop;

  -- Double soumission : pas de double effet
  a := public.daily_answer(v_run, 3, tst.wrong_given(), 1);
  perform tst.ok((a ->> 'duplicate')::bool and (a ->> 'is_correct')::bool, 'double soumission renvoie le verdict initial');

  res := public.daily_result();
  perform tst.ok((res ->> 'score')::int = 4, 'score 4/5');
  perform tst.ok((res ->> 'total_ms')::int = 5 * 4800, 'temps total = somme des temps comptés');
  perform tst.ok((res ->> 'streak')::int = 1, 'série = 1');
  perform tst.ok(res -> 'percentile' ->> 'source' = 'estimate', 'percentile en estimation sous 100 joueurs');
  perform tst.ok((res -> 'percentile' ->> 'top')::int between 1 and 99, 'percentile borné');
  perform tst.ok(jsonb_array_length(res -> 'answers') = 5, '5 réponses dans le résultat');
  perform tst.ok(res -> 'achievements' -> 0 ->> 'id' = 'first_daily', 'trophée premier daily');

  select * into p from public.profiles where id = u;
  perform tst.ok(p.xp_total = 4 * 10 + 30, 'XP = 4×10 + 30, obtenu : ' || p.xp_total);
  perform tst.ok(p.seeds = 10 + 10, 'graines = 10 (daily) + 10 (trophée), obtenu : ' || p.seeds);
  perform tst.ok(p.questions_answered = 5, 'compteur de réponses');

  -- Une seule tentative officielle
  perform tst.ok(public.daily_start() ->> 'status' = 'finished', 'daily_start ne recrée pas de run');
  perform tst.throws(format('select public.daily_question(%L, 1)', v_run), 'daily_closed');
  perform tst.ok(public.daily_status() ->> 'state' = 'done', 'état terminé');
  perform tst.ok(jsonb_array_length(public.daily_review()) = 5, 'revue disponible après la fin');
  perform tst.ok(public.daily_review() -> 0 ? 'answer', 'revue contient les réponses');

  -- Changer l'heure système (client) n'a aucun effet : seule l'horloge serveur compte. Jour suivant :
  perform tst.tick('1 day');
  perform tst.ok(public.daily_status() ->> 'state' = 'available', 'nouveau jour : disponible');
  r := public.daily_start(); v_run := (r ->> 'run_id')::uuid;
  for i in 1 .. 5 loop
    q := public.daily_question(v_run, i);
    perform tst.tick('4 seconds');
    perform public.daily_answer(v_run, i, tst.correct_given((q ->> 'id')::uuid), null);
  end loop;
  res := public.daily_result();
  perform tst.ok((res ->> 'score')::int = 5 and (res ->> 'streak')::int = 2, 'jour 2 : 5/5, série 2');
  perform tst.ok(exists (select 1 from public.user_achievements where user_id = u and achievement_id = 'first_perfect'), 'trophée 5/5');
  perform tst.ok(exists (select 1 from public.user_achievements where user_id = u and achievement_id = 'fast_perfect'), 'trophée éclair (< 60 s)');

  -- Jour sauté, pas de joker : la série repart à 1
  perform tst.tick('2 days');
  perform tst.ok((public.daily_status() ->> 'streak')::int = 0, 'série affichée rompue');
  r := public.daily_start(); v_run := (r ->> 'run_id')::uuid;
  for i in 1 .. 5 loop
    q := public.daily_question(v_run, i);
    perform tst.tick('3 seconds');
    perform public.daily_answer(v_run, i, tst.wrong_given(), 3000);
  end loop;
  res := public.daily_result();
  perform tst.ok((res ->> 'score')::int = 0 and (res ->> 'streak')::int = 1, '0/5 compte comme joué, série 1');
end $$;

-- Temps : le client ne peut pas retrancher plus de 2 s au temps serveur.
do $$
declare u uuid := tst.new_user(); r jsonb; q jsonb; a jsonb; v_run uuid;
begin
  perform tst.clock('2026-10-01 09:00:00+02');
  perform tst.login(u);
  r := public.daily_start(); v_run := (r ->> 'run_id')::uuid;
  q := public.daily_question(v_run, 1);
  perform tst.tick('10 seconds');
  a := public.daily_answer(v_run, 1, tst.wrong_given(), 1);
  perform tst.ok((a ->> 'counted_ms')::int = 8000, 'temps compté = serveur − 2 s, obtenu ' || (a ->> 'counted_ms'));
  q := public.daily_question(v_run, 2);
  perform tst.tick('5 minutes');
  a := public.daily_answer(v_run, 2, tst.wrong_given(), null);
  perform tst.ok((a ->> 'counted_ms')::int = 120000, 'temps plafonné à 120 s');
end $$;

-- Minuit : un run commencé à 23:59 reste rattaché à sa date, délai de grâce 30 min puis expiration.
do $$
declare u uuid := tst.new_user(); u2 uuid := tst.new_user(); r jsonb; q jsonb; a jsonb; v_run uuid;
begin
  perform tst.clock('2026-10-02 23:59:30+02');
  perform tst.login(u);
  r := public.daily_start(); v_run := (r ->> 'run_id')::uuid;
  perform tst.ok((r ->> 'date')::date = '2026-10-02', 'date de départ');
  q := public.daily_question(v_run, 1);
  perform tst.tick('10 minutes');  -- 00:09:30 le lendemain
  a := public.daily_answer(v_run, 1, tst.correct_given((q ->> 'id')::uuid), 5000);
  perform tst.ok((a ->> 'is_correct')::bool, 'réponse acceptée après minuit (grâce)');
  perform tst.ok((public.daily_status() ->> 'date')::date = '2026-10-03', 'le statut montre déjà le nouveau jour');
  perform tst.tick('25 minutes'); -- 00:34:30 : délai dépassé
  perform tst.ok((public.daily_question(v_run, 2) ->> 'expired')::bool, 'question refusée : délai dépassé');
  perform tst.ok((select status from public.daily_runs where id = v_run) = 'expired', 'run expiré');
  perform tst.ok((select score from public.daily_runs where id = v_run) = 1, 'score officiel = réponses données');
  perform tst.ok((select streak_current from public.profiles where id = u) = 0, 'un run expiré ne compte pas pour la série');
  perform tst.ok(jsonb_array_length(public.daily_review('2026-10-02')) = 5, 'revue complète même expiré');

  -- Maintenance planifiée : clôture des runs abandonnés d'autres joueurs
  perform tst.login(u2);
  perform tst.clock('2026-10-02 12:00:00+02');
  r := public.daily_start();
  perform tst.clock('2026-10-03 06:00:00+02');
  perform public.cron_daily_maintenance();
  perform tst.ok((select status from public.daily_runs where id = (r ->> 'run_id')::uuid) = 'expired', 'cron expire les runs abandonnés');
  perform tst.ok((select count(*) from public.daily_sets where daily_date between '2026-10-03' and '2026-10-05') = 3, 'cron génère J à J+2');
end $$;

-- Fuseau : même série pour tous à une date donnée ; changements limités.
do $$
declare paris uuid := tst.new_user(); tokyo uuid := tst.new_user(); r jsonb;
begin
  perform tst.clock('2026-10-10 20:00:00+02');  -- 03:00 le 11 à Tokyo
  perform tst.login(tokyo);
  perform tst.ok((public.set_timezone('Asia/Tokyo') ->> 'applied')::bool, 'premier changement accepté');
  perform tst.ok((public.daily_status() ->> 'date')::date = '2026-10-11', 'Tokyo est déjà le 11');
  perform tst.ok((public.daily_start() ->> 'date')::date = '2026-10-11', 'Tokyo joue le Daily du 11');
  perform tst.ok(not (public.set_timezone('Pacific/Kiritimati') ->> 'applied')::bool, 'second changement < 20 h refusé');
  perform tst.throws('select public.set_timezone(''Mars/Olympus'')', 'invalid_timezone');
  perform tst.login(paris);
  perform tst.ok((public.daily_status() ->> 'date')::date = '2026-10-10', 'Paris est encore le 10');
  perform tst.ok((select count(distinct question_id) from public.daily_set_items where daily_date = '2026-10-11') = 5, 'série de 5 questions distinctes');
  perform tst.ok((select count(distinct slot) from public.daily_set_items where daily_date = '2026-10-11') = 5, 'un emplacement par pilier + surprise');
end $$;

-- Génération : 5 questions et 5 concepts distincts, pas de réutilisation à moins de 14 jours.
-- (La variété des types est une préférence douce : elle dépend de la composition de la banque.)
do $$
declare d date;
begin
  for i in 0 .. 20 loop
    d := '2027-01-01'::date + i;
    perform public._ensure_daily_set(d);
    perform tst.ok((select count(distinct q.concept_id) from public.daily_set_items i join public.questions q on q.id = i.question_id
                    where i.daily_date = d) = 5, '5 concepts distincts (' || d || ')');
  end loop;
  perform tst.ok(not exists (
    select 1 from public.daily_set_items a join public.daily_set_items b
      on a.question_id = b.question_id and a.daily_date < b.daily_date and b.daily_date - a.daily_date <= 14
    where a.daily_date >= '2027-01-01'), 'aucune question réutilisée à moins de 14 jours');
end $$;

-- Équilibre du créneau Surprise : aucun domaine ne domine sur 60 jours.
do $$
declare v_max numeric; v_domains int;
begin
  for i in 0 .. 59 loop perform public._ensure_daily_set('2028-01-01'::date + i); end loop;
  select max(n)::numeric / 60, count(*) into v_max, v_domains from (
    select q.domain_id, count(*) n from public.daily_set_items i join public.questions q on q.id = i.question_id
    where i.daily_date between '2028-01-01' and '2028-02-29' and i.slot = 'surprise' group by 1) t;
  perform tst.ok(v_domains >= 6, 'au moins 6 domaines différents en Surprise : ' || v_domains);
  perform tst.ok(v_max <= 0.3, 'aucun domaine au-delà de 30 % des Surprise : ' || round(v_max * 100) || ' %');
end $$;

-- Daily : jamais deux questions de la même famille.
do $$
begin
  perform tst.ok(not exists (
    select 1 from public.daily_set_items i join public.questions q on q.id = i.question_id
    where i.daily_date between '2028-01-01' and '2028-02-29' and q.family is not null
    group by i.daily_date, q.family having count(*) > 1), 'une famille au plus par Daily');
end $$;
