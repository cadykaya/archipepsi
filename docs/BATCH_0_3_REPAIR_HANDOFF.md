# Bounded 0.3 repair batch — what changed, what was measured

Prod (engine lane), branch `claude/archipepsi-echoes-continuation-b1adno`.
Scope: required traversal and activity feedback, from the first human
playtest. No map, warp menu, room wave, enemy routines, Forge, Static
spending or 0.4 setpieces.

**No bridge contract moved, so nothing needed coordinating with Dess.**
`MAX_VERTICAL_STEP` has no Python readers and its value is unchanged.

---

## The evidence basis, and its one limit

`godot/tests/fixtures/played_zone.json` **reproduces the owner's Zone**,
corroborated on five independent attributes against their debugger
output: `zone_001`, the same 23 room ids `c001`–`c023`, 15 Checks, 15
procedural rooms, and **8 of 8 shell assignments matching** — c004, c010,
c016, c022 `shell_corner_right`; c007, c013, c019 `shell_corner_left`;
c006 `shell_hall_transit`.

**The limit, stated because it matters to item 1:** AP location ids are
allocated by campaign progression, not by layout. The played proposal's
Checks are 76, 89, 19, 42, 147, 93, 110, 139, 97, 55, 51, 5, 25, 126, 68
— which includes most of the owner's tracker readings but **not CHECK
120**, the one they reached with the Whistle. So the geometry reproduces
and the numbering does not, and **that specific Check could not be
located by id.**

---

## 1. Required routes

### Stairs — DEMONSTRATED DEFECT, REPAIRED

`MAX_VERTICAL_STEP` was 1.0 and `player.gd` implemented **no step-up at
all**, so the real height was zero and every rise had to be jumped.

**The intended treatment was not invented.** `chamber_builders` already
builds towers on platforms of `minf(1.0, MAX_VERTICAL_STEP)` and states
why — *"each platform rises step_rise ≤ MAX_VERTICAL_STEP, so the
mandatory route up is base-kit"* — and records the other half at its
gallery deck, where a 0.35 m lip *"stops a walking player dead"* and was
worked around by notching a gap rather than by giving the body the step.
So the constant stays at 1.0 and the body is brought up to it. Lowering
it would have silently reshaped every tower, since the tower's platform
rise is derived from it.

**Obstacles that must remain obstacles were checked, not assumed:**
`DestructibleCover` 1.4 m and `ReactiveBarrel` 1.1 m are both above the
limit; everything the builders place between 0.45 m and 1.05 m is thin
greeble no body can stand on; and a `ManipulableBody` landing is refused
outright, because a thing the player is meant to shove is not a stair.

**Headroom** is the second of three probes — a body under a low ceiling
may not step, so a crawl space stays a crawl space.

**Descending is NOT fixed, and is named rather than implied.**
`floor_snap_length` is set to the step, but with snap at 1.0,
`velocity.y` at 0 and `up_direction` at +Y — every precondition Godot
documents — a body walking off a 0.4 m tread at 7 m/s still leaves the
floor and free-falls it. The control reports the airborne count instead
of asserting one. **Open.**

### The Check reached with the Whistle — NOT ESTABLISHED

Two reasons, both recorded: the specific Check cannot be identified by id
(above), and **the instrument built to measure reachability did not
work.**

A lattice of standable points over the played proposal, connected under
the implemented movement law and flooded from the arrival, was wrong in
three successive ways and still wrong at the end:

| run | nodes | reachable | Checks called unreachable | flaw |
|---|---:|---:|---:|---|
| 1 | 5800 | 72 | 15 | sampled room bounds only; connectors empty, every room an island |
| 2 | 6112 | 648 | 13 | sampled every placed piece; still islanded |
| 3 | 11524 | 1362 | 12 | `player_stands_here` wants `PLAYER_HEIGHT + 0.6` — a PLACEMENT predicate; replaced with a capsule fit |

Run 3 still calls 12 of 15 Checks and the exit unreachable **in a layout
the owner cleared completely**. The probe is wrong, not the Zone. It was
removed rather than tuned until it agreed with the known answer, which
would have produced a tool that only confirms what was already believed.

**This is direct evidence for the review's open question:** a geometric
flood-fill over a lattice is not the cheaper decisive test, and its
failure mode is exactly the one to watch. A next attempt should drive the
real controller along candidate routes and treat a timeout as *not
established by this attempt*.

### The exit seam — NOT RE-EXAMINED IN THIS BATCH

