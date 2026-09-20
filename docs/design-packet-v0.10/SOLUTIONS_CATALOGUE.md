# v0.10 solutions catalogue — ten designs, on paper, for cherry-picking

**Status: PAPER ONLY. Nothing here is implemented and nothing here is
authorised.** `RESEARCH_MEMO.md` answers the nine questions and proves
Architecture D. This is the other half of the brief: options to choose
between, each worked far enough to build from, each checked against the
boundaries that are load-bearing.

Read `## 0` first — it is the one finding that constrains the rest.

---

## 0. The constraint that orders everything else

**Archipelago's `Accessibility` defaults to `full`**
(`.archipelago/Options.py:1334`). Full means every location must be
reachable and acquirable.

Archipelago checks that against its own model, and its model of
Archipepsi is three tiers gated on Signal Keys. It does **not** know
about Zones. Zones are a runtime allocation made by
`campaign._select_zone_locations()` — Python decides at play time which
location ids go into the Zone being built.

So the two models can disagree in exactly one direction, and it is the
dangerous one:

> Archipelago proves Check 037 is reachable. The runtime then puts
> Check 037 in a Zone the player leaves and can never return to.
> **Archipelago cannot see this and will never fail on it.** The seed is
> now unwinnable at `full` accessibility and the generator said it was
> fine.

That is not hypothetical under the new design. "Finish a Zone with 5 of
15" plus "leave a Zone unfinished" is precisely a rule that strands 10
locations per Zone unless something brings the player back.

**Therefore: design 10 (re-entry) is a hard dependency of design 1
(the 5-of-15 split), not a nice-to-have.** Ship 1 without 10 and the
default-accessibility multiworld breaks in a way no test in this repo
currently looks for and no AP generation error will catch.

Three ways out, and only the first two are real:

| | Approach | Verdict |
|---|---|---|
| **A** | Zones are re-enterable; the 10 stay reachable forever | **Recommended.** Also what the player asked for |
| **B** | Unclaimed Checks return to the allocator pool when a Zone is abandoned | **Viable**, and cheaper. See design 10 variant 2 |
| **C** | Require `Accessibility: minimal` in the YAML | **No.** Imposes a setting on everyone in the multiworld to cover our own bug |

A test belongs on this whichever way it goes: *no location may be
allocated to a Zone that the player can put permanently out of reach.*
It is the CS8b lesson again — the campaign scaled, a consumer did not —
except the consumer here is Archipelago's own solvability guarantee.

---

## 0-bis. The invariant is LOGICAL solvability, not base-kit solvability

**Superseded, 2026-08-29, by owner direction.** Earlier drafts of this
document required the whole mandatory route to be reachable with the
starting kit. That is no longer the rule and must not be restated.

A local key, a required Check, or **the Zone exit itself** may sit behind
a hard Echo capability gate — Grapple, Teleport — provided all five hold:

1. the matching AP location logic declares the same prerequisite;
2. Archipelago proves the capability progression is obtainable;
3. the physical Zone graph agrees with that AP logic;
4. the player can safely leave the blocked Zone;
5. the Zone remains re-enterable.

Explicitly legal in the target design:

```
GRAPPLE required -> red local key -> red door -> Check 5 -> Zone exit
```

...provided those AP locations are logically Grapple-gated.

**"NOT YET" is good gameplay.** The thing being protected is that the
seed is *winnable*, not that every door opens the first time you reach
it. Hard progression is the feature.

So the failure mode to guard is no longer "a gate exists". It is
**divergence**: the Zone requiring a capability that AP's logic for those
locations does not declare. Condition 1 is the one with teeth, and
conditions 4 and 5 are why `## 0` and design 10 are load-bearing — a gate
you cannot walk away from, or cannot come back to, converts hard
progression into a dead run.

Note what this does **not** relax: `max_safe_gap` and the movement floor
still bound what a gate may ask of the kit you *do* have. A declared
Grapple gate is legal; an undeclared 3-metre jump is still a bug.

