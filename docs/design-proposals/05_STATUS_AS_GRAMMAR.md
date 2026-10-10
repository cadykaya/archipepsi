# ARCHIPEPSI — COMPLETE DESIGN 5: STATUS AS GRAMMAR

## Statuses are the verbs; damage is only how fights end

**Status:** Complete alternative proposal. Not canon until selected by the owner.
**Proposal:** 5 of 5
**Design thesis:** Status is the game's verb layer, applied to actors, objects, surfaces, and the player alike. A small number of cross-family pairs combine into compounds, and every compound is a new rule rather than a damage bonus.
**Target:** Godot 4.5 client plus the existing Python/Pydantic bridge.
**Source authorities:** `docs/authorities/PLAYER_DESIGN_AUTHORITY_v1.0.md`, `docs/authorities/DUNGEON_ENVIRONMENT_AUTHORITY_v0.1.md`
**Written against:** `docs/design-proposals/00_ZERO_GUESSWORK_STANDARD.md` v1.1

### Proposal profile

| Axis | Rating |
|---|---:|
| Novelty | 5 / 5 |
| Player-build variety | 4 / 5 |
| Environmental breadth | 4 / 5 |
| System interaction depth | 5 / 5 |
| Implementation risk | 3 / 5 |
| Procedural validation difficulty | 3 / 5 |
| Reuse of current repo foundations | 3 / 5 |

**Principal tradeoff:** one system does the work that combat, puzzles, and traversal do separately in the other four. Status applies to actors, objects, surfaces, and the player, which unifies the game under a single vocabulary — and means every system in it inherits that vocabulary's failure modes. Weapons and Abilities are correspondingly plainer: they are mostly *how a Status is delivered*.

**Who should pick this:** an owner who reads Player Authority §20.7's *"statuses are gameplay verbs first"* as a mission statement rather than a caveat, and who wants one idea expressed everywhere instead of four ideas expressed once each.

---

# 0. PURPOSE

This document resolves every open decision in the two source authorities into an implementable form, to the Zero-Guesswork Standard.

## 0.1 The two traps this thesis walks between

A Status-centric design is the easiest of the five to get wrong, because the Player Authority rejects both obvious versions of it.

**Trap one — the primer loop.** §20.7: *"It should not force every combat build into 'apply Status, swap, consume Status for damage.'"* A design where Statuses exist to be cashed out for damage is the thing §7.5 and §30.2 already reject as a Weapon architecture, wearing a different hat.

**Trap two — the soup.** §30.3 rejects *"dozens of damaging proc types"* and, more sharply, *"mandatory composition knowledge."* A twelve-by-twelve reaction matrix is exactly that: a wiki page the player must hold in their head before combat is legible.

This proposal's answer to both is the same rule:

> **A Status changes what is true. It never changes how much damage something takes, and no combination is required to know in advance.**

Concretely: `12` base Statuses (§15.2) and **only `8` combining pairs** (§15.5) out of the `54` cross-family pairs that could exist. The other `46` simply coexist. A player never needs a matrix, because the combining pairs are few enough to meet, and every one of them is telegraphed on the target before it fires (§33.7).

## 0.2 What "the verb layer" means

Player Authority §20.1 lists thirteen things a Status may alter: movement, gravity, friction, mass and physics response, targeting, faction, AI behaviour, action permissions, perception, visibility, manipulation eligibility, collision and phase behaviour, and authored interaction rules.

Designs 1 through 4 use between three and six of those. **This proposal uses all thirteen**, and extends the target set: a Status here may sit on an actor, an object, a surface, a volume, or the player.

That extension is what makes the design a *grammar* rather than a bigger catalog. `PHASED` on an enemy is a combat effect; `PHASED` on a wall is a door; `PHASED` on the player is traversal. One verb, three grammatical positions.

## 0.3 Relationship to Designs 1–4

Design 5 **explicitly pins** shared systems to Design 1 by section number, using the convention Design 2 established and Design 3 refined. A pin means *identical* and names a document and section in this repository.

**Pins and modifiers.** Where a section modifies something it also pins, the pin names its modifier inline:

| Pinned section | Modified by | What changes |
|---|---|---|
| Design 1 §8.2 (resolution order) | §8.9 | Step 8's Status attempt becomes the full §15.4 pipeline |
| Design 1 §10.1 (`CarryableDefinition`) | §10.5 | Objects carry Status |
| Design 1 §15 (Status) | §15 entire | Replaced, not extended |
| Design 1 §25.0 (material traits) | §25.6 | Traits gate Status susceptibility |

---

# 1. INHERITED LAWS

*Pinned: identical to Design 1 §1.1 and §1.2.* All 48 laws unchanged.

Four bind hardest here:

- **Law 26** — chance-based Status with visible pity and adaptation. This proposal applies Statuses far more often than any other, so the pity system carries proportionally more weight (§15.4).
- **Law 27** — **a Status never directly or indirectly deals periodic damage.** §15.3 defines the structural rule that keeps twelve Statuses and eight compounds inside it.
- **Law 24** — no elemental or resistance matrix as the core damage model. §15.6 explains why susceptibility by material trait is not that.
- **Law 6** (Player Authority §2.6) — complexity comes from combinations of simple rules, each reducible to a short player-facing sentence. Every Status and compound in §15 has one, and they are printed in §33.7.

## 1.3 Precedence

*Pinned: identical to Design 1 §1.3.*

---

# 2. SCOPE

## 2.1 Ships in Status As Grammar

**The Status system — the reason this proposal exists**

- **Twelve base Statuses** in four families (§15.2), covering all thirteen alterations §20.1 permits.
- **Eight compounds** from cross-family pairs (§15.5) — `8` of a possible `54`, chosen for legibility.
- **Status on five target kinds** (§15.1): actor, object, surface, volume, player.
- **Susceptibility by material trait** (§15.6), which is how a Status knows whether it can apply to a crate, a floor, or a `BRUISER`.
- **Status-reactive sensors and hazards** (§20.5, §25.6), which is how the dungeon reads the verb layer.
- **Four Status-based puzzle families** (§24), which is how Status becomes level design rather than only combat.
- **Self-Status as build** (§12.5): Abilities that apply Statuses to the player.

**Player**

- Movement, damage, interaction, carryables, Mobility, physics — *pinned: identical to Design 1 §6, §8, §9, §10, §13, §14*.
- Five Weapon families and eight Ability families, both narrower than Design 1's and both oriented around delivery.
- Gear and Mods — *pinned: identical to Design 1 §16*, with four intrinsics replaced (§16.1.1).

**Dungeon**

- Signal graph, actuators, hacking, topology, capability progression, composition — *pinned: identical to Design 1 §19, §21, §22, §28, §29, §30*.
- Sixteen puzzle families (§24): twelve pinned, four new.

## 2.2 Explicitly deferred

| Deferred system | Cost of deferring |
|---|---|
| Forge | *Pinned: identical to Design 1 §2.2.* Design 4 ships it; this does not. |
| Water as a swimmable medium | Painful here: water is the most natural surface for `CONDUCTIVE` and `SLIPPERY`, and `FROZEN` would have been a thirteenth Status. Shallow water remains a movement volume and can carry Status (§15.1), which recovers part of it. |
| Energy balls and reflector beams | *Pinned: identical to Design 1 §2.2.* |
| Dynamic joints and constraint simulation | *Pinned: identical to Design 1 §2.2.* |
| Reversible macro state and looping topology | Design 3 ships this; this does not. |
| Compositional item generation | Design 4 ships this; this proposal uses Design 1's profile mechanism unchanged (§3.3). |
| Physics constructs, portals, gases, advanced gravity, programmable logic, rotating rooms, in-Zone loadout stations | *Pinned: identical to Design 1 §2.2.* |
| **Two puzzle families** | `OBSERVATION_TARGET` and `MULTI_STAGE_MACHINE` are cut for budget. Neither is the sole cover for any authority acceptance test. |

**Deferral means:** *pinned: identical to Design 1 §2.2.*

## 2.3 Removed rather than deferred

*Pinned: identical to Design 1 §2.3.*

## 2.4 What "v1" means here

*Pinned: identical to Design 1 §2.4.*

---

# 3. AUTHORITY AND DATA OWNERSHIP

*Pinned: identical to Design 1 §3.1 through §3.5*, including the profile mechanism — **Epsilon selects a named profile and never emits a number** — and the deterministic offline fallback.

Epsilon's one added choice: for a Weapon or Ability whose profile carries a Status slot, it selects **which** of the twelve Statuses that item applies, from the subset legal for that family. The Status itself is authored; only the selection is Epsilon's, exactly as in Design 1.

---

# 4. SCHEMAS

*Pinned: identical to Design 1 §4.1, §4.2, §4.4, §4.6, §4.7* — common types, host definition, Ability and Mobility shapes, profiles, and the loadout.

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
  status_target     : enum { ACTOR_ONLY, ACTOR_AND_SURFACE } = ACTOR_ONLY
  crit_eligible     : bool = true
```

`status_target = ACTOR_AND_SURFACE` means a miss still does something: the Status lands on whatever surface was struck. That single field is most of what makes Weapons interesting in this proposal, and it is why §11 can afford to be plain.

## 4.5 Status

Replaces Design 1 §4.5's `StatusDefinition` entirely.

```
StatusDefinition:
  id                : Id                       # status:core:<slug>
  family            : enum { KINETIC, COGNITIVE, PERMISSION, MATERIAL }
  base_duration     : Seconds
  base_chance       : Chance
  targets           : list[enum { ACTOR, OBJECT, SURFACE, VOLUME, PLAYER }]
  requires_trait    : list[string] = []        # material traits, OR-ed; empty = any
  sentence          : string, 1..64 chars      # the player-facing rule, §33.7
  stacks            : false                    # always

