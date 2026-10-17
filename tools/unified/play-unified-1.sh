#!/usr/bin/env bash
# Unified integration 1 review build (Linux).  ./play-unified-1.sh [--fresh]
set -euo pipefail
cd "$(dirname "$0")"
PY=""
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1; then PY="$candidate"; break; fi
done
[ -n "$PY" ] || { echo "Python 3 not found." >&2; exit 1; }
"$PY" -c "import pydantic, websockets" >/dev/null 2>&1 \
  || "$PY" -m pip install --quiet pydantic websockets
exec "$PY" tools/unified_launch.py --godot ./Archipepsi-Unified-1.x86_64 "$@"
