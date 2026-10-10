#!/usr/bin/env bash
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
OUT="${1:-$ROOT/docs/art/review/skiffkit_2026-09-22}"
H="$ROOT/godot/_harness"
[ -x "$GODOT" ] || { echo "no godot at $GODOT" >&2; exit 2; }
# shellcheck source=godot_run.sh
. "$ROOT/tools/content/godot_run.sh"
mkdir -p "$OUT"
cleanup() { rm -rf "$H"; }
trap cleanup EXIT
cleanup; mkdir -p "$H"
cp "$ROOT/tools/content/skiffkit_views.gd" "$H/skiffview.gd"
sed 's/^class_name ArtBench$//' "$ROOT/tools/artpreview/artbench.gd" > "$H/artbench.gd"
run_godot skiffview _harness/skiffview.gd "$ROOT/assets/models" "$OUT"
