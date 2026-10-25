-- ─────────────────────────────────────────── 0088 · Arène : duels classés (D-111)
-- Un duel classé = 7 questions mélangées, 15 s chacune (3 s de marge réseau), mêmes questions pour les deux joueurs.
-- File commune : « Trouver un adversaire » prend le duel ouvert le plus ancien d'un autre joueur (le premier qui le
-- prend le garde) ; s'il n'y en a pas, le joueur ouvre le sien, que le prochain joueur prendra. Jamais d'attente :
-- on joue tout de suite, et le résultat arrive dès que l'autre a joué (notification).
-- Points de la semaine (lundi → dimanche, heure de Paris) : victoire +3, égalité +1, défaite 0 (on ne perd jamais de
-- points), +1 par victoire dès 3 victoires de suite. Classement : 5 duels au moins dans la semaine pour être classé
-- devant ceux qui en ont joué moins. Le lundi, chacun reçoit les récompenses de sa place (top 15), un coffre en bois
-- sinon. En plus : coffre d'argent au 1er duel gagné du jour et à chaque série de 5 victoires, coffre en or (carte
-- rare ou mieux) toutes les 10 victoires. Les duels entre amis et par lien ne changent pas.

alter table public.duels add column arena bool not null default false;
create index duels_arena_queue on public.duels (created_at) where arena and status = 'open' and opponent_id is null;
create index duels_arena_player on public.duels (challenger_id, created_at desc) where arena;

-- Réglages de l'Arène (un seul endroit, modifiables sans mise à jour de l'app).
create or replace function public._arena_rule(p_key text) returns int
language sql immutable set search_path = public, pg_temp as $$
  select case p_key
    when 'questions' then 7 when 'seconds' then 15 when 'grace' then 3
    when 'win' then 3 when 'draw' then 1 when 'loss' then 0
    when 'streak_from' then 3 when 'streak_bonus' then 1 when 'streak_chest' then 5
    when 'chest_every' then 10 when 'min_duels' then 5
    when 'queue_hours' then 48 when 'play_minutes' then 30 when 'abandon_minutes' then 15
    when 'daily_limit' then 80 end
$$;

-- Semaine de l'Arène : du lundi 0 h au lundi suivant, heure de Paris.
create or replace function public._arena_week(p_ts timestamptz) returns date
language sql stable set search_path = public, pg_temp as $$
  select date_trunc('week', (p_ts at time zone 'Europe/Paris'))::date
$$;

create or replace function public._arena_week_end(p_week date) returns timestamptz
language sql stable set search_path = public, pg_temp as $$
  select ((p_week + 7)::timestamp) at time zone 'Europe/Paris'
$$;

-- Récompenses de fin de semaine selon la place (les quantités se règlent ici).
create or replace function public._arena_prize(p_rank int, p_eligible bool) returns jsonb
language sql immutable set search_path = public, pg_temp as $$
  select case
    when p_eligible and p_rank = 1 then '{"gold":3,"card":"legend","seeds":500,"trophy":"arena_champion","cosmetic":"cadre.champion","crown":true}'::jsonb
    when p_eligible and p_rank = 2 then '{"gold":2,"card":"epic","seeds":300,"trophy":"arena_podium"}'::jsonb
    when p_eligible and p_rank = 3 then '{"gold":2,"card":"epic","seeds":200,"trophy":"arena_podium"}'::jsonb
    when p_eligible and p_rank <= 5 then '{"gold":1,"packs":2,"seeds":100}'::jsonb
    when p_eligible and p_rank <= 10 then '{"silver":1,"packs":1}'::jsonb
    when p_eligible and p_rank <= 15 then '{"silver":1}'::jsonb
    else '{"wood":1}'::jsonb end
$$;

-- Le tableau des récompenses, pour l'affichage.
create or replace function public._arena_prizes_table() returns jsonb
language sql immutable set search_path = public, pg_temp as $$
  select jsonb_build_array(
    jsonb_build_object('from', 1, 'to', 1) || public._arena_prize(1, true),
    jsonb_build_object('from', 2, 'to', 2) || public._arena_prize(2, true),
    jsonb_build_object('from', 3, 'to', 3) || public._arena_prize(3, true),
    jsonb_build_object('from', 4, 'to', 5) || public._arena_prize(4, true),
    jsonb_build_object('from', 6, 'to', 10) || public._arena_prize(6, true),
    jsonb_build_object('from', 11, 'to', 15) || public._arena_prize(11, true),
    jsonb_build_object('from', 16, 'to', null) || public._arena_prize(16, true))
$$;

insert into public.album_cosmetics (id, name) values ('cadre.champion', 'Cadre Champion de l''Arène')
on conflict (id) do nothing;
insert into public.achievements (id, name, description, reward_seeds, sort, category, chest) values
  ('arena_champion', 'Champion de l''Arène', 'Finir 1er du classement de l''Arène sur une semaine.', 0, 200, 'exploit', 'gold'),
  ('arena_podium', 'Podium de l''Arène', 'Finir dans les 3 premiers de l''Arène sur une semaine.', 0, 201, 'exploit', 'silver'),
  ('arena_wins_25', 'Gladiateur', 'Gagner 25 duels classés.', 0, 202, 'exploit', 'silver')
on conflict (id) do nothing;

