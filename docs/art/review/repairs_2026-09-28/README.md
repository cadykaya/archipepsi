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

| | |
|---|---|
| **Branch** | `claude/archipepsi-art-repairs-2026-09-28` |
| **Base** | the reviewed source `a1584c8a8a4d2beba95bc157ae3b6298a64c7fe2` (the owner review, kept as it is) |
| **Pipeline** | every model rebuilt by its own builder, with Blender 4.5.9 LTS. No binary was hand-edited. `tools/check_art_current.sh` passes at the three repairs' head (`e4103ba`) and again at the handoff (`ad3eb1b`). |

## Take one family without the others

| Family | Commits | What Production would import |
|---|---|---|
| 1 · 049 hinges | `9231ce3b415ce8c0eaa8ea2ed99074c65bbae660`, then `c4dbd9044fa778a630de369f1d278ee42056f2eb` | 6 GLBs and the manifest in `assets/models/batch049/connect/` |
| 2 · the skiff's ends | `d48c36122a84065e812c55b76dc966e63bb6e854` | 2 GLBs and the manifest in `assets/models/batch045/setpieces/` |
| 3 · lightened panels | `e4103ba95068c7471b68ecac75456eaef89eb841` | 11 GLBs and the manifest in `assets/models/batch043/physics/` |
| Dated corrections | `dc0d879b7a3470b814151fca98824b136c7765b8` | Documents only |

Each family's exact files are listed in its section below. None depends
on another. Each was tested by cherry-picking it alone onto `a1584c8`,
and each applies cleanly with `git cherry-pick <commits>`.
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
| `hinge_paddle` | arm, grip | 0, 0.72, 0 | X | released 0 · held 22° | measured: the last degree before it meets its spring |
| `hinge_seal_lever` | lever | 0, 0.12, 0.04 | X | intact 0 · thrown 90° (hides both tabs) | declared |
| `hinge_breaker` | handle | 0, 0.38, 0 | X | closed 0 · thrown 30° | declared; asserted clear of its window |
| `hinge_flag` | blade | 0, 0.62, −0.055 | X | down 0 · up 90° | declared |
| `hinge_dial` | knob, pointer | 0, 0.17, 0.035 | Z | 8 detents at 45° steps | measured: one per tooth |
| `hinge_gauge` | needle | 0, 0.15, 0.02 | Z | empty +90 · half 0 · full −90 | declared: an ordinary half-dial |

The builder refuses any position that pushes a part into something it
did not touch as built, through the floor, or into the wall.

**What stays the same:**
- **Rest shape:** every vertex, UV and material at rest (verified node by
  node against `a1584c8`).
- **Budgets:** triangle counts and sizes.
- **The rest of the batch:** the other eight 049 models are
  byte-identical.
- **A09.2's silhouettes:** the three commitments still differ.
- **Nothing runtime:** no collider, script or animation.

The commitment silhouette is **not** selected, and the paddle is not
recaptioned. Both are your decisions (A1).

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

| Found | Smallest repair |
|---|---|
| **Ten more lightened panels are badly seated.** Six hang off the body (both on the cart, girder and power cell). Four are exactly coplanar with the face under them (both on the plate, one on the key component, and the mechanical part's hub end). | Run the same seat rule for every panel, not only blocked ones: one condition in `_lightened_panels`. |
| **`conn_gauge`'s face is invisible.** The face disc lies wholly inside the solid bezel box. | Open the bezel into a frame, or bring the face 1 cm proud. |
| **`ArtBench.aabb_of`** measures each mesh with only its own transform. It frames cameras; no recorded number uses it. | Accumulate parent transforms, as `connect_fit.gd` now does. |

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

No frame was re-rendered to hide an error.

## Verification

| Check | Result |
|---|---|
| `python3 tools/art_repairs_2026_09_28/verify_049_hinges.py` | PASS: rest geometry, UVs and materials identical to `a1584c8`; each hinge where the manifest says; every detent on its tooth. Sabotaged manifest: FAIL, as it should. |
| `python3 tools/art_repairs_2026_09_28/verify_skiff_fore.py` | PASS. On the old files: FAIL. |
| `python3 tools/art_repairs_2026_09_28/verify_053_panels.py` | PASS: 22 panels on their own material and clear; 9 moved and seated. On the old files: FAIL. |
| `tools/content/run_connect_fit.sh` | PASS: 14 assets, A09's distinctions kept |
| `tools/content/run_import_examples.sh` | 4 examples, 0 problems |
| `tools/check_art_current.sh` | PASS at `e4103ba` and again at `ad3eb1b`: every generated asset rebuilds byte-identical |

**Rebuild the evidence:**

    tools/art_repairs_2026_09_28/run_pose_views.sh <frames>/pose
    tools/art_repairs_2026_09_28/run_tint_views.sh <frames>/tint
    python3 tools/art_repairs_2026_09_28/build_sheets.py <frames> docs/art/review/repairs_2026-09-28/sheets

## Not done, on purpose

- No promotion to PASS, binding or runtime use.
- No new asset or catalogue entry.
- No menu, gameplay system, room programme or 0.5 work.
- No Production file touched, no message sent.
- No watchers.

**Stopped here for your remaining visual decisions.**
