# Wave-1 final integration — independent audit of `833fe80`

**Independent audit. 2026-09-03. No implementation.**

| Role | Ref |
| --- | --- |
| **Audited Production head** | **`833fe80`** — *Wave 1 measures true, offers included* |
| Production prior head | `acbad8d` |
| Art source head | `468125e` |
| Prior physical-truth audit | `802732d` |
| Production report | `docs/reports/2026-09-03-wave1-final-integration.md` |

No product code, content, review state or promotion was touched. The only
artefact is this file.

---

## Method, and what it can and cannot claim

Unchanged from `802732d`, and stated again because the verdicts rest on it.
**No engine ran** — this environment has no Godot and no Blender binary. What
was measured is the importer's *input* and the engine's documented
deterministic transform of it:

* the committed `.glb` files, which are the exact bytes the scene importer
  reads, with `nodes/use_name_suffixes=true` in every `.import`;
* the convex hull each `-convcolonly` node becomes via
  `Mesh::create_convex_shape` → `ConvexHullComputer::convex_hull`, which is
  uniquely determined by the point set;
* Production's own probe geometry, replayed: `SpaceProbe`'s constants and
  query shapes, `MovementPackage._grapples` / `_rails`, `LaunchSolver.violations`
  and `RoomAudit`'s surface, socket and traversal checks, each copied from
  `833fe80` rather than reimplemented from the report.

Capsule queries are modelled as swept spheres against exact
point-to-polytope distances, so a contact is decided by real distance and not
by a bounding box.

**Two limits, stated rather than smoothed over.** The Godot suites could not be
executed, so every GDScript claim below is established by reading the code and
the assertions and by reproducing the arithmetic they rest on — I say
explicitly where that is the evidence. And the analysis is over the authored
shell colliders; composer-placed content is reasoned about from the
instantiation code, not observed.

**The Python suite did run.**

---

## 1. Provenance — CLEAN

Art `468125e` was synced on exactly four content paths, and every one is
**byte-identical** to Art's blob (tree hashes compared directly, not diffed):

| Path | Blob |
| --- | --- |
| `godot/content/SCENE_PLAN.json` | `f23131bd…` |
| `godot/content/registry/authored_art.json` | `fe085b1a…` |
| `godot/content/shells/shell_plenum_helix.glb` | `c862a693…` |
| `godot/content/shells/shell_plenum_helix.tscn` | `522a6dac…` |

No Art branch history was merged: `acbad8d..833fe80` is a single commit. The
remaining ten changed files are Production's own code, tests and docs. The
`SCENE_PLAN.json` delta is exactly the three moved collar markers plus the
plenum's `collision` count `117 → 150`, which is the decomposition (3 collars
× 12 wedges − 3 tubes = +33). **Verdict: faithful.**

## 2. Per-room structural / measured — CONFIRMED 0 / 0

`RoomAudit`'s surface, point-socket and traversal-endpoint checks replayed
against the imported collision of each room:

| Room | Surfaces | Point sockets | Traversal segs | Findings |
| --- | --- | --- | --- | --- |
| `shell_hall_transit` | 12 | 8 | 12 | **0** |
| `shell_plenum_helix` | 20 | 7 | 15 | **0** |
| `shell_span_basin` | 6 | 8 | 5 | **0** |
| `shell_yard_gantry` | 6 | 9 | 5 | **0** |

Every declared `stand` surface admits a valid placement on the 9 × 9
`Placement` grid with the full `STANCE` footprint and 2.4 m of headroom; every
`cover` and `enemy_high` socket has ground under it, is not buried and names a
surface at a consistent height; every traversal endpoint — **optional segments
included**, which is where the last audit's findings lived — has ground under
its `EDGE_INSET`-stepped probe.

The eight approved P2 shells were re-measured on the same head and are also
**0 findings**, so the integration did not disturb them.

## 3. The 24 movement offers — CONFIRMED 24 measured, 24 built, 0 declined

Replayed through Production's current logic: continuous `_grapples` with no
stride, `_rails` over the baked Catmull-Rom at the beam's own half-thickness,
and `LaunchSolver.violations` including the new source-standability and
reservation checks.

