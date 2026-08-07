#!/bin/bash

# Nightly logical backup (pg_dump) of the SLSL content DB — the Cloud SQL
# Postgres behind this Django admin, the hand-curated source of truth for all
# SLSL dictionary content. Complements (not replaces) the Cloud SQL automated
# daily backups enabled in deployment/db.ts: this copy is off-GCP, in gdrive,
# and survives project-level disasters.
#
# Invoked once every 24 hours by the launchd agent me.dport.backup-slsl-db
# (plist in dotfiles/macos/launchagents/) with --if-stale; run by hand with no
# args to force.
#
# The defer/notify/marker conventions live in dotfiles/jobs/lib.sh (shared by
# every Mac job): no network or no gdrive defers (exit 0, no alert, marker
# untouched — every "Backup FAILED" alert in this job's history was `lookup
# oauth2.googleapis.com: no such host` against a healthy database), a real
# failure pops a Notification Center alert, the marker is touched only on
# success. The lock gives single-flight: two overlapping runs used to race on
# the fixed proxy port below.
#
# Connects via cloud-sql-proxy (IAM/ADC auth, so no IP allowlisting), with DB
# credentials read from the gitignored prod_secrets.json next to this repo's
# admin_site. Keeps the last 30 dumps.

set -euo pipefail

NAME="slsl-db"
LOG_HINT="~/Library/Logs/me.dport.backup-slsl-db.log"
source "$HOME/github/dotfiles/jobs/lib.sh"
PROXY_PID=""
job_cleanup() { [ -n "$PROXY_PID" ] && kill "$PROXY_PID" 2>/dev/null || true; }
job_init
with_lock
if_stale_guard "$@"
require_network
require_gdrive

DEST="$HOME/gdrive/backups/dictionary/slsl-db"
SECRETS="$(cd "$(dirname "$0")/.." && pwd)/prod_secrets.json"
CONNECTION_NAME="slsl-dictionary:us-east1:slsl-admin-db-instance-02833a6"
PROXY_PORT=54321
PG_DUMP="/opt/homebrew/opt/libpq/bin/pg_dump"

mkdir -p "$DEST"

SQL_USER=$(python3 -c "import json;print(json.load(open('$SECRETS'))['sql_user'])")
SQL_DATABASE=$(python3 -c "import json;print(json.load(open('$SECRETS'))['sql_database'])")
SQL_PASSWORD=$(python3 -c "import json;print(json.load(open('$SECRETS'))['sql_password'])")

# Absolute paths throughout: launchd runs with a minimal PATH.
"$HOME/bin/cloud-sql-proxy" --port "$PROXY_PORT" "$CONNECTION_NAME" &
PROXY_PID=$!

# Wait for the proxy to accept connections (it authenticates via ADC first).
for _ in $(seq 1 30); do
    nc -z 127.0.0.1 "$PROXY_PORT" 2>/dev/null && break
    sleep 1
done

OUT="$DEST/slsl-db-$(date +%Y-%m-%d).sql.gz"
TMP_OUT="/tmp/slsl-db-$(date +%Y-%m-%d).sql.gz"
PGPASSWORD="$SQL_PASSWORD" "$PG_DUMP" \
    -h 127.0.0.1 -p "$PROXY_PORT" -U "$SQL_USER" -d "$SQL_DATABASE" \
    --no-owner --no-acl | gzip > "$TMP_OUT"

# A dump this small should never be empty; treat that as failure.
[ -s "$TMP_OUT" ] || { echo "dump is empty" >&2; rm -f "$TMP_OUT"; exit 1; }

rm -f "$OUT"
mv "$TMP_OUT" "$OUT"

# Keep the newest 30 dumps. We use || true because Google Drive File Provider
# can be asynchronous; immediately after a mv, the directory glob might briefly
# return empty, causing ls to fail and trip set -e.
ls -1t "$DEST"/slsl-db-*.sql.gz 2>/dev/null | tail -n +31 | while read -r old; do rm -f "$old"; done || true

mark_success
log "$NAME backup completed: $(du -h "$OUT" | cut -f1) $(basename "$OUT")"
