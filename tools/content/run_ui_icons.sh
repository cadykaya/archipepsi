#!/usr/bin/env bash
# Track A -- the interface symbols and page arrows in Godot 4.5.1.
#
#   tools/content/run_ui_icons.sh [icon dir] [out.json]
#
# The icon dir defaults to assets/ui/. Everything `icons.json` names is
# staged into godot/_harness/ with the contract and the palette, imported,
# checked, and deleted afterwards -- a risk test must not leave art in
# godot/content/ that nothing regenerates.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
ICONS="${1:-$ROOT/assets/ui}"
OUT="${2:-}"
H="$ROOT/godot/_harness"
[ -x "$GODOT" ] || { echo "no godot at $GODOT" >&2; exit 2; }
# shellcheck source=godot_run.sh
. "$ROOT/tools/content/godot_run.sh"
cleanup() { rm -rf "$H"; }
trap cleanup EXIT
cleanup; mkdir -p "$H"

[ -f "$ICONS/icons.json" ] || {
  echo "no icons.json in $ICONS -- the harness reads the symbol list from
  the contract rather than restating it" >&2; exit 2; }
cp "$ICONS/icons.json" "$H/icons.json"
cp "$ROOT/assets/art_palette.json" "$H/art_palette.json"
# The text face's page: the gate reads "chrome ink" off it rather than
# trusting the contract's copy of the colour.
cp "$ICONS/ui_text.png" "$H/ui_text.png"
python3 - "$ICONS/icons.json" <<'PY' | while read -r f; do
import json, sys
for key, entry in json.load(open(sys.argv[1])).items():
    if not key.startswith("_"):
        print(entry["file"])
PY
  [ -f "$ICONS/$f" ] || { echo "icons.json names $f; it is not in $ICONS" >&2; exit 2; }
  cp "$ICONS/$f" "$H/"
done
cp "$ROOT/tools/content/ui_icons.gd" "$H/ui_icons.gd"

log="$(mktemp)"
set +e
xvfb-run -a timeout --kill-after=15s "${GODOT_IMPORT_TIMEOUT:-600}" \
  "$GODOT" --headless --path "$ROOT/godot" --import >"$log" 2>&1
status=$?
set -e
if [ "$status" -ne 0 ]; then
  echo "run_ui_icons: the import pass exited $status; log at $log" >&2
  exit 1
fi
rm -f "$log"

run_godot icons _harness/ui_icons.gd ${OUT:+"$OUT"}
