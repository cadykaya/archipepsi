# Proposal: the room is the gameplay

**Status: PROPOSED, NOT IMPLEMENTED.** Nothing here is built. Written
after the 2026-08-30 playtest of Zone 1 at `d5beedd`.

The owner's finding, which supersedes "the activity families need work":

> There's more stuff to do, but it does nothing and it's not fun.
> A breakable crate containing something would be more fun than walking
> over four buttons that do nothing.

---

## 1. Audit: why the rooms feel flat

Measured from the Zone the owner actually played
(`1bdf42f800c5637e`, 23 rooms), not inferred from schema names.

### 1.1 Every room is a rectangle, and that is not a generation failure

| | |
|---|---|
| Rooms in Zone 1 | 23 |
| Footprint shapes | **rectangle × 23** |
| Distinct corridor widths | **one: 7.9 m, all eight of them** |
| Arena wall heights | 4.6 – 7.0 m |
| Arena floor areas | 64 – 624 m² |
| Walkable elevations per arena | **one** |

Here is the reason, and it is the whole finding:

```
ArenaChamber        width, depth, wall_height, objective, enemies
CorridorChamber     length, width, enemies
PlatformPathChamber segment_count, gap_size, vertical_step, objective, enemies
TowerChamber        floors, objective, enemies
TreasureRoomChamber objective
```

**A room's entire shape is three numbers.** There is no field in which a
balcony, a pit, an alcove, a side branch, a catwalk or a chokepoint could
be described. Epsilon could not generate an interesting room if it wanted
to, and neither could a human writing the JSON by hand. The flatness is
not a quality problem in the generator — it is the generator faithfully
building everything the schema can say.

Everything else follows from that.

### 1.2 Elevation exists in exactly one chamber type, and it is the broken one

`platform_path` is the only type with vertical structure, and it is a
special-case minigame: a corridor of platforms over a void, not a place
with a raised area. It is also where all 23 floating activity elements
are, because it has no floor for the composer to place onto
(`docs/ZONE_ACTIVITY_AUDIT.md`).

So verticality in this game is currently a ROOM TYPE rather than a
property a room can have. An arena cannot be tall.

### 1.3 Combat has nowhere to happen

| | |
|---|---|
| Rooms with enemies | 10 of 23 |
| Rooms with **one** enemy group | **9 of 10** |
| Enemy archetypes | 28 ranged, 12 melee, 1 brute |
| Elevation available to any of them | none |

**Two thirds of the enemies are ranged, in flat rectangles.** Ranged
units want height, sightlines and cover to contest; none of the three
exists. A ranged enemy in a flat box is a melee enemy that misses.

The one room that reads differently — c014, 26 × 24 m, three groups
including the Zone's only brute — is different because it has more
things in it, not because its space does anything.

### 1.4 The room is mostly furniture that does nothing

Per arena, from the builder: 4 corner buttresses, 2–4 crates, 1–3 theme
props. **Seven to eleven objects, every one inert.** Against that, the
interactive population of a whole room is: one Check, one enemy group,
and (since last week) one or two activities.

The whole Zone contains **two** affordance features.

The player learns the correct lesson very fast: *objects here do not
matter.* Then they learn it about the activities too, because an
activity's entire consequence is a flavour log.

### 1.5 The honest summary

A room today is a **rectangular box with a size**, holding a reward, some
enemies with nowhere to stand, and seven to eleven pieces of scenery. The
"content budget" buys quantity of things placed in the box. Nothing buys
the box being a place.

---

## 2. Proposed room grammar

A bounded set of composable ingredients. The design goal is that **a room
built from these should be worth walking through with zero activities and
zero Checks in it.**

### 2.1 The four layers

**FOOTPRINT** — the plan. Still simple, no longer only one shape.
`rect`, `L`, `T`, `cross`, `rect_with_pit`, `rect_with_gallery`. Six
shapes, each expressible as a base rectangle plus one subtraction or one
addition, so the seal/overlap tests stay tractable.

**ELEVATION BANDS** — 1 to 3 walkable heights in ANY room type.
`ground` (0 m), `mid` (1.2–2.5 m), `high` (3–5 m). A band is a set of
surfaces, not a floor: a shelf along one wall is a band, a catwalk across
the middle is a band, a sunken pit is a band below ground.

**CONNECTIONS** — how bands reach each other, declared not implied:
`ramp`, `stair`, `drop` (one-way down), `jump` (bounded by
`max_safe_gap`, as `platform_path` already is), or
`capability:<name>` (see §6). Every band above ground needs at least one
connection the campaign is guaranteed to be able to use.

