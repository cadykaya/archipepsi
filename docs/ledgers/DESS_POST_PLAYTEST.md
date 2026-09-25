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
- `bridge/archipepsi_bridge/epsilon/requests.py`, the Echo request
  schema. Added 2026-09-24: your OV05 seam table edited it, and the
  first list missed it. The provider, fallback, mock and prompt are not
  requested.
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

**DESS-24 — defect in advice, found in W2.2.** The Zone model's refusal
of a held requirement (`zone.py`, the route validator) still ends "put a
LATCH between the plate and the machine". That is the step-once route
D-07 retires. The refusal itself stays, since nothing else can hold the
plate yet. **Fix, in step 1's commit:** the message names the two legal
forms instead: a lever for a permanent opening (1c), and a declared
weight, `held_by`, for a held one (1d). Its neighbour, "declare a plate
that counts the player at a class they reach", is reworded in step 2,
because under 1d the player's body never solves a held route. The text
changes; what is accepted does not, so every saved Zone still loads
(M-1).

## W2.1 — H-UI-DATA: the inventory view (`inventory_view.py`, `fbe5aa3`)

**A projection over the fold, adding no state.** Each item carries:
- `activation`: slotted for an Action, always-on otherwise (not a
  toggle);
- the slots the authority accepts it in, read off the component, since
  only an Action occupies its one declared slot;
- where it is equipped;
- a consumable's charges, where zero while equipped is legal;
- its history, with upgrades kept as history rather than extra items;
- its siblings from the same Echo.

Pending and refused uses are not mirrored (D-9 §3).

**Evidence:** 6 tests. The central one tries every item in every slot
through `slot_action` and requires the view's answer to match the
authority's.

**Queued for the handback:** `CampaignSnapshot.inventory` (`protocol.py`),
then `make export`.

## W2.2 — H-MAP-DATA: the map view (`map_view.py`)

**One projection for the minimap, the 3D map and the journal.**
- **States:** `unknown`, `blocked` (always with a reason) and `open`.
  `transitioning` is the engine's overlay on a live gate. The bridge
  knows settled state only, and does not fake a fifth one.
- **A gate reads recorded consequences, never possession:**
  - a key door opens by `opened_locks`. Holding the key only adds "you
    hold it" to the reason.
  - a state door opens by `macro_state` against the variable's
    `initial`. A carried cell changes nothing; installing it sets the
    variable.
  - a machine door is the graph settled with nothing pressed and this
    save's recorded latches. That is the runtime's restore order, and
    legacy step-once Zones read as saved (M-1).
  - a capability door opens by what is **equipped**. Owned but
    unslotted is NOT YET: "you own it; equip it".
- **Circuits by declaration id:**
  - `key:<key>`;
  - `state:<variable>`: the setter, the receiver, the object it accepts
    and the doors it opens, so supply, receiver and door share one id;
  - `machine:<room>:<actuator>`.
- **Nothing undiscovered is revealed:**
  - no connector touching only undiscovered rooms;
  - no name for an undiscovered room;
  - a gate whose control is in an undiscovered room says "somewhere
    else";
  - a circuit lists only discovered rooms, and an object only once its
    home or its receiver is found;
  - a circuit with no discovered member is omitted.
- **Discovery is an input.** Until the save records it, it is derived
  from recorded facts only: the entrance, key rooms, opened locks,
  latches, defeats, object rooms and set variables. It can undercount;
  it never guesses.
- **Names (M-3):** a hosted minor's contract name ("Unweighted Switch"),
  otherwise type and number ("Arena 3"). Generic shell labels such as
  "corner left" describe geometry and would repeat. Names are computed
  per call and never stored; ids stay the save's.

**Evidence:**
- 9 tests on the committed candidate Zone, plus one schema-valid
  mutation that adds a grapple gate. The capability case uses a real
  Hookshot Echo.
- 13 sabotages, each failing its targeted assertion:
  - a held key opens its door;
  - a carried object opens a state door;
  - "settable" is read as "open";
  - recorded latches are ignored;
  - an undiscovered room is named;
  - a control room is named;
  - a setter room is named;
  - circuit rooms are not filtered by discovery;
  - circuit objects are not filtered by discovery;
  - connectors are not filtered by discovery;
  - discovery guesses neighbours;
  - "owned" is treated as "equipped";
  - the NOT YET reason is dropped.

**Not drawn yet: rail networks.** They are not part of the progression
graph (`topology.py` never reads them), so no connector's state depends
on them. A carrier connector type is 0.5 work, not a gap in these states.

**Not reachable yet:** a live control's `unknown`. The Zone model
refuses a plate → shutter with no latch, so no accepted Zone has one. It
becomes reachable with D-13 1d (`held_by`), and its test lands in that
commit.

**Queued for the handback:**
- `ZoneProgress.visited_rooms: tuple[str, ...] | None`. `None` means
  unknown, for legacy saves, as `defeated` does; it is monotone.
- A `RoomEntered` intent and `record_room_entered`: idempotent, and
  refuses an undeclared room. On a legacy Zone, the first entry records
  the derived rooms plus this one. Those rooms are proven by facts, so
  nothing is invented.
- `CampaignSnapshot.map` for the current Zone, then `make export`.
- **Prod's half:** send `RoomEntered` wherever the minimap marks a room
  seen, and draw from this view.

## CI does not run, and what that hides (2026-09-24)

**Every PR-gate and Integration run on this branch fails within about
four seconds, with no log**, from at least `6ebbc90` (19:26 UTC) to
`fbe5aa3`. That covers both lanes' pushes. The job is created and never
starts, so nothing in any diff can cause or fix it. This is an Actions
account or runner matter for the owner. A re-run would fail the same way.

**Until it runs, the local suite is the only evidence**, run as the gate
runs it: `cd bridge && ARCHIPELAGO_ROOT=/nonexistent python -m pytest -q`.

- **DESS-25 — defect, hidden by the outage.** Two tests in
  `bridge/tests/test_status_guarantee.py` read
  `Path("godot/scripts/autoload/constants.gd")`, relative to the working
  directory:
  - `test_the_engine_is_told_both_lists`;
  - `test_the_engine_is_told_which_targets_each_kind_supports`.

  They pass under `make` from the repo root. They fail with
  `FileNotFoundError` from `bridge/`, which is exactly how the PR gate
  runs, so they turn the gate red the moment Actions runs again.
  **Fix:** anchor the path at the repository root through `__file__`.
  They exercise a generated export, so after the handback.

## D-01 — H-SELF-ECHO: the contract (`docs/D14_SELF_ADDRESSED_ECHO_PROD.md`)

**The rule.** A confirmed Check releases its original through AP once.
Under the policy, Epsilon also makes a local Echo from it, keyed
`echo_<location_id>`, whoever the recipient is. The original and the
Echo are two records: AP counts the first, the fold the second. The Echo
is never sent, received, counted as a key or coin, or stocked.

**Applying the standing rule** (no silent compatibility change):
`CampaignSave.self_addressed_echoes`, default `False`, and set `True` at
campaign creation. A legacy campaign never grows an Echo for its own
items. The backlog sweep would otherwise mint them retroactively on the
first load after the update. If the owner wants legacy campaigns
included, it has to be a visible opt-in.

