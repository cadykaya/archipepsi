# ARCHIPEPSI — COMPLETE DESIGN 1: RELIABLE CORE

## Conservative resolution of the Player and Dungeon authorities

**Status:** Complete alternative proposal. Not canon until selected by the owner.
**Proposal:** 1 of 5
**Design thesis:** Prefer a finite, typed, observable implementation over a broader simulation. Every systemic feature gets a closed catalog rather than a general mechanism.
**Target:** Godot 4.5 client plus the existing Python/Pydantic bridge.
**Source authorities:** `docs/authorities/PLAYER_DESIGN_AUTHORITY_v1.0.md`, `docs/authorities/DUNGEON_ENVIRONMENT_AUTHORITY_v0.1.md`
**Written against:** `docs/design-proposals/00_ZERO_GUESSWORK_STANDARD.md`

### Proposal profile

| Axis | Rating |
|---|---:|
| Novelty | 2 / 5 |
| Player-build variety | 4 / 5 |
| Environmental breadth | 3 / 5 |
| System interaction depth | 3 / 5 |
| Implementation risk | 2 / 5 |
| Procedural validation difficulty | 2 / 5 |
| Reuse of current repo foundations | 5 / 5 |

**Principal tradeoff:** Reliable Core preserves the identity of the game by narrowing how each idea is expressed. Where the authorities describe a capability, this proposal supplies a closed list of the forms that capability may take. It defers the systems most likely to multiply physics, persistence, and procedural-validation failures — and it defers them cleanly rather than shipping them half-built.

**Who should pick this:** an owner who wants the game shipping, correct, and extensible, and who is willing to trade "the generator can surprise me" for "the generator cannot produce something broken."

---

# 0. PURPOSE

This document resolves every open decision in the two source authorities into a form an implementing agent can build without inventing behavior, choosing between plausible interpretations, or silently inheriting an unspecified contract.

It is written to the Zero-Guesswork Standard. Concretely, that means:

- Every number the player can perceive the effect of has a value here. Those values are starting values; the tuning pass owns changing them. It does not own inventing them.
- Every failure path terminates in a specified state.
- Every persisted object has an exact serialized shape.
- Every generator decision draws from a closed set defined in this document.

It does **not** specify class layout, node hierarchy, file organization, or algorithm choice. Those belong to the implementer.

Where this document says "exactly", "always", "never", or gives a number, that is a contract. Where it says "may", the surrounding text names the closed set being selected from and the default when nothing is selected.

---

# 1. INHERITED LAWS

These come from the source authorities. This proposal does not reopen them, and no section below contradicts them. They are restated here so an implementer never has to hold three documents open at once.

## 1.1 From the Player Design Authority

1. A permanent baseline exists: movement, jump, interaction, Static Pulse, baseline melee, menus, and out-of-bounds recovery can never be removed by any mechanism.
2. Inputs describe roles, not generated content. Epsilon never decides which key an Echo uses.
3. One Epsilon device. Weapon Echoes are configurations of it, not separate carried guns.
4. Static Pulse is always selectable in the Weapon cycle.
5. Up to three equipped Weapon Echo configurations. The cycle is Static Pulse plus those three.
6. Each Weapon Echo must stand alone. Mandatory priming is rejected as an architecture.
7. LMB is the active Weapon's primary. RMB is the active Weapon's secondary or intrinsic.
8. Five direct Ability slots: Q, E, 1, 2, 3.
9. One dedicated Mobility slot: Shift.
10. `F` is universal world interaction and can never be taken by generated combat content.
11. `R` is the active Weapon's feed action.
12. Permanent baseline melee, default MMB.
13. No dedicated Signature or Ultimate slot in v1. Key `4` is unassigned.
14. No baseline sprint or stamina.
15. No baseline crouch or slide.
16. No persistent conventional ammunition scarcity. Magazine reserve is effectively infinite.
17. `RESOURCE`, `COOLDOWN`, and `ACTION` recharge identities all exist. Readiness and Cost remain conceptually distinct.
18. Only controlled, typed recharge hybrids. No Boolean scripting language.
19. Runtime resources are not AP currency or AP items.
20. Physics Echoes are bounded manipulation, never universal movement or dominant damage.
21. Ordinary `F` carryables never secretly require a Physics Echo.
22. One damage road. Nothing writes Health outside the damage resolver.
23. No random base-damage variance.
24. No elemental or resistance matrix as the core damage model.
25. Linear overcrit tiers.
26. Chance-based Status with visible pity and adaptation.
27. **A Status never directly or indirectly deals periodic damage.**
28. Four Gear slots: Head, Torso, Arms, Legs.
29. Exactly one high-tier Gear piece may be equipped across those four.
30. Mods may meaningfully transform hosts.
31. Loadout experimentation is free at safe boundaries. No respec tax.
32. The full loadout is committed for the duration of an excursion.
33. Only equipped hosts are runtime-active.
34. **NO REQUIREMENT BEFORE GUARANTEE.** A hard capability gate is legal only where the planner proves the capability is available before the requirement.
35. Raw DPS is never progression truth.
36. Optional sequence breaking is welcome.
37. Epsilon never authors executable mechanics or keybinds.

## 1.2 From the Dungeon & Environmental Gameplay Authority

38. Cause and effect are spatially legible. Hidden relationships are permitted only where discovering the relationship is the intended challenge.
39. Simulation owns truth; presentation explains truth. Missing VFX may hurt readability but never changes a mechanism.
40. Epsilon composes from validated truths and never invents physics constants, launch arcs, signal graphs, collision semantics, capabilities, AP truth, timing windows, or unrecoverable objects.
41. Environmental verbs cross-pollinate through explicit compatibility contracts, not ad hoc exceptions.
42. **No softlocks.** Every required package is naturally recoverable or provides explicit recovery.
43. A room remains a place, not a circuit diagram.
44. The foundational causal model is `INPUT → SIGNAL → OUTPUT`.
45. Local dungeon keys are not AP items. Environmental systems may gate or reveal Checks but never manufacture AP progression truth.
46. Critical state is never communicated by a single channel, and never by color alone.
47. Composition is deterministic from a seed. Decorative randomness never alters solvability.
48. Physical geometry is the final authority for physical claims.

## 1.3 Precedence

Where this document and a source authority appear to conflict, the source authority wins and the conflict is a defect in this document. Report it rather than resolving it locally.

Where this document is silent, it is not silent by permission. Silence is a defect. See §40.

---

# 2. SCOPE

## 2.1 Ships in Reliable Core

**Player**

- Full final control grammar and rebinding.
- Base movement with the exact constants in §6.
- Static Pulse and baseline melee.
- Eight Weapon primary families, five secondary kinds, four feed models.
- Twelve Ability families across four activation forms and three recharge identities.
- Five Mobility families.
- Four Physics primitives: `PUSH`, `PULL`, `HOLD`, `ALIGN`.
- Six Statuses, none of which deal damage.
- Four Gear slots with territory-constrained intrinsics; five Mod families.
- Full damage road with Defense, Barrier, and linear overcrit.
- Interaction, carryables, and sockets.
- Complete active-build projection with cold-introduction rules.

**Dungeon**

- Acyclic typed signal graph with eleven node types.
- Nine input and sensor types.
- Nine actuator families.
- One reusable hacking minigame.
- Eighteen puzzle package families, each with a runnable reference fixture.
- Six hazard families, four destructible classes.
- Wind, conveyors, power, and player rails.
- Forward-only Zone flags for dungeon-scale state.
- Deterministic linear Zone composition over authored shells.
- Four semantic capability gates.

**Infrastructure**

- Exact schemas for every persisted and generated object.
- Five persistence categories with reconstruction order.
- Enemy and encounter contract.
- Performance budgets and debug inspection.
- Eighty-one test vectors with concrete inputs and expected outputs.

## 2.2 Explicitly deferred

Each deferral is a decision. The cost column is what the game loses by taking it.

| Deferred system | Cost of deferring |
|---|---|
| Forge | No player-directed item synthesis. Foreign items accumulate as Mods with no conversion path; Epsilon Static banks with no sink. The Archive grows monotonically. |
| Water, swimming, buoyancy, fill/drain | Removes an entire traversal medium and the Dungeon Authority's Slice 5. Shallow non-swimmable water remains legal as a movement-slowing volume. |
| Energy balls and reflector beams | Removes the two routing puzzle families the Dungeon Authority names first. `ENERGY_ROUTE` and `BEAM_RECEIVER` are not among the eighteen shipped families. |
| Physics constructs | Physics rearranges only; it never creates matter. Removes construct-launcher Weapons and construct-spawning Abilities. |
| Dynamic joints: ropes, chains, pulleys, counterweights, pendulums | All machinery is kinematic. Removes the Dungeon Authority's §11 constraint families. Cranes and lifts still work; they are animated along authored paths rather than simulated. |
| Portals and teleporters | No space folding. Zone topology is strictly physical. |
| Gases, smoke, steam, pressure, temperature | Removes a hazard and readability channel. Fire remains as an Actor with a damage volume. |
| Advanced and directional gravity | Global gravity is a single constant. Removes low-gravity regions and reorienting architecture. |
| Programmable logic | The signal graph is authored and acyclic. Players reconfigure routes through `SELECTOR` nodes and hacking, never by writing logic. |
| Rotating whole rooms | Rotating machinery within a room ships; rotating the room does not. |
| In-Zone loadout stations | Loadout editing is Hub-only, as the Player Authority specifies for v1. |

**Deferral means:** the system is absent, its data shapes are not defined, and no partial implementation exists. It is not stubbed, not flagged off, and not half-present in a schema. Adding it later is a new implementation wave against an amended authority.

## 2.3 Removed rather than deferred

These are rejected outright by the Player Authority §30 and are recorded here so a future pass does not rediscover them as options: three unrelated physical guns; primer rotation as the default architecture; elemental/status damage soup; Status DoT; deterministic universal Status buildup; one universal Ability cooldown model; one universal mana bar; arbitrary hybrid recharge expressions; persistent bullet scarcity; sprint/stamina; a dedicated Signature slot; unlimited mid-combat Archive swapping; respec tax; armor score and item level; physics as telekinesis, as primary movement, or as dominant damage; arbitrary runtime mesh construction; AP-delivered Epsilon Static as ammo or mana; bespoke interaction keys per dungeon verb.

## 2.4 What "v1" means here

One shippable game containing: a Hub, generated Zones over authored shells, the full player build system, the dungeon vocabulary above, and Archipelago integration. It is not a demo and not a vertical slice.

---

# 3. AUTHORITY AND DATA OWNERSHIP

Three systems hold truth. Every value in this document belongs to exactly one of them.

## 3.1 Bridge authority (Python / Pydantic)

The bridge owns:

- The catalogs. Every family, template, and profile named in this document is bridge data.
- Interpretation. Turning a foreign AP item into an Archipepsi definition.
- Validation. A definition that fails bridge validation never reaches the client.
- Zone composition. Room selection, package assignment, Check allocation, capability placement.
- Capability proof. The `NO REQUIREMENT BEFORE GUARANTEE` planner.
- AP transaction state.

The bridge never simulates gameplay. It never computes damage, resolves a hit, or decides whether a jump is physically possible — it consults the movement law in §6.2 for reachability, which is a shared constant table, not a simulation.

## 3.2 Godot authority (client)

The client owns:

- All simulation: movement, collision, damage resolution, signal evaluation, machinery motion, Status resolution.
- Physical truth. If the bridge claims a gap is crossable and the geometry disagrees, the geometry wins and the Zone fails its audit.
- Presentation.
- Local runtime state.

The client never invents a definition. It receives validated definitions and executes them.

## 3.3 Epsilon authority (the language model)

Epsilon may choose, per interpretation, from the closed sets in this document:

| Epsilon may choose | Epsilon may never choose |
|---|---|
| Which host category an item becomes | Any numeric gameplay value |
| Which family within that category | Any keybind |
| Which named **profile** the family uses (§4.6) | A new family, profile, or Status |
| Display name and flavor text | A capability requirement |
| Which cosmetic accent set applies | Whether an item is progression |
| Which of the family's legal Statuses it applies, if any | Anything about Zone composition |

**The critical rule:** Epsilon selects a profile ID from a list. It does not emit numbers. A profile is a named, pre-balanced bundle of every value the family needs — the deterministic resolver in the bridge expands the profile ID into the full parameter set. This is the difference between "Epsilon can make a weird gun" and "Epsilon can balance the game", and Reliable Core takes only the first.

If Epsilon is unavailable, the bridge assigns profiles by the deterministic fallback in §17.5. The game is fully playable with the model offline.

## 3.4 Stable identifiers

Every generated or authored object carries a stable ID.

```
Format:   <kind>:<namespace>:<slug>[@<rev>]
Kinds:    weapon ability mobility gear mod status shell room package
          node object hazard enemy encounter zone profile capability
Namespace: "core" for authored content, "gen" for interpreted content
Slug:     ^[a-z0-9_]{1,48}$
Rev:      positive integer, omitted when 1
```

Examples: `weapon:core:static_pulse`, `ability:gen:a7f3c1e0`, `shell:core:yard_gantry`, `profile:core:cadence_rapid`.

Rules:

- An ID is permanent. Content is never re-slugged.
- A generated slug is the first 8 hex characters of a SHA-256 over `(campaign_seed, ap_item_id, host_category)`. Collisions append `_2`, `_3`, and so on, checked against the Archive at insertion.
- `@rev` increments when a **definition's mechanical content changes** while its identity is preserved. Only migration (§17.4) does this.
- The client rejects any ID not matching the format. Rejection is a hard error at load, not a silent skip.

## 3.5 Validation behavior

Validation runs at three points with three different outcomes.

| Point | On failure |
|---|---|
| Interpretation (bridge, per item) | Definition is rejected. The item becomes the deterministic fallback for its category (§17.5). The rejection is logged with the failing rule. The player is never shown an error. |
| Zone composition (bridge, per Zone) | Composition retries per §30.7. On exhaustion, the certified fallback Zone (§37 fixture 19) is used. |
| Load (client, per definition) | Hard error. The client refuses to enter the Zone and reports which ID failed which rule. This is a bug, not a gameplay state. |

A definition never partially loads. There is no "load what works" path.

---

# 4. SCHEMAS

Every shape below is the serialized contract. Field order is irrelevant. Unknown fields are a hard error at load; this is deliberate, so that a definition written against a newer catalog fails loudly rather than losing behavior silently.

Types are given as `name: type = default`. `?` marks nullable. Absent non-nullable fields with no default are a hard error.

## 4.1 Common

```
Id            : string matching §3.4
Seconds       : float >= 0.0
Meters        : float >= 0.0
Damage        : float >= 0.0
Chance        : float in [0.0, 1.0]
MassClass     : enum { LIGHT, MEDIUM, HEAVY, FIXED }
DamageTag     : enum { RANGED, MELEE, PROJECTILE, BEAM, EXPLOSIVE,
                       PHYSICS, FIRE, ENVIRONMENTAL }
Faction       : enum { PLAYER, HOSTILE, NEUTRAL }
```

## 4.2 Host definition (common to all equipped things)

```
HostDefinition:
  id                : Id
  category          : enum { WEAPON, ABILITY, MOBILITY, GEAR }
  tier              : enum { USEFUL, HIGH }
  display_name      : string, 1..48 chars
  flavor_text       : string, 0..280 chars = ""
  provenance        : Provenance
  mod_capacity      : int          # derived: USEFUL=2, HIGH=4. Stored for audit.
  mods              : list[Id] = []          # length <= mod_capacity
  accent_set        : Id = "accent:core:neutral"

Provenance:
  source_game       : string, 1..64 chars
  source_item       : string, 1..128 chars
  source_player     : string, 0..64 chars = ""
  ap_item_id        : int? = null            # null for authored content
  received_at       : int                    # campaign event ordinal, >= 0
  interpretation_by : enum { EPSILON, FALLBACK, AUTHORED }
```

`mod_capacity` is derived from `tier` and duplicated into the record so a save can be audited without re-deriving. A record whose `mod_capacity` disagrees with its `tier` is a hard error at load.

## 4.3 Weapon

```
WeaponDefinition (extends HostDefinition, category = WEAPON):
  primary           : WeaponAction
  secondary         : WeaponAction? = null
  feed              : FeedSpec
  view_modules      : list[Id], length 3..6

WeaponAction:
  family            : enum { HITSCAN_SINGLE, HITSCAN_BURST, HITSCAN_SPREAD,
                             PROJECTILE_DIRECT, PROJECTILE_LOB,
                             BEAM_CONTINUOUS, CHARGE_RELEASE_SHOT, CLOSE_ARC }
  profile           : Id                     # profile:core:*, see §4.6
  status_applied    : Id? = null             # status:core:*, or null
  status_chance     : Chance = 0.0           # must be 0.0 when status_applied is null
  crit_eligible     : bool = true

FeedSpec:
  model             : enum { MAGAZINE, HEAT, CHARGE, NONE }
  profile           : Id                     # profile:core:feed_*
```

Secondary families are constrained separately in §11.2; the `WeaponAction.family` enum above is the primary set. A secondary uses `SecondaryAction` instead:

```
SecondaryAction:
  kind              : enum { ZOOM, ALT_FIRE, GUARD, DETONATE, MODE_SWAP }
  profile           : Id
  alt_action        : WeaponAction?  = null  # required iff kind == ALT_FIRE, else must be null
```

## 4.4 Ability and Mobility

```
AbilityDefinition (extends HostDefinition, category = ABILITY):
  family            : enum { PROJECTILE_ATTACK, AREA_BURST, BARRIER_GRANT,
                             HEAL_CHANNEL, DEPLOYABLE_TURRET, DEPLOYABLE_FIELD,
                             STATUS_APPLICATOR, MARK_REVEAL, PHYSICS_VERB,
                             DASH_IMPULSE, WEAPON_BUFF, TEMPORARY_RULE }
  activation        : enum { PRESS, HOLD, CHARGE_RELEASE, CHANNEL }
  recharge          : RechargeSpec
  profile           : Id
  status_applied    : Id? = null
  status_chance     : Chance = 0.0
  physics_primitive : enum { PUSH, PULL, HOLD, ALIGN }? = null
                      # required iff family == PHYSICS_VERB, else must be null

MobilityDefinition (extends HostDefinition, category = MOBILITY):
  family            : enum { DASH, GRAPPLE, BLINK, BURST_JUMP, AIR_STEP }
  recharge          : RechargeSpec
  profile           : Id
  grants_capability : Id? = null             # capability:core:*, see §29.1

RechargeSpec:
  identity          : enum { RESOURCE, COOLDOWN, ACTION }
  profile           : Id                     # profile:core:recharge_*
  hybrid            : HybridSpec? = null

HybridSpec:
  template          : enum { KILL_ACCELERATES_COOLDOWN, ACTION_DISCOUNTS_RESOURCE,
                             ACTION_PROGRESS_DECAYS, OVERCRIT_GENERATES_RESOURCE,
                             MOVEMENT_ADVANCES_COOLDOWN }
  magnitude         : enum { SMALL, MEDIUM, LARGE }
```

The `(family, activation, recharge.identity)` triple must appear in the compatibility matrix in §12.9. A triple absent from that matrix is a hard error at load, not a silently-accepted combination.

## 4.5 Gear, Mod, Status

```
GearDefinition (extends HostDefinition, category = GEAR):
  territory         : enum { HEAD, TORSO, ARMS, LEGS }
  intrinsics        : list[Intrinsic], length 1 if tier == USEFUL, 2 if tier == HIGH

Intrinsic:
  template          : Id                     # intrinsic:core:*, catalog in §16.1
  magnitude         : enum { SMALL, MEDIUM, LARGE }

ModDefinition:
  id                : Id
  family            : enum { AUGMENT, REPLACEMENT, TRIGGER, PASSIVE, CONVERSION }
  template          : Id                     # mod:core:*, catalog in §16.2
  magnitude         : enum { SMALL, MEDIUM, LARGE }
  host_categories   : list[enum { WEAPON, ABILITY, MOBILITY, GEAR }], length >= 1
  provenance        : Provenance
  rank              : int >= 1 = 1           # consolidated duplicate count
  trap_flavor       : bool = false

StatusDefinition:
  id                : Id                     # exactly the six in §15.1
  family            : enum { THERMAL, KINETIC, COGNITIVE }
  base_duration     : Seconds
  base_chance       : Chance
  stacks            : false                  # always false in Reliable Core
```

**Gear intrinsic count is settled here:** `USEFUL` Gear has exactly one intrinsic; `HIGH` Gear has exactly two. The salvaged reference draft contradicted itself on this point. There is one rule and it is the length constraint on `intrinsics` above.

## 4.6 Profiles

A profile is a named, pre-balanced parameter bundle. It is the mechanism by which Epsilon expresses an idea without touching a number.

```
Profile:
  id                : Id                     # profile:core:<slug>
  applies_to        : list[string]           # family names this profile is legal for
  params            : map[string, float | int | bool | string]
```

Rules:

- Profiles are authored. Epsilon never creates one.
- A profile is legal for a family only if the family name appears in `applies_to`. Selecting an illegal profile is rejected at interpretation.
- Every parameter a family reads must be present in every profile legal for it. A missing parameter is a hard error at catalog load, caught in CI, not at runtime.
- Profile parameter values are the tuning surface. Changing them is a balance pass. Adding or removing a parameter is a schema change.

The complete profile catalog is given inline with each family: §11.1 (weapon primaries), §11.2 (secondaries), §11.3–11.6 (feeds), §12.1 (abilities), §12.4–12.6 (recharge), §13.1 (mobility), §14.3 (physics).

## 4.7 Loadout

```
Loadout:
  weapons           : list[Id?], length exactly 3     # null = empty slot
  abilities         : map[enum { Q, E, ONE, TWO, THREE }, Id?]   # all five keys present
  mobility          : Id? = null
  gear              : map[enum { HEAD, TORSO, ARMS, LEGS }, Id?] # all four keys present
  committed_at      : int? = null     # campaign event ordinal at excursion start
```

Validity rules, all checked at commit and at load:

1. Every non-null ID exists in the Archive.
2. No ID appears twice across the entire Loadout.
3. Each `gear` entry's `territory` matches its map key.
4. At most one equipped host across all categories has `tier == HIGH` **within Gear**; Weapons, Abilities, and Mobility have no high-tier restriction (Player Authority §21.3, §21.4).
5. Each host's `mods` list length is at most its `mod_capacity`, and every Mod's `host_categories` includes that host's `category`.
6. Static Pulse is never present in `weapons`; it is implicit and always available.

A Loadout failing any rule cannot be committed. The Hub UI blocks commit and names the failing rule (§34.6).

---

# 5. LIFECYCLE AND PERSISTENCE

## 5.1 The five categories

Every piece of state belongs to exactly one category. The category determines what survives each boundary.

| Category | Death | Room unload | Zone exit | Save/load | Later revisit |
|---|---|---|---|---|---|
| `EPHEMERAL` | Discarded | Discarded | Discarded | Not written | Rebuilt from initial |
| `PUZZLE_LOCAL` | Reset to group initial | Preserved | Discarded | Written | Rebuilt from initial |
| `ROOM_PERSISTENT` | Preserved | Preserved | Preserved | Written | Restored |
| `ZONE_PERSISTENT` | Preserved | Preserved | Preserved | Written | Restored |
| `AP_PERSISTENT` | Preserved | Preserved | Preserved | Written by bridge | Restored |

## 5.2 Category assignment

This table is exhaustive for Reliable Core. State not listed here does not exist.

