#!/usr/bin/env bash
# Track A2 -- stage the hybrid visual checkpoint (the fourth ruling of
# 2026-09-27) from source.
#
#   tools/menu_proto/studies/stage_hybrid.sh <review dir>
#
# Renders the hybrid (render.sh H), composes its cross-wall overview
# (compose.py), and copies into <review dir>: the five gameplay-size screens,
# the two half-way turns across the joins, and the overview. The review
# directory's README.md is written by hand and left alone. Nothing here is
# edited by hand: re-run this to regenerate.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REVIEW="${1:?usage: stage_hybrid.sh <review dir>}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
"$HERE/render.sh" "$WORK" H
python3 "$HERE/compose.py" "$WORK" "$WORK/sheets" H
mkdir -p "$REVIEW"
rm -f "$REVIEW"/*.png
cp "$WORK/H/H"_[1-5]_*.png "$REVIEW/"
cp "$WORK/H/H_m1_turn_journal_map.png" "$REVIEW/H_6_turn_journal_map.png"
cp "$WORK/H/H_m4_turn_equipment_settings.png" "$REVIEW/H_7_turn_equipment_settings.png"
cp "$WORK/sheets/H_0_overview.png" "$REVIEW/"
echo "stage: $(ls "$REVIEW"/*.png | wc -l) images -> $REVIEW ($(du -sh "$REVIEW" | cut -f1))"
