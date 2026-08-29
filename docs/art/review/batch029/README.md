# Batch 029 / 036-R — the secret clue language

**Status: PASS** (owner, 2026-08-29). Locked: no universal secret colour; a
secret cue is a **deviation from a learned environmental pattern**; a
**smaller reliable vocabulary is preferred over padding the set**;
`repeated_motif` remains deleted; the current tiering is accepted.
**Stop revising this system until it has real in-game Zone testing.**

This document describes the **036 revision**, which is
what the sheets in this folder now show. The original 029 nine-cue pass and
its 5-of-9 result are recorded as history at the bottom.

## The idea, unchanged

> **A secret cue is not a thing. It is a deviation from a learned
> environmental pattern.**

So a cue asset alone is meaningless: every asset here is a whole
wall-and-floor section carrying **both** the repeating baseline **and** the
single place it fails. The sheet is a test with a pass mark — *if you cannot
find it, that tier is wrong.* No secret colour and no beacon: a colour is a
label, and a label is the opposite of a thing you notice.

Tiers are a **magnitude**, not more cues — the same deviation at 100 / 50 /
25 %, with the learning tier also lit harder because *meant to be found* is
part of what that tier is.

## The contract that exists

Read-only against `claude/archipepsi-echoes-continuation-b1adno`:

- **`"secret"` is a real socket kind** in `schemas/content.py`, with a
  `position` and a `yaw`.
- `content_value.SECRET_VALUE = 8` — *"optional, findable, and the reason to
  look around."*
- **`secret_ping` already exists** as an Echo readout. That matters: the game
  can already *tell* a player where a secret is, so the visual language must
  be the **primary** channel and the ping an Echo-granted assist. A cue that
  only works once you hold the right Echo is not a cue.

**Missing:** the socket says *where*; nothing says what a cue **looks like**,
and no tier can be declared so a Zone teaches before it tests. Interface
requirement 30.

## EIGHT cues — the current set

| cue | tier | theme | the pattern | the deviation |
|---|---|---|---|---|
| `displaced_panel` | learning | concrete_facility | panels sit flush | one sits proud |
| `light_leak` | learning | gothic_stone | every panel edge is dark | one is not, **and the light lands on the floor** |
| `wear_traffic` | learning | concrete_facility | floor wear follows the route | a worn spur leaves it and stops at a wall |
| `construction_seam` | medium | concrete_facility | joints run vertically in every bay | in one bay they run horizontally |
| `service_access` | medium | rusted_industrial | blind panels, dummy fixings | one has real fixings, a handle and a hinge line |
| `partial_sightline` | medium | temple_ruin | a solid run of panels | one gap with real depth behind it |
| `broken_construction` | subtle | rusted_industrial | one coursing, one material | one bay was built by someone else |
| `unreachable_space` | subtle | void_glitch | an enclosed room | a ledge you can see and cannot reach |

`repeated_motif` is **not in the set.** See below.

## What 036 changed, and why

| change | reason |
|---|---|
| **`repeated_motif` DELETED** | its premise — count the marks, one bay has an extra — needs the marks to *resolve*, and at 1998 texel densities and player distance they do not. A **premise failure, not a tuning one**; three more passes at mark size would have been three passes at the wrong idea. The builder branch is kept (a rejected alternative stays visible in this lane) and is simply not in `CUES`. |
| `wear_traffic` **subtle → learning** | it was the clearest cue in the whole sheet while carrying the hardest tier. The useful reading is not *make it harder* — it is that **wear is a strong channel**, so it should be the cue that *teaches* the grammar |
| `broken_construction` **learning → subtle** | it read easily at learning and survives being halved, so it takes the tier `wear_traffic` vacated |
| `light_leak` **strengthened** | too weak for a learning tier. The leak is wider and now **spills onto the floor** — a leak that exists only as a bright edge is a bright edge; one that puts light on the floor is a door that is not shut |
| `partial_sightline` **neon_transit → temple_ruin** | the cue was fine; the pairing was not. Neon transit's own trim is bright vertical lines, so a gap between panels competed with the decoration |
| `unreachable_space` **ledge 2.62 → 2.15 m** | it sat above the frame at a 1.6 m eye, so it had never actually been tested rather than failed |

**Smaller and reliable, over larger and unreliable.** Eight, not nine.

## Sheets

| | |
|---|---|
| `A_secret_cues.png` | all eight. Captions name the pattern and the tier and **never** say which bay is wrong |
| `B_secret_tiers.png` | one cue at 100 / 50 / 25 %, retained — "subtle" means nothing until you see it beside the other two |

## What the renders changed

- **Square-on is the worst possible angle for these cues.** A panel 14 cm
  proud has no silhouette and casts no visible shadow face-on — and it is not
  even the representative angle, since a player walks *along* a corridor. The
  rig rakes.
- **The deviation sat mid-run**, where a 90° FOV shrinks the middle bays
  hard, so it was being judged at a size no player would judge it at. It is
  now at the near end.
- **The eight-cue sheet first shipped showing six.** The panel index was
  moved to four columns while the sheet WIDTH stayed at three, so cues 4 and
  8 were blitted off the right edge and a blank third row was left behind. It
  was re-rendered and not looked at. Fixed, and it is L-24 for the second
  time in this lane.

---

## History — the original 029 nine-cue pass

Nine cues were built and the sheet returned **five of nine**:
`construction_seam`, `displaced_panel`, `broken_construction` and
`wear_traffic` read; `service_access` weakly; `light_leak` was too weak for
its tier; `repeated_motif` failed outright; `partial_sightline` was ambiguous
in `neon_transit`; and `unreachable_space` was never testable. Every one of
those results is answered in the table above. Kept because the failures are
why the current set looks the way it does.
