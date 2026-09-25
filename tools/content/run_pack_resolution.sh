#!/usr/bin/env bash
# Track D -- the packs' rows through Production's own ThemePack resolver.
#
#   tools/content/run_pack_resolution.sh [out.json]
#
# Production's resolver and their constants are fetched READ-ONLY from
# their branch and staged; nothing of theirs is edited, vendored or
# committed here. The art lane does not get to hold its own opinion of
# how a pack resolves.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
PROD="${PROD_04_REF:-origin/claude/archipepsi-0-4-blindside}"
OUT="${1:-}"
H="$ROOT/godot/_harness"
[ -x "$GODOT" ] || { echo "no godot at $GODOT" >&2; exit 2; }
# shellcheck source=godot_run.sh
. "$ROOT/tools/content/godot_run.sh"
cleanup() { rm -rf "$H"; }
trap cleanup EXIT
cleanup; mkdir -p "$H"

# `Constants` is a global this project does not register, and a file
# referencing one fails to COMPILE while `load()` still hands back a
# GDScript -- the fault then reads as "nonexistent function", which is
# how an afternoon goes missing. Bound to a preloaded copy instead, the
# same move run_manipulation_readiness.sh already makes.
git -C "$ROOT" show "$PROD:godot/scripts/autoload/constants.gd" \
  | sed 's/^class_name .*$//' > "$H/prod_constants.gd"
git -C "$ROOT" show "$PROD:godot/scripts/generation/theme_pack.gd" \
  | sed 's/^class_name ThemePack$//; s/\bConstants\./_PROD_CONST./g' \
  > "$H/prod_theme_pack.gd"
python3 - "$H/prod_theme_pack.gd" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
lines = p.read_text().split("\n")
at = next(i for i, l in enumerate(lines) if l.startswith("extends ")) + 1
lines[at:at] = ['const _PROD_CONST := preload('
                '"res://_harness/prod_constants.gd")']
p.write_text("\n".join(lines))
PY
grep -q "_PROD_CONST\." "$H/prod_theme_pack.gd" || {
  echo "run_pack_resolution: the Constants rewrite matched nothing, so the
  staged resolver is not the one this runner thinks it staged" >&2; exit 1; }

cp "$ROOT/tools/content/pack_resolution.gd" "$H/pack_resolution.gd"
run_godot packres _harness/pack_resolution.gd ${OUT:+"$OUT"}
