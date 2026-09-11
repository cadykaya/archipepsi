# Amalgam slice 1 — engine lane

**Branch:** `claude/archipepsi-amalgam-slice1`
**Started from:** `c8ed2e9` (Production; the playable checkpoint branch is
`claude/archipepsi-echoes-continuation-b1adno`, head `8bb6a05`)
**Lane:** Prod — Godot implementation and integration only. No bridge
schema, no graph, no AP allocation; those are Dess's column and nothing
here implements them.

---

## 1. What is playable

Run the game with `--slice1` and the Zone you enter carries, in addition
to everything it carried before:

- **A three-door junction.** One wide arena uses `entry`, `exit` and
  `side_left`, and declares `side_right` `SEALED`. Three apertures are
  cut; the fourth wall is solid and is *measured* as solid.
- **A red lock and a red key.** `side_left` is `LOCKED`. Its slab stands
  in a carved opening — walk into it without the key and it stops you.
  The key is placed in an earlier room, in space that room reserved for
  it, and picking it up opens every lock it admits anywhere in the Zone.
- **A return plug.** In the last wide room, a pad that lands you back at
  the Zone start. Walking in returns you; walking out re-arms it.

Everything else about the Zone is unchanged. The fixture adds an
assignment; it never changes a room's dimensions or removes content.

**Without `--slice1` the junction, the lock, the key and the plug do not
exist**, and an ordinary run is otherwise what it was.

**Warp stations are the exception and are deliberately NOT flag-gated.**
§30.12.4 makes them part of what a Zone *is* — entrance, exit and large
rooms — rather than a slice feature, and the Amalgam is now the
implementation target, so they are placed in every Zone this branch
builds. That is a gameplay change to ordinary play on this branch and is
called out here rather than left to be discovered.

## 2. How to run it

The bridge and the Windows launchers are unchanged. From a checkout of
this branch:

```
# 1. the bridge, as usual
python -m archipepsi_bridge --ap mock --epsilon fallback \
    --save-dir slice1

# 2. the game, with the flag
godot-bin/godot --path godot -- --slice1
```

Both movement flags still apply, so `--slice1 --movement-package=rail`
composes the slice inside a rail Zone.

On Windows the existing `Play 3AB - none (Windows).bat` works if you add
`--slice1` to the Godot line; the launcher was not changed, because
changing it would change the playable checkpoint's launcher too.

**Headless, if you only want to see it compose:**

```
make godot-room-contract
```

The slice's own checks print `ESCAPE`/junction lines and the suite fails
if any of them regress.

## 3. What is implemented and proved

Each of these has a test that fails when the thing it guards is removed;
that was verified by removing them.

