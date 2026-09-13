# The first real playthrough — what happened, and what it means

Session of 2026-09-13. Skyah played; the engine lane watched, checked
code, ran probes, and logged. Tree at `cd620f0`, branch
`claude/archipepsi-echoes-continuation-b1adno`.

`docs/PLAYTEST_DIAGNOSTIC_RESULT.md` is the raw findings log, written
live and including two retractions. **This document is the synthesis:
what we saw, what it taught us, what we liked, what we did not, the
ideas it produced, and the problems with proposed solutions.**

---

## 1. What actually happened

A default-scale campaign (450 locations), mock Archipelago, fallback
Epsilon. One Zone, `zone_001`, 23 rooms, 15 Checks.

**It was finished.** Every Check claimed, the exit reached, the goal
beat available. That is the headline and it should not be buried under
the list below: a procedurally composed Zone at production scale was
played end to end by a human, and it worked. Branches, local keys,
colour-coded locks, warp stations, return devices, activities, enemies,
a shop, Echo upgrades and multiworld item attribution all functioned.

Along the way, in roughly this order:

- The **return pad repair** from this checkpoint was confirmed by a
  human: the device was seen before it was reached, the room's content
  was crossed to, and the return was taken deliberately. That was the
  one thing the automated harness could not produce and it is now
  closed.
- **Activity targets** were found hanging in mid-air with a wall-mount
  stalk attached to nothing.
- **An activity gave no feedback of any kind** — seven targets shot in
  one room with no way to tell whether anything had happened.
- A **warp station was repaired** by solving its room's puzzle, which
  felt earned.
- A **Check was found behind a gap** crossable only with a teleport
  Echo — the single most serious finding of the session.
- **Stairs had to be jumped** rather than walked.
- A **corridor doorway showed holes** at the seam where it meets a room.
- A **large room held one enemy and three targets in a row** on a
  walkway.
- The player got **lost holding three unused keys**, and named why: it
  is a Metroidvania with no map.
- A **pressure-plate room read as impossible**, then turned out to be
  solvable and merely illegible.
- The **exit could not be walked to**; the route was blocked and only
  reachable through holes in the geometry.
- **Taking the exit portal crashed the game.**

---

## 2. What we learned

### 2.1 The suite proves the pieces and never the assembly

This is the single most important thing the session produced. Three of
the worst findings have the same shape:

| found | what the test proved | what it never asked |
|---|---|---|
| Check behind a jump gap | the ROOM is reachable | that you can reach the thing inside it |
| stairs that must be jumped | the step is under 1.0 m | that the player body can climb it |
| holes at a doorway | each CHAMBER is sealed | that the JOIN between them is |
| the exit portal crash | the campaign reaches ALL_CHECKS_CLEARED | that anyone can walk into the portal |

Every one of those checks passed on the tree the owner played. 1526
Python tests, 19 offline Godot targets and three live-bridge suites were
all green on the exact commit that contained all four defects.

**The project has spent a long run proving that generated content is
structurally correct — the door exists, the pad is clear, the manifest
replays, the room is reachable. It has never once asked whether the
result can be finished.**

### 2.2 Validation and physics disagree, and nobody was checking

Two findings are literally the same bug:

- `MAX_VERTICAL_STEP = 1.0` decides geometry is walkable. `player.gd`
  implements **no step-up at all** — the real value is zero. The
  codebase already records this and worked around it locally once.
- AP location logic decides a Check is reachable. The physical route to
  it may need a capability AP has no vocabulary for.

In both, **a layer that decides what is reachable reasons from a number
the physics does not honour.** One makes stairs annoying. The other can
deadlock a stranger's multiworld.

### 2.3 Illegibility is not a polish problem — it blocks diagnosis

Three separate times the game could not tell the player, or this lane,
what was true:

- **Nothing casts a shadow.** Two "that object is floating" reports,
  one retracted, neither settleable by eye. The engine lane had to
  refuse a finding the owner had offered in good faith.
- **A plate's only held-state signal is a glow energy change** (3.2
  against 0.9), with no sound. A solvable two-pad room read as
  impossible, and this lane then wrote up "unsolvable by construction"
  and had to retract it. (The activity's countdown does exist — see
  problem 9 as corrected; it did not reach the player.)
- **The EXIT tracker gives a bearing through walls**, which with no map
  reads as "the exit is inaccessible."

Legibility failures did not merely annoy the player. **They produced
two wrong findings, one wasted fix, and an hour of misdirected
analysis.**

