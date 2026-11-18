#!/usr/bin/env bash
# What the agent installs, and what changes by hand (docs/GETTING-STARTED.md, docs/THREAT-MODEL.md). Who may ask for an install
# is the agent's judgment under its instructions (policy/CLAUDE.md), not a lock: this script keeps the record and tells the owner.
#   installs.sh record  PostToolUse: a change in the install folders is recorded in /data/tools.json and the owner is told;
#                       a change in the settings, the jobs or the bot's files that did not go through config.sh is told too
#   installs.sh replay  start.sh: make the Python environment, then reinstall the recorded packages (failures are logged)
#   installs.sh mark    config.sh: its own change was told, so take the settings as they are now
set -uo pipefail
SEEN=/data/cron/watch.seen; SUMS=/data/cron/watch.sums; LOG=/data/tools.json; B=$(dirname "$(readlink -f "$0")")
TOOLS=(/data/bin /data/tools /data/config/skills /data/workspace/.claude/skills)
KEPT=(/data/settings /data/cron/jobs /data/cron/prompts /data/cron/crontab /data/config/settings.json /data/config/channels/telegram/.env /data/config/channels/telegram/access.json)
# Only these are replayed at start, and only if every word is a package name or exactly --python /data/tools/venv/bin/python.
REPLAY='^(uv pip install|uv tool install|bun add -g) '
SPEC='^(@[a-z0-9._-]+/)?[A-Za-z0-9][A-Za-z0-9._-]*(\[[A-Za-z0-9,._-]+\])?([=<>!~@]=?[A-Za-z0-9.*+,<>=~-]*)*$'
in=$( [[ ${1:-} =~ ^(replay|mark)$ ]] || cat )
field() { jq -r "$1 // \"\"" <<<"$in"; }
# Installs: the first file changed since the last look, by change time, which cannot be set back (left out: the bytecode a first import
# writes, and the lock files a tool takes while it runs). The settings: by content, since the plugin touches its own files at start.
# config.sh, the start and the replay mark the state after their own writes, so only other writers are reported.
changed() { [ ! -e "$SEEN" ] || find "$@" -cnewer "$SEEN" ! -type d ! -name '*.pyc' ! -name '*.lock' ! -path '*/.locks/*' -print -quit 2> /dev/null; }
sums() { find "${KEPT[@]}" -type f -print0 2> /dev/null | sort -z | xargs -0 -r sha256sum; true; }  # some of them may not exist yet
case "${1:-}" in
  record)
    t=$(changed "${TOOLS[@]}"); k=$([ ! -e "$SUMS" ] || diff <(sums) "$SUMS" | sed -n 's/^< [0-9a-f]* *//p' | head -1); touch "$SEEN"; sums > "$SUMS"; c=$(field '.tool_input.command // .tool_input.file_path // .tool_input.notebook_path')
    [ -z "$k" ] || "$B/notify.sh" "⚠️ $k was changed by hand, not through config.sh, after: ${c:0:300}" || true
    [ -n "$t" ] || exit 0
    jq -cn --arg t "$(field .tool_name)" --arg c "$c" '{at: (now | todate), tool: $t, command: $c}' >> "$LOG"
    "$B/notify.sh" "🧰 Installed: ${c:0:300}" || true ;;
  mark) touch "$SEEN"; sums > "$SUMS" ;;
  replay)
    trap 'touch "$SEEN"; sums > "$SUMS"' EXIT  # what the start wrote and puts back is not news to the owner
    cd / && export UV_NO_CONFIG=1  # a uv.toml planted in the workspace must not choose the package index
    mkdir -p /data/bin /data/tools
    ! command -v uv > /dev/null || [ -x /data/tools/venv/bin/python ] || uv venv -q --python /usr/bin/python3 /data/tools/venv || echo "installs: no Python environment (not fatal)" >&2
    [ -s "$LOG" ] || exit 0
    # The agent chains commands on one line: take each part on its own, without its redirections, and keep the installs.
    jq -r '.command // empty' "$LOG" | sed -E 's/ [0-9]*>(&[0-9]+|[^ ]*)//g' | tr ';|&' '\n' | sed -E 's/^ +| +$//g' | grep -E -- "$REPLAY" | awk '!seen[$0]++' | while IFS= read -r c; do
      read -ra w <<<"$c"
      for ((i = 3; i < ${#w[@]}; i++)); do [[ ${w[i]} =~ $SPEC ]] || { [ "${w[i]} ${w[i+1]:-}" = "--python /data/tools/venv/bin/python" ] && ((i++)); } || continue 2; done
      "${w[@]}" < /dev/null > /dev/null 2>&1 && echo "installs: reinstalled: $c" >&2 || echo "installs: could not reinstall (not fatal): $c" >&2
    done ;;
  *) sed -n '2,6p' "$0" >&2; exit 2 ;;
esac