| Room | grapples | rail | launch pair | Result |
| --- | --- | --- | --- | --- |
| `shell_hall_transit` | 3 | 1 | 2 | 6 built / 0 declined |
| `shell_plenum_helix` | 3 | 1 | 2 | 6 built / 0 declined |
| `shell_span_basin` | 3 | 1 | 2 | 6 built / 0 declined |
| `shell_yard_gantry` | 3 | 1 | 2 | 6 built / 0 declined |
| **total** | 12 | 4 | 8 | **24 / 0** |

**These pass with margin, not on a boundary** — which is the part worth
recording, because the previous audit found the Hall's grapples passing by
exactly 0.000 m:

| Measure | Requirement | Measured |
| --- | --- | --- |
| rail beam clearance, Hall | ≥ 0.175 m | **0.628 m** |
| rail beam clearance, Plenum | ≥ 0.175 m | **0.461 m** |
| rail beam clearance, Span | ≥ 0.175 m | **1.100 m** |
| rail beam clearance, Yard | ≥ 0.175 m | **0.925 m** |
| grapple drops | 4.0 – 30.0 m | 7.43 – 27.20 m, all 12 |

The Span's three anchors — the false-refusal witnesses of the previous
audit — now build under the continuous probe, and the Plenum's `grapple_1`,
which was genuinely bad at 0.762 m of hang space, has moved to `x = 6.0` and
measures a 9.67 m drop onto `pl_collar_1_sec11`.

## 4. Launch-source contract — COHERENT IN DESIGN, ONE INCOHERENT INSTANCE

The contract as written is coherent and correctly implemented:

* `launch_source.position` is used as one origin. `LaunchSolver` validates a
  single trajectory from `stand_pose(to_world * source_foot)`; nothing iterates
  the radius.
* `launch_source.radius` is checked as a reservation against
  `LaunchPad.PAD_REACH`. **`PAD_REACH = 1.697056` is exactly the half-diagonal
  of the 2.4 × 2.4 m pad** (`1.2 × √2 = 1.69705627…`), verified arithmetically.
  All four rooms reserve 3.0 m, which holds it.
* `launch_target.position` remains the authored aim and `radius` the landing
  region, checked against `MIN_LANDING_RADIUS = 2.5`; all four declare 3.5.
* Transforms are correct. `_body_pose()` reads `global_position`, and
  `world_target()` reads `get_parent().global_transform * target` where the
  parent is the room root the pad is constructed into — so translation,
  vertical offset, yaw and nesting all come free, and `solve()` is world pose
  to world pose. The validator computes the same two poses from `to_world`,
  which `consume` sets to `root.global_transform`. The two cannot diverge.

### F-1 · The Yard's launch source is not a foot-contact point — **NEW FINDING**

**Physical fact proven.** Seven of the eight launch points in the four rooms
sit exactly on the surface beneath them. One does not:

| Room | Offer | y | Surface under it | Gap |
| --- | --- | --- | --- | --- |
| Hall | `launch_basin` | 0.000 | `hl_basin` | 0.0000 m |
| Hall | `launch_gantry` | 21.000 | `hl_east_gantry` | 0.0000 m |
| Plenum | `launch_floor` | 0.000 | `pl_floor` | 0.0000 m |
| Plenum | `launch_collar` | 11.333 | `pl_collar_2_sec05` | 0.0000 m |
| Span | `launch_basin` | 0.000 | `sp_basin` | 0.0000 m |
| Span | `launch_deck` | 14.000 | `sp_deck` | 0.0000 m |
| **Yard** | **`launch_west`** | **0.500** | `yd_floor` (top y = 0.0000) | **0.5000 m** |

The other three sources were moved to their floors in this integration
(`[12,0,18] → [9,0,18]`, `[0,0.5,6] → [-6.5,0,2]`, `[0,0.5,45] → [-7,0,45]`).
The Yard's was not touched and still carries the old `y = 0.5`.

**Player-facing impact.** Real but small, and it is not a mis-aimed flight.
`_construct` sets `pad.position = source`, so the pad's trigger box spans
world y 0.500–1.000 and its visible mesh floats **0.495 m above the floor**.
The capture then teleports the player to `stand_pose(0.5) = y 1.45` rather than
the y 0.95 a body standing on `yd_floor` occupies — a half-metre hop before
the launch fires. The arc itself is self-consistent, because validation and
runtime derive the same pose from the same wrong point, so the flight still
lands on target. A visibly floating pad and a half-metre jolt.