**Evidence** (`bridge/tests/test_self_echo_boundaries.py`, 3 tests,
each failing under a sabotage):
- **No clone:** a sweep grant sends nothing and moves no AP state. Two
  sabotages: a send after the grant, and a cloned key.
- **One per Check:** without `append_interpretation`'s guard, the save
  model still refuses the duplicate.
- **Legacy stays:** with the self filter lifted, `echo_89100006` is
  minted. That also shows the existing pipeline interprets a
  self-addressed original unchanged.

**Split:**
- **Dess, after W0.1:** the protocol field and export, landed first as a
  no-op.
- **Prod:** creation, the filter, text, reveal, and the combined tests,
  including the deliberate `test_full_loop.py` change D14 §6 names.
- **Epsilon lane:** prompt wording.

**Not settled here:** B-2/D-02 and B-3/D-03.

**Handback addendum.** Prod's OV05 seam table also edited
`epsilon/requests.py`, `epsilon/fallback.py`, `epsilon/mock.py` and
`epsilon/claude.py`'s prompt. Schema files return with the rest under
§5: `epsilon/requests.py` joins the W0.1 list. The provider, fallback
and prompt stay where the Epsilon lane's content ownership puts them.
D-01 itself needs none of the four.

## D-02 / D-03 / D-04 — options for the owner (`docs/D15_OWNER_OPTIONS_D02_D04.md`)

**Brought before any branch is built, as the owner asked.** Research
was three read-only passes over the code and design; every claim in D15
cites its file.

**Recommendations:**
- **D-02:** A. Python fixes the function and Epsilon flavours it, with
  a qualifying fallback.
- **D-03:** C now, E later. E is AP capability events, which meets the
  2026-09-05 ruling's letter; B would need that ruling changed.
- **D-04:** H now, G when a consumer is named.

**DESS-26 — latent, found in the D-02 research.** `grapple_pull_target`
counts as the `grapple` capability (`mechanics.py:296-297`), but at
runtime it moves the enemy, not the player. It is latent: the only edge
composer takes its capability from `featured_acquisition`, which nothing
emits. Every D-02 option excludes it from traversal. The fix lands with
whichever D-02 option is chosen.

## W0.1 — the handback, taken (Prod's entry: `PROD_POST_PLAYTEST.md` W0.1, at `f332fff`)

**Dess is the single writer of the released files from `5f348ab`
onward.** They are:
- `schemas/**` and `generated/*`;
- the progression and composition modules;
- the campaign/server progress seams;
- their generated copies and fixtures;
- their bridge tests.

`epsilon/requests.py`, which I added to the request later, was not
released. Nothing I am doing needs it, so it stays unedited.

**Confirmed:**
- DESS-19 and DESS-20 are fixed by `f332fff`. Both tests pass.
- The suite, run as the gate runs it (`cd bridge`), at the handback head:
  2 failed, 2104 passed, 4 skipped. The 2 failures are DESS-25, fixed
  first.

**Answers to Prod's notes:**
- **N-1 (the Unweighted goal moves within G): agreed.** D12's contract
  text and its `latches` entry are unchanged. Where the objective volume
  sits is registry geometry, and that is yours.
- **N-2 (the transit ride): D12 does not mean it as an alternate.**
  - EX50-033 §6's valid shortcut is "a sufficiently strong jump or
    mobility tool", meaning something beyond the base kit.
  - A base-kit jump from the moving carriage that never applies
    `lightened` bypasses the room's one interaction.
  - **So go ahead with the weighbridge.** It is geometry only, and the
    HEAVY plate stays a held sensor reading the carriage's weight, which
    fits D-07.
  - This is my reading of the owner's spec, so it is flagged to her.
- **N-3 (CI):** noted as yours.

**D13's order, agreed:**
1. 1a + 1b now: the refusal, with the composer declining.
2. Your lever placement in `RoomGraphs`.
3. 1c, adopting your offered patch (the composer's lever form, and
   `PULSE_BUTTON` admitted).
4. 1d, the held weight.

**Note D-1 (Dess → Prod), for step 1:**
- The candidate stops composing a latch route until 1c, so the candidate
  fixture regenerates without its c009 plate route.
- `godot/tests/candidate_live_driver.gd` (~335-345, ~439-447) expects
  `shutters.size() == 1` ("P14's shutter"). It reads 0 until 1c, then 1
  again, as the lever's.
- **The legacy suite is not affected** (`godot-latched-route`, `-live`
  and `latched-route-play`). The step-once composer is kept under a
  legacy name for exactly that fixture and tool: it is M-1's input,
  never a production path.

## W1.2 — H-PRESSURE-C step 1 landed: 1a + 1b (D13), with the legacy kept

**1a — `validate_zone` refuses a plate that sets a LATCH**, directly or
through NOT/OR (`schemas/zone.py`, `_plates_that_latch`).
- Accept-time only. The Zone model validators are unchanged, so every
  saved Zone still loads and plays as saved (M-1).
- DESS-24's message is reworded as part of this. The held-requirement
  refusal no longer advises a latched plate: it names the lever (1c) and
  the declared weight (1d). Only the text changed; nothing that was
  accepted is now refused.

**1b — the production composer declines** with `DECLINED_UNTIL_LEVERS`
(`latched_route.py`). One search now serves two entry points:
- `compose_latched_route` is production. It declines until 1c, then
  emits the lever form, which is Prod's offered patch adopted.
- `compose_legacy_step_once_route` is M-1's input only: the legacy
  fixture and `tools/compose_latched_route.py`. Prod's
  `godot-latched-route*` replay suite therefore stays valid unchanged.

**Fixtures, regenerated from source:**
- `candidate_zone.json` loses exactly its c009 plate route. Nothing
  else changes, including the minors.
- `latched_route_zone.json` is byte-identical.
- The packet's `zone.py` mirror is copied, and `check_packet` passes.

**DESS-27 — defect, found here.** `make candidate-fixture` has refused
every run ("a step declined; nothing written") since the `consumables`
option joined `all`. The dump compared the emitted steps against steps
plus options. Verified at the untouched head. It now compares steps only
(`playtest._must_emit`). A decline by D-07 policy passes visibly; any
other decline still refuses a partial fixture.

**`playtest.py`.** It carries the fixtures' generators, which Prod's
OV05 seam row added (`PROD_OV05.md:76`). The exception has ended and
the fixtures were released, so their generators came with them. Say so
if you read it otherwise.

**Tests changed on purpose, each to assert the new rule:**
- `test_candidate_profile.py`: the profile now expects the latch step
  declined by D-07's reason and no room graph. Its two placement tests
  hold the shared search through the legacy entry.
- `test_p14_latched_route.py`: the three search tests use the legacy
  entry, with assertions unchanged.
- `test_map_view.py`: the machine-gate cases read M-1's legacy fixture.
- `test_signal_graph.py`: the held-requirement message test pinned the
  retired advice ("LATCH"). It now asserts the lever and D-07, and that
  "put a LATCH between" is gone.

