-- Brainlix — 0032 Pubs récompensées (AdMob), vérifiées par le serveur
-- Quand une pub est vue en entier, Google appelle notre fonction Edge `admob-ssv` (vérification côté serveur, signée
-- par Google). Elle enregistre la vue dans `ad_views` via `ad_ssv_record` (clé de service uniquement). L'app demande
-- ensuite la récompense avec `ad_claim` : le serveur contrôle la vue, les limites, et donne la récompense. Impossible
-- d'obtenir une récompense sans pub réellement vue, même en modifiant l'app.
-- Récompenses (limites comptées au jour du joueur, dans son fuseau) :
--   double_seeds  : double les graines d'une partie (Jouer ou 5 du jour) finie depuis moins d'1 h ; 1 fois par partie, 3 par jour.
--   boost_chest   : coffre boosté (chances de montée doublées : 50 / 40 / 10 %, graines +50 %) ; 2 par jour.
--   free_chest    : un coffre en bois offert (qui peut monter à la Recharge) ; 1 par jour.
--   streak_rescue : série sauvée dans les 48 h après sa perte ; 1 par mois.
--   correction    : débloque « Corrige tes erreurs » (1 fois par partie, sans limite par jour). Remplace le gratuit.
-- Mode test : un compte admin peut réclamer sans vue vérifiée (pubs de test de Google dans les builds TestFlight,
-- pour lesquelles Google n'appelle pas notre serveur).

create table public.ad_views (
  transaction_id text primary key,
  user_id        uuid not null references public.profiles(id) on delete cascade,
  ad_unit        text not null,
  kind           text not null check (kind in ('double_seeds', 'boost_chest', 'free_chest', 'streak_rescue', 'correction')),
  ref            text not null default '',
  test           bool not null default false,
  created_at     timestamptz not null default now(),
  claimed_at     timestamptz,
  claimed_day    date,
  reward         jsonb
);
create index on public.ad_views (user_id, kind, claimed_day);
create index on public.ad_views (user_id, kind, ref) where claimed_at is null;
create index on public.ad_views (created_at);
alter table public.ad_views enable row level security;
revoke all on public.ad_views from public, anon, authenticated;

alter table public.user_chests add column boosted bool not null default false;

-- ─────────────────────────────────────────── Réception des vues vérifiées (fonction Edge, clé de service)
-- `p_custom` = « kind:ref » posé par l'app. Une vue inconnue (joueur, type) est ignorée sans erreur : Google ne doit
-- pas réessayer indéfiniment.
create or replace function public.ad_ssv_record(p_transaction text, p_user text, p_ad_unit text, p_custom text)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid;
  v_kind text := split_part(coalesce(p_custom, ''), ':', 1);
  v_ref text := coalesce(nullif(substr(coalesce(p_custom, ''), length(split_part(coalesce(p_custom, ''), ':', 1)) + 2), ''), '');
begin
  if p_transaction is null or length(p_transaction) > 200 then return jsonb_build_object('recorded', false); end if;
  begin v_user := p_user::uuid; exception when others then return jsonb_build_object('recorded', false); end;
  if not exists (select 1 from public.profiles where id = v_user)
     or v_kind not in ('double_seeds', 'boost_chest', 'free_chest', 'streak_rescue', 'correction') or length(v_ref) > 100 then
    return jsonb_build_object('recorded', false);
  end if;
  insert into public.ad_views (transaction_id, user_id, ad_unit, kind, ref, created_at)
  values (p_transaction, v_user, left(coalesce(p_ad_unit, ''), 100), v_kind, v_ref, public._now())
  on conflict (transaction_id) do nothing;
  return jsonb_build_object('recorded', true);
end $$;

-- ─────────────────────────────────────────── Limites
create or replace function public._ad_limit(p_kind text) returns int
language sql immutable as $$
  select case p_kind when 'double_seeds' then 3 when 'boost_chest' then 2 when 'free_chest' then 1 else null end
$$;

-- Récompenses de ce type déjà obtenues aujourd'hui (ou ce mois-ci pour la série).
create or replace function public._ad_used(p_user uuid, p_kind text) returns int
language sql stable as $$
  select count(*)::int from public.ad_views
  where user_id = p_user and kind = p_kind and claimed_at is not null
    and case when p_kind = 'streak_rescue'
             then claimed_day >= date_trunc('month', public._user_today(p_user))::date
             else claimed_day = public._user_today(p_user) end
$$;

-- Série perdue et encore récupérable : perdue depuis moins de 48 h (1 ou 2 jours manqués en plus des jokers).
create or replace function public._streak_rescuable(p_user uuid) returns int
language sql stable as $$
  select case when p.streak_current >= 2 and p.streak_last_date is not null
               and (public._user_today(p_user) - p.streak_last_date - 1 - p.streak_freezes) between 1 and 2
              then p.streak_current end
  from public.profiles p where p.id = p_user
$$;

-- Questions à corriger d'une partie, avec toutes les conditions (erreurs levées sinon).
create or replace function public._correction_check(p_user uuid, p_session uuid) returns uuid[]
language plpgsql stable as $$
declare
  s public.play_sessions;
  v_missed uuid[];
begin
  select * into s from public.play_sessions where id = p_session and user_id = p_user;
  if not found then raise exception 'session_not_found'; end if;
  if exists (select 1 from public.play_corrections where session_id = p_session and finished_at is not null) then
    raise exception 'correction_done';
  end if;
  if s.mode = 'onboarding' then raise exception 'correction_unavailable'; end if;
  if exists (select 1 from public.play_sessions s2 where s2.user_id = p_user and s2.created_at > s.created_at)
     or public._now() - s.created_at > interval '1 hour' then
    raise exception 'correction_expired';
  end if;
  v_missed := public._missed_questions(p_user, p_session);
  if cardinality(v_missed) = 0 then raise exception 'nothing_to_correct'; end if;
  return v_missed;
end $$;

-- Graines gagnées pendant une partie (« play:<id> » ou « daily:<id> »), si elle date de moins d'1 h.
create or replace function public._ad_game_seeds(p_user uuid, p_ref text) returns int
language plpgsql stable as $$
declare
  v_kind text := split_part(p_ref, ':', 1);
  v_id uuid;
  v_seeds int;
  v_last timestamptz;
begin
  begin v_id := split_part(p_ref, ':', 2)::uuid; exception when others then raise exception 'invalid_ref'; end;
  if v_kind = 'play' then
    if not exists (select 1 from public.play_sessions where id = v_id and user_id = p_user) then raise exception 'invalid_ref'; end if;
  elsif v_kind = 'daily' then
    if not exists (select 1 from public.daily_runs where id = v_id and user_id = p_user and status <> 'in_progress') then
      raise exception 'invalid_ref';
    end if;
  else
    raise exception 'invalid_ref';
  end if;
  select coalesce(sum(amount), 0), max(created_at) into v_seeds, v_last from public.ledger
  where user_id = p_user and currency = 'seeds' and amount > 0 and ref = v_id::text
    and reason in ('play_correct', 'daily_complete', 'daily_perfect');
  if v_seeds = 0 then raise exception 'nothing_to_double'; end if;
  if public._now() - v_last > interval '1 hour' then raise exception 'ad_expired'; end if;
  return v_seeds;
end $$;

-- Vérifie qu'une récompense est possible, AVANT de montrer la pub (erreurs levées sinon).
create or replace function public._ad_check(p_user uuid, p_kind text, p_ref text) returns void
language plpgsql stable as $$
declare
  c public.user_chests;
begin
  if p_kind not in ('double_seeds', 'boost_chest', 'free_chest', 'streak_rescue', 'correction') then
    raise exception 'invalid_kind';
  end if;
  if p_kind = 'streak_rescue' then
    if public._ad_used(p_user, p_kind) >= 1 then raise exception 'ad_limit'; end if;
  elsif p_kind <> 'correction' and public._ad_used(p_user, p_kind) >= public._ad_limit(p_kind) then
    raise exception 'ad_limit';
  end if;
  case p_kind
    when 'double_seeds' then
      if exists (select 1 from public.ad_views where user_id = p_user and kind = p_kind and ref = p_ref and claimed_at is not null) then
        raise exception 'ad_already_used';
      end if;
      perform public._ad_game_seeds(p_user, p_ref);
    when 'boost_chest' then
      begin
        select * into c from public.user_chests where id = p_ref::uuid and user_id = p_user;
      exception when invalid_text_representation then raise exception 'invalid_ref';
      end;
      if c.id is null then raise exception 'chest_not_found'; end if;
      if c.opened_at is not null then raise exception 'chest_opened'; end if;
      if c.boosted then raise exception 'ad_already_used'; end if;
    when 'streak_rescue' then
      if public._streak_rescuable(p_user) is null then raise exception 'streak_not_rescuable'; end if;
    when 'correction' then
      begin
        perform public._correction_check(p_user, p_ref::uuid);
      exception when invalid_text_representation then raise exception 'invalid_ref';
      end;
    else null;
  end case;
end $$;

-- Prend la vue vérifiée non encore utilisée pour cette récompense (ou, en mode test admin, en crée une).
create or replace function public._ad_take(p_user uuid, p_kind text, p_ref text, p_test bool) returns text
language plpgsql as $$
declare v_tx text;
begin
  select transaction_id into v_tx from public.ad_views
  where user_id = p_user and kind = p_kind and ref = coalesce(p_ref, '') and claimed_at is null
  order by created_at limit 1 for update skip locked;
  if v_tx is null then
    if coalesce(p_test, false) and exists (select 1 from public.app_admins where user_id = p_user) then
      v_tx := 'test:' || gen_random_uuid();
      insert into public.ad_views (transaction_id, user_id, ad_unit, kind, ref, test, created_at)
      values (v_tx, p_user, 'test', p_kind, coalesce(p_ref, ''), true, public._now());
    else
      raise exception 'ad_pending';  -- Google n'a pas encore confirmé la vue : l'app réessaie quelques secondes
    end if;
  end if;
  update public.ad_views set claimed_at = public._now(), claimed_day = public._user_today(p_user) where transaction_id = v_tx;
  return v_tx;
end $$;

-- ─────────────────────────────────────────── API joueur
-- État des pubs : récompenses restantes, série à sauver, pubs entre les parties autorisées.
create or replace function public.ad_status() returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  p public.profiles;
begin
  select * into p from public.profiles where id = v_user;
  return jsonb_build_object(
    'double_seeds', greatest(3 - public._ad_used(v_user, 'double_seeds'), 0),
    'boost_chest', greatest(2 - public._ad_used(v_user, 'boost_chest'), 0),
    'free_chest', greatest(1 - public._ad_used(v_user, 'free_chest'), 0),
    'streak_rescue', case when public._ad_used(v_user, 'streak_rescue') = 0 then public._streak_rescuable(v_user) end,
    -- Pas de pub entre les parties pendant les 3 premiers jours.
    'interstitial', p.created_at <= public._now() - interval '3 days',
    'admin', exists (select 1 from public.app_admins where user_id = v_user));
end $$;

-- À appeler avant de montrer la pub : évite de regarder une pub pour rien.
create or replace function public.ad_can(p_kind text, p_ref text default null) returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  perform public._ad_check(public._require_user(), p_kind, coalesce(p_ref, ''));
  return jsonb_build_object('ok', true);
end $$;

-- Récompense d'une pub vue. Idempotent par vue ; erreur « ad_pending » tant que Google n'a pas confirmé.
create or replace function public.ad_claim(p_kind text, p_ref text default null, p_test bool default false) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  v_ref text := coalesce(p_ref, '');
  v_tx text;
  v_reward jsonb;
  v_seeds int;
  v_chest uuid;
  v_streak int;
begin
  -- La correction a son propre point d'entrée (elle renvoie les questions à rejouer).
  if p_kind = 'correction' then
    begin
      return public.play_correction_start(v_ref::uuid, 'ad', p_test);
    exception when invalid_text_representation then raise exception 'invalid_ref';
    end;
  end if;
  perform pg_advisory_xact_lock(hashtext('ad:' || v_user));
  perform public._ad_check(v_user, p_kind, v_ref);
  v_tx := public._ad_take(v_user, p_kind, v_ref, p_test);

  case p_kind
    when 'double_seeds' then
      v_seeds := public._ad_game_seeds(v_user, v_ref);
      perform public._grant(v_user, 'seeds', v_seeds, 'ad_double_seeds', split_part(v_ref, ':', 2), 'ad_double:' || v_ref);
      v_reward := jsonb_build_object('seeds', v_seeds);
    when 'boost_chest' then
      update public.user_chests set boosted = true where id = v_ref::uuid;
      v_reward := jsonb_build_object('chest_id', v_ref, 'boosted', true);
    when 'free_chest' then
      perform public._give_chest(v_user, 'wood', 'ad', null, 'ad_chest:' || v_tx);
      select id into v_chest from public.user_chests where user_id = v_user and idempotency_key = 'ad_chest:' || v_tx;
      v_reward := jsonb_build_object('chest_id', v_chest, 'tier', 'wood');
    when 'streak_rescue' then
      v_streak := public._streak_rescuable(v_user);
      -- Comme si la veille avait été jouée ; les jokers couvraient déjà une partie du trou : ils sont utilisés.
      update public.profiles set streak_last_date = public._user_today(v_user) - 1, streak_freezes = 0 where id = v_user;
      v_reward := jsonb_build_object('streak', v_streak);
  end case;

  update public.ad_views set reward = v_reward where transaction_id = v_tx;
  return v_reward || jsonb_build_object('balance', (select seeds from public.profiles where id = v_user));
end $$;

-- ─────────────────────────────────────────── Correction : la pub remplace le gratuit
drop function public.play_correction_start(uuid, text);
create or replace function public.play_correction_start(p_session uuid, p_via text default 'ad', p_test bool default false)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  s public.play_sessions;
  v_missed uuid[];
  c public.play_corrections;
begin
  select * into s from public.play_sessions where id = p_session and user_id = v_user;
  if not found then raise exception 'session_not_found'; end if;
  -- Déjà ouverte (pub déjà vue) : on reprend.
  select * into c from public.play_corrections where session_id = p_session;
  if found then
    if c.finished_at is not null then raise exception 'correction_done'; end if;
    return jsonb_build_object('question_ids', to_jsonb(c.question_ids), 'ranked', s.ranked);
  end if;
  if p_via <> 'ad' then raise exception 'ad_required'; end if;
  perform pg_advisory_xact_lock(hashtext('ad:' || v_user));
  v_missed := public._correction_check(v_user, p_session);
  perform public._ad_take(v_user, 'correction', p_session::text, p_test);
  insert into public.play_corrections (session_id, user_id, via, question_ids, started_at)
  values (p_session, v_user, 'ad', v_missed, public._now());
  return jsonb_build_object('question_ids', to_jsonb(v_missed), 'ranked', s.ranked);
end $$;

-- ─────────────────────────────────────────── Coffre boosté
do $$
declare v_old text; v_new text;
begin
  v_old := pg_get_functiondef('public.chest_open(uuid)'::regprocedure);
  v_new := replace(replace(replace(replace(replace(v_old,
    'random() < 0.25 then', 'random() < (case when c.boosted then 0.50 else 0.25 end) then'),
    'random() < 0.20 then', 'random() < (case when c.boosted then 0.40 else 0.20 end) then'),
    'random() < 0.05 then', 'random() < (case when c.boosted then 0.10 else 0.05 end) then'),
    '  if v_final = ''savant'' then
    v_fifty := 1;',
    '  if c.boosted then v_seeds := round(v_seeds * 1.5); end if;
  if v_final = ''savant'' then
    v_fifty := 1;'),
    '''tier'', c.tier, ''final_tier''', '''tier'', c.tier, ''boosted'', c.boosted, ''final_tier''');
  if v_new not like '%case when c.boosted then 0.50%' or v_new not like '%case when c.boosted then 0.40%'
     or v_new not like '%case when c.boosted then 0.10%' or v_new not like '%v_seeds * 1.5%'
     or v_new not like '%''boosted'', c.boosted%' then
    raise exception '0032: chest_open inchangée';
  end if;
  execute v_new;
end $$;

-- ─────────────────────────────────────────── Admin : pubs
create or replace function public.admin_ads(p_days int default 30) returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare
  v_days int := least(greatest(coalesce(p_days, 30), 7), 180);
  v_today date := public._paris_day(public._now());
  v_from date := v_today - (v_days - 1);
begin
  perform public._require_admin();
  return jsonb_build_object(
    'series', (select coalesce(jsonb_agg(jsonb_build_object(
          'day', d.day,
          'rewarded', (select count(*) from public.ad_views v where not v.test and public._paris_day(v.created_at) = d.day),
          'interstitial', (select count(*) from public.app_events e where e.name = 'interstitial'
                             and public._paris_day(e.created_at) = d.day),
          'viewers', (select count(distinct user_id) from public.ad_views v where not v.test and public._paris_day(v.created_at) = d.day)
        ) order by d.day), '[]'::jsonb)
      from (select generate_series(v_from, v_today, interval '1 day')::date as day) d),
    'by_kind', (select coalesce(jsonb_object_agg(kind, jsonb_build_object('views', n, 'claimed', c)), '{}'::jsonb) from (
                  select kind, count(*) n, count(*) filter (where claimed_at is not null) c from public.ad_views
                  where not test and created_at > public._now() - interval '7 days' group by kind) t),
    'seeds_doubled', (select coalesce(sum(amount), 0) from public.ledger
                      where reason = 'ad_double_seeds' and created_at > public._now() - interval '7 days'),
    'interstitial_7d', (select count(*) from public.app_events where name = 'interstitial'
                          and created_at > public._now() - interval '7 days'),
    'viewers_7d', (select count(distinct user_id) from public.ad_views where not test
                     and created_at > public._now() - interval '7 days'));
end $$;

-- ─────────────────────────────────────────── Droits
revoke execute on function public.ad_ssv_record(text, text, text, text) from public, anon, authenticated;
grant execute on function public.ad_ssv_record(text, text, text, text) to service_role;
revoke execute on function public._ad_limit(text), public._ad_used(uuid, text), public._streak_rescuable(uuid),
  public._correction_check(uuid, uuid), public._ad_game_seeds(uuid, text), public._ad_check(uuid, text, text),
  public._ad_take(uuid, text, text, bool) from public, anon, authenticated;
revoke execute on function public.ad_status(), public.ad_can(text, text), public.ad_claim(text, text, bool),
  public.play_correction_start(uuid, text, bool), public.admin_ads(int) from public, anon;
grant execute on function public.ad_status(), public.ad_can(text, text), public.ad_claim(text, text, bool),
  public.play_correction_start(uuid, text, bool), public.admin_ads(int) to authenticated;
