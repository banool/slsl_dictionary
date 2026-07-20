#!/bin/bash

# Nightly logical backup (pg_dump) of the SLSL content DB — the Cloud SQL
# Postgres behind this Django admin, the hand-curated source of truth for all
# SLSL dictionary content. Complements (not replaces) the Cloud SQL automated
# daily backups enabled in deployment/db.ts: this copy is off-GCP, in gdrive,
# and survives project-level disasters.
#
# Invoked by the launchd agent me.dport.backup-slsl-db (plist in
# dotfiles/macos/launchagents/) with --if-stale (skip if last success <20h —
# combined with RunAtLoad this catches up sleeps/shutdowns with exactly one
# run); run by hand with no args to force. Pops a Notification Center alert on
# failure.
#
# Connects via cloud-sql-proxy (IAM/ADC auth, so no IP allowlisting), with DB
# credentials read from the gitignored prod_secrets.json next to this repo's
# admin_site. Keeps the last 30 dumps.

set -euo pipefail

NAME="slsl-db"
MARKER_DIR="$HOME/.local/state/dictionary-backups"
MARKER="$MARKER_DIR/$NAME.last-success"
LOG_HINT="~/Library/Logs/me.dport.backup-slsl-db.log"
PROXY_PID=""

on_exit() {
    code=$?
    [ -n "$PROXY_PID" ] && kill "$PROXY_PID" 2>/dev/null || true
    if [ "$code" -ne 0 ]; then
        /usr/bin/osascript -e "display notification \"Exit $code — see $LOG_HINT\" with title \"Backup FAILED: $NAME\"" || true
    fi
}
trap on_exit EXIT

if [ "${1:-}" = "--if-stale" ] && [ -n "$(find "$MARKER" -mmin -1200 2>/dev/null)" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $NAME backup fresh (<20h), skipping"
    exit 0
fi

if [ ! -d "$HOME/gdrive" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - skipped: ~/gdrive not mounted" >&2
    exit 1
fi

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
PGPASSWORD="$SQL_PASSWORD" "$PG_DUMP" \
    -h 127.0.0.1 -p "$PROXY_PORT" -U "$SQL_USER" -d "$SQL_DATABASE" \
    --no-owner --no-acl | gzip > "$OUT"

# A dump this small should never be empty; treat that as failure.
[ -s "$OUT" ] || { echo "dump is empty" >&2; exit 1; }

# Keep the newest 30 dumps.
ls -1t "$DEST"/slsl-db-*.sql.gz | tail -n +31 | while read -r old; do rm -f "$old"; done

mkdir -p "$MARKER_DIR" && touch "$MARKER"
echo "$(date '+%Y-%m-%d %H:%M:%S') - $NAME backup completed: $(du -h "$OUT" | cut -f1) $(basename "$OUT")"
