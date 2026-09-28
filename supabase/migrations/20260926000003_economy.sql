-- Brainlix — 0003 Economy
-- Ledger unique XP + graines (une seule monnaie), trophées.

create type public.currency as enum ('xp', 'seeds');

create table public.ledger (
  id               bigint generated always as identity primary key,
  user_id          uuid not null references public.profiles(id) on delete cascade,
  currency         public.currency not null,
  amount           int  not null check (amount <> 0),
  reason           text not null,       -- daily_correct, daily_complete, daily_perfect, play_correct, error_corrected,
                                        -- achievement, referral_invitee, referral_inviter, referral_tier, spend_*
  ref              text,                -- identifiant métier lié (run, question, referral…)
  idempotency_key  text not null,
  created_at       timestamptz not null default now(),
  unique (user_id, idempotency_key)
);
create index on public.ledger (user_id, created_at desc);
create index on public.ledger (user_id, currency, reason, created_at);

-- Le solde du profil est un cache du ledger, tenu par trigger. Le check seeds >= 0 refuse les découverts.
create or replace function public._ledger_apply() returns trigger
language plpgsql as $$
begin
  if new.currency = 'xp' then
    update public.profiles set xp_total = xp_total + new.amount where id = new.user_id;
  else
    update public.profiles set seeds = seeds + new.amount where id = new.user_id;
  end if;
  return new;
end $$;
create trigger ledger_apply after insert on public.ledger for each row execute function public._ledger_apply();

-- Crédite/débite une fois par clé. Renvoie true si l'écriture a eu lieu.
create or replace function public._grant(p_user uuid, p_currency public.currency, p_amount int, p_reason text, p_ref text, p_key text)
returns bool language plpgsql as $$
declare v_id bigint;
begin
  if p_amount = 0 then return false; end if;
  insert into public.ledger (user_id, currency, amount, reason, ref, idempotency_key, created_at)
  values (p_user, p_currency, p_amount, p_reason, p_ref, p_key, public._now())
  on conflict (user_id, idempotency_key) do nothing
  returning id into v_id;
  return v_id is not null;
exception when check_violation then
  raise exception 'insufficient_seeds' using errcode = 'P0001';
end $$;

-- Somme gagnée aujourd'hui (UTC) pour une raison : sert aux plafonds journaliers.
create or replace function public._earned_today(p_user uuid, p_currency public.currency, p_reason text) returns int
language sql stable as $$
  select coalesce(sum(amount), 0)::int from public.ledger
  where user_id = p_user and currency = p_currency and reason = p_reason
    and created_at >= date_trunc('day', public._now() at time zone 'UTC') at time zone 'UTC'
$$;

-- Plafonne un gain au reste disponible du jour.
create or replace function public._grant_capped(p_user uuid, p_currency public.currency, p_amount int, p_cap int,
                                                p_reason text, p_ref text, p_key text) returns int
language plpgsql as $$
declare v_amount int := least(p_amount, greatest(p_cap - public._earned_today(p_user, p_currency, p_reason), 0));
begin
  if v_amount > 0 and public._grant(p_user, p_currency, v_amount, p_reason, p_ref, p_key) then
    return v_amount;
  end if;
  return 0;
end $$;

-- ─────────────────────────────────────────── Trophées (rares et significatifs)
create table public.achievements (
  id            text primary key,
  name          text not null,
  description   text not null,
  reward_seeds  int  not null default 0,
  sort          int  not null default 0
);

insert into public.achievements (id, name, description, reward_seeds, sort) values
  ('first_daily',     'Premier rendez-vous',   'Terminer ton premier 5 du jour.',                        10,  10),
  ('first_perfect',   'Cinq sur cinq',         'Réussir un 5 du jour sans faute.',                       20,  20),
  ('fast_perfect',    'Éclair',                'Un 5/5 en moins d''une minute.',                         30,  30),
  ('streak_7',        'Une semaine',           '7 jours de série.',                                      20,  40),
  ('streak_30',       'Un mois',               '30 jours de série.',                                     60,  50),
  ('streak_100',      'Centenaire',            '100 jours de série.',                                   200,  60),
  ('errors_100',      'Rien ne se perd',       'Corriger 100 erreurs.',                                  60,  70),
  ('questions_1000',  'Mille questions',       'Répondre à 1 000 questions.',                            80,  80),
  ('polymath',        'Esprit large',          'Atteindre un niveau solide de 65 dans 5 domaines.',     100,  90),
  ('first_friend',    'En bonne compagnie',    'Avoir un premier ami sur Brainlix.',                    10, 100);

create table public.user_achievements (
  user_id         uuid not null references public.profiles(id) on delete cascade,
  achievement_id  text not null references public.achievements(id),
  unlocked_at     timestamptz not null default now(),
  primary key (user_id, achievement_id)
);

create or replace function public._unlock(p_user uuid, p_id text) returns bool
language plpgsql as $$
declare v_reward int;
begin
  insert into public.user_achievements (user_id, achievement_id, unlocked_at) values (p_user, p_id, public._now())
  on conflict do nothing;
  if not found then return false; end if;
  select reward_seeds into v_reward from public.achievements where id = p_id;
  perform public._grant(p_user, 'seeds', v_reward, 'achievement', p_id, 'achievement:' || p_id);
  return true;
end $$;

-- Vérifie les conditions non liées à un événement précis. Renvoie les nouveaux trophées.
create or replace function public._check_achievements(p_user uuid) returns text[]
language plpgsql as $$
declare
  p public.profiles;
  v_new text[] := '{}';
begin
  select * into p from public.profiles where id = p_user;
  if p.streak_best >= 7   and public._unlock(p_user, 'streak_7')   then v_new := v_new || 'streak_7'::text; end if;
  if p.streak_best >= 30  and public._unlock(p_user, 'streak_30')  then v_new := v_new || 'streak_30'::text; end if;
  if p.streak_best >= 100 and public._unlock(p_user, 'streak_100') then v_new := v_new || 'streak_100'::text; end if;
  if p.errors_corrected >= 100 and public._unlock(p_user, 'errors_100') then v_new := v_new || 'errors_100'::text; end if;
  if p.questions_answered >= 1000 and public._unlock(p_user, 'questions_1000') then v_new := v_new || 'questions_1000'::text; end if;
  if (select count(*) from public.user_skills s
      where s.user_id = p_user and s.is_domain and s.mu >= 65 and s.var <= 36) >= 5
     and public._unlock(p_user, 'polymath') then
    v_new := v_new || 'polymath'::text;
  end if;
  return v_new;
end $$;