---

## 1. The 5-of-15 split — required Checks and hidden Checks

**Problem.** "If a level has 15 total checks, let the player finish it
with only 5. Put the other 10 in someplace hidden."

**Mechanism.** The split is an *allocation* decision, so it belongs
where allocation truth already lives: `_select_zone_locations()` already
picks `zone_target_checks` ids by deterministic seeded shuffle over a
track round-robin. Splitting the picked list into `required` and
`optional` is one more deterministic function of the same seed, and it
persists in the save's `ZoneRecord` beside `allocated_location_ids`.

Epsilon then receives both lists and must place the required ones on the
mandatory path and the optional ones off it. The engine validates that —
it already validates placement, and this is one more rule of the same
kind. **Epsilon does not choose the split**; it composes around it.

**Which 5?** Three options, and they are not equivalent:

1. **First 5 of the shuffle.** Trivial, deterministic, and *wrong*: the
   shuffle is by track, so the required 5 skew toward whichever game's
   track came up. A player's mandatory path becomes "the Ocarina of Time
   Checks" for a whole Zone.
2. **One per track, then fill.** Spreads the mandatory path across
   source worlds, which is the multiworld texture the game is for.
   **Recommended.**
3. **By scouted classification** — required Checks are the ones holding
   progression items for *someone*. Tempting and **rejected**: it leaks
   hidden scouting information into level structure, which is the exact
   thing `ScoutedLocation._unrevealed_withholds_identity` exists to
   prevent. A player would learn what an unrevealed Check holds by
   noticing where it was placed.

**Boundary check.** Python owns it, it is deterministic, it goes in the
save through a validated transition, and nothing derived is separately
persisted. Clean.

**Risk, and it is measured, not feared.** The `room_value` budget buys
rooms without knowing which are optional. Six real Zones at the
production default:

| Zone | Rooms | Rooms holding a Check | Total value | In Check rooms |
| --- | --- | --- | --- | --- |
| zone_001 | 23 | 15 | 921 | 832 (90%) |
| zone_002 | 23 | 15 | 922 | 783 (85%) |
| zone_003 | 23 | 15 | 922 | 814 (88%) |
| zone_004 | 20 | 15 | 917 | 799 (87%) |
| zone_005 | 20 | 15 | 923 | 828 (90%) |
| zone_006 | 19 | 15 | 920 | 847 (92%) |

**89% of a Zone's content value sits in rooms that hold a Check**
(85–92%). Rooms holding no Check carry about 104 points between them.
The generator is building roughly one room per Check plus connectors,
which is also why the Zone reads as a corridor of pedestals.

So if ten of fifteen Checks become optional and their rooms become
skippable, **about 59% of the Zone goes with them.** Playtest 2.5
measured the whole Zone at 8–11 minutes; the required path would be
**3–4.5 minutes.**

**Do not read this as "optional Checks need extra spur budget."** That
is the small half. The measurement's real content is that the generator
has an accidental identity baked into it:

> one Check ≈ one room ≈ one unit of gameplay

Checks are *rewards placed through gameplay*. They must not be the
mechanism that causes gameplay rooms to exist. As long as they are, the
Zone's length is a function of its Check count, which is why 921 content
points bought 8–11 minutes and why the configurable ceiling of 2000
cannot reach 40 minutes at any setting.

**So the core route is itself too small, before any Check is hidden.**
Breaking the identity means funding PLAYER ACTIVITY independently of
Check count, and the core route needs substantial activity of its own:

- encounters
- interaction / puzzle clusters
- key and door structure
- traversal and verticality
- exploration, landmarks
- shortcuts and loops

Optional branches then receive an *additional* activity budget on top of
that — design 7 variant 2 — rather than the core being hollowed out to
pay for them.

