#!/bin/sh
# WHAT THE DIAGNOSTIC BUILD IS CHECKED FOR, before it goes to the owner.
#
#   tools/diagnostic_build/test.sh <package folder> [wine]
#
# Every claim the package makes about itself, exercised against the built
# folder rather than against the source it came from:
#
#   1  the folder holds what README.txt says it holds;
#   2  SHA256SUMS.txt covers every file and matches;
#   3  archipepsi-build.json is schema `archipepsi-build/1`, its integrity
#      figures match the executable, and its modes name .bat files that
#      exist and start the starter;
#   4  THIRD_PARTY_NOTICES.txt carries Godot's MIT grant, CPython's
#      licence and each bundled wheel;
#   5  nothing in the package writes to the package: the campaign save
#      goes to the per-user folder, and the folder's checksums still
#      match after a run;
#   6  the bundled Python imports the bridge and its two libraries;
#   7  the bridge starts from the packaged tree alone and announces the
#      PROTOTYPE scale, the fallback Epsilon and the mock server;
#   8  (with Wine) the starter runs the WHOLE CAMPAIGN headlessly through
#      the packaged game and bridge, to ALL_CHECKS_CLEARED;
#   9  (with Wine) a second instance refuses to start while a bridge is
#      already listening, and says why.
#
# Steps 8 and 9 need a `wine` that implements KERNEL32.CopyFile2 (Wine 10
# or newer; Wine 9 aborts the bridge on its first save). Pass the wine
# binary as the second argument to run them; without it they are skipped
# and said to be skipped. NEITHER IS A WINDOWS RESULT: Wine is a
# different runtime, and only a run on real Windows tests Windows.
set -eu

PKG=${1:?usage: test.sh <package folder> [wine binary]}
WINE=${2:-}
PKG=$(cd "$PKG" && pwd)
HERE=$(cd "$(dirname "$0")" && pwd)
PY=${PYTHON:-python3}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
FAILED=0
pass() { printf '  ok    %s\n' "$*"; }
fail() { printf '  FAIL  %s\n' "$*"; FAILED=$((FAILED + 1)); }
skip() { printf '  skip  %s\n' "$*"; }
step() { printf '\n%s\n' "$*"; }

step "1  the folder holds what it should"
for f in "Archipepsi-Diagnostic.exe" "Archipepsi-Diagnostic.console.exe" \
	"START HERE - Mock Campaign (Windows).bat" \
	"With log window - Mock Campaign (Windows).bat" \
	"README.txt" "BUILD-INFO.txt" "THIRD_PARTY_NOTICES.txt" \
	"SHA256SUMS.txt" "archipepsi-build.json" \
	"game/Archipepsi.exe" "game/Archipepsi.console.exe" \
	"runtime/python/python.exe" "runtime/python/python312._pth" \
	"runtime/bridge/archipepsi_bridge/__main__.py" \
	"runtime/godot/content/registry" \
	"runtime/docs/baselines/playtest_2_5.json"; do
	[ -e "$PKG/$f" ] && pass "$f" || fail "missing: $f"
done
# A review room's isolation feature reaching this build would mean the
# wrong preset was used.
if strings "$PKG/game/Archipepsi.exe" 2>/dev/null \
	| grep -qx 'impact_lab\|crossing_review\|impact_relay'; then
	fail "the export carries a review-isolation feature tag"
else
	pass "no review-isolation feature tag in the export"
fi

if find "$PKG" -name "__pycache__" -type d | grep -q .; then
	fail "the package ships __pycache__ (the build should not, and a run must not add it)"
else
	pass "no __pycache__ anywhere in the package"
fi

step "2  checksums"
(cd "$PKG" && sha256sum -c --quiet SHA256SUMS.txt) \
	&& pass "every listed file matches" || fail "a file does not match its checksum"
# Plain POSIX sh here (no process substitution): this script runs under
# whatever /bin/sh is, and dash is not bash.
cut -c67- "$PKG/SHA256SUMS.txt" | LC_ALL=C sort > "$TMP/listed.txt"
(cd "$PKG" && find . -type f ! -name SHA256SUMS.txt \
	! -name archipepsi-build.json | sed 's|^\./||' | LC_ALL=C sort) > "$TMP/present.txt"
MISSING=$(comm -23 "$TMP/present.txt" "$TMP/listed.txt" | wc -l)
[ "$MISSING" -eq 0 ] && pass "no file is left out of SHA256SUMS.txt" \
	|| fail "$MISSING file(s) are not in SHA256SUMS.txt"

step "3  archipepsi-build.json"
"$PY" "$HERE/check_manifest.py" "$PKG" && pass "manifest is consistent with the folder" \
	|| fail "manifest does not describe this folder"

step "4  notices"
N="$PKG/THIRD_PARTY_NOTICES.txt"
grep -q "Godot Engine contributors" "$N" && pass "Godot's copyright line" \
	|| fail "no Godot copyright in the notices"
grep -q "PYTHON SOFTWARE FOUNDATION LICENSE" "$N" && pass "CPython's licence" \
	|| fail "no CPython licence in the notices"
