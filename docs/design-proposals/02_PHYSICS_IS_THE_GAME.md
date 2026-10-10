# ARCHIPEPSI — COMPLETE DESIGN 2: PHYSICS IS THE GAME

## Rearrangement as the central verb

**Status:** Complete alternative proposal. Not canon until selected by the owner.
**Proposal:** 2 of 5
**Design thesis:** The player's defining capability is rearranging authored matter. Combat and traversal are contexts in which rearrangement pays off — not systems physics replaces.
**Target:** Godot 4.5 client plus the existing Python/Pydantic bridge.
**Source authorities:** `docs/authorities/PLAYER_DESIGN_AUTHORITY_v1.0.md`, `docs/authorities/DUNGEON_ENVIRONMENT_AUTHORITY_v0.1.md`
**Written against:** `docs/design-proposals/00_ZERO_GUESSWORK_STANDARD.md` v1.1

### Proposal profile

| Axis | Rating |
|---|---:|
| Novelty | 4 / 5 |
| Player-build variety | 3 / 5 |
| Environmental breadth | 5 / 5 |
| System interaction depth | 5 / 5 |
| Implementation risk | 4 / 5 |
| Procedural validation difficulty | 4 / 5 |
| Reuse of current repo foundations | 3 / 5 |

**Principal tradeoff:** Physics Is The Game spends its complexity budget on one system and pays for it everywhere else. The manipulation language is deep, constraints are genuinely simulated, and physical configuration is real persistent state. In exchange the Weapon and Ability catalogs are half the size of Design 1's, Zones are shorter and lean harder on authored rooms, and the performance and validation budgets are the tightest of any proposal.

**Who should pick this:** an owner who thinks the memorable moments in Archipepsi will be the ones where the player solved something the level designer did not plan, and who is willing to trade catalog breadth and generation freedom to get them.

---

# 0. PURPOSE

This document resolves every open decision in the two source authorities into an implementable form, to the Zero-Guesswork Standard.

## 0.1 What the thesis actually claims

"Physics is the game" is easy to state loosely and easy to get wrong, because the Player Authority explicitly rejects three readings of it:

| Rejected reading | Authority |
|---|---|
| Physics as unrestricted telekinesis | §30.16 |
| Physics as the main movement system | §30.17 |
| Physics as dominant damage | §30.18 |

This proposal accepts all three rejections without amendment. Weapons remain the damage road. Mobility remains the movement identity. Manipulation remains bounded.

What it claims instead is narrower and, this proposal argues, more interesting:

> **Rearranging the world is the player's most expressive verb, the primary way rooms are solved, and a legal progression requirement.**

The authority permits exactly this. §25.1 lists "a validated manipulation family" among the capabilities a hard gate may require, and §17.2 states the governing principle — physics rearranges energy and matter more effectively than it creates either. Design 1 declined to use that permission. Design 2 is built on it.

The payoff for moving an enemy is that the enemy is now in a flame jet, off a ledge, out of cover, or pinned in your firing line. It is not that the throw killed them. That distinction is what keeps this proposal inside §30.18, and §31.3 defines the invariant that enforces it.

## 0.2 Relationship to Design 1

Design 2 **explicitly pins** the systems it shares with Design 1 by section number rather than restating them. A pin reads:

> *Pinned: identical to Design 1 §8.2.*

This is not the silent inheritance forbidden by Standard §2.4. Those pins are precise, they name a document and a section in this repository, and the pinned text is itself closed. The purpose is that a reader choosing between proposals can see the actual differences rather than diffing 30,000 words of restatement, and that two documents cannot drift into slightly different descriptions of the same system.

**Anything that differs from Design 1, even slightly, is restated here in full.** A pin means *identical*. Where you see a pin, Design 1's text is the contract.

Sections with no pin and no content are impossible; every section either has content or a pin.

---

# 1. INHERITED LAWS

*Pinned: identical to Design 1 §1.1 and §1.2.* All 48 laws are inherited unchanged, including the three physics rejections in §30.16–§30.18 of the Player Authority.

Two of those laws deserve emphasis here because this proposal comes closest to them:

- **Law 20** — Physics Echoes are bounded manipulation, never universal movement or dominant damage. §31.3 defines the measurable invariant this proposal uses to hold that line.
- **Law 34** — `NO REQUIREMENT BEFORE GUARANTEE`. Design 2 introduces a manipulation capability gate, which makes this law load-bearing in a way it was not for Design 1. §29 is correspondingly stricter.

## 1.3 Precedence

*Pinned: identical to Design 1 §1.3.*

---

# 2. SCOPE

## 2.1 Ships in Physics Is The Game

**The manipulation system — this proposal's whole reason to exist**

- Twelve physics verbs (§14.1), against Design 1's four.
- Genuine constraint simulation: hinges, sliders, ropes, chains, pulleys, counterweights, seesaws, pendulums (§26.5). Design 1 deferred all of these and made machinery kinematic.
- Bounded attachment and detachment (§14.6).
- Local gravity volumes (§27.5).
- `MANIPULATE` as a real, planner-proven capability gate (§29).
- Transform-level persistence for physical configurations, with semantic latching (§5.7).
- A twelve-class object taxonomy with real mass, material, and constraint compatibility (§10.1).
- Enemies as physical objects: repositionable, pinnable, tetherable (§32.4).
- Environmental kills as a first-class, fully credited win condition (§25.4).

**Player — narrower than Design 1, deliberately**

- Four Weapon primary families (Design 1: eight), four secondary kinds (Design 1: five), three feed models (Design 1: four).
- Eight Ability families (Design 1: twelve).
- Five Mobility families — *pinned: identical to Design 1 §13*.
- Four Statuses (Design 1: six), all of which change physical behavior.
- Gear and Mods — *pinned: identical to Design 1 §16*, except the four intrinsic templates replaced in §16.1.1.

**Dungeon**

- Signal graph, sensors, actuators, hacking — *pinned: identical to Design 1 §19–§22*, with the actuator additions in §21.10.
- Sixteen puzzle families (§24), of which nine are new to this proposal and seven are pinned from Design 1.
- Hazards and destruction — *pinned: identical to Design 1 §25*, with the additions in §25.6.
- Shorter Zones over more authored shells (§30.2).

## 2.2 Explicitly deferred

| Deferred system | Cost of deferring |
|---|---|
| Forge | *Pinned: identical to Design 1 §2.2.* No item synthesis; Mods accumulate; Epsilon Static banks with no sink. |
| Water, swimming, buoyancy | Removes a medium that would interact richly with this proposal's buoyant objects and constraint system. This is a **more painful** deferral here than in Design 1, and §41.2 records it as such. |
| Energy balls and reflector beams | Removes two routing families. Their puzzle role is partly covered by this proposal's cargo, counterweight, and tether families. |
| Portals and teleporters | No space folding. Constraint simulation across a portal is a research problem, not a feature. |
| Gases, smoke, steam, pressure, temperature | Removes a hazard and readability channel. |
| Directional gravity | Local gravity *magnitude* volumes ship (§27.5); gravity *direction* does not. Reorienting the player's up-vector breaks the movement law, every validator, and the camera. |
| Programmable logic | *Pinned: identical to Design 1 §2.2.* |
| Rotating whole rooms | Rotating machinery within a room ships and is load-bearing here; rotating the room does not. |
| In-Zone loadout stations | *Pinned: identical to Design 1 §2.2.* Hub-only editing. |
| Arbitrary runtime mesh construction | Player Authority §30.19. Attachment (§14.6) joins existing authored objects; it never creates geometry. |

**Deferral means:** *pinned: identical to Design 1 §2.2.* Absent, unschema'd, unstubbed.

## 2.3 Removed rather than deferred

*Pinned: identical to Design 1 §2.3.*

## 2.4 What "v1" means here

*Pinned: identical to Design 1 §2.4.*

---

# 3. AUTHORITY AND DATA OWNERSHIP

*Pinned: identical to Design 1 §3.1, §3.2, §3.3, §3.4, §3.5.*

The profile mechanism (Design 1 §3.3) is inherited without change: **Epsilon selects a named profile and never emits a number.** It is orthogonal to this proposal's thesis, it works, and Standard §5.2 asks a proposal to inherit it or say what replaces it. Design 2 inherits it.

## 3.6 One addition: physical authority is absolute here

Design 1 §30.8 states that geometry wins over composition claims. Design 2 extends that: **when the simulation and the puzzle's semantic state disagree, the semantic state wins for progression and the simulation wins for everything else.**

This is the central architectural consequence of shipping real constraint simulation. A counterweight that has opened a door has *opened the door*, permanently and semantically (§5.7), even if the rope later settles into a configuration that no longer satisfies the original condition. Without this rule, a settling simulation can close a door behind the player and strand them, and no amount of validation prevents it — the failure is in the physics, which is exactly the thing a validator cannot fully predict.

---

# 4. SCHEMAS

*Pinned: identical to Design 1 §4.1, §4.2, §4.6, §4.7* — common types, the host definition, the profile shape, and the loadout.

The following shapes differ.

## 4.3 Weapon

```
WeaponDefinition (extends HostDefinition, category = WEAPON):
  primary           : WeaponAction
  secondary         : SecondaryAction? = null
  feed              : FeedSpec
  view_modules      : list[Id], length 3..6

WeaponAction:
  family            : enum { HITSCAN_SINGLE, PROJECTILE_DIRECT,
                             BEAM_CONTINUOUS, CLOSE_ARC }
  profile           : Id
  status_applied    : Id? = null
  status_chance     : Chance = 0.0
  crit_eligible     : bool = true
  physical_rider    : enum { NONE, IMPULSE, ANCHOR_POINT, MASS_SHIFT } = NONE
  rider_magnitude   : enum { SMALL, MEDIUM, LARGE }? = null
                      # required iff physical_rider != NONE, else must be null

SecondaryAction:
  kind              : enum { ZOOM, ALT_FIRE, GUARD, TETHER_SHOT }
  profile           : Id
  alt_action        : WeaponAction? = null    # required iff kind == ALT_FIRE

FeedSpec:
  model             : enum { MAGAZINE, HEAT, NONE }
  profile           : Id
```

Two changes from Design 1 beyond the shrunken enums. `physical_rider` is new: every Weapon may carry one bounded physical effect alongside its damage, which is how Weapons participate in the manipulation language without becoming manipulation tools. `TETHER_SHOT` replaces `DETONATE` and `MODE_SWAP` as a secondary kind, because `PROJECTILE_LOB` is not a family here and mode-swapping a four-family catalog buys little.

`CHARGE` is not a feed model in Design 2. Charge-and-release exists on Abilities (§12.2) but not on Weapons, because a held Weapon charge conflicts with `HOLD`-style manipulation on the same input cluster.

## 4.4 Ability and Mobility

```
AbilityDefinition (extends HostDefinition, category = ABILITY):
  family            : enum { PHYSICS_VERB, AREA_BURST, BARRIER_GRANT,
                             DEPLOYABLE_ANCHOR, STATUS_APPLICATOR,
                             MARK_REVEAL, MASS_FIELD, TEMPORARY_RULE }
  activation        : enum { PRESS, HOLD, CHARGE_RELEASE, CHANNEL }
  recharge          : RechargeSpec
  profile           : Id
  status_applied    : Id? = null
  status_chance     : Chance = 0.0
  physics_verb      : enum { PUSH, PULL, HOLD, ALIGN, TETHER, PIN,
                             ATTACH, DETACH, ROTATE, SETTLE }? = null
                      # required iff family == PHYSICS_VERB, else must be null
  field_verb        : enum { LIGHTEN_FIELD, ANCHOR_FIELD }? = null
                      # required iff family == MASS_FIELD, else must be null
```

`MobilityDefinition` and `RechargeSpec` — *pinned: identical to Design 1 §4.4*, except that `HybridSpec.template` gains one entry, `MANIPULATION_ADVANCES_COOLDOWN` (§12.7).

## 4.5 Gear, Mod, Status

*Pinned: identical to Design 1 §4.5*, except:

- `StatusDefinition.id` is one of the **four** in §15.1 rather than six.
- `StatusDefinition.family` is `enum { KINETIC, THERMAL }` — `COGNITIVE` does not exist in Design 2, because both of Design 1's cognitive Statuses are cut (§15.6).

## 4.8 Physical object — new to Design 2

Design 1 stored puzzle state semantically and never persisted a transform (§17.6 of the Dungeon Authority permits exactly that). Design 2 cannot: a stacked, wedged, or counterweighted configuration **is** the puzzle state, and it is not expressible as a Boolean.

```
PhysicalObject:
  id                : Id
  class             : one of the twelve in §10.1
  mass_kg           : float > 0.0
  material          : enum { METAL, STONE, WOOD, COMPOSITE, GLASS }
  mass_class        : MassClass                # derived from mass_kg per §10.2
  manipulable       : bool
  attach_points     : list[AttachPoint] = []
  constraint        : ConstraintSpec? = null   # non-null iff the object is jointed
  required          : bool = false
  home_transform    : transform
  allowed_volume    : Id
  destructible      : bool = false
  physics_permitted : bool = true              # note the inverted default vs Design 1

AttachPoint:
  local_transform   : transform
  accepts_materials : list[enum { METAL, STONE, WOOD, COMPOSITE, GLASS }]
  occupied_by       : Id? = null

ConstraintSpec:
  kind              : enum { HINGE, SLIDER, ROPE, CHAIN, PULLEY,
                             COUNTERWEIGHT, SEESAW, PENDULUM }
  anchor_a          : Id                       # object or world anchor
  anchor_b          : Id?  = null              # null for world-anchored
  length            : Meters?  = null          # required for ROPE, CHAIN, PULLEY
  limit_lower       : float?   = null          # required for HINGE, SLIDER, SEESAW
  limit_upper       : float?   = null          # same
  breakable_at      : float?   = null          # newtons; null means unbreakable
```

`physics_permitted` defaults to `true` here and defaulted to `false` in Design 1. That inversion is the schema-level expression of the thesis: in Design 2 an object is manipulable unless a package says otherwise, and a package that forbids manipulation must justify it against §14.5.

## 4.9 Physical configuration state — new to Design 2

```
PhysicalConfiguration:
  object_id         : Id
  transform         : transform                # position and rotation, 32-bit floats
  linear_velocity   : vec3
  angular_velocity  : vec3
  sleeping          : bool
  attached_to       : list[Id] = []
  constraint_state  : ConstraintState? = null

ConstraintState:
  broken            : bool = false
  current_value     : float                    # angle for HINGE/SEESAW/PENDULUM,
                                               # extension for SLIDER/ROPE/CHAIN/PULLEY
```

Serialized at 32-bit float precision. This is deliberate: 64-bit would imply a fidelity the simulation does not have, and any puzzle whose correctness depends on more than 32-bit positional precision is a puzzle this proposal forbids (§23.5 check 19).

---

# 5. LIFECYCLE AND PERSISTENCE

## 5.1 The five categories

*Pinned: identical to Design 1 §5.1.* The category table and its boundary semantics are unchanged.

## 5.2 Category assignment

Differs from Design 1 in the physical rows. The full table:

| State | Category |
|---|---|
| Projectiles, beams, VFX, audio | `EPHEMERAL` |
| Timed button remaining time | `EPHEMERAL` |
| Enemy positions and health | `EPHEMERAL` |
| **`PhysicalConfiguration` of any object with `required = true`** | **`PUZZLE_LOCAL`** |
| **`PhysicalConfiguration` of any object participating in a constraint** | **`PUZZLE_LOCAL`** |
| **`PhysicalConfiguration` of any other object** | **`EPHEMERAL`** |
| **Attachment graph** | **`PUZZLE_LOCAL`** |
| **Constraint broken-flags** | **`PUZZLE_LOCAL`** |
| **Latched puzzle conditions (§5.7)** | **`ROOM_PERSISTENT`** |
| Socket occupancy | `PUZZLE_LOCAL` |
| Lever and latch state | `PUZZLE_LOCAL` |
| Machinery position along its path | `PUZZLE_LOCAL` |
| Destructible destroyed-flag | `PUZZLE_LOCAL` |
| Sequence node progress | `PUZZLE_LOCAL` |
| Encounter cleared-flag | `ROOM_PERSISTENT` |
| One-way shortcut opened-flag | `ROOM_PERSISTENT` |
| Local key collected-flag | `ROOM_PERSISTENT` |
| Secret discovered-flag | `ROOM_PERSISTENT` |
| Checkpoint reached-flag | `ROOM_PERSISTENT` |
| Zone flags | `ZONE_PERSISTENT` |
| Player Health at checkpoint | `ZONE_PERSISTENT` |
| Host runtime state | `ZONE_PERSISTENT` |
| Check activated | `AP_PERSISTENT` |
| Items received, Archive contents | `AP_PERSISTENT` |
| Coins, Signal Keys, Epsilon Static | `AP_PERSISTENT` |
| Committed Loadout | `AP_PERSISTENT` |

The three-way split on `PhysicalConfiguration` is the load-bearing decision. Persisting every rigid body would make saves enormous and reloads slow; persisting none would lose the puzzle. Objects that matter — required ones and jointed ones — persist their full transform. Decorative debris does not and rebuilds at `home_transform`.

## 5.3 Snapshot cadence

*Pinned: identical to Design 1 §5.3*, with one addition: a save is **refused** while any `PUZZLE_LOCAL` physical object is non-sleeping. See §5.8.

## 5.4 Death

*Pinned: identical to Design 1 §5.4*, with steps 2 and 5 as written there. Physical objects reset with their reset group, per §23.4.

## 5.5 Room unload and reload

*Pinned: identical to Design 1 §5.5*, with the addition that `PUZZLE_LOCAL` physical configurations serialize on unload and are restored on reload with velocities **zeroed** and `sleeping` forced true. A room reloaded mid-swing does not resume the swing; it resumes at rest in the same position. This is a deliberate loss of fidelity that removes an entire class of reload-divergence bugs, and §41.2 records it.

## 5.6 Host runtime state

*Pinned: identical to Design 1 §5.6.*

## 5.7 Latching

