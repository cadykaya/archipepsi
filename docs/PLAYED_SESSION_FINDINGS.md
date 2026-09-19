# The owner's own session, read

**Source:** the owner's uploaded bundle — the `.diagnostic-582e954`
slot JSON, its `.bak`, and one `playtime.jsonl` — worked from a
disposable copy outside the repository. **Not committed. Originals not
modified.** Checksums verified against the bundle's own `SHA256SUMS.txt`
and against the loose copies shared earlier: same bytes.

**Build played:** `582e954da8e7`, Windows, Python 3.14.4, **`tree:
dirty`** — provenance, not a diagnosis. The bundle carries no
uncommitted diff, so matching this checkout to that commit cannot prove
the historical code was identical.

---

## The fixture is that Zone, and so is its geometry

Two separate claims, and only the first was ever checked.

**The content.** The uploaded proposal at `/zones/0/zone` is
**byte-identical** to `godot/tests/fixtures/played_zone.json` as parsed
JSON, and both hash to `fe2b014761fbb449` — the `zone_digest` in the
playtime record.

**The placement, which is new.** The save also carries the *committed
manifest* at `/zones/0/manifest`, and **the fixture carries none**. So
every engine measurement this batch built the Zone by SOLVING its layout
afresh: the right rooms, but an arrangement nobody had checked against
the played one.

Checked now. `godot-traverse` builds the saved proposal twice — once
re-solved, once replaying the committed manifest — and compares every
room transform:

> **re-solving reproduces the committed placement exactly: worst room
> 0.000 m**, across all 24 room records.

So the earlier measurements were on the played geometry after all. That
is a verified result rather than the assumption it had been, and the
walker now replays the manifest regardless:

```
make godot-traverse                      # the fixture, re-solved, as before
godot --headless --path godot -- --traverse-test \
      --zone-json=<copy>/proposal.json \
      --manifest-json=<copy>/manifest.json
```

**24 of 24 checks pass on the saved level.**

---

## CHECK 126 is in c021, and CHECK 120 does not exist

**Confirmed by the game, not by a lookup.** On the committed placement
the interact prompt at the pedestal reads:

> `[E] CLAIM CHECK 126`

`c021` is a procedural `platform_path`: 3 segments, declared `gap_size`
2.03, `vertical_step` 0.51, objective `platform_to_goal`, **entry
`USED` by `e:c018:c021`, exit `SEALED` with no edge**, carrying
`p:c021:start` — a TRAVERSAL_ONLY return pad bound for `zone_start`.

**`89100120` is allocated nowhere in this save.** Checked against the
proposal's chambers. Any earlier "CHECK 120" wording was not an
identifier.

---

## The crossing, from where a player is actually put down

**The earlier start was the wrong door.** `_nearest_doorway` picks by
distance and checks neither a door's usage nor where the room is
entered from — so on `c021` it chose **`c021/exit`, which is SEALED**,
has no edge, and is nowhere a player has ever stood. That result stands
only as **local approach evidence** — can the Check be addressed from
beside it — and was never a route.

**The route, run from the committed arrival** `(5.65, 0.0, 42.25)`,
where `e:c018:c021` puts a body down. One continuous walk, guaranteed
kit (walk + jump), nothing relocated along the course.

| | |
|---|---|
| arrival | x **5.6** |
| return plug `p:c021:start` | x **19.0** — 13.4 m along an 18.7 m run |
| CHECK 126 | x **24.3** |

All three on the same centreline, and **the plug sits between the
arrival and the Check**.

**Attempt A — everything live: the plug fired.** Walking the line took
the body over `p:c021:start`, which announced itself on its own
`traversed` signal and sent it to `zone_start`; it ended at
`(3.3, 0.0, 6.0)`, in `c001`. That is the **device doing its job**, not
the course refusing a route.

**Attempt B — the same walk with that one trigger muted: REACHED**,
closest 2.20 m, 143 frames. Route and transition are separate subjects
and A cannot separate them; B isolates the course. Nothing was moved or
rebuilt — one `Area3D` stopped monitoring for one walk and was restored.

> **The course is crossable from its real arrival on walk and jump
> alone.**

### Route C — the complete outbound journey — NOT DEMONSTRATED

