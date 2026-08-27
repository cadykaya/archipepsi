# Echoes 2.0 — architecture proposal

**Status: proposal. Nothing here is implemented.**

Scope: supersedes DESIGN §19 and the Echo half of EPSILON_SPEC, and
replaces `schemas/echo.py` at `SCHEMA_VERSION = 8`. Everything else in
`docs/design-packet-v0.7/` stands unchanged — the AP contract, the
transaction layer, the Zone/chamber schema, the Hub, the shop, the finale.

---

## 1. The problem with v0.7

One foreign item becomes one Echo, and an Echo is one activated ability or
one passive multiplier. Exactly one is equipped. The vocabulary is six
initiators, two modifiers, two passives.

Three consequences, all of them structural rather than incidental:

- **Echoes differ only by numbers.** Every interpretation must land as a
  gun, a dash, a heal or a stat multiplier, so twenty-six of them read as
  one thing with twenty-six names.
- **Twenty-five of them are dead weight.** One slot, no reason to own the
  rest, no way for a Check to matter after the moment it is claimed.
- **Nothing can relate to anything.** There is no way for one item to
  answer another, so no build ever develops — it is twenty-six parallel
  souvenirs.

The premise of the game is that the multiworld builds a character around
you. v0.7 cannot express a character.

## 2. The move

**An Echo stops being a thing you equip and becomes an interpretation that
contributes components.**

```
Echo (one per foreign Check — the umbrella fiction is unchanged)
├── Action           needs a button; competes for a slot
├── Trait            continuous modifier of a derived stat
├── Resource         a HUD channel with its own economy
├── Rule             EVENT → CONDITIONS → COST → EFFECTS
├── Status           a bounded, named condition applied to self or enemies
├── Affordance       a tag that widens the level generator's grammar
└── Info             a readout
```

Only Actions compete for a slot. Everything else is simply *true* once
owned. That alone dissolves "26 Echoes, one slot": a Check can matter for
the rest of the run without ever being equipped.

### 2.1 The load-bearing decision: a log, not a state

The save stores **the interpretations**, in order. The live mechanical
state is a **pure fold** over them:

```python
def derive_mechanics(interpretations: Sequence[EchoInterpretation]) -> Mechanics:
    """Canonical order: source.location_id ascending. Pure, total,
    deterministic. Same log → same Mechanics, on any client, after any
    reload, in any order the Checks actually confirmed."""
```

This is the decision everything else hangs off, and it buys five things at
once:

| Requirement | How the fold provides it |
| --- | --- |
| Provenance ("created by X, expanded by Y") | Every component records which interpretations touched it — it is the fold's input |
| Determinism | Same log → same state, by construction |
| Save safety | The log is append-only; derived state is always rebuildable, never repaired |
| Families / Mk levels | "Mk III" *is* "three upgrade operations targeted this component" |
| Items modifying items | An operation can target a component an earlier interpretation created |

It also fits the architecture the packet already demands: frozen validated
value objects, changed only through the transition layer. Granting an Echo
appends one interpretation and recomputes the fold. Nothing is mutated in
place.

## 3. Dispositions — letting items answer each other

Epsilon does not only get to invent. Each interpretation is a small list
of **operations**, and this is where build evolution actually comes from:

| Operation | Meaning | Example |
| --- | --- | --- |
| `CREATE` | A new component | *Magic Meter* → Resource `mp` |
| `UPGRADE` | Numeric growth of something owned | *Magic Meter Upgrade* → `mp.max += 50` |
| `MODIFY` | A new capability on something owned | *Fire Flower* → the gun's hits apply `burning` |
| `LINK` | A typed relationship between two components | *kills → MP* |
| `MERGE` | Two economies become one | *Blue Estus* folded into the `mp` economy |

`MERGE` keeps the absorbed id resolving to the survivor forever, so a rule
written against the old resource never dangles.

## 4. Relationships are first-class

Not encoded awkwardly as disconnected rules — four typed edges with
defined runtime meaning:

| Link | Meaning |
| --- | --- |
| `powers(resource → action)` | The action costs that resource |
| `fills(action\|event → resource)` | Using it adds to that resource |
| `scales(resource → trait)` | The trait interpolates with the resource fraction |
| `gates(resource → action)` | The action is unavailable below a threshold |

Which is what makes the endgame character sheet a *graph*:

```
kills ──fills──▶ MP ──powers──▶ Grapple ──fills──▶ Momentum ──scales──▶ recoil
```

Nobody planned that. It grew out of four unrelated AP items, and it is
inspectable as a network rather than as a list.