**New to Design 2 and central to it.**

A puzzle condition that has ever been satisfied is **latched**: recorded as `ROOM_PERSISTENT` and never re-evaluated.

```
LatchedCondition:
  package_id        : Id
  condition_index   : int >= 0
  latched_at        : int          # campaign event ordinal
```

Rules:

1. When a package's completion condition evaluates true, it latches on that same tick.
2. A latched condition is **never** re-evaluated. Its output signal is `ON` forever.
3. Latching survives death, reset, room unload, save/load, and Zone re-entry.
4. A package reset (§23.4) restores object positions but **does not clear latches**.
5. A latch is per-condition, not per-package. A three-condition package latches each independently.

This exists because simulated physics settles. A counterweight puzzle that opens a door can, minutes later, drift into a configuration that no longer satisfies its condition — a rope stretches, a stack topples, an object is nudged. Without latching, doors close behind players for reasons no validator can predict and no player can diagnose.

The cost is honest and worth stating: **a physics puzzle in Design 2 can be solved but not un-solved.** Toggling behaviour — Design 1's `A_B_STATE` family — cannot be driven by a physical configuration here. It is driven by levers and signals, which is why §24 keeps `A_B_STATE` as a signal family rather than a physical one.

## 5.8 Save refusal on moving physics

A manual save or checkpoint activation is refused while any `PUZZLE_LOCAL` physical object has `sleeping = false`.

The player is shown:

> **Cannot save right now.** Wait for everything to settle.

Objects sleep after `1.5 s` below `0.05 m/s` linear and `0.10 rad/s` angular. In practice the refusal lasts a few seconds after the player stops interacting. Checkpoints re-attempt automatically every `0.5 s` while the player remains in the trigger volume, so a checkpoint is never permanently missed.

This is the alternative to serializing a live simulation mid-motion and reproducing it exactly on load, which is not achievable across platforms and is the honest reason for the rule.

## 5.9 Save/load reconstruction order

Design 1 §5.9's ten steps, with two insertions. The full order:

1. AP state.
2. Committed Loadout.
3. Zone identity and seed; recompose deterministically.
4. Zone flags.
5. Per-room `ROOM_PERSISTENT` flags.
6. **Latched conditions (§5.7).**
7. Apply Zone flags and latches to machinery initial states.
8. Per-room `PUZZLE_LOCAL` state for the entry room and its neighbours.
9. **Physical configurations: place objects at their saved transforms, then rebuild the attachment graph, then rebuild constraints, then step the simulation `0` frames and assert every object is non-penetrating.** A penetrating object is displaced to the nearest free point within `1.0 m`; if none exists it returns to `home_transform`.
10. Host runtime state.
11. Player transform and Health.
12. Rebuild `EPHEMERAL` state.

Step 9's order matters. Constraints built before their objects are placed produce an immediate impulse as the solver corrects; placing first and constraining second produces none.

## 5.10 Mid-transition machinery

*Pinned: identical to Design 1 §5.10.* Actuators remain kinematic and store `t` and `direction`.

## 5.11 Temporary grants across a save

*Pinned: identical to Design 1 §5.11.* Barrier, Status, and `TEMPORARY_RULE` are `EPHEMERAL` and do not survive a save.

Held and tethered objects are also released on save/load. A `HOLD` or `TETHER` relation is `EPHEMERAL`; the object drops at its current position and the relation is not restored.

## 5.12 Active encounters across a save

*Pinned: identical to Design 1 §5.12.* Unreachable by construction.

---

# 6. BASE PLAYER

## 6.1 Body

*Pinned: identical to Design 1 §6.1*, with one addition: the player's `mass_kg` is `80.0`, which is `MEDIUM` per §10.2. Design 1 assigned the player a mass class directly; Design 2 needs an actual mass because the player stands on seesaws and counterweighted platforms.

## 6.2 Movement law

*Pinned: identical to Design 1 §6.2.* Every constant, derived value, and margin is unchanged.

This is deliberate and worth stating plainly: **Design 2 does not touch the movement law.** The temptation in a physics-centric design is to make the player heavier, floatier, or momentum-driven. That would invalidate every traversal audit, every LaunchPad solve, and every mandatory-route guarantee in both authorities. The physics in this proposal is in the world, not in the player's feet.

**One addition — external velocity.** The player's velocity may be modified by the world: moving platforms, seesaws, wind, and carried momentum. External velocity is added to input velocity and is clamped to `25.0 m/s` total. Air control never adds to a speed already above `AIR_MAX_STEER_SPEED`, per Design 1 §6.2, so external momentum cannot be amplified by strafing.

## 6.3 Out-of-bounds recovery

*Pinned: identical to Design 1 §6.3.*

## 6.4 Static Pulse

*Pinned: identical to Design 1 §6.4*, with one addition:

| Property | Value |
|---|---|
| `physical_rider` | `IMPULSE`, magnitude `SMALL` |
| Impulse on hit | `1.5 m/s` along the ray, to `LIGHT` objects only |

Static Pulse can nudge a light object. This matters because it is the permanent baseline: a room whose only remaining need is "move that small thing slightly" must never be unsolvable, and §29.2 relies on this being universally available.

It cannot move `MEDIUM` or heavier. It is a nudge, not a tool.

## 6.5 Baseline melee

*Pinned: identical to Design 1 §6.5*, with the impulse raised from `4.0 m/s` to `7.0 m/s` and extended to `MEDIUM` mass class. Melee is the baseline's physical verb; it shoves.

---

# 7. INPUT

*Pinned: identical to Design 1 §7.1, §7.2, §7.3, §7.4.*

The control grammar is frozen by the Player Authority and this proposal does not reinterpret it. Manipulation lives on the Ability slots (Q/E/1/2/3), on Weapon riders, and on `F`, exactly as the authority requires.

## 7.5 One addition: hold-to-manipulate and the interaction cluster

A `PHYSICS_VERB` Ability with `activation = HOLD` occupies its Ability input for as long as it is held. While such an Ability is held:

| Input | Behavior |
|---|---|
| Movement, look, jump | Unaffected |
| The held Ability's own input | Releases the verb |
| Another Ability input | Discarded, not queued |
| `weapon_primary`, `weapon_secondary` | Permitted; a held object is not dropped by firing |
| `melee` | Permitted |
| `mobility` | Permitted; the relation persists through a dash or blink if the object remains in range, and releases if it does not |
| `interact` | Discarded — `F` is unavailable while a physics relation is held |
| `weapon_cycle_*` | Permitted |

`F` being unavailable while holding is the single input-level concession this proposal makes to its thesis, and it is a restriction rather than a reassignment: `F` never does anything new, it is simply inert while a manipulation relation is active. This prevents the ambiguity where `F` might place a carried object or operate the terminal the held object is floating in front of. The prompt is suppressed entirely, so the player is never shown an action that will not fire.

---

# 8. DAMAGE

*Pinned: identical to Design 1 §8.1, §8.2, §8.3, §8.4, §8.5, §8.7, §8.8.*

The damage request shape, resolution order, Defense curve, Barrier pooling, linear overcrit, healing, and death are unchanged. One damage road, per inherited Law 22.

## 8.6 Friendly, self, and environmental damage

Design 1 §8.6's table, with two rows changed:

| Case | Behavior |
|---|---|
| Player damages `PLAYER`-faction actor | Full damage |
| Player's own explosion overlaps the player | `50%` damage, no crit, no Status, full impulse |
| Enemy damages enemy of same faction | Full damage |
| Enemy explosion damages the enemy that fired it | Full damage |
| Hazard damages any actor | Full damage, regardless of faction |
| **`PHYSICS` impact from a player-manipulated object hits the player** | **`25%` damage, capped at `20.0`, no crit** |
| **`PHYSICS` impact from a constraint-driven object hits the player** | **Full damage per §14.7** |

Design 1 set player-owned physics damage to the player at exactly zero. Design 2 cannot: when a swinging counterweight is the room's central mechanism, being hit by it must matter, or the mechanism is not a hazard and the room is not tense.

The split is by **causation**, not ownership. An object the player is actively pushing or holding deals `25%` capped damage back — enough to discourage carelessness, not enough to make manipulation feel punishing. An object moving under constraint or gravity, which the player may have set in motion but is not currently driving, deals full damage. A pendulum you released is a hazard. A crate you are shoving is not.

---

# 9. WORLD INTERACTION

*Pinned: identical to Design 1 §9.1, §9.3, §9.4.*

## 9.2 Deterministic focus

Design 1 §9.2's algorithm and its four-key sort are unchanged. The priority class table gains one row:

| Class | Contents |
|---|---|
| 1 | Terminal or panel currently open |
| 2 | Socket accepting the object currently carried |
| **3** | **Attach point accepting the object currently carried or held** |
| 4 | Pickup or drop target |
| 5 | Button, lever, door, Check |
| 6 | Optional or cosmetic interaction |

Design 1's classes 3, 4, 5 shift down to 4, 5, 6. Attach points sit above ordinary pickup because a player carrying a girder toward a visible attach point means to attach it.

`F` is inert while a physics relation is held (§7.5), so focus resolution never has to arbitrate between a held object and a carried one — those states are mutually exclusive.

---

# 10. CARRYABLES, OBJECTS, AND SOCKETS

## 10.1 The twelve object classes

Design 1 had seven. The five additions exist because constraint simulation gives them something to do.

| Class | Typical mass | Carriable | Manipulable | Role |
|---|---:|---|---|---|
| `GENERIC` | `15 kg` | yes | yes | General props |
| `WEIGHTED` | `140 kg` | **no** | yes | Pressure plates, counterweights |
| `POWER_CELL` | `40 kg` | yes | yes | Power sockets |
| `KEY_COMPONENT` | `8 kg` | yes | yes | Local key loops |
| `MECHANICAL_PART` | `55 kg` | yes | yes | Machinery repair sockets |
| `MOVABLE_COVER` | `220 kg` | no | yes | Sightlines, shields |
| `CART` | `180 kg` | no | yes | Constrained to floor path or rail |
| **`GIRDER`** | `95 kg` | no | yes | Spans gaps; attaches at both ends |
| **`BALLAST`** | `320 kg` | no | yes | Counterweight mass; rarely moved far |
| **`PLATE`** | `60 kg` | no | yes | Flat; bridges, ramps, blast shields |
| **`DRUM`** | `70 kg` | no | yes | Rolls; conveyors, ramps, momentum |
| **`ANCHOR_BLOCK`** | `500 kg` | no | **no** | A `FIXED` world attachment point that can be revealed or destroyed but never moved |

`WEIGHTED` is **not carriable** in Design 2, where Design 1 allowed it. At `140 kg` it is manipulated, not picked up. This is a real difference in feel: Design 1's cube puzzles are walked; Design 2's are pushed, pulled, and dropped.

## 10.2 Mass classes

Mass class is derived from `mass_kg`, not declared:

| Class | Range |
|---|---|
| `LIGHT` | `mass_kg < 30.0` |
| `MEDIUM` | `30.0 <= mass_kg < 120.0` |
| `HEAVY` | `120.0 <= mass_kg < 400.0` |
| `FIXED` | `mass_kg >= 400.0`, or `manipulable = false` |

Derivation rather than declaration means `LIGHTEN` (§15.1) has a defined effect on any object: it scales `mass_kg` and the class follows.

## 10.3 Pickup and carry

Carry rules — *pinned: identical to Design 1 §10.2* — with the eligibility rule changed: an object is carriable if `carriable = true` **and** `mass_kg <= 60.0`. Above that it is manipulable only.

## 10.4 Drop and place

*Pinned: identical to Design 1 §10.3*, including the absence of a throw. Dropping is zero-velocity.

Throwing is still absent in a physics-centric design, which deserves justification rather than a pin. `PUSH` (§14.3) is the throw. Giving the player both a carry-throw and a push verb produces two mechanisms with different force curves, different eligibility, and different damage rules for the same player intention, and the pair is a permanent source of "why did that do something different this time".

## 10.5 Recovery

*Pinned: identical to Design 1 §10.4*, with one addition to the trigger table:

| Trigger | Behavior |
|---|---|
| **A required object's constraint breaks and it comes to rest outside `allowed_volume`** | **Respawn at `home_transform` after `1.0 s`, with its constraint rebuilt** |

Semantic identity survives respawn, exactly as in Design 1: a respawned object has the same `id`, and latched conditions (§5.7) are unaffected.

---

# 11. WEAPONS

Four primary families against Design 1's eight. The catalog is narrow so the manipulation catalog can be wide, and every family carries a physical rider so Weapons participate in the world rather than sitting beside it.

## 11.1 Primary families

### `HITSCAN_SINGLE`
*Parameters: pinned from Design 1 §11.1.*

| Profile | `damage` | `interval` | `range` | `spread_deg` | falloff | `crit_chance` |
|---|---:|---:|---:|---:|---|---:|
| `cadence_rapid` | `7.0` | `0.10` | `50.0` | `1.2` | `25→45`, `0.6` | `0.05` |
| `cadence_standard` | `18.0` | `0.28` | `70.0` | `0.4` | `40→70`, `0.7` | `0.10` |
| `cadence_precise` | `52.0` | `0.85` | `120.0` | `0.0` | none | `0.30` |

### `PROJECTILE_DIRECT`
*Parameters: pinned from Design 1 §11.1.* Straight-line travelling body, unaffected by gravity.

| Profile | `damage` | `interval` | `speed` | `radius` | `lifetime` | `impact_radius` | `pierce_count` | `crit_chance` |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `bolt_fast` | `22.0` | `0.35` | `70.0` | `0.15` | `3.0` | `0.0` | `0` | `0.10` |
| `shell_impact` | `40.0` | `0.90` | `40.0` | `0.30` | `4.0` | `3.0` | `0` | `0.05` |

### `BEAM_CONTINUOUS`
*Parameters: pinned from Design 1 §11.1.*

| Profile | `damage` | `tick_interval` | `range` | `ramp_time` | `ramp_max_mult` | `crit_chance` |
|---|---:|---:|---:|---:|---:|---:|
| `beam_steady` | `4.0` | `0.10` | `35.0` | `0.0` | `1.0` | `0.05` |
| `beam_ramping` | `2.5` | `0.10` | `30.0` | `2.0` | `2.4` | `0.05` |

### `CLOSE_ARC`
*Parameters: pinned from Design 1 §11.1.*

| Profile | `damage` | `interval` | `reach` | `sweep_radius` | `max_targets` | `impulse` | `crit_chance` |
|---|---:|---:|---:|---:|---:|---:|---:|
| `arc_swift` | `34.0` | `0.45` | `2.8` | `0.7` | `4` | `5.0` | `0.15` |
| `arc_heavy` | `72.0` | `1.10` | `3.2` | `0.9` | `6` | `9.0` | `0.10` |

**Not present:** `HITSCAN_BURST`, `HITSCAN_SPREAD`, `PROJECTILE_LOB`, `CHARGE_RELEASE_SHOT`. Burst and spread are cadence variations that add catalog rows without adding decisions. `PROJECTILE_LOB` is cut because a gravity-affected projectile in a world full of moving physics objects is the single hardest thing to make read clearly. `CHARGE_RELEASE_SHOT` is cut with the `CHARGE` feed (§4.3).

## 11.2 Physical riders

Every Weapon carries exactly one rider, `NONE` included. This is how a four-family catalog stays expressive.

| Rider | Effect on hit | `SMALL` | `MEDIUM` | `LARGE` |
|---|---|---|---|---|
| `NONE` | None | — | — | — |
| `IMPULSE` | Applies impulse along the ray to `LIGHT` and `MEDIUM` objects | `1.5 m/s` | `4.0 m/s` | `8.0 m/s` |
| `ANCHOR_POINT` | Leaves a temporary attach point on the struck surface, usable by `TETHER` and `ATTACH` | `4.0 s`, 1 concurrent | `8.0 s`, 2 | `15.0 s`, 3 |
| `MASS_SHIFT` | Scales the struck object's `mass_kg` for a duration | `×0.75`, `4.0 s` | `×0.55`, `6.0 s` | `×0.40`, `8.0 s` |

Rider rules:

- A rider fires only on a hit that resolved through the damage road. A miss applies nothing.
- A rider applies to at most one object per shot — the first struck. `CLOSE_ARC` with `max_targets 6` applies its rider to the nearest struck object only.
- `MASS_SHIFT` never reduces an object's `mass_kg` below `1.0 kg`, and never affects `FIXED` objects.
- `MASS_SHIFT` does not stack. Reapplying refreshes duration and takes the lower multiplier of the two.
- `ANCHOR_POINT` on a surface that is itself moving attaches to that surface and moves with it.
- Riders apply to enemies for `IMPULSE` and `MASS_SHIFT` only. `ANCHOR_POINT` on an enemy does nothing and is not placed.

## 11.3 Secondary kinds

| Kind | Behavior | Uses feed |
|---|---|---|
| `ZOOM` | *Pinned: identical to Design 1 §11.2.* | no |
| `ALT_FIRE` | *Pinned: identical to Design 1 §11.2.* A second full `WeaponAction` with its own rider. | yes, shared |
| `GUARD` | *Pinned: identical to Design 1 §11.2.* | no |
| `TETHER_SHOT` | **New.** Fires an anchor that creates a `TETHER` relation (§14.3) between the struck surface and the next surface struck by a second `TETHER_SHOT`. Two shots make one tether; a third replaces the oldest. | no |

`TETHER_SHOT` profiles:

| Profile | `range` | `max_length` | `breaking_force` | `concurrent_tethers` |
|---|---:|---:|---:|---:|
| `tether_light` | `25.0` | `12.0` | `2200 N` | `1` |
| `tether_heavy` | `20.0` | `9.0` | `5000 N` | `2` |

A `TETHER_SHOT` tether is a real `ROPE` constraint (§4.8) with `breakable_at = breaking_force`. It is `EPHEMERAL`: it does not survive save, death, or room unload. Puzzle solutions may **use** a shot tether but may never **require** one, per §14.5 — a required tether is authored, not shot.

## 11.4 Feeds

