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
builds the layout payload in the shape `zone_builder.layout_to_json`
produces. Everything downstream of that payload is the real path; so is
everything upstream. **The engine now serializes a real one** (§5), so
the seam is crossed — but it is crossed in the engine lane's
environment, and nothing in *this* suite has run Godot. A green run
here is still evidence about the validator, not about the exchange.

### 4.1a Which refusals has anything ever triggered?

A validator with twenty-two refusals and a green suite says nothing
about how many of those refusals a test has ever fired. `make
mutate-bridge` answers it: mute one refusal, run the tests, and if they
still pass, nothing was reading it.

The first run found **eleven**, and one of them was not in a validator
at all — deleting the re-entry manifest replay outright, the thing §5.3
calls where the determinism comes from, passed all 1091 tests, because
every assertion read the saved record and the save file is identical
either way. **Assert the message, not the record.**

| Module | Sites | Unmeasured, first run | Now |
|---|---|---|---|
| `layout.py` | 22 → 34 | 8 — including the chain walk's inductive step, which the single-piece fixture could never reach | 0 |
| `topology.py` | 4 | 1 — "not reachable at all" had never fired; every test stranded rooms behind a *gate* | 0 |
| `schemas/physics.py` | 13 | 1 | 1, deliberately — see below |
| `schemas/transitions.py` | 28 | 22 | 17, and **not this lane's** — see below |

**A survivor is not automatically a missing test.** It is one of three
things, and saying which is the work:

1. a real gap — write the test that fires it;
2. unreachable by construction — keep it as a backstop, comment which
   invariants keep it unreachable, and test *those*. The empty-`must`
   branch in `check_physics_content` is this: three separate model rules
   have to hold for it to stay dead, and
   `test_nothing_load_bearing_reaches_the_empty_latch_backstop` pins all
   three. It will keep showing up as a survivor, and that is correct;
3. dead code — delete it.

Never close a survivor by weakening the check.

**The harness had the defect it exists to find.** Run in a directory
where pytest could not start, it reported `1 sites, 0 unmeasured` — a
clean bill of health from a run in which nothing ran, because any
non-zero exit was scored as "the tests noticed". Two things stop that
now: an **unmutated baseline** must pass before a single mutation is
written, and only pytest's exit code **1** (tests ran, tests failed)
counts as a kill. Collection failure, usage error, internal error,
interruption and anything else are **harness errors** — reported with
their output, exit 2, never counted as a measurement in either
direction. The source is restored on every path, including interrupts.

**Seventeen survivors in `schemas/transitions.py` are left standing on
purpose.** They are in `start_generation`, `accept_zone`, `abandon_zone`,
`release_location`, `claim_zone_check`, `buy_shop_stock`,
`rollback_shop_purchase` and `grant_local_reward` — pre-existing
campaign transitions, not this lane's, and touching them here would mix
an audit of someone else's code into an Amalgam slice. The five that
were this lane's (`rest_zone` ×2, the progress-state guard,
`complete_zone` ×2) are closed. The finding is real and reproducible:

```
cd bridge && python3 tools/mutate.py archipepsi_bridge/schemas/transitions.py \
  "raise ValueError(" tests/test_zone_progress.py tests/test_regressions.py \
  tests/test_reconnect_races.py tests/test_affordances.py
```

### 4.2 Gaps, precisely

1. ~~**The engine does not send `layout_result`.**~~ It does:
   `zone_controller.gd::send_layout_result`, after
   `_measure_layout_evidence`, which is the only order that works — an
   earlier version sent the layout before measuring and the bridge
   refused it for carrying no measurements, correctly.
2. ~~**Aperture evidence is not in the layout result.**~~ It travels,
   as `apertures` and `arrival_ok` — verdicts, not coordinates.
3. ~~**No engine consumes the replayed manifest.**~~ `zone_builder`
   replays committed transforms and chains instead of re-solving.

   **All three are the engine lane's evidence, not this lane's** —
   there is no Godot here. What this lane verified from the merge is
   narrower and is in §5.4: the engine's payload shape against the
   validator, which found a hole on *this* side.
