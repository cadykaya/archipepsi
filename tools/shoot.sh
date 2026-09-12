#!/usr/bin/env sh
# The shot runner. A JSON shot list in, a folder of PNGs out.
#
#   tools/shoot.sh <shotlist.json> [out_dir]
#
# Shot lists live in tools/shots/. See tools/artpreview/shoot.gd for the
# schema and tools/artpreview/camera_rig.gd for what the camera can do.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
LIST="${1:?usage: tools/shoot.sh <shotlist.json> [out_dir]}"
case "$LIST" in /*) ;; *) LIST="$ROOT/$LIST" ;; esac
[ -f "$LIST" ] || { echo "shoot: no such shot list: $LIST" >&2; exit 2; }
OUT="${2:-$ROOT/docs/art/review/shots}"
case "$OUT" in /*) ;; *) OUT="$ROOT/$OUT" ;; esac
[ -x "$GODOT" ] || { echo "shoot: no godot at $GODOT (set GODOT=...)" >&2; exit 2; }
# A `class_name` script is invisible until an import pass writes the class
# cache, and `-s` does not rescan. camera_rig.gd and hub_scene.gd are both
# class_name scripts, so this is not optional after adding either.
"$GODOT" --headless --path "$ROOT/tools/artpreview" --import >/dev/null 2>&1 || true
# --headless cannot RENDER: it selects the dummy driver and an awaited
# SubViewport capture hangs forever with no output.
xvfb-run -a -s "-screen 0 1920x1200x24" "$GODOT" --rendering-driver opengl3 \
  --path "$ROOT/tools/artpreview" -s shoot.gd -- "$ROOT/assets" "$OUT" "$LIST" 2>&1 \
  | grep -E "^\[shoot\]|SCRIPT ERROR|ERROR: Node|Parse Error" || true
