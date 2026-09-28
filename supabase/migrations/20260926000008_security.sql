-- Brainlix — 0008 Security
-- RLS activée partout. Lecture directe : référentiel public + ses propres lignes. Aucune écriture directe.
-- Les fonctions internes (préfixe _) ne sont exécutables par personne côté API.

do $$
declare t text;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon, authenticated', t);
  end loop;
end $$;

-- Référentiel lisible par tous les utilisateurs connectés (y compris anonymes Supabase).
grant select on public.domains, public.subdomains, public.achievements to anon, authenticated;
create policy "read domains"      on public.domains      for select using (true);
create policy "read subdomains"   on public.subdomains   for select using (true);
create policy "read achievements" on public.achievements for select using (true);

grant select on public.concepts to authenticated;
create policy "read concepts" on public.concepts for select to authenticated using (true);

-- Données personnelles : lecture de ses propres lignes uniquement.
grant select on public.profiles, public.user_skills, public.user_skill_snapshots, public.user_concepts,
                public.question_attempts, public.ledger, public.user_achievements, public.daily_runs to authenticated;
create policy "own profile"      on public.profiles             for select to authenticated using (id = auth.uid());
create policy "own skills"       on public.user_skills          for select to authenticated using (user_id = auth.uid());
create policy "own snapshots"    on public.user_skill_snapshots for select to authenticated using (user_id = auth.uid());
create policy "own concepts"     on public.user_concepts        for select to authenticated using (user_id = auth.uid());
create policy "own attempts"     on public.question_attempts    for select to authenticated using (user_id = auth.uid());
create policy "own ledger"       on public.ledger               for select to authenticated using (user_id = auth.uid());
create policy "own achievements" on public.user_achievements    for select to authenticated using (user_id = auth.uid());
create policy "own daily runs"   on public.daily_runs           for select to authenticated using (user_id = auth.uid());

-- Social : visible par les parties concernées.
grant select on public.friendships, public.referrals, public.leagues, public.league_members to authenticated;
create policy "own friendships" on public.friendships for select to authenticated
  using (auth.uid() in (requester_id, addressee_id));
create policy "own referrals" on public.referrals for select to authenticated
  using (auth.uid() in (inviter_id, invitee_id));
create policy "member leagues" on public.leagues for select to authenticated
  using (public._is_member(id, auth.uid()));
create policy "member league_members" on public.league_members for select to authenticated
  using (public._is_member(league_id, auth.uid()));

-- questions, daily_sets, daily_set_items, daily_answers, play_sessions, user_devices, app_admins, blocked_terms,
-- generation_batches, question_reviews : aucune policy ⇒ aucun accès direct (réponses secrètes, anti-triche).

-- ─────────────────────────────────────────── Fonctions
revoke execute on all functions in schema public from public, anon, authenticated;
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;

do $$
declare f text;
begin
  foreach f in array array[
    'daily_status()', 'daily_start()', 'daily_question(uuid,int)', 'daily_answer(uuid,int,jsonb,int)',
    'daily_result(date)', 'daily_review(date)', 'daily_history(int)',
    'play_pack(text,text,text,int)', 'play_submit(uuid,jsonb)', 'play_spend_help(uuid,uuid,text)', 'onboarding_pack()',
    'profile_me()', 'handle_available(text)', 'set_handle(text)', 'profile_update(jsonb)',
    'complete_onboarding(text,text[])', 'set_timezone(text)', 'register_device(text)',
    'skills_overview()', 'domain_stats(text)', 'errors_overview()', 'achievements_mine()',
    'search_handles(text)', 'friend_request(text)', 'friend_respond(uuid,bool)', 'friend_remove(uuid)',
    'friend_block(uuid)', 'friends_overview()',
    'referral_claim(text,text)', 'referral_overview()',
    'league_create(text,league_period)', 'league_join(text)', 'league_leave(uuid)', 'league_rename(uuid,text)',
    'league_standings(uuid,int)', 'leagues_mine()',
    'delete_account()', 'is_admin()',
    'admin_question_upsert(jsonb)', 'admin_import(jsonb,question_origin,uuid)',
    'admin_question_set_status(uuid,question_status,text)', 'admin_questions(jsonb,int,int)', 'admin_dashboard()',
    'admin_daily_get(date)', 'admin_daily_generate(date)', 'admin_daily_replace(date,int,uuid,bool)',
    'admin_batch_create(text,text,int,text,text)'
  ] loop
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- RLS/policies appellent ces fonctions dans le contexte de l'utilisateur.
grant execute on function public._is_member(uuid, uuid) to authenticated;

-- ─────────────────────────────────────────── Planification (pg_cron, disponible sur Supabase)
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    perform cron.schedule('brainlix-daily-maintenance', '*/15 * * * *', 'select public.cron_daily_maintenance()');
  end if;
exception when others then
  raise notice 'pg_cron indisponible : maintenance Daily non planifiée (%)', sqlerrm;
end $$;

-- Évite la récursion RLS (la policy de league_members interroge league_members).
alter function public._is_member(uuid, uuid) security definer set search_path = public, pg_temp;
