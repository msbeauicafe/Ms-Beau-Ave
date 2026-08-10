#!/usr/bin/env bash
# Start MS BEAU AVE on a throwaway Postgres: initdb → migrations → seed → app.
# Nothing is installed and nothing survives Ctrl-C; use DATABASE_URL directly
# against a real Postgres/Supabase when you want the data to stick around.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PGBIN="${PGBIN:-$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1)}"
WORKDIR="$(mktemp -d)"
PGDATA="$WORKDIR/pgdata"
PGPORT="${APP_DB_PORT:-54330}"
export APP_PORT="${PORT:-4300}"
export PGUSER=postgres           # psql defaults to $USER, which the cluster has no role for
export DATABASE_URL="postgresql://postgres@localhost:$PGPORT/msbeauave?host=$WORKDIR"

AS_PG=""
if [ "$(id -u)" = "0" ] && id postgres >/dev/null 2>&1; then
  AS_PG="runuser -u postgres --"
  chmod 777 "$WORKDIR"
fi

cleanup() {
  $AS_PG "$PGBIN/pg_ctl" -D "$PGDATA" -m immediate stop >/dev/null 2>&1 || true
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

echo "==> starting a throwaway Postgres"
$AS_PG "$PGBIN/initdb" -D "$PGDATA" -U postgres --auth=trust --no-sync >/dev/null
$AS_PG "$PGBIN/pg_ctl" -D "$PGDATA" -w \
  -o "-k $WORKDIR -p $PGPORT -c listen_addresses='' -c fsync=off -c synchronous_commit=off" \
  -l "$WORKDIR/pg.log" start >/dev/null
"$PGBIN/psql" -q -h "$WORKDIR" -p "$PGPORT" -d postgres -c "CREATE DATABASE msbeauave" >/dev/null

echo "==> applying migrations"
for f in "$REPO_ROOT"/supabase/migrations/*.sql; do
  echo "    $(basename "$f")"
  "$PGBIN/psql" -q -v ON_ERROR_STOP=1 -h "$WORKDIR" -p "$PGPORT" -d msbeauave -f "$f" >/dev/null
done

echo "==> seeding demo data"
node "$REPO_ROOT/scripts/seed-mvp.js"

echo "==> starting the app"
PORT="$APP_PORT" node "$REPO_ROOT/app/server.js"
