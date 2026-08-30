#!/usr/bin/env sh
# Prove the exported pack against PRODUCTION'S OWN ContentRegistry.
#
#   tools/verify_content_pack.sh
#
# The validator is not a re-implementation of Production's rules -- it IS
# Production's file, fetched from the gameplay branch at run time into a
# throwaway harness and deleted afterwards. Nothing from the gameplay branch
# is ever committed to the art branch, and the gameplay branch is never
# written to.
#
# It also simulates the OTHER HALF of the handoff: Production renaming its six
# procedural `fixture_light_<theme>` ids to `<id>_proc` so the authored pack
# can take the canonical ids. Those two halves are ONE atomic change -- the
# registry refuses a duplicate id, so landing either half alone fails at load.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
PROD="${PROD_REF:-origin/claude/archipepsi-echoes-continuation-b1adno}"
H="$ROOT/godot/_harness"
[ -x "$GODOT" ] || { echo "verify-content: no godot at $GODOT" >&2; exit 2; }

cleanup() {
  rm -rf "$H"
  rm -f "$ROOT/godot/content/registry/legacy_procedural.json"
}
trap cleanup EXIT
cleanup
mkdir -p "$H"

# Production's validator, with only `class_name` stripped so it can be
# preloaded, and the six CLUSTER_* constants inlined because a `-s` script
# context has no autoloads. The pack declares no cluster, so that branch only
# has to compile. Every rule that runs is Production's, unedited.
git show "$PROD:godot/scripts/content/content_registry.gd" \
  | sed 's/^class_name ContentRegistry$//' \
  | python3 -c '
import sys
s = sys.stdin.read()
s = s.replace("extends RefCounted", "extends RefCounted\n"
    "const CLUSTER_ANCHORS = [\"floor_wall\", \"floor_corner\", \"wall\", \"ceiling\"]\n"
    "const CLUSTER_FLOOR_ANCHORS = [\"floor_wall\", \"floor_corner\"]\n"
    "const CLUSTER_MAX_DEPTH = 2.5\nconst CLUSTER_MAX_HEIGHT = 4.0\n"
    "const CLUSTER_MAX_WIDTH = 6.0\nconst CLUSTER_MOUNTED_UNDERSIDE_MIN = 2.75\n", 1)
s = s.replace("Constants.CLUSTER_", "CLUSTER_")
sys.stdout.write(s)' > "$H/content_registry.gd"

git show "$PROD:godot/scripts/content/visual_ownership.gd" \
  | sed 's/^class_name VisualOwnership$//' > "$H/visual_ownership.gd"

git show "$PROD:godot/content/registry/legacy_procedural.json" | python3 -c '
import json, sys
d = json.load(sys.stdin)
for e in d["entries"]:
    if e["id"].startswith("fixture_light_"):
        e["id"] += "_proc"
json.dump(d, open(sys.argv[1], "w"), indent=1)
' "$ROOT/godot/content/registry/legacy_procedural.json"

cp "$ROOT/tools/content/verify_pack.gd" "$H/verify.gd"
xvfb-run -a -s "-screen 0 1280x800x24" "$GODOT" --headless --path "$ROOT/godot" \
  -s _harness/verify.gd 2>&1 | grep -E "^\[verify\]|SCRIPT ERROR" || true