| State | Category |
|---|---|
| Projectiles, beams, VFX, audio | `EPHEMERAL` |
| Timed button remaining time | `EPHEMERAL` |
| Enemy positions and health | `EPHEMERAL` |
| Carryable position and carry state | `PUZZLE_LOCAL` |
| Socket occupancy | `PUZZLE_LOCAL` |
| Lever and latch state | `PUZZLE_LOCAL` |
| Machinery position along its path | `PUZZLE_LOCAL` |
| Destructible object destroyed-flag | `PUZZLE_LOCAL` |
| Sequence node progress | `PUZZLE_LOCAL` |
| Encounter cleared-flag | `ROOM_PERSISTENT` |
| One-way shortcut opened-flag | `ROOM_PERSISTENT` |
| Local key collected-flag | `ROOM_PERSISTENT` |
| Secret discovered-flag | `ROOM_PERSISTENT` |
| Checkpoint reached-flag | `ROOM_PERSISTENT` |
| Zone flags (§28.3) | `ZONE_PERSISTENT` |
| Player Health at checkpoint | `ZONE_PERSISTENT` |
| Host runtime state (§5.6) | `ZONE_PERSISTENT` |
| Check activated | `AP_PERSISTENT` |
| Items received, Archive contents | `AP_PERSISTENT` |
| Coins, Signal Keys, Epsilon Static | `AP_PERSISTENT` |
| Committed Loadout | `AP_PERSISTENT` |

## 5.3 Snapshot cadence

A save is written on: Zone entry, Zone exit, checkpoint activation, Check activation confirmation, Hub loadout commit, and manual save. It is **not** written continuously and not on a timer.

Consequence, stated so it is a decision rather than a surprise: a crash mid-room loses progress back to the last checkpoint. Checkpoints are placed by §30.6 at a density that bounds this loss to one room.

## 5.4 Death

On player death:

1. Every `EPHEMERAL` object is destroyed.
2. Every `PUZZLE_LOCAL` reset group in the current room resets to its initial state, in the order defined in §23.4.
3. `ROOM_PERSISTENT`, `ZONE_PERSISTENT`, and `AP_PERSISTENT` state is untouched.
4. The player respawns at the most recent checkpoint with Health restored to 100 and Barrier 0.
5. **Host runtime state is preserved exactly.** Cooldowns keep their remaining time. Resource pools keep their current values. Magazines keep their current rounds. Heat keeps its current value. Action progress keeps its accumulated count.

Point 5 is the anti-exploit rule (Player Authority §29.4). Dying is a full Health restore and nothing else. It is never the cheapest way to refill anything. A build that spends its whole resource pool and dies wakes up with an empty pool.

Health is the single exception because a death that did not restore Health would be an unrecoverable state.

## 5.5 Room unload and reload

A room unloads when the player is more than 1 room away along the Zone spine. On unload, `EPHEMERAL` state is destroyed and `PUZZLE_LOCAL` state is serialized to memory. On reload, `PUZZLE_LOCAL` state is restored, then `EPHEMERAL` state is rebuilt from initial.

Enemies do not persist. A room reloaded after unload respawns its encounter **only if** the encounter's cleared-flag is false. A cleared encounter never respawns.

## 5.6 Host runtime state

```
HostRuntimeState:
  host_id           : Id
  resource_current  : float?  = null    # present iff recharge.identity == RESOURCE
  cooldown_charges  : int?    = null    # present iff identity == COOLDOWN
  cooldown_elapsed  : Seconds? = null   # present iff identity == COOLDOWN
  action_progress   : float?  = null    # present iff identity == ACTION
  magazine_rounds   : int?    = null    # present iff feed.model == MAGAZINE
  heat_current      : float?  = null    # present iff feed.model == HEAT
  introduced_cold   : bool    = false
```

A host's runtime state is created when the host first becomes active in a Zone and destroyed when the Zone's `ZONE_PERSISTENT` state is discarded.

## 5.7 Cold introduction

A host that has never been active in the current Zone instance is introduced **cold**:

| Field | Cold value |
|---|---|
| `resource_current` | `0.0` |
| `cooldown_charges` | `0` |
| `cooldown_elapsed` | `0.0` |
| `action_progress` | `0.0` |
| `magazine_rounds` | `0` |
| `heat_current` | `0.0` |
| `introduced_cold` | `true` |

A host that **has** been active in this Zone instance restores its saved state exactly.

Because Reliable Core is Hub-only for loadout editing, cold introduction happens in exactly one situation: the player commits a new Loadout at the Hub and re-enters a Zone they have partially completed. This is the case the rule exists for, and it is why the rule cannot be dropped as unreachable.

## 5.8 Fresh Zone readiness

On a Zone's **first** activation — the first time the player enters a given Zone instance — every equipped host begins in its authored ready state:

| Field | Fresh value |
|---|---|
| `resource_current` | profile's `resource_max` |
| `cooldown_charges` | profile's `charge_count` |
| `cooldown_elapsed` | `0.0` |
| `action_progress` | `0.0` |
| `magazine_rounds` | profile's `magazine_capacity` |
| `heat_current` | `0.0` |
| `introduced_cold` | `false` |

Both this table and the cold table in §5.7 apply **only to fields that are present** for the host, per the `present iff` conditions in §5.6. A `NONE`-feed Weapon has no `magazine_rounds` field to set; a `COOLDOWN` Ability has no `resource_current`. Setting an absent field is a hard error, not a no-op.

`action_progress` starts at zero even on a fresh Zone. An `ACTION` ability's readiness is earned by doing its verb; there is no free first use. This is deliberate and is the one asymmetry between the three identities — `RESOURCE` and `COOLDOWN` start full because their recharge is passive, `ACTION` starts empty because its recharge is the gameplay.

## 5.9 Save/load reconstruction order

A load reconstructs in exactly this order. Order matters because later steps read earlier state.

1. AP state: Archive, Coins, Signal Keys, Epsilon Static, Check flags.
2. Committed Loadout. Validate per §4.7; a failure here is a hard error.
3. Zone identity and seed. Recompose the Zone deterministically (§30.5). The composition must reproduce byte-identically; a mismatch is a hard error.
4. Zone flags.
5. Per-room `ROOM_PERSISTENT` flags.
6. Apply Zone flags to machinery initial states (§28.3).
7. Per-room `PUZZLE_LOCAL` state for the entry room and its immediate neighbors.
8. Host runtime state.
9. Player transform and Health.
10. Rebuild `EPHEMERAL` state.

## 5.10 Mid-transition machinery

A save taken while an actuator is mid-motion writes its **path parameter** `t` in `[0.0, 1.0]` and its `direction` in `{FORWARD, REVERSE, STOPPED}`.

On load, the actuator is placed at exactly `t` and resumes in `direction`. It does not snap to an endpoint and does not restart.

If the actuator's controlling signal has changed between save and load — because a Zone flag or lever state produces a different input — the actuator resolves per §21.1 transition rules on the first frame after load, from position `t`. It does not teleport.

## 5.11 Temporary grants across a save

A temporary Barrier grant, an active Status, or a `TEMPORARY_RULE` effect is `EPHEMERAL`. It does not survive a save.

Stated plainly so it is not a surprise: saving and loading clears the player's Barrier and any Status on any actor. This is a deliberate simplification. The alternative — persisting effect timers and their sources — requires every effect source to be resolvable after load, including sources that were `EPHEMERAL` themselves. Reliable Core does not pay that cost.

Because saves only occur at the six points in §5.3, and none of them occur during combat, this is not reachable mid-fight.

## 5.12 Active encounters across a save

Not reachable. A save cannot be taken during an active encounter, because none of the six save points occur during one:

- Checkpoints do not activate during an active encounter (§30.6).
- Checks are not activatable during an active encounter (§9.4).
- Zone entry and exit, Hub commit, and manual save all require a non-combat state.

Manual save is refused with the message in §34.7 when an encounter is active. This is the closure for the "active encounters" persistence gap: the state is made unreachable rather than specified.

---

# 6. BASE PLAYER

## 6.1 Body

| Property | Value |
|---|---|
| Capsule radius | `0.40 m` |
| Capsule height | `1.80 m` |
| Eye height | `1.65 m` |
| Step height | `0.40 m` |
| Max walkable slope | `46°` |
| Base Health | `100.0` |
| Base Barrier | `0.0` |
| Base Defense | `0.0` |
| Mass class | `MEDIUM` |
| Faction | `PLAYER` |

## 6.2 Movement law

These constants are the single authoritative movement definition. The player controller, the room validator, the traversal auditor, and the LaunchPad solver all read this table. There is no second definition of "a safe base jump".

| Constant | Value |
|---|---|
| `WALK_SPEED` | `6.50 m/s` |
| `GROUND_ACCEL` | `60.0 m/s²` |
| `GROUND_DECEL` | `80.0 m/s²` |
| `AIR_ACCEL` | `12.0 m/s²` |
| `AIR_MAX_STEER_SPEED` | `6.50 m/s` |
| `GRAVITY` | `22.0 m/s²` |
| `JUMP_VELOCITY` | `7.40 m/s` |
| `TERMINAL_VELOCITY` | `60.0 m/s` |
| `COYOTE_TIME` | `0.12 s` |
| `JUMP_BUFFER` | `0.15 s` |
| `SIMULATION_TICK` | `1/60 s` fixed |

Derived, and used by every validator:

| Derived value | Formula | Value |
|---|---|---|
| `JUMP_APEX` | `JUMP_VELOCITY² / (2·GRAVITY)` | `1.245 m` |
| `JUMP_AIRTIME` | `2·JUMP_VELOCITY / GRAVITY` | `0.673 s` |
| `JUMP_REACH` | `WALK_SPEED · JUMP_AIRTIME` | `4.373 m` |
| `MAX_SAFE_STEP_UP` | `JUMP_APEX − 0.10 m` margin | `1.145 m` |
| `MAX_SAFE_GAP` | `JUMP_REACH − 0.45 m` margin | `3.923 m` |
| `MIN_HEADROOM` | capsule height `+ 0.15 m` | `1.95 m` |

The margins exist because a validator that certifies a jump at exactly its theoretical limit certifies a jump the player will miss. `MAX_SAFE_STEP_UP` and `MAX_SAFE_GAP` are the numbers a mandatory route must satisfy. Optional routes may exceed them; that is what makes them optional.

**Air control** applies `AIR_ACCEL` toward the input direction, clamped so that the horizontal speed component along the input direction never exceeds `AIR_MAX_STEER_SPEED`. It never increases speed above that ceiling, so air-strafing cannot accumulate velocity. Speed already above the ceiling from an external impulse is preserved, not clamped down — the player keeps launch momentum but cannot steer to add to it.

**Coyote time** permits a jump for `COYOTE_TIME` after leaving a walkable surface, once per airborne period. **Jump buffer** stores a jump input for `JUMP_BUFFER` and consumes it on the first frame the player is grounded.

**Fall damage does not exist.** A fall either lands the player somewhere valid or triggers out-of-bounds recovery. This is what makes the Dungeon Authority's Span Basin pattern work — falling changes your route instead of reloading you.

## 6.3 Out-of-bounds recovery

A room declares an `oob_volume`: an axis-aligned box enclosing all playable space, expanded `10.0 m` in every horizontal direction and `40.0 m` downward.

On leaving `oob_volume`, or on remaining below the room's `floor_y` for `1.5 s`:

1. All player velocity is zeroed.
2. The player is placed at the most recent checkpoint.
3. Health is set to `max(current_health, 25.0)`.
4. No damage is dealt and no death occurs.

Step 3 means out-of-bounds never kills but also never heals a healthy player. A player at 8 Health who falls out of the world comes back at 25 rather than dying to geometry.

Carryables leaving `oob_volume` follow §10.4 instead.

## 6.4 Static Pulse

`weapon:core:static_pulse`. Always index 0 of the Weapon cycle. Cannot be unequipped, consumed, forged, or disabled.

| Property | Value |
|---|---|
| Primary family | `HITSCAN_SINGLE` |
| Damage | `6.0` |
| Interval | `0.35 s` |
| Range | `60.0 m` |
| Damage falloff | none |
| Spread | `0.0°` |
| Damage tags | `RANGED` |
| Crit eligible | yes |
| Secondary | none — RMB is inert |
| Feed | `NONE` — R is a no-op with an acknowledgement animation |
| Status applied | none |

No falloff and no spread are deliberate. Static Pulse is the reference against which every other Weapon's value is measured, and a reference with distance-dependent output is not a reference.

`RANGED_HIT` capability (§29.1) is satisfied by Static Pulse, permanently and unconditionally. Every mandatory shootable target in the game is reachable with it.

## 6.5 Baseline melee

Default MMB. Rebindable. Not an Echo, not a Weapon slot, not an Ability, and never removable.

| Property | Value |
|---|---|
| Damage | `25.0` |
| Reach | `2.20 m` |
| Sweep shape | capsule cast, radius `0.50 m`, from eye position along view direction |
| Recovery | `0.55 s` |
| Max targets per swing | `3` |
| Impulse to target | `4.0 m/s` along view direction |
| Damage tags | `MELEE` |
| Crit eligible | yes |
| Breaks materials | `BREAKABLE` |

Melee is usable while any Weapon is selected, while reloading, while venting, while overheated, and while holding a charge. It does not cancel or interrupt any of those; the Weapon's state continues underneath. It **is** blocked while carrying a carryable (§10.2) and during a hack (§22.1).

Melee is a stable verb for `ACTION` recharge precisely because it always means the same thing. "Land three baseline melee hits" is legible because baseline melee cannot be reconfigured.

---

# 7. INPUT

## 7.1 Semantic roles and defaults

Gameplay consumes roles. Generated definitions never contain a keycode.

| Role | Default | Rebindable |
|---|---|---|
| `move_forward/back/left/right` | `W A S D` | yes |
| `look` | mouse | sensitivity only |
| `jump` | `Space` | yes |
| `weapon_primary` | `LMB` | yes |
| `weapon_secondary` | `RMB` | yes |
| `melee` | `MMB` | yes |
| `weapon_cycle_next` | wheel down | yes |
| `weapon_cycle_prev` | wheel up | yes |
| `ability_q` | `Q` | yes |
| `ability_e` | `E` | yes |
| `ability_1` | `1` | yes |
| `ability_2` | `2` | yes |
| `ability_3` | `3` | yes |
| `mobility` | `Shift` | yes |
| `interact` | `F` | yes |
| `weapon_feed` | `R` | yes |
| `archive` | `Tab` | yes |
| `pause` | `Esc` | no |

Key `4` is bound to nothing and is reserved.

## 7.2 Rebinding rules

- Every role except `pause` may be bound to any keyboard key or mouse button.
- A binding conflict is rejected at the moment of assignment with the message in §34.8. The previous binding is retained. Bindings are never silently swapped.
- Rebinding changes only the physical trigger. It never changes which host occupies a slot, and it never changes a role's meaning. `ability_e` bound to `G` is still Ability slot E.
- Bindings are stored in client settings, not in the save file, and are shared across campaigns.

## 7.3 Simultaneous and conflicting input

Resolved in this fixed priority order within a single tick. Higher entries win and suppress lower ones.

1. `pause`
2. `interact`
3. `mobility`
4. `ability_q`, `ability_e`, `ability_1`, `ability_2`, `ability_3` — if two are pressed on the same tick, the earlier in this list wins and the other is discarded, not buffered
5. `melee`
6. `weapon_secondary`
7. `weapon_primary`
8. `weapon_feed`
9. `weapon_cycle_next` / `weapon_cycle_prev`
10. `jump`, movement, `look` — never suppressed by anything above

Movement and look are always live. There is no state in Reliable Core that removes player control of the camera.

## 7.4 Weapon cycling input

`weapon_cycle_next` advances to the next non-empty cycle index, wrapping. `weapon_cycle_prev` reverses. Empty slots are skipped without a tick of input.

Cycling is instant at the simulation level. The `0.25 s` device transition (§33.4) is presentation; the newly selected Weapon is usable on the first frame after the input.

Cycling is blocked while: carrying a carryable, in a hack, or holding a `CHARGE` feed at or above minimum charge. In the last case the input is discarded, not buffered, and the HUD flashes the charge indicator.

---

# 8. DAMAGE

## 8.1 The damage request

Every loss of Health or Barrier in the game is a `DamageRequest` passed to one resolver. Nothing writes Health directly.

```
DamageRequest:
  amount            : Damage
  tags              : list[DamageTag], length >= 1
  source_actor      : Id?                # null for world hazards with no owner
  source_host       : Id?                # the Weapon/Ability/Gear that caused it
  target_actor      : Id
  crit_eligible     : bool
  crit_chance       : float >= 0.0       # may exceed 1.0; see §8.5
  penetration       : float in [0.0, 1.0] = 0.0
  ignores_barrier   : bool = false
  status_applied    : Id? = null
  status_chance     : Chance = 0.0
  impulse           : Meters/s = 0.0
  impulse_dir       : vec3? = null
```

## 8.2 Resolution order

Exactly this order. Every step is deterministic given its inputs.

1. **Validity.** If `target_actor` does not exist, or is already dead, the request is discarded with no effect.
2. **Faction check.** If source and target factions are equal and the request is not self-damage, apply §8.6.
3. **Crit tier.** Compute per §8.5. Multiply `amount` by the tier multiplier.
4. **Defense.** Apply per §8.3.
5. **Barrier.** Apply per §8.4 unless `ignores_barrier`.
6. **Health.** Subtract the remainder from Health, clamped at `0.0`.
7. **Impulse.** Apply `impulse` along `impulse_dir` if both are non-null and the target's mass class permits it (§14.2).
8. **Status.** Attempt `status_applied` at `status_chance` per §15.2, only if Health loss in step 6 was greater than `0.0` **or** `amount` was `0.0` to begin with. A blow fully absorbed by Barrier does not apply Status.
9. **Death.** If Health reached `0.0`, resolve death per §8.8.
10. **Reactions.** Fire Mod triggers per §16.4, in the order defined there.

Rounding: no rounding occurs at any step. Health, Barrier, and damage are floats throughout. Display rounds to the nearest integer for presentation only.

## 8.3 Defense

```
mitigated = amount × (1.0 − effective_defense / (effective_defense + 100.0))
effective_defense = max(0.0, defense × (1.0 − penetration))
```

Defense uses a hyperbolic curve with no cap, which is self-limiting: `100` Defense is 50% mitigation, `200` is 66.7%, `400` is 80%. Infinite mitigation is unreachable because the curve approaches 1.0 asymptotically and Defense sources are bounded by §16.5.

| Actor | Base Defense |
|---|---|
| Player | `0.0` |
| Standard enemy | `0.0` |
| Armored enemy | `100.0` |
| Boss | `150.0` |

Penetration is bounded to `0.6` by §16.5. No combination reaches full penetration.

## 8.4 Barrier

Barrier is a separate pool that absorbs before Health.

- Barrier absorbs damage up to its current value, then the remainder passes to Health in the same request.
- Barrier never regenerates on its own. It is granted only by `BARRIER_GRANT` abilities, Gear intrinsics, and Mods.
- Multiple Barrier grants **sum into a single pool**. They do not stack as separate layers.
- Each grant carries its own expiry. When a grant expires, its amount is subtracted from the current pool, floored at `0.0`.
- Damage depletes the pool as a whole, not per-grant. A grant that expires after the pool has already been depleted below its amount removes only what remains.

Worked example, because this is the subtlest rule in §8: grant A gives `40` Barrier for `10 s`. At `t=2` grant B gives `30`, pool is `70`. At `t=5` the player takes `50` damage; pool is `20`. At `t=10` grant A expires and subtracts `40`; pool floors at `0.0`. Grant B, despite having time remaining, contributes nothing — its value was already spent.

The player is shown one Barrier number, never a stack of grants.

## 8.5 Crit and overcrit

```
guaranteed_tier = floor(crit_chance)
remainder       = crit_chance − guaranteed_tier
crit_tier       = guaranteed_tier + (1 if roll() < remainder else 0)
multiplier      = 1.0 + crit_tier
```

`crit_tier` is clamped to `4`. `multiplier` is therefore in `{1.0, 2.0, 3.0, 4.0, 5.0}` — linear, per Player Authority §19.3.

| `crit_chance` | Guaranteed | Possible | Multiplier range |
|---|---|---|---|
| `0.00` | Tier 0 | — | `1.0` |
| `0.35` | Tier 0 | Tier 1 | `1.0` or `2.0` |
| `1.00` | Tier 1 | — | `2.0` |
| `1.50` | Tier 1 | Tier 2 | `2.0` or `3.0` |
| `2.00` | Tier 2 | — | `3.0` |
| `4.00`+ | Tier 4 | — | `5.0` (clamped) |

`roll()` draws from the combat RNG stream (§30.5). Base player `crit_chance` is `0.0`; all crit comes from Weapon profiles, Gear, and Mods.

**Crit eligibility is explicit and does not propagate.** A damage source is crit-eligible only if its definition says so:

| Source | Crit eligible by default |
|---|---|
| Weapon primary and secondary | yes |
| Baseline melee | yes |
| Static Pulse | yes |
| Ability direct damage | yes |
| Physics impact (§14.4) | **no** |
| Hazards (§25.1) | **no** |
| Explosions from reactive barrels | **no** |
| Fire Actors | **no** |
| Deployable turret fire | yes |
| Deployable field damage | **no** |

An "overcrit" is any hit at `crit_tier >= 2`. It is a named event because `ACTION` recharge and Mod triggers consume it (§12.6, §16.2).

## 8.6 Friendly, self, and environmental damage

| Case | Behavior |
|---|---|
| Player damages `PLAYER`-faction actor (a `TURNCOAT` enemy) | Full damage. Turncoats are not protected. |
| Player's own explosion overlaps the player | `50%` damage, no crit, no Status, full impulse |
| Enemy damages enemy of same faction | Full damage. Enemies have no friendly fire immunity. |
| Enemy explosion damages the enemy that fired it | Full damage |
| Hazard damages any actor | Full damage per §25.1, regardless of faction |
| `PHYSICS` impact from a player-owned object hits the player | `0.0`. Player-owned objects never damage the player. |

Self-damage at 50% makes explosive Weapons a real decision without making them unusable at close range. It never crits, so an overcrit build cannot accidentally delete itself.

## 8.7 Healing

Healing is a `HealRequest`, not a negative `DamageRequest`.

```
HealRequest:
  amount            : float > 0.0
  target_actor      : Id
  source_host       : Id?
```

Healing is clamped to the target's maximum Health. It never crits, never applies Status, and never fires damage reactions. Overheal is discarded, not converted to Barrier.

The only sources of healing in Reliable Core are the `HEAL_CHANNEL` ability family (§12.1), the `HEALTH_PICKUP` destructible drop (§25.3), and checkpoint restoration.

## 8.8 Death

On an actor reaching `0.0` Health:

1. Kill credit is assigned to the `source_actor` of the fatal request. If `source_actor` is null, credit goes to the player **only if** the fatal request's `source_host` is non-null and player-owned; otherwise the kill is uncredited.
2. Uncredited kills advance no `ACTION` progress and fire no triggers. An enemy that walks into a hazard with no owner is not the player's kill.
3. Enemy: the actor is removed, its encounter's remaining count decrements, and drops resolve per §32.6.
4. Player: §5.4.

Environmental kill credit is defined precisely in §25.4.

---

# 9. WORLD INTERACTION

## 9.1 Candidates

An `Interactable` declares:

```
Interactable:
  id                : Id
  verb              : enum { PRESS, PICK_UP, PLACE, DROP, PULL, OPEN,
                             HACK, USE_TERMINAL, ACTIVATE_CHECK, INSERT, REMOVE }
  priority_class    : int in [1, 5]        # see §9.2
  range             : Meters <= 4.0
  requires_los      : bool = true
  enabled           : bool = true
  disabled_reason   : string = ""          # shown when enabled is false
```

## 9.2 Deterministic focus

Every frame, the resolver:

1. Collects Interactables whose origin is within `range` of the player's eye position.
2. Discards any whose angle from the view direction exceeds `35°` (the interaction cone).
3. Discards any with `requires_los` whose line from eye to origin is blocked by `signal_blocking` or opaque geometry.
4. Sorts the survivors by, in order: **`priority_class` ascending**, then **angle from view center ascending**, then **distance ascending**, then **`id` lexicographic ascending**.
5. Focuses the first.

Step 4's final tiebreak on `id` exists so that focus is fully deterministic. Two interactables at identical angle and distance resolve the same way every time, in every replay.

Priority classes:

| Class | Contents |
|---|---|
| 1 | Terminal or panel currently open |
| 2 | Socket accepting the object currently carried |
| 3 | Pickup or drop target |
| 4 | Button, lever, door, Check |
| 5 | Optional or cosmetic interaction |

While carrying, the carried object's legal Place target is class 2 and therefore beats every button and lever in range. This is the resolution of the Player Authority's §15.3 ambiguity: F while carrying a cube in front of a terminal places the cube, and the prompt says so before the press.

## 9.3 Prompt and activation

The focused Interactable's verb and display name are shown as `[F] <Verb> <Name>`. When nothing is focused, no prompt is shown.

When the focused Interactable has `enabled = false`, the prompt shows in the disabled style with `disabled_reason` appended, and pressing `interact` produces the rejection feedback in §34.9 without changing state.

Activation is on key **release** for `HACK` and `USE_TERMINAL`, and on key **press** for every other verb. Hold-to-activate does not exist; there is no interaction that requires holding F.

## 9.4 AP Checks

A Check uses `verb = ACTIVATE_CHECK` and `priority_class = 4`, so it participates in normal focus. Its transaction is separate:

1. On activation the Check enters `PENDING` and is visually distinct. It is immediately non-reactivatable.
2. The client sends the location to the bridge.
3. On confirmation the Check enters `CONFIRMED`, a save is written (§5.3), and the reward presentation plays.
4. If the bridge is disconnected, the Check remains `PENDING` and is queued. It confirms when the connection is restored.
5. A `PENDING` Check that is saved and loaded remains `PENDING` and re-queues on load.
6. A Check is never un-activated by any reset, death, or reload.

Checks are not activatable while an encounter in the same room is active. The Interactable's `enabled` is false with `disabled_reason = "Area not secure"`.

---

# 10. CARRYABLES AND SOCKETS

## 10.1 Object classes

```
CarryableDefinition:
  id                : Id
  class             : enum { GENERIC, WEIGHTED, POWER_CELL, KEY_COMPONENT,
                             MECHANICAL_PART, MOVABLE_COVER, CART }
  mass_class        : MassClass
  carriable         : bool
  socket_tags       : list[string] = []
  required          : bool = false          # progression-critical
  home_transform    : transform             # spawn and recovery point
  allowed_volume    : Id                    # room volume it may not leave
  destructible      : bool = false
```

| Class | Mass | Carriable | Typical use |
|---|---|---|---|
| `GENERIC` | `LIGHT` | yes | General props, throwing weight around |
| `WEIGHTED` | `HEAVY` | yes | Pressure plates |
| `POWER_CELL` | `MEDIUM` | yes | Power sockets |
| `KEY_COMPONENT` | `LIGHT` | yes | Local key loops |
| `MECHANICAL_PART` | `MEDIUM` | yes | Machinery repair sockets |
| `MOVABLE_COVER` | `HEAVY` | **no** | Pushed, or Physics-moved; changes sightlines |
| `CART` | `HEAVY` | **no** | Constrained to a floor path or rail |

`MOVABLE_COVER` and `CART` are never carriable. They move by player collision push, by `PUSH`/`PULL` Physics, or by machinery.

## 10.2 Pickup and carry

`F` on a carriable object with `carriable = true` and `mass_class` of `LIGHT` or `MEDIUM` picks it up. `HEAVY` objects are never carriable.

While carrying:

| Property | Value |
|---|---|
| Carry position | `1.20 m` forward, `0.20 m` below eye, following view with `0.08 s` smoothing |
| Carried collision | collides with world geometry; passes through actors |
| Movement effect | `WALK_SPEED` × `0.85` while carrying a `MEDIUM` object; no penalty for `LIGHT` |
| Blocked actions | melee, Weapon primary, Weapon secondary, weapon cycling, Mobility, hacking |
| Permitted actions | movement, jump, look, Abilities, `interact`, pause, Archive |

Abilities remain usable while carrying. This is deliberate: a defensive Ability being unavailable because you are holding a cube is the kind of rule that produces deaths the player cannot explain.

If the carried object is pushed into geometry such that its carry position is occluded, it is held at the nearest unoccluded point along the line to the player. If no such point exists within `0.40 m` of the player, the object is dropped at the player's feet.

## 10.3 Drop and place

`F` while carrying:

- If the focused Interactable is a compatible socket (class 2), the object is **placed** into it.
- Otherwise the object is **dropped** at its current carry position with zero velocity.

There is no throw in Reliable Core. Dropping is always zero-velocity. This removes an entire family of physics edge cases — thrown objects clipping geometry, thrown objects as weapons, thrown objects as traversal — at the cost of a verb the Dungeon Authority lists as legal. §40 records this as a sacrifice.

**Socket compatibility:** a socket declares `accepts: list[string]`. An object may be placed if any of its `socket_tags` appears in `accepts`. An incompatible object produces the rejection feedback in §34.9; the socket's prompt shows as disabled before the press, so incompatibility is visible in advance.

**Removal:** a socket with `removable = true` returns its contents to the player's carry state on `F`. A socket with `removable = false` shows `[F] Remove` as disabled with `disabled_reason = "Locked in place"`.

## 10.4 Recovery

Every object with `required = true` recovers. Recovery triggers:

| Trigger | Behavior |
|---|---|
| Leaves `allowed_volume` | Respawn at `home_transform` after `1.0 s` |
| Leaves the room's `oob_volume` | Respawn at `home_transform` immediately |
| Destroyed, where `destructible` | Respawn at `home_transform` after `2.0 s` |
| At rest for `5.0 s` in a position not reachable by the player | Respawn at `home_transform` |
| Player activates a reset control | Respawn at `home_transform` immediately |
| Puzzle reset (§23.4) | Respawn at `home_transform` |

Reachability for the fourth trigger is evaluated against the movement law in §6.2 from the room's navigable set, computed once at room load, not per-frame.

**Semantic identity survives respawn.** A respawned object has the same `id`. A puzzle asking "is the weighted object in the socket" asks about the semantic object, never about a runtime instance. Respawning never invalidates puzzle state.

An object with `required = false` that leaves `allowed_volume` is destroyed and not replaced.

If `home_transform` is itself occupied by another object at respawn time, the respawning object is placed at the nearest free point within `2.0 m`. If no free point exists, the occupying object is destroyed first if it is `required = false`, or displaced to *its* `home_transform` if it is `required = true`. Two required objects sharing a `home_transform` is a package authoring error caught by the validator in §23.5.

---

# 11. WEAPONS

## 11.1 Primary families

Eight families. Every generated Weapon's primary is one of these, with a profile from that family's legal set.

### `HITSCAN_SINGLE`
One instantaneous ray per shot.

| Parameter | Meaning |
|---|---|
| `damage` | per hit |
| `interval` | seconds between shots |
| `range` | maximum ray length |
| `spread_deg` | cone half-angle |
| `falloff_start`, `falloff_end` | distances between which damage lerps to `falloff_min_mult` |
| `falloff_min_mult` | multiplier at and beyond `falloff_end` |
| `crit_chance` | added to the player's crit chance for this action |

| Profile | `damage` | `interval` | `range` | `spread_deg` | falloff | `crit_chance` |
|---|---:|---:|---:|---:|---|---:|
| `cadence_rapid` | `7.0` | `0.10` | `50.0` | `1.2` | `25→45`, `0.6` | `0.05` |
| `cadence_standard` | `18.0` | `0.28` | `70.0` | `0.4` | `40→70`, `0.7` | `0.10` |
| `cadence_precise` | `52.0` | `0.85` | `120.0` | `0.0` | none | `0.30` |

### `HITSCAN_BURST`
`burst_count` rays fired `burst_interval` apart on one input, then `interval` recovery. The burst completes even if the input is released.

| Profile | `damage` | `burst_count` | `burst_interval` | `interval` | `range` | `spread_deg` | `crit_chance` |
|---|---:|---:|---:|---:|---:|---:|---:|
| `burst_triple` | `14.0` | `3` | `0.06` | `0.42` | `60.0` | `0.8` | `0.10` |
| `burst_double_heavy` | `30.0` | `2` | `0.09` | `0.70` | `80.0` | `0.3` | `0.20` |

### `HITSCAN_SPREAD`
`pellet_count` rays in one instant, each independently rolled for crit.

| Profile | `damage` (per pellet) | `pellet_count` | `interval` | `range` | `spread_deg` | falloff | `crit_chance` |
|---|---:|---:|---:|---:|---:|---|---:|
| `spread_close` | `9.0` | `9` | `0.75` | `25.0` | `7.0` | `8→22`, `0.35` | `0.05` |
| `spread_wide` | `6.0` | `14` | `0.95` | `18.0` | `12.0` | `6→16`, `0.30` | `0.05` |

### `PROJECTILE_DIRECT`
A travelling body on a straight line, unaffected by gravity.

| Parameter | Meaning |
|---|---|
| `speed` | m/s |
| `radius` | collision sphere radius |
| `lifetime` | seconds before despawn |
| `impact_radius` | `0.0` for single-target, `> 0.0` for area on impact |
| `pierce_count` | actors passed through before stopping |

| Profile | `damage` | `interval` | `speed` | `radius` | `lifetime` | `impact_radius` | `pierce_count` | `crit_chance` |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `bolt_fast` | `22.0` | `0.35` | `70.0` | `0.15` | `3.0` | `0.0` | `0` | `0.10` |
| `bolt_piercing` | `26.0` | `0.60` | `55.0` | `0.20` | `3.0` | `0.0` | `2` | `0.15` |
| `shell_impact` | `40.0` | `0.90` | `40.0` | `0.30` | `4.0` | `3.0` | `0` | `0.05` |

### `PROJECTILE_LOB`
A travelling body under gravity that detonates.

| Parameter | Meaning |
|---|---|
| `gravity_scale` | multiplier on `GRAVITY` |
| `fuse` | seconds until detonation regardless of contact |
| `detonate_on_contact` | whether world contact detonates immediately |
| `bounce_count` | world bounces before forced detonation, when not detonating on contact |
| `bounce_restitution` | velocity retained per bounce |

| Profile | `damage` | `interval` | `speed` | `gravity_scale` | `fuse` | `detonate_on_contact` | `bounce_count` | `bounce_restitution` | `impact_radius` |
|---|---:|---:|---:|---:|---:|---|---:|---:|---:|
| `lob_impact` | `55.0` | `1.00` | `28.0` | `1.0` | `4.0` | yes | `0` | — | `4.0` |
| `lob_timed` | `70.0` | `1.30` | `24.0` | `1.0` | `2.0` | no | `3` | `0.35` | `5.0` |

**Contact with an actor always detonates**, regardless of `detonate_on_contact`. That flag governs world geometry only. A `lob_timed` grenade that hits an enemy explodes on the enemy; one that hits a wall bounces.

### `BEAM_CONTINUOUS`
A held ray dealing damage in discrete ticks.

| Parameter | Meaning |
|---|---|
| `tick_interval` | seconds between damage applications |
| `damage` | per tick |
| `ramp_time` | seconds of continuous fire to reach `ramp_max_mult` |
| `ramp_max_mult` | damage multiplier at full ramp |

| Profile | `damage` | `tick_interval` | `range` | `ramp_time` | `ramp_max_mult` | `crit_chance` |
|---|---:|---:|---:|---:|---:|---:|
| `beam_steady` | `4.0` | `0.10` | `35.0` | `0.0` | `1.0` | `0.05` |
| `beam_ramping` | `2.5` | `0.10` | `30.0` | `2.0` | `2.4` | `0.05` |

Ramp progress accumulates while the beam is held on any target and decays at twice the ramp rate when released. Breaking line of sight does not reset ramp; releasing the input does, gradually. Ramp is per-Weapon, is `EPHEMERAL`, and resets to zero on cycling away.

### `CHARGE_RELEASE_SHOT`
Held to build charge, released to fire. Requires `feed.model == CHARGE`.

| Parameter | Meaning |
|---|---|
| `damage_min`, `damage_max` | damage at minimum and full charge |
| `charge_time` | seconds from zero to full |
| `min_charge_fraction` | fraction below which release does nothing |

| Profile | `damage_min` | `damage_max` | `charge_time` | `min_charge_fraction` | `speed` | `impact_radius` | `crit_chance` |
|---|---:|---:|---:|---:|---:|---:|---:|
| `charge_lance` | `20.0` | `95.0` | `1.20` | `0.25` | `90.0` | `0.0` | `0.20` |
| `charge_burst` | `15.0` | `70.0` | `0.90` | `0.20` | `45.0` | `4.5` | `0.10` |

Damage scales **linearly** between `damage_min` and `damage_max` across the charge range. Releasing below `min_charge_fraction` cancels: no shot, no cost, charge resets to zero.

### `CLOSE_ARC`
A short sweep from the device, distinct from baseline melee in that it is a Weapon and may carry a Status.

| Profile | `damage` | `interval` | `reach` | `sweep_radius` | `max_targets` | `impulse` | `crit_chance` |
|---|---:|---:|---:|---:|---:|---:|---:|
| `arc_swift` | `34.0` | `0.45` | `2.8` | `0.7` | `4` | `5.0` | `0.15` |
| `arc_heavy` | `72.0` | `1.10` | `3.2` | `0.9` | `6` | `9.0` | `0.10` |

## 11.2 Secondary kinds

| Kind | Behavior | Uses feed |
|---|---|---|
| `ZOOM` | Held. FOV to `profile.zoom_fov`, spread × `profile.spread_mult`, `WALK_SPEED` × `profile.move_mult`. No damage. | no |
| `ALT_FIRE` | A second full `WeaponAction` on RMB, with its own parameters. | yes, shared |
| `GUARD` | Held. Grants `profile.barrier` Barrier that expires `0.2 s` after release. `WALK_SPEED` × `0.5`. Primary is blocked while held. | no |
| `DETONATE` | Press. Detonates all of this Weapon's live `PROJECTILE_LOB` bodies immediately. No effect if none exist. | no |
| `MODE_SWAP` | Press. Toggles the primary between its profile and `profile.alt_profile`. `0.35 s` swap time during which the primary is blocked. | no |

Profiles:

| Profile | Kind | Parameters |
|---|---|---|
| `zoom_standard` | `ZOOM` | `zoom_fov 45°`, `spread_mult 0.35`, `move_mult 0.6` |
| `zoom_long` | `ZOOM` | `zoom_fov 25°`, `spread_mult 0.10`, `move_mult 0.45` |
| `guard_light` | `GUARD` | `barrier 40.0` |
| `guard_heavy` | `GUARD` | `barrier 90.0` |
| `detonate_standard` | `DETONATE` | — |
| `mode_swap_standard` | `MODE_SWAP` | `alt_profile` names any profile legal for the primary's family |

**Shared feed lock.** Primary and `ALT_FIRE` secondary draw from the same feed state. Only one may be active at a time:

- Starting a primary action locks the secondary until the primary's `interval` elapses, and vice versa.
- A burst in progress locks both until it completes.
- A held charge locks the secondary entirely until released or cancelled.
- A held beam locks the secondary; releasing unlocks on the next tick.
- `MODE_SWAP` during any of the above is discarded, not queued.

This is the closure for the "shared primary/alt-fire lock" gap. There is exactly one active Weapon action at a time, always.

## 11.3 `MAGAZINE`

| Parameter | Meaning |
|---|---|
| `magazine_capacity` | rounds when full |
| `consumption` | rounds per shot |
| `reload_duration` | seconds |

| Profile | `magazine_capacity` | `consumption` | `reload_duration` |
|---|---:|---:|---:|
| `mag_small_fast` | `12` | `1` | `1.10` |
| `mag_standard` | `30` | `1` | `1.80` |
| `mag_large_slow` | `60` | `1` | `2.60` |
| `mag_shell` | `6` | `1` | `2.20` |

Rules:

- Reserve is infinite. Reload always fills to capacity.
- Firing with `magazine_rounds < consumption` does nothing: no shot, no cost, and an empty-click acknowledgement. It does **not** auto-reload.
- `R` starts a reload. `R` during a reload does nothing.
- **Reload is interruptible.** Cycling away, using an Ability, using Mobility, or interacting cancels the reload with no progress retained. `magazine_rounds` is unchanged.
- Reload completes at exactly `reload_duration` after it starts. There is no partial-reload credit and no per-round reloading, including for `mag_shell`.
- Melee does **not** interrupt a reload.

## 11.4 `HEAT`

| Parameter | Meaning |
|---|---|
| `heat_max` | lockout threshold |
| `heat_per_use` | added per shot, or per second for `BEAM_CONTINUOUS` |
| `cool_rate` | units per second while not firing, after `cool_delay` |
| `cool_delay` | seconds after last use before cooling begins |
| `vent_duration` | seconds for an active vent |
| `lockout_duration` | forced cooldown after reaching `heat_max` |
| `inactive_cool_rate` | units per second while this Weapon is not selected |

| Profile | `heat_max` | `heat_per_use` | `cool_rate` | `cool_delay` | `vent_duration` | `lockout_duration` | `inactive_cool_rate` |
|---|---:|---:|---:|---:|---:|---:|---:|
| `heat_standard` | `100.0` | `8.0` | `35.0` | `0.6` | `1.40` | `2.50` | `12.0` |
| `heat_beam` | `100.0` | `28.0` (per s) | `40.0` | `0.5` | `1.20` | `2.20` | `15.0` |

Rules:

- Firing adds `heat_per_use`. For beams, heat accrues continuously at `heat_per_use` per second while firing.
- Reaching `heat_max` triggers lockout: the Weapon cannot fire for `lockout_duration`, during which heat drains linearly from `heat_max` to `0.0` over exactly `lockout_duration`. Lockout cannot be shortened by venting.
- `R` starts a vent, legal only when `heat_current > 0.0` and not in lockout. A vent takes `vent_duration` and sets heat to `0.0` on completion. The Weapon cannot fire during a vent.
- **A vent is interruptible** by the same actions that interrupt a reload (§11.3), with no heat reduction applied.
- `inactive_cool_rate` applies while the Weapon is not the selected configuration. This is the one thing that continues for an unselected Weapon, and it is the explicit exception the Player Authority §9.2 permits.
- Lockout continues while unselected and while in lockout the `inactive_cool_rate` does not apply — the lockout drain rate governs.

## 11.5 `CHARGE`

| Parameter | Meaning |
|---|---|
| `charge_time` | seconds to full, from the primary's profile |
| `hold_max` | seconds a full charge may be held before auto-release |
| `cancel_refund` | always `1.0`; cancelling costs nothing |

| Profile | `hold_max` |
|---|---:|
| `charge_hold_short` | `2.0` |
| `charge_hold_long` | `5.0` |

Rules:

- Charge builds while `weapon_primary` is held, from `0.0` at `1/charge_time` per second, clamped at `1.0`.
- Releasing at or above `min_charge_fraction` fires. Below it, the charge cancels with no cost.
- Holding at full for `hold_max` auto-releases at full charge.
- **Cycling away cancels the charge entirely.** Charge is not retained across a cycle, and cycling is blocked while charge is at or above `min_charge_fraction` (§7.4), so this is only reachable below that threshold.
- Death, Zone exit, and hacking all cancel a held charge with no cost.
- `R` with a `CHARGE` feed cancels the current charge. This is the feed action.

## 11.6 `NONE`

No feed state. `R` plays a `0.3 s` acknowledgement animation and does nothing. The HUD shows no ammunition, no heat bar, and no charge meter. Fabricating a fake resource display for a Weapon that has none is explicitly forbidden.

## 11.7 Cycling and activation

The cycle is `[static_pulse, weapons[0], weapons[1], weapons[2]]` with null entries skipped.

On cycling away from a Weapon, its state is preserved exactly:

| State | On cycle away |
|---|---|
| `magazine_rounds` | preserved |
| `heat_current` | continues cooling at `inactive_cool_rate` |
| Heat lockout | continues draining |
| Charge | cancelled |
| Beam ramp | reset to `0.0` |
| Reload in progress | cancelled, no progress retained |
| Vent in progress | cancelled, no reduction applied |
| `MODE_SWAP` state | preserved |
| Live `PROJECTILE_LOB` bodies | continue to their fuse or contact |

**Only the selected Weapon is activation-active.** An unselected Weapon runs no combat passives, no kill reactions, no Status emitters, no resource generators, no target listeners, and no Mod triggers. `inactive_cool_rate` is the only exception in the entire system.

Live projectiles from an unselected Weapon still resolve — they were committed while it was selected — and their damage is credited to that Weapon's `source_host`. A `DETONATE` secondary only works while its own Weapon is selected.

---

# 12. ABILITIES, READINESS, AND COST

## 12.1 The twelve families

| Family | What it does | Damage | Legal Statuses |
|---|---|---|---|
| `PROJECTILE_ATTACK` | Fires a projectile using the `PROJECTILE_DIRECT` or `PROJECTILE_LOB` mechanics | yes | any |
| `AREA_BURST` | Instant damage in a sphere at a target point or at the player | yes | any |
| `BARRIER_GRANT` | Grants Barrier to the player | no | none |
| `HEAL_CHANNEL` | Restores Health over a channel | no | none |
| `DEPLOYABLE_TURRET` | Places an actor that fires at hostiles | yes | any |
| `DEPLOYABLE_FIELD` | Places a volume applying an effect to actors inside | yes | any |
| `STATUS_APPLICATOR` | Applies a Status with no damage | no | any, required |
| `MARK_REVEAL` | Highlights actors and Interactables through geometry | no | none |
| `PHYSICS_VERB` | Executes one of the four Physics primitives | no | none |
| `DASH_IMPULSE` | Repositions the player a fixed distance | no | none |
| `WEAPON_BUFF` | Modifies the selected Weapon's output for a duration | no | none |
| `TEMPORARY_RULE` | Applies one typed rule change for a duration | no | none |

Common parameters, present in every ability profile:

| Parameter | Meaning |
|---|---|
| `cast_time` | seconds before the effect commits, during which movement is unrestricted |
| `duration` | effect lifetime, `0.0` for instantaneous |
| `radius` | area of effect, `0.0` for single-target |
| `range` | maximum targeting distance |
| `magnitude` | the family's primary scalar, meaning defined per family |

| Family | `magnitude` means |
|---|---|
| `PROJECTILE_ATTACK`, `AREA_BURST`, `DEPLOYABLE_TURRET`, `DEPLOYABLE_FIELD` | damage |
| `BARRIER_GRANT` | Barrier granted |
| `HEAL_CHANNEL` | Health per second |
| `STATUS_APPLICATOR` | `source_potency` added to application chance (§15.2) |
| `MARK_REVEAL` | nothing; ignored |
| `PHYSICS_VERB` | force in newtons |
| `DASH_IMPULSE` | distance in metres |
| `WEAPON_BUFF` | multiplier on Weapon damage |
| `TEMPORARY_RULE` | the rule's scalar, per §12.10 |

Representative profiles (the full catalog is an authored data file; these are the balanced starting set):

