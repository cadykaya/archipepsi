# Three doorways moved back onto their own rooms

**Arty**

*2026-09-12. Repairing Production's `docs/art-requests/2026-09-11-doorways-outside-their-envelope.md`
at `dc4ef39`. Three shells authorized; nine preserved; the Span stairs not
touched. Every number below is measured from the exported `.glb`, not from
the builder that wrote it.*

---

## The repair, confirmed from geometry

Production proposed moving each `exit` to the shell's declared depth and
asked me to confirm that from the art. I did, and it is right: in all three
the wall's **outer face** is exactly at the declared depth, and the exported
parts say so.

| shell | the wall at the exit | aperture | `exit` was | `exit` is |
| --- | --- | --- | ---: | ---: |
| `shell_hall_transit` | `hl_back_*`, z **59.40 – 60.00** | x −3.0…3.0, y 28.0…36.0 | 62.0 | **60.0** |
| `shell_plenum_helix` | `pl_north_*`, z **19.40 – 20.00** | x −1.2…1.2, y 0.0…3.2 | 22.0 | **20.0** |
| `shell_span_basin` | `sp_north_*`, z **89.40 – 90.00** | x −1.2…1.2, y 14.0…17.2 | 92.0 | **90.0** |

`size` was not the thing that was wrong. Each shell's geometry ends exactly
where its depth says, so the alternative Production offered — grow the depth
instead — would have moved the room to meet a mistake.

**Three fields move together, in all twelve shells.** `exit_offset`, the
`bounds` depth and the `exit` socket named one point each; they agreed with
each other here too, on the wrong number. All three were corrected in the
authoring source, and `godot/content/registry/authored_art.json` was
regenerated from it.

The hall and the span needed **no geometry at all** — their exits are raised,
so a sill already fills the wall thickness below the opening and its top is
the threshold. Their `.glb` files are byte-identical to what shipped.

## The plenum needed geometry as well as a number

The plenum's exit is at floor level, so it has no sill — and its floor,
correctly for a floor, runs only between the walls' **inner** faces. The last
0.6 m to the doorway face had nothing under it. Moving the socket to 20.0
alone would have put the doorway on the far side of a hole.

`pl_north_threshold` carries the floor across: same width as the opening,
same underside as the floor, top at 0.0, declaring no Surface — exactly as
the hall's and the span's sill tops declare none. **+12 triangles, +1
collider.**

**What it is worth, measured rather than assumed.** I expected this to be the
difference between crossing and falling. It is not. Walking straight through
at 7 m/s, a capsule of Production's dimensions bridges the 0.6 m gap on its
own; the threshold takes the dip from **0.118 m to 0.000 m**. So the hole was
a real defect and the slab is a real fix, but the thing that broke the join
was the coordinate, and I am not going to claim otherwise.

## A player actually walked each join

`tools/content/crossing_test.gd` loads the shipped `.glb` with its exported
collision, attaches a corridor stub **at the socket** the way `ZoneBuilder`
does, and walks a capsule of Production's own dimensions out of the room
under Production's own gravity — once at the origin, once with the shell
translated to (−18.5, 0, 46.25) and yawed 37°, the corridor placed by
transforming the socket rather than re-deriving it.

| join | at the origin | placed and yawed 37° |
| --- | --- | --- |
| `shell_hall_transit` | crossed, 0.000 m dip | crossed, 0.000 m dip |
| `shell_plenum_helix` | crossed, 0.000 m dip | crossed, 0.000 m dip |
| `shell_span_basin` | crossed, 0.000 m dip | crossed, 0.000 m dip |

Against the art **as it shipped**, the same harness fails all six: the player
leaves the doorway and falls, 0.07 m past the hall's and span's sockets and
0.00 m past the plenum's.

**What this does not prove.** It is not `player.gd`. It uses Production's
capsule, gravity, walk speed and floor angle and the engine's own
`move_and_slide` — the facts that decide whether a floor carries a body
across a threshold. It carries no weapons, HUD, movement packages, volumes or
step assistance, so it is evidence about the **geometry** of the join and
nothing about how the crossing feels. Production's playtest still closes this
out.

## Two bugs in my own harness, and how they showed

The first crossing run reported the hall and the span falling and the plenum
crossing. All three numbers were **identical** — 3.53 m past the socket,
2.622 m of drop — and three different rooms cannot fail at the same distance.
That was the tell.

1. **The corridor stub was in the physics space at the world origin.** A
   Node3D moved *after* it is in the tree defers its transform to the physics
   server until the end of the frame, and all six crossings ran inside one
   frame. The stub drew in the right place and collided nowhere. It is now
   positioned before `add_child`.

2. **All six rooms were standing in the same world at once**, because
   `queue_free()` is deferred too. The plenum's "pass" was the player walking
   on the **hall's basin floor**, 3 m below and 20 m away. A crossing rescued
   by another room's floor is worse than a failing one: it reports success.
   Now each stage is `free()`d immediately, and the harness refuses to walk
   unless exactly one stage is in the world.

