# Glyph, run for real — and one concrete wall through it

**Arty** · art lane · `claude/archipepsi-art` · 2026-09-10

Two things: the correction of an earlier reconnaissance that was reading a
snapshot, and the first Archipepsi texture authored through ECMS Glyph.

**Batch 041 stands as accepted.** No approved asset, manifest field, schema,
runtime or review state was changed by this work.

---

## 1 · The correction

An earlier reconnaissance in this lane inspected
`cadykaya/ECMS-GLYPH` at **`0cf872d`** and reported that Glyph *"is a
specification, not a program"* and that *"there is no pixel editor in it"*.

**That was true of the revision I fetched and false about the project.**
`0cf872d` is the frozen authority snapshot; the implementation lived on
`claude/glyph-v1-implementation` and was merged to `main` at
**`727129e14ade02eee6ee8b21843d4cad6e03ed9b`**. Updating and re-reading it
is what this report replaces the earlier claim with. The lesson is the
ordinary one and it is worth writing down: *the default branch at the moment
you clone is not the project.*

Glyph exists, it builds, it runs, and it drew the texture in §3.

---

## 2 · Setup, and what it actually did

| step | result |
| --- | --- |
| `git fetch origin main` + checkout | HEAD = `727129e1…`, and `727129e` is HEAD itself, so the implementation merge is included |
| Node | **v22.22.2** against the documented `>=22.5.0` |
| `npm ci` | **exit 0** |
| `npm run build` | **clean** — `tsc --build` across the workspace, no errors |
| `node tools/first-edit.mjs` | project created, 3 revisions, `example-8x.png` at 32 × 32 shown at 8× |
| **I opened the PNG** | a small face blocked in — tan disc, dark outline, a brown mark. Seen, not inferred from the exit code |
| **reopen** | the script's own check reported 3 revisions restored, top authored by the agent on behalf of the owner |
| **reopen, independently** | `glyph describe` and `glyph log` on the closed container: same head, same three revisions, both identities intact |

A TypeScript monorepo on Node 22 with **no third-party runtime dependency**
— every import in the product is a Node builtin or another workspace
package. `reportlab` and `pillow` were already present for the document
side, so nothing had to be installed beyond `npm ci`.

**The recorded `GLA-PRF-001` failure is untouched and remains open.** It is
the pixel-edit p95 at the certified envelope — 108.08 ms against a 100 ms
budget, this branch's own deterministic failure, never passed. I did not fix
it and did not run the multi-hour certification benchmark. What I can add is
a figure from a *different* workload, offered as context and not as a
counter-claim: the whole authoring run in §3 — open the container, create
asset, palette and variant, four full-canvas dense patches of 16,384 cells
each, three renders — took **936 ms**. The certified envelope is a
2048 × 2048 lattice of 131,072 cels with 50,201 revisions. A 128 × 128
single-cel texture never approaches it, so a texture lane is not where that
failure bites.

---

## 3 · One concrete_facility wall

Review package: **`docs/art/review/glyph_trial_2026-09-10/`**, README inside.

**A trial. It ships nowhere**, replaces nothing, and
`assets/textures/theme/concrete_facility_wall.png` is unchanged.

### Whose work it is

| | |
| --- | --- |
| Lead Owner, authorising | **Skyiah** — `act_owner_skyiah` |
| agent artist, drawing | **Arty** — `act_agent_arty` |

`MAKING_ART_WITH_GLYPH.md` is blunt that these are two identities and that
collapsing them has already gone wrong once in Glyph's own history — two art
trials dispatched as the owner, fifty-one revisions recording a person who
did not draw them. Every command here dispatches as the artist and carries
`on_behalf_of` the owner, and `glyph log` on the closed container shows it:
revision 1 the owner's creation, revisions 2–6 all the artist's.

### The structure came from the repository, not from taste

`assets/art_palette.json` gives `concrete_facility`'s solved ramps;
`tools/blender/materials.py` gives the vocabulary.

| | |
| --- | --- |
| tile | 128 px at 32 texels/m = **4.00 m** of wall |
| panel courses | **1.2 m** = 38 texels → rows 0, 38, 76, 114 |
| vertical joints | **2.0 m** = 64 texels |
| bolts | **0.5 m** = 16 texels, **on** the seams |
| base course | bottom **0.85 m** = 27 texels, top edge row 101 |
| weep | 0.7 m from the bolt line, about one bolt in five |
| palette | **11 entries**, every one derived from the shipped ramps |

Four passes, one revision each, committed with what was visibly wrong rather
than what was done: the pour, the panels, the base course, the wear.

**No hazard markings.** An ordinary corridor wall.

### Inspected four ways

* **native** 128 × 128, and an **8× integer enlargement** — opened, not just written;
* **3 × 3 tiled** at 2× with the tile boundaries marked: the boundary does
  not read as a seam;
