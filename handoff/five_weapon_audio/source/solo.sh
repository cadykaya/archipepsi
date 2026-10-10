#!/usr/bin/env bash
# Render each track of one built project alone (master chain still applies) and measure it.
# usage (from the sigmaudio root): solo.sh <project.json> <tailSeconds> <outDir>
set -euo pipefail
p="$1"; tail="$2"; out="$3"; mkdir -p "$out"; rm -f "$out"/*.wav
here="$(cd "$(dirname "$0")" && pwd)"
node -e 'const p=require(process.argv[1]);for(const t of p.cues[0].tracks)console.log(t.id+"\t"+t.name)' "$p" | while IFS=$'\t' read -r id name; do
  f="$out/$(echo "$name" | tr -c 'A-Za-z0-9\n' '_').wav"
  node tools/sigmaudio.mjs render-one-shot "$p" --track "$id" --out "$f" --tail-seconds "$tail" --sample-rate 48000 --json > /dev/null
done
python3 -I "$here/measure.py" "$out/solo.json" "$out"/*.wav | python3 -c '
import sys,json
for l in sys.stdin:
  r=json.loads(l); b=r["band_db"]
  print("%-40s pk %6.1f  M %6.1f  sub %5.1f low %5.1f mid %5.1f hi %5.1f air %5.1f  -40 at %.2fs end %6.1f"%(r["file"][:40],r["peak_dbfs"],r["momentary_max_lufs"],b["sub_20_80"],b["low_80_300"],b["mid_300_2k"],b["high_2k_8k"],b["air_8k_up"],r["decay_to_minus40_s"],r["last_20ms_peak_dbfs"]))'