CompoundDefinition:
  id                : Id                       # compound:core:<slug>
  components        : list[Id], length exactly 2   # two base Statuses, different families
  duration          : Seconds
  consumes          : true                     # always: components are removed
  targets           : list[enum { ACTOR, OBJECT, SURFACE, VOLUME, PLAYER }]
  sentence          : string, 1..80 chars
```

`consumes` is fixed `true` and is the rule that keeps the system bounded: a compound removes both components, so a target's Status count never grows by combining.

## 4.8 Status runtime state

```
ActiveStatus:
  status_id         : Id
  target_kind       : enum { ACTOR, OBJECT, SURFACE, VOLUME, PLAYER }
  target_id         : Id
  remaining         : Seconds
  applied_by        : Id?                      # actor, for provenance and kill credit
  is_compound       : bool = false

StatusTargetState:
  target_id         : Id
  active            : list[ActiveStatus], length <= 3
  susceptibility    : map[family, float]       # pity, per §15.4
  adaptation        : map[family, float]
```

**A target carries at most three active entries**, where a compound counts as one. That cap is a readability rule before it is a performance one: four simultaneous rule changes on one enemy is a situation no player can reason about.

---

# 5. LIFECYCLE AND PERSISTENCE

*Pinned: identical to Design 1 §5.1 through §5.12.*

## 5.13 One addition: Status categories

| State | Category |
|---|---|
| `ActiveStatus` on an actor, object, surface, or volume | `EPHEMERAL` |
| `ActiveStatus` on the player | `EPHEMERAL` |
| `susceptibility` and `adaptation` per target | `EPHEMERAL` |

Every Status is `EPHEMERAL`, exactly as in Design 1 §5.11. Nothing about the verb layer survives a save, a death, or a room unload.

This is a deliberate and slightly painful decision in a proposal built on Status: a player who has spent thirty seconds assembling a compound on a boss loses it if they die. It is the right call anyway, because the alternative — persisting effect timers whose sources may themselves be gone — is the corrupted-save class of bug, and §5.3's save points never occur mid-combat.

---

# 6. BASE PLAYER

*Pinned: identical to Design 1 §6.1 through §6.5.*

## 6.6 One addition: the player is a Status target

The player appears in a Status's `targets` list as `PLAYER`, distinct from `ACTOR`. A Status that lists `ACTOR` but not `PLAYER` can never land on the player, and vice versa.

**Enemies never apply Status to the player.** *Pinned reasoning from Design 1 §32.1.* Every Status the player carries is one they applied to themselves (§12.5) or accepted from an environmental source they walked into (§25.6). This keeps the verb layer something the player wields rather than something done to them, and it is what makes `PERMISSION`-family Statuses tolerable at all — being `SILENCED` by an enemy would be miserable.

---

# 7. INPUT

*Pinned: identical to Design 1 §7.1 through §7.4.*

---

# 8. DAMAGE

*Pinned: identical to Design 1 §8.1, §8.3, §8.4, §8.5, §8.6, §8.7, §8.8* — the damage request, Defense, Barrier, linear overcrit, friendly fire, healing, and death.

## 8.2 Resolution order

*Pinned: identical to Design 1 §8.2* — **except that step 8 is replaced by §8.9**.

## 8.9 Step 8: the Status attempt — modifies Design 1 §8.2

Design 1's step 8 attempts one Status against one actor. Here it runs the full pipeline in §15.4, which additionally:

- resolves `status_target = ACTOR_AND_SURFACE` by attempting the Status on the struck surface when the actor attempt fails or no actor was struck;
- checks `requires_trait` against the target's material traits (§15.6);
- checks the three-entry cap and, when full, fails visibly rather than silently replacing;
- checks §15.5's compound table and, on a match, resolves the compound instead.

Everything else about the damage road is unchanged. **No Status, and no compound, modifies incoming or outgoing damage** — with the single, explicit exception of `BRITTLE` on objects (§15.2), which is not an actor and cannot be killed.

---

# 9. WORLD INTERACTION

*Pinned: identical to Design 1 §9.1 through §9.4.*

---

# 10. CARRYABLES AND SOCKETS

*Pinned: identical to Design 1 §10.1 through §10.4* — **except that §10.5 adds Status to objects**.

## 10.5 Objects carry Status — modifies Design 1 §10.1

`CarryableDefinition` gains one field:

```
status_traits     : list[string] = []      # material traits for §15.6 susceptibility
```

An object with `status_traits` containing `burnable` can take `BURNING`; one containing `conductive` can take `CONDUCTIVE`; one with neither takes neither. The traits are the same six in Design 1 §25.0, extended by §25.6.

A carried object retains its Statuses. Picking up a `BURNING` crate does not extinguish it, and the player is not damaged by carrying it — but the Fire Actor it spawns (§15.2) is at the carry position, which is `1.20 m` in front of the player's eyes, and that is very much the player's problem.

---

# 11. WEAPONS

Five primary families. *Parameters and profiles: pinned: identical to Design 1 §11.1* for `HITSCAN_SINGLE`, `HITSCAN_BURST`, `PROJECTILE_DIRECT`, `BEAM_CONTINUOUS`, and `CLOSE_ARC`. `HITSCAN_SPREAD`, `PROJECTILE_LOB`, and `CHARGE_RELEASE_SHOT` are cut for budget.

Weapons are plain here on purpose. In this proposal a Weapon's interesting property is **which Status it carries and where that Status lands**, and a rich Weapon catalog on top of a rich Status catalog is more than a player can hold.

## 11.1 Status delivery

| `status_target` | Behaviour |
|---|---|
| `ACTOR_ONLY` | The Status is attempted on the struck actor. A miss does nothing. |
| `ACTOR_AND_SURFACE` | The Status is attempted on the struck actor; if no actor was struck, or the actor attempt fails §15.4, it is attempted on the struck surface instead. |

`ACTOR_AND_SURFACE` costs nothing mechanically and changes everything about how a Weapon plays: a `CONDUCTIVE` beam that misses paints the wall behind the target, and the wall is now part of the fight.

**Which families may carry which target mode:**

| Family | `ACTOR_ONLY` | `ACTOR_AND_SURFACE` |
|---|:-:|:-:|
| `HITSCAN_SINGLE` | ● | ● |
| `HITSCAN_BURST` | ● | ● |
| `PROJECTILE_DIRECT` | ● | ● |
| `BEAM_CONTINUOUS` | ● | ● |
| `CLOSE_ARC` | ● | |

`CLOSE_ARC` is excluded from surface application because a melee sweep strikes whatever is within `3 m` in a wide arc, and painting every surface in that arc every `0.45 s` produces a room where everything is `BURNING` and nothing is legible.

**Beam surface application is rate-limited** to one attempt per `0.5 s` per surface, rather than one per `0.10 s` damage tick, for the same reason.

## 11.2 Secondary kinds and feeds

*Pinned: identical to Design 1 §11.2* for `ZOOM`, `ALT_FIRE`, and `GUARD`, and §11.3, §11.4, §11.6 for `MAGAZINE`, `HEAT`, and `NONE`. `DETONATE` and `MODE_SWAP` are cut with `PROJECTILE_LOB`; `CHARGE` is cut with `CHARGE_RELEASE_SHOT`.

## 11.3 Cycling

*Pinned: identical to Design 1 §11.7*, with the `CHARGE` and `PROJECTILE_LOB` rows removed.

Statuses already applied to the world persist across a cycle. They are world state, not Weapon state, and §11.7's "only the selected Weapon is activation-active" rule is unaffected — an unselected Weapon applies nothing new.

---

# 12. ABILITIES, READINESS, AND COST

## 12.1 The eight families

| Family | What it does | Damage | Status role |
|---|---|---|---|
| `STATUS_APPLICATOR` | Applies a Status to a target, with no damage | no | **required**, any legal |
| `STATUS_FIELD` | Applies a Status to every legal target in a volume, repeatedly | no | **required**, any legal |
| `SELF_STATUS` | Applies a Status to the player | no | **required**, `PLAYER`-legal only |
| `STATUS_TRANSFER` | Moves one Status from one target to another | no | none of its own |
| `PROJECTILE_ATTACK` | *Pinned: identical to Design 1 §12.1.* | yes | optional |
| `AREA_BURST` | *Pinned: identical to Design 1 §12.1.* | yes | optional |
| `BARRIER_GRANT` | *Pinned: identical to Design 1 §12.1.* | no | none |
| `PHYSICS_VERB` | *Pinned: identical to Design 1 §12.1.* Four primitives. | no | none |

Design 1's `HEAL_CHANNEL`, `DEPLOYABLE_TURRET`, `DEPLOYABLE_FIELD`, `MARK_REVEAL`, `DASH_IMPULSE`, `WEAPON_BUFF`, and `TEMPORARY_RULE` are absent. `MARK_REVEAL` is subsumed: revealing things is what §33.7's Status display does continuously and for free.

Common parameters and profiles — *pinned: identical to Design 1 §12.1* — with:

| Family | `magnitude` means |
|---|---|
| `STATUS_APPLICATOR` | `source_potency` added to application chance |
| `STATUS_FIELD` | `source_potency`, applied every `1.0 s` to each legal target in the volume |
| `SELF_STATUS` | ignored; self-application never rolls (§15.4) |
| `STATUS_TRANSFER` | ignored |

## 12.2 `STATUS_FIELD`

A volume that attempts its Status on every legal target inside it, once per second.

| Profile | `cast_time` | `duration` | `radius` | `range` | `magnitude` |
|---|---:|---:|---:|---:|---:|
| `field_brief` | `0.20` | `5.0` | `4.5` | `22.0` | `0.20` |
| `field_wide` | `0.30` | `8.0` | `7.0` | `18.0` | `0.10` |

A field applies to actors, objects, **and the surfaces its volume touches**, which is how a player converts a room rather than a target. Fields respect `requires_trait` (§15.6) and the three-entry cap exactly as single applications do.

## 12.3 `STATUS_TRANSFER`

Removes one `ActiveStatus` from a source target and applies it to a destination target, at full remaining duration and with **no application roll** — a transferred Status always lands, provided the destination is legal for it per `targets` and `requires_trait`.

| Profile | `cast_time` | `range` | Notes |
|---|---:|---:|---|
| `transfer_standard` | `0.25` | `25.0` | Two activations: source, then destination, within `8.0 s` |

Rules:

- The player selects which Status to move when the source carries more than one; the selector appears as a radial at the source (§33.9).
- A compound **cannot** be transferred. Its components were consumed; there is nothing atomic to move.
- Transferring onto a target already at the three-entry cap fails, with the §34.11 feedback, and the source keeps its Status.
- If the transfer completes a §15.5 pair on the destination, the compound forms normally.

`STATUS_TRANSFER` is the family that turns Status from an effect into a resource. Pulling `BURNING` off a hazard and putting it on an `ARMORED` enemy, or pulling `ANCHORED` off yourself and putting it on a crate that needs to stay put, is the play this proposal exists for.

## 12.4 Activation, preflight, recharge

*Pinned: identical to Design 1 §12.2, §12.2.1, §12.3, §12.4, §12.5, §12.6, §12.7, §12.8* — the four activation forms, channel bounds, preflight and commit, the three recharge identities, the ten `ACTION` facts, the five hybrid templates, and runtime persistence.

## 12.5 `SELF_STATUS` and the build

A `SELF_STATUS` Ability applies a Status to the player with **no roll** — self-application always succeeds — and the player may end it early by re-pressing the Ability input.

Only Statuses whose `targets` includes `PLAYER` are legal: `LIGHTENED`, `ANCHORED`, `SLIPPERY`, `PHASED`, `CONDUCTIVE`, and `BURNING`. The six `COGNITIVE` and `PERMISSION` Statuses are never self-applicable, because an Ability that blinds or silences the player is an Ability nobody equips.

| Profile | `duration` | Notes |
|---|---:|---|
| `self_brief` | `4.0` | Ends early on re-press |
| `self_sustained` | `10.0` | Ends early on re-press |

This is where the grammar becomes a build. `PHASED` on the player is traversal through tagged geometry. `ANCHORED` on the player is immunity to every impulse in the room, at the cost of not moving. `CONDUCTIVE` on the player makes them a link in an `ARC_PATH`, which is either a build or a mistake.

## 12.6 The compatibility matrix

| Family | `PRESS` | `HOLD` | `CHARGE_RELEASE` | `CHANNEL` | `RESOURCE` | `COOLDOWN` | `ACTION` |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| `STATUS_APPLICATOR` | ● | | ● | | ● | ● | ● |
| `STATUS_FIELD` | ● | | | ● | ● | ● | ● |
| `SELF_STATUS` | ● | ● | | | ● | ● | |
| `STATUS_TRANSFER` | ● | | | | ● | ● | ● |
| `PROJECTILE_ATTACK` | ● | | ● | | ● | ● | ● |
| `AREA_BURST` | ● | | ● | | ● | ● | ● |
| `BARRIER_GRANT` | ● | ● | | | ● | ● | ● |
| `PHYSICS_VERB` | ● | ● | | | ● | ● | |

`SELF_STATUS` cannot be `ACTION`: a Status the player needs for traversal, gated behind a combat verb, can strand them in a room with nothing to kill. Same reasoning as `PHYSICS_VERB` in Design 1 §12.9, and it matters more here because `PHASED` is a real movement option.

`STATUS_FIELD` may be `CHANNEL`, which is how a sustained conversion field is expressed: it pays per sample and ends when the player cannot pay.

---

# 13. MOBILITY

*Pinned: identical to Design 1 §13.1 through §13.6.*

---

# 14. PHYSICS ECHOES

*Pinned: identical to Design 1 §14.1 through §14.5* — four primitives, eligibility, behaviour, impact damage, and the rule that physics never gates progression.

`LIGHTENED` and `ANCHORED` change physics eligibility, exactly as in Design 1 §14.2, and here that interaction is load-bearing rather than incidental: `LIGHTENED` is how a `HEAVY` object becomes manipulable at all.

---

# 15. THE STATUS SYSTEM

## 15.1 The five target kinds

| Kind | What it is | Status persists |
|---|---|---|
| `ACTOR` | An enemy | Until expiry or death |
| `PLAYER` | The player | Until expiry or re-press (§12.5) |
| `OBJECT` | A carryable or physical object | Until expiry; survives being carried |
| `SURFACE` | A tagged face of world geometry | Until expiry; area is the struck face, capped at `6 × 6 m` |
| `VOLUME` | An authored region | Until expiry |

A Status lists which kinds it may target. Attempting it on a kind not in its list fails at §15.4 step 1, visibly.

## 15.2 The twelve base Statuses

Each carries a **sentence** — one short player-facing rule, per Player Authority §2.6 — which is printed verbatim in the HUD (§33.7).

### `KINETIC`

| Status | Duration | Chance | Targets | Sentence | Exact effect |
|---|---:|---:|---|---|---|
| `lightened` | `8.0 s` | `0.40` | actor, object, player | *"Lighter than it should be."* | `mass_class` drops one step; incoming impulse `×2.0`; wind and conveyors now affect it; becomes Physics-eligible if it was `HEAVY` |
| `anchored` | `4.0 s` | `0.30` | actor, object, player | *"Fixed in place."* | `mass_class` becomes `FIXED`; immune to all impulse, wind, conveyor, and Physics; actor movement speed `0.0`, attacks continue; player movement `0.0`, jump blocked, all other actions permitted |
| `slippery` | `10.0 s` | `0.45` | object, surface, player | *"Nothing holds."* | Friction `×0.10`; actors on a slippery surface retain `85%` of horizontal velocity per second with no input; objects slide freely; player ground acceleration `×0.35` |

### `COGNITIVE`

| Status | Duration | Chance | Targets | Sentence | Exact effect |
|---|---:|---:|---|---|---|
| `confused` | `5.0 s` | `0.30` | actor | *"Cannot tell friend from foe."* | Target selection ignores faction; retargets to nearest actor of any faction every `1.0 s` |
| `turncoat` | `8.0 s` | `0.15` | actor | *"Fighting for you now."* | `faction` becomes `PLAYER`; targets nearest `HOSTILE`; reverts at current Health; its kills credit to the player |
| `blinded` | `6.0 s` | `0.35` | actor | *"Cannot see past arm's reach."* | Perception range `40 m → 4 m`; loses its current target; cannot acquire a new one beyond `4 m`; ranged attacks are not attempted |

### `PERMISSION`

| Status | Duration | Chance | Targets | Sentence | Exact effect |
|---|---:|---:|---|---|---|
| `silenced` | `6.0 s` | `0.30` | actor | *"No special moves."* | Cannot use any ability or special attack; basic attacks continue |
| `rooted` | `5.0 s` | `0.35` | actor | *"Cannot walk."* | Cannot move under its own power; **can** still be pushed, pulled, and thrown, unlike `anchored`; attacks continue |
| `phased` | `6.0 s` | `0.25` | actor, object, surface, player | *"Passes through."* | Collision with actors disabled; collision with geometry tagged `phaseable` disabled; a `phased` **surface** is passable by everything; cannot be damaged and cannot deal damage while phased |

### `MATERIAL`

| Status | Duration | Chance | Targets | Sentence | Exact effect |
|---|---:|---:|---|---|---|
| `burning` | `6.0 s` | `0.35` | actor, object, surface, volume, player | *"On fire, and setting fire."* | Actor: `ai_state = PANIC`, no attacks, randomised movement. Any target with trait `burnable`: spawns a Fire Actor (§15.3). Emits light, radius `6.0 m`. Player: screen edge effect, no mechanical penalty |
| `conductive` | `10.0 s` | `0.40` | actor, object, surface, player | *"Carries a current."* | Electric hazards affect it at `×1.0` where they otherwise would not reach; forms a link with any contacting `conductive` target, propagating electric hazard contact between them, at most `4` links deep |
| `brittle` | `8.0 s` | `0.35` | **object, surface only** | *"About to give."* | Destructible Health `×0.5`; any non-null `breakable_at` halved; `bombable` and `breakable` surfaces additionally accept `MELEE`-tagged damage |

`brittle` is the one Status that touches a damage number, and it is restricted to `OBJECT` and `SURFACE` — things that are destroyed rather than killed. It can never appear on an actor, which is what keeps Law 27 and §30.3's "no damage soup" intact.

## 15.3 How `burning` produces damage without a Status dealing damage

*Pinned mechanism: identical to Design 1 §15.1's `burning`.* The Status sets AI state and ignites material. Damage comes from a **Fire Actor** — a separate world object with its own damage volume, lifetime, provenance, and hazard contract (Design 1 §25.2).

The structural rule, which every one of the twelve Statuses and eight compounds obeys:

> **No `StatusDefinition` or `CompoundDefinition` may reference the damage resolver.** A Status changes a rule; if damage follows, it follows because a *world object* — a Fire Actor, a hazard, a physics impact — did it, with its own provenance.

Test vector 21 measures this directly: every Status and every compound applied to an actor on inert ground leaves its Health untouched.

## 15.4 Application

```
effective_chance = clamp(
    base_chance + source_potency + susceptibility − resistance − adaptation,
    0.05, 0.95)
