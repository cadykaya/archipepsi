#!/usr/bin/env bash
# Track A -- the open technical risk: a Glyph-authored bitmap font in
# Godot 4.5.1.
#
#   tools/content/run_font_import.sh [font dir] [out.json]
#
# The font dir defaults to assets/ui/, the committed interface family.
#
# The Glyph guide's bitmap-font proof names Godot 4.3. This project ships
# 4.5.1. Everything else in the interface family stands on the assumption
# that a `.fnt` and its page arrive with their metrics intact, so this
# runs before any of it is built.
#
# The font is staged into godot/_harness/ and deleted afterwards: the risk
# test must not leave a font in godot/content/ that nothing regenerates.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
FONT="${1:-$ROOT/assets/ui}"
OUT="${2:-}"
H="$ROOT/godot/_harness"
[ -x "$GODOT" ] || { echo "no godot at $GODOT" >&2; exit 2; }
[ -f "$FONT/ui_numerals.fnt" ] || { echo "no ui_numerals.fnt in $FONT" >&2; exit 2; }
[ -f "$FONT/ui_numerals.png" ] || { echo "no ui_numerals.png in $FONT" >&2; exit 2; }
# shellcheck source=godot_run.sh
. "$ROOT/tools/content/godot_run.sh"
cleanup() { rm -rf "$H"; }
trap cleanup EXIT
cleanup; mkdir -p "$H"

cp "$FONT/ui_numerals.fnt" "$FONT/ui_numerals.png" "$H/"
cp "$ROOT/tools/content/font_import.gd" "$H/font_import.gd"

# The sabotage font: `1` advancing 5 like every other glyph, same page,
# same art, one number changed. The harness requires that the measurement
# NOTICE. Sharing the page is deliberate -- if the sabotage differed in
# its pixels too, a pass would not say which difference was seen.
sed 's/^\(char id=49 .*\)xadvance=4\(.*\)$/\1xadvance=5\2/' \
  "$H/ui_numerals.fnt" > "$H/sabotage.fnt"
if cmp -s "$H/ui_numerals.fnt" "$H/sabotage.fnt"; then
  echo "run_font_import: the sabotage edit changed nothing -- char id=49 does
  not carry xadvance=4, so the planted failure was never planted and the
  harness's sabotage step would be grading two identical fonts" >&2
  exit 1
fi

# The editor's own BMFont importer, over the staged font.
log="$(mktemp)"
set +e
xvfb-run -a timeout --kill-after=15s "${GODOT_IMPORT_TIMEOUT:-600}" \
  "$GODOT" --headless --path "$ROOT/godot" --import >"$log" 2>&1
status=$?
set -e
if [ "$status" -ne 0 ]; then
  echo "run_font_import: the import pass exited $status; log at $log" >&2
  exit 1
fi
grep -E "ui_numerals|sabotage" "$log" | head -5 || true
rm -f "$log"
[ -f "$H/ui_numerals.fnt.import" ] || {
  echo "run_font_import: Godot wrote no .import sidecar for the .fnt, so it
  does not recognise the format at all" >&2; exit 1; }

run_godot fontimport _harness/font_import.gd ${OUT:+"$OUT"}