-- Résultat de chaque duel classé, pour chaque joueur.
create table public.arena_results (
  duel_id    uuid not null references public.duels(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  week       date not null,
  outcome    text not null check (outcome in ('win', 'draw', 'loss')),
  points     int not null,
  streak     int not null,
  score      int not null,
  opp_score  int not null,
  bonus      text[] not null default '{}',
  created_at timestamptz not null,
  primary key (duel_id, user_id)
);
create index arena_results_week on public.arena_results (week, user_id);
create index arena_results_user on public.arena_results (user_id, created_at desc);
alter table public.arena_results enable row level security;
revoke all on public.arena_results from anon, authenticated;

-- Récompenses de fin de semaine, versées une fois.
create table public.arena_week_rewards (
  week       date not null,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  rank       int not null,
  points     int not null,
  wins       int not null,
  duels      int not null,
  eligible   bool not null,
  prizes     jsonb not null,
  created_at timestamptz not null,
  seen_at    timestamptz,
  primary key (week, user_id)
);
create index arena_week_rewards_rank on public.arena_week_rewards (week, rank);
alter table public.arena_week_rewards enable row level security;
revoke all on public.arena_week_rewards from anon, authenticated;

-- Classement d'une semaine : classés (5 duels au moins) d'abord, puis points, victoires, et le premier arrivé.
create or replace function public._arena_standings(p_week date)
returns table (user_id uuid, rank int, points int, wins int, duels int, eligible bool)
language sql stable set search_path = public, pg_temp as $$
  with s as (
    select r.user_id, sum(r.points)::int as points, count(*) filter (where r.outcome = 'win')::int as wins,
           count(*)::int as duels, max(r.created_at) as last_at
    from public.arena_results r
    where r.week = p_week and public._real_player(r.user_id)
    group by r.user_id
  )
  select s.user_id, (row_number() over (order by (s.duels >= public._arena_rule('min_duels')) desc, s.points desc,
                                         s.wins desc, s.last_at))::int,
         s.points, s.wins, s.duels, s.duels >= public._arena_rule('min_duels')
  from s
$$;

-- Champion de la semaine passée (sa couronne se voit pendant toute la semaine en cours).
create or replace function public._arena_champion() returns uuid
language sql stable set search_path = public, pg_temp as $$
  select w.user_id from public.arena_week_rewards w
  where w.week = public._arena_week(public._now()) - 7 and w.rank = 1 and w.eligible
$$;

-- Tirage d'un duel classé : 7 questions à choix, vrai/faux ou nombre (le chrono est court), difficulté moyenne, domaines
-- variés, jamais vues par le joueur si possible, jamais une question d'un 5 du jour protégé.
create or replace function public._arena_pick(p_user uuid) returns uuid[]
language plpgsql volatile set search_path = public, pg_temp as $$
declare v_ids uuid[];
begin
  select array_agg(id order by rnd) into v_ids from (
    select id, random() as rnd from (
      select q.id,
             row_number() over (partition by q.domain_id
                                order by exists (select 1 from public.question_attempts a
                                                 where a.question_id = q.id and a.user_id = p_user),
                                         random()) as rn
      from public.questions q
      where q.status = 'published' and q.type in ('mcq', 'true_false', 'numeric')
        and not q.needs_review
        and q.difficulty_effective between 30 and 62
        and q.id <> all (public._protected_daily_questions())
    ) t
    where rn = 1
    order by random()
    limit public._arena_rule('questions')
  ) s;
  return v_ids;
end $$;

create or replace function public._arena_new(p_user uuid) returns public.duels
language plpgsql set search_path = public, pg_temp as $$
declare
  v_ids uuid[] := public._arena_pick(p_user);
  v_code text;
  d public.duels;
begin
  if coalesce(cardinality(v_ids), 0) < public._arena_rule('questions') then raise exception 'not_enough_questions'; end if;
  loop
    v_code := public._random_code(6);
    exit when not exists (select 1 from public.duels where code = v_code);
  end loop;
  insert into public.duels (code, challenger_id, opponent_id, question_ids, status, created_at, expires_at, difficulty, arena)
  values (v_code, p_user, null, v_ids, 'open', public._now(),
          public._now() + make_interval(hours => public._arena_rule('queue_hours')), 'medium', true)
  returning * into d;
  return d;
end $$;

-- Vue d'un duel classé pour un joueur. Les réponses de l'adversaire se dévoilent question par question, une fois
-- qu'on a soi-même répondu à la même question.
create or replace function public._arena_json(d public.duels, p_user uuid) returns jsonb
language plpgsql stable set search_path = public, pg_temp as $$
declare
  v_other uuid := case when p_user = d.challenger_id then d.opponent_id else d.challenger_id end;
  n int := cardinality(d.question_ids);
  me record; them record;
  v_res public.arena_results;
  v_champion uuid := public._arena_champion();
begin
  select * into me from public._duel_state(d.id, p_user);
  select * into them from public._duel_state(d.id, v_other);
  select * into v_res from public.arena_results where duel_id = d.id and user_id = p_user;
  return jsonb_build_object(
    'id', d.id, 'status', d.status, 'created_at', d.created_at, 'expires_at', d.expires_at, 'finished_at', d.finished_at,
    'total', n, 'seconds', public._arena_rule('seconds'),
    'opponent', case when v_other is null then null else jsonb_build_object(
        'id', v_other, 'handle', (select handle from public.profiles where id = v_other),
        'week_points', coalesce((select sum(points) from public.arena_results
                                 where user_id = v_other and week = public._arena_week(public._now())), 0),
        'champion', coalesce(v_other = v_champion, false),
        'answered', them.answered,
        'score', case when me.answered = n or d.status = 'finished' then them.score end,
        'total_ms', case when me.answered = n or d.status = 'finished' then them.total_ms end) end,
    'me', jsonb_build_object('answered', me.answered, 'score', me.score, 'total_ms', me.total_ms),
    'my_turn', d.status in ('open', 'active') and me.answered < n,
    'winner', case when d.status = 'finished' then case when d.winner_id is null then 'draw'
                                                        when d.winner_id = p_user then 'me' else 'opponent' end end,
    'result', case when v_res.duel_id is null then null else jsonb_build_object(
        'outcome', v_res.outcome, 'points', v_res.points, 'streak', v_res.streak, 'bonus', to_jsonb(v_res.bonus)) end);
end $$;

-- Règlement d'un duel classé terminé : points, séries, coffres, notification de celui qui n'est pas là.
create or replace function public._arena_settle(p_duel uuid) returns void
language plpgsql set search_path = public, pg_temp as $$
declare
  d public.duels;
  u uuid;
  v_other uuid;
  me record; them record;
  v_outcome text;
  v_prev int;
  v_streak int;
  v_points int;
  v_bonus text[];
  v_day date;
  v_wins_total int;
  v_week date := public._arena_week(public._now());
begin
  select * into d from public.duels where id = p_duel;
  if not d.arena or d.status <> 'finished' or d.opponent_id is null then return; end if;
  foreach u in array array[d.challenger_id, d.opponent_id] loop
    continue when exists (select 1 from public.arena_results where duel_id = d.id and user_id = u);
    v_other := case when u = d.challenger_id then d.opponent_id else d.challenger_id end;
    select * into me from public._duel_state(d.id, u);
    select * into them from public._duel_state(d.id, v_other);
    v_outcome := case when d.winner_id = u then 'win' when d.winner_id is null then 'draw' else 'loss' end;
    select r.streak into v_prev from public.arena_results r where r.user_id = u order by r.created_at desc limit 1;
    v_streak := case when v_outcome = 'win' then coalesce(v_prev, 0) + 1 else 0 end;
    v_points := public._arena_rule(v_outcome)
                + case when v_outcome = 'win' and v_streak >= public._arena_rule('streak_from')
                       then public._arena_rule('streak_bonus') else 0 end;
    v_bonus := '{}';
    if v_outcome = 'win' then
      v_day := public._paris_day(public._now());
      -- 1er duel gagné du jour : coffre d'argent.
      if public._give_chest(u, 'silver', 'arena_daily', d.id::text, 'arena_daily:' || v_day) then
        v_bonus := v_bonus || 'daily_chest'::text;
      end if;
      -- Chaque série de 5 victoires : coffre d'argent.
      if v_streak % public._arena_rule('streak_chest') = 0
         and public._give_chest(u, 'silver', 'arena_streak', d.id::text, 'arena_streak:' || d.id) then
        v_bonus := v_bonus || 'streak_chest'::text;
      end if;
      -- Coffre d'Arène : toutes les 10 victoires, un coffre en or (carte rare ou mieux).
      select count(*) + 1 into v_wins_total from public.arena_results where user_id = u and outcome = 'win';
      if v_wins_total % public._arena_rule('chest_every') = 0
         and public._give_chest(u, 'gold', 'arena_chest', d.id::text, 'arena_chest:' || v_wins_total) then
        v_bonus := v_bonus || 'arena_chest'::text;
      end if;
      if v_wins_total >= 25 then perform public._unlock(u, 'arena_wins_25'); end if;
    end if;
    insert into public.arena_results (duel_id, user_id, week, outcome, points, streak, score, opp_score, bonus, created_at)
    values (d.id, u, v_week, v_outcome, v_points, v_streak, me.score, them.score, v_bonus, public._now());
    -- Celui qui n'est pas en train de jouer apprend le résultat par notification.
    if u is distinct from auth.uid() then
      perform public._push(u, 'social', case v_outcome when 'win' then 'Duel gagné' when 'draw' then 'Égalité'
                                                       else 'Duel perdu' end,
        (select handle from public.profiles where id = v_other) || ' a joué ton duel : '
          || me.score || ' – ' || them.score || case when v_points > 0 then ', +' || v_points || ' pts.' else '. Revanche ?' end,
        jsonb_build_object('type', 'arena', 'id', d.id), 'arena_end:' || d.id || ':' || u);
    end if;
  end loop;
end $$;

-- Clôture des duels (0033), avec le règlement de l'Arène. Un duel classé dont l'adversaire a abandonné en cours de
-- route est gagné par celui qui a fini ; un duel ouvert que personne n'a pris est annulé, sans perte.
create or replace function public._duel_close(p_duel uuid) returns void
language plpgsql set search_path = public, extensions, pg_temp as $$
declare
  d public.duels;
  a record; b record;
  n int;
  v_winner uuid;
begin
  select * into d from public.duels where id = p_duel for update;
  if d.status not in ('open', 'active') then return; end if;
  n := cardinality(d.question_ids);
  select * into a from public._duel_state(d.id, d.challenger_id);
  select * into b from public._duel_state(d.id, d.opponent_id);
  if d.opponent_id is not null and a.answered = n and b.answered = n then
    v_winner := case when a.score > b.score then d.challenger_id when b.score > a.score then d.opponent_id
                     when a.total_ms < b.total_ms then d.challenger_id when b.total_ms < a.total_ms then d.opponent_id end;
  elsif d.expires_at < public._now() then
    if a.answered = n and coalesce(b.answered, 0) < n and d.opponent_id is not null then v_winner := d.challenger_id;
    elsif coalesce(b.answered, 0) = n and a.answered < n then v_winner := d.opponent_id;
    end if;
    if v_winner is null and not (a.answered = n and coalesce(b.answered, 0) = n) then
      update public.duels set status = 'expired', finished_at = public._now() where id = d.id;
      return;
    end if;
  else
    return;
  end if;
  update public.duels set status = 'finished', finished_at = public._now(), winner_id = v_winner where id = d.id;
  if d.arena then
    perform public._arena_settle(d.id);
  else
    perform public._duel_notify_end(d.id);
  end if;
  if v_winner is not null then
    perform public._grant_capped(v_winner, 'xp', 20, 200, 'duel_win', d.id::text, 'duel_win_xp:' || d.id);
    perform public._grant_capped(v_winner, 'seeds', 5, 20, 'duel_win', d.id::text, 'duel_win_seeds:' || d.id);
  end if;
end $$;

-- Ferme les duels classés du joueur arrivés à échéance.
create or replace function public._arena_close_mine(p_user uuid) returns void
language plpgsql set search_path = public, pg_temp as $$
declare r record;
begin
  for r in select id from public.duels where arena and p_user in (challenger_id, opponent_id)
             and status in ('open', 'active') and expires_at < public._now() loop
    perform public._duel_close(r.id);
  end loop;
end $$;

-- « Trouver un adversaire ».
create or replace function public.arena_find() returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  n int := public._arena_rule('questions');
  d public.duels;
  v_last uuid;
  st record;
begin
  perform public._arena_close_mine(v_user);
  -- Un duel classé commencé et pas fini : on le reprend.
  select dd.* into d from public.duels dd
  where dd.arena and v_user in (dd.challenger_id, dd.opponent_id) and dd.status in ('open', 'active')
    and (select count(*) from public.duel_answers a where a.duel_id = dd.id and a.user_id = v_user and a.answered_at is not null) < n
  order by dd.created_at desc limit 1;
  if found then
    return jsonb_build_object('duel', public._arena_json(d, v_user), 'matched', d.opponent_id is not null, 'resumed', true);
  end if;
  if (select count(*) from public.duels where arena and v_user in (challenger_id, opponent_id)
        and created_at > public._now() - interval '1 day') >= public._arena_rule('daily_limit') then
    raise exception 'rate_limited';
  end if;

  -- Dernier adversaire : on évite de retomber sur lui tout de suite.
  select case when dd.challenger_id = v_user then dd.opponent_id else dd.challenger_id end into v_last
  from public.duels dd where dd.arena and v_user in (dd.challenger_id, dd.opponent_id) and dd.opponent_id is not null
  order by dd.created_at desc limit 1;

  -- Le duel ouvert le plus ancien d'un autre joueur, joué en entier (ou abandonné depuis 15 min) ; le premier qui le
  -- prend le garde (les autres passent au suivant sans attendre).
  select dd.* into d from public.duels dd
  where dd.arena and dd.status = 'open' and dd.opponent_id is null and dd.challenger_id <> v_user
    and dd.expires_at > public._now()
    and ((select count(*) from public.duel_answers a where a.duel_id = dd.id and a.user_id = dd.challenger_id
                                                     and a.answered_at is not null) = n
         or dd.created_at < public._now() - make_interval(mins => public._arena_rule('abandon_minutes')))
    and not exists (select 1 from public.friendships f
                    where f.user_low = least(v_user, dd.challenger_id) and f.user_high = greatest(v_user, dd.challenger_id)
                      and f.status = 'blocked')
    and not exists (select 1 from public.profiles p where p.id = dd.challenger_id and p.banned_at is not null)
  order by dd.challenger_id is not distinct from v_last, dd.created_at
  limit 1
  for update skip locked;

  if found then
    -- Questions laissées sans réponse par un joueur parti : fausses, au temps maximum.
    insert into public.duel_answers (duel_id, user_id, position, question_id, served_at, answered_at, given, is_correct, counted_ms)
    select d.id, d.challenger_id, g.pos, d.question_ids[g.pos], public._now(), public._now(), null, false,
           (public._arena_rule('seconds') * 1000)
    from generate_series(1, n) g(pos)
    on conflict (duel_id, user_id, position) do update
      set answered_at = coalesce(duel_answers.answered_at, excluded.answered_at),
          is_correct = coalesce(duel_answers.is_correct, false),
          counted_ms = coalesce(duel_answers.counted_ms, excluded.counted_ms);
    update public.duels set opponent_id = v_user, status = 'active',
      expires_at = public._now() + make_interval(mins => public._arena_rule('play_minutes'))
    where id = d.id returning * into d;
    return jsonb_build_object('duel', public._arena_json(d, v_user), 'matched', true, 'resumed', false);
  end if;

  d := public._arena_new(v_user);
  return jsonb_build_object('duel', public._arena_json(d, v_user), 'matched', false, 'resumed', false);
end $$;

-- Question d'un duel classé. `them_ms` : temps de l'adversaire sur cette question s'il y a déjà répondu (pas sa réponse).
create or replace function public.arena_question(p_duel uuid, p_position int) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  d public.duels := public._duel_for_player(p_duel, v_user);
  v_other uuid := case when v_user = d.challenger_id then d.opponent_id else d.challenger_id end;
  st record;
  q public.questions;
  v_them public.duel_answers;
begin
  if not d.arena then raise exception 'duel_not_found'; end if;
  if d.expires_at < public._now() then perform public._duel_close(d.id); return jsonb_build_object('expired', true); end if;
  if d.status not in ('open', 'active') then return jsonb_build_object('expired', true); end if;
  select * into st from public._duel_state(d.id, v_user);
  if p_position <> st.answered + 1 or p_position > cardinality(d.question_ids) then raise exception 'duel_out_of_order'; end if;
  insert into public.duel_answers (duel_id, user_id, position, question_id, served_at)
  values (d.id, v_user, p_position, d.question_ids[p_position], public._now())
  on conflict (duel_id, user_id, position) do nothing;
  select * into q from public.questions where id = d.question_ids[p_position];
  select * into v_them from public.duel_answers where duel_id = d.id and user_id = v_other and position = p_position
    and answered_at is not null;
  return public._question_public(q, d.id::text) || jsonb_build_object(
    'position', p_position, 'total', cardinality(d.question_ids), 'seconds', public._arena_rule('seconds'),
    'served_at', (select served_at from public.duel_answers where duel_id = d.id and user_id = v_user and position = p_position),
    'them_ms', v_them.counted_ms);
end $$;

-- Réponse : chrono tenu par le serveur (trop tard = faux). Renvoie la correction, et ce qu'a fait l'adversaire sur la
-- même question s'il y a déjà répondu.
create or replace function public.arena_answer(p_duel uuid, p_position int, p_given jsonb, p_client_ms int) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  d public.duels := public._duel_for_player(p_duel, v_user);
  v_other uuid := case when v_user = d.challenger_id then d.opponent_id else d.challenger_id end;
  n int := cardinality(d.question_ids);
  a public.duel_answers;
  q public.questions;
  v_server_ms int; v_counted int; v_late bool;
  v_res jsonb;
  v_correct bool;
  v_done bool;
  v_them public.duel_answers;
  me record;
begin
  if not d.arena then raise exception 'duel_not_found'; end if;
  select * into a from public.duel_answers where duel_id = d.id and user_id = v_user and position = p_position for update;
  if not found then raise exception 'duel_not_served'; end if;
  select * into q from public.questions where id = a.question_id;
  if a.answered_at is null then
    if d.status not in ('open', 'active') then raise exception 'duel_closed'; end if;
    v_server_ms := floor(extract(epoch from public._now() - a.served_at) * 1000)::int;
    v_late := v_server_ms > (public._arena_rule('seconds') + public._arena_rule('grace')) * 1000;
    v_counted := least(v_server_ms, greatest(coalesce(p_client_ms, v_server_ms), v_server_ms - 2000));
    v_counted := least(greatest(v_counted, 300), public._arena_rule('seconds') * 1000);
    -- Hors Elo, comme les autres duels : XP, erreurs à revoir et statistiques.
    v_res := public._record_attempt(v_user, q.id, case when v_late then null else p_given end, v_counted, 'challenge', d.id,
                                    md5(d.id::text || ':' || v_user || ':' || p_position)::uuid, false);
    v_correct := (v_res ->> 'is_correct')::bool and not v_late;
    update public.duel_answers set answered_at = public._now(), given = p_given, is_correct = v_correct, counted_ms = v_counted
    where duel_id = d.id and user_id = v_user and position = p_position
    returning * into a;
    if v_correct then
      perform public._grant_capped(v_user, 'xp', 5, 300, 'duel_correct', d.id::text,
                                   'duel_correct:' || d.id || ':' || v_user || ':' || p_position);
    end if;
    v_done := p_position = n;
    if v_done then perform public._duel_close(d.id); end if;
  end if;
  select * into v_them from public.duel_answers where duel_id = d.id and user_id = v_other and position = p_position
    and answered_at is not null;
  select * into me from public._duel_state(d.id, v_user);
  return jsonb_build_object(
      'position', p_position, 'is_correct', a.is_correct, 'counted_ms', a.counted_ms, 'late', coalesce(v_late, false),
      'finished', p_position = n, 'error_transition', v_res -> 'error_transition',
      'my_score', me.score,
      'them', case when v_them.duel_id is null then null
                   else jsonb_build_object('is_correct', v_them.is_correct, 'counted_ms', v_them.counted_ms) end,
      'them_score', (select count(*) filter (where is_correct) from public.duel_answers
                     where duel_id = d.id and user_id = v_other and position <= p_position))
    || public._question_reveal(q);
end $$;

-- Bilan d'un duel classé.
create or replace function public.arena_result(p_duel uuid) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  d public.duels := public._duel_for_player(p_duel, v_user);
  v_other uuid;
  v_mine int;
  v_week date := public._arena_week(public._now());
begin
  if not d.arena then raise exception 'duel_not_found'; end if;
  perform public._duel_close(d.id);
  select * into d from public.duels where id = p_duel;
  v_other := case when v_user = d.challenger_id then d.opponent_id else d.challenger_id end;
  select answered into v_mine from public._duel_state(d.id, v_user);
  return public._arena_json(d, v_user) || jsonb_build_object(
    'my_answers', coalesce((select jsonb_agg(jsonb_build_object('position', position, 'is_correct', is_correct, 'counted_ms', counted_ms)
                                             order by position)
                            from public.duel_answers where duel_id = d.id and user_id = v_user and answered_at is not null), '[]'::jsonb),
    'their_answers', case when v_mine = cardinality(d.question_ids) or d.status = 'finished' then coalesce((
                            select jsonb_agg(jsonb_build_object('position', position, 'is_correct', is_correct, 'counted_ms', counted_ms)
                                             order by position)
                            from public.duel_answers where duel_id = d.id and user_id = v_other and answered_at is not null), '[]'::jsonb) end,
    'week', (select jsonb_build_object('points', s.points, 'rank', s.rank, 'duels', s.duels, 'eligible', s.eligible)
             from public._arena_standings(v_week) s where s.user_id = v_user),
    'chest_progress', (select count(*) % public._arena_rule('chest_every') from public.arena_results
                       where user_id = v_user and outcome = 'win'),
    'chest_every', public._arena_rule('chest_every'));
end $$;

-- Fin de semaine : chacun reçoit les récompenses de sa place, une seule fois. Appelée par la tâche horaire et, par
-- sécurité, à l'ouverture de l'Arène.
create or replace function public._arena_close_week(p_week date) returns int
language plpgsql set search_path = public, pg_temp as $$
declare
  s record;
  v_prize jsonb;
  v_card text;
  v_n int := 0;
  i int;
begin
  if public._now() < public._arena_week_end(p_week) then return 0; end if;
  perform pg_advisory_xact_lock(hashtext('arena_week:' || p_week));
  if exists (select 1 from public.arena_week_rewards where week = p_week) then return 0; end if;
  for s in select * from public._arena_standings(p_week) order by rank loop
    v_prize := public._arena_prize(s.rank, s.eligible);
    insert into public.arena_week_rewards (week, user_id, rank, points, wins, duels, eligible, prizes, created_at)
    values (p_week, s.user_id, s.rank, s.points, s.wins, s.duels, s.eligible, v_prize, public._now());
    for i in 1 .. coalesce((v_prize ->> 'gold')::int, 0) loop
      perform public._give_chest(s.user_id, 'gold', 'arena_week', p_week::text, 'arena_week:' || p_week || ':gold:' || i);
    end loop;
    for i in 1 .. coalesce((v_prize ->> 'silver')::int, 0) loop
      perform public._give_chest(s.user_id, 'silver', 'arena_week', p_week::text, 'arena_week:' || p_week || ':silver:' || i);
    end loop;
    for i in 1 .. coalesce((v_prize ->> 'wood')::int, 0) loop
      perform public._give_chest(s.user_id, 'wood', 'arena_week', p_week::text, 'arena_week:' || p_week || ':wood:' || i);
    end loop;
    if (v_prize ->> 'seeds') is not null then
      perform public._grant(s.user_id, 'seeds', (v_prize ->> 'seeds')::int, 'arena_week', p_week::text, 'arena_week_seeds:' || p_week);
    end if;
    if (v_prize ->> 'packs') is not null then
      perform public._album_row(s.user_id);
      update public.user_album set tickets = tickets + (v_prize ->> 'packs')::int where user_id = s.user_id;
    end if;
    if (v_prize ->> 'card') is not null then
      perform public._album_row(s.user_id);
      select ac.id into v_card from public.album_cards ac
      where ac.rarity = (v_prize ->> 'card')::public.card_rarity
      order by (exists (select 1 from public.user_cards uc where uc.user_id = s.user_id and uc.slot = 0 and uc.card_id = ac.id)),
               random()
      limit 1;
      if v_card is not null then
        update public.arena_week_rewards set prizes = prizes || jsonb_build_object(
            'card_pull', public._album_receive(s.user_id, 0::smallint, v_card, 'arena_week_card:' || p_week))
        where week = p_week and user_id = s.user_id;
      end if;
    end if;
    if (v_prize ->> 'trophy') is not null then
      perform public._unlock(s.user_id, v_prize ->> 'trophy');
      if v_prize ->> 'trophy' = 'arena_champion' then perform public._unlock(s.user_id, 'arena_podium'); end if;
    end if;
    if (v_prize ->> 'cosmetic') is not null then
      insert into public.user_cosmetics (user_id, item_id, source) values (s.user_id, v_prize ->> 'cosmetic', 'arena')
      on conflict do nothing;
    end if;
    perform public._push(s.user_id, 'social',
      case when s.rank = 1 and s.eligible then 'Champion de l''Arène !' else 'Fin de semaine dans l''Arène' end,
      case when s.eligible and s.rank <= 15 then 'Tu finis ' || s.rank || case when s.rank = 1 then 'er' else 'e' end
                                                 || ' avec ' || s.points || ' pts. Viens chercher tes récompenses !'
           else 'Ton coffre de la semaine t''attend. Nouvelle semaine, nouveau classement !' end,
      jsonb_build_object('type', 'arena_week', 'week', p_week), 'arena_week:' || p_week || ':' || s.user_id);
    v_n := v_n + 1;
  end loop;
  return v_n;
end $$;

create or replace function public.cron_arena() returns int
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_n int := 0; r record;
begin
  v_n := public._arena_close_week(public._arena_week(public._now()) - 7);
  -- Duels classés arrivés à échéance (personne ne les rouvrira).
  for r in select id from public.duels where arena and status in ('open', 'active') and expires_at < public._now() limit 500 loop
    perform public._duel_close(r.id);
  end loop;
  return v_n;
end $$;

-- Ligne de classement publique.
create or replace function public._arena_row(p_user uuid, p_rank int, p_points int, p_wins int, p_duels int, p_eligible bool,
                                             p_me uuid, p_champion uuid) returns jsonb
language sql stable set search_path = public, pg_temp as $$
  select jsonb_build_object('rank', p_rank, 'id', p_user, 'handle', p.handle, 'points', p_points, 'wins', p_wins,
                            'duels', p_duels, 'eligible', p_eligible, 'me', p_user = p_me,
                            'champion', coalesce(p_user = p_champion, false))
  from public.profiles p where p.id = p_user
$$;

-- Tout l'écran de l'Arène en un appel.
create or replace function public.arena_overview() returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  v_week date := public._arena_week(public._now());
  v_champion uuid;
  me record;
  v_streak int;
  v_wins int;
  v_reward public.arena_week_rewards;
  v_top jsonb;
  v_open int;
begin
  perform public._arena_close_week(v_week - 7);
  perform public._arena_close_mine(v_user);
  v_champion := public._arena_champion();
  select * into me from public._arena_standings(v_week) s where s.user_id = v_user;
  select r.streak into v_streak from public.arena_results r where r.user_id = v_user order by r.created_at desc limit 1;
  select count(*) into v_wins from public.arena_results where user_id = v_user and outcome = 'win';
  select * into v_reward from public.arena_week_rewards
  where user_id = v_user and seen_at is null and week >= v_week - 28 order by week desc limit 1;
  select coalesce(jsonb_agg(public._arena_row(s.user_id, s.rank, s.points, s.wins, s.duels, s.eligible, v_user, v_champion)
                            order by s.rank), '[]'::jsonb)
    into v_top from public._arena_standings(v_week) s where s.rank <= 3;
  -- Duels qui attendent un adversaire (hors les siens) : « un adversaire t'attend ».
  select count(*) into v_open from public.duels dd
  where dd.arena and dd.status = 'open' and dd.opponent_id is null and dd.challenger_id <> v_user and dd.expires_at > public._now();
  return jsonb_build_object(
    'week', v_week, 'ends_at', public._arena_week_end(v_week),
    'me', jsonb_build_object('points', coalesce(me.points, 0), 'wins', coalesce(me.wins, 0), 'duels', coalesce(me.duels, 0),
                             'rank', me.rank, 'eligible', coalesce(me.eligible, false),
                             'min_duels', public._arena_rule('min_duels'), 'champion', coalesce(v_user = v_champion, false)),
    'players', (select count(*) from public._arena_standings(v_week)),
    'top', v_top,
    'champion', case when v_champion is null then null
                     else jsonb_build_object('id', v_champion, 'handle', (select handle from public.profiles where id = v_champion)) end,
    'streak', coalesce(v_streak, 0),
    'wins_total', v_wins,
    'chest', jsonb_build_object('progress', v_wins % public._arena_rule('chest_every'), 'goal', public._arena_rule('chest_every')),
    'daily_chest', not exists (select 1 from public.user_chests where user_id = v_user
                               and idempotency_key = 'arena_daily:' || public._paris_day(public._now())),
    'waiting', v_open,
    'prizes', public._arena_prizes_table(),
    'rules', jsonb_build_object('questions', public._arena_rule('questions'), 'seconds', public._arena_rule('seconds'),
                                'win', public._arena_rule('win'), 'draw', public._arena_rule('draw'),
                                'streak_from', public._arena_rule('streak_from'), 'streak_chest', public._arena_rule('streak_chest')),
    'reward', case when v_reward.week is null then null else jsonb_build_object(
        'week', v_reward.week, 'rank', v_reward.rank, 'points', v_reward.points, 'eligible', v_reward.eligible,
        'prizes', v_reward.prizes) end,
    'duels', coalesce((select jsonb_agg(public._arena_json(dd, v_user) order by dd.created_at desc)
                       from (select * from public.duels dd where dd.arena and v_user in (dd.challenger_id, dd.opponent_id)
                               and dd.status <> 'expired' order by dd.created_at desc limit 15) dd), '[]'::jsonb));
end $$;

-- Classements : semaine (tous), amis (semaine), depuis toujours (victoires).
create or replace function public.arena_leaderboard(p_scope text default 'week') returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  v_week date := public._arena_week(public._now());
  v_champion uuid := public._arena_champion();
  v_rows jsonb;
  v_me jsonb;
begin
  if p_scope = 'all' then
    with s as (
      select r.user_id, count(*) filter (where r.outcome = 'win')::int as wins, count(*)::int as duels,
             sum(r.points)::int as points, max(r.created_at) as last_at
      from public.arena_results r where public._real_player(r.user_id) group by r.user_id
    ), ranked as (
      select s.*, (row_number() over (order by s.wins desc, s.points desc, s.last_at))::int as rank from s
    )
    select coalesce(jsonb_agg(public._arena_row(user_id, rank, points, wins, duels, true, v_user, v_champion) order by rank)
                    filter (where rank <= 100), '[]'::jsonb),
           (array_agg(public._arena_row(user_id, rank, points, wins, duels, true, v_user, v_champion)) filter (where user_id = v_user))[1]
      into v_rows, v_me from ranked;
  elsif p_scope = 'friends' then
    with f as (
      select v_user as id
      union select case when requester_id = v_user then addressee_id else requester_id end
      from public.friendships where status = 'accepted' and v_user in (requester_id, addressee_id)
    ), s as (
      select f.id as user_id, coalesce(sum(r.points), 0)::int as points,
             (count(r.*) filter (where r.outcome = 'win'))::int as wins, count(r.*)::int as duels, max(r.created_at) as last_at
      from f left join public.arena_results r on r.user_id = f.id and r.week = v_week
      group by f.id
    ), ranked as (
      select s.*, (row_number() over (order by s.points desc, s.wins desc, s.last_at nulls last))::int as rank from s
    )
    select coalesce(jsonb_agg(public._arena_row(user_id, rank, points, wins, duels, duels >= public._arena_rule('min_duels'),
                                                v_user, v_champion) order by rank), '[]'::jsonb),
           (array_agg(public._arena_row(user_id, rank, points, wins, duels, duels >= public._arena_rule('min_duels'),
                                        v_user, v_champion)) filter (where user_id = v_user))[1]
      into v_rows, v_me from ranked;
  else
    select coalesce(jsonb_agg(public._arena_row(s.user_id, s.rank, s.points, s.wins, s.duels, s.eligible, v_user, v_champion)
                              order by s.rank) filter (where s.rank <= 100), '[]'::jsonb),
           (array_agg(public._arena_row(s.user_id, s.rank, s.points, s.wins, s.duels, s.eligible, v_user, v_champion))
              filter (where s.user_id = v_user))[1]
      into v_rows, v_me from public._arena_standings(v_week) s;
  end if;
  return jsonb_build_object('scope', coalesce(p_scope, 'week'), 'week', v_week, 'ends_at', public._arena_week_end(v_week),
                            'rows', v_rows, 'me', v_me, 'min_duels', public._arena_rule('min_duels'),
                            'prizes', public._arena_prizes_table());
end $$;

create or replace function public.arena_reward_seen(p_week date) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user();
begin
  update public.arena_week_rewards set seen_at = public._now() where user_id = v_user and week = p_week and seen_at is null;
end $$;

-- Les duels classés ne se rejoignent pas par un code, ne se refusent pas et restent hors de la liste des duels entre amis.
create or replace function public.duel_join(p_code text) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  d public.duels;
begin
  select * into d from public.duels where code = upper(trim(p_code)) and not arena for update;
  if not found then raise exception 'duel_not_found'; end if;
  if d.challenger_id = v_user or d.opponent_id = v_user then return public._duel_json(d, v_user); end if;
  if d.opponent_id is not null then raise exception 'duel_taken'; end if;
  if d.status <> 'open' or d.expires_at < public._now() then raise exception 'duel_closed'; end if;
  update public.duels set opponent_id = v_user, status = 'active' where id = d.id returning * into d;
  perform public._push(d.challenger_id, 'social', 'Défi relevé',
    (select handle from public.profiles where id = v_user) || ' a relevé ton défi. Qui va gagner ?',
    jsonb_build_object('type', 'duel', 'id', d.id), 'duel_join:' || d.id);
  return public._duel_json(d, v_user);
end $$;

create or replace function public.duel_decline(p_duel uuid) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user();
begin
  update public.duels set status = 'declined', finished_at = public._now()
  where id = p_duel and opponent_id = v_user and status = 'active' and not arena
    and not exists (select 1 from public.duel_answers where duel_id = p_duel and user_id = v_user);
  if not found then raise exception 'duel_not_found'; end if;
end $$;

create or replace function public.duels_mine() returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user(); r record;
begin
  for r in select id from public.duels where v_user in (challenger_id, opponent_id) and status in ('open', 'active')
                                         and expires_at < public._now() and not arena loop
    perform public._duel_close(r.id);
  end loop;
  return coalesce((select jsonb_agg(public._duel_json(d, v_user) order by d.created_at desc)
                   from public.duels d where v_user in (d.challenger_id, d.opponent_id) and not d.arena
                     and d.created_at > public._now() - interval '30 days' and d.status <> 'declined'), '[]'::jsonb);
end $$;

-- Les fonctions des duels entre amis refusent les duels classés (qui ont leur chrono et leur règlement).
create or replace function public._not_arena(p_duel uuid) returns bool
language plpgsql stable set search_path = public, pg_temp as $$
begin
  if exists (select 1 from public.duels where id = p_duel and arena) then raise exception 'duel_not_found'; end if;
  return true;
end $$;

do $$
declare f record; v_old text; v_new text;
begin
  for f in select p.oid, p.proname from pg_proc p where p.pronamespace = 'public'::regnamespace
             and p.proname in ('duel_question', 'duel_answer', 'duel_rematch') loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(v_old, 'public._duel_for_player(p_duel, v_user);',
                     'public._duel_for_player(p_duel, v_user);
  -- 0088 : un duel classé se joue par arena_question / arena_answer.
  _arena_guard bool := public._not_arena(p_duel);');
    if f.proname = 'duel_rematch' then
      v_new := replace(v_old, 'if not found then raise exception ''duel_not_found''; end if;
  v_other',
                       'if not found or d.arena then raise exception ''duel_not_found''; end if;
  v_other');
    end if;
    if v_new = v_old then raise exception '0088: % inchangée', f.proname; end if;
    execute v_new;
  end loop;
end $$;

-- Missions d'Arène : « Joue un duel classé » (jour), « Gagne 3 duels classés » (semaine). Elles mènent à l'Arène.
-- L'app 1.5 envoie l'en-tête « x-brainlix-arena » : les anciennes versions ne reçoivent pas ces missions.
create or replace function public._client_arena() returns bool
language sql stable set search_path = public, pg_temp as $$
  select coalesce(nullif(current_setting('request.headers', true), '')::jsonb ->> 'x-brainlix-arena', '') >= '1'
$$;

do $$
declare v_old text; v_new text;
begin
  v_old := pg_get_functiondef('public._quest_progress(uuid, text, text, date, date)'::regprocedure);
  v_new := replace(v_old, '    when ''answers'' then',
    '    when ''arena_duels'' then (select count(*) from public.arena_results
                              where user_id = p_user and created_at >= v_from and created_at < v_to)
    when ''arena_wins'' then (select count(*) from public.arena_results
                             where user_id = p_user and outcome = ''win'' and created_at >= v_from and created_at < v_to)
    when ''answers'' then');
  if v_new = v_old then raise exception '0088: _quest_progress inchangée'; end if;
  execute v_new;

  v_old := pg_get_functiondef('public._quest_goal(text)'::regprocedure);
  v_new := replace(v_old, '    when ''errors_corrected'' then ''errors''',
    '    when ''errors_corrected'' then ''errors''
    when ''arena_duels'' then ''duels''
    when ''arena_wins'' then ''duels''');
  if v_new = v_old then raise exception '0088: _quest_goal inchangée'; end if;
  execute v_new;

  v_old := pg_get_functiondef('public._quests_ensure(uuid, text, date)'::regprocedure);
  v_new := replace(replace(replace(v_old,
    '        (''answers'', null, 20, ''Réponds à 20 questions'', false),',
    '        (''answers'', null, 20, ''Réponds à 20 questions'', false),
        (''arena_duels'', null, 1, ''Joue un duel classé dans l''''Arène'', false),'),
    '        (''domains_played'', null, 4, ''Joue dans 4 domaines différents'', false),',
    '        (''domains_played'', null, 4, ''Joue dans 4 domaines différents'', false),
        (''arena_wins'', null, 3, ''Gagne 3 duels classés'', false),'),
    -- Missions d'Arène seulement pour une app qui a l'Arène (1.5 et après).
    '    select * from pool order by',
    '    select * from pool where (pool.metric not like ''arena%'' or public._client_arena()) order by');
  if v_new = v_old or v_new not like '%arena_wins%' or v_new not like '%arena_duels%' or v_new not like '%_client_arena()%' then
    raise exception '0088: _quests_ensure inchangée';
  end if;
  execute v_new;
end $$;

revoke execute on function public._arena_rule(text), public._arena_week(timestamptz), public._arena_week_end(date),
  public._arena_prize(int, bool), public._arena_prizes_table(), public._arena_standings(date), public._arena_champion(),
  public._arena_pick(uuid), public._arena_new(uuid), public._arena_json(public.duels, uuid), public._arena_settle(uuid),
  public._arena_close_mine(uuid), public._arena_close_week(date), public.cron_arena(),
  public._arena_row(uuid, int, int, int, int, bool, uuid, uuid), public._not_arena(uuid), public._client_arena()
  from public, anon, authenticated;
revoke execute on function public.arena_find(), public.arena_question(uuid, int), public.arena_answer(uuid, int, jsonb, int),
  public.arena_result(uuid), public.arena_overview(), public.arena_leaderboard(text), public.arena_reward_seen(date)
  from public, anon;
grant execute on function public.arena_find(), public.arena_question(uuid, int), public.arena_answer(uuid, int, jsonb, int),
  public.arena_result(uuid), public.arena_overview(), public.arena_leaderboard(text), public.arena_reward_seen(date)
  to authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('brainlix-arena', '4 * * * *', 'select public.cron_arena()');
  end if;
exception when others then
  raise notice 'pg_cron indisponible : semaine de l''Arène close à l''ouverture de l''Arène seulement (%)', sqlerrm;
end $$;