| Profile | `cast_time` | `duration` | `radius` | `range` | `magnitude` |
|---|---:|---:|---:|---:|---:|
| `ab_instant_light` | `0.00` | `0.0` | `0.0` | `40.0` | `35.0` |
| `ab_instant_heavy` | `0.35` | `0.0` | `5.0` | `30.0` | `85.0` |
| `ab_field_short` | `0.20` | `6.0` | `4.0` | `20.0` | `12.0` |
| `ab_field_long` | `0.20` | `14.0` | `5.5` | `20.0` | `8.0` |
| `ab_barrier_small` | `0.00` | `8.0` | `0.0` | `0.0` | `50.0` |
| `ab_barrier_large` | `0.25` | `6.0` | `0.0` | `0.0` | `120.0` |
| `ab_channel_heal` | `0.00` | `3.0` | `0.0` | `0.0` | `18.0` |
| `ab_status_reliable` | `0.15` | `0.0` | `0.0` | `35.0` | `0.30` |
| `ab_status_area` | `0.30` | `0.0` | `6.0` | `25.0` | `0.15` |
| `ab_reveal` | `0.00` | `12.0` | `30.0` | `0.0` | `0.0` |
| `ab_physics_standard` | `0.00` | `0.0` | `0.0` | `18.0` | `900.0` |
| `ab_dash_short` | `0.00` | `0.0` | `0.0` | `0.0` | `7.0` |
| `ab_weapon_buff` | `0.00` | `5.0` | `0.0` | `0.0` | `1.5` |
| `ab_rule_standard` | `0.10` | `8.0` | `0.0` | `0.0` | `1.0` |

## 12.2 Activation forms

| Form | Behavior |
|---|---|
| `PRESS` | Fires once on press. Ignores hold. |
| `HOLD` | Effect active while held. Ends on release or when cost can no longer be paid. |
| `CHARGE_RELEASE` | Builds `0.0`→`1.0` over `cast_time` while held; releasing applies `magnitude × charge`. Below `0.25` charge, cancels free. |
| `CHANNEL` | Repeating discrete samples at `0.5 s` intervals while held. Each sample pays its own cost. Bounded per §12.2.1. |

### 12.2.1 Channel bounds

For a `CHANNEL` ability, `duration` is the **maximum total channel time**, not an effect lifetime. A channel ends at the first of:

1. The input is released.
2. `duration` has elapsed since the channel began.
3. The next sample's preflight fails — insufficient resource, or the effect has nothing left to do.
4. The player takes any damage. Channels are interruptible by damage; this is what keeps a heal channel from being a free heal under fire.
5. Death, room unload, Zone exit, hack entry, or picking up a carryable.

The first sample fires immediately on commit, at `t = 0`, not after `0.5 s`. A channel of `duration 3.0 s` therefore fires samples at `t = 0.0, 0.5, 1.0, 1.5, 2.0, 2.5` — **six** samples — and ends at `3.0 s` before a seventh.

`ab_channel_heal` (`duration 3.0`, `magnitude 18.0`) therefore restores at most `6 × (18.0 × 0.5) = 54.0` Health for six sample costs. This is the complete bound; there is no path by which a channel exceeds it.

A channel cannot be restarted until its recharge permits a fresh activation. Releasing early and re-pressing is a new activation with a new preflight, not a resumption.

## 12.3 Preflight and commit

Every activation has a **preflight** and a **commit point**.

Preflight checks, in order:
1. The host exists and is equipped.
2. Readiness: charges available, resource sufficient, or action progress complete.
3. Family-specific validity: a `PHYSICS_VERB` needs an eligible target, a `BLINK`-style `DASH_IMPULSE` needs a valid destination, a `DEPLOYABLE_*` needs a valid surface.
4. Not blocked by carry state, hack state, or death.

**A failed preflight spends nothing.** No resource, no charge, no action progress, no cooldown. The player receives the rejection feedback in §34.9 naming which check failed.

**Commit** occurs at the end of `cast_time`. At commit, the cost is deducted and the effect is created. After commit there is no refund: a projectile that misses, a field placed somewhere useless, a Status that fails its roll — all are committed and spent.

Cancelling during `cast_time`, by any means, refunds fully. `cast_time` is the window in which the player may change their mind.

For `CHANNEL`, each sample is its own preflight and commit. The channel ends when the next sample's preflight fails. The partial sample is not charged.

## 12.4 `RESOURCE`

| Parameter | Meaning |
|---|---|
| `resource_max` | pool capacity |
| `cost` | per activation, or per sample for `CHANNEL` |
| `regen_rate` | units per second |
| `regen_delay` | seconds after last spend before regen resumes |

| Profile | `resource_max` | `cost` | `regen_rate` | `regen_delay` |
|---|---:|---:|---:|---:|
| `res_light` | `100.0` | `25.0` | `12.0` | `1.0` |
| `res_heavy` | `100.0` | `60.0` | `8.0` | `2.0` |
| `res_drain` | `100.0` | `10.0` | `6.0` | `1.5` |

Pools are **per-host**. There is no universal mana. Two hosts share a pool only through an explicit `LINK` Mod (§16.2), and a linked pool uses the larger `resource_max` of the two.

## 12.5 `COOLDOWN`

| Parameter | Meaning |
|---|---|
| `charge_count` | maximum charges, `1` to `3` |
| `recharge_time` | seconds per charge |

| Profile | `charge_count` | `recharge_time` |
|---|---:|---:|
| `cd_single_short` | `1` | `6.0` |
| `cd_single_long` | `1` | `18.0` |
| `cd_double` | `2` | `10.0` |
| `cd_triple` | `3` | `8.0` |

Charges recharge **serially**. Only one charge is ever in progress. A second missing charge begins recharging only when the first completes. Parallel hidden cooldowns are rejected by the Player Authority §13.2 and are not implemented.

## 12.6 `ACTION`

| Parameter | Meaning |
|---|---|
| `fact` | which verb or metric advances progress |
| `threshold` | progress required for readiness |
| `contribution` | progress added per occurrence |
| `decay_rate` | progress lost per second, `0.0` for none |

The `fact` catalog is closed. These are the only legal facts:

| Fact | Advances on |
|---|---|
| `MELEE_HIT` | each baseline melee hit that dealt Health damage |
| `WEAPON_KILL` | each kill credited to a Weapon |
| `AIRBORNE_KILL` | each kill where the victim was not grounded |
| `OVERCRIT` | each hit at `crit_tier >= 2` |
| `DISTANCE_MOVED` | metres of player ground movement |
| `DAMAGE_TAKEN` | points of Health lost |
| `DAMAGE_BLOCKED` | points absorbed by Barrier |
| `STATUS_APPLIED` | each successful Status application by the player |
| `INTERACT_USED` | each successful `F` interaction |
| `WEAPON_CYCLED` | each cycle to a different Weapon |

| Profile | `fact` | `threshold` | `contribution` | `decay_rate` |
|---|---|---:|---:|---:|
| `act_melee_three` | `MELEE_HIT` | `3.0` | `1.0` | `0.0` |
| `act_kills_two` | `WEAPON_KILL` | `2.0` | `1.0` | `0.0` |
| `act_airborne_one` | `AIRBORNE_KILL` | `1.0` | `1.0` | `0.05` |
| `act_overcrit_four` | `OVERCRIT` | `4.0` | `1.0` | `0.0` |
| `act_distance_forty` | `DISTANCE_MOVED` | `40.0` | `1.0` | `0.0` |
| `act_blocked_150` | `DAMAGE_BLOCKED` | `150.0` | `1.0` | `0.0` |
| `act_status_three` | `STATUS_APPLIED` | `3.0` | `1.0` | `0.0` |

Facts are **facts about simulation**, never UI events. `WEAPON_CYCLED` counts an actual configuration change, not a wheel input that was skipped or blocked.

Progress is capped at `threshold`. Excess is discarded, so a build cannot bank readiness.

## 12.7 Hybrids

Exactly five templates. Each has three magnitudes. No other hybrid exists.

| Template | Applies to | `SMALL` | `MEDIUM` | `LARGE` |
|---|---|---|---|---|
| `KILL_ACCELERATES_COOLDOWN` | `COOLDOWN` | `−0.5 s` per kill | `−1.5 s` | `−3.0 s` |
| `ACTION_DISCOUNTS_RESOURCE` | `RESOURCE` | `−10%` cost while action complete | `−25%` | `−40%` |
| `ACTION_PROGRESS_DECAYS` | `ACTION` | `decay_rate 0.05/s` | `0.15/s` | `0.30/s` |
| `OVERCRIT_GENERATES_RESOURCE` | `RESOURCE` | `+4` per overcrit | `+10` | `+20` |
| `MOVEMENT_ADVANCES_COOLDOWN` | `COOLDOWN` | `−0.02 s` per metre | `−0.05 s` | `−0.10 s` |

**Contribution cap:** hybrid acceleration may reduce an effective recharge by at most `60%` of its base. A `cd_single_long` at `18.0 s` never recharges faster than `7.2 s` regardless of kills.

**Loop prevention:** a hybrid may never be advanced by an event its own host produced. An `OVERCRIT_GENERATES_RESOURCE` ability whose own damage overcrits generates nothing from that overcrit. This is checked at the event source, not by cycle detection, and it is the complete answer to self-feeding loops in Reliable Core.

**No hidden second tax.** A `COOLDOWN` ability never also requires a Resource pool, and a `RESOURCE` ability never also has charges. The identity is the constraint. The hybrid modifies recharge; it never adds a second cost.

## 12.8 Runtime persistence

Ability runtime state is `ZONE_PERSISTENT` per §5.6. Regeneration, recharge, and decay run only while the player is in a Zone and not paused. They do not advance at the Hub, during a load, or while the game is paused.

## 12.9 The compatibility matrix

A `(family, activation, recharge)` triple not in this table is a hard error at load. `●` = legal.

| Family | `PRESS` | `HOLD` | `CHARGE_RELEASE` | `CHANNEL` | `RESOURCE` | `COOLDOWN` | `ACTION` |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| `PROJECTILE_ATTACK` | ● | | ● | | ● | ● | ● |
| `AREA_BURST` | ● | | ● | | ● | ● | ● |
| `BARRIER_GRANT` | ● | ● | | | ● | ● | ● |
| `HEAL_CHANNEL` | | | | ● | ● | | ● |
| `DEPLOYABLE_TURRET` | ● | | | | ● | ● | ● |
| `DEPLOYABLE_FIELD` | ● | | | | ● | ● | ● |
| `STATUS_APPLICATOR` | ● | | ● | | ● | ● | ● |
| `MARK_REVEAL` | ● | | | | | ● | ● |
| `PHYSICS_VERB` | ● | ● | | | ● | ● | |
| `DASH_IMPULSE` | ● | | | | ● | ● | ● |
| `WEAPON_BUFF` | ● | | | | ● | ● | ● |
| `TEMPORARY_RULE` | ● | | | | ● | ● | ● |

Notable exclusions and why:

- `HEAL_CHANNEL` is `CHANNEL`-only, because a press-to-heal is a different design (a burst heal) and Reliable Core ships one healing shape. It cannot be `COOLDOWN`, because a channel whose readiness is a charge would let the player pay once and channel indefinitely.
- `PHYSICS_VERB` cannot be `ACTION`, because physics is a puzzle tool and gating a puzzle tool behind a combat verb creates the possibility of a player standing in a room unable to progress. This matters for §29 and is not a balance choice.
- `MARK_REVEAL` cannot be `RESOURCE`, because an information ability with a drainable pool is an information ability the player rations, which defeats its purpose.
- `HOLD` is limited to `BARRIER_GRANT` and `PHYSICS_VERB`, the only two families whose effect is meaningfully continuous without being a channel.

**`HEAL_CHANNEL` bounds.** Each `0.5 s` sample restores `magnitude × 0.5` Health, clamped to maximum Health. A sample that would overheal restores only the deficit and still pays full cost. The channel ends automatically at full Health.

## 12.10 `TEMPORARY_RULE` catalog

Closed. These are the only rule changes an Ability may make.

| Rule | Effect for `duration` | `magnitude` means |
|---|---|---|
| `RULE_CRIT_FLOOR` | Player's `crit_chance` is at least `magnitude` | crit chance floor |
| `RULE_DEFENSE_ADD` | Player Defense `+magnitude` | Defense points |
| `RULE_STATUS_POTENCY` | Player's Status applications gain `+magnitude` chance | chance addend |
| `RULE_SPEED_ADD` | `WALK_SPEED × (1 + magnitude)` | fraction |
| `RULE_IMPULSE_IMMUNE` | Player ignores all incoming impulse | ignored |
| `RULE_MASS_LIGHT` | Player's mass class treated as `LIGHT` by wind and conveyors | ignored |

Two instances of the same rule do not stack; the later replaces the earlier and resets the duration.

---

# 13. MOBILITY

## 13.1 The five families

| Family | Behavior | Grants capability |
|---|---|---|
| `DASH` | Instant horizontal displacement along input direction | `capability:core:long_gap` if `distance >= 8.0` |
| `GRAPPLE` | Fires an anchor; pulls the player toward it | `capability:core:grapple` |
| `BLINK` | Instant teleport to a validated point along view | `capability:core:blink` |
| `BURST_JUMP` | Vertical impulse, usable once airborne | `capability:core:long_gap` if `impulse >= 9.0` |
| `AIR_STEP` | One additional full jump while airborne | none |

| Profile | Family | Key parameters |
|---|---|---|
| `mob_dash_short` | `DASH` | `distance 7.0`, `travel_time 0.15`, ground and air |
| `mob_dash_long` | `DASH` | `distance 11.0`, `travel_time 0.22`, ground and air |
| `mob_grapple_standard` | `GRAPPLE` | `range 30.0`, `pull_speed 22.0`, `anchor_travel_speed 90.0` |
| `mob_grapple_long` | `GRAPPLE` | `range 45.0`, `pull_speed 26.0`, `anchor_travel_speed 110.0` |
| `mob_blink_short` | `BLINK` | `range 12.0` |
| `mob_blink_long` | `BLINK` | `range 20.0` |
| `mob_burst_standard` | `BURST_JUMP` | `impulse 8.5 m/s` |
| `mob_burst_high` | `BURST_JUMP` | `impulse 11.0 m/s` |
| `mob_airstep_standard` | `AIR_STEP` | one extra jump at `JUMP_VELOCITY` |

## 13.2 Ground and air legality

| Family | Ground | Air | Notes |
|---|:-:|:-:|---|
| `DASH` | ● | ● | Air dash does not zero vertical velocity |
| `GRAPPLE` | ● | ● | |
| `BLINK` | ● | ● | |
| `BURST_JUMP` | | ● | Grounded use is a preflight failure |
| `AIR_STEP` | | ● | Refreshes on ground contact, not on grapple or dash |

## 13.3 Common movement safety

Every Mobility action, before commit, validates its destination:

1. The destination capsule must not intersect world geometry.
2. A capsule sweep from origin to destination must not pass fully through a `signal_blocking` or solid surface. Passing through actors is permitted.
3. The destination must be within `range` or `distance` of the origin.

Failing any check is a **preflight failure**: nothing is spent, and the rejection names the reason.

For `DASH` and `BLINK`, if the direct destination fails, the system retries at `90%`, `75%`, `50%`, and `25%` of the distance, in that order, and commits at the first that passes. Only if all five fail is it a preflight failure. This is why dashing into a wall moves you up to the wall rather than doing nothing.

**Cancellation.** `DASH` and `BLINK` are instantaneous and cannot be cancelled. `GRAPPLE` is cancellable at any point by pressing `mobility` again, by jumping, or by taking any damage; cancellation costs nothing additional because the cost was committed at fire. `BURST_JUMP` and `AIR_STEP` are instantaneous.

**Collision recovery.** If a Mobility action nonetheless places the player intersecting geometry — possible when geometry moves during a dash — the player is pushed to the nearest non-intersecting point within `2.0 m`. If none exists, out-of-bounds recovery (§6.3) runs.

## 13.4 `GRAPPLE` specifics

1. On activation an anchor projectile travels at `anchor_travel_speed` up to `range`.
2. It attaches on contact with a surface tagged `grapple_compatible` or with any `FIXED` mass-class object. Contact with anything else fails the grapple; the cost is already committed.
3. On attachment the player is pulled toward the anchor at `pull_speed`, with gravity suspended.
4. The pull ends when the player is within `2.0 m` of the anchor, on cancellation, or after `4.0 s`.
5. On ending, the player retains their current velocity. This is what makes grapple traversal feel like momentum rather than teleportation.

Grapple targets are room content (§18 of the Dungeon Authority). A mandatory grapple route requires `capability:core:grapple` proven by §29.

**No spring dynamics.** The pull is a constant-speed move toward the anchor, not a simulated spring. This is a deliberate Reliable Core simplification: springs are tunable, expressive, and a persistent source of edge cases where the player oscillates, clips, or accumulates unbounded velocity. Constant-speed pull has none of those and reads nearly identically at the speeds involved.

## 13.5 `BLINK` specifics

The destination is the first of:

1. The point at `range` along the view direction, if unobstructed.
2. The last unobstructed point before the first surface hit along that ray, offset back by the capsule radius.

The destination is then snapped down to the floor if a floor exists within `3.0 m` below it; otherwise the player blinks into the air and falls. Blinking through a wall is impossible because rule 2 stops at the first surface.

## 13.6 Mandatory-route contracts

A route is mandatory if removing it disconnects the Zone spine. A mandatory route may require at most one capability, and that capability must be one of the four in §29.1.

Mandatory routes are validated against the movement law in §6.2 **plus** the least capable profile that actually grants the required capability. "Least capable that grants" matters: `mob_dash_short` at `7.0 m` is below the `8.0 m` threshold and therefore grants nothing, so it is never the validation basis.

The granting profiles per capability, and the resulting validation contract:

| Capability | Granting profiles | Mandatory route must satisfy |
|---|---|---|
| `capability:core:grapple` | `mob_grapple_standard` (`30.0 m`), `mob_grapple_long` | Anchor within `30.0 m` of a reachable standing position, with line of sight |
| `capability:core:blink` | `mob_blink_short` (`12.0 m`), `mob_blink_long` | Destination within `12.0 m`, unobstructed, with a floor within `3.0 m` below |
| `capability:core:long_gap` | `mob_dash_long` (`11.0 m`), `mob_burst_high` (`11.0 m/s`) | Horizontal gap at most `9.0 m`, with the landing surface no higher than `MAX_SAFE_STEP_UP` (`1.145 m`) above the launch surface |

**`long_gap` is a horizontal capability only.** This matters, because its two granting profiles have different shapes and a mandatory route must be crossable by **both**:

- `mob_dash_long` displaces `11.0 m` horizontally and adds no height. A player jumps, reaches the `1.245 m` apex, dashes `11.0 m`, and lands. It clears `9.0 m` horizontal with `2.0 m` of margin, but it cannot gain height beyond the base jump.
- `mob_burst_high` adds `11.0 m/s` vertical at the apex, for an extra `2.75 m` of height and roughly `12.6 m` of horizontal reach at `WALK_SPEED` over the resulting airtime. It clears both bounds comfortably.

The binding constraint is therefore `mob_dash_long`'s lack of vertical gain, which is why the landing surface may be no higher than a plain base jump could already reach. A route needing both extra distance **and** extra height is not expressible as a `long_gap` requirement, and the planner must not emit one.

---

# 14. PHYSICS ECHOES

Four primitives. Reliable Core deliberately implements the smallest set that supports the Dungeon Authority's puzzle families without approaching telekinesis.

## 14.1 The primitives

| Primitive | Effect |
|---|---|
| `PUSH` | Applies an impulse away from the player along the view ray |
| `PULL` | Applies an impulse toward the player along the view ray |
| `HOLD` | While held, moves the target to a fixed carry point and keeps it there |
| `ALIGN` | Rotates the target to the nearest axis-aligned orientation and holds it for `2.0 s` |

## 14.2 Eligibility

A target is eligible only if **all** of:

| Condition | Rule |
|---|---|
| Mass class | `LIGHT` or `MEDIUM`. `HEAVY` responds to `PUSH` and `PULL` at `25%` force. `FIXED` never responds. |
| Distance | Within the profile's `range` |
| Line of sight | Unobstructed from eye to target origin |
| Tag | Object's `physics_eligible` is true |
| Actor rule | Enemies: `PUSH` and `PULL` only, never `HOLD` or `ALIGN`. The player is never a target. |
| Progression rule | An object with `required = true` is eligible **only if** its package's manifest sets `physics_permitted = true` |

The progression rule is the answer to Player Authority §35.6 test 31: a required key component that is physically light is still not manipulable unless its package explicitly allows it. Physical lightness is not permission.

Bosses are never eligible for any Physics primitive.

## 14.3 Behavior

| Profile | `range` | `force` (N) | `hold_distance` | `hold_max_mass` | `max_relations` |
|---|---:|---:|---:|---|---:|
| `phys_light` | `15.0` | `600.0` | `3.0` | `LIGHT` | `1` |
| `phys_standard` | `18.0` | `900.0` | `3.5` | `MEDIUM` | `1` |
| `phys_strong` | `22.0` | `1400.0` | `4.0` | `MEDIUM` | `2` |

Rules:

- **`max_relations`** caps simultaneous held or aligned objects. A new `HOLD` beyond the cap releases the oldest.
- **`HOLD` releases** on: input release, target leaving `range × 1.5`, line of sight blocked for `0.5 s`, player death, room unload, or the target being destroyed.
- **Held objects collide with world geometry** and stop against it; they do not clip. A held object crushed between the carry point and geometry releases.
- **A held object passes through actors**, exactly as a carried object does.
- **`ALIGN`** snaps rotation over `0.3 s` and then holds orientation for `2.0 s`, during which the object still responds to gravity and translation. It is a rotation tool, not a freeze.
- **Impulse from `PUSH`/`PULL`** is `force / mass`, where `LIGHT = 20 kg`, `MEDIUM = 80 kg`, `HEAVY = 300 kg`. Resulting velocity is clamped to `25.0 m/s`.

**Physics cannot move the player.** No primitive applies force to the player, and no primitive may be aimed at a surface to generate reaction force. This closes the rocket-jump, infinite-staircase, and crate-railgun cases in the Player Authority §17.4 by removing the mechanism rather than by capping it.

**Upward energy limit:** the vertical component of any physics-imparted velocity is clamped to `12.0 m/s`. An object cannot be launched arbitrarily high to build a platform.

## 14.4 Impact damage

A physics-moved object that strikes an actor deals damage:

```
damage = clamp((speed − 8.0) × mass_factor, 0.0, 45.0)
mass_factor: LIGHT 1.0, MEDIUM 2.2, HEAVY 4.0
```

| Rule | Value |
|---|---|
| Speed threshold | `8.0 m/s`. Below this, no damage. |
| Damage ceiling | `45.0` per impact, hard |
| Tags | `PHYSICS` |
| Crit eligible | **no** |
| Re-hit cooldown | `1.0 s` per (object, target) pair |
| Damage to the player from player-owned objects | `0.0` |
| Provenance | `source_actor` = the player if the object was moved by the player within the last `3.0 s`, else null |

The `1.0 s` re-hit cooldown per pair is what prevents a jittering or resting object from repeatedly damaging. The ceiling is what prevents "accelerate a coffee mug to relativistic speed" from being the optimal boss strategy.

## 14.5 Physics and progression

**No mandatory route or puzzle solution in Reliable Core requires a Physics Echo.** Physics is always an optional alternate solution. This is stronger than the authorities require — they permit a guaranteed physics gate — and it is taken deliberately: it removes physics from the capability planner entirely, which removes an entire class of "generated Zone is unwinnable" failures.

The cost is that physics can never be the point of a puzzle, only a shortcut through one. §40 records this.

---

# 15. STATUS

## 15.1 The six Statuses

None deals damage, directly or indirectly. All change rules.

