#!/usr/bin/env bash
# Track A -- the other half of the open technical risk: a Glyph-authored
# nine-slice in Godot 4.5.1.
#
#   tools/content/run_nine_slice.sh [panel dir] [out.json]
#
# The panel dir defaults to assets/ui/. The panels are staged into
# godot/_harness/ and deleted afterwards, for the same reason the font
# is: a risk test must not leave art in godot/content/ that nothing
# regenerates.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
PANELS="${1:-$ROOT/assets/ui}"
OUT="${2:-}"
H="$ROOT/godot/_harness"
[ -x "$GODOT" ] || { echo "no godot at $GODOT" >&2; exit 2; }
# shellcheck source=godot_run.sh
. "$ROOT/tools/content/godot_run.sh"
cleanup() { rm -rf "$H"; }
trap cleanup EXIT
cleanup; mkdir -p "$H"

for name in panel well selected keycap; do
  [ -f "$PANELS/panel_$name.png" ] || {
    echo "no panel_$name.png in $PANELS" >&2; exit 2; }
  cp "$PANELS/panel_$name.png" "$H/"
done
[ -f "$PANELS/panels.json" ] || {
  echo "no panels.json in $PANELS -- the harness reads the declared
  insets and ring colours from it rather than restating them" >&2; exit 2; }
cp "$PANELS/panels.json" "$H/panels.json"
cp "$ROOT/tools/content/nine_slice.gd" "$H/nine_slice.gd"

log="$(mktemp)"
set +e
xvfb-run -a timeout --kill-after=15s "${GODOT_IMPORT_TIMEOUT:-600}" \
  "$GODOT" --headless --path "$ROOT/godot" --import >"$log" 2>&1
status=$?
set -e
if [ "$status" -ne 0 ]; then
  echo "run_nine_slice: the import pass exited $status; log at $log" >&2
  exit 1
fi
rm -f "$log"

run_godot nineslice _harness/nine_slice.gd ${OUT:+"$OUT"}
