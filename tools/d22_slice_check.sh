#!/usr/bin/env bash
# D-22 SLICE — the scripted §6.A check (`docs/D22_SLICE_BRIEF.md`).
#
# Four phases, each a NEW bridge beside a NEW Godot, started exactly as
# the slice launcher starts them; only the slice's own save folder and the
# driver's notes file cross between them. Around them, A11's isolation:
# the player's save folder and Godot's user folder are hashed before and
# after, and the bridge's sockets are watched for anything that is not
# the local Godot client.
#
#   tools/d22_slice_check.sh [OUT_DIR]
#   DEMO=1 tools/d22_slice_check.sh OUT_DIR   (records the demonstration)
#   BUILD=<unpacked review build> tools/d22_slice_check.sh OUT_DIR
#       the same check against the exported executable and the bridge
#       source packed beside it (the clean-unpack verification)
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
OUT="${1:-$ROOT/.d22-slice-check}"
GODOT="${GODOT:-$ROOT/godot-bin/godot}"
BRIDGE_DIR="$ROOT/bridge"
PROJECT=(--path godot)
if [ -n "${BUILD:-}" ]; then
  GODOT="$BUILD/Archipepsi-D22-Slice.x86_64"
  BRIDGE_DIR="$BUILD/bridge"
  PROJECT=()
fi
PY="${PY:-python3}"
SAVES="$OUT/saves"
NOTES="$OUT/notes.json"
rm -rf "$OUT"; mkdir -p "$SAVES"

hash_tree() {  # a stable digest of a folder's names and bytes (or ABSENT)
  if [ -d "$1" ]; then
    (cd "$1" && find . -type f -print0 | sort -z | xargs -0 -r sha256sum) \
      | sha256sum | cut -d' ' -f1
  else echo ABSENT; fi
}
PLAYER_SAVES="$ROOT/bridge/saves"
GODOT_USER="$HOME/.local/share/godot/app_userdata/Archipepsi"
before_saves=$(hash_tree "$PLAYER_SAVES")

STATUS=0
for phase in forge draft crossing area_two; do
  (cd "$BRIDGE_DIR" && exec "$PY" -m archipepsi_bridge --ap=mock \
      --mock-scale prototype --epsilon=fallback --d22-slice \
      --save-dir "$SAVES") > "$OUT/bridge-$phase.log" 2>&1 &
  BRIDGE=$!
  for _ in $(seq 50); do
    (exec 3<>/dev/tcp/127.0.0.1/38290) 2>/dev/null && break; sleep 0.2
  done
  kill -0 $BRIDGE 2>/dev/null || { echo "bridge did not start ($phase)"; \
    cat "$OUT/bridge-$phase.log"; exit 1; }
  # Every TCP peer the bridge process holds, sampled while Godot runs.
  ( while kill -0 $BRIDGE 2>/dev/null; do
      ss -tnpH 2>/dev/null | grep "pid=$BRIDGE," || true; sleep 0.5
    done ) > "$OUT/sockets-$phase.txt" &
  WATCH=$!
  if [ -n "${DEMO:-}" ]; then
    # The demonstration: the same phases, rendered for real and paced,
    # one movie per phase (joined afterwards).
    xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" "${PROJECT[@]}" \
        --rendering-driver opengl3 --resolution 1280x720 \
        --write-movie "$OUT/clip-$phase.avi" --fixed-fps 30 \
        -- --d22-slice --d22-live=$phase --d22-demo \
        --d22-notes="$NOTES" > "$OUT/godot-$phase.log" 2>&1
  else
    "$GODOT" --headless "${PROJECT[@]}" -- --d22-slice --d22-live=$phase \
        --d22-notes="$NOTES" > "$OUT/godot-$phase.log" 2>&1
  fi
  RC=$?
  kill $BRIDGE 2>/dev/null; wait $BRIDGE 2>/dev/null; kill $WATCH 2>/dev/null
  grep -E "^(  ok|  NOTE|FAIL|GODOT D22)" "$OUT/godot-$phase.log"
  if [ $RC -ne 0 ]; then
    STATUS=1; echo "-- phase $phase failed; log tail:"; \
    tail -25 "$OUT/godot-$phase.log"; break
  fi
  [ "$phase" != area_two ] && echo "-- restart: both processes new, only the save crosses --"
done

after_saves=$(hash_tree "$PLAYER_SAVES")
# A11: a peer that is not 127.0.0.1 is a connection the slice must not make.
remote=$(cat "$OUT"/sockets-*.txt 2>/dev/null | awk '{print $5}' \
  | grep -v -E '^(127\.0\.0\.1|\[::1\]|\[::ffff:127\.0\.0\.1\]):' | sort -u)
echo
echo "A11 isolation"
echo "  player saves (bridge/saves): before $before_saves"
echo "                               after  $after_saves"
if [ "$before_saves" = "$after_saves" ]; then
  echo "  ok   the player's save folder is byte-identical"
else echo "  FAIL the player's save folder changed"; STATUS=1; fi
if [ -z "$remote" ]; then
  echo "  ok   0 connections from the bridge to anything but this machine"
else echo "  FAIL the bridge reached: $remote"; STATUS=1; fi
if grep -l -i -E "archipelago\.gg|wss?://[^1]" "$OUT"/bridge-*.log >/dev/null 2>&1; then
  echo "  FAIL a bridge log names a remote Archipelago"; STATUS=1
else echo "  ok   no bridge log names a remote Archipelago"; fi
echo "  slice saves: $(ls "$SAVES" | tr '\n' ' ')"
[ -f "$NOTES" ] && echo "  notes: $(cat "$NOTES" | tr -d '\n' | cut -c1-300)"
echo
[ $STATUS -eq 0 ] && echo "D22 SLICE CHECK OK" || echo "D22 SLICE CHECK FAILED"
exit $STATUS
