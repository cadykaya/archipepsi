# The plenum's entrance, the yard's threshold, and three checkers that were wrong

**Arty**

*2026-09-12, following `2026-09-12-doorway-repair.md`. Codex's three
follow-ups on `f016a2d`, then the repairs the assembled crossing actually
demonstrates. Every number is measured from the exported `.glb` or from a
player-shaped body walking the join.*

---

## First, a correction I owe Production

I said `doorways_outside_envelope()` compares `exit` z against `size` depth
and so could not see `shell_yard_gantry`. **Both halves were wrong.** Read at
`origin/claude/archipepsi-amalgam-slice1`:

```gdscript
var slack := envelope.grow(ChamberBuilders.WALL_THICKNESS + SPAN_TOLERANCE)
...
for axis in 3:
```

All three axes, with **0.405 m** of slack. The yard's 0.40 m is *inside* it.
Their check is not missing anything, my envelope rule was stricter than
theirs, and a stricter art-side rule reports defects Production does not
have. `measure_doorways.py` mirrors their number now rather than inventing
one, and the correction is struck through in the first report, in the reply
filed beside their request, and on the frontier.

**Being outside a zero-tolerance envelope is not a defect and is not a reason
to move an authored socket.** What is a defect is a gap or an obstruction the
assembled crossing demonstrates — which is what the rest of this is.

## Three checkers that could not fail

**1 · The aperture probe stepped outward.** It read the wall's mid-thickness
as `along - inward * thickness / 2`, which is a step *past* the face into
open air, where nothing is solid. **A doorway completely filled by a wall
passed.** `inward()` returns the direction the room is in, so reaching the
wall's middle is a step *along* it; the sign is `+`.

No shipped shell could have caught this, because none of the twelve has a
blocked doorway — a check whose only evidence is "it passes on art we already
believe" has not been tested, it has been agreed with. So
`tools/content/test_measure_doorways.py` builds rooms on purpose: for each of
the four wall orientations, an **open control** and a **blocked twin**
differing by one box, plus an unfloored variant, plus both sides of the
envelope slack. **14 cases.** With the old sign it fails eight times.

**2 · `KNOWN` exempted a doorway's whole identity.** Keyed by doorway alone,
a doorway excused for a support gap would have gone on passing if somebody
later moved its socket into the air or walled up its opening. It is keyed by
`"<shell>/<doorway>:<kind>"` now — `envelope`, `obstruction`, `support` — so
one known defect buys an exception for itself and nothing else. Still
enforced in both directions: a finding that stops measuring **fails**, which
is how the yard's repair announced itself below.

**3 · `theme_for()` read "which theme" when the question was "did anyone
choose one".** `--theme concrete_facility` names the default, so a check of
the *name* read it as no choice at all: `build_plenum` stayed rusted
industrial through a run that explicitly asked for concrete — **and wrote the
shipped tree while doing it**, because isolation keyed on the same wrong
question. Both halves key on whether the flag was *present* now.
`verify_theme_argument.py` checks the explicit-default case in all three
respects, and reproducing the bug fails all three.

## The plenum's entrance: the door moved, because a walkway cannot be built

Its entry stood over the open shaft — past a 0.6 m sill, nothing, and a 68 m
drop. The room already said where the player arrives: the socket's
`surface_id` is `landing_0` and the `player_entry` volume is at `_corner(0)`,
**which is landing_0**. Only the hole in the wall disagreed, because the
wall-building loop centred both doors at x 0 — right at floor level, where
the floor is continuous, and wrong at y 68.

**A walkway was the other option and the geometry refuses it.** `run_0`
leaves landing_0 along the same wall and descends east, rising to meet
anything laid at the entry's height. A 0.5 m slab from the door to the top
tread would leave:

| tread | top | headroom under the walkway |
| --- | ---: | ---: |
| `pl_run_0_tread5` | 67.19 | **0.31 m** |
| `pl_run_0_tread4` | 66.38 | **1.12 m** |
| `pl_run_0_tread3` | 65.57 | 1.93 m |

A player is 1.8 m tall. The walkway would seal the top of the helix.

So the door moved to `_corner(0)` — read, not typed, so moving the helix
moves the door. It spans x −9.10…−6.70 over a landing at −9.40…−6.40, a
0.30 m margin each side, its sill top flush with the landing at y 68.00.
**No new geometry, and two declarations that were false are now true.**

## The yard's threshold: 1.60 m of nothing, and 1.20 m of it repaired

