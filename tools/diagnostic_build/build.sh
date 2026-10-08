#!/bin/sh
# THE WINDOWS DIAGNOSTIC BUILD of the prototype-scale campaign: one folder
# that runs as unpacked, with the Godot export, the bridge and a private
# Python, so nobody installs Godot or Python to play it.
#
#   tools/diagnostic_build/build.sh <output folder>
#
# What it packages is the COMMITTED tree at HEAD (`git archive`), never the
# working tree, so the revision in the folder name is the code inside it.
#
# Needs: git, curl, unzip, zip, python3 (with pip), and the MinGW-w64 C
# compiler (x86_64-w64-mingw32-gcc; Debian/Ubuntu package mingw-w64).
# Everything else -- Godot 4.5.1, its export templates, CPython 3.12.10's
# embeddable package and the bridge's wheels -- is downloaded, checked
# against toolchain.lock / requirements-windows.txt, and cached in
# $ARCHIPEPSI_BUILD_CACHE (default ~/.cache/archipepsi-diagnostic-build).
#
# No file outside tools/diagnostic_build/ is changed. In particular the
# export preset is written into a staged copy of godot/, not into the
# project: the game line has no export_presets.cfg, and each review branch
# carries its own.
#
# Output:
#   <out>/Archipepsi-Diagnostic-Campaign-<sha8>/        the folder
#   <out>/Archipepsi-Diagnostic-Campaign-<sha8>-windows.zip
set -eu

OUT=${1:?usage: build.sh <output folder>}
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
CACHE=${ARCHIPEPSI_BUILD_CACHE:-$HOME/.cache/archipepsi-diagnostic-build}
SHA=$(git -C "$ROOT" rev-parse --short=8 HEAD)
COMMIT=$(git -C "$ROOT" rev-parse HEAD)
BRANCH=$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)
EPOCH=$(git -C "$ROOT" log -1 --format=%ct HEAD)
PRODUCT=Archipepsi-Diagnostic-Campaign
NAME=$PRODUCT-$SHA

mkdir -p "$OUT" "$CACHE"
OUT=$(cd "$OUT" && pwd)
WORK="$OUT/.work-$SHA"
PKG="$OUT/$NAME"
ZIP="$OUT/$NAME-windows.zip"
rm -rf "$WORK" "$PKG" "$ZIP"
mkdir -p "$WORK" "$PKG"

say() { printf '\n== %s\n' "$*"; }

if [ -n "$(git -C "$ROOT" status --porcelain --untracked-files=no)" ]; then
	echo "note: the working tree has uncommitted changes; they are NOT" \
	     "in this build (it packages HEAD $SHA)."
fi

# -- 1. the pinned downloads -------------------------------------------------
say "toolchain (toolchain.lock)"
fetch() {   # fetch <name> -> prints the cached path
	line=$(grep -E "^$1[[:space:]]" "$HERE/toolchain.lock")
	set -- $line
	algo=$2 want=$3 url=$4
	file="$CACHE/$(basename "$url")"
	if [ ! -f "$file" ] || [ "$(${algo}sum "$file" | cut -d' ' -f1)" != "$want" ]; then
		curl -fsSL --retry 3 -o "$file.part" "$url"
		mv "$file.part" "$file"
	fi
	got=$(${algo}sum "$file" | cut -d' ' -f1)
	if [ "$got" != "$want" ]; then
		echo "REFUSED: $url" >&2
		echo "  $algo $got, toolchain.lock expects $want" >&2
		exit 1
	fi
	echo "$file"
}
EDITOR_ZIP=$(fetch godot-editor)
TEMPLATES=$(fetch godot-templates)
GODOT_LICENSE=$(fetch godot-license)
GODOT_COPYRIGHT=$(fetch godot-copyright)
PY_EMBED=$(fetch python-embed)
echo "all downloads match toolchain.lock"

