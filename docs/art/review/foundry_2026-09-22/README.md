# T06 — DOOM 1993, the UAC techbase: the sixth game pack, and the runway

**Arty**

Batch 060. 2026-09-22. Branch `claude/archipepsi-art`, PR #5.

**PROPOSAL. Not imported, not runtime-bound, not owner-approved.**

---

## CORRECTION, after T07: the runway had ONE pack left, not two

The count below says two families remain. **It is one.** `void_glitch`
is not an option — it is Archipepsi's own missing-texture theme, an
editor checkerboard with the word `null` across it, and
`THEME_BY_GAME_HINT` maps it to Archipepsi itself. Painting a game pack
in it would mean *"this texture failed to load"*.

So **T07 (`gothic_stone`) was the last pack with a family of its own**,
and every pack from **T08** must share pixels or wait. The deadline is
one pack earlier than this file first said.

## The runway (as counted here, before the correction above)

T05 proved two packs sharing a house family read as one place, and that
different shapes cannot save them
(`docs/art/review/twilight_2026-09-22/README.md`). The workaround since
has been to give each pack a family nobody has used yet.

**Count it.**

```
temple_ruin        T01, T05      already doubled — T05 is the proof
rusted_industrial  T02, T04      already doubled
neon_transit       T03
concrete_facility  T06           ← this one
gothic_stone       —
void_glitch        —
```

**Two families unused. Seventy-five packs behind this one.**

> **The workaround runs out at T07** — see the correction at the top of
> this file; `void_glitch` cannot be spent. Every pack from **T08** on
> must share pixels with an earlier pack, or wait.

That is a deadline rather than an opinion, and it is the sharpest form
the namespace argument has taken in six packs. It is in the manifest as
`family_runway`, so it is data.

---

## The subtheme: **the UAC techbase, containment level**

DOOM 1993 has three episodes and they are three different places: a
techbase, a military installation, and Hell.

**Hell is the famous half, and it is also the half that is terrain** —
rock, flesh, fire. The techbase is the architecture, and architecture is
what a theme pack ships. The packet's concept, "Foundry Containment",
names the same choice.

No hint for DOOM 1993 — one of the 75 of 81 without one.

---

## The six pieces

| asset | tris | what makes it this pack's |
|---|---|---|
| `tp_dm_bank_column` | 132 | a column that carries **information**. Every other pack's carries a roof, a torque, a cable, a hull, a wire. This is the one whose job is to be looked *at*. |
| `tp_dm_screen_wall` | 108 | the wall is an **interface**, and the hand-run cable **loops** are the subject. Screens are furniture; loops are people solving something. |
| `tp_dm_blast_frame` | 72 | the opening dressed as a **marked blast door**. |
| `tp_dm_spill_trough` | 72 | floor dressing that **contains** something, grating dragged off and dropped skewed. |
| `tp_dm_light_recess` | 60 | the light is a stepped **recess**, not a fitting on a wall — **the only pack in six whose lamp is a hole rather than an object.** |
| `tp_dm_keycard_reader` | 60 | Batch 043's wall-switch contract as a **keycard reader**. Sixth material culture, same place on the same wall. |

---

## Where the accent is spent, and why that is a rule

`concrete_facility`'s `_concrete_accent` says it in its own docstring:
the accent marks a thing as **significant**, and *a colour that marks
everything marks nothing* — a review note this lane already paid for once
when every manufactured object in a room came out steel blue.

So this pack spends it on exactly two things: **the blast frame's
chevrons** and **the keycard reader's lamp column**. The four racks on
the bank column do not get it, because four racks on a column are not
four significant things.

That is the third family whose `trim`/`accent` semantics had to be read
before use — after T02 shipped a clock movement in warning stripes for
not reading `rusted_industrial`'s.

---

## Two gates, both routine by now

**`assert_parts_touch` caught the cable loops** floating 6 cm off
anything at 1.30 m. **A cable that touches nothing is not untidy, it is
floating.** They loop just above the desk now and drop behind it — which
is where hand-run cable actually goes, so the gate improved the art
rather than only permitting it.

**The no-foothold rule caught the grating leaned** against the trough
lip: 0.16 m tall in a 0.72 × 0.47 m footprint, above the 0.12 m walk-up.
A 0.66 m grating cannot shrink under the 0.35 m plan limit, and
`brushkit.block` only turns about Z so there is no steep lean to be had.
**Dragged off and dropped skewed says "somebody took this off" just as
well**, and the skew is what stops it reading as replaced.

---

## What I still think is weak

**The chevrons do not read at approach distance.** They are there in
geometry — a block projecting from each jamb face — but
`concrete_facility`'s accent is a *marked surface*, not a stripe, so at
9 m the frame reads as a frame. A real chevron is a painted pattern, and
**painting one is exactly what the missing material treatment would
do.** Another instance of the same finding.

**The trough is nearly invisible in `DM_approach`.** It is 0.15 m tall
dressing on a floor lit from the far side. It reads in `DM_chamber`. I
would rather it be honestly low than raised to suit one camera.

---

## The exact unfinished integration work

1. **Material treatment missing** — and the chevrons above are a
   concrete example of what it would buy.
2. **No runtime selection, and no hint.**
3. **Not imported.** `assets/models/batch060/`.
4. **No owner review.**
5. **The runway.** Two packs of it. See the top of this file.

---

## How to regenerate

```
.tools/blender/blender -b --python tools/blender/build_foundry.py
tools/content/run_pack_views.sh tp_doom_1993
```
