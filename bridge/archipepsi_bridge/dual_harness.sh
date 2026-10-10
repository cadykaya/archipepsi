#!/usr/bin/env bash
# Start a real MultiServer on a generated two-Archipepsi seed, run the dual
# driver against it, and tear the server down. Used by `make dual-real`.
#
# A fresh server per run, on its own port with its own save file: the
# MultiServer persists checked locations beside the seed, so a second run
# against a warm server would start with everything already checked and
# prove nothing.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AP="$ROOT/.archipelago"
PORT="${DUAL_PORT:-38299}"
SEED="${DUAL_SEED:-}"
SLOT_A="${DUAL_SLOT_A:-Skyiah}"
SLOT_B="${DUAL_SLOT_B:-Partner}"

if [ -z "$SEED" ]; then
  SEED="$(ls -t "$AP"/output/*.zip 2>/dev/null | head -1)"
fi
if [ -z "$SEED" ]; then
  echo "no generated seed; run 'make seed-multi' first" >&2
  exit 1
fi

WORK="$(mktemp -d)"
cp "$SEED" "$WORK/"
LOCAL_SEED="$WORK/$(basename "$SEED")"
LOG="$WORK/multiserver.log"

SKIP_REQUIREMENTS_UPDATE=1 python3 "$AP/MultiServer.py" \
  --port "$PORT" "$LOCAL_SEED" > "$LOG" 2>&1 &
SERVER_PID=$!
cleanup() {
  kill "$SERVER_PID" 2>/dev/null
  wait "$SERVER_PID" 2>/dev/null
  rm -rf "$WORK"
}
trap cleanup EXIT

for _ in $(seq 1 60); do
  grep -q "server listening" "$LOG" 2>/dev/null && break
  kill -0 "$SERVER_PID" 2>/dev/null || { echo "MultiServer died:" >&2
                                         tail -20 "$LOG" >&2; exit 1; }
  sleep 0.5
done
grep -q "server listening" "$LOG" || { echo "MultiServer never listened:" >&2
                                       tail -20 "$LOG" >&2; exit 1; }
echo "-- MultiServer up on $PORT ($(basename "$SEED"))"

cd "$ROOT/bridge" && python3 -m archipepsi_bridge.dual_real \
  "localhost:$PORT" "$SLOT_A" "$SLOT_B"