Its floor is inset by `WALL` at every edge — right for a floor, wrong for a
threshold. From the floor's edge at 41.40 to the socket at 43.00 there was
**1.60 m** with nothing under it: 0.60 m of inset, 0.60 m of wall with no
sill, and 0.40 m of socket standing proud. A player walking in from the
corridor **fell at 1.22 m**, in both placements.

`yd_threshold_±1` carries the floor across the first **1.20 m**, to the
wall's outer face, and no further. Building out to the socket would have
grown the shell from **85.20 m to 86.00 m** — a dimension Production's
composer derives chamber dimensions from, and a doorway repair is not a
reason to resize a room. The last 0.40 m is the same step both corner shells
carry today, and the crossing carries it at **0.029 m and 0.053 m** of dip.

**+24 triangles. `size` unchanged. Sockets unchanged.**

## The corners needed nothing, and my harness was the reason they looked broken

The crossing harness built its corridor stub along the shell's own +Z
whatever the socket said. Right for the six yaw-0/180 doorways it first
carried; wrong for every doorway facing along X. The corner pair and the yard
had their corridor built out of the *side* of the room, so two joins "fell"
into a gap that was not there and the yard's entry "crossed" a stub it never
touched. It reads the yaw now.

With the stub where the doorway actually faces, **both corners cross** — at
the origin and placed and yawed. Their 0.40 m geometric step is real and
stays reported in `KNOWN`; it is not a demonstrated gap, and on the
2026-09-12 ruling it is not repaired.

A second harness bug, same family: judging a crossing by a fixed distance
past the socket graded a doorway on what the room keeps near it. All three
treasure rooms "failed" by walking in 1.2–2.1 m and stopping against **their
own plinths**. A crossing succeeds when the player gets a body's width past
the socket and never falls, and the walk runs its full length so a fall
*after* the threshold still counts — which is how the yard's 1.22 m drop
survived the change.

## Evidence

**Every doorway of every shell, both directions, both placements:**

```
[crossing] 48 crossings, 0 known-uncrossable, 0 new problems
```

An `exit` is walked from inside the room out onto the stub; an `entry` from
the stub into the room, because that is the direction a player meets it. The
joins are read from the manifests at run time, so adding a shell adds its
crossings.

```
measure-doorways: 12 shell(s), every doorway inside Production's envelope
                  slack, through a clear opening, and supported 1.0 m back
                  -- except 4 reported and unauthorized (see KNOWN)
test-doorways:    14 cases -- open, blocked and unfloored in all four
                  orientations, plus both sides of the envelope slack
verify-theme:     the default writes the shipped pack, a second theme writes
                  only assets/themed/, and an unknown theme refuses
check-art:        PASS -- every generated asset matches its source
```

The four that remain in `KNOWN` are all the same 0.40 m step, all crossed,
all reported: both corners (the wall's thickness, no sill) and both yard
doorways (the socket standing proud of the wall).

## Sabotage, before any of it was trusted

| sabotage | result |
| --- | --- |
| the aperture probe stepped outward again | 4 blocked doorways pass → 8 failures |
| a `KNOWN` entry that no longer measures | named as stale, exit 1 |
| `theme_for` keyed on the theme's name | all three explicit-default properties fail |
| the theme redirect removed | caught under both spellings of the argument |
| the unknown-theme refusal removed | caught by name |
| the yard rebuilt without its threshold | the player falls at 1.22 m, both placements |

## Changed files

| file | what |
| --- | --- |
| `tools/content/measure_doorways.py` | probe direction; Production's 0.405 m slack on all three axes; `KNOWN` keyed by defect kind; a testable core |
| `tools/content/test_measure_doorways.py` | new — 14 synthetic cases |
| `tools/content/crossing_test.gd` | stub reads the socket's yaw; entries walked inward; every shell; crossing judged by getting through |
| `tools/blender/common.py` | `THEME_EXPLICIT` — omitted vs chosen |
| `tools/content/verify_theme_argument.py` | the explicit-default case |
| `tools/blender/build_plenum.py` | the entry over `_corner(0)` |
| `tools/blender/build_yard.py` | `yd_threshold_±1`, and `DOOR_OUT` shared with the sockets |
| `assets/models/batch040/shells/*`, `godot/content/*` | rebuilt and regenerated |
| `tools/check_art_current.sh` | the unit test runs with everything else |

**Preserved:** the hall, the span, the towers, the treasure rooms and both
corners are byte-identical. All movement offers, the Span stairs, and the
yard's `size` and sockets unchanged.

## Still open

`shell_span_basin`'s route/collider hold is **not** lifted by this. The
corners' and the yard's 0.40 m steps are reported and unrepaired by ruling.
