> ## ⚠ REFERENCE ONLY — NOT CANON, NOT COMPLETE
>
> This is a salvaged third-party draft (GPT-5, 2026-09-02), kept only as a
> structural reference. **Do not implement from this document.**
>
> Its own author audited it at roughly **85% of a zero-guesswork authority** and
> listed twelve unclosed areas: content-generation rules, machine-readable
> schemas, weapon delivery edge cases, the ability compatibility matrix,
> movement/physics details, machinery transition behavior, persistence edge
> cases, the enemy/encounter contract, concrete dungeon fixtures, player-facing
> flow, external contract pinning, and test vectors. It also contains at least
> one known internal contradiction (Gear intrinsic count: one section says
> exactly one intrinsic, another correctly gives high-tier Gear two).
>
> A rewrite closing those gaps was in progress when the authoring session
> crashed; that work was lost. The canonical proposals live in
> `docs/design-proposals/` and are written from the source authorities in
> `docs/authorities/`, not from this file.

# ARCHIPEPSI — COMPLETE DESIGN 1: RELIABLE CORE

## Conservative resolution proposal for the Player and Dungeon authorities

**Status:** Complete alternative proposal; not canon until selected by the owner

**Proposal:** 1 of 5

**Design thesis:** Prefer a finite, typed, observable implementation over a broader simulation.

**Target:** Godot 4.5 client plus the existing Python/Pydantic bridge
**Source authorities:** ARCHIPEPSI Player Design Authority v1.0 and Dungeon & Environmental Gameplay Authority v0.1

## Proposal profile

| Axis | Rating |
|---|---:|
| Novelty | 2/5 |
| Player-build variety | 4/5 |
| Environmental breadth | 3/5 |
| System interaction depth | 3/5 |
| Implementation risk | 2/5 |
| Procedural validation difficulty | 2/5 |
| Reuse of current repo foundations | 5/5 |

**Principal tradeoff:** Reliable Core preserves the broad identity of the game by narrowing how each idea is expressed. It defers the systems most likely to multiply physics, persistence, and procedural-validation failures.

---

# 0. PURPOSE

This proposal resolves the parts of the Player and Dungeon authorities that are currently directional rather than executable.

It deliberately chooses ordinary, proven game structures:

- closed catalogs instead of invented runtime mechanics;
- discrete state machines instead of continuous general simulation;
- tagged interactions instead of inferred material behavior;
- authored puzzle packages instead of arbitrary signal graphs;
- one active Zone and a small number of loaded rooms;
- monotonic cross-room state instead of reversible global machinery;
- conservative limits that can be widened after profiling.

This is the "boring working" design. Its job is to create a version Claude can implement without deciding what the game means while writing code.

Where this proposal says **DEFERRED**, the feature is not silently missing. Its schema value is rejected, its generator option is absent, and its UI does not advertise it.

---

# 1. INHERITED LAWS

The following existing decisions remain canonical:

1. The player carries one Epsilon device.
2. Static Pulse is permanent and always selectable.
3. The Weapon cycle contains Static Pulse plus up to three Weapon Echoes.
4. LMB is selected Weapon primary, RMB is its intrinsic, and R services its feed.
5. Q, E, 1, 2, and 3 are five direct Ability slots.
6. Shift is one dedicated Mobility slot.
7. MMB is permanent baseline melee.
8. F is universal world interaction.
9. There is no baseline sprint, crouch, slide, or Signature slot in v1.
10. There is no persistent conventional ammunition inventory.
11. Resource, Cooldown, and Action recharge identities coexist.
12. Runtime resources are not AP items or currencies.
13. Every loss of Health or Barrier uses one typed damage road.
14. Ordinary base damage is deterministic.
15. Overcrit scales linearly.
16. Status is chance-based with visible pity and adaptation.
17. Status never deals periodic damage.
18. The player has Head, Torso, Arms, and Legs Gear slots.
19. Only one equipped Gear piece may be high-tier.
20. Full loadout editing occurs at the Hub and is free.
21. Only equipped hosts and their installed Mods are live.
22. Required progression never precedes a proven capability guarantee.
23. Raw DPS is never progression truth.
24. AP Check transactions remain separate from local puzzle truth.
25. Epsilon chooses within closed schemas and never writes executable behavior.

---

# 2. V1 SCOPE

## 2.1 Ships in Reliable Core

Reliable Core includes:

- the final semantic input grammar and rebinding;
- base movement, Static Pulse, melee, death, and recovery;
- three Weapon slots with seven finite primary families;
- five Ability slots with ten finite non-Physics Ability families and four Physics primitives;
- one Mobility slot with five finite Mobility families;
- Resource, Cooldown, and Action recharge;
- six non-damaging Status families;
- four Gear slots and a finite Mod catalog;
- Hub-only loadout editing and a large inactive Archive;
- F interaction, ordinary carrying, sockets, local keys, and recovery;
- four bounded Physics primitives;
- a deterministic signal graph;
- common inputs, sensors, conduits, and actuators;
- eighteen of the twenty initial puzzle-package families;
- destruction, reactive barrels, recoverable bombs, and five hazard families;
- existing rails, LaunchPads, bounce pads, wind volumes, and moving platforms;
- forward-only Zone flags for limited multi-room state;
- deterministic generation, physical audits, semantic reset, save/load, debugging, and accessibility contracts.

## 2.2 Explicitly deferred

The following do not ship in Reliable Core v1:

- Forge synthesis;
- in-Zone loadout stations;
- Physics-created constructs;
- Physics tether, pin, mass change, and enemy carrying;
- raw energy-ball routing;
- environmental beam reflection and splitting;
- swimming, oxygen, buoyancy, fill/drain, and dynamic water levels;
- gas, smoke, pressure, heat/cold simulation, and vacuum;
- directional gravity and whole-room gravity reorientation;
- portals and space folding;
- dynamic ropes, pulleys, chains, and unconstrained joints;
- sound-triggered sensors;
- light-sensitive sensors;
- programmable logic;
- arbitrary material chemistry;
- arbitrary terrain destruction;
- reversible cross-room A/B state;
- recursive or cyclic dungeon dependencies.

Ankle- to knee-deep decorative water may exist, but it has no gameplay effect in this proposal.

## 2.3 Removed rather than deferred

Reliable Core rejects:

- new items modifying every owned item globally;
- arbitrary user-authored circuitry;
- runtime-generated collision meshes;
- loose physics debris as a valid puzzle input;
- mandatory Physics Echo solutions;
- ammunition drops;
- automatic loadout swapping at Zone entry;
- hidden difficulty scaling based on build DPS.

---

# 3. AUTHORITY AND DATA OWNERSHIP

## 3.1 Bridge authority

The Python bridge owns and persists:

- AP identity, receipts, pending Checks, and reconciliation;
- the append-only interpretation/provenance log;
- Archive definitions;
- equipped loadout IDs;
- generated Zone manifests;
- confirmed AP Check state;
- Zone completion and abandonment;
- persistent room and Zone semantic state;
- the active-excursion runtime snapshot;
- settings that affect generation.

All persisted writes are atomic and schema-versioned.

## 3.2 Godot authority

Godot owns:

- transforms, velocity, collision, and current simulation;
- current Health and Barrier;
- live Weapon feed state;
- Ability and Mobility readiness state;
- live Status state;
- room-local signal evaluation;
- active hazards, projectiles, Actors, and VFX;
- focus selection and player interaction;
- physical validation against instantiated geometry.

Godot reports semantic snapshots. It never asks the bridge to persist arbitrary rigid-body transforms.

## 3.3 Epsilon authority

Epsilon may select:

- one legal host or Mod template;
- legal bounded parameters;
- display name, short description, and provenance presentation;
- one legal room purpose;
- one legal shell ID;
- legal package families and named offers supplied in the request;
- legal presentation variants.

Epsilon may not provide:

- code;
- callback names;
- file paths;
- scene paths;
- physical coordinates;
- arbitrary tags;
- formulas;
- unbounded numbers;
- novel signal topology;
- AP truth;
- hard capability truth.

## 3.4 Stable identifiers

Every persistent semantic object has an ASCII lowercase identifier of at most 48 characters.

Required prefixes are:

| Kind | Prefix |
|---|---|
| Weapon host | weapon_ |
| Ability host | ability_ |
| Mobility host | mobility_ |
| Gear host | gear_ |
| Mod | mod_ |
| Resource pool | pool_ |
| Status family | status_ |
| Room object | object_ |
| Signal node | signal_ |
| Actuator | actuator_ |
| Puzzle package | puzzle_ |
| Reset group | reset_ |
| Zone flag | zoneflag_ |

IDs are assigned once and never regenerated from display names.

## 3.5 Validation behavior

Unknown fields, enum values, identifiers, and out-of-range numbers are rejected rather than ignored or clamped.

Provider output receives:

1. structural validation;
2. semantic validation against the request;
3. at most one repair request;
4. deterministic local fallback if repair fails.

Loaded historical data receives an explicit migration. It is never passed through the current validator and silently truncated.

---

# 4. ACTIVE BUILD MODEL

## 4.1 Host categories

The active build contains:

- Static Pulse;
- zero to three Weapon hosts;
- zero to five Ability hosts;
- zero or one Mobility host;
- zero or one Head Gear;
- zero or one Torso Gear;
- zero or one Arms Gear;
- zero or one Legs Gear;
- Mods installed only on those equipped hosts.

An unequipped definition produces no runtime listener, resource, modifier, Actor, Status attempt, scheduled task, target query, or presentation element.

## 4.2 Required host fields

Every active host definition includes:

- host_id;
- host_kind;
- display_name;
- description of at most 160 characters;
- source provenance IDs;
- quality: USEFUL or HIGH_TIER;
- one closed mechanic template;
- bounded template parameters;
- Mod capacity;
- compatible Mod families;
- presentation family;
- schema version.

Only Gear uses the one-high-tier-equipped restriction.

## 4.3 Mod capacity

- Useful host: 2 Mod slots.
- High-tier host: 4 Mod slots.
- Empty slots are legal.
- The same Mod ID cannot occupy two slots.
- Exact duplicate Mods consolidate into one Archive row with a provenance count.
- Duplicate count gives no mechanical rank in Reliable Core.

## 4.4 Excursion commitment

Entering an uncompleted Zone creates an excursion and locks the equipped host IDs.

Returning to the Hub suspends the excursion. The player may inspect the Archive but may not change its committed loadout.

The player may:

- resume with the exact committed loadout;
- abandon the Zone, discarding unconfirmed local state but retaining confirmed AP truth;
- complete the Zone, ending the excursion.

A completed Zone revisit is a new excursion with a newly committed loadout and fresh host readiness.

This removes every v1 cold-introduction case. No host can enter an already-active excursion.

Abandoning ends the excursion permanently. It discards that Zone's runtime, PUZZLE_LOCAL, ROOM_PERSISTENT, and ZONE_PERSISTENT state. Confirmed AP Checks, received items, Archive/provenance, and campaign currency remain. An abandoned Zone cannot be resumed.

## 4.5 Closed schema shapes

Reliable Core introduces:

- PLAYER_CONTENT_SCHEMA_VERSION = 1;
- ENVIRONMENT_SCHEMA_VERSION = 1;
- RUNTIME_SNAPSHOT_VERSION = 1.

The historical interpretation schema keeps its existing version and is not renamed.

Every model forbids extra fields and is a discriminated union on its family/kind field.

### WeaponHost

Common host fields plus:

- primary: one Weapon-family union from section 11;
- secondary: NONE, AIM, ALT_FIRE, or DETONATE_OWNED;
- secondary_parameters, present only when required by that secondary;
- feed: MAGAZINE, HEAT, CHARGE, or NONE;
- feed_parameters, whose union must match feed;
- presentation_family matching primary;
- mod_slots: exactly 2 or 4 from quality.

### AbilityHost

Common host fields plus:

- ability: one Ability-family union from section 12 or one Physics primitive;
- activation form;
- recharge identity;
- recharge parameters whose union matches that identity;
- target filter;
- crit permission;
- presentation family;
- mod_slots.

### MobilityHost

Common host fields plus:

- mobility family from section 13;
- fixed family parameters;
- advertised capability;
- fixed COOLDOWN state from section 13;
- presentation family;
- mod_slots.

### GearHost

Common host fields plus:

- gear_slot: HEAD, TORSO, ARMS, or LEGS;
- one intrinsic for USEFUL or exactly two for HIGH_TIER;
- target bindings required by targeted intrinsics;
- mod_slots.

### ModDefinition

Fields:

- mod_id;
- display name/description;
- provenance IDs;
- family: AUGMENT, TRIGGER, PASSIVE, CONVERSION, LINK, or TRADEOFF;
- compatible host kinds/families;
- one matching parameter union;
- quality;
- schema version.

### CommittedLoadout

Fields:

- weapon_a, weapon_b, weapon_c;
- ability_q, ability_e, ability_1, ability_2, ability_3;
- mobility;
- gear_head, gear_torso, gear_arms, gear_legs;
- mod IDs by host slot;
- link endpoint bindings;
- target bindings for targeted Gear;
- stable loadout_hash derived from canonical serialized content.

Every host field is a nullable semantic ID. Static Pulse is implicit and cannot be removed.

### RuntimeSnapshot

Fields:

- excursion_id;
- snapshot sequence;
- loadout_hash;
- player Health and Barrier;
- selected Weapon state;
- Weapon feed state by equipped host ID;
- Ability readiness/cost state by host ID;
- Mobility readiness state;
- active pool state;
- current room and checkpoint IDs;
- PUZZLE_LOCAL semantic states;
- ROOM_PERSISTENT semantic states;
- Zone flags and local keys;
- snapshot version.

