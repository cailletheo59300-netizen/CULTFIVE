-- Nouveaux types de réponses : correction, « Pile ! », 5 du jour (1 ou 2 par jour, remplaçant classique pour l'app 1.0),
-- parties classées (au plus un par partie, jamais sans l'app à jour), duels toujours classiques.
create or replace function tst.app_v2(p_on bool) returns void language sql as $$
  select set_config('request.headers', case when p_on then '{"x-brainlix-types":"2"}' else '{}' end, false)
$$;

-- 1. Correction de chaque type.
do $$
begin
  perform tst.ok(public._evaluate('counter', '{"value":206,"tolerance":10}', '{"value":214}'), 'compteur : dans la marge');
  perform tst.ok(not public._evaluate('counter', '{"value":206,"tolerance":10}', '{"value":217}'), 'compteur : hors marge');
  perform tst.ok(not public._evaluate('counter', '{"value":15,"tolerance":0}', '{"value":14}'), 'compteur exact : faux à 1 près');
  perform tst.ok(public._evaluate('timeline', '{"value":-44,"tolerance":20}', '{"value":-60}'), 'frise : avant J.-C.');
  perform tst.ok(public._evaluate('gauge', '{"value":71,"tolerance":5}', '{"value":66}'), 'jauge : borne incluse');
  perform tst.ok(public._evaluate('proportion', '{"value":5.5,"rel_tolerance":0.15}', '{"value":6.2}'), 'proportion : + 12,7 %');
  perform tst.ok(not public._evaluate('proportion', '{"value":5.5,"rel_tolerance":0.15}', '{"value":6.4}'), 'proportion : + 16 %');
  perform tst.ok(public._evaluate('letters', '{"word":"BAGUETTE"}', '{"text":"baguette"}'), 'lettres : casse ignorée');
  perform tst.ok(not public._evaluate('letters', '{"word":"BAGUETTE"}', '{"text":"BAGEUTTE"}'), 'lettres : mauvais ordre');
  perform tst.ok(public._evaluate('word_order', '{"words":["Tous","pour","un","un","pour","tous"]}',
                                  '{"words":["Tous","pour","un","un","pour","tous"]}'), 'mots : mots répétés comparés au texte');
  perform tst.ok(not public._evaluate('word_order', '{"words":["Tous","pour","un"]}', '{"words":["un","pour","Tous"]}'), 'mots : ordre faux');
  perform tst.ok(public._evaluate('image_choice', '{"option_id":"ab12"}', '{"option_id":"ab12"}'), 'images : bonne option');
  perform tst.ok(not public._evaluate('counter', '{"value":5,"tolerance":0}', '{"value":"5"}'), 'texte au lieu d''un nombre : faux');
  perform tst.ok(public._is_exact('counter', '{"value":206,"tolerance":10}', '{"value":206}'), 'pile : valeur exacte');
  perform tst.ok(not public._is_exact('counter', '{"value":206,"tolerance":10}', '{"value":207}'), 'pas pile à 1 près');
  perform tst.ok(not public._is_exact('mcq', '{"option_id":"a"}', '{"option_id":"a"}'), 'pas de pile sur un QCM');
  perform tst.ok((select guess_rate from public.questions where type = 'image_choice' limit 1) = 0.25, 'images : hasard 1/4');
  perform tst.ok(not exists (select 1 from public.questions q where q.payload ? 'labels' or q.payload::text like '%"correct"%'),
                 'la bonne réponse et les noms ne sont jamais dans la partie publique');
  perform tst.ok(not exists (select 1 from public.questions where type = 'image_choice' and payload ->> 'kind' = 'painting' and status = 'published'),
                 'tableaux sans image : pas encore publiés');
end $$;

-- 2. « Pile ! » : +5 graines, une seule fois.
do $$
declare
  u uuid := tst.new_user();
  v_q uuid; s0 int; r jsonb; v_client uuid := gen_random_uuid();
begin
  select id into v_q from public.questions where type = 'counter' and (answer ->> 'tolerance')::int > 0 and status = 'published' limit 1;
  select seeds into s0 from public.profiles where id = u;
  r := public._record_attempt(u, v_q, tst.correct_given(v_q), 4000, 'training', null, v_client, false);
  perform tst.ok((r ->> 'is_correct')::bool and (r ->> 'exact')::bool, 'pile signalé');
  perform tst.ok((select seeds from public.profiles where id = u) = s0 + 5, 'pile : +5 graines');
  perform public._record_attempt(u, v_q, tst.correct_given(v_q), 4000, 'training', null, v_client, false);
  perform tst.ok((select seeds from public.profiles where id = u) = s0 + 5, 'pile : pas versé deux fois');
end $$;

-- 3. 5 du jour sur 30 jours : 1 ou 2 nouveaux types, jamais deux du même, toujours un remplaçant classique.
do $$
declare
  d date; n int; v_bad int := 0; v_same int := 0; v_total int := 0;
begin
  for k in 0 .. 29 loop
    d := date '2027-03-01' + k;
    perform public._generate_daily_set(d);
    select count(*) into n from public.daily_set_items i join public.questions q on q.id = i.question_id
    where i.daily_date = d and not public._is_classic(q.type);
    v_total := v_total + n;
    perform tst.ok(n between 1 and 2, d || ' : 1 ou 2 questions d''un nouveau type (' || n || ')');
    perform tst.ok((select count(distinct q.type) from public.daily_set_items i join public.questions q on q.id = i.question_id
                    where i.daily_date = d and not public._is_classic(q.type)) = n, d || ' : types différents');
    perform tst.ok(not exists (
      select 1 from public.daily_set_items i join public.questions q on q.id = i.question_id
      left join public.questions f on f.id = i.fallback_question_id
      where i.daily_date = d and not public._is_classic(q.type) and (f.id is null or not public._is_classic(f.type))),
      d || ' : remplaçant classique pour chaque nouveau type');
    perform tst.ok(not exists (select 1 from public.daily_set_items i join public.questions q on q.id = i.question_id
                               where i.daily_date = d and public._is_classic(q.type) and i.fallback_question_id is not null),
                   d || ' : pas de remplaçant pour une question classique');
    select count(*) into n from public.daily_set_items i join public.questions q on q.id = i.question_id
    join public.daily_set_items y on y.daily_date = d - 1 join public.questions qy on qy.id = y.question_id
    where i.daily_date = d and not public._is_classic(q.type) and q.type = qy.type;
    v_same := v_same + n;
  end loop;
  perform tst.ok(v_total between 33 and 57, 'environ 1,35 question fun par jour sur 30 jours (' || v_total || ')');
  perform tst.ok(v_same <= 2, 'un même type rarement deux jours de suite (' || v_same || ')');
end $$;

-- 4. App 1.0 (sans en-tête) : uniquement des types classiques ; app à jour : les nouveaux types.
do $$
declare
  u1 uuid := tst.new_user(); u2 uuid := tst.new_user();
  r jsonb; q jsonb; a jsonb; v_run uuid; v_fun int := 0; v_q uuid;
begin
  perform tst.clock('2027-03-10 10:00:00+01');
  perform tst.login(u1);
  perform tst.app_v2(false);
  v_run := (public.daily_start() ->> 'run_id')::uuid;
  for i in 1 .. 5 loop
    q := public.daily_question(v_run, i);
    perform tst.ok(public._is_classic((q ->> 'type')::public.question_type), 'app 1.0 : question classique en ' || i);
    a := public.daily_answer(v_run, i, tst.correct_given((q ->> 'id')::uuid), 3000);
    perform tst.ok((a ->> 'is_correct')::bool, 'app 1.0 : remplaçant corrigé normalement');
  end loop;
  perform tst.ok((select count(*) from jsonb_array_elements(public.daily_review()) x
                  where not public._is_classic((x ->> 'type')::public.question_type)) = 0, 'app 1.0 : revue sans nouveau type');

  perform tst.login(u2);
  perform tst.app_v2(true);
  v_run := (public.daily_start() ->> 'run_id')::uuid;
  for i in 1 .. 5 loop
    q := public.daily_question(v_run, i);
    v_q := (q ->> 'id')::uuid;
    if not public._is_classic((q ->> 'type')::public.question_type) then
      v_fun := v_fun + 1;
      perform tst.ok(not (q -> 'payload' ? 'labels'), 'pas de réponse dans la question');
    end if;
    a := public.daily_answer(v_run, i, tst.correct_given(v_q), 3000);
    perform tst.ok((a ->> 'is_correct')::bool, 'app à jour : bonne réponse acceptée en ' || i);
  end loop;
  perform tst.ok(v_fun between 1 and 2, 'app à jour : 1 ou 2 nouveaux types dans le 5 du jour');
  -- Les deux joueurs ont des positions identiques et le même score possible.
  perform tst.ok((public.daily_result() ->> 'score')::int = 5, 'score 5/5 avec les nouveaux types');
  perform tst.app_v2(false);
end $$;

-- 5. Parties classées : au plus un nouveau type par partie, et seulement pour l'app à jour.
do $$
declare
  u uuid; pack jsonb; n int; v_with int := 0;
begin
  for k in 1 .. 40 loop
    u := tst.new_user();
    perform tst.login(u);
    perform tst.app_v2(true);
    pack := public.play_pack('quick', null, null, 10);
    select count(*) into n from jsonb_array_elements(pack -> 'questions') x where not public._is_classic((x ->> 'type')::public.question_type);
    perform tst.ok(n <= 1, 'au plus un nouveau type par partie (' || n || ')');
    v_with := v_with + n;
    perform tst.app_v2(false);
    pack := public.play_pack('quick', null, null, 10);
    perform tst.ok(not exists (select 1 from jsonb_array_elements(pack -> 'questions') x
                               where not public._is_classic((x ->> 'type')::public.question_type)), 'app 1.0 : partie classique');
  end loop;
  perform tst.ok(v_with between 4 and 30, 'des nouveaux types dans une partie sur deux au plus (' || v_with || '/40)');
end $$;

-- 6. Duels : toujours classiques, même avec l'app à jour.
do $$
declare u1 uuid := tst.new_user(); u2 uuid := tst.new_user(); ids uuid[];
begin
  perform tst.app_v2(true);
  ids := public._duel_pick(u1, u2, 10, null, 'auto');
  perform tst.ok(not exists (select 1 from public.questions q where q.id = any (ids) and not public._is_classic(q.type)), 'duel : types classiques');
  perform tst.app_v2(false);
end $$;

-- 7. Lot 2 : le compte est bon, mot mystère, épingle, tri.
do $$
declare
  u uuid := tst.new_user(); v_q uuid; s0 int; r jsonb;
begin
  perform tst.ok(public._number_target_ok('[3,6,5,2]', 27, '[{"a":6,"op":"+","b":5},{"a":11,"op":"-","b":2},{"a":9,"op":"*","b":3}]'), 'compte est bon : 6+5-2=9, 9×3=27');
  perform tst.ok(not public._number_target_ok('[3,6,5,2]', 27, '[{"a":9,"op":"*","b":3}]'), 'compte est bon : 9 n''est pas disponible');
  perform tst.ok(not public._number_target_ok('[3,6,5,2]', 27, '[{"a":6,"op":"*","b":6}]'), 'compte est bon : un nombre ne sert qu''une fois');
  perform tst.ok(not public._number_target_ok('[3,6,5,2]', 2, '[{"a":5,"op":"/","b":2}]') , 'compte est bon : division non entière refusée');
  perform tst.ok(not public._number_target_ok('[3,6,5,2]', 3, '[{"a":2,"op":"-","b":5}]'), 'compte est bon : pas de négatif');
  perform tst.ok(public._km(48.58, 7.75, 48.86, 2.35) between 390 and 410, 'distance Paris–Strasbourg ≈ 400 km');
  perform tst.ok(public._evaluate('map_pin', '{"lat":48.58,"lon":7.75,"tolerance_km":60}', '{"lat":48.9,"lon":7.6}'), 'épingle : à 37 km, dans la marge');
  perform tst.ok(not public._evaluate('map_pin', '{"lat":48.58,"lon":7.75,"tolerance_km":60}', '{"lat":47.7,"lon":7.3}'), 'épingle : à 100 km, hors marge');
  perform tst.ok(public._is_exact('map_pin', '{"lat":48.58,"lon":7.75,"tolerance_km":60}', '{"lat":48.6,"lon":7.76}'), 'épingle : pile à 2 km');
  perform tst.ok(public._evaluate('sort', '{"groups":{"a":"x","b":"y"}}', '{"groups":{"b":"y","a":"x"}}'), 'tri : l''ordre des clés ne compte pas');
  perform tst.ok(not public._evaluate('sort', '{"groups":{"a":"x","b":"y"}}', '{"groups":{"a":"y","b":"y"}}'), 'tri : une étiquette mal rangée');
  perform tst.ok((select count(*) from public.questions where type in ('number_target', 'riddle', 'map_pin', 'sort') and status = 'published') >= 200,
                 'lot 2 importé');
  -- Chaque question du lot 2 accepte sa propre bonne réponse (solution du compte est bon comprise).
  perform tst.ok(not exists (select 1 from public.questions q where q.type in ('number_target', 'riddle', 'map_pin', 'sort')
                             and not public._evaluate(q.type, q.answer, tst.correct_given(q.id))), 'bonne réponse acceptée pour tout le lot 2');
  -- Mot mystère trouvé au 1er indice : +3 graines.
  select id into v_q from public.questions where type = 'riddle' and status = 'published' limit 1;
  select seeds into s0 from public.profiles where id = u;
  r := public._record_attempt(u, v_q, jsonb_build_object('option_id', (select answer ->> 'option_id' from public.questions where id = v_q), 'clues', 1),
                              5000, 'training', null, gen_random_uuid(), false);
  perform tst.ok((r ->> 'is_correct')::bool, 'mot mystère juste');
  perform tst.ok((select seeds from public.profiles where id = u) = s0 + 3, 'mot mystère au 1er indice : +3 graines');
end $$;
