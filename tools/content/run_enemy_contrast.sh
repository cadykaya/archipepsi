#!/usr/bin/env bash
# Tier 1 -- enemy body against wall, floor, dim light and an opening onto
# the room's void, in all six rooms under each room's own light.
#
#   tools/content/run_enemy_contrast.sh [out dir] [models.json]
#
# `models.json` maps each theme to a model directory, which is how a
# band candidate is measured: the themes in a band point at that band's
# build. Omitted, every theme uses ITS OWN shipped band, read from the
# generated `assets/models/batch030/enemy_value_bands.json` -- so the
# default run measures the treatment as it landed (RULED 2026-09-26).
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
OUT="${1:-$ROOT/docs/art/review/enemies_2026-09-25/contrast_current}"
MAP="${2:-}"
H="$ROOT/godot/_harness"
[ -x "$GODOT" ] || { echo "no godot at $GODOT" >&2; exit 2; }
# shellcheck source=godot_run.sh
. "$ROOT/tools/content/godot_run.sh"
mkdir -p "$OUT"
cleanup() { rm -rf "$H"; }
trap cleanup EXIT
cleanup; mkdir -p "$H"
if [ -z "$MAP" ]; then
  MAP="$H/models.json"
  python3 - "$ROOT" "$MAP" <<'PY'
import json, sys
root, out = sys.argv[1], sys.argv[2]
bands = json.load(open(root + "/assets/models/batch030/enemy_value_bands.json"))
rooms = ("concrete_facility", "rusted_industrial", "neon_transit",
         "gothic_stone", "temple_ruin", "void_glitch")
missing = [t for t in rooms if t not in bands["room_band"]]
if missing:
    sys.exit("run_enemy_contrast: no value band for %s" % missing)
json.dump({t: root + "/assets/models/" +
           bands["bands"][bands["room_band"][t]]["models"] for t in rooms},
          open(out, "w"))
PY
fi
# The environment in enemy_contrast.gd is copied from Production's
# zone_builder.gd. A copy goes stale silently, so every value it depends
# on is checked against its source before anything renders -- the fog
# colour included, because the opening case IS the fog colour.
PROD="${PROD_04_REF:-origin/claude/archipepsi-0-4-blindside}"
zb="$(git -C "$ROOT" show "$PROD:godot/scripts/generation/zone_builder.gd")"
for want in "env.ambient_light_energy = 0.35" "env.fog_density = 0.012" \
            "env.ambient_light_color = ThemeMaterials.light_color(theme)" \
            "env.fog_enabled = true" \
            "env.background_color = ThemeMaterials.void_color(theme)" \
            "env.fog_light_color = ThemeMaterials.void_color(theme).lightened(0.1)"; do
  printf '%s\n' "$zb" | grep -qF -- "$want" || {
    echo "run_enemy_contrast: zone_builder.gd no longer says '$want'. The
  contrast harness copies the game's room environment and would now be
  measuring a different one. Update AMBIENT / FOG_DENSITY to match." >&2
    exit 1; }
done
tm="$(git -C "$ROOT" show "$PROD:godot/scripts/generation/theme_materials.gd")"
printf '%s\n' "$tm" | grep -qF -- 'return Color(spec(theme)["trim_color"]).darkened(0.6)' || {
  echo "run_enemy_contrast: ThemeMaterials.void_color no longer darkens the
  trim by 0.6; the harness's void and fog colours would now be wrong" >&2
  exit 1; }
# The lamps and void colours come from art_palette.json's engine anchors,
# which are a COPY of Production's THEME_MATERIALS. Every room's light was
# once measured under another room's lamp; this makes a stale copy fail.
git -C "$ROOT" show "$PROD:godot/scripts/autoload/constants.gd" | python3 -c '
import json, re, sys
src = sys.stdin.read()
m = re.search(r"^const THEME_MATERIALS = (\{.*\})$", src, re.M)
if not m:
    sys.exit("run_enemy_contrast: no THEME_MATERIALS line in constants.gd")
prod = json.loads(m.group(1))
mine = json.load(open(sys.argv[1]))["engine_anchors"]
bad = ["%s.%s: palette %r, Production %r" % (t, k, mine[t][k], prod[t][k])
       for t in prod for k in ("trim_color", "light_color", "light_energy")
       if t not in mine or str(mine[t][k]).lower() != str(prod[t][k]).lower()]
if bad:
    sys.exit("run_enemy_contrast: engine anchors differ from Production:\n  "
             + "\n  ".join(bad))
' "$ROOT/assets/art_palette.json" || exit 1
for knob in tonemap_mode fog_height_density fog_sun_scatter fog_aerial_perspective fog_light_energy fog_sky_affect fog_mode; do
  printf '%s\n' "$zb" | grep -q "$knob" && {
    echo "run_enemy_contrast: zone_builder.gd now sets $knob; this harness
  assumes Godot's default for it and must be updated to match" >&2
    exit 1; }
done

sed 's/^class_name ArtBench$//' "$ROOT/tools/artpreview/artbench.gd" \
  > "$H/artbench.gd"
cp "$ROOT/tools/content/enemy_contrast.gd" "$H/contrast.gd"
GODOT_RUN_TIMEOUT="${GODOT_RUN_TIMEOUT:-1500}" run_godot contrast \
  _harness/contrast.gd "$OUT" "$ROOT/assets/art_palette.json" \
  "$ROOT/assets/art_budgets.json" "$MAP"
