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
| 1. Serialization agreement | the shared vectors, run through both production serializers | the two lanes build and hash the same bytes from the same input | **done 2026-09-12, both lanes** — `PhysicsPackage` in `godot/scripts/content/physics_package.gd`, checked in `godot-content`; all nine agree byte for byte |
| 2. Scene binding | `scene_digest` computed from the **real** setup, not a constant | the evidence names the scene it ran against | **computed 2026-09-12** — `SceneDigest` in `godot/scripts/content/scene_digest.gd`, falsified in `godot-content`; not yet called from a replay, because there is no replay |
| 3. Physical outcome | replaying that setup and observing the latches | the puzzle is actually solvable as built | **runs 2026-09-12** — `ReplayHarness`, three runs in `godot-physics`; no Zone authors a package yet, so nothing in a campaign has produced evidence |

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

1. ~~**A rigid body that rests and can be pushed**~~ — **done
   2026-09-12.** `ManipulableBody` (`godot/scripts/gameplay/`), measured
   by `make godot-physics`: it falls, comes to rest on the floor and
   sleeps, and a push wakes and moves it.
2. ~~**One verb resolving to force, range and mass**~~ — **done
   2026-09-12.** `Manipulation`. Identity stays Boolean and the newtons
   never reach the verifier: `grants_manipulate` answers §29.3.1, and
   `Envelope` resolves §29.3.2's three minima at the entry check and
   stores nothing. A refused push says WHICH of `out_of_reach`,
   `too_heavy`, `constrained` or `no_direction` it was, because "nothing
   moved" is the same report as a bug.
3. ~~**The headless replay harness**~~ — **done 2026-09-12.**
   `ReplayHarness`. Three runs, a fresh stage each, at the package's own
   `fixed_step_hz`, against a provider at exactly the envelope — the
   numbers are read from `Constants` and are not a parameter, because
   replaying above the envelope proves a strong provider can solve it,
   which is not the claim. Per run, never a union.

   Falsified: a solution that pushes the crate the wrong way latches in
   none of the three, and the harness reports that rather than what was
   hoped.

**Two vocabularies are the engine's, and here they are.** `detail` and
`reference_solution.steps` are opaque to the bridge by design — it never
re-derives a physical fact — which means nothing was written down about
what they say. They are:

| `kind` | `detail` | observed |
|---|---|---|
| `POSITION_REGION` | `<body_id> in <region_id>` | the body's origin inside the region |
| `WEIGHT_THRESHOLD` | `<plate_id> >= <kg>` | the total mass of bodies over the plate |
| `CONSTRAINT_STATE` | — | **refused**: no joints exist |
| `ATTACH_SENSOR` | — | **refused**: no attachment sensors exist |

| step | |
|---|---|
| `push <body_id> <dx> <dz> <seconds>` | one held push, at the envelope |
| `wait <seconds>` | |
| `settle` | until every body is at rest, bounded by `settle_timeout_s` |

**REFUSED IS NOT UNLATCHED**, and the distinction is load-bearing. A
latch kind with no runtime, a step nobody wrote, a body the stage does
not build — each comes back as a refusal naming what it was. Reporting
one as "did not latch" would be the harness saying the puzzle is
unsolvable, which is a verdict about the content instead of about the
harness.

**What building the substrate found.** §29.3.2 promises a host at
exactly `ENVELOPE_FORCE_N` can move a body at exactly
`ENVELOPE_MASS_KG`. Godot's default friction is 1.0, so a 120 kg body
resists with about 1176 N against 700 N of push — the contract promised
something the substrate refused, and a mandatory route authored at the
envelope would have been unsolvable by the host the verifier says
qualifies. The first run of `godot-physics` reported it in one line:
*700 N moved 120 kg by 0.00 m.*

A manipulable body therefore carries its own `PhysicsMaterial` whose
friction is **derived** from the envelope (two thirds of `F / m g`, so
the body accelerates rather than creeping) rather than chosen, and the
three constants are **exported to GDScript from `physics.py`** rather
than retyped into `constants.py` — two sources for one contract is the
drift the export mechanism exists to prevent.

~~**Before any of that, one small shared thing:** the nine vectors in
`physics_digest_vectors.json` passing in GDScript.~~ **Done
2026-09-12.** `PhysicsPackage` builds each vector's `package` and writes
its own canonical bytes; the test compares the BYTES and then the
digest, because a digest check alone cannot say whether two lanes built
different objects or serialized the same object differently.

Two things it needed that were not obvious. Godot's `JSON.stringify`
prints an integral float as `80` where Python prints `80.0`, and emits
non-ASCII directly where Python's default `ensure_ascii=True` escapes it
as `\uXXXX` — either alone produces a digest the bridge cannot match for
a package both lanes agree about in every other respect. So the engine
writes its own JSON rather than borrowing one.

Falsified two ways: half a kilogram of mass moves the digest, and a
package carrying a field the engine does not model is REFUSED rather
than dropped, because a producer that silently ignores a new field
digests less than the bridge hashes.

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
  enters, filled for every mode in **`ZONE_ENTERABLE_MODES`**, which is
  now `ZONE_READY`, `ZONE_ACTIVE`, `ZONE_DORMANT`. One branch, one
  field.
