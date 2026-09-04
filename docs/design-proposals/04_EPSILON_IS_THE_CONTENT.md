# ARCHIPEPSI — COMPLETE DESIGN 4: EPSILON IS THE CONTENT

## Epsilon composes a sentence, not picks one

**Status:** Complete alternative proposal. Not canon until selected by the owner.
**Proposal:** 4 of 5
**Design thesis:** The generated items *are* the game. Combat and dungeons are the substrate that shows them off. Epsilon composes each item from an authored alphabet under a power budget, rather than selecting a pre-written whole.
**Target:** Godot 4.5 client plus the existing Python/Pydantic bridge.
**Source authorities:** `docs/authorities/PLAYER_DESIGN_AUTHORITY_v1.0.md`, `docs/authorities/DUNGEON_ENVIRONMENT_AUTHORITY_v0.1.md`
**Written against:** `docs/design-proposals/00_ZERO_GUESSWORK_STANDARD.md` v1.1

### Proposal profile

| Axis | Rating |
|---|---:|
| Novelty | 5 / 5 |
| Player-build variety | 5 / 5 |
| Environmental breadth | 2 / 5 |
| System interaction depth | 4 / 5 |
| Implementation risk | 4 / 5 |
| Procedural validation difficulty | 3 / 5 |
| Reuse of current repo foundations | 4 / 5 |

**Principal tradeoff:** this proposal generates millions of mechanically distinct items instead of a few dozen, and pays for it with the thinnest dungeon of the five and a balance system that is a budget rather than a designer's judgement. It is also the only proposal that ships **Forge**, because an item-centric game without an item economy is a game where the Archive only ever grows.

**Who should pick this:** an owner who thinks the sentence *"a foreign item became something nobody has seen before"* is the reason Archipepsi exists, and who accepts that rooms will be good arenas rather than good places.

---

# 0. PURPOSE

This document resolves every open decision in the two source authorities into an implementable form, to the Zero-Guesswork Standard.

## 0.1 The line this proposal is built on

Player Authority §26.2:

> Developers author the alphabet.
> Godot enforces the grammar.
> **Epsilon chooses and describes a sentence.**

Designs 1, 2, and 3 read that as: developers write a few dozen complete sentences, and Epsilon picks one. That is the **profile mechanism** (Design 1 §3.3), it is safe, and its creative surface is roughly 24 distinct Weapons.

Design 4 reads it literally. Developers author *words* — delivery atoms, cadence atoms, payload atoms, trigger clauses. Epsilon **composes** a sentence from them. The grammar that keeps the sentence legal is not a whitelist of finished items; it is a **power budget** (§4.5) that every composition must land inside.

The result is combinatorially large — §11.6 computes it exhaustively at **`175,155,080`** distinct legal Weapons against Design 1's `24` — while every atom, every number, and every rule remains authored.

## 0.2 What this proposal does **not** claim

Standard §5.2 asks a proposal that rejects the profile mechanism to say what replaces it, and how a Zone stays valid when the model is unavailable or returns nonsense. Both are answered in §17, but the constraints are worth stating before anything else, because "Epsilon is the content" is easy to hear as something the authorities forbid.

| Not claimed | Authority |
|---|---|
| Epsilon writes code or callbacks | §26.2 |
| Epsilon invents an input or keybind | §2.2, §37 |
| Epsilon emits a number | §26.2, and this proposal's own §3.3 |
| Epsilon authors Boolean recharge logic | §13.4 |
| Epsilon decides progression truth | §25, Dungeon §3.4 |
| Epsilon is required for the game to run | §2.8 |
| Epsilon touches Zone composition | Dungeon §3.4 |

Every one holds here exactly as it holds in Design 1. **Epsilon still emits only selections from enumerated sets.** What changes is that it makes ten or fifteen of them per item instead of three, and their combination is checked against a budget rather than pre-approved as a unit.

## 0.3 Relationship to Designs 1–3

Design 4 **explicitly pins** shared systems to Design 1 by section number, using the convention Design 2 established and Design 3 refined. A pin means *identical*, names a document and section in this repository, and is not the silent inheritance Standard §2.4 forbids.

**Pins and modifiers.** Where a section of this document modifies something it also pins, the pin names its modifier inline. The complete list:

| Pinned section | Modified by | What changes |
|---|---|---|
| Design 1 §4.2 (`HostDefinition`) | §4.4 | Gains `composition` and `budget_spent` |
| Design 1 §17.1 (interpretation) | §17.2 | The request and response shapes are compositional |
| Design 1 §17.3 (duplicates) | §17.5 | Duplicates feed Forge rather than only consolidating |
| Design 1 §18.1 (Forge deferred) | §18 | **Forge ships** |

Every other section labelled "one addition" adds alongside a pinned system without altering it.

---

# 1. INHERITED LAWS

*Pinned: identical to Design 1 §1.1 and §1.2.* All 48 laws unchanged.

Four are load-bearing here and are restated because this proposal presses hardest against them:

- **Law 2** — inputs describe roles, not generated content. A composed item occupies a legal role and never creates one.
- **Law 18** — only controlled, typed recharge hybrids. No Boolean scripting language. §12.8's trigger clauses are the mechanism that stays inside this, and §12.8.1 explains exactly how.
- **Law 33** — only equipped hosts are runtime-active. With an Archive that may hold thousands of composed items, this stops being a nicety and becomes the thing that keeps the game running at all.
- **Law 37** — Epsilon never authors executable mechanics or keybinds.

## 1.3 Precedence

*Pinned: identical to Design 1 §1.3.*

---

# 2. SCOPE

## 2.1 Ships in Epsilon Is The Content

**The composition system — the reason this proposal exists**

- **An authored atom alphabet** (§4.5): **102 atoms across 15 dimensions** — 38 for Weapons, 32 for Abilities, 19 for Gear, 13 for Mods — each with a cost, a parameter set, and a compatibility mask.
- **The power budget** (§4.6): every composition must land in a tier-determined band. This replaces pre-balanced profiles as the balance mechanism.
- **Compositional Weapons, Abilities, Mobility, Gear, and Mods** (§11–§16).
- **Trigger clauses** (§12.8): `WHEN <event> THEN <effect>`, both from closed catalogs, at most three per item, no Boolean combination.
- **Forge** (§18): the only proposal of the five that ships it, with the authority's own 5→1→5→1 economy.
- **A deterministic offline composer** (§17.6) that produces budget-valid items with no model at all.
- **Item identity and comparison UI** (§34.5): when items are the content, reading them is a first-class system.

**Player**

- Movement, damage, interaction, carryables, Mobility, physics, Status — *pinned: identical to Design 1 §6, §8, §9, §10, §13, §14, §15*.
- Composed Weapons, Abilities, and Gear replacing Design 1's fixed catalogs.

**Dungeon — the thinnest of the five, deliberately**

- Signal graph, sensors, actuators, hacking — *pinned: identical to Design 1 §19–§22*.
- **Twelve** puzzle families (§24), against Design 1's eighteen.
- Hazards and destruction — *pinned: identical to Design 1 §25*.
- Zone flags, topology, capability progression, composition — *pinned: identical to Design 1 §28, §29, §30*.

## 2.2 Explicitly deferred

| Deferred system | Cost of deferring |
|---|---|
| Water, energy balls, reflector beams | *Pinned: identical to Design 1 §2.2.* Nine authority acceptance tests. |
| Dynamic joints and constraint simulation | *Pinned: identical to Design 1 §2.2.* Design 2 ships this; this does not. |
| Reversible macro state and looping topology | Design 3 ships this; this does not. Zone flags stay forward-only and the spine stays a tree. |
| Physics constructs, portals, gases, advanced gravity, programmable logic, rotating rooms, in-Zone loadout stations | *Pinned: identical to Design 1 §2.2.* |
| **Six puzzle families** | `ROUTE_SWITCH`, `MOVING_MACHINE`, `BOMB_BARRIER`, `OBSERVATION_TARGET`, `A_B_STATE`, and `MULTI_STAGE_MACHINE` are cut (§24). Rooms lose most of their capacity to be *places*; §41.2 records this as this proposal's defining sacrifice. The six were chosen so that no authority acceptance test is orphaned — the mechanisms they used remain, pinned from Design 1, and §38 covers them directly. |

**Deferral means:** *pinned: identical to Design 1 §2.2.*

## 2.3 Removed rather than deferred

*Pinned: identical to Design 1 §2.3.*

## 2.4 What "v1" means here

*Pinned: identical to Design 1 §2.4.*

---

# 3. AUTHORITY AND DATA OWNERSHIP

*Pinned: identical to Design 1 §3.1 (bridge), §3.2 (Godot), §3.4 (stable identifiers), §3.5 (validation behavior).*

## 3.3 Epsilon authority — the widened surface

Epsilon selects, per interpretation, from the closed sets in this document:

| Epsilon may choose | Epsilon may never choose |
|---|---|
| Host category | Any numeric value |
| Family within the category | Any keybind or input |
| **Each atom filling each dimension slot** | Any atom outside the compatibility mask |
| **Which trigger clauses to attach, from the catalogs** | A new atom, dimension, event, or effect |
| Display name and flavor text | A composition exceeding its budget |
| Accent set | A capability requirement |
| Which Status the item applies, from the catalog | Anything about Zone composition |

**The critical rule is unchanged from Design 1: Epsilon emits selections, never numbers.** Every atom carries its own authored parameters. A composition of twelve atoms is twelve enum choices, and the deterministic resolver expands them into the full parameter set and sums their costs.

What is different is only the *shape* of the choice. Design 1 asks: "which of these three profiles?" Design 4 asks: "which delivery, which cadence, which payload, which feed, which rider, which triggers?" — each from its own enumerated list. Both are selections from authored sets. Neither is a number.

## 3.6 Where balance now lives

In Design 1, balance lives in the authored profile: a designer writes `cadence_precise` at `52.0` damage per `0.85 s` and that pairing is the balance decision.

In Design 4, balance lives in **atom costs and the budget** (§4.6). A designer prices each atom, and the budget bounds what a composition can hold. No human approves a specific combination, because there are millions.

This is the proposal's biggest bet and its biggest risk, and it is stated plainly here rather than buried: **the budget is doing work a designer did in every other proposal.** §4.7 defines the pricing discipline that makes it tractable, and §41.2 records the residual risk honestly.

---

# 4. SCHEMAS

*Pinned: identical to Design 1 §4.1 (common types), §4.7 (loadout).*

## 4.2 Host definition

*Pinned: identical to Design 1 §4.2* — **except that §4.4 adds two fields**.

## 4.4 Composed host — modifies Design 1 §4.2

Two fields are added to `HostDefinition`:

```
HostDefinition (extends Design 1 §4.2):
  ...                                          # Design 1 §4.2's fields
  composition       : Composition              # NEW
  budget_spent      : int                      # NEW, must equal sum of atom costs

Composition:
  slots             : map[string, Id]          # dimension name -> atom id
  triggers          : list[TriggerClause], length 0..3
```

`budget_spent` is stored rather than derived so a save can be audited without re-resolving the atom catalog. A record whose `budget_spent` disagrees with the sum of its atoms' costs is a hard error at load.

The `profile` field from Design 1's `WeaponAction`, `AbilityDefinition`, and `MobilityDefinition` **does not exist** in this proposal. Composition replaces it entirely.

## 4.5 The atom

```
Atom:
  id                : Id                       # atom:core:<slug>
  dimension         : string                   # which slot it fills
  cost              : int, 1..90
  params            : map[string, float | int | bool | string]
  requires          : list[Id] = []            # atoms that must also be present
  excludes          : list[Id] = []            # atoms that must not be present
  tier_min          : enum { USEFUL, HIGH } = USEFUL
```

Rules:

- Atoms are **authored**. Epsilon never creates one, and the catalog is a checked-in data file.
- Every dimension a family declares must be filled by exactly one atom of that dimension. There are no empty slots and no defaults — a composition missing a dimension is rejected at interpretation.
- `requires` and `excludes` form the **compatibility mask**. They are flat lists of atom ids, never expressions, so mask evaluation is a set operation and cannot become logic.
- `tier_min = HIGH` marks an atom only a high-tier item may use.
- Every parameter a family reads must be present in every atom legal for its dimension, checked at catalog load in CI.

## 4.6 The power budget

```
Budget:
  tier              : enum { USEFUL, HIGH }
  target            : int                      # USEFUL 100, HIGH 180
  tolerance         : int                      # 15 for both
```

A composition is legal only if:

```
target − tolerance  <=  sum(atom.cost)  <=  target
```

| Tier | Legal cost range |
|---|---|
| `USEFUL` | `85` to `100` |
| `HIGH` | `165` to `180` |

**Both bounds matter.** The upper bound stops a composition being stronger than its tier. The lower bound stops it being weaker — an item that costs `40` in a `100` budget is a disappointment, and a generator that produces disappointments is worse than one that produces nothing. A composition under the floor is completed by the resolver per §17.4 step 5 rather than shipped weak.

## 4.6.1 The trigger allowance

Trigger clauses are budgeted **separately** from the base composition, and are capped by count as well as by cost:

| Tier | Trigger allowance | Max clauses |
|---|---:|---:|
| `USEFUL` | `22` | `1` |
| `HIGH` | `38` | `2` |

This separation is not a convenience. With a single shared budget, a base composition landing at the top of its band has zero points left and can carry no clause at all — which would make the trigger system a feature most items never get. Computed against the real catalog, a shared budget yields `479` clause-sets for a base at `78` and exactly `1` for a base at `100`. A separate allowance gives every item the same expressive range regardless of how its base was spent.

The count cap is a readability rule rather than a balance one. Two rules on an item is what a player can hold in their head while fighting; three is a paragraph.

Mods use a separate, smaller budget:

| Mod tier | Legal cost range |
|---|---|
| Filler-derived | `18` to `25` |
| Trap-derived | `18` to `25`, plus one mandatory `DRAWBACK` atom worth `−10` to `−25` |

## 4.7 Pricing discipline

Atom costs are the balance surface, so how they are set is a rule rather than a matter of taste.

1. **A cost is proportional to the atom's contribution to expected damage-per-second, survivability, or utility-per-second against the reference target**: a `SKIRMISHER` (60 HP, 0 Defense) at `15 m`, over a `10 s` engagement.
2. **The reference item costs its budget exactly.** `cadence_standard` + `delivery_hitscan` + `payload_direct` + `feed_magazine_standard` + `secondary_none` + no triggers = exactly `100`, and is the item every other `USEFUL` Weapon is priced against.
3. **A cost is never negative** except for `DRAWBACK` atoms, which exist only on trap-derived Mods and are capped at `−25`.
4. **Costs are integers.** Fractional pricing invites false precision the model does not have.
5. **Repricing an atom is a balance pass and does not change any schema.** This is the payoff of the whole design: rebalancing the game is editing a cost column, not rewriting profiles.
6. **A new atom must be priced against the reference item before it ships**, and CI rejects a catalog containing an atom with no recorded pricing rationale.

## 4.8 Trigger clause

```
TriggerClause:
  event             : enum      # the 14 in §12.8
  effect            : enum      # the 16 in §12.8
  magnitude         : enum { SMALL, MEDIUM, LARGE }
  cost              : int                      # derived from (event, effect, magnitude)
  internal_cooldown : Seconds                  # authored per effect, never per item
```

A clause is **one event, one effect**. There is no `AND`, no `OR`, no `NOT`, no nesting, and no clause that references another clause. §12.8.1 explains why that boundary is exactly where Player Authority §13.4 draws it.

## 4.9 Status and Mod

*Pinned: identical to Design 1 §4.5* for `StatusDefinition`. `ModDefinition` is replaced by the composed form in §16.3.

---

# 5. LIFECYCLE AND PERSISTENCE

*Pinned: identical to Design 1 §5.1 through §5.12* — the five categories, the assignment table, snapshot cadence, death, room unload, host runtime state, cold introduction, fresh-Zone readiness, reconstruction order, mid-transition machinery, temporary grants, and encounter unreachability.

## 5.13 One addition: Archive scale

The Archive in this proposal is expected to hold **thousands** of composed items in a long campaign, against Design 1's hundreds. Two consequences:

- **Archive contents serialize as `(id, ap_item_id, composition, budget_spent, provenance)`** and nothing else. The expanded parameter set is re-derived from the atom catalog on load. A save therefore stores about `200` bytes per item rather than the full expansion, and a `5,000`-item Archive is under `1 MB`.
- **Re-derivation is version-sensitive.** An atom repriced or reparameterised between versions changes what an existing item does. §17.7 defines the migration rule for that, and it is the one genuinely new persistence problem this proposal creates.

---

# 6. BASE PLAYER

*Pinned: identical to Design 1 §6.1 through §6.5* — body, the movement law and all derived margins, out-of-bounds recovery, Static Pulse, and baseline melee.

Static Pulse is **not** composed. It is authored, fixed, and identical to Design 1's, because Law 1's permanent baseline cannot depend on a system that can produce a bad roll.

---

# 7. INPUT

*Pinned: identical to Design 1 §7.1 through §7.4.*

---

# 8. DAMAGE

*Pinned: identical to Design 1 §8.1 through §8.8.*

---

# 9. WORLD INTERACTION

*Pinned: identical to Design 1 §9.1 through §9.4.*

---

# 10. CARRYABLES AND SOCKETS

*Pinned: identical to Design 1 §10.1 through §10.4.*

---

# 11. WEAPONS

## 11.1 The six dimensions

Every Weapon fills exactly six slots. There are no defaults and no empty slots.

| Dimension | What it decides |
|---|---|
| `frame` | The device chassis: base handling and swap speed |
| `delivery` | How the attack reaches its target |
| `cadence` | Rate and rhythm |
| `payload` | What happens on hit |
| `feed` | The ammunition or heat model |
| `secondary` | The RMB action |

## 11.2 The atom catalog

Costs are the balance surface, priced per §4.7 against the reference item. Atoms marked **H** are `tier_min = HIGH` and may appear only in a high-tier composition.

### `frame`

| Atom | Cost | Parameters |
|---|---:|---|
| `frame_light` | `8` | swap `0.15 s`, damage `×0.92`, spread `×0.85` |
| `frame_standard` | `10` | swap `0.25 s`, damage `×1.00`, spread `×1.00` |
| `frame_heavy` | `14` | swap `0.40 s`, damage `×1.12`, spread `×1.20` |
| `frame_exotic` **H** | `22` | swap `0.20 s`, damage `×1.20`, spread `×0.90` |

### `delivery`

| Atom | Cost | Parameters |
|---|---:|---|
| `delivery_arc` | `14` | reach `3.0 m`, sweep radius `0.8 m`, max targets `4` |
| `delivery_projectile` | `18` | speed `55 m/s`, radius `0.2 m`, lifetime `3.0 s` |
| `delivery_hitscan` | `20` | range `70 m`, instant |
| `delivery_spread` | `22` | `9` pellets, cone `7°`, range `25 m`, falloff `8→22` at `0.35` |
| `delivery_burst` | `24` | `3` shots, `0.06 s` apart, range `60 m` |
| `delivery_beam` | `26` | range `35 m`, tick `0.10 s`, continuous |
| `delivery_dual` **H** | `34` | two independent lines, each `0.70×` output, `±4°` divergence |

### `cadence`

| Atom | Cost | Parameters |
|---|---:|---|
| `cadence_deliberate` | `20` | interval `0.85 s`, damage `×2.60`, crit `+0.25` |
| `cadence_standard` | `25` | interval `0.28 s`, damage `×1.00`, crit `+0.10` |
| `cadence_heavy` | `28` | interval `0.55 s`, damage `×1.85`, crit `+0.15` |
| `cadence_rapid` | `30` | interval `0.10 s`, damage `×0.42`, crit `+0.05` |
| `cadence_precise` | `34` | interval `0.85 s`, damage `×2.85`, crit `+0.30`, spread `×0.0` |
| `cadence_adaptive` **H** | `42` | interval `0.40 s` falling to `0.18 s` over `3.0 s` of sustained fire, resetting after `1.5 s` idle; damage `×1.30` |

### `payload`

| Atom | Cost | Parameters |
|---|---:|---|
| `payload_mark` | `22` | base damage `10.0`; marks the target for `5.0 s` |
| `payload_status` | `26` | base damage `12.0`; applies its Status at `0.30` |
| `payload_direct` | `30` | base damage `18.0` |
| `payload_drain` | `32` | base damage `14.0`; heals `2.0` per hit, `12.0/s` cap |
| `payload_pierce` | `34` | base damage `16.0`; passes through `2` actors |
| `payload_charge` | `36` | base damage `10.0` to `40.0` over `1.2 s` of hold |
| `payload_area` | `38` | base damage `16.0` in `3.0 m` |
| `payload_chain` | `40` | base damage `13.0`; jumps to `2` further targets within `6 m` at `0.6×` each |
| `payload_compound` **H** | `52` | base damage `15.0`, plus `8.0` in `2.5 m`, plus its Status at `0.20` |

### `feed`

