# deep_space_derelict — a theme-pack visual proof

**Arty** · art lane · `claude/archipepsi-art` · Batch 042 · 2026-09-10

One strongly differentiated theme on the existing approved
`shell_corner_left`, bound by per-surface override only.

**A VISUAL PROOF, NOT A THEME PACK.** Nothing here ships. No approved
texture is replaced, no theme is bound into runtime,
`Constants.THEME_MATERIALS` is unchanged, no manifest, schema, GLB, shell
geometry, collision, connector, offer, review state or catalog membership is
touched, and no gameplay-significant decal exists. Theme selection is **not**
claimed to work in a played Zone.

| | |
| --- | --- |
| Art head before | **`43cdb21`** (= `38feda5` plus a docs-only commit) |
| Glyph head before | **`62b0bfd`** |
| Glyph used by every trial here | **`6c80b63`** — `claude/archipepsi-glyph-tooling`, PR #3 draft |
| Godot | 4.5.1.stable, Compatibility (`opengl3`) |
| owner / artist | Skyiah `act_owner_skyiah` / Arty `act_agent_arty` |

---

## Why it is not a darkened concrete

Two things carry the difference, and neither is brightness.

**Structure is transposed.** `concrete_facility` is a poured wall: horizontal
courses every 1.0 m, vertical joints every 2.0 m, bolts **on the horizontal
seams**. This is a fabricated hull: **vertical stringers** every 1.0 m,
**horizontal weld seams** every 2.0 m, rivets **on the stringers**. The same
two pitches, swapped axes.

**The value hierarchy is rebuilt, not shifted.** Ramps are solved in CIE LCh
at a fixed hue and chroma per role against chosen L\* steps — the method
`art_palette.json` already uses:

| | concrete_facility | deep_space_derelict |
| --- | --- | --- |
| base | L 42–93, chroma 2–4, hue 129 (neutral) | L 22–62, chroma 8, hue 200 (cold steel) |
| trim | L 21–55 | **L 9–26** — near-black structure |
| accent | L 28–63, hue 263 | L 26–66, hue **225** |

The wall field stays the **palest large surface** (L 48) against a floor at
L 32 and a frame at L 9. Dark secondary structure establishes the room; the
pale field keeps it navigable.

**`VALUE_STUDY.png` supports the reading; it does not carry it alone.**
Grayscale removes **hue**, not brightness — a lighter and a darker version of
one texture stay lighter and darker in it. What it is good for is inspecting
the **value hierarchy and the boundaries**: whether the trim still separates
from the wall, whether the doorway and the floor plane still read.

What establishes more than a recolour is the **changed patterns**, visible
in that study and in the flat fields: panel courses that became stringers,
poured joints that became weld seams, a bolt line that moved from the seams
to the stringers, and a deck that grew anti-slip tread it did not have.
Different marks in different places, which no brightness or hue change can
produce.

---

## The four material roles

| role | file | native | metres | tiles |
| --- | --- | --- | --- | --- |
| `wall` | `derelict_wall.png` | 128 × 128 | **4.00 × 4.00 m** | both axes |
| `floor` | `derelict_floor.png` | 128 × 128 | **4.00 × 4.00 m** | both axes |
| `trim` | `derelict_trim.png` | 128 × 32 | **4.00 × 1.00 m** | horizontally; once, at the floor junction |
| `accent` | `derelict_accent.png` | 128 × 128 | **4.00 × 4.00 m** | both axes |

All at **32 texels/m**, the house convention. Every structural pitch divides
its own tile — 1.0 m = 32 and 2.0 m = 64 both divide 128 — which is what
makes the repeat invisible. `TILING_3x3.png` shows all four at 3 × 3.

**`hazard` is engine-owned and this theme supplies no replacement.** No
decorative hazard stripe appears anywhere.

**`ceiling` resolves to `wall` by the authority draft's §8.2 optional-role
fallback — intentional and resolved, not a missing asset.** One surface took
that path and the binder records it. The follow-up's directional-material
section is where that resolution has a visible consequence worth knowing.

### Two passes that were wrong, kept in `passes/`

**Noise on every material.** The wall banded 30% of columns and then dropped
45% of the pixels inside each, and the floor dithered its plate tone at 70%
per pixel — both came out as static, and on the floor the anti-slip tread
was lost inside it. A rolled band is *continuous*; a plate is one piece of
metal and takes one flat tone.

