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
#   * every shell's material names still resolve to a theme role, and every
#     theme still carries every role a shell uses
#   * every declared runtime size and attachment point still matches the
#     geometry that was exported
#   * assets/art_budgets.json still matches its own derivation
#   * the asset interface BATCH_043_INTEGRATION.md quotes still holds
#   * every shell doorway is on its own room, through a clear opening, and
#     has a floor under it -- and a player-shaped body can walk each
#     repaired join, placed and yawed
#   * every builder on disk is in the rebuild list, so none is silently
#     exempt from the line below
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
#: This script's own absolute path, captured BEFORE the cd. The coverage
#: gate below reads it, and a hardcoded name would make a sabotaged copy
#: grade the original -- which is a check that cannot be tested.
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
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
# The theme role convention, over EVERY shell on disk rather than a list.
# Cheap, and gap 2 of the theme-pack queue: nothing else stops the next
# builder naming a surface something no binder can resolve.
python3 tools/content/check_theme_roles.py >/dev/null || \
  fail "check_theme_roles: a shell carries a material name that resolves to
    no theme role, or a theme is short a role a shell uses. Run

    python3 tools/content/check_theme_roles.py"

# Theme-pack gap 3's unblocked half: the six-theme texture set as a
# shippable thing, and one description a binder could be written against.
# Where it lands is Production's and nothing here decides it.
python3 tools/content/verify_theme_set.py >/dev/null || \
  fail "verify-theme-set: the six-theme texture set is short a required
    role, a theme has painted a universal one, or THEME_PACK.json no longer
    matches the set. Run

    python3 tools/content/verify_theme_set.py"

# The exported theme pack against the set it came from, and against the
# digests Production's loader refuses on. Gap 3's shipping half.
python3 tools/content/verify_theme_export.py >/dev/null || \
  fail "verify-theme-export: godot/content/theme/ is stale, a digest no
    longer matches its descriptor row, or a sidecar is missing or is
    importing without mipmaps. Re-export and re-import:

    python3 tools/export_content_pack.py && tools/import_godot_content.sh"

# The Batch 043 candidates' declared geometry against what was exported.
python3 tools/content/verify_exported_geometry.py >/dev/null || \
  fail "verify-geometry: a declared runtime size or attachment point
    disagrees with the exported .glb. Run

    python3 tools/content/verify_exported_geometry.py"

# Every shell doorway against the geometry it was exported from. Three
# shells shipped an `exit` 2 m past their own back wall and twelve shells
# passed every other check, because every other shell rule is about a SPAN
# and this one is about a POINT.
# The doorway checker against geometry built to make it fail, before it is
# trusted on geometry we believe. Its aperture probe stepped the wrong way
# for a while and no shipped shell could have shown it.
python3 tools/content/test_measure_doorways.py >/dev/null || \
  fail "test-doorways: the doorway checker no longer tells an open doorway
    from a blocked one, in one of the four wall orientations. Run

    python3 tools/content/test_measure_doorways.py"

python3 tools/content/measure_doorways.py >/dev/null || \
  fail "measure-doorways: a shell doorway is outside its own room, blocked,
    or standing over nothing -- or a finding listed as KNOWN was repaired
    and its line was left behind. Run

    python3 tools/content/measure_doorways.py"

# Theme-pack gap 4: the theme is an argument, and a non-default one must
# not be able to reach the shipped pack.
# Ordinary decoration may not impersonate a signal. Fast, and it was not
# being run by anything at all -- see the coverage gate below.
python3 tools/content/check_decal_colours.py >/dev/null || \
  fail "decal-colours: a decal has drifted into one of the six reserved
    universal colours, so ordinary dirt now reads as interactive. Run

    python3 tools/content/check_decal_colours.py"

# The exported content pack against its manifests and markers. This is
# where verify_manifest.py and verify_markers.py are reached.
tools/verify_content_pack.sh >/dev/null 2>&1 || \
  fail "verify-content-pack: the exported pack no longer matches its
    manifests or its markers. Run

    tools/verify_content_pack.sh"