# -- 2. the committed source ---------------------------------------------------
say "source: $BRANCH @ $COMMIT"
mkdir -p "$WORK/src"
git -C "$ROOT" archive --format=tar HEAD -- godot bridge \
	docs/baselines/playtest_2_5.json THIRD_PARTY_NOTICES.md \
	| tar -x -C "$WORK/src"
PORT=$(sed -n 's/^BRIDGE_PORT = \([0-9][0-9]*\)$/\1/p' \
	"$WORK/src/bridge/archipepsi_bridge/schemas/constants.py")
GD_PORT=$(sed -n 's/^const BRIDGE_PORT = \([0-9][0-9]*\)$/\1/p' \
	"$WORK/src/godot/scripts/autoload/constants.gd")
[ -n "$PORT" ] && [ "$PORT" = "$GD_PORT" ] || {
	echo "bridge port ($PORT) and Godot's ($GD_PORT) disagree or are missing" >&2
	exit 1; }

# -- 3. the Godot export -------------------------------------------------------
say "Godot 4.5.1 export"
mkdir -p "$WORK/godot-bin" "$WORK/xdg"
unzip -q -o "$EDITOR_ZIP" -d "$WORK/godot-bin"
GODOT="$WORK/godot-bin/Godot_v4.5.1-stable_linux.x86_64"
# The editor's settings, templates and caches go here, not into the
# builder's home: the build must not depend on, or disturb, whatever
# Godot the machine already has.
export XDG_CONFIG_HOME="$WORK/xdg/config" XDG_DATA_HOME="$WORK/xdg/data" \
	XDG_CACHE_HOME="$WORK/xdg/cache"
TPL="$XDG_DATA_HOME/godot/export_templates/4.5.1.stable"
mkdir -p "$TPL"
unzip -q -o -j "$TEMPLATES" templates/windows_release_x86_64.exe \
	templates/windows_release_x86_64_console.exe templates/version.txt -d "$TPL"
grep -qx '4.5.1.stable' "$TPL/version.txt" || {
	echo "the export templates are $(cat "$TPL/version.txt"), not 4.5.1.stable" >&2
	exit 1; }
"$GODOT" --version | grep -q '^4\.5\.1\.stable\.official\.f62fdbde1' || {
	echo "not the pinned Godot build: $("$GODOT" --version)" >&2; exit 1; }
sed -e "s|@REVISION@|$SHA|" \
	"$HERE/export_presets.cfg.in" > "$WORK/src/godot/export_presets.cfg"
mkdir -p "$PKG/game"
"$GODOT" --headless --path "$WORK/src/godot" --import > "$WORK/import.log" 2>&1 || {
	tail -40 "$WORK/import.log" >&2; exit 1; }
"$GODOT" --headless --path "$WORK/src/godot" \
	--export-release "Diagnostic Campaign (Windows)" "$PKG/game/Archipepsi.exe" \
	> "$WORK/export.log" 2>&1 || { tail -40 "$WORK/export.log" >&2; exit 1; }
[ -f "$PKG/game/Archipepsi.exe" ] && [ -f "$PKG/game/Archipepsi.console.exe" ] || {
	echo "the export did not produce both executables" >&2
	tail -40 "$WORK/export.log" >&2; exit 1; }
if grep -q "SCRIPT ERROR\|^ERROR" "$WORK/export.log"; then
	echo "the export logged errors:" >&2
	grep "SCRIPT ERROR\|^ERROR" "$WORK/export.log" | sort -u >&2
	exit 1
fi

# -- 4. Python and the bridge -------------------------------------------------
say "embedded Python 3.12.10 and the bridge's wheels"
PYDIR="$PKG/runtime/python"
mkdir -p "$PYDIR"
unzip -q "$PY_EMBED" -d "$PYDIR"
cp "$HERE/package/python312._pth" "$PYDIR/python312._pth"
python3 -m pip install --quiet --disable-pip-version-check --no-deps \
	--require-hashes --only-binary=:all: --no-compile \
	--platform win_amd64 --python-version 3.12 --implementation cp --abi cp312 \
	--cache-dir "$CACHE/pip" \
	--target "$PYDIR/Lib/site-packages" -r "$HERE/requirements-windows.txt"