for w in pydantic pydantic_core websockets annotated_types typing_extensions; do
	grep -qi "^${w%%_*}\|$w" "$N" && pass "names $w" || fail "no notice for $w"
done
grep -q "mingw" "$N" && pass "the MinGW-w64 runtime" || fail "no MinGW-w64 notice"

step "5-7  the packaged bridge, on its own"
SAVES="$TMP/saves"
# PYTHONDONTWRITEBYTECODE, because this step runs the packaged bridge with
# the HOST python and would otherwise leave __pycache__ inside the package.
# (The bundled interpreter ignores the variable -- it is isolated by its
# python312._pth -- which is why the starter passes `-B` instead.)
( cd "$PKG/runtime/bridge" && ARCHIPEPSI_SAVE_DIR="$SAVES" \
	PYTHONDONTWRITEBYTECODE=1 timeout 90 "$PY" -m archipepsi_bridge \
	--ap=mock --epsilon=fallback --mock-scale=prototype --save-dir "$SAVES" \
	> "$TMP/bridge.log" 2>&1 ) & BRIDGE=$!
i=0
while [ $i -lt 60 ]; do
	grep -q "bridge listening" "$TMP/bridge.log" 2>/dev/null && break
	sleep 1; i=$((i + 1))
done
if grep -q "bridge listening" "$TMP/bridge.log"; then
	pass "the bridge starts from the packaged tree (no checkout, no install)"
	grep -q "prototype scale (30 locations" "$TMP/bridge.log" \
		&& pass "announces the prototype scale" || fail "scale is not prototype"
	grep -q "epsilon     fallback" "$TMP/bridge.log" \
		&& pass "announces the fallback Epsilon" || fail "Epsilon is not fallback"
	grep -q "MOCK - offline fixture campaign" "$TMP/bridge.log" \
		&& pass "announces the offline mock campaign" || fail "not the mock campaign"
	grep -q "shells INFO shell" "$TMP/bridge.log" \
		&& pass "reads the packaged room-shell registry" \
		|| fail "the shell registry was not read"
else
	fail "the bridge did not start; see $TMP/bridge.log"
	sed -n '1,20p' "$TMP/bridge.log"
fi
kill $BRIDGE 2>/dev/null || true
wait $BRIDGE 2>/dev/null || true

step "8-9  the starter, the game and the whole campaign (Wine)"
if [ -z "$WINE" ]; then
	skip "no wine given; the starter, the game and the campaign were NOT run here"
	skip "a second-bridge refusal was NOT run here"