The bridge rejects a runtime snapshot whose excursion_id or loadout_hash differs from the active committed excursion.

---

# 5. LIFECYCLE AND PERSISTENCE

## 5.1 Saved categories

| Category | Examples | Save behavior |
|---|---|---|
| CAMPAIGN | Archive, provenance, loadout, currencies | Permanent |
| AP_PERSISTENT | Confirmed Checks, received items | AP transaction authority |
| ZONE_PERSISTENT | Forward Zone flags | Survives unload, death, suspension, and revisit |
| ROOM_PERSISTENT | Permanent shortcut, repaired generator | Survives unload, death, suspension, and revisit |
| PUZZLE_LOCAL | Lever, socket, bridge state | Saved during an active excursion; incomplete state resets on death |
| EPHEMERAL | Pulses, projectiles, timers, temporary fields | Never persisted |

## 5.2 Runtime snapshot cadence

Godot emits a semantic runtime snapshot:

- after a completed interaction;
- after a room transition;
- when a checkpoint is touched;
- before Return to Hub;
- before an ordinary save-and-quit;
- every ten seconds while state is dirty.

Snapshots are idempotent and contain a monotonically increasing excursion sequence number. The bridge ignores an older sequence.

## 5.3 Death

On lethal damage:

1. Active holds, channels, charge, reload, vent, and interaction UI cancel.
2. Current magazine counts, Heat, Resource values, Cooldown charge progress, and Action progress are preserved at the moment of death.
3. Temporary player stat pulses and defensive states clear.
4. Temporary spawned Actors and projectiles clear.
5. Incomplete PUZZLE_LOCAL reset groups return to their declared initial state.
6. ROOM_PERSISTENT, ZONE_PERSISTENT, and AP_PERSISTENT truth remains.
7. Encounter enemies since the last checkpoint respawn.
8. After 1.5 seconds, the player respawns at the latest valid checkpoint with 100 Health and 0 temporary Barrier.
9. Runtime timers do not advance during the death delay.

Death therefore restores playability without refilling combat economies.

## 5.4 Room unload

- EPHEMERAL state clears.
- Loose required objects return to their semantic spawn unless socketed.
- Socketed objects and completed puzzle stages serialize semantically.
- Ordinary decorative objects need not persist.
- Runtime resources and Weapon state belong to the excursion, not the room, and remain unchanged.

## 5.5 Save/load

Loading reconstructs definitions first, then the committed loadout, then the Zone manifest, then semantic room state, then runtime host state.

If a host definition is unavailable or quarantined:

- keep its Archive/provenance record;
- leave its active slot empty;
- never substitute a different mechanic;
- show a migration notice at the Hub;
- Static Pulse and baseline actions remain usable.

---

# 6. BASE PLAYER

## 6.1 Starting values

| Value | Reliable Core default |
|---|---:|
| Health | 100 |
| Baseline Barrier | 0 |
| Walk speed | 7.0 m/s |
| Ground acceleration | 28.0 m/s² |
| Ground deceleration | 36.0 m/s² |
| Air acceleration | 11.2 m/s² |
| Gravity | 24.0 m/s² |
| Jump velocity | 8.0 m/s |
| Coyote time | 0.12 s |
| Jump buffer | 0.10 s |
| Terminal fall speed | 30.0 m/s |
| Player capsule radius | 0.40 m |
| Player capsule height | 1.80 m |
| Eye height | 1.60 m |

Movement uses fixed-timestep acceleration through move-toward logic. It does not use frame-dependent interpolation.

## 6.2 Out-of-bounds

Authored recovery volumes take priority over death. They return the player to the volume's named recovery transform after a 0.25-second fade and preserve combat state.

Crossing global Y = -30 without a recovery volume causes ordinary death.

Reliable Core has no ordinary fall-damage calculation. A fall either lands normally, enters an authored recovery volume, or crosses the global out-of-bounds boundary.

Every mandatory traversal route must name at least one valid checkpoint or recovery transform behind it.

## 6.3 Static Pulse

Static Pulse is a hitscan Weapon configuration with:

- 6 base damage;
- 0.35-second cadence;
- 40-metre range;
- one target;
- no spread;
- no falloff;
- no feed state;
- no knockback;
- ordinary Weapon crit eligibility;
- permission to trigger baseline shootable targets.

The first solid collider stops the trace. An ineligible collider produces an impact response but no damage.

SCATTER ray patterns and all other bounded spread patterns use a fixed spiral sample set rotated by a deterministic hash of attack_instance_id. Scene reload cannot reroll a committed spread.

## 6.4 Baseline melee

Baseline melee uses a 100-degree forward sphere sweep:

- origin: player chest;
- reach: 2.2 metres;
- sweep radius: 0.45 metres;
- maximum targets: 3, sorted nearest first;
- base damage: 12;
- recovery: 0.55 seconds;
- target impulse: 4.0 m/s;
- ordinary direct-attack crit eligibility;
- permission to break MELEE_BREAKABLE props.

One activation can damage each target at most once. It spends no resource and remains available with an empty build.

---

# 7. INPUT AND REBINDING

The semantic controls from the Player Authority are used unchanged.

Gameplay code consumes semantic actions only. Definitions never contain physical keycodes.

Reliable Core officially supports keyboard and mouse in v1. Controller inputs may be bound through the same action layer but are not a v1 certification target.

The binding screen:

- lists every player-facing semantic action;
- captures keyboard and mouse inputs;
- displays existing conflicts;
- offers SWAP or CANCEL when the new binding conflicts;
- prevents removal of the last binding for Move, Look, Jump, Weapon Primary, Interact, Pause, and Menu Confirm;
- supports Reset All to canonical defaults;
- saves settings outside campaign saves.

Debug bindings are hidden unless developer mode is enabled.

---

# 8. COMMON DAMAGE ROAD

## 8.1 Damage request

Every damage request contains:

- unique hit_id;
- attack_instance_id;
- source semantic ID;
- instigator actor ID or WORLD;
- target actor ID;
- base_amount;
- source position;
- normalized impulse direction;
- impulse magnitude;
- zero or more closed damage tags;
- crit permission;
- crit chance in percentage points;
- flat Defense penetration;
- zero or more separate Status attempts.

Legal v1 damage tags are:

- RANGED;
- MELEE;
- PROJECTILE;
- BEAM;
- EXPLOSIVE;
- PHYSICS;
- FIRE;
- CONSTRUCT;
- ENVIRONMENTAL;
- HAZARD.

Tags communicate cause. They do not create automatic resistance channels.

## 8.2 Resolution order

For each unique hit_id:

1. Reject a duplicate hit, dead target, invalid target, or non-positive base amount.
2. Resolve invulnerability and an eligible active Parry.
3. Apply source outgoing-damage modifiers.
4. Resolve crit and linear overcrit.
5. Apply explicit target modifiers such as BLOCK or MARKED.
6. Subtract flat Defense penetration from Defense, minimum zero.
7. Convert remaining Defense to mitigation.
8. Apply mitigated damage to Barrier.
9. Apply the remainder to Health.
10. Apply bounded impulse.
11. Emit one immutable DAMAGE_RESOLVED fact.
12. Resolve attached Status attempts.
13. If Health reached zero, emit one KILL fact and perform death.

No effect directly writes Health or Barrier.

## 8.3 Defense

Defense is in the range 0–150.

After penetration:

    mitigation = defense / (defense + 100)

Final mitigation is capped at 60%.

Invulnerability is a separate boolean rule and never represented as extreme Defense.

After passive modifiers, BLOCK, and Defense, a non-parried/non-invulnerable hit deals at least 15% of its post-crit amount.

BLOCK affects only a hit whose source lies inside its declared facing arc and whose tags include MELEE, RANGED, PROJECTILE, or BEAM. It does not reduce EXPLOSIVE, PHYSICS, ENVIRONMENTAL, or HAZARD damage.

PARRY checks a 120-degree facing arc. It may negate one MELEE or PROJECTILE hit during its active window. A successful Parry sets damage and impulse to zero, consumes the window, and emits PARRY_SUCCESS. It cannot parry hitscan RANGED, BEAM, EXPLOSIVE, PHYSICS, ENVIRONMENTAL, or HAZARD damage.

## 8.4 Barrier

Barrier absorbs post-Defense damage before Health.

- Barrier has no natural regeneration.
- Temporary Barrier cannot exceed 100.
- Granting Barrier adds up to the cap.
- Barrier granted by a duration loses only the unused amount from that grant when the duration expires.
- Barrier clears on death and at the end of an excursion.

## 8.5 Crit

Crit uses the canonical linear overcrit formula.

- Tier I adds 1× base final attack damage.
- Tier II adds 2×.
- Tier III adds 3×.
- The technical crit-chance ceiling is 400%.
- Displayed damage rounds to the nearest integer; simulation retains floats.

The crit remainder roll is deterministic from Zone seed, attack_instance_id, and pellet index. Save/load cannot reroll a committed attack.

Direct Weapon attacks, baseline melee, and explicitly tagged direct Abilities may crit.

Physics impacts, hazards, Statuses, reactive barrels, passive Actors, and secondary explosions do not crit unless a closed authored template explicitly opts in. Reliable Core supplies no such opt-in for those families.

## 8.6 Friendly and self damage

- Player attacks do not damage friendly actors by default.
- Enemy attacks do not damage other enemies unless ENVIRONMENTAL.
- Player-owned explosions deal 50% damage to the player.
- World hazards use their authored actor filters.
- Impulse may affect an actor even when friendly damage is zero if the source explicitly permits friendly impulse.

## 8.7 Healing

Healing uses a typed HEAL_REQUEST containing source ID, target ID, and positive amount.

The Health service rejects a dead or full-Health target, clamps the result to 100 Health, and emits HEAL_RESOLVED with requested and actual amounts. Healing cannot crit and does not revive.

---

# 9. WORLD INTERACTION

## 9.1 Candidate requirements

An interaction candidate must:

- be within 3.0 metres of the camera;
- be inside a 12-degree center-screen cone, unless directly ray-hit;
- have unobstructed line of sight;
- expose one currently legal verb;
- not be disabled without a readable reason.

The player capsule and the carried object do not block the query.

## 9.2 Deterministic focus

Candidates are sorted by:

1. semantic priority;
2. smallest angle from screen center;
3. shortest distance;
4. lexical semantic ID.

Priority from highest to lowest is:

1. continuation of an already-open modal interaction;
2. compatible Place/Insert action for the carried object;
3. explicit terminal, control panel, or AP Check under the reticle;
4. pickup target;
5. button, lever, door, socket, or reset control;
6. optional contextual interaction.

The prompt shown before the press is authoritative.

## 9.3 Activation

F activates on just-pressed, not release.

Ordinary world interactions complete immediately unless their contract opens a modal interaction. Holding F is not a second hidden verb.

An illegal activation:

- changes no state;
- spends nothing;
- plays one rejection cue;
- displays a reason for 1.25 seconds.

## 9.4 AP Checks

An AP Check uses the same focus and F input but dispatches to the AP transaction service.

Pending, sent, confirmed, and reconciliation states belong to that service. A local signal never directly marks an AP location complete.

---

# 10. CARRYABLES AND SOCKETS

## 10.1 Semantic object classes

| Class | Semantic weight | Baseline F carry | Physics target |
|---|---:|---|---|
| LIGHT | 0.5 | Yes | Yes |
| WEIGHTED | 2.0 | Yes | Yes |
| COMPONENT | 0.5 | Yes | Only if package allows |
| COVER | 3.0 | No | Push/Pull only |
| HEAVY | 4.0 | No | No |
| FIXED | 0.0 | No | No |

Loose debris always has semantic weight 0.

## 10.2 Pickup

Picking up an object:

- requires the object to advertise BASELINE_CARRY;
- stores its last valid semantic spawn/socket state;
- moves it to a carry anchor 1.6 metres forward and 0.2 metres below the camera;
- changes it to kinematic carry mode;
- disables collision with the player only;
- preserves collision with world geometry;
- permits only one carried object.

The object sweeps toward the anchor. If geometry blocks it, it stops at the last clear point. If it remains more than 2.5 metres from the anchor for 0.5 seconds, it drops at the last valid position.

WEIGHTED objects multiply walk speed and jump velocity by 0.85 while carried. LIGHT and COMPONENT objects do not change movement.

## 10.3 Drop and place

Reliable Core has no baseline throw button.

While carrying:

- F inserts/places when a compatible socket is focused within 1.0 metre;
- otherwise F drops at the nearest clear floor position within 1.25 metres ahead;
- if no safe drop exists, nothing happens and the prompt says NO CLEAR DROP.

Socketed objects become kinematic and cannot be moved by Physics. A removable socket exposes REMOVE through F. A progression socket may declare LOCK_ON_COMPLETE and then cannot be removed after completion.

## 10.4 Recovery

Every required object has:

- semantic object ID;
- named spawn;
- allowed room volume;
- reset group;
- replacement delay;
- optional socket state.

Leaving the allowed volume dissolves the object and respawns it after 1.0 second.

Destroying a replaceable required object respawns it after 2.0 seconds.

Every required-object package includes an obvious reset control. Reset is disabled while the object is correctly locked into a completed socket.

Loose transforms are not saved. On room reload, the object is reconstructed at its spawn or recorded socket.

---

# 11. WEAPONS

## 11.1 Closed primary-family catalog

Reliable Core supports exactly seven Weapon primary families:

| Family | Delivery | Legal feed | Bounded parameters |
|---|---|---|---|
| HITSCAN | One ray | MAGAZINE or NONE | damage 4–20, cadence 0.12–0.90 s, range 15–60 m |
| SCATTER | 5–12 deterministic rays | MAGAZINE | pellet damage 2–7, cadence 0.55–1.30 s, spread 6–20°, range 8–30 m |
| BURST | 2–5 hitscan shots | MAGAZINE | damage 3–12, interval 0.06–0.18 s, burst recovery 0.30–1.00 s |
| PROJECTILE | One simulated projectile | MAGAZINE or NONE | damage 6–30, cadence 0.20–1.20 s, speed 12–45 m/s, lifetime 1–5 s, bounces 0–2 |
| LOB | Gravity projectile with blast | MAGAZINE | damage 15–45, cadence 0.60–1.80 s, radius 1.5–5 m, fuse 0.4–2.5 s |
| BEAM | Continuous ray while held | HEAT | 8–35 damage/s, range 10–40 m |
| CHARGE_BOLT | Charged projectile | CHARGE | minimum 5–15, maximum 25–60 damage, full charge 0.5–2.0 s |

Every generated value lies inside these ranges.

Nominal single-target damage per second must be between 14 and 45. For SCATTER, all pellets count. For BURST, all burst shots count and cadence includes burst recovery. For CHARGE_BOLT, cadence is full-charge time plus 0.25 seconds. LOB may reach 50 nominal center-target DPS because its travel and fuse are part of its risk. A Weapon outside its family range or DPS envelope is rejected.

One HITSCAN, SCATTER, PROJECTILE, or LOB activation consumes its declared feed cost once. BURST consumes that cost for each shot and stops the burst when the next shot cannot be paid. A burst commits on its first shot; switching or death cancels remaining uncommitted shots. CHARGE_BOLT has a fixed 0.25-second post-shot recovery.

## 11.2 Secondary catalog

RMB is exactly one of:

- NONE;
- AIM;
- ALT_FIRE;
- DETONATE_OWNED.

AIM changes FOV from 75° to 55° over 0.12 seconds, halves spread, and multiplies movement speed by 0.85 while held.

ALT_FIRE contains one second attack from the same closed primary catalog. It is legal only with MAGAZINE or HEAT, uses the same feed, and consumes exactly twice the primary feed cost.

DETONATE_OWNED is legal only for PROJECTILE or LOB. It detonates all live projectiles from that Weapon, oldest first, up to four. Projectiles remain after switching, but RMB can detonate them only while their Weapon is selected.

Guard, parry, scope magnification beyond AIM, Physics manipulation, and arbitrary mode scripting are not Weapon secondaries in Reliable Core.

## 11.3 MAGAZINE

MAGAZINE fields are:

- capacity: integer 1–30;
- consumption: integer 1–capacity;
- reload duration: 0.6–3.0 seconds;
- current rounds.

Rules:

1. Reserve is infinite.
2. R starts reload only when the magazine is not full.
3. Rounds are committed only when reload completes.
4. Primary, secondary, melee, Weapon switch, taking Health damage, and death cancel reload with no rounds added.
5. Pressing fire on an empty magazine starts reload and does not fire.
6. Switching preserves current rounds.
7. Reload time does not run while inactive.

## 11.4 HEAT

Heat ranges from 0 to 100.

Required fields are:

- Heat added per shot or second;
- cooling delay: 0.25–1.0 seconds;
- active cooling: 15–40 per second;
- inactive cooling policy: NONE or HALF_RATE;
- active vent duration: 0.6–1.5 seconds.

Rules:

1. An attack is legal when its cost keeps Heat at or below 100.
2. Reaching 100 triggers OVERHEATED.
3. OVERHEATED prevents firing until Heat reaches 35.
4. R starts venting. A completed vent sets Heat to 25.
5. Firing, melee, Weapon switch, taking Health damage, or death cancels vent with no Heat removed.
6. Normal cooling begins after the declared delay.
7. Inactive cooling uses either zero or half the active rate, as declared.

## 11.5 CHARGE

Holding LMB builds charge from 0 to 1.

- Minimum release threshold: 0.25.
- Releasing below threshold cancels without firing.
- Releasing at or above threshold fires with linear interpolation.
- Full charge may be held for 1.0 second, then automatically fires.
- Switching, melee, taking Health damage, death, or R cancels and clears charge.
- Charge never persists while inactive.
- R is a presentation acknowledgement and mechanical no-op.

## 11.6 NONE

NONE has no feed state. R performs a short device acknowledgement animation but changes no gameplay state and displays no ammo UI.

## 11.7 Cycling and activation

- Wheel forward and backward cycle through Static Pulse and occupied Weapon slots.
- Empty slots are skipped.
- Switching takes 0.18 seconds before the new primary may fire.
- The old Weapon stops accepting new activation immediately.
- Switching cancels reload, vent, held charge, and beam channel.
- Already committed projectiles and explosions remain.
- Per-Weapon magazine and Heat state remains.
- Inactive Weapons run no rules or listeners except declared inactive cooling.
- A fresh excursion starts MAGAZINE at capacity, Heat at 0, and Charge at 0.

---

# 12. ABILITIES, READINESS, AND COST

## 12.1 Closed Ability catalog

Reliable Core supports exactly ten Ability families:

| Family | Result |
|---|---|
| DIRECT_BOLT | One direct projectile or hitscan attack |
| RADIAL_BLAST | Bounded damage/impulse around player or impact |
| BARRIER_GRANT | Adds temporary Barrier |
| BLOCK | Reduces incoming damage while held |
| PARRY | Opens a short defensive success window |
| HEAL | Restores Health |
| RESOURCE_RESTORE | Restores a linked equipped Resource pool |
| STATUS_SHOT | Makes one Status attempt against one target |
| STATUS_FIELD | Fixed-radius temporary field making Status attempts at 1 Hz |
| SCAN | Reveals tagged actors, routes, or interactables for a duration |

PHYSICS_CAST is implemented through the separate Physics primitive catalog in section 14 and may occupy an Ability slot.

Abilities do not spawn autonomous combat AI in Reliable Core. Turrets, pets, arbitrary constructs, and programmable deployables are deferred.

## 12.1.1 Ability parameters

| Family | Legal parameters and bounds | Required activation |
|---|---|---|
| DIRECT_BOLT | damage 10–45, range 10–50 m, projectile speed 15–50 m/s or hitscan | PRESS or CHARGE_RELEASE |
| RADIAL_BLAST | damage 10–35, radius 2–6 m, impulse 0–10 m/s | PRESS |
| BARRIER_GRANT | Barrier 15–60, duration 2–12 s | PRESS |
| BLOCK | damage reduction 30–70%, facing arc 90–180° | HOLD |
| PARRY | active window 0.15–0.45 s, recovery 0.30–1.0 s | PRESS |
| HEAL | Health 15–50, no overheal | PRESS or CHANNEL |
| RESOURCE_RESTORE | restore 10–50 units to one other equipped pool | PRESS |
| STATUS_SHOT | range 10–40 m, one Status profile | PRESS or CHARGE_RELEASE |
| STATUS_FIELD | radius 2–6 m, duration 2–8 s, one attempt per target per second, maximum 8 targets | PRESS |
| SCAN | range 15–60 m, duration 3–20 s, one readout family | PRESS |

BLOCK must use RESOURCE identity and pays one 0.10-second sample at a time.

Target forms are closed:

- DIRECT_BOLT and STATUS_SHOT use AIM_RAY;
- RADIAL_BLAST declares SELF or AIM_IMPACT;
- BARRIER_GRANT, BLOCK, PARRY, and HEAL use SELF;
- RESOURCE_RESTORE uses one linked equipped pool;
- STATUS_FIELD uses a supported AIM_GROUND_POINT within 20 metres and requires a clear 2-metre vertical cylinder;
- SCAN uses a sphere centered on the player.

AIM_IMPACT commits when its projectile/trace is created; AIM_GROUND_POINT commits only after the placement cylinder passes preflight.

RESOURCE_RESTORE may use COOLDOWN or ACTION identity. It cannot target its own pool, cannot be linked in a Resource cycle, and fails preflight when the target pool is full.

HEAL channel samples restore 5 Health each and stop at full Health. A sample that would exceed maximum restores only the missing amount but pays its ordinary cost.

STATUS_SHOT and STATUS_FIELD deal zero damage unless a separate compatible damage Mod is installed and validated.

SCAN reveals exactly one readout family: ENEMY, INTERACTABLE, ROUTE, SECRET_HINT, or HAZARD. SECRET_HINT indicates that a secret exists within range but does not identify its exact interaction.

## 12.2 Activation forms

Every Ability uses exactly one activation form:

### PRESS

Preflight occurs on press. If legal, the action commits and resolves once.

### HOLD

Preflight occurs on press. The first complete 0.10-second sample is the commit. Cost is paid in complete samples. Release or inability to pay ends the action.

### CHARGE_RELEASE

Charge begins only after successful preflight. Release before minimum charge cancels free. Release after minimum commits once. Maximum hold after full charge is 1.0 second.

### CHANNEL

The channel commits one complete 0.25-second sample at a time. Each sample pays its authored cost before resolving. Missing the next payment ends the channel without debt.

Only one Ability or Mobility activation may be in a held/charge/channel state at once. Every Reliable Core held, charged, or channeled Ability blocks Weapon primary until it ends.

## 12.3 Preflight and commit

Preflight checks:

- host is equipped and ready;
- required target exists;
- destination or placement is safe;
- required pool can pay one complete cost;
- active-Actor cap is not exceeded;
- the player is alive and not interaction-locked.

Failure before commit spends nothing and creates no cooldown.

After commit, a miss, target movement, or destruction does not refund readiness or cost.

## 12.4 RESOURCE identity

A Resource Ability owns one local pool unless an explicit installed Mod links it to another equipped pool.

Pool fields:

- maximum: 20–200;
- cost per use/sample: 5–100;
- regeneration per second: 0–25;
- regeneration delay after spend: 0–5 seconds;
- presentation: BAR, PIPS, or COUNTER.

Validation requires at least one deterministic gain source. A pool with zero regeneration must have a legal equipped Link or Action fact that fills it.

Fresh excursions begin full. Resource cannot go below zero or above maximum.

At most two equipped hosts may consume one shared pool. Sharing requires a visible LINK Mod installed on one of those hosts.

## 12.5 COOLDOWN identity

- Charges: 1–3.
- Recharge duration per charge: 0.5–30 seconds.
- Charges recharge serially.
- Spending a charge starts the recharge clock if it is not already running.
- Reaching one full charge immediately makes the Ability usable.
- Partial recharge progress is preserved.
- Fresh excursions begin at maximum charges.

## 12.6 ACTION identity

An Action-recharge host names exactly one metric:

- BASELINE_MELEE_HIT;
- WEAPON_HIT;
- KILL;
- DAMAGE_DEALT;
- DAMAGE_TAKEN;
- DISTANCE_MOVED;
- LAND;
- PARRY_SUCCESS;
- OVERCRIT.

The host defines a target and contribution:

| Metric | Legal target |
|---|---:|
| BASELINE_MELEE_HIT | 2–8 hits |
| WEAPON_HIT | 3–20 hits |
| KILL | 1–8 kills |
| DAMAGE_DEALT | 40–500 damage |
| DAMAGE_TAKEN | 20–200 damage |
| DISTANCE_MOVED | 10–100 metres |
| LAND | 2–12 landings |
| PARRY_SUCCESS | 1–5 successes |
| OVERCRIT | 1–8 overcrits |

Progress is factual, visible, and capped at the target. On Ability commit, progress becomes zero. Fresh excursions begin ready with progress at the target.

Passive damage Actors, hazards, and Status effects do not advance WEAPON_HIT. DAMAGE_DEALT counts resolved Health plus Barrier damage and excludes overkill.

Contribution rules:

- hit, kill, land, Parry, and overcrit metrics add exactly 1;
- DAMAGE_DEALT and DAMAGE_TAKEN add the resolved non-overkill amount;
- DISTANCE_MOVED adds horizontal player displacement caused by baseline locomotion or the equipped Mobility host;
- moving platforms, conveyors, wind, knockback, respawn, and teleports not produced by the equipped Mobility host add no movement progress;
- one multi-pellet attack adds at most one WEAPON_HIT per target;
- one attack_instance_id emits at most one OVERCRIT fact, using its highest resolved tier.

## 12.7 Controlled hybrids

Reliable Core supports five hybrid Mod templates:

- KILL_ADVANCES_COOLDOWN;
- MOVEMENT_ADVANCES_COOLDOWN;
- OVERCRIT_FILLS_RESOURCE;
- ACTION_DISCOUNTS_NEXT_COST;
- ACTION_PROGRESS_DECAYS.

Rules:

- one hybrid modifier per host;
- a host cannot advance itself from an event caused by that same activation;
- one event contributes to a given host at most once;
- one event may advance at most two hosts;
- contribution from a single event is capped at 25% of the target;
- hybrid contribution may supply at most 50% of one full recharge cycle;
- effects emit no reaction event until the next fixed tick;
- reaction processing stops after 32 effects in one frame and reports a validator fault.

## 12.8 Runtime persistence

Resource values, Cooldown charges/progress, and Action progress persist through Weapon switching, room changes, suspension, and save/load.

Death preserves the value at death. Active hold/channel state cancels.

Completing or abandoning an excursion discards its runtime readiness state. The next excursion begins fresh.

---

# 13. MOBILITY

## 13.1 Closed Mobility catalog

Reliable Core supports:

| Family | Default behavior | Hard capability |
|---|---|---|
| DASH | Add 9 m/s horizontally in aim direction, preserve greater existing speed | CROSS_LONG_GAP |
| AIR_DASH | Set horizontal speed to at least 11 m/s; one use until landing | CROSS_LONG_GAP |
| BURST_JUMP | Add 6 m/s upward and 4 m/s forward | CROSS_LONG_GAP |
| GRAPPLE | Pull/swing toward a tagged anchor within 25 m for up to 2.5 s | GRAPPLE |
| BLINK | Move to a validated point before a hit surface within 12 m | BLINK |

Hover, glide, wall kick, target-pull Grapple, flight, and free-space teleport are deferred as Mobility hosts.

Default recharge:

- DASH: one COOLDOWN charge, 2.0 seconds;
- AIR_DASH: one COOLDOWN charge, 2.5 seconds, and at most one use before landing;
- BURST_JUMP: one COOLDOWN charge, 4.0 seconds;
- GRAPPLE: one COOLDOWN charge, 1.0 second beginning on release;
- BLINK: one COOLDOWN charge, 4.0 seconds.

AIR_DASH becomes usable again only when both its Cooldown is complete and the player has landed since its prior use.

## 13.2 Common movement safety

All movement activations:

- use the same player capsule as baseline movement;
- preflight against current collision;
- never disable collision;
- never place the player inside geometry;
- cancel safely if the target becomes invalid before commit;
- report the capability family used;
- use authored room validation for mandatory routes.

## 13.3 Grapple

A valid anchor advertises GRAPPLE_ANCHOR.

On activation:

1. Ray/cone acquisition chooses the nearest valid anchor within 4° of aim, then distance, then ID.
2. A spring-damper force pulls the player toward the anchor.
3. Rope length begins at current distance and may shorten at 8 m/s while holding forward.
4. Tangential velocity is preserved.
5. Releasing Shift, losing line of sight for 0.25 seconds, exceeding 30 metres, death, or collision fault ends the Grapple.
6. The player may jump to release with an additional 2 m/s outward/upward impulse.

One grapple relation may exist. Grapple has a 1.0-second COOLDOWN after release.

## 13.4 Blink

Blink casts along aim to the first solid surface, steps back by player radius plus 0.10 metre, finds supported floor within 1.5 metres below, and capsule-tests the destination.

No hit, no floor, or blocked clearance means no commit and no spend.

Blink uses one COOLDOWN charge with a 4.0-second recharge by default.

## 13.5 Mandatory-route contracts

Mandatory capability routes use audited envelopes:

- CROSS_LONG_GAP: horizontal gap no greater than 5.0 metres at equal landing height or 4.0 metres at a landing up to 1.0 metre higher, with landing region radius at least 2.5 metres;
- GRAPPLE: anchor within 22 metres, unobstructed, with at least 4 metres of swing room and a valid release/landing region;
- BLINK: target surface and landing remain simultaneously visible, with a landing radius at least 1.5 metres.

Optional movement routes may use more demanding values but cannot contain the only AP Check or only progression exit unless their capability is guaranteed.

---

# 14. PHYSICS ECHOES

## 14.1 V1 primitives

Physics Abilities use exactly one primitive:

- PUSH;
- PULL;
- HOLD;
- ALIGN.

Only one Physics relation may be active.

TETHER, PIN, mass/drag alteration, constructed matter, arbitrary rotation, welding, and player self-launch are deferred.

## 14.2 Eligibility

Valid targets advertise one or more explicit tags:

- PHYSICS_LIGHT;
- PHYSICS_WEIGHTED;
- PHYSICS_COVER;
- PHYSICS_ALIGNABLE;
- PHYSICS_OPTIONAL_PUZZLE.

Invalid targets include:

- AP Check objects;
- fixed architecture;
- doors and moving machinery;
- socketed objects;
- currently carried objects;
- locked required components;
- bosses;
- untagged enemies;
- the player.

Physics is never the only mandatory puzzle solution in Reliable Core.

## 14.3 Primitive behavior

| Primitive | Behavior |
|---|---|
| PUSH | One impulse away from player, maximum 7 m/s added speed |
| PULL | One impulse toward a point 1.5 m before player, maximum 6 m/s added speed |
| HOLD | Spring-damper toward aim point, acquisition 20 m, hold distance 12 m, maximum speed 12 m/s |
| ALIGN | Rotate PHYSICS_ALIGNABLE object toward its nearest authored 15° snap increment at maximum 90°/s |

Every Physics host uses a private Resource pool of 100 with 15 units/s regeneration after a 1.0-second delay.

- PUSH costs 20.
- PULL costs 20.
- HOLD costs 12 units/s in 0.10-second samples.
- ALIGN costs 8 units/s in 0.10-second samples.

PUSH and PULL use PRESS. HOLD and ALIGN use HOLD.

If HOLD loses line of sight for 0.20 seconds, exceeds range, cannot pay, or encounters a safety fault, it releases.

ALIGN releases under the same conditions and also releases immediately after reaching a valid snap orientation.

## 14.4 Impact damage

A player-owned manipulated object may deal impact damage when:

- semantic mass is at least LIGHT;
- relative speed exceeds 6 m/s;
- it is not resting or constrained;
- that object-target pair has not damaged within 0.5 seconds.

Damage is:

    min(25, (relative_speed - 6) × semantic_weight × 3)

Impact damage:

- uses PHYSICS and ENVIRONMENTAL tags;
- cannot crit;
- receives no Weapon on-hit modifiers;
- credits the player for three seconds after their last manipulation;
- never damages from jitter below the threshold;
- cannot damage while carried or socketed.

LIGHTENED ordinary enemies may be PUSH or PULL targets, but never HOLD targets.

---

# 15. STATUS

## 15.1 Closed v1 catalog

Reliable Core has six enemy Status families:

| Status | Ordinary target effect | Boss substitute |
|---|---|---|
| BURNING | Seeks a nearby non-fire safe point and cannot use precision ranged attacks | AGITATED: attack windup +20% |
| SLOWED | Locomotion speed ×0.55 | Locomotion speed ×0.80 |
| LIGHTENED | Effective knockback response ×1.75 and permits PUSH/PULL Physics targeting | Knockback response ×1.20; never grants Physics targeting |
| SHOCKED | Next authored electronic/ranged action is canceled and consumes Status | Next such action is delayed 0.75 s |
| MARKED | Visible outline and +25 percentage points attacker crit chance against target | Same, capped by global crit ceiling |
| TURNCOAT | Faction changes to player ally for duration | CONFUSED: loses target and cannot reacquire for 1.5 s |

BURNING itself deals no damage. A spatial world-fire Actor may deal ordinary FIRE damage independently.

## 15.2 Application formula

Every attempt contains:

- status family;
- source host ID;
- base chance from 0.20 to 0.65;
- source potency from 0 to 0.20;
- duration;
- deterministic attempt ID.

Targets contain:

- family resistance from 0 to 0.35;
- current susceptibility from 0 to 0.30;
- current adaptation from 0 to 0.40;
- optional explicit immunity/substitute.

Default resistance is 0 for ordinary enemies, 0.15 for elites, and 0.30 for bosses. A family override may move that value within 0–0.35 and must be visible in enemy-authoring data.

For a nonimmune target:

    effective = clamp(base + potency + susceptibility - resistance - adaptation, 0.05, 0.95)

The deterministic roll uses Zone seed, attempt ID, target ID, and Status family.

## 15.3 Failure and success

On failure:

- show a resisted cue;
- add 0.10 susceptibility for that target/family, maximum 0.30;
- display one to three susceptibility pips near the target health presentation.

On success:

- reset susceptibility for that family to zero;
- apply or refresh the Status;
- add 0.20 adaptation, maximum 0.40.

Adaptation begins decaying three seconds after the Status ends at 0.05 per second.

The same Status refreshes duration but does not stack magnitude. Different Statuses coexist. Status durations are 1–8 seconds and bosses receive 50% of ordinary duration unless the substitute specifies a fixed duration.

If BURNING finds no reachable safe point, the enemy remains in place, plays its panic behavior, and still cannot use precision ranged attacks.

## 15.4 Immunity

True immunity is legal only when:

- the target lacks the required behavior or body;
- faction replacement would invalidate the encounter;
- movement alteration would break an authored immobile phase;
- the target is an inanimate mechanism not supporting that Status.

Where the table defines a boss substitute, the substitute is used instead of immunity.

All Statuses clear on death and ordinary enemy reconstruction. No Status schedules Health damage.

---

# 16. GEAR, MODS, AND RULES

## 16.1 Gear territories

Gear contains exactly one intrinsic plus its Mod slots.

Useful Gear uses one of the following intrinsic templates:

| Slot | Legal intrinsic templates |
|---|---|
| Head | target outline; threat direction; trajectory preview; Status susceptibility readout; +10–20 crit chance |
| Torso | 20–50 starting/maximum Barrier; 5–15% bounded damage reduction; +10–25% Resource regeneration; emergency Barrier |
| Arms | 10–25% reload speed; 10–25% Heat efficiency; +15–35% melee reach/impulse; +10–25% Physics range |
| Legs | 5–15% movement speed; 5–15% jump velocity; +10–25% air control; 10–25% Mobility recharge speed |

High-tier Gear contains exactly two distinct intrinsic templates from its own slot's row. Each uses the same legal numeric range as Useful Gear. It may not invent a new event or mechanic family.

Traversal modifiers may improve base movement but may not reduce it below the base movement law.

An intrinsic that affects Resource regeneration, Cooldown, Action progress, Weapon feed, or Mobility must name one compatible equipped target in the committed loadout. If no compatible target is equipped, that Gear cannot be committed.

Starting/maximum Barrier is granted once at the beginning of a fresh excursion and establishes that Gear's Barrier cap. It does not refill on death.

Emergency Barrier triggers when Health crosses from above 30 to 30 or below, grants 25–40 Barrier, and has a 30-second cooldown. It cannot trigger while the player is dead.

Informational Head effects are exact booleans:

- target outline shows the currently aimed damageable actor through obstruction for 1.5 seconds after line of sight;
- threat direction shows the direction of a hostile actor that damaged the player during the previous 3 seconds;
- trajectory preview shows the validated first impact of the selected LOB or PROJECTILE Weapon;
- Status susceptibility readout shows the target's three pity pips and adaptation ring.

## 16.2 Mod families

Reliable Core supports:

### AUGMENT

Changes one numeric field on its host.

- Maximum one AUGMENT per field.
- Ordinary range: ±10–25%.
- Damage, area, duration, charge count, and resource efficiency remain under the host-family budget.

### TRIGGER

Listens to one closed event and produces one closed effect after its own cooldown.

Legal events:

- BASELINE_MELEE_HIT;
- WEAPON_HIT;
- KILL;
- DAMAGE_TAKEN;
- PARRY_SUCCESS;
- OVERCRIT;
- STATUS_APPLIED;
- INTERACTION_COMPLETE;
- LAND;
- RESOURCE_FULL.

Legal effects:

- add Resource;
- advance Cooldown;
- add Action progress;
- grant temporary Barrier;
- apply one self stat pulse;
- emit one bounded impulse;
- attempt one Status against the triggering target.

TRIGGER cooldown is 0.5–30 seconds. One trigger produces one effect.

Effect bounds are:

- Resource: 5–25 units;
- Cooldown: 0.25–2.0 seconds;
- Action progress: one discrete count or 5–25 continuous units;
- Barrier: 5–25;
- stat pulse: 10–25% for 1–5 seconds;
- impulse: 1–6 m/s;
- Status attempt: base chance 0.20–0.50 and duration 1–5 seconds.

A Status trigger is legal only for an event that supplies one living enemy target.

### PASSIVE

Applies one continuous bounded stat modifier while its host is equipped.

Legal targets:

- damage dealt;
- damage taken;
- crit chance;
- movement speed;
- jump velocity;
- air control;
- knockback response;
- reload speed;
- Heat generation/cooling;
- Resource regeneration;
- Status potency.

PASSIVE uses a 10–25% change. Traversal changes are positive only. Damage-taken increase is capped at 25%, and damage-dealt reduction is capped at 25%.

### CONVERSION

Converts one factual contribution to another at a fixed bounded ratio.

Legal conversions:

- excess healing to Barrier at 50%, maximum 25 Barrier per heal;
- each overcrit tier to 5 Resource units;
- prevented BLOCK damage to Action progress at 50%, maximum 25% of its target per hit;
- each 10 metres of eligible movement to 1 second of Cooldown progress;
- Status failure to an additional 0.05 susceptibility, still subject to the 0.30 cap.

Maximum one CONVERSION per host.

### LINK

Creates one visible relationship between equipped hosts.

Reliable Core supports exactly:

- POOL_SHARE: two Resource hosts use one pool, with the lower maximum and lower regeneration of the pair;
- RESTORE_TARGET: RESOURCE_RESTORE names one other equipped pool;
- TRIGGER_TARGET: a Gear trigger names one equipped host or pool.

A LINK Mod stores semantic host IDs in the committed loadout, not inside the permanent Mod definition. Removing either endpoint disables the link and makes the loadout invalid until another endpoint is selected.

One Mod creates one link. No host participates in more than one POOL_SHARE.

REPLACEMENT Mods are deferred in Reliable Core.

## 16.3 Compatibility

- Weapon Mods install only on Weapon hosts. Global passive effects live on equipped Gear.
- Ability Mods install only on matching Ability families.
- Mobility Mods install only on Mobility.
- Gear Mods install only on their named Gear slot.
- A Physics Mod requires a PHYSICS_CAST host or Arms Gear.
- A Status Mod requires a host that produces a target hit/attempt.
- A feed Mod requires the matching feed type.
- A Resource Mod must name a pool present in the final equipped graph.

