-- Familles dans les défis, les ligues et la Survie (D-086) : 2 au plus par famille, jamais deux à la suite.
do $$
declare
  u uuid := tst.new_user();
  ids uuid[];
  bad int := 0;
  n_era int;
begin
  perform tst.ok((select count(*) from public.questions where family = 'person_era' and status = 'published') >= 10,
                 'questions « siècle » présentes');
  for i in 1 .. 15 loop
    ids := public._duel_pick(u, null, 10, array['history'], 'auto');
    select count(*) into n_era from unnest(ids) x(id) join public.questions q on q.id = x.id where q.family = 'person_era';
    if n_era > 2 then bad := bad + 1; end if;
    if exists (select 1 from unnest(ids) with ordinality a(id, o) join public.questions qa on qa.id = a.id
               join unnest(ids) with ordinality b(id, o) on b.o = a.o + 1 join public.questions qb on qb.id = b.id
               where qa.family is not null and qa.family = qb.family) then bad := bad + 1; end if;
  end loop;
  perform tst.ok(bad = 0, 'défi d''histoire : 2 questions « siècle » au plus, jamais à la suite');

  -- Réordonnancement : deux questions d'une même famille côte à côte sont séparées.
  select array_agg(id) into ids from (
    (select id from public.questions where family = 'person_era' and status = 'published' limit 2)
    union all (select id from public.questions where family is null and status = 'published' limit 2)) t;
  ids := public._spread_families(ids);
  perform tst.ok((select q.family from public.questions q where q.id = ids[2]) is distinct from 'person_era',
                 'deux questions d''une même famille séparées');
end $$;
