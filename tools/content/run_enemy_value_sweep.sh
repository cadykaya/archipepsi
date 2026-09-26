#!/usr/bin/env bash
# Tier 1 -- the value sweep the enemy bands are chosen from.
#
#   tools/content/run_enemy_value_sweep.sh [out dir]
#
# For each step of the lightness grid, build the ten enemies with their
# body ramp's L* scaled by that factor (hue and chroma held; the markings
# untouched) and measure them in all six rooms x four cases with
# run_enemy_contrast.sh. The builds go to the gitignored
# assets/themed/_enemy_lightness_<k>/, never over the shipped models, and
# only each step's contrast.json is kept, as <out>/sweep/k<k>.json -- the
# frames are one command away and would be 3 MB a step.
#
# Then the pure-black matte limit (the darkest a body can render in each
# room: the room's own fog, not paint), then enemy_value_bands.py derives
# the fewest bands, and the recommended two-band candidate is measured
# once more WITH its frames, into <out>/candidate_two_bands/.
#
# One Godot at a time: every step goes through godot/_harness.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BLENDER="${BLENDER:-$ROOT/.tools/blender/blender}"
OUT="${1:-$ROOT/docs/art/review/enemies_2026-09-25/value_bands}"
GRID="${ENEMY_SWEEP_GRID:-1.00 0.85 0.70 0.55 0.40 0.25 0.10}"
[ -x "$BLENDER" ] || { echo "no blender at $BLENDER" >&2; exit 2; }
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT/sweep"

# EVERY step, 1.00 included, is a scratch build. Before the bands landed
# (2026-09-26) k 1.00 was the shipped folder; it now holds the standard
# band, and a sweep that read it as "today's skin" would measure k 0.40
# twice and call one of them 1.00.
models_for() {
  echo "$ROOT/assets/themed/_enemy_lightness_$1/models/batch030/enemies"
}

map_all() {  # every theme -> one model dir
  python3 - "$1" "$2" <<'PY'
import json, sys
json.dump({t: sys.argv[1] for t in ("concrete_facility", "rusted_industrial",
    "neon_transit", "gothic_stone", "temple_ruin", "void_glitch")},
    open(sys.argv[2], "w"))
PY
}

for k in $GRID; do
  ENEMY_LIGHTNESS="$k" "$BLENDER" --background \
    --python "$ROOT/tools/blender/build_enemy_roles.py" > "$TMP/build_$k.log" 2>&1 \
    || { tail -20 "$TMP/build_$k.log" >&2; echo "build k$k failed" >&2; exit 1; }
  map_all "$(models_for "$k")" "$TMP/map_$k.json"
  "$ROOT/tools/content/run_enemy_contrast.sh" "$TMP/run_$k" "$TMP/map_$k.json" \
    > "$TMP/run_$k.log" 2>&1 \
    || { tail -20 "$TMP/run_$k.log" >&2; echo "measure k$k failed" >&2; exit 1; }
  cp "$TMP/run_$k/contrast.json" "$OUT/sweep/k$k.json"
  echo "[sweep] k$k measured"
done

map_all "$(models_for 1.00)" "$TMP/map_black.json"
ENEMY_CONTRAST_BLACK=1 ENEMY_CONTRAST_MATTE=1 \
  "$ROOT/tools/content/run_enemy_contrast.sh" "$TMP/run_black" "$TMP/map_black.json" \
  > "$TMP/run_black.log" 2>&1 \
  || { tail -20 "$TMP/run_black.log" >&2; echo "black limit failed" >&2; exit 1; }
cp "$TMP/run_black/contrast.json" "$OUT/sweep/limit_black_matte.json"
echo "[sweep] black-matte limit measured"

python3 "$ROOT/tools/content/enemy_value_bands.py" "$OUT/sweep" | tee "$OUT/derivation.txt"

python3 - "$OUT/value_bands.json" "$TMP/map_two.json" "$ROOT" <<'PY'
import json, sys
bands = json.load(open(sys.argv[1]))["partitions"]["2"]["by_theme"]
root = sys.argv[3]
def d(k):
    return root + "/assets/themed/_enemy_lightness_%.2f/models/batch030/enemies" % k
json.dump({t: d(k) for t, k in bands.items()}, open(sys.argv[2], "w"))
PY
rm -rf "$OUT/candidate_two_bands"
"$ROOT/tools/content/run_enemy_contrast.sh" "$OUT/candidate_two_bands" "$TMP/map_two.json" \
  > "$TMP/run_two.log" 2>&1 \
  || { tail -20 "$TMP/run_two.log" >&2; echo "candidate failed" >&2; exit 1; }
echo "[sweep] two-band candidate measured -> $OUT/candidate_two_bands"
