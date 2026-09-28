-- Brainlix — 0013 Duels
-- Défier un ami (ou n'importe qui via un lien) sur les mêmes 5 questions. Chacun joue quand il veut (48 h).
-- Même règle que le Daily : temps officiel côté serveur, questions servies dans l'ordre, pas de retour en arrière.
-- Vainqueur : meilleur score, puis temps total le plus court. Récompense : +20 XP et +5 graines (plafonnés).

create table public.duels (
  id            uuid primary key default gen_random_uuid(),
  code          text not null unique,
  challenger_id uuid not null references public.profiles(id) on delete cascade,
  opponent_id   uuid references public.profiles(id) on delete cascade,
  question_ids  uuid[] not null check (cardinality(question_ids) = 5),
  status        text not null default 'open' check (status in ('open', 'active', 'finished', 'declined', 'expired')),
  created_at    timestamptz not null default now(),
  expires_at    timestamptz not null,
  finished_at   timestamptz,
  winner_id     uuid,
  check (opponent_id is null or opponent_id <> challenger_id)
);
create index on public.duels (challenger_id, created_at desc);
create index on public.duels (opponent_id, created_at desc);

create table public.duel_answers (
  duel_id     uuid not null references public.duels(id) on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  position    int  not null check (position between 1 and 5),
  question_id uuid not null references public.questions(id),
  served_at   timestamptz not null,
  answered_at timestamptz,
  given       jsonb,
  is_correct  bool,
  counted_ms  int,
  primary key (duel_id, user_id, position)
);
alter table public.duels enable row level security;
alter table public.duel_answers enable row level security;

-- Score d'un joueur dans un duel.
create or replace function public._duel_state(p_duel uuid, p_user uuid, out answered int, out score int, out total_ms int)
language sql stable as $$
  select count(*) filter (where answered_at is not null)::int,
         count(*) filter (where is_correct)::int,
         coalesce(sum(counted_ms) filter (where answered_at is not null), 0)::int
  from public.duel_answers where duel_id = p_duel and user_id = p_user
$$;

-- Clôture : quand les deux ont fini, ou à l'expiration (celui qui a joué gagne ; personne → expiré).
create or replace function public._duel_close(p_duel uuid) returns void
language plpgsql as $$
declare
  d public.duels;
  a record; b record;
  v_winner uuid;
begin
  select * into d from public.duels where id = p_duel for update;
  if d.status not in ('open', 'active') then return; end if;
  select * into a from public._duel_state(d.id, d.challenger_id);
  select * into b from public._duel_state(d.id, d.opponent_id);
  if d.opponent_id is not null and a.answered = 5 and b.answered = 5 then
    v_winner := case when a.score > b.score then d.challenger_id when b.score > a.score then d.opponent_id
                     when a.total_ms < b.total_ms then d.challenger_id when b.total_ms < a.total_ms then d.opponent_id end;
  elsif d.expires_at < public._now() then
    if a.answered = 5 and coalesce(b.answered, 0) < 5 and d.opponent_id is not null then v_winner := d.challenger_id;
    elsif coalesce(b.answered, 0) = 5 and a.answered < 5 then v_winner := d.opponent_id;
    end if;
    if v_winner is null and not (a.answered = 5 and coalesce(b.answered, 0) = 5) then
      update public.duels set status = 'expired', finished_at = public._now() where id = d.id;
      return;
    end if;
  else
    return;
  end if;
  update public.duels set status = 'finished', finished_at = public._now(), winner_id = v_winner where id = d.id;
  if v_winner is not null then
    perform public._grant_capped(v_winner, 'xp', 20, 200, 'duel_win', d.id::text, 'duel_win_xp:' || d.id);
    perform public._grant_capped(v_winner, 'seeds', 5, 20, 'duel_win', d.id::text, 'duel_win_seeds:' || d.id);
  end if;
end $$;

-- Vue d'un duel pour un joueur. Le score adverse n'est révélé qu'une fois sa propre partie finie.
create or replace function public._duel_json(d public.duels, p_user uuid) returns jsonb
language plpgsql stable as $$
declare
  v_other uuid := case when p_user = d.challenger_id then d.opponent_id else d.challenger_id end;
  me record; them record;
begin
  select * into me from public._duel_state(d.id, p_user);
  select * into them from public._duel_state(d.id, v_other);
  return jsonb_build_object(
    'id', d.id, 'code', d.code, 'status', d.status, 'created_at', d.created_at, 'expires_at', d.expires_at,
    'i_am_challenger', p_user = d.challenger_id,
    'opponent', case when v_other is null then null else jsonb_build_object(
        'id', v_other, 'handle', (select handle from public.profiles where id = v_other),
        'answered', them.answered,
        'score', case when me.answered = 5 or d.status = 'finished' then them.score end,
        'total_ms', case when me.answered = 5 or d.status = 'finished' then them.total_ms end) end,
    'me', jsonb_build_object('answered', me.answered, 'score', me.score, 'total_ms', me.total_ms),
    'my_turn', d.status in ('open', 'active') and me.answered < 5,
    'winner', case when d.status = 'finished' then case when d.winner_id is null then 'draw'
                                                        when d.winner_id = p_user then 'me' else 'opponent' end end);
end $$;

create or replace function public.duel_create(p_friend uuid default null) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  v_ids uuid[];
  v_code text;
  d public.duels;
begin
  if p_friend is not null and not public._are_friends(v_user, p_friend) then raise exception 'not_friends'; end if;
  if (select count(*) from public.duels where challenger_id = v_user and created_at > public._now() - interval '1 day') >= 20 then
    raise exception 'rate_limited';
  end if;
  -- Cinq domaines différents, difficulté moyenne, jamais une question d'un Daily en cours ou à venir.
  select array_agg(id) into v_ids from (
    select id from (
      select distinct on (q.domain_id) q.id, q.domain_id from public.questions q
      where q.status = 'published' and q.type <> 'map_pick' and q.difficulty_effective between 35 and 65
        and q.id <> all (public._protected_daily_questions())
      order by q.domain_id, random()) t
    order by random() limit 5) t;
  if cardinality(v_ids) < 5 then raise exception 'not_enough_questions'; end if;
  loop
    v_code := public._random_code(6);
    exit when not exists (select 1 from public.duels where code = v_code);
  end loop;
  insert into public.duels (code, challenger_id, opponent_id, question_ids, status, created_at, expires_at)
  values (v_code, v_user, p_friend, v_ids, case when p_friend is null then 'open' else 'active' end,
          public._now(), public._now() + interval '48 hours')
  returning * into d;
  return public._duel_json(d, v_user);
end $$;

create or replace function public.duel_join(p_code text) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  d public.duels;
begin
  select * into d from public.duels where code = upper(trim(p_code)) for update;
  if not found then raise exception 'duel_not_found'; end if;
  if d.challenger_id = v_user or d.opponent_id = v_user then return public._duel_json(d, v_user); end if;
  if d.opponent_id is not null then raise exception 'duel_taken'; end if;
  if d.status <> 'open' or d.expires_at < public._now() then raise exception 'duel_closed'; end if;
  update public.duels set opponent_id = v_user, status = 'active' where id = d.id returning * into d;
  return public._duel_json(d, v_user);
end $$;

create or replace function public.duel_decline(p_duel uuid) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user();
begin
  update public.duels set status = 'declined', finished_at = public._now()
  where id = p_duel and opponent_id = v_user and status = 'active'
    and not exists (select 1 from public.duel_answers where duel_id = p_duel and user_id = v_user);
  if not found then raise exception 'duel_not_found'; end if;
end $$;

create or replace function public._duel_for_player(p_duel uuid, p_user uuid) returns public.duels
language plpgsql as $$
declare d public.duels;
begin
  select * into d from public.duels where id = p_duel and p_user in (challenger_id, opponent_id) for update;
  if not found then raise exception 'duel_not_found'; end if;
  return d;
end $$;

create or replace function public.duel_question(p_duel uuid, p_position int) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  d public.duels := public._duel_for_player(p_duel, v_user);
  st record;
  q public.questions;
begin
  -- Pas d'exception après la clôture : elle l'annulerait. État explicite, comme le Daily.
  if d.expires_at < public._now() then perform public._duel_close(d.id); return jsonb_build_object('expired', true); end if;
  if d.status not in ('open', 'active') then return jsonb_build_object('expired', true); end if;
  select * into st from public._duel_state(d.id, v_user);
  if p_position <> st.answered + 1 then raise exception 'duel_out_of_order'; end if;
  insert into public.duel_answers (duel_id, user_id, position, question_id, served_at)
  values (d.id, v_user, p_position, d.question_ids[p_position], public._now())
  on conflict (duel_id, user_id, position) do nothing;
  select * into q from public.questions where id = d.question_ids[p_position];
  return public._question_public(q, d.id::text) || jsonb_build_object('position', p_position, 'total', 5);
end $$;

create or replace function public.duel_answer(p_duel uuid, p_position int, p_given jsonb, p_client_ms int) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  d public.duels := public._duel_for_player(p_duel, v_user);
  a public.duel_answers;
  q public.questions;
  v_server_ms int; v_counted int;
  v_res jsonb;
  v_done bool;
begin
  select * into a from public.duel_answers where duel_id = d.id and user_id = v_user and position = p_position for update;
  if not found then raise exception 'duel_not_served'; end if;
  select * into q from public.questions where id = a.question_id;
  if a.answered_at is not null then
    return jsonb_build_object('position', p_position, 'is_correct', a.is_correct, 'duplicate', true, 'counted_ms', a.counted_ms,
                              'finished', p_position = 5) || public._question_reveal(q);
  end if;
  if d.status not in ('open', 'active') then raise exception 'duel_closed'; end if;

  v_server_ms := floor(extract(epoch from public._now() - a.served_at) * 1000)::int;
  v_counted := least(v_server_ms, greatest(coalesce(p_client_ms, v_server_ms), v_server_ms - 2000));
  v_counted := least(greatest(v_counted, 300), 120000);
  v_res := public._record_attempt(v_user, q.id, p_given, v_counted, 'challenge', d.id,
                                  md5(d.id::text || ':' || v_user || ':' || p_position)::uuid, true);
  update public.duel_answers set answered_at = public._now(), given = p_given, is_correct = (v_res ->> 'is_correct')::bool,
    counted_ms = v_counted
  where duel_id = d.id and user_id = v_user and position = p_position;
  if (v_res ->> 'is_correct')::bool then
    perform public._grant_capped(v_user, 'xp', 5, 300, 'duel_correct', d.id::text, 'duel_correct:' || d.id || ':' || v_user || ':' || p_position);
  end if;
  v_done := p_position = 5;
  if v_done then perform public._duel_close(d.id); end if;
  return jsonb_build_object('position', p_position, 'is_correct', (v_res ->> 'is_correct')::bool, 'duplicate', false,
                            'counted_ms', v_counted, 'finished', v_done, 'error_transition', v_res -> 'error_transition')
         || public._question_reveal(q);
end $$;

-- Résultat détaillé : mes réponses, et celles de l'adversaire une fois ma partie finie.
create or replace function public.duel_result(p_duel uuid) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  d public.duels := public._duel_for_player(p_duel, v_user);
  v_other uuid;
  v_mine int;
begin
  perform public._duel_close(d.id);
  select * into d from public.duels where id = p_duel;
  v_other := case when v_user = d.challenger_id then d.opponent_id else d.challenger_id end;
  select answered into v_mine from public._duel_state(d.id, v_user);
  return public._duel_json(d, v_user) || jsonb_build_object(
    'my_answers', coalesce((select jsonb_agg(jsonb_build_object('position', position, 'is_correct', is_correct, 'counted_ms', counted_ms) order by position)
                            from public.duel_answers where duel_id = d.id and user_id = v_user and answered_at is not null), '[]'::jsonb),
    'their_answers', case when v_mine = 5 or d.status = 'finished' then coalesce((
                            select jsonb_agg(jsonb_build_object('position', position, 'is_correct', is_correct, 'counted_ms', counted_ms) order by position)
                            from public.duel_answers where duel_id = d.id and user_id = v_other and answered_at is not null), '[]'::jsonb) end);
end $$;

-- Mes duels récents (30 jours), clôture des expirés au passage.
create or replace function public.duels_mine() returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user(); r record;
begin
  for r in select id from public.duels where v_user in (challenger_id, opponent_id) and status in ('open', 'active')
                                         and expires_at < public._now() loop
    perform public._duel_close(r.id);
  end loop;
  return coalesce((select jsonb_agg(public._duel_json(d, v_user) order by d.created_at desc)
                   from public.duels d where v_user in (d.challenger_id, d.opponent_id)
                     and d.created_at > public._now() - interval '30 days' and d.status <> 'declined'), '[]'::jsonb);
end $$;

do $$
declare f text;
begin
  foreach f in array array['duel_create(uuid)', 'duel_join(text)', 'duel_decline(uuid)', 'duel_question(uuid,int)',
                           'duel_answer(uuid,int,jsonb,int)', 'duel_result(uuid)', 'duels_mine()'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
revoke execute on function public._duel_state(uuid, uuid), public._duel_close(uuid), public._duel_json(public.duels, uuid),
  public._duel_for_player(uuid, uuid) from public, anon, authenticated;