**SOCKETS** — typed positions the room offers, which the composer fills:
`cover`, `enemy_ground`, `enemy_high`, `machinery`, `container`,
`hazard`, `reward_pocket`, `traversal_anchor`, `activity_element`.

### 2.2 Why sockets are the load-bearing idea

Every placement bug this month was one bug: **the builder knows things
the composer does not.**

- Activities landed inside props → the solver did not know where props were.
- Activities landed in mid-air → the solver did not know where the floor was.
- Two activities landed on one spot → the solver did not know what it had already placed.

Each was fixed by handing the solver more information after the fact.
Sockets end the class: the room DECLARES where things may go, and nothing
is ever placed anywhere else. It is the same move the affordance system
already made (`FOOTPRINT` + `fits()`), generalised.

### 2.3 Procedural vs authored

| | |
|---|---|
| **Procedural** | footprint, band heights, connections, socket positions |
| **Authored** | what fills a socket — a crate mesh, a machinery housing, a cover piece |

The grammar is generated; the furniture is authored. That keeps the
existing "developers author the alphabet, Godot enforces the grammar,
Epsilon writes sentences" boundary exactly as it is.

---

## 3. Environmental objects, one verb each

Six objects. **Prefer few objects with real verbs over many decorative
variants** — the current build is the argument for that.

| Object | Verb | What happens | Buildable today? |
|---|---|---|---|
| **Crate** | BREAK | contents appear | **Yes** — `Damageable` exists; reward is the constraint (§8) |
| **Cache** | OPEN | contents appear; rewards searching corners | **Yes**, same constraint |
| **Barrel** | SHOOT | area damage, hurts what is near it | **Yes** — `Damageable` + `Blast` both exist |
| **Machinery** | OPERATE | a door / lift / bridge / fan changes state | **Needs a small new system** (§11) |
| **Block** | PUSH | cover, height, weight on a plate | **Needs physics** (§11, §13) |
| **Hazard** | AVOID / BAIT | real damage to whoever is in it | **Yes** — damage exists |

Hazard orange stays reserved and this does not spend it: a hazard IS a
hazard, which is the one thing the colour is for.

**Crates and barrels are the cheapest real gameplay available.** Both run
entirely on systems that already ship.

---

## 4. Elevation as ordinary structure

The rule: **any room type may have bands.** `platform_path` stops being
"the vertical room" and becomes "the room whose bands are connected only
by jumps".

What that unlocks, in the order it becomes worth having:

1. **A shelf or gallery along one wall of an arena**, reached by a ramp.
   Ranged enemies stand on it. The player has a reason to look up, and a
   reason to go up.
2. **A sunken pit** — cover from above, exposure from the gallery, and a
   place to put a reward that costs something to reach.
3. **A catwalk crossing the space**, giving an overhead route and an
   underpass, which is two routes for one piece of geometry.
4. **Drop-downs** — one-way connections that make a high route a
   commitment rather than a detour.

Note what this costs the existing invariants: **nothing new.**
`max_safe_gap(vertical_step)` already bounds mandatory jumps and is
already exported to GDScript as a function. A band connected by `jump`
uses the bound that exists.

---

## 5. Combat and geometry

No Encounter Director. The claim is narrower: **enemy placement should be
a socket, and sockets should exist at more than one height.**

- `enemy_high` sockets on a gallery, `enemy_ground` on the floor. Ranged
  units prefer high; brutes prefer chokepoints; melee prefer the route
  the player must take.
- `cover` sockets between them, so approach has a shape.
- A `barrel` socket near an `enemy_ground` cluster makes a tactical
  option the player can find. Never required — damage stays balance.
- More than one connection between bands means more than one approach,
  which is the cheapest form of tactical choice there is.

The measured problem this addresses: **28 of 41 enemies are ranged and
none of them has anywhere to be ranged from.**

---

## 6. Semantic capabilities change what a room may be

NO REQUIREMENT BEFORE GUARANTEE is preserved exactly
(`mechanics.capability_guarantee`, cases A–D). What changes is that a
guarantee should BUY something.

| Guaranteed | The room may then legally contain |
|---|---|
| `ranged_hit` (always) | shootable receivers, barrels, targets |
| `cross_long_gap` | a band connected only by a long jump, on an OPTIONAL route |
| `grapple` | a `traversal_anchor` socket; a high cache; a grapple shortcut |
| `blink` | a band across a barrier no walk-route crosses |

Two rules keep this safe, and both already exist in code:

- A connection to a band holding **required** content must be one the
  campaign is guaranteed to use. That is `capability_guarantee` applied
  to geometry instead of to activities.
