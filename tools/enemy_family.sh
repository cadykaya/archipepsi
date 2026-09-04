#!/usr/bin/env sh
# Batch 002 D -- the whole roster in one frame at aggro range.
#
#   tools/enemy_family.sh [out_dir]
#
# Ten roles, two ranks of five, both at ENEMY_AGGRO_RADIUS. See
# tools/artpreview/EnemyFamily.gd for why it is two ranks and not one.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
OUT="${1:-$ROOT/docs/art/review/batch002}"
# Godot's cwd is not the repo root, so a relative out-dir writes the captures
# somewhere nobody looks -- and save_png reports no error either way.
case "$OUT" in /*) ;; *) OUT="$ROOT/$OUT" ;; esac
[ -x "$GODOT" ] || { echo "enemy_family: no godot at $GODOT" >&2; exit 2; }
if [ ! -f "$ROOT/tools/artpreview/.godot/global_script_class_cache.cfg" ]; then
  "$GODOT" --headless --path "$ROOT/tools/artpreview" --import >/dev/null 2>&1 || true
fi
# --headless selects the dummy driver and never presents a frame, so an
# awaited SubViewport capture hangs forever. xvfb + opengl3 is the only
# combination that renders here.
xvfb-run -a -s "-screen 0 1920x1200x24" "$GODOT" --rendering-driver opengl3 \
  --path "$ROOT/tools/artpreview" -s EnemyFamily.gd -- "$ROOT/assets" "$OUT" 2>&1 \
  | grep -E "^\[family\]|SCRIPT ERROR|ERROR: Node" || true