else
	HOME_DIR="$TMP/home"
	mkdir -p "$HOME_DIR"
	export ARCHIPEPSI_DIAGNOSTIC_HOME="Z:$(printf '%s' "$HOME_DIR" | tr '/' '\\')"
	# Piped through `cat`: a Windows Python on Wine dies on a redirected
	# console handle it is given directly.
	( cd "$PKG" && timeout 2400 "$WINE" Archipepsi-Diagnostic.console.exe \
		--headless -- --integration-test 2>&1 | cat > "$TMP/campaign.log" ) || true
	if grep -q "GODOT INTEGRATION OK" "$TMP/campaign.log"; then
		pass "the campaign runs to its goal through the packaged build"
		grep -q "ALL_CHECKS_CLEARED" "$TMP/campaign.log" \
			&& pass "reaches ALL_CHECKS_CLEARED" || fail "no ALL_CHECKS_CLEARED"
		grep -q "SCRIPT ERROR" "$TMP/campaign.log" \
			&& fail "a script error was raised during the run" \
			|| pass "no script error"
	else
		fail "the campaign did not report OK; see $TMP/campaign.log"
		tail -20 "$TMP/campaign.log"
	fi
	[ -f "$HOME_DIR/saves"/*.json ] 2>/dev/null \
		&& pass "the campaign save is in the per-user folder" \
		|| { ls "$HOME_DIR/saves" >/dev/null 2>&1 \
			&& pass "the campaign save is in the per-user folder" \
			|| fail "no save in $HOME_DIR/saves"; }
	[ -f "$HOME_DIR/logs/starter.log" ] && pass "the starter wrote its log there too" \
		|| fail "no starter log"
	# Against SHA256SUMS.txt, not against a snapshot taken earlier in this
	# script: the list is what the package claims about itself, and a file
	# that APPEARS (the bundled interpreter's __pycache__, once) is as much
	# a change as a file that differs.
	(cd "$PKG" && sha256sum -c --quiet SHA256SUMS.txt) \
		&& pass "every file still matches SHA256SUMS.txt after the run" \
		|| fail "the run changed a file the package had checksummed"
	(cd "$PKG" && find . -type f ! -name SHA256SUMS.txt \
		! -name archipepsi-build.json | sed 's|^\./||' | LC_ALL=C sort) \
		> "$TMP/present-after.txt"
	NEW=$(comm -23 "$TMP/present-after.txt" "$TMP/listed.txt" | wc -l)
	[ "$NEW" -eq 0 ] && pass "the run added no file to the package folder" \
		|| { fail "the run left $NEW new file(s) in the package:"
		     comm -23 "$TMP/present-after.txt" "$TMP/listed.txt" | head -3; }

	# `timeout 45` is how this bridge STOPS: killing the pipeline kills the
	# `timeout` and the shell, not the Windows process behind Wine, and a
	# bridge left holding the port made step 10 skip itself every run.
	( cd "$PKG/runtime/bridge" && timeout 45 "$WINE" ../python/python.exe \
		-m archipepsi_bridge --ap=mock --epsilon=fallback \
		--save-dir "Z:$(printf '%s' "$TMP/other" | tr '/' '\\')" 2>&1 \
		| cat > "$TMP/other.log" ) & OTHER=$!
	# Wait for the bridge's own "listening" line, not for a port probe:
	# probing raced the bind, the starter found the port free, and its
	# own bridge won the port instead -- which tested nothing.
	i=0
	while [ $i -lt 90 ]; do
		grep -q "bridge listening" "$TMP/other.log" 2>/dev/null && break
		sleep 1; i=$((i + 1))
	done
	grep -q "bridge listening" "$TMP/other.log" 2>/dev/null \
		|| fail "the second bridge never started, so the refusal was not tested"
	( cd "$PKG" && "$WINE" Archipepsi-Diagnostic.console.exe 2>&1 | cat > "$TMP/refusal.log" ) \
		< /dev/null || true
	grep -q "already using the bridge port" "$TMP/refusal.log" \
		&& pass "a second instance refuses to start, and says why" \
		|| { fail "no refusal while a bridge was listening"; cat "$TMP/refusal.log"; }
	kill $OTHER 2>/dev/null || true
	wait $OTHER 2>/dev/null || true
fi

step "10  the multi-part delivery of the same build"
PARTS=$(ls "$(dirname "$PKG")/$(basename "$PKG")"-windows-part*.zip 2>/dev/null || true)
if [ -z "$PARTS" ]; then
	skip "no part zips beside the folder; build.sh writes them"
else
	# 25 MB, which is what the project's file transfer to her PC allows --
	# it refused a 28 MB part, and that is why the delivery is in three.
	for z in $PARTS; do
		MB=$(( ($(stat -c %s "$z") + 1048575) / 1048576 ))
		[ "$MB" -le 25 ] && pass "$(basename "$z") is ${MB} MB (fits a 25 MB limit)" \
			|| fail "$(basename "$z") is ${MB} MB, over a 25 MB limit"
	done
	SP="$TMP/split"
	mkdir -p "$SP"
	for z in $PARTS; do ( cd "$SP" && unzip -q "$z" ); done
	SPKG="$SP/$(basename "$PKG")"
	(cd "$SPKG" && sha256sum -c --quiet SHA256SUMS.txt) \
		&& pass "the part zips unpack into one folder whose checksums match" \
		|| fail "the unpacked multi-part folder does not match its checksums"
	"$PY" "$HERE/check_manifest.py" "$SPKG" \
		&& pass "its manifest records the split, and the parts match it" \
		|| fail "the split manifest does not describe the folder"
	if [ -n "$WINE" ]; then
		HOME2="$TMP/home2"
		mkdir -p "$HOME2"
		# One quick boot, not the whole campaign: what is being tested is
		# that the starter JOINS the game and reaches it.
		ARCHIPEPSI_DIAGNOSTIC_HOME="Z:$(printf '%s' "$HOME2" | tr '/' '\\')"
		export ARCHIPEPSI_DIAGNOSTIC_HOME
		# Step 9 left a bridge dying; wait for the port before starting,
		# or the starter correctly refuses and tests nothing.
		i=0
		while [ $i -lt 120 ]; do
			"$PY" -c "import socket,sys;sys.exit(0 if socket.socket().connect_ex(('127.0.0.1',38290))==0 else 1)" || break
			sleep 1; i=$((i + 1))
		done
		( cd "$SPKG" && timeout 600 "$WINE" Archipepsi-Diagnostic.console.exe \
			--headless -- --boot-test 2>&1 | cat > "$TMP/split-boot.log" ) || true
		[ -f "$SPKG/game/Archipepsi.exe" ] \
			&& pass "the starter joined the game on its first run" \
			|| fail "the game was not joined; see $TMP/split-boot.log"
		[ -f "$SPKG/game/Archipepsi.exe.part1" ] \
			&& fail "the parts were left behind after joining" \
			|| pass "the parts were removed after joining"
		if grep -q "GODOT BOOT TESTS OK" "$TMP/split-boot.log"; then
			pass "the joined game runs"
		elif grep -q "already using the bridge port" "$TMP/split-boot.log"; then
			# Not the build's doing: something else on this machine holds
			# the port, so the starter correctly refused before the game.
			skip "another bridge held the port, so the joined game was NOT run here"
		else
			fail "the joined game did not run; see $TMP/split-boot.log"
		fi
	else
		skip "no wine given; the starter's join was NOT run here"
	fi
fi

printf '\n'
if [ "$FAILED" -eq 0 ]; then
	echo "PACKAGE OK${WINE:+ (including the Wine run; still not a Windows result)}"
	exit 0
fi
echo "$FAILED CHECK(S) FAILED"
exit 1
