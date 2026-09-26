-- CULT FIVE — 0006 Social & Profile
-- Profil (pseudo, fuseau, onboarding), amis, parrainage anti-abus, ligues privées, suppression de compte.

-- ═══════════════════════════════════════════ PROFIL
create or replace function public.profile_me() returns jsonb
language sql security definer set search_path = public, pg_temp as $$
  select jsonb_build_object(
    'id', p.id, 'handle', p.handle, 'avatar', p.avatar, 'age_range', p.age_range, 'timezone', p.timezone,
    'challenge_prior', p.challenge_prior, 'interests', p.interests,
    'xp_total', p.xp_total, 'seeds', p.seeds,
    'streak', public._streak_effective(p.id), 'streak_best', p.streak_best, 'streak_freezes', p.streak_freezes,
    'questions_answered', p.questions_answered, 'questions_correct', p.questions_correct,
    'errors_corrected', p.errors_corrected,
    'active_errors', (select count(*) from public.user_concepts uc where uc.user_id = p.id and uc.error_state in ('failed', 'to_review')),
    'referral_code', p.referral_code,
    'notif_daily', p.notif_daily, 'notif_daily_time', to_char(p.notif_daily_time, 'HH24:MI'), 'notif_reminder', p.notif_reminder,
    'onboarded', p.onboarded_at is not null,
    'is_anonymous', coalesce((select u.is_anonymous from auth.users u where u.id = p.id), false),
    'created_at', p.created_at)
  from public.profiles p where p.id = auth.uid()
$$;

create or replace function public.handle_available(p_handle text) returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  if not public._handle_is_valid(p_handle) then
    return jsonb_build_object('available', false, 'reason', case when p_handle ~ '^[A-Za-z0-9_]{3,20}$' then 'not_allowed' else 'invalid' end);
  end if;
  return jsonb_build_object('available', not exists (
    select 1 from public.profiles where lower(handle) = lower(p_handle) and id <> auth.uid()), 'reason', null);
end $$;

create or replace function public.set_handle(p_handle text) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user(); p public.profiles;
begin
  if not public._handle_is_valid(p_handle) then raise exception 'handle_invalid'; end if;
  select * into p from public.profiles where id = v_user for update;
  if p.handle = p_handle then return public.profile_me(); end if;
  -- Changement libre la première fois (pseudo auto-généré), puis une fois tous les 7 jours.
  if p.handle_changed_at is not null and p.handle_changed_at > public._now() - interval '7 days'
     and lower(p.handle) <> lower(p_handle) then
    raise exception 'handle_change_too_soon';
  end if;
  begin
    update public.profiles set handle = p_handle,
      handle_changed_at = case when lower(p.handle) = lower(p_handle) then handle_changed_at else public._now() end
    where id = v_user;
  exception when unique_violation then
    raise exception 'handle_taken';
  end;
  return public.profile_me();
end $$;

-- Mise à jour des préférences non sensibles.
create or replace function public.profile_update(p jsonb) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user();
begin
  update public.profiles set
    avatar          = case when p ? 'avatar' and jsonb_typeof(p -> 'avatar') = 'object' and length((p -> 'avatar')::text) < 300
                           then p -> 'avatar' else avatar end,
    age_range       = case when p ? 'age_range' then p ->> 'age_range' else age_range end,
    interests       = case when p ? 'interests'
                           then (select coalesce(array_agg(x), '{}') from jsonb_array_elements_text(p -> 'interests') x
                                 where x in (select id from public.domains)) else interests end,
    notif_daily     = coalesce((p ->> 'notif_daily')::bool, notif_daily),
    notif_daily_time= coalesce((p ->> 'notif_daily_time')::time, notif_daily_time),
    notif_reminder  = coalesce((p ->> 'notif_reminder')::bool, notif_reminder)
  where id = v_user;
  return public.profile_me();
end $$;

-- Onboarding : le niveau de challenge est un prior. Si peu de réponses, on décale les compétences déjà créées.
create or replace function public.complete_onboarding(p_prior_level text, p_interests text[]) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  v_prior real := case p_prior_level when 'discovery' then 38 when 'balanced' then 50 when 'challenge' then 60 when 'expert' then 70 end;
  v_old real;
