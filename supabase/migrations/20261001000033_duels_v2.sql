-- Brainlix — 0033 Duels personnalisés, face-à-face, profil d'un ami
-- 1. Duel réglable : 5, 10, 15 ou 20 questions ; tous les domaines ou certains ; difficulté automatique (calée sur le
--    niveau moyen des deux joueurs) ou choisie (facile, moyenne, difficile). Mêmes règles qu'avant : mêmes questions,
--    dans l'ordre, temps officiel serveur, 48 h pour jouer, score adverse révélé après sa propre partie.
-- 2. Les duels ne changent plus l'Elo (sélection libre des domaines et de la difficulté) : les réponses gardent XP,
--    erreurs à revoir et statistiques. Réponses déjà enregistrées inchangées.
-- 3. Revanche : même adversaire, mêmes réglages, nouvelles questions.
-- 4. Profil d'un ami (réservé aux amis) : son 5 du jour, son Elo, et notre face-à-face calculé depuis tous les duels.

alter table public.duels drop constraint duels_question_ids_check;
alter table public.duels add constraint duels_question_ids_check check (cardinality(question_ids) between 5 and 20);
alter table public.duel_answers drop constraint duel_answers_position_check;
alter table public.duel_answers add constraint duel_answers_position_check check (position between 1 and 20);
alter table public.duels
  add column domains    text[],
  add column difficulty text not null default 'auto' check (difficulty in ('auto', 'easy', 'medium', 'hard')),
  add column rematch_of uuid references public.duels(id) on delete set null;
create index if not exists duels_pair on public.duels (least(challenger_id, opponent_id), greatest(challenger_id, opponent_id), created_at desc)
  where opponent_id is not null;

-- Niveau global d'un joueur (0–100) : moyenne de ses domaines pondérée par le nombre de réponses ; 50 sans historique.
create or replace function public._overall_mu(p_user uuid) returns real
language sql stable as $$
  select coalesce(sum(s.mu * s.n) / nullif(sum(s.n), 0), 50)::real
  from public.user_skills s join public.domains d on d.id = s.scope_id
  where s.user_id = p_user and s.n > 0
$$;

-- Tirage des questions d'un duel : réparties entre les domaines demandés, dans la fenêtre de difficulté, jamais déjà
-- vues par l'un des deux joueurs si possible, jamais une question d'un 5 du jour protégé. Rangées de la plus facile à
-- la plus dure.
create or replace function public._duel_pick(p_a uuid, p_b uuid, p_count int, p_domains text[], p_difficulty text)
returns uuid[] language plpgsql volatile as $$
declare
  v_target real := case when p_b is null then public._overall_mu(p_a)
                        else (public._overall_mu(p_a) + public._overall_mu(p_b)) / 2 end;
  v_lo real;
  v_hi real;
  v_ids uuid[];
begin
  select lo, hi into v_lo, v_hi from (values
    ('easy', 15::real, 40::real), ('medium', 38, 62), ('hard', 60, 92),
    ('auto', greatest(v_target - 12, 15), least(v_target + 12, 90))) t(k, lo, hi)
  where k = p_difficulty;
  select array_agg(id order by d, id) into v_ids from (
    select id, d from (
      select q.id, q.difficulty_effective as d,
             row_number() over (partition by q.domain_id
                                order by (q.difficulty_effective between v_lo and v_hi) desc,
                                         exists (select 1 from public.question_attempts a
                                                 where a.question_id = q.id and a.user_id in (p_a, p_b)),
                                         abs(q.difficulty_effective - (v_lo + v_hi) / 2) > (v_hi - v_lo) / 2,
                                         random()) as rn
      from public.questions q
      where q.status = 'published' and q.type <> 'map_pick'
        and (p_domains is null or q.domain_id = any (p_domains))
        and q.id <> all (public._protected_daily_questions())
    ) t
    order by rn, random()
    limit p_count
  ) s;
  return v_ids;
end $$;

-- Création interne (duel, défi par lien, revanche).
create or replace function public._duel_new(p_user uuid, p_opponent uuid, p_count int, p_domains text[], p_difficulty text,
                                            p_rematch_of uuid) returns public.duels
language plpgsql as $$
declare
  v_ids uuid[];
  v_code text;
  v_domains text[];
  d public.duels;
