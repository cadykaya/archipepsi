#!/usr/bin/env bash
# An approved weapon, developed toward the Foundry's fidelity, end to end.
# DEVELOPMENT MODELS, not shipping assets. (Arty, 2026-10-13)
#
#   tools/weapon_model.sh OUT sightline|switchback|bulkhead|driver [...]
#
# Per weapon, into OUT/<weapon>/:
# 1. refined geometry, one atlas, the bakes + wear spec
#                                       tools/blender/build_weapon_model.py
# 2. paint the maps from the bakes      tools/blender/weapon_paint.py
# 3. Glyph holds, derives the normal map, checks, exports
#                                       tools/glyphui/author_weapon_maps.py
# 4. the lean integration maps (lean_maps.py); the review GLB wearing
#    Glyph's maps, the geometry GLB for integration, <weapon>.json
# 5. Cycles looks at the painted model  build_weapon_model.py -- look
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(mkdir -p "$1" && cd "$1" && pwd)"
shift
BLENDER="$ROOT/.tools/blender/blender"
BPY="$ROOT/.tools/blender/4.5/python/bin/python3.11"
for W in "$@"; do
    D="$OUT/$W"
    "$BLENDER" -b --python "$ROOT/tools/blender/build_weapon_model.py" -- \
        bake "$W" "$D" 2>&1 | grep -E '^\[art\] [a-z]+:' || true
    "$BPY" "$ROOT/tools/blender/weapon_paint.py" "$D"
    # Glyph must pass: a failure here stops the run (it is not filtered)
    GLYPH_ROOT="${GLYPH_ROOT:-/home/user/glyph-trial}" \
        python3 "$ROOT/tools/glyphui/author_weapon_maps.py" "$D" "$W" \
        > "$D/glyph.log" 2>&1 || { tail -20 "$D/glyph.log"; exit 1; }
    grep -E 'check_material|maps.json' "$D/glyph.log"
    # the integration set: the same texels in the formats they need
    python3 "$ROOT/tools/blender/lean_maps.py" "$D" "$W"
    for MODE in assemble look; do
        "$BLENDER" -b --python "$ROOT/tools/blender/build_weapon_model.py" \
            -- "$MODE" "$W" "$D" 2>&1 | grep -E '^\[art\] (wrote|[a-z]+:)' \
            || true
    done
    test -s "$D/$W.glb"
done
echo "[weapon_model] done -> $OUT"