Neither bug was in the art. Both would have produced a confident report.

## Five more doorways, on shells I was told to preserve

> **Corrected 2026-09-12.** This section said Production's
> `doorways_outside_envelope()` compares `exit` z against `size` depth and
> so could not see `shell_yard_gantry`. **Both halves were wrong.** It
> tests all three axes, and it grows the envelope by
> `ChamberBuilders.WALL_THICKNESS + SPAN_TOLERANCE` = **0.405 m** — so the
> yard's 0.40 m is *inside* its tolerance and is not the defect they
> reported. Being outside a zero-tolerance envelope is not itself a
> defect, and it is not a reason to move an authored socket. What the yard
> actually had was a **demonstrated gap**: its floor stopped 1.60 m short
> of the socket and a player walking in fell at 1.22 m. That is repaired —
> see `2026-09-12-doorway-repair-2.md`.


Measuring all twelve rather than the three turned up five findings I have
**not** repaired, because the brief authorized three shells. They are named
in `KNOWN` in `tools/content/measure_doorways.py`, enforced in both
directions — a finding that disappears fails as loudly as a new one, so the
day any is repaired the check says so instead of going quiet.

| doorway | finding |
| --- | --- |
| **`shell_yard_gantry/entry`** | ~~0.40 m outside its envelope on X~~ — **struck, see the correction above.** The real finding was no floor at the socket: **repaired 2026-09-12.** |
| **`shell_yard_gantry/exit`** | the same, mirrored. **Repaired.** |
| **`shell_plenum_helix/entry`** | **opens onto air.** Past the 0.6 m sill the nearest floor at y 68 is `pl_run_0_tread6`, **4.57 m away in −x**, and the drop is 68 m. Its `surface_id` says `landing_0`, which is 7.9 m away. |
| `shell_corner_left/exit` | `cl_floor` stops at x 3.00; the socket is on the wall's outer face at 3.40. A 0.4 m threshold gap. |
| `shell_corner_right/exit` | the same, mirrored. |

~~The yard is the one to authorize next: it is Production's own defect class,
and their `doorways_outside_envelope()` will not report it.~~ **Struck** —
see the correction above; the yard's coordinate is fine and its floor was
not. The plenum's entry is the most severe — but repairing it means **new geometry** (a landing
in front of the door, meeting the helix), which is a design decision and not
a targeted repair.

## What is measured now

`tools/content/measure_doorways.py` reads every shell's doorways out of the
exported `.glb` and asks three questions: is the socket **on the room**; is
the declared opening **clear** where a wall stands at that plane; and is
there **floor at the socket's own height**, one metre back into the room.

The first version also required the socket to sit on a wall face, and failed
all three towers — whose exits are the open end of a bridge rather than a
hole in anything. That was the checker being wrong about the shells, which is
the likeliest failure mode of a new check, so it is written down in the file
rather than quietly relaxed.

Six sabotage tests, each confirmed failing before the check was trusted:

| sabotage | result |
| --- | --- |
| the art as it shipped, through the crossing harness | 6 of 6 crossings fail |
| the repaired socket with the plenum's threshold removed | crosses, dip 0.118 m (recorded, not hidden) |
| the hall's exit pushed back to 62.0 | outside the envelope, and unsupported |
| a `KNOWN` entry that no longer measures | named as stale, exit 1 |
| a doorway blocked across its declared opening | blocked, named by part |
| no shell measured at all | refuses to report a pass |

## Changed files

| file | what |
| --- | --- |
| `tools/blender/build_hall.py` | `exit_offset`, `bounds`, `exit` socket: `D + 2.0` → `D` |
| `tools/blender/build_span.py` | the same three. Stairs untouched. |
| `tools/blender/build_plenum.py` | the same three, plus `pl_north_threshold` |
| `assets/models/batch039/shells/manifest.json` | hall: three 62.0 → 60.0 |
| `assets/models/batch040/shells/manifest.json` | plenum 22.0 → 20.0, span 92.0 → 90.0, +12 tris, +1 collider |
| `assets/models/batch040/shells/shell_plenum_helix.glb` | the threshold slab |
| `godot/content/registry/authored_art.json` | regenerated |
| `godot/content/SCENE_PLAN.json`, `godot/content/shells/shell_plenum_helix.glb` | regenerated |
| `tools/content/measure_doorways.py` | new — every doorway, every shell |
| `tools/content/crossing_test.gd`, `run_crossing_test.sh` | new — the walked join |
| `tools/check_art_current.sh` | both now run with every other standing check |

**Preserved:** the other nine shells, all movement offers, every collider
except the plenum's one new threshold, the Span stairs, and the hall's and
span's geometry byte-for-byte.

## Still open

`shell_span_basin`'s route/collider hold is **not** lifted by this — that
finding is still Production's to supply. The five doorways above await
authorization.
