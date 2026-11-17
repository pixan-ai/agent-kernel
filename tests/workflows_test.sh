#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016  # helpers are called through check "$@"; regexes are single-quoted on purpose
# Supply-chain hygiene of the CI itself: what OpenSSF Scorecard and a reviewer look for in .github/workflows.
set -uo pipefail
# shellcheck source=tests/lib.sh
. "$(dirname "$(readlink -f "$0")")/lib.sh"
cd "$(dirname "$0")/.." || exit 1

absent() { ! grep -qE "$1" .github/workflows/*.yml; }

# Every `uses:` is a local action or a full 40-character commit SHA (a tag can be moved; a SHA cannot).
unpinned=$(grep -hnE '^[[:space:]]*(-[[:space:]]*)?uses:' .github/workflows/*.yml \
  | grep -vE 'uses:[[:space:]]*(\./|[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+@[0-9a-f]{40}([[:space:]]|$))' || true)
check "every action is pinned to a full commit SHA" test -z "$unpinned"
while IFS= read -r line; do [ -z "$line" ] || echo "     $line"; done <<<"$unpinned"

for f in .github/workflows/*.yml; do
  check "$f declares top-level permissions" grep -qE '^permissions:' "$f"
done
check "no workflow is triggered by pull_request_target" absent 'pull_request_target'
check "no workflow reads untrusted event data" absent 'github\.(head_ref|event\.(issue|pull_request|comment|review|pages)\b)'
count() { grep -h -- "$1" .github/workflows/*.yml | grep -c ''; }
check "every checkout drops its credentials" test "$(count 'uses: actions/checkout@')" = "$(count 'persist-credentials: false')"

# Only the `base` target (no Anthropic software) may leave the build machine.
pushes=$(grep -c 'push: true' .github/workflows/release.yml); based=$(grep -B1 'push: true' .github/workflows/release.yml | grep -c 'target: base')
check "every image push in the release workflow builds the base target" test "$pushes" -gt 0 -a "$pushes" = "$based"
check "the Dockerfile's default (last) target is the agent, built from base" test "$(grep -E '^FROM ' Dockerfile | tail -1 | grep -c 'FROM base AS agent$')" = 1
check "Claude Code is installed only after the base target" test -z "$(sed '/^FROM base AS agent$/,$d' Dockerfile | grep -iE 'claude\.ai/install|claude plugin')"

check "the container's PID 1 is tini, which forwards signals to the entrypoint" grep -qE '^ENTRYPOINT \["tini", "-g", "--", "/usr/local/bin/start.sh"\]$' Dockerfile

for f in .github/workflows/*.yml; do
  check "$f: every job has a time limit (audit, B9)" test "$(grep -c 'runs-on:' "$f")" = "$(grep -c 'timeout-minutes:' "$f")"
done
check "CI cancels a pull request's older run when a new push arrives (audit, B9)" bash -c 'grep -q "^concurrency:" "$0" && grep -q "cancel-in-progress: \${{ github.event_name == .pull_request. }}" "$0"' .github/workflows/ci.yml
check "CI runs ShellCheck on the policy's hook commands too (audit, B6)" grep -q "shellcheck -s sh" .github/workflows/ci.yml

# Versions the Dockerfile pins by hand: a weekly workflow compares each with upstream (audit of 2026-11-17, M10).
for v in $(sed -n '/^ARG /{:a;/\\$/{N;ba};p}' Dockerfile | grep -oE '[A-Z][A-Z0-9_]+=' | tr -d = | grep -v '_SHA256$'); do
  check "the pins workflow watches $v" grep -q "$v=" .github/workflows/pins.yml
done

# Docker Hub as a second registry (decision of 2026-11-17): same digest, signed and verified there too, credentials only from secrets.
hub() { grep -q "name=docker.io/\${{ vars.DOCKERHUB_REPOSITORY }},enable=" "$1" && grep -q 'password: \${{ secrets.DOCKERHUB_TOKEN }}' "$1" \
  && grep -q 'cosign sign --yes "docker.io/$HUB@$DIGEST"' "$1" && grep -q 'for ref in "$IMAGE" ${HUB:+"docker.io/$HUB"}' "$1"; }
check "a release also publishes to Docker Hub when it is configured, signed and verified there" hub .github/workflows/release.yml

gate=$(grep -B2 -A8 'Trivy, blocking' .github/workflows/ci.yml)
blocks() { grep -q 'image-ref: pixan-kernel-spike:base' <<<"$gate" && grep -q 'exit-code: "1"' <<<"$gate" && ! grep -q 'continue-on-error' <<<"$gate"; }
check "CI fails on a fixable CRITICAL vulnerability in the publishable image" blocks

echo "$FAILS failed"; exit $((FAILS > 0))
