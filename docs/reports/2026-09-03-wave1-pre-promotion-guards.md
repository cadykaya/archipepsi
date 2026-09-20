# PROD — Wave-1 Pre-Promotion Guard Closure

**Archipepsi Production lane · 2026-09-03**

Head before: `833fe80`. Art sync: `466fd4e`. Independent audit: `f97545f`.
All six findings closed. **The four Wave-1 rooms are promotion-ready and
still `review: pending`.** Nothing was promoted.

---

## 1. Art sync — F-1's authored half

Synced through the established mirrored handoff; no Art branch history was
merged. `466fd4e` touches four files, three of which are Art-lane-only
(`manifest.json`, `build_yard.py`, `verify_manifest.py`). The single
Production-visible path is `godot/content/registry/authored_art.json`, and
the diff is **one value**:

```
shell_yard_gantry / launch_west   position[1]: 0.5 → 0.0
```

Confirmed by a field-by-field walk of the whole Yard entry: exactly one
leaf changed. `x = -28.0`, `z = 26.0`, `radius = 3.0` and
`target = launch_catwalk` are untouched. `size` is still
`[85.2, 17.6, 52.0]` (the approved ~16 m height), traversal is unchanged,
and the other three shells' entries are byte-identical.

> Art's head has since moved past the requested commit to **`f2b920a`**,
> which adds only `docs/art/reports/2026-09-03-yard-launch-pad.md`. I
> synced from `466fd4e` as instructed.

---

## 2. F-1 — a launch endpoint is a contact point, and it is checked as one

`LaunchSolver` asked `SpaceProbe.ground_below(..., Constants.MAX_VERTICAL_STEP)`
for both endpoints. That is *ground within a metre* — a step check wearing a
contact check's name — while `content.py` says both positions **are** the
foot-contact centre. The schema and the probe held two views of one word, and
a pad hovered half a metre over its floor through every gate in the project.

Replaced with `LaunchSolver.off_surface`, which does what the ruling asks:
**compare the declared world-space foot height with the surface actually
hit**, at `SpaceProbe.CONTACT_EPS` (0.001 m) and nothing wider. A separate
named reach (`CONTACT_REPORT_REACH`) is used only to make the message name
the surface and the gap — `"no ground within 1.0 m"` sent people looking for
a missing floor when the floor was 0.5 m down. Body-fit checks are unchanged
and still independent, so a buried endpoint is still refused by the check
that can name the solid it is inside.

The schema text now states the tolerance rather than implying it, mirrored
to the v0.9 packet.

**Tests (all in `room_contract_driver.gd`):**

| Required | Result |
| --- | --- |
| all eight Wave-1 endpoints within contact tolerance | 8/8, gap 0.0000 m |
| translation / vertical / yaw / nesting preserve the result | 7 placements + a nested wrapper, per room |
| lifting a valid **source** by 0.5 m is refused | 4/4 |
| lifting a valid **target** by 0.5 m is refused | 4/4 |
| the Yard's old `y = 0.5` fails | refused, naming `yd_floor` and `0.5000 m` |
| a point exactly on its floor passes deterministically | 16 repeats per endpoint, identical answers |

Rooms are staged **one at a time**. The first draft staged all four at the
origin and they overlapped: the Hall's arc was refused on `yd_roof` and the
Plenum's landing on `sp_roof`. A fixture sharing a space with a room it is
not about measures the wrong room.

---

## 3. F-2 — the four repaired positions are now a standing fixture

`REPAIRED_LAUNCHES` puts each old value back into the room the art lane
actually shipped — one field changed, everything else as authored — and
requires the specific physical refusal, not "something failed".

| Room | Offer | Old value | Required reason |
| --- | --- | --- | --- |
| Hall | `launch_basin` (source) | `(12, 0, 18)` | `the arc is obstructed` |
| Plenum | `launch_floor` (source) | `(0, 0.5, 6)` | `floats 0.5000 m over pl_floor` |
| Plenum | `launch_collar` (**target**) | `(0, 28.333, 10)` | `is inside pl_machine` |
| Span | `launch_basin` (source) | `(0, 0.5, 45)` | `floats 0.5000 m over sp_basin` |

All four reproduce. The Plenum target is the one that sat 4.0 m inside the
machine, and the refusal names `pl_machine`.

---

## 4. F-4 — validation must not construct gameplay (owner ruling)