begin
  if v_prior is null then raise exception 'invalid_level'; end if;
  select challenge_prior into v_old from public.profiles where id = v_user;
  if (select questions_answered from public.profiles where id = v_user) < 10 then
    update public.user_skills set mu = least(greatest(mu + (v_prior - v_old), 0), 100) where user_id = v_user;
  end if;
  update public.profiles set
    challenge_prior = v_prior,
    interests = (select coalesce(array_agg(x), '{}') from unnest(p_interests) x where x in (select id from public.domains)),
    onboarded_at = coalesce(onboarded_at, public._now())
  where id = v_user;
  return public.profile_me();
end $$;

-- Fuseau : pris en compte au plus une fois toutes les 20 h (voyage OK, bascule répétée impossible).
create or replace function public.set_timezone(p_tz text) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user(); p public.profiles;
begin
  if not exists (select 1 from pg_timezone_names where name = p_tz) then raise exception 'invalid_timezone'; end if;
  select * into p from public.profiles where id = v_user for update;
  if p.timezone = p_tz then return jsonb_build_object('timezone', p.timezone, 'applied', true); end if;
  if p.timezone_changed_at is not null and p.timezone_changed_at > public._now() - interval '20 hours' then
    return jsonb_build_object('timezone', p.timezone, 'applied', false);
  end if;
  update public.profiles set timezone = p_tz, timezone_changed_at = public._now() where id = v_user;
  return jsonb_build_object('timezone', p_tz, 'applied', true);
end $$;

create or replace function public.register_device(p_device_hash text) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  insert into public.user_devices (user_id, device_hash, first_seen) values (public._require_user(), p_device_hash, public._now())
  on conflict do nothing;
end $$;

-- Compétences (profil, statistiques)
create or replace function public.skills_overview() returns jsonb
language sql security definer set search_path = public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'domain_id', d.id, 'name', d.name,
      'level', round(k.mu::numeric, 0),
      'reliability', round(greatest(0, 1 - sqrt(k.var) / 10)::numeric, 2),
      'answered', coalesce(s.n, 0), 'correct', coalesce(s.correct, 0))
    order by coalesce(s.n, 0) desc, d.sort), '[]'::jsonb)
  from public.domains d
  left join public.user_skills s on s.user_id = auth.uid() and s.scope_id = d.id
  cross join lateral public._skill_peek(auth.uid(), d.id) k
  where d.is_active
$$;

create or replace function public.domain_stats(p_domain text) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user();
begin
  if not exists (select 1 from public.domains where id = p_domain) then raise exception 'domain_not_found'; end if;
  return jsonb_build_object(
    'domain_id', p_domain,
    'level', (select round(mu::numeric, 0) from public._skill_peek(v_user, p_domain)),
    'reliability', (select round(greatest(0, 1 - sqrt(var) / 10)::numeric, 2) from public._skill_peek(v_user, p_domain)),
    'answered', coalesce((select n from public.user_skills where user_id = v_user and scope_id = p_domain), 0),
    'correct', coalesce((select correct from public.user_skills where user_id = v_user and scope_id = p_domain), 0),
    'avg_ms', (select case when n > 0 then total_ms / n end from public.user_skills where user_id = v_user and scope_id = p_domain),
    'concepts_mastered', (select count(*) from public.user_concepts uc join public.concepts c on c.id = uc.concept_id
                          join public.subdomains sd on sd.id = c.subdomain_id
                          where uc.user_id = v_user and sd.domain_id = p_domain
                            and (uc.error_state = 'mastered' or (uc.error_state is null and uc.correct >= 2))),
    'history', (select coalesce(jsonb_agg(jsonb_build_object('day', day, 'level', round(mu::numeric, 1)) order by day), '[]'::jsonb)
                from public.user_skill_snapshots where user_id = v_user and scope_id = p_domain and day >= current_date - 90),
    'subdomains', (select coalesce(jsonb_agg(jsonb_build_object(
                      'id', sd.id, 'name', sd.name,
                      'level', round(k.mu::numeric, 0),
                      'reliability', round(greatest(0, 1 - sqrt(k.var) / 10)::numeric, 2),
                      'answered', coalesce(us.n, 0), 'correct', coalesce(us.correct, 0),
                      'available', (select count(*) from public.questions q where q.subdomain_id = sd.id and q.status = 'published'))
                    order by sd.sort), '[]'::jsonb)
                   from public.subdomains sd
                   left join public.user_skills us on us.user_id = v_user and us.scope_id = sd.id
                   cross join lateral public._skill_peek(v_user, sd.id) k
                   where sd.domain_id = p_domain),
    'by_difficulty', (select coalesce(jsonb_agg(jsonb_build_object('band', band, 'answered', n, 'correct', c) order by band), '[]'::jsonb)
                      from (select case when question_difficulty < 40 then 'easy' when question_difficulty < 60 then 'medium' else 'hard' end band,
                                   count(*) n, count(*) filter (where is_correct) c
                            from public.question_attempts a join public.questions q on q.id = a.question_id
                            where a.user_id = v_user and q.domain_id = p_domain group by 1) t),
    'recent_errors', (select coalesce(jsonb_agg(jsonb_build_object('concept_id', c.id, 'label', c.label, 'state', uc.error_state, 'since', uc.error_since)
                                                order by uc.error_since desc), '[]'::jsonb)
                      from (select * from public.user_concepts uc0
                            where uc0.user_id = v_user and uc0.error_state in ('failed', 'to_review')
                              and split_part(uc0.concept_id, '.', 1) = p_domain
                            order by uc0.error_since desc limit 10) uc
                      join public.concepts c on c.id = uc.concept_id));
