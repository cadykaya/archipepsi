#!/usr/bin/env bash
# Track A -- the interface family composed into a face, as evidence.
#
#   tools/content/run_interface_face.sh [out dir]
#
# Not a gate. This renders owner-facing sheets from the committed
# interface art; the gates that REFUSE are run_font_import.sh and
# run_nine_slice.sh.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
UI="$ROOT/assets/ui"
OUT="${1:-$ROOT/docs/art/review/interface_2026-09-24}"
H="$ROOT/godot/_harness"
[ -x "$GODOT" ] || { echo "no godot at $GODOT" >&2; exit 2; }
# shellcheck source=godot_run.sh
. "$ROOT/tools/content/godot_run.sh"
mkdir -p "$OUT"
cleanup() { rm -rf "$H"; }
trap cleanup EXIT
cleanup; mkdir -p "$H"

cp "$UI"/panel_*.png "$UI/panels.json" "$UI/ui_numerals.fnt" \
   "$UI/ui_numerals.png" "$UI/ui_text.fnt" "$UI/ui_text.png" \
   "$UI"/icon_*.png "$UI/icons.json" "$H/"
cp "$ROOT/assets/art_palette.json" "$H/"
cp "$ROOT/tools/artpreview/artbench.gd" "$H/artbench.gd"
cp "$ROOT/tools/content/interface_face.gd" "$H/interface_face.gd"

log="$(mktemp)"
set +e
xvfb-run -a timeout --kill-after=15s "${GODOT_IMPORT_TIMEOUT:-600}" \
  "$GODOT" --headless --path "$ROOT/godot" --import >"$log" 2>&1
status=$?
set -e
[ "$status" -eq 0 ] || {
  echo "run_interface_face: import exited $status; log at $log" >&2; exit 1; }
rm -f "$log"

run_godot face _harness/interface_face.gd "$OUT"