| Piece | Where | Proof |
|---|---|---|
| Joining sockets resolved by **id**, not name | `content_instantiator.gd` `socket_by_id` / `socket_for_edge` | every existing shell still composes through the legacy alias path |
| A procedural room **declares four joining sockets** | `chamber_builders.gd` `procedural_sockets` | the junction's side doors land on opposite walls |
| **N apertures carved** from the assignment | `chamber_builders.gd` `cut_plan`, `_perimeter` | three carved, one not |
| **The seal is measured, inverted** | `room_audit.gd` `_assigned_doors_match_their_usage` | a solid wall re-declared `USED` is caught; deleting the probe turns the suite red |
| **A lock is content in a carved opening** | `locked_door.gd`, `space_probe.gd` | the slab blocks with no key and is gone with one; the aperture still measures as a hole |
| **Zone-local keys** | `zone_key.gd`, arena reservation | the key's space is reserved by the room that holds it |
| **Return plugs** | `return_plug.gd`, `zone_builder.gd` anchors | a plug naming an unknown anchor is refused; the destination admits a standing capsule |
| **`LayoutResult` commits the whole chain** | `zone_builder.gd` | `rooms` + `links` per edge, with every connector and corner |
| **Timeout ≠ infeasible** | `zone_builder.gd` | a 0.001 ms budget yields `LAYOUT_TIMEOUT` with candidates remaining |
| **Infeasible is exhausted** | `zone_builder.gd` | a Zone that doubles back into its own arm exhausts the **shipping** policy and reports it; a tightened policy exhausts too, which is what makes the result mean "this space is empty" |
| **Warp stations** | `warp_station.gd` | placed at entrance, exit and large rooms; an unreached station is never a destination; no prompt offers loadout editing |
| **Activity completion reaches the screen** | `zone_controller.gd` | asserted on the live object graph; removing the listener reports "6 of 6 activities complete into silence" |
| **The AUTHORED producer carries N doors too** | `content_instantiator.gd` `authored_door_plan` | a three-doorway authored shell composes, audits and seals |
| **A Zone resumes at the station it was left from** | `zone_controller.gd`, `main.gd` | removing the resume lands the player **153.9 m** away; a station that was online stays online |
| **Key reachable before its own lock, by walking** | `room_contract_driver.gd` | flooded walk-only from spawn; the room beyond the lock is *not* reached |
| **A spatial cycle is refused; a plug cycle is not** | `zone_builder.gd` `unclosable_cycles` | the same three-room loop is refused when the closing edge is `JOINED` and composes when it is `TRAVERSAL_ONLY`; disabling the guard reports `LAYOUT_OK` on a loop, and counting `TRAVERSAL_ONLY` edges refuses a legal return plug |
| **A broken station is repaired by its own room's puzzle** | `warp_station.gd`, `zone_controller.gd` `_repair_station_for` | a large room WITH an activity yields a broken station and one without does not; the entrance and exit are never broken; the other room's puzzle does not repair it |
| **A capability gate holds, and never blocks the way out** | `locked_door.gd` `requires_capability`, `zone_builder.gd` `gates_on_the_route` | a gate on a branch socket composes and one on a chain socket is refused by name; the slab opens for the capability and not for a key; a plain key lock on the chain is still legal |
| **The committed layout is measured, not re-solved** | `zone_builder.gd` `layout_findings` | §30.11.2e Body and Arrival over every committed room pair; two rooms stacked, a face-wide sliver and an arrival 50 m outside its room are each caught, and one doorway of shared wall is not |
| **Everything built is committed** | `zone_builder.gd`, `room_contract_driver.gd` `_box_key` | every box in `bounds_list` is accounted for by a committed room or chain piece; the check found two real omissions (§5i) |
| **The walk prober is no kinder than the body** | `room_contract_driver.gd` `_rise_over`, `_is_a_ramp` | the ascent bound is read off a real `Player`'s `floor_max_angle` and is strictly less than `MAX_VERTICAL_STEP`; with climbing disabled all three escape proofs fail, so the rule is live |
| **A branch is a placed room, crossed, returned from and remembered** | `zone_builder.gd` branches, `slice1_fixture.gd`, `zone_controller.gd` carried progress | the vault is refused reachable with the lock standing and reachable once it opens, its plug lands standable at `zone_start`, and the opened lock, the key and the station all survive a leave and a re-entry |

## 4. Implemented but not integrated

- **`LayoutResult` is returned and nothing consumes it.** `ZoneController`
  still reads `root` / `chambers` / `bounds_list`. The bridge is the
  intended consumer (commit, then check 19e) and that is Dess's column.
- **Progress intents are sent and nothing receives them.**
  `key_collected` and `lock_opened` go out on the existing intent channel
  with the shapes the contract specifies. `ZoneProgress` does not exist
  yet on the bridge, so they are currently dropped. The engine side is
  idempotent by identity, so a later receiver needs no engine change.
- **Resume is in memory, not in a save.** `main.gd` keeps each Zone's
  resume anchor and online stations for the life of the session, so
  leaving to the Hub and returning puts the player back at their station
  with it still lit. It does not survive quitting, and nothing pretends
  it does — `ZoneProgress` on the Zone record is where it belongs and is
  Dess's column. This is what that field replaces.
- **`Slice1Fixture` is scaffolding.** It decorates an already-composed
  Zone with one valid assignment so the engine half can be walked. It
  invents no topology and is expected to be deleted when the bridge sends
  real `RoomAssignment`s.

## 5. What remains

- The bridge column entirely: `TopologyEdge`, `realization`,
  `DoorAssignment` / `PlugAssignment`, `ZoneProgress`, `DORMANT`, the
  `R ⊆ E` verifier, the manifest and check 19e.
- **Shipping** authored multi-door shells. The engine path is proved
  against `shell_room_junction.tscn`, a three-doorway technical fixture
  this lane authored, so Art can add real three-door shells without the
  engine being the unknown. All twelve shipping shells remain two-door
  and remain valid.
- The exit unlock.
- **§30.11.2e constraint 1 (Join).** Needs the socket assignment to say
  which two sockets are supposed to meet, which is the bridge column.
  Constraints 2 and 4 are measured (§5h); 3 is refused (§5e).
