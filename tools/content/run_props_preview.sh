#!/usr/bin/env bash
# Render the physics-prop candidates into a directory.
#
#   tools/content/run_status_preview.sh <out-dir>
#
# The harness is a THROWAWAY directory inside the Godot project. Nothing from
# it is committed and it is removed on exit, so the project on disk is the
# project the game ships with before and after this runs.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
OUT="${1:-$ROOT/docs/art/review/props_2026-09-11/room}"
H="$ROOT/godot/_harness"
[ -x "$GODOT" ] || { echo "no godot at $GODOT" >&2; exit 2; }
# shellcheck source=godot_run.sh
. "$ROOT/tools/content/godot_run.sh"
mkdir -p "$OUT"
cleanup() { rm -rf "$H"; }
trap cleanup EXIT
cleanup; mkdir -p "$H"
cp "$ROOT/tools/content/props_preview.gd" "$H/props.gd"
# `class_name` is stripped for the same reason the content verifier strips
# it: Godot does not register a global class for a script dropped into the
# project between runs, so the bench is preloaded by path instead.
sed 's/^class_name ArtBench$//' "$ROOT/tools/artpreview/artbench.gd" > "$H/artbench.gd"
# Compatibility renderer, with a real GL context. --headless gives the dummy
# driver and every capture comes back black.
run_godot props _harness/props.gd \
  "$ROOT/assets/models" \
  "$ROOT/docs/art/review/derelict_2026-09-10" \
  "$OUT" "${LABELS:-labels}"
