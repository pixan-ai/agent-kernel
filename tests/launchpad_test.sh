#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016  # helpers are called through check "$@"; regexes are single-quoted on purpose
# Acceptance tests for host/launchpad, the host configuration a fleet supervisor uses to start agents (docs/FLEET.md).
# What was measured on a lab server (2026-11-25) is held here: the name is data, never shell; only "start" of a well-formed
# unit reaches systemd; a missing agent file fails the start; the agent file cannot set the owner, the Claude key or Claude's flags.
# Runs on the CI host, not in the image (it needs docker compose, not a daemon).
set -uo pipefail
# shellcheck source=tests/lib.sh
. "$(dirname "$(readlink -f "$0")")/lib.sh"
cd "$(dirname "$(readlink -f "$0")")/.." || exit 1
L=host/launchpad; T=$(mktemp -d)

# The wrapper: run it with a stand-in for sudo that records what reached it.
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> %s/sudo.log\n' "$T" > "$T/sudo"; chmod +x "$T/sudo"
sed "s#/usr/bin/sudo#$T/sudo#" $L/agent-launchpad-start > "$T/start"; chmod +x "$T/start"
start() { rm -f "$T/sudo.log"; SSH_ORIGINAL_COMMAND=$1 "$T/start" > /dev/null 2>&1; }  # runs in this shell: checks call it directly
reached() { [ "$(cat "$T/sudo.log" 2> /dev/null)" = "$1" ]; }
refused() { ! start "$1" && [ ! -e "$T/sudo.log" ]; }
start junior; check "a well-formed name reaches systemctl start, and only that" reached "-n /usr/bin/systemctl start agent-launchpad@junior.service"
for bad in 'x;id' '../x' 'X' 'a b' '*' '' '$(id)' 'stop junior' '-junior' 'a' "$(printf 'a%.0s' {1..40})" $'junior\nid'; do
  check "the name \"$(printf %q "$bad")\" is refused before sudo" refused "$bad"
done

# The sudo rule, the second fence: only "start agent-launchpad@NAME.service" with a well-formed NAME.
re=$(sed -n 's/.*systemctl \(\^.*\$\).*/\1/p' $L/sudoers)
check "the sudo rule allows systemctl with one anchored pattern" test -n "$re"
for ok in "start agent-launchpad@junior.service" "start agent-launchpad@a1-b.service"; do check "sudo allows \"$ok\"" grep -qE "$re" <<<"$ok"; done
for no in "stop agent-launchpad@junior.service" "start agent-launchpad@Junior.service" "start agent-launchpad@junior.service other.service" \
  "start agent-launchpad@*.service" "restart agent-launchpad@junior.service" "start sshd.service" "start agent-launchpad@a.service"; do
  check "sudo refuses \"$no\"" bash -c '! grep -qE "$1" <<<"$0"' "$no" "$re"
done

# The unit: a missing agent file must fail the start (Assert, not Condition, which exits 0), and the fixed values come from root's file.
U=$L/agent-launchpad@.service
check "the unit fails the start when the agent's file is missing (AssertPathExists)" bash -c 'grep -q "^AssertPathExists=" "$0" && ! grep -q "^ConditionPathExists=" "$0"' $U
check "the unit interpolates from root's file only (--env-file), never from a project .env" grep -q -- "--env-file /etc/agent-launchpad/fixed.env" $U
check "the unit never deletes a volume" bash -c '! grep -q -- "down -v" "$0"' $U

# What the agent's file can and cannot set: run compose's own resolution with a hostile agent file.
P=$T/project; mkdir -p "$P" "$T/fleet"; cp compose.yml Dockerfile "$P/"; : > "$P/.env"
printf 'OWNER_TELEGRAM_ID=42\nCLAUDE_KEY=sk-ant-oat01-fleet\nTZ=America/Mexico_City\nFLEET_DIR=%s\n' "$T/fleet" > "$T/fixed.env"
printf 'TELEGRAM_BOT_TOKEN=1:abc\nOWNER_TELEGRAM_ID=666\nCLAUDE_KEY=sk-ant-api03-evil\nCLAUDE_FLAGS=--dangerously-skip-permissions\nCOMPOSE_FILE=/etc/passwd\n' > "$T/fleet/junior.env"
if command -v docker > /dev/null && docker compose version > /dev/null 2>&1; then
  cfg=$(AGENT=junior docker compose -p agent-junior --env-file "$T/fixed.env" -f "$P/compose.yml" -f "$PWD/$L/compose.launchpad.yml" config --format json 2> "$T/err")
  env() { jq -r --arg k "$1" '.services.agent.environment[$k] // ""' <<<"$cfg"; }
  check "compose resolves the launchpad files (no error)" test -n "$cfg"
  check "the agent's file gives the bot token" test "$(env TELEGRAM_BOT_TOKEN)" = 1:abc
  check "...but not the owner: the host's wins" test "$(env OWNER_TELEGRAM_ID)" = 42
  check "...nor the Claude key" test "$(env CLAUDE_KEY)" = sk-ant-oat01-fleet
  check "...nor Claude's flags" test -z "$(env CLAUDE_FLAGS)"
  check "the agent gets its own volume and the fleet network, with its name as alias" bash -c 'jq -e ".volumes.data.name == \"agent-junior_data\" and (.services.agent.networks.agents.aliases | index(\"junior\"))" <<<"$0" > /dev/null' "$cfg"
else
  echo "skip - docker compose is not installed: the agent file checks did not run"
fi

# The budget: host configuration is counted on its own, like bin/ is.
n=$(cat $L/* | grep -cvE '^[[:space:]]*([#;]|$)')
check "host/launchpad stays within 100 lines ($n)" test "$n" -le 100

rm -rf "$T"
echo "$FAILS failed"; exit $((FAILS > 0))
