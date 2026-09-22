# Overnight 04 — the engine lane's execution log

**Prod (runtime/integration).** The shared ledger is
`docs/ledgers/HUGE_BATCH_LEDGER.md`; this file is this lane's OV04 rows and
findings, split out on 2026-09-22 because both lanes append to a ledger tail
and every single merge was conflicting there. Same reason the owner gave for
lane-prefixed finding IDs: stop paying a cost that has nothing to do with the
work.

Findings are `P-n`. Rows close with revision, evidence and scope limit.

The OV04 packet replaces OV03 as the work order: 24 packages, 133 units,
`docs/` copy of the inventory not duplicated here. Rows close against this
ledger with revision, evidence and scope limit, per P00.

**P00 reconciled, once.** Tree clean at `16c198b`, branch in sync, protected
refs present and untouched (`review/0.4-m2mech-snapshot`,
`claude/archipepsi-echoes-continuation-b1adno`). Bridge lane merged through
`68eb947`. Ownership unchanged: the Python composer and every shared schema is
the bridge lane's single writer; runtime, machinery, feedback and physical
acceptance are this lane's.


### P06 — all seven additional enemy roles, implemented and verified

`make godot-roster`, **40 checks**, in CI. H1's standing row closes: the
approved family is ten and all ten now have behaviour.

**The archetype list is DERIVED, not transcribed.** `ENEMY_ARCHETYPES` was a
hand-written tuple of three beside a ten-role envelope table — the same
two-lists-for-one-fact defect the status vocabulary had. It is
`tuple(ENEMY_STATS)` now, so a role gains behaviour and becomes placeable in
one edit, and `Enemy.create`'s assert ("an approved art role is not yet a
placeable enemy") keeps saying something true with nobody maintaining a second
list.

**Each role does what its recovered brief says**, and the brief is the approved
roster's own one-liner (`docs/art/ART_REVIEW.md`), not new design:

| role | brief | what was built |
|---|---|---|
| charger | one telegraphed rush | telegraphs `charge`, aim FIXED at the telegraph, unsteerable commitment, recovery window |
| bulwark | cannot be fought frontally | 85% shrug inside a ~110° arc; measured 3.0 frontal vs 20.0 from behind |
| drifter | owns the ceiling | holds station 4.2 m up, never reaches the floor |
| diver | contests the grapple arc | no dive at a grounded player; commits when they leave the ground |
| scuttler | costs attention | 8.4 m closed in two seconds, 12 hp, 3 damage |
| artillery | indirect, denies ground | lobbed shell with flight time and a ground mark; silent inside 8 m |
| beacon | makes everything near it worse | `empowered` on neighbours through the ordinary boundary; lapses when it dies |

**Tuning is provisional and labelled.** The numbers make each role's shape
legible against the Static Pulse's ~17 DPS; none is playtested, and the package
that authorised this says missing tuning may be provisional while missing
behaviour may not.

**Three real defects found while building it:**

1. **The envelope's key is `flying`, not `is_flying`** — so both flyers fell.
   The name came from the Python attribute rather than the exported dictionary.
2. **A flyer's hover ray took the first thing it hit**, and the first thing it
   hit was whatever was standing underneath: a drifter over a charger read the
   charger's shoulders as the ground and held station 4.2 m above THEM. It
   re-casts past actors now, bounded to five tries.
3. **`ENEMY_AGGRO_RADIUS` is 18 m and artillery's reach is 34**, so the top
   half of its declared range was unusable — it could never notice what it was
   built to hit. A role notices at the greater of the two.

**`empowered` now has an enemy implementation, declared beside it.**
`stat_stack.gd` reads it for the PLAYER's `damage_dealt` and nothing read it on
an enemy, so a beacon applying it would have been an inert Status — exactly
what the per-target boundary refuses. `Enemy._hit_for()` is the implementation
and `empowered: ("self", "enemy")` is the declaration, in the same change.


### P-4 — a charger finishes its rush standing on the player

Found while measuring P06's commitment, and **not diagnosed**, which is why it
is a finding rather than a repair.

Measuring the rush with a player-shaped body in its path gave the charger's
final position as the PLAYER's position, 0.8 m up, whichever direction it had
committed to. A rushing `CharacterBody3D` walks into a player-shaped
`CharacterBody3D`, climbs it and stops, so what the measurement recorded was
the collision rather than the commitment.

Two things are separable and both are asserted, so the suite is honest about
which is which: the aim is fixed at the telegraph (measured against a real
player) and the commitment carries and ends (measured with nothing in the way,
labelled DIRECT HANDLER).

Open: whether a charger should be able to end a rush on top of the player at
all. It is a question about body separation on contact, it affects the three
original archetypes equally, and answering it by guessing is how a combat feel
gets changed by accident.

### P07 — enemies have a job, a memory and a way home

`godot-roster` grows to **49 checks**. Three units close (P07.1, P07.2,
P07.4); P07.3 navigation and P07.5 lifecycle/performance stay open and are
named below.

**P07.1 — an unwatched enemy was doing nothing at all.** The movement block had
no `else` on its aggro test, so an enemy outside 18 m stood exactly where it
was placed until the player crossed the line. A room of statues that animate on
a trigger reads as a room of triggers, and it hides every navigation defect
until the moment it matters.

Four jobs, assigned per role so each says something true about it rather than
giving everything the same walk: `patrol` (melee, charger, scuttler), `watch`
(ranged, brute, bulwark, artillery), `tend` (beacon), `drift` (both flyers).
**The fixed-role gunner is deliberate and the suite says so**: EX50-021's
gunner covers a lane and must still be covering it when the player arrives, so
a watcher never leaves its post. The case asserts movers moved AND holders
held, because asserting only the first would make every watcher a bug.

**P07.2 — interest outlives range.** Stepping a metre outside the radius
switched an enemy off mid-fight: trivially exploitable, and it read as the
enemy forgetting you while looking straight at you. Interest now runs
`ENEMY_INTEREST_SECONDS` past the last contact.

**P07.4 — a fight ends with a walk back to work.** An enemy dragged across a
room returns to the post it was placed at before resuming, so a chase does not
leave it guarding somewhere nobody asked it to guard. The post is captured on
the first physics frame rather than at construction, because a composer places
an enemy after building it.

**A real defect the case found: an enemy whose player LEFT THE SCENE never
forgot.** Interest was only decayed inside the `player != null` branch, so with
no player at all an enemy stayed permanently alert and never went back to work
— a different path from "out of range" and one nothing had exercised.

**And a test that was measuring the wrong thing, twice.** Moving the target out
of range does not test forgetting: the enemy pursues during its interest window
and legitimately catches up, so interest refreshes and never lapses — the
mechanic working. An earlier attempt moved the target to z −60, off the 40 m
stage, where it fell, died and respawned beside the enemy. The case frees the
player outright now.

**Open, and not claimed:** P07.3 (navigation on the assembled level — the
patrol beat is a radius around a post and does not consult room geometry, so a
post near a wall will walk into it and rely on the existing sidestep recovery)
and P07.5 (lifecycle and performance — nothing here measures the cost of ten
working enemies in one room).