python3 tools/content/verify_theme_argument.py >/dev/null || \
  fail "verify-theme: the default build no longer writes the shipped pack, a
    --theme run can reach it, or an unknown theme builds instead of being
    refused. Run

    python3 tools/content/verify_theme_argument.py"

python3 tools/blender/derive_budgets.py --write >/dev/null
if ! cmp -s assets/art_budgets.json /tmp/art_budgets_committed.json; then
  fail "assets/art_budgets.json no longer matches derive_budgets.py. Either a
  game dimension moved (good -- re-render everything) or somebody edited the
  JSON by hand (bad -- edit the derivation, or the reasoning stops being why
  and becomes decoration)."
  diff -u /tmp/art_budgets_committed.json assets/art_budgets.json | head -30 || true
fi

# --- 4b. the exported asset interface still matches the handoff ---------
# BATCH_043_INTEGRATION.md quotes this script's measurements as the contract
# Production imports against. It exits non-zero on a missing model, a renamed
# part, a short result or a moved end stop, so it is worth running rather
# than merely quoting. Needs the engine; skipped without it, like the
# rebuild below.
if [ -x "${GODOT:-$ROOT/.tools/godot}" ]; then
  say "the Batch 043 import examples..."
  tools/content/run_import_examples.sh >/dev/null 2>&1 || \
    fail "import_examples: the asset interface quoted in
    docs/art/BATCH_043_INTEGRATION.md no longer matches the exported assets.
    Run

    tools/content/run_import_examples.sh"

  say "the repaired doorway crossings..."
  tools/content/run_crossing_test.sh >/dev/null 2>&1 || \
    fail "crossing: a player-shaped body can no longer walk one of the three
    repaired joins, at the origin or placed and yawed. Run

    tools/content/run_crossing_test.sh"

  # The exported pack ACTUALLY BINDING, which no Python validator reaches:
  # between the last byte on disk and a wall in a room there is an
  # importer, a loader, a sampler and a UV scale, and the shipped
  # ThemeMaterials is procedural, so a Zone builds the same whether the
  # pack is there or not. Runs three controls that move real files aside
  # and put them back.
  # Every opening's OWN arrival region, by Production's own rule. A
  # single generic region is the pre-§11.3 behaviour: one answer for
  # however many doors a room has.
  say "per-socket arrival regions..."
  tools/content/run_arrival_test.sh >/dev/null 2>&1 || \
    fail "arrival: an opening has no arrival region named after it, or a
    declared region is unsupported, blocked, or cannot be walked into the
    room from. Run

    tools/content/run_arrival_test.sh"

  # A setpiece that does not fit is not a visual problem, it is a
  # gameplay one: an oversize deck fouls a dock, an undersize crate stops
  # being a 1.0 m step, and a collider riding in on a "visual" changes
  # what Production owns. The envelope numbers are read from their
  # constants, not restated here.
  say "the 0.4 setpiece visuals still fit Production's envelope..."
  tools/content/run_setpiece_fit.sh >/dev/null 2>&1 || \
    fail "setfit: a setpiece visual no longer imports, lost a named part,
    left Production's envelope, or brought a collider, body, light, camera
    or script along with it. Run

    tools/content/run_setpiece_fit.sh"

  # The yard kit is fitted to a curve that cannot be restated, only
  # evaluated -- the gap the span bridges is 14.048 m and no constant in
  # railway_scenario.gd says so. A builder that drifts back to a
  # remembered number exports a span 48 mm short of the far rail, which
  # is exactly what a sabotage run produced. This is what caught it.
  say "the yard kit still fits the MEASURED Blindside yard..."
  tools/content/run_yardkit_fit.sh >/dev/null 2>&1 || \
    fail "yardfit: a yard visual no longer imports, lost a named part,
    stopped fitting the measured yard, or brought a collider, body,
    light, camera or script along with it. Run

    tools/content/run_yardkit_fit.sh"

  # A vehicle that turns cannot be checked by a still. The carrier
  # yaws through the corner, so a fitting that clears a dock at S1 may
  # not clear one at S2 -- and the sweep is the only thing that asks.
  say "the loaded skiff still sweeps the route without fouling a dock..."
  tools/content/run_skiff_sweep.sh >/dev/null 2>&1 || \
    fail "sweep: a fitting on the skiff now enters a dock pad somewhere
    on the route, or a rider can no longer see over the cover. Run

    tools/content/run_skiff_sweep.sh"

  # The roster has to survive Production's consumer, not only the
  # build-time envelope assert. This is where the damage-tint finding
  # lives, and it will turn from a note into a pass the moment
  # _collect_tint_parts also considers surface materials.
  say "the ten enemy roles against their published envelopes..."
  tools/content/run_enemy_readiness.sh >/dev/null 2>&1 || \
    fail "enemyready: a role no longer imports, left its published
    envelope, lost a declared anchor, or grew one that stands proud of
    the body. Run

    tools/content/run_enemy_readiness.sh"

  # A06-A08's promises are sentences in an assignment until something
  # checks them: eight pips against OPEN_SECONDS, a class read that is
  # not a kilogram gauge, a lane marking under the shot line, and a
  # return gate with no tread on it.
  say "the other three 0.4 rooms keep their kits' promises..."
  tools/content/run_roomkit_fit.sh >/dev/null 2>&1 || \
    fail "roomfit: a room visual no longer imports, lost a named part,
    broke one of the A06-A08 promises, or brought a collider, light,
    camera, script or animation along with it. Run

    tools/content/run_roomkit_fit.sh"

  # A09's distinctions are the deliverable: a band that keeps Batch
  # 043's face, three commitments that cannot be confused, and labels
  # nobody baked.
  say "the cross-room kit keeps A09's distinctions..."
  tools/content/run_connect_fit.sh >/dev/null 2>&1 || \
    fail "connfit: a connection visual no longer imports, its band
    stopped matching Batch 043's run face, two of the three commitments
    became the same shape, or a runtime-populated field went missing.
    Run

    tools/content/run_connect_fit.sh"

  # REPORTS rather than refuses: whose legibility rule governs the
  # projectiles is an owner decision, not a defect. What this catches
  # is the meshes failing to import or profile at all.
  say "Art's projectiles through Production's legibility rule..."
  tools/content/run_projectile_legibility.sh >/dev/null 2>&1 || \
    fail "projleg: a projectile no longer imports or no longer profiles
    through ProjectileSilhouette. The pairwise legibility numbers are
    REPORTED, not refused -- see the batch 051 handoff. Run

    tools/content/run_projectile_legibility.sh"

  # A13. Batch 043 drew Design 6 §15.2's thirteen statuses and checked
  # every example against §15.2's own target lists, which is the right
  # check against the design and not a check against the engine. This is
  # the other one: Production's closed vocabulary, their implemented
  # subset, their supported-target table and their three apply() guards,
  # applied to the kit. It also refuses to keep checking a guard they
  # have rewritten.
  # A14. Batch 043's twelve physics props carry a mass class derived
  # from Design 2 §10.2, transcribed into the exporter -- and Production
  # transcribes the same table into `MassClass`. Two transcriptions of
  # one section is the arrangement that drifts. This runs their ladder,
  # their envelope constants and their friction derivation over Art's
  # export, and refuses to keep checking a derivation they have changed.
  say "the physics props against the envelope that must move them..."
  tools/content/run_manipulation_readiness.sh >/dev/null 2>&1 || \
    fail "manipready: a prop's exported mass_class or envelope verdict
    disagrees with Production's own numbers, a rung of the mass ladder
    has emptied, or MassClass / ManipulableBody have moved under it. Run

    tools/content/run_manipulation_readiness.sh"

  say "the status kit against the runtime that exists..."
  tools/content/run_status_readiness.sh >/dev/null 2>&1 || \
    fail "statusready: a kind in ECHO_STATUS_KINDS has no glyph, a glyph
    claims runtime targets the runtime does not give it, the vocabulary
    map no longer lands on a real target kind, or one of apply()'s three
    guards has moved. Run

    tools/content/run_status_readiness.sh"

  say "the theme pack binding, and its control..."
  tools/content/run_theme_bind.sh >/dev/null 2>&1 || \
    fail "theme-bind: Production's ThemeMaterials no longer binds the
    exported pack's authored pixels to a material, the pixels no longer
    survive the import, or the missing-row control stopped falling back.
    Run

    tools/content/run_theme_bind.sh"
