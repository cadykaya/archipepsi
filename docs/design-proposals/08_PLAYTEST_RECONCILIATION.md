# 08 — PLAYTEST RECONCILIATION AND FIRST BRANCHING SLICE

**Findings, not a proposal.** Design 6 reconciled against Production `96c450e` and the owner decisions of 11 September 2026, following the first human playthrough of the 3A/3B build.

**Scope.** This document verifies the playtest package's diagnoses against Production source, states which owner decisions Design 6 already carries and which it does not, and proposes a bounded implementation split. **It schedules nothing and implements nothing.** Implementation belongs on a separate branch cut from a pinned Production revision.

| | |
|---|---|
| **Playtest package** | `archipepsi-zone1-playtest-2026-09-11`, Zone `zone_001` id `a9e649315285bdf3`, 23 chambers |
| **Production revision verified against** | `96c450e8ba91ec012fb1e2ce44d269a67a14bf53` |
| **Design revision** | `06_THE_AMALGAM.md` at this branch's head, including §30.11.2d's correction |
| **Owner decisions** | 2026-09-11, seven, reproduced in §3 |

---

## 1. The diagnoses, verified

The owner's brief was explicit: *treat the ZIP as observations plus diagnoses to verify.* Every load-bearing claim was measured against Production source at `96c450e`, not accepted from the report.

### 1.1 Confirmed

| Claim | Measured |
|---|---|
| **`c015` has no walking exit** — `1.46 m` under the deck, `1.34 m` over it, for a `1.8 m` player with no crouch | `band_rect(band, width, depth)` takes **no door position**; for `side: "back"` it returns `span_x = width` centred at `centre_z = depth − span_z/2`, flush to the back wall. `_elevation_band` lays a `0.4 m` slab centred at `rise − 0.2`, so `rise 1.86` occupies `[1.46, 1.86]`. `DOOR_HEIGHT = 3.2`, `DOOR_WIDTH = 2.4`, `_perimeter`'s `exit_gap_y` defaults to `0.0`. The played Zone's `c015` carries `{kind: gallery, rise: 1.86, coverage: 0.3, side: "back"}`. Deck depth `10.1 × 0.3 = 3.03 m` — a tunnel, not a lip |
| **The fixture's second and third entries are unreachable** | `room_contract_driver.gd:743` is `"side": ["left", "right", "back"][i % 3]` inside `if i % 3 == 0:`, verbatim. All sixteen rooms get `"left"` |
| **The pit's ramp is built outside the recess** | `ramp_at` is computed identically for both kinds from `centre ± span/2 ± run/2`; `if kind == "pit": turn += PI` rotates the wedge and moves nothing |
| **Epsilon cannot express position** | `EnemyGroup` is `{archetype, count}`. `ArenaChamber` is `{type, width, depth, wall_height, objective, enemies, elevation}` plus the shared base — no position field anywhere |
| **The Zone has no edges** | `Zone.chambers: tuple[Chamber, ...]` at `schema_version: Literal[7]`. List order is the topology |
| **Every authored shell has exactly two doorways** | All twelve are `['entry', 'exit']`. The large shells are not socket-poor — `shell_yard_gantry` declares `11` sockets, `shell_hall_transit` and `shell_span_basin` `10` each — **but only two of each are joining kinds** |
| **`timed_run` clocks sit at the most forgiving legal value** | Derived as exactly `ActivityPrimitive`'s validator floor, `element_count × SECONDS_PER_ACTIVITY_ELEMENT` = `4.0 s` per element |

### 1.2 Falsified

Two of S-9's findings are wrong at `96c450e`, and wrong about the Zone that was actually played.

> **"No activity timer exists anywhere, and `timed_run` clocks are derived at the most forgiving legal value."**

The second clause is true. The first is false three times over:

1. `activity_runtime.gd` declares `time_limit` (`:92`), reads it from the activity (`:118`), counts `_clock` down in `_process`, renders the remainder live as `"%.1fs"` in `_progress_text()`, and calls `_fail("out of time")` when it reaches zero.
2. `fallback.py:_activity` derives the clock and `zone.py`'s `_a_timed_puzzle_stays_base_kit_solvable` validates a floor against it.
3. **All nine `timed_run` activities in `zone_001` carried clocks** — `8.0`, `12.0`, `12.0`, `16.0`, `16.0`, `16.0`, `16.0`, `20.0`, `12.0` seconds.

> **"No completion feedback: finishing a `switch_sequence` or `target_challenge` produces nothing the player can perceive."**

False. `_succeed()` sets the label to `DONE` and sends a `grant_local_reward` intent with a display name; `_fail()` sets `RESET — <reason>` and holds it for `ACTIVITY_RESULT_SECONDS`; progress reads `"%d / %d"` throughout; `timed_run` tags its `START` and `GOAL` elements. `labels_visible` starts `ON`.

