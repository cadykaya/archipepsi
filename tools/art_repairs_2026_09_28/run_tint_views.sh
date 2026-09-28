#!/usr/bin/env bash
# Repair 2026-09-28: the skiff and lightened-panel before/after frames.
#
#   tools/art_repairs_2026_09_28/run_tint_views.sh <out-dir> [old-ref]
#
# Extracts the reviewed models from <old-ref> (default a1584c8) into a
# temporary folder, writes the shot list with tint_shots.py, stages the
# harness in a godot/_harness folder removed on exit, and renders one frame
# per shot for the old and the repaired file. Writes only into <out-dir>.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
OUT="${1:?usage: run_tint_views.sh <out-dir> [old-ref]}"
REF="${2:-a1584c8}"
H="$ROOT/godot/_harness"
OLD="$(mktemp -d)"
[ -x "$GODOT" ] || { echo "no godot at $GODOT" >&2; exit 2; }
# shellcheck source=../content/godot_run.sh
. "$ROOT/tools/content/godot_run.sh"
mkdir -p "$OUT"
cleanup() { rm -rf "$H" "$OLD"; }
trap cleanup EXIT
rm -rf "$H"; mkdir -p "$H"
for f in batch045/setpieces/sp_skiff_deck.glb \
         batch043/physics/phys_generic.glb batch043/physics/phys_ballast.glb \
         batch043/physics/phys_mechanical_part.glb \
         batch043/physics/phys_movable_cover.glb \
         batch043/physics/phys_weighted.glb; do
  mkdir -p "$OLD/$(dirname "$f")"
  git -C "$ROOT" show "$REF:assets/models/$f" > "$OLD/$f"
done
python3 "$ROOT/tools/art_repairs_2026_09_28/tint_shots.py" \
  "$OLD" "$ROOT/assets/models" > "$H/shots.json"
cp "$ROOT/tools/art_repairs_2026_09_28/tint_views.gd" "$H/tintview.gd"
sed 's/^class_name ArtBench$//' "$ROOT/tools/artpreview/artbench.gd" > "$H/artbench.gd"
run_godot tintview _harness/tintview.gd "$H/shots.json" "$OUT"
