#!/usr/bin/env bash
# Track A2 -- record the review captures of the interactive prototype.
#
#   tools/menu_proto/capture.sh <out dir> [cap ...]   (default: tapes/cap_*.json)
#
# Each capture tape drives the prototype through Godot's real input path
# (Input.parse_input_event) under Movie Maker: a fixed 30 fps, 1920 x 1080,
# the pointer drawn (--cursor), the scripted input captioned on screen.
# The frames become <out>/captures/<cap>.mp4; each moment the tape MARKS
# becomes a full-size still, <out>/stills/<cap>__<mark>.png, and the marks
# of one capture a sheet, <out>/sheets/<cap>.png.
#
# This is SCRIPTED evidence. It is not hands-on use.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
P="$ROOT/tools/menu_proto"
OUT="${1:?usage: capture.sh <out dir> [cap ...]}"
shift
CAPS=("$@")
[ ${#CAPS[@]} -eq 0 ] && CAPS=($(cd "$P/tapes" && ls cap_*.json | sed 's/\.json$//'))
FF="${FFMPEG:-$(python3 -c 'import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())')}"
mkdir -p "$OUT/captures" "$OUT/stills" "$OUT/sheets"
timeout 300 "$GODOT" --headless --path "$P" --import >/dev/null 2>&1 || true
for cap in "${CAPS[@]}"; do
  frames="$(mktemp -d)"
  timeout 1200 xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path "$P" \
    --rendering-driver opengl3 --resolution 1920x1080 --fixed-fps 30 \
    --write-movie "$frames/f.png" -- --tape="res://tapes/$cap.json" --cursor \
    --marks="$frames/marks.json" >"$frames/log" 2>&1 || true
  if grep -q "SCRIPT ERROR" "$frames/log" || [ ! -f "$frames/marks.json" ]; then
    grep "SCRIPT ERROR" -A 3 "$frames/log" >&2 || true
    echo "capture: $cap did not finish -- log $frames/log" >&2
    exit 1
  fi
  "$FF" -y -loglevel error -framerate 30 -i "$frames/f%08d.png" \
    -c:v libx264 -pix_fmt yuv420p -crf 18 -preset slow -movflags +faststart \
    "$OUT/captures/$cap.mp4"
  python3 - "$frames" "$OUT" "$cap" "$P/tapes/$cap.json" <<'PY'
import json, os, sys
from PIL import Image, ImageDraw
frames, out, cap, tape = sys.argv[1:]
marks = json.load(open(os.path.join(frames, "marks.json")))["marks"]
have = sorted(f for f in os.listdir(frames) if f.startswith("f") and f.endswith(".png"))
about = json.load(open(tape)).get("about", "")
shots = []
for m in marks:
    i = min(max(int(m["frame"]), 0), len(have) - 1)
    src = os.path.join(frames, have[i])
    dst = os.path.join(out, "stills", "%s__%s.png" % (cap, m["label"]))
    Image.open(src).convert("RGB").save(dst, optimize=True)
    shots.append((m["label"], dst))
# The sheet: the marked moments in order, at half size, labelled.
cols = 2
w, h = 960, 540
rows = (len(shots) + cols - 1) // cols
sheet = Image.new("RGB", (cols * w, rows * (h + 28) + 34), "#0b0d10")
d = ImageDraw.Draw(sheet)
d.text((10, 10), "%s -- %s" % (cap, about), fill="#ffd84d")
for k, (label, path) in enumerate(shots):
    x, y = (k % cols) * w, 34 + (k // cols) * (h + 28)
    sheet.paste(Image.open(path).resize((w, h), Image.LANCZOS), (x, y))
    d.text((x + 10, y + h + 6), "%d. %s" % (k + 1, label), fill="#e8eef6")
sheet.save(os.path.join(out, "sheets", cap + ".png"), optimize=True)
print("capture: %s -- %d frames, %d stills" % (cap, len(have), len(shots)))
PY
  rm -rf "$frames"
done