**Why the gate misses it.** `LaunchSolver` asks
`ground_below(source_foot, Constants.MAX_VERTICAL_STEP)` — ground within
**1.0 m**. That is a within-a-step check, not a contact check, so any source up
to a metre above its floor passes. The contract written into `content.py` in
this same commit says `position` *is* the foot-contact centre; the gate permits
1.0 m of daylight under it. The schema and the probe hold different views of
the same word.

**Ownership: shared handoff.** The authored position is Art's; the gate that
should have caught the mismatch is Production's, and it is Production's
contract text that the value contradicts.

**Blocks room promotion: no.** The Yard's shell measures 0/0, its mandatory
routes work, and the offer validates and lands correctly. It blocks the claim
that the launch-source contract is coherent *across the library*, not the room.

**Smallest correct follow-up.** Set `launch_west`'s `y` to `0.0` in the Yard
builder, and tighten `LaunchSolver`'s source-ground check from
`MAX_VERTICAL_STEP` to a contact tolerance so the gate enforces the sentence
the schema now carries.

**Tests it must leave behind.** One assertion that every `launch_source` and
`launch_target` in the library sits within a contact tolerance of the surface
below it, and a sabotage that lifts one by 0.5 m and expects a refusal —
today that sabotage passes silently.

## 5. Sabotage tests — THREE BITE, ONE IS NOT A TEST

Established by reading the assertions and reproducing their arithmetic; the
suites could not be executed here.

| Claimed | Verdict |
| --- | --- |
| Removing launch capture fails | **Bites.** `_test_a_launch_source_is_one_origin_not_a_disc` asserts `player.global_position.distance_to(canonical) < 0.001` after `launch()`. Without the capture line a corner entrant sits at `half = 2.4/2 − 0.05 = 1.15` on both axes, i.e. **1.15 × √2 = 1.6263 m** away — matching Production's reported 1.63 m, and failing both the pose and the landing assertion. |
| Undersized launch reservation fails | **Bites.** The guard fires on `source_radius < PAD_REACH`; the test passes `1.0` against `1.697056` and asserts the message. Remove the guard and the array is empty and the assertion fails. |
| Blocked launch origin fails | **Bites.** The rig's `lid` at `(0, 1.2, 0)` size `(3, 2, 3)` spans y 0.2–2.2; the canonical body pose is y 0.95 with a capsule spanning 0.07–1.83, wholly inside it. The test asserts both `not origin_is_clear(...)` and that `launched` does not advance. Remove the `origin_is_clear` gate from `launch()` and the count advances. *(Minor precision note: the validator half asserts the message contains `"launch source"`, a substring shared with the "not on a surface" message. It passes for the right reason in this rig, but a more specific substring would be stronger.)* |
| **Old Art launch positions reproduce their refusals** | **NOT A TEST — see F-2.** |

### F-2 · Report row 10 is a manual observation, not a standing guard — **NEW FINDING**

**Code fact proven.** A repo-wide search finds **no test anywhere** that pins
the pre-repair launch positions — `[12, 0, 18]`, `[0, 0.5, 6]`,
`[0, 28.333, 10]` or `[0, 0.5, 45]`. The only occurrences of those values are
in content files, not assertions. The report's table row *"Old Art launch
positions reproduce their refusal — pass"* records something Production did,
not something the suite will keep doing.

**Player-facing impact.** None today. The exposure is that the four defects the
previous audit proved could all return without a single test going red.

**Why existing gates miss it.** There is no gate; that is the finding.

**Ownership: Production.** **Blocks room promotion: no.**

**Smallest correct follow-up.** One fixture holding the four old positions,
asserting each is refused and naming the collider — the plenum's especially,
whose target sat 4.0000 m inside `pl_machine`.

## 6. Offer-order independence — CORRECT BY CONSTRUCTION, UNGUARDED

**Code fact proven.** `consume` now accumulates a `plan` from `_rails` and
`_launches` and constructs only after every verdict is in; `_grapples`
validates and constructs nothing. So:

* all offers are judged against the authored room before any offer geometry
  exists — confirmed by reading `consume`: no `add_child` or `build_rail` call
  occurs before the `for item in plan` loop;
* a rail built earlier cannot cause a launch refusal, because no rail exists
  during judging;
