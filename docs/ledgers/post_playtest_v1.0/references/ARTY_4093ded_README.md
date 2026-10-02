# Archipepsi art — everything from 2026-09-22

**Arty**

Branch `claude/archipepsi-art`, PR #5 (draft), pushed through `4093ded`.
Full suite green at every commit:
`check-art: PASS — every generated asset matches its source.`

**Paused here at the owner's request.** The pack queue is genuinely
blocked at T08 — see §3.

---

## What is in this archive

```
docs/art/reports/          the two written reports
docs/art/theme-packs/      COVERAGE.md — both ledgers
docs/art/review/           ten folders of frames, each with a signed README
source/                    every tool written or changed today
```

---

## 1 · The tile-edge course break — a candidate, not an application

**Read** `docs/art/reports/2026-09-22-course-candidate.md`.
**Look** at `docs/art/review/course_candidate_2026-09-22/` — start with
`STRIP_neon_transit_wall.png`: shipped above, candidate below, 24 m of
wall, six repeats, same scale, same flat light.

I named the mechanism wrong **twice**, and both wrong turns are in the
report. A `panel_grid`-only shim left `concrete_facility_wall_ribbed`
byte-identical — which is how the incompleteness was caught rather than
argued. Three paths are live, not one.

**Shipped measures 4 broken axis/texture pairs. The candidate measures 0.
Nothing is applied.** The shipped set rebuilds byte-identical with
`paintkit.SNAP_COURSES` off, and the suite proves it rather than asserting
it.

**The cost is real and it is your call.** 18 of 22 pitches move; the
divisors of 128 are the powers of two, so 1.35 m has nowhere nearer than
1.0 m. My read, which is not the decision: `neon_transit` and
`concrete_facility` improve, `gothic_stone` does not.

---

## 2 · Seven game packs, one shell, four cameras

| | pack | subtheme, stated | family | frames |
|---|---|---|---|---|
| T01 | Ocarina of Time | Forest Temple | `temple_ruin` | `forest_temple_2026-09-22/` |
| T02 | Super Mario 64 | Tick Tock Clock | `rusted_industrial` | `clockwork_2026-09-22/` |
| T03 | Bomb Rush Cyberfunk | Brink Terminal, after hours | `neon_transit` | `brink_2026-09-22/` |
| T04 | Super Metroid | the Wrecked Ship | `rusted_industrial` | `wreck_2026-09-22/` |
| T05 | Kingdom Hearts 2 | Twilight Town service alley | `temple_ruin` | `twilight_2026-09-22/` |
| T06 | DOOM 1993 | the UAC techbase | `concrete_facility` | `foundry_2026-09-22/` |
| T07 | Dark Souls III | High Wall of Lothric, aqueduct run | `gothic_stone` | `lothric_2026-09-22/` |

Every one is shot from the **same four camera positions in the same
Production-grey shell**, with Batch 043's wall-switch housing in the
**same place on the same wall**. Seven `*_approach.png` side by side is
the test.

Each folder has a **README signed Arty** with its own findings, its own
weaknesses, and its own unfinished integration work.

**Catalogue coverage and completed pack coverage are reported
separately**, as you asked. Catalogue **81 of 81**. Completed **0 of 81**.
In progress **7**.

---

## 3 · THE PACK QUEUE IS BLOCKED AT T08 — the three findings that block it

### a. T05 was an experiment and it failed usefully

T05 shares `temple_ruin` with T01 **on purpose**, to test your criterion
that *a useful visual variant is not a duplicate merely because its
construction is shared*.

The shapes are different and legible as different — corbelled brick piers
against rooted columns, a four-thickness hoarding against a split relief,
a rolled awning against a bossed surround. And `TW_approach.png` still
reads as a warmer Forest Temple, because `temple_ruin`'s accent is mossy
stone, so awning canvas reads as foliage.

> **The geometry says "boarded-up shopfront". The pixels say "overgrown
> temple". The pixels win.**

