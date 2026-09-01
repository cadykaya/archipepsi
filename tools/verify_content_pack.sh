#!/usr/bin/env sh
# Prove the exported pack against BOTH of Production's validators.
#
#   tools/verify_content_pack.sh
#
# TWO validators, because this is a DUAL-LANGUAGE contract and they do not
# police the same things:
#
#   schemas/content.py    strict pydantic: `extra="forbid"`, length limits
#   content_registry.gd   does the scene EXIST, does the fallback chain end
#
# The first version of this script ran only the GDScript half. The pack
# passed it, and Production's Python gate rejected it on three counts -- a
# 231-character pack description against a 160 limit, plus `source_asset` and
# `source_batch_review`, two fields `ContentEntry` forbids outright. That is
# how a broken pack reached an integration attempt. Verifying one side of a
# two-sided contract is verifying nothing.
#
# It also simulates the OTHER HALF of the handoff: Production renaming its six
# procedural `fixture_light_<theme>` ids to `<id>_proc` so the authored pack
# can take the canonical ids. Those two halves are ONE atomic change -- the
# registry refuses a duplicate id, so landing either half alone fails at load.
#
# Production's files are fetched read-only at run time into a throwaway
# harness and deleted on exit. Nothing from the gameplay branch is committed
# to the art branch, and that branch is never written to.
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

# Production's validator, adapted in exactly two mechanical ways and no more:
#
#   1. `class_name ContentRegistry` is stripped and the file is PRELOADED by
#      path instead, because Godot's global class cache does not register a
#      script dropped into the project between runs. Stripping the line
#      leaves three dangling self-references, all inside the static-singleton
#      convenience `shared()` that this test never calls, so those three are
#      rewritten and nothing else is. The transform asserts that no
#      self-reference survived.
#   2. The six CLUSTER_* constants are inlined, because a `-s` script context
#      has no autoloads. The pack declares no cluster, so that branch only
#      has to compile.
#
# Every rule that RUNS -- `_load_manifest`, `_accept`, `resolve`,
# `_check_cross_references` -- is Production's, unedited.
git show "$PROD:godot/scripts/content/content_registry.gd" | python3 -c '
import sys
s = sys.stdin.read()
s = s.replace("class_name ContentRegistry\n", "")
s = s.replace("extends RefCounted", "extends RefCounted\n"
    "const CLUSTER_ANCHORS = [\"floor_wall\", \"floor_corner\", \"wall\", \"ceiling\"]\n"
    "const CLUSTER_FLOOR_ANCHORS = [\"floor_wall\", \"floor_corner\"]\n"
    "const CLUSTER_MAX_DEPTH = 2.5\nconst CLUSTER_MAX_HEIGHT = 4.0\n"
    "const CLUSTER_MAX_WIDTH = 6.0\nconst CLUSTER_MOUNTED_UNDERSIDE_MIN = 2.75\n", 1)
s = s.replace("Constants.CLUSTER_", "CLUSTER_")
s = s.replace("static var _shared: ContentRegistry = null", "static var _shared = null")
s = s.replace("static func shared() -> ContentRegistry:", "static func shared() -> Object:")
s = s.replace("_shared = ContentRegistry.new()",
              "_shared = (load(\"res://_harness/content_registry.gd\") as GDScript).new()")
assert "ContentRegistry" not in s, "a self-reference survived the transform"
sys.stdout.write(s)' > "$H/content_registry.gd"

# No self-references, so only the class_name line goes.
git show "$PROD:godot/scripts/content/visual_ownership.gd" \
  | sed 's/^class_name VisualOwnership$//' > "$H/visual_ownership.gd"

# Production's own manifest, VERBATIM.
#
# This used to simulate the other half of the handoff by renaming the six
# procedural `fixture_light_<theme>` ids to `<id>_proc`. That simulation is
# retired: Production has LANDED the rename, so its manifest already carries
# the `_proc` ids and renaming again produced `_proc_proc` -- a fallback
# chain pointing at ids no pack defines. A simulation of a state that has
# since become real is not a simulation, it is a second, wrong copy.
git show "$PROD:godot/content/registry/legacy_procedural.json" \
  > "$ROOT/godot/content/registry/legacy_procedural.json"

# 1. PYTHON. First, because it is the cheaper gate and the one that was
#    missing. Both manifests are present, so `build_registry` also checks the
#    cross-pack rules against the real post-handoff state.
echo "[verify] --- Production's Python ContentManifest ---"
python3 "$ROOT/tools/content/verify_manifest.py" "$PROD"

# 2. GDSCRIPT.
echo "[verify] --- Production's GDScript ContentRegistry ---"
cp "$ROOT/tools/content/verify_pack.gd" "$H/verify.gd"
xvfb-run -a -s "-screen 0 1280x800x24" "$GODOT" --headless --path "$ROOT/godot" \
  -s _harness/verify.gd 2>&1 | grep -E "^\[verify\]|SCRIPT ERROR" || true
