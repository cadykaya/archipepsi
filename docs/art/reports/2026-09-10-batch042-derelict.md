# Batch 042 — deep_space_derelict, a theme-pack visual proof

**Arty** · art lane · `claude/archipepsi-art` · 2026-09-10

One strongly differentiated theme, proved on the existing approved
`shell_corner_left` by per-surface override alone.

**This is a bounded Art-side visual proof, not runtime theme-pack
integration.** No approved texture is replaced, no theme is bound into
runtime, `Constants.THEME_MATERIALS` is unchanged, no manifest, schema, GLB,
shell geometry, collision, connector, offer, review state or catalog
membership is touched, and nothing here claims theme selection works in a
played Zone. Production's Stage 3A/3B work was not modified.

Review package: `docs/art/review/derelict_2026-09-10/`, README inside.

---

## 1 · Revisions

| | |
| --- | --- |
| Art head before | **`43cdb21`** — the brief's `38feda5` plus one docs-only commit |
| Glyph head before | **`62b0bfd`** |
| Glyph used by every delivered trial | **`6c80b63`** — `claude/archipepsi-glyph-tooling`, PR #3 draft |
| Godot | 4.5.1.stable, Compatibility (`opengl3`) |

Both trial records carry `glyph_sha`, read from the installation.

---

## 2 · Why it is not a darkened concrete

Two things carry it, and neither is brightness.

**Structure is transposed.** `concrete_facility` is a poured wall —
horizontal courses every 1.0 m, vertical joints every 2.0 m, bolts on the
horizontal seams. This is a fabricated hull — **vertical stringers** every
1.0 m, **horizontal weld seams** every 2.0 m, rivets **on the stringers**.
The same two pitches, swapped axes.

**The value hierarchy is rebuilt.** Ramps are solved in CIE LCh at fixed hue
and chroma per role against chosen L\* steps, the method `art_palette.json`
already uses. Base goes from concrete's neutral L 42–93 / chroma 2–4 /
hue 129 to cold steel at L 22–62 / chroma 8 / hue 200; trim goes to
near-black L 9–26; accent moves from hue 263 to 225.

The wall field remains the **palest large surface** (L 48) against a floor
at L 32 and a frame at L 9 — dark secondary structure establishes the room,
the pale field keeps it navigable.

**`VALUE_STUDY.png` is the load-bearing evidence.** With hue removed
entirely, the two rooms are still unmistakably different structures. A theme
differing only in brightness would collapse into the same picture there.

**The theme was re-solved once, honestly.** The first solve put the wall
field at L 58 and the room rendered as a bright steel corridor — readable,
cold, and not lonely. The hierarchy was right and the level was wrong, so
base and floor were re-solved **down the same L\* axis** rather than
hue-shifted or dimmed at the lamp.

---

## 3 · Material roles and physical scale

| role | native | metres | tiles |
| --- | --- | --- | --- |
| `wall` | 128 × 128 | **4.00 × 4.00 m** | both axes |
| `floor` | 128 × 128 | **4.00 × 4.00 m** | both axes |
| `trim` | 128 × 32 | **4.00 × 1.00 m** | horizontally; once at the floor junction |
| `accent` | 128 × 128 | **4.00 × 4.00 m** | both axes |

All at **32 texels/m**. Every structural pitch divides its own tile (1.0 m =
32, 2.0 m = 64, both dividing 128), which is what makes the repeat
invisible. All four survive 3 × 3 with no singular event and no visible
boundary.

`hazard` is engine-owned; **this theme supplies no replacement** and paints
no decorative hazard stripe. `ceiling` has no authored field and falls back
to `wall` per the authority draft's §8.2 — one surface took that path and
the binder records it rather than resolving it silently.

**Two noise passes were wrong and are kept.** The wall banded 30% of columns
and dropped 45% of the pixels inside each; the floor dithered plate tone at
70% per pixel and lost its anti-slip tread inside the static. And the deck
read as a **checkerboard** whose arrangement repeated — 20 L\* between the
palest and darkest plate, sixteen plates to a tile. Plate tones are now a
hair either side of the field and the age is carried by tread wear, which is
what actually differs between two plates of the same metal.

---

## 4 · Decals — four new, four reused

New: `decal_coolant` (0.50 × 1.25 m), `decal_corroded_seam` (1.00 × 0.25 m,
aligned to a seam and never free-floating), `decal_panel_removed`
(0.75 × 0.75 m), `decal_inspection` (0.50 × 0.25 m). Each exists because
this theme has something the neutral kit cannot describe — a *cold* trail
where `decal_drip` is a warm brown run, corrosion following a weld this
theme actually has, a bay whose cover is gone, and a small dated inspection
mark.

