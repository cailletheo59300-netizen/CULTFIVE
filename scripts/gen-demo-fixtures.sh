#!/usr/bin/env bash
# Génère les données du mode démo (réponses RPC réelles) : ios/CultFive/Demo/Fixtures/*.demo.json
set -euo pipefail
cd "$(dirname "$0")/.."
F=ios/CultFive/Demo/Fixtures
mkdir -p "$F"
psql -X -q -At -d "${TEST_DB:-cultfive_test}" -f scripts/demo-fixtures.sql | F="$F" python3 -c '
import sys, json, os
names = ["daily_status","daily_start","daily_question","daily_result","daily_review","play_pack","profile","skills",
         "domain_stats","errors","friends","league","leagues","achievements","history","referral","domains","subdomains"]
blocks = [b.strip() for b in sys.stdin.read().split("@@@") if b.strip()]
assert len(blocks) == len(names), (len(blocks), len(names))
for n, b in zip(names, blocks):
    with open(os.path.join(os.environ["F"], n + ".demo.json"), "w") as f:
        json.dump(json.loads(b), f, ensure_ascii=False, indent=1)
print(len(blocks), "fichiers de démo")
'