else
  say "SKIPPED the engine checks -- no godot at ${GODOT:-$ROOT/.tools/godot}"
fi

# --- 5. the preview project has not drifted from the game ---------------
# The theme-pack coverage ledger and its dated catalogue snapshot.
# A ledger that can silently lose a row reports full coverage of a
# shorter list.
# REPORTS, does not gate -- and the distinction is the point. Every wall
# and accent texture in all six themes has its panel-course rhythm broken
# at the tile edge, because `surface_for` lays courses at `range(0, 128,
# 38)` and 128 is not a multiple of 38. The repair is one line and it
# regenerates every one of them, which is a look decision for the owner
# rather than a defect fix. So this prints it on every run -- it cannot
# be forgotten -- and `--strict` turns it into a gate the day somebody
# rules. It DOES refuse (exit 3) if surface_for's arithmetic changes
# under it, because then it is checking a rule that has moved.
say "the panel courses against the tile they are drawn on..."
python3 tools/content/check_theme_courses.py | sed 's/^/    /' || \
  fail "check_theme_courses: surface_for's arithmetic has changed under
  the report. Re-read it. Run

    python3 tools/content/check_theme_courses.py"

say "theme-pack coverage matches the catalogue snapshot..."
python3 tools/content/check_pack_coverage.py >/dev/null || \
  fail "check_pack_coverage: the coverage table and catalogue.json
  disagree -- a game has no row, a row names a game the catalogue does
  not hold, or the stated count has drifted. Run

    python3 tools/content/check_pack_coverage.py"

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

