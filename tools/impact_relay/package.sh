#!/bin/sh
# THE IMPACT RELAY, ART CANDIDATE (G1 with Arty's Batch 065 fitted; the
# same room, mechanics and physics as the G1 baseline, which is packed from
# review/impact-relay-g1 as Archipepsi-Impact-Relay). Exported and packed by
# Crossing D's process: one Windows zip and one Linux zip, each a folder
# that runs as it is unpacked -- an executable with its pack inside, no
# Godot, no Python and no import step -- and the Windows folder again in
# two parts for the chat's upload limit. (The kit lever and raceway it uses
# are imported by tools/crossing_d/import_kit.sh.)
#
#   tools/impact_relay/package.sh <output folder> [path/to/godot]
#
# Needs Godot 4.5.1's own export templates in the template folder
# ($XDG_DATA_HOME/godot/export_templates/4.5.1.stable/:
# windows_release_x86_64.exe, windows_release_x86_64_console.exe,
# linux_release.x86_64) -- the engine's free release files.
set -e
OUT=${1:?usage: package.sh <output folder> [godot]}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
GODOT=${2:-$ROOT/godot-bin/godot}
SHA=$(git -C "$ROOT" rev-parse --short=8 HEAD)
NAME=Archipepsi-Impact-Relay-Art-$SHA
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
WIN="$OUT/windows/$NAME"
LIN="$OUT/linux/$NAME"
rm -rf "$OUT/windows" "$OUT/linux"
mkdir -p "$WIN" "$LIN"
# The candidate art, copied byte for byte from its sources and imported.
"$ROOT/tools/impact_relay/import_kit.sh" "$GODOT" >/dev/null
"$GODOT" --headless --path "$ROOT/godot" --import >/dev/null 2>&1
"$GODOT" --headless --path "$ROOT/godot" \
	--export-release "Impact Relay Art (Windows)" "$WIN/Archipepsi-Impact-Relay-Art.exe"
"$GODOT" --headless --path "$ROOT/godot" \
	--export-release "Impact Relay Art (Linux)" "$LIN/Archipepsi-Impact-Relay-Art.x86_64"
# The two Windows launchers, the default (enemy-free, base kit + swing
# tether) first, then the labelled heavy-hit mode. Each joins the game's
# two parts on its first run when it came in two (below); the size they
# check is the one executable's.
FIRST="1 - START HERE - Impact Relay ART candidate (Windows).bat"
SECOND="2 - Impact Relay ART candidate, heavy-hit mode (Windows).bat"
SIZE=$(stat -c %s "$WIN/Archipepsi-Impact-Relay-Art.exe")
for bat in "$FIRST" "$SECOND"; do
	sed "s/@SIZE@/$SIZE/g" "$ROOT/tools/impact_relay/$bat" > "$WIN/$bat"
done
cp "$ROOT/tools/impact_relay/play-impact-relay-art.sh" \
	"$ROOT/tools/impact_relay/play-impact-relay-art-heavy-hit.sh" "$LIN/"
for dir in "$WIN" "$LIN"; do
	sed "s/@REVISION@/$SHA/" "$ROOT/tools/impact_relay/README.txt" > "$dir/README.txt"
	(cd "$dir" && sha256sum -- * > SHA256SUMS.txt)
done
(cd "$OUT/windows" && rm -f "../$NAME-windows.zip" && zip -qr "../$NAME-windows.zip" "$NAME")
# THE SAME WINDOWS FOLDER IN TWO PARTS, for a channel that will not carry
# the one zip (the chat's upload limit; Wisp's studies went the same way).
# The executable is cut in two; the launcher joins it on its first run,
# checks the joined size, and starts the game. The cut sits at 44%: the
# engine's code compresses worse than the game's pack behind it, so the
# two zips come out about the same size.
SPLIT="$OUT/windows-split/$NAME"
rm -rf "$OUT/windows-split"
mkdir -p "$SPLIT"
cp -- "$WIN"/* "$SPLIT"/
EXE="$SPLIT/Archipepsi-Impact-Relay-Art.exe"
CUT=$((SIZE * 44 / 100))
head -c "$CUT" "$EXE" > "$EXE.part1"
tail -c +"$((CUT + 1))" "$EXE" > "$EXE.part2"
rm "$EXE"
(cd "$OUT/windows-split" && rm -f "../$NAME-windows-part1of2.zip" \
	"../$NAME-windows-part2of2.zip" \
	&& zip -q -9 "../$NAME-windows-part1of2.zip" \
		"$NAME/Archipepsi-Impact-Relay-Art.exe.part1" "$NAME/$FIRST" "$NAME/$SECOND" \
		"$NAME/Archipepsi-Impact-Relay-Art.console.exe" "$NAME/README.txt" \
		"$NAME/SHA256SUMS.txt" \
	&& zip -q -9 "../$NAME-windows-part2of2.zip" \
		"$NAME/Archipepsi-Impact-Relay-Art.exe.part2")
(cd "$OUT/linux" && rm -f "../$NAME-linux.zip" && zip -qr "../$NAME-linux.zip" "$NAME")
ls -l "$OUT"/*.zip
