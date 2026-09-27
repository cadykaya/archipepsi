#!/usr/bin/env bash
# Track A2 -- the four direction studies' stills (third ruling, 2026-09-27).
#
#   tools/menu_proto/studies/render.sh <out dir> [dirs] [WxH]   (dirs: ABCD)
#
# For each direction: <out>/<dir>/ gets the gameplay-size screens --
# equipment_normal, equipment_stress, map_detail, journal, settings -- and
# two page-turn frames. Scripted stills of an isolated study scene; nothing
# is wired and nothing is hands-on.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
P="$ROOT/tools/menu_proto"
OUT="${1:?usage: render.sh <out dir> [dirs] [WxH]}"
DIRS="${2:-ABCD}"
RES="${3:-1280x720}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
# New class_names (the studies' own) are only known after an import.
timeout 300 "$GODOT" --headless --path "$P" --import >/dev/null 2>&1 || true
run() {  # <dir> <state> <shots>
  local log; log="$(mktemp)"
  timeout 300 xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path "$P" \
    --rendering-driver opengl3 --resolution "$RES" --fixed-fps 30 \
    res://studies/study.tscn -- --dir="$1" --state="$2" --shots="$3" >"$log" 2>&1 || true
  if grep -qE "SCRIPT ERROR|Parse Error" "$log"; then
    grep -E "SCRIPT ERROR|Parse Error" -A3 "$log" >&2
    echo "render: study $1 ($2) failed -- log $log" >&2
    exit 1
  fi
  grep -E "characters the face lacks" "$log" >&2 || true
  rm -f "$log"
}
for d in $(echo "$DIRS" | grep -o .); do
  o="$OUT/$d"
  mkdir -p "$o"
  run "$d" normal "equipment=$o/${d}_1_equipment_normal.png;map=$o/${d}_3_map_detail.png;journal=$o/${d}_4_journal.png;settings=$o/${d}_5_settings.png;turn:journal>map@0.5=$o/${d}_m1_turn_journal_map.png;turn:equipment>map@0.35=$o/${d}_m2_turn_equipment_map.png"
  run "$d" stress "equipment=$o/${d}_2_equipment_stress.png"
  echo "render: $d -> $o ($(ls "$o" | wc -l) images, $RES)"
done
