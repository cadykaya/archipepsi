# Owner-away batch — engine lane

**Branch:** `claude/archipepsi-echoes-continuation-b1adno`
**Started from:** `b914d98`
**Tested revision:** `b3d583d` — everything in §8 ran on that commit,
serially, with nothing edited during the run. This document's
verification table is a later documentation-only commit on top of it.

One batch, worked from `ARCHIPEPSI_PROD_AWAY_WORK_QUEUE.md` plus the
four-item first block. Read the three lists first — **done**, **blocked**,
**prototype** — and then the replay checklist, which is the only part
that needs you at a keyboard.

---

## 1. Done, with what was measured

### Stair descent — repaired, and its boundary proven

The open item from last batch. `floor_snap_length` was
`MAX_VERTICAL_STEP`, `velocity.y` was zero, `up_direction` was +Y —
every precondition Godot's own floor snap documents — and a body
walking off a 0.4 m tread still free-fell it.

Characterised before being touched, with a per-frame trajectory and a
probe on the frame contact was lost:

```
lost floor y=0.741 vy=+0.0000 down_hit=true trav=0.109
  after apply_floor_snap: floor=false y=0.741 (moved 0.000)
```

Ground was 0.341 m below and the cast stopped at 0.109 m. The body has
not yet cleared the tread it is leaving, so a straight-down cast from
where it ended hits **that tread's top edge** — and 0.109 m is exactly
the capsule-against-corner solution for this geometry, so the number
named its own cause. An edge normal is 55° off vertical, past
`floor_max_angle`, so the snap classified the staircase as a wall and
refused. No snap length could have helped: the obstruction is 0.1 m
away, not 1 m.

The repair measures the drop from a probe placed a radius **past** the
edge and walks the body down it with `velocity.y` held at zero. The
limit is `MAX_VERTICAL_STEP`, the same number the ascent uses.

| control | before | after |
|---|---|---|
| two 0.4 m treads, 40 frames | 10 airborne | **1 airborne** |
| 2.5 m ledge | — | 24 airborne, 9.2 m/s — still a fall |
| jump at a tread's lip | — | peak 1.80 m — arc intact |
| 20° ramp, 45 frames | — | 0 airborne either way |

**Comfort is still yours to judge.** Zero airborne frames is not the
definition of good stairs and this does not claim to have found one.
What it claims is that the fall is gone and the three things that must
still fall, jump and slide still do.

### Bounded traversal routes, on the real controller

`make godot-traverse`, a new suite. It drives the **real player body**
along a **named route** and reports one of five outcomes; only
`BLOCKED` asserts anything.

Calibrated before it is believed: it must cross an open corridor, must
be stopped by a 4 m wall **and name it**, and must climb a staircase
rather than treat it as a wall.

On the played Zone, built through `ZoneController` (not `ZoneBuilder` —
the pedestals, stations and player are the controller's, and a first
version found zero Check pedestals in a fifteen-Check Zone):

- **5 of 6 sampled Checks reached** from their own room's doorway on
  the base kit (walk + jump, no Echoes), all five addressable by the
  game's own interact ray.
- **1 `OFF_LEVEL`**: `Reward_89100126` sits 2.6 m below the floor the
  walker reached, with nothing in the way. That is your *"also the
  check is floating"*, and it is not a blocked route.
- **0 blocked.**

Four wrong verdicts were caught on the way, each by asking *why*
rather than reading the count: three "blocked" routes were the body
50 m below the Zone (a doorway position is a point in the door plane,
not a place to stand); the wall control reported "lost" because the
walker was mid-jump when the stuck counter expired; the exit approach
ended held by a layout verdict that offline never arrives; and the
"floating" Check was filed as geometry.

### Exit placement and approach — kept apart

Standability beside the portal is **placement evidence**, and the queue
was right to insist it is not a route. Both were measured:

- 3 of 16 bearings at 2.5 m around the portal are standable;
- the approach from `c023/exit` **reached** it, and the game's own
  interact ray found it from where the walk stopped.

**Your exact reported approach is still unresolved** and stays that way
until the save arrives.

### Assembled joins

Real assemblies, with the pair that makes the sample readable:

- 3 of 6 sampled declared doorways walked through;
- the same doorway with a 6 m slab across it **refuses** the walker;
- `c001/side_left` has no partner doorway within 6 m **and** lets the
  walker out into a fall — a **leak candidate**. The partner test is a
  labelled proxy for a join list the controller does not carry, so this
  is a lead, not a verdict.

