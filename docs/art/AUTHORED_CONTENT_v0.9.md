# Authored content — the v0.9 clarification

**Status: owner decision, recorded 2026-08-28. Normative for the art lane.**

This document clarifies `docs/design-packet-v0.8/AUTHORED_CONTENT.md` and
`docs/design-packet-v0.8/DESIGN.md` §3.4 and §20. It does not edit them.

**The v0.8 packet is frozen and stays frozen.** It said what it said, at the
time it said it, and backdating a clarification into it would make the
project's own history unreliable — which is a worse cost than the mild
inconvenience of having to read two documents. What follows is the current
reading; where it and v0.8 disagree, this document wins **for the art lane
only** and changes nothing about Epsilon's contract.

---

## 1. What v0.8 says

`DESIGN.md` §3.4, last line:

> No AI-generated art, models, shaders or audio.

`DESIGN.md` §20:

> **Blender is installed on the development machine (4.5.9). Do not use
> it.** No modelling, no `.blend` files, no glTF pipeline, no import step.
> "The developer happens to have Blender" is not a reason to build an asset
> pipeline the design defers. Custom models are roadmap material (§23).

`AUTHORED_CONTENT.md`, the banner:

> **HUMANS MAKE THE ALPHABET. GODOT ENFORCES THE GRAMMAR. EPSILON WRITES
> SENTENCES.**

---

## 2. What it now means

### 2.1 The prohibition is on RUNTIME EPSILON-GENERATED ASSETS

That prohibition is **absolute and unchanged**. Epsilon may never
manufacture, during play:

- a mesh
- a texture
- a shader
- audio
- an arbitrary resource path
- an executable asset-generation instruction of any kind

Epsilon may **select and combine approved, shipped assets**, which is
exactly what `AUTHORED_CONTENT.md` §4 already grants it. Nothing in this
clarification widens Epsilon's half by a single row, and a change that moved
any row of §2 or §6 of that document into Epsilon's half would be out of
contract.

### 2.2 Development-time agent-authored assets ARE permitted

A model or texture created by Claude during development is **ordinary
authored game content**, on the same footing as one a human made in Blender
by hand, once all six of the following are true:

1. It is **generated and buildable in the development toolchain** — a
   committed source script plus a committed build command, reproducible from
   a clean checkout.
2. It has been **inspected** — measured, rendered, and looked at.
3. It has been **reviewed by the owner**, and the owner has marked it PASS
   in `ART_REVIEW.md`.
4. It is **committed to the repository** as a versioned artefact.
5. It is **addressed through a stable asset ID**.
6. It **ships as known content**.

Until all six hold, an asset is a candidate, not content.

The distinction that matters is not *who typed it* but *when and under what
review*. A development-time asset is inspected, reviewed and frozen before
anyone plays. A runtime-generated one is none of those things, by
definition, and no amount of validation makes it so.

### 2.3 The banner

> **DEVELOPERS AUTHOR THE ALPHABET.
> GODOT ENFORCES THE GRAMMAR.
> EPSILON WRITES SENTENCES.**

"Developers" rather than "humans": the alphabet is authored under
development-time review, and that is the property that made "humans" the
right word in v0.8. The grammar and the sentences are untouched.

### 2.4 §20's Blender prohibition is superseded, for the art lane

§20 said *do not use Blender* and gave its reason plainly: "the developer
happens to have Blender" is not a reason to build a pipeline the design
defers. That reason was correct while the POC's success condition was a
playable loop and every visual was acknowledged placeholder debt.

v0.9 is the production frontier and the debt in `AUTHORED_CONTENT.md` §6 is
now the work. So the art lane uses Blender 4.5.9 — the exact version §20
names — and builds the glTF pipeline §20 deferred. §20's *art-sourcing* rule
is untouched and remains in force:

> **Do not search for, download, browse, or evaluate external asset packs,
> texture packs, or model libraries.**

Nothing in the art lane sources an external asset. Geometry is built from
primitives in `tools/blender/brushkit.py`; textures are painted pixel by
pixel in `tools/blender/paintkit.py` from `assets/art_palette.json`, whose
anchor colours are read from the engine's own `THEME_MATERIALS`.

---

## 3. What has NOT changed

| | |
| --- | --- |
| Epsilon's half | Exactly `AUTHORED_CONTENT.md` §4. Composition and selection, never creation, at any creativity setting. |
| Godot's half | Exactly §5. Legal dimensions, collision, mandatory-path safety, spawning, affordance truth, instantiation, performance limits. A composition that violates the grammar is refused, not clamped. |
| The five authoring levels | Exactly §3. L0 props · L1 modules · L2 alcoves and stations · L3 room shells · L4 landmarks. Epsilon selects and arranges 0–4 and creates at none. |
| The debt list | Exactly §6. Every row stays a human's to fix, and moving one to Epsilon is out of contract. |
| The art-sourcing rule | Exactly §20. No external packs, textures or model libraries. |
| The three failure modes | A door you cannot recognise as a door; a ledge that is 1.4 m in one Zone and 1.9 m in another; an Epsilon that is a different character each time. All three still govern. |

---

## 4. The obligations this places on the art lane

Because an agent authored it, the evidence bar is **higher**, not lower:

- **Every asset is reproducible from committed source.** No `.blend` file is
  the source of truth for anything. `tools/check_art_current.sh` rebuilds
  everything and fails if a committed artefact moved.
- **Every asset carries objective metrics** — triangles, measured
  dimensions, measured texel density, and the anchor its origin means — in a
  manifest beside it.
- **Every asset carries standardised review evidence** rendered by the same
  bench as every other asset, at the distance it is genuinely seen from.
- **Only the owner marks PENDING → PASS.** No subjective judgement is self-
  certified. The agent may mark objective failures, never aesthetic
  successes.
- **Rejected alternatives are not deleted before review.** Three concepts
  are offered and none is chosen.

---

## 5. Where this is recorded

- This file, on `claude/archipepsi-art`.
- `docs/art/ART_BIBLE.md` §0, which points here.
- `docs/art/ART_FRONTIER.md`, which states the gate.

When the art branch is integrated, this belongs in the v0.9 design packet
proper. It is on the art branch for now because the art branch is where it
takes effect, and because the engineering branch is actively changing
content contracts and should not receive a doc-only merge in the middle of
that.