| Atom | Cost | Parameters |
|---|---:|---|
| `feed_magazine_small` | `12` | capacity `12`, reload `1.10 s` |
| `feed_magazine_standard` | `15` | capacity `30`, reload `1.80 s` |
| `feed_heat` | `18` | max `100`, per use `8.0`, cool `35/s` after `0.6 s`, vent `1.40 s`, lockout `2.50 s`, inactive cool `12/s` |
| `feed_none` | `22` | no feed state; `R` is a no-op |
| `feed_selfloading` **H** | `28` | capacity `20`, no reload input; regenerates `1` round every `0.6 s` while not firing |

### `secondary`

| Atom | Cost | Parameters |
|---|---:|---|
| `secondary_none` | `0` | RMB inert |
| `secondary_zoom` | `8` | FOV `45°`, spread `×0.35`, move `×0.60` |
| `secondary_detonate` | `12` | detonates this Weapon's live area payloads |
| `secondary_tether` | `14` | two-shot tether, `2500 N` break force, `EPHEMERAL` |
| `secondary_guard` | `16` | `40` Barrier while held, move `×0.50`, primary blocked |
| `secondary_altfire` | `24` | a second `(delivery, payload)` pair sharing the feed |
| `secondary_dualmode` **H** | `32` | toggles the primary between its composed `cadence` and one other legal `cadence` atom, `0.35 s` swap |

## 11.3 The reference item

```
frame_standard            10
delivery_hitscan          20
cadence_standard          25
payload_direct            30
feed_magazine_standard    15
secondary_none             0
                         ---
                         100   = exactly the USEFUL target
```

It deals `18.0 × 1.00 = 18.0` damage every `0.28 s` at `70 m` — which is Design 1's `cadence_standard` profile, by construction. Every atom in §11.2 is priced against this item, and this is the anchor §4.7 rule 2 names.

## 11.4 Resolution

The final parameter set is derived in this fixed order:

1. `payload` supplies base damage, and the Status if any.
2. `cadence` supplies interval and multiplies base damage by its damage multiplier.
3. `frame` multiplies the result and supplies swap time.
4. `delivery` supplies range, geometry, and travel behaviour, and applies its own falloff if it has one.
5. `feed` supplies the ammunition model.
6. `secondary` supplies the RMB action.
7. Crit chance is the sum of `cadence`'s contribution and any trigger clause granting crit.
8. Spread is `delivery`'s cone multiplied by `frame`'s and `cadence`'s spread multipliers.

Order matters and is fixed so that the same composition always resolves to the same numbers, on every machine, forever.

## 11.5 Compatibility mask

Flat `requires` / `excludes` lists, never expressions:

| Atom | Excludes | Why |
|---|---|---|
| `delivery_beam` | `feed_magazine_small`, `feed_magazine_standard` | A magazine-fed continuous beam has no coherent reload point |
| `delivery_beam` | `payload_charge`, `payload_chain` | Charge and chain both need discrete hits |
| `delivery_arc` | `secondary_zoom`, `payload_area` | Zooming a melee arc is meaningless; area on a sweep double-counts |
| `delivery_spread` | `payload_pierce`, `payload_chain` | Nine pellets each piercing or chaining is an unbounded target count |
| `payload_charge` | `cadence_rapid`, `feed_heat` | A `0.10 s` interval cannot hold a `1.2 s` charge |
| `secondary_detonate` | *requires* `payload_area` | Nothing to detonate otherwise |
| `secondary_altfire` | `feed_none` | An alt-fire sharing a feed needs a feed to share |
| `delivery_dual` | `payload_compound` | Both multiply output lines; together they quadruple hit count |

The mask is checked before the budget. A composition violating it is rejected at interpretation regardless of cost.

## 11.6 How large the space actually is

Every figure below is computed exhaustively over the catalog in §11.2 and the mask in §11.5, and is **asserted in CI** — a mask or pricing change that collapses any of them is a silent disaster, and the assertion is what makes it loud.

| | `USEFUL` | `HIGH` |
|---|---:|---:|
| Unconstrained slot combinations | `17,280` | `52,920` |
| Mask-legal | `10,644` | `35,992` |
| **In budget band** | **`745`** | **`1,505`** |
| Clause-sets available (§4.6.1) | `479` | `116,145` |
| **Distinct legal Weapons** | **`356,855`** | **`174,798,225`** |

**Total: `175,155,080` distinct legal Weapons**, against Design 1's `24`.

Two things about that number are worth stating rather than celebrating. The `HIGH` tier carries `99.8%` of it, because two clauses from `672` at a `38`-point allowance is where the combinatorics actually live — the base composition contributes far less variety than the clauses do. And a space this size is not `175` million *good* items; it is `175` million *legal* ones. §4.7's pricing discipline and §17.4's rejection path are what stand between those two statements, and §41.2 is honest about the gap.

## 11.7 Cycling and activation

*Pinned: identical to Design 1 §11.7*, with `CHARGE`-feed rows removed — charge is a `payload` here, not a feed — and one addition: `frame` supplies the swap time, so cycling speed varies by Weapon rather than being a fixed `0.25 s`.

---

# 12. ABILITIES, READINESS, AND COST

## 12.1 The five dimensions

| Dimension | What it decides |
|---|---|
| `form` | The activation shape |
| `effect` | What it does |
| `targeting` | Where it lands |
| `recharge` | How it becomes ready |
| `scaling` | How its magnitude is determined |

## 12.2 The atom catalog

### `form`

| Atom | Cost | Parameters |
|---|---:|---|
| `form_press` | `10` | instant, `cast_time 0.0` |
| `form_cast` | `12` | `cast_time 0.30 s`, cancellable, full refund on cancel |
| `form_hold` | `16` | active while held |
| `form_charge` | `18` | `0.0`→`1.0` over `0.90 s`; below `0.25` cancels free |
| `form_channel` | `20` | samples every `0.5 s`; bounds per Design 1 §12.2.1 |
| `form_sustained` **H** | `30` | samples every `0.5 s` with no maximum duration; ends only on release or unpayable cost |

### `effect`

| Atom | Cost | Parameters |
|---|---:|---|
| `effect_mark` | `14` | reveals targets for `12.0 s` |
| `effect_status` | `22` | applies its Status at `source_potency 0.30` |
| `effect_barrier` | `26` | grants `50.0` Barrier for `8.0 s` |
| `effect_damage` | `28` | `35.0` damage |
| `effect_physics` | `28` | one Design 1 §14 primitive at `900 N` |
| `effect_field` | `32` | a volume dealing `12.0/s` for `6.0 s` |
| `effect_heal` | `34` | `18.0` Health per second |
| `effect_deployable` | `38` | a turret firing `8.0` every `0.5 s` for `12.0 s` |
| `effect_transform` **H** | `62` | applies a `TEMPORARY_RULE` from Design 1 §12.10 for `8.0 s` |

### `targeting`

| Atom | Cost | Parameters |
|---|---:|---|
| `target_self` | `6` | the player |
| `target_point` | `12` | aim point, `range 30 m` |
| `target_actor` | `14` | focused actor, `range 35 m` |
| `target_area` | `18` | sphere `radius 5.0 m` at the aim point, `range 25 m` |
| `target_cone` | `16` | `60°` cone, `range 18 m` |
| `target_chained` **H** | `32` | the focused actor plus up to `3` more within `8 m` of each other, `range 30 m` |

### `recharge`

| Atom | Cost | Parameters |
|---|---:|---|
| `recharge_action` | `14` | one of the ten facts in Design 1 §12.6; threshold per fact |
| `recharge_resource` | `18` | pool `100`, cost `25`, regen `12/s` after `1.0 s` |
| `recharge_cooldown_long` | `20` | `1` charge, `18.0 s` |
| `recharge_cooldown_multi` | `24` | `2` charges, `10.0 s` each, serial |
| `recharge_cooldown_short` | `26` | `1` charge, `6.0 s` |
| `recharge_dual` **H** | `40` | `2` charges at `8.0 s` each **and** a `60`-point pool costing `20` per use, regen `10/s`. The one legal exception to Design 1 §13.5's no-hidden-second-tax rule, permitted only at high tier and shown explicitly in the HUD as two constraints. |

### `scaling`

| Atom | Cost | Parameters |
|---|---:|---|
| `scaling_flat` | `10` | magnitude as authored by `effect` |
| `scaling_charge` | `16` | magnitude `×0.4` to `×1.6` across charge; requires `form_charge` |
| `scaling_stacks` | `18` | magnitude `×1.0` to `×1.8` with consecutive hits, decaying `0.3/s` |
| `scaling_escalating` **H** | `34` | magnitude `×0.8` rising to `×2.4` across a `12.0 s` engagement, resetting `3.0 s` after the last hit |
| `scaling_proximity` | `14` | magnitude `×1.5` within `6 m`, `×0.7` beyond `18 m` |

## 12.3 The reference Ability

```
form_press                10
effect_damage             28
target_actor              14
recharge_cooldown_short   26
scaling_flat              10
                         ---
                          88   = inside the USEFUL band [85, 100]
```

`12` points of headroom, which admits one `SMALL` trigger clause.

## 12.4 Compatibility mask

| Atom | Rule |
|---|---|
| `scaling_charge` | *requires* `form_charge` |
| `effect_heal` | *requires* `form_channel`; *excludes* `target_actor`, `target_cone` |
| `effect_deployable` | *requires* `target_point`; *excludes* `form_hold`, `form_channel` |
| `effect_physics` | *excludes* `recharge_action`, `target_area`, `target_cone` |
| `effect_barrier` | *requires* `target_self` |
| `effect_field` | *requires* `target_point` or `target_area` |
| `form_hold` | *excludes* `effect_damage`, `effect_deployable`, `effect_status` |
| `effect_physics` | *also excludes* `target_chained` |
| `effect_heal` | *requires* `form_channel` **or** `form_sustained` |

`effect_physics` excluding `recharge_action` is the same rule Design 1 §12.9 gives and for the same reason: a manipulation tool gated behind a combat verb can strand a player in a room with nothing to kill. It is a safety rule, not a balance one.

## 12.5 Space

| | `USEFUL` | `HIGH` |
|---|---:|---:|
| Unconstrained slot combinations | `4,000` | `9,720` |
| Mask-legal | `1,577` | `4,431` |
| **In budget band** | **`766`** | **`48`** |
| Clause-sets available | `479` | `116,145` |
| **Distinct legal Abilities** | **`366,914`** | **`5,574,960`** |

**Total: `5,941,874` distinct legal Abilities.**

