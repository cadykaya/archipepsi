# Archipepsi — Echo Contract (v0.8)

**Echoes 2.0.** This document is the prose for everything an Echo is, and
supersedes DESIGN §15/§19 and EPSILON_SPEC §8/§10/§12.2/§13 as they stood
in v0.7. It describes `schemas/echo.py` and `schemas/mechanics.py` at
`SCHEMA_VERSION = 8`, **which are shipped, executable and binding over
this document** in the usual authority order — S1 landed them.

Everything the rest of the packet says about Archipelago, allocation, the
transaction layer, the Zone and chamber schema, the Hub, the shop and the
finale is **unchanged**. This is a roll-forward, not a redesign.

---

# 1. What v0.7 could not express

One foreign item became one Echo. An Echo was one activated ability or one
passive multiplier. Exactly one was equipped. The whole vocabulary was six
initiators, two modifiers and two passives.

Three consequences, structural rather than incidental:

- **Echoes differed only by numbers.** Every interpretation had to land as
  a gun, a dash, a heal or a stat multiplier, so twenty-six of them read
  as one thing with twenty-six names.
- **Twenty-five were dead weight.** One slot, no reason to own the rest,
  no way for a Check to matter after the moment it was claimed.
- **Nothing could relate to anything.** No item could answer another, so
  no build ever developed.

The premise of the game is that the multiworld gradually builds a
character around you. v0.7 had no way to represent a character.

# 2. The move

An Echo stops being a thing you equip and becomes an **interpretation that
contributes components**.

```
Echo                  one per foreign Check — the umbrella fiction is unchanged
├── Action            needs a button; competes for a slot
├── Trait             continuous modifier of a derived stat
├── Resource          a HUD channel with its own economy
├── Rule              EVENT → CONDITIONS → COST → EFFECTS
├── Status            a bounded named condition, on you or on enemies
├── Affordance        a tag that widens the level generator's grammar
└── Info              a readout
```

Only **Actions** compete for a slot. Everything else is simply *true* once
owned. That alone dissolves "26 Echoes, one slot": a Check can matter for
the rest of the run without ever being equipped.

## 2.1 The ordered log and the fold

The save stores **the interpretations, in the order they were granted**.
The live mechanical state is a **pure fold** over that order.

```python
def derive_mechanics(log: Sequence[EchoInterpretation]) -> Mechanics:
    """Fold in `interpretation_seq` ascending. Pure, total, deterministic:
    same log -> same Mechanics, on any client, after any reload."""
```

### The ordering is grant order, never location id

An interpretation may target a component that existed **when it was
generated**. Location ids are assigned by Archipelago, not by the order
you find them, so folding a complete log by `source_location_id` can
replay a later-received, lower-numbered interpretation *before* the
component it targets exists. That is a corrupt fold, and it is reachable
by ordinary play.

So:

- `EchoInterpretation.interpretation_seq: int` — assigned **once**, at
  grant time, monotonically increasing across the campaign. **Immutable
  thereafter.** It is persisted; it is never recomputed, renumbered or
  inferred.
- The fold orders by `interpretation_seq` ascending, and by nothing else.
- When one reconciliation batch discovers several Checks at once, the
  sequence numbers within that batch are assigned in `source_location_id`
  ascending order. That is a **tie-break for assignment only** — once
  assigned, the sequence is the whole truth.
- `source_location_id` remains on the interpretation for provenance,
  display and dedup. It has no ordering role.

### Targets must be live at their own sequence

Every operation that names a target (`UPGRADE`, `MODIFY`, `LINK`,
`MERGE`) is validated twice: once at grant time against the mechanics as
they stand, and again on every fold, at the sequence position where the
operation replays. A fold that finds a dangling or not-yet-existing
target is a **corrupt log** and fails loudly — it is never silently
skipped, because a silently skipped operation is a build that quietly
differs from the one the player earned.

### What the fold buys

| Requirement | How the fold provides it |
| --- | --- |
| Provenance — "created by X, expanded by Y" | Every component records which interpretations touched it. That *is* the fold's input. |
| Determinism | Same log → same state, by construction. |
| Save safety | The log is append-only; derived state is always rebuildable, never repaired. |
| Families and Mk levels | "Mk III" *is* "three upgrade operations targeted this component". |
| Items modifying items | An operation can target a component an earlier interpretation created. |