*Pinned: identical to Design 1 §11.3 (`MAGAZINE`) and §11.4 (`HEAT`) and §11.6 (`NONE`).* `CHARGE` does not exist in Design 2.

## 11.5 Cycling and activation

*Pinned: identical to Design 1 §11.7*, with `CHARGE` and `PROJECTILE_LOB` rows removed as inapplicable. The full on-cycle-away table:

| State | On cycle away |
|---|---|
| `magazine_rounds` | preserved |
| `heat_current` | continues cooling at `inactive_cool_rate` |
| Heat lockout | continues draining |
| Beam ramp | reset to `0.0` |
| Reload in progress | cancelled, no progress retained |
| Vent in progress | cancelled, no reduction applied |
| Placed `ANCHOR_POINT`s | persist to their own expiry |
| Active `TETHER_SHOT` tethers | persist until broken or replaced |

Anchor points and tethers persisting across a cycle is the one exception to Design 1's "only the selected Weapon is activation-active" rule, and it is narrow: they are inert world objects once placed, not passives. They generate no events, apply no modifiers, and query no targets. They simply exist until they expire.

---

# 12. ABILITIES, READINESS, AND COST

## 12.1 The eight families

| Family | What it does | Damage | Legal Statuses |
|---|---|---|---|
| `PHYSICS_VERB` | Executes one of the twelve verbs in §14.1 | no | none |
| `AREA_BURST` | Instant damage plus radial impulse in a sphere | yes | any |
| `BARRIER_GRANT` | Grants Barrier | no | none |
| `DEPLOYABLE_ANCHOR` | Places a persistent world anchor point usable by `TETHER` and `ATTACH` | no | none |
| `STATUS_APPLICATOR` | Applies a Status with no damage | no | any, required |
| `MARK_REVEAL` | Highlights actors, Interactables, attach points, and constraint stress through geometry | no | none |
| `MASS_FIELD` | Scales `mass_kg` of every eligible object in a volume for a duration | no | none |
| `TEMPORARY_RULE` | Applies one typed rule change | no | none |

Design 1's `PROJECTILE_ATTACK`, `HEAL_CHANNEL`, `DEPLOYABLE_TURRET`, `DEPLOYABLE_FIELD`, `DASH_IMPULSE`, and `WEAPON_BUFF` are absent. `MASS_FIELD` and `DEPLOYABLE_ANCHOR` are new. The catalog is halved because `PHYSICS_VERB` and `MASS_FIELD` between them cover twelve verbs, each with its own parameters and eligibility, and total build complexity has to stay inside a player's head.

Common parameters — *pinned: identical to Design 1 §12.1* — with `magnitude` meanings:

| Family | `magnitude` means |
|---|---|
| `PHYSICS_VERB` | force in newtons |
| `AREA_BURST` | damage |
| `BARRIER_GRANT` | Barrier granted |
| `DEPLOYABLE_ANCHOR` | anchor lifetime in seconds |
| `STATUS_APPLICATOR` | `source_potency` added to application chance |
| `MARK_REVEAL` | ignored |
| `MASS_FIELD` | mass multiplier, where `< 1.0` lightens and `> 1.0` weighs down |
| `TEMPORARY_RULE` | the rule's scalar |

Profiles:

| Profile | `cast_time` | `duration` | `radius` | `range` | `magnitude` |
|---|---:|---:|---:|---:|---:|
| `ab_instant_light` | `0.00` | `0.0` | `0.0` | `40.0` | `35.0` |
| `ab_burst_kinetic` | `0.25` | `0.0` | `6.0` | `30.0` | `55.0` |
| `ab_barrier_small` | `0.00` | `8.0` | `0.0` | `0.0` | `50.0` |
| `ab_barrier_large` | `0.25` | `6.0` | `0.0` | `0.0` | `120.0` |
| `ab_anchor_short` | `0.20` | `20.0` | `0.0` | `25.0` | `20.0` |
| `ab_anchor_long` | `0.20` | `60.0` | `0.0` | `30.0` | `60.0` |
| `ab_status_reliable` | `0.15` | `0.0` | `0.0` | `35.0` | `0.30` |
| `ab_status_area` | `0.30` | `0.0` | `6.0` | `25.0` | `0.15` |
| `ab_reveal` | `0.00` | `12.0` | `30.0` | `0.0` | `0.0` |
| `ab_mass_light` | `0.15` | `10.0` | `7.0` | `20.0` | `0.35` |
| `ab_mass_heavy` | `0.15` | `8.0` | `6.0` | `20.0` | `2.50` |
| `ab_physics_light` | `0.00` | `0.0` | `0.0` | `20.0` | `700.0` |
| `ab_physics_standard` | `0.00` | `0.0` | `0.0` | `24.0` | `1400.0` |
| `ab_physics_strong` | `0.00` | `0.0` | `0.0` | `28.0` | `2600.0` |
| `ab_rule_standard` | `0.10` | `8.0` | `0.0` | `0.0` | `1.0` |

Physics forces are substantially higher than Design 1's `600–1400 N`, and ranges are longer. That is the thesis expressed in numbers.

## 12.2 Activation forms

*Pinned: identical to Design 1 §12.2 and §12.2.1.* `PRESS`, `HOLD`, `CHARGE_RELEASE`, `CHANNEL`, with the channel bounds from §12.2.1 — `duration` is maximum channel time, the first sample fires at `t = 0`, and the five end conditions apply.

## 12.3 Preflight and commit

*Pinned: identical to Design 1 §12.3.*

For `PHYSICS_VERB`, "family-specific validity" in preflight step 3 means: an eligible target exists per §14.2, within `range`, with line of sight. A verb aimed at nothing spends nothing.

## 12.4 `RESOURCE`

*Pinned: identical to Design 1 §12.4.*

## 12.5 `COOLDOWN`

*Pinned: identical to Design 1 §12.5.*

## 12.6 `ACTION`

Design 1 §12.6's parameter shape and cap behavior are unchanged. The **fact catalog differs** — three of Design 1's facts are removed as inapplicable and four physical facts are added:

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
| **`MASS_MOVED`** | **kilogram-metres of displacement the player caused, per §12.6.1** |
| **`ENVIRONMENTAL_KILL`** | **each kill credited to the player through §25.4** |
| **`OBJECT_ATTACHED`** | **each successful `ATTACH` (§14.3)** |
| **`CONSTRAINT_BROKEN`** | **each constraint the player caused to exceed `breakable_at`** |

`WEAPON_CYCLED` is removed — with four families and no mode swap, cycling is not a meaningful verb here.

| Profile | `fact` | `threshold` | `contribution` | `decay_rate` |
|---|---|---:|---:|---:|
| `act_melee_three` | `MELEE_HIT` | `3.0` | `1.0` | `0.0` |
| `act_kills_two` | `WEAPON_KILL` | `2.0` | `1.0` | `0.0` |
| `act_overcrit_four` | `OVERCRIT` | `4.0` | `1.0` | `0.0` |
| `act_distance_forty` | `DISTANCE_MOVED` | `40.0` | `1.0` | `0.0` |
| `act_blocked_150` | `DAMAGE_BLOCKED` | `150.0` | `1.0` | `0.0` |
| `act_mass_moved` | `MASS_MOVED` | `2000.0` | `1.0` | `0.0` |
| `act_env_kill_one` | `ENVIRONMENTAL_KILL` | `1.0` | `1.0` | `0.05` |
| `act_attach_two` | `OBJECT_ATTACHED` | `2.0` | `1.0` | `0.0` |

### 12.6.1 `MASS_MOVED`

Kilogram-metres, accumulated as:

```
contribution = mass_kg × distance_moved_this_tick
```

Counted only while the object is under an active player relation — being pushed, pulled, held, tethered by the player, or within `0.5 s` of a player-applied impulse. It is **not** counted for objects moving under gravity, under constraint, or under machinery.

Without that restriction, standing next to a pendulum would passively charge every `MASS_MOVED` ability in the game. The rule is that the player must be causing the motion, continuously.

`2000.0` kilogram-metres is roughly a `140 kg` `WEIGHTED` object dragged `14 m`, or a `320 kg` `BALLAST` lifted `6 m`. It is a meaningful amount of work.

## 12.7 Hybrids

Design 1 §12.7's five templates, plus one:

| Template | Applies to | `SMALL` | `MEDIUM` | `LARGE` |
|---|---|---|---|---|
| `KILL_ACCELERATES_COOLDOWN` | `COOLDOWN` | `−0.5 s` per kill | `−1.5 s` | `−3.0 s` |
| `ACTION_DISCOUNTS_RESOURCE` | `RESOURCE` | `−10%` cost | `−25%` | `−40%` |
| `ACTION_PROGRESS_DECAYS` | `ACTION` | `0.05/s` decay | `0.15/s` | `0.30/s` |
| `OVERCRIT_GENERATES_RESOURCE` | `RESOURCE` | `+4` per overcrit | `+10` | `+20` |
| `MOVEMENT_ADVANCES_COOLDOWN` | `COOLDOWN` | `−0.02 s` per metre | `−0.05 s` | `−0.10 s` |
| **`MANIPULATION_ADVANCES_COOLDOWN`** | `COOLDOWN` | **`−0.5 s` per `500` kg·m** | **`−1.5 s`** | **`−3.0 s`** |

Contribution cap, loop prevention, and the no-hidden-second-tax rule — *pinned: identical to Design 1 §12.7*. `MANIPULATION_ADVANCES_COOLDOWN` consumes the same `MASS_MOVED` accounting as §12.6.1, including its player-causation restriction, so a pendulum cannot recharge it either.

## 12.8 Runtime persistence

*Pinned: identical to Design 1 §12.8.*

## 12.9 The compatibility matrix

`●` = legal. A triple absent here is a hard error at load.

| Family | `PRESS` | `HOLD` | `CHARGE_RELEASE` | `CHANNEL` | `RESOURCE` | `COOLDOWN` | `ACTION` |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| `PHYSICS_VERB` | ● | ● | ● | | ● | ● | |
| `AREA_BURST` | ● | | ● | | ● | ● | ● |
| `BARRIER_GRANT` | ● | ● | | | ● | ● | ● |
| `DEPLOYABLE_ANCHOR` | ● | | | | ● | ● | ● |
| `STATUS_APPLICATOR` | ● | | ● | | ● | ● | ● |
| `MARK_REVEAL` | ● | | | | | ● | ● |
| `MASS_FIELD` | ● | | | ● | ● | ● | |
| `TEMPORARY_RULE` | ● | | | | ● | ● | ● |

Exclusions and why:

- **`PHYSICS_VERB` cannot be `ACTION`.** *Pinned reasoning from Design 1 §12.9*, and far more load-bearing here: manipulation is a progression capability in Design 2 (§29), and a progression tool gated behind a combat verb can strand a player in a room with nothing to kill.
- **`PHYSICS_VERB` gains `CHARGE_RELEASE`**, which Design 1 did not permit. A charged `PUSH` scaling force with charge is the single most requested shape for a manipulation verb and it is safe: charge affects magnitude only, never eligibility.
- **`MASS_FIELD` cannot be `ACTION`** for the same reason as `PHYSICS_VERB`, and cannot be `HOLD` because a held mass field plus a held physics verb would occupy two Ability inputs simultaneously for one continuous effect.
- **`MASS_FIELD` may be `CHANNEL`**, which is how a sustained lightening field is expressed: it pays per sample and ends when the player cannot pay.
- **`MARK_REVEAL` cannot be `RESOURCE`.** *Pinned reasoning from Design 1 §12.9.*

## 12.10 `TEMPORARY_RULE` catalog

Closed. Design 1's six, with two replaced:

| Rule | Effect for `duration` | `magnitude` means |
|---|---|---|
| `RULE_CRIT_FLOOR` | Player's `crit_chance` is at least `magnitude` | crit chance floor |
| `RULE_DEFENSE_ADD` | Player Defense `+magnitude` | Defense points |
| `RULE_STATUS_POTENCY` | Player's Status applications gain `+magnitude` chance | chance addend |
| `RULE_SPEED_ADD` | `WALK_SPEED × (1 + magnitude)` | fraction |
| **`RULE_MANIPULATION_FORCE`** | Player's physics verbs gain `×(1 + magnitude)` force | fraction |
| **`RULE_RELATION_COUNT`** | Player's `max_relations` `+magnitude`, capped at `6` total | integer |

`RULE_IMPULSE_IMMUNE` and `RULE_MASS_LIGHT` from Design 1 are removed: impulse immunity would trivialise this proposal's central hazard class, and player mass is now a real number used by seesaws and platforms rather than a class that can be swapped.

Two instances of the same rule do not stack; the later replaces the earlier and resets duration.

---

# 13. MOBILITY

*Pinned: identical to Design 1 §13.1 through §13.6.* Five families, the same profiles, the same ground and air legality, the same safety validation, the same grapple and blink specifics, the same mandatory-route contracts including the horizontal-only `long_gap` contract.

Mobility is untouched because Player Authority §30.17 rejects physics as the main movement system, and the cleanest way to honour that is to leave the movement system exactly as the conservative proposal has it. A physics-centric design that also rewrote traversal would be two designs.

## 13.7 One interaction: relations survive Mobility

A `HOLD`, `TETHER`, or `PIN` relation persists through a `DASH`, `BLINK`, `BURST_JUMP`, or `AIR_STEP` if the object remains within the verb's `range` after the move, and releases if it does not. `GRAPPLE` releases every relation at the moment the anchor attaches, because a grapple pull with a held object produces a two-body problem the solver handles badly and the player cannot predict.

---

# 14. THE MANIPULATION SYSTEM

This is the section the proposal exists for.

## 14.1 The twelve verbs

| Verb | Effect |
|---|---|
| `PUSH` | Impulse away from the player along the aim ray |
| `PULL` | Impulse toward the player along the aim ray |
| `HOLD` | Moves the target to a carry point and keeps it there while held |
| `ALIGN` | Rotates the target to the nearest axis-aligned orientation |
| `TETHER` | Creates a `ROPE` constraint between two surfaces or objects |
| `PIN` | Fixes the target in world space for a duration |
| `ATTACH` | Joins two objects at compatible attach points |
| `DETACH` | Separates an attachment, or breaks a constraint |
| `ROTATE` | Applies continuous angular velocity about the view axis |
| `LIGHTEN_FIELD` | Scales `mass_kg` down in a volume |
| `ANCHOR_FIELD` | Scales `mass_kg` up in a volume |
| `SETTLE` | Immediately damps all velocity on eligible objects in a volume |

**Which family hosts which verb.** Ten verbs are hosted by the `PHYSICS_VERB` Ability family; the two field verbs are hosted by the `MASS_FIELD` family (§12.1). The split is not cosmetic — the two families have different rows in the §12.9 compatibility matrix, because a field is a volume effect with a duration and the other ten are targeted acts. A verb is hosted by exactly one family and is never reachable through the other.

`SETTLE` deserves justification, because it is the only verb with no fictional analogue: it exists so a player who has knocked a room into chaos can calm it deliberately rather than waiting out §5.8's save refusal. It is the manipulation system's undo, and playtesting a physics game without one is how players learn to stop touching things.

## 14.2 Eligibility

A target is eligible only if **all** of:

| Condition | Rule |
|---|---|
| `manipulable` | The object's `manipulable` is `true` |
| Mass | `mass_kg <= verb_mass_limit` from the profile. `FIXED` objects respond to no verb except `DETACH` and `ROTATE` about a constrained axis. |
| Distance | Within the profile's `range` |
| Line of sight | Unobstructed from eye to target origin, except for `LIGHTEN_FIELD`, `ANCHOR_FIELD`, and `SETTLE`, which are volumes and require line of sight to the volume centre only |
| Actor rule | Enemies: `PUSH`, `PULL`, `PIN`, `LIGHTEN_FIELD`, `ANCHOR_FIELD` only. Never `HOLD`, `ATTACH`, `TETHER`, `ROTATE`, `ALIGN`, `DETACH`, `SETTLE`. |
| Boss rule | Bosses respond to no verb |
| The player | Never a target of any verb, ever |
| Progression rule | An object with `required = true` responds only if `physics_permitted = true` — which is the **default** in Design 2 (§4.8) |

Enemies being `HOLD`-ineligible is what keeps this proposal inside Player Authority §17.4's ban on "arbitrary enemy carrying". They can be shoved, dragged, pinned, and made light or heavy. They cannot be picked up and carried around, and they cannot be welded to things.

## 14.3 Verb behavior

Every verb, with its exact contract.

### `PUSH` / `PULL`

```
impulse_velocity = clamp(force / mass_kg, 0.0, 30.0)
```

Vertical component of the resulting velocity is clamped to `14.0 m/s` (§14.4). Applied as a single impulse on commit, not continuously.

| Profile | `range` | `force` | `verb_mass_limit` |
|---|---:|---:|---:|
| `ab_physics_light` | `20.0` | `700 N` | `120 kg` |
| `ab_physics_standard` | `24.0` | `1400 N` | `260 kg` |
| `ab_physics_strong` | `28.0` | `2600 N` | `400 kg` |

### `HOLD`

Moves the target to `hold_distance` ahead of the eye at up to `8.0 m/s`, then maintains it there. The held object collides with world geometry and stops against it; it passes through actors.

Releases on: input release, target leaving `range × 1.5`, line of sight blocked for `0.5 s`, `breakable_at` exceeded on a constraint the object participates in, player death, room unload, save, or the target being destroyed.

`hold_distance` is `3.5 m`, adjustable by the player between `1.5 m` and `6.0 m` with `weapon_cycle_next` / `weapon_cycle_prev` while holding. This is the one input remapping in Design 2, it applies only while a `HOLD` is active, and Weapon cycling resumes the instant the hold ends.

### `ALIGN`

Rotates to the nearest axis-aligned orientation over `0.3 s`, then holds orientation for `2.5 s` while translation continues normally.

### `TETHER`

Creates a `ROPE` constraint between the first and second surfaces struck by two successive activations. `length` is the distance between the two points at the moment the second is placed, `×1.05`. `breakable_at` is the profile's `breaking_force`.