**What is true, and is a different fix.** The signal is a billboard `Label3D` placed at `_label_home() + (0, 3.1, 0)`, and `_label_home()` returns the `START` element's position. **A player standing at the `GOAL` at the moment of completion has the feedback behind them and three metres up.** That is a placement defect, not an absence — and it inverts the remedy: surface the existing signal on the HUD, do not build a feedback system that already exists.

### 1.3 The pattern, from the other side

The playtest names a recurring shape: *a measurement exists, is correct, and is never handed the case that fails it.* Its mirror appeared in the report itself: **a mechanism exists, is correct, and is never seen by the player it was built for.** Both are failures of delivery rather than of construction, and both are invisible to a test that asks whether the thing exists.

---

## 2. §30.11.2d, corrected

**The owner ruled directly: compatible sockets do not prove shell-body clearance or global layout feasibility.** Design 6 claimed the opposite. The claim is withdrawn; §30.11.2d is rewritten and §30.11.2e adopts the placement solve it had deferred. `06_THE_AMALGAM_AUDIT.md` §9c records the pass in full.

The counterexample is Production's own: **`shell_yard_gantry`'s entry connector sits `0.4 m` past its own west wall.** A doorway socket is an *attachment transform*, not a point on the envelope — the engine says so outright, and says no standing floor is required beneath it. `SIDE_CLEARANCE = 0.4` and `HEAD_CLEARANCE = 0.2` bound the **aperture around the player capsule**; Design 6 read them as bounding the shells.

Two further reasons, both available when the claim was made:

- **Cycle closure is not a pairwise property.** §30.2 gives the Zone `1`–`4` independent cycles. Every join around a cycle can be legal while the composed transform is not the identity.
- **Production already contradicts it.** `ZoneBuilder._search` needs a `96`-connector escape hatch to chain large rooms *in a straight line*.

**Consequence for the plan: the placement solver is mandatory in the design, not only in Production.** It is the long pole in §4 and the reason the first slice is scoped the way it is. The composition budget grows from `88.0 s` to `103.0 s` per Zone.

---

## 3. The seven decisions against Design 6

| # | Owner decision | Design 6 | Where |
|---:|---|---|---|
| 1 | Rooms may have multiple used doorways and branching routes | **Already the design.** The Zone is a graph of `8`–`12` rooms and `10`–`20` edges with `1`–`4` independent cycles; `TopologyEdge` is a first-class record; §30.11.2b states outright that *"a room's degree can exceed two"* and that a linear entry/exit assumption cannot express a junction | §4.9a, §30.2, §30.11.2b |
| 2 | Existing two-door shells remain valid | **Already covered, by the rule that looks like a restriction.** §30.11.2b offers a shell only when an injective assignment exists from incident edges to sockets — so a two-door shell is simply never offered to a degree-3 room, and stays legal everywhere else. No variant-per-door-count is needed | §30.11.2b |
| 3 | Dead-end branches must provide a declared return route | **Partially.** The model check's `R ⊆ E` already *rejects* a dead end the player cannot leave — the verifier will not pass a Zone that strands. But Design 6 has **no plug catalogue and no return anchor**, so it can only reject the bad Zone, never compose the good one | §30.6 property 1; mechanism **absent** |
| 4 | Shells declare doorway capacity; composition declares used / sealed / locked | **Half.** Capacity-versus-usage falls out of §30.11.2b's injective assignment for free. **Sealed and locked are absent** — and sealing carries the trap the playtest named: `_openings_are_holes` reports a blocked doorway as a defect, so for a declared-sealed door the same measurement must **invert** and confirm the seal. Skipping the check for walled doors would be a fourth instance of the recurring shape | §30.11.2b; sealing **absent** |
| 5 | Warp stations support useful return and revisit | **Absent, and deliberately so.** §2.2 *Explicitly deferred* records *"In-Zone loadout stations — deferred in all five. Hub-only editing"*, and deferral there means *pinned: identical to Design 1 §2.2*. This is the one decision that reverses a choice all six proposals made, so it is a **modifier to a pin**, not a gap — §0.5's ledger gains a row when it is written | **absent** |
| 6 | Zone-local keys first; cross-game ability gates later | **Already the design, and the sequence matches.** Local keys are in the state vector (`0`–`4`, two states each), pinned from Design 1 §28, and `LOCAL_KEY_LOOP` is one of the `34` authored puzzle families. **A key behind its own lock is caught as unreachability** by the model check's `R ⊆ E`, not by a named key-graph check — Design 6 has no check corresponding to the design packet's *acyclic key graph* rule, and does not need one while the model check subsumes it. Ability gates are §29.5a and check 23, which today reduces to *"no capability gate on any AP-relevant mandatory route"* until the apworld declares prerequisites — exactly "later" | §4.10, §28 pin, §30.6 property 1; §29.5a, check 23 |
| 7 | Leaving with unclaimed Checks must preserve a way to obtain them | **Partially, and not as a player affordance.** §5.6.2 returns a retired Zone's unclaimed Checks to the allocator when a schema migration retires it. That is a data-safety path, not a way for a player to go back | §5.6.2; affordance **absent** |

