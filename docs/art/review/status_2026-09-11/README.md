# Batch 043 / A — the complete status graphic kit

**Arty**

**Twenty-four** statuses, eight compounds, four family frames, a compound
frame, a duration rule, a player tick and the §33.8 hint. Authored in ECMS
Glyph, exported as individual transparent PNGs, and photographed on real
room geometry under the game's own light.

**PROPOSAL. Nothing here is approved, nothing is bound to runtime, and no
status mechanic is implemented by any of it.** The preview's states are a
hand-written table; there is no roll, no countdown, no §15.4 pipeline and no
compound rule anywhere in this directory.

Design read at `a20bf55`: Design 6 §15.2 and §33.10, Design 5 §15.1–15.8 and
§33.7–33.9, Design 1 §19.5's sibling rule about hue.

---

## Batch 052 — eleven more, and why they were missing

**The kit drew the destination and the runtime runs the origin.**

Batch 043 drew Design 6 §15.2's thirteen. `Constants.ECHO_STATUS_KINDS` is
the closed vocabulary `StatusEffects.apply` refuses anything outside, and it
holds **twenty-four** — §15.2's thirteen plus ECHOES §8's eleven. Of the
thirteen the runtime actually IMPLEMENTS, this kit had drawn exactly **two**:
`lightened` and `burning`. Eleven conditions the game can put on a target
today had nothing on screen to say so, and eleven of the kit's markers were
for kinds `apply()` refuses outright with *NO STATUS BEFORE ITS EFFECT*.

Batch 052 draws the other eleven — `slowed`, `frozen`, `shocked`,
`poisoned`, `marked`, `stunned`, `vulnerable`, `empowered`, `low_profile`,
`haste`, `regenerating` — so the kit now covers the whole closed vocabulary.
`tools/content/run_status_readiness.sh` is the check that says so, and it
reads Production's constants and `apply()`'s own guards rather than
restating either.

Three fields on those eleven are **not** quoted from a design, because
ECHOES §8 names them and stops: their family (argued per glyph from what the
runtime measurably does), their targets (the runtime's own supported list,
translated), and their sentence. Each carries a `*_source` field saying so.

Two drawings were redrawn during the batch because a new build-time gate
measured them against the kit they were joining, and `SHEET_markers.png`
stopped silently dropping a third of the kit. Both are described below.

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

`status_bodies.mjs` holds 32 hand-drawn 16 × 16 silhouettes. That is where
the judgement is, and it is the file to edit.

Everything else follows: the dark outline is a one-pixel eight-way dilation
of the body, so every glyph carries exactly the same weight and a hole left
inside a body — `silenced`'s slash, `brittle`'s crack — closes into a dark
hairline by itself. `status_frames.mjs` builds the five frames
procedurally, because a frame has to be identical under every glyph it wraps
and hand-placing four of them four times would only introduce drift.

## The reads-apart gate, and the two glyphs it redrew

Until Batch 052 the only thing checked about a hand-drawn body was that it
was 16 rows of 16 characters. A kit whose entire job is to tell a player
*which* of twenty-four conditions is on a target had no rule that any two of
them looked different — and it was about to take eleven new members.

For every pair, over every offset within two pixels and the horizontal
mirror:

```
apart = 1 - max sqrt( IoU(body_a, body_b) * IoU(outline_a, outline_b) )
```

Two choices in that are worth stating.

**The vertical mirror is deliberately not searched.** Up and down carry
meaning here: `burning` rises and `poisoned` falls, `conductive` hangs its
bolt below a rail and `shocked` stands one on top of a mass. An upside-down
match is a real distinction, not a near-miss.

**The outline term is there because area alone is a bad judge.** Measured on
filled masks the closest pair in the kit came out as `burning` and
`regenerating` — a fat flame and a fat cross, which nobody would confuse,
scored together for nothing but both being large. A 16 px glyph reads by its
silhouette, and the geometric mean means a pair has to be close in *both* to
be called close.

**The numbers are measured, not picked.** The kit's own closest pair is
`brittle` / `shatterpoint` at **0.304** — two MATERIAL fractures, and Batch
043's comment on `brittle` already argues that one deliberately. `FLOOR` sits
under it at **0.25**: low enough to refuse no drawing in the kit, high enough
that a near-duplicate cannot get in. A gate that refuses correct art is a
gate that gets switched off, and then it is worse than nothing.

`MUST_READ_APART` is a second, higher bar at **0.45**, and it is not the
close pairs — it is the thirteen whose *meanings* are adjacent enough that a
player could take one for the other (`vulnerable` / `exposed`, `marked` /
`low_profile`, `slowed` / `slippery`, the two damage-over-time statuses, the
two current statuses, and so on). Their measured minimum is 0.507. Opposites
are not on the list: nobody mistakes healing for being on fire.

### It bit its own author, twice, in the batch that added it

**`shocked` was a block with a jagged void torn through it.** A handsome
drawing, and measurably `brittle`: **0.295** apart, the closest pair in the
whole kit, under the floor. Both would have read as *a block with a fault in
it* on a 32 px marker, and both are MATERIAL — so the family frame could not
have separated them either. The discharge moved outside the body, and the
pair went to 0.51.