* **beside the shipped painter**, both at 4×, same size, no stretching;
* **on real room geometry** — two instances of `shell_corner_left` themed
  `concrete_facility` through **Batch 041's per-surface override path**, the
  only difference between them being which PNG the `wall` role resolves to.
  0 unresolved surfaces either side; nothing rebuilt, nothing exported.

### What I can see — recorded, unverified

Glyph keeps three claims apart on purpose: `render_created` is checked,
`pixels_read` proves bytes were accessed and nothing about perception, and a
**`visual_assessment` is an attributed opinion that is never verified**. So
this is signed, not proved, and I cannot approve it — that is the owner's
and is a different act.

It reads as an Archipepsi corridor wall: the panel rhythm is right, the base
course grounds the pale field where the eye meets the floor, the bolts read
as bolts.

**And it is cleaner than the shipped wall.** Consistently: the shipped one
is grittier, its joints dithered, its base course scuffed; mine has crisper
joints, clearer bolts, a smoother band. If the house look is meant to read
*used*, this is a step toward *new*. That is the owner's judgment, and §4
says why it happened.

### Two passes that were wrong, kept in `passes/`

**Vertical striping.** Every broad patch came out a column. Mine, not
Glyph's: my seeded tie-breaker was FNV-1a read out as `h / 2**32`, `y` is
hashed last, and one `imul` does not carry the low bits into the high bits
that division reads — so it was very nearly **constant in y**. Measured:
83.2% of vertical neighbours agreed within 0.02, against 3.3% horizontal. A
murmur3 `fmix32` avalanche fixed it to 4.5% / 3.6%.

**Grit too dark and everywhere.** Inside the base course it was
`course_under` — a **0.255 value jump per pixel**, larger than the whole
`min_interactable_separation` of 0.18. Pitting is a small step, not a hole.

Both were found by measuring the image rather than by squinting at it, which
is what the Glyph guide's own boat lesson says to do: *when a render says
something is wrong and changing it does not help, look at the grid.*

---

## 4 · The concrete tooling limitation

**Indexed colour has no partial mix, and the house look is built from
partial mixes.**

`materials.py` reaches its surface through many low-strength continuous
blends — the field is `mix(base[2], accent[2], 0.10)`, broad patches land at
strength 0.26, the base course at 0.80, streaks fade continuously along
their length, speckle mixes at 0.5. A continuous painter effectively spends
thousands of colours.

Glyph's indexed mode stores a palette reference per pixel, so every one of
those mixes has to be **pre-resolved into a named entry before drawing**.
Eleven entries is a real pixel-art palette and it is why the result is
crisp — and it is also exactly why it comes out cleaner than the shipped
wall. A fading streak becomes two steps. Speckle becomes one step. The
grain the shipped painter gets for free costs an entry each.

**Three honest responses, none of them chosen here:**

1. spend more entries — a 24–32 entry palette would carry the fades, at the
   cost of the discipline that makes an indexed palette worth having;
2. accept the crisper look for Glyph-authored surfaces and say so;
3. author in RGBA mode, which Glyph supports (`GLY-COL-001`) and which would
   give back continuous mixing — and give up the palette constraint that is
   the reason to want Glyph for this work in the first place.

That is a direction question and it is the owner's.

Two smaller notes, both mine rather than Glyph's: `easel.view()` returns the
three claims under `record`, not at the top level, and my first script read
them at the wrong depth and logged nothing; and I sent the whole 128 × 128
grid on every pass when `.` leaves a cell untouched, so a pass could have
been a delta. Neither cost anything here.

**One property worth recording as a positive:** the authoring script is
**deterministic** — re-run in a clean directory it produces a byte-identical
PNG. That is what makes it a source file rather than a session.

---

## 5 · Hazard, per the owner's clarification

Batch 041's **G1** is settled and the report records the ruling: **every
pack must resolve the `hazard` role, but may resolve it to the same shared
universal material.** Separate theme-coloured hazard textures are not
required.

That matches the art lane's standing rule rather than colliding with it, and
it closes the question without a texture. **Nothing was painted for it**, and
no danger marking appears on this trial wall — an ordinary corridor is not a
place to demonstrate a hazard band.

---

## 6 · Preservation

| check | result |
| --- | --- |
| twelve shipped shells byte-identical | **yes** |
| `assets/textures/theme/` unchanged | **yes** — including `concrete_facility_wall.png` |
| asset rebuilt or exported | **no** — Blender never ran |
| manifest / schema fields | **unchanged** |
| runtime | **unchanged** — nothing under `godot/scripts/` written |
| review state | **unchanged** — twelve `pass`, three projectiles `pending` |
| Batch 041 | **stands as accepted**, a preview demonstration |
| `tools/blender/check_docs_metrics.py` | **PASS** |
| `tools/check_art_current.sh` | **PASS** |

The Glyph clone at `/home/user/ecms-glyph` is disposable and is not
referenced from this repository. Everything the trial produced — project,
script, PNGs, renders — lives in the review area and survives it.