**The deck was a checkerboard.** Using the ramp's own steps put 20 L\*
between the palest plate and the darkest, and with sixteen plates to a tile
the *arrangement* became the thing that repeated. Plate tones are now a hair
either side of the field (L 28.5 and L 35.5 against L 32) and the age is
carried by **how worn each plate's tread is** — which is what actually
differs between two plates of the same metal.

**And the whole theme was re-solved once.** The first solve put the wall
field at L 58 and the room rendered as a bright steel corridor: readable,
cold, and not lonely. The hierarchy was right and the absolute level was
wrong, so base and floor were re-solved **down the same L\* axis** rather
than hue-shifted or dimmed at the lamp.

---

## The decal extension — four new, four reused

| id | metres | surfaces | orientation |
| --- | --- | --- | --- |
| **NEW** `decal_coolant` | 0.50 × 1.25 | wall | upright only |
| **NEW** `decal_corroded_seam` | 1.00 × 0.25 | wall | aligned to a seam; never free-floating |
| **NEW** `decal_panel_removed` | 0.75 × 0.75 | wall | upright only |
| **NEW** `decal_inspection` | 0.50 × 0.25 | wall | upright only |
| reused `decal_grime` | 1.00 × 1.00 | wall, floor, ceiling | any rotation |
| reused `decal_scorch` | 1.00 × 1.00 | wall, floor, ceiling | any rotation |
| reused `decal_scuff` | 0.75 × 0.25 | wall, floor | wall horizontal; floor any |
| reused `decal_stencil` | 0.75 × 0.50 | wall | upright only |

Each new mark exists because this theme has something the neutral kit
cannot describe: a **cold** trail where `decal_drip` is a warm brown run,
corrosion that follows a **weld** this theme actually has, a bay whose cover
is **gone**, and a small dated **inspection** mark.

**`decal_drip` and `decal_splatter` were deliberately not carried over.** A
warm run and a splatter belong to a wet, dirty building; this one is cold
and dry, and reusing them would have been filling a list.

Physical size is authoritative — a card is built from `metres`, never from a
pixel count. Nothing is interactive, and nothing marks an affordance.

### Protected colours — measured, not promised

`python3 tools/content/check_decal_colours.py` over both records:
**PASS, 44 colours checked, 0 refused**, with 11 negative controls, 0 wrong.

The accent is the only saturated family in the theme, and it is **39.4° in
hue from `signal` `#39d7c8`** and 38.0° from concrete's own accent — neither
a gameplay colour nor a borrowed one. Its three entries (chroma 20.8, 27.9,
28.0) are above the gate's chroma floor and were therefore checked against
every guarded hue rather than waved through as "reads as dirt".

**No warm emergency colour was authored, deliberately.** The only warm
semantics available are engine-owned — `hazard` orange and `send` yellow —
and inventing a decorative warm that sits near either is what the brief
forbids. Recorded as a gap rather than filled badly.

---

## Real-geometry binding

`tools/content/derelict_preview.gd`. Three instances of the same approved
scene, 40 m apart, per-surface overrides only.

| check | result |
| --- | --- |
| unresolved surfaces (concrete / derelict / dressed) | **0 / 0 / 0** |
| shared mesh materials unchanged by binding | **true** |
| collision digest unchanged by binding | **true** — 10 bodies, 10 shapes, instance-local transforms |
| dressing added collision | **no** — same bodies, shapes and transforms |
| dressing added | 6 `MeshInstance3D` cards and nothing else |
| geometry duplicated to carry the trim role | **none** — the trim binds to the kick rail the shell already has |
| z-fighting, flicker, floating edges | none at any of three framings |

Cards are surface-aligned `QuadMesh`, 6 mm off, alpha-blended, depth-write
off, nearest filter — the projected `Decal` node is a Forward+ feature and
does nothing in Compatibility.

### The light is a proposal, not the proof

All three instances render under **concrete_facility's own lamp**, so any
difference between them is the art. `THEME_LIGHT.png` then applies the
theme's proposed lamp (`#b9cfd6`, dim) as a **separate, labelled**
condition. A theme that only worked under its own lighting would not have
been proved, and this one does not depend on it.

**One honest consequence:** under the dim proposed lamp the sun reaches the
deck directly and the floor becomes the brightest surface in view, inverting
the stated hierarchy. That is a lighting result, not a texture one — under
the shared lamp the hierarchy holds — and it is the kind of thing a real
lighting pass would settle.

---

## Proposals, named and not bound