Its frames are deliberately not lit or posed to hide it.

### b. The family runway is spent at T07

```
temple_ruin        T01, T05      doubled — T05 is the proof
rusted_industrial  T02, T04      doubled
neon_transit       T03
concrete_facility  T06
gothic_stone       T07           ← the last one
void_glitch        UNUSABLE
```

`void_glitch` is Archipepsi's own **missing-texture theme** — an editor
checkerboard with `null` written across it. A game pack painted in it
would mean *"this texture failed to load"*.

> **Every pack from T08 must share pixels with an earlier pack, or wait.
> Seventy-four packs are behind.**

### c. The per-game hint covers 6 of 81 games

| pack | hint | nearest family by MATERIAL | |
|---|---|---|---|
| T01 | `temple_ruin` | `temple_ruin` | agree |
| T02 | `concrete_facility` | `rusted_industrial` | **disagree** |
| T03 | `neon_transit` | `neon_transit` | agree |
| T04–T06 | **none** | — | nothing to compare |
| T07 | `gothic_stone` | `gothic_stone` | agree |

The hint picks a family by **game**; a treatment follows what a pack is
**made of**. Two questions, one field — and **a hint that is right most of
the time is worse than one that is always wrong, because nobody notices
the one case.**

`COVERAGE.md` §3 carries a backward-compatible seam for Prod/Dess to
accept, amend or refuse. **Art did not build a second loader.**

---

## What the gates took away, and what that tells you

Four refusals across seven packs, and between them they describe where a
theme pack stops:

* **T01's door boss** grew sideways and overhung the doorway by 0.04 m.
* **T04's pressure-door coaming** — a 0.10 m sill across the opening is
  **floor**, and floor is Production's whatever its height. Note it is
  *under* the 0.12 m walk-up, so the foothold rule would never have seen
  it.
* **T05's awning valance**, hanging 6 cm below the door head. That is
  what a valance does, and it is still **headroom**.
* **T03's shutter guide lip**, tangent at exactly 1.20 m, which taught
  the gate a millimetre in width as well as in height.

T04's coaming and T05's valance are **the same rule seen from both ends
of the same opening**. If either should exist, it is Production's to
place; art has marked where.

**A fourth gate was added today** — `assert_fits_corridor`. T02, T03 and
T07 all shipped a surround poking through a 3.6 m ceiling, and the only
thing that ever noticed was a human reading a manifest.

**And one thing no gate can say.** T07's buttress springing was two
stepped wedges; `assert_parts_touch` was satisfied by a 14 cm overlap and
the frame showed a staircase hanging in mid-air. *A gate can say a thing
is attached. It can never say it is legible.* That is the case for the
in-engine frames existing at all.

---

## 4 · Glyph, advanced to `87db9e2`

`docs/art/reports/2026-09-22-glyph-toolchain-trial.md` §5. Both addendum
repairs verified over **real stdio JSON-RPC**, not in process. One edit →
commit → **image opened** → reopen → export, as a granted artist distinct
from the owner. `memory.promote` on my own candidate refused even with
`scopes:["*"]`.

**Verdict unchanged: adopt `check_tiling` as a reporting step, do not move
the authoring build.** `6c80b63` stays, clean and unmoved.

Worth knowing: **opening a `.glyph` writes to it.** Five `verify` runs on
the repository's own fixtures modified six tracked files by checkpointing
their WAL. Restored.

---

## What I need from you

1. **A ruling on the course candidate**, per treatment or wholesale.
2. **The T08 question.** Is a recolour-shaped pack acceptable as an
   interim? **Art's answer is no, and T05 is the evidence** — but it is
   your call and 74 packs wait on it.
3. **A pack-namespace decision from Prod/Dess**, for which `COVERAGE.md`
   §3 carries a proposal.
4. **Nothing on Glyph.** That one is answered.

Unblocked meanwhile, if you would rather I kept moving: **A15**
(item/Forge modules), **A16** (finish the six theme families),
**A17–A19**.
