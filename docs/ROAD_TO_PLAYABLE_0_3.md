# The Road to Playable 0.3

**Owner-frozen, 2026-09-04.** Production head at freeze: `e344e2c`.

This document is the acceptance contract for the **Playable 0.3** product
milestone. The rulings in §4 and the checklist in §5 are frozen: they change
only by an explicit owner decision recorded here, not by a lane deciding a
stage was harder or easier than expected.

---

## 1. Two different things are called "0.3"

They are unrelated, and confusing them has already cost one planning
conversation.

| name | what it is |
| --- | --- |
| **design packet v0.3** | An old revision of the design document set. Superseded. The repository currently carries `docs/design-packet-v0.4`, `v0.7`, `v0.8`, `v0.9` and `v0.10`; `v0.8` holds the schema gate and `v0.10` the current catalogues. |
| **Playable 0.3** | The **product milestone** this document defines: the first build where the spatial game can be played end to end and judged. |

A packet version is a document revision. A Playable milestone is a state of
the game. **Packet v0.10 does not mean Playable 0.10, and Playable 0.3 does
not mean packet v0.3.** Always write the full name.

---

## 2. Where the project actually is

Measured at `e344e2c`, not estimated.

**Done.**

* Foundation — Archipelago / Python / Epsilon / runtime loop, and real
  activities. **29 activities audited, 0 structural failures.**
* Authored-room grammar — connectors, audits, safe entry, offer contracts.
* Room Wave 1 — **12 approved authored room shells**, all `review: pass`, all
  measuring `structural=0 measured=0`:

| chamber type | count | ids |
| --- | --- | --- |
| `arena` | 3 | `shell_hall_transit`, `shell_span_basin`, `shell_yard_gantry` |
| `tower` | 4 | `shell_plenum_helix`, `shell_tower_collapsed`, `shell_tower_gantry`, `shell_tower_spiral` |
| `corridor` | 2 | `shell_corner_left`, `shell_corner_right` |
| `treasure_room` | 3 | `shell_treasure_cache`, `shell_treasure_coffer`, `shell_treasure_vault` |

**The fact that reordered this roadmap.** No authored room has ever appeared
in a played Zone. Three measurements, each reproducible:

1. Every one of the 23 chambers in the recorded Zone carries
   `shell_id: null`. The generated chamber is a *type* and a size, never a
   shell.
2. With `shell_id` absent, `ContentInstantiator` falls back to
   `SHELL_FOR_TYPE`, and every entry in that map is a `*_proc` id.
3. So every chamber of every played Zone is built procedurally, and the Wave-1
   promotion changed the catalogue *offered* to Epsilon without changing one
   thing a player walks through.

The reading side is complete and correct: `shell_id` is on the chamber schema,
`validate_zone` refuses an id that was not offered, and `ContentInstantiator`
resolves it through the fallback chain. What is missing is that **nothing ever
writes it**. Twelve approved shells are selectable in principle and selected by
nobody.

**The consequence for planning.** Wave 1 is inventory in a warehouse. Wave 2
would be more inventory in the same warehouse. Composition is what opens the
door, so composition is load-bearing and moves to the front.

---

## 3. The road

| # | stage | outcome | state |
| --- | --- | --- | --- |
| — | Foundation | AP / Python / Epsilon / runtime loop and real activities | **Done** |
| — | Authored-room grammar | Connectors, audits, safe entry, offer contracts | **Done** |
| — | Room Wave 1 | 12 approved, selectable shells | **Done** |
| **3A** | **Live movement integration** | A player actually rides an authored rail and uses an authored launch pad | **Next — joint-first** |
| **3B** | **Authored composition** | Authored `shell_id` values appear through the real Epsilon → played Zone path | **Next — joint-first** |
| — | Theme Pack foundation | TP0–TP5 schema, fallback, material binding, authoring factory | May run alongside; blocks nothing |
| — | Environmental agency | Crate → plate/button → signal → powered door/bridge, plus reactive objects | Unstarted — carries an open owner gate (§6) |
| — | Playtest 3 | Test whether the spatial game is genuinely fun | Upcoming |
| — | Current-runtime fun pass | Drops, melee, re-entry, spurs, keys, better encounters | After Playtest 3, before runtime migration |
| — | Room Wave 2 | 2–3 strongest rooms promoted, then growth toward 20–30 | **Off the Playable 0.3 critical path** |
| — | Player / buildcraft migration | Player Authority, statuses, Mods / Gear / Forge, bounded reactions | After the game proves fun |
| — | Integrity Faults | Director, 10-minute cycles, modifiers, ~100-room library | Later |

