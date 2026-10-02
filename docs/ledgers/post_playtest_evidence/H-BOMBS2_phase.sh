#!/bin/bash
# One phase of godot-bombs-live, as the make recipe runs it, for iterating.
tree="$1"; phase="$2"; saves="$tree/.bombs-saves"; log="$3"
cd "$tree/bridge" || exit 2
ARCHIPEPSI_SAVE_DIR="$saves" python3 -m archipepsi_bridge --ap=mock \
  --epsilon=fallback --mock-scale=default --candidate=all \
  > "$log.bridge" 2>&1 &
BRIDGE_PID=$!; sleep 2
kill -0 $BRIDGE_PID 2>/dev/null || { echo "bridge did not start"; exit 1; }
cd "$tree"
ids=$(cd "$tree/bridge" && python3 -m archipepsi_bridge.fixtures.mock_placements "Bomb Bag")
godot-bin/godot --headless --path godot -- --bombs-live="$phase" \
  --bombs-save-dir="$saves" --bombs-bag-ids="$ids" > "$log" 2>&1
status=$?
kill $BRIDGE_PID 2>/dev/null; wait $BRIDGE_PID 2>/dev/null
grep -E "^(  ok|  NOTE|FAIL|reached|claimed|GODOT BOMBS LIVE)|SCRIPT ERROR|Parse Error" "$log" | cut -c1-220
exit $status