### `status:core:burning` — family `THERMAL`
| Property | Value |
|---|---|
| Duration | `6.0 s` |
| Base chance | `0.35` |
| On enemy | AI enters `PANIC`: movement direction randomised every `0.5 s`, no attacks, no ability use |
| On object | Ignites if material is `burnable`, spawning a Fire Actor (§25.2) |
| On player | Screen edge effect; no mechanical penalty |
| Emits | Light, radius `6.0 m`; satisfies `light_sensitive` receivers |

The Fire Actor is a **separate world object** with its own damage volume, lifetime, and provenance. `BURNING` creates it on flammable material; the Status itself never touches Health. This is the exact structure the Player Authority §20.2 mandates, and the no-DoT law is not bypassable by attaching a damaging helper to the Status.

### `status:core:lightened` — family `KINETIC`
| Property | Value |
|---|---|
| Duration | `8.0 s` |
| Base chance | `0.40` |
| Effect | Mass class drops one step (`HEAVY`→`MEDIUM`→`LIGHT`); `LIGHT` unchanged |
| Consequence | Becomes Physics-eligible if it was `HEAVY`; incoming impulse ×`2.0`; wind and conveyors now affect it |
| On player | Incoming impulse ×`2.0`; jump unchanged |

`LIGHTENED` is the load-bearing Status for build interaction. It is the reason a Physics build wants a Status applicator, and it is the concrete example the Player Authority §2.6 uses.

### `status:core:anchored` — family `KINETIC`
| Property | Value |
|---|---|
| Duration | `4.0 s` |
| Base chance | `0.30` |
| Effect | Mass class becomes `FIXED`; immune to all impulse, Physics, wind, and conveyors |
| On enemy | Movement speed `0.0`; may still attack and use abilities |
| On player | Movement speed `0.0`; jump blocked; all other actions permitted |

### `status:core:confused` — family `COGNITIVE`
| Property | Value |
|---|---|
| Duration | `5.0 s` |
| Base chance | `0.30` |
| On enemy | Target selection ignores faction: targets the nearest actor of any faction, including its own |
| On player | Not applicable; enemies cannot apply Status to the player in Reliable Core |

### `status:core:turncoat` — family `COGNITIVE`
| Property | Value |
|---|---|
| Duration | `8.0 s` |
| Base chance | `0.15` |
| On enemy | Faction becomes `PLAYER`. Targets hostiles. Reverts on expiry at current Health. |
| Kill credit | A turncoat's kills credit **to the player** |
| On boss | Substituted with `CONFUSED` at the same duration (§15.4) |

### `status:core:exposed` — family `COGNITIVE`
| Property | Value |
|---|---|
| Duration | `6.0 s` |
| Base chance | `0.35` |
| Effect | Target Defense set to `0.0`; incoming `crit_chance` `+1.0` |
| On player | Same |

## 15.2 Application

```
effective_chance = clamp(
    base_chance
  + source_potency
  + susceptibility
  − resistance
  − adaptation,
  0.05, 0.95)
```

| Term | Source | Range |
|---|---|---|
| `base_chance` | The Status definition | fixed per Status |
| `source_potency` | `STATUS_APPLICATOR` `magnitude`, or the Weapon/Ability `status_chance` field | `0.0` to `0.40` |
| `susceptibility` | Pity, accumulated on failure | `0.0` to `0.45` |
| `resistance` | Target archetype (§32.2) | `0.0` to `0.40` |
| `adaptation` | Accumulated on success | `0.0` to `0.50` |

The clamp to `[0.05, 0.95]` guarantees that no target is ever fully immune through arithmetic and no application is ever certain. True immunity is a separate explicit mechanism (§15.4).

**Pity and adaptation are tracked per `(target_actor, status_family)`**, not per Status. Failing to apply `LIGHTENED` builds susceptibility to `ANCHORED` as well, because both are `KINETIC`. This is what makes the three families meaningful rather than decorative.

| Event | Change |
|---|---|
| Application fails | `susceptibility += 0.15`, capped at `0.45` |
| Application succeeds | `susceptibility = 0.0`; `adaptation += 0.20`, capped at `0.50` |
| Per second, no application attempt | `adaptation −= 0.05`, floored at `0.0` |
| Target dies | Both discarded with the actor |

Susceptibility does not decay. It persists until a success clears it. This means a player who keeps trying always eventually succeeds, which is the point of visible pity.

## 15.3 Duration, stacking, and refresh

- Statuses **do not stack**. `stacks` is `false` for all six.
- Re-applying an active Status **refreshes** its duration to full and does not extend beyond it.
- A target may carry multiple **different** Statuses simultaneously. `ANCHORED` and `LIGHTENED` are mutually exclusive; applying either removes the other, since one sets mass to `FIXED` and the other reduces it.
- Statuses are `EPHEMERAL`. They do not survive save/load (§5.11), death, or room unload.

## 15.4 Immunity and substitution

Preferred order when a target cannot take a Status:

1. **Reduced expression.** A boss takes `CONFUSED` where a standard enemy would take `TURNCOAT`.
2. **Higher resistance.** Bosses have `resistance = 0.40` for all families.
3. **True immunity**, only where the effect is mechanically nonsensical.

| Target | Immune to | Substitution |
|---|---|---|
| Boss | `TURNCOAT` | `CONFUSED`, same duration |
| Boss | `ANCHORED` | `EXPOSED`, half duration |
| Turret (immobile) | `ANCHORED`, `LIGHTENED` | none; attempt fails visibly |
| Fire Actor | all | none |

A substituted application still consumes the attempt and still resolves pity and adaptation against the family of the **original** Status.

## 15.5 Required feedback

Every application attempt produces visible feedback regardless of outcome. A failed attempt that produces nothing is forbidden — it is indistinguishable from a bug.

| Outcome | Feedback |
|---|---|
| Success | Status VFX on target; HUD status row appears; audio cue |
| Failure | Distinct "resisted" VFX; the susceptibility meter on the target's nameplate visibly advances |
| Substituted | The substituted Status's VFX plus a distinct substitution audio cue |
| Immune | A distinct "immune" VFX; no meter advance |

---

# 16. GEAR, MODS, AND RULES

## 16.1 Gear

Four slots. `USEFUL` Gear has exactly one intrinsic; `HIGH` Gear has exactly two. Exactly one `HIGH` piece may be equipped across the four slots.

Intrinsic templates are constrained by territory. This is what makes the territories mechanical rather than flavour.

| Territory | Legal intrinsic templates |
|---|---|
| `HEAD` | `INT_MARK_ON_HIT`, `INT_OVERCRIT_ADVANCES_ABILITY`, `INT_STATUS_POTENCY`, `INT_REVEAL_INTERACTABLES`, `INT_CRIT_CHANCE` |
| `TORSO` | `INT_MAX_HEALTH`, `INT_BARRIER_ON_KILL`, `INT_DEFENSE`, `INT_RESOURCE_REGEN`, `INT_BARRIER_ON_DAMAGE` |
| `ARMS` | `INT_MELEE_DAMAGE`, `INT_RELOAD_SPEED`, `INT_HEAT_CAPACITY`, `INT_PHYSICS_FORCE`, `INT_INTERACT_RANGE` |
| `LEGS` | `INT_MOVE_SPEED`, `INT_JUMP_HEIGHT`, `INT_MOBILITY_RECHARGE`, `INT_LANDING_CONTROL`, `INT_RAIL_CONTROL` |

Magnitudes:

| Template | `SMALL` | `MEDIUM` | `LARGE` |
|---|---|---|---|
| `INT_MARK_ON_HIT` | mark `2 s` | `4 s` | `7 s` |
| `INT_OVERCRIT_ADVANCES_ABILITY` | `+0.5` progress | `+1.0` | `+2.0` |
| `INT_STATUS_POTENCY` | `+0.05` | `+0.12` | `+0.20` |
| `INT_REVEAL_INTERACTABLES` | `10 m` | `20 m` | `35 m` |
| `INT_CRIT_CHANCE` | `+0.08` | `+0.18` | `+0.32` |
| `INT_MAX_HEALTH` | `+15` | `+35` | `+60` |
| `INT_BARRIER_ON_KILL` | `+10` | `+25` | `+45` |
| `INT_DEFENSE` | `+20` | `+50` | `+90` |
| `INT_RESOURCE_REGEN` | `+15%` | `+35%` | `+60%` |
| `INT_BARRIER_ON_DAMAGE` | `+8` per `100` taken | `+18` | `+32` |
| `INT_MELEE_DAMAGE` | `+20%` | `+50%` | `+90%` |
| `INT_RELOAD_SPEED` | `+12%` | `+28%` | `+45%` |
| `INT_HEAT_CAPACITY` | `+15%` | `+35%` | `+60%` |
| `INT_PHYSICS_FORCE` | `+20%` | `+50%` | `+85%` |
| `INT_INTERACT_RANGE` | `+0.5 m` | `+1.2 m` | `+2.0 m` |
| `INT_MOVE_SPEED` | `+5%` | `+11%` | `+18%` |
| `INT_JUMP_HEIGHT` | `+8%` | `+18%` | `+30%` |
| `INT_MOBILITY_RECHARGE` | `+12%` | `+28%` | `+45%` |
| `INT_LANDING_CONTROL` | air accel `+25%` | `+55%` | `+90%` |
| `INT_RAIL_CONTROL` | rail speed `+10%` | `+22%` | `+38%` |

`INT_JUMP_HEIGHT` is the one intrinsic that changes the movement law. It **raises** the player's jump above the validated baseline, so it never invalidates a mandatory route; validators always use base `JUMP_APEX`. No intrinsic may ever reduce a movement constant, for the same reason.

## 16.2 Mod templates

| Family | Meaning |
|---|---|
| `AUGMENT` | Modifies a host parameter |
| `REPLACEMENT` | Substitutes one profile for another |
| `TRIGGER` | Fires an effect on a defined event |
| `PASSIVE` | Unconditional modifier while the host is equipped |
| `CONVERSION` | Changes a host's type-level property |

| Template | Family | Effect (`SMALL` / `MEDIUM` / `LARGE`) | Legal hosts |
|---|---|---|---|
| `MOD_DAMAGE` | `AUGMENT` | `+10% / +22% / +38%` damage | Weapon, Ability |
| `MOD_RATE` | `AUGMENT` | `−8% / −16% / −26%` interval | Weapon |
| `MOD_CAPACITY` | `AUGMENT` | `+20% / +45% / +75%` magazine or heat max | Weapon |
| `MOD_RANGE` | `AUGMENT` | `+15% / +35% / +60%` range | Weapon, Ability, Mobility |
| `MOD_RECHARGE` | `AUGMENT` | `−10% / −22% / −35%` recharge time or cost | Ability, Mobility |
| `MOD_STATUS_CHANCE` | `AUGMENT` | `+0.05 / +0.12 / +0.20` | Weapon, Ability |
| `MOD_ADD_STATUS` | `CONVERSION` | Host applies a named Status at `0.15 / 0.25 / 0.35` | Weapon, Ability |
| `MOD_PROFILE_SWAP` | `REPLACEMENT` | Host uses a different legal profile of its family | Weapon, Ability, Mobility |
| `MOD_GRAPPLE_SECONDARY` | `REPLACEMENT` | Weapon secondary becomes a `GRAPPLE`-family action | Weapon |
| `MOD_ON_KILL_BARRIER` | `TRIGGER` | `+15 / +30 / +50` Barrier on kill | Weapon, Ability, Gear |
| `MOD_ON_KILL_INVULN` | `TRIGGER` | `0.4 s / 0.8 s / 1.2 s` invulnerability on kill, `4.0 s` internal cooldown | Gear |
| `MOD_ON_OVERCRIT_RECHARGE` | `TRIGGER` | Advances a named Ability by `0.5 / 1.0 / 2.0` progress | Weapon, Gear |
| `MOD_ON_STATUS_DAMAGE` | `TRIGGER` | `+8% / +18% / +30%` damage to Status-affected targets | Weapon, Ability |
| `MOD_LINK` | `CONVERSION` | Links this host's Resource pool to a named host's | Ability, Mobility |
| `MOD_DEFENSE` | `PASSIVE` | `+15 / +35 / +60` Defense | Gear |
| `MOD_PENETRATION` | `PASSIVE` | `+0.10 / +0.22 / +0.35` penetration | Weapon |
| `MOD_TRAP_UNSTABLE` | `PASSIVE` | `+25% / +45% / +70%` damage; `+30% / +50% / +80%` self-damage taken from own explosives | Weapon |
| `MOD_TRAP_GREEDY` | `PASSIVE` | `+30% / +55% / +90%` Resource regen; `−15% / −25% / −40%` max Health | Gear |

`MOD_TRAP_*` templates are the mechanical expression of foreign trap items: real, bounded, visible tradeoffs (§17.2).

## 16.3 Compatibility

- A Mod may attach only to a host whose `category` appears in its `host_categories`.
- `MOD_ADD_STATUS` requires the host's `status_applied` to be null. A host that already applies a Status rejects it.
- `MOD_PROFILE_SWAP` requires the named profile to be legal for the host's family.
- `MOD_GRAPPLE_SECONDARY` requires the host's `secondary` to be null.
- `MOD_LINK` requires the named host to be equipped and to have `recharge.identity == RESOURCE`. If the named host is unequipped at commit, the Loadout is invalid.
- `MOD_ON_OVERCRIT_RECHARGE` requires the named Ability to be equipped and to have `recharge.identity == ACTION`.
- **Duplicate templates on one host do not stack.** Only the highest magnitude applies. The lower is inert but remains installed and visible, marked as superseded.

## 16.4 Modifier order

Modifiers apply in this order. Order matters and is fixed.

1. `REPLACEMENT` — profile swaps resolve first, so later modifiers act on the final profile.
2. `CONVERSION` — type-level changes.
3. `PASSIVE` and `AUGMENT` additive terms, summed.
4. `PASSIVE` and `AUGMENT` multiplicative terms, applied to the result of step 3 as a product.
5. Gear intrinsics, additive then multiplicative, in the same two-step pattern.
6. `TEMPORARY_RULE` effects.
7. Clamps from §16.5.

Within a step, order is by host slot in the fixed order: Weapons 0–2, Abilities Q, E, 1, 2, 3, Mobility, Gear Head, Torso, Arms, Legs; then by Mod index within each host. This makes the result fully deterministic.

**Trigger ordering:** when one event fires multiple `TRIGGER` Mods, they resolve in the same host order. A trigger that fires during another trigger's resolution is queued and resolves after, never recursively. Queue depth is capped at `8`; triggers beyond that are discarded for that event.

## 16.5 Runtime limits

Hard clamps applied after all modifiers. These exist so no combination produces a degenerate build.

| Quantity | Clamp |
|---|---|
| Weapon `interval` | minimum `0.05 s` |
| Player Defense | maximum `400.0` |
| Penetration | maximum `0.60` |
| Player Barrier pool | maximum `400.0` |
| Player max Health | `50.0` to `250.0` |
| `crit_chance` | maximum `4.0` (tier 4) |
| `WALK_SPEED` multiplier | `1.0` to `1.45` |
| Status effective chance | `0.05` to `0.95` |
| Recharge reduction from all sources | maximum `60%` of base |
| Invulnerability uptime | maximum `25%` over any `10 s` window |

The invulnerability clamp is enforced by a rolling window: if granting invulnerability would exceed `2.5 s` within the trailing `10 s`, the grant is truncated to fit.

---

# 17. FOREIGN ITEMS, ARCHIVE, AND MIGRATION

## 17.1 Interpretation

An incoming AP item becomes exactly one Archipepsi object, chosen by its AP classification:

| AP classification | Becomes | Tier |
|---|---|---|
| `filler` | Mod | — |
| `trap` | Mod, `trap_flavor = true`, template drawn from `MOD_TRAP_*` or any `AUGMENT` | — |
| `useful` | Weapon, Ability, Mobility, or Gear | `USEFUL` |
| `progression` | Weapon, Ability, Mobility, or Gear | `HIGH` |

Another game's `progression` flag determines **tier**, never Archipepsi capability truth. A foreign progression item becomes a high-tier host; it does not become a capability guarantee. Capability truth comes only from §29.

## 17.2 The interpretation request

Epsilon receives:

- The item name, its source game, and its AP classification.
- The legal category set for that classification.
- For each legal category, the family list and each family's legal profile list.
- The Status catalog.
- The current campaign's already-used display names, to avoid duplicates.

Epsilon returns:

```
InterpretationResponse:
  category          : one of the offered categories
  family            : one of that category's families
  profile           : one of that family's legal profiles
  secondary_kind    : one of the legal secondary kinds, or null   # WEAPON only
  secondary_profile : legal for secondary_kind, or null
  feed_model        : one of MAGAZINE, HEAT, CHARGE, NONE          # WEAPON only
  feed_profile      : legal for feed_model                          # WEAPON only
  activation        : legal for family                              # ABILITY only
  recharge_identity : legal for (family, activation)                # ABILITY, MOBILITY
  recharge_profile  : legal for recharge_identity
  territory         : HEAD | TORSO | ARMS | LEGS                    # GEAR only
  intrinsics        : list of (template, magnitude), correct length # GEAR only
  status_applied    : a Status id or null
  display_name      : string
  flavor_text       : string
  accent_set        : one of the offered accent sets
```

Every field is a selection from an enumerated set. **Epsilon emits no numbers** except `magnitude`, which is itself a three-valued enum.

The response is validated against every constraint in §4 and §12.9. Any violation rejects the whole response and falls through to §17.5.

## 17.3 Duplicates

Two different AP items may produce identical mechanical content. That is fine and expected; they remain separate Archive entries with separate provenance.

Two receipts of the **same** AP item produce one Archive entry with `rank` incremented, for Mods only. Hosts are never ranked; a second copy of the same host item is a second independent entry with its own `id`.

Mod `rank` has no mechanical effect in Reliable Core — there is no Forge to consume it. It exists so that provenance and counts are correct when Forge is added later, and so that the Archive does not show four hundred identical rows.

## 17.4 Migration from existing saves

The current executable's four-slot Echo model does not map onto the new host categories. Migration:

1. Every existing Echo becomes an Archive entry with `interpretation_by = FALLBACK` and its original provenance preserved.
2. Its mechanical content is **discarded** and regenerated deterministically per §17.5 from its provenance.
3. The entry's `@rev` is incremented.
4. The player's committed Loadout is cleared. On next Hub visit they are shown the migration notice in §34.12 and must commit a new Loadout.
5. All Zone state is discarded. Zones regenerate from their seeds under the new composition rules.
6. AP truth — Checks, received items, Coins — is untouched.

Migration is one-way and runs once, detected by a save-format version field. A migrated save cannot be opened by the old executable.

## 17.5 Deterministic fallback

Used when Epsilon is unavailable, returns an invalid response, or times out after `10.0 s`.

```
h = SHA-256(campaign_seed || ap_item_id || host_category)
```

Successive 4-byte words of `h` index, modulo the list length, into: the category list, the family list, the profile list, and each remaining enumerated field in the schema order given in §17.2. `display_name` becomes the source item name verbatim. `flavor_text` becomes `""`. `accent_set` becomes `accent:core:neutral`.

The result is always valid by construction, because every index is taken modulo a legal list. It is fully reproducible: the same campaign and item always produce the same fallback.

**The game is completely playable with Epsilon offline.** The only loss is thematic interpretation — items are mechanically identical to what a model would have produced, since the model was only ever selecting from these same lists.

## 17.6 Archive behavior

The Archive holds every owned host and Mod. It is `AP_PERSISTENT`.

- Unequipped entries produce **zero** runtime work: no listeners, no reactions, no resource generation, no Status claims, no scheduler entries, no actors, no queries. This is testable and is test vector 46.
- The Archive is unbounded in size.
- Sorting, filtering, and favouriting are UI concerns with no mechanical effect.

---

# 18. ECONOMY

## 18.1 Forge

**Deferred.** No item synthesis exists in Reliable Core. Mods accumulate and are never consumed.

The cost: the Player Authority §26.3 describes a ~5 Mods → 1 Useful Echo → (×5) → 1 high-tier progression. Without it, build growth comes only from AP receipts, and a long campaign accumulates a large inert Mod collection. This is the single largest sacrifice in this proposal and §40 records it as such.

## 18.2 Epsilon Static

Received and banked. It has a counter in the UI and no sink. It is explicitly **not** ammunition, not mana, and not a per-cast cost, per Player Authority §14.2.

It exists in Reliable Core solely so that the AP item pool is correct and so that adding Forge later does not require a new item type.

## 18.3 Coins and Signal Keys

Pinned to the existing implementation. This proposal does not redefine them. The contract it depends on:

- Coins are an `AP_PERSISTENT` integer, spendable at Hub shops.
- Signal Keys are an `AP_PERSISTENT` integer, consumed to unlock Zone access.
- Neither is consumed by loadout editing, Mod installation, or removal — §22.4 of the Player Authority forbids a respec tax and this proposal honours it.

An implementer must read the existing shop and key implementation for their exact interfaces. What this document pins is that Reliable Core adds no new consumer of either.

---

# 19. SIGNAL GRAPH

## 19.1 Ports

| Form | Meaning |
|---|---|
| `OFF` | Boolean false |
| `ON` | Boolean true |
| `PULSE` | A single-tick event, not a state |
| `VALUE` | An integer in `[0, 15]` |

A port is one form. A node's input port accepts only its declared form; a graph connecting mismatched forms fails validation at composition, never at runtime.

`PULSE` is not a one-tick `ON`. A node reading a Boolean port sees `OFF` when a `PULSE` occurred; a node reading a pulse port sees the event. The distinction is why `LATCH` needs pulses and `AND` needs Booleans.

## 19.2 Node types

Eleven. This is the complete set.

| Node | Inputs | Output | Behavior |
|---|---|---|---|
| `DIRECT` | 1 Boolean | Boolean | Passes through |
| `AND` | 2–4 Boolean | Boolean | `ON` when all inputs `ON` |
| `OR` | 2–4 Boolean | Boolean | `ON` when any input `ON` |
| `NOT` | 1 Boolean | Boolean | Inverts |
| `TIMER` | 1 Pulse | Boolean | `ON` for `duration` after a pulse; a new pulse restarts it |
| `LATCH` | 2 Pulse (`set`, `reset`) | Boolean | `ON` after `set`, `OFF` after `reset`; `set` wins on the same tick |
| `SEQUENCE` | `n` Pulse (2–6) | Boolean | `ON` when inputs pulse in index order with no out-of-order pulse; any out-of-order pulse resets progress to zero |
| `COUNTER` | 1 Pulse, 1 Pulse (`reset`) | Boolean | `ON` when pulse count reaches `target`; `reset` zeroes the count |
| `SELECTOR` | 1 Value | `n` Boolean | Output `i` is `ON` when input equals `i`, all others `OFF` |
| `DELAY` | 1 Boolean | Boolean | Mirrors input after `duration`, tracking both edges |
| `THRESHOLD` | 1 Value | Boolean | `ON` when input `>= threshold` |

## 19.3 Evaluation

The graph is a **directed acyclic graph**. Cycles are rejected at composition (§23.5) and can never exist at runtime.

Evaluation, once per simulation tick:

1. Sensors write their outputs.
2. Nodes evaluate in topological order, computed once at room load and cached.
3. Actuators read their inputs and update.

Because evaluation is topological and the graph is acyclic, a full propagation completes within one tick. There is no multi-tick settling, no oscillation, and no order dependence between sibling nodes.

**Pulses live for exactly one tick.** A pulse written in step 1 is visible to every node in step 2 of the same tick and is gone at the start of the next.

## 19.4 Latency and presentation

Logical state propagates instantly. The visible conduit pulse travelling along a wire is presentation and lags the logic; it never gates it.

