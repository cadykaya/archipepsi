#!/usr/bin/env sh
# Ship the art lane's approved Hub fixtures to the game (ART-CATCHUP).
#
#   tools/import_hub_fixtures.sh
#
#   assets/models/batch002/epsilon/epsilon_installation.glb -> godot/content/hub/
#   assets/models/batch003/hub/hub_{campaign,controls}_board.glb -> ditto
#
# The Epsilon installation (batch 002, the Style Lock centrepiece) and the
# Hub's fixtures (batch 003), PASS 28 Aug. Byte for byte; Godot's importer
# writes the sidecars. Only what the Hub WIRES is shipped: the shop,
# archive and abandon models are 2.45 m cabinets against 1.1 m counters
# whose interaction volumes and labels the game relies on, so they wait
# for a fit decision instead of riding along unused. Everything under godot/content/hub/ is a GENERATED
# ARTIFACT.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$ROOT/godot-bin/godot}"
[ -x "$GODOT" ] || { echo "import_hub_fixtures: no godot at $GODOT" >&2; exit 2; }
DST="$ROOT/godot/content/hub"
rm -rf "$DST"
mkdir -p "$DST"
cp "$ROOT/assets/models/batch002/epsilon/epsilon_installation.glb" "$DST/"
for b in campaign controls; do
	cp "$ROOT/assets/models/batch003/hub/hub_${b}_board.glb" "$DST/"
done
log="$(mktemp)"
xvfb-run -a timeout 600 "$GODOT" --headless --path "$ROOT/godot" --import >"$log" 2>&1 || true
grep -E "SCRIPT ERROR|Failed to load" "$log" | head -5 || true
rm -f "$log"
echo "import_hub_fixtures: $(ls "$DST"/*.glb | wc -l) model(s)"