3b. **One Zone in six is still refused, and it is Art's.**
   `shell_hall_transit`, `shell_plenum_helix` and `shell_span_basin`
   declare an `exit` doorway 2.0 m outside their own envelope, so the
   validator refuses a Zone holding one. That is the correct failure —
   the playtest's "the connecter isnt connected at all" — and the
   request is `docs/art-requests/2026-09-11-doorways-outside-their-envelope.md`.
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

## 5. Handoff to the engine lane — **all three landed**

The engine lane reports the seam crossed at `dc4ef39`: `placement_plan`
reads the bridge's `edges` and each chamber's `doors` and places the real
branching graph, the layout goes back as `layout_result` with measured
apertures and arrival verdicts, and `ZoneReady.manifest` is replayed on
re-entry rather than re-solved. See `docs/AGENT_FRONTIER.md` and
`docs/AMALGAM_SLICE1.md` §5o.

**That is their evidence, not this lane's.** There is no Godot binary in
the bridge environment, so nothing here has run the integration driver;
what follows is what the three items asked for, kept because the
payload shapes are the contract and a reader needs them. §5.4 is what
crossing the seam turned up on this side.

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

### 5.4 What the crossing found on this side

Reading the engine's `layout_to_json` against the validator turned up a
hole that was mine. `zone_builder` appends an **exit room nobody
declared** (`rooms["exit"]`, a real body with a portal in it) and files
its approach under `e:__exit__`, plus `r:<room>` for the first room on
the spine, which no edge names because nothing joins *into* it.

The validator knew those three names and **did nothing else with them**.
That took two passes to actually close, and the first one is worth
recording because it is the same defect wearing a smaller hat.

**Pass one** parsed the exit room like any other and walked each
reserved chain's own links. That caught an exit room with no bounds and
one sitting inside `c001`. It did not catch four more, and the write-up
claimed one of them as fixed when it was not:

| Still accepted after pass one | Why the check could not see it |
|---|---|
| delete `rooms["exit"]` **and** `joins["e:__exit__"]` | the reserved pair was optional, so absent was indistinguishable from absent-on-purpose |
| delete only `joins["e:__exit__"]` | same |
| the **last** piece's `exit` moved ten kilometres away | internal continuity has no opinion about where a corridor goes, only that it does not come apart on the way |
| a piece with `kind: "NOT_A_PIECE"` | nothing read `kind` at all |

**The claim to correct.** The pass-one table in this document said "an
exit approach whose corridor **ends** ten kilometres away → refused".
That was false. The test behind it broke a chain in the *middle*, which
was caught; the case as written — a chain continuous through itself that
simply never arrives — accepted. `test_an_exit_approach_whose_last_piece_ends_far_away_is_refused`
is now that exact case, and it fails without the fix.

**Pass two takes the contract from the builder instead of from taste.**

*Presence.* Every `LAYOUT_OK` out of `zone_builder` carries the exit room
— it is appended unconditionally on that path, and every earlier return
is a `LAYOUT_INFEASIBLE` — and `_joins` files its approach whenever the
room is there. So both are **required**, not tolerated.

*Pieces.* `PIECE_KINDS` and the pose requirement are
`zone_builder.gd::malformed_pieces`, lifted whole: kind in
{`CONNECTOR`, `CORNER`}, `position` and `yaw` present, `position` a
point, and a `CORNER` recording a non-zero `turn`. **That guard is what
the engine runs against a committed chain before replaying it, and when
it trips the engine returns `LAYOUT_INFEASIBLE` and the Zone does not
open.** So a manifest the bridge accepts and the engine cannot rebuild
is a Zone that dies on re-entry — the exact failure Law 47c exists to
prevent. The bridge now applies the same rule at commit time, where it
is still a refusal rather than a dead save. `bounds` travels with every
piece and is deliberately **not** required: `_replay_route` re-derives
it by placing the piece, so demanding it would be the bridge inventing a
contract the engine does not have.

*Route.* `e:__exit__` gets the **full walk** — `socket_a -> first
entry`, `exit -> next entry`, `last exit -> socket_b` — because the
builder makes that close exactly: the exit room's `position` **is** the
route cursor, which is the last piece's `exit`, and `socket_a` is the
spine tail's `exit` doorway, which is where the route started. The
engine's own comment above the CORNER record says this walk is the
bridge's half of the exchange.