**New tests** (D13 §3):
- production declines;
- no candidate composition, and not the committed fixture, latches a
  plate;
- all three shapes (direct, through NOT, through OR) load but are not
  accepted;
- a legacy step-once Zone loads, and its latch survives a reload.

**Sabotages, each failing its target:**
- the old emitter on the production path (3 tests);
- 1a removed;
- the walk narrowed to direct inputs (the NOT and OR shapes fail, and
  direct still passes);
- the refusal moved into a model validator, which breaks M-1's loads
  (3 tests);
- the 14 map sabotages, re-run.

**Next in D13:** 1c after Prod's lever placement; then 1d.

## DESS-21 — fixed at the root

**`RailNetwork` now refuses a name under a reserved latch namespace**
(`graph_` or `minor_`), as physics packages already do
(`refuse_reserved_package_id`, which now says what it is refusing).
- A span latch persists as `network_id/latch_id`. A railway named into
  either space would have had its span latches read down the room-graph
  or minor path.
- No fixture, and no composed Zone, declares a rail network, since no
  composer emits one. So the model-level refusal cannot reject any saved
  Zone.

**The second half of the original fix is not needed.** With the name
refused at the model, no validated Zone can make `record_latch`'s
`graph_` branch meet a rail, so a guard there would be dead code.

**Evidence:** one parametrized test covering both prefixes, plus a legal
name that merely starts with "graph". It fails by name with the refusal
removed. The packet mirrors of `zone.py` and `physics.py` are copied, and
`check_packet` is clean.


## D-01 — the protocol field landed (D14 §7, Dess's half)

**The field.** `CampaignSave.self_addressed_echoes: bool = False`,
documented as fixed per campaign.
- A save written before it loads with it off, and keeps its behaviour
  for its whole life.