- **A branch's own keys, locks and stations.** The branch is a room to
  everything downstream — its Checks, activities and enemies are wired by
  the same controller code as the chain's — but the per-room key, lock
  and station placement still runs only over `zone.chambers`. A branch
  that wants its own locked door does not get one yet.
- **Checks in the vault.** A Check id is an AP allocation, so the slice
  fixture's branch carries a puzzle instead. The owner's design puts
  Checks in a gated dead end and that arrives with `RoomAssignment`.
- **Closing** a spatial cycle. Refusal is implemented and proved (§5e);
  the router still builds chains, so a Zone that wants a genuine loop
  gets a typed `LAYOUT_INFEASIBLE` naming the pair, not a layout.

## 5k. The door opened onto the outside of a wall

`slice1:vault` was an edge id on a `LOCKED` side door with **nothing
behind it**. The aperture was carved, the lock stood in it, the seal
probe measured it as a real hole, the audit passed — and the door led out
of the room into empty space. Every part was proved and the thing they
were parts of was not.

A branch is a real room now: declared on its parent as
`branches: [{socket_id, chamber}]`, placed off that side socket by the
**same route search the chain uses**, before the chain continues, so
every later room routes around it. It joins `built_chambers`, so its
Checks, activities and enemies are wired by the same controller code as
any other room's. A branch declared behind a socket the door plan leaves
`SEALED` — or never assigns — is refused before anything is allocated;
`LOCKED` is fine and is the point.

**The connector into a branch is not decoration, and this is why.** The
first version let the search place the branch flush against its parent
and return a route of *zero* pieces. The envelopes abutted, each room's
floor stopped at its own wall, and the half-metre between them **had no
floor at all** — a player through the door fell into the gap. Found by
measuring, not by reading: the flood reported no standable column at
z=66.75 or z=66.50 with standable floor on both sides. The chain never
hit it because it lays a linking connector between every pair of rooms;
a branch is a join like any other and gets one too.

Both failure modes are now sabotage cases in the suite, and they are
caught by **different** measurements — which is the §5h point again:
- flush abutment → Body reports a 28.80 m³ interpenetration;
- the 0.4 m gap → Body reports nothing and the **walk** cannot cross.

**Progress now survives leaving and re-entering.** `main.gd` carried the
resume anchor and the online stations and carried neither the keys nor
the opened locks, so a player who opened the vault, walked out and walked
back in found it locked — possibly from the inside. `locked_door.gd`
already stated the rule this breaks: opened locks are "a growing set,
which is what makes a resume safe: a reload can never put the player back
behind a door they have already opened". Both are carried now, through
the same fields `main.gd` uses, and the re-entry walk confirms the vault
is reachable without touching the key again.

## 5j. The prober climbed a metre the player cannot

Every escape proof here is worth exactly what its movement model is
worth, and the model was wrong in the permissive direction. The flood
allowed a rise of `MAX_VERTICAL_STEP` — **a full metre** — between
adjacent cells. The real Player is a bare `CharacterBody3D` with a
capsule and **no step-up at all**; `chamber_builders.gd` already said so
in as many words, in the comment explaining why the trim lip had to be
gapped: *"there is no step-up anywhere in `player.gd`;
`MAX_VERTICAL_STEP` is a constant validation reasons with, not one the
body implements"*. The repair to that lip was made because a 0.35 m kerb
stops a walking player dead — and the prober proving the repair would
have walked up three of them.

What the body can actually ascend is a ramp no steeper than
`floor_max_angle`, so that is now the rule, **read off a real `Player`**
rather than declared, so it cannot drift from the body again. Over one
cell the bound is `cell × tan(floor_max_angle)`; at 0.5 m cells that is
half what the old constant allowed. And because at that cell size a
vertical half-metre and a 45° ramp are the same two numbers, any step
that rises is re-sampled at 0.1 m between the columns: a ramp passes,
a kerb does not.

**The escape proofs still hold under the stricter measure** — c015's
back gallery, c005's pit and the pit band all remain leavable on foot,
with no movement offers and no Teleport. That is the result, and it was
not assumed: with the ascent bound set to zero all three fail, so the
ramps are genuinely being walked rather than the rule being inert.

`_test_the_walk_prober_is_no_kinder_than_the_controller` is a standing
guard: it fails if the per-cell bound ever stops being strictly less than
`MAX_VERTICAL_STEP`, or if the bound stops scaling with the run — which
is what makes it a slope rather than a step.

