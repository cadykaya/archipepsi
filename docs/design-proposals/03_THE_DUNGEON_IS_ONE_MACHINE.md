# ARCHIPEPSI — COMPLETE DESIGN 3: THE DUNGEON IS ONE MACHINE

## A Zone is a machine you reprogram, not a corridor you walk

**Status:** Complete alternative proposal. Not canon until selected by the owner.
**Proposal:** 3 of 5
**Design thesis:** A Zone has one global state. Rooms are its components. What you do in one room reconfigures another, the configuration is reversible, and the memorable moment is understanding the whole machine.
**Target:** Godot 4.5 client plus the existing Python/Pydantic bridge.
**Source authorities:** `docs/authorities/PLAYER_DESIGN_AUTHORITY_v1.0.md`, `docs/authorities/DUNGEON_ENVIRONMENT_AUTHORITY_v0.1.md`
**Written against:** `docs/design-proposals/00_ZERO_GUESSWORK_STANDARD.md` v1.1

### Proposal profile

| Axis | Rating |
|---|---:|
| Novelty | 4 / 5 |
| Player-build variety | 2 / 5 |
| Environmental breadth | 4 / 5 |
| System interaction depth | 4 / 5 |
| Implementation risk | 3 / 5 |
| Procedural validation difficulty | 5 / 5 |
| Reuse of current repo foundations | 4 / 5 |

**Principal tradeoff:** this proposal spends everything on Zone-scale structure. Topology loops, macro state is reversible, signals cross rooms, and rail networks reroute. All of that is only safe because §30 replaces Design 1's construction-based safety with an actual **model check** over the Zone's reachable state space — which is the highest procedural-validation difficulty of any of the five, and the reason player-build variety is the lowest.

**Who should pick this:** an owner who wants Archipepsi's Zones to be *places you learn* rather than sequences you clear, and who accepts a leaner loadout and a slower, heavier generator to get them.

---

# 0. PURPOSE

This document resolves every open decision in the two source authorities into an implementable form, to the Zero-Guesswork Standard.

## 0.1 What the thesis claims

Dungeon Authority §70 gives a fifteen-step example dungeon: enter an unpowered wing, find a power cell, start a generator, watch conduits light through several rooms, gain a crane and lose safety as security activates, reach a control room, reroute power from security to a lift, take the lift to a rail junction, shoot a target to switch the rail, ride to a high gallery, throw a lever that permanently lowers a shortcut to the entrance, and later drain a basin that opens a whole lower level.

It then says: *"That is a dungeon. It is not a list of activities."*

**Design 3 is the proposal that builds §70.** Design 1 explicitly declines it — its four forward-only Zone flags cannot express "reroute power from security to the lift", because rerouting means the security state goes *back*. Design 2 leaves Design 1's flags untouched. This proposal makes macro state a first-class, reversible, verified system.

## 0.2 The problem this creates, stated up front

Dungeon Authority §38 requires cross-room dependencies to be *"validated for reachability"* and *"cycle-safe"*, and acceptance test D64 requires that macro state *"cannot create an accidental progression cycle."*

Design 1 satisfied both **by construction**: forward-only flags cannot cycle, and a tree topology has no loops. That is airtight and it is also the reason Design 1 cannot build §70.

Design 3 wants reversible state and a looping topology, so it cannot use construction. It must instead **prove** the property, on every generated Zone, before shipping it. §30.6 defines that proof: a breadth-first search over the product of macro state and room position, verifying that the exit is reachable from every reachable configuration.

That verification is the single most important system in this proposal, it is the reason procedural-validation difficulty is rated 5/5, and if it does not work the proposal does not work.

## 0.3 Relationship to Designs 1 and 2

Design 3 **explicitly pins** shared systems to Design 1 by section number, using the same convention Design 2 established (§0.2 of that document). A pin means *identical*, names a document and section in this repository, and is not the silent inheritance Standard §2.4 forbids.

Anything that differs, even slightly, is restated here in full. Design 3 pins more heavily on the player side than Design 2 does, because its complexity budget is spent elsewhere and it has no reason to reinvent a working combat model.

**Pins and modifiers.** A pin means *identical* — but four sections of this document modify something they also pin. Every such pin names its modifier inline, so a reader can never take a pin at face value and miss a change made later in the document. The complete list, so it can be checked rather than trusted:

| Pinned section | Modified by | What changes |
|---|---|---|
| Design 1 §6.4 (Static Pulse) | §6.6 | Gains `signal_rider = PULSE_ON_HIT` |
| Design 1 §7.1 (input roles) | §7.5 | `Tab` gains a long-press binding for the Zone Diagram |
| Design 1 §10.1 (`CarryableDefinition`) | §10.5 | `allowed_volume` may name a set of rooms |
| Design 1 §19.3 (signal evaluation) | §19.7 | Signal-verb overrides apply at step 1 |

Every other section labelled "one addition" adds something new alongside a pinned system without altering it, and a pin with no modifier named is genuinely identical.

---

# 1. INHERITED LAWS

*Pinned: identical to Design 1 §1.1 and §1.2.* All 48 laws unchanged.

Three are load-bearing here:

- **Law 34** — `NO REQUIREMENT BEFORE GUARANTEE`, which in a looping Zone applies to macro state as well as capability: no configuration may exist that the player can enter and not leave.
- **Law 42** — no softlocks. This proposal's entire verification system exists to enforce it.
- **Law 47** — composition is deterministic from a seed. Macro state adds a dimension to what must be reproducible.

## 1.3 Precedence

*Pinned: identical to Design 1 §1.3.*

---

# 2. SCOPE

## 2.1 Ships in The Dungeon Is One Machine

**Zone-scale systems — the reason this proposal exists**

- **Macro variables** (§28.3): up to 8 per Zone, 2–4 states each, freely **reversible**, against Design 1's four forward-only Booleans.
- **The Machine Graph** (§19.8): a Zone-level signal graph spanning rooms, not merely room-local graphs plus flags.
- **Predicated topology** (§28.4): every room connection carries a predicate over macro state, so the Zone's shape changes as its state changes.
- **Looping topology** (§30.2): a graph with cycles, not a tree.
- **Control rooms** (§30.4): a room purpose whose packages set macro variables.
- **Rail networks** (§26.6): multi-junction routing that reconfigures with macro state.
- **The model check** (§30.6): BFS over the product of macro state and room position, proving no dead configuration exists.
- **The Zone Diagram** (§33.7): a player-facing map of the machine, because a machine you cannot see is a machine you cannot reason about.
- **Signal verbs** (§14): a player ability family that reads and temporarily manipulates the machine.
- **Backtracking as content**: revisiting a room in a new configuration is the core loop, not a chore.

**Player — the leanest of the five, deliberately**

- Five Weapon primary families, four secondary kinds, three feed models.
- Eight Ability families, of which one is the new `SIGNAL_VERB`.
- Five Mobility families — *pinned: identical to Design 1 §13*.
- Four physics primitives — *pinned: identical to Design 1 §14*, including the rule that physics never gates progression.
- Four Statuses.
- Gear and Mods — *pinned: identical to Design 1 §16*, with three intrinsics replaced in §16.1.1.

**Dungeon**

- Signal graph, sensors, actuators, hacking — *pinned: identical to Design 1 §19–§22*, plus the machine-graph layer in §19.8 and three added sensors in §20.5.
- Eighteen puzzle families (§24): fourteen pinned from Design 1, four new and Zone-scale.
- Hazards and destruction — *pinned: identical to Design 1 §25*.
- Longer, denser, fewer Zones (§30.2).

## 2.2 Explicitly deferred

| Deferred system | Cost of deferring |
|---|---|
| Forge | *Pinned: identical to Design 1 §2.2.* |
| Water as a swimmable medium | Removes drain-and-flood as a macro variable, which is the single most evocative example in Dungeon Authority §39. **This is the most painful deferral in this proposal** and §41.2 records it. Shallow water still exists as a movement volume, and "basin drained" survives as a topology predicate rather than as simulated fluid. |
| Energy balls and reflector beams | Removes two routing families whose Zone-scale version would have fit this proposal well. |
| Dynamic joints and constraint simulation | *Pinned: identical to Design 1 §2.2.* All machinery is kinematic. Design 2 ships this; Design 3 does not. |
| Physics constructs | Physics rearranges only. |
| Portals and teleporters | No space folding. A teleporter is a topology edge with a predicate, which this proposal could express — but its camera, physics, and audit costs are unrelated to the thesis. |
| Gases, smoke, steam, pressure, temperature | Removes a hazard and readability channel. |
| Advanced and directional gravity | Global gravity is one constant. "Gravity state A → B" from Dungeon Authority §39 is therefore **not** an available macro variable, which is a named example this proposal cannot build; §41.2 records it. |
| Programmable logic | The machine graph is authored and its topology is fixed; the player reconfigures it through `SELECTOR` nodes, hacking, and signal verbs, never by writing logic. |
| Rotating whole rooms | Rotating machinery within a room ships. |
| In-Zone loadout stations | *Pinned: identical to Design 1 §2.2.* |

**Deferral means:** *pinned: identical to Design 1 §2.2.*

## 2.3 Removed rather than deferred

*Pinned: identical to Design 1 §2.3.*

## 2.4 What "v1" means here

*Pinned: identical to Design 1 §2.4.*

---

# 3. AUTHORITY AND DATA OWNERSHIP

*Pinned: identical to Design 1 §3.1 through §3.5*, including the profile mechanism — **Epsilon selects a named profile and never emits a number** — and the deterministic offline fallback.

## 3.6 One addition: the verifier is bridge authority

The model check in §30.6 runs in the bridge, at composition time, and its result is part of the Zone's definition. The client never re-runs it and never needs to.

This matters because the check is the only thing standing between a generated Zone and a softlock, and it must run exactly once, deterministically, on the machine that composed the Zone. A client that disagreed with the bridge about reachability would be a client that could refuse a valid Zone or accept an invalid one.

The client's obligation is narrower and stated in §30.9: it verifies that the Zone it loaded has the macro-variable count, connection count, and predicate set the bridge recorded, and refuses to load on mismatch.

---

# 4. SCHEMAS

*Pinned: identical to Design 1 §4.1, §4.2, §4.5, §4.6, §4.7* — common types, host definitions, Gear/Mod/Status shapes, profiles, and the loadout.

## 4.3 Weapon

```
WeaponDefinition (extends HostDefinition, category = WEAPON):
  primary           : WeaponAction
  secondary         : SecondaryAction? = null
  feed              : FeedSpec
  view_modules      : list[Id], length 3..6

WeaponAction:
  family            : enum { HITSCAN_SINGLE, HITSCAN_BURST, PROJECTILE_DIRECT,
                             BEAM_CONTINUOUS, CLOSE_ARC }
  profile           : Id
  status_applied    : Id? = null
  status_chance     : Chance = 0.0
  crit_eligible     : bool = true
  signal_rider      : enum { NONE, PULSE_ON_HIT } = NONE

SecondaryAction:
  kind              : enum { ZOOM, ALT_FIRE, GUARD, PROBE_SHOT }
  profile           : Id
  alt_action        : WeaponAction? = null    # required iff kind == ALT_FIRE

FeedSpec:
  model             : enum { MAGAZINE, HEAT, NONE }
  profile           : Id
```

`signal_rider = PULSE_ON_HIT` makes a Weapon able to trigger a `SHOOTABLE_TARGET` from any family, which matters in a Zone where shooting a distant target to reroute a rail is a common verb. It emits nothing on a hit against an actor.

`PROBE_SHOT` is a secondary that reveals the machine-graph state of whatever it strikes for `8.0 s` (§14.2).

## 4.4 Ability and Mobility

```
AbilityDefinition (extends HostDefinition, category = ABILITY):
  family            : enum { SIGNAL_VERB, PROJECTILE_ATTACK, AREA_BURST,
                             BARRIER_GRANT, DEPLOYABLE_FIELD, STATUS_APPLICATOR,
                             MARK_REVEAL, PHYSICS_VERB }
  activation        : enum { PRESS, HOLD, CHARGE_RELEASE, CHANNEL }
  recharge          : RechargeSpec
  profile           : Id
  status_applied    : Id? = null
  status_chance     : Chance = 0.0
  signal_verb       : enum { PROBE, BRIDGE, INVERT, HOLD_SIGNAL, CUT }? = null
                      # required iff family == SIGNAL_VERB, else must be null
  physics_primitive : enum { PUSH, PULL, HOLD, ALIGN }? = null
                      # required iff family == PHYSICS_VERB, else must be null
```

