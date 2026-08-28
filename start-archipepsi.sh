#!/usr/bin/env bash
# The macOS and Linux twin of "Start Archipepsi (Windows).bat".
#
# The bridge is the game's other half: it owns the campaign and talks to
# Archipelago. Godot renders and sends what you do. The game says BRIDGE
# OFFLINE until this is running, so leave it open while you play.
#
#   ./start-archipepsi.sh
#
# On macOS you can also make it double-clickable in Finder:
#   Get Info -> Open with -> Terminal.app
set -uo pipefail
cd "$(dirname "$0")"

echo
echo "  Archipepsi - starting the bridge"
echo "  -------------------------------"
echo

PY=""
for candidate in python3 python py; do
  if command -v "$candidate" >/dev/null 2>&1; then PY="$candidate"; break; fi
done
if [ -z "$PY" ]; then
  echo "  Python is not installed, or is not on your PATH."
  echo "  Install it from https://www.python.org/downloads/"
  echo
  read -r -p "  Press Enter to close. "
  exit 1
fi

if ! "$PY" -c "import pydantic, websockets" >/dev/null 2>&1; then
  echo "  Installing the two libraries the bridge needs..."
  echo
  if ! "$PY" -m pip install --quiet pydantic websockets; then
    echo
    echo "  That failed. Try running this by hand to see why:"
    echo "      $PY -m pip install pydantic websockets"
    echo
    read -r -p "  Press Enter to close. "
    exit 1
  fi
  echo "  Done."
  echo
fi

echo "  Starting. Leave this window open, then press MOCK CAMPAIGN"
echo "  in the game."
echo

cd bridge
"$PY" -m archipepsi_bridge --ap=mock --epsilon=fallback

# Only reached when the bridge stops. Hold the window so the error is
# readable rather than flashing past on a double-click.
echo
echo "  The bridge has stopped. Any error is printed above."
echo
read -r -p "  Press Enter to close. "
