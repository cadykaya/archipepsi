# Campaign scale and content budget

**Owner decision, 2026-08-28.** Supersedes the prototype campaign shape.
Normative. Where this document and an older one disagree about campaign
size, Zone density or room composition, this one wins.

The prototype numbers — 30 locations, 3 Checks per Zone, 6 chambers, 14
enemies — proved the architecture and are not the intended game. They
stay reachable as small values; they stop being the defaults.

Target: **a ~20+ hour first playthrough**, made of Zones that read as
actual FPS levels rather than four rooms wrapped around three AP
locations.

---

## 1. Campaign options

Campaign scale moves out of binding module constants and into
Archipelago player options, because it is a per-seed choice and because
two players in one multiworld may legitimately want different sizes.

| Option | Default | Range | Meaning |
|---|---|---|---|
| `location_count` | 450 | 30 – 600 | Active Archipepsi Checks, goal included |
| `zone_target_checks` | 15 | 1 – 30 | Checks allocated to an ordinary Zone |
| `zone_budget` | 1000 | 200 – 2000 | Content value an ordinary Zone must contain |

Ranges are **bounded and tested**, not advisory. Small values stay
available for development, CI and short multiworlds; the frontier suite
runs at both ends.

The upper bounds are provisional engineering limits, not design
statements. `location_count` 600 is the size of the reserved stable ID
universe (§3); raising it is a deliberate, versioned change. If
measurement forces any bound down, the reason is recorded here and
reported, not silently applied.

### Default math

```
450 locations
  1 reserved as the goal (the finale's only Check)
449 ordinary Checks / 15 per Zone  ≈ 30 ordinary Zones + finale
```

If a 1000-budget Zone lands near ~40 minutes median, that is ~20 hours.

**The 40-minute figure is a design target, not a measurement.** It is
provisional until CS10's instrumentation and human playtests support it.
Nothing in the code may assert it, and no document may describe the
20-hour campaign as proven.

---

## 2. Per-campaign config is truth

The three options become **immutable campaign configuration**, carried in
slot data, owned by Python campaign truth, and consumed by Godot.

- Python owns them. Derived values (tier bounds, finale requirement, item
  pool split, allocation targets) are computed FROM them, never
  re-declared beside them.
- Godot **consumes** the config it is sent. It may not fall back to a
  build-time default when the bridge has told it otherwise; a client
  quietly using 30 while the campaign is 450 is a divergence, not a
  default.
- The config is fixed at generation. Nothing in play may change it.

### Legacy migration

A save or slot predating the options migrates as the **prototype**
configuration:

```
location_count      = 30
zone_target_checks  = 3
zone_budget         = (prototype marker; no budget was enforced)
```

An old campaign is **never** reinterpreted as a 450-location campaign.
Doing so would invent 420 locations the seed never had, and strand every
item the multiworld placed. This is a load-bearing rule with a test that
fails if an unversioned save is admitted at the new defaults.

---

## 3. Dynamic APWorld location count

Standard Archipelago pattern: **a bounded maximum stable ID and name
universe, of which each player instantiates only their selection.**

- The ID/name universe is declared once, at the maximum (`600`), and is
  stable forever. `Archipepsi Check 007` is id `89100007` in every seed
  regardless of anyone's `location_count`.
- A world instantiates only the first `location_count` of them.
- IDs are **never renumbered** because somebody chose a different size.
- The goal remains the **final active** location for that campaign — so
  its id varies by `location_count` while every other id does not.

### Tiers

Three bands remain three bands. The active range splits approximately
evenly across them; at 450 that is ~150 each. Signal Keys remain the two
tier-unlock progression items unless implementation shows a real reason
they cannot.

### Finale eligibility

The literal `FINALE_REQUIRED_OTHER_CHECKS = 24` was 24-of-29. It becomes
a **derived proportion of campaign size**, preserving the intent: the
finale opens after a substantial majority of non-goal Checks are done.
No new fixed integer.