* reversing the visit order cannot change a verdict, because each judge reads
  only `space` and the authored room;
* the Player is excluded via `SpaceProbe.is_placed_content`, alongside
  `ActivityElement` and the `DestructibleCover` group. This is a class check on
  the collider's ancestors, so it removes bodies that walked in and **cannot**
  remove room collision — room geometry is never parented under a `Player`.

That is the design working, and I could not construct an ordering that changes
a verdict. Two observations sit beside it.

### F-3 · Nothing tests the ordering property — **NEW FINDING**

**Code fact proven.** No test in the repository runs `consume` under two
different offer orders and compares verdicts. The ordering fix is real, but it
is guarded only by its own structure.

**Player-facing impact.** None today. If judging and building were ever
recombined — the exact regression this commit repaired — every suite would stay
green.

**Ownership: Production. Blocks promotion: no.**

**Smallest correct follow-up.** One test that calls `consume` on a live room
with `only = ["rail_route", "launch_source"]` and again with the two reversed,
and asserts identical `built`/`declined` sets. It is a handful of lines and it
pins the property the commit message argues for.

### F-4 · `OfferBinding.validate` is named for judging and also builds — **NEW FINDING**

**Code fact proven.** `OfferBinding.validate` returns
`MovementPackage.consume(...)`, which constructs. Calling it twice on the same
live root therefore judges the second time against geometry the first call
built — the same class of defect as the ordering bug, one level up.
`room_contract_driver.gd` already calls `validate_zone` twice on the same
`live["root"]` (lines 1327 and 1340); it is harmless there only because the
second call passes a grapple-only offer set.

**Player-facing impact.** None today: `ZoneController._validate_offers` is the
sole production caller and runs once per Zone.

**Why existing gates miss it.** Nothing asserts idempotency, and the one live
caller happens to be single-shot.

**Ownership: Production. Blocks promotion: no.**

**Smallest correct follow-up.** Either split a judge-only entry point from the
building one, or make `consume` refuse a root it has already built into. The
naming is the trap: a method called `validate` will eventually be called twice.

## 7. Hall 71 vs 73 — RECONCILED, with one claim narrower than reported

**Independently confirmed:** `shell_hall_transit.glb` carries exactly **71**
`-convcolonly` nodes, each of which the importer turns into one
`StaticBody3D` + one `CollisionShape3D`. That is the authored scope, and the
`.tscn` adds only `Marker3D` nodes, so it contributes no collision.

`_test_the_two_collider_counts_measure_different_things` is a genuinely
rigorous reconciliation: it walks every `CollisionShape3D` under the
instantiated root, attributes each by whether its owning scene ends in `.glb`,
asserts `authored == 71` and `authored + placed == 73`, asserts every
non-authored collider satisfies `SpaceProbe.is_placed_content`, and asserts
zero duplicate bodies keyed on class and name.

### F-5 · The two extra colliders are bounded, not identified — **MINOR FINDING**

**Code fact proven.** The test asserts the two extras are *placed content* —
i.e. an `ActivityElement`, a `DestructibleCover`, or a `Player`. The report
states specifically "a `DestructibleCover`" and "an activity element". That
1 + 1 split is **not** pinned by any assertion; only the total and the
placed-content property are. Since no `Player` is staged in that test the
report's reading is consistent, but a future composer change could alter the
mix and keep the test green.

Two smaller notes on the same test, neither a defect: the duplicate key is
`class|name`, and Godot auto-uniquifies sibling names, so it detects exact
collisions rather than every conceivable double-add; and
`SpaceProbe._shape_obstruction` caps `intersect_shape` at 8 results, so a real
blocker behind eight placed-content colliders would be missed — unreachable
today, with two placed items in the Hall.

**Player-facing impact:** none. **Ownership:** Production. **Blocks
promotion:** no. **Follow-up:** assert the two by class, one line each.

## 8. Repaired physical truth — ALL CONFIRMED

**Plenum collar holes are physically open.** Each collar is now 12 convex ring
wedges. Mesh volume **53.2124 m³** per collar equals the sum of its pieces'
hulls **53.2124 m³**, and both equal the analytic annulus **53.2125 m³** — the
28.80 m³ of invisible fill per collar, 86.40 m³ in total, is gone. A downward
ray on the machine axis and at r = 2.0 and r = 3.5 finds **nothing** at all
three collar heights; at r = 5.25 it lands on the real ring.

