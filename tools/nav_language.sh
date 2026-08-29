#!/usr/bin/env sh
# Batch 022 -- PROPOSAL: the navigation language, in room contexts.
#
#   tools/nav_language.sh [out_dir]
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
OUT="${1:-$ROOT/docs/art/review/batch022}"
case "$OUT" in /*) ;; *) OUT="$ROOT/$OUT" ;; esac
[ -x "$GODOT" ] || { echo "nav_language: no godot at $GODOT" >&2; exit 2; }
if [ ! -f "$ROOT/tools/artpreview/.godot/global_script_class_cache.cfg" ]; then
  "$GODOT" --headless --path "$ROOT/tools/artpreview" --import >/dev/null 2>&1 || true
fi
xvfb-run -a -s "-screen 0 1920x1200x24" "$GODOT" --rendering-driver opengl3 \
  --path "$ROOT/tools/artpreview" -s NavLanguage.gd -- "$ROOT/assets" "$OUT" 2>&1 \
  | grep -E "^\[nav\]|SCRIPT ERROR|ERROR: Node" || true
