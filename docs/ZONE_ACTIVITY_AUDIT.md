# Zone 1 activity audit

Run against Production head `9a1d78f`, on the Zone a baseline playtest
walks: `zone_digest 1bdf42f800c5637e`, 23 rooms, 15 Checks, 916 points.
**Section 1-ter re-runs it after ROOM GRAMMAR v0, on
`zone_digest 6e8d83d0f3ec088b` — 23 rooms, 15 Checks, 922 points — and
that is the current state.**

**Why this exists.** `godot-activity` drives activities it builds itself.
That is what let a whole batch ship while the game built zero activities
in zero rooms: the suite proved the runtime works and nothing about
whether anything reaches it. Everything below starts from
`ZoneBuilder.build` on the real Zone JSON and measures the assembled
scene with physics.

Reproduce: `make zone-fixture && make godot-zone-audit`, and
`make zone-shots` for the frames.

---

## 1. What is proven

| Claim | Result |
|---|---|
| The Zone declares activities | **30**, across 19 of 23 rooms |
| The assembled scene holds their runtimes | **30 of 30** |
| Elements built vs. asked for | **all match** |
| Elements inside their own chamber's bounds | **30 of 30 activities, 0 strays** |
| Every kind completable in the assembled Zone | **4 of 4** |

Kinds present in Zone 1: `pressure_routing` ×9, `timed_run` ×7,
`target_challenge` ×7, `switch_sequence` ×7. No extra Zones were needed.

Driven to `COMPLETE` in the assembled scene, through the real physics and
the real damage path, on activities the ZONE placed rather than on
fixtures:

```
timed_run         c001_0   IDLE -> ACTIVE -> (partial) -> COMPLETE
target_challenge  c002_0   IDLE -> ACTIVE -> (partial) -> COMPLETE
pressure_routing  c003_0   IDLE -> ACTIVE -> (partial) -> COMPLETE
switch_sequence   c005_0   IDLE -> ACTIVE -> (partial) -> COMPLETE
```

Each was checked at every step: IDLE before it is touched, ACTIVE after
the first element, not COMPLETE at N−1, COMPLETE at N.

**23 of 30 activities are clean on every measure.**

---

## 1-bis. Second run, after the playtest-readiness batch

Same Zone, same digest `1bdf42f800c5637e`. **30 activities audited, 0
structural failures, 0 placement notes.** Everything in section 2 below
is fixed; it is kept as the record of what was wrong and how it was
found.

| | before | after |
|---|---:|---:|
| Activities stacked on another activity | 14 elements | **0** |
| Elements overlapping props | 4 | **0** |
| Elements with no line from the walking lane | 2 | **0** |
| Kinds completable in the assembled Zone | 4 of 4 | 4 of 4 |

The fix was one idea: the row solver knew the room's DIMENSIONS and
nothing about its CONTENTS. It is now handed every box already spoken
for — the room's own props, then each activity as it is placed — and
walks a deterministic search for the nearest free spot inside the same
lane and wall clearances. No prop was moved or deleted and no element
left its chamber.

One thing that made it take two attempts, recorded because it will
happen again: `mesh.global_transform` **does not accumulate for a node
outside the scene tree**, and a chamber is built detached and added
later. The first occupancy pass therefore collected every prop at its own
local offset near the origin, intersected nothing, and the solver
silently did nothing while looking entirely correct.

---

## 1-ter. Third run, after ROOM GRAMMAR v0

New Zone: `zone_digest 6e8d83d0f3ec088b`, 23 rooms, 15 Checks, 922
points. The digest moved because `ElevationBand` is a new schema field
and the fallback consumes RNG to decide it, which shifts every room's
dimensions downstream. **29 activities audited, 0 structural failures,
10 placement notes.**

The comparison that matters is not before-vs-after on two different
Zones. It is the SAME Zone through two engines:

| Engine | Zone | Result |
|---|---|---|
| pre-batch (`a032b03`) | old (`1bdf42f8…`) | 30 audited, 0 failures, 8 notes |
| pre-batch (`a032b03`) | **new** (`6e8d83d0…`) | 29 audited, 0 failures, **10 notes** |
| this batch | **new** (`6e8d83d0…`) | 29 audited, 0 failures, **10 notes** |