## 5. The rule engine, and why it terminates

```
EVENT  →  CONDITIONS (all must hold)  →  COST  →  EFFECTS
```

Closed allowlists, no nesting, no OR (that is two rules), no arithmetic
beyond bounded numeric parameters.

**Events** (engine-emitted): `zone_enter`, `chamber_enter`, `jump`,
`land`, `dash_end`, `kill`, `damage_dealt`, `damage_taken`, `action_used`,
`action_ready`, `check_claimed`, `tick_1hz`, `resource_full`,
`resource_empty`, `status_applied`, `low_health`.

**Conditions**: `resource_at_least/at_most`, `hp_below/above`,
`moving_backward`, `airborne`, `grounded`, `speed_above`, `enemy_within`,
`slot_is`, `zone_is_finale`, `status_active`.

**Costs**: `resource_spend(id, amount)`. Unaffordable ⇒ the rule does not
fire. That is the whole cost vocabulary.

**Effects**: `resource_add`, `heal`, `grant_shield`, `impulse_self`,
`trait_pulse`, `damage_around`, `fire_projectile`, `apply_status`,
`reset_action_cooldown`, `refill_resource`.

> **The termination argument.** Events are emitted **only by the engine**.
> **No effect emits an event.** So a rule can never trigger another rule
> within a dispatch, and there is no cascade to bound — it is impossible
> by construction rather than by a depth limit somebody has to maintain.
> Cross-frame oscillation (fill on empty, drain on full) is bounded
> separately by a mandatory per-rule cooldown (≥ 0.1 s) and a global cap
> on rule firings per frame.

This is the single most important safety property in the design, and it is
free if the allowlist is drawn correctly the first time.

## 6. Resources and the HUD

Fifteen pre-laid channels. **Godot owns every pixel.** Epsilon owns
semantics only: activate a channel, name it, colour it, choose continuous
bar / segmented pips / counter, set max and initial, set regen or decay,
and wire rules to it. It never sees a coordinate.

Channel assignment is deterministic: creation order, which is
`source_location_id` ascending — so the same campaign lays out the same
dashboard every time.

**Merging over duplicating** is enforced, not merely encouraged: at or
over budget, `CREATE` of a resource is rejected by the validator and the
existing repair-once loop asks Epsilon to `UPGRADE`, `LINK` or `MERGE`
instead.

**The pressure valve.** Fifteen channels available does not mean fifteen
bars in your face. A channel renders in full when it changed recently, is
a cost of a slotted action, or is not full; otherwise it collapses to a
thin idle strip and animates back up when it becomes relevant. HP is
always full-size. So the cockpit accumulates without ever needing a second
monitor.

## 7. Traits, statuses, transformations

**Traits** modify derived stats: `move_speed`, `jump_height`, `gravity`,
`air_control`, `ground_friction`, `damage_dealt`, `damage_taken`,
`knockback_resist`, `regen`. A trait may be `scaled_by` a resource (or by
`hp_fraction` / `hp_inverse`), which is how *Berserker* and *Momentum*
work without a special case.

**Statuses** are bounded named conditions on self or enemies: `burning`,
`slowed`, `frozen`, `shocked`, `poisoned`, `marked`, `stunned`,
`vulnerable`, `empowered`, `low_profile`, `haste`, `regenerating`. This is
where Mario items and elemental weapons finally have somewhere to go.

**Transformations** are timed trait sets plus a status — `heavy`,
`ghostlike`, `berserk`, `low_gravity`, `super_speed` all fall out of
`trait_pulse` and need no new machinery.

> **Where I would push back.** `tiny` and `huge` change the *collider*,
> and every doorway, gap, lane budget and enemy-fit invariant in the game
> is derived from a fixed player size. That is not a trait, it is a second
> movement contract. I recommend deferring geometry-changing forms to a
> later stage rather than cutting them.

## 8. Slots — rich, not a flight simulator

The control grammar is ours. Epsilon assigns a **category**; it never
invents a keybind.

| Input | Slot |
| --- | --- |
| LMB | **Static Pulse** — always, never replaced, never modified |
| RMB | Echo A |
| MMB / F | Echo B |
| Shift | Mobility |
| C | Utility / Interact ability |
| Wheel | Favourites within the highlighted slot |
| Tab | Archive (compare, favourite, inspect provenance) |

Note that Static Pulse's *identity* is untouchable, but a global
`damage_dealt` trait still multiplies its damage — which is how *Double
Damage* becomes a temporary overcharge without anything replacing the
baseline weapon.

## 9. Curses and tradeoffs

An interpretation may cost you something. Three rules make that safe:

1. **Never impossible.** Mandatory AP progression stays clearable with
   base movement and Static Pulse alone.
2. **Severe means removable.** A component with a serious downside must be
   `requires_equipped` — bound to an Action you can take off. *Iron Boots*
   gives enormous knockback resistance and sluggish acceleration, and you
   can unequip it.
3. **Permanent means mild.** An always-on component may only carry a
   bounded, minor downside.

Movement stats used by the platforming derivation (`move_speed`,
`jump_height`, `gravity`, `air_control`) have a **hard floor at base**:
nothing may make you worse at clearing a gap than the base kit, so
`max_safe_gap` and every generated jump stay valid untouched. Downside
expresses in `ground_friction`, `damage_taken`, resource drain, or
visibility — channels that can bite without blocking.

## 10. Families and evolution

Ancestry is semantic, not textual. Because operations target component
ids, *Hookshot → Longshot → Clawshot* is not three inventory rows; it is
one grapple with three upgrade operations against it, displayed as:

```
GRAPPLE  Mk III
  Mk I    pull to surface          ← Hookshot        (Ocarina of Time)
  Mk II   +12 m range              ← Longshot        (Ocarina of Time)
  Mk III  pulls light enemies      ← Clawshot        (Twilight Princess)
```

Every AP item responsible is named. Provenance is never deleted.

## 11. Source identity

Each source game deterministically yields an identity package — colour,
one glyph from a small procedural shape set, UI accent, a sound family, a
particle style. All derived from the game name by the existing sha256
rule, so the client and the bridge cannot disagree, and no copyrighted
asset is involved.

So MP created by *Ocarina of Time* wears Ocarina's colour and glyph, and
when *Dark Souls* later adds refill pips to that same economy, the pips
carry Dark Souls' accent. The HUD becomes a collage of the multiworld.

## 12. World affordances

An affordance is a capability tag the player owns —
`grapple_anchor`, `breakable_wall`, `water_volume`, `bounce_pad`, `rail`,
`wind_volume`, `moving_platform`. The Zone generation request carries the
unlocked set, and Epsilon may place matching optional features.

**The invariant, enforced by the Zone validator, not by good intentions:**
an affordance feature may never lie on the mandatory path, and may never
host a reward, an exit or an objective. It may hold secrets, notes,
challenge rewards, cosmetics.

This generalises what the secret alcoves already do and already test — the
existing geometry test is the template, and the inventory expands the
generator rather than creating randomizer softlocks.

## 13. Interpretation

Epsilon thinks in concepts before it reaches for a mechanic:

```
item  →  concepts  →  supported systems  →  validated recipe
```

*Water Tunic* → water / buoyancy / pressure / protection.
*BLJ* → backwards / momentum / acceleration / exploit.
*Master Sword* → blade / heroism / anti-evil / energy.

The concepts are stored, not just used — the inventory can show you
"Epsilon read this as: water / buoyancy / pressure", which is half the
charm.

**Modes**: `literal` · `mechanical` · `conceptual` · `systemic`, chosen
per interpretation and influenced by Epsilon's creativity setting.

**And the rule that decides which interpretation is good:**

> The best interpretation is not the one most similar to the source item.
> It is the one that creates the most recognisable, interesting new
> relationship between the source concept and the build the player already
> has.

If you already own three guns, *Master Sword* should not be gun four. It
should give melee, or turn full MP into sword beams, or introduce a
health-at-full conditional. That is a **prompt-level** rule and a
**budget-level** rule at once: the request tells Epsilon what you already
own, and the validator prefers dispositions that touch it.

## 14. Complexity budgets

Validation becomes **contextual** — it checks the resulting campaign
totals, not just the shape of one Echo.

| Budget | Soft | Hard |
| --- | --- | --- |
| Created resources | 6 | 15 channels |
| Owned actions | 12 | — (4 slotted) |
| Rules | 14 | 20 |
| Distinct affordance tags | 8 | 12 |
| Info readouts | 3 | 5 |
| Movement stats | — | derived caps (§9) |

Over soft budget, the request asks for `UPGRADE`/`MODIFY`/`LINK`/`MERGE`.
Over hard budget, `CREATE` is rejected and the existing repair-once loop
runs. First-try acceptance **will drop** — which is exactly what `make
replay` measures, so we will see it.

## 15. The Echo Lab

Almost mandatory once items can add arbitrary little systems. A permanent
Hub chamber with a target dummy, a tall wall, a long runway, a gap, a
damage source and a moving target — growing new fixtures as new systems
unlock (a water volume when water traversal arrives, anchors when grapple
does).

