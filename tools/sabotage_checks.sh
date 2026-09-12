#!/usr/bin/env sh
# Prove every art guard can actually fail.
#
#   tools/sabotage_checks.sh
#
# > **A check that has never failed is unverified.**
#
# Each case below reintroduces the exact bug a guard was written to catch and
# confirms the guard fires. A guard that stays silent here is worse than no
# guard, because it converts an open question into a false certainty.
#
# Every edit is made to a COPY under /tmp or reverted immediately; the
# working tree is restored on exit whatever happens, including on a failure
# or an interrupt.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
WORK="$(mktemp -d)"
FAILED=0
CASE=0

# Every case here restores with `git checkout --`, which DISCARDS uncommitted
# work in the files it touches. That is not hypothetical: this script silently
# reverted a two-line correction to ASSET_INVENTORY.md that had been made and
# not yet committed, and the next run then failed its own clean-tree baseline
# on numbers the author had already fixed. Refuse to run rather than eat
# somebody's edit.
TOUCHED="godot/scripts/gameplay/player.gd
godot/scripts/generation/affordance_features.gd
godot/scripts/enemies/enemy.gd
assets/art_palette.json
docs/art/ART_REVIEW.md
docs/art/ASSET_INVENTORY.md"
if ! git diff --quiet -- $TOUCHED; then
  echo "sabotage: REFUSING TO RUN -- these files have uncommitted changes and"
  echo "  this script restores them with 'git checkout', which would discard"
  echo "  your edits:"
  git diff --name-only -- $TOUCHED | sed 's/^/    /'
  echo "  Commit or stash them first."
  exit 2
fi

restore() {
  # Restore anything this script touched, from git, unconditionally.
  git checkout -- godot/scripts/gameplay/player.gd \
                  godot/scripts/generation/affordance_features.gd \
                  godot/scripts/enemies/enemy.gd \
                  assets/art_palette.json \
                  docs/art/ART_REVIEW.md \
                  docs/art/ASSET_INVENTORY.md 2>/dev/null || true
  rm -rf "$WORK"
}
trap restore EXIT INT TERM

expect_fail() { # <name> <command...>
  CASE=$((CASE + 1))
  name="$1"; shift
  if "$@" >"$WORK/out" 2>&1; then
    printf '  %-52s NOT CAUGHT\n' "$name"
    echo "      the guard passed while the bug was present -- it is not a guard"
    FAILED=$((FAILED + 1))
  else
    printf '  %-52s caught\n' "$name"
  fi
}

expect_pass() { # <name> <command...>
  CASE=$((CASE + 1))
  name="$1"; shift
  if "$@" >"$WORK/out" 2>&1; then
    printf '  %-52s clean\n' "$name"
  else
    printf '  %-52s FALSE POSITIVE\n' "$name"
    echo "      a guard fails the thing it was written to protect; it is"
    echo "      measuring the wrong edge. Output:"
    sed 's/^/      /' "$WORK/out" | head -12
    FAILED=$((FAILED + 1))
  fi
}

echo "sabotage: baseline -- every guard must pass a clean tree first"
expect_pass "engine_truth on a clean tree" python3 tools/blender/engine_truth.py
expect_pass "palette on a clean tree"      python3 tools/blender/palette.py

echo
echo "sabotage: engine_truth -- does it notice engineering moving a number?"

sed -i 's/camera.fov = 90.0/camera.fov = 75.0/' godot/scripts/gameplay/player.gd
expect_fail "camera FOV 90 -> 75" python3 tools/blender/engine_truth.py
git checkout -- godot/scripts/gameplay/player.gd

sed -i 's/"grapple_anchor": {"half_width": 0.7, "half_depth": 0.7, "height": 5.6}/"grapple_anchor": {"half_width": 0.9, "half_depth": 0.7, "height": 5.6}/' \
  godot/scripts/generation/affordance_features.gd
expect_fail "grapple anchor footprint 0.7 -> 0.9" python3 tools/blender/engine_truth.py
git checkout -- godot/scripts/generation/affordance_features.gd

sed -i 's/"brute": size = Vector3(1.8, 2.6, 1.8)/"brute": size = Vector3(2.0, 2.6, 1.8)/' \
  godot/scripts/enemies/enemy.gd
