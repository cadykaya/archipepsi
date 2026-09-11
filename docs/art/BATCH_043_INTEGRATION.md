# Batch 043 — integration handoff

**Arty** · for **Production** and **Dess**

The asset interface for a controlled integration trial. **Gameplay behaviour
and collision are Production's** — nothing here decides what a power cell
does when it is inserted, how heavy a ballast feels, what a switch triggers,
or where a collider goes.

All of it is **PROPOSAL** art. No registry entry is added, no approved asset
is touched, no mechanic is implemented, and the playable build is unchanged.
**Batch 043 stays available for integration feedback**; these remain
candidates until their gameplay use is checked.

---

## 0 · The pinned revision

Everything below describes **exactly this revision** and nothing else. If a
number here disagrees with a file, the file wins and this document is stale.

| | |
| --- | --- |
| **Art revision** | **`7ea95e2`** — branch `claude/archipepsi-art` |
| Design read | `a20bf55` · `docs/design-proposals/06_THE_AMALGAM.md` |
| ECMS Glyph | `6c80b63` · branch `claude/archipepsi-glyph-tooling` — **unchanged by this batch** |
| Godot | 4.5.1, Compatibility renderer, `xvfb-run --rendering-driver opengl3` |
| Blender | headless, `.tools/blender/blender` |
| Packages | `docs/art/packages/archipepsi-art-batch043-REVIEW.zip` · `-SOURCE.zip` |

**The pin is on the ASSETS.** This document and the import examples are
committed after `7ea95e2`, so the doc's own commit is later — but every
`.glb`, texture and manifest is byte-identical between them, which is the
part a consumer depends on and is checkable:

```
git diff --stat 7ea95e2 HEAD -- assets/     # empty
```

**Verified at this revision:**

```
verify-geometry: 15 size(s) and 21 attach point(s) verified against the
                 exported geometry, in runtime Y-up coordinates
check-docs:      260 of 260 built assets have their metrics quoted and verified
```

Re-run both with:

```
python3 tools/content/verify_exported_geometry.py
python3 tools/blender/check_docs_metrics.py
```

---

## 1 · Coordinates — read this before using any number

Blender authors **Z-up**; glTF is **Y-up by definition**. Every manifest
entry therefore carries **two size fields that are not the same triple**:

| field | frame | what it is |
| --- | --- | --- |
| `size` | **authoring**, Blender Z-up: width X, depth Y, height Z | the shared exporter's own field, identical in meaning across every batch. Deliberately left alone |
| `size_runtime_y_up` | **runtime**, glTF/Godot Y-up: `{x, y_up, z}` | **what you want.** `common.runtime_size()` maps (x, y, z) → (x, z, y) |
| `size_authoring_blender_z_up` | authoring | the same as `size`, spelled out, so the two cannot be confused by shape |

Attach-point `position` and `normal` are in **runtime axes**, with the
origin shift applied once and the Y-up conversion applied once.
`authored_blender_z_up` sits beside each for traceability and is **not** the
runtime value.

An earlier revision filled `size_runtime_y_up` from the authoring triple, so
Y and Z were swapped in all fifteen entries. It is now checked:
`verify_exported_geometry.py` measures the union AABB **with node transforms
accumulated** and refuses to run unless the manifest holds an object
asymmetric enough for a swap to show.

---

## 2 · The twelve object classes

`assets/models/batch043/physics/` · manifest keyed by asset id.

All are **floor-anchored**: local Y 0 is the ground plane, so an asset placed
at a floor position stands on it with no offset. `+X` is the object's length.