A tether is `EPHEMERAL` and is destroyed by save, death, room unload, or Zone exit.

| Profile | `range` | `max_length` | `breaking_force` | `concurrent` |
|---|---:|---:|---:|---:|
| `ab_tether_light` | `22.0` | `14.0` | `2500 N` | `2` |
| `ab_tether_strong` | `18.0` | `10.0` | `6000 N` | `3` |

Placing a tether beyond `max_length` fails at the second activation, refunds nothing (the first activation already committed), and shows the rejection in §34.9.

### `PIN`

Sets the target to `FIXED` in world space for `duration`, ignoring gravity and all forces. Ends on duration, on `DETACH`, or on the player pinning something else beyond `max_relations`.

A pinned object still collides. A pinned object supporting weight holds it. This is the verb that makes improvised structures possible, and it is why `PIN` duration is short.

| Profile | `range` | `duration` | `verb_mass_limit` | `max_pinned` |
|---|---:|---:|---:|---:|
| `ab_pin_brief` | `20.0` | `6.0` | `260 kg` | `2` |
| `ab_pin_long` | `16.0` | `14.0` | `400 kg` | `1` |

### `ATTACH` / `DETACH`

`ATTACH` joins two objects at compatible attach points: the currently held object and a focused attach point within `4.0 m`, where the point's `accepts_materials` includes the held object's `material` and `occupied_by` is null. The join is a fixed weld, not a hinge.

`DETACH` separates an attachment, or breaks a `ConstraintSpec` whose `breakable_at` is non-null, at the focused point.

Attachment is `PUZZLE_LOCAL` and survives save, reload, and reset within its group.

**An attachment chain is capped at `4` objects.** The fifth `ATTACH` onto a chain fails with the §34.9 rejection. Without that cap a player builds an arbitrarily long bridge out of girders, which is the "permanent bridge printer" Player Authority §17.4 forbids.

### `ROTATE`

Applies `angular_velocity` about the view axis while held, up to `2.5 rad/s`. On a constrained object it drives the constraint within `limit_lower`/`limit_upper`. On a free object it spins it. On a `FIXED` object it does nothing unless that object has a `HINGE` or `SEESAW` constraint, in which case it drives that.

`ROTATE` is how valves, wheels, cranks, and rotating bridges are operated by hand.

### `LIGHTEN_FIELD` / `ANCHOR_FIELD`

Scales `mass_kg` of every eligible object whose origin is inside a sphere of `radius` at the aim point, for `duration`. `LIGHTEN_FIELD` uses `magnitude < 1.0`; `ANCHOR_FIELD` uses `magnitude > 1.0`.

Fields do not stack. An object inside two fields takes the one applied later.

Fields never move objects. They change what other forces can do to them, which is the point: a `320 kg` `BALLAST` is immovable until it is lightened, and a `15 kg` crate stops blowing around in the wind once it is anchored.

### `SETTLE`

Sets linear and angular velocity to zero on every eligible object within `radius` of the aim point, and forces `sleeping = true` on the next tick. Does not affect constrained objects currently driven by machinery, and does not affect actors.

| Profile | `range` | `radius` |
|---|---:|---:|
| `ab_settle_standard` | `25.0` | `8.0` |

## 14.4 Bounded manipulation — the limits that keep this legal

Player Authority §17.3 requires explicit contracts for every manipulation limit. In one place:

| Limit | Value |
|---|---|
| Impulse velocity ceiling | `30.0 m/s` |
| **Vertical velocity ceiling from any player-caused impulse** | **`14.0 m/s`** |
| `max_relations` (held, pinned, tethered, combined) | `3`, raised to at most `6` by `RULE_RELATION_COUNT` |
| Attachment chain length | `4` objects |
| Concurrent player-created tethers | `3` |
| `HOLD` carry distance | `1.5 m` to `6.0 m` |
| Verb mass limit | `400 kg`, the `FIXED` threshold |
| Manipulation force ceiling after all modifiers | `4000 N` |
| Field radius ceiling | `8.0 m` |
| `MASS_SHIFT` and field multiplier range | `0.30` to `3.00` |

**Physics never moves the player.** No verb targets the player, and no verb may be aimed at a surface to generate reaction force. This is Design 1's rule, unchanged, and it is what keeps §30.17 satisfied even though manipulation is far stronger here.

The `14.0 m/s` vertical ceiling is the specific defence against the "infinite staircase" in §17.4: a player can launch an object about `4.5 m` upward, which is enough to place a plate on a ledge and not enough to build a tower. Combined with the `4`-object attachment cap, improvised structures are local and bounded.

## 14.5 Physics and progression — the departure from Design 1

**Design 2 permits mandatory manipulation.** Design 1 forbade it. This is the single largest divergence between the two proposals.

A mandatory route or puzzle solution may require `capability:core:manipulate` (§29.1), subject to:

1. The capability is proven available before the requirement by the §29.2 planner. `NO REQUIREMENT BEFORE GUARANTEE` applies in full.
2. The required manipulation is satisfiable by the **least capable** granting profile, `ab_physics_light` at `700 N` and `20.0 m` range (§29.3).
3. The required solution never depends on a `TETHER_SHOT` tether, a player-created tether, an attachment chain longer than `2`, or a `PIN` — all of which are `EPHEMERAL`, player-created, or time-limited. Required solutions use only `PUSH`, `PULL`, `HOLD`, `ROTATE`, and the two fields.
4. The required solution never depends on a specific physical configuration holding for longer than `10.0 s`, because latching (§5.7) is what makes solutions permanent and a solution that must be *maintained* is a solution that can be lost.
5. Every mandatory manipulation puzzle has a validated reference solution recorded in its package manifest, and the validator replays it (§23.5 check 20).

Rule 5 is what makes this safe and is the expensive part of the proposal. Design 1 avoided mandatory physics precisely to avoid needing it.

## 14.6 Attachment

Attachment joins authored objects at authored points. It never creates geometry, per Player Authority §30.19.

- An attach point accepts one object. `occupied_by` is set on attach and cleared on detach.
- Attached objects become one rigid body for simulation, with summed mass and combined collision.
- The combined body's `mass_kg` is the sum; its class is re-derived per §10.2. Attaching two `MEDIUM` girders makes a `HEAVY` assembly that most verbs can no longer lift.
- Detaching restores the original bodies at their current world transforms with zero velocity.
- **A player-created attachment is separable with `F`**, at priority class 3 (§9.2), with the prompt `[F] Detach`. Only an authored attachment — one placed by a package manifest — requires the `DETACH` verb.

That last rule closes a softlock. A player may equip an `ATTACH` Ability without a `DETACH` Ability; without `F`-separation they could weld a required object to something and have no way to undo it. Package reset (§23.4 step 4) would eventually recover it, but requiring a reset to undo an ordinary action is a bad answer to a problem the interaction system already solves.
- An assembly may participate in a constraint. The constraint anchors to the object that was constrained before the attach.

## 14.7 Impact damage

```
damage = clamp((speed − 6.0) × mass_factor, 0.0, 90.0)
mass_factor = mass_kg / 40.0, clamped to [0.5, 4.0]
```

| Rule | Value |
|---|---|
| Speed threshold | `6.0 m/s` |
| Damage ceiling | `90.0` per impact, hard |
| Tags | `PHYSICS` |
| Crit eligible | **no** |
| Re-hit cooldown | `1.0 s` per (object, target) pair |
| To the player, from a player-driven object | `25%`, capped at `20.0` (§8.6) |
| To the player, from a constraint- or gravity-driven object | full |
| Provenance | `source_actor` = the player if the object was under a player relation or player impulse within the last `4.0 s`, else null |

The ceiling is `90.0` against Design 1's `45.0`. That is double, and it is the most dangerous number in this document, so §31.3 defines the invariant that keeps it from violating Player Authority §30.18.

## 14.8 Constraint simulation

The eight constraint kinds in §4.8 are genuinely simulated, not animated.

| Kind | Solver treatment |
|---|---|
| `HINGE` | Single-axis rotational joint with angular limits |
| `SLIDER` | Single-axis translational joint with limits |
| `ROPE` | Distance constraint, taut only — resists extension, not compression |
| `CHAIN` | Same as `ROPE`, rendered segmented, identical solver treatment |
| `PULLEY` | Two rope constraints sharing a total length through a fixed point |
| `COUNTERWEIGHT` | A `PULLEY` where one end carries an authored mass |
| `SEESAW` | A `HINGE` with its axis horizontal and its pivot offset authored |
| `PENDULUM` | A `HINGE` or `ROPE` with an authored rest position and damping |

Rules that make this shippable:

- **Solver iterations are fixed at `8` per tick.** Not adaptive. A fixed iteration count is reproducible on a given build and is what makes the reference-solution replay in §23.5 check 20 meaningful.
- **Constraint chains are capped at `4` linked constraints.** A pulley feeding a seesaw feeding a hinge is three.
- **`breakable_at` is checked once per tick** against the solver's reported constraint force. On break, the constraint is removed, `broken` is set, and both bodies keep their current velocity.
- **A broken constraint on a `required` object rebuilds** with the object at `home_transform` per §10.5.
- **Constrained objects never sleep** while their constraint value is changing by more than `0.01` per tick. This is why §5.8's save refusal exists.
- **No constraint may be created at runtime except `TETHER`.** Every other constraint is authored into the room. `ATTACH` creates a weld, which is not a constraint in the solver sense — it merges bodies.

## 14.9 Determinism

Constraint simulation is **not** bit-reproducible across platforms, and this proposal does not pretend otherwise.

What is guaranteed:

| Guaranteed | Not guaranteed |
|---|---|
| Zone composition is byte-identical from a seed (§30.5) | Object rest positions after player interaction |
| Every object's `home_transform` and initial state | The exact path an object takes |
| Every latched condition, once latched (§5.7) | Whether a marginal stack topples |
| That every mandatory puzzle has a validated solution (§23.5 check 20) | That the player's solution matches the reference |

Dungeon Authority §59 requires deterministic composition and explicitly permits runtime divergence under player action. This proposal sits exactly inside that permission, and latching is what stops divergence from becoming progression loss.

---

# 15. STATUS

Four Statuses. All change physical behavior; none deals damage. Design 1's `CONFUSED` and `TURNCOAT` are removed (§15.6).

## 15.1 The four

### `status:core:lightened` — family `KINETIC`
| Property | Value |
|---|---|
| Duration | `8.0 s` |
| Base chance | `0.40` |
| Effect | `mass_kg × 0.35`; class re-derived per §10.2 |
| Consequence | Verb eligibility widens; incoming impulse scales inversely with the new mass; wind and conveyors now affect it |
| On enemy | Same; a lightened enemy is thrown much further by `PUSH` |
| On player | Not applicable — enemies never apply Status (§32.1) |

### `status:core:anchored` — family `KINETIC`
| Property | Value |
|---|---|
| Duration | `4.0 s` |
| Base chance | `0.30` |
| Effect | `mass_kg` set to `500.0`; class becomes `FIXED` |
| Consequence | Immune to every verb, all impulse, wind, and conveyors |
| On enemy | Movement speed `0.0`; may still attack |

`LIGHTENED` and `ANCHORED` are mutually exclusive; applying either removes the other.

### `status:core:brittle` — family `KINETIC`
| Property | Value |
|---|---|
| Duration | `6.0 s` |
| Base chance | `0.35` |
| Effect | Incoming `PHYSICS`-tagged damage `×2.0`; any constraint the object participates in has its effective `breakable_at` halved |
| On enemy | Incoming `PHYSICS` damage doubled |
| On object | Makes an otherwise-unbreakable authored constraint breakable at half force, **only** where `breakable_at` was already non-null |

`BRITTLE` never makes an unbreakable constraint breakable. A `null` `breakable_at` stays null. That rule is what keeps `BRITTLE` from dismantling a room's authored structure.

### `status:core:burning` — family `THERMAL`
*Pinned: identical to Design 1 §15.1 `status:core:burning`*, including the Fire Actor mechanism that keeps the no-DoT law intact, with one addition: a `BURNING` object with `material = WOOD` has its constraints' `breakable_at` reduced by `40%` for the Status duration.

## 15.2 Application

*Pinned: identical to Design 1 §15.2.* Same formula, same clamps, same pity and adaptation, tracked per `(target_actor, status_family)`.

With only two families here — `KINETIC` and `THERMAL` — pity and adaptation cross-pollinate more aggressively than in Design 1. Failing to apply `LIGHTENED` builds susceptibility to `ANCHORED` and `BRITTLE` as well.

## 15.3 Duration, stacking, refresh

*Pinned: identical to Design 1 §15.3.*

## 15.4 Immunity and substitution

| Target | Immune to | Substitution |
|---|---|---|
| Boss | `ANCHORED` | `BRITTLE`, half duration |
| Boss | `LIGHTENED` | `BRITTLE`, half duration |
| Turret (immobile) | `ANCHORED`, `LIGHTENED` | none; attempt fails visibly |
| Fire Actor | all | none |
| `FIXED`-class object | `LIGHTENED` | none; attempt fails visibly |

## 15.5 Required feedback

*Pinned: identical to Design 1 §15.5.*

## 15.6 Why `CONFUSED` and `TURNCOAT` are cut

Both are cognitive effects that change AI targeting. In a proposal where the interesting thing to do with an enemy is *move* it, an effect that changes who it shoots competes for the same slot as an effect that changes where it is, and loses. Cutting them takes the Status catalog from six to four and removes the `COGNITIVE` family entirely, which sharpens pity and adaptation.

§41.2 records this as a sacrifice: Design 2 has no way to turn an enemy against its allies.

---

# 16. GEAR, MODS, AND RULES

*Pinned: identical to Design 1 §16.2, §16.3, §16.4, §16.5* — Mod templates, compatibility, modifier order, and runtime clamps.

## 16.1 Gear

*Pinned: identical to Design 1 §16.1* for the slot structure, tier rules, and the one-high-tier restriction.

### 16.1.1 Four replaced intrinsic templates

Design 1's territory table, with four entries changed to match this proposal's systems:

| Territory | Legal intrinsic templates |
|---|---|
| `HEAD` | `INT_MARK_ON_HIT`, `INT_OVERCRIT_ADVANCES_ABILITY`, `INT_STATUS_POTENCY`, **`INT_REVEAL_STRESS`**, `INT_CRIT_CHANCE` |
| `TORSO` | `INT_MAX_HEALTH`, `INT_BARRIER_ON_KILL`, `INT_DEFENSE`, `INT_RESOURCE_REGEN`, `INT_BARRIER_ON_DAMAGE` |
| `ARMS` | `INT_MELEE_DAMAGE`, `INT_RELOAD_SPEED`, **`INT_MANIPULATION_FORCE`**, **`INT_RELATION_COUNT`**, `INT_INTERACT_RANGE` |
| `LEGS` | `INT_MOVE_SPEED`, `INT_JUMP_HEIGHT`, `INT_MOBILITY_RECHARGE`, `INT_LANDING_CONTROL`, **`INT_IMPACT_RESISTANCE`** |

| Template | `SMALL` | `MEDIUM` | `LARGE` |
|---|---|---|---|
| `INT_REVEAL_STRESS` | Constraint force shown when within `8 m` | `18 m` | `30 m` |
| `INT_MANIPULATION_FORCE` | `+15%` force | `+35%` | `+60%` |
| `INT_RELATION_COUNT` | `+1` relation | `+1` | `+2` |
| `INT_IMPACT_RESISTANCE` | `PHYSICS` damage taken `−20%` | `−40%` | `−60%` |

Replaced: `INT_REVEAL_INTERACTABLES` (subsumed by `INT_REVEAL_STRESS`, which reveals both), `INT_HEAT_CAPACITY` (three feeds instead of four makes it narrow), `INT_PHYSICS_FORCE` (renamed and rescaled to `INT_MANIPULATION_FORCE`), and `INT_RAIL_CONTROL` (rails are less central here).

`INT_MANIPULATION_FORCE` and `RULE_MANIPULATION_FORCE` both scale force and both feed the `4000 N` ceiling in §14.4. Neither can exceed it.

---

# 17. FOREIGN ITEMS, ARCHIVE, AND MIGRATION

*Pinned: identical to Design 1 §17.1 through §17.6* — interpretation, the Epsilon request shape, duplicates, migration from existing saves, the deterministic fallback, and Archive behavior.

The only difference is the content of the enumerated lists Epsilon selects from, which are this document's §11.1, §11.3, §12.1, and §13.1 rather than Design 1's. The mechanism is identical: **Epsilon selects a named profile and never emits a number**, and the offline fallback hashes provenance into the same lists.

---

# 18. ECONOMY

*Pinned: identical to Design 1 §18.1, §18.2, §18.3.* Forge deferred, Epsilon Static banked with no sink, Coins and Signal Keys pinned to the existing implementation with no new consumer.

---

# 19. SIGNAL GRAPH

*Pinned: identical to Design 1 §19.1 through §19.6.* Four port forms, eleven node types, acyclic topological evaluation within one tick, conduits as presentation, the same persistence categories per node.

## 19.7 One addition: latched outputs

A node whose input derives from a latched condition (§5.7) reports `ON` unconditionally from the tick the latch is set. The latch is applied at step 1 of §19.3's evaluation, alongside sensor writes, so the rest of the graph sees it as an ordinary sensor value and no node type needs to know latching exists.

---

# 20. INPUTS AND SENSORS

*Pinned: identical to Design 1 §20.1 through §20.4* for the nine sensor types and their rules, including the semantic-mass rule that a plate requiring `HEAVY` is never satisfied by accumulated `LIGHT` objects.

## 20.5 Three additions

| Type | Output | Key parameters |
|---|---|---|
| `WEIGHT_THRESHOLD` | Boolean | `threshold_kg`, `accepts: list[object class]` |
| `CONSTRAINT_STATE` | Value `[0,15]` | `constraint_id`, `bucket_count` |
| `ATTACH_SENSOR` | Boolean | `attach_point_id`, `accepts_materials` |

