# Amalgam — bridge lane

**Branch:** `claude/archipepsi-amalgam-bridge`
**Started from:** `82d500f` (the engine slice)
**Lane:** Dess — bridge schema, graph, reachability, layout validation and
campaign state. **No Godot carving, no physical placement, no physics.**
Those are Prod's column and nothing here implements them.

---

## 1. What is implemented

| Piece | Where | Proof |
|---|---|---|
| The Zone is a **graph**, not a list | `schemas/graph.py`, `Zone.edges` | a Zone with no edges still means the chain its order describes |
| `DoorAssignment` / **separate** `PlugAssignment` | `schemas/graph.py` | a `TRAVERSAL_ONLY` edge named by a door is refused; the refusal fails when removed |
| Assignment production | `topology.compose_chain`, `compose_with_branch` | a three-door junction, a locked branch, a key before the lock, a way back |
| Logical reachability over states | `topology.reachability` | `R ⊆ E`, every Check reachable, every key obtainable without passing its own lock |
| Progress intents **received** | `protocol.py`, `campaign.handle_progress` | a collected key reaches the save and survives a round trip |
| `DORMANT` and re-entry | `transitions.rest_zone` / `enter_zone` | leave through the exit with Checks outstanding, walk back in, progress intact |
| Layout validation | `layout.validate` | overlap, aperture polarity both ways, unresolved anchors, ambiguous chains |
| Validate **then** commit | `layout.validate` | a failing proposal has no digest, because nothing else can produce one |

`1135` bridge tests pass. Every check that asserts an absence was
sabotage-tested: the guard was removed and the test was watched to fail.

---

## 2. Exact payloads

### 2.1 What the engine already sends, and the bridge now receives

Unchanged on the engine side. These are the shapes `zone_controller.gd`
puts on the wire today; the bridge had no route for them and dropped
them, which is the path this branch closes.

```json
{"type": "key_collected",  "zone_id": "zone_001", "key_id": "red"}
{"type": "lock_opened",    "zone_id": "zone_001", "room_id": "c014",
                           "socket_id": "side_left"}
{"type": "station_reached","zone_id": "zone_001",
                           "station_id": "room:c014:arrival"}
```

**All three are idempotent by identity** and a resend is the normal case,
never an error. `station_reached` is specified and not yet emitted; the
receiver is ready for it.

### 2.2 What the bridge sends in the Zone

Additive. A chamber gains `doors` and `keys`; the Zone gains `edges` and
`plugs`. **`schema_version` stays `7`** — a Zone carrying none of it is
exactly the chain Zone that shipped before, so nothing already in a save
breaks and there is no migration.

```json
{
  "id": "c014", "type": "arena", "width": 26.0, "depth": 24.0,
  "doors": [
    {"socket_id": "entry",      "usage": "USED",   "edge_id": "e:c012:c014"},
    {"socket_id": "exit",       "usage": "USED",   "edge_id": "e:c014:c016"},
    {"socket_id": "side_left",  "usage": "LOCKED", "edge_id": "e:c014:c020",
     "key_id": "red", "colour": "red"},
    {"socket_id": "side_right", "usage": "SEALED"}
  ],
  "keys": []
}
```

```json
"edges": [
  {"edge_id": "e:c014:c020", "room_a": "c014", "room_b": "c020",
   "direction": "BIDIRECTIONAL", "realization": "JOINED"},
  {"edge_id": "p:c020:start", "room_a": "c020", "room_b": "c001",
   "direction": "A_TO_B", "realization": "TRAVERSAL_ONLY"}
],
"plugs": [
  {"edge_id": "p:c020:start", "room_id": "c020",
   "source_anchor": "room:c020:arrival", "destination": "zone_start",
   "device": "pad"}
]
```

**Note the shapes match `Slice1Fixture` deliberately.** Two lanes
disagreeing about which field carries a lock is a defect that surfaces as
a wall in the wrong place.

Four rules the engine can rely on:

1. **Every joining socket a room declares is mentioned.** Unused ones are
   `SEALED`, never omitted — "unmentioned" is how an unaudited hole gets
   into a wall.
2. **`LOCKED` carves.** The lock is a placement over a real hole. Only
   `SEALED` declines to cut.
3. **A plug never appears in `doors`.** It consumes no joining socket, so
   a room's door budget is unaffected by how many plugs it holds.
4. **Anchors are names.** `zone_start`, `last_large_room`, or
   `room:<id>:arrival`. Never a coordinate.

### 2.3 What the bridge needs back — the one real protocol change

`zone_builder.build()` already returns everything below. **It is returned
into Godot and never sent anywhere**, so this is a serialization and one
new intent, not new computation.

```json
{
  "type": "layout_result",
  "zone_id": "zone_001",
  "status": "LAYOUT_OK",
  "rooms":   {"c001": {"position": [0,0,0], "yaw": 0.0}},
  "bounds":  {"c001": {"position": [-8,0,0], "size": [16,5,15]}},
  "links":   {"c002": [{"kind": "CONNECTOR",
                        "position": [0,0,15], "yaw": 0.0,
                        "bounds": {"position": [-2,0,15],
                                   "size": [4,4,6]}}]},
  "anchors": {"zone_start": [0,0,1], "room:c020:arrival": [0,0,401]},
  "arrival": {"zone_start": true, "room:c020:arrival": true},
  "apertures": {"c014/entry": true, "c014/side_right": false}
}
```

