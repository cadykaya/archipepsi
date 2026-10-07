#!/bin/sh
# THE CANDIDATE CROSSING KIT, for Crossing D's readability review build.
#
#   tools/crossing_d/import_kit.sh [path/to/godot]
#
# Arty's Batch 063 crossing kit is a PROPOSAL: review pending, not in the
# content pack (art branch claude/archipepsi-art-crossing-kit-2026-10-02,
# commit eb8fceda; handoff docs/art/reports/2026-10-02-crossing-readability-kit.md).
# This build trials five of its pieces -- the floor lever and the power
# raceway's run, turn, inside corner and terminal -- in place of D's own
# lever and power lines. They come byte for byte from
#
#   assets/models/batch063/crossing_kit/   (as committed at eb8fceda, with
#                                           the kit's manifest.json)
# into
#   godot/candidate/crossing_kit/
#
# which is a GENERATED ARTIFACT: the copies, Godot's import sidecars and
# the textures its importer extracts. Nothing in it is edited by hand. It
# sits outside godot/content/ on purpose: that tree holds approved art
# only and the content pack regenerates it whole.
set -e
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
GODOT=${1:-$ROOT/godot-bin/godot}
[ -x "$GODOT" ] || { echo "import_kit: no godot at $GODOT" >&2; exit 2; }
SRC=$ROOT/assets/models/batch063/crossing_kit
DST=$ROOT/godot/candidate/crossing_kit
PIECES="ck_floor_lever ck_raceway_run ck_raceway_turn ck_raceway_inside ck_raceway_terminal"
mkdir -p "$DST"
# The list is the list: drop any other piece (and what its import made).
for f in "$DST"/*.glb; do
	[ -e "$f" ] || continue
	n=$(basename "$f" .glb)
	case " $PIECES " in
	*" $n "*) ;;
	*) rm -f "$f" "$f.import" "$DST/${n}_"*.png "$DST/${n}_"*.png.import ;;
	esac
done
for n in $PIECES; do
	cp "$SRC/$n.glb" "$DST/$n.glb"
done
"$GODOT" --headless --path "$ROOT/godot" --import >/dev/null 2>&1 || true
for n in $PIECES; do
	[ -f "$DST/$n.glb.import" ] || {
		echo "import_kit: $n.glb was not imported" >&2
		exit 1
	}
done
echo "import_kit: $(echo $PIECES | wc -w) pieces in godot/candidate/crossing_kit"
