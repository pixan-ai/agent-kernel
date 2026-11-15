#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016  # helpers are called through check "$@"; bash -c bodies are single-quoted on purpose
# Acceptance tests for what every agent can read out of the box: voice notes and documents.
# CI runs this inside the built image as the agent's own user (uid 1001) and with no network, so nothing is downloaded at use.
# The fixtures were made for this repository: a synthetic Spanish voice (espeak-ng) and three small Office files.
set -uo pipefail
# shellcheck source=tests/lib.sh
. "$(dirname "$(readlink -f "$0")")/lib.sh"
F=$(dirname "$(readlink -f "$0")")/fixtures; T=$(mktemp -d)
says() { grep -qi "$2" <<<"$1"; }

check "runs as the agent's own user" test "$(id -u)" = 1001
out=$(whisper-ctranslate2 --model_directory /opt/models/whisper-small --compute_type int8 --language es --output_dir "$T" "$F/hola.ogg" 2>&1)
check "a voice note is transcribed, offline, with the model in the image" says "$out" "hola"
for f in doc.docx hoja.xlsx pres.pptx; do
  check "a document is read to text: $f" says "$(markitdown "$F/$f" 2>&1)" "mango"
done
check "Word is written from Markdown" bash -c 'echo "# mango" | pandoc -o "$0/out.docx" && markitdown "$0/out.docx" | grep -q mango' "$T"
check "video frames can be taken: ffmpeg is on the path" bash -c 'ffmpeg -hide_banner -version > /dev/null'
rm -rf "$T"
echo "$FAILS failed"; exit $((FAILS > 0))
