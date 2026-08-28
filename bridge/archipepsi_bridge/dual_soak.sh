#!/usr/bin/env bash
# `make dual-real-soak`: the dual-slot proof across several freshly
# GENERATED multiworlds, not one lucky seed.
#
# The seed decides which of A's thirty locations hold B's items, whether a
# cross-delivery exists at all in either direction, and how the two
# allocators overlap. One seed proves one arrangement, and the failure
# modes this file exists for are exactly the ones an arrangement can hide.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AP="$ROOT/.archipelago"
SEEDS="${DUAL_SEEDS:-3}"
PORT_BASE="${DUAL_PORT_BASE:-38310}"

pass=0
for i in $(seq 1 "$SEEDS"); do
  echo "=== seed $i of $SEEDS ==="
  rm -rf "$AP/players_multi" "$AP/output"
  mkdir -p "$AP/players_multi"
  cp "$ROOT/apworld/yaml/demo.yaml" "$ROOT/apworld/yaml/partner.yaml" \
     "$AP/players_multi/"
  ( cd "$AP" && SKIP_REQUIREMENTS_UPDATE=1 python3 Generate.py \
      --player_files_path players_multi --outputpath output \
      >/dev/null 2>&1 ) || { echo "generation failed" >&2; exit 1; }
  if DUAL_PORT=$((PORT_BASE + i)) \
     bash "$ROOT/bridge/archipepsi_bridge/dual_harness.sh" 2>&1 \
     | grep -E "^-- |dual INFO|DUAL "; then
    pass=$((pass + 1))
  fi
done
echo
if [ "$pass" = "$SEEDS" ]; then
  echo "DUAL ARCHIPEPSI SOAK OK: $pass/$SEEDS freshly generated multiworlds"
else
  echo "DUAL ARCHIPEPSI SOAK FAILED: $pass/$SEEDS" >&2
  exit 1
fi
