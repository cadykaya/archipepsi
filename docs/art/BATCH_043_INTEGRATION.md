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

**Still required for Production's machinery integration — recorded, not
blocking.** §19.5 names three cues and none exists:

| state | cue | status |
| --- | --- | --- |
| `active` | a low hum | **not supplied** |
| `pulse_travelling` | a click on arrival | **not supplied** |
| `delayed` | a rising pitch | **not supplied** — and it is the *second* timing channel, not the first |

The filling band is §19.5's primary timing display and it is delivered, with
both endpoints static and a labelled 4.0 s demonstration. **The visual kit
does not wait on sound**; these three remain open against whoever owns audio.

Also still required: the signal graph itself.

## 3. The physics-prop family

`assets/models/batch043/physics/` — all twelve Design 2 §10.1 classes.

**Coordinates — read this before using any number.** Every entry carries a
`coordinate_space` block, and **two different size fields that are not the
same triple**:

| field | frame | what it is |
| --- | --- | --- |
| `size` | **authoring**, Blender Z-up: width X, depth Y, height Z | the shared exporter's own field, identical in meaning across every batch. Left alone on purpose |
| `size_runtime_y_up` | **runtime**, glTF/Godot Y-up: `{x, y_up, z}` | what a loader sees. `common.runtime_size()` maps (x, y, z) → (x, z, y) |
| `size_authoring_blender_z_up` | authoring | the same as `size`, spelled out, so the two are never confused by shape |

Attach-point `position` and `normal` are in **runtime axes**, with the origin
shift applied once and the Y-up conversion applied once;
`authored_blender_z_up` sits beside each for traceability and is **not** the
runtime value.

`tools/content/verify_exported_geometry.py` measures both against the
exported `.glb` — union AABB with node transforms accumulated for sizes,
per-node accessor bounds for points.

**Per entry:** `class`, `mass_kg`, derived `mass_class`, `carriable`,
`manipulable`, `parts` (the addressable node names), `material_roles`
(`body`, `handling`), `attach_points`, triangle count, texel density, anchor.

**Reading the family.** Unpainted dark steel appears **only** where the
player's device touches, fully matte so it cannot catch the room's specular
and arrive brighter than the body it sits on. Measured across all twelve in
the render: the fitting is at least **17.9 L\*** below its body on bright
concrete and **13.4 L\*** on dark derelict.

A hand grip means a hand can lift it, and **that follows §10.1's `carriable`
flag, not a mass threshold.** §10.3's 60 kg is necessary, not sufficient —
carriable is `carriable = true` AND `mass_kg <= 60.0`. `PLATE` is exactly
60 kg and §10.1 marks it **not carriable**, so it has lifting slots and no
grip. Read the flag; the threshold only removes candidates.

`ANCHOR_BLOCK` is `FIXED` and has neither grip nor pad — one tether eye, and
nothing to take hold of.

**Two candidates for two classes.** `phys_generic` and `phys_drum` are the
manipulable siblings of the approved, unchanged, decorative `prop_crate` and
`prop_oil_drum`.

**Not supplied:** collision. None is derived and none ships. Nothing here is
traversal or physics evidence, and no dimension is a runtime contract —
they are art dimensions and will move to fit one.

## 4. Checks this batch adds, and what each would catch

| check | catches |
| --- | --- |
| `tools/content/verify_exported_geometry.py` — sizes | a swapped or relabelled axis convention, measured against the union AABB with node transforms. It refuses to run unless the manifest contains an object asymmetric enough to expose a swap |
| `tools/content/verify_exported_geometry.py` — attach points | a missed origin shift, a double shift, a point naming a node that is not in the `.glb` |
| `props_preview.gd` handling-contrast probe | the family's value rule failing in the render — a fitting that reads brighter than its body under the shipped lights |
| `common.assert_parts_touch` | a fitting floating off the body or off the chain of fittings that reaches it |
| `common.assert_budget_group` | a split mesh buying triangles |
| `author_conduit_states.mjs` brightness floor | `inactive` and `blocked` collapsing back onto one channel |
| `status_preview.gd` legality gate | an example scene contradicting `status_kit.json` |
| `tools/content/inspect_glb_nodes.py` | a state region that arrives as a material slot with no node to drive |

All of them fail loudly, and each was made to fail on purpose before it was
trusted. Re-declaring the old axis convention on two objects produces:

```
phys_plate declares size_runtime_y_up [1.8, 0.92, 0.145]; the exported
geometry measures [1.8, 0.145, 0.92]  -- these match with Y and Z swapped,
so the axis convention is wrong rather than the geometry
```

and moving one attach point 0.35 m names it the same way.
