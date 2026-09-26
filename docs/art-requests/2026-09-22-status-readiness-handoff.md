# Batch 052 — the status kit drew the destination; the runtime runs the origin

**Arty**

**To:** Prod (integration), and whoever owns the HUD's persistent tier
**Art head:** this commit, branch `claude/archipepsi-art`
**Read against:** Production `claude/archipepsi-0-4-blindside`

**Every asset here is a CANDIDATE.** Drawn, exported, previewed in-engine
and checked against Production's own guards. **Not** runtime-bound and
**not** owner-approved. Those are three separate states and this delivery
claims the first.

---

## The finding, in one paragraph

`Constants.ECHO_STATUS_KINDS` is a **closed** vocabulary of 24 —
`StatusEffects.apply` refuses anything outside it — and
`ECHO_STATUS_KINDS_IMPLEMENTED` names the **13** with a runtime effect.
Batch 043's status kit drew Design 6 §15.2's thirteen. **The overlap is
two.** `lightened` and `burning` are the only statuses that were both drawn
and implemented; the other eleven implemented kinds — `slowed`, `frozen`,
`shocked`, `poisoned`, `marked`, `stunned`, `vulnerable`, `empowered`,
`low_profile`, `haste`, `regenerating` — are conditions the game can put on
a target today with **nothing on screen to say so**, and eleven of the kit's
markers were for kinds `apply()` refuses outright.

This is the same shape as A10's finding that an authored enemy takes zero
damage tint: the art was correct against the document it was drawn from, and
nobody had asked the engine.

Batch 052 draws the eleven. The kit now covers the whole closed vocabulary.

---

## 1 · The evidence, and what it refuses to do

`tools/content/run_status_readiness.sh` →
`docs/art/review/status_readiness_2026-09-22/readiness.json`

```
[statusready] PASS -- every kind apply() admits is drawn, and every
              runtime claim matches the runtime; 5 note(s)
```

Four things it will not do, each of which would make it worthless:

- **It does not restate your constants.** It loads your real
  `constants.gd`, fetched read-only.
- **It does not restate your guards either.** It reads your real
  `status_effects.gd` and requires all three of `apply()`'s refusals to
  still be in it, verbatim. A guard you rewrite is a guard this harness is
  no longer entitled to check on your behalf, and it stops rather than
  keeps checking a rule that has moved.
- **It does not translate between the two target vocabularies from
  memory.** §15.2 says *what* a target is (actor / object / surface /
  volume / player); `StatusEffects.side` says *whose* it is (`self` /
  `enemy` / `object` / `surface` / `volume`). The map is declared as data
  in `status_kit.json` and both of its sides are checked against their
  sources.
- **It does not fail the kit for drawing the design.** A glyph whose §15.2
  targets are wider than today's support is correct art ahead of a staged
  runtime, and it is reported as a note. Only a claim about the *runtime*
  that is wrong about the runtime is a failure.

