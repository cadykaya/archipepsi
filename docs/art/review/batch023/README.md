# Batch 023 — PROPOSAL: theme landmark language

**Status: PENDING. Proposal scale, not runtime truth. Nothing is integration-ready.**

## The contract audit came first

The instruction was to find the contract rather than invent one. There isn't
one, and the search is short enough to reproduce:

```
grep -rn "landmark" godot/ bridge/ assets/ tools/
```

Three hits, none an engine concept: `max_triangles.landmark = 2500` in the
derived budgets, the same number in `art_budgets.json`, and one asset
exporting under that tier. **Today "landmark" means a polygon ceiling.**

| Question | Answer |
|---|---|
| Does "landmark" have a runtime semantic contract? | **No.** A budget tier only. |
| Can Epsilon select one? | **No.** `AUTHORED_CONTENT.md` lists *Reusable landmarks and hero props* as a category it would select from; nothing implements it. |
| Placement bounds / anchors / footprints? | **None.** Room shells carry `check_anchor`, `enemy_anchors`, `affordance_anchor`, `bay_anchors`, `bounds`, `interior`, `sightline` — and no landmark anchor. |
| Standalone object, shell feature, chamber property, or art concept? | **Art/design concept only.** |
| Does Godot have an integration seam? | **No — and not only for landmarks.** `godot/scripts/` references no `.glb` and reads no manifest; `chamber_builders.gd` builds every room from `BoxMesh`. The whole authored pipeline is unwired, and the approved room shells sit in the same position. |

Recorded as **interface requirement 24**. Every manifest entry carries
`integration_ready: false` and `scale_basis: "proposal scale"`.

## Places, not props

The first pass built six OBJECTS — a ladle, a bell frame, a shaft — each
standing alone in an empty room. They were decent objects and they were the
wrong deliverable: **a landmark you walk around is a prop at landmark
scale.** The target is *"the Zone with the giant ___"*, which is a memory of
a place.

So each of these is a hero structure **plus the architecture that makes it
somewhere you were**: a route at ground level, a route above it, something
to look down from, and usually something visible you cannot reach.

| place | theme | tris | size (m) | spatial job |
|---|---|---|---|---|
| `lm_drop_test_hall` | concrete_facility | 644 | 16.30 × 16.30 × 17.95 | loop around a central void |
| `lm_process_tower` | rusted_industrial | 1396 | 13.00 × 14.00 × 17.06 | spiral route up a leaning mass |
| `lm_stacked_interchange` | neon_transit | 632 | 15.80 × 21.10 × 14.90 | two platforms around a void |
| `lm_bell_breach` | gothic_stone | 796 | 16.90 × 16.00 × 13.86 | three levels, one event |
| `lm_collapsed_ziggurat` | temple_ruin | 452 | 25.00 × 25.00 × 12.45 | the ruin IS the route |
| `lm_reentrant_room` | void_glitch | 372 | 24.08 × 18.87 × 9.28 | space that lies about itself |

- **Drop Test Hall** (concrete_facility) — loop around a central void
  *Routes:* rim loop at floor level, gallery loop above it, gantry across the void, control booth visible and unreachable
- **Process Tower** (rusted_industrial) — spiral route up a leaning mass
  *Routes:* basin floor below, spiral of catwalk stages climbing the standing column, sheared upper column overhead and unreachable
- **Stacked Interchange** (neon_transit) — two platforms around a void
  *Routes:* lower platform, mezzanine ring round the stair void, upper platform above it, stopped car at the tunnel mouth
- **Bell Breach** (gothic_stone) — three levels, one event
  *Routes:* undercroft with the bell, gallery above with the breach punched through it, empty frame above that, great stair connecting them
- **Collapsed Ziggurat** (temple_ruin) — the ruin IS the route
  *Routes:* sunken court, formal stair up the intact face, rubble ramp up the collapsed corner, surviving summit platform
- **Reentrant Room** (void_glitch) — space that lies about itself
  *Routes:* three offset copies of one room whose overlaps are crossable, a floor continuing at a wrong angle, a door opening onto its own exterior

## Art provides affordance; the engine owns mechanics

The routes above are **shapes, not rules.** Nothing here invents grapple,
teleport, boss, Check-placement, local-key, checkpoint or reachability
behaviour, and no landmark needs an unapproved capability for mandatory
traversal. Where a ledge is unreachable it is unreachable *by being high* —
a fact about geometry, not a claim about movement.

## Epsilon is absent on purpose

None of the six is an Epsilon monument. Each answers *what was this place
for* or *what happened here* from its own construction history. Epsilon is
an intrusion that arrives; these are the places it would arrive into, and
they have to read without it. Epsilon green appears nowhere as importance,
navigation or landmark colour.

## Sheets

| | |
|---|---|
| `A_landmarks_eye.png` | all six at the game's own 90° FOV from a 1.6 m eye, **standing inside** each place, with a 1.8 m human reference in frame |
| `B_landmarks_long.png` | the same six at distance, where each is a shape |

## What the renders changed

- **Six interiors were photographed from outside their own walls.** A hall,
  an interchange and an undercroft each rendered as a box with a wall facing
  camera, and the place — the entire deliverable — was behind it. The
  builder now records `eye_from` / `eye_at` per landmark, because it is the
  only thing that knows where the hero feature is.
- **The human reference was offset from the camera blindly** and landed
  behind it in most panels. It is now placed along the view direction.
- **A rig lit for an object on a backdrop leaves an interior half-black.**
  The inside views run more ambient and a stronger key; the long views keep
  the standard rig, because there the place is a silhouette.
- **The void room's viewpoint was inside one of its own copies**, so a wall
  filled the frame instead of the intersection that is the whole idea.

## Budget note

All six fit the 2500-triangle `landmark` tier (372–1396), but that tier is
described as *"an L4 set piece — one per room at most, seen from across
it"*, which is an OBJECT budget. These are places. The numbers happen to
fit; the definition does not, and if landmarks become production the tier
probably wants restating.
