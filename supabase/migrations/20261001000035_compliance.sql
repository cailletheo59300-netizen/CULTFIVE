-- Brainlix — 0035 Conformité : signalement des joueurs et des ligues, filtre des noms de ligue, export des données
-- personnelles (droit d'accès RGPD), durées de conservation.

-- ─────────────────────────────────────────── Signalements (règle Apple sur le contenu des joueurs)
create table public.content_reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  target_kind text not null check (target_kind in ('user', 'league')),
  target_id   uuid not null,
  reason      text not null check (reason in ('name', 'behavior', 'cheating', 'other')),
  note        text check (length(note) <= 500),
  created_at  timestamptz not null default now(),
  resolved_at timestamptz
);
create index on public.content_reports (created_at desc) where resolved_at is null;
alter table public.content_reports enable row level security;
revoke all on public.content_reports from public, anon, authenticated;

-- On ne signale que ce qu'on voit : un ami, un membre d'une de ses ligues, un adversaire de duel, ou sa ligue.
create or replace function public.report_content(p_kind text, p_target uuid, p_reason text, p_note text default null) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user();
begin
  if p_kind not in ('user', 'league') or p_reason not in ('name', 'behavior', 'cheating', 'other') then raise exception 'invalid'; end if;
  if (select count(*) from public.content_reports where reporter_id = v_user and created_at > public._now() - interval '1 day') >= 20 then
    raise exception 'rate_limited';
  end if;
  if p_kind = 'league' and not public._is_member(p_target, v_user) then raise exception 'league_not_found'; end if;
  if p_kind = 'user' and (p_target = v_user or not (
       public._are_friends(v_user, p_target)
       or exists (select 1 from public.league_members a join public.league_members b on a.league_id = b.league_id
                  where a.user_id = v_user and b.user_id = p_target)
       or exists (select 1 from public.duels d where (d.challenger_id = v_user and d.opponent_id = p_target)
                                               or (d.challenger_id = p_target and d.opponent_id = v_user)))) then
    raise exception 'user_not_found';
  end if;
  insert into public.content_reports (reporter_id, target_kind, target_id, reason, note, created_at)
  values (v_user, p_kind, p_target, p_reason, left(nullif(trim(p_note), ''), 500), public._now());
end $$;

-- Admin : signalements ouverts, avec le nom visé.
create or replace function public.admin_content_reports() returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  perform public._require_admin();
  return (select coalesce(jsonb_agg(jsonb_build_object(
      'id', r.id, 'kind', r.target_kind, 'target_id', r.target_id, 'reason', r.reason, 'note', r.note, 'created_at', r.created_at,
      'reporter', (select handle from public.profiles where id = r.reporter_id),
      'target', case r.target_kind when 'user' then (select handle from public.profiles where id = r.target_id)
                                   else (select name from public.leagues where id = r.target_id) end,
      'count', (select count(*) from public.content_reports x where x.target_id = r.target_id and x.resolved_at is null))
    order by r.created_at desc), '[]'::jsonb)
    from public.content_reports r where r.resolved_at is null);
end $$;

create or replace function public.admin_content_resolve(p_target uuid) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  perform public._require_admin();
  update public.content_reports set resolved_at = public._now() where target_id = p_target and resolved_at is null;
end $$;

create or replace function public.admin_league_rename(p_league uuid, p_name text) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  perform public._require_admin();
  if length(trim(coalesce(p_name, ''))) not between 3 and 40 then raise exception 'invalid_name'; end if;
  update public.leagues set name = trim(p_name) where id = p_league;
end $$;

-- ─────────────────────────────────────────── Noms de ligue : mots interdits des pseudos
-- Comparés mot par mot (début de mot) pour ne pas refuser « Ligue technique » ou « On habite ici » ; les termes
-- réservés aux pseudos (admin, support, officiel…) ne concernent pas les ligues.
create or replace function public._text_is_clean(p_text text) returns bool
language sql stable as $$
  select not exists (
    select 1
    from regexp_split_to_table(lower(translate(coalesce(p_text, ''), 'ÉÈÊËÀÂÄÎÏÔÖÙÛÜÇéèêëàâäîïôöùûüç',
                                                                    'eeeeaaaiioouuuceeeeaaaiioouuuc')), '[^a-z0-9_]+') w
    join public.blocked_terms b on left(w, length(b.term)) = b.term
    where b.term not in ('admin', 'cultfive', 'cult_five', 'support', 'moderat', 'official', 'officiel'))
$$;

