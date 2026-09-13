# Combined handoff — truthful connection capacity, and the acceptance/recovery proof

**Dess, bridge lane — 2026-09-13.** At the exact merged commit
**`4da931c`**, which is the engine lane's `74f6878` merged into the
bridge lane's `2330017` (merge `3d516bc`) plus this batch's repair.
Art's `1a9f1c9` is not in this branch and nothing here depends on it.

Full suite **1466 passed, 6 skipped**; `check_packet.py` green. The six
skips are environment-only: no `anthropic` module, no Archipelago
checkout.

---

## 1. Candidate layout — what the composer now proposes

**One declaration, three paths.** `schemas/zone.procedural_sockets_for`
is the single statement of what a procedural room of a given type can
hold. `topology._sockets_for` offers from it; `validate_zone` refuses a
proposal that went around it; the engine's `_perimeter` cuts a side hole
only when the door plan names one (`chamber_builders.gd:797`), so a
socket the bridge stops offering is a hole the engine stops cutting.
Nothing else declares a door count.

A procedural `platform_path` offers `entry` and `exit`. An **authored**
shell is never asked — it declares its own openings in the catalog, and
sharing a chamber type with a procedural room says nothing about what an
artist cut. This is a statement about the present procedural producer,
not a rule against branching platform rooms; a supported side-landing
variant remains possible later and is not required by this repair.

**The measurement, before and after.** Scanned across every committed
fixture:

| | platform courses with a USED side door |
|---|---|
| before | **28**, across 22 fixtures — including `c008` of the played Zone, the room `zone_01` refuses its layout for |
| after | **0**, across 37 fixtures |

**Branching preserved by moving junctions, not by dropping them.** The
junction search already walked back through candidates; the
*destination* did not, so a destination whose predecessors were all full
simply fell back onto the spine. `_branch_routes` now keeps a reserve
and replaces a failed destination rather than spending a branch on
nothing. Regenerating the played Zone from the same source inputs:

```
same 23 rooms, same types, same 30 edges, same 8 plugs
edges removed: e:c008:c014, e:c008:c018     (off the platform course)
edges added:   e:c002:c018, e:c005:c014     (onto rooms that can hold a door)
```

`SPINE_SHARE` and `MAX_SIDE_DEPTH` are untouched.

**What got harder, reported rather than hidden.** With honest capacity,
re-selection after an unhostable host is rarer: of the played Zone's
eight plug rooms, **one** can move its branch while preserving the
arrangement; the other seven stand down to the ordinary bounded layout
refusal. That is the approved outcome — handing back a Zone with fewer
branches to make a device requirement go away is not — but the regraph
recovery now fires far less often than it appeared to against the old
advertisement. It has its own control
(`test_a_branch_that_cannot_move_is_a_refusal_not_a_smaller_zone`).

---

## 2. Bridge acceptance

**Where the refusal sits, and why not on load.** Every Zone composed
before this carries the unholdable doors. Refusing them in the Zone's
own Invariant 8 — which runs on load — would make a save holding one
unreadable rather than repairable. So Invariant 8 audits what the type
*can* hold and tolerates a mention of what it cannot, and the refusal
lives in `validate_zone`, whose entire job is concise errors for a
repair request. Verified: the pre-repair `played_zone.json` still loads;
a proposal that assigns `side_left` on a platform course is refused with
`"…uses joining socket(s) ['side_left'] its build cannot hold"`.

**Committed manifests are untouched.** No regraph, no reposition. The
re-selection path already refuses a Zone holding a manifest, and this
batch did not change that.

**The engine-capture payloads pass against the merged validator** — 23
tests in `test_placement_contract.py` and `test_proposal_carrier.py`,
with no key or outcome rewritten on the way in. Their scope is now
stated in the file: they are **interface evidence**. They prove the
report crosses the wire in a shape the validator reads and that each
outcome reaches the recovery it belongs to. They are **not**
physical-layout acceptance, and a green run there says nothing about
whether a Zone can be crossed.