# EVERY builder, not the ones that existed when this was written. The
# batch002 scripts were added and this loop was not, so the newest assets in
# the tree were the only ones nothing proved could be rebuilt -- the same
# shape of gap as L-33.
#
# It happened again: `build_physics_props`, `build_machinery` and
# `build_wave1_repair_overlay` each shipped .glb files into assets/models and
# none was listed here. The Batch 043 pair were the two builders behind the
# candidates pinned for an integration trial, so the art Production was about
# to import against was the art with the least proof behind it.
#
# Twice is a pattern, and a list maintained by remembering is not a check. So
# the list is now compared with the directory, and a builder that exists but
# is not named here FAILS -- rather than being quietly skipped, which is what
# made both gaps invisible. This runs whether or not Blender is installed.
SCRIPTS="build_materials build_architecture build_props
  build_concept_epsilon build_concept_check build_concept_portal
  build_concept_enemy build_concept_anchor build_batch002_enemies
  build_epsilon_installation build_hub build_lab build_check
  build_ways_out build_traversal build_projectile build_affordances
  build_dressing build_rails build_theme_dressing build_lights
  build_shells build_arenas build_paths build_towers build_rooms
  build_hall build_hall_overlay build_plenum build_yard build_span
  build_arch_kit build_arch_services build_navigation build_landmarks
  build_epsilon_states build_forge build_checkpoint build_pickups
  build_interaction_kit build_secrets build_enemy_roles build_zone_keys
  build_viewmodel build_gates build_decoys build_physics_props
  build_machinery build_wave1_repair_overlay build_junctions
  build_setpieces build_yardkit build_skiffkit build_roomkits
  build_connect build_jobs build_combatfx build_forest_temple
  build_theme_candidate build_clockwork build_brink build_wreck"

