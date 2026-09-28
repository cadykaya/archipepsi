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
| `SHEET_numerals.png` | Every numeral at 8x, with the cyan line marking the advance each one declares. `1`'s line sits a column left of the rest — that is the whole metrics proof, as a picture. |
| `SHEET_text.png` | The text face: 52 characters — capitals, the numerals' own digits unchanged, and the punctuation a label needs. |

## The text face

`ui_text` is what the interface talks with. **Capitals only**: a 6x8
cell gives five rows above the baseline, and lowercase needs an
x-height plus ascenders and descenders inside the same five — at that
size the descender either collides with the next line or is one pixel
and reads as dirt. A mixed-case face wants a taller cell, not a
squeezed one.

**There is no separate heading face, on purpose.** The import
measurement showed the imported font scaling to exactly 2x, so a
heading is this face at 16 px. A second alphabet at double size would
be two things to keep in step for a result the engine already gives,
and they would drift the first time only one was corrected.

The digits are the numerals' own rows, unchanged. A UI that spells `12`
one way in a label and another in a count has two fonts pretending to
be one.

## The three treatments

* **panel** — raised. A window, a header, a button at rest.
* **well** — the same bevel inverted. A recess: a grid cell, a list
  area, a slot, a pressed button.
* **selected** — a well's job with `signal` on its outline. The one
  cell you are about to act on.

They differ only in where the light is. A recess and a relief are the
same object lit from the other side, and giving them separate face
colours would have made them two objects that have to be kept in step.

## Keycaps, symbols and page arrows — `PROMPTS_keycaps_and_symbols`

Added 2026-09-25, the rest of Track A. **Owner-approved 2026-09-26** —
see the end of this section.

* **keycap** — the key a prompt names: `E`, `Q`, `TAB`. Twelve square,
  corners cut, and a two-pixel **front lip** along the bottom, because
  a key is a raised face you press *down* and the lip is its depth. So
  its insets are unequal (left 2, top 2, right 1, bottom 3) and it
  stretches to fit the key's name. Same `dead` chrome as the panels: the
  key is not the thing you operate, the object is, so it gets no
  `signal`.
* **Page arrows** — left, right, up, down. One arrow drawn once; the
  other three are it mirrored and turned, and the gate re-derives them
  from the imported pixels to prove it.
* **circuit, control, exit, blocked** — `exit` and `blocked` share one
  door frame on purpose: they are the same place in two states, and the
  bars across the opening are the whole difference.

Every symbol is **one ink on transparency**. The colour that says
"usable" or "locked" is a STATE, applied by the interface at runtime, so
it is recorded in `assets/ui/icons.json` and not painted in. The bottom
row of the sheet shows that recorded intent: `circuit` powered and
unpowered, `control` operable (`signal`, the only colour an interactable
may be) and not, `exit` open, `blocked` in `dead`.

**OWNER-APPROVED 2026-09-26:** the keycap, the four symbols and the page
arrows. With one adjustment, now made: *"use pure-white source ink for
tintable semantic symbols so ordinary runtime modulation produces the
exact palette colour. Keep the text face's off-white ink for text."*

The symbols first inked in the text face's `#e8eef6`, and `modulate`
landed every tint 3–9% darker per channel than the palette (a `signal`
symbol rendered `#34c9c1` against the palette's `#39d7c8`). They now ink
in `#ffffff`, and `icons.json`'s `_tints` names the exact colour of each
tint:

| tint | colour | source |
| --- | --- | --- |
| chrome ink | `#e8eef6` | the text face's ink, so a neutral symbol matches the label beside it |
| signal | `#39d7c8` | `universal.signal` step 2, as the selected panel's outline |
| dead | `#4a4f57` | `universal.dead` step 1, as the keycap's lip |

**Production multiplies; nothing else is needed.** `run_ui_icons.sh`
renders every symbol with `modulate` set to every tint its states name
and reads back the palette colour: 10 of 10 pairs, exact.

Gates: `run_nine_slice.sh` (now four treatments, four margins each, and
a sabotage that draws the keycap with its lip treated as stretchable)
and `run_ui_icons.sh` (lossless, one ink, a clear 1 px margin, arrows
re-derived).

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

**2. One pixel of bevel. — RULED, 2026-09-25: keep it.**

> *"The distinction is sufficient in composed context; do not enlarge
> the entire minimum-cell/border system for isolated readability."*

Also ruled: the current panel/grid language is accepted as **the
structural interface language** — which is not a statement that the
visual identity is finished. The original note is kept below.

On a dark background in
`PANELS_at_four_sizes`, `panel` and `well` take a moment to tell apart —
the bevel is 1 px, though it carries 0.341 L\* of separation. In context,
in `FACE_grid_and_selection`, wells sitting on a panel read as recesses
immediately. So this may be nothing. If you want them distinct in
isolation too, that is a 2 px bevel, a 4 px border, and a larger minimum
cell — say so and I will bring both to compare.
