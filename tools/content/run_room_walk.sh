#!/bin/sh
# The real player through the ordinary room, in a throwaway copy of
# Production's project at a pinned revision.
#
#   sh tools/content/run_room_walk.sh [out-dir]
#
#   PROD_REF   the Production revision to walk in (default 17b76098)
#   GODOT      the engine (default .tools/godot)
#
# Nothing in this checkout or in Production's is written. The copy is a
# `git archive` of PROD_REF's godot/ in a new temporary directory; the
# room's eleven files go into it and its one registry entry is added to
# THAT revision's registry; and the directory is removed on exit, success
# or not.
#
# In that throwaway registry, and only there, the entry's review is `pass`.
# The committed entry stays `pending`, and a pending shell is one the game
# will not build: the census would measure it (its own driver lifts the
# gate for that) but skip it in the doorway crossings, which build through
# the shared registry -- the first run here reported both doors "not
# built". Lifting the gate in the copy is what lets Production's own
# crossing test walk out through them.
#
# Three engine runs, each judged on its own:
#   import     the copy imports
#   walk       tools/content/room_walk.gd: a wall control, then the floor
#              route, the upper loop and the drop, with no jumps
#   census     Production's own `--room-contract` suite, which builds
#              every authored shell through ContentInstantiator and
#              audits it (the review gate lifted in a private registry
#              copy, by Production's own driver, as it does for every
#              shell)
# With an out-dir, a fourth, rendering run (xvfb, opengl3) saves the two
# eye-height pictures there.
set -eu

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
PROD_REF="${PROD_REF:-17b76098}"
OUT="${1:-}"
ROOM=shell_concourse_pier

[ -x "$GODOT" ] || { echo "run_room_walk: no godot at $GODOT" >&2; exit 2; }
git -C "$ROOT" cat-file -e "$PROD_REF^{commit}" 2>/dev/null || {
  echo "run_room_walk: $PROD_REF is not in this clone; fetch it first" >&2
  exit 2; }
[ -f "$ROOT/godot/content/shells/$ROOM.tscn" ] || {
  echo "run_room_walk: no $ROOM.tscn; run tools/export_content_pack.sh" >&2
  exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/room_walk.XXXXXX")"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

git -C "$ROOT" archive "$PROD_REF" godot | tar -x -C "$WORK"
cp "$ROOT"/godot/content/shells/"$ROOM"* "$WORK/godot/content/shells/"
python3 - "$ROOT/godot/content/registry/authored_art.json" \
  "$WORK/godot/content/registry/authored_art.json" "$ROOM" <<'EOF'
import json, sys
mine, theirs, rid = sys.argv[1:4]
entry = [e for e in json.load(open(mine))["entries"] if e["id"] == rid]
assert len(entry) == 1, "%s is not in %s" % (rid, mine)
entry[0]["review"] = "pass"   # the throwaway copy only; see the header
reg = json.load(open(theirs))
reg["entries"] = [e for e in reg["entries"] if e["id"] != rid] + entry
json.dump(reg, open(theirs, "w"), indent=2)
EOF
mkdir "$WORK/godot/_harness"
cp "$ROOT/tools/content/room_walk.gd" "$WORK/godot/_harness/room_walk.gd"
cat > "$WORK/godot/_harness/room_walk.tscn" <<'EOF'
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://_harness/room_walk.gd" id="1"]

[node name="RoomWalk" type="Node"]
script = ExtResource("1")
EOF

failed=0
# run <label> <pass-pattern> <engine args...>: prints the run's own lines,
# and fails it on a non-zero exit, a SCRIPT ERROR or a missing pass line.
run() {
  label="$1"; pass="$2"; shift 2
  log="$WORK/$label.log"
  set +e
  timeout --kill-after=15s "${ROOM_WALK_TIMEOUT:-1200}" "$@" >"$log" 2>&1
  status=$?
  set -e
  grep -E "^\[walk\]" "$log" || true
  verdict=ok
  if [ "$status" -ne 0 ]; then verdict="exit $status"; fi
  if grep -q "SCRIPT ERROR" "$log"; then verdict="SCRIPT ERROR"; fi
  if [ -n "$pass" ] && ! grep -q "$pass" "$log"; then
    verdict="${verdict}; no '$pass'"; fi
  if [ "$verdict" != ok ]; then
    failed=1
    echo "[room] $label FAILED ($verdict); log tail:"
    tail -n 25 "$log"
  else
    echo "[room] $label ok"
  fi
}

run import "" "$GODOT" --headless --path "$WORK/godot" --import
run walk "\[walk\] PASS" \
  "$GODOT" --headless --path "$WORK/godot" res://_harness/room_walk.tscn
run census "GODOT ROOM CONTRACT TESTS OK" \
  "$GODOT" --headless --path "$WORK/godot" -- --room-contract
# The suite's own verdict is not enough: it prints a PENDING shell's
# findings and still says OK, which is how the first census of this room
# passed with its reward inside the pier. The room's own line must be clean.
grep -E "$ROOM" "$WORK/census.log" | grep -vE "^(ERROR|WARNING|   at:)" \
  | sed 's/^/[census] /' || true
if grep -qE "^  $ROOM .* structural=0 measured=0\$" "$WORK/census.log"; then
  echo "[room] census: $ROOM built and audited clean"
else
  failed=1
  echo "[room] census: $ROOM has findings, or no census line at all"
fi
for door in entry exit; do
  if grep -E "^    crossed: " "$WORK/census.log" | grep -qF "\"$ROOM/$door ("; then
    echo "[room] census: a real body crossed $ROOM/$door onto its stub"
  else
    failed=1
    echo "[room] census: $ROOM/$door was not crossed"
  fi
done
if [ -n "$OUT" ]; then
  mkdir -p "$OUT"
  OUT="$(cd "$OUT" && pwd)"
  run shots "" xvfb-run -a "$GODOT" --path "$WORK/godot" \
    --rendering-driver opengl3 --resolution 1280x720 \
    res://_harness/room_walk.tscn -- --shots "$OUT"
fi

if [ "$failed" -ne 0 ]; then
  echo "[room] FAILED at Production $PROD_REF"
  exit 1
fi
echo "[room] PASS at Production $PROD_REF"