**No numeric budgets yet. Playtest them.** Picking a number now would be
retuning against a guess, which is the mistake `CAMPAIGN_SCALE.md` §3
already records once.

**Depends on: design 10.** See `## 0`.

---

## 2. Zone-local keys, outside the Archipelago pool

**Problem.** Doom-style coloured keys, per Zone, not in the randomiser.

**Why this is safe, stated precisely.** A Zone-local key is not an item.
It never enters `itempool`, has no location id, is never scouted, never
sent, and does not survive the Zone. It is a *lock state on generated
geometry*, exactly like a door that opens when a room's enemies die —
which the engine already has as `objective: kill_all`.

**Mechanism.** Epsilon composes `lock` / `key` pairs inside one Zone as
part of the chamber vocabulary. The engine validates the pair graph
before accepting the Zone:

- every lock has at least one key reachable without passing that lock
  (no key behind its own door);
- the key graph is acyclic — no lock whose key sits behind itself,
  directly or through a chain;
- **every capability gate on the way to a key, a required Check or the
  Zone exit is declared in the matching AP location logic**, so the
  physical graph and the logical graph agree.

The last one is the whole of it, and it is `## 0-bis`'s rule applied to
keys. A key MAY sit behind Grapple. What may not happen is the Zone
requiring Grapple while AP's logic for those locations does not say so —
that is the divergence, not the gate.

It stays a graph reachability check over a handful of nodes, cheap and
deterministic, and it is testable by sabotage: build a cyclic key graph,
or a gate the AP logic does not declare, and confirm the validator
refuses both.

**Boundary check.** Clean, and notably it does *not* touch Archipelago
at all. That is the whole appeal: it buys metroidvania structure inside
a Zone with zero multiworld risk.

**Variant worth considering.** Keys as *consumed* vs *retained*. Doom
retains; retaining is more legible and lets a Zone reuse a colour for a
shortcut back. Recommend retained, discarded at Zone exit.

**Verdict: the highest value-per-risk item in this document.** It is the
only design here that adds real structure while being invisible to
Archipelago.

---

## 3. Save stations

**Problem.** Death returns the player to the Zone entrance. Playtest 2.5
lost minutes to one death, and the record now flags it as such.

**Mechanism.** A save station is a chamber-level interactable that, on
activation, sends one intent. Four capabilities were asked for and they
have *different* truth requirements — this is the design's whole
subtlety:

| Capability | Truth | Cost |
|---|---|---|
| Set respawn point | Zone-local, discarded on exit | Trivial |
| Heal | Zone-local resource state | Trivial |
| Return to Hub | Campaign transition — already exists | Small |
| Fast-travel target | **Persistent, cross-Zone** | Real |

The first three are cheap. The fourth is a persistent state change and
needs a validated transition, a save field, and a Hub UI to select from
— and it only means anything once design 10 (re-entry) exists, because
fast travel into a Zone you can never re-enter is nothing.

**Recommendation: ship the first three now, defer the fourth to
design 10.** Splitting it this way is what makes it an evening's work
instead of a week's.

**Boundary check.** Respawn and healing are simulation state Godot owns
and does not persist. Return-to-Hub is an existing validated transition.
Fast travel is the only piece that touches the save, and it is exactly
the piece to defer.

**Risk, and it is a design risk not a technical one.** A save station
that heals fully makes attrition meaningless, and attrition is most of
what makes a resource loop (design 4) matter. If both ship, the station
should heal to a cap or cost something.

---

## 4. The resource loop

**Problem.** "Enemies drop nothing, no healing, no ammo." Combat has no
consequence and no reward, so a fight is a delay.

**Four options, in increasing cost:**

1. **Drops only.** Enemies drop health and Static on death. One system,
   immediately fixes "killing things gives nothing".
2. **Drops + a scarce resource the Actions spend.** Makes the four
   Action slots a *choice* rather than a rotation. This is where the
   Echo system starts paying rent: an Echo you cannot afford to fire is
   an Echo you think about.