### Diagnostic launcher

`Start Archipepsi (Windows).bat` starts the bridge at **prototype**
scale in `bridge/saves`, and both are silent until several Zones in.
That is how the diagnostic run came to be taken at the wrong scale in
the wrong folder.

New: `Diagnostic Campaign (Windows).bat` → `python -m
archipepsi_bridge.diagnostic`. It pins mock AP, the deterministic
Epsilon and **default scale**, prints build / scale / resolved folder,
and makes the save folder a named slot you pick without editing a
command. It never deletes, resets or moves a save, never writes to
`bridge/saves`, and never touches git.

**Platform limitation, stated plainly:** the `.bat` was **not executed**
— this container is Linux and has no `cmd.exe`. Every decision it
delegates is in the Python, where 26 tests check it, including that a
path with a space in it stays one argument. The launch path itself was
run here end to end, and the port-conflict refusal was verified against
a real second bridge.

### Targets on walls

Your note: *"they have pegs and they should be sticking out of the
walls."* The stalk was always there; `_row` placed targets with the same
floor-plan solve it uses for switches, so it held them off nothing.

A `SHOT` element is now offered a side wall (not the ends — that is
where you come in), turns to face the room, and sits exactly the
stalk's reach off the wall plane. The offer may be declined: a wall
that is all doorway returns nothing and every element is still built.
A room that vouched walkable surfaces is not offered a wall at all —
`godot-zone-audit` caught the first version putting six elements over
a `platform_path`'s forty-metre pit.

Controls: mounted and facing and clear of the doorway and on **both**
walls; shot with the real Static Pulse from the walking lane while
standing on the floor; the same shot through a slab must **miss**; a
room with no mountable wall declines and still builds all three.

Screenshots at player height: `docs/evidence/away-batch-0.3/`.

### Stations ask where you want to go

Pressing E teleported you to whichever reached station came next in
build order. It now opens a panel.

- lists reached stations only; the one you are standing at is shown and
  not selectable;
- opening moves nobody, Esc moves nobody, one choice moves you once
  however many times it is pressed;
- broken stations still refuse and still need their puzzle; first
  activation is unchanged.

**Return to Hub is wired** — it is the pause menu's own handler:
`leave_zone` after the resume anchor, keys, opened locks and reached
stations are remembered, so the Zone goes **dormant** and the portal
offers it back. It is not `abandon_zone`.

**Save is not a button, and that is the traced answer.**
`station_reached` already goes to `CampaignEngine.handle_progress`,
which commits through `store.write_save` — the campaign is on disk the
moment a station is reached. There is no second "save now" operation to
wire, and inventing one would mean inventing a save slot. The panel
says what is true instead: *"Your progress is already saved — reaching
a station writes it."*

### Keys say what they opened

You finished the playtest holding three keys, reporting you had found
no door that uses them. Both halves of the reason were in the code: the
pickup toast said `RED KEY` and nothing else, and every lock that opened
sent its own `UNLOCKED` card with no room on it.

One message now, assembled from what actually opened:

```
RED KEY   opened the way in the arena (c004) and 1 elsewhere
```

A room is named by **what it is** as well as its id — you read `c018`
off a return pad and asked what c018 was. And only a room you have
been in this session: an unreached room is counted and never named. No
persistent map state, and a load is not an event, so a resume does not
greet you with last night's doors.

### Which puzzle in a room did something

A station's repair is attached to a **room**, so the first activity
solved there repairs it and every later one finds it already repaired.
Both said `<ID> COMPLETE`. The completion card now carries the
consequence — `STATION HALL ONLINE`, or `HALL was already online`, or
nothing at all in a room with no station. Truthful feedback from facts
already established; no extra reward, nothing marked complete, nothing
made compulsory.

---

## 2. Blocked, with the exact decision needed

### Retiring `timed_run` and `pressure_routing`

`python -m tools.family_retirement` composes the same Zones twice and
prints the deltas. Twelve default-scale Zones:

```
family                   before    after   delta
pressure_routing             86        0      -86   <- retired
timed_run                    75        0      -75   <- retired
switch_sequence              85      180      +95
target_challenge             97      178      +81

rooms 248 -> 248    enemies 411 -> 411    Checks 180 -> 180
```

