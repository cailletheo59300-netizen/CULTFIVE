#!/usr/bin/env bash
# Banque de questions du mode démo : ~30 vraies questions par domaine (réponses incluses, familles variées),
# extraites de la base de test (après scripts/test-db.sh). Sortie : ios/CultFive/Demo/Fixtures/play_bank.demo.json
# Usage : PGHOST=... PGPORT=... PGUSER=postgres scripts/gen-demo-bank.sh
set -euo pipefail
cd "$(dirname "$0")/.."
DB="${TEST_DB:-cultfive_test}"
psql -X -At -d "$DB" <<'SQL' > ios/CultFive/Demo/Fixtures/play_bank.demo.json
with ranked as (
  select q.id, q.domain_id, row_number() over (partition by q.domain_id, coalesce(q.family, q.id::text) order by md5(q.id::text)) as per_family
  from public.questions q where q.status = 'published'
), picked as (
  select r.id, row_number() over (partition by r.domain_id order by r.per_family, md5(r.id::text || 'demo')) as n
  from ranked r where r.per_family <= 8
)
select jsonb_pretty(jsonb_agg(
  public._question_public(q, 'demo') || public._question_reveal(q)
  || jsonb_build_object('concept_id', q.concept_id, 'has_hint', q.hint is not null, 'has_context', q.context_note is not null,
                        'hint', q.hint, 'context_note', q.context_note,
                        'difficulty', round(q.difficulty_effective::numeric), 'family', q.family)
  order by q.domain_id, p.n))
from picked p join public.questions q on q.id = p.id where p.n <= 30;
SQL
node -e 'const b=require("./ios/CultFive/Demo/Fixtures/play_bank.demo.json");const c={};for(const q of b)c[q.domain_id]=(c[q.domain_id]||0)+1;console.log(b.length,c)'
