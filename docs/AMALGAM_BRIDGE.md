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

## 4. What is proved, and by what

**An earlier version of this document said "one gap left". That was
wrong** — the aperture check was not merely unfed, it was *optional*, so
it could never have failed on a real Zone. An independent pass found six
kinds of evidence that could each be omitted from an otherwise sound
layout and still produce an ACCEPTED manifest. That is fixed, and the
wording that hid it is corrected here.

### 4.1 Two kinds of evidence, kept apart

| | |
|---|---|
| **Connected runtime evidence** | the bridge's own path, end to end, through real handlers. `test_amalgam_end_to_end.py` generates an ordinary Zone, commits a layout through `handle_layout_result`, plays through `handle_progress`, leaves through `handle_exit_zone`, **reloads the bytes from disk**, and re-enters. Nothing in it assigns to `engine.save` |
| **Helper-level evidence** | a function proved in isolation. `test_layout.py` and `test_topology.py` are this: they establish that a validator refuses what it should, not that anything calls it |

**The end-to-end test's one synthetic part is the engine.** `_place()`
builds the layout payload that `zone_builder.build()` will send once it
serializes one. Everything downstream of that payload is the real path;
everything upstream is the real path. **The seam itself is not yet
crossed by a running engine**, and no test here should be read as
evidence that it is.

### 4.2 Gaps, precisely

1. **The engine does not send `layout_result`.** The intent, the route,
   the handler, the validator and the manifest store all exist and are
   exercised; `zone_builder.build()` returns its result into Godot and
   nothing puts it on the wire. **§5 is the handoff.**
2. **Aperture evidence is not in the layout result.**
   `_assigned_doors_match_their_usage` measures both polarities in
   `room_audit.gd`. Until it travels, a real Zone will be **refused**
   rather than silently accepted — which is the correct failure, and is
   why closing this is worth doing before the emitter ships.
3. **No engine consumes the replayed manifest.** `handle_enter_zone`
   sends `ZoneReady.manifest` on a re-entry. Laying those pieces back
   down instead of re-searching is the engine's half.
4. **Physical reachability is unproved and is not this lane's.** `R ⊆ E`
   is a graph property; it cannot see a key inside a crate. Per owner
   direction the `c8ed2e9` walk flood is **not** authoritative — it
   permits one-metre step-ups the player cannot perform, so a diagnostic
   that over-permits would pass a key nobody can reach.
5. **One unfinished Zone holds locations at a time.** A DORMANT Zone
   still reserves its Checks, so a new Zone cannot be generated while
   one is outstanding. **This is the current implementation limit, not a
   frozen Amalgam rule**; `test_one_unfinished_zone_holds_locations_at_a_time`
   asserts the boundary so lifting it is deliberate. Revisiting a
   finished Zone is unaffected — VISITING reserves nothing.

## 5. Handoff to the engine lane

Three items, in the order that makes each one testable when it lands.

### 5.1 Surface aperture polarity

`room_audit.gd` already measures it. Add it to the build result:

```json
"apertures": {"c014/entry": true, "c014/side_left": true,
              "c014/side_right": false}
```

`true` = the capsule passes; `false` = solid. **Every door the Zone
declares needs an entry**, including `SEALED` ones — that is the
inverted probe, and a door the layout does not report is refused rather
than skipped.

### 5.2 Send the result

```json
{"type": "layout_result", "zone_id": "zone_001", "layout": { … }}
```

`layout` is `zone_builder.build()`'s dictionary, serialized. The bridge
needs `rooms` (with nested `bounds`), `joins`, `anchors`, `arrival_ok`,
`apertures` and `stations`. Two of those are new:

```json
"joins": {"e:c012:c014": {
    "socket_a": [0, 0, 24], "socket_b": [0, 0, 40],
    "chain": [{"kind": "CONNECTOR", "entry": [0, 0, 24],
               "exit": [0, 0, 40],
               "bounds": {"position": [-2, 0, 24], "size": [4, 4, 16]}}]}}

"arrival_ok": {"room:c014:arrival": true, "zone_start": true}
```

**`joins` is the one that matters most.** Absolute room transforms make
cycle closure free and prove nothing about whether two assigned sockets
are connected; the bridge walks socket → first entry, each exit → the
next entry, last exit → socket. An empty chain means direct abutment and
is still walked. **`arrival_ok` is a measured verdict, not a
coordinate** — a point says where a body would arrive, not that one
fits.

### 5.3 Replay instead of re-searching

On re-entry `ZoneReady` carries `manifest`. Laying its `rooms` and
`joins` back down is what makes a revisited Zone the same Zone; a
re-search would be a second layout for a place the player already knows.

## 6. What remains in this lane

- Consume a real `layout_result` (§4.1) and commit a real manifest.
- Re-entry that rebuilds from the committed manifest rather than
  regenerating — the state machine is done, the manifest replay is not.
- The `manipulate` capability contract, `vector_latches`, and the model
  check's physics properties: the next Amalgam dependencies after this
  slice, none of them started.