**Why 3A and 3B are joint-first and adjacent.** A real Zone today contains zero
authored rooms and therefore zero authored offers, so movement integration has
nothing in a real Zone to bind to. 3A proves the mechanism against curated
scaffolding; 3B removes the scaffolding. Either one alone leaves a false
impression — 3A alone looks like working movement in a Zone nobody can
generate, 3B alone looks like authored rooms with no reason to be there.

---

## 4. Frozen rulings

**R1 — Joint-first milestone.** Authored composition (3B) and live movement
integration (3A) together are the next milestone. Neither is complete without
the other.

**R2 — 3A scaffolding is scaffolding.** 3A may use a deliberately curated
authored Zone, chosen to guarantee enough rail and launch exposure to exercise
the mechanism. That Zone is **temporary test scaffolding**. It is not the
eventual demo, it is not a substitute for real composition, and no acceptance
criterion may be satisfied by it alone.

**R3 — 3B is defined by the real path.** 3B is complete when authored
`shell_id` values appear through the genuine Epsilon → played Zone path and
the named shells are built. A hand-written Zone file, a test fixture or a
developer override does not satisfy 3B.

**R4 — Nothing between them.** No unrelated milestone may be scheduled between
3A and 3B. Theme Pack work may run in parallel because it blocks neither, but
it may not be sequenced *between* them.

**R5 — Wave 2 is off the critical path.** Room Wave 2 is not required for
Playable 0.3. Twelve shells, four of them offer-bearing, are enough to prove
composition, movement and agency. Wave 2 grows variety, which makes a playtest
more enjoyable but not more valid.

**R6 — 3A movement selection is an operator control.** For 3A **only**, which
movement package is active is a developer / operator playtest control. It is
explicitly **not** an Archipelago item, not progression state, not a randomized
unlock, and not a permanent addition to the Zone schema. How a package is
earned or granted in the shipped game is an undecided question and 3A must not
answer it by accident.

**R7 — Three temporary selections, Zone-wide.** The 3A selections are exactly
`none`, `rail` and `launch`, applied to the whole Zone. Each room then
contributes its own compatible offers, and the package deterministically
selects zero or more suitable offers per room. **It must not automatically
build every rail and every launch pad in every room.** `none` must leave a
Zone that plays.

**R8 — Movement offers are strictly optional.** No Check and no mandatory route
may require a movement offer. Every mandatory route must remain traversable
with zero offer geometry constructed. Making any offer load-bearing requires a
separate owner ruling **and** matching Archipelago location logic that declares
the gate — a physical gate the AP logic does not declare is the failure that
produces an unwinnable seed, and it is forbidden.

**R9 — `grapple_point` builds nothing in 3A.** There is no grapple mechanic in
this engine. `grapple_point` is validated and constructs zero nodes, by design.
3A must not report grapple support, and a package that "selects" a grapple
point must be understood as recording an opportunity, not creating one.
Grapple becomes real only when a grapple player expression exists.

**R10 — Validation still must not construct gameplay.** The `7e13f44` ruling
stands through 3A and 3B: pure validation reports accepted / declined /
refused and builds nothing; construction is a separately named, deliberate
call. Selecting offers is a third thing again, sitting between them. Do not
call something "built" when no node was constructed.

---

## 5. The frozen acceptance checklist

