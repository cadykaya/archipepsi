# Overnight 05 — the engine lane's execution log

**Prod (runtime/integration), single writer this run.** The work order is
`docs/ledgers/ov05/01_EXECUTION_PLAN.md`, with its ready queue in
`03_READY_QUEUE.md`. The packet was copied verbatim from the owner's ZIP,
and every file matched `SHA256SUMS.txt`. Dess and Arty are paused.
Findings are `P5-n`. Rows close with a revision, evidence and a scope
limit. This file is the investigation history; code comments state
contracts.

## Start (O05-00.1)

- Branch `claude/archipepsi-0-4-blindside` at `330c555`, equal to
  origin, clean tree. That checkpoint is preserved at the NEW ref
  `review/ov05-start-330c555`; nothing existing was overwritten.
- These refs stay untouched: `claude/archipepsi-echoes-continuation-b1adno`,
  `review/0.4-m2mech-snapshot` and the 0.3 comparison.
- Last frozen full run: `57e962e`, 56/56 local steps
  (`docs/AGENT_FRONTIER.md`). The tree reported at `330c555` is taken as
  delivered at the scope stated there and is not re-run as a baseline.
- **Available here:**
  - Godot 4.5.1 headless, plus xvfb + opengl3 for captures;
  - Python 3.11.15;
  - the Archipelago checkout, so a local real multiworld can run with
    no credentials;
  - 4 cores and 15 GB.
- **Not available:** `ANTHROPIC_API_KEY` is unset, so live Epsilon
  cannot run. Deterministic fallback only, labelled as such. No window
  and no Windows host.
- **Processes:** only this session's. No heartbeat, watcher,
  subscription, schedule or remote-CI polling.
- EX50-011/021/033: the packet's recovered backups are byte-identical to
  `docs/design-library/EX50_entries/`, so the repository copy governs.

## O05 → P map

| O05 | P rows |
|---|---|
| 00 | P00 / P23 |
| 01 | P12 prerequisite / P16 |
| 02 | P16.1–.5 / P03 |
| 03 | P04 / P16 |
| 04 | P03 / P04 / P15 |
| 05 | P01 / P02 / M2 |
| 06 | P01.2 / P05 |
| 07 | P14 |
| 08 | P12 / P13 / P18 |
| 09 | P09–P11 |
| 10 | P04 / P13 / P15 |
| 11 | D-9 / P18 / P19 |
| 12 | P07 / P08 / P21 |
| 13 | P01 / P02 / P19 |
| 14 | P08.1 / P21.4 / D-11 |
| 15 | P21 / P23 |
| 16 | P07 / P10–P20 / P22 |
| 17 | P23 |

## Temporary shared-seam ownership — for Dess's later review

The owner authorised bounded Python/schema/export/test edits for this
run, against accepted semantics only. Each seam is named, with its source
rule, before it is edited. Rows are appended as edits land:

