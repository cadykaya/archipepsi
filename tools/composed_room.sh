#!/usr/bin/env sh
# Batch 001 I -- the composed room. Six captures from the game's own camera.
#
#   tools/composed_room.sh
#
# This is the shot that decides whether the kit makes a PLACE. Everything
# else in the batch proves individual objects.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
OUT="${1:-$ROOT/docs/art/review/batch001}"
THEME="${2:-concrete_facility}"
# Godot's cwd is not the repo root, so a relative out-dir silently writes the
# captures somewhere nobody looks -- and save_png reports no error, so the
# script still says it wrote them.
case "$OUT" in /*) ;; *) OUT="$ROOT/$OUT" ;; esac
[ -x "$GODOT" ] || { echo "composed_room: no godot at $GODOT" >&2; exit 2; }
if [ ! -f "$ROOT/tools/artpreview/.godot/global_script_class_cache.cfg" ]; then
  "$GODOT" --headless --path "$ROOT/tools/artpreview" --import >/dev/null 2>&1 || true
fi
xvfb-run -a -s "-screen 0 1920x1200x24" "$GODOT" --rendering-driver opengl3 --path "$ROOT/tools/artpreview" \
  -s ComposedRoom.gd -- "$ROOT/assets" "$OUT" "$THEME" 2>&1 \
  | grep -E "^\[room\]|SCRIPT ERROR|ERROR: Node" || true