rm -rf "$PYDIR/Lib/site-packages/bin"

mkdir -p "$PKG/runtime/bridge" "$PKG/runtime/godot/content" "$PKG/runtime/docs/baselines"
cp -R "$WORK/src/bridge/archipepsi_bridge" "$PKG/runtime/bridge/"
cp "$WORK/src/bridge/pyproject.toml" "$PKG/runtime/bridge/"
# What the bridge reads from the repository at run time, at the same paths
# relative to it (`Path(__file__).parents[2]`): the room shell registry
# (shells.py) and the playtest baseline the banner's Zone line reads
# (playtest.py, never fatal).
cp -R "$WORK/src/godot/content/registry" "$PKG/runtime/godot/content/"
cp "$WORK/src/docs/baselines/playtest_2_5.json" "$PKG/runtime/docs/baselines/"
find "$PKG/runtime" -name __pycache__ -type d -prune -exec rm -rf {} +

# -- 5. the starter -----------------------------------------------------------
say "starter (MinGW-w64)"
for variant in gui console; do
	if [ $variant = gui ]; then exe=Archipepsi-Diagnostic.exe; flags=-mwindows
	else exe=Archipepsi-Diagnostic.console.exe; flags="-mconsole -DSTARTER_CONSOLE"; fi
	# shellcheck disable=SC2086
	x86_64-w64-mingw32-gcc -O2 -Wall -Wextra -Werror -municode $flags \
		-DBRIDGE_PORT="$PORT" -DBUILD_REVISION="L\"$SHA\"" \
		-o "$PKG/$exe" "$HERE/starter/archipepsi_starter.c" \
		-lws2_32 -lshell32 -lole32 -luuid -static-libgcc -s \
		-Wl,--no-insert-timestamp
done

# -- 6. launchers, readme, notices, build info --------------------------------
say "documents"
cp "$HERE/package/START HERE - Mock Campaign (Windows).bat" \
	"$HERE/package/With log window - Mock Campaign (Windows).bat" "$PKG/"
sed "s/@REVISION@/$SHA/g" "$HERE/package/README.txt.in" | sed 's/$/\r/' > "$PKG/README.txt"
python3 "$HERE/notices.py" \
	--archipepsi "$WORK/src/THIRD_PARTY_NOTICES.md" \
	--godot-license "$GODOT_LICENSE" --godot-copyright "$GODOT_COPYRIGHT" \
	--python "$PYDIR/LICENSE.txt" \
	--site-packages "$PYDIR/Lib/site-packages" \
	--mingw /usr/share/doc/mingw-w64-common/copyright \
	> "$PKG/THIRD_PARTY_NOTICES.txt"
{
	echo "Archipepsi diagnostic campaign build"
	echo
	echo "source      $BRANCH @ $COMMIT"
	echo "built       tools/diagnostic_build/build.sh <out>"
	echo "bridge      --ap=mock --epsilon=fallback --mock-scale=prototype --save-dir <per-user>"
	echo "bridge port $PORT"
	echo "godot       $("$GODOT" --version)"
	echo "python      3.12.10 embeddable amd64"
	echo "wheels      $(grep -E '^[a-z]' "$HERE/requirements-windows.txt" | cut -d' ' -f1 | tr '\n' ' ')"
	echo "starter cc  $(x86_64-w64-mingw32-gcc --version | head -1)"
	echo
	echo "toolchain.lock:"
	grep -vE '^(#|$)' "$HERE/toolchain.lock" | awk '{print "  " $1 "  " $2 " " $3}'
} | sed 's/$/\r/' > "$PKG/BUILD-INFO.txt"

# -- 7. checksums, manifest, zip ----------------------------------------------
say "checksums and zip"
(cd "$PKG" && find . -type f ! -name SHA256SUMS.txt ! -name archipepsi-build.json \
	| sed 's|^\./||' | LC_ALL=C sort | while IFS= read -r f; do sha256sum -- "$f"; done \
	> SHA256SUMS.txt)
