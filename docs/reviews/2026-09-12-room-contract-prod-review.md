# Prod review — `09_ROOM_CONTRACT.md`

**Reviewed revision:** `cb3bf64`
**Reviewer:** Prod (engine lane)
**Production revision this review is measured against:** `c8ed2e9`
**Status of the document under review:** DRAFT. This review is the engine
lane's response and is not itself canon.

---

## 0. Verdict

**Accept the architecture. Do not start implementing yet.**

The three-layer split — shell capacity, per-instance assignment, persistent
progress — is right, and the §7 ownership table is the correct division.
§1's rule (Layer 2 cannot decide placement) and §2.2's transform/aperture/
envelope/`player_entry` distinction are both load-bearing and both correct;
§2.2 in particular states the thing that produces the worst class of bug in
this area, and `shell_yard_gantry`'s 0.4 m overhanging transform is the
right example to have pinned.

**Six defects block a parallel start.** One (§1 below) is a genuine
interface contradiction: the two lanes reading this document today would
build incompatible things and not discover it until integration. Four are
mechanical. One needs the owner and must not be settled by either lane.

I am not asking for a redesign. Every correction below is a patch to
existing text.

---

## 1. Return edges contradict their own contract — BLOCKING

**§3.2:** *"A `TRAVERSAL_ONLY` edge assigns no socket, meets no collar, and
closes no loop."*
**§3.3 invariant 4:** *"Every `TRAVERSAL_ONLY` edge is named by exactly one
`DoorAssignment` and carries a `destination`."*

These cannot both hold. A `DoorAssignment` **is** a socket assignment: its
first field is `socket_id`, invariant 1 requires that id to exist in the
shell's capacity, and invariant 2 forbids reuse. So invariant 4 consumes a
joining socket for a device that §3.2 says binds no geometry. The schema
compounds it: `usage` is `USED | LOCKED | SEALED`, none of which is a plug,
and `edge_id` is *"required iff usage != SEALED"*, so a plug would have to
be carried by a `USED` or `LOCKED` door — both of which carve an aperture.

A three-door junction with one plug would be assigned **four** sockets by
the bridge and carve **four** apertures in the engine. On a two-door shell
with a plug, the injective assignment in §30.11.2b fails outright and the
shell is never offered — which is the opposite of §2.3's promise that every
existing shell still composes.

### Patch

Give the plug its own record. It is not a door and should not borrow a
door's shape.

```
PlugAssignment:
  edge_id       : EdgeId
  room_id       : RoomId          # the room the device stands in
  source_anchor : AnchorId        # where the device is placed
  destination   : AnchorId        # where the player arrives
  device        : PlugKind        # from the authored plug catalogue
```

- **§3.2**, append: *"A `TRAVERSAL_ONLY` edge is carried by a
  `PlugAssignment`, never a `DoorAssignment`. It consumes no joining
  socket, and a room's joining-socket budget is unaffected by how many
  plugs it holds."*
- **§3.3 invariant 4**, replace with: *"Every `TRAVERSAL_ONLY` edge is
  named by exactly one `PlugAssignment` and by **no** `DoorAssignment`. It
  carries a `source_anchor` in `room_id` and a `destination`."*
- **`DoorAssignment.edge_id`**, replace the condition with: *"required iff
  `usage != SEALED`; the named edge must be `JOINED`."*
- **§3.3**, add invariant 7: *"Every `PlugAssignment`'s `source_anchor` and
  `destination` name anchors the engine can resolve. Neither is a
  coordinate."*

Both anchors are `AnchorId`, so §3.2's *"never a coordinate"* holds for the
source as well as the destination — the composer says *which* anchor, the
engine says *where*.

### Safe arrival must be proved, not assumed

Nothing in the draft requires the destination to be somewhere a body fits.
The engine already owns the measurement: `RoomAudit._arrival_is_safe`
(`room_audit.gd:657`) and `player_stands_here` (`:189`). Add to §3.1's
table as a fourth row, and to §8:

> **Check 11b — the plug lands somewhere a player fits.** The resolved
> `destination` anchor admits the standing capsule and has ground under it,
> measured by the same probe that judges `player_entry`. **A plug whose
> destination is unreachable or buried fails composition**, and the test
> fails if the probe is skipped.

### Inherited checks still quantify over every edge

Two Amalgam checks contradict §3.2 as written, and one of them contradicts
its own document:

- **Check 19b:** *"Every **incident topology edge** of every room carries a
  distinct connector-socket assignment…"* — but §30.11.2b's prose (line
  294) already says *"§30.11.2b's injective assignment ranges over `JOINED`
  edges only."* The prose is fixed and the check text is not.
  **Replace "every incident topology edge" with "every incident `JOINED`
  edge".**
- **Check 19e:** *"every edge joined within `EPSILON_JOIN` … every
  independent cycle closed."* Both clauses must be restricted:
  **"every `JOINED` edge joined within `EPSILON_JOIN` … every independent
  cycle **of the `JOINED` subgraph** closed."** §3.2 says slice 1 *"has a
  graph cycle and nothing for the solver to close"* — 19e as written would
  hand the solver exactly that closure constraint.

**Logical reachability includes return edges; physical joining checks apply
to `JOINED` edges only.** That sentence belongs in §3.2 verbatim.

---

## 2. Socket identities — the premise is false, and no migration is needed

**§2.1** asserts: *"Positional names cannot survive a third door — a shell
gaining a side door would have to renumber, and every stored assignment
referring to `exit` would silently mean something else."*

Measured at `c8ed2e9`, that is not what production does.

**Every positional consumer of a socket name is two functions in one
file:**

| Location | Matches |
|---|---|
| `content_instantiator.gd:676` `_entry_offset` | `name in ["entry", "end_a"]` |
| `content_instantiator.gd:704` `_exit_offset` | `name in ["exit", "end_b"]` |

Each already accepts **two different names for the same role.** That is the
proof: the ids are already opaque labels resolved through an alias set, not
positions. `entry` no more means "the first door" than `end_a` does.

**Adding a side door therefore invalidates nothing.** A third opening gets
a third id. `entry` and `exit` keep pointing at the openings they have
always pointed at, every stored assignment keeps meaning what it meant, and
no shell is renamed, renumbered or rebuilt.

