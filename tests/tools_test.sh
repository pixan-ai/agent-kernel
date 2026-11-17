#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016  # helpers are called through check "$@"; regexes and jq programs are single-quoted on purpose
# Acceptance tests for the diagnostic tool bin/screen.sh. It reads fixed paths under /data
# and the installed managed policy, so run as root inside the built image (or in a private mount namespace).
set -uo pipefail
# shellcheck source=tests/lib.sh
. "$(dirname "$(readlink -f "$0")")/lib.sh"
cd / || exit 1  # the tests empty /data, which can be the working directory of the container
SCREEN=${SCREEN:-/usr/local/bin/screen.sh}

has() { grep -qF -- "$2" <<<"$1"; }
reset() { mkdir -p /data; find /data -mindepth 1 -delete; }

check "the managed policy is installed" test -r /etc/claude-code/managed-settings.json

# --- screen.sh: the readable view of the raw terminal log
reset
printf '\033[1;1HHello \033[31mred\033[0m\r\n\033[2;1HWorld\033]0;title\007\033[3;1H   \033[4;1Hlast' > /data/tui.log
check "screen: cursor moves split lines; colors, titles, CRs and blank lines are dropped" \
  test "$("$SCREEN")" = $'Hello red\nWorld\nlast'

printf 'thought\033[9Gfor\033[13G1s)\033[2;1H5h\033[1C9%%' > /data/tui.log
check "screen: a move along the line is a space, not a new line (seen live: one word per line)" test "$("$SCREEN")" = $'thought for 1s)\n5h 9%'

seq 1 40 | sed 's/^/line /' > /data/tui.log
check "screen: shows the last 30 lines by default" test "$("$SCREEN" | wc -l)" = 30
check "screen: the first of them is line 11" test "$("$SCREEN" | head -1)" = "line 11"
check "screen: an argument sets how many lines" \
  test "$("$SCREEN" 3)" = $'line 38\nline 39\nline 40'

printf '%0200d\n' 0 | tr 0 x > /data/tui.log
check "screen: lines are cut at 160 columns" test "$("$SCREEN" | awk '{ print length }')" = 160

reset
check "screen: no log -> prints nothing" test -z "$("$SCREEN" 2>/dev/null)"

reset
echo "$FAILS failed"; exit $((FAILS > 0))