`MobilityDefinition` and `RechargeSpec` — *pinned: identical to Design 1 §4.4*, with one added hybrid template, `MACRO_CHANGE_REFRESHES_COOLDOWN` (§12.7).

## 4.8 Macro variable — new to Design 3

```
MacroVariable:
  id                : Id                       # macro:<zone_slug>:<name>
  states            : list[string], length 2..4
  initial_state     : string                   # must appear in states
  reversible        : bool = true
  display_name      : string, 1..32 chars
  setters           : list[Id]                 # package ids that may set it
```

`reversible = false` reproduces Design 1's forward-only flag as a special case, and the composer uses it for genuinely one-way events such as a collapsed structure. The default is `true`, which is the inversion this proposal is built on.

**A macro variable is set only by a package listed in `setters`.** Nothing else changes it — not a signal verb, not physics, not damage. §14.4 explains why that restriction is what makes verification possible.

## 4.9 Machine graph — new to Design 3

```
MachineGraph:
  zone_id           : Id
  variables         : list[MacroVariable], length 0..8
  edges             : list[TopologyEdge]
  effects           : list[MacroEffect]
  state_bound       : int                      # product of all states, <= 4096

TopologyEdge:
  id                : Id
  room_a            : Id
  room_b            : Id
  direction         : enum { BIDIRECTIONAL, A_TO_B }
  predicate         : Predicate                # when this edge is passable
  capability        : Id? = null               # a §29.1 capability, or null

MacroEffect:
  variable          : Id
  state             : string
  target_room       : Id
  effect            : enum { POWER_ON, POWER_OFF, HAZARD_ON, HAZARD_OFF,
                             LIGHT_ON, LIGHT_OFF, RAIL_ROUTE, ACTUATOR_STATE,
                             ENCOUNTER_ENABLE, SECRET_REVEAL }
  parameter         : string = ""

Predicate:
  clauses           : list[Clause], length 1..4      # OR of clauses
Clause:
  terms             : list[Term], length 1..4        # AND of terms
Term:
  variable          : Id
  operator          : enum { IS, IS_NOT }
  state             : string
```

Predicates are disjunctive normal form, bounded at four clauses of four terms. Bounded DNF rather than arbitrary expressions is deliberate: it is trivially evaluable, trivially explainable to the player in the Zone Diagram (§33.7), and it keeps the verifier's per-edge cost constant.

`state_bound` is the product of every variable's state count and **must not exceed 4096**. With at most 14 rooms, the verifier's product graph is at most `4096 × 14 = 57,344` nodes, which is a BFS that completes in milliseconds. That bound is what makes §30.6 affordable, and §30.5 check 12 enforces it.

## 4.10 Zone runtime state

```
ZoneState:
  zone_id           : Id
  macro             : map[Id, string]          # every variable's current state
  visited_rooms     : list[Id]
  discovered_edges  : list[Id]                 # for the Zone Diagram
  diagram_known     : map[Id, bool]            # per-variable, has the player seen it
```

---

# 5. LIFECYCLE AND PERSISTENCE

*Pinned: identical to Design 1 §5.1, §5.3, §5.4, §5.5, §5.6, §5.7, §5.10, §5.11, §5.12* — the five categories, snapshot cadence, death, room unload, host runtime state, cold introduction, mid-transition machinery, temporary grants, and encounter unreachability.

## 5.2 Category assignment

Design 1 §5.2's table, with the Zone-flag row replaced:

| State | Category |
|---|---|
| *(all `EPHEMERAL` and `PUZZLE_LOCAL` rows)* | *Pinned: identical to Design 1 §5.2.* |
| Encounter cleared-flag | `ROOM_PERSISTENT` |
| One-way shortcut opened-flag | `ROOM_PERSISTENT` |
| Local key collected-flag | `ROOM_PERSISTENT` |
| Secret discovered-flag | `ROOM_PERSISTENT` |
| Checkpoint reached-flag | `ROOM_PERSISTENT` |
| **`ZoneState.macro`** | **`ZONE_PERSISTENT`** |
| **`ZoneState.visited_rooms`, `discovered_edges`, `diagram_known`** | **`ZONE_PERSISTENT`** |
| Player Health at checkpoint | `ZONE_PERSISTENT` |
| Host runtime state | `ZONE_PERSISTENT` |
| *(all `AP_PERSISTENT` rows)* | *Pinned: identical to Design 1 §5.2.* |

## 5.8 Macro state on death and reset

**Macro state is never changed by death, puzzle reset, or room reload.** It changes only when a setter package sets it.

This is the direct consequence of §4.8's setter restriction and it is worth stating plainly: a player who dies immediately after rerouting power wakes at a checkpoint with power still rerouted. The Zone remembers, because the Zone is the machine and the player's death is not an event in it.

## 5.9 Save/load reconstruction order

Design 1 §5.9's ten steps, with macro state inserted:

1. AP state.
2. Committed Loadout.
3. Zone identity and seed; recompose deterministically.
4. **`ZoneState.macro`.**
5. **Evaluate every `TopologyEdge` predicate against the restored macro state; establish which edges are passable.**
6. **Apply every `MacroEffect` matching the restored state to its target room.**
7. Per-room `ROOM_PERSISTENT` flags.
8. Per-room `PUZZLE_LOCAL` state for the entry room and its neighbours.
9. Host runtime state.
10. Player transform and Health.
11. **Verify the player's room is reachable from the Zone entry under the restored macro state.** On failure, this is a hard error: the save is refused with the message in §34.13 rather than loading into a state the verifier says is impossible.
12. Rebuild `EPHEMERAL` state.

Step 11 is a cheap consistency check that catches a corrupted or hand-edited save before it becomes an unexplainable softlock. It re-runs one BFS on the loaded state, not the full §30.6 verification.

---

# 6. BASE PLAYER

*Pinned: identical to Design 1 §6.1 through §6.5* — body, the movement law and all its derived margins, out-of-bounds recovery, Static Pulse, and baseline melee — **except that §6.4 is modified by §6.6 below**.

The movement law is untouched for the same reason Design 2 gives: every traversal audit, LaunchPad solve, and mandatory-route guarantee in both authorities is computed from it, and this proposal's verifier depends on those computations being correct.

## 6.6 Static Pulse triggers targets — modifies Design 1 §6.4

Static Pulse has `signal_rider = PULSE_ON_HIT`.

Every mandatory `SHOOTABLE_TARGET` in the Zone — including every rail-switch and macro-setter target — is therefore reachable with the permanent baseline, which is what `capability:core:ranged_hit` guarantees. In a Zone where shooting a distant target reroutes the machine, this is not a convenience; it is the thing that keeps the machine operable by a player with no items.

---

# 7. INPUT

*Pinned: identical to Design 1 §7.1 through §7.4* — **except that §7.1's `archive` row is modified by §7.5 below**.

## 7.5 The Zone Diagram binding — modifies Design 1 §7.1

`Tab` opens the Archive, per Design 1 §7.1. A **long press of `Tab`** — held `0.35 s` — opens the Zone Diagram (§33.7) instead. A short press opens the Archive.

This is the only compound input in any of the five proposals, and it earns its place: the Diagram is opened constantly in this design, it needs no other free key, and a long press cannot be triggered accidentally by a player reaching for the Archive.

Both are rebindable independently; a player who dislikes the long press may bind the Diagram to any free key.

---

# 8. DAMAGE

*Pinned: identical to Design 1 §8.1 through §8.8.* One damage road, the same Defense curve, Barrier pooling, linear overcrit, healing, death, and the friendly-fire table including player-owned physics impacts at zero.

---

# 9. WORLD INTERACTION

*Pinned: identical to Design 1 §9.1 through §9.4.*

## 9.5 One addition: macro setters are interactions

A macro-setter package exposes its setter as an ordinary Interactable with `verb = PULL` or `verb = USE_TERMINAL`, at priority class 4. Setting a macro variable is a normal `F` press with a normal prompt.

The prompt names the consequence rather than the mechanism:

> `[F] Route power to the lift`

not

> `[F] Set macro:vault:power to lift`

The Zone Diagram is where the player sees the variable; the prompt is where they see what pulling this lever does. Dungeon Authority §3.1 requires cause and effect to be legible, and at Zone scale a prompt alone cannot carry it — which is why §33.7 exists.

---

# 10. CARRYABLES AND SOCKETS

*Pinned: identical to Design 1 §10.1 through §10.4* — seven object classes, carry rules, drop and place, and the recovery triggers — **except that §10.1's `allowed_volume` field is modified by §10.5 below**.

## 10.5 Cross-room carry — modifies Design 1 §10.1

One field of `CarryableDefinition` changes:

```
allowed_volume    : list[Id], length >= 1      # Design 1: a single Id
```

A carryable's `allowed_volume` names a **set** of rooms, so a power cell can be carried from the room it spawns in to the generator it powers three rooms away. A single-element list is the Design 1 behaviour and is the default the composer uses for ordinary room-local objects.

Rules:

- A carryable with a multi-room `allowed_volume` is `ZONE_PERSISTENT` rather than `PUZZLE_LOCAL`, because it survives the unload of the room it started in.
- Carrying is blocked across an edge whose predicate is currently false, because that edge is not passable at all.
- **A required cross-room carryable's `home_transform` must lie in a room reachable under every reachable macro state**, checked by §30.6. Otherwise a player could carry the cell into a wing, change the machine, and strand the cell where the puzzle needing it can never reach it.
- Dropping it anywhere in its `allowed_volume` is legal. Recovery per Design 1 §10.4 returns it to `home_transform`.

That third rule is one of the six things the verifier proves, and it is the one that would be easiest to miss by hand.

---

# 11. WEAPONS

Five primary families. Design 1's eight minus `HITSCAN_SPREAD`, `PROJECTILE_LOB`, and `CHARGE_RELEASE_SHOT`.

## 11.1 Primary families

*Parameters and profiles: pinned: identical to Design 1 §11.1* for `HITSCAN_SINGLE`, `HITSCAN_BURST`, `PROJECTILE_DIRECT`, `BEAM_CONTINUOUS`, and `CLOSE_ARC`. Every profile in those five families is unchanged.

The three cut families are cut for budget, not principle: this proposal's complexity lives at Zone scale, and a spread shotgun adds a row to a catalog without adding a decision to a dungeon.

## 11.2 Signal riders

| Rider | Effect |
|---|---|
| `NONE` | None |
| `PULSE_ON_HIT` | A hit on a `SHOOTABLE_TARGET` emits its pulse, regardless of the target's `required_tags` |

`PULSE_ON_HIT` is on Static Pulse permanently (§6.6) and may appear on any generated Weapon. It never emits on a hit against an actor and never interacts with any sensor other than `SHOOTABLE_TARGET`.

## 11.3 Secondary kinds

*Pinned: identical to Design 1 §11.2* for `ZOOM`, `ALT_FIRE`, and `GUARD`. `DETONATE` and `MODE_SWAP` are absent — `DETONATE` because `PROJECTILE_LOB` is not a family here, `MODE_SWAP` because a five-family catalog does not need it.

| Kind | Behavior | Uses feed |
|---|---|---|
| `PROBE_SHOT` | **New.** Reveals the machine-graph state of the struck node, actuator, or conduit for `8.0 s`: its current value, its input node, and the predicate governing it. No damage, no feed cost. | no |

| Profile | `range` | `reveal_duration` | `interval` |
|---|---:|---:|---:|
| `probe_standard` | `50.0` | `8.0` | `1.0` |
| `probe_long` | `90.0` | `12.0` | `1.6` |

`PROBE_SHOT` is the Weapon-slot expression of this proposal's information layer. It is never required — the Zone Diagram (§33.7) shows everything a mandatory route depends on — but it is how a player reads a machine from across a room without walking to it.

## 11.4 Feeds

*Pinned: identical to Design 1 §11.3 (`MAGAZINE`), §11.4 (`HEAT`), §11.6 (`NONE`).* `CHARGE` is absent with `CHARGE_RELEASE_SHOT`.

## 11.5 Cycling and activation

*Pinned: identical to Design 1 §11.7*, with the `CHARGE` and `PROJECTILE_LOB` rows removed as inapplicable.

