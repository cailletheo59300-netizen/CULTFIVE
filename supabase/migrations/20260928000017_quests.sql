-- Brainlix — 0017 Objectifs du jour et de la semaine, récap des semaines, historique du 5 du jour
-- Objectifs : 3 par jour (dont toujours « Fais le 5 du jour ») et 3 par semaine (lundi → dimanche, fuseau du joueur).
-- La progression est recalculée à partir de ce qui a vraiment été joué (Daily, parties, réponses, erreurs corrigées,
-- cote) : rien à tricher côté client. Récompenses modestes pour ne pas dévaluer les graines :
--   jour    : 15 XP + 2 graines par objectif, +10 XP + 3 graines si les trois sont remplis  → 9 graines max / jour
--   semaine : 50 XP + 8 graines par objectif, coffre de 15 graines si les trois sont remplis → 39 graines max / semaine
-- Versées une seule fois (clé d'idempotence du ledger), au moment où l'app consulte les objectifs.

create table public.user_quests (
  user_id      uuid not null references public.profiles(id) on delete cascade,
  period       text not null check (period in ('day', 'week')),
  period_start date not null,
  slot         int  not null check (slot between 1 and 3),
  metric       text not null,
  param        text,
  target       int  not null check (target > 0),
  label        text not null,
  xp           int  not null,
  seeds        int  not null,
  completed_at timestamptz,
  primary key (user_id, period, period_start, slot)
);
alter table public.user_quests enable row level security;
create policy user_quests_own on public.user_quests for select using (user_id = auth.uid());

-- Début de semaine (lundi) dans le fuseau du joueur.
create or replace function public._user_week_start(p_user uuid) returns date
language sql stable as $$ select date_trunc('week', public._user_today(p_user))::date $$;

-- Progression d'un objectif sur [p_day_from, p_day_to[ (jours du fuseau du joueur).
create or replace function public._quest_progress(p_user uuid, p_metric text, p_param text, p_day_from date, p_day_to date)
returns int language plpgsql stable as $$
declare
  v_tz text := public._user_tz(p_user);
  v_from timestamptz := (p_day_from::timestamp) at time zone v_tz;
  v_to timestamptz := (p_day_to::timestamp) at time zone v_tz;
begin
  return case p_metric
    when 'daily_done' then (select count(*) from public.daily_runs
                            where user_id = p_user and daily_date >= p_day_from and daily_date < p_day_to and status <> 'in_progress')
    when 'daily_perfect' then (select count(*) from public.daily_runs
                               where user_id = p_user and daily_date >= p_day_from and daily_date < p_day_to and score = 5)
    when 'ranked_games' then (select count(*) from public.play_sessions
                              where user_id = p_user and ranked and completed_at >= v_from and completed_at < v_to)
    when 'answers' then (select count(*) from public.question_attempts
                         where user_id = p_user and created_at >= v_from and created_at < v_to)
    when 'correct_domain' then (select count(*) from public.question_attempts a join public.questions q on q.id = a.question_id
                                where a.user_id = p_user and a.is_correct and q.domain_id = p_param
                                  and a.created_at >= v_from and a.created_at < v_to)
    when 'errors_corrected' then (select count(*) from public.user_concepts
                                  where user_id = p_user and corrected_at >= v_from and corrected_at < v_to)
    when 'domains_played' then (select count(distinct q.domain_id) from public.question_attempts a
                                join public.questions q on q.id = a.question_id
                                where a.user_id = p_user and a.created_at >= v_from and a.created_at < v_to)
    -- Meilleure progression de cote sur un domaine joué pendant la période.
    when 'cote_gain' then greatest(0, coalesce((
      select max(public._cote(k.mu) - public._cote(coalesce(
               (select s.mu from public.user_skill_snapshots s
                where s.user_id = p_user and s.scope_id = d.domain_id and s.day < p_day_from order by s.day desc limit 1),
               (select a2.user_skill_before from public.question_attempts a2 join public.questions q2 on q2.id = a2.question_id
                where a2.user_id = p_user and q2.domain_id = d.domain_id and a2.created_at >= v_from
                order by a2.created_at limit 1),
               50)))
      from (select distinct q.domain_id from public.question_attempts a join public.questions q on q.id = a.question_id
            where a.user_id = p_user and a.created_at >= v_from and a.created_at < v_to) d
      cross join lateral public._skill_peek(p_user, d.domain_id) k), 0))
    else 0 end;
end $$;

-- Crée les objectifs de la période s'ils n'existent pas (tirage stable : même joueur, même période → mêmes objectifs).
create or replace function public._quests_ensure(p_user uuid, p_period text, p_start date)
returns void language plpgsql as $$
declare
  v_errors int := (select count(*) from public.user_concepts where user_id = p_user and error_state in ('failed', 'to_review'));
  v_domain text;
  v_domain_name text;
  r record;
  v_slot int := 1;
begin
  if exists (select 1 from public.user_quests where user_id = p_user and period = p_period and period_start = p_start) then return; end if;
  -- Domaine du jour pour « bonnes réponses en … » : parmi les centres d'intérêt s'il y en a.
  select d.id, d.name into v_domain, v_domain_name from public.domains d
  where d.is_active and (d.id = any (coalesce((select interests from public.profiles where id = p_user), '{}'))
                         or coalesce(cardinality((select interests from public.profiles where id = p_user)), 0) = 0)
  order by md5(p_user::text || p_start::text || d.id) limit 1;
  if v_domain is null then
    select d.id, d.name into v_domain, v_domain_name from public.domains d where d.is_active
    order by md5(p_user::text || p_start::text || d.id) limit 1;
  end if;

  for r in
    with pool(metric, param, target, label, fixed) as (
      select * from (values
        -- jour
        ('daily_done', null, 1, 'Fais le 5 du jour', true),
        ('ranked_games', null, 2, 'Joue 2 parties classées', false),
        ('answers', null, 20, 'Réponds à 20 questions', false),
        ('correct_domain', v_domain, 5, '5 bonnes réponses en ' || v_domain_name, false),
        ('errors_corrected', null, 2, 'Corrige 2 erreurs', false)
      ) t where p_period = 'day' and (t.column1 <> 'errors_corrected' or v_errors >= 2)
      union all
      select * from (values
        -- semaine
        ('daily_done', null, 5, 'Fais le 5 du jour 5 fois', false),
        ('ranked_games', null, 8, 'Joue 8 parties classées', false),
        ('domains_played', null, 4, 'Joue dans 4 domaines différents', false),
        ('cote_gain', null, 30, 'Gagne 30 points de cote dans un domaine', false),
        ('daily_perfect', null, 1, 'Fais un sans-faute au 5 du jour', false),
        ('errors_corrected', null, 6, 'Corrige 6 erreurs', false)
      ) t where p_period = 'week' and (t.column1 <> 'errors_corrected' or v_errors >= 3)
    )
    select * from pool order by fixed desc, md5(p_user::text || p_period || p_start::text || metric) limit 3
  loop
    insert into public.user_quests (user_id, period, period_start, slot, metric, param, target, label, xp, seeds)
    values (p_user, p_period, p_start, v_slot, r.metric, r.param, r.target, r.label,
            case when p_period = 'day' then 15 else 50 end, case when p_period = 'day' then 2 else 8 end)
    on conflict do nothing;
    v_slot := v_slot + 1;
  end loop;
end $$;

-- Met à jour la période : progression, récompenses dues, bonus. Renvoie le JSON de la période + les nouveautés.
create or replace function public._quests_period(p_user uuid, p_period text, p_start date, p_newly_in jsonb,
                                                 out result jsonb, out newly jsonb)
language plpgsql as $$
declare
  v_to date := p_start + case when p_period = 'day' then 1 else 7 end;
  q public.user_quests;
  v_progress int;
  v_quests jsonb := '[]'::jsonb;
  v_all bool := true;
  v_bonus_xp int := case when p_period = 'day' then 10 else 0 end;
  v_bonus_seeds int := case when p_period = 'day' then 3 else 15 end;
  v_key text;
begin
  newly := p_newly_in;
  perform public._quests_ensure(p_user, p_period, p_start);
  for q in select * from public.user_quests where user_id = p_user and period = p_period and period_start = p_start order by slot loop
    v_progress := least(public._quest_progress(p_user, q.metric, q.param, p_start, v_to), q.target);
    if v_progress >= q.target and q.completed_at is null then
      update public.user_quests set completed_at = public._now()
      where user_id = p_user and period = p_period and period_start = p_start and slot = q.slot;
      q.completed_at := public._now();
      v_key := 'quest:' || p_period || ':' || p_start || ':' || q.slot;
      perform public._grant(p_user, 'xp', q.xp, 'quest', v_key, v_key || ':xp');
      if public._grant(p_user, 'seeds', q.seeds, 'quest', v_key, v_key || ':seeds') then
        newly := newly || jsonb_build_object('label', q.label, 'xp', q.xp, 'seeds', q.seeds);
      end if;
    end if;
    v_all := v_all and q.completed_at is not null;
    v_quests := v_quests || jsonb_build_object('slot', q.slot, 'label', q.label, 'target', q.target, 'progress', v_progress,
                                               'done', q.completed_at is not null, 'xp', q.xp, 'seeds', q.seeds);
  end loop;
  if v_all and jsonb_array_length(v_quests) > 0 then
    v_key := 'quest_bonus:' || p_period || ':' || p_start;
    perform public._grant(p_user, 'xp', v_bonus_xp, 'quest', v_key, v_key || ':xp');
    if public._grant(p_user, 'seeds', v_bonus_seeds, 'quest', v_key, v_key || ':seeds') then
      newly := newly || jsonb_build_object('label', case when p_period = 'day' then 'Tous les objectifs du jour'
                                                              else 'Coffre de la semaine' end,
                                               'xp', v_bonus_xp, 'seeds', v_bonus_seeds, 'bonus', true);
    end if;
  end if;
  result := jsonb_build_object(
    'period_start', p_start,
    'ends_at', public._day_end(v_to - 1, public._user_tz(p_user)),
    'quests', v_quests,
    'bonus', jsonb_build_object('xp', v_bonus_xp, 'seeds', v_bonus_seeds, 'done', v_all and jsonb_array_length(v_quests) > 0));
end $$;

create or replace function public.quests_overview() returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  v_newly jsonb := '[]'::jsonb;
  v_day jsonb;
  v_week jsonb;
begin
  select p.result, p.newly into v_day, v_newly from public._quests_period(v_user, 'day', public._user_today(v_user), v_newly) p;
  select p.result, p.newly into v_week, v_newly from public._quests_period(v_user, 'week', public._user_week_start(v_user), v_newly) p;
  return jsonb_build_object('day', v_day, 'week', v_week, 'newly', v_newly,
                            'balance', (select seeds from public.profiles where id = v_user));
end $$;

-- ─────────────────────────────────────────── Récap des semaines (profil)
create or replace function public.weekly_recap(p_weeks int default 8) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  v_tz text := public._user_tz(v_user);
  v_this date := public._user_week_start(v_user);
  v_out jsonb := '[]'::jsonb;
  v_start date; v_from timestamptz; v_to timestamptz;
  v_answers int; v_correct int;
begin
  for i in 0 .. least(greatest(p_weeks, 1), 26) - 1 loop
    v_start := v_this - 7 * i;
    v_from := (v_start::timestamp) at time zone v_tz;
    v_to := ((v_start + 7)::timestamp) at time zone v_tz;
    select count(*), count(*) filter (where is_correct) into v_answers, v_correct
    from public.question_attempts where user_id = v_user and created_at >= v_from and created_at < v_to;
    -- Semaines antérieures à l'inscription : on s'arrête.
    exit when i > 0 and v_to < (select created_at from public.profiles where id = v_user);
    v_out := v_out || jsonb_build_object(
      'week_start', v_start,
      'answers', v_answers,
      'correct', v_correct,
      'games', (select count(*) from public.play_sessions where user_id = v_user and completed_at >= v_from and completed_at < v_to),
      'dailies', (select count(*) from public.daily_runs where user_id = v_user and daily_date >= v_start and daily_date < v_start + 7
                                                          and status <> 'in_progress'),
      'daily_avg', (select round(avg(score)::numeric, 1) from public.daily_runs where user_id = v_user and daily_date >= v_start
                                                                                and daily_date < v_start + 7 and status <> 'in_progress'),
      'errors_corrected', (select count(*) from public.user_concepts where user_id = v_user and corrected_at >= v_from and corrected_at < v_to),
      'quests_done', (select count(*) from public.user_quests where user_id = v_user and completed_at >= v_from and completed_at < v_to),
      -- Variation de cote par domaine joué : fin de semaine (dernier point connu) contre fin de la semaine précédente.
      'cote_moves', coalesce((
        select jsonb_agg(jsonb_build_object('domain_id', m.domain_id, 'delta', m.delta) order by abs(m.delta) desc)
        from (select d.domain_id,
                     public._cote((select s.mu from public.user_skill_snapshots s where s.user_id = v_user and s.scope_id = d.domain_id
                                     and s.day < v_start + 7 order by s.day desc limit 1))
                     - public._cote(coalesce((select s.mu from public.user_skill_snapshots s where s.user_id = v_user
                                                and s.scope_id = d.domain_id and s.day < v_start order by s.day desc limit 1),
                                             (select a.user_skill_before from public.question_attempts a join public.questions q on q.id = a.question_id
                                              where a.user_id = v_user and q.domain_id = d.domain_id and a.created_at >= v_from
                                              order by a.created_at limit 1), 50)) as delta
              from (select distinct q.domain_id from public.question_attempts a join public.questions q on q.id = a.question_id
                    where a.user_id = v_user and a.created_at >= v_from and a.created_at < v_to) d) m
        where m.delta <> 0), '[]'::jsonb));
  end loop;
  return v_out;
end $$;

-- ─────────────────────────────────────────── Historique du 5 du jour : % de réussite et percentile
create or replace function public.daily_history(p_days int default 35) returns jsonb
language sql security definer set search_path = public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'date', daily_date, 'status', status, 'score', score, 'total_ms', total_ms,
           'rate', case when status <> 'in_progress' then coalesce(score, 0) * 20 end,
           'percentile', case when status <> 'in_progress' then public._daily_percentile(id) end)
         order by daily_date desc), '[]'::jsonb)
  from public.daily_runs
  where user_id = auth.uid() and daily_date >= public._user_today(auth.uid()) - least(greatest(p_days, 1), 400)
$$;

revoke execute on function public._quest_progress(uuid, text, text, date, date) from public, anon, authenticated;
revoke execute on function public._quests_ensure(uuid, text, date) from public, anon, authenticated;
revoke execute on function public._quests_period(uuid, text, date, jsonb) from public, anon, authenticated;
revoke execute on function public.quests_overview() from public, anon;
revoke execute on function public.weekly_recap(int) from public, anon;
grant execute on function public.quests_overview() to authenticated;
grant execute on function public.weekly_recap(int) to authenticated;
grant select on public.user_quests to authenticated;
