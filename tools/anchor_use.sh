#!/usr/bin/env sh
# Batch 002 E -- what each grapple anchor is FOR.
#
#   tools/anchor_use.sh [out_dir]
#
# A review sheet shows an object. This shows the job: each anchor mounted
# where it belongs, with the jump apex and flat reach it has to beat drawn
# into the same frame.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
OUT="${1:-$ROOT/docs/art/review/batch002}"
case "$OUT" in /*) ;; *) OUT="$ROOT/$OUT" ;; esac
[ -x "$GODOT" ] || { echo "anchor_use: no godot at $GODOT" >&2; exit 2; }
if [ ! -f "$ROOT/tools/artpreview/.godot/global_script_class_cache.cfg" ]; then
  "$GODOT" --headless --path "$ROOT/tools/artpreview" --import >/dev/null 2>&1 || true
fi
xvfb-run -a -s "-screen 0 1920x1200x24" "$GODOT" --rendering-driver opengl3 \
  --path "$ROOT/tools/artpreview" -s AnchorUse.gd -- "$ROOT/assets" "$OUT" 2>&1 \
  | grep -E "^\[anchoruse\]|SCRIPT ERROR|ERROR: Node" || true
