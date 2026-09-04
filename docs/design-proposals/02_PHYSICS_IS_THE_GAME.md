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
                             ATTACH, DETACH, ROTATE, LIGHTEN_FIELD,
                             ANCHOR_FIELD, SETTLE }? = null
                      # required iff family == PHYSICS_VERB, else must be null
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
- `MASS_SHIFT` never changes an object's class below `LIGHT` and never affects `FIXED` objects.
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

Design 1's `PROJECTILE_ATTACK`, `HEAL_CHANNEL`, `DEPLOYABLE_TURRET`, `DEPLOYABLE_FIELD`, `DASH_IMPULSE`, and `WEAPON_BUFF` are absent. `MASS_FIELD` and `DEPLOYABLE_ANCHOR` are new. The catalog is halved because `PHYSICS_VERB` alone covers twelve verbs, each with its own parameters and eligibility, and total build complexity has to stay inside a player's head.

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