`48` in-band high-tier bases is thin, and it is thin for a structural reason: the Ability mask is far more restrictive than the Weapon mask, because effects, forms, and targeting shapes genuinely constrain each other. `48` bases × `116,145` clause-sets is still `5.5` million distinct high-tier Abilities, so the variety arrives — but it arrives through clauses rather than through base shape, and a player will meet the same `48` skeletons more often than they meet the same Weapon. **CI asserts this count at `48` or above**; a mask change that drops it below is a regression, not a tuning choice.

## 12.6 Recharge identity

An Ability's player-facing identity is derived from its `recharge` atom: `recharge_action` → `ACTION`, `recharge_resource` → `RESOURCE`, the three cooldown atoms → `COOLDOWN`. The HUD treatments in Design 1 §33.3 apply unchanged, and the three remain visually distinct.

Preflight, commit, and refund rules — *pinned: identical to Design 1 §12.3.*

## 12.7 Mobility

Mobility is **not composed**. *Pinned: identical to Design 1 §13* — five authored families with five authored profiles.

Movement is the one system where a bad composition is unrecoverable: an item that moves the player badly makes the whole game feel wrong, and every mandatory-route guarantee in both authorities is computed against specific movement numbers. §29 depends on knowing exactly what a `GRAPPLE` does. Composition would put that behind a budget, and the budget is not trustworthy enough for it.

This is the clearest place where the thesis is deliberately not applied, and §41.3 records it as a proposal-level choice.

## 12.8 Trigger clauses

A clause is `WHEN <event> THEN <effect>`. Both from closed catalogs. At most three per item.

### Events (14)

`ON_HIT`, `ON_CRIT`, `ON_OVERCRIT`, `ON_KILL`, `ON_AIRBORNE_KILL`, `ON_RELOAD`, `ON_WEAPON_SWAP`, `ON_DAMAGE_TAKEN`, `ON_BARRIER_BREAK`, `ON_STATUS_APPLIED`, `ON_ABILITY_USED`, `ON_MOBILITY_USED`, `ON_INTERACT`, `ON_LOW_HEALTH`

### Effects (16)

`GRANT_BARRIER`, `HEAL`, `RESTORE_RESOURCE`, `ADVANCE_COOLDOWN`, `ADVANCE_ACTION`, `ADD_CRIT`, `ADD_DAMAGE`, `ADD_SPEED`, `ADD_DEFENSE`, `APPLY_STATUS`, `REFILL_MAGAZINE`, `VENT_HEAT`, `GRANT_INVULN`, `SPAWN_FIRE`, `PUSH_NEARBY`, `MARK_NEARBY`

### Cost

```
clause_cost = round(event_weight + effect_weight × magnitude_multiplier)
magnitude_multiplier: SMALL 1.0, MEDIUM 1.8, LARGE 3.0
```

**Event weights.** A common event costs more than a rare one, because frequency is power.

| Event | Weight | Event | Weight |
|---|---:|---|---:|
| `ON_HIT` | `8` | `ON_RELOAD` | `5` |
| `ON_CRIT` | `6` | `ON_WEAPON_SWAP` | `5` |
| `ON_KILL` | `6` | `ON_MOBILITY_USED` | `5` |
| `ON_DAMAGE_TAKEN` | `6` | `ON_OVERCRIT` | `4` |
| `ON_ABILITY_USED` | `6` | `ON_STATUS_APPLIED` | `4` |
| `ON_AIRBORNE_KILL` | `3` | `ON_INTERACT` | `3` |
| `ON_BARRIER_BREAK` | `2` | `ON_LOW_HEALTH` | `2` |

**Effect weights.**

| Effect | Weight | Effect | Weight |
|---|---:|---|---:|
| `GRANT_INVULN` | `14` | `GRANT_BARRIER` | `8` |
| `ADD_CRIT` | `11` | `HEAL` | `8` |
| `ADD_DAMAGE` | `10` | `SPAWN_FIRE` | `8` |
| `ADVANCE_COOLDOWN` | `9` | `RESTORE_RESOURCE` | `7` |
| `APPLY_STATUS` | `9` | `REFILL_MAGAZINE` | `7` |
| `ADVANCE_ACTION` | `6` | `ADD_SPEED` | `5` |
| `ADD_DEFENSE` | `6` | `PUSH_NEARBY` | `5` |
| `VENT_HEAT` | `4` | `MARK_NEARBY` | `4` |

`14 × 16 × 3 = 672` distinct clauses, costing `6` to `50`. At the `USEFUL` allowance of `22`, `478` of them are affordable; at the `HIGH` allowance of `38`, `653` are.

**Clause count is capped by tier** per §4.6.1: `1` for `USEFUL`, `2` for `HIGH`.

Every effect carries an **authored `internal_cooldown`**, never chosen by Epsilon: `GRANT_INVULN` is `4.0 s`, `REFILL_MAGAZINE` is `8.0 s`, `HEAL` is `1.0 s`, and so on. This is what stops `ON_HIT → GRANT_INVULN` from being permanent invulnerability, and it is a property of the effect rather than of the item.

### 12.8.1 Why this stays inside Player Authority §13.4

§13.4 rejects: *"Q is ready if you have 63% blue meter AND killed two Burning enemies OR have not jumped for seven seconds unless the target is airborne."*

Every feature of that sentence is absent here by construction:

| §13.4's example has | This proposal |
|---|---|
| A number Epsilon chose (`63%`) | Epsilon emits no numbers; magnitude is a three-valued enum |
| `AND` | No clause combination exists |
| `OR` | Same |
| `unless` | Same |
| A compound predicate | One event, from a list of 14 |
| Nesting | Clauses cannot reference clauses |
| Unbounded count | At most three per item |
| Unbounded frequency | Every effect has an authored internal cooldown |

§13.4 permits *"finite models, finite factual predicates, finite metrics, bounded contributions, authored hybrid templates, explicit caps."* A trigger clause is exactly a finite factual predicate paired with a bounded contribution under an explicit cap. The boundary §13.4 draws is at **combination**, and this proposal does not cross it.

### 12.8.2 Loop prevention

A clause may not be advanced by an event its own effect produced. `ON_KILL → ADD_DAMAGE` cannot be triggered by a kill that its own damage bonus caused, because the check is at the event source, not by cycle detection — *pinned: identical to Design 1 §12.7*.

Additionally: **no item may carry two clauses with the same `event`.** Three `ON_HIT` clauses on one Weapon is a burst of simultaneous effects the player cannot read, and it is the shape most likely to produce an unintended engine. One event, one clause, per item.

## 12.9 Runtime limits

*Pinned: identical to Design 1 §16.5* — every clamp applies unchanged, and they are the final backstop when a budget-legal composition still produces too much of something. Invulnerability uptime capped at `25%` of any `10 s` window matters especially here.

---

# 13. MOBILITY

*Pinned: identical to Design 1 §13.* See §12.7 for why Mobility is deliberately not composed.

---

# 14. PHYSICS ECHOES

*Pinned: identical to Design 1 §14.1 through §14.5* — four primitives, eligibility, behavior, impact damage, and the rule that physics never gates progression.

`effect_physics` (§12.2) is how a composed Ability expresses one of the four primitives. The primitive itself is chosen as part of the composition; its parameters are Design 1's.

---

# 15. STATUS

*Pinned: identical to Design 1 §15.1 through §15.5* — six Statuses, the application formula with pity and adaptation, duration and stacking, immunity and substitution, and required feedback.

Status is not composed. Six authored Statuses with authored behaviour are what `payload_status`, `effect_status`, and the `APPLY_STATUS` trigger effect all select from.

---

# 16. GEAR AND MODS

## 16.1 Gear

Gear composes across three dimensions, plus its territory.

| Dimension | What it decides |
|---|---|
| `territory` | `HEAD`, `TORSO`, `ARMS`, `LEGS` — not costed; it constrains which `domain` atoms are legal |
| `domain` | The stat or system the piece touches |
| `magnitude_atom` | How strongly |

### `domain` atoms by territory

| Territory | Legal `domain` atoms |
|---|---|
| `HEAD` | `dom_targeting` `18`, `dom_information` `16`, `dom_crit` `26`, `dom_status_potency` `22` |
| `TORSO` | `dom_health` `24`, `dom_barrier` `26`, `dom_defense` `22`, `dom_resource` `20` |
| `ARMS` | `dom_melee` `20`, `dom_handling` `18`, `dom_physics` `20`, `dom_interaction` `14` |
| `LEGS` | `dom_speed` `24`, `dom_jump` `18`, `dom_mobility_recharge` `22`, `dom_landing` `16` |

### `magnitude_atom`

| Atom | Cost | Effect on the domain's scalar |
|---|---:|---|
| `mag_slight` | `20` | the domain's `SMALL` value from Design 1 §16.1 |
| `mag_marked` | `44` | the `MEDIUM` value |
| `mag_profound` | `72` | the `LARGE` value |

A `USEFUL` Gear piece is `domain + magnitude_atom` plus **one** trigger clause from the `22` allowance, landing in `[85, 100]`. `dom_crit` (`26`) + `mag_marked` (`44`) = `70`, leaving `30` — over the `22` clause allowance, so the resolver completes it per §17.4 step 5 with a second `domain` atom from the same territory. **A `HIGH` Gear piece carries exactly two `domain` atoms and two magnitude atoms**, which is this proposal's expression of Design 1 §4.5's "high-tier Gear has exactly two intrinsics."

The one-high-tier-Gear-piece restriction is *pinned: identical to Design 1 §16.1.*

## 16.2 Modifier order and runtime clamps

*Pinned: identical to Design 1 §16.4 and §16.5.* The clamps matter more here than anywhere else in the five proposals, because they are the final backstop when a budget-legal composition still produces too much of something.

## 16.3 Mods

A Mod is a **single trigger clause plus an optional passive atom**, budgeted at `18` to `25` (§4.6).

```
ModDefinition:
  id                : Id
  clause            : TriggerClause? = null
  passive           : Id? = null              # a passive atom
  host_categories   : list[enum { WEAPON, ABILITY, MOBILITY, GEAR }], length >= 1
  provenance        : Provenance
  rank              : int >= 1 = 1
  trap_flavor       : bool = false
  drawback          : Id? = null              # required iff trap_flavor
  budget_spent      : int
```

Exactly one of `clause` or `passive` is non-null.

### Passive atoms

| Atom | Cost | Effect |
|---|---:|---|
| `pas_damage` | `22` | `+12%` host damage |
| `pas_rate` | `20` | `−9%` host interval |
| `pas_capacity` | `18` | `+25%` magazine or heat max |
| `pas_range` | `18` | `+20%` host range |
| `pas_recharge` | `24` | `−12%` recharge time or cost |
| `pas_status_chance` | `20` | `+0.06` status chance |
| `pas_penetration` | `22` | `+0.12` penetration |
| `pas_defense` | `20` | `+18` Defense |

