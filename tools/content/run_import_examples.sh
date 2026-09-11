#!/usr/bin/env bash
# Run the Batch 043 import examples and record what they measured.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
OUT="${1:-$ROOT/docs/art/review/props_2026-09-11/room}"
H="$ROOT/godot/_harness"
[ -x "$GODOT" ] || { echo "no godot at $GODOT" >&2; exit 2; }
mkdir -p "$OUT"
cleanup() { rm -rf "$H"; }
trap cleanup EXIT
cleanup; mkdir -p "$H"
cp "$ROOT/tools/content/import_examples.gd" "$H/examples.gd"
sed 's/^class_name ArtBench$//' "$ROOT/tools/artpreview/artbench.gd" > "$H/artbench.gd"
xvfb-run -a "$GODOT" --path "$ROOT/godot" --rendering-driver opengl3 \
  -s _harness/examples.gd -- "$ROOT/assets/models" "$OUT" 2>&1 \
  | grep -E "^\[examples\]|SCRIPT ERROR" || true
