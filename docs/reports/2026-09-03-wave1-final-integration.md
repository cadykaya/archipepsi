# PROD — Wave-1 Final Integration + Launch-Source Contract

**Archipepsi Production lane · 2026-09-03**

| | |
|---|---|
| Head before | `acbad8dcf1ff80ecfb9db584ad50e43db90345d9` |
| Art head synced | `468125ed8ef1f68e020406b63b3a7abe35528242` |
| Audit reference | `802732d35d155833ea30c515d4aaa5d4449580fb` |
| Branch | `claude/archipepsi-echoes-continuation-b1adno` |

---

## 1. Art state synced

Four mirrored files, byte-identical to Art `468125e`: `SCENE_PLAN.json`,
`registry/authored_art.json`, `shells/shell_plenum_helix.glb`,
`shells/shell_plenum_helix.tscn`. Nothing else in the tree came from the Art
lane, and no branch history was merged.

Authored changes carried, verified per room:

| Room | Change |
|---|---|
| Plenum | collars decomposed into convex ring wedges (colliders 119 → 152); `launch_collar` `(0, 28.33, 10)` → `(-5.25, 11.33, 10)`; `launch_floor` `(0, 0.5, 6)` → `(-6.5, 0, 2)`; `grapple_1` `(7, 38, 10)` → `(6, 38, 10)`; all three collar traversal endpoints moved onto the ring band; rail re-routed |
| Hall | rail control points re-routed; `launch_basin` `(12, 0, 18)` → `(9, 0, 18)` |
| Span | `rail_underdeck` re-routed; `launch_basin` `(0, 0.5, 45)` → `(-7, 0, 45)`, floor y corrected to 0 |
| Yard | unchanged |

All four remain `review: pending`.

## 2. Launch-source semantics

**`launch_source.position` is THE canonical room-local foot-contact centre the
constructed launch fires from — one point, not a choice of points.**

**`launch_source.radius` is the region RESERVED** for the consuming movement
package to build its mechanism in. It is not a disc of ballistic starting
positions, so Production validates **one** trajectory rather than a family of
them, and the thing that must fit inside the reservation is the pad's own
footprint (`PAD_REACH` = 1.697 m from centre).

`launch_target.position` stays the authored foot-contact **aim**;
`launch_target.radius` stays the acceptable **landing region**. The asymmetry is
deliberate: *where you leave from is exact, where you arrive is a region.*

Written into `bridge/archipepsi_bridge/schemas/content.py` (and the v0.9 packet
copy, which is the contract) so the two ends cannot silently converge again.

The Art pads at Hall `(9, 0, 18)` and Span `(-7, 0, 45)` were **not** moved
farther on account of their 3.0 m radius.

## 3. Runtime capture behaviour

`LaunchPad.solve()` derived velocity from the pad centre while `launch(player)`
applied it to whoever happened to be overlapping the trigger — so a player
clipping the edge of a 2.4 m pad flew a trajectory beginning up to 1.2 m from
the validated one and landed somewhere nobody checked.

Now, in order:

1. `solve()` — world body-pose → world body-pose, the same poses the validator used.
2. `origin_is_clear(rider)` — the canonical pose must hold a body, excluding the rider's own collider. **A blocked origin refuses to fire** rather than teleporting the player into geometry.
3. `player.global_position = _body_pose()` — captured to the canonical origin.
4. velocity applied.

Entering at the centre, any edge, or any corner produces the identical arc.

## 4. Launch-contract test results

All exercise the real `Player`, the real `LaunchPad`, a real physics space and
the authored-room instantiation path.

| # | Proof | Result |
|---|---|---|
| 1 | `position` is the canonical origin | pass |
| 2 | `radius` is a reservation, not a family of origins | pass — one trajectory validated |
| 3 | The constructed pad fits its reservation | pass; a 1.0 m reservation is refused for a 1.70 m pad |
| 4 | Centre entry follows the validated trajectory | pass |
| 5 | Nine edge/corner entries captured to one origin | pass, all nine |
| 6 | Removing the capture fails the test | **red** — edge entry lands 1.63 m off |
| 7 | Capture pose capsule-safe; blocked origin refused | pass — pad does not fire, validator agrees |
| 8 | Correct under translation, Y, yaw 90/180/270, nested, ZoneBuilder chain | pass |
| 9 | Hall and Span use the same arc validation approved | pass |
| 10 | Old Art launch positions reproduce their refusal | pass |

## 5. Hall 71 vs 73 — reconciled

**They were never the same question.** Both counts are correct.

| Scope | Count | What it measures |
|---|---|---|
| **Authored shell colliders** | **71** | `-convcolonly` twins the importer builds from `shell_hall_transit.glb`. What an art-side gate can see. |
| **Instantiated chamber colliders** | **73** | Everything in the room after `build_chamber` returns. |

The extra two are **composer-placed content**, not authored shell collision and
not importer-generated:

1. a `CollisionShape3D` under a `DestructibleCover` (StaticBody3D)
2. a `CollisionShape3D` under an activity element's StaticBody3D

