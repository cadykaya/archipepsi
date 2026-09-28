# Batch 012 — the three unbuilt themes

**Start with the three `H_probe_*_room.png`.**

`neon_transit`, `gothic_stone` and `temple_ruin` had no material family, so
every theme-specific asset behind them was blocked. All six themes build
now.

Full write-up: [`ART_REVIEW.md`](../../ART_REVIEW.md) § *Batch 012*.

| Image | What it answers |
| --- | --- |
| `H_probe_gothic_stone_room.png` etc. | each theme in engine, in a composed room |
| `H_probe_*_greyscale.png` | does it hold without hue |
| `H_material_*.png` | the five roles at 4×, for judging the paint |

## Nothing here is invented

§9 of the inventory already recorded each theme's identity and each
treatment implements the line written there — glazed tile and grout for
neon, coursed ashlar and iron banding for gothic, cut sandstone and brass
for temple, each with the history that section names.

The probe rooms are the same bench and the same room the approved themes
were judged in, with only the material family swapped. That is also the
runtime model these are built for: **one authored mesh, six theme
materials, selected by Godot.**

## This one is cheap to redirect

A texture rebuilds in seconds. If a theme reads wrong — too clean, too
loud, wrong century — say which and it changes. That is worth knowing
before anything theme-specific gets built on top of it.

Nothing here is approved. `PASS` is yours.
