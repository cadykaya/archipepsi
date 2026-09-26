#!/usr/bin/env bash
# Track A2 -- capture the spatial-interaction studies.
#
#   tools/menu_studies/run_menu_studies.sh [review dir] [study ...]
#
# Each study runs twice through the same timeline -- MOTION and REDUCED
# MOTION -- in godot/_harness, one Godot at a time, capturing every frame
# at 1920 x 1080 into a scratch folder. `assemble_captures.py` then cuts
# the review material from those frames: an MP4 per run, a sheet of the
# settled steps, and full-size stills at gameplay size.
#
# Studies default to: leaf lens thread. `probe` is the kit check.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
OUT="${1:-$ROOT/docs/art/review/menu_studies_2026-09-26}"
shift || true
STUDIES="${*:-leaf lens thread}"
H="$ROOT/godot/_harness"
UI="$ROOT/assets/ui"
MS="$ROOT/tools/menu_studies"
FRAMES="${MENU_STUDY_FRAMES:-$(mktemp -d)}"
[ -x "$GODOT" ] || { echo "no godot at $GODOT" >&2; exit 2; }
# shellcheck source=../content/godot_run.sh
. "$ROOT/tools/content/godot_run.sh"
cleanup() { rm -rf "$H"; }
trap cleanup EXIT
cleanup; mkdir -p "$H" "$OUT"

cp "$UI/ui_text.fnt" "$UI/ui_text.png" "$UI/ui_numerals.fnt" \
   "$UI/ui_numerals.png" "$UI/panel_keycap.png" "$UI"/icon_*.png "$H/"
cp "$MS"/study_*.gd "$MS/menu_studies.gd" "$H/"
cp "$MS/sample/content.json" "$MS/sample/layout.json" \
   "$MS/sample/SOURCE.json" "$H/"

log="$(mktemp)"
set +e
xvfb-run -a timeout --kill-after=15s "${GODOT_IMPORT_TIMEOUT:-600}" \
  "$GODOT" --headless --path "$ROOT/godot" --import >"$log" 2>&1
status=$?
set -e
[ "$status" -eq 0 ] || {
  echo "run_menu_studies: import exited $status; log at $log" >&2; exit 1; }

for study in $STUDIES; do
  for mode in motion reduced; do
    rm -rf "$FRAMES/$study/$mode"
    GODOT_RUN_TIMEOUT="${GODOT_RUN_TIMEOUT:-900}" run_godot studies \
      _harness/menu_studies.gd "$FRAMES/$study/$mode" "$study" "$mode"
  done
done
python3 "$MS/assemble_captures.py" "$FRAMES" "$OUT" $STUDIES
echo "run_menu_studies: frames in $FRAMES"
