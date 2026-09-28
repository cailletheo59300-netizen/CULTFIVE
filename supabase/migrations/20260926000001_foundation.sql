-- Brainlix — 0001 Foundation
-- Référentiel (domaines, sous-domaines, concepts, questions), profils, administrateurs, utilitaires.
-- Toute la logique métier est en RPC SECURITY DEFINER ; les tables ne sont jamais écrites directement par le client.

-- ─────────────────────────────────────────── Types
create type public.question_type   as enum ('mcq', 'true_false', 'numeric', 'ordering', 'pairs', 'map_pick');
create type public.question_status as enum ('draft', 'review', 'published', 'disabled');
create type public.question_origin as enum ('human', 'ai', 'import');
create type public.attempt_context as enum ('onboarding', 'daily', 'quick_play', 'training', 'surprise', 'errors', 'challenge');
create type public.daily_slot      as enum ('calc', 'french', 'geo', 'history', 'surprise');
create type public.error_state     as enum ('failed', 'to_review', 'correct_once', 'mastered');

-- ─────────────────────────────────────────── Horloge (surchargeable en test uniquement)
-- En production, toutes les requêtes API ont session_user = 'authenticator' : la surcharge est ignorée.
create or replace function public._now() returns timestamptz
language sql stable as $$
  select case
    when session_user <> 'authenticator' and nullif(current_setting('app.now_override', true), '') is not null
      then current_setting('app.now_override', true)::timestamptz
    else now()
  end
$$;

-- ─────────────────────────────────────────── Référentiel
create table public.domains (
  id          text primary key check (id ~ '^[a-z_]+$'),
  name        text not null,
  daily_slot  public.daily_slot,           -- null ⇒ réservoir « Surprise »
  sort        int  not null default 0,
  is_active   bool not null default true
);

create table public.subdomains (
  id         text primary key check (id ~ '^[a-z_]+\.[a-z_]+$'),
  domain_id  text not null references public.domains(id),
  name       text not null,
  sort       int  not null default 0,
  check (split_part(id, '.', 1) = domain_id)
);
create index on public.subdomains (domain_id);

-- Un concept = une connaissance unique, quelle que soit la formulation des questions qui la mesurent.
create table public.concepts (
  id            text primary key check (id ~ '^[a-z_]+\.[a-z_]+\.[a-z0-9_]+$'),
  subdomain_id  text not null references public.subdomains(id),
  label         text not null,
  created_at    timestamptz not null default now(),
  check (split_part(id, '.', 1) || '.' || split_part(id, '.', 2) = subdomain_id)
);
create index on public.concepts (subdomain_id);

create table public.questions (
  id                   uuid primary key default gen_random_uuid(),
  external_key         text unique,                       -- clé stable du contenu curé (import idempotent)
  concept_id           text not null references public.concepts(id),
  subdomain_id         text not null references public.subdomains(id),
  domain_id            text not null references public.domains(id),
  type                 public.question_type not null,
  prompt               text not null check (length(prompt) between 5 and 400),
  payload              jsonb not null default '{}'::jsonb, -- partie publique (options, éléments, carte…)
  answer               jsonb not null,                     -- partie secrète
  explanation          text not null check (length(explanation) between 10 and 600),
  takeaway             text check (length(takeaway) <= 200),   -- « À retenir »
  hint                 text check (length(hint) <= 200),       -- aide payante (mode Jouer)
  context_note         text check (length(context_note) <= 300),
  source               text,
  fact_as_of           date,                                -- pour les faits évolutifs
  locale               text not null default 'fr',
  difficulty_initial   real not null check (difficulty_initial between 0 and 100),
  difficulty_min       real not null check (difficulty_min between 0 and 100),
  difficulty_max       real not null check (difficulty_max between 0 and 100),
  difficulty_observed  real not null,
  difficulty_var       real not null default 100,
  difficulty_effective real generated always as (least(greatest(difficulty_observed, difficulty_min), difficulty_max)) stored,
  confidence           real generated always as (greatest(0, 1 - sqrt(difficulty_var) / 10)) stored,
  answer_count         int  not null default 0,
  correct_count        int  not null default 0,
  range_widenings      int  not null default 0,
  last_widen_count     int  not null default 0,
  needs_review         bool not null default false,
  review_reason        text,
  status               public.question_status not null default 'draft',
  origin               public.question_origin not null default 'human',
  batch_id             uuid,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  published_at         timestamptz,
  check (difficulty_min <= difficulty_initial and difficulty_initial <= difficulty_max)
);
create index questions_pick_domain on public.questions (domain_id, status, difficulty_effective);
create index questions_pick_sub    on public.questions (subdomain_id, status, difficulty_effective);
create index questions_concept     on public.questions (concept_id);
create index questions_review      on public.questions (needs_review) where needs_review;