Playable 0.3 is complete when **all eight** hold. Each is a measurement, not a
judgement, except where it explicitly says otherwise.

**A1 — An authored room appears in an actually played Zone.**
At least one approved authored shell is named by `shell_id` through the real
Epsilon → played Zone path and is built and entered by a player. Not a fixture,
not scaffolding, not an override. *This is the floor: without it, every other
criterion could be satisfied by a fully procedural Zone.*

**A2 — A real Zone is composed from approved authored rooms.**
Composition chains multiple approved authored shells into one playable Zone,
respecting the connector grammar and entry contract.

**A3 — Activities genuinely work.**
Measured, not asserted: the activity audit reports **0 structural failures**.
The evidence at freeze is **29 audited activities, 0 structural failures**.

**A4 — At least one real movement package changes navigation.**
With a package active, a player rides an authored rail or uses an authored
launch pad in a played Zone, and the route they take differs from the route
available with `none`.

**A5 — One environmental-agency chain works end to end.**
A single complete chain — crate → plate or button → signal → powered door or
bridge — functions in play. One is enough; breadth is not a 0.3 requirement.

**A6 — The current player can complete the Zone.**
The player as it exists today, without the buildcraft migration, can finish the
Zone from entry to goal.

**A7 — A coherent short run.**
Combat, rewards, re-entry and optional paths together produce a run that reads
as a whole rather than a set of disconnected systems. *This one is a judgement
and is stated as such; it is the owner's call, made after playing.*

**A8 — Playtest 3 happens, and its findings are triaged.**
Playtest 3 is run. Every finding is triaged into exactly one of two buckets:

* **0.3-blocking** — the finding prevents the intended run or invalidates it
  (the run cannot be completed, or completing it does not demonstrate what the
  playtest was for). These are repaired before 0.3 is called complete.
* **Deferred** — everything else, recorded explicitly with a named later
  milestone. A finding may not be left untriaged, and "we should fix this
  eventually" is not a bucket.

An unbounded "repair all blocking findings" clause would let Playtest 3 absorb
arbitrary scope. The triage is what keeps the gate finite.

---

## 6. Open owner-design gates

**Environmental-agency signal persistence — UNRESOLVED.** A powered door that
stays open is persistent state. The load-bearing boundary is that persistent
state changes go through validated transitions, and derived mechanics come only
from the interpretation-log fold and are not separately persisted. Whether an
agency signal is transient within one visit, persisted across re-entry, or
derived, is **an owner design decision that has not been made**.

This document deliberately does not invent those semantics. Environmental
agency must not be implemented until that ruling exists, or it will be built
twice.

---

## 7. Explicitly not in Playable 0.3

None of these may be used to argue 0.3 is incomplete, and none may be added to
the checklist without an owner decision recorded here:

* the full player redesign and buildcraft migration (Player Authority,
  statuses, Mods / Gear / Forge, bounded reactions);
* Room Wave 2 and growth toward a 20–30 room library;
* the complete Theme Pack art refresh (TP6 Neon Transit and Void Glitch
  repair, TP7 Deep Space Derelict);
* Integrity Faults — Director, 10-minute cycles, modifiers, the ~100-room
  library;
* a shipped answer to how a movement package is earned (see R6).

---

## 8. Evidence at freeze

| fact | value |
| --- | --- |
| Production head | `e344e2c` |
| Approved authored room shells | 12 (arena 3, tower 4, corridor 2, treasure_room 3) |
| Authored registry review census | 18 `pass` / 3 `pending` (the 3 pending are projectile substitutions) |
| Activities | 29 audited, **0 structural failures** |
| Movement offers | 24 declared, 20 judged, 8 constructible, **0 declined** |
| Offer nodes built by shipped gameplay | **0** |
| Played Zone | `6e8d83d0f3ec088b` — 23 chambers, 15 Checks, 922 points, 35 enemies |
| Chambers naming an authored shell | **0 of 23** |
| Godot suites | 17 / 17 exit 0 |
| Python | 1140 passed, 0 failed, 627 subtests |
