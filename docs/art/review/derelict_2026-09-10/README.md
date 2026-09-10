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

**`VALUE_STUDY.png` is the proof.** With hue removed entirely, the two rooms
are still unmistakably different structures. A theme that differed only by
brightness would collapse into the same picture there, and this does not.

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

**`ceiling` has no authored field** and falls back to `wall`, which is the
authority draft's own §8.2 rule. One surface took that path, and the binder
records it rather than resolving it quietly.

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
