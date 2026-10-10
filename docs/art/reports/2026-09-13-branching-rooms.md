# The Span's stairs, and the first three rooms with a choice in them

**Arty**

*2026-09-13. Prod's handoffs read at `612a7d2`. Four items: the span-basin
route, the first branching vocabulary, its capacity, and the theme export.
Every number is measured from the exported `.glb` or from a player-shaped
body walking it.*

---

## 1 · The span's stairs were not short. The landing was on top of them.

Production measured both basin flights as three risers short and asked for
three more at 0.877 m. Read tread by tread from the export, **the flight has
all sixteen treads and `sp_ramp_0_tread15`'s top is at 14.00 — the deck's own
height.**

What was wrong is that `sp_landing_0` lay across it. The landing ran
x −3.50…14.40 and the flight sits at x 9.40…14.40, so a slab at y 13.50…14.00
covered the last three treads:

| tread | top | headroom under the landing |
| --- | ---: | --- |
| `tread13` | 12.25 | 1.25 m — a 1.8 m player does not fit |
| `tread14` | 13.12 | **0.38 m** |
| `tread15` | 14.00 | **inside the landing** |

That is the playtest word for word — *"the ugly stairs that don't work, they
are just square pegs and the catwalk on top is above the stairs"*. It is also
why rays measured it short: dropped from above at x 11.9 they hit the landing
at 14.00 and then the last tread they could **see** at 11.38, an apparent
2.62 m step. The three between were buried, not missing.

The landing now stops at the flight's west edge, tops flush at 14.00.
Contrary to the request this **is** a manifest change — `landing_0` and
`landing_1` are declared Surfaces and their extent was the defect.

### The acceptance question, answered by walking it

`tools/content/run_route_walk.sh` walks a capsule of Production's dimensions
under Production's gravity, jumping when it stops making progress:

| | |
| --- | --- |
| **after** | **completed, ended on the deck at 14.00, 16 jumps** |
| before | stuck at 12.77 m after 60 jumps, trapped under the landing |

Sixteen jumps because it **must** jump. `run_controller_limits.sh` drives the
same body at a step:

| | measured |
| --- | ---: |
| walking up | **0.12 m** |
| jumping up | 1.50 m |
| walking up a ramp | to **46°**, which is `floor_max_angle` |

`move_and_slide` has no step-up, exactly as the request's own *"separately,
and not yours"* note says. So the riser height was left alone: **no staircase
in this pipeline is walkable until the engine has a step-up**, and a ramp
would reintroduce L-95, the recorded lesson that the AABB gates cannot see a
slope. The one-way `deck_to_basin` drop, the declared endpoints and the
mandatory deck routes are untouched.

**This is capsule evidence and is labelled as such.** No weapons, HUD,
movement packages or assistance. The full-player proof is Production's.

## 2 · Three rooms with a choice in them

`assets/models/batch044/shells/`. **Proposal art**: `review: "pending"`, not
exported to `godot/content/`, and Art does not write `pass`.

| id | connections | size (w × h × d) | tris | plan |
| --- | --- | --- | ---: | --- |
| `shell_junction_triad` | 3 | 26.00 × 8.66 × 26.00 | 672 | a T of arms round an open middle |
| `shell_junction_cross` | 4 | 30.00 × 9.66 × 30.00 | 852 | a plant block you walk around |
| `shell_bay_terminus` | 1 used + 2 closable | 18.00 × 7.66 × 22.00 | 516 | narrow in, opens out, stops |

### Every route is flat, and that is the measurement talking

0.12 m is the **whole budget** for a walking route. A 0.6 m shelf is a jump,
not a step. So none of these rooms puts a height change on a route: they are
single level, and their areas are told apart by enclosure, ceiling, fittings
and light instead of elevation. Raised geometry still exists — the triad's
overlook, the cross's plant — but it is scenery and perch, never floor a
route crosses, exactly as `shell_span_basin`'s shoulders are.

**Nine internal routes, 0 jumps each.**

### The first version was a hall, and the render said so

The triad's first build was a 26 m square with a door in three walls. From
the entry **you could not tell the east branch existed** — you are looking
along its wall. Framing it did not help. What fixed it was the plan: the four
corners became solid mass, so the approach is narrow, the middle opens out,
and both side arms appear at the moment you arrive — which is the moment the
choice is made.

That is the difference between a junction and a T inflated into a box, and it
took an interior view at eye height to see it. The before and after are both
in `docs/art/review/junctions_2026-09-13/`.

