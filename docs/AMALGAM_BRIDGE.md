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
| `layout.py` | 22 | 8 — including the chain walk's inductive step, which the single-piece fixture could never reach | 0 |
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
make physics-vectors        # cd bridge && python3 -m archipepsi_bridge.schemas.physics_vectors
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

## 6. What remains in this lane

- Consume a real `layout_result` (§4.1) and commit a real manifest.
- ~~Re-entry that rebuilds from the committed manifest rather than
  regenerating.~~ **Done on this side, and now actually measured.**
  `handle_enter_zone` sends the committed manifest back down, and
  `test_the_whole_path` asserts the *emitted* `zone_ready` carries it
  with the same digest — against a first generation, which carries
  none. Deleting the replay outright used to pass all 1091 tests: the
  save file looks identical whether or not the manifest is ever sent,
  so every assertion in the suite was reading storage rather than the
  seam. What remains is the engine **consuming** it (§5.3).
- The `manipulate` capability contract, `vector_latches`, and the model
  check's physics properties: the next Amalgam dependencies after this
  slice, none of them started.
