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
#      P2-C ADDED A SECOND AUTOLOAD REFERENCE. `eda4fd9` validates
#      `fits_floors` against `Constants.TOWER_MIN_FLOORS/MAX_FLOORS`, and
#      the harness broke on it -- a compile error, not a failed rule, so
#      it would have read as "the validator is unhappy" if the log had
#      not been looked at. The inlined constants are now READ FROM
#      PRODUCTION'S OWN `constants.gd` rather than retyped, so the next
#      one to move cannot silently make this harness test a different
#      number than the game does.
git show "$PROD:godot/scripts/autoload/constants.gd" > "$H/prod_constants.gd"
git show "$PROD:godot/scripts/content/content_registry.gd" | python3 -c '
import re, sys
s = sys.stdin.read()
with open(sys.argv[1]) as fh:
    src = fh.read()
wanted = sorted(set(re.findall(r"Constants\.([A-Z][A-Z0-9_]*)", s)))
inlined = []
for name in wanted:
    hit = re.search(r"^const %s\s*(?::\s*\w+\s*)?:?=\s*(.+)$" % name,
                    src, re.M)
    if hit is None:
        raise SystemExit(
            "verify-content: Production references Constants.%s and its "
            "own constants.gd does not define it" % name)
    inlined.append("const %s = %s" % (name, hit.group(1).split("#")[0].strip()))
s = s.replace("class_name ContentRegistry\n", "")
s = s.replace("extends RefCounted",
              "extends RefCounted\n" + "\n".join(inlined) + "\n", 1)
s = s.replace("Constants.", "")
s = s.replace("static var _shared: ContentRegistry = null", "static var _shared = null")
s = s.replace("static func shared() -> ContentRegistry:", "static func shared() -> Object:")
s = s.replace("_shared = ContentRegistry.new()",
              "_shared = (load(\"res://_harness/content_registry.gd\") as GDScript).new()")
assert "ContentRegistry" not in s, "a self-reference survived the transform"
assert "Constants." not in s, "an autoload reference survived the transform"
sys.stdout.write(s)' "$H/prod_constants.gd" > "$H/content_registry.gd"

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

# 3. COLLISION. Not Production's validator -- ours, and the reason it
# exists is that neither of theirs can catch this. A shell with perfect
# metadata and no colliders passes both checks above and then measures as
# 625 findings of "nothing is there", which is what happened at eda4fd9.
# Loads the real shipped .tscn, counts real CollisionShape3Ds, and fires
# RoomAudit's own probe at every declared surface. Reports; never PASSes.
echo "[verify] --- collision in the shipped scenes (art-side evidence) ---"
cp "$ROOT/tools/content/verify_collision.gd" "$H/collision.gd"
xvfb-run -a -s "-screen 0 1280x800x24" "$GODOT" --headless --path "$ROOT/godot" \
  -s _harness/collision.gd 2>&1 | grep -E "^\[collision\]|SCRIPT ERROR" || true

# 4. SHELL VALIDATOR. Production's, and the rule that matters here is
# `_check_segment`: a mandatory traversal is measured from its markers in
# the scene against `Constants.max_safe_gap`, and one with no markers is
# refused rather than assumed good. Stages 1-3 never reach it -- the
# Python schema checks the DECLARED numbers, the registry checks loading,
# the collision stage checks surfaces -- so a shell could pass all three
# and be refused the moment Production instantiated it. P2's eight never
# exercised it because every mandatory segment in them was a 1.0 m stone.
#
# Transformed like `content_registry.gd` above and no further:
#
#   1. `class_name` stripped, loaded by path.
#   2. `Constants` becomes an INSTANCE of Production's own constants.gd
#      (it `extends Node`, and `max_safe_gap` is a plain method), so the
#      numbers and the function are theirs, not retyped.
#   3. `RoomContract.envelope(x)` is substituted with its own one-line
#      body, `x.grow(WALL_ALLOWANCE)`, and `WALL_ALLOWANCE` /
#      `FLOOR_ALLOWANCE` are READ from Production's `room_contract.gd`,
#      `chamber_builders.gd` and `content_instantiator.gd`. Loading
#      `room_contract.gd` itself would pull in `ChamberBuilders` at
#      const-init, and that chain is three files deep for two floats.
#   4. `catalog()`'s `ContentRegistry` parameter type becomes `Object`.
#      That function is selection, not validation, and nothing here calls
#      it; it only has to compile.
#
# Every rule that RUNS -- `refusals`, `_check_segment`, `_check_sockets`,
# `_check_envelope`, `mesh_boxes` -- is Production's, unedited.
echo "[verify] --- Production's ShellValidator on the shipped scenes ---"
git show "$PROD:godot/scripts/content/room_contract.gd" > "$H/prod_room_contract.gd"
git show "$PROD:godot/scripts/generation/chamber_builders.gd" > "$H/prod_chambers.gd"
git show "$PROD:godot/scripts/content/content_instantiator.gd" > "$H/prod_instantiator.gd"
git show "$PROD:godot/scripts/content/shell_validator.gd" | python3 -c '
import re, sys
s = sys.stdin.read()


