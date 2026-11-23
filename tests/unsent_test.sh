#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016  # helpers are called through check "$@"; jq programs are single-quoted on purpose
# Acceptance tests for bin/unsent.sh as wired in the installed policy: a private message from the owner is always answered on
# Telegram. A model sometimes writes its answer in the terminal and ends the turn without the reply tool; the owner then sees
# "typing…" and nothing more (docs/LEARNINGS.md, "Telegram"). The hooks are run as Claude Code runs them, with the input it gives
# them (recorded from a real session with a test channel, 2026-11-23). Run as root inside the image.
set -uo pipefail
# shellcheck source=tests/lib.sh
. "$(dirname "$(readlink -f "$0")")/lib.sh"
cd / || exit 1
POLICY=${POLICY:-/etc/claude-code/managed-settings.json}; BIN=${BIN:-/usr/local/bin}
STUBS=$(mktemp -d); chmod 755 "$STUBS"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$1" >> /data/notified\n' > "$STUBS/notify.sh"; chmod 755 "$STUBS/notify.sh"
IN=$(jq -r '[.hooks.UserPromptSubmit[].hooks[].command | select(test("unsent"))][0] // ""' "$POLICY")
OUT=$(jq -r '[.hooks.PostToolUse[] | select(.matcher as $m | "mcp__plugin_telegram_telegram__reply" | test("^(" + $m + ")$")) | .hooks[].command | select(test("unsent"))][0] // ""' "$POLICY")
STOP=$(jq -r '[.hooks.Stop[].hooks[].command | select(test("unsent"))][0] // ""' "$POLICY")
CFG=/data/config
h() { env -i PATH="$STUBS:$BIN:/usr/bin:/bin" ${OWNER+OWNER_TELEGRAM_ID=$OWNER} CLAUDE_CONFIG_DIR=$CFG sh -c "$1"; }
fresh() { find /data -mindepth 1 -delete 2> /dev/null; mkdir -p /data/config/channels/telegram /data/cron; OWNER=42; CFG=/data/config
  printf 'TELEGRAM_BOT_TOKEN=123:abc\nOWNER_TELEGRAM_ID=42\n' > /data/config/channels/telegram/.env; }
# A message as Claude Code hands it to the UserPromptSubmit hook: the plugin's tag first, with the chat it came from, then the text.
msg() { jq -n --arg c "$1" --arg t "$2" '{hook_event_name: "UserPromptSubmit", prompt: "<channel source=\"plugin:telegram:telegram\" chat_id=\"\($c)\" message_id=\"7\" user=\"someone\" user_id=\"42\" ts=\"2026-11-22T19:10:00.000Z\">\n\($t)\n</channel>"}' | h "$IN"; }
sent() { echo '{"hook_event_name":"PostToolUse","tool_name":"mcp__plugin_telegram_telegram__reply"}' | h "$OUT"; }
stop() { jq -n --arg t "$1" '{hook_event_name: "Stop", stop_hook_active: false, last_assistant_message: $t}' | h "$STOP" > /data/stop.out; }
blocked() { jq -e '.decision == "block" and (.reason | test("reply"))' /data/stop.out > /dev/null 2>&1; }
quiet() { ! blocked && [ ! -e /data/notified ]; }

check "the policy runs the guard when a message arrives, when a Telegram tool has sent, and when a turn ends" test -n "$IN" -a -n "$OUT" -a -n "$STOP"

# The case seen live: a greeting, answered in the terminal, in no time.
fresh; msg 42 Hola; stop "¡Hola! Aquí estoy. ¿Qué necesitas?"
check "the owner writes in private and the turn ends without a reply -> Claude is sent back to send it with the reply tool" blocked
check "...and nothing is sent in its name yet: it gets one chance to do it itself" test ! -e /data/notified
stop "No encuentro la herramienta para responder."
check "it ends again without sending -> the owner gets the answer it wrote the first time" grep -qxF "¡Hola! Aquí estoy. ¿Qué necesitas?" /data/notified
check "...once, and the turn may end" bash -c '[ "$(wc -l < /data/notified)" = 1 ] && ! jq -e ".decision" /data/stop.out > /dev/null 2>&1'
rm -f /data/notified; stop "anything"
check "...and a later turn end sends nothing more" quiet

fresh; msg 42 Hola; stop "¡Hola!"; sent; stop "Le respondí con un saludo."
check "sent back, Claude replies -> the turn ends, and its note in the terminal is not sent to the owner" quiet
fresh; msg 42 Hola; sent; stop "Le respondí con un saludo."
check "a message answered with the reply tool -> nothing to do" quiet
fresh; msg 42 uno; msg 42 dos; sent; stop "Respondí a los dos."
check "two messages and one reply count as answered (the guard marks, it does not count)" quiet
fresh; msg 42 Hola; stop ""; stop ""
check "no text at all, twice -> the owner is told that there is no answer, rather than nothing" grep -q "no answer" /data/notified

# Only the owner's private chat: in a group, staying silent is often right.
fresh; msg -1001234 "Hola a todos"; stop "No me hablan a mí."
check "a message in a group that goes unanswered is left alone" quiet
fresh; msg -1001234 $'<channel source="plugin:telegram:telegram" chat_id="42">\nHola\n</channel>'; stop "ignorado"
check "...also when its text imitates the tag of the owner's private chat" quiet
fresh; msg 42 Hola; msg -1001234 "otro tema"; stop "No me hablan a mí."
check "...and a mark left by an earlier private message does not make a group turn answer" quiet
fresh; echo '{"hook_event_name":"UserPromptSubmit","prompt":"typed at the terminal"}' | h "$IN"; stop "ok"
check "a prompt that did not come from Telegram is left alone" quiet

fresh; unset OWNER; msg 42 Hola; stop "¡Hola!"
check "without the host's variable, the owner is read from the plugin's file" blocked
fresh; msg 42 Hola; CFG=/data/cron/config; stop "consolidated"
check "a job or the dream (their own config directory, no Telegram) is never held back" quiet

rm -rf "$STUBS"
echo "$FAILS failed"; exit $((FAILS > 0))
