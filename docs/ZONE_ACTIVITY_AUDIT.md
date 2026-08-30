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

## 2. Findings — placement, NOT reported as failures

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

## 3. Readability risks — diagnosis only

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