### 3.1 Where Design 6 constrains the decisions

Three caps the owner should see before the first slice is cut, because they bound what the design will validate:

| Cap | Value | What it means for these decisions |
|---|---|---|
| **Local keys per Zone** | `0`–`4` (§30.2) | Doom-style colour keys fit, but four is the ceiling the state vector was sized for. A fifth key is a `4096` state-bound recomputation, not a constant change |
| **Entry and exit** | **one each, distinct rooms** (§30.2) | A branching Zone still has a single entrance and a single exit. Multiple *doors* per room is decision 1; multiple *Zone* entrances is not, and is not proposed here |
| **Rooms and edges** | `8`–`12` rooms, `10`–`20` edges | With `1`–`4` cycles that is roughly `12`–`15` edges in practice. Average degree ≈ `2.5`, so most rooms stay two-door even after the change |

### 3.2 The one genuinely new authority question

Decision 3 makes **Epsilon choose the plug and the return anchor**. That is a *second selection axis* alongside `shell_id`, and Design 6's §30.1 rebase was written for exactly one.

It fits the existing shape without moving the boundary: a bridge-filtered offer set, one selection per dead end, committed to the manifest, with §30.11.6's offline selector as the terminal. **Both destinations the owner named — Zone start, last large room — are declared anchors rather than coordinates**, so `zone_builder.gd:4`'s *"Epsilon never chooses world coordinates"* still holds verbatim. No special pleading required; it is the `shell_id` pattern applied twice.

---

## 4. The implementation split

### 4.1 What is reused or extended

| Production asset | Disposition |
|---|---|
| `ZoneBuilder.origin_for(join, yaw, entry)` / `exit_cursor(origin, yaw, exit)` | **Reused unchanged.** Already public precisely so a test measures the seam. These are the solver's primitives |
| `SpaceProbe` — `ground_below`, `body_fits`, `stance_fits`, `column_is_clear`, `stand_pose`, `refusal` | **Reused unchanged.** The one canonical real-geometry query; the solver's body and arrival constraints call it rather than sampling |
| `room_audit.gd` — `_openings_are_holes`, `_arrival_is_safe`, `_traversal_is_true` | **Extended from two probes to N**, plus the inverted probe for declared-sealed doors |
| `chamber_builders._perimeter(…, exit_gap_y, left_gap_z, left_gap_width, …)` | **Extended.** It already carves side gaps; N doors is a generalisation of machinery that exists |
| `chamber_builders.band_rect` | **Extended to take the door set** — which is also the B-1 fix. One derivation, per the comment already above it |
| `content.py` shell socket schema, `authored_art.json` | **Extended.** Doorway sockets gain declared usage; `player_entry` gains a per-doorway binding |
| `zone.py` `Zone` / `Chamber` | **Extended.** Edges as data; `schema_version` `7` → `8` with a migration |
| `activity_runtime.gd` | **Reused as is.** Only the label's *surface* moves (§1.2). No new system |
| `campaign.py` `_select_zone_locations`, `handle_leave_zone` / `handle_abandon_zone` | **Reused** as the substrate for decision 7. `handle_leave_zone` is already non-destructive |

### 4.2 What is genuinely new

| New | Why it cannot be an extension |
|---|---|
| **`TopologyEdge` as stored data** | The Zone is a list whose order is the topology. A graph needs edges; there is nothing to extend |
| **The placement solver** | A cursor walk cannot branch, fail, or backtrack. This is the real engineering, and §30.11.2d's correction makes it mandatory rather than optional |
| **Door usage — used / sealed / locked** | No field exists, and sealing needs the *inverted* audit, not a skipped one |
| **Dead-end plug catalogue + Epsilon's plug axis** | New authored content and a second selection axis (§3.2) |
| **Zone-local key geometry** | `zone.py` has no key field. The verifier's side exists (check 16); the world's side does not |
| **Warp stations and the resume anchor** | Godot discards the player's position on Hub return. A station is a persisted set plus a spawn anchor |
| **The unclaimed-Check return path** | §5.6.2 is a migration path, not a player affordance |

