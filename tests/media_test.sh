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
# Making documents (decided 2026-11-15): with Python libraries for designed files, and PDF with Typst. Not pandoc --pdf-engine=typst:
# the image's pandoc 3.1 writes a template that this Typst rejects ("font fallback list must not be empty"); its body alone compiles.
check "an Excel file is made with Python, and reads back" bash -c 'python-docs -c "import openpyxl; w=openpyxl.Workbook(); w.active[\"A1\"]=\"mango\"; w.save(\"$0/a.xlsx\")" && markitdown "$0/a.xlsx" | grep -q mango' "$T"
check "a Word file is made with Python, and reads back" bash -c 'python-docs -c "import docx; d=docx.Document(); d.add_heading(\"mango\"); d.save(\"$0/a.docx\")" && markitdown "$0/a.docx" | grep -q mango' "$T"
check "a PowerPoint file is made with Python, and reads back" bash -c 'python-docs -c "import pptx; p=pptx.Presentation(); s=p.slides.add_slide(p.slide_layouts[0]); s.shapes.title.text=\"mango\"; p.save(\"$0/a.pptx\")" && markitdown "$0/a.pptx" | grep -q mango' "$T"
check "a PDF is made from Markdown, offline, and reads back" bash -c 'printf "# Informe\n\nVentas de **mango**: 12\n" | pandoc -t typst -o "$0/a.typ" && typst compile "$0/a.typ" "$0/a.pdf" && pdftotext "$0/a.pdf" - | grep -q mango' "$T"
check "video frames can be taken: ffmpeg is on the path" bash -c 'ffmpeg -hide_banner -version > /dev/null'
rm -rf "$T"
echo "$FAILS failed"; exit $((FAILS > 0))