**Identical-content retry, closed at the lifecycle boundary.**
`proposal_digest` stays content identity and identical content still
hashes identically — which is exactly why it cannot tell two attempts
apart. Measured before repair: one real refusal became **two**, and
three duplicate deliveries would exhaust a Zone that never failed three
times. `ZoneReady.attempt` / `LayoutResult.attempt` carry the ordinal,
read from `layout_refusals` at offer time, so there is no second counter
to keep in step and nothing is folded into the digest.

Stated rather than implied — **the permitted reuse**: a result for the
*current* attempt at the *current* content is valid however late it
arrives. Lateness alone is not staleness; the bridge has no clock on a
build. What is refused is a result for a different attempt or a
different proposal. Absent means "cannot be checked", never "stale".
Both directions are tested: a duplicate costs nothing, and a real second
failure is still charged.

---

## 3. Player traversal and deliberate return — NOT PROVEN HERE

**No Godot binary exists in this container** (`godot-bin/` is absent), so
`godot-return-journey`, `godot-zone-audit`, `godot-graphs` and the
integration driver did not run. The four crossings the brief asks for —
the course as a through-room, a supported platform destination carrying
a return, an invalid side departure, and a multi-door room carrying the
branch — have **bridge-side** controls here
(`test_topology.py`, five of them, each sabotage-proven) and their
**engine-side** halves are unrun. An assigned opening is not a door
until something with floor and an accessible route is measured in a
physics space, and nothing in this batch measures that.

I am not claiming these legs pass.

---

## 4. Cold reconstruction

Proven for the bridge half at DEFAULT_CONFIG, in one run rather than leg
by leg (`test_the_default_scale_journey_survives_a_cold_restart`):
acceptance with both identities on the offer → placement → commitment →
every branch destination still carrying its return anchor → the record
read back off disk with the same manifest digest, the same plug count
and the same proposal identity → a fresh layout offered to a committed
Zone replaying rather than replacing it.

The legs existed one at a time and had never been walked as a chain,
which is how a chain passes everywhere and fails as a whole.

---

## 5. Unresolved blockers, and what this batch does not close

**Blockers**

- The engine legs above. They need a Godot binary in the runner.
- The wider twenty-Zone sample was regenerated through its Python half
  only (`dump_zones.py`); the `zone-sample` target's Godot verification
  pass did not run, so those files are composed-and-bridge-validated but
  not engine-walked.

**Explicitly still on the backlog, untouched by this batch**

- The existing **overlap**, **ordinary-journey** and **pending-room**
  findings. None of them is addressed here and none should be read as
  closed.
- Whether a supported side-landing variant of the platform course should
  exist. Not required by this repair, and not proposed.

**Not claimed.** This batch does not complete Playable 0.3. It closes
one untrue capacity declaration, the branch loss that correcting it
exposed, and the identical-content retry. The fun reports,
capability-progression options, new rewards, enemy redesigns and 0.4
setpieces were not implementation assignments in this batch and none was
started.

---

## 6. Evidence index

| Claim | Where |
|---|---|
| One shared declaration | `schemas/zone.py::procedural_sockets_for` |
| Composer reads it | `topology.py::_sockets_for` |
| Acceptance refuses what went around it | `schemas/zone.py::validate_zone` |
| Engine cuts only what is assigned | `chamber_builders.gd:797` |
| Four connection controls + authored-shell rule | `tests/test_topology.py` (5 tests) |
| Stand-down is a refusal, not a smaller Zone | `tests/test_amalgam_end_to_end.py` |
| Retry: duplicate costs nothing, real failure charged | `tests/test_amalgam_end_to_end.py` (4 tests) |
| Journey end to end | `tests/test_amalgam_end_to_end.py` |
| Capture payloads, scope labelled | `tests/test_placement_contract.py` |
