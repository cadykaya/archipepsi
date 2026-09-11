# Batch 043 / C — Design 2's twelve object classes, all built

**Arty**

Design 2 §10.1, pinned by Design 6 §4.7. Twelve classes, each with a typical
mass and two flags. **All twelve now have a textured, exported candidate.**

**Masses, `carriable` and `manipulable` are the design's and are quoted.
Everything else here is a proposal.** `mass_class` is derived from `mass_kg`
by §10.2 and never declared — the column below is computed by
`build_physics_props.py`, not typed.

---

| class | mass | carry | manip | derived | candidate | size (m, runtime axes) | tris |
| --- | ---: | --- | --- | --- | --- | --- | ---: |
| `KEY_COMPONENT` | 8 | yes | yes | `LIGHT` | `phys_key_component` | 0.25 × 0.20 × 0.30 | 108 |
| `GENERIC` | 15 | yes | yes | `LIGHT` | `phys_generic` | 0.65 × 0.65 × 0.62 | 96 |
| `POWER_CELL` | 40 | yes | yes | `MEDIUM` | `phys_power_cell` | 0.34 × 0.34 × 0.60 | 148 |
| `MECHANICAL_PART` | 55 | yes | yes | `MEDIUM` | `phys_mechanical_part` | 0.47 × 0.40 × 0.43 | 136 |
| `PLATE` | 60 | **no** | yes | `MEDIUM` | `phys_plate` | 1.80 × 0.92 × 0.14 | 68 |
| `DRUM` | 70 | **no** | yes | `MEDIUM` | `phys_drum` | 1.03 × 0.68 × 0.68 | 108 |
| `GIRDER` | 95 | **no** | yes | `MEDIUM` | `phys_girder` | 3.20 × 0.20 × 0.26 | 84 |
| `WEIGHTED` | 140 | **no** | yes | `HEAVY` | `phys_weighted` | 0.82 × 0.86 × 0.70 | 108 |
| `CART` | 180 | **no** | yes | `HEAVY` | `phys_cart` | 1.36 × 0.86 × 0.67 | 232 |
| `MOVABLE_COVER` | 220 | **no** | yes | `HEAVY` | `phys_movable_cover` | 1.33 × 0.26 × 1.72 | 108 |
| `BALLAST` | 320 | **no** | yes | `HEAVY` | `phys_ballast` | 1.12 × 0.82 × 0.50 | 120 |
| `ANCHOR_BLOCK` | 500 | **no** | **no** | `FIXED` | `phys_anchor_block` | 0.99 × 0.99 × 0.69 | 80 |

Sizes are in **runtime axes** — X, **Y up**, Z — because that is what a
loader sees. See *Coordinate spaces* below; this distinction was wrong in the
first revision of this file and it is not a pedantic one.

---

## The family rule

Design 2 §33.7, always: *"Manipulable objects have a consistent material
treatment; `FIXED` objects visibly do not share it."*

A coloured sticker satisfies the letter of that and fails §50's
no-hue-alone rule the moment the room is dark. So the treatment is
**unpainted dark steel — flat, smooth, far below any painted body in value —
and it appears only on the surfaces the player's device touches.**

The first attempt used a *light* bare metal and it failed in the room.
`concrete_facility`'s painted bodies sit at L\* 60–70 and a light steel pad
landed straight on top of them: a 16 cm attach pad on the ballast read as a
stain. Dark is not a style choice, it is the side of the value axis that was
free. `room/PROPS_lineup_bright.png` and `room/PROPS_lineup_dark.png` are the
same twelve under bright concrete and dark derelict; the fittings hold on
both, which is what a value-carried rule has to survive.

The second half is the read between carriable and merely manipulable, which
§10.3 draws at 60 kg:

| | fitting |
| --- | --- |
| `KEY_COMPONENT` 8, `GENERIC` 15, `POWER_CELL` 40, `MECHANICAL_PART` 55 kg | **a hand-scale grip** |
| `PLATE` 60 … `BALLAST` 320 kg | **device attach pads**, and no grip at all |
| `ANCHOR_BLOCK` 500 kg, `FIXED` | **neither** — see below |

A hand grip means a hand can lift it. Its absence, on an object that plainly
has attachment features, means a device has to. `PLATE` is the sharpest case:
exactly on the 60 kg line, and §10.1 puts it on the manipulate side, so it
has lifting slots and no grip — and that is the most informative thing about
it.

## `GENERIC` and `DRUM`: two candidates, not one contradictory promise

An earlier revision of this file called `prop_crate` and `prop_oil_drum`
manipulable candidates while the comparison frame showed them as the
*decorative* half of the family rule. Both statements were in the package and
they cannot both be true.