---

## 4. Item pool scaling

The pool must **exactly** equal the active location count. Roles are
unchanged:

- **Signal Keys** — progression, tier unlocks
- **Epsilon Coins** — shop economy
- **Epsilon Static** — filler

Coins and Static scale deterministically from `location_count`, roughly
preserving the prototype's proportions (2 / 10 / 18 of 30) unless testing
gives a better reason. The derivation is documented where it lives, and
the split is exact: no rounding may leave the pool one item short of the
location count.

The **shop economy scales too**. Hundreds of new locations must not make
the shop effectively free (Coins everywhere) or irrelevant (prices
unreachable). Prices and restock derive from campaign config.

---

## 5. Content budget: room value

Zone density stops being "chamber count" and becomes a **content
budget**.

A room's value comes from the amount of meaningful content actually in
it. Illustrative, **not locked arithmetic**:

- A large room with ~10 enemies across waves, traversal geometry, rails,
  grapple opportunities, several Checks, a puzzle, vertical routes and
  secrets — roughly **80+**.
- A small transitional room with one enemy, a bounce pad and a simple
  beat — roughly **10**.

A `zone_budget = 1000` Zone contains approximately 1000 of real content.

### The engine computes the score. Epsilon does not.

**A provider-supplied `"room_value": 80` is not evidence that a room is
worth 80.** Epsilon chooses real structured content; Python recomputes
the value from the accepted components.

Scoring sources include shell/space complexity, encounter groups, enemy
quantity and threat, traversal motifs, puzzle complexity, interactive
machinery, optional routes, secrets, affordance opportunities and
authored setpieces. Weights live in **one authoritative, testable
table**.

Epsilon may be given a target to design toward. It may not satisfy a
budget by claiming a number.

### Checks are not content

An AP Check pedestal is **not** gameplay. A bare Check contributes zero
or near-zero.

The value is in what it takes to reach, earn or find it: the encounter,
the puzzle, the traversal route, the exploration, the secret.

Otherwise fifteen pedestals in an empty warehouse satisfy a 1000 budget.
That must be impossible, and there is a test that says so.

### Hard Zone, soft rooms

Forcing every room to an exact integer produces formulaic rooms. So:

- Rooms get **target** values and roles, with sensible tolerance.
- The **Zone** must land in a relatively narrow band around
  `zone_budget` — starting at ±10%, centralized in one constant, tuned
  from evidence.

---

## 6. Anti-degenerate composition

Budget alone is insufficient: 100 identical connectors can total 1000 and
still be a bad level. A **small number of broad constraints** forbids
degenerate output without scripting the level.

A full-size Zone should mix combat, traversal, puzzle/activity,
exploration and quieter space, optional/secret content, and at least one
memorable landmark or setpiece.

Explicitly prevented:

- an entire full-size Zone of tiny connectors
- long chains of empty rooms
- every Check in one room
- every room reusing one encounter
- every room reusing one affordance
- repeated meaningless geometry purely to reach the number

Expectations **scale with `zone_budget`**. A tiny development Zone is not
required to contain every category. Inside these constraints Epsilon is
free.

---

## 7. Rooms stop being sterile

The prototype forbade an affordance feature from sharing a chamber with a
reward or an objective. That was a cheap early proof that an optional
Echo could never gate progression.

**The invariant survives. The blanket separation does not.**

A large room MAY hold multiple Checks, enemies, puzzles, traversal,
rails, grapple anchors, bounce pads, optional Echo affordances and
secrets — **provided every AP Check and the mandatory exit remain
completable with the base movement and Static kit alone.**

The crude "cannot coexist" rule is replaced by a structural proof:
mandatory route and reward anchors, a base-kit-valid route, optional
affordance routes kept off the mandatory route, and validation of the
actually instantiated geometry where relevant.