### 2.4 Reading code and reasoning is unreliable; probing is not

The engine lane formed five hypotheses from code inspection during this
session. **Four were wrong**: the hazard drums, the "unsolvable"
pressure plates, the exit portal being stranded, and the exit room
having no doors. Every probe that was actually run returned a correct
answer in minutes.

Recorded because it should change method, not just this page: **when a
question is answerable by measurement, measure it.** The fixture probes
cost four minutes each.

### 2.5 Size is not content

Activities are capped at 3 per room, lights fixed at 3 per arena, and
Checks capped by count — all against variable room dimensions. The
obvious repair, scaling each constant with floor area, is wrong. The
owner ruled it:

> big rooms are not fun on their own, they give really really good
> opportunities for fun. that distinction matters

Six lights and five targets in a row is still a room with nothing to do
in it. `topology.SPINE_SHARE` already carries the unresolved half of
this ("rooms behaved like enlarged corridors"); this is the half that
says what a fix must aim at.

---

## 3. What we liked

- **The Zone was completable and the loop closed.** Checks, Echoes,
  upgrades (`Spear of Justice` → `Mk 2` → `Mk 4`), a shop, multiworld
  attribution on a Check (`CHECK 076 (Bomb Rush Cyberfunk)`).
- **The art.** "Visually the game is way prettier." Tile trims, recessed
  rack panels, grated floors, glow bounce. The theme pack carries the
  space.
- **The ramp to a second floor with enemies on it** — the one piece of
  vertical level design that worked as intended.
- **The capability gate, as an experience.** "I can only clear it with
  the jump boost — this is actually genius!" The feeling the design aims
  at was produced, by accident, and is worth preserving legally.
- **Activity gating a warp station.** The 3-target room repaired `C018`
  and felt earned. The contract exists and works — in exactly one place.
- **Big dim rooms read as dangerous.** Currently an accident of
  arithmetic; worth converting into a decision before someone "fixes"
  the lighting and deletes it.

## 4. What we did not like

- **Puzzles that gate nothing.** Seven targets shot, nothing happened,
  the room abandoned mid-solve. "There should never be ones that do
  nothing, it will tell the player that sometimes puzzles are
  meaningless."
- **A puzzle sitting next to its own unlocked reward.** Red and gold
  keys in the open beside the target challenge that ought to earn them.
- **Races and simultaneous-plate puzzles.** Cut, on the owner's ruling:
  execution rather than decision, and trivialised by any movement Echo.
- **Enemies with no job.** No idle state exists at all — not a missing
  animation, a missing state machine. "Their whole purpose can't be to
  remain motionless until the legendary protagonist shows up."
- **Warp stations that fire instantly** instead of offering save, Hub,
  or a destination.
- **Branches that are one hallway and a dead end.** `MAX_SIDE_DEPTH = 2`
  is at its cap; the ask is variance, not a bigger number.
- **Three targets in a row in a large room**, using none of it.
- **Too hard for a new player**, stated plainly and recorded.

## 5. Ideas this session produced

1. **Static as currency** — for crafting Echoes and for recomposing a
   Zone. Mostly already designed as **Forge** (`04_EPSILON_IS_THE_
   CONTENT.md` §18) and never built. Zone recomposition is genuinely new.
2. **A `fit_low_gap` capability** — crouch/slide/prone, opening
   crawlspaces. Legal under `SOLUTIONS_CATALOGUE` §0-bis; the cost is
   the AP logic, not the animation.
3. **A pressure plate as a button that gates a reveal** — asked for
   twice by different routes, and the one atom worth keeping from the
   family being cut.
4. **Hidden targets, a block puzzle, a button that opens a wall, then a
   route** — the owner's sketch of what an activity room should be, and
   a precise statement of three things the system cannot express:
   multi-surface distribution, inter-element dependency, and line of
   sight as a placement input.
5. **Big rooms as opportunity rather than content** — the principle that
   rules out the naive density fix.

---

## 6. Every problem, in severity order

**Fixed this session**

0. ~~Taking the exit portal crashed the game~~ — fixed at `cd620f0`,
   with a regression control verified against the defect.

**Correctness — these can break someone else's game**

1. **An AP Check sits behind an undeclared capability gate.** Echoes are
   not AP items, so Archipelago cannot declare or reason about the gate
   and believes the Check reachable. A seed placing another player's
   progression item there deadlocks *that player's* game.
2. **Nothing verifies a player can walk from the spine to the exit.**
   Confirmed blocked in a live Zone; only passable through holes in the
   geometry. Graph reachability is proven, physical reachability never.
