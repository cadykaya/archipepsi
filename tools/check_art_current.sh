#!/usr/bin/env sh
# Fails when committed art does not match the source that generates it.
#
#   tools/check_art_current.sh
#
# ## Why this exists
#
# Generated assets go stale in silence. A model is built by one command and
# its review sheet by another; a pass that runs only the first leaves every
# sheet describing an object that no longer exists. Nothing fails: the build
# is deterministic, the tests are green, and the assets are simply older than
# their source. mario-3 carried a stale character through two commits that
# way and spent a three-worktree forensic audit establishing that nothing was
# wrong except the staleness.
#
# This is the two minutes that replaces all of that: rebuild everything, and
# fail if git sees a difference.
#
# ## What it covers
#
#   * every engineering number the art lane reads is still live
#   * the palette's anchors still match THEME_MATERIALS, every ramp still
#     contains its own anchor, and the value sandwich still holds
#   * the numbers ART_REVIEW.md and ASSET_INVENTORY.md quote match the build
#   * assets/art_budgets.json still matches its own derivation
#   * every .glb and .png rebuilds byte-identical from its source
#   * the preview project's renderer settings still match godot/'s
#   * files the build produces that were never committed at all, which
#     `git diff` cannot see
#
# NOT covered: the review sheets in docs/art/review/. They are renders, not
# build output, and re-rendering them is a 15-minute job -- but a stale .glb
# implies a stale sheet, and this catches the .glb.
#
# On failure the rebuilt assets are left in the working tree deliberately:
# `git diff` then shows exactly what was out of date.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
BLENDER="${BLENDER:-$ROOT/.tools/blender/blender}"
PATHS="assets/art_palette.json assets/art_budgets.json assets/models assets/textures"
status=0

say() { printf 'check-art: %s\n' "$1"; }
fail() { printf 'check-art: FAIL -- %s\n' "$1"; status=1; }

# --- 1. the numbers the art lane borrows -------------------------------
say "engineering numbers..."
python3 tools/blender/engine_truth.py >/dev/null || \
  fail "engine_truth: a value the art lane reads has moved. Run
    python3 tools/blender/engine_truth.py
  for the list. Update engine_truth, never the asset."

# --- 2. palette ---------------------------------------------------------
say "palette..."
python3 tools/blender/palette.py >/dev/null || \
  fail "palette: anchors drifted, a ramp lost its anchor, or a signalling
  colour stopped separating from a wall. Run
    python3 tools/blender/palette.py"

# --- 3. the documents quote the numbers the build actually produced -----
say "document metrics match the build..."
python3 tools/blender/check_docs_metrics.py >/dev/null || \
  fail "check_docs_metrics: a triangle count or measured size quoted in
  ART_REVIEW.md or ASSET_INVENTORY.md does not match the manifest. The
  owner's ledger is the one place a wrong number is invisible. Run
    python3 tools/blender/check_docs_metrics.py"

# --- 4. budgets still match their own derivation ------------------------
say "budgets match their derivation..."
cp assets/art_budgets.json /tmp/art_budgets_committed.json
python3 tools/blender/derive_budgets.py --write >/dev/null
if ! cmp -s assets/art_budgets.json /tmp/art_budgets_committed.json; then
  fail "assets/art_budgets.json no longer matches derive_budgets.py. Either a
  game dimension moved (good -- re-render everything) or somebody edited the
  JSON by hand (bad -- edit the derivation, or the reasoning stops being why
  and becomes decoration)."
  diff -u /tmp/art_budgets_committed.json assets/art_budgets.json | head -30 || true
fi

# --- 5. the preview project has not drifted from the game ---------------
say "preview renderer settings match godot/..."
for setting in "textures/canvas_textures/default_texture_filter=0"; do
  if grep -qF "$setting" godot/project.godot; then
    grep -qF "$setting" tools/artpreview/project.godot || \
      fail "tools/artpreview/project.godot is missing '$setting', which
  godot/project.godot sets. A preview that renders with different settings
  from the game is a camera that lies."
  else
    fail "godot/project.godot no longer sets '$setting'. The preview mirrors
  it; find out what replaced it before trusting another render."
  fi
done
if ! grep -q "f62fdbde1" tools/artpreview/project.godot; then
  fail "tools/artpreview/project.godot no longer records the pinned Godot
  build. The preview and the game must run the same engine."
fi

# --- 6. everything rebuilds byte-identical ------------------------------
if [ ! -x "$BLENDER" ]; then
  say "SKIPPED rebuild -- no blender at $BLENDER (set BLENDER=...)"
  say "  Everything above still ran."
  exit $status
fi

if ! git diff --quiet -- $PATHS; then
  say "SKIPPED rebuild -- generated assets are already modified in the tree."
  say "  Commit or stash them first; otherwise this cannot tell your edits"
  say "  from drift."
  exit 2
fi

# EVERY builder, not the ones that existed when this was written. The
# batch002 scripts were added and this loop was not, so the newest assets in
# the tree were the only ones nothing proved could be rebuilt -- the same
# shape of gap as L-33.
for script in build_materials build_architecture build_props \
              build_concept_epsilon build_concept_check build_concept_portal \
              build_concept_enemy build_concept_anchor \
              build_batch002_enemies build_epsilon_installation \
              build_hub; do
  say "rebuilding $script..."
  "$BLENDER" --background --python "tools/blender/$script.py" >/dev/null 2>&1 || \
    fail "$script.py did not complete. Run it directly for the traceback."
done

if ! git diff --quiet -- $PATHS; then
  fail "committed art is out of date with its source:"
  git diff --stat -- $PATHS | sed 's/^/    /'
  echo "    (rebuilt files left in the working tree; 'git diff' shows the drift)"
  echo "    Re-render the review sheets too: tools/batch001_sheets.sh"
fi

untracked=$(git ls-files --others --exclude-standard -- $PATHS)
if [ -n "$untracked" ]; then
  fail "the build produces files that were never committed:"
  echo "$untracked" | sed 's/^/    /'
fi

[ $status -eq 0 ] && say "PASS -- every generated asset matches its source."
exit $status
