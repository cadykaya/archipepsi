# Batch 023 — PROPOSAL: theme landmark language

**Status: PENDING. Nothing here is integration-ready.**

## The contract audit came first, and it changed the batch

The instruction was to find the contract rather than invent one. There
isn't one, and the search is short enough to reproduce:

```
grep -rn "landmark" godot/ bridge/ assets/ tools/
```

Three hits, none an engine concept: `max_triangles.landmark = 2500` in the
derived budgets, the same number in `art_budgets.json`, and one asset
exporting under that tier. **Today "landmark" means a polygon ceiling.**

| Question | Answer |
|---|---|
| What does the game mean by "landmark"? | A triangle budget tier — "an L4 set piece, one per room at most, seen from across it". Nothing else. |
| Does Epsilon select a landmark ID? | **No.** `AUTHORED_CONTENT.md` lists *Reusable landmarks and hero props* as a category it would select from; no schema field or vocabulary entry implements it. |
| Is there a placement / footprint / anchor contract? | **Not for landmarks.** Room shells carry `check_anchor`, `enemy_anchors`, `affordance_anchor`, `bay_anchors`, `bounds`, `interior`, `sightline`, `exit_offset` — and no landmark anchor. |
| Room property, object, shell feature, or composition idea? | Only the last, plus the budget tier. |
| What bounds may landmark geometry legally own? | Nothing reserves any. The only hard numbers are the 2500-tri landmark ceiling and the 12000-tri room budget. |
| Does Godot have an integration seam? | **No — and not only for landmarks.** `godot/scripts/` references no `.glb` and reads no manifest; `chamber_builders.gd` builds every room from `BoxMesh`. The whole authored pipeline is unwired, and the approved room shells sit in the same position. |

So this is a **visual-language proposal**. The missing seam is interface
requirement 24. Every manifest entry carries `integration_ready: false`,
and the footprints on the sheets are **measured, not reserved** — they say
how big the proposal is, not what it is allowed to own.

## The six

Each answers *what was built HERE* from its own theme's construction
history. **None is an Epsilon monument** — Epsilon may arrive later as an
event, and Epsilon green stays Epsilon's identity rather than becoming the
generic "important place" colour.

They take deliberately different **spatial jobs**, because six variations
on "big object in the middle of the room" would not punctuate a 20-room
Zone:

| landmark | theme | tris | measured (m) | spatial job |
|---|---|---|---|---|
| `lm_freight_shaft` | concrete_facility | 328 | 9.4 × 5.5 × 10.1 | vertical shaft, reads at two elevations |
| `lm_pour_ladle` | rusted_industrial | 368 | 6.9 × 10.8 × 5.3 | curved mass, ramp and mid-room cover |
| `lm_escalator_bank` | neon_transit | 464 | 7.6 × 10.6 × 8.5 | level link, circulation between floors |
| `lm_bell_frame` | gothic_stone | 428 | 9.3 × 5.8 × 8.5 | overhead volume, one story at two heights |
| `lm_stepped_cistern` | temple_ruin | 492 | 10.1 × 10.1 × 4.7 | cut void, descends -- negative not mass |
| `lm_unfinished_room` | void_glitch | 168 | 11.7 × 8.1 × 6.5 | broken construct, the theme admitting it is built |

- **Freight shaft** (concrete_facility) — a lift stalled between floors.
  Built to move heavy things vertically; stopped mid-job. Open on two sides
  so it reads *up*: the same cage seen from below and from the floor above
  makes one place, not two. Supports a platform, a second one at a
  different height, and a sightline between storeys.
- **Pour ladle** (rusted_industrial) — a tapped ladle frozen mid-pour, the
  spill hardened where it fell. The only **curve** in a project built from
  boxes, which is most of why the room is memorable. Supports a ramp onto
  the shoulder and hard cover mid-room.
- **Escalator bank** (neon_transit) — three flights under a departure
  board, one collapsed into a ramp. The one landmark whose reason to exist
  is **circulation**, and it ties to approved work: the board is a housing
  for runtime wording exactly as Batch 022's signage is.
- **Bell frame** (gothic_stone) — the headstock, and the bell on the floor
  below it. Occupies the **volume overhead**, so the memorable thing is
  something you walk under; the fallen bell puts the other half of the same
  event at floor level. One story at two heights.
- **Stepped cistern** (temple_ruin) — a dry stepped tank cut into the
  floor, roots through the joints. The only **void** in the set. Five
  masses plus one hole is a set with range; six masses is one idea. From
  the rim you see the whole geometry and everything standing in it.
- **Unfinished room** (void_glitch) — a room that failed to load. Nothing
  was built here, which is this theme's only honest answer: a fragment at
  the wrong scale and angle, a scaffold of provisional shells, one form
  stamped several times like a loop that never terminated. Deliberately not
  Epsilon: this is the substrate showing through, not an intrusion.

## Sheets

| | |
|---|---|
| `A_landmarks_player_scale.png` | all six, same camera, same room, same 1.8 m human reference, with `corridor_height` 3.6 m marked on the back wall |
| `L_*_silhouette.png` | the shape read — the harder test |
| `L_*.png` | each landmark lit, three-quarter |

## What the renders changed

- **The cistern's whole idea was invisible.** The first sheet laid one 30 m
  floor slab over everything, sealing the four terraces underneath, so the
  one proposal whose point is that it *descends* rendered as a flat frame
  lying on the ground. The panel now opens the floor around a landmark that
  declares `cuts_floor`.
- **`brushkit.frame` stands in the XZ plane.** Used for a horizontal
  terrace it builds a nine-metre wall on end — a 4 m pit that measured
  10.6 m tall. The cistern needed a flat-ring helper of its own.
- **`brushkit.stair` takes per-step run and rise**, not totals. Passing a
  4.4 m total rise asked for a 4.4 m step and the builder refused it, which
  is the check doing its job.
- **A caption claimed a test that had not run.** The shot key is `variants`
  (an array); written singular it was silently ignored, and six lit frames
  shipped labelled SILHOUETTE.
- **The escalator read as one glowing slab.** neon_transit's accent at
  balustrade size filled the whole flight and hid the steps — the entire
  point of an escalator. Balustrades are `trim` now.
- **A blue bell reads as a slab.** The bell wore the theme accent, which in
  gothic_stone is a cold blue, and a truncated cone on its side has no
  mouth. It is bronze-valued trim now, with a flared rim.

## What art did not do

No mechanics were invented. Nothing here gates progression, none of it
requires an unapproved movement capability for mandatory traversal, and no
Check, hitbox, affordance or objective truth was moved to make a
composition work. The jobs listed above are things a landmark could
**support** if the engine chose to — the engine remains the authority.