**`LEGACY_ENTRY` is being read backwards.** It is the fallback used when a
shell declares *no* entry socket at all (`_entry_offset`'s final `return`),
and the comment says so: *"A room that declares no entry connector attaches
at `RoomContract.LEGACY_ENTRY`."* It is precedent for **positional
defaults when a name is absent** — the opposite of evidence that named ids
need migrating.

### Patch

- **§2.1**, replace the whole section with:

  > **A `socket_id` identifies one opening for the life of the shell.** It
  > is never reused for a different opening, and changing one is a
  > `catalog_digest` change (§30.11.5 class 6).
  >
  > **Production already satisfies this.** `entry` and `exit` are opaque
  > stable ids that happen to read positionally; `content_instantiator.gd`
  > resolves each through a two-name alias set (`entry`/`end_a`,
  > `exit`/`end_b`), so neither is treated as an ordinal. A shell gaining a
  > third opening gets a third id and the existing two keep their meaning.
  > **No rename, no alias table, no shell rebuild.**

- **§2.3**, "Must add" row: strike *"stable `socket_id`s"*, keep
  *"a `player_entry` volume per joining socket"*. Art's only obligation for
  slice 1 is the arrival volume.

### The real repair, and it is the engine lane's

The defect is not the names; it is that **the joining sockets are chosen by
name instead of by assignment.** With N doors, which opening joins which
edge is the bridge's decision, and `_entry_offset` / `_exit_offset` cannot
express it.

> `_entry_offset` and `_exit_offset` are replaced by one resolver that
> takes a `socket_id` from the `DoorAssignment`. **When no assignment is
> present it falls back to the legacy pair**, which is exactly what keeps
> all twelve two-door shells composing unchanged through the existing path.

That is a contained change in one file and it satisfies *"existing authored
room composition must remain supported"* by construction rather than by
promise.

---

## 3. `LAYOUT_OK` does not commit the layout — BLOCKING

**§6:** `LAYOUT_OK { transforms : map[RoomId, Transform] }`.

Room transforms are not the layout. `zone_builder.gd`'s `_emit_route` also
places **corner pieces and connector segments**, chosen by `_plan_route`'s
search and returned as an ordered list of `{turn, connectors}` steps. A
manifest holding only room transforms cannot rebuild the connecting
geometry without re-running the search — and re-running it is exactly what
§5.2 promises never happens.

This also breaks §5.2's join measurement. **Two rooms linked by a connector
chain do not meet each other's sockets**; each meets the near end of the
chain. A 19e that compares socket to socket will fail every non-adjacent
pair in a Zone that composes correctly.

### Patch

```
LAYOUT_OK {
  rooms : map[RoomId, Transform]
  links : map[EdgeId, list[PlacedPiece]]   # ordered, origin → destination
}

PlacedPiece:
  kind      : CONNECTOR | CORNER
  transform : Transform          # world placement, as built
  bounds    : AABB               # world-space, as measured
```

`links[e]` is empty for a directly-abutting edge and holds the chain in
build order otherwise. That is replay-exact: the engine rebuilds by
replaying pieces, never by re-searching.

**§5.2's join clause**, replace with:

> An edge joins when its two endpoint sockets meet **the two ends of
> `links[edge_id]`** within `EPSILON_JOIN`, and each consecutive pair
> within the chain meets within `EPSILON_JOIN`. For an empty chain the two
> sockets meet each other directly. **Socket-to-socket coincidence is the
> special case, not the rule.**

### Validate before publishing, not after

§5.2 currently says *"writes them into the Zone manifest as part of
`manifest_digest`, **then** runs check 19e."* That publishes an unvalidated
manifest and checks it afterwards. Reverse it:

> The bridge validates the proposed layout, and **only a layout that passes
> 19e becomes the accepted immutable manifest.** A failing proposal is
> `LAYOUT_REFUSED` back to the engine lane and never acquires a digest.

### Which side measures what

The draft does not divide the evidence, and without that division the
obvious reading is that Python re-implements collision. It must not.

| Fact | Produced by | Means |
|---|---|---|
| room transforms, piece transforms, piece `bounds` | **Godot** | measured from the built scene |
| capsule fits at every `player_entry` and plug destination | **Godot** | `player_stands_here` / `_arrival_is_safe`; reported as a boolean per anchor with the anchor id |
| apertures are holes; sealed doors are solid | **Godot** | `_openings_are_holes`, both polarities |
| chain continuity within `EPSILON_JOIN` | **Bridge** | arithmetic on returned transforms |
| no two room envelopes intersect | **Bridge** | AABB arithmetic on returned `bounds` |
| every `JOINED` cycle closed | **Bridge** | arithmetic |
| digest, catalog match, invariant conformance | **Bridge** | schema |

> **The bridge never runs a shape query.** Everything requiring a physics
> world is measured in Godot and returned as evidence; the bridge checks
> arithmetic and identity on that evidence. Measuring is not re-solving,
> and re-deriving a capsule result in Python would be a second derivation
> of a fact the engine owns.

---

## 4. The failure tests do not prove the distinction they exist for

§8 checks 6 and 7 are called *"the pair that matters most"*, and as written
neither is reliable.

**Check 6** — *"a deliberately over-constrained input returns
`LAYOUT_TIMEOUT` with `candidates_remaining > 0`"*. An over-constrained
input is one with **few** candidates. It fails fast, exhausts the space,
and by §6.2 must therefore report `LAYOUT_INFEASIBLE`. The fixture as
described produces the opposite of the result asserted, and on a fast
machine it will do so every time.

> **Replace:** a timeout fixture is a **large** space with a **small**
> budget, never a constrained one. Compose N rooms whose route space is
> measurably larger than one budget can explore, set `budget_ms` below the
> measured cost of a single full candidate, and assert `LAYOUT_TIMEOUT`
> with `candidates_remaining > 0` and `elapsed_ms >= budget_ms`. The
> budget, not the geometry, is what the fixture controls.

**Check 7 / §6.2** — *"an input with no layout"*. No solver here can
establish that. Mine searches a **bounded routing policy**:
`MAX_ROUTE_TURNS = 2`, `EXPLORE_CONNECTORS = 40`,
`MAX_CLEARANCE_CONNECTORS = 96`, and a per-Zone `_clearance_budget` derived
from placed geometry. Exhausting that says *"no layout exists under these
bounds"*. It says nothing about a layout with three turns.

> **§6.2, replace:** `exhausted: true` means **the candidate space defined
> by the declared routing policy is empty** — not that no geometric layout
> exists. `LAYOUT_INFEASIBLE` therefore carries the policy it exhausted:
>
> ```
> LAYOUT_INFEASIBLE {
>   exhausted : true
>   policy    : { max_route_turns, explore_connectors,
>                 max_clearance_connectors, clearance_budget }
>   blocking_rooms, blocking_pairs
> }
> ```
>
> A catalog review reading this result must be able to see that widening
> the policy is an available response. **A bounded search may never report
> that a design is impossible.**

§6.4's escalation still holds; it simply now escalates a fact that is true.

---

## 5. Art and progress boundaries

### 5.1 `SEALED` means two different things and the draft names one

§3.1 defines `SEALED` as *"no aperture; wall"*. That is achievable for a
**procedural** room, where the builder simply does not cut the opening.

**It is not achievable for an authored shell.** The opening is already
modelled in the shell's mesh; there is nothing to decline to cut. Closure
must be a **placed object over an existing aperture**, which is a different
construction with a different failure mode — and it is Art's capacity
question, per the ownership table.

> **§3.1, replace the `SEALED` row's Geometry cell with:**
> *procedural — the aperture is never cut; authored — a closure is placed
> over the existing aperture.* **Both are proved by the same inverted
> probe**, and the authored case additionally asserts the closure is a
> present node, so a missing closure cannot read as a pass.

Add to §8:

> **Check 4b — an authored seal is a thing, not an absence.** A `SEALED`
> socket on an authored shell has a closure node placed over its aperture,
> and the inverted probe passes. Removing the closure fails the check.

### 5.2 `R ⊆ E` does not prove a key is reachable

Invariant 5 and check 10 rest entirely on `R ⊆ E`. That is a **graph**
property over edges the bridge believes exist. It cannot see that the key
stands inside a crate, on a ledge with no ramp, or behind the trim lip that
made every band ramp unwalkable until `c8ed2e9`.

> **Add check 10b — the key is physically reachable.** From the room's
> arrival volume, the key's anchor is reachable **walking only**, with no
> jump, no offer and no Teleport, and without crossing its own lock. The
> engine owns this; the mechanism exists as the escape flood added in
> `c8ed2e9` (`room_contract_driver.gd`, `_walk_reaches`). The same check
> applies to every allocated Check in the Zone.

`R ⊆ E` stays. It is necessary and it is not sufficient, and the draft
currently treats it as both.

### 5.3 The exit relaxation must be coupled to a working return

§4.1 couples the exit unlock to *"`DORMANT` works"*. Check 14 tests that
progress survives a Hub return. Neither tests the thing the coupling is
for: **leaving through a relaxed exit with Checks outstanding, and coming
back to them.**

> **Strengthen check 14:** the Zone is left **through the exit with
> allocated Checks unclaimed**, reaches `DORMANT`, is re-entered, and the
> outstanding Checks are still claimable with keys, opened locks, stations
> and claimed Checks intact. **The presence of the `DORMANT` enum is not
> the property; the round trip is.**

### 5.4 An unapproved prohibition is being frozen — FLAG, do not settle

`06_THE_AMALGAM.md` §30.12.1's lifecycle table gives `COMPLETE` →
Re-enterable: **"no — nothing remains"**.

That is a new rule, it is not an owner ruling in evidence, and it is
reachable from an ordinary action: claim every Check, walk out, and the
Zone is closed forever. "Nothing remains" is a claim about *Checks*, and a
player may want to return for a room, a route, a station, or a plug they
never used.

**This should not be settled by either lane.** It is flagged here, and §6
below lists it as the one decision the owner still owes.

---

## 6. Corrections to the document itself

| Where | Says | Should say |
|---|---|---|
| §5.2 | *"This is how Law 47a's determinism is obtained"* | **47c.** §1.4 defines 47a as *bridge structural determinism* before the model is consulted; **47c** is *"Once a `ZoneManifest` exists, every save, load, replay, and later retrieval of that Zone is byte-identical from the manifest."* Committed replay is 47c |
| header | *"**Reviewed by:** Prod (engine lane)."* | *"**Engine-lane review:** returned `2026-09-12` against `cb3bf64` — changes requested; see `docs/reviews/2026-09-12-room-contract-prod-review.md`."* The line asserted a review that had not happened |
| `06_THE_AMALGAM.md` line 2121 | *"Law 47a requires a Zone to rebuild identically forever"* | **47c**, same error, in the source document |

---

## 7. The agreement, if the patches above are taken

### Data the bridge sends, once per Zone

`EdgeAssignment[]` · `RoomAssignment[]` · `PlugAssignment[]` ·
`catalog_digest` · placement budget (`budget_ms`).

### Data the engine returns, once per Zone

`LayoutResult` — on `LAYOUT_OK`: `rooms`, `links`, and the measured
evidence in §3's table (per-anchor arrival booleans, per-aperture polarity
results). On failure: the typed result with `candidates_remaining` or
`policy` as §4 requires.

