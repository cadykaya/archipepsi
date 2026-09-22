# Batch 045 — visual kits for the four 0.4 setpieces

**Arty**

**To:** Prod (integration) and Dess (selection, where it applies)
**Art head:** this commit, branch `claude/archipepsi-art`
**Fitted against:** Production `claude/archipepsi-0-4-blindside` @ `f404410`

**Every asset here is a CANDIDATE.** Imported and fit-checked; **not**
runtime-bound and **not** owner-approved. Those are three separate states
and this delivery claims the first two only.

---

## What this is

The four 0.4 rooms work, and they are built out of `BoxMesh`.
`RailCarrier` makes a 4 × 0.4 × 4 box and calls it a skiff. This batch
gives those working machines a visual identity **without changing one
number they run on** — no collider, body, trigger, light, camera or
script rides along, and no speed, timing, mass, placement or topology is
touched.

| id | tris | size (m) | parts | for |
|---|---|---|---|---|
| `sp_skiff_deck` | 300 | 4.00 × 4.16 × 1.49 | 24 | Blindside carrier |
| `sp_dock_stand` | 72 | 0.80 × 0.80 × 1.27 | 5 | Blindside dock control |
| `sp_hoist_car` | 132 | 4.00 × 4.00 × 1.48 | 10 | Passing Platforms, vertical |
| `sp_crossing_carrier` | 96 | 4.04 × 4.00 × 0.88 | 7 | Passing Platforms, horizontal |
| `sp_receiver_hood` | 72 | 2.40 × 1.14 × 1.70 | 5 | Counterfire receiver |
| `sp_lane_screen` | 60 | 0.34 × 3.00 × 1.37 | 4 | Counterfire lane protection |
| `sp_shutter_leaf` | 60 | 0.48 × 2.40 × 2.60 | 4 | Counterfire shutter |
| `sp_weight_plate` | 72 | 2.40 × 2.40 × 0.16 | 5 | Unweighted sensor |
| `sp_ballast_crate` | 132 | 2.12 × 2.12 × 1.00 | 10 | Unweighted crate |

All at **32 texels/m**, the architecture band — deliberately, because a
skiff at the prop band's 64 standing against docks and yard walls at 32
reads as a different game's asset pasted in.

Source: `tools/blender/build_setpieces.py`. Exports:
`assets/models/batch045/setpieces/`. Evidence:
`docs/art/review/setpieces_2026-09-22/`.

---

## 1 · The one thing I need from Prod: a bounded presentation hook

**There is no seam today.** `RailCarrier._ready()` does this:

```gdscript
var mesh_node := MeshInstance3D.new()
mesh_node.name = "Deck"
var mesh := BoxMesh.new()
mesh.size = deck
mesh_node.mesh = mesh
mesh_node.material_override = ThemeMaterials.trim_mat(_theme)
add_child(mesh_node)
_deck_mesh = mesh_node
```

I am **not** building a private loader, so I am not going around this.
The smallest change that would let the authored mesh in, for you to
accept, amend or refuse:

> An optional `visual: PackedScene` (or content id) on `RailCarrier`. When
> set, instantiate it as a child **instead of** building `Deck`, and leave
> `_deck_mesh` pointing at the instance's root so anything that currently
> drives `Deck` keeps working. When unset, today's `BoxMesh` — so nothing
> regresses if the asset is missing.

The same shape serves `passing_platforms.gd`'s two carriers and
`unweighted_switch.gd`'s crate. **Name it and I will use your name.**
Until it exists these are complete, correctly shaped assets sitting in a
folder — that is an integration task, not a reason to stop producing.

### The origin, which is the part that is easy to get wrong

`RailCarrier.pose()` returns `Transform3D(basis, here + basis.y * (deck.y
* 0.5))`, so **the node origin is the deck box's CENTRE, not its floor.**
Every deck asset here is authored about that origin. An asset authored
floor-anchored arrives 0.2 m low and nobody notices until a passenger
clips through. Local axes from the same function: `basis.x` is the dock
side, `basis.z` is travel.

---

## 2 · CORRECTION, 2026-09-22 — this section was wrong

> ~~**A handrail at a natural height would break the gantry guarantee.**
> `GANTRY_Y` 3.1 against a 1.333 m standing jump: a railing cap at 1.1 m
> above the deck sits at world 2.1, and 2.1 + 1.333 = 3.43, *above the
> gantry*. So nothing on a rideable deck rises past world 1.75 (node
> +0.95).~~

**Struck. It was the strongest claim in Batch 045 and both of its
numbers were wrong.** Found by measuring the yard for Batch 046 rather
than reading it.

**`GANTRY_Y` 3.1 is measured above the RAIL at 0.6, not above the
floor.** `_gantry()` puts the platform centre at world **3.70**, so it
spans **3.50 to 3.90**. A railing cap at world 2.1 reaches 3.433 —
below the platform's *underside*.

**And the platform is 3.5 m away horizontally.** It occupies lateral
5.5 to 9.5; the deck spans −2.0 to 2.0. A jump that travels 3.5 m across
has risen only 1.0 m by the time it arrives, so a player leaving that
railing gets to **3.10** — under the platform, still.

