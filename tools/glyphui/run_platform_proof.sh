#!/usr/bin/env bash
# The epsilon proof: "PLATFORM ε" through Godot's own importer, drawn in
# ui_text alone.
#
#   tools/glyphui/run_platform_proof.sh <out-dir>
#
# The script:
#   - stages the committed face (assets/ui/ui_text.fnt and its page) and
#     the epsilon's authored rows, read from author_text.py, in
#     godot/_harness. It CREATES that folder and then removes it; if the
#     folder already exists it is somebody else's, and the script stops
#     without touching it;
#   - runs the editor's import pass, so the font is the imported
#     resource a project loads;
#   - renders the line with every fallback off, and checks the drawn
#     epsilon against the authored rows.
# Writes only into <out-dir>.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
OUT="${1:?usage: run_platform_proof.sh <out-dir>}"
H="$ROOT/godot/_harness"
[ -x "$GODOT" ] || { echo "no godot at $GODOT" >&2; exit 2; }
# shellcheck source=../content/godot_run.sh
. "$ROOT/tools/content/godot_run.sh"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
if ! mkdir "$H" 2>/dev/null; then
  echo "run_platform_proof: $H already exists and is not this run's;" \
       "nothing was touched" >&2
  exit 2
fi
cleanup() { rm -rf "$H"; }
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
cp "$ROOT/assets/ui/ui_text.fnt" "$ROOT/assets/ui/ui_text.png" "$H/"
cp "$ROOT/tools/glyphui/platform_proof.gd" "$H/platform_proof.gd"
(cd "$ROOT/tools/glyphui" && python3 -c '
import json, fontkit
from author_text import GLYPHS, BASELINE
rows = GLYPHS["ε"]
print(json.dumps({"rows": rows, "baseline": BASELINE,
                  "advance": fontkit.advance_of(rows)}))') > "$H/epsilon.json"

log="$(mktemp)"
set +e
xvfb-run -a timeout --kill-after=15s "${GODOT_IMPORT_TIMEOUT:-600}" \
  "$GODOT" --headless --path "$ROOT/godot" --import >"$log" 2>&1
status=$?
set -e
[ "$status" -eq 0 ] || {
  echo "run_platform_proof: the import pass exited $status; log at $log" >&2
  exit 1; }
rm -f "$log"
[ -f "$H/ui_text.fnt.import" ] || {
  echo "run_platform_proof: no .import sidecar for the face" >&2; exit 1; }
run_godot proof _harness/platform_proof.gd "$OUT"