---

# 12. ABILITIES, READINESS, AND COST

## 12.1 The eight families

| Family | What it does | Damage | Legal Statuses |
|---|---|---|---|
| `SIGNAL_VERB` | Executes one of the five signal verbs in §14.1 | no | none |
| `PROJECTILE_ATTACK` | *Pinned: identical to Design 1 §12.1.* | yes | any |
| `AREA_BURST` | *Pinned: identical to Design 1 §12.1.* | yes | any |
| `BARRIER_GRANT` | *Pinned: identical to Design 1 §12.1.* | no | none |
| `DEPLOYABLE_FIELD` | *Pinned: identical to Design 1 §12.1.* | yes | any |
| `STATUS_APPLICATOR` | *Pinned: identical to Design 1 §12.1.* | no | any, required |
| `MARK_REVEAL` | Highlights actors, Interactables, **conduits, and machine-graph nodes** through geometry | no | none |
| `PHYSICS_VERB` | *Pinned: identical to Design 1 §12.1.* Four primitives. | no | none |

Design 1's `HEAL_CHANNEL`, `DEPLOYABLE_TURRET`, `DASH_IMPULSE`, `WEAPON_BUFF`, and `TEMPORARY_RULE` are absent. `SIGNAL_VERB` is new.

Common parameters and profiles — *pinned: identical to Design 1 §12.1* — with the added `magnitude` meaning:

| Family | `magnitude` means |
|---|---|
| `SIGNAL_VERB` | duration of the temporary effect, in seconds |

Signal profiles:

| Profile | `cast_time` | `duration` | `radius` | `range` | `magnitude` |
|---|---:|---:|---:|---:|---:|
| `sig_probe` | `0.00` | `10.0` | `0.0` | `40.0` | `10.0` |
| `sig_brief` | `0.20` | `0.0` | `0.0` | `30.0` | `6.0` |
| `sig_sustained` | `0.20` | `0.0` | `0.0` | `25.0` | `14.0` |

## 12.2 Activation forms

*Pinned: identical to Design 1 §12.2 and §12.2.1.*

## 12.3 Preflight and commit

*Pinned: identical to Design 1 §12.3.*

For `SIGNAL_VERB`, family-specific validity means: a legal machine-graph node exists within `range`, with line of sight, and the verb is legal on that node type per §14.3.

## 12.4–12.6 Recharge identities

*Pinned: identical to Design 1 §12.4 (`RESOURCE`), §12.5 (`COOLDOWN`), §12.6 (`ACTION`)*, with the fact catalog changed: `WEAPON_CYCLED` is removed, and two are added.

| Fact | Advances on |
|---|---|
| *(the nine retained from Design 1 §12.6)* | *Pinned.* |
| **`MACRO_CHANGED`** | **each time the player sets a macro variable to a state it was not in** |
| **`ROOM_REVISITED`** | **each time the player enters a room they have visited before, under a macro state they have not seen that room in** |

