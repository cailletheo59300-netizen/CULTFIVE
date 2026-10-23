-- ─────────────────────────────────────────── 0086 · Moins de questions déjà vues (D-108)
-- Parties adaptatives (_select_questions) :
--   · une notion réussie ne revient pas avant 30 jours (7 avant) ; ratée, toujours 3 jours ;
--   · à difficulté égale, une notion jamais vue passe avant une notion déjà vue ;
--   · au dernier repli (plus rien de neuf), la notion vue il y a le plus longtemps plutôt qu'une au hasard ;
--   · la révision glissée dans une partie : une fois par jour et par domaine au plus (une par partie avant), et de
--     préférence une autre question de la même notion que celle déjà jouée. « Mes erreurs » ne change pas.

create table public.review_slots (
  user_id   uuid not null references public.profiles(id) on delete cascade,
  domain_id text not null,
  day       date not null,
  primary key (user_id, domain_id, day)
);
alter table public.review_slots enable row level security;
revoke all on public.review_slots from anon, authenticated;

do $$
declare f record; v_old text; v_new text;
begin
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = '_select_questions' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(replace(replace(replace(v_old,
      '      and q.id <> all (v_banned)
    order by uc.review_due, random()',
      '      and q.id <> all (v_banned)
      -- 0086 : une révision par jour et par domaine au plus.
      and not exists (select 1 from public.review_slots rs where rs.user_id = p_user and rs.domain_id = p_domain
                        and rs.day = public._paris_day(public._now()))
    -- 0086 : de préférence une autre question de la notion que celle déjà jouée.
    order by uc.review_due,
             (select max(qa.created_at) from public.question_attempts qa where qa.user_id = p_user and qa.question_id = q.id) nulls first,
             random()'),
      '      v_target := v_target - 1;',
      '      v_target := v_target - 1;
      insert into public.review_slots (user_id, domain_id, day) values (p_user, p_domain, public._paris_day(public._now()))
      on conflict do nothing;'),
      'then interval ''7 days'' else interval ''3 days'' end',
      'then interval ''30 days'' else interval ''3 days'' end'),
      '      order by case when v_band.explore then q.answer_count else 0 end,',
      '      -- 0086 : au dernier repli, la notion vue il y a le plus longtemps ; sinon les notions jamais vues d''abord.
      order by case when lvl = 5 then coalesce((select uc.last_seen_at from public.user_concepts uc
                                                where uc.user_id = p_user and uc.concept_id = q.concept_id), ''-infinity'') end,
               exists (select 1 from public.user_concepts uc where uc.user_id = p_user and uc.concept_id = q.concept_id and uc.seen > 0),
               case when v_band.explore then q.answer_count else 0 end,');
    if v_new not like '%public.review_slots rs%' or v_new not like '%insert into public.review_slots%'
       or v_new not like '%interval ''30 days''%' or v_new not like '%uc.seen > 0%' then
      raise exception '0086: _select_questions inchangée';
    end if;
    execute v_new;
  end loop;
end $$;