- **`hub.portal_enabled` is true for all three**, including with
  Archipelago down: the Zone is already on disk and entering it needs no
  round-trip. **This was the correction that mattered.** The first
  version added `ZONE_DORMANT` to a *new* constant while
  `portal_enabled` kept reading the old one — so the Hub said "your Zone
  is waiting", `resume_zone_id` said which one, and the button was
  greyed out. The game consumes `portal_enabled`; a mode branch in the
  consumer would not have fixed it. There is one constant now, and
  `test_naming_a_zone_and_lighting_the_portal_are_one_decision` asserts
  the two facts off the model so they cannot drift apart again.
- **`hub.revisitable`** — finished Zones the player may walk back into,
  newest first, as `{zone_id, display_name}`. Separate from
  `resume_zone_id` because they are different offers: at most one Zone is
  unfinished and blocks generation; any number of COMPLETE ones stay open
  and block nothing. **Uncapped** — it carried a 64-entry limit that
  `CampaignSave.zones` does not have, so a campaign that finished 65
  Zones had its whole snapshot refused. A `ZoneHandle` is an id and a
  name; several hundred is noise beside the fold in the same message, so
  no pagination is needed and none is invented.
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

### 5.5a-bis The other half of the restart — **done, on both sides**

**DONE 2026-09-12, and one line of it was on the bridge's side.** Both
consumer changes below landed; `make godot-reload` presses the real
portal in `ZONE_DORMANT` and lands back in the Zone it left.

The line the engine lane had to touch in `protocol.py`, flagged here
because it is the bridge's file: **`portal_enabled` was reading a second
list.** `ZONE_ENTER_MODES` gained `ZONE_DORMANT`; `ZONE_ENTERABLE_MODES`
— the same question, under a different name — did not, and
`portal_enabled` reads that one. So the portal showed the mode's prompt
and refused to fire: a way back into a Zone that is wired, labelled and
dead, and no test on either side could see it because each lane's half
was correct.

**Settled: one name, not an alias.** `ZONE_ENTER_MODES` is gone rather
than aliased — an alias is still two names, a reader who greps the dead
one finds a definition and may add to it, and the aliasing only holds
while nobody rebinds either. The surviving question is "what the portal
can enter without Archipelago", `portal_enabled` is its consumer, and
the engine's `HubController` spells it the same way.

Two places, and deliberately small. **Neither lane should edit the other
side of this seam** — this was the proposal, and the engine lane took
it.

The manifest survived a restart and the progress did not: `main.gd` read
keys, locks, stations and the resume point out of its own in-memory
dictionaries, which a new process starts empty. Same rooms, every key
back on the floor.

**The engine lane found and fixed this independently, at `fa5f056`, and
their fix is better than the one written up here.** `_to_zone` reads
`record.progress` and `_union_progress` converts the saved arrays into
the runtime dictionaries — **as a union with the in-memory half, not a
replacement**, because an intent sent in the same breath as leaving may
not be in the snapshot yet. Both sides are monotone sets, so taking both
cannot lose progress and cannot invent it. That is a case this lane's
write-up did not consider.

**What this lane got wrong, and has reverted.** `ZoneReady.progress` was
added here as the carrier. It is not the one the game reads: `_to_zone`
is driven by `_on_snapshot`, and takes both the layout and the progress
from `BridgeClient.active_zone()` — the snapshot's `ZoneRecord`, which
has carried `progress` since it existed. Adding a field to `ZoneReady`
made **a second carrier for one fact on a different message**, which is
the failure this document describes two sections earlier about
`ZONE_ENTER_MODES`, committed again one commit after writing it down.
Reverted; the record is the carrier.

The regression coverage stays and now asserts the carrier in use: after
a restart and a re-entry, the **serialized snapshot's**
`active_zone.progress` carries the collected keys and opened locks, and
`active_zone.manifest` the committed digest.

> **One thing for Prod, not a change request.** The comment above the
> manifest read in `_to_zone` says "`ZoneReady` carries the manifest",
> while the line beneath takes it from the snapshot record. Both
> carriers do exist — `ZoneReady.manifest` is real and emitted — so the
> comment is describing a path the code does not take. Worth a look
> when convenient; whether `ZoneReady.manifest` should stay at all is
> the engine lane's call, since it is their consumer that decides.

### 5.5b The dormant portal — **done 2026-09-12, engine lane**

**Scope was the dormant Hub portal and `resume_zone_id` routing, and
nothing else.** Progress restoration was folded in here once and
removed — the engine lane had already done it (§5.5a-bis). Both changes
below landed; `make godot-reload` presses the real portal in
`ZONE_DORMANT`, across a restart of BOTH processes, and lands back in
the Zone it left. The proposal is kept as written because it is what was
taken.

**DONE 2026-09-12, and one line of it was on the bridge's side.** Both
consumer changes below landed; `make godot-reload` presses the real
portal in `ZONE_DORMANT` and lands back in the Zone it left.

**Both lanes found the same last obstacle, from opposite ends.**
`portal_enabled` was reading a second list: one of two near-identically
named constants gained `ZONE_DORMANT` and the other did not. From the
bridge it looked like a button greyed out over a Zone the Hub was
naming; from the engine it looked like a portal that showed the mode's
prompt and refused to fire. No test on either side could see it, because
each lane's half was correct.