### Drawback atoms — trap-derived Mods only

| Atom | Cost | Effect |
|---|---:|---|
| `dwb_self_damage` | `−12` | `+35%` self-damage from own explosives |
| `dwb_max_health` | `−18` | `−15%` maximum Health |
| `dwb_reload` | `−10` | `+30%` reload duration |
| `dwb_spread` | `−14` | `+45%` spread |
| `dwb_resource` | `−25` | `−30%` resource regeneration |

A trap Mod is `passive + drawback`, netting into `[18, 25]`. `pas_damage` (`22`) + `dwb_max_health` (`−18`) = `4`, below the floor, so trap Mods pair a large passive with a small drawback or take a second passive. This is the mechanical expression of Player Authority §26.1's *"foreign trap → Mod, often with a visible bounded tradeoff flavor"*: a trap Mod is genuinely good and genuinely costs something.

### Compatibility

*Pinned: identical to Design 1 §16.3* for host-category matching, duplicate non-stacking, and the superseded-but-visible rule. Two additions:

- A Mod whose `clause.event` duplicates an event already on the host is **rejected at install**, per §12.8.2's one-clause-per-event rule. The Archive shows why.
- A host's clause count including installed Mods obeys the §4.6.1 cap: `1` for `USEFUL`, `2` for `HIGH`. Mod clauses count against it.

That second rule is the one that keeps an item readable after modding, and it means Mod slots on a `USEFUL` host can only hold passives once its own clause exists.

---

# 17. FOREIGN ITEMS, ARCHIVE, AND INTERPRETATION

## 17.1 Classification

*Pinned: identical to Design 1 §17.1.* `filler` → Mod, `trap` → Mod with a drawback, `useful` → `USEFUL` host, `progression` → `HIGH` host. Another game's progression flag sets tier, never Archipepsi capability truth.

## 17.2 The interpretation request — modifies Design 1 §17.1

Epsilon receives:

- The item name, its source game, its source player, and its AP classification.
- The tier the classification implies.
- **For each dimension of each legal category: the full atom list, each atom's `cost`, `tier_min`, and a one-line description of what it does.**
- The compatibility mask, as flat `requires` / `excludes` lists.
- The budget band and the trigger allowance for the tier.
- The trigger event and effect catalogs with their weights.
- The Status catalog.
- Display names already used this campaign.

It returns:

```
CompositionResponse:
  category          : one of the offered categories
  slots             : map[dimension, atom_id]     # every dimension filled
  triggers          : list[(event, effect, magnitude)], length 0..cap
  status_applied    : a Status id or null
  territory         : HEAD | TORSO | ARMS | LEGS  # GEAR only
  display_name      : string, 1..48
  flavor_text       : string, 0..280
  accent_set        : one of the offered accent sets
```

**Still no numbers.** Every field is a selection. `magnitude` is a three-valued enum. The model is doing more choosing than in Design 1 — eleven or so selections rather than three — but the *kind* of thing it emits is unchanged, which is what keeps Player Authority §26.2 satisfied.

## 17.3 Why Epsilon is given the costs

The request includes each atom's cost, which Design 1's does not. This is deliberate: a model that cannot see the budget will routinely propose compositions that miss the band, and every miss is a round-trip. Showing the arithmetic lets it compose to the target on the first attempt most of the time.

It does not let the model *set* a cost. Costs are read-only inputs, and the resolver recomputes the sum from the authored catalog rather than trusting anything the response claims about it.

## 17.4 Validation and repair

A response is processed in this exact order:

1. **Schema.** Every dimension filled, every atom id exists, category legal for the classification. Failure → reject.
2. **Tier.** No `tier_min = HIGH` atom in a `USEFUL` composition. Failure → reject.
3. **Mask.** All `requires` present, no `excludes` present. Failure → reject.
4. **Clause legality.** At most the tier's cap, no duplicate events, total clause cost within the allowance. Over → **drop the most expensive clause and re-check**, up to the cap; still failing → reject.
5. **Budget.** Sum the base atoms. Over the target → reject. **Under the floor → repair**, by this exact procedure:

   Walk the dimensions in the fixed order `payload, cadence, delivery, feed, secondary, frame`. In each:

   a. Consider only atoms that are tier-legal and **mask-legal against every other atom currently in the composition**.
   b. If any such atom brings the running total **into the band**, take the cheapest one and stop — the composition is repaired.
   c. Otherwise take the most expensive such atom that keeps the running total at or below the target, and continue to the next dimension.
   d. If every dimension is exhausted and the total is still below the floor, reject.

   The mask check in (a) is not optional and is the step most likely to be skipped: an upgrade that lands in band but violates the mask is not a repair, it is a different bug.
6. **Accept.** Store the composition and `budget_spent`.

A rejection at any step falls through to §17.6's deterministic composer. The player is never shown an error, and never receives a partially-valid item.

Step 5's repair is what stops the floor from producing a rejection storm. Composing slightly under budget is the most common model mistake, and it is trivially fixable without another round trip.

## 17.5 Duplicates — modifies Design 1 §17.3

Two receipts of the **same** AP item produce one Archive entry with `rank` incremented, for Mods **and** hosts. Design 1 ranked Mods only, because it had no Forge to consume ranks.

Here `rank` is a real resource: §18's Forge consumes it. A fifth copy of the same foreign Mod is not clutter; it is a quarter of the way to a Useful Echo.

Two *different* AP items that compose identically remain separate entries with separate provenance. Identity is provenance, not mechanics.

## 17.6 The deterministic composer

Used when Epsilon is unavailable, times out after `10.0 s`, or fails §17.4 three times.

```
h = SHA-256(campaign_seed || ap_item_id || category || attempt_index)
```

Then, greedily:

1. Order the dimensions by descending maximum atom cost.
2. For each dimension in that order, take `h`'s next 4-byte word modulo the count of atoms that are tier-legal, mask-legal against what is already chosen, and whose cost does not push the running total above the target.
3. If a dimension has no legal atom, restart with `attempt_index + 1`. This terminates because the cheapest atom in every dimension is always affordable from an empty composition, and the catalog guarantees at least one all-cheapest composition exists.
4. If the total is under the floor, run §17.4 step 5's repair.
5. Draw trigger clauses the same way from the affordable set, respecting the cap and the one-event rule.
6. `display_name` is the source item's name verbatim; `flavor_text` is `""`; `accent_set` is neutral.

**The game is fully playable with Epsilon offline.** Every item is budget-valid, mask-legal, and reproducible forever from the campaign seed.

What is lost is **thematic coherence**, and in this proposal that loss is larger than in any other. Design 1's fallback picks a profile at random and the item is still a coherent whole someone designed. Here the fallback picks eleven atoms at random, and the result is mechanically sound but thematically arbitrary — a foreign sword that becomes a self-loading chain-lightning beam for no reason anyone can see.

The items still work. The joke stops landing. §41.2 records this as the cost of the thesis.

## 17.7 Catalog versioning

An item's stored `composition` is re-expanded from the atom catalog on every load (§5.13). Repricing or reparameterising an atom therefore changes what every existing item using it does.

The rule:

- **Reparameterising an atom changes existing items, silently and intentionally.** That is the balance mechanism working: a tuning pass improves every item that uses the atom.
- **Repricing an atom may push an existing item's `budget_spent` outside its band.** On load, an item whose recomputed cost falls outside its tier's band is **flagged, not rejected**: it keeps working, the Archive marks it `Legacy`, and Forge (§18) offers to recompose it into the current band at no resource cost.
- **Removing an atom is forbidden once shipped.** An atom may be repriced to `1` and hidden from future composition, but its id must resolve forever or every save containing it breaks.

That last rule is the real constraint this design puts on the project, and it is permanent: **the atom catalog is append-only after ship.**

## 17.8 Archive

*Pinned: identical to Design 1 §17.6* — unequipped entries produce zero runtime work, the Archive is unbounded, sorting and filtering are UI-only.

## 17.9 Migration from existing saves

*Pinned: identical to Design 1 §17.4* — old Echoes become Archive entries with preserved provenance and regenerated mechanical content, the Loadout is cleared, Zone state is discarded, AP truth is untouched. Regeneration here uses §17.6's composer.

---

# 18. FORGE AND THE ECONOMY

**This is the only proposal of the five that ships Forge**, and it ships because an item-centric game whose Archive only grows is a game with no economy at all. Designs 1, 2, and 3 each record Forge's absence as their largest sacrifice; this proposal pays for it by cutting six puzzle families (§2.2).

## 18.1 The conversions

Player Authority §26.3's economy, implemented:

| Conversion | Input | Output |
|---|---|---|
| **Consolidate** | `5` ranks of Mods, any mix | `1` `USEFUL` host of a chosen category |
| **Elevate** | `5` `USEFUL` hosts, any mix | `1` `HIGH` host of a chosen category |
| **Recompose** | `1` host | the same host, recomposed at the same tier |
| **Reclaim** | `1` host | `2` Mod ranks |

Ratios are tuning values; the structural rule is Player Authority §26.3's — *"the player steers broad family/destination without typing exact stats."*

## 18.2 What the player steers

At the Forge the player chooses:

- The **category** of the output: Weapon, Ability, or Gear.
- For Gear, the **territory**.
- Up to **two atoms to preserve**, drawn from the inputs' compositions. A preserved atom is guaranteed to appear in the output if it is legal there.
- Nothing else.

The remaining dimensions are composed by Epsilon, or by §17.6's composer offline, against the output tier's budget. The player is steering, not authoring, which is exactly the line §26.3 draws.

**Preservation is why Forge is interesting.** A player with a Weapon whose `cadence_precise` they love and whose everything else they hate can preserve that one atom and reroll the rest. That is the loop this proposal is built around, and it is only possible because items are compositions rather than wholes.

## 18.3 Forge costs

| Conversion | Coin cost | Epsilon Static cost |
|---|---:|---:|
| Consolidate | `0` | `10` |
| Elevate | `0` | `40` |
| Recompose | `0` | `25` |
| Reclaim | `0` | `0` |
| Recompose a `Legacy` item (§17.7) | `0` | `0` |

**Epsilon Static is Forge's currency.** This is the sink Designs 1–3 all note it lacks, and it resolves the awkwardness of a received item type with no use. It remains explicitly *not* ammunition, *not* mana, and *not* a per-cast cost, per Player Authority §14.2 — it is a persistent crafting resource, spent only at the Hub.

Coins and Signal Keys are *pinned: identical to Design 1 §18.3* and Forge does not consume them.

## 18.4 Where Forge may be used

At the Hub only, alongside loadout editing. Forging is never available inside a Zone.