3. **`MAX_VERTICAL_STEP` is a fiction.** Validation blesses geometry at
   up to 1.0 m; the player's real step-up is zero.
4. **No join is ever seal-tested.** The leak probe builds chambers
   alone; every room meets every other room through an untested seam.
5. **Nothing checks a generated puzzle has a solution.**
   `pressure_routing`'s 28 m route budget against its actual layout is
   unchecked.
6. **The exit portal's position is never validated** — a hardcoded
   offset, and `room_audit` has no portal checks at all. Five fixtures
   land it correctly; nothing guarantees the sixth.

**Legibility — these blocked diagnosis, not just enjoyment**

7. **Nothing casts a shadow.** Grounding is unjudgeable by eye.
8. **Activity feedback does not reach the player.** *Corrected after
   independent review.* The completion path is not silent by omission:
   `_on_activity_completed` calls `tones.play("secret_found")` and the
   bank defines `"secret"`, so the call resolves to nothing. Set, hit and
   failed have no call at all. The completion cue is one wrong string;
   the rest is missing wiring.
9. **A timed activity's countdown exists and is not landing.**
   *Corrected after independent review.* `_process` ticks `_clock` and
   `_progress_text` appends `"   %.1fs"` while active. The clock is
   produced and sent to the label. What failed is its presentation, not
   its existence. Whether a sequence requirement is legible is an open
   question, not an established defect.
10. **No map**, in a game with keys, locks, branches, warps and
    backtracking.

**Design — the owner's calls, recorded not implemented**

11. Activities gate the warp station and nothing else.
12. Activity elements are mounted to nothing.
13. Density capped by count, never by room size; lights likewise.
14. Enemies have no idle state.
15. Warp stations warp instead of offering a choice.
16. Branch depth at its cap; the ask is variance.
17. 288 of 450 items are Static, against a visual cap of 18; Forge
    designed and unbuilt.
18. Too hard for a new player.

**From the independent review — source-traced, not reproduced in play**

19. **The content score rewards ingredients, not arrangement.** An
    activity scores 6 + 3/element + 4 timed + 3 ordered, with no term for
    spatial relationship or consequence. *Stated risk, not observed:*
    retiring the disliked families could drop a Zone under budget and be
    compensated with more targets or enemies — the same clutter in
    different objects. Worth checking before and after retirement.
20. **Several activities can share a station repair that happens once.**
    `repair()` returns false when already repaired. In a room with
    several activities and one broken station the first completion
    consumes the consequence. Wiring every activity to station repair
    would therefore not answer the "puzzles that do nothing" complaint.

---

## 7. Five solutions

Each addresses a cluster, not an item. They are deliberately not "fix
each bug".

### S1. The Playable Proof — one validator that plays, instead of many that inspect

**Covers 1, 2, 4, 5, 6 and prevents the next one.**

Every existing check asks a property of a part: is the door a hole, is
the spot standable, is the room in the graph. **Replace the top of that
stack with a single question asked of the whole: from the Zone's
arrival, can a body reach every Check, the exit, and every key its locks
need?**

A conservative flood-fill over the built geometry using the real
movement law — `WALK_SPEED`, `MAX_VERTICAL_STEP` *as implemented*,
`PLAYER_RADIUS`, `PLAYER_HEIGHT` — run inside the existing zone audit
against assembled Zones, reporting a count of unreachable Checks per
fixture.

This is the one change that would have caught four of tonight's six
correctness findings before a human saw them, and it makes the fifth
(puzzle solvability) expressible in the same framework. It also
converts "we think there might be undeclared gates" into a number.

*Cost:* a real piece of work, but bounded, offline, and it needs no new
gameplay. *Risk:* a flood-fill that is too permissive proves nothing —
it must use the implemented movement, not the declared one, which is
why S2 comes with it.

### S2. Make the movement law true, then make it the only authority

**Covers 3, and unblocks S1.**

`MAX_VERTICAL_STEP` must either be implemented by the player body or
deleted from validation. Two honest options, and the choice is a design
one: give the body a real step-up of 1.0 m so stairs walk, or set the
constant to 0.0 so validation stops blessing geometry nobody can climb.

**The rule that must hold either way: exactly one number, honoured by
both sides.** Every "can the player get there" answer in the project
depends on it, including S1's.

*Recommendation:* implement step-up. Stairs that must be jumped is a
comfort defect a new player will feel immediately, and "too hard for a
new player" is already on the list.