Installing a Mod runs validation against the complete active graph. Invalid combinations remain owned but cannot be installed.

## 16.4 Modifier order

For one numeric stat:

1. Start from authored base.
2. Sum additive flat changes.
3. Combine percentage modifiers additively around 1.0.
4. Apply the system cap.
5. Derive presentation.

Example: +20% and +15% produce ×1.35, not ×1.38.

No stat may have more than three active modifiers from Mods/Gear combined.

## 16.5 Runtime rule limits

- Maximum two TRIGGER Mods per host.
- Maximum sixteen active trigger listeners across the build.
- Minimum trigger cooldown: 0.5 seconds.
- Effects are queued for the next fixed tick.
- Effects do not synchronously emit another trigger.
- One factual event is consumed once by one listener ID.
- Maximum 32 resolved rule effects per frame.
- A validator rejects a directed cycle among Resource, Cooldown, and Action contributions.

If a runtime cap is nevertheless reached, remaining effects are dropped deterministically by descending semantic priority then lexical Mod ID, and developer diagnostics display the fault.

---

# 17. FOREIGN ITEMS, ARCHIVE, AND MIGRATION

## 17.1 New interpretation shape

One confirmed foreign receipt creates exactly one primary Archive piece:

| AP classification | Reliable Core interpretation |
|---|---|
| Filler | One Mod |
| Trap | One unequipped TRADEOFF Mod with one bounded upside and downside |
| Useful | One Useful Weapon, Ability, Mobility, or Gear host |
| Progression | One high-tier host; never automatic Archipepsi capability truth |

Epsilon may choose the category only from those allowed for the AP classification.

New v1 interpretations use CREATE only. Cross-item UPGRADE, MODIFY, MERGE, and LINK operations are not generated. Mechanical relationships are visible equipped Mods.

This preserves provenance while dramatically reducing order-dependent campaign mutation.

## 17.2 Trap Mods

A TRADEOFF Mod:

- is never automatically installed;
- states its upside and downside in one sentence;
- keeps both effects on the same host;
- cannot reduce traversal below base;
- cannot remove Static Pulse, interaction, melee, or required capabilities;
- cannot increase damage taken above ×1.33;
- cannot reduce damage dealt below ×0.75;
- cannot disable an input.

## 17.3 Archive behavior

The Archive shows:

- source item/game/player/location;
- interpreted type and quality;
- mechanic summary;
- compatibility;
- installed location, if any;
- duplicate count;
- validation/migration warning.

Search and filters include host kind, Gear slot, Status, capability, feed, recharge identity, quality, source game, and compatibility with the currently selected host.

## 17.4 Existing-save migration

The old append-only interpretation log remains immutable evidence. Migration produces new Archive projections without rewriting historical receipts.

Mapping rules:

1. Old ranged Actions become Weapon candidates.
2. Old movement Actions become Mobility candidates.
3. Old defensive, utility, and special-melee Actions become Ability candidates.
4. An old Trait, Resource, Rule, Status, or Info component becomes a compatible Mod.
5. If it originated in the same interpretation as an Action, that Action is its preferred host.
6. Otherwise it becomes an uninstalled standalone Mod.
7. Old Affordance components become Archive metadata only; they never globally alter generation.
8. Illegal old Status DoT behavior is removed. The provenance remains and the component is replaced by the nearest legal Status or a quarantined cosmetic record.
9. Old slotted Actions are proposed in the corresponding new slots but are not committed until the player confirms at the Hub.
10. No migrated piece is silently deleted.

The first migrated load opens a review screen listing every conversion and quarantine.

---

# 18. FORGE AND NATIVE CURRENCIES

## 18.1 Forge

Forge is explicitly deferred from Reliable Core v1.

No screen, generated Zone, capability proof, or progression path may require Forge.

Archive data retains enough provenance for a later Forge version, but v1 does not spend or consume owned interpretations.

## 18.2 Epsilon Static

Epsilon Static is banked as a persistent campaign count.

In Reliable Core v1:

- it is displayed in the Hub;
- it affects the existing bounded Epsilon glitch presentation up to 18 visible units;
- it is not spent;
- it does not alter combat;
- it does not grant capability;
- it does not change generation;
- it is reserved for the future Forge/Integrity authority.

This is intentionally modest. It avoids inventing a permanent economy merely to make a filler number move.

## 18.3 Epsilon Coins and Signal Keys

Existing Coin, shop, Signal Key, campaign tier, and AP behavior remain outside this proposal and unchanged.

---

# 19. SIGNAL GRAPH

## 19.1 Port types

Reliable Core signal ports use exactly:

- BOOL: OFF or ON;
- PULSE: one immutable event;
- VALUE: integer 0–7.

Continuous analog signals are deferred.

Connections require identical types except through an explicit converter node.

## 19.2 Foundational nodes

Supported general nodes:

- DIRECT;
- AND;
- OR;
- NOT;
- PULSE_TO_TIMER;
- LATCH;
- SELECTOR;
- SEQUENCE.

COUNTER, ROUTER, DELAY, and THRESHOLD exist only as private implementation inside a validated package. Epsilon cannot place them directly.

## 19.3 Boolean behavior

- DIRECT outputs its BOOL input.
- AND outputs ON only when every input is ON.
- OR outputs ON when any input is ON.
- NOT outputs the inverse of one input.
- A node recomputes only when an input changes.

## 19.4 Pulse behavior

A PULSE contains:

- source node ID;
- excursion-local monotonic pulse sequence;
- fixed-tick timestamp.

A pulse is delivered once per edge and is not persisted.

PULSE_TO_TIMER converts a pulse to ON for its authored duration, then OFF. A new pulse restarts the duration from full.

LATCH declares mode SET_RESET or TOGGLE. SET_RESET accepts SET and RESET pulses; if both arrive in the same tick, RESET wins. TOGGLE accepts one TOGGLE pulse per tick. Multiple identical pulses in one tick count once.

## 19.5 VALUE behavior

VALUE carries an integer 0–7.

SELECTOR stores one value within its declared minimum/maximum. NEXT and PREVIOUS pulses wrap only if the package declares WRAP; otherwise they clamp. RESET restores the authored initial value.

An actuator may read VALUE only when its contract explicitly supports indexed positions.

## 19.6 Sequence behavior

SEQUENCE stores an expected ordered list of two to six input IDs.

- Correct next pulse advances by one.
- Incorrect pulse emits FAILURE and resets progress to zero.
- Completion emits one SUCCESS pulse and either resets or latches according to package definition.
- Progress is visible.

## 19.7 Evaluation order

1. Sensors sample during the fixed physics tick.
2. Changed inputs enqueue events.
3. Nodes process in topological order, with lexical node ID as tie-break.
4. Actuator commands apply after graph evaluation in the same fixed tick.
5. Presentation observes the committed result.

General signal graphs must be acyclic. LATCH and TIMER own their internal memory and do not create graph cycles.

Limits:

- maximum 64 nodes per room;
- maximum 128 edges per room;
- maximum 32 graph hops;
- maximum 256 edge deliveries per fixed tick.

Exceeding a structural limit fails validation. Runtime does not guess which edge to ignore.

## 19.8 Latency and presentation

Logic propagates in the same fixed tick. Timed behavior is represented by PULSE_TO_TIMER rather than delayed conduit propagation.

A visible conduit pulse may animate over 0.15–0.60 seconds, but that delay is always cosmetic in Reliable Core.

## 19.9 Persistence and reset

- DIRECT/AND/OR/NOT have no saved state.
- PULSE is ephemeral.
- TIMER is ephemeral and resets on death, room unload, and puzzle reset.
- LATCH, SELECTOR, and SEQUENCE follow their package persistence category.
- Reset returns nodes to authored initial state and clears queued pulses.

---

# 20. INPUTS AND SENSORS

## 20.1 Pressure plate

A plate defines:

- accepted semantic object classes;
- threshold from 0.5 to 4.0;
- optional player/enemy acceptance;
- signal node ID.

Qualifying semantic weight is summed while actors are stably overlapping.

- Player: 1.0.
- Ordinary enemy: 1.0 unless authored otherwise.
- LIGHT/COMPONENT: 0.5.
- WEIGHTED: 2.0.
- COVER: 3.0.
- HEAVY: 4.0.
- Debris and carried objects: 0.

Hysteresis is 0.10 semantic weight, and an overlap must persist for two fixed ticks before changing state.

## 20.2 Pulse button

F emits one PULSE. It has a 0.25-second input lockout and cannot queue repeated pulses while its press animation is active.

## 20.3 Timed button

F starts or restarts an ON duration of 3–30 seconds. It presents remaining time through a segmented light band and cadence cue.

## 20.4 Lever

F toggles a persistent BOOL after a 0.25-second commit animation. It cannot be activated again until the animation completes.

## 20.5 Shootable target

A target defines accepted hit tags.

Mandatory targets accept RANGED from Static Pulse. They:

- ignore invalid hits;
- show an invalid-impact cue;
- emit PULSE or toggle one internal latch;
- have a 0.20-second repeat lockout;
- remain legible at 40 metres.

## 20.6 Object socket

A socket exposes:

- accepted object class and optional exact semantic key;
- removable or LOCK_ON_COMPLETE behavior;
- BOOL output while occupied or latched;
- rejection cue for incompatible objects.

## 20.7 Proximity sensor

Detects PLAYER, ENEMY, or an explicit object class in one authored volume. State changes use the same two-tick stability rule as plates.

## 20.8 Encounter-clear sensor

Observes a named encounter group. It emits one PULSE when every required member is dead, permanently despawned, or below the enemy fall-kill boundary.

Respawned encounter members restore the sensor only if the package has not latched completion.

## 20.9 Deferred sensors

Trip beams, arbitrary state observers, sound sensors, light sensors, water-level sensors, and physics-contact scripting are absent from Reliable Core.

---

# 21. ACTUATORS AND MACHINERY

## 21.1 Common actuator contract

Every actuator declares:

- semantic actuator ID;
- accepted signal type;
- initial state;
- target states;
- transition duration or speed;
- obstruction policy;
- reset group;
- persistence category;
- presentation state;
- safe recovery behavior.

Simulation state changes first. Animation, audio, VFX, and conduit presentation report committed state.

## 21.2 Door, gate, and shutter

States are CLOSED, OPENING, OPEN, CLOSING, and BLOCKED.

- Default travel speed: 2.5 m/s.
- ON requests OPEN; OFF requests CLOSED.
- A non-hazard door sweeps its closing volume.
- If the player or a required object blocks closure, the door enters BLOCKED for 0.15 seconds and then reopens.
- It retries closure only after the blocker leaves.
- A door may never trap the player between itself and solid geometry.
- A hazard door uses the HAZARD_MOVING_WALL contract and must be labeled as such.

## 21.3 Bridge and moving platform

Bridges and platforms move between two authored transforms or along one authored path.

- Default translation speed: 3.0 m/s.
- Default angular speed: 60°/s.
- Motion is kinematic and fixed-timestep.
- Player and loose objects inherit platform velocity while in stable contact.
- A required object cannot be crushed against an endpoint.
- Power loss finishes the current 0.10-second safety step, then pauses.
- Reset moves to the initial state only after its swept path is clear.

## 21.4 Lift

A lift supports two to four authored stops.

- VALUE selects a stop.
- A pulse call requests one stop.
- Requests are served in received order, with duplicate destinations collapsed.
- Doors interlock with movement.
- Loss of power stops at the next safe stop rather than between floors.
- Every required lift route has an alternate recovery path or recall control.

## 21.5 Path machine

Crane, rotating arm, sliding wall, turntable, and similar machines use one PATH_MACHINE contract:

- two to four authored indexed poses;
- kinematic path authored by the shell/package;
- VALUE or BOOL selects pose;
- optional cargo socket;
- swept-volume validation;
- no freeform player steering;
- no dynamic rope or joint.

A crane load is attached through a semantic socket and follows the authored path. It becomes a loose object only at a declared release pose.

## 21.6 Rail switch

A rail switch selects one of two validated branches.

- It may switch only when no rider occupies the junction exclusion region.
- If requested while occupied, the request is queued.
- Both branches must independently pass the rail audit.
- Presentation shows physical point orientation, not color alone.

## 21.7 LaunchPad and bounce pad

Existing LaunchSolver and authored source/landing contracts remain.

- LaunchPad default accepts PLAYER only.
- An object-launch package may add LIGHT or WEIGHTED explicitly.
- A powered pad fires only while ON.
- Bounce pad applies its authored vertical impulse on contact and has a 0.20-second per-actor lockout.

## 21.8 Hazard controller

The controller changes ENABLED/DISABLED state on a separate hazard actor. The hazard owns collision, telegraph, phase, and damage.

Disabling a hazard immediately stops new damage but does not erase already committed projectiles or explosions.

## 21.9 Light controller

Light controllers may alter illumination and show signal state. Light is presentation and navigation only in Reliable Core. It cannot be the sole mechanical input.

---

# 22. HACKING

Reliable Core implements one reusable minigame: ROUTE_MATCH.

## 22.1 Entry and controls

F on a hack terminal opens a modal panel and freezes player movement and combat.

Mandatory terminals are placed outside an active encounter and outside every enabled hazard volume. Taking damage cancels the panel immediately and changes no terminal or signal state.

- W/S or mouse selects one of three rows.
- A/D or mouse cycles the selected row among three symbols.
- F or UI CONFIRM submits.
- Esc or UI CANCEL exits.