| file / symbol | accepted rule | change | commit |
|---|---|---|---|
| `schemas/protocol.py` `ZoneProgress.object_poses`, `consumed_objects`, `with_object_pose` / `without_object_pose` / `with_consumed` | Amalgam §5.6 step 10 (required physical configurations restored "at saved transforms"); §30.6.1 `ObjectState` AT_HOME / CARRIED / PLACED(room) / CONSUMED; §10.5 (a multi-room carryable is `ZONE_PERSISTENT`) | two bounded fields (max 4 each), both `ZONE_PERSISTENT` in `SAVE_FIELD_CATEGORY`. A pose is a settled room + position + yaw, never a node path. Consumption is monotone and drops the pose | O05-02 commit |
| `protocol.py` intents `ObjectSettled`, `ObjectConsumed`, `ObjectRecovered` | D-8 §11.1 (the owning room is the current room; a crossing is a transfer); P16 `ObjectConsumer`; §10.4 recovery | three client intents, each routed to one transition. None of them is sufficient on its own: consumption still needs the transfer into the consumer's room first | O05-02 commit |
| `transitions.py` `record_zone_state` | D-8 §4: the setter is "where the player performs the interaction". For a variable an `ObjectConsumer` sets, that interaction is installing the object | refuses a `(variable, state)` any consumer sets, so a raw `zone_state_selected` cannot stand in for the delivery | O05-02 commit |
| `transitions.py` `record_object_consumed` | P16 uniqueness (O05-02.4) | the first install consumes the object. A repeat is absorbed only when its consequence already holds; anything else is refused | O05-02 commit |
| `transitions.py` `recover_transported_object` | §10.4 recovery keeps the object's identity | refuses an installed object (no duplicate) and drops a stale pose | O05-02 commit |
| `transitions.py` `record_object_settled` (new) | §5.6 step 10 | records a settled pose only for a declared, unconsumed object, in a room inside its volume, at finite coordinates | O05-02 commit |
| `campaign.py` `handle_progress`, `server.py` routing | existing progress dispatch | the three intents above | O05-02 commit |
| `cross_room.compose_zone_state` (Dess's D-8 composer) | D-8 "one gate per doorway", the rule P14's composer already applies from its side | (a) skips a gated edge that already carries `opened_by` or `requires_state` (P5-1); (b) new keyword `reader_order="furthest"|"nearest"`, **default unchanged**. `"nearest"` keeps reveal and return at the control's junction (O05-04.2) | O05-04 commit |
| `server._about` | the existing `BridgeError.about` convention (domain key; empty means unchecked) | adds `zone_state_selected:<zone>:<variable>:<state>`, so the lever's PENDING can be resolved as REFUSED on an exact match | O05-04 commit |
| `candidate.py` (new), `CampaignEngine.candidate_steps`, `--candidate` | O05-13: an opt-in profile, off by default; the pattern of `quiet_generation` | runs `zone_state`, `latched_route`, `transport` after the graph is proved and before `accept_zone`. On host re-selection it is re-applied from a stripped Zone. Records each step, emitted or declined, under `<save dir>/candidate/` | O05-02 commit |
| `playtest.dump-candidate` (replaces the new `dump-transport`) | fixtures generated from source | the transport and reversible fixtures are `candidate.apply` on the played Zone, with freshness tests | O05-02 commit |
| `transport_route.py` (new) | P16 `TransportedObject`/`ObjectConsumer`; D-8 `permanent` lifetime; §0-bis (a declared gate is allowed, an undeclared one never is) | an explicit composer step in the same shape as `cross_room.py` and `latched_route.py`. It is never a default, so digests and comparisons do not move | O05-02 commit |
| `transitions.record_latch` + `_accepted_rail_latches` (new) | `RailSpan.latch_id` "is the persistence handle: a commissioned span is the repair that survives leaving and coming back, recorded through the same latch machinery a physics package already uses" (zone.py) | a third, separately evidenced path for a declared railway's controlled span (P5-9); the physics and `graph_` paths are unchanged | `d92d723` |
| `diagnostic.py` (launcher) | O05-15.1: "reuse the current launch/bootstrap idioms"; the follow-up 02 slot/marker rule | `--candidate[=STEPS]` mode: its own slot, a profile marker, a banner naming the profile and that nothing is staged. The single write moved into one `_mark` shared by both markers | `d92d723` |
| `latched_route.compose_latched_route` (Dess's P14 composer) | P5-1's "one gate per doorway", extended to rooms: one relationship's control per room; P5-2/P5-8's walkable, one-floor rooms | skips a plate room already holding a Zone-state setter, a carried object's home or its socket (P5-11); stands plates only in arenas and treasure rooms, on the floor of the doorway they open. **P14 alone composes exactly as before** (c002; tested) | this checkpoint |
| `candidate.STEPS` order | O05-13 | `zone_state, transport, latched_route` (was `zone_state, latched_route, transport`): P14, the step with the widest choice of rooms, now goes last (P5-11) | this checkpoint |
| `CampaignEngine._candidate` re-certification | O05-13.3 "rejected hosts/choices must not silently drop allocated Checks"; acceptance does not re-run `validate_zone` | the profile's Zone is re-run through `validate_zone` with the provider's own offer and allocation, and through the whole Zone schema. A result that INTRODUCES an error is discarded whole and recorded (`certified`, `refused_by_validate_zone`) | this checkpoint |
| `CampaignEngine` certify call: `zone_budget` | `epsilon/base.py`: the provider is accepted "against `request.campaign.zone_budget`"; "accepting against the default instead held a 1000-point Zone to a 200-point Zone's limits" | the re-certification passes the same budget (P5-12). Before, the prototype's 200 points applied and the "already failing" comparison hid it | O05-06 commit |
| `schemas/minors.py` (new) | O05-06.1 "select each minor by its actual space, entrances, mechanisms, reward and recovery requirements"; EX50-033 §3/§5 (the bolt is the persistent fact, the crate package-local, LIGHTENED ephemeral) | the occurrence contract: shell, catalogue id, host chamber type, the way in, the sealed openings, the latches it may record (`bolt`), completion and recovery in words. Space and doorways stay the registry entry's | O05-06 commit |
| `schemas/physics.py` `MINOR_PACKAGE_PREFIX`, `RESERVED_PACKAGE_PREFIXES`, `refuse_reserved_package_id` | the `graph_` reservation's own reason: a physics latch must not share an identity with another kind | `minor_` reserved beside `graph_`; the existing message is unchanged for `graph_` | O05-06 commit |
| `transitions.record_latch` + `_accepted_minor_latches` (new) | the graph path's four facts (accepted Zone, committed layout, placed room, declared latch) | a fourth, separately evidenced path: `minor_<room>/<latch>` only for a room the ACCEPTED Zone builds from a contracted minor shell, only that contract's latches, and never a name a rail network also has | O05-06 commit |
| `shells.is_offerable` | `AUTHORED_CONTENT.md`: the offer is what a provider may choose | an entry tagged `minor` is never offered; only the candidate `minors` step places one | `83044c3` |
| `godot/content/registry/minor_rooms.json` (new pack) | S12 registry contract; no `review` field = not art | `minor_unweighted_switch`: the scenario's own room (`UnweightedSwitchRoom`) hosted by `UnweightedSwitchHosted`, a doorway in A's wall and the way on cut at the sill in G | `83044c3` |
| `minor_hosting.py` (new), `candidate.STEPS` += `minors`, `candidate.strip` (+ `unhost`) | O05-06.1/.4/.5; P5-13 (no counted content removed); "an incompatible host declines by name" | the minor is ADDED behind a dead-end arena and takes that arena's Check; the parent keeps its fight and objective. Runs last. `strip` hands the Check back so re-hosting still works | O05-06 commit |
| `CampaignEngine._certify_offer` | `validate_zone` refuses a shell the offer lacks; the provider's offer never has a minor | when the profile includes `minors`, the certification offer is the provider's plus each minor's own registry rule -- and nothing looser | O05-06 commit |
| `mock_ap.MockServerState.bound/store`, `MockAPBackend.for_campaign`, `server._connect_mock` | `MockServerState`'s own docstring: "truth that survives quit/reload/reconnect"; a real Archipelago room keeps confirmed Checks | the mock room is kept beside the campaign's save and resumed only with it (P5-14). Test and harness code that shares an unbound state is unchanged | O05-06 commit |
| `ZoneController.minors`, `MinorRooms` (Godot, new) | §5.4a (the decision persists; the machine is rebuilt from it) | a hosted minor is FOUND in its room; its bolt is restored from `latches_accepted()` before anyone sees it and reported as `minor_<room>/bolt` when pulled; its lines go to the HUD | O05-06 commit |

## Reconciliation (O05-00.2): the immediately relevant rows only

| Row | Evidence at `330c555` | Class |
|---|---|---|
| Ordinary hand carry (Design 2 §10.3–10.4 → Design 1 §10.2–10.3) | `ManipulableBody` has no pickup. The player's interact ray exists (`player._update_interact_target`, 3 m, `interact()`/`interact_prompt()`) | **missing** |
| `TransportedObject` declaration | `schemas/zone.py`: `carriable`, `mass_kg`, `movement`, `allowed_volume`, `home_room_id`, `required`, plus the carry-line refusal | present |
| `TransportedObjects` runtime | `transported_objects.gd` builds one body per declaration, tracks its room through connectors, reports `object_transported` and recovers an object that leaves its volume. **But** the body is a fixed 18 kg crate that cannot be picked up (the declared mass is ignored), recovery is immediate rather than §10.4's 1.0 s, and a consumed object would respawn loose | partial |
| `ObjectConsumer` | Schema, plus the `record_object_consumed` transition (the object must be in the consumer's room; sets the D-8 variable). **No protocol intent, no Godot consumer, no consumed state** | bridge partial / runtime missing |
| Object persistence | `ZoneProgress.object_rooms` holds the room only. Amalgam §5.6 step 10 restores required physical configurations "at saved transforms", and §30.6.1 names `CONSUMED` | partial |
| Recovery transition | `recover_transported_object` exists, with no intent to reach it | partial |
| D-8 macro setters/readers | `zone_state.gd`, `record_zone_state`, the `zone_state_selected` intent | present (to be exercised at O05-04) |
| Acquisition consumers | reconciled at O05-05.1 | — |

## Rows

### O05-01 — ordinary hand carry, operated (P12 prerequisite / P16) — closed

- **Built.** `godot/scripts/gameplay/hand_carry.gd` implements Design 2
  §10.3–10.4. `ManipulableBody` gains `carriable`, `carried_by`,
  `installed_in`, `interact` and `interact_prompt`. `Player` routes
  `interact` to the carry, applies the 0.85 factor for `MEDIUM`, blocks
  the Static Pulse and the `mobility` slot, and drops the object on
  death. The HUD shows carry feedback.
- **Slot mapping (Prod's reading, recorded).** Design 1 blocks the
  "Weapon primary" and "Mobility" and permits "Abilities". In this game
  the Static Pulse is the Weapon primary and the `mobility` slot is
  Mobility. `echo_a`, `echo_b`, `utility` and `consumable` are the
  Abilities. Melee, the Weapon secondary, weapon cycling and hacking do
  not exist here.
- **Evidence (actual input, world effect).** `make godot-carry` gives
  32 checks and 1 note. A real `Player` in a real physics room is driven
  with `Input.action_press` on `interact`, `move_forward`, `fire_pulse`
  and the mobility slot. The driver checks:
  - the pose, 1.20 m out, following yaw and pitch;
  - the blocked slots;
  - a walk into a wall: the object touches it and is never inside it,
    is held short, then dropped at the feet once flush;
  - a drop at rest, then pickup again;
  - the refusals with their exact text: not carriable at 18 kg, 60.00 kg
    accepted, 60.01 kg refused, a `LIGHTENED` 70 kg object refused
    because kilograms are unchanged;
  - walking speed 1.0 for `LIGHT`, 0.85 for `MEDIUM` and 1.0 for
    `LIGHTENED` `MEDIUM`;
  - the Archive's modal hold;
  - death while carrying.
- **Sabotage.** With the kilogram limit removed, 4 checks fail. With
  the sweep removed, 2 fail. The `LIGHTENED` case first passed
  vacuously: a previous press dropped the object it was about to test.
  It now releases first and asserts the exact refusal.
- **Regression on the same tree:** physics 68, mass-class 59,
  unweighted 61, passing-platforms 63, hud, boot, verbs and
  room-contract all OK.
- **Scope limit.** This is a purpose-built physics room, not a composed
  Zone. `LIGHTENED` is applied directly with `apply_status` here; the
  real source is exercised in O05-02.5. There is no consumer yet; that
  is O05-02.

### O05-02 — a required object carried across rooms and installed (P16) — verified

- **Built from the delivered declaration.**
  - `transport_route.compose_transport` derives the object from a
    composed Zone: a 40 kg `power_cell` that is `required`, `carriable`
    and hand carried.
  - The allowed volume is a run of the spine, home first. The composer
    only uses walkable room types (P5-2) that sit on one floor (P5-8).
  - It adds an `ObjectConsumer` in the run's last room, a permanent D-8
    variable, lamps, and `requires_state` on the next spine edge.
  - It refuses the placement unless `reachability` shows the run is
    reachable with the gate shut, and the exit is not.
  - The engine spawns the object once, at home. A consumed object is
    never spawned loose.
- **Real connections and consumer.**
  - The real `Player` is driven with `Input.action_press`. It picks the
    cell up with the interact ray and carries it across the connector.
    The cell is never recovered while between rooms.
  - It installs the cell with `interact` at the `ObjectSocket`. Being in
    the same room does nothing; a different carriable object is refused
    ("WRONG PART").
  - The declared doorway (`StateGates`, P5-4) opens and the player walks
    through.
  - On the played Zone the run is c004 → c005, gated at `e:c005:c006`.
- **Authority and uniqueness** (bridge-tested; `test_transport_route.py`,
  51 tests):
  - Python holds the room, the pose and the consumption.
  - A forged transfer, pose, value or install is refused by name. The
    live suite repeats these refusals against the real bridge.
  - An installed object cannot move, settle or recover.
  - A second consumer is refused.
- **Status continuity, separately.** Unweighted Switch's real `SHOT`
  applicator makes the cell LIGHTENED (factor 1.00, down from 0.85). The
  same body is carried over the threshold, and the Status expires on its
  own 8.0 s clock. The kilograms stay 40 throughout, and nothing about
  the Status is sent for saving.
- **Evidence.** `make godot-transport` gave **106/106** on the tree
  committed as `5902920`: 10 cases, 6 notes. Every note is the declared
  P5-7 Bulwark harness removal.

### O05-03 — restore and recover the journey — verified (live restart re-run pending)

- **Persisted facts.** `ZoneProgress.object_poses` records a settled
  room, position and yaw, never a node path. `consumed_objects` records
  the installation. Both are `ZONE_PERSISTENT`. `Main._to_zone` hands
  both to the Zone before it is built (P5-3).
- **Two restart points (live).** `make godot-transport-live` runs four
  processes of each side against one disposable save:
  - `seed`, `place` (put down in c005), then restart;
  - `install` (the same body picked up and installed; forgeries
    refused), then restart;
  - `restore` (seated at load, doorway open, nothing announced).

  On `d92d723`, seed and place passed (6 and 16 checks). Install failed
  in the driver itself: its cached copy of the served Zone was empty
  after the restart. The fix is committed with this row and the re-run
  result goes here: **(pending)**.
- **Recovery without solving.** Covered by `godot-transport`:
  - out of the volume: home after 1.0 s, and not before 0.5 s;
  - destroyed: the same identity is back after 2.0 s;
  - out of bounds: home at once;
  - death: dropped where it was held, still owned;
  - interrupted beside the socket: restored loose, not installed.
- **Reset domains.** The object's facts are its own. Installing changes
  only its variable (bridge test). The reversible lever, the P14 latch
  and keys survive side by side in the combined candidate Zone (see
  O05-13).

### O05-04 — a reversible lever changes another room's doorway — verified

- **Bound to D-8.** `compose_zone_state(mechanism="lamp",
  reader_order="nearest")` produces the following on the played Zone:
  - the control in c002;
  - `requires_state` on `e:c002:c003`;
  - a lamp in c003, the first room past the gate (O05-04.2).

  `span_bolt` would have been refused by the engine (P5-6).
- **Source feedback and a useful consequence.** Pulling the lever makes
  it read PENDING. The bridge's snapshot makes it read ACCEPTED, or a
  refusal whose `about` names that exact selection makes it read
  REFUSED and reverts it. The consequence is the doorway itself, not
  only text: it opens, and closes on reversal.
- **Reversal, occupancy, escape** (`godot-reversible`, **32/32** on
  `5902920` and again on `d92d723`):
  - both configurations are played;
  - reversal is played;
  - the closing state with the player in the doorway is held as
    "CLOSING QUEUED · DOORWAY OCCUPIED", with three interlock refusals;
  - the close applies by itself once the doorway is clear;
  - the base-kit way back is kept.
- **Restart with the chosen configuration** (`godot-reversible-live`,
  OK on `d92d723`):
  - seed: 3 checks;
  - select: 9 checks. The status is recorded frame by frame, PENDING
    then ACCEPTED. The value is on disk. A forged selection is refused
    by its own key;
  - restore: 3 checks. The doorway is open at load and walked through
    without touching the lever.

### O05-05 — the featured Echo at Blindside (M2) — reconciled; the integrated loop is BLOCKED, M2 partial

**O05-05.1, what runs today** (read at `5902920` by one read-only helper;
the claims marked ✓ were re-checked by hand):

| seam | state |
|---|---|
| claim → pending → AP send → confirm | runs. `reward.gd` `claim_check` → `transactions.claim_check` → `T.claim_zone_check`, then `backend.check_locations` (real `ap_client` or `mock_ap`) → `T.confirm_check` |
| a foreign item → a local Echo | runs, **for a foreign item only** ✓ (`transactions.py` ~118-133: a self-recipient item is "Delivered to you" and mints nothing). Interpretation is validate → one repair → deterministic fallback; `append_interpretation` is idempotent per `echo_id`; `derive()` folds |
| equip through the menu | runs. `InventoryLayer` → `slot_action` → `T.slot_action` → snapshot → `EchoRuntime.set_equipped`. No auto-equip |
| the grapple itself | runs (`echo_runtime._grapple`, `player.camera_ray`, cooldown, a miss refunded) |
| D-1/D-2 featured acquisition | declared and tested at the bridge: `Zone.featured_acquisition`, `established_in_zone`, case C, the circularity refusal (`topology._explore_acquiring`). **No composer emits it** |
| `Zone.rail_networks` | built by `RailNetworks` in composed Zones (track, carrier, junction, span, a GROUND-level control). **No composer emits it**; no direction receivers are built outside `railway_scenario.gd`; `topology.reachability` has no rail model |
| rail span persistence | **was broken — fixed here, P5-9** |
| the gantry, the grapple ring, the pedestal grant, the S3 hole | exist only in `railway_scenario.gd` (the M2-mech development scenario, labelled a shortcut) |

**The exact blockers** — each a policy the packet does not choose and
this lane may not invent (`06_SOURCES_AND_LIMITS.md`: "does not
authorize weakening the guarantee to finish M2"):

- **B-1, allocation edge case: the featured Check can hold the player's
  own item.** Only a foreign item mints an Echo ✓. A featured Check
  holding a Signal Key or coin would hand over nothing. Choosing the
  featured Check by its scouted recipient is the move
  `SOLUTIONS_CATALOGUE.md` §1 option 3 rejects ("leaks hidden scouting
  information into level structure"). Which Check is featured, and what
  a self item does there, is Dess's/the owner's call.
- **B-2, qualification: nothing makes the Echo supply the function.**
  `EchoGenerationRequest` has no required-capability field ✓
  (`epsilon/requests.py`), nothing refuses a non-qualifying
  interpretation for a featured Check, and the fallback yields a grapple
  only when the item's NAME suggests one. `qualifies_for_gap` and
  `capability_guarantee` have no production caller. "Use only the
  selected fallback/repair rules" (O05-05.6): no rule is selected for a
  provider that does not qualify.
- **B-3, pre-seed AP representation.** The APWorld declares Signal-Key
  tier rules only ✓ (`apworld/archipepsi/__init__.py`).
  `docs/AP_CAPABILITY_LOGIC.md` is a proposal ("Nothing here is
  implemented"; the shape "is an owner decision"). Production never
  passes `declared_capabilities`, so Option C governs: a capability
  gate may sit only where no AP location is behind it.
- **Latent risk, recorded rather than acted on:** `_explore_acquiring`
  lets Checks or the exit sit behind the FEATURED gate (case C). With
  B-1 and B-2 open, a composer that emitted `featured_acquisition` today
  could produce an unwinnable seed. None does. It must not until B-1..B-3
  are settled.

**What that leaves (O05-05.2-.7).** The required progression gate stays
unavailable, and M2 is **partial**: the physical loop is proved only in
the development scenario (M2-mech, pedestal grant, labelled as such);
the claim, delivery, interpretation, equip and grapple halves each run
through real campaign machinery, separately. No walking bypass, no
faked foreign item, no candidate `blindside` step (the profile still
refuses the name). Composing the three-dock structure without the gate
it exists for would be a railway demo, not Blindside.

**Engine work that does not wait on the policy, when M2 resumes** (none
started, so nothing is half-built): direction receivers for composed
railways; a rail path that follows the committed doorways rather than a
curve through room arrivals; a declared control height/capability and
the overhead gantry; the S3 destination; a rail model in
`topology.reachability`.

### O05-06 — the existing minors in game context — EX50-033 integrated and played; EX50-011 and EX50-021 not yet

- **O05-06.1, the occurrence contract.** `schemas/minors.py` states what
  the registry cannot: the host chamber type, the one way in, the sealed
  openings, the latches the room records, and completion and recovery in
  words. Space and doorways stay the registry entry's own
  (`minor_rooms.json`). A minor is never offered to a provider
  (`shells.is_offerable`); only the candidate `minors` step places one.
- **Extraction, not duplication (O05-06.1).** `UnweightedSwitchRoom` is
  the scenario's room, moved out whole. Two owners, one implementation:
  - `--unweighted` (development, still labelled so): 61 checks OK;
  - `UnweightedSwitchHosted`, the registry shell: a doorway in A's wall,
    G walled in with the way on cut at the sill, and the scenario's
    stand-in goal plate removed, because the goal is the Zone's Check.
  - `godot-room-contract`: the minor shell PASSES, and both doorways are
    crossed by a real body (3.10 and 3.11 m past, 0.08 m of dip).
- **O05-06.4, selection.** The `minors` step (`minor_hosting.py`) runs
  last in the candidate profile. It ADDS the minor as a new room behind a
  dead-end arena, off the parent's side doorway, and moves that arena's
  one Check onto the minor's gallery (P5-13).
  - A parent is: an arena; not the first room; holding no key and no
    other relationship's control; with exactly one Check; entered by an
    ungated doorway; with a free side socket.
  - Otherwise the step declines by name, listing each room's reason.
  - The Zone is schema-validated, reachability-proved and re-certified
    (`validate_zone` with the minor's own shell rule added to the offer,
    and the Zone's real budget, P5-12). `strip` hands the Check back so
    re-hosting still works.
  - Frozen sample: emitted in 12 of 12, every case certified, every
    allocated Check kept.
- **O05-06.4, persistence.** The bolt is `minor_<room>/bolt`, a reserved
  namespace, accepted only for a room the ACCEPTED Zone builds from a
  contracted shell (`test_minor_hosting.py`, 23 tests). `ZoneController`
  finds the hosted room, restores the bolt from the latch record before
  anyone sees it, reports it when it is pulled, and sends the room's own
  lines to the HUD.
- **O05-06.5, reward and return.** The Check stands at the shell's
  objective on the gallery and is claimed once through the ordinary
  claim path. The way back is the room's own: the return gap, then the
  return stair the bolt adds. The parent keeps its return plug.
- **Played (`make godot-candidate-live`, now five phases, all OK):**
  seed 39, play 20, restore 5, minor 16 and minor_restore 10 checks.
  - **seed:** the served Zone matches `candidate_zone.json` field for
    field, minor room `c024` included. All four steps are recorded
    EMITTED and certified.
  - **minor:** the controller finds the minor in its own room. It is
    built from its shell and stands as built: bolt free, crate parked, no
    stair, no stand-in goal. Its Check stands on the gallery, 1.90 m up.
    HARNESS STEP, declared: the player is placed at c015's arrival
    (reaching it crosses P14's plate and two locked doors, which their
    own suites play). From there the player, by hand:
    - clears c015 with the base kit;
    - walks through the doorway the profile added (14.9 m);
    - pulls the drive: the crate lands on the HEAVY plate and the crossing
      SHUTS;
    - shoots the applicator with the Static Pulse: LIGHTENED is on the
      crate, and the crossing OPENS with the crate still on the plate;
    - stands on the crate top (0.99 m) and goes through onto the gallery;
    - pulls the bolt: ACCEPTED, `minor_c024/bolt` is in the save;
    - claims Check 89100055: CONFIRMED, with exactly one claim intent.
  - **minor_restore:** both processes are new, and nothing is done before
    these checks:
    - the bolt holds, the crossing is open, and the 8-step return stair
      stands;
    - the crate is parked and LIGHTENED is gone (package-local and
      ephemeral);
    - the Check stays claimed (this needed P5-14).
    Then the crate is driven back onto the HEAVY plate by hand and the
    crossing STAYS OPEN, because the restored bolt holds it. No latch and
    no claim is sent back.
- **Not yet:** EX50-011 Passing Platforms and EX50-021 Counterfire
  Arcade. The contract, composer, latch path and engine hook are shared;
  each still needs its room extracted and hosted. For EX50-021 the
  gunner must be the Zone's declared enemy, not a room-owned copy
  (EX50-021 §9: "Enemy position and health follow the source encounter
  persistence rather than a new puzzle-owned copy").

### O05-13 — the candidate composer profile — built; the whole profile played live

- **Candidate configuration, not fixture laundering (O05-13.1).**
  - The `--candidate[=STEPS]` bridge flag is off by default. It is
    applied inside the real generation path, after the graph is proved
    and before `accept_zone`.
  - Each step derives its relationship from the Zone the campaign really
    composed, or declines by name.
  - Order: `zone_state, transport, latched_route` (P5-11). Nothing is
    loaded from a file and nothing edits a save.
- **Re-certified, not trusted (O05-13.3).**
  - The profile's Zone is re-run through `validate_zone` with the
    provider's own offer and allocation, and through the whole Zone
    schema.
  - A result that introduces an error is discarded whole, and the record
    says `certified: false` and names the rule.
  - The test drops an allocated Check and asserts the provider's Zone
    survives. With re-certification disabled, that test fails.
- **Every outcome recorded.** `<save dir>/candidate/<zone>.json` holds:
  - the profile and the provider;
  - every step, emitted or declined, with its reason;
  - the proposal digest and the certification.
- **The whole profile, played (`make godot-candidate-live`, new):**
  - **seed:** 38 checks. The served Zone is `candidate_zone.json` field
    for field. It has three relationships on three doorways
    (`e:c002:c003`, `e:c005:c006`, `e:c009:c010`), and all three steps
    are recorded EMITTED.
  - **play:** 20 checks, 1 note (the P5-7 harness). All three are built
    and nothing is refused. The lever is pulled and ACCEPTED, and its
    doorway opens. The cell is carried from c004 into c005, installed
    and ACCEPTED. The player walks into c006. P14's branch stays shut.
  - **restore:** 5 checks. Both processes are new. The lever's doorway
    is open at load, the cell is seated (one copy) with its doorway
    open, P14's shutter is still shut, and nothing is announced.
  - The first run of this suite found P5-11.
- **Bounded sample (O05-13.3).** `bridge/tools/candidate_sample.py`
  freezes its inputs before running: count 12, `C.DEFAULT_CONFIG` mock
  multiworld, fallback provider, whole profile, revision. It records
  every case in `docs/ledgers/ov05_evidence/candidate_sample.json`.
  - `zone_state` emitted in 12 of 12 cases.
  - `latched_route` emitted in 12 of 12.
  - `transport` emitted in 11 of 12. zone_002 declined by name: its
    platform path and transit hall leave no walkable, one-floor run
    inside the home window.
  - **Every case was certified and kept all its allocated Checks.**
  - The layout verdict is not in this sample: it is the bridge half
    only.
- **Scope limit.** The deterministic fallback provider composed
  everything; no live model was used. The composers are a small
  canonical set (O05-13.2), not an expressive ceiling.

### O05-15 — a launchable candidate — built

- **One launcher family (O05-15.1).**
  - `Diagnostic Campaign - Candidate (Windows).bat`, or
    `python -m archipepsi_bridge.diagnostic --candidate`.
  - It uses its own slot (`candidate`) and resumes by default; `--new`
    starts a fresh one.
  - A marker records the slot's mode and profile, and the launcher
    refuses to continue it any other way.
  - The banner prints the revision, the profile, mock AP, fallback
    Epsilon, the default scale and "staged: nothing".
  - The direct scenario launchers are unchanged, for comparison.
- **Normal lifecycle (O05-15.2).** The real Main, client and bridge, and
  the shipped input paths. Nothing is seeded. The diagnostic drivers
  stay separate modes.
- **Owner review (O05-15.4).** `PROD_OV05_ROUTE.md` (spoiler-light) and
  `PROD_OV05_ANSWERS.md` (answers, with the evidence class of each
  claim). `make candidate-shots` renders the review frames under xvfb.
  It is diagnostic and asserts nothing.
- **Not claimed.** Windows execution. The `.bat` is read, and the Python
  module it delegates to is tested (`test_diagnostic_launcher.py`,
  45 tests).

## Findings (`P5-n`)

- **P5-1 — two composers gate one doorway.** On the played Zone, D-10's
  `compose_latched_route` puts P14's shutter on `e:c002:c003` through
  `opened_by`. Dess's `compose_zone_state` then puts `requires_state` on
  that same edge. The logic is sound, because both conditions must hold.
  The world is not: a doorway takes one shutter. `StateGates` therefore
  refuses a state gate on an edge that also carries `opened_by`, by name,
  and leaves that doorway to the latch shutter. The logic stays stricter
  than the world, which never traps anyone. Resolution belongs to the
  composer's owner and is **open for Dess**. The candidate profile
  (O05-13) has to choose an order, or skip that edge.
- **P5-2 — a required carry was routed through a platform path.** The
  first `compose_transport` run chose c002→c003→c004 on the played Zone.
  c003 is a `platform_path`: islands over a kill pit. A cell fumbled
  there can come to rest where nobody reaches it, and §10.4's "at rest
  5 s, unreachable" recovery is not implemented. The played acceptance
  found it. The composer now carries only through corridors, arenas and
  treasure rooms, and the run became c004→c005→c006.
- **P5-3 — D-8 values and P16 rooms were never restored in the real
  client.** `Main._to_zone` passed keys, locks, stations and latches from
  the snapshot. It never passed `macro_state` or `object_rooms`, so a
  D-8 selection or a carried object's room survived only in synthetic
  suites that set the controller fields by hand. `_to_zone` now passes
  all four object and state fields from the snapshot alone: the rooms,
  the poses, the consumption, and the D-8 values.
- **P5-4 — `requires_state` edges were never physically enforced.**
  `topology.reachability` honoured them, and nothing in Godot read them.
  The route was shut in logic and open in the world. New
  `StateGates` puts a declared shutter in the edge's own doorway, bound
  to the variable by id. It sits in the `ROUTE_GATE` group, so the
  aperture evidence still reads the doorway as an opening.
- **P5-5 — the transported-object runtime predated carry.** It built a
  fixed 18 kg crate whatever the declaration said. It recovered on the
  first frame instead of after §10.4's 1.0 s, and it reported a recovery
  as an ordinary transfer home. It had no consumed state, so an
  installed object would have respawned loose. All four are fixed. The
  D-8 driver's recovery case now asserts the delay, including that the
  object is not recovered before 1.0 s. Its "between rooms" proxy was a
  point 400 m above the Zone, which is out of bounds by §10.4. It is now
  a real point beside a room, with the out-of-bounds case asserted
  separately.
- **P5-6 — the D-8 composer's reader mechanism is not one the engine
  builds.** `compose_zone_state` defaults to `mechanism="span_bolt"`.
  `ZoneStateBuild` implements `barrier` and `lamp` and refuses anything
  else by name, which also drops that variable's setter. For O05-04.
- **P5-7 — a scripted two-Bulwark fight is not stable evidence.** c005
  holds two Bulwarks in a pit arena. Four orbit policies were tried: plain
  strafing, a 4–6 m band, 2.8–3.8 m, and 3.6–4.6 m. Each cleared the room
  on some starts and lost the player on others. Two reasons, both
  measured. Their slam lands within reach × 1.4 = 3.36 m. And at 90°/s
  a Bulwark out-turns any orbit wide enough to stay clear of the slam.
  The designed opening is the 0.9 s recovery after a swing, and baiting
  that reliably is AI play, not transport evidence. The transport and
  reversible suites therefore remove Bulwarks through the real damage
  path, from behind, as a **declared and counted harness step**, and
  fight the artillery arena with the base kit as P14's suite does.
  Bulwark counterplay stays `godot-encounter`'s played acceptance.

- **P5-8 — the delivery opened a door 27 m overhead, and a check passed
  anyway.** After P5-2 the run was c004→c005→c006, with the socket in
  c006. c006 is `shell_hall_transit`: entered at the floor, left 28 m up
  by a launch arc. The carried cell never reached c007, because the door
  the delivery opened was overhead. The journey's "pressed at the shut
  doorway, the player stays on this side" check passed regardless: it
  measured which side of the door plane the player was on, and the
  player was 27 m below the door. Two fixes. First, the composer now reads
  each shell's doorway heights from the registry, the same data the
  engine builds from. Every room of the journey has to be one floor
  (within 0.5 m) across its way in, its carry doorways and the door the
  delivery opens. An unmeasured shell is declined, not guessed flat. The
  played Zone's run is now c004→c005, gated at `e:c005:c006`. The longer
  runs are refused by name ("'exit' at 28 m ... a hand carry is a walk").
  Second, the driver asserts that the player stands at the doorway, on
  its floor, before it reads the side.
- **P5-9 — a composed railway's commissioned span could not be saved.**
  `RailSpan.latch_id` is documented as the handle a commissioned span
  persists under, and the engine reports it (`RailJunction.latch_fired`
  → `report_latch(network_id, latch_id)`). But `record_latch` accepted
  only P14's `graph_` latches and the committed manifest's physics
  packages, and a railway is neither, so the bridge refused every
  composed span a player commissioned and it was gone at the next load.
  `godot-rail-zone` fills `latches_carried` directly, so it never saw
  this. Fixed with a third, separately evidenced path. The ACCEPTED Zone
  must declare the network; the layout must be committed; the committed
  layout must have placed every dock room; and only a span with a
  control can latch, since one without ships commissioned. A name that
  is both a physics package and a network is refused as ambiguous.
  Covered by `bridge/tests/test_rail_latch_record.py`, 9 tests. Before
  the fix, 7 of 8 failed with "accepted no physics package 'yard'".
- **P5-10 — the lever status assigned a freed control.** O05-04's
  `_setter_status` read each setter into a typed variable. The
  zone-state suite frees a control on purpose, and the typed read then
  raised "Trying to assign invalid previously freed instance". The
  suite's own 60 checks passed, but `make godot-zone-state` fails on
  any script error, and the regression batch caught it. The controller
  now skips an invalid instance before the typed read.
- **P5-11 — two relationships' controls in one room, and one of them
  lost.** In the first played combination of the whole candidate profile
  (`godot-candidate-live`), `zone_state` put the reversible lever in c002
  and `latched_route` put P14's plate in c002 as well. The engine refused
  P14's graph by name: "no clear floor for sensor 'step_plate' on this
  side of the doorway it opens". So the branch's shutter was never built,
  and the doorway was logically gated and physically open. This is the
  combination the candidate launcher actually plays; each step's own
  suite had passed alone. Fixed in the composers, where rooms are chosen:
  - one relationship's control per room;
  - P14's plate only in open rooms (arena, treasure room) on the floor of
    the doorway it opens;
  - the profile order is now zone_state, transport, latched_route, so
    that P14, the step with the widest choice of rooms, goes last.

  On the played Zone the plate is now in c009 and the shutter is across
  `e:c009:c010`. P14 composed alone is unchanged (c002).
- **P5-12 — the profile's re-certification judged a 1000-point Zone
  against a 200-point budget.** O05-13.3's `certify` called
  `validate_zone` without `zone_budget`, so the prototype's 200 points
  applied: every default-scale Zone read as "31 enemies, limit is 14".
  The "refuse only what the profile introduced" comparison hid it,
  because the error was already present on the graphed Zone. It surfaced
  when the first version of the minor step removed two enemies: the count
  in the message changed, the string no longer matched, and all 12 sample
  cases were discarded. `epsilon/base.py` names this exact mistake. The
  call now passes `request.campaign.zone_budget`, and
  `test_certification_is_held_to_the_budget_the_provider_was` pins the
  call site: with the argument removed, it fails.
- **P5-13 — substituting a minor for a room empties the Zone below its
  content floor.** The first minor step turned a dead-end arena INTO
  EX50-033. With the budget restored (P5-12), all 12 sample Zones then
  refused it. The fallback composes to within a few points of the floor
  (the played Zone holds 903 against a 900 minimum), and
  `content_value.room_value` has no row for a minor. So the replaced
  arena's enemies and activity left the count, and even the cheapest host
  (38 points) took the Zone out of its band. Valuing a minor is a row in
  Dess's table (CAMPAIGN_SCALE.md 5) and is not invented here. The step
  now ADDS the minor as a new room behind a dead-end arena and moves that
  arena's Check onto the minor's gallery. "An AP Check is not content",
  so nothing counted is removed; the parent keeps its fight and its
  objective. Emitted in 12 of 12 sample Zones, all certified. **Question
  for Dess:** should a hosted minor carry a content value of its own? It
  currently counts only through the table's existing objective and space
  rows (4 points on the played Zone).
- **P5-14 — a restarted mock campaign forgot every confirmed Check.**
  `MockServerState` says it is "truth that survives quit/reload/
  reconnect". It survived reconnects only, because it lived in the
  bridge's memory. The save deliberately keeps no copy of Archipelago's
  truth. So in a mock campaign (which is what the diagnostic and
  candidate launchers play), quitting and relaunching turned every
  confirmed Check back into unchecked: its pedestal became claimable, and
  claiming it delivered its item a second time. `godot-candidate-live`'s
  `minor_restore` phase found this by asserting the minor's Check was
  still claimed after a restart. The room is now kept beside the
  campaign's own save (`<save stem>.mock_room`, not `.json`, so
  the save stays the only `.json` in its folder) and resumed only when that
  save exists, so a new campaign never inherits an old room. An unbound
  `MockServerState`, which tests share in one process, behaves exactly as
  before. Covered by `test_mock_room_persistence.py`, 5 tests; with
  `store()` disabled, 4 of them fail.
- **P5-15 — a hosted room's shutter stood near the world origin.**
  `ServiceShutter` placed its panel and its doorway interlock at
  `global_position = shut_at`. That was right for every owner standing at
  the world origin (the Zone's state gates and P14's graphs) and wrong
  for a room that carries its own shutter and is placed elsewhere.
  Hosted in the Zone, EX50-033's panel stood near the origin while its
  state read shut. The first `minor` run passed anyway, because it read
  `is_shut()`, which is the panel's offset and not where the panel is.
  The shutter now works in its parent's frame; for owners at the origin
  that is the same frame. The minor phase now checks the panel is IN the
  crossing when shut, has the player stand on the crate and fail to walk
  through, and after the restart checks the panel is physically raised.
