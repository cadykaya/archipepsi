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