There is one name now — `ZONE_ENTERABLE_MODES`, the bridge's spelling,
which `portal_enabled` reads — and `HubController` spells it the same
way. The alternative (two tuples kept equal by hand) is the same defect
waiting for the next mode.

Two places, and deliberately small. **Neither lane should edit the other
side of this seam** — this was the proposal, and the engine lane took
it.

**`hub.gd::_on_portal_activated`** — one arm gains a mode:

```gdscript
    "ZONE_READY", "ZONE_ACTIVE", "ZONE_DORMANT":
        enter_zone_requested.emit()
```

or, better, drive it off the constant so the next mode needs no edit
here: `if BridgeClient.hub_mode() in Constants.ZONE_ENTERABLE_MODES:`.

Nothing is needed for the *enabled* half — `portal_enabled` already
carries it, and that is the field `hub.gd` reads at line 754.

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

**Progress restoration is NOT in this task.** It was, and the engine
lane had already done it at `fa5f056` — see §5.5a-bis. Nothing is owed
there.

**The serialized offer, which is the contract.** Proved on the wire in
`test_the_portal_can_find_the_zone_you_walked_out_of`, against
`snapshot().model_dump_json()` rather than the Python objects:

```json
"hub": {
  "mode": "ZONE_DORMANT",
  "resume_zone_id": "zone_001",
  "resume_zone_name": "…",
  "portal_enabled": true,
  "accepts_zone_request": false,
  "revisitable": []
}
```

and the same with `"ap_online": false` — the mode does not move, the
portal stays lit, the Zone id is still there.

**What proves it end to end, and it is the engine lane's to run:**
restart with a dormant Zone, press the portal, and arrive in the same
layout with the same keys, locks and Checks. This lane has no Godot;
everything above is the bridge half.

**Open for Prod:** `revisitable` can hold many Zones and the portal is
one object. Offering the dormant Zone on the portal and finished Zones
through some other affordance is the obvious split, but which affordance
is a Hub design question and is yours. The bridge exposes the list; it
does not assume a widget.


## 5.6 Environmental agency: where a physics package may live

**The engine half exists.** `ReplayHarness.replay` returns exactly the
`ReplayEvidence` shape this lane already validates — `package_id`,
`content_digest`, the three provider values, `per_run_latched` — and
refuses with a reason when a package has no setup or no reference
solution. What is missing is the other end: **nothing produces a
package**, so the harness has nothing to replay and the evidence gate
has nothing to gate.

This lane owns package validation, acceptance plumbing and the
persistent consequence. Before writing them it tried the obvious
placement — `Chamber.packages`, beside `keys`, additive and empty — and
**a guard refused it, correctly**:

```
these fields let Epsilon say an arbitrary string:
    LatchCondition.detail
    PhysicsPackage.required_latches
    ReferenceSolution.steps
    ReplayEvidence.per_run_latched
```

`test_epsilon_vocabulary` walks the Zone schema as **Epsilon's output
surface**, because the Zone is what a creative provider fills. Two of
those four are safe under the existing precedent — `required_latches`
and `per_run_latched` are charset-constrained ids resolved against a
declaration in the same object, exactly like `edge_id` and `key_id`.
**Two are not.** `LatchCondition.detail` is what the engine must
observe, and `ReferenceSolution.steps` is the engine's own script. A
provider that can write those is a provider authoring a physical claim,
which is the lane boundary itself: *Epsilon emits validated structured
creative interpretation only.*

So the placement was wrong and the field is not in the tree. The
carrier is the open question, and it is genuinely joint:

> **For Prod.** A package has to reach the engine, and it must not be
> reachable by Epsilon. Three shapes, and the choice decides what this
> lane builds:
>
> 1. **Composer-written, on the Zone.** Packages land where `doors`,
>    `edges` and `plugs` land — added by `topology.apply` after
>    acceptance, so the provider never sees the field. Needs the
>    vocabulary guard taught that these fields are composer-owned, the
>    same exemption `edge_id` already has and for the same reason.
> 2. **Beside the manifest.** A package is physical, like the layout, so
>    it travels with `layout_result`/the committed manifest rather than
>    with the Zone. Fits "the engine owns physical truth" and means a
>    package is part of what a re-entry replays.
> 3. **Its own carrier.** Rejected here unless one of the above fails:
>    the brief is explicit that competing truths beside `ZoneReady` and
>    the snapshot are what this seam keeps getting wrong.
>
> Whichever it is, the bridge's half is the same and is ready to write:
> `PhysicsPackage` validation at acceptance via `check_physics_content`,
> a `latch_fired` intent validated against packages the Zone actually
> declares (the `record_key`-accepts-anything defect, not repeated), and
> `ZoneProgress.latched` as a monotone set that survives a reload —
> §5.7's "never cleared by reset or death" includes quitting.
>
> **Nothing becomes load-bearing on the way.** A latch is recorded
> before any route depends on one, and what a route may depend on waits
> on `AP_CAPABILITY_LOGIC.md` §8. **And movement qualification stays
> separate**: `CROSSING_EVIDENCE` is not populated from a physics
> replay. A package proving a crate moves says nothing about how far a
> dash carries a body, and the two contracts do not establish each
> other.