end $$;

create or replace function public.errors_overview() returns jsonb
language sql security definer set search_path = public, pg_temp as $$
  select jsonb_build_object(
    'active', (select coalesce(jsonb_agg(jsonb_build_object('concept_id', c.id, 'label', c.label, 'domain_id', split_part(c.id, '.', 1),
                                                           'state', uc.error_state, 'since', uc.error_since, 'times_failed', uc.error_count)
                                        order by uc.error_since desc), '[]'::jsonb)
               from public.user_concepts uc join public.concepts c on c.id = uc.concept_id
               where uc.user_id = auth.uid() and uc.error_state in ('failed', 'to_review')),
    'corrected_total', (select errors_corrected from public.profiles where id = auth.uid()),
    'mastered_total', (select count(*) from public.user_concepts where user_id = auth.uid() and error_state = 'mastered'))
$$;

create or replace function public.achievements_mine() returns jsonb
language sql security definer set search_path = public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', a.id, 'name', a.name, 'description', a.description,
                                               'unlocked_at', ua.unlocked_at) order by a.sort), '[]'::jsonb)
  from public.achievements a
  left join public.user_achievements ua on ua.achievement_id = a.id and ua.user_id = auth.uid()
$$;

-- ═══════════════════════════════════════════ AMIS
create type public.friendship_status as enum ('pending', 'accepted', 'declined', 'blocked');

create table public.friendships (
  id            uuid primary key default gen_random_uuid(),
  requester_id  uuid not null references public.profiles(id) on delete cascade,
  addressee_id  uuid not null references public.profiles(id) on delete cascade,
  status        public.friendship_status not null default 'pending',
  blocked_by    uuid references public.profiles(id) on delete cascade,
  created_at    timestamptz not null default now(),
  responded_at  timestamptz,
  user_low      uuid generated always as (least(requester_id, addressee_id)) stored,
  user_high     uuid generated always as (greatest(requester_id, addressee_id)) stored,
  check (requester_id <> addressee_id),
  unique (user_low, user_high)
);
create index on public.friendships (addressee_id, status);
create index on public.friendships (requester_id, status);

create or replace function public._are_friends(a uuid, b uuid) returns bool
language sql stable as $$
  select exists (select 1 from public.friendships
                 where user_low = least(a, b) and user_high = greatest(a, b) and status = 'accepted')
$$;

create or replace function public._befriend(a uuid, b uuid) returns void
language plpgsql as $$
begin
  insert into public.friendships (requester_id, addressee_id, status, created_at, responded_at)
  values (a, b, 'accepted', public._now(), public._now())
  on conflict (user_low, user_high) do update set status = 'accepted', responded_at = public._now()
    where public.friendships.status <> 'blocked';
  perform public._unlock(a, 'first_friend');
  perform public._unlock(b, 'first_friend');