Reused unchanged: `decal_grime`, `decal_scorch`, `decal_scuff`,
`decal_stencil`. **`decal_drip` and `decal_splatter` were deliberately not
carried over** — a warm run and a splatter belong to a wet, dirty building,
and reusing them would have been filling a list.

Physical size is authoritative; nothing is interactive or semantic.

### Protected colours

`check_decal_colours.py` over both records: **PASS, 44 colours, 0 refused,
11 negative controls 0 wrong.** The gate was extended this batch to read a
`fields` record as well as a `decals` one, because a repeating field is
decoration too and the rule is the same.

The accent is the theme's only saturated family: **39.4° in hue from
`signal` `#39d7c8`** and 38.0° from concrete's accent. Its three entries sit
above the gate's chroma floor, so they were checked against every guarded
hue rather than waved through.

**No warm emergency colour was authored, deliberately.** The only warm
semantics available are engine-owned — `hazard` orange, `send` yellow — and
inventing a decorative warm near either is what the brief forbids. Recorded
as a gap rather than filled badly.

---

## 5 · Real-geometry binding

Three instances of the same approved scene, per-surface overrides only.

| check | result |
| --- | --- |
| unresolved surfaces, all three | **0 / 0 / 0** |
| shared mesh materials unchanged | **true** |
| collision digest unchanged | **true** — 10 bodies, 10 shapes, instance-local transforms |
| dressing added collision | **no** |
| dressing added | 6 card `MeshInstance3D`s, nothing else |
| geometry duplicated for the trim role | **none** — trim binds to the kick rail the shell already has |
| z-fighting, flicker, floating edges | none at three framings |
| doorway and floor boundaries | readable, in colour and in value |

**The light is a proposal, not the proof.** All three render under
concrete's own lamp, so any difference is the art; the theme's proposed lamp
is a separate labelled board. One honest consequence: under that dim lamp
the sun reaches the deck directly and the floor becomes the brightest
surface, inverting the stated hierarchy. A lighting result, not a texture
one — under the shared lamp the hierarchy holds.

---

## 6 · The Glyph change

**`easel.study({ value: true })`** — `6c80b63`, base `62b0bfd`, PR #3
updated. `tools/easel.mjs` only.

**The task that exposed it.** This batch's central requirement is a proof
that a dark theme is not a pale one dimmed, and that cannot be answered in
colour. Nothing in Glyph reduced to value, so the reduction would have
happened in a script outside the derivation chain, in an image naming
nothing about its source. `value: true` keeps it inside — same
re-verification, same `derived_from` digest, same `is_a_render: false`.

CIE L\*, not a channel average: L\* is the axis this project's palettes are
already solved against, and an average would answer a different question for
every hue.

**Render semantics unchanged** — `view` untouched, the reduction happens
only in the derived study after compositing, and alpha is not touched.

**Tested so it can tell a reduction from a copy**: every opaque pixel must
come back neutral, the demo uses a strongly blue ground so passing pixels
through unchanged would fail, and the value study's alpha must match the
colour study's exactly.

**Suite 337 passed, 1 failed** — the pre-existing `GLA-PRF-001`, untouched
and unrelabelled, unchanged from before the branch.

---

## 7 · What remains before this could be a shipped theme pack

Not started, and none of it is Art's alone:

1. **A runtime binder.** Nothing binds a theme to a shipped scene; this is a
   preview harness.
2. **The theme has to exist to the engine.** `Constants.THEME_MATERIALS` is
   Production's and unchanged.
3. **Somewhere for the textures to ship.** As with the six existing themes,
   the set is read only by tooling.
4. **A `ceiling` field, or a ruling that the §8.2 fallback is the answer.**
5. **Canonical material naming.** All 597 shipped slots are legacy
   `<prefix>_<role>`; a binder reads them today, but §8.4 wants exact role
   ids.
6. **The unbound proposals** — emissive mask, roughness mask, animated
   display, light colour — need a contract before any of them means
   anything.
7. **A lighting pass**, per the hierarchy inversion in §5.
8. **Owner review.** Nothing here is approved, and it is not mine to
   approve.

---

## 8 · Preservation

| check | result |
| --- | --- |
| approved textures replaced | **none** |
| GLB, geometry, collision, connectors, offers | **untouched** — Blender never ran |
| manifest, schema, catalog membership | **unchanged** |
| shell review states | **unchanged** — twelve `pass`, three projectiles `pending` |
| `Constants.THEME_MATERIALS` | **unchanged** |
| Production Stage 3A/3B work | **not modified** |
| `check_art_current.sh` | **PASS** |
| `check_docs_metrics.py` | **PASS** |
| `check_decal_colours.py` | **PASS** |
