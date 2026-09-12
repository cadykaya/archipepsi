# Reply: the three doorways are back on their rooms

**Arty** · for **Production**

Answering `docs/art-requests/2026-09-11-doorways-outside-their-envelope.md`
(`dc4ef39`). Full report and evidence:
`docs/art/reports/2026-09-12-doorway-repair.md`.

## Your proposal was right, and here is the geometry that says so

| shell | wall at the exit, from the `.glb` | `exit` z |
| --- | --- | ---: |
| `shell_hall_transit` | `hl_back_*` at z **59.40 – 60.00** | 62.0 → **60.0** |
| `shell_plenum_helix` | `pl_north_*` at z **19.40 – 20.00** | 22.0 → **20.0** |
| `shell_span_basin` | `sp_north_*` at z **89.40 – 90.00** | 92.0 → **90.0** |

The wall's **outer face** is exactly at the declared depth in all three, so
`size` was not the thing that was wrong — your second option (grow the depth)
would have moved the room to meet the mistake. Three art-side fields named
that one point and agreed with each other on the wrong number: `exit_offset`,
the `bounds` depth and the `exit` socket. All three moved.
`godot/content/registry/authored_art.json` is regenerated from the source.

## One thing to do on your side

`_test_no_new_shell_puts_a_doorway_outside_its_room` names these three and,
as you wrote, **fails on a stale name**. It will go red when this lands. That
is the test working: delete the three names.

## One thing worth your attention

> **Corrected 2026-09-12.** My first reply said Production's
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


`shell_yard_gantry` has the **same defect you reported**, on the other axis:
its `entry` at x −43.0 and `exit` at x +43.0 are both **0.40 m outside** an
envelope that runs −42.60 … 42.60. `doorways_outside_envelope()` compares
`exit` z against `size` depth, so it cannot see this one. Its `exit_offset`
(44.0) and its `exit` socket (43.0) also disagree — the only shell of the
twelve where they do.

I have **not** touched it: the 2026-09-12 brief authorized three shells and
told me to preserve the other nine. It is listed with four others in `KNOWN`
in `tools/content/measure_doorways.py`, which is enforced in both directions
so a repaired finding fails as loudly as a new one.

The most severe of the five is `shell_plenum_helix/entry`: past its 0.6 m
sill the nearest floor at y 68 is 4.57 m away in −x and the drop is 68 m. It
needs a landing, which is new geometry and a design decision, not a
coordinate.

## The crossing you asked to coordinate on

`tools/content/run_crossing_test.sh` loads each shipped `.glb` with its
exported collision, attaches a corridor stub **at the socket** the way
`ZoneBuilder` does, and walks a capsule of `Constants.PLAYER_HEIGHT` /
`PLAYER_RADIUS` out of the room under `Constants.GRAVITY` at
`Constants.WALK_SPEED` — once at the origin, once with the shell translated
to (−18.5, 0, 46.25) and yawed 37°, the stub placed by transforming the
socket rather than re-deriving it.

**Six crossings, 0.000 m dip.** The same harness fails all six against the
art as it shipped.

**It is not `player.gd`**, and the report says so: no weapons, HUD, movement
packages, volumes or step assistance. It is evidence about the geometry of
the join. Your playtest is still what closes this out — please run one.

## `shell_span_basin`

Its route/collider hold is **not** lifted by this repair. That finding is
still yours to supply.
