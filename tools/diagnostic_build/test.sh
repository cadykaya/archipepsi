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

step "2  checksums"
(cd "$PKG" && sha256sum -c --quiet SHA256SUMS.txt) \
	&& pass "every listed file matches" || fail "a file does not match its checksum"
MISSING=$(cd "$PKG" && find . -type f ! -name SHA256SUMS.txt \
	! -name archipepsi-build.json | sed 's|^\./||' | LC_ALL=C sort \
	| comm -23 - <(cut -c67- SHA256SUMS.txt | LC_ALL=C sort) | wc -l)
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
BEFORE="$TMP/before.txt"
(cd "$PKG" && find . -type f | LC_ALL=C sort | xargs sha256sum) > "$BEFORE"
SAVES="$TMP/saves"
( cd "$PKG/runtime/bridge" && ARCHIPEPSI_SAVE_DIR="$SAVES" timeout 90 "$PY" -m archipepsi_bridge \
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
	AFTER="$TMP/after.txt"
	(cd "$PKG" && find . -type f | LC_ALL=C sort | xargs sha256sum) > "$AFTER"
	diff -q "$BEFORE" "$AFTER" >/dev/null \
		&& pass "the package folder is byte-identical after the run" \
		|| { fail "the run changed the package folder:"; diff "$BEFORE" "$AFTER" | head; }

	( cd "$PKG/runtime/bridge" && timeout 120 "$WINE" ../python/python.exe \
		-m archipepsi_bridge --ap=mock --epsilon=fallback \
		--save-dir "Z:$(printf '%s' "$TMP/other" | tr '/' '\\')" 2>&1 \
		| cat > "$TMP/other.log" ) & OTHER=$!
	i=0
	while [ $i -lt 60 ]; do
		"$PY" -c "import socket,sys;sys.exit(0 if socket.socket().connect_ex(('127.0.0.1',38290))==0 else 1)" && break
		sleep 1; i=$((i + 1))
	done
	( cd "$PKG" && "$WINE" Archipepsi-Diagnostic.console.exe 2>&1 | cat > "$TMP/refusal.log" ) \
		< /dev/null || true
	grep -q "already using the bridge port" "$TMP/refusal.log" \
		&& pass "a second instance refuses to start, and says why" \
		|| { fail "no refusal while a bridge was listening"; cat "$TMP/refusal.log"; }
	kill $OTHER 2>/dev/null || true
	wait $OTHER 2>/dev/null || true
fi

printf '\n'
if [ "$FAILED" -eq 0 ]; then
	echo "PACKAGE OK${WINE:+ (including the Wine run; still not a Windows result)}"
	exit 0
fi
echo "$FAILED CHECK(S) FAILED"
exit 1