You asked for one bounded route with everything active: arrival, CHECK
126 reached and addressable, deliberate return. **It could not be
demonstrated, and the interference is arithmetic.**

`c021` is a line of **narrow platforms over the drop**, not a wide
walkway. The centreline, cast from above the course:

| x | centreline floor | +3.0 m off-centre |
|---|---|---|
| 14.2 – 15.2 | y 1.02 | — |
| 15.7 – 17.7 | **gap** | — |
| 18.2 – 19.7 | y 1.53 — *the pad's platform* | — |
| 20.2 – 22.3 | **gap** | — |
| 22.8 | y 1.53 | y 1.53 |

Swept laterally at the pad's own x, in 0.25 m steps:

> **the platform carries floor from −1.25 m to +1.25 m of its centre —
> 2.50 m wide. Passing the trigger needs more than 1.80 m. Short by
> 0.55 m on each side.**

The plug's trigger is a 1.4 m cylinder; a 0.4 m body needs 1.8 m of
lateral clearance to walk past it. **The trigger spans its own
platform.** A walking route to this Check must cross that platform, and
there is no floor beside the pad to cross it on.

**This is specific to this committed placement and this controller. It
is not a claim that no route exists**: the kit has a jump, this walker
steers in straight lines, and nothing measured here rules out a
player's own solution.

**Nothing was repaired** *(true when written; the repair below came
after)*. The pad was not moved, no return was disabled in the live
route, and no activation policy was changed.

**The archived and freshly computed anchors do agree — but the first
comparison that said so proved nothing.** It read the "fresh" value out
of a build made with `--manifest-json=`, and `ZoneBuilder.layout_from_json`
hands the archive's own numbers back, so the archive was compared with
itself. The claim happens to be right, and here is the evidence that
actually establishes it: built from the same proposal with **no
manifest**, on the unrepaired code, `room:c021:return` lands at
`(19.0, 1.5, 42.2)`. The archive carries `(18.99, 1.53, 42.25)`. One
centimetre apart, computed independently — so the pad's place is what
current code produces, not an artefact of that particular save.

**And there is a valid way out.** Walking from the Check onto the return
plug **fires it** (`p:c021:start → zone_start`). The walk's own outcome
reads BLOCKED at 2.25 m, which is the walker still aiming at a pad the
body has just left — the signal is the fact, not the walk outcome. An
earlier version of this check read that outcome as the answer and
reported a working exit as a softlock.

**WHICH CONTROLLER.** All of this ran on the **current build, with this
batch's descent repair in it**. It says the crossing works on the
repaired controller. It says nothing about what the owner's older build
did, and is not an explanation of their session.

Reproduce:

```
godot --headless --path godot -- --traverse-test \
      --zone-json=<copy>/proposal.json --manifest-json=<copy>/manifest.json
```

**26 of 26 checks pass on the saved level.**

---

## Withdrawn: the "timed, gap-spanning switches" reading

I wrote that `c021`'s four switches were spread across the gaps, making
the activity a traversal with a timer running. **That was wrong on every
count**, and it came from reading one camera angle instead of measuring.

From the saved proposal, and from the built geometry:

| claim | measured |
|---|---|
| "timer already running" | `time_limit` = **0.0** — untimed |
| "in order" | `ordered` = **false** |
| "spread across the gaps" | all four at **x 4.6, y 1.0**, spanning 5.0 m in z |
| "along the course" | at the **arrival end**; the Check is at x 24.3 |
| — | floor sampled every 0.5 m between the first and last switch: **0 of 11 samples without ground — one continuous ledge** |

Which is what the owner's screenshot showed. The render in this
directory is the same room from a camera angle that made a lit near
ledge and a shadowed far one look like two; it is kept as a picture of
`c021`, not as evidence about the switches.

**And nothing here reads the 792 active seconds as difficulty.** The
measurement does not support it and elapsed activity time is not a
difficulty diagnosis.

---

## The Whistle: two different Whistles, and 126 is the upgrade

The `.bak` and the live save differ in **exactly one field**:

```
slots.mobility   act_l89100076 (Fresh Rep, dash)
              -> act_l89100019 (Warp Whistle, blink)
```