A package needing genuine delay uses a `DELAY` node. Its `duration` is mechanical, and its conduit renders in a visually distinct "charging" style so the player can tell a mechanical delay from a cosmetic travel animation. This is the resolution of the Dungeon Authority §6.3 requirement.

## 19.5 Conduits

Conduits are presentation. They are **never destructible** and never carry state. Their states:

| State | Visual channels |
|---|---|
| `inactive` | dim, static, no audio |
| `active` | bright, steady flow animation, low hum |
| `pulse_travelling` | bright travelling band, directional, click on arrival |
| `blocked` | dim with a broken-segment pattern, no audio |
| `delayed` | filling-band animation showing remaining time, rising pitch |

Every state differs in **at least two** of brightness, pattern, motion, and audio. None is distinguished by hue alone, per Dungeon Authority §50.

## 19.6 Persistence

| Node | Category | What persists |
|---|---|---|
| `LATCH` | `PUZZLE_LOCAL` | Its Boolean state |
| `COUNTER` | `PUZZLE_LOCAL` | Its count |
| `SEQUENCE` | `PUZZLE_LOCAL` | Its progress index |
| `TIMER` | `EPHEMERAL` | Nothing; rebuilds as `OFF` |
| `DELAY` | `EPHEMERAL` | Nothing; rebuilds mirroring its input |
| All others | stateless | Nothing |

On reset, `PUZZLE_LOCAL` nodes return to their authored initial state.

---

# 20. INPUTS AND SENSORS

Nine types.

| Type | Output | Key parameters |
|---|---|---|
| `PRESSURE_PLATE` | Boolean | `accepts: list[MassClass]`, `min_mass_class` |
| `PULSE_BUTTON` | Pulse | — |
| `TIMED_BUTTON` | Boolean | `duration` |
| `LEVER` | Boolean | `initial_state` |
| `SHOOTABLE_TARGET` | Pulse or Boolean | `mode: PULSE \| TOGGLE`, `required_tags: list[DamageTag]` |
| `OBJECT_SOCKET` | Boolean | `accepts: list[string]`, `removable: bool` |
| `PROXIMITY_SENSOR` | Boolean | `filter: PLAYER \| ENEMY \| OBJECT_CLASS \| ANY`, `volume` |
| `ENCOUNTER_CLEAR` | Boolean | `encounter_id` |
| `HACK_TERMINAL` | Pulse or Value | `mode: PULSE \| VALUE`, `difficulty: 1..3` |

## 20.1 Pressure plate

`ON` while the total qualifying mass on the plate meets `min_mass_class`. Qualifying actors are those whose mass class appears in `accepts`.

**Mass is semantic, not summed physics mass.** A plate requiring `HEAVY` is satisfied by one `HEAVY` object or by the player if `PLAYER` mass class `MEDIUM` appears in `accepts` and `min_mass_class` is `MEDIUM` or below. It is **never** satisfied by accumulating light debris — three `LIGHT` objects do not make a `MEDIUM`. This is the closure for Dungeon Authority test 22 and it is a rule, not a tuning value.

A `LIGHTENED` object's reduced class is what the plate reads. A `LIGHTENED` heavy cube stops holding a `HEAVY` plate down. This is an intentional interaction and packages using both must account for it; the validator flags a package whose only solution uses a `HEAVY` plate and whose room contains a Status source capable of `LIGHTENED` only as a warning, not an error, since the player caused it and recovery exists.

## 20.2 Shootable target

A hit qualifies if the `DamageRequest`'s `tags` include at least one of `required_tags`. Default `required_tags` is `[RANGED]`, satisfied by Static Pulse.

**Every mandatory shootable target has `required_tags = [RANGED]`.** No mandatory target may require a tag Static Pulse does not produce. Optional targets may require `EXPLOSIVE` or `MELEE`.

Target state is readable at `60.0 m` — the Static Pulse range — through a shape and brightness change, not a hue change.

## 20.3 Hack terminal

See §22.

## 20.4 Deferred sensors

Not implemented: trip beam, sound sensor, water-level sensor, light-sensitive receiver as a *puzzle input* (light still affects `BURNING` visibility). Their absence removes stealth-adjacent packages and beam-blocking puzzles, consistent with the §2.2 deferral of routed beams.

---

# 21. ACTUATORS AND MACHINERY

## 21.1 Common contract

Every actuator has:

```
Actuator:
  id                : Id
  kind              : enum { DOOR, BRIDGE, MOVING_PLATFORM, LIFT, PATH_MACHINE,
                             RAIL_SWITCH, LAUNCHPAD, HAZARD_CONTROLLER, LIGHT_CONTROLLER }
  input_port        : Id
  travel_time       : Seconds
  initial_t         : float in [0.0, 1.0]
  path              : list[transform], length >= 2      # kinematic waypoints
  safe_closure      : bool = true
```

All machinery is **kinematic**: it moves along `path` by interpolating `t`, and is never physics-simulated. It pushes actors it collides with rather than being blocked by them, except as §21.2 constrains.

### Transition rules

This table is the complete answer to "what happens when a signal changes mid-motion", and it applies to every actuator kind.

| Event | Behavior |
|---|---|
| Input goes `ON` while at `t=0` | Move toward `t=1` at `1/travel_time` per second |
| Input goes `OFF` while at `t=1` | Move toward `t=0` |
| Input **reverses mid-motion** | Reverse immediately from the current `t`. No snap, no pause, no completion of the current leg. |
| Input reverses again mid-reversal | Reverse again from the current `t` |
| Power lost mid-motion | **Stop at the current `t` and hold.** Do not return to `t=0`. |
| Power restored | Resume toward the position the current input commands, from the held `t` |
| Reset mid-motion | Move to `initial_t` at `travel_time` rate. It animates back; it does not teleport. |
| Two conflicting commands on one tick | The graph is acyclic and each actuator has exactly one `input_port`, so this is unreachable by construction |
| Save/load mid-motion | §5.10 |

Stopping in place on power loss rather than returning to rest is deliberate: a lift that drops to the bottom when a generator fails can strand or kill the player, and a bridge that retracts mid-crossing is a softlock generator.

## 21.2 Door, gate, shutter

`safe_closure = true` (the default) means: if closing would intersect the player or any `required = true` object, the door stops and reverses to fully open, then retries after `1.0 s`. It repeats indefinitely. It never crushes.

`safe_closure = false` marks the door as an authored hazard. It deals `HAZARD` damage per §25.1 and does not reverse. Only a package explicitly declaring a crusher hazard may set it false, and the validator rejects `safe_closure = false` on any door on a mandatory route.

## 21.3 Bridge, moving platform

Actors standing on a moving platform inherit its velocity. On leaving the platform, the player retains that velocity. Platform velocity is added to, not substituted for, player input velocity.

A platform that moves into geometry with an actor on it pushes the actor along until the actor is crushed against static geometry; at that point the actor takes `HAZARD` damage. Validators reject any mandatory-route platform whose path can crush.

## 21.4 Lift

A `LIFT` uses a `VALUE` input port and a `SELECTOR`, with `path` entries as stops. It travels to the stop indexed by its input. Changing the input mid-travel redirects immediately from the current position — it does not complete its current leg first.

## 21.5 Path machine

The general kinematic mover: cranes, rotating machinery, pistons, moving walls. Identical rules to §21.1 with no special cases. A crane is a `PATH_MACHINE` whose `path` describes the hook position; suspended cargo is a child transform, not a simulated rope (§2.2).

## 21.6 Rail switch

Changes which branch a rail follows. The change takes effect **only when no actor is on the rail within `10.0 m` of the junction**; otherwise it is queued and applies when the rail clears. This prevents a player being switched onto an invalid route mid-ride, which is otherwise the most reliable way to produce an unrecoverable state on a rail.

## 21.7 LaunchPad and bounce pad

A `LAUNCHPAD` declares `source_region` and `landing_region`. The **runtime solves the arc** from the movement law in §6.2; authors never specify a velocity vector.

Solve: given source centre `S`, landing centre `L`, and `GRAVITY`, choose the launch velocity with the minimum speed that reaches `L` and whose apex clears every obstruction between them by at least `1.0 m`. If no such velocity exists, the LaunchPad fails validation and the package is rejected at composition.

A `BOUNCE_PAD` applies a fixed vertical impulse of `13.0 m/s` and is not a directional solver.

## 21.8 Hazard controller

Enables and disables a hazard actor. The hazard owns its damage and collision; the controller owns only whether it is running. Disabling mid-cycle stops the hazard in place per §21.1 and clears any wind-up.

## 21.9 Light controller

Sets a room's lighting between authored `lit` and `unlit` states over `travel_time`. Lighting never gates progression: no mandatory route requires a specific lighting state, and no clue required for a mandatory route is visible only under one lighting condition. Per Dungeon Authority §21, darkness may hide optional content only.

---

# 22. HACKING

One reusable minigame. Not one bespoke puzzle per hackable door.

## 22.1 Entry and controls

`F` on a `HACK_TERMINAL` enters the hack. During a hack:

- The camera locks to the terminal. Player movement is disabled.
- `Esc` or `F` exits with no effect on puzzle state.
- Weapons, Abilities, Mobility, and melee are blocked.
- The player is **not** invulnerable. Taking any damage exits the hack immediately with no effect.
- Terminals are non-interactable while an encounter in the room is active, with `disabled_reason = "Interference detected"`.

## 22.2 The puzzle

**Route connection.** A grid of `4×4` (difficulty 1), `5×5` (2), or `6×6` (3) tiles. Each tile carries a pipe segment. Clicking a tile rotates it `90°`. The hack completes when a continuous route connects the source tile to the sink tile.

| Difficulty | Grid | Target time | Minimum rotations from initial state |
|---|---|---:|---:|
| 1 | `4×4` | `5 s` | `4` |
| 2 | `5×5` | `10 s` | `7` |
| 3 | `6×6` | `15 s` | `11` |

Generation guarantees a solution exists and that the initial state is exactly `minimum rotations` away from a solved state, so difficulty is genuine rather than incidental.

There is **no timer and no failure state.** A hack cannot be failed, only abandoned. Abandoning preserves tile rotations, so returning resumes where the player left off. This closes Dungeon Authority tests 32 and 33: hack failure cannot corrupt puzzle state because hack failure does not exist.

## 22.3 Output

| Mode | Emits |
|---|---|
| `PULSE` | A single pulse on completion |
| `VALUE` | Cycles its output value `(v + 1) mod n` on each completion, where `n` is the connected `SELECTOR`'s output count |

`VALUE` mode is how hacking redirects a route rather than merely enabling an output — the Dungeon Authority §5.7 requirement that a hack be more than a button with extra animation.

A completed `PULSE` terminal is re-hackable, producing another pulse. A completed `VALUE` terminal is re-hackable, advancing the value again. Neither is consumed.

---

# 23. PUZZLE-PACKAGE CONTRACT

## 23.1 Manifest

```
PackageManifest:
  id                  : Id
  family              : one of the eighteen in §24
  required_offers     : list[OfferRequirement]
  objects             : list[ObjectPlacement]
  nodes               : list[NodePlacement]
  actuators           : list[ActuatorPlacement]
  reset_group         : Id
  persistence         : enum { PUZZLE_LOCAL, ROOM_PERSISTENT }
  capability_required : Id? = null       # one of §29.1, or null
  physics_permitted   : bool = false     # may Physics move this package's required objects
  optional_solutions  : list[enum { PHYSICS, MOBILITY, COMBAT, ALTERNATE_INPUT }] = []
  timing_window       : Seconds? = null  # null when the package has no timed element
  budget              : PackageBudget
  audit_criteria      : list[string]

OfferRequirement:
  offer_type          : one of the offer types in §28.7
  count               : int >= 1
  min_volume          : vec3? = null
  min_separation      : Meters = 0.0

PackageBudget:
  max_rigid_bodies    : int <= 12
  max_actuators       : int <= 6
  max_nodes           : int <= 20
  max_signal_updates  : int <= 40        # per second, steady state
```

## 23.2 Room offers

A package instantiates only into an authored shell that exposes the offers it requires. The generator never places a package into space the shell has not declared available. This is what keeps rooms places rather than circuit diagrams.

## 23.3 Completion and AP

A package's completion drives a signal. It never directly awards AP. A Check placed inside a package's gated area is reached because the package opened the way, and the Check's own transaction (§9.4) is what awards anything.

A package is never itself a Check.

## 23.4 Reset

A reset restores every member of the package's `reset_group` in this fixed order:

1. Actuators move to `initial_t`.
2. `PUZZLE_LOCAL` nodes return to authored initial state.
3. Carryables respawn at `home_transform`.
4. Sockets empty.
5. Destructibles respawn.
6. Hazards return to their initial phase.

Reset never touches: confirmed Checks, `ROOM_PERSISTENT` flags, opened one-way shortcuts, Zone flags, or encounter cleared-flags.

Reset triggers: player death in the room, an explicit reset control, or room reload after unload.

## 23.5 Validation pipeline

A composed package must pass every check. Failure rejects the placement and the generator retries per §30.7.

| # | Check |
|---|---|
| 1 | Every required interaction point is reachable from the room's entry using base movement plus any capability the package declares |
| 2 | The player capsule fits at every interaction point with `MIN_HEADROOM` clearance |
| 3 | A carry path exists from every required object's spawn to every socket it must reach, with `MIN_HEADROOM` along it |
| 4 | Every required object has a valid `home_transform` inside `allowed_volume`, and no two required objects share one |
| 5 | Every required object is recoverable by at least one §10.4 trigger |
| 6 | `timing_window`, if non-null, is at least `1.6 ×` the computed traversal time for the required path at `WALK_SPEED` |
| 7 | Every LaunchPad arc solves per §21.7 |
| 8 | Every rail route is physically continuous and its switch cannot strand |
| 9 | Every grapple target lies inside a declared grapple offer |
| 10 | The signal graph is acyclic |
| 11 | Every port form matches its connection |
| 12 | Any declared capability is proven available before this room by §29.2 |
| 13 | No actuator state reachable from the initial state removes every progression path |
| 14 | Every `PUZZLE_LOCAL` object reconstructs from its serialized form |
| 15 | Reset restores the initial state exactly |
| 16 | Every hazard on a mandatory route has a telegraph of at least `0.8 s` |
| 17 | The package's budget is within §23.1 limits |
| 18 | No door on a mandatory route has `safe_closure = false` |

Check 13 is exhaustive over the package's reachable actuator states. Because `max_actuators` is 6 and each has two rest states, the worst case is 64 combinations — cheap enough to check completely rather than heuristically.

## 23.6 Deterministic failure

If a package fails validation during composition, the failure is logged with the package ID, the shell ID, the failing check number, and the seed. The generator retries per §30.7. The player never sees a partially placed package.

---

# 24. THE EIGHTEEN PUZZLE FAMILIES

Each has a runnable reference fixture in §37.

| # | Family | Shape |
|---|---|---|
| 1 | `CARRY_TO_PLATE` | Weighted object → pressure plate → output |
| 2 | `INSERT_COMPONENT` | Carryable component → socket → output |
| 3 | `PULSE_REMOTE` | Button → output |
| 4 | `TIMED_TRAVERSE` | Timed button → temporary route → validated traversal window |
| 5 | `SHOOT_TARGET` | Shootable target → output |
| 6 | `TOGGLE_ROOM_STATE` | Lever → persistent room transformation |
| 7 | `HACK_OVERRIDE` | Terminal → signal or route change |
| 8 | `DUAL_INPUT` | Two inputs → `AND` → output |
| 9 | `ALTERNATE_INPUT` | Two inputs → `OR` → output |
| 10 | `ROUTE_SWITCH` | Input → rail or conveyor route change |
| 11 | `MOVING_MACHINE` | Input → path machine changes geometry |
| 12 | `BOMB_BARRIER` | Recoverable explosive → tagged bombable target |
| 13 | `ENCOUNTER_GATE` | Encounter-clear → output |
| 14 | `OBSERVATION_TARGET` | Spatial clue → correct mechanism among several |
| 15 | `A_B_STATE` | Switch toggles linked architecture between two validated states |
| 16 | `LOCAL_KEY_LOOP` | Find local key → return → open gate → shortcut |
| 17 | `MULTI_STAGE_MACHINE` | Validated sequence of three mechanisms |
| 18 | `DUNGEON_STATE_CHANGE` | Room action sets a Zone flag affecting validated later rooms |

**Not shipped:** `ENERGY_ROUTE` and `BEAM_RECEIVER`, per §2.2. The Dungeon Authority names twenty families; Reliable Core ships eighteen.

---

# 25. HAZARDS AND DESTRUCTION

## 25.0 Material traits

Six. Deliberately small, and each is used by more than one system.

| Trait | Used by |
|---|---|
| `breakable` | Melee, all damage, `MOD_*` |
| `bombable` | Explosive damage only |
| `burnable` | `BURNING` Status, Fire Actors |
| `grapple_compatible` | `GRAPPLE` Mobility |
| `rail_compatible` | Player rails |
| `signal_blocking` | Line of sight for interaction, proximity sensors, and grapple |

Untagged geometry is indestructible. An explosion does not damage arbitrary level geometry.

## 25.1 Hazard contract

```
Hazard:
  id                : Id
  family            : one of §25.2
  damage            : Damage
  tick_interval     : Seconds        # 0.0 for single-contact
  telegraph         : Seconds        # warning before first damage
  affects           : list[Faction]
  crit_eligible     : false          # always
```

All hazard damage goes through the §8 damage resolver. Hazards affect every faction in `affects`, including enemies — this is what makes "hazards as tools" real rather than aspirational.

Any hazard on a mandatory route has `telegraph >= 0.8 s`, enforced by validation check 16.

## 25.2 Families

| Family | `damage` | `tick_interval` | `telegraph` | Notes |
|---|---:|---:|---:|---|
| `FLAME_JET` | `12.0` | `0.25` | `1.0` | Ignites `burnable`; applies `BURNING` at `0.5` |
| `ELECTRIC_FIELD` | `18.0` | `0.50` | `0.8` | |
| `CRUSHER` | `100.0` | `0.0` | `1.2` | Instant on contact; a door with `safe_closure = false` |
| `BLADE` | `35.0` | `0.0` | `0.8` | Moving `PATH_MACHINE` with a damage volume |
| `FALLING_DEBRIS` | `45.0` | `0.0` | `1.5` | Single event, triggered by signal |
| `FIRE_ACTOR` | `8.0` | `0.40` | `0.0` | Spawned by `BURNING` on `burnable` material; lifetime `10.0 s`; spreads to adjacent `burnable` within `2.0 m` once |

The Fire Actor is the mechanism by which `BURNING` produces damage **without the Status dealing damage**. It is a world object, it damages anything standing in it including the player and the enemy that spawned it, and its provenance is the actor who applied the `BURNING`.

Fire spreads exactly once per Actor, to at most three adjacent burnable surfaces. This bound is what keeps a room from becoming an unbounded fire simulation.

## 25.3 Destructible classes

| Class | Health | On destruction |
|---|---:|---|
| `CRATE` | `30.0` | Drops per its `drop_table`; debris despawns after `4.0 s` |
| `BARRIER_PANEL` | `80.0` | Opens a passage; `PUZZLE_LOCAL` |
| `REACTIVE_BARREL` | `20.0` | Explodes: `70.0` damage, `5.0 m` radius, `EXPLOSIVE` tag, impulse `14.0 m/s`; chains to barrels within radius after `0.15 s` |
| `DESTRUCTIBLE_SUPPORT` | `120.0` | Drops its attached load as a `FALLING_DEBRIS` hazard; `ROOM_PERSISTENT` |

Drop tables:

| Table | Contents |
|---|---|
| `drop_none` | nothing |
| `drop_health` | one `HEALTH_PICKUP` restoring `25.0` |
| `drop_puzzle` | the package's declared object |

Barrel chaining is bounded: a chain reaction propagates at most `5` links from the initial detonation. This is a hard cap, not a probability.

## 25.4 Environmental kill credit

A kill by a hazard, explosion, crusher, or falling debris credits the player if and only if **the player caused the hazard to act on this target within the last `5.0 s`**, by:

- shooting the reactive barrel or destructible support;
- activating the signal that enabled the hazard;
- applying `LIGHTENED` or an impulse that moved the target into the hazard;
- placing a bomb object.

Otherwise the kill is uncredited (§8.8). An enemy that patrols into an always-on flame jet is nobody's kill and advances no `ACTION` progress.

## 25.5 Enemy participation

Enemies interact with the environment in exactly these ways. Nothing emergent beyond this list is relied upon by any package.

| Interaction | Rule |
|---|---|
| Pressure plates | Only if the plate's `accepts` includes the enemy's mass class |
| Doors | Enemies never operate doors |
| Hazards | Enemies take hazard damage and their pathfinding avoids active hazards |
| Conveyors and wind | Affected per their mass class |
| Moving platforms | Ride them; pathfinding treats them as their current position |
| Physics | Pushed and pulled per §14.2 |
| Local keys | Enemies never carry them |

**No required progression depends on enemy behavior**, except `ENCOUNTER_GATE`, whose condition is "the encounter is cleared" — a fact about the encounter, not about any individual enemy's choices. This is the closure for Dungeon Authority §28's warning about brittle emergent behavior.

An enemy cannot permanently hold down a required pressure plate: an enemy standing on a plate is killable, and if the encounter is cleared the enemy is gone. Test vector 59.

---

# 26. ROUTING, FORCES, AND CONSTRAINTS

## 26.1 Power

Power is an ordinary Boolean signal named `power`. There is no electrical simulation. A generator is a `LATCH` whose set input is a socket holding a power cell. Machinery declaring `requires_power` treats its `power` input as an additional `AND` term.

## 26.2 Wind

A wind volume applies a constant acceleration in a direction to actors and objects by mass class:

| Mass class | Response |
|---|---|
| `LIGHT` | Full acceleration |
| `MEDIUM` | `40%` |
| `HEAVY` | `0%` |
| `FIXED` | `0%` |

The player is `MEDIUM`, so wind moves the player at `40%`. A player under `RULE_MASS_LIGHT` (§12.10) takes full acceleration, which is the intended interaction.

Wind affects projectiles only if the projectile's family is `PROJECTILE_LOB`. Direct projectiles, hitscan, and beams are unaffected. This is a compatibility decision, not physics.

## 26.3 Conveyors and cargo

A conveyor applies a constant velocity along its surface to anything touching it, by the same mass-class table as wind. Direction is signal-controlled and reverses instantly, with no ramp.

`CART` objects are constrained to an authored floor path and move only along it.

## 26.4 Player rails

A rail is a spline tagged `rail_compatible`. The player mounts by contacting it while airborne, or by `F` at a mount point.

| Property | Value |
|---|---|
| Ride speed | `14.0 m/s` base, modified by `INT_RAIL_CONTROL` |
| Dismount | `jump` — leaves at ride speed plus `JUMP_VELOCITY` vertical |
| Forced dismount | At a rail end, retaining ride velocity |
| Control while riding | Look freely; Weapons and Abilities usable; Mobility blocked |
| Damage while riding | Normal; taking damage does not dismount |

Rail switching per §21.6.

## 26.5 Constraints

**Deferred.** No hinges, ropes, chains, pulleys, counterweights, seesaws, or pendulums. Anything the Dungeon Authority §11 describes as constrained motion is implemented as a kinematic `PATH_MACHINE` following an authored path.

A crane looks like a crane and moves like a crane. It is not simulated as one, and its cargo cannot swing.

---

# 27. MEDIA

## 27.1 Water

**Deferred as a swimmable medium.** Shallow water exists as a movement volume: `WALK_SPEED × 0.7` while inside, no swimming, no oxygen, no buoyancy, no fill or drain. Its depth never exceeds `1.0 m`, enforced at shell authoring.

There is no drowning in Reliable Core. Water deep enough to drown in does not exist.

