# Dess — post-playtest execution (Wave 0 → Wave 1 → Wave 2, then D-01)

The governing packet is `post_playtest_v1.0/` (Prod's CP0 copy).
Dess's brief is `post_playtest_v1.0/dispatch/DESS_START.md`. Task IDs
are the packet's.

## Resumption

- **Resumed:** 2026-09-24, at `76b0952` (Prod's CP1 head, fast-forwarded,
  clean tree).
- **Approval:** the owner approved the Dess lane plan — Wave 0 → Wave 1
  → Wave 2, then D-01 as ready work. D-02, D-03 and D-04 stay owner
  decisions: Dess brings concrete options before implementing those
  branches.

## The owner's rulings on the plan's decisions (2026-09-24, verbatim)

**M-1 — legacy step-once plate routes.** "Existing saved Zones
containing the old step-once route retain their saved behavior until
the player leaves or the Zone is regenerated. New composition must not
produce that route. Do not reinterpret an existing Zone as a held plate
and do not auto-open it by inventing state."

**M-2 — legacy encounters.** "If an older save contains no evidence
that an encounter member died, the current encounter is unknown:
reconstruct it and resume the player from its safe arrival point rather
than amid respawned enemies. However, replaying an unknown encounter
must not duplicate any already-authorized one-shot AP Check, unique
reward, key, or other monotone progression state."

**M-3 — map room names.** "Use the authored room name when one exists,
otherwise type + number. This is presentation only; it must not become
persistent room identity."

## W0.1 — the Prod → Dess file handback (REQUESTED; Dess edits no shared file until it is recorded)

Prod's ledger (`PROD_POST_PLAYTEST.md`, "Ownership, recorded before any
shared edit") took a temporary single-writer exception because Dess had
not resumed, with the rule *"if Dess or Arty resumes, the file in
question passes back to them."* **Dess has resumed.**

The owner has made this handback **mandatory before Dess edits any
shared file, with no two-writer interval.** There is no live channel
between the sessions, so the handback is requested here. Until Prod
records it, **Dess edits none of the files below.**

### Files requested back (the 09 §5 split: Dess owns schema, protocol, progression source and generated exports)

- `bridge/archipepsi_bridge/schemas/**`: protocol, transitions, zone,
  signal_graph, physics, constants, graph, minors, gear, export,
  mechanics, echo, content, migration, and `generated/*`.
- Progression and composition in `bridge/archipepsi_bridge/`: topology,
  cross_room, latched_route, transport_route, candidate, minor_hosting,
  theme_packs, content_value, layout, store.
- In `campaign.py` and `server.py`: **only** the progress-intent seams —
  the handlers, the routing and `_about`.
- Generated from those: `godot/scripts/autoload/constants.gd`, the
  apworld constants copy, `docs/design-packet-v0.8/schemas/*`, and the
  Zone fixtures the make targets regenerate.
- Bridge tests follow the file they exercise.

**Prod keeps** everything else under `godot/`, the runtime integration
and the final combined tests.

### What the handback needs from Prod (one ledger entry)

1. Commit, or name, any in-flight edit to the files above.
2. Record *"handback to Dess at `<sha>`"* with the released files, and
   any file he must keep and until which checkpoint.
3. After that, request any shared change through a Dess note or a
   recorded temporary transfer — never by editing directly.

### Sequencing, so CP2 is not held up

After the handback, Dess delivers the bridge halves of H-PRESSURE-C and
H-RELEASE-C first. Those are what H-PRESSURE-R and the three room
repairs consume, so Prod does not need to take the exception for them.

## Working without shared edits until the handback lands

These touch no shared file:

- **H-SEAMS review.** Verdicts are recorded here; any repair waits for
  the handback.
- **Boundary tests of existing behaviour, in new test files.**
- **The H-KEYS audit.** A new read-only tool.
- **Contract texts** for H-PRESSURE-C and H-RELEASE-C.

Anything that needs a shared edit is queued below with its file named.

---

## W0.2 — H-SEAMS: the review, once (at `76b0952`)

**Baseline in this container, before any Dess edit:**
- `make test`: **2 failed, 2073 passed, 6 skipped**. Both failures are
  DESS-19 and DESS-20 below.
- `check_packet`: green.

### Findings (lane-prefixed; they continue from DESS-18)

- **DESS-19 — defect.** Post-playtest exception edit, H-RESUME-R.
  `transitions.record_defeat` is not listed in `TRANSITIONS`, so
  `test_every_transition_returns_a_validated_campaign` fails at the head.
  **Fix:** add it to the tuple. `transitions.py`, after the handback.
- **DESS-20 — defect.** Same edit. `generated/protocol.schema.json` was
  never regenerated after `EnemyDefeated` and `defeated` were added
  (checked by exporting to a temporary directory and diffing), so
  `test_generated_artifacts_are_not_stale` fails. **Fix:** `make export`.
  A generated artifact, so after the handback.
- **DESS-21 — latent.** OV05 rail/minor latch paths.
  - `RailNetwork.network_id` is not refused the reserved
    `graph_`/`minor_` prefixes.
  - `record_latch` checks `graph_` first and never asks about rails, so
    a network named `graph_<room>` would have its span latches routed
    down the room-graph path. If that room's graph declared a LATCH of
    the same id, the rail latch would be recorded as a graph latch.
  - The `minor_` branch already refuses a rail name; the `graph_` branch
    does not.
  - **Fix:**
    - refuse the reserved prefixes on `network_id` (`zone.py`);
    - make the graph branch refuse a rail name, as the minor branch does
      (`transitions.py`).
  - After the handback.

### Adopted, with how each was checked

| Area | Verdict | Checked by |
|---|---|---|
| `ZoneProgress.defeated`, `record_defeat`, `EnemyDefeated` | **adopted.** It matches D-06 (next section) | Read against the ruling. M-2 is pinned by new tests (next section) |
| New save fields: `object_poses`, `consumed_objects`, `carrier_states`, `defeated` | **adopted** | Every `ZoneProgress` field has a `SAVE_FIELD_CATEGORY`. Bounds match what a Zone can declare: object fields 4 = `transported_objects` 4; carriers 8 ≥ 2 (Passing is the only contract with carriers); `defeated` 512 ≥ 480 (= 40 chambers × 12 per-chamber cap, enforced) |
| New intents: object settled/consumed/recovered, `CarrierRested`, `EnemyDefeated` | **adopted** | All 32 `ClientMessage` intent types are named in `server.py` routing |
| `record_latch`'s four evidence paths (physics / `graph_` / rail / `minor_`) | **adopted, except DESS-21** | `graph_` and `minor_` are reserved on `PhysicsPackage`, `ReplayEvidence` and `PlacedPackage`. The minor branch refuses a rail name; the rail branch refuses a physics name |
| Consumable staging (`CANDIDATE_ACTION_SLOTS`, the request option) | **adopted** | `IMPLEMENTED_ACTION_SLOTS` still withholds `consumable`; only the candidate profile advertises it (D-05 stays open) |
| `rooted`/`anchored` on an enemy | **adopted** | Exported as `ECHO_STATUS_SUPPORTED_TARGETS`, with enemy as the only target for both |
| `DIVER_TRIGGER_HEIGHT` 1.6 → 0.8 m | **adopted** | Prod's own provisional tuning, derived from `JUMP_APEX_HEIGHT`; not a Dess contract |
| Packet mirror | **adopted** | `check_packet` green |

### Superseded by the owner's rulings — changed in W1.2, not reverted as authorship

- **The route rules.** At the head: `ROUTE_SENSOR_KINDS = (PRESSURE_PLATE,)`,
  `ROUTE_NODE_KINDS = (NOT, LATCH)`. Together they admit plate → LATCH.
  D-07 and M-1 retire that for new composition.
- **`candidate.STEPS` includes `latched_route`.** W1.2 changes what it
  emits. The step itself stays.

### Deferred to the contract that touches them (reviewed then, not twice)

- **OR / TIMER / PULSE_BUTTON / SHOOTABLE_TARGET, and the port forms** →
  W1.2.
- **`minors.py` and the hosting modules:**
  - `MinorContract`, including its `graph`, `carriers` and `enemies`;
  - `minor_hosting`, `offer_order`, `shells.is_offerable`;
  - the `minor_rooms.json` registry;
  - candidate re-certification and budget.

  All → W1.3.

### Outside Dess's review scope, named rather than skipped

- **Godot runtime rows**, which are Prod's:
  - the verbs;
  - constraints, `SignalGraph`, `HostedMinor`, `MinorRooms`;
  - the arcade and switch rooms, `ServiceShutter`;
  - enemy behaviour, `RoomAudit`.
- **Epsilon interpretation content**: the fallback readings, the mock
  reading, the model prompt paragraph.

---

## W1.1 — H-RESUME-C: Prod's bridge half reviewed against D-06 and M-2

**The representation is adopted.** Each part checked against the
ruling:

- **Identity** is `room/archetype#n`, derived from the declaration. It
  is stable because an accepted Zone is immutable in its save. No node
  paths are stored, and nothing about a live enemy.
- **`None` means unknown**, and a tuple means known.
- **The first defeat recorded after an unknown resume starts the
  record.** That is correct for the whole Zone: a room entered after
  that resume builds its members fresh, so what falls from then on is
  exactly what is known.
- **Monotone and idempotent**, and checked against the declaration.
  The category is `ROOM_PERSISTENT`.
- **Reload is never a reset.** No other reset event exists in this
  slice.

**M-2 holds, and is now pinned** (`bridge/tests/test_resume_replay_boundaries.py`,
new, 4 tests). A replayed unknown encounter cannot duplicate:

- **an AP Check.** `transactions.claim_check` finalizes an
  already-confirmed location and sends nothing: no new pending record,
  no second delivery.
  - Sabotage-checked: remove that guard, and the test fails with "an
    already-confirmed Check was sent again".
  - The mock ignores a repeat too.
- **a key.** `collected_keys` is a one-way set.
- **a unique reward.** `grant_local_reward` is idempotent by
  `reward_id`.

The defeat record's bound holds the largest legal roster.

**Still Prod's (runtime):**
- the reconstructed room must not show an already-claimed reward
  pickup again;
- it must not re-grant a local reward;
- the evidence for both is `checked_location_ids` and `local_rewards`
  in the snapshot.

The bridge refusals above are the authority backstop, not that
behaviour.

**Open in H-RESUME-C:** DESS-19 and DESS-20, the two mechanical repairs
to Prod's edit. They wait for the handback.

---

## W1.4 — H-KEYS: what each local key opens, and whether it reads as locked (V-14)

`bridge/tools/audit_local_keys.py` (new, read-only) reads each Zone
through the real schema and classifies every declared key:

| Class | Meaning |
|---|---|
| **NO_LOCK** | opens nothing |
| **NOTHING** | its lock guards no Check, exit or key |
| **KEY_FIRST** | every way to the lock passes the key's own room |
| **GATES_CHECK / EXIT / KEY** | what its lock guards |

It reads the declaration only. Whether the engine realized each lock is
Prod's runtime evidence.

`bridge/tests/test_audit_local_keys.py` produces every class it claims
from a schema-valid mutation of a real sample Zone, so a uniform result
is not a silent classifier.

**Result on the committed 20-Zone sample** (`godot/tests/fixtures/sample`,
80 keys):
- **0 NO_LOCK, 0 NOTHING.** Every key opens a lock that guards a Check,
  so the payoff is real.
- **80 of 80 KEY_FIRST.** Keys sit in early route rooms (c002–c005) and
  their locks later. The player passes each key before they can ever
  stand at its lock, so every locked door is reached with its key
  already in hand.

- **DESS-22 — finding (presentation and order, not a missing lock).**
  This is the most likely mechanism behind PT-15, "keys without noticed
  matching doors". The locks exist and pay off; they are simply never
  met locked. **No generator change now** (V-14: "no unjustified global
  rescope").
  - **Near-term (Prod/Arty, CP2 readability):** a locked door
    approached with its key should visibly *unlock* — a colour-matched
    key-to-door beat — rather than behave like an ordinary opening.
  - **Input to H-05-COMPOSE (0.5):** place some keys beyond a point
    where their locked door has already been seen.
- **DESS-23 — latent.** The Zone schema accepts a key that no door
  locks, and the audit's NO_LOCK case is built exactly that way. The
  composer never produces one (0 of 80). A validator guard belongs in
  `zone.py` — after the handback, low priority.

---

## W1.3 — H-RELEASE-C: the room cards (`docs/D12_MINOR_ROOM_CARDS_PROD.md`)

- **Contract delivered.** It covers the ten 03 §4 fields for each of
  Unweighted, Counterfire and Passing, built from the original EX50
  specs and PT-04 to PT-07.
- **The load-bearing rule comes from the specs.** All three accept
  access the recorded latch never sees, and the owner ruled out
  input-order locks. So **the bridge does not gate a minor's Check on
  its latch** — bolt, release and stair are the return and the
  permanence.
- **World and authority agree through the world.** The goal is
  reachable only on its gallery, which is Prod's to build and test.
- **The return latch is operated from the goal side, or fires there.**
  An alternate arrival therefore still makes the way back; the physical
  proof after every arrival is Prod's (PT-07).
- **Pinned** in `bridge/tests/test_minor_release_boundaries.py`, new,
  on the committed candidate Zone:
  - a minor's Check is claimable with its latch unrecorded;
  - a dead gunner strands nothing.
- **No new claim gate and no inert field.** Contract text and `latches`
  move only if Prod's rebuild changes which control releases the return.

## W1.2 — H-PRESSURE-C: the contract (`docs/D13_PRESSURE_CONTRACT_PROD.md`); the code waits for the handback

**Facts checked:**
- **`validate_zone()` is accept-time only**, so D-07's refusal can apply
  to new composition while every legacy Zone loads and behaves as saved
  (M-1).
- **The composer change must land in the same commit as the refusal.**
  The candidate re-certification discards a whole Zone that introduces
  a `validate_zone` error.
- **`plate → TIMER` is already refused** by the port forms.
- **`RoomGraphs` does not read the bridge's placeable-sensor list.** So
  lever routes land together with Prod's lever placement, as one
  integration.

**Queued for the handback, in order:**
1. `validate_zone` refuses plate → LATCH, and `compose_latched_route`
   declines instead of emitting it. One commit; fixtures regenerated.
2. `SensorNode.held_by`, with its validator and the route-search
   modelling, and a composed held-weight fixture.
3. Lever routes (`PULSE_BUTTON` → LATCH), with Prod's lever placement.
