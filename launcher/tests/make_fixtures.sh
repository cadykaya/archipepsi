#!/bin/sh
# Adds one review build's packages to tests/fixtures/ by running that
# build's OWN package.sh, with fake_godot.sh standing in for the Godot
# export, so the fixtures have exactly the delivered layout (folder,
# launchers, README, SHA256SUMS, the 44% cut into two parts) with a tiny
# fake game inside.
#
#   tests/make_fixtures.sh <checkout> <tools/.../package.sh>
#
# The fixtures were made from git worktrees of:
#   wip/crossing-d-review (#20)          tools/crossing_d/package.sh
#   review/crossing-d-readability (#21)  tools/crossing_d/package.sh
#   review/impact-lab-g0 (#22)           tools/impact_lab/package.sh
#   review/impact-relay-g1               tools/impact_relay/package.sh
#   review/impact-relay-g1-art           tools/impact_relay/package.sh
#
# The fake game is random, so remaking a package changes its bytes:
# library-0.1.0.zip (a library written by launcher 0.1.0 from these
# fixtures) must then be remade too, or the upgrade tests will fail.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
OUT="$HERE/fixtures"
TMP=$(mktemp -d)
mkdir -p "$OUT"
sh "$1/$2" "$TMP/out" "$HERE/fake_godot.sh" >/dev/null
cp "$TMP"/out/*-windows*.zip "$OUT"/
rm -rf "$TMP"
ls -l "$OUT"
