#!/usr/bin/env bash
# A13 -- the Batch 043 status kit against the runtime that exists.
#
# Production's constants AND their apply() guards are fetched read-only
# from the 0.4 branch. Nothing here edits, imports or binds anything of
# theirs; the harness reads their rules and applies them to Art's kit.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
PROD="${PROD_04_REF:-origin/claude/archipepsi-0-4-blindside}"
KIT="${1:-$ROOT/docs/art/review/status_2026-09-11}"
OUT="${2:-$ROOT/docs/art/review/status_readiness_2026-09-22}"
H="$ROOT/godot/_harness"
[ -x "$GODOT" ] || { echo "no godot at $GODOT" >&2; exit 2; }
# shellcheck source=godot_run.sh
. "$ROOT/tools/content/godot_run.sh"
mkdir -p "$OUT"
cleanup() { rm -rf "$H"; }
trap cleanup EXIT
cleanup; mkdir -p "$H"
git -C "$ROOT" show "$PROD:godot/scripts/autoload/constants.gd" \
  | sed 's/^class_name .*$//' > "$H/prod_constants.gd"
git -C "$ROOT" show "$PROD:godot/scripts/gameplay/status_effects.gd" \
  | sed 's/^class_name .*$//' > "$H/prod_status_effects.gd"
cp "$ROOT/tools/content/status_readiness.gd" "$H/statusready.gd"
run_godot statusready _harness/statusready.gd "$KIT" "$OUT/readiness.json"