| class | mass | carriable | manipulable | derived | model | runtime X · Y-up · Z |
| --- | ---: | --- | --- | --- | --- | --- |
| `KEY_COMPONENT` | 8 | yes | yes | `LIGHT` | `phys_key_component.glb` | 0.246 · 0.305 · 0.195 |
| `GENERIC` | 15 | yes | yes | `LIGHT` | `phys_generic.glb` | 0.645 · 0.625 · 0.646 |
| `POWER_CELL` | 40 | yes | yes | `MEDIUM` | `phys_power_cell.glb` | 0.340 · 0.600 · 0.340 |
| `MECHANICAL_PART` | 55 | yes | yes | `MEDIUM` | `phys_mechanical_part.glb` | 0.475 · 0.430 · 0.403 |
| `PLATE` | 60 | **no** | yes | `MEDIUM` | `phys_plate.glb` | 1.800 · 0.145 · 0.920 |
| `DRUM` | 70 | **no** | yes | `MEDIUM` | `phys_drum.glb` | 1.029 · 0.684 · 0.684 |
| `GIRDER` | 95 | **no** | yes | `MEDIUM` | `phys_girder.glb` | 3.201 · 0.260 · 0.200 |
| `WEIGHTED` | 140 | **no** | yes | `HEAVY` | `phys_weighted.glb` | 0.820 · 0.696 · 0.860 |
| `CART` | 180 | **no** | yes | `HEAVY` | `phys_cart.glb` | 1.360 · 0.670 · 0.856 |
| `MOVABLE_COVER` | 220 | **no** | yes | `HEAVY` | `phys_movable_cover.glb` | 1.326 · 1.720 · 0.260 |
| `BALLAST` | 320 | **no** | yes | `HEAVY` | `phys_ballast.glb` | 1.125 · 0.497 · 0.825 |
| `ANCHOR_BLOCK` | 500 | **no** | **no** | `FIXED` | `phys_anchor_block.glb` | 0.988 · 0.689 · 0.988 |

Masses and both flags are **Design 2 §10.1's**, quoted. `mass_class` is
derived by §10.2 and never declared. **Every dimension is a proposed art
dimension** — no runtime contract for object size or attachment interfaces
exists, and this table is not one.

### Attachment frames

Each `attach_points` entry names the **node** it lies on, a `position` and a
unit `normal` in runtime axes, and what it proposes. Twenty-one in total:

| asset | points |
| --- | --- |
| `phys_key_component` | `attach_bit` — the keyed underside, `n = (0, −1, 0)`. Asymmetric, so it enters one way round only |
| `phys_generic` | `grip_hand_0/1` — recessed hand grips, `n = (0, 0, ±1)` |
| `phys_power_cell` | `attach_socket` — the face that meets a power socket, `n = (0, −1, 0)` |
| `phys_mechanical_part` | `attach_key` — the keyed flange face, `n = (0, 0, 1)` |
| `phys_plate` | `attach_slot_0/1` — lifting slots, both `n = (0, 1, 0)`, symmetric within the slab |
| `phys_drum` | `attach_hub_0/1` — end hubs on the rolling axis, `n = (±1, 0, 0)` |
| `phys_girder` | `attach_end_a/b` — end plates, `n = (±1, 0, 0)` |
| `phys_weighted` | `attach_push_0/1` — opposite push faces, `n = (0, 0, ±1)` |
| `phys_cart` | `grip_bar` — a push bar at one end only, `n = (−1, 0, 0)` |
| `phys_movable_cover` | `attach_push_0/1` — push faces on both sides, `n = (0, 0, ±1)` |
| `phys_ballast` | `attach_pad_0…3` — four pads, `n` on ±X and ±Z |
| `phys_anchor_block` | `attach_eye` — the tether eye, `n = (0, 1, 0)`. The **only** fitting on the class |

### Material controls

Two roles per asset, in `material_roles`:

| role | material name | what it is |
| --- | --- | --- |
| `body` | `<asset_id>` | the painted field. Quiet: near-flat, deliberate seams at a per-class pitch, wear at the edges only |
| `handling` | `<asset_id>_grip` | unpainted dark steel, **fully matte** (roughness 0.95) so it cannot catch the room's specular and out-shine the body |

Each fitting is **its own node with exactly one material slot**, so
`set_surface_override_material(0, m)` on the node is enough to light it —
which is §33.7's *"attach point available: visible marker when within 6 m"*.

