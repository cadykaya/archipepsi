#!/usr/bin/env bash
# One shard of the Integration gate's headless Godot targets
# (tools/ci/godot_shards.txt). Runs every target in the shard, in order,
# each in its own log group with its time; a failing target does not stop
# the ones after it (so one red run names every failure), but the shard
# fails if any did.
#
#   tools/ci/run_shard.sh <shard number>
set -uo pipefail
cd "$(dirname "$0")/../.."
N="${1:?usage: run_shard.sh <shard number>}"
LINE=$(grep -E "^${N}:" tools/ci/godot_shards.txt) \
  || { echo "::error::no shard ${N} in tools/ci/godot_shards.txt"; exit 1; }
FAILED=()
TIMES=()
for target in ${LINE#*:}; do
  echo "::group::make ${target}"
  start=$(date +%s)
  make "${target}"
  rc=$?
  took=$(( $(date +%s) - start ))
  echo "::endgroup::"
  TIMES+=("${target} ${took}s")
  if [ $rc -ne 0 ]; then
    echo "::error::${target} failed (exit ${rc}, ${took}s)"
    FAILED+=("${target}")
  fi
done
echo "shard ${N} timings:"; printf '  %s\n' "${TIMES[@]}"
if [ ${#FAILED[@]} -ne 0 ]; then
  echo "shard ${N}: ${#FAILED[@]} failed: ${FAILED[*]}"
  exit 1
fi
echo "shard ${N}: all ${#TIMES[@]} targets passed"
