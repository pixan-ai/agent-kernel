#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016  # helpers are called through check "$@"; regexes and jq programs are single-quoted on purpose
# Documentation-vs-code drift tests: what the docs say must be what the scripts do. Run from a checkout (no image needed).
set -uo pipefail
# shellcheck source=tests/lib.sh
. "$(dirname "$(readlink -f "$0")")/lib.sh"
cd "$(dirname "$0")/.." || exit 1

listed() { grep -qxF -- "$1" <<<"$2"; }
exists() { [ -e "$1" ]; }

# Configuration the entrypoint takes from the environment = variables it reads but never assigns itself.
refs=$(grep -oE '\$\{?[A-Z][A-Z0-9_]*' bin/start.sh | tr -d '${' | sort -u)
# Assigned by the script itself (also on an indented line), or a shell built-in such as SECONDS or EUID.
assigned=$({ grep -oE '(^[[:space:]]*|;[[:space:]]*|\()[A-Z][A-Z0-9_]*=' bin/start.sh | sed -E 's/^[;(]//; s/^[[:space:]]+//; s/=$//'; echo SECONDS; echo EUID; } | sort -u)
inputs=$(comm -23 <(printf '%s\n' "$refs") <(printf '%s\n' "$assigned"))
# Consumed by Claude Code or the OS, not by start.sh, but documented for the user.
known=$(printf '%s\n' "$inputs" ANTHROPIC_MODEL TZ; grep -oE '^ARG [A-Z][A-Z0-9_]*' Dockerfile | cut -d" " -f2)  # build arguments: a host variable of the same name is used at build
documented=$(sed -n '/^| Variable/,/^$/p' README.md | grep -oE '^\| `[A-Z][A-Z0-9_]*`' | tr -d '|` ')
example=$(grep -oE '^#? ?[A-Z][A-Z0-9_]*=' .env.example | tr -d '# =')

check "start.sh reads at least the Telegram and Claude credentials" listed TELEGRAM_BOT_TOKEN "$inputs"
for v in $inputs; do check "README documents $v, which start.sh reads" listed "$v" "$documented"; done
for v in $documented; do check "$v, documented in README, is something the code uses" listed "$v" "$known"; done
for v in $example; do check ".env.example's $v is documented in README" listed "$v" "$documented"; done

# The repository layout in the README: every path exists, and every top-level directory is listed.
layout=$(sed -n '/^## Repository layout/,/^## /p' README.md | sed -n '/^```$/,/^```$/p' | grep -v '^```$' | awk '{ print $1 }')
for p in $layout; do check "README layout: $p exists" exists "$p"; done
for d in $(git ls-files | cut -d/ -f1 | sort -u); do
  [ -d "$d" ] && check "README layout lists the directory $d/" grep -q "^$d/" <<<"$layout"
done