## 5i. Two pieces the layout was built with and never wrote down

`LayoutResult` was committed as complete, and it was not. Two things the
builder placed were in no manifest:

1. **The linking connector between rooms.** Emitted at the end of each
   room's turn, after that room's chain had already been recorded.
2. **The whole exit-room route, and the exit room itself.** Its approach
   was searched by `_plan_route` exactly like every other and was the one
   route never written down.

Both passed every assertion the completeness test made, because each one
asked whether the *recorded* pieces were well-formed and none asked
whether everything *built* was recorded. An unrecorded piece raises no
complaint about the recorded ones. This is the recurring defect once
more, and this time inside the test written to prevent exactly it — the
fifth time on this branch.

The measurement that closes it is one line of principle: `bounds_list` is
every world box the builder actually placed, so a committed layout is
complete exactly when it accounts for all of them. The linking connector
is now carried into the **next** room's chain (build order, so a replay
lays it before the room it leads to), and the exit room commits a
transform and a chain like any other room.

## 5h. Two computations, not one done twice

§30.11.2e asks for its constraints to be measured on the committed
transforms — "the bridge does not check the engine's arithmetic by
redoing it". The builder already refused overlapping candidates *during*
placement, and that is not the same computation: `_overlaps` runs over a
`placed` array that deliberately omits pieces (`_all_but_last`) and
tolerates half a cubic metre. A blind spot there is invisible to itself.

`layout_findings(result)` measures what was actually committed, over
every pair, afterwards:

- **Body** — no two room envelopes intersect beyond a collar.
- **Arrival** (geometric half) — every committed arrival point lies
  inside the room that claims it. The *physical* half, that the standing
  capsule fits, is `RoomAudit`'s and needs a live scene.

For this to be answerable at all, `LayoutResult` now commits each room's
**envelope and arrival** alongside its transform. Without them Body and
Arrival can only be answered by re-running the builders, which is exactly
the second computation the design forbids.

**The collar tolerance is a shape, not a size**, and the test that
settled it is worth recording: a 0.05 m sliver spread across two rooms'
whole shared face is **3.6 m³** — *more* than a doorway's worth of wall
(2.4 × 3.2 × 0.4 = 3.07 m³) — and it is interpenetration, not a collar.
A volume bound would have had to choose between passing that and failing
a real door-sized collar. So the rule is the shape of one aperture: thin
through the wall, no wider or taller than a door. Both cases are in the
suite.

Verified by removal: with `layout_findings` returning `[]` always, two
rooms committed at the same place, the sliver, and an arrival 50 m
outside its own room all measure as satisfying the constraints.

## 5g. NOT YET, without a dead run

`SOLUTIONS_CATALOGUE §0-bis` makes a hard capability gate legal — "NOT
YET is good gameplay" — and puts five conditions on it. A `LOCKED` door
may now declare `requires`, naming a capability from the vocabulary
`ACTIVITY_CAPABILITIES` already defines, read from the same
`available_capabilities` snapshot field `ActivityRuntime` reads for its
NOT_YET state. A door may declare a key, a capability, or both, and
every requirement it declares must be satisfied.

Condition 4 — *the player can safely leave the blocked Zone* — is the
one with teeth here, and the owner's own example is why. "The missile
ability will be in zone 2, so it puts a missile door guarding a dead end
zone that contains a few checks": the capability is deliberately NOT in
this Zone. A key lock on the chain is safe because its key is in the
Zone by construction and the suite proves the key is reachable first. A
capability gate on the chain is a door nothing in this Zone can open,
standing between the player and the exit.

So `build()` refuses it, beside the cycle guard and before anything is
allocated: the chain walks `entry` and `exit`, so a gate may stand only
on a branch socket. The refusal names the room.

Verified by removal: with the guard disabled a gate on `entry` and on
`exit` both compose and allocate a root; with the capability check
removed from `try_open`, a player holding nothing — and a player holding
a red key — walk through a Missile door.

**Conditions 1, 2 and 3 are not this lane's** and nothing here pretends
otherwise. "The matching AP location logic declares the same
prerequisite" is the divergence the catalogue calls the real failure
mode, and it lives where the AP logic does.

## 5f. The first thing a solved puzzle does

The Zone 1 playtest finished four activities and perceived none of it.
The listener fix (§5 above) put the completion on screen; this puts it in
the world. The owner ruling is that a station may "start off or broken
and need you to complete a small puzzle (since we already have puzzles
they just do nothing lol)" — the parenthesis is the brief.

