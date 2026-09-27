#!/usr/bin/env bash
# Track A2 -- stills of the prototype at a given window size (gameplay
# size by default: Production's window default, 1280 x 720).
#
#   tools/menu_proto/stills.sh <out dir> [WxH]
#
# Each tapes/still_*.json runs to its end and the frame is saved as
# <out>/<still>.png, one Godot at a time. Scripted, not hands-on.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
P="$ROOT/tools/menu_proto"
OUT="${1:?usage: stills.sh <out dir> [WxH]}"
RES="${2:-1280x720}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"      # Godot resolves a relative path from --path
for tape in $(cd "$P/tapes" && ls still_*.json); do
  name="${tape%.json}"
  end=$(python3 -c "import json,sys; t=0.0
for s in json.load(open(sys.argv[1]))['steps']:
    t = float(s['at']) if 'at' in s else t + float(s.get('after', 0))
print(max(t - 0.05, 0.1))" "$P/tapes/$tape")
  timeout 120 xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path "$P" \
    --rendering-driver opengl3 --resolution "$RES" -- --tape="res://tapes/$tape" \
    --shot="$OUT/$name.png" --shot-at="$end" >/dev/null 2>&1 || true
  [ -f "$OUT/$name.png" ] || { echo "stills: $name was not written" >&2; exit 1; }
  echo "stills: $OUT/$name.png ($RES)"
done
