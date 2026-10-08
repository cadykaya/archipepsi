#!/bin/sh
# Rebuilds tests/fixtures/ by running the review builds' OWN package.sh
# scripts, with fake_godot.sh standing in for the Godot export, so the
# fixtures have exactly the delivered layout (folder, launchers, README,
# SHA256SUMS, the 44% cut into two parts) with a tiny fake game inside.
#
#   tests/make_fixtures.sh <crossing-d checkout> <readable-d checkout> <impact-lab checkout>
#
# e.g. git worktrees of wip/crossing-d-review (#20),
# review/crossing-d-readability (#21) and review/impact-lab-g0 (#22).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
OUT="$HERE/fixtures"
TMP=$(mktemp -d)
rm -rf "$OUT"
mkdir -p "$OUT"
sh "$1/tools/crossing_d/package.sh" "$TMP/d" "$HERE/fake_godot.sh" >/dev/null
sh "$2/tools/crossing_d/package.sh" "$TMP/rd" "$HERE/fake_godot.sh" >/dev/null
sh "$3/tools/impact_lab/package.sh" "$TMP/il" "$HERE/fake_godot.sh" >/dev/null
cp "$TMP"/*/*-windows*.zip "$TMP"/il/*-linux.zip "$OUT"/
rm -rf "$TMP"
ls -l "$OUT"