They are now separated. **`prop_crate` and `prop_oil_drum` are unchanged,
still approved, and still decoration** — painted end to end, no fittings,
nothing a device grips. `phys_generic` and `phys_drum` are their manipulable
siblings: the same object class, carrying the handling language.
`room/PROPS_candidate_vs_decorative_*.png` puts each pair side by side.

`phys_generic` is 0.62 m rather than `prop_crate`'s 1.0 m, because at 1.0 m a
box reads as furniture and §10.1 gives `GENERIC` 15 kg.

**A one-metre crate is not automatically a step.** An earlier note said
`prop_crate` is climbable "by design" because it equals
`Constants.MAX_VERTICAL_STEP`. That constant is a bound in the traversal
schema; it is not a statement that the current player can step onto a
free-standing object of that height, and nothing in this lane has tested one.
The claim is withdrawn.

## `ANCHOR_BLOCK` reads as fixed

§10.1: *"a `FIXED` world attachment point that can be revealed or destroyed
but never moved."* §33.7: a `FIXED` object visibly does not share the
manipulable treatment.

So it has none of the movable family's fittings — no hand grip, no push pad,
no attach pad, nothing a device could take hold of to shift it. It is cast
into a skirt that spreads onto the floor, it is wider at the bottom than the
top, and it has exactly one bare-steel feature: a **tether eye** on its
crown. A device does touch an anchor block, just never to move it, so the eye
is bare and everything else is cast. That is the sentence the class needs:
*you attach to this; you do not attach it to anything.*

`room/PROPS_fixed_vs_movable_bright.png` and `_dark.png` put it beside a
320 kg `BALLAST` — four attach pads, skids, and meant to move.

## Coordinate spaces, and the origin shift

Blender authors **Z-up**; glTF is **Y-up by definition** and the exporter
converts on the way out. An earlier manifest said *"+X is the object's
length; +Z is up"* beside geometry that had already been exported Y-up. That
is a contract nobody can follow, and it was wrong twice over, because the
attachment positions were also recorded *before* `set_origin_group` re-based
each asset on its anchor.

There are two transformations between an authored point and a runtime one,
and both now happen, each exactly once:

1. the **origin shift**, which `set_origin_group` now returns so a caller can
   apply it to recorded points; then
2. the **Y-up conversion**, `(x, y, z)_blender → (x, z, −y)_runtime`.

Every manifest entry carries a `coordinate_space` block naming both frames,
`size_runtime_y_up`, `orientation_runtime`, and per attach point both
`position` / `normal` in runtime axes **and** `authored_blender_z_up` beside
them, so neither can be mistaken for the other.

**And it is checked against the shipped geometry.**
`tools/content/verify_attach_points.py` opens each exported `.glb`, finds the
node the attach point names, reads that node's own accessor bounds, and
confirms the recorded runtime position lands on it:

```
verify-attach: 21 attach point(s) verified against the exported geometry,
               in runtime Y-up coordinates
```

The check bites: displacing one point by 0.35 m — a plausible missed shift —
produces
`phys_ballast/attach_pad_0 at [0.0, 0.647, 0.39] is off its own part`.

## Fittings are connected, and that is asserted too

`common.assert_parts_touch` floods outward from the body and fails the build
for any fitting that meets neither the body nor anything already connected to
it. It was written because two fittings had already shipped floating:
`phys_key_component`'s carry grip 43 mm above its case, and
`phys_weighted`'s push pads 10 mm off the posts they sit on. Both were
positioned against a NOMINAL class height instead of the body's measured top.

It is a **box-overlap** test, which is a lower bound on contact: two boxes can
overlap while the shapes inside them do not. It catches gross floats. It is
not a proof of surface contact.

## What is proposed and what is settled

**Settled, because §10.1 and §10.2 state it:** the twelve masses, the
carriable and manipulable flags, and each derived `mass_class`.

**Proposed, because nothing states it:** every dimension, every attach-point
position and normal, and the bare-metal rule itself. No runtime contract for
object dimensions or attachment interfaces exists. These are **art
dimensions** and will move to fit a contract when one arrives.

**No collision.** None is derived, none ships, and nothing here is traversal
or physics evidence. Player physics, mass rules, carry limits and package
schemas are untouched.

## One thing the room corrected that a sheet could not

The ballast was first built at 0.86 × 0.66 × 0.66 — near enough a cube that in
the room it read as `prop_crate` in a bigger size, which is the one thing a
320 kg counterweight must not do. It is now a 2:1 footprint-to-height block
with heavier skids. **Weight is proportion before it is texture.**