- Optional content may sit behind any capability at all, guaranteed or
  not. §0-bis already permits this and it is the good case: a high cache
  you cannot reach yet is a reason to come back.

The Forge rule holds unchanged — the room asks for the semantic function,
never a named Echo. No Forge closure here.

---

## 7. Activities become the rule connecting room elements

The owner's read after playing: three of the four families are one verb.
That is correct, and it is a symptom of activities being **self-contained
and consequence-free**. Re-cast, each family becomes a rule ABOUT the
room:

| Family | Standalone today | As a room rule |
|---|---|---|
| `switch_sequence` | touch N boxes → flavour log | operate the machinery that raises the bridge to the gallery |
| `target_challenge` | shoot N boxes → flavour log | shoot the receivers that open the shutter over the cache |
| `pressure_routing` | walk N pads → flavour log | hold the nodes that keep the lift powered — **the family that most needs `block` to exist**, because weights on plates is what makes it a puzzle rather than a sprint |
| `timed_run` | touch start, touch goal | operate machinery, then take the route before it closes |

**Not all four survive unchanged, and `pressure_routing` is the one I
would expect to be replaced rather than fixed.** Its current rule — a
hidden four-second window on pads you sprint between — was measured
impossible in one of Zone 1's rooms and unreadable in the rest. As a
weights-on-plates problem it is a different and better mechanic; as a
sprint it is a worse `switch_sequence`.

---

## 8. Reward, and the uncomfortable constraint

**Coins are an Archipelago item** (`ITEM_NAME_EPSILON_COIN`, counted from
`ap.coins_received`). A crate cannot mint one without fabricating
Archipelago truth. This is worth stating plainly because it is the first
thing anyone reaches for.

What a crate CAN pay today, in full:

- an `EarnedLocalReward` from a closed catalog of six kinds, five of them
  usable (`challenge_marker` is deferred by standing instruction), capped
  at 120 for the lifetime of a campaign

That is the entire local reward vocabulary. It is a note. **This is why
"break a crate and get something" is not a small task: the something does
not exist yet.**

What is needed, roughly in order of value:

| Reward | Requires |
|---|---|
| A temporary room advantage (a door opens, a lift powers) | machinery state — small |
| Access to an optional space | the grammar itself — free once §2 lands |
| Information (a readout, a marker) | exists |
| A bounded local **resource** (ammo, charge, a heal) | **a new `EarnedLocalReward` kind, or a new local consumable model** — real schema work |
| Forge materials | the Forge |

The honest recommendation: **the first slice should pay in room state and
access, not in items**, because those are free once the grammar exists,
and the item economy is a design conversation that should not be rushed
to unblock a crate.

---

## 9. Anti-softlock requirements

Binding on anything movable, breakable or stateful.

1. **Nothing required may be destructible.** A breakable crate never
   contains progression; caches hold optional rewards. Enforced in the
   schema, not by convention.
2. **Movable objects respawn.** A `block` that leaves its room, falls
   into a pit, or is destroyed returns to its socket. The socket is the
   authority on where it belongs, which is another reason sockets are the
   load-bearing idea.
3. **Machinery state is derived, never separately persisted.** A room
   rebuilt on re-entry re-derives its state from the campaign save. This
   follows the existing boundary: derived mechanics come from the fold,
   not from a second store.
4. **A room must be leavable in every state.** If machinery can close a
   route, either it can be reopened, or the other route always exists.
   Testable, and it is the same shape as the sealed-chamber test that
   already runs.
5. **Sequence breaks are welcome; stranding is not.** Reaching a cache
   early with a capability the room did not expect is a good outcome.
   Being unable to leave is never one.
6. **Re-entry is the hard case and it is already half-solved** — the Zone
   digest and request-replay work exists. Room state has to join it.

---

## 10. What today's systems already support

Buildable with **no new subsystem**:

- Breakable crates and caches — `Damageable` is the seam and every weapon
  already speaks it
- Reactive barrels — `Damageable` + `Blast`, both shipping
- Hazard volumes — damage exists
- Elevation bands, ramps, drops, galleries, pits — geometry, and
  `max_safe_gap` already bounds the jumps
- Socket-based placement — this is the occupancy work from `0c66380`
  generalised, and the audit tooling to verify it exists at `b4a51d1`
- Enemy placement at height — spawns are already positions

Blocked only by the reward vocabulary (§8), not by the interaction.

---

## 11. What needs systems that do not exist