Bindings use menu semantic actions, not hardcoded keys.

## 22.2 Puzzle

- Three rows each display one of three conduit symbols.
- A target symbol is shown for every row.
- Initial positions are deterministic from Zone seed and terminal ID.
- At least two rows begin incorrect.
- No timer is used for mandatory hacks.
- Submission succeeds only when all three match.
- Wrong submission flashes the incorrect rows and leaves the current choices unchanged.
- Cancel changes no room state.

Success emits one SUCCESS pulse. A package may latch it or use it to change a SELECTOR.

The same terminal cannot award an AP Check directly.

---

# 23. PUZZLE-PACKAGE CONTRACT

## 23.1 Required manifest

Every puzzle instance contains:

- puzzle_id;
- family;
- room_id;
- package version;
- purpose;
- named room offers consumed;
- object definitions;
- input/sensor definitions;
- closed signal graph;
- actuator definitions;
- initial state;
- completion condition;
- failure condition;
- reset_group_id;
- persistence category;
- capability requirements;
- AP Check IDs gated, if any;
- local rewards, if any;
- declared alternate solutions;
- timing contract, if any;
- audit expectations;
- deterministic presentation variant.

No package contains raw script, scene paths, or physical coordinates supplied by Epsilon.

## 23.2 Room offers

Packages may consume only named, physically authored offers:

- INTERACTION_POINT;
- CARRYABLE_SPAWN;
- CARRY_PATH;
- SOCKET_POINT;
- PLATE_POINT;
- TARGET_POINT;
- CONDUIT_ROUTE;
- MACHINE_ENVELOPE;
- MACHINE_POSE;
- PLATFORM_PATH;
- RAIL_ROUTE;
- LAUNCH_SOURCE;
- LAUNCH_TARGET;
- GRAPPLE_POINT;
- HAZARD_LANE;
- COVER_POINT;
- BOMBABLE_SURFACE;
- KEY_BRANCH;
- RETURN_ROUTE;
- SECRET_POINT;
- RESET_POINT;
- REWARD_POINT;
- EXIT_POINT.

An offer may be consumed by only one required role unless it explicitly declares SHAREABLE.

## 23.3 Completion and AP behavior

Puzzle completion is local semantic truth.

If it gates an AP Check, completion enables or reveals a separate AP Check interaction. The Check is not sent until the player focuses that Check and presses F.

One puzzle may gate up to one AP Check in small/medium rooms and up to two distinct Checks in large rooms. Each Check has its own acquisition interaction.

## 23.4 Reset requirements

Every incomplete required package must support immediate retry through:

- automatic reset after failure; or
- a visible RESET_POINT reachable from every failure state.

Reset:

- affects only its reset group;
- clears ephemeral signals/projectiles;
- reconstructs required objects;
- restores actuator initial state safely;
- never reverses confirmed AP truth, permanent shortcuts, or Zone flags.

An optional RESET_FIELD is a visible volume attached to one reset group. Crossing it:

- is harmless to the player;
- dissolves loose required carryables and respawns them at their semantic spawn;
- clears player-owned temporary projectiles and Ability fields tagged for that group;
- releases active Physics HOLD/ALIGN relations;
- does not reset a completed package unless its manifest declares REPEATABLE;
- never alters AP, ROOM_PERSISTENT, or ZONE_PERSISTENT truth.

## 23.5 Validation pipeline

Validation occurs in this order:

1. Schema and closed-vocabulary validation in Python.
2. Capability and AP-allocation validation in Python.
3. Offer existence and unique-consumption validation.
4. Signal graph type, limit, and acyclicity validation.
5. Initial and completion-state topology validation.
6. Godot physical placement and collision audit.
7. Carry path, interaction clearance, and object recovery audit.
8. Timed-path traversal audit.
9. Machine swept-volume audit.
10. Reset simulation.
11. Save/reload reconstruction simulation.

## 23.6 Deterministic failure handling

For one selected package:

1. Try its first deterministic offer assignment.
2. Try up to two additional deterministic assignments.
3. If none pass, reject the package before the Zone is committed.
4. The composer may choose the next legal package from its pre-shuffled candidate list.
5. If no candidate passes, use a verified base-solvable PULSE_REMOTE or SHOOT_TARGET package when the room has compatible offers.
6. If even that is impossible, reject the entire generated Zone and invoke the existing deterministic fallback Zone builder.

The saved Zone records every declined package and reason. Runtime never replaces a broken visible puzzle with a different one.

---

# 24. INITIAL PUZZLE FAMILIES

Reliable Core ships eighteen package families. ENERGY_ROUTE and BEAM_RECEIVER are rejected by the v1 schema and deferred.

## 24.1 CARRY_TO_PLATE

**Offers:** one CARRYABLE_SPAWN, one CARRY_PATH, one PLATE_POINT, one output.

**State:** weighted object on accepted plate produces ON. Output follows ON.

**Safety:** carried objects have zero plate weight. Required object respawns. If the output is a passage, the far side must contain a non-resetting return route or safe door policy.

**Completion:** reaching the package goal while the plate is ON. Completion may latch a shortcut but does not consume the object.

## 24.2 INSERT_COMPONENT

**Offers:** COMPONENT spawn, CARRY_PATH, SOCKET_POINT, output.

**State:** compatible insertion produces ON.

**Completion:** insertion. Progression versions use LOCK_ON_COMPLETE. Optional versions may remain removable.

**Recovery:** component respawns if lost or destroyed before locking.

## 24.3 PULSE_REMOTE

**Offers:** INTERACTION_POINT, CONDUIT_ROUTE, output.

**State:** button PULSE sets a LATCH that activates output.

**Completion:** latch set. Reset exists only for optional repeatable machinery; progression completion persists for the excursion.

## 24.4 TIMED_TRAVERSE

**Offers:** INTERACTION_POINT, temporary output/path, goal sensor, reset point.

**State:** activation starts TIMER; goal reached while ON emits SUCCESS and latches a return route.

**Timing:** minimum allowed time is:

    ceil(path_length / 5.6 + required_interactions × 0.5 + 2.0)

The 5.6 m/s planning speed is 80% of baseline walk speed.

**Failure:** timer expiry resets immediately. No death is required to retry.

## 24.5 SHOOT_TARGET

**Offers:** TARGET_POINT visible within 40 metres, CONDUIT_ROUTE, output.

**State:** valid RANGED hit emits PULSE and sets completion LATCH.

**Safety:** Static Pulse must have unobstructed line of sight unless a guaranteed capability is declared.

## 24.6 TOGGLE_ROOM_STATE

**Offers:** lever, two safe architecture states, goal.

**State:** lever toggles A/B room-local state.

**Validation:** both complete transforms are physically safe. The player can always reach the lever or a reset. The package solution needs at most four toggles.

**Completion:** reaching the goal in the target state.

## 24.7 HACK_OVERRIDE

**Offers:** terminal, conduit, output or selector.

**State:** ROUTE_MATCH success emits PULSE. It either sets a latch or changes one declared selector.

**Failure:** wrong submission changes no signal truth. Cancel is always safe.

## 24.8 DUAL_INPUT

**Offers:** two independent inputs, one output.

**State:** AND activates output.

**Validation:** solo play must be possible. Inputs must be maintainable by two objects, one object plus player with a reachable route, or one latched input plus one live input.

**Completion:** both true simultaneously; progression output then latches.

## 24.9 ALTERNATE_INPUT

**Offers:** two distinct solutions and one output.

**State:** OR from either input completes the package.

**Validation:** both declared paths must work independently. The package records which path completed for diagnostics only.

## 24.10 ROUTE_SWITCH

**Offers:** one selector/lever, one rail/conveyor/path junction, two valid destinations.

**State:** selector chooses branch A or B.

**Validation:** both branches are physically audited. The switch cannot move under an occupying rider/object.

**Completion:** required cargo/player reaches the target branch destination.

## 24.11 MOVING_MACHINE

**Offers:** input, MACHINE_ENVELOPE, two MACHINE_POSE offers, goal.

**State:** input moves one PATH_MACHINE between A and B.

**Validation:** swept space, endpoint support, player escape, and required-object safety pass.

**Completion:** machine reaches the target pose and exposes the goal.

## 24.12 BOMB_BARRIER

**Offers:** bomb dispenser, carry path, BOMBABLE_SURFACE, safe retreat space.

**State:** F picks up an unarmed bomb. Placing it on the tagged surface arms a 2.5-second fuse. Explosion destroys only that target.

**Damage:** 40 EXPLOSIVE damage in a 4.5-metre radius with line-of-sight blocking.

**Recovery:** dispenser provides one replacement two seconds after explosion or loss until completion.

## 24.13 ENCOUNTER_GATE

**Offers:** authored encounter, gate/output.

**State:** ENCOUNTER_CLEAR emits PULSE and permanently opens the gate for the excursion.

**Safety:** enemies outside valid bounds count as dead. No hidden reinforcement may remain outside the encounter group.

## 24.14 OBSERVATION_TARGET

**Offers:** one readable clue sightline and three or four labeled targets/controls.

**State:** the clue identifies one correct target or a sequence of at most four.

**Failure:** incorrect input gives a visible/audio error and resets sequence progress.

**Accessibility:** symbols differ by shape and pattern, never color alone.

## 24.15 A_B_STATE

**Offers:** one lever and two groups of linked architecture.

**State:** A elements active while B elements inactive, then inverse.

**Validation:** every complete state is safe; transition sweeps are safe; solution needs at most four toggles; reset remains reachable.

**Scope:** room-local only. Cross-room reversible A/B is deferred.

## 24.16 LOCAL_KEY_LOOP

**Offers:** KEY_BRANCH, local key pickup, RETURN_ROUTE, local lock.

**State:** F on the key stores a Zone-local token in a three-slot keyring. The key is not physically carried and cannot be dropped.

**Lock:** matching key is consumed to permanently open its local gate.

**Validation:** the key branch and return route are reachable before the lock. Local keys never become AP items.

## 24.17 MULTI_STAGE_MACHINE

**Offers:** sufficient offers for two or three child packages in one room.

**State:** stages complete strictly in order. A completed stage latches and cannot be reset by a later-stage failure.

**Limits:** maximum three stages, maximum one required object per stage, maximum one timed stage, no cross-room dependency.

## 24.18 DUNGEON_STATE_CHANGE

**Offers:** one control package and named dependent presentation/output offers in later rooms.

**State:** completion sets one forward-only Zone flag from false to true.

**Limits:** no flag can return to false; no package can require a flag set in a later room; maximum four Zone flags.

**Validation:** all dependencies form a forward DAG by mandatory-spine room index.

## 24.19 Deferred package families

ENERGY_ROUTE and BEAM_RECEIVER are not generated in Reliable Core.

Sequence/memory puzzles are authored variants of OBSERVATION_TARGET. Control panels are SELECTOR or HACK_OVERRIDE presentations. Reset fields are infrastructure, not an independent puzzle family.

---

# 25. HAZARDS AND DESTRUCTION

## 25.0 Material traits

Reliable Core supports exactly these gameplay material traits:

- WORLD_SOLID;
- TRANSPARENT_SOLID;
- BREAKABLE;
- MELEE_BREAKABLE;
- DESTRUCTIBLE_COVER;
- BOMBABLE;
- PROJECTILE_BLOCKER;
- GRAPPLE_ANCHOR.

Object mass/carry/Physics classes are semantic object traits rather than surface materials.

Conductive, insulating, reflective, slippery, sticky, buoyant, magnetic, heat-sensitive, cold-sensitive, penetrable, and signal-blocking materials are absent in v1.

## 25.1 Hazard contract

Every hazard declares:

- hazard_id;
- damage request template;
- accepted actor classes;
- ENABLED/DISABLED state;
- phase timing;
- telegraph duration;
- per-actor hit lockout;
- controller node;
- reset behavior;
- safe initial state.

Required traversal never begins with an unavoidable active hit.

## 25.2 V1 hazard families

| Family | Default damage | Telegraph | Hit behavior |
|---|---:|---:|---|
| FLAME_JET | 10 FIRE/Hazard | 0.75 s ignition | 0.50 s per-actor lockout |
| ELECTRIC_FLOOR | 12 Hazard | 0.75 s pulse | One hit per active pulse |
| LASER_LINE | 15 Beam/Hazard | Always visible; 0.50 s warmup | 0.50 s lockout |
| CRUSHER | 25 Hazard | 0.75 s motion cue | One hit per closing stroke |
| ROTATING_ARM | 18 Physics/Hazard | Continuous visible motion | 0.75 s lockout |

Hazard damage uses the common damage road and cannot crit.

Each package explicitly says whether the hazard affects PLAYER, ENEMY, or both. A hazard that can be used as a tool defaults to both.

## 25.3 Destructible classes

### BREAKABLE_CRATE

- 15 Health;
- accepts ordinary combat damage;
- no required progression inside unless represented by a separate visible interaction;
- may reveal a local reward, target, or route.

### DESTRUCTIBLE_COVER

- 40 Health;
- INTACT and BROKEN collision states;
- changes line of sight only through authored cover geometry;
- broken state persists for the current encounter or package.

### REACTIVE_BARREL

- 12 Health;
- explosion delay: 0.20 seconds after lethal hit;
- radius: 4.0 metres;
- center damage: 30, linear falloff to 0;
- impulse affects LIGHT and WEIGHTED loose objects;
- chain reactions delay each new barrel by at least 0.15 seconds;
- player receives 50% damage from their own credited barrel.

### RECOVERABLE_BOMB

