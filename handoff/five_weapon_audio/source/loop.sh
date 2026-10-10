#!/usr/bin/env bash
# Render the steady hold with SigmAudio (1 s pre-roll) and cut the loop from it.
# usage (from the sigmaudio root): loop.sh <sounds.mjs> <starter.json> <workDir>
set -euo pipefail
sounds="$1"; starter="$2"; work="$3"; here="$(cd "$(dirname "$0")" && pwd)"
SHIFT_MS=1000 node "$here/build-sfx.mjs" "$sounds" "$starter" "$work/projects" massdriver_charge_hold > /dev/null
mkdir -p "$work/raw" "$work/wav"; rm -f "$work/raw/massdriver_charge_hold.wav"
node tools/sigmaudio.mjs render-one-shot "$work/projects/massdriver_charge_hold.sigmaudio.json" --out "$work/raw/massdriver_charge_hold.wav" --tail-seconds 0.1 --sample-rate 48000 --json > "$work/raw/massdriver_charge_hold.receipt.json"
# event starts at 1.05 s; take 1.6 s from 2.0 s (well past the 50 ms attack)
python3 -I "$here/loopcut.py" "$work/raw/massdriver_charge_hold.wav" "$work/wav/massdriver_charge_hold_loop.wav" 2.0 1.6 0.1
