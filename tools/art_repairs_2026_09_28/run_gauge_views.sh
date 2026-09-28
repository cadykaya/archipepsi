#!/usr/bin/env bash
# Repair 2026-09-28, follow-up: the gauge's before/after frames.
#
#   tools/art_repairs_2026_09_28/run_gauge_views.sh <out-dir> [old-ref]
#
# Renders conn_gauge as it was at <old-ref> (default 77d33ca: hinged, bezel
# still solid) and as built now. Both are turned by the same hinge to each
# declared reading, in their real materials.
#
# Stages its harness in godot/_harness, which it CREATES and then removes.
# If that folder already exists it belongs to somebody else: the runner
# stops without touching it. Writes only into <out-dir>.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
OUT="${1:?usage: run_gauge_views.sh <out-dir> [old-ref]}"
REF="${2:-77d33ca}"
H="$ROOT/godot/_harness"
[ -x "$GODOT" ] || { echo "no godot at $GODOT" >&2; exit 2; }
# shellcheck source=../content/godot_run.sh
. "$ROOT/tools/content/godot_run.sh"
mkdir -p "$OUT"
if ! mkdir "$H" 2>/dev/null; then
  echo "run_gauge_views: $H already exists and is not this run's;" \
       "nothing was touched" >&2
  exit 2
fi
OLD="$(mktemp -d)"
cleanup() { rm -rf "$H" "$OLD"; }
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
git -C "$ROOT" show "$REF:assets/models/batch049/connect/conn_gauge.glb" \
  > "$OLD/conn_gauge.glb"
cp "$ROOT/tools/art_repairs_2026_09_28/gauge_views.gd" "$H/gaugeview.gd"
sed 's/^class_name ArtBench$//' "$ROOT/tools/artpreview/artbench.gd" \
  > "$H/artbench.gd"
run_godot gaugeview _harness/gaugeview.gd "$OLD/conn_gauge.glb" \
  "$ROOT/assets/models/batch049/connect/conn_gauge.glb" \
  "$ROOT/assets/models/batch049/connect/manifest.json" "$OUT"