begin
  if p_count not in (5, 10, 15, 20) then raise exception 'invalid_count'; end if;
  if coalesce(p_difficulty, 'auto') not in ('auto', 'easy', 'medium', 'hard') then raise exception 'invalid_difficulty'; end if;
  if (select count(*) from public.duels where challenger_id = p_user and created_at > public._now() - interval '1 day') >= 20 then
    raise exception 'rate_limited';
  end if;
  -- Domaines : uniquement des domaines actifs ; vide ou tous = « tous les domaines ».
  select array_agg(id order by sort) into v_domains from public.domains where is_active and id = any (coalesce(p_domains, '{}'));
  if v_domains is not null and cardinality(v_domains) = (select count(*) from public.domains where is_active) then v_domains := null; end if;
  v_ids := public._duel_pick(p_user, p_opponent, p_count, v_domains, coalesce(p_difficulty, 'auto'));
  if coalesce(cardinality(v_ids), 0) < p_count then raise exception 'not_enough_questions'; end if;
  loop
    v_code := public._random_code(6);
    exit when not exists (select 1 from public.duels where code = v_code);
  end loop;
  insert into public.duels (code, challenger_id, opponent_id, question_ids, status, created_at, expires_at,
                            domains, difficulty, rematch_of)
  values (v_code, p_user, p_opponent, v_ids, case when p_opponent is null then 'open' else 'active' end,
          public._now(), public._now() + interval '48 hours', v_domains, coalesce(p_difficulty, 'auto'), p_rematch_of)
  returning * into d;
  return d;
end $$;

-- Clôture : quand les deux ont fini, ou à l'expiration (celui qui a joué gagne ; personne → expiré).
create or replace function public._duel_close(p_duel uuid) returns void
language plpgsql as $$
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
  n int := cardinality(d.question_ids);
  me record; them record;
begin
  select * into me from public._duel_state(d.id, p_user);
  select * into them from public._duel_state(d.id, v_other);
  return jsonb_build_object(
    'id', d.id, 'code', d.code, 'status', d.status, 'created_at', d.created_at, 'expires_at', d.expires_at,
    'total', n, 'domains', to_jsonb(d.domains), 'difficulty', d.difficulty,
    'i_am_challenger', p_user = d.challenger_id,
    'opponent', case when v_other is null then null else jsonb_build_object(
        'id', v_other, 'handle', (select handle from public.profiles where id = v_other),
        'answered', them.answered,
        'score', case when me.answered = n or d.status = 'finished' then them.score end,
        'total_ms', case when me.answered = n or d.status = 'finished' then them.total_ms end) end,
    'me', jsonb_build_object('answered', me.answered, 'score', me.score, 'total_ms', me.total_ms),
    'my_turn', d.status in ('open', 'active') and me.answered < n,
    'winner', case when d.status = 'finished' then case when d.winner_id is null then 'draw'
                                                        when d.winner_id = p_user then 'me' else 'opponent' end end);
end $$;

drop function public.duel_create(uuid);
create or replace function public.duel_create(p_friend uuid default null, p_count int default 5, p_domains text[] default null,
                                              p_difficulty text default 'auto') returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  d public.duels;
begin
  if p_friend is not null and not public._are_friends(v_user, p_friend) then raise exception 'not_friends'; end if;
  d := public._duel_new(v_user, p_friend, coalesce(p_count, 5), p_domains, p_difficulty, null);
  return public._duel_json(d, v_user);
end $$;

-- Revanche : même adversaire, mêmes réglages, nouvelles questions (aussi après un défi par lien).
create or replace function public.duel_rematch(p_duel uuid) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  d public.duels;
  v_other uuid;
  r public.duels;