The last two rows are identical, note for note. Every placement change
between the 8 and the 10 comes from the Zone's own room dimensions
moving, not from anything this batch did to the engine — and all ten
notes are in `platform_path` rooms (section 4, still open). **No arena
carries a placement note, banded or not.**

New in this run: `_audit_bands` measures every declared band in the
assembled Zone — a ray onto the deck's own `reserved` socket, compared
against the rise the Zone declared. It is a STRUCTURAL check, not a
note: a band is a claim about geometry and the way that claim fails is
silently. 5 bands measured, 5 correct.

Three defects it found, all the same shape — **the builder knew a
physical fact and nothing else did**:

- The access ramp is `3 × rise` long, so at 6.8 m it is wider than
  `ROOM_SCALE_SOLID` and occupancy classified it as architecture. It
  became the only obstacle in the room nobody could see, and two
  elements of one arena were inside it. Fixed by DECLARING it as a
  `reserved` socket.
- Ground sockets for crates and barrels were offered at six fixed
  points with nothing checked. Three of six landed inside the room's own
  props or inside a gallery's solid mass. The builder now vouches for
  them against its own geometry.
- **A pit was a sealed basement.** The recess was dug and the arena's
  floor slab was still laid across the whole room, so the pit had a lid.
  Every unit test passed: the bounds dropped, the sockets sat below
  zero, and a ray from inside the recess found its deck. Nothing asked
  what a ray from ABOVE hits first. `arena` now builds its floor as up
  to four slabs around the hole, from the same `band_rect` the band
  itself is built from.

The last one is the batch's own instance of the recurring shape: the
test that missed it is called `_test_a_pit_is_a_hole_not_a_painted_floor`
and its docstring cites `_carve_gap` never removing the base slab. **A
guard inherits the blind spot of the fix it was built to protect.**

---

## 2. Findings — placement, FIXED in the readiness batch

These are recorded, printed as `NOTE`, and deliberately do not fail
`godot-zone-audit`. They were found the evening before a playtest the
owner needs to run on the current design, and none of them stops an
activity working. **Nothing here has been changed.**

### 2a. Two activities in one room land on top of each other

| Room | Activities | Elements affected |
|---|---|---|
| `c002` | `target_challenge` ×2, both 2 elements | 2 + 2, **identical positions** |
| `c006` | `target_challenge` ×2, both 5 elements | 5 + 5, **identical positions** |

`c002_0` and `c002_1` are at exactly `[-5.5, 2.2, 20.55]` and
`[-17.1, 2.2, 29.1]`. The row solver is handed the room's width and depth
and nothing about what is already in the room, so two activities of the
same kind and the same element count get the same layout.

**Consequence for the playtest:** those rooms show half the targets they
contain. Shooting one registers on one activity; its twin is inside it.

### 2b. Elements overlap theme props

| Activity | Room | Elements |
|---|---|---|
| `c011_0` | `c011` arena | 1 of 5 |
| `c014_2` | `c014` arena | 1 of 4 |
| `c020_0` | `c020` arena | 2 of 3 |

Blocking bodies are the room's own props. Same root cause as 2a: props
and activities are placed independently and nothing reconciles a room's
occupants. Affordance features have their own solver and are unaffected.

Two of these (`c011_0`, `c014_2`) are also the only elements in the Zone
with no clear line from anywhere on the walking lane — they are inside
the prop, not merely beside it.

### 2c. Not a finding, recorded so it is not re-derived

- **`shell_id` arrives as `null` and is read as the string `<null>`.**
  `str(chamber.get("shell_id", ""))` on a null yields `"<null>"`, which
  is not empty, so the "Epsilon chose a shell" branch runs with garbage
  and falls back with a warning. Noisy, harmless, one line to fix, NOT
  fixed here.

---

## 3. Readability risks — diagnosed here, provisionally treated

The treatment is graybox, not final art. Structure first, state second,
colour never the only cue.

