# Batch 009 — the six remaining affordances

**Start with `A_affordance_family.png`, then its `_silhouette`.**

§5 of the inventory lists seven affordances; the grapple anchors were
built and passed at Style Lock, and these are the other six.

Full write-up: [`ART_REVIEW.md`](../../ART_REVIEW.md) § *Batch 009*.

| Image | What it answers |
| --- | --- |
| `A_affordance_family.png` · `_grey` · `_silhouette` | one family, seven promises |
| `A_wind_column.png` | the updraft as the engine stacks it — three rings and a perch |
| `A_rail_beam.png` · `A_bounce_pad.png` · `A_breakwall_panel.png` | each on its own |
| `A_movplat_water.png` | the two that are read from above |

## The three things worth your eye

1. **They all wear `signal`**, because §5 says *the seven look the same
   everywhere or they teach nothing* — and the approved grapple anchors
   already wear it. What separates them is form: the silhouette sheet is
   the test.
2. **The engine currently disagrees.** `affordance_features.gd` tints these
   six different ways; four of those colours are not in the palette, two
   vary per theme, and the rail's violet sits beside `glitch`, which means
   *means nothing mechanically*. I have not touched that file — the sheets
   show the family rule, and the conflict is interface requirement 15 for
   you and engineering to settle.
3. **Two channels stay the engine's**: the breakable panel's cracks (it
   draws and shrinks them with the panel's health) and the number of wind
   rings (it stacks three).

Nothing here is approved. `PASS` is yours.
