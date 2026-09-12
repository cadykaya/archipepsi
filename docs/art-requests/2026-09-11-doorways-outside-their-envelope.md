# Art repair: three shells declare a doorway outside their own room

**From:** Production (engine lane)
**Severity:** the join is physically broken in the shipped game
**Shells:** `shell_hall_transit`, `shell_plenum_helix`, `shell_span_basin`
**File:** `godot/content/registry/authored_art.json`

## What is wrong

Each of the three declares its `exit` doorway **2.0 m past its own
declared depth**:

| Shell | `size` depth | `exit` z | past the room |
|---|---:|---:|---:|
| `shell_hall_transit` | 60.0 | 62.0 | **+2.0** |
| `shell_plenum_helix` | 20.0 | 22.0 | **+2.0** |
| `shell_span_basin`   | 90.0 | 92.0 | **+2.0** |

The other nine approved shells put `exit` **inside** their envelope
(−0.4 m to −26.0 m), so this is three mistakes rather than a convention.
`shell_yard_gantry` exits from the middle of its depth and is fine — the
rule is not "near the far wall", it is "on the room".

## Why it matters

`ZoneBuilder` joins the next corridor **at the socket**. The room's wall
is at its declared depth. So a `shell_span_basin` room in a real Zone has
its wall at z = 90 and its corridor starting at z = 92, with **2 m of
nothing between them** — no floor, no wall, a hole.

This is the first sentence of the 2026-09-11 playtest:

> "oof the connecter isnt connected at all haha"

It is also what the bridge's layout validator now refuses a generated
Zone for, by name: *"edge 'e:c002:c003' socket_a does not lie on room
'c002'; the route and the room disagree about where the doorway is."*

## The repair

Move each `exit` doorway back onto the room — for these three, `z` equal
to the shell's `size` depth:

```
shell_hall_transit  exit  [0.0, 28.0, 62.0]  ->  [0.0, 28.0, 60.0]
shell_plenum_helix  exit  [0.0,  0.0, 22.0]  ->  [0.0,  0.0, 20.0]
shell_span_basin    exit  [0.0, 14.0, 92.0]  ->  [0.0, 14.0, 90.0]
```

If the scene geometry really does extend 2 m further than `size` says,
then `size` is what is wrong and the depth should grow instead — but the
two have to agree, and the chamber dimensions the composer derives from
`size` would then change with it.

## What Production did and did not do

**Did not change any authored coordinate.** A manifest position is
authored geometry and authored geometry is Art's.

**Did** add the measurement that was missing:
`ContentInstantiator.doorways_outside_envelope()`. Every other shell
compatibility rule is about a SPAN; this one is about a POINT, which is
why twelve shells passed validation with three of them holding a doorway
in mid-air.

`_test_no_new_shell_puts_a_doorway_outside_its_room` names these three
and fails on a fourth — and it also fails on a **stale** name, so the day
one of these is repaired the suite says so instead of going quiet.

## Update, 2026-09-12 — these three are now WITHHELD from composition

Codex measured the shipped GLBs independently and they end at the
declared depth — 60, 20 and 90 — so the **socket** is the outlier, not
the mesh. That settles the "or `size` is wrong" branch above: the repair
is the one in the table.

Until it lands, `shells.is_offerable` refuses to offer a shell whose
doorway sits more than one `WALL_THICKNESS` from its own body, so these
three are no longer put in front of a composer at all. **Repairing the
manifest is all it takes to get them back** — the gate measures, it does
not list names.

**Two things this cost, so the repair has a price attached.**

1. The fallback provider's variety fell to four distinct shapes in six
   Zones, because its landmark arena was a fixed `26.0 x 24.0 x 7.0` and
   the shell a big room happened to wear was doing all the varying. Fixed
   independently — the landmark rolls now — but it is what these three
   were covering.
2. **No generated Zone can carry an authored movement offer at all.**
   The four shells that carry offers are these three plus
   `shell_yard_gantry`, and the yard is 4429 m2 against an
   `AUTHORED_AREA_BUDGET` of 4000 — so none of the four is both joinable
   and affordable, and `godot-playtest3a`'s two offer tests have nothing
   to walk. Raising the budget to 5000 to admit the yard was tried and
   PUT BACK: it made every generated Zone an 85 x 52 m room with two
   unwalkable joins, an arrival a body cannot stand at and a rail it
   cannot ride. Repairing these three restores it immediately instead —
   Hall is 2472 m2 and Plenum 424, both comfortably inside the budget.

**`shell_yard_gantry` is the control, and it is fine.** Its doorways sit
at `x = +/-43.0` in an 85.2 m envelope — 0.4 m proud, which is exactly
the outer face of its own wall and exactly where a connector meets it.
The rule is not "inside the envelope"; it is "on the body, within a wall
thickness". Nine of the twelve shells satisfy it comfortably.

## And two findings about `shell_yard_gantry`, from the run that tried it

Admitting the yard for one run put it under the crossing measurement for
the first time, and it came back with two joins that neither the flood
nor a real `Player` can walk, in a 23-room Zone:

* `c005->c006` — the walk into the yard reaches a goal cell that is
  **not standable**.
* `c006->c007` — "the player cannot stand where the room is entered".
  The yard declares `player_entry` at `(-40.2, 1.0, 26.0)`, one metre
  above its own `floor` surface, which is a convention no procedural
  room uses (`ChamberBuilders.PROCEDURAL_ARRIVAL` is a floor point).

Neither is urgent — the budget change was reverted, so no generated Zone
carries the yard today and `KNOWN_UNWALKED_JOINS` is back to 3 — but they
are what the yard would cost if it were ever the answer, and they are
worth a look while the three repairs above are open.