end $$;

-- Recherche : 3 caractères minimum, préfixe, 10 résultats, jamais les comptes bloqués.
create or replace function public.search_handles(p_query text) returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user();
begin
  if length(coalesce(p_query, '')) < 3 then return '[]'::jsonb; end if;
  return (select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'handle', p.handle, 'avatar', p.avatar,
                                                       'relation', coalesce(f.status::text, 'none'),
                                                       'incoming', f.addressee_id = v_user) order by lower(p.handle)), '[]'::jsonb)
          from (select * from public.profiles
                where lower(handle) like lower(replace(replace(p_query, '%', ''), '_', '\_')) || '%' and id <> v_user
                order by lower(handle) limit 10) p
          left join public.friendships f on f.user_low = least(v_user, p.id) and f.user_high = greatest(v_user, p.id)
          where f.status is distinct from 'blocked');
end $$;

create or replace function public.friend_request(p_handle text) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  v_target uuid;
  f public.friendships;
begin
  select id into v_target from public.profiles where lower(handle) = lower(p_handle);
  if v_target is null or v_target = v_user then raise exception 'user_not_found'; end if;
  if (select count(*) from public.friendships where requester_id = v_user and created_at > public._now() - interval '1 day') >= 30 then
    raise exception 'rate_limited';
  end if;

  select * into f from public.friendships where user_low = least(v_user, v_target) and user_high = greatest(v_user, v_target) for update;
  if not found then
    insert into public.friendships (requester_id, addressee_id, created_at) values (v_user, v_target, public._now());
    return jsonb_build_object('status', 'pending');
  end if;
  case f.status
    when 'accepted' then return jsonb_build_object('status', 'accepted');
    when 'blocked'  then raise exception 'user_not_found';  -- ne révèle pas le blocage
    when 'pending' then
      if f.addressee_id = v_user then          -- demande croisée : acceptation
        perform public._befriend(v_user, v_target);
        return jsonb_build_object('status', 'accepted');
      end if;
      return jsonb_build_object('status', 'pending');
    when 'declined' then
      if f.responded_at > public._now() - interval '7 days' then return jsonb_build_object('status', 'pending'); end if;
      update public.friendships set requester_id = v_user, addressee_id = v_target, status = 'pending',
                                    created_at = public._now(), responded_at = null where id = f.id;
      return jsonb_build_object('status', 'pending');
  end case;
end $$;

create or replace function public.friend_respond(p_friendship uuid, p_accept bool) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user(); f public.friendships;
begin
  select * into f from public.friendships where id = p_friendship and addressee_id = v_user and status = 'pending' for update;
  if not found then raise exception 'request_not_found'; end if;
  if p_accept then
    perform public._befriend(f.requester_id, v_user);
  else
    update public.friendships set status = 'declined', responded_at = public._now() where id = f.id;
  end if;
  return jsonb_build_object('status', case when p_accept then 'accepted' else 'declined' end);
end $$;

create or replace function public.friend_remove(p_user uuid) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user();
begin
  delete from public.friendships
  where user_low = least(v_user, p_user) and user_high = greatest(v_user, p_user)
    and (status <> 'blocked' or blocked_by = v_user);
end $$;

create or replace function public.friend_block(p_user uuid) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user();
begin
  if p_user = v_user then raise exception 'invalid'; end if;
  insert into public.friendships (requester_id, addressee_id, status, blocked_by, created_at, responded_at)
  values (v_user, p_user, 'blocked', v_user, public._now(), public._now())
  on conflict (user_low, user_high) do update set status = 'blocked', blocked_by = v_user, responded_at = public._now();
  -- Les ligues communes ne sont pas modifiées : chacun reste libre de quitter une ligue.
end $$;