```

*Pinned: identical to Design 1 §15.2* for the term sources, the clamp, and the pity and adaptation economy, tracked per `(target, family)`.

The full pipeline, run at §8.9:

1. **Target legality.** The target's kind is in the Status's `targets`. Fail → visible rejection.
2. **Trait legality.** `requires_trait` is empty, or the target has at least one listed trait (§15.6). Fail → visible rejection.
3. **Cap.** The target has fewer than three active entries, **or** the incoming Status would form a compound with an existing one (§15.5). Fail → visible rejection.
4. **Already present.** If the Status is already active on the target, refresh its duration to full and stop. No roll, no pity change.
5. **Roll**, unless the source is `SELF_STATUS` or `STATUS_TRANSFER`, which never roll.
6. **On failure:** `susceptibility += 0.15`, capped `0.45`. Visible.
7. **On success:** `susceptibility = 0.0`; `adaptation += 0.20`, capped `0.50`; the Status is added.
8. **Compound check.** If the new Status forms a §15.5 pair with an existing one, both are consumed and the compound is added in their place.

Step 3's exception is important: a target at the cap can still receive a Status that *combines*, because combining reduces the entry count rather than raising it. Without it, a full target could never be improved.

## 15.5 The eight compounds

Only these eight pairs combine. The other `46` cross-family pairs coexist with no interaction, and same-family pairs never combine.

| Compound | Components | Duration | Targets | Sentence |
|---|---|---:|---|---|
| `updraft` | `lightened` + `burning` | `5.0 s` | actor, object | *"Rising on its own heat."* |
| `grounded` | `anchored` + `conductive` | `8.0 s` | actor, object, surface | *"Earthed. Current flows through it and past it."* |
| `spreading` | `slippery` + `burning` | `8.0 s` | surface, object | *"The fire is travelling."* |
| `arc_path` | `slippery` + `conductive` | `10.0 s` | surface | *"A current runs along it."* |
| `suspended` | `anchored` + `phased` | `6.0 s` | actor, object | *"Held out of the world."* |
| `shatterpoint` | `anchored` + `brittle` | `6.0 s` | **object, surface only** | *"One good hit."* |
| `helpless` | `confused` + `silenced` | `7.0 s` | actor | *"Lost, and out of tricks."* |
| `floundering` | `blinded` + `slippery` | `6.0 s` | actor | *"Blind and sliding."* |

### Exact effects

| Compound | Effect |
|---|---|
| `updraft` | Constant upward acceleration of `9.0 m/s²`, capped at `6.0 m/s` rise. An actor under `updraft` is airborne and therefore a legal `AIRBORNE_KILL`. Ends on expiry; the target falls normally. |
| `grounded` | Immune to all electric hazard damage. Becomes a permanent conduit node for the duration: any `conductive` target contacting it is also immune. This is the counter to `arc_path`, and the fact that it is *built from* two Statuses rather than handed out is the point. |
| `spreading` | The Fire Actor propagates along contiguous surfaces sharing the `slippery` Status, at `2.0 m/s`, to a maximum radius of `12.0 m` from origin. Propagation stops at any non-slippery surface. This is the only unbounded-looking effect in the system and its bound is the `12.0 m` radius, checked per Fire Actor. |
| `arc_path` | Electric hazard contact anywhere on the surface applies to every actor touching it, at most `4` actors, once per `0.5 s`. |
| `suspended` | The target is frozen in world space and non-collidable. It cannot act, be damaged, be moved, or be targeted. On expiry it resumes with zero velocity. A pure puzzle and control verb with no damage relationship at all. |
| `shatterpoint` | The next damage event of any magnitude destroys the object or surface outright. Objects only; never an actor. |
| `helpless` | No attacks, no abilities, movement randomised every `1.0 s` at `0.4 ×` base speed. |
| `floundering` | Movement is randomised and retains `95%` of velocity per second, producing genuine sliding; no attacks; perception `4 m`. |

**None of the eight modifies incoming or outgoing damage**, except `shatterpoint`, which applies only to objects and surfaces.

### Why eight and not fifty-four

§30.3 rejects *"mandatory composition knowledge."* Fifty-four combinations is a wiki page. Eight is a set a player meets in the first few hours and remembers, and §33.8 telegraphs each one on the target *before* it fires, so it is discoverable in play rather than memorised in advance.

The eight were chosen so that each is a **verb the player could not otherwise reach**: rising, earthing, spreading, conducting, suspending, shattering, disabling, and destabilising. A ninth compound that merely made something stronger would not have earned its place.

## 15.6 Susceptibility by material trait

Design 1 §25.0's six material traits, extended by three:

| Trait | Gates |
|---|---|
| `breakable` | — |
| `bombable` | — |
| `burnable` | `burning` |
| `grapple_compatible` | — |
| `rail_compatible` | — |
| `signal_blocking` | — |
| **`conductive_material`** | `conductive` |
| **`smooth`** | `slippery` |
| **`phaseable`** | `phased` on a surface |

A Status with a non-empty `requires_trait` can only land on a target carrying at least one of those traits. `burning` requires `burnable`; `conductive` requires `conductive_material`; `slippery` on a surface requires `smooth`; `phased` on a surface requires `phaseable`.

**Actors are exempt from trait gating.** Every actor can take every actor-legal Status, subject only to the roll. Trait gating exists so that the *world* is not uniformly susceptible — a stone floor does not burn, a wooden crate does — and applying it to enemies would recreate exactly the armour-matchup chart §30.3 rejects.

That distinction is the whole answer to "is this a resistance matrix?" It is not, because it never applies to the things you fight.

## 15.7 Immunity and substitution

*Pinned: identical to Design 1 §15.4* in structure — reduced expression first, higher resistance second, true immunity only where the effect is nonsensical.

| Target | Immune to | Substitution |
|---|---|---|
| Boss | `turncoat` | `confused`, same duration |
| Boss | `anchored` | `rooted`, same duration |
| Boss | `suspended` (compound) | Does not form; components remain separate |
| Turret (immobile) | `anchored`, `rooted`, `lightened` | none; attempt fails visibly |
| Fire Actor | all | none |
| `FIXED` object | `lightened` | none; attempt fails visibly |

Boss resistance is `0.40` across all four families, *pinned: identical to Design 1 §32.2*.

## 15.8 Required feedback

*Pinned: identical to Design 1 §15.5* for success, failure, substitution, and immunity feedback. Extended by §33.7 and §33.8, which are mandatory in this proposal rather than presentation polish.

---

# 16. GEAR AND MODS

*Pinned: identical to Design 1 §16.2 through §16.5* — Mod templates, compatibility, modifier order, and runtime clamps.

## 16.1 Gear

*Pinned: identical to Design 1 §16.1* for slots, tiers, and the one-high-tier restriction.

### 16.1.1 Four replaced intrinsics

| Territory | Legal intrinsic templates |
|---|---|
| `HEAD` | `INT_MARK_ON_HIT`, `INT_OVERCRIT_ADVANCES_ABILITY`, **`INT_STATUS_POTENCY`**, **`INT_READ_COMPOUNDS`**, `INT_CRIT_CHANCE` |
| `TORSO` | `INT_MAX_HEALTH`, `INT_BARRIER_ON_KILL`, `INT_DEFENSE`, `INT_RESOURCE_REGEN`, **`INT_STATUS_DURATION`** |
| `ARMS` | `INT_MELEE_DAMAGE`, `INT_RELOAD_SPEED`, `INT_PHYSICS_FORCE`, **`INT_TRANSFER_RANGE`**, `INT_INTERACT_RANGE` |
| `LEGS` | *Pinned: identical to Design 1 §16.1.* |

| Template | `SMALL` | `MEDIUM` | `LARGE` |
|---|---|---|---|
| `INT_STATUS_POTENCY` | `+0.05` chance | `+0.12` | `+0.20` |
| `INT_READ_COMPOUNDS` | Compound previews at `12 m` (§33.8) | `25 m` | `40 m` |
| `INT_STATUS_DURATION` | `+15%` duration on Statuses you apply | `+35%` | `+55%` |
| `INT_TRANSFER_RANGE` | `STATUS_TRANSFER` range `+20%` | `+45%` | `+75%` |

`INT_STATUS_DURATION` never extends a compound, only its components, and never applies to a Status the player carries on themselves.

---

# 17. FOREIGN ITEMS, ARCHIVE, AND MIGRATION

*Pinned: identical to Design 1 §17.1 through §17.6.* The only difference is the content of the enumerated lists Epsilon selects from — this document's §11, §12.1, and §15.2.

---

# 18. ECONOMY

*Pinned: identical to Design 1 §18.1, §18.2, §18.3.* Forge deferred, Epsilon Static banked, Coins and Signal Keys unchanged.

---

# 19. SIGNAL GRAPH

*Pinned: identical to Design 1 §19.1 through §19.6.*

---

# 20. INPUTS AND SENSORS

*Pinned: identical to Design 1 §20.1 through §20.4.*

## 20.5 Three Status-reactive sensors — new to Design 5

| Type | Output | Key parameters |
|---|---|---|
| `STATUS_SENSOR` | Boolean | `status_id`, `target_id` — `ON` while the named target carries the named Status |
| `STATUS_VOLUME_SENSOR` | Value `[0,15]` | `status_id`, `volume` — the count of targets in the volume carrying it, clamped |
| `COMPOUND_SENSOR` | Boolean | `compound_id`, `target_id` — `ON` while the target carries the named compound |

These are how the dungeon reads the verb layer. A door that opens while a specific crate is `CONDUCTIVE`, a bridge that extends while three actors in a room are `ANCHORED`, a gate that requires `SUSPENDED` on a particular object — each is a sensor feeding an ordinary Design 1 signal graph, and nothing in §19 needs to know Status exists.

**A mandatory route may never depend on a Status the player cannot guarantee.** §29.5 defines the rule, and it is the one place this proposal touches capability progression.

---

# 21. ACTUATORS AND MACHINERY

*Pinned: identical to Design 1 §21.1 through §21.9*, including §21.1.1's per-kind power-loss table.

---

# 22. HACKING

*Pinned: identical to Design 1 §22.1 through §22.3.*

---

# 23. PUZZLE-PACKAGE CONTRACT

*Pinned: identical to Design 1 §23.1 through §23.6*, with two added manifest fields and two added validation checks.

## 23.1 Added manifest fields

```
PackageManifest:
  ...                                        # Design 1 §23.1's fields
  status_required   : Id? = null             # a Status or compound a solution needs
  status_source     : Id? = null             # the in-room source guaranteeing it