### Data the engine sends during play

`key_collected` · `lock_opened` · `station_reached`, idempotent by
identity, exactly as §5.3 has them. No change.

### Files

Unchanged from §7 of the draft, with three additions to the engine column:
`godot/scripts/content/content_instantiator.gd` (socket resolution by id),
and `godot/tests/room_contract_driver.gd` (checks 4b, 10b, 11b). The bridge
column gains `PlugAssignment` and the `policy` field.

**Neither lane may implement the other's column** stands, and I would add:
**neither lane may relax the other's check.** If the engine cannot prove
arrival, the answer is a failing composition, not a softer predicate.

---

## 8. What I need from the owner

**One decision, and only one:**

> **Is a `COMPLETE` Zone re-enterable?** §30.12.1 currently says no. Either
> answer is implementable; the table should not assert one until it is
> ruled.

Everything else above is a correction within the two lanes' authority.

---

## 9. Where implementation should start

**`c8ed2e9`**, on `claude/archipepsi-echoes-continuation-b1adno`.

`origin/main` is still `fb040c2` ("Initial commit"), so that branch is
Production. `c8ed2e9` is the head of the escape-repair pass: 17 Godot
suites green by exit code, Python 1105 passed, packet gate clean. It
changes `chamber_builders.gd` and `room_contract_driver.gd` — both files
the engine slice builds directly on — so starting anywhere earlier means
re-fixing the four band defects it closed.

**Arty's holds are unaffected by everything above.** Slice 1 needs no new
authored doorway, and §2.3's "Need not add" row is correct as written once
`stable socket_id`s comes out of "Must add". The Span stair repair
(`docs/art-requests/2026-09-12-span-basin-stairs.md`) is independent of
this contract.
