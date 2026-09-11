# Batch 043 — integration handoff

**Arty**

Everything Production needs to drive this batch, and nothing else. All of it
is **PROPOSAL** art: no mechanic is implemented, no registry entry is added,
no approved asset is touched, and the playable build is unchanged.

Revisions are in `docs/art/reports/2026-09-11-batch043.md`.

---

## 1. The status graphic kit — 2D, no mesh

`docs/art/review/status_2026-09-11/`

| | |
| --- | --- |
| assets | `png/*.png`, individual and transparent. The atlas is a supplement |
| manifest | `status_kit.json` — id, family, `targets`, `sentence`, duration, chance, components, native size, depletion track |
| marker | 32 × 32; the glyph is 16 × 16 seated at (8, 8); the tick is 8 × 8 at (23, 23) |
| reduced treatment | the 16 × 16 glyph **alone** — a different picture, not a smaller one |

**Drawing a marker.** Screen-fixed, world-anchored. The preview uses a
`Sprite3D` with `billboard = enabled`, `fixed_size = true`,
`texture_filter = NEAREST`, `alpha_cut = DISCARD`. At `pixel_size` 0.0032 a
32 px marker occupies 32 screen px in a 700 px-tall viewport — the size it
was drawn at.

**Depletion.** There is no ring asset. Each frame's **own outer edge** is the
track, and `status_kit.json → depletion.tracks[<frame>]` is that edge as an
ordered pixel list, clockwise from 12 o'clock, 76–112 px long. Paint the
first `remaining` fraction in `lit` and the rest in `spent`.

**Target legality is data, not convention.** `targets` per status is §15.2's
own column. Twelve of the twenty-one are legal on an `OBJECT`, eight are
actor-only, one (`arc_path`) is surface-only. The art preview fails its own
run on an illegal pair; a runtime should refuse at §15.4 step 1, visibly.

**Not supplied:** any HUD, any status runtime, any world-space marker
renderer. The preview's persistent tier is a mock.

## 2. The machinery feedback kit

`assets/models/batch043/machinery/` · manifest `how_to_drive`

Every state region is **its own named node AND its own single material
slot**, so a runtime gets both handles.

| node | on | drive it by |
| --- | --- | --- |
| `state_band` | `mach_conduit_run` | `set_surface_override_material(0, m)` to swap state; `uv1_offset.x` to scroll `active` / `pulse_travelling`. **Never scale it** |
| `fill_band` | `mach_conduit_run` | visible only for `delayed`; scale on X. Take the fixed end from the node's own AABB: `position.x = base + x₀·(1 − s)` |
| `hinge_lever` | `mach_wall_switch` | an **Empty at the pintle**; rotate it about X. Its own origin is the attachment point and cannot move |
| `lever_arm` | child of `hinge_lever`, at identity | geometry only |
| `state_lens` | `mach_wall_switch` | one material slot |
| `state_lens_0` / `_1` | `mach_receiver_lamp` | one material slot each; two lenses so the receiver can say *agreeing with its input* or not |

Band tile: 64 × 16 px = **2.00 × 0.50 m at 32 texels/m**, the architecture
budget, asserted on both axes at build time. Clamps at the 0.50 m bolt pitch.

**Still required:** the signal graph itself, and §19.5's audio — a low hum,
an arrival click, and a rising pitch. The rising pitch is the **second**
timing channel; the filling band is the first and it is delivered.

## 3. The physics-prop family

`assets/models/batch043/physics/` — all twelve Design 2 §10.1 classes.

**Coordinates.** Every entry carries a `coordinate_space` block.
Dimensions (`size`, `size_runtime_y_up`) and every attach point's `position`
and `normal` are in **runtime axes: X, Y up, Z**, with the origin shift
applied once and the Y-up conversion applied once.
`authored_blender_z_up` sits beside each point for traceability and is
**not** the runtime value. `tools/content/verify_attach_points.py` confirms
each runtime position lands on the node it names, read from the exported
`.glb`.

**Per entry:** `class`, `mass_kg`, derived `mass_class`, `carriable`,
`manipulable`, `parts` (the addressable node names), `material_roles`
(`body`, `handling`), `attach_points`, triangle count, texel density, anchor.

**Reading the family.** Unpainted dark steel appears **only** where the
player's device touches. A hand grip means a hand can lift it (≤ 60 kg,
§10.3); its absence on an object with attach pads means a device has to.
`ANCHOR_BLOCK` is `FIXED` and has neither — one tether eye, and nothing to
take hold of.

**Two candidates for two classes.** `phys_generic` and `phys_drum` are the
manipulable siblings of the approved, unchanged, decorative `prop_crate` and
`prop_oil_drum`.

**Not supplied:** collision. None is derived and none ships. Nothing here is
traversal or physics evidence, and no dimension is a runtime contract —
they are art dimensions and will move to fit one.

## 4. Checks this batch adds, and what each would catch

| check | catches |
| --- | --- |
| `tools/content/verify_attach_points.py` | a missed origin shift, a double shift, a wrong axis convention, a point naming a node that is not in the `.glb` |
| `common.assert_parts_touch` | a fitting floating off the body or off the chain of fittings that reaches it |
| `common.assert_budget_group` | a split mesh buying triangles |
| `author_conduit_states.mjs` brightness floor | `inactive` and `blocked` collapsing back onto one channel |
| `status_preview.gd` legality gate | an example scene contradicting `status_kit.json` |
| `tools/content/inspect_glb_nodes.py` | a state region that arrives as a material slot with no node to drive |

All six fail loudly. The attach-point verifier was sabotage-tested: moving
one point 0.35 m produces a named failure and a non-zero exit.
