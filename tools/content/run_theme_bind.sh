#!/usr/bin/env bash
# Prove the exported theme pack binds authored pixels -- and keep the two
# controls that say what happens when it cannot.
#
# The controls move a real file aside and put it back. That is on purpose:
# a control that simulates absence tests the simulation. The restore runs
# from a trap, so an interrupt still puts the pack back, and the script
# refuses to finish until it has checked that it did.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
OUT="${1:-$ROOT/docs/art/review/theme_bind_2026-09-13}"
H="$ROOT/godot/_harness"
PACK="$ROOT/godot/content/theme"
ASIDE="$(mktemp -d)"
[ -x "$GODOT" ] || { echo "no godot at $GODOT" >&2; exit 2; }
# shellcheck source=godot_run.sh
. "$ROOT/tools/content/godot_run.sh"
mkdir -p "$OUT"

restore() {
  for f in "$ASIDE"/*.png; do
    [ -e "$f" ] || continue
    mv -f "$f" "$PACK/$(basename "$f")"
  done
  rm -rf "$ASIDE" "$H"
}
trap restore EXIT
rm -rf "$H"; mkdir -p "$H"
cp "$ROOT/tools/content/theme_binder.gd" "$H/themebinder.gd"
cp "$ROOT/tools/content/theme_bind_proof.gd" "$H/bindproof.gd"

# res://, and the ROOT the descriptor's rows hang off: a row reads
# "theme/<name>.png", so content/theme/ here would double the folder.
CONTENT="res://content"
run_godot bind-whole _harness/bindproof.gd \
  "$CONTENT" "$OUT/binding_whole.json" whole

# Control 1: a REQUIRED authored texture is gone.
mv "$PACK/concrete_facility_floor.png" "$ASIDE/"
run_godot bind-missing-required _harness/bindproof.gd \
  "$CONTENT" "$OUT/control_missing_required.json" missing_required
mv "$ASIDE/concrete_facility_floor.png" "$PACK/"

# Control 2: the file is THERE and is the wrong pixels. Another theme's
# wall, which loads perfectly well and is not what the descriptor hashed.
mv "$PACK/concrete_facility_wall.png" "$ASIDE/"
cp "$PACK/gothic_stone_wall.png" "$PACK/concrete_facility_wall.png"
run_godot bind-mismatched _harness/bindproof.gd \
  "$CONTENT" "$OUT/control_mismatched_digest.json" mismatched_digest
rm -f "$PACK/concrete_facility_wall.png"
mv "$ASIDE/concrete_facility_wall.png" "$PACK/"

# Control 3: an OPTIONAL authored texture is gone.
mv "$PACK/concrete_facility_ceiling.png" "$ASIDE/"
run_godot bind-missing-optional _harness/bindproof.gd \
  "$CONTENT" "$OUT/control_missing_optional.json" missing_optional
mv "$ASIDE/concrete_facility_ceiling.png" "$PACK/"

# The pack must be whole again before this script is allowed to succeed.
python3 "$ROOT/tools/content/verify_theme_export.py" >/dev/null || {
  echo "theme-bind: FAIL -- the pack was not restored after the controls" >&2
  exit 1
}
echo "theme-bind: PASS -- the whole pack binds, and all three controls behave"
