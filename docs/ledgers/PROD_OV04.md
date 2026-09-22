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



### P16 — transported objects, the row that was explicitly unfinished

`godot-zone-state` grows to **56 checks**. M7 closes. The bridge lane declared
the contract (DESS-06); this is the runtime.

**Authority, not persistence, was the open half** — and D-8 §11.1 took this
lane's own proposal narrowed to exactly that: a transported object is
room-layer state **whose owning room is its current room**, and crossing a
boundary is a TRANSFER rather than a write to the machine layer. §19.7 rule 2
stays intact and nothing addresses another room; the player carries it, which
is "the player is the bridge" at its most literal.

| unit | evidence |
|---|---|
| P16.1 one identity | the declared object builds as one `ManipulableBody`, in its home room, knowing whether it is required |
| P16.2 moved physically | carried into another room's committed bounds; the room changes and `object_transported` goes out once |
| P16.3 persistence | a snapshot naming c002 builds it in c002, physically there and not merely recorded, reporting nothing for a build |
| P16.4 recovery | leaving the allowed volume recovers it home once; a saved room outside the volume is not trusted at build either |
| P16.5 status vs authority | what the save carries is the ROOM and only the room |

**A room is decided by geometry, not by who last touched it** — whichever
committed `room_bounds` contains the object. And **a doorway is not a third
place**: a position in no room keeps the room it had, so a carry across a
threshold reports once instead of flickering. That case is asserted, because
the obvious implementation reports twice.

**P16.5 is the one that is easiest to break by accident.** §5.1 puts every
`ActiveStatus` in `EPHEMERAL`, so a burning cell carried three rooms arrives
having been carried three rooms and not still burning. `TransportedObjects` has
no field a Status could ride in and never consults `ManipulableBody.statuses`;
the case asserts the reported shape is the room alone.

---

### P15 — the actuator contract, the power-loss table, and C4a closed

`godot-actuator` is new at **93 checks**, and it is the first suite in this
lane whose subject is a *document section* rather than a room: Amalgam §21, all
of it that this engine can reach.

**The engine had six actuators and no contract.** `ServiceShutter`,
`RailCarrier`, `ShuttleDeck`, `RailJunction`, `PoweredLink`'s door and
`LaunchSolver`'s pad were each built for the room that needed them, and no two
of them answered "the input reversed halfway through" or "the power went out"
the same way — because until now nobody had asked. §21.1 introduces its
transition table as *"the complete answer to what happens when a signal changes
mid-motion, and it applies to every actuator kind"*, so `Actuator` is that
answer written once, and `SafeClosure` is §21.2's interlock written once beside
it.

| unit | evidence |
|---|---|
| P15.1 the vocabulary | twelve kinds, every one with a §21.1.1 power-loss answer; seven hold, and the two that do not hold are named |
| P15.2 the transition table | ON at `t=0`, OFF at `t=1`, reverse mid-motion, reverse again mid-reversal, arrival reported once — each measured on the frame after the flip |
| P15.3 reset | animates to `initial_t` one frame's worth at a time, and **stays there** until something commands it again |
| P15.4 power loss, per kind | five carriers caught mid-motion hold at the exact `t` they were caught at and resume from it; a DOOR closes against its own input; a LAUNCHPAD goes inert; a HAZARD_CONTROLLER disables and clears its wind-up; a LIGHT_CONTROLLER travels to `unlit` |
| P15.5 §21.4 lift | selector indexes stops; changed mid-travel it redirects on the next frame and never visits the stop it was going to |
| P15.6 §21.5 path machine | rotation interpolates with position — a crane, not a slider — and it places what it drives |
| P15.7 §21.6 rail switch | an actor at 6.0 m and again at 9.9 m queues the change; at 12.0 m the **queued** change applies. Queued, never dropped |
| P15.8 §21.2 interlock | a closure interrupted halfway returns to **fully open**, retries every 1.0 s for as long as somebody stands there, and shuts on the next retry after they leave |
| P15.9 the protected set | a `required = true` object refuses a closure exactly as the player does; the same body without the marker does not |
| P15.10 the authored crusher | `safe_closure = false` closes on the player, names the body every frame of contact (§25.1 damage is a rate), and has no interlock to refuse anything |
| P15.11 C4a on the shipped machine | the same two properties on the real `ServiceShutter`, with a real doorway volume and a real body |
| P15.12 §21.1.1 on shipped carriers | a `ShuttleDeck` caught partway up its shaft and a `RailCarrier` caught partway down a span both hold at the exact position, resume the errand they were on, and are not restarted by power returning if the player stopped them by hand |
| P15.12 §21.10 refused by name | `WINCH`, `BRAKE`, `DRIVER` build nothing and say why; so does a kind outside the twelve, and so does a path §21.1's `length >= 2` cannot mean |

**C4a is closed.** `service_shutter.gd` stopped where it was and waited, which
never crushed anybody and was half of §21.2. The document requires a refused
closure to *"stop and reverse to fully open, then retry after `1.0 s`,
repeating indefinitely"*, because a panel parked halfway is still narrowing the
doorway it was asked to clear and gives the person under it no sign that
stepping aside is what it is waiting for. It reverses now.

**The suite did not cover its own defect on the first attempt, and the
sabotage said so.** Both interlock cases opened the door fully, put a body in
the doorway, and only then asked it to shut — so the panel never started
moving, and "stopped where it was" and "reversed to fully open" were the same
number. Reverting the repair left the suite green. §21.2's subject is a closure
that has *begun* ("if closing **would intersect**"), so both cases now let the
panel halfway down with the doorway clear and have somebody walk into it there.
With that correction the same revert produces **nine failures**, on the
contract class and on the shipped machine, naming the stop-and-wait behaviour
in the message.

**Two defects the cases found in the contract itself.** `reset()` originally
ended when it arrived, so an actuator whose input still said `ON` travelled
home and immediately set off again — a reset that reset nothing; a reset now
holds until the next command. And the shutter's `overrun` read `goal <= 0.0`,
which stays true after a successful closure, so the readout froze at the last
refusal's value for the rest of the Zone's life.

**Three of the twelve are not built, and say so.** §21.10's `WINCH`, `BRAKE`
and `DRIVER` drive a constraint solver this engine does not have; they are in
the vocabulary and in the power-loss table so the table has no hole, and
`Actuator.create` refuses them by name. That is **P13**'s, and a stub would
have been worse than the refusal.

**The table landed on machines that are in rooms today, not only on the new
class.** `ShuttleDeck` is the engine's LIFT and `RailCarrier` its
MOVING_PLATFORM, and neither had any notion of power at all. `power()` is
deliberately not `hold()` on the carrier: `hold()` clears `target_dock`,
because a fail-safe stop means the carrier has no errand any more, and reusing
it here would bring a carrier back powered and parked halfway down a span with
its passenger aboard and nothing to say where it was headed. §21.1 requires
power restored to *"resume toward the position the current input commands, from
wherever power loss left it"*, so the errand survives the outage.

**Not claimed by this package:** §21.11's macro-effect deferral (a `POWER_OFF`
waiting for the player to step off the gantry) belongs with the macro/signal
work; §21.3's velocity-retention-on-leaving is `sync_to_physics`'s and is
measured by `godot-physics`, not here; and the shipped machines keep their own
motion curves — `Actuator` is the contract they consult for the rules that must
be the same everywhere, not a rewrite of six working machines mid-flight.
