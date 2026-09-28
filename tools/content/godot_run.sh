#!/usr/bin/env bash
# Run a Godot harness script and ACTUALLY REPORT WHETHER IT WORKED.
#
#   . tools/content/godot_run.sh
#   run_godot <tag> <harness.gd> [args...]
#
# ## Why this exists
#
# Every runner in this directory used to end its pipeline with
#
#     ... 2>&1 | grep -E "^\[tag\]|SCRIPT ERROR" || true
#
# which is three separate ways of never failing. `|| true` swallows the
# grep's status; the pipeline's status is the GREP's, not Godot's, so the
# engine could exit non-zero and the shell would not know; and `grep` exits
# 1 when it simply matched nothing, so even without `|| true` a silent run
# and a crashed run are the same result.
#
# The owner caught it on `run_import_examples.sh`, where it mattered most:
# that script is quoted in the integration handoff as VERIFICATION, and a
# verification that cannot fail is worse than none — it launders a broken
# run into evidence.
#
# So this helper:
#
#   * keeps the engine's own exit status, by writing the log to a file and
#     never putting Godot in a pipeline;
#   * fails on `SCRIPT ERROR` (a GDScript parse or runtime fault) and on
#     `USER ERROR` (a deliberate `push_error` from the harness);
#   * does NOT fail on bare `ERROR:` lines, because a headless container
#     emits real ones that mean nothing here — ALSA cannot open a sound
#     device and says so on every run. Failing on those would make the
#     check cry wolf, which ends the same way as never crying at all;
#   * and gives the engine a deadline.
#
# That last one came out of sabotage-testing the first three. Injecting a
# SCRIPT ERROR into a harness did not produce a failure: it produced a run
# that never ended. A GDScript fault aborts the frame, but nothing calls
# `quit()`, so the SceneTree keeps ticking and the runner waits on it for
# ever. For a step quoted as verification that is no better than the `||
# true` it replaced — a check that hangs never says no. So the engine runs
# under `timeout`, inside xvfb so the deadline supervises Godot directly
# and nothing is orphaned behind the X server.
#
# It prints the tagged lines, so the runners read as before.
#
# `GODOT_RUN_TIMEOUT` overrides the deadline (seconds).

run_godot() {
  local tag="$1"; shift
  local harness="$1"; shift
  local log
  log="$(mktemp)"

  set +e
  xvfb-run -a timeout --kill-after=15s "${GODOT_RUN_TIMEOUT:-300}" \
    "$GODOT" --path "$ROOT/godot" --rendering-driver opengl3 \
    -s "$harness" -- "$@" >"$log" 2>&1
  local engine_status=$?
  set -e

  grep -E "^\[${tag}\]|SCRIPT ERROR|USER ERROR" "$log" || true

  local failed=0
  if [ "$engine_status" -eq 124 ] || [ "$engine_status" -eq 137 ]; then
    echo "godot-run: the engine did not finish within" \
      "${GODOT_RUN_TIMEOUT:-300}s and was stopped; a harness that faults" \
      "before it calls quit() hangs instead of failing" >&2
    failed=1
  elif [ "$engine_status" -ne 0 ]; then
    echo "godot-run: the engine exited ${engine_status}" >&2
    failed=1
  fi
  if grep -q "SCRIPT ERROR" "$log"; then
    echo "godot-run: the harness raised a SCRIPT ERROR" >&2
    failed=1
  fi
  if grep -q "USER ERROR" "$log"; then
    echo "godot-run: the harness called push_error" >&2
    failed=1
  fi
  if [ "$failed" -ne 0 ]; then
    echo "godot-run: full log at $log" >&2
    return 1
  fi
  rm -f "$log"
  return 0
}
