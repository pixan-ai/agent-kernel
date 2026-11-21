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
for v in TELEGRAM_BOT_TOKEN OWNER_TELEGRAM_ID CLAUDE_CODE_OAUTH_TOKEN TZ; do
  check "the Railway template sets $v, like the guide" bash -c 'grep -q "| \`$0\` |" <<<"$1" && grep -q "| \`$0\` |" docs/GETTING-STARTED.md' "$v" "$tmpl"
done
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
check "README's \"less than 300 lines of Bash\" holds: $lines lines of code in bin/*.sh" test "$lines" -lt 300
echo "$FAILS failed"; exit $((FAILS > 0))
