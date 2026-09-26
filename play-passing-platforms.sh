#!/usr/bin/env bash
# EX50-011 Passing Platforms, on Linux and macOS.
# `./play-passing-platforms.sh` or `./play-passing-platforms.sh parted`.
#
# NOT A ZONE: no Checks, no exit, no campaign, no bridge. It runs before
# the game boots its menu and cannot be reached without the flag.
#
# `parted` is the specification's own counterexample -- the same room
# with the shuttle's track shifted so nothing passes. It is there to be
# unable to be completed.
set -euo pipefail
cd "$(dirname "$0")"

variant="${1:-passing}"
extra=()
[ "$variant" = "parted" ] && extra=(--parted)

godot="${ARCHIPEPSI_GODOT:-}"
if [ -z "$godot" ] && [ -x godot-bin/godot ]; then godot=godot-bin/godot; fi
if [ -z "$godot" ]; then godot="$(command -v godot || true)"; fi
if [ -z "$godot" ]; then
  echo "Godot 4.5.1 not found. Set ARCHIPEPSI_GODOT to its path." >&2
  exit 1
fi

echo
echo "  ARCHIPEPSI 0.4 - EX50-011 PASSING PLATFORMS - $variant"
echo "  Not a Zone: no Checks, no exit, no campaign, no bridge."
echo
echo "  Pull H EAST at the arrival floor, board the lift, pull LAUNCH,"
echo "  and step north onto the shuttle while it passes. Or pull STOP H"
echo "  when it is beside the lift and take your time."
echo
exec "$godot" --path godot -- --passing-platforms "${extra[@]}"
