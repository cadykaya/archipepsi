# Batch 029 — PROPOSAL: the secret clue language

**Status: PENDING. Visual language only.** Nothing decides what a secret
contains, how it opens, what it is worth, or where secrets are placed.

## The audit — this batch had the most contract to work with

Read-only against `claude/archipepsi-echoes-continuation-b1adno`.

- **`"secret"` is a real socket kind.** `schemas/content.py`:
  `Literal["doorway", "corridor_end", "affordance", "spawn", "objective",
  "secret", "vista", "presentation"]`, with a `position` and a `yaw`. A shell
  can already declare *where* a secret is, in a validated schema, today.
- **Secrets are scored.** `content_value.py`: `SECRET_VALUE = 8` — *"Per
  authored secret. Optional, findable, and the reason to look around."*
- **There is already an assist.** `secret_ping` is an Echo readout. That
  matters: the game can already *tell* a player where a secret is, so the
  visual language has to be the **primary** channel with the ping as an
  Echo-granted assist. A cue that only works once you have the right Echo is
  not a cue.

**What is missing is narrow.** The socket says where a secret *is*. Nothing
says what one *looks like* — no cue vocabulary, no difficulty grading, and no
way for a shell to declare "this is a learning-tier cue" so a Zone can teach
before it tests. **Interface requirement 30.**

## The one idea

> **A secret cue is not a thing. It is a deviation from a pattern.**

Which has a hard consequence: a cue asset on its own is meaningless. "One
panel sits proud" only exists relative to the five that do not. So every
asset is a whole wall-and-floor section containing **both** the repeating
baseline **and** the single place it fails — and the review sheet is
therefore a game with a pass mark: *if you cannot find it, that tier is
wrong.*

No secret colour and no beacon. A colour would be a label, and a label is the
opposite of a thing you notice. The player is meant to feel clever, and you
cannot feel clever about reading a sign.

Tiers are a **magnitude**, not three more cues: the same deviation at 100%,
50% and 25%, with the learning tier also lit harder because "meant to be
found" is part of what that tier is.

## The sheet's verdict on itself

The test was run as specified — captions name the pattern and the tier and
never say which bay is wrong. Reading the final sheet cold:

| cue | tier | verdict |
|---|---|---|
| `construction_seam` | medium | **reads** — the horizontal joints are unmistakable once you look |
| `displaced_panel` | learning | **reads** — the proud edge catches its own shadow |
| `service_access` | medium | **reads, weakly** — the handle and hinge are there but small |
| `light_leak` | learning | **too weak for its tier.** A learning cue should be unmistakable and this one is a slight brightening |
| `repeated_motif` | subtle | **fails.** The marks do not resolve at all at player distance |
| `partial_sightline` | medium | **ambiguous** in `neon_transit`, whose own trim is bright vertical lines — the theme competes with the cue |
| `wear_traffic` | subtle | **reads — and too easily.** It is the clearest cue in the set while carrying the hardest tier, so it is mis-tiered |
| `broken_construction` | learning | **reads** — the coursing change is obvious |
| `unreachable_space` | subtle | **not proven.** The ledge sits above the frame at a 1.6 m eye, so this one has not been tested rather than failed |

**Five read, one is weak, one is ambiguous, one is mis-tiered, and one was
not testable.** That is the finding, and it is more useful than a sheet where
everything worked.

Three of those are worth naming as design results rather than render bugs:

- **`repeated_motif` may be the wrong kind of cue for this engine.** Counting
  marks needs them to resolve, and at 1998 texel densities and player
  distance they do not. A motif cue probably has to be structural rather than
  graphic.
- **`partial_sightline` collides with `neon_transit`.** That theme's own trim
  is bright vertical lines, so a "gap between panels" competes with the
  decoration. The cue is probably fine; the theme pairing is not.
- **`wear_traffic` is mis-tiered.** A polished floor spur reads instantly. It
  should be a learning cue, not a subtle one — which is itself the useful
  result, because it says wear is a *strong* channel worth using more.

## What the renders changed

- **Square-on is the worst possible angle for these cues.** A panel standing
  14 cm proud has no silhouette and casts no visible shadow face-on. It is
  also not the representative angle: a player walks *along* a corridor, so
  its walls are seen obliquely almost all the time. The rig now rakes.
- **The deviation was mid-run.** At the game's own 90° FOV a raking view down
  7.2 m shrinks the middle bays hard, so the cue was being judged at a size
  no player would ever judge it at. It is now at the near end, where a player
  actually passes it.

## Metrics

| asset | cue | tier | theme | tris | size (m) |
|---|---|---|---|---|---|
| `secret_construction_seam` | construction seam | medium | concrete_facility | 540 | 7.20 × 3.82 × 3.40 |
| `secret_displaced_panel` | displaced panel | learning | concrete_facility | 528 | 7.20 × 3.82 × 3.40 |
| `secret_service_access` | service access | medium | rusted_industrial | 552 | 7.20 × 3.82 × 3.40 |
| `secret_light_leak` | light leak | learning | gothic_stone | 540 | 7.20 × 3.82 × 3.40 |
| `secret_repeated_motif` | repeated motif | subtle | temple_ruin | 756 | 7.20 × 3.82 × 3.40 |
| `secret_partial_sightline` | partial sightline | medium | neon_transit | 552 | 7.20 × 4.07 × 3.40 |
| `secret_wear_traffic` | wear and traffic | subtle | concrete_facility | 552 | 7.20 × 3.82 × 3.40 |
| `secret_broken_construction` | broken construction | learning | rusted_industrial | 600 | 7.20 × 3.82 × 3.40 |
| `secret_unreachable_space` | unreachable space | subtle | void_glitch | 576 | 7.20 × 4.47 × 3.80 |
| `secret_tier_learning` | displaced panel | learning | concrete_facility | 528 | 7.20 × 3.82 × 3.40 |
| `secret_tier_medium` | displaced panel | medium | concrete_facility | 528 | 7.20 × 3.82 × 3.40 |
| `secret_tier_subtle` | displaced panel | subtle | concrete_facility | 528 | 7.20 × 3.82 × 3.40 |

## Sheets

| | |
|---|---|
| `A_secret_cues.png` | nine cues. Find the deviation |
| `B_secret_tiers.png` | one cue at 100% / 50% / 25% |
