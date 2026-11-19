#!/usr/bin/env bash
# What the agent installs, and what changes by hand (docs/GETTING-STARTED.md, docs/THREAT-MODEL.md). Who may ask for an install
# is the agent's judgment under its instructions (policy/CLAUDE.md), not a lock: this script keeps the record and tells the owner.
#   installs.sh record  PostToolUse: a change in the install folders is recorded in /data/tools.json and the owner is told;
#                       a change in the settings, the jobs, the bot's files, the workspace's Claude settings and MCP servers
#                       or the record itself that did not go through config.sh is told too
#   installs.sh replay  start.sh: make the Python environment, then reinstall the recorded packages (failures are logged)
#   installs.sh mark    config.sh: its own change was told, so take the settings as they are now
set -uo pipefail
SEEN=/data/cron/watch.seen; SUMS=/data/cron/watch.sums; LOG=/data/tools.json; B=$(dirname "$(readlink -f "$0")")
TOOLS=(/data/bin /data/tools /data/config/skills /data/workspace/.claude/skills)
KEPT=(/data/settings /data/cron/jobs /data/cron/prompts /data/cron/crontab /data/config/settings.json /data/config/channels/telegram/.env /data/config/channels/telegram/access.json
  /data/cron/config/settings.json /data/workspace/.mcp.json /data/workspace/.claude/settings.json /data/workspace/.claude/settings.local.json /data/workspace/CLAUDE.md "$LOG")
# Only these are replayed at start, and only if every word is a package name or exactly --python /data/tools/venv/bin/python.
REPLAY='^(uv pip install|uv tool install|bun add -g) '
GONE='^(uv pip uninstall|uv tool uninstall|bun remove -g) '  # recorded too, so that what was uninstalled does not come back
SPEC='^(@[a-z0-9._-]+/)?[A-Za-z0-9][A-Za-z0-9._-]*(\[[A-Za-z0-9,._-]+\])?([=<>!~@]=?[A-Za-z0-9.*+,<>=~-]*)*$'
in=$( [[ ${1:-} =~ ^(replay|mark)$ ]] || cat )
field() { jq -r "$1 // \"\"" <<<"$in"; }
# Installs: the first file changed since the last look, by change time, which cannot be set back (left out: the bytecode a first import
# writes, and the lock files a tool takes while it runs). The settings: by content, since the plugin touches its own files at start.
# config.sh, the start and the replay mark the state after their own writes, so only other writers are reported.
changed() { [ ! -e "$SEEN" ] || find "$@" -cnewer "$SEEN" ! -type d ! -name '*.pyc' ! -name '*.lock' ! -path '*/.locks/*' -print -quit 2> /dev/null; }
sums() { find "${KEPT[@]}" -type f -print0 2> /dev/null | sort -z | xargs -0 -r sha256sum  # some of them may not exist yet
  for f in /data/config/.claude.json /data/cron/config/.claude.json; do  # Claude Code rewrites it all the time: only its MCP servers count
    s=$(jq -cS '[.mcpServers // {}, (.projects // {} | .[] | .mcpServers // {})] | add | select(length > 0)' $f 2> /dev/null) && [ -n "$s" ] && echo "$(sha256sum <<<"$s" | cut -d' ' -f1)  $f"; done; true; }
case "${1:-}" in
  record)
    t=$(changed "${TOOLS[@]}"); k=$([ ! -e "$SUMS" ] || diff <(sums) "$SUMS" | sed -n 's/^< [0-9a-f]* *//p' | head -1); touch "$SEEN"; trap 'sums > "$SUMS"' EXIT; c=$(field '.tool_input.command // .tool_input.file_path // .tool_input.notebook_path')
    [ -z "$k" ] || "$B/notify.sh" "⚠️ $k was changed by hand, not through config.sh, after: ${c:0:300}" || true
    g=$(tr ';|&' '\n' <<<"$c" | sed -E 's/^ +//' | grep -E -- "$GONE")  # deleting files is not seen as a change: an uninstall is read from the command
    [ -n "$t$g" ] || exit 0
    jq -cn --arg t "$(field .tool_name)" --arg c "$c" '{at: (now | todate), tool: $t, command: $c}' >> "$LOG"
    "$B/notify.sh" "🧰 $([ -n "$t" ] && echo Installed || echo Removed): ${c:0:300}" || true ;;
  mark) touch "$SEEN"; sums > "$SUMS" ;;
  replay)
    trap 'touch "$SEEN"; sums > "$SUMS"' EXIT  # what the start wrote and puts back is not news to the owner
    cd / && export UV_NO_CONFIG=1  # a uv.toml planted in the workspace must not choose the package index
    mkdir -p /data/bin /data/tools
    ! command -v uv > /dev/null || [ -x /data/tools/venv/bin/python ] || uv venv -q --python /usr/bin/python3 /data/tools/venv || echo "installs: no Python environment (not fatal)" >&2
    [ -s "$LOG" ] || exit 0
    # The agent chains commands on one line: take each part on its own, without its redirections, and keep the installs and uninstalls.
    mapfile -t L < <(jq -r '.command // empty' "$LOG" | sed -E 's/ [0-9]*>(&[0-9]+|[^ ]*)//g' | tr ';|&' '\n' | sed -E 's/^ +| +$//g' | grep -E -- "$REPLAY|$GONE")
    pkg() { local p=${1#@}; echo "${p%%[=<>!~@[]*}"; }  # a package's name, without its version
    declare -A ran=()
    for ((n = 0; n < ${#L[@]}; n++)); do c=${L[n]}; [[ $c =~ $REPLAY ]] && [ -z "${ran[$c]:-}" ] || continue
      read -ra w <<<"$c"
      for ((j = n + 1; j < ${#L[@]}; j++)); do [[ ${L[j]} =~ $GONE ]] || continue; read -ra u <<<"${L[j]}"  # uninstalled later, by the same tool: skip
        [ "${u[0]}" = "${w[0]}" ] || continue; [ "${w[0]}" = bun ] || [ "${u[1]}" = "${w[1]}" ] || continue
        for p in "${u[@]:3}"; do for q in "${w[@]:3}"; do [ "$(pkg "$p")" != "$(pkg "$q")" ] || continue 4; done; done; done
      ran[$c]=1
      for ((i = 3; i < ${#w[@]}; i++)); do [[ ${w[i]} =~ $SPEC ]] || { [ "${w[i]} ${w[i+1]:-}" = "--python /data/tools/venv/bin/python" ] && ((i++)); } || continue 2; done
      "${w[@]}" < /dev/null > /dev/null 2>&1 && echo "installs: reinstalled: $c" >&2 || echo "installs: could not reinstall (not fatal): $c" >&2
    done ;;
  *) sed -n '2,6p' "$0" >&2; exit 2 ;;
esac
