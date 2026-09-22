#!/usr/bin/env bash
# A theme pack in context: the kit dressing a Production-grey shell.
#
#   tools/content/run_pack_views.sh <pack-id> [out-dir]
#
# The shell, the gates and the opening check are shared; the layout --
# where the pieces go, which is art -- is tools/content/packlayouts/<pack>.json.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PACK="${1:?usage: run_pack_views.sh <pack-id> [out-dir]}"
LAYOUT="$ROOT/tools/content/packlayouts/$PACK.json"
GODOT="${GODOT:-$ROOT/.tools/godot}"
OUT="${2:-$ROOT/docs/art/review/${PACK}_$(date +%Y-%m-%d)}"
# Absolute, always. Godot runs with --path godot, so a relative
# out-dir lands somewhere nobody meant and every save fails.
case "$OUT" in /*) ;; *) OUT="$(pwd)/$OUT" ;; esac
H="$ROOT/godot/_harness"
[ -x "$GODOT" ] || { echo "no godot at $GODOT" >&2; exit 2; }
[ -f "$LAYOUT" ] || { echo "no layout at $LAYOUT" >&2; exit 2; }
# shellcheck source=godot_run.sh
. "$ROOT/tools/content/godot_run.sh"
mkdir -p "$OUT"
cleanup() { rm -rf "$H"; }
trap cleanup EXIT
cleanup; mkdir -p "$H"
cp "$ROOT/tools/content/pack_views.gd" "$H/packview.gd"
sed 's/^class_name ArtBench$//' "$ROOT/tools/artpreview/artbench.gd" > "$H/artbench.gd"
run_godot packview _harness/packview.gd "$ROOT/assets/models" "$OUT" "$LAYOUT"
echo "pack-views: $PACK -- $(ls "$OUT"/*.png | wc -l) captures in $OUT"
