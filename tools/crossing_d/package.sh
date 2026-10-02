#!/bin/sh
# CROSSING D'S REVIEW BUILD, exported and packed: one Windows zip and one
# Linux zip, each a folder that runs as it is unpacked -- an executable
# with its pack inside, no Godot, no Python and no import step.
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
NAME=Archipepsi-Crossing-D-review-$SHA
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
cp "$ROOT/tools/crossing_d/Play Crossing D - no enemies (Windows).bat" "$WIN/"
cp "$ROOT/tools/crossing_d/play-crossing-d.sh" "$LIN/"
for dir in "$WIN" "$LIN"; do
	sed "s/@REVISION@/$SHA/" "$ROOT/tools/crossing_d/README.txt" > "$dir/README.txt"
	(cd "$dir" && sha256sum -- * > SHA256SUMS.txt)
done
(cd "$OUT/windows" && rm -f "../$NAME-windows.zip" && zip -qr "../$NAME-windows.zip" "$NAME")
# THE SAME WINDOWS FOLDER IN TWO PARTS, for a channel that will not carry
# the one zip (the chat's upload limit; Wisp's studies went the same way).
# The executable is cut in two and joined by a script that checks the
# joined size and starts the game. The cut sits at 44%: the engine's code
# compresses worse than the game's pack behind it, so the two zips come
# out about the same size.
SPLIT="$OUT/windows-split/$NAME"
rm -rf "$OUT/windows-split"
mkdir -p "$SPLIT"
cp -- "$WIN"/* "$SPLIT"/
EXE="$SPLIT/Archipepsi-Crossing-D.exe"
SIZE=$(stat -c %s "$EXE")
CUT=$((SIZE * 44 / 100))
head -c "$CUT" "$EXE" > "$EXE.part1"
tail -c +"$((CUT + 1))" "$EXE" > "$EXE.part2"
rm "$EXE"
JOIN="1 - Join the game, run once (Windows).bat"
sed "s/@SIZE@/$SIZE/g" "$ROOT/tools/crossing_d/$JOIN" > "$SPLIT/$JOIN"
(cd "$OUT/windows-split" && rm -f "../$NAME-windows-part1of2.zip" \
	"../$NAME-windows-part2of2.zip" \
	&& zip -q -9 "../$NAME-windows-part1of2.zip" \
		"$NAME/Archipepsi-Crossing-D.exe.part1" "$NAME/$JOIN" \
		"$NAME/Play Crossing D - no enemies (Windows).bat" \
		"$NAME/Archipepsi-Crossing-D.console.exe" "$NAME/README.txt" \
		"$NAME/SHA256SUMS.txt" \
	&& zip -q -9 "../$NAME-windows-part2of2.zip" \
		"$NAME/Archipepsi-Crossing-D.exe.part2")
(cd "$OUT/linux" && rm -f "../$NAME-linux.zip" && zip -qr "../$NAME-linux.zip" "$NAME")
ls -l "$OUT"/*.zip
