#!/usr/bin/env bash
# Does tools/verify_content_pack.sh leave the caller's tree alone?
#
#   tools/content/test_verify_content_pack_safety.sh [ref ...]
#
# Production reported that the verifier deleted its tracked
# `godot/content/registry/legacy_procedural.json` and the scratch
# harnesses under `godot/`. This proves the fix without going near anybody's
# checkout. For each ref -- by default this checkout's HEAD, where that
# manifest is not tracked, and Production's pinned c12a72f, where it is --
# it:
#
#   1. makes a DISPOSABLE detached worktree of the ref in a temp folder,
#      and runs Godot's import there, so it looks like a checkout someone
#      works in (an import cache, .uid files);
#   2. installs THIS checkout's verifier into it;
#   3. plants caller-owned sentinels:
#        - godot/content/registry/legacy_procedural.json with a local edit
#          (created, where the ref does not track it);
#        - godot/_harness/prod_scratch.gd, a scratch harness;
#        - godot/scratch_probe.gd and godot/tests/scratch/notes.txt;
#        - godot/.godot/caller_cache_marker, in the ignored cache;
#   4. records every path under godot/ with its type and sha256, and
#      `git status`;
#   5. runs the verifier twice, and after each run requires that record to
#      be identical and the private copy gone:
#        - PASSING: as it is;
#        - FAILING: with a python3 shim on PATH that fails the run at
#          verify_markers.py, after the harness and manifest are written.
#
# At least one PASSING run must really pass (exit 0), or there is no
# successful run to speak of and the test fails.
#
# With OLD_REF=<rev>, it first runs that revision's verifier the same way
# and REPORTS what it destroyed. That is the "before", and it runs only
# here, in a disposable worktree.
#
# Production is read only at the pinned revision (PROD_REF, default
# c12a72f). Worktrees are detached; no branch is created or moved. The
# worktrees and temp folder are removed on exit. Exit 1 if any run of the
# verifier under test changed anything.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
PIN="c12a72fbc62500f4815d683d66a97f47fe514b06"
export PROD_REF="${PROD_REF:-$PIN}"
[ -x "$GODOT" ] || { echo "safety: no godot at $GODOT" >&2; exit 2; }
if [ "$#" -gt 0 ]; then REFS=("$@"); else REFS=(HEAD "$PIN"); fi
PY="$(command -v python3)"

T="$(mktemp -d "${TMPDIR:-/tmp}/verify-safety.XXXXXX")"
WTS=()
finish() {
  for wt in "${WTS[@]}"; do
    git -C "$ROOT" worktree remove --force "$wt" >/dev/null 2>&1 || true
  done
  git -C "$ROOT" worktree prune >/dev/null 2>&1 || true
  rm -rf "$T"
}
trap finish EXIT

mkdir -p "$T/shim"
cat > "$T/shim/python3" <<EOF
#!/bin/sh
case "\$1" in
  */verify_markers.py)
    echo "[verify] (test) injected failure at verify_markers.py" >&2
    exit 3 ;;
esac
exec "$PY" "\$@"
EOF
chmod +x "$T/shim/python3"

record() {  # every path under godot/: type, target or sha256; git status
  (cd "$1" && find godot -print0 | LC_ALL=C sort -z |
    while IFS= read -r -d '' f; do
      if [ -L "$f" ]; then printf 'L %s -> %s\n' "$f" "$(readlink "$f")"
      elif [ -d "$f" ]; then printf 'D %s\n' "$f"
      else printf 'F %s %s\n' "$f" "$(sha256sum < "$f" | cut -c1-16)"; fi
    done
    echo "--- git status"
    git status --porcelain --untracked-files=all --ignored -- godot)
}

compare() {  # before after -> "deleted N, changed N, added N" and the list
  "$PY" - "$1" "$2" <<'EOF'
import sys
def load(p):
    out = {}
    for line in open(p, encoding="utf-8"):
        if line.startswith("--- git status"):
            break
        kind, rest = line.rstrip("\n").split(" ", 1)
        path, _, value = rest.partition(" ")
        out[path] = (kind, value)
    return out
a, b = load(sys.argv[1]), load(sys.argv[2])
gone = sorted(set(a) - set(b))
new = sorted(set(b) - set(a))
changed = sorted(p for p in set(a) & set(b) if a[p] != b[p])
print("deleted %d, overwritten %d, added %d" % (len(gone), len(changed),
                                                len(new)))
for tag, rows in (("deleted", gone), ("overwritten", changed),
                  ("added", new)):
    for p in rows[:12]:
        print("    %-11s %s" % (tag, p))
    if len(rows) > 12:
        print("    %-11s ... and %d more" % (tag, len(rows) - 12))
EOF
}

