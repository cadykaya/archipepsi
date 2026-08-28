# Archipepsi v0.9 — Production and the Authored-Content Transition

**Status: the active frontier.** v0.8's Echoes 2.0 arc (S1–S10) is complete
and its packet is history, not authority-in-motion; this plan is what
wake-ups execute. It does not reopen any v0.8 contract.

## What v0.9 is for

Two things at once, and they are the same thing:

1. **Make Archipepsi ready to RECEIVE authored content cleanly.** Every
   visual in the game is a procedural placeholder today
   (`AUTHORED_CONTENT.md` §6). The goal is not to replace them — it is to
   build the seams so that replacing them later is scene work rather than
   a rewrite.
2. **Keep becoming a shippable game.** CI, settings, packaging, release
   gates. None of that waits on art.

## The governing rule

> **DEVELOPERS AUTHOR THE ALPHABET. GODOT ENFORCES THE GRAMMAR.
> EPSILON WRITES SENTENCES.**

`docs/design-packet-v0.8/AUTHORED_CONTENT.md` is normative and outranks
this plan. Epsilon is a composer, never an asset generator.

**Three rules this plan is under, restated because they are how a stage
gets faked:**

- **Do not manufacture "final art" procedurally to claim an
  authored-content stage complete.** A stage that needs a mesh is done
  when the *seam* is done and the mesh is named as a gate, not when
  something mesh-shaped is generated.
- **Existing primitive geometry and materials are valid TESTABLE
  placeholders** until real authored assets replace them. They stay.
- **Graybox `.tscn` scenes are legitimate deliverables** for these stages
  and are explicitly not final art. Each must say so in-file.

## Dependency order

The numbering below is organizational. Dependency analysis puts them in
this order, which differs from a naive 11→23 sweep in two ways worth
stating: **S21 and S22 are independent of the entire asset pipeline**, so
they are the work that continues if an art gate blocks everything else;
and **S12 is the true foundation** — S13 through S19 all consume its
vocabulary.

```
S11  CI                        ── independent, first (baseline before the tree grows)
 │
S12  registry + asset contract ── the foundation everything below consumes
 │
 ├── S13  instantiation pipeline (authored-if-available → validated fallback)
 │     ├── S14  Hub + Echo Lab migration
 │     ├── S15  room shells + connector grammar
 │     │     └── S16  encounter + traversal vocabulary
 │     ├── S17  interactable / presentation contracts
 │     └── S18  enemy / player / affordance visual interfaces
 └── S19  material / VFX / audio / lighting registries

S20  authored campaign spine   ── needs S14 + S15; carries human-decision gates
S21  settings / input / a11y   ── INDEPENDENT of all of the above
S22  packaging / first-run     ── mostly independent; S21 informs it
S23  release hardening         ── last; consumes everything
```

## Stages

### S11 — Reproducible production baseline / CI

CI on a fresh checkout, not on this development machine. Test tiers
documented: fast PR gate, full integration gate, heavyweight/nightly.
Build and version metadata. Dependency caching that cannot hide a missing
requirement.

**Acceptance:** a fresh clone has a documented route to green, and a
failure names the layer that broke.

### S12 — Authored content registry + asset contract

The technical vocabulary for human-authored content at the five levels.
Stable ids, content level, scene path, theme and semantic tags, bounds,
required clearances, connector/socket metadata, spawn-safe volumes,
capability requirements, affordance attachment points, complexity cost,
variants, fallback id.

**Epsilon references semantic ids and tags only, and may never emit a
filesystem path.** Validation rejects unknown ids, incompatible connector
geometry, impossible dimensions, missing required sockets, out-of-category
content and unsafe metadata.

Plus `ART_ASSET_SPEC.md`: scale and units, axes, origins, collision,
naming, socket naming, LODs, materials, animation naming, import settings,
and how to add an asset without touching generator logic.

**Acceptance:** the registry is testable without a single authored asset
existing, and a bad manifest fails loudly.

### S13 — Scene / prefab instantiation pipeline

The adapter. Gameplay code asks for an authored room shell, doorway or
affordance visual by id and does not care whether it gets a final asset, a
graybox `.tscn`, or the legacy procedural fallback.

```
AUTHORED SCENE IF AVAILABLE
        ↓
VALIDATED PLACEHOLDER / FALLBACK OTHERWISE
```

Collision, safe-path and capability invariants hold across every branch.
Selection and fallback are deterministic.

**Acceptance:** the same request yields the same result on any machine,
and removing an authored scene degrades to the placeholder rather than
failing.

### S14 — Hub + Echo Lab authored-scene migration

The strongest debt in §6. Separate logic from geometry: game code keeps
state, interactions, AP truth, progression, reset behaviour, measurement
semantics and fixture mechanics; authored scenes take geometry, placement,
hierarchy, landmarks and anchors.

Hub anchors: main portal, Epsilon presence, shop, Archive/loadout, Lab
entrance, progression display, postgame state, generation/loading
presentation.

**Mechanically meaningful Echo Lab dimensions stay exact and
regression-tested.**

**Acceptance:** replacing the mesh hierarchy later does not require
rewriting their gameplay systems.

