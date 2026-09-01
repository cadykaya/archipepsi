# Room Architecture Study — a library Epsilon composes

**Status: STUDY ONLY. Nothing here is implemented, approved, or scheduled.**
Every recommendation needs its own owner approval per the repo's per-slice
law. This document changes no Production code, ships no assets, and starts
no batch.

Audited heads (verified in-repo, 2026-09-01):

| Branch | Head | Note |
|---|---|---|
| Production `claude/archipepsi-echoes-continuation-b1adno` | `552469d` | one past the `2699805` room-grammar commit named in the brief |
| Art `claude/archipepsi-art` | `25dc623` | one past the `e26ee48` named in the brief |

Method: six parallel deep-read audits of both branches (schema, builders,
composition/capabilities, F3, design history, environmental objects),
followed by three steelmanned architecture models, an adversarial red
team, a contract-drafting pass, three worked room designs, and two
independent judges. Findings are reconciled here, not concatenated.
Every load-bearing claim below was verified against source; key
file:line references are retained.

Throughout, claims are labeled:

- **PRESENT** — verified in the repository today.
- **PROPOSED** — what this study recommends building (unapproved).
- **FUTURE** — what may exist later, only after named validation lands.

---

## 0. The answer

**Yes — with one large correction to the framing.**

Archipepsi should move toward a library of deliberately designed spaces
that Epsilon composes. But this is not a new direction that needs
deciding — it is the repository's *already-recorded* direction, about
70% built and 0% loaded:

- Owner decision **D1** (2026-08-28) already rules: *"Epsilon chooses
  spatial and design INTENT. Authored content owns exact physical
  geometry. Godot validates physical truth."* — and explicitly resolves
  Q1 as "a hybrid of options A and C" (`design-packet-v0.9/OWNER_DECISIONS.md:12-54`,
  `OPEN_QUESTIONS.md:17-24`).
- **AUTHORED_CONTENT.md** (normative) already lists "Authored room
  shells and room seeds," "Reusable room connectors," "Authored
  encounter templates," and "Authored traversal motifs" as human-authored
  vocabulary, and records `chamber_builders.gd` as *debt*: "Builds room
  shells (level 3) procedurally from primitives. Should become
  *selection* among authored shells."
- The **entire authored-shell runtime path is implemented and empty**:
  `ContentEntry(category="room_shell")`, `shells.py` catalog,
  `validate_zone` shell checks, `ShellValidator`, `ConnectorGrammar`,
  `_from_authored_scene` — with `shell_catalog() == {}` pinned by a test
  that instructs future editors to flip it when shells land
  (`test_shell_catalog.py:75-86`).

So the real question is not *whether* but *what shape and in what
order*. The study's answer, defended in §3:

> **The room grammar is the contract language. Authored shells and
> authored modules are two more producers speaking it, next to the
> generator. Load the library dimensionless-rooms-first, at a bounded
> per-zone dose, with the procedural continuous-dimension system alive
> forever underneath.**

And one honest warning the owner should hear before spending on rooms:
**a shell library fixes "23 of 23 rooms are rectangles." It does not fix
"it does nothing and it's not fun."** The consequence half of the misery
verdict is blocked on the reward/container vocabulary, the small
machinery system, and topology — not on geometry. The library is the
*enabler* of those slices (it gives crates and machinery designed places
to matter); it is not their substitute. Section 2.4 quantifies this.

---

## 1. Verified current reality (PRESENT)

### 1.1 What a room can say today

Exactly 5 chamber kinds (`zone.py:519-525`), whose complete spatial
vocabulary is:

| Kind | Spatial fields |
|---|---|
| `corridor` | length 6–30, width 4–10 (height hardcoded 3.6, raised for features) |
| `arena` | width 10–28, depth 10–28, wall_height 4–8, **elevation: ElevationBand \| None** |
| `platform_path` | segment_count 3–8, gap_size ≤ 2.6 jointly bounded by `max_safe_gap(vertical_step)` |
| `tower` | floors 2–5 — **no spatial fields at all** |
| `treasure_room` | **none** |

ROOM GRAMMAR v0 landed at `2699805`: one optional `ElevationBand` per
arena (`gallery|pit`, rise 1.0–4.0, coverage 0.2–0.55, side, access —
though `access:"stair"` is dead vocabulary: the builder always ramps),
HEADROOM = 2.4 m validated at parse, ramp run = 3× rise so base movement
always reaches the deck. Everything else in
`docs/proposals/ROOM_FIRST_GAMEPLAY.md` (L/T/cross footprints, 1–3 bands
in any room, machinery, blocks, crate loot) is **proposal-only** by its
own status line.

### 1.2 Two unrelated things are both called "socket"

1. **Builder runtime sockets** (GDScript dicts, ROOM GRAMMAR v0):
   `access`, `reserved` (with extent), `enemy_high`, `cover`,
   `reactive`, and `stand` (per built surface, from `552469d`). Emitted
   only by the arena and platform_path builders; vouched by construction;
   consumed by `Activities`, `_build_environment`, enemy placement,
   `_room_occupancy`. `ChamberBuilders.solid_boxes` (furniture < 6.0 m
   per floor axis) is the single derivation of solidity.
2. **Registry `Socket`s** (Python schema, dormant): kinds
   `doorway/corridor_end/affordance/spawn/objective/secret/vista/presentation`
   with name/position/yaw/width/height; `ConnectorGrammar` joins
   doorway↔corridor_end at ≥ 1.2×2.0 m passability; `ShellValidator`
   measures declared sockets/traversal against Marker3Ds at 0.15 m
   tolerance.

Any room-architecture design must not conflate them. §9 merges them.

### 1.3 The authored path is strictly poorer than the procedural path

`_from_authored_scene` (`content_instantiator.gd:390-403`) derives
everything from one fixed `size` per registry entry and **returns no
`sockets` key**. An authored room today gets no cover, no barrels, no
reserved regions, no stand surfaces — Activities flat-solve against
bounds, the exact bug class `552469d` closed for platform_path. This,
plus fixed size replacing per-chamber dimensions, is the precise
mechanism behind the recorded F3 deferral ("integrating F3 now would
make rooms MORE uniform").

### 1.4 Zone topology, movement law, capability law

- A Zone is a **flat ordered tuple of chambers**; adjacency is a
  Godot-side cursor+yaw walk with alternating 90° corners, connectors
  5×4 m, and an AABB overlap guard (> 0.5 m³ intersection rejected)
  proven safe by never revisiting. One walkable chain; the only
  branches are cosmetic bends. v0.10 §7's ladder (path → dead-end spurs
  → hub-and-spoke → shortcuts → open graph) is paper, and its named hard
  engineering is changing "never revisit" to "revisit only at a declared
  join."
- Movement law (all derived, never typed): MAX_VERTICAL_STEP 1.0,
  JUMP_APEX 1.333, SAFE_BASE_JUMP_GAP 2.6 flat / `max_safe_gap(1.0)` =
  2.0, HEADROOM 2.4, BRUTE_LANE 2.6, door 2.4×3.2, min passable
  1.2×2.0, player capsule r 0.4 h 1.8, FALL_KILL_Y −30, ramp run 3×
  rise. **No navmesh exists** — enemies steer directly, so the usual
  "authored meshes break the navmesh" objection is void here; what
  authored meshes actually threaten is `solid_boxes`, mesh==collider,
  and the flat-rectangle assumptions in the placement solvers.
- Capability law: semantic families (`ranged_hit` baseline,
  `cross_long_gap`, `grapple`, `blink`), the four-case guarantee ladder
  (baseline / owned / established-in-zone [no producer yet] / forge
  [unreachable]), **logical solvability** (owner 2026-08-29) — declared
  AP-visible capability gates on mandatory routes are *intended* later
  via Architecture D (proven feasible, not authorized). Affordance
  features stay optional-only today. DPS/HP can never be logic.

### 1.5 Environmental verbs and their blockers