prepare() {  # worktree ref script -> a checkout someone works in
  git -C "$ROOT" worktree add --detach "$1" "$2" >/dev/null 2>&1
  WTS+=("$1")
  cat > "$1/tools/verify_content_pack.sh" < "$3"
  if ! xvfb-run -a timeout 600 "$GODOT" --headless --path "$1/godot" \
      --import > "$1.import.log" 2>&1; then
    echo "  (Godot's import exited non-zero in $(basename "$1"); the" \
         "record below is taken as the import left it)"
  fi
}

plant() {  # caller-owned files the verifier must not touch
  local wt="$1"
  local reg="$wt/godot/content/registry/legacy_procedural.json"
  if [ -f "$reg" ]; then
    printf '\n' >> "$reg"   # a local edit to a tracked file
  else
    printf '{"caller": "owned, untracked"}\n' > "$reg"
  fi
  mkdir -p "$wt/godot/_harness" "$wt/godot/tests/scratch" "$wt/godot/.godot"
  printf 'extends SceneTree\n# caller-owned scratch harness\n' \
    > "$wt/godot/_harness/prod_scratch.gd"
  printf 'extends SceneTree\n# caller-owned probe\n' > "$wt/godot/scratch_probe.gd"
  printf 'caller-owned notes\n' > "$wt/godot/tests/scratch/notes.txt"
  printf 'caller-owned cache marker\n' > "$wt/godot/.godot/caller_cache_marker"
}

run() {  # label worktree script [shim] -> exit status of the verifier
  local label="$1" wt="$2" script="$3" shim="${4:-}"
  local log="$T/$label.log"
  mkdir -p "$T/tmp-$label"
  set +e
  (cd "$wt" && TMPDIR="$T/tmp-$label" GODOT="$GODOT" \
     PATH="${shim:+$shim:}$PATH" sh "$script" > "$log" 2>&1)
  local status=$?
  set -e
  echo "$status"
}

failed=0
passed_once=0
for ref in "${REFS[@]}"; do
  sha="$(git -C "$ROOT" rev-parse --short "$ref")"
  tracked="no"
  git -C "$ROOT" cat-file -e \
    "$ref:godot/content/registry/legacy_procedural.json" 2>/dev/null \
    && tracked="yes"
  echo "== $ref ($sha): legacy_procedural.json tracked there: $tracked"

  if [ -n "${OLD_REF:-}" ]; then
    wt="$T/wt-old-$sha"
    git -C "$ROOT" show "$OLD_REF:tools/verify_content_pack.sh" \
      > "$T/old_verifier.sh"
    prepare "$wt" "$ref" "$T/old_verifier.sh"
    plant "$wt"
    record "$wt" > "$T/before"
    status="$(run "old-$sha" "$wt" tools/verify_content_pack.sh)"
    record "$wt" > "$T/after"
    echo "  OLD verifier ($OLD_REF), exit $status:" \
      "$(compare "$T/before" "$T/after" | sed -n 1p)"
    compare "$T/before" "$T/after" | tail -n +2 | grep -v "/\.godot/\|\.uid$" \
      || true
    echo "    (Godot's own cache and .uid files, which it adds, not listed)"
  fi

  for mode in passing failing; do
    wt="$T/wt-$mode-$sha"
    prepare "$wt" "$ref" "$ROOT/tools/verify_content_pack.sh"
    plant "$wt"
    record "$wt" > "$T/before"
    if [ "$mode" = passing ]; then
      status="$(run "$mode-$sha" "$wt" tools/verify_content_pack.sh)"
    else
      status="$(run "$mode-$sha" "$wt" tools/verify_content_pack.sh "$T/shim")"
    fi
    record "$wt" > "$T/after"
    left="$(ls -A "$T/tmp-$mode-$sha")"
    verdict="$(compare "$T/before" "$T/after" | sed -n 1p)"
    echo "  NEW verifier, $mode run, exit $status: $verdict;" \
      "private copies left: ${left:-none}"
    if [ "$mode" = passing ] && [ "$status" -eq 0 ]; then
      passed_once=1
    fi
    if [ "$mode" = failing ] && [ "$status" -eq 0 ]; then
      echo "  FAIL: the injected failure did not fail the run"; failed=1
    fi
    if [ "$mode" = failing ] && ! grep -q "injected failure" \
        "$T/$mode-$sha.log"; then
      echo "  FAIL: the run stopped before the injected failure"; failed=1
    fi
    if ! cmp -s "$T/before" "$T/after" || [ -n "$left" ]; then
      compare "$T/before" "$T/after" | tail -n +2
      diff <(sed -n '/^--- git status/,$p' "$T/before") \
           <(sed -n '/^--- git status/,$p' "$T/after") || true
      echo "  FAIL: the $mode run changed the caller's tree"; failed=1
    fi
  done
done

if [ "$passed_once" -ne 1 ]; then
  echo "FAIL: no PASSING run exited 0, so preservation on a successful" \
       "run was not shown"
  failed=1
fi
if [ "$failed" -ne 0 ]; then
  exit 1
fi
echo "PASS: on passing and failing runs the verifier deleted, overwrote" \
     "and added nothing under godot/, and removed its private copy"
