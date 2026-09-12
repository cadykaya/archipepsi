# Wall layers, a decal kit, and one Glyph improvement

**Arty** · art lane · `claude/archipepsi-art` · 2026-09-10

An authoring and preview batch. **No approved asset, geometry, collision,
connector, manifest, runtime or review state changed.** Nothing here is
promoted, and no Theme Pack binder was implemented.

Review package: `docs/art/review/glyph_layers_2026-09-10/`, README inside.

---

## 1 · Revisions

| | |
| --- | --- |
| Art head this batch began at | **`1ffd0fe`** |
| Glyph, base | **`727129e`** (`main`) |
| Glyph, used by every delivered trial | **`62b0bfd`** — `claude/archipepsi-glyph-tooling`, **PR #3** (draft) |
| Godot | 4.5.1.stable, Compatibility (`opengl3`) |

`glyph_sha` is in both trial records, read from the installation rather than
typed beside it.

---

## 2 · The wall, separated

| layer | what | bound to |
| --- | --- | --- |
| base wall | `wall_field.png` 128 × 128 = **4.00 × 4.00 m**, repeating, no skirting band | the `wall` role |
| structural trim | `wall_skirt.png` 128 × 32 = **4.00 × 1.00 m**, once, at the floor junction | the `trim` role |
| decals | six transparent marks | surface-aligned cards |

**Two findings, both from removing the band rather than from reasoning about
it.**

**The base course had been hiding a seam.** The shipped panel course pitch is
1.2 m = 38 texels and **128 / 38 = 3.37**, so courses do not line up across a
vertical repeat — the mismatch was landing inside the dark band. The pitch
here is **1.0 m = 32 texels, dividing 128 exactly four times**; vertical
joints stay at 2.0 m = 64. Texel density is unchanged at 32/m. A tiling
texture's structural pitch has to divide its own tile.

**The drips had to leave the field.** The first pass kept the trial's weep
streaks and one tile looked fine. Tiled 3 × 3 they were the only thing
visible: five identical drips per tile on a grid, and the eye reaches them
before it reads a panel. `passes/pass1_drips_repeat_3x3_4x.png` is the
evidence. A mark that specific cannot survive repetition — so it became
`decal_drip`, placed once. **The field now carries only what can bear being
seen a hundred times.**

Eleven palette entries where the trial had eleven for one texture; nine for
the field and eight for the skirting, and the added ones earn it — two steps
out from the field in each direction instead of one, so a patch has a middle
and an edge rather than a flat plateau. That was the trial's own conclusion:
the shipped painter builds its surface from many low-strength continuous
mixes, indexed colour cannot do continuous, but it can afford a second step.

---

## 3 · The decal kit

Six marks, transparent RGBA, each at a declared physical size, with the
surfaces it suits and the orientations it may take. **Physical size is
authoritative** — a card is built from `metres`, never from the pixel count.

| id | metres | surfaces | orientation |
| --- | --- | --- | --- |
| `decal_drip` | 0.50 × 1.50 | wall | **upright only** |
| `decal_grime` | 1.00 × 1.00 | wall, floor, ceiling | any rotation |
| `decal_scuff` | 0.75 × 0.25 | wall, floor | wall: horizontal, 0.3–1.1 m; floor: any |
| `decal_stencil` | 0.75 × 0.50 | wall | **upright only** |
| `decal_scorch` | 1.00 × 1.00 | wall, floor, ceiling | any rotation |
| `decal_splatter` | 0.75 × 0.75 | wall, floor | any rotation |

A drip stays upright because gravity is structure; a floor scuff rotates
because a floor has no up. The stencil is "SUB" in the house 3 × 5 alphabet
from `paintkit.py` — established vocabulary, not a second alphabet.

**Two marks were redrawn after looking.** The scuff first read as a row of
disconnected blocks because it dropped pixels at a flat rate along every
stroke; a scrape is continuous where the thing bore down and breaks up only
as it lifts, and all four strokes now lift the same way because one object
made all of them. The splatter's droplets came out as **plus signs** — a
radius-1 disc on an integer grid is a cross — and are now 2 × 2 blocks near
in and single pixels far out.

### The colour gate, and the rule I had to fix

`tools/content/check_decal_colours.py`: **PASS, 19 colours, 0 refused.**

Its first version compared every texel against every step of all six
reserved ramps in CIE L\*a\*b\* and **failed all six decals, 62 times**.
Almost every hit was `dead` (`#4a4f57`), whose ramp is neutral grey from
`#26292d` to `#9ba5b6`. Every dark neutral in the game is near some step of
it — including the entire shared `grime` family the **shipped** textures are
painted with. The rule was forbidding dirt for being dirt-coloured.

