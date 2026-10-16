#!/usr/bin/env bash
# The macOS / Linux twin of "Play D-22 Slice (Windows).bat".
#   ./play-d22-slice.sh           play or resume the slice
#   ./play-d22-slice.sh --fresh   start over (old run renamed aside)
set -euo pipefail
cd "$(dirname "$0")"

PY=""
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1; then PY="$candidate"; break; fi
done
[ -n "$PY" ] || { echo "Python not found." >&2; exit 1; }
"$PY" -c "import pydantic, websockets" >/dev/null 2>&1 \
  || "$PY" -m pip install --quiet pydantic websockets

godot="${ARCHIPEPSI_GODOT:-}"
if [ -z "$godot" ] && [ -x godot-bin/godot ]; then godot=godot-bin/godot; fi
if [ -z "$godot" ]; then godot="$(command -v godot || true)"; fi
[ -n "$godot" ] || { echo "Godot 4.5.1 not found. Set ARCHIPEPSI_GODOT." >&2; exit 1; }

exec "$PY" tools/d22_slice_launch.py --godot "$godot" "$@"