3. **Drops + ammo per Echo family.** Richer, and it fights the Echo
   design: an Echo's identity comes from the source world, and per-family
   ammo would add a second axis the player must track across hundreds of
   Echoes. **Not recommended at 450 locations.**
4. **Full survival-horror scarcity.** Wrong genre for a game whose Zones
   are 40 minutes and whose items arrive from other players.

**Recommendation: 1 now, 2 designed alongside it.** 1 is an evening and
is the single highest fun-per-hour change on either list.

**Boundary check.** Health and a spendable resource are simulation
state. The *derived* question — how much a given Echo costs to fire —
must come from the fold, like every other derived mechanic, and must not
be separately persisted. The rule engine already has cost atomicity
(S4), so the seam exists.

**The trap.** `CHECK_VALUE = 0` (`content_value.py:84`) exists so that
Checks do not inflate a Zone's measured content. Drops must not become a
way for Epsilon to buy budget by filling a room with enemies. Count drops
as zero content value, for the same reason and with the same test.

---

## 5. Real melee

**Problem.** No baseline melee. The player's only verb is the current
Echo.

**Mechanism.** One always-available, never-randomised, never-interpreted
attack. It is *base kit* — never randomised, never gated, present from
the first second of the first Zone.

**That matters more now, not less.** Under `## 0-bis` a Zone may gate
content behind Grapple, so the things that are *never* gated are the few
the player can always fall back on. Melee is the floor beneath the
gates, not a substitute for them:

- a Zone may require melee anywhere, with no AP declaration needed,
  precisely because every player has it in every seed;
- so whatever a Zone may require melee to *break* must stay breakable by
  melee alone, forever, at every campaign scale — a `max_safe_gap`-style
  bound, and the reason to add it the same day as the verb.

**Recommendation: base kit, and add the invariant at the same time.**
Adding the verb without the invariant is how a Zone ends up requiring an
upgraded melee the player does not have.

**Variant: should melee be upgradeable by Echoes?** Tempting, and it
collides with the boundary — an upgradeable melee is a derived mechanic
and must come from the fold, not from a separate melee-level field. If
it is upgradeable, it is upgradeable *through* the interpretation log
like everything else, and the base capability must remain sufficient.

---

## 6. Killing the through-wall Check text

**Problem.** "Get rid of the text telling you where a check is through
walls lol."

**Two channels currently say it**, and they should be treated
differently:

1. **The per-Check `StateLabel`** (`reward.gd:104`) — a billboarded
   `Label3D` floating above every pedestal.
2. **The HUD counter** (`zone_controller.gd:343`) — `CHECKS n/m
   CLAIMED`, centre-top. This is a *count*, not a pointer, and it is not
   the offender.

**The label is already redundant.** Art requirement 11 landed
`RewardObject.state_profile()`: LOCKED and CONFIRMED are now different
*forms*, measured from geometry, precisely so the state does not need
words. The label survives only as a name.

**Options:**

1. **Delete the label.** Cleanest. State is form; identity is the item
   visual and its source tint.
2. **Keep it, but only within a few metres.** Half a fix — it still
   points through a wall, just a nearer one.
3. **Move identity to an inspect verb.** The player looks at a pedestal
   and a HUD line names it. **Recommended**: it keeps the information
   the player wants, removes the beacon, and rewards approaching.
4. **Replace with diegetic signage** — the Zone's own transit signs name
   what is down each branch. Best-feeling, most expensive, and it is
   partly the navigation language art has not chosen yet
   (`objective_marker` / `signage_module` are still blocked).

**Recommendation: 1 + 3 together.** They are one change and it is small.

**Note.** Option 4 depends on an art decision that is explicitly not
engineering's; do not build it as a way of forcing that decision.

---

## 7. Zone topology — stopping the hallway

