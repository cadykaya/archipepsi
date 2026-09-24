#!/usr/bin/env bash
# A14 -- Batch 043's twelve physics props against the envelope that would
# have to move them.
#
# Production's constants, their MassClass ladder, their ManipulableBody
# friction derivation and their project's gravity are all fetched
# read-only. Nothing of theirs is edited, imported or bound.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
PROD="${PROD_04_REF:-origin/claude/archipepsi-0-4-blindside}"
OUT="${1:-$ROOT/docs/art/review/manipulation_2026-09-22}"
H="$ROOT/godot/_harness"
[ -x "$GODOT" ] || { echo "no godot at $GODOT" >&2; exit 2; }
# shellcheck source=godot_run.sh
. "$ROOT/tools/content/godot_run.sh"
mkdir -p "$OUT"
cleanup() { rm -rf "$H"; }
trap cleanup EXIT
cleanup; mkdir -p "$H"

# `MassClass.read` takes a `StatusEffects`. Pulling the real one in drags
# `Constants.ECHO_STATUS_*` and `BridgeClient` behind it, and this harness
# does not need a status system -- `read()` asks a container exactly two
# questions and this answers those. It is bound under a name that says it
# is NOT StatusEffects, so nothing here can quietly become a second
# status implementation.
cat > "$H/one_status.gd" <<'GD'
extends RefCounted
## Not StatusEffects. One status, answering the one question
## `MassClass.read` asks of a container.
var kind := ""
func has(what: String) -> bool:
	return what == kind
GD

# The type is RENAMED before it is bound. This project registers its own
# `StatusEffects` as a global class -- an older copy, from before the
# vocabulary grew -- and a `const` cannot shadow a global class name, so
# binding the stub under that name silently resolved to the wrong thing.
# `_ONE_STATUS` cannot collide, and it says what it is.
# AND `Constants.` TOO, since 2026-09-24. The mass ladder used to be
# three literals in this file; Production moved the values into the
# generated `Constants` and left `mass_class.gd` delegating to them. A
# file that references a global this project does not register fails to
# COMPILE, and a failed compile here is silent in a useful-looking way:
# `load()` returns a GDScript, `of_mass` is simply not on it, and the
# harness reports "Nonexistent function". Binding it to the preloaded
# copy is the same move already made for `StatusEffects` below, for the
# same reason.
git -C "$ROOT" show "$PROD:godot/scripts/autoload/constants.gd" \
  | sed 's/^class_name .*$//' > "$H/prod_constants.gd"
# The SAME file again, verbatim and never parsed. The rewritten copy
# above is what RUNS; this is what the contract is READ from. Asserting
# the delegation against the rewritten copy would be asserting against
# this harness's own sed -- it would pass whatever Production did, which
# is the exact shape of a check that cannot fail.
git -C "$ROOT" show "$PROD:godot/scripts/gameplay/mass_class.gd" \
  > "$H/prod_mass_class_verbatim.gd"
git -C "$ROOT" show "$PROD:godot/scripts/gameplay/mass_class.gd" \
  | sed 's/^class_name MassClass$//; s/\bStatusEffects\b/_ONE_STATUS/g; s/\bConstants\./_PROD_CONST./g' \
  > "$H/prod_mass_class.gd"
python3 - "$H/prod_mass_class.gd" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
s = p.read_text()
lines = s.split("\n")
at = next(i for i, l in enumerate(lines) if l.startswith("extends ")) + 1
# `StatusEffects` appears ONLY as the type of `read()`'s third argument.
# Binding the name to the one-question stub is the single mechanical
# edit; the ladder, the thresholds and every branch of `read()` are
# theirs, unaltered, and the harness verifies the thresholds are still
# the ones it thinks it is reading.
lines[at:at] = ['const _ONE_STATUS := preload('
                '"res://_harness/one_status.gd")',
                'const _PROD_CONST := preload('
                '"res://_harness/prod_constants.gd")']
p.write_text("\n".join(lines))
PY

# Fetched VERBATIM and never parsed: the harness reads two things out of
# it as TEXT -- the friction derivation and FRICTION_HEADROOM's own
# declaration -- and parsing it would drag MassClass, StatusEffects and
# a RigidBody3D in for the sake of one number.
git -C "$ROOT" show "$PROD:godot/scripts/gameplay/manipulable_body.gd" \
  > "$H/prod_manipulable_body.gd"

git -C "$ROOT" show "$PROD:godot/project.godot" > "$H/prod_project"
cp "$ROOT/tools/content/manipulation_readiness.gd" "$H/manipready.gd"
run_godot manipready _harness/manipready.gd "$ROOT/assets/models" \
  "$OUT/manipulation.json"