Lowering the threshold would have been weakening a test to pass it, so the
**rule** changed instead. The gate now guards the five *chromatic* families
by chroma and hue: a decoration is refused when it is saturated enough to
read as a colour rather than as dirt **and** its hue sits within 30° of a
reserved anchor. `dead` is excluded deliberately, with the reason in the
file — it signals by being applied to a known fixture that was lit and now
is not, and a stain cannot impersonate that.

And it **bites**: eleven negative controls, five that must fail and six that
must pass, **0 wrong**. A run in which the controls pass wrongly is itself a
failure.

---

## 4 · Godot, actually observed

**The projected `Decal` node is a Forward+ feature and does nothing in
Compatibility.** So a decal is a surface-aligned `QuadMesh`: +Z along the
receiving normal, lifted 6 mm, alpha-blended, `DEPTH_DRAW_DISABLED`,
`TEXTURE_FILTER_NEAREST`. One helper, `_card()`; the lift lives there so no
caller can forget it. Placements are explicit, one per line.

Four framings — wide, close (1.4 m), oblique, and down onto the floor —
clean beside dressed, matched light.

* **No z-fighting or flicker** at any framing.
* **No floating edges**; every card inside its receiving surface.
* **The decal and the wall share a pixel grid**, both at 32 texels/m, so a
  mark reads as part of the surface.
* **0 unresolved surfaces** on both instances; 6 cards.

**The finding that changed the design.** The first preview laid the skirting
on as two quads at the floor junction and it doubled up:
`shell_corner_left` **already has a kick rail there**, as authored geometry
wearing the `trim` role, and the clean render shows it. So the separated
trim layer binds **where the geometry is**, and cards are left for what has
no geometry — decals. That is the right architecture and it was not obvious
until the room was rendered.

**A limitation, recorded rather than hidden.** `wall_skirt.png` is authored
at 4.00 × 1.00 m, but the rail it now wears is far shorter than a metre and
its UVs map the whole texture across that narrow face. **The skirting reads
as tone rather than as structure on this shell** — lip, joints and scuffing
compressed out of legibility. Correct where it sits, and not showing what
was authored. Either it is authored to the rail's proportions or it belongs
on a shell whose trim is a full skirting. Not resolved here.

---

## 5 · The Glyph improvement

**`easel.study({ from, tile, over, into })`** — `62b0bfd`, PR #3 (draft),
`tools/easel.mjs` only.

**The artist problem, twice over.** A transparent decal on a transparent
ground is *invisible* — opening it shows nothing, and the temptation is then
to write a `visual_assessment` of an image nobody could see, which is the
collapse `look.mjs` exists to prevent. And a tiling texture cannot be judged
from one tile; §2's drip finding came from a 3 × 3 sheet that one tile could
not have told me.

**What it is not.** `verifyLook` asserts a render's file is exactly the
native size × an integer scale, and that is most of what `render_created` is
worth. A 3 × 3 sheet is nine times that. So a study carries its own record:
re-verifies its source view, names that digest as `derived_from`, states
`is_a_render: false`, hashes itself, and **refuses** a source that does not
verify.

**Validation.** `tools/study-demo.mjs` end to end, driven by
`packages/protocol/test/easel.test.ts`. The test checks tiling multiplies
exactly in both axes, that a ground is *actually laid* — the checker study
has no transparent pixel left and the bare one still does, so the feature
cannot pass by writing the source back out under a new name — that digests
differ, and that both refusal paths fire.

**Suite: 337 passed, 1 failed.** The failure is the pre-existing
`GLA-PRF-001` (108.08 ms against 100 ms), untouched. 336/337 before this
branch, 337/338 after: one added test, passing. **Nothing weakened, no
threshold moved.**

No protocol, core, store or io change. No third-party dependency —
compositing is source-over on the packed RGBA the renderer and PNG codec
already share. **No normative authority file touched, and no conflict with
the frozen authority at `0cf872d` found**: a study is a tool-level
convenience, not a protocol surface. Attribution, permissions, transaction
history and the protection contracts are untouched. Left on the branch for
the Glyph maintainer; not merged.

---

## 6 · Preservation

| check | result |
| --- | --- |
| twelve shipped shells byte-identical | **yes** |
| `assets/` unchanged, `concrete_facility_wall.png` included | **yes** — it remains the comparison baseline |
| geometry, collision, connectors | **untouched** — Blender never ran |
| manifest / schema fields | **unchanged** |
| runtime | **unchanged** — nothing under `godot/scripts/` written |
| review states | **unchanged** — twelve `pass`, three projectiles `pending` |
| assets promoted | **none** |
| Theme Pack binder | **not implemented** |
| `tools/check_art_current.sh` | **PASS** |
| `tools/blender/check_docs_metrics.py` | **PASS** |
| `check_decal_colours.py` | **PASS**, 11 controls 0 wrong |

Editable Glyph projects, reproducible scripts, textures and previews all
live under `docs/art/review/glyph_layers_2026-09-10/` and **survive deletion
of the Glyph installation**. Only re-authoring needs Glyph back.
