# T03 — Bomb Rush Cyberfunk, Brink Terminal after hours: the third game pack, in context

**Arty**

Batch 057 content, 057-R context. 2026-09-22. Branch
`claude/archipepsi-art`, PR #5.

**PROPOSAL. Not imported, not runtime-bound, not owner-approved.**

---

## Three packs, one shell, four cameras

`BR_approach`, `BR_board`, `BR_threshold` and `BR_chamber` are shot from
**exactly** the positions T01's and T02's frames use, in **exactly** the
same Production-grey shell, with the ticket validator in the same place
on the same wall as T01's timber switch and T02's winding key.

Put the three `*_approach.png` beside each other. If the packs read as
one room with three coats of paint, that is the verdict and nothing in
the framing hid it.

---

## The subtheme: **Brink Terminal, after hours**

Bomb Rush Cyberfunk has six boroughs. A terminal is the half of that
game which is **architecture** rather than terrain, and architecture is
what a theme pack ships. Not Versum Hill's rooftops, not Mataan, not
Pyramid Island.

The concourse with the shutters down, the board dark, one strip light
out, and the tags that only happen when nobody is watching.

---

## The six pieces

| asset | tris | what makes it this pack's, and not `neon_transit`'s |
|---|---|---|
| `tp_br_concourse_pillar` | 84 | **tagged and worn through at grind height.** The house pillar is clean tile, because the house station still has staff in it. |
| `tp_br_board_panel` | 96 | a departure board caught **mid-flip**. One slat still turning says *until recently*; a board merely off reads as a missing texture. |
| `tp_br_shutter_head` | 72 | the opening is dressed as a **shuttered concourse gate** — head box, guide lips, bottom rail parked above the head. |
| `tp_br_torn_rail` | 72 | floor dressing that was **ridden off**, where T01's grew and T02's fell. Still carrying one stanchion and another's ripped baseplate. |
| `tp_br_strip_light` | 96 | a municipal batten with **one tube out**. The tell is a *material* difference, never an emissive one. |
| `tp_br_validator_plate` | 60 | Batch 043's wall-switch contract as a **ticket validator**: tap pad, paddle, lamp bezel. |

---

## The finding: the hint is usually right, and that is the problem

| pack | `THEME_BY_GAME_HINT` | nearest family by MATERIAL | agree? |
|---|---|---|---|
| T01 Ocarina of Time | `temple_ruin` | `temple_ruin` | yes |
| T02 Super Mario 64 | `concrete_facility` | `rusted_industrial` | **no** |
| T03 Bomb Rush Cyberfunk | `neon_transit` | `neon_transit` | yes |

The hint picks a family by **game**. A treatment follows what a pack is
**made of**. Two questions, one field.

> **A hint that is always wrong gets noticed. One that is right two times
> in three does not.**

That is the argument for `COVERAGE.md` §3's pack namespace, and it is
now three data points rather than an opinion. Each manifest records
`theme_hint_says` beside `painted_with`, and T03 records
`theme_hint_agrees` — **agreement is data too, not silence.**

---

## The hazard band, checked this time instead of assumed

T02 shipped a clock movement in warning stripes before anyone noticed
that `rusted_industrial`'s `trim` **is** the universal hazard band.

T03 looked first. Only `rusted_industrial` splits `trim` from
`trim_plain`; `neon_transit`'s trim is a **signage band** with no danger
semantics, and its `accent` is a tiled panel rather than a stencil. Both
are used deliberately here and neither is a warning.

---

## The gate learned a millimetre, and the harness found a hole in itself

**Two corrections, and neither was found by a person reading the code.**

### 1. The Blender gate grazed in height but not in width

A roller shutter's guide lip has its inner face **on** the opening edge —
that is what a guide is — and this pack authored it at exactly 1.20 m.
Blender's float32 delivered 1.1999999, and `assert_opening_clear`
reported an intrusion **"by 0.000 m"**.

Refusing correct architecture is the fastest way to get a gate switched
off, so the millimetre that has guarded the height test since T01 now
guards the width test too. **A 5 mm intrusion still fails**, and that was
re-run rather than assumed.

Fourth time this lane has learned the same lesson: `skiff_sweep` in
metres, `manipulation_readiness` in newtons, T01's lintel in height, and
now a jamb in width.

### 2. The in-engine check could not see a box

The imported-geometry check tested **vertices**. That caught T01's door
boss, whose corners sit at 3.00 and 3.20 m. **A roller shutter's guide is
one box spanning 0 to 3.2, whose only vertices are at the extremes the
test excludes** — so a guide shifted half a metre into the doorway
registered *nothing*.

**Its own sabotage step is what said so**, three packs after the check was
written:

```
[packview] FAIL: the opening check did not notice a surround shifted
           0.5 m into the doorway, so it cannot notice a real one
```

It measures **per triangle** now, asking the same question `packgates`
asks per object: does this triangle's box overlap the opening's volume
by more than a graze, in width **and** in height? T01 and T02 were
re-verified under it and still pass.

**Three versions of one check; every wrong one was caught by the check
itself.** That is what the sabotage step is for, and it is why it runs on
every pack rather than once.

---

## What I still think is weak

**The pillar's kick band reads as a coloured collar, not as damage.**
`neon_transit`'s `accent` is a clean tiled panel, so a band of it at
grind height says *there is a band here* rather than *this has been hit
a thousand times*. The scuff bars help the silhouette and not the
surface. **This is the clearest case yet of why the pack needs its own
material treatment**: the shape is right and the paint cannot say what
the shape means.

**The chamber is dark.** That is deliberate — after hours, one working
tube, sodium from the wrong side — but it costs legibility on the torn
rail in `BR_chamber`. I would rather show the owner an honest dark
concourse than a lit one that does not exist at this hour.

---

## The exact unfinished integration work

Identical to T01's and T02's, and it will be identical for every pack
until the namespace exists:

1. **Material treatment missing.** Painted in `neon_transit`. A tint does
   not count and none is claimed.
2. **No runtime selection.** Here the hint would at least select the
   right *family* — which is the trap, not the solution.
3. **Not imported.** The `.glb`s are in `assets/models/batch057/`.
4. **No owner review.** `not started` in the completion ledger.

---

## How to regenerate

```
.tools/blender/blender -b --python tools/blender/build_brink.py
tools/content/run_pack_views.sh tp_bomb_rush_cyberfunk
```

The gates are `tools/blender/packgates.py`, the plumbing is
`tools/blender/packkit.py`, the shell and the opening check are
`tools/content/pack_views.gd`, and **where the pieces go is art** and
lives in `tools/content/packlayouts/tp_bomb_rush_cyberfunk.json`.
