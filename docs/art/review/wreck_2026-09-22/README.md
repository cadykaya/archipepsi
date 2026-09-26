# T04 — Super Metroid, the Wrecked Ship: the fourth game pack, in context

**Arty**

Batch 058 content, 058-R context. 2026-09-22. Branch
`claude/archipepsi-art`, PR #5.

**PROPOSAL. Not imported, not runtime-bound, not owner-approved.**

---

## Four packs, one shell, four cameras

`WS_approach`, `WS_panel`, `WS_threshold` and `WS_chamber` are shot from
**exactly** the positions T01, T02 and T03 use, in **exactly** the same
Production-grey shell, with the dogging lever in the same place on the
same wall as T01's timber switch, T02's winding key and T03's ticket
validator.

Four `*_approach.png` side by side is the test. If they read as one room
with four coats of paint, that is the verdict.

---

## The subtheme: **the Wrecked Ship**

Super Metroid has six regions and **five of them are caves**, which is
terrain. The Wrecked Ship is the one that is architecture, and
architecture is what a theme pack ships. The packet's concept,
"Pressureworks Derelict", is the same choice in other words.

---

## The six pieces

| asset | tris | what makes it this pack's |
|---|---|---|
| `tp_ws_stanchion` | 84 | a ship's **frame member** — boxed and flanged, never round — with its own service run burst out of it and never repaired. |
| `tp_ws_bulkhead_panel` | 84 | the inspection hatch let go and is still on **one hinge**. A hatch on the floor is debris; a hatch still attached is an accident. |
| `tp_ws_pressure_door` | 132 | the opening dressed as a **pressure boundary**: dogging lugs, seal channel, banded threshold cheeks. |
| `tp_ws_debris_fan` | 72 | floor dressing that **blew out** — plates at spreading angles all pointing back at one origin. A pile points at nothing. |
| `tp_ws_lamp_cage` | 84 | a caged emergency lamp hanging **off true**. A straight fitting is one somebody maintains. |
| `tp_ws_dogging_lever` | 60 | Batch 043's wall-switch contract **thrown**, not pressed. |

---

## The finding: this is the first pack with no hint at all

| pack | `THEME_BY_GAME_HINT` | nearest family by MATERIAL | |
|---|---|---|---|
| T01 Ocarina of Time | `temple_ruin` | `temple_ruin` | agree |
| T02 Super Mario 64 | `concrete_facility` | `rusted_industrial` | **disagree** |
| T03 Bomb Rush Cyberfunk | `neon_transit` | `neon_transit` | agree |
| T04 Super Metroid | **none** | `rusted_industrial` | **nothing to compare** |

`THEME_BY_GAME_HINT` holds **six** entries. The catalogue holds **81
games**.

> **75 of 81 have no hint. A selection mechanism covering 7% of the
> catalogue is not a mechanism with an exception in it — it is a
> mechanism for six games.**

T02's disagreement was already an argument for `COVERAGE.md` §3's pack
namespace. This is sharper: for nine games in ten there is nothing to
agree or disagree *with*. Recorded as `theme_hint_says: null` plus the
count, so the gap is a number in the manifest rather than a sentence in
a report.

---

## The hazard band means something here, and that is the contrast with T02

Same family as T02. **Opposite answer. The difference is the geometry,
not the taste.**

`rusted_industrial`'s `trim` paints a universal hazard band — correct on
a walkway edge, a machinery boundary, a drop or a warning surface. T02
reached for this family and had to refuse the band **everywhere**,
because nothing in a clock room is a hazard boundary.

**A derelict is nothing but hazard boundaries.** The pressure threshold,
the lamp cage, the severed conduit — those are exactly the surfaces the
band was written for. They carry it; everything else carries
`trim_plain`. The striped conduit end in `WS_panel` is the band doing
its literal job.

---

## The coaming is the one part of a pressure door art cannot ship

A real pressure door has a raised sill you step over. The first cut of
`tp_ws_pressure_door` had one: 0.10 m tall, full width, across the
doorway.

**The gate refused it by 2.740 m and was right.**

It does not narrow the opening's *width*. It lays **floor** inside an
opening the player walks through, and floor is Production's whatever its
height.

And note what would have happened otherwise: **a 0.10 m step is under the
0.12 m walk-up**, so the no-foothold rule would never have seen it. The
opening rule is the only thing standing between a plausible detail and
art changing a walking surface.

What survives is the **mark without the step** — a banded cheek at the
foot of each jamb, outside the opening. **If the coaming should exist, it
is Production's to place and collide**, and that is a real request rather
than a complaint.

---

## The foothold rule shrank a lamp, and was right

`ws_lc_body` at 0.30 m square, turned 16°, measures **0.37 m in plan** —
above the 0.12 m walk-up, inside the 1.33 m jump, with nothing above it
tall enough to cover it.

The lamp hangs on a wall at 2.3 m in the room, so in *world* terms it is
not a step. **But the gate measures the asset's own frame and cannot know
where it will be hung, which is the correct thing for it to do.**
Shrinking a lamp is cheaper than an exception, and the same shape as
T02's pendulum bob.

---

## What the room found

**The hull plate was invisible.** The bulkhead panel first sat at
x −4.90 with a 0.14 m plate, **entirely inside the 0.4 m wall**, so the
frame read as ribs floating on grey. The hull is the subject of that
piece. It is at −4.80 now and stands proud.

**The first lighting was too dark to judge.** Ambient 0.22 with fog
0.026 made an honest derelict and an unreadable review frame. Lifted to
0.32 / 0.020 with a stronger emergency lamp — still one-sided, still
warm-from-the-wrong-place, but now the owner can see what they are being
asked about.

---

## What I still think is weak

**The two stanchions are the same object turned 180°**, and at this
distance the turn reads more as "one of them is backwards" than as "only
one is torn open". Placing them is layout, not geometry, so it is a
one-line change — but the honest fix is a second stanchion variant, and
that is a seventh asset this pack does not have.

**The debris fan reads better in `WS_panel` than in `WS_chamber`.** It
needs the raking light that the blown panel's lamp gives it; from above
it flattens into plates on a floor. That is a real limit of flat plating
at 0.05 m, not a lighting accident.

---

## The exact unfinished integration work

1. **Material treatment missing.** Painted in `rusted_industrial`.
2. **No runtime selection, and here not even a hint to misuse.**
3. **Not imported.** `assets/models/batch058/`.
4. **No owner review.**
5. **One request for Production:** if a pressure-door coaming should
   exist, it is theirs. Art has marked where it would go.

---

## How to regenerate

```
.tools/blender/blender -b --python tools/blender/build_wreck.py
tools/content/run_pack_views.sh tp_super_metroid
```
