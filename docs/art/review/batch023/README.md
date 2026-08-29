# Batch 023 — PROPOSAL: theme landmark language

**Status: PENDING. Proposal scale, not runtime truth. Nothing is integration-ready.**

## The contract audit — CORRECTED 2026-08-29

> **The first version of this audit was run against the wrong branch.** It
> searched `claude/archipepsi-build-inzshp`, which is the art lane's base and
> is 73 commits behind Production. Production had already built the authored
> content pipeline. The original wording is struck below; the corrected
> finding is narrower and more useful.

~~Three hits, none an engine concept. Today "landmark" means a polygon
ceiling. `godot/scripts/` references no `.glb` and reads no manifest; the
whole authored pipeline is unwired.~~ **All four of those statements are
false.** Audited read-only against
`claude/archipepsi-echoes-continuation-b1adno`:

`ContentRegistry` (321 lines) loads JSON manifests from
`res://content/registry/`, and validates category, level, sockets,
footprints, scene existence, fallback chains and cycles.
`ContentInstantiator` routes every chamber build as *authored scene if
available -> validated fallback*, reading the `shell_id` Epsilon chose.
`schemas/content.py` (489 lines) is the shape authority. **`landmark` is a
real registered category at L4** in both languages, pinned together by
`test_content_registry.py`.

### One name, two unrelated meanings

Worth naming before anything else, because it makes a `grep` misleading:

| sense | where | what it means |
|---|---|---|
| **A — asset category** | `ContentCategory "landmark"`, L4 | a registry entry for an authored thing |
| **B — composition metric** | `composition.LANDMARK_RATIO = 1.8`, `epsilon/fallback.py` | *the biggest room in a Zone*, by content value — `landmark["width"] = 26.0` |

19 of Production's 26 "landmark" mentions are **sense B**, which has nothing
to do with an asset.

### The six questions, answered against current Production

| # | Question | Answer |
|---|---|---|
| 1 | Is there a landmark **category**? | **Yes.** L4, in `content.py` `_LEVELS` and `content_registry.gd` `LEVELS`. Not a budget tier — a validated category. |
| 2 | Can Epsilon **select** one? | **The query exists; the offer does not.** `ids_of_category("landmark")` and `ids_with_tags(tags, "landmark")` would answer. But the only id Epsilon is offered and that is read back is `chamber.shell_id`. There is no `landmark_id` on the chamber schema, so there is no field in which to name one. |
| 3 | Can runtime **place** one? | **No.** `ContentInstantiator` has exactly two placement routes: `SHELL_FOR_TYPE` (room_shell) and `fixture_light_%s` (fixture). Nothing queries category `landmark`. The registry today carries 12 entries — 5 room shells, 6 light fixtures, 1 connector — all `procedural_fallback: true`, and **zero landmarks**. |
| 4 | Is there a **footprint / bounds / anchor** contract? | **No, and this is the sharpest gap.** `NEEDS_FOOTPRINT := ["cluster"]` excludes landmark; `NEEDS_SOCKETS := ["room_shell", "connector"]` excludes it too. `Constants` publishes `CLUSTER_ANCHORS`, `CLUSTER_MAX_WIDTH/HEIGHT/DEPTH`, `CLUSTER_CLEARANCE`, `CLUSTER_MOUNTED_UNDERSIDE_MIN` — and **no `LANDMARK_` equivalent**. A landmark entry would load carrying no envelope at all, which is the exact thing `cluster` was given a validator to prevent. |
| 5 | Is the gap **merely Art→registry asset integration**? | **No — that understates it by three steps.** See the chain below. |
| 6 | What of old req 24 survives? | The *landmark* half, reworded. The *pipeline* half is deleted outright. |

### The real seam, in four steps

| # | step | state |
|---|---|---|
| 1 | approved `.glb` → Godot-importable scene under `res://content/` | **MISSING.** Art writes `assets/models/**.glb`; the Godot project contains **zero** `.glb` and does not include `assets/` at all. The registry hard-refuses any scene not under `res://content/`. |
| 2 | → content-registry entry | **POSSIBLE TODAY.** The category exists and a well-formed manifest entry would load. |
| 3 | → selection | **MISSING.** No `landmark_id` on the chamber schema; nothing offers landmark ids to Epsilon. |
| 4 | → placement | **MISSING.** No instantiation path, and no envelope to place against (see 4 above). |

Step 2 works. Steps 1, 3 and 4 do not. Every manifest entry still carries
`integration_ready: false` and `scale_basis: "proposal scale"` — the reason
is now step 1, 3 and 4, not "there is no pipeline".

### What Art should NOT ask for

Production has already built manifest loading, semantic ids, authored scene
loading, the shippability gate, shell validation, procedural fallback and the
L4 category. None of that needs requesting again.

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

`LandmarkGallery.gd` renders the same twelve views as individual files for
presentation surfaces that set their own typography. It calls `Landmarks.gd`'s
own `_panel()` rather than reimplementing the rig, so a gallery panel and its
sheet cell cannot drift; only the packaging differs. It writes nothing into the
repository -- pass it an output directory:

```
xvfb-run -a -s "-screen 0 1920x1200x24" .tools/godot --rendering-driver opengl3 \
    --path tools/artpreview -s LandmarkGallery.gd -- "$PWD/assets" <out_dir>
```

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
