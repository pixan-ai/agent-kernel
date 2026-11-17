#!/usr/bin/env bash
# The install lock (docs/GETTING-STARTED.md, docs/THREAT-MODEL.md): only a message from the owner or a super-user may make the
# agent install packages, tools or skills. Called by the managed policy's hooks with the hook's JSON on stdin, and by start.sh.
#   install-lock.sh turn    UserPromptSubmit: open the lock for this turn if the message is a super-user's, else close it
#   install-lock.sh check   PreToolUse: an install while the lock is closed is refused (exit 2); the install record is never written by hand
#   install-lock.sh record  PostToolUse: an install that ran is added to /data/tools.json and the owner is told; a change in the
#                           install folders with the lock closed is told to the owner
#   install-lock.sh replay  start.sh: make the Python environment, then reinstall the recorded packages (failures are logged)
set -uo pipefail
OK=/data/cron/install-ok; SEEN=$OK.seen; LOG=/data/tools.json; B=$(dirname "$(readlink -f "$0")")
# Package managers, also with options before the verb. A pattern, not a sandbox (docs/THREAT-MODEL.md).
F='( +-[^ ]+)*'
INSTALL="(^|[^[:alnum:]_.-])((uv$F( +(pip|tool))?|pip[0-9.x]*|python3? -m pip|npm|pnpm|yarn|bun)$F +(install|i|add)( |\$)|(uv$F +tool$F +run|uvx|bunx|npx|bun x)( |\$)|claude +(plugin|mcp) )"
# Where installs live: the shell can write there in too many ways to guess them, so what changed is looked at after each command (record).
WATCH=(/data/bin /data/tools /data/config/skills /data/workspace/.claude/skills)
# Never written by hand, whoever asks: the lock and its mark, the install record, the settings, the jobs (config.sh writes those and
# tells the owner) and the keys. Not anchored to /data: a relative path after cd counts too.
KEPT='install-o([^p]|$)|(^|[^/[:alnum:]_.-]|/data/)tools\.js|/data/sett|/data/cron/(jo|pro)|/data/ssh'
# Only these are replayed at start, and only if every word is a package name or exactly --python /data/tools/venv/bin/python.
REPLAY='^(uv pip install|uv tool install|bun add -g) '
SPEC='^(@[a-z0-9._-]+/)?[A-Za-z0-9][A-Za-z0-9._-]*(\[[A-Za-z0-9,._-]+\])?([=<>!~@]=?[A-Za-z0-9.*+,<>=~-]*)*$'
in=$( [ "${1:-}" = replay ] || cat )
field() { jq -r "$1 // \"\"" <<<"$in"; }
# The main session only: scheduled jobs and the dream run with their own config directory and never get the lock.
main_session() { [ "${CLAUDE_CONFIG_DIR-}" = /data/config ]; }
open() { main_session && [ -n "$(field .session_id)" ] && [ "$(jq -r .session "$OK" 2> /dev/null)" = "$(field .session_id)" ]; }
plain() { tr -d '\\"'"'"'[]*?{}'; }  # what a pattern match sees: no quotes, escapes or glob characters
in_place() { case "$(realpath -m -- "$(field '.tool_input.file_path // .tool_input.notebook_path')" 2> /dev/null)" in
  /data/bin/*|/data/tools/*|/data/config/skills/*|*/.claude/skills/*) true ;; *) false ;; esac; }
cmd() { field .tool_input.command; field .tool_input.command | plain; }  # as typed, and without quotes and escapes
install() { grep -qE -- "$INSTALL" <<<"$(cmd)" || in_place; }
# The first thing changed in the install folders since the last look (by change time, which cannot be set back; bytecode a first import writes is left out)
changed() { [ ! -e "$SEEN" ] || find "${WATCH[@]}" -cnewer "$SEEN" ! -type d ! -name '*.pyc' -print -quit 2> /dev/null; }
case "${1:-}" in
  turn)
    main_session || exit 0; rm -f "$OK"
    # A Telegram message reaches Claude as <channel source="…telegram…" chat_id="…" user="…" user_id="…" …> on a line of its own,
    # then the text. The values cannot hold a quote, and the text comes after that line, so a tag typed in a message is never the
    # first line; and a turn with a second <channel (a typed one, or two messages at once) gets no lock at all.
    p=$(field .prompt); first=${p%%$'\n'*}
    [[ $first =~ ^\<channel\ source=\"[^\"]*telegram[^\"]*\"(\ [A-Za-z_][A-Za-z0-9_]*=\"[^\"]*\")*\>$ ]] || exit 0
    [ "$(grep -oi '<channel' <<<"$p" | wc -l)" = 1 ] || exit 0
    [[ $first =~ \ user_id=\"([0-9]+)\" ]] || exit 0; id=${BASH_REMATCH[1]}
    [[ $first =~ \ user=\"([^\"]*)\" ]] && who=${BASH_REMATCH[1]} || who=$id
    grep -qxF "OWNER_TELEGRAM_ID=$id" /data/config/channels/telegram/.env 2> /dev/null || grep -qxF "admin $id" /data/settings 2> /dev/null || exit 0
    jq -n --arg s "$(field .session_id)" --arg id "$id" --arg u "$who" '{session: $s, id: $id, user: $u}' > "$OK" ;;
  check)
    ! grep -qE -- "$KEPT" <<<"$(printf '%s %s' "$(field .tool_input.command)" "$(realpath -m -- "$(field '.tool_input.file_path // .tool_input.notebook_path')")" | plain)" ||
      { echo "The settings, the jobs, the install record and the keys are kept by the policy: change settings and jobs with config.sh, read the record with the Read tool." >&2; exit 2; }
    ! grep -qE -- '(config|peer)\.sh[^;&|]*admin' <<<"$(cmd)" || open ||
      { echo "Only the owner or a super-user can name a super-user. Say so, and do not try another way." >&2; exit 2; }
    ! install || open || { echo "Only the owner or a super-user can ask for an install (packages, tools, skills, /data/bin, /data/tools). Say so, and do not try another way." >&2; exit 2; } ;;
  record)
    c=$(changed); touch "$SEEN"
    open || { [ -z "$c" ] || "$B/notify.sh" "⚠️ $c changed in the install folders, with no request from you or a super-user, after: $(field .tool_input.command | head -c 300)" || true; exit 0; }
    install || [ -n "$c" ] || exit 0
    jq -cn --slurpfile o "$OK" --arg t "$(field .tool_name)" --arg c "$(field '.tool_input.command // .tool_input.file_path // .tool_input.notebook_path')" \
      '{at: (now | todate), by: $o[0].user, by_id: $o[0].id, tool: $t, command: $c}' >> "$LOG"
    "$B/notify.sh" "🧰 Installed at the request of $(jq -r .user "$OK"): $(field '.tool_input.command // .tool_input.file_path' | head -c 300)" || true ;;
  replay)
    trap 'touch "$SEEN"' EXIT  # what the start puts back is not news to the owner
    mkdir -p /data/bin /data/tools
    ! command -v uv > /dev/null || [ -x /data/tools/venv/bin/python ] || uv venv -q --python /usr/bin/python3 /data/tools/venv || echo "install-lock: no Python environment (not fatal)" >&2
    [ -s "$LOG" ] || exit 0
    # The agent chains commands on one line: take each part on its own, without its redirections, and keep the installs.
    jq -r '.command // empty' "$LOG" | sed -E 's/ [0-9]*>(&[0-9]+|[^ ]*)//g' | tr ';|&' '\n' | sed -E 's/^ +| +$//g' | grep -E -- "$REPLAY" | awk '!seen[$0]++' | while IFS= read -r c; do
      read -ra w <<<"$c"
      for ((i = 3; i < ${#w[@]}; i++)); do [[ ${w[i]} =~ $SPEC ]] || { [ "${w[i]} ${w[i+1]:-}" = "--python /data/tools/venv/bin/python" ] && ((i++)); } || continue 2; done
      "${w[@]}" < /dev/null > /dev/null 2>&1 && echo "install-lock: reinstalled: $c" >&2 || echo "install-lock: could not reinstall (not fatal): $c" >&2
    done ;;
  *) sed -n '2,8p' "$0" >&2; exit 2 ;;
esac