# Unquoted on purpose: word-splitting collapses the list's line breaks, so a
# name that happens to sit at the end of a line is still delimited by spaces.
# (The first version quoted it, and flagged all six line-terminal builders.)
listed=" $(echo $SCRIPTS) "
for f in tools/blender/build_*.py; do
  name=$(basename "$f" .py)
  case "$listed" in
    *" $name "*) ;;
    *) fail "$name is not in this script's rebuild list, so nothing proves
  the art it writes came from its source. Add it to SCRIPTS in
  tools/check_art_current.sh." ;;
  esac
done

# --- 5b. every content GATE is actually run -----------------------------
#
# The same rule as the builder list above, for the same reason: a check
# nobody runs is worse than no check, because it is quoted. It found three
# on the day it was written -- check_decal_colours.py, which nothing at
# all called, and verify_manifest.py and verify_markers.py, which only
# verify_content_pack.sh called and which this script did not run either.
#
# Only GATES. The `run_*.sh` harnesses that render evidence are not in
# scope: requiring them here would re-render the whole review library on
# every run, and some of them take minutes.
#
# WHAT IT DOES NOT CATCH, said out loud: it matches the path anywhere in
# the text, so a gate named only inside a `fail` message reads as covered.
# The failure mode it is built for -- a gate nothing mentions at all -- is
# caught, and that is the one that happened. Sabotage-tested by removing
# verify_content_pack.sh's only call: it then reports verify_manifest.py
# and verify_markers.py, which is exactly right.
# This file, PLUS every tools/*.sh it names -- "through a script it calls"
# has to mean that literally, or verify_manifest.py and verify_markers.py
# (reached only by verify_content_pack.sh) would read as uncovered.
reach="$SELF $(grep -o 'tools/[a-z_/]*\.sh' "$SELF" | sort -u)"
# shellcheck disable=SC2086
covered=" $(grep -ho 'tools/[a-z_/]*\.\(py\|sh\)' $reach | sort -u \
            | tr '\n' ' ') "
for f in tools/content/verify_*.py tools/content/check_*.py \
         tools/content/test_*.py; do
  case "$covered" in
    *" $f "*) ;;
    *) fail "$f is a gate and nothing in this script runs it, directly or
  through a script it calls. Add it, or add whatever does run it." ;;
  esac
done

# --- 5c. every ENGINE gate is actually CALLED ---------------------------
#
# 5b greps for a path anywhere in the file and deliberately ignores the
# `run_*.sh` harnesses, because most of them render evidence and would
# re-render the review library on every run. Three of them are not
# evidence, they are gates -- and this file lost the theme-bind call in a
# botched stash recovery, shipped a commit claiming it was gated, and
# 5b could not see it because the path still appeared in the commit's own
# prose. So these are named, and what is required is the CALL SHAPE, not a
# mention.
for gate in run_import_examples.sh run_crossing_test.sh run_theme_bind.sh \
           run_arrival_test.sh run_setpiece_fit.sh \
           run_yardkit_fit.sh run_skiff_sweep.sh \
           run_enemy_readiness.sh run_roomkit_fit.sh \
           run_connect_fit.sh run_projectile_legibility.sh; do
  grep -q "^[[:space:]]*tools/content/$gate >/dev/null" "$SELF" || \
    fail "tools/content/$gate is an engine gate and this script does not
  call it. Naming it in a comment or an error message is not calling it."
done

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

for script in $SCRIPTS; do
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

# Theme-pack gap 4: the default is the thing this whole script compares
# against, so it has to be the thing that was built. A shipped asset
# carrying another theme's paint would rebuild byte-identical here and be
# wrong in every render.
if [ -n "${ART_THEME:-}" ] && [ "$ART_THEME" != "concrete_facility" ]; then
  fail "ART_THEME=$ART_THEME is set, so the rebuild above did not build the
  shipped pack. Unset it and run again; this script only means anything
  against the default theme."
fi

untracked=$(git ls-files --others --exclude-standard -- $PATHS)
if [ -n "$untracked" ]; then
  fail "the build produces files that were never committed:"
  echo "$untracked" | sed 's/^/    /'
fi

[ $status -eq 0 ] && say "PASS -- every generated asset matches its source."
exit $status
