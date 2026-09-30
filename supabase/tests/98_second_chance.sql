-- Seconde chance : payée, 2e essai retenu, demi-réussite pour l'Elo, moitié des points, notion à revoir.
do $$
declare
  u uuid := tst.new_user();
  u2 uuid := tst.new_user();
  pack jsonb; pack2 jsonb;
  q public.questions; q2 public.questions;
  wrong jsonb;
  seeds0 int;
  r jsonb; r2 jsonb;
  e jsonb;
  mu_sc real; mu_ok real; mu_ko real;
  pts_sc int; pts_ok int;
begin
  perform tst.clock('2027-09-01 10:00:00+02');
  update public.profiles set seeds = 100 where id in (u, u2);

  -- Même question pour deux joueurs neufs : l'un réussit du premier coup, l'autre au 2e essai.
  perform tst.login(u);
  pack := public.play_pack('training', 'geography', null, 10, true, null);
  select * into q from public.questions
  where id in (select (x ->> 'id')::uuid from jsonb_array_elements(pack -> 'questions') x)
    and type = 'mcq' and jsonb_array_length(payload -> 'options') >= 3
  limit 1;
  select jsonb_build_object('option_id', o ->> 'id') into wrong
  from jsonb_array_elements(q.payload -> 'options') o where o ->> 'id' <> q.answer ->> 'option_id' limit 1;

  -- Sans paiement : le 1er essai compte.
  r := public.play_submit((pack ->> 'session_id')::uuid, jsonb_build_array(jsonb_build_object(
         'client_attempt_id', gen_random_uuid(), 'question_id', q.id, 'first_given', wrong,
         'given', tst.correct_given(q.id), 'response_ms', 4000)));
  perform tst.ok(not (r -> 'results' -> 0 ->> 'is_correct')::bool and not (r -> 'results' -> 0 ->> 'second_chance')::bool,
                 'seconde chance non payée : le 1er essai compte');

  -- Nouvelle partie, avec paiement.
  pack := public.play_pack('training', 'geography', null, 10, true, null);
  select * into q from public.questions
  where id in (select (x ->> 'id')::uuid from jsonb_array_elements(pack -> 'questions') x)
    and type = 'mcq' and jsonb_array_length(payload -> 'options') >= 3
  limit 1;
  select jsonb_build_object('option_id', o ->> 'id') into wrong
  from jsonb_array_elements(q.payload -> 'options') o where o ->> 'id' <> q.answer ->> 'option_id' limit 1;
  select seeds into seeds0 from public.profiles where id = u;
  r := public.play_spend_help((pack ->> 'session_id')::uuid, q.id, 'second_chance');
  perform tst.ok(r - 'balance' - 'ticket_used' - 'tickets_left' = '{}'::jsonb, 'seconde chance : rien n''est dévoilé');
  perform tst.ok((select seeds from public.profiles where id = u) = seeds0 - 15, 'seconde chance : 15 graines');
  perform public.play_spend_help((pack ->> 'session_id')::uuid, q.id, 'second_chance');
  perform tst.ok((select seeds from public.profiles where id = u) = seeds0 - 15, 'seconde chance : pas facturée deux fois');

  select mu into mu_sc from public.user_skills where user_id = u and scope_id = 'geography';
  r := public.play_submit((pack ->> 'session_id')::uuid, jsonb_build_array(jsonb_build_object(
         'client_attempt_id', gen_random_uuid(), 'question_id', q.id, 'first_given', wrong,
         'given', tst.correct_given(q.id), 'response_ms', 4000)));
  e := r -> 'results' -> 0;
  perform tst.ok((e ->> 'is_correct')::bool and (e ->> 'second_chance')::bool, 'seconde chance payée : 2e essai retenu');
  pts_sc := (e ->> 'points')::int;
  perform tst.ok((select error_state::text from public.user_concepts where user_id = u and concept_id = q.concept_id) = 'failed',
                 'seconde chance : notion à revoir');
  perform tst.ok((select second_chance from public.question_attempts where user_id = u and question_id = q.id order by created_at desc limit 1),
                 'tentative marquée');

  -- Joueur témoin : même question, juste du premier coup, puis faux.
  perform tst.login(u2);
  pack2 := public.play_pack('training', 'geography', null, 10, true, null);
  update public.play_sessions set question_ids = question_ids || q.id where id = (pack2 ->> 'session_id')::uuid;
  r2 := public.play_submit((pack2 ->> 'session_id')::uuid, jsonb_build_array(jsonb_build_object(
          'client_attempt_id', gen_random_uuid(), 'question_id', q.id, 'given', tst.correct_given(q.id), 'response_ms', 4000)));
  pts_ok := (r2 -> 'results' -> 0 ->> 'points')::int;
  perform tst.ok(pts_sc > 0 and pts_sc < pts_ok, 'seconde chance : moins de points (' || pts_sc || ' contre ' || pts_ok || ')');

  -- Elo : la demi-réussite fait moins monter qu'une bonne réponse franche.
  select (e ->> 'domain_after')::real into mu_sc;
  select (r2 -> 'results' -> 0 ->> 'domain_after')::real into mu_ok;
  perform tst.ok(mu_sc < mu_ok, 'Elo : demi-réussite < réussite (' || mu_sc || ' < ' || mu_ok || ')');

  -- Vrai/Faux : pas de seconde chance.
  perform tst.login(u);
  select * into q2 from public.questions where type = 'true_false' and status = 'published' limit 1;
  update public.play_sessions set question_ids = question_ids || q2.id where id = (pack ->> 'session_id')::uuid;
  perform tst.throws(format('select public.play_spend_help(%L, %L, ''second_chance'')', pack ->> 'session_id', q2.id), 'help_unavailable');

  -- Ticket indice utilisé avant les graines.
  insert into public.user_items (user_id, item_id, qty) values (u, 'ticket_hint', 1)
  on conflict (user_id, item_id) do update set qty = 1;
  select seeds into seeds0 from public.profiles where id = u;
  select * into q2 from public.questions
  where id in (select (x ->> 'id')::uuid from jsonb_array_elements(pack -> 'questions') x)
    and type = 'mcq' and jsonb_array_length(payload -> 'options') >= 3 and id <> q.id
  limit 1;
  r := public.play_spend_help((pack ->> 'session_id')::uuid, q2.id, 'second_chance');
  perform tst.ok((r ->> 'ticket_used')::bool and (select seeds from public.profiles where id = u) = seeds0, 'seconde chance : ticket indice');

  perform tst.ok(not has_function_privilege('authenticated', 'public._second_chance_ok(uuid, uuid, uuid, jsonb)', 'execute'), 'fonction interne protégée');
end $$;
