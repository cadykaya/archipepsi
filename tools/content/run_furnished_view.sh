#!/usr/bin/env bash
# One room, furnished the way the runtime would. Preview only, and stamped.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
SHELL_ID="${1:-shell_junction_cross}"
OUT="${2:-$ROOT/docs/art/review/furnished_2026-09-13}"
H="$ROOT/godot/_harness"
[ -x "$GODOT" ] || { echo "no godot at $GODOT" >&2; exit 2; }
# shellcheck source=godot_run.sh
. "$ROOT/tools/content/godot_run.sh"
mkdir -p "$OUT"
cleanup() { rm -rf "$H"; }
trap cleanup EXIT
cleanup; mkdir -p "$H"
cp "$ROOT/tools/content/furnished_view.gd" "$H/furnish.gd"
sed 's/^class_name ArtBench$//' "$ROOT/tools/artpreview/artbench.gd" > "$H/artbench.gd"
run_godot furnish _harness/furnish.gd "$ROOT/assets/models" "$OUT" "$SHELL_ID"