### 5.6a Option 2 taken — a package travels with the layout

**Owner direction, 2026-09-12: option 2.** A package is a physical fact,
so it moves the way the layout moves. Implemented on the bridge side;
what the engine owes is at the end.

**The path.** The engine resolves the Zone's bounded intent into a real
setup, measures it, replays it, and offers the result inside
`layout_result` as `layout["packages"]` — a list of `PlacedPackage`.
`layout.validate` is where it is checked, so it goes through the same
**validate-then-commit** gate the layout does, and an accepted package
is written into the manifest under the same `manifest_digest`. Nothing
is on the Zone, so `test_epsilon_vocabulary` never walks it and the two
fields that refused the first attempt — `LatchCondition.detail` and
`ReferenceSolution.steps` — stay out of Epsilon's reach by
construction rather than by exemption.

**Three identities, all resolved against the Zone.** `zone_id` is the
Zone the layout was offered for; `room_id` is a room it declares;
`content_ref` is `feature:<tag>` or `shell:<shell_id>` and must name
content that room declares. Neither half of that vocabulary is new. A
package that parses, describes a real mechanism, and is attached to the
wrong thing is the failure the wrapper exists to make impossible.

**A bad package refuses the layout and is never dropped.** Committing
the manifest without it would build the room and leave the mechanism
inert — the content the engine asked for, quietly downgraded, with
nothing saying so. Load-bearing or not: the engine declared it.

**`check_physics_content` runs over the accepted set**, which is where a
load-bearing latch with no evidence, evidence recorded for another
package, and evidence for another revision of this one are each refused.
`local_keys` is passed because it is a real dimension with a real count;
the rest of the state vector is the verifier's budget question and
nothing derives it from a Zone yet, so what is checked there is a
**floor** rather than the whole vector, and the code says so.

**The consequence, and only the approved one.** `latch_fired` is a
client intent; `record_latch` checks it against the packages the
committed manifest accepted and only then adds
`package_id/latch_id` to `ZoneProgress.latched` — monotone, idempotent,
and persisted, because Design 2 §5.7 says a satisfied latch is never
cleared by a reset and quitting is a reset. The live signal is not
state. **One carrier**: `ZoneProgress` on the `ZoneRecord` the snapshot
already carries and `main.gd::_to_zone` already reads. Nothing was added
to `ZoneReady`.

**Nothing became load-bearing.** No engine produces evidence yet, so
every load-bearing package is refused — which is the accessibility
guarantee stated as a test rather than as a promise
(`test_a_load_bearing_package_without_evidence_refuses_the_layout`).
`CROSSING_EVIDENCE` is untouched: a package proving a crate moves says
nothing about how far a dash carries a body.

> **What the engine lane owes, concretely.** Emit `layout["packages"]`
> from `zone_builder`/`ReplayHarness` as a list of
> `{package_id, zone_id, room_id, content_ref, package}` — the wrapper
> is `schemas/physics.py::PlacedPackage` and `package` is the shape
> `physics_package.gd` already builds. Send `latch_fired` when a latch
> the accepted package declares is satisfied. Two things are NOT
> requested: any field on the Zone, and any second carrier for what a
> player has latched.


### 5.6a-bis ANSWERED by the engine lane, 2026-09-12: it emits them

**What the engine owes is paid.** `ChainCertificate`
(`godot/scripts/gameplay/chain_certificate.gd`) builds a
`PhysicsPackage` for every `powered_door` a room declares, replays it
three times at exactly the manipulation envelope, and
`layout_to_json` sends the result as `layout["packages"]` — the
`PlacedPackage` wrapper above, `content_ref: "feature:powered_door"`,
with the `ReplayEvidence` inside the package where the model already
has a field for it. No second carrier, and nothing on the Zone.

**It replays IN THE ROOM, on the real chain.** The room's own crate and
its own plate, reset between the three runs and put back afterwards. A
reconstruction on a clean floor agrees with the generator by
construction; the failure worth catching is the one where the composer
put something between the crate and the plate, and
`godot-room-contract` drops a slab there and requires the certificate
to stop. The latch is a `WEIGHT_THRESHOLD` naming the plate and its
kilograms, because that is what `PoweredLink` reads every physics
frame. `setup.scene_digest` is the real `SceneDigest` over the room,
taken after the crate has settled and been zeroed so the setup is the
same setup every time. It costs about five seconds of Zone-entry time
per chain, inside the hold the player is already under.

**And three checks were added to `_packages`, because
`check_physics_content` deliberately skips these.** Its subject is
progression guarantees, so it passes over every package that is not
load-bearing — and a chain guarding a note is not. On its own it would
have accepted every chain in silence, which is this project's recurring
defect: a measurement that exists, is correct, and is never handed the
case that fails it. `_certified_features` asks the three it skips:

| check | why |
|---|---|
| one package per declared `powered_door` | the inverted probe: a room that declares a chain and offers nothing has either failed to build it and not said so, or built it and not replayed it |
| its evidence passes `evidence_fault` | the same function `check_physics_content` calls, asked of the packages it skips — one implementation, two callers |
| the package is not load-bearing | §13.2 forbids a feature on the mandatory path; a package claiming a route depends on it claims the opposite of what the affordance contract promises |