do $$
declare v_old text; v_new text;
begin
  v_old := pg_get_functiondef('public.league_create(text, int, text[], text, text, bool, int)'::regprocedure);
  v_new := replace(v_old,
    '  if p_count not in (5, 10, 15, 20) then raise exception ''invalid_count''; end if;',
    '  if not public._text_is_clean(p_name) then raise exception ''name_not_allowed''; end if;
  if p_count not in (5, 10, 15, 20) then raise exception ''invalid_count''; end if;');
  if v_new = v_old then raise exception '0035: league_create inchangée'; end if;
  execute v_new;
end $$;

create or replace function public.league_rename(p_league uuid, p_name text) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if length(trim(coalesce(p_name, ''))) not between 3 and 40 then raise exception 'invalid_name'; end if;
  if not public._text_is_clean(p_name) then raise exception 'name_not_allowed'; end if;
  update public.leagues set name = trim(p_name) where id = p_league and owner_id = public._require_user();
  if not found then raise exception 'forbidden'; end if;
end $$;

-- ─────────────────────────────────────────── Export des données personnelles (droit d'accès)
create or replace function public.my_data_export() returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user();
begin
  return jsonb_build_object(
    'generated_at', public._now(),
    'about', 'Données personnelles associées à ton compte Brainlix. Questions : bonjour@brainlix.site.',
    'account', (select jsonb_build_object('id', u.id, 'email', u.email, 'anonymous', u.is_anonymous, 'created_at', u.created_at)
                from auth.users u where u.id = v_user),
    'profile', (select to_jsonb(p) - 'referral_code' || jsonb_build_object('referral_code', p.referral_code)
                from public.profiles p where p.id = v_user),
    'levels', (select coalesce(jsonb_agg(jsonb_build_object('scope', scope_id, 'level', round(mu::numeric, 2), 'answers', n,
                                                            'correct', correct)), '[]'::jsonb)
               from public.user_skills where user_id = v_user),
    'answers', (select coalesce(jsonb_agg(jsonb_build_object('at', created_at, 'question_id', question_id, 'context', context,
                                                             'correct', is_correct, 'ms', response_ms) order by created_at), '[]'::jsonb)
                from public.question_attempts where user_id = v_user),
    'daily', (select coalesce(jsonb_agg(jsonb_build_object('date', daily_date, 'status', status, 'score', score, 'total_ms', total_ms)
                                        order by daily_date), '[]'::jsonb)
              from public.daily_runs where user_id = v_user),
    'friends', (select coalesce(jsonb_agg(jsonb_build_object('handle', p.handle, 'status', f.status, 'since', f.created_at)), '[]'::jsonb)
                from public.friendships f
                join public.profiles p on p.id = case when f.requester_id = v_user then f.addressee_id else f.requester_id end
                where v_user in (f.requester_id, f.addressee_id)),
    'leagues', (select coalesce(jsonb_agg(jsonb_build_object('name', l.name, 'role', m.role, 'joined_at', m.joined_at)), '[]'::jsonb)
                from public.league_members m join public.leagues l on l.id = m.league_id where m.user_id = v_user),
    'duels', (select coalesce(jsonb_agg(jsonb_build_object('created_at', d.created_at, 'status', d.status,
                                                           'won', d.winner_id = v_user)), '[]'::jsonb)
              from public.duels d where v_user in (d.challenger_id, d.opponent_id)),
    'ledger', (select coalesce(jsonb_agg(jsonb_build_object('at', created_at, 'currency', currency, 'amount', amount, 'reason', reason)
                                         order by created_at), '[]'::jsonb)
               from public.ledger where user_id = v_user),
    'items', (select coalesce(jsonb_agg(item_id), '[]'::jsonb) from public.user_items where user_id = v_user),
    'chests', (select coalesce(jsonb_agg(jsonb_build_object('tier', tier, 'source', source, 'opened_at', opened_at)), '[]'::jsonb)
               from public.user_chests where user_id = v_user),
    'usage_events', (select coalesce(jsonb_agg(jsonb_build_object('at', created_at, 'name', name, 'props', props)), '[]'::jsonb)
                     from public.app_events where user_id = v_user),
    'ad_rewards', (select coalesce(jsonb_agg(jsonb_build_object('at', created_at, 'kind', kind, 'claimed_at', claimed_at)), '[]'::jsonb)
                   from public.ad_views where user_id = v_user),
    'question_reports', (select coalesce(jsonb_agg(jsonb_build_object('at', created_at, 'question_id', question_id, 'reason', reason)),
                                         '[]'::jsonb)
                         from public.question_reports where user_id = v_user));
end $$;

-- ─────────────────────────────────────────── Durées de conservation
-- Journal d'usage, vues de pubs et essais de codes : 13 mois au plus (24 h pour les essais de codes).
create or replace function public.cron_retention() returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_events int; v_ads int; v_codes int; v_reports int;
begin
  delete from public.app_events where created_at < public._now() - interval '13 months';
  get diagnostics v_events = row_count;
  delete from public.ad_views where created_at < public._now() - interval '13 months';
  get diagnostics v_ads = row_count;
  delete from public.league_code_attempts where created_at < public._now() - interval '1 day';
  get diagnostics v_codes = row_count;
  delete from public.content_reports where resolved_at < public._now() - interval '13 months';
  get diagnostics v_reports = row_count;
  return jsonb_build_object('app_events', v_events, 'ad_views', v_ads, 'code_attempts', v_codes, 'content_reports', v_reports);
end $$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('brainlix-retention', '17 3 * * *', 'select public.cron_retention()');
  end if;
exception when others then
  raise notice 'pg_cron indisponible : purge non planifiée (%)', sqlerrm;
end $$;

-- ─────────────────────────────────────────── Droits
revoke execute on function public._text_is_clean(text), public.cron_retention() from public, anon, authenticated;
revoke execute on function public.report_content(text, uuid, text, text), public.my_data_export(),
  public.admin_content_reports(), public.admin_content_resolve(uuid), public.admin_league_rename(uuid, text),
  public.league_rename(uuid, text) from public, anon;
grant execute on function public.report_content(text, uuid, text, text), public.my_data_export(),
  public.admin_content_reports(), public.admin_content_resolve(uuid), public.admin_league_rename(uuid, text),
  public.league_rename(uuid, text) to authenticated;