Everything else — every interpretation, the proposal, the manifest, the
progress — is equal. The `.bak` is the moment before the Whistle went
into the slot. It is not a second layout, and restoring it would not
produce different geometry.

**But the final Whistle is not the Whistle that reached CHECK 126**, and
this matters for any crossing question:

| seq | from | effect | range | cooldown |
|---|---|---|---|---|
| 4 | CHECK 019 | **first acquired** | 14.0 | 2.50 |
| 5 | **CHECK 126** | range +6.0 | **20.0** | 2.50 |
| 9 | CHECK 042 | cooldown −0.2 | 20.0 | 2.30 |
| 10 | CHECK 147 | cooldown −0.2 | 20.0 | **2.10** |

CHECK 126 *is* the +6. Whatever crossing reached it was made with **at
most the 14 m Whistle**, never the 20 m one. An earlier version of this
page quoted only the final 20 m figure; that was the right number for
the wrong moment.

Fresh Rep's recorded primitive is **`dash`** — no jump-height trait is
recorded for it. An apparent assisted jump would still need controller
measurement.

**Was the Whistle needed?** Earlier I answered this from the *declared*
`gap_size` values, which is not evidence about built geometry. Answered
properly now, by walking the committed placement with the real
controller and the base kit only:

> **6 of 6 sampled Checks REACHED, 0 BLOCKED**, including
> `Reward_89100126` from `c021`'s own doorway (closest 1.20 m,
> addressable, prompt shown, real `interact()` runs). The room can be
> left again across a **2.00 m** measured gap, inside the 2.60 m
> base-kit jump.

So on the played geometry the sampled routes do not need the Whistle.
Those six started from the nearest declared doorway, which is **local
approach evidence** (see above) — for `c021` the one route run from the
real arrival also reached, on walk and jump alone. Six sampled Checks,
one real-arrival route, not a proof about all fifteen, and nothing about
how a human would choose to move.

**`Reward_89100126` sits on ground at y 1.53 with 0.00 m under it.** The
Check this lane once reported 2.6 m below the floor, and retracted, was
reached by the player and is reachable by the walker. The retraction was
right.

---

## The exit approach, on the saved join

Walked on the manifest's own `e:__exit__` (`c023` → `exit`, synthetic):

- the exit portal is **REACHED** from `c023`'s nearest doorway (10.5 m,
  closest 2.10 m) and the game's interact ray finds it;
- **3 of 16** bearings at 2.5 m around the portal are standable — that
  is placement evidence, not a route;
- `c023`'s ordinary exit is declared **SEALED** while the manifest also
  carries the synthetic exit join. **Both facts stand**; neither alone
  is a leak or an obstruction, and the route and the transition logic
  are separate subjects.

All 22 SEALED sockets on the assembled Zone measure solid, and the
deliberately mislabelled control is still caught.

---

## What the session says about the two retired families

4770 seconds of elapsed time on one Zone, 1391 of them inside an
activity. **That elapsed figure is not play time**: the owner says the
session included discussion and assistance, so it is not evidence of
difficulty or frustration and is not read as any here. 28 of 29
activities completed, 4 deaths, `zone_value` 911 against a 1000 budget.

The per-activity numbers below are a different matter — they are the
activity's own timer, and they are what the families were doing.

| family | n | completed instantly | median | max | needed a retry |
|---|---|---|---|---|---|
| `pressure_routing` | 5 | 1 | 2.72 s | 7.14 s | **2** |
| `switch_sequence` | 7 | 0 | 6.33 s | 792.65 s | 0 |
| `target_challenge` | 8 | 0 | 2.25 s | 257.82 s | 0 |
| `timed_run` | 9 | **5** | **0.00 s** | 9.14 s | 1 |

**`timed_run` was over before it started, five times out of nine.** Its
median active time is zero. A timed run whose timer never accumulates is
not a race; it is a doorway with a label on it.

**`pressure_routing` would not hold.** Of five:

| | |
|---|---|
| `c023_0` | **23 attempts** for 2.72 s of active time |
| `c011_0` | 3 attempts |
| `c015_0` | entered, 0.00 s, **never completed** — the only failure in the Zone |