**Problem.** "These maps are all hallways." Correct: `ZoneBuilder` walks
a cursor forward, chaining chambers with connectors and occasional 90°
corners. It is a **path**, structurally. No amount of per-room content
changes that, which is why 921 content points still felt empty.

**Five topologies, from cheapest to most structural:**

1. **Path** (today). One chain.
2. **Path + dead-end spurs.** A connector occasionally branches to a
   short spur holding an optional Check. Cheapest possible change, and
   it is enough to make design 1 mean something. The mandatory path is
   still the chain, so every existing invariant survives untouched.
3. **Path + shortcuts.** A spur rejoins the chain further along, opened
   from the far side. This is the Dark Souls loop and it is what makes a
   level feel like a place. Needs the builder to close a cycle in world
   space — real work, because placement is currently proven safe by
   never revisiting.
4. **Hub-and-spoke.** A central chamber with several branches, one
   gated per Zone-local key colour. Doom's actual shape. Pairs
   perfectly with design 2.
5. **Open graph.** Full metroidvania. Every placement invariant becomes
   a graph problem. Not a v0.10 target.

**Recommendation: 2 now, 4 as the real target, 3 after.** 2 is a
week-one change that design 1 *requires* rather than merely benefits
from — spurs are where the optional Checks' activity comes from, on top
of a core route that has to grow its own (design 1); 4 is the one that
answers "I wanted the maps to be big and interconnected".

**The hard part, named.** `_overlaps()` proves placements disjoint by
checking each candidate against every prior bounds. That works because
the layout never comes back on itself. Topologies 3–5 *must* come back
on themselves, so the guarantee has to change from "never revisit" to
"revisit only at a declared join". **That is the actual engineering in
this document**, and it is worth a proof of its own before anything is
built on it.

---

## 8. Physics objects and a puzzle vocabulary

**Problem.** No physics objects, no launch pads, no puzzles.

**The boundary makes this easier than it looks.** Epsilon may not invent
mechanics; it composes from a closed vocabulary (S19 enforces this
*structurally* — every string field is a closed set or a charset that
cannot spell a path). So a puzzle vocabulary is a developer-authored
alphabet, and the design question is only: which letters?

**A minimal set that composes into real puzzles:**

| Primitive | Verb it creates |
|---|---|
| Carryable weight | pick up, place, block, weigh down |
| Pressure plate | hold a state while weighted |
| Launch pad | reach a place legs cannot |
| Breakable barrier | melee has a use (design 5) |
| Moving platform | timing |
| Light/beam + receiver | line of sight as a resource |

Six letters produce far more than six puzzles, and every one of them is
a *physical* thing the existing chamber grammar can host.

**Two rules that must hold, and they are the same rule twice:**

1. **Gate deliberately, and declare it.** `ECHOES.md` §13.2 forbids a
   mandatory Check behind an *affordance* — an unowned, incidental
   dependency. A declared capability gate is the opposite of that and is
   legal under `## 0-bis`: a required puzzle MAY need Grapple, provided
   the AP logic for that location says so. What stays forbidden is the
   undeclared version, where the Zone needs an Echo that AP never
   required the player to have.
2. **A physics object must not be able to leave the room.** A carryable
   dropped through the geometry, or thrown into the void, can make a
   required puzzle unsolvable — and the player cannot tell that has
   happened. Either objects respawn on a timer, or puzzles have a reset,
   or both. **This is the single most likely source of a soft-lock in
   this entire document.**

**Recommendation.** Launch pad and breakable barrier first (no
soft-lock surface at all). Carryable + pressure plate second, with the
reset rule designed in from the start rather than added after the first
report of a lost cube.

---

## 9. Capability-gated optional content — Architecture D, applied

**Problem.** Hard progression is a feature. Some content should be
impossible until a capability exists.

**This is the one design already proven** (`RESEARCH_MEMO.md` §0):
capability events plus access rules generate clean, and an unsatisfiable
gate *fails generation* rather than producing a dead seed.