begin
  select * into d from public.duels where id = p_duel and v_user in (challenger_id, opponent_id);
  if not found then raise exception 'duel_not_found'; end if;
  v_other := case when v_user = d.challenger_id then d.opponent_id else d.challenger_id end;
  if v_other is null then raise exception 'duel_not_found'; end if;
  if exists (select 1 from public.friendships where user_low = least(v_user, v_other) and user_high = greatest(v_user, v_other)
             and status = 'blocked') then
    raise exception 'duel_not_found';
  end if;
  r := public._duel_new(v_user, v_other, cardinality(d.question_ids), d.domains, d.difficulty, d.id);
  return public._duel_json(r, v_user);
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
  if p_position <> st.answered + 1 or p_position > cardinality(d.question_ids) then raise exception 'duel_out_of_order'; end if;
  insert into public.duel_answers (duel_id, user_id, position, question_id, served_at)
  values (d.id, v_user, p_position, d.question_ids[p_position], public._now())
  on conflict (duel_id, user_id, position) do nothing;
  select * into q from public.questions where id = d.question_ids[p_position];
  return public._question_public(q, d.id::text) || jsonb_build_object('position', p_position, 'total', cardinality(d.question_ids));
end $$;

create or replace function public.duel_answer(p_duel uuid, p_position int, p_given jsonb, p_client_ms int) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  d public.duels := public._duel_for_player(p_duel, v_user);
  n int := cardinality(d.question_ids);
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
                              'finished', p_position = n) || public._question_reveal(q);
  end if;
  if d.status not in ('open', 'active') then raise exception 'duel_closed'; end if;

  v_server_ms := floor(extract(epoch from public._now() - a.served_at) * 1000)::int;
  v_counted := least(v_server_ms, greatest(coalesce(p_client_ms, v_server_ms), v_server_ms - 2000));
  v_counted := least(greatest(v_counted, 300), 120000);
  -- Hors Elo (p_ranked = false) : les réponses gardent XP, erreurs à revoir et statistiques.
  v_res := public._record_attempt(v_user, q.id, p_given, v_counted, 'challenge', d.id,
                                  md5(d.id::text || ':' || v_user || ':' || p_position)::uuid, false);
  update public.duel_answers set answered_at = public._now(), given = p_given, is_correct = (v_res ->> 'is_correct')::bool,
    counted_ms = v_counted
  where duel_id = d.id and user_id = v_user and position = p_position;
  if (v_res ->> 'is_correct')::bool then
    perform public._grant_capped(v_user, 'xp', 5, 300, 'duel_correct', d.id::text, 'duel_correct:' || d.id || ':' || v_user || ':' || p_position);
  end if;
  v_done := p_position = n;
  if v_done then perform public._duel_close(d.id); end if;
  return jsonb_build_object('position', p_position, 'is_correct', (v_res ->> 'is_correct')::bool, 'duplicate', false,
                            'counted_ms', v_counted, 'finished', v_done, 'error_transition', v_res -> 'error_transition')
         || public._question_reveal(q);
end $$;

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
    'their_answers', case when v_mine = cardinality(d.question_ids) or d.status = 'finished' then coalesce((
                            select jsonb_agg(jsonb_build_object('position', position, 'is_correct', is_correct, 'counted_ms', counted_ms) order by position)
                            from public.duel_answers where duel_id = d.id and user_id = v_other and answered_at is not null), '[]'::jsonb) end);
end $$;

-- ─────────────────────────────────────────── Profil d'un ami et face-à-face
create or replace function public.friend_profile(p_friend uuid) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  p public.profiles;
  r record;
  dd public.duels;
  v_streak_who text;
  v_streak int := 0;
  v_played int := 0; v_wins int := 0; v_losses int := 0; v_draws int := 0;
  v_questions int := 0; v_my_correct int := 0; v_their_correct int := 0; v_full_q int := 0;
  v_best_pct int;
  v_best_score int; v_best_total int;
  v_list jsonb := '[]'::jsonb;
  v_n int := 0;
  v_domains int;
  v_placed bool;
  v_cote int;
  me record; them record;