```

A package whose solution requires a Status must name the in-room source that guarantees it — a hazard, a volume, a dispenser, or an authored applicator. **A puzzle never requires a Status only the player's loadout can supply**, which is what keeps this proposal out of the capability planner (§29.5).

## 23.5 Two added validation checks

| # | Check |
|---|---|
| 1–18 | *Pinned: identical to Design 1 §23.5.* |
| **19** | **A package with a non-null `status_required` has a non-null `status_source` in the same room, and that source is reachable and operable using base movement and the permanent baseline.** |
| **20** | **Every `requires_trait` a required Status needs is present on the target the package expects it on.** A `BURNING` puzzle whose target is a stone crate is rejected at composition, not discovered in play. |

---

# 24. THE SIXTEEN PUZZLE FAMILIES

Twelve pinned from Design 1 §24, four new and Status-based.

| # | Family | Origin |
|---|---|---|
| 1–12 | `CARRY_TO_PLATE`, `INSERT_COMPONENT`, `PULSE_REMOTE`, `TIMED_TRAVERSE`, `SHOOT_TARGET`, `TOGGLE_ROOM_STATE`, `HACK_OVERRIDE`, `DUAL_INPUT`, `ALTERNATE_INPUT`, `ROUTE_SWITCH`, `ENCOUNTER_GATE`, `LOCAL_KEY_LOOP` | *Pinned: identical to Design 1 §24.* |
| 13 | **`STATUS_GATE`** | A `STATUS_SENSOR` on a specific object gates an output. The player must get that Status onto that object from a source in the room. |
| 14 | **`CONDUCTION_ROUTE`** | An electric source, a receiver, and a gap. The player makes a path of `conductive` objects or surfaces, or builds an `arc_path`, to close it. |
| 15 | **`PHASE_PASSAGE`** | A `phaseable` wall between the player and the objective. The room provides a `phased` source; the player applies it to the wall, or to themselves. |
| 16 | **`COMPOUND_LOCK`** | A `COMPOUND_SENSOR` requiring a specific compound on a specific object. The room provides both components separately, and the player must combine them on the right target. |

`COMPOUND_LOCK` is the family that makes this proposal a design rather than a mechanic. A room containing a `burnable` crate, a fire source, and a lightening field, whose exit needs `updraft` on that crate, is a puzzle in a language the player already learned in combat.

**Cut:** `BOMB_BARRIER`, `MOVING_MACHINE`, `A_B_STATE`, `DUNGEON_STATE_CHANGE`, `OBSERVATION_TARGET`, `MULTI_STAGE_MACHINE`. The mechanisms all remain, pinned from Design 1 §21, §25, and §28; §38 covers the three authority tests that lose their fixture.

---

# 25. HAZARDS AND DESTRUCTION

*Pinned: identical to Design 1 §25.1 through §25.5* — the hazard contract, six families, four destructible classes, environmental kill credit, and enemy participation.

## 25.6 Material traits — modifies Design 1 §25.0

Design 1's six traits plus the three in §15.6: `conductive_material`, `smooth`, `phaseable`. Nine total.

Untagged geometry remains indestructible and now also **Status-inert**: a surface with none of the nine traits takes no Status at all.

## 25.7 Status-applying hazards

Each of Design 1's six hazard families gains a Status it applies on contact, at a fixed chance, which is how a room supplies the Statuses §23.1 requires:

| Hazard | Applies | Chance |
|---|---|---:|
| `FLAME_JET` | `burning` | `0.50` |
| `ELECTRIC_FIELD` | `conductive` | `0.45` |
| `CRUSHER` | none | — |
| `BLADE` | none | — |
| `FALLING_DEBRIS` | none | — |
| `FIRE_ACTOR` | `burning` | `0.40` |

Two additions, which exist so that `slippery` and `phased` have room sources:

| Hazard | `damage` | `tick_interval` | `telegraph` | Applies | Chance |
|---|---:|---:|---:|---|---:|
| `COOLANT_VENT` | `0.0` | — | `0.8` | `slippery` | `0.60` |
| `PHASE_EMITTER` | `0.0` | — | `1.0` | `phased` | `0.55` |

Both deal zero damage. They are hazards structurally — signal-controlled volumes with telegraphs — and dispensers functionally. A `COOLANT_VENT` that makes a floor `slippery` is a trap in a combat room and a tool in a puzzle room, which is exactly the cross-pollination Dungeon Authority §3.5 asks for.

---

# 26. ROUTING, FORCES, AND CONSTRAINTS

*Pinned: identical to Design 1 §26.1 through §26.5.*

Wind and conveyors interact with `lightened` and `anchored` exactly as Design 1 §26.2 and §26.3 specify, by mass class. Here that is a designed interaction rather than an incidental one: `lightened` is how a `HEAVY` object becomes wind-movable.

---

# 27. MEDIA

*Pinned: identical to Design 1 §27.1 through §27.4.*

---

# 28. ROOM AND ZONE TOPOLOGY

*Pinned: identical to Design 1 §28.1 through §28.7.*

---

# 29. CAPABILITY PROGRESSION

*Pinned: identical to Design 1 §29.1 through §29.4.* Four capabilities; Status grants none.

## 29.5 Status is never a capability

**No Status, compound, or Status-applying item is a semantic capability**, and no mandatory route or puzzle solution may depend on one the player supplies.

Every required Status comes from an in-room source named in the package manifest (§23.1) and validated by §23.5 check 19. A player with no Status-applying items whatsoever completes every mandatory route in the game.

This is the same position Design 1 takes on physics (§14.5), and it is taken for the same reason: making the verb layer a progression requirement would put the capability planner in the business of reasoning about `12` Statuses and `8` compounds across `5` target kinds, and every generated Zone would carry that proof burden.

The cost is real and §41.2 records it: **a Status build makes the game easier and more expressive, but never opens a route that is otherwise closed.**

---

# 30. PROCEDURAL COMPOSITION

*Pinned: identical to Design 1 §30.1 through §30.8*, with §24's family list and this `PURPOSE_ROTATION`:

`[traversal, arena, status_puzzle, traversal, ranged_arena, environmental_puzzle, junction, status_puzzle, holdout, vertical_ascent, gauntlet, arena, status_puzzle, routing_puzzle, traversal, boss_arena]`

`status_puzzle` is a new purpose hosting families 13–16, and it appears three times in the rotation, which puts roughly one Status puzzle every five rooms.

---

# 31. CROSS-SYSTEM COMPATIBILITY

*Pinned: identical to Design 1 §31*, with these rows added or changed:

| A × B | Result |
|---|---|
| `lightened` × wind, conveyor, physics | Reduced mass class applies to all three |
| `anchored` × wind, conveyor, physics, impulse | No effect on the target |
| `anchored` × `rooted` | Coexist; `anchored` is strictly stronger and subsumes it behaviourally |
| `slippery` × any actor standing on it | `85%` horizontal velocity retained per second with no input |
| `burning` × `burnable` | Spawns a Fire Actor (§15.3) |
| `burning` × non-`burnable` | Status applies to an actor; no Fire Actor; no damage of any kind |
| `conductive` × `ELECTRIC_FIELD` | Hazard reaches the target and every linked `conductive` target, `4` links deep |
| `conductive` × `grounded` | `grounded` blocks propagation entirely |
| `phased` × geometry tagged `phaseable` | Passable |
| `phased` × untagged geometry | Solid; `phased` never opens arbitrary walls |
| `phased` × damage | Cannot damage or be damaged while phased |
| `brittle` × actor | **Impossible**; `brittle` targets only objects and surfaces |
| `shatterpoint` × actor | Impossible for the same reason |
| `spreading` × non-contiguous surfaces | Propagation stops; hard cap `12.0 m` radius |
| `arc_path` × more than 4 actors | Only the nearest `4` are affected |
| `suspended` × damage, targeting, movement | All impossible on the target for the duration |
| Any Status × a target at the three-entry cap | Rejected, unless it forms a compound |
| Any compound × transfer | Compounds cannot be transferred |
| Status × save, death, room unload | All `EPHEMERAL`; cleared |
| Status × capability planner | No interaction; Status is never a capability (§29.5) |

---

# 32. ENEMIES AND ENCOUNTERS

*Pinned: identical to Design 1 §32.1 through §32.7.*

## 32.8 Status-compatible AI

Every archetype responds to every actor-legal Status and compound:

| Condition | AI response |
|---|---|
| `burning` | `PANIC`; no attacks; randomised movement |
| `lightened`, `anchored` | No AI change; physical response only. `anchored` sets speed `0.0`; attacks continue |
| `confused` | Retarget nearest actor of any faction every `1.0 s` |
| `turncoat` | Faction `PLAYER`; targets nearest `HOSTILE` |
| `blinded` | Perception `4 m`; no ranged attempts |
| `silenced` | No abilities; basic attacks continue |
| `rooted` | Speed `0.0`; attacks continue; still pushable |
| `phased` | Cannot attack or be attacked; movement continues |
| `conductive` | No AI change |
| `updraft` | Airborne; `DISPLACED`-equivalent: no actions until grounded |
| `helpless` | No attacks, no abilities, randomised movement at `0.4×` |
| `floundering` | No attacks; sliding movement |
| `suspended` | Removed from the encounter entirely for the duration; does not count as cleared |

`suspended` not counting toward encounter clear is deliberate: suspending the last enemy must not complete the encounter, or `suspended` becomes a win button.

---

# 33. HUD AND PRESENTATION

*Pinned: identical to Design 1 §33.1 through §33.6.*

Presentation is not polish in this proposal. A game whose verb layer is invisible is a game of guesswork, and §33.7 through §33.9 are mandatory.

## 33.7 Reading Status

Every target carrying a Status shows, in world space:

| Element | Rendering |
|---|---|
| Per-Status marker | A distinct **shape** per family — `KINETIC` angular, `COGNITIVE` rounded, `PERMISSION` barred, `MATERIAL` irregular — with a per-Status glyph inside it |
| Remaining duration | The marker depletes around its edge |
| Family | Shape, never colour alone |
| Applied by the player | A small tick on the marker; Statuses the player did not cause lack it |
| Sentence | On focus, the Status's `sentence` from §15.2 prints beside the target, verbatim |

The sentence printing verbatim is the mechanism that makes twelve Statuses learnable. *"Nothing holds."* under a `slippery` marker teaches the rule in one reading, and it is the same six words every time.

## 33.8 Compound telegraphing

**When a target carries one component of a §15.5 pair, the marker for that Status displays a compound hint**: the other component's glyph, dimmed, alongside the compound's glyph.

A player who has applied `lightened` to a crate sees, on that crate, a dimmed flame and an `updraft` glyph. They have not been told what `updraft` does — but they have been told that fire plus this equals *something*, which is exactly enough to make them try it.

This is what replaces the wiki page §30.3 rejects. The combination table is not memorised; it is **printed on the target, at the moment it becomes relevant**, and only for the pair the player is one step away from.

`INT_READ_COMPOUNDS` (§16.1.1) extends the range at which hints are visible; it never reveals anything a closer player would not see.

## 33.9 The transfer selector

`STATUS_TRANSFER` (§12.3) on a source carrying more than one Status opens a radial at the source showing each, with its glyph and sentence. Selecting one and then a destination completes the transfer.

The radial pauses nothing. It is a `0.25 s` cast, and the player is fully vulnerable throughout.

---

# 34. PLAYER-FACING FLOW

*Pinned: identical to Design 1 §34.1 through §34.12.*

## 34.11 Status rejection feedback

Added to Design 1 §34.9's table:

| Refusal | Feedback |
|---|---|
| Target kind illegal for this Status | The target outlines in the rejection treatment for `0.4 s`; the Status glyph shows struck through |
| Target lacks the required trait | Same, plus the required trait named beside the target |
| Target at the three-entry cap | The target's three markers pulse in sequence |
| Roll failed | Design 1 §15.5's "resisted" treatment; the susceptibility meter on the target visibly advances |
| Transfer destination illegal | The destination outlines struck through; the source keeps its Status |
| Transfer of a compound attempted | The compound's marker pulses with a distinct refusal cue |
| Boss substitution occurred | The substituted Status's marker appears with a distinct substitution cue |

Every one of these is visible on the **target**, not in a corner of the HUD, because in this proposal the target is where the player is looking.

---

# 35. PERFORMANCE BUDGETS

*Pinned: identical to Design 1 §35* for every runtime budget, plus:

| Quantity | Budget |
|---|---:|
| `ActiveStatus` entries per target | `3` |
| Targets carrying Status, per room | `40` |
| Total `ActiveStatus` entries per room | `90` |
| Status-carrying surfaces per room | `16` |
| Surface Status area | `6 × 6 m` per face |
| `spreading` propagation radius | `12.0 m` from origin |
| `conductive` link depth | `4` |
| `arc_path` affected actors | `4` |
| Fire Actors per room | `6` — *pinned: identical to Design 1 §35* |
| Status ticks per second | `1` — every Status evaluates at `1 Hz`, not per frame |

The `1 Hz` tick is the single most important performance decision here. Statuses change rules, and a rule change does not need to be re-evaluated sixty times a second; it needs to be applied once and read continuously. `90` entries at `1 Hz` is `90` evaluations per second, which is nothing.

**Exception:** duration countdown and marker depletion are presentation and run per frame. They never gate the mechanical tick.

---

# 36. DEBUGGING AND INSPECTION

*Pinned: identical to Design 1 §36*, plus:

| Inspectable | Content |
|---|---|
| Status registry | Every `ActiveStatus` in the room: status, target kind, target, remaining, applier |
| Per-target state | Active entries, susceptibility and adaptation per family, and the cap |
| Compound proximity | Every target one component away from a §15.5 pair, and which |
| Trait map | Every surface and object's material traits, and which Statuses they admit |
| Application log | The last 100 attempts: source, target, each §15.4 step's result, final outcome |
| Propagation | Live `spreading` fronts with origin and radius, and `conductive` link chains with depth |
| Damage provenance | Every damage event whose source traces to a Status-spawned world object |

The application log is the one that matters. "Why did that not apply?" is the question this proposal generates most, and the log answers it with the exact step that failed.

---

# 37. REFERENCE FIXTURES

## 37.1 Puzzle fixtures

*Pinned: identical to Design 1 §37 fixtures 1–11, 13, 16* — the twelve retained families, in the same `20 × 20 × 6 m` test shell. Fixture 19, the certified fallback Zone, is *pinned: identical to Design 1 §37 fixture 19*, with its package list restricted to families 1–12 and **containing no Status puzzle at all** — the fallback must be completable by a player who never applies a Status.

## 37.2 Status-family fixtures

| # | Fixture | Setup | Solution |
|---|---|---|---|
| S1 | `fx_status_gate` | Stone crate at `(4,0,4)` with trait `conductive_material`; `ELECTRIC_FIELD` hazard at `(8,0,8)`; `STATUS_SENSOR` for `conductive` on that crate gates a door at `(18,0,12)` | Push the crate through the field; it takes `conductive`; the door opens while it lasts |
| S2 | `fx_conduction_route` | Electric source at `(3,2,10)`; receiver at `(17,2,10)`; three `conductive_material` crates; gap `14 m` | Chain the crates within contact distance; current propagates `4` links; receiver fires |
| S3 | `fx_phase_passage` | `phaseable` wall at `(10,0,0)`–`(10,0,20)`; `PHASE_EMITTER` at `(4,0,4)`; objective beyond | Stand in the emitter to take `phased`, then walk through — or apply `phased` to the wall if the loadout can |
| S4 | `fx_compound_lock` | `burnable` crate at `(5,0,5)`; `FLAME_JET` at `(9,0,5)`; a `lightened` volume at `(5,3,5)`; `COMPOUND_SENSOR` for `updraft` on that crate gates a ceiling hatch at `(10,6,10)` | Ignite the crate, carry or push it into the lightening volume; `updraft` forms; the crate rises; the hatch opens |

S4 is the acceptance target for the whole proposal. It requires the player to have learned that fire plus light equals rising, and §33.8 taught them by showing the hint on the crate the moment it was `lightened`.

## 37.3 Compound fixtures

One per compound, in a `12 × 12 × 8 m` shell, each asserting formation, effect, and expiry.

| # | Compound | Assertion |
|---|---|---|
| K1 | `updraft` | A `140 kg` crate under `updraft` rises at `6.0 m/s` capped, is airborne, and falls normally on expiry |
| K2 | `grounded` | A `grounded` actor takes `0` damage from `ELECTRIC_FIELD`, and a `conductive` actor touching it also takes `0` |
| K3 | `spreading` | Fire propagates at `2.0 m/s` along contiguous `slippery` surfaces, stops at the first non-slippery face, and never exceeds `12.0 m` from origin |
| K4 | `arc_path` | Electric contact affects exactly the nearest `4` actors touching the surface, once per `0.5 s` |
| K5 | `suspended` | The target cannot be damaged, moved, targeted, or act; resumes with zero velocity; does **not** count toward encounter clear |
| K6 | `shatterpoint` | The next damage of any magnitude destroys the object; cannot be applied to any actor |
| K7 | `helpless` | No attacks, no abilities, movement randomised at `0.4×` |
| K8 | `floundering` | No attacks, `95%` velocity retention, perception `4 m` |

Every compound fixture additionally asserts that **both components were consumed** at formation and that the target's entry count went from `2` to `1`.

## 37.4 The negative fixture set

Four that must **fail**, checked in as negative tests:

| # | Fixture | The trap | Expected |
|---|---|---|---|
| N1 | `fx_bad_status_gate` | A `STATUS_GATE` requiring `burning` on a **stone** crate | Rejected at §23.5 check 20 |
| N2 | `fx_bad_no_source` | A `COMPOUND_LOCK` whose room provides only one component | Rejected at §23.5 check 19 |
| N3 | `fx_bad_loadout_gated` | A mandatory route requiring `phased`, with no in-room source | Rejected at §23.5 check 19 |
| N4 | `fx_bad_brittle_actor` | `brittle` applied to a `SKIRMISHER` | Rejected at §15.4 step 1; `brittle` has no `ACTOR` target |

---

# 38. TEST VECTORS

## Pinned systems
1. Every Design 1 vector covering a pinned section passes unchanged. A failure in any is a failure of a pin, not of a new system.

## The Status pipeline
2. §15.4's eight steps execute in order; a failure at any step produces the §34.11 feedback naming that step's reason.
3. A Status attempted on a target kind not in its `targets` fails at step 1, across all `12 × 5 = 60` combinations.
4. A Status with a non-empty `requires_trait` fails at step 2 on a target lacking every listed trait.
5. Actors are exempt from trait gating: every actor-legal Status can land on every archetype, subject only to the roll.
6. A target at three entries rejects a fourth non-combining Status, and **accepts** one that forms a compound.
7. Re-applying an active Status refreshes duration to full, does not roll, and does not change susceptibility.
8. A failed roll raises `susceptibility` by `0.15`, capped `0.45`; a success zeroes it and raises `adaptation` by `0.20`, capped `0.50`.
9. `effective_chance` never leaves `[0.05, 0.95]` across every archetype, potency, pity, and adaptation combination.
10. `SELF_STATUS` and `STATUS_TRANSFER` never roll and always land when steps 1–3 pass.

## The twelve Statuses
11. Each of the twelve produces exactly the effect in §15.2, measured: mass class change, movement speed, friction, perception range, ability permission, collision, and AI state.
12. `anchored` makes a target immune to impulse, wind, conveyor, and all four physics primitives.
13. `rooted` prevents self-movement but **permits** being pushed, pulled, and thrown — the distinction from `anchored`.
14. `phased` passes through `phaseable` geometry and **not** through untagged geometry.
15. `phased` targets can neither damage nor be damaged for the duration.
16. `slippery` retains `85%` horizontal velocity per second with no input.
17. `brittle` cannot be applied to any actor, across all six archetypes (N4).
18. `burning` on a non-`burnable` actor deals exactly `0` damage over its full duration.
19. `burning` on a `burnable` target spawns a Fire Actor whose damage credits to the applier.
20. `conductive` links propagate at most `4` deep.
21. Apply each of the twelve Statuses, and then each of the eight compounds, to a `SKIRMISHER` (60 Health) standing on non-`burnable`, non-`conductive_material` floor in an otherwise empty room, and wait out every full duration. **Expected Health after all twenty: exactly `60.0`.** Repeat against a `BRUISER` and an `ARMORED`: `180.0` and `140.0`, unchanged. The only Status and compound that alter a damage number, `brittle` and `shatterpoint`, cannot be applied to any actor and so cannot appear in this test at all (vectors 17 and 28).

## The eight compounds
22. Exactly `8` of the `54` cross-family pairs combine; the other `46` coexist with no interaction, verified exhaustively.
23. Same-family pairs never combine, across all `12` same-family pairs.
24. Compound formation consumes both components; the entry count goes `2 → 1`.
25. Each compound produces exactly the effect in §15.5 (fixtures K1–K8).
26. A compound cannot be transferred (§12.3).
27. `suspended` on the last enemy does **not** complete the encounter.
28. `shatterpoint` cannot form on an actor, because `brittle` cannot.
29. `spreading` never exceeds `12.0 m` from origin and stops at non-contiguous surfaces.
30. `grounded` blocks `conductive` propagation entirely.

## Transfer and self-application
31. `STATUS_TRANSFER` moves a Status at full remaining duration with no roll.
32. Transferring onto a capped target fails and the source keeps its Status.
33. A transfer completing a §15.5 pair on the destination forms the compound normally.
34. `SELF_STATUS` is legal only for the six `PLAYER`-legal Statuses; the other six are rejected at load.
35. Re-pressing a `SELF_STATUS` input ends it early.
36. Enemies never apply Status to the player, across 10,000 simulated encounters.

## Puzzles and progression
37. Every package with a non-null `status_required` names an in-room `status_source` reachable with base movement and the permanent baseline (§23.5 check 19).
38. Every required Status's `requires_trait` is satisfied by the target the package expects (check 20).
39. Each of N1–N4 fails its named check and passes the others where applicable.
40. Across 10,000 Zones, no mandatory route depends on a Status the player must supply.
41. The fallback Zone contains no Status puzzle and is completable by a player who applies no Status at all.
42. A player with zero Status-applying items completes every mandatory route in 10,000 generated Zones.

## Presentation
43. Every active Status shows a family-shaped marker with a per-Status glyph, distinguishable with hue removed.
44. Focusing a target prints each Status's `sentence` verbatim, identically every time.
45. A target one component from a §15.5 pair shows the compound hint (§33.8), and shows it for no other pair.
46. `INT_READ_COMPOUNDS` extends hint range and reveals nothing a closer player would not see.
47. The transfer radial lists every Status on the source with glyph and sentence, and pauses nothing.

## Performance
48. Statuses evaluate at `1 Hz`, not per frame; duration display runs per frame and never gates the tick.
49. A room at budget — `40` Status-carrying targets, `90` entries, `16` surfaces — holds frame time within the platform target.
50. `ActiveStatus` entries never exceed `3` per target or `90` per room.

## Gaps closed by the §39 traceability pass
51. A `REACTIVE_BARREL` damages valid actors and chains at most `5` links; a `bombable` wall responds to explosive damage and an untagged wall does not.
52. A Zone flag set in one room propagates to dependent machinery in later rooms, survives unload and reload, and is never cleared.
53. A boss takes `confused` where `turncoat` was attempted and `rooted` where `anchored` was attempted, at the durations in §15.7, rather than a blanket immunity; `suspended` does not form on a boss and its components remain separate; a `TURRET` fails `anchored`, `rooted`, and `lightened` visibly.

---

# 39. TRACEABILITY

All 142 acceptance tests named by the two source authorities, mapped to the coverage that closes them. Notation follows Design 2 §39.

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
| P10 | Player-facing bindings are rebindable without changing semantic slot roles. | D1 V 17, 18 |
| P11 | Static + three Weapon Echoes produce four valid cycle states. | D1 V 19 |
| P12 | Empty slots are skipped. | D1 V 20 |
| P13 | Switching away from a partial magazine does not refill it. | D1 V 21 |
| P14 | Switching away from Heat does not clear it. | D1 V 22 |
| P15 | Switching does not activate inactive Weapon passives. | D1 V 25 |
| P16 | A selected Weapon remains useful without another Weapon acting as mandatory primer. | D1 V 27 |
| P17 | Resource Ability cannot overspend its pool. | D1 V 35 |
| P18 | Multi-charge Cooldown recharges predictably and serially. | D1 V 36 |
| P19 | Action recharge advances only on declared facts/metrics. | D1 V 37 |
| P20 | Failed preflight spends nothing. | D1 V 35, 38 |
| P21 | Post-commit miss receives no implicit refund. | D1 V 39 |
| P22 | Recharge modifiers cannot create an unbounded self-feed loop. | D1 V 40, 41 |
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
| P41 | Status cannot directly or indirectly schedule periodic Health damage. | V 18, 21 |
| P42 | Failed chance-based Status attempt visibly increases bounded susceptibility. | V 8 |
| P43 | Successful Status application increases temporary adaptation. | V 8 |
| P44 | Strong enemies can resist more without every effect becoming blanket `IMMUNE`. | V 53 |
| P45 | World fire may damage independently from `BURNING`. | V 19 |
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
| D7 | A conduit state is understandable without relying only on color. | D1 V 102 |
| D8 | AND requires both inputs. | D1 fx 8 |
| D9 | OR accepts either input. | D1 fx 9 |
| D10 | Timed state visibly communicates remaining urgency. | D1 V 103 |
| D11 | Latch persists according to package semantics. | D1 V 108 |
| D12 | Signal reset restores initial state. | D1 V 109 |
| D13 | A powered door opens. | D1 fx 1 |
| D14 | Removing power closes safely. | D1 V 110 |
| D15 | A player in the doorway is not silently crushed by a non-hazard door. | D1 V 110 |
| D16 | A persistent shortcut remains unlocked after room revisit. | D1 fx 16 |
| D17 | A topology transformation never removes every valid progression route unintentionally. | D1 V 111 |
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
| D35 | Rail branch switch selects a physically valid route. | D1 fx 10 |
| D36 | LaunchPad source/landing remains valid. | D1 V 116 |
| D37 | Grapple target exists within an audited grapple opportunity. | D1 V 117 |
| D38 | Moving platform does not strand required progression. | D1 V 111 |
| D39 | Hazard damage uses common damage road. | D1 V 119 |
| D40 | Hazard telegraphs before unavoidable contact where appropriate. | D1 V 140 |
| D41 | Hazard can affect enemies if package says it can. | D1 V 120 |
| D42 | Hazard controller correctly disables/enables it. | D1 V 121 |
| D43 | Reset restores hazard phase safely. | D1 V 141 |
| D44 | Reactive barrel damages valid actors. | V 51 |
| D45 | Bombable wall responds to tagged explosive. | V 51 |
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
| D61 | Generator state propagates to dependent room. | V 52 |
| D62 | Cross-room state survives unload/reload. | D1 V 126 |
| D63 | Dependency chain remains reachable. | D1 V 127 |
| D64 | Dungeon macro-state cannot create an accidental progression cycle. | D1 V 127, 128 |
| D65 | Puzzle reset affects only its declared reset group. | D1 V 129 |
| D66 | Completed AP Check is not undone by puzzle reset. | D1 V 130 |
| D67 | Persistent shortcut is not undone by local reset. | D1 fx 16 |
| D68 | Temporary projectiles and signals are cleared. | D1 V 131 |
| D69 | Critical active/inactive state is distinguishable without color alone. | V 43 |
| D70 | Required sound cue has visual equivalent. | D1 V 106 |
| D71 | A distant controlled output can be inferred from input. | D1 V 101 |
| D72 | Wrong-sequence failure communicates the error. | D1 V 107 |
| D73 | Same seed/package produces same initial composition. | D1 V 81 |
| D74 | Decorative randomness does not alter solvability. | D1 V 81 |
| D75 | Package audit produces stable results. | D1 V 132 |
| D76 | Inactive physics objects sleep. | D1 V 133 |
| D77 | Large room does not keep unlimited projectiles alive. | D1 V 134 |
| D78 | Beam routing has bounded complexity. | D1 V 135 |
| D79 | Signal update is event-driven where practical. | D1 V 136 |
| D80 | Debug view can identify active semantic state without inspecting scene internals manually. | D1 V 137 |

## 39.3 Coverage

| | Count |
|---|---:|
| Authority acceptance tests | 142 |
| Covered by a Design 5 test vector | 9 |
| Covered through a pin to Design 1 | 124 |
| Not applicable — system deferred by §2.2 | 9 |
| **Uncovered** | **0** |

At 9 of 133 applicable tests, Design 5 rewrites a small share of the acceptance surface — but *which* rows it rewrites is the point. **P41** (Status cannot directly or indirectly schedule periodic Health damage), **P42** and **P43** (visible pity and adaptation), **P44** (strong enemies resist without blanket immunity) and **P45** (world fire damages independently of `BURNING`) are the five tests the Player Authority wrote specifically about Status, and this is the only proposal where all five are closed by its own machinery rather than by inheriting someone else's.

The nine deferred tests are D48–D52 and D53–D56, the same nine every proposal defers. Water is a genuine loss here, being the natural surface for both `conductive` and `slippery`.

---

# 40. IMPLEMENTATION WAVES

| Wave | Contents | Vectors |
|---|---|---|
| 1 | Everything pinned from Design 1 waves 1–8 and 10–20: input, movement, damage, hosts, Weapons, Abilities, Mobility, interaction, physics, Gear, and the whole dungeon | 1 |
| 2 | Status data model: the twelve definitions, five target kinds, `ActiveStatus`, the three-entry cap | 3, 6, 50 |
| 3 | Material traits and susceptibility gating | 4, 5 |
| 4 | The §15.4 application pipeline, with pity and adaptation | 2, 7–10 |
| 5 | The twelve base effects, measured individually | 11–20 |
| 6 | The no-damage rule and its static analysis | 21 |
| 7 | **The eight compounds**, formation, consumption, and effects | 22–30 |
| 8 | `STATUS_TRANSFER` and `SELF_STATUS` | 31–36 |
| 9 | Status-reactive sensors and the two zero-damage hazards | fixtures S1–S4 |
| 10 | The four Status puzzle families and §23.5's two checks | 37–39 |
| 11 | The negative fixture set N1–N4 | 39 |
| 12 | Composition with `status_puzzle` purposes | 40–42 |
| 13 | **Presentation**: markers, sentences, compound hints, the transfer radial | 43–47 |
| 14 | Performance: the `1 Hz` tick, budgets, propagation caps | 48–50 |
| 15 | Debug: registry, application log, propagation view | — |
| 16 | The two families whose fixtures were cut | 51, 52 |

**Build wave 13 with wave 7, not after it.** Compounds without the §33.8 hint system are undiscoverable, and a playtest of compounds without telegraphing measures the wrong thing entirely — it measures whether testers read the design document. This is the one proposal where deferring presentation invalidates the feature it is deferring behind.

Waves 2–7 are the critical path and are strictly sequential.

---

# 41. CLOSURE STATEMENT

## 41.1 What this proposal decided

1. **Status is the verb layer**, applied to five target kinds — actor, player, object, surface, volume — covering all thirteen alterations Player Authority §20.1 permits.
2. **Twelve base Statuses in four families**, each with a one-sentence player-facing rule printed verbatim in the HUD.
3. **Eight compounds out of fifty-four possible cross-family pairs.** The other forty-six coexist with no interaction, and same-family pairs never combine.
4. **A compound consumes its components**, so combining always reduces a target's entry count. The system cannot grow unbounded.
5. **Three active entries per target, maximum**, because four simultaneous rule changes is not something a player can reason about.
6. **No Status or compound modifies a damage number**, except `brittle` and `shatterpoint`, which apply only to objects and surfaces — things destroyed rather than killed. §15.3's structural rule is statically checkable.
7. **Compound hints are printed on the target** (§33.8), which is what replaces the wiki page §30.3 rejects. The player is told they are one step from *something*, never what.
8. **Trait gating applies to the world and never to actors** (§15.6), which is the precise reason this is not the armour-matchup chart §30.3 forbids.
9. **Status is never a capability** (§29.5). Every required Status has an in-room source, validated at composition.
10. **Enemies never apply Status to the player.** Every Status the player carries is self-applied or walked into.
11. **`STATUS_TRANSFER` makes Status a resource** rather than only an effect, and is the family this proposal is built around.
12. **`SELF_STATUS` makes it a build**: `phased` is traversal, `anchored` is impulse immunity, `conductive` is either a build or a mistake.
13. **Statuses tick at `1 Hz`**, not per frame. A rule change is applied once and read continuously.
14. **Everything Status is `EPHEMERAL`.** Nothing survives a save, a death, or a room unload.
15. **Two zero-damage hazards** — `COOLANT_VENT` and `PHASE_EMITTER` — exist so `slippery` and `phased` have room sources, and are traps in combat rooms and tools in puzzle rooms.
16. **Four negative fixtures that must fail**, including a `brittle` actor and a loadout-gated mandatory route.

## 41.2 What this proposal sacrificed

| Sacrifice | What is lost |
|---|---|
| **Weapon and Ability variety** | Five Weapon families and eight Ability families, half of the latter existing only to deliver Status. Combat texture comes almost entirely from the verb layer; a player who dislikes it has little else. |
| **Status builds opening routes** | §29.5 means a Status build makes the game easier and more expressive but never opens a closed route. The same trade Design 3 makes with signal verbs, and it is a real limit on how much the build can matter. |
| **Forge** | *Pinned from Design 1.* Design 4 ships it; this does not. |
| **Water** | The natural home for `conductive` and `slippery`, and a thirteenth Status (`frozen`) that would have written itself. |
| **Compositional generation** | Design 4's territory. Items here are Design 1's profiles with a Status slot. |
| **Reversible macro state, constraint simulation** | Designs 3 and 2 respectively. |
| **Two puzzle families** | `OBSERVATION_TARGET` and `MULTI_STAGE_MACHINE`, plus four more cut in §24. |
| **Status persistence** | Everything clears on death. Assembling a compound on a boss and dying loses it. |
| **Simple presentation** | Marker shapes, per-Status glyphs, sentences, compound hints, and a transfer radial are all mandatory. This proposal has the largest UI surface of the five and cannot ship without it. |

## 41.3 Proposal-level choices the authorities did not mandate

- Exactly twelve Statuses and exactly eight compounds.
- Which eight pairs combine, and that combining consumes.
- The three-entry cap.
- Trait gating applying to the world and not to actors.
- `brittle` and `shatterpoint` being object-only, which is the whole reason the no-damage rule survives.
- `STATUS_TRANSFER` existing at all.
- Compound hints being shown one step early rather than not at all or fully.
- Statuses being `EPHEMERAL` rather than persisted.
- The `1 Hz` tick.

## 41.4 Where this proposal disagrees with an authority

**Nowhere**, and §0.1 names the two traps it was most at risk of falling into, each with the mechanism that avoids it.

One thing deserves flagging rather than burying: `brittle` halves an object's destructible Health, and `shatterpoint` destroys an object outright. Both touch a damage number, which is exactly what Law 27 and §30.3 exist to prevent. They are permitted here because **neither can ever apply to an actor** — `brittle`'s `targets` list contains no `ACTOR` entry, and a compound cannot form from a component that cannot apply. An object is destroyed, not killed; it has no Health bar the player reads, no death, and no kill credit. If an owner considers that too close to the line, deleting `brittle` costs one Status and one compound and nothing else in the design depends on it.

## 41.5 The claim

**Every acceptance test named by the two source authorities is covered.** §39 maps all 142: 9 to a Design 5 vector, 124 through an explicit pin to Design 1, 9 to a recorded deferral. None is uncovered.

The five the Player Authority wrote specifically about Status — P41 through P45 — are closed here by this proposal's own machinery rather than by inheritance, which is the only place among the five proposals where that is true.

**There are no intentionally open behavioral decisions in this proposal.**

Anything not described here is one of: pinned to a named Design 1 section; inherited from the authorities and listed in §1; rejected by a closed schema in §4; explicitly deferred in §2.2; or an engineering decision belonging to the implementer.

---

**End of Complete Design 5: Status As Grammar**