| Family | Was | Now |
|---|---|---|
| `switch_sequence` | a pale box | head on a post, on a dark mount; **countable lugs** when the activity is ordered, and none when it is not |
| `target_challenge` | a pale box | a ring around a recessed face on a wall stalk — aim-at-the-middle, with no breakage cue |
| `pressure_routing` | a pale rectangle on a pale floor | pad in a heavy kerb, **joined pad-to-pad by a conduit** so the simultaneity rule is visible |
| `timed_run` | pixel-identical to `switch_sequence` | START is an **open gate** you run through; GOAL is a **closed beacon** with a wide lit head; waypoints are neither |

The clock and progress count now ride the element the run STARTS from
rather than floating above the activity's centroid, which for a 14 m run
was a point in mid-air belonging to nothing.

**Semantic separation.** `neon_transit`'s light is `#7cf2ff`, **0.17**
from `CHECK_SIGNAL` against the project's own `MIN_LAYER_SEPARATION` of
0.45 — so in the Zone the owner plays, every switch and target was
wearing Archipelago's colour. `VisualOwnership.separated_from_reserved`
pushes a theme's colour clear of Checks and Epsilon and leaves it alone
otherwise: five of six themes are unchanged, `neon_transit` moves to
0.47. It is not a universal activity colour — the theme still reads as
itself, and structure carries identity first.

**Props vs activities.** No prop was changed. Activities gained dark
matte mounting hardware, which is what props do not have: a player
scanning a room can now find the operable things by looking for the
hardware rather than by shooting cyan boxes.

### Playtest labelling (F4)

Every activity names itself at rest, before it is touched: the family,
and what you do to it — `SWITCH SEQUENCE / walk into all 4`,
`PRESSURE ROUTING / hold all 4 pads at once`. A `timed_run` also tags its
`START` and `GOAL`. Once an attempt is running the same label carries the
progress count and the clock; back at rest it returns to the identity
line rather than going blank.

**F4 turns them off**, and that is the point of them having a switch. The
graybox silhouettes are supposed to carry family identity on their own,
so a label nobody can hide would make "can you tell these apart"
permanently unanswerable. It starts ON because a playtester who cannot
tell a pressure pad from a floor tile is testing the placeholder rather
than the mechanics.

A crutch, and named as one. It comes out when interaction art lands.

---

## 4. OPEN: activities in a `platform_path` have nothing to stand on

Found by the owner in play, on `d5beedd`, reported as "some of these
pressure pads are not on the ground, and they have no collision, and 2 of
them are under the shelf". All three observations are one bug.

**A `platform_path` has no floor.** It is discrete platforms rising over
a void — `y = step * (i + 1)`, with `gap_size` of nothing between them.
The activity solver places elements on a flat plane at the room's nominal
floor height and knows nothing about where the platforms are, so an
element lands either in a gap (floating; the sensors are deliberately
non-solid, which is right on a floor and useless in mid-air) or beneath a
raised platform, which is the shelf.

| Room | Activities | Elements with no ground |
|---|---|---:|
| c003 | pressure_routing x2 | 4 of 6 |
| c008 | timed_run x2 | 4 of 6 |
| c012 | timed_run x2 | 8 of 10 |
| c017 | switch_sequence | 4 of 5 |
| c021 | switch_sequence | 3 of 4 |

**23 elements, every `platform_path` in Zone 1, every kind that lands in
one.** Arenas and corridors are unaffected — they have a real floor.

### Why the audit was green over it

A pad floating in a void is inside its chamber, overlaps nothing, and is
perfectly visible from the walking line. Every check this file had
passed it. **Nothing asked whether there was anything to stand on**, and
that is the check that now exists (`_has_ground`) and produced the table
above. Fifth time in this project that a guard has inherited the blind
spot of the thing it protects.

### Also open, from the same session

- **`c015_1` is mathematically unsolvable.** Five pads whose best
  possible route is 4.8 s at full walk speed in a straight line with zero
  reaction time, against a 4.0 s hold window. Nothing checks that a
  routing puzzle's circuit fits inside `PLATE_HOLD_SECONDS`. `c003_0` at
  3.6 s of a 4.0 s budget is technically possible and brutal.
