#!/usr/bin/env sh
# Batch 003 -- the Hub, built out of authored assets.
#
#   tools/hub_room.sh [out_dir]
#
# Every dimension and fixture position is read out of godot/scripts/hub/hub.gd.
# See tools/artpreview/HubRoom.gd for the one position that is a proposal.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
OUT="${1:-$ROOT/docs/art/review/batch003}"
case "$OUT" in /*) ;; *) OUT="$ROOT/$OUT" ;; esac
[ -x "$GODOT" ] || { echo "hub_room: no godot at $GODOT" >&2; exit 2; }
if [ ! -f "$ROOT/tools/artpreview/.godot/global_script_class_cache.cfg" ]; then
  "$GODOT" --headless --path "$ROOT/tools/artpreview" --import >/dev/null 2>&1 || true
fi
xvfb-run -a -s "-screen 0 1920x1200x24" "$GODOT" --rendering-driver opengl3 \
  --path "$ROOT/tools/artpreview" -s HubRoom.gd -- "$ROOT/assets" "$OUT" 2>&1 \
  | grep -E "^\[hub\]|SCRIPT ERROR|ERROR: Node" || true