### 4.3 The first playable branching slice

**One T-junction. Three doors. One local key. Procedural rooms only.**

| | |
|---|---|
| **Shape** | Eight procedural rooms. Exactly **one** room of degree `3`. Zero cycles, one entry, one exit |
| **The branch** | The short branch dead-ends behind a **local key**. The key sits in the long branch. The dead end carries **one plug** — the simplest in the catalogue, a one-way return door to the Zone start |
| **Shells** | **None authored.** Every room is procedural |
| **Excluded** | Authored multi-door shells, warp stations, ability gates, cycles, multi-room activities |

**Why no authored shells.** All twelve declare exactly two doorways, so a branching room built from one needs an **art change**. Procedural rooms are built by code and gain a third door the moment `_perimeter` can carve it. Cutting art out of slice 1 means the contract can be proven before anyone re-authors a shell — and when the shells do gain doorways, they arrive against a contract that is already tested.

**Why one junction and no cycle.** A single degree-3 node exercises edges-as-data, the N-door builder, the N-probe audit, key lock and unlock, the plug return, and `R ⊆ E` over a real branch. **A cycle additionally requires closure**, which is the solver's hardest constraint (§30.11.2e) and the one with no Production precedent. Proving the graph on an acyclic junction first means the solver's closure constraint is the only thing under test when the first cycle lands.

**What it proves, in order:** edges survive a save round-trip → a room builds with three doors → the audit probes three and passes → the solver places a branch without overlap → a key locks and unlocks real geometry → a plug returns the player → the verifier accepts a Zone it could not previously express.

**What would falsify it:** the solver failing to place eight procedural rooms with one junction inside `3.0 s`. That is the number §30.11.2e commits to, and slice 1 is the first chance to find out whether it is the right one.

### 4.4 Proposed lanes

Proposed, not assumed — the boundary matters more than who holds which side.

| Lane | Owns | Files |
|---|---|---|
| **Design / bridge** | The graph schema and its migration, the placement solve and its determinism, the plug offer-and-selection axis, the validators | `bridge/…/schemas/zone.py`, the solver module, `bridge/…/epsilon/` offer construction, `06_THE_AMALGAM.md` |
| **Production / Godot** | Geometry and the audits that measure it, including the B-1 and B-2 repairs already in flight | `godot/scripts/generation/chamber_builders.gd`, `zone_builder.gd`, `godot/scripts/content/room_audit.gd`, `godot/tests/` |
| **Shared seam — agree before either starts** | **`RoomContract`**: what the bridge sends per room (the doorway list, each door's usage, key state) and what Godot guarantees back (each door is a hole or provably sealed, each `player_entry` admits the capsule) | `godot/scripts/…/room_contract.gd` ⇄ `bridge/…/schemas/zone.py` |

**The seam is the deliverable that unblocks both lanes**, and it is one document, not a system. Neither side can start without it and neither side should write it alone.

### 4.5 Player-facing decisions still open

These change what the slice feels like and none is answerable from the code.

| # | Question | Why it is open |
|---:|---|---|
| 1 | **Does a local key survive death?** | Design 6 classes local keys `ROOM_PERSISTENT`, so the machinery says yes. But a key that survives death and a key that does not are different games, and the classification was made for a different question |
| 2 | **Does a sealed or locked door survive Hub return and re-entry?** | The layout is committed to the manifest and rebuilds deterministically. **Key and lock state are not layout** — they are progress, and nothing currently says which |
| 3 | **What does revisit mean?** Re-enterable Zones, a Hub board that routes back, or unclaimed Checks returning to the pool for reallocation into a later Zone | Decision 7 requires *a* way. Design 6 already implements the third (§5.6.2) as data safety; the first two are campaign structure. **This is the one that decides whether "revisit" is a place or a promise** |
| 4 | **Does the exit still hard-lock on 100%?** | `exit_portal.gd` locks until every assigned Check confirms. Design 6 requires every Check *reachable*, never every Check *claimed*. With B-1 present that lock is what forced a Teleport backtrack through an impassable room — the two defects compounded |
| 5 | **Where does completion feedback live?** | §1.2: it exists and the player cannot see it. Moving it to the HUD is small; deciding whether the world label stays as well is a legibility choice |

Question 3 is the one to answer first: it is the only one that changes what gets built in slice 2.

---

## 5. What this document does not do

- It does not schedule anything. Sequence is the owner's.
- It does not reimplement 3B or touch shared runtime.
- It does not promote Design 6. The first line of `06_THE_AMALGAM.md` still reads *not canon*.
- It does not treat the playtest package as settled: §1.2 records two findings that did not survive verification, and the same standard applies to everything above.
