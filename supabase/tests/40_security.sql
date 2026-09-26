-- Sécurité : RLS, droits d'exécution, réponses secrètes, horloge non surchargeable en production.
create temp table sec_users as select tst.new_user() as a, tst.new_user() as b;
grant select on sec_users to authenticated, anon;
select tst.clock('2026-12-20 10:00:00+01');
select tst.login(a) from sec_users;
select public.daily_start();

set role authenticated;

do $$
declare n int;
begin
  -- Banque de questions et Daily : aucun accès direct
  perform tst.throws('select count(*) from public.questions', 'permission denied');
  perform tst.throws('select count(*) from public.daily_set_items', 'permission denied');
  perform tst.throws('select count(*) from public.daily_answers', 'permission denied');
  perform tst.throws('select count(*) from public.app_admins', 'permission denied');
  -- Aucune écriture directe
  perform tst.throws('update public.profiles set seeds = 999999', 'permission denied');
  perform tst.throws('insert into public.ledger (user_id, currency, amount, reason, idempotency_key) values (auth.uid(), ''seeds'', 1000, ''hack'', ''x'')', 'permission denied');
  perform tst.throws('update public.daily_runs set score = 5', 'permission denied');
  -- Fonctions internes non exécutables
  perform tst.throws('select public._grant(auth.uid(), ''seeds'', 1000, ''hack'', null, ''hack'')', 'permission denied');
  perform tst.throws('select public._record_attempt(auth.uid(), gen_random_uuid(), ''{}'', 1, ''daily'', null, null)', 'permission denied');
  perform tst.throws('select public._generate_daily_set(current_date + 40)', 'permission denied');
  perform tst.throws('select public.cron_daily_maintenance()', 'permission denied');
  -- Admin : refusé
  perform tst.throws('select public.admin_dashboard()', 'forbidden');
  perform tst.throws('select public.admin_import(''[]'')', 'forbidden');
  -- RLS : on ne voit que ses lignes
  select count(*) into n from public.profiles;
  perform tst.ok(n = 1, 'un seul profil visible (le sien)');
  select count(*) into n from public.daily_runs;
  perform tst.ok(n = 1, 'ses propres runs uniquement');
  -- Référentiel lisible
  select count(*) into n from public.domains;
  perform tst.ok(n = 12, 'domaines lisibles');
end $$;

-- Un autre utilisateur ne peut pas manipuler le run de A
reset role;
select tst.login(b) from sec_users;
set role authenticated;
do $$
declare v_run uuid;
begin
  reset role;
  select r.id into v_run from public.daily_runs r join sec_users s on r.user_id = s.a;
  set role authenticated;
  perform tst.throws(format('select public.daily_question(%L, 1)', v_run), 'daily_run_not_found');
  perform tst.throws(format('select public.daily_answer(%L, 1, ''{}'', 1)', v_run), 'daily_run_not_found');
end $$;

-- Anonyme (non connecté) : aucune RPC métier
reset role;
select set_config('request.jwt.claims', '', false);
set role anon;
do $$
begin
  perform tst.throws('select public.daily_start()', 'permission denied');
  perform tst.throws('select public.profile_me()', 'permission denied');
end $$;
reset role;

-- Utilisateur connecté mais jeton sans sujet : refusé
set role authenticated;
do $$ begin perform tst.throws('select public.daily_start()', 'not_authenticated'); end $$;
reset role;

-- En production (session_user = authenticator), la surcharge d'horloge est ignorée.
do $$
begin
  perform tst.ok(abs(extract(epoch from public._now() - '2026-12-20 10:00:00+01'::timestamptz)) < 1, 'surcharge active en test');
end $$;
select tst.login(a) from sec_users;
set session authorization authenticator;
set role authenticated;
do $$
begin
  perform tst.ok((public.daily_status() ->> 'date')::date = (now() at time zone 'Europe/Paris')::date,
                 'surcharge ignorée pour les requêtes API (horloge réelle)');
end $$;
reset session authorization;
