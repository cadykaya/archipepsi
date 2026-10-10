#!/usr/bin/env bash
# Build (with a 1 s pre-roll, see README), render with SigmAudio's one-shot renderer, then trim.
# usage (from the sigmaudio root): render.sh <sounds.mjs> <starter.json> <workDir> [name ...]
set -euo pipefail
sounds="$1"; starter="$2"; work="$3"; shift 3; here="$(cd "$(dirname "$0")" && pwd)"
SHIFT_MS=1000 node "$here/build-sfx.mjs" "$sounds" "$starter" "$work/projects" "$@" > "$work/build.log"
names="$*"; [ -z "$names" ] && names=$(cd "$work/projects" && ls *.sigmaudio.json | sed 's/.sigmaudio.json//' | grep -v charge_hold)
mkdir -p "$work/raw"
for n in $names; do
  tail=$(node -e 'import(require("url").pathToFileURL(process.argv[1]).href).then(m=>console.log(m.default[process.argv[2]].tailMs/1000))' "$sounds" "$n")
  rm -f "$work/raw/$n.wav" "$work/raw/$n.receipt.json"
  node tools/sigmaudio.mjs render-one-shot "$work/projects/$n.sigmaudio.json" --out "$work/raw/$n.wav" --tail-seconds "$tail" --sample-rate 48000 --json > "$work/raw/$n.receipt.json"
done
python3 -I "$here/trim.py" "$work/wav" $(for n in $names; do echo "$work/raw/$n.wav"; done) > "$work/trim.log"