### The groove shows the routes

Every floor is laid as panels around a 0.40 m channel recessed **0.06 m** —
inside the 0.12 m budget, so stepping out is free. It runs from each doorway
to the middle, so the choices are legible from the floor. The panels are
declared as the `stand` Surfaces, because the panels are where a body stands
and the channel is narrower than a player.

Each threshold reaches **0.80 m past the wall's inner face**, which is not
decoration: without it the door opened onto the channel's own centre line and
a player stepped down and back up in the doorway. `measure_doorways.py`
caught that.

## 3 · Capacity, not extra holes

`docs/art/review/junctions_2026-09-13/CAPACITY.json` — every socket id,
position, aperture, arrival surface, stand surface and volume.

**Socket identities are stable, and `entry` / `exit` keep their names and
meaning**, so all three still work as ordinary through-rooms under today's
two-socket router (`ContentInstantiator.ALIASES` maps them to `end_a` /
`end_b`). The branches are additional. A composer that does not know about
them simply does not assign them — and an unassigned socket is `SEALED`,
which the engine already closes with a slab. **These rooms are not a flag
day.**

### Closures seat on a collar

`_place_closures` builds the aperture plus 0.6 m, 0.5 m deep, at the socket.
So every doorway carries an accent frame clearing the opening by 0.30 m on
each side and above — the same piece that makes a way out readable from
across the room. **All 34 authored doorways were walked closed as well as
open: 102 crossings, every closed one stopped the player.**

### `enemy_spawn` is declared, in all three

Production's note was explicit: a shell with none gets its enemies scattered
over the largest declared surface, which for the hall put every one of them
in the pit and one of them in a doorway. The triad spawns on the open middle;
the cross uses **two** volumes, one per side of the plant, because a single
box spanning the ambulatory would also cover the machine standing in it; the
terminus spawns in its chamber, away from the door.

### What the shell does not pretend to know

Ordinary door, seal, local lock, return device, Zone exit — the shell cannot
know which a socket becomes. It gives them all the same clean seat and does
**not** distinguish them in the mesh; the distinguishing look belongs to the
placement. Locks, closures and return devices stay placements, never topology.

The destination's space is an `objective` volume, deliberately **not** a
Check: an encounter, activity, reward or local-key objective all fit, and
baking one campaign's Check into the mesh would make the room useful once.

## 4 · The theme pack is at the destination

`godot/content/theme/` — 37 textures and `THEME_PACK.json`, byte for byte,
with `.import` sidecars produced by **running Godot's own importer** rather
than hand-writing a uid, a dest hash and a source md5. Only the one parameter
the contract names is set: mipmaps, which default to off.

**Filter and repeat are not set, and the file says why**: in Godot 4 they are
sampler state on the material, not importer parameters. Asserting a key that
cannot exist is a check that always fails or one that lies. The binder sets
them, which is Production's half.

`verify_theme_export.py` checks every digest against the **exported** pixels,
so clause 4 — *"the pack Arty built and the pack the game loaded are the same
claim"* — is true before Production's loader ever runs.

## Measured limitations

- **Nothing here is walkable up.** 0.12 m. Until the engine has a step-up,
  every stair in the pack is a jump per riser, and these three rooms avoid
  the question rather than answering it.
- **The capsule is not `player.gd`.** No weapons, HUD, movement packages,
  volumes or step assistance. My evidence is about geometry.
- **Stills are stills.** They show framing and legibility. They do not show
  combat visibility and they do not show flicker-free motion.
- **The four-connection room is not provable end to end yet**, because the
  router is a two-socket world today. What is proved is that each branch
  crosses, closes, and is reachable inside the room.
- Four 0.40 m steps stay reported and unrepaired in `measure_doorways.KNOWN`
  — both corners and both yard doorways, all crossed.

## Checks

```
measure-doorways  15 shell(s), every doorway inside Production's envelope
                  slack, through a clear opening, and supported 1.0 m back
crossing          102 crossings -- 34 doorways, open, placed and yawed 37
                  degrees, and closed; 0 problems
route-walk        11 routes; the two span flights at 16 jumps, nine interior
                  routes at 0
verify-theme-set  6 theme(s), 37 texture(s), the description matching
verify-theme-exp  37 texture(s) and the descriptor, every digest matching
check-art         PASS -- every generated asset matches its source
```

## Not done, and named

No engine topology change, no change to the twelve existing shells beyond the
span's landing, no runtime binder, no watchers, and **no owner approval
claimed** — Batch 044 joins the pending band.