python3 "$HERE/manifest.py" "$PKG" --branch "$BRANCH" --commit "$COMMIT" \
	--zip "$(basename "$ZIP")" --built-at "$EPOCH"
# AFTER the last file is written, and over the whole tree: writing a file
# also changes its DIRECTORY's mtime, and the top folder's own entry in
# the zip is what made two builds of one commit differ by two bytes.
find "$PKG" -exec touch -h -d "@$EPOCH" {} +
(cd "$OUT" && find "$NAME" | LC_ALL=C sort | zip -q -X -9 "$ZIP" -@)

# -- 8. THE SAME FOLDER IN THREE PARTS ---------------------------------------
# For every channel that will not carry the one 50 MB zip: the chat's
# upload limit, and the 25 MB per file this project's file transfer to her
# PC turned out to allow (it refused a 28 MB part, which is why this is
# three and not two). The game is cut in three; the starter joins the
# parts on its first run, checks the joined size against
# game/Archipepsi.exe.size and deletes them. Same convention as the review
# builds' -partNofM sets, so the launcher reads it unchanged.
#
# Part 1 also carries everything else in the folder -- the bundled Python
# and bridge, about 20 MB zipped -- so it takes only a sliver of the game
# and parts 2 and 3 halve the rest. `test.sh` step 10 measures every zip,
# so a build that grows past the limit fails here rather than at the point
# of handing it over.
say "the same folder in three parts"
SPLIT="$OUT/$NAME-split"
rm -rf "$SPLIT"
mkdir -p "$SPLIT"
cp -R "$PKG" "$SPLIT/$NAME"
S="$SPLIT/$NAME"
EXE="$S/game/Archipepsi.exe"
SIZE=$(stat -c %s "$EXE")
echo "$SIZE" > "$EXE.size"
C1=$((SIZE * 4 / 100))
C2=$((C1 + (SIZE - C1) / 2))
head -c "$C1" "$EXE" > "$EXE.part1"
tail -c +"$((C1 + 1))" "$EXE" | head -c "$((C2 - C1))" > "$EXE.part2"
tail -c +"$((C2 + 1))" "$EXE" > "$EXE.part3"
JOINED=$(cat "$EXE.part1" "$EXE.part2" "$EXE.part3" | wc -c)
[ "$JOINED" = "$SIZE" ] || { echo "the parts total $JOINED, not $SIZE" >&2; exit 1; }
rm "$EXE"
(cd "$S" && find . -type f ! -name SHA256SUMS.txt ! -name archipepsi-build.json \
	| sed 's|^\./||' | LC_ALL=C sort | while IFS= read -r f; do sha256sum -- "$f"; done \
	> SHA256SUMS.txt)
python3 "$HERE/manifest.py" "$S" --branch "$BRANCH" --commit "$COMMIT" \
	--zip "$NAME-windows-part1of3.zip" --built-at "$EPOCH" --split
find "$S" -exec touch -h -d "@$EPOCH" {} +
P1="$OUT/$NAME-windows-part1of3.zip"
P2="$OUT/$NAME-windows-part2of3.zip"
P3="$OUT/$NAME-windows-part3of3.zip"
rm -f "$P1" "$P2" "$P3"
(cd "$SPLIT" && find "$NAME" \( -path "*Archipepsi.exe.part2" -o \
	-path "*Archipepsi.exe.part3" \) -prune -o -print \
	| LC_ALL=C sort | zip -q -X -9 "$P1" -@)
(cd "$SPLIT" && zip -q -X -9 "$P2" "$NAME/game/Archipepsi.exe.part2")
(cd "$SPLIT" && zip -q -X -9 "$P3" "$NAME/game/Archipepsi.exe.part3")
rm -rf "$SPLIT" "$WORK"
say "done"
ls -l "$ZIP" "$P1" "$P2" "$P3"
sha256sum "$ZIP" "$P1" "$P2" "$P3"