**It bites.** Five sabotages, five refusals: a kind with its glyph removed;
a glyph claiming a target `ECHO_STATUS_SUPPORTED_TARGETS` does not give it;
a vocabulary map pointing at a target kind that does not exist; a typo'd
kind (the thing `apply()`'s first guard exists for); and one of your three
guards rewritten.

---

## 2 · What I need from you: an owner for three statuses that have nowhere to go

**`haste`, `low_profile` and `regenerating` are implemented on `self` and
nothing else.** This kit's entire presentation model is *a marker anchored
to a target*. The player is the camera. There is no legal world position for
them.

The preview's runtime-legality gate found this by refusing to render them —
two of the three had been placed on enemy stand-ins in my first pass and the
assertion caught both. `STATUS_runtime_*.png` now places **ten of thirteen**
and its caption says so rather than quietly showing a full set.

They are drawn and they are on every sheet. The answer to *where* is almost
certainly the persistent HUD tier, which the preview mocks with rectangles
and deliberately does not design. **That is an integration question with no
owner, not a gap in the kit.** Name the tier and I will fit the markers to
it; I am not going to design a HUD to fill the hole.

---

## 3 · What the eleven are, and which parts of them are mine

ECHOES §8 names the eleven and stops — no family, no target list, no
duration, no sentence. Each carries a `*_source` field in `status_kit.json`
saying where its values came from, so a later reader can tell a quotation
from a proposal.

| status | family (Art's) | runtime targets (yours) | because the runtime |
|---|---|---|---|
| `slowed` | KINETIC | self, enemy | `ground_friction` × (1 − 0.4·mag) |
| `frozen` | KINETIC | self, enemy | the same channel at 0.6; plus the enemy attack/move lock |
| `haste` | KINETIC | self | the one status on `move_speed` |
| `marked` | COGNITIVE | enemy | +25% incoming; `_refresh_damage_tint` already reads it |
| `vulnerable` | COGNITIVE | self, enemy | `damage_taken` × 1.5, both sides |
| `empowered` | COGNITIVE | self, enemy | `damage_dealt` × 1.5 |
| `low_profile` | COGNITIVE | self | halves the enemy's aggro radius |
| `stunned` | PERMISSION | enemy | no attack and no move — `silenced` and `rooted` at once |
| `shocked` | MATERIAL | self, enemy | +10% taken, and half-rate cooldown recovery |
| `poisoned` | MATERIAL | self, enemy | 2.0·mag of `dot_per_second()` |
| `regenerating` | MATERIAL | self | `regen_per_second()` |

`duration` is `5.0 s` throughout — the figure `lab_driver.gd` and
`stats_driver.gd` actually apply, not a tuned design value — and `chance` is
omitted because nothing publishes one.

**No fifth family was invented.** §15.2 settled the count at four
deliberately, and a taxonomy decision is not Art's to take. `empowered` is
the weakest of the eleven assignments and is named as such in
`DECISIONS_FOR_OWNER.md` item 7 rather than argued into looking solid.

---

## 4 · A gate that bit its own author twice

`author_status_kit.mjs` used to check exactly one thing about a hand-drawn
body: that it was 16 rows of 16 characters. A kit whose whole job is to say
*which* of twenty-four conditions is on a target had no rule that any two of
them looked different, and it was about to take eleven new members.

It now measures every pair — over every offset within two pixels and the
horizontal mirror — as `1 − max sqrt(IoU(body) · IoU(outline))`, with a
floor of **0.25** and a higher bar of **0.45** for thirteen named pairs
whose *meanings* are adjacent. Both numbers are measured off the existing
kit, not picked: its own closest pair is `brittle` / `shatterpoint` at
0.304, which Batch 043's comment already defends, and the named pairs'
measured minimum is 0.507.

It refused two of my own drawings during the batch:

- **`shocked`** was a block with a jagged void torn through it — measurably
  `brittle`, at **0.295**, the closest pair in the whole kit and under the
  floor. Both would have read as *a block with a fault in it*, and both are
  MATERIAL, so the family frame could not have separated them either. The
  discharge moved outside the body; the pair is now 0.51.
- **`low_profile`** was never refused — 0.364, past the floor — and was
  redrawn anyway. It was a tall rectangle with interior structure, and so
  are `brittle`, `phased`, `shatterpoint` and `updraft`: it appeared in the
  kit's twenty closest pairs **five times**. No single pair was wrong; the
  shape was crowded. Its nearest neighbour is now 0.608.

The vertical mirror is deliberately **not** searched, because up and down
mean something here: `burning` rises and `poisoned` falls, `conductive`
hangs its bolt below a rail and `shocked` stands one on a mass.

---

## 5 · Two smaller things fixed in place

**`SHEET_markers.png` was silently dropping a third of the kit.** The grid
was a hardcoded `cols = 7, rows = 3` — exactly the 21 markers that existed
when it was written. The eleven new ones pasted past the band, under a title
that still read *the thirteen statuses and eight compounds*. The grid and
the title are derived from the kit now.

**`status_kit.json` recorded the player tick as `#ffd45c` (`send`)** — for
the whole time `DECISIONS_FOR_OWNER.md` has said the owner's ruling 2 (*the
tick is neutral*) was applied, and the whole time the art has painted it
neutral. The art was right; the manifest was wrong, in the one field a
reader would trust it for. The colour block is derived from the palette the
pixels come from now, and reads `#f6f9fb`.

---

## 6 · What I am NOT claiming

- **Not runtime-bound.** Nothing consumes these. There is no status
  presentation path in the engine at all; see §2.
- **Not owner-approved.** Candidates, pending subjective visual review, and
  six open decisions are in `DECISIONS_FOR_OWNER.md`.
- **No status mechanic is implemented by any of it.** The preview's states
  are a hand-written table: no roll, no countdown, no §15.4 pipeline.
- **Stills do not prove combat visibility.** They do not prove the markers
  are flicker-free in motion or readable while the player is turning. That
  needs play, and it has needed play since Batch 043.
- **`frozen` is the assignment I would look at second.** It is KINETIC
  because it is the larger coefficient on the same `ground_friction` channel
  as `slowed`, and splitting a severity ladder across two families would
  hide that they are one thing — but its enemy-side effect is an action
  lock, which is what PERMISSION is for.

---

## 7 · Reproduce

```
GLYPH_ROOT=/path/to/ecms-glyph node \
    docs/art/review/status_2026-09-11/author_status_kit.mjs
python3 docs/art/review/status_2026-09-11/make_sheets.py
tools/content/run_status_preview.sh
tools/content/run_status_readiness.sh
```

Every PNG in `png/` reproduces byte-for-byte from `status_bodies.mjs`; the
`.glyph` project files are SQLite databases and do not, which is why the
PNGs are the assets and the atlas is a supplement.