**Collar traversal endpoints stand on real ring geometry.** All three moved to
radius 5.25 and their `EDGE_INSET` probes land at r = 5.20 on named ring
wedges — `pl_collar_0_sec02`, `pl_collar_1_sec05`, `pl_collar_2_sec11` — at
exactly the declared heights. The player's stance fits at each; the machine no
longer blocks any of them.

**Rails avoid the previously proven intersections.** All four baked curves
clear every collider by 0.461–1.100 m against the 0.175 m the beam needs. The
Span's `rail_underdeck`, which drove 1.9801 m through both pylons, now clears
`sp_pylon_0` by 1.100 m; the Hall's `rail_helix`, which entered the east
gantry by 0.25 m and a ramp tread by 0.3894 m, now clears by 0.628 m; the
Plenum's `rail_descent`, which entered all three real rings by 0.1663 m, now
clears by 0.461 m.

**Relocated launch and grapple offers are usable.** The Plenum's
`launch_collar` moved off the machine axis — where it sat 4.0000 m inside
`pl_machine` — to `[-5.25, 11.333, 10.0]` on collar 2's band, and both ends now
have ground and admit a body. All 12 grapple anchors validate.

**Yard's approved height is intact:** `size` is `[85.2, 17.6, 52.0]`,
unchanged from `acbad8d`, floor at y = 0.000 and roof at 16.000–16.600.

**Span's one-way mid-span drop is intact:** `deck_to_basin` remains a `drop`
from y 14.0 to y 0.0, and the Span's entire traversal block is byte-identical
to `acbad8d`.

**Mandatory routes work without any optional offer.** With no offer geometry
constructed, every mandatory endpoint in all four rooms has ground:
Hall 9 segments, Plenum 12, Span 2, Yard 2 — **0 missing**.

**No recurrence of the topology defect:** 458 collider nodes across all 12
shells, **0 non-convex**.

## 9. Regression — RUN, with one count unreconciled

**Python: `1094 passed, 6 skipped, 0 failed`** in 58 s, via `make test`'s exact
command (`pytest -q` over the configured `testpaths`). All six skips are
environment-dependent and none is a failure: a missing `anthropic` package, and
five needing an Archipelago checkout or a built apworld.

### F-6 · The 1140 figure is not reproducible here — **REPORTING FINDING**

The report claims "1140 Python tests + 627 subtests pass"; a clean environment
collects 1100. The mechanism is identified: `apworld/tests/test_apworld.py`
(20 test functions) and `bridge/tests/test_claude_provider.py` (4) skip at
*module* level, so they collapse to one skip each rather than being collected,
and a full `make setup` environment would collect them. That accounts for most
of the gap but not all of it. **Zero tests fail either way**, so the
substantive claim holds; the number does not reproduce. Ownership: Production.
Blocks nothing. Follow-up: quote the count with the environment that produced
it, or quote passes and failures rather than a total.

**Godot: not executed here** — no engine binary. 17/17 suites exiting 0 is
Production's measurement and this audit neither confirms nor disputes it; the
individual assertions I could reach are analysed in §5 and §7.

**Not independently verified** (no engine or bridge fixtures available): the
`6e8d83d0f3ec088b` digest, `make baseline` byte-identity, and the packet gate.
**Independently verified:** review states are unchanged — all four Wave-1 rooms
still `pending`, the eight P2 shells still `pass`, nothing promoted.

## 10. Gameplay-consumer adjudication

The distinction Production draws is correct, and it is worth stating in three
separate answers rather than one.

### A. Does the missing gameplay consumer invalidate any claim that the offer contracts and runtime nodes are technically correct?

**No.** The technical claims do not rest on a shipped consumer and never did.
`OfferBinding` is a real production caller that passes a real
`PhysicsDirectSpaceState3D`; the launch tests instantiate a real `Player`, a
real `LaunchPad` and real `StaticBody3D` colliders in the tree and wait real
physics frames. I independently reproduced the geometric half of it — 24 of 24
offers, against imported collision, using Production's own logic — with no
engine at all. Evidence that was never derived from gameplay is not weakened by
gameplay's absence.