### `WEIGHT_THRESHOLD`

Where a `PRESSURE_PLATE` reads semantic mass class, a `WEIGHT_THRESHOLD` reads actual summed `mass_kg` of qualifying objects resting on it, and emits `ON` at or above `threshold_kg`.

This is the sensor that makes counterweights work, and it is the **one place** Design 1's anti-cheese rule is deliberately relaxed: accumulated mass does count here. That is safe because the sensor is opt-in per package and because §23.5 check 21 requires every `WEIGHT_THRESHOLD` on a mandatory route to be satisfiable by a single authored object, so stacking is a shortcut and never the requirement.

### `CONSTRAINT_STATE`

Emits the named constraint's `current_value`, normalised across `limit_lower`..`limit_upper` and quantised into `bucket_count` buckets in `[0, 15]`. This is how a seesaw's angle or a pulley's extension drives a `SELECTOR` or `THRESHOLD` node.

Quantisation matters: a continuous constraint value driving a continuous signal would make puzzle state depend on float precision the simulation does not have. Buckets make the readout stable.

### `ATTACH_SENSOR`

Emits `ON` while its attach point's `occupied_by` is non-null and the occupying object's `material` is in `accepts_materials`.

---

# 21. ACTUATORS AND MACHINERY

*Pinned: identical to Design 1 §21.1, §21.1.1, §21.2 through §21.9* — the common contract, the per-kind power-loss table, and all nine actuator kinds. Actuators remain **kinematic**; they move along authored paths and are not solver bodies.

## 21.10 Constraint-driven machinery — new to Design 2

Three additions, which are the reason this proposal ships constraints at all.

| Kind | Behavior |
|---|---|
| `WINCH` | Shortens or lengthens a named `ROPE`, `CHAIN`, or `PULLEY` constraint at `rate_m_per_s` while its input is `ON`, between `length_min` and `length_max` |
| `BRAKE` | Locks a named `HINGE`, `SLIDER`, or `SEESAW` at its current value while its input is `ON`; releases on `OFF` |
| `DRIVER` | Applies torque to a named `HINGE` toward `target_value` at `rate_rad_per_s` while its input is `ON` |

These are the bridge between the signal graph and the solver: a signal can now change a simulated mechanism, not just move a kinematic platform.

Rules:

- All three obey Design 1 §21.1's transition table, including holding position on power loss.
- A `WINCH` at `length_min` or `length_max` stops and holds; it does not wrap or error.
- A `BRAKE` engaging mid-swing locks at the current value, whatever it is. It does not snap to a limit.
- A `DRIVER` applies torque, not position. It can be resisted by mass and it can stall. A stalled `DRIVER` holds torque and reports stalled to the debug overlay (§36).
- **None of the three may be the only mechanism on a mandatory route unless its package records a validated reference solution** (§23.5 check 20), because all three interact with a solver whose outcome the validator cannot compute analytically.

---

# 22. HACKING

*Pinned: identical to Design 1 §22.1, §22.2, §22.3.* One reusable route-connection minigame, three difficulties, no timer, no failure state, exits preserve tile rotations.

Hacking is unchanged because it is a signal-layer mechanism and this proposal's thesis is about the physical layer. Reinventing it would add difference without adding meaning.

---

# 23. PUZZLE-PACKAGE CONTRACT

## 23.1 Manifest

Design 1 §23.1's shape, with four added fields:

```
PackageManifest:
  id                  : Id
  family              : one of the sixteen in §24
  required_offers     : list[OfferRequirement]
  objects             : list[ObjectPlacement]
  nodes               : list[NodePlacement]
  actuators           : list[ActuatorPlacement]
  constraints         : list[ConstraintSpec] = []      # NEW
  reset_group         : Id
  persistence         : enum { PUZZLE_LOCAL, ROOM_PERSISTENT }
  capability_required : Id? = null
  physics_permitted   : bool = true                    # default inverted vs Design 1
  reference_solution  : ReferenceSolution? = null      # NEW, required per §23.5 check 20
  latch_conditions    : list[LatchCondition]           # NEW
  settle_timeout      : Seconds = 8.0                  # NEW
  optional_solutions  : list[enum { PHYSICS, MOBILITY, COMBAT, ALTERNATE_INPUT }] = []
  timing_window       : Seconds? = null
  budget              : PackageBudget

LatchCondition:
  index               : int >= 0
  expression          : signal node Id                 # the node whose ON latches
  latches             : bool = true                    # false only for A_B_STATE

ReferenceSolution:
  steps               : list[SolutionStep], length 1..12
  max_duration        : Seconds

SolutionStep:
  verb                : enum { MOVE_TO, PUSH, PULL, HOLD, ROTATE, ATTACH,
                               INTERACT, SHOOT, WAIT }
  target              : Id?          = null
  destination         : transform?   = null
  force               : float?       = null
  duration            : Seconds?     = null

PackageBudget:
  max_rigid_bodies    : int <= 40      # Design 1: 12
  max_constraints     : int <= 8       # NEW
  max_actuators       : int <= 6
  max_nodes           : int <= 20
  max_signal_updates  : int <= 40
```

`settle_timeout` is the time the validator allows a package's objects to come to rest from their initial state before declaring the package unstable (§23.5 check 22). A package whose initial configuration is still moving after `8.0 s` is a package that will not reproduce and is rejected.

## 23.2 Room offers

*Pinned: identical to Design 1 §23.2*, with the offer types in §28.7.

## 23.3 Completion and AP

*Pinned: identical to Design 1 §23.3.* Completion drives a signal; it never awards AP directly, and a package is never itself a Check.

## 23.4 Reset

Design 1 §23.4's ordered restore, with physical steps inserted:

1. Actuators move to `initial_t`.
2. `PUZZLE_LOCAL` nodes return to authored initial state.
3. **Every constraint is destroyed.**
4. **Every attachment is separated.**
5. Carryables and physical objects return to `home_transform` with zero velocity and `sleeping = true`.
6. **Every authored constraint is rebuilt, in manifest order.**
7. Sockets empty.
8. Destructibles respawn.
9. Hazards return to their initial phase.

Steps 3 and 6 bracket the position restore for the reason given in §5.9: constraints rebuilt around objects already in place produce no corrective impulse, while constraints left in place during a teleport produce a large one.

**Reset never clears a latch** (§5.7 rule 4), and never touches confirmed Checks, `ROOM_PERSISTENT` flags, opened shortcuts, Zone flags, or encounter cleared-flags.

## 23.5 Validation pipeline

Design 1 §23.5's eighteen checks, all retained, plus four:

| # | Check |
|---|---|
| 1–18 | *Pinned: identical to Design 1 §23.5.* |
| **19** | **No latch condition depends on a physical quantity finer than `0.05 m` positional or `0.05 rad` angular.** A puzzle whose correctness turns on precision the simulation does not reproduce is rejected. |
| **20** | **Every package with `capability_required = manipulate`, or containing a `WINCH`, `BRAKE`, or `DRIVER` on a mandatory route, has a `reference_solution`, and replaying it from the initial state latches every `latch_condition` within `max_duration`.** The replay runs headless at fixed `8`-iteration solver settings, three times; all three must latch. |
| **21** | **Every `WEIGHT_THRESHOLD` on a mandatory route is satisfiable by a single authored object present in the room**, so stacking is a shortcut and never the requirement. |
| **22** | **The package's initial configuration reaches `sleeping = true` on every object within `settle_timeout`.** |

Check 20 is the expensive one and the one that makes mandatory manipulation defensible. It is a headless physics replay per package per composition, which is why Zones are shorter here (§30.2) and why composition is slower than Design 1's.

Running it three times rather than once catches configurations that are marginal — a stack that settles two times in three is not a puzzle, it is a coin flip, and check 22 plus a three-run check 20 rejects it.

## 23.6 Deterministic failure

*Pinned: identical to Design 1 §23.6.* Logged with package ID, shell ID, failing check number, and seed; the generator retries per §30.7.

---

# 24. THE SIXTEEN PUZZLE FAMILIES

Seven pinned from Design 1, nine new. Design 1's `CARRY_TO_PLATE`, `TIMED_TRAVERSE`, `BOMB_BARRIER`, `OBSERVATION_TARGET`, `LOCAL_KEY_LOOP`, and `MULTI_STAGE_MACHINE` are absorbed or replaced as noted.

| # | Family | Shape | Origin |
|---|---|---|---|
| 1 | `PUSH_TO_PLATE` | Push a `WEIGHTED` object onto a plate | replaces `CARRY_TO_PLATE` |
| 2 | `INSERT_COMPONENT` | Carryable component → socket → output | *pinned from Design 1 §24* |
| 3 | `PULSE_REMOTE` | Button → output | *pinned from Design 1 §24* |
| 4 | `SHOOT_TARGET` | Shootable target → output | *pinned from Design 1 §24* |
| 5 | `TOGGLE_ROOM_STATE` | Lever → persistent room transformation | *pinned from Design 1 §24* |
| 6 | `HACK_OVERRIDE` | Terminal → signal or route change | *pinned from Design 1 §24* |
| 7 | `DUAL_INPUT` | Two inputs → `AND` → output | *pinned from Design 1 §24* |
| 8 | `ENCOUNTER_GATE` | Encounter-clear → output | *pinned from Design 1 §24* |
| 9 | `A_B_STATE` | Lever toggles linked architecture; `latches = false` | *pinned from Design 1 §24* |
| 10 | **`COUNTERWEIGHT_LIFT`** | Load a counterweight past a `WEIGHT_THRESHOLD` to raise a platform | new |
| 11 | **`SEESAW_ROUTE`** | Shift mass across a seesaw to create a walkable angle | new |
| 12 | **`PENDULUM_TIMING`** | Release or brake a pendulum to pass a gap or strike a target | new |
| 13 | **`BRIDGE_ASSEMBLY`** | Attach girders across authored attach points to span a gap | new |
| 14 | **`WINCH_HAUL`** | Drive a winch to haul a load into position | new |
| 15 | **`TETHER_ROUTE`** | Tether two objects so one constrains or carries the other | new |
| 16 | **`MASS_GATE`** | Lighten or anchor an object so a mechanism can or cannot move it | new |

`BOMB_BARRIER` is absorbed into `PUSH_TO_PLATE` and `MASS_GATE` — a reactive barrel is an object you position. `OBSERVATION_TARGET` is cut because Design 2's rooms already require reading physical relationships. `LOCAL_KEY_LOOP` and `MULTI_STAGE_MACHINE` are cut as families and remain expressible as compositions of the sixteen; Design 1 kept them as named families and Design 2 does not, which is a real reduction in generation vocabulary that §41.2 records.

**Not shipped:** `ENERGY_ROUTE`, `BEAM_RECEIVER`, `ROUTE_SWITCH`, `MOVING_MACHINE`, `DUNGEON_STATE_CHANGE` as a physical family. Zone flags still exist (§28.3) and are set by signal packages.

---

# 25. HAZARDS AND DESTRUCTION

*Pinned: identical to Design 1 §25.0 through §25.5* — six material traits, the hazard contract, six hazard families, four destructible classes, environmental kill credit, and the enemy-participation table.

## 25.6 Two additions

| Family | `damage` | `tick_interval` | `telegraph` | Notes |
|---|---:|---:|---:|---|
| `SWINGING_LOAD` | per §14.7 | `0.0` | `1.5` | A `PENDULUM`-constrained mass. Damage is impact damage, not a fixed value, so a slow swing is survivable and a fast one is not. |
| `COLLAPSING_STACK` | per §14.7 | `0.0` | `1.0` | An authored stack whose supporting object is destructible; collapse is simulated, not scripted |

Both compute damage through §14.7 rather than declaring a number, which is the first time a hazard's damage is emergent. The telegraph requirement still applies: `SWINGING_LOAD` telegraphs by being visibly in motion, and check 16 measures the time between it becoming dangerous and it reaching the player's position, not a scripted wind-up.

## 25.7 Environmental kill credit

*Pinned: identical to Design 1 §25.4*, with the causation window extended from `5.0 s` to `4.0 s` for consistency with §14.7's provenance rule, and one added cause:

- the player attached, detached, tethered, or broke a constraint that put the hazard in motion.

---

# 26. ROUTING, FORCES, AND CONSTRAINTS

*Pinned: identical to Design 1 §26.1 (power), §26.2 (wind), §26.3 (conveyors and cargo), §26.4 (player rails).*

Wind's mass-class response table is unchanged, which now has more consequence: a `LIGHTENED` `BALLAST` becomes wind-affected, and an `ANCHOR_FIELD` is how a player stops a light object from being blown off a ledge.

## 26.5 Constraints

**This is what Design 1 deferred and Design 2 ships.** The eight kinds, their solver treatment, the fixed `8`-iteration budget, the `4`-constraint chain cap, `breakable_at` handling, and the no-runtime-creation rule are all specified in §14.8.

A crane in Design 2 is a `PULLEY` with a load on one end and a `WINCH` driving it. Its cargo swings. Design 1's crane was a `PATH_MACHINE` whose cargo was a child transform and could not swing. That is the single most visible difference between the two proposals in play.

---

# 27. MEDIA

*Pinned: identical to Design 1 §27.1 (shallow water only), §27.2 (light), §27.3 (sound), §27.4 (deferred media).*

## 27.5 Local gravity volumes — new to Design 2

A gravity volume scales `GRAVITY` for eligible bodies inside it.

| Property | Value |
|---|---|
| Scale range | `0.25` to `2.00` |
| Affects | Physical objects always; the player only if `affects_player` is true |
| Direction | Always down. Directional gravity is deferred (§2.2). |
| Player effect | `JUMP_APEX` and fall speed scale; `WALK_SPEED` and air control do not |
| Transition | Linear blend over `0.5 s` on entry and exit |

**A mandatory route may never depend on a gravity volume with `affects_player = true`.** Validators compute reachability from the movement law in Design 1 §6.2, which assumes `GRAVITY = 22.0`, and a route that requires low gravity would be certified against the wrong constants. Player-affecting volumes are optional-route content only, and check 13 rejects any mandatory route passing through one.

Object-affecting volumes may be mandatory, because check 20's reference-solution replay exercises them directly.

---

# 28. ROOM AND ZONE TOPOLOGY

*Pinned: identical to Design 1 §28.1 through §28.7* — room-local transformations, one-way shortcuts, four forward-only Zone flags, cross-room effect only through flags, local keys, secrets, and the twenty offer types.

Zone flags remain forward-only monotonic Booleans. A physics-centric proposal does not make dungeon macro-state cyclic; that is Design 3's thesis, not this one.

## 28.8 Two added offer types

`constraint_anchor` — a world point a package may anchor an authored constraint to.
`attach_surface` — a surface a package may place attach points on.

---

# 29. CAPABILITY PROGRESSION

## 29.1 The five capabilities

Design 1's four, plus one.

| Capability | Satisfied by | Guaranteed |
|---|---|---|
| `capability:core:ranged_hit` | Static Pulse | **Always** |
| `capability:core:grapple` | Any `GRAPPLE` Mobility | Only by proof |
| `capability:core:blink` | Any `BLINK` Mobility | Only by proof |
| `capability:core:long_gap` | `DASH` ≥ `8.0 m`, or `BURST_JUMP` ≥ `9.0 m/s` | Only by proof |
| **`capability:core:manipulate`** | **Any `PHYSICS_VERB` Ability whose verb is `PUSH`, `PULL`, or `HOLD`** | **Only by proof** |

`ALIGN`, `ROTATE`, `TETHER`, `PIN`, `ATTACH`, `DETACH`, the two fields, and `SETTLE` **do not** grant `manipulate`. Only the three verbs that move an object from one place to another do, because those are the three a required solution may use (§14.5 rule 3) plus `ROTATE`, and `ROTATE` alone cannot reposition anything.

## 29.2 Proof

*Pinned: identical to Design 1 §29.2.* Either the committed Loadout contains a granting host, or AP logic guarantees one is received before this Zone becomes accessible. No in-Zone capability acquisition.

## 29.3 The `manipulate` contract

A mandatory manipulation requirement is validated against the **least capable granting profile**, which is `ab_physics_light`: `700 N`, `20.0 m` range, `120 kg` verb mass limit.

Consequently a mandatory manipulation puzzle may require moving an object of at most `120 kg`, at a range of at most `20.0 m`, with at most `700 N` of force available. Anything heavier, further, or stiffer is optional-route content.

`700 N` on a `120 kg` object is `5.83 m/s` of impulse, which moves it several metres on a flat floor. That is the design envelope for required physics, and it is deliberately modest.

## 29.4 Entry validation

*Pinned: identical to Design 1 §29.3.* Requirements are shown before entry and block it, with the §34.4 message listing qualifying Archive entries.

## 29.5 Optional routes

*Pinned: identical to Design 1 §29.4.* Optional routes may require anything, are never validated for reachability, and sequence-breaking them is welcome.

This matters more here than in Design 1. A player who stacks a `PLATE` on a `DRUM` and a `GIRDER` on both to reach an optional ledge has done exactly what this proposal is for, and nothing defends against it.

---

# 30. PROCEDURAL COMPOSITION

## 30.1 What Epsilon chooses

*Pinned: identical to Design 1 §30.1.* Nothing in Zone composition. Composition is deterministic and bridge-owned; Epsilon's only role is item interpretation.

## 30.2 Zone shape

A linear spine of **6 to 11** rooms, against Design 1's 8 to 16.

| Property | Value |
|---|---|
| Spine length | `6` to `11` rooms |
| Branches | `0` to `2`, each `1` room, each on a distinct spine room |
| Branch content | Optional Checks, secrets, rewards. Never spine-mandatory. |
| Loops | None. The graph is a tree. |
| Authored-shell reuse within a Zone | At most `2` rooms may share a shell |

Zones are shorter because check 20's physics replay makes composition expensive, and because a physics room carries more content per room than a signal room. The Check budget is unchanged, so Checks are denser.

## 30.3 Composition algorithm

Design 1 §30.3's eleven steps, with three changes:

- Step 2 becomes `spine_length = 6 + rng.int(0, 5)`.
- Step 6's per-room package attempt limit drops from `12` to `8`, because each attempt may now run a physics replay.
- A new step 6a: **after all packages are placed in a room, run a whole-room settle test** — simulate `settle_timeout` seconds from the room's initial state and require every object to reach `sleeping = true`. A room that fails is retried as a whole, up to `3` times, before `FAIL_ROOM`.

`PURPOSE_ROTATION` becomes:

`[traversal, physical_puzzle, arena, physical_puzzle, junction, ranged_arena, physical_puzzle, vertical_ascent, holdout, physical_puzzle, boss_arena]`

Eleven entries for a maximum spine of eleven. `PACKAGE_DENSITY`: `physical_puzzle` `2`, `junction` `2`, `traversal` `1`, arena purposes `1`, `boss_arena` `0`. `ENCOUNTER_BUDGET` — *pinned: identical to Design 1 §30.3.*

## 30.4 Whole-Zone audit

Design 1 §30.4's eight checks, plus:

| # | Check |
|---|---|
| **9** | **Total rigid bodies across the three loaded rooms is at most `90`, and total constraints at most `20`.** |
| **10** | **Every mandatory manipulation requirement in the Zone is satisfiable by `ab_physics_light` per §29.3.** |
| **11** | **No room contains more than `20` protected bodies** — `required` objects plus bodies participating in a constraint — leaving at least `4` of the `24` non-sleeping budget always available to unprotected bodies. |

## 30.5 Determinism

*Pinned: identical to Design 1 §30.5* for the three independent RNG streams and byte-identical composition.

Composition determinism is unaffected by simulation non-determinism, because composition produces initial states and the settle test in step 6a is run at fixed solver settings on the composing machine. A room that settles on the build machine and diverges on a player's machine is possible in principle; check 22's `8.0 s` margin and check 20's three-run requirement are what make it improbable, and §14.9 states plainly that this is a probabilistic guarantee rather than an absolute one.

## 30.6 Checkpoints

*Pinned: identical to Design 1 §30.6*, with §5.8's save-refusal interaction: a checkpoint retries every `0.5 s` while the player remains in its volume, so a checkpoint entered while objects are still moving activates a moment later rather than being missed.

## 30.7 Retry and fallback

*Pinned: identical to Design 1 §30.7*, with the room-level settle retry from §30.3 step 6a inserted before `FAIL_ROOM`.

The certified fallback Zone is Design 2's own (§37 fixture 17), not Design 1's.

## 30.8 Physical authority

*Pinned: identical to Design 1 §30.8*, with §3.6's addition: where simulation and semantic state disagree, semantic state wins for progression and simulation wins for everything else.

---

# 31. CROSS-SYSTEM COMPATIBILITY

## 31.1 The matrix

*Pinned: identical to Design 1 §31*, with these rows changed or added:

| A × B | Result |
|---|---|
| Physics × `required` object | **Permitted by default**; forbidden only where `physics_permitted = false` |
| Physics × enemy | `PUSH`, `PULL`, `PIN`, `LIGHTEN_FIELD`, `ANCHOR_FIELD` only |
| Physics × boss | No effect |
| Physics × player | No effect, ever |
| **`LIGHTENED` × `WEIGHT_THRESHOLD`** | **Threshold reads the reduced `mass_kg`** |
| **`ANCHORED` × any verb, wind, conveyor, impulse, constraint** | **No effect on the target; a constraint attached to it goes taut** |
| **`BRITTLE` × constraint with non-null `breakable_at`** | **Effective `breakable_at` halved** |
| **`BRITTLE` × constraint with null `breakable_at`** | **No effect** |
| **`BURNING` × `WOOD` object's constraints** | **`breakable_at` reduced `40%` for the duration** |
| **Attachment × constraint** | **The assembly inherits the constraint of whichever member was constrained first** |
| **`ATTACH` × attach point already `occupied_by`** | **Rejected; §34.9 feedback** |
| **Gravity volume × player** | **Only where `affects_player`, and never on a mandatory route** |
| **`SETTLE` × constrained object under `WINCH`/`DRIVER` drive** | **No effect while driven** |
| **Explosion × constraint** | **Applies force; may exceed `breakable_at` and break it** |

## 31.2 Relation exclusivity

A single object may be under at most **one** player relation at a time. Activating a second relation on an object already held, pinned, or tethered by the player releases the first. This is separate from `max_relations`, which caps relations across *different* objects.

## 31.3 The weapons-remain-dominant invariant

Player Authority §30.18 rejects physics as dominant damage. A proposal that doubles the impact ceiling owes a demonstration, not an assurance.

**The invariant:** for every enemy archetype, time-to-kill using Weapons must be strictly lower than time-to-kill using manipulation, under any legal loadout.

**Why it holds structurally.** Physics damage is gated by ability recharge; Weapon damage is gated by fire rate. Those differ by an order of magnitude.

Worked, at the most favourable physics numbers this document permits:

| | |
|---|---|
| Maximum manipulation force after all modifiers (§14.4) | `4000 N` |
| Heaviest useful object | `260 kg` (`ab_physics_standard` limit) |
| Resulting impulse | `4000 / 260 = 15.4 m/s` |
| `mass_factor` at `260 kg` | `260/40 = 6.5`, clamped to `4.0` |
| Impact damage (§14.7) | `(15.4 − 6.0) × 4.0 = 37.6` |
| Best ability recharge | `cd_single_short`, `6.0 s` |
| **Sustained physics DPS** | **`6.3`** |
| `cadence_standard` Weapon | `18.0` per `0.28 s` |
| **Sustained Weapon DPS** | **`64.3`** |

Weapons out-damage manipulation by roughly **ten to one**, and the ratio holds across every profile because the recharge economy — not the impact ceiling — is the binding constraint. Reaching the `90.0` ceiling requires a `400 kg` object at `28.5 m/s`, which needs `11,400 N`, nearly three times the ceiling. **The `90.0` cap is unreachable by player action** and exists only to bound constraint- and gravity-driven impacts, which is where it actually applies.

Test vector 96 measures this, and check 23 below enforces it at composition.

**Check 23**, added to §23.5: no encounter may be composed such that the physics-only time-to-kill is lower than the Weapon-only time-to-kill for any enemy in it. In practice this is satisfied automatically and the check exists to catch a future tuning pass that breaks it.

The reason to reposition an enemy is never that the throw kills them. It is that they are now in the flame jet, off the ledge, out of cover, or pinned in your firing line — and then your Weapon kills them.

---

# 32. ENEMIES AND ENCOUNTERS

## 32.1 Minimum enemy contract

Design 1 §32.1's interface, with two added fields:

```
Enemy:
  id                : Id
  archetype         : one of §32.2
  health            : Damage
  defense           : float
  faction           : Faction
  mass_kg           : float > 0.0        # NEW — enemies are physical objects
  mass_class        : MassClass          # derived per §10.2
  status_resistance : float in [0.0, 0.40]
  statuses          : list[active Status]
  ai_state          : enum { IDLE, ENGAGED, PANIC, STUNNED, DISPLACED, DEAD }
  target            : Id?
  grounded          : bool               # NEW
```

Enemies never apply Status to the player — *pinned reasoning from Design 1 §32.1*.

`DISPLACED` is new: an enemy under player-applied impulse above `4.0 m/s` enters `DISPLACED`, cannot act, and returns to `ENGAGED` on the first tick it is grounded and below `1.0 m/s`. This is what makes shoving an enemy a real tempo tool rather than a cosmetic nudge, and it is bounded — `DISPLACED` cannot chain, because a second impulse while already `DISPLACED` extends nothing.

## 32.2 Archetypes

Design 1's six, with masses assigned:

| Archetype | Health | Defense | `mass_kg` | Class | Status resist | Behavior |
|---|---:|---:|---:|---|---:|---|
| `SKIRMISHER` | `60` | `0` | `85` | `MEDIUM` | `0.00` | Closes to `8 m`, hitscan bursts |
| `BRUISER` | `180` | `0` | `240` | `HEAVY` | `0.15` | Closes to melee, high contact damage |
| `ARMORED` | `140` | `100` | `300` | `HEAVY` | `0.20` | Slow advance, sustained fire |
| `FLYER` | `45` | `0` | `25` | `LIGHT` | `0.00` | Hovers at `6 m`; **`grounded` is always false** |
| `TURRET` | `90` | `50` | `600` | `FIXED` | `0.40` | Immobile, `40 m` range |
| `BOSS` | `1800` | `150` | `2000` | `FIXED` | `0.40` | Three phases; responds to no verb |

`FLYER` at `25 kg` is the lightest thing in the game and is trivially thrown, which is intentional: it is the archetype that most rewards manipulation, and it is also the one that makes `AIRBORNE_KILL` achievable. `TURRET` and `BOSS` are `FIXED` and immovable.

## 32.3 Faction behavior

Design 1 §32.3's table, minus the `TURNCOAT` and `CONFUSED` rows (both Statuses are cut, §15.6):

| Situation | Behavior |
|---|---|
| `HOSTILE` default | Targets the player |
| Enemy damages enemy | Full damage, no retaliation state change |
| Enemy killed by environment | Credit per §25.7 |

## 32.4 Status- and physics-compatible AI

| Condition | AI response |
|---|---|
| `BURNING` | `PANIC` for the duration; no attacks, randomised movement |
| `LIGHTENED` | No AI change; physical response only |
| `ANCHORED` | Movement `0`; attacks continue if in range |
| `BRITTLE` | No AI change |
| `DISPLACED` | No actions until grounded and below `1.0 m/s` |
| Under `PIN` | Movement `0`; attacks continue if in range; identical to `ANCHORED` behaviourally |
| Airborne from impulse | `DISPLACED` |

Enemy pathfinding treats physical objects as dynamic obstacles, re-queried at `4 Hz`. An enemy whose path is blocked by an object the player just moved re-routes within `0.25 s`. It never pushes objects itself — enemies are moved by physics but never move objects, which keeps every physical configuration the player's responsibility and keeps §25.5's "no required progression depends on enemy behavior" true.

## 32.5 Encounters

*Pinned: identical to Design 1 §32.5.* Waves, triggers, clear conditions, and the `ROOM_PERSISTENT` cleared-flag.

## 32.6 Death, drops, respawn

*Pinned: identical to Design 1 §32.6.* Enemies never respawn once cleared; an uncleared encounter respawns in full on re-entry.

## 32.7 Boss encounters

*Pinned: identical to Design 1 §32.7*, with the addition that a boss arena's packages are restricted to families 3, 4, 7, and 8 — the signal families. A boss arena contains no physics puzzle, because a solver under encounter load is where the performance budget breaks.

---

# 33. HUD AND PRESENTATION

*Pinned: identical to Design 1 §33.1, §33.3, §33.5, §33.6* — the always-visible list, the three recharge display treatments, causality feedback, and the colour rules.

## 33.2 Feed display by model

Design 1 §33.2's table without the `CHARGE` row:

| Model | Display |
|---|---|
| `MAGAZINE` | `rounds / capacity`; reload shows a progress arc |
| `HEAT` | Bar filling toward `heat_max`; lockout crosshatch with countdown |
| `NONE` | **Nothing.** No bar, no counter, no placeholder. |

## 33.4 Device presentation

*Pinned: identical to Design 1 §33.4*, with one addition: the device visibly indicates the active manipulation relation. A `HOLD` shows a tether line from device to object; a `PIN` shows a static marker; a `TETHER` shows the rope. Presentation never decides an outcome.

## 33.7 Physical state readability — new to Design 2

The player must be able to read the physical situation without experimenting. Required, always:

| State | Presentation |
|---|---|
| Manipulable vs not | Manipulable objects have a consistent material treatment; `FIXED` objects visibly do not share it |
| Currently held | Outline plus the device tether line |
| Currently pinned | Static corner markers, distinct from the hold outline in shape |
| Currently tethered | The rope renders; tension is shown by rope straightness and a pitch-shifted hum |
| Constraint under stress | Progressive visual strain on the constraint at `60%`, `80%`, and `95%` of `breakable_at`, each distinct in pattern and audio, not only in colour |
| Approaching `breakable_at` | The `95%` state adds an audible creak that rises in rate |
| Mass class | Object silhouette scale conventions per class, plus a heft cue on impact audio |
| `LIGHTENED` / `ANCHORED` | Distinct particle treatment and a change in impact audio pitch |
| Attach point available | Visible marker when within `6 m`, brighter when the carried object's material is accepted |
| Attach point occupied | Marker changes shape, not only colour |

The constraint-stress display is the one that matters most and is easiest to skip. A player who cannot tell that a rope is about to break cannot plan around it, and a rope that breaks without warning reads as the game cheating.

---

# 34. PLAYER-FACING FLOW

*Pinned: identical to Design 1 §34.1 through §34.6, §34.8, §34.10, §34.11, §34.12* — first run, the Hub, receiving an item, Zone entry, Archive and equip, invalid-loadout messages, binding conflicts, leaving a Zone, the read-only in-excursion Archive, and the migration notice.

## 34.7 Manual save refused

Two reasons now, with distinct messages:

> **Cannot save right now.** Finish the encounter first.

> **Cannot save right now.** Wait for everything to settle.

The second is §5.8's physics refusal. It names the reason rather than saying "try again", and the HUD highlights the objects still in motion so the player knows what they are waiting for.

## 34.9 Rejection feedback

Design 1 §34.9's table, plus the manipulation rejections:

| Refusal | Feedback |
|---|---|
| Ability not ready | HUD entry flashes; audio; readiness element highlights |
| Resource insufficient | Resource number flashes and the bar pulses |
| **No eligible manipulation target** | **Crosshair rejection mark; any ineligible object under the crosshair outlines in the ineligible treatment for `0.4 s`** |
| **Target too heavy for this verb** | **Crosshair rejection mark plus a mass indicator on the target showing its `mass_kg` against the verb's limit** |
| **`max_relations` reached** | **The oldest relation's marker pulses to show what would be released** |
| **Attach point occupied** | **The point's marker flashes; the occupying object outlines** |
| **Attachment chain at `4`** | **The whole chain outlines with a count indicator** |
| **Tether beyond `max_length`** | **The attempted rope renders in the rejected treatment for `0.4 s`** |
| No valid Mobility destination | Rejection mark; attempted destination outlined for `0.4 s` |
| Weapon empty | Empty-click audio; magazine counter flashes |
| Weapon in lockout | Heat bar pulses; countdown emphasised |
| Socket incompatible | Socket flashes; prompt was already disabled |
| Interactable disabled | Prompt shows `disabled_reason` |
| **`F` suppressed while holding** | **No prompt is shown at all (§7.5)** |

The "too heavy" rejection showing an actual number is deliberate. In a game where mass is the central quantity, the player needs to learn the mass vocabulary, and the fastest way to teach it is to show the number at the moment it mattered.

---

# 35. PERFORMANCE BUDGETS

Substantially tighter than Design 1's, and enforced at composition rather than hoped for at runtime.

| Quantity | Budget | Design 1 |
|---|---:|---:|
| Active rigid bodies per loaded room | `40` | `12` |
| Active rigid bodies across all loaded rooms | `90` | `36` |
| **Active constraints per room** | **`8`** | — |
| **Active constraints across all loaded rooms** | **`20`** | — |
| **Solver iterations per tick** | **`8`, fixed** | — |
| **Simultaneous non-sleeping bodies** | **`24`** | — |
| Loaded rooms | `3` | `3` |
| Live projectiles, all sources | `48` | `64` |
| Live projectiles per Weapon | `18` | `24` |
| Actuators per room | `6` | `6` |
| Signal nodes per room | `20` | `20` |
| Active enemies | `10` | `12` |
| Active hazard volumes per room | `8` | `8` |
| Fire Actors per room | `4` | `6` |
| Player relations held | `3`, up to `6` with `RULE_RELATION_COUNT` | `2` |
| Player-created tethers | `3` | — |

Rules:

- **The `24` non-sleeping cap is enforced by forced sleep**: if a 25th body would be awake, the body that has been awake longest and is not `required`, not constrained, and not under a player relation is put to sleep in place. This is visible as a decorative object stopping abruptly, which is the least-bad failure mode available.
- **If no unprotected candidate exists**, nothing is forced to sleep and the cap is exceeded for that tick. This is reachable only if a room holds more than `24` protected bodies at once, which §30.4 check 11 forbids at composition — so it is a defect rather than a gameplay state, and the debug overlay (§36) reports it. Degrading gracefully rather than sleeping a required object is deliberate: a forced-sleep on a required or constrained body would freeze a puzzle mid-solution, which is worse than a dropped frame.
- Sleep thresholds are `1.5 s` below `0.05 m/s` linear and `0.10 rad/s` angular (§5.8).
- Constrained objects never sleep while their constraint value changes by more than `0.01` per tick.
- Signal evaluation is event-driven — *pinned: identical to Design 1 §35.*
- Projectile budgets are lower than Design 1's because the physics solver takes the headroom.

---

# 36. DEBUGGING AND INSPECTION

*Pinned: identical to Design 1 §36* for all fourteen inspectables, plus:

| Inspectable | Content |
|---|---|
| Constraints | Every constraint's kind, anchors, `current_value`, limits, live solver force, and force as a fraction of `breakable_at` |
| Attachment graph | Every attachment, chain lengths, and each assembly's summed mass |
| Relations | Every active player relation, its verb, its target, and its age |
| Sleep state | Every body's sleeping flag, time awake, and whether it is a forced-sleep candidate |
| Mass | Every object's base `mass_kg`, current `mass_kg` after Statuses and fields, and derived class |
| Latches | Every latched condition, its package, and the ordinal it latched at |
| Settle | Live settle test: time since the room's last full sleep, and which bodies are preventing it |
| Reference solutions | For any package with one, the recorded steps and a replay control |

The replay control is the one an implementer will actually live in: being able to re-run check 20 against a live room is what makes a failing physics puzzle diagnosable rather than mysterious.

---

# 37. REFERENCE FIXTURES

