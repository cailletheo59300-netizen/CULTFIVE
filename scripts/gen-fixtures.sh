#!/usr/bin/env bash
# Régénère les fixtures JSON des tests de contrat Swift à partir de la base de test (réponses RPC réelles).
# Usage : PGHOST=... PGPORT=... PGUSER=postgres scripts/gen-fixtures.sh   (après scripts/test-db.sh)
set -euo pipefail
cd "$(dirname "$0")/.."
F=ios/Packages/CultFiveCore/Tests/CultFiveCoreTests/Fixtures
mkdir -p "$F"
psql -X -q -At -d "${TEST_DB:-cultfive_test}" -f scripts/fixtures.sql | F="$F" python3 -c '
import sys, json, os
names = ["daily_status","daily_start","daily_question","daily_verdict","daily_result","daily_review","play_pack",
         "play_submit","profile","skills","domain_stats","errors","friends","league","leagues","achievements","history","domains","quests","weekly_recap"]
blocks = [b.strip() for b in sys.stdin.read().split("@@@") if b.strip()]
assert len(blocks) == len(names), (len(blocks), len(names))
for n, b in zip(names, blocks):
    with open(os.path.join(os.environ["F"], n + ".json"), "w") as f:
        json.dump(json.loads(b), f, ensure_ascii=False, indent=1)
print(len(blocks), "fixtures")
'