**`low_profile` was a deep open-bottomed shelter.** This one is the more
interesting case, because the gate never refused it: 0.364 from its nearest
neighbour, comfortably past the floor. But it was a tall rectangle with
interior structure, and so are `brittle`, `phased`, `shatterpoint` and
`updraft` — it sat in the kit's twenty closest pairs **five times over**. No
single pair was wrong; the shape was simply crowded. It is now a slab over a
small body, and its nearest neighbour is 0.608 away.

### And the sheet that was quietly lying

`make_sheets.py` drew the marker sheet on a hardcoded `cols = 7, rows = 3` —
exactly the 21 markers the kit had. The eleven added here pasted straight
past the band, and a sheet titled *the thirteen statuses and eight
compounds* silently showed two thirds of a kit of thirty-two. The grid is
derived from the kit now, and so is the title.

---

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

**Neutral throughout, and no reserved colour is used at all.**

An earlier revision made the player-applied tick `send` #ffd45c and argued
that `send` means "this one came from you". **That misreads the palette.**
`send` means one specific thing — *this leaves for the multiworld* — and it
belongs to Check transmission. Everything the player causes is not a send,
and a gold tick on a `burning` crate would have taught a player that setting
a crate on fire is an Archipelago event.

The tick is now the same near-white as the rest of the kit, and it moved
outside the frame's outer edge so the two ink outlines draw a gap between
them. Its job was always carried by shape and position — a check mark proud
of the lower right, present or absent — and the colour was never doing the
work.

The four families stay neutral by owner decision, and the compound
double-ring is kept: it identifies a compound, not a fifth mechanical family.
`DECISIONS_FOR_OWNER.md` records what was decided and what is still open.

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

## Every example is legal, and the preview enforces it

An earlier revision put `confused` on an oil drum and `rooted` on a utility
box. **Both are actor-only**, and `status_kit.json` said so on the line
above — the metadata was right and the picture was wrong, which is the worse
way round, because the picture is what gets looked at.

The preview now loads the kit's own `targets` lists at startup and every
marker goes through a gate that **fails the run** rather than render an
illegal pair:

```
[status] 114 status/target pairs checked against §15.2, 30 of them
         against apply() as well
```

§15.2 makes exactly **twelve** of the kit legal on an `OBJECT` — which is
also §33.10 rule 2's full-render count — plus `arc_path`, which is
surface-only, and the rest actor-only. Batch 052's eleven added none to the
object column: **not one of them is implemented on an object.**

### And a second gate, which §15.2 cannot answer

`STATUS_runtime_*.png` is captioned *what the runtime can raise today*, and
a caption like that has to be checked against the runtime, not the design.
Every marker in that shot goes through a second assertion, against
`Constants.ECHO_STATUS_SUPPORTED_TARGETS` — the same table `apply()` refuses
on — using the vocabulary map the kit now declares (§15.2 says *what* a
target is, `StatusEffects.side` says *whose* it is; they are not the same
words and the translation is data, not a reader's assumption).

It fired twice on its first run, and it was right both times: `haste` and
`low_profile` had been put on enemy stand-ins, and both are implemented on
`self` **alone**.

### The finding that came out of that

**Three of the thirteen implemented statuses have nowhere to go.** `haste`,
`low_profile` and `regenerating` are `self`-only, and this kit's entire
presentation model is *a marker anchored to a target*. The player is the
camera. There is no legal world position for them, so `STATUS_runtime_*`
places **ten of thirteen** and says so in its caption rather than quietly
showing a full set.

They are not missing art — they are drawn, and they are on
`SHEET_markers.png` and `SHEET_native_size.png` like everything else. What
they have no answer for is *where*, and that answer is the persistent HUD
tier, which this preview mocks with rectangles and deliberately does not
design. It is in `DECISIONS_FOR_OWNER.md`.

**Actor-only statuses ride a labelled stand-in.** Batch 030's ten enemy roles
are still unspawnable behind req 31, so there is no approved actor to put
them on. The stand-in is a flat, unshaded, untextured capsule with
`PREVIEW STAND-IN / not an enemy asset` over its head, drawn in front of its
own body so it cannot be hidden behind. **It is a placement, not a proposal:
no silhouette decision is being made and nothing here is a sketch of an
enemy.** The alternative was putting actor-only statuses on crates, which is
what the first pass did.

`arc_path` is shown on a floor face — the one surface-only member of the kit,
on the one kind it is legal for.

## What a still cannot show

These are static frames and a twelve-frame loop. **They do not prove combat
visibility, they do not prove the markers are flicker-free in motion, and
they do not prove readability while the player is turning.** Those need play.

## Files

| | |
| --- | --- |
| `status_bodies.mjs` | the 32 hand-drawn silhouettes — edit here |
| `status_frames.mjs` | the five frames and the depletion track |
| `author_status_kit.mjs` | authors every Glyph project and exports every PNG |
| `make_sheets.py` | regenerates every `SHEET_*.png` from `png/` |
| `glyph/` | the editable Glyph projects, one per asset |
| `png/`, `png8x/` | individual transparent exports, and 8× with a checker study |
| `status_kit.json` | every id, family, sentence, target list, duration, native size and depletion track — plus, since Batch 052, each status's `runtime_targets`, the two target vocabularies and the map between them, and the `reads_apart` margins |
| `atlas_markers.png` + `.json` | a supplement; the individual PNGs are the assets |

Rebuild:

```
GLYPH_ROOT=/path/to/ecms-glyph node author_status_kit.mjs
python3 make_sheets.py
tools/content/run_status_preview.sh
tools/content/run_status_readiness.sh
```
