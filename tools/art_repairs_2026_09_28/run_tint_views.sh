#!/usr/bin/env bash
# Repair 2026-09-28: the skiff and lightened-panel before/after frames.
#
#   tools/art_repairs_2026_09_28/run_tint_views.sh <out-dir> [old-ref]
#   tools/art_repairs_2026_09_28/run_tint_views.sh <out-dir> e4103ba followup
#
# The second form is the follow-up: the seven props whose panels were
# re-seated after the first repair, before (e4103ba) and after.
#
# Extracts the reviewed models from <old-ref> (default a1584c8) into a
# temporary folder, writes the shot list with tint_shots.py, stages the
# harness in a godot/_harness folder it creates and removes (or stops,
# if that folder is already somebody else's), and renders one frame
# per shot for the old and the repaired file. Writes only into <out-dir>.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
OUT="${1:?usage: run_tint_views.sh <out-dir> [old-ref]}"
REF="${2:-a1584c8}"
SET="${3:-first}"
H="$ROOT/godot/_harness"
OLD="$(mktemp -d)"
[ -x "$GODOT" ] || { echo "no godot at $GODOT" >&2; exit 2; }
# shellcheck source=../content/godot_run.sh
. "$ROOT/tools/content/godot_run.sh"
mkdir -p "$OUT"
# The harness folder is claimed, never cleared: if it already exists it is
# somebody else's, and the runner stops without touching it.
if ! mkdir "$H" 2>/dev/null; then
  rm -rf "$OLD"
  echo "$(basename "$0"): $H already exists and is not this run's;" \
       "nothing was touched" >&2
  exit 2
fi
cleanup() { rm -rf "$H" "$OLD"; }
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
if [ "$SET" = followup ]; then
  FILES="ballast cart girder key_component mechanical_part plate power_cell"
  FILES="$(for n in $FILES; do echo "batch043/physics/phys_$n.glb"; done)"
else
  FILES="batch045/setpieces/sp_skiff_deck.glb
    batch043/physics/phys_generic.glb batch043/physics/phys_ballast.glb
    batch043/physics/phys_mechanical_part.glb
    batch043/physics/phys_movable_cover.glb
    batch043/physics/phys_weighted.glb"
fi
for f in $FILES; do
  mkdir -p "$OLD/$(dirname "$f")"
  git -C "$ROOT" show "$REF:assets/models/$f" > "$OLD/$f"
done
python3 "$ROOT/tools/art_repairs_2026_09_28/tint_shots.py" \
  "$OLD" "$ROOT/assets/models" "$SET" "$REF" > "$H/shots.json"
cp "$ROOT/tools/art_repairs_2026_09_28/tint_views.gd" "$H/tintview.gd"
sed 's/^class_name ArtBench$//' "$ROOT/tools/artpreview/artbench.gd" > "$H/artbench.gd"
run_godot tintview _harness/tintview.gd "$H/shots.json" "$OUT"
