#!/usr/bin/env bash
# The five-weapon integration package, assembled from its runs. (Arty,
# 2026-10-14.)
#
#   tools/five_integration_package.sh ART CAP OUT [PREV_DEV]
#
# ART  tools/weapon_model.sh's output for sightline, switchback, bulkhead
#      and driver, plus foundry/ (foundry_geometry.py + lean_maps.py)
# CAP  tools/five_integration.sh's output (Prod's range, read-only)
# OUT  the review folder, e.g. docs/art/review/weapon_integration_2026-10-14
# PREV_DEV  the 2026-10-13 development build (its Cycles looks), for the
#      before/after memory sheet
#
# Copies, per weapon, what integration takes (the geometry GLB, the lean
# maps and their recipe, the model record) and the range records; then
# lays out the sheets. Nothing is edited by hand; rerun to regenerate.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ART="$(cd "$1" && pwd)"
CAP="$(cd "$2" && pwd)"
mkdir -p "$3"
OUT="$(cd "$3" && pwd)"
PREV_DEV="${4:-}"

for w in foundry sightline switchback bulkhead driver; do
    d="$OUT/models/$w"
    mkdir -p "$d/lean"
    cp "$ART/$w/${w}_geo.glb" "$d/"
    cp "$ART/$w/lean/"*.png "$ART/$w/lean/lean.json" "$d/lean/"
    [ -f "$ART/$w/$w.json" ] && cp "$ART/$w/$w.json" "$d/"
done

mkdir -p "$OUT/range"
cp "$CAP"/*_stills.json "$CAP"/*_impacts.json "$CAP"/*_clip.json \
    "$OUT/range/"

python3 "$ROOT/tools/crossing_capture/five_integration_sheets.py" \
    "$ART" "$CAP" "$OUT" \
    "$ROOT/docs/art/review/weapon_development_2026-10-13/in_range" \
    ${PREV_DEV:+"$PREV_DEV"}
find "$ROOT/tools" -name __pycache__ -type d -prune -exec rm -rf {} +
echo "[package] $OUT ($(du -sh "$OUT" | cut -f1))"
