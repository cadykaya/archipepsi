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
git -C "$ROOT" show "$PROD:godot/scripts/gameplay/mass_class.gd" \
  | sed 's/^class_name MassClass$//; s/\bStatusEffects\b/_ONE_STATUS/g' \
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
                '"res://_harness/one_status.gd")']
p.write_text("\n".join(lines))
PY

# Fetched VERBATIM and never parsed: the harness reads two things out of
# it as TEXT -- the friction derivation and FRICTION_HEADROOM's own
# declaration -- and parsing it would drag MassClass, StatusEffects and
# a RigidBody3D in for the sake of one number.
git -C "$ROOT" show "$PROD:godot/scripts/gameplay/manipulable_body.gd" \
  > "$H/prod_manipulable_body.gd"

git -C "$ROOT" show "$PROD:godot/scripts/autoload/constants.gd" \
  | sed 's/^class_name .*$//' > "$H/prod_constants.gd"
git -C "$ROOT" show "$PROD:godot/project.godot" > "$H/prod_project"
cp "$ROOT/tools/content/manipulation_readiness.gd" "$H/manipready.gd"
run_godot manipready _harness/manipready.gd "$ROOT/assets/models" \
  "$OUT/manipulation.json"
