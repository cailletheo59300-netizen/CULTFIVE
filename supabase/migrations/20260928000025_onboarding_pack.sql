-- Brainlix — 0025 Onboarding : exactement 3 questions, tirées d'une banque choisie à la main
-- Corrige un bug : la limite à 3 portait sur l'agrégat (une ligne), pas sur les questions : on en servait 5.
-- Banque dédiée (clés onb1-*, onb2-*, onb3-*) : une question qui surprend, une énigme connue, un « le savais-tu ? »,
-- dans cet ordre. Sans cette banque (base de test ancienne), repli sur 3 domaines variés.
create or replace function public.onboarding_pack() returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  v_session uuid := gen_random_uuid();
  v_ids uuid[];
begin
  select array_agg(id order by slot) into v_ids from (
    select distinct on (slot) q.id, substr(q.external_key, 1, 4) as slot
    from public.questions q
    where q.status = 'published' and q.external_key ~ '^onb[123]-'
      and q.id <> all (public._protected_daily_questions())
    order by slot, random()
  ) t;

  if cardinality(v_ids) is distinct from 3 then
    select array_agg(id) into v_ids from (
      select id from (
        select distinct on (q.domain_id) q.id, q.domain_id
        from public.questions q
        where q.status = 'published' and q.type in ('mcq', 'true_false', 'numeric')
          and q.difficulty_effective between 25 and 50
          and q.domain_id in ('geography', 'history', 'french', 'science', 'calc')
          and q.id <> all (public._protected_daily_questions())
        order by q.domain_id, random()
      ) d order by random() limit 3
    ) t;
  end if;

  insert into public.play_sessions (id, user_id, mode, question_ids, created_at)
  values (v_session, v_user, 'onboarding', coalesce(v_ids, '{}'), public._now());

  return jsonb_build_object('session_id', v_session, 'questions', coalesce((
    select jsonb_agg(public._question_public(q, v_session::text) || public._question_reveal(q)
                     || jsonb_build_object('concept_id', q.concept_id) order by array_position(v_ids, q.id))
    from public.questions q where q.id = any (v_ids)), '[]'::jsonb));
end $$;

revoke execute on function public.onboarding_pack() from public, anon;
grant execute on function public.onboarding_pack() to authenticated;