**One carve-out, precisely.** The capture path is proven by direct invocation
(`pad.launch(player)`) and by `body_entered` firing in the rig. It is not
proven under live player input: the rigs set `input_frozen = true` and place
the body by assignment. So "the runtime node is contract-correct" holds; "the
runtime node is correct under a player who walks onto it while moving" is not
established. That is a narrow gap, and it is a gameplay-milestone gap, not a
contract gap.

### B. Does it block promotion of the four room shells, given that their mandatory routes work without optional offers?

**No.** I verified the premise rather than accepting it: with zero offer
geometry constructed, all 25 mandatory segments across the four rooms have
ground at both endpoints, and all four rooms measure 0 findings on surfaces,
sockets and traversal. A room shell's promotion turns on whether the shell is
physically what it claims to be, and all four are. An optional offer that no
package consumes cannot make a mandatory route less true.

### C. Does it instead block only the claim that rails and launches are currently player-facing in an ordinary generated Zone, and therefore the Playtest-3 gameplay milestone?

**Yes — and that is exactly where the blocker belongs.** No shipped Zone builds
a rail or a launch from an authored offer: all four rooms that declare offers
are `review: pending` and out of the catalog, and the eight catalog shells
declare none. `ZoneController._validate_offers` logs verdicts and constructs
nothing a player meets. So no player has ridden an authored rail or stood on an
authored pad, and no amount of test evidence changes that. The Playtest-3
gameplay milestone is blocked; the shells are not.

**The line to hold:** everything in §§2–8 is *technically validated by
real-physics integration tests*, and none of it is *currently exercised by
shipped gameplay*. Both statements are true, and neither substitutes for the
other.

## 11. Promotion readiness, per room

| Room | Physical truth | Offers | Verdict |
| --- | --- | --- | --- |
| `shell_hall_transit` | structural 0 / measured 0 | 6 / 6, rail clears 0.628 m | **READY for owner review** |
| `shell_plenum_helix` | structural 0 / measured 0 | 6 / 6, collar repair verified exact | **READY for owner review** |
| `shell_span_basin` | structural 0 / measured 0 | 6 / 6, rail clears 1.100 m, one-way drop intact | **READY for owner review** |
| `shell_yard_gantry` | structural 0 / measured 0 | 6 / 6, rail clears 0.925 m, approved height intact | **READY for owner review**, carrying F-1 |

F-1 does not block the Yard's shell: the room measures true and its mandatory
routes work. It should be fixed before anything relies on `launch_west`, and
before the launch-source contract is described as coherent library-wide.

Promotion remains the owner's decision. Nothing here promotes anything.

## 12. Remaining blockers

**For room promotion: none.** All four rooms are physically true on their own
geometry.

**For the Playtest-3 gameplay milestone: one.** No gameplay consumer builds an
authored offer in a played Zone, and none of the four rooms is in the catalog.

**Open items, none blocking promotion:**

| # | Finding | Owner | Follow-up |
| --- | --- | --- | --- |
| F-1 | Yard `launch_west` sits 0.5000 m above its floor; the gate allows 1.0 m where the contract says contact | shared | move it to y = 0; tighten the source-ground check to a contact tolerance |
| F-2 | "Old Art launch positions reproduce their refusal" is a manual observation, not a test | Production | one refusal fixture holding the four old positions |
| F-3 | No test pins offer-order independence | Production | one test running `consume` under both orders |
| F-4 | `OfferBinding.validate` builds as well as judges, and is not idempotent | Production | split judge-only from build, or refuse a second build |
| F-5 | The two extra Hall colliders are asserted as placed content, not identified | Production | assert the two by class |
| F-6 | The 1140 Python-test figure does not reproduce (1094 pass, 0 fail, 6 skip) | Production | quote the count with its environment |

---

**Summary.** Every substantive claim in the audit's scope measures true. The
provenance is faithful, all four rooms measure 0/0, all 24 offers build against
real imported collision with real margins rather than boundary luck, the collar
repair is exact to 0.0001 m³, all three previously proven rail intersections
are gone, the launch target that sat four metres inside a machine is on a ring
band, and the 71/73 question is properly closed. The ordering fix is sound.

What this audit adds is one authored value that contradicts the contract
written in the same commit (F-1), and four places where a correct behaviour is
currently guaranteed by its own structure rather than by a test that would go
red if it stopped being true (F-2 to F-5). None blocks a room. All are small.
