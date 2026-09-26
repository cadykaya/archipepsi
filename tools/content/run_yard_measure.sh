#!/usr/bin/env bash
# Measure the Blindside yard with Production's own RailPath.
#
# The constants come out of `railway_scenario.gd` by grep, not by being
# retyped here: a number art restates is a number that can drift without
# anyone noticing. The curve itself cannot be restated at all -- three of
# the five control points sit on a Catmull-Rom corner -- so their
# `RailPath` is fetched read-only and evaluated.
#
# Writes `assets/models/batch046/yard_fit.json`, which
# `tools/blender/build_yardkit.py` reads. Committed, so the rebuild gate
# in check_art_current.sh can prove the art came from it.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
PROD="${PROD_04_REF:-origin/claude/archipepsi-0-4-blindside}"
OUT="${1:-$ROOT/assets/models/batch046/yard_fit.json}"
H="$ROOT/godot/_harness"
[ -x "$GODOT" ] || { echo "no godot at $GODOT" >&2; exit 2; }
# shellcheck source=godot_run.sh
. "$ROOT/tools/content/godot_run.sh"
mkdir -p "$(dirname "$OUT")"
cleanup() { rm -rf "$H"; }
trap cleanup EXIT
cleanup; mkdir -p "$H"

# `RoomContract` is reached ONLY from `RailPath.violations()`, which
# this measurement never calls -- but GDScript parses the whole file, so
# the name has to resolve. Pulling the real one in drags ChamberBuilders
# and the whole material stack behind it, so it is bound to a stub that
# REFUSES instead: if anything here ever does call `violations()`, the
# run fails loudly rather than measuring against a fake envelope.
cat > "$H/refuses.gd" <<'GD'
extends RefCounted
## Not RoomContract. Deliberately.
static func envelope(_bounds: AABB) -> AABB:
	push_error("yard_measure called RailPath.violations(), which needs "
		+ "the real RoomContract. This harness is a ruler, not a "
		+ "validator -- it must not answer that question with a stub.")
	# The signature matches so the file still parses; the push_error
	# above is what makes the run fail, and this value is never used
	# because the runner stops on it.
	return AABB()
GD

git -C "$ROOT" show "$PROD:godot/scripts/gameplay/rail_path.gd" \
  | sed 's/^class_name RailPath$//; s/\bRailPath\b/RailPathSelf/g' \
  > "$H/prod_rail_path.gd"
# `from_points` is a static factory that names its own class, and
# stripping `class_name` leaves that name unbound. Rebinding it to the
# script's own `self` reference is the one mechanical edit.
python3 - "$H/prod_rail_path.gd" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
s = p.read_text()
s = s.replace("RoomContract.", "_REFUSES.")
lines = s.split("\n")
at = next(i for i, l in enumerate(lines) if l.startswith("extends ")) + 1
lines[at:at] = ['const RailPathSelf := preload('
                '"res://_harness/prod_rail_path.gd")',
                'const _REFUSES := preload("res://_harness/refuses.gd")']
p.write_text("\n".join(lines))
PY

# The scenario's constants, read from the scenario. A name this grep
# cannot find becomes a missing key, and the harness refuses rather than
# quietly substituting a default.
git -C "$ROOT" show "$PROD:godot/scripts/content/railway_scenario.gd" \
  | python3 -c '
import json, re, sys
src = sys.stdin.read()
out = {}
for name, body in re.findall(r"^const ([A-Z_0-9]+) := (.+)$", src, re.M):
    body = body.split("#")[0].strip()
    m = re.fullmatch(r"Vector3\(([^)]*)\)", body)
    if m:
        out[name] = [float(x) for x in m.group(1).split(",")]
        continue
    m = re.fullmatch(r"Vector2\(([^)]*)\)", body)
    if m:
        out[name] = [float(x) for x in m.group(1).split(",")]
        continue
    try:
        out[name] = float(body)
    except ValueError:
        pass
json.dump(out, sys.stdout, indent=1, sort_keys=True)
' > "$H/scenario_constants.json"

cp "$ROOT/tools/content/yard_measure.gd" "$H/yardmeasure.gd"
run_godot yard _harness/yardmeasure.gd \
  "$ROOT/godot/_harness/scenario_constants.json" "$OUT"
echo "[yard] wrote $OUT"
