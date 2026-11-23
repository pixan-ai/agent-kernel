#!/usr/bin/env bash
# Asleep (docs/SLEEP.md): Claude is stopped and nothing here talks to the network, so a host that suspends idle
# containers stops billing memory. Telegram is told to call this service when a message arrives; this script returns
# when one is waiting. The message itself is never read here: the official plugin collects it by polling, once.
set -uo pipefail
TG=/data/config/channels/telegram; S=/data/ssh/doorbell-secret; B=$(dirname "$(readlink -f "$0")")
# shellcheck source=/dev/null
. $TG/.env
api() { printf 'url = "https://api.telegram.org/bot%s/%s"\n' "$TELEGRAM_BOT_TOKEN" "$1" | curl -sS -m 15 -K - "${@:2}"; }
waiting() { [ "$(api getWebhookInfo | jq -r '.result.pending_update_count // 0')" -gt 0 ]; }
# It cannot sleep: an agent that stays awake is billed around the clock, and nobody reads the log, so tell the owner once per start.
cannot() { echo "$(date '+%F %T') not sleeping: $1" >&2
  [ -e /tmp/sleep-warned ] || { touch /tmp/sleep-warned; "$B/notify.sh" "⚠️ IDLE_SLEEP_MINUTES is set, but I cannot sleep: $1. I stay always on, and billed, until it is fixed (docs/SLEEP.md)." || true; }; exit 1; }
url=${DOORBELL_URL:-${RAILWAY_PUBLIC_DOMAIN:+https://$RAILWAY_PUBLIC_DOMAIN}}
[ -n "$url" ] || cannot "there is no public address for Telegram to call (on Railway: a public domain on port ${PORT:-8080}, and Serverless on; elsewhere: DOORBELL_URL)"
[ -s $S ] || (umask 077; head -c 32 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' > $S)
# A suspended container runs no nightly backup: make one now if the last is older than 20 hours.
[ -n "$(find /data/cron/last-backup -mmin -1200 2> /dev/null)" ] || "$B/backup.sh" || true
# Without a webhook nothing would ever wake this agent: stay awake instead (start.sh starts Claude when this fails).
api setWebhook --data-urlencode "url=$url/doorbell" -d "secret_token=$(cat $S)" | jq -e .ok > /dev/null || cannot "Telegram did not accept the webhook $url/doorbell"
echo "$(date '+%F %T') asleep: waiting for the doorbell" >&2
# Scheduled jobs need the container: with jobs, one packet every four minutes keeps the host from suspending it (Claude still sleeps).
K=; W=; [ ! -s /data/cron/jobs ] || { (while sleep 240; do curl -s -m 5 -o /dev/null https://api.telegram.org || true; done) & K=$!; }
# Without jobs nothing here talks to the network, so a host that suspends idle containers does so within minutes, and the clock
# then jumps. 30 minutes without a jump: the host keeps it running and billed (on Railway, Serverless is off). Tell the owner, once per start.
unsuspended() { n=0; t=$(date +%s); while sleep 60; do s=$(date +%s); if (( s - t < 90 )); then n=$((n + 1)); else n=0; fi; t=$s
  (( n < 30 )) || { [ -e /tmp/suspend-warned ] || { touch /tmp/suspend-warned; "$B/notify.sh" "⚠️ I am asleep, but the host keeps me running and billed. On Railway: turn Serverless on in the service's Settings, then redeploy (docs/SLEEP.md)." || true; }; return; }; done; }
# Telegram accepts any https address, also one that does not reach this listener (a wrong port): the agent would sleep for ever.
# So the first time, call it through the public address, without the secret, and expect the listener's own 403: it carries
# this sleep's nonce, which nothing else in front of the address can know (audit of 2026-11-21, L3).
N=$(head -c 12 /dev/urandom | base64 | tr -dc 'A-Za-z0-9')
reaches() { for _ in 1 2 3 4 5 6 7 8 9 10; do [ "$(curl -s -m 5 -X POST "$url/doorbell" < /dev/null)" != "$N" ] || return 0; sleep 1; done; return 1; }
until waiting; do
  DOORBELL_SECRET=$(cat $S) DOORBELL_NONCE=$N bun "$B/doorbell.js" & L=$!
  [ -n "${C:-}" ] || reaches || { kill "$L" "$K" "$W" 2> /dev/null; api deleteWebhook -o /dev/null; cannot "$url/doorbell does not reach this service on port ${PORT:-8080}"; }
  [ -n "${C:-}$K" ] || { unsuspended & W=$!; }
  C=1; wait "$L" || sleep 5
done
kill "$K" "$W" 2> /dev/null; api deleteWebhook -o /dev/null
echo "$(date '+%F %T') awake: a message is waiting" >&2