```
NEW MECHANIC DETECTED — TEST CHAMBER UPDATED
```

So you can find out what your Stardew Valley artifact did without waiting
for a Zone that happens to suit it. And Epsilon gets to be Epsilon about
it: *"YOU ASKED WHAT IT DOES. THE WALL IS RIGHT THERE."*

## 16. Safety invariants

Named so they can be tested, and each one maps to a test:

| | Invariant |
| --- | --- |
| **I1** | No component reads, writes, creates, reorders or gates an AP location or item. Structural: the component schema has no such fields beyond read-only provenance. |
| **I2** | Every component is validated data drawn from closed enums. No generated code is ever executed. |
| **I3** | Derived movement stats never fall below base. `max_safe_gap` stays valid unmodified. |
| **I4** | No mandatory path element depends on any non-base capability. |
| **I5** | Effects never emit events; every rule has a cooldown ≥ 0.1 s; rule firings per frame are capped. |
| **I6** | Live mechanics are a pure fold of the interpretation log in canonical order. |
| **I7** | Severe downsides are slot-bound; permanent components carry only mild ones. |
| **I8** | Grant-time validation is against campaign totals, not one Echo in isolation. |
| **I9** | Only the log persists. Resource values and statuses reset on Zone entry, like HP. |

## 17. Schema v8 and migration

`SCHEMA_VERSION` 7 → 8. `CampaignSave.schema_version` 7 → 8.
`equipped_echo_id` → `slots: dict[SlotName, ComponentId]`.

Migration is a pure total function, `migrate_v7_to_v8`:

- a v7 `PrimaryEcho` → one interpretation, `CREATE` one `ActionComponent`
  (`slot="echo_a"`), initiator and modifiers carried across verbatim;
- a v7 `PassiveEcho` → one interpretation, `CREATE` one `TraitComponent`
  per passive;
- `equipped_echo_id` → the `echo_a` slot, if that Echo had an action.

Tested against a v7 save corpus, and `make replay` must accept both
versions of the generation archive. Generated artifacts
(`schemas/generated/*.json`, `constants.gd`) are regenerated by
`export.py`, never hand-edited.

## 18. Staging

Nine stages. **Each one ends with the game green and playable** — no stage
leaves it half-migrated.

| | Stage | Ships |
| --- | --- | --- |
| **S1** | Schema v8 + fold + migration | No new mechanics; v7 Echoes migrate and play identically. The riskiest stage, done first and alone. |
| **S2** | Resources + HUD channels | Channel assignment, contextual visibility, provenance in the inventory |
| **S3** | Rule engine | Events, conditions, costs, effects, termination guards, budget validation |
| **S4** | Traits, links, statuses | Derived stat stack with clamps; the four link kinds; player and enemy statuses |
| **S5** | Dispositions | `UPGRADE`/`MODIFY`/`LINK`/`MERGE`; families and Mk levels; source identity packages |
| **S6** | Slots + loadout UX | Four slots, favourites, comparison |
| **S7** | The Echo Lab | The Hub test chamber that grows with your vocabulary |
| **S8** | World affordances | Generator grammar plus the never-mandatory validator |
| **S9** | Interpretation pipeline | Concepts, modes and budgets in the Claude provider; a mock provider rich enough to keep the integration test meaningful |

## 19. Honest risks

- **Scale.** This is roughly Phases 2–4 of the original build combined.
  Several sessions, not one.
- **Acceptance rate.** Contextual validation makes Epsilon's job harder.
  The repair loop and the archive metric stop being nice-to-haves.
- **Emergent unfun.** Rules are where a build turns miserable — a drain on
  the resource you need most. Budgets and the movement floor mitigate;
  playtesting is the only real answer.
- **Deployables** (turret, decoy, temporary platform) are the most
  expensive item on the list: lifetimes, AI, and a placement rule so
  nothing can be dropped outside Zone bounds. I would put them after S8,
  not inside it.
- **Teleport** should be an instant grapple along a validated ray to a hit
  surface — never free-space, which is an out-of-bounds bug waiting to be
  written.

## 20. Decisions I need from you

1. **Resource persistence.** Reset to initial on Zone entry, like HP
   (recommended — it removes a whole class of save bugs), or persist
   across Zones in the save?
2. **Permanent severe curses** — never (recommended), or allowed with a
   ceiling?
3. **Geometry-changing forms** (`tiny`, `huge`) — defer past S9
   (recommended), or design the second movement contract now?
4. **Packet shape.** This addendum supersedes Echoes only and v0.7 stands
   for everything else (recommended), or a full v0.8 packet?