**The existing helper fixtures were brought up to that contract rather
than the contract brought down to them.** `_ok_result` and the
end-to-end `_place` now emit pieces with a pose and a kind and include
the reserved pair, because that is what a complete layout *is*; their
age was not a reason to make production evidence optional. The accepted
real-payload control is
`test_a_complete_layout_is_accepted_and_gets_a_digest`, and 34 of 34
refusals in `layout.py` are exercised by a test (`make mutate-bridge`).

### 5.4a Open, and Prod's to settle: the `r:<room>` endpoints

`r:<room>` is **anchored, not walked end to end**, and that is the one
place where the check is weaker than an edge's on purpose.

`zone_builder` files it as `socket_a` = the room's own `position`,
`socket_b` = its `arrival`, `chain` = the corridor that reaches the
room. So the chain *terminates at* `socket_a`, and `socket_b` is a point
several metres inside the room: the two declared ends are not the two
ends of the chain, and `socket_a -> chain -> socket_b` would refuse
every real Zone. What is required instead is that the chain **arrives**
— its last piece ends inside the room it approaches — which catches a
corridor that stops in open space without asserting a shape the builder
does not produce.

> **The question.** Can `r:<room>` be filed with doorway endpoints, the
> way `e:__exit__` already is — `socket_a` where the corridor starts,
> `socket_b` the doorway it arrives at? If yes, this lane deletes the
> special case and walks it exactly like a `JOINED` edge, and the first
> room's approach stops being the one corridor checked more loosely than
> the rest. If the fields are meant as they are, say so and the anchor
> check stands as the honest one, with this note as the reason.

Two things make this cheap to settle: it is one dictionary literal in
`_joins`, and this lane's side is a single branch in
`_check_reserved_join`.

## 6. The physics dependency, and what the engine lane owes it

**The missing physics runtime is an implementation dependency with an
owner, not an indefinite block.** Zero `RigidBody3D` in the project. The
bridge-side contract is written and tested anyway —
`schemas/physics.py`, `test_physics_contract.py` — so that when a
runtime lands, the rules it has to satisfy already exist rather than
being invented under pressure to make a demo work.

**Today every load-bearing physics package is REFUSED**, and a test
asserts that so it cannot drift quietly. No runtime means no replay
evidence, and no evidence is a refusal rather than a pending acceptance.

### 6.1 Two questions that must not merge

| | Identity | Qualification |
|---|---|---|
| Asks | does this host grant `manipulate` at all? | does it count as the *guaranteed* provider for a mandatory route? |
| Type | **Boolean**, from verb-set membership | **numeric**, `700 N` / `20.0 m` / `120 kg` |
| Read by | the verifier, and only the verifier | §29.4's Zone-entry check, and nowhere else |
| Stored | no | **no** — recomputed at entry from the resolved loadout, so a player cannot qualify by equipping Gear they then remove |

A sub-envelope host is real content: it manipulates, solves optional
routes, and is composable. It is simply not the thing that unlocks a
gated Zone — exactly as a `DASH` under `8.0 m` does not satisfy
`long_gap`. **Keeping them apart is what keeps a newton out of the state
vector.**

### 6.2 What the engine lane owes, concretely

**A body.** A manipulable object declaring what the bridge's contract
reasons about:

```json
{"body_id": "crate_a", "mass_kg": 80.0, "constrained": false,
 "rest_region": "room:c014:basin"}
```

**An interaction.** A verb resolving to numbers the envelope compares:

```json
{"verb": "PUSH", "force_n": 700.0, "range_m": 20.0,
 "mass_limit_kg": 120.0}
```

`PUSH`, `PULL` and `HOLD` grant `manipulate`; the other nine verbs never
do. Identity is the verb; the numbers are qualification and are a
different question.

**Evidence.** The one the whole gate turns on — §23.5 check 20's replay,
**bound to what it replayed**:

```json
{"package_id": "basin_bridge",
 "content_digest": "9f2c14ab7d3e0561",
 "provider_force_n": 700.0,
 "provider_range_m": 20.0,
 "provider_mass_kg": 120.0,
 "per_run_latched": [["bridge_down"], ["bridge_down"], ["bridge_down"]]}
```

**Three runs, all latching every promoted latch, at EXACTLY the
envelope.** Replaying above it proves a strong provider can solve the
puzzle, which is not the claim check 20 makes — a package that passes
must be solvable by *every* qualifying provider.

