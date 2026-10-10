#!/bin/sh
# THE FIVE-WEAPON RANGE (five firing profiles on the weapon-feel range,
# Heavy Report and the Static Pulse as references, no enemies), exported
# and packed by the Weapon Feel's process: one Windows
# zip and one Linux zip, each a folder that runs as it is unpacked -- an
# executable with its pack inside, no Godot, no Python and no import step
# -- and the Windows folder again in two parts for the chat's upload limit.
#
#   tools/five_weapons/package.sh <output folder> [path/to/godot]
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
NAME=Archipepsi-Five-Weapons-$SHA
HERE="$ROOT/tools/five_weapons"
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
WIN="$OUT/windows/$NAME"
LIN="$OUT/linux/$NAME"
rm -rf "$OUT/windows" "$OUT/linux"
mkdir -p "$WIN" "$LIN"
"$GODOT" --headless --path "$ROOT/godot" --import >/dev/null 2>&1
"$GODOT" --headless --path "$ROOT/godot" \
	--export-release "Five Weapons (Windows)" "$WIN/Archipepsi-Five-Weapons.exe"
"$GODOT" --headless --path "$ROOT/godot" \
	--export-release "Five Weapons (Linux)" "$LIN/Archipepsi-Five-Weapons.x86_64"
# The five Windows launchers, one per weapon, Foundry first. Each joins the game's two parts on its first run when it came in
# two (below); the size they check is the one executable's.
B1="1 - START HERE - Five Weapons, Foundry (Windows).bat"
B2="2 - Five Weapons, Sightline (Windows).bat"
B3="3 - Five Weapons, Switchback (Windows).bat"
B4="4 - Five Weapons, Bulkhead (Windows).bat"
B5="5 - Five Weapons, Mass Driver (Windows).bat"
SIZE=$(stat -c %s "$WIN/Archipepsi-Five-Weapons.exe")
for bat in "$B1" "$B2" "$B3" "$B4" "$B5"; do
	sed "s/@SIZE@/$SIZE/g" "$HERE/$bat" > "$WIN/$bat"
done
cp "$HERE/play-five-weapons.sh" "$HERE/play-sightline.sh" \
	"$HERE/play-switchback.sh" "$HERE/play-bulkhead.sh" \
	"$HERE/play-mass-driver.sh" "$LIN/"
for dir in "$WIN" "$LIN"; do
	sed "s/@REVISION@/$SHA/" "$HERE/README.txt" > "$dir/README.txt"
	(cd "$dir" && sha256sum -- * > SHA256SUMS.txt)
done
(cd "$OUT/windows" && rm -f "../$NAME-windows.zip" && zip -qr "../$NAME-windows.zip" "$NAME")
# THE SAME WINDOWS FOLDER IN TWO PARTS, cut at 44% as the Impact Relay's is.
SPLIT="$OUT/windows-split/$NAME"
rm -rf "$OUT/windows-split"
mkdir -p "$SPLIT"
cp -- "$WIN"/* "$SPLIT"/
EXE="$SPLIT/Archipepsi-Five-Weapons.exe"
CUT=$((SIZE * 44 / 100))
head -c "$CUT" "$EXE" > "$EXE.part1"
tail -c +"$((CUT + 1))" "$EXE" > "$EXE.part2"
rm "$EXE"
(cd "$OUT/windows-split" && rm -f "../$NAME-windows-part1of2.zip" \
	"../$NAME-windows-part2of2.zip" \
	&& zip -q -9 "../$NAME-windows-part1of2.zip" \
		"$NAME/Archipepsi-Five-Weapons.exe.part1" "$NAME/$B1" "$NAME/$B2" \
		"$NAME/$B3" "$NAME/$B4" "$NAME/$B5" \
		"$NAME/Archipepsi-Five-Weapons.console.exe" \
		"$NAME/README.txt" "$NAME/SHA256SUMS.txt" \
	&& zip -q -9 "../$NAME-windows-part2of2.zip" \
		"$NAME/Archipepsi-Five-Weapons.exe.part2")
(cd "$OUT/linux" && rm -f "../$NAME-linux.zip" && zip -qr "../$NAME-linux.zip" "$NAME")
ls -l "$OUT"/*.zip