Forging **destroys** its inputs. The confirmation names them individually and requires an explicit second press, because destroying an item a player liked is the one irreversible action in this proposal.

## 18.5 Why there is no respec tax

*Pinned: identical to Design 1 §18.3* and Player Authority §22.4. Installing and removing Mods is free. **Forge changes persistent expression; loadout editing does not**, and only the first costs anything.

---

# 19. SIGNAL GRAPH

*Pinned: identical to Design 1 §19.1 through §19.6.*

---

# 20. INPUTS AND SENSORS

*Pinned: identical to Design 1 §20.1 through §20.4.* Nine sensor types, unchanged.

---

# 21. ACTUATORS AND MACHINERY

*Pinned: identical to Design 1 §21.1 through §21.9*, including §21.1.1's per-kind power-loss table.

---

# 22. HACKING

*Pinned: identical to Design 1 §22.1 through §22.3.*

---

# 23. PUZZLE-PACKAGE CONTRACT

*Pinned: identical to Design 1 §23.1 through §23.6.* The manifest, room offers, completion, reset ordering, the eighteen validation checks, and deterministic failure.

---

# 24. THE TWELVE PUZZLE FAMILIES

| # | Family | Origin |
|---|---|---|
| 1 | `CARRY_TO_PLATE` | *Pinned: identical to Design 1 §24.* |
| 2 | `INSERT_COMPONENT` | *Pinned.* |
| 3 | `PULSE_REMOTE` | *Pinned.* |
| 4 | `TIMED_TRAVERSE` | *Pinned.* |
| 5 | `SHOOT_TARGET` | *Pinned.* |
| 6 | `TOGGLE_ROOM_STATE` | *Pinned.* |
| 7 | `HACK_OVERRIDE` | *Pinned.* |
| 8 | `DUAL_INPUT` | *Pinned.* |
| 9 | `ALTERNATE_INPUT` | *Pinned.* |
| 10 | `ENCOUNTER_GATE` | *Pinned.* |
| 11 | `LOCAL_KEY_LOOP` | *Pinned.* |
| 12 | `DUNGEON_STATE_CHANGE` | *Pinned.* |

**Cut:** `ROUTE_SWITCH`, `MOVING_MACHINE`, `BOMB_BARRIER`, `OBSERVATION_TARGET`, `A_B_STATE`, `MULTI_STAGE_MACHINE`.

The mechanisms those families used all remain — rail switches, path machines, reactive barrels, and bombable surfaces are pinned from Design 1 §21 and §25, and Zone flags from §28.3. What is lost is the composer's ability to *ask for* those room shapes, which makes rooms simpler and more repetitive. That is the trade, stated plainly.

---

# 25. HAZARDS AND DESTRUCTION

*Pinned: identical to Design 1 §25.0 through §25.5.* Six material traits, six hazard families, four destructible classes including `REACTIVE_BARREL`, environmental kill credit, and enemy participation.

---

# 26. ROUTING, FORCES, AND CONSTRAINTS

*Pinned: identical to Design 1 §26.1 through §26.5.*

---

# 27. MEDIA

*Pinned: identical to Design 1 §27.1 through §27.4.*

---

# 28. ROOM AND ZONE TOPOLOGY

*Pinned: identical to Design 1 §28.1 through §28.7.* Four forward-only Zone flags, cross-room effect only through flags, a tree spine.

---

# 29. CAPABILITY PROGRESSION

*Pinned: identical to Design 1 §29.1 through §29.4.* Four capabilities; composed items grant none beyond what Mobility grants, and Mobility is not composed (§12.7).

## 29.5 One addition: composition never grants capability

No atom, no trigger clause, and no Mod grants a capability. `capability:core:grapple`, `blink`, and `long_gap` come only from the five authored Mobility families; `ranged_hit` comes only from the permanent baseline.

This is the rule that keeps §29's planner working in a world of `175` million Weapons: the planner never has to reason about what a composed item can do, because the answer is always "nothing that affects reachability."

---

# 30. PROCEDURAL COMPOSITION

*Pinned: identical to Design 1 §30.1 through §30.8*, with the puzzle-family list of §24 in place of Design 1's eighteen, and `PURPOSE_ROTATION` reduced to the purposes those twelve families can fill:

`[traversal, arena, environmental_puzzle, traversal, ranged_arena, junction, holdout, physical_puzzle, traversal, gauntlet, arena, boss_arena]`

Zone shape, the composition algorithm, the whole-Zone audit, determinism, checkpoints, retry and fallback, and physical authority are all unchanged.

---

# 31. CROSS-SYSTEM COMPATIBILITY

*Pinned: identical to Design 1 §31*, with these additions:

| A × B | Result |
|---|---|
| Trigger clause × trigger clause on one host | Never two clauses with the same `event` (§12.8.2) |
| Mod clause × host clause | Counts against the tier's clause cap (§16.3) |
| Trigger effect × its own event | Cannot self-feed (§12.8.2) |
| `GRANT_INVULN` × the §16.5 uptime clamp | Clamp wins; uptime never exceeds `25%` of any `10 s` window |
| Composed item × capability planner | No interaction; composition grants no capability (§29.5) |
| Atom repricing × an existing item | Item is flagged `Legacy` and works; Forge recomposes free (§17.7) |
| Atom removal × an existing item | Forbidden; the catalog is append-only after ship (§17.7) |

---

# 32. ENEMIES AND ENCOUNTERS

*Pinned: identical to Design 1 §32.1 through §32.7.* Six archetypes, faction behaviour, status-compatible AI, encounters and waves, death and respawn, boss encounters.

## 32.8 One addition: the reference target

§4.7 rule 1 prices every atom against a `SKIRMISHER` — `60` Health, `0` Defense — at `15 m` over a `10 s` engagement. That archetype is therefore **balance-load-bearing** in a way it is not in the other proposals: changing its Health or Defense invalidates every atom price in the catalog.

Its stats are frozen. A tuning pass that wants enemies tougher raises the other five archetypes or adds a seventh; it does not touch `SKIRMISHER`.

---

# 33. HUD AND PRESENTATION

*Pinned: identical to Design 1 §33.1 through §33.6.*

## 33.7 Reading a composed item — new to Design 4

When items are the content, the item card is a core system rather than a menu.

Every host displays, always:

| Element | Content |
|---|---|
| Name and provenance | Display name, source game, source player |
| Tier | `USEFUL` or `HIGH`, with the budget spent shown as `92 / 100` |
| **Composition line** | One line per filled dimension, naming the atom in player language |
| **Trigger clauses** | Rendered as `WHEN <event> THEN <effect>`, in plain words, one per line |
| Derived numbers | The resolved damage, interval, range, and feed after §11.4's resolution order |
| `Legacy` marker | Present when §17.7's recomputed cost is out of band |

The composition line is the difference between an item the player understands and a wall of statistics. `Heavy frame · Beam · Precise · Draining · Self-loading · Guard` tells a player what they are holding in six words, and every one of those words means the same thing on every item they will ever see.

That last property is the real payoff of composition, and it is worth stating: **a player who learns the 102 atoms can read any of the 175 million items at a glance.** A catalog of hand-written profiles has no such property — each one must be learned separately.

## 33.8 Comparison

Selecting two hosts of the same category shows them side by side, aligned by dimension, with differing atoms highlighted and identical atoms dimmed. Derived numbers show their delta.

This is required rather than optional. A player receiving several items an hour cannot evaluate them without it, and "which of these two is better for me" is the question this proposal asks most often.

---

# 34. PLAYER-FACING FLOW

*Pinned: identical to Design 1 §34.1 through §34.12* — first run, the Hub, receiving an item, Zone entry, Archive and equip, invalid-loadout messages, save refusal, binding conflicts, rejection feedback, leaving a Zone, the read-only in-excursion Archive, and the migration notice.

## 34.13 The Forge screen

1. The player selects a conversion from §18.1.
2. The screen shows the inputs it will destroy, individually, by name and provenance.
3. The player chooses category, territory where applicable, and up to two atoms to preserve (§18.2).
4. The Epsilon Static cost is shown against the current balance.
5. **A second, explicit confirmation press.** The text names what is being destroyed:

> **Forge this?** *Cracked Bell*, *Sunken Tally*, *Kestrel's Note*, *Ninth Cassette* and *Pale Ordinance* will be destroyed. This cannot be undone.

6. The result is presented as a full item card (§33.7), with preserved atoms marked.

## 34.14 Composition-failure messaging

There is none, and that is the design. §17.4's rejections fall through to §17.6's composer, so the player always receives an item. Failure is invisible by construction rather than by suppression — there is no error state a player can reach.

---

# 35. PERFORMANCE BUDGETS

*Pinned: identical to Design 1 §35* for every runtime budget.

## 35.1 Two additions specific to composition

| Quantity | Budget |
|---|---:|
| Atom catalog resolution, per item, on Archive load | `0.5 ms` |
| Full Archive expansion at `5,000` items | `2.5 s`, performed once on load, off the main thread |
| Interpretation round-trip timeout | `10.0 s`, then §17.6 |
| §17.4 repair attempts before falling through | `3` |
| Active trigger clauses across the whole loadout | `13` — one per `USEFUL` host or two per `HIGH`, across `3` Weapons, `5` Abilities, `1` Mobility, `4` Gear, plus Mod clauses, capped by §16.3 |

The `13`-clause cap matters at runtime: every clause is an event subscription, and thirteen subscriptions firing on `ON_HIT` is the worst case the damage resolver must absorb without a frame spike. Design 1 §16.4's trigger queue depth of `8` applies and clauses beyond it are discarded for that event.

---

# 36. DEBUGGING AND INSPECTION

*Pinned: identical to Design 1 §36*, plus:

| Inspectable | Content |
|---|---|
| Composition | Every equipped item's atoms, their costs, the sum, and the band it landed in |
| Resolution trace | The §11.4 order applied step by step, showing each intermediate value |
| Clause registry | Every active clause, its event, its effect, its internal cooldown, and time since last fire |
| Catalog stats | Live counts of mask-legal and in-band compositions per category per tier, against the CI-asserted values |
| Interpretation log | The last 50 Epsilon responses, which §17.4 step each failed at, and whether the fallback ran |
| Legacy items | Every item whose recomputed cost is out of band, and by how much |

The interpretation log is the one an implementer will live in. A model that starts failing step 5 constantly is a model whose prompt has drifted, and without the log that shows up as "items feel samey" three weeks later.

---

# 37. REFERENCE FIXTURES

## 37.1 Puzzle fixtures

*Pinned: identical to Design 1 §37 fixtures 1–9, 13, 16, 18* — the twelve retained families, in the same `20 × 20 × 6 m` test shell, with the same layouts, solutions, and reset expectations.