**`per_run_latched` is per run, not a union.** A record saying "all
three latched, and here is everything that latched somewhere" cannot
distinguish three good runs from three runs each latching a different
third of the requirement. That case is tested.

### 6.2a The content digest — one function, both sides

Counts, provider values and latch names do not describe what was
replayed, so a successful record from one package read as a pass for a
different package with different conditions. **`content_digest` closes
that, and it is identity and freshness, not authentication.** It does
not stop anyone forging a record; it stops a record that was true of one
thing being read as true of another.

**The producer and the validator compute it the same way.** The bridge's
implementation is `schemas/physics.py::canonical_bytes`, hashed by
`package_digest`; there is exactly one canonicalization per language and
a test asserts it (`test_there_is_one_canonicalization_in_this_language`).
Two implementations in one language is how the two stop agreeing.

1. Build this object, exactly these fields, exactly these names:

```json
{"package_id": "basin_bridge",
 "latch_conditions": [{"latch_id": "bridge_down",
                       "kind": "CONSTRAINT_STATE",
                       "detail": "hinge at rest below 5 degrees"}],
 "vector_latches": [0],
 "required_latches": ["bridge_down"],
 "setup": {"bodies": [{"body_id": "crate_a", "mass_kg": 80.0,
                       "constrained": false}],
           "scene_digest": "0123456789abcdef",
           "solver": {"iterations": 8, "fixed_step_hz": 60.0,
                      "settle_timeout_s": 8.0}},
 "reference_solution": ["push_crate", "wait_for_settle"]}
```

2. The two sequences are treated **oppositely, and deliberately**:
   - `required_latches` is a **set of names** → **sorted**. Two
     declarations of the same requirements must digest identically.
   - `vector_latches` is the state vector's **bit order** → **preserved
     as declared**. Sorting it would silently renumber the verifier's
     dimensions, which is a content change wearing a formatting mask.
3. Serialize as JSON with **sorted keys** and **no whitespace**
   (`separators=(",", ":")`), non-ASCII escaped (`\uXXXX`).
4. `sha256`, hex, **first 16 characters**.

`setup` and `reference_solution` are `null` when absent — **but a
load-bearing package may not have them absent**, see §6.2c. Everything
that could change what a replay proves is in there: the conditions
*including their detail*, which are promoted and in what order, which
are required, the bodies, the **scene digest**, the solver settings, and
the solution's steps. **Change any one and the evidence is stale and is
refused**, which is a prompt to re-replay rather than an accusation.

**One shared file, constructed by both lanes.**
`godot/tests/fixtures/physics_digest_vectors.json` holds nine vectors.
Each carries the structured `package` **input** as well as the expected
`canonical` string and `digest`.

> **Both lanes construct the package from `package` and run their own
> production serializer.** Hashing the stored `canonical` string proves
> the file is self-consistent and nothing whatever about the code — the
> serializer could drift and every vector would still pass. Comparing
> the canonical bytes *as well as* the hash is also what tells the two
> failure modes apart: differing bytes is a construction difference,
> matching bytes with a differing hash is a hashing one.

The vectors are chosen so each isolates one way to diverge, and so that
every rule above is load-bearing:

| Vector | Pins |
|---|---|
| a fully specified load-bearing package | the base |
| the same package with a moved scene | `scene_digest` reaches the digest |
| empty: no setup, no solution, no latches | absences serialize as `null` |
| unicode and punctuation in a detail | escaping agrees |
| integral floats, which must not print as integers | `80.0` is not `80` — the classic cross-language divergence |
| declaration order that differs from canonical order | input key order does **not** reach the output |
| several requirements and promotions, declared out of order | the multi base |
| the same requirements, declared already sorted | same digest → `required_latches` **is** sorted |
| the same latches promoted in a different bit order | different digest → `vector_latches` is **not** |

The last three exist because with one required latch and one promoted
index, `sorted()` and `list()` are interchangeable with each other and
with doing nothing at all: a vector set that cannot see a change to the
serializer is the same defect one level down.

**Generated, never hand-edited.** Regenerate with:

```
make physics-vectors        # cd bridge && python3 tools/physics_vectors.py
```

The generator calls `canonical_bytes` and `package_digest` — no second
copy of the recipe — so the file cannot drift from the serializer it
documents.