**A chain the engine could not build or could not replay is not
offered, and the absence is what refuses the layout.** Warned loudly
engine-side, refused bridge-side by the count. Dropping it quietly
would build the room and leave the mechanism inert — the downgrade this
carrier exists to make impossible.

**Still owed by this lane:** `latch_fired` when a player satisfies a
declared latch. The chain's consequence today is the local reward
behind the door, which rides the validated path every reward does.


### 5.7 The return pad stood where the player lands

**Engine-lane finding, integrated build, 2026-09-12.** `ReturnPlug` is
an `Area3D` firing on `body_entered`, and the composer anchored it at
`room:<rid>:arrival` — which is exactly where `zone_builder` stands a
body entering the room (`anchors["room:%s:arrival"]` is the room's own
`player_entry`, carried into world space). So walking into a side
destination triggered the return on the first frame, every time, and
re-entering did it again. **The device was right, the edge was right,
and the anchor was the place the player is standing.**

**The composer names `room:<rid>:return` now.** `ROOM_ANCHOR_KINDS` has
two entries; the composer still names only an anchor and no world
coordinate appears in this lane.

**Where `:arrival` is kept, and why.** It stays a legal anchor form.
`ZoneRecord.zone` is a typed `Zone`, so refusing that spelling in the
model would refuse to LOAD every save already holding a branched Zone.
The defect is caught in `layout.validate` instead — rule 4b — which a
committed manifest never runs again. So:

* a Zone with a committed manifest keeps exactly the devices it was
  certified with, and nothing repositions anything inside one;
* an accepted-but-unplaced Zone is refused and recomposed, which is the
  recovery path a refusal already has;
* **already-committed saves keep the old placement**, and the repair
  reaches them on their next Zone. Said out loud rather than hidden.

**What rule 4b requires.** That the plug does not stand on its room's
arrival, and that the engine has MEASURED the separation:
`plug_clear[edge_id]` is a boolean per plug, true when a body standing
at the room's arrival is outside that device's trigger volume. Missing
is a refusal, not a pass — a distinct anchor is not evidence, the same
way a coordinate is not evidence a capsule fits.

> **For Prod — the engine half, and the smallest version of it.**
>
> 1. **Reserve the spot with the contract that already exists.**
>    `ChamberBuilders._clear_spot(width, depth, claimed, seed)` is what
>    reconciles key spots and the reward pedestal against the room's own
>    furniture, and it CLAIMS the space so nothing else lands there.
>    A return spot is the same kind of thing, and the comment beside
>    `key_spots` already says why: "the builder knows where it put its
>    furniture, so the builder is what reconciles them." An offset from
>    the arrival is not this — it can land in a crate, in a wall, or
>    outside the room.
> 2. **Publish it** as `anchors["room:<rid>:return"]`, for every room
>    the Zone gives a plug. An unpublished anchor is already refused
>    here (rule 4), so nothing silently skips a return the way
>    `zone_builder`'s `push_warning` does today.
> 3. **Measure and report `plug_clear`**, one boolean per plug, the way
>    `arrival_ok` and `apertures` are reported.
> 4. **Clearance is yours to set**, because it is `ReturnPlug.RADIUS`
>    plus the player capsule plus whatever margin you want. This lane
>    does not spell an engine number: it asks for the verdict.
>
> **These two halves must land together.** A branching Zone composed
> here names `:return`, and until the engine publishes it rule 4
> refuses the layout — loudly, naming the anchor. That is the
> coordination cost of the repair and it is visible rather than silent;
> ordering it any other way means either a vacuous rule or leaving the
> trap in.
>
> Also yours: the player test. Enter normally, reach the room's
> content, deliberately take the return exactly once, and re-enter.


### 5.7a The lifecycle after every layout attempt fails — driven, not read

Asked for alongside §5.7. Driven through `handle_layout_result` and the
Hub, because every existing test of this path calls `T.refuse_layout` on
the save directly and so proves the transition works while saying
nothing about what a player reaches.

**Two things are correct and now have controls.**

* **A never-accepted Zone and a committed one are properly distinct.**
  The fresh proposal is recomposed twice and then goes DORMANT holding
  its Checks; a Zone with a manifest keeps the manifest, its content and
  its progress, and is never sent back to be composed again. The
  committed one is not erased to recover the failed one.
* **The locations are recoverable and the campaign is never stuck.**
  From DORMANT, `abandon_zone` returns them to the pool, the Hub goes
  `ZONE_AVAILABLE`, and the next Zone generates and draws on those ids.

**Two defects, both AUTHORISED and repaired** — see §5.7b. They are
kept here as the diagnosis.

1. **The Hub's only offer after exhaustion is the loop.** In
   `ZONE_DORMANT` the portal is enabled and `resume_zone_id` names the
   exhausted Zone, so the affordance on screen is "RETURN TO ZONE" —
   into geometry the validator has refused three times. Entering
   succeeds, the client asks for a layout, it is refused, and the Zone
   goes DORMANT again. `layout_refusals` is never read after the third,
   so *"and it stops"* stops the RECOMPOSITION and not the loop. The
   escape (abandon) exists and is reachable; nothing points at it.
   Whether the fix is a Hub affordance, a `layout_state == "REFUSED"`
   arm on entry, or a notification is a design call, not mine to make.
