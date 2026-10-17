#!/usr/bin/env bash
# UNIFIED INTEGRATION 1 -- the checks at the seams (godot/tests/unified_check.gd).
# Each phase: a new slice bridge beside a new client started with --unified,
# exactly as the unified launcher starts them, on a fresh save folder.
#
#   tools/unified_check.sh [OUT_DIR] [phase ...]
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
OUT="${1:-$ROOT/.unified-check}"; shift || true
PHASES=("$@"); [ ${#PHASES[@]} -eq 0 ] && PHASES=(weapons)
GODOT="${GODOT:-$ROOT/godot-bin/godot}"
PY="${PY:-python3}"
rm -rf "$OUT"; mkdir -p "$OUT"
STATUS=0
for phase in "${PHASES[@]}"; do
  SAVES="$OUT/saves-$phase"; mkdir -p "$SAVES"
  (cd bridge && exec "$PY" -m archipepsi_bridge --ap=mock \
      --mock-scale prototype --epsilon=fallback --d22-slice \
      --save-dir "$SAVES") > "$OUT/bridge-$phase.log" 2>&1 &
  BRIDGE=$!
  for _ in $(seq 50); do
    (exec 3<>/dev/tcp/127.0.0.1/38290) 2>/dev/null && break; sleep 0.2
  done
  timeout "${PHASE_TIMEOUT:-600}" "$GODOT" --headless --path godot -- --d22-slice --unified \
      --unified-live=$phase --d22-notes="$OUT/notes-$phase.json" \
      > "$OUT/godot-$phase.log" 2>&1
  RC=$?
  kill $BRIDGE 2>/dev/null; wait $BRIDGE 2>/dev/null
  grep -E "^(  ok|  NOTE|FAIL|GODOT UNIFIED)" "$OUT/godot-$phase.log"
  grep -E "SCRIPT ERROR" "$OUT/godot-$phase.log" | sort -u | head -5
  if [ $RC -ne 0 ]; then STATUS=1; tail -15 "$OUT/godot-$phase.log"; fi
done
[ $STATUS -eq 0 ] && echo "UNIFIED CHECK OK" || echo "UNIFIED CHECK FAILED"
exit $STATUS