begin
  if not public._are_friends(v_user, p_friend) then raise exception 'not_friends'; end if;
  select * into p from public.profiles where id = p_friend;
  for r in select d.id from public.duels d where d.status in ('open', 'active') and d.expires_at < public._now()
             and least(d.challenger_id, d.opponent_id) = least(v_user, p_friend)
             and greatest(d.challenger_id, d.opponent_id) = greatest(v_user, p_friend) loop
    perform public._duel_close(r.id);
  end loop;

  -- Du plus récent au plus ancien : bilan, série en cours, meilleur score, 20 derniers duels.
  for dd in select d.* from public.duels d
           where least(d.challenger_id, d.opponent_id) = least(v_user, p_friend)
             and greatest(d.challenger_id, d.opponent_id) = greatest(v_user, p_friend)
             and d.status in ('active', 'finished', 'expired')
           order by d.created_at desc loop
    select * into me from public._duel_state(dd.id, v_user);
    select * into them from public._duel_state(dd.id, p_friend);
    if dd.status = 'finished' then
      v_played := v_played + 1;
      if dd.winner_id = v_user then v_wins := v_wins + 1;
      elsif dd.winner_id = p_friend then v_losses := v_losses + 1;
      else v_draws := v_draws + 1; end if;
      -- Série : même vainqueur sur les derniers duels terminés.
      if v_streak_who is null and v_played = 1 and dd.winner_id is not null then
        v_streak_who := case when dd.winner_id = v_user then 'me' else 'friend' end; v_streak := 1;
      elsif v_streak > 0 and v_streak = v_played - 1 and dd.winner_id is not null
            and (dd.winner_id = v_user) = (v_streak_who = 'me') then
        v_streak := v_streak + 1;
      end if;
      v_questions := v_questions + me.answered;
      if me.answered = cardinality(dd.question_ids) and them.answered = cardinality(dd.question_ids) then
        v_full_q := v_full_q + cardinality(dd.question_ids);
        v_my_correct := v_my_correct + me.score;
        v_their_correct := v_their_correct + them.score;
      end if;
      if me.answered = cardinality(dd.question_ids)
         and (v_best_pct is null or me.score * 100 / cardinality(dd.question_ids) > v_best_pct) then
        v_best_pct := me.score * 100 / cardinality(dd.question_ids);
        v_best_score := me.score; v_best_total := cardinality(dd.question_ids);
      end if;
    end if;
    if v_n < 20 then
      v_list := v_list || public._duel_json(dd, v_user);
      v_n := v_n + 1;
    end if;
  end loop;

  select count(*) filter (where s.n > 0), bool_or(s.n >= 50),
         round(sum(public._cote(s.mu) * s.n)::numeric / nullif(sum(s.n), 0))::int
    into v_domains, v_placed, v_cote
  from public.user_skills s join public.domains d on d.id = s.scope_id
  where s.user_id = p_friend and s.n > 0;

  return jsonb_build_object(
    'id', p.id, 'handle', p.handle, 'avatar', p.avatar,
    'streak', public._streak_effective(p.id), 'streak_best', p.streak_best, 'xp_total', p.xp_total,
    'cote', v_cote, 'cote_placed', coalesce(v_placed, false),
    'today', (select jsonb_build_object('score', dr.score, 'total_ms', dr.total_ms, 'status', dr.status,
                                        'answers', (select jsonb_agg(coalesce(da.is_correct, false) order by da.position)
                                                    from public.daily_answers da where da.run_id = dr.id))
              from public.daily_runs dr
              where dr.user_id = p.id and dr.daily_date = public._user_today(p.id) and dr.status = 'finished'),
    'head_to_head', jsonb_build_object(
      'played', v_played, 'wins', v_wins, 'losses', v_losses, 'draws', v_draws, 'questions', v_questions,
      -- Taux de bonnes réponses sur les duels joués en entier par les deux.
      'my_rate', case when v_full_q > 0 then round(100.0 * v_my_correct / v_full_q)::int end,
      'their_rate', case when v_full_q > 0 then round(100.0 * v_their_correct / v_full_q)::int end,
      'streak', case when v_streak > 0 then jsonb_build_object('who', v_streak_who, 'count', v_streak) end,
      'my_best', case when v_best_score is not null then jsonb_build_object('score', v_best_score, 'total', v_best_total) end),
    'duels', v_list);
end $$;

revoke execute on function public._overall_mu(uuid), public._duel_pick(uuid, uuid, int, text[], text),
  public._duel_new(uuid, uuid, int, text[], text, uuid) from public, anon, authenticated;
revoke execute on function public.duel_create(uuid, int, text[], text), public.duel_rematch(uuid), public.friend_profile(uuid)
  from public, anon;
grant execute on function public.duel_create(uuid, int, text[], text), public.duel_rematch(uuid), public.friend_profile(uuid)
  to authenticated;
