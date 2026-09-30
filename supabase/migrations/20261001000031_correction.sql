-- Brainlix — 0031 « Corrige tes erreurs » en fin de partie
-- Après une partie, le joueur peut rejouer une fois les questions qu'il a ratées. Chaque question corrigée
-- rembourse l'Elo que l'erreur avait fait perdre (domaine et thème), sans jamais dépasser le niveau d'avant la partie :
-- on annule des pertes, on ne gagne jamais d'Elo. Rien d'autre ne bouge : ni points, ni XP, ni graines, ni score,
-- ni statistiques, ni défis ; la notion reste dans « Mes erreurs ».
-- Seulement pour la dernière partie du joueur, dans l'heure qui suit, une fois par partie.
-- Déblocage : gratuit (3 par jour) en attendant les pubs ; la pub vérifiée prendra le relais.

-- Pour rembourser au plus juste, chaque réponse garde le niveau avant/après qu'elle a produit.
alter table public.question_attempts
  add column dom_mu_before real,
  add column dom_mu_after real,
  add column sub_mu_after real;

do $$
declare v_old text; v_new text;
begin
  v_old := pg_get_functiondef('public._record_attempt(uuid, uuid, jsonb, int, public.attempt_context, uuid, uuid, bool, bool)'::regprocedure);
  v_new := replace(replace(v_old,
    'created_at, second_chance)',
    'created_at, second_chance, dom_mu_before, dom_mu_after, sub_mu_after)'),
    'v_seen, v_now, coalesce(p_second_chance, false));',
    'v_seen, v_now, coalesce(p_second_chance, false),
          case when p_ranked then v_dom.mu_before end, case when p_ranked then v_dom.mu_after end,
          case when p_ranked then v_sub.mu_after end);');
  if v_new not like '%dom_mu_before, dom_mu_after, sub_mu_after)%' or v_new not like '%case when p_ranked then v_sub.mu_after end);%' then
    raise exception '0031: _record_attempt inchangée';
  end if;
  execute v_new;
end $$;

create table public.play_corrections (
  session_id   uuid primary key references public.play_sessions(id) on delete cascade,
  user_id      uuid not null references public.profiles(id) on delete cascade,
  via          text not null check (via in ('free', 'ad')),
  question_ids uuid[] not null,
  started_at   timestamptz not null default now(),
  finished_at  timestamptz,
  corrected    int,
  refunds      jsonb
);
create index on public.play_corrections (user_id, started_at desc);
alter table public.play_corrections enable row level security;
revoke all on public.play_corrections from public, anon, authenticated;

-- Questions ratées d'une partie (la dernière tentative enregistrée pour chaque question).
create or replace function public._missed_questions(p_user uuid, p_session uuid) returns uuid[]
language sql stable as $$
  select coalesce(array_agg(question_id order by created_at), '{}') from public.question_attempts
  where user_id = p_user and session_id = p_session and not is_correct
$$;

-- Ouvre la correction de la dernière partie. Renvoie les questions à rejouer (le pack de la partie contient déjà
-- leurs énoncés et réponses côté app).
create or replace function public.play_correction_start(p_session uuid, p_via text default 'free') returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  s public.play_sessions;
  v_missed uuid[];
  c public.play_corrections;
begin
  select * into s from public.play_sessions where id = p_session and user_id = v_user;
  if not found then raise exception 'session_not_found'; end if;
  select * into c from public.play_corrections where session_id = p_session;
  if found then
    if c.finished_at is not null then raise exception 'correction_done'; end if;
    return jsonb_build_object('question_ids', to_jsonb(c.question_ids), 'ranked', s.ranked);
  end if;
  if s.mode = 'onboarding' then raise exception 'correction_unavailable'; end if;
  -- Seulement la dernière partie, dans l'heure : le remboursement se calcule sur le niveau d'avant cette partie.
  if exists (select 1 from public.play_sessions s2 where s2.user_id = v_user and s2.created_at > s.created_at)
     or public._now() - s.created_at > interval '1 hour' then
    raise exception 'correction_expired';
  end if;
  v_missed := public._missed_questions(v_user, p_session);
  if cardinality(v_missed) = 0 then raise exception 'nothing_to_correct'; end if;
  if p_via not in ('free', 'ad') then raise exception 'invalid_via'; end if;
  if p_via = 'ad' then
    raise exception 'ad_not_verified';  -- branché avec la vérification des pubs
  end if;
  if (select count(*) from public.play_corrections where user_id = v_user and via = 'free'
        and started_at > public._now() - interval '1 day') >= 3 then
    raise exception 'correction_limit';
  end if;
  insert into public.play_corrections (session_id, user_id, via, question_ids, started_at)
  values (p_session, v_user, p_via, v_missed, public._now());
  return jsonb_build_object('question_ids', to_jsonb(v_missed), 'ranked', s.ranked);