It fits the architecture the packet already demands — frozen validated
value objects, changed only through the transition layer. Granting an Echo
appends one interpretation and recomputes the fold. Nothing is ever
mutated in place.

# 3. Dispositions

Each interpretation is a short list of **operations**. This is where build
evolution comes from.

| Operation | Meaning | Example |
| --- | --- | --- |
| `CREATE` | A new component | *Magic Meter* → Resource `mp` |
| `UPGRADE` | Numeric growth of something owned | *Magic Meter Upgrade* → `mp.max += 50` |
| `MODIFY` | A new capability on something owned | *Fire Flower* → the gun's hits apply `burning` |
| `LINK` | A typed relationship between two components | kills → MP |
| `MERGE` | Two economies become one | *Blue Estus* folded into the `mp` economy |

## 3.1 MERGE, hardened

`MERGE` is the only operation that can change what an id *means*, so it
carries its own rules. All are validated at grant time and re-validated on
fold.

- **Canonical resolution.** Aliases form a union-find with full path
  compression. Every id mentioned by any operation is resolved to its
  canonical component before anything else happens.
- **No self-merge.** `absorbed` and `survivor` must resolve to *different*
  canonical components. A merge whose two sides already share a canonical
  is rejected, not treated as a no-op.
- **No alias cycles.** Because both sides are resolved to canonicals
  before the alias is recorded, and the survivor must itself be a live
  canonical, a cycle is unreachable. The validator asserts it anyway; a
  cycle is a corrupt log.
- **Targets must be live canonicals.** `survivor` must resolve to a
  component that exists at that sequence position and has not itself been
  absorbed.
- **Aliases are permanent.** An absorbed id resolves to its survivor for
  the rest of the campaign. A rule, link or cost written against the old
  id keeps working forever and is never rewritten in place.
- **Provenance is unioned.** The survivor carries the full provenance of
  both sides, in sequence order. Nothing is dropped, and neither source
  item stops being credited.
- **Capacity is declared, not guessed.** The merge states its policy for
  `max_value` (`sum` or `keep_survivor`) and for presentation. Current
  values do not survive anyway — see §19, I9.
- Only resources may merge. Actions, traits and rules evolve through
  `UPGRADE`/`MODIFY`; there is no second identity mechanism.

# 4. Relationships are first-class

Four typed edges, each with a defined runtime meaning. Epsilon does not
encode these awkwardly as disconnected rules.

| Link | Runtime meaning |
| --- | --- |
| `powers(resource → action)` | The action costs that resource |
| `fills(action \| event → resource)` | Using it adds to that resource |
| `scales(resource → trait)` | The trait interpolates with the resource fraction |
| `gates(resource → action)` | The action is unavailable below a threshold |

Which makes the endgame character sheet a graph:

```
kills ──fills──▶ MP ──powers──▶ Grapple ──fills──▶ Momentum ──scales──▶ recoil
```

Four unrelated AP items; one network; inspectable as a network.

# 5. The rule engine

```
EVENT  →  CONDITIONS (all must hold)  →  COST  →  EFFECTS
```

Closed allowlists. No nesting, no `OR` (that is two rules), no arithmetic
beyond bounded numeric parameters.

**Events** (engine-emitted only): `zone_enter`, `chamber_enter`, `jump`,
`land`, `dash_end`, `kill`, `damage_dealt`, `damage_taken`, `action_used`,
`action_ready`, `parry_success`, `check_claimed`, `tick_1hz`,
`resource_full`, `resource_empty`, `low_health`, `status_applied`.

**Conditions**: `resource_at_least`, `resource_at_most`, `hp_below`,
`hp_above`, `moving_backward`, `airborne`, `grounded`, `speed_above`,
`enemy_within`, `slot_is`, `zone_is_finale`, `status_active`.

**Costs**: `resource_spend(id, amount)`. Unaffordable ⇒ the rule does not
fire. That is the entire cost vocabulary.

**Effects**: `resource_add`, `heal`, `grant_shield`, `impulse_self`,
`trait_pulse`, `damage_around`, `fire_projectile`, `apply_status`,
`reset_action_cooldown`, `refill_resource`, `grant_local_reward`.

## 5.1 Dispatch, edges, and deferral

Effects never emit events. That alone is not sufficient, because an effect
*can* move state across a threshold that the engine watches — a
`resource_add` that fills a bar is exactly the case. The full rule is:

1. **Effects write state only.** No effect emits, enqueues or raises an
   event, directly or indirectly.
2. **Threshold events are edge-triggered and derived.** At the *end* of a
   tick the engine compares each watched value against its previous
   value and derives `resource_full`, `resource_empty`, `low_health`,
   `status_applied` on the crossing edge only — never on the level.
3. **Derived events are deferred by at least one tick.** They are
   enqueued and dispatched no earlier than the next tick. Nothing derived
   inside a dispatch can be dispatched inside that same dispatch.
4. **One dispatch, one pass.** Within a dispatch every rule is considered
   at most once, against the state as it stood when the dispatch began.
5. **Cooldowns and caps.** Every rule carries a mandatory cooldown of at
   least 0.1 s, and rule firings per tick are globally capped.

> **The termination argument.** Rules cannot cascade *within* a dispatch,
> by construction — nothing produced during a dispatch is visible to it.
> Across ticks, oscillation (fill on empty, drain on full) is bounded by
> the per-rule cooldown and the per-tick cap, and every step is
> edge-triggered so a value merely *sitting* at a threshold fires nothing.

This is the most important safety property in the design.

# 6. Action primitives

Echoes 2.0 has to broaden the *verbs* as well as the systems. Actions draw
from a closed, validated catalog; every primitive has bounded numeric
parameters and a fixed slot category.

**The catalog holds 28 primitives**: 3 close combat, 6 ranged, 10 movement,
5 defensive, 4 utility. That count is not decoration — from S1 on,
`check_packet.py` derives it from the exported enum and fails if this
document and the schema disagree, because a prose catalog that quietly
drifts from the executable one is exactly the class of rot the packet's
self-check exists to prevent.

## 6.1 Close combat

| Primitive | Shape |
| --- | --- |
| `melee_swing` | Arc damage in front. Bounded reach and arc angle. |
| `melee_thrust` | Narrow, longer reach, higher single-target damage. |
| `slam_ground` | Radial damage on landing; usable only while airborne. |

## 6.2 Ranged

| Primitive | Shape |
| --- | --- |
| `hitscan_damage` | *(carried from v0.7)* pellets, spread, range. |
| `projectile_damage` | *(carried from v0.7)* speed, lifetime, plus `gravity_scale` and `bounces`. |
| `arc_lob` | Gravity-affected projectile with a fuse. |
| `burst_fire` | N shots over a bounded window from one press. |
| `charge_shot` | Hold to charge; damage and speed scale with charge time, both bounded. |
| `beam_sustained` | Continuous tick damage while held. **Must** be `powers`-linked to a resource. |

## 6.3 Movement

| Primitive | Shape |
| --- | --- |
| `dash` | *(carried from v0.7)* impulse along aim. |
| `air_dash` | Dash usable only airborne; bounded uses per airtime. |
| `double_jump` | One extra jump per airtime. |
| `wall_kick` | Jump off a surface while in contact with it. |
| `hover` | Reduced gravity while held; **must** drain a resource. |
| `glide` | Capped fall speed plus forward speed while held. |
| `blink` | Instant translation **along a validated ray to a hit surface**, bounded distance, landing point tested for clearance. Never free-space. |
| `grapple_to_surface` | *(carried from v0.7)* pull toward the hit point. |
| `grapple_pull_target` | Pull a light enemy toward you. |
| `grapple_swing` | Tethered arc from the anchor. |

## 6.4 Defensive

| Primitive | Shape |
| --- | --- |
| `shield` | *(carried from v0.7)* absorb pool for a duration. |
| `block` | Damage reduction while held; drains a resource. |
| `parry` | Short window; a hit inside it emits the engine event `parry_success`. |
| `heal_self` | *(carried from v0.7)* |
| `cleanse` | Remove statuses from self. |

## 6.5 Utility

| Primitive | Shape |
| --- | --- |
| `scan_mark` | Applies `marked` to enemies in view. |
| `restore_resource` | Refills a resource — how *Blue Estus* becomes a button. |
| `pull_pickup` | Draws nearby **local** rewards toward you. Never touches an AP reward. |
| `place_marker` | Cosmetic waypoint. |

**Deployables** — turret, decoy, temporary platform, field — remain
deferred past the staged plan. They need lifetimes, their own AI, and a
placement rule so nothing can be dropped outside Zone bounds.