**Reading the family.** Unpainted dark steel appears only where the player's
device touches. A hand grip follows §10.1's **`carriable` flag**, not a mass
threshold — §10.3's 60 kg is necessary, not sufficient, and `PLATE` is
exactly 60 kg and **not** carriable, so it has lifting slots and no grip.
`ANCHOR_BLOCK` has neither grip nor pad.

Measured in the render across all twelve, the fitting sits at least
**17.9 L\*** below its body on bright concrete and **13.4 L\*** on dark
derelict.

**No collision.** None is derived, none ships, and nothing here is traversal
or physics evidence.

---

## 3 · The machinery presentation

`assets/models/batch043/machinery/`

| asset | anchor | runtime X · Y-up · Z | drivable nodes |
| --- | --- | --- | --- |
| `mach_conduit_run.glb` | wall | 2.060 · 0.500 · 0.176 | `state_band`, `fill_band` |
| `mach_wall_switch.glb` | wall | 0.360 · 0.535 · 0.190 | `hinge_lever`, `lever_arm`, `state_lens` |
| `mach_receiver_lamp.glb` | floor | 0.500 · 0.370 · 0.260 | `state_lens_0`, `state_lens_1` |

| to do this | do this |
| --- | --- |
| swap a conduit's state | `set_surface_override_material(0, m)` on `state_band`. **Never scale it** |
| scroll `active` / `pulse_travelling` | `uv1_offset.x` on the band material |
| grow `delayed` | scale **`fill_band`** on X only. Fixed end from its own AABB: `position.x = base + x₀·(1 − s)` |
| hide the fill | `fill_band.visible = false` for every state but `delayed` |
| move a lever | rotate **`hinge_lever`** about X. It is an Empty at the pintle; its own origin is the attachment point and cannot move |
| light an indicator | `state_lens`, `state_lens_0`, `state_lens_1` — one material slot each |

Band tile: 64 × 16 px = **2.00 × 0.50 m at 32 texels/m**, asserted on both
axes at build time. Clamps at the 0.50 m bolt pitch.

The five `§19.5` states, with the measured trough value that separates them:

| state | mean L\* | pattern | motion |
| --- | ---: | --- | --- |
| `inactive` | 22.0 | unbroken hairline | none |
| `pulse_travelling` | 34.5 | one block, constant length | scrolls +X, 4.0 m/s |
| `blocked` | 41.0 | broken blocks, bright cut ends, one severance | none |
| `delayed` | 27.1 track + a lit fill | graduated track between two **fixed** end stops | `fill_band` grows |
| `active` | 47.3 | chevrons cut out of the bar | scrolls +X, 0.6 m/s |

---

## 4 · Four import examples

Runnable, and **run**: `tools/content/import_examples.gd`, driven by
`tools/content/run_import_examples.sh`. Every figure quoted below is that
script's own output at `7ea95e2`, recorded in
`docs/art/review/props_2026-09-11/room/import_examples.json`.

These show the **asset interface**. They add no physics body, no collider and
no behaviour.

### 4.1 A carriable prop — `POWER_CELL`

```gdscript
var cell := ArtBench.load_glb("%s/batch043/physics/phys_power_cell.glb" % models)
add_child(cell)

# Floor-anchored: local Y 0 IS the ground plane, so no offset is needed.
cell.global_position = Vector3(2.5, 0.0, -1.25)
cell.rotate_y(deg_to_rad(35.0))

# The grip is a named node, and it is geometry rather than a marker --
# so its own AABB centre is the point a hand closes on.
var grip := cell.find_child("grip_bar", true, false) as MeshInstance3D
var grip_world := grip.global_transform * grip.mesh.get_aabb().get_center()

# The socket face comes from the manifest, in runtime axes. It is a point
# ON the asset, so it travels with it like any other point.
var socket := cell.global_transform * Vector3(0.0, 0.004, 0.0)
var normal := cell.global_transform.basis * Vector3(0.0, -1.0, 0.0)
```

Measured:

