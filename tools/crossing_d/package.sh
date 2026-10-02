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
(cd "$OUT/linux" && rm -f "../$NAME-linux.zip" && zip -qr "../$NAME-linux.zip" "$NAME")
ls -l "$OUT"/*.zip