**161 activities removed, 176 more of the two that stay.** The composer
picks by `kinds[(guard + len(acts)) % len(kinds)]`, so a shorter list
is not less content — it is the same content made of two families
instead of four. That is the substitution you asked against.

**The decision you need to make:** what fills the budget those two
families were spending. Three shapes, none of them started:

1. **Let the Zone be worth less.** The rooms stay, the point total
   drops, and the budget band moves to match. Cheapest, and it makes
   levels quieter rather than denser.
2. **Spend it on rooms instead of activities.** More, smaller rooms at
   the same total. Changes pacing, not density.
3. **Replace the families with something new.** The largest, and it is
   a design task rather than a switch.

Until then the list ships unchanged. The compatibility conditions are
already fixed in place so whoever makes that change cannot take an old
campaign with it: the schema keeps both identifiers whatever the
composer does, a committed Zone carrying either still validates, a
retired kind is never translated into a surviving one, and the held
plate is a constant the engine reads rather than a property of the
family that generates it.

**Coordination:** the composer is the bridge lane's file. The only edit
made to it is a pure hoist of the family list to
`fallback.ACTIVITY_KINDS`, byte-identical in behaviour, so the question
can be asked without editing the composer. **Dess owns the change
itself.**

### Your diagnostic save

`.diagnostic-582e954` is on your machine and not here. The exact
Whistle crossing and the original exit seam stay unresolved. When
you're back, a **private copy** of the slot JSON is enough — the
original stays where it is and untouched.

---

## 3. Prototype — review only

### Navigation schematic (F5)

*"I'm lost. I realize we have made a 3d metroidvania with no map."*

You are right, and what a map should be is yours to decide. This is the
smallest thing that can be **looked at**: F5, beside the F3 readout and
F4 labels, off by default, and nothing in the game reads it.

![the schematic](evidence/away-batch-0.3/nav_schematic_prototype.png)

Every fact on it is one something else already owns — rooms from the
chamber tracker, links from the Zone's own declared edges, locks from
`gates_not_yet_open()`, stations from `stations_reached()`. No second
stored topology and no persistence: a reload shows an empty panel and
says so.

It can only show a room you have walked, and only a link between two of
them. It is a schematic and says so: dots are room centres, lines are
declared adjacency, a line is not a corridor and its length is not a
distance. **No bearing arrow and no path guidance** — "which way now"
is the question you actually want answered, and answering it badly is
worse than leaving it open.

What it can tell you today: where you are, which rooms you have been
in, how they connect, which of them still has a gate you cannot open,
and which stations are live. What it cannot: anything about a room you
have not entered, and anything about distance or direction.

### Shared-puzzle consequence — the proposal, kept a proposal

One representative room, audited: a room with two activities. Both
`_repair_station_for` calls hit the same station, the first repairs it
and the second finds it already repaired. The local reward each
activity sends is keyed by its own identity, so **both still pay** —
the shared thing is the station, not the loot.

That makes them **two independent activities that happen to share one
consequence**, which is neither of the two clean shapes:

| shape | what the player is told | what they get |
|---|---|---|
| alternative solutions to one problem | "either of these opens it" | one payoff |
| independent activities | "two things to do here" | two payoffs |
| **what we have** | nothing | two payoffs, one station |

**Implemented now, because it is truthful feedback from facts already
established:** the completion card says which it was. Nothing else
changed — no extra reward, nothing marked complete, nothing compulsory.

**Proposed, and not done:** declare the relationship in the room. If
two activities in a room are meant to be *alternatives*, the composer
should say so and the second should read as already-solved rather than
as a puzzle with no visible effect. If they are meant to be
*independent*, each wants its own consequence and the station is the
wrong thing for them to share. **Which of those it should be is your
call, and it is the same call as the budget shape above** — both are
questions about what a puzzle is for.

---

## 4. Still needing your judgement

- **Comfort of the repaired stairs.** Mechanically the fall is gone.
- **Whether `Reward_89100126` being 2.6 m below its walkway is a bug.**
  It may be a drop you are meant to take.
- **`c001/side_left`**, the leak candidate.
- **Which of the three budget shapes** the family retirement takes.
- **Whether the schematic is the map** or the sketch a map replaces.

---

## 5. How to launch and resume the diagnostic campaign

Double-click **`Diagnostic Campaign (Windows).bat`**. That is the whole
thing: it resumes the same slot every time and never resets anything.