**Updated 2026-09-11 against `a632ec9`.** Prod surfaced two of the three
missing fields, and **nested them inside each room's entry** rather than
shipping sibling maps. The bridge reads the engine's shape; the sibling
form is still accepted because an earlier draft of this document asked
for one, and reading both costs a `get`.

```json
"rooms": {"c001": {"position": [0,0,0], "yaw": 0.0,
                   "bounds":  {"position": [-8,0,0], "size": [16,5,15]},
                   "arrival": [0,0,3]}}
```

| Field | Status | Note |
|---|---|---|
| `rooms` | **exists** | `room_transforms`, as is |
| `links` | **exists** | as is, keyed by chamber id — see §4 |
| `anchors` | **exists** | as is |
| `bounds` | **now exists**, nested | `room_transforms[id].bounds`, world-space, as measured |
| `arrival` | **now exists**, nested | `room_transforms[id].arrival`, the point a body arriving there stands at |
| `apertures` | **still needed** | `_assigned_doors_match_their_usage` measures both polarities in `room_audit.gd`, and the layout result does not carry them. `{"room/socket": is_hole}` is the shape the validator reads |

Failure payloads are already exactly right:

```json
{"status": "LAYOUT_TIMEOUT", "elapsed_ms": 3000.0,
 "nodes_explored": 12, "candidates_remaining": 4}

{"status": "LAYOUT_INFEASIBLE", "exhausted": true,
 "policy": {"max_route_turns": 2, "explore_connectors": 40,
            "max_clearance_connectors": 96, "clearance_budget": 31},
 "blocking_rooms": ["c004"], "blocking_pairs": []}
```

**The bridge never reinterprets these.** A timeout stays a timeout with
`candidates_remaining` intact, and an infeasibility carries the policy it
exhausted, because a bounded search may never report that a design is
impossible.

---

## 3. Protocol changes, in full

| Change | Kind |
|---|---|
| `key_collected`, `lock_opened`, `station_reached` added to `ClientMessage` | additive |
| `ZoneProgress` on `ZoneRecord` — keys, locks, stations, resume anchor | additive, defaults empty |
| `ZoneState` gains `DORMANT` | additive |
| `TERMINAL_ZONE_STATES` unchanged; **new** `REVISITABLE_ZONE_STATES` | the two questions separated |
| `Zone.edges`, `Zone.plugs`, chamber `doors`, chamber `keys` | additive, `schema_version` stays `7` |
| `layout_result` intent | **new, needed from the engine** |

**`COMPLETE` is revisitable** (ruled 2026-09-12) and still reserves
nothing, because "does this hold locations" and "can you walk back in"
are different questions that one constant used to answer.

---

## 4. Integration gaps — what is not yet true

Stated plainly rather than implied by what is missing.

1. **Nothing sends `layout_result` yet.** The validator is written,
   tested against the documented shape, and has never seen real engine
   output. §2.3 is what closes it.
2. **`apertures` is not surfaced.** `bounds` and `arrival` arrived at
   `a632ec9` and the validator reads them. The door-polarity evidence is
   measured in `room_audit.gd` and does not travel in the layout result,
   so **the check that a `SEALED` door is solid and a `USED` door is a
   hole is written, tested, and currently never handed real data.** That
   is the one remaining piece of §2.3.
3. ~~**The branch is logical, not physical.**~~ **Closed at `a632ec9`.**
   The engine now routes and places a branch room off the junction —
   `_emit_route` runs a second time for it and the room lands in
   `room_transforms` with its own bounds and arrival. The graph and the
   placement now say the same thing.
4. **`links` is keyed by room.** Sound while each room has one inbound
   `JOINED` edge. The validator **asserts that** and refuses the Zone
   when it stops holding, naming `edge_id` keying as the fix.
5. **Physical reachability is unproved and is not mine.** `R ⊆ E` is a
   graph property; it cannot see a key inside a crate. Per owner
   direction of 2026-09-12 the `c8ed2e9` walk flood is **not**
   authoritative — it permits one-metre step-ups the player cannot
   perform, so it is a structural diagnostic rather than a traversal
   proof, and a diagnostic that over-permits will pass a key nobody can
   reach. **The bridge states the obligation and consumes a verdict; it
   encodes no flood as the proof.**
6. ~~**`station_reached` has no emitter.**~~ **Closed at `a632ec9`.**
   `warp_station.gd` exists and `zone_controller.gd` sends the intent;
   the bridge receiver was already written to the documented shape and
   needed no change.
7. **The relaxed exit is not shipped**, and should not be until the
   leave-and-return round trip is demonstrated end to end. The unlock is
   a two-line change and re-entry is a schema change; shipping them in
   the easy order converts a forgone reward into a stranded one.

---

## 5. One consequence that wants an owner's eye

A `DORMANT` Zone still reserves its locations — that is exactly what
stops the allocator reissuing a Check the player means to come back for.
It is therefore **the** Zone holding locations, so **a new Zone cannot be
generated while one is dormant.**

That satisfies every ruling: the outstanding Checks stay where they are,
and the Zone is re-enterable with progress intact. It also means one Zone
in flight at a time. Allowing several dormant Zones at once is a real
allocation change and is not made here.

---

## 6. What remains in this lane

- Consume a real `layout_result` (§4.1) and commit a real manifest.
- Re-entry that rebuilds from the committed manifest rather than
  regenerating — the state machine is done, the manifest replay is not.
- The `manipulate` capability contract, `vector_latches`, and the model
  check's physics properties: the next Amalgam dependencies after this
  slice, none of them started.
