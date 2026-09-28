#!/usr/bin/env bash
# Repair 2026-09-28, family 049: render the hinge before/after frames.
#
#   tools/art_repairs_2026_09_28/run_pose_views.sh <out-dir> [old-ref]
#
# Extracts the six reviewed 049 models from <old-ref> (default a1584c8)
# into a temporary folder, stages the harness the same way the art lane's
# other runners do (a godot/_harness folder removed on exit), and renders
# three frames per control. Writes only into <out-dir>.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
OUT="${1:?usage: run_pose_views.sh <out-dir> [old-ref]}"
REF="${2:-a1584c8}"
H="$ROOT/godot/_harness"
OLD="$(mktemp -d)"
[ -x "$GODOT" ] || { echo "no godot at $GODOT" >&2; exit 2; }
# shellcheck source=../content/godot_run.sh
. "$ROOT/tools/content/godot_run.sh"
mkdir -p "$OUT" "$OLD/batch049/connect"
cleanup() { rm -rf "$H" "$OLD"; }
trap cleanup EXIT
rm -rf "$H"; mkdir -p "$H"
for id in conn_hold_paddle conn_repair_seal conn_breaker conn_flag_ack \
          conn_set_dial conn_gauge; do
  git -C "$ROOT" show "$REF:assets/models/batch049/connect/$id.glb" \
    > "$OLD/batch049/connect/$id.glb"
done
cp "$ROOT/tools/art_repairs_2026_09_28/pose_views.gd" "$H/poseview.gd"
sed 's/^class_name ArtBench$//' "$ROOT/tools/artpreview/artbench.gd" > "$H/artbench.gd"
run_godot poseview _harness/poseview.gd "$OLD" "$ROOT/assets/models" "$OUT"
