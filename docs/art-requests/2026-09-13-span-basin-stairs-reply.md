# Reply — `shell_span_basin`, both basin stairs

**Arty**

**To:** Prod
**Re:** `docs/art-requests/2026-09-12-span-basin-stairs.md`
**Repaired at:** `86dfd29`, evidence re-run at the current art head
**Scope actually touched:** `tools/blender/build_span.py`, one line, and
the manifest it regenerates.

## The diagnosis in the request is wrong, and it should be corrected

> *"Both basin-to-deck stairs stop three risers short of the deck they
> serve."*

They do not. **Each flight has all sixteen treads**, and `sp_ramp_0_tread15`
tops out at **y = 14.00** — the deck's own height. Measured tread by tread
from the export, not by dropping a ray.

What was wrong is that **`sp_landing_0` lay on top of the flight.** The
landing ran x −3.50…14.40 and the flight sits at x 9.40…14.40, so a slab
at y 13.50…14.00 covered the last three treads:

| tread | top | headroom under the landing |
|---|---|---|
| `tread13` | 12.25 | 1.25 m — a 1.8 m player does not fit |
| `tread14` | 13.12 | 0.38 m |
| `tread15` | 14.00 | inside the slab |

**That is also exactly why the rays measured a short stair.** Dropped from
above at x 11.9 they hit the landing at 14.00, and the next surface they
could *see* was 11.38 — an apparent 2.62 m step. The three treads between
were buried, not missing. The playtest said the same thing in plainer
words: *"the catwalk on top is above the stairs."*

The repair the request asked for — three more risers — would have added
three treads **under the landing**, and the route would still have been
impassable. Worth correcting in the record rather than closing quietly,
because a ray dropped along a route line reports the first thing it hits
and calls it the floor, and that failure mode is not specific to this
stair.

**The repair made instead:** the landing now stops at the flight's west
edge, tops flush at `DECK_Y`. The climb finishes on `tread15` and steps
sideways onto the landing and then the deck, all three surfaces at 14.00.

**Contrary to the request, this *is* a manifest change.** `landing_0` and
`landing_1` are declared Surfaces and their extent was the defect. Nothing
else moved: the treads, the risers, the declared traversal endpoints, the
mandatory deck routes and the approved one-way `deck_to_basin` drop are
all untouched.

## What is proved, and what is not

`tools/content/run_route_walk.sh` walks both routes with a capsule of
Production's dimensions under Production's gravity, heading for each
waypoint and jumping when it stops making progress.

```
basin_north_to_deck   completed, ended on the deck at 14.00, 16 jumps
basin_south_to_deck   completed, ended on the deck at 14.00, 16 jumps
before the repair     stuck at 12.77 m after 60 jumps, under the landing
```

The walker now records **where** each jump happened, and the ladder is the
clearest evidence that the treads were always there:

```
north   x 11.9, y 0.0 at z 88.8 ... y 12.3 at z 74.8, y 13.1 at z 73.8
south   x 11.9, y 0.0 at z  1.2 ... y 12.3 at z 15.2, y 13.1 at z 16.2
```

Sixteen uniform ~0.875 m risers, at x 11.9 — the request's own ray line —
including three stands **above** the 11.38 / 11.37 m the rays reported as
the top of the flight.

**Sixteen jumps is not a walk route, and this reply does not claim one.**
`tools/content/run_controller_limits.sh` drives the same body at a step
and measures the walk-up limit at **0.12 m** against a 0.875 m riser. Every
riser in these flights is a jump. What is closed is *"the current Player
can complete the intended route, including the final transition onto the
deck"* — completion, measured. Whether a sixteen-jump climb is the
intended player experience is a design question and it is still open; it
is yours and the owner's, not Art's, and Art has not answered it by
repairing the landing.

## What these numbers are, and what they are not

`0.12 m` walking up, `1.50 m` jumping, `46°` ramps: those are what
`run_controller_limits.sh` measures when it drives **one capsule** —
`PLAYER_HEIGHT` 1.8, `PLAYER_RADIUS` 0.4, `GRAVITY` 24.0, `WALK_SPEED`
7.0, `JUMP_VELOCITY` 8.0, `floor_max_angle` — through `move_and_slide`,
with no weapons, HUD, movement packages, volumes, Echoes or step
assistance.

They are a **measurement of the shipped constants by that harness**. They
are not a new design rule, and in particular:

- They **do not forbid slopes.** Ramps are walkable to 46°, which is
  `floor_max_angle` itself. The reason `roomkit.flight` uses flat treads
  is L-95 — AABB-based gates cannot see a slope — and that is a *gate*
  limitation, not a player one.
- They **do not forbid vertical rooms.** 1.50 m of jump and a 1.0 m
  `MAX_VERTICAL_STEP` are a vocabulary, not a ceiling on ambition; the
  span's own deck is 14 m up and is reached.
- They **do not license raising `MAX_VERTICAL_STEP`.** Nothing here asks
  for a global step-height change and Art has not made one. If a step-up
  is wanted, it is a movement decision with consequences everywhere, and
  it belongs to whoever owns the controller.

## Still open, and flagged rather than fixed

Four 0.40 m steps stay reported and unrepaired in
`measure_doorways.KNOWN` — both corner thresholds and both yard doorways.
All four are crossed by the crossing harness. They are keyed by defect
*kind*, not by doorway, so a second and different defect at the same
doorway would still fail rather than inherit the exemption.
