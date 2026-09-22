#!/usr/bin/env bash
# The course candidate in engine, beside the shipped set, same scale.
#
# Reads assets/textures/theme/ and assets/textures/theme_candidate/ at run
# time. Writes only captures. Nothing is imported and nothing is bound at
# runtime -- this is the isolated review scene, not a selection.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
OUT="${1:-$ROOT/docs/art/review/course_candidate_2026-09-22}"
H="$ROOT/godot/_harness"
[ -x "$GODOT" ] || { echo "no godot at $GODOT" >&2; exit 2; }
[ -d "$ROOT/assets/textures/theme_candidate" ] || {
  echo "no candidate set -- run build_theme_candidate.py first" >&2; exit 2; }
# shellcheck source=godot_run.sh
. "$ROOT/tools/content/godot_run.sh"
mkdir -p "$OUT"
cleanup() { rm -rf "$H"; }
trap cleanup EXIT
cleanup; mkdir -p "$H"
cp "$ROOT/tools/content/course_candidate_view.gd" "$H/coursecand.gd"
run_godot cand _harness/coursecand.gd "$ROOT/assets" "$OUT"
echo "course-candidate: wrote $(ls "$OUT"/*.png | wc -l) captures to $OUT"
