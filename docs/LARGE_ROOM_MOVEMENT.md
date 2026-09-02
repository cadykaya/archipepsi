# P3.0 — the large-room movement foundation

What Production can hold up before Art authors the first LARGE vertical
shell. Nothing here is a room; everything here is a contract with a
consumer and a test.

## What the rail WAS, before this

Stated plainly, because the difference is the point of the batch.

`AffordanceFeatures.rail_ride_path` returned **two points** on a straight
line along one axis, 6.0 m long, at a fixed height. `build_rail_along`
did accept a multi-segment polyline and swept one beam and one ride
volume per segment from the same points — that part was real, and it is
what this builds on — but nothing ever handed it more than two points, so
the polyline claim was never exercised.

The "ride" was **not** path following. It was an `Area3D` whose influence
dictionary (`friction_scale 0.05`, `speed_scale 1.25`, `gravity_scale
0.85`) merged into the player's ordinary physics step. The player was
never attached to anything. There was no entry condition, no direction,
no jump-off, no endpoint, and an ascending rail would not have carried
anybody up.

**It was a slippery corridor lane, not a spline grinder.** It could not
curve, could not climb, and only a corridor could host one.

## The rail path contract

`RailPath` (`godot/scripts/gameplay/rail_path.gd`) owns a `Curve3D` and
is the single authority: the visual beam, the ride volumes, the runtime
traversal and the validation all read it. There is no second copy of the
shape.

| rule | value | why |
|---|---|---|
| `BAKE_INTERVAL` | 0.2 m | explicit, so sampling is identical on every machine and run |
| `MIN_SEGMENT` | 0.5 m | shorter than this and a segment has no direction |
| `MAX_SEGMENT` | 60 m | one span is not a Zone |
| `MAX_PITCH_DEGREES` | 75° | short of vertical: at 90 the tangent's horizontal component vanishes and "which way am I going" loses its answer |

No upside-down loops in this slice: the rider's up vector is world up,
and a path that goes over the top needs a frame that rolls with it.

`violations()` refuses a degenerate path **where it is built**, not where
it is ridden.

## Riding

`RailRider` is a pure state machine — no node, no input singleton, no
scene — so the whole of it is driven frame-exact in a headless test.

* **Entry** (`catch`) needs three things: within `CATCH_RADIUS` 1.6 m
  laterally, within `CATCH_BELOW` 2.2 m vertically, and *moving along the
  path*. Walking sideways into a rail does nothing. Catching an end while
  already heading off it does nothing. Direction is chosen from the sign
  of the player's velocity along the tangent, so entering backwards rides
  backwards.
* **THE RAIL DRIVES.** Speed converges on a target of `DRIVE_SPEED` 9.0
  shifted by slope (`SLOPE_BIAS` 5.0), held inside `[MIN_SPEED 4.0,
  MAX_SPEED 22.0]`, at `SETTLE` 1.6/s. The speed you *arrive* with rides
  on top and bleeds away, so a sprint entry is rewarded and a walking
  entry still finishes.

  This is a **progression requirement, not a taste**. The map provides
  rails, so a route through one may be mandatory, and a mandatory route
  must be completable by a player who owns nothing. The first draft of
  this file was purely ballistic and a walking player stalled a third of
  the way up a six-metre climb.
* **Exit** is the endpoint (leave along the tangent, carrying speed) or
  jump (tangent speed plus a normal `JUMP_VELOCITY`). Never a dead stop.
* While riding, `Player` returns early from its physics step and does not
  call `move_and_slide`: the rail is the collision. It is not a cutscene
   — speed varies with slope, entry momentum is yours, and jump is always
  available.

## The launch pad

`launch_pad` is **beside** `bounce_pad`, not instead of it.

| | bounce pad | launch pad |
|---|---|---|
| direction | primarily vertical | directed traversal edge |
| destination | not part of the contract | **half of the contract** |
| purpose | local vertical opportunity | crossing real horizontal + vertical distance |

`LaunchSolver` derives the trajectory from source, destination and
gravity. **No hand-authored velocity vector exists anywhere**: move
either end and the arc follows, because a literal vector would be a
second authoring of the destination that stops agreeing the moment
anything moves.

A **readable arc, not minimum time**: the apex is chosen at
`APEX_CLEARANCE` 3.5 m over the higher end and the velocity follows from
it. That also makes the solution unique, which is what makes it
deterministic — no solver, no iteration, no seed, just two square roots.