Three of five misbehaved. And the room holding the 23-attempt plate ate
**1060 seconds — 17.7 minutes, a fifth of the whole session** — for 43
points of content.

**This is the strongest evidence yet for retiring those two families,
and it is not the evidence the variant is built on.** The variant
removes them to reduce content *volume*. The session says they should go
because they *do not work*: one completes itself, the other will not
latch. Those are different problems with different remedies, and cutting
the budget by 28% addresses neither.

---

## Two other things worth seeing

**`c021_0` recorded 792 active seconds** on a four-element
`switch_sequence`. The explanation I offered for it is withdrawn above,
and **no replacement is offered**: the switches are untimed, unordered
and on one ledge, so nothing measured here accounts for the number, and
elapsed activity time is not a difficulty diagnosis. It is recorded and
left alone.

**The three longest rooms after the arena are all `platform_path`.** Per
the caveat above, the room timers include whatever else the session
contained, so this is a place to look rather than a measurement of
traversal cost.

---

## What this does not settle

- **Why** `timed_run` completes at 0.00 s, and **why** the `c023` plate
  needed 23 attempts. Both are reproducible-looking, neither is
  diagnosed, and neither was chased here — that would be new work.
- Whether the 792 s in `c021` is a defect, a course that simply takes
  that long, or time the session spent not playing. The record cannot
  separate them.
- **Whether the sampled six generalise.** Six of fifteen Checks were
  walked, and only `c021`'s was run from its real arrival; the other
  five started from the nearest declared doorway, which may be the
  wrong door for them too.
- **Why `c021`'s return pad sits on the line** between the arrival and
  the Check. A body walking straight at the Check is sent home by it.
  There is lateral room in an 8 m wide course to pass beside it, and
  nothing here measures whether a player finds that obvious. Not
  chased — it is a design question, not a defect I can demonstrate.
- **The `c023` exit seam.** SEALED ordinary exit plus a synthetic join
  is preserved as two facts; which one the production reconstruction
  path follows was not traced.
- Anything about the variant's router blocker, which is unrelated and
  documented in `docs/FOLLOWUP_02_INTEGRATION.md` §6a.

---

## The return placement, repaired — and where the defect actually lived

**The product rule.** A convenience return must not intercept the normal
required approach to the reward. A player has to be able to reach the
reward, use it, and *then* deliberately walk to the return, with every
device live.

### What was actually putting the pad on the course

Two stages, and the first one is not where the damage was done.

**Stage 1 — the reservation.** `ChamberBuilders.return_spot` took the
**last** `stand` surface the room declares that is wide enough to hold a
capsule. On a `platform_path` that is the end ledge, whose centre **is
the reward**. So the reserved spot was the Check's own square metre.

**Stage 2 — the settle, and this is the one that hurt.**
`RoomAudit._settle_return_anchors` re-measures every `room:<rid>:return`
against three questions — is the ground supported, is a body at the
arrival outside the trigger, and is the spot clear of the room's
content path — and when the reserved spot fails, it searches the room's
declared stands for the farthest one that passes. It moved
`p:c021:start` off the reward and onto **island 3, the last platform
before it**, which is squarely on the only route to the Check. Measured,
not inferred: unrepaired, a fresh build publishes `(24.27, 1.53, 42.25)`
from the builder and the controller receives `(19.0, 1.5, 42.2)`.

The guard that should have refused island 3 is `clear_of_content_path`,
and it was guarding nothing. Its content point comes from
`RoomAudit.content_of`, which returns **the room's warp station** — and
`c021` has no station, so `content_of` answered `INF`, the guard
answered `true` for every candidate, and the search was free to stand
the device in the middle of the approach.

### The repair

**`ChamberBuilders.return_spot` reserves a spot that is already valid.**
Instead of the last qualifying surface's centre, it gathers the claims
first — the arrival, the key spots, and `reward_clearance` — and tries
the declared stands **furthest first**, sampling across each surface for
a place a body fits that clashes with none of them. On `c021` that is
local `(2.6, 1.53, 21.62)`: the same end ledge, **2.6 m to the side of
the reward, level with it**, past the whole course rather than on it. No
world coordinate is named anywhere; the room's own declared fields
decide it.