### S15 — Authored room shells + connector grammar

Room shell ids, doorway and corridor connectors, entrances and exits,
floor/ceiling constraints, safe player-entry volumes, enemy spawn volumes,
objective placement volumes, optional secret sockets, affordance sockets,
vista sockets.

Existing chamber archetypes become graybox shell scenes so the pipeline is
exercised. The procedural builder remains fallback. Epsilon composes room
ids + connections + semantic intent rather than primitive numbers.

**I4 and every allocation/AP invariant hold.**

### S16 — Encounter + traversal vocabulary

Authored compositions above the room: encounter templates (frontal
pressure, ranged balcony, crossfire, brute centrepiece, reinforcement
wave, vertical pressure, defensive hold, mixed) and traversal motifs (gap,
ascent, wall-kick, grapple route, rail, lift, optional shortcut). Each
with a stable id, legal room requirements, capability requirements, socket
requirements, safety constraints, difficulty metadata.

**Base-kit solvability is absolute. Echo-dependent traversal is optional
only — with a test proving Epsilon cannot turn optional capability content
into mandatory progression.**

### S17 — Core interactable / presentation scene contracts

Stable authored-scene interfaces for the repeatedly-seen things: Check
object and reveal, Echo acquisition, portal, shop terminal,
Archive/loadout, Epsilon's anchor, local reward pickup, objectives, doors
and transitions, signage hooks, loading/generation presentation,
provider-failure presentation.

AP moments made readable: item sent, item received, recipient identity,
foreign item → Echo, waiting, reconnect/offline, goal. **Without leaking
hidden scouting information.**

### S18 — Enemy / player / affordance visual interfaces

Scene contracts for actors. Enemies: hit/hurt/death, animation state,
telegraph, attack origin sockets — collision stays mechanically
authoritative and the model may be replaced independently. Player:
viewmodel interface, action animation hooks, stable muzzle/action origins.
Affordances: footprints, clearances and mechanics preserved exactly;
visual construction moves behind scene ids.

**Prove that swapping a visual cannot change a hitbox, reachability, AP
truth or required movement.**

### S19 — Material / VFX / audio / lighting vocabularies

Semantic registries for materials, VFX, particles, impacts,
beam/projectile presentation, status and elemental presentation,
source-identity presentation, audio families, ambience, lighting presets,
atmosphere, sky packages.

Epsilon may say "cold + industrial + unstable" or select a legal preset
id. It may not generate textures, audio or shaders, author particle
programs, place arbitrary lights, or provide resource paths. The
deterministic source-identity rules stay; their semantic identity
separates from final rendering. Performance limits belong to Godot.

### S20 — Authored campaign spine

Fixed spaces and constrained compositions: first-run/onboarding, first
Zone family, Hub progression states, finale spine, postgame Hub.

**This stage carries human-decision gates.** Where an aesthetic, layout or
narrative decision is not already settled by the contracts, the deliverable
is a precise design question plus the scene and state hooks — never a
guess. Finale logic stays tied to existing AP truth.

### S21 — Player settings / input / accessibility

Remappable controls, controller support where feasible, sensitivity,
invert, FOV, volumes, display settings, graphics settings matched to the
actual renderer, pause behaviour, subtitles, colour-independent cues,
scalable UI, safe defaults.

**Preferences persist separately from campaign truth and never enter the
AP/campaign save.** Rebinding cannot break a mandatory action.

### S22 — Packaging / first-run / provider UX

Godot export configuration, bridge/runtime packaging strategy, version
display, first-run dependency and configuration UX, provider selection and
fallback, API-key handling without committing secrets, provider errors,
save folder, logs and crash diagnostics, server/slot/password entry,
reconnect UX.

Target: substantially reduce "open three terminals and know the repo".
**No third-party assets bundled without an explicit licensing decision.**

### S23 — Release hardening / content gates

Measurable gates: clean-checkout build, CI green, full regression,
dual-Archipepsi proof, save migration and recovery, disconnect/reconnect,
provider failure, performance budgets, registry validation, missing-asset
fallback, packaging smoke, licence/attribution inventory, crash capture,
human-playtest checklist.

Plus an explicit list of **work automation cannot complete** — final
models, animations, viewmodels, environment and theme kits, props,
materials, VFX, audio, landmarks, polish, and human balance and feel
evaluation. Those are production tasks, not gaps to be filled
procedurally.

## Stopping rules

Stop only for: a human aesthetic/narrative/design decision the contracts
do not settle; final authored art that does not exist with no independent
code-side work left; an architecture decision that would materially alter
existing invariants; or a genuine blocker.

**If a stage is blocked on missing art but later infrastructure is
independent, record the art gate and continue with the independent work.**
S21 and S22 exist in the dependency graph partly for this reason.

Not to be done: inventing final art, turning Epsilon into an asset
generator, replacing authored-content requirements with more elaborate
procedural art, implementing `challenge_marker` semantics without a
decision, starting deployables, weakening AP/save/fold/base-kit
invariants, refactoring for aesthetics, or changing working semantics
without a demonstrated reason.