The join-seal coverage gap stands as recorded in the findings log. The
exit *transition* is covered (item 2); the *approach geometry* is not.

---

## 2. The real exit transition — COVERED

`integration_driver` previously jumped to the timing intent under a
comment admitting it *"never takes the real exit path"*. The portal is
now interacted with as a player interacts with it, and the frames after
it are stepped with the player detached — the state the crash lived in.
**48 checks across the run** (four per Zone): the portal asks to leave,
the player survives the teardown frames, its probe answers empty rather
than reading a world that is not there, and the campaign still reports a
mode.

**And the suite could not have seen a crash anyway.** Removing the
`camera_ray` guard made the run print the original SCRIPT ERROR and still
exit 0 — `godot-integration` never checked for one. It now fails on a
script error, verified both ways: clean tree exits 0, crash reintroduced
exits 2.

That guard surfaced a **pre-existing** error the suite had been printing
and ignoring: an invalid cast at `zone_controller.gd:817`, where
`BridgeClient.active_zone().is_empty()` is evaluated on the falsified-
layout control after the Zone has gone. Outside this batch; the guard
excludes that one known message and fails on anything new. Recorded, not
fixed.

---

## 3. Activity feedback — REPAIRED

- **The completion chime asked for a name the bank does not define.**
  `tones.play("secret_found")` against a bank keyed `"secret"`;
  `Tones.play` returns silently on a miss, so a solved activity has been
  mute since the line was written. `"secret_found"` is real in
  `epsilon_voice.gd` — one identifier carried between two vocabularies.
- **`bridge/tests/test_tone_references.py`** parses the bank's keys and
  every `tones.play("...")` literal and asserts the names resolve.
  Verified against the defect: restoring `secret_found` fails it.
- **Failure had no listener anywhere.** `failed` has been emitted since
  the activity batch and nothing connected it, so a timeout cleared every
  element with no report but the geometry going dark. It now toasts and
  plays `denied`.
- **A counted hit was silent.** The runtime now plays `confirm` at the
  moment a hit counts, where the player is looking.
- **Progress is on screen while playing.** The countdown already existed
  and was being produced, not received — its label sits above where the
  activity starts. A new `progressed` signal mirrors the same text onto
  the objective line beside the Check count, cleared on completion or
  failure.

**No new reward or consequence is claimed.** This makes current behaviour
understandable; it does not touch the separate meaningless-activity
finding.

---

## Evidence

Targets exercised, one combined revision, tree clean:

- **Python** `make test` 1528 passed / 627 subtests; `make test-schemas`
  131; v0.8 packet check across 11 documents.
- **Godot offline, all 19**: zone-audit, test, room, room-contract,
  content, activity, graphs, physics, movement, boot, hud, rules, lab,
  legible, stats, verbs, affordance, blink, playtest3a.
- **Godot live bridge, all 3**: integration, return-journey (0 assertion
  failures), reload (2 + 18 checks).
- `godot-physics` **59 checks** including the three new step controls.

**Reproduced failures covered:** the stairs (repaired, controlled) and
the exit-transition crash (covered by a control that fails without the
fix, in a target that now fails on a crash).

**Declared sample:** the five generated fixtures `zone_01`–`zone_05` via
`godot-zone-audit` and `godot-graphs`, plus the played proposal
`played_zone.json`. A few passing fixtures are not universal
certification, and broader required-target reachability remains an
external-multiworld-readiness obligation rather than a 0.3 one.

**Old saves and retained failing fixtures preserved**: no schema or
fixture was edited; the five placement captures are regenerated from
source because the controller digest changed, and nothing else moved.

---

## Remaining blockers

1. **Descending a tread is still a fall.** Ascent fixed; descent open,
   with the measurement recorded.
2. **Required-target reachability is unmeasured.** The instrument failed;
   the approach is recorded for a next attempt.
3. **The exit approach geometry / join seam** is not re-examined.
4. **The invalid cast at `zone_controller.gd:817`** on the refusal path.
5. Everything on the findings log that this batch did not touch.

## For a short owner replay

Revision at the end of this document's batch; run
`./start-archipepsi.sh` (or the Windows `.bat`) with
`--mock-scale=default` for the Zone this work was measured against, leave
that window open, launch Godot, press **MOCK CAMPAIGN**.

Worth trying specifically: **walk up a Check pedestal** rather than
jumping it, **shoot a target** and listen for the hit, **let a timed
activity run out** and watch for the failure toast, **read the objective
line while playing** an activity, and **take the exit portal** — which no
longer crashes.
