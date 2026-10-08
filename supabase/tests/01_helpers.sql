-- ─────────── Outils de test (schéma tst, jamais déployé)
create schema if not exists tst;
create or replace function tst.new_user(p_anonymous bool default false) returns uuid language plpgsql as $$
declare v uuid := gen_random_uuid();
begin
  insert into auth.users (id, email, is_anonymous) values (v, case when not p_anonymous then v || '@test.local' end, p_anonymous);
  return v;
end $$;
create or replace function tst.login(p_user uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_user)::text, false)
$$;
create or replace function tst.clock(p_at timestamptz) returns void language sql as $$
  select set_config('app.now_override', p_at::text, false)
$$;
create or replace function tst.tick(p_interval interval) returns void language sql as $$
  select set_config('app.now_override', (current_setting('app.now_override')::timestamptz + p_interval)::text, false)
$$;
create or replace function tst.ok(p_cond bool, p_msg text) returns void language plpgsql as $$
begin
  if p_cond is not true then raise exception 'ASSERTION FAILED: %', p_msg; end if;
end $$;
create or replace function tst.throws(p_sql text, p_expected text) returns void language plpgsql as $$
begin
  execute p_sql;
  raise exception 'ASSERTION FAILED: expected error "%" from: %', p_expected, p_sql;
exception when others then
  if sqlerrm like 'ASSERTION FAILED%' then raise; end if;
  if position(p_expected in sqlerrm) = 0 then
    raise exception 'ASSERTION FAILED: expected "%", got "%" from: %', p_expected, sqlerrm, p_sql;
  end if;
end $$;
-- Bonne réponse d'une question (pour simuler un joueur parfait).
create or replace function tst.correct_given(p_question uuid) returns jsonb language sql as $$
  select case q.type
    when 'mcq' then jsonb_build_object('option_id', q.answer ->> 'option_id')
    when 'map_pick' then jsonb_build_object('option_id', q.answer ->> 'option_id')
    when 'true_false' then jsonb_build_object('value', q.answer -> 'value')
    when 'numeric' then jsonb_build_object('value', q.answer -> 'value')
    when 'ordering' then jsonb_build_object('order', q.answer -> 'order')
    when 'pairs' then jsonb_build_object('pairs', q.answer -> 'pairs')
    when 'counter' then jsonb_build_object('value', q.answer -> 'value')
    when 'timeline' then jsonb_build_object('value', q.answer -> 'value')
    when 'gauge' then jsonb_build_object('value', q.answer -> 'value')
    when 'proportion' then jsonb_build_object('value', q.answer -> 'value')
    when 'letters' then jsonb_build_object('text', q.answer -> 'word')
    when 'word_order' then jsonb_build_object('words', q.answer -> 'words')
    when 'image_choice' then jsonb_build_object('option_id', q.answer ->> 'option_id')
  end from public.questions q where q.id = p_question
$$;
create or replace function tst.wrong_given() returns jsonb language sql as $$ select '{"option_id":"nope","value":-999999}'::jsonb $$;
grant usage on schema tst to anon, authenticated;
grant execute on all functions in schema tst to anon, authenticated;