# Relative links in the documents resolve.
broken=""
for f in README.md CONTRIBUTING.md SECURITY.md docs/*.md; do
  while IFS= read -r l; do
    t=${l#](}; t=${t%)}; t=${t%%#*}
    case $t in http*|mailto:*|"") continue ;; esac
    [ -e "$(dirname "$f")/$t" ] || broken="$broken $f->$t"
  done < <(grep -oE '\]\([^)]+\)' "$f")
done
# The guide is where an owner looks: everything the scripts let the host set must be explained there.
for v in $(grep -ohE '\$\{[A-Z][A-Z0-9_]+:[-?+]' bin/* compose.yml | tr -d '${:?+-' | sort -u | grep -vE '^SSH_(CONNECTION|ORIGINAL_COMMAND)$') PORT BACKUP_AGE_RECIPIENT; do
  check "the guide explains $v" grep -q "\`$v\`" docs/GETTING-STARTED.md
done
check "relative links in the documents resolve" test -z "$broken"
[ -z "$broken" ] || echo "     broken:$broken"

check "every external Dockerfile FROM is pinned by digest (Renovate keeps it current)" test -z "$(grep -E '^FROM ' Dockerfile | grep -vE '@sha256:[0-9a-f]{64}|^FROM base AS ')"
check "agent instructions exist and match the policy: connectors disabled" bash -c 'jq -e .disableClaudeAiConnectors policy/managed-settings.json >/dev/null && grep -qi "connectors.*disabled" policy/CLAUDE.md'
check "agent instructions tell it not to touch credentials" grep -qi "never read, print, send" policy/CLAUDE.md

# The project is open source and stands on its own: no business is advertised in it (decided 2026-11-17).
check "no document or script mentions consulting" bash -c '! grep -rniI --exclude-dir=.git --exclude=docs_test.sh "consult" .'
# Which Claude credential: Anthropic's terms keep subscriptions for ordinary, individual use (audit of 2026-11-17, A5).
check "the guide recommends an API key for an agent that serves groups or clients" grep -q "API key for an agent that serves groups or clients" docs/GETTING-STARTED.md
check "...and README links Anthropic's legal page" grep -q "code.claude.com/docs/en/legal-and-compliance" README.md
# Third-party licences go into the image, and name the versions the Dockerfile pins (audit of 2026-11-17, A4).
check "the image carries LICENSE and THIRD-PARTY.md" bash -c 'grep -qx "COPY LICENSE THIRD-PARTY.md /usr/share/doc/agent-kernel/" Dockerfile && grep -qx "!THIRD-PARTY.md" .dockerignore'
check "THIRD-PARTY.md names no version of what moves on its own (Renovate, Debian), so it never goes stale (v1 audit, B4)" bash -c '! grep -qE "(supercronic|uv|Typst|Bun|pandoc.|poppler-utils.) [0-9]|Debian 13\.[0-9]" THIRD-PARTY.md'
check "no GPL FFmpeg in the image: voice and video are in the optional stack, which the agent is pointed to (decided 2026-11-18)" bash -c '! grep -v "^#" Dockerfile | grep -qiE "whisper|imageio|ffmpeg" && grep -q "/etc/claude-code/stack.md" policy/CLAUDE.md && grep -q "whisper-ctranslate2==" policy/stack.md && grep -q "imageio-ffmpeg==" policy/stack.md'
# The Railway template's settings are kept in the repository: the same variables as the guide, the volume, the uid.
tmpl=$(sed -n '/^## The one-click template/,$p' docs/DEPLOY-RAILWAY.md)
for v in TELEGRAM_BOT_TOKEN OWNER_TELEGRAM_ID CLAUDE_KEY TZ; do
  check "the Railway template sets $v, like the guide" bash -c 'grep -q "| \`$0\` |" <<<"$1" && grep -q "| \`$0\` |" docs/GETTING-STARTED.md' "$v" "$tmpl"
done
# A template cannot turn Serverless on (four ways tried, docs/SLEEP.md), so the one click left to the deployer must be said where they read.
check "the template's page tells the deployer to turn Serverless on" grep -q "Enable Serverless" docs/railway-template-overview.md
check "...the guide gives it as a numbered step of the one-click path" grep -qE '^[0-9]+\. .*Enable Serverless' docs/GETTING-STARTED.md
check "...and so does the description of IDLE_SLEEP_MINUTES in the template" bash -c 'grep "^| \`IDLE_SLEEP_MINUTES\`" <<<"$0" | grep -q "Enable Serverless"' "$tmpl"
check "...a volume at /data and Restart Policy Always" bash -c 'grep -q "mounted at \`/data\`" <<<"$0" && grep -q "Restart Policy \*\*Always\*\*" <<<"$0"' "$tmpl"
check "Claude Code stays at its pinned version: neither the auto-updater nor \`claude update\` (audit of 2026-11-18, B9)" bash -c 'grep -q "DISABLE_AUTOUPDATER=1" Dockerfile && grep -q "DISABLE_UPDATES=1" Dockerfile'
# denyInsteadOfPrompting (policy) needs Claude Code 2.1.319 or later; an older one ignores it (audit of 2026-11-18 v1, A1).
floor=$(grep -oE "^ \&\& \{ \[.*\}; \}$" Dockerfile)
check "the build's Claude Code floor refuses 2.1.311 and takes 2.1.319 and 2.1.320" bash -c 'v=2.1.311; ! (eval "$0") 2> /dev/null && v=2.1.319 && (eval "$0") && v=2.1.320 && (eval "$0")' "${floor# && }"
check "...and the default version is not below the floor" bash -c '[ -n "$0" ] && v=$(grep -oE "^ARG CLAUDE_CODE_VERSION=\S+" Dockerfile | cut -d= -f2) && (eval "$0")' "${floor# && }"
check "Docker Compose passes CLAUDE_CODE_VERSION to the build, as Railway does (v1 audit, B1)" grep -qF "args: [CLAUDE_CODE_VERSION]" compose.yml
# The image starts as root, so an exec without --user is root, and the agent can plant programs in its own folders (audit of 2026-11-21, A3).
check "every docker exec in the docs runs as the agent, never root (A3; any spelling of it, L8)" bash -c '! grep -rhoE "docker(-compose| compose| container)? exec [^|]*" docs README.md CONTRIBUTING.md | grep -v -- "--user 1001"'
# railway ssh has no --user: it opens a shell as the image's user, root. The docs say so, and how to drop to the agent (L6).
check "DEPLOY-RAILWAY.md warns that railway ssh opens a root shell (L6)" grep -q "railway ssh.*root" docs/DEPLOY-RAILWAY.md
check "...and every mention of railway ssh says how to drop to the agent's user, or links to where it does (L6, L8)" bash -c '! grep -rh "railway ssh" docs README.md CONTRIBUTING.md | grep -v -e "setpriv --reuid=1001" -e "(DEPLOY-RAILWAY.md)"'
lines=$(cat bin/*.sh | grep -cvE '^[[:space:]]*(#|$)')
# A prompt a newcomer gives to their own AI assistant to be walked through the setup (2026-11-24). It must say what the code does now.
A=docs/SETUP-WITH-AI.md
# A release moves the version in three places; the CHANGELOG leads and the other two must follow (docs/RELEASING.md).
V=$(grep -m1 -oE '^## \[[0-9]+\.[0-9]+' CHANGELOG.md | tr -d '#[ ')
for f in README.md docs/THREAT-MODEL.md; do check "$f says Status: $V, the latest version in the CHANGELOG" grep -q "Status: $V\." "$f"; done
check "README shows the OpenSSF Scorecard badge, linked to the full report" grep -q "api.scorecard.dev/projects/github.com/pixan-ai/agent-kernel/badge.*scorecard.dev/viewer" README.md
# A key typed on a command line stays in the shell history: the docs ask for it with read -rs instead.
check "no command in the docs carries a Claude key on its command line" bash -c '! grep -rnE "(OAUTH_TOKEN|API_KEY|CLAUDE_KEY)=.?sk-ant" README.md docs --include=*.md --exclude-dir=history'
check "the guide checks the key before deploying, asking for it without showing it" grep -q "read -rs" docs/GETTING-STARTED.md
# On one Linux server, a network joined by hand is lost at every `docker compose up -d`, and with it the name a fellow agent looks up (lab, 2026-11-24).
check "PEERS.md declares the shared network in a compose override, so an update keeps it" bash -c 'grep -q "compose.override.yml" docs/PEERS.md && grep -q "external: true" docs/PEERS.md && grep -q "aliases:" docs/PEERS.md'
check "compose.override.yml is git-ignored, so git pull never touches a server's own override" grep -qx "compose.override.yml" .gitignore
check "CONTRIBUTING warns that the image tests delete /data, so they never run in a live agent" grep -q "never .*live agent" CONTRIBUTING.md
# What code does not prevent, a person must look for: the weekly review is required, says who, what and where, and is in the threat model (decided 2026-11-25).
check "the guide makes a weekly review by the owner or a super-user required" grep -q "^## 8. Review your agents every week (required)" docs/GETTING-STARTED.md
check "...and says where to look: notices, settings, installs, conversations and logs" bash -c 'f=docs/GETTING-STARTED.md; for w in "Setting changed" "What have you installed" "SSH_ORIGINAL_COMMAND=transcript" "docker compose logs" "Deploy Logs"; do sed -n "/^## 8\. Review/,/^## /p" "$f" | grep -qF "$w" || exit 1; done'
check "the threat model lists the weekly review as a human control that finds problems late and prevents none" grep -q "weekly review.*finds.*late" docs/THREAT-MODEL.md
# The code manual covers every file the agent runs, and its line table matches the code.
for f in bin/* policy/*; do check "CODE.md explains $f" grep -q "^### .*\`$f\`" docs/CODE.md; done
for f in bin/*.sh; do n=$(grep -cvE '^[[:space:]]*(#|$)' "$f"); check "CODE.md gives $f its $n lines" grep -q "^| \`$f\` | $n |" docs/CODE.md; done
check "README links the code manual" grep -q "docs/CODE.md" README.md
# The product manual explains every feature and points to where each is documented; the canvas says the project sells nothing.
for d in MEMORY CRON GROUPS PEERS SLEEP BACKUP SETTINGS SETUP-WITH-AI THREAT-MODEL; do check "PRODUCT.md explains the feature documented in $d.md" grep -q "($d.md" docs/PRODUCT.md; done
check "the business model canvas states there are no revenue streams" bash -c 'sed -n "/^## Revenue streams/,/^## /p" docs/BUSINESS-MODEL-CANVAS.md | grep -q "None"'
check "README links the product manual" grep -q "docs/PRODUCT.md" README.md
for f in README.md docs/GETTING-STARTED.md docs/DEPLOY-LINUX.md; do check "$f links to the setup prompt" grep -q "SETUP-WITH-AI.md" "$f"; done
# A new variable in .env (an agent's own tool, seen live 2026-11-24) never reaches a container that is only restarted; and -v deletes the volume.
for f in docs/DEPLOY-LINUX.md docs/SETUP-WITH-AI.md; do
  check "$f: a change to .env is applied with docker compose up -d, not restart" grep -qE "docker compose up -d.*restart. does not read .env" "$f"
  check "$f: warns that docker compose down -v deletes the agent's memory" grep -q "down -v" "$f"
done
check "DEPLOY-LINUX.md says how to read the agent's conversation on the server" grep -q "SSH_ORIGINAL_COMMAND=transcript" docs/DEPLOY-LINUX.md
for w in CLAUDE_KEY OWNER_TELEGRAM_ID TELEGRAM_BOT_TOKEN sk-ant-oat01- sk-ant-api03- "Enable Serverless" "docker compose up -d --build"; do
  check "the setup prompt names $w" grep -qF -- "$w" "$A"
done
check "...and forbids asking for a secret in the chat" grep -q "Never ask the user to paste" "$A"
# Every start-up error that names a credential, as start.sh prints it today: the prompt must quote it, or it diagnoses an old agent.
grep -oE 'echo "(missing |Telegram rejected )?(CLAUDE_KEY|OWNER_TELEGRAM_ID|TELEGRAM_BOT_TOKEN)[^:"(]*' bin/start.sh | sed 's/^echo "//; s/ *$//' | sort -u > /tmp/start-errors
check "start.sh has credential errors to quote (the extraction works)" test "$(wc -l < /tmp/start-errors)" -ge 4
while IFS= read -r e; do check "the setup prompt quotes the start-up error \"$e\"" grep -qF -- "$e" "$A"; done < /tmp/start-errors
# One place for "something is wrong": the troubleshooting guide quotes every start-up error, and says how to tell the causes of a silent agent apart.
T=docs/TROUBLESHOOTING.md
while IFS= read -r e; do check "TROUBLESHOOTING.md quotes the start-up error \"$e\"" grep -qF -- "$e" "$T"; done < /tmp/start-errors
check "TROUBLESHOOTING.md says how to tell the causes of a silent agent apart, in order" grep -q "^## The agent does not answer" "$T"
for f in README.md docs/GETTING-STARTED.md docs/DEPLOY-LINUX.md docs/DEPLOY-RAILWAY.md; do check "$f links to the troubleshooting guide" grep -q "TROUBLESHOOTING.md" "$f"; done
# Running agents on Telegram: the user guide has its own section (a supergroup from the start, privacy, names, the owner's account).
check "the guide has a section on running the agent in Telegram" bash -c 'sed -n "/^## 9\. Running it in Telegram/,/^## /p" docs/GETTING-STARTED.md | grep -q "supergroup" && sed -n "/^## 9\. Running it in Telegram/,/^## /p" docs/GETTING-STARTED.md | grep -q "two-step verification"'
check "the guide says how long until Railway shows Sleeping" grep -q "about 13 minutes" docs/GETTING-STARTED.md
# 247 is a budget, not a target: a 24/7 agent within 247 lines. A change that needs a line finds one to give back (CONTRIBUTING.md).
check "README's \"within 247 lines of Bash\" holds: $lines lines of code in bin/*.sh" test "$lines" -le 247
echo "$FAILS failed"; exit $((FAILS > 0))
