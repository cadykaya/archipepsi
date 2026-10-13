#!/usr/bin/env bash
# The Foundry fidelity study, end to end. NON-PRODUCTION. (Arty, 2026-10-13)
#
#   tools/foundry_study.sh OUT [PROD_CHECKOUT]
#
# 1. model, unwrap, bake masks          tools/blender/build_foundry_study.py
# 2. paint the maps from the bakes      tools/blender/foundry_paint.py
# 3. Glyph holds, derives, checks, exports the maps
#                                       tools/glyphui/author_foundry_study_maps.py
# 4. the GLB, wearing Glyph's maps      build_foundry_study.py -- assemble
# 5. (with PROD_CHECKOUT, a read-only checkout of review/five-weapons-v2)
#    the real game: stills, then the firing clip through the movie maker
#                                       tools/crossing_capture/foundry_study.gd
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(mkdir -p "$1" && cd "$1" && pwd)"
PROD="${2:-}"
BLENDER="$ROOT/.tools/blender/blender"
BPY="$ROOT/.tools/blender/4.5/python/bin/python3.11"
GODOT="$ROOT/.tools/godot"

"$BLENDER" -b --python "$ROOT/tools/blender/build_foundry_study.py" -- bake "$OUT" \
    2>&1 | grep -E '^\[art\]' || true
"$BPY" "$ROOT/tools/blender/foundry_paint.py" "$OUT"
GLYPH_ROOT="${GLYPH_ROOT:-/home/user/glyph-trial}" \
    python3 "$ROOT/tools/glyphui/author_foundry_study_maps.py" "$OUT"
"$BLENDER" -b --python "$ROOT/tools/blender/build_foundry_study.py" -- assemble "$OUT" \
    2>&1 | grep -E '^\[art\]' || true
test -s "$OUT/foundry_study.glb"

if [ -n "$PROD" ]; then
    cp "$ROOT/tools/crossing_capture/foundry_study.gd" \
        "$PROD/godot/tests/_arty_foundry_study.gd"
    run() {   # mode [extra godot args...]
        local mode="$1"; shift
        xvfb-run -a -s "-screen 0 1920x1200x24" "$GODOT" --rendering-driver opengl3 \
            --path "$PROD/godot" --resolution 1600x900 "$@" \
            -s res://tests/_arty_foundry_study.gd -- --five-weapons \
            --glb="$OUT/foundry_study.glb" --out="$OUT/capture" --mode="$mode" \
            2>&1 | grep -E '^\[study\]' || true
    }
    run placeholder
    run stills
    # the AVI (real time, with sound) first; the PNG frames second, so the
    # clip.json left behind is the one whose `drawn` indices name them
    run clip --fixed-fps 60 --write-movie "$OUT/capture/foundry_clip.avi"
    mkdir -p "$OUT/capture/frames"
    run clip --fixed-fps 60 --write-movie "$OUT/capture/frames/f.png"
    python3 "$ROOT/tools/crossing_capture/foundry_study_sheets.py" "$OUT" \
        "$OUT/sheets"
    rm -f "$PROD/godot/tests/_arty_foundry_study.gd" \
        "$PROD/godot/tests/_arty_foundry_study.gd.uid"
fi
echo "[foundry_study] done -> $OUT"
