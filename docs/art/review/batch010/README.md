# Batch 010 — the dressing the generator actually places

**The finding matters more than the three props.**

`ASSET_INVENTORY.md` §8 listed twenty-two universal props and **nothing
places any of them**. The only thing in the generator that puts dressing in
a Zone is `chamber_builders._theme_props`, and it places one prop per
*theme* — none of which was in the inventory at all. Both records are
corrected; these are the three whose theme material family exists.

Full write-up: [`ART_REVIEW.md`](../../ART_REVIEW.md) § *Batch 010*.

| Image | What it answers |
| --- | --- |
| `D_drum_stack.png` · `_grey` | **start here** — does the drum tile when stacked |
| `D_dressing_family.png` · `_silhouette` | three of six |
| `D_wall_plate.png` · `D_valve_wheel.png` | each on its own |

## Three things

1. **The drum is exactly 0.95 m and its bung is flush**, because the engine
   stacks it at 0.95 intervals four times in ten. A 20 mm boss would make
   every stacked pair interpenetrate by exactly that.
2. **void_glitch's prop is deliberately untouched.** It is a text label
   reading `prop_missing.mdl`; authoring a mesh for it would destroy the
   joke, which is that theme's identity.
3. **The warning plate is a lot of orange.** It is the only dressing a
   facility Zone gets and it is what `hazard_mat` already does — a warning
   plate is a warning — but it is the largest area of orange in the
   facility, so it is worth checking against the Batch 004 rule.

Nothing here is approved. `PASS` is yours.
