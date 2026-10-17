#!/usr/bin/env bash
# Batch 044's presentation pass on the triad and the terminus, as variants.
# DISPOSABLE REVIEW SHEETS. (Arty, 2026-10-17.)
#
#   tools/batch044_presentation.sh WORK_DIR OUT_DIR
#
# Nothing under assets/ is written: every variant, the control included, is
# built into WORK_DIR by `build_junctions.py --presentation=... --out=...`,
# which refuses an assets/ path. Each variant's models tree is the shipped
# one by symlink, with its own batch044/shells/ (the committed cross linked
# in, so the route walk covers all three rooms).
#
#   1. Blender: control + skin, base, top, face, board, trunks, all
#   2. the stamped furnished views (tools/content/furnished_view.gd)
#   3. the route walk (tools/content/route_walk.gd), every variant
#   4. sheets and numbers
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mkdir -p "$1" && cd "$1" && pwd)"
OUT="$(mkdir -p "$2" && cd "$2" && pwd)"
SHELLS=shell_junction_triad,shell_bay_terminus
VARIANTS="control skin base top face board trunks all"

for v in $VARIANTS; do
    M="$WORK/models/$v"
    mkdir -p "$M"
    "$ROOT/.tools/blender/blender" -b --python \
        "$ROOT/tools/blender/build_junctions.py" -- --presentation="$v" \
        --out="$M" --only="$SHELLS" > "$WORK/build_$v.log" 2>&1 \
        || { echo "[b44] build $v FAILED (see $WORK/build_$v.log)" >&2;
             exit 1; }
    for d in "$ROOT"/assets/models/*/; do
        n="$(basename "$d")"
        [ "$n" = batch044 ] || ln -sfn "$d" "$M/$n"
    done
    ln -sfn "$ROOT/assets/models/batch044/shells/shell_junction_cross.glb" \
        "$M/batch044/shells/shell_junction_cross.glb"
    for s in ${SHELLS//,/ }; do
        bash "$ROOT/tools/content/run_furnished_view.sh" "$s" \
            "$WORK/shots/$v" "$M" > "$WORK/furnish_${v}_$s.log" 2>&1 \
            || { echo "[b44] views $v $s FAILED" >&2; exit 1; }
    done
    bash "$ROOT/tools/content/run_route_walk.sh" "$WORK/walk/$v" "$M" \
        > "$WORK/walk_$v.log" 2>&1 \
        || { echo "[b44] route walk $v FAILED" >&2; exit 1; }
    echo "[b44] $v built, viewed, walked"
done
cmp "$WORK/models/control/batch044/shells/shell_junction_triad.glb" \
    "$ROOT/assets/models/batch044/shells/shell_junction_triad.glb"
cmp "$WORK/models/control/batch044/shells/shell_bay_terminus.glb" \
    "$ROOT/assets/models/batch044/shells/shell_bay_terminus.glb"
echo "[b44] the control is byte-identical to the committed rooms"
python3 "$ROOT/tools/content/batch044_presentation_sheets.py" \
    "$WORK/shots" "$WORK/walk" "$OUT"
find "$ROOT/tools" -name __pycache__ -type d -prune -exec rm -rf {} +