-- Cohérence : domaine et sous-domaine dérivés du concept.
create or replace function public._questions_derive() returns trigger
language plpgsql as $$
begin
  select c.subdomain_id, s.domain_id into new.subdomain_id, new.domain_id
  from public.concepts c join public.subdomains s on s.id = c.subdomain_id
  where c.id = new.concept_id;
  if tg_op = 'INSERT' and new.difficulty_observed is null then
    new.difficulty_observed := new.difficulty_initial;
  end if;
  if new.status = 'published' and (tg_op = 'INSERT' or old.status is distinct from 'published') then
    new.published_at := coalesce(new.published_at, now());
  end if;
  new.updated_at := now();
  return new;
end $$;
create trigger questions_derive before insert or update on public.questions
for each row execute function public._questions_derive();

-- ─────────────────────────────────────────── Profils
create table public.profiles (
  id                  uuid primary key references auth.users(id) on delete cascade,
  handle              text not null check (handle ~ '^[A-Za-z0-9_]{3,20}$'),
  handle_changed_at   timestamptz,
  avatar              jsonb not null default '{"color":"chloro","pose":"rest"}'::jsonb,
  age_range           text check (age_range in ('13-17', '18-24', '25-34', '35-49', '50+')),
  timezone            text not null default 'Europe/Paris',
  timezone_changed_at timestamptz,
  challenge_prior     real not null default 50 check (challenge_prior between 20 and 80),
  interests           text[] not null default '{}',
  xp_total            int  not null default 0 check (xp_total >= 0),
  seeds               int  not null default 0 check (seeds >= 0),
  streak_current      int  not null default 0,
  streak_best         int  not null default 0,
  streak_last_date    date,
  streak_freezes      int  not null default 0 check (streak_freezes between 0 and 2),
  questions_answered  int  not null default 0,
  questions_correct   int  not null default 0,
  errors_corrected    int  not null default 0,
  referral_code       text not null unique,
  referred_by         uuid references public.profiles(id) on delete set null,
  notif_daily         bool not null default true,
  notif_daily_time    time not null default '08:30',
  notif_reminder      bool not null default true,
  onboarded_at        timestamptz,
  created_at          timestamptz not null default now()
);
create unique index profiles_handle_ci on public.profiles (lower(handle));

create table public.app_admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);

-- Termes interdits dans les pseudos (validation basique ; la liste s'enrichit en base).
create table public.blocked_terms (term text primary key check (term = lower(term)));
insert into public.blocked_terms (term) values
  ('admin'), ('cultfive'), ('cult_five'), ('support'), ('moderat'), ('official'), ('officiel'),
  ('nazi'), ('hitler'), ('pute'), ('salope'), ('encule'), ('nique'), ('bite'), ('fuck'), ('shit'), ('bitch'), ('nigg'), ('pd_');

create table public.user_devices (
  user_id     uuid not null references public.profiles(id) on delete cascade,
  device_hash text not null check (length(device_hash) between 16 and 128),
  first_seen  timestamptz not null default now(),
  primary key (user_id, device_hash)
);
create index on public.user_devices (device_hash);

-- ─────────────────────────────────────────── Utilitaires
create or replace function public.is_admin() returns bool
language sql stable security definer set search_path = public, pg_temp as $$
  select exists (select 1 from public.app_admins where user_id = auth.uid())
$$;

create or replace function public._require_user() returns uuid
language plpgsql stable as $$
declare v uuid := auth.uid();
begin
  if v is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
  return v;
end $$;

create or replace function public._require_admin() returns uuid
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare v uuid := public._require_user();
begin
  if not exists (select 1 from public.app_admins where user_id = v) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  return v;
end $$;

-- Code lisible sans caractères ambigus (0/O, 1/I/L).
create or replace function public._random_code(p_len int) returns text
language sql volatile as $$
  select string_agg(substr('ABCDEFGHJKMNPQRSTUVWXYZ23456789', 1 + floor(random() * 31)::int, 1), '')
  from generate_series(1, p_len)
$$;

create or replace function public._handle_is_valid(p_handle text) returns bool
language sql stable as $$
  select p_handle ~ '^[A-Za-z0-9_]{3,20}$'
     and not exists (select 1 from public.blocked_terms b where position(b.term in lower(p_handle)) > 0)
$$;

-- Création automatique du profil à l'inscription (y compris compte anonyme).
create or replace function public._on_auth_user_created() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_handle text;
  v_code   text;
  v_words  text[] := array['curieux', 'lucide', 'agile', 'vif', 'malin', 'rusé', 'futé', 'sage', 'alerte', 'subtil'];
begin
  loop
    v_handle := translate(v_words[1 + floor(random() * array_length(v_words, 1))::int], 'éè', 'ee')
                || '_' || lpad(floor(random() * 100000)::text, 5, '0');
    exit when not exists (select 1 from public.profiles where lower(handle) = lower(v_handle));
  end loop;
  loop
    v_code := public._random_code(7);
    exit when not exists (select 1 from public.profiles where referral_code = v_code);
  end loop;
  insert into public.profiles (id, handle, referral_code, created_at) values (new.id, v_handle, v_code, public._now());
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
for each row execute function public._on_auth_user_created();
