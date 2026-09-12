# 09 — THE ROOM CONTRACT

**STATUS: DRAFT FOR INTERFACE REVIEW. Not agreed, not implemented.**

The seam between the bridge and the engine for multi-door rooms. It exists so two lanes can implement in parallel without either guessing what the other guarantees, and it is the one artefact neither lane should write alone.

**Engine-lane review:** returned `2026-09-12` against `cb3bf64` — changes requested; see `docs/reviews/2026-09-12-room-contract-prod-review.md`. **All six corrections are taken**, and §10 records what each changed.
**Pinned against:** Production `c8ed2e9`, engine slice `82d500f`, and `06_THE_AMALGAM.md` §4.9a, §30.11.2b, §30.11.2e, §30.12.
**Not covered:** anything outside the multi-door seam. §9 lists what this deliberately omits.

---

## 1. The rule that shapes everything else

> **There is exactly one physical-placement implementation, and it is the engine's.**

The bridge owns the **graph** — which rooms exist, which edges join them, which socket serves which edge, what is locked and by what key. The engine owns **world coordinates** — where each room actually goes, whether the bodies fit, whether the capsule passes.

`zone_builder.gd:4` already states this: *"Epsilon never chooses world coordinates; this file owns them."* The contract extends the boundary rather than moving it. A placement solver in the bridge would be a second implementation of the engine's own geometry, and two implementations of the same geometry disagree eventually, at the worst possible time, with neither obviously wrong.

**What the bridge does instead of solving:** it *commits* what the engine reports, and it *measures* the result against stated constraints. Measuring a returned layout is a different computation from producing one, so it is not a second implementation.

**Three layers, and the reason they are separated:** they have different lifetimes, different authors, and different failure modes. Conflating any two is how a catalog change silently invalidates a save.

| Layer | Lifetime | Written by | Read by |
|---|---|---|---|
| **1 — Shell capacity** | the life of the shell in the catalog | authoring (Art) | both lanes |
| **2 — Room-instance assignment** | the life of one composed Zone | bridge | engine |
| **3 — Persistent progress** | the life of the campaign save | engine, via intents | both lanes |

---

## 2. Layer 1 — Shell capacity

**Static, authored, per shell.** Neither lane writes this at runtime. It is what a shell *can* do; Layer 2 is what one room instance *does* with it.

```
ShellCapacity:
  shell_id        : ShellId                 # catalog key, stable forever
  envelope        : AABB                    # the body, room-local
  sockets         : list[SocketCapacity]
  catalog_digest  : Digest                  # the snapshot this came from

SocketCapacity:
  socket_id       : SocketId                # STABLE — see 2.1
  kind            : SocketKind              # DOORWAY | CORRIDOR_END | <non-joining>
  transform       : Transform               # room-local attachment frame
  outward         : Vector3                 # which side of the frame is "out"
  aperture        : Aperture | null         # required iff kind is joining
  collar          : CollarId | null         # required iff kind is joining
  player_entry    : VolumeRef | null        # required iff kind is joining

Aperture:
  width, height   : float                   # the opening itself
  sill            : float                   # height of the opening's base
```

### 2.1 Socket ids are stable, and production already satisfies it

> **A `socket_id` identifies one opening for the life of the shell.** It is never reused for a different opening, and changing one is a `catalog_digest` change (§30.11.5 class 6).

**A previous revision claimed this needed a migration. It does not, and the claim was measurably false.** `entry` and `exit` are opaque stable ids that happen to read positionally; `content_instantiator.gd` resolves each through a two-name alias set — `entry`/`end_a` at `:676`, `exit`/`end_b` at `:704` — so neither is treated as an ordinal. **A shell gaining a third opening gets a third id and the existing two keep their meaning. No rename, no alias table, no shell rebuild.**

The same revision cited `RoomContract.LEGACY_ENTRY` as precedent for migrating named ids. It is the opposite: it is the fallback used when a shell declares *no* entry socket at all, which is precedent for **positional defaults when a name is absent**.

**The real defect was adjacent and is the engine lane's.** Joining sockets were chosen *by name* rather than by assignment, and with N doors which opening serves which edge is the bridge's decision. `_entry_offset` and `_exit_offset` are replaced by one resolver taking a `socket_id` from the `DoorAssignment`, falling back to the legacy pair when no assignment is present — which is what keeps all twelve two-door shells composing unchanged **by construction rather than by promise**. Implemented at `82d500f` as `socket_by_id` / `socket_for_edge`.