PRESENT with real verbs: `DestructibleCover` (cumulative, never a gate,
pays in space), `ReactiveBarrel` (blast 4.5 m / 34, hurts the player),
`BreakablePanel` (per-hit ≥ 12 capability gate on optional alcoves),
`BouncePad` (apex 5.33 m), `MovingPlatform`, water/wind/rail volumes,
`ActivityElement` in three trigger modes (touch/shot/stand) under
`ActivityRuntime`. **Absent**: machinery/room-state (ROOM_FIRST §11,
"new but modest"), movable blocks (v9 physics), and any loot — the
local-reward catalog is a closed 6-kind list of notes, Coins are an
Archipelago item nothing local may mint, and `DestructibleCover`
deliberately drops nothing "rather than answering the loot question
badly."

### 1.6 F3 inventory, exactly

19 owner-PASSED shells (batches 015–019): 4 corridors, 4 arenas, 3
platform paths, 3 towers, 3 treasure rooms, 2 corners. Ground truth
from parsing the GLBs: **each is a single mesh node with zero markers,
zero metadata, zero collision**; all design data lives in bespoke
sidecar manifests no validator on either branch reads, with a
documented axis-order trap (art `size` = [outer_width, LENGTH,
outer_height]; `interior` = [width, HEIGHT, length]; Godot Vector3 =
[width, height, depth] — feeding `size` verbatim sets room_height to the
room's *length*). Decisive fact for §16: the shells were **generated by
Blender Python scripts reading the engine's own constants**
(`tools/blender/build_shells.py`, `routecheck` verifying every jump
against `max_safe_gap`), so every surface and anchor the new contract
needs is already a variable in the script that placed it.

### 1.7 The economy this must serve

Playtest 2.5, measured: a 921-point Zone produced **4.6 minutes** of
play against a 40-minute target, 32 seconds of combat; **90.3% of
content sits in Check rooms**; the 26×24 set-piece produced 20.3
seconds. Recorded priority: *"break the relationship between Check count
and player activity."* Campaign scale is frozen at ~15 rooms and 15
Checks per 1000-point Zone, 30 Zones (goal at ~24). The art lane is
intentionally idle awaiting owner briefs; owner review is the measured
scarcest resource (batches 023–030 sat PENDING for weeks; PASS is the
owner's word alone).

### 1.8 Settled decisions this study must not (and does not) re-litigate

D1 (intent/geometry/truth split; size classes small/medium/large; no
generic stretching; procedural fallback never deleted); "grammar first,
then authored rooms become an ingredient" (F3 verdict, recorded three
times); the socket contract ("the builder owns physical truth";
declared, never inferred); NO REQUIREMENT BEFORE GUARANTEE; logical
solvability; Coins-are-AP; the authored-content boundary (developers
author the alphabet, Godot enforces the grammar, Epsilon writes
sentences; five authoring levels); the Tier-7 expansion rule (a new
shell variant must create a meaningfully different route/combat
problem/vertical relationship — never count); enclosed-by-default;
hazard-orange semantics.

---

## 2. Critique of the owner idea

### 2.1 What is right (and already ratified)

The core intuition — *"give Epsilon a box of genuinely good level-design
pieces to compose rather than asking it to rediscover level design from
rectangles"* — survives contact with the project **because the project
already had it**: it is D1 plus AUTHORED_CONTENT.md's five-level ladder,
and the measured evidence supports it emphatically. Under full
continuous freedom the generator produced 23/23 rectangles and eight
corridors all exactly 7.9 m wide: continuous dimensions were *unrealized
entropy*, not authorship. The two-dimensional idea (spatial shell ×
gameplay package) is also correct in kind — it is the only structure
that avoids authoring N×M rooms, and it matches how the repo already
separates geometry (builder) from population (composer).

### 2.2 What breaks (red-team verdicts, reconciled)

| Piece of the idea | Verdict | Why |
|---|---|---|
| MICRO + MASSIVE size families | **DROP** | Re-litigates D1's `small/medium/large` Literal (in code, two places). MICRO can't carry gameplay: FEATURE_MIN_WIDTH is 6.7–7.9 m, BRUTE_LANE 2.6 must survive beside content — a sub-7 m room hosts no feature, no brute, almost no package; the micro use case (treasure closet) already exists as three 8×8 shells. MASSIVE exceeds the arena cap (28), has no boss system to serve, and direct-steering enemies crossing 40 m open floors read broken — a massive room is *more* of the measured failure (the 26×24 room produced 20.3 s of play). |
| ~13 spatial archetypes as mechanical kinds | **COLLAPSE to intent tags** | The schema has 5 chamber kinds; each mechanically new kind costs a pydantic model + builder + audits + a **procedural twin** (D1: fallback never deleted; keyless players play fallback zones). Most listed archetypes are the same thing at different sizes or decorations of rect (dogleg = corner; bridge-over-void = platform_path; perimeter gallery = arena+band). Honest grid: ~6 buildable families × 3 sizes ≈ the 19 shells that already exist, unintegrated. |
| 65–130-cell shell grid | **RESHAPE: demand-driven** | 130 shells ≈ 33 owner-review batches ≈ 7× the entire shell output to date, spent on the axis a player sees ~1.4–3.5×/campaign, while 5 packages would be seen ~36×/campaign — inverted against the measured deficit. Author shells when a zone design wants them; convert the existing 19 first. |
| Portable packages with contract-only compatibility | **RESHAPE** | A package that satisfies socket counts can still play badly: sockets carry no orientation; sightline/approach/readability facts live nowhere ("2 enemy_high + 4 cover" is satisfied both by pillars-with-no-firing-lines and by a rim firing squad over a coverless pit). Fix (§10): parameterized recipes, pair demands *measured* at dock time, and 2–3 measured room scalars — never a curated N×M matrix. |
| PUZZLE and BOSS packages now | **BLOCKED on verbs, not architecture** | Machinery, blocks, loot, boss behaviors don't exist. A PUZZLE package today re-skins the four activity families the owner already judged. Ship COMBAT / TRAVERSAL / EXPLORATION recipes first. |
| Multi-volume occupancy envelopes | **DEFER; derive, never type** | The current single-AABB + never-revisit guard is sound for the next two topology rungs. Tight concave envelopes create legal-but-unintended contacts and only buy denser packing, which nothing measured asks for. If envelope metadata ever exists it is derived by tooling from the built scene. |
| A rich connector taxonomy | **SHRINK to interface minima** | See §8. Width is a number, not a kind; vertical deltas stay inside shells; one-way joins wait for the shortcuts slice. |
| Authored shells without a physical import audit | **BLOCKS** | Baked gaps escape pydantic (Q1's own warning); the sealed-basement bug class returns per-asset; author-*claimed* sockets are not builder-*vouched* sockets. The audit in §6.4 is the non-negotiable price of admission — and cheaper than one batch of shells. |

### 2.3 The failure the idea is actually closest to

Asked "rooms that look different but play identical" vs "play different
but feel like tiles" — the sketched architecture is structurally closer
to **look-different-play-identical**: its authored spend concentrates on
geometry (the axis seen ~2×) while play flows through a handful of
package patterns over today's thin verb set (the axis seen ~36×). That
is the exact post-conversion failure already diagnosed ("more stuff to
do, but it does nothing"). The corrective is baked into every
recommendation below: packages are parameterized, socket sheets are
over-provisioned and seed-filled, and verb-slices (machinery, container)
outrank shell-count growth.

### 2.4 What the idea misses

The misery verdict has two halves. *"The rooms are miserable"* (shape) —
the library fixes this. *"It does nothing"* (consequence) — the library
cannot touch this: crate contents are blocked on the closed local-reward
catalog, machinery is an unbuilt small system, and the 4.6-vs-40-minute
gap is an economy/conversion problem. The correct sell to the owner:
the library gives the crate a *designed place to matter*; the crate
still needs the reward decision (owner decision #2, §20).

---

## 3. Architecture comparison

Three models were steelmanned independently, red-teamed, and scored by
two independent judges (one weighing level design and player experience,
one weighing engineering reality and consistency with recorded
decisions).

### Model A — whole authored shells

Shells become the Check-room/landmark vocabulary (~7–8 of 15 rooms per
zone); procedural stays connective tissue. Strongest honest case:
level-design quality is unmatchable (owner-walked rooms, `cover_reach`
0.000/0.338/0.521/0.786 as a designed family discriminator; no generator
here will produce `shell_arena_balcony`'s three-sided 3.2 m balcony);
the runtime path is fully built; a finite library is exhaustively
QA-walkable, and a shell bug is fixed once forever where a builder bug
re-manifests in every generated room. Genuine breaking points: at
repo-real scale (24–30 zones, ~360–450 rooms) every arena shell is seen
12–15 times against a Tier-7 rule that forbids padding the library;
grammar evolution costs O(N shells) instead of O(1 builder); interior
occupancy of merged > 6 m meshes is invisible to `solid_boxes`, so the
embedded-element bug class returns unless occupancy is declared and
measured; and its 7–8-shells-per-zone dose inverts the recorded
"grammar first, then authored rooms become an *ingredient*" ordering.

### Model B — modular spatial kits

The generator keeps owning shape and truth with continuous dimensions;
authored L1–L2 modules (wall bays, gallery deck segments, ramp/stair
kits, doorway frames) replace raw `_box`/`_wedge` primitives in slot
frames quantized from the derivations the builder already owns
(`_perimeter`, `band_rect`). Strongest case: best collision story of
the three (frames disjoint by construction; sub-6 m pieces stay visible
to `solid_boxes`; the 81-position seal suite runs unchanged), and it is
D1's "authored repeatable spans" carve-out made concrete. Decisive
weakness, conceded by its own advocate: **the repo already ran this
experiment.** Today's rooms are composed of many pieces (boxes, wedges,
greebles, 7–11 props per arena) and they are miserable, because "the
flatness is the generator faithfully building everything the schema can
say." Prettier fixed pieces change nothing about what the schema can
say. Slice 1 delivers zero new words to Epsilon and zero movement on
any measured problem.

### Model C — hybrid: the grammar as the shared contract

The room grammar (surfaces, sockets, connections, occupancy) is the one
contract language with three producers — the generator (fluent), authored
modules (phrases), authored shells (fixed sentences) — and one
validator/consumer stack that cannot tell producers apart. Shells land
where designed space matters most *and* fixed size costs least;
grammar+modules carry the bulk; procedural covers everything, forever.
Its unique discriminator: **`tower`, `treasure_room`, and the corner
pieces have no continuous dimensions to lose** (`zone.py:504-516`;
corners never touch the Zone schema), so the entire F3 objection is
arithmetically void for 8 of the 19 owner-PASSED shells — no other model
has a first slice this cheap, this safe, or this high-yield, because the
procedural tower (the schema's nominally most vertical, spatially least
expressible room) is the exact room it replaces.

### Judged scores

Both judges, independently, on ten criteria (5 best):

| Criterion | A | B | C |
|---|---|---|---|
| Level-design quality | 4–5 | 2 | 4 |
| Variety | 2–3 | 2–3 | 4 |
| Implementation cost | 3 | 2–3 | 4 |
| Collision safety | 4 | 5 | 4 |
| Epsilon authorship | 2–3 | 1–2 | 4 |
| Replayability | 3 | 2 | 4 |
| Art workload | 2 | 2–3 | 4 |
| Validation difficulty | 3 | 4 | 4 |
| Extensibility | 3 | 4 | 5 |
| Fit with recorded decisions | 3 | 3–4 | 5 |
| **Total** | **30–31** | **28–31** | **42** |

### Recommendation (PROPOSED)

**Model C, executed with Model A's tooling, holding Model B's mechanisms
in reserve.** Why it wins, stated against the alternatives:

1. **It is the recorded trajectory, finished.** D1 is literally "a
   hybrid of options A and C"; the F3 verdict is C's phase ordering; the
   five authoring levels are its org chart. A needs a new owner decision
   to shell half the zone; B promotes a "may exist later where safe"
   clause into a strategy. C re-litigates nothing.
2. **Its first slice is uniquely lossless and cheap.** ~2–3 weeks,
   zero new art: socket parity + the 8 dimensionless shells
   (3 towers, 3 treasure, 2 corners) + the landmark arena. Where A's
   first slice must immediately pay the arena-family gap (4 exist, 7–8
   needed) and per-shell interior-occupancy authoring, and B's first
   slice buys texture.
3. **It puts the loss function where it varies.** Corridors lose real
   expressiveness under fixed shells (6–30 m per chamber vs fixed
   14–20 m); towers lose nothing. No uniform-dose model can be right
   when the loss varies this much by chamber type; C is the only model
   whose dose follows the loss function.
4. **It preserves the kill switch and the fallback.** Every phase is
   individually revertible via the `review:"pending"` flip (proven live
   on the projectiles at `5f1435f`), and refusal always degrades to the
   never-deleted procedural builder.

**Borrowed from A** (used verbatim in the phases): the
manifest-converter with the axis-order trap handled; the picker with
teeth (deterministic size_class+intent scoring, never-twice-per-zone,
≥1-zone reuse gap — without it `intent` joins `access:"stair"` as dead
vocabulary); `validate_zone` rules (`shell_id` ⇒ `elevation is None`;
FEATURE_MIN_WIDTH ≤ named shell's interior width); ShellValidator
verdict caching; measured-AABB-vs-declared-size check; mirror variants
as cheap catalog stretch; over-provisioned socket sheets with seeded
subset fill (§6.3). **Borrowed from B**: the **sub-6 m rule as law**
for any authored piece smaller than a room (anything larger declares
`no_build`/reserved volumes — preserving `solid_boxes` as the single
derivation); `box_hits` re-vouching of every declared socket claim
against live occupancy; the `repeat_a`/`repeat_b` span grammar held in
reserve as *the* future corridor slice (the one place fixed shells
genuinely lose); landing producer-side changes invisible to Epsilon
first so every slice is A/B-able against the zone digest.

**One reconciled disagreement worth recording**: Model A proposed
satisfying ShellValidator by synthesizing Marker3Ds from the manifest
into a wrapper scene. The engineering judge caught this as circular
(markers generated *from* the manifest, measured *against* the manifest,
prove only that the converter copied numbers). The contracts pass had
independently reached the same conclusion from the other side (the
sealed-basement pit passed its own marker-style test). Resolution,
adopted in §6.4: **geometric validation replaces marker validation as
the gate** — raycast/sweep the instantiated scene at the declared
coordinates. Strictly stronger truth, and it removes any need to
re-export the 19 GLBs.

---

## 4. Size model (PROPOSED)

**Keep `small / medium / large`. Do not add MICRO or MASSIVE.** (D1
decided the vocabulary; §2.2 gives the mechanical reasons the extremes
carry no gameplay.) What changes is what size *means*: a size class is
a **capacity certificate**, not a dimension band. Defining sizes by
what they can host is what makes size "a vocabulary, not a tax":

| Class | Rough envelope (not locked) | Certified capacity |
|---|---|---|
| `small` | ≲ 10 m major axis | 1 encounter beat OR 1 reward moment; no brute; no affordance feature; ≤ 1 elevation change. The treasure trio and short connectives live here. |
| `medium` | ~10–20 m | 1 full encounter (mixed archetypes incl. brute lane) or 1 traversal/puzzle setup; 1–2 elevated surfaces; ≥ 2 route choices; can host features ≥ its width per FEATURE_MIN_WIDTH. Most Check rooms. |
| `large` | ~20–28 m (arena schema cap) | Multi-group encounter, ≥ 2 independent elevated circuits, landmark/boss certificate eligible; composition law's ≥1.8× landmark slot. ≤ 1 per zone by rule. |

Micro *spaces* exist as **modules inside rooms** (alcoves, pockets,
niches — level 2 content), not as rooms. If a boss arena ever wants to
exceed the arena cap, that is one `large`-family authored variant plus a
schema-bound change argued on its own merits — not a fifth class. Do
not lock exact metre bands until the prototype's playtest; the capacity
column, not the metre column, is the contract.

---

## 5. Spatial archetype model (PROPOSED)

Two-layer vocabulary, replacing the ~13-item list:

**Layer 1 — buildable families** (mechanical kinds; each has or gets a
procedural twin; adding one is a real engineering event):
the existing five — `corridor`, `arena`, `platform_path`, `tower`,
`treasure_room` — plus, when the v0.10 spur/hub slices are approved,
**`junction`** (a room with 3–5 joining sockets). Junction is the one
genuinely missing mechanical kind: today no room has more than two
connectors, which is *the* structural reason every Zone is a hallway.
The schema's `Socket` model already permits ≥ 3 joining sockets; only
ZoneBuilder consumes at most two — one approved slice away.

**Layer 2 — intent tags** (closed, Dev-owned list in `semantic_tags`;
advisory for selection, never a mechanical contract). Drawn from what
the 19 shells already differentiate, v1:
`vertical, long_sightline, short_sightline, cover_rich, open_floor,
pit, gallery, split, loop, tight, hazard_drop, turn`.

Mapping the brief's list: L/dogleg → an arena/corridor shell whose exit
socket carries yaw ±90 (`turn`); loop/split-level → `loop`+`vertical`
tags on a medium arena shell (worked example, §11 Room B);
bridge-over-void → platform_path family; central island / perimeter
gallery → `open_floor`/`gallery` arenas; shaft → tower family;
irregular industrial → `large`+`split` arena. Every distinction that
matters to *composition* is a tag; every distinction that matters to
*code* is a family. This is what keeps the taxonomy from forcing
7–8 new procedural twin builders nobody budgeted.

---

## 6. Room shell / module contract (PROPOSED)

Docked entirely onto existing models (`ContentEntry`, `Socket`,
`Volume`, `TraversalSegment`); every added field names its consumer; no
parallel vocabularies. Summary of the drafted contract (full field-level
change list in §6.5):

### 6.1 The shell entry

A room shell is one `ContentEntry(category="room_shell")` with:

- `size` (one AABB — see §7), `size_class` (**required** for shells),
  exactly one chamber-family tag + intent tags in `semantic_tags`,
  `cost`, `variants`/`fallback` chaining to the `shell_*_proc` entries.
- **Joining sockets**: exactly one named `entry` at (0, sill, 0) yaw
  180, ≥ 1 other; the one named `exit` is the chain exit. A corner is
  simply a shell whose exit socket has yaw ±90 (no `turn` field, no
  corner category); the build contract gains a derived `exit_yaw` that
  ZoneBuilder consumes — the one small ZoneBuilder change this study
  asks for, and the same one the art corner shells always assumed.
- **`surfaces` — the one new model, and the heart of the contract**:
  `Surface {name, y, center(x,z), extent(x,z)}`, ≥ 1 required, one must
  contain the entry socket's foot. At instantiation each Surface becomes
  a `{"kind":"stand", position, extent}` runtime dict — **byte-for-byte
  the shape `Activities._best_surface`, `_build_environment`, and
  `_room_occupancy` already consume**, so authored rooms reach parity
  with procedural rooms with zero consumer changes. Eligibility stays
  by measurement (extent − element ≥ BRUTE_LANE), never by name.
- **Gameplay sockets** (§9's merged kinds) with a new `surface_id`
  field tying each to a Surface.
- **Volumes**: `player_entry`, `enemy_spawn` (y > 0.5 ⇒ offered as
  `enemy_high`), `objective`, and `no_build` → the authored equivalent
  of `reserved` (identical semantics: declared AABBs content must
  avoid). **Sub-6 m rule (from Model B), now law**: any authored piece
  smaller than a room stays under `ROOM_SCALE_SOLID` = 6.0 per floor
  axis so `solid_boxes` sees it; anything larger must declare its
  interior masses as `no_build`.
- **TraversalSegments**: every mandatory route declared and bounded by
  `max_safe_gap` at parse (existing model); optional routes may exceed
  and may (later, with Architecture D) carry `requires`.
- `requires_capabilities` gains its first consumer: the catalog filters
  shells whose optional content wants capabilities the campaign cannot
  guarantee.
- **`descends: float`** — one new field: metres of legal open shaft
  below y=0 (the platform-path kill-shaft exception, declared instead of
  special-cased; doubles as the IR19 open-shaft flag).

### 6.2 Modules

Authored L1–L2 pieces enter through the **existing** `module` /
`fixture` / `cluster` categories, unchanged. Two reserved mechanisms,
held for their own slices: `repeat_a`/`repeat_b` joining sockets for
D1's repeatable spans (the corridor lane — the one family where fixed
shells measurably lose), and per-piece gameplay-socket claims re-vouched
by `box_hits` at placement. Neither is in the prototype.

### 6.3 Interior variation (the anti-tiles mechanism — mandatory, not garnish)

A shell is not viable as a *place* seen 6–10 times per campaign unless:
(1) it **over-provisions sockets ≥ 2× what is ever filled** and the
instantiator fills a seeded, budget-sized subset (C(8,4) = 70 cover
layouts before enemy composition even varies — riding the existing "a
socket is an offer, not an order" rule unchanged); (2) the objective
seed-picks among ≥ 2 objective volumes so the route problem moves; (3)
Epsilon's population channel stays fully live (enemy mix, activities,
features, flavor); (4) S19 theme rematerialing lands so one mesh has six
visual identities (**prerequisite for any shell reuse across zones**;
explicitly Not Wired Yet); (5) mirror variants where asymmetry permits.
These mechanisms *are* the model; without them the honest exposure
budget of a fixed shell is ~2–3 plays, which is the arithmetic that
correctly deferred F3.

### 6.4 What must be measured (geometric validation replaces markers)

ShellValidator's Marker3D gate is replaced by raycast/sweep checks at
the **declared coordinates** against the instantiated scene (markers
stay as an optional extra layer). Per shell, at import/approval:

1. **Surface support + headroom**: grid-sample every Surface — ray down
   hits within 0.15 m of declared y; 2.4 m clear above.
2. **Pit-is-a-hole / first-hit-from-above**: the declared surface must
   be reachable from above (the general form of the sealed-basement
   lesson).
3. **Socket-on-surface**: every gameplay socket's foot lands on its
   declared surface.
4. **Doorway-is-a-hole**: a player-capsule sweep through every joining
   socket's rect must pass — mesh==collider means the hole must exist in
   both.
5. **Seal check**: the 81-position seal probe generalized to authored
   shells; rays may exit only through joining sockets, `descends > 0`
   the declared exception.
6. **Size honesty**: measured mesh AABB equals declared `size` within
   0.15 m/axis, nothing outside derived bounds (closes the axis-order
   trap permanently; implements a promise `content.py` makes and nothing
   keeps).
7. **Traversal truth**: support at declared segment endpoints; a
   declared `gap` must actually be a gap; `max_safe_gap` on measured
   spans. Plus mandatory-route capsule sweep — **the walkability prover
   authored shells are the first content to need**.

This audit is the red team's BLOCKS-level precondition, it reuses probe
patterns the zone audit already has, and it is cheaper than one batch of
shells.

### 6.5 Complete change list

Python `content.py`: `Surface` model + `ContentEntry.surfaces`;
`ContentEntry.descends`; `Socket.surface_id`; `Socket.kind` Literal
shrink (§9); room_shell rules (entry-socket convention, ≥ 1 surface,
size_class required, sockets on the AABB face, exactly one family tag).
`shells.py`: capability filter. `zone.py`: `ChamberBase.package_id`
(§10); `validate_zone` size_class cross-check + package checks + the two
borrowed rules. New `packages.py` (§10). Godot: ShellValidator checks
1–7 above; `_from_authored_scene` emits stand/cover/reactive/enemy_high
dicts + no_build→reserved + `exit_yaw`; ZoneBuilder consumes exit_yaw;
`content_registry.gd` mirrors every change same-commit (dual-language
law). Art tooling: build-script manifest emitter; export unblock.
**Deliberately NOT added** (each killed with a named reason in the
drafting pass): occupancy volumes, footprint polygons, wide/vertical/
one-way connector kinds, socket extents, declared LOS pairs,
secret/vista/presentation/spawn/objective socket kinds, machinery/
container/hazard/reward_pocket/traversal_anchor/activity_element
socket kinds (each waits for its system), TraversalSegment.requires
(waits for Architecture D), shell-side package lists, per-surface
nav/material data.

---

## 7. Collision / occupancy contract (PROPOSED)

- **One conservative AABB per room stays the chain law.** The existing
  `_world_aabb` guard (> 0.5 m³ intersection rejected) is sound for
  today's chain and for the next two topology rungs (dead-end spurs,
  hub-and-spoke), which still place each room once and never revisit.
- **Wall thickness is inside `size`; every joining socket lies on an
  AABB face** (validated arithmetic). Composition butts socket planes
  coincident — zero-volume contact, so flush joins pass the existing
  guard, and no two rooms ever share a wall (each brings its own). This
  also converts the latent `shell_corridor_proc` manifest inconsistency
  (exit socket beyond its own size) from a landmine into a refused
  manifest.
- **`descends`** extends bounds downward for declared shafts; the
  bounds union keeps feeding the blink-I14 world boundary and
  chamber-entry detection unchanged.
- An L-shaped shell's bounding box over-claims its notch —
  **accepted**: pay a conservative 6×8 m of dead reservation (Room A,
  §11) rather than build concave-envelope machinery nothing needs yet.
- **FUTURE**: multi-volume occupancy arrives only with the
  loops/shortcuts slice, as "contact allowed only on a declared join
  plane" — a guard change riding the "revisit only at a declared join"
  proof v0.10 §7 already names as the actual engineering. Any envelope
  metadata is derived by an export tool from the built scene, never
  typed by an author (the derived-constants rule applied to geometry).

---

## 8. Connector contract (PROPOSED)

**Vocabulary: exactly `{doorway, corridor_end}`. Add nothing now.**

- *Wide* is not a kind — `Socket.width` is already continuous; a 6 m
  industrial opening is a doorway with width 6, and passage math
  (per-axis min, ≥ 1.2×2.0) is unchanged. Scale telegraphing (the red
  team's legitimate sameness complaint) is answered by shells owning
  larger openings and themed L1 door-frame modules dressing the standard
  absence — silhouette, not new kinds.
- *Vertical* is not a kind — a raised sill is socket position.y (tower
  summits already exit at +15 m via exit_offset.y); climbing happens
  inside shells as TraversalSegments.
- *One-way (drop)* is **killed for v1**: it breaks the never-revisit
  guarantee in the worst direction (softlock surface until the re-entry
  design lands). When the shortcuts slice is approved it arrives as
  `TraversalSegment kind="drop"` inside a shell — still not a socket
  kind.
- **Mismatch absorption**: tolerance first (passage-min rule; a
  2.4-to-3.2 join leaves a cosmetic reveal, accepted), the existing
  `connector` category second (push-forward-with-connectors is already
  the mechanism, capped by composition law at 3 consecutive), stretching
  **never** (D1). No adapter library: a 15 m elevation delta between
  rooms would need a 45 m ramp run at the 3:1 law — longer than the
  longest legal corridor — so vertical deltas stay inside shells, where
  the art shells already keep them.
- Hub/spur topology needs **more sockets per shell** (§5's junction
  family), not more socket kinds.

---

## 9. Socket contract (PROPOSED)

One merged vocabulary. Rule applied: every kind must name a consumer
that exists or is one approved slice away; kill the rest.

**`Socket.kind` Literal, v1 (6):**
`doorway, corridor_end, cover, reactive, enemy_high, affordance`
— plus the `Surface` model (§6.1) and `Volume` kinds
(`player_entry, enemy_spawn, objective, no_build`).

| Kind | Consumer today | Disposition |
|---|---|---|
| doorway / corridor_end | ZoneBuilder chaining, ConnectorGrammar, `_exit_offset` | KEEP |
| cover / reactive | `_build_environment` → DestructibleCover / ReactiveBarrel (live) | KEEP (runtime kinds promoted to schema) |
| enemy_high | ranged-take-high spawn loop (live) | KEEP (promoted) |
| affordance | AffordanceFeatures in authored shells; 4 F3 corridors already author anchors | KEEP |
| stand | `Activities._best_surface` | **Becomes the `Surface` model**, not a socket |
| reserved | `_room_occupancy` | **Becomes `Volume kind="no_build"`** (identical semantics) |
| access | audit drivers only | Builder-internal; authored equivalent is a mandatory TraversalSegment |
| spawn / objective | none (Volumes own both) | KILL |
| secret / vista / presentation | none | KILL (secret returns with the secrets slice) |
| enemy_ground | `enemy_spawn` Volume owns it | not added |
| machinery, container, hazard, reward_pocket, traversal_anchor, activity_element | no runtime systems | **FUTURE** — each arrives with its system (machinery with ROOM_FIRST §11; container with the loot decision), not before |

Fields: existing (name, kind, position, yaw, width, height) +
`surface_id`. **No extent field** — placement claim sizes come from the
consumer classes (`DestructibleCover.SIZE` etc.), exactly as the live
code works; declaring extent would be a second source of truth.
**Relationships (line-of-sight pairs, distances) are deliberately not
socket fields**: a declared LOS is a claim that must be measured anyway,
so pair requirements live in packages (§10) and are measured by raycast
at dock time — one derivation, nothing stored to drift.

Both Literal changes land in `content.py` and `content_registry.gd` in
the same commit (verified safe against both committed registries;
"verifying one side of a two-sided contract is verifying nothing").

---

## 10. Gameplay package model (PROPOSED)

Purpose: make "what you do in this room" a portable, validated unit that
docks onto any room meeting its requirements — procedural or authored —
so play stops being a per-room accident of which builder emitted which
sockets.

### 10.1 Portable packages

Dev-authored Python data (new `packages.py`, catalog cloned from
`shells.py`; packages are logic, not scenes — they do not enter
ContentCategory):

```python
class SocketDemand(Strict):  kind: Literal["cover","reactive","enemy_high","affordance"]; min_count: int = 1
class SurfaceDemand(Strict): min_extent: tuple[float,float]; elevation: Literal["ground","raised","any"]; min_count: int = 1
class PairDemand(Strict):    a: ...; b: ...; min_distance; max_distance; line_of_sight: bool   # measured at dock, never declared
class GameplayPackage(Strict):
    id; display_name
    activities: tuple[ActivityPrimitive, ...]      # EXISTING model — packages emit primitives
    environment: tuple[SocketDemand, ...]
    surfaces: tuple[SurfaceDemand, ...]
    pairs: tuple[PairDemand, ...]                  # ≤ 4
    requires_capabilities: tuple[ActivityCapability, ...]   # existing guarantee ladder, verbatim
    cost: int
```

- Docking: `ChamberBase.package_id` (additive; package set ⇒ raw
  `activities` empty — the package brings them). Epsilon's request
  catalog gains `packages: {chamber_type: [ids]}` exactly like
  `room_shells`.
- **Compatibility is computed, never stored** — no shell ever names a
  package. Two phases, matching the existing structural/semantic/
  physical split: Python checks counts/extents/capabilities against
  declared surfaces+sockets (or a per-type emission-guarantee table for
  procedural rooms); Godot measures PairDemands (raycast at eye height,
  distances) at dock time, demoting to the package's no-pair layout on
  failure — elements never drop (existing law).
- **Packages are parameterized recipes, not sealed bundles** (the
  red-team's authorship correction): Epsilon supplies enemy mix within
  caps, activity params, intensity, reward routing. A sealed package
  would move *encounter composition* — Epsilon's contracted half — to
  authors; a parameterized one moves only the spatial pattern.
- **Room scalars close the plays-badly gap**: the import audit (§6.4)
  additionally measures 2–3 room-level scalars — `sightline_max`,
  `cover_reach`, `open_floor` (the numbers the art lane already used as
  its family discriminators) — derived, never typed. Packages may bound
  them ("COMBAT-ranged wants sightline_max ≥ 10"); Epsilon sees them as
  catalog metadata. This is O(N+M); a curated pair matrix (O(N×M)) is
  rejected as bespoke content by the back door.

### 10.2 Bespoke layouts

`PackageLayout {package_id, shell_id, elements: [{surface_id, at(x,z)}]}`
— authored metre-precise placements for a specific shell, bypassing the
solver. Legal because the author is a developer in a fixed shell's local
space (the "builder owns metres" rule guards *Epsilon*, which never sees
this table); validated by the same support-ray the `no_ground_under`
structural test already runs. Reserved for landmark/boss rooms; the
default is always the portable solver.

### 10.3 What ships when

COMBAT, TRAVERSAL, EXPLORATION recipes are near-term real (they compose
verbs that exist). **PUZZLE waits for machinery (ROOM_FIRST §11) and
BOSS waits for boss behaviors** — shipping them earlier would re-skin
the activity families the owner already judged. Packages do not fix
conversion; they give conversion a portable home.

---

## 11. Three concrete rooms — one space, several games (PROPOSED, worked examples)

Full designs (dimensions, every socket, every configuration) are the
working set behind this section; condensed here to what proves the
architecture. All three honor the movement law (mandatory routes:
steps ≤ 1.0, gaps ≤ 2.6/2.0, ramps 3:1, HEADROOM 2.4; doors 2.4×3.2 at
the entrance-at-origin convention). Socket kinds beyond v1
(`machinery`, `container`, `reward`) are used as **FUTURE** vocabulary
and flagged; every puzzle has a no-machinery fallback reading.

### Room A — `shell_elbow_m` (MEDIUM / L, combat-capable, exit turns +90°)

14×14 bounding minus a 6×8 solid SE block; wall height 6.0; entrance
(0,0,0)+Z, exit east wall (9,0,11)+X — the room is itself a turn piece.

```
Z=14 +--------------------------+----D2 exit -> +X
     | LEG 2      [perch y3.0]  |
     |  pocket>   ==platform==  |     # = solid block
Z=8  +--------------+ [deck y2] |     == deck y2.0
     | LEG 1        |#######    |     /r = ramp (rise 2, run 6)
     |          /r  |#######    |
Z=0  +---D1---------+###########+
     X=-5          X=+3        X=+9
```

Surfaces: floor L-polygon; gallery deck y 2.0 (2.4×5.5, hugging the
block's west face, wrapping the inner corner — ground under it reserved,
underside 1.6 < HEADROOM); ramp (reserved volume); west perch y 3.0
(2.5×2.5 = MIN_PLATFORM_SIZE, **not base-kit reachable by construction**
— deck→perch is a 3.1 m gap at 1.0 rise > max_safe_gap(1.0)=2.0);
shuttered wall pocket. Plan-shape sightline: the block hides the exit
and its guard until you round the elbow — line-of-sight broken by
footprint, not props.

- **A-COMBAT "hold the elbow"**: melee ×2 in leg 1, ranged ×2 on the
  deck, brute at the blind corner. The survivable lane (west wall
  cover-hop) and the counter-lane (east ramp, the only way to silence
  the deck) are on opposite sides — a diagonal cross under plunging
  fire, with a reactive barrel at the ramp foot as the tactical answer
  and a free 2 m drop-flank off the deck's north lip behind the brute.
- **A-TRAVERSAL "the long way round"**: no enemies; timed run
  ramp → deck → moving-platform catch (travel 3.1 ≤ 3.6 cap) → perch;
  a missed catch costs a ~9 s re-loop, not a death. A grapple line over
  the elbow shortcuts the ramp for owners — optional, per capability
  law.
- **A-PUZZLE "three vantages"**: three shot-mode receivers (existing
  ActivityElement machinery), each visible from exactly one of the
  room's three mutually-blind positions (leg 1; leg 2 floor; deck edge)
  → shutter opens the pocket. The puzzle is a sightline census of the
  same geometry the combat config fights over. (Shutter = the one small
  §11 machinery system; fallback reading: pocket simply open.)

*Proves*: first non-rect footprint; exit-with-turn as a room property;
reserved-under-shelf vs walkable-under distinction; bounding-AABB
over-claim of the notch as an accepted cost.

### Room B — `shell_gallery_loop_m` (MEDIUM / split-level loop)

12×18 rect, wall height 7.6, straight chain — **the loop lives entirely
inside the room**, rehearsing circulation at room scale while zone
topology stays linear. Deck y 2.8 with the underpass beneath at exactly
HEADROOM 2.4 (**brute-proof by geometry**: TALLEST_ACTOR 2.6 > 2.4);
bridge y 2.8; ramp (rise 2.8, run 8.4); an independent second ascent via
two 1.0 m steps at the far end; a bounce-pad/grapple-only perch at 4.8.
Two ups plus free drops = true circulation, not a chain. The deck
overlooks the west floor; the underpass is invisible from the deck — the
room's information asymmetry.

- **B-COMBAT "overlook siege"**: three genuinely different reads —
  cover-hop the exposed west lane; take the underpass (total LOS denial,
  a 2.4 m-headroom knife fight the brute cannot follow you into,
  emerging *behind* the snipers); or force the ramp and the exposed
  bridge crossing with a barrel at the junction as the clearing tool.
- **B-TRAVERSAL "circulation sprint"**: ordered timed run that uses
  every vertical connection exactly once — up-ramp, across-bridge,
  drop, under-deck, up-steps — against the base-movement-floored clock.
- **B-PUZZLE "power the shutter"**: three stand-plates (existing mode)
  across three elevations with overlapping hold windows; drops are the
  fast legs, ascents the slow ones, so ordering is the puzzle.

*Proves*: a room-internal loop with two independent ascents inside
today's linear topology; HEADROOM exercised exactly at its bound as an
actor filter; overlook/underpass asymmetry; a simultaneity puzzle from
pure geometry.

### Room C — `shell_foundry_hall_l` (LARGE / industrial hall, landmark slot, boss-capable)

26×24, wall height 8.0 — the composition law's ≥ 1.8× landmark
singleton. Central raised slab y 1.0 (**rise exactly 1.0 on every
edge: walk-on elevation, ramp-free** — the step bound used as
architecture) carrying a solid machine housing (top 2.8); two wall-hung
catwalks y 3.8 with a 2.6 m gantry joining them over the slab (clearance
over slab exactly 2.4); two diagonal stair flights (four 0.95 risers,
width 2.4 — passable to the player, **too narrow for the brute**); a
−1.0 partial-cover trench (step-in/step-out legal, no softlock); a
shuttered freight bay; a bounce/grapple perch. Every ground orbit
≥ 2× BRUTE_LANE. Directly beneath each catwalk is its sniper's blind
spot — the landed "elevation negates near cover" finding, inverted into
a player tool.

- **C-COMBAT**: a crossfire hall where the two orbits fail differently
  (west exposed but owns the trench; east exposed but owns the
  under-catwalk dead ground), and silencing each catwalk costs a
  different route.
- **C-TRAVERSAL "gantry circuit"**: the full high loop against the
  clock; diagonal stair placement guarantees no shortcut.
- **C-PUZZLE "restart the line"**: three touch-valves at −1.0 / +1.0 /
  +3.8 drive the press; press state opens the freight bay (§11
  machinery; state derived from the save; room leavable in every
  state).
- **C-BOSS**: boss reveal on the slab apron with clean LOS from the
  door; phase-2 adds on the catwalks flip which orbit is safe; phase-3
  adds flush the under-lanes; the bay stays shuttered so no pocket
  deeper than the 4.5 m blast radius is open; barrels are per-phase
  one-shot resources. (Boss contract distilled in §14.)

*Proves*: the boss checklist can't even be posed in a 14 m room; a
four-elevation room whose entire mandatory path is one flat walk;
authored stairs measured riser-by-riser; and the socket-economy question
at scale (24 sockets / 624 m² — if the composer routinely fills < 60%,
that is the trim signal).

### The proof it is play, not props

Across every configuration of a room, **geometry, surfaces, connectors,
occupancy, and the full socket sheet are byte-identical** — even most
physical objects sit at the same sockets in combat and puzzle configs.
What varies: which sockets are filled and by whom; which ActivityElements
exist, their trigger mode (touch/shot/stand — three verbs of one
existing class), order, and hold windows; machinery initial state; which
optional affordance is granted; the boss phase schedule. Same
coordinates, different verbs: Room B's underpass is an ambush pocket in
combat, leg three of the sprint in traversal, and plate p1's home in the
puzzle. Routes, verb assignments, and information change while every
mesh stays fixed — which is exactly D1's claim, demonstrated.

---

## 12. Environmental object model

**PRESENT**: break (two semantics: cumulative non-gate cover; per-hit
capability-gated panel), explode (barrel), launch (pad), ride
(platform/rail), swim/lift (volumes), touch/shoot/stand (activity
elements). **PROPOSED** — adopt ROOM_FIRST §3's six-object discipline
as the ceiling, not the floor: Crate BREAK, Cache OPEN, Barrel SHOOT,
Machinery OPERATE, Block PUSH, Hazard AVOID/BAIT. One verb each; a
small number of objects with real verbs beats a large number of
decorations — the current build (7–11 inert props per arena vs 2
working features per Zone) is the measured argument.

Binding to rooms: objects fill sockets (`cover`/`reactive` today;
`machinery`/`container` when their systems exist); the socket is the
authority on where an object belongs — which is also the respawn rule
for anything movable (ROOM_FIRST §9, adopted verbatim: nothing required
is destructible; movable objects respawn to their socket; machinery
state derives from the save; a room is leavable in every state).

**The honest blocker, restated**: the crate's *contents* do not exist.
The local-reward catalog is closed (notes), Coins are AP items, and the
recorded recommendation stands — the first slice pays in **room state
and access** (a crate that opens a pocket or drops a ramp), because
those are free once the grammar exists. The container decision (owner
decision #2, §20) is the single highest-leverage unblock in this entire
study, and it is not an Art decision.

---

## 13. Verticality model (PROPOSED)

Elevation is a property any room may have, expressed three ways by the
three producers, all under one law:

- **Procedural rooms**: ElevationBand today (one band, arenas), growing
  along ROOM_FIRST §2's ladder (bands in any room type, catwalk/alcove
  kinds) as its own approved slices.
- **Authored shells**: verticality is baked and *declared as Surfaces +
  TraversalSegments*, then measured (§6.4). The worked rooms
  demonstrate the palette: galleries with reserved undersides, decks
  with walkable undersides (≥ HEADROOM), walk-on slabs (rise exactly
  1.0 — elevation with no ramp tax), stairs (per-riser ≤ 1.0; retiring
  the dead `access:"stair"` vocabulary), catwalks + underpasses (two
  routes per piece of geometry), pits/trenches (≤ 1.0 self-rescuable;
  deeper needs a declared exit), perches (optional, capability-priced),
  shafts (`descends`).
- **Height as a systems tool, not just a view**: HEADROOM-exact spaces
  filter brutes; under-catwalk lanes are sniper blind spots; drops are
  free one-way connections down (never mandatory one-ways until the
  re-entry design lands); the 1.333 jump apex prices every optional
  ledge.

Rules that keep it safe (all existing, now applied to three producers):
every band/surface above ground reachable by a guaranteed connection
where its content is required; HEADROOM under everything walkable-under;
`max_safe_gap(rise)` on every mandatory hop; FALL_KILL_Y only below
declared `descends` shafts.

---

## 14. Boss compatibility model (PROPOSED, contract now — content FUTURE)

**A certificate on a shell, not a separate family.** A `boss` intent
tag plus measured guarantees, defined now so the landmark shell can
carry it, exercised only when boss behaviors exist (today "a boss room
is an arena holding one brute" — there is nothing to choreograph yet):

1. ≥ 2 concentric ground kite loops around a central mass; every aisle
   ≥ 2× BRUTE_LANE so the boss's body never corks a loop.
2. A telegraph sightline band: the central mass blocks projectile
   trades while keeping the boss's wind-up silhouette readable; from
   every point on the high loop the arena floor is visible.
3. A passive player-only refuge from geometry (stairs < 2.6 wide), with
   the camping answer being add-spawn sockets up there, not an invisible
   rule. *(Caveat: brute-can't-follow relies on collider fit under
   direct steering — needs one measured Godot test before the contract
   leans on it.)*
4. Free disengage: every high surface has a short free drop back to a
   loop; no open pocket deeper than the blast radius during the fight.
5. Spawn/phase anchors are sockets: a reveal anchor with a clean line
   from the entrance; add anchors chosen so each phase flips which orbit
   is safe.
6. Camera readability: one central mass, no full-height mid-room
   columns, catwalks hugging walls.

BOSS packages stay blocked until the enemy roles gain behaviors; the
certificate costs nothing to carry meanwhile.

---

## 15. Epsilon's role

**PRESENT**: Epsilon already authors the Zone's sequence, room types
and dimensions, enemy composition, activities, features, flavor, reward
routing, theme — and the D1 fields (`shell_id`, `size_class`, `intent`)
sit validated-but-unofferable.

**PROPOSED (near term)** — deterministic composition over a real
catalog: choose shells by archetype + size_class + intent against
measured room scalars; choose parameterized packages and fill their
parameters (the encounter/activity composition that AUTHORED_CONTENT.md
contracts as Epsilon's half); place landmarks, quiet rooms, and pacing
under the existing composition law; spend capability guarantees on
optional spice; keep designer notes and graffiti as the legible voice of
its choices. The authorship question was tested against the strongest
objection (a picker over pre-approved pairs is a weighted random
picker): the honest answer is that continuous dimensions were never
authorship (23/23 rectangles), and the authorship that matters —
*population, pacing, and the zone answering the item log* — is exactly
what parameterized packages preserve and sealed bundles would destroy.
That line (parameterized, never sealed) is this study's firmest
authorship guarantee. The fallback provider must speak every new word
(shell_id, package_id) deterministically — budget it with every slice;
it is what keyless players play.

**FUTURE (bounded invention)** — only after, and in this order:
1. The conformance suite (§6.4 + §17's producer-agnostic gate) is
   green over both producers for a full release cycle — the measured
   proof that the contract, not the producer, carries safety.
2. Authored examples exist in machine-readable form (shells + packages
   + bespoke layouts) for Epsilon to learn the house style from.
3. **Remix rung**: Epsilon composes new *configurations* of existing
   shells (socket fills, package parameters, objective pockets beyond
   the curated sets) — every output still passing the same validators;
   archive + replay make each invention reviewable after the fact.
4. **Invention rung**: Epsilon proposes new *layouts* inside the
   contract (surface lists + socket sheets for the generator to build,
   or PackageLayouts for existing shells) — gated by the same geometric
   audit, the walkability prover, capability law, and the repair-once →
   fallback pipeline, with the `review` field as the owner's per-item
   kill switch. Epsilon never emits meshes, paths, or dimensions
   outside declared bounds at any rung (D2's runtime line is
   unchanged).

The validation that must exist before rung 4 is precisely the audit of
§6.4 — which is why it is in the prototype, not the future.

---

## 16. F3 verdict: retrofit by regeneration; land as pending

Neither "reuse as-is" (fixed sizes, zero metadata — the recorded
deferral stands) nor "retire" (the *forms* are owner-approved and the
family discriminators are genuinely designed). The decisive fact: the
shells are **script-generated**, so the correct retrofit is extending
the Blender build scripts + exporter to emit contract metadata
(Surfaces, sockets, volumes, TraversalSegments, `descends`) from the
same variables that placed the geometry — **no hand-measuring, no
remodeling, and under §6.4's geometric validation, no GLB re-export**.

| Family | Verdict | Cost | Note |
|---|---|---|---|
| Treasure ×3 | **Retrofit now** | trivial | `TreasureRoomChamber` has no dimensions — zero expressiveness lost; the trio maps to D1's "vocabulary, not triplication" exactly. Watch recurrence: the exit room is a treasure room every zone → 3 ids across 24–30 zones is heavy; acceptable as legible "shrine typology" only after S19 theming, else expand the trio. |
| Towers ×3 | **Retrofit now** | cheap | `floors` only — no dims to lose; `routecheck` data becomes TraversalSegments. Floors 2/3/5 exist; floors=4 chambers fall back procedurally (or the offer filters by floors). Replaces the schema's spatially least expressible room with its largest per-room quality jump. |
| Corners ×2 | **Retrofit, gated** | cheap | Never in the Zone schema. Gated on `exit_yaw` (§6.1) — do not land before ZoneBuilder consumes it. |
| Arenas ×4 | **Retrofit selectively** | medium | `shell_arena_balcony` first (the landmark singleton — one fixed size per size_class IS the design there). Interior masses (pillars, balcony, barrier) need `no_build` declarations — the one real authoring addition. Balcony access is enemy-only until an access variant is authored; owner-taste flag. |
| Corridors ×4 | **Hold as prototypes** | — | The one family where fixed size measurably loses (6–30 m per chamber vs fixed 14–20). Their future is Model B's lane: recut `shell_corridor_bays`' ~3.6 m bays as D1 repeatable spans. `shell_corridor_gallery`'s 2.6 m deck has no base-kit access — enters optional/enemy-only if converted. |
| Paths ×3 | **Hold** | — | Mandatory routes must stay parametric (Q1's baked-gap warning is schema law); worst jumps 1.8/2.309/2.4 sit within 0.2–0.3 m of derived bounds — a margin retune strands them. Deck dressing may return as modules later. |

All conversions land as `review:"pending"` and the owner flips per
entry — batch-PASS did not survive the A/B for the projectiles, and the
per-entry review field is the proven kill switch. (Drift note for the
art lane, unrelated but live: the art branch's exported pack still says
`pass` for the three projectiles Production reverted at `5f1435f`; the
next regeneration must export them as pending or they silently
re-enable.)

---

## 17. Tiny prototype recommendation (PROPOSED)

Smallest set that answers the largest unknowns — three slices, each
independently owner-approvable, each leaving the game shippable, each
A/B-able against the zone digest:

**P1 — Socket parity + the geometric audit** (engineering only, no art,
no Epsilon-visible change). `_from_authored_scene` emits
stand/cover/reactive/enemy_high/reserved from declared metadata; the
§6.4 ray-probe audit + walkability sweep; **one conformance suite keyed
to the contract, run over both producers** (per-path suites inherit the
blind spot of the fix they protect — the repo's own lesson). *Answers:
can an authored room reach full grammar parity with a procedural room?*

**P2 — The eight dimensionless shells.** Converter (axis-trap handled)
+ exporter extension; towers ×3, treasure ×3, corners ×2 (corners gated
on `exit_yaw`); flip the pinned empty-catalog test as it instructs; land
pending, owner flips. *Answers: does the full catalog→selection→
validation→instantiation→audit loop hold on real content, and do
authored rooms read as places in situ (the projectile A/B question, for
walls)?*

**P3 — One landmark + one new shell + three packages.**
`shell_arena_balcony` as the large landmark singleton (with `no_build`
interiors), **one new-built shell to the full contract** — Room A's
`shell_elbow_m`, chosen because it exercises everything the 19 never
did (non-rect footprint, turning exit, over-provisioned socket sheet,
two objective pockets) — and three parameterized packages (COMBAT,
TRAVERSAL, EXPLORATION-quiet) docked on it. Picker with teeth + the
shell-repetition composition rule. *Answers the study's central claim:
does one authored space produce genuinely different play under
different packages — and does the owner, playing it, look around the
room?*

Explicitly **not** in the prototype: corridor/path conversion, module
lane, machinery (its own §11 slice), PUZZLE/BOSS packages, junction
rooms, MICRO/MASSIVE anything, S19 (deferrable past P2 while all
authored rooms share one baked look; prerequisite before shell *reuse
across zones* is judged). Acceptance: all existing suites green; the
conformance suite green over both producers; zone digest moves only
when a slice intends it; the playtest question is ROOM_FIRST §14's own
— *"did you look around the room?"*

---

## 18. Art / Production boundary

**Art can do now, independently** (within the existing idle-lane rules —
this study itself is the owner brief to un-idle against, if approved):
extend the Blender build scripts + exporter to emit contract-format
metadata; build `shell_elbow_m` to the full contract as a *pending*
proposal; draft package recipes on paper; keep dual-validator tooling
current (it already fetches Production's validators read-only).

**Must be agreed with Production first** (all schema/runtime): every
`content.py`/`zone.py` field in §6.5; the ShellValidator/geometric-audit
work; `_from_authored_scene` socket emission; `exit_yaw` in ZoneBuilder;
`packages.py`; the S19 material binding; fallback-provider parity for
shell/package words.

**Production-authoritative, permanently**: movement law and derived
constants; validation and refusal; occupancy (`solid_boxes` + declared
volumes — one derivation); placement authority (a socket is an offer);
capability logic and the guarantee ladder; the composition law;
determinism and the digest; the review gate.

**The owner**: every PASS, every slice approval, and the taste calls in
§20 — unchanged.

---

## 19. Failure modes / red-team findings (the ones that survived review)

Ranked by what they would cost if ignored:

1. **BLOCKS — authored shells without the physical import audit.**
   Baked gaps escape pydantic; sealed-basement returns per-asset;
   author-claimed ≠ builder-vouched. §6.4 is the price of admission.
   *(Also caught independently: marker-based validation is circular —
   geometric probes are the gate.)*
2. **BLOCKS — PUZZLE/BOSS packages before their verbs.** They would
   re-skin the judged-boring activity families. Gate on machinery §11
   and boss behaviors.
3. **RESHAPES — the grid arithmetic.** 5×13×N authoring is ~7× total
   shell output to date spent on the least-seen axis, against a
   single-owner review bottleneck. Demand-driven library; convert the
   19 first.
4. **RESHAPES — contract-satisfying-but-plays-badly packages.**
   Sockets can't say sightlines. Pair demands measured at dock + three
   measured room scalars; never a curated pair matrix.
5. **RESHAPES — look-different-play-identical.** The architecture's
   default failure mode. Countered by §6.3's variation mechanisms and
   by verb-slices outranking shell count.
6. **CAUTION — retune stranding.** Authored shells only re-validate
   where procedural rooms re-derive; two F3 paths sit within 0.2–0.3 m
   of derived bounds. Policy: ≥ 0.2 m headroom inside every bound for
   new shells; CI re-runs the shell audit on any constants change.
7. **CAUTION — connector sameness & the pacing tax.** Standardize
   interface minima, not door geometry; no adapter library; big shells
   force push-forward connectors — watch dead corridor seconds in P3's
   playtest.
8. **CAUTION — Epsilon-as-picker.** Parameterized packages and live
   population are the guarantee; sealed bundles are the failure.
9. **CAUTION — fallback parity debt.** Every new word Epsilon can say,
   the deterministic fallback must also say; budget it per slice or
   keyless players fork off the content path.
10. **CAUTION — theme seam.** Until S19, authored rooms are one baked
    look beside 6-theme procedural rooms — the exact in-context
    rejection the projectiles suffered. Judge shell *reuse* only after
    S19.

---

## 20. Open owner decisions

Only what genuinely requires taste or intent; everything else above is
engineering deduction from the record.

1. **Direction**: adopt the hybrid (grammar-as-contract; shells
   dimensionless-first at 3–4 per zone growing toward the Check-arena
   share as families pass review) — yes/no. This is the study's
   recommendation; it is also the smallest decision compatible with D1.
2. **The container/reward question** (pre-existing, re-surfaced as the
   single highest-leverage unblock): does the local-reward catalog gain
   a container kind / local consumables, or does the first crate slice
   pay only in room state and access? Nothing in this study substitutes
   for it.
3. **Machinery slice** (ROOM_FIRST §11, "new but modest"): approve or
   defer. PUZZLE packages and two of the worked rooms' configurations
   wait on it.
4. **Prototype approval and its scope** (§17's P1–P3) — including
   whether the one new-built shell is worth authoring before P1/P2
   results, and whether `shell_arena_balcony`'s enemy-only balcony is
   acceptable for the landmark until an access variant exists.
5. **Repetition tolerance**: the per-zone shell dose (start 3–4?) and
   the reuse gap are taste numbers only playtests can set; also whether
   the 3-id treasure recurrence reads as typology or tiling.
6. **Topology sequencing**: v0.10 §7 recommends dead-end spurs now and
   hub-and-spoke as the target; junction shells and any one-way
   vocabulary hang on this. This study only asks: decide it *before*
   commissioning junction-family art.
7. **Size vocabulary confirmation**: ratify keeping S/M/L (dropping
   MICRO/MASSIVE) as §4 defines them by capacity.
8. **F3 per-family dispositions** (§16): especially corridors-as-
   modules-later vs converting any now, and the treasure-trio expansion.

---

*Working materials: six subsystem audits, three model steelmans, red
team, contract draft, three full room designs, and two judge reports
were produced for this study and are summarized faithfully above; the
full room designs (every socket coordinate and configuration) are
available to convert into batch briefs the moment the owner approves a
prototype slice.*
