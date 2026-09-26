-- CULT FIVE — 0012 Signalements et outils d'admin
-- Les joueurs peuvent signaler une question (réponse fausse, ambiguë, faute, autre) : elle passe « à revoir ».
-- L'admin web liste, trie (plus dures, plus faciles, taux de réussite, signalements) et corrige.
-- Les thèmes retirés de la taxonomie restent en base (historique) mais sont inactifs.

alter table public.subdomains add column is_active bool not null default true;

create table public.question_reports (
  id          bigint generated always as identity primary key,
  question_id uuid not null references public.questions(id) on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  reason      text not null check (reason in ('wrong_answer', 'ambiguous', 'typo', 'outdated', 'other')),
  note        text check (length(note) <= 300),
  created_at  timestamptz not null default now(),
  resolved_at timestamptz,
  unique (question_id, user_id)
);
create index on public.question_reports (question_id) where resolved_at is null;
alter table public.question_reports enable row level security;

-- Signalement par un joueur : une fois par question, 20 par jour au plus.
create or replace function public.report_question(p_question uuid, p_reason text, p_note text default null) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  v_label text;
begin
  if p_reason not in ('wrong_answer', 'ambiguous', 'typo', 'outdated', 'other') then raise exception 'invalid_reason'; end if;
  if not exists (select 1 from public.questions where id = p_question) then raise exception 'question_not_found'; end if;
  if (select count(*) from public.question_reports where user_id = v_user and created_at > public._now() - interval '1 day') >= 20 then
    raise exception 'rate_limited';
  end if;
  insert into public.question_reports (question_id, user_id, reason, note, created_at)
  values (p_question, v_user, p_reason, left(p_note, 300), public._now())
  on conflict (question_id, user_id) do nothing;
  v_label := case p_reason when 'wrong_answer' then 'réponse fausse' when 'ambiguous' then 'ambiguë' when 'typo' then 'faute'
                           when 'outdated' then 'plus à jour' else 'autre' end;
  update public.questions set needs_review = true,
    review_reason = coalesce(review_reason, 'Signalée par un joueur (' || v_label || ')')
  where id = p_question;
  return jsonb_build_object('reported', true);
end $$;

-- Liste admin : filtres + tri + taux de réussite et signalements ouverts.
create or replace function public.admin_questions(p_filter jsonb default '{}'::jsonb, p_limit int default 50, p_offset int default 0)
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare v_sort text := coalesce(p_filter ->> 'sort', 'recent');
begin
  perform public._require_admin();
  return (with base as (
      select q.*,
             case when q.answer_count > 0 then round(q.correct_count::numeric / q.answer_count, 3) end as success_rate,
             (select count(*) from public.question_reports r where r.question_id = q.id and r.resolved_at is null) as open_reports
      from public.questions q where
            (p_filter ->> 'domain_id' is null or q.domain_id = p_filter ->> 'domain_id')
        and (p_filter ->> 'subdomain_id' is null or q.subdomain_id = p_filter ->> 'subdomain_id')
        and (p_filter ->> 'status' is null or q.status::text = p_filter ->> 'status')
        and (p_filter ->> 'type' is null or q.type::text = p_filter ->> 'type')
        and (p_filter ->> 'origin' is null or q.origin::text = p_filter ->> 'origin')
        and (p_filter ->> 'needs_review' is null or q.needs_review = (p_filter ->> 'needs_review')::bool)
        and (p_filter ->> 'search' is null or q.prompt ilike '%' || (p_filter ->> 'search') || '%'
             or q.external_key ilike '%' || (p_filter ->> 'search') || '%')
        and (p_filter ->> 'min_difficulty' is null or q.difficulty_effective >= (p_filter ->> 'min_difficulty')::real)
        and (p_filter ->> 'max_difficulty' is null or q.difficulty_effective <= (p_filter ->> 'max_difficulty')::real)
        and (p_filter ->> 'min_answers' is null or q.answer_count >= (p_filter ->> 'min_answers')::int)
        and (p_filter ->> 'reported' is null or exists (select 1 from public.question_reports r
                                                         where r.question_id = q.id and r.resolved_at is null))
    )
    select jsonb_build_object(
      'total', (select count(*) from base),
      'items', coalesce((select jsonb_agg(to_jsonb(t)) from (
          select * from base
          order by
            case when v_sort = 'hardest' then difficulty_effective end desc nulls last,
            case when v_sort = 'easiest' then difficulty_effective end asc nulls last,
            case when v_sort = 'lowest_success' then success_rate end asc nulls last,
            case when v_sort = 'most_answered' then answer_count end desc nulls last,
            case when v_sort = 'reports' then open_reports end desc nulls last,
            created_at desc
          limit least(p_limit, 200) offset p_offset) t), '[]'::jsonb)));
end $$;

create or replace function public.admin_question_reports(p_question uuid) returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  perform public._require_admin();
  return coalesce((select jsonb_agg(jsonb_build_object('reason', r.reason, 'note', r.note, 'created_at', r.created_at,
                                                        'resolved_at', r.resolved_at, 'handle', p.handle) order by r.created_at desc)
                   from public.question_reports r join public.profiles p on p.id = r.user_id where r.question_id = p_question), '[]'::jsonb);
end $$;

-- Clôture des signalements d'une question (après correction ou si non fondés).
create or replace function public.admin_resolve_reports(p_question uuid) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_admin uuid := public._require_admin();
begin
  update public.question_reports set resolved_at = now() where question_id = p_question and resolved_at is null;
  update public.questions set needs_review = false, review_reason = null where id = p_question;
  insert into public.question_reviews (question_id, reviewer_id, action, note) values (p_question, v_admin, 'approve', 'signalements clos');
end $$;

create or replace function public.admin_dashboard() returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  perform public._require_admin();
  return jsonb_build_object(
    'questions_by_status', (select jsonb_object_agg(status, n) from (select status, count(*) n from public.questions group by 1) t),
    'published_by_domain', (select jsonb_object_agg(domain_id, n) from (select domain_id, count(*) n from public.questions
                                                                         where status = 'published' group by 1) t),
    'published_by_subdomain', (select jsonb_object_agg(subdomain_id, n) from (select subdomain_id, count(*) n from public.questions
                                                                               where status = 'published' group by 1) t),
    'needs_review', (select count(*) from public.questions where needs_review),
    'open_reports', (select count(*) from public.question_reports where resolved_at is null),
    'users', (select count(*) from public.profiles),
    'daily_players_today', (select count(*) from public.daily_runs where daily_date = current_date and status = 'finished'),
    'answers_7d', (select count(*) from public.question_attempts where created_at > now() - interval '7 days'),
    'upcoming_dailies', (select coalesce(jsonb_agg(daily_date order by daily_date), '[]'::jsonb) from public.daily_sets where daily_date >= current_date));
end $$;

revoke execute on function public.report_question(uuid, text, text) from public, anon;
grant execute on function public.report_question(uuid, text, text) to authenticated;
revoke execute on function public.admin_question_reports(uuid) from public, anon;
grant execute on function public.admin_question_reports(uuid) to authenticated;
revoke execute on function public.admin_resolve_reports(uuid) from public, anon;
grant execute on function public.admin_resolve_reports(uuid) to authenticated;
