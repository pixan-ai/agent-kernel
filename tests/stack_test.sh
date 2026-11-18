#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016  # helpers are called through check "$@"; bash -c bodies are single-quoted on purpose
# Acceptance tests for the optional stack (policy/stack.md): every `sh` block runs as written, as the agent's own user, and then
# does what it promises. Needs the network (the recipes download from PyPI and Hugging Face). CI runs this inside the built image.
set -uo pipefail
# shellcheck source=tests/lib.sh
. "$(dirname "$(readlink -f "$0")")/lib.sh"
F=$(dirname "$(readlink -f "$0")")/fixtures; T=$(mktemp -d); STACK=${STACK:-/etc/claude-code/stack.md}
check "runs as the agent's own user" test "$(id -u)" = 1001
uv venv -q --python /usr/bin/python3 /data/tools/venv  # what the start makes (installs.sh replay)
check "every recipe in stack.md runs as written" bash -ec "$(awk '/^```sh$/{f=1; next} /^```$/{f=0} f' "$STACK")"
out=$(whisper-ctranslate2 --model_directory /data/tools/models/whisper-small --compute_type int8 --language es --output_dir "$T" "$F/hola.ogg" 2>&1)
check "...then a voice note is transcribed, as its use line says" grep -qi hola <<<"$out"
check "...and ffmpeg is on the path and makes a real frame" bash -c 'ffmpeg -hide_banner -loglevel error -f lavfi -i testsrc=size=64x48 -frames:v 1 "$0/frame.png" && test -s "$0/frame.png"' "$T"
rm -rf "$T"
echo "$FAILS failed"; exit $((FAILS > 0))