| Profile | `fact` | `threshold` | `contribution` | `decay_rate` |
|---|---|---:|---:|---:|
| *(Design 1's seven)* | *Pinned.* | | | |
| `act_macro_one` | `MACRO_CHANGED` | `1.0` | `1.0` | `0.0` |
| `act_revisit_three` | `ROOM_REVISITED` | `3.0` | `1.0` | `0.0` |

`ROOM_REVISITED` is the fact that most expresses this proposal's loop: it advances when the player comes back to somewhere they know and finds it different. It cannot be farmed by walking a corridor, because the `(room, macro state)` pair must be new.

## 12.7 Hybrids

Design 1 §12.7's five templates, plus one:

| Template | Applies to | `SMALL` | `MEDIUM` | `LARGE` |
|---|---|---|---|---|
| *(Design 1's five)* | | *Pinned: identical to Design 1 §12.7.* | | |
| **`MACRO_CHANGE_REFRESHES_COOLDOWN`** | `COOLDOWN` | **`−2.0 s` per macro change** | **`−5.0 s`** | **restores one full charge** |

Contribution cap, loop prevention, and the no-hidden-second-tax rule — *pinned: identical to Design 1 §12.7.* The `LARGE` variant restoring a full charge is bounded by the fact that macro changes are authored, finite, and gated behind reaching a setter room; it cannot be spammed.

## 12.8 Runtime persistence

*Pinned: identical to Design 1 §12.8.*

## 12.9 The compatibility matrix

| Family | `PRESS` | `HOLD` | `CHARGE_RELEASE` | `CHANNEL` | `RESOURCE` | `COOLDOWN` | `ACTION` |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| `SIGNAL_VERB` | ● | | | | ● | ● | ● |
| `PROJECTILE_ATTACK` | ● | | ● | | ● | ● | ● |
| `AREA_BURST` | ● | | ● | | ● | ● | ● |
| `BARRIER_GRANT` | ● | ● | | | ● | ● | ● |
| `DEPLOYABLE_FIELD` | ● | | | | ● | ● | ● |
| `STATUS_APPLICATOR` | ● | | ● | | ● | ● | ● |
| `MARK_REVEAL` | ● | | | | | ● | ● |
| `PHYSICS_VERB` | ● | ● | | | ● | ● | |

`SIGNAL_VERB` is `PRESS`-only. A held or channelled signal verb would mean a machine state that persists exactly as long as an input is held, which is a fourth kind of state on top of macro, room, and puzzle state, and this proposal has enough of those. Its effects are already temporary with an authored duration, which is the same expressiveness without the extra state.

`SIGNAL_VERB` **may** be `ACTION`, unlike `PHYSICS_VERB`, because signal verbs are never required for progression (§14.4) and so cannot strand a player.

`PHYSICS_VERB` cannot be `ACTION` — *pinned reasoning from Design 1 §12.9.*

## 12.10 `TEMPORARY_RULE`

Absent. Design 1's family and its six rules are not in this proposal's catalog.

---

# 13. MOBILITY

*Pinned: identical to Design 1 §13.1 through §13.6.* Five families, the same profiles, ground and air legality, safety validation, grapple and blink specifics, and the horizontal-only `long_gap` contract.

---

# 14. SIGNAL VERBS

The player's interface to the machine.

## 14.1 The five verbs

| Verb | Effect | Duration |
|---|---|---|
| `PROBE` | Reveals a node's current value, its inputs, and its governing predicate | `magnitude` seconds |
| `BRIDGE` | Temporarily connects the output of one node to the input of another | `magnitude` seconds |
| `INVERT` | Temporarily inverts a Boolean node's output | `magnitude` seconds |
| `HOLD_SIGNAL` | Temporarily forces a Boolean node's output `ON` | `magnitude` seconds |
| `CUT` | Temporarily forces a Boolean node's output `OFF` | `magnitude` seconds |

## 14.2 Targeting

A signal verb targets a **node**, not an object. Legal targets are: sensors, logic nodes, actuator inputs, and conduits, all within `range` with line of sight.

Nodes are targetable only once the player has seen them — either by standing in the room, by `PROBE`, by `PROBE_SHOT` (§11.3), or by `MARK_REVEAL`. An unseen node cannot be targeted, which prevents blind manipulation of a machine the player has not met.

`BRIDGE` requires two activations: the source node, then the destination. The second must occur within `10.0 s` or the first is discarded with no cost, since the cost commits on the second.

## 14.3 Legality by node type

| Node type | `PROBE` | `BRIDGE` | `INVERT` | `HOLD_SIGNAL` | `CUT` |
|---|:-:|:-:|:-:|:-:|:-:|
| Sensor | ● | source only | ● | ● | ● |
| `DIRECT`, `AND`, `OR`, `NOT` | ● | ● | ● | ● | ● |
| `TIMER`, `DELAY` | ● | ● | | ● | ● |
| `LATCH`, `COUNTER`, `SEQUENCE` | ● | source only | | | ● |
| `SELECTOR`, `THRESHOLD` | ● | source only | | | ● |
| Actuator input | ● | destination only | ● | ● | ● |
| **Macro setter** | ● | | | | |

The last row is the load-bearing one. **No signal verb can set, change, or hold a macro variable.** A macro setter can be probed and nothing else.

## 14.4 Why signal verbs never gate progression

Every signal verb is temporary, and none may drive a macro setter. Both restrictions exist for one reason: the §30.6 verifier proves reachability **assuming the player has no signal verbs at all**.

That makes signal verbs pure upside. They can open a shortcut, skip a fetch, or hold a door long enough to slip through — and none of that can produce a Zone state the verifier did not consider, because the machine returns to its verified configuration when the effect expires and the macro state was never touched.

The consequence, stated plainly: **a signal build makes a Zone easier, never different in a way that matters to progression.** §41.2 records that as a real limitation. A player who invests in signal verbs is buying convenience and information, not access.

## 14.5 Interaction with hacking

A `HACK_TERMINAL` (Design 1 §22) is a macro setter or an ordinary node, per its package. Where it is a macro setter, signal verbs cannot substitute for hacking it — the hack must be performed. Where it is an ordinary node, `HOLD_SIGNAL` on its output produces the same effect as completing the hack, for `magnitude` seconds.

That is intentional: hacking a door open permanently is a different act from holding it open for six seconds, and a player who wants the permanent version does the minigame.

---

# 15. STATUS

Four Statuses. *Pinned: identical to Design 1 §15.2 (application), §15.3 (duration and stacking), §15.5 (required feedback).*

## 15.1 The four

*Pinned: identical to Design 1 §15.1* for `status:core:burning`, `status:core:lightened`, `status:core:anchored`, and `status:core:exposed`, including `BURNING`'s Fire Actor mechanism.

`CONFUSED` and `TURNCOAT` are cut, as in Design 2, and for the same budget reason. Families are therefore `KINETIC` and `THERMAL`; `COGNITIVE` does not exist.

## 15.4 Immunity and substitution

| Target | Immune to | Substitution |
|---|---|---|
| Boss | `ANCHORED` | `EXPOSED`, half duration |
| Turret (immobile) | `ANCHORED`, `LIGHTENED` | none; attempt fails visibly |
| Fire Actor | all | none |

---

# 16. GEAR, MODS, AND RULES

*Pinned: identical to Design 1 §16.2 through §16.5* — Mod templates, compatibility, modifier order, and runtime clamps.

## 16.1 Gear

*Pinned: identical to Design 1 §16.1* for slots, tiers, and the one-high-tier rule.

### 16.1.1 Three replaced intrinsics

| Territory | Legal intrinsic templates |
|---|---|
| `HEAD` | `INT_MARK_ON_HIT`, `INT_OVERCRIT_ADVANCES_ABILITY`, `INT_STATUS_POTENCY`, **`INT_REVEAL_MACHINE`**, `INT_CRIT_CHANCE` |
| `TORSO` | *Pinned: identical to Design 1 §16.1.* |
| `ARMS` | `INT_MELEE_DAMAGE`, `INT_RELOAD_SPEED`, **`INT_SIGNAL_RANGE`**, `INT_PHYSICS_FORCE`, `INT_INTERACT_RANGE` |
| `LEGS` | `INT_MOVE_SPEED`, `INT_JUMP_HEIGHT`, `INT_MOBILITY_RECHARGE`, `INT_LANDING_CONTROL`, **`INT_RAIL_CONTROL`** |

| Template | `SMALL` | `MEDIUM` | `LARGE` |
|---|---|---|---|
| `INT_REVEAL_MACHINE` | Machine nodes visible through geometry within `12 m` | `25 m` | `45 m` |
| `INT_SIGNAL_RANGE` | Signal verb `range` `+20%` | `+45%` | `+75%` |
| `INT_RAIL_CONTROL` | rail speed `+10%` | `+22%` | `+38%` |

`INT_RAIL_CONTROL` is *pinned: identical to Design 1 §16.1* and restated here only because rails are central to this proposal and it is retained rather than replaced.

Replaced: `INT_REVEAL_INTERACTABLES` (subsumed), `INT_HEAT_CAPACITY` (three feeds), and `INT_RESOURCE_REGEN` moves nowhere — it stays on `TORSO`.

---

# 17. FOREIGN ITEMS, ARCHIVE, AND MIGRATION

*Pinned: identical to Design 1 §17.1 through §17.6.* The only difference is the content of the enumerated lists Epsilon selects from, which are this document's §11.1, §11.3, §12.1, and §13.1.

---

# 18. ECONOMY

*Pinned: identical to Design 1 §18.1, §18.2, §18.3.*

---

# 19. SIGNAL GRAPH

*Pinned: identical to Design 1 §19.1 through §19.6* — four port forms, eleven node types, acyclic topological evaluation within one tick, conduits as presentation with their five states, and per-node persistence — **except that §19.3's evaluation order is modified by §19.7 below**.

## 19.7 Signal-verb effects on evaluation — modifies Design 1 §19.3

A signal verb's effect (§14.1) is applied at evaluation step 1, alongside sensor writes, as an override on the affected node's output. `INVERT`, `HOLD_SIGNAL`, and `CUT` override the node's computed value; `BRIDGE` adds an edge for the duration.

A bridged edge that would create a cycle in the room's graph is **rejected at activation** with the §34.11 feedback, and the cost is not spent. The graph stays acyclic at all times, so §19.3's single-tick topological evaluation holds unchanged.

## 19.8 The Machine Graph — new to Design 3

Above the per-room signal graphs sits one Zone-level layer.

```
Room signal graph   — local sensors, logic, actuators.  Acyclic. Per room.
        ↑ reads                              ↓ sets (via setter packages only)
Machine graph       — macro variables, topology predicates, macro effects.
                      Zone-scoped. Evaluated on macro change, not per tick.
```

Rules that keep the two layers from becoming one intractable graph:

1. **A room's signal graph may read macro state** through a `MACRO_STATE` sensor (§20.5). It is an input like any other.
2. **A room's signal graph may not write macro state.** Only a setter package writes, and only through a player `F` interaction (§9.5).
3. **The machine graph has no logic nodes.** It is variables, predicates, and effects — no `AND`, no `TIMER`, no `LATCH`. All logic lives in room graphs.
4. **The machine graph is evaluated on macro change only**, not per tick. A macro change re-evaluates every topology predicate and re-applies every matching effect, once.
5. **Macro effects are idempotent.** Applying the same effect twice is applying it once. This is what makes re-evaluation on load (§5.9 step 6) produce the same result as the original sequence of changes.

Rules 2 and 3 together are what make §30.6's verification tractable: the machine graph is a finite state machine whose transitions are player actions, with no internal dynamics of its own. If room graphs could write macro state, the state space would include every room's signal configuration and the product would be astronomically larger.

---

# 20. INPUTS AND SENSORS

*Pinned: identical to Design 1 §20.1 through §20.4* — nine sensor types including the semantic-mass rule and the `[RANGED]` requirement on mandatory shootable targets.

## 20.5 Three additions

| Type | Output | Key parameters |
|---|---|---|
| `MACRO_STATE` | Boolean | `variable`, `state` — `ON` while the named variable is in the named state |
| `MACRO_SELECTOR` | Value `[0,15]` | `variable` — emits the index of the variable's current state |
| `ROOM_VISITED` | Boolean | `room_id` — `ON` once the player has entered the named room |

`MACRO_STATE` is how a room reacts to the Zone. A door in room 7 that opens when power is routed to the lift is a `MACRO_STATE` sensor feeding a `DIRECT` node feeding a `DOOR` actuator, and nothing about the door needs to know that the lever is three rooms away.

`ROOM_VISITED` exists so a Zone can react to exploration without a macro variable. It is monotone — once `ON`, never `OFF` — and it is included in the verifier's state vector (§30.6) exactly like an irreversible variable.

---

# 21. ACTUATORS AND MACHINERY

*Pinned: identical to Design 1 §21.1, §21.1.1, §21.2 through §21.9* — the common contract, per-kind power-loss behaviour, and all nine kinds.

## 21.10 Macro effects

A `MacroEffect` (§4.9) applies a change to a room when a variable enters a state. The ten effect types:

| Effect | Behavior |
|---|---|
| `POWER_ON` / `POWER_OFF` | Sets the target room's `power` signal, which every `requires_power` actuator reads as an `AND` term |
| `HAZARD_ON` / `HAZARD_OFF` | Enables or disables every hazard in the target room |
| `LIGHT_ON` / `LIGHT_OFF` | Sets the room's lighting state |
| `RAIL_ROUTE` | Sets a named rail junction to the branch named in `parameter` |
| `ACTUATOR_STATE` | Drives a named actuator to `t = 0` or `t = 1`, per `parameter` |
| `ENCOUNTER_ENABLE` | Arms an encounter that is otherwise inert |
| `SECRET_REVEAL` | Reveals a secret passage |

Rules:

- Effects apply **immediately and without animation** when the macro state changes and the player is not in the target room. When the player *is* in the target room, actuators animate at `travel_time` per Design 1 §21.1, because a door teleporting shut beside the player is unreadable.
- `POWER_OFF` on a room whose actuators are mid-motion follows Design 1 §21.1.1's per-kind power-loss table: doors close, load-bearing machinery holds.
- **`HAZARD_ON` never activates a hazard the player is currently standing inside.** It waits until the player leaves that hazard's volume, then activates. Without this rule, routing power can kill a player standing in the wrong corridor with no telegraph, which Dungeon Authority §25 forbids.
- Effects are idempotent (§19.8 rule 5).

---

# 22. HACKING

*Pinned: identical to Design 1 §22.1, §22.2, §22.3.* One reusable route-connection minigame, three difficulties, no failure state.

A hack terminal may be a macro setter (§14.5), which is how "reroute power from security to the lift" is expressed as an act rather than a lever pull.

---

# 23. PUZZLE-PACKAGE CONTRACT

*Pinned: identical to Design 1 §23.1 through §23.6*, with three added manifest fields and two added validation checks.

## 23.1 Added manifest fields

```
PackageManifest:
  ...                                          # Design 1 §23.1's fields
  macro_setter        : MacroSetter? = null    # NEW
  macro_predicate     : Predicate?   = null    # NEW — when this package is active
  cross_room_objects  : list[Id] = []          # NEW — carryables with multi-room volumes

MacroSetter:
  variable            : Id
  sets_to             : list[string]           # the states this package can set
  interaction_verb    : enum { PULL, USE_TERMINAL, HACK }
  prompt_text         : string, 1..64 chars    # names the consequence, per §9.5
```

A package with a non-null `macro_setter` is a **setter package**. A package with a non-null `macro_predicate` is inert while the predicate is false: its objects are present but its signals do not evaluate and its interactions are disabled with a `disabled_reason`.

## 23.5 Two added validation checks

| # | Check |
|---|---|
| 1–18 | *Pinned: identical to Design 1 §23.5.* |
| **19** | **Every setter package's `sets_to` states all appear in its variable's `states`, and the package's room is listed in the variable's `setters`.** |
| **20** | **Every `cross_room_objects` entry has an `allowed_volume` covering every room between its `home_transform` and every socket that consumes it, under at least one reachable macro state.** The stronger cross-state guarantee is §30.6 property 4. |

---

# 24. THE EIGHTEEN PUZZLE FAMILIES

Fourteen pinned from Design 1 §24, four new and Zone-scale.

| # | Family | Origin |
|---|---|---|
| 1–14 | `CARRY_TO_PLATE`, `INSERT_COMPONENT`, `PULSE_REMOTE`, `TIMED_TRAVERSE`, `SHOOT_TARGET`, `TOGGLE_ROOM_STATE`, `HACK_OVERRIDE`, `DUAL_INPUT`, `ALTERNATE_INPUT`, `ROUTE_SWITCH`, `MOVING_MACHINE`, `ENCOUNTER_GATE`, `A_B_STATE`, `LOCAL_KEY_LOOP` | *Pinned: identical to Design 1 §24.* |
| 15 | **`MACRO_SETTER`** | A control point that sets one macro variable. The atom of this proposal. |
| 16 | **`POWER_ROUTE`** | A control room that moves one power allocation between two or more consumers, each in a different room |
| 17 | **`CROSS_ROOM_FETCH`** | A carryable in room A, a socket in room B, with the route between them predicated on macro state |
| 18 | **`RAIL_NETWORK`** | A multi-junction rail whose routing is set by macro state, reaching different rooms in different configurations |

Design 1's `BOMB_BARRIER`, `OBSERVATION_TARGET`, `MULTI_STAGE_MACHINE`, and `DUNGEON_STATE_CHANGE` are absent as families. The first two for budget; `MULTI_STAGE_MACHINE` because a multi-stage machine is now expressed as a chain of macro variables rather than a single package; and `DUNGEON_STATE_CHANGE` because it has been promoted from one puzzle family into the entire architecture of this proposal.

---

# 25. HAZARDS AND DESTRUCTION

*Pinned: identical to Design 1 §25.0 through §25.5* — material traits, hazard contract, six families, four destructible classes, environmental kill credit, and enemy participation.

Hazards gain Zone-scale control through `HAZARD_ON` / `HAZARD_OFF` (§21.10), which is how "security active → disabled" from Dungeon Authority §39 is expressed.

---

# 26. ROUTING, FORCES, AND CONSTRAINTS

*Pinned: identical to Design 1 §26.1 (power), §26.2 (wind), §26.3 (conveyors and cargo), §26.5 (constraints deferred).*

## 26.4 Player rails

*Pinned: identical to Design 1 §26.4* for ride speed, mounting, dismounting, and control while riding.

## 26.6 Rail networks — new to Design 3

Design 1 has rails with a switch. Design 3 has a **network**: a set of rail segments joined at junctions, where each junction's branch is set by a `RAIL_ROUTE` macro effect or a local `ROUTE_SWITCH` package.

```
RailNetwork:
  id                : Id
  segments          : list[RailSegment]
  junctions         : list[RailJunction]

RailSegment:
  id                : Id
  spline            : spline                  # tagged rail_compatible
  from_junction     : Id?                     # null if it starts at a mount point
  to_junction       : Id?                     # null if it ends at a dismount point

RailJunction:
  id                : Id
  room              : Id
  branches          : list[Id]                # segment ids, length 2..4
  current_branch    : int                     # index into branches
  set_by            : enum { MACRO, LOCAL_SWITCH }
  variable          : Id?                     # required iff set_by == MACRO
```

Rules:

- A network has at most `6` junctions and `12` segments per Zone.
- Junction changes obey Design 1 §21.6: a change is queued while any actor is within `10.0 m` of the junction and applies when it clears.
- **Every reachable routing of the network must terminate at a dismount point.** A routing that dead-ends mid-air is rejected at composition by §30.5 check 13. This is checked exhaustively — at most `4^6 = 4096` routings, each a linear walk.
- A rail route is a topology edge for verification purposes (§30.6), with a predicate derived from the junction settings that produce it.

A rail network is the clearest expression of this proposal's thesis: the same physical rails carry the player to a different place depending on the state of the machine.

---

# 27. MEDIA

*Pinned: identical to Design 1 §27.1 through §27.4.* Shallow water only, lighting with two mechanical hooks plus `LIGHT_ON` / `LIGHT_OFF`, sound with visual equivalents, and the deferred media list.

---

# 28. ROOM AND ZONE TOPOLOGY

*Pinned: identical to Design 1 §28.1 (room-local transformations), §28.2 (one-way shortcuts), §28.5 (local keys), §28.6 (secrets), §28.7 (offer types).*

## 28.3 Macro variables — replacing Design 1's Zone flags

Design 1's four forward-only Booleans are replaced by up to **eight variables of two to four states each, reversible by default** (§4.8).

| Property | Design 1 | Design 3 |
|---|---|---|
| Count | 4 | up to 8 |
| States each | 2 (Boolean) | 2–4 |
| Reversible | never | by default; `reversible = false` available |
| Set by | one package each | any package in the variable's `setters` list |
| Read by | later spine rooms only | any room, in any direction |
| Safety | by construction | by the §30.6 model check |

Example variables from a real Zone:

| Variable | States |
|---|---|
| `power_route` | `none`, `security`, `lift`, `rails` |
| `basin` | `flooded`, `drained` |
| `gantry` | `stowed`, `extended` |
| `main_gate` | `sealed`, `open` |

`power_route` with four states is exactly the Dungeon Authority §70 mechanism: power is a scarce allocation, routing it to the lift takes it away from security, and both consequences are real.

## 28.4 Predicated topology

Every connection between two rooms is a `TopologyEdge` (§4.9) with a `predicate` over macro state and an optional `capability`.

| Edge kind | Expression |
|---|---|
| Always open | `predicate` with one clause of one term that is always true |
| Powered door | `predicate`: `power_route IS lift` |
| One-way drop | `direction: A_TO_B`, predicate always true |
| Capability gate | `capability: capability:core:grapple` |
| Shortcut opened from the far side | `direction: A_TO_B` plus a `ROOM_PERSISTENT` shortcut flag folded into the state vector |
| Rail route | predicate derived from junction settings (§26.6) |

An edge whose predicate is false is **impassable and visibly so**: the door is shut, the bridge is retracted, the rail points elsewhere. The player can always see why they cannot go somewhere, which Dungeon Authority §49 requires.

## 28.8 Two added offer types

`macro_control` — a location a setter package may bind its control point to.
`rail_junction` — a location a rail network may place a junction.

---

# 29. CAPABILITY PROGRESSION

*Pinned: identical to Design 1 §29.1 (four capabilities), §29.2 (proof), §29.3 (entry validation), §29.4 (optional routes).*

Manipulation is **not** a capability here — physics is pinned from Design 1 and never gates (§2.1). Signal verbs are not a capability either (§14.4).

## 29.5 Capabilities inside the verifier

A `TopologyEdge` with a non-null `capability` is passable in the verifier only if that capability is in the player's proven set. Because Design 1 §29.2 permits no in-Zone capability acquisition, the proven set is **constant for the whole Zone** — it is whatever the committed Loadout provides at entry.

The verifier therefore runs once per Zone per capability set. Composition evaluates it against the *minimum* set the Zone requires, which is the set §29.3's entry validation will enforce. A player entering with more capabilities than required has strictly more edges available, so a Zone verified for the minimum set is verified for every richer set.

That monotonicity is what keeps the verification cost at one BFS rather than one per possible loadout, and it holds only because capabilities cannot be gained mid-Zone.

---

# 30. PROCEDURAL COMPOSITION

## 30.1 What Epsilon chooses

*Pinned: identical to Design 1 §30.1.* Nothing in Zone composition.

## 30.2 Zone shape

A **graph with cycles**, not a tree.

| Property | Value |
|---|---|
| Rooms | `8` to `14` |
| Edges | `10` to `22` |
| Cycles | At least `1`, at most `4` independent cycles |
| Entry, exit | One each, distinct rooms |
| Macro variables | `2` to `8` |
| Setter packages | `2` to `8`, at most one per variable per room |
| Local keys | `0` to `4` |
| **State-vector bound** | **product of all state counts ≤ `4096`** (§30.5 check 12) |

The state vector, which is what §30.6 searches, comprises:

- each macro variable's state count;
- `2` per local key, for held or consumed;
- `2` per `ENCOUNTER_GATE` flag;
- `2` per one-way shortcut flag;
- `2` per `ROOM_VISITED` sensor in use.

Their product is the `state_bound`. With `14` rooms, the product graph is at most `4096 × 14 = 57,344` nodes.

## 30.3 Composition algorithm

Deterministic given `(zone_seed, progression_state, ap_catalog)`.

```
 1. rng = seeded(zone_seed)
 2. room_count = 8 + rng.int(0, 6)
 3. Build a spanning path over room_count rooms, then add
    cycle_count = 1 + rng.int(0, 3) extra edges between non-adjacent rooms,
    then edge_count is clamped to [10, 22]
 4. Assign purposes from PURPOSE_ROTATION, forcing at least two
    control_room purposes
 5. Select shells per purpose, as Design 1 §30.3 step 4
 6. Choose variable_count = 2 + rng.int(0, 6); for each, choose a state
    count in [2,4] and a setter room from the control rooms
 7. Assign predicates to edges: each edge draws a predicate from the
    legal DNF space over the chosen variables, biased so that
    ~40% of edges are unconditional
 8. Place macro effects: each (variable, state) pair receives 1-3 effects
    in rooms other than its setter's room
 9. Place packages per room, as Design 1 §30.3 step 6, with attempt limit 12
10. Allocate Checks: check_count = clamp(room_count * 2 / 3, 5, 9)
11. Place encounters per ENCOUNTER_BUDGET
12. Place checkpoints: entry, plus every room whose shortest-path distance
    from the previous checkpoint exceeds 2 edges under the initial macro state
13. Run the state-vector bound check (§30.5 check 12)
14. RUN THE MODEL CHECK (§30.6). On failure: FAIL_ZONE
```

`PURPOSE_ROTATION` = `[traversal, control_room, arena, environmental_puzzle, junction, control_room, ranged_arena, routing_puzzle, traversal, control_room, holdout, observation_puzzle, vertical_ascent, boss_arena]`.

Step 7's `40%` unconditional bias exists because a Zone where every edge is predicated is a Zone the player cannot navigate by intuition at all. Some doors are just doors.

## 30.4 Control rooms

A `control_room` purpose hosts one `MACRO_SETTER` or `POWER_ROUTE` package and no encounter. It is the Zone's interface, and Dungeon Authority §4 lists "dungeon-state control room" as a purpose family, which this implements literally.

A control room is always reachable under the macro states from which its variable needs setting — which is property 6 of §30.6, and the check that prevents a Zone from routing power away from the only lift that reaches the room where power is routed.

## 30.5 Determinism and structural checks

*Pinned: identical to Design 1 §30.5* for the three independent RNG streams and byte-identical composition.

Design 1 §30.4's eight whole-Zone checks, plus five:

| # | Check |
|---|---|
| 1–8 | *Pinned: identical to Design 1 §30.4*, with check 1 replaced by §30.6 property 1 and check 5 removed as inapplicable — macro variables are not forward-only and are read in any direction. |
| **9** | Every `TopologyEdge` names two distinct existing rooms, and every predicate term names an existing variable and an existing state of it. |
| **10** | Every macro variable has at least one setter package, and every state of every variable is settable by at least one package. A variable with an unreachable state is a defect. |
| **11** | Every `MacroEffect` names an existing room and an existing `(variable, state)` pair. |
| **12** | The state-vector product is at most `4096`. |
| **13** | Every reachable rail-network routing terminates at a dismount point (§26.6). |

## 30.6 The model check

**The system this proposal stands on.**

Define a **configuration** as a pair `(v, r)` where `v` is the full state vector (§30.2) and `r` is a room.

Two kinds of transition:

| Transition | From → To | Legal when |
|---|---|---|
| **Move** | `(v, r) → (v, r')` | An edge joins `r` and `r'`, its predicate is true under `v`, its `capability` is in the proven set, and its direction permits `r → r'` |
| **Set** | `(v, r) → (v', r)` | A setter package in `r` can set variable `x` to state `s`, and `v' = v[x := s]`. For a monotone component — an irreversible variable, a key, an encounter flag, a shortcut, a visit flag — only the forward direction exists. |

Let `START = (v_initial, entry_room)`.

```
R = all configurations reachable from START            (forward BFS)
E = all configurations from which EXIT is reachable    (reverse BFS from every
                                                        configuration whose room
                                                        is the exit room)
```

The six properties, all required:

| # | Property | Test |
|---|---|---|
| **1** | The exit is reachable | `∃ c ∈ R` with `c.room = exit` |
| **2** | **No dead configuration** | `R ⊆ E` |
| **3** | Every Check is reachable | for each Check in room `k`, `∃ c ∈ R` with `c.room = k` and the Check's own predicate true under `c.v` |
| **4** | Every required cross-room carryable is recoverable | for each such object, its `home_transform` room is in `{c.room : c ∈ R}` for **every** `v` appearing in `R` |
| **5** | Every capability gate is proven before its first requirement | *pinned: identical to Design 1 §29.2*, evaluated over `R` |
| **6** | Every variable is settable from a reachable configuration | for each `(variable, state)`, `∃ c ∈ R` in a room whose setter can produce it |

**Property 2 is the whole thing.** It says: there is no configuration the player can reach from which they cannot finish. That is precisely what Dungeon Authority §38's "cycle-safe" and acceptance test D64's "cannot create an accidental progression cycle" demand, and it is exactly what construction gave Design 1 for free and this proposal must buy.

**Cost.** `|R| ≤ 57,344`. Outgoing transitions per configuration are at most `edges (22) + settable states (8 × 4 = 32) = 54`. Total edge traversals under `3.1M`, twice — once forward, once reverse. This is milliseconds, and it runs once per Zone at composition, never at runtime.

**On failure**, the Zone is rejected whole and retried per §30.8. The failure is logged with the seed, the failing property, and — for property 2 — **a witness**: one concrete configuration in `R \ E`, printed as its variable assignment and room. A witness makes a verification failure diagnosable rather than mysterious, and it is what turns a red composition into a five-minute fix.

## 30.7 Checkpoints

Placed per §30.3 step 12. A checkpoint activates on entry to its volume when no encounter in the room is active.

Checkpoint placement uses distance under the **initial** macro state, which is conservative: as the machine opens up, distances shorten, so a checkpoint spacing valid at the start stays valid.

## 30.8 Retry and fallback

| Failure | Response |
|---|---|
| A package fails §23.5 | Retry the package, up to 12 times, then reduce package count |
| A room fails | Retry with a different shell, up to 3 times |
| A structural check 9–13 fails | Retry the whole Zone with `zone_seed + 1`, up to 5 times |
| **The model check fails** | **Retry the whole Zone with `zone_seed + 1`, up to 5 times** |
| All retries exhausted | The certified fallback Zone (§37 fixture 19) |

The fallback Zone is authored, hand-verified, and **passes the model check by construction**: it has two macro variables, both irreversible, and a tree topology. It is a Design-1-shaped Zone, deliberately, because the guaranteed-safe fallback for a proposal built on verification should not itself depend on verification succeeding.

## 30.9 Client-side consistency

The client does not re-run the model check. On load it verifies that the composed Zone matches the bridge's record: the same room count, edge count, variable set, state counts, and predicate hashes. A mismatch is a hard error and the Zone is refused.

## 30.10 Physical authority

*Pinned: identical to Design 1 §30.8.* Geometry wins over composition claims; a room whose physical and logical truth disagree fails its audit at load.

---

# 31. CROSS-SYSTEM COMPATIBILITY

*Pinned: identical to Design 1 §31* for the full matrix, with these rows added:

| A × B | Result |
|---|---|
| Signal verb × macro setter | `PROBE` only; no verb sets a macro variable |
| Signal verb × room signal node | Per the §14.3 legality table |
| `BRIDGE` × a connection that would create a cycle | Rejected at activation; no cost spent |
| Macro effect × player inside the target room | Actuators animate; effects do not teleport |
| `HAZARD_ON` × player inside that hazard's volume | Deferred until the player leaves |
| Macro change × actuator mid-motion | Design 1 §21.1's transition table |
| Macro change × rail junction with an actor within `10 m` | Queued until clear |
| Macro state × puzzle reset | No interaction; reset never changes macro state |
| Macro state × player death | No interaction (§5.8) |
| Cross-room carryable × impassable edge | Cannot be carried across; the edge is not passable at all |
| `ROOM_VISITED` × any macro change | None; it is monotone and independent |

---

# 32. ENEMIES AND ENCOUNTERS

*Pinned: identical to Design 1 §32.1 through §32.7* — the enemy contract, six archetypes, faction behaviour, status-compatible AI, encounters and waves, death and respawn, and boss encounters.

## 32.8 Two additions

**Encounter arming.** An encounter with `ENCOUNTER_ENABLE` in a `MacroEffect` is inert until armed. An inert encounter's enemies are not spawned and its trigger volume does nothing. Arming an encounter the player is standing in spawns its first wave after a `2.0 s` delay with an audible cue, so the player is never surrounded without warning.

**Encounter flags in the state vector.** An `ENCOUNTER_GATE` package's cleared-flag is a monotone component of the verification state vector (§30.2). This is what lets a Zone say "the gantry gate opens once the hangar is cleared" and have that fact participate in the reachability proof rather than sit outside it.

---

# 33. HUD AND PRESENTATION

*Pinned: identical to Design 1 §33.1 through §33.6* — the always-visible list, feed displays (minus `CHARGE`), the three recharge treatments, device presentation, causality feedback, and the colour rules.

## 33.7 The Zone Diagram — new to Design 3

A machine the player cannot see is a machine they cannot reason about. Dungeon Authority §3.1 requires cause and effect to be spatially legible, and at Zone scale — where the lever is three rooms from the door — no amount of conduit rendering carries it. The Diagram is this proposal's answer, and it is mandatory rather than a convenience.

Opened with a long press of `Tab` (§7.5).

**What it shows:**

| Element | Rendering | Known when |
|---|---|---|
| Rooms | Nodes, labelled, positioned by authored layout | Visited, or seen from an adjacent room |
| Player position | Highlighted node | Always |
| Edges | Lines between rooms | Once traversed, or once seen from either side |
| Impassable edges | Dashed, with the predicate that would open them | Once the edge is known **and** its predicate's variables are known |
| Macro variables | A row of controls, each showing current state | Once the player has seen any setter or any effect of that variable |
| Effects of the current state | Rooms tinted by what is powered, hazardous, or lit | For known variables |
| Checks | Marked, with activated state | Once the room is visited |
| Setters | Marked on their room, with the variable they control | Once seen |

**What it never shows:** anything the player has not encountered. `diagram_known` (§4.10) tracks per-variable discovery, and an undiscovered variable does not appear, nor do the predicates that reference it — those edges render as "locked, reason unknown."

**What it never does:** the Diagram is read-only. It never sets a variable, never fast-travels, and never marks a route as correct. Discovering that routing power to the rails opens the gallery is the game; the Diagram only makes sure the player can *hold* what they have already discovered.

**Why read-only matters mechanically:** if the Diagram could set variables, every setter's room would become irrelevant and the verifier's Move transitions would be meaningless — the player could reach any configuration from anywhere. The whole model check depends on setting a variable requiring physical presence in a specific room.

## 33.8 In-world machine readability

The Diagram supplements the world; it does not replace it. Required in-world, always:

| State | Presentation |
|---|---|
| A conduit crossing a room boundary | Rendered continuing into the wall, in the same visual family on both sides |
| A powered vs unpowered room | Lighting, conduit animation, ambient audio — three channels, no reliance on hue |
| A setter's current selection | Physical position of the lever, plus a legible indicator naming the current target |
| An impassable predicated edge | The barrier is visibly a barrier of its type: a shut powered door reads differently from a retracted bridge |
| A macro change in progress | A Zone-wide audio cue and a `1.5 s` conduit propagation animation from the setter outward |

The propagation animation is presentation only — §19.8 rule 4 evaluates the machine graph instantly — but it is what makes a macro change feel like something happened to a place rather than to a variable.

---

# 34. PLAYER-FACING FLOW

*Pinned: identical to Design 1 §34.1 through §34.9, §34.10, §34.11, §34.12* under Design 1's numbering — first run, the Hub, receiving an item, Zone entry, Archive and equip, invalid-loadout messages, manual save refusal, binding conflicts, rejection feedback, leaving a Zone, the read-only in-excursion Archive, and the migration notice.

Numbered here as §34.1–§34.10 to leave room for the additions below.

## 34.11 Signal-verb rejection feedback

Added to Design 1 §34.9's table:

| Refusal | Feedback |
|---|---|
| No legal node in range | Crosshair rejection mark; any out-of-range known node pulses |
| Verb illegal on this node type | The node highlights with its type named and the legal verbs listed |
| Node not yet discovered | No target acquired at all; the node is invisible to targeting |
| `BRIDGE` would create a cycle | Both endpoints flash; the would-be edge renders struck through for `0.5 s`; no cost spent |
| `BRIDGE` second activation timed out | The first endpoint's marker fades; no cost spent |
| Signal verb aimed at a macro setter | The setter highlights with `Probe only` |

## 34.12 Macro change feedback

When the player sets a variable:

1. The prompt's `prompt_text` is echoed as a confirmation line naming the consequence.
2. The Zone-wide audio cue plays and conduits propagate outward for `1.5 s` (§33.8).
3. The Zone Diagram, if opened within `10.0 s`, opens with the changed variable highlighted and every newly-passable edge emphasised for `3.0 s`.
4. Any room the player can currently see that is affected shows its change animating.

Point 3 is the one that teaches the machine. A player who reroutes power and immediately opens the Diagram sees exactly what they just did to the Zone.

## 34.13 Load refused as unreachable

When §5.9 step 11 finds the saved player position unreachable under the saved macro state:

> **This save could not be loaded.** The recorded position is not reachable in the recorded Zone state. Your last checkpoint has been loaded instead.

The game then loads the most recent checkpoint in that Zone, which was itself written from a verified configuration. If no checkpoint exists, the Zone is re-entered from its entry room with macro state and all `ROOM_PERSISTENT` flags preserved.

This is a corruption path, not a gameplay state, and it degrades to something playable rather than refusing to load at all.

---

# 35. PERFORMANCE BUDGETS

*Pinned: identical to Design 1 §35* for every runtime budget — rigid bodies, projectiles, actuators, signal nodes, enemies, hazards, Fire Actors, deployables, and physics relations.

## 35.1 Composition-time budgets — new to Design 3

The runtime cost of this proposal is Design 1's. The cost that is new is at composition:

| Quantity | Budget |
|---|---:|
| State-vector product | `4096` |
| Rooms | `14` |
| Topology edges | `22` |
| Macro variables | `8` |
| Setter packages | `8` |
| Rail junctions per Zone | `6` |
| Rail segments per Zone | `12` |
| Product-graph nodes searched | `57,344` |
| Model-check wall-clock budget | `2.0 s` per Zone attempt |
| Total composition budget including retries | `20.0 s` per Zone |

A Zone attempt exceeding the `2.0 s` model-check budget is treated as a failure and retried with the next seed. This is a guard against a pathological predicate structure rather than an expected path; the analysis in §30.6 puts the typical cost three orders of magnitude below it.

## 35.2 Runtime cost of the machine layer

Effectively zero. The machine graph is evaluated on macro change (§19.8 rule 4), which happens a handful of times per Zone, not per tick. `MACRO_STATE` sensors are ordinary Boolean sensors reading a value that changes rarely, and event-driven signal evaluation (Design 1 §35) means an unchanging macro state costs nothing.

---

# 36. DEBUGGING AND INSPECTION

*Pinned: identical to Design 1 §36* for all fourteen inspectables, plus:

| Inspectable | Content |
|---|---|
| Macro state | Every variable, its current state, its setter rooms, and the ordinal of its last change |
| Topology | Every edge, its predicate, whether it currently evaluates true, and why |
| Machine effects | Every `MacroEffect`, whether it is currently applied, and to which room |
| Verification | The recorded model-check result: the sizes of `R` and `E`, all six properties, and elapsed time |
| **Witness replay** | For a failed property 2, the witness configuration, plus a step-by-step path from `START` to it |
| Reachability probe | From the current live configuration, the set of rooms reachable without changing macro state, and the set reachable with |
| Diagram state | Every `diagram_known` flag and what revealed it |
| Rail network | Every junction, its current branch, and the full route the player would take from each mount point |

The witness replay is the tool that makes this proposal debuggable. A property-2 failure without a path to the dead configuration is a puzzle; with one, it is a bug report.

---

# 37. REFERENCE FIXTURES

Eighteen family fixtures plus the certified fallback. Fixtures 1–14 are *pinned: identical to Design 1 §37 fixtures 1–14* for the fourteen pinned families, in the same `20 × 20 × 6 m` test shell.

The five that are Design 3's own are Zone-scale and use a **four-room test Zone** rather than a single shell: rooms `A`, `B`, `C`, `D` in a square, edges `A–B`, `B–C`, `C–D`, `D–A`, entry `A`, exit `C`.

| # | Fixture | Setup | Expected |
|---|---|---|---|
| 15 | `fx_macro_setter` | Variable `gate` with states `sealed`, `open`; setter lever in `B`; edge `B–C` predicated `gate IS open` | Throwing the lever in `B` makes `B–C` passable; the Diagram shows the change; the state survives death and reload |
| 16 | `fx_power_route` | Variable `power` with states `none`, `lift`, `security`; control terminal in `B`; `lift` powers an actuator in `D`; `security` arms hazards in `C` | Each of the three states produces exactly its recorded effects and no others; switching away from `security` disables the hazards; a player standing in a hazard when `security` is set is not damaged until they leave |
| 17 | `fx_cross_room_fetch` | `POWER_CELL` home in `A`, `allowed_volume` `{A,B,D}`; socket in `D`; edge `A–D` predicated `gate IS open`, edge `A–B–...–D` always open | The cell is carriable to `D` by either route; dropping it anywhere in `{A,B,D}` is legal; it cannot be carried through an impassable edge; property 4 holds for every reachable state |
| 18 | `fx_rail_network` | Two junctions in `B` and `D`, four segments; junction 1 set by `power IS rails`, junction 2 by a local `ROUTE_SWITCH` | All four routings terminate at a dismount point; a junction change is queued while the player is within `10 m` and applies on clear |
| 19 | `fx_fallback_zone` | The certified fallback: 8 rooms, **tree topology**, two **irreversible** variables, 4 Checks, checkpoints at rooms 1, 4, 7, no rail network, no cross-room carryables | Passes the model check by construction, with `R` and `E` equal; used whenever §30.8's retries exhaust |

Every fixture ships with an expected-state assertion file. Fixtures 15–19 additionally ship their **recorded model-check result** — the sizes of `R` and `E`, and the six property outcomes — so a regression in the verifier is caught by a diff rather than by a playthrough.

## 37.1 The adversarial fixture set

Five Zones that **must fail** verification, checked into the repo as negative tests. A verifier that passes these is broken.

| # | Fixture | The trap | Failing property |
|---|---|---|---|
| N1 | `fx_bad_one_way_trap` | A one-way drop into a wing whose only exit is predicated on a variable whose setter is outside the wing | 2 |
| N2 | `fx_bad_power_starve` | Routing power to the rails removes power from the only lift that reaches the control room | 2 |
| N3 | `fx_bad_orphan_state` | A variable with a state no setter can produce | 10, and 6 |
| N4 | `fx_bad_stranded_cell` | A required cross-room carryable whose home room becomes unreachable after a legal macro change | 4 |
| N5 | `fx_bad_rail_void` | A rail routing that terminates mid-air with no dismount point | check 13 |

N2 is the one worth dwelling on, because it is exactly the mistake Dungeon Authority §70's power-rerouting example invites and exactly the mistake a human designer makes. Property 2 catches it and the witness names the configuration.

---

# 38. TEST VECTORS

## Pinned systems
1. Every Design 1 vector covering a pinned section passes unchanged. A failure in any is a failure of a pin, not of a new system.

## Macro state
2. A Zone with `power_route` in four states permits exactly four states; a fifth is a hard error at load.
3. Setting a variable applies every matching `MacroEffect` and no others, across all 10 effect types.
4. Macro effects are idempotent: applying the same effect twice produces the state applying it once produces.
5. Macro state survives player death unchanged.
6. Macro state survives puzzle reset unchanged.
7. Macro state survives room unload, Zone exit, save, and reload.
8. A `reversible = false` variable cannot be returned to a previous state by any means.
9. Only a package in a variable's `setters` list can change it; 10,000 randomised attempts through every other system change nothing.
10. A `MACRO_STATE` sensor reads the variable within one tick of a change.
11. `HAZARD_ON` on a room where the player is inside the hazard volume defers until the player leaves, and deals no damage in the interim.
12. A macro change while the player is in the target room animates actuators at `travel_time`; while absent, it applies instantly.

## Topology
13. An edge whose predicate is false is impassable by every means, including Mobility, and is visibly a barrier.
14. A predicate of four clauses of four terms evaluates correctly against all `4096` state vectors it can be tested over.
15. A one-way edge is passable in exactly one direction.
16. A shortcut flag, once set, is monotone and appears in the state vector.
17. A rail routing change is queued while an actor is within `10.0 m` of the junction.
18. All reachable rail routings terminate at a dismount point, across 10,000 Zones.

## The model check
19. For fixture 19, `R` and `E` are equal sets and all six properties pass.
20. Each of the five adversarial fixtures N1–N5 **fails** its named property, and passes the others where applicable.
21. Property 2 failure produces a witness configuration in `R \ E`, and the recorded path from `START` reaches it.
22. Across 10,000 generated Zones, every accepted Zone satisfies all six properties, and every rejected Zone names the property it failed.
23. The state-vector product never exceeds `4096` in an accepted Zone.
24. The model check completes within `2.0 s` for every accepted Zone; a Zone exceeding it is retried, not shipped.
25. The same `(campaign_seed, zone_id)` produces a byte-identical Zone and an identical model-check result across 1,000 compositions.
26. A Zone verified for the minimum capability set remains completable with any richer set, across 10,000 Zones × 8 loadout variations.
27. Every Check in an accepted Zone is reachable (property 3), verified independently by a naive exhaustive walk on 100 sampled Zones.
28. Every required cross-room carryable's home room is reachable under every reachable state (property 4).
29. No accepted Zone contains a variable state that no setter can produce (property 6).

## Signal verbs
30. `PROBE` reveals a node's value, inputs, and predicate for exactly `magnitude` seconds.
31. `BRIDGE` requires two activations; the second beyond `10.0 s` discards the first at no cost.
32. `BRIDGE` that would create a cycle is rejected at activation with no cost spent, and the room graph remains acyclic.
33. `INVERT`, `HOLD_SIGNAL`, and `CUT` override a node's output for exactly `magnitude` seconds and revert exactly.
34. No signal verb changes any macro variable, across 10,000 randomised attempts against every node type.
35. A node the player has not discovered cannot be targeted.
36. Verb legality matches the §14.3 table exactly for every (verb, node type) pair.
37. A Zone verified without signal verbs remains completable with them: signal verbs never remove a route.
38. `HOLD_SIGNAL` on a hack terminal's output produces the hack's effect for its duration and does not complete the hack.

## Zone Diagram
39. The Diagram shows only discovered rooms, edges, and variables; `diagram_known` gates each independently.
40. The Diagram is read-only: no input within it changes any macro variable, position, or Zone state.
41. An impassable edge whose predicate references an undiscovered variable renders as "locked, reason unknown".
42. Opening the Diagram within `10.0 s` of a macro change highlights the changed variable and the newly passable edges.
43. A long press of `Tab` opens the Diagram; a short press opens the Archive; both rebind independently.

## Persistence
44. Save and load reproduces macro state exactly, and re-evaluates every predicate and effect to the same result.
45. Load with a saved position unreachable under the saved macro state loads the last checkpoint with the §34.13 message.
46. Effects re-applied on load produce the same room states as the original change sequence, for 1,000 randomised change sequences.

## Composition
47. Every accepted Zone has 8–14 rooms, 10–22 edges, at least one cycle, and 2–8 variables.
48. Every accepted Zone has at least two control rooms.
49. Roughly `40%` of edges are unconditional, ± `10` percentage points, averaged over 1,000 Zones.
50. Checkpoint spacing never exceeds 2 edges under the initial macro state.
51. Composition including retries completes within `20.0 s` per Zone.
52. When retries exhaust, fixture 19 is used and is completable.

## Presentation
53. A conduit crossing a room boundary renders continuously in the same visual family on both sides.
54. Powered and unpowered rooms are distinguishable in three channels with hue removed.
55. A setter's current selection is legible from its physical position plus its indicator.
56. A macro change plays the Zone-wide cue and the `1.5 s` propagation animation, and the animation never gates the logic.

## Client consistency
57. A client loading a Zone whose room count, edge count, variable set, state counts, or predicate hashes differ from the bridge's record refuses it as a hard error.

## Gaps closed by the §39 traceability pass
58. `ACTION` recharge advances only on the eleven facts in §12.4–12.6. `MACRO_CHANGED` advances only on a state the variable was not already in; setting a variable to its current state advances nothing. `ROOM_REVISITED` advances only on a `(room, macro state)` pair the player has not seen, so pacing a corridor accrues `0.0`.
59. A `SIGNAL_VERB` preflight that fails — no legal node in range, node undiscovered, verb illegal on that node type, or occluded — spends no resource, charge, or action progress, across all five verbs and every node type.
60. `MACRO_CHANGE_REFRESHES_COOLDOWN` cannot self-feed: setting a variable cannot advance a cooldown whose own ability caused the set, and total recharge reduction never exceeds `60%` of base. Macro changes are authored and finite, so the `LARGE` full-charge restore cannot be farmed.

---

# 39. TRACEABILITY

All 142 acceptance tests named by the two source authorities, mapped to the coverage that closes them. Notation follows Design 2 §39: `V n` is a Design 3 vector, `fx n` a Design 3 fixture, `D1 V n` / `D1 fx n` coverage reached through an explicit pin to Design 1, and **deferred** a system out of scope by §2.2.

## 39.1 Player Design Authority §35

| # | Acceptance test | Covered by |
|---|---|---|
| P1 | Empty build can move, jump, interact, melee, and defeat a basic mandatory enemy with Static Pulse. | D1 V 1 |
| P2 | Static Pulse cannot be removed from the Weapon cycle. | D1 V 2 |
| P3 | Out-of-bounds recovery returns to valid state. | D1 V 3 |
| P4 | No foreign receipt is required for the player to remain basically playable. | D1 V 4 |
| P5 | Q/E/1/2/3 activate five distinct Ability slots directly. | D1 V 12 |
| P6 | Shift activates Mobility and never ordinary sprint. | D1 V 13 |
| P7 | F never activates a generated combat Echo. | D1 V 14 |
| P8 | MMB always reaches baseline melee unless rebound. | D1 V 15 |
| P9 | R dispatches only the selected Weapon’s feed action. | D1 V 16 |
| P10 | Player-facing bindings are rebindable without changing semantic slot roles. | D1 V 17, 18 + V 43 |
| P11 | Static + three Weapon Echoes produce four valid cycle states. | D1 V 19 |
| P12 | Empty slots are skipped. | D1 V 20 |
| P13 | Switching away from a partial magazine does not refill it. | D1 V 21 |
| P14 | Switching away from Heat does not clear it. | D1 V 22 |
| P15 | Switching does not activate inactive Weapon passives. | D1 V 25 |
| P16 | A selected Weapon remains useful without another Weapon acting as mandatory primer. | D1 V 27 |
| P17 | Resource Ability cannot overspend its pool. | D1 V 35 |
| P18 | Multi-charge Cooldown recharges predictably and serially. | D1 V 36 |
| P19 | Action recharge advances only on declared facts/metrics. | V 58 |
| P20 | Failed preflight spends nothing. | V 59 |
| P21 | Post-commit miss receives no implicit refund. | D1 V 39 |
| P22 | Recharge modifiers cannot create an unbounded self-feed loop. | V 60 |
| P23 | Resource/Cooldown/Action are visibly distinguishable in HUD. | D1 V 42 |
| P24 | F activates a normal mechanism. | D1 V 82 |
| P25 | F activates an AP Check while preserving AP transaction semantics. | D1 V 48 |
| P26 | F picks up and drops/places carryables. | D1 V 83, 84 |
| P27 | Required carryable lost out of bounds recovers. | D1 V 49 |
| P28 | Carrying produces unambiguous context prompt. | D1 V 46 |
| P29 | Hacking begins through F and resolves as a room-signal input rather than bespoke door logic. | D1 V 88 |
| P30 | Eligible object can be manipulated. | D1 V 51 |
| P31 | Ineligible progression object cannot be manipulated merely because it is physically light. | D1 V 52 |
| P32 | Physics cannot self-launch the player into universal traversal. | D1 V 53 |
| P33 | Player-owned impact has a hard damage ceiling. | D1 V 57 |
| P34 | Resting/jittering props cannot repeatedly damage. | D1 V 55 |
| P35 | Optional clever sequence breaks remain possible where no semantic gate forbids them. | D1 V 91 |
| P36 | No normal gameplay path writes Health outside the damage resolver. | D1 V 58 |
| P37 | Same ordinary non-crit attack under same state gives same damage. | D1 V 59 |
| P38 | 100% crit guarantees Tier I. | D1 V 60 |
| P39 | 150% crit never produces an ordinary hit. | D1 V 61 |
| P40 | Overcrit tiers scale linearly rather than exponentially. | D1 V 63 |
| P41 | Status cannot directly or indirectly schedule periodic Health damage. | D1 V 64, 66 |
| P42 | Failed chance-based Status attempt visibly increases bounded susceptibility. | D1 V 67 |
| P43 | Successful Status application increases temporary adaptation. | D1 V 68 |
| P44 | Strong enemies can resist more without every effect becoming blanket `IMMUNE`. | D1 V 70, 71 |
| P45 | World fire may damage independently from `BURNING`. | D1 V 65 |
| P46 | Unequipped Archive hosts produce zero live listeners/reactions/resources. | D1 V 73 |
| P47 | Full loadout cannot be swapped during ordinary active combat. | D1 V 74 |
| P48 | Weapon cycling is not a full loadout swap. | D1 V 138 |
| P49 | Re-equipping an old host restores legal saved state instead of refilling it. | D1 V 75 |
| P50 | Newly introduced host cannot manufacture free readiness in an already-active Zone. | D1 V 76 |
| P51 | Mod insertion/removal at the Hub has no respec fee. | D1 V 77 |
| P52 | Only one high-tier Gear piece may be equipped across Head/Torso/Arms/Legs. | D1 V 78 |
| P53 | Hard capability gate cannot appear before guarantee. | D1 V 80 |
| P54 | Epsilon cannot invent a hard requirement. | D1 V 94 |
| P55 | GRAPPLE-required Zone verifies a usable expression is equipped before entry or supplies it before the requirement. | D1 V 96 |
| P56 | Raw DPS threshold cannot become AP reachability logic. | D1 V 95 |
| P57 | Physics/recoil may bypass optional geometry without automatically invalidating the Zone. | D1 V 91 |
| P58 | Weapon-cycle transition visibly identifies the newly selected configuration. | D1 V 97 |
| P59 | Static Pulse has recognizable neutral/home presentation. | D1 V 98 |
| P60 | Viewmodel animation/VFX cannot decide simulation outcome. | D1 V 99 |
| P61 | Physics ownership/target/relation state is visually readable. | D1 V 92 |
| P62 | A configuration with no RMB or feed mechanic does not invent meaningless filler UI. | D1 V 100 |

## 39.2 Dungeon & Environmental Gameplay Authority §71

| # | Acceptance test | Covered by |
|---|---|---|
| D1 | F operates the intended focused object when several interactables are nearby. | D1 V 45 |
| D2 | Carryable pickup/drop is predictable. | D1 V 83 |
| D3 | Placing an object in a compatible socket succeeds. | D1 V 84 |
| D4 | An incompatible object is rejected visibly. | D1 V 85 |
| D5 | The player knows what F will do in an ambiguous context. | D1 V 45, 47 |
| D6 | A plate visibly communicates its output relationship. | D1 V 101 |
| D7 | A conduit state is understandable without relying only on color. | V 53 |
| D8 | AND requires both inputs. | D1 fx 8 |
| D9 | OR accepts either input. | D1 fx 9 |
| D10 | Timed state visibly communicates remaining urgency. | D1 V 103 |
| D11 | Latch persists according to package semantics. | D1 V 108 |
| D12 | Signal reset restores initial state. | D1 V 109 |
| D13 | A powered door opens. | D1 fx 1 |
| D14 | Removing power closes safely. | D1 V 110 |
| D15 | A player in the doorway is not silently crushed by a non-hazard door. | D1 V 110 |
| D16 | A persistent shortcut remains unlocked after room revisit. | V 16 |
| D17 | A topology transformation never removes every valid progression route unintentionally. | V 19, 22 |
| D18 | Required carryable cannot be permanently lost. | D1 V 49 |
| D19 | Dropping it out of bounds restores it. | D1 V 49 |
| D20 | Destroying a replaceable required object restores it. | D1 V 86 |
| D21 | Save/load reconstructs its semantic state. | D1 V 87 |
| D22 | A weighted plate cannot be cheesed by meaningless tiny debris unless authored. | D1 V 139 |
| D23 | Required timed path is physically feasible. | D1 V 112 |
| D24 | Timing includes reasonable player variance. | D1 V 112 |
| D25 | Failure permits immediate retry. | D1 V 113 |
| D26 | Countdown is readable. | D1 V 103 |
| D27 | Mandatory shootable target works with guaranteed baseline weapon capability. | D1 V 114 |
| D28 | Invalid hits do not trigger it. | D1 V 115 |
| D29 | Target state is readable at distance. | D1 V 104 |
| D30 | Hack can enable an output. | D1 fx 7 |
| D31 | Hack can redirect a connection in a package designed for routing. | D1 fx 7 |
| D32 | Hack failure does not corrupt puzzle state. | D1 V 89 |
| D33 | Hack interaction can be exited/reset safely. | D1 V 89 |
| D34 | Powered rail state is readable. | D1 V 105 |
| D35 | Rail branch switch selects a physically valid route. | V 17, 18 |
| D36 | LaunchPad source/landing remains valid. | D1 V 116 |
| D37 | Grapple target exists within an audited grapple opportunity. | D1 V 117 |
| D38 | Moving platform does not strand required progression. | D1 V 111 |
| D39 | Hazard damage uses common damage road. | D1 V 119 |
| D40 | Hazard telegraphs before unavoidable contact where appropriate. | D1 V 140 |
| D41 | Hazard can affect enemies if package says it can. | D1 V 120 |
| D42 | Hazard controller correctly disables/enables it. | D1 V 121 |
| D43 | Reset restores hazard phase safely. | D1 V 141 |
| D44 | Reactive barrel damages valid actors. | D1 fx 12 |
| D45 | Bombable wall responds to tagged explosive. | D1 fx 12 |
| D46 | Ordinary architecture does not become arbitrarily destructible. | D1 V 122 |
| D47 | Destructible required support has recovery or alternate progression. | D1 V 123 |
| D48 | Energy ball reaches receiver on validated route. | **deferred** (§2.2) |
| D49 | Lost ball resets. | **deferred** (§2.2) |
| D50 | Reflector changes valid path. | **deferred** (§2.2) |
| D51 | Beam receiver responds continuously. | **deferred** (§2.2) |
| D52 | Moving blocker changes beam state correctly. | **deferred** (§2.2) |
| D53 | Player can enter, swim, surface, and exit. | **deferred** (§2.2) |
| D54 | Oxygen state is readable. | **deferred** (§2.2) |
| D55 | Required buoyant object behaves consistently. | **deferred** (§2.2) |
| D56 | Drain/fill state restores correctly after save/load when persistent. | **deferred** (§2.2) |
| D57 | Enemy can be killed by an environmental hazard. | D1 V 124 |
| D58 | Movable cover changes line of sight. | D1 V 125 |
| D59 | Enemy cannot permanently softlock a required plate. | D1 V 118 |
| D60 | Encounter-clear gate opens from authored encounter completion. | D1 fx 13 |
| D61 | Generator state propagates to dependent room. | V 3 |
| D62 | Cross-room state survives unload/reload. | V 7 |
| D63 | Dependency chain remains reachable. | V 22, 27 |
| D64 | Dungeon macro-state cannot create an accidental progression cycle. | V 19, 20, 22 |
| D65 | Puzzle reset affects only its declared reset group. | D1 V 129 |
| D66 | Completed AP Check is not undone by puzzle reset. | D1 V 130 |
| D67 | Persistent shortcut is not undone by local reset. | V 16 |
| D68 | Temporary projectiles and signals are cleared. | D1 V 131 |
| D69 | Critical active/inactive state is distinguishable without color alone. | V 54 |
| D70 | Required sound cue has visual equivalent. | D1 V 106 |
| D71 | A distant controlled output can be inferred from input. | V 39, 53 |
| D72 | Wrong-sequence failure communicates the error. | D1 V 107 |
| D73 | Same seed/package produces same initial composition. | V 25 |
| D74 | Decorative randomness does not alter solvability. | D1 V 81 |
| D75 | Package audit produces stable results. | V 25 |
| D76 | Inactive physics objects sleep. | D1 V 133 |
| D77 | Large room does not keep unlimited projectiles alive. | D1 V 134 |
| D78 | Beam routing has bounded complexity. | D1 V 135 |
| D79 | Signal update is event-driven where practical. | D1 V 136 |
| D80 | Debug view can identify active semantic state without inspecting scene internals manually. | D1 V 137 |

## 39.3 Coverage

| | Count |
|---|---:|
| Authority acceptance tests | 142 |
| Covered by a Design 3 test vector | 16 |
| Covered through a pin to Design 1 | 117 |
| Not applicable — system deferred by §2.2 | 9 |
| **Uncovered** | **0** |

At 16 of 133 applicable tests, Design 3 rewrites about a sixth of the acceptance surface — the least of the three proposals so far, and exactly what a design that spends its whole budget at Zone scale should look like. Its player systems are Design 1's, deliberately.

Four rows carry this proposal's headline. **D17** (a topology transformation never removes every valid progression route), **D63** (dependency chain remains reachable), and above all **D64** (dungeon macro-state cannot create an accidental progression cycle) are the tests Design 1 satisfies by construction and Design 3 satisfies by proof. **D61** (generator state propagates to a dependent room) is the one Design 1's forward-only flags could only partly express.

The nine deferred tests are D48–D52 and D53–D56. Water is the costliest deferral here: `flooded → drained` is Dungeon Authority §39's most evocative macro-variable example, and this proposal can express it only as a topology predicate over a state that no fluid simulation backs.

---

# 40. IMPLEMENTATION WAVES

| Wave | Contents | Vectors |
|---|---|---|
| 1 | Everything pinned from Design 1 waves 1–10: input, movement, damage, hosts, Weapons, Abilities, Mobility, interaction, physics, Status, Gear | 1 |
| 2 | `MacroVariable`, `ZoneState`, macro persistence and its independence from death and reset | 2, 5–9 |
| 3 | `MacroEffect` and its ten types, including the deferred-hazard rule | 3, 4, 11, 12 |
| 4 | `MACRO_STATE`, `MACRO_SELECTOR`, `ROOM_VISITED` sensors | 10 |
| 5 | `TopologyEdge`, DNF predicates, predicated passability | 13–16 |
| 6 | **The model check**: product-graph BFS, the six properties, witness generation | 19–24, 27–29 |
| 7 | The adversarial fixture set N1–N5 | 20, 21 |
| 8 | Composition: looping topology, variable assignment, predicate placement | 47–52 |
| 9 | Rail networks and multi-junction routing | 17, 18 |
| 10 | Signal verbs and their legality table | 30–38, 59 |
| 11 | The Zone Diagram, discovery gating, read-only enforcement | 39–43 |
| 12 | In-world machine readability: cross-boundary conduits, propagation animation | 53–56 |
| 13 | Save/load: macro restore, predicate re-evaluation, the unreachable-position path | 44–46 |
| 14 | Client consistency check | 57 |
| 15 | The four Zone-scale puzzle families and their fixtures | fixtures 15–18 |
| 16 | Encounter arming and encounter flags in the state vector | 58 |
| 17 | Debug: macro inspection, verification results, witness replay, reachability probe | — |
| 18 | Player-facing flow: macro feedback, signal rejections, the load-refused path | 58–60 |

**Build wave 6 before wave 8.** The model check must exist and be trusted before the composer is allowed to generate the looping Zones that need it, and wave 7's adversarial fixtures are how you establish that trust. A composer shipping unverified looping Zones is the failure mode this entire proposal exists to prevent, and it is easy to reach by building the fun part first.

Waves 2–7 are the critical path and are strictly sequential. Waves 9–12 may run in parallel once 6 is trusted. Waves 13–18 integrate.

---

# 41. CLOSURE STATEMENT

## 41.1 What this proposal decided

1. **Macro state is reversible** — up to 8 variables of 2–4 states — replacing Design 1's four forward-only Booleans. This is the decision every other decision here follows from.
2. **Zone topology loops.** A graph with 1–4 cycles, not a tree.
3. **Every room connection is predicated** on macro state, in bounded DNF.
4. **Safety is proved, not constructed.** §30.6's model check over the product of state vector and room, with property 2 — no reachable configuration from which the exit is unreachable — as the load-bearing guarantee.
5. **The state vector is bounded at 4096**, which is what makes the proof affordable at `57,344` product-graph nodes and milliseconds per Zone.
6. **The machine graph has no logic and cannot be written by room graphs.** Both restrictions exist to keep the state space finite and small.
7. **Signal verbs are never required** and cannot touch macro state, so verification runs as if the player has none.
8. **The Zone Diagram is mandatory and read-only.** Read-only is not a UX preference: if it could set variables, physical presence would stop mattering and the model check would be meaningless.
9. **Macro state ignores death and reset.** The Zone is the machine; the player's death is not an event in it.
10. **Rail networks reroute** — up to 6 junctions and 12 segments, with every reachable routing proven to terminate.
11. **Cross-room carryables** exist, with a `ZONE_PERSISTENT` category and a verifier property protecting them from being stranded.
12. **Five adversarial fixtures** that must fail verification, checked in as negative tests.
13. **A witness is produced on failure** — the concrete dead configuration and a path to it — which is what makes this debuggable.
14. **Capability monotonicity** (§29.5) keeps verification at one BFS rather than one per loadout, and holds only because capabilities cannot be gained mid-Zone.
15. **The fallback Zone is Design-1-shaped**: tree topology, irreversible variables. The safety net for a verification-dependent proposal does not itself depend on verification.

## 41.2 What this proposal sacrificed

| Sacrifice | What is lost |
|---|---|
| **Player build depth** | The leanest loadout of the five: five Weapon families, eight Abilities, four physics primitives, four Statuses, no `TEMPORARY_RULE`, no healing, no turrets. Combat is competent and unremarkable, on purpose. |
| **Water** | The costliest deferral here. `flooded → drained` is Dungeon Authority §39's best macro example and this proposal can only fake it as a predicate. |
| **Directional and variable gravity** | `gravity state A → B` is a named §39 macro example this proposal cannot build at all. |
| **Constraint simulation** | Design 2 ships it; this does not. Cranes do not swing. |
| **Signal builds that change access** | A signal build makes a Zone easier and never opens a route that matters. That is the price of verifying without them, and it makes an entire Ability family strictly optional. |
| **Composition speed** | Up to `20 s` per Zone against Design 1's fraction of a second. Generation is a background job, not something to do while the player waits. |
| **Zone count** | Fewer, longer, denser Zones. A campaign has fewer distinct places. |
| **Simple debugging** | When a Zone is rejected, understanding *why* requires reading a witness path through a state machine. The tooling in §36 exists because without it this is undebuggable. |
| **Two puzzle families** | `BOMB_BARRIER` and `OBSERVATION_TARGET` cut for budget. |
| **Forge** | *Pinned from Design 1.* |

## 41.3 Proposal-level choices the authorities did not mandate

- The `4096` state bound, and every budget derived from it.
- Bounded DNF rather than arbitrary predicate expressions.
- Macro state surviving death and reset untouched.
- Signal verbs being excluded from verification rather than modelled in it.
- The Diagram being read-only.
- The long-press `Tab` binding.
- `40%` of edges unconditional.
- The fallback Zone being deliberately un-machine-like.
- Verification running in the bridge only, with the client checking consistency rather than re-verifying.

## 41.4 Where this proposal disagrees with an authority

**Nowhere.** It is the proposal that most directly *implements* an authority section — Dungeon Authority §38, §39, and §70 — rather than deferring it.

The one thing worth flagging: Dungeon Authority §39 lists `gravity state A → B` among its macro-state examples, and §2.2 defers directional and variable gravity. That is a deferral of a named example, recorded in §2.2 and §41.2, not a contradiction — §39 says a macro state *may* affect those things, and this proposal implements seven of the eight examples it lists.

If a reader finds a contradiction, it is a defect in this document and should be reported rather than resolved locally (§1.3).

## 41.5 The claim

**Every acceptance test named by the two source authorities is covered.** §39 maps all 142: 16 to a Design 3 vector, 117 through an explicit pin to Design 1, 9 to a recorded deferral. None is uncovered.

**There are no intentionally open behavioral decisions in this proposal.**

Anything not described here is one of:

- pinned to a named Design 1 section, which is itself closed;
- inherited unchanged from the two source authorities, and listed in §1;
- rejected by a closed schema in §4;
- explicitly deferred in §2.2, with its cost stated;
- an engineering decision that belongs to the implementer.

**And one thing more, specific to this proposal:** every generated Zone carries a proof. If a shipped Zone contains a dead configuration, that is not a design gap to be argued about — it is a verifier bug, it is reproducible from the seed, and §36's witness replay will name the exact configuration. That is the trade this proposal makes: a much harder generator, in exchange for a class of failure that becomes impossible rather than unlikely.

---

**End of Complete Design 3: The Dungeon Is One Machine**
