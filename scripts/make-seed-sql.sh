#!/usr/bin/env bash
# Regenerate scripts/seed-supabase.sql — the demo dataset as portable SQL.
#
# scripts/seed-mvp.js builds the data by calling the engine's own functions, so
# every pool allocation, FEFO pick and invoice reconciles. This script replays
# that against a throwaway database and dumps the result, giving a file that
# can be loaded into a hosted Postgres (Supabase) where we cannot run Node.
#
# The dump is schema-agnostic: table names are unqualified so it lands in
# whatever search_path points at (`msbeau` on the shared Supabase project).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PGBIN="${PGBIN:-$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1)}"
OUT="$REPO_ROOT/scripts/seed-supabase.sql"
WORKDIR="$(mktemp -d)"
PGPORT="${SEED_PORT:-54350}"
export PGUSER=postgres

AS_PG=""
if [ "$(id -u)" = "0" ] && id postgres >/dev/null 2>&1; then
  AS_PG="runuser -u postgres --"
  chmod 777 "$WORKDIR"
fi
cleanup() {
  $AS_PG "$PGBIN/pg_ctl" -D "$WORKDIR/pgdata" -m immediate stop >/dev/null 2>&1 || true
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

$AS_PG "$PGBIN/initdb" -D "$WORKDIR/pgdata" -U postgres --auth=trust --no-sync >/dev/null
$AS_PG "$PGBIN/pg_ctl" -D "$WORKDIR/pgdata" -w \
  -o "-k $WORKDIR -p $PGPORT -c listen_addresses='' -c fsync=off" \
  -l "$WORKDIR/pg.log" start >/dev/null
"$PGBIN/psql" -q -h "$WORKDIR" -p "$PGPORT" -d postgres -c "CREATE DATABASE seedsrc" >/dev/null
for f in "$REPO_ROOT"/supabase/migrations/*.sql; do
  "$PGBIN/psql" -q -v ON_ERROR_STOP=1 -h "$WORKDIR" -p "$PGPORT" -d seedsrc -f "$f" >/dev/null
done

DATABASE_URL="postgresql://postgres@localhost:$PGPORT/seedsrc?host=$WORKDIR" \
  node "$REPO_ROOT/scripts/seed-mvp.js" >/dev/null

{
  cat <<'HDR'
-- ============================================================================
-- MS BEAU AVE — demo dataset (GENERATED — do not hand-edit)
--
-- Regenerate with: bash scripts/make-seed-sql.sh
--
-- Built by running scripts/seed-mvp.js against a clean database and dumping
-- the result, so the rows are exactly what the engine's own functions produced:
-- 70/20/10 pool allocations, FEFO-picked order lines, invoices with the
-- past-due block, and a reconciling stock ledger.
--
-- Table names are unqualified, so this loads into whatever search_path points
-- at. Replication role is switched to `replica` for the load because the
-- movement journal and audit log are append-only by trigger and would reject
-- back-dated historical rows.
-- ============================================================================
set session_replication_role = replica;
HDR
  # Excluded:
  #   audit_log       — records the seeding run itself, not business data
  #   statutory_rates — reference data migration 0005 inserts on its own, so
  #                     dumping it too would collide on the primary key and
  #                     abort the rest of the load
  # --column-inserts rather than the default COPY: this file is executed
  # server-side (Postgres fetches it over HTTP), and `COPY ... FROM stdin` is
  # a psql client construct with no stdin to read from there. Naming the
  # columns also makes the file independent of column order.
  # The \restrict / \unrestrict wrappers newer pg_dump emits are likewise
  # psql-only meta-commands and are stripped.
  "$PGBIN/pg_dump" -h "$WORKDIR" -p "$PGPORT" -d seedsrc \
      --data-only --no-owner --no-privileges --column-inserts \
      --exclude-table-data=audit_log --exclude-table-data=statutory_rates \
    | sed -E "s/^INSERT INTO public\./INSERT INTO /; \
              s/setval\('public\./setval('/; \
              /^\\\\(un)?restrict/d; \
              /^SET search_path/d; \
              /^SELECT pg_catalog\.set_config\('search_path'/d"
  echo "reset session_replication_role;"
} > "$OUT"

echo "wrote $OUT ($(wc -c < "$OUT") bytes, $(grep -c "^INSERT INTO" "$OUT") rows)"
