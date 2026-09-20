# Wall layers and the decal kit

**Arty** · art lane · `claude/archipepsi-art` · 2026-09-10

The concrete_facility wall separated into three layers, and six reusable
decals, all authored in ECMS Glyph and previewed on real room geometry.

**A TRIAL. Nothing here ships.** No approved asset, geometry, collision,
connector, manifest, runtime or review state changed.
`assets/textures/theme/concrete_facility_wall.png` is untouched and remains
the comparison baseline.

| | |
| --- | --- |
| Art head this batch began at | **`1ffd0fe`** |
| Glyph, base | **`727129e`** (`main`) |
| Glyph, used by every trial here | **`62b0bfd`** — `claude/archipepsi-glyph-tooling`, PR #3 (draft) |
| Godot | 4.5.1.stable, Compatibility (`opengl3`) under `xvfb` |
| owner, authorising | **Skyiah** — `act_owner_skyiah` |
| agent artist, drawing | **Arty** — `act_agent_arty` |

Both records (`wall_layers_record.json`, `decal_kit.json`) carry
`glyph_sha`, read from the installation rather than typed beside it.

---

## The three layers

| layer | what | where it lives |
| --- | --- | --- |
| **base wall** | `wall_field.png`, 128 × 128 = **4.00 × 4.00 m**. Repeating field, panel seams, subtle variation. **No skirting band.** | bound to the `wall` role |
| **structural trim** | `wall_skirt.png`, 128 × 32 = **4.00 × 1.00 m**. Placed **once**, at the floor junction. | bound to the `trim` role |
| **decals** | six transparent marks, `decals/` | surface-aligned cards |

### The seam the base course was hiding

Removing the band exposed a real defect in the shipped convention. The panel
course pitch is 1.2 m = 38 texels, and **128 / 38 = 3.37** — so courses do
*not* line up across a vertical repeat. The mismatch had been landing inside
the dark base course, where nobody could see it.

The pitch here is **1.0 m = 32 texels, which divides 128 exactly four
times**. Vertical joints stay at 2.0 m = 64, which divides it twice. The
texel-density convention (32 texels/m) is unchanged. *A tiling texture's
structural pitch has to divide its own tile, or the repeat shows.*

`WALL_FIELD_3x3_SHEET.png` is the evidence, tile boundaries marked in red.

### And the drips had to leave the field

The first pass kept the trial's weep streaks. Tiled 3 × 3 they were the only
thing anyone could see — five identical dark drips per tile, recurring on a
grid, and the eye locks onto them before it reads a single panel.
`passes/pass1_drips_repeat_3x3_4x.png` is what that looks like.

A mark that specific cannot survive repetition, and it does not have to: a
drip beneath a joint is `decal_drip`, placed once where a joint actually
leaks. **The field now carries only what can bear being seen a hundred
times** — the pour, the panel structure, and grit fine enough to read as
surface rather than as an event.

---

## The decal kit

Six marks, transparent RGBA, each authored once at a declared physical size.
**Physical size is authoritative**: a card is built from `metres`, never from
the pixel count, so a texture rework cannot silently resize a mark in the
world.

| # | id | native | metres | surfaces | orientation |
| --- | --- | --- | --- | --- | --- |
| 1 | `decal_drip` | 16 × 48 | 0.50 × 1.50 | wall | **upright only** |
| 2 | `decal_grime` | 32 × 32 | 1.00 × 1.00 | wall, floor, ceiling | any rotation |
| 3 | `decal_scuff` | 24 × 8 | 0.75 × 0.25 | wall, floor | wall: horizontal, 0.3–1.1 m up; floor: any |
| 4 | `decal_stencil` | 24 × 16 | 0.75 × 0.50 | wall | **upright only** |
| 5 | `decal_scorch` | 32 × 32 | 1.00 × 1.00 | wall, floor, ceiling | any rotation |
| 6 | `decal_splatter` | 24 × 24 | 0.75 × 0.75 | wall, floor | any rotation |

A drip stays upright because gravity is structure. A floor scuff rotates
freely because a floor has no up. The stencil stays upright because it is
lettering, and an unreadable mark that used to be readable looks like a
mistake — it is "SUB", set in the house 3 × 5 stencil alphabet from
`paintkit.py` rather than a second alphabet nobody keeps in step.

### Decoration may not impersonate a signal

`tools/content/check_decal_colours.py` is a gate, not a promise: **PASS, 19
colours checked, 0 refused.**

