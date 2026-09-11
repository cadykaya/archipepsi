# 09 — THE ROOM CONTRACT

**STATUS: DRAFT FOR INTERFACE REVIEW. Not agreed, not implemented.**

The seam between the bridge and the engine for multi-door rooms. It exists so two lanes can implement in parallel without either guessing what the other guarantees, and it is the one artefact neither lane should write alone.

**Reviewed by:** Prod (engine lane).
**Pinned against:** Production `96c450e`, and `06_THE_AMALGAM.md` §4.9a, §30.11.2b, §30.11.2e, §30.12.
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

### 2.1 Socket ids are stable, and today they are not

Production names both doorways positionally: every one of the twelve authored shells declares exactly `['entry', 'exit']`. **Positional names cannot survive a third door** — a shell gaining a side door would have to renumber, and every stored assignment referring to `exit` would silently mean something else.

> **A `socket_id` identifies one opening for the life of the shell. It is never reused for a different opening, and changing one is a `catalog_digest` change**, which §30.11.5 class 6 already treats as a hard load error rather than a silent reinterpretation.

Migration is mechanical and is the engine lane's: existing `entry`/`exit` become stable ids, and the legacy names remain as an alias table for one schema version. **`RoomContract.LEGACY_ENTRY` already exists as the precedent** — the old behaviour was named rather than assumed, which is exactly the right treatment here.

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
| **Must add** | stable `socket_id`s; a `player_entry` volume per joining socket |
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
  edge_id         : EdgeId | null           # required iff usage != SEALED; null iff SEALED
  key_id          : KeyId | null            # required iff usage == LOCKED; null otherwise

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
| `SEALED` | **no aperture; wall** | no | **the opening is solid** — the capsule does *not* pass |

> **`SEALED` inverts the audit; it does not skip it.** `_openings_are_holes` reports a blocked doorway as a defect. For a declared-`SEALED` door the same measurement runs with the **opposite expected answer**, and the expectation comes from the declaration rather than from the geometry.

**Skipping the check for sealed doors is the tempting shortcut and it is forbidden.** It would be a fourth instance of the recurring failure the playtest named — *a measurement exists, is correct, and is never handed the case that fails it.* A sealed door that is accidentally a hole is a shortcut past a lock; a sealed door correctly solid but unchecked is indistinguishable from it in the test report. **It must be checked harder, not less.**

### 3.2 `TRAVERSAL_ONLY` edges bind no geometry and carry full reachability

A return plug — a non-euclidean door, a rematerialisation pad, a tube that fades — moves the player between two rooms with nothing joining them spatially.

> **A `TRAVERSAL_ONLY` edge assigns no socket, meets no collar, and closes no loop. It participates fully in reachability, direction, and every predicate the model check reads.**

Consequences the engine lane should hold onto:

- A room's **door degree** is its `JOINED` degree. A dead-end room with one door and one plug has door degree `1`.
- **The plug's presence makes the graph cyclic and creates no spatial cycle.** Slice 1 has a graph cycle and nothing for the solver to close.
- `destination` is an **`AnchorId`** — a declared anchor such as the Zone start or the last large room — **never a coordinate.** The composer names anchors; the engine resolves them. `zone_builder.gd:4` holds verbatim.

### 3.3 Invariants the bridge guarantees before sending

The engine may assume all of these and should assert them anyway; a violation is `LAYOUT_REFUSED` (§6.3), not a placement failure.

1. Every `socket_id` in a `DoorAssignment` exists in that `shell_id`'s capacity.
2. No `socket_id` appears twice in one `RoomAssignment`.
3. Every `JOINED` edge is named by exactly two `DoorAssignment`s, one in each endpoint room, neither `SEALED`.
4. Every `TRAVERSAL_ONLY` edge is named by exactly one `DoorAssignment` and carries a `destination`.
5. Every `key_id` on a `LOCKED` door is obtainable without passing that lock — **`R ⊆ E` proves this before the send**, and it is the bridge's obligation, not a thing the engine can check.
6. Every joining socket a room does not use is declared `SEALED`. **There is no fourth state and no default** — an unmentioned socket is a contract violation, because "unmentioned" is exactly how an unaudited hole gets into a wall.

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

**Sends:** on `LAYOUT_OK`, the world transform per room.
**Bridge does:** writes them into the Zone manifest as part of `manifest_digest`, then runs **§30.5 check 19e** — measuring the returned transforms against join, body, closure and arrival. Measuring is not re-solving.

> **The layout is solved once and replayed forever.** Every later load uses the committed transforms. This is how Law 47a's determinism is obtained without promising that two machines independently rediscover the same layout — a promise about cross-platform floating point that nothing here can keep.

