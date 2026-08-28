#!/usr/bin/env sh
# The Archipepsi asset review sheet. One command, eight shots, identical for
# every asset -- see tools/artpreview/ReviewSheet.gd for what each shot is
# for and why the sheet is deliberately not allowed to grow.
#
#   tools/review_sheet.sh <model.glb, repo-relative> <out.png> <label> [dist_m]
#
# `dist_m` is the distance the asset is genuinely judged at, and omitting it
# omits the shot that matters most. The distances are not free choices:
#   enemy            18   ENEMY_AGGRO_RADIUS -- where you first see one
#   Check / portal   30   the longest corridor zone.py permits
#   Epsilon          6    a Hub conversation distance
#   prop / module    3    walking past it
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
MODEL="$1"; OUT="$2"; LABEL="$3"; DIST="${4:-0}"

if [ -z "$MODEL" ] || [ -z "$OUT" ] || [ -z "$LABEL" ]; then
  echo "usage: tools/review_sheet.sh <model.glb> <out.png> <label> [dist_m]" >&2
  exit 2
fi
[ -x "$GODOT" ] || { echo "review_sheet: no godot at $GODOT (set GODOT=...)" >&2; exit 2; }

case "$MODEL" in /*) ABS="$MODEL" ;; *) ABS="$ROOT/$MODEL" ;; esac
case "$OUT" in /*) ABSOUT="$OUT" ;; *) ABSOUT="$ROOT/$OUT" ;; esac
[ -f "$ABS" ] || { echo "review_sheet: no such model: $ABS" >&2; exit 1; }

# A `class_name` script is invisible until an import pass writes
# .godot/global_script_class_cache.cfg -- a `-s` run does NOT rescan, so
# without this every reference to ArtBench is "Identifier not declared in the
# current scope" for a file that is plainly there. Cheap after the first run.
if [ ! -f "$ROOT/tools/artpreview/.godot/global_script_class_cache.cfg" ]; then
  "$GODOT" --headless --path "$ROOT/tools/artpreview" --import >/dev/null 2>&1 || true
fi

# --headless is NOT usable for the RENDER: it selects the dummy rendering driver, which
# never presents a frame, so an awaited SubViewport capture hangs forever
# with no output at all. xvfb + opengl3 is the only combination that renders
# in this sandbox, and it means every capture is a Compatibility-renderer
# LOWER BOUND on the owner's Forward+ build.
xvfb-run -a "$GODOT" --rendering-driver opengl3 --path "$ROOT/tools/artpreview" \
  -s ReviewSheet.gd -- "$ABS" "$ABSOUT" "$LABEL" "$DIST" 2>&1 \
  | grep -E "^\[sheet\]|ERROR|SCRIPT ERROR" || true

[ -f "$ABSOUT" ] || { echo "review_sheet: FAILED, no sheet written: $ABSOUT" >&2; exit 1; }
