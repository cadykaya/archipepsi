#!/usr/bin/env bash
# Walk the span-basin routes with a player-shaped body, jumping at risers.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
MODELS="${2:-$ROOT/assets/models}"
OUT="${1:-$ROOT/docs/art/review/span_2026-09-13}"
H="$ROOT/godot/_harness"
[ -x "$GODOT" ] || { echo "no godot at $GODOT" >&2; exit 2; }
# shellcheck source=godot_run.sh
. "$ROOT/tools/content/godot_run.sh"
mkdir -p "$OUT"
cleanup() { rm -rf "$H"; }
trap cleanup EXIT
cleanup; mkdir -p "$H"
cp "$ROOT/tools/content/route_walk.gd" "$H/route.gd"
sed 's/^class_name ArtBench$//' "$ROOT/tools/artpreview/artbench.gd" > "$H/artbench.gd"
run_godot route _harness/route.gd "$MODELS" "$OUT"
