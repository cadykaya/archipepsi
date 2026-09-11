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
