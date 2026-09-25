#!/usr/bin/env bash
# Track B -- the ten-role family's silhouettes at the review distance.
#
#   tools/content/run_enemy_silhouettes.sh [out dir]
#
# Renders each role at `enemy_review_distance_m` through the game's own
# camera and writes its silhouette at NATIVE SIZE, then
# `tools/content/enemy_readability.py` measures how far apart they are.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
MODELS="${ENEMY_MODELS:-$ROOT/assets/models/batch030/enemies}"
OUT="${1:-$ROOT/docs/art/review/enemies_2026-09-25}"
H="$ROOT/godot/_harness"
[ -x "$GODOT" ] || { echo "no godot at $GODOT" >&2; exit 2; }
# shellcheck source=godot_run.sh
. "$ROOT/tools/content/godot_run.sh"
mkdir -p "$OUT"
cleanup() { rm -rf "$H"; }
trap cleanup EXIT
cleanup; mkdir -p "$H"
sed 's/^class_name ArtBench$//' "$ROOT/tools/artpreview/artbench.gd" \
  > "$H/artbench.gd"
cp "$ROOT/tools/content/enemy_silhouettes.gd" "$H/enemysil.gd"
run_godot enemysil _harness/enemysil.gd "$OUT" "$MODELS" \
  "$ROOT/assets/art_budgets.json" "$MODELS/manifest.json"