**What this cannot catch, stated plainly.** Python generating the file
and Python checking it is a closed loop for anything that is a *contract
change* rather than an internal inconsistency: change the separators and
regenerate, and the Python suite goes green. Only the Godot lane running
these same inputs closes it. The two ordering vectors survive a
regeneration (they assert relationships between vectors, not literals),
but the general case does not, and **regenerating this file is a
contract change that requires the engine lane to re-run.**

### 6.2b `scene_digest` — the part only the engine can compute

Body id, mass and constrained-ness are what the **contract** reasons
about. They are not what a replay **ran against**. Collision geometry,
initial transforms, static obstacles, gravity and layer masks can all
change while every field the bridge holds stays identical — and a
solution that latched before the crate moved two metres left is not
evidence about the room as it now stands.

**The bridge cannot compute this and must not try.** It has no scene,
and re-deriving a physical fact in Python is the thing the lane split
exists to prevent. The engine computes it over the actual replay setup
and supplies it; the bridge folds it into `package_digest` so a scene
change invalidates evidence exactly as a solver change does.

**Wire format: sixteen lowercase hex characters** (`^[0-9a-f]{16}$`),
the same shape as `package_digest`, enforced by `PhysicsSetup`. Only the
*output* shape is contracted — how the engine builds the string it
hashes is engine-owned, because the bridge must never be in a position
to re-derive it.

**A constant passes.** The bridge cannot tell a real scene digest from
`"0123456789abcdef"` repeated forever: both are sixteen hex characters
and both fold into `package_digest` identically. §6.2c catches a proof
over an *absent* setup; it cannot catch a proof over a *fake* one. That
is level 2, it belongs to the engine lane, and there is no validator on
this side that will ever substitute for it.

**Coverage — agreed with the engine lane before implementing, because
widening it later invalidates every existing record.**

| Included | |
|---|---|
| Geometry | every collider participating in the replay: shape, extents, transform |
| Initial state | each body's starting transform, linear and angular velocity, sleep state |
| Effective physics values | gravity, mass, friction, restitution, damping, layer and mask — **the values in force, including those inherited from project defaults or a shared material** |
| Static content | the room geometry the bodies interact with |
| Versioning | the Godot/physics-engine version and the construction version of the generator that built the scene |

| Excluded on purpose | |
|---|---|
| Visual-only materials | albedo, shaders, textures — anything with no collision consequence |
| Lighting | lights, probes, environment, post-processing |
| Decoration | props with no collider, decals, audio, particles |

**Five decisions only the engine lane can make.** Each one changes the
implementation, and each has a proposed default so the answer can be
"yes" rather than an essay. **Answer these before computing a real
`scene_digest`**; widening or re-quantizing afterwards invalidates every
record written in between.

| | Question | Proposed default |
|---|---|---|
| 1 | **Float quantization.** Transforms and velocities are floats. Digested raw, single-precision noise or a build change churns the digest; digested too coarsely, a real move hides | Round every length to **1e-4 m**, every angle to **1e-4 rad**, every velocity to **1e-4 m/s**, and format with a fixed decimal representation before digesting. Never digest a raw `float`'s printed form |
| 2 | **Are effective values actually readable?** The list says *effective, not overridden* — gravity from project settings plus area overrides, friction from a possibly-inherited `PhysicsMaterial`. If some of these cannot be read without stepping the sim, the list is wrong and must shrink | Read what is readable statically; for anything that is not, digest the **resource path plus its own digest** rather than the resolved number, and say so here |
| 3 | **What counts as "participating".** "Every collider participating in the replay" is not yet decidable, and an undecidable rule is two implementations that disagree | Every collider on the **collision layers the package's bodies test against**, within the room the package belongs to. Not a radius — a radius is a tuning constant that will drift |
| 4 | **Ordering.** Scene-tree order is not stable across saves, and an unordered digest makes the same scene digest differently on reload | Sort bodies by `body_id` and static colliders by **scene-relative node path**, both before digesting |
| 5 | **Versioning granularity.** "Construction/physics versioning" needs concrete sources | Godot version, **physics backend name and version** (Godot Physics vs Jolt are not the same experiment), and a **generator version constant** bumped by hand whenever scene construction changes shape |

Two of these are easy to get wrong and are called out for that reason:

- **Effective, not overridden.** Digesting only the values a node
  overrides means a change to the project default — the one that moves
  every body at once — leaves every digest untouched. The digest records
  what the solver actually used.