Every primitive is subject to §10: nothing here may make a mandatory path
easier *to the point of being required*, and nothing here may make base
movement worse.

# 7. Resources and the HUD

Fifteen pre-laid channels. **Godot owns every pixel.** Epsilon owns
semantics: activate a channel, name it, colour it from a safe palette,
choose bar / pips / counter, set max and initial, set regen or decay, wire
rules to it. It never sees a coordinate.

Channel assignment is deterministic: creation order, which is
`interpretation_seq` ascending — so the same campaign lays out the same
dashboard every time.

**Merging over duplicating** is enforced, not encouraged: at or over
budget, `CREATE` of a resource is rejected by the validator and the
existing repair-once loop asks for `UPGRADE`, `LINK` or `MERGE` instead.

**The pressure valve.** Fifteen channels available does not mean fifteen
bars in your face. A channel renders full-size when it changed recently,
is a cost of a slotted action, or is not full; otherwise it collapses to a
thin idle strip and animates back up when it becomes relevant. HP is
always full-size.

## 7.1 Source identity and semantic colour are different things

They answer different questions and must not be conflated.

| | Chosen by | Answers |
| --- | --- | --- |
| **Source identity** — glyph, accent, sound family, particle style | Derived deterministically from the source game name (the existing sha256 rule, shared by bridge and client) | *Which world contributed this?* |
| **Semantic colour and name** — the bar's own fill and label | Chosen by Epsilon from a safe named palette, per interpretation | *What is this, in the fiction it came from?* |

So *Ocarina of Time*'s Magic Meter creates a resource Epsilon names **MP**
and paints **green**, because that is what a magic meter looks like. When
*Dark Souls III* later contributes Blue Estus to the same economy, the
refill pips carry **Dark Souls' accent and glyph** while the bar stays
green — one economy, visibly built by two worlds.

The palette is a closed set of named hues with defined light and dark
pairs, so a chosen colour is always legible on both grounds and can never
collide with the HUD's reserved semantic colours (damage, danger, AP
confirmation).

# 8. Traits, statuses, transformations

**Traits** modify derived stats: `move_speed`, `jump_height`, `gravity`,
`air_control`, `ground_friction`, `damage_dealt`, `damage_taken`,
`knockback_resist`, `regen`. A trait may be `scaled_by` a resource — or by
`hp_fraction` / `hp_inverse`, which is how *Berserker* and *Momentum* work
with no special case.

**Statuses** are bounded named conditions on self or enemies: `burning`,
`slowed`, `frozen`, `shocked`, `poisoned`, `marked`, `stunned`,
`vulnerable`, `empowered`, `low_profile`, `haste`, `regenerating`.

**Transformations** — `heavy`, `ghostlike`, `berserk`, `low_gravity`,
`super_speed` — fall out of `trait_pulse` plus a status and need no new
machinery.

`tiny` and `huge` change the **collider**, and every doorway, gap, lane
budget and enemy-fit invariant is derived from a fixed player size. That
is a second movement contract, and it is **deferred past the staged plan**
(settled decision, §22).

# 9. Slots

The control grammar is ours. Epsilon assigns a **category**; it never
invents a keybind.

| Input | Slot |
| --- | --- |
| LMB | **Static Pulse** — always, never replaced, never modified |
| RMB | Echo A |
| MMB / F | Echo B |
| Shift | Mobility |
| C | Utility / interact ability |
| Wheel | Favourites within the highlighted slot |
| Tab | Archive — compare, favourite, inspect provenance |

Static Pulse's *identity* stays untouchable, but a global `damage_dealt`
trait still multiplies its damage — which is how *Double Damage* becomes a
temporary overcharge without anything replacing the baseline weapon.

# 10. Curses and tradeoffs

1. **Never impossible.** Mandatory AP progression stays clearable with
   base movement and Static Pulse alone.
2. **Severe means removable.** A component with a serious downside must be
   bound to an Action you can take off (`requires_equipped`). *Iron Boots*
   gives enormous knockback resistance and sluggish acceleration — and you
   can unequip it.
3. **Permanent means mild.** An always-on component may carry only a
   bounded, minor downside. Permanent severe curses do not exist (settled
   decision, §22).