Options, if you want them — drop one on the command line:

```
--list            which diagnostic slots exist, and where
--slot 582e954    resume a slot by name
--new             begin a fresh slot named for this revision
--dry-run         say what would happen and start nothing
```

Updating is still a **separate** double-click (`Update Archipepsi`).
This file never fetches, switches branch or resets anything.

**Your original save is untouched.** `.diagnostic-582e954` is where it
was; nothing in this batch reads, writes, moves or deletes it, and
`.diagnostic-*` is gitignored so no slot is ever committed.

---

## 6. Replay checklist, for when you're back

Short, and in the order the work landed.

1. **Walk down a staircase.** The two-tread drop in a `treasure_room`,
   or any set of steps. Does it feel like walking or like a series of
   small falls? Then **jump off a real ledge** — it must still be a
   fall.
2. **Walk up to a `target_challenge`.** Are the targets on the wall?
   Can you shoot them from where you naturally stand?
3. **Press E on a warp station you have reached.** The panel should
   open without moving you. Escape should move nothing. Pick a
   destination; it should warp once. Try **Return to Hub** and then
   re-enter the Zone from the portal — it should be the same Zone,
   where you left it.
4. **Pick up a key.** One card, naming a room you have been in.
5. **Solve two puzzles in the same room.** The second should tell you
   the station was already online.
6. **Press F5.** Tell me whether that is a map or a sketch of one.

---

## 7. For the bridge lane (Dess)

One thing, and it is not urgent.

`fallback.ACTIVITY_KINDS` is now a module constant instead of a literal
inside `_build_to_budget`. Behaviour is byte-identical; the point is
that `python -m tools.family_retirement` can measure a change to it
without editing the composer.

The owner has decided the two standalone drills should stop being
generated. **The change is yours**, and the measurement says it cannot
be the switch alone: over twelve default-scale Zones it removes 161
activities and returns 176 more of `switch_sequence` and
`target_challenge`, because the family is picked by
`kinds[(guard + len(acts)) % len(kinds)]`. Rooms, enemies and Check
allocation are unchanged, so nothing else absorbs it.

The three budget shapes are written up in §2 of this document. The
engine-side compatibility conditions are already pinned in
`bridge/tests/test_activity_family_retirement.py` — schema keeps both
identifiers, a committed Zone still validates, no kind is translated on
the way in, and the held plate is a constant the engine reads. Those
should stay green through whatever you pick.

---

## 8. Verification

All of it ran **serially** on `b3d583d`, on Linux, with Godot 4.5.1
headless (`zone-shots` under xvfb). Serially on purpose: an earlier
overlapping run produced one transient `test_playtest_baseline`
failure that was a race between my own runs and not a defect — it
passes alone and it passes here.

| | |
|---|---|
| `pytest bridge/tests` | **1389 passed** |
| `pytest apworld/tests` | **39 passed, 627 subtests** |
| `make test-schemas` | **131 passed** |
| 20 offline Godot suites | all green |
| `godot-integration`, `godot-return-journey`, `godot-reload` | all green (live mock bridge) |

The numbers this batch is actually about:

```
godot-physics (68 checks)
  stays with the treads: 1 airborne frame of 40, where a free fall
    down two 0.4 m treads spends 20
  a 2.5 m ledge is a FALL, not a step down: 24 airborne of 45
  a jump taken at the lip of a tread still rises: peak 1.80 from 0.40
  a 20-degree ramp: feet on it the whole way, 0 airborne of 45

godot-traverse (12 checks)
  the base kit reaches 5 of 6 sampled Checks from their own doorway
  0 BLOCKED by geometry
  1 Check off the level the walker reached -- needs your eye
  the exit: 3 of 16 bearings standable (placement), approach REACHED
  joins: 3 of 6 walked through; a 6 m slab across one REFUSES the
    walker, so those walks are about the geometry
```

### What was NOT verified, stated rather than implied

- **Windows.** No `cmd.exe` here. The `.bat` files were read, not run.
- **Comfort.** Every claim above is mechanical.
- **Your Zone.** No fixture here reproduces it and none pretends to.
- **Anything beyond the sample.** `godot-traverse` walked six Checks,
  one exit and six doorways in one assembled Zone. It is a sample, not
  a certificate, and a straight-line walker that does not arrive has
  measured its own route choice.
