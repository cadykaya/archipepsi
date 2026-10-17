#!/usr/bin/env bash
# The Shunter look sheet, end to end. DISPOSABLE CONCEPT. (Arty, 2026-10-17.)
#
#   tools/shunter_looks.sh PROD_CHECKOUT WORK_DIR OUT_DIR
#
# PROD_CHECKOUT is a READ-ONLY checkout of a Production build with Crossing
# D (`--crossing-d --empty-yard`): `dcap.gd` is copied into its tests/ for
# the run, checked to parse first, and removed after; nothing of Prod's is
# edited. Renderer: Forward+, the game's own, on Mesa's software Vulkan.
#
#   1. Blender: 9 looks x 4 states of the maquette (study_shunter_looks.py)
#   2. one dcap spec per pose, plus the empty yard
#   3. Godot: each pose alone in the yard, four cameras, colour and grey
#   4. the sheets and the numbers
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROD="$(cd "$1" && pwd)"
WORK="$(mkdir -p "$2" && cd "$2" && pwd)"
OUT="$(mkdir -p "$3" && cd "$3" && pwd)"
GODOT="$ROOT/.tools/godot"
LVP=/usr/share/vulkan/icd.d/lvp_icd.json
[ -f "$LVP" ] && export VK_ICD_FILENAMES="$LVP"

"$ROOT/.tools/blender/blender" -b --python \
    "$ROOT/tools/blender/study_shunter_looks.py" -- "$WORK/glb" 2>&1 \
    | grep -E "^\[shunter\]" | tail -1
python3 "$ROOT/tools/crossing_capture/shunter_looks.py" specs \
    "$WORK/glb" "$WORK/specs"

cp "$ROOT/tools/crossing_capture/dcap.gd" "$PROD/godot/tests/_arty_dcap.gd"
if ! timeout 120 "$GODOT" --headless --path "$PROD/godot" --check-only \
        -s res://tests/_arty_dcap.gd > /dev/null 2>&1; then
    echo "[looks] dcap.gd does not parse; nothing run" >&2
    rm -f "$PROD/godot/tests/_arty_dcap.gd"*
    exit 1
fi
for spec in "$WORK"/specs/*.json; do
    name="$(basename "$spec" .json)"
    mkdir -p "$WORK/shots/$name"
    [ -f "$WORK/shots/$name/R6_gray.png" ] && continue
    timeout 600 xvfb-run -a -s "-screen 0 1920x1200x24" "$GODOT" \
        --rendering-method forward_plus --rendering-driver vulkan \
        --path "$PROD/godot" --resolution 1600x900 \
        -s res://tests/_arty_dcap.gd -- --crossing-d --empty-yard \
        --dcap="$spec" --out="$WORK/shots/$name" > "$WORK/shots/$name.log" 2>&1
    if [ -f "$WORK/shots/$name/R6_gray.png" ]; then
        echo "[looks] shot $name"
    else
        echo "[looks] FAILED $name (see $WORK/shots/$name.log)"
    fi
done
rm -f "$PROD/godot/tests/_arty_dcap.gd"*
python3 "$ROOT/tools/crossing_capture/shunter_looks.py" sheets \
    "$WORK/shots" "$OUT"
find "$ROOT/tools" -name __pycache__ -type d -prune -exec rm -rf {} +
