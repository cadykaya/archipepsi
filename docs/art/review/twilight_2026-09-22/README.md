# T05 — Kingdom Hearts 2, Twilight Town service alley: the pack that was an experiment

**Arty**

Batch 059. 2026-09-22. Branch `claude/archipepsi-art`, PR #5.

**PROPOSAL. Not imported, not runtime-bound, not owner-approved.**

---

## Read this first: the experiment returned a negative result

This pack shares `temple_ruin` with T01 **on purpose**.

The owner's completion criteria say reuse is encouraged and that **a
useful visual variant is not a duplicate merely because its construction
is shared.** Two packs in one family, in one shell, under the same four
cameras, is the **test** of that claim rather than an accident of it.

**The test says the claim cannot be met today, and the reason is exactly
the namespace.**

Open `TW_hoarding.png`. All four thicknesses are there and legible —
wall, brick infill, boards, batten, torn bill. The silhouette does its
job. The piers are corbelled where T01's are rooted. The gate is soft
goods where T01's is bossed stone.

Now open `FT_approach.png` from
`docs/art/review/forest_temple_2026-09-22/` and `TW_approach.png` side by
side.

> **The geometry is saying "boarded-up shopfront". The pixels are saying
> "overgrown temple". The pixels win.**

`temple_ruin`'s `accent` is mossy stone, so the awning canvas reads as
foliage and the timber boards read as green stone panels.

**This is the strongest single argument in the whole run for
`COVERAGE.md` §3's pack namespace, and it is a picture rather than an
assertion.** It is also why these frames are not lit or posed to hide it:
the honest frame is the useful one. Two packs sharing a *family* is fine.
Two packs sharing the same *pixels* is not a variant — it is a recolour
that forgot to recolour.

---

## The subtheme: **Twilight Town, the service alley behind Tram Common**

Kingdom Hearts 2 has a dozen worlds and three of them are whole
architectures on their own. Blending Twilight Town, Hollow Bastion and
The World That Never Was is the average the owner ruled out. The packet's
concept, "Twilight Service District", names this choice already.

Kingdom Hearts 2 has **no entry** in `THEME_BY_GAME_HINT` — one of the 75
of 81 without one. `temple_ruin` is Art's choice by material culture, not
a hint being followed.

---

## The six pieces

| asset | tris | what makes it this pack's |
|---|---|---|
| `tp_tw_alley_buttress` | 84 | a brick pier that carries a **wire**, not a roof. Corbelled, with a catenary bracket and a stay triangulating back into it. |
| `tp_tw_hoarding` | 108 | the wall is **covered, in four thicknesses**. One flat board is a board; four is a wall somebody keeps having to deal with. |
| `tp_tw_awning_gate` | 84 | **soft goods on a hard frame** — the one thing no other pack and no house family has. |
| `tp_tw_tram_track` | 84 | floor dressing **laid and then neglected**. Displaced, never continuous. |
| `tp_tw_street_lantern` | 96 | one pane of four simply **absent**. A dark pane is a dark pane; a hole is a lantern somebody broke. |
| `tp_tw_tram_call` | 60 | Batch 043's wall-switch contract as a municipal **tram call**: a pull in a slot. |

---

## Two gates fired, and both were right

### The valance is T04's coaming at the other end of the same hole

A real shop awning's valance hangs **below** the door head. The first cut
put it at `DOOR_H + 0.05`, lower edge at 3.14 m — six centimetres inside
the opening — and the gate refused it by 2.550 m.

That is what a valance *does*. It is still **headroom**, and headroom in
Production's doorway is Production's. The canopy ships **rolled**, which
is also what a shop does out of hours.

T04 lost a coaming at the floor for the same reason. **The two refusals
are the same rule seen from both ends of the same opening**, and between
them they are a fair description of what a theme pack may not touch.

### The setts had to be bedded, not scattered

`assert_parts_touch` called two of the four floating at 3–4 cm. It was
right in a way that is also the art note: **a sett that is not touching
the rail is a stone lying in a street**, and the whole read of that piece
is that the rail was *bedded* in them.

---

## The tram track claims nothing about the ground

It is a **displaced section** and deliberately not a continuous run.

A continuous rail across a floor is infrastructure a player reads as
walkable, and floor is Production's. A lifted sett and a rail end nobody
relaid says the same thing about the place and claims nothing about the
ground. Same reasoning as T04's missing coaming, applied before the gate
had to say it.

---

## What I still think is weak, beyond the finding

**The catenary never appears.** Both piers carry a bracket and an eye,
and there is no cable between them, because a cable is a moving art
problem and this batch is static dressing. Two brackets reaching at each
other across an empty room is a promise the pack does not keep. Either a
seventh asset (a slack span) or the brackets should point somewhere less
obviously paired.

**The lantern's missing pane does not read at approach distance.** It
works in `TW_chamber`; at 9 m the lantern is a warm blob. That is honest
for a 0.32 m fitting at 32 texels/m and I would not enlarge it to fix a
review frame.

---

## The exact unfinished integration work

1. **Material treatment missing — and here that is THE finding**, not
   boilerplate. See the top of this file.
2. **No runtime selection, and no hint to misuse.**
3. **Not imported.** `assets/models/batch059/`.
4. **No owner review.**
5. **A question for the owner**, which only this pack can ask: if two
   packs must share a house family until the namespace lands, should
   later packs avoid families already used — or is a recolour-shaped
   pack acceptable as an interim? **Art's answer is that it is not, and
   that is why this one was built to prove it.**

---

## How to regenerate

```
.tools/blender/blender -b --python tools/blender/build_twilight.py
tools/content/run_pack_views.sh tp_kingdom_hearts_2
```
