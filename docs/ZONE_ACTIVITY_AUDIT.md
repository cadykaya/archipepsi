# Zone 1 activity audit

Run against Production head `9a1d78f`, on the Zone a baseline playtest
walks: `zone_digest 1bdf42f800c5637e`, 23 rooms, 15 Checks, 916 points.

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