## 27.2 Light

Lighting is presentation with two mechanical hooks: `BURNING` emits light, and `LIGHT_CONTROLLER` changes room lighting state. No puzzle input reads light level.

## 27.3 Sound

Every mechanically required cue has a visual equivalent, per Dungeon Authority §22 and §50. Sound alone never carries required information. There is no sound sensor.

## 27.4 Deferred media

Gases, smoke, steam, pressure, temperature, vacuum, acid, and coolant do not exist.

---

# 28. ROOM AND ZONE TOPOLOGY

## 28.1 Room-local transformations

A room may change state through its packages: doors, bridges, platforms, lifts, lights, hazard state, and destructible passages. Every transformation is driven by the signal graph and is `PUZZLE_LOCAL` or `ROOM_PERSISTENT` per its package manifest.

## 28.2 One-way connections and shortcuts

A shortcut opened from the far side is `ROOM_PERSISTENT` and is never re-closed by any reset. Drop-downs and one-way vents are geometry, not machinery, and need no state.

## 28.3 Zone flags

Dungeon-scale state is exactly **four forward-only Boolean flags** per Zone:

| Flag | Set by | Affects |
|---|---|---|
| `power_restored` | A `DUNGEON_STATE_CHANGE` package | Machinery with `requires_power` in later rooms |
| `security_disabled` | A `DUNGEON_STATE_CHANGE` package | Hazard controllers in later rooms |
| `main_route_open` | A `DUNGEON_STATE_CHANGE` package | Doors on the spine in later rooms |
| `auxiliary_open` | A `DUNGEON_STATE_CHANGE` package | Optional-branch doors in later rooms |

Rules:

- Flags are **forward-only**. Once set, never cleared, by any mechanism including death, reset, and reload.
- A flag may be set by at most one package in a Zone.
- A flag may be read by any number of later rooms, and **only** by rooms later on the spine than the room that sets it.
- Flags are `ZONE_PERSISTENT`.

Forward-only monotonic flags are why Reliable Core needs no cross-room cycle detection: a Zone's macro state is a point on a lattice of at most 16 states, always moving upward. It cannot cycle, cannot deadlock, and cannot be validated wrong. The cost is that a dungeon cannot have a genuinely reconfigurable global machine — the Dungeon Authority §39's "rail network rerouted" is not expressible. §40 records this.

## 28.4 Cross-room outputs

A signal never crosses a room boundary directly. Cross-room effect happens only through Zone flags. This means the "generator in Room A powers lift in Room C" pattern works, and "valve upstream continuously modulates water downstream" does not — the second requires a continuous cross-room value, which Reliable Core does not have.

## 28.5 Local keys

A local key is a `KEY_COMPONENT` carryable. Its collected-flag is `ROOM_PERSISTENT`. Local keys are never AP items and never cross a Zone boundary — a key taken to the Hub is destroyed and respawns at its `home_transform`.

## 28.6 Secrets

A secret is an optional area behind a `breakable` or `bombable` surface, an optional grapple route, or an unmarked passage. Its discovered-flag is `ROOM_PERSISTENT`. Secrets never contain progression-mandatory content, and no mandatory route passes through one.

## 28.7 Offer types

A shell declares the offers packages may bind to. Exhaustive:

`stand_region`, `cover`, `reactive`, `enemy_high`, `access`, `rail`, `launch`, `grapple`, `machinery_input`, `machinery_output`, `conduit_route`, `carryable_spawn`, `carry_path`, `platform_corridor`, `path_machine_envelope`, `hazard_lane`, `secret_opportunity`, `alternate_route`, `reset_station`, `zone_state_control`.

---

# 29. CAPABILITY PROGRESSION

## 29.1 The four capabilities

| Capability | Satisfied by | Guaranteed |
|---|---|---|
| `capability:core:ranged_hit` | Static Pulse | **Always.** Permanent baseline. |
| `capability:core:grapple` | Any `GRAPPLE` Mobility | Only by proof |
| `capability:core:blink` | Any `BLINK` Mobility | Only by proof |
| `capability:core:long_gap` | `DASH` with `distance >= 8.0`, or `BURST_JUMP` with `impulse >= 9.0` | Only by proof |

No other capability exists. Physics grants none (§14.5), Weapons grant none beyond `ranged_hit`, and Gear grants none.

## 29.2 Proof

The bridge's planner may place a requirement for capability `C` in room `n` only if:

1. The player's committed Loadout contains a host granting `C`; **or**
2. AP logic guarantees a host granting `C` is received before this Zone becomes accessible.

Route 2 requires the AP world definition to place a `C`-granting item in a sphere strictly earlier than this Zone's access. Reliable Core does **not** implement in-Zone capability acquisition — there is no "find the grapple in room 3 to use it in room 7" — because that requires the planner to reason about within-Zone item placement, and Hub-only loadout editing means the player could not equip it anyway.

## 29.3 Entry validation

Before Zone entry, the UI shows every capability the Zone requires. If the committed Loadout lacks a required capability, entry is blocked with the message in §34.4.

This is the practical meaning of `NO REQUIREMENT BEFORE GUARANTEE` under Hub-only editing: requirements are checked at the boundary where the player can still act on them.

## 29.4 Optional routes

An optional route may require anything, including capabilities the player does not have, physics tricks, and precise execution. Optional routes are never validated for reachability and never counted by the planner.

Sequence-breaking an optional obstacle is welcome and is not defended against.

---

# 30. PROCEDURAL COMPOSITION

## 30.1 What Epsilon chooses

Nothing in Zone composition. Composition is entirely deterministic and bridge-owned. Epsilon's only role in the game is item interpretation (§17.2).

This is a Reliable Core position, and a strong one: it means a Zone's validity never depends on a model response, and a Zone is byte-identically reproducible from its seed forever.

## 30.2 Zone shape

A Zone is a **linear spine** of 8 to 16 rooms with optional dead-end branches.

```
entry → r1 → r2 → ... → rN → exit
              ↳ branch (1-2 rooms, dead end)
```

| Property | Value |
|---|---|
| Spine length | `8` to `16` rooms, drawn from the Zone seed |
| Branches | `0` to `3`, each `1` or `2` rooms, each attached to a distinct spine room |
| Branch content | Optional Checks, secrets, and rewards only. Never spine-mandatory. |
| Loops | None. The graph is a tree. |

A tree has no cycles, so cross-room dependency cycles are impossible by construction, not by validation.

## 30.3 Composition algorithm

Fully deterministic given `(zone_seed, progression_state, ap_catalog)`.

```
 1. rng = seeded(zone_seed)
 2. spine_length = 8 + rng.int(0, 8)
 3. For i in 0..spine_length-1:
      purpose[i] = PURPOSE_ROTATION[i mod len(PURPOSE_ROTATION)]
 4. For i in 0..spine_length-1:
      candidates = shells whose declared purposes include purpose[i]
                   and whose offers can host at least one legal package
      shell[i] = candidates[rng.int(0, len(candidates))]
      If candidates is empty: FAIL_SHELL
 5. check_count = clamp(spine_length / 2, 4, 8)
    Distribute Checks across rooms at indices
      round(spine_length * (k + 0.5) / check_count) for k in 0..check_count-1
 6. For each room i:
      package_count = PACKAGE_DENSITY[purpose[i]]
      For j in 0..package_count-1:
        Try up to 12 candidate packages, in rng order, from families
          legal for purpose[i] and hostable by shell[i]'s free offers
        Accept the first passing all 18 checks in §23.5
        If none passes: reduce package_count by 1 and continue
      If room i ends with 0 packages and purpose[i] requires one: FAIL_ROOM
 7. capability_gate:
      If the planner proves a capability C available (§29.2), place at most
      one gate requiring C, at spine index >= ceil(spine_length / 2)
 8. encounter_budget[i] = ENCOUNTER_BUDGET[purpose[i]]
    Populate encounters per §32.5
 9. checkpoints at spine indices 0, and every 3rd room thereafter, and at
    the room preceding any capability gate
10. branches: for b in 0..branch_count-1, attach to a distinct spine room
    at index >= 2, using the same room composition, marked optional
11. Run the whole-Zone audit in §30.4. On failure: FAIL_ZONE
```

`PURPOSE_ROTATION` = `[traversal, arena, environmental_puzzle, traversal, ranged_arena, physical_puzzle, junction, holdout, observation_puzzle, traversal, timing_challenge, arena, routing_puzzle, vertical_ascent, gauntlet, boss_arena]`.

`PACKAGE_DENSITY`: puzzle purposes `2`, junction `2`, traversal `1`, arena purposes `1`, boss arena `0`.

`ENCOUNTER_BUDGET`: arena `3`, ranged arena `3`, holdout `4`, gauntlet `5`, boss arena `1` (the boss), all others `0` to `1`.

## 30.4 Whole-Zone audit

| # | Check |
|---|---|
| 1 | Entry reaches exit using base movement plus proven capabilities |
| 2 | Every Check is reachable |
| 3 | Every branch is reachable and is a dead end |
| 4 | At most one capability gate, and it is proven |
| 5 | Every Zone flag is set by at most one room and read only by later rooms |
| 6 | Checkpoint spacing never exceeds 3 rooms |
| 7 | Total rigid bodies across loaded rooms is within §35 budgets |
| 8 | No two required objects in a room share a `home_transform` |

## 30.5 Determinism

Three independent RNG streams, each seeded separately, so that consuming from one never shifts another:

| Stream | Seed | Consumed by |
|---|---|---|
| Composition | `hash(campaign_seed, zone_id)` | Everything in §30.3 |
| Decoration | `hash(campaign_seed, zone_id, "decor")` | Purely visual variation |
| Combat | `hash(campaign_seed, zone_id, room_index, encounter_index)` | Crit rolls, Status rolls, AI |

The same campaign seed and Zone ID always produce a byte-identical Zone. Decoration draws from its own stream, so decorative changes can never alter composition. Combat randomness is re-seeded per encounter, so a retried encounter is not identical but the Zone around it is.

## 30.6 Checkpoints

Placed per §30.3 step 9. A checkpoint activates on the player entering its trigger volume, and only when no encounter in the room is active. Activating writes a save.

## 30.7 Retry and fallback

| Failure | Response |
|---|---|
| `FAIL_SHELL` | Retry room `i` with the next `purpose` in rotation, up to 3 times |
| `FAIL_ROOM` | Retry the whole room with a different shell, up to 3 times |
| `FAIL_ZONE` | Retry the whole Zone with `zone_seed + 1`, up to 5 times |
| All retries exhausted | Use the certified fallback Zone (§37 fixture 19) |

The fallback Zone is an authored, hand-validated 8-room linear Zone with fixed content. It is not generated, is checked into the repo, and passes every audit by construction. It exists so that composition failure is a degraded experience rather than a broken campaign.

## 30.8 Physical authority

If the composition claims a route is traversable and the runtime geometry disagrees, the geometry wins. The room fails its audit at load, and the client reports it. Reliable Core never ships a room whose logical and physical truth disagree — it refuses to load it.

---

# 31. CROSS-SYSTEM COMPATIBILITY

The complete matrix. An interaction not listed here does not occur.

| A × B | Result |
|---|---|
| Explosion × `bombable` | Destroys |
| Explosion × `breakable` | Destroys |
| Explosion × untagged geometry | No effect |
| Explosion × `REACTIVE_BARREL` | Chains, max 5 links |
| Melee × `breakable` | Destroys |
| Melee × `bombable` | No effect |
| Any damage × `breakable` | Destroys |
| `BURNING` × `burnable` | Spawns `FIRE_ACTOR` |
| `FIRE_ACTOR` × `burnable` | Spreads once, max 3 targets |
| `FIRE_ACTOR` × any actor | Damages, all factions |
| Wind × `LIGHT` | Full acceleration |
| Wind × `MEDIUM` | 40% |
| Wind × `HEAVY`, `FIXED` | No effect |
| Wind × `PROJECTILE_LOB` | Affects |
| Wind × hitscan, beam, direct projectile | No effect |
| Conveyor × object | By mass class, as wind |
| Physics × `required` object | Only if `physics_permitted` |
| Physics × enemy | `PUSH`, `PULL` only |
| Physics × boss | No effect |
| Physics × player | No effect, ever |
| `LIGHTENED` × pressure plate | Plate reads the reduced class |
| `ANCHORED` × wind, conveyor, impulse, Physics | No effect on the target |
| Enemy × pressure plate | Only if `accepts` includes its mass class |
| Enemy × hazard | Damages; pathfinding avoids |
| Rail × `RAIL_SWITCH` | Queued while occupied within 10 m |
| Water × anything | Movement slow only |
| Light × puzzle input | No interaction |
| Sound × puzzle input | No interaction |

---

# 32. ENEMIES AND ENCOUNTERS

## 32.1 Minimum enemy contract

Every enemy implements exactly this interface. Nothing in the game reads more than this.

```
Enemy:
  id                : Id
  archetype         : one of §32.2
  health            : Damage
  defense           : float
  faction           : Faction              # HOSTILE by default
  mass_class        : MassClass
  status_resistance : float in [0.0, 0.40]
  statuses          : list[active Status]
  ai_state          : enum { IDLE, ENGAGED, PANIC, STUNNED, DEAD }
  target            : Id?
```

Enemies deal damage through the §8 resolver like everything else. Enemy attacks never apply Status to the player — Status is a player-side verb in Reliable Core. This is a deliberate asymmetry: it removes an entire category of "the player is anchored and cannot act" frustration, and it means §15's six Statuses only ever need to be defined against enemies and objects.

## 32.2 Archetypes

Six. Enough to compose encounters, few enough to balance.

| Archetype | Health | Defense | Mass | Status resist | Behavior |
|---|---:|---:|---|---:|---|
| `SKIRMISHER` | `60` | `0` | `MEDIUM` | `0.00` | Closes to `8 m`, hitscan bursts |
| `BRUISER` | `180` | `0` | `HEAVY` | `0.15` | Closes to melee, high contact damage |
| `ARMORED` | `140` | `100` | `HEAVY` | `0.20` | Slow advance, sustained fire |
| `FLYER` | `45` | `0` | `LIGHT` | `0.00` | Hovers at `6 m` altitude, dives |
| `TURRET` | `90` | `50` | `FIXED` | `0.40` | Immobile, `40 m` range, telegraphed shots |
| `BOSS` | `1800` | `150` | `FIXED` | `0.40` | Authored per encounter; three phases |

`FLYER` exists so `AIRBORNE_KILL` (§12.6) is reliably achievable. An `ACTION` recharge whose fact can never occur is a dead build, and encounter budgets guarantee at least one `FLYER` in every arena purpose.

## 32.3 Faction behavior

| Situation | Behavior |
|---|---|
| `HOSTILE` default | Targets the player |
| `TURNCOAT` applied | `faction = PLAYER`; targets nearest `HOSTILE` |
| Turncoat expires | Reverts to `HOSTILE` at current Health, retargets the player |
| `CONFUSED` applied | Targets nearest actor of any faction, re-evaluated every `1.0 s` |
| Enemy damages enemy | Full damage, no retaliation state change |

## 32.4 Status-compatible AI

Every archetype responds to every Status:

| Status | AI response |
|---|---|
| `BURNING` | `ai_state = PANIC` for the duration; no attacks, randomized movement |
| `LIGHTENED` | No AI change; physical response only |
| `ANCHORED` | Movement `0`; attacks continue if in range |
| `CONFUSED` | Retarget per §32.3 |
| `TURNCOAT` | Faction switch per §32.3 |
| `EXPOSED` | No AI change |

A `TURRET` under `PANIC` stops firing. A `BOSS` never enters `PANIC` — it substitutes to `EXPOSED` at half duration per §15.4.

## 32.5 Encounters

```
Encounter:
  id                : Id
  waves             : list[Wave], length 1..3
  clear_condition   : enum { ALL_DEAD, SURVIVE_DURATION }
  duration          : Seconds?          # required iff SURVIVE_DURATION
  cleared           : bool              # ROOM_PERSISTENT

Wave:
  spawns            : list[(archetype, count)]
  trigger           : enum { ENCOUNTER_START, PREVIOUS_WAVE_CLEARED, DELAY }
  delay             : Seconds?          # required iff trigger == DELAY
```

Encounter budget from §30.3 is the total spawn count across all waves. Composition fills the budget from archetypes legal for the room's purpose, always including at least one `FLYER` in arena purposes.

An encounter starts when the player enters its trigger volume. It cannot restart once `cleared`.

## 32.6 Death, drops, and respawn

- On an enemy's death, its remaining-count decrements. At zero for the final wave, `cleared` is set.
- Enemies drop nothing by default. A `drop_health` table on the encounter drops one `HEALTH_PICKUP` from the last enemy of the final wave.
- **Enemies never respawn.** A cleared encounter stays cleared through death, reload, and revisit. An uncleared encounter's enemies are destroyed on player death and respawn in full when the player re-enters the trigger volume.
- Enemies killed by environmental hazards count identically toward clear conditions. Kill credit for `ACTION` progress follows §25.4 separately.

## 32.7 Boss encounters

A `BOSS` has three phases at `100%`, `66%`, and `33%` Health. Phase transitions grant `2.0 s` invulnerability and reposition the boss. A boss is `FIXED` mass, is immune to `ANCHORED` and `TURNCOAT` with the substitutions in §15.4, and is never Physics-eligible.

A boss arena has one encounter, no packages, and a checkpoint immediately before entry.

---

# 33. HUD AND PRESENTATION

## 33.1 Always visible

| Element | Content |
|---|---|
| Health | Numeric and bar |
| Barrier | Numeric and bar, shown only when `> 0` |
| Selected Weapon | Name and cycle position (e.g. `2 / 4`) |
| Weapon feed | Per §33.2 |
| Ability row | Five entries, Q E 1 2 3 |
| Mobility | One entry |
| Interaction prompt | When an Interactable is focused |
| Active Statuses on the player | Icon row |

## 33.2 Feed display by model

| Model | Display |
|---|---|
| `MAGAZINE` | `rounds / capacity`; reload shows a progress arc |
| `HEAT` | A bar filling toward `heat_max`; lockout shown as a distinct crosshatch fill with a countdown |
| `CHARGE` | A radial fill; the `min_charge_fraction` threshold marked |
| `NONE` | **Nothing.** No bar, no counter, no placeholder. |

## 33.3 Recharge display by identity

The three identities must look different. Five identical radial timers is explicitly forbidden by Player Authority §27.2.

| Identity | Display | Example |
|---|---|---|
| `RESOURCE` | Numeric current over max, with a fill bar | `Q  62 / 100` |
| `COOLDOWN` | Charge pips plus remaining time on the recharging pip | `E  ●●○  1.4s` |
| `ACTION` | The verb and progress toward threshold | `1  MELEE HITS 2 / 3` |
| Ready | The word `READY` | `SHIFT  READY` |

## 33.4 Device presentation

- The Epsilon device is assembled from `3` to `6` authored modules per `view_modules`.
- Cycling plays a `0.25 s` reconfiguration animation. The Weapon is usable immediately; the animation never gates the simulation.
- Static Pulse has a distinct neutral silhouette recognizable without reading text.
- Presentation never decides an outcome. Every visual is a report of a simulation result that already happened.

## 33.5 Causality feedback

Every build relationship produces visible feedback at the moment it fires:

| Event | Feedback |
|---|---|
| Overcrit advances an Ability | The Ability's progress element flashes and the responsible Gear or Mod icon pulses |
| A `TRIGGER` Mod fires | Its icon pulses |
| Status fails | Per §15.5 |
| Heat reaches lockout | The bar switches to crosshatch with an audio cue |
| A hybrid reduces a cooldown | The pip's remaining time visibly jumps |

## 33.6 Color

Color is never the only channel. Reserved meanings: provenance accents, hazard orange, Check cyan, Epsilon identity. Readiness, telegraphs, and machinery state use shape, motion, rhythm, intensity, position, and audio in addition.

---

# 34. PLAYER-FACING FLOW

## 34.1 First run

1. The player begins at the Hub with an empty Archive.
2. The starting Loadout is: no Weapons, no Abilities, no Mobility, no Gear. Static Pulse and melee are available because they are baseline.
3. The first Zone requires no capability, per §29.2 — a Zone requiring one cannot be the first, since nothing is proven yet.
4. The Archive tutorial prompt appears on the first host receipt, not before.

The game is fully playable at step 2. This is what the permanent baseline is for.

## 34.2 The Hub

Available at the Hub and nowhere else: loadout editing, Mod installation and removal, shops, and Zone selection.

## 34.3 Receiving an item

1. A receipt banner names the item, its source game, and its source player.
2. The item enters the Archive marked new.
3. **Nothing auto-equips.** The player chooses. An item arriving mid-excursion is banked and appears in the Archive at the next Hub visit.

Auto-equip is rejected: it would silently change a committed build mid-excursion and would make the cold-introduction rules (§5.7) player-visible in a confusing way.

## 34.4 Zone entry

The Zone selection screen shows, per Zone: name, Signal Key cost, Check count, and required capabilities.

If the committed Loadout lacks a required capability, entry is blocked and the screen shows:

> **Cannot enter.** This Zone requires GRAPPLE. Equip a Mobility Echo that provides it.

with the qualifying Archive entries listed directly beneath. The player is never told to go find something they already own without being shown it.

## 34.5 Archive and equip

The Archive lists hosts by category and Mods separately. Each entry shows display name, provenance, tier, and mechanical summary.

Equipping is drag or select-to-slot. An illegal equip is refused with the specific rule from §4.7, not a generic error.

## 34.6 Invalid loadout messages

| Rule violated | Message |
|---|---|
| Duplicate host | `Already equipped in another slot.` |
| Wrong Gear territory | `<Name> is <Territory> gear. It cannot go in the <Slot> slot.` |
| Second high-tier Gear | `Only one high-tier Gear piece may be equipped. Unequip <Name> first.` |
| Mod capacity exceeded | `<Host> has <n> Mod slots and they are full.` |
| Mod host mismatch | `<Mod> cannot attach to a <Category>.` |
| `MOD_LINK` target unequipped | `<Mod> links to <Target>, which is not equipped.` |

## 34.7 Manual save refused

> **Cannot save right now.** Finish the encounter first.

## 34.8 Binding conflict

> **<Key> is already bound to <Role>.** Unbind it first, or choose another key.

## 34.9 Rejection feedback

Every refused action produces feedback naming the reason. Silence is forbidden.

| Refusal | Feedback |
|---|---|
| Ability not ready | The HUD entry flashes; audio "unavailable"; the readiness element highlights |
| Resource insufficient | The resource number flashes red-shifted **and** the bar pulses |
| No valid Physics target | Crosshair shows a rejection mark |
| No valid Mobility destination | Same, with the attempted destination outlined for `0.4 s` |
| Weapon empty | Empty-click audio; the magazine counter flashes |
| Weapon in lockout | The heat bar pulses; countdown emphasized |
| Socket incompatible | The socket flashes; audio rejection; the prompt was already showing as disabled |
| Interactable disabled | The prompt shows `disabled_reason` |

## 34.10 Leaving a Zone

Two exits, and only two.

**Completing it.** The exit room contains an `ACTIVATE_CHECK`-priority Interactable with `verb = OPEN` labelled `[F] Return to Hub`. Activating it writes a save and returns the player to the Hub. It is disabled while an encounter in the exit room is active.

**Abandoning it.** The pause menu offers `Return to Hub`, available whenever a manual save would be (§34.7) — that is, not during an active encounter. It presents:

> **Return to the Hub?** Puzzle progress in this Zone will reset. Checks you have activated, shortcuts you have opened, encounters you have cleared, and Zone-wide changes will be kept.

That warning is exactly the §5.2 category table stated in player language: `PUZZLE_LOCAL` is discarded on Zone exit, and `ROOM_PERSISTENT`, `ZONE_PERSISTENT`, and `AP_PERSISTENT` survive.