-- Vue d'ensemble : amis (avec leur 5 du jour), demandes reçues / envoyées.
create or replace function public.friends_overview() returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user();
begin
  return jsonb_build_object(
    'friends', (select coalesce(jsonb_agg(jsonb_build_object(
                  'id', p.id, 'handle', p.handle, 'avatar', p.avatar,
                  'streak', public._streak_effective(p.id),
                  'today', (select jsonb_build_object('score', r.score, 'total_ms', r.total_ms, 'status', r.status,
                                                      'answers', (select jsonb_agg(coalesce(da.is_correct, false) order by da.position)
                                                                  from public.daily_answers da where da.run_id = r.id))
                            from public.daily_runs r
                            where r.user_id = p.id and r.daily_date = public._user_today(p.id) and r.status = 'finished'))
                  order by lower(p.handle)), '[]'::jsonb)
                from public.friendships f
                join public.profiles p on p.id = case when f.requester_id = v_user then f.addressee_id else f.requester_id end
                where (f.requester_id = v_user or f.addressee_id = v_user) and f.status = 'accepted'),
    'incoming', (select coalesce(jsonb_agg(jsonb_build_object('friendship_id', f.id, 'id', p.id, 'handle', p.handle, 'avatar', p.avatar,
                                                             'created_at', f.created_at) order by f.created_at desc), '[]'::jsonb)
                 from public.friendships f join public.profiles p on p.id = f.requester_id
                 where f.addressee_id = v_user and f.status = 'pending'),
    'outgoing', (select coalesce(jsonb_agg(jsonb_build_object('friendship_id', f.id, 'id', p.id, 'handle', p.handle, 'avatar', p.avatar)
                                           order by f.created_at desc), '[]'::jsonb)
                 from public.friendships f join public.profiles p on p.id = f.addressee_id
                 where f.requester_id = v_user and f.status = 'pending'));
end $$;

-- ═══════════════════════════════════════════ PARRAINAGE
create type public.referral_status as enum ('claimed', 'qualified', 'rejected');

create table public.referrals (
  id             uuid primary key default gen_random_uuid(),
  inviter_id     uuid not null references public.profiles(id) on delete cascade,
  invitee_id     uuid not null unique references public.profiles(id) on delete cascade,
  status         public.referral_status not null default 'claimed',
  reject_reason  text,
  device_hash    text,
  created_at     timestamptz not null default now(),
  qualified_at   timestamptz
);
create index on public.referrals (inviter_id, status);

-- Règles :
--  · l'invité doit avoir un compte non anonyme de moins de 7 jours, jamais parrainé ;
--  · pas d'auto-parrainage (même compte ou même appareil que l'invitant) ; un appareil ne sert qu'une fois ;
--  · l'invité reçoit 100 graines immédiatement (sans valeur transférable : aucun intérêt à multiplier les comptes) ;
--  · l'invitant reçoit 150 graines quand l'invité termine son premier 5 du jour ; 20 parrainages récompensés / 30 jours ;
--  · paliers : 3, 5, 10 invités qualifiés.
create or replace function public.referral_claim(p_code text, p_device_hash text) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  v_inviter uuid;
  me public.profiles;
  v_reason text;
begin
  select * into me from public.profiles where id = v_user for update;
  select id into v_inviter from public.profiles where referral_code = upper(trim(p_code));
  if v_inviter is null then raise exception 'referral_code_invalid'; end if;
  if exists (select 1 from public.referrals where invitee_id = v_user) or me.referred_by is not null then
    raise exception 'referral_already_claimed';
  end if;
  if coalesce((select is_anonymous from auth.users where id = v_user), true) then raise exception 'referral_requires_account'; end if;

  v_reason := case
    when v_inviter = v_user then 'self'
    when me.created_at < public._now() - interval '7 days' then 'account_too_old'
    when p_device_hash is null or length(p_device_hash) < 16 then 'no_device'
    when exists (select 1 from public.user_devices where user_id = v_inviter and device_hash = p_device_hash) then 'same_device'
    when exists (select 1 from public.referrals where device_hash = p_device_hash) then 'device_reused'
  end;

  perform public.register_device(p_device_hash);
  insert into public.referrals (inviter_id, invitee_id, status, reject_reason, device_hash, created_at)
  values (v_inviter, v_user, case when v_reason is null then 'claimed' else 'rejected' end::public.referral_status,
          v_reason, p_device_hash, public._now());
  if v_reason is not null then
    return jsonb_build_object('status', 'rejected', 'reason', v_reason);
  end if;

  update public.profiles set referred_by = v_inviter where id = v_user;
  perform public._grant(v_user, 'seeds', 100, 'referral_invitee', v_inviter::text, 'referral_invitee');
  perform public._befriend(v_inviter, v_user);
  return jsonb_build_object('status', 'claimed', 'seeds', 100,
                            'inviter', (select handle from public.profiles where id = v_inviter));
