#!/usr/bin/env sh
# Ship the art lane's approved ways-out and Echo Lab models (ART-CATCHUP).
#
#   tools/import_play_fixtures.sh
#
#   assets/models/batch002/portal/portal_b2_wound.glb      -> godot/content/ways_out/
#   assets/models/batch006/portal/portal_core_*.glb        -> godot/content/ways_out/
#   assets/models/batch004/lab/<the wired fixtures>.glb    -> godot/content/lab/
#   assets/models/batch009/affordance/<the wired three>.glb -> godot/content/affordances/
#
# The portal frame (002, PASS "locked as the portal DNA"), its two cores
# (006, PASS 28 Aug) and the Echo Lab's fixtures (004, PASS 28 Aug). Byte
# for byte; Godot's importer writes the sidecars. Only what the game WIRES
# is shipped: the moving target and the reset pad are shorter than the
# colliders players already use, so they wait for a fit decision; the
# notice board has no wall to hang on where the Lab's notice appears. Of
# the affordances (009, PASS 28 Aug) the breakable panel, bounce pad and
# wind ring fit their colliders; the moving-platform deck and wind perch
# are taller than theirs, the rail beam differs from the code rail and
# the water basin marks a different place, so those four wait.
# Everything under godot/content/{ways_out,lab,affordances}/ is a GENERATED ARTIFACT.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$ROOT/godot-bin/godot}"
[ -x "$GODOT" ] || { echo "import_play_fixtures: no godot at $GODOT" >&2; exit 2; }
WAYS="$ROOT/godot/content/ways_out"
AFF="$ROOT/godot/content/affordances"
LAB="$ROOT/godot/content/lab"
rm -rf "$WAYS" "$LAB" "$AFF"
mkdir -p "$WAYS" "$LAB" "$AFF"
cp "$ROOT/assets/models/batch002/portal/portal_b2_wound.glb" "$WAYS/"
cp "$ROOT"/assets/models/batch006/portal/portal_core_*.glb "$WAYS/"
for m in dummy hazard height_markers runway_measure; do
	cp "$ROOT/assets/models/batch004/lab/lab_$m.glb" "$LAB/"
done
for m in breakwall_panel bounce_pad wind_ring; do
	cp "$ROOT/assets/models/batch009/affordance/$m.glb" "$AFF/"
done
log="$(mktemp)"
xvfb-run -a timeout 600 "$GODOT" --headless --path "$ROOT/godot" --import >"$log" 2>&1 || true
grep -E "SCRIPT ERROR|Failed to load" "$log" | head -5 || true
rm -f "$log"
echo "import_play_fixtures: $(ls "$WAYS"/*.glb "$LAB"/*.glb "$AFF"/*.glb | wc -l) model(s)"