**Re-entering** a Zone already in progress restores its `ROOM_PERSISTENT` and `ZONE_PERSISTENT` state and rebuilds every `PUZZLE_LOCAL` puzzle from its initial state. The player restarts at the Zone entry, not at their last checkpoint — checkpoints are within-excursion recovery, not a Zone bookmark.

There is no death-triggered ejection. Dying returns the player to a checkpoint (§5.4), never to the Hub.

## 34.11 The Archive during an excursion

`Tab` opens the Archive anywhere, including mid-Zone. Inside a Zone it is **read-only**: the player can inspect everything they own, including items received during this excursion, and can change nothing. Every equip control is shown disabled with:

> Loadout can only be changed at the Hub.

Showing the Archive but disabling its controls is deliberate. Hiding it would leave a player unable to check what a Mod on their equipped Weapon actually does, which is information they need and which changing nothing.

## 34.12 Migration notice

> **Your build has been reset.** Archipepsi's loadout system has changed: the Epsilon device now holds three Weapon configurations, five Abilities, one Mobility Echo, and four pieces of Gear. Everything you have received is still in your Archive, reinterpreted for the new system. Open the Archive to build a new loadout.

---

# 35. PERFORMANCE BUDGETS

Numeric and enforced, not aspirational. Exceeding a budget is a validation failure at composition, not a runtime slowdown.

| Quantity | Budget |
|---|---:|
| Active rigid bodies per loaded room | `12` |
| Active rigid bodies across all loaded rooms | `36` |
| Loaded rooms | `3` (current plus immediate neighbours) |
| Live projectiles, all sources | `64` |
| Live projectiles per Weapon | `24` |
| Beam segments | `1` per beam; no bouncing |
| Actuators per room | `6` |
| Signal nodes per room | `20` |
| Signal updates per second per room | `40` |
| Active enemies | `12` |
| Active hazard volumes per room | `8` |
| Fire Actors per room | `6` |
| Deployables per player | `2` (oldest despawns) |
| Physics relations held | `2` (per `max_relations`) |

Rules:

- Signal evaluation is **event-driven**. A node evaluates only when an input changes. The `40/s` budget bounds worst-case churn, not steady state.
- Decorative rigid bodies sleep after `2.0 s` at rest and do not count toward the budget while asleep.
- Required semantic objects never sleep and always count.
- Projectiles despawn at `lifetime` unconditionally. There is no path by which a projectile persists indefinitely.

---

# 36. DEBUGGING AND INSPECTION

A debug overlay, toggled by a developer-only input never present in the player control grammar, exposes:

| Inspectable | Content |
|---|---|
| Signal graph | Nodes, current values, edges, topological order, last-changed tick |
| Interaction | Current focus candidate list with priority class, angle, distance, and the sort result |
| Reset groups | Membership and each member's current versus initial state |
| Persistence | Every object's category and its current serialized form |
| Capability | Required, proven, equipped, and the proof route |
| Packages | Active package IDs, their manifests, and which offers they bound to |
| Objects | Semantic ID, mass class, `physics_eligible`, `required`, distance from `home_transform` |
| Routes | LaunchPad solved arcs, rail splines, grapple regions |
| Timing | Every timed window and its computed feasibility margin |
| Zone flags | All four, set or unset, and which room set each |
| Audit | Every §23.5 and §30.4 check result for the current Zone |
| Host runtime | Every equipped host's full `HostRuntimeState` |
| Status | Per-actor active Statuses, susceptibility, and adaptation per family |
| Budgets | Live counts against every §35 budget |

Debug inputs are never part of the player control grammar and are compiled out of release builds.

---

# 37. REFERENCE FIXTURES

One runnable fixture per puzzle family, plus the certified fallback Zone. Each is a real, measured, checked-in scene that passes every §23.5 check. They are the acceptance target: an implementation is correct when it runs these.

All fixtures use a `20 × 20 × 6 m` test shell with the entry at `(0, 0, 0)` unless stated. Coordinates are metres, `+Y` up.

| # | Fixture | Layout | Solution | Reset |
|---|---|---|---|---|
| 1 | `fx_carry_to_plate` | `WEIGHTED` cube at `(4, 0, 2)`; plate `2×2 m` at `(12, 0, 8)` accepting `HEAVY`; door at `(18, 0, 10)` | Carry cube to plate; door opens while held down | Cube to `(4,0,2)`; door closed |
| 2 | `fx_insert_component` | `POWER_CELL` at `(3, 0, 3)`; socket at `(15, 2, 9)` on a `2.0 m` ledge, which exceeds `MAX_SAFE_STEP_UP` (`1.145 m`), so a ramp rises from `(13, 0, 9)` to `(15, 2, 9)` at `28°` | Carry cell up the ramp, insert | Cell to spawn; socket empty; door closed |
| 3 | `fx_pulse_remote` | Button at `(5, 0, 5)`; `TIMER` `4.0 s`; bridge at `(10, 0, 10)` spanning a `3.5 m` gap | Press, cross within `4 s` (traversal `2.1 s`, margin `1.9×`) | Bridge retracted |
| 4 | `fx_timed_traverse` | `TIMED_BUTTON` `6.0 s` at `(2, 0, 2)`; three platforms rising at `(6,0,6)`, `(10,0,10)`, `(14,0,14)`; exit at `(18,3,18)` | Press, traverse. Path is `17.0 m` at `WALK_SPEED` = `2.6 s`; window `6.0 s` = `2.3×` margin | Platforms lowered |
| 5 | `fx_shoot_target` | Target at `(18, 4, 18)`, `25.4 m` from entry, well inside Static Pulse range; `required_tags [RANGED]`; gate at `(18,0,14)` | Shoot it | Target unlit; gate closed |
| 6 | `fx_toggle_room_state` | Lever at `(4,0,4)`; two bridge groups A at `(8,0,*)` and B at `(12,0,*)`; exit reachable only via one | Toggle to the needed state; `ROOM_PERSISTENT` | Not reset — persists by design |
| 7 | `fx_hack_override` | `HACK_TERMINAL` difficulty 2, `VALUE` mode at `(6,0,6)`; `SELECTOR` with 3 outputs; three doors | Hack repeatedly to select the door needed | Value to `0`; doors closed |
| 8 | `fx_dual_input` | Plate at `(6,0,4)` accepting `HEAVY`; `WEIGHTED` cube at `(3,0,3)`; `LEVER` at `(14,0,4)`; `AND` → door | Cube on plate, then throw lever | Cube to spawn; lever off; door closed |
| 9 | `fx_alternate_input` | Shootable target at `(16,5,16)`; button at `(4,0,12)`; `OR` → door | Either | Both reset; door closed |
| 10 | `fx_route_switch` | Rail from `(2,4,2)` to a junction at `(10,4,10)`, branching to `(18,6,14)` and `(18,1,6)`; `SHOOTABLE_TARGET` sets the switch | Shoot to select the branch, then ride | Switch to branch 0 |
| 11 | `fx_moving_machine` | `PATH_MACHINE` crane, hook path `(6,5,6)`→`(14,5,14)`, `travel_time 5.0 s`, carrying a `4×4 m` platform; lever controls it | Ride the platform across a `9 m` gap | Crane to `t=0` |
| 12 | `fx_bomb_barrier` | `REACTIVE_BARREL` at `(5,0,5)`, respawning; `bombable` wall at `(9,0,5)`, `3.5 m` away — inside the `5 m` blast | Push or shoot the barrel near the wall | Barrel respawned; wall restored |
| 13 | `fx_encounter_gate` | Encounter: 2 `SKIRMISHER`, 1 `FLYER`, one wave; `ENCOUNTER_CLEAR` → door | Clear it | Not reset — `cleared` is `ROOM_PERSISTENT` |
| 14 | `fx_observation_target` | Three identical buttons at `(4,0,16)`, `(10,0,16)`, `(16,0,16)`; a wall marking visible only from `(10,0,2)` indicates which; wrong presses visibly reset | Observe, then press the right one | Marking unchanged; door closed |
| 15 | `fx_a_b_state` | Lever toggles platform group A raised / B lowered and the inverse; exit needs one of each traversed | Toggle mid-route | Group A raised |
| 16 | `fx_local_key_loop` | `KEY_COMPONENT` at `(17,3,3)` behind a `1.0 m` step; keyed gate at `(2,0,18)`; opening it opens a one-way shortcut back to entry | Fetch, return, open | Key to spawn; gate closed; **shortcut stays open** |
| 17 | `fx_multi_stage_machine` | Stage 1: power cell → socket. Stage 2: `power_restored` enables a lift. Stage 3: lift reaches a terminal that opens the exit | Three stages in order | All three to initial |
| 18 | `fx_dungeon_state_change` | A `DUNGEON_STATE_CHANGE` package setting `power_restored`; a later room's lift requires it | Set the flag | **Never reset** — forward-only |
| 19 | `fx_fallback_zone` | The certified fallback: 8 rooms, linear, one package each drawn from families 1, 3, 5, 8, 9, 13, 15, 16; 4 Checks at rooms 2, 4, 6, 8; checkpoints at 1, 4, 7; no capability gate; no branches | — | Per package |

Fixture 19 is checked into the repo as authored content and is never generated. It is the guaranteed-valid Zone of §30.7.

Every fixture ships with an expected-state assertion file: the exact serialized `PUZZLE_LOCAL` state after solving, and after resetting. A fixture whose post-reset state differs from its initial state by even one field fails.

---

# 38. TEST VECTORS

Concrete inputs and expected outputs. Numbered continuously so a failure report names one number.

## Baseline
1. Empty Loadout: player moves, jumps, interacts, melees, and kills a `SKIRMISHER` (60 HP) with Static Pulse in 10 shots over `3.5 s`.
2. Static Pulse cannot be removed from the cycle by any input, Loadout, or Mod.
3. Player at `(0, −50, 0)` — below `oob_volume` — returns to the last checkpoint with Health `max(current, 25)`, no death.
4. With zero AP receipts, the player completes fixture 19 end to end.

## Movement
5. Jump from flat ground reaches exactly `1.245 m` apex within `0.001 m`.
6. Horizontal jump distance at `WALK_SPEED` is `4.373 m` ± `0.01`.
7. A `3.923 m` gap (`MAX_SAFE_GAP`) is crossable; a `4.5 m` gap is not.
8. Leaving a ledge and jumping within `0.12 s` succeeds; at `0.13 s` it fails.
9. Jump pressed `0.15 s` before landing executes on landing; at `0.16 s` it does not.
10. Air-strafing for `10 s` never exceeds `6.5 m/s` horizontal from input alone.
11. A `20 m/s` LaunchPad impulse is not clamped down by air control.

## Controls
12. Q, E, 1, 2, 3 activate five distinct hosts.
13. `Shift` activates Mobility and never changes base speed.
14. `F` never activates any generated combat content, across all 12 Ability families.
15. `MMB` reaches baseline melee with any Weapon selected and during a reload.
16. `R` affects only the selected Weapon's feed.
17. Rebinding `ability_e` to `G` leaves slot E's contents unchanged.
18. Binding `G` to `ability_e` when `G` is bound to `jump` is refused; `jump` keeps `G`.

## Weapon cycle
19. Static plus three Weapons yields exactly 4 cycle states.
20. With Weapons in slots 0 and 2 only, the cycle is 3 states and skips slot 1 with no input cost.
21. Fire 5 of 30 rounds, cycle away, cycle back: `magazine_rounds == 25`.
22. Heat to `60`, cycle away for `2.0 s` at `inactive_cool_rate 12.0`: heat is `36.0`.
23. Cycle away during a reload at `1.0 s` of `1.8 s`, cycle back: reload is not in progress and rounds are unchanged.
24. Reach `heat_max`, cycle away, cycle back at `1.0 s`: still in lockout, heat is `60.0` (linear drain over `2.5 s`).
25. An unselected Weapon's `TRIGGER` Mods do not fire on any event.
26. A `PROJECTILE_LOB` in flight when its Weapon is cycled away still detonates and credits that Weapon.
27. Every Weapon in the catalog kills a `SKIRMISHER` unassisted with no other Weapon equipped.

## Feeds
28. Firing at `magazine_rounds = 0` produces no shot, no cost, and no auto-reload.
29. Reload from `0` yields exactly `magazine_capacity` at exactly `reload_duration`.
30. A vent interrupted at `50%` leaves heat unchanged.
31. Releasing a charge at `0.20` with `min_charge_fraction 0.25` fires nothing and costs nothing.
32. A charge at `1.0` held for `hold_max` auto-releases at full damage.
33. `CHARGE_RELEASE_SHOT` at charge `0.5` on `charge_lance` deals exactly `57.5` (`20 + 0.5 × 75`).
34. Primary and `ALT_FIRE` cannot both be mid-action on any tick, across 10,000 randomized input sequences.

## Ability recharge
35. A `RESOURCE` ability at `20` resource with `cost 25` fails preflight and spends nothing.
36. `cd_double` recharges serially: two spent charges return at `10 s` and `20 s`, never both at `10 s`.
37. `act_melee_three` advances only on melee hits that dealt Health damage — not on hits fully absorbed by Barrier.
38. A `PHYSICS_VERB` with no eligible target in range spends nothing.
39. A committed projectile that misses receives no refund.
40. `OVERCRIT_GENERATES_RESOURCE` on an ability whose own damage overcrits generates `0` from that overcrit.
41. Recharge reduction from all sources never exceeds `60%`: `cd_single_long` never recharges faster than `7.2 s`.
42. `RESOURCE`, `COOLDOWN`, and `ACTION` render with three visually distinct HUD treatments.
43. Loading a `(family, activation, recharge)` triple absent from §12.9 is a hard error naming the triple.
44. A `HEAL_CHANNEL` sample at full Health restores `0` and still pays full cost; the channel then ends.

## Interaction
45. `F` with a terminal at `12°` and a cube at `4°` from centre activates the **terminal** (priority class 1 beats class 3).
46. While carrying, `F` with a compatible socket at `20°` and a lever at `2°` **places into the socket** (class 2 beats class 4).
47. Two interactables at identical angle and distance resolve identically across 1,000 runs.
48. `F` activates a Check; the Check confirms and is never undone by death, reset, or reload.
49. A required carryable dropped outside `oob_volume` respawns at `home_transform` with the same `id`.
50. A Check in a room with an active encounter shows `Area not secure` and cannot be activated.

## Physics
51. A `LIGHT` object within range is moved by `PUSH`.
52. A `required` object with `physics_permitted = false` is not manipulable despite being `LIGHT`.
53. No sequence of Physics inputs moves the player, across 10,000 randomized attempts.
54. Player-owned object impact on the player deals exactly `0`.
55. An object resting on an enemy deals damage at most once per `1.0 s`.
56. Physics-imparted vertical velocity never exceeds `12.0 m/s`.
57. Impact damage never exceeds `45.0` at any speed.

## Damage, crit, Status
58. No code path writes Health outside the resolver — verified by making Health private and auditing all call sites.
59. The same non-crit attack on the same target state produces identical damage across 1,000 repetitions.
60. `crit_chance 1.0` produces `crit_tier 1` on 10,000 of 10,000 hits.
61. `crit_chance 1.5` produces tier 1 or 2 and never tier 0, across 10,000 hits; tier 2 occurs on `50% ± 2%`.
62. `crit_chance 4.5` produces tier 4 on every hit (clamped).
63. Multipliers are exactly `{1,2,3,4,5}` — never `{1,2,4,8,16}`.
64. No Status schedules a `DamageRequest`. Verified by static analysis of Status code plus a runtime assertion.
65. `BURNING` on a `burnable` surface spawns a `FIRE_ACTOR` whose damage is credited to the `BURNING` applier.
66. `BURNING` on a non-burnable enemy in an empty room deals `0` damage over its full `6 s`.
67. A failed application raises `susceptibility` by exactly `0.15`, capped at `0.45`.
68. A success zeroes susceptibility and raises `adaptation` by `0.20`, capped at `0.50`.
69. Adaptation decays at `0.05/s` with no attempts and floors at `0.0`.
70. A boss takes `CONFUSED` when `TURNCOAT` is applied, at the same duration.
71. Effective chance is never below `0.05` or above `0.95` across all archetype and modifier combinations.
72. `ANCHORED` and `LIGHTENED` never coexist on one target.

## Loadout
73. Unequipped Archive entries produce zero listeners, reactions, resources, actors, or queries — verified by instrumenting every registration point and asserting the count with a 500-entry Archive.
74. Loadout cannot be edited outside the Hub.
75. Re-equipping a host used earlier in this Zone instance restores its exact saved state.
76. A never-used host introduced to an active Zone starts at every cold value in §5.7.
77. Installing and removing Mods at the Hub costs nothing.
78. Equipping a second `HIGH` Gear piece is refused with the §34.6 message.
79. Dying with an empty resource pool respawns with the pool still empty.

## Capability and generation
80. A capability gate never appears in a Zone where §29.2 cannot prove the capability, across 10,000 seeds.
81. The same `(campaign_seed, zone_id)` produces a byte-identical Zone across 1,000 compositions, and decoration reseeding never alters composition.

---

# 39. IMPLEMENTATION WAVES

Ordered by dependency. Each wave ends at a testable state; a wave is done when its test vectors pass.

| Wave | Contents | Tests |
|---|---|---|
| 1 | Input roles, rebinding, base movement law, out-of-bounds recovery | 5–11, 17, 18 |
| 2 | Damage road, Defense, Barrier, crit, death, Static Pulse, baseline melee | 1–3, 58–63 |
| 3 | Host schemas, Archive, Loadout validation, active projection | 73, 74, 78 |
| 4 | Weapon cycle, the eight primaries, six secondaries, four feeds | 19–34 |
| 5 | Abilities, the three recharge identities, hybrids, the compatibility matrix | 35–44 |
| 6 | Mobility families, movement safety, collision recovery | 12, 13 |
| 7 | Interaction resolver, carryables, sockets, recovery | 45–50 |
| 8 | Physics primitives and impact damage | 51–57 |
| 9 | Status, application, pity, adaptation, substitution | 64–72 |
| 10 | Gear, Mods, modifier order, runtime clamps | 14–16, 77 |
| 11 | Signal graph, sensors, actuators, transition rules | fixtures 1, 3, 8, 9 |
| 12 | Hacking | fixture 7 |
| 13 | Puzzle-package contract, validation pipeline, reset groups | fixtures 1–18 |
| 14 | Hazards, destructibles, environmental kill credit | fixture 12 |
| 15 | Enemies, archetypes, encounters, waves | fixture 13 |
| 16 | Persistence: all five categories, reconstruction order, mid-transition | 75, 76, 79 |
| 17 | Zone composition, audit, retry, fallback Zone | 4, 80, 81, fixture 19 |
| 18 | Capability planner and entry validation | 80 |
| 19 | HUD, device presentation, causality feedback | 42 |
| 20 | Player-facing flow, migration, all messaging | — |

Waves 1–3 are the foundation and are strictly sequential. Waves 4–10 are player systems and may proceed in parallel once 3 is complete. Waves 11–15 are dungeon systems and may proceed in parallel with 4–10. Waves 16–20 integrate and must come last.

---

# 40. CLOSURE STATEMENT

## 40.1 What this proposal decided

Eighteen decisions that were open in the source authorities, resolved here:

1. Static Pulse is **hitscan**, `6.0` damage at `0.35 s`, `60 m`, no falloff, no spread.
2. Weapons draw from **eight closed primary families and five secondary kinds**; Epsilon selects a profile ID and never a number.
3. Abilities draw from **twelve families** governed by an explicit `(family, activation, recharge)` compatibility matrix.
4. Mobility draws from **five families**, with ground and air legality specified per family.
5. Physics is **four primitives** — `PUSH`, `PULL`, `HOLD`, `ALIGN` — that cannot move the player and are never required for progression.
6. Status is **six non-DoT effects** in three families, with pity and adaptation tracked per family rather than per Status.
7. `BURNING` produces damage only through a separate **Fire Actor**, closing the no-DoT law against circumvention.
8. Defense is a **hyperbolic curve with no cap**, self-limiting and unable to reach full mitigation.
9. Barrier grants **sum into one pool** with independent expiries; the worked example in §8.4 is the contract.
10. Death **preserves all host runtime state** and restores only Health.
11. Cold introduction is **fully specified** and reachable only through Hub re-entry.
12. There is **no throw**; dropping is always zero-velocity.
13. The signal graph is an **acyclic DAG with eleven node types** evaluated in topological order within a single tick.
14. Machinery is **kinematic** and **holds position on power loss** rather than returning to rest.
15. Dungeon macro-state is **four forward-only Boolean flags**, making cross-room cycles impossible by construction.
16. Zone shape is a **linear spine of 8–16 rooms with dead-end branches** — a tree, so composition cannot cycle.
17. Composition is **fully deterministic and bridge-owned**; Epsilon has no role in it.
18. Capability gates are **four**, and one of them (`ranged_hit`) is permanently satisfied by the baseline.

## 40.2 What this proposal sacrificed

Honestly and without hedging:

| Sacrifice | What is lost |
|---|---|
| **Forge** | The entire item-synthesis economy. Mods accumulate inertly; Epsilon Static has no sink. This is the largest single loss, and it means long campaigns have a growing pile of items with no use. |
| **Energy balls and reflector beams** | Two of the twenty puzzle families the Dungeon Authority names, and the most spatially interesting routing puzzles available. |
| **Water as a medium** | Swimming, buoyancy, oxygen, fill and drain, and every puzzle built on changing water level. |
| **Dynamic joints** | Ropes, pulleys, counterweights, pendulums. A crane cannot swing its load. Physical puzzles lose their most tactile family. |
| **Throwing** | A verb the Dungeon Authority explicitly lists. Carryables can only be walked into position. |
| **Physics as a puzzle requirement** | Physics can shortcut a puzzle but never be the point of one. This is a real loss of expressive range, taken to eliminate a class of unwinnable-seed failures. |
| **Reconfigurable global machinery** | Forward-only flags mean a dungeon can turn on but never be rerouted. The Dungeon Authority's "rail network rerouted" macro state is inexpressible. |
| **Branching Zone topology** | A tree spine means no loops, no shortcuts back to earlier rooms except one-way drops, and no genuinely non-linear dungeon. |
| **Enemy-applied Status** | Status is player-side only. Enemies cannot anchor, confuse, or expose the player. |
| **Grapple spring dynamics** | Constant-speed pull rather than a simulated spring. Traversal feels slightly more mechanical. |

## 40.3 Proposal-level choices the authorities did not mandate

These are places where the authorities were silent and this proposal decided. They are the decisions most worth reviewing, because a different proposal could reasonably decide otherwise:

- No fall damage.
- Enemies never apply Status to the player.
- Death preserves everything except Health.
- Auto-equip does not exist.
- Hacking cannot be failed.
- Physics never gates progression, which is stricter than the authorities require.
- Composition excludes Epsilon entirely, which is also stricter than required.
- Save is refused during encounters rather than specified for them.

## 40.4 Where this proposal disagrees with an authority

Nowhere. Every inherited law in §1 is honoured. If a reader finds a contradiction, it is a defect in this document and should be reported rather than resolved locally (§1.3).

## 40.5 The claim

**There are no intentionally open behavioral decisions in this proposal.**

Anything not described here is one of:

- inherited unchanged from the two source authorities, and listed in §1;
- rejected by a closed schema in §4, which makes it unrepresentable;
- explicitly deferred in §2.2, with its cost stated;
- an engineering decision that belongs to the implementer per §0.

If an implementer encounters a moment of play where this document does not say what happens, that is a defect in this document. It is not permission to decide.

---

**End of Complete Design 1: Reliable Core**