```
size_runtime               [0.34, 0.6, 0.34]
aabb_min_y                 0.0            <- stands on the plane it is placed on
grip_world                 [2.5, 0.575, -1.25]
grip_bar_end_after_yaw     [2.59, 0.575, -1.313]   <- the yaw moved it
socket_world_after_yaw     [2.5, 0.004, -1.25]
socket_normal_after_yaw    [0.0, -1.0, 0.0]
```

### 4.2 A manipulate-only prop — `BALLAST`

No grip. Four attach pads, and the useful question is which one faces the
player.

```gdscript
var ballast := ArtBench.load_glb("%s/batch043/physics/phys_ballast.glb" % models)
add_child(ballast)
ballast.rotate_y(deg_to_rad(20.0))

# Straight out of the manifest, runtime axes.
const PADS := [
    {"id": "attach_pad_0", "at": Vector3(0.0, 0.297, 0.39),  "n": Vector3(0, 0, 1)},
    {"id": "attach_pad_1", "at": Vector3(0.0, 0.297, -0.39), "n": Vector3(0, 0, -1)},
    {"id": "attach_pad_2", "at": Vector3(-0.54, 0.297, 0.0), "n": Vector3(-1, 0, 0)},
    {"id": "attach_pad_3", "at": Vector3(0.54, 0.297, 0.0),  "n": Vector3(1, 0, 0)},
]

var best := ""
var best_dot := -2.0
for pad in PADS:
    var n: Vector3 = ballast.global_transform.basis * pad["n"]
    var p: Vector3 = ballast.global_transform * pad["at"]
    var facing := n.normalized().dot((eye - p).normalized())
    if facing > best_dot:
        best_dot = facing
        best = pad["id"]

# Each pad is its OWN node with one material slot, so it can be lit when
# the player is close enough to use it (§33.7).
var node := ballast.find_child(best, true, false) as MeshInstance3D
node.set_surface_override_material(0, highlight)
```

Measured, for an eye at `(0, 1.6, 3)`:

```
pads                4
chosen              attach_pad_0
facing_dot          0.826
```

### 4.3 The fixed anchor — `ANCHOR_BLOCK`

```gdscript
var anchor := ArtBench.load_glb("%s/batch043/physics/phys_anchor_block.glb" % models)
add_child(anchor)

# One fitting, and it is not for moving the anchor.
var eye := anchor.global_transform * Vector3(0.0, 0.651, 0.0)
```

Measured:

```
manipulable          false
mesh_nodes           ["phys_anchor_block", "attach_eye"]
grips_or_push_pads   0
tether_eye_world     [0.0, 0.651, 0.0]
```

The absence is the interface: there is **no fitting for moving it**, by
construction, because §10.1 says it is never moved and §33.7 says a `FIXED`
object visibly does not share the manipulable treatment.

### 4.4 The switch and conduit presentation

```gdscript
# (a) the lever: rotate the HINGE, never the arm.
var hinge := sw.find_child("hinge_lever", true, false) as Node3D
hinge.rotate_x(deg_to_rad(-52.0))

# (b) the indicator: one material slot on its own node.
var lens := sw.find_child("state_lens", true, false) as MeshInstance3D
lens.set_surface_override_material(0, lit)

# (c) the conduit: the TRACK never moves; only the fill grows.
var band := run.find_child("state_band", true, false) as MeshInstance3D
var fill := run.find_child("fill_band", true, false) as MeshInstance3D
var x0 := fill.mesh.get_aabb().position.x
var frac := 0.55
fill.visible = true
fill.scale = Vector3(frac, 1.0, 1.0)
fill.position.x = base_x + x0 * (1.0 - frac)
```

Measured:

```
pivot_moved_m            0.0        <- the attachment point does not move
band_span_x              [-1.0, 1.0]
track_world_x            [-1.0, 1.0]     <- unchanged by the fill
fill_at_55pct_world_x    [-1.0, 0.1]     <- grows from the fixed end
endpoints_move           false
```

---

## 5 · The status graphic kit

2D, no mesh. `docs/art/review/status_2026-09-11/`