### 2.2 The transform is not the aperture, and neither is the envelope

This is the distinction that broke `06_THE_AMALGAM.md` §30.11.2d, and it is stated here so no implementation re-derives the error:

| Field | Is | Is not |
|---|---|---|
| `transform` | the room-to-room **attachment frame** | a point on the envelope, and **not** a place with floor under it |
| `aperture` | the **opening** the player passes through | the clear volume around it |
| `collar` | the **standardized clearance** around the aperture | any statement about either shell's body |
| `envelope` | the shell's **body** | derivable from the sockets |
| `player_entry` | the **interior region the body arrives into** | the same point as `transform` |

**`shell_yard_gantry`'s entry transform sits `0.4 m` past its own west wall.** That is legal, intentional, and the reason `player_entry` exists as a separate volume. **Any predicate reading only `transform` knows nothing about bodies** — which is why Layer 2 cannot decide placement and §1's rule holds.

### 2.3 What Art must add, and what it need not

| | |
|---|---|
| **Must add** | a `player_entry` volume per joining socket. **That is Art's whole obligation for slice 1** |
| **Need not add** | additional doorways. **Every existing two-door shell remains valid and composes exactly as it does today.** A shell is offered to a room only when an injective assignment exists from the room's `JOINED` edges to its joining sockets (§30.11.2b), so a two-door shell is simply never offered to a three-door room |
| **Later, not now** | three-door and four-door authored shells. Slice 1 needs none |

---

## 3. Layer 2 — Room-instance assignment

**Per composed Zone. The bridge writes it; the engine reads it and never amends it.**

```
RoomAssignment:
  room_id         : RoomId
  shell_id        : ShellId
  doors           : list[DoorAssignment]

DoorAssignment:
  socket_id       : SocketId                # must exist in that shell's capacity
  usage           : USED | LOCKED | SEALED
  edge_id         : EdgeId | null           # required iff usage != SEALED, and the
                                            #   named edge must be JOINED; null iff SEALED
  key_id          : KeyId | null            # required iff usage == LOCKED; null otherwise

PlugAssignment:                             # a plug is NOT a door
  edge_id         : EdgeId                  # the TRAVERSAL_ONLY edge it carries
  room_id         : RoomId                  # the room the device stands in
  source_anchor   : AnchorId                # where the device is placed
  destination     : AnchorId                # where the player arrives
  device          : PlugKind                # from the authored plug catalogue

EdgeAssignment:
  edge_id         : EdgeId
  room_a, room_b  : RoomId
  direction       : BIDIRECTIONAL | A_TO_B | B_TO_A
  realization     : JOINED | TRAVERSAL_ONLY
  destination     : AnchorId | null         # required iff TRAVERSAL_ONLY
```

### 3.1 Three usages, three different geometric outcomes