Validation refuses: an unsolvable pair, a range over `MAX_RANGE` 80 m, an
obstructed arc (walked at `ARC_SAMPLES` 24, the same samples the pad
draws), a landing with no room for the player, a landing with nothing
under it, and a landing region smaller than `MIN_LANDING_RADIUS` 2.5 m —
because a pad the player can miss by leaning on the stick reads as
broken.

Base kit: the solve consults gravity and two points, and nothing else.

## The offer seam

A large shell declares `offers`; a package consumes what it understands.

```
rail_route     an ordered 3D path a rail may be built along
launch_source  a place a directed launch may fire FROM (names its target)
launch_target  a landing region a launch may be aimed AT
```

Closed and short for the reason `SOCKET_KINDS` is: **a kind with no
consumer is a kind nobody can be held to.** `grapple_anchor`,
`platform_route` and `wind_column` are the named next arrivals and are
deliberately absent — they arrive through this same key with the packages
that read them, needing no new grammar. That is what makes this a seam
rather than a taxonomy.

**AN OFFER IS NOT AN ORDER**, and three things follow, each tested:

1. a package may **decline** — and a package that consumes nothing leaves
   a working room, because the same shell has to play as ordinary combat
   space with no traversal mechanic in it at all;
2. a package must **validate** what it builds — a route that is not a
   shape a rider can hold is refused at build time, not discovered under
   a player;
3. a refusal is **reported**, never silent.

`MovementPackage` is the minimum harness that proves this, and nothing
more: no scoring, no progression, no content.

## Progression safety

`NO REQUIREMENT BEFORE GUARANTEE` is preserved and now has a movement-layer
proof. Neither the rail nor the launch pad reads an Echo, a capability or
a loadout. The suite drives both with nothing owned and nothing equipped:
a rail caught at plain `WALK_SPEED` completes a 6 m climb, and the
steepest rail the contract accepts never falls below `MIN_SPEED`. A route
the base kit could not finish could not be mandatory; these can be.

No raw DPS is used as progression logic anywhere in this batch.

---

# THE ART-FACING CONTRACT FOR THE FIRST LARGE SHELL

Everything below is already validated by Production. Nothing else is
needed from Art to author the room.

## Manifest

The existing `ContentEntry` fields are unchanged. One optional field is
added:

```jsonc
"offers": [
  { "name": "spine",  "kind": "rail_route",
    "points": [[x,y,z], [x,y,z], ...] },        // >= 2, shell-local
  { "name": "pad_a",  "kind": "launch_source",
    "position": [x,y,z], "radius": 1.5, "target": "gallery" },
  { "name": "gallery","kind": "launch_target",
    "position": [x,y,z], "radius": 4.0 }
]
```

* a `rail_route` needs **at least two** points and no `position`/`radius`;
* a region offer needs a `position` and a `radius > 0` and no `points`;
* a `launch_source` **must** name a `launch_target` that exists;
* `max_length` 32 offers per shell.

## What a rail route must satisfy

Refused otherwise, with the reason:

* every segment between 0.5 m and 60 m;
* no segment pitching past **75°**;
* no upside-down sections in this slice;
* total length > 0.

Curves, climbs, descents, helices and multi-level wraps are all legal and
all proven. A rail may gain 12 m; a helix may wrap a column twice.

## What a launch pair must satisfy

* source-to-target distance between 0.5 m and **80 m**;
* the landing region radius **at least 2.5 m**;
* the solved arc must be clear of geometry along its whole flight —
  Production measures this, so leave the arc corridor open;
* the landing must have floor under it and room for a 0.8 × 1.8 m player.

The apex sits 3.5 m over the higher end. Art does **not** author a
velocity, a direction, or an arc: declare the two ends and Production
solves it.

## What the shell still owes, unchanged from P2

`surfaces`, `sockets`, `traversal`, `volumes`, doorways, envelope, and
convex collision per `ART_ASSET_SPEC` §3. A LARGE room is a bigger room,
not a different contract: every `stand` Surface must still offer
somewhere a player fits, and every mandatory traversal segment must still
arrive somewhere a player fits.

## What Art should NOT do

* do not bake a rail, a pad or any traversal mechanic into the geometry —
  offer the region, let a package build it;
* do not author a launch velocity or arc;
* do not assume a package will consume any offer — the room must read as
  a room with none of them built.