Fixture 19, the certified fallback Zone, is *pinned: identical to Design 1 §37 fixture 19*, with its package list restricted to the twelve families of §24.

## 37.2 Composition fixtures — new to Design 4

Ten checked-in compositions with their exact expected resolution. These are the acceptance target for §11.4 and §12.2: an implementation is correct when it resolves these to these numbers.

| # | Fixture | Composition | Expected resolution |
|---|---|---|---|
| C1 | `fx_reference_weapon` | `frame_standard`, `delivery_hitscan`, `cadence_standard`, `payload_direct`, `feed_magazine_standard`, `secondary_none`, no clauses | Cost `100`. `18.0` damage per `0.28 s`, `70 m`, crit `+0.10`, magazine `30`, reload `1.80 s`. Byte-identical to Design 1's `cadence_standard` profile. |
| C2 | `fx_budget_floor` | `frame_light`, `delivery_arc`, `cadence_deliberate`, `payload_mark`, `feed_magazine_small`, `secondary_none` | Cost `76`, below the `85` floor. Step 5 reaches `payload` first and needs an atom costing at least `31`; `payload_area` is mask-excluded by `delivery_arc`, so the cheapest in-band option is `payload_drain` (`32`). **Accepted at `86` after one substitution.** |
| C3 | `fx_budget_ceiling` | `frame_heavy`, `delivery_beam`, `cadence_precise`, `payload_chain`, `feed_none`, `secondary_altfire` | Rejected twice: mask (beam excludes chain; altfire excludes feed_none) and, mask aside, cost `160` over the `100` target. Falls through to §17.6. |
| C4 | `fx_mask_beam_magazine` | `delivery_beam` + `feed_magazine_standard` | Rejected at §17.4 step 3. The mask is checked before the budget, so the cost is never computed. |
| C5 | `fx_tier_violation` | A `USEFUL` composition containing `payload_compound` | Rejected at §17.4 step 2. |
| C6 | `fx_clause_overflow` | A `USEFUL` Weapon with two clauses | Step 4 drops the more expensive clause and re-checks; one clause survives; accepted. |
| C7 | `fx_duplicate_event` | Two clauses both on `ON_HIT` | Rejected at step 4 for the one-event rule (§12.8.2), not for cost. |
| C8 | `fx_high_weapon` | `frame_exotic`, `delivery_dual`, `cadence_adaptive`, `payload_area`, `feed_selfloading`, `secondary_dualmode`, two clauses | Cost `196` — over the `180` target. Rejected. The catalog's most expensive atoms do not compose. |
| C9 | `fx_high_valid` | `frame_standard`, `delivery_dual`, `cadence_adaptive`, `payload_pierce`, `feed_heat`, `secondary_guard`, `ON_CRIT → ADD_DAMAGE MEDIUM` | Cost `10+34+42+34+18+16 = 154`, below the `165` floor. **This fixture exists to exercise step 5's mask check.** At `payload`, reaching band needs an atom costing `45`+; only `payload_compound` (`52`) qualifies and `delivery_dual` excludes it — so rule (c) takes the most expensive legal payload, `payload_chain` (`40`), giving `160`, and continues. `cadence` and `delivery` are already at their maxima. At `feed`, `feed_selfloading` (`28`) brings the total to **`170`**, in band. Accepted after two substitutions. Clause cost `6 + 10×1.8 = 24`, within the `38` allowance. |
| C10 | `fx_reference_ability` | `form_press`, `effect_damage`, `target_actor`, `recharge_cooldown_short`, `scaling_flat`, no clauses | Cost `88`. `35.0` damage to the focused actor within `35 m`, one charge, `6.0 s`. |

Each ships an assertion file recording the full resolved parameter set, so a change to §11.4's resolution order is caught by a diff.

## 37.3 The catalog assertion

A single CI test recomputes, exhaustively, every figure in §11.6 and §12.5 from the atom catalog and mask, and fails if any differs:

| Assertion | Value |
|---|---:|
| Weapon mask-legal, `USEFUL` | `10,644` |
| Weapon in-band, `USEFUL` | `745` |
| Weapon mask-legal, `HIGH` | `35,992` |
| Weapon in-band, `HIGH` | `1,505` |
| Ability mask-legal, `USEFUL` | `1,577` |
| Ability in-band, `USEFUL` | `766` |
| Ability mask-legal, `HIGH` | `4,431` |
| Ability in-band, `HIGH` | `48`, and never fewer |
| Distinct clauses | `672` |
| Clauses affordable at `22` | `478` |
| Clauses affordable at `38` | `653` |

This test is the single most valuable one in the proposal. A mask edit that quietly drops in-band Weapons from `745` to `12` produces a game where every item feels the same, and nothing else would catch it.

---

# 38. TEST VECTORS

## Pinned systems
1. Every Design 1 vector covering a pinned section passes unchanged. A failure in any is a failure of a pin, not of a new system.

## Composition and budget
2. The reference Weapon (C1) resolves to exactly `18.0` damage per `0.28 s` at `70 m`, matching Design 1's `cadence_standard` profile byte for byte.
3. `budget_spent` always equals the sum of the composition's atom costs; a record where it does not is a hard error at load.
4. No accepted `USEFUL` composition costs below `85` or above `100`; no accepted `HIGH` composition below `165` or above `180`, across 100,000 generated items.
5. A composition below the floor is repaired per §17.4 step 5 in the fixed dimension order, and the repaired result is in band **and mask-legal** (C2 repairs in one substitution to `86`; C9 in two to `170`).
6. A composition above the target is rejected, never trimmed (C3, C8).
7. A `tier_min = HIGH` atom in a `USEFUL` composition is rejected at step 2 (C5).
8. The mask is evaluated before the budget: C4 is rejected without its cost being computed.
9. §11.4's resolution order produces identical numbers for the same composition across 1,000 resolutions and across machines.
10. Every dimension is filled in every accepted composition; a missing dimension is a hard error.

## Trigger clauses
11. `672` distinct clauses exist; `478` are affordable at the `USEFUL` allowance and `653` at the `HIGH` allowance.
12. A `USEFUL` item carries at most `1` clause; a `HIGH` item at most `2`, including clauses contributed by Mods.
13. Two clauses with the same event are rejected (C7), and the Archive states the reason.
14. Clause cost equals `round(event_weight + effect_weight × magnitude_multiplier)` for all `672`.
15. Every effect's `internal_cooldown` is authored and identical across every item using it.
16. `ON_HIT → GRANT_INVULN` at `LARGE` never produces more than `25%` invulnerability uptime over any `10 s` window, under any fire rate, per Design 1 §16.5.
17. A clause cannot be advanced by an event its own effect produced (§12.8.2).
18. Thirteen simultaneous `ON_HIT` clauses resolve within Design 1 §16.4's queue depth of `8`, discarding the remainder for that event, with no frame spike.

## Interpretation
19. Epsilon emits no numeric field, across 10,000 responses; every field is a selection from an enumerated set.
20. A response naming an atom id that does not exist is rejected at step 1.
21. A response naming a capability requirement is rejected; composition grants no capability (§29.5).
22. Three consecutive §17.4 failures fall through to §17.6, and the player receives a valid item.
23. A `10.0 s` timeout falls through to §17.6.
24. §17.6 produces a mask-legal, in-band composition for every one of 100,000 `(campaign_seed, ap_item_id, category)` triples, with no infinite loop.
25. §17.6 is deterministic: the same triple produces the same item across 1,000 runs.
26. The game completes fixture 19 end to end with Epsilon disabled entirely.

## Forge
27. Consolidate destroys exactly `5` Mod ranks and produces exactly `1` `USEFUL` host of the chosen category.
28. Elevate destroys exactly `5` `USEFUL` hosts and produces `1` `HIGH` host.
29. Reclaim converts `1` host into `2` Mod ranks.
30. A preserved atom appears in the output whenever it is legal at the output tier and in the output category; when it is not legal, the player is told before confirming.
31. Forging destroys its inputs only after the second confirmation press, and never on the first.
32. Forge is unavailable inside a Zone.
33. Epsilon Static is the only currency Forge consumes; Coins and Signal Keys are untouched.
34. Recomposing a `Legacy` item costs `0` Epsilon Static.

## Catalog versioning
35. Reparameterising an atom changes every existing item using it, on the next load, with no migration step.
36. Repricing an atom out of an existing item's band flags it `Legacy`; the item still functions and still equips.
37. An atom id removed from the catalog is a hard error at load; the catalog is append-only after ship.
38. A `5,000`-item Archive expands within `2.5 s` off the main thread and serializes under `1 MB`.

## Presentation
39. Every host's card shows one composition line per filled dimension, in player language, and the same atom reads identically on every item.
40. Trigger clauses render as `WHEN <event> THEN <effect>` in plain words, never as identifiers.
41. Comparison aligns two hosts by dimension, highlights differing atoms, dims identical ones, and shows derived deltas.
42. The `budget_spent` display shows the item's cost against its tier target.

## Gaps closed by the §39 traceability pass
43. A `RAIL_SWITCH` changes branch only when no actor is within `10.0 m` of the junction, and a queued change applies when the rail clears.
44. A `REACTIVE_BARREL` damages valid actors and chains at most `5` links; a `bombable` wall responds to explosive damage and an untagged wall does not.
45. An `OR` node accepts either input independently, and all eleven node types pinned from Design 1 §19.2 load.
46. `ACTION` recharge advances only on the ten facts in Design 1 §12.6, reached here through the `recharge_action` atom.
47. A composed Ability whose `recharge` atom is `recharge_action` renders with the `ACTION` HUD treatment, and the three identities remain visually distinct.

---

# 39. TRACEABILITY

All 142 acceptance tests named by the two source authorities, mapped to the coverage that closes them. Notation follows Design 2 §39: `V n` is a Design 4 vector, `fx n` a Design 4 fixture, `D1 V n` / `D1 fx n` coverage reached through an explicit pin to Design 1, **deferred** a system out of scope by §2.2.

## 39.1 Player Design Authority §35

