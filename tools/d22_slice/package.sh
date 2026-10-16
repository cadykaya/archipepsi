#!/bin/sh
# THE D-22 SLICE REVIEW BUILD, exported and packed: one Windows zip and one
# Linux zip, each a folder that runs as it is unpacked -- the game as an
# executable with its pack inside, the bridge's Python source beside it,
# and a launcher that starts both. Needs Python 3 (with pydantic and
# websockets, which the launcher installs if missing), as the ordinary game
# does; needs no Godot and no import step.
#
#   tools/d22_slice/package.sh <output folder> [path/to/godot]
#
# Needs Godot 4.5.1's own export templates in the template folder
# ($XDG_DATA_HOME/godot/export_templates/4.5.1.stable/).
set -e
OUT=${1:?usage: package.sh <output folder> [godot]}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
GODOT=${2:-$ROOT/godot-bin/godot}
SHA=$(git -C "$ROOT" rev-parse --short=8 HEAD)
NAME=Archipepsi-D22-Slice-$SHA
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
WIN="$OUT/windows/$NAME"
LIN="$OUT/linux/$NAME"
rm -rf "$OUT/windows" "$OUT/linux"
mkdir -p "$WIN" "$LIN"
"$GODOT" --headless --path "$ROOT/godot" --import >/dev/null 2>&1
"$GODOT" --headless --path "$ROOT/godot" \
	--export-release "D-22 Slice (Windows)" "$WIN/Archipepsi-D22-Slice.exe"
"$GODOT" --headless --path "$ROOT/godot" \
	--export-release "D-22 Slice (Linux)" "$LIN/Archipepsi-D22-Slice.x86_64"
for dir in "$WIN" "$LIN"; do
	mkdir -p "$dir/bridge" "$dir/tools"
	# The bridge package only: no tests, no caches, no saves.
	(cd "$ROOT/bridge" && find archipepsi_bridge -type f \
		! -path '*/__pycache__/*' ! -name '*.pyc' -print0 \
		| xargs -0 -I{} cp --parents {} "$dir/bridge/")
	cp "$ROOT/tools/d22_slice_launch.py" "$dir/tools/"
	sed "s/@REVISION@/$SHA/" "$ROOT/tools/d22_slice/README.txt" > "$dir/README.txt"
done
for bat in "1 - START HERE - D-22 Slice (Windows).bat" \
		"2 - D-22 Slice, start over (Windows).bat"; do
	sed 's/\r$//; s/$/\r/' "$ROOT/tools/d22_slice/$bat" > "$WIN/$bat"
done
cp "$ROOT/tools/d22_slice/play-d22-slice.sh" "$LIN/"
chmod +x "$LIN/play-d22-slice.sh" "$LIN/Archipepsi-D22-Slice.x86_64"
for dir in "$WIN" "$LIN"; do
	(cd "$dir" && find . -type f ! -name SHA256SUMS.txt -print0 | sort -z \
		| xargs -0 sha256sum > SHA256SUMS.txt)
done
(cd "$OUT/windows" && rm -f "../$NAME-windows.zip" && zip -qr "../$NAME-windows.zip" "$NAME")
(cd "$OUT/linux" && rm -f "../$NAME-linux.zip" && zip -qr "../$NAME-linux.zip" "$NAME")
ls -l "$OUT"/*.zip