One per family, plus the certified fallback Zone. Each is a checked-in scene that passes every §23.5 check, with real coordinates and a recorded reference solution where §23.5 check 20 requires one.

All fixtures use a `24 × 24 × 8 m` test shell with entry at `(0, 0, 0)`, `+Y` up. Larger than Design 1's `20 × 20 × 6` because constraint mechanisms need vertical room.

| # | Fixture | Layout | Reference solution | Latches |
|---|---|---|---|---|
| 1 | `fx_push_to_plate` | `WEIGHTED` (`140 kg`) at `(4,0,3)`; plate at `(14,0,9)` accepting `HEAVY`; door at `(22,0,12)` | `PUSH` twice at `700 N` along `+X`, then once along `+Z` | Plate `ON` |
| 2 | `fx_insert_component` | `POWER_CELL` (`40 kg`) at `(3,0,3)`; socket at `(17,2,10)`; ramp from `(15,0,10)` at `26°` | Carry up ramp, `F` to insert | Socket occupied |
| 3 | `fx_pulse_remote` | Button `(5,0,5)`; `TIMER` `4.0 s`; bridge over a `3.5 m` gap at `(12,0,12)` | Press, cross | Bridge extended |
| 4 | `fx_shoot_target` | Target at `(20,5,20)`, `28.9 m` from entry, `required_tags [RANGED]` | Static Pulse | Target struck |
| 5 | `fx_toggle_room_state` | Lever `(4,0,4)`; two bridge groups | Throw lever | Room state B |
| 6 | `fx_hack_override` | Terminal difficulty 2, `VALUE` mode at `(6,0,6)`; `SELECTOR` ×3 | Hack to value 2 | Door 2 open |
| 7 | `fx_dual_input` | Plate `(6,0,4)` + `WEIGHTED` at `(3,0,3)`; lever `(16,0,4)`; `AND` | `PUSH` cube to plate, throw lever | Both inputs |
| 8 | `fx_encounter_gate` | 2 `SKIRMISHER`, 1 `FLYER`, one wave | Clear it | Encounter cleared |
| 9 | `fx_a_b_state` | Lever toggles platform groups A/B; `latches = false` | Toggle mid-route | **Does not latch** |
| 10 | `fx_counterweight_lift` | `PULLEY` at `(12,7,12)`; platform (`200 kg`) one end, basket other; `WEIGHT_THRESHOLD` `300 kg` on the basket; two `BALLAST` (`320 kg`) at `(5,0,5)` and `(7,0,5)` | `PUSH` one `BALLAST` into the basket; platform rises to `+4.2 m` | Threshold `ON` |
| 11 | `fx_seesaw_route` | `SEESAW` pivot at `(12,1,12)`, beam `10 m`, limits `±22°`; `BALLAST` at `(6,0,12)` | `PUSH` `BALLAST` to the far arm; walk the resulting `−18°` incline | `CONSTRAINT_STATE` bucket ≥ 12 |
| 12 | `fx_pendulum_timing` | `PENDULUM` from `(12,7,6)`, `250 kg` bob, `5 m` rope; `BRAKE` on a button; gap `(12,0,10)`→`(12,0,15)` | `ROTATE` to swing, `BRAKE` at extent, cross beneath | Gap crossed sensor |
| 13 | `fx_bridge_assembly` | Two `GIRDER` (`95 kg`) at `(4,0,8)` and `(4,0,10)`; attach points at `(10,2,12)` and `(16,2,12)`; gap `6 m` | `HOLD` girder 1, `ATTACH` at first point; repeat for girder 2 | Both `ATTACH_SENSOR` |
| 14 | `fx_winch_haul` | `WINCH` at `(18,6,18)` on a `ROPE` to a `CART` (`180 kg`) at `(6,0,18)`; lever drives the winch | Throw lever; cart hauls to `(16,0,18)` | Cart proximity sensor |
| 15 | `fx_tether_route` | `PLATE` (`60 kg`) at `(5,0,14)`; anchor at `(14,5,14)`; `DRUM` (`70 kg`) at `(8,0,14)` | `TETHER` plate to anchor; `PUSH` drum onto the suspended plate to swing it into position | Plate proximity sensor |
| 16 | `fx_mass_gate` | `BALLAST` (`320 kg`) blocking a `SLIDER` door; `WEIGHT_THRESHOLD` `100 kg` beyond it | `LIGHTEN_FIELD` the `BALLAST`, `PULL` it clear, release | Threshold `ON` |
| 17 | `fx_fallback_zone` | The certified fallback: 6 rooms, linear, one package each from families 1, 3, 4, 7, 8, 9; 4 Checks at rooms 2, 3, 5, 6; checkpoints at 1, 3, 5; **no `manipulate` requirement**; no branches | — | per package |

Fixture 17 contains **no mandatory manipulation** and no constraint machinery. The fallback Zone must be guaranteed-completable by construction, and the cheapest way to guarantee that in a physics proposal is for the fallback to use none of the physics.

Every fixture ships with an expected-state assertion file recording the serialized `PUZZLE_LOCAL` state after solving and after resetting, plus, for fixtures 10 through 16, the recorded `ReferenceSolution` and the three-run replay result.

---

# 38. TEST VECTORS

Design 1's vectors apply wherever a system is pinned. The vectors below are Design 2's own: the systems that differ, and every system that is new. Numbered continuously.

## Pinned systems
1. All Design 1 vectors covering pinned sections pass unchanged against this proposal: movement law (D1 vectors 5–11), damage road (58–63), interaction focus (45, 47, 48, 50), Mobility (12, 13), loadout (73–79), hacking (88–90), signals (108, 109), determinism (81). A failure in any of these is a failure of a pin, not of a new system.

## Baseline
2. Empty Loadout: the player completes fixture 17 end to end using only Static Pulse, melee, and `F`.
3. Static Pulse's `IMPULSE` rider moves a `15 kg` `GENERIC` object and does not move a `40 kg` `POWER_CELL`.
4. Baseline melee's `7.0 m/s` impulse displaces a `MEDIUM` object and does not displace a `HEAVY` one.

## The twelve verbs
5. `PUSH` at `700 N` on a `120 kg` object produces exactly `5.83 m/s` ± `0.01`.
6. `PUSH` at `4000 N` on a `20 kg` object produces `30.0 m/s`, the clamp, not `200 m/s`.
7. Vertical velocity from any player impulse never exceeds `14.0 m/s`, across 10,000 randomised verb, angle, and mass combinations.
8. `HOLD` maintains an object at `hold_distance` ± `0.1 m` while line of sight holds, and releases within one tick of `0.5 s` of occlusion.
9. `hold_distance` adjusts between `1.5 m` and `6.0 m` on wheel input while holding, and wheel input resumes Weapon cycling on the first tick after release.
10. `ALIGN` brings an object within `0.02 rad` of axis alignment and holds orientation `2.5 s` while gravity still acts on it.
11. `TETHER` between two points `9 m` apart creates a `ROPE` of `length 9.45` (`×1.05`).
12. A tether beyond `max_length` fails on the second activation and refunds nothing.
13. `PIN` holds a `260 kg` object against gravity for exactly `6.0 s` on `ab_pin_brief`, and supports a `140 kg` object resting on it.
14. `ATTACH` joins two `GIRDER`s into one body of `190 kg`, class `HEAVY`.
15. A fifth `ATTACH` onto a four-object chain is rejected with the §34.9 feedback.
16. `DETACH` restores both bodies at their world transforms with zero velocity.
17. `ROTATE` on a `HINGE`-constrained object drives it within limits and stops at `limit_upper` without oscillating.
18. `LIGHTEN_FIELD` at `0.35` on a `320 kg` `BALLAST` yields `112 kg`, class `MEDIUM`, and the change reverts exactly on expiry.
19. Two overlapping fields do not stack; the later-applied wins.
20. `SETTLE` zeroes velocity on every eligible body in radius and forces sleep next tick, and does not affect a body under `WINCH` drive.
21. No sequence of verb inputs moves the player, across 10,000 randomised attempts.
22. `max_relations` at `3` releases the oldest relation on a fourth; `RULE_RELATION_COUNT` raises it and never past `6`.
23. A second relation on an already-held object releases the first (§31.2).

## Eligibility
24. A `FIXED` object responds to no verb except `DETACH` and constrained `ROTATE`.
25. An enemy responds to `PUSH`, `PULL`, `PIN`, and both fields, and to no other verb.
26. A boss responds to no verb.
27. A `required` object with `physics_permitted = false` is inert to every verb despite being `LIGHT`.
28. Verb mass limits are enforced exactly at the boundary: `ab_physics_light` moves `120.0 kg` and refuses `120.1 kg`.

## Constraints
29. A `ROPE` resists extension and not compression: an object below its anchor falls freely until the rope goes taut.
30. A `PULLEY` conserves total length across both ends within `0.02 m` over `60 s` of motion.
31. A `COUNTERWEIGHT` at equal masses rests; adding `20 kg` to one side moves it down.
32. A `SEESAW` respects `limit_lower` and `limit_upper` and does not pass through them under any load up to `400 kg`.
33. A `PENDULUM` released from `45°` returns to within `40°` on its first back-swing with default damping.
34. A constraint exceeding `breakable_at` breaks on that tick; both bodies retain velocity; `broken` is set.
35. `breakable_at = null` never breaks, under any force, including explosions.
36. `BRITTLE` halves an effective non-null `breakable_at` and leaves a null one null.
37. A broken constraint on a `required` object rebuilds with the object at `home_transform` within `1.0 s`.
38. Solver iterations are exactly `8` per tick under all loads; the count never adapts.
39. A `4`-constraint chain simulates; a 5th linked constraint is rejected at composition.

## Latching
40. A latched condition reports `ON` after the physical configuration that caused it is fully dismantled.
41. A latch survives death, reset, room unload, save/load, and Zone re-entry.
42. Package reset restores object positions and does not clear latches.
43. An `A_B_STATE` package with `latches = false` toggles freely and never latches.
44. Latching is applied at evaluation step 1 and is visible to every node in the same tick.

## Persistence
45. A save is refused while any `PUZZLE_LOCAL` object is awake, with the §34.7 settle message.
46. A checkpoint entered during motion activates within `0.5 s` of the last object sleeping.
47. Save then load reproduces every `PUZZLE_LOCAL` object's transform within `0.01 m` and `0.01 rad`.
48. Load rebuilds attachments before constraints, and no object is penetrating after step 9.
49. A room reloaded mid-swing restores at rest, not mid-swing, with velocities zeroed.
50. Held, pinned, and tethered relations are released by save/load and are not restored.
51. `PhysicalConfiguration` is serialized at 32-bit precision; a puzzle requiring finer precision fails check 19 at composition.

## Damage and the invariant
52. Physics impact at `15.4 m/s` on a `260 kg` object deals exactly `37.6` ± `0.1`.
53. Impact damage never exceeds `90.0` at any achievable speed and mass.
54. The `90.0` ceiling is unreachable by player-applied force: no legal combination of force, mass, and modifier reaches it.
55. A player-driven object striking the player deals `25%`, capped at `20.0`.
56. A constraint-driven object striking the player deals full damage.
57. Re-hit cooldown is `1.0 s` per (object, target) pair; a resting object never damages twice within it.
58. **Weapon-only TTK is strictly lower than physics-only TTK for all six archetypes, under every legal loadout** (§31.3).
59. No composed encounter violates check 23, across 10,000 seeds.

## Status
60. Four Statuses exist; no fifth loads.
61. `LIGHTENED` and `ANCHORED` never coexist on one target.
62. `LIGHTENED` on a `320 kg` object changes what a `WEIGHT_THRESHOLD` beneath it reads.
63. `ANCHORED` makes a target immune to every verb, wind, conveyor, and impulse, and a constraint attached to it goes taut.
64. `BURNING` on a `WOOD` object reduces its constraints' `breakable_at` by exactly `40%` for the duration and restores it exactly on expiry.
65. No Status schedules a `DamageRequest`: applying all four to a `SKIRMISHER` on non-burnable floor leaves Health at exactly `60.0`.
66. Pity and adaptation are tracked per `(target, family)` across the two families only.

## Capability and generation
67. `capability:core:manipulate` is granted by `PUSH`, `PULL`, and `HOLD` abilities and by no other verb.
68. Every mandatory manipulation requirement across 10,000 Zones is satisfiable by `ab_physics_light` at `700 N`, `20.0 m`, `120 kg`.
69. No mandatory route passes through a gravity volume with `affects_player = true`.
70. Every package with a mandatory manipulation requirement has a `reference_solution` whose replay latches all conditions in three of three runs.
71. Every `WEIGHT_THRESHOLD` on a mandatory route is satisfiable by one authored object.
72. Every composed room reaches full sleep within `settle_timeout`.
73. No required solution depends on a tether, a `PIN`, or an attachment chain longer than `2`.
74. No required solution depends on a configuration holding longer than `10.0 s`.

## Performance
75. A room at budget — `40` bodies, `8` constraints, `10` enemies — holds frame time within the platform target for `60 s` of active play.
76. The `24` non-sleeping cap forces sleep on the longest-awake unprotected body, and never on a `required`, constrained, or player-held one.
77. Total loaded rigid bodies never exceeds `90`, and constraints never exceed `20`.
78. A decorative body at rest for `1.5 s` sleeps and stops counting.

## Presentation
79. Constraint stress is distinguishable at `60%`, `80%`, and `95%` of `breakable_at` in at least two of pattern, motion, and audio, with hue removed.
80. Manipulable and `FIXED` objects are distinguishable without experimentation, with hue removed.
81. Held, pinned, and tethered states are mutually distinguishable by shape, not colour.
82. The "too heavy" rejection displays the target's actual `mass_kg` and the verb's limit.
83. `F` shows no prompt at all while a relation is held.

## Gaps closed by the §39 traceability pass
84. `ACTION` recharge advances only on the thirteen facts in §12.6. `MASS_MOVED` accrues only while the player is causing the motion: standing beside a free-swinging `PENDULUM` for `60 s` accrues exactly `0.0`.
85. A `PHYSICS_VERB` preflight that fails — no eligible target, out of range, occluded, over the mass limit — spends no resource, charge, or cooldown, across all twelve verbs.
86. `MANIPULATION_ADVANCES_COOLDOWN` cannot self-feed: an ability that moves an object cannot use that same movement to advance its own cooldown, and total recharge reduction never exceeds `60%` of base.
87. An optional ledge reachable only by stacking, tethering, or attaching remains reachable, and using it does not fail the Zone audit. Optional geometry is never defended against.
88. A boss takes `BRITTLE` at half duration where `ANCHORED` or `LIGHTENED` was applied, rather than a blanket immunity, and a `TURRET` fails both visibly.
89. An `OR` node accepts either input independently, and the node catalog pinned from Design 1 §19.2 loads all eleven types.
90. A one-way shortcut opened from the far side is `ROOM_PERSISTENT`: it survives death, puzzle reset, room reload, and Zone re-entry, and no reset re-closes it.
91. A `RAIL_SWITCH` changes branch only when no actor is within `10.0 m` of the junction, and the queued change applies when the rail clears.
92. A `SWINGING_LOAD` telegraphs by visible motion: the interval between it becoming dangerous and reaching the player's position is at least `1.5 s` on every mandatory route, measured rather than scripted.
93. A `REACTIVE_BARREL` damages valid actors and chains at most `5` links; a `bombable` wall responds to explosive damage and an untagged wall does not.
94. A Zone flag set in one room propagates to dependent machinery in later rooms, survives unload and reload, and is never cleared.
95. Every `CONSTRAINT_STATE` sensor quantises to its `bucket_count` and its output is stable across `1,000` replays of the same physical input.
96. Measured over `1,000` simulated encounters per archetype, Weapon-only kills complete in less time than manipulation-only kills in `1,000` of `1,000` cases (§31.3).
97. A player with an `ATTACH` Ability and no `DETACH` Ability can separate every attachment they created, using `F` alone.
98. No composed room across 10,000 Zones holds more than `20` protected bodies, so a forced-sleep candidate always exists.

---

# 39. TRACEABILITY

All 142 acceptance tests named by the two source authorities — 62 in Player Authority §35, 80 in Dungeon Authority §71 — mapped to the coverage that closes them.

Design 2 has a fourth resolution that Design 1 did not need, because it pins shared systems (§0.2):

| Notation | Meaning |
|---|---|
| `V n` | A Design 2 test vector, §38 |
| `fx n` | A Design 2 reference fixture, §37 |
| `D1 V n` | Covered through an explicit pin to Design 1, whose vector *n* closes it. Vector 1 asserts every such pin holds. |
| **deferred** | The system is out of scope by §2.2 and the test is not applicable |

A `D1 V n` row is only legitimate where this document actually pins the relevant section. Where Design 2 changed a system, its own vector covers it — which is why the physics, Status, capability, and presentation rows are all `V`.

## 39.1 Player Design Authority §35