| # | Acceptance test | Covered by |
|---|---|---|
| P1 | Empty build can move, jump, interact, melee, and defeat a basic mandatory enemy with Static Pulse. | D1 V 1 |
| P2 | Static Pulse cannot be removed from the Weapon cycle. | D1 V 2 |
| P3 | Out-of-bounds recovery returns to valid state. | D1 V 3 |
| P4 | No foreign receipt is required for the player to remain basically playable. | V 26 |
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
| P19 | Action recharge advances only on declared facts/metrics. | V 46 |
| P20 | Failed preflight spends nothing. | D1 V 35, 38 |
| P21 | Post-commit miss receives no implicit refund. | D1 V 39 |
| P22 | Recharge modifiers cannot create an unbounded self-feed loop. | V 17 |
| P23 | Resource/Cooldown/Action are visibly distinguishable in HUD. | V 47 |
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
| P37 | Same ordinary non-crit attack under same state gives same damage. | V 9 |
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
| P51 | Mod insertion/removal at the Hub has no respec fee. | V 33 |
| P52 | Only one high-tier Gear piece may be equipped across Head/Torso/Arms/Legs. | D1 V 78 |
| P53 | Hard capability gate cannot appear before guarantee. | D1 V 80 |
| P54 | Epsilon cannot invent a hard requirement. | V 21 |
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
| D9 | OR accepts either input. | V 45 |
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
| D35 | Rail branch switch selects a physically valid route. | V 43 |
| D36 | LaunchPad source/landing remains valid. | D1 V 116 |
| D37 | Grapple target exists within an audited grapple opportunity. | D1 V 117 |
| D38 | Moving platform does not strand required progression. | D1 V 111 |
| D39 | Hazard damage uses common damage road. | D1 V 119 |
| D40 | Hazard telegraphs before unavoidable contact where appropriate. | D1 V 140 |
| D41 | Hazard can affect enemies if package says it can. | D1 V 120 |
| D42 | Hazard controller correctly disables/enables it. | D1 V 121 |
| D43 | Reset restores hazard phase safely. | D1 V 141 |
| D44 | Reactive barrel damages valid actors. | V 44 |
| D45 | Bombable wall responds to tagged explosive. | V 44 |
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
| D61 | Generator state propagates to dependent room. | D1 fx 18 |
| D62 | Cross-room state survives unload/reload. | D1 V 126 |
| D63 | Dependency chain remains reachable. | D1 V 127 |
| D64 | Dungeon macro-state cannot create an accidental progression cycle. | D1 V 127, 128 |
| D65 | Puzzle reset affects only its declared reset group. | D1 V 129 |
| D66 | Completed AP Check is not undone by puzzle reset. | D1 V 130 |
| D67 | Persistent shortcut is not undone by local reset. | D1 fx 16 |
| D68 | Temporary projectiles and signals are cleared. | D1 V 131 |
| D69 | Critical active/inactive state is distinguishable without color alone. | D1 V 102 |
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
| Covered by a Design 4 test vector | 11 |
| Covered through a pin to Design 1 | 122 |
| Not applicable — system deferred by §2.2 | 9 |
| **Uncovered** | **0** |

At 11 of 133 applicable tests, Design 4 rewrites the least of any proposal so far — fewer even than Design 3. That is not thin work; it is where the work went. This proposal changes almost nothing about how the game *behaves* and almost everything about where its content *comes from*, and the authorities' acceptance tests are written about behaviour. A test like "a selected Weapon remains useful without another Weapon acting as mandatory primer" (P16) is satisfied by pinning Design 1's cycling rules, whether the game holds 24 Weapons or 175 million.

The three rows that needed this proposal's own vectors on the dungeon side — **D9**, **D35**, **D44/D45** — are there because §24 cuts the six puzzle families that exercised them. The mechanisms survive, pinned from Design 1; only the composer's ability to ask for those room shapes is gone, so the tests moved from fixtures to direct vectors.

The nine deferred tests are D48–D52 and D53–D56, the same nine every proposal defers.

---

# 40. IMPLEMENTATION WAVES

| Wave | Contents | Vectors |
|---|---|---|
| 1 | Everything pinned from Design 1 waves 1–2 and 6–20: input, movement, damage, interaction, physics, Status, Mobility, the whole dungeon | 1 |
| 2 | The atom catalog as data, with CI's §37.3 assertion | fixtures C1–C10 |
| 3 | `Composition`, `budget_spent`, and the §11.4 / §12.2 resolution orders | 2, 3, 9, 10 |
| 4 | The mask, the budget bands, and §17.4's six-step validation including the repair procedure | 4–8 |
| 5 | Trigger clauses: catalogs, costs, internal cooldowns, the caps, loop prevention | 11–18 |
| 6 | The interpretation request and response shapes | 19–21 |
| 7 | **The deterministic composer** | 22–26 |
| 8 | Archive at scale: compact serialization, off-thread expansion | 38 |
| 9 | Gear and Mod composition | — |
| 10 | Forge: the four conversions, preservation, Static as currency | 27–34 |
| 11 | Catalog versioning, `Legacy` flagging, append-only enforcement | 35–37 |
| 12 | Item cards, composition lines, comparison | 39–42 |
| 13 | The three families whose fixtures were cut | 43–45 |
| 14 | Debug: composition inspection, resolution trace, clause registry, interpretation log | — |

**Build wave 7 before wave 6.** The deterministic composer must exist and be trusted before the model is wired in, for two reasons: it is the fallback every failure path lands in, and it is the only way to generate the tens of thousands of items the balance pass needs without spending a fortune on inference. A project that builds the model path first has no way to test the budget at scale.

Waves 2–5 are the critical path and are strictly sequential.

---

# 41. CLOSURE STATEMENT

## 41.1 What this proposal decided

1. **Epsilon composes rather than selects.** Eleven or so enum choices per item instead of three, against an authored alphabet of `70` atoms across `11` dimensions.
2. **Balance is a budget, not a designer's approval.** Every composition lands in a tier band, and atom costs are the balance surface.
3. **The bands are `[85, 100]` and `[165, 180]`**, with a floor as well as a ceiling — a weak item is a failure too.
4. **Trigger clauses are budgeted separately** (§4.6.1), because a shared budget leaves most items unable to afford one at all.
5. **A clause is one event, one effect**, capped at `1` for `USEFUL` and `2` for `HIGH`, with no duplicate events and authored internal cooldowns. §12.8.1 shows exactly why this stays inside Player Authority §13.4.
6. **The space is `175,155,080` Weapons and `5,941,874` Abilities**, computed exhaustively and asserted in CI (§37.3).
7. **Mobility is not composed** (§12.7), because every mandatory-route guarantee in both authorities is computed against specific movement numbers.
8. **Static Pulse is not composed**, because the permanent baseline cannot depend on a system that can roll badly.
9. **Composition never grants a capability** (§29.5), which is what keeps §29's planner working in a world of `175` million items.
10. **§17.4's repair procedure is mask-aware and fully deterministic** — the C9 fixture exists specifically to exercise the case where the obvious repair is illegal.
11. **The deterministic composer is a first-class system**, not a degraded path, and the game is fully playable with the model off.
12. **The atom catalog is append-only after ship** (§17.7). This is a permanent constraint on the project and the largest hidden cost of the design.
13. **Repricing flags items `Legacy` rather than breaking them**, and Forge recomposes them free.
14. **Forge ships** — the only proposal of the five — with Epsilon Static as its currency, resolving the sink the other three leave dangling.
15. **Forge preserves up to two atoms**, which is the loop this proposal is built around and is only expressible because items are compositions.
16. **The `SKIRMISHER` archetype is balance-frozen** (§32.8), because every atom price is set against it.
17. **The item card is a core system** (§33.7), and the payoff of composition is that learning `70` atoms lets a player read any of `175` million items.

## 41.2 What this proposal sacrificed

| Sacrifice | What is lost |
|---|---|
| **Six puzzle families** | `ROUTE_SWITCH`, `MOVING_MACHINE`, `BOMB_BARRIER`, `OBSERVATION_TARGET`, `A_B_STATE`, `MULTI_STAGE_MACHINE`. Rooms become arenas. This proposal's dungeon is the thinnest of the five and it is not close. |
| **Designer judgement over specific items** | Nobody approves any of the `175` million. `4.7`'s pricing discipline and `16.5`'s clamps are all that stand between "legal" and "good", and they will not catch every bad combination. This is the proposal's central risk and no amount of process removes it. |
| **Thematic coherence when Epsilon is offline** | §17.6 produces mechanically sound, thematically arbitrary items. In Design 1 the offline fallback still yields a coherent designed profile; here it yields eleven random atoms. The items work; the joke stops landing. |
| **Catalog freedom after ship** | Append-only forever. An atom that turns out to be a mistake can be priced to irrelevance but never removed. |
| **A frozen reference enemy** | `SKIRMISHER` can never be retuned. |
| **Simple balance patches** | Repricing one atom changes every item using it, retroactively, across every save. That is the mechanism working, and it also means a balance pass has no blast radius smaller than "everything". |
| **Water, energy balls, beams, constraints, macro state, looping topology** | Everything Designs 2 and 3 ship, this defers. |
| **Ability base variety at high tier** | `48` in-band base compositions. Variety arrives through clauses; players will meet the same skeletons often. |

## 41.3 Proposal-level choices the authorities did not mandate

- The specific band widths and the `15`-point tolerance.
- Giving Epsilon the atom costs in the request (§17.3).
- Repairing under-budget compositions rather than rejecting them.
- Clause caps of `1` and `2` rather than `3`, chosen for readability over combinatorics.
- Mobility and Static Pulse being exempt from composition.
- Epsilon Static as Forge's currency.
- Preserving exactly two atoms at Forge.
- Append-only catalog rather than a versioned-migration scheme.

## 41.4 Where this proposal disagrees with an authority

**Nowhere**, and §0.2 lists the seven constraints it was most at risk of breaking, each with the mechanism that holds it.

One thing deserves flagging rather than burying: `recharge_dual` (§12.2) gives a high-tier Ability both charges and a resource pool, which is the shape Player Authority §13.5 warns about — *"a Cooldown Ability should not casually also require a major Resource pool."* §13.5 permits it where *"a deliberate authored template makes it legible and worthwhile."* `recharge_dual` is exactly that: a single authored atom, high-tier only, costing `40`, displayed in the HUD as two explicit constraints. It is the permitted exception rather than the rejected default, and it is named here so an owner can strike it if they disagree.

## 41.5 The claim

**Every acceptance test named by the two source authorities is covered.** §39 maps all 142: 11 to a Design 4 vector, 122 through an explicit pin to Design 1, 9 to a recorded deferral. None is uncovered.

**There are no intentionally open behavioral decisions in this proposal.**

Anything not described here is one of: pinned to a named Design 1 section; inherited from the authorities and listed in §1; rejected by a closed schema in §4; explicitly deferred in §2.2; or an engineering decision belonging to the implementer.

**And one thing specific to this proposal:** the atom catalog in §11.2, §12.2, and §16 is not illustrative. It is the shipping catalog, its costs are the shipping prices, and §37.3's assertion holds the whole design to them. A reader who wants to know what this game contains can count it.

---

**End of Complete Design 4: Epsilon Is The Content**
