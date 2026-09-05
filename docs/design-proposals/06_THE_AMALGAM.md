# ARCHIPEPSI — COMPLETE DESIGN 6: THE AMALGAM

## Everything is a verb applied to the world, and the Zone remembers

**Status:** Complete proposal. Not canon until selected by the owner.
**Proposal:** 6 of 6 — the union of Designs 1 through 5
**Design thesis:** Physics verbs, Status verbs, and signal verbs are one vocabulary applied to actors, objects, surfaces, volumes, and the player. The Zone is a machine that records what you did to it, and a single verifier proves you can never break it.
**Target:** Godot 4.5 client plus the existing Python/Pydantic bridge.
**Source authorities:** `docs/authorities/PLAYER_DESIGN_AUTHORITY_v1.0.md`, `docs/authorities/DUNGEON_ENVIRONMENT_AUTHORITY_v0.1.md`
**Written against:** `docs/design-proposals/00_ZERO_GUESSWORK_STANDARD.md` v1.1

### Proposal profile

| Axis | Rating |
|---|---:|
| Novelty | 5 / 5 |
| Player-build variety | 5 / 5 |
| Environmental breadth | 5 / 5 |
| System interaction depth | 5 / 5 |
| Implementation risk | **5 / 5** |
| Procedural validation difficulty | **5 / 5** |
| Reuse of current repo foundations | **1 / 5** |

> **Engine status, added after the fact.** This document was written against the two source authorities and never against the code. It has since been checked: see [`07_ENGINE_RECONCILIATION.md`](07_ENGINE_RECONCILIATION.md). Three of its systems are blocked at the substrate — the engine has no rigid-body physics, refuses `manipulate` as a capability by name, and has no channel between §30.6 and Archipelago's own solvability logic. §41.6 records this. Read the reconciliation before treating any of §14, §21.10, §26, or §29 as buildable.

**Principal tradeoff:** there isn't one, in content. This proposal takes everything from all five, and §0.4 records the single clause it could not take. The tradeoff is entirely in **cost**: it is the most complex document in the repository, its composition-time validation is three validators stacked, and its performance budgets required a full rewrite to coexist. §41.2 is unusually blunt about where that risk sits, because a proposal that sacrifices nothing has to be honest about what it costs instead.

**Who should pick this:** an owner who wants the whole game and is prepared to pay for it in build time and validation infrastructure rather than in cut features.

---

# 0. PURPOSE

## 0.1 What this document is

Designs 1 through 5 are five mutually exclusive resolutions of the two source authorities. This is their union.

It exists because the five turned out to be **far more compatible than they look**. Four of the six apparent architectural forks are superset relationships rather than contradictions, and §0.3 shows each one. The union is therefore not a compromise; it is mostly a matter of taking the more general mechanism in each case and letting the narrower one fall out as a special case of it.

## 0.2 The thesis, and why a union needs one

A union without a thesis is a feature list, and a feature list is not a game.

> **Everything is a verb applied to the world, and the Zone remembers.**

Design 2 gave the player twelve **physics verbs**. Design 5 gave twelve **Status verbs**. Design 3 gave five **signal verbs**. All three act on the same five target kinds — actor, object, surface, volume, player — and all three are things the player *does to the world* rather than things the world does to the player.

The second half matters as much as the first. Design 2's **latching** makes a solved physical configuration permanent. Design 3's **macro state** makes a Zone's configuration persistent and reconfigurable. Together they mean the Zone accumulates a record of what the player did, and that record is what the verifier reasons about.

That is one game. `PHASED` on a wall, `PUSH` on a crate, and `HOLD_SIGNAL` on a node are three dialects of the same sentence: *I changed something, and it stayed changed.*

## 0.3 The six forks, resolved

| # | Fork | Appears to be | Resolution |
|---|---|---|---|
| 1 | **Macro state** — 4 forward-only Booleans (D1, D2, D4, D5) vs 8 reversible variables (D3) | Contradiction | **Superset.** Design 3's `MacroVariable` carries `reversible: bool`. Design 1's four flags are exactly `reversible = false` with two states. Take Design 3's; Design 1's are a legal configuration of it. |
| 2 | **Topology** — tree (D1, D2, D4, D5) vs graph with cycles (D3) | Contradiction | **Superset.** A tree is a graph with zero independent cycles. Design 3's model check verifies both, and its `cycle_count` parameter may be `0`. Take Design 3's. |
| 3 | **Machinery** — kinematic (D1, D3, D4, D5) vs simulated constraints (D2) | Contradiction | **Already merged.** Design 2 keeps all nine kinematic actuators unchanged *and* adds eight constraint kinds, bridged by `WINCH`, `BRAKE`, and `DRIVER`. Take Design 2's whole §21 and §14.8. |
| 4 | **Item generation** — profile selection (D1, D2, D3, D5) vs composition (D4) | Contradiction | **Superset.** A profile *is* a fixed composition. Every profile in Designs 1, 2, 3, and 5 is expressible as a named atom composition, and §11.7 does exactly that. Take Design 4's system. |
| 5 | **Forge** — deferred (D1, D2, D3, D5) vs ships (D4) | Difference | **Additive.** Take Design 4's §18 entire. |
| 6 | **Physics gating progression** — never (D1, D3, D4, D5) vs mandatory manipulation (D2) | **Genuine fork** | Resolved by §29 and §30.6: `manipulate` becomes a fifth capability, and because capabilities are constant for a Zone (Design 3 §29.5) that costs the verifier nothing. Design 2's reference-solution replay proves the physical half, and the puzzle's latch enters the state vector so the graph half is proved too. This is the one fork that required new machinery, and it is why the verifier is load-bearing for the whole union. |

**The load-bearing consequence:** this proposal only works with Design 3's model check at its centre. Everything else merges around it.

## 0.4 The one thing that could not be taken

Design 1's `status:core:exposed` sets a target's Defense to `0.0` **and** adds `+1.0` to incoming crit chance. Design 5's central invariant is that no Status applied to an actor modifies a damage number.

Both change the number the damage resolver produces. The union keeps one and drops the other, and §15.3 states the distinction honestly rather than pretending Defense-to-zero is not a damage change: **no Status may modify raw damage, crit chance, or a crit multiplier**, and `exposed`'s Defense effect is the single declared exception to that rule.

**`exposed` ships here with its Defense effect and without its crit clause.** That is the only content in all five proposals this union does not take, it is one clause of one Status, and it is flagged here rather than buried because "no cuts" was the instruction and this is the exception to it.

One other thing is *deduplicated* without being cut. §11.7.1 drops three of Design 4's `effect` atoms — `status`, `physics`, and `field` — because the union ships discriminator-carrying atoms doing the same jobs, and two atoms meaning the same thing is a defect rather than a superset. Each remaps deterministically at the same tier and loses no behaviour, and it happens during authoring rather than after ship, so Design 4 §17.7's append-only rule is untouched. That is a deduplication, not a loss of content, which is why it is recorded here in its own paragraph rather than counted against the one cut above. An owner who prefers Design 1's version can restore the crit clause by striking §15.3's actor rule — it costs the no-damage-modification invariant and nothing else.

## 0.5 How this document pins

This document **pins to all five proposals**, not only to Design 1. A pin reads *"Pinned: identical to Design 3 §30.6"* and means exactly that: the named section of the named document is the contract.

Where a pinned section itself pins onward — Design 5 §13 pins to Design 1 §13 — the chain resolves to the same text and the pin is written to the original.

**Pins and modifiers.** Where a section here modifies something it also pins, the pin names its modifier inline. The complete list:

| Pinned | Modified by | What changes |
|---|---|---|
| Design 3 §4.9 (`MachineGraph`) | §4.10 | The state vector gains physics latches |
| Design 3 §30.6 (the model check) | §30.6 | Two properties added; physics and capability integrated |
| Design 4 §4.5 (the atom) | §11.7 | The alphabet absorbs physics, signal, and Status atoms |
| Design 5 §15.2 (`exposed` absent) | §15.2 | `exposed` is restored, less its crit clause (§0.4) |
| Design 4 §12.2 (the `effect` dimension) | §11.7.1 | Three atoms superseded by discriminator-carrying equivalents; four `HIGH` atoms added |
| Design 4 §11.2 (the `payload` dimension) | §11.7 | Two atoms added, carrying Design 2's and Design 3's Weapon riders |
| Design 2 §29.3 (the `manipulate` contract) | §29.3.1, §29.3.2 | Capability **identity** becomes Boolean verb-set membership; the numeric envelope is retained as **provider qualification** for mandatory routes only |
| Design 1 §19.3 (signal evaluation) | §19.3 | Step 1 gains latches and signal verbs, and an internal order |
| Design 1 §21.1.1 (power loss) | §21.1.1 | Three constraint-driven actuator kinds added to the per-kind table |
| Design 1 §23.4 (package reset) | §23.4 | Two clauses added: Statuses cleared, macro state untouched |
| Design 1 §32.1 (the enemy contract) | §32.1.1 | The enemy-Status asymmetry gains an explicit boundary table |
| Design 3 §30.1 (Epsilon chooses nothing) | §30.1, §30.11 | **Rebased.** Epsilon selects one `shell_id` per room from a bridge-filtered catalog |
| Design 3 §30.6 property 4 | §30.6.1 | Quantified per configuration rather than over the global reachable set |
| Design 3 §30.7 (checkpoints) | §30.7 | Validated over reachable configurations, not the initial state |
| Design 5 §15.3 (the no-damage rule) | §15.3 | Restated as three rules with `exposed` as a declared exception |
| Design 5 §35 (Status budgets) | §35.2, §35.2.1 | Two caps reduced; mandatory capacity reserved |

**This table is complete and §38 vector 3 tests that claim.** Every section of this document that modifies something it also pins appears above; no section modifies a pin absent from it.
| Design 1 §35 (budgets) | §35 | Rewritten entirely; five proposals' budgets cannot coexist unchanged |

---

# 1. INHERITED LAWS

*Pinned: identical to Design 1 §1.1 and §1.2.* All 48 laws unchanged.

Every law survives the union. The three that were closest to breaking, and what holds them:

- **Law 20** — physics is bounded manipulation, never universal movement or dominant damage. Held by Design 2 §14.4's nine explicit limits and §31.3's ten-to-one arithmetic, both taken unchanged.
- **Law 27** — a Status never deals periodic damage. Held by Design 5 §15.3's structural rule, plus §0.4's removal of `exposed`'s crit clause.
- **Law 34** — `NO REQUIREMENT BEFORE GUARANTEE`. Held by §30.6, which now proves it over macro state, capabilities, keys, encounter flags, and physics latches simultaneously.

## 1.3 Precedence

*Pinned: identical to Design 1 §1.3.*

---

# 2. SCOPE

## 2.1 Ships in The Amalgam

Everything from all five, organised by where it comes from.

**From Design 1 — the spine**

- The movement law and every derived margin (§6).
- The damage road: request, resolution order, Defense curve, Barrier pooling, linear overcrit, healing, death (§8).
- The interaction resolver with its four-key deterministic sort (§9).
- The signal graph: four port forms, eleven node types, acyclic single-tick evaluation (§19).
- Hacking (§22), capability proof (§29), the deterministic offline fallback (§17).
- Its `32` Weapon-side profiles (`18` primary, `6` secondary, `8` feed) and `14` Ability profiles, re-expressed as named compositions (§11.8). Its `9` Mobility profiles are retained as authored profiles rather than composed (§12.8).

**From Design 2 — the physical layer**

- Twelve manipulation verbs, eligibility, and the §14.4 limits.
- Eight constraint kinds, genuinely simulated, with `WINCH` / `BRAKE` / `DRIVER`.
- Latching (§5.5), which is also how physical progress enters the verifier.
- Transform-level persistence for required and constrained objects.
- The twelve-class object taxonomy, `DISPLACED` enemies, environmental kills.

**From Design 3 — the Zone layer**

- Reversible macro state, up to 8 variables of 2–4 states.
- Predicated topology, looping graphs, rail networks.
- **The model check** (§30.6), extended here to cover physics and capability.
- The Machine Graph, the Zone Diagram, five signal verbs.

**From Design 4 — the content layer**

- Compositional generation: the atom alphabet, budgets, trigger clauses.
- **Forge**, with Epsilon Static as its currency.
- Catalog versioning, `Legacy` flagging, the append-only rule.

**From Design 5 — the verb layer**

- Thirteen Statuses in four families (twelve from Design 5, plus `exposed` per §0.4).
- Eight compounds, consuming their components.
- Status on five target kinds; trait gating on the world and never on actors.
- `STATUS_TRANSFER`, `SELF_STATUS`, compound telegraphing.

## 2.2 Explicitly deferred

Only what **every** proposal defers. Nothing any proposal shipped is deferred here.

| Deferred system | Cost |
|---|---|
| Water as a swimmable medium | Nine authority acceptance tests (D48–D56). Deferred in all five and therefore here. It is the most-missed system in the repository: it is the natural surface for `conductive` and `slippery`, the natural macro variable for `flooded → drained`, and the natural medium for buoyant constraint puzzles. **It is the first thing to add after this ships.** |
| Energy balls and reflector beams | Two routing families, deferred in all five. |
| Portals and teleporters | Deferred in all five. |
| Gases, smoke, steam, pressure, temperature | Deferred in all five. |
| Directional gravity | Deferred in all five. Design 2's local gravity *magnitude* volumes ship. |
| Programmable logic | Deferred in all five. |
| Rotating whole rooms | Deferred in all five. |
| In-Zone loadout stations | Deferred in all five. Hub-only editing. |

**Deferral means:** *pinned: identical to Design 1 §2.2.*

## 2.3 Removed rather than deferred

*Pinned: identical to Design 1 §2.3.*

## 2.4 What "v1" means here

One shippable game containing everything in §2.1. §40.2 stages it across 35 waves, and §41.2 is explicit that this is the largest v1 of the six proposals by a wide margin. §40.0 keeps that sequence strictly separate from the live Playable 0.3 critical path, which this document does not govern.

---

# 3. AUTHORITY AND DATA OWNERSHIP

*Pinned: identical to Design 1 §3.1 (bridge), §3.2 (Godot), §3.4 (identifiers), §3.5 (validation behavior).*

## 3.3 Epsilon authority

*Pinned: identical to Design 4 §3.3* — Epsilon composes from the atom alphabet and emits selections, never numbers. §11.7 widens the alphabet to cover physics, signal, and Status content, which widens what Epsilon chooses among without changing the kind of thing it chooses.

## 3.6 Two additions

**The verifier is bridge authority.** *Pinned: identical to Design 3 §3.6.* The model check runs once, in the bridge, at composition. The client verifies consistency (§30.9) and never re-verifies.

**Semantic state beats simulation for progression.** *Pinned: identical to Design 2 §3.6.* Where the physics solver and a latched condition disagree, the latch wins for progression and the simulation wins for everything else.

Those two rules together are what let a verified Zone contain a physics simulation at all: the verifier reasons about latches, which are monotone and discrete, and never about rigid-body positions, which are neither.

---

# 4. SCHEMAS

*Pinned: identical to Design 1 §4.1 (common types) and §4.7 (loadout).*

## 4.2 Host definition

*Pinned: identical to Design 4 §4.4* — `HostDefinition` with `composition` and `budget_spent`.

**Composition replaces `profile` for Weapons, Abilities, Gear, and Mods. Mobility is the exception** and retains `profile`, per §12.8's total exemption. A previous revision said composition replaces `profile` *"everywhere"*, which §12.8 then contradicted forty sections later; the exception is named here instead:

```
HostDefinition:
  ...                                    # Design 4 §4.4's fields
  composition : Composition?             # null for category == mobility
  profile     : Id?                      # non-null ONLY for category == mobility
```

Exactly one of the two is non-null, decided by `category`, and §30.5 check 19c rejects a host with both or neither.

**`qualifies_manipulate` is not a field.** §29.3.2's provider qualification is **derived, never serialized**: it is computed from the resolved committed Loadout at §29.4's entry check and discarded. Caching it would create a value that can go stale when Gear changes, and the only consumer runs once per Zone entry, so there is nothing to save. Any text implying a stamped flag is superseded by this paragraph.

## 4.5 The atom

*Pinned: identical to Design 4 §4.5* — id, dimension, cost, params, `requires`, `excludes`, `tier_min`. §11.7 gives the widened alphabet.

## 4.6 Budgets and the trigger allowance

*Pinned: identical to Design 4 §4.6 and §4.6.1* — bands `[85, 100]` and `[165, 180]`, trigger allowances `22` and `38`, clause caps `1` and `2`.

## 4.7 Physical object and configuration

*Pinned: identical to Design 2 §4.8 and §4.9* — `PhysicalObject` with attach points and `ConstraintSpec`, and `PhysicalConfiguration` at 32-bit precision.

## 4.8 Status

*Pinned: identical to Design 5 §4.5* — `StatusDefinition` and `CompoundDefinition`, with §15.2's thirteen-Status catalog.

## 4.9 Machine graph

*Pinned: identical to Design 3 §4.9* — `MacroVariable`, `TopologyEdge`, `MacroEffect`, bounded-DNF `Predicate` — **except that §4.10 extends the state vector**.

## 4.10 The unified state vector — modifies Design 3 §4.9

Design 3's verifier searched a vector of macro variables, local keys, encounter flags, shortcut flags, and visit flags. The union adds two components and, critically, **excludes a third**.

```
StateVector components:
  macro variables         2-4 states each, up to 8          # Design 3
  local keys              2 states each, up to 4            # Design 3
  encounter-clear flags   2 states each                     # Design 3
  one-way shortcut flags  2 states each                     # Design 3
  room-visited flags      2 states each                     # Design 3
  PHYSICS LATCHES         2 states each, up to 8            # NEW, from Design 2 §5.7

  product of all state counts <= 4096                       # unchanged

NOT in the vector:
  capabilities   - constant for a Zone (Design 3 §29.5); a search parameter
  Statuses       - EPHEMERAL and never gating (Design 5 §5.13, §29.5)
```

**Capabilities are not a dimension.** Design 3 §29.5 establishes that no capability can be acquired mid-Zone, so the proven set is fixed for the whole search. It is a *parameter* the verifier runs against — the minimum set §29.4's entry validation enforces — and a Zone verified for that minimum is verified for every richer set, by Design 3 §29.5's monotonicity argument. Adding `manipulate` as a fifth capability therefore costs the verifier nothing, which is the whole reason fork 6 resolves.

**Physics latches slot in for free.** Design 2 §5.7's latched conditions are monotone Booleans — once satisfied, never re-evaluated, never cleared by reset or death. That is exactly the shape Design 3's verifier already handles for keys and shortcuts. A physics puzzle's completion is therefore a state-vector component like any other, and the verifier proves reachability across it without knowing anything about rigid bodies.

This is the single most important structural finding in the union, and it is why fork 6 resolves at all: **latching is the bridge between simulated physics and provable progression.**

**Status is deliberately excluded.** Statuses are `EPHEMERAL` (Design 5 §5.13) and never gate progression (Design 5 §29.5). Both rules are taken unchanged, and together they keep the entire verb layer out of the state vector. Including it would multiply the state space by roughly `13³ × 5` and make §30.6 intractable; excluding it costs nothing, because a Status can never be the reason a player is stuck.

The `4096` bound is unchanged, but the composer's allocation problem is genuinely harder, because latches now compete with macro variables for the same budget. A worked allocation exactly at the ceiling:

| Component | Count | States each | Contribution |
|---|---:|---:|---:|
| Macro variables | `3` | `4` | `64` |
| Local keys | `2` | `2` | `4` |
| Physics latches | `4` | `2` | `16` |
| | | **Product** | **`4,096`** |

A Zone wanting eight macro variables gets very few latches, and the reverse. §30.3 step 9 makes that allocation explicitly, after every other dimension is frozen, and §30.5 check 12 proves the product rather than discovering the overflow.

## 4.11 Trigger clause

*Pinned: identical to Design 4 §4.8 and §12.8* — one event, one effect, three magnitudes, authored internal cooldowns, the `672`-clause catalog.

---

# 5. LIFECYCLE AND PERSISTENCE

## 5.1 The five categories

*Pinned: identical to Design 1 §5.1.*

## 5.2 Category assignment

The union of all five assignment tables. Where two proposals assign the same state, they agree; where only one proposal has a state, its assignment is taken.

| State | Category | From |
|---|---|---|
| Projectiles, beams, VFX, audio | `EPHEMERAL` | D1 |
| Timed button remaining | `EPHEMERAL` | D1 |
| Enemy positions and health | `EPHEMERAL` | D1 |
| `PhysicalConfiguration`, `required` or constrained | `PUZZLE_LOCAL` | D2 |
| `PhysicalConfiguration`, all other objects | `EPHEMERAL` | D2 |
| Attachment graph, constraint broken-flags | `PUZZLE_LOCAL` | D2 |
| **Latched conditions** | `ROOM_PERSISTENT` | D2 |
| Socket occupancy, lever state, machinery `t`, destructible flags, sequence progress | `PUZZLE_LOCAL` | D1 |
| Encounter cleared, shortcut opened, local key, secret, checkpoint | `ROOM_PERSISTENT` | D1 |
| **`ZoneState.macro`, visited rooms, discovered edges, diagram flags** | `ZONE_PERSISTENT` | D3 |
| Player Health at checkpoint, host runtime state | `ZONE_PERSISTENT` | D1 |
| **All `ActiveStatus`, susceptibility, adaptation** | `EPHEMERAL` | D5 |
| Checks, Archive, currencies, committed Loadout | `AP_PERSISTENT` | D1 |

## 5.3 Snapshot cadence and save refusal

*Pinned: identical to Design 1 §5.3*, with **both** refusal conditions:

- Refused during an active encounter — *pinned: identical to Design 1 §5.12*.
- Refused while any `PUZZLE_LOCAL` physical object is non-sleeping — *pinned: identical to Design 2 §5.8*, including the `0.5 s` checkpoint retry.

## 5.4 Death, unload, host state, cold introduction

*Pinned: identical to Design 1 §5.4, §5.5, §5.6, §5.7, §5.8*, with Design 2's additions: physical objects reset with their group, and a reloaded room restores physical configurations at rest with velocities zeroed (*pinned: identical to Design 2 §5.5*).

**Macro state is untouched by death and reset** — *pinned: identical to Design 3 §5.8*. **Latches are untouched by death and reset** — *pinned: identical to Design 2 §5.7 rule 4*. **All Statuses clear** — *pinned: identical to Design 5 §5.13*.

## 5.5 Latching

*Pinned: identical to Design 2 §5.7* entire. A satisfied puzzle condition latches on the tick it is satisfied, is never re-evaluated, and survives everything.

§4.10 adds one consequence Design 2 did not have: **a latch is a state-vector component**, so the verifier proves that no reachable combination of latched and unlatched conditions strands the player.

## 5.6 Save/load reconstruction order

The union of Design 1 §5.9, Design 2 §5.9, and Design 3 §5.9. Order matters and is fixed.

1. AP state.
2. Committed Loadout.
3. **The committed `ZoneManifest`** (§5.6.1). Never a fresh recomposition, never an Epsilon query.
4. `ZoneState.macro`.
5. **Latched conditions.**
6. Evaluate every `TopologyEdge` predicate against the restored macro state and latches.
7. Apply every matching `MacroEffect`.
8. Per-room `ROOM_PERSISTENT` flags.
9. Per-room `PUZZLE_LOCAL` state for the entry room and its neighbours.
10. **Physical configurations**: place objects at saved transforms, rebuild the attachment graph, rebuild constraints, step zero frames, assert non-penetration.
11. Host runtime state.
12. Player transform and Health.
13. **Verify the player's room is reachable from the Zone entry under the restored vector.** On failure, §34.13's message and a checkpoint load.
14. Rebuild `EPHEMERAL` state, including zero Statuses.

Steps 5 and 6 must precede 7, and step 10's internal order — place, attach, constrain — is Design 2 §5.9's and is not negotiable: constraints built before placement produce a corrective impulse.

### 5.6.1 Step 3 in full — loading a committed Zone

A previous revision of step 3 read *"Zone identity and seed; recompose deterministically; assert byte-identical."* That contradicts §30.11.7 outright: a fresh recomposition would re-ask Epsilon, and §30.5.1 P1 does not promise the answer would match. Step 3 is:

1. Load the `ZoneManifest` recorded in the save.
2. Verify `manifest.schema_version` is supported (§5.6.2).
3. Verify `manifest_digest` over every covered field. A mismatch is a **hard error**: §34.13's message, no approximation, no repair.
4. Verify `shell_catalog_digest` and `ap_catalog_digest` against the client's current catalogs. A mismatch is a hard error with a message naming which catalog moved.
5. Instantiate the recorded rooms, `shell_id`s, `connector_assignment`s, packages, and machine graph **exactly as recorded**. No composition step runs.
6. Read `replay_verdicts` from the manifest. **None is recomputed** (§30.11.8).
7. Restore semantic and runtime state per steps 4 onward.

**Epsilon is not contacted at any point in a load.** A save whose manifest is intact loads with the bridge offline and the model unreachable.

### 5.6.2 Manifest versioning and migration

```
ZoneManifest.schema_version : int    # currently 1; bumped on any field change
```

| Condition | Outcome |
|---|---|
| `schema_version` equals the client's | Load per §5.6.1 |
| `schema_version` is **older** and a migration exists | Migrate in memory, recompute `manifest_digest` over the migrated form, load. The saved manifest is rewritten on the next save |
| `schema_version` is **older** with no migration | The Zone is **retired**: the save loads at the Hub, the Zone's unclaimed Checks return to the allocator, and §34.13's message names the version gap. The campaign survives; the Zone does not |
| `schema_version` is **newer** than the client's | Hard error. A client never guesses at a format from the future |

Retirement rather than refusal is deliberate: a manifest that cannot be migrated must not strand a campaign, and returning its Checks is the behaviour the allocator already implements for an abandoned Zone.

### 5.6.3 Closed schemas for the committed artefacts

`ReplayVerdict` and `epsilon_provenance` were prose in a previous revision. They are saved state and therefore need shapes:

```
ReplayVerdict:
  package_id        : Id
  config_digest     : digest         # over the package's initial physical configuration
  solver_iterations : int = 8
  max_duration      : Seconds        # the bound actually replayed (30.9a)
  runs              : tuple[bool, bool, bool]   # all three must be true
  verdict           : enum { LATCHED, FAILED }
  environment_id    : string, 1..64  # the canonical replay environment
```

```
EpsilonProvenance:
  model_id          : string?        # null iff no request was issued
  request_digest    : digest?        # null iff no request was issued
  response_digest   : digest?        # null iff no usable response was received
  selected_offline  : bool           # true when 30.11.6's selector chose the final shells
  repair_attempts   : int in [0, 1]
  request_count     : int            # == 1 + repair_attempts when a request was issued;
                                     #    0 when none was (retry attempts, 30.11.10)
  elapsed_ms        : int >= 0       # wall time actually spent waiting; 0 when none
  outcome           : enum { ACCEPTED, ACCEPTED_AFTER_REPAIR,
                             TIMED_OUT, MALFORMED, NOT_REQUESTED }
```

**A repair attempt is another request**, so `request_count = 1 + repair_attempts` whenever a request was issued at all. A previous revision fixed `request_count = 1` while allowing a repair, which cannot both be true.

Every field is defined in every case — no field is left non-null in a case where no value exists:

| Case | `outcome` | `model_id` | `response_digest` | `selected_offline` | `request_count` | `elapsed_ms` |
|---|---|---|---|---|---:|---|
| First response valid | `ACCEPTED` | the model | its digest | `false` | `1` | actual |
| Repair response valid | `ACCEPTED_AFTER_REPAIR` | the model | the **repair** response's digest | `false` | `2` | actual, both requests |
| First request times out, repair valid | `ACCEPTED_AFTER_REPAIR` | the model | the repair's digest | `false` | `2` | actual, including the `10.0 s` |
| Both requests time out | `TIMED_OUT` | the model | **null** | `true` | `2` | `20000` |
| Response malformed twice | `MALFORMED` | the model | **null** | `true` | `2` | actual |
| Zone retry attempt (§30.11.10) | `NOT_REQUESTED` | **null** | **null** | `true` | `0` | `0` |

`request_digest` is null exactly when `outcome` is `NOT_REQUESTED`, and non-null otherwise — a request that timed out was still issued and its digest is still what was asked. `selected_offline` is `true` in exactly the last three rows, which is the same condition as *"no usable response existed"*.

Both are covered by `manifest_digest`. A `ReplayVerdict` whose `config_digest` no longer matches its package is **rejected at load**, not silently trusted and not re-certified on the client.

## 5.7 Mid-transition machinery

*Pinned: identical to Design 1 §5.10.* Kinematic actuators store `t` and `direction`. Simulated constraints store `current_value` and `broken` per Design 2 §4.9.

## 5.8 Temporary grants and relations

*Pinned: identical to Design 1 §5.11.* Barrier, Statuses, and physics relations (`HOLD`, `TETHER`, `PIN`) are all `EPHEMERAL` and do not survive a save.

## 5.9 Archive scale

*Pinned: identical to Design 4 §5.13.* Compositions serialize compactly and re-expand from the atom catalog off the main thread.

---

# 6. BASE PLAYER

*Pinned: identical to Design 1 §6.1 through §6.5* — body, the movement law and every derived margin, out-of-bounds recovery, Static Pulse, baseline melee.

Three additions, all from Design 2:

- The player's `mass_kg` is `80.0`, because they stand on seesaws — *pinned: identical to Design 2 §6.1*.
- External velocity is added to input velocity, clamped to `25.0 m/s` total — *pinned: identical to Design 2 §6.2*.
- Static Pulse carries `IMPULSE` rider at `SMALL` and `PULSE_ON_HIT`; baseline melee's impulse is `7.0 m/s` to `MEDIUM` — *pinned: identical to Design 2 §6.4, §6.5 and Design 3 §6.6*.

**The movement law is untouched.** All three of Designs 2, 3, and 5 pin it unchanged, for the same reason: every traversal audit, LaunchPad solve, and mandatory-route guarantee is computed from it, and §30.6 now depends on those computations being correct.

---

# 7. INPUT

*Pinned: identical to Design 1 §7.1 through §7.4*, with two additions:

- `F` is inert while a physics relation is held, with the prompt suppressed — *pinned: identical to Design 2 §7.5*.
- A long press of `Tab` opens the Zone Diagram; a short press opens the Archive; both rebind independently — *pinned: identical to Design 3 §7.5*.

Those are the only two input changes in the union, and neither adds a key. The control grammar is the Player Authority's, unchanged.

---

# 8. DAMAGE

*Pinned: identical to Design 1 §8.1, §8.3, §8.4, §8.5, §8.7, §8.8.*

**§8.2 resolution order** — *pinned: identical to Design 1 §8.2*, with step 8 replaced by Design 5 §8.9's full Status pipeline.

**§8.6 friendly, self, and environmental damage** — *pinned: identical to Design 2 §8.6*, including the causation split: a player-driven object deals `25%` capped at `20.0` back to the player, a constraint- or gravity-driven object deals full.

---

# 9. WORLD INTERACTION