| `usage` | Geometry | Passable | The audit must prove |
|---|---|:-:|---|
| `USED` | aperture carved | yes | **the opening is a hole** — the capsule sweeps through |
| `LOCKED` | aperture carved | once `key_id` is held | the opening is a hole, **and** the lock reads as a lock |
| `SEALED` | **procedural** — the aperture is never cut. **Authored** — a closure is placed over the existing aperture | no | **the opening is solid** — the capsule does *not* pass. The authored case **additionally** asserts the closure is a present node |
| *(a plug's destination)* | no aperture; a device | via the device | **the destination admits a standing capsule and has ground under it** |

**`SEALED` is two constructions, not one.** A procedural room declines to cut the opening. **An authored shell has no such option** — the opening is already in its mesh, so closure is a placed object over an existing aperture, with its own failure mode: a *missing* closure must not read as a pass. That is why the authored case asserts the node exists as well as running the probe.

> **`SEALED` inverts the audit; it does not skip it.** `_openings_are_holes` reports a blocked doorway as a defect. For a declared-`SEALED` door the same measurement runs with the **opposite expected answer**, and the expectation comes from the declaration rather than from the geometry.

**Skipping the check for sealed doors is the tempting shortcut and it is forbidden.** It would be a fourth instance of the recurring failure the playtest named — *a measurement exists, is correct, and is never handed the case that fails it.* A sealed door that is accidentally a hole is a shortcut past a lock; a sealed door correctly solid but unchecked is indistinguishable from it in the test report. **It must be checked harder, not less.**

### 3.2 `TRAVERSAL_ONLY` edges bind no geometry and carry full reachability

A return plug — a non-euclidean door, a rematerialisation pad, a tube that fades — moves the player between two rooms with nothing joining them spatially.

> **A `TRAVERSAL_ONLY` edge assigns no socket, meets no collar, and closes no loop. It participates fully in reachability, direction, and every predicate the model check reads.**

> **A `TRAVERSAL_ONLY` edge is carried by a `PlugAssignment`, never a `DoorAssignment`.** It consumes no joining socket, and a room's joining-socket budget is unaffected by how many plugs it holds.

> **Logical reachability includes return edges; physical joining checks apply to `JOINED` edges only.**

**A previous revision had invariant 4 give the plug a `DoorAssignment`, contradicting the paragraph above it.** A `DoorAssignment` *is* a socket assignment — its first field is `socket_id` — so a three-door junction with one plug would have been assigned four sockets and carved four apertures, and a two-door shell carrying a plug would have failed §30.11.2b's injective assignment outright, breaking §2.3's promise that every existing shell still composes. **The plug gets its own record because it is not a door.**

Consequences the engine lane should hold onto:

- A room's **door degree** is its `JOINED` degree. A dead-end room with one door and one plug has door degree `1`.
- **The plug's presence makes the graph cyclic and creates no spatial cycle.** Slice 1 has a graph cycle and nothing for the solver to close.
- `destination` is an **`AnchorId`** — a declared anchor such as the Zone start or the last large room — **never a coordinate.** The composer names anchors; the engine resolves them. `zone_builder.gd:4` holds verbatim.

### 3.3 Invariants the bridge guarantees before sending

The engine may assume all of these and should assert them anyway; a violation is `LAYOUT_REFUSED` (§6.3), not a placement failure.

1. Every `socket_id` in a `DoorAssignment` exists in that `shell_id`'s capacity.
2. No `socket_id` appears twice in one `RoomAssignment`.
3. Every `JOINED` edge is named by exactly two `DoorAssignment`s, one in each endpoint room, neither `SEALED`.
4. Every `TRAVERSAL_ONLY` edge is named by exactly one `PlugAssignment` and by **no** `DoorAssignment`. It carries a `source_anchor` in `room_id` and a `destination`.
5. Every `key_id` on a `LOCKED` door is obtainable without passing that lock — **`R ⊆ E` proves this before the send**, and it is the bridge's obligation, not a thing the engine can check.
7. Every `PlugAssignment`'s `source_anchor` and `destination` name anchors the engine can resolve. **Neither is a coordinate** — the composer says *which* anchor, the engine says *where*.
8. Every joining socket a room does not use is declared `SEALED`. **There is no fourth state and no default** — an unmentioned socket is a contract violation, because "unmentioned" is exactly how an unaudited hole gets into a wall.

---

## 4. Layer 3 — Persistent progress

**Per Zone record, across death, Hub return, and re-entry (§30.12.2).**

```
ZoneProgress:
  zone_id          : ZoneId
  collected_keys   : set[KeyId]
  opened_locks     : set[DoorRef]           # (room_id, socket_id)
  reached_stations : set[StationId]
  claimed_checks   : set[LocationId]
  resume_anchor    : AnchorId | null        # the only non-monotone field
```

**Every set is monotone and only ever grows within a Zone's life.** That is not a convenience — it is what makes a resume safe. A monotone progress set is §5.7's latch shape, so a reload cannot regress a player behind a door they opened, and the model check's `R ⊆ E` holds across a resume for the same reason it holds within a run.

`resume_anchor` is the exception and is a *position*, not progress: it is the station a player returns to, it is overwritten rather than accumulated, and losing it costs a walk rather than a run.

**Where it lives.** `ZoneRecord` in `bridge/…/schemas/protocol.py` — it already exists, already carries `zone_id`, `state` and `allocated_location_ids`, and already survives saves. `ZoneProgress` is a field on it, not a new subsystem.

**Progress is not layout.** The layout rebuilds from the manifest and is identical by construction (§30.11.2e). What a player *did* is separate, and conflating them is how a catalog change would appear to a player as a lost key.

### 4.1 The state this requires

`ZoneState` today is `PENDING_GENERATION | GENERATED | ACTIVE | COMPLETE | ABANDONED`, with `COMPLETE` and `ABANDONED` terminal and `enter_zone` accepting only `GENERATED` (idempotent on an already-`ACTIVE` Zone, and raising on anything else). **Re-entry is not currently representable.** §30.12.1 adds `DORMANT`, and `enter_zone` must accept it.

**This is the coupling in §30.12.3.** The exit may stop requiring every Check **only once `DORMANT` works** — the unlock is a two-line change and re-entry is a schema change, so shipping them in the easy order converts a forgone reward into a stranded one.

---

## 5. How the two sides communicate

Three exchanges. All extend the existing `BridgeClient` intent channel; none is a new transport.

### 5.1 Compose — bridge → engine, once per Zone

**Sends:** the `EdgeAssignment` list, one `RoomAssignment` per room, the `catalog_digest`, and the placement budget.
**Expects:** a `LayoutResult` (§6).

The engine solves placement, using its own geometry, its own `SpaceProbe`, and its own `origin_for` / `exit_cursor` seam primitives. **The bridge does not suggest transforms and does not check the solve by redoing it.**

### 5.2 Commit — engine → bridge, once per Zone

**Sends:** on `LAYOUT_OK`, the **whole layout** — room transforms *and* the connector and corner chain that reaches each of them, plus the measured evidence in §5.4.

**Bridge does:** validates the proposal, and **only a layout that passes §30.5 check 19e becomes the accepted immutable manifest.** A failing proposal is `LAYOUT_REFUSED` back to the engine lane and **never acquires a digest**. A previous revision had the bridge commit first and check afterwards, which publishes an unvalidated manifest.

> **Room transforms are not the layout.** `zone_builder.gd`'s `_emit_route` also places corner pieces and connector segments chosen by `_plan_route`'s search. A manifest holding only room transforms cannot rebuild the connecting geometry without re-running that search — and re-running it is exactly what this section promises never happens.

**An edge joins when its two endpoint sockets meet the two ends of its chain** within `EPSILON_JOIN`, and each consecutive pair within the chain meets within `EPSILON_JOIN`. For an empty chain the two sockets meet each other directly. **Socket-to-socket coincidence is the special case, not the rule** — two rooms linked by a connector chain do not meet each other's sockets at all, and a check comparing them would fail every non-adjacent pair in a Zone that composed correctly.

> **The layout is solved once and replayed forever.** Every later load uses the committed transforms and chains. This is how **Law 47c**'s determinism is obtained — *once a `ZoneManifest` exists, every save, load, replay and later retrieval of that Zone is byte-identical from the manifest* — without promising that two machines independently rediscover the same layout, which would be a claim about cross-platform floating point that nothing here can keep. **47a is bridge structural determinism before the model is consulted, and is a different property**; a previous revision cited it here by mistake.

### 5.3 Progress — engine → bridge, during play

Existing intent shape. `grant_local_reward` is the precedent: an id derived from identity rather than from the moment, so the same event twice is one event.

| Intent | Carries | Idempotent on |
|---|---|---|
| `key_collected` | `zone_id`, `key_id` | `key_id` |
| `lock_opened` | `zone_id`, `room_id`, `socket_id` | the `(room_id, socket_id)` pair |
| `station_reached` | `zone_id`, `station_id` | `station_id` |

**Every one is idempotent by identity, because every target set is monotone.** A duplicate is not an error and must never be reported as one; a resend after a dropped connection is the normal case.

---

### 5.4 Which side measures what

Without this division the obvious reading is that Python re-implements collision. **It must not.**

| Fact | Produced by | Means |
|---|---|---|
| room transforms, piece transforms, piece `bounds` | **Engine** | measured from the built scene |
| the capsule fits at every `player_entry` and every plug destination | **Engine** | `player_stands_here` / `_arrival_is_safe`, reported as a boolean per anchor with the anchor id |
| apertures are holes; sealed doors are solid | **Engine** | `_openings_are_holes`, both polarities |
| chain continuity within `EPSILON_JOIN` | **Bridge** | arithmetic on returned transforms |
| no two room envelopes intersect | **Bridge** | AABB arithmetic on returned `bounds` |
| every `JOINED` cycle closed | **Bridge** | arithmetic |
| digest, catalog match, invariant conformance | **Bridge** | schema |
| **logical** reachability — `R ⊆ E`, keys, Checks, return edges | **Bridge** | graph search |
| **physical** reachability — can a player actually walk there | **Engine** | see §5.5 |

> **The bridge never runs a shape query.** Everything requiring a physics world is measured in the engine and returned as evidence; the bridge checks arithmetic and identity on that evidence. Re-deriving a capsule result in Python would be a second derivation of a fact the engine owns.

### 5.5 Physical reachability is the engine's, and is not yet proved

`R ⊆ E` is a **graph** property over edges the bridge believes exist. It cannot see that a key stands inside a crate, on a ledge with no ramp, or behind a trim lip. **It is necessary and it is not sufficient, and a previous revision treated it as both.**

The engine lane proposed closing the gap with the walk flood added at `c8ed2e9` (`room_contract_driver.gd`, `_walk_reaches`). **Per owner direction of 2026-09-12 that flood is not authoritative**: it is a grid flood that permits one-metre step-ups the player cannot actually perform, which makes it a **structural diagnostic rather than a traversal proof**. A diagnostic that over-permits will pass a key the player cannot reach.

> **Physical reachability is Prod's to define and prove.** The bridge states the obligation, consumes the verdict, and **does not encode any particular flood as the proof.** Until a traversal proof exists that is faithful to the movement law, physical reachability is an **open gap** and is recorded as one — not silently satisfied by the nearest available measurement.

## 6. How failure is reported

**A typed result, never a boolean and never a bare error string.**

```
LayoutResult =
  | LAYOUT_OK          { rooms     : map[RoomId, Transform]
                       , links     : map[RoomId, list[PlacedPiece]]  # see 6.5
                       , anchors   : map[AnchorId, Vector3]
                       , arrival   : map[AnchorId, bool]             # engine evidence
                       , apertures : map[DoorRef, bool] }            # engine evidence
  | LAYOUT_TIMEOUT     { elapsed_ms, nodes_explored, candidates_remaining }
  | LAYOUT_INFEASIBLE  { exhausted : true
                       , policy    : RoutingPolicy                   # see 6.2
                       , blocking_rooms, blocking_pairs }
  | LAYOUT_REFUSED     { violation, room_id?, socket_id? }

PlacedPiece:
  kind      : CONNECTOR | CORNER
  transform : Transform          # world placement, as built
  bounds    : AABB               # world-space, as measured

RoutingPolicy:
  max_route_turns, explore_connectors,
  max_clearance_connectors, clearance_budget
```

### 6.1 A timeout is a timeout

> **`LAYOUT_TIMEOUT` says the budget was spent with candidates unexplored. It says nothing whatever about whether a layout exists.**

Reporting a timeout as impossibility lets a slow machine indict a sound design and sends a recomposable Zone down a terminal path. The two are routed differently and mean opposite things: **`LAYOUT_TIMEOUT` says the solver ran out of time; `LAYOUT_INFEASIBLE` says the geometry ran out of room.**

`candidates_remaining` is the field that keeps the distinction honest. A solver reporting a timeout with zero candidates remaining has in fact exhausted the space and should have said `LAYOUT_INFEASIBLE`; the bridge treats that combination as a contract violation rather than quietly reinterpreting it.

### 6.2 Only an exhausted search may claim infeasibility

`exhausted : true` is required, not decorative. **A solver that cannot distinguish exhaustion from expiry reports `LAYOUT_TIMEOUT`** — the honest answer and the conservative one.

`blocking_rooms` and `blocking_pairs` are what make the result actionable: they are what turns "this Zone did not compose" into a catalog review with room ids attached.

**And exhaustion is bounded, so the claim must be too.** The engine searches a declared routing policy — `MAX_ROUTE_TURNS`, `EXPLORE_CONNECTORS`, `MAX_CLEARANCE_CONNECTORS`, and a per-Zone clearance budget. Exhausting that space means *"no layout exists under these bounds"*, never *"no layout exists"*.

> **`exhausted: true` means the candidate space defined by the declared routing policy is empty.** `LAYOUT_INFEASIBLE` therefore **carries the policy it exhausted**, so a catalog review can see that widening the policy is an available response. **A bounded search may never report that a design is impossible.**

### 6.5 `links` is keyed by room, and that is a slice-1 accommodation

The contract wants `links` keyed by `EdgeId` — a chain realizes an *edge*, and in a branching graph two edges can reach the same room. **The engine at `82d500f` keys by chamber id**, because `_emit_route` walks a chain and "the chain that reaches this room" is unambiguous while the topology is a line.

> **The bridge accepts the room-keyed form and converts it, and the conversion is named rather than implicit.** It is sound only while each room is reached by exactly one chain, so the adapter **asserts that** and fails loudly the moment it stops holding. `EdgeId` keying is the target as soon as a room has two inbound `JOINED` edges.

### 6.3 `LAYOUT_REFUSED` is the bridge's bug, not the geometry's

Any §3.3 invariant violated — an unknown `socket_id`, a doubly-assigned socket, an edge with one endpoint, an unmentioned socket, a `catalog_digest` mismatch. **It is not a placement outcome and must never be retried**, because retrying identical invalid input is the definition of a loop. It escalates to the bridge lane with the violated invariant named.

### 6.4 What the bridge does with each

| Result | Bridge |
|---|---|
| `LAYOUT_OK` | **check 19e, then commit.** Only a passing layout acquires a digest |
| `LAYOUT_TIMEOUT` | one repair request for a combination with fewer large shells; then the offline selector; then `FAIL_ZONE`. **Never re-sends the identical request** — the search is ordered and would spend the same budget the same way. Logged as **performance** |
| `LAYOUT_INFEASIBLE` | the same escalation, logged for **catalog review** with the blocking rooms |
| `LAYOUT_REFUSED` | no retry. Hard error naming the invariant |

---

## 7. Implementation boundaries

| Owns | Lane | Files |
|---|---|---|
| Graph and schema — `TopologyEdge`, `realization`, `DoorAssignment`, `ZoneProgress`, `DORMANT`, migrations | **Bridge (Dess)** | `bridge/…/schemas/zone.py`, `bridge/…/schemas/protocol.py`, `bridge/…/schemas/transitions.py` |
| Logical reachability — `R ⊆ E` including `TRAVERSAL_ONLY` edges; key obtainable without passing its own lock | **Bridge (Dess)** | the verifier; `bridge/…/epsilon/` offer construction |
| Commitment and measurement — manifest, `manifest_digest`, check 19e | **Bridge (Dess)** | `bridge/…/schemas/zone.py` |
| **Physical placement** — the solve, transforms, collision | **Engine (Prod)** | `godot/scripts/generation/zone_builder.gd` |
| Carving — N apertures, sealed walls, lock geometry | **Engine (Prod)** | `godot/scripts/generation/chamber_builders.gd` |
| Socket resolution by id | **Engine (Prod)** | `godot/scripts/content/content_instantiator.gd` |
| **Physical** reachability, to a definition faithful to the movement law | **Engine (Prod)** | `godot/tests/room_contract_driver.gd` — **open**, §5.5 |
| Audits — N-door probes, the inverted seal probe, arrival | **Engine (Prod)** | `godot/scripts/content/room_audit.gd` |
| This contract | **Both. Agreed before either starts** | `docs/design-proposals/09_ROOM_CONTRACT.md` |

**Neither lane may implement the other's column.** The bridge writes no transform; the engine invents no edge, shell, or assignment.

**Neither lane may relax the other's check.** If the engine cannot prove arrival, the answer is a failing composition, not a softer predicate.

**Not in either lane for slice 1:** the B-1 and B-2 blockers, which are Prod's current work against a frozen build and are not gated on this contract.

---

## 8. First-slice acceptance checks

**The slice is temporary scaffolding.** It exists to prove the contract end to end and is expected to be replaced by authored three-door geometry once the interface holds. **It is not a content milestone and nothing in it should be treated as shippable level design.**

**Shape:** eight rooms, one degree-3 procedural junction, one local key, one locked branch, one return plug. **Every non-junction room composes through the existing authored path, unchanged.**

| # | Check | Passes when | Lane |
|---:|---|---|---|
| 1 | **Edges survive a round trip** | a Zone with `TopologyEdge`s saves, loads, and compares equal, including `realization` and `destination` | Bridge |
| 2 | **Three doors carve** | the junction builds with three apertures at its three assigned sockets, at the declared `aperture` dimensions | Engine |
| 3 | **Three doors probe** | `_openings_are_holes` runs **three** sweeps and passes all three | Engine |
| 4 | **The sealed door is solid** | an unused joining socket declared `SEALED` is measured by the same probe with the **inverted** expectation, and **the test fails if the probe is skipped** | Engine |
| 4b | **An authored seal is a thing, not an absence** | a `SEALED` socket on an authored shell has a closure node over its aperture and the inverted probe passes. **Removing the closure fails the check** | Engine |
| 5 | **Placement succeeds inside budget** | eight rooms with one junction return `LAYOUT_OK` within `3.0 s` | Engine |
| 6 | **The timeout is a timeout** | a **large** route space with a **small** budget returns `LAYOUT_TIMEOUT` with `candidates_remaining > 0` and `elapsed_ms >= budget_ms`. **The budget, not the geometry, is what the fixture controls** | Engine |
| 7 | **Infeasible is exhausted, under a stated policy** | an input whose candidate space **under the declared routing policy** is empty returns `LAYOUT_INFEASIBLE` with `exhausted: true`, the `policy` it exhausted, and non-empty `blocking_rooms` | Engine |
| 8 | **The contract refuses bad input** | an assignment naming an unknown `socket_id` returns `LAYOUT_REFUSED` and is **not retried** | Both |
| 9 | **The lock gates** | the locked branch is impassable without `key_id` and passable with it | Engine |
| 10 | **The key is logically reachable first** | `R ⊆ E` over the real graph, **including return edges**, proves the key obtainable without passing its own lock — **and the check fails on a deliberately circular key placement** | Bridge |
| 10b | **The key is physically reachable** | **OPEN — Prod's to define.** A traversal proof faithful to the movement law shows the key's anchor reachable from the room's arrival volume without crossing its own lock. **The `c8ed2e9` walk flood does not satisfy this** (§5.5); until a faithful proof exists this check is an acknowledged gap, not a passing check | Engine |
| 11 | **The plug returns** | traversing the plug places the player at the declared `AnchorId`, and the edge appears in the reachable set | Both |
| 11b | **The plug lands somewhere a player fits** | the resolved `destination` anchor admits the standing capsule and has ground under it, by the same probe that judges `player_entry`. **A plug whose destination is unreachable or buried fails composition**, and the test fails if the probe is skipped | Engine |
| 12 | **The plug closes nothing** | the solver is never handed a closure constraint for the `TRAVERSAL_ONLY` edge — asserted, not observed | Engine |
| 13 | **Progress survives death** | key and opened lock persist across a death and reload | Both |
| 14 | **The leave-and-return round trip, with Checks outstanding** | the Zone is left **through the exit with allocated Checks unclaimed**, reaches `DORMANT`, is re-entered, and those Checks are still claimable with keys, opened locks, stations and claimed Checks intact. **The presence of the `DORMANT` enum is not the property; the round trip is** | Both |
| 14b | **A cleared Zone is still revisitable** | a Zone with every Check claimed reaches `COMPLETE`, and is **re-entered** with layout and progress intact. Per the 2026-09-12 ruling, claiming the last Check does not close the place | Both |
| 15 | **Layout replays** | re-entry uses the committed transforms and does **not** re-solve — asserted by instrumenting the solver, not inferred from the result | Both |

**Every check that asserts an absence — 4, 6, 8, 12, 15 — is written to fail when the thing it guards is removed.** That is the discipline the playtest's recurring finding demands: a check that passes when its subject is skipped is not evidence.

**Checks 6 and 7 are the pair that matters most.** They are the only two that distinguish "we ran out of time" from "this cannot be built", and the whole escalation path depends on the distinction being real in the implementation rather than only in this document.

---

## 9. What this contract does not cover

- **Authored three-door shells.** Slice 1 uses none; the capacity schema is ready for them.
- **Spatial cycles.** `JOINED` closure is specified (§30.11.2e) and not exercised.
- **Warp station placement rules.** §30.12.4 defines what a station *is*; where composition puts them is open.
- **Ability gates.** §29.5a and check 23; after local keys, per the owner's sequence.
- **The exit unlock**, beyond naming its coupling to `DORMANT` (§4.1).
- **Enemy placement, prop placement, perception.** All are Epsilon-expressiveness questions and none is a door.
- **Anything on a schedule.** Sequence is the owner's.

---

## 10. Engine-lane review, resolved

`docs/reviews/2026-09-12-room-contract-prod-review.md` returned **changes requested** against `cb3bf64` with six defects. **All six are taken.** Two were blocking and one of those was a contradiction the document made with itself.

| # | Finding | Resolution |
|---:|---|---|
| 1 | **BLOCKING.** `TRAVERSAL_ONLY` edges were given a `DoorAssignment`, which *is* a socket assignment — so a plug consumed a joining socket and would have carved a fourth aperture, and a two-door shell with a plug would have failed the injective assignment outright | `PlugAssignment` added as its own record; invariant 4 replaced; invariant 7 added; checks 19b and 19e scoped to `JOINED`; check 11b added |
| 2 | §2.1's premise was **false**: socket ids are already opaque and alias-resolved, so no migration is needed, and `LEGACY_ENTRY` was cited backwards | §2.1 replaced. The real defect — joining sockets chosen *by name* rather than by assignment — is named and is already fixed at `82d500f` |
| 3 | **BLOCKING.** `LAYOUT_OK` carried room transforms only, which cannot rebuild connector chains without re-running the search §5.2 promises never happens. And the bridge committed *before* validating | `links` added; the join clause now runs through the chain; **validate then commit**, and a failing proposal never acquires a digest; §5.4 divides the evidence |
| 4 | Checks 6 and 7 asserted the opposite of what their fixtures produce, and `LAYOUT_INFEASIBLE` claimed more than a bounded search can know | Both fixtures corrected; `LAYOUT_INFEASIBLE` now carries the `policy` it exhausted. **A bounded search may never report that a design is impossible** |
| 5 | `SEALED` means two different constructions; `R ⊆ E` is necessary and not sufficient; check 14 did not test the round trip it exists for | §3.1's row split; §5.5 added; checks 4b, 10b and 14 rewritten |
| 6 | **FLAG, for the owner.** §30.12.1 froze *"a `COMPLETE` Zone is not re-enterable"* without a ruling | **Ruled 2026-09-12: fully cleared Zones remain revisitable.** §30.12.1 corrected; check 14b added |

Plus two corrections to the document itself: **Law 47a → 47c** where committed replay is meant, and the header line, which asserted a review that had not happened.

**One correction to the review, per owner direction of 2026-09-12.** Its check 10b proposed the `c8ed2e9` walk flood as the physical-reachability proof. That flood permits one-metre step-ups the player cannot perform, making it a **structural diagnostic rather than a traversal proof**, and a diagnostic that over-permits will pass a key the player cannot reach. **Physical reachability stays Prod's to define and prove; this contract states the obligation, consumes the verdict, and encodes no particular flood as authoritative.** §5.5 records it as an open gap rather than a satisfied check.

---

## 11.7 Restriction 1 answered — the bridge now writes both edge ids

**Bridge lane, 2026-09-12, against the engine lane's `7adc5e5`.** §11.2
named `arrive_edge` / `depart_edge` as read by the engine and written by
nobody. They are written now, and nothing in §11 changed to make room
for them.

**They name an edge, exactly as §11.2 asked.** `ChamberBase.arrive_edge`
and `ChamberBase.depart_edge` are optional `str | None`, held to the
same `[a-z0-9_:]` charset as every other edge id, additive, and
`schema_version` stays 7. A chamber carrying neither is the chamber that
shipped before multi-door existed and the engine's fallback applies —
which is still what all twelve two-door shells get, because the composer
puts their chain on `entry` and `exit`.

**Derived from the door assignment, not maintained beside it.** The
composer already decides which socket serves which edge; these two
fields are pointers into that decision, carried on `GraphProduct` as
`arrivals` / `departures` and written by `topology.apply`. Three rules
keep them from becoming a second topology:

* each must name an edge one of that room's own **non-`SEALED`** doors
  carries — because `socket_for_edge` returns an empty socket when it
  finds none, and an empty answer is the legacy fallback taken
  *silently*, which is a filled-in field that does nothing;
* `arrive_edge` must name an edge the room is the **`room_b`** of, and
  `depart_edge` an edge it is the **`room_a`** of, per §11.1 and §6.5;
* they may not be the same edge.

**What the composer emits today.** Spine rooms arrive by the edge from
the previous spine room and depart by the edge to the next. A branch
destination arrives by its vault. A junction on the spine does **not**
depart by its branch — it departs by the spine, and the branch mouth is
placed by the engine's own socket table, which is §11.4 and yours. A
nested junction with exactly one onward vault departs by it; with two
there is no single continuation, so the field is left unset and your
documented fallback is the honest answer rather than an arbitrary pick.

**Proved against your lookup, not against our intention.**
`test_a_non_default_opening_survives_the_wire_and_names_its_edge`
composes a room whose chain enters through `side_left` and leaves
through `side_right` with both default sockets `SEALED`, serializes it,
re-parses it, and resolves the result with a transcription of
`socket_for_edge` — so the assertion is what the engine will land on. A
second control runs every room of every composed Zone through the same
lookup and refuses a selector that resolves to the fallback. Three more
refuse an edge the room does not carry, a selector pointing the wrong
way down its edge, and a selector onto a sealed door.

**Unchanged, and yours:** §11.3 per-socket arrival regions, §11.4 branch
mouths from the procedural socket table. A `joinable` list in the offer
proves capacity is visible and these two fields say which opening the
chain uses; neither is a claim that the body arrives through it.
