#!/usr/bin/env sh
# The three enemy archetypes in one frame at ENEMY_AGGRO_RADIUS.
#   tools/enemy_lineup.sh
set -e
# The xvfb screen size is set EXPLICITLY. A SubViewport larger than the
# virtual screen is silently clamped, and the parts of the frame outside the
# clamp come back black -- so a 1600x1080 lineup rendered into a default
# 1280x1024 screen produced a sheet whose entire figure band was empty, with
# no error anywhere. Nothing in the scene can detect this: get_viewport().size
# still reports the size that was asked for.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
OUT="${1:-$ROOT/docs/art/review/batch001}"
case "$OUT" in /*) ;; *) OUT="$ROOT/$OUT" ;; esac
[ -x "$GODOT" ] || { echo "enemy_lineup: no godot at $GODOT" >&2; exit 2; }
if [ ! -f "$ROOT/tools/artpreview/.godot/global_script_class_cache.cfg" ]; then
  "$GODOT" --headless --path "$ROOT/tools/artpreview" --import >/dev/null 2>&1 || true
fi
xvfb-run -a -s "-screen 0 1920x1200x24" "$GODOT" --rendering-driver opengl3 --path "$ROOT/tools/artpreview" \
  -s EnemyLineup.gd -- "$ROOT/assets" "$OUT" 2>&1 \
  | grep -E "^\[lineup\]|SCRIPT ERROR|ERROR: Node" || true