- unarmed while carried;
- arms only through package placement or explicit hit;
- fuse: 2.5 seconds;
- radius: 4.5 metres;
- center damage: 40;
- replacement behavior defined by BOMB_BARRIER.

### BOMBABLE_SURFACE

- ignores ordinary damage;
- responds only to a valid recoverable-bomb explosion or explicit BOMBABLE attack template;
- swaps once to its authored destroyed geometry;
- arbitrary structural walls remain unaffected.

Physics-driven structural collapse and persistent debris are deferred. A falling support event uses an authored animation/collider transition, not loose simulated rubble.

## 25.4 Environmental kill credit

An environmental source credits the last player who:

- pushed the enemy or object;
- activated the controlling mechanism;
- damaged the reactive object;
- changed the hazard state;

within the prior five seconds.

Credit changes rewards and trigger facts, not AP truth.

## 25.5 Enemy participation

Reliable Core enemies may:

- count for encounter-clear;
- stand on plates when the plate explicitly accepts ENEMY;
- be struck by hazards;
- ride conveyors and moving platforms;
- block trip-free physical paths;
- destroy ordinary cover.

Enemies do not:

- carry required keys/components;
- operate terminals;
- intentionally solve puzzles;
- alter Zone flags;
- permanently occupy a required plate after encounter reset.

---

# 26. ROUTING, FORCES, AND CONSTRAINTS

## 26.1 Power

Power is represented by BOOL signals, visible conduits, local cells, and generator latches.

There is no voltage, current, conductivity, wire damage, or automatic water interaction.

## 26.2 Wind

A wind volume declares accepted classes and a constant direction/strength.

Defaults:

- player: acceleration up to 8 m/s²;
- LIGHT object: up to 12 m/s²;
- WEIGHTED object: no effect;
- COVER/HEAVY: no effect;
- projectile: optional authored drift, maximum 4 m/s²;
- Status/fire/smoke: no effect because those simulations are absent.

Wind contribution is summed then capped at 12 m/s². A mandatory player route is audited against its weakest allowed wind state.

## 26.3 Conveyors and cargo

Conveyors apply surface velocity up to 5 m/s to player and loose LIGHT/WEIGHTED objects.

Cargo routing uses:

- authored conveyor paths;
- two-way diverters;
- chutes;
- lift cargo sockets;
- crane cargo sockets.

Required cargo cannot leave its allowed route without triggering recovery.

## 26.4 Player rails

Existing curved rail and RailRider contracts remain.

- Rails transport the player, not loose physics objects.
- Jump exits at any point.
- Branch switches use audited junctions.
- Powered rails visibly distinguish enabled and disabled state.
- A mandatory rail path must have a valid entry, continuous audited curve, and supported exit.

Cargo rails are separate PATH_MACHINE actors.

## 26.5 Constraints

Reliable Core supports only authored kinematic constraints:

- hinge between named angles;
- slider between named endpoints;
- turntable between indexed poses;
- trolley on authored path;
- crane cargo socket.

Dynamic rope, pulley, chain, seesaw, pendulum, free joint, and counterweight simulation is deferred.

## 26.6 Deferred routed phenomena

Energy balls and environmental beams have no v1 runtime class. Their receiver, reflector, splitter, and blocker tags are rejected by schema rather than accepted inertly.

---

# 27. WATER, LIGHT, SOUND, AND OTHER MEDIA

## 27.1 Water

Reliable Core permits decorative water and shallow authored puddle/basin surfaces no deeper than 0.5 metre.

They:

- do not change movement;
- do not provide buoyancy;
- do not conduct electricity;
- do not create oxygen state;
- cannot rise or drain;
- cannot be a required gameplay route.

The existing water-like movement modifier volume is migrated to a generic FORCE_VOLUME or disabled. It must not be presented as full water.

Swimming, oxygen, drowning, currents, buoyancy, pumps, valves, fill/drain, and persistent water level require a later Water Authority.

## 27.2 Light

Light communicates navigation, power, hazards, and clues. It is not a mechanical sensor input.

A required clue remains perceivable under minimum supported brightness and has a non-light identifier such as shape, motion, or signage.

## 27.3 Sound

Sound communicates:

- machinery start/stop;
- countdown cadence;
- signal pulse;
- hazard warning;
- interaction success/failure;
- distant output activation.

Any required sound cue has a visual equivalent. Sound never directly activates a signal node in v1.

## 27.4 Deferred media

Smoke, steam, gas, vacuum, pressure, heat/cold fields, acid, lava-like liquids, advanced gravity, magnetism, and phase-space have no v1 gameplay contracts.

Fire exists only as:

- BURNING Status presentation with no damage; or
- a spatial FIRE Actor that issues ordinary damage requests.

---

# 28. ROOM AND ZONE TOPOLOGY

## 28.1 Room-local transformations

A room may persistently:

- open a shortcut;
- lower a ladder/stair;
- extend a bridge;
- destroy a bombable barrier;
- repair/start a generator;
- change a rail branch;
- move one machine to a completed pose;
- reveal a secret or AP Check.

A transformation records a semantic state ID, never arbitrary transforms.

## 28.2 One-way connections

Allowed one-way topology:

- drop to a validated recovery route;
- far-side unlock;
- permanent shortcut gate;
- deployed bridge/ladder;
- encounter lock-in with a valid post-combat exit.

The validator proves the player can never remove the only remaining progression path.

## 28.3 Zone flags

A Zone contains at most four boolean flags.

Rules:

1. Initial value is false.
2. A flag changes only false to true.
3. Only DUNGEON_STATE_CHANGE or an authored boss event sets it.
4. A room may read flags set only by an earlier mandatory-spine room.
5. A flag is ZONE_PERSISTENT.
6. A flag never resets on death, room unload, or puzzle reset.
7. A flag cannot directly award an AP Check.

Examples include WING_POWERED, SECURITY_DISABLED, CRANE_ONLINE, and SHORTCUT_NETWORK_OPEN.

## 28.4 Cross-room outputs

Rooms do not send arbitrary runtime signals to unloaded rooms.

An unloaded room derives its initial local state from:

- its saved ROOM_PERSISTENT state;
- current Zone flags;
- AP truth;
- immutable Zone manifest.

This makes cross-room behavior reconstructible without keeping a dungeon-wide live signal graph.

## 28.5 Local keys

Local keys:

- exist only inside one Zone;
- use explicit key IDs;
- occupy a three-slot keyring;
- are collected through F;
- are consumed only by the matching lock;
- persist through death, suspension, save/load, and room unload;
- disappear when the Zone is completed or abandoned;
- never represent AP items.

The generator cannot place more simultaneously held required keys than keyring capacity.

## 28.6 Secrets and local rewards

Secrets may award:

- Health restoration;
- temporary Barrier;
- a local environmental advantage;
- a shortcut;
- lore/archive text;
- cosmetic presentation;
- an explicit AP Check.

Random crates never award AP truth.

Health pickups restore 25 Health and are consumed for the excursion. Barrier pickups grant 25 Barrier. Neither respawns on death.

---

# 29. CAPABILITY PROGRESSION

## 29.1 Closed v1 capability list

Reliable Core progression recognizes exactly:

- RANGED_HIT;
- GRAPPLE;
- BLINK;
- CROSS_LONG_GAP.

RANGED_HIT is permanently guaranteed by Static Pulse.

GRAPPLE, BLINK, and CROSS_LONG_GAP are satisfied only by an equipped Mobility host advertising that exact capability.

Physics, Status, Gear, damage, crit, hacking, carrying, bombs, rails, and ordinary machinery are not randomized hard capabilities in Reliable Core.

## 29.2 Generator proof

A generated required route or AP Check may name a capability only when:

1. the campaign owns at least one non-quarantined expression before Zone generation;
2. that expression can legally occupy the required slot;
3. the Zone entry screen can validate it;
4. the room package and physical offer pass that capability's audit.

Epsilon chooses only from the proven list included in its request.

## 29.3 Entry validation

Before entering a Zone, the screen shows:

- required capabilities;
- which equipped host satisfies each;
- any missing requirement.

If a requirement is missing, ENTER is disabled and EDIT LOADOUT is focused.

Reliable Core does not auto-equip, borrow, or locally grant a missing randomized capability.

## 29.4 Optional routes

An optional route may use a capability the player currently has, but an AP Check behind that route still counts as a requirement and must obey the guarantee.

Physics tricks, recoil, hazard timing, and geometry may bypass optional non-AP obstacles. Semantic AP gates and required exits remain protected by their explicit conditions.

## 29.5 Deferred guarantee sources

Zone-established capability, Forge construction, temporary loaner Echoes, and in-Zone loadout stations are deferred. The planner cannot cite them in v1.

---

# 30. PROCEDURAL COMPOSITION

## 30.1 What Epsilon chooses

For every chamber, Epsilon may choose:

- purpose from the closed purpose list;
- shell ID from the supplied compatible shell catalog;
- zero to two package-family IDs from a supplied legal set;
- named offers from that shell;
- bounded difficulty parameters;
- presentation variants;
- optional declared capability from the proven list.

Epsilon never chooses metres, transforms, arbitrary paths, node graphs, or completion logic.

## 30.2 Package density

| Room size | Required packages | Optional packages | Maximum total |
|---|---:|---:|---:|
| Small | 0–1 | 0 | 1 |
| Medium | 0–1 | 0–1 | 2 |
| Large | 1 | 0–1 | 2 |

MULTI_STAGE_MACHINE counts as two packages for density and budget.

One room may contain up to three AP Checks only when each has a distinct acquisition condition and the shell has distinct REWARD_POINT offers.

## 30.3 Room purposes

Every room has one primary purpose and at most one secondary purpose.

The composer selects purpose before packages. Legal Reliable Core primary purposes are:

- traversal;
- arena;
- ranged arena;
- close arena;
- ambush;
- holdout;
- gauntlet;
- environmental puzzle;
- physical puzzle;
- logic puzzle;
- observation puzzle;
- timing challenge;
- exploration;
- secret;
- reward;
- junction;
- shortcut;
- ascent;
- descent;
- safe/recovery;
- spectacle transition;
- dungeon-state control.

Hybrid is represented by primary plus secondary rather than a freeform purpose.

## 30.4 Zone shape

Reliable Core Zones use:

- one forward mandatory spine;
- zero to two optional branches per spine room;
- permanent shortcuts that reconnect to an earlier spine room;
- no required dependency cycle;
- no reversible cross-room topology.

Zone flags flow forward along the spine.

## 30.5 Determinism

Every selection uses a named deterministic seed derived from:

- AP seed name;
- team;
- slot;
- Zone generation index;
- room ID;
- package role.

Decorative randomness uses a separate seed and cannot alter collision, offers, capability, timing, or reward reachability.

## 30.6 Physical authority

Python validates schema and semantic possibility.

Godot's instantiated geometry decides:

- clearance;
- support;
- line of sight;
- carry path;
- machine sweep;
- rail curve;
- launch arc;
- Grapple/Blink route;
- actual topology.

A package not physically proved does not count toward content budget and cannot gate an AP Check.

---

# 31. CROSS-SYSTEM COMPATIBILITY

This table is authoritative for Reliable Core. A missing pairing means no interaction.

| Source | Target | V1 behavior |
|---|---|---|
| Explosion | BREAKABLE_CRATE / DESTRUCTIBLE_COVER | Deals ordinary damage |
| Explosion | BOMBABLE_SURFACE | Only RECOVERABLE_BOMB or explicit BOMBABLE source works |
| Explosion | Ordinary architecture | No effect |
| Explosion | LIGHT / WEIGHTED loose object | Bounded impulse |
| Explosion | Socketed/locked required object | No impulse |
| Wind | Player | Authored acceleration within cap |
| Wind | LIGHT object | Authored acceleration within cap |
| Wind | WEIGHTED/COVER/HEAVY | No effect |
| Wind | Projectile | Only when projectile opts in |
| Physics | LIGHT/WEIGHTED | PUSH, PULL, or HOLD according to tags |
| Physics | COVER | PUSH/PULL only |
| Physics | COMPONENT | Only when package explicitly permits |
| Physics | Local key/AP Check/fixed machine | No effect |
| Physics | Ordinary enemy | No effect |
| Physics | LIGHTENED ordinary enemy | PUSH/PULL only |
| Player | Pressure plate | Weight 1.0 if accepted |
| Carried object | Pressure plate | Weight 0 |
| Loose object | Pressure plate | Semantic weight if accepted |
| Enemy | Pressure plate | Weight 1.0 only if accepted |
| Loose object | Moving platform/conveyor | Inherits platform/surface motion |
| Carried object | Socket | Places only through F |
| Socketed object | Physics/explosion/wind | No movement |
| LaunchPad | Player | Default accepted |
| LaunchPad | Object | Only explicit object-launch package |
| Hazard | Enemy | Only when AFFECTS_ENEMIES is true |
| Hazard | Required object | No damage unless package defines recovery |
| World fire | Actor | Ordinary FIRE damage |
| BURNING Status | Actor Health | No damage |
| Status | Machinery | Only an explicit authored sensor; none in Reliable Core |
| Light | Signal graph | Presentation only |
| Sound | Signal graph | Presentation only |
| Decorative water | Any system | No mechanical interaction |
| Puzzle reset | Confirmed AP Check | No effect |
| Puzzle reset | Zone flag/permanent shortcut | No effect |
| Room unload | Loose required object | Reconstruct at spawn/socket |

---

# 32. HUD AND FIRST-PERSON PRESENTATION

## 32.1 HUD layout

On a standard 16:9 display:

- bottom left: Health number/bar and Barrier overlay;
- bottom center: reticle, selected Weapon name, and feed state;
- bottom right: Q, E, 1, 2, 3 Ability states in one row;
- immediately above Ability row: Shift Mobility state;
- below reticle: current F interaction prompt;
- upper left: active enemy-target Statuses when focused;
- upper center: temporary puzzle timer or sequence progress;
- Tab: full Archive/loadout interface at the Hub or read-only Archive during an excursion.

Safe-area and UI-scale settings reposition these anchors rather than scaling from screen center without bounds.

## 32.2 Recharge presentation

- RESOURCE shows quantity, maximum, and activation cost.
- COOLDOWN shows charge pips and time until the next charge.
- ACTION shows the named required fact and progress.
- A failed preflight flashes the exact missing condition for 0.75 seconds.
- A contributing event briefly pulses the host it advanced.

## 32.3 Weapon presentation

The Weapon cycle appears around the reticle for 0.75 seconds after wheel input. It shows Static Pulse plus occupied slots and highlights the selected configuration.

Feed presentation:

- MAGAZINE: current/capacity, no reserve number;
- HEAT: heat bar, lock threshold, and VENT prompt;
- CHARGE: reticle/device charge indication;
- NONE: no fabricated feed widget.

## 32.4 Device model

The viewmodel uses authored modules:

- one core/body;
- one grip;
- one of seven emitter families matching the primary Weapon family;
- zero or one secondary module;
- one moving mechanism;
- one provenance accent;
- one Epsilon intrusion/glitch layer.

Static Pulse uses the neutral core emitter and white rhythmic pulse pattern.

Weapon switching uses a 0.18-second authored reconfiguration. It may swap/rotate modules, but the simulation selection changes at switch start and firing unlocks only when the transition ends.

Runtime never generates meshes or collision.

## 32.5 Physics and interaction feedback

The focused object receives a thin outline and verb prompt.

Physics feedback separately communicates:

- eligible target;
- acquired target;
- active relation;
- out-of-range tension;
- blocked line of sight;
- impending release;
- invalid/locked target.

These states use outline pattern and reticle shape as well as color.

## 32.6 Environmental language

Reusable visual forms:

| Meaning | Shape/motion language |
|---|---|
| Input | Inward triangle/press motion |
| Output | Framed square/mechanical response |
| Conduit | Directional chevrons |
| Timer | Shrinking segmented band |
| Latch | Closed clasp symbol |
| Reset | Circular return arrow |
| Locked socket | Crossbar |
| Valid socket | Matching silhouette |
| Hazard | Repeating angular stripe and prefire motion |
| AP Check | Existing cyan/white AP language |

Color reinforces these meanings but never carries them alone.

## 32.7 Accessibility

Required settings:

- HUD scale 80–150%;
- reticle size;
- camera shake 0–100%, default 40%;
- view bob 0–100%, default 35%;
- weapon motion 0–100%, default 70%;
- hold/toggle option for AIM, BLOCK, and GRAPPLE;
- subtitles and environmental cue captions;
- independent master/music/effects/voice volume;
- high-contrast interaction outlines;
- reduced-flash mode;
- color-vision palettes that preserve shape/pattern.

No mandatory clue uses audio, hue, or rapid flashing alone.

---

# 33. PERFORMANCE BUDGETS

Budgets are per currently loaded room unless stated otherwise.

| System | Hard limit |
|---|---:|
| Loaded gameplay rooms | 3 |
| Awake loose rigid bodies | 24 |
| Total loose rigid bodies across loaded rooms | 64 |
| Kinematic moving collision actors | 8 |
| Dynamic joints | 0 |
| Player-owned live projectiles | 32 |
| Enemy-owned live projectiles | 32 |
| Simultaneous Weapon beams | 1 player + 4 enemy |
| Spawned Ability fields | 8 |
| Active hazards | 16 |
| Signal nodes | 64 per room |
| Signal edges | 128 per room |
| Signal deliveries | 256 per fixed tick |
| Trigger listeners | 16 active build |
| Trigger effects | 32 per frame |
| Physics relations | 1 player |
| Active Status instances | 6 per target |
| Path-machine actors | 6 |

Loose rigid bodies sleep after two seconds below 0.05 m/s linear and 2°/s angular velocity.

Decorative debris is nonpersistent, has no semantic weight, cannot activate inputs, and despawns after ten seconds when off camera and farther than 15 metres.

Projectiles despawn at their family lifetime or immediately after an unrecoverable collision.

Performance-limit violations are validation failures for generated content. The runtime may cull decorative content, but it may not cull required semantic objects.

---

# 34. DEBUGGING AND INSPECTION

Developer mode supplies four overlays:

## 34.1 Interaction overlay

Shows:

- all candidates;
- range, angle, line-of-sight result;
- semantic priority;
- winning tie-break;
- current prompt and rejection reason.

## 34.2 Signal overlay

Shows:

- nodes, port types, and current state;
- queued pulse sequence;
- edges and evaluation order;
- reset group and persistence;
- controlled actuator.

## 34.3 Puzzle overlay

Shows:

- package family/version;
- consumed offers;
- capability requirements;
- completion/failure state;
- required objects and recovery state;
- timing calculation;
- AP Checks gated;
- validator result and fallback history.

## 34.4 Runtime overlay

Shows:

- committed loadout;
- Weapon feed state;
- Ability/Mobility readiness and costs;
- active pools and Links;
- Status chance components;
- damage-resolution calculation;
- active rule/listener count;
- rigid-body/projectile/signal budgets;
- current Zone flags.

All audit failures write structured records containing Zone seed, room ID, package ID, semantic object ID, and exact reason.

---

# 35. REQUIRED AUTOMATED TESTS

The canonical Player and Dungeon acceptance tests remain. Reliable Core additionally requires the following executable suites.

## 35.1 Schema and migration

1. Every Epsilon-fillable enum is closed.
2. Unknown fields and out-of-range values fail.
3. Historical interpretation logs remain immutable.
4. Every old primitive maps or produces a visible quarantine.
5. No old Status can schedule periodic damage.
6. Loading and saving without changes is byte-stable except explicit metadata.

## 35.2 Player

7. Empty build completes a basic enemy encounter.
8. Static Pulse cannot leave the cycle.
9. Melee hits one target once per activation.
10. Rebinding changes physical input without changing semantic role.
11. Death preserves spent magazines, Heat, Resources, and recharge progress.
12. Completed-Zone revisit starts a fresh excursion.
13. Suspended excursion rejects loadout changes.

## 35.3 Weapons and Abilities

14. Switching cancels reload/vent/charge/channel without refilling.
15. Inactive Weapons run no listeners.
16. Every Weapon family remains inside its DPS envelope at schema extremes.
17. Failed preflight spends nothing.
18. Post-commit miss does not refund.
19. Serial charges restore one at a time.
20. Action progress advances only from its declared fact.
21. Shared pools have at most two consumers.
22. A reaction graph cannot contain a directed refill loop.

## 35.4 Damage and Status

23. Every Health/Barrier loss creates one DAMAGE_RESOLVED record.
24. Same non-crit request produces the same damage.
25. Save/load cannot reroll crit or Status.
26. 150% crit never produces an ordinary hit.
27. Physics/hazard/explosion cannot crit.
28. Status failure increases visible susceptibility to its cap.
29. Status success resets susceptibility and adds adaptation.
30. BURNING alone never changes Health.
31. Every boss Status uses its declared substitute or explicit immunity.

## 35.5 Interaction and Physics

32. Candidate selection is stable regardless of scene-tree insertion order.
33. Prompt and activated verb always agree.
34. Carried object cannot activate a plate.
35. Required object recovers from loss and destruction.
36. Incompatible socket rejects visibly.
37. Physics cannot target AP, fixed, socketed, or locked objects.
38. Resting/jittering props cause no damage.
39. Impact damage cannot exceed 25.

## 35.6 Signals and machinery

40. Signal graph result is independent of scene-tree order.
41. Simultaneous SET/RESET resolves to RESET.
42. A pulse crosses each edge once.
43. General graph cycles fail generation.
44. Non-hazard door reopens around player and required objects.
45. Rail switch waits for junction clearance.
46. Lift cannot stop between valid floors after power loss.
47. Reset clears only its declared group.

## 35.7 Puzzle packages

48. Every shipped family has at least one deterministic fixture.
49. Every fixture passes initial, completion, reset, death, save/load, and room-reload simulation.
50. Every timed fixture uses the audited minimum formula.
51. Every DUAL_INPUT fixture is solo-solvable.
52. Every A/B state preserves a route to reset or completion.
53. Every local key precedes its lock and respects keyring capacity.
54. Every Zone flag dependency points forward.
55. A package failure selects the same deterministic fallback on replay.
56. A puzzle completion never sends an AP Check without the separate F interaction.

## 35.8 Performance and accessibility

57. Generated rooms cannot exceed hard budgets.
58. Inactive physics bodies sleep.
59. Required semantic objects cannot be culled.
60. Every required audio cue has a visual cue.
61. Every color-coded critical state differs by shape, motion, or pattern.
62. Debug overlays identify the responsible package and object without manual scene inspection.

---

# 36. IMPLEMENTATION ORDER

Claude should implement Reliable Core in the following sequence. A later wave does not begin until the prior wave's tests pass.

## Wave 1 — Schema and migration seam

- Add new host/loadout/puzzle schemas beside the old schema.
- Preserve the historical interpretation log.
- Implement projection migration and quarantine reporting.
- Add semantic input actions and binding settings.

## Wave 2 — Common player foundation

- Common damage request/resolver.
- Health, Barrier, Defense, crit.
- Static Pulse and baseline melee through the common road.
- Excursion state and runtime snapshot protocol.

## Wave 3 — Weapon host

- Weapon selection and device cycle.
- Seven primary families.
- Four secondary options.
- MAGAZINE, HEAT, CHARGE, and NONE state machines.
- Weapon HUD and tests.

## Wave 4 — Ability and Mobility hosts

- Activation/preflight/commit service.
- Resource, Cooldown, and Action readiness.
- Ten Ability families.
- Five Mobility families.
- Capability advertising and route audit.

## Wave 5 — Status, Gear, and Mods

- Six Status families.
- Pity/adaptation.
- Gear slots and one-high-tier enforcement.
- Closed Mod catalog, ordering, budgets, and loop validator.
- Archive projection and Hub loadout UI.

## Wave 6 — Interaction and physical objects

- Deterministic F resolver.
- Carry/drop/place.
- Sockets, object identity, recovery, and reset.
- Four Physics primitives and impact damage.

## Wave 7 — Environmental cause and effect

- Signal graph.
- Inputs and sensors.
- Visible conduits.
- Doors and foundational actuators.
- Save/reset reconstruction.

## Wave 8 — Machinery and packages

- Platforms, lifts, path machines, rail switches, LaunchPad power, hazard controllers.
- ROUTE_MATCH hacking.
- Puzzle-package manifest and validation pipeline.
- Simple package families first, then transforming and multi-stage families.

## Wave 9 — Environmental combat and Zone state

- Hazards, destruction, barrels, bombs, and local rewards.
- Wind, conveyors, cargo, and kinematic constraints.
- Forward Zone flags and cross-room reconstruction.
- Capability entry enforcement.

## Wave 10 — Presentation and hardening

- Modular device presentation.
- Final HUD and accessibility settings.
- All debug overlays.
- Performance budgets and soak fixtures.
- Full canonical acceptance suite.

---

# 37. STARTING TUNING POLICY

Numbers explicitly stated in this proposal are the v1 implementation defaults.

They may move only inside their stated schema bounds without reopening architecture.

The following require a named balance change and updated fixture but not a design revision:

- movement acceleration;
- Static Pulse and melee numbers;
- Weapon damage/cadence within family envelopes;
- feed capacity/rates;
- Ability costs and recharge;
- Status chance/pity/adaptation;
- hazard damage/timing;
- interaction ranges;
- Physics force/range;
- Gear/Mod percentages;
- performance limits after measured profiling.

Changing an enum, state transition, persistence category, capability meaning, deferred-feature boundary, or interaction pairing requires a versioned design revision.

---

# 38. RELIABLE CORE DECISION SUMMARY

Reliable Core deliberately makes these major choices:

1. Keep the full Player slot fantasy, but build it from closed host templates.
2. Preserve current good movement and Static Pulse values.
3. Use finite Weapon, Ability, Mobility, Status, Gear, and Mod catalogs.
4. Make active loadout state excursion-bound, eliminating in-Zone swap exploits.
5. Preserve old provenance while migrating old mechanics into inactive Archive pieces.
6. Stop generating cross-item mutation operations in v1.
7. Defer Forge and leave Epsilon Static banked.
8. Keep baseline carrying simple and omit baseline throwing.
9. Limit Physics to PUSH, PULL, HOLD, and ALIGN; never require it for progression.
10. Use a deterministic acyclic room signal graph.
11. Implement one reusable hacking minigame.
12. Ship eighteen concrete puzzle families.
13. Defer energy-ball, reflector-beam, and full water systems.
14. Use kinematic machinery instead of dynamic joints.
15. Give dungeons forward-only persistent Zone flags rather than arbitrary cross-room graphs.
16. Restrict hard capability progression to RANGED_HIT, GRAPPLE, BLINK, and CROSS_LONG_GAP.
17. Reject automatic equip and local capability invention.
18. Set numeric performance and interaction budgets before content scales up.

There are no intentionally open behavioral decisions inside this proposal.

Anything not described is either:

- inherited unchanged from the named authorities or existing AP/campaign authority;
- rejected by a closed schema;
- explicitly deferred above.

**End of Complete Design 1: Reliable Core**
