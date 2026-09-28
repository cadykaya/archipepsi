#!/usr/bin/env bash
# The concourse-pier playtest (Linux / macOS):
#
#   ./play-concourse-pier.sh            empty: architecture and lighting
#   ./play-concourse-pier.sh populated  the same, with one small encounter
#
# No bridge, and isolated before anything connects: the game refuses to
# open a bridge connection under this flag and writes none of your
# settings, favourites or saves. The room is Arty's pending
# shell_concourse_pier, loaded for this playtest only.
set -euo pipefail
cd "$(dirname "$0")"

mode="${1:-empty}"
extra=()
[ "$mode" = "populated" ] && extra=(--populated)

godot="${ARCHIPEPSI_GODOT:-}"
if [ -z "$godot" ] && [ -x godot-bin/godot ]; then godot=godot-bin/godot; fi
if [ -z "$godot" ]; then godot="$(command -v godot || true)"; fi
if [ -z "$godot" ]; then
  echo "Godot 4.5.1 not found. Set ARCHIPEPSI_GODOT to its path." >&2
  exit 1
fi

echo
echo "  ARCHIPEPSI 0.4 - CONCOURSE PIER PLAYTEST - $mode"
echo "  Not connected, nothing is saved. The exit portal, RETURN TO HUB"
echo "  or ABANDON start the route again; Esc then QUIT GAME to stop."
echo
exec "$godot" --path godot -- --concourse-pier "${extra[@]}"
