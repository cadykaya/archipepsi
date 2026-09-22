#!/usr/bin/env bash
# A03.5 -- the loaded skiff's swept visual envelope, over the whole route.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
PROD="${PROD_04_REF:-origin/claude/archipepsi-0-4-blindside}"
OUT="${1:-$ROOT/docs/art/review/skiffkit_2026-09-22}"
H="$ROOT/godot/_harness"
[ -x "$GODOT" ] || { echo "no godot at $GODOT" >&2; exit 2; }
# shellcheck source=godot_run.sh
. "$ROOT/tools/content/godot_run.sh"
mkdir -p "$OUT"
cleanup() { rm -rf "$H"; }
trap cleanup EXIT
cleanup; mkdir -p "$H"

cat > "$H/refuses.gd" <<'GD'
extends RefCounted
## Not RoomContract. Deliberately -- see run_yard_measure.sh.
static func envelope(_bounds: AABB) -> AABB:
	push_error("skiff_sweep called RailPath.violations(), which needs "
		+ "the real RoomContract. This harness measures; it does not "
		+ "validate, and must not answer that with a stub.")
	return AABB()
GD

git -C "$ROOT" show "$PROD:godot/scripts/gameplay/rail_path.gd" \
  | sed 's/^class_name RailPath$//; s/\bRailPath\b/RailPathSelf/g' \
  > "$H/prod_rail_path.gd"
python3 - "$H/prod_rail_path.gd" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
s = p.read_text().replace("RoomContract.", "_REFUSES.")
lines = s.split("\n")
at = next(i for i, l in enumerate(lines) if l.startswith("extends ")) + 1
lines[at:at] = ['const RailPathSelf := preload('
                '"res://_harness/prod_rail_path.gd")',
                'const _REFUSES := preload("res://_harness/refuses.gd")']
p.write_text("\n".join(lines))
PY

cp "$ROOT/tools/content/skiff_sweep.gd" "$H/sweep.gd"
run_godot sweep _harness/sweep.gd "$ROOT/assets/models" "$OUT/sweep.json"
