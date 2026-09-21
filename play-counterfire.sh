#!/usr/bin/env bash
# EX50-021 Counterfire Arcade, on Linux and macOS.
# `./play-counterfire.sh` or `./play-counterfire.sh blocked`.
#
# NOT A ZONE: no Checks, no exit, no campaign, no bridge. It runs before
# the game boots its menu and cannot be reached without the flag.
#
# `blocked` is the specification's counterpart -- a real blocker between
# the gunner's muzzle and the receiver. The shutter cannot open that way.
set -euo pipefail
cd "$(dirname "$0")"

variant="${1:-arcade}"
extra=()
[ "$variant" = "blocked" ] && extra=(--blocked)

godot="${ARCHIPEPSI_GODOT:-}"
if [ -z "$godot" ] && [ -x godot-bin/godot ]; then godot=godot-bin/godot; fi
if [ -z "$godot" ]; then godot="$(command -v godot || true)"; fi
if [ -z "$godot" ]; then
  echo "Godot 4.5.1 not found. Set ARCHIPEPSI_GODOT to its path." >&2
  exit 1
fi

echo
echo "  ARCHIPEPSI 0.4 - EX50-021 COUNTERFIRE ARCADE - $variant"
echo "  Not a Zone: no Checks, no exit, no campaign, no bridge."
echo
echo "  Stand in the painted lane where the gunner can see you. When it"
echo "  shoots, step west into the alcove: the shot carries on into the"
echo "  impact trip behind you and the service shutter opens for eight"
echo "  seconds. Or take the west stair, kill the gunner, and shoot the"
echo "  trip yourself from the lane side."
echo
exec "$godot" --path godot -- --counterfire "${extra[@]}"