The movement stats the platforming derivation depends on — `move_speed`,
`jump_height`, `gravity`, `air_control` — have a **hard floor at base**.
Nothing may make you worse at clearing a gap than the base kit, so
`max_safe_gap` and every generated jump stay valid untouched. Downside
expresses in `ground_friction`, `damage_taken`, resource drain or
visibility: channels that bite without blocking.

# 11. Families and evolution

Ancestry is semantic, not textual. Because operations target component
ids, *Hookshot → Longshot → Clawshot* is one grapple with three upgrade
operations against it:

```
GRAPPLE  Mk III
  Mk I    pull to surface          <- Hookshot     Ocarina of Time
  Mk II   +12 m range              <- Longshot     Ocarina of Time
  Mk III  pulls light enemies      <- Clawshot     Twilight Princess
```

Every AP item responsible is named. Provenance is never deleted or
rewritten.

# 12. Source identity packages

Each source game deterministically yields glyph, accent colour, sound
family and particle style, derived from the game name by the sha256 rule
the bridge and client already share — so the two cannot disagree, and no
copyrighted asset is involved. These mark *contribution*: tracer and
particle style, the glyph beside a bar segment, the accent on a provenance
row. They are not the resource's own colour (§7.1).

# 13. World affordances, and the capability that pays for them

An affordance is a capability tag the player owns: `grapple_anchor`,
`breakable_wall`, `water_volume`, `bounce_pad`, `rail`, `wind_volume`,
`moving_platform`. The Zone generation request carries the unlocked set,
and Epsilon may place matching optional features.

## 13.1 The affordance registry

Each tag declares the derived-mechanic capability that makes it
*interactable*. A feature may be offered to the generator, and may appear
in an accepted Zone, **only** if that capability is satisfied. A water
volume in a run with no way to move through water is set dressing that
looks like content, and it is worse than nothing.

| Tag | Requires |
| --- | --- |
| `grapple_anchor` | An owned action in the grapple family |
| `breakable_wall` | An owned action that can deal impact damage at or above a threshold |
| `water_volume` | An owned buoyancy or aquatic-movement trait or action |
| `rail` | An owned grind or slide capability |
| `wind_volume` | An owned glide or hover capability |
| `bounce_pad` | *(none — base-kit usable)* |
| `moving_platform` | *(none — base-kit usable)* |

Capability is evaluated over **owned** mechanics, never equipped ones. You
own the grapple even when it is not slotted; you can always slot it.

## 13.2 The invariant

Enforced by the Zone validator, not by good intentions: an affordance
feature may **never** lie on the mandatory path, and may **never** host an
AP reward, an exit or an objective. It may hold local rewards (§14.2),
secrets, notes, challenge markers and cosmetics.

This generalises what the secret alcoves already do and already test — the
existing geometry test is the template.

# 14. Info components and local rewards

## 14.1 Info

Readouts are persistent once owned, occupy no slot, and never alter the
world — they only tell you about it.

| Readout | Shows |
| --- | --- |
| `enemy_health` | A bar over damaged enemies |
| `enemy_radar` | Off-screen enemy directions |
| `threat_direction` | Which way incoming fire came from |
| `secret_ping` | A faint cue near an unfound secret in the current chamber |
| `affordance_highlight` | Outlines affordance features you can actually use |
| `trajectory_preview` | Arc preview for lobbed and charged shots |
| `damage_numbers` | Numeric damage on hit |
| `resource_forecast` | Whether a queued action is affordable |
| `speedometer` | Current speed, for momentum builds |
| `challenge_timer` | Elapsed time and best on an active challenge marker |

## 14.2 Local rewards

Secrets and challenges need payoffs, and those payoffs must never be
Archipelago's. A closed catalog:

| Reward | Shape |
| --- | --- |
| `epsilon_note` | Authored text, placed in the world and archived |
| `challenge_marker` | An optional timed or scored challenge; records a personal best |
| `cosmetic_grant` | Viewmodel skin, tracer style, HUD accent |
| `hub_decoration` | An object that appears in the Hub afterwards |
| `lab_fixture` | A new fixture in the Echo Lab |
| `flavor_log` | An archive entry |

**None of these is an AP item, an AP location, a Check, an Epsilon Coin, a
Signal Key or an Echo.** They are local, cosmetic or informational, they
are recorded in the campaign save as earned, and they are worth exactly
zero to Archipelago. A local reward may never be placed on a mandatory
path either — it is a reason to explore, never a reason to be stuck.

