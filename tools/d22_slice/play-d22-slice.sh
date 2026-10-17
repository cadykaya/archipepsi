#!/usr/bin/env bash
# D-22 slice review build (Linux).  ./play-d22-slice.sh [--fresh]
set -euo pipefail
cd "$(dirname "$0")"
PY=""
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1; then PY="$candidate"; break; fi
done
[ -n "$PY" ] || { echo "Python 3 not found." >&2; exit 1; }
"$PY" -c "import pydantic, websockets" >/dev/null 2>&1 \
  || "$PY" -m pip install --quiet pydantic websockets
exec "$PY" tools/d22_slice_launch.py --godot ./Archipepsi-D22-Slice.x86_64 "$@"