end $$;

create or replace function public._referral_on_first_daily(p_user uuid) returns void
language plpgsql as $$
declare
  r public.referrals;
  v_count int;
begin
  select * into r from public.referrals where invitee_id = p_user and status = 'claimed' for update;
  if not found then return; end if;
  if (select count(*) from public.daily_runs where user_id = p_user and status = 'finished') < 1 then return; end if;

  update public.referrals set status = 'qualified', qualified_at = public._now() where id = r.id;
  if (select count(*) from public.referrals where inviter_id = r.inviter_id and status = 'qualified'
        and qualified_at > public._now() - interval '30 days') <= 20 then
    perform public._grant(r.inviter_id, 'seeds', 150, 'referral_inviter', r.id::text, 'referral_inviter:' || r.id);
  end if;
  select count(*) into v_count from public.referrals where inviter_id = r.inviter_id and status = 'qualified';
  if v_count in (3, 5, 10) then
    perform public._grant(r.inviter_id, 'seeds', case v_count when 3 then 150 when 5 then 250 else 500 end,
                          'referral_tier', v_count::text, 'referral_tier:' || v_count);
  end if;
end $$;

create or replace function public.referral_overview() returns jsonb
language sql security definer set search_path = public, pg_temp as $$
  select jsonb_build_object(
    'code', (select referral_code from public.profiles where id = auth.uid()),
    'qualified', (select count(*) from public.referrals where inviter_id = auth.uid() and status = 'qualified'),
    'pending', (select count(*) from public.referrals where inviter_id = auth.uid() and status = 'claimed'),
    'tiers', '[3, 5, 10]'::jsonb)
$$;

-- ═══════════════════════════════════════════ LIGUES PRIVÉES
create type public.league_period as enum ('week', 'month');

create table public.leagues (
  id           uuid primary key default gen_random_uuid(),
  name         text not null check (length(trim(name)) between 3 and 40),
  owner_id     uuid not null references public.profiles(id) on delete cascade,
  period       public.league_period not null default 'week',
  invite_code  text not null unique,
  created_at   timestamptz not null default now()
);

