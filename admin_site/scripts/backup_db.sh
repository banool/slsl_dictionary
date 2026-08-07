#!/bin/bash

# Nightly logical backup (pg_dump) of the SLSL content DB — the Cloud SQL
# Postgres behind this Django admin, the hand-curated source of truth for all
# SLSL dictionary content. Complements (not replaces) the Cloud SQL automated
# daily backups enabled in deployment/db.ts: this copy is off-GCP, in gdrive,
# and survives project-level disasters.
#
# Invoked once every 24 hours by the launchd agent me.dport.backup-slsl-db
# (plist in dotfiles/macos/launchagents/) with --if-stale; run by hand with no
# args to force. Pops a Notification Center alert on failure — but only on a
# real one, see the network gate below.
#
# Connects via cloud-sql-proxy (IAM/ADC auth, so no IP allowlisting), with DB
# credentials read from the gitignored prod_secrets.json next to this repo's
# admin_site. Keeps the last 30 dumps.

set -euo pipefail

NAME="slsl-db"
MARKER_DIR="$HOME/.local/state/job-markers"
MARKER="$MARKER_DIR/$NAME.last-success"
LOG_HINT="~/Library/Logs/me.dport.backup-slsl-db.log"
PROXY_PID=""

stamp() { date '+%Y-%m-%d %H:%M:%S'; }

# --- network gate ---------------------------------------------------------
#
# This runs on a laptop, where "no network" is a normal condition rather than a
# fault: the lid is shut, wifi hasn't reassociated yet, there's no signal. And
# it is the condition this job is most likely to meet, because launchd
# coalesces the nightly firings missed while asleep into one firing on wake —
# so the scheduled run lands in the exact second the lid opens, before DNS
# answers. Every "Backup FAILED" alert in this job's history has been that:
# `lookup oauth2.googleapis.com: no such host` against a database that was
# perfectly healthy.
#
# So a run with no network is DEFERRED, not failed: exit 0, no alert, marker
# untouched. Untouched is what keeps this honest — the dashboard's freshness
# board reads that marker, so backups that have genuinely stopped still go
# amber. Deferring buys silence for a few hours, it does not buy silence.

# Apple's captive-portal endpoint, which is what macOS itself uses to decide
# whether it is online. It needs DNS, a route, and an unintercepted answer, so
# a hotel portal (a 200 serving a login page) correctly reads as offline.
online() {
    local body
    body=$(/usr/bin/curl -sf -m 5 http://captive.apple.com/hotspot-detect.html 2>/dev/null) || return 1
    case "$body" in *"<TITLE>Success</TITLE>"*) return 0 ;; *) return 1 ;; esac
}

# Wifi takes a few seconds to come back after the lid opens, so wait rather
# than judging the network by its worst moment. Bounded: ~2 minutes of waiting.
await_network() {
    local waited=0
    while ! online; do
        [ "$waited" -ge 120 ] && return 1
        sleep 5
        waited=$((waited + 5))
    done
}

on_exit() {
    code=$?
    [ -n "$PROXY_PID" ] && kill "$PROXY_PID" 2>/dev/null || true
    if [ "$code" -ne 0 ]; then
        # Re-checked here as well as up front, because the network can go away
        # mid-dump — and then the failure belongs to the disconnect, not to the
        # database. Same deferral, same reasoning.
        if online; then
            /usr/bin/osascript -e "display notification \"Exit $code — see $LOG_HINT\" with title \"Backup FAILED: $NAME\"" || true
        else
            echo "$(stamp) - $NAME deferred: network went away mid-run (exit $code); retrying at the next scheduled run"
            exit 0
        fi
    fi
}
trap on_exit EXIT

# The guard exists only so that RunAtLoad (and the wake-up catch-up firing)
# can't repeat a backup that just happened. It must stay WELL under 24h: a
# catch-up that ran at, say, 22:00 would otherwise still look "fresh" at the
# 03:30 firing five hours later, that firing would skip, and the next one is a
# day after that — a 29h gap dressed up as a healthy backup.
if [ "${1:-}" = "--if-stale" ] && [ -n "$(find "$MARKER" -mmin -240 2>/dev/null)" ]; then
    echo "$(stamp) - $NAME backup ran <4h ago, skipping"
    exit 0
fi

if ! await_network; then
    echo "$(stamp) - $NAME deferred: no network (laptop closed / wifi down); retrying at the next scheduled run"
    exit 0
fi

# Don't create ~/gdrive ourselves: if it's missing, Google Drive isn't
# mounted/syncing and we'd be "backing up" to a local-only folder. Deferred
# rather than failed for the same reason as the network — a Mac that booted
# 20 seconds ago hasn't mounted it yet, and the freshness board is what
# notices if it never does.
if [ ! -d "$HOME/gdrive" ]; then
    echo "$(stamp) - $NAME deferred: ~/gdrive not mounted"
    exit 0
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

mkdir -p "$MARKER_DIR" && touch "$MARKER"
echo "$(stamp) - $NAME backup completed: $(du -h "$OUT" | cut -f1) $(basename "$OUT")"
