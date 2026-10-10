#!/usr/bin/env bash
# Regenerate every delivered file from source. Run from a SigmAudio checkout root.
# usage: make-all.sh <starter.sigmaudio.json> <workDir>
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; starter="$1"; work="$2"
mkdir -p "$work"; rm -rf "$work/projects" "$work/raw" "$work/wav" "$work/preview"   # never trust a stale render
"$here/render.sh" "$here/sounds.mjs" "$starter" "$work"
"$here/loop.sh" "$here/sounds.mjs" "$starter" "$work"
python3 -I "$here/measure.py" "$work/measurements.json" "$work"/wav/*.wav > /dev/null
python3 -I "$here/context.py" "$work/wav" "$work/preview"
for f in "$work"/preview/*.wav; do ffmpeg -v error -y -i "$f" -c:a aac -b:a 256k "${f%.wav}.m4a"; done
(cd "$work/wav" && sha256sum *.wav > SHA256SUMS.txt)