**Applied to the 10 optional Checks:** an optional Check may sit behind
a capability the player does not yet have. Archipelago will enforce that
the capability is obtainable. The player sees a ledge they cannot reach
and comes back — which is metroidvania, and which is what makes design
10 (re-entry) valuable rather than merely necessary.

**Where it can still go wrong, and Archipelago will not help:** AP
enforces the gate *in its own model* — tiers and capability events. It
does not know that Zone 4's grapple ledge is physically in Zone 4. The
runtime allocator must not put a capability-gated location in a Zone the
player cannot re-enter. Same failure as `## 0`, same fix.

**Recommendation: build the groundwork in the memo's order** — capability
map in `slot_data`, then the allocator filter, then the interpretation
validator that *enforces* the family. The third is where D lives or dies
and deserves its own sabotage proof.

---

## 10. Leaving a Zone, and coming back

**Problem.** "Leave a zone unfinished, unlock/select zones." And, from
`## 0`, this is also a correctness requirement rather than a feature.

**Three designs:**

1. **Zones persist.** A Zone is generated once, its layout stored, and
   re-entering rebuilds the same level with claimed Checks already
   claimed. Everything the player asked for, and the most storage: a
   layout per Zone for up to 30 Zones. Generation is already
   deterministic from a seeded request, so **the stored thing is the
   request, not the geometry** — which makes this far cheaper than it
   sounds and keeps the archive as the single source of truth.
   **Recommended.**
2. **Zones dissolve; Checks return.** Leaving an unfinished Zone returns
   its unclaimed ids to the allocator pool. **This is not something to
   build — it is what the allocator already does**: a disposable proof
   generated a real Zone and flipped its state, and a terminal Zone hands
   back 15 of 15 unclaimed Checks while a non-terminal one hands back 0
   (`RESEARCH_MEMO.md` §6b). So this variant is "make CLEARED terminal"
   and nothing else. Cheapest, fully satisfies `## 0`, and loses the
   metroidvania promise entirely — the ledge you could not reach does not
   exist any more; that Check simply turns up in a later Zone.
3. **Zones persist only while unfinished.** A hybrid: a Zone stays
   re-enterable until exhausted, then dissolves. Bounded storage,
   keeps the promise. **Good fallback if 1's storage is a problem.**

**Boundary check on option 1.** The stored request is already validated
and already archived (`replay_archive` re-validates the generation
archive). Re-entry replays it. Nothing derived is persisted; the fold
still owns mechanics. This fits the existing architecture unusually
well.

**Risk.** A stored request replayed after the *engine* changes may build
a different level — which is exactly what the Playtest 2.5 baseline
tripwire already detects for the corpus Zones. The same tripwire shape
applies here, and a player's stored Zone must either replay identically
or be openly regenerated, never silently changed.

---

## Cherry-picking guide

**If you want the biggest fun-per-hour, in order:**

1. Design 4 variant 1 (drops) — an evening
2. Design 5 (melee) — an evening, with the invariant
3. Design 3, first three capabilities (save stations) — an evening
4. Design 7 variant 2 (spurs) — a week, and it unlocks design 1
5. Design 2 (Zone-local keys) — a week, zero AP risk, most structure

**If you want the redesign the brief is really about:** designs 1 + 10 +
9 together, in that dependency order, with `## 0`'s test written
*first*. They are one change and none of the three is safe alone — and
design 1 needs design 7 variant 2 underneath it, because 89% of a Zone's
content is in its Check rooms. Before any of it, the core route has to
stop being one room per Check: fund activity, not pedestals (design 1).

**What not to start with:** design 8's carryables (soft-lock surface
before the reset rule exists), design 7 variants 3–5 (needs the
placement proof first), design 3's fast travel (meaningless before 10).

**What is decided by a person, not by more research:** which 5 of 15 is
a feel question once the mechanism is chosen; whether melee upgrades;
whether a save station heals fully. Those are yours.