In `derelict_palette.json` under `proposals_not_bound`. **None is
implemented and none is a runtime contract:** a light-colour recommendation,
an emissive mask for the accent indicators (so they can glow without fake
bloom painted into the albedo, which this batch does not do), a
roughness/value mask, and a reserved 0.5 × 0.25 m animated-display strip in
the accent field, painted dark and inert here.

---

## The files

| file | what |
| --- | --- |
| `derelict_palette.json` | the theme's solved ramps and the unbound proposals |
| `author_derelict.mjs` | authors the four fields |
| `author_derelict_decals.mjs` | authors four decals, records four reused |
| `make_sheets.py` | rebuilds all five boards |
| `*.glyph`, `decals/*.glyph` | **eight editable projects** |
| `derelict_fields.json`, `decal_kit.json` | records, both carrying `glyph_sha` |
| `derelict_binding.json` | the mesh and collision evidence above |
| `THEME_COMPARISON.png` | concrete / derelict / dressed, identical light |
| `MATERIAL_HIERARCHY.png` | close, the order of the values |
| `VALUE_STUDY.png` | hue removed |
| `THEME_LIGHT.png` | shared lamp beside the proposed one |
| `TILING_3x3.png` | all four fields at 3 × 3 |
| `passes/` | the passes that were wrong |

Godot binder `tools/content/derelict_preview.gd`; colour gate
`tools/content/check_decal_colours.py`.

**Everything survives deletion of the Glyph installation.** Only
re-authoring needs Glyph back.

---

# Follow-up — lighting, directional materials, and a delivery correction

**Arty** · 2026-09-10

## The room was lit by a sun shining through its own hull

That was mine, and it is worth stating plainly because it changes what the
earlier renders meant.

`derelict_preview.gd` lit the room with a `DirectionalLight3D` and never set
`shadow_enabled`, **which defaults to `false`**. An unshadowed directional
light illuminates every surface whose normal faces it and is stopped by
nothing — so an enclosed room was being lit through its walls. Every surface
got the same light regardless of whether anything was between it and the
lamp, which is exactly why the room read as broadly illuminated.

**And a built Zone has no sun at all.** Measured in Production at `2f727a7`:

| | shipped | my first preview |
| --- | --- | --- |
| ambient | `0.35`, from `light_color(theme)` | 0.55, then 0.17 |
| per-fixture | `OmniLight3D`, `omni_range` 12.0, `shadow_enabled = false` | none |
| directional | **none** | one, unshadowed |
| fog | `fog_density` 0.012 | none |

So the sun was scaffolding I introduced. **Darkening the textures to
compensate for it was treating a rendering artifact as an art problem** —
the ramps I re-solved down are still defensible on their own terms, but that
is not the reason I gave for them at the time.

### The study

`tools/content/derelict_lighting.gd`. The sun is gone. Ambient drops to 0.13
and four `OmniLight3D` fixtures do the work, so pools and recesses come from
**placement and falloff**, which is what the game can actually do.

| fixture | energy | range | why it is there |
| --- | --- | --- | --- |
| `ceiling_panel` | 1.7 | 7.0 | the one panel still lit; it is what makes the deck readable |
| `mouth_panel` | 0.65 | 4.2 | failing, so the mouth stays gloomier than the middle |
| `west_service` | 0.55 | 2.8 | rakes the bulkhead so its stringers read as stringers |
| `conduit_glow` | 0.40 | 1.8 | the accent conduit's own indicator colour, decorative only |

Every added node hangs under **`PREVIEW_LIGHTING_NOT_SHIPPED`**. No
collision, no gameplay meaning, no runtime integration.

**Emission is recorded, not painted.** No bloom is baked into any albedo.
Each housing keeps its own dark surface colour and carries an
`emission_energy_multiplier` between 0.20 and 0.40, written per fixture into
`lighting_study.json`.

**One preview divergence, declared:** the study sets `shadow_enabled = true`
on its lights. The shipped fixture builder sets it **`false`**, so the game
as it stands gets no cast shadows in Compatibility — dark recesses there
would have to come from falloff alone. The hard shadow the west lamp throws
up the plating is therefore a preview result, and whether Production wants
fixture shadows is theirs to decide.

**Static shots cannot show combat visibility or flicker-free motion.** Three
matched framings under three lights is what `LIGHTING_STUDY.png` is; it is
not a playtest.

## Directional materials — measured, and mostly fine

