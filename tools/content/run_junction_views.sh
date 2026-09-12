#!/usr/bin/env bash
# Interior views of the three branching rooms, from a standing player's eye.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
OUT="${1:-$ROOT/docs/art/review/junctions_2026-09-13}"
H="$ROOT/godot/_harness"
[ -x "$GODOT" ] || { echo "no godot at $GODOT" >&2; exit 2; }
# shellcheck source=godot_run.sh
. "$ROOT/tools/content/godot_run.sh"
mkdir -p "$OUT"
cleanup() { rm -rf "$H"; }
trap cleanup EXIT
cleanup; mkdir -p "$H"
cp "$ROOT/tools/content/junction_views.gd" "$H/views.gd"
sed 's/^class_name ArtBench$//' "$ROOT/tools/artpreview/artbench.gd" > "$H/artbench.gd"
run_godot views _harness/views.gd "$ROOT/assets/models" "$OUT"
