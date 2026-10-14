#!/usr/bin/env bash
# The five weapons in Prod's range: placeholder against art, every capture
# the integration package shows. (Arty, 2026-10-14)
#
#   tools/five_integration.sh ART PROD_CHECKOUT OUT [weapon ...]
#
# ART holds, per weapon, <w>/<w>_geo.glb and <w>/lean/ (tools/weapon_model.sh
# and, for the Foundry, tools/blender/foundry_geometry.py + lean_maps.py).
# PROD_CHECKOUT is a READ-ONLY checkout of review/five-weapons-v3: the two
# capture scripts are copied into its tests/ for the run and removed after;
# nothing of Prod's is edited.
#
# Per weapon (the Bulkhead once per variant), for Prod's placeholder with
# his own effects, then the art with the Glyph effects:
#   stills   (--fixed-fps 60)  rest, ADS, the shot; cost; clearance
#   impacts  (--fixed-fps 60)  metal, stone, wood, gel: impact and mark
#   clip     (--fixed-fps 30, movie frames)  a burst, every frame logged
#
# An entry `before=<weapon>=<glb>` instead runs only the stills of a GLB as
# it was delivered before (its maps embedded), tagged <weapon>_before: the
# "before" of the texture-memory comparison, in the same renderer.
# SIDES="art" re-runs only the art (default: "placeholder art").
# MODES="stills" runs only some modes (default: "stills impacts clip").
# The art's normal map loads as RG8 (Godot's shader rebuilds Z: pixel-
# identical, 18% less texture memory); NORMAL=rgb loads it as imported,
# RGB8 (tags <base>_art_rgb).
#
# The renderer is the game's own, Forward+ (Prod's project sets no other),
# on Mesa's software Vulkan (lavapipe; `apt-get install mesa-vulkan-drivers`
# on a GPU-less machine). Not Compatibility: the bullet marks are Decals,
# which Compatibility does not draw. RENDERER=compat runs the old way.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ART="$(cd "$1" && pwd)"
PROD="$(cd "$2" && pwd)"
OUT="$(mkdir -p "$3" && cd "$3" && pwd)"
shift 3
WEAPONS=("$@")
[ ${#WEAPONS[@]} -eq 0 ] && WEAPONS=(foundry sightline switchback \
    bulkhead:breacher bulkhead:sweeper driver)
GODOT="$ROOT/.tools/godot"
if [ "${RENDERER:-forward_plus}" = compat ]; then
    RENDER_ARGS=(--rendering-driver opengl3)
else
    RENDER_ARGS=(--rendering-method forward_plus --rendering-driver vulkan)
    LVP=/usr/share/vulkan/icd.d/lvp_icd.json
    [ -f "$LVP" ] && export VK_ICD_FILENAMES="$LVP"
fi
FX="$ROOT/assets/fx/weapons/fx.json"
cp "$ROOT/tools/crossing_capture/five_integration.gd" \
    "$PROD/godot/tests/_arty_five_integration.gd"
cp "$ROOT/tools/crossing_capture/glyph_fx_layer.gd" \
    "$PROD/godot/tests/_arty_glyph_fx_layer.gd"
# both must parse before any run: a parse error does not stop Godot, it
# leaves each run to wait out its timeout without the effects
for f in _arty_five_integration.gd _arty_glyph_fx_layer.gd; do
    if ! timeout 120 "$GODOT" --headless --path "$PROD/godot" --check-only \
            -s "res://tests/$f" > /dev/null 2>&1; then
        echo "[five_integration] $f does not parse; nothing run" >&2
        rm -f "$PROD/godot/tests/_arty_"*
        exit 1
    fi
done

run() {   # tag fps extra-godot-args -- script args...
    local tag="$1" fps="$2"; shift 2
    local godot_args=()
    while [ "$1" != "--" ]; do godot_args+=("$1"); shift; done
    shift
    timeout 600 xvfb-run -a -s "-screen 0 1920x1200x24" "$GODOT" \
        "${RENDER_ARGS[@]}" --path "$PROD/godot" --resolution 1600x900 \
        --fixed-fps "$fps" "${godot_args[@]}" \
        -s res://tests/_arty_five_integration.gd -- --five-weapons \
        --out="$OUT" --tag="$tag" "$@" 2>&1 \
        | grep -E "^\[int\]|SCRIPT ERROR" | sort | uniq -c \
        | sed "s/^/  $tag /"
}

for entry in "${WEAPONS[@]}"; do
    if [ "${entry%%=*}" = before ]; then
        rest="${entry#before=}"
        w="${rest%%=*}"
        run "${w}_before" 60 -- --weapon="$w" --glb="$(cd "$(dirname \
            "${rest#*=}")" && pwd)/$(basename "${rest#*=}")" --mode=stills
        continue
    fi
    w="${entry%%:*}"
    v=""
    [ "$entry" != "$w" ] && v="${entry#*:}"
    var=()
    [ -n "$v" ] && var=(--variant="$v")
    base="$w${v:+_$v}"
    art=(--glb="$ART/$w/${w}_geo.glb" --lean="$ART/$w/lean" --fx="$FX"
         --normal="${NORMAL:-rg}")
    for side in ${SIDES:-placeholder art}; do
        tag="${base}_$side"
        [ "$side" = art ] && [ "${NORMAL:-rg}" = rgb ] && tag="${tag}_rgb"
        extra=()
        [ "$side" = art ] && extra=("${art[@]}")
        for mode in ${MODES:-stills impacts clip}; do
            if [ "$mode" = clip ]; then
                rm -rf "$OUT/${tag}_clip" && mkdir -p "$OUT/${tag}_clip"
                run "$tag" 30 --write-movie "$OUT/${tag}_clip/f.png" -- \
                    --weapon="$w" "${var[@]}" "${extra[@]}" --mode=clip
            else
                run "$tag" 60 -- --weapon="$w" "${var[@]}" "${extra[@]}" \
                    --mode="$mode"
            fi
        done
    done
done
rm -f "$PROD/godot/tests/_arty_five_integration.gd"* \
    "$PROD/godot/tests/_arty_glyph_fx_layer.gd"*
echo "[five_integration] done -> $OUT"
