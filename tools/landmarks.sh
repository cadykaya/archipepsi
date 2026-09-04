#!/usr/bin/env sh
# Batch 023 -- PROPOSAL: the theme landmarks at player scale.
#   tools/landmarks.sh [out_dir]
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
OUT="${1:-$ROOT/docs/art/review/batch023}"
case "$OUT" in /*) ;; *) OUT="$ROOT/$OUT" ;; esac
[ -x "$GODOT" ] || { echo "landmarks: no godot at $GODOT" >&2; exit 2; }
xvfb-run -a -s "-screen 0 1920x1200x24" "$GODOT" --rendering-driver opengl3 \
  --path "$ROOT/tools/artpreview" -s Landmarks.gd -- "$ROOT/assets" "$OUT" 2>&1 \
  | grep -E "^\[landmarks\]|SCRIPT ERROR|ERROR: Node" || true