*Pinned: identical to Design 1 §9.1, §9.3, §9.4*, with:

- Design 2 §9.2's six priority classes, which insert attach points above ordinary pickup.
- Design 3 §9.5's macro setters as class-4 Interactables whose prompt names the consequence.
- Design 2 §14.6's rule that player-created attachments are `F`-separable at class 3.

---

# 10. CARRYABLES, OBJECTS, AND SOCKETS

*Pinned: identical to Design 2 §10.1 through §10.5* — the twelve object classes, mass derived from `mass_kg`, carry rules, zero-velocity drop, and the recovery triggers.

Two additions:

- `allowed_volume` is a list of rooms, and a multi-room carryable is `ZONE_PERSISTENT` — *pinned: identical to Design 3 §10.5*.
- Objects carry Status via `status_traits` — *pinned: identical to Design 5 §10.5*.

A `BURNING` power cell carried three rooms to a generator is a sentence this union can write and none of the five could.

---

# 11. WEAPONS

## 11.1 Composition

*Pinned: identical to Design 4 §11.1 through §11.5* — six dimensions, the atom catalog, the reference item at exactly `100`, the §11.4 resolution order, and the compatibility mask.

Two atom additions to the `payload` dimension, carrying Design 2's and Design 3's Weapon riders into the composition system:

