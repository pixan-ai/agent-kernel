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
pushes=$(grep -cE 'push: true|push=true' .github/workflows/release.yml); based=$(grep -B1 -E 'push: true|push=true' .github/workflows/release.yml | grep -c 'target: base')
check "every image push in the release workflow builds the base target" test "$pushes" -gt 0 -a "$pushes" = "$based"
check "the Dockerfile's default (last) target is the agent, built from base" test "$(grep -E '^FROM ' Dockerfile | tail -1 | grep -c 'FROM base AS agent$')" = 1
check "the agent image starts as root, so a host needs no setting to fix the volume (start.sh drops to uid 1001; 2026-11-20)" \
  bash -c 'test "$(sed -n "/^FROM base AS agent$/,\$p" Dockerfile | grep -E "^USER " | tail -1)" = "USER 0"'
check "root runs nothing found through PATH at start: tini and start.sh by absolute path, start.sh on /bin/bash (audit of 2026-11-21, A2)" \
  bash -c 'grep -qx "ENTRYPOINT \[\"/usr/bin/tini\", \"-g\", \"--\", \"/usr/local/bin/start.sh\"\]" Dockerfile && test "$(head -1 bin/start.sh)" = "#!/bin/bash"'
check "Claude Code is installed only after the base target" test -z "$(sed '/^FROM base AS agent$/,$d' Dockerfile | grep -iE 'claude\.ai/install|claude plugin')"

check "the container's PID 1 is tini, which forwards signals to the entrypoint" grep -qE '^ENTRYPOINT \["/usr/bin/tini", "-g", "--", "/usr/local/bin/start.sh"\]$' Dockerfile

for f in .github/workflows/*.yml; do
  check "$f: every job has a time limit (audit, B9)" test "$(grep -c 'runs-on:' "$f")" = "$(grep -c 'timeout-minutes:' "$f")"
done
check "CI cancels a pull request's older run when a new push arrives (audit, B9)" bash -c 'grep -q "^concurrency:" "$0" && grep -q "cancel-in-progress: \${{ github.event_name == .pull_request. }}" "$0"' .github/workflows/ci.yml
check "CI runs ShellCheck on the policy's hook commands too (audit, B6)" grep -q "shellcheck -s sh" .github/workflows/ci.yml

# Everything updates by pull request, merged only when CI is green (decided 2026-11-18): Renovate, with a line for each version it moves.
check "Renovate merges its own pull requests only once their checks pass, and Claude Code follows its stable channel" \
  bash -c 'jq -e ".automerge == true and .platformAutomerge == false and .prCreation == \"immediate\" and (.packageRules[] | select(.matchDepNames == [\"@anthropic-ai/claude-code\"]) | .followTag) == \"stable\"" renovate.json > /dev/null'
for v in $(grep -oE '^ARG [A-Z][A-Z0-9_]*=' Dockerfile | cut -c5- | tr -d = | grep -v '_SHA256$'); do
  check "Renovate updates $v: a '# renovate:' line comes right before it" bash -c 'grep -B1 "^ARG $0=" Dockerfile | head -1 | grep -q "^# renovate: datasource="' "$v"
done
check "...and only Renovate: no second bot, no weekly issue" test ! -e .github/dependabot.yml -a ! -e .github/workflows/pins.yml

# Docker Hub as a second registry (decision of 2026-11-17): same digest, signed and verified there too, credentials only from secrets.
hub() { grep -q "name=docker.io/\${{ vars.DOCKERHUB_REPOSITORY }},enable=" "$1" && grep -q 'password: \${{ secrets.DOCKERHUB_TOKEN }}' "$1" \
  && grep -q 'cosign sign --yes "docker.io/$HUB@$DIGEST"' "$1" && grep -q 'for ref in "$IMAGE" ${HUB:+"docker.io/$HUB"}' "$1"; }
check "a release also publishes to Docker Hub when it is configured, signed and verified there" hub .github/workflows/release.yml

# What is signed is what was checked: the published digest itself (audit of 2026-11-18, M4), and the test registry is pinned too (B10).
pub=$(sed -n '/^  publish:/,$p' .github/workflows/release.yml)
checked_first() { local s n c; s=$(grep -n 'Sign (keyless)' <<<"$pub" | cut -d: -f1); n=$(grep -n 'command -v claude' <<<"$pub" | cut -d: -f1); c=$(grep -n 'image-ref: ${{ env.IMAGE }}@${{ steps.build.outputs.digest }}' <<<"$pub" | cut -d: -f1)
  [ -n "$s" ] && [ -n "$n" ] && [ -n "$c" ] && [ "$n" -lt "$s" ] && [ "$c" -lt "$s" ]; }
check "the publish job checks the pushed digest (no Claude Code, no fixable CRITICAL) before signing it" checked_first
# No version tag before the checks and the signature (audit of 2026-11-18 v1, M1): pushed by digest, tagged at the very end, both jobs.
acc=$(sed -n '/^  acceptance:/,/^  publish:/p' .github/workflows/release.yml)
tagged_last() { local v t; v=$(grep -n "$2" <<<"$1" | tail -1 | cut -d: -f1); t=$(grep -n 'imagetools create -t' <<<"$1" | head -1 | cut -d: -f1)
  grep -q 'push-by-digest=true' <<<"$1" && ! grep -qE '^ +tags: [^|]' <<<"$1" && [ -n "$v" ] && [ -n "$t" ] && [ "$t" -gt "$v" ]; }
check "a release pushes by digest and adds its version tags only after it is checked, signed and verified" tagged_last "$pub" 'gh attestation verify'
check "...and the release path rehearses that on every pull request" tagged_last "$acc" 'verification with the wrong key must fail'
check "the throwaway registry of the release path is pinned by digest" grep -qE 'image: registry:3@sha256:[0-9a-f]{64}' .github/workflows/release.yml

gate=$(grep -B2 -A8 'Trivy, blocking' .github/workflows/ci.yml)
blocks() { grep -q 'image-ref: agent-kernel:base' <<<"$gate" && grep -q 'exit-code: "1"' <<<"$gate" && ! grep -q 'continue-on-error' <<<"$gate"; }
check "CI fails on a fixable CRITICAL vulnerability in the publishable image" blocks

echo "$FAILS failed"; exit $((FAILS > 0))