- A no-op until Prod's integration sets it `True` at creation
  (`campaign.py`'s new-campaign `CampaignSave(`), in the same commit as
  the grant filter.

**Exports and mirrors:**
- `make export` changed no generated file, because the protocol schema
  covers client messages.
- The packet mirror of `protocol.py` is copied.

**Tests:**
- A pre-policy save loads with it off.
- On, it round-trips.
- The legacy test now asserts the field exists before removing it, so
  the removal is no longer vacuous.
- Defaulting it to on fails by name.

## W2 wiring, part A — the two views moved into the schema layer

**What moved.** `inventory_view.py` and `map_view.py` now live in
`bridge/archipepsi_bridge/schemas/`.
- They use the schema modules' dual imports.
- Each has one byte-identical copy in the v0.8 packet, following the
  precedent of `gear.py`, `signal_graph.py` and `minors.py`.
- It is a pure move: no behaviour changes, and 17 tests pass unchanged
  except for their import path.

**Why.** The snapshot can then derive the inventory and the map on the
model, as it already derives `available_capabilities`, without an edit
to `campaign.py`'s snapshot builder, which is outside the released
seams. `record_room_entered` can also reuse the discovery derivation.

## W2 wiring, part B — discovery is recorded (`visited_rooms`, `RoomEntered`)

**The field.** `ZoneProgress.visited_rooms: tuple[str, ...] | None`.
- `None` means no record yet, and that is also what any save written
  before the field loads as.
- It is monotone, `ROOM_PERSISTENT` (like a station reached), and bounded
  by `ZONE_MAX_CHAMBERS`.

**The intent.** `RoomEntered`, applied by `transitions.record_room_entered`
(listed in `TRANSITIONS`).
- Routed in `server.py` and handled in `campaign.py`'s progress seam.
- Idempotent.
- Refuses a room the accepted Zone does not declare.
- A Zone with no record starts it with the rooms the save already
  proves, plus the one entered. So nothing is invented, and the map
  never shows fewer rooms after the first report than before it.

**The map.** Discovery is now the record joined with what the save
proves, so a report the engine missed never hides a room a fact names.

**Exports and mirrors.** `make export` regenerated `protocol.schema.json`
with the new intent. The packet mirrors of `protocol.py`,
`transitions.py` and `map_view.py` are copied. The packet's own
`generated/` copies were already frozen history before this, so they are
left alone.

**Evidence.**
- `tests/test_room_discovery.py`, 6 tests. One sends raw JSON through
  `BridgeServer.dispatch` into the save.
- 6 sabotages, each failing its target:
  - the first entry forgets the proof;
  - the declaration is unchecked;
  - the map ignores the record;
  - the map ignores the proof;
  - the server does not route it;
  - the handler branch is missing.

**Note D-2 (Dess → Prod).** Send
`{"type": "room_entered", "zone_id", "room_id"}` wherever the minimap
marks a room seen. A resend is harmless.

## W2 wiring, part C — the snapshot carries the inventory and the map

**The fields.** `CampaignSnapshot.inventory` and
`CampaignSnapshot.zone_map` (the latter `None` with no Zone) are computed
on the model from what the snapshot already carries (the fold, the slots,
the consumable uses and generation, the active Zone record), exactly as
`available_capabilities` is. `campaign.py`'s snapshot builder is
untouched.

**The inventory adds only what the fold lacks, keyed by
`component_id`:**
- activation;
- the slots it may and does occupy;
- charges;
- siblings.

Name, kind, mk and history are read once, from `mechanics.owned`, by the
id. This is a change to W2.1's shape, made because of what the size tests
measured:
- **The first shape repeated the fold.** It made the inventory about 80%
  of the fold's size, around 44% of an elided snapshot, and broke the
  premise that the fold is what an elided snapshot is made of.
- **The join-by-id shape is 16-21%.** All 22 size tests pass. The worst
  reachable snapshot is 1,069,647 bytes against the 8 MiB client buffer
  (7.8x headroom).
- **C-INVENTORY still holds.** There is no second copy of an item, and
  no upgrade arithmetic: the join is a lookup, and history lives on the
  resolved item in the fold.

**The consumable rule is now in one place.** `inventory_view.charges_left`
is the only rule, and `CampaignSave.charges_left` delegates to it.

**Exports and mirrors.** `make export` regenerated `protocol.schema.json`
with the snapshot's two new fields. The packet mirrors of `protocol.py`,
`inventory_view.py` and `map_view.py` are copied. `check_packet` is
clean.

**Evidence:**
- `tests/test_snapshot_views.py`: the snapshot equals the direct
  projections, both reach the wire, and there is no map without a Zone.
- The inventory tests now read history through the join and assert the
  view repeats nothing.
- Sabotage "inventory from nothing": caught.
- Sabotage "map always absent": caught.

**Note D-3 (Dess → Prod).** The menu reads
`snapshot.inventory.items[*]` joined to `snapshot.mechanics.owned` by
`component_id`. The minimap, 3D map and journal read `snapshot.zone_map`,
overlaying only the live `transitioning` state.

## DESS-23 — fixed at acceptance

**The rule.** `validate_zone` now refuses a declared key that no LOCKED
door names (`_keys_that_open_nothing`).
- It applies at acceptance only. The model still loads such a Zone, so
  no save can break on it, and the audit's NO_LOCK mutation remains
  schema-valid.
- The committed sample (20 Zones) and the candidate hold none, and a
  test says so.

**Evidence:** the NO_LOCK mutation is now refused at acceptance, and
removing the guard fails that test by name. The packet mirror of
`zone.py` is copied and `check_packet` is clean. Bridge suite: 2125
passed.

## W1.2 — H-PRESSURE-C step 2 (1d, the bridge half): a door held by a declared weight

**`SensorNode.held_by`** is valid on plates only.
- A `plate -> shutter` route, open only while pressed, is legal exactly
  when every plate on it names its weight. It needs no latch.
- The player's body never counts as the route's solution.

**The weight must:**
- be a declared `TransportedObject`;
- be a hand carry. The object model already refuses anything else
  today; the plate's own rule keeps the guarantee once manipulation is
  built;
- have a class at least the plate's;
- have the plate's room in its volume, and the far side outside it, so
  it can never be carried through the door it holds;
- not be a receiver's object;
- hold one plate only.

The chain must be direct: a latch would make the route permanent, and
that is the lever's job.

**The route search.** A held door is a variable set in the plate's
room, so the door stays closed until the plate is reached. The search
also refuses:
- a weight homed where it cannot be reached without the door ("behind
  the route it holds");
- a carry from home to plate with no plain doorway path inside the
  volume. This is conservative: it may refuse an arrangement a key would
  make possible, and never certifies an impossible carry.

**DESS-24's second half:**
- the object-only refusal no longer calls the carry verbs unbuilt, and
  names `held_by`;
- the route refusal's advice now names the carried weight, not "a plate
  that counts the player";
- `plate_accepts_player`'s docstring is corrected the same way.

**Also:**
- **The map.** A held door reads `unknown` with "worked live by a
  control": whether the weight is on the plate right now is the engine's
  to say. That is W2.2's previously unreachable branch, now tested.
- **Exports and fixtures.** `make export` updated `zone.schema.json` and
  `protocol.schema.json`. The legacy fixture regenerates with
  `"held_by": null` on its plate, its only change (RoomGraphs reads
  sensors with `.get`). Packet mirrors are copied.

**Evidence:**
- `tests/test_held_route.py`: 16 tests.
- 10 sabotages, each failing its target: the held branch, the far side,
  the chain shape, the class, the volume, the receiver clash, two
  plates on one weight, an undeclared weight, the door open in the
  search, and the weight's home.
- Bridge suite: 2141 passed.

**Next:**
- a composer and a fixture for Prod's acceptance (1d-ii);
- 1c after Prod's lever placement.


## W1.2 — 1d-ii: the held-route composer and its fixture

**The composer.** `latched_route.compose_held_route` puts D13 1d's
route on a real Zone through the same search and room rules as the
latch route:
- an object-only MEDIUM plate held by a 40 kg `counterweight`, driving
  the shutter directly;
- the weight homed in the plate's room, with its volume that room plus
  one plain near-side neighbour, never the far side.

It is an explicit step and never a default. The candidate profile does
not run it.

**The fixture.** `godot/tests/fixtures/held_route_zone.json`: the played
Zone with the held plate in c002 and the shutter across `e:c002:c003`.
- Regenerate it from `bridge/` with
  `python -m archipepsi_bridge.playtest dump-held --out ../godot/tests/fixtures/held_route_zone.json`.
- A currency test names that command.

**Evidence:**
- The composed route is sound: it passes reachability, and acceptance
  raises no D-07 error.
- The fixture is current.
- A too-light weight, or one allowed across the door, makes the composer
  decline rather than emit.
- The shared decline message now says "route", not "latch".
- Bridge suite: 2143 passed.

**Note D-4 (Dess → Prod), for H-PRESSURE-R's held arrangement.** Play
it on this fixture:
- the weight carried onto the plate opens the door, which stays open
  while it rests there;
- lifting the weight while the player is in the doorway uses your
  closure interlock;
- a reload restores the weight's pose from `object_poses`, so the door
  opens with no plate state saved.

If you want a `held-route-fixture` make target beside
`latched-route-fixture`, it is yours to add. The command above is its
recipe.

## The owner's rulings on D-02, D-03, D-04, D-01 compatibility and Unweighted (2026-09-25, verbatim)

> Your independent Wave 0–2 work and D-01 landing are accepted. Keep the
> current compatibility boundaries and evidence exactly as landed.
>
> **D-02 — approved with one semantic constraint.** The game owns the
> mechanical requirement for a featured Echo. For Blindside, that means an
> Echo must provide the actual traversal capability the room requires.
> Epsilon may name, style and author the Echo within that mechanical
> contract, and there must be a deterministic guaranteed fallback if
> generated content fails the requirement. `grapple_pull_target` must not
> satisfy a traversal `grapple` requirement merely because it belongs to
> the same broad family or shares the name. Moving an enemy does not prove
> that the player can perform the crossing. Fix DESS-26 accordingly and
> make the capability contract distinguish the affordance that the gate
> actually requires.
>
> **D-03 — approved.** Finish Blindside now with rewards that are not AP
> Checks. Do not place an AP Check behind the capability gate until
> Archipelago's own logic declares that prerequisite and can prove the
> capability obtainable. Keep capability events in the AP logic as an
> explicit deferred task; this ruling postpones that integration rather
> than deleting it.
>
> **D-04 — approved.** Do not deliver manipulation verbs until a real
> room/mechanic has a consumer for one. Do not revive the conflicting
> migration rule. When Prod identifies a concrete consumer, bring the
> smallest verb contract required by that mechanic.
>
> **D-01 compatibility — your current behavior is approved.** Existing
> campaigns do not automatically gain self-addressed Echoes. The legacy
> default stays false. A deliberate developer/owner opt-in for an old
> campaign may exist for testing if useful, but there is no silent
> migration and no inferred entitlement from an old save.
>
> **Unweighted — your ruling is also approved.** Riding the carriage and
> jumping to the sill without using `lightened` is not the valid alternate
> route described by EX50-033. Prod should prevent that accidental
> geometry bypass while preserving the authored `lightened` alternate.
>
> You may now continue the remaining ready Wave 3 work already present in
> the approved handoff scope. H-GEAR remains limited to the 16 costed
> domains. Do not implement D-04 manipulation verbs, and do not fake around
> work that genuinely requires Prod's integration half.

### Deferred, explicitly (not deleted)

- **H-AP-GATE: capability events in the AP logic** (D-03 option E,
  `O05-05.5`). Archipelago declares the prerequisite and proves the
  capability obtainable; the bridge proves the event is physically true
  (the featured Check's qualifying Echo, and its Zone allocated as soon
  as AP logic can reach it). Until then no AP Check, AP-relevant key or
  Zone exit sits behind a capability gate: §29.5a as written, enforced by
  `topology.reachability`.
- **H-ATOM-DELIVERY** (D-04, `O05-08.5`). It opens when Prod names a real
  consumer, and then Dess brings the smallest verb contract that mechanic
  needs. The Amalgam's migration rule stays retired.

## DESS-26 — fixed: a traversal capability is answered only by moving the player

Owner ruling D-02: "`grapple_pull_target` must not satisfy a traversal
`grapple` requirement [...] make the capability contract distinguish the
affordance that the gate actually requires."

**The contract, in `schemas/mechanics.py`:**
- `PLAYER_TRAVERSAL_PRIMITIVES` lists the primitives that move the
  player's own body. It is read off what the runtime does:
  - `_grapple` bites a `StaticBody3D` and pulls the player;
  - `grapple_swing` is a held tether on one;
  - `grapple_pull_target` hits only enemies and moves the enemy.
- The ECHOES catalog still files all three under movement. That is
  right for authoring and gates nothing.
- `grapple` is now the anchor-grapples (`grapple_to_surface`,
  `grapple_swing`). So is the `grapple_anchor` affordance, since pulling
  an enemy never touches an anchor.
- `CAPABILITY_AFFORDANCES` states what each capability certifies.
  `TRAVERSAL_CAPABILITIES` names those answered by moving the player, and
  a test holds every one of them to `PLAYER_TRAVERSAL_PRIMITIVES`, so a
  future family member cannot get in on a shared name.

**What it changes.** A campaign owning only an enemy pull no longer
counts as able to grapple or to use grapple anchors, which was physically
true all along. Nothing is written to any save, since capabilities are
derived. No composer emits a grapple-gated edge yet
(`featured_acquisition` is not composed), so no saved route depends on
the old answer.

**Test change, on purpose.** `test_grapple_is_satisfied_by_any_member_of_the_family`
asserted the ruled-out behaviour. It is now
`..._by_every_grapple_that_moves_the_player`, plus two new tests:
- the enemy pull satisfies no traversal capability and no anchor;
- every traversal capability is answered by moving the player.

**Evidence:**
- 3 sabotages fail by name: the enemy pull put back into `grapple`, into
  the anchor, or into the traversal set.
- `make export` changed nothing.
- The packet mirror of `mechanics.py` is copied, and `check_packet` is
  clean.
- Bridge suite: 2145 passed.

## W3.2 — H-QUALIFY, Dess's half: the featured Echo's mechanical contract (`schemas/featured.py`)

**D-02 as ruled.** The game owns the requirement; Epsilon names and
styles within it; a deterministic fallback always qualifies.

**The requirement is a proven function, not a label.** For Blindside's
gantry:
- `FEATURED_REQUIREMENTS["grapple"]` is `grapple_to_surface` with range
  ≥ 20 and pull ≥ 14. The pedestal grapple the development scenario
  reaches the deck with is exactly that (`railway_scenario.gd:43-57,
  361-364, 747-756`).
- `grapple_swing` is also a `grapple`, but nothing has measured it on
  the gantry, so it does not qualify there.
- A requirement may only name a primitive that moves the player within
  its traversal capability. That is DESS-26's contract, enforced by the
  model.
- `validate_zone` now refuses a featured acquisition whose capability
  has no proven requirement (no name-only claim).

**`check(log, candidate, requirement, next_seq)`** folds the candidate
onto the log as `append_interpretation` would stamp it, and passes only
if **this** Echo created or changed a non-consumable Action meeting
every floor:
- an upgrade that makes an owned grapple reach counts;
- an owned grapple does not excuse an Echo that supplies nothing;
- an enemy pull, a swing, a short range, a weak pull or a consumable are
  each told why.

**`fallback_interpretation(...)`** is deterministic, uses the
requirement's own floors, and is named from the item. A Signal Key
yields a working grapple.

**Recipient-independent.** A featured Check's Echo is held to the same
requirement whoever the original was addressed to (D-01 makes the Echo
exist either way).

**Evidence:**
- `tests/test_featured_requirement.py`: 18 tests.
- 7 sabotages, each failing its target: any primitive passes, the floors
  are ignored, a consumable passes, an owned grapple excuses the Echo,
  the fallback is too weak, the featured room is unguarded, a
  requirement may name anything.
- One v0.8 packet copy of `featured.py`; the `zone.py` mirror copied;
  `check_packet` clean; export unchanged.
- Bridge suite: 2163 passed.

**Note D-5 (Dess → Prod): the pipeline's half, in `epsilon/*` and
`campaign.py`'s grant path, which were not released to me:**
1. **At grant:** `req = featured.requirement_for(zone, location_id)` for
   the Zone record whose `featured_acquisition` names the location.
2. **Request:** carry `req.describe()`, for example as
   `EchoGenerationRequest.required_function`, so the provider authors
   within the contract.
3. **Semantic step:** add
   `featured.check(save.interpretations, candidate, req, save.next_interpretation_seq)`
   to the validation checks when `req` is set.
4. **After the one repair still fails:** substitute
   `featured.fallback_interpretation(req, location_id=…, item_name=…, source_game=…, recipient_name=…)`
   for the generic fallback.
5. **Combined tests:**
   - a provider returning an enemy pull yields the qualifying fallback;
   - a good provider's Echo is kept;
   - the same holds for self-addressed and foreign originals.

## Note D-6 (Dess → Prod): Blindside's composition, proposed interface (O05-05.2, for H-BLINDSIDE)

**What H-BLINDSIDE needs from the bridge is ready:**
- the D-01 field;
- DESS-26;
- the featured contract (D-5).

What is missing is the composition: the three-dock layout with an
acquisition branch, the S2 junction, and the gantry whose control
commissions S2→S3. It touches three things:
- the Zone schema: `RailSpan` names a control room, but not how the
  control is reached;
- the route search, which has no rail model;
- your `RailNetworks`, which builds ground-level controls. The gantry
  and its ring exist only in `railway_scenario.gd`.

**Proposed, in the same order as the lever (D13 1c):**
1. **Schema (Dess):** `RailSpan.control_placement: Literal["ground", "gantry"] = "ground"`.
   A gantry control is overhead, reached by an anchor-grapple, so the
   capability it demands is `grapple`. That is DESS-26's contract,
   derived, never declared separately.
2. **Route search (Dess):** a span becomes a route between its docks'
   rooms, open once commissioned. Commissioning means reaching the
   control room, with `grapple` for a gantry.
   - §29.5a applies unchanged (D-03). No AP Check, no AP-relevant key and
     not the Zone exit may lie beyond a gantry-gated span.
   - So S3 holds only local rewards, and the featured Check sits on the
     acquisition branch, before the gate.
3. **Your gantry placement in `RailNetworks`:** the development
   scenario's deck (3.1 m up, 7.5 m out) and its anchor, built for a
   `gantry` control.
4. **The composer (Dess), after 3:** a candidate preference that selects
   the supported situation on the real composer. It never loads a
   fixture or patches a save (O05-05.2's wording).

**Your confirmation needed:** the field name and the gantry's geometry.
Once you confirm, 1 and 2 land as search-only rules, and 4 waits for 3.

## W3.5 — H-GEAR: stopped with options (D16), by the owner's own rule

**Why it stopped.** Checked before building, H-GEAR meets "a new owner
decision, a material contract conflict, or a genuinely new cross-lane
dependency" four times over:
- the design's budget rules disagree on trigger clauses (§4.6.1 against
  `04:760`), and no clause catalog exists;
- the piece shapes disagree, on USEFUL completion and on
  exactly-one against at-most-one HIGH;
- no Forge or Static transaction is approved (B4 pending, D-14 open);
- only 3 of the 16 costed domains have a runtime stat path (speed, jump,
  landing).

The research was a read-only pass, and every claim in D16 cites its
line.

**Recommendation: G1.** The LEGS slice (speed, jump, landing): USEFUL
pieces with a profound magnitude, which land in band under both budget
readings without a clause. Echo acquisition only, four territory slots,
and source-owned clamped multipliers. The support gate opens only once
Prod's StatStack applies them.

**Nothing is implemented.** `SUPPORTED_GEAR_DOMAINS` stays empty.

## W1.2 — H-PRESSURE-C step 3 (1c): the lever, admitted

**Unblocked by Prod's N-5.** `RoomGraphs` has placed a `PULSE_BUTTON`
as a thrown bolt since `2346261`, and the engine keeps its own placeable
list, which includes the lever (N-4). So the bridge half lands on its
own, adopting Prod's offered patch
(`post_playtest_evidence/H-PRESSURE-R_bridge_half_offer.patch`), adapted
to the split composer.

**What landed:**
- `signal_graph.py`: `PULSE_BUTTON` joins `ZONE_PLACEABLE_SENSOR_KINDS`
  and `ROUTE_SENSOR_KINDS`, with Prod's D-07 comments.
- `zone.py`:
  - the plate's body rule skips a lever, which is pulled, not stood on;
  - the placeable refusal now names a target, not a button;
  - the held-requirement refusal now says a plate is legal when it names
    its weight (`held_by`, 1d), and a permanent opening needs a lever
    into a LATCH;
  - the softlock refusal names the lever's action ("by pulling the
    lever") when a lever is the control;
  - the docstring records that `plate -> LATCH -> shutter` still loads
    (M-1) and is refused at acceptance (1a).
- `latched_route.py`: `compose_latched_route` emits
  `lever -> LATCH -> shutter` through the shared search.
  `DECLINED_UNTIL_LEVERS` is gone. The legacy entry is unchanged.
- `playtest.py`: `lever_route_zone()` and `dump-lever`. `_must_emit`
  compares steps only, because the policy excuse has ended.
- `tools/compose_latched_route.py`, the live suite's seeding tool, gains
  `--form lever`. The default stays `legacy`, so every existing caller
  runs exactly as before. It had no test; it now has four, each form
  landing on its own fixture and refused against the other's.
- Regenerated, never hand-edited:
  - `candidate_zone.json` gains exactly the c009 lever route and its
    edge's `opened_by`;
  - `lever_route_zone.json` is new: the lever in c002, the shutter
    across `e:c002:c003`;
  - `constants.gd` changes one line: `SIGNAL_ZONE_PLACEABLE_SENSORS`
    gains `PULSE_BUTTON`;
  - the packet mirrors of `signal_graph.py` and `zone.py`. The HEAD
    mirrors were identical before the copy, and `check_packet` is clean.

**Adapted from Prod's patch, and why:**
- Prod's docstring put the step-once refusal "where Zones are MADE".
  1a refuses it at acceptance (`validate_zone`), so the docstring says
  that.
- The held-requirement message keeps DESS-24. For a plate it gives no
  "put a LATCH between" advice, because that is D-07's rejected chain. A
  bare lever never reaches the message: the room graph refuses it first
  ("move for one tick").
- Prod's "no composition emits a plate that latches" merged into the
  existing test. That test now covers the production latch step and the
  lever fixture too. It asks both the validator's helper and Prod's
  independent `upstream` walk, so a blind helper cannot hide a plate.
- Prod's "a save composed before D-07 still loads" was already held by
  1b's legacy restore test.

**Tests:**
- New:
  - the lever route is accepted end to end (model, search, acceptance);
  - it opens for good after one pull;
  - a bare lever is refused;
  - a lever softlock is named as a pull;
  - the lever's latch is recorded, survives a reload, and the map reads
    the door open;
  - the near and far route searches run for the plate and the lever;
  - the legacy entry still makes only M-1's plate, on the doorway the
    lever takes;
  - both route fixtures are current.
- Changed on purpose, each to assert the new rule:
  - the composer tests use the production entry;
  - the production-decline test is replaced by the emission tests;
  - the candidate profile expects every step emitted and one lever
    graph, and its placement test reads the profile's own lever;
  - `test_signal_graph`'s placeable test accepts the lever and refuses
    a target.

**Sabotages.** Each one failed by name and was restored byte-for-byte:

| # | rule removed | caught by |
|---|---|---|
| S1 | lever out of `ROUTE_SENSOR_KINDS` | the lever route tests, the composer tests (17) |
| S2 | lever out of `ZONE_PLACEABLE_SENSOR_KINDS` | the same, and the placeable test (18) |
| S3 | the plate body rule applied to a lever | the lever route tests (17) |
| S4 | the softlock names the plate | the lever softlock test |
| S5 | the composer emits the retired plate | emission, acceptance, fixture, no-latching-plate (9) |
| S6 | the composer declines again | the emission tests (15) |
| S7 | the validator's helper blinded and the composer emits a plate | the independent walk: `['c002/step_plate']` |
| S8 | the lever fixture edited | the fixture test |
| T1 | the tool's lever form composes the plate | its two lever cases |
| T2 | the tool skips the fixture comparison | both refusal cases |
| T3 | the tool ignores `--form` | its two lever cases |

**Suites:** the bridge suite, run as the gate runs it, gives 2175 passed
and 4 skipped. The schema suite gives 131, and `check_packet` is clean.

**Note D-7 (Dess → Prod), for H-PRESSURE-R and the live suites:**
1. The candidate composes the lever route again, in c009 across
   `e:c009:c010`.
   - `godot-candidate-live` (your `9d79fb7`) now demands the third
     doorway and the route shutter back. Please run it on the
     regenerated `candidate_zone.json`.
   - Its `LATCH_POLICY_DECLINE` branch can no longer be reached.
2. `lever_route_zone.json` is the production composer's output on the
   played Zone: the lever in c002, the shutter across `e:c002:c003`.
   That is the same room and door as the legacy plate and your explicit
   substitution. `godot-latched-route-live` can play it as composed
   (N-5): seed with `tools/compose_latched_route.py --form lever
   --expect ../godot/tests/fixtures/lever_route_zone.json`. Without
   `--form`, the tool is M-1's legacy replay, unchanged.
3. The Makefile is yours, so I did not touch it. If you want targets,
   the recipes are:
   - `lever-route-fixture`: `cd bridge && $(PY) -m archipepsi_bridge.playtest dump-lever --out ../godot/tests/fixtures/lever_route_zone.json`;
   - `held-route-fixture`: the same, with `dump-held` and
     `held_route_zone.json`.
   The `latched-route-fixture` comment still calls it P14's acceptance
   input; it is now M-1's legacy input.
4. `SIGNAL_ZONE_PLACEABLE_SENSORS` is now plate and lever, so your
   `godot-signal-graph` subset check should pass. Godot cannot run here,
   so none of the live suites were run by me.

## Readiness for Prod: what you can consume now, and what waits (at `462bf42`)

The brief asks for one compact table. Each row names the Dess half that
has landed. "Waits on" names the next owner of the work. Nothing in the
Dess column stands in for your runtime half.

| Item | Dess half, landed | You can consume now | Waits on |
|---|---|---|---|
| H-RESUME-C (D-06, M-2) | review `9503650`, M-2 pinned | your H-RESUME-R as landed | nothing |
| H-PRESSURE-C 1a + 1b (D-07, M-1) | `d2ffea0` | legacy Zones load and play as saved; `latched_route_zone.json` unchanged | nothing |
| H-PRESSURE-C 1c | `462bf42` | `lever_route_zone.json`; the candidate's c009 lever route; `compose_latched_route.py --form lever` | you: `godot-candidate-live` on the new candidate, `godot-latched-route-live` on the lever (D-7) |
| H-PRESSURE-C 1d | `bca85d4`, `70778bc` | `held_route_zone.json` | you: play the held route (D-4) |
| H-RELEASE-C | `172f6c3` (the D12 room cards) | the three cards | you: the transit-ride fix (N-2), as the owner ruled |
| H-KEYS | `fe1c68d`; DESS-23 at `0ac9504` | acceptance refuses a key that opens nothing | nothing |
| H-UI-DATA | `fbe5aa3`, `cf0a2d2`, `7fc7918` | `CampaignSnapshot.inventory` | you: read it (D-3) |
| H-MAP-DATA | `3ac9d26`, `5ecb6e9`, `7fc7918` | `CampaignSnapshot.zone_map`; the `room_entered` intent | you: send `room_entered` (D-2), read `zone_map` (D-3) |
| H-SELF-ECHO (D-01) | contract `21cc34d` (D14); field `764f9db` | `CampaignSave.self_addressed_echoes`, false by default | you: D14 §7 (creation true, the grant filter, the reveal, `test_full_loop.py`) |
| DESS-26 (D-02) | `f877fe8` | an enemy pull no longer answers `grapple` | nothing |
| H-QUALIFY (D-02) | `8ab7aeb` (`schemas/featured.py`) | `requirement_for`, `check`, `fallback_interpretation` | you: the pipeline wiring (D-5) |
| H-BLINDSIDE composition | proposal `f316aa4` (D-6) | nothing yet | you: confirm the field and the gantry geometry. Then Dess lands the schema and search, you place the gantry, and Dess composes |
| H-AP-GATE (D-03) | deferred by ruling, recorded | nothing | a later decision to integrate capability events |
| H-ATOM-DELIVERY (D-04) | deferred by ruling, recorded | nothing | a real consumer you name, then the smallest verb contract |
| H-GEAR | options `07584fc` (D16) | nothing | the owner's rulings |
| CI | none | nothing | the owner (your N-6) |

## The owner's rulings on D16 (H-GEAR) and the Wave 3 checkpoint (2026-09-25, verbatim)

> Checkpoint accepted.
>
> `462bf42` and `bab79db` count as the completed Dess-side Wave 3 bridge checkpoint.
>
> The lever result is approved as landed:
> - new permanent routes use lever → latch → shutter
> - M-1 legacy step-once plate saves continue loading and behaving as saved
> - the replay tool may support both forms while keeping legacy as its current default
> - the live Godot verification remains Production’s responsibility
>
> D16 / Gear rulings:
>
> 1. Approve G1 for movement stats.
>
> Pair speed, jump and landing Gear only with the corresponding runtime stats that already exist. Do not create a second or parallel Gear-stat system.
>
> 2. Approve strongest single-stat pieces only for now.
>
> Until a clause catalogue exists, a Gear piece should express one bounded, understandable stat effect. Do not invent compound/affix combinations ahead of that catalogue.
>
> 3. Approve no Forge or Static acquisition path.
>
> For this scope, Gear comes only from Archipelago items’ Echoes. Do not add Forge, Static or another acquisition economy for Gear.
>
> 4. Approve the later HIGH restriction.
>
> At most one HIGH piece may be effective/equipped at once.
>
> Treat HIGH as a balance/classification rule, not as part of persistent item identity, so later balancing does not require save migration.
>
> After landing the ready D16 work under those rulings, stop at the Wave 3 frontier.
>
> Do not begin the 0.5 programme yet. Production still has the outstanding D-2 through D-7 integration seams and Arty is still completing the current interface work. We’ll open 0.5 deliberately as a team once the current 0.4 integration frontier is synchronized.
>
> If Production hands back a currently listed bridge dependency, you may resume that approved seam without waiting for a new general go-ahead. Otherwise hold at the Wave 3 checkpoint.

**Handed back since, and taken under that rule:** Prod's N-8 (a
`--form held` for the replay tool, D-4's seam), N-10 (a
`passing_zone.json` fixture for H-PASSING) and N-11 (the `about` key for
a refused `slot_action`, H-UI-DATA's seam).

## W3.5 — H-GEAR, G1 as ruled: the bridge half, gate closed (`f9330de`; `docs/D16_H_GEAR_OPTIONS.md`, "G1 as ruled")

**The rulings, as held:**
- **1:** each paired domain multiplies a stat the StatStack already
  moves: speed `move_speed` ×1.18, jump `jump_height` ×1.30, landing
  `air_control` ×1.90 (Design 1 §16.1's LARGE values). There is no
  Gear-only stat and no Gear-only clamp.
- **2:** one domain at `mag_profound`. Another domain, a weaker
  magnitude or a second intrinsic is refused, and each refusal names
  its ruling.
- **3:** a piece is an Echo component (`kind: "gear"`). A save wearing a
  piece its log never made is refused on load.
- **4:** a piece stores atoms only, as the grammar's parallel lists.
  Factor, territory and tier are derived when read, so neither a
  rebalance nor HIGH's later two-atom shape needs a migration.

**Landed:**
- `schemas/gear.py`: `GEAR_EFFECTS`, `LEGAL_MAGNITUDES`,
  `refuse_illegal_piece`, `effects_of`, `worn_effects`, `TERRITORIES`.
  The gate's refusal now names the paired stat and what opens it.
- `schemas/echo.py`: `GearComponent` joins the union, and the `gear_`
  id prefix is admitted. `gear` joins `COMPONENT_KINDS`, which is what
  a provider is offered, only once the gate opens.
- `schemas/mechanics.py`: the fold refuses a link to or from Gear.
  Upgrade, modify and merge already refused any kind they do not list.
- `schemas/protocol.py`: `GearSlots` and `_reject_unwearable`;
  `CampaignSave.gear` and `CampaignSnapshot.gear`; the computed
  `gear_effects`; the `GearAction` intent.
- `schemas/transitions.py`: `gear_action`.
- `schemas/inventory_view.py`: `activation: "worn"`, `GearFacts` per
  Gear item, and `territories`.
- `server.py` and `campaign.py` (the intent seams): the route, the
  handler, and the `about` key.
- `epsilon/requests.py`: `gear_domains` and `gear_magnitudes` are
  offered only with the gate open. Until then the request is
  byte-identical, so the playtest baseline did not move. It is retaken
  deliberately in the gate-opening commit.
- Regenerated, never hand-edited:
  - `generated/echo.schema.json` and `protocol.schema.json`;
  - Prod's `equipment_snapshot.json` and `journal_snapshot.json`, by
    their own unchanged targets. The diffs are additive only: an empty
    `gear`, `gear_effects: {}` and four empty territories.
- The packet mirrors of all six schema files. `check_packet` is clean.
- Not exported: the factor table. The engine reads derived numbers from
  the snapshot. An exported table would invite the second derivation
  ruling 1 forbids.

**The gate stays closed** until Prod's half is in (note D-8), the
lever's order.

**One interpretation, for the owner.** §16.5's ×1.45 walk-speed cap is
not applied. The stack's existing `SPEED_MULT_MAX` (×1.6) is the one
envelope, because ruling 1 forbids a Gear-only clamp and changing the
stack's cap would change existing traits. A profound speed piece alone
is ×1.18.

## Prod's hand-backs, answered

- **N-11 (H-INVENTORY):** `_about` returns `slot_action:<slot>:<id>`, and
  `slot_action:<slot>:` for a clear. The whole path is tested: parse,
  route, refuse, and the error frame's key.
- **N-8 (the held route):** `tools/compose_latched_route.py --form held
  --expect ../godot/tests/fixtures/held_route_zone.json`. The composed
  save carries the counterweight, whose pose the bridge keeps across a
  restart. Each form lands on its own fixture and is refused against
  the others'.
- **N-10 (H-PASSING):** `godot/tests/fixtures/passing_zone.json` is the
  candidate campaign's `zone_002`, as the live bridge designs it: Zone 1
  generated and abandoned, then the portal asked again. It is never the
  played Zone relabelled.
  - EX50-011 is hosted as `c025` and EX50-021 as `c024`, matching your
    N-9.
  - The recipe for your `make passing-fixture`: `cd bridge && $(PY) -m
    archipepsi_bridge.playtest dump-passing --out
    ../godot/tests/fixtures/passing_zone.json`.
  - A currency test names it.

**Suites:** the bridge suite gives 2216 passed and 4 skipped; the schema suite gives 131; `check_packet` is clean.

**Sabotages.** Each one failed by name and was restored byte-for-byte:

| # | rule removed | caught by |
|---|---|---|
| G1 | the pairing | the unpaired-domain cases (4) |
| G2 | the magnitude rule | slight and marked |
| G3 | the one-intrinsic rule | the two-atom case |
| G4 | the gate | the closed-gate test |
| G5 | `gear` always advertised | the closed-gate test, the baseline (3) |
| G6 | the load-time wear check | forged, territory and kind cases (4) |
| G7 | the territory check | the HEAD case |
| G8 | the link refusal | the link case |
| G9 | a tier stored on the piece | the atoms-only test |
| G10 | a Gear-only 1.45 clamp | the no-clamp test |
| G11 | Gear shown as always-on | the inventory test |
| G12 | the snapshot ignoring what is worn | three effect tests |
| G13 | atoms offered while closed | the closed-gate test, the baseline (3) |
| G14 | `gear` required in a save | 45, the old-save case among them |
| N11a/b | the two `about` keys | three cases each |
| N8 | the held form composing the lever | its fixture case |
| N10 | Zone 1 passed off as the passing Zone | the currency test |

**Note D-8 (Dess → Prod), for Gear:**
1. `campaign.snapshot()` should pass `gear=save.gear`. It is one line,
   and the function is yours; until it is in, the snapshot shows
   nothing worn.
2. `stat_stack.gd` should multiply `gear_effects[stat]` into each stat's
   product, beside traits, statuses and pulses, before `clamp_stat`.
   There is no separate clamp.
3. The Equipment wall: the four `inventory.territories`, `gear_action`,
   and the refusal key `gear_action:<territory>:<id>`.
4. The prompt, once the gate opens, authors atoms only.
5. Tell me when 1 to 3 are in. The gate then opens in one bridge
   commit, with the baseline retaken in it.

## Readiness update: added since the table (at the hold)

| Item | Dess half, landed | You can consume now | Waits on |
|---|---|---|---|
| H-GEAR G1 (D16, as ruled) | `f9330de` | the `gear_action` intent and its key; `CampaignSnapshot.gear` and `gear_effects`; `inventory.territories` and each Gear item's facts | you: D-8 (`snapshot()` passes `gear`, the StatStack multiplies `gear_effects`, the wall wears Gear); then Dess opens the gate |
| N-8 (the held route) | `f9330de` | `compose_latched_route.py --form held` | you: play it across a real restart |
| N-10 (H-PASSING) | `f9330de` | `passing_zone.json` and the `dump-passing` recipe | you: `make passing-fixture`, and the hosted suite into CI |
| N-11 (H-INVENTORY) | `f9330de` | refusals keyed `slot_action:<slot>:<id>` | nothing |

## Replies to Prod's N-12 to N-15 (at `7166b35`)

- **D-5's `required_function` in `epsilon/requests.py`** (a released
  file). Adopted as landed. It is the field D-5 asked for, and because it
  is serialised absent rather than null, every other request is
  byte-identical, so the baseline did not move. My Gear change to the
  same file merged cleanly beside it.
- **N-12:** accepted as written. Converting the save before the claim is
  the test the rule needed. The file stays as you left it.
- **N-13: no.** `fallback_interpretation` stays free of the §15 reading.
  Every deterministic Echo is labelled by your `_read_and_label`, and a
  second labelling path in `featured.py` is the kind of duplicate the
  pipeline exists to prevent. Your label stays, and so does your test's
  tripwire.
- **N-14: accepted, with the room constraint.** A gantry control demands
  `wall_height >= 8.0` and clear floor for the deck and its approach.
  - It goes into the schema, so the search never certifies a room your
    build would refuse.
  - D-6 steps 1 and 2 (the field and the search rules) are a listed
    dependency you have handed back, so they resume under the owner's
    rule. Your 3 (the gantry placement) and my 4 (the composer) follow.
- **N-15:**
  - **AND, DIRECT and SEQUENCE:** none is planned in 0.4, and no room
    names one. Build none (O05-07).
  - **A `signal_verb` primitive: not now.** The owner's D-04 principle
    is that a verb reaches the player only once a real room or mechanic
    consumes it. A signal verb on an Echo is that delivery. When a room
    names one, it goes to the owner with its consumer, and I add the
    smallest primitive it needs. Your runtime-only landing is yours to
    make.
  - **A recorded LATCH is a macro setter: yes.** It is persistent
    progression, and §14.4 keeps every verb off macro setters. So a
    verb's override is never seen by a recorded latch's set input. That
    is the reading that can never create progression, and the bridge
    already records a latch only from a firing the runtime reports
    (`record_latch`).
