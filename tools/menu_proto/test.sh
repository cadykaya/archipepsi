#!/usr/bin/env bash
# Track A2 -- run the prototype's scripted checks, headless.
#
#   tools/menu_proto/test.sh [tape ...]      (default: every tapes/test_*.json)
#
# Each tape drives the prototype through Godot's real input path
# (Input.parse_input_event: keys, mouse, pad) at a fixed 60 fps, and
# asserts on what the faces report. This is SCRIPTED evidence: it shows
# the code does what it says for these inputs. It is not hands-on use.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
P="$ROOT/tools/menu_proto"
TAPES=("$@")
[ ${#TAPES[@]} -eq 0 ] && TAPES=($(cd "$P" && ls tapes/test_*.json))
timeout 300 "$GODOT" --headless --path "$P" --import >/dev/null 2>&1 || true
fail=0
for t in "${TAPES[@]}"; do
  log="$(mktemp)"
  timeout 300 "$GODOT" --headless --path "$P" --fixed-fps 60 -- \
    --test="res://${t#./}" >"$log" 2>&1
  code=$?
  grep -E "^\[test\]|SCRIPT ERROR|ERROR: .*res://" "$log" | grep -v "^\[test\] ok" || true
  ok=$(grep -c "^\[test\] ok" "$log")
  if [ $code -ne 0 ] || grep -q "SCRIPT ERROR" "$log"; then
    echo "test: $t FAILED (exit $code, $ok ok) -- log $log"
    fail=1
  else
    echo "test: $t passed ($ok checks)"
  fi
done
exit $fail