expect_fail "brute collision box widened" python3 tools/blender/engine_truth.py
git checkout -- godot/scripts/enemies/enemy.gd

echo
echo "sabotage: palette -- drift, lost anchors, and unreadable interactables"

python3 - <<'PY'
import json
p = "assets/art_palette.json"
d = json.load(open(p))
d["engine_anchors"]["concrete_facility"]["base_color"] = "#ff0000"
json.dump(d, open(p, "w"), indent=2)
PY
expect_fail "theme anchor drifted from THEME_MATERIALS" python3 tools/blender/palette.py
git checkout -- assets/art_palette.json

python3 - <<'PY'
import json
p = "assets/art_palette.json"
d = json.load(open(p))
# A ramp that no longer contains the colour the engine paints with.
d["themes"]["void_glitch"]["trim"]["ramp"] = ["#001a14", "#002a20", "#00382b"]
json.dump(d, open(p, "w"), indent=2)
PY
expect_fail "ramp no longer contains its own anchor" python3 tools/blender/palette.py
git checkout -- assets/art_palette.json

python3 - <<'PY'
import json
p = "assets/art_palette.json"
d = json.load(open(p))
# Two adjacent steps at the same value: the greyscale-mush failure.
ramp = d["themes"]["concrete_facility"]["base"]["ramp"]
ramp[0] = ramp[1]
json.dump(d, open(p, "w"), indent=2)
PY
expect_fail "two ramp steps with no value separation" python3 tools/blender/palette.py
git checkout -- assets/art_palette.json

python3 - <<'PY'
import json
p = "assets/art_palette.json"
d = json.load(open(p))
# A signal family with no step that separates from any wall: the Check
# that vanishes into one theme's walls.
base = d["themes"]["concrete_facility"]["base"]["anchor"]
trim = d["themes"]["concrete_facility"]["trim"]["anchor"]
d["universal"]["signal"]["ramp"] = [base, base, trim, trim]
json.dump(d, open(p, "w"), indent=2)
PY
expect_fail "signal colour indistinguishable from a wall" python3 tools/blender/palette.py
git checkout -- assets/art_palette.json

python3 - <<'PYX'
import json
p = "assets/art_palette.json"
d = json.load(open(p))
# The drift the hue rule exists to catch: Epsilon's green sliding into
# void_glitch's cyan, where "you can use this", "Epsilon" and "cosmetic
# corruption" stop being nameable as different colours.
d["universal"]["identity"]["anchor"] = "#00ffbf"
json.dump(d, open(p, "w"), indent=2)
PYX
expect_fail "Epsilon green drifts into the cyan family" python3 tools/blender/palette.py
git checkout -- assets/art_palette.json

echo
echo "sabotage: the owner's ledger -- does a wrong number get caught?"
expect_pass "document metrics on a clean tree" python3 tools/blender/check_docs_metrics.py

# `sed` that matches nothing exits 0 and changes nothing, so a sabotage case
# whose pattern goes stale stops sabotaging and the guard it is testing
# reports NOT CAUGHT -- which reads as the guard being broken. Both cases
# below did exactly that when the inventory table's shape changed. Every
# edit is now verified to have landed before the guard is asked about it.
sabotage_edit() { # <file> <sed-expr>
  before=$(md5sum "$1" | cut -d" " -f1)
  sed -i "$2" "$1"
  after=$(md5sum "$1" | cut -d" " -f1)
  if [ "$before" = "$after" ]; then
    printf '  %-52s STALE CASE\n' "sabotage of $1 changed nothing"
    echo "      the pattern no longer matches; this case tests nothing"
    FAILED=$((FAILED + 1))
    return 1
  fi
}

if sabotage_edit docs/art/ART_REVIEW.md 's/| 300 tris/| 299 tris/'; then
  expect_fail "a triangle count mistyped in ART_REVIEW.md" \
    python3 tools/blender/check_docs_metrics.py
fi
git checkout -- docs/art/ART_REVIEW.md

if sabotage_edit docs/art/ASSET_INVENTORY.md 's/1.04 × 1.04 × 1.01/1.04 × 1.04 × 1.10/'; then
  expect_fail "a measured size mistyped in ASSET_INVENTORY.md" \
    python3 tools/blender/check_docs_metrics.py
fi
git checkout -- docs/art/ASSET_INVENTORY.md

echo
echo "sabotage: the build-time asserts -- fired from a throwaway script"

