-- Frise des siècles (D-087) : bornes et bon siècle posés sur les QCM de siècles ; réponse {"century": n} corrigée.
do $$
declare
  q public.questions;
  n int;
begin
  perform tst.ok(public._century_of('XVIIIe siècle') = 18 and public._century_of('XIVᵉ siècle') = 14
                 and public._century_of('Ier siècle') = 1 and public._century_of('Un siècle') is null, 'siècles lus');
  select * into q from public.questions where type = 'mcq' and status = 'published' and payload::text ~ 'XVIII. siècle' limit 1;
  perform tst.ok(q.payload ? 'century_scale' and q.answer ? 'century', 'frise posée sur une question « siècle »');
  select public._century_of(o ->> 'text') into n from jsonb_array_elements(q.payload -> 'options') o
  where o ->> 'id' = q.answer ->> 'option_id';
  perform tst.ok((q.answer ->> 'century')::int = n, 'bon siècle = celui du bon choix');
  perform tst.ok(public._evaluate(q.type, q.answer, jsonb_build_object('century', n)), 'frise : bon siècle juste');
  perform tst.ok(not public._evaluate(q.type, q.answer, jsonb_build_object('century', n + 1)), 'frise : siècle voisin faux');
  perform tst.ok(public._evaluate(q.type, q.answer, jsonb_build_object('option_id', q.answer ->> 'option_id')),
                 'anciennes versions : choix classique toujours juste');
  perform tst.ok(not exists (select 1 from public.questions where type = 'mcq' and payload ? 'century_scale'
                             and payload::text ~ 'Un siècle'), 'pas de frise hors QCM de siècles');
end $$;
