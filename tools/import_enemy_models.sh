#!/usr/bin/env sh
# Ship the art lane's approved enemy family to the game (ART-CATCHUP).
#
#   tools/import_enemy_models.sh
#
#   assets/models/batch030/enemies/*.glb       -> godot/content/enemies/standard/
#   assets/models/batch030/enemies_deep/*.glb  -> godot/content/enemies/deep/
#   assets/models/batch030/enemy_value_bands.json -> godot/content/enemies/
#
# The ten roles in their two value bands (Tier 1, RULED 2026-09-26) and the
# re-cut ranged and bulwark (Tier 2, ACCEPTED 2026-09-26). Byte for byte:
# the art lane's check_enemy_bands.py ties its measured contrast to each
# model's sha256, so a copied model is the model that was measured.
# The band map is data (`enemy_value_bands.json`), read at run time, never
# restated. Godot's own importer then writes the sidecars.
#
# Everything under godot/content/enemies/ is a GENERATED ARTIFACT.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$ROOT/godot-bin/godot}"
[ -x "$GODOT" ] || { echo "import_enemy_models: no godot at $GODOT" >&2; exit 2; }
SRC="$ROOT/assets/models/batch030"
DST="$ROOT/godot/content/enemies"
for band in standard deep; do
  from="$SRC/enemies"; [ "$band" = deep ] && from="$SRC/enemies_deep"
  mkdir -p "$DST/$band"
  # A role the band no longer has leaves with its sidecar.
  for f in "$DST/$band"/*.glb; do
    [ -e "$f" ] || continue
    [ -f "$from/$(basename "$f")" ] || rm -f "$f" "$f.import"
  done
  cp "$from"/enemy_role_*.glb "$DST/$band/"
done
cp "$SRC/enemy_value_bands.json" "$DST/enemy_value_bands.json"
log="$(mktemp)"
xvfb-run -a timeout 600 "$GODOT" --headless --path "$ROOT/godot" --import >"$log" 2>&1 || true
grep -E "SCRIPT ERROR|Failed to load|ERROR: .*glb" "$log" | head -5 || true
rm -f "$log"
echo "import_enemy_models: $(ls "$DST"/standard/*.glb | wc -l) standard, $(ls "$DST"/deep/*.glb | wc -l) deep"
