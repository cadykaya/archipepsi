#!/usr/bin/env sh
# Build the drop-in authored-content pack under godot/content/.
#
#   tools/export_content_pack.sh
#
# Three steps, and each one has to be Godot's rather than mine:
#   1. python  copies the approved .glb and writes the registry manifest
#   2. godot --import  produces the .import sidecars and extracts the
#      embedded textures, which is what makes ResourceLoader.exists() true
#   3. godot -s wrap_content.gd  writes the .tscn wrappers
#
# Everything under godot/content/ is a GENERATED ARTIFACT. Regenerate it;
# never hand-edit it.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
[ -x "$GODOT" ] || { echo "export-content: no godot at $GODOT" >&2; exit 2; }

python3 "$ROOT/tools/export_content_pack.py"

cp "$ROOT/tools/content/wrap_content.gd" "$ROOT/godot/_wrap_content.gd"
trap 'rm -f "$ROOT/godot/_wrap_content.gd" "$ROOT/godot/_wrap_content.gd.uid"' EXIT

xvfb-run -a -s "-screen 0 1280x800x24" "$GODOT" --headless \
  --path "$ROOT/godot" --import >/dev/null 2>&1 || true
xvfb-run -a -s "-screen 0 1280x800x24" "$GODOT" --headless \
  --path "$ROOT/godot" -s _wrap_content.gd 2>&1 | grep -E "^\[wrap\]|SCRIPT ERROR" || true
