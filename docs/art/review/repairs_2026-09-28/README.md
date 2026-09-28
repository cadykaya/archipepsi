# Repair handoff: the 049 hinges, the skiff's ends, the lightened panels

*Arty — 2026-09-28*

**The authorised technical repair pass on the owner review's objective
art defects.** Three families are repaired, each separable. The rest is
held for your decisions, with the exact conflict recorded.

- **Nothing here is promoted:** every repaired asset is still a
  candidate.
- **Nothing is bound or integrated.**
- **Production was not touched:** read only at its pinned
  `c12a72fbc62500f4815d683d66a97f47fe514b06`.

**Followed up the same day.** You accepted the three families as
technical progress, without promoting their candidate art or authorising
Production binding, and asked for four more things. Each is in its own
commit; see [Follow-up, 2026-09-28](#follow-up-2026-09-28):
1. every lightened panel is checked for seating and clearance, and twelve
   are re-seated;
2. the gauge face shows through its bezel;
3. three documentation corrections;
4. `verify_content_pack.sh` can no longer delete or overwrite the
   caller's files.

| | |
|---|---|
| **Branch** | `claude/archipepsi-art-repairs-2026-09-28` |
| **Base** | the reviewed source `a1584c8a8a4d2beba95bc157ae3b6298a64c7fe2` (the owner review, kept as it is) |
| **Pipeline** | every model rebuilt by its own builder, with Blender 4.5.9 LTS. No binary was hand-edited. `tools/check_art_current.sh` passes at the three repairs' head (`e4103ba`) and again at the handoff (`ad3eb1b`). After the follow-up it passes at `3c2f3711` in the same configuration as those runs, reading Production's default local ref (`19c5d8e`). With `PROD_REF` at the pin, one gate cannot compile Production's newer code. That gate, `run_theme_bind.sh`, is unchanged since `a1584c8`; see "Found during the follow-up". |

## Take one family without the others

| Family | Commits | What Production would import |
|---|---|---|
| 1 · 049 hinges | `9231ce3b415ce8c0eaa8ea2ed99074c65bbae660`, then `c4dbd9044fa778a630de369f1d278ee42056f2eb`; follow-ups `9deb2c64a03318f7b39c2847a2c77c93528843f4` (the gauge face) and `e059dd73a0914692eb0b5135e1cb140ab795e012` (pose names) | 6 GLBs and the manifest in `assets/models/batch049/connect/` |
| 2 · the skiff's ends | `d48c36122a84065e812c55b76dc966e63bb6e854` | 2 GLBs and the manifest in `assets/models/batch045/setpieces/` |
| 3 · lightened panels | `e4103ba95068c7471b68ecac75456eaef89eb841`; follow-up `a0f1e769ae73cab35ccfcf2c32dda2b41efe7e2a` (every panel seated) | 11 GLBs and the manifest in `assets/models/batch043/physics/` |
| Dated corrections | `dc0d879b7a3470b814151fca98824b136c7765b8`; follow-up `72dad0cfad744355f656d8616e544e79ddb0e536` (the danger sheet) | Documents only |
| The content-pack verifier | `3c2f3711b91982a9d8afb4319029929060e3dbe9` | One script and its test; no asset |

Each family's exact files are listed in its section below. None depends
on another. Each was tested by cherry-picking it alone onto `a1584c8`,
and each applies cleanly with `git cherry-pick <commits>`. *Re-tested
after the follow-up, follow-ups included:* each still applies alone, and
families 1 and 3 then rebuild byte-identical through their own builders.
**Eligibility is your call.** None of these assets is approved, and
Production's frozen integration set does not contain them.

---

## 1 · 049: the six moving parts turn on real hinges

**Evidence:** [`sheets/1_049_hinges.jpg`](sheets/1_049_hinges.jpg)

**The defect.** `paddle_arm`, `seal_lever`, `dial_pointer`,
`gauge_needle`, `flag_blade` and `breaker_handle` exported with identity
transforms. Turning one therefore turned it about the asset origin, at
the foot of the mount. At the declared angles, each old pin travelled
0.13–0.88 m. The "declared positions" existed only in docstrings.

**The correction.** This is Batch 043's hinge pattern:
- an empty node at the pin;
- the moving parts as its children, at identity.

Every pivot is derived from the parts' measured boxes. Each hinge
declares its positions in the manifest's `hinge` block.

| Hinge | Carries | Pivot (runtime) | Axis | Positions | From |
|---|---|---|---|---|---|
| `hinge_paddle` | arm, grip | 0, 0.72, 0 | X | level 0 · down 22° *(named released / held until the follow-up)* | measured: the last degree before it meets its spring |
| `hinge_seal_lever` | lever | 0, 0.12, 0.04 | X | intact 0 · thrown 90° (hides both tabs) | declared |
| `hinge_breaker` | handle | 0, 0.38, 0 | X | closed 0 · thrown 30° | declared; asserted clear of its window |
| `hinge_flag` | blade | 0, 0.62, −0.055 | X | down 0 · up 90° | declared |
| `hinge_dial` | knob, pointer | 0, 0.17, 0.035 | Z | 8 detents at 45° steps | measured: one per tooth |
| `hinge_gauge` | needle | 0, 0.15, 0.02 | Z | empty +90 · half 0 · full −90 | declared: an ordinary half-dial |

The builder refuses any position that pushes a part into something it
did not touch as built, through the floor, or into the wall.

**What stays the same:**
- **Rest shape:** every vertex, UV and material at rest (verified node by
  node against `a1584c8`). The follow-up makes one exception: the
  gauge's bezel, opened into a frame.
- **Budgets:** triangle counts and sizes. The gauge goes from 64 to 100
  triangles in the follow-up.
- **The rest of the batch:** the other eight 049 models are
  byte-identical.
- **A09.2's silhouettes:** the three commitments still differ.
- **Nothing runtime:** no collider, script or animation.

The commitment silhouette is **not** selected, and the paddle is not
recaptioned. Both are your decisions (A1). *(Follow-up: the paddle's
positions are now named for where the arm is. That does not recaption
it; see below.)*

**Changed:**
- `tools/blender/build_connect.py`;
- `assets/models/batch049/connect/` (the six GLBs and the manifest);
- `tools/content/connect_fit.gd`, which now measures in the model's
  frame;
- `docs/art/review/connect_2026-09-22/fit.json`, regenerated (every size
  identical; only the listing order changed);
- `tools/art_repairs_2026_09_28/verify_049_hinges.py`, `pose_views.gd`
  and `run_pose_views.sh`.

**Status:**
- Visual: **PENDING**.
- Technical compatibility: hinges and positions declared; no colliders.
- Binding: none.
- Gameplay: no.

**Still depends on:**
- the permanent-control decision;
- a placement contract (Production's levers stand; these mount on walls);
- colliders;
- a driver.

---

## 2 · The skiff: fore is the end that goes first

**Evidence:** [`sheets/2_skiff_fore.jpg`](sheets/2_skiff_fore.jpg)

**The defect.** In `sp_skiff_deck` and `sp_skiff_deck_bare`, `lamp_fore`
sat at runtime −Z. RailCarrier's FORWARD is the node's +Z:
`RailCarrier.pose()` sets `basis.z` to the path tangent, toward the next
higher dock (`rail_carrier.gd:420` at `c12a72f`). So the lamp named fore
was the trailing one. This was measured on the exported GLB, not assumed
from Blender axes.

**The correction.** The builder's fore/aft loop now puts `fore` at
runtime +Z, so each end's lamp, end plate, band, cap and posts swap
names. Each entry in the manifest gains `fore_is`, stating the contract.

**What stays the same:**
- every box: each `*_fore` node carries exactly the old `*_aft` geometry,
  UVs and material;
- the manifest's part lists;
- every other setpiece (byte-identical).

**Changed:**
- `tools/blender/build_setpieces.py`;
- `assets/models/batch045/setpieces/` (the two skiff decks and the
  manifest);
- `tools/art_repairs_2026_09_28/verify_skiff_fore.py`, which reads the
  pinned runtime line.

**Status:** Visual: **PENDING**. Technical compatibility: names now agree
with the runtime frame. Binding: none. Gameplay: no.

**Still depends on** the optional-mesh binding (C1).

---

## 3 · The lightened panels: their own material, clear of the fittings

**Evidence:** [`sheets/3_lightened_panels.jpg`](sheets/3_lightened_panels.jpg)
(the first round; the follow-up is
[`sheets/6_panels_seated.jpg`](sheets/6_panels_seated.jpg))

**The defect:**
- All 22 `lightened_panel_*` nodes wore `<asset>_grip`, the family's
  "the player's device touches here" material.
- Nine sat on or under a fitting:
  - the ballast's and the weighted block's pads;
  - the generic crate's hand grips;
  - the mechanical part's key;
  - the movable cover's push pads, from which its panels hung 5.5 cm off
    the face.

**The correction:**
- **Material:** a separate slot for the panels, `<asset>_lightened`, at
  `#4a5058` at rest. That is Batch 043's unlit state-node value.
- **Clear panels:** stay exactly where they were.
- **Blocked panels:** move the shortest distance to a place that clears
  every fitting by 2 cm, is seated (the whole panel over the body, flat
  to 1 cm), and is never proud of the collider box.

| Object | Move |
|---|---|
| generic crate | both panels down 0.07 m, below the grips |
| ballast | both slide 0.30 m along their faces |
| movable cover | both up 0.25 m, onto the face above the rib |
| weighted block | both turn onto the free side faces |
| mechanical part | the keyed-face panel turns onto the side |

**What stays the same:**
- dimensions and the collider box;
- every fitting and every body, vertex for vertex;
- carriable, manipulable, mass, mass class, envelope and attach points
  (the Batch 043 import examples pass);
- the anchor block, which is byte-identical.

**Changed:**
- `tools/blender/build_physics_props.py`;
- `assets/models/batch043/physics/` (11 GLBs and the manifest, which gains
  a `lightened_panels` block recording every move);
- a dated note in `docs/art/BATCH_043_INTEGRATION.md`;
- `tools/art_repairs_2026_09_28/verify_053_panels.py`.

**Status:** Visual: **PENDING**. Technical compatibility: addressable, one
slot per panel. Binding: none. Gameplay: no.

**Still depends on** a runtime that shows `lightened`. The rest value is
one constant: if you would rather the panel disappear into the body
until lit, that is a one-line change. The review rig renders it paler
than it will be in the game.

---

## Follow-up, 2026-09-28

*Added the same day, after your reply. You accepted the three families as
technical progress. That does not promote their candidate art or
authorise Production binding, and nothing below does either.*

| # | Commit | What |
|---|---|---|
| F1 | `a0f1e769` | Every lightened panel seated and clear; twelve re-seated |
| F2 | `9deb2c64` | The gauge face shows through its bezel |
| F3 | `e059dd73`, `72dad0cf` | The paddle's poses get mechanical names; the danger sheet's binding line and code-reading labels |
| F4 | `3c2f3711` | `verify_content_pack.sh` no longer writes or deletes anything in the caller's tree |

### F1 · Every lightened panel seated

**Evidence:** [`sheets/6_panels_seated.jpg`](sheets/6_panels_seated.jpg).
Before is the first repair (`e4103ba`); after is this branch. The panels
wear a flat review tint so their place reads. Their real look is sheet
3's grey-blue.

The seat and clearance checks now run on all 22 panels, at the place the
rule first puts each one, not only on the nine near fittings. The
verifier asks three separate questions of each panel:
- **MATERIAL:** does it wear its own `<asset>_lightened` slot?
- **CLEAR:** is every fitting at least 2 cm away across its face, and
  10 cm in front?
- **SEATED:** rays 1 cm apart must all find the body 2 mm to 3 cm behind
  the panel's face. It must never be flush, never float, be flat to
  1 cm, and never stand proud of the collider box.

So the old placements fail on their own defects, not merely on their
old material:

| Files | MATERIAL fails | CLEAR fails | SEATED fails |
|---|---|---|---|
| `a1584c8` (reviewed) | 22 | 9 | 17 |
| `e4103ba` (first repair) | 0 | 0 | 12 |
| this branch | 0 | 0 | 0 |

| Object | At `e4103ba` | Now |
|---|---|---|
| cart, both | on the deck's sides, partly over no body | on the deck top |
| girder, both | up to 4.5 cm off the web | seated on the web, 7 cm in |
| power cell, both | up to 4.2 cm off the core, across the cage | seated on the core at 80% width |
| plate, both | flush with its long sides | one on the +X end, one on the top |
| key component, one | flush with its face | on the +X side |
| mechanical part, hub end | flush, across the uneven hub | on the −X side |
| ballast, both | slid onto a cast band, flush with it | between the bands: 3 cm lower, 60% of the height |

Ten of these are the six floating and four coplanar cases the first
handoff reported. The ballast's pair was caught by the stricter test.
Three panels never moved at all: the drum's two and the key component's
other.

**Unchanged:**
- every body and fitting, vertex for vertex;
- sizes and attach points (21 verified; the Batch 043 import examples
  pass);
- masses, mass classes, and carriable and manipulable permissions.

The generic crate, drum, movable cover, weighted block and anchor block
are byte-identical to the first repair.

**The subdued grey-blue at rest stays the working treatment.** That is
not an approval of how `lightened` looks when it is active.

### F2 · The gauge face shows through its bezel

**Evidence:** [`sheets/5_gauge_face.jpg`](sheets/5_gauge_face.jpg). Real
materials, no tint, at each declared reading, straight on and from the
side.

**The defect.** `gauge_bezel` was a solid 0.30 × 0.05 × 0.30 m block with
the face wholly inside it. From the front, 0 cm² of the face showed, and
the needle (the bezel's own cream) was read against the bezel.

**The correction.** The smallest suitable one: the bezel becomes what a
bezel is. It is a frame of the same outer size, depth, place, name and
material, built with the kit's own `brushkit.frame`, and the face is read
through its 0.20 m window:
- the window's edge is 1 cm inside the face's flats, so the bezel still
  holds the rim;
- it is 1 cm outside the needle's whole sweep (reach 0.091 m).

The window's corners show the case behind the octagonal face.

**Unchanged:**
- the case, face and needle;
- the pin at (0, 0.15, 0.02), the Z axis, and the travel: empty +90,
  half 0, full −90.

The model goes from 64 to 100 triangles. There is no redesign.

**Guards:**
- The build now refuses a bezel the needle touches at rest or at any
  reading (`clear_of`). The old new-contact rule excused it, because
  the needle touched it as built. Sabotage-tested with a 0.16 m window.
- `verify_049_gauge.py` looks straight on through a 2 mm grid of rays
  at every degree of the sweep:
  - the dial round the pin shows only face or needle;
  - the needle is never covered, and is always backed by the face;
  - the housing, pin and travel are as they were.

  It fails on the old model and on a changed outer box.
- `verify_049_hinges.py` still holds the bezel to its outer box and
  material, and runs the gauge verifier for it.

### F3 · Documentation

- **The danger sheet's binding line** said generally that the seam
  would be `telegraph_started` / `telegraph_finished`. It applies to the
  charger and the artillery; the beacon has no telegraph. Sheet 4 is
  recomposed from the same data, with a dated note.
- **Code readings are labelled** in `DANGER_MARKS.md` and on sheet 4:
  - the charger's footprint;
  - the artillery's early burst;
  - the beacon's 12 m support radius.

  Each is read from Production's code at `c12a72f`. None was tested in
  play, and none is an approved presentation.
- **The paddle's poses** are `level` (0°) and `down` (22°); they were
  `released` and `held`.
  - Every hinge's manifest entry now says its positions are mechanical
    poses: not inputs, states or rules.
  - The paddle's entry adds that A1 (momentary or permanent) is open.
  - A pose called "held" authorised no hold-input mechanic.
  - The A09.2 `commitment` text from the original request is left as
    recorded. Recaptioning it is part of A1.

### F4 · `verify_content_pack.sh` leaves the caller's tree alone

**Production's note** (`12a8ede1`, §1) says that running it on a
Production checkout deletes:
- the tracked `godot/content/registry/legacy_procedural.json`;
- untracked files under `godot/`, including scratch harnesses.

**Confirmed in disposable worktrees only.** Production's copy is
byte-identical to ours (blob `43911e47`). Before and after every run it
cleared `godot/_harness` and that manifest, whoever owned them, and it
overwrote the manifest in between.

**The fix** (`3c2f3711`, one script):
- Everything the run writes goes into a private copy of `godot/` in a
  new temporary directory: Production's manifest, the harness, and
  Godot's import cache.
- The Python gate and both Godot steps read the copy. The later steps
  only read the tree.
- Cleanup removes that directory and nothing else, on success, on
  failure and on an interrupt.
- It refuses to run if `godot/` holds a symbolic link.
- The checks themselves are unchanged.

**The test,** `tools/content/test_verify_content_pack_safety.sh`:
- makes disposable detached worktrees and imports Godot in each;
- plants caller-owned sentinels:
  - a local edit to the manifest (or the file itself, where it is
    untracked);
  - `godot/_harness/prod_scratch.gd`;
  - two untracked files elsewhere;
  - a file in the ignored cache;
- records every path under `godot/` with its hash, and compares after
  each run.

| Tree | Old script (`a1584c8`) | New, passing run | New, failing run |
|---|---|---|---|
| this branch (manifest untracked) | exit 0; deleted `_harness/`, the scratch harness and the manifest | exit 0; nothing deleted, overwritten or added | exit 3 (injected at `verify_markers.py`); nothing deleted, overwritten or added |
| Production's pin `c12a72f` (manifest tracked) | exit 0; deleted `_harness/`, the scratch harness and the tracked, edited manifest | exit 0; nothing | exit 3; nothing |

No private copy was left behind by any run.

**Not reproduced.** Three untracked sentinels elsewhere under `godot/`
survived the old script too. If Production lost files outside
`_harness`, something else removed them. The new script touches nothing
either way.

It was not run in Production's worktree, and nothing was sent to
Production.

---

## Held for your decisions

Each item below is recorded, not changed.

| Item | Exact current conflict at `c12a72f` | Waits on |
|---|---|---|
| `fx_bulwark_face` | Plate at +Z (0.365–0.425); the bulwark's front is −Z (`enemy.gd:1262`). A separate candidate effect: **the approved bulwark body is not affected.** Use parked. | Whether the effect is used |
| `sp_crossing_carrier` (Passing) | Buffers and lamps on local ±X. V-to-H boards across its +X side, and H-to-G alights across its +Z end (`passing_platforms_room.gd:59-78`), so moving them to the ends blocks G. | The Passing room |
| `sp_hoist_car` (Passing) | Its closed back is at +Z, the face toward H's track | The Passing room |
| `cf_shutter_track` (Counterfire) | `track_head` at y 1.30–1.56 sits inside the leaf's 2.6 m rise | Counterfire recheck |
| `cf_lane_mark`, `sp_lane_screen` (Counterfire) | The mark grows outward, under the wall segments. The screen is 3.0 × 1.37 against 1.6 × 1.7 segments. | Counterfire recheck |
| `uw_plate_frame`, `uw_drive_housing` (Unweighted) | The frame's approach wall crosses the drive corridor. The case at x 1.25–1.95 and the rail at x 1.14–1.30 overlap the guide rails and shoes. | The Unweighted room |
| `yk_gantry_anchor` (Blindside yard) | A ceiling mount in an open-sky yard | The yard kit (C1) |
| The diver trail | Points down, but the dive aims at an airborne body (`enemy.gd:1413-1414`); no contract fixes its direction | A trail binding |
| Danger marks | See [`DANGER_MARKS.md`](DANGER_MARKS.md) and [`sheets/4_danger_marks_to_scale.jpg`](sheets/4_danger_marks_to_scale.jpg): geometry, anchors and timing prepared; presentation open | Warning or boundary |
| Telegraph ring, status families | Not chosen | D1, D4 |
| Theme packs | T01/T05 course slivers, T01's repeating worn band, four pack levers with no hinge node | The temple_ruin and pack rulings |
| Withheld room shells | Not retrofitted or enabled | Small, standard and large |

The Counterfire, Unweighted and yard measurements are the owner review's
(`C_machinery.md`), taken against `c12a72f`. The Passing facts were read
again this pass.

## Found during the repair, not repaired

*Follow-up, 2026-09-28:* the first two rows below are now repaired
(`a0f1e769`, `9deb2c64`). The third is still open.

| Found | Smallest repair |
|---|---|
| **Ten more lightened panels are badly seated.** Six hang off the body (both on the cart, girder and power cell). Four are exactly coplanar with the face under them (both on the plate, one on the key component, and the mechanical part's hub end). | Run the same seat rule for every panel, not only blocked ones: one condition in `_lightened_panels`. |
| **`conn_gauge`'s face is invisible.** The face disc lies wholly inside the solid bezel box. | Open the bezel into a frame, or bring the face 1 cm proud. |
| **`ArtBench.aabb_of`** measures each mesh with only its own transform. It frames cameras; no recorded number uses it. | Accumulate parent transforms, as `connect_fit.gd` now does. |

**Found during the follow-up, not repaired:**

| Found | Smallest repair |
|---|---|
| **The plate's nose wedge slopes across the plate's width.** `pl_nose` uses `wedge`'s default `axis="y"`, so it does not chamfer the leading edge its docstring promises. | `axis="x"`, turned so the low edge is the tip |
| **Hex colours are written straight into the linear base colour,** art-lane-wide. The panel exports lighter than `#4a5058` would be in sRGB; the grey-blue you saw is what exports. A runtime restoring `at_rest` as sRGB would draw it darker. | A decision, not a patch: either convert once in `palette.rgba`, which changes every flat colour, or say "linear" in the manifests |
| **42 other art-lane runners** still clear `godot/_harness`, whoever owns it. My three repair runners now claim it or stop. | The same claim-or-stop guard, or `verify_content_pack.sh`'s private copy |
| **`run_theme_bind.sh` cannot compile Production at the pin.** There, `theme_pack.gd`'s `UNIVERSAL_ROLES` and `PACK_TABLE` are `Constants.*` autoload references, and a `-s` harness has no autoloads. At the older default ref they are literals, and the gate passes. The gate is unchanged since `a1584c8`, so this is a limit of the gate, not something the follow-up caused. | Inline the two constants from Production's own `constants.gd`, as `verify_content_pack.sh` already does for `ContentRegistry` |

## Documentation corrections

`dc0d879` adds dated notes beside the stale records the review listed:
- 043's pin diff and the cart's `push_bar`;
- the enemy spawn claims;
- the 015–022 statuses;
- the 028 numbers;
- the status count;
- a reserved colour;
- the ballast caption;
- the pack wording.

It also adds `CORRECTIONS.md` beside seven evidence folders. My own
errors are in
`docs/art/review/owner_review_2026-09-28/CORRECTIONS_2026-09-28.md`:
- the bulwark-face wording;
- D2's charger width;
- my proposed carrier fixes.

The follow-up adds three corrections, each with a dated note (see F3):
- the danger sheet's binding line;
- code-reading labels;
- the paddle's pose names.

Sheets 1 and 3 are recomposed from their own frames, with dated notes.

No frame was re-rendered to hide an error.

## Verification

| Check | Result |
|---|---|
| `python3 tools/art_repairs_2026_09_28/verify_049_hinges.py` | PASS: rest geometry, UVs and materials identical to `a1584c8`, except the gauge's bezel, whose outer box and material it still checks and whose reshape it hands to the gauge verifier; each hinge where the manifest says; every detent on its tooth. Sabotaged manifest: FAIL, as it should. |
| `python3 tools/art_repairs_2026_09_28/verify_049_gauge.py` | PASS: face round the needle at every degree from −90° to +90°; needle never covered. On `77d33ca` and `a1584c8`: FAIL (face 0 cm²). A changed outer box: FAIL. |
| `python3 tools/art_repairs_2026_09_28/verify_skiff_fore.py` | PASS. On the old files: FAIL. |
| `python3 tools/art_repairs_2026_09_28/verify_053_panels.py` | PASS: 22 panels on their own material, clear and seated; 19 placed by the repairs. On `e4103ba`'s files: FAIL on SEATED alone (12). On `a1584c8`'s: FAIL 22 / 9 / 17. |
| `tools/content/test_verify_content_pack_safety.sh` | PASS: on passing and failing runs, in both trees, the new verifier deleted, overwrote and added nothing (about 5 min) |
| `tools/content/run_connect_fit.sh` | PASS: 14 assets, A09's distinctions kept |
| `tools/content/run_import_examples.sh` | 4 examples, 0 problems |
| `tools/check_art_current.sh` | PASS at `e4103ba`, at `ad3eb1b` and at `3c2f3711`: every generated asset rebuilds byte-identical. These runs read Production's default local ref (`19c5d8e`). At `3c2f3711` with `PROD_REF` at the pin, everything passes except `run_theme_bind.sh`, which cannot compile Production's newer `theme_pack.gd` (reported below). |

**Rebuild the evidence:**

    tools/art_repairs_2026_09_28/run_pose_views.sh <frames>/pose
    tools/art_repairs_2026_09_28/run_tint_views.sh <frames>/tint
    tools/art_repairs_2026_09_28/run_gauge_views.sh <frames>/gauge
    tools/art_repairs_2026_09_28/run_tint_views.sh <frames>/tint_fu e4103ba followup
    python3 tools/art_repairs_2026_09_28/build_sheets.py <frames> docs/art/review/repairs_2026-09-28/sheets

The runners claim `godot/_harness` or stop; none clears a folder it did
not create.

## Not done, on purpose

- No promotion to PASS, binding or runtime use.
- No new asset or catalogue entry.
- No menu, gameplay system, room programme or 0.5 work.
- No Production file touched, no message sent.
- No watchers.
- *Follow-up:*
  - no gauge redesign;
  - no active-state presentation for the panels;
  - the unsafe verifier was never run in Production's worktree.

**Stopped here for your remaining visual decisions.**