It guards the five **chromatic** reserved families — `signal`, `hazard`,
`identity`, `send`, `glitch` — by chroma and hue, not by raw distance. A
decoration is refused when it is saturated enough to read as a *colour*
rather than as dirt **and** its hue sits inside 30° of a reserved anchor.

`dead` (`#4a4f57`) is **deliberately not guarded**, and the reason is
recorded in the file. The first version of the check compared every texel
against every step of all six ramps in Lab and failed all six decals 62
times — almost all of them on `dead`, whose ramp is neutral grey from
`#26292d` to `#9ba5b6`. Every dark neutral in the game is near some step of
it, including the entire shared `grime` family the shipped textures are
painted with. The rule was forbidding dirt for being dirt-coloured. And
`dead` does not signal by colour arriving somewhere — it signals by being
applied to a known fixture that was lit and now is not. A stain cannot
impersonate that.

The gate proves it **bites**: five negative controls that must fail (the
teal itself, the hazard orange itself, a scorch drifted toward hazard, a
grime patch drifted toward signal, the send yellow) and six that must pass
(the three grime steps, the `dead` slate, the stencil paint, the scuff
substrate). **11 controls, 0 wrong.** A run where the controls pass wrongly
is itself a failure.

---

## Godot, and what it actually showed

Godot 4.5.1 Compatibility. **The projected `Decal` node is a Forward+
feature and does nothing here**, so a decal is a surface-aligned `QuadMesh`:
rotated so its +Z is the receiving surface's normal, lifted **6 mm** off it,
alpha-blended, `DEPTH_DRAW_DISABLED`, `TEXTURE_FILTER_NEAREST`.

One helper, `_card()`, and every placement goes through it — the lift is
applied there so no caller can forget it and no caller can disagree about
it. Placements are written out by hand, one per line, because this
demonstrates the **art**. Production owns the eventual runtime placement,
seed policy and gameplay-effect lifecycle; nothing here proposes one.

Four framings, clean beside dressed, matched light:
`GODOT_CLEAN_VS_DRESSED.png`.

**Observed, not assumed:**

* **No z-fighting or flicker** at any of the four framings, including 1.4 m
  from the drip and at a grazing angle along the north wall.
* **No floating edges.** Every card is inside its receiving surface.
* **The decal and the wall share a pixel grid** — both authored at 32
  texels/m — so a mark reads as part of the surface rather than as a sticker
  from another game.
* **0 unresolved surfaces** on both instances.

### The finding that changed the design

The first preview laid the skirting on as **two quads at the floor
junction**, and it doubled up: `shell_corner_left` **already has a kick rail
there**, as authored geometry wearing the `trim` role. The clean render
shows the one that was already present. So the separated trim layer binds
**where the geometry is**, and cards are left for what has no geometry —
which is decals. That is the correct architecture and it was not obvious
until the room was rendered.

### And a limitation, recorded rather than hidden

`wall_skirt.png` is authored at 4.00 × 1.00 m, but the kick rail it now
wears is much shorter than a metre, and its UVs map the whole texture across
that narrow face. **The skirting reads as tone rather than as structure on
this shell** — its lip, joints and scuffing are compressed out of legibility.
It is correct where it sits and it is not showing what was authored. Either
the skirting is authored to the rail's proportions, or it belongs on a shell
whose trim is a full-height skirting. Not resolved here.

---

## The files

| file | what |
| --- | --- |
| `author_wall_layers.mjs` | authors the field and the skirting; records `glyph_sha` |
| `author_decal_kit.mjs` | authors the six decals and writes `decal_kit.json` |
| `make_sheets.py` | rebuilds all four sheets |
| `wall_field.glyph`, `wall_skirt.glyph`, `decals/*.glyph` | the **editable projects**, eight of them, each reopenable without the scripts |
| `wall_layers_record.json`, `decal_kit.json` | the look records, structure and timings |
| `WALL_LAYERS.png` | field and skirting, apart and together |
| `WALL_FIELD_3x3_SHEET.png` | tiling, both axes, boundaries marked |
| `DECAL_KIT.png` | native / over checker / on the wall, per mark |
| `GODOT_CLEAN_VS_DRESSED.png` | four framings, clean beside dressed |
| `passes/` | the passes that were wrong, kept |

Godot binder: `tools/content/decal_preview.gd`. Colour gate:
`tools/content/check_decal_colours.py`.

**Everything survives the Glyph installation being deleted** — projects,
scripts, textures and renders are all here. Only re-authoring needs Glyph.