def const(path, name):
    with open(path) as fh:
        hit = re.search(r"^const %s\s*(?::\s*\w+\s*)?:?=\s*(.+)$" % name,
                        fh.read(), re.M)
    if hit is None:
        raise SystemExit("verify-content: %s does not define %s"
                         % (path, name))
    return hit.group(1).split("#")[0].strip()


# RoomContract.WALL_ALLOWANCE is `ChamberBuilders.WALL_THICKNESS + 0.15`,
# so it is COMPOSED from Production the same way Production composes it.
expr = const(sys.argv[1], "WALL_ALLOWANCE")
wall = expr.replace("ChamberBuilders.WALL_THICKNESS",
                    const(sys.argv[2], "WALL_THICKNESS"))
if re.search(r"[A-Za-z_]", wall):
    raise SystemExit("verify-content: WALL_ALLOWANCE still references "
                     "something this harness has not resolved: %s" % wall)
floor = const(sys.argv[3], "FLOOR_ALLOWANCE")

s = s.replace("class_name ShellValidator\n", "")
s = s.replace("extends RefCounted",
              "extends RefCounted\n"
              "const WALL_ALLOWANCE = %s\n" % wall
              + "const FLOOR_ALLOWANCE = %s\n" % floor
              + "static var Constants = "
                "(load(\"res://_harness/prod_constants.gd\") "
                "as GDScript).new()\n", 1)
s = s.replace("ContentInstantiator.FLOOR_ALLOWANCE", "FLOOR_ALLOWANCE")
s = s.replace("RoomContract.WALL_ALLOWANCE", "WALL_ALLOWANCE")
# `RoomContract.envelope` is one line -- `return bounds.grow(WALL_ALLOWANCE)`
# -- and it is copied as that line rather than spliced into the call site,
# so the substitution does not depend on how the argument is wrapped.
s = s.replace("RoomContract.envelope(", "_envelope(")
s += """

static func _envelope(bounds: AABB) -> AABB:
\treturn bounds.grow(WALL_ALLOWANCE)
"""
s = s.replace("registry: ContentRegistry", "registry: Object")
# Two type inferences that only break BECAUSE of the substitutions
# above, widened to the declared types Production already gives them.
# `max_safe_gap` returns float and `get_entry` returns Dictionary in
# Production; here they come off an untyped `Object`, so `:=` has
# nothing to infer from. Nothing else about either line changes, and
# both are asserted below so a rename cannot make this a silent no-op.
for was, now in [
        ("\tvar allowed := Constants.max_safe_gap(",
         "\tvar allowed: float = Constants.max_safe_gap("),
        ("\t\tvar entry := registry.get_entry(id)",
         "\t\tvar entry: Dictionary = registry.get_entry(id)")]:
    if was not in s:
        raise SystemExit("verify-content: the ShellValidator transform "
                         "expected to widen %r and did not find it" % was)
    s = s.replace(was, now)
code = "\n".join(ln.split("#")[0] for ln in s.splitlines())
for gone in ["RoomContract", "ContentInstantiator", "ContentRegistry"]:
    if gone in code:
        raise SystemExit("verify-content: %s survived the ShellValidator "
                         "transform" % gone)
sys.stdout.write(s)' "$H/prod_room_contract.gd" "$H/prod_chambers.gd" \
  "$H/prod_instantiator.gd" > "$H/shell_validator.gd"
cp "$ROOT/tools/content/verify_shells.gd" "$H/shells.gd"
xvfb-run -a -s "-screen 0 1280x800x24" "$GODOT" --headless --path "$ROOT/godot" \
  -s _harness/shells.gd 2>&1 | grep -E "^\[shells\]|SCRIPT ERROR" || true
