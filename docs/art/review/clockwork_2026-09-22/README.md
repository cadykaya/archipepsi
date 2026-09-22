# T02 — Super Mario 64, Tick Tock Clock: the second game pack, in context

**Arty**

Batch 056 content, 056-R context. 2026-09-22. Branch
`claude/archipepsi-art`, PR #5.

**PROPOSAL. Not imported, not runtime-bound, not owner-approved.**

---

## Same shell, same four cameras, different place

`CK_approach`, `CK_movement`, `CK_threshold` and `CK_chamber` are shot
from **exactly** the positions `FT_approach`, `FT_relief`, `FT_threshold`
and `FT_chamber` use in `docs/art/review/forest_temple_2026-09-22/`, in
exactly the same Production-grey shell. Put the two `*_approach.png`
side by side: if the packs read as the same room with different paint,
that is the verdict and the framing did not hide it.

---

## The subtheme is chosen and stated: **Tick Tock Clock**

Super Mario 64 has fifteen courses. The packet's concept for T02 is
"Clockwork Garden", which has **two halves**. This pack is the clockwork
half. **Peach's hedged courtyard is the deliberate second subtheme and is
not built here** — a courtyard and a movement do not share a material
culture, and pretending they do is how a pack stops reading as a place.

Not Bob-omb Battlefield, which is the more famous course: a green hill
reads as *no theme at all* in a 1998 shooter's palette, and the house
already owns institutional grey and rusted metal. A movement is
unmistakable from any angle, at any distance, in any light — which is
the test a pack has to pass.

---

## The six pieces

| asset | tris | what makes it this pack's, and not `rusted_industrial`'s |
|---|---|---|
| `tp_ck_gear_column` | 160 | the column is a **shaft**: it transmits torque. The house column holds a roof up. |
| `tp_ck_wall_movement` | 172 | the panel is **parted** and the works show through, held by a bridge the way a movement is. T01's relief is split; this one is open. |
| `tp_ck_door_bezel` | 72 | the opening is dressed as a **dial** — minute marks up the jambs, XII over the head. |
| `tp_ck_fallen_hand` | 88 | floor dressing that **fell**, where T01's grew. And it is bent, because a straight one is bar stock. |
| `tp_ck_pendulum_lamp` | 64 | the fitting **hangs and swings**. No house family has a light that is also a moving part. |
| `tp_ck_key_escutcheon` | 60 | Batch 043's wall-switch contract **wound**, not pressed: a square arbor with a handle on it. |

---

## What the room changed, which is the reason to build the room

**Four defects, three found by looking and one by reading the manifest.**

**1. The gears were lying down.** `_wheel` first built them from two
crossed boxes with `rotation_z` — the only rotation `brushkit.block`
offers. That makes a gear lying **flat**: right on a vertical shaft,
wrong on a wall. `tp_ck_wall_movement` measured **0.88 m deep on a
0.12 m plate**, because a 0.62 m square turned 45° *in plan* pokes
0.44 m straight through the wall it is mounted on. The manifest said so
before any render did. They are eight-sided prisms now, stood upright
with `brushkit.spin` where they belong.

**2. The XII did not fit the room.** Stacked above the lintel it topped
out at **3.78 m** against the chamber's 3.60 m ceiling. **A pack that
does not fit the room it dresses is not dressing it.** It sits on the
lintel's face now, projecting in depth.

**3. The column read as a pipe with flanges.** `CK_approach` showed it:
three flat discs stacked on a vertical shaft, seen from eye height, are
three horizontal lines. **A gear is only a gear face on.** The column now
carries an upright wheel with a pinion meshing below it, which is also
what a clock tower's shaft actually carries.

**4. The wheels read as slabs** until each got a raised hub. One prism,
28 triangles, and it is the difference between a gear and a stop sign.

---

## Nothing here wears the hazard band, and that is a rule

`rusted_industrial`'s `trim` role paints a **universal hazard band** —
correct on a walkway edge, a machinery boundary, a drop or a warning
surface — and **the colour is never decorative, in any theme, for any
reason.**

The first pass painted the gear wheels and the door marks with `trim`
and `accent`. The room showed the cost immediately: **a clock movement in
warning stripes, and a dial mark stencilled `hot`.** Nothing in a clock
room is a hazard boundary, so nothing in this pack carries the band. They
paint `trim_plain` — trim, minus danger — and collide as `trim`, because
`roomcollision.paint_role` knows four classes and `trim_plain` is not one
of them.

**T01 never hit this**, because `temple_ruin`'s trim carries no hazard
semantics. **Every later pack that reaches for `rusted_industrial`
will.**

---

## The finding worth handing to Prod/Dess

**The per-game hint and the pack's material disagree, and for T01 they
happened to agree.**

`Constants.THEME_BY_GAME_HINT` maps `"Super Mario 64" -> concrete_facility`.
That is the runtime's answer for this game today. A clock movement is
brass, steel and oil, so the nearest existing family **by material
culture** is `rusted_industrial`.

> The hint picks a family by **game**. A treatment follows what the pack
> is **made of**. Two questions, one field.

This is the clearest argument yet for `COVERAGE.md` §3's pack namespace,
and it is recorded in the manifest as `theme_hint_says` beside
`painted_with` so it is **data**, not a remark in a report.

Neither family is this pack's own treatment, and none is claimed.

---

## What I still think is weak

**The bridge over the wall movement's gear train is too heavy.** It does
the job a bridge does — a clock's gears are held by a plate over them,
and without one a gear train reads as decoration stuck to a wall — but at
0.78 × 0.50 m it hides most of the big wheel it spans. I would narrow it
to a strap before the owner spends a review on it.

**The wall movement's gears are less legible than the column's**, because
they are smaller and sit in a 0.36 m gap. That is the honest cost of
parting a 2.16 m panel rather than opening it wide; opening it wider
would make the panel read as a frame instead of a wall.

---

## The exact unfinished integration work

Identical to T01's, and it will be identical for every pack until the
namespace exists:

1. **Material treatment missing.** Painted in `rusted_industrial`. A tint
   does not count and none is claimed.
2. **No runtime selection**, and here the hint would select the *wrong*
   family even if it could name a pack.
3. **Not imported.** The `.glb`s are in `assets/models/batch056/`.
4. **No owner review.** `not started` in the completion ledger.

---

## How to regenerate

```
.tools/blender/blender -b --python tools/blender/build_clockwork.py
tools/content/run_pack_views.sh tp_super_mario_64
```

The shell, the gates and the opening check are shared
(`tools/content/pack_views.gd`, `tools/blender/packgates.py`); **where
the pieces go is art** and lives in
`tools/content/packlayouts/tp_super_mario_64.json`. There are eighteen
packs in the first wave and sixty-three behind them; the alternative is
eighty-one copies of one harness.
