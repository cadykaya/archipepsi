#!/usr/bin/env bash
# Owner review 2026-09-28: the seven T01-T07 prop packs and the house
# baseline under ONE fixed light and the shared approach camera.
#
#   tools/owner_review_2026_09_28/run_packs_fixed_light.sh <out-dir>
#
# Stages the isolated harness copy (pack_views_review.gd) exactly the way
# tools/content/run_pack_views.sh stages the original: into a temporary
# godot/_harness that is removed on exit. The layouts are the copies in
# packs_fixed_light/ (make_fixed_light_layouts.py). Nothing else moves.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:?usage: run_packs_fixed_light.sh <out-dir>}"
GODOT="${GODOT:-$ROOT/.tools/godot}"
H="$ROOT/godot/_harness"
[ -x "$GODOT" ] || { echo "no godot at $GODOT" >&2; exit 2; }
. "$ROOT/tools/content/godot_run.sh"
mkdir -p "$OUT"
cleanup() { rm -rf "$H"; }
trap cleanup EXIT
cleanup; mkdir -p "$H"
cp "$ROOT/tools/owner_review_2026_09_28/pack_views_review.gd" "$H/packview.gd"
sed 's/^class_name ArtBench$//' "$ROOT/tools/artpreview/artbench.gd" > "$H/artbench.gd"
for L in "$ROOT"/tools/owner_review_2026_09_28/packs_fixed_light/*.json; do
  run_godot packview _harness/packview.gd "$ROOT/assets/models" "$OUT" "$L"
done
echo "packs-fixed-light: $(ls "$OUT"/*.png | wc -l) captures in $OUT"