Optional Echo capabilities may create shortcuts, alternate routes,
optional secrets, combat advantages and better-feeling traversal. They
may **never** be required for the mandatory path, an AP Check, an
objective, or the Zone exit.

### Multiple Checks per room

A sufficiently complex room may carry 2–3 independently earned Checks
corresponding to **distinct** gameplay activities. Each needs its own
clear acquisition condition and must be sent exactly once; two ids may
not share one completion edge.

### Room count

`ZONE_MAX_CHAMBERS = 6` is prototype debt and stops being the composition
target. A sane absolute safety and performance maximum stays. For a 1000
budget, 10–20 meaningful spaces is a starting envelope — an envelope, not
a lock. Fewer large complex spaces and more small ones are both legal if
the budget and constraints hold.

---

## 8. Combat scale

`MAX_ENEMIES_PER_ZONE = 14`, `MAX_ENEMIES_PER_CHAMBER = 8`,
`MAX_BRUTES_PER_ZONE = 1` and `WORST_CASE_ZONE_TTK_BUDGET = 40s`
described six-room Zones. Replacing 14 with a bigger number is not the
fix: the concepts were **conflated** and must separate.

- total enemies across an entire long Zone
- maximum **simultaneously active**
- per-encounter threat budget
- per-room encounter budget
- total Zone combat contribution to content value
- hard performance cap
- worst-case **encounter** TTK

A 40-minute Zone can contain many enemies over time without 70 on screen
at once. TTK validation reframes around **encounters**, not the whole
level's enemies as one sustained fight. Hard performance and safety caps
remain.

---

## 9. Puzzle and activity vocabulary

Production Zones need real non-combat activity, and **only implemented
primitives score**. Epsilon writing "puzzle" as flavour text earns
nothing.

A small composable graybox vocabulary — switch and multi-switch logic,
ordered target sequences, timed activation, pressure-plate routing, node
or power routing, moving-platform timing, target challenges, and
traversal combined with activation. Names are illustrative.

Prefer a few reusable composable systems over fifteen bespoke minigames.
Difficulty comes from bounded composition: element count, timing
generosity, spacing, enemy pressure, route complexity.

**Base-kit solvability is absolute.** An unimplemented puzzle tag counts
for nothing.

---

## 10. The Epsilon contract, restated

> Build me a 1000-budget Zone from these legal authored shells,
> encounters, puzzle primitives, traversal motifs, affordances and props,
> and place these 15 allocated AP Checks across it.

Epsilon decides room concepts, pacing, value distribution, composition,
encounters, puzzle and traversal combinations, optional routes, Check
distribution, landmarks and dressing intent.

Epsilon does **not** decide executable code, resource paths, unsafe
geometry, immutable AP truth, whether its own output is valid, or its own
content score.

---

## 11. The fallback is not a toy

Human playtesting currently runs on the deterministic offline fallback.
It must satisfy the **same** campaign options, allocated Check count,
zone budget, room-value calculation, composition requirements and safety
constraints as the real provider.

It does not need an LLM's prose. It does need to be representative enough
that offline playtesting exercises production-scale gameplay.

**Deterministic** means the same campaign and zone replay identically. It
does not mean every Zone is the same room list.

---

## 12. Provider output size

A 1000-budget, ~15-Check Zone is substantially more structured data than
the prototype. **Measure it.** Provider output must never silently
truncate.

If one giant Zone request proves unreliable, the fallback position is a
deterministic hierarchical pipeline: blueprint and budget distribution,
then bounded room plans, then assembled Zone validation. Epsilon still
owns composition, and the immutable interpretation log still fully
determines the built Zone. **No second mechanics truth.**

**Measured (CS9).** A Zone's JSON at the 1000-point default is 23 rooms
and about 2,100 tokens; the largest campaign anyone can configure — 30
Checks at 2000 — is 36 rooms and about 4,000. Both fit comfortably in
one response, so the hierarchical pipeline is NOT needed and was not
built. Two things did need fixing: the output allowance was a fixed
8192 set when a Zone was six rooms, and now scales with the Zone's
content budget (`claude.zone_output_budget`, 8192 to 32,000); and
`stop_reason == "max_tokens"` was not handled at all, so a response cut
off mid-Zone could parse into a valid-looking object holding a few rooms
and none of the Checks. That is now a named error rather than a small
Zone.

