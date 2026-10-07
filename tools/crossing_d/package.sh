#!/bin/sh
# CROSSING D'S READABILITY REVIEW BUILD, exported and packed: one Windows
# zip and one Linux zip, each a folder that runs as it is unpacked -- an
# executable with its pack inside, no Godot, no Python and no import step.
# (The candidate kit it wears is imported by tools/crossing_d/import_kit.sh;
# the import below picks it up.)
#
#   tools/crossing_d/package.sh <output folder> [path/to/godot]
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
NAME=Archipepsi-Crossing-D-readability-$SHA
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
WIN="$OUT/windows/$NAME"
LIN="$OUT/linux/$NAME"
rm -rf "$OUT/windows" "$OUT/linux"
mkdir -p "$WIN" "$LIN"
"$GODOT" --headless --path "$ROOT/godot" --import >/dev/null 2>&1
"$GODOT" --headless --path "$ROOT/godot" \
	--export-release "Crossing D (Windows)" "$WIN/Archipepsi-Crossing-D.exe"
"$GODOT" --headless --path "$ROOT/godot" \
	--export-release "Crossing D (Linux)" "$LIN/Archipepsi-Crossing-D.x86_64"
# The two Windows launchers, the NO-ENEMIES one first. Each joins the
# game's two parts on its first run when it came in two (below); the
# size they check is the one executable's.
FIRST="1 - START HERE - Crossing D, NO ENEMIES (Windows).bat"
SECOND="2 - Crossing D, with enemies (Windows).bat"
SIZE=$(stat -c %s "$WIN/Archipepsi-Crossing-D.exe")
for bat in "$FIRST" "$SECOND"; do
	sed "s/@SIZE@/$SIZE/g" "$ROOT/tools/crossing_d/$bat" > "$WIN/$bat"
done
cp "$ROOT/tools/crossing_d/play-crossing-d.sh" "$LIN/"
for dir in "$WIN" "$LIN"; do
	sed "s/@REVISION@/$SHA/" "$ROOT/tools/crossing_d/README.txt" > "$dir/README.txt"
	(cd "$dir" && sha256sum -- * > SHA256SUMS.txt)
done
(cd "$OUT/windows" && rm -f "../$NAME-windows.zip" && zip -qr "../$NAME-windows.zip" "$NAME")
# THE SAME WINDOWS FOLDER IN TWO PARTS, for a channel that will not carry
# the one zip (the chat's upload limit; Wisp's studies went the same way).
# The executable is cut in two; either launcher joins it on its first run,
# checks the joined size, and starts the game. The cut sits at 44%: the
# engine's code compresses worse than the game's pack behind it, so the
# two zips come out about the same size.
SPLIT="$OUT/windows-split/$NAME"
rm -rf "$OUT/windows-split"
mkdir -p "$SPLIT"
cp -- "$WIN"/* "$SPLIT"/
EXE="$SPLIT/Archipepsi-Crossing-D.exe"
CUT=$((SIZE * 44 / 100))
head -c "$CUT" "$EXE" > "$EXE.part1"
tail -c +"$((CUT + 1))" "$EXE" > "$EXE.part2"
rm "$EXE"
(cd "$OUT/windows-split" && rm -f "../$NAME-windows-part1of2.zip" \
	"../$NAME-windows-part2of2.zip" \
	&& zip -q -9 "../$NAME-windows-part1of2.zip" \
		"$NAME/Archipepsi-Crossing-D.exe.part1" "$NAME/$FIRST" \
		"$NAME/$SECOND" \
		"$NAME/Archipepsi-Crossing-D.console.exe" "$NAME/README.txt" \
		"$NAME/SHA256SUMS.txt" \
	&& zip -q -9 "../$NAME-windows-part2of2.zip" \
		"$NAME/Archipepsi-Crossing-D.exe.part2")
(cd "$OUT/linux" && rm -f "../$NAME-linux.zip" && zip -qr "../$NAME-linux.zip" "$NAME")
ls -l "$OUT"/*.zip
