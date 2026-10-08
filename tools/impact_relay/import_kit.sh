#!/bin/sh
# THE IMPACT RELAY'S CANDIDATE ART, for the G1 review build.
#
#   tools/impact_relay/import_kit.sh [path/to/godot]
#
# Arty's Batch 065 is a CANDIDATE kit fitted to the G0 plate and shutter
# (art branch claude/archipepsi-art-bloom-g1-2026-10-08, kit commit
# eb5516c0, delivery head be673117; handoff
# docs/art/reports/2026-10-08-bloom-noise-and-impact-relay-g1.md):
# ir_object_launcher, ir_impact_seal and ir_seal_jamb, with the kit's
# manifest.json in assets/models/batch065/impact_relay/ (byte for byte as
# committed there; its builder, tools/blender/build_impact_relay.py,
# stays on the art branch with the Batch 064 helpers it imports). Arty made
# no tote or weight, so the weight wears an existing piece of her Batch 043
# physics family (assets/models/batch043/physics/): phys_power_cell, a
# MEDIUM carriable that fits inside the weight's unchanged box. The tote
# keeps its placeholder.
#
# They are copied into
#   godot/candidate/impact_relay/
# which is a GENERATED ARTIFACT, as godot/candidate/crossing_kit/ is: the
# copies, Godot's import sidecars and the textures its importer extracts.
# Nothing in it is edited by hand, and it stays out of godot/content/,
# which holds approved art only.
set -e
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
GODOT=${1:-$ROOT/godot-bin/godot}
[ -x "$GODOT" ] || { echo "import_kit: no godot at $GODOT" >&2; exit 2; }
DST=$ROOT/godot/candidate/impact_relay
PIECES="batch065/impact_relay/ir_object_launcher batch065/impact_relay/ir_impact_seal
batch065/impact_relay/ir_seal_jamb batch043/physics/phys_power_cell"
mkdir -p "$DST"
names=""
for p in $PIECES; do names="$names $(basename "$p")"; done
# The list is the list: drop any other piece (and what its import made).
for f in "$DST"/*.glb; do
	[ -e "$f" ] || continue
	n=$(basename "$f" .glb)
	case " $names " in
	*" $n "*) ;;
	*) rm -f "$f" "$f.import" "$DST/${n}_"*.png "$DST/${n}_"*.png.import ;;
	esac
done
for p in $PIECES; do
	cp "$ROOT/assets/models/$p.glb" "$DST/$(basename "$p").glb"
done
"$GODOT" --headless --path "$ROOT/godot" --import >/dev/null 2>&1 || true
for n in $names; do
	[ -f "$DST/$n.glb.import" ] || {
		echo "import_kit: $n.glb was not imported" >&2
		exit 1
	}
	cmp -s "$DST/$n.glb" "$(find "$ROOT/assets/models" -name "$n.glb" | head -1)" || {
		echo "import_kit: $n.glb differs from its source" >&2
		exit 1
	}
done
echo "import_kit: $names imported into godot/candidate/impact_relay/"