**`RoomAudit.content_of` falls back to the committed reward** when a
room has no station, so the settle pass can no longer re-create the
defect in a room whose reservation is rejected. The station is still
preferred where there is one. The fallback keeps the property the
station was chosen for: it is a function of the committed layout, so a
cold restart settles the anchor in the same place.

On `c021` the first change alone is sufficient — the settle accepts the
reservation and never searches. The second is why the same defect cannot
come back through the other door.

### The acceptance case, executed

One route, guaranteed kit, every trigger live, **nothing relocated
between legs** — each leg starts where the last one left the body:

| | |
|---|---|
| Arrival | `(5.6, 0.0, 42.2)`, where `e:c018:c021` puts a body down |
| Outbound | **REACHED**, 143 frames, walk and jump only |
| The pad on the way | **did not fire** — the plug's own signal, not a distance |
| The reward, reached | the game's own interact ray finds CHECK 126 from where the route ends |
| The reward, used | `subject.interact(_walker)` runs from that position; `[E] CLAIM CHECK 126` |
| Deliberate return | `p:c021:start → zone_start` **fired**, at frame 14 |
| And it delivered | the walk **stops there**; the body lands **0.20 m** from `zone_start` |

**Both end checks were looser than they looked.** `interact_prompt()` is
a property of the object — it reads the same standing on the Check as
standing in the next room — so asserting it non-empty asserted nothing
about where the route ended. The game's own interact ray, aimed and
polled from the final position, is what answers, and the reward's own
interaction path then runs from there; offline it refuses, which is the
correct refusal and is what the check pins. On the other end, the leg
used to keep steering for a hundred frames after the teleport, drift
about six metres, and be excused by "within a quarter of the journey" —
a tolerance sized to excuse the instrument. `_walk` now takes a stop
predicate and ends the frame the plug fires, so the number reported is
the landing: `0.20 m`, which is `anchor + UP * 0.2` exactly.

The return plug now sits **18.7 m along an 18.7 m run and 2.6 m off its
line** — at the end, beside the reward, off the approach. Unrepaired it
sat **13.4 m along and 0.4 m off**, and the same route reports
**BLOCKED at 7.11 m** with the plug firing on the way to the Check.

**Reverted, the case fails.** With `chamber_builders.gd` at its old
revision and nothing else changed, the same command returns two
failures: *the outbound route never touches the return plug* and *the
whole course is walked from the door the room is entered by*.

### Open defect, recorded and not resolved: a replay does not keep its committed placement

**The save file is untouched.** `work_manifest.json` still carries
`room:c021:return = [18.99, 1.53, 42.25]`, byte for byte. Nothing was
rewritten and no migration was written.

**And the device still moves.** `layout_from_json` parses the archived
`anchors` block; `_build_once` consumes only `rooms` and `joins`. Every
anchor is **recomputed** from the replayed poses, so reopening the
owner's own save on this build puts `room:c021:return` at
`(24.27, 1.53, 39.65)` — **5.89 m** from where the save says it is.

**This does not meet the committed-placement claim this branch has been
making.** `commit_layout`'s own words are "a committed layout is
replayed, never replaced", and `_the_committed_placement_is_what_was_played`
verifies exactly that — for room transforms, at 0.000 m. It was never
true of anchors, and nothing until now measured them. A *fixed* rule
that recomputes them was invisible; a rule that changes moves the
device.

**Deliberately left open.** This batch does not adopt anchor
recomputation as the intended persistence contract, does not revert the
placement repair to hide the consequence, and does not invent a
migration. The question for the owner is whether a replayed anchor
should come from the manifest — and if so, what a replay should do with
a manifest whose anchor the current rules would refuse.

### Reproduce

```
make godot-return-placement          # the producer regression, no save needed

godot --headless --path godot -- --traverse-test \
      --zone-json=<copy>/work_proposal.json        # fresh:  30 checks
godot --headless --path godot -- --traverse-test \
      --zone-json=<copy>/work_proposal.json \
      --manifest-json=<copy>/work_manifest.json    # replay: 31 checks
```

**The broader sampler's uncertainty is separate.** Three routes in the
Zone remain UNRESOLVED — a straight-line walker that does not arrive has
measured its own route choice. That is unchanged by this repair and is
not evidence about it either way.