| # | Acceptance test | Covered by |
|---|---|---|
| P1 | Empty build can move, jump, interact, melee, and defeat a basic mandatory enemy with Static Pulse. | V 2 |
| P2 | Static Pulse cannot be removed from the Weapon cycle. | D1 V 2 |
| P3 | Out-of-bounds recovery returns to valid state. | D1 V 3 |
| P4 | No foreign receipt is required for the player to remain basically playable. | V 2 |
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
| P19 | Action recharge advances only on declared facts/metrics. | V 84 |
| P20 | Failed preflight spends nothing. | V 85 |
| P21 | Post-commit miss receives no implicit refund. | D1 V 39 |
| P22 | Recharge modifiers cannot create an unbounded self-feed loop. | V 86 |
| P23 | Resource/Cooldown/Action are visibly distinguishable in HUD. | D1 V 42 |
| P24 | F activates a normal mechanism. | D1 V 82 |
| P25 | F activates an AP Check while preserving AP transaction semantics. | D1 V 48 |
| P26 | F picks up and drops/places carryables. | D1 V 83, 84 |
| P27 | Required carryable lost out of bounds recovers. | D1 V 49 |
| P28 | Carrying produces unambiguous context prompt. | V 83 |
| P29 | Hacking begins through F and resolves as a room-signal input rather than bespoke door logic. | D1 V 88 |
| P30 | Eligible object can be manipulated. | V 5 |
| P31 | Ineligible progression object cannot be manipulated merely because it is physically light. | V 27 |
| P32 | Physics cannot self-launch the player into universal traversal. | V 21 |
| P33 | Player-owned impact has a hard damage ceiling. | V 53 |
| P34 | Resting/jittering props cannot repeatedly damage. | V 57 |
| P35 | Optional clever sequence breaks remain possible where no semantic gate forbids them. | V 87 |
| P36 | No normal gameplay path writes Health outside the damage resolver. | D1 V 58 |
| P37 | Same ordinary non-crit attack under same state gives same damage. | D1 V 59 |
| P38 | 100% crit guarantees Tier I. | D1 V 60 |
| P39 | 150% crit never produces an ordinary hit. | D1 V 61 |
| P40 | Overcrit tiers scale linearly rather than exponentially. | D1 V 63 |
| P41 | Status cannot directly or indirectly schedule periodic Health damage. | V 65 |
| P42 | Failed chance-based Status attempt visibly increases bounded susceptibility. | D1 V 67 |
| P43 | Successful Status application increases temporary adaptation. | D1 V 68 |
| P44 | Strong enemies can resist more without every effect becoming blanket `IMMUNE`. | V 88 |
| P45 | World fire may damage independently from `BURNING`. | D1 V 65 |
| P46 | Unequipped Archive hosts produce zero live listeners/reactions/resources. | D1 V 73 |
| P47 | Full loadout cannot be swapped during ordinary active combat. | D1 V 74 |
| P48 | Weapon cycling is not a full loadout swap. | D1 V 138 |
| P49 | Re-equipping an old host restores legal saved state instead of refilling it. | D1 V 75 |
| P50 | Newly introduced host cannot manufacture free readiness in an already-active Zone. | D1 V 76 |
| P51 | Mod insertion/removal at the Hub has no respec fee. | D1 V 77 |
| P52 | Only one high-tier Gear piece may be equipped across Head/Torso/Arms/Legs. | D1 V 78 |
| P53 | Hard capability gate cannot appear before guarantee. | V 68 |
| P54 | Epsilon cannot invent a hard requirement. | D1 V 94 |
| P55 | GRAPPLE-required Zone verifies a usable expression is equipped before entry or supplies it before the requirement. | D1 V 96 |
| P56 | Raw DPS threshold cannot become AP reachability logic. | D1 V 95 |
| P57 | Physics/recoil may bypass optional geometry without automatically invalidating the Zone. | V 87 |
| P58 | Weapon-cycle transition visibly identifies the newly selected configuration. | D1 V 97 |
| P59 | Static Pulse has recognizable neutral/home presentation. | D1 V 98 |
| P60 | Viewmodel animation/VFX cannot decide simulation outcome. | D1 V 99 |
| P61 | Physics ownership/target/relation state is visually readable. | V 81 |
| P62 | A configuration with no RMB or feed mechanic does not invent meaningless filler UI. | D1 V 100 |

## 39.2 Dungeon & Environmental Gameplay Authority §71

| # | Acceptance test | Covered by |
|---|---|---|
| D1 | F operates the intended focused object when several interactables are nearby. | D1 V 45 |
| D2 | Carryable pickup/drop is predictable. | D1 V 83 |
| D3 | Placing an object in a compatible socket succeeds. | fx 2 |
| D4 | An incompatible object is rejected visibly. | D1 V 85 |
| D5 | The player knows what F will do in an ambiguous context. | V 83 |
| D6 | A plate visibly communicates its output relationship. | D1 V 101 |
| D7 | A conduit state is understandable without relying only on color. | D1 V 102 |
| D8 | AND requires both inputs. | fx 7 |
| D9 | OR accepts either input. | V 89 |
| D10 | Timed state visibly communicates remaining urgency. | D1 V 103 |
| D11 | Latch persists according to package semantics. | D1 V 108 |
| D12 | Signal reset restores initial state. | D1 V 109 |
| D13 | A powered door opens. | fx 1 |
| D14 | Removing power closes safely. | D1 V 110 |
| D15 | A player in the doorway is not silently crushed by a non-hazard door. | D1 V 110 |
| D16 | A persistent shortcut remains unlocked after room revisit. | V 90 |
| D17 | A topology transformation never removes every valid progression route unintentionally. | D1 V 111 |
| D18 | Required carryable cannot be permanently lost. | D1 V 49 |
| D19 | Dropping it out of bounds restores it. | D1 V 49 |
| D20 | Destroying a replaceable required object restores it. | D1 V 86 |
| D21 | Save/load reconstructs its semantic state. | V 47 |
| D22 | A weighted plate cannot be cheesed by meaningless tiny debris unless authored. | V 71 |
| D23 | Required timed path is physically feasible. | D1 V 112 |
| D24 | Timing includes reasonable player variance. | D1 V 112 |
| D25 | Failure permits immediate retry. | D1 V 113 |
| D26 | Countdown is readable. | D1 V 103 |
| D27 | Mandatory shootable target works with guaranteed baseline weapon capability. | D1 V 114 |
| D28 | Invalid hits do not trigger it. | D1 V 115 |
| D29 | Target state is readable at distance. | D1 V 104 |
| D30 | Hack can enable an output. | fx 6 |
| D31 | Hack can redirect a connection in a package designed for routing. | fx 6 |
| D32 | Hack failure does not corrupt puzzle state. | D1 V 89 |
| D33 | Hack interaction can be exited/reset safely. | D1 V 89 |
| D34 | Powered rail state is readable. | D1 V 105 |
| D35 | Rail branch switch selects a physically valid route. | V 91 |
| D36 | LaunchPad source/landing remains valid. | D1 V 116 |
| D37 | Grapple target exists within an audited grapple opportunity. | D1 V 117 |
| D38 | Moving platform does not strand required progression. | D1 V 111 |
| D39 | Hazard damage uses common damage road. | D1 V 119 |
| D40 | Hazard telegraphs before unavoidable contact where appropriate. | V 92 |
| D41 | Hazard can affect enemies if package says it can. | D1 V 120 |
| D42 | Hazard controller correctly disables/enables it. | D1 V 121 |
| D43 | Reset restores hazard phase safely. | D1 V 141 |
| D44 | Reactive barrel damages valid actors. | V 93 |
| D45 | Bombable wall responds to tagged explosive. | V 93 |
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
| D60 | Encounter-clear gate opens from authored encounter completion. | fx 8 |
| D61 | Generator state propagates to dependent room. | V 94 |
| D62 | Cross-room state survives unload/reload. | D1 V 126 |
| D63 | Dependency chain remains reachable. | D1 V 127 |
| D64 | Dungeon macro-state cannot create an accidental progression cycle. | D1 V 127, 128 |
| D65 | Puzzle reset affects only its declared reset group. | D1 V 129 |
| D66 | Completed AP Check is not undone by puzzle reset. | D1 V 130 |
| D67 | Persistent shortcut is not undone by local reset. | V 90 |
| D68 | Temporary projectiles and signals are cleared. | D1 V 131 |
| D69 | Critical active/inactive state is distinguishable without color alone. | V 79, 80 |
| D70 | Required sound cue has visual equivalent. | D1 V 106 |
| D71 | A distant controlled output can be inferred from input. | D1 V 101 |
| D72 | Wrong-sequence failure communicates the error. | D1 V 107 |
| D73 | Same seed/package produces same initial composition. | D1 V 81 |
| D74 | Decorative randomness does not alter solvability. | D1 V 81 |
| D75 | Package audit produces stable results. | V 70 |
| D76 | Inactive physics objects sleep. | V 78 |
| D77 | Large room does not keep unlimited projectiles alive. | D1 V 134 |
| D78 | Beam routing has bounded complexity. | D1 V 135 |
| D79 | Signal update is event-driven where practical. | D1 V 136 |
| D80 | Debug view can identify active semantic state without inspecting scene internals manually. | V 95 |

## 39.3 Coverage

| | Count |
|---|---:|
| Authority acceptance tests | 142 |
| Covered by a Design 2 test vector | 32 |
| Covered by a Design 2 reference fixture | 6 |
| Covered through a pin to Design 1 | 95 |
| Not applicable — system deferred by §2.2 | 9 |
| **Uncovered** | **0** |

The 95 pinned rows are the measure of how much Design 2 shares with Design 1, and the 38 own rows are the measure of what it changes. Both numbers are useful when choosing between them: at 38 of 133 applicable tests, this proposal rewrites roughly a quarter of the acceptance surface and inherits the rest.

The nine deferred tests are D48–D52 (energy balls, reflector beams) and D53–D56 (water as a medium) — the same nine Design 1 defers. Water is the more painful of the two here, because buoyancy and changing water level would interact richly with constraint simulation; §41.2 records that.

---

# 40. IMPLEMENTATION WAVES

Ordered by dependency. A wave is done when its vectors pass.

| Wave | Contents | Vectors |
|---|---|---|
| 1 | Everything pinned from Design 1 waves 1–3: input roles, movement law, damage road, host schemas, Archive, Loadout | 1 |
| 2 | Physical object model: `PhysicalObject`, mass derivation, the twelve classes, `PhysicalConfiguration` | 3, 4, 51 |
| 3 | The solver: eight constraint kinds, fixed 8-iteration budget, `breakable_at`, sleep rules | 29–39 |
| 4 | The twelve verbs, eligibility, and the §14.4 limits | 5–28 |
| 5 | Impact damage and the §31.3 invariant | 52–59, 96 |
| 6 | Latching, and the physical persistence categories | 40–44 |
| 7 | Save refusal, settle detection, reconstruction order | 45–50 |
| 8 | Weapons: four families, physical riders, `TETHER_SHOT` | 84, 85 |
| 9 | Abilities: eight families, the compatibility matrix, `MASS_MOVED` | 84, 86 |
| 10 | Status: the four, application, substitution | 60–66 |
| 11 | Gear and Mods, with the four replaced intrinsics | pinned |
| 12 | Sensors: `WEIGHT_THRESHOLD`, `CONSTRAINT_STATE`, `ATTACH_SENSOR` | 71, 95 |
| 13 | Constraint-driven actuators: `WINCH`, `BRAKE`, `DRIVER` | fixtures 12, 14 |
| 14 | Puzzle-package contract, reference solutions, checks 19–23 | 70, 72, 73, 74 |
| 15 | The sixteen families and their fixtures | fixtures 1–16 |
| 16 | Hazards: `SWINGING_LOAD`, `COLLAPSING_STACK`, emergent telegraphs | 92, 93 |
| 17 | Enemies: mass, `DISPLACED`, physics-aware pathfinding | 25, 26 |
| 18 | Gravity volumes | 69 |
| 19 | Composition: shorter spine, settle test, audit checks 9–10 | 67, 68, 94 |
| 20 | Presentation: constraint stress, relation states, mass readability | 79–83 |
| 21 | Performance: budgets, forced sleep, the `24` cap | 75–78 |
| 22 | Player-facing flow, both save-refusal messages, rejection feedback | 82, 83 |

Waves 2 and 3 are the foundation and are strictly sequential — nothing else in this proposal can be built or tested without a working solver. Waves 4–7 are the manipulation core and must complete before any puzzle work. Waves 8–11 are player systems and may run in parallel with 12–16. Waves 17–22 integrate.

**The honest scheduling note:** wave 3 is the highest-risk item in any of the five proposals. If the solver cannot hold `40` bodies and `8` constraints at frame rate with `8` fixed iterations, this proposal does not work, and that is knowable at the end of wave 3 rather than at the end of the project. Build wave 3 first and measure it before committing to the rest.

---

# 41. CLOSURE STATEMENT

## 41.1 What this proposal decided

1. **Rearrangement is the central verb**, expressed as twelve manipulation verbs against Design 1's four.
2. **Constraints are genuinely simulated** — eight kinds, fixed 8-iteration solver, real `breakable_at` — where Design 1 made all machinery kinematic.
3. **Physical configuration is persisted state**, at 32-bit precision, for required and constrained objects only.
4. **Latching (§5.7)**: a satisfied puzzle condition is permanent and never re-evaluated. This is the mechanism that makes simulated physics safe for progression, and it is the single most important decision in this document.
5. **Mandatory manipulation is permitted**, validated against the least capable granting profile and proven by a replayed reference solution (§23.5 check 20). Design 1 forbade this outright.
6. **`capability:core:manipulate`** is a fifth capability, granted only by `PUSH`, `PULL`, and `HOLD`.
7. **The manipulation limits in §14.4** — a `14.0 m/s` vertical ceiling, a 4-object attachment cap, a `400 kg` mass ceiling, a `4000 N` force ceiling — are what keep this inside Player Authority §17.4.
8. **Physics never moves the player**, unchanged from Design 1, which is what keeps §30.17 satisfied.
9. **Weapons remain dominant damage by a factor of about ten** (§31.3), demonstrated arithmetically rather than asserted, with the `90.0` impact ceiling shown to be unreachable by player action.
10. **Player-driven impacts hurt the player at `25%` capped at `20.0`; constraint-driven impacts hurt at full.** The split is by causation, not ownership.
11. **Enemies are physical**: real mass, `DISPLACED` state, shovable and pinnable, never carriable or weldable.
12. **Four Statuses**, all kinetic or thermal, all changing physical behaviour. `BRITTLE` is new and never makes an unbreakable constraint breakable.
13. **Weapons carry physical riders** — one bounded physical effect each — so a four-family catalog stays expressive.
14. **Saves are refused while physics is in motion**, which is the honest alternative to serializing a live simulation.
15. **Zones are shorter** (6–11 rooms) because check 20's replay makes composition expensive.
16. **Local gravity volumes ship**, but never on a mandatory route where they affect the player.
17. **`SETTLE` exists** as a deliberate undo for a chaotic room.
18. **Design 2 pins rather than restates** what it shares with Design 1 (§0.2), which is a documentation decision with real consequences for how these five are compared and merged.

## 41.2 What this proposal sacrificed

| Sacrifice | What is lost |
|---|---|
| **Half the Weapon catalog** | Four primary families against eight. No burst, no spread, no lobbed projectile, no charged shot. Gun-feel variety is materially poorer. |
| **A third of the Ability catalog** | Eight families against twelve. No healing at all, no turrets, no damage fields, no weapon buffs, no ability-driven repositioning. |
| **Two Statuses and a whole family** | No `CONFUSED`, no `TURNCOAT`, no `COGNITIVE` family. Design 2 cannot turn an enemy against its allies. |
| **Water** | The most painful deferral in this proposal specifically. Buoyancy, changing water level, and floating routes would interact with constraints better than anything else on the deferred list. |
| **Two puzzle families as named families** | `LOCAL_KEY_LOOP` and `MULTI_STAGE_MACHINE` remain expressible as compositions but are no longer generation vocabulary, which narrows what the composer can ask for. |
| **Zone length** | 6–11 rooms against 8–16. Campaigns are shorter or need more Zones. |
| **Performance headroom** | The tightest budgets of any proposal, with a forced-sleep failure mode that is visible to the player. |
| **Cross-platform reproducibility of play** | Two players on the same seed reach the same rooms and solve them differently. Latching makes that safe, not identical. |
| **Un-solvable puzzles** | Latching means a physical puzzle can be solved but never un-solved. Toggling behaviour must be driven by levers, never by configuration. |
| **Mid-motion saves** | Waiting for a room to settle before a checkpoint takes is a small, repeated friction the player will notice. |
| **Forge** | *Pinned from Design 1.* No synthesis; Mods accumulate inertly. |

## 41.3 Proposal-level choices the authorities did not mandate

Reviewable, and the places another proposal could reasonably differ:

- Latching as the answer to simulation drift. A different proposal might re-evaluate conditions continuously and accept that doors can close.
- Refusing saves during motion rather than serializing velocity.
- Restoring rooms at rest rather than mid-swing.
- Player-driven impacts at `25%` rather than Design 1's `0%`.
- `SETTLE` existing at all.
- Enemies never moving objects themselves.
- Attachment capped at 4 rather than any other number.
- 32-bit configuration precision, and check 19 forbidding puzzles finer than it.
- Pinning to Design 1 rather than restating.

## 41.4 Where this proposal disagrees with an authority

**Nowhere.** The three physics rejections in Player Authority §30.16–§30.18 are accepted in full:

| Rejection | How this proposal honours it |
|---|---|
| Not unrestricted telekinesis | §14.4's nine explicit limits; enemies never carriable; the player never a target |
| Not the main movement system | §13 is pinned unchanged from Design 1; physics never moves the player; §14.4's vertical ceiling caps improvised height at ~`4.5 m` |
| Not dominant damage | §31.3's arithmetic: Weapons out-damage manipulation about ten to one, and the impact ceiling is unreachable by player force |

The proposal uses a permission the authority grants and Design 1 declined — §25.1's "validated manipulation family" as a hard gate — which is a different thing from disagreeing with it.

If a reader finds a contradiction, it is a defect in this document and should be reported rather than resolved locally (§1.3).

## 41.5 The claim

**Every acceptance test named by the two source authorities is covered.** §39 maps all 142: 32 to a Design 2 vector, 6 to a Design 2 fixture, 95 through an explicit pin to Design 1, 9 to a recorded deferral. None is uncovered.

**There are no intentionally open behavioral decisions in this proposal.**

Anything not described here is one of:

- pinned to a named Design 1 section, which is itself closed;
- inherited unchanged from the two source authorities, and listed in §1;
- rejected by a closed schema in §4, which makes it unrepresentable;
- explicitly deferred in §2.2, with its cost stated;
- an engineering decision that belongs to the implementer.

A pin is a contract, not a gap. If a pinned Design 1 section turns out to be open, that is a defect in Design 1 and it is fixed there, once, for both documents.

If an implementer encounters a moment of play where neither this document nor its pins say what happens, that is a defect here. It is not permission to decide.

---

**End of Complete Design 2: Physics Is The Game**