`OfferBinding.validate` returned `MovementPackage.consume`, which builds. So
the one thing `ZoneController` did with a live Zone — check it — put a pad
and a beam into every room that offered one, as a side effect of something
named validation. Promotion would have activated every offer by accident,
and a second `validate` would have judged them against the first call's own
output.

**Split, with different words for different facts:**

| | reports | builds | who calls it |
| --- | --- | --- | --- |
| `MovementPackage.judge` / `OfferBinding.validate` | `accepted / declined / refused` | nothing, ever | `ZoneController._validate_offers`, every gate |
| `MovementPackage.consume` / `OfferBinding.construct` | `built / declined / refused` | judged-valid offers only | **nothing shipped** |

`consume` judges first, so it can only build what was already accepted
against the room as authored. A second construction into the same root is
**refused by name** rather than silently doubling the room. Nothing is
called "built" unless a node was made — a `grapple_point` is accepted and
constructs nothing, because there is no grapple mechanic to construct.

Idempotency is measured on a live instantiated room: node count, collider
count and offer-node count before and after one validation, then two, then
the explicit construction, then a refused second construction.

No shipped gameplay caller was invented. The Zone-level path is asserted to
build zero offer nodes, behaviourally, in the exact shape
`ZoneController` hands it.

---

## 5. F-3 — order independence, as behaviour

The property, stated as a property: **a verdict on one offer does not depend
on which other offers were asked about.** Measured on the Hall, whose launch
arc grazes its own rail beam by 0.35 m — the pair that actually collided.

* rail alone + launch alone == rail-and-launch together
* `["rail_route", "launch_source"]` == `["launch_source", "rail_route"]`
* the manifest's `offers` array reversed == forwards
* six validations changed the Hall's node count by **0**
* a vacuity guard: an empty accepted set fails, so this cannot pass by
  comparing two empty answers

---

## 6. F-5 — the two extra Hall colliders, by class

The audit was right that the 1+1 split was never asserted. Asserting it
showed **the previous Production report's second half was wrong.**

```
hall colliders: authored(shell mesh)=71 placed(composer)=2 instantiated(total)=73
hall placed colliders: DestructibleCover=2 ReactiveBarrel=0 ActivityElement=0 Player=0
```

Both extras are `DestructibleCover`, not "a destructible cover and an
activity element". The Hall declares **three `cover` sockets and no
`reactive` socket**; `_build_environment` places one crate per socket and
drops any whose box lands on occupied space, so three sockets become two
crates. The socket counts are asserted too, so 2 has a cause rather than
being a constant. Provenance and duplicate-body assertions are unchanged.

A group check would have read this as "two covers" for the wrong reason:
`DestructibleCover.GROUP` is `environment_objects`, which `ReactiveBarrel`
also joins. The assertion asks the class.

---

## 7. F-6 — the counts, with the environment that produced them

**This container**, `make setup` complete — Python 3.11.15, pytest 9.1.1,
`anthropic` 1.1.0 installed, `.archipelago` checkout present, apworld built:

```
collected 1140 | passed 1140 | failed 0 | skipped 0 | 627 subtests passed
```

The audit's 1100 collected / 1094 passed / 6 skipped is **not a
disagreement**, and it reconciles exactly:

| environment | collected | passed | failed | skipped |
| --- | --- | --- | --- | --- |
| everything present (here) | 1140 | 1140 | 0 | 0 |
| no Archipelago checkout (measured here) | 1103 | 1098 | 0 | 5 |
| no checkout **and** no `anthropic` (the audit's) | 1100 | 1094 | 0 | 6 |

Environment-dependent modules: `apworld/tests/test_apworld.py` (38 tests,
collapses to one module-level skip), `apworld/tests/test_packaging.py`
(1 test, needs a built `.apworld`), `bridge/tests/test_claude_provider.py`
(4 tests, `importorskip("anthropic")`), and three tests in
`bridge/tests/test_bridge.py` and `test_packaging.py` that skip without the
checkout. **Zero failures in every configuration.**

---

## 8. The offer census — two scopes, each unambiguously named

```
shell_hall_transit    declared=6 accepted=5 built=2 declined=0
shell_plenum_helix    declared=6 accepted=5 built=2 declined=0
shell_span_basin      declared=6 accepted=5 built=2 declined=0
shell_yard_gantry     declared=6 accepted=5 built=2 declined=0
offer census: declared=24 judged=20 constructed=8 declined=0
```

* **DECLARED — 24.** What the manifests contain: 6 per room (1 `rail_route`,
  1 `launch_source`, 1 `launch_target`, 3 `grapple_point`).
* **JUDGED — 20.** Verdicts returned by pure validation. A launch **pair**
  is one verdict that measures two authored points, so the four
  `launch_target` entries are measured inside their source's verdict rather
  than appearing as verdicts of their own. `24 = 20 + 4` is asserted.
* **CONSTRUCTED — 8.** Nodes that exist afterwards: 4 rails + 4 pads. The
  12 grapple points are accepted and construct nothing. `8 = 20 − 12` is
  asserted.
* **DECLINED — 0**, in every scope.

Reporting one number for all three is how two counts of one thing start
disagreeing, so all three are printed by the suite.

---

## 9. Recertification

| Item | Result |
| --- | --- |
| Four Wave-1 rooms, structural / measured | **0 / 0** each (Hall, Plenum, Span, Yard) |
| All twelve authored shells | 0 / 0, 0 refused |
| Offers accepted by pure real-physics validation | 24 declared / 20 judged, **0 declined** |
| Offers constructible through the explicit path | all accepted offers, **0 declined**, 8 nodes |
| Offers constructed by shipped gameplay | **zero** — asserted on the live Zone path |
| Mandatory routes with zero offer geometry | intact; validation now builds nothing at all |
| Godot suites | **17 / 17 exit 0** |
| Python | 1140 passed, 0 failed, 627 subtests (env above) |
| Packet / schema gate | clean — 11 documents, 949 identifiers |
| `make baseline` | byte-identical |
| Played Zone | `6e8d83d0f3ec088b` — 23 rooms, 15 Checks, 922 points, 35 enemies |
| Catalog / review states | unchanged — 14 `pass`, 7 `pending` |
| Yard height | `[85.2, 17.6, 52.0]`, unchanged |
| Span one-way drop | `deck_to_basin`, y 14.0 → 0.0, unchanged |
| New GDScript warnings | none |

---

## 10. Every guard proven by sabotage

| Sabotage | Result |
| --- | --- |
| contact tolerance widened back to `MAX_VERTICAL_STEP` | **11 red**, including the Yard's old value and both hover cases |
| F-2 fixture given the *repaired* value instead of the old one | **red** — "was ACCEPTED"; the fixture measures the real room |
| judging and construction recombined in one pass | **11 red** — "six pure validations changed the hall from 174 nodes to 224"; "the hall's rail and launch were accepted `[rail_helix]` separately and `[]` together" |
| `validate` returns `consume` again | **17 red** |
| once-per-root construction guard removed | **red**, and the second construction declined both offers against beams the first one had built |

Each was run, observed red, and restored.

---

## 11. Corrections to my own previous report

1. The Hall's two composer colliders are **two `DestructibleCover`s**, not
   "a destructible cover and an activity element".
2. "24 offers built" conflated three different counts. They are 24 declared,
   20 judged, 8 constructed.
3. "1140 Python tests" was true here and not reproducible in a clean
   checkout. Quoted with its environment from now on.

---

## 12. Status

**Four Wave-1 rooms: promotion-ready, `review: pending`.** Promotion is the
owner's decision and this task does not take it.

Still open and unchanged, deliberately: no gameplay movement package
consumes an authored offer in a played Zone, so no player has ridden an
authored rail or stood on an authored pad. That blocks the Playtest-3
gameplay milestone; it does not block the shells, whose mandatory routes
work with zero offer geometry.

Non-scope: Wave 2, unstarted.

> **Correction, 2026-09-04.** An earlier draft of this line also recorded the
> Plenum's annular collar convex disc as unresolved. That was stale when it
> was written. Art `468125e` decomposed all three collars into twelve convex
> ring sectors each; the independent audit at `f97545f` verified the volume
> and the topology — mesh 53.2124 m³ per collar equals the sum of its pieces'
> hulls and the analytic annulus to 0.0001 m³, downward rays on the machine
> axis and at r = 2.0 and r = 3.5 find nothing at all three collar heights,
> and 458 collider nodes across all twelve shells contain **zero non-convex**
> geometry. The holes are physically open. Nothing about the collar is
> outstanding.

*No heartbeat is armed. The Wave-1 guard list is closed and CI is green, so
the next task should start by turning the trigger back on.*