- **The `pressure_routing` label describes something impossible.** "Hold
  all N pads at once" is not what the mechanic asks for — pads stay live
  for a hold window and the player runs a circuit.
- **Labels clip and overlap.** Two activities in one small room both
  render at `pixel_size 0.012`; the owner's screenshots show
  `RESSURE ROUTING`, `d all 2 pads at once`, `RESET — a plate re`. Sized
  from a wide screenshot, never checked from eye height in a corridor.

None of the four is fixed. They are recorded here so the next batch
starts from evidence.

---

## 3-bis. The original diagnosis, for the record

From the frames `make zone-shots` produced. **Nothing has been
redesigned.**

**The inversion is the headline: props are the loudest objects in the
room and activity elements are the quietest.** Theme props are saturated
cyan cubes. Switches and targets are pale near-white slabs, and floor
plates are pale rectangles on a pale tiled floor that already carries
cyan inset squares. The things you are meant to touch read as scenery,
and the scenery reads as important.

Against the owner's list:

| Risk | Present? |
|---|---|
| Activity looks like ordinary scenery | **Yes** — the main finding above |
| Elements blend with props | **Inverted** — props out-read the elements |
| Unclear start/goal distinction | **Yes** — a `timed_run`'s start and goal are the same white slab as its waypoints |
| Unclear sequence ordering | **Yes** — nothing marks first from last; `ordered` is never set in Zone 1 anyway, so the risk is latent |
| Unclear target affordance | **Yes** — a target does not read as shootable; it is a pale square at 2.2 m |
| Unclear pressure plate affordance | **Yes, worst case** — plates sit at 0.08 m and are near-indistinguishable from floor tiling |
| Status/timer feedback not visible enough | **Likely** — the `Label3D` sits 2.6 m above the activity's origin and is off by default until an attempt starts, so the clock only appears once you are already committed |
| Elements hidden behind geometry | **Two**, both in 2b |
| Reads optional when trying to communicate interaction | **Yes**, follows from the above |
| Labels contradict state | **Not observed** — labels tracked state correctly in every driven case |

One thing outside activities, seen in the same frames: **Zone wall
signage is clipping its own text** (`PLA…`, overlapping strings on the
same panel). Not touched; recorded because it is visible in every arena.

---

## 4. Screenshots

Eight frames, `make zone-shots`, written to
`user://zone_shots/`. One clean example of each kind plus every flagged
activity. Gitignored by living outside the tree: they are for looking at,
not for diffing.

The first deterministic screenshots of a real generated Production Zone.
The Art lane's `CAMERA_BENCH.md` names this gap precisely and its two
traps both bit on the way:

1. `--headless` selects the dummy renderer and an awaited capture hangs
   with no output. Xvfb plus `--rendering-driver opengl3`.
2. Framing solved from the subject's AABB alone puts the camera outside
   the room, and the first eight frames were photographs of chamber
   exteriors. The camera is now clamped inside the room's own bounds.

ROOM GRAMMAR v0 added a room pass: one frame per chamber that DECLARES
an elevation band, named `NN_room_<id>_<kind>_<side>.png`. The subjects
are chosen by asking the Zone which chambers have a band — never by
naming one that looked good, which is how a generator gets judged on its
best output — and each is aimed at the deck's own `reserved` socket, so
the photograph and the builder cannot disagree about where the band is.
The camera goes to the high corner FURTHEST from the band; solving a
distance for a subject the size of the room puts it outside the room
again, and the clamp then lands it inside the furniture. On the
committed Zone that is 5 frames of 23 chambers.

The pit screenshot is why the band audit exists. It showed an unbroken
floor where the Zone declared a pit, which is what sent the probe
looking, and the probe found the lid.

---

## 5. What the tooling asserts, and what it does not

`godot-zone-audit` **fails** on: a declared activity with no runtime, a
runtime with the wrong element count, an element outside its chamber, a
kind that cannot be completed in the assembled Zone. Sabotage-proven —
returning the population step to one routing branch fails it with 31
messages.

It **notes** placement findings, because they are written down here and a
target that goes red on a known open defect is a target people learn to
ignore.

`zone-shots` asserts nothing at all. It is for looking.