`tools/content/inspect_uvs.py` solves the Jacobian dP/dU and dP/dV per
triangle from the shipped `.glb`, **grouped by face normal**. That grouping
matters: a first version averaged over each primitive and reported the same
answer for the floor, ceiling, wall and trim, which is impossible for
surfaces in different planes — the giveaway that it was averaging the six
faces of a box together.

Every piece of this shell is a box with a per-face unwrap:

| faces | U runs | V runs | pattern |
| --- | --- | --- | --- |
| the four **vertical** (±X, ±Z) | horizontal | **world up** | upright, as authored |
| the two **horizontal** (±Y) | +X | +Z | laid flat, rotated 90° |

**32 of 48 wall faces have V along world up.** The 16 that do not are the
tops and bottoms of wall slabs — nearly all hidden — **except the ceiling**,
which is exactly such a face and takes the `wall` field through the resolved
§8.2 fallback.

**Which roles tolerate rotation:**

| role | tolerates | why |
| --- | --- | --- |
| `floor` | **yes** | the deck grid is symmetric; tread reads either way |
| `wall` | **no** on a vertical face | stringers and welds are directional and must stand up |
| `trim` | **no** | it has a lit top chamfer and a dark bottom; upside-down is wrong |
| `accent` | **no** | louvres and conduit runs are horizontal by intent |

**Is the ceiling's rotation appropriate? Yes — and I am not correcting it.**
`UV_DIRECTION.png` shows both. As shipped, the stringers run *along* the
corridor and read as longitudinal stiffeners. Rotated 90° they run *across*
and read as transverse frames. Both are plausible ship overheads; the
rotated one lines up slightly better with the doorway lintel. That is a
**preference, not a defect**, so the shipped behaviour stands and the
rotation is shown only as a demonstration that a per-surface material can do
it — `img.rotate_90()` on one material's own texture, no mesh, no UV and no
shared texture touched.

**Texel density, re-checked on the real geometry:** **32.0 × 32.0 texels/m
on all 108 faces**, trim included. The declared figure holds after UV
mapping — measured from `metres_per_uv`, not taken from the asset record.

### The smallest future requirement

If consistent orientation is ever wanted, the smallest thing that would do
it is **a per-role declaration of whether the role is directional**, plus a
binder that consults the surface's own V axis. Something like
`{"wall": "up", "trim": "up", "accent": "up", "floor": "any"}` — four
strings. **Not built here**, and it needs a contract before it means
anything.

## Delivery correction

**The Batch 042 ZIP was wrong and I should not have sent it as it was.** Its
README listed editable Glyph projects and authoring scripts; the archive
contained **none of them** — the copy list simply never included them, so
the archive contradicted its own contents page.

**All eleven sources are and were committed.** Exact paths:

```
docs/art/review/derelict_2026-09-10/author_derelict.mjs
docs/art/review/derelict_2026-09-10/author_derelict_decals.mjs
docs/art/review/derelict_2026-09-10/make_sheets.py
docs/art/review/derelict_2026-09-10/derelict_wall.glyph
docs/art/review/derelict_2026-09-10/derelict_floor.glyph
docs/art/review/derelict_2026-09-10/derelict_trim.glyph
docs/art/review/derelict_2026-09-10/derelict_accent.glyph
docs/art/review/derelict_2026-09-10/decals/decal_coolant.glyph
docs/art/review/derelict_2026-09-10/decals/decal_corroded_seam.glyph
docs/art/review/derelict_2026-09-10/decals/decal_panel_removed.glyph
docs/art/review/derelict_2026-09-10/decals/decal_inspection.glyph
```

Plus the Godot side: `tools/content/derelict_preview.gd`,
`tools/content/derelict_lighting.gd`, `tools/content/inspect_uvs.py`,
`tools/content/check_decal_colours.py`.

**To reproduce the textures** you need Node ≥ 22.5.0 and an ECMS-GLYPH
checkout at **`6c80b63`** (`claude/archipepsi-glyph-tooling`), then
`npm ci && npm run build`, then
`GLYPH_ROOT=<checkout> node author_derelict.mjs .`. The `.glyph` containers
are SQLite and open with `glyph describe` / `glyph log` from that checkout —
they need nothing else.

**To reproduce the renders** you need Godot 4.5.1 with the Compatibility
renderer; the sheets need Python 3 with Pillow.

Going forward the archive ships in two clearly labelled parts: a
review-export with the images and documents, and a source bundle with the
projects, scripts and their dependency note.
