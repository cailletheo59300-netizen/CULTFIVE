#!/usr/bin/env bash
# Rejoue toutes les migrations + seed sur une base jetable puis exécute les tests SQL.
# Usage : PGHOST=... PGPORT=... PGUSER=postgres scripts/test-db.sh
set -euo pipefail
cd "$(dirname "$0")/.."
DB="${TEST_DB:-cultfive_test}"
psql -v ON_ERROR_STOP=1 -q -d postgres -c "drop database if exists $DB" -c "create database $DB"
run() { psql -v ON_ERROR_STOP=1 -q -X -d "$DB" -f "$1" >/dev/null; }
run supabase/tests/00_local_bootstrap.sql
for f in supabase/migrations/*.sql; do run "$f"; done
[ -f supabase/seed.sql ] && run supabase/seed.sql
run supabase/tests/01_helpers.sql
status=0
for t in supabase/tests/[1-9]*.sql; do
  if psql -v ON_ERROR_STOP=1 -q -X -d "$DB" -f "$t" >/tmp/cultfive_test.out 2>&1; then
    echo "ok   $(basename "$t")"
  else
    echo "FAIL $(basename "$t")"; cat /tmp/cultfive_test.out; status=1
  fi
done
exit $status