**Neither count concealed duplicate or unintended geometry** — zero duplicate
bodies in either scope. Both are now asserted by name in
`_test_the_two_collider_counts_measure_different_things`, so neither can drift
into the other.

## 6. Per-room results

Structural / measured from `RoomAudit`; offers from `OfferBinding.validate`
through the real physics space.

### Hall — `shell_hall_transit`
`structural=0 measured=0` · authored colliders **71** · instantiated **73** ·
12 surfaces · 12 traversals (9 mandatory / 3 optional) · 21 sockets

| Offer | Kind | Result |
|---|---|---|
| `rail_helix` | rail_route | **BUILT** |
| `launch_basin` | launch_source | **BUILT** |
| `launch_gantry` | launch_target | **AVAILABLE** (validated in the pair) |
| `grapple_0` | grapple_point | **BUILT** |
| `grapple_1` | grapple_point | **BUILT** |
| `grapple_2` | grapple_point | **BUILT** |

Optional collar traversal, mandatory route, stair/plinth/marker fixes all clean.

### Plenum — `shell_plenum_helix`
`structural=0 measured=0` · instantiated colliders **152** (was 119; the collar
decomposition) · 20 surfaces · 15 traversals · 28 sockets

| Offer | Kind | Result |
|---|---|---|
| `rail_descent` | rail_route | **BUILT** |
| `launch_floor` | launch_source | **BUILT** |
| `launch_collar` | launch_target | **AVAILABLE** |
| `grapple_0` / `grapple_1` / `grapple_2` | grapple_point | **BUILT** (all three) |

The three collar endpoints that Production detected independently of the hull
are now real destinations; `grapple_1` is usable; collar holes physically open.

### Yard — `shell_yard_gantry`
`structural=0 measured=0` · instantiated colliders **43** · geometry height
**17.60 m** (the approved ~16 m form) · unchanged by this Art commit.

`rail_crane`, `launch_west`, `launch_catwalk`, `grapple_0..2` — **all BUILT /
AVAILABLE**.

### Span — `shell_span_basin`
`structural=0 measured=0` · instantiated colliders **57** · retains
`deck_to_basin`, a one-way `drop` from y=14 to y=0.

`rail_underdeck`, `launch_basin`, `launch_deck`, `grapple_0..2` — **all BUILT /
AVAILABLE**.

### Totals
**24 offers measured, 0 refused, 0 raised.** Independently reproduced by
Production's runtime geometry binding.

## 7. An ordering defect found and fixed

`MovementPackage.consume` validated and constructed in one pass, so the rail was
**built** before the launch was **judged** — and the Hall's arc collided with the
beam Production had just added. The same launch passed on a freshly built room.

The verdict depended on which offer kind `consume` happened to visit first: run
launches before rails and the launch passes while the rail might fail instead.
**An answer that changes with iteration order is not an answer.**

Judging is now a separate phase from building. An offer is a claim about the
**room**; what another package chose to build in it is not part of that claim.

Also corrected: the Player is no longer treated as room geometry. A probe
reporting *"their body is inside Player"* was true and useless.

## 8. Regression

- 17/17 Godot suites exit 0
- 1140 Python tests + 627 subtests pass
- Packet gate green (the schema doc change was reconciled into the v0.9 packet copy, which is the contract)
- Eight approved P2 shells: `structural=0 measured=0`
- Digest `6e8d83d0f3ec088b` — 23 rooms / 15 Checks / 922 points — **unchanged**
- `make baseline` byte-identical
- Catalog unchanged at the eight approved P2 shells
- All four Wave-1 rooms `review: pending`, none offerable
- Entry-connector chaining and `player_entry` safety clean
- Authored-local → physics-world invariant holds under real Zone placement
- No new warnings

## 9. Remaining caveats

1. **`MovementPackage` still has no gameplay consumer.** `LaunchPad` and
   `RailRider` are frame-correct and contract-correct, but no shipped Zone builds
   a rail or a launch from an authored offer, so the runtime is proven by test
   rather than by play.
2. **Wave-1 rooms are not in the played Zone.** All four remain `pending` and
   out of the catalog, so none of this reaches a player yet.
3. **`PAD_REACH` is a literal** (1.697) rather than derived from `PAD_SIZE` at
   compile time — GDScript will not fold a `sqrt` into a `const`. A test pins the
   relationship.

## 10. Promotion readiness

**Ready for one bounded independent audit.** Nothing was promoted, no review
state changed, Wave 2 unstarted.

Every claim in the audit's scope now measures true under Production's own
canonical binding: all four rooms `structural=0 measured=0`, all 24 offers
measured with 0 refused, the 71/73 question closed with both scopes named, and
the launch-source contract written into the schema.

The two open items an auditor should weigh are the ordering defect this pass
found in Production's own validator — fixed here, but it means every offer
verdict before this commit was order-dependent — and the absence of a gameplay
consumer for the movement package.
