#!/usr/bin/env bash
# Spin up an ephemeral Postgres 16 cluster, apply the IMS migrations, run the
# test suite, and tear the cluster down. No system Postgres service required —
# only the postgres binaries (initdb/pg_ctl) must be on disk.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PGBIN="${PGBIN:-$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1)}"
WORKDIR="${IMS_TEST_DIR:-$(mktemp -d)}"
PGDATA="$WORKDIR/pgdata"
PGPORT="${IMS_TEST_PORT:-54329}"
export PGHOST="$WORKDIR"           # unix socket dir — no TCP conflicts
export PGPORT
export PGUSER="postgres"
export PGDATABASE="msbeauave_test"
export IMS_TEST_DSN="postgresql://postgres@localhost:$PGPORT/msbeauave_test?host=$WORKDIR"

# Postgres refuses to run as root (common in CI/containers): delegate the
# server processes to the unprivileged postgres user in that case.
AS_PG=""
if [ "$(id -u)" = "0" ] && id postgres >/dev/null 2>&1; then
  AS_PG="runuser -u postgres --"
  chmod 777 "$WORKDIR"
fi

cleanup() {
  $AS_PG "$PGBIN/pg_ctl" -D "$PGDATA" -m immediate stop >/dev/null 2>&1 || true
  [ -z "${IMS_TEST_DIR:-}" ] && rm -rf "$WORKDIR"
}
trap cleanup EXIT

echo "==> initdb ($PGDATA)"
$AS_PG "$PGBIN/initdb" -D "$PGDATA" -U postgres --auth=trust --no-sync >/dev/null

echo "==> starting postgres on socket $WORKDIR port $PGPORT"
$AS_PG "$PGBIN/pg_ctl" -D "$PGDATA" -w \
  -o "-k $WORKDIR -p $PGPORT -c listen_addresses='' -c fsync=off -c synchronous_commit=off" \
  -l "$WORKDIR/pg.log" start >/dev/null

"$PGBIN/psql" -v ON_ERROR_STOP=1 -h "$WORKDIR" -d postgres -c "CREATE DATABASE msbeauave_test" >/dev/null

echo "==> applying migrations"
for f in "$REPO_ROOT"/supabase/migrations/*.sql; do
  echo "    $(basename "$f")"
  "$PGBIN/psql" -v ON_ERROR_STOP=1 -h "$WORKDIR" -d msbeauave_test -f "$f" >/dev/null
done

echo "==> running tests"
cd "$REPO_ROOT"
node --test tests/*.test.js
