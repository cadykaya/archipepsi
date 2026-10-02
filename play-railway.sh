#!/usr/bin/env bash
# The railway, on Linux and macOS. `./play-railway.sh` or
# `./play-railway.sh bracing`.
#
# NOT A ZONE: no Checks, no exit, no campaign, no bridge. It runs before
# the game boots its menu and cannot be reached without the flag.
set -euo pipefail
cd "$(dirname "$0")"

binding="${1:-gantry}"
extra=()
[ "$binding" = "bracing" ] && extra=(--bracing)

godot="${ARCHIPEPSI_GODOT:-}"
if [ -z "$godot" ] && [ -x godot-bin/godot ]; then godot=godot-bin/godot; fi
if [ -z "$godot" ]; then godot="$(command -v godot || true)"; fi
if [ -z "$godot" ]; then
  echo "Godot 4.5.1 not found. Set ARCHIPEPSI_GODOT to its path." >&2
  exit 1
fi

echo
echo "  ARCHIPEPSI 0.4 - THE RAILWAY - binding: $binding"
echo "  Not a Zone: no Checks, no exit, no campaign, no bridge."
echo
exec "$godot" --path godot -- --railway "${extra[@]}"