| Wanted | Needs |
|---|---|
| Machinery that opens doors / raises lifts | a small room-state system: a switchable device, its state, and its effect. **New, but modest.** |
| Movable blocks, weights on plates | v9 physics tool (Phase 3 Wave F) |
| Enemy roles reacting to elevation | Encounter Director (Phase 4) — the grammar can land first and be exploited later |
| Local consumables / resources as crate contents | a schema change to the local reward model (§8) |
| Capability-gated REQUIRED routes | Architecture D groundwork (Phase 2) — optional routes need none of it |
| Room state surviving re-entry | save/re-entry work, already on the Phase 1 list |

---

## 12. F3: keep it deferred, and now we know why

Art's own handoff answers this, and the answer is stronger than "not
yet". `ContentInstantiator._from_authored_scene()` takes `size` from the
**registry entry — one fixed value per entry**, and derives room chaining,
bounds, Check position and all 41 enemy spawns from it. Art measured the
mismatch:

| | procedural | authored (Batch 015) |
|---|---|---|
| corridor length | per chamber, 6–30 m | fixed 14.0–20.0 m |
| corridor height | 3.6 m, raised for features | fixed 4.5–5.9 m |

So an authored shell today is **less** expressive than the procedural
builder: it replaces per-chamber dimensions with one fixed size for every
room of its type. Integrating F3 now would make rooms *more* uniform,
which is the opposite of the finding.

But the fix Art names — *"either authored shells that declare per-chamber
variable geometry, or a generator that asks a shell what sizes it can
be"* — **is the socket contract in §2.2.** A shell that declares its
bands and sockets is exactly a shell that can answer "what sizes can you
be".

**F3 is not blocked by art and it is not blocked by taste. It is blocked
by the room grammar, and this proposal is what unblocks it.** That is the
right order: grammar first, then authored rooms become an ingredient in
it.

---

## 13. The smallest slice worth building

**"A room you can go up in, and a crate worth breaking."**

Three changes, no new subsystem, and it attacks the owner's sentence
directly:

**S1 — `ArenaChamber` gains one elevation band.** Optional field: a
gallery along one wall, or a sunken pit, with a ramp connection. One
band, one shape, one connection type. Not the full grammar — the
smallest piece of it that proves the shape.

**S2 — enemies can stand on it.** `enemy_high` spawns on the band.
Ranged units go up. This is a placement change, not an AI change.

**S3 — crates break, and contain something.** The Zone's 2–4 crates per
arena stop being scenery. Contents: an `EarnedLocalReward` where that is
enough, and **at least one crate per Zone that opens a route or reveals a
pocket**, because room state is the reward that needs no new economy.

Deliberately NOT in the slice: machinery, movable blocks, barrels, the
full footprint vocabulary, activity re-casting, the reward economy. Each
is defensible; none is needed to answer the question.

---

## 14. Acceptance criteria for the slice

Measurable, and mostly by tooling that already exists.

1. **Every arena in Zone 1 has ≥ 2 walkable elevations** — verifiable in
   the real-Zone audit, which already raycasts for ground.
2. **≥ 40% of ranged enemies spawn on a band above ground** (28 ranged
   today; the number is provisional and the next playtest sets it).
3. **The band is reachable by the guaranteed base kit** — the sealed-room
   and `max_safe_gap` tests extended to bands. No new invariant, wider
   application.
4. **Every crate is breakable and every break produces an observable
   outcome.** Zero crates whose only consequence is debris.
5. **≥ 1 crate per Zone changes room state** (opens a pocket, drops a
   ramp), not just grants a note.
6. **Zone digest moves; nothing else regresses.** All existing suites
   green, the activity audit still at 0 structural failures.
7. **The owner's verdict.** The question for playtest 4 is not "can you
   tell the families apart" — it is *"did you look around the room?"* If
   the answer is still no, the grammar is wrong and more of it will not
   help.

---

## 15. Explicitly deferred

| Deferred | Why |
|---|---|
| Full footprint vocabulary (L, T, cross, gallery) | S1 proves the band first; shapes are cheap once bands work |
| Machinery / switchable devices | small new system, but a system — after the band lands |
| Movable blocks, weights on plates | v9 physics |
| Encounter Director | Phase 4; the grammar can be exploited later without it |
| Local consumables, crate item economy | schema + economy design, §8 |
| Activity re-casting into room rules | §7 — depends on machinery existing |
| Fixing the 23 floating `platform_path` elements | owner ruling: may be obsoleted by embedding activities in real geometry. The diagnostic guard stays. |
| The impossible c015 pressure configuration | same; `pressure_routing` may not survive §7 |
| Capability-gated required routes | Architecture D / Phase 2 |
| F3 authored shells | §12 — unblocked by the grammar, not before it |
| Forge closure | Phase 3+ |
