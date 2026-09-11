# Batch 043 / A — the complete status graphic kit

**Arty**

Thirteen statuses, eight compounds, four family frames, a compound frame, a
duration rule, a player tick and the §33.8 hint. Authored in ECMS Glyph,
exported as individual transparent PNGs, and photographed on real room
geometry under the game's own light.

**PROPOSAL. Nothing here is approved, nothing is bound to runtime, and no
status mechanic is implemented by any of it.** The preview's states are a
hand-written table; there is no roll, no countdown, no §15.4 pipeline and no
compound rule anywhere in this directory.

Design read at `a20bf55`: Design 6 §15.2 and §33.10, Design 5 §15.1–15.8 and
§33.7–33.9, Design 1 §19.5's sibling rule about hue.

---

## Native sizes, and why they are what they are

| asset | native | what it is |
| --- | --- | --- |
| glyph | **16 × 16** | the reduced treatment of §33.10 rule 2 — what a distant or crowded target gets, alone, with no ring and no sentence |
| marker | **32 × 32** | frame + glyph, seated at (8, 8) |
| tick | **8 × 8** | the player-applied mark, at (21, 21) |

32 is not a taste decision. The frame must leave a clear radius of 12 px; a
16 × 16 glyph reaches 11.3 px at its corners. At a 24 px marker the frame
stroke cut the corners off every glyph in the kit, so the marker went to 32
and the glyph stayed where it was.

`SHEET_native_size.png` is the sheet that matters: everything at 1:1, on
bright concrete, dark derelict and a mid grey chosen because it flatters
nothing.

## What is drawn by hand and what is derived

`status_bodies.mjs` holds 21 hand-drawn 16 × 16 silhouettes. That is where
the judgement is, and it is the file to edit.

Everything else follows: the dark outline is a one-pixel eight-way dilation
of the body, so every glyph carries exactly the same weight and a hole left
inside a body — `silenced`'s slash, `brittle`'s crack — closes into a dark
hairline by itself. `status_frames.mjs` builds the five frames
procedurally, because a frame has to be identical under every glyph it wraps
and hand-placing four of them four times would only introduce drift.

## The six pairs

`SHEET_pairs.png`, at 6× and at 1:1. A pair sheet is the only fair test: two
glyphs judged one at a time always look distinct, and the confusion appears
only when they are adjacent.

| pair | what separates them |
| --- | --- |
| `anchored` / `rooted` | one vertical spike with a head and a barb, against a headless stem with three roots splaying below a ground line. Anchored cannot be moved; rooted can still be dragged, and the splay is why |
| `lightened` / `updraft` | the same slab. Lightened floats over emptiness and is bottom-heavy; updraft pins it to the top edge and fills everything under it with rising flow |
| `blinded` / `confused` | a shut, solid lens with lashes, against an X of barbed arrows |
| `conductive` / `grounded` | a bolt travelling pad to pad, against a symmetric ladder descending into earth |
| `brittle` / `shatterpoint` | a plate with one wandering fault line, against a plate with a punched void |
| `phased` / `suspended` | a box a bar runs clean through, against a block held clear inside four corner brackets, touching none of them |

## Duration, the tick, and the hint

`SHEET_components.png`.

**Duration is the frame's own outer edge.** §33.7 says the marker depletes
around its edge, so the edge is the track — there is no second ring to align,
tint or keep in step. `status_kit.json` carries each frame's track as an
ordered pixel list, clockwise from 12 o'clock, 76 to 112 pixels long
depending on the frame. A runtime paints the first `remaining` fraction lit
and the rest at the `spent` value. The smallest visible step is about 1% of
duration.

`dim` and `spent` are two greys, not one, and the difference is deliberate: a
dimmed compound hint has to stay READABLE as a glyph, because it is telling
the player what to apply next. A spent arc only has to hold the frame's
silhouette open. One shared grey made the depletion unreadable at a glance,
which is the one thing it exists for.

**The hint** is §33.8 read literally: the missing component's glyph, dimmed,
beside the compound's. Both directions are exported for all eight compounds —
sixteen files — because a player can arrive at a pair from either side.

## Colour

Neutral: one ink, one face, one dim, one spent. The only reserved colour in
the kit is `send` on the player tick, and it is **proposed** rather than
assumed. The reasoning, and the four other questions this batch needs an
owner for, are in `DECISIONS_FOR_OWNER.md`.

`SHEET_markers_grayscale.png` is therefore nearly identical to
`SHEET_markers.png` — which is the point, not an oversight.

## In the room

`room/` — `shell_corner_left` under the shipped light model (ambient plus
`OmniLight3D` fixtures; **no directional light, because a built Zone has
none**), on three backgrounds.

| shot | what it shows |
| --- | --- |
| `STATUS_individual_*` | four families on four targets, one at 38% remaining with the player tick, and the focused target's §15.2 sentence printed verbatim |
| `STATUS_compound_*` | left, a crate carrying `lightened` with the §33.8 hint; right, the same pair resolved into `updraft` |
| `STATUS_crowd_*` | sixteen marked targets. The nearest twelve render fully, four reduce to a single glyph (§33.10 rule 2), and the crosshair and the persistent tier stay clear |
| `SEQ_compound_forming.gif` | twelve rendered frames of one change. Each frame also stands alone as a still |
| `*_grey.png` | the same frames in grayscale |

The HUD in those frames is **mocked**. Those rectangles stand in for Health,
Barrier, the weapon and feed, five abilities and Mobility, and they exist so
the proximate tier can be judged against something it is not allowed to
cover. No HUD is being designed here.

Statuses are shown only on `OBJECT` targets, because that is the only one of
§15.1's five kinds with an approved candidate in the catalogue.
`BATCH_043_INVENTORY.md` says why.

## What a still cannot show

These are static frames and a twelve-frame loop. **They do not prove combat
visibility, they do not prove the markers are flicker-free in motion, and
they do not prove readability while the player is turning.** Those need play.

## Files

| | |
| --- | --- |
| `status_bodies.mjs` | the 21 hand-drawn silhouettes — edit here |
| `status_frames.mjs` | the five frames and the depletion track |
| `author_status_kit.mjs` | authors every Glyph project and exports every PNG |
| `make_sheets.py` | regenerates every `SHEET_*.png` from `png/` |
| `glyph/` | 70 editable Glyph projects |
| `png/`, `png8x/` | individual transparent exports, and 8× with a checker study |
| `status_kit.json` | every id, family, sentence, target list, duration, native size and depletion track |
| `atlas_markers.png` + `.json` | a supplement; the individual PNGs are the assets |

Rebuild:

```
GLYPH_ROOT=/path/to/ecms-glyph node author_status_kit.mjs
python3 make_sheets.py
tools/content/run_status_preview.sh
```
