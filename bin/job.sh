#!/usr/bin/env bash
# Runs one scheduled prompt and delivers the answer to the owner. Usage: job.sh NAME (the prompt is in /data/cron/prompts/NAME; see config.sh job)
set -uo pipefail
name=$1; shift; [ $# -gt 0 ] || set -- "$(cat "/data/cron/prompts/$name")"
# Its own config directory: a second Claude on the bot's directory would start a second Telegram plugin, which kills the first.
export CLAUDE_CONFIG_DIR=/data/cron/config
cd /data/workspace || exit 1
to=$(cat "/data/cron/prompts/$name.to" 2> /dev/null || true)  # a group to deliver to; empty = the owner, in private
grep -qxF "group $to" /data/settings 2> /dev/null || to=    # only a group this agent is still in
# This session has no Telegram on purpose: it only writes the message, and this script delivers it.
if out=$(timeout "${JOB_TIMEOUT:-900}" claude -p --permission-mode auto "$*

Write only the text of the message. It is delivered to Telegram for you: do not look for a tool to send it." 2> "/data/cron/$name.err") && [ -n "$out" ]; then
  # The bot's own session never saw this message: record it. A hook shows the bot its recent deliveries with every message it receives.
  # Sent first, recorded only if Telegram took it: a refused delivery (bot removed, group renumbered) is told to the owner.
  notify.sh "$out" "$to" || { notify.sh "⚠️ Scheduled job \"$name\" could not be delivered to ${to:-the owner}."; exit 1; }
  jq -cn --arg n "$name" --arg to "$to" --arg t "$out" '{at: (now | floor), name: $n, to: $to, text: $t}' >> sent.jsonl
  # A one-off (a fixed day and month) is done once delivered: remove it, or it would come back next year.
  ! grep -qE "^[^ ]+ [^ ]+ [0-9]+ [0-9]+ [^ ]+ job\.sh $name$" /data/cron/jobs 2> /dev/null || config.sh drop "$name" > /dev/null || true
else
  notify.sh "⚠️ Scheduled job \"$name\" failed or timed out. ${out:0:300} $(tail -c 300 "/data/cron/$name.err")"; exit 1  # Claude gives its reason (a limit, no login) on standard output
fi
