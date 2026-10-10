#!/usr/bin/env bash
# Track A2 -- stage the four direction studies' review package from source.
#
#   tools/menu_proto/studies/stage.sh <review dir>
#
# Renders every direction (render.sh), composes the overviews, motion sheets
# and comparison sheets (compose.py), and copies the deliverable set into
# <review dir>: per direction the five gameplay-size screens, the overview
# and the annotated motion sheet; and the two comparison sheets. The review
# directory's README.md is written by hand and left alone. Nothing here is
# edited by hand: re-run this to regenerate.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REVIEW="${1:?usage: stage.sh <review dir>}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
"$HERE/render.sh" "$WORK" ABCD
python3 "$HERE/compose.py" "$WORK" "$WORK/sheets"
mkdir -p "$REVIEW"
rm -f "$REVIEW"/*.png
for d in A B C D; do
  cp "$WORK/$d/${d}"_[1-5]_*.png "$REVIEW/"
  cp "$WORK/sheets/${d}_0_overview.png" "$WORK/sheets/${d}_6_motion.png" "$REVIEW/"
done
cp "$WORK/sheets/00_compare_equipment.png" "$WORK/sheets/00_compare_overviews.png" "$REVIEW/"
echo "stage: $(ls "$REVIEW"/*.png | wc -l) images -> $REVIEW ($(du -sh "$REVIEW" | cut -f1))"