| | |
| --- | --- |
| assets | `png/*.png`, individual and transparent. The atlas is a supplement |
| manifest | `status_kit.json` — id, family, `targets`, `sentence`, duration, chance, components, native size, depletion track |
| marker | 32 × 32; the glyph is 16 × 16 seated at (8, 8); the tick is 8 × 8 at (23, 23) |
| reduced treatment | the 16 × 16 glyph **alone** — a different picture, not a smaller one |

Screen-fixed, world-anchored: `Sprite3D` with `billboard = enabled`,
`fixed_size = true`, `texture_filter = NEAREST`, `alpha_cut = DISCARD`. At
`pixel_size` 0.0032 a 32 px marker occupies 32 screen px in a 700 px-tall
viewport.

**Depletion has no ring asset.** Each frame's own outer edge is the track;
`status_kit.json → depletion.tracks[<frame>]` is that edge as an ordered
pixel list, clockwise from 12 o'clock, 76–112 px long. Paint the first
`remaining` fraction in `lit` and the rest in `spent`.

**Target legality is data.** `targets` per status is §15.2's own column:
twelve of the twenty-one are legal on an `OBJECT`, eight are actor-only, and
`arc_path` is surface-only. A runtime should refuse an illegal pair at §15.4
step 1, visibly. The art preview fails its own run on one.

Nothing here uses a reserved grammar colour. Not supplied: any HUD, any
status runtime, any world-space marker renderer.

---

## 6 · Production integration dependencies

Open, recorded, and **not blocking the visual kit**.

### 6.1 Audio — §19.5's three cues

| state | cue | status |
| --- | --- | --- |
| `active` | a low hum | **not supplied** |
| `pulse_travelling` | a click on arrival | **not supplied** |
| `delayed` | a rising pitch | **not supplied** |

§19.5's row for `delayed` is *"filling-band animation showing remaining time,
rising pitch"* — **the filling band is the primary timing channel and it is
delivered**, with both endpoints static and a labelled 4.0 s demonstration at
five known fractions. The rising pitch is the second channel. The visual kit
does not wait on sound; these three remain open against whoever owns audio.

### 6.2 Everything else still required

1. **Collision**, for every object in §2. None exists.
2. **An object contract** — dimensions and attachment interfaces for the
   twelve classes. Ours are art dimensions and will move to fit one.
3. **The signal graph** the conduit states would display.
4. **A HUD**, for §33.10's three-tier contract. The preview's persistent
   tier is a mock.
5. **A world-space marker renderer.** Nothing in Production draws one.
6. **A status runtime** — duration, depletion fraction, compound check and
   the applied-by-player flag are preview literals.
7. **`ACTOR` status targets** wait on req 31; seven of ten enemy roles are
   still unspawnable. Art did not route around it.

---

## 7 · Checks that stand behind this handoff

| check | catches |
| --- | --- |
| `verify_exported_geometry.py` — sizes | a swapped or relabelled axis convention, measured with node transforms. Refuses to run without an asymmetric object |
| `verify_exported_geometry.py` — attach points | a missed origin shift, a double shift, a point naming a node not in the `.glb` |
| `props_preview.gd` contrast probe | the family's value rule failing in the render |
| `common.assert_parts_touch` | a fitting floating off the body or off the chain that reaches it |
| `common.assert_budget_group` | a split mesh buying triangles |
| `author_conduit_states.mjs` brightness floor | `inactive` and `blocked` collapsing onto one channel |
| `status_preview.gd` legality gate | an example scene contradicting `status_kit.json` |
| `inspect_glb_nodes.py` | a state region arriving as a material slot with no node to drive |
| `import_examples.gd` | the interface in this document drifting from the assets |

Each was made to fail on purpose before it was trusted.

---

## 8 · Holds still in force

- **No junction shell, dead-end plug or warp station** until Dess returns the
  doorway contract.
- **`shell_span_basin` untouched** until Production supplies the precise
  route/collider finding.
- The twelve shipped shells and every approved asset are unchanged.