Even Production's own shield — `_shield()`, 1.25 m of cover on a
`CollisionShape3D` hung on an `AnimatableBody3D`, so genuinely solid and
standable, top at world **2.25** — reaches 3.583 straight up and 3.250
across the gap. **Nothing on this deck is a route to the gantry.**

### What changed as a result

The old cap made the skiff's guard rails **world 1.75 — half a metre
below the cover welded to the same deck.** They are now a natural 1.05 m
above the deck (world 2.05), a little under the shield so the shield
stays the tallest thing on the vehicle.

`assert_under_cap()` survives, with an honest job: **nothing on a
rideable deck stands taller than Production's own `SHIELD_HEIGHT`
cover.** That is an art rule about silhouette and it needs no arithmetic
about jumps. `setpiece_fit.gd` enforces the same.

**The failure mode is the one worth keeping:** the arithmetic was
careful and reproducible, and it was done against a constant whose
*frame* I assumed. If you take one number from this document, take
`assets/models/batch046/yard_fit.json` — the yard as evaluated, rather
than as read.

---

## 3 · State-addressable nodes, per asset

A region a runtime has to drive arrives as a node you can fetch by name.
A material slot is not a hinge.

| asset | nodes | what they are for |
|---|---|---|
| `sp_skiff_deck` | `lamp_fore`, `lamp_aft`, `beacon_hold`, `console_readout` | `RailCarrier` already has FORWARD / BACK / HOLD and emits `departed(from, dir)` and `refused(reason, detail)`. These are somewhere to put them. **Art declares the node; you decide what lights it and when.** |
| `sp_hoist_car` | `lamp_up`, `lamp_down` | direction before it moves |
| `sp_crossing_carrier` | `lamp_west`, `lamp_east` | ditto |
| `sp_receiver_hood` | `receiver_mouth` | the receiver accepting |
| `sp_shutter_leaf` | `shutter_edge`, `shutter_rib_0..2` | the leading edge during `OPEN_SECONDS` |
| `sp_weight_plate` | `plate_readout`, `plate_pad_*` | the class the sensor reads |
| `sp_ballast_crate` | `lightened_panel_0..3` | **LIGHTENED, and only this** |
| `sp_dock_stand` | `lever_fore`, `lever_aft`, `stand_readout` | both directions, and the refusal reason |

### The crate is a step, in every state

`CRATE` is (2.0, 1.0, 2.0) and `MAX_VERTICAL_STEP` is 1.0. The model is
**exactly 1.0 m tall in every state** and the four `lightened_panel_*`
nodes are the only things that change. A crate that shrinks or dissolves
to look lighter is a step that stopped existing, and the fit harness
fails the asset if its height moves by more than a millimetre.

---

## 4 · Evidence

`tools/content/run_setpiece_fit.sh` → `docs/art/review/setpieces_2026-09-22/fit.json`

It imports each GLB through the real glTF path and asks three questions
and one negative: does it import, do the named parts survive, does it fit
the envelope **read from your constants**, and does anything ride along
that should not.

```
[setfit] PASS -- 9 asset(s) imported, kept their parts, fit Production's
         envelope, and brought nothing else
```

**It bites.** Sabotage-tested by swapping real GLBs so the sizes are
genuinely wrong: it reported the crate at 0.340 m where the envelope is
2.000, the crate 1.370 m tall against `MAX_VERTICAL_STEP` 1.00, the crate
with no `lightened_*` node, and the plate 2.120 where it must be 2.400.

Build-time gates fired on their own author during this batch, which is
the honest record: `assert_under_cap` refused the skiff at node 1.070 and
again at 0.990, and `assert_parts_touch` refused two direction lamps
floating 0.47 m clear of the body.

`tools/content/run_setpiece_views.sh` renders all nine under the shipped
Zone's lighting — ambient 0.35, fog 0.012, shadowless omnis at range
12.0, no directional light — because a setpiece that only reads under a
key light is a setpiece that does not read.

---

## 5 · What I am NOT claiming

- **Not runtime-bound.** Nothing consumes these yet; see §1.
- **Not owner-approved.** Candidates, pending subjective visual review.
- **The skiff's console is the weakest element** — it reads a little flat
  against the deck pan. Named here rather than left for you to notice.
- **The first skiff was rejected by me**, not by a reviewer: painted in
  `trim` with thin rails it read as a slatted pallet with scaffolding.
  The deck is the `floor` role now, the ends are solid panels with a
  band, and it has a curb and corner bumpers. Both renders exist.
- **`sp_skiff_deck` is 4.16 m along the travel axis** — the two direction
  lamps stand 8 cm proud of the deck box at each end. The boarding sides
  are exactly 4.00, which is the axis where the docks meet the deck's
  outer edge. If the ends matter to you, say so and the lamps inset.
- **No pivot is invented for the shutter.** `sp_shutter_leaf` is authored
  about its box centre. A sliding shutter and a hinged one want different
  origins; tell me which and I will re-anchor rather than guess.