2. **The refusal counter outlives its bound.** `layout_refusals` is
   `le=99` and incremented on every refusal without limit; the 100th
   raises `ValidationError` out of `refuse_layout`. Milder than it
   looks — `_apply` is never reached, so the save is unchanged and the
   player can still abandon — but it is an exception where a refusal
   belongs, and it is only reachable because of defect 1.


### 5.7b The failed Zone is a Zone to discard — **done, bridge side**

**Owner decision, 2026-09-12**, on both §5.7a findings.

**A Zone whose layout attempts are exhausted and which never had an
accepted manifest is not enterable.** `ZoneRecord.layout_exhausted` is
the predicate: no manifest, `layout_state == "REFUSED"`, and the budget
spent. Three facts already in the record, read together — **no fourth
field and no new `ZoneState`**, because a second place recording the
same thing is a place it can disagree with itself.

`hub_mode_for(record)` is the ONE function that turns it into a Hub
mode, and the mode is `ZONE_FAILED`: derived on every snapshot, never
stored. It is in `ZONE_HELD_MODES` (the Zone still reserves its Checks)
and deliberately in neither `ZONE_ENTERABLE_MODES` nor
`ZONE_REQUEST_MODES`, so `portal_enabled` and `accepts_zone_request` are
both false without anything setting them. `enter_zone` refuses it at the
transition as well, so a replayed intent or a debug command cannot route
around the Hub.

**The offer is to discard, and `abandon_zone` already is that
transition.** Nothing is abandoned automatically: releasing the
locations is a decision with a cost. Afterwards the ids come back
through `abandon_zone` and no other path, the Hub may request the next
Zone, that Zone may allocate the released ids, and the discarded Zone
stays discarded. All of it asserted through the handlers.

**The budget is spent exactly once.** `layout_refusals` saturates at
`MAX_LAYOUT_REFUSALS` — which now has ONE definition, in `protocol`,
read by the transition that spends it and the record that reports it
spent — and a further `layout_result` for an exhausted Zone is an
ignored stale result: no notification, no recompose, and the save
object is unchanged. 120 retries leave the field at 3 and the save
loading. A resend after a dropped connection is the ordinary case.

**A committed Zone is never swept in.** Its replay may be refused any
number of times; it keeps its manifest, saturates the same counter,
stays `ZONE_DORMANT` and stays enterable.