A station in a large room that carries an activity starts BROKEN: it
cannot be reached by standing in it, by pressing E at it, or by a caller
reaching for `mark_reached`, and it reads as dead from across the room.
Solving that room's puzzle repairs it, which also activates it — the
player has already earned it and should not then have to walk onto the
pad.

**No new schema field was spent on the choice.** Epsilon already decides
whether a room carries an activity, so Epsilon already decides this; the
builder states the rule. If that turns out to be too blunt — every
puzzled station room, no exceptions — a `station_repair` field on the
chamber is the place to put the finer choice, and it belongs with the
rest of the interpretation schema rather than here.

**The entrance and the exit are never broken**, because they are appended
outside the per-room loop. A Zone therefore always has a working save
point at the door and one at the goal, and a broken station is never a
gate on progression: warp only ever moves a player between stations they
have already reached on foot.

## 5e. Constraint 3 is a refusal, not a solver

§30.11.2e constraint 3 requires every cycle in the physically realized
subgraph to compose to the identity. This router places each room from
the previous one and never returns to a transform it has already fixed,
so it cannot satisfy that constraint — it can only avoid being asked.

Two ways to not-satisfy it were available. The silent one is to build the
chain and drop the closing edge: the graph would say two rooms are joined
both ways, the geometry would join them once, and nothing downstream
could tell. The loud one is to refuse before anything is allocated and
name the pair. `build()` takes the loud one, ahead of the first `new()`,
and `routing_policy` now carries `closes_cycles: false` so the refusal
points at the bound a reviewer would have to widen.

The scoping is the load-bearing half, and it is the owner's feature that
makes it so. A return plug makes the topology cyclic and creates no
spatial cycle — that is the entire point of `TRAVERSAL_ONLY`. So
`unclosable_cycles` unions over `JOINED` edges only. Both halves were
verified by removal: disabling the guard reports `LAYOUT_OK` on a
`JOINED` loop and allocates a root; removing the realization filter
refuses a legal dead-end plug.

What this is **not** is cycle closure. A Zone that genuinely wants a loop
does not get one. It gets a typed infeasibility naming `blocking_pairs`,
which is honest and is not the feature.

## 5d. A test of mine passed with the thing it guarded removed

The resume test asserted the player lands near the station they left
from, and it passed **whether or not the resume existed**. It took
`stations[size - 1]`, which is the *entrance* — it is appended last — and
the entrance is two metres from where a player spawns anyway.

Caught by removing the resume and watching the suite stay green, which is
the only reason it was caught at all. The test now picks the station
furthest from the spawn and additionally refuses to run unless that
station is more than 20 m away, so the assertion cannot go quiet again.
With the resume removed it now reports the player landing **153.9 m** off.

Worth stating plainly: this is the fourth time in this session the
recurring defect has appeared inside work written to fix the recurring
defect. The removal check is not a formality.

## 5c. The authored producer had no door plan at all

Multi-door composition was proved on the **procedural** producer alone:
`procedural_sockets` declares four openings and `cut_plan` carves the
assigned ones. The authored producer resolved sockets by id — that landed
in the first commit — and then **emitted no door plan**, so nothing
measured whether an authored shell's assignment meant anything, and the
inverted seal probe never ran on one.

The two are not symmetrical and that is why this is a separate path:

- A **`USED`** authored door needs nothing done to it. The opening is
  already in the mesh.
- A **`SEALED`** authored door cannot be an uncut wall for the same
  reason. It needs a **closure placed over the existing aperture**,
  which is a different construction with a different way of failing.

`authored_door_plan` resolves each assignment against the shell's
declared doorway sockets and refuses one that names a socket the shell
does not declare, or names a socket that is not a doorway.
`_place_closures` puts the slab in before the result is handed out, so
the room a caller receives is already the room the audit will measure.

**`shell_room_junction.tscn`** is the fixture that makes this measurable:
`shell_room_honest.tscn`'s geometry with the left wall split around a
2.4 m opening and the balcony moved to the right wall so it does not hang
across it. It is a technical fixture, not content, and it needed no
art-lane asset to exist.

Removing `_place_closures` produces both failures it should: the closure
is missing, **and** the inverted probe reports *"door 'side_west' is
SEALED and must be solid, but the player's own capsule passes straight
through it"*.