---

## 13. Instrumentation

Local debug and playtest output only — no external analytics or
telemetry. Recorded per session:

- Zone start/end elapsed time
- per-room dwell time
- deaths
- Checks completed
- encounter completion time where useful
- computed room and Zone content value

So that a report reads:

```
Zone 7: budget 1008 · 14 rooms · 15 Checks · player time 41m 12s
```

This is how the weights get tuned from evidence instead of asserting
"room_value 80 = four minutes" by fiat.

**Implemented (CS10).** Godot owns the clock — `PlaytimeLog`
(`godot/scripts/gameplay/playtime_log.gd`) measures elapsed time,
per-chamber dwell, deaths and encounter durations, and sends one
`zone_timing` intent as the player leaves. The bridge joins it to the
room and Zone values it computed for the same Zone and appends one line
of JSON to `playtime.jsonl` beside the saves
(`bridge/archipepsi_bridge/instrumentation.py`).

Four properties hold, and each is tested:

- **Local.** One file under the player's own save directory. No
  analytics service, no upload path, and no identifier beyond the seed
  and slot they already gave Archipelago. A test reads the module's
  imports and refuses anything that could reach a network.
- **Inert.** No campaign state depends on it, no snapshot carries it,
  and a Zone plays identically with the whole thing removed.
- **Never costly.** A failed write logs and returns. Losing the Zone a
  player just finished because a log file could not be opened would be a
  far worse trade than losing one measurement.
- **Honest about what it measured.** An abandoned Zone's elapsed time is
  not a Zone length (`completed` separates them), a room nobody entered
  reads zero rather than being absent, and a fight the player died in is
  not reported as a long encounter.

The record carries `seconds_per_budget_point`, which is the number this
whole redesign is a bet on: a 1000-point Zone that takes four minutes
means the weights in `content_value.py` are wrong, and this is how
anyone finds out. `instrumentation.summarise()` reports what the records
say and nothing more — `zones: 3` means three Zones were timed, and the
numbers are worth exactly that much.

---

## 14. Required proof

This change touches Archipelago generation, campaign truth, saves,
Epsilon schemas and Godot. It is an architecture change and is proven
like one. New invariants are **sabotage-proven**: broken deliberately,
the test confirmed to fail, then restored.

- a real AP seed generates at the 450 / 15 / 1000 defaults
- a small dev seed generates at prototype-like options
- dynamic location ids and goal are correct at several sizes
- item pool count **exactly** equals active location count
- tier boundaries correct for multiple location counts
- finale requirement scales correctly
- slot data carries campaign config
- save and reconnect preserve campaign config
- pre-option campaigns migrate as 30 / 3 prototype campaigns
- Zone allocation respects the configured target
- remainder Zones (the last, short one) work
- the goal never leaks into ordinary allocation
- computed room and Zone value **cannot be forged** by Epsilon
- empty rooms cannot cheaply satisfy a budget
- Checks alone cannot satisfy a budget
- the fallback produces deterministic but distinct Zones
- multiple Checks in one room send independently
- optional affordances in a reward room cannot gate the reward
- base-kit-only solvability still holds
- no provider failure leaves the campaign stuck in GENERATING
- large generated Zones stay performant
- the full frontier is green

---

## 15. What this document does not decide

- **The 40-minute Zone.** A target to calibrate against, not a fact.
- **Final weights.** The scoring table starts from reasoned estimates and
  is tuned from playtest evidence.
- **Art.** The art lane owns its subjective visual decisions
  independently. Engineering uses neutral technical fixtures where art is
  not yet integrated, and does not invent the art lane's choices.
