# Interface family — first slice, in the engine

*Arty*

**PROPOSAL. Imported and measured in Godot 4.5.1. NOT owner-approved.**

Two sheets, both rendered from the committed art by
`tools/content/run_interface_face.sh`. Everything in them is authored
art through the real pipeline — Glyph → `.fnt`/`.png` → Godot's own
importer → `NinePatchRect` and `Label` — at authored pixel size, shown
at 3x with nearest so you are looking at the actual pixels.

| Sheet | What it shows |
| --- | --- |
| `FACE_grid_and_selection.png` | A window, a header well with a total, a 4x3 grid of cells, one of them selected, and a count in every cell. |
| `PANELS_at_four_sizes.png` | The three treatments at 10x10 (authored), 24x16, 60x28 and 118x40. The corners are the same pixels in all four. |

## The three treatments

* **panel** — raised. A window, a header, a button at rest.
* **well** — the same bevel inverted. A recess: a grid cell, a list
  area, a slot, a pressed button.
* **selected** — a well's job with `signal` on its outline. The one
  cell you are about to act on.

They differ only in where the light is. A recess and a relief are the
same object lit from the other side, and giving them separate face
colours would have made them two objects that have to be kept in step.

## What to look at

**The corners.** That is the whole claim of a nine-slice: the 10x10 box
and the 118x40 box in `PANELS_at_four_sizes` have identical corner
pixels. `tools/content/run_nine_slice.sh` asserts it byte for byte
rather than leaving it to the eye.

**The counts.** `12/48` in the header and the quantity in each cell are
the `ui_numerals` bitmap font at 8 px, composed by the engine from
per-glyph advances. `1` is narrower than `0` — deliberately, because
that is the cheapest way to see whether the metrics survived the trip.

**What is missing, on purpose.** There is no item art and no slot
labelling. The equipment-slot vocabulary is Production's to define and
the ruling was explicit: build the shell, the grids, the frames and the
selection treatment now; defer anything that needs a slot's meaning.
The cells are empty because the vocabulary has not arrived, not because
the art is unfinished.

## Two things I wanted a decision on — the first is ruled

**1. Interface chrome has no universal family. — RULED, 2026-09-25.**

> *"Interface chrome may continue using the `dead` family provisionally
> for neutral chrome only. Keep `signal`, `hazard` and `identity`
> reserved for their semantic roles rather than generic decoration."*

So these panels stand as authored. The concern that raised the question
is not dismissed by the ruling and is worth writing down for whoever
meets it next: `dead` also means *unpowered, locked, spent, offline*,
so a locked slot drawn in `dead` on `dead` chrome will not read. When
item and state art arrives — once Production's slot vocabulary lands —
that collision is where it will show up, and the answer will probably
be a value band rather than a new family: chrome in `dead`'s dark half,
item state in its light half.

**2. One pixel of bevel.** On a dark background in
`PANELS_at_four_sizes`, `panel` and `well` take a moment to tell apart —
the bevel is 1 px, though it carries 0.341 L\* of separation. In context,
in `FACE_grid_and_selection`, wells sitting on a panel read as recesses
immediately. So this may be nothing. If you want them distinct in
isolation too, that is a 2 px bevel, a 4 px border, and a larger minimum
cell — say so and I will bring both to compare.