# 15. Interpretation

Epsilon thinks in concepts before it reaches for a mechanic:

```
item -> concepts -> supported systems -> validated recipe
```

```
Water Tunic     water · buoyancy · pressure · protection
BLJ             backwards · momentum · acceleration · exploit
Master Sword    blade · heroism · anti-evil · energy
```

The concepts are **stored**, not merely used, so the inventory can say
"Epsilon read this as: water / buoyancy / pressure".

Modes: `literal` · `mechanical` · `conceptual` · `systemic`, declared per
interpretation and influenced by Epsilon's creativity setting.

> The best interpretation is not the one most similar to the source item.
> It is the one that creates the most recognisable, interesting new
> relationship between the source concept and the build the player already
> has.

If you already own three guns, *Master Sword* should not be gun four. It
should give melee, or turn full MP into sword beams, or introduce a
health-at-full conditional. This is a prompt-level rule and a budget-level
rule at once: the request tells Epsilon what you already own, and the
validator prefers dispositions that touch it.

# 16. Complexity budgets

Validation becomes **contextual** — it checks the resulting campaign
totals, not the shape of one Echo in isolation.

| Budget | Soft | Hard |
| --- | --- | --- |
| Created resources | 6 | 15 channels |
| Owned actions | 12 | — (4 slotted) |
| Rules | 14 | 20 |
| Distinct affordance tags | 8 | 12 |
| Info readouts | 3 | 5 |
| Movement stats | — | derived caps (§10) |

Over soft budget, the request asks for `UPGRADE` / `MODIFY` / `LINK` /
`MERGE`. Over hard budget, `CREATE` is rejected and the existing
repair-once loop runs. First-try acceptance **will drop**; `make replay`
is what measures it.

# 17. The Echo Lab

A permanent Hub chamber — target dummy, tall wall, long runway, gap,
damage source, moving target — growing new fixtures as new systems unlock:
a water volume when water traversal arrives, anchors when grapple does,
a rail when a grind capability does.

```
NEW MECHANIC DETECTED — TEST CHAMBER UPDATED

  EPSILON: YOU ASKED WHAT IT DOES.
           THE WALL IS RIGHT THERE.
```

So you can find out what your Stardew Valley artifact did without waiting
for a Zone that happens to suit it.

# 18. Safety invariants

Each maps to a test.

| | Invariant |
| --- | --- |
| **I1** | No component reads, writes, creates, reorders or gates an AP location or item. Structural: the schema has no such fields beyond read-only provenance. |
| **I2** | Every component is validated data from closed enums. No generated code is ever executed. |
| **I3** | Derived movement stats never fall below base. `max_safe_gap` stays valid unmodified. |
| **I4** | No mandatory path element depends on any non-base capability. |
| **I5** | Effects never emit events. Threshold events are edge-derived at end of tick and dispatched no earlier than the next tick. Rule cooldown ≥ 0.1 s; per-tick firing cap. |
| **I6** | Live mechanics are a pure fold of the log in `interpretation_seq` order. Sequence is assigned once and never changes. |
| **I7** | Severe downsides are slot-bound; permanent components carry only mild ones. |
| **I8** | Grant-time validation is against campaign totals, not one Echo in isolation. |
| **I9** | Only the log persists. Resource *definitions*, maxima and upgrades persist with it; resource *current values* and statuses reset on Zone entry, like HP. |
| **I10** | Alias soundness: no self-merge, no cycles, survivors are live canonicals, absorbed ids resolve permanently, provenance is unioned. |
| **I11** | Every operation target resolves to a live canonical component at its own sequence position, on every fold. A dangling target fails loudly. |
| **I12** | No affordance feature appears unless the owned mechanics can interact with it. |
| **I13** | Local rewards are never AP items, locations, Checks, Coins, Keys or Echoes, and never sit on a mandatory path. |
| **I14** | `blink` resolves only to a validated surface hit within bounds, with a clearance test at the landing point. |

# 19. Schema v8 and migration

`SCHEMA_VERSION` 7 → 8. `CampaignSave.schema_version` 7 → 8.
`equipped_echo_id` → `slots: dict[SlotName, ComponentId]`.

New persisted fields: `interpretation_seq` on every interpretation, and a
campaign-level `next_interpretation_seq` counter so sequence assignment
survives a reload without ever reusing a number.

Migration is a pure, total function:

- a v7 `PrimaryEcho` → one interpretation, `CREATE` one `ActionComponent`
  in `echo_a`, initiator and modifiers carried across verbatim;
- a v7 `PassiveEcho` → one interpretation, `CREATE` one `TraitComponent`
  per passive;
- `equipped_echo_id` → the `echo_a` slot, if that Echo had an action;
- `interpretation_seq` assigned in the v7 save's own echo order, which is
  grant order, so a migrated campaign folds exactly as it played.

Tested against a v7 save corpus. `make replay` must accept both versions
of the generation archive. Generated artifacts — `schemas/generated/*.json`,
`constants.gd` — are regenerated by `export.py`, never hand-edited.

> **Shipped in S1.** `schemas/echo.py`, `schemas/mechanics.py` and
> `schemas/migration.py` are the executable contract and outrank this
> document. The 28-primitive catalog count in §6 is derived from
> `ACTION_PRIMITIVES` by `check_packet.py`, so the prose cannot drift from
> the enum.

# 20. Staging

Ten stages. **Each ends with the game green and playable** — no stage
leaves it half-migrated.

| | Stage | Ships |
| --- | --- | --- |
| **S1** | Schema v8, the fold, migration | No new mechanics. v7 Echoes migrate and play identically. Sequence assignment, alias resolution, target-liveness checks. The riskiest stage, done first and alone. |
| **S2** | Action primitive catalog | §6 plus the action runner. The first stage the player can feel. Landed 21 of the 28 verbs: the other seven are not deferrals of effort but of *stage* — three `POWERED_PRIMITIVES` and `restore_resource` need a Resource to drain or refill (S3), `scan_mark` and `cleanse` need statuses (S5), and `pull_pickup` needs local rewards (S9). `IMPLEMENTED_PRIMITIVES` and `DEFERRED_PRIMITIVES` partition the catalog so a verb cannot go missing from both. |
| **S3** | Resources + HUD channels | Channel assignment, safe palette, source glyphs, contextual visibility, provenance in the inventory. |
| **S4** | Rule engine | Events, conditions, costs, effects, edge derivation, deferred dispatch, cooldowns and caps. |
| **S5** | Traits, links, statuses | Derived stat stack with clamps; the four link kinds; player and enemy statuses. |
| **S6** | Dispositions | `UPGRADE` / `MODIFY` / `LINK` / `MERGE`; families and Mk levels; source identity packages. |
| **S7** | Slots + loadout UX | Four Action slots (`SLOT_NAMES`), favourites, comparison. |
| **S8** | The Echo Lab | The Hub test chamber that grows with your vocabulary. |
| **S9** | Affordances + local rewards | Capability registry, generator grammar, the never-mandatory validator, the local-reward catalog, Info readouts. |
| **S10** | Interpretation pipeline | Concepts, modes and budgets in the Claude provider; a mock provider rich enough to keep the integration test meaningful. |

Deployables come after S10, if at all.

# 21. Honest risks

- **Scale.** Roughly Phases 2–4 of the original build combined. Several
  sessions, not one.
- **Acceptance rate.** Contextual validation makes Epsilon's job harder.
  The repair loop and the archive metric stop being nice-to-haves.
- **Emergent unfun.** Rules are where a build turns miserable — a drain on
  the resource you need most. Budgets and the movement floor mitigate;
  playtesting is the only real answer.
- **Fold cost.** The fold runs on every grant and every load. It is linear
  in log length with a tiny constant, but it is on the save path, so it
  gets a benchmark in S1 rather than an assumption.
- **Action catalog breadth.** §6 is the stage most likely to grow legs.
  Each primitive is a real physics contract with its own edge cases; S2
  ships the catalog *closed*, and anything not in it waits for a later
  version rather than being added mid-stage.

# 22. Settled decisions

| | Decision | Settled as |
| --- | --- | --- |
| 1 | Resource persistence | **Current values reset on Zone entry**, like HP. Definitions, maxima and upgrades persist with the log. |
| 2 | Permanent severe curses | **Never.** Severe downsides must be removable and equipment-bound. |
| 3 | Geometry-changing `tiny` / `huge` forms | **Deferred past S10.** |
| 4 | Packet shape | **A complete v0.8 authority packet.** v0.7 rolled forward; only what Echoes 2.0 touches is changed; no broad design review reopened. |