| Atom | Cost | Dimension | Effect |
|---|---:|---|---|
| `payload_impulse` | `24` | `payload` | Base damage `14.0`; applies `4.0 m/s` impulse to `LIGHT` and `MEDIUM` targets (Design 2's `IMPULSE` rider) |
| `payload_anchor_point` | `20` | `payload` | Base damage `12.0`; leaves an attach point on the struck surface for `8.0 s`, max 2 concurrent (Design 2's `ANCHOR_POINT` rider) |

`PULSE_ON_HIT` (Design 3 §11.2) is **not** an atom. It is universal: every Weapon in this union triggers a `SHOOTABLE_TARGET`, because Design 3's Zones make shooting a distant target to reroute a rail a core verb and gating it behind an atom would make some Weapons unable to operate the dungeon.

`status_target = ACTOR_AND_SURFACE` (Design 5 §4.3) is a **free field** rather than an atom, legal for every family except `delivery_arc`, with beam application rate-limited to `0.5 s` per surface — *pinned: identical to Design 5 §11.1*.

## 11.7 The widened alphabet

Design 4's alphabet covered Weapons, Abilities, Gear, and Mods. The union must also express Design 2's twelve physics verbs, Design 3's five signal verbs, and Design 5's four Status delivery families.

They enter through the **`effect` dimension** of the Ability grammar, each carrying a **non-costed discriminator** exactly as Design 4 §4.4 already does for `physics_primitive`:

| Atom | Cost | `tier_min` | Discriminator | Legal values |
|---|---:|---|---|---|
| `effect_physics_basic` | `24` | — | `physics_verb` | `PUSH`, `PULL`, `ALIGN`, `SETTLE` |
| `effect_physics_hold` | `30` | — | `physics_verb` | `HOLD`, `ROTATE`, `PIN`, `TETHER` |
| `effect_physics_structural` | `34` | — | `physics_verb` | `ATTACH`, `DETACH` |
| `effect_mass_field` | `32` | — | `field_verb` | `LIGHTEN_FIELD`, `ANCHOR_FIELD` |
| `effect_signal_read` | `16` | — | `signal_verb` | `PROBE` |
| `effect_signal_write` | `26` | — | `signal_verb` | `BRIDGE`, `INVERT`, `HOLD_SIGNAL`, `CUT` |
| `effect_status` | `22` | — | `status_verb` | `APPLY`, `FIELD`, `TRANSFER`, `SELF` |
| **`effect_physics_master`** | **`62`** | **`HIGH`** | `physics_verb` | **all twelve** |
| **`effect_mass_master`** | **`62`** | **`HIGH`** | `field_verb` | both, at `HIGH` magnitudes |
| **`effect_signal_master`** | **`62`** | **`HIGH`** | `signal_verb` | **all five** |
| **`effect_status_master`** | **`62`** | **`HIGH`** | `status_verb` | all four, plus compound-aware application |

Discriminators are free because verbs within one atom are priced equivalently; the atom carries the cost. Splitting physics across three atoms rather than one is what makes `HOLD` cost more than `PUSH` without pricing twelve verbs individually.

### 11.7.1 Three of Design 4's atoms are superseded, not duplicated

Design 4's `effect` dimension already contains `status` (`22`), `physics` (`28`), and `field` (`32`). The seven above do the same jobs with discriminators attached, so shipping both would put two atoms in the catalog meaning the same thing — a defect, not a superset.

**`effect:status`, `effect:physics`, and `effect:field` do not appear in the union's shipped catalog.** Each is superseded by its discriminator-carrying equivalent: `physics` → `effect_physics_basic` with `physics_verb = PUSH`, `field` → `effect_mass_field` with `field_verb = LIGHTEN_FIELD`, `status` → `effect_status` with `status_verb = APPLY`. Each remap preserves the item's tier and its resolved numbers.

**This does not breach Design 4 §17.7's append-only rule, and the distinction is exact.** That rule reads *"removing an atom is forbidden once shipped"* and *"the atom catalog is append-only **after ship**"*. It binds from ship forward, because its whole purpose is that a saved `composition` must resolve forever. The union's catalog is settled during authoring, before any save exists, so the three never ship and no save can reference them.

Two rules keep that true rather than merely stated:

1. **The three ids are permanently reserved and never reissued.** An `effect:physics` id encountered after ship resolves to the §11.7 remap above and is flagged `Legacy` for Forge, exactly as Design 4 §17.7 handles a repriced atom. It never binds to a different atom.
2. **From ship, the union's `121`-atom catalog is append-only**, with no exception. §11.7.1 is the last removal this design permits, and it happens before the rule starts.

The `effect` dimension therefore holds **`17`** atoms: Design 4's nine, less three, plus eleven.

**The whole catalog is `121` atoms against Design 4's `102`.** An earlier revision said `110`, having counted only the `effect` delta. The full accounting, against Design 4 §0's stated breakdown of `38` Weapon + `32` Ability + `19` Gear + `13` Mod:

| Group | Design 4 | Change | Amalgam |
|---|---:|---|---:|
| Weapon | `38` | `+2` payload (§11.7) | **`40`** |
| Ability | `32` | `effect` `9` → `17` | **`40`** |
| Gear | `19` | `domain` `16` → `25` (§16) | **`28`** |
| Mod | `13` | unchanged | **`13`** |
| **Total** | **`102`** | **`+19`** | **`121`** |

### 11.7.2 Why the four `HIGH` atoms are not optional

Without them the union does not work, and the arithmetic says so plainly.

The `HIGH` band is `[165, 180]`. The most expensive base composable without a `tier_min = HIGH` effect atom is `174` — but the mask rejects it, and in practice **the highest reachable total using any non-`HIGH` effect atom falls below the band floor for every effect family except `heal`.** Design 4 shipped `48` in-band `HIGH` bases and `47` of them use `transform*`; §12.5 of that document called the number thin and was right.

Design 4 could live with that because nothing in Design 4 depended on a particular effect family reaching `HIGH`. **The union cannot**, because §29.1 makes `capability:core:manipulate` a progression gate granted by a physics Ability, and a capability with no high-tier expression is a capability the Forge can never elevate into.

> ### ⚠ OWNER DECISION REQUIRED — the four `HIGH` master atoms
>
> `effect_physics_master`, `effect_mass_master`, `effect_signal_master`, and `effect_status_master` were introduced during an audit pass to close a real defect: with Design 4's catalog alone, **no high-tier physics, Status, signal, or mass-field Ability can be composed at all**, and §29.1 makes `manipulate` a progression gate granted by a physics Ability.
>
> **The defect is real. Adding four atoms is new game content, and that is the owner's call, not an auditor's.** This document does not treat their existence as an approved repair.
>
> | If the owner **retains** them | If the owner **removes** them |
> |---|---|
> | Catalog `121`, Abilities `16,586,524`, `HIGH` in-band bases `138` | Catalog `117`, Abilities `6,133,474`, `HIGH` in-band bases `48` — Design 4's exact known-thin figure |
> | Every gate-bearing effect family has a high-tier expression | **No high-tier physics, Status, signal, or mass-field Ability exists.** Forge cannot elevate into `manipulate`, and §18's Elevate has nothing to produce for those families |
> | §12.7's three CI floors stand | Those floors are removed and §12.7's table is regenerated |
>
> **Removing them does not break the design** — it re-creates Design 4's known thinness in four more places, and §41.5 would record it. Retaining them is this document's recommendation, and §41.6's verdict is conditional on the choice either way.

Pricing the four at `62` — the price Design 4 already assigns its own high-tier effect atom, `transform*`, rather than a new price point — lifts `HIGH` in-band bases from `48` to `138` and gives every effect family at least one:

| Family | `USEFUL` in-band bases | `HIGH` in-band bases |
|---|---:|---:|
| Physics | `385` | `9` |
| Damage | `217` | — |
| Signal | `194` | `31` |
| Status | `162` | `41` |
| Mark | `64` | — |
| Mass field | `63` | `9` |
| Deployable | `31` | — |
| Barrier | `27` | — |
| Heal | `23` | `1` |
| `transform*` | — | `47` |
| **Total** | **`1,166`** | **`138`** |

`damage`, `mark`, `deployable`, and `barrier` still have no `HIGH` base. That is inherited from Design 4 unchanged and is acceptable, because none of them gates progression — a high-tier damage Ability is `transform*` or a heavily-claused `USEFUL` one, which is the trade Design 4 already made and documented. **The four families that ship a `HIGH` atom here are exactly the four the union added, and exactly the four that a capability, a puzzle, or a Zone predicate can depend on.**

`effect_status` additionally requires `status_applied`, naming one of the thirteen in §15.2, except when `status_verb = TRANSFER`.

**Parameters** for each verb are pinned, not re-derived: Design 2 §14.3 for the physics verbs, Design 3 §14.1 for the signal verbs, Design 5 §12.2 and §12.3 for `FIELD` and `TRANSFER`, Design 5 §12.5 for `SELF`.

## 11.8 The five proposals' profiles as compositions

Every profile in Designs 1, 2, 3, and 5 is a fixed composition, and all of them are checked in as **named compositions** — pre-built atom selections with a stable id.

**The unit being counted matters**, and a previous revision conflated three of them. Design 1 does not have "14 Weapon profiles"; it has primary-family profiles, secondary profiles, and feed profiles, which compose into complete Weapon configurations. Regenerated from the live `01_RELIABLE_CORE.md`:

| Design 1 unit | Count | The entries |
|---|---:|---|
| **Primary profiles** (§11.1) | **`18`** | `cadence_rapid`, `cadence_standard`, `cadence_precise`, `burst_triple`, `burst_double_heavy`, `spread_close`, `spread_wide`, `bolt_fast`, `bolt_piercing`, `shell_impact`, `lob_impact`, `lob_timed`, `beam_steady`, `beam_ramping`, `charge_lance`, `charge_burst`, `arc_swift`, `arc_heavy` |
| **Secondary profiles** (§11.3) | **`6`** | `zoom_standard`, `zoom_long`, `guard_light`, `guard_heavy`, `detonate_standard`, `mode_swap_standard` |
| **Feed profiles** (§11.4) | **`8`** | `mag_small_fast`, `mag_standard`, `mag_large_slow`, `mag_shell`, `heat_standard`, `heat_beam`, `charge_hold_short`, `charge_hold_long` |
| **Ability profiles** (§12.1) | **`14`** | `ab_barrier_small`, `ab_barrier_large`, `ab_channel_heal`, `ab_dash_short`, `ab_field_short`, `ab_field_long`, `ab_instant_light`, `ab_instant_heavy`, `ab_physics_standard`, `ab_reveal`, `ab_rule_standard`, `ab_status_area`, `ab_status_reliable`, `ab_weapon_buff` |
| **Mobility profiles** (§13) | **`9`** | `mob_dash_short`, `mob_dash_long`, `mob_blink_short`, `mob_blink_long`, `mob_grapple_standard`, `mob_grapple_long`, `mob_burst_standard`, `mob_burst_high`, `mob_airstep_standard` |

| Source | Count | Example |
|---|---:|---|
| Design 1 §11.1 primary profiles | `18` | `cadence_standard` → `frame_standard + delivery_hitscan + cadence_standard + payload_direct + feed_mag_standard + secondary_none` |
| Design 1 §11.3 secondary profiles | `6` | `zoom_long` → `secondary_zoom` with its authored parameters |
| Design 1 §11.4 feed profiles | `8` | `heat_beam` → `feed_heat` with its authored parameters |
| Design 1 §12.1 Ability profiles | `14` | `ab_barrier_small` → `form_press + effect_barrier + target_self + recharge_cooldown_short + scaling_flat` |
| Design 1 §13 Mobility profiles | `9` | **Not composed.** Retained verbatim as authored profiles per §12.8 |
| Design 2 §12.1 physics profiles | `3` | `ab_physics_light` → `form_press + effect_physics_basic + target_actor + recharge_cooldown_short + scaling_flat`, `physics_verb = PUSH`. This is the composition §29.3's floor is defined as. |
| Design 3 §12.1 signal profiles | `3` | `sig_brief` → `form_press + effect_signal_write + target_actor + recharge_cooldown_short + scaling_flat` |
| Design 5 §12.2–12.3 Status profiles | `3` | `field_brief` → `form_press + effect_status + target_area + recharge_cooldown_short + scaling_flat`, `status_verb = FIELD` |

Named compositions serve three purposes: they are the offline composer's preferred output when a thematic match exists, they are what the reference fixtures assert against, and they mean **no content from any of the five is lost in translation to the atom system** — every profile still exists, by name, resolving to identical numbers.

## 11.9 The Weapon space

**Weapons ARE affected.** An earlier revision of this section asserted they were not, and carried Design 4's `175,155,080` through unchanged. That was wrong: §11.7 adds `payload_impulse` and `payload_anchor_point`, so the `payload` dimension grows from `9` atoms to `11` and every Weapon figure moves.

Recomputed by exhaustive enumeration over the union's actual catalog and the §11.7.3 mask:

| | `USEFUL` | `HIGH` |
|---|---:|---:|
| Unconstrained slot combinations | `21,600` | `64,680` |
| Mask-legal | `12,999` | `43,240` |
| **In budget band** | **`1,210`** | **`1,539`** |
| Clause-sets available | `479` | `116,145` |
| **Distinct legal Weapons** | **`579,590`** | **`178,747,155`** |

**Total: `179,326,745` distinct legal Weapons**, against Design 4's `175,155,080` — a `1.024×` increase from `+4,171,665`.

Almost all of it lands in `USEFUL`, which grows `62%` (`356,855` → `579,590`) because two mid-cost payload atoms open many in-band combinations at that tier. `HIGH` grows only `2.3%`, since a `HIGH` Weapon's cost is dominated by its `*` atoms.

### 11.9.1 The two mask rows the new payloads need

| Atom | Rule | Why |
|---|---|---|
| `payload_impulse` | *excludes* `delivery_beam` | An impulse is a discrete push. A continuous beam has no impact moment to apply one at, and Design 2 §14.7 prices impact by momentum transfer |
| `payload_anchor_point` | *excludes* `delivery_arc`, `delivery_spread` | An anchor point is placed on the struck surface. A lobbed arc and a spread pattern do not have one determinate strike point, and Design 2 §14.6 requires attach points be exact |

Both are inherited physical facts, not balance choices. The enumeration above includes them.

---

# 12. ABILITIES, READINESS, AND COST

## 12.1 The grammar

*Pinned: identical to Design 4 §12.1* — five dimensions (`form`, `effect`, `targeting`, `recharge`, `scaling`), with §11.7's seven added `effect` atoms.

## 12.2 Compatibility mask

*Pinned: identical to Design 4 §12.4*, plus the safety rules the five established, all of which survive:

| Atom | Rule | From |
|---|---|---|
| `effect_physics_*` | *excludes* `recharge_action` | D1 §12.9, D2 §12.9 — a manipulation tool behind a combat verb can strand a player |
| `effect_physics_*` | *excludes* `target_area`, `target_cone`, `target_chained` | D2 §14.2 — verbs target one object |
| `effect_mass_field` | *requires* `target_area` or `target_point` | D2 §14.3 |
| `effect_mass_field` | *excludes* `recharge_action`, `form_hold` | D2 §12.9 |
| `effect_signal_*` | *excludes* `form_hold`, `form_channel` | D3 §12.9 — a held signal verb is a fourth kind of state |
| `effect_status` with `status_verb = SELF` | *excludes* `recharge_action` | D5 §12.6 — `phased` is traversal |
| `effect_status` with `status_verb = FIELD` | *requires* `target_area` | D5 §12.2 |
| `effect_status` with `status_verb = TRANSFER` | *requires* `target_actor`; *excludes* `status_applied` | D5 §12.3 |

Every one of these is a safety rule inherited verbatim, not a balance choice. §29.6 explains why they matter more in the union than in any single proposal.

## 12.3 Activation, preflight, recharge

*Pinned: identical to Design 1 §12.2, §12.2.1, §12.3, §12.4, §12.5, §12.7, §12.8.*

## 12.4 The `ACTION` fact catalog

The union of all five. Design 1's ten, plus Design 2's four, plus Design 3's two:

| Fact | From |
|---|---|
| `MELEE_HIT`, `WEAPON_KILL`, `AIRBORNE_KILL`, `OVERCRIT`, `DISTANCE_MOVED`, `DAMAGE_TAKEN`, `DAMAGE_BLOCKED`, `STATUS_APPLIED`, `INTERACT_USED`, `WEAPON_CYCLED` | D1 §12.6 |
| `MASS_MOVED`, `ENVIRONMENTAL_KILL`, `OBJECT_ATTACHED`, `CONSTRAINT_BROKEN` | D2 §12.6 |
| `MACRO_CHANGED`, `ROOM_REVISITED` | D3 §12.4 |

Sixteen facts. `MASS_MOVED`'s player-causation restriction (Design 2 §12.6.1) and `MACRO_CHANGED`'s already-in-that-state rule (Design 3 §12.4) both apply unchanged — without them, standing next to a pendulum or flipping a lever twice would farm readiness.

## 12.5 Hybrids

The union of all five: Design 1's five templates, plus `MANIPULATION_ADVANCES_COOLDOWN` (D2 §12.7) and `MACRO_CHANGE_REFRESHES_COOLDOWN` (D3 §12.7). Seven templates.

Contribution cap, loop prevention, and the no-hidden-second-tax rule — *pinned: identical to Design 1 §12.7*, with Design 4's `recharge_dual` as the one authored exception, high-tier only.

## 12.6 Trigger clauses

*Pinned: identical to Design 4 §12.8, §12.8.1, §12.8.2* — `14` events, `16` effects, three magnitudes, `672` clauses, authored internal cooldowns, one clause per event, caps of `1` and `2` by tier.

## 12.7 The space

Computed over the `17`-atom `effect` dimension of §11.7, the masks of §12.2, and the trigger allowances of §4.6.

| | `USEFUL` | `HIGH` |
|---|---:|---:|
| Unconstrained slot combinations | `6,000` | `18,360` |
| Mask-legal | `2,405` | `8,268` |
| **In budget band** | **`1,166`** | **`138`** |
| Clause-sets available | `479` | `116,145` |
| **Distinct legal Abilities** | **`558,514`** | **`16,028,010`** |

**Total: `16,586,524` distinct legal Abilities**, against Design 4's `5,941,874`.

The `2.8×` increase comes almost entirely from the `HIGH` tier, where in-band bases go from `48` to `138` for the reason §11.7.2 gives. `USEFUL` grows more modestly, from `766` bases to `1,166`, because the union added seven ordinary-tier effect atoms to a tier that already had plenty.

**CI asserts three floors**, and each is a regression test rather than a tuning value:

| Assertion | Floor | Why |
|---|---:|---|
| `HIGH` in-band bases, all families | `138` | Design 4 §12.5's `48` was already thin |
| `HIGH` in-band bases with a physics effect | `9` | Below this, `capability:core:manipulate` has no high-tier expression and Forge cannot elevate into it (§18) |
| `HIGH` in-band bases with a Status effect | `41` | Below this, Design 5's verb layer has no high-tier expression |

A mask change or a reprice that drops any of the three is a regression, not a balance choice.

## 12.8 Mobility

**Not composed.** *Pinned: identical to Design 1 §13* — five authored families with five authored profiles.

All of Designs 2, 3, and 5 pin Mobility unchanged, and Design 4 §12.7 explicitly exempts it from composition. The union agrees for Design 4's reason: every mandatory-route guarantee is computed against specific movement numbers, and §30.6 depends on knowing exactly what a `GRAPPLE` does.

**The exemption is total, and every other section is bound by it:**

| Question | Answer |
|---|---|
| Does a Mobility host carry a `composition`? | **No.** Its `HostDefinition` carries `profile`, the one place §4.2's "composition replaces `profile` everywhere" does not apply |
| May Epsilon compose a Mobility? | **No.** It selects one of the five authored profiles by name |
| Is Mobility Forgeable? | **No.** §18's four conversions exclude category `mobility`; Reclaim on a Mobility yields Epsilon Static only |
| Does a Mobility appear in §12.7's space? | **No.** The `16,586,524` figure counts Abilities only |
| May a Gear domain scale a Mobility? | **Yes** — `dom_speed`, `dom_jump`, `dom_mobility_recharge`, `dom_landing`, `dom_rail_control` all do, within Design 1 §16.2's clamps. Scaling a profile is not composing one |

**Why this matters more here than in Design 4.** Design 4 exempted Mobility for tidiness. The union exempts it because §29.1's `cross_long_gap`-equivalent capability is defined by a *number* — `DASH ≥ 8.0 m` — and §30.6 proves mandatory routes against it. A composed Mobility would make that number vary per item, and the traversal proof would lose its floor exactly as §29.3 describes for manipulation. **Mobility is the one host where the numbers are logic rather than balance**, and that is why it alone is authored.

---

# 13. MOBILITY

*Pinned: identical to Design 1 §13.1 through §13.6*, with Design 2 §13.7's addition: `HOLD`, `TETHER`, and `PIN` relations survive a `DASH`, `BLINK`, `BURST_JUMP`, or `AIR_STEP` if the object stays in range, and `GRAPPLE` releases every relation on attach.

---

# 14. THE MANIPULATION SYSTEM

*Pinned: identical to Design 2 §14.1 through §14.9* entire — twelve verbs, eligibility, per-verb behaviour, the §14.4 limits, mandatory manipulation, attachment, impact damage, constraint simulation, and the determinism statement.

Two notes on how it lands in the union:

**§14.5's mandatory manipulation is now verifier-backed.** Design 2 validated a required manipulation with a reference-solution replay. Here that replay still runs (§23.5 check 20, at §30.3 step 12), and *additionally* the puzzle's completion latches (§5.5) into a state-vector component the model check proves reachability across. Design 2 proved the physics works; the union also proves the Zone stays completable whatever order the player does things in.

**§14.2's eligibility now reads Status.** `LIGHTENED` and `ANCHORED` change mass class, which changes verb eligibility — Design 2 §14.2 and Design 5 §15.2 already agree on this, and in the union it is the most-used cross-system interaction in the game.

---

# 15. THE STATUS SYSTEM

*Pinned: identical to Design 5 §15.1, §15.3, §15.4, §15.5, §15.6, §15.7, §15.8* — five target kinds, the no-damage structural rule, the application pipeline, the eight compounds, trait gating, immunity and substitution, and required feedback.

## 15.2 Thirteen Statuses — modifies Design 5 §15.2

Design 5's twelve, plus `exposed` restored per §0.4:

| Status | Family | Duration | Chance | Targets | Sentence |
|---|---|---:|---:|---|---|
| *(Design 5's twelve)* | | | | | *Pinned: identical to Design 5 §15.2.* |
| `exposed` | `COGNITIVE` | `6.0 s` | `0.35` | **actor only** | *"Nothing is covering it."* |

`exposed` sets the target's Defense **stat** to `0.0` for the duration. **It does not grant crit**, per §0.4. It is actor-only because objects have no Defense stat (§15.3).

Placing it in `COGNITIVE` rather than a fifth family is deliberate: `COGNITIVE` is the family of Statuses that change how a target *relates* to the fight — what it sees, whom it fights, what it can do — and "its guard is down" belongs there. It also keeps the family count at four and the compound table unchanged.

## 15.3 The actor rule — stated honestly

An earlier revision said *"no Status applied to an actor modifies a damage number"* and then exempted `exposed` on the grounds that setting Defense to zero is *"a rule change rather than a multiplier."* **That does not survive contact with §8.** Defense is an input the damage resolver reads on every hit. Zeroing it changes the number. Calling that a rule change is a word game, and the Zero-Guesswork Standard §2.5 exists to catch exactly this shape.

The invariant is restated as the thing the architecture actually needs, which is narrower and true:

> **1. No Status directly deals or schedules Health damage.** This is Player Authority §20.1 and Law 27, and it is absolute — no exception, no Status, ever.
>
> **2. No Status applied to an actor modifies raw damage, crit chance, or crit multiplier**, and none applies a multiplier to final damage.
>
> **3. `exposed` is the single explicit exception, and it is an exception to rule 2 alone.** It sets the target's Defense **stat** to `0.0` for its duration. Defense is a stat on the target, the resolver reads it normally, and no multiplier is introduced anywhere — but the resulting number is different, and this document says so rather than defining the difference away.

Rule 1 is the authority's and admits nothing. Rule 2 is Design 5's, and it is what `brittle` and `shatterpoint` being object-and-surface-only protects. Rule 3 is the union's one named exception, declared rather than argued away.

**`exposed` is actor-only.** An earlier revision listed its targets as *"actor, object"*. Objects have no Defense stat — Design 1 §8 gives Defense to actors, and destructibles resolve through §25's four destructible classes and damage tags rather than through the Defense curve. Applying `exposed` to an object would have silently invented an object Defense field. It targets actors, and §15.2's row says so.

An owner who wants Design 1's `+1.0` crit clause back strikes rule 2 rather than this section. That is a real cost — it reopens the "apply Status, swap, consume Status for damage" pattern Player Authority §20.7 rejects — and it is why the clause is the union's one cut (§0.4).

---

# 16. GEAR AND MODS

*Pinned: identical to Design 4 §16.1, §16.2, §16.3* — composed Gear across territory, domain, and magnitude; Design 1's modifier order and runtime clamps; Mods as a clause plus an optional passive, with drawback atoms for traps.

The `domain` atom list is the union of all five proposals' intrinsic templates, deduplicated:

| Territory | Domains |
|---|---|
| `HEAD` | `dom_targeting`, `dom_information`, `dom_crit`, `dom_status_potency`, **`dom_read_stress`** (D2), **`dom_read_machine`** (D3), **`dom_read_compounds`** (D5) |
| `TORSO` | `dom_health`, `dom_barrier`, `dom_defense`, `dom_resource`, **`dom_status_duration`** (D5) |
| `ARMS` | `dom_melee`, `dom_handling`, `dom_physics`, `dom_interaction`, **`dom_relation_count`** (D2), **`dom_signal_range`** (D3), **`dom_transfer_range`** (D5) |
| `LEGS` | `dom_speed`, `dom_jump`, `dom_mobility_recharge`, `dom_landing`, `dom_rail_control`, **`dom_impact_resistance`** (D2) |

Twenty-five domains against Design 4's sixteen: eight drawn from the intrinsic templates Designs 2, 3, and 5 replaced, plus `dom_rail_control` from Design 1 §16.1, which Design 4 dropped when it cut its catalog to sixteen. Every intrinsic any of the five proposals defined survives as a domain atom, at the magnitudes that proposal gave it.

---

# 17. FOREIGN ITEMS, ARCHIVE, AND INTERPRETATION

*Pinned: identical to Design 4 §17.1 through §17.9* — classification, the compositional request and response, why Epsilon sees the costs, the six-step validation with the mask-aware repair procedure, rank-consuming duplicates, the deterministic composer, catalog versioning with `Legacy` flagging and the append-only rule, and migration.

## 17.10 One addition: named compositions in the fallback

Design 4 §17.6's deterministic composer picks atoms greedily by hash. The union adds one step before that: **if the item's provenance hashes to a named composition (§11.8) legal for its category and tier, use it.**

This meaningfully improves the offline experience, which Design 4 §41.2 named as its largest cost. A model-less campaign now produces recognisable, hand-balanced items most of the time and greedy compositions the rest, rather than greedy compositions always.

---

# 18. FORGE AND THE ECONOMY

*Pinned: identical to Design 4 §18.1 through §18.5* entire — Consolidate, Elevate, Recompose, Reclaim; the player steering category, territory, and up to two preserved atoms; Epsilon Static as the currency; Hub-only; the two-press destruction confirmation; no respec tax.

Forge is the union's answer to a question Designs 1, 2, 3, and 5 all left open and all named as their largest sacrifice. It ships here because Design 4 ships it and this proposal cuts nothing.

---

# 19. SIGNAL GRAPH

*Pinned: identical to Design 1 §19.1, §19.2, §19.4, §19.5, §19.6* — four port forms, eleven node types, delay-versus-presentation, the five conduit states, and per-node persistence categories.

## 19.3 Evaluation — modifies Design 1 §19.3

Design 1's evaluation is three steps: sensors write, nodes evaluate in topological order, actuators read. The union adds two more writers to step 1, and step 1 therefore needs an internal order it did not need before.

| Proposal | What it writes at step 1 |
|---|---|
| Design 1 | Sensor outputs |
| Design 2 §19.7 | Latched outputs — a latched node reports `ON` unconditionally |
| Design 3 §19.7 | Signal-verb overrides — `INVERT`, `HOLD_SIGNAL`, `CUT` override a node's value; `BRIDGE` adds an edge |

Three writers to the same tick is three ways to disagree. **Step 1 runs in this order, and the order is the contract:**

```
1a. Sensors write their outputs.                 # Design 1 §20
1b. Latches assert ON over any sensor result.    # Design 2 §5.7
1c. Signal verbs override the result of 1a-1b.   # Design 3 §14.1
2.  Nodes evaluate in topological order.
3.  Actuators read.
```

Two consequences follow from that order and both are deliberate.

**A latch beats its own sensor.** Once a pressure plate's condition has latched, removing the crate does not turn the node off — 1b runs after 1a and asserts `ON`. That is exactly what Design 2 §5.7 means by permanence.

A latch asserts on **exactly one node**: the one named by its `LatchCondition.expression` (§23.1). The sensor's own output is unchanged, and any other node consuming that sensor reads the live value. A plate feeding both a latched gate and an unlatched indicator lights the gate permanently and the indicator only while a crate sits on it.

**A signal verb beats a latch.** `CUT` on a latched node reports `OFF` for the verb's duration, and when the verb expires the latch reasserts at the next tick's 1b. A player can therefore *temporarily* suppress a solved puzzle but can never *un-solve* it. That is the only sane resolution: signal verbs are explicitly non-gating (Design 3 §14.4) and time-limited, latches are explicitly permanent (Design 2 §5.7 rule 4), and letting the permanent thing win a temporary contest would make `CUT` useless while letting the temporary thing win permanently would break the verifier.

`BRIDGE` still may not create a cycle, per Design 3 §19.7, and is still rejected at activation with the §34.11 feedback.

## 19.7 The Machine Graph

*Pinned: identical to Design 3 §19.8* — the two-layer split, all five rules. Room graphs read macro state and never write it; the machine graph has no logic nodes and is evaluated on macro change only; macro effects are idempotent.

**One addition: latches are room-layer, not machine-layer.** A latch belongs to its package and lives in the room graph. It is read *by* the verifier as a state-vector component (§4.10) but it is never a machine-graph variable, has no predicate, and drives no macro effect. A puzzle that should change the Zone drives a setter package's interaction, which the player then performs — the latch does not reach across rooms on its own.

This keeps Design 3 §19.8 rule 2 intact under the union. If a latch could write macro state, a physics puzzle would become a machine-graph transition with a solver in the middle of it, and §30.6's tractability argument would collapse.

---

# 20. INPUTS AND SENSORS

Eighteen types. Design 1's nine, plus nine drawn from Designs 2, 3, and 5.

| # | Type | Output | Origin |
|---:|---|---|---|
| 1–9 | `PRESSURE_PLATE`, `PULSE_BUTTON`, `TIMED_BUTTON`, `LEVER`, `SHOOTABLE_TARGET`, `OBJECT_SOCKET`, `PROXIMITY_SENSOR`, `ENCOUNTER_CLEAR`, `HACK_TERMINAL` | — | *Pinned: identical to Design 1 §20.1 through §20.4* |
| 10 | `WEIGHT_THRESHOLD` | Boolean | *Pinned: identical to Design 2 §20.5* |
| 11 | `CONSTRAINT_STATE` | Value `[0,15]` | *Pinned: identical to Design 2 §20.5* |
| 12 | `ATTACH_SENSOR` | Boolean | *Pinned: identical to Design 2 §20.5* |
| 13 | `MACRO_STATE` | Boolean | *Pinned: identical to Design 3 §20.5* |
| 14 | `MACRO_SELECTOR` | Value `[0,15]` | *Pinned: identical to Design 3 §20.5* |
| 15 | `ROOM_VISITED` | Boolean | *Pinned: identical to Design 3 §20.5* |
| 16 | `STATUS_SENSOR` | Boolean | *Pinned: identical to Design 5 §20.5* |
| 17 | `STATUS_VOLUME_SENSOR` | Value `[0,15]` | *Pinned: identical to Design 5 §20.5* |
| 18 | `COMPOUND_SENSOR` | Boolean | *Pinned: identical to Design 5 §20.5* |

Every rule attached to each sensor in its origin proposal is inherited unchanged: the semantic-mass rule on `PRESSURE_PLATE`, the `[RANGED]` requirement on mandatory `SHOOTABLE_TARGET`s, the single-object satisfiability rule on `WEIGHT_THRESHOLD`, `CONSTRAINT_STATE`'s quantisation, and `ROOM_VISITED`'s monotonicity.

## 20.6 The mass-reading trio

Three of the eighteen read mass, and a player who does not know which is which will be confused by a door that opens for one crate and not another. The distinction is a rule, not tuning:

| Sensor | Reads | Accumulates? |
|---|---|---|
| `PRESSURE_PLATE` | Semantic `MassClass` | **No.** Three `LIGHT` never make a `MEDIUM` (Design 1 §20.1) |
| `WEIGHT_THRESHOLD` | Summed `mass_kg` | **Yes**, and it is the only sensor that does (Design 2 §20.5) |
| `CONSTRAINT_STATE` | A constraint's value, quantised | Indirectly — mass moves the constraint |

Presentation carries the difference, per Dungeon Authority §50: a `PRESSURE_PLATE` displays a class glyph, a `WEIGHT_THRESHOLD` displays a filling bar. A player never has to guess which kind of mass a floor plate wants.

## 20.7 Status sensors and the verifier

A `STATUS_SENSOR`, `STATUS_VOLUME_SENSOR`, or `COMPOUND_SENSOR` may drive any node in a room graph. It may **never** drive a topology-edge predicate, and it may reach a mandatory route only through a latch. §30.6 property 8 states this formally and §23.5 check 29 enforces it at composition.

The rule is what keeps thirteen Statuses and eight compounds out of the state vector while letting Status puzzles gate real progress: the Status sets the latch, the latch is permanent, and the Status is free to expire two seconds later. The verifier sees a monotone Boolean and never learns that `updraft` exists.

---

# 21. ACTUATORS AND MACHINERY

Twelve actuator kinds: Design 1's nine kinematic, plus Design 2's three constraint-driven.

*Pinned: identical to Design 1 §21.1 (common contract and transition table), §21.2 through §21.9* — door interlocks, platform velocity inheritance, lift selectors, path machines, rail-switch clearance, the LaunchPad arc solver, hazard and light controllers.

*Pinned: identical to Design 2 §21.10* — `WINCH`, `BRAKE`, and `DRIVER`, with all five of its rules including the reference-solution requirement on mandatory routes.

*Pinned: identical to Design 3 §21.10* — the ten macro effect types and all four of their rules, including the hazard-activation guard.

## 21.1.1 Power loss — modifies Design 1 §21.1.1

Design 1's per-kind table gains three rows.

| Kind | On power loss |
|---|---|
| *(Design 1's nine)* | *Pinned: identical to Design 1 §21.1.1.* Doors close under interlock; everything that carries the player holds; launchpads go inert; hazards disable; lights go `unlit`. |
| `WINCH` | **Holds** its current length. A rope does not lengthen because a generator stopped. |
| `BRAKE` | **Engages**, whatever its input says. Fail-safe: an unpowered brake is a locked brake. |
| `DRIVER` | **Releases torque, and its hinge locks at the current value** under an implicit brake. |

Design 2 §21.10 states that all three "hold position on power loss." Under Design 2 alone that sentence is sufficient, because power loss there is a rare authored event. Under the union it is not, and this is a defect the merge creates rather than inherits: Design 3's `POWER_OFF` macro effect makes power loss a **routine, player-caused, whole-room** event. A player who reroutes power away from the gantry room has just cut power to every winch, brake, and driver in it, possibly while standing under a suspended girder.

So "holds position" is made per-kind and explicit above. The safety property it buys: **no power change can put a simulated mass in motion.** A winch holds, a brake locks, a driver's hinge locks. Nothing swings, drops, or unspools because the lights went out.

## 21.11 Macro effects and the player's physical position

Design 3 §21.10's rules protect the player from macro effects in two ways: actuators animate rather than teleport when the player is present, and `HAZARD_ON` waits for the player to leave the hazard volume. The union adds a third guard of the same shape, for the same reason:

**`POWER_OFF` on a room where the player is supported by, riding, or attached to a constrained body is deferred until they are not.** Supported means standing on a body whose only support is a `WINCH` or `DRIVER`; riding means a `TETHER` or `ATTACH` relation to a moving constrained body; attached means the player's own Mobility relation terminates on one.

The deferral is visible: the control point reports `waiting — someone is on the gantry` in the §34.12 macro-change feedback, and the change applies the moment the condition clears. It is never silently dropped, and it never expires — a queued `POWER_OFF` survives until it applies.

**The deferral is bounded by geometry, not by Statuses.** A previous revision argued it "cannot deadlock" because movement-removing Statuses expire. That argument is wrong twice: a player may simply *choose* to stand on the gantry forever, and base movement existing does not prove the geometry offers a way off. The real guarantee is a composition obligation:

> **§30.5 check 21.** Every constrained body that a reachable `POWER_OFF` can affect, and that the player can stand on, ride, or attach to, has a **base-movement-safe egress** — a surface reachable from it by §6.2's movement law alone, under every reachable macro state, with no offer geometry and no capability.

With check 21 the deferral is bounded by the player's own choice rather than by the world: they can always step off, and if they do not, nothing bad happens — the change simply waits. An indefinite wait by choice is not a deadlock, and §33.10 renders the notice persistently so the choice is informed.

### 21.11.1 A queued macro change is saved state

| Question | Rule |
|---|---|
| **Serialized shape** | `PendingMacroChange { variable, target_state, source_room, queued_at_tick }`. At most one per variable |
| **Persistence category** | `ROOM_PERSISTENT`, scoped to the Zone. It survives save, load, death, and room unload |
| **Save/load order** | Restored at §5.6 step 7, after macro state and after actuators, before encounters. On restore the guard is **re-evaluated** rather than trusted: if the player no longer occupies the protected relation, it applies immediately on the first tick |
| **Room unload/reload** | Unaffected. The guard is about the player's relation, not the room's residency |
| **Zone exit** | Discarded. A queued change is Zone-scoped and the Zone is being left |
| **Same state requested again** | **Absorbed.** Macro effects are idempotent (§19.7 rule 5); the queue is unchanged and the control reports the existing wait |
| **A *different* state of the same variable requested while one is queued** | **Latest wins, explicitly.** The queued change is replaced by the new one, `queued_at_tick` resets, and the originating control reports `replaced — now waiting to set <state>`. First-wins would let a player accidentally lock a variable to a stale intention by touching a lever once |
| **Different variable** | Independent. Each variable has its own slot; queues never interact |
| **Player dies while queued** | The queue survives; the guard clears on respawn because the player is no longer on the body, so it applies on the next tick |

Latest-wins is the one policy choice here and it is recorded in §41.3 as such.

Without this rule, the union's most obvious emergent action — reroute power while a friend is on the crane — is an unavoidable death with no telegraph, which Dungeon Authority §25 forbids and which neither Design 2 nor Design 3 could have anticipated alone.

---

# 22. HACKING

*Pinned: identical to Design 1 §22.1, §22.2, §22.3* — one reusable route-connection minigame, three difficulties, no timer, no failure state, exits preserve tile rotations.

*Pinned: identical to Design 3 §22's addition* — a hack terminal may be a macro setter, which is how "reroute power from security to the lift" becomes an act rather than a lever pull.

Hacking is the one system all five proposals left completely alone. It stays that way.

---

# 23. PUZZLE-PACKAGE CONTRACT

*Pinned: identical to Design 1 §23.2 (room offers), §23.3 (completion and AP), §23.6 (deterministic failure).*

## 23.1 The manifest

Design 1 §23.1's fields, plus every field any proposal added. Ten additions, no removals.

```
PackageManifest:
  id                  : Id
  family              : one of the thirty-four in §24
  required_offers     : list[OfferRequirement]
  objects             : list[ObjectPlacement]
  nodes               : list[NodePlacement]
  actuators           : list[ActuatorPlacement]
  reset_group         : Id
  persistence         : enum { PUZZLE_LOCAL, ROOM_PERSISTENT }
  capability_required : Id? = null
  optional_solutions  : list[enum { PHYSICS, MOBILITY, COMBAT, ALTERNATE_INPUT, STATUS }]
  timing_window       : Seconds? = null
  budget              : PackageBudget

  constraints         : list[ConstraintSpec] = []      # Design 2
  physics_permitted   : bool = true                    # Design 2
  reference_solution  : ReferenceSolution? = null      # Design 2
  latch_conditions    : list[LatchCondition]           # Design 2
  settle_timeout      : Seconds = 8.0                  # Design 2

  macro_setter        : MacroSetter? = null            # Design 3
  macro_predicate     : Predicate?   = null            # Design 3
  cross_room_objects  : list[Id] = []                  # Design 3

  status_required     : Id? = null                     # Design 5
  status_source       : Id? = null                     # Design 5

  vector_latches      : list[int] = []                 # NEW — see below
  status_solution     : StatusSolution? = null         # NEW — §35.2.2
```

`ReferenceSolution`, `SolutionStep`, `LatchCondition`, and `MacroSetter` are *pinned: identical to Design 2 §23.1 and Design 3 §23.1*.

**`StatusSolution` is new**, and it is what §35.2.2's guarantee and §30.5 check 22 actually read. A validator may not test a field the schema cannot represent:

```
StatusSolution:
  source_id        : Id            # the in-room status_source, per Design 5 §23.1
  status_id        : Id            # one of the thirteen, or a compound
  target_id        : Id            # the exact object or actor the solution applies it to
  reserved_bodies  : int >= 0      # capacity reserved per §35.2.1
  reserved_entries : int >= 0
```

A package with a non-null `status_required` **must** carry a `status_solution` whose `source_id` equals `status_source` and whose `status_id` equals `status_required`. `guaranteed_application` is not a stored flag: it is **derived** as *"this application's `(source_id, status_id, target_id)` equals this package's `status_solution` triple"*, evaluated at application time. Check 22 tests the manifest fields above; the runtime tests the triple.

**`vector_latches` is the union's one new field.** It names which of the package's `latch_conditions` are promoted into the Zone state vector (§4.10). A latch not named here is still permanent and still latches — it simply is not something the verifier reasons about, because nothing on a mandatory route depends on it.

The field exists because the state vector has a hard budget of `4096` and latches now compete with macro variables for it (§4.10). A room full of optional physics puzzles would otherwise blow the budget with latches no route needs. Naming them explicitly makes the allocation a composition decision rather than an accident of package selection, and §30.3 step 8 makes it.

## 23.4 Reset — modifies Design 1 §23.4

*Pinned: identical to Design 2 §23.4* — the nine-step ordered restore with constraint destruction bracketing the position restore, and the rule that reset never clears a latch.

Two clauses added for the union:

10. **Statuses on the package's objects are cleared.** They are `EPHEMERAL` (Design 5 §5.13); reset is a reload boundary and they do not survive it.
11. **Macro state is untouched.** Reset is package-scoped. A setter package resetting does not un-set its variable, exactly as it does not un-confirm a Check.

Clause 11 matters more than it looks. Reset is how a stuck puzzle recovers, and a reset that reverted macro state would make the recovery mechanism itself a way to lose progress — which is the softlock class §30.6 property 2 exists to eliminate, reintroduced through the back door.

## 23.5 Validation pipeline

Design 1's eighteen checks, plus eight from Designs 2, 3, and 5, plus five the union creates (`27`, `28`, `29`, `30`, `31`) and one sub-numbered addition (`22a`). **All thirty-two ids are unique**; the union's additions are numbered above the inherited range rather than reusing it.

| # | Check | Origin |
|---:|---|---|
| 1–18 | *Pinned: identical to Design 1 §23.5.* | D1 |
| 19 | No latch condition depends on a physical quantity finer than `0.05 m` positional or `0.05 rad` angular. | D2 |
| 20 | Every package with `capability_required = manipulate`, or containing a `WINCH`, `BRAKE`, or `DRIVER` on a mandatory route, has a `reference_solution` that latches every `latch_condition` within `max_duration`, replayed headless three times at fixed `8`-iteration solver settings. All three must latch. | D2 |
| 21 | Every `WEIGHT_THRESHOLD` on a mandatory route is satisfiable by a single authored object present in the room. | D2 |
| 22 | The package's initial configuration reaches `sleeping = true` on every object within `settle_timeout`. | D2 |
| 23 | Every setter package's `sets_to` states appear in its variable's `states`, and its room is in the variable's `setters` list. | D3 |
| 24 | Every `cross_room_objects` entry has an `allowed_volume` covering every room between its `home_transform` and every consuming socket, under at least one reachable macro state. | D3 |
| 25 | A package with a non-null `status_required` has a non-null `status_source` in the same room, reachable and operable using base movement and the permanent baseline. | D5 |
| 26 | Every `requires_trait` a required Status needs is present on the target the package expects it on. | D5 |

Three further checks are new to the union, and each closes something no single proposal could have hit.

| # | Check | Why it is new |
|---:|---|---|
| **27** | **Every index in `vector_latches` names a real entry in `latch_conditions`, that entry has `latches = true`, and the package's `capability_required` is `null` or in the Zone's minimum proven set.** | A state-vector component the verifier can never set is worse than useless: it doubles the search space and adds an unreachable half. |
| **28** | **No `DRIVER` on a mandatory route drives a hinge whose free rotation — after the §21.1.1 implicit brake releases at its limits — can leave the route impassable, unless a `BRAKE` on the same hinge is on the same signal.** | Design 2's `DRIVER` never faced routine power loss. Under the union it does (§21.11), and a drawbridge held up by torque alone is a softlock waiting for a control room three rooms away. |
| **29** | **No `STATUS_SENSOR`, `STATUS_VOLUME_SENSOR`, or `COMPOUND_SENSOR` output reaches a mandatory-route actuator or a `macro_setter` enable except through a node listed in `latch_conditions`.** | This is §30.6 property 8 enforced locally, and it is the rule that keeps the entire Status layer out of the state vector. |
| **22a** | **Physical invariance: a package whose latch is a `vector_latch` is unaffected by every `MacroEffect` reaching its room**, outside §23.5.1's enumerated harmless set. | Stated in full in §23.5.1; listed here so this table is the complete index of the thirty-two checks rather than thirty-one of them. |
| **31** | **`ReferenceSolution.max_duration ≤ MAX_REPLAY_DURATION = 12.0 s`** (§35.4.1). | The replay budget is built from this bound; an unbounded `max_duration` makes the composition budget unbounded. Numbered `31` rather than `23`: check `23` is Design 3's setter validation, and two rows sharing an id makes every citation ambiguous. |
| **30** | **Every mandatory manipulation package's reference solution latches when replayed by a synthetic provider at exactly `700 N` / `20.0 m` / `120 kg`** (§29.3.2). | A package that latches only above the envelope is solvable by some qualifying providers and not others, which is the soundness gap §29.3.1 closes. |

### 23.5.1 Replay context — which macro states a reference solution must survive

A reference solution proven in one physical configuration does not prove the Latch transition is possible in every configuration §30.6 permits it from. A macro effect can cut power to the room's `WINCH`, disable the hazard the solution used, retract the gantry the crate sat on, or re-route the rail that delivered it — and the verifier would still call the Latch transition legal.

The union takes the **invariance** branch rather than the replay-every-state branch, because replaying every macro-state class multiplies §35.4.1's `10.8 s` by up to `4` per variable:

> **§23.5 check 22a — physical invariance.** A package whose latch is a `vector_latch` must be **physically invariant** under every `MacroEffect` that can reach its room. Formally: for every `(variable, state)` pair whose effects include the package's room, applying that effect changes no object, constraint, actuator, or surface the package's `reference_solution` touches.

The enumerated harmless set — effects that may reach a replay-backed package's room:

| Effect | Permitted | Why |
|---|---|---|
| `LIGHT_ON` / `LIGHT_OFF` | **Yes** | Lighting never gates (Design 1 §21.9) and touches no body |
| `ENCOUNTER_ENABLE` | **Yes** | Enemies never move objects (§32.4) |
| `SECRET_REVEAL` | **Yes** | Adds geometry elsewhere in the room |
| `HAZARD_ON` / `HAZARD_OFF` | **Only if** no hazard volume intersects the solution's swept path | A hazard that kills the player mid-solution changes whether it can be executed |
| `POWER_ON` / `POWER_OFF` | **No**, if the package contains a `WINCH`, `BRAKE`, or `DRIVER` | Power changes what the mechanism does |
| `ACTUATOR_STATE` | **No**, if the named actuator is in the package | It moves the geometry the solution used |
| `RAIL_ROUTE` | **No**, if a routed rail delivers an object the solution uses | It changes where the object is |

A package failing check 22a is rejected at §30.3 step 12 and the room retries, exactly as a failed replay is. **One replay then proves the transition in every configuration the model check permits**, because the package's physics cannot differ between them.

Check 20 remains the expensive one — a headless physics replay, three runs, per manipulation package, per composition, in the canonical environment with its verdict committed (§30.11.8). Check 29 is nearly free and is the most load-bearing check in the document.

---

# 24. THE THIRTY-FOUR PUZZLE FAMILIES

Every family any proposal shipped, deduplicated. Design 1's eighteen, Design 2's eight new, Design 3's four new, Design 5's four new. Design 4 shipped no new families.

| # | Family | Origin |
|---:|---|---|
| 1 | `CARRY_TO_PLATE` | D1 |
| 2 | `INSERT_COMPONENT` | D1 |
| 3 | `PULSE_REMOTE` | D1 |
| 4 | `TIMED_TRAVERSE` | D1 |
| 5 | `SHOOT_TARGET` | D1 |
| 6 | `TOGGLE_ROOM_STATE` | D1 |
| 7 | `HACK_OVERRIDE` | D1 |
| 8 | `DUAL_INPUT` | D1 |
| 9 | `ALTERNATE_INPUT` | D1 |
| 10 | `ROUTE_SWITCH` | D1 |
| 11 | `MOVING_MACHINE` | D1 |
| 12 | `BOMB_BARRIER` | D1 |
| 13 | `ENCOUNTER_GATE` | D1 |
| 14 | `OBSERVATION_TARGET` | D1 |
| 15 | `A_B_STATE` | D1 |
| 16 | `LOCAL_KEY_LOOP` | D1 |
| 17 | `MULTI_STAGE_MACHINE` | D1 |
| 18 | `DUNGEON_STATE_CHANGE` | D1 |
| 19 | `PUSH_TO_PLATE` | D2 |
| 20 | `COUNTERWEIGHT_LIFT` | D2 |
| 21 | `SEESAW_ROUTE` | D2 |
| 22 | `PENDULUM_TIMING` | D2 |
| 23 | `BRIDGE_ASSEMBLY` | D2 |
| 24 | `WINCH_HAUL` | D2 |
| 25 | `TETHER_ROUTE` | D2 |
| 26 | `MASS_GATE` | D2 |
| 27 | `MACRO_SETTER` | D3 |
| 28 | `POWER_ROUTE` | D3 |
| 29 | `CROSS_ROOM_FETCH` | D3 |
| 30 | `RAIL_NETWORK` | D3 |
| 31 | `STATUS_GATE` | D5 |
| 32 | `CONDUCTION_ROUTE` | D5 |
| 33 | `PHASE_PASSAGE` | D5 |
| 34 | `COMPOUND_LOCK` | D5 |

Each family's shape, offers, and reference fixture are *pinned to the proposal that defined it*. Design 2 declared `PUSH_TO_PLATE` a replacement for `CARRY_TO_PLATE`; here both ship, because a crate you carry and a crate you shove are different rooms and the union cuts nothing. Design 2's absorption arguments for `BOMB_BARRIER` and `OBSERVATION_TARGET` were budget decisions, not compatibility ones, and do not apply.

**Still not shipped:** `ENERGY_ROUTE` and `BEAM_RECEIVER`. Every proposal deferred them with the routed-beam system in §2.2, and the union defers only what all five defer. Thirty-four of the Dungeon Authority's twenty named families plus fourteen invented ones.

## 24.1 Family count and generation variety

Thirty-four families against Design 1's eighteen is the single largest driver of room variety in this proposal, and it is the clearest place where the union is measurably better than any input rather than merely larger.

### 24.1.1 `PACKAGE_DENSITY` — the one Amalgam table

An earlier revision analysed Zones as `2`–`4` packages per room, giving `16`–`48` per Zone. **That population is not one the composer ever generates.** Design 1 §30.3's actual density is per-purpose and much lower, and the union inherits it. One table, and §30.3 step 11 reads only this:

| Purpose | Packages |
|---|---:|
| `environmental_puzzle`, `routing_puzzle`, `observation_puzzle` | `2` |
| `junction` | `2` |
| `control_room` | `1` (§30.4: exactly one setter package, no encounter) |
| `traversal`, `vertical_ascent` | `1` |
| `arena`, `ranged_arena`, `holdout` | `1` |
| `boss_arena` | `0` |

Against the seeded cyclic rotation of §30.3.0, the package count depends on both room count and offset. Computed over all `5 × 14` pairs:

| Rooms | Min | Max | Mean |
|---:|---:|---:|---:|
| `8` | `8` | `11` | `9.64` |
| `9` | `9` | `13` | `10.86` |
| `10` | `11` | `14` | `12.14` |
| `11` | `12` | `15` | `13.36` |
| `12` | `13` | `16` | `14.57` |

**Overall range `8`–`16`, mean `12.11`.** A previous revision gave exact per-size counts, which was only true while the rotation was truncated to a fixed twelve-entry prefix; with a seeded offset the count is a distribution, and it is stated as one.

**What thirty-four families actually buys**, at the mean package count `k = 12`, 60,000 trials per cell:

| Families | Distinct | Duplicate placements | Most-repeated family |
|---:|---:|---:|---:|
| `12` (D4) | `7.77` | `4.23` | `2.88×` |
| `18` (D1) | `8.94` | `3.06` | `2.47×` |
| **`34`** | **`10.24`** | **`1.76`** | **`2.05×`** |

**Repeats do not disappear and it would be dishonest to say they do.** A mean Zone still places `1.76` duplicates. What changes is the number a player notices: the most-repeated family appears `2.05` times rather than `2.47` at Design 1's catalog and `2.88` at Design 4's, and duplicate placements fall **`42%`** against Design 1 and **`58%`** against Design 4.

Those percentages are unchanged from the previous revision's recomputation, and re-deriving them over the corrected `8`–`16` distribution rather than the truncated `11`/`13`/`16` counts is what confirms they were not an artifact of the wrong population.

That is the honest form of the "more fun" claim: not that any one puzzle is better, and not that repetition ends, but that the same room shape shows up around `40%` less often.

---

# 25. HAZARDS AND DESTRUCTION

*Pinned: identical to Design 1 §25.1 through §25.5* — the hazard contract, six hazard families, four destructible classes including `REACTIVE_BARREL`, environmental kill credit, and the enemy-participation table.

*Pinned: identical to Design 5 §25.6* — the material trait set, which replaces Design 1 §25.0's six traits with Design 5's larger set. Design 5's is a superset and is what the thirteen Statuses gate against.

*Pinned: identical to Design 5 §25.7* — Status-applying hazards.

*Pinned: identical to Design 2 §25.6 and §25.7* — the two physical additions and physical environmental kill credit.

**The one merge decision.** Design 2 and Design 5 both extend environmental kill credit, from different directions: Design 2 credits the player for a crate they pushed, Design 5 for a Status they applied. Both rules ship, and where both apply — a `brittle` crate the player pushed onto an enemy — **credit resolves to the most recent player action**, which is Design 1 §25.4's existing tiebreak applied to a case it did not anticipate. No new rule is needed.

---

# 26. ROUTING, FORCES, AND CONSTRAINTS

*Pinned: identical to Design 1 §26.1, §26.2, §26.3, §26.5* — conveyors, fans and force volumes, hazard routing, and the anti-cheese rules on force stacking.

*Pinned: identical to Design 2 §26.5* — the eight constraint kinds, genuinely simulated, with their limits, break thresholds, and solver settings.

*Pinned: identical to Design 3 §26.4 and §26.6* — player rails and rail networks with multi-junction routing set by macro state.

## 26.7 Rails and constraints do not mix

A player riding a rail is kinematically driven (Design 1 §26.4). A constrained body is solver-driven (Design 2 §26.5). The union states the boundary once so that no package has to discover it:

- **A rail may not pass through a constrained body's swept volume.** Rejected at composition as §30.5 check 15.
- **A player on a rail holds no manipulation relations.** Entering a rail severs every relation **the player holds** — `HOLD`, `PIN`, and any `TETHER` whose other end is the player — per Design 2 §13.7's Mobility rule applied to rails. The relation is severed, not suspended; the object settles where it was. Object-to-object relations the player created earlier — a `TETHER` between two crates, an `ATTACH` between a girder and an anchor — are **untouched**, because they are properties of the world rather than of the rider.
- **A `RAIL_ROUTE` macro effect obeys Design 1 §21.6's clearance rule**, which already queues a junction change while an actor is within `10.0 m`.

The third rule is inherited, not new, and is called out here because Design 3's macro effects can now change a junction from another room entirely — the clearance rule is what stops that from being a remote kill.

---

# 27. MEDIA

*Pinned: identical to Design 1 §27* — the media contract, and the deferral of water, gas, and pressure.

*Pinned: identical to Design 2 §27.5* — local gravity **magnitude** volumes. Directional gravity remains deferred per §2.2.

---

# 28. ROOM AND ZONE TOPOLOGY

*Pinned: identical to Design 1 §28.1, §28.2, §28.5, §28.6, §28.7* — room-local transformations, one-way shortcuts, local keys, secrets, and the twenty base offer types.

*Pinned: identical to Design 3 §28.3* — macro variables replace Design 1's four forward-only Zone flags. Up to eight variables of two to four states, reversible by default. Design 1's flags remain expressible as `reversible = false` two-state variables, per fork 1.

*Pinned: identical to Design 3 §28.4* — predicated topology, including the rule that a false predicate is visibly false.

## 28.8 Offer types

Design 1's twenty, plus four.

| Offer | Origin |
|---|---|
| *(Design 1's twenty)* | *Pinned: identical to Design 1 §28.7.* |
| `constraint_anchor` | D2 §28.8 — a world point a package may anchor an authored constraint to |
| `attach_surface` | D2 §28.8 — a surface a package may place attach points on |
| `macro_control` | D3 §28.8 — a location a setter package may bind its control point to |
| `rail_junction` | D3 §28.8 — a location a rail network may place a junction |

Twenty-four offer types. Every shell in the library declares which it provides, and §30.3 step 11 matches packages to shells through them exactly as Design 1 does.

---

# 29. CAPABILITY PROGRESSION

## 29.1 The five capabilities

*Pinned: identical to Design 2 §29.1.* Design 1's four, plus `capability:core:manipulate`, granted only by a `PUSH`, `PULL`, or `HOLD` verb and never by the other nine.

## 29.2 Proof, entry, optional routes

*Pinned: identical to Design 2 §29.2, §29.4, §29.5* — proof before requirement with no in-Zone capability acquisition, entry validation that blocks and explains with the §34.4 message, and optional routes that may require anything and are never validated for reachability.

## 29.3 The `manipulate` contract — modifies Design 2 §29.3

Design 2 validates every mandatory manipulation against **the least capable granting profile**, `ab_physics_light`: `700 N`, `20.0 m` range, `120 kg` verb mass limit. That is well-defined in Design 2 because its profiles are a closed, hand-authored set of three.

**Under composition it is not, and this is the sharpest seam in the union.** Design 4 §11.4 resolves an Ability's numbers from its atoms and its scaling atom, so Epsilon can compose a `PUSH` Ability that is *weaker* than `ab_physics_light`. A player holding only that Ability would pass a Boolean-only entry check, walk into a Zone whose mandatory puzzle was authored at `700 N`, and be unable to move the crate. §30.6 cannot see it, because the verifier treats `manipulate` as a Boolean and never reasons about newtons.

### 29.3.1 Two different questions, and the earlier revision answered only one

A prior revision replaced the numeric floor with pure verb-set membership and concluded that *"a composed Ability cannot be too weak to satisfy a gate — only present or absent."* **That conclusion does not follow.** If two `PUSH` providers resolve to different force, range, and mass limits, one can physically fail to shift an object the other shifts, while both satisfy the same Boolean. Membership answers *"is this a manipulation Ability"*; it does not answer *"can this one move the crate."*

The repair separates the two questions and gives each its own home:

| Question | Answer | Who reads it |
|---|---|---|
| **Capability identity** — is `manipulate` present? | Boolean. Membership in `{PUSH, PULL, HOLD}` over `physics_verb` | §30.6's verifier, §29.5's monotonicity argument. **Finite, and unchanged** |
| **Provider qualification** — does this host count as the *guaranteed* provider for a mandatory route? | The resolved host meets the mandatory-route envelope | §29.4's Zone-entry validation. **Never the verifier** |

### 29.3.2 The mandatory-route envelope

*Pinned: identical to Design 2 §29.3's contract.* A host **qualifies** as a `manipulate` provider for mandatory-route purposes when its resolved values are all of:

| Parameter | Minimum |
|---|---:|
| Force | `700 N` |
| Range | `20.0 m` |
| Verb mass limit | `120 kg` |

Four rules follow, and together they close the soundness gap without putting a newton anywhere near the state vector:

1. **Every mandatory manipulation puzzle is authored against this envelope and no other.** §23.5 check 20's reference solution is replayed by a synthetic provider at exactly `700 N` / `20.0 m` / `120 kg`. If the solution does not latch at the minimum, the package is rejected — so a package that passes is solvable by *every* qualifying provider, not merely by a strong one.
2. **§29.4's entry validation counts only qualifying providers.** A player whose only `PUSH` Ability resolves below the envelope does not satisfy the entry check, is told so with the §34.4 message, and cannot enter a Zone whose mandatory route needs it.
3. **A sub-envelope host is still real content.** It manipulates, it solves optional routes, it is Forgeable and composable and fun. It simply is not the thing that unlocks a gated Zone, exactly as a `DASH` under `8.0 m` does not satisfy `long_gap`.
4. **The verifier is untouched.** §30.6 still sees one Boolean whose value is fixed for the Zone, and §29.5's monotonicity argument holds verbatim, because a richer loadout can only add qualifying providers.

**Where qualification is computed.** At §29.4's entry check, from the **resolved committed Loadout**, and nowhere else. It is a pure function of `(host composition, equipped Gear, active Mods)` evaluated at that moment — not a stored field (§4.2). Gear may raise a host's numbers, and because qualification is recomputed at entry, a player cannot qualify by equipping Gear they then remove.

**Why the previous revision's argument was appealing and wrong.** It is true that a numeric floor on every granting composition would be a maintenance burden forever. But the alternative it chose — declaring the numbers irrelevant to logic — quietly moved the failure from composition time to the player standing in front of an immovable crate. The envelope is not a floor on *what may be composed*; it is a floor on *what counts as a guarantee*, which is a much smaller claim and the one Design 2 actually made.

## 29.4 Entry validation

*Pinned: identical to Design 1 §29.3 and Design 2 §29.4.* Requirements are shown before entry and block it, with the §34.4 message listing qualifying Archive entries.

## 29.5 Capabilities inside the verifier

*Pinned: identical to Design 3 §29.5.* The proven set is constant for a Zone, composition verifies against the minimum required set, and a Zone verified for the minimum is verified for every richer set.

**This is where fork 6 actually resolves.** Design 2 needed `manipulate` to be a capability so that mandatory physics could be validated. Designs 1, 3, 4, and 5 refused physics gating because they had no way to prove it safe. Design 3's monotonicity argument makes the fifth capability free: it is a parameter of the search, not a dimension of it, so a fifth capability costs exactly one more term in the entry check and zero additional search.

What is *not* free is the physical half — proving that a required manipulation is actually performable. That is §23.5 check 20's headless replay, and it is the union's single largest composition cost. §35 budgets it and §41.2 names it as the top risk.

## 29.6 Status is never a capability

*Pinned: identical to Design 5 §29.5.* No Status appears in any capability, no mandatory route requires a Status the player cannot guarantee from an in-room source, and the capability planner never reasons about Status.

Together with §23.5 check 29 and §30.6 property 8, this is the third of three independent guards keeping the verb layer out of progression proof. Three guards for one property is deliberate: it is the property whose failure would make the union's verification intractable rather than merely wrong.

---

# 30. PROCEDURAL COMPOSITION

## 30.1 What Epsilon chooses — rebased on the 2026-09-04 runtime ruling

Design 1 §30.1 says Epsilon chooses **nothing** in Zone composition. **That is superseded**, and the superseding fact is a runtime discovery rather than a design preference:

> Every chamber in the recorded played Zone carried `shell_id: null`. Epsilon emitted a chamber `type` and nothing wrote an authored shell id, so `ContentInstantiator` fell through `SHELL_FOR_TYPE` to a `*_proc` shell. All 23 chambers in the played Zone were procedural. **No authored room had ever appeared in a played Zone.**

The owner ruling that followed makes authored composition and live movement the joint-first milestone, with 3B reserved to put authored `shell_id` values through the real Epsilon → played-Zone path. A final design that keeps Epsilon out of Zone composition entirely would specify a seam the project has already decided to close, so this section is rebased rather than defended.

**What changes is exactly one selection. What does not change is everything else.**

| Epsilon chooses | Epsilon does not choose |
|---|---|
| **One `shell_id` per room, from the bridge-supplied offered catalog for that room's type and purpose** | Room count, topology, edges, or predicates |
| **The Zone's `theme`, `display_name`, and `designer_note`** — an **Amalgam extension**, not inherited; see below | Macro variables, their states, or their setters |
| Which items to compose (§17) | Package selection, placement, or parameters |
| | Transforms, metres, node graphs, completion logic, or any balance number |

**On theme, name, and note.** A previous revision cited these as *"pinned: Design 1 §30.1"*. **Design 1 §30.1 authorises no such thing** — it says *"Nothing in Zone composition. Composition is entirely deterministic and bridge-owned."* Attributing them to it was wrong. They are an Amalgam extension with a bounded schema, and they are listed here as one:

```
ZonePresentation:
  theme          : Theme          # a closed enum, from the authored theme catalog
  display_name   : string, 1..64 chars
  designer_note  : string?, 0..280 chars, default null
```

`theme` selects from a closed enum. `display_name` and `designer_note` are **presentation strings that no system reads** — they are never parsed, never matched, never compared, and never affect composition, validation, or the model check. They exist so a Zone has a name a player can remember, and §30.5 check 19a rejects any Zone whose presentation strings exceed their bounds or whose theme is outside the catalog.

That is the project's existing bounded-choice philosophy applied one level up: **developers author the alphabet — the shells — the bridge proves and filters legality, Epsilon selects within the closed offered set, and Godot consumes only validated committed data.** A shell id is a name from a finite list, exactly as an atom id is. It is not procedural authority.

**Nothing else about §30.3 moves**, but the determinism claim has to be split in two, because a model response is not reproducible by re-asking. §30.5.1 defines the two properties and §30.11.7 supplies the artefact that makes the second one hold.

## 30.2 Zone shape

Design 3's shape, with two rows added and one bound tightened.

| Property | Value |
|---|---|
| Rooms | `8` to `12` |
| Edges | `10` to `20` |
| Independent cycles | `1` to `4` |
| Entry, exit | One each, distinct rooms |
| Macro variables | `2` to `8` |
| Setter packages | `2` to `8`, at most one per variable per room |
| Local keys | `0` to `4` |
| **Vector latches** | **`0` to `8`** |
| **Bodies participating in a constraint, Zone-wide** | **`0` to `40`** |
| **Packages requiring a §23.5 check 20 replay** | **`0` to `12`** |
| **State-vector bound** | product of all state counts ≤ `4096` |

Rooms fall from Design 3's `8–14` to `8–12`, and edges from `22` to `20`. That is not a content cut — every family, verb, Status, and atom still ships — it is a **composition-cost** reduction, and it is forced by §23.5 check 20: a Zone with fourteen rooms of physics packages is fourteen rooms of headless replays, three runs each. Design 2 reached the same conclusion from the same check and set the same ceiling.

The product-graph bound is therefore `4096 × 12 = 49,152` configurations, down from Design 3's `57,344`.

## 30.3 Composition algorithm

Deterministic given `(zone_seed, progression_state, ap_catalog)`. Design 3's fourteen steps, with three inserted.

```
 1. rng = seeded(zone_seed)
 2. room_count = 8 + rng.range(0, 4)            # inclusive, per 30.3.1
 3. Build a spanning path over room_count rooms, add
    cycle_count = 1 + rng.range(0, 3) extra edges between non-adjacent
    rooms, clamp edge_count to [10, 20]
 4. Assign purposes from PURPOSE_ROTATION, forcing at least two
    control_room purposes
 5. Select shells per purpose, and bind each room's shell_id (30.11)
 6. Choose variable_count = 2 + rng.range(0, 6); for each, a state
    count in [2,4] and a setter room from the control rooms
 7. Assign edge predicates over the chosen variables (30.3.2)
 8. FREEZE EVERY NON-LATCH VECTOR DIMENSION.                        # MOVED
    Determine, and record as final:
      - key_count        = rng.range(0, 4)
      - encounter_gates  = rooms whose purpose takes an ENCOUNTER_GATE
      - shortcut_flags   = one-way edges from step 3
      - visit_flags      = rooms any predicate references via ROOM_VISITED
    No later step may add to any of these. Compute
      frozen_product = prod(variable states) * 2^(keys + gates
                       + shortcuts + visits)
    If frozen_product > 4096: FAIL_ZONE and retry the seed.
 9. ALLOCATE LATCHES from what is left.                             # MOVED
      headroom     = 4096 // frozen_product
      latch_budget = min(8, floor(log2(headroom)))
    THE VECTOR IS NOW FROZEN. Its exact product is known and no
    later step can change it.
10. Place macro effects: each (variable, state) pair gets 1-3 effects
    in rooms other than its setter's room
11. Place packages per room per PACKAGE_DENSITY (24.1.1), attempt
    limit 12, drawing from the thirty-four families in the order
    30.3.2 fixes.  A package whose vector_latches is non-empty is NOT
    SELECTABLE while latch_budget is 0; selecting one decrements
    latch_budget by len(vector_latches).  A package that would
    introduce ANY OTHER new vector dimension is not selectable at
    all -- see the freeze rule below.
12. VALIDATE PHYSICS.  For every package selected in step 11 that
    requires manipulation or drives a constraint on a mandatory
    route, run 23.5 check 20's three headless replays in the
    canonical environment (30.11).  A package failing any run is
    rejected and step 11 retries.
13. Allocate Checks: check_count = clamp(room_count * 2 / 3, 5, 9)
14. Place encounters per ENCOUNTER_BUDGET
15. Place checkpoints PROVISIONALLY under the initial macro state
16. Run the structural checks (30.5)
17. RUN THE MODEL CHECK (30.6), producing R.  On failure: FAIL_ZONE
18. VALIDATE CHECKPOINT COVERAGE over R (30.7.1, 30.7.3).  Add a
    checkpoint and repeat 18 while a violation remains, at most 3
    times; a 4th is FAIL_ZONE
19. Re-run structural check 12
20. COMMIT the Zone manifest and its digest (30.11)
```

**The freeze rule, stated as one outcome.** After step 8, the set of non-latch state-vector dimensions is final. If any later step would introduce one — a package wanting an `ENCOUNTER_GATE` in a room step 8 did not count, a shortcut a package would open, a `ROOM_VISITED` sensor a package would read — **that package is not selectable, and step 11 tries the next candidate.** It is never accommodated by growing the vector, and the attempt limit of `12` then the density reduction in §30.8 handle exhaustion.

This is the repair for a real ordering defect. The previous revision allocated latch headroom at step 8 from *"the variables and the key count"*, while encounter-gate, shortcut, and visit flags were still being decided by later steps — so the product could exceed `4096` after allocation, and structural check 12 **discovered** the overflow instead of the algorithm **preventing** it. Check 12 is now a proof that re-derives a known-correct number, and a failure in it is a bug in the composer rather than an expected retry path.

### 30.3.0 Purpose selection — every shipped purpose is generatable

A previous revision truncated Design 3's `PURPOSE_ROTATION` to its first twelve entries. The rotation's last two are `vertical_ascent` and `boss_arena`, so truncation made **two shipped purposes impossible to generate** — a boss arena could never occur, and §24's `PACKAGE_DENSITY` carried a row for a purpose that would never be assigned.

The full fourteen-entry rotation is retained and read **cyclically from a seeded offset**:

```
PURPOSE_ROTATION = [traversal, control_room, arena, environmental_puzzle,
                    junction, control_room, ranged_arena, routing_puzzle,
                    traversal, control_room, holdout, observation_puzzle,
                    vertical_ascent, boss_arena]                    # 14, pinned from D3

offset      = rng.index(14)
purpose[i]  = PURPOSE_ROTATION[(offset + i) mod 14]   for i in 0..room_count-1
```

Then three deterministic corrections, applied in this order:

1. **At least two `control_room`.** While fewer than two, convert the highest-indexed room whose purpose occurs more than once; if none does, convert the last room. This preserves Design 3's control-room requirement.
2. **At most one `boss_arena`.** Any second or later occurrence becomes `arena`.
3. **A `boss_arena`, if present, is the exit room.** Swap it with whatever purpose the exit room holds.

**Coverage, computed over all `5 × 14 = 70` (room count, offset) pairs:**

| Purpose | Generatable in |
|---|---:|
| `traversal`, `control_room` | `70 / 70` |
| `arena`, `holdout`, `observation_puzzle`, `ranged_arena`, `routing_puzzle`, `vertical_ascent` | `50 / 70` |
| `boss_arena` | `49 / 70` |
| `environmental_puzzle` | `49 / 70` |
| `junction` | `48 / 70` |

Every purpose has non-zero probability. `boss_arena` occurs in roughly `70%` of Zones, which is the intended texture — a boss is an event, not a fixture.

### 30.3.1 RNG primitives

`rng.int(a, b)` was ambiguous: §30.3 used it to mean an inclusive count while the inherited package-selection code used it to index a list, and those need opposite bounds. Two named primitives replace it, and every draw in this document uses one of them explicitly:

| Primitive | Yields | Used for |
|---|---|---|
| `rng.range(a, b)` | an integer in `[a, b]`, **inclusive of both** | counts: rooms, cycles, variables, keys, state counts |
| `rng.index(n)` | an integer in `[0, n)`, **exclusive upper** | list indexing: `candidates[rng.index(len(candidates))]` |

`rng.index(0)` is a composition error, never a draw — an empty candidate list is handled by the exhaustion rule in §30.8, not by indexing into nothing.

Each consumes exactly one 32-bit word from its stream, so RNG consumption is a function of the number of draws and not of their outcomes. That is what keeps §30.5's byte-identical guarantee true when a retry changes an outcome but not a draw count.

### 30.3.2 Exact selection ordering and weights

Every choice affecting a generated Zone needs an exact candidate set, an exact order, and exact exhaustion behaviour. Three that were previously prose:

**Edge predicates (step 7).** Design 3's *"~40% unconditional"* is not a rule. The exact rule: iterate edges in ascending `(room_a, room_b)` order; edge `i` is unconditional when `rng.range(0, 99) < 40`. That is a per-edge `40%` with a fixed traversal order and one draw per edge — reproducible, and the observed fraction varies as a binomial around `0.4` exactly as intended.

**Package candidates (step 11).** The candidate set is every family legal for the room's purpose **and** hostable by the room's shell's free offers **and** selectable under the §30.3 freeze rule, sorted ascending by the family's §24 index. Candidates are drawn without replacement using `rng.index` over the remaining list, up to the attempt limit of `12`.

**Shell requests (step 5).** `offered_shells` is sorted ascending by shell id before the request, so the list Epsilon sees is a function of the catalog and the room, never of iteration order. §30.11.6's offline selector indexes that same sorted list.

**Every failure in step 11 terminates, and it terminates on a certified pair rather than on an assertion.** A previous revision claimed families `1`–`18` "always provide a substitute". Purpose compatibility alone does not prove that: the room's shell must also still have a free offer of the right kind, and offers are consumed by packages already placed.

The guarantee is made by construction instead. **`CERTIFIED_FALLBACK[purpose]`** names, for every purpose in `PURPOSE_ROTATION`, one `(family, shell_id)` pair that is checked in, hand-verified, and requires no replay, no vector latch, no constraint, and no capability:

| Purpose | Certified pair |
|---|---|
| `traversal`, `junction` | `PULSE_REMOTE` on `shell_corner_left` |
| `control_room` | `MACRO_SETTER` on `shell_corner_right` |
| `arena`, `ranged_arena`, `holdout` | `ENCOUNTER_GATE` on `shell_hall_transit` |
| `environmental_puzzle`, `routing_puzzle`, `observation_puzzle` | `DUAL_INPUT` on `shell_hall_transit` |
| `vertical_ascent` | `SHOOT_TARGET` on `shell_tower_spiral` |
| `boss_arena` | none; `PACKAGE_DENSITY` is `0` |

Every certified shell is one of the twelve `review: pass` authored shells, and each certified family binds only offers its certified shell declares — verified once, checked in as a fixture, and re-proved by §37.2's fallback Zone which is built entirely from this table.

**The exhaustion rule, and why the shell is never swapped late.** A previous revision let step 11 substitute the certified shell for the selected one when the selected shell could not host the fallback package. **That is unsafe:** by step 11 the shell's connector assignment is fixed (§30.11.2b), its neighbours' geometry chains to it, its offers may be partly bound, and Epsilon's choice is on its way into the manifest. Replacing it invalidates all four and re-running every affected invariant mid-algorithm is not something this document is willing to specify.

**The policy is: the shell is chosen once, at step 5, and never changes.** Two repairs make the fallback guarantee actually hold for the shell Epsilon selects.

**First, the key is a connector signature, not a degree.** A previous revision wrote *"indexed by purpose and connector signature"* while the actual form was `CERTIFIED_FALLBACK[purpose][degree]`. Degree is not a signature: two degree-`2` rooms can demand entirely different socket kinds and directions. The key is the room's **normalized incident signature**:

```
ConnectorSignature = sorted multiset of (socket_kind, direction) over incident edges
CERTIFIED_FALLBACK[purpose][signature] -> family
```

`socket_kind` ranges over four values (doorway, drop, rail mouth, vertical shaft) and `direction` over three (inbound, outbound, bidirectional), so with degree `1`–`4` the signature space is finite and small, and the table is enumerable and checked in.

**Second, the guarantee attaches to every offered shell, not to one certified shell.** A previous revision proved the *certified* shell was in `offered_shells` and then claimed at step 11 that the shell Epsilon *actually selected* could host the fallback family. That does not follow — Epsilon may pick a different offered shell.

> **Every shell in `offered_shells` must be proven capable of hosting the room's `CERTIFIED_FALLBACK[purpose][signature]` family, in addition to the §30.11.2a minimum vocabulary.** A shell that cannot is not offered.

The guarantee then holds for whatever Epsilon selects, because it held for every candidate before the question was asked. If no shell satisfies both conditions, `offered_shells` is empty and §30.11.5's empty-list row applies — `FAIL_ROOM`, before Epsilon is contacted.

Given that, the exhaustion rule at step 11 is shell-preserving:

| Situation | Outcome |
|---|---|
| Step 11 exhausts `12` attempts for a room | Place `CERTIFIED_FALLBACK[purpose][signature]`'s **family** into the **already-selected shell**, which step 5 proved every offered shell can host |
| Density is `2` and only one package placed | The room ships with one. `PACKAGE_DENSITY` is a target, not a floor |
| The certified family fails in the selected shell | **Unreachable by construction** — the offering rule proved compatibility for every candidate. Reaching it is a corrupted catalog: it fails the room, then §30.8's Zone retry, then §37.2's fallback Zone |

**No unbounded retry, no late shell swap, and no step that assumes something will fit.**

**Step 8 is the union's characteristic decision.** It is where a Zone chooses what kind of Zone it is. A Zone that spent its budget on three four-state macro variables (`64`) and two keys (`4`) has `4096 / 256 = 16` of headroom left, which is four latches — a machine-heavy Zone with a few physical locks. A Zone with two two-state variables (`4`) and no keys has `1024` of headroom, which is the full eight latches — a physics-heavy Zone with a simple machine. Both are legal, both are verified identically, and the seed decides which.

That single step is what makes the union produce recognisably different Zones rather than one averaged Zone, and it is the closest thing this document has to a generative thesis.

**Step 12 is the union's characteristic cost.** It is a physics engine running inside the composer. §35.4 budgets it at `10.8 s` per attempt, which is more than every other per-attempt step combined by a factor of four.

## 30.4 Control rooms

*Pinned: identical to Design 3 §30.4.* One `MACRO_SETTER` or `POWER_ROUTE` package, no encounter, always reachable under the macro states from which its variable needs setting — which is §30.6 property 6.

## 30.5 Determinism and structural checks

### 30.5.1 Two determinism properties, not one

Design 1 §30.5 promises byte-identical composition from `(zone_seed, progression_state, ap_catalog)`. That promise is **only** true for a composer no model participates in. Once Epsilon selects shells (§30.1), re-running the same inputs may produce a different legal Zone, and §30.11.2a establishes that different legal shells genuinely yield different package multisets.

Claiming both would be a contradiction. The document claims two separate, weaker, true things instead:

> **P1 — Structural reproducibility.** Given `(zone_seed, progression_state, ap_catalog, shell_catalog_digest)`, everything the bridge owns is byte-identical on every run: room count, topology, edges, purposes and their offset, incident-edge signatures, `offered_shells` per room, macro variables and predicates, the frozen state vector, RNG draw sequence, package candidate ordering, the `CERTIFIED_FALLBACK` resolution, and every validation verdict that does not read a shell.
>
> **P2 — Committed reconstruction.** Given a `ZoneManifest`, reconstruction is byte-identical forever, on any machine, with Epsilon unreachable. This is the property save, load, and replay actually rely on.

**What is deliberately not claimed:** that fresh generation from a seed alone is byte-identical. It is not, and no amount of wording makes it so while a model chooses.

**Zone identity therefore includes the validated Epsilon selection.** A Zone is identified by `manifest_digest`, which covers `zone_seed`, the catalog digests, **and** `epsilon_provenance.response_digest`. Two Zones from one seed with different shell selections are two different Zones with two different identities — not one Zone that reconstructed wrong.

*Pinned: identical to Design 1 §30.5* for the three independent RNG streams, which underpin P1.

Design 1's eight whole-Zone checks, plus Design 3's five, plus twelve new. **Every id is unique**, including the sub-numbered `19a`–`19c`.

| # | Check | Origin |
|---:|---|---|
| 1–8 | *Pinned: identical to Design 1 §30.4*, with check 1 replaced by §30.6 property 1 and check 5 removed as inapplicable. | D1 |
| 9 | Every `TopologyEdge` names two distinct existing rooms; every predicate term names an existing variable and state. | D3 |
| 10 | Every macro variable has at least one setter, and every state of every variable is settable. | D3 |
| 11 | Every `MacroEffect` names an existing room and an existing `(variable, state)` pair. | D3 |
| 12 | The state-vector product equals the value frozen at §30.3 step 9 and is at most `4096`. **This is a proof, not a filter** — step 8 already refused any composition that could exceed it, so a failure here is a composer bug. | D3, modified |
| 13 | Every reachable rail-network routing terminates at a dismount point. | D3 |
| **14** | **For every set of three mutually adjacent rooms and every reachable macro state, simultaneously active rigid bodies ≤ `90` and active constraints ≤ `20`.** Scope is the loaded set, not the Zone, and it is evaluated per macro state because Design 3's effects can power several rooms at once. | NEW |
| **15** | **No rail path intersects any constrained body's swept volume** (§26.7). | NEW |
| **16** | **Every `vector_latch` claimed in step 11 is within the step 9 allocation**, and the recomputed product equals the frozen value. | NEW |
| **17** | **At most `12` packages in the Zone require a §23.5 check 20 replay** — that is, have `capability_required = manipulate`, or place a `WINCH`, `BRAKE`, or `DRIVER` on a mandatory route. | NEW |
| **18** | **No topology-edge predicate and no mandatory-route gating expression contains a negated vector-latch term.** Vector latches appear only as positive terms, which is what makes §30.7.2's monotonicity real rather than asserted. | NEW |
| **19** | **Every room record carries a `shell_id` that is present in the offered catalog, type-compatible with the room's purpose, and exposes every offer the room's packages bind to** (§30.11). | NEW |
| **20** | **The sum of a room's mandatory Status reservations (§35.2.1), plus one ordinary application, is within the room's `60`-entry and `24`-body caps.** | NEW |
| **19a** | **Every Zone's `ZonePresentation` names a theme in the authored catalog and strings within their length bounds** (§30.1). | NEW |
| **19b** | **Every incident topology edge of every room carries a distinct connector-socket assignment, and both endpoints of every edge agree on the joining transform** (§30.11.2b). | NEW |
| **19c** | **Every `HostDefinition` carries exactly one of `composition` or `profile`, decided by its `category`** — `profile` for `mobility`, `composition` for every other category (§4.2). | NEW |
| **22** | **Every package with a non-null `status_required` declares a `status_source` and a solution target, and that triple is marked `guaranteed_application`** (§35.2.2). | NEW |
| **21** | **Every constrained body a reachable `POWER_OFF` can affect, and that the player can stand on, ride, or attach to, has a base-movement-safe egress** — a surface reachable from it by §6.2's movement law alone, under every reachable macro state, with no offer geometry and no capability (§21.11). | NEW |

Check 14 exists because Design 2's per-room budgets were written for a proposal where the loaded set was the only thing that mattered and its contents were fixed. Under the union a macro effect can power three adjacent rooms at once, and three rooms at Design 2's per-room ceiling of `40` sum to `120` against a loaded-set budget of `90` (§35.1). The check is quantified over reachable macro states rather than over the initial one, because the state that overflows is rarely the state the Zone starts in. §35.1 sets the runtime ceiling; check 14 enforces it at composition so it is never discovered at `14 fps`.

## 30.6 The model check — modifies Design 3 §30.6

**The system this proposal stands on.** *Pinned: identical to Design 3 §30.6* for the configuration definition, the forward and reverse BFS, properties 1 through 6, the witness requirement, and the failure response — with one added transition kind and two added properties.

A **configuration** is a pair `(v, r)`: the full unified state vector (§4.10) and a room.

### The three transitions

| Transition | From → To | Legal when |
|---|---|---|
| **Move** | `(v, r) → (v, r')` | *Pinned: identical to Design 3 §30.6.* An edge joins them, its predicate is true under `v`, its `capability` is in the proven set, and direction permits it |
| **Set** | `(v, r) → (v', r)` | *Pinned: identical to Design 3 §30.6.* A setter package in `r` sets variable `x` to `s`. Monotone components move forward only |
| **Latch** | `(v, r) → (v', r)` | **NEW.** A package in `r` declares latch `l` in `vector_latches`, `v[l]` is false, the package's `macro_predicate` is true under `v` (a `null` predicate is true in every state), its `capability_required` is `null` or in the proven set, and its `reference_solution` passed §23.5 check 20. Then `v' = v[l := true]`, **forward only** |

The Latch transition is the whole bridge between Design 2 and Design 3, and its legality condition is where the two halves of the proof meet. The **graph** half — can the player reach the room, in a configuration where the package is live, holding the required capability — is proved by the search. The **physical** half — can a player holding that capability actually make the objects do the thing — is proved by check 20's replay, before the search ever runs.

Neither half proves the other and neither is sufficient alone. That is the honest statement of what this union bought and what it cost.

### The eight properties

| # | Property | Test |
|---:|---|---|
| 1–3, 5–6 | Exit reachable; **`R ⊆ E`**; every Check reachable; every capability gate proven before its requirement; every variable settable from a reachable configuration | *Pinned: identical to Design 3 §30.6* |
| **4** | **Every required cross-room carryable is recoverable from every configuration in which it is still required** — strengthened, see §30.6.1 | Modified |
| **7** | **Every vector latch is settable from a reachable configuration** | For each latch `l`, `∃ c ∈ R` from which a Latch transition on `l` is legal. A latch nothing can set is a permanently-false state-vector dimension, which is a composition defect, not a puzzle |
| **8** | **Status reaches progression only through a latch** | No topology-edge predicate reads a Status sensor, and no mandatory-route actuator or `macro_setter` enable is driven by one except through a node in `latch_conditions`. Structural, checked over the composed graph rather than the search |

### 30.6.1 Property 4, strengthened

Design 3 states property 4 as: *for each required object, its `home_transform` room is in `{c.room : c ∈ R}` for every `v` appearing in `R`.*

**That is too weak, and the weakness is the dangerous direction.** It asks whether the home room appears *somewhere* in the global reachable set. It does not ask whether the player, standing in the configuration they are actually in, can still get there. A macro change that seals the wing containing a required power cell satisfies Design 3's wording — the home room is reachable in *some* configuration, namely the earlier one — and strands the player anyway.

The union quantifies per configuration. Define, for a required object `o` consumed by a socket in room `k`:

```
REQ(o) = { c in R : o has not yet been consumed in c
                    and some route from c to the exit passes
                    through o's socket }
HOME(o) = { c in R : c.room == home_room(o) }
```

> **Property 4.** For every required cross-room carryable `o` and every `c ∈ REQ(o)`, there is a path in the configuration graph from `c` to some `h ∈ HOME(o)`, and from `h` to a configuration whose room is `k` with `o` carried.

**The configuration must be augmented, because `(v, r)` cannot express this.** `REQ(o)` asks whether `o` has been consumed and `HOME(o)` asks where it is; neither fact is in the state vector or the room. Rather than put transforms into the global vector — which §4.10 exists to prevent — property 4 runs over a **per-object proof augmentation** that exists only inside the verifier:

```
ObjectState = AT_HOME | CARRIED | PLACED(room_id) | CONSUMED
augmented configuration = (v, room, object_state)          # for ONE object o
```

`PLACED` **is** room-indexed, and a previous revision was wrong to drop the index. It argued that room unload returns a dropped required object to `home_transform`, so where it was dropped could not matter. **That is not Design 2 §10.5's contract** — recovery returns an object that has *left the world*, not one legally resting inside its `allowed_volume`. A required cell dropped in room `B` stays in room `B`, and a proof that cannot say so cannot tell "the cell is two rooms away" from "the cell is here".

`room_id` ranges over the object's declared `allowed_volume` only, which §23.5 check 24 already bounds.

### 30.6.2 The augmented transitions, in full

| From | Transition | Legal when |
|---|---|---|
| `AT_HOME` | pick up | the player's room is `home_room(o)` |
| `PLACED(k)` | pick up | the player's room is `k` |
| `CARRIED` | drop | the player's room is in `allowed_volume`; → `PLACED(player's room)` |
| `CARRIED` | insert | the player's room holds `o`'s socket; → `CONSUMED`, terminal |
| `CARRIED` | **Move** | **carry-legal only — see below** |
| `AT_HOME`, `PLACED(k)`, `CONSUMED` | Move | ordinary §30.6 Move rules; the object does not travel |

> **The carry-legal Move rule.** From a `CARRIED` configuration, a Move across edge `e` is legal only when **all** hold: the destination room is in `o`'s `allowed_volume`; `e`'s predicate is true under `v`; `e`'s `capability` is in the proven set; **and `e` is traversable while carrying.**

That last clause is the one that matters and the one a previous revision omitted entirely. Design 1 §10.3 disables a subset of actions while a carryable is held, and an edge whose only crossing uses a disabled action **is not available to a carrying player** even though it is available to the same player empty-handed. Concretely: an edge whose `capability` is `grapple` or `blink` is not carry-legal, because both are `MOBILITY` actions §10.3 blocks while carrying; an edge crossed by base movement or by a `LAUNCHPAD` is.

Each edge therefore carries a derived `carry_legal: bool`, computed at composition from its `capability` and its authored crossing method, committed in the manifest, and read by the augmented search. **Without it the proof would route a required object across a grapple gap the player cannot actually cross while holding it** — which is precisely the stranding property 4 exists to reject, reintroduced by the proof itself.

> **Property 4, formally.** For each required cross-room carryable `o`, search the augmented graph `R⁺(o)` from `(v_initial, entry, AT_HOME)`. Require: every configuration in `R⁺(o)` whose `object_state` is not `CONSUMED`, and from which the exit is only reachable through `o`'s socket, can reach a configuration with `object_state = CONSUMED`.

**This is validation state, not persistence.** `ObjectState` never enters the state vector, never appears in a save, and never becomes a macro dimension. It exists for the duration of one search per object and is discarded.

**Cost, recomputed from the real state count.** `ObjectState` has `2 + |allowed_volume|` values — `AT_HOME`, `CONSUMED`, `CARRIED`, and one `PLACED(k)` per room in the volume — not a universal `4×`. §23.5 check 24 bounds `allowed_volume` by the rooms between an object's home and its socket, and §30.2 caps a Zone at `12` rooms, so the worst case is `|allowed_volume| = 12` and `14` object states.

| Term | Worst case |
|---|---:|
| States per object | `14` (`12` rooms + `AT_HOME` + `CONSUMED`) |
| Augmented configurations per object | `14 × 49,152 = 688,128` |
| Required cross-room objects | `4` authored + `4` local keys = `8` |
| **Total augmented configurations** | **`5,505,024`** |

Against the base search's `49,152` that is `112×`, and it is still a BFS over a graph with under `6M` nodes — tens of milliseconds, well inside §35.4's `2.0 s` model-check budget. A typical `allowed_volume` of `3` rooms gives `5` states and `245,760` configurations across all objects, which is smaller than the base search.

It is the difference between *"the object's room exists on the map"* and *"you can still go and get it, while carrying it."*

**On the object's own recovery rule.** Design 2 §10.5's recovery — an object that leaves the world returns to `home_transform` — is what makes `HOME(o)` a fixed room rather than a moving target. Property 4 is stated over rooms rather than over transforms for that reason, and §5.6's reconstruction order guarantees the object is at its home transform whenever the player has not carried it away.

**Property 2 remains the whole thing.** `R ⊆ E` — there is no configuration the player can reach from which they cannot finish — now quantifies over macro state, keys, encounter flags, shortcuts, visit flags, **and physics latches** simultaneously. A player who assembles a bridge, routes power away from the room, and finds the gantry retracted is exactly the configuration property 2 rejects, and no proposal but this one could even express it.

**Property 8 is what keeps property 2 computable.** Without it, a mandatory door reading a `STATUS_SENSOR` would put thirteen Statuses across five target kinds into the vector, multiplying the space by roughly `13³ × 5` — call it `11,000` — and turning a `49,152`-configuration search into a `540`-million-configuration one. With it, the Status layer is invisible to the verifier and the search is unchanged.

### Cost

| Term | Value |
|---|---|
| Configurations in `R` | ≤ `4096 × 12 = 49,152` |
| Outgoing transitions per configuration | edges `20` + settable states `8 × 4 = 32` + latches `8` = **`60`** |
| Edge traversals, forward | ≤ `2,949,120` |
| Edge traversals, reverse | ≤ `2,949,120` |
| **Search total** | **≤ `5.9M` traversals** |
| **Physics replays** (§23.5 check 20) | ≤ `12` packages × `3` runs × `12.0 s` (`MAX_REPLAY_DURATION`) = `432 s` simulated, at `40×` real time, **serial** = `10.8 s` |

The search is milliseconds and is not the cost. **The replays are.** §35.4 budgets them at `10.8 s`, and they are the reason §30.2 caps Zones at twelve rooms.

### On failure

*Pinned: identical to Design 3 §30.6.* The Zone is rejected whole, retried per §30.8, and the failure logs the seed, the failing property, and — for property 2 — a witness configuration in `R \ E`, printed as its full variable assignment, latch assignment, and room.

The witness now includes latch state, which is the difference between *"the player can get stuck"* and *"the player can get stuck after solving the girder puzzle and then cutting power to the gantry."* One of those is diagnosable.

## 30.7 Checkpoints — modifies Design 3 §30.7

Design 3 places checkpoints under the **initial** macro state and calls that conservative *"because opening the machine only shortens distances."*

**That argument is false for a reversible machine, and this document's own fixture disproves it.** U1 (§37.3) sets `power IS security`, which **closes** edge `B–C`; setting it back reopens it. A reversible variable can lengthen a shortest path as easily as shorten it, so a spacing valid at the initial state can become a spacing of five edges two lever-throws later.

The same objection applies to the latch clause a previous revision added. *"Latching only ever opens routes"* is true of a latch considered alone, but a latch feeds predicates, and a predicate may read it negated — `NOT latch_0 AND power IS gantry` is a legal DNF term over the vector, so a latch **can** close a route.

Two repairs, and the second is what makes the first cheap.

### 30.7.1 The exact placement rule

Checkpoint spacing is validated over the **verified reachable configuration set `R`** (§30.6), not over one configuration:

*"Nearest preceding checkpoint"* is not well defined on a cyclic graph — there is no linear predecessor. Coverage is defined directly over reachable configurations instead:

Let `CP` be the set of configurations whose room holds a checkpoint. Define, for any configuration `x`, the room-change distance `d(x)` as the minimum number of **Move** transitions from any element of `CP` to `x` in the configuration graph.

> **Checkpoint coverage.** For every `x ∈ R`, `d(x) ≤ CHECKPOINT_SPAN = 2`.

One multi-source BFS from `CP` over the same graph §30.6 already built. No predecessor ordering, no path direction, no linearity assumption — a cyclic Zone is handled by the same rule as a tree.

### 30.7.3 The two-pass placement, in the algorithm and not only in prose

Checkpoint placement needs `R`, and `R` is produced by the model check. §30.3 therefore runs the two explicitly, rather than describing an order the step list contradicts:

```
15. Place checkpoints PROVISIONALLY: entry room, plus every room whose
    shortest-path distance from the previous provisional checkpoint
    exceeds 2 edges under the INITIAL macro state.
16. Run the structural checks (30.5)
17. RUN THE MODEL CHECK (30.6), producing R.  On failure: FAIL_ZONE
18. VALIDATE CHECKPOINT COVERAGE over R (30.7.1).
    If every x in R has d(x) <= 2: proceed to 20.
    Otherwise add a checkpoint to the room of the violating configuration
    with the largest d(x), and repeat from 18.
    At most 3 additions; a 4th is FAIL_ZONE.
19. Re-run structural check 12 only (adding a checkpoint changes no
    state-vector dimension, so no other check can be invalidated).
20. Commit the Zone manifest and its digest (30.11)
```

Adding a checkpoint only ever shrinks `d`, so the loop is monotone and terminates. The bound of `3` additions is the declared attempt count; exceeding it means the topology is too sparse for `CHECKPOINT_SPAN = 2` and the seed is retried.

### 30.7.2 The monotone-latch invariant, made real

Rather than assert that latches only open routes, the union **requires** it and checks it:

> **Structural check 18.** No topology-edge predicate, and no mandatory-route gating expression, contains a negated vector-latch term. A vector latch may appear only as a positive term.

With check 18, a vector latch genuinely is monotone with respect to mandatory-route reachability: setting one can only add configurations to `R`, never remove them. The all-false evaluation is then conservative **because a check makes it so**, not because a sentence says so.

Macro variables get no such restriction — negated macro terms are the whole point of a reversible machine, and §30.7.1 is what handles them.

## 30.8 Retry and fallback

*Pinned: identical to Design 3 §30.8*, with one row added.

| Failure | Response |
|---|---|
| *(Design 3's five rows)* | *Pinned.* Package retry ×12, room retry ×3, structural retry ×5, model-check retry ×5, then the certified fallback |
| **§23.5 check 20 replay failure** | **Reject the package and retry step 10 for that room, up to `12` times, then place a non-physics package instead** |

A replay failure is a *package* failure, not a Zone failure, and must not cost a whole-Zone retry — a Zone retry re-runs every replay in the Zone, which is the most expensive thing the composer does.

The certified fallback Zone is *pinned: identical to Design 3 §30.8* and is deliberately Design-1-shaped: two irreversible variables, tree topology, **zero vector latches, zero constraints**. The guaranteed-safe fallback for a proposal built on three stacked validators should not itself depend on any of them.

## 30.9 Client-side consistency

*Pinned: identical to Design 3 §30.9*, with the checked record extended: room count, edge count, variable set, state counts, predicate hashes, **latch count, and constraint count**. A mismatch is a hard error and the Zone is refused.

## 30.10 Physical authority

*Pinned: identical to Design 1 §30.8 and Design 2 §30.8.* Geometry wins over composition claims. A room whose physical and logical truth disagree fails its audit at load.

## 30.11 The `shell_id` contract and the committed Zone manifest — new

This section exists because of the runtime finding in §30.1. It is the seam that made every played room procedural, and it is specified here so that the failure cannot recur silently.

### 30.11.1 Every room record carries a shell id

```
RoomRecord:
  room_id              : Id
  purpose              : Purpose        # the 11 values PURPOSE_ROTATION draws from (30.3.0)
  type                 : ChamberType    # CLOSED: arena | tower | corridor | treasure_room
  shell_id             : Id             # REQUIRED. No default. Never null.
  connector_assignment : dict[EdgeId, SocketId]   # 30.11.2b. Total over incident edges
  offers_bound         : list[OfferBinding]
  packages             : list[Id]
```

`ChamberType` is the **closed four-value enum** above and carries no open extension — a generated-record schema with an ellipsis in it is a schema an implementer has to guess at. `connector_assignment` is total: every incident edge of the room appears exactly once as a key, and no `SocketId` appears twice as a value (§30.5 check 19b).

`shell_id` has **no default and is not nullable.** A `RoomRecord` without one fails schema validation at the bridge and the Zone is never served. There is no code path in which a room is composed, served, and then discovers it has no shell.

### 30.11.2 The offered catalog

The bridge supplies Epsilon, per room, with `offered_shells` — the shells that are **all** of:

1. present in the authored shell catalog;
2. `review: pass`;
3. of a `type` compatible with the room's purpose (§30.11.3);
4. exposing at least the **minimum offer vocabulary** the room's purpose requires (§30.11.2a) — *not* the offers of specific packages, which do not exist yet;
5. **connector-satisfiable** against the room's full incident-edge signature (§30.11.2b).

Epsilon selects one id from that list and returns nothing else about the room. **A selection outside the list is not a shell selection; it is an invalid response**, handled by §30.11.5.

### 30.11.2a Minimum offer vocabulary — the ordering repair

A previous revision made rule 4 read *"exposing every offer the room's already-selected packages require."* **Those packages do not exist when the shell is chosen.** Shell selection is §30.3 step 5; package selection is step 11. The rule was unsatisfiable as written.

The repair is to make rule 4 depend only on what *is* known at step 5 — the room's purpose:

| Purpose | Minimum offer vocabulary the shell must expose |
|---|---|
| `environmental_puzzle`, `routing_puzzle` | ≥ 2 `mechanism_mount`, ≥ 1 `object_rest`, ≥ 1 `actuator_path` |
| `observation_puzzle` | ≥ 2 `mechanism_mount`, ≥ 1 `sightline` |
| `junction` | ≥ 2 `mechanism_mount`, ≥ 1 `actuator_path` |
| `control_room` | ≥ 1 `macro_control` |
| `traversal`, `vertical_ascent` | ≥ 1 `traversal_span` |
| `arena`, `ranged_arena`, `holdout`, `boss_arena` | ≥ 1 `encounter_volume` |

`PACKAGE_DENSITY` (§24.1.1) bounds how many packages a purpose takes, and the vocabulary above is sized so the densest purpose can always bind. Step 11 then draws only from families the **selected** shell's remaining free offers can host.

**The honest consequence, stated rather than hidden.** A previous revision claimed the legal shell answers were *"all equivalent to the composer."* **They are not.** A shell exposing three `mechanism_mount` offers admits package families a shell exposing two does not, so Epsilon's choice at step 5 genuinely narrows what step 11 can place. Two legal shell answers can yield Zones with different package multisets from the same seed.

That is acceptable and it is why §30.11.7's manifest exists: the *chosen* Zone is committed and reconstructs identically forever. What it is not is composition-equivalence, and §30.5's determinism claim is scoped accordingly in §30.5.1.

### 30.11.2b Connector satisfiability on a graph

A previous revision required a shell to be *"connector-compatible with both neighbours"* — entry and exit. **The Zone is a graph with `1`–`4` independent cycles (§30.2), so a room's degree can exceed two**, and a linear entry/exit assumption cannot express a junction with three or four incident edges.

Define the room's **incident-edge signature** at step 3, before any shell is offered: for room `r`, the ordered list of its incident `TopologyEdge`s, each carrying its direction (`A_TO_B`, `B_TO_A`, or bidirectional) and the neighbour it joins.

> **A shell is connector-satisfiable for room `r` when there exists an injective assignment from `r`'s incident edges to the shell's declared connector sockets** such that every assigned pair is compatible in socket **kind** (doorway, drop, rail mouth, vertical shaft), **direction** (a one-way drop assigns only to a drop socket oriented outward), **transform** (the socket's attachment frame can be placed so both rooms' geometry chains without overlap), and **clearance** (§30.11.2c's headroom and width minima).

Three consequences, each exact:

1. **A shell with fewer sockets than the room has incident edges is never offered.** Degree `4` requires at least four compatible sockets.
2. **The assignment is computed, recorded, and committed.** `RoomRecord.connector_assignment` maps each incident edge id to the socket id it uses. It is part of the manifest and therefore part of `manifest_digest`.
3. **Assignment is deterministic.** Where several injective assignments exist, take the lexicographically smallest by `(edge_id, socket_id)` pairs sorted ascending. No search, no choice, no seed consumed.

**§30.5 check 19b** re-proves on the composed Zone that every incident edge of every room carries a distinct socket assignment and that both endpoints of every edge agree on the transform that joins them. A Zone with an unassigned edge, a doubly-assigned socket, or a transform mismatch is rejected.

### 30.11.2c Clearance minima

*Pinned: identical to Design 1 §28.1's room-shell contract* for the geometric minima a connector must satisfy — walkable width, headroom above the arrival surface, and a landing region clear of hazard volumes. A socket that cannot meet them for a given edge is not compatible for that edge, which is what makes the assignment in §30.11.2b a real constraint rather than a naming exercise.

### 30.11.3 Type and purpose compatibility

| Purpose | Compatible types |
|---|---|
| `arena`, `ranged_arena`, `holdout`, `boss_arena` | `arena` |
| `vertical_ascent` | `tower` |
| `traversal`, `junction` | `corridor`, `arena` |
| `control_room` | `corridor`, `arena` |
| `environmental_puzzle`, `routing_puzzle`, `observation_puzzle` | `arena`, `tower` |
| Any purpose hosting a Check with no packages | `treasure_room` |

The table is the contract. A shell whose type is absent from its room's row is not offered, and §30.5 check 19 re-proves this on the composed Zone rather than trusting the request.

### 30.11.4 The runtime instantiates exactly that id

The client reads `shell_id` from the committed manifest and instantiates that shell. **`SHELL_FOR_TYPE` is not consulted for a room record**, and there is no fallback from an authored shell to a procedural one.

> **A `*_proc` shell may only be instantiated for a `RoomRecord` whose `shell_id` is itself a procedural shell id, selected as such at composition, recorded as such in the manifest, and reported as such in the audit.** Silent substitution is not a degraded mode; it is a hard error.

### 30.11.5 Every failure has exactly one outcome

| Condition | Outcome |
|---|---|
| Epsilon returns an id **not in** `offered_shells` | Response rejected; §17.4's repair runs once; on second failure the **deterministic offline selector** (§30.11.6) chooses. Logged with seed, room, and the returned id |
| Epsilon returns **no** `shell_id` for a room | Same as above. Absence and invalidity are one case |
| Response is **malformed** or times out (`10.0 s`) | Deterministic offline selector, per Design 4 §17.6 |
| `offered_shells` is **empty** for a room | `FAIL_ROOM`. Retry the room with a different shell-compatible purpose up to `3` times, then `FAIL_ZONE` per §30.8. A room with no legal shell is a catalog gap, not a runtime condition |
| A selected shell is **`review: pending`** or has been withdrawn since the request | Rejected at §30.5 check 19 and the Zone is recomposed from the same seed with the shrunken catalog. The catalog snapshot digest (§30.11.7) makes this detectable rather than silent |
| The manifest's `shell_id` is **unknown to the client** at load | **Hard error.** The Zone is refused with §34.13's message. It is never approximated |
| The client's shell catalog **digest differs** from the manifest's | Hard error, refused, same message. This is §30.9's consistency check extended to shells |

### 30.11.6 The deterministic offline selector

*Pinned: identical to Design 4 §17.6's shape.* Given the room and `offered_shells`, choose `offered_shells[H mod len(offered_shells)]` where `H` is the composition hash of `(zone_seed, room_id)`, over `offered_shells` sorted by id. It always yields a legal shell when the list is non-empty, it needs no model, and it is what §37.2's certified fallback Zone uses for every room.

### 30.11.7 The committed Zone manifest

**Epsilon's output is not reproducible by re-asking.** A future call with the same prompt may return a different legal shell, so "re-ask on load and expect the same answer" is not determinism — it is a coin flip that usually lands the same way.

Composition therefore **commits an immutable manifest**, and everything downstream reads the manifest rather than the model:

```
ZoneManifest:
  schema_version       : int = 1       # 5.6.2's migration key
  zone_id              : Id
  zone_seed            : int
  progression_state    : digest
  ap_catalog_digest    : digest
  shell_catalog_digest : digest        # the exact catalog the offers came from
  presentation         : ZonePresentation      # 30.1
  rooms                : list[RoomRecord]      # each with shell_id and connector_assignment
  machine              : MachineGraph
  packages             : list[PackageInstance]
  replay_verdicts      : list[ReplayVerdict]   # the named type in 5.6.3
  epsilon_provenance   : EpsilonProvenance     # the named type in 5.6.3
  manifest_digest      : digest        # over every field above
```

**Exactly one authoritative shape exists for each persisted type.** `ReplayVerdict` and `EpsilonProvenance` are defined once, in §5.6.3, and referenced by name here. A previous revision inlined an abbreviated anonymous `epsilon_provenance` shape alongside the named definition, which is two contracts for one field.

Four rules:

1. **Save, load, and replay reconstruct from the manifest.** Epsilon is **never** re-queried for a Zone that has one. This is the repair for the determinism conflict: byte-identical reconstruction is a property of the committed record, not of the model.
2. **`epsilon_provenance` records what was asked and what came back**, so a Zone can be explained without being re-generated, and `selected_offline` distinguishes a model choice from a fallback choice.
3. **The manifest is immutable after commit.** A change of any kind produces a new Zone, never an edited one.
4. **`manifest_digest` is checked at load** (§30.9). A mismatch refuses the Zone.

### 30.11.8 Replay verdicts are committed, not recomputed

The same reasoning closes the physics-determinism conflict §41.2 raised. Godot's solver is not guaranteed identical across machines, so **a replay verdict computed on the player's machine could differ from the one computed on another's, and two clients would then disagree about whether a Zone is legal from one seed.**

> **§23.5 check 20's replays run exactly once, in the canonical bridge environment, at composition. Each verdict is written into the manifest as a `ReplayVerdict` carrying the package id, the three run outcomes, the solver settings, and a digest of the package's initial physical configuration. The client never re-runs a replay and never re-derives a verdict.**

A `ReplayVerdict` is data like any other manifest field, covered by `manifest_digest`. If the package's authored configuration changes, its digest changes, and the stale verdict is rejected at load rather than silently trusted.

**This is what makes §35.4.1's `10.8 s` a one-time composition cost** rather than a per-load one, and it is why the replay execution model is contracted as serial and single-environment in §35.4: a verdict that only has to be produced once does not need to be fast, it needs to be reproducible.

### 30.11.9 What this does not authorise

`shell_id` selection is the **entire** extension of Epsilon's authority in this document. Epsilon still emits no transform, no distance, no node graph, no completion condition, no callback, no balance number, and no executable behaviour of any kind. It picks a name from a list the bridge proved legal, and §30.5 check 19 re-proves the choice on the composed Zone before it is committed.

---

# 31. CROSS-SYSTEM COMPATIBILITY

*Pinned: identical to Design 1 §31* for the base matrix, and to Design 2 §31.1, Design 3 §31, and Design 5 §31 for the rows each added. Every row survives.

## 31.1 The rows the union creates

Eleven pairs exist only here, because they pair systems no single proposal shipped together. Each is resolved in the section named.

| A | B | Resolution | Where |
|---|---|---|---|
| Latching | Macro state | Latches are room-layer, never machine-layer; both enter the state vector | §19.7, §4.10 |
| Latching | Signal verbs | A verb suppresses a latch temporarily; a latch reasserts next tick | §19.3 |
| Latching | Status | A Status may set a latch; a latch never expires with it | §20.7, §30.6 p8 |
| Constraints | Macro effects | `POWER_OFF` never puts a simulated mass in motion; deferred while the player is on one | §21.1.1, §21.11 |
| Constraints | Rails | Disjoint by composition check; relations sever on rail entry | §26.7, §30.5 c15 |
| Constraints | Zone-wide budget | Counted across simultaneously-powered rooms, not per package | §30.5 c14 |
| Status | Topology | Never; Status may not appear in an edge predicate | §30.6 p8 |
| Status | Reset | Cleared on reset; latches are not | §23.4 |
| `manipulate` | The verifier | A parameter, not a dimension; free by monotonicity | §29.5 |
| Composed items | Physics verbs | Physics verbs are `effect` atoms with non-costed discriminators | §11.7 |
| Composed items | Status verbs | Status effects are `effect` atoms; the thirteen are the `payload` alphabet | §11.7, §15.2 |

## 31.2 Relation exclusivity and the weapons invariant

*Pinned: identical to Design 2 §31.2 and §31.3.* One relation per object, and the ten-to-one arithmetic proving weapons out-damage manipulation — `6.3` DPS of physical impact against `64.3` DPS of weapon fire, at the most favourable physics build against the least favourable weapon.

The invariant holds unchanged under the union and is worth checking again, because the union adds two damage-adjacent systems Design 2 did not have. It survives both: no Status deals periodic damage (§15.3), and `exposed` sets Defense to zero without multiplying anything (§0.4). Neither raises the physics numerator. The `10:1` ratio is arithmetic on Design 2's numbers and those numbers are pinned.

## 31.3 Interaction density

The union's claim is not that it has more systems than any input. It is that the systems **touch**. That is arithmetic, so it is computed here rather than asserted.

Twelve major systems. Which proposals ship each:

| # | System | D1 | D2 | D3 | D4 | D5 | Amalgam |
|---:|---|:-:|:-:|:-:|:-:|:-:|:-:|
| 1 | Movement | Y | Y | Y | Y | Y | Y |
| 2 | Weapons | Y | Y | Y | Y | Y | Y |
| 3 | Abilities | Y | Y | Y | Y | Y | Y |
| 4 | Mobility | Y | Y | Y | Y | Y | Y |
| 5 | Manipulation — the twelve verbs | — | Y | — | — | — | Y |
| 6 | Constraints — genuinely simulated | — | Y | — | — | — | Y |
| 7 | Status | Y | Y | Y | Y | Y | Y |
| 8 | Signals | Y | Y | Y | Y | Y | Y |
| 9 | Machinery | Y | Y | Y | Y | Y | Y |
| 10 | Macro state — reversible, multi-state | — | — | Y | — | — | Y |
| 11 | Compositional generation | — | — | — | Y | — | Y |
| 12 | Forge | — | — | — | Y | — | Y |
| | **Systems shipped** | **7** | **9** | **8** | **9** | **7** | **12** |
| | **Pairs possible** | **21** | **36** | **28** | **36** | **21** | **66** |

Rows 5, 6, 10, 11, and 12 are the five system slots no single proposal filled more than two of. `n(n-1)/2` gives the last row: `21`, `36`, `28`, `36`, `21`, `66`.

**Sixty-six against a best-of-inputs thirty-six is `1.83×`.** That number is exact, it follows from the ship table above and nothing else, and it is the strongest quantitative claim this document makes. It is a claim about *surface area*, not about quality — a pair existing is not the same as a pair being good.

**How many of the 66 interact.** §36.1 generates all sixty-six rows mechanically and classifies each: **`51` INTERACTS** with a section reference, **`15` ORTHOGONAL** with a reason. Those totals are derived from the generated table rather than asserted before it, and §38 vector 66 re-derives them.

**What is deliberately not claimed.** The other five proposals were not audited pair-by-pair the same way, so no "stated rules" count is given for them and none should be inferred. The comparison above is on pairs *possible*, which is computable from the ship table, and stops there.

**The honest version of "the most fun".** Not that any one system beats its counterpart in another proposal — in most cases it is literally the same system, pinned across. The claim is that the number of places where two systems meet is `1.83×` the richest single proposal, that fifty-one of those meetings are required to have a stated outcome rather than an emergent surprise, and that §36.1 is the artefact that makes the requirement checkable instead of rhetorical.

The cost of that density is §41.2's subject, and it is not small.

---

# 32. ENEMIES AND ENCOUNTERS

*Pinned: identical to Design 1 §32.1 (the minimum enemy contract), §32.2 (six archetypes), §32.3 (faction behaviour), §32.5 (encounters and waves), §32.6 (death, drops, no respawn), §32.7 (boss phases).*

*Pinned: identical to Design 4 §32.8* — `SKIRMISHER` is balance-load-bearing and its stats are frozen, because §11.7's atom prices are all quoted against it.

*Pinned: identical to Design 3 §32.8* — encounter arming through `ENCOUNTER_ENABLE`, with the `2.0 s` audible delay when the player is already inside; and encounter cleared-flags as monotone state-vector components.

*Pinned: identical to Design 2 §32.7's restriction* — a boss arena contains no physics puzzle. A solver under encounter load is where the frame budget breaks, and that was true in Design 2 with four Statuses; it is more true here with thirteen.

## 32.1.1 Enemy attacks and Status — modifies Design 1 §32.1

Design 1 states that enemy attacks never apply Status to the player, as a deliberate asymmetry against "anchored and cannot act" frustration.

**The union keeps the asymmetry and states its exact boundary**, because with thirteen Statuses and five target kinds the boundary is no longer obvious:

| Source | May apply Status to the player? |
|---|---|
| An enemy attack | **Never** |
| An authored hazard (Design 5 §25.7) | **Yes** — hazards are telegraphed, static, and avoidable |
| A `SELF_STATUS` Ability (Design 5 §12.5) | **Yes** — the player chose it |
| A `STATUS_TRANSFER` mis-selection | **Yes** — the player chose the destination |
| A compound formed on the player from any of the above | **Yes** |
| A physical impact (Design 2 §14.7) | Damage only; `DISPLACED` is a physics state, not a Status |

The rule is *who decided*: the player or an authored, visible piece of the world may put a Status on the player; a reactive agent may not. That keeps Design 1's frustration argument intact while letting Design 5's hazards and self-application ship whole.

## 32.4 Status- and physics-compatible AI

*Pinned: identical to Design 5 §32.8* for all thirteen actor-legal Statuses and the rule that `suspended` does not count toward encounter clear.

*Pinned: identical to Design 2 §32.4* for `DISPLACED`, the `PIN` response, dynamic-obstacle pathfinding re-queried at `4 Hz`, and the rule that **enemies never move objects**.

Two rows the union must add, because they name conditions no single proposal could produce:

| Condition | AI response |
|---|---|
| `exposed` | No AI change. Defense is `0.0`; behaviour is unchanged |
| `DISPLACED` while carrying an actor-legal Status | The Status continues to tick. `DISPLACED` suppresses *actions*, never Status duration |

The second is the case that would otherwise be a bug rather than a decision: an enemy launched by an impulse while `burning` must keep burning, or a physics build accidentally cleanses the Status a fire build applied.

**Why enemies never move objects, restated.** It is Design 2's rule and it carries more weight here. If an enemy could push a crate, an enemy could set a latch, and a latch is a state-vector component §30.6 assumes only the player can advance. The verifier's Latch transition is legal on player action alone. An enemy that could latch would make the reachability proof unsound, and this one-line AI restriction is what keeps it sound.

---

# 33. HUD AND PRESENTATION

*Pinned: identical to Design 1 §33.1 through §33.6* — the always-visible list, feed displays, the three distinct recharge treatments, device presentation, causality feedback, and the colour rules.

*Pinned: identical to Design 2 §33.7* — physical state readability, including the three-stage constraint-stress display.

*Pinned: identical to Design 3 §33.7 and §33.8* — the Zone Diagram, read-only, with per-variable discovery; and in-world machine readability.

*Pinned: identical to Design 4 §33.7 and §33.8* — the composition line, trigger clauses in plain words, and side-by-side comparison.

*Pinned: identical to Design 5 §33.7, §33.8, §33.9* — per-family Status marker shapes with verbatim sentences, compound telegraphing, and the transfer selector.

## 33.10 The screen-space problem, and its resolution

Five proposals' HUD requirements do not fit on one screen simultaneously. This is the union's most concrete presentation defect and it needs a rule, not an apology.

Count what is always-on if every pin is taken literally: Health, Barrier, Weapon and feed, five Abilities, Mobility, player Statuses, interaction prompt, physical-state overlays on every nearby object, constraint stress on every constraint, Status markers on up to `40` targets, compound hints on a subset of those, and machine-readability cues on every conduit. In a powered room with an encounter and a physics puzzle, that is a screen the player cannot read.

**The resolution is a three-tier contract**, and every element above is assigned to exactly one tier.

| Tier | Rule | Contents |
|---|---|---|
| **Persistent** | Always drawn, never occluded, never faded | Health, Barrier, Weapon and feed, Ability row, Mobility, player's own Statuses, interaction prompt |
| **Proximate** | Drawn for every target within `12.0 m`, **plus** the target under the crosshair at any range | Status markers, compound hints, physical-state outlines, mass-class cues, attach-point markers |
| **Summoned** | Drawn only while a modal input is held | Zone Diagram (`Tab` long press), transfer selector (`STATUS_TRANSFER` cast), item comparison (Archive) |

Three rules govern the tiers:

1. **Persistent never yields.** No proximate or summoned element may overlap, dim, or animate over a persistent element. The persistent tier owns its screen regions absolutely.
2. **Proximate elements degrade by distance, never by importance.** At `40` targets in range, markers past the nearest `12` render as a single glyph without duration ring or sentence. The nearest twelve always render fully. Sorting is by distance, then by whether the player applied it, then by target id — deterministic, so the display does not flicker between frames.
3. **Summoned elements suspend the proximate tier entirely** while held. The Zone Diagram is not drawn over a field of Status markers.

Two elements are promoted above their natural tier because the union makes them safety-critical rather than informational:

- **Constraint stress at `95%`** renders persistently, at screen edge if off-screen, because §21.11's power-loss guard protects the player from *macro* changes and nothing protects them from a rope they cannot see about to break.
- **`waiting — someone is on the gantry`** (§21.11) renders persistently for the player who triggered the deferral, because a control that appears not to work is worse than one that refuses.

Everything else stays in its tier. This is the section a HUD implementer will read first and it is the one place in this document where the union genuinely had to invent rather than merge.

---

# 34. PLAYER-FACING FLOW

*Pinned: identical to Design 1 §34.1 through §34.9* — first run, Zone entry, Zone completion, capability refusal with qualifying Archive entries listed, death and checkpoint restore, Hub loadout editing, manual save rules, interaction refusal, and rejection feedback.

*Pinned: identical to Design 1 §34.10 and §34.11* — the two ways to leave a Zone and what each preserves.

*Pinned: identical to Design 2 §34.7 and §34.9* — save refused while physics is in motion, and physical rejection feedback.

*Pinned: identical to Design 3 §34.11, §34.12, §34.13* — signal-verb rejection feedback, macro-change feedback, and load refused as unreachable.

*Pinned: identical to Design 4 §34.13 and §34.14* — the Forge screen and composition-failure messaging.

*Pinned: identical to Design 5 §34.11* — Status rejection feedback.

## 34.15 One refusal the union creates

Every proposal's rejection feedback answers "why did that not work." The union produces one refusal none of them has:

**A manipulation refused because the player lacks `manipulate` on a mandatory route is impossible by construction** — §29.2's entry validation blocks the Zone before the player enters it, listing qualifying Archive entries. But a manipulation refused on an *optional* route is both possible and common, since optional routes may require anything (§29.2, pinned from Design 2 §29.5).

The feedback distinguishes them explicitly:

| Situation | Message |
|---|---|
| No manipulation Ability equipped, optional route | *"Nothing here can move that."* — names the requirement, not the fix |
| Manipulation equipped, object over the verb's mass limit | *"Too heavy for this."* — names the object's mass class and the verb's limit |
| Manipulation equipped, object is `FIXED` | *"That is part of the building."* |
| Manipulation equipped, relation cap reached | *"Both hands are full."* — names what is held |

The first message is deliberately not *"you need a physics Ability"*. A player on an optional route has found something they cannot do yet, and telling them precisely which item to equip converts exploration into a shopping list. Player Authority §30.3 rejects mandatory composition knowledge for the same reason.

---

# 35. PERFORMANCE BUDGETS — rewritten

Design 1 §35, Design 2 §35, Design 3 §35.1, Design 4 §35.1, and Design 5 §35 **cannot coexist unchanged**. Design 2's `40` rigid bodies and Design 5's `90` Status entries were each sized against a runtime containing the other four proposals' systems at Design 1's levels, not against each other. This section is therefore written from scratch, and it is the only section in this document that is.

## 35.0 The frame

`60 fps` on the target hardware is `16.667 ms`. The budget allocates it, and the rows sum to **less** than the frame rather than to a rounded-up total:

| Consumer | Budget | Notes |
|---|---:|---|
| Physics solver | `4.0 ms` | `40` bodies, `8` constraints, `8` iterations |
| Rendering | `7.0 ms` | Unchanged from Design 1's assumptions |
| Enemy AI | `1.5 ms` | `10` enemies, pathfinding re-queried at `4 Hz` |
| Signal graphs | `0.3 ms` | Event-driven; this is worst-case churn |
| Status evaluation | `0.4 ms` | See §35.2's staggering rule |
| Trigger clauses | `0.3 ms` | `13` active, queue depth `8` |
| Gameplay, animation, audio, everything else | `3.0 ms` | |
| **Allocated** | **`16.5 ms`** | |
| **Headroom** | **`0.167 ms`** | Unallocated, deliberately |
| **Frame** | **`16.667 ms`** | `1000 / 60` |

An earlier revision allocated `16.7 ms` against a `16.67 ms` frame, which is `0.033 ms` overcommitted before anything runs. The rows now sum to `16.5 ms` and the remainder is left unallocated.

**Two kinds of budget, and only one is a composition check.** Conflating them is why the table above reads as though a composer could enforce it:

| Kind | Examples | Enforced by |
|---|---|---|
| **Static counts** — properties of the composed Zone | bodies, constraints, projectiles, `ActiveStatus` entries, signal nodes, actuators, enemies, hazard volumes, trigger clauses | **Composition.** §30.5 checks 14 and 16, and §35.1's table. A Zone exceeding one is rejected before it is served |
| **Measured milliseconds** — properties of the machine | solver ms, render ms, AI ms, Status evaluation ms | **Performance certification** (§35.5), on target hardware, as a test. **Never** at composition — a composer cannot know what a renderer will cost on a machine it has never seen |

Every count in §35.1 is composition-enforced. Every millisecond in §35.0 is a certification target. Exceeding a **count** is a validation failure at composition; exceeding a **millisecond target** is a failed performance certification and a tuning task.

## 35.1 Runtime budgets

| Quantity | Amalgam | D1 | D2 | D5 | Why this value |
|---|---:|---:|---:|---:|---|
| Loaded rooms | `3` | `3` | `3` | `3` | Unchanged in all five |
| Active rigid bodies per loaded room | `40` | `12` | `40` | — | Design 2's; physics ships whole |
| Active rigid bodies, all loaded rooms | `90` | `36` | `90` | — | Design 2's |
| Simultaneous non-sleeping bodies | `24` | — | `24` | — | Design 2's, with its forced-sleep rule |
| Active constraints per room | `8` | — | `8` | — | Design 2's |
| Active constraints, all loaded rooms | `20` | — | `20` | — | Design 2's |
| Solver iterations per tick | `8`, fixed | — | `8` | — | Design 2's; also the replay setting |
| **`ActiveStatus` entries per target** | **`3`** | — | — | `3` | Design 5's |
| **Status-carrying targets per room** | **`24`** | — | — | `40` | **Reduced.** See §35.2 |
| **Total `ActiveStatus` entries per room** | **`60`** | — | — | `90` | **Reduced.** See §35.2 |
| Status-carrying surfaces per room | `16` | — | — | `16` | Design 5's; surfaces are not solver bodies |
| Live projectiles, all sources | `48` | `64` | `48` | — | Design 2's; the solver takes the headroom |
| Live projectiles per Weapon | `18` | `24` | `18` | — | Design 2's |
| Active enemies | `10` | `12` | `10` | — | Design 2's |
| Actuators per room | `6` | `6` | `6` | — | Unchanged |
| Signal nodes per room | `20` | `20` | `20` | — | Unchanged |
| Signal updates per second per room | `40` | `40` | — | — | Unchanged |
| Active hazard volumes per room | `8` | `8` | `8` | — | Unchanged |
| Fire Actors per room | `4` | `6` | `4` | `6` | **Design 2's.** Fire Actors are solver-adjacent |
| Deployables per player | `2` | `2` | — | — | Unchanged |
| Player relations held | `3`, up to `6` with `RULE_RELATION_COUNT` | `2` | `3`/`6` | — | Design 2's |
| Player-created tethers | `3` | — | `3` | — | Design 2's |
| Active trigger clauses, whole loadout | `13` | — | — | — | Design 4's |
| Trigger queue depth per event | `8` | `8` | — | — | Design 1's |
| `spreading` propagation radius | `12.0 m` | — | — | `12.0 m` | Design 5's |
| `conductive` link depth | `4` | — | — | `4` | Design 5's |
| `arc_path` affected actors | `4` | — | — | `4` | Design 5's |

## 35.2 The two reductions, and why they are here

Two of Design 5's numbers come down. Both are Status counts, and both come down because Design 5 sized them against Design 1's `12` rigid bodies per room.

**Status-carrying targets per room: `40` → `24`.** Design 5's `40` was chosen to cover a room's worth of enemies and objects. Under the union a room may hold `40` rigid bodies, `24` of them awake, plus `10` enemies. Setting the Status target cap to `24` ties it to the **non-sleeping body cap** rather than to the total: a sleeping body is not participating in anything, and a Status on it costs an evaluation for no visible result. The rule is therefore mechanical rather than arbitrary:

> **A Status may not be applied to a sleeping, unfocused body.** Application wakes the body if it is eligible; if the wake would exceed the `24` non-sleeping cap and no unprotected sleep candidate exists (Design 2 §35), the application is **refused** with the §34 Status rejection feedback, and the cost is not spent.

That is a visible, explicable refusal rather than a silent cap, and it makes the two budgets one budget.

**An authored hazard at the cap is refused identically.** A hazard applying `burning` to a `25`th body is refused with the same feedback on the target rather than silently succeeding, because a Status the budget cannot hold is a Status the player cannot see. The hazard's damage still resolves through §8 — refusing the Status never refuses the damage. It degrades to "the hazard hurt but did not ignite" rather than to an overrun.

### 35.2.1 Reserved capacity — mandatory Status latches are never refused

A refusable Status application and a verifier that assumes a Status latch is settable **cannot both be right.** §30.6's Latch transition treats a `STATUS_GATE` or `COMPOUND_LOCK` latch as legal from any configuration reaching its room; §35.2's cap can refuse the very application that sets it. The verifier would then be proving a transition the runtime can decline, which is the one failure mode §30.6 exists to make impossible.

The budget is therefore split, and the split is a composition-time obligation:

> **Every package with a non-null `status_required` reserves, at composition, the exact `ActiveStatus` entries and non-sleeping body slots its authored solution consumes.** Reserved capacity is deducted from the room's `60`-entry and `24`-body budgets before any ordinary application is considered. **Ordinary and optional applications may consume only unreserved capacity.**

Four rules make that exact:

1. **The reservation is computed from the package's own manifest**, not estimated: the target count its `status_required` names, times the entries each carries, plus the components of any compound in a `COMPOUND_LOCK`. For §24's four Status families that is at most `3` bodies and `5` entries per package.
2. **A reserved slot is held for its named target.** It is not a floating allowance an unrelated crate can occupy.
3. **An ordinary application that would encroach on reserved capacity is refused** with §34's feedback, exactly as one exceeding the total cap is. From the player's side the two refusals are the same message.
4. **§30.5 check 20:** the sum of all reservations in a room, plus one ordinary application, is at most the room's caps. A Zone whose mandatory Status puzzles reserve more than `60` entries or `24` bodies in one room is rejected at composition.

**The consequence, which is the whole point:** a room can be saturated with ambient Status — every unreserved slot consumed by burning crates and shocked enemies — and the mandatory `COMPOUND_LOCK` still solves, because its capacity was never available to be taken. §37.3's fixture U9 is that scenario and it must pass.

### 35.2.2 Reservation is necessary but not sufficient — the application roll

Reserved capacity stops a *budget* refusal. It does nothing about a *chance* refusal, and every authored Status source in Design 5 §25.7 is probabilistic:

| Source | Status | Chance |
|---|---|---:|
| `FLAME_JET` | `burning` | `0.50` |
| `ELECTRIC_FIELD` | `conductive` | `0.45` |
| `COOLANT_VENT` | `slippery` | `0.60` |
| `PHASE_EMITTER` | `phased` | `0.55` |

§30.6's Latch transition treats a `STATUS_GATE` or `COMPOUND_LOCK` latch as settable from any configuration reaching its room. A `0.45` roll can fail indefinitely. **A verifier transition that depends on an unbounded sequence of coin flips is not a proof**, and this is the same class of defect as §35.2.1 arriving through a different door.

> **The guaranteed puzzle-source path.** A `status_source` **declared by a mandatory package in its manifest** applies its declared `status_required` to the package's declared solution target **without a chance roll**, after legality and trait checks pass. Application consumes the package's reserved capacity (§35.2.1).

Five rules bound it to exactly the case that needs it:

1. **Declared-target only.** The guarantee covers the `(source, status, target)` triple the manifest names. The same `FLAME_JET` applied to an enemy, a crate, or the player rolls its `0.50` like any hazard.
2. **Legality still applies.** Trait susceptibility (Design 5 §15.6), immunity and substitution (§15.7), and the reserved-capacity check all run first. The guarantee removes the *roll*, not the *rules* — a `burning` source aimed at a stone crate still fails, and §23.5 check 26 already rejects that package at composition.
3. **It is a composition-time property, not a runtime mode.** `guaranteed_application` is derived from the manifest at validation; nothing toggles it in play, and no player action extends it to another target.
4. **Optional solutions keep their rolls.** A package's `optional_solutions` list is unaffected — the guarantee attaches to the mandatory path only.
5. **§30.5 check 22.** Every package with a non-null `status_required` has a declared `status_source` and a declared solution target, and that triple is marked `guaranteed_application`. A mandatory Status latch reachable only through a rolled application is rejected at composition.

**Why not simply raise the chances to `1.0`.** Because that would change every hazard in the game. `FLAME_JET` at `0.50` is a real combat and traversal texture Design 5 §25.7 chose deliberately; a jet that always ignites is a different hazard. The guarantee is scoped to the puzzle's own declared solution precisely so the hazard stays what it is everywhere else — which is also why fixture U16 tests both halves in the same room.

**Total `ActiveStatus` entries per room: `90` → `60`.** `24` targets × `3` entries is `72`, and `60` is below it, so the entry cap binds before the target cap in a dense room. That is intentional: it means the failure mode is "this crate cannot take a third Status right now", which is local and understandable, rather than "no more Statuses anywhere", which is not. When the entry cap is reached, application is refused by the same rule.

**Nothing else in Design 5 is reduced.** Twelve base Statuses plus `exposed`, eight compounds, five target kinds, `STATUS_TRANSFER`, `SELF_STATUS`, and compound telegraphing all ship at full strength. What is smaller is how many objects in one room may carry them at once, and the reduction is from `90` simultaneous entries to `60` — a number a room still cannot reach in ordinary play.

## 35.3 Status staggering — new to the union

Design 5 evaluates every Status at `1 Hz`. Under Design 5 alone, `90` entries landing on the same frame is `90` cheap evaluations and no solver competing for the frame. Under the union, that frame may also be a solver frame with `24` awake bodies and `8` constraints, and a synchronised tick puts the whole Status layer on the worst possible frame.

**Staggering rides the fixed simulation tick, never the rendered frame.** The engine runs physics and gameplay at a fixed `60` ticks per second independent of render rate; `sim_tick` is that counter. Rendered frames are not a clock and must never be used as one — at `120 fps` a frame-indexed rule would evaluate every Status at `2 Hz`, and at `30 fps` at `0.5 Hz`, making Status duration a function of the player's graphics settings.

**Each room keeps a ring of `60` phase buckets.** On application, an `ActiveStatus` is placed in the bucket holding the fewest entries, ties broken by lowest index. On expiry it leaves its bucket.

```
SIM_HZ = 60                        # fixed gameplay tick, render-independent
phase  = argmin_i |bucket[i]|, ties broken by lowest i
evaluate when (sim_tick mod SIM_HZ) == phase
```

Each Status therefore evaluates exactly once per `60` simulation ticks, which is exactly once per second of game time, at every render rate including uncapped and fluctuating. If the simulation tick rate is ever changed, `SIM_HZ` changes with it and the `1 Hz` guarantee is preserved by construction rather than by coincidence.

Least-loaded placement is chosen over a hash because it gives an **exact** bound rather than a probabilistic one: with `n` entries in a room the maximum bucket load is `ceil(n / 60)`, so at the `60`-entry cap no frame ever evaluates more than one. A hash would put the worst case at three or four by collision, which is fine on average and is not a guarantee — and this section exists precisely to remove a once-per-second spike.

Placement is deterministic given the application order, so a replay produces identical bucket assignments. The evaluation rate is still `1 Hz` per Status — nothing about Design 5's mechanics changes — and duration countdown plus marker depletion remain per-frame presentation as Design 5 specifies.

This is a pure implementation rule with no player-visible consequence, and it is in the design document because it is the difference between `0.4 ms` and a `2 ms` spike once a second.

## 35.4 Composition-time budgets

*Pinned: identical to Design 3 §35.1* for the search budgets, with the values §30.2 revised, plus Design 4's item budgets and the union's replay cost.

| Quantity | Budget |
|---|---:|
| State-vector product | `4096` |
| Rooms | `12` |
| Topology edges | `20` |
| Macro variables | `8` |
| Setter packages | `8` |
| Vector latches | `8` |
| Rail junctions per Zone | `6` |
| Rail segments per Zone | `12` |
| Product-graph configurations searched | `49,152` |
| Model-check wall clock | `2.0 s` per Zone attempt |
| **Physics replays per Zone** | **`36`** — `12` packages × `3` runs, capped by §30.5 check 17 |
| **Physics replay wall clock** | **`10.8 s` per Zone attempt**, serial |
| **Epsilon shell selection** | `20.0 s` worst case, one batched request, not re-asked on retry (§35.4.2) |
| **Total composition budget including retries** | **`88.0 s` per Zone** = `20.0` + `5` attempts × `13.6` (§35.4.3) |
| Atom catalog resolution, per item, on Archive load | `0.5 ms` |
| Full Archive expansion at `5,000` items | `2.5 s`, once, off the main thread |
| Interpretation round-trip timeout | `10.0 s`, then §17.10's fallback |

The replay budget deserves its emphasis, and two successive revisions got it wrong in the same place. The first stated `1.8 s`, which requires `160×` throughput against the `40×` the same sentence assumed. The second fixed the throughput but used the wrong duration.

### 35.4.1 The replay bound is `max_duration`, not `settle_timeout`

The second error, of the same family as the first. `settle_timeout = 8.0 s` (Design 2 §23.1) is how long the validator waits for a package's **initial configuration** to come to rest — it is check 22's bound. Check 20 replays a `ReferenceSolution`, whose bound is `ReferenceSolution.max_duration`, an unbounded field in Design 2's schema. **Using `8.0 s` for the replay was using the wrong quantity**, and it happened to be the smaller one.

The union bounds the right field and validates the bound:

> **`ReferenceSolution.max_duration ≤ MAX_REPLAY_DURATION = 12.0 s`.** §23.5 **check 31** rejects any package declaring more. `12.0 s` is one second per step at Design 2 §23.1's twelve-step ceiling, which is what a `PUSH`, `MOVE_TO`, or `WAIT` step actually costs.

Recomputed against the right quantity:

| Term | Value |
|---|---:|
| Replays per Zone attempt | `36` (`12` packages × `3` runs) |
| Replayed seconds each | ≤ `12.0` (`MAX_REPLAY_DURATION`) |
| Total simulated | `432 s` |
| Headless throughput, required minimum | `40×` real time |
| Execution model | Serial, single-threaded, one canonical environment |
| **Worst-case wall clock** | **`10.8 s`** |

**The execution model is part of the contract, not an implementation detail.** Replays run serially in one canonical bridge environment because §30.11.8 requires their verdict to be reproducible and committed; parallelism across cores is permitted only if it cannot change a verdict, and since it cannot change a verdict it also cannot be relied on to lower the budget. `10.8 s` is therefore the number every other budget is built from.

If measured throughput proves better than `40×`, the budget falls and nothing else changes. If it proves worse, §30.5 check 17's cap of `12` replay packages is the dial: at `6` the worst case is `5.4 s`. §41.2 names this as the tuning response.

### 35.4.2 Epsilon shell selection — cardinality and its cost

A total wall clock that omits the model request is not a total. §30.11.10 fixes the shape:

| Property | Value |
|---|---|
| Requests per Zone | **One, batched at Zone level** — every room's `offered_shells` in a single request, every `shell_id` in a single response |
| Timeout | `10.0 s` (Design 4 §17.4's interpretation timeout) |
| Repair attempts | `1`. A response with any invalid selection is repaired once per §17.4 |
| On second failure | §30.11.6's deterministic offline selector, which costs microseconds |
| **Worst-case Epsilon wall clock** | **`20.0 s`** — two `10.0 s` timeouts |
| On a Zone retry (seed + 1) | **Epsilon is not re-asked.** The offline selector chooses for every retry attempt |

Batching is what keeps this bounded: twelve serial per-room requests at a `10.0 s` timeout would be `120 s` of worst case for a decision that is one list per room. Not re-asking on retry is the same reasoning — a structural failure is not evidence the shell choice was wrong, and the certified offline selector is always legal.

### 35.4.3 The corrected total

| Term | Value |
|---|---:|
| Epsilon shell selection, once per Zone | `20.0 s` |
| Per composition attempt: replay | `10.8 s` |
| Per composition attempt: model check | `2.0 s` |
| Per composition attempt: everything else | `0.8 s` |
| **Per attempt** | **`13.6 s`** |
| Attempts before the §37.2 fallback Zone | `5` |
| **Total worst case** | **`88.0 s`** = `20.0 + 5 × 13.6` |
| **First-attempt deterministic compute** | **`13.6 s`** — the bridge-owned work, excluding all model latency |
| **First-attempt total** | **`13.6 s` + actual Epsilon latency** |
| **First-attempt bounded worst case** | **`33.6 s`** = `13.6 + 20.0`, when both Epsilon requests time out |

The replay is the largest per-attempt cost, roughly `5×` the model check, and §30.8's package-level retry exists specifically so a failure does not re-pay it.

`88.0 s` against Design 3's `20.0 s` is the honest price of the union's composition, and `13.6 s` is what a Zone that composes first time actually costs. §41.2 says what to do if it proves too slow.

## 35.5 Performance certification — what composition cannot check

§35.1's counts are composition-enforced. §35.0's milliseconds are not, and cannot be: the composer runs in the bridge and has never seen the player's GPU.

**The certification fixture.** One authored Zone, built to every §35.1 count simultaneously — `40` bodies and `8` constraints in the loaded room, `24` of them awake, `60` `ActiveStatus` entries, `10` enemies mid-encounter, `20` signal nodes, a constraint at `95%` stress, and the Zone Diagram summonable. It is not a Zone the composer would produce; it is the worst legal Zone, authored deliberately.

| Measure | Target | Failing means |
|---|---|---|
| Frame time, 99th percentile, target hardware | ≤ `16.667 ms` | A tuning task against §35.0's row allocations |
| Physics solver | ≤ `4.0 ms` | Reduce §35.1's body or constraint caps and recompose |
| Status evaluation, worst tick | ≤ `0.4 ms` | §35.3's bucketing is not distributing; a composer bug |
| Composition wall clock, worst Zone | ≤ `88.0 s` | Reduce §30.5 check 17's replay cap, or default to the offline selector |

**Target hardware is named in the fixture, not here**, because it is a project fact that changes and this document should not go stale when it does. What this document fixes is that the certification exists, what it measures, and that a failure is a tuning task rather than a validation failure — a Zone that passes composition is *legal*; whether it is *fast* is a separate question answered on a real machine.

---

# 36. DEBUGGING AND INSPECTION

*Pinned: identical to Design 1 §36* for all fourteen inspectables.

*Pinned: identical to Design 2 §36* — the solver overlay, constraint values and stress, relation display, forced-sleep events, and stalled `DRIVER` reporting.

*Pinned: identical to Design 3 §36* — the machine-graph inspector, macro-effect log, and model-check witness replay.

*Pinned: identical to Design 4 §36* — the composition inspector showing atoms, costs, budget spent, and mask evaluation.

*Pinned: identical to Design 5 §36* — the Status table with per-entry phase, source, and remaining duration.

## 36.1 The system map — all 66 pairs

Generated mechanically from §31.3's twelve-system inventory, every unordered pair emitted exactly once. A previous revision listed only the fifteen orthogonal pairs while §38 vector 66 claimed the page carried all sixty-six — and two of those fifteen rows said INTERACTS, so it was not even a list of fifteen orthogonal pairs. Both defects are why this table is generated rather than written.

**`51` INTERACTS, `15` ORTHOGONAL, `66` total.** The totals are derived from the table below, not asserted ahead of it.

| Pair | Class | Section or reason |
|---|---|---|
| Movement — Weapons | INTERACTS | §6.2, §11 |
| Movement — Abilities | INTERACTS | §6.2, §12 |
| Movement — Mobility | INTERACTS | §13 |
| Movement — Manipulation | INTERACTS | §14.4 |
| Movement — Constraints | ORTHOGONAL | The movement law is evaluated against static geometry; a constrained body is a dynamic obstacle handled by §26.7's rails rule and by collision, not by the law |
| Movement — Status | INTERACTS | §15.2 (`rooted`, `floundering`) |
| Movement — Signals | ORTHOGONAL | A signal never alters the movement law; it moves actuators, which §21.3 handles as platform velocity |
| Movement — Machinery | INTERACTS | §21.3 |
| Movement — Macro state | ORTHOGONAL | A macro effect changes what geometry exists, never how the player moves through it |
| Movement — Compositional generation | ORTHOGONAL | The movement law constrains room geometry at authoring, never at composition |
| Movement — Forge | ORTHOGONAL | Forge is Hub-only; the movement law is a Zone-runtime constant |
| Weapons — Abilities | INTERACTS | §12.5 hybrids |
| Weapons — Mobility | INTERACTS | §13.7 |
| Weapons — Manipulation | INTERACTS | §31.2's 10:1 invariant |
| Weapons — Constraints | ORTHOGONAL | Weapons damage; they do not manipulate. §31.2's invariant depends on this |
| Weapons — Status | INTERACTS | §11.7 payload atoms |
| Weapons — Signals | INTERACTS | §20.2 `SHOOTABLE_TARGET` |
| Weapons — Machinery | INTERACTS | §25 destructibles |
| Weapons — Macro state | ORTHOGONAL | A weapon never sets a variable; `SHOOTABLE_TARGET` is a signal input, not a setter |
| Weapons — Compositional generation | INTERACTS | §11.7, §11.9 |
| Weapons — Forge | INTERACTS | §18 |
| Abilities — Mobility | INTERACTS | §12.8 |
| Abilities — Manipulation | INTERACTS | §11.7 `effect_physics_*` |
| Abilities — Constraints | INTERACTS | §14.8 |
| Abilities — Status | INTERACTS | §11.7 `effect_status` |
| Abilities — Signals | INTERACTS | §11.7 `effect_signal_*` |
| Abilities — Machinery | ORTHOGONAL | Abilities act on actors and objects; machinery is kinematic and unaffected |
| Abilities — Macro state | INTERACTS | §19.3 signal verbs |
| Abilities — Compositional generation | INTERACTS | §12.7 |
| Abilities — Forge | INTERACTS | §18 |
| Mobility — Manipulation | INTERACTS | §13.7 relations survive Mobility |
| Mobility — Constraints | INTERACTS | §26.7 |
| Mobility — Status | INTERACTS | §15.2 (`phased`, `updraft`) |
| Mobility — Signals | INTERACTS | §20 `PROXIMITY_SENSOR` |
| Mobility — Machinery | INTERACTS | §21.7 LaunchPad |
| Mobility — Macro state | INTERACTS | §28.4 capability-gated edges |
| Mobility — Compositional generation | ORTHOGONAL | Mobility is not atom-composed (§12.8) and never affects Zone composition |
| Mobility — Forge | ORTHOGONAL | §12.8: Forge excludes Mobility entirely |
| Manipulation — Constraints | INTERACTS | §26.5, §14.8 |
| Manipulation — Status | INTERACTS | §15.2 (`lightened`, `anchored`) |
| Manipulation — Signals | INTERACTS | §20.5 `WEIGHT_THRESHOLD` |
| Manipulation — Machinery | INTERACTS | §21.10 |
| Manipulation — Macro state | INTERACTS | §21.11 deferral guard |
| Manipulation — Compositional generation | INTERACTS | §11.7 |
| Manipulation — Forge | ORTHOGONAL | Forge is Hub-only; manipulation is Zone-only |
| Constraints — Status | INTERACTS | §15.2 on constrained bodies |
| Constraints — Signals | INTERACTS | §20.5 `CONSTRAINT_STATE` |
| Constraints — Machinery | INTERACTS | §21.10 `WINCH`/`BRAKE`/`DRIVER` |
| Constraints — Macro state | INTERACTS | §21.1.1, §30.5 check 14 |
| Constraints — Compositional generation | INTERACTS | §30.5 check 14 bounds what composition may place |
| Constraints — Forge | ORTHOGONAL | Forge is Hub-only; constraints are Zone-only |
| Status — Signals | INTERACTS | §20.5 Status sensors |
| Status — Machinery | INTERACTS | §25.7 Status hazards |
| Status — Macro state | INTERACTS | §30.6 property 8 — **only** through a latch |
| Status — Compositional generation | INTERACTS | §11.7's `effect_status` atoms are part of the composed alphabet |
| Status — Forge | INTERACTS | §18.2 — Forge may recompose or preserve `effect_status` atoms |
| Signals — Machinery | INTERACTS | §19.3, §21 |
| Signals — Macro state | INTERACTS | §19.7 the machine graph |
| Signals — Compositional generation | INTERACTS | §30.3 step 11 places signal packages |
| Signals — Forge | ORTHOGONAL | Forge is Hub-only; signals are Zone-only |
| Machinery — Macro state | INTERACTS | §21.10 macro effects |
| Machinery — Compositional generation | INTERACTS | §30.3 step 11 |
| Machinery — Forge | ORTHOGONAL | Forge is Hub-only; machinery is Zone-only |
| Macro state — Compositional generation | INTERACTS | §30.3 steps 6–10 |
| Macro state — Forge | ORTHOGONAL | Forge is Hub-only; macro state is Zone-only |
| Compositional generation — Forge | INTERACTS | §18.1 Recompose |

Two naming corrections a previous revision needed. System 11 is **Compositional generation** — item composition — and it is not the same thing as Zone composition, which is §30 and is not one of the twelve systems. `Status — Compositional generation` is therefore **INTERACTS** (§11.7 puts `effect_status` atoms in the composed alphabet), and the orthogonality that does hold is between Status and *Zone* composition, which §30.6 property 8 states in its own section. `Status — Forge` is likewise INTERACTS, because §18.2 lets Forge preserve or recompose those atoms.

The page exists so that "these two systems do not interact" is a **recorded decision** rather than a gap. Five of the fifteen orthogonal rows are the same fact — Forge is Hub-only — and stating it five times in a generated table is better than five separate silences.

---

# 37. REFERENCE FIXTURES

## 37.1 Pinned fixture sets

Every fixture any proposal shipped, taken whole.

| Set | Count | Source |
|---|---:|---|
| Family fixtures for the eighteen Design 1 families | `18` | *Pinned: identical to Design 1 §37*, `20 × 20 × 6 m` shell |
| Family fixtures for the eight Design 2 families | `8` | *Pinned: identical to Design 2 §37* fixtures 10–16 and 1, `24 × 24 × 8 m` shell |
| Zone-scale fixtures for the four Design 3 families | `4` | *Pinned: identical to Design 3 §37* fixtures 15–18, four-room test Zone |
| Family fixtures for the four Design 5 families | `4` | *Pinned: identical to Design 5 §37.1* |
| Status-family and compound fixtures | `12` | *Pinned: identical to Design 5 §37.2 and §37.3* |
| Composition fixtures | `9` | *Pinned: identical to Design 4 §37* |
| **Subtotal** | **`55`** | |

Where two proposals ship a fixture for the same family, both ship: `fx_carry_to_plate` and `fx_push_to_plate` are different rooms testing different verbs.

## 37.2 The certified fallback Zone

*Pinned: identical to Design 3 §37 fixture 19*, with Design 2 §37 fixture 17's restriction applied: **eight rooms, tree topology, two irreversible two-state variables, zero vector latches, zero constraints, no `manipulate` requirement, no rail network, no cross-room carryables.**

The fallback for a proposal running three stacked validators uses none of the three. It passes the model check by construction with `R = E`, it needs no physics replay, and its state vector is `4` configurations.

## 37.3 The union fixtures — new

Nineteen fixtures that exist only here, because each exercises a seam no single proposal had. All use Design 3's four-room test Zone (`A`, `B`, `C`, `D` in a square; edges `A–B`, `B–C`, `C–D`, `D–A`; entry `A`, exit `C`) unless stated.

| # | Fixture | Setup | Expected |
|---|---|---|---|
| U1 | `fx_latch_across_macro` | `BRIDGE_ASSEMBLY` in `B` with two `GIRDER` (`95 kg`); its latch is a vector latch. Variable `power` states `gantry`, `security`. Edge `B–C` predicated `latch_0 AND power IS gantry` | Assembling the bridge sets `latch_0` permanently. Setting `power IS security` closes `B–C` while `latch_0` stays true. Returning `power` to `gantry` reopens it without reassembly. The model check reports `R ⊆ E` |
| U2 | `fx_status_sets_latch` | `CONDUCTION_ROUTE` in `B`: an emitter, a receiver, a `4.0 m` gap, one steel crate carrying the `conductive`-susceptible `metallic` trait (Design 5 §15.6), and an in-room `status_source` per §23.5 check 25. `STATUS_SENSOR` for `conductive` on the crate drives a `LATCH` node listed in `latch_conditions` and in `vector_latches` | Applying `conductive` to the crate and positioning it closes the circuit and sets the latch. The Status expires `10.0 s` later (Design 5 §15.2's duration, not `8.0 s`); **the latch remains true**. The state vector contains the latch and never the Status |
| U3 | `fx_verb_suppresses_latch` | Fixture U2's room, plus a `CUT` signal verb available to the player, targeted at the latched node | While `CUT` is active the node reads `OFF` and the door closes. When `CUT` expires the node reads `ON` on the **next tick** and the door reopens. The latch is never cleared. Evaluation order per §19.3 is observable in the tick log |
| U4 | `fx_power_loss_gantry` | Room `B` holds a `WINCH` on a `ROPE` suspending a `CART` (`180 kg`), a `BRAKE` on a `SEESAW`, and a `DRIVER` on a drawbridge hinge paired with a second `BRAKE`. Control terminal in `D` can `POWER_OFF` room `B` | With the player standing on the cart, `POWER_OFF` is **deferred**, the terminal reports `waiting — someone is on the gantry`, and the persistent notice renders. On the player stepping off, power drops: the winch holds its length, both brakes engage, the drawbridge hinge locks at its current value. **Nothing moves.** |
| U5 | `fx_vector_ceiling` | Three macro variables of four states, two local keys, four vector latches — the §4.10 worked allocation, exactly `4,096` | Structural check 12 passes at the boundary. The model check reports `R` and `E` sizes and all eight property outcomes. Adding a fifth latch fails check 16 at composition, not at runtime |
| U6 | `fx_status_budget_refusal` | One room, `24` non-sleeping bodies each carrying two Statuses = `48` entries, **no reservations**. The player applies further Statuses one at a time, to already-carrying bodies so the `24`-body cap never binds | Applications `49` through `60` **all apply**, taking the room to exactly the `60`-entry cap. Application `61` is **refused** with §34's Status rejection feedback and its cost is not spent. A `25`th body is refused separately by the body cap. Both refusals render the same message |
| U9 | `fx_reserved_status_latch` | Fixture U2's `CONDUCTION_ROUTE`, whose package reserves `1` body and `2` entries (§35.2.1). The room is then filled to its **unreserved** ceiling: `23` bodies and `58` entries of ambient Status | Every further ordinary application is refused. The mandatory `conductive` application onto the reserved crate **succeeds**, sets the latch, and the Zone remains completable. Reserved capacity was never available to be consumed |
| U10 | `fx_stranded_required_object` | Four-room Zone. `POWER_CELL` home in `A`, socket in `D`. Edge `A–B` predicated `gantry IS extended`; the only setter for `gantry` is in `C`, reachable only after passing `A–B` | **Must fail composition** by §30.6 property 4 as strengthened in §30.6.1. Design 3's original wording passes it, because room `A` is reachable in the initial configuration — which is exactly the weakness §30.6.1 repairs |
| U11 | `fx_replay_macro_invariance` | A `WINCH_HAUL` package in room `B` whose latch is a vector latch, with a `POWER_OFF` effect on `B` reachable from a control room | **Must fail composition** by §23.5 check 22a. The same package with the `POWER_OFF` effect targeting room `D` instead **passes**, and its single replay verdict is committed to the manifest |
| U12 | `fx_tick_independence` | Fixture U6's room, replayed against one recorded fixed-simulation-tick sequence at `30`, `60`, `120`, and uncapped render rates | Status state is byte-identical at every simulation-tick boundary across all four runs. Every Status evaluates exactly once per `60` ticks. Render rate changes no gameplay value |
| U13 | `fx_authored_shell_path` | A composed Zone whose room `B` binds `shell_id = shell_yard_gantry`, committed to the manifest, loaded and played | The played room **is** `shell_yard_gantry`. `shell_id` is non-null in the record, the client instantiates exactly it, `SHELL_FOR_TYPE` is never consulted, and the audit reports the authored id |
| U14 | `fx_shell_refusal_matrix` | Four requests against one room: an id outside `offered_shells`; no id at all; a malformed response; a `review: pending` id | Each produces exactly the §30.11.5 outcome for its row — one repair attempt then the deterministic offline selector for the first three, and rejection at §30.5 check 19 for the fourth. **No request produces a `*_proc` shell** |
| U16 | `fx_guaranteed_and_rolled_source` | One room holding a `STATUS_GATE` whose manifest declares `FLAME_JET` → `burning` → crate `C1` as its solution, plus a second identical `FLAME_JET` and a `burnable` crate `C2` that no package declares | Applying the declared jet to `C1` ignites it on **every** attempt, `100/100` trials. Applying either jet to `C2`, or the undeclared jet to `C1`, ignites at `0.50` ± sampling error. The same hazard is deterministic for the puzzle and probabilistic everywhere else |
| U17 | `fx_weakest_qualifying_provider` | Every mandatory manipulation fixture in §37.1 and §37.3, replayed by a synthetic provider at exactly `700 N` / `20.0 m` / `120 kg` | Every one latches within `MAX_REPLAY_DURATION`. A provider at `699 N` fails §29.4's entry check for the Zone rather than entering and failing the puzzle |
| U18 | `fx_degree_four_connectors` | A junction room with four incident edges — two bidirectional, one inbound one-way drop, one outbound rail mouth — offered a shell with five declared sockets | All four edges receive distinct compatible sockets, the assignment is the lexicographically smallest legal one, and both endpoints of each edge agree on the transform. A shell with three sockets is never offered for this room |
| U19 | `fx_purpose_coverage` | Compose Zones over all `5 × 14` (room count, offset) pairs | Every purpose in the fourteen-entry rotation occurs in at least one Zone. `boss_arena` occurs in `49/70` and never more than once per Zone, always as the exit room. At least two `control_room` in every Zone |
| U15 | `fx_manifest_reconstruction` | A committed Zone manifest, saved, reloaded, and replayed twice, with Epsilon made unavailable for both reloads | Both reconstructions are byte-identical to the original and to each other. Epsilon is never queried. `manifest_digest` verifies. Replay verdicts are read from the manifest and never recomputed |
| U7 | `fx_composed_physics_ability` | Epsilon composes an Ability with the atom `effect_physics_master` (`62`) — not `eff_manipulate`, which is not an atom id in this document — carrying discriminator `physics_verb = PUSH` per §11.7, at tier `HIGH`, with two trigger clauses | The composition resolves in band `[165, 180]` with the `38`-point trigger allowance counted separately. It is one of the `9` in-band `HIGH` physics bases (§12.7). The resulting Ability grants `capability:core:manipulate` and resolves at or above §29.3's floor. The composition line reads in player language per §33.7 |
| U8 | `fx_hud_density` | One room at both Status caps simultaneously — `24` Status-carrying bodies (the §35.1 target cap) **plus** `16` Status-carrying surfaces (the separate surface cap), which are two budgets and not one `40`-target budget — with an active encounter, a constraint at `95%` stress, and an off-screen deferred `POWER_OFF` | The nearest `12` targets render full markers with sentences; the rest render single glyphs; the sort is stable across frames. The persistent tier is never overlapped. The `95%` constraint renders at screen edge. Holding `Tab` suspends the proximate tier entirely |

Every fixture ships an expected-state assertion file. U1, U2, U4, U5, U10, and U11 additionally ship their **recorded model-check result** — the sizes of `R` and `E` and all eight property outcomes — so a verifier regression is caught by a diff rather than by a playthrough. U13 through U15 ship their **committed Zone manifest and its digest**, which is what makes a reconstruction regression a diff rather than a playthrough.

## 37.4 The adversarial fixture set

Eleven Zones that **must fail** verification. A verifier that passes any of these is broken. Five are Design 3's; six are the union's own, and each of the six targets a failure mode that only exists because two proposals were merged.

| # | Fixture | The trap | Fails |
|---|---|---|---|
| N1 | `fx_bad_one_way_trap` | A one-way drop into a wing whose only exit is predicated on a variable set outside the wing | property 2 |
| N2 | `fx_bad_power_starve` | Routing power to the rails removes power from the only lift reaching the control room | property 2 |
| N3 | `fx_bad_orphan_state` | A variable with a state no setter can produce | check 10, property 6 |
| N4 | `fx_bad_stranded_cell` | A required cross-room carryable whose home room becomes unreachable after a legal macro change | property 4 |
| N5 | `fx_bad_rail_void` | A rail routing terminating mid-air with no dismount point | check 13 |
| **N6** | `fx_bad_status_topology` | A topology edge predicated on a `STATUS_SENSOR` — *"the door is open while the crate is `conductive`"* | **property 8**, check 29 |
| **N7** | `fx_bad_unproven_latch` | A vector latch whose package has `capability_required = manipulate` and no `reference_solution` | check 20, then check 27 |
| **N8** | `fx_bad_unsettable_latch` | A vector latch in a room reachable only through the edge that latch opens | **property 7** |
| **N9** | `fx_bad_driver_drawbridge` | A `DRIVER` holding a mandatory drawbridge up, with no `BRAKE` on the same signal, in a room a control terminal can depower | **check 28** |
| **N10** | `fx_bad_vector_overflow` | Eight four-state variables and eight latches — a product of `16,777,216` | check 12, check 16 |
| **N11** | `fx_bad_body_overflow` | Three adjacent rooms each holding `40` bodies, inert at the initial macro state and all three powered simultaneously by one reachable state | **check 14** |

N6 is the one to dwell on. It is the single most attractive mistake this design invites: Status is expressive, sensors read it, and predicating a door on `conductive` looks exactly like every other predicate. Property 8 rejects it, check 29 rejects it earlier and more cheaply, and §29.6 rejects the whole class at the capability layer. Three guards, one mistake, because if it ever gets through the search grows by roughly `11,000×` (§30.6 property 8), exceeds §35.4's `2.0 s` model-check budget, and is rejected as a timeout — which looks like a hang rather than like the design error it is.

N9 and N11 are the two failures Design 2 could not have anticipated and Design 3 could not have anticipated, respectively. Each is a system behaving correctly under the other system's routine operation, which is the exact signature of a merge defect.

---

# 38. TEST VECTORS

Every Design 1, 2, 3, 4, and 5 vector applies wherever this document pins to that proposal. A failure in any of them is a failure of a pin, not of a new system. The vectors below are the union's own: the seams, the modified sections, and the rewritten budgets. Each states an **outcome**, never a method.

## Pins

1. Every vector from Designs 1 through 5 covering a section this document pins passes unchanged. Where two proposals both cover a system, both vector sets pass.
2. Every pin in this document names a section that exists in the named proposal, and that section's text is the contract. No pin resolves to a section that does not exist.
3. Every entry in §0.5's pin/modifier table names a section of this document that does modify the pinned section, and no section modifies a pin not listed there.

## The alphabet and the item space

3a. The `effect` dimension contains exactly `17` atoms, the `payload` dimension exactly `11`, the `domain` dimension exactly `25`, and the whole catalog exactly `121`. No two atoms in any dimension resolve to the same behaviour.
3b. The shipped catalog contains no atom with id `effect:status`, `effect:physics`, or `effect:field`, and no composition emitted by Epsilon references one.
3c. An Archive item carrying one of those three ids resolves to its §11.7.1 equivalent at the same tier on load, is flagged `Legacy`, and keeps working. The id never resolves to any other atom.
3d. After ship, no atom id is removed from the catalog and no id is reissued.
3e. Exhaustive enumeration over the catalog yields `1,166` in-band `USEFUL` Ability bases and `138` in-band `HIGH` bases.
3f. At least `9` in-band `HIGH` Ability bases carry a physics effect atom, and at least `41` carry a Status effect atom.
3g. Exhaustive enumeration over the union's catalog yields `579,590` in-band `USEFUL` and `178,747,155` in-band `HIGH` Weapons, totalling `179,326,745`.
3h. Every effect family that a capability, a puzzle, or a topology predicate can depend on — physics, mass field, signal, Status — has at least one in-band `HIGH` base.

## The shell contract and the committed manifest

3m. Every `RoomRecord` in every composed Zone carries a non-null `shell_id`. A record without one fails schema validation and the Zone is never served.
3n. Every bound `shell_id` is a member of the `offered_shells` list the bridge supplied for that room, is `review: pass`, is type-compatible with the room's purpose per §30.11.3, and exposes every offer the room's packages bind to.
3o. The client instantiates the shell named by `shell_id` and no other. `SHELL_FOR_TYPE` is not consulted for any `RoomRecord`, and no authored record ever resolves to a `*_proc` shell.
3p. Each of the six conditions in §30.11.5 produces exactly the outcome that table names, and none of them produces a procedural shell for a record whose selected shell was authored.
3q. Reconstructing a Zone from its committed manifest, with Epsilon unreachable, produces a byte-identical Zone. Epsilon is not queried on load, and `manifest_digest` verifies.
3r. Replay verdicts are read from the manifest at load and never recomputed on the client. A package whose physical-configuration digest differs from its committed verdict's is rejected, not re-certified.
3s. Removing the authored shell from a played Zone's manifest, or restoring a silent `SHELL_FOR_TYPE` fallback in the client, causes fixture U13 to fail.

## The manipulation floor

3i. `capability:core:manipulate` is *present* on exactly those compositions whose `physics_verb` is `PUSH`, `PULL`, or `HOLD`. Presence is a Boolean and reads no magnitude.
3j. A host *qualifies* as a mandatory-route provider only when its resolved force, range, and mass limit are at least `700 N`, `20.0 m`, and `120 kg`. `qualifies_manipulate` is stamped at §17.4 validation and recomputed against the committed Loadout at entry.
3k. The state vector contains no force, range, mass, damage, or duration value, and no edge predicate or latch condition compares one. §30.6 searches over Booleans only.
3l. Every mandatory manipulation package's reference solution latches when replayed by a synthetic provider at exactly `700 N` / `20.0 m` / `120 kg`. A package that latches only above the envelope is rejected at composition.
3l1. A player whose only manipulation host resolves below the envelope fails §29.4's entry check with the §34.4 message, and is never admitted to a Zone whose mandatory route requires the capability.
3l2. A sub-envelope manipulation host remains usable on optional routes, composable, and Forgeable.

## The one cut

4. `exposed` sets its target's Defense to `0.0` for `6.0 s` and changes no other value on the target.
5. Applying `exposed` to an actor and then striking it produces the same crit chance as striking it without `exposed`.
6. No Status in the thirteen-Status catalog deals or schedules Health damage, and none modifies raw damage, crit chance, or a crit multiplier on an actor.
6a. `exposed` is the only Status that changes an actor's Defense stat, and it appears on no object.

## The state vector

7. A composed Zone's state vector contains exactly its macro variables, local keys, encounter-clear flags, one-way shortcut flags, room-visited flags, and vector latches, and no other component.
8. Capabilities do not appear as a state-vector dimension in any composed Zone.
9. Statuses and compounds do not appear as a state-vector dimension in any composed Zone.
10. A Zone with three four-state macro variables, two local keys, and four vector latches composes successfully with a state-vector product of `4,096`.
11. The same Zone with a fifth vector latch is rejected at composition by structural check 16.
12. A vector latch's value is `true` after the player satisfies its condition, remains `true` after a package reset, remains `true` after player death, and remains `true` after save and reload.

## Signal evaluation order

13. A latched node reports `ON` on the tick after its condition is satisfied and on every tick thereafter, including ticks on which the underlying sensor reports `OFF`.
14. A `CUT` signal verb applied to a latched node makes it report `OFF` for the verb's duration.
15. On the first tick after that `CUT` expires, the node reports `ON` again with no player action.
16. A `BRIDGE` signal verb that would create a cycle is rejected at activation, its cost is not spent, and the §34.11 feedback names the reason.
17. A room's signal graph never writes a macro variable. A composed Zone in which any node output reaches a macro variable is rejected at composition.

## Sensors

18. A `PRESSURE_PLATE` requiring `HEAVY` is not satisfied by any number of `LIGHT` objects.
19. A `WEIGHT_THRESHOLD` of `300 kg` is satisfied by two `160 kg` objects.
20. A `WEIGHT_THRESHOLD` on a mandatory route is satisfied by exactly one authored object present in its room.
21. A `PRESSURE_PLATE` and a `WEIGHT_THRESHOLD` in the same room are visually distinguishable without reading text, by glyph and by fill style respectively.
22. A `STATUS_SENSOR` output that reaches a mandatory-route actuator does so only through a node named in its package's `latch_conditions`.
23. A composed Zone containing a topology edge whose predicate references a Status sensor is rejected at composition.

## Actuators and power

24. On power loss a `DOOR` closes under its interlock, a `LIFT` holds position, a `WINCH` holds its length, a `BRAKE` engages, and a `DRIVER`'s hinge locks at its current value.
25. No power state change puts a previously stationary simulated body into motion.
26. A `POWER_OFF` macro effect on a room where the player stands on a body supported only by a `WINCH` does not apply while the player remains there.
27. That deferred `POWER_OFF` applies within one tick of the player leaving the supporting body.
28. While deferred, the originating control point displays `waiting — someone is on the gantry` and that notice renders in the persistent HUD tier.
29. A `HAZARD_ON` macro effect does not activate a hazard while the player stands inside its volume.
30. A `RAIL_ROUTE` macro effect issued from another room does not change a junction while an actor is within `10.0 m` of it, and applies once the rail clears.

## Puzzle validation

31. A composed Zone contains no package whose `vector_latches` names a `latch_condition` with `latches = false`.
32. A composed Zone contains no package whose `vector_latches` is non-empty and whose `capability_required` is outside the Zone's minimum proven set.
33. Every package with `capability_required = manipulate` on a mandatory route has a `reference_solution` whose three replays all latch every `latch_condition`.
34. A package whose reference solution latches on two of three replays is rejected, and its room is retried.
35. A composed Zone contains no `DRIVER` on a mandatory route whose free hinge can make the route impassable, unless a `BRAKE` on the same hinge shares its signal.
35a. A composed Zone contains at most `12` packages requiring a §23.5 check 20 replay. A composition that would select a thirteenth places a non-physics package instead.
35b. For every set of three mutually adjacent rooms in a composed Zone and every reachable macro state, simultaneously active rigid bodies number at most `90` and active constraints at most `20`.
36. A package with a non-null `status_required` has a `status_source` in the same room reachable using base movement and the permanent baseline alone.
37. A package reset restores objects, constraints, nodes, and Statuses to their authored state, and does not clear any latch, Check, shortcut, or macro variable.

## The model check

38. A composed Zone satisfies all eight properties of §30.6 before it is served to the client.
39. A Zone in which a reachable configuration cannot reach the exit is rejected, and the failure log names one witness configuration with its full variable assignment, latch assignment, and room.
40. A Zone containing a vector latch settable from no reachable configuration is rejected by property 7.
41. A Zone in which Status reaches a mandatory route other than through a latch is rejected by property 8.
42. The Latch transition is legal only from a configuration where the package's room is reachable, its `macro_predicate` is true, and its capability is in the proven set.
43. The Latch transition is forward-only. No sequence of legal transitions returns a latch to `false`.
44. A Zone verified against the minimum required capability set is not re-verified when the player enters with a larger set.
45. Adding `capability:core:manipulate` to a Zone's required set changes the number of configurations searched by zero.
46. The forward and reverse searches together traverse at most `5.9M` edges for a Zone at the `4096 × 12` bound.
47. Each of the eleven adversarial fixtures N1 through N11 is rejected at composition, by the property or check named in §37.4.

## Enemies

48. No enemy attack applies a Status to the player.
49. An authored hazard, a `SELF_STATUS` Ability, and a `STATUS_TRANSFER` may each apply a Status to the player.
50. An enemy launched into the air while `burning` continues to burn for the remainder of the Status duration.
51. No enemy moves any physical object at any time.
52. A `suspended` enemy does not count toward an encounter's clear condition.
53. Arming an encounter the player is standing in spawns its first wave after `2.0 s` with an audible cue.

## Presentation

54. Every element in §33.10's persistent tier is drawn without occlusion in a room containing an active encounter, `40` Status-carrying targets, and a constraint at `95%` stress.
55. With more than `12` Status-carrying targets in range, the nearest `12` render full markers and the remainder render single glyphs.
56. That ordering is identical across consecutive frames when nothing has moved.
57. Holding the Zone Diagram input suspends every proximate-tier element for its duration.
58. A constraint at `95%` of `breakable_at` renders at the screen edge when its object is off-screen.
59. Refusing a manipulation on an optional route produces a message naming the requirement and never naming an item to equip.

## Performance

60. A room at every §35.1 budget simultaneously holds its frame within `16.67 ms` on target hardware.
61. Applying a Status that would exceed `60` `ActiveStatus` entries in a room is refused with feedback, and the cost is not spent.
62. Applying a Status to a sleeping body wakes it when under the `24` non-sleeping cap, and is refused when not.
63. With `n` `ActiveStatus` entries in a room, no single simulation tick evaluates more than `ceil(n / 60)` of them. At the `60`-entry cap, no tick evaluates more than one.
64. Each Status evaluates exactly once per second of game time, and duration countdown renders per frame.
64a. A fixture replayed at `30`, `60`, `120`, and uncapped render rates over the same fixed simulation-tick sequence produces byte-identical Status state at every tick boundary. Render rate changes no gameplay value.
65. Zone composition including Epsilon selection and all retries completes within `88.0 s`.
65d. A single composition attempt's **deterministic compute** completes within `13.6 s`, of which serial physics replay accounts for at most `10.8 s`. This figure excludes model latency and is the only one a bridge can hold itself to.
65e. A first attempt's **total** elapsed time is `13.6 s` plus Epsilon's actual latency, bounded at `33.6 s` when both requests time out.
65a. `36` replays of `12.0 s` each, at the contracted `40×` minimum throughput, complete in `10.8 s` or less on the canonical environment.
65b. No package declares `ReferenceSolution.max_duration` above `12.0 s`; §23.5 check 31 rejects one that does.
65c. Shell selection issues exactly one batched Epsilon request per Zone, at most one repair attempt, and no request at all on a retry attempt.

## Coverage of the union itself

66. §36.1's system map contains exactly `66` rows — every unordered pair of §31.3's twelve systems, each exactly once — and each row is classified either INTERACTS with a section reference that exists in this document, or ORTHOGONAL with a reason. No row is unclassified and no pair is missing.
67. Counting §36.1's rows yields exactly `51` INTERACTS and `15` ORTHOGONAL. §31.3's stated totals equal those counts.
68. Every one of the thirty-four families in §24 has a reference fixture in §37.
69. Every one of the eighteen sensor types in §20 and twelve actuator kinds in §21 appears in at least one fixture.
70. All thirteen Statuses, all eight compounds, all twelve manipulation verbs, all eight constraint kinds, and all five signal verbs appear in at least one fixture.

## Gaps closed by the §39 traceability pass

71. A `DOOR` losing power closes rather than holding, satisfying Dungeon Authority test D14 under every macro state including `POWER_OFF` issued remotely.
72. No composed Zone permits an accidental progression cycle, satisfying Dungeon Authority test D64 over macro state, keys, flags, shortcuts, visits, and latches simultaneously.
73. No Status directly or indirectly schedules periodic Health damage, satisfying Player Authority test P41 across the thirteen-Status catalog and all eight compounds.
74. Physics is never the dominant damage source, never the main movement method, and never telekinesis, satisfying Player Authority tests P30, P31, and P32 at the union's numbers rather than Design 2's alone.

---
# 39. TRACEABILITY

All 142 acceptance tests named by the two source authorities. Notation: `A V n` is a vector in §38 of this document; `Dm V n` is vector `n` of Design `m`, reached through a pin. A row citing only `Dm V n` is closed by that proposal's machinery, taken unchanged.

## 39.1 Player Design Authority §35

| # | Acceptance test | Covered by |
|---|---|---|
| P1 | Empty build can move, jump, interact, melee, and defeat a basic mandatory enemy with Static Pulse. | D2 V 2 |
| P2 | Static Pulse cannot be removed from the Weapon cycle. | D1 V 2 |
| P3 | Out-of-bounds recovery returns to valid state. | D1 V 3 |
| P4 | No foreign receipt is required for the player to remain basically playable. | D4 V 26 |
| P5 | Q/E/1/2/3 activate five distinct Ability slots directly. | D1 V 12 |
| P6 | Shift activates Mobility and never ordinary sprint. | D1 V 13 |
| P7 | F never activates a generated combat Echo. | D1 V 14 |
| P8 | MMB always reaches baseline melee unless rebound. | D1 V 15 |
| P9 | R dispatches only the selected Weapon’s feed action. | D1 V 16 |
| P10 | Player-facing bindings are rebindable without changing semantic slot roles. | D1 V 17, 18 |
| P11 | Static + three Weapon Echoes produce four valid cycle states. | D1 V 19 |
| P12 | Empty slots are skipped. | D1 V 20 |
| P13 | Switching away from a partial magazine does not refill it. | D1 V 21 |
| P14 | Switching away from Heat does not clear it. | D1 V 22 |
| P15 | Switching does not activate inactive Weapon passives. | D1 V 25 |
| P16 | A selected Weapon remains useful without another Weapon acting as mandatory primer. | D1 V 27 |
| P17 | Resource Ability cannot overspend its pool. | D1 V 35 |
| P18 | Multi-charge Cooldown recharges predictably and serially. | D1 V 36 |
| P19 | Action recharge advances only on declared facts/metrics. | D4 V 46 |
| P20 | Failed preflight spends nothing. | D2 V 85 |
| P21 | Post-commit miss receives no implicit refund. | D1 V 39 |
| P22 | Recharge modifiers cannot create an unbounded self-feed loop. | D4 V 17 |
| P23 | Resource/Cooldown/Action are visibly distinguishable in HUD. | D4 V 47 |
| P24 | F activates a normal mechanism. | D1 V 82 |
| P25 | F activates an AP Check while preserving AP transaction semantics. | D1 V 48 |
| P26 | F picks up and drops/places carryables. | D1 V 83, 84 |
| P27 | Required carryable lost out of bounds recovers. | D1 V 49 |
| P28 | Carrying produces unambiguous context prompt. | D2 V 83 |
| P29 | Hacking begins through F and resolves as a room-signal input rather than bespoke door logic. | D1 V 88 |
| P30 | Eligible object can be manipulated. | **A V 74**; D2 V 5 |
| P31 | Ineligible progression object cannot be manipulated merely because it is physically light. | **A V 74**; D2 V 27 |
| P32 | Physics cannot self-launch the player into universal traversal. | **A V 74**; D2 V 21 |
| P33 | Player-owned impact has a hard damage ceiling. | D2 V 53 |
| P34 | Resting/jittering props cannot repeatedly damage. | D2 V 57 |
| P35 | Optional clever sequence breaks remain possible where no semantic gate forbids them. | D2 V 87 |
| P36 | No normal gameplay path writes Health outside the damage resolver. | D1 V 58 |
| P37 | Same ordinary non-crit attack under same state gives same damage. | D4 V 9 |
| P38 | 100% crit guarantees Tier I. | D1 V 60 |
| P39 | 150% crit never produces an ordinary hit. | D1 V 61 |
| P40 | Overcrit tiers scale linearly rather than exponentially. | D1 V 63 |
| P41 | Status cannot directly or indirectly schedule periodic Health damage. | **A V 6, 73**; D5 V 18, 21 |
| P42 | Failed chance-based Status attempt visibly increases bounded susceptibility. | D5 V 8 |
| P43 | Successful Status application increases temporary adaptation. | D5 V 8 |
| P44 | Strong enemies can resist more without every effect becoming blanket `IMMUNE`. | D5 V 53 |
| P45 | World fire may damage independently from `BURNING`. | D5 V 19 |
| P46 | Unequipped Archive hosts produce zero live listeners/reactions/resources. | D1 V 73 |
| P47 | Full loadout cannot be swapped during ordinary active combat. | D1 V 74 |
| P48 | Weapon cycling is not a full loadout swap. | D1 V 138 |
| P49 | Re-equipping an old host restores legal saved state instead of refilling it. | D1 V 75 |
| P50 | Newly introduced host cannot manufacture free readiness in an already-active Zone. | D1 V 76 |
| P51 | Mod insertion/removal at the Hub has no respec fee. | D4 V 33 |
| P52 | Only one high-tier Gear piece may be equipped across Head/Torso/Arms/Legs. | D1 V 78 |
| P53 | Hard capability gate cannot appear before guarantee. | **A V 44, 45**; D2 V 68 |
| P54 | Epsilon cannot invent a hard requirement. | D4 V 21 |
| P55 | GRAPPLE-required Zone verifies a usable expression is equipped before entry or supplies it before the requirement. | D1 V 96 |
| P56 | Raw DPS threshold cannot become AP reachability logic. | D1 V 95 |
| P57 | Physics/recoil may bypass optional geometry without automatically invalidating the Zone. | D2 V 87 |
| P58 | Weapon-cycle transition visibly identifies the newly selected configuration. | D1 V 97 |
| P59 | Static Pulse has recognizable neutral/home presentation. | D1 V 98 |
| P60 | Viewmodel animation/VFX cannot decide simulation outcome. | D1 V 99 |
| P61 | Physics ownership/target/relation state is visually readable. | **A V 54**; D2 V 81 |
| P62 | A configuration with no RMB or feed mechanic does not invent meaningless filler UI. | D1 V 100 |

## 39.2 Dungeon & Environmental Gameplay Authority §71

| # | Acceptance test | Covered by |
|---|---|---|
| D1 | F operates the intended focused object when several interactables are nearby. | D1 V 45 |
| D2 | Carryable pickup/drop is predictable. | D1 V 83 |
| D3 | Placing an object in a compatible socket succeeds. | D1 V 84 |
| D4 | An incompatible object is rejected visibly. | D1 V 85 |
| D5 | The player knows what F will do in an ambiguous context. | D2 V 83 |
| D6 | A plate visibly communicates its output relationship. | D1 V 101 |
| D7 | A conduit state is understandable without relying only on color. | **A V 54**; D3 V 53 |
| D8 | AND requires both inputs. | fx 8 |
| D9 | OR accepts either input. | D2 V 89 |
| D10 | Timed state visibly communicates remaining urgency. | D1 V 103 |
| D11 | Latch persists according to package semantics. | D1 V 108 |
| D12 | Signal reset restores initial state. | D1 V 109 |
| D13 | A powered door opens. | fx 1 |
| D14 | Removing power closes safely. | **A V 24, 71**; D1 V 110 |
| D15 | A player in the doorway is not silently crushed by a non-hazard door. | D1 V 110 |
| D16 | A persistent shortcut remains unlocked after room revisit. | **A V 12**; D3 V 16 |
| D17 | A topology transformation never removes every valid progression route unintentionally. | **A V 38, 39**; D3 V 19, 22 |
| D18 | Required carryable cannot be permanently lost. | D1 V 49 |
| D19 | Dropping it out of bounds restores it. | D1 V 49 |
| D20 | Destroying a replaceable required object restores it. | D1 V 86 |
| D21 | Save/load reconstructs its semantic state. | **A V 12**; D2 V 47 |
| D22 | A weighted plate cannot be cheesed by meaningless tiny debris unless authored. | **A V 18-21**; D2 V 71 |
| D23 | Required timed path is physically feasible. | D1 V 112 |
| D24 | Timing includes reasonable player variance. | D1 V 112 |
| D25 | Failure permits immediate retry. | D1 V 113 |
| D26 | Countdown is readable. | D1 V 103 |
| D27 | Mandatory shootable target works with guaranteed baseline weapon capability. | D1 V 114 |
| D28 | Invalid hits do not trigger it. | D1 V 115 |
| D29 | Target state is readable at distance. | D1 V 104 |
| D30 | Hack can enable an output. | fx 7 |
| D31 | Hack can redirect a connection in a package designed for routing. | fx 7 |
| D32 | Hack failure does not corrupt puzzle state. | D1 V 89 |
| D33 | Hack interaction can be exited/reset safely. | D1 V 89 |
| D34 | Powered rail state is readable. | D1 V 105 |
| D35 | Rail branch switch selects a physically valid route. | **A V 30**; D3 V 17, 18 |
| D36 | LaunchPad source/landing remains valid. | D1 V 116 |
| D37 | Grapple target exists within an audited grapple opportunity. | D1 V 117 |
| D38 | Moving platform does not strand required progression. | D1 V 111 |
| D39 | Hazard damage uses common damage road. | D1 V 119 |
| D40 | Hazard telegraphs before unavoidable contact where appropriate. | **A V 29**; D1 V 140 |
| D41 | Hazard can affect enemies if package says it can. | D1 V 120 |
| D42 | Hazard controller correctly disables/enables it. | D1 V 121 |
| D43 | Reset restores hazard phase safely. | D1 V 141 |
| D44 | Reactive barrel damages valid actors. | D2 V 93 |
| D45 | Bombable wall responds to tagged explosive. | D2 V 93 |
| D46 | Ordinary architecture does not become arbitrarily destructible. | D1 V 122 |
| D47 | Destructible required support has recovery or alternate progression. | D1 V 123 |
| D48 | Energy ball reaches receiver on validated route. | Deferred — §2.2 |
| D49 | Lost ball resets. | Deferred — §2.2 |
| D50 | Reflector changes valid path. | Deferred — §2.2 |
| D51 | Beam receiver responds continuously. | Deferred — §2.2 |
| D52 | Moving blocker changes beam state correctly. | Deferred — §2.2 |
| D53 | Player can enter, swim, surface, and exit. | Deferred — §2.2 |
| D54 | Oxygen state is readable. | Deferred — §2.2 |
| D55 | Required buoyant object behaves consistently. | Deferred — §2.2 |
| D56 | Drain/fill state restores correctly after save/load when persistent. | Deferred — §2.2 |
| D57 | Enemy can be killed by an environmental hazard. | D1 V 124 |
| D58 | Movable cover changes line of sight. | D1 V 125 |
| D59 | Enemy cannot permanently softlock a required plate. | D1 V 118 |
| D60 | Encounter-clear gate opens from authored encounter completion. | fx 13 |
| D61 | Generator state propagates to dependent room. | **A V 26, 27**; D3 V 3 |
| D62 | Cross-room state survives unload/reload. | **A V 12**; D3 V 7 |
| D63 | Dependency chain remains reachable. | **A V 38, 40**; D3 V 22, 27 |
| D64 | Dungeon macro-state cannot create an accidental progression cycle. | **A V 38, 39, 72**; D3 V 19, 20, 22 |
| D65 | Puzzle reset affects only its declared reset group. | D1 V 129 |
| D66 | Completed AP Check is not undone by puzzle reset. | D1 V 130 |
| D67 | Persistent shortcut is not undone by local reset. | **A V 12, 37**; D3 V 16 |
| D68 | Temporary projectiles and signals are cleared. | D1 V 131 |
| D69 | Critical active/inactive state is distinguishable without color alone. | **A V 54, 58**; D3 V 54 |
| D70 | Required sound cue has visual equivalent. | D1 V 106 |
| D71 | A distant controlled output can be inferred from input. | **A V 57**; D3 V 39, 53 |
| D72 | Wrong-sequence failure communicates the error. | D1 V 107 |
| D73 | Same seed/package produces same initial composition. | D3 V 25 |
| D74 | Decorative randomness does not alter solvability. | D1 V 81 |
| D75 | Package audit produces stable results. | **A V 33, 34**; D2 V 70 |
| D76 | Inactive physics objects sleep. | **A V 62**; D2 V 78 |
| D77 | Large room does not keep unlimited projectiles alive. | D1 V 134 |
| D78 | Beam routing has bounded complexity. | D1 V 135 |
| D79 | Signal update is event-driven where practical. | D1 V 136 |
| D80 | Debug view can identify active semantic state without inspecting scene internals manually. | **A V 66**; D2 V 95 |

## 39.3 Coverage

| | Count |
|---|---:|
| Authority acceptance tests | `142` |
| Not applicable — system deferred by §2.2 | `9` |
| **Applicable** | **`133`** |
| Closed by an Amalgam vector, alongside its pinned source | `24` |
| Closed through a pin alone | `109` |
| **Uncovered** | **`0`** |

The `109` pinned rows, by which proposal's machinery closes them:

| Source | Rows |
|---|---:|
| Design 1 | `81` |
| Design 2 | `11` |
| Design 4 | `7` |
| Design 5 | `4` |
| Design 3 | `1` |
| A reference fixture rather than a vector | `5` |
| **Total** | **`109`** |

Two observations that are the point of this section rather than bookkeeping.

**Design 3 shows one pinned row and that is not a mistake.** Almost every test Design 3 closed with its own machinery — D7, D16, D17, D35, D61, D62, D63, D64, D67, D69, D71 — appears above with an Amalgam vector *in addition to* its Design 3 citation, because the union modified the mechanism that closes it. That is the traceability record of §0.3's finding: Design 3's model check is the piece everything else merges around, so almost nothing it touches survives untouched.

**The `24` union vectors are not spread evenly.** They cluster on exactly the tests where two proposals' systems meet:

| Test | Why the union needed its own vector |
|---|---|
| **D14** — removing power closes safely | Design 1's per-kind table did not cover `WINCH`, `BRAKE`, or `DRIVER`, and Design 3's `POWER_OFF` made power loss routine. §21.1.1 and §21.11 |
| **D64** — macro-state cannot create an accidental progression cycle | The state vector now spans macro state *and* physics latches. §30.6 property 2 |
| **D63** — dependency chain remains reachable | Property 7 added, because a latch nothing can set is a new way to break a chain |
| **P41** — Status cannot schedule periodic Health damage | Design 5's invariant plus §0.4's removal of `exposed`'s crit clause |
| **P30–P32** — physics is not telekinesis, movement, or dominant damage | §31.2's arithmetic re-checked against thirteen Statuses rather than four |
| **D22** — a weighted plate cannot be cheesed by debris | Three mass-reading sensors now coexist, and only one accumulates. §20.6 |
| **D69, D7** — critical state distinguishable without colour | Five proposals' HUD requirements on one screen. §33.10 |

D14 is worth naming twice. It was found in Design 1 only by running the traceability matrix, after five internal audit passes had missed it, and the union broke it again in a new way — three actuator kinds Design 1's table never listed, under a power-loss event Design 1 never made routine. The same row caught it the second time.

---

# 40. IMPLEMENTATION WAVES

## 40.0 This section does not govern Playable 0.3

**Two sequences exist and they must not be merged.** The repository has a live product milestone with a frozen critical path; this document describes the eventual complete game. Confusing them would let a design proposal reorder work an owner has already sequenced.

| | Governs | Owned by |
|---|---|---|
| **A. Playable 0.3** | What the project builds **now** | `docs/ROAD_TO_PLAYABLE_0_3.md` and the 2026-09-04 owner rulings. **Not this document** |
| **B. The Amalgam waves** | Completing this architecture, after and around A | §40.2 below |

## 40.1 What Playable 0.3 is, and what this document must not do to it

Recorded here so the boundary is legible, **not** to restate the roadmap as design authority:

- **3A** may use a curated authored Zone strictly as temporary test scaffolding, to prove rail and launch construction against the current player.
- **3B** follows immediately and puts authored `shell_id` values through the real Epsilon → played-Zone path.
- **No unrelated milestone comes between 3A and 3B.**
- Wave 2 shells, Theme Packs, Integrity Faults, the 20–30-room proof library, and full buildcraft migration are **off** the 0.3 critical path.
- Movement offers stay strictly optional in 0.3. Mandatory routes and Checks must remain completable with no offer geometry.
- Environmental-agency signal persistence is an unresolved owner gate and is not decided by this document.

**This document contributes exactly one thing to that path: §30.11's contract**, which is the specification 3B needs and which nothing in the repository currently states. Every other section of this document is wave B work. **§40.2 must not be read as authorising anything before 3B ships.**

The one dependency worth naming in the other direction: **§30.11 is written so 3B can implement it without any other part of this document.** It needs a required `shell_id`, a filtered offered catalog, type compatibility, the failure table, and a committed manifest. It does not need latches, macro state, physics, or the model check.

## 40.2 The Amalgam waves

Thirty-five waves. The ordering constraint is that **the verifier exists before the systems it verifies**, which inverts the instinct to build the fun parts first.

| Wave | Contents | Gate |
|---:|---|---|
| 1 | Common types, Ids, `HostDefinition`, save envelope | Schemas round-trip |
| 2 | Base player, movement law, out-of-bounds recovery | D1 V 1–11 |
| 3 | Input, slots, rebinding | D1 V 12–20 |
| 4 | Damage resolver, Defense, Barrier, overcrit, death | D1 V 55–70 |
| 5 | Interaction resolver, carryables, sockets | D1 V 45–54 |
| 6 | Signal graph: ports, eleven node types, topological evaluation | D1 V 100–115 |
| 7 | Sensors 1–9, actuators 1–9, the per-kind power-loss table | A V 24; D1 V 116–130 |
| 8 | Puzzle-package contract, checks 1–18, reset | D1 V 131–141 |
| 9 | **`shell_id`, the offered catalog, and the committed manifest (§30.11)** | **A V 3m–3q; fixtures U13, U14, U15.** This is 3B's specification and it ships first |
| 10 | **The state vector and the model check, properties 1–6** | Fixtures N1–N5 rejected |
| 11 | Macro variables, predicated topology, the machine graph | D3 V 1–20 |
| 12 | Sensors 13–15, macro effects, control rooms, `CERTIFIED_FALLBACK` resolution at step 5 | D3 V 21–40 |
| 13 | The Zone Diagram, read-only, per-variable discovery | A V 57; D3 V 41–55 |
| 14 | **Composition steps 1–14 and 16–20** — topology, purposes, shell binding, the vector freeze, latch allocation, macro effects, **package placement (step 11)**, Checks, encounters, provisional checkpoints, structural checks, and the manifest commit. RNG primitives and `PACKAGE_DENSITY` | A V 38–47; §30.3.1, §30.3.2 |
| 15 | **Property 4 as strengthened (§30.6.1)** | A V 40; fixture U10 rejected |
| 16 | **Checkpoints over reachable configurations (§30.7.1)** | Fixture U1's recorded result |
| 17 | The certified fallback Zone and `CERTIFIED_FALLBACK` | §37.2 passes with `R = E` |
| 18 | Physical object model, twelve object classes, mass classes | D2 V 1–15 |
| 19 | The twelve manipulation verbs, eligibility, §14.4's limits | D2 V 16–40 |
| 20 | Eight constraint kinds, the solver at `8` fixed iterations | D2 V 41–55 |
| 21 | `WINCH`, `BRAKE`, `DRIVER`, and their power-loss behaviour | A V 24, 25 |
| 22 | **Latching, and latches as state-vector components** | A V 12, 13 |
| 23 | **§23.5 check 20's replay, in the canonical environment, verdicts committed** | A V 33, 34, 65a; fixture N7 rejected |
| 24 | **Check 22a physical invariance (§23.5.1)** | Fixture U11 |
| 25 | **Model check property 7, the Latch transition, check 18** | A V 40, 42, 43; fixture N8 rejected |
| 26 | `capability:core:manipulate` as verb-set membership (§29.3) | A V 3i–3l, 44, 45 |
| 27 | Sensors 10–12, checks 21, 27, 28 | A V 19–21, 35; fixture N9 rejected |
| 28 | §21.11's deferral guard, its persistence, and check 21 | A V 26–28 |
| 29 | The thirteen Statuses, five target kinds, application pipeline | D5 V 1–20 |
| 30 | The eight compounds and compound telegraphing | D5 V 21–40 |
| 31 | `STATUS_TRANSFER`, `SELF_STATUS`, the transfer selector | D5 V 41–55 |
| 32 | Sensors 16–18, checks 25, 26, 29 | A V 22, 23, 36 |
| 33 | **Model check property 8** | A V 41; fixture N6 rejected |
| 34 | **Reserved Status capacity (§35.2.1), check 20, fixed-tick staggering** | A V 61–64a; fixtures U6, U9, U12 |
| 35 | The atom alphabet, trigger clauses, Forge, the named-composition fallback | D4 V 1–55; A V 3a–3h, 7 |

Four ordering rules the table encodes:

1. **Wave 9 before everything else that touches a Zone.** The `shell_id` contract is both 3B's deliverable and the thing every later Zone wave assumes. It has no dependency on the rest of this document, which is what lets it ship first.
2. **Wave 10 before wave 14.** The verifier ships before the composer that depends on it, and its five negative fixtures pass before any Zone is generated.
3. **Wave 23 before wave 25.** The physical half of the proof — check 20's replay — ships before the graph half learns to depend on it. A Latch transition whose legality references a validator that does not exist is a Latch transition that is always legal, which is the most dangerous possible bug in this document.
4. **Wave 33 before wave 34.** Property 8 ships before Status budgets, so the first Zone composed with Status sensors is already rejected if a Status reaches a topology predicate. Building the budgets first produces a working, playable, unsound game — worse than a broken one, because it looks finished.

Waves 1–17 are a complete, shippable game: Design 3 with authored shells. Step 12's physics replay is not among them and is not needed — with no physics layer built, no package requires one, and §30.5 check 17's cap is trivially satisfied at zero. Step 15 and steps 18–19's checkpoint validation land in wave 16. Waves 18–28 add Design 2. Waves 29–34 add Design 5. Wave 35 adds Design 4. **Each of those four boundaries is a legitimate stopping point**, and §41.2 says what you have at each.

---

# 41. CLOSURE STATEMENT

## 41.1 What this proposal decided

| Question the authorities left open | Decision |
|---|---|
| Is macro state forward-only or reversible? | Reversible, up to `8` variables of `2`–`4` states. Design 1's flags are the `reversible = false` special case |
| Tree or graph topology? | Graph, `1`–`4` independent cycles, predicated edges |
| Kinematic or simulated machinery? | Both. Nine kinematic kinds plus three constraint-driven, bridged by `WINCH`, `BRAKE`, `DRIVER` |
| Profiles or composition for generated items? | Composition. Every profile in Designs 1, 2, 3, and 5 re-expressed as a named atom composition |
| Does Forge ship in v1? | Yes |
| May physics gate progression? | **Yes**, through `capability:core:manipulate` plus a validated reference solution plus a vector latch. This is the one fork that needed new machinery |
| How is a Zone proven safe? | One model check, eight properties, `R ⊆ E` at its centre, run once at composition |
| How does Status participate in progression? | **Only through a latch.** Three independent guards enforce it |
| How many Statuses, and may one modify damage on an actor? | Thirteen. **None deals or schedules Health damage, and none modifies raw damage, crit chance, or a crit multiplier.** `exposed` sets an actor's Defense stat to `0.0`, which changes the resulting number and is the one declared exception (§15.3) |
| What happens on power loss? | Per actuator kind. Doors close, load-bearing machinery holds, and no simulated mass is set in motion |
| Who resolves a conflict between a latch, a sensor, and a signal verb? | §19.3's step-1 order: sensors, then latches, then verbs |
| What fits on the screen? | §33.10's three tiers, with two elements promoted for safety |
| Do the physics, signal, and Status verbs get high-tier expressions? | Yes. Four `HIGH` effect atoms at `62`, lifting in-band `HIGH` bases from `48` to `138` |
| What stops a composed manipulation Ability being too weak for a puzzle validated against a profile? | §29.3.2's envelope, applied to **provider qualification** rather than to composition legality. Any composition may grant the Boolean; only one meeting `700 N` / `20.0 m` / `120 kg` counts as a guaranteed mandatory-route provider |

## 41.2 What this proposal sacrificed

It cut one clause of one Status (§0.4). Everything else it gave up is cost, not content, and the cost is real.

**1. Composition time: `88.0 s` per Zone worst case; a first attempt is `13.6 s` of deterministic compute plus Epsilon's actual latency, bounded at `33.6 s`. Against Design 3's `20.0 s` and Design 1's low single digits.** Two costs dominate: §23.5 check 20's headless physics replay at `10.8 s` per attempt, and Epsilon's `20.0 s` worst-case shell request. If the replay proves too slow, §30.5 check 17's cap of `12` replay packages is the dial — at `6` it halves to `5.4 s`. If Epsilon's latency dominates, §30.11.6's offline selector is already the certified answer and can be made the default. Both are tuning values with stated meanings, not redesigns.

**2. Three validators stacked.** A Zone must pass the structural checks, the physics replays, *and* the model check. Each has its own failure mode and its own retry path, and a bug in any of the three produces a class of broken Zone the other two do not catch. Design 1 had one validator that could not fail because construction guaranteed the property. This has three that can.

**3. Zones are shorter.** `8`–`12` rooms against Design 3's `8`–`14`, and `20` edges against `22`. That is `2` rooms of content per Zone, given up to keep composition inside its budget.

**4. Two of Design 5's numbers came down** — `40` Status-carrying targets per room to `24`, and `90` `ActiveStatus` entries to `60` (§35.2). No mechanic was removed and the caps are above what ordinary play reaches, but they are lower than Design 5 shipped and a room built to Design 5's ceiling will refuse applications here.

**5. It is the longest document in the repository and the most expensive to build.** Thirty-five implementation waves. An owner picking this is choosing a longer road to a first playable, and §40's four stopping points exist because that choice deserves an exit at each stage:

| Stop after | You have | What is missing |
|---|---|---|
| **Wave 9** | **The `shell_id` contract alone** — authored rooms in played Zones, which is Playable 0.3's 3B | Everything else. This is the only boundary that is on the current critical path |
| Wave 17 | Design 3 complete and verified, with authored shells | Physics, thirteen Statuses, composed items, Forge |
| Wave 28 | Designs 2 and 3 merged, with mandatory physics proven safe | Status as a language, composed items, Forge |
| Wave 34 | Designs 2, 3, and 5 | Composed items and Forge; items remain profile-selected |
| Wave 35 | This document | Water (§2.2), and nothing else any proposal shipped |

**6. The single largest technical risk, named plainly — corrected.** This section originally named §23.5 check 20's solver determinism as the top risk: a headless replay whose three runs must agree, in an engine whose cross-platform determinism is assumed rather than proven.

**That was the wrong risk, and checking against the engine showed why.** There is no solver in the project to be non-deterministic — zero `RigidBody3D`, zero joints, and a physics section in `project.godot` containing one line. The real risk is one order more basic: **the entire physical layer this proposal is half-built on does not exist**, and the engine's own note says the physics capabilities *"wait on the v9 physics tool."* §40's waves 15 through 24 are ten waves of building a subsystem from nothing before any of Design 2's content appears.

Solver determinism becomes the top risk again once that subsystem exists, and the mitigation stated above — move replay validation to the bridge as a build-time artefact shipped with the Zone — still applies then. It is simply not the first thing that will go wrong.

## 41.3 Proposal-level choices the authorities did not mandate

- Thirteen Statuses in four families rather than any other count. Design 5's twelve plus `exposed`.
- Thirty-four puzzle families. The union of five sets, deduplicated.
- `8` vector latches as the ceiling, and least-loaded phase buckets rather than a hash (§35.3).
- Sensors, then latches, then signal verbs, as step 1's order (§19.3). The reverse order is defensible and produces a different game.
- `24` non-sleeping bodies as the anchor for the Status target cap (§35.2). Tying the two budgets together is a choice; leaving them independent and lower is the alternative.
- Three HUD tiers with two safety promotions (§33.10). This is the section with the least authority backing and the most room for an owner's taste.

## 41.4 Where this proposal disagrees with an authority

Nowhere. Every one of the 48 inherited laws holds (§1), and §39 traces all `133` applicable acceptance tests to a vector or a fixture with none uncovered.

The three laws closest to breaking, and what holds each, are named in §1 rather than hidden here: Law 20 by Design 2's §14.4 limits and §31.2's arithmetic, Law 27 by Design 5's structural rule and §0.4's one cut, and Law 34 by §30.6 proving `NO REQUIREMENT BEFORE GUARANTEE` over six kinds of state at once.

## 41.5 Engine status — where this document is not buildable as written

Added after [`07_ENGINE_RECONCILIATION.md`](07_ENGINE_RECONCILIATION.md) checked all six proposals against `claude/archipepsi-echoes-continuation-b1adno`. Three findings are engine-blocking and belong in the closure statement rather than in a separate document nobody reads.

| # | Finding | What it blocks |
|---|---|---|
| **1** | **No rigid-body physics exists.** Zero `RigidBody3D`, zero joints, in 140 GDScript files. The engine is static geometry, areas, and character bodies | §14 (twelve verbs), §21.10 (`WINCH`/`BRAKE`/`DRIVER`), §26 (eight constraint kinds), §23.5 check 20, and `4.0 ms` of §35.0's frame budget |
| **2** | **The engine refuses `manipulate` as a capability, by name.** `mechanics.py:269`: the physics capabilities *"are not here because nothing can satisfy them yet: they wait on the v9 physics tool, and a capability nothing can satisfy is a gate nothing opens"* | §29.1's fifth capability, and therefore §0.3's fork 6 — the one fork this document claims required new machinery |
| **3** | **§30.6 has no channel to Archipelago's solvability logic.** The apworld's complete access-rule set is three regions gated on Signal Key counts (`apworld/archipepsi/__init__.py:109`). It declares no capability prerequisite, does not know Zones exist, and defaults to `Accessibility: full` | Every capability gate in this document. The model check proves a property Archipelago never consumes, and Archipelago proves a property the model check never sees |

**Finding 3 is the one that matters most and is the least about physics.** It applies to Design 1's three capabilities on a tree topology exactly as much as to this document's five. Two independent solvability models, neither aware of the other, and the one that decides whether a seed is winnable is the one this document never touches. The reconciliation's recommendation 6 is the decision that has to be made before any proposal is promoted: either the apworld learns to declare capability prerequisites, or Zone composition may not place an allocated Check behind one.

**What survives all three.** The Epsilon architecture (§3.3, §11.7, §17) matches the engine's normative *"developers author the alphabet, Godot enforces the grammar, Epsilon writes sentences"*. The guarantee model (§30.6 property 5) matches `CapabilityGuarantee`'s four cases. And the engine left case C — `established_in_zone` — as an unimplemented parameter with the note that *"when a capability-establishment construct exists it plugs in here"*. **§30.6 is that construct.** The socket was left open; what is missing is the wiring in finding 3.

### 41.5.1 One section of this document is buildable now, and it is the one the project needs

The 2026-09-04 runtime finding — every played chamber carrying `shell_id: null`, all 23 chambers procedural, no authored room ever reaching a player — is the seam Playable 0.3's 3B exists to close, and **the repository has no written contract for it.**

**§30.11 is that contract**, and it is deliberately free of every blocker above:

| §30.11 needs | Blocked by findings 1–3? |
|---|---|
| A required, non-nullable `shell_id` on every room record | No |
| A bridge-filtered `offered_shells` list per room | No |
| Type and purpose compatibility (§30.11.3) | No |
| The six-row failure table with no silent `*_proc` path (§30.11.5) | No |
| A committed manifest with a digest, reconstructed without re-querying Epsilon (§30.11.7) | No |
| Rigid-body physics, `manipulate`, latches, macro state, the model check | **Not required by §30.11 at all** |

§40.2 wave 9 is therefore the one wave of this document that can ship against the engine as it stands today, and §40.0 records that it is the only part of this document on the live critical path. **Everything else in this proposal waits; this does not.**

## 41.6 The claim

Five proposals, one union, one clause cut.

The union works because four of its six apparent forks were superset relationships rather than contradictions, and the fifth — Forge — was purely additive. Only the sixth needed new machinery, and the machinery it needed already existed in another proposal: **Design 2's latches are monotone Booleans, which is exactly the shape Design 3's verifier already searched.** That single observation is what turns "physics may gate progression" from an unprovable claim into a state-vector component, and it is why this document exists at all.

What it buys is `66` system pairs against a best-of-inputs `36`, `34` puzzle families against `18`, thirteen Statuses, twelve manipulation verbs, eight constraint kinds, reversible macro state, `179,326,745` composable Weapons and `16,586,524` composable Abilities, and Forge — with one verifier proving, over all of it simultaneously, that no reachable configuration is a dead one.

What it costs is **`88.0 s`** of worst-case composition — **`13.6 s`** of deterministic compute on a first attempt, plus Epsilon's actual latency, bounded at **`33.6 s`** — three stacked validators, two rooms per Zone, and **`35`** waves of build.

**Every number in this section is duplicated from an authoritative section and was mechanically compared against it before this document claimed closure.** A previous revision of this paragraph said `28` seconds and thirty-four waves while the body said otherwise — which by itself made that revision's PASS false, and is the reason §41 is now regenerated last rather than carried forward.

| Claim here | Authority | Value |
|---|---|---:|
| Composition, worst case | §35.4.3 | `88.0 s` |
| Composition, first-attempt compute | §35.4.3 | `13.6 s` |
| Composition, first-attempt bounded | §35.4.3 | `33.6 s` |
| Implementation waves | §40.2 | `35` |
| Composable Weapons | §11.9 | `179,326,745` |
| Composable Abilities | §12.7 | `16,586,524` |
| Atom catalog | §11.7.1 | `121` |
| Puzzle families | §24 | `34` |
| System pairs | §31.3 | `66` |
| Statuses | §15.2 | `13` |
| Model-check configurations | §30.6 | `49,152` |
| Union fixtures / adversarial | §37.3, §37.4 | `19` / `11` |

This document meets the Zero-Guesswork Standard v1.1 in every area of its twelve-point checklist. Where it deviates from a source proposal it says so inline and names the modifier. Where it cut something it says so in §0.4, once, in the first two hundred words. Where an earlier revision of *this document* was wrong, §41.5 and the repair audit say so by name rather than quietly correcting it.

### The verdict, stated precisely

**Design verdict: PASS.** The architecture holds, and two adversarial repair passes did not find a defect in it.

**Zero-Guesswork verdict: CONDITIONAL — NOT YET PROMOTABLE.** Not PASS, and the difference is not pedantry. The standard requires exactly one mandated outcome for every player-visible behaviour, saved state, procedural-validity input, and failure case. **Three questions remain that an implementer cannot answer from this document**, and a document with open behaviour is not zero-guesswork however clean the rest of it is:

| # | Open decision | What it changes | Whose call |
|---:|---|---|---|
| **1** | **Environmental-agency signal persistence** — transient per visit, or persistent through validated transitions and the interpretation-log fold | **Saved state.** §5.2's category assignment for signal state, and therefore what a save contains | Owner. The continuity archive marks it an explicit unresolved gate |
| **2** | **Capability gating versus Archipelago logic** | **Procedural validity.** Whether §30.6 may admit a capability-gated mandatory Check at all | Owner, and it needs AP work either way |
| **3** | **The four `HIGH` master atoms** (§11.7.2) | **Content.** Catalog `121` vs `117`, Abilities `16,586,524` vs `6,133,474`, and whether any gate-bearing family has a high-tier expression | Owner. New content, introduced by an audit, not an approved repair |

**The proposed resolution for decision 2, for approval and not enacted:**

> An allocated AP Check, a local key relevant to AP reachability, or a Zone exit may sit behind a capability gate **only if** the matching AP access rule declares the same prerequisite and Archipelago can prove that prerequisite obtainable. **Until that AP integration exists, composition rejects such placement.**

That preserves capability-gated *local* gameplay — optional routes, shortcuts, flanks — while refusing to create a second solvability model Archipelago cannot see. It matches the 2026-09-04 ruling that making an offer load-bearing *"requires a separate owner ruling and matching AP logic"*, and it is the conservative direction: it forbids something the document currently permits. **It is written here for approval and is not in force.**

**Resolve those three and the verdict becomes PASS with no further document work** — decisions 1 and 3 each have their outcomes already tabulated, and decision 2's rule is drafted above.

**It is not canon. Exactly one of the six proposals should be, and this one is the most expensive of them by a wide margin. Pick it only if you want the whole game and are prepared to build the verifier first — and read `07_ENGINE_RECONCILIATION.md` before treating §14, §21.10, §26, or §29 as buildable against the engine that exists today.**