> **For Prod — the Hub half, in one console.**
>
> `hub.gd` already has the control. `AbandonConsole` has the wording
> ("[E] ABANDON HELD ZONE"), the confirm step ("CONFIRM ABANDON? —
> unclaimed Checks return to the pool") and the intent. Two changes,
> and **no second control and no duplicated campaign state.**
>
> 1. **`_visible_modes` gains `"ZONE_FAILED"`.** It is currently
>    `["GENERATING", "ZONE_READY", "ZONE_ACTIVE"]`, so the console is
>    hidden for a Zone nobody is standing in — which is every failed
>    one.
> 2. **Resolve the target CONDITIONALLY.** In `ZONE_FAILED`, take it
>    from `hub.discard_zone_id` (and `discard_zone_name` for the
>    label): a failed Zone is DORMANT, so `BridgeClient.active_zone()`
>    is empty and the console would have nothing to send. **In the
>    three modes the console already serves, keep the resolution it
>    already has.**
>
> **`discard_zone_id` is populated in `ZONE_FAILED` and nowhere else.**
> Measured, not assumed — `ZONE_READY`, `ZONE_ACTIVE` and a committed
> `ZONE_DORMANT` all report it empty. So replacing the lookup
> unconditionally would give the existing modes a console that shows its
> prompt, arms its confirmation and does nothing: a control that
> displays and does not act, which is the failure this whole batch has
> been about. **Owner correction, 2026-09-12** — this section said
> "take the id from `discard_zone_id`, not from `active_zone()`", which
> read as a replacement, and that was this lane's error rather than a
> misreading.
>
> The field is deliberately not populated in the other modes. Its
> meaning is "the Zone the Hub is offering to discard because it cannot
> be entered", and widening it to "any Zone you could abandon" would
> make one name answer two questions — which is the shape of every
> defect this seam has produced.
>
> **And it is now an invariant, not a sentence.** `HubStatus`
> refuses a `discard_zone_id` outside `ZONE_FAILED` and refuses
> `ZONE_FAILED` without one, so the conditional this section asks for
> is guaranteed by the model rather than by anyone remembering.
>
> No matching rule exists for `resume_zone_id`, and one must not be
> added: it is legitimately set in `GENERATING`, which is not in
> `ZONE_ENTERABLE_MODES`, so the symmetric-looking invariant is false.
> It was written, refused by 128 tests, and removed.
>
> **Arm against the id, and disarm when it changes.** A confirmation
> armed for one Zone must not apply to another: reset it when the
> resolved target changes or goes away (a restart, an abandon from the
> pause menu, a Zone that left the mode). The console holds the arming;
> the bridge holds no notion of it, and should not.
>
> Nothing else changes. `_on_portal_activated` needs no new arm:
> `ZONE_FAILED` is not in `ZONE_ENTERABLE_MODES`, the portal is
> disabled, and the headline already says "ZONE FAILED TO BUILD — It
> could not be laid out. Discard it to return its Checks to the pool."
>
> **The only way to make this wrong is to leave the player a mode with
> no usable control**, so if the console cannot be shown in
> `ZONE_FAILED`, say so rather than adding a second way in. A correct
> snapshot and a console with no reachable target are not a recovery.


### 5.8 A destination needs no departure — the Terminus

**Owner finding against Art's batch 044, 2026-09-12.**
`shell_bay_terminus` declares `entry`, `branch_east` and `branch_west`,
and **no `exit`**; its `shape_tags` are "destination" and "dead_end".

**What it did, measured before repairing it.** `compose_with_branch`
called `compose_chain` first as a feasibility gate, and `compose_chain`
requires an entry/exit pair from EVERY room — so a leaf-compatible room
was refused as a through-room before it could ever be chosen as a leaf.
The Zone came back with **zero edges and every one of the Terminus's
openings SEALED**: a linear fallback with the destination walled shut,
and a single note the only thing that said so.

**Roles are decided before anything is composed.** `_role` reads the
room's own declaration:

| declares | role | may be |
|---|---|---|
| `entry` + `exit` | `ROLE_THROUGH` | on the spine, or a destination |
| `entry`, no `exit` | `ROLE_LEAF` | a destination only |
| no `entry` | `ROLE_UNJOINABLE` | refused |

`entry` and `exit` are not two names among many: the contract gives each
one meaning, and the engine's `socket_by_id` aliases them to a connector
grammar's `end_a`/`end_b` for exactly that reason. A shell declaring
`exit` says *the chain may continue through me*; one declaring an
arrival and no `exit` says *the chain arrives and stops*. That is a
capacity fact already on the wire.

**`shape_tags` is not consulted and does not reach this lane.** A role
read off authored prose could disagree with the openings the room
actually has; the openings are the thing the composer must assign.

**A leaf is a REQUIRED destination, not a budgeted one.** It is placed
before the spare-room budget picks anything and does not spend it —
refusing to branch would seal it shut. A leaf may not be the Zone's
first or last room (it would have to carry the chain), and a leaf no
room before it can host **refuses the Zone with a reason**. Nothing is
fabricated, nothing is cut, and there is no silent linear fallback: all
three are refusals with the room named.

**A leaf that hosts one onward branch departs by a real opening.**
`depart_edge` resolves through `doors` to `branch_east` — a doorway the
shell declares — so the engine places the continuation from there. This
is why fixing `_exit_offset`'s fallback alone was insufficient: the
manifest still carries `exit_offset: [0, 0, 22]` for a room with no exit
socket, and the fallback is a departure through a wall. The selector is
the fix, and it landed in §11.7.

**A capability probe, not a promotion.** No shell in the shipped
registry lacks `exit`, so ordinary generation cannot produce this today.
What is proved is that the producer path handles the capacity when a
shell declaring it arrives — a separate question from whether a pending
asset may be offered, and this section grants nothing on that.

> **For Prod — what the bridge now sends, and what is yours.**
>
> A leaf arrives through `entry` and carries a return plug like any
> dead end. Its unused declared openings are `SEALED` and its `doors`
> list every one of them; none is invented. `arrive_edge` names the
> inbound edge and `depart_edge` is **absent** unless the leaf hosts
> exactly one onward branch, in which case it names that branch's edge
> and resolves to a real doorway.
>
> Yours: the physical placement — that the body arrives through the
> assigned opening in a rotated placement, that the sealed side
> doorways are built closed, and that nothing reads `exit_offset` for a
> room with no exit socket. The bridge will not fabricate the departure
> that field implies.


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

### 6a. Conditions 1 and 2 need an Archipelago decision

`reachability` takes `declared_capabilities`, and **nothing passes it**
— not production, not one test. So the guarantee set is always
`BASELINE_CAPABILITIES` and the rule that a gate must be declared is one
no gate can satisfy. It fails safe rather than open, and composition
emits no gates, so nothing is wrongly refused today.

The reason is not a missing wire. **Capabilities are not Archipelago
items**, and the thing that produces them is Epsilon interpreting
whatever the multiworld gave you — a random reward, which is not a proof
of obtainability whatever it happens to yield.

**The proposal is `docs/AP_CAPABILITY_LOGIC.md`**: the acquisition chain
traced end to end, explicit capability items compared against guaranteed
local acquisition represented in AP logic, and for each the three things
that have to hold — where the guarantee comes from, how specific
location rules match it, and how a qualifying provider actually reaches
the player. It ends with the owner choice, which is real: the two
options are different games. It also names one repair owed under either
— `_capability_is_satisfied` tests primitives only, so a 2-metre dash
satisfies `cross_long_gap` and a gate is proved against the wrong claim.

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

### 5.4a ANSWERED by the engine lane, 2026-09-12: yes, and it is done

**Yes.** `r:<room>` is filed with doorway endpoints now, and this lane's
special case can go.

`zone_builder._joins` emits:

| field | was | is |
|---|---|---|
| `socket_a` | the room's own `position` | the chain's FIRST piece's `entry` |
| `socket_b` | the room's `arrival`, metres inside | `door_world["<room>/entry"]`, the doorway |

So `socket_a -> chain -> socket_b` closes exactly, the way `e:__exit__`
does, and the first room's approach stops being the one corridor checked
more loosely than the rest. Delete the branch in `_check_reserved_join`
and walk it like a `JOINED` edge.

**Two fallbacks, both narrow and both stated.** A room whose chamber
declares no `doors` at all has no `door_world` entry — the pre-graph
shape — and falls back to the room's `position`; a room placed with an
EMPTY chain has `socket_a == socket_b`, which is a zero-length walk and
should pass rather than refuse. Neither arises in a composed Zone; they
are there so a legacy fixture does not become unbuildable.

The reason it was the old shape was not a decision: `_joins` was written
before every producer emitted a door plan, so `door_world` had nothing
for the head room and the only points available were the transform's.
That changed when `_doors_from_bounds` landed and nothing went back to
look.

### 6.2b ANSWERED by the engine lane, 2026-09-12

All five defaults are **accepted**, with one narrowed and one widened.
None of this is implemented yet — this is the agreement §6.2b asks for
before a real digest is computed, so that the first record written is
already under the final rule.

**1. Float quantization — accepted as proposed.** 1e-4 m, 1e-4 rad,
1e-4 m/s, fixed decimal representation, never a raw float's printed form.
The engine-side reason to be comfortable with 1e-4: `EPSILON_JOIN` is
1e-3 m and `MAX_VERTICAL_STEP` is 1.0 m, so a quantum is an order of
magnitude below the tightest distance anything in this game reasons
about, and four below the smallest one a player can feel.

**2. Effective values — accepted, and here is which are readable.** In
Godot 4.5 the engine can read statically: `ProjectSettings`
`physics/3d/default_gravity` and `default_gravity_vector`;
`RigidBody3D.mass`, `gravity_scale`, `linear_damp`, `angular_damp` and
their `*_damp_mode`; `collision_layer` and `collision_mask`. Friction and
restitution live on a `PhysicsMaterial` that may be null, inherited, or
shared — so those follow the proposal exactly and are digested as
**resource path plus the resource's own digest**, never as a resolved
number. `Area3D` gravity overrides are read from the areas themselves and
digested as (path, mode, value, priority); resolving what a body actually
experiences requires stepping the sim, and a digest must not step
anything.

**3. "Participating" — accepted and NARROWED.** Every collider on the
collision layers the package's bodies test against, within the room the
package belongs to — plus, explicitly, **the connector pieces named in
that room's join chain**. The narrowing is the word "room": a Zone is one
scene, so "within the room" needs the room's committed world `bounds`
from the manifest to be decidable at all, and that is what the engine
will use. Not a radius, agreed, and for the reason given.

**4. Ordering — accepted as proposed**, with one addition. Bodies by
`body_id`, static colliders by scene-relative node path. The addition:
node paths must be taken relative to the **room's** root rather than the
Zone's, because a Zone re-entered after a different number of rooms were
placed gives the same room a different Zone-relative path. That is the
same bug class the ordering rule exists to close.

**5. Versioning — accepted and WIDENED by one field.** Godot version,
physics backend name and version, and a hand-bumped generator constant.
The addition: the **shell registry digest** for any authored shell whose
geometry is in the room. Arty regenerates shells from Blender source and
a repaired collider changes the experiment without touching any engine
constant — 2026-09-12's threshold repair moved `shell_yard_gantry`'s
floor 1.20 m and bumped no version anywhere. A generator constant a human
remembers to bump cannot cover a lane that ships geometry independently.

**And the level-2 hole is acknowledged as the engine lane's.** A constant
passes the bridge's check; nothing on that side will ever catch a fake
digest. What catches it here is the same shape as the crossing control
in `room_contract_driver`: a digest is only evidence if changing the
scene changes it.

**Implemented 2026-09-12** as `SceneDigest`, under exactly the five
answers above, and falsified four ways in `godot-content`: the same room
built in a different node order digests the same; a collider moved by
1e-3 m digests differently; a move a tenth of the quantum does not; and a
body that starts the replay moving digests differently from one at rest.
Without those the function is a constant with extra steps.

Two things the implementation taught, recorded because they change what
the answers above claim:

* **The digest is of the SETUP, before anything is stepped.** A body
  still falling when the digest is taken makes the digest a moment
  nobody can reproduce. The bodies therefore carry their starting
  transform, velocity and sleep state, and a replay harness digests
  before it runs.
* **The shell registry digest is the weaker half of decision 5, not the
  strong one.** The reason given for adding it was Arty's threshold
  repair, and the collider enumeration is what actually catches that:
  `yd_threshold_±1` added colliders while `size` and the sockets stayed
  byte-identical. The registry digest covers the other direction — a
  DECLARATION that moved without the geometry moving — which the
  collider list cannot see. Both are in; the claim about which catches
  what is corrected here.
