#!/usr/bin/env bash
# Do the art-lane runners leave a `godot/_harness` that is not theirs alone?
# (FU-2, Arty, 2026-10-17.)
#
#   tools/content/test_harness_claim.sh
#
# Every runner that stages a harness now goes through `claim_harness`
# (tools/content/godot_run.sh) or the 2026-09-28 repair runners' own
# `mkdir "$H"` guard. This proves it without going near anybody's checkout:
# the runners are copied into a temp tree with an empty `godot/`, and Godot
# is a stub that records being called.
#
#   1. STATIC: every runner that sets `H=.../godot/_harness` claims it, and
#      none still carries the old `cleanup; mkdir` opening.
#   2. FOREIGN FOLDER: with a sentinel planted in `godot/_harness`, EVERY
#      such runner exits non-zero, the stub Godot is never called, and the
#      sentinel's bytes and the folder's listing are unchanged. One runner
#      is also held to the exact contract: status 2 and the message.
#   3. OWN FOLDER: with no folder there, a runner creates it, Godot sees it,
#      and it is gone afterwards.
#   4. SIGNAL: a run stopped with TERM mid-Godot exits 143 and removes it.
#   5. PARTIAL CLAIM: `claim_harness A B` with B taken removes A, leaves B
#      untouched, and exits 2.
#
# Exit 1 on any failure. Nothing outside the temp tree is written.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
FAILS=0
ok() { echo "[claim] ok   $*"; }
bad() { echo "[claim] FAIL $*"; FAILS=$((FAILS + 1)); }

cp -r "$ROOT/tools" "$T/tools"
mkdir -p "$T/godot" "$T/assets/models" "$T/out"
# The stub: proves whether it ran and whether the harness was there then.
cat > "$T/godot_stub" <<'EOF'
#!/usr/bin/env bash
echo "called" >> "$STUB_LOG"
[ -d "$STUB_ROOT/godot/_harness" ] && echo "harness-present" >> "$STUB_LOG"
[ -n "${STUB_SLEEP:-}" ] && sleep "$STUB_SLEEP"
exit 0
EOF
chmod +x "$T/godot_stub"
export GODOT="$T/godot_stub" STUB_LOG="$T/stub.log" STUB_ROOT="$T"
H="$T/godot/_harness"

# --- 1. static --------------------------------------------------------
# `$ROOT/godot/_harness` exactly, and never this file: it stages its own
# `$T/godot/_harness`, and a first draft that matched itself ran itself.
runners=$(grep -lE '^H="\$ROOT/godot/_harness"' "$T"/tools/*.sh \
  "$T"/tools/*/*.sh | grep -v '/test_harness_claim\.sh$')
n=0
for f in $runners; do
  n=$((n + 1))
  rel="${f#"$T"/}"
  if grep -q 'cleanup; mkdir' "$f"; then
    bad "$rel still clears the harness before using it"
  elif ! grep -qE 'claim_harness "\$H"|if ! mkdir "\$H"' "$f"; then
    bad "$rel stages a harness without claiming it"
  fi
done
[ "$n" -ge 45 ] && ok "static: $n runners, every one claims" \
  || bad "static: only $n runners found -- the search is broken"

# --- 2. foreign folder ------------------------------------------------
mkdir -p "$H"
printf 'somebody else\n' > "$H/prod_scratch.gd"
before="$(cd "$H" && find . -type f -exec sha256sum {} + | sort)"
for f in $runners; do
  rel="${f#"$T"/}"
  rm -f "$STUB_LOG"
  timeout 60 bash "$f" "$T/out/x" > "$T/run.log" 2>&1 < /dev/null
  status=$?
  after="$(cd "$H" 2>/dev/null && find . -type f -exec sha256sum {} + | sort)"
  if [ "$after" != "$before" ]; then
    bad "$rel changed somebody else's harness"
    mkdir -p "$H"; printf 'somebody else\n' > "$H/prod_scratch.gd"
  elif [ -f "$STUB_LOG" ]; then
    bad "$rel ran Godot with somebody else's harness in place"
  elif [ "$status" -eq 0 ]; then
    bad "$rel exited 0 without running"
  fi
done
ok "foreign folder: $n runners stopped, sentinel unchanged"
rm -f "$STUB_LOG"
bash "$T/tools/content/run_furnished_view.sh" shell_junction_triad \
  "$T/out/f" > "$T/run.log" 2>&1
status=$?
if [ "$status" -eq 2 ] && grep -q "already exists and is not this run's" \
    "$T/run.log"; then
  ok "foreign folder: exact contract (status 2, message)"
else
  bad "foreign folder: run_furnished_view exited $status: $(cat "$T/run.log")"
fi
rm -rf "$H"

# --- 3. own folder ----------------------------------------------------
rm -f "$STUB_LOG"
bash "$T/tools/content/run_furnished_view.sh" shell_junction_triad \
  "$T/out/f" > "$T/run.log" 2>&1
status=$?
if [ "$status" -eq 0 ] && grep -q harness-present "$STUB_LOG" \
    && [ ! -e "$H" ]; then
  ok "own folder: claimed, used, removed"
else
  bad "own folder: status $status, stub $(tr '\n' ' ' < "$STUB_LOG" \
    2>/dev/null), harness $( [ -e "$H" ] && echo left || echo gone)"
fi

# --- 4. signal --------------------------------------------------------
rm -f "$STUB_LOG"
STUB_SLEEP=3 bash "$T/tools/content/run_furnished_view.sh" \
  shell_junction_triad "$T/out/f" > "$T/run.log" 2>&1 &
pid=$!
for _ in $(seq 50); do [ -f "$STUB_LOG" ] && break; sleep 0.1; done
kill -TERM "$pid"
wait "$pid"
status=$?
if [ "$status" -eq 143 ] && [ ! -e "$H" ]; then
  ok "signal: TERM exits 143 and removes the claim"
else
  bad "signal: status $status, harness $( [ -e "$H" ] && echo left \
    || echo gone)"
fi

# --- 5. partial claim -------------------------------------------------
mkdir -p "$T/b"; printf 'theirs\n' > "$T/b/keep"
bash -c ". '$T/tools/content/godot_run.sh'; claim_harness '$T/a' '$T/b'; \
  echo unreachable" > "$T/run.log" 2>&1
status=$?
if [ "$status" -eq 2 ] && [ ! -e "$T/a" ] && [ "$(cat "$T/b/keep")" = theirs ] \
    && ! grep -q unreachable "$T/run.log"; then
  ok "partial claim: first released, second untouched, status 2"
else
  bad "partial claim: status $status, a $( [ -e "$T/a" ] && echo left \
    || echo gone)"
fi

if [ "$FAILS" -ne 0 ]; then
  echo "[claim] $FAILS failure(s)"
  exit 1
fi
echo "[claim] PASS -- no runner clears a harness that is not its own"