create table public.league_members (
  league_id  uuid not null references public.leagues(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  role       text not null default 'member' check (role in ('owner', 'member')),
  joined_at  timestamptz not null default now(),
  primary key (league_id, user_id)
);
create index on public.league_members (user_id);

create or replace function public._is_member(p_league uuid, p_user uuid) returns bool
language sql stable as $$
  select exists (select 1 from public.league_members where league_id = p_league and user_id = p_user)
$$;

-- Bornes de période (dates de Daily) : semaine ISO (lundi) ou mois civil ; p_offset = 0 courant, -1 précédent.
create or replace function public._period_bounds(p_period public.league_period, p_ref date, p_offset int,
                                                 out start_date date, out end_date date)
language sql immutable as $$
  select s::date, (s + case p_period when 'week' then interval '7 days' else interval '1 month' end)::date - 1
  from (select date_trunc(case p_period when 'week' then 'week' else 'month' end, p_ref::timestamp)
               + p_offset * case p_period when 'week' then interval '7 days' else interval '1 month' end as s) t
$$;

create or replace function public.league_create(p_name text, p_period public.league_period) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user(); v_id uuid; v_code text;
begin
  if (select count(*) from public.league_members where user_id = v_user) >= 10 then raise exception 'too_many_leagues'; end if;
  if (select count(*) from public.leagues where owner_id = v_user and created_at > public._now() - interval '1 day') >= 5 then
    raise exception 'rate_limited';
  end if;
  loop
    v_code := public._random_code(6);
    exit when not exists (select 1 from public.leagues where invite_code = v_code);
  end loop;
  insert into public.leagues (name, owner_id, period, invite_code, created_at)
  values (trim(p_name), v_user, p_period, v_code, public._now()) returning id into v_id;
  insert into public.league_members (league_id, user_id, role, joined_at) values (v_id, v_user, 'owner', public._now());
  return public.league_standings(v_id, 0);
end $$;

create or replace function public.league_join(p_code text) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user(); l public.leagues;
begin
  select * into l from public.leagues where invite_code = upper(trim(p_code));
  if not found then raise exception 'league_not_found'; end if;
  if not public._is_member(l.id, v_user) then
    if (select count(*) from public.league_members where league_id = l.id) >= 50 then raise exception 'league_full'; end if;
    if (select count(*) from public.league_members where user_id = v_user) >= 10 then raise exception 'too_many_leagues'; end if;
    insert into public.league_members (league_id, user_id, joined_at) values (l.id, v_user, public._now());
  end if;
  return public.league_standings(l.id, 0);
end $$;

create or replace function public.league_leave(p_league uuid) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user(); v_next uuid;
begin
  delete from public.league_members where league_id = p_league and user_id = v_user;
  if (select owner_id from public.leagues where id = p_league) = v_user then
    select user_id into v_next from public.league_members where league_id = p_league order by joined_at limit 1;
    if v_next is null then
      delete from public.leagues where id = p_league;
    else
      update public.leagues set owner_id = v_next where id = p_league;
      update public.league_members set role = 'owner' where league_id = p_league and user_id = v_next;
    end if;
  end if;
end $$;

create or replace function public.league_rename(p_league uuid, p_name text) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  update public.leagues set name = trim(p_name) where id = p_league and owner_id = public._require_user();
  if not found then raise exception 'forbidden'; end if;
end $$;

-- Classement : somme des scores du 5 du jour sur la période ; départage au temps total, puis jours joués.
create or replace function public.league_standings(p_league uuid, p_offset int default 0) returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  l public.leagues;
  b record;
begin
  select * into l from public.leagues where id = p_league;
  if not found or not public._is_member(p_league, v_user) then raise exception 'league_not_found'; end if;
  select * into b from public._period_bounds(l.period, public._user_today(v_user), least(p_offset, 0));
  return jsonb_build_object(
    'id', l.id, 'name', l.name, 'period', l.period, 'invite_code', l.invite_code,
    'is_owner', l.owner_id = v_user,
    'start_date', b.start_date, 'end_date', b.end_date,
    'standings', (select coalesce(jsonb_agg(row_to_json(t)::jsonb order by t.rank), '[]'::jsonb) from (
        select rank() over (order by coalesce(sum(r.score), 0) desc, coalesce(sum(r.total_ms), 0) asc,
                                     count(r.id) desc) as rank,
               p.id, p.handle, p.avatar,
               coalesce(sum(r.score), 0)::int as points,
               count(r.id)::int as days,
               coalesce(sum(r.total_ms), 0)::int as total_ms,
               p.id = v_user as is_me
        from public.league_members m
        join public.profiles p on p.id = m.user_id
        left join public.daily_runs r on r.user_id = m.user_id and r.status in ('finished', 'expired')
                                     and r.daily_date between b.start_date and b.end_date
        where m.league_id = l.id
        group by p.id, p.handle, p.avatar) t));
end $$;

create or replace function public.leagues_mine() returns jsonb
language sql security definer set search_path = public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', l.id, 'name', l.name, 'period', l.period,
                                               'members', (select count(*) from public.league_members x where x.league_id = l.id),
                                               'invite_code', l.invite_code) order by m.joined_at), '[]'::jsonb)
  from public.league_members m join public.leagues l on l.id = m.league_id
  where m.user_id = auth.uid()
$$;

-- ═══════════════════════════════════════════ SUPPRESSION DE COMPTE (exigence App Store)
-- Supprime l'utilisateur d'auth : tout cascade. Les statistiques agrégées des questions sont conservées.
create or replace function public.delete_account() returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user();
begin
  delete from public.leagues where owner_id = v_user
    and not exists (select 1 from public.league_members m where m.league_id = leagues.id and m.user_id <> v_user);
  update public.leagues l set owner_id = (select m.user_id from public.league_members m
                                          where m.league_id = l.id and m.user_id <> v_user order by m.joined_at limit 1)
  where l.owner_id = v_user;
  delete from auth.users where id = v_user;
end $$;