end $$;

-- Réponses de la correction : une par question ratée. Rembourse l'Elo perdu sur les questions corrigées.
create or replace function public.play_correction_submit(p_session uuid, p_answers jsonb) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  s public.play_sessions;
  c public.play_corrections;
  a jsonb;
  q public.questions;
  v_corrected uuid[] := '{}';
  r record;
  v_now_mu real;
  v_refund real;
  v_refunds jsonb := '[]'::jsonb;
begin
  select * into s from public.play_sessions where id = p_session and user_id = v_user;
  if not found then raise exception 'session_not_found'; end if;
  select * into c from public.play_corrections where session_id = p_session for update;
  if not found then raise exception 'correction_not_started'; end if;
  if c.finished_at is not null then
    return jsonb_build_object('corrected', c.corrected, 'total', cardinality(c.question_ids), 'refunds', c.refunds, 'duplicate', true);
  end if;
  if jsonb_typeof(p_answers) <> 'array' then raise exception 'invalid_answers'; end if;

  for a in select * from jsonb_array_elements(p_answers) loop
    continue when not ((a ->> 'question_id')::uuid = any (c.question_ids)) or (a ->> 'question_id')::uuid = any (v_corrected);
    select * into q from public.questions where id = (a ->> 'question_id')::uuid;
    if public._evaluate(q.type, q.answer, a -> 'given') then v_corrected := v_corrected || q.id; end if;
  end loop;

  if s.ranked and cardinality(v_corrected) > 0 then
    -- Domaines puis thèmes : pertes des questions corrigées, plafonnées au niveau d'avant la partie.
    for r in
      select scope_id, sum(loss) as losses, max(start_mu) as start_mu, bool_or(is_domain) as is_domain from (
        select q2.domain_id as scope_id, greatest(a2.dom_mu_before - a2.dom_mu_after, 0) as loss,
               (select a3.dom_mu_before from public.question_attempts a3 join public.questions q3 on q3.id = a3.question_id
                where a3.session_id = p_session and a3.user_id = v_user and q3.domain_id = q2.domain_id
                order by a3.created_at, a3.id limit 1) as start_mu, true as is_domain
        from public.question_attempts a2 join public.questions q2 on q2.id = a2.question_id
        where a2.session_id = p_session and a2.user_id = v_user and a2.question_id = any (v_corrected) and a2.dom_mu_before is not null
        union all
        select q2.subdomain_id, greatest(a2.user_skill_before - a2.sub_mu_after, 0),
               (select a3.user_skill_before from public.question_attempts a3 join public.questions q3 on q3.id = a3.question_id
                where a3.session_id = p_session and a3.user_id = v_user and q3.subdomain_id = q2.subdomain_id
                order by a3.created_at, a3.id limit 1), false
        from public.question_attempts a2 join public.questions q2 on q2.id = a2.question_id
        where a2.session_id = p_session and a2.user_id = v_user and a2.question_id = any (v_corrected) and a2.sub_mu_after is not null
      ) x group by scope_id
    loop
      select mu into v_now_mu from public.user_skills where user_id = v_user and scope_id = r.scope_id for update;
      continue when v_now_mu is null or r.start_mu is null;
      v_refund := least(r.losses, greatest(r.start_mu - v_now_mu, 0));
      continue when v_refund <= 0;
      update public.user_skills set mu = mu + v_refund where user_id = v_user and scope_id = r.scope_id;
      update public.user_skill_snapshots set mu = mu + v_refund
       where user_id = v_user and scope_id = r.scope_id and day = (public._now() at time zone 'UTC')::date;
      if r.is_domain then
        v_refunds := v_refunds || jsonb_build_object('domain_id', r.scope_id,
          'cote_refund', public._cote(v_now_mu + v_refund) - public._cote(v_now_mu),
          'cote_after', public._cote(v_now_mu + v_refund));
      end if;
    end loop;
  end if;

  update public.play_corrections set finished_at = public._now(), corrected = cardinality(v_corrected), refunds = v_refunds
  where session_id = p_session;
  return jsonb_build_object('corrected', cardinality(v_corrected), 'total', cardinality(c.question_ids),
                            'corrected_ids', to_jsonb(v_corrected), 'refunds', v_refunds, 'duplicate', false);
end $$;

revoke execute on function public._missed_questions(uuid, uuid) from public, anon, authenticated;
revoke execute on function public.play_correction_start(uuid, text), public.play_correction_submit(uuid, jsonb) from public, anon;
grant execute on function public.play_correction_start(uuid, text), public.play_correction_submit(uuid, jsonb) to authenticated;