BLENDER="${BLENDER:-$ROOT/.tools/blender/blender}"
if [ ! -x "$BLENDER" ]; then
  echo "  (skipped: no blender at $BLENDER)"
else
  run_case() { # <name> <python>
    printf '%s\n' "$2" > "$WORK/case.py"
    if "$BLENDER" -b --python "$WORK/case.py" 2>&1 | grep -q "GUARD FIRED"; then
      printf '  %-52s caught\n' "$1"
    else
      printf '  %-52s NOT CAUGHT\n' "$1"
      FAILED=$((FAILED + 1))
    fi
    CASE=$((CASE + 1))
  }

  PRE='import sys, os
sys.path.insert(0, os.path.join(os.getcwd(), "tools", "blender"))
import common, brushkit
common.reset_scene()
try:
'
  # TypeError and KeyError count. `speckle` enforces its structural zone by
  # REQUIRING the argument rather than by raising -- the guard IS the
  # signature. A harness catching only AssertionError reported NOT CAUGHT
  # for a guard that was working perfectly: the same class of mistake as a
  # filter that cannot express failure, inverted.
  POST='
except (AssertionError, ValueError, TypeError, KeyError) as exc:
    print("GUARD FIRED:", type(exc).__name__, exc)
else:
    print("NO GUARD")
'
  run_case "triangle budget exceeded" "$PRE    obj = brushkit.prism('x', 1.0, 1.0, 8)
    for i in range(60):
        brushkit.prism('y%d' % i, 0.1, 0.2, 8, (i * 0.3, 0, 0))
    import bpy
    objs = [o for o in bpy.data.objects if o.type == 'MESH']
    joined = common.join(objs, 'over')
    common.assert_budget(joined, 'over', 'architecture_module')$POST"

  run_case "smooth shading on a hard surface" "$PRE    obj = brushkit.block('x', (1, 1, 1))
    for poly in obj.data.polygons:
        poly.use_smooth = True
    common.assert_flat(obj, 'x')$POST"

  run_case "radial segment cap exceeded" "$PRE    brushkit.prism('x', 0.5, 1.0, 24, asset_name='x')$POST"

  run_case "asset outgrows its mechanical box" "$PRE    obj = brushkit.block('x', (2.0, 1.0, 1.0))
    common.assert_fits(obj, 'x', (1.4, 1.4, None), 'PROP_FOOTPRINT.')$POST"

  run_case "texel density outside its tier band" "$PRE    obj = brushkit.block('x', (4.0, 0.4, 4.0), (0, 0, 2.0))
    common.set_origin(obj, 'floor')
    common.uv_project_world(obj, 8, 128)
    common.assert_texel_density(obj, 'x', 'architecture', 128)$POST"

  run_case "stair rise above MAX_VERTICAL_STEP" "$PRE    brushkit.stair('x', 0.4, 1.6, 2.0, 4)$POST"

  run_case "speckle without a structural zone" "$PRE    import paintkit, palette as pal
    surf = paintkit.Surface(64, 2.0, 'wall')
    canvas = paintkit.Canvas(64, pal.grime(1))
    paintkit.speckle(canvas, surf, pal.grime(0))
    raise ValueError('speckle accepted a call with no zone: the API that '
                     'made digital camouflage possible is back')$POST"
fi

echo
echo "sabotage: the offer gate -- can it refuse the art it was built from?"
# IN-PROCESS, NOT IN-TREE. Every other case here edits a source file and
# puts it back with `git checkout`, which is right for a guard that reads
# source and wrong for this one: the declarations under test live in the
# pack's generated manifests, and a script that checks out a manifest can
# eat an export somebody has not committed. `sabotage_offers.py`
# substitutes each bug in memory, so nothing is written and nothing is
# restored. It reports its own cases; this only asks whether they all
# behaved.
expect_pass "every offer-gate negative control" \
  python3 tools/content/sabotage_offers.py

echo
if [ "$FAILED" -gt 0 ]; then
  echo "sabotage: FAIL -- $FAILED of $CASE case(s) did not behave. A guard that"
  echo "  cannot fail is not a guard, and one that fails a clean tree is"
  echo "  measuring the wrong edge."
  exit 1
fi
echo "sabotage: PASS -- all $CASE cases behaved. Every guard fires on its own bug."
