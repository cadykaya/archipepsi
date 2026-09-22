#!/usr/bin/env bash
# A10.2 -- the ten approved roles against Production's own envelopes,
# and against Production's own damage-tint rule.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
PROD="${PROD_04_REF:-origin/claude/archipepsi-0-4-blindside}"
OUT="${1:-$ROOT/docs/art/review/enemy_readiness_2026-09-22}"
H="$ROOT/godot/_harness"
[ -x "$GODOT" ] || { echo "no godot at $GODOT" >&2; exit 2; }
# shellcheck source=godot_run.sh
. "$ROOT/tools/content/godot_run.sh"
mkdir -p "$OUT"
cleanup() { rm -rf "$H"; }
trap cleanup EXIT
cleanup; mkdir -p "$H"
git -C "$ROOT" show "$PROD:godot/scripts/autoload/constants.gd" \
  | sed 's/^class_name .*$//' > "$H/prod_constants.gd"
cp "$ROOT/tools/content/enemy_readiness.gd" "$H/enemyready.gd"
run_godot enemyready _harness/enemyready.gd "$ROOT/assets/models" \
  "$OUT/readiness.json"