- **Versioning is part of the scene.** The same bodies under a different
  solver build are not the same experiment. A physics-engine upgrade
  must invalidate the evidence, and nothing else in the digest would
  notice it.

**The three levels, kept apart.** Each proves exactly one thing, and
none of them substitutes for another:

| Level | Artefact | Proves | Status |
|---|---|---|---|
| 1. Serialization agreement | the shared vectors, run through both production serializers | the two lanes build and hash the same bytes from the same input | **fixture-tested** — Python side done, Godot side owed |
| 2. Scene binding | `scene_digest` computed from the **real** setup, not a constant | the evidence names the scene it ran against | **not started** — needs a physics scene |
| 3. Physical outcome | replaying that setup and observing the latches | the puzzle is actually solvable as built | **not started** — needs a physics runtime |

Level 1 passing says nothing about level 2, and both passing say nothing
about level 3. The contract stays labelled **fixture-tested** until real
engine output passes through its actual acceptance path.

### 6.2c A proof of nothing is not a proof

Three green runs against no setup, no solution, or no required outcome
are three runs of nothing — and a digest over `null` is a perfectly
consistent digest of an absence. A **load-bearing** package (one with a
promoted latch, a required latch, or on a mandatory route) is refused
unless it has all of:

- a `setup` with **at least one body**;
- a `reference_solution` with **at least one step**;
- at least one `latch_condition`;
- on a mandatory route, at least one **`required_latch`**.

**`required_latches` and `vector_latches` are different questions.**
`vector_latches` is the verifier's budget — what it reasons about as a
state dimension. `required_latches` is what a mandatory route actually
depends on. A latch can be promoted without being required (it opens a
shortcut the search should know about); **the reverse cannot hold**,
because §23.1 says a latch left out of `vector_latches` is one nothing
on a mandatory route depends on. Required therefore implies promoted,
and the schema enforces that rather than leaving it to prose.

Evidence must show **every declared `latch_condition`** latching in
every run, not merely the promoted ones — §23.5 check 20's wording, and
the reason is that the verifier trusts the promoted ones on the strength
of the same solution.

**Latch identity.** `latch_id` is unique **within** a package and
nowhere wider; globally a latch is `package_id/latch_id`. Two packages
may both call a latch `bridge_down`; one package may not declare it
twice, because two conditions sharing a name are indistinguishable to
every consumer.

### 6.3 Sequence

Nothing above needs the full physics system. In order:

1. **A rigid body that rests and can be pushed** — the substrate. Until
   this exists nothing else can be measured.
2. **One verb resolving to force, range and mass** — enough to evaluate
   the envelope for one host.
3. **The headless replay harness** — three runs at fixed solver
   settings against a synthetic provider at exactly the envelope,
   reporting which `latch_id`s latched **per run**. **This is the
   deliverable the bridge is waiting on**; the schema for its output
   already exists and is validated.

**Before any of that, one small shared thing:** the nine vectors in
`physics_digest_vectors.json` passing in GDScript — **constructed from
each vector's `package` and run through the engine's own serializer**,
not hashed from the stored strings. It needs no physics at all — it is
JSON and sha256 — and it is what makes every later piece of evidence
mean something. Doing it first means the harness has somewhere to put
its answer on the day it works.

`scene_digest` comes next and needs a scene but no runtime: §6.2b is the
coverage list to agree before it is computed for real. Until then the
field is engine-supplied and the bridge only folds it in, so a constant
placeholder passes level 1 and proves nothing at level 2.

## 5.5 The way back into a Zone — bridge done, two lines owed by the Hub

**The lifecycle existed and the player could not reach it.** Walk out of
a Zone, restart, and this is what happened:

| | |
|---|---|
| the Zone | `DORMANT`, holding 15 allocated Checks, manifest and progress intact |
| `active_zone_id` | `None` — `rest_zone` clears it, because nobody is standing in the Zone |
| what the Hub said | **`ZONE_AVAILABLE` — "PORTAL READY — Epsilon is waiting to design your next Zone."** |
| what the portal did | sent `request_next_zone`, which the bridge refused: *"Zone 'zone_001' still holds locations; finish or abandon it first"* |
| the way out | abandon the Zone, losing its Checks and everything done in it |