### 5.3 Progress — engine → bridge, during play

Existing intent shape. `grant_local_reward` is the precedent: an id derived from identity rather than from the moment, so the same event twice is one event.

| Intent | Carries | Idempotent on |
|---|---|---|
| `key_collected` | `zone_id`, `key_id` | `key_id` |
| `lock_opened` | `zone_id`, `room_id`, `socket_id` | the `(room_id, socket_id)` pair |
| `station_reached` | `zone_id`, `station_id` | `station_id` |

**Every one is idempotent by identity, because every target set is monotone.** A duplicate is not an error and must never be reported as one; a resend after a dropped connection is the normal case.

---

## 6. How failure is reported

**A typed result, never a boolean and never a bare error string.**

```
LayoutResult =
  | LAYOUT_OK          { transforms : map[RoomId, Transform] }
  | LAYOUT_TIMEOUT     { elapsed_ms, nodes_explored, candidates_remaining }
  | LAYOUT_INFEASIBLE  { exhausted : true, blocking_rooms, blocking_pairs }
  | LAYOUT_REFUSED     { violation, room_id?, socket_id? }
```

### 6.1 A timeout is a timeout

> **`LAYOUT_TIMEOUT` says the budget was spent with candidates unexplored. It says nothing whatever about whether a layout exists.**

Reporting a timeout as impossibility lets a slow machine indict a sound design and sends a recomposable Zone down a terminal path. The two are routed differently and mean opposite things: **`LAYOUT_TIMEOUT` says the solver ran out of time; `LAYOUT_INFEASIBLE` says the geometry ran out of room.**

`candidates_remaining` is the field that keeps the distinction honest. A solver reporting a timeout with zero candidates remaining has in fact exhausted the space and should have said `LAYOUT_INFEASIBLE`; the bridge treats that combination as a contract violation rather than quietly reinterpreting it.

### 6.2 Only an exhausted search may claim infeasibility

`exhausted : true` is required, not decorative. **A solver that cannot distinguish exhaustion from expiry reports `LAYOUT_TIMEOUT`** — the honest answer and the conservative one.

`blocking_rooms` and `blocking_pairs` are what make the result actionable: they are what turns "this Zone did not compose" into a catalog review with room ids attached.

### 6.3 `LAYOUT_REFUSED` is the bridge's bug, not the geometry's

Any §3.3 invariant violated — an unknown `socket_id`, a doubly-assigned socket, an edge with one endpoint, an unmentioned socket, a `catalog_digest` mismatch. **It is not a placement outcome and must never be retried**, because retrying identical invalid input is the definition of a loop. It escalates to the bridge lane with the violated invariant named.

### 6.4 What the bridge does with each

| Result | Bridge |
|---|---|
| `LAYOUT_OK` | commit, then check 19e |
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
| Audits — N-door probes, the inverted seal probe, arrival | **Engine (Prod)** | `godot/scripts/content/room_audit.gd` |
| This contract | **Both. Agreed before either starts** | `docs/design-proposals/09_ROOM_CONTRACT.md` |

**Neither lane may implement the other's column.** The bridge writes no transform; the engine invents no edge, shell, or assignment.

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
| 5 | **Placement succeeds inside budget** | eight rooms with one junction return `LAYOUT_OK` within `3.0 s` | Engine |
| 6 | **The timeout is a timeout** | a deliberately over-constrained input returns `LAYOUT_TIMEOUT` with `candidates_remaining > 0`, **not** `LAYOUT_INFEASIBLE` | Engine |
| 7 | **Infeasible is exhausted** | an input with no layout returns `LAYOUT_INFEASIBLE` with `exhausted: true` and non-empty `blocking_rooms` | Engine |
| 8 | **The contract refuses bad input** | an assignment naming an unknown `socket_id` returns `LAYOUT_REFUSED` and is **not retried** | Both |
| 9 | **The lock gates** | the locked branch is impassable without `key_id` and passable with it | Engine |
| 10 | **The key is reachable first** | `R ⊆ E` proves the key obtainable without passing its own lock — **and the check fails on a deliberately circular key placement** | Bridge |
| 11 | **The plug returns** | traversing the plug places the player at the declared `AnchorId`, and the edge appears in the reachable set | Both |
| 12 | **The plug closes nothing** | the solver is never handed a closure constraint for the `TRAVERSAL_ONLY` edge — asserted, not observed | Engine |
| 13 | **Progress survives death** | key and opened lock persist across a death and reload | Both |
| 14 | **Progress survives Hub return** | key, lock, station and claimed Checks persist across Hub return and re-entry; the Zone is `DORMANT` and re-enterable | Both |
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