### S3. Legibility as a schema obligation, not a polish pass

**Covers 7, 8, 9 and half of 10.**

Tonight illegibility cost two wrong findings and a retracted fix. Treat
it as a correctness property: **a generated thing must declare how the
player learns its state.**

Concretely: an activity's schema entry names its feedback channels, and
the runtime refuses to present one that cannot report set, unset,
complete and failed. `tones.gd` already has the vocabulary; wiring four
call sites is hours, not a batch. A plate shows its remaining hold. A
timed activity shows its clock.

Shadows belong here too, and are a **diagnostic prerequisite** rather
than art: until an object's contact with the floor is visible, no
playtest can report grounding, and this lane cannot ask for it. Full
shadow maps may not be needed — contact decals or a chosen subset of
lights may buy the whole diagnostic value.

### S4. Give size a vocabulary instead of a multiplier

**Covers 13, 16, and the owner's principle in §2.5.**

Do not scale the constants. **Give the builders a set of things a large
room can do that a small one cannot** — verticality, separated puzzle
parts, concealment, more than one route to the same objective, a
sightline worth having — and let room dimensions *select among them*
rather than multiply a count.

The same move answers branch depth: the ask is a distribution — some
short spurs, some real side paths — not a larger `MAX_SIDE_DEPTH`.

This is also where the owner's activity sketch lands. It needs
**inter-element dependency** (one element gating another's reveal),
which does not exist and is the keystone: it is what turns a target row
into a room.

### S5. Build Forge, and let a conversion target a capability

**Covers 1's root cause, 17, and gives solo play a spine.**

Forge is specified and unbuilt. Building it makes 288 dead items a
currency. **But the decision that matters is whether a conversion may
target a semantic capability** — one of `ranged_hit`, `cross_long_gap`,
`grapple`, `blink` — rather than only a category.

If it may, the whole chain closes: Static is an AP item, so Archipelago
*can* declare "this Check requires enough Static to Elevate", *can*
prove obtainability, and the capability gate the owner enjoyed becomes
legal instead of a deadlock. Solo players get a deterministic route to
every capability.

Reading: "give me something that crosses gaps" steers a broad family and
sits inside Player Authority §26.3; "give me a 12 m dash on a 3 s
cooldown" types exact stats and sits outside it. **Only the second is
forbidden.**

*If the answer is no*, the fallback is narrower and still works:
capability gates are permitted in front of **local rewards** and
forbidden in front of **AP Checks**, which preserves the discovery
without the deadlock. The composer needs S1 to tell the two apart.

---

## 7-bis. Two recommendations accepted from the independent review

Recorded as recommendations. **Neither selects a validator architecture
nor expands this checkpoint's acceptance.**

1. **A minimal sound-reference check belongs with the feedback repair** —
   assert that every tone name a caller requests exists in the bank. That
   alone would have caught `secret_found` at build time; a textual check
   for the presence of `tones.play()` would not.
2. **Broader required-target reachability evidence belongs with external
   multiworld readiness**, not with the one-gap regression. One
   playthrough found one Check behind a gate Archipelago cannot declare
   and nothing has counted how many exist. That count is a condition on
   entering a seed with other players' games, tracked there rather than
   attached to this checkpoint.

## 8. What this adds up to

**Two different failures ran through this session and the first version
of this document collapsed them into one.** It closed by saying "what is
missing is not features but proof". That is wrong, and wrong in a way
that could do damage: it would license attaching a large validation
project to this checkpoint and treating the enjoyment problem as
addressed.

Correctness and enjoyment are separate obligations:

- **Correctness.** A Check behind a gate Archipelago cannot declare, a
  route to the exit nobody verified, a step law the body does not
  implement, a join no test covers, a crash on the transition that ends a
  Zone. Proof is the right instrument for these, and they are the ones
  that can damage a stranger's game.
- **Enjoyment.** Seven targets in a row, a warp that fires without
  asking, enemies with no job, a puzzle whose reward sits unlocked
  beside it. **A room can be provably completable and still be dull.**
  No validator supplies the missing design.

The next version should be better on both, and should not treat more
objects, more restrictions and more completion markers as substitutes for
a better room.

*Section 7's five solutions are Prod's, written before the independent
review. Section 7 has not been rewritten; read it alongside the review's
five, and note that S5's claim that capability targeting closes the AP
problem is incomplete — Elevate also consumes five `USEFUL` hosts, so
"enough Static" does not imply the recipe can be performed.*