A softlock reachable by ordinary play, with the Hub actively
recommending the one call that cannot work. **And a crash beside it:**
`hub_status` mapped three Zone states to modes and `VISITING` was not
one of them, so walking back into a finished Zone raised
`KeyError: 'VISITING'` out of the snapshot path — which every client
update goes through.

A comment in `protocol.py` explained why this was fine: DORMANT "pins NO
hub mode… going back is a separate affordance rather than a mode", and
"inventing a ZONE_DORMANT mode would put a Zone on screen that nobody is
standing in". Half of that is right — a dormant Zone is not the *active*
Zone. The other half assumed an affordance that was never built.
`ZONE_DORMANT` does not put a Zone on screen; it puts a **door** on
screen.

### 5.5a What the bridge now provides

- **`ZONE_DORMANT`** — the campaign holds a Zone and nobody is in it.
- **`ZONE_HELD_MODES`** now includes it (it blocks generation), and a new
  **`ZONE_OCCUPIED_MODES`** is the *other* question (`active_zone` is
  non-null). Those were one list, which is precisely why "held and
  unoccupied" could not be described.
- **`hub.resume_zone_id` / `resume_zone_name`** — which Zone the portal
  enters, filled for every mode in **`ZONE_ENTER_MODES`**
  (`ZONE_READY`, `ZONE_ACTIVE`, `ZONE_DORMANT`). One branch, one field.
- **`hub.revisitable`** — finished Zones the player may walk back into,
  newest first, as `{zone_id, display_name}`. Separate from
  `resume_zone_id` because they are different offers: at most one Zone is
  unfinished and blocks generation; any number of COMPLETE ones stay open
  and block nothing.
- **`ZONE_STATE_HUB_MODE`** is total over `ZoneState` by assertion, so the
  next lifecycle state cannot be forgotten into a `KeyError` in front of
  a player. `VISITING` maps to `ZONE_ACTIVE` — the snapshot invariant
  already said a revisit is the same experience as a first visit; only
  the producer disagreed.

Proved on this side, entering **only by what the snapshot exposes**
(reaching into `save.zones` for the id would prove the transition works
and nothing about whether the portal can find it):
`test_the_portal_can_find_the_zone_you_walked_out_of` and
`test_a_finished_zone_is_offered_back_and_counts_nothing_twice` —
restart, the Hub names the Zone, enter by that id, manifest digest,
collected keys and allocated Checks all intact; and a revisit that
reserves nothing and leaves `completed_zone_count` and `zone_history`
untouched.

### 5.5b The consumer change, for Prod to make

Two places, and deliberately small. **Neither lane should edit the other
side of this seam** — this is the proposal, not a patch.

**`hub.gd::_on_portal_activated`** — one arm gains a mode:

```gdscript
    "ZONE_READY", "ZONE_ACTIVE", "ZONE_DORMANT":
        enter_zone_requested.emit()
```

or, better, drive it off the constant so the next mode needs no edit
here: `if BridgeClient.hub_mode() in Constants.ZONE_ENTER_MODES:`.

**`main.gd::_on_enter_zone`** — take the id from the Hub rather than
from `active_zone()`, which is empty for a dormant Zone:

```gdscript
func _on_enter_zone() -> void:
    var zid := str(BridgeClient.hub().get("resume_zone_id", ""))
    if zid == "":
        return
    _entering_zone = true
    BridgeClient.send_intent({"type": "enter_zone", "zone_id": zid})
```

`resume_zone_id` is filled for `ZONE_READY` and `ZONE_ACTIVE` too, so
this one path replaces the old one rather than sitting beside it.

**What proves it, and it is the engine lane's to run:** restart with a
dormant Zone, press the portal, and arrive in the same layout with the
same keys, locks and Checks. This lane has no Godot; everything above is
the bridge half.

**Open for Prod:** `revisitable` can hold many Zones and the portal is
one object. Offering the dormant Zone on the portal and finished Zones
through some other affordance is the obvious split, but which affordance
is a Hub design question and is yours. The bridge exposes the list; it
does not assume a widget.


## 6. What remains in this lane

**The five conditions §0-bis puts on a legal capability gate**
(`docs/design-packet-v0.10/SOLUTIONS_CATALOGUE.md`), which is the real
scoreboard for this part of the Amalgam:

| | Condition | State |
|---|---|---|
| 1 | the matching AP location logic declares the same prerequisite | **enforced** — `reachability` searches under the guaranteed set and blames a gate when one is the reason |
| 2 | Archipelago proves the capability progression is obtainable | **blocked, and further than it looks** — see below |
| 3 | the physical Zone graph agrees with that AP logic | **enforced** — same search |
| 4 | the player can safely leave the blocked Zone | **enforced, and it always was** — by `R ⊆ E`. See the correction below |
| 5 | the Zone remains re-enterable | **enforced** by the lifecycle: DORMANT keeps the Zone's Checks and its committed manifest, and `enter_zone` replays it |

**A correction, because the previous version of this section was
wrong.** It said condition 4 "had no rule at all" and that a one-way
edge into a dead end "satisfied every check — the exit was reachable,
every Check sat in a reachable room, no key was behind its own lock".
None of that was true.

`R ⊆ E` asks, of every reachable state, whether the **exit** is still
reachable. `_escapable` asks whether the **entrance or the exit** is.
The first condition implies the second, so **there is no Zone that
`_escapable` refuses and `R ⊆ E` accepts** — it is subsumed by
construction. Worse, the fixture offered as proof deleted two spine
edges, so the exit was unreachable from *everywhere*, and three other
rules fired before either of them. The claim was made without checking
what the existing rules already caught, which is the same error as
claiming a corridor-ends-far-away case was refused when the test behind
it broke a chain in the middle.

**What `_escapable` does add**, which is why it stays. Among the states
`R ⊆ E` already refuses, it separates the two that mean different
things to a player:

| Situation | `R ⊆ E` | `_escapable` | What it is |
|---|---|---|---|
| exit gated, entrance reachable | refuses | passes | §0-bis's **"NOT YET is good gameplay"** — leave, find the capability, come back |
| exit gated, one-way edge in | refuses | refuses | the **dead run** the catalogue warns about |

`R ⊆ E` reports both with one sentence. The escape line says which one
it is. It never changes the verdict, and
`test_the_escape_check_never_refuses_what_r_subset_e_accepts` asserts
that rather than assuming it.

**And it is a backstop.** §0-bis explicitly permits the Zone exit itself
to sit behind a capability gate. Today a *declared* gate puts the
capability into the guaranteed set, so the exit is reachable and
`R ⊆ E` holds; the day that is relaxed to model a player who does not
hold the item yet, `_escapable` stops being subsumed and becomes the
only thing between that player and a Zone they cannot leave. The
subsumption test is what will notice.

### 6a. Condition 2 is blocked on something bigger than this lane

`reachability` takes `declared_capabilities`, and **nothing has ever
passed it** — not production, not one test. So the guarantee set is
always `BASELINE_CAPABILITIES`, and the rule that a gate must be
declared is, today, a rule that no gate can ever satisfy. A check that
can only refuse is as broken as one that can only accept; it simply
fails safe instead of failing open.

The reason is not a missing wire. **Capabilities are not Archipelago
items.** The apworld's pool is `Signal Key`, `Epsilon Coin`,
`Epsilon Static`, and its logic is tier-based on Signal Key count;
`grapple`, `blink` and `cross_long_gap` appear nowhere in it. §0-bis
condition 2 asks Archipelago to prove a capability progression is
obtainable, and Archipelago currently has no such progression to
reason about.

> **For the owner, not for this lane to decide.** Either Echo
> capabilities become AP items with their own logic — a real apworld
> change, pool and rules — or they stay outside the multiworld, in which
> case an AP-relevant route may never be gated on one and the guard is
> correctly a wall rather than a gate. Both are coherent; they are
> different games. Until it is settled, composition emits no gates, the
> rule is dormant, and the first gate to appear is refused rather than
> waved through.

### 6b. Still open

- The `manipulate` capability contract, `vector_latches`, and the model
  check's physics properties: blocked at the substrate — still zero
  `RigidBody3D` in the project, and the capability vocabulary
  deliberately omits `manipulate` so a Zone cannot declare a gate no
  build can satisfy.
- **One unfinished Zone holds locations at a time** — the current
  implementation limit, asserted by a test so lifting it is deliberate
  rather than accidental.
- Physical reachability stays the engine lane's: `R ⊆ E` is a graph
  property and cannot see a key inside a crate.