One thing the fixture taught, worth writing down: the shared
compatibility rule is an **equality**, and a chamber declares the space
**inside** its walls while a manifest declares the **envelope**. A 12 × 16
shell is offered to a chamber declaring 11.2 × 15.2, not 12 × 16.

## 5b. The playtest's open finding, closed

The Zone 1 playtest reported finishing activities and perceiving nothing.
The correction to that report established that `ActivityRuntime` already
clocks a `time_limit`, says `DONE`, sends `grant_local_reward` and emits
`completed` — and left the gap between that and the player open, because
the mechanism existing is not evidence it reaches anyone.

**The gap was that `completed` had no listener anywhere in the project.**
The only acknowledgement was a `Label3D` on the activity itself, which is
behind you the moment you touch the last element. A key toasts and a lock
toasts; finishing a puzzle did not.

`ZoneController` now connects it and raises a HUD toast with the
activity's id and its time. No new reward and no new rule — the grant
already went out from the runtime, keyed by identity so the same
completion twice is one grant. This adds only the part that was missing.

`godot-integration` asserts it on the **live object graph**: every
`ActivityRuntime` in a built Zone must have a listener on `completed`.
Removing the connection reports *"6 of 6 activities complete into
silence"*. A test that grepped the controller for a `connect` call would
have passed on a connection to a function that does nothing.

## 5a. A live defect found while closing the infeasibility gap

**Two same-direction corner shells in a row make a Zone the router
cannot place.** `shell_corner_left` twice swings the route 180°, the next
room is placed back along the arm it just left, and `_search` exhausts
every clearance push and both turns without finding a clear position.

`zone_builder.gd`'s header says *"turns alternate direction (no U-shapes
by construction)"*. That guarantee covers **route** turns — the ones
`_plan_route` chooses. It does **not** cover **shell** turns, which come
from a chamber's `exit_yaw` and are the composer's choice. Zone 1 never
hit it because its six corner shells happened to alternate.

This is now the fixture that exercises `LAYOUT_INFEASIBLE` under the
shipping policy, so the branch is proved rather than recorded as
unproved. **The defect itself is not fixed here**: whether the router
should absorb a U-turn or the composer should be forbidden from emitting
one is a composition decision that touches Dess's column, and it is
recorded for that conversation rather than settled unilaterally.

## 6. A pre-existing defect found on the way, and not fixed here

An 18 × 12 procedural arena offers a `cover` ground socket at
`(-5.76, 0, 6.24)` that lands inside the room's own crates. It reproduces
**identically when the same chamber is built with no door assignment at
all**, so it is not multi-door composition's doing.

`_test_the_playable_slice_composes_end_to_end` excludes that one finding
**by name** and fails on any other, so the exclusion cannot hide a
regression this lane causes. It belongs to the arena's ground-socket
placement and wants its own repair.

One related fix *was* made, because it was clearly in the same statement:
the ground-socket loop now excludes `claimed` — the Check's pedestal box
and every key's reserved space — and not only the band's declared
regions. The pedestal is built after that loop runs, so `solid_boxes`
cannot see it, and a socket could be offered inside it.

## 6b. Owner rulings recorded

- **2026-09-11 — a fully cleared Zone stays revisitable.** Completing the
  final Check does not permanently close a Zone. This settles the
  question this document had open against `06_THE_AMALGAM` §30.12.1, and
  it is what `SOLUTIONS_CATALOGUE` §0-bis condition 5 ("the Zone remains
  re-enterable") needs in order to be satisfiable at all — a capability
  gate is only legal because the player can come back with the
  capability. Nothing in the engine closed a Zone on completion, so
  nothing had to change; it is recorded here so nothing starts to.

## 7. Interface status

`docs/reviews/2026-09-12-room-contract-prod-review.md` (on the checkpoint
branch, `8bb6a05`) returned changes requested against `cb3bf64`. **This
slice implements only the parts that are invariant across how the
`TRAVERSAL_ONLY` contradiction is resolved** — socket resolution, N-door
carving, the inverted seal probe, the lock, the key, walk-reachability,
and a plug carrying a source and a destination anchor. Whether a plug is
carried by its own record or by a `DoorAssignment` changes a field name
on the bridge side and nothing in the engine geometry.

**One decision is still the owner's:** whether a `COMPLETE` Zone is
re-enterable (`06_THE_AMALGAM.md` §30.12.1 currently says no, and that is
not an owner ruling in evidence).
