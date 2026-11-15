#!/usr/bin/env bash
# The install lock (docs/GETTING-STARTED.md, docs/THREAT-MODEL.md): only a message from the owner or a super-user may make the
# agent install packages, tools or skills. Called by the managed policy's hooks with the hook's JSON on stdin, and by start.sh.
#   install-lock.sh turn    UserPromptSubmit: open the lock for this turn if the message is a super-user's, else close it
#   install-lock.sh check   PreToolUse: an install while the lock is closed is refused (exit 2); the install record is never written by hand
#   install-lock.sh record  PostToolUse: an install that ran is added to /data/tools.json and the owner is told
#   install-lock.sh replay  start.sh: make the Python environment, then reinstall the recorded packages (failures are logged)
set -uo pipefail
OK=/data/cron/install-ok; LOG=/data/tools.json; B=$(dirname "$(readlink -f "$0")")
# Package managers. A pattern, not a sandbox (docs/THREAT-MODEL.md).
INSTALL='(^|[^[:alnum:]_.-])((uv( pip| tool)?|pip[0-9.x]*|python3? -m pip|npm|pnpm|yarn|bun) +(install|i|add)( |$)|(uvx|bunx|npx|bun x)( |$)|claude +(plugin|mcp) )'
# Where installs live. From the shell, any mention of these counts, except running what is there and reading it (refused: check).
WHERE='/data/(bin|tools)(/|[^A-Za-z0-9_.-]|$)|\.claude/skills|/data/config/skills'
# What is recorded and announced as an install: a package manager, or a plain write there (record). Narrower on purpose: a script
# that only names the folder is refused while the lock is closed, but is not announced as an install when it is open.
WRITE="$INSTALL|(^|[;&|(] *)(cp|mv|ln|install|tee|touch|mkdir|rm|rmdir|chmod|chown|tar|unzip|curl|wget|rsync|dd|git) [^;&|]*($WHERE)|>+ *[\"']?[^ ;&|]*($WHERE)"
# Never written by hand, whoever asks: the lock, the install record, the settings and the jobs (config.sh writes those and tells the owner).
KEPT='install-o|tools\.js|/data/sett|/data/cron/(jo|pro)'
# Only these are replayed at start, and only if every word is a package name or exactly --python /data/tools/venv/bin/python.
REPLAY='^(uv pip install|uv tool install|bun add -g) '
SPEC='^(@[a-z0-9._-]+/)?[A-Za-z0-9][A-Za-z0-9._-]*(\[[A-Za-z0-9,._-]+\])?([=<>!~@]=?[A-Za-z0-9.*+,<>=~-]*)*$'
in=$( [ "${1:-}" = replay ] || cat )
field() { jq -r "$1 // \"\"" <<<"$in"; }
# The main session only: scheduled jobs and the dream run with their own config directory and never get the lock.
main_session() { [ "${CLAUDE_CONFIG_DIR-}" = /data/config ]; }
open() { main_session && [ -n "$(field .session_id)" ] && [ "$(jq -r .session "$OK" 2> /dev/null)" = "$(field .session_id)" ]; }
plain() { tr -d '\\"'"'"'[]*?{}'; }  # what a pattern match sees: no quotes, escapes or glob characters
in_place() { case "$(realpath -m -- "$(field '.tool_input.file_path // .tool_input.notebook_path')")" in
  /data/bin/*|/data/tools/*|/data/config/skills/*|*/.claude/skills/*) true ;; *) false ;; esac; }
# Each command on its own, without running an installed tool (with its variables) and without read-only looks: what is left must not name them.
uses_only() { local c; c=$(field .tool_input.command | plain)
  ! grep -qE -- '\$\(|`|<\(' <<<"$c" || ! grep -qE -- "$WHERE" <<<"$c" || return 1
  tr ';&|(' '\n' <<<"$c" | sed -E 's/^ +//; s#^([A-Za-z_][A-Za-z0-9_]*=[^ ]* +)*/data/(bin|tools/venv/bin)/[A-Za-z0-9._-]+( |$)##' \
    | grep -vE '^(ls|cat|head|tail|file|stat|du|wc|which|readlink)( [^<>]*)?$' | grep -qE -- "$WHERE" && return 1; return 0; }
cmd() { field .tool_input.command; field .tool_input.command | plain; }  # as typed, and without quotes and escapes
install() { grep -qE -- "$INSTALL" <<<"$(cmd)" || in_place || ! uses_only; }
wrote() { grep -qE -- "$WRITE" <<<"$(field .tool_input.command)" || in_place; }
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
      { echo "The settings, the jobs and the install record are kept by the policy: change them with config.sh, read the record with the Read tool." >&2; exit 2; }
    ! grep -qE -- '(config|peer)\.sh[^;&|]*admin' <<<"$(cmd)" || open ||
      { echo "Only the owner or a super-user can name a super-user. Say so, and do not try another way." >&2; exit 2; }
    ! install || open || { echo "Only the owner or a super-user can ask for an install (packages, tools, skills, /data/bin, /data/tools). Say so, and do not try another way." >&2; exit 2; } ;;
  record)
    wrote && open || exit 0
    jq -cn --slurpfile o "$OK" --arg t "$(field .tool_name)" --arg c "$(field '.tool_input.command // .tool_input.file_path // .tool_input.notebook_path')" \
      '{at: (now | todate), by: $o[0].user, by_id: $o[0].id, tool: $t, command: $c}' >> "$LOG"
    "$B/notify.sh" "🧰 Installed at the request of $(jq -r .user "$OK"): $(field '.tool_input.command // .tool_input.file_path' | head -c 300)" || true ;;
  replay)
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
