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
| `schemas/minors.py` `MinorContract.enemies`; the `minor_counterfire_arcade` contract | EX50-021 §9 (the gunner follows "the source encounter persistence") | a minor may declare the chamber's own enemies; the composer writes them into the chamber, so the Zone spawns and owns the encounter | `6cbe5f2` |
| `minor_hosting.compose_minor` (every contract, each behind its own dead end) | O05-06.5: "The composer does not need to place all three in every Zone" (so it MAY place more than one) | `HostedMinor.rooms`; a minor is never a parent | `6cbe5f2` |
| `minor_rooms.json` `minor_counterfire_arcade`, `HostedMinor` (Godot, new), `CounterfireArcadeRoom` extraction | as for EX50-033 | a second minor shell; `HostedMinor` is the one interface a Zone uses for any minor (`latched`, `said`, `restore`) | `6cbe5f2` |
| `ZoneController.minors`, `MinorRooms` (Godot, new) | §5.4a (the decision persists; the machine is rebuilt from it) | a hosted minor is FOUND in its room; its bolt is restored from `latches_accepted()` before anyone sees it and reported as `minor_<room>/bolt` when pulled; its lines go to the HUD | O05-06 commit |
| `schemas/protocol.py` `ZoneProgress.carrier_states`, `with_carrier`; `SAVE_FIELD_CATEGORY["carrier_states"] = "PUZZLE_LOCAL"` | EX50-011 §9 ("Carrier poses, destinations and hold states are package-local. A stable save restores each at its saved pose before the player"; a dwell restores held); Amalgam §5.2 (machinery `t` is `PUZZLE_LOCAL`), §5.3 (no save while a `PUZZLE_LOCAL` body moves), §5.6 step 9; `SAVE_FIELD_CATEGORY`'s own note (a path that always exists restores the pose) | one bounded field (max 8): `(minor_<room>/<carrier>, t, destination, held)`, overwritten rather than accumulated, like `macro_state`. Only a carrier AT REST is ever recorded | `400ed37` |
| `protocol.py` intent `CarrierRested` | as above | one client intent, routed to one transition | `400ed37` |
| `transitions.record_carrier_rested` (new); `_accepted_minor_latches` split into `_accepted_minor_contract` | the minor path's four facts (accepted Zone, committed layout, placed room, contracted shell) | records a rest only for a carrier the hosted minor's contract declares, at one of its declared stops (or held with no errand), at a finite offset. The latch path's checks and messages are unchanged | `400ed37` |
| `schemas/minors.py` `MinorContract.carriers`; the `minor_passing_platforms` contract | O05-06.2; EX50-011 §3 (a lift A/TRANSFER/SHELF and a shuttle WEST/EAST), §4 (the stair at G), §9 | the stair is the latch; the carriers and their stops are declared, so the bridge refuses a machine or stop the minor does not have | `400ed37` |
| `campaign.py` `handle_progress`, `server.py` routing | existing progress dispatch | `carrier_rested` | `400ed37` |
| `ShuttleDeck._place` (Godot) | P5-15's rule: a machine places itself in its parent's frame | the lift is placed with `position`, not `global_position`. Every existing parent is at the origin, so nothing else moves | `400ed37` |
| `RailCarrier.frame_from_parent` (Godot, opt-in, default off) | `to_world` "maps the path into world"; a room at a Zone transform knows its frame only once it is in the tree | when set, `_ready` takes `to_world` from the parent. Off everywhere else, so the Zone railway and its tests are unchanged | `400ed37` |
| `HostedMinor.carrier_rested` / `restore_carriers` / `player_died`; `ZoneController` reports and restores them | EX50-011 §9 (restore before the player; before completion, death restores the initial transport configuration) | a minor may report a carrier at rest and is handed its saved rests before anyone sees the room | `400ed37` |
| `minor_hosting.offer_order` (new) | O05-06.5 "The composer does not need to place all three in every Zone"; O05-06.1 "select each minor" | this lane's selection rule: the contract order turns with the Zone's ordinal, so a campaign meets every minor. With a fixed order, EX50-011 was hosted in 0 of 12 sample Zones. `zone_001` is unchanged | `400ed37` |
| `RoomAudit._openings_are_holes` + `_exit_facing` (Godot) | the 2026-09-03 owner ruling for entries ("the entry is where the room says it is") | the exit probe stands on the wall the declared `exit_yaw` faces. Before, a side exit was measured on the far wall (P5-17) | `400ed37` |
| `schemas/signal_graph.py` `SUPPORTED_NODE_KINDS` += `OR`, `SUPPORTED_SENSOR_KINDS` += `PULSE_BUTTON`; `SENSOR_OUTPUT_FORM`, `NODE_INPUT_FORMS`, `ZONE_PLACEABLE_SENSOR_KINDS`, `ROUTE_SENSOR_KINDS`/`ROUTE_NODE_KINDS` (new) | Design 1 §19.1 (ports: "a graph connecting mismatched forms fails validation at composition, never at runtime"), §19.2 (OR: 2–4 Boolean inputs; LATCH: pulse `set`), §20 (PULSE_BUTTON: Pulse); O05-07.2 "add support/export only with the working consumer; nothing silently becomes OR or a no-op" | two kinds join, each with its consumer (EX50-033's chain). Port forms are checked, so a pulse feeding a Boolean reader, or driving a machine by itself, is refused. The P14 LATCH's Boolean set is kept as that slice's accepted rule | `a718654` |
| `signal_graph.settle`, `upstream` | the runtime's evaluation order (§19.3) | generalized from chains to trees: OR is any of its inputs, and `upstream` walks every input. A single chain comes back exactly as before (tested) | `a718654` |
| `schemas/zone.py` room-graph and route validators | D-10 §5 (a route hangs on the guaranteed base kit); P14's `phases` reasons about one plate through NOT/LATCH | a Zone may declare only sensors its builder PLACES (plates). A route gate hangs only on a PRESSURE_PLATE through NOT/LATCH; anything else is refused by name. The same OR as a machine in a room is legal. The composed P14 routes are unchanged | `a718654` |
| `schemas/minors.py` `MinorContract.graph`; EX50-033's declared chain | EX50-033 §3 (the HEAVY plate under a NOT; the bolt holds the crossing); `SignalGraph`'s own header ("the scenario keeps its own wiring ... rewriting it to go through here would change a working room to prove a point about a different one") | the minor's chain is declared in its contract and validated by the Zone graph schema. Its LATCH ids are exactly the contract's latches, so a fired latch is still `minor_<room>/bolt` and existing saves read the same. Exported to Godot as `Constants.MINOR_SIGNAL_GRAPHS` | `a718654` |
| `SignalGraph` (Godot): pulse sensors, `OR`, `restore_latch` | §19.3 ("pulses live for exactly one tick") | a `CallLever` source is a PULSE_BUTTON, raised for one evaluation and cleared. An unbound source reads OFF. `restore_latch` puts a latch back by id, silently, for a room that owns its graph | `a718654` |
| `RoomGraphs` (Godot) | as the Zone validator | refuses a sensor it cannot place, instead of placing a plate for it | `a718654` |
| `UnweightedSwitchRoom` (Godot) | O05-07.3 "route an existing minor ... relationship through the shared implementation while preserving its specialized semantics and standalone comparison" | the room binds its own plate, bolt lever and shutter to the declared ids, and the shared runtime drives the shutter. What the room keeps is its lines and the return stair. The §11 control is the plate sensor left unbound | `a718654` |
| `schemas/signal_graph.py`: `SUPPORTED_NODE_KINDS` += `TIMER`, `SUPPORTED_SENSOR_KINDS` += `SHOOTABLE_TARGET`; `DamageTag`, `SUPPORTED_TARGET_TAGS`, `TIMER_MAX_SECONDS` (new); `SensorNode.mode`/`required_tags`, `LogicNode.duration` (new, optional) | Design 1 §19.2 (TIMER: 1 Pulse, ON for `duration`, a new pulse restarts it), §19.6 (TIMER is EPHEMERAL), §20/§20.2 (SHOOTABLE_TARGET: `mode: PULSE \| TOGGLE`, `required_tags` default `[RANGED]`); EX50-021 §3 | two kinds join with EX50-021's chain. TOGGLE is refused: nothing reads it. `required_tags` accepts exactly `[RANGED]`, because the runtime has no damage tags and its SHOT path counts any hit (see the O05-07 slice 2 notes). `TIMER_MAX_SECONDS` is `ActivityPrimitive.time_limit`'s 120 s ceiling, a bound this lane chose | `384497b` |
| `schemas/minors.py`: the `minor_counterfire_arcade` contract's `graph` | EX50-021 §3 ("the receiver emits one pulse per valid hit"; "the eight-second TIMER refreshes on another valid receiver hit. Its output opens the service shutter"), §9 ("the receiver timer is ephemeral") | the chain is declared, and its LATCH id is the contract's `release`, so a pulled release is still `minor_<room>/release` | `384497b` |
| `SignalGraph` (Godot): `ImpactReceiver` pulses, `TIMER` + `advance`/`timer_left`, `bind_declared`/`source_is` (moved up from `UnweightedSwitchRoom`) | §19.3; §19.2 | a receiver's valid hit is a one-tick pulse, and TIMERs run down on the physics tick; a TIMER running out re-evaluates the graph. A room binds its machines by declared id; a machine of the wrong kind is left unbound and reported | `384497b` |
| `ServiceShutter` (Godot): `trip`, `open_seconds`, `left` removed; `create(...)` loses its `seconds` parameter (5 call sites, one of them a test's) | EX50-021 §3 names the TIMER as the window's owner | the shutter is commanded like every actuator. A second clock would be a second answer to how long the way stays open | `384497b` |
| `CounterfireArcadeRoom` (Godot) | O05-07.3 | the room binds its receiver, release lever and shutter to the declared ids; the shared runtime drives the shutter. The room keeps its lines and the release stair | `384497b` |
| `godot/tests/fixtures/latched_route_zone.json` (Dess's P14 fixture) and `candidate_zone.json`, regenerated with their make targets | "Regenerated from source, never edited" | the only change is three `null` keys per graph (`mode`, `required_tags`, `duration`): the new optional fields, dumped the way `requires_class` already is. `proposal_digest` is derived and never stored, so no save is affected | `384497b` |
| `candidate.OPTIONS` (new), `parse` / `steps_of` / `options_of`; `CampaignEngine.candidate_options` (new) | O05-11.4 "enable the complete function for the explicit overnight candidate profile"; O05-13's "off by default" | an option is switched on by the same spec, and `all` includes it; the engine keeps options apart from Zone steps, so every Zone-profile test is unchanged | O05-11 commit |
| `epsilon/capabilities.CANDIDATE_ACTION_SLOTS` (new); `validate_stage_support(..., slots=)` | the file's own promotion condition (authorize, then launch; count accepted expenditure), met by `player.gd` and the D-9 suites | the gate admits exactly the slots the request advertised. `IMPLEMENTED_ACTION_SLOTS` is untouched and still withholds `consumable` | O05-11 commit |
| `epsilon/requests.allowed_for` (new; the request's default factory); `epsilon/base.generate_echo_validated` | as above | a request advertises the consumable slot only when built with `consumable=True`; the default is byte-for-byte the old dict (tested) | O05-11 commit |
| `epsilon/fallback`: the explosive rule's consumable reading (`_consumable`, new) | O05-11.3 "a deterministic supported candidate provider must be able to produce and deliver a consumable ... include real damage and a currently supported Status" | only when the request offers the slot: three of the weapon reading's own lob, plus `stunned` 1.5 s. Otherwise unchanged, and no other item reads differently (tested) | O05-11 commit |
| `__main__._candidate_line`, `--candidate` help; `diagnostic.candidate_steps` message | O05-15.1 "print ... profile ... and any staged functions" | the option is printed with the steps | O05-11 commit |
| `EchoProjectile.statuses` + `_apply_statuses` (new); `EchoRuntime._launch` | the schema's pairing of `apply_status_on_hit` with any damage primitive (P5-19) | a projectile carries its status modifiers to what it damages | O05-11 commit |

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

### O05-03 — restore and recover the journey — verified, the live restart included

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
  after the restart. The fix is committed with this row. **Re-run at
  `400ed37`**, in the batch recorded under O05-06: seed 6, place 16,
  install 18, restore 12, all four phases OK.
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

### O05-06 — the existing minors in game context — all three integrated and played

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
  - Frozen sample (regenerated at `6cbe5f2`, both contracts): the step
    emitted in 12 of 12, every case certified, every allocated Check
    kept. EX50-033 was hosted in 12 of 12 and EX50-021 in 10 of 12; in
    zone_004 and zone_012 EX50-021 declined by name, because the one
    remaining dead end had already taken EX50-033 and every other room
    holds a relationship's control, a key or no free side socket.
    The first frozen run declined zone_012: its one
    dead end has a right-hand gallery, which stands in a `side_right`
    doorway. The step now tries each free side socket, and the Zone
    schema judges each one (`test_a_gallery_on_the_preferred_side_...`).
    A decline lists the dead ends' reasons first.
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
- **O05-06.3, EX50-021 Counterfire Arcade: integrated and played.**
  - **Extraction.** `CounterfireArcadeRoom` is the scenario's room,
    moved out whole and placed in its own frame. `--counterfire` owns one
    at the origin (still 44 checks OK). `CounterfireArcadeHosted` is the
    registry shell `minor_counterfire_arcade`, and it differs from the
    scenario in four ways:
    - a doorway in the arrival wall;
    - the annex closed (the scenario stood in a void);
    - a sealed way on at the flank's height, as EX50-033's hosted room
      has one;
    - no stand-in goal plate.
  - **The gunner is the Zone's.** EX50-021 §9 says "Enemy position and
    health follow the source encounter persistence rather than a new
    puzzle-owned copy". So the contract declares one `ranged` enemy for
    the chamber, the shell's `enemy_spawn` volume is the gallery post,
    and the hosted room builds none. The Zone spawns, tracks and
    persists it like any other enemy.
  - **Hosting.** The `minors` step now hosts every contracted minor,
    each behind its own dead end; a parent that took one is no longer a
    dead end, and a minor is never a parent. On the played Zone,
    EX50-021 is `c025` behind `c020` and EX50-033 is `c024` behind
    `c015`. Its latch is `minor_<room>/release`.
  - **Played (`minor` phase):**
    - HARNESS STEP, declared: placed at c020's arrival.
    - c020 itself is walked past, not fought. Its two ranged enemies
      stand on an elevation band the scripted fighter cannot reach.
      Measured: three deaths, not one landing a hit.
    - At the stance, facing the gallery, nothing is pressed: the Zone's
      gunner commits a shot.
    - The player dodges into the alcove. The enemy's own projectile
      carries on down the lane and trips the receiver.
    - Through the shutter with 5.6 s of its interval left, then up the
      supported route onto the flank (2.96 m).
    - The release is pulled and ACCEPTED as `minor_c025/release`.
    - Check 89100025 is CONFIRMED.
    - The shot detector takes only a projectile inside the room heading
      south: the first run picked up one of c020's ranged enemies
      shooting through the doorway.
  - **Restart (`minor_restore` phase):** before anyone acts, the room is
    released, the shutter open with its panel physically raised, and the
    fixed stair standing. The Check stays claimed. 20 s later (two and a
    half intervals, nothing shot) the shutter is still open.
- **O05-06.2, EX50-011 Passing Platforms: integrated, played, and
  restarted from a non-default platform state.**
  - **Extraction.** `PassingPlatformsRoom` is the scenario's room, moved
    out whole and placed in its own frame. `--passing-platforms` owns one
    at the origin (63 checks unchanged, then 70 with the checks below).
    The lift now places itself in its parent's frame (`ShuttleDeck._place`,
    P5-15's rule), and the shuttle takes its frame from the room when it
    enters the tree (`RailCarrier.frame_from_parent`, opt-in, off for the
    Zone's own railways). `PassingPlatformsHosted` is the registry shell
    `minor_passing_platforms`: a doorway in the arrival wall at x = 0, and
    the way on cut behind G at G's height for the Zone to seal. The plate
    on G stays: it is §4's "arriving at G" that releases the stair. The
    Zone's Check stands at the objective on G.
  - **What persists.** The stair is the latch `minor_<room>/stair`. Each
    carrier's rest is `minor_<room>/<carrier>` in the new
    `ZoneProgress.carrier_states` (`PUZZLE_LOCAL`, Amalgam §5.2): pose,
    destination and hold, reported only AT REST (arrived, STOP, or a
    declared dwell), because §5.3 refuses to save a moving machine. The
    bridge accepts a rest only for a carrier and stop the contract
    declares (`record_carrier_rested`, 11 bridge tests). A dwell comes
    back HELD (§9). Before completion, a death sends both carriers home
    by the ordinary commands (§9 with §8's no-teleport rule).
  - **Where it appears (a selection rule, recorded for Dess).** Every
    sample Zone has at most two dead ends a minor can take, and with a
    fixed order EX50-011 was hosted in 0 of 12. `minor_hosting.
    offer_order` turns the order with the Zone's ordinal: `zone_001`
    keeps EX50-033 + EX50-021 (the evidence above is unchanged), and
    `zone_002` offers EX50-021, EX50-011, EX50-033. The other two minors
    already had their own live proofs, so EX50-011 is played in
    `zone_002`.
  - **Reached by the ordinary lifecycle (`next` phase).** zone_001
    re-entered and abandoned from the pause menu (ABANDON ZONE, CONFIRM
    ABANDON); the portal designs zone_002 with the whole profile; the
    bridge's record shows EX50-011 built as `c025` behind `c015`; the
    layout is ACCEPTED.
  - **Played, before the restart (`next`, 21 checks):**
    - HARNESS STEP, declared: placed at c015's arrival, then walked in.
    - H EAST pulled at A. HARNESS STEP, declared: the player is killed
      through the damage path. The shuttle went home from 1.52 m by
      ordinary motion (largest step 0.054 m, the docking snap included),
      and its rest at WEST was reported.
    - H EAST again, then STOP H at A as the shuttle crossed the
      rendezvous: HELD at 8.075 m with no errand, ACCEPTED as
      `minor_c025/shuttle` = [8.075, "", true].
  - **Restarted (`next_restore`, 18 checks).** Before the player: the
    shuttle HELD at 8.075 m, as saved, with 0.0000 m of drift over a
    second, and no rest reported back. Then the patient route (§6) was
    finished FROM the restored shuttle: onto the lift at A, LAUNCH, its
    dwell reported as a held rest bound for SHELF, the step across onto
    the held shuttle, H ON EAST from its own deck, carried to EAST,
    walked off onto G, the stair ACCEPTED as `minor_c025/stair`, Check
    89100005 CONFIRMED, and the lift, left to its schedule, came to rest
    at SHELF.
  - **Restarted again (`next_final`, 7 checks).** The stair stands with
    G's railing open where it lands, the shuttle at EAST and the lift at
    SHELF exactly as last saved, the Check still claimed, and the stair
    walked from A up onto G with both carriers elsewhere. Nothing is
    sent back.
  - **Whole run, one process chain, at `400ed37`:** `godot-candidate-
    live` seed 40, play 20, restore 5, minor 32, minor_restore 15,
    next 21, next_restore 18, next_final 7, all OK. Around it, with no
    regressions: `make test-bridge` 1883 passed, 1 skipped;
    `godot-passing-platforms` 70; room-contract; actuator 93;
    rail-carrier 73; rail-junction 140; rail-zone 25; room; zone-audit;
    content; counterfire 44; unweighted 62; zone-state 60; transport-live
    6/16/18/12; reversible-live 3/9/6; latched-route-live 2/18/12;
    consumable-live OK. `godot-zone-audit` rewrote the placement
    fixtures' `controller_digest`, stale since O05-01 changed
    `player.gd` (committed apart, `3f6c1d3`).
  - **Direct-handler checks, labelled as such** (`godot-passing-
    platforms`): a lift stopped in its dwell reports [4.0, "SHELF",
    held]; handed to a second room it waits five seconds without
    leaving, and LAUNCH resumes it to SHELF; the shuttle restores held
    at 7.25 m.

### O05-07 — the shared graph, broadened through a real consumer — slice 1 done

- **The consumer is EX50-033's own chain.** The room wired it by hand:
  the HEAVY plate through a NOT into the shutter, and the bolt holding
  the crossing open. It is now declared in the minor's occurrence
  contract (`MinorContract.graph`) and run by the shared `SignalGraph`,
  in both the `--unweighted` scenario and the hosted room:

      plate (PRESSURE_PLATE, HEAVY) -> NOT (unloaded) --.
                                                         OR (open) -> shutter
      bolt_lever (PULSE_BUTTON) -> LATCH (bolt) --------'

  The room binds its own plate, lever and shutter to the declaration's
  ids and keeps only presentation: its lines and the return stair. The
  LATCH id is the contract's latch, so a pulled bolt is still
  `minor_<room>/bolt` and a restored one comes back through
  `restore_latch`, silently.
- **Two kinds join, with §19.1's port forms.** `PULSE_BUTTON` (a pulse,
  one tick) and `OR` (2–4 Booleans). A pulse feeding a Boolean reader,
  or driving a machine by itself, is refused at composition. The P14
  LATCH's Boolean set is kept (D-10 option B). `settle` and `upstream`
  now handle trees; a single chain comes back as before.
- **What a Zone may ask for did not widen.** A Zone may declare only
  sensors its builder places (plates), and `RoomGraphs` refuses anything
  else instead of placing a plate for it. A route gate hangs only on a
  plate through NOT/LATCH, the shapes the route search reasons about;
  an OR in front of a route is refused by name. The same OR as a machine
  in a room is legal.
- **Evidence.**
  - Bridge: 13 new tests, and 4 sabotages each fail their test (port
    forms twice, the route rule, the placeable rule).
  - `godot-unweighted` 69: the 62 comparison checks unchanged, plus 7
    that read the graph itself. They check the bindings, the node order,
    and OPEN at rest. With the crate on the plate: plate ON, NOT OFF,
    OR OFF, and the graph shuts the crossing. The bolt's one-tick pulse
    sets the LATCH, and the OR holds the crossing open with the plate
    still loaded. On the next tick the pulse is gone and the latch holds.
    §11's control leaves the plate sensor declared and unbound.
  - Sabotage: with the runtime's OR always false, the chain fails
    throughout, the complete route included, so the shared runtime is
    what opens and holds the crossing, not leftover wiring.
  - Unchanged: `godot-signal-graph` 46, `godot-latched-route` 38,
    `godot-graphs`, `make test-bridge` 1897 passed.
  - In a Zone, through the real bridge: `godot-candidate-live`, all
    eight phases, the same counts as at `400ed37` (40/20/5/32/15/21/
    18/7). That includes the hosted EX50-033 in c024: the bolt pulled
    and accepted as `minor_c024/bolt`, then restored before anyone
    acts, and still holding the crossing with the crate back on the
    plate.
- **~~Not routed, and why: EX50-021.~~ CORRECTED in slice 2.** This
  said the window was the shutter's own timer "by design", citing
  `ServiceShutter`'s comment and EX50-021 §3/§9. §3 says the opposite:
  "the eight-second TIMER refreshes on another valid receiver hit. Its
  output opens the service shutter." §9 calls it "the receiver timer".
  The shutter's clock was an implementation shortcut, and the note
  mistook it for the source's intent. EX50-021 is now routed (below).
- **Also fixed:** `test_a_zone_with_no_edges_is_declined_with_the_reason`
  (O05-02, this lane's) had skipped on every run. Its Zone could not be
  validated without edges. It now builds a Zone that can, and runs; the
  bridge suite has no skips.
- **Still unsupported, individually:** AND, DIRECT, TIMER, SEQUENCE,
  COUNTER, SELECTOR, DELAY, THRESHOLD; fifteen of the eighteen sensors;
  all five signal verbs (O05-07.4).

### O05-07.5 — sensor distinctions and safety, on the graph runtime

Tests only; no runtime change was needed. Each case runs through the
graph, not just the sensor, and each was sabotaged.

- **A class is not a sum.** Two MEDIUM bodies of 100 kg, 200 kg
  together against HEAVY's 120 kg floor, stand on a HEAVY plate. The
  plate is not satisfied, the NOT stays true and the shutter stays
  open. The plate-level pair already existed
  (`mass_class_driver._debris_does_not_add_up`); this one is the graph
  reading the plate. Sabotage: a plate that adds up kilograms fails it.
- **Duplicate occupancy.** Two HEAVY bodies are one answer, not a
  count. Taking one off must not change the plate's answer even for a
  frame; the check records every `occupancy_changed` the plate emits.
  Only the last one leaving releases it, once. Sabotage: a plate that
  releases for one frame when any body leaves fails it with answers
  `[false, true]`, although its end state (NOT false, shutter shut)
  looked right. That is why the check records answers, not only the end
  state.
- **A repeated pulse.** A second pull fires nothing more:
  - in the suite, the LATCH fires once;
  - in EX50-033, the LATCH fires once and the room engages once.
  Sabotage: a held LATCH that re-fires on a pulse fails both suites,
  with "LATCH fired 2 time(s), the room engaged 1". The room's own
  `bolted` guard would have hidden it, so the check counts the latch.
- **Stale callbacks.** A lever outlives the graph that wired it:
  - freeing the graph leaves nothing on the lever, so no pull can reach
    a graph that is gone;
  - its replacement, started twice, is wired once and hears one pull
    once.
  Stated plainly: both hold at the engine as well. Godot drops a freed
  target's connections, and it refuses an identical second connection
  with an error. So removing the graph's own wire-once guard does not
  fail the check; it adds the engine's error to the log (confirmed).
- **Already covered, not repeated:**
  - removal (`_a_heavy_occupant_closes_it_and_leaving_opens_it`);
  - player participation per sensor (`_the_player_is_not_an_occupant`,
    and `mass_class_driver._counts_player_is_the_only_door` for the
    decisive `counts_player` pair);
  - a pulse's normal expiry after one tick (`godot-unweighted`);
  - route requirements widened only through the named route kinds
    (slice 1).
- **Waits on its producer:** repeated SHOTS need SHOOTABLE_TARGET in the
  graph, and the expiry of a temporary override needs O05-07.4's verbs.
- **Evidence:** `godot-signal-graph` 57 (46 + 11);
  `godot-unweighted` 70 (69 + 1).

### O05-07 — slice 2: EX50-021's own chain, through the graph — done

- **The consumer is the arcade's own contract.** EX50-021 §3 names the
  parts: "the receiver emits one pulse per valid hit", "the eight-second
  TIMER refreshes on another valid receiver hit. Its output opens the
  service shutter", and the manual release is permanent. §9: "The
  receiver timer is ephemeral." Declared in the minor's contract and run
  by `SignalGraph`, in the `--counterfire` scenario and in the hosted
  room alike:

      receiver (SHOOTABLE_TARGET, PULSE) -> TIMER (window, 8 s) --.
                                                                  OR (open) -> shutter
      release_lever (PULSE_BUTTON) -> LATCH (release) ------------'

  It is the same tree as EX50-033's, with a TIMER where the NOT was. The
  LATCH id is the contract's `release`, so saves read the same.
- **Two kinds join, each with this consumer.**
  - `TIMER`: one pulse in; ON for `duration` after it; a new pulse
    restarts it (§19.2); EPHEMERAL (§19.6). The runtime runs TIMERs down
    on the physics tick, and a TIMER running out re-evaluates the graph.
    That is the one change no sensor announces.
  - `SHOOTABLE_TARGET`, in PULSE mode: `ImpactReceiver`, which already
    reuses the activity SHOT path (07.1's "reuse SHOT/STAND/TOUCH ...
    paths"), with its 0.4 s re-arm as the debounce. TOGGLE is refused:
    nothing reads it.
- **A stated gap: `[RANGED]` is a floor, not a filter.** §20.2's
  `required_tags` defaults to `[RANGED]`. The runtime has no damage
  tags: `take_damage` carries an amount, a direction and a knockback,
  and the SHOT path counts any hit, "a melee swing" included. So every
  ranged hit operates the receiver and a Static Pulse always suffices,
  which is what §20.2 requires of a mandatory target. But a swing or a
  blast would operate it too. A target requiring MELEE or EXPLOSIVE
  would be operated by a Static Pulse, the opposite of what it says, so
  the schema accepts exactly `[RANGED]` and refuses every other tag set
  by name. Enforcing tags means a DamageRequest carrying them through
  every damage call site. That is a cross-cutting change this lane did
  not make, so it is recorded here for review.
- **One clock, not two.** `ServiceShutter` kept its own timer (`trip`,
  `open_seconds`, `left`), and the arcade tripped it directly. It is
  now commanded like every actuator, and the window is the TIMER's.
  `create(...)` lost its `seconds` parameter: five call sites, one of
  them a test's (`actuator_driver`), which passed the value positionally.
- **A shared binder.** `SignalGraph.bind_declared` moved up from
  EX50-033's room now that there are two. It also checks that each
  declared sensor's machine is of its kind. A lever bound under a
  target's id is left unbound (reads OFF) and reported, rather than run
  as something the declaration never described.
- **Tests changed, and why.**
  - `counterfire_driver`'s interlock case opened the shutter with
    `trip()` and ran it out with `shutter.left = 0.2`. It now opens it
    with a hit on the receiver's own target body and runs out the
    graph's TIMER. The assertions are unchanged, and the case now
    exercises the path the room actually uses.
  - Two "(%.1f s left)" messages read the removed `shutter.left`; they
    read the TIMER now (`window_left()`).
  - The wrapper's `_on_release` test hook pulls the lever through its
    own `interact`, so the graph hears it.
  - Two bridge tests pin the supported sets. They now list TIMER and
    SHOOTABLE_TARGET, and everything else is still refused.
- **Fixtures regenerated, not edited:** `latched_route_zone.json` (Dess's
  P14 fixture) and `candidate_zone.json`. Each gains three `null` keys
  per graph (`mode`, `required_tags`, `duration`), dumped the way
  `requires_class` already is. The content is otherwise identical,
  checked key by key. `proposal_digest` is derived and never stored, so
  no save is affected. Omitting the keys instead needs pydantic 2.11's
  `exclude_if`; the pin is `>=2.6`, and raising it would be a tooling
  upgrade.
- **Evidence.**
  - Bridge: 10 new tests; `make test-bridge` 1907 passed, none skipped.
  - Four schema sabotages each fail exactly their own test: a TIMER fed
    a Boolean, any tags accepted, TOGGLE accepted, and duration made
    optional.
  - `godot-counterfire` **55** (44 + 11). The 44 played and primitive
    checks are unchanged in assertion; the committed hostile shot, the
    fallback Static Pulse, the interlock and the release now run through
    the graph. The 11 new checks read the graph itself:
    - the bindings, and the node order TIMER/LATCH/OR;
    - the declared 8 s equals the room's §2 `OPEN_SECONDS`;
    - SHUT at rest;
    - one hit is one pulse, TIMER ON at about 8 s;
    - on the next tick the pulse is gone and the window holds;
    - REPEATED SHOTS: a second hit restarts the window (6.38 s → 7.98 s),
      and a third inside the re-arm is not a third pulse;
    - expiry: window OFF, OR OFF, shutter shut;
    - the release LATCH fires once and holds the OR through a later
      expiry.
  - Runtime sabotages, each failing its checks:
    - a TIMER that does not restart ("6.38 s left, then 6.37 s");
    - an expiry that does not re-evaluate (the interlock and expiry
      cases);
    - receivers ignored (every played "shutter opened" fails, so the
      graph is what drives the room);
    - a binder that accepts any kind.
  - `godot-signal-graph` 59 (+2, the binder), `godot-unweighted` 70,
    `godot-actuator` 93, `godot-graphs`, `godot-latched-route` 38,
    `godot-content`, `godot-encounter` 51, `godot-room-contract`,
    `godot-zone-audit`, and, because `StateGates` drives the same panel,
    `godot-zone-state` 60, `godot-reversible` 32 and `godot-transport`
    106: all OK, all at their previous counts.
  - Live, through the real bridge:
    - `godot-candidate-live`, all eight phases at the same counts as
      before (40/20/5/32/15/21/18/7). The hosted arcade in c025: the
      Zone's own gunner's shot trips the receiver, the player goes
      through "inside its interval (5.6 s left)", read from the TIMER,
      and the release is accepted as `minor_c025/release`. On restart it
      is restored through `restore_latch` before anyone acts, and still
      holds the shutter two and a half windows later.
    - `godot-latched-route-live` against the regenerated fixture: 2/18/12.

### O05-10 — machinery through interruptions, on this run's occurrences — 10.1, 10.3, 10.4 in part

- **10.1, the audit, limited to the machine kinds this run touched.**
  - **`ServiceShutter`**: every doorway machine this run built uses
    this one panel class:
    - EX50-021's shutter, commanded by its graph's TIMER;
    - EX50-033's, by its graph's NOT/OR;
    - the P14 route panel (`RoomGraphs`);
    - O05-04's `StateGates` doorway (`settle`/`command`).

    Its closure is §21.2's through the shared `SafeClosure`, which
    `Actuator` also uses, so no second safety helper exists. Since
    O05-07 slice 2 it keeps no clock of its own either.
  - **`RailCarrier` / `ShuttleDeck`** (EX50-011) step through the shared
    `StopTravel`. They carry the player, so §21.1.1 has them hold.
  - **Power loss is untested here, stated:** no occurrence built this
    run has a power source, a `HAZARD_CONTROLLER` or a
    `LIGHT_CONTROLLER`. §21.1.1's per-kind rows stay an explicitly
    untested family for these occurrences. The P15 construction suite's
    coverage is not a substitute (§10's "Done").
- **10.3, interrupted operations.**
  - **A real mid-motion reversal, on EX50-021's shutter**
    (`godot-counterfire`, new): the window runs out and the panel goes
    down. At 0.591 open, with the doorway clear (this is not the
    interlock), a hit arrives. The panel goes back up from 0.591, never
    lower, with no step larger than 0.014 of its travel in a frame, and
    opens fully. That is §21.1's "reverse immediately from the current
    `t`. No snap, no pause, no completion of the current leg".
    Sabotage: a shutter that ignores commands mid-motion finishes the
    leg (lowest 0.000) and fails it.
  - **Blocked closure, reopen and retry:** the arcade's interlock case,
    now through the graph. The window expires with the player in the
    doorway, the panel holds open (3.1 s over), and it shuts once the
    doorway is clear.
  - **A queued change:** O05-04's "CLOSING QUEUED · DOORWAY OCCUPIED",
    applied by itself once clear (`godot-reversible` 32).
  - **No restart from stale input:** a pulse is gone on the next tick
    (EX50-021 and EX50-033). EX50-011's death reset leaves its carriers
    at their reset rest until a new call (O05-06.2).
- **10.4, ownership and isolation.**
  - **Two arcades, two windows** (`godot-counterfire`, new). A hit on
    one opens its own window (6.38 s) and not the other's. The first is
    freed mid-window. The other stays shut, and a room built in its
    place starts shut with no window, evaluated exactly once. Sabotage:
    TIMERs shared across graphs (`static var timers`) fails both checks
    and an existing one.
  - **A freed graph's lever wiring reaches nothing**, and its
    replacement is wired once (O05-07.5).
- **Remaining, individually:**
  - 10.2's "separately selected constrained assembly": no constrained
    assembly is in the candidate. Its Passing Platforms half was done
    with O05-06.2.
  - 10.4's "counters or resources do not accrue repeated effects after
    several enter/leave/restart cycles" has no dedicated measurement.
    The candidate-live chain restarts the process eight times, and its
    restore checks assert nothing is announced twice, but no counter is
    read across cycles.
  - Power loss (above).
- **Evidence:** `godot-counterfire` 59 (55 + 4).

### O05-11 — the consumable slot, for the candidate only — promoted; natural acquisition bounded by an open rule

- **Commitment ordering holds, so promotion was allowed (11.1/11.2).**
  The condition in `capabilities.py` was "authorize, then launch, and
  never refund a charge whose effect is already in the world, with
  coverage that counts accepted expenditure". It is met:
  - the press only reserves and authorizes;
  - `_on_consumable_authorized` launches, then commits, or releases a
    launch that did not happen;
  - `godot-consumable-live` and `-restart` count accepted spends across
    a dropped socket and a killed process.

  Nothing new was needed there. That is inspected, not re-tested.
- **Candidate-only promotion (11.4).**
  - `candidate.OPTIONS = ("consumables",)`. It is switched on by the
    same `--candidate` spec, and `all` includes it. It is not a Zone
    step: the engine keeps it in `candidate_options`, apart from
    `candidate_steps`, so every "is the profile on" test still asks
    about Zone composition.
  - Under it, `_echo_request` advertises all five slots
    (`allowed_for(consumable=True)`). `generate_echo_validated` admits
    exactly the slots the request advertised.
  - **Production is unchanged:** `IMPLEMENTED_ACTION_SLOTS` still
    withholds `consumable`, and `test_s1_review_fixes`' STAGED
    assertion is untouched.
  - The launcher prints the option in its profile line. A candidate slot
    made before this commit resumes only under its own profile, and the
    refusal names `--candidate=zone_state,transport,latched_route,minors`.
- **The provider's reading (11.3).** Offered the slot, the fallback reads
  a Bomb Bag as three of the same bomb: the weapon reading's `arc_lob`
  (34 damage, 4 m), plus a 1.5 s `stunned` on what the blast catches.
  That is real damage and a supported Status. Not offered, it is the
  weapon, exactly as before, and no other item reads differently.
- **Acquired, folded, slotted, spent, kept (bridge, real engine).**
  `test_the_candidate_acquires_uses_and_keeps_a_bomb_bag` runs a mock
  campaign under the option through these real steps:
  - the Check is claimed;
  - the fallback reads the item as the consumable, and it validates;
  - the fold owns it with 3 charges;
  - `handle_slot_action` slots it;
  - `handle_authorize_consumable` and `handle_use_consumable` settle
    one use;
  - the save reloads from disk with 2 left, still slotted.

  **One thing is arranged, and the test says so:** the first Check's
  item NAME is set to "Bomb Bag". Its id, recipient and flags are kept,
  so allocation is untouched. The next point is why.
- **THE BOUNDARY: in the mock's own campaigns the sequel rule takes the
  bomb.** Unarranged, every Bomb Bag reaches a campaign that already
  owns a lob (prototype seeds default and Soak00–07; default scale).
  Those lobs come from items no keyword rule matches ("Boomerang",
  "Revelation Scroll", "Restoration Wine"), which fall through to the
  fallback's default "throw it" `arc_lob`. `_as_sequel`, ECHOES §11's
  "a sequel when the campaign already owns the item's verb", keys the
  family on the primitive alone, so the consumable CREATE becomes that
  weapon's UPGRADE (pinned:
  `test_in_the_mock_s_own_campaign_the_sequel_rule_takes_it`).
  - **Whether a consumable shares a family with a verb you always have
    is a design decision, not a missing mapping.** ECHOES v0.8 predates
    the consumable slot, and no accepted source settles it. Changing the
    family key would redesign S6's evolution rule, so it is left for Dess
    and the owner.
  - Until then, a candidate played on the deterministic provider will
    rarely hold a consumable. A live model sees the slot offered and may
    create one.
- **Runtime:** P5-19 (above) makes the bomb's stun, and any projectile's
  status, actually land. `godot-consumable` 91, `godot-verbs`,
  `godot-stats`, `godot-lab`, `godot-archive` 23, `godot-hud` and
  `godot-legible` are OK.
- **Not claimed:** a live Godot run of this naturally acquired bomb. The
  live consumable suites use `give_consumable.py`, a test setup, and a
  hitscan charge. The bomb's client path is the same `EchoRuntime`
  press, now with its status proven in `godot-verbs`.

### O05-08 — manipulation: what is a missing mapping and what is a decision (owner's question, answered)

- **What the accepted sources pin.**
  - **Delivery**, Amalgam §11.7: the twelve verbs enter "through the
    `effect` dimension of the Ability grammar, each carrying a
    non-costed discriminator" (`physics_verb` / `field_verb`) on costed
    atoms:
    - `effect_physics_basic` (24): PUSH, PULL, ALIGN, SETTLE;
    - `effect_physics_hold` (30): HOLD, ROTATE, PIN, TETHER;
    - `effect_physics_structural` (34): ATTACH, DETACH;
    - `effect_mass_field` (32): the two fields;
    - `effect_physics_master` (62, `tier_min` HIGH): all twelve.

    An Ability is a composition, e.g. `ab_physics_light` = `form_press`
    + `effect_physics_basic` + `target_actor` + `recharge_cooldown_short`
    + `scaling_flat`, `physics_verb = PUSH` (§ table at line 768).
  - **Legal forms**, Design 2 §12.9: PRESS / HOLD / CHARGE_RELEASE, and
    RESOURCE / COOLDOWN, never ACTION.
  - **Behaviour**, Design 2 §14.2–§14.4: eligibility, per-verb effect,
    profile numbers, limits.
  - **Qualification**, §29.3: `capability:core:manipulate` is Boolean
    membership in {PUSH, PULL, HOLD}, and the envelope is 700 N / 20 m /
    120 kg.
- **What the running Echo representation is:** ECHOES v0.8's Action,
  meaning one primitive from a closed catalog (28 plus 3 modifiers),
  bounded numbers, a slot, a cooldown, up to 2 modifiers and optional
  charges. There are no atoms, compositions, costs or discriminators,
  for ANY verb. The bridge implements no part of the Amalgam's
  composition grammar (searched).
- **Fields the current representation cannot carry faithfully:**
  1. the atom identity and its cost (24/30/34/32/62);
  2. `tier_min` HIGH for the master atom;
  3. the separate `form` / `target` / `scaling` dimensions of a
     composition;
  4. `physics_verb` as an atom's discriminator, i.e. the rule that
     verbs within one atom are "priced equivalently";
  5. CHARGE_RELEASE on a verb. The running model has charge only on
     `charge_shot`, a damage primitive.

  RESOURCE recharge IS carriable (`powers` links), and a cooldown is.
- **Verdict, in three separate parts (none substitutes for another).**
  1. **Verb runtime: a bounded, faithful integration is possible and is
     within this batch's authority.** §14.2/§14.3 are exact: the
     impulse formula and its 30 m/s and 14 m/s clamps, HOLD's
     1.5–6.0 m distance, 8 m/s and release conditions, ALIGN's
     0.3 s + 2.5 s, SETTLE's exclusions, PIN's durations. It builds on
     `Manipulation` / `ManipulableBody`. Evidence would be direct
     invocation, labelled "runtime, not delivered". Per 08.5 it stays
     unavailable to generation, because a verb that no Action reaches
     is not enabled.
  2. **Normal Echo delivery: a genuine design boundary, not a missing
     mapping.** Adding a `physics_verb` primitive to the ECHOES catalog
     would carry the verb and a profile's resolved numbers, but not the
     atom semantics: cost, tier, which verbs share a price. It would
     also be a second delivery path beside the composition grammar the
     accepted design names as the path. That is the parallel ability
     system the owner excludes. Delivery needs either the composition
     grammar (a replacement of the Echo representation, Dess's model)
     or an explicit decision on how atoms are represented in the
     interim.
  3. **Mandatory-route qualification** exists as data and code
     (`physics.MANIPULATE_VERBS`, `Manipulation.Envelope`,
     `grants_manipulate`). It qualifies a HOST, so it has nothing to
     read until delivery exists.
- **What this lane will do next inside that line:** the verb runtime,
  one verb family at a time, labelled runtime-only, unavailable to
  generation. Nothing is delivered, and there are no primitives or
  shortcuts.

### O05-14 — existing visual work — reconciled; nothing it may bind

- **14.1.** The checkout has no delivered enemy or machinery models. The
  registry holds 12 room shells, 6 fixtures and 3 projectile visuals.
  18 are `pass` and bound; the 3 projectiles are `pending`. Pending is
  not approval, and they stay unbound.
- **14.2.** D-11's exact-role lookup, family fallback, pack-aware caches
  and universal-role refusals are unchanged since OV04 (#128). No seam
  is added without a delivery to consume.
- **14.3.** No candidate pack is available to review. `THEME_PACK_STATUS`
  stays `{}`, and Arty stays paused.

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
  - `minors` emitted in 12 of 12. Regenerated at `3f6c1d3` (clean) with
    all three contracts and the offer order turning per Zone:
    EX50-033 in 7, EX50-021 in 7, EX50-011 in 8. Each Zone hosts two, or
    one where only one dead end qualifies (zone_004, zone_012), and the
    rest decline by name. zone_002 hosts EX50-011 as `c025` behind
    `c015`, the same rooms as the live run; its Check differs because
    that run's zone_001 was played before it was abandoned.
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
- **P5-16 — EX50-033's guide rails were a way round the whole room.**
  The rails that keep the crate in its channel were 1.4 m tall, walkable,
  and ran to the doorway. The jump apex is 1.33 m, so the rail is out of
  reach from the floor but not from the parked crate (1.0 + 1.33), and
  from the rail top the sill is (1.4 + 1.33 > 1.9). That route crosses
  while the empty plate holds the crossing open: no step placed, no
  LIGHTENED. It was found when the live suite's "standing on the crate
  top" check measured the player at 1.35 m after the Zone's layout
  changed the approach, i.e. standing on a rail. The rails are now
  0.45 m (0.45 + 1.33 = 1.78, under the sill), and `godot-unweighted`
  asserts that a jump from them stays under the sill (62 checks). The
  scenario had passed 61 checks with this route open.
- **P5-17 — the room audit measured every exit on the room's far wall.**
  `RoomAudit._openings_are_holes` probed "the exit" at
  `(exit.x, exit.y, bounds.end.z)`. For a room whose `exit_yaw` turns the
  way on to a side wall, that is not the doorway: beside EX50-021's flank
  it was open air, so that exit passed without being looked at, and
  beside EX50-011's gallery it was a wall corner, so a doorway a real
  body crosses was reported sealed. The probe now stands on the wall the
  exit faces (`_exit_facing`, from `exit_yaw`, the way the entry was
  corrected on 2026-09-03). Sabotage: with EX50-011's aperture filled,
  the audit reports the exit sealed at (14.25, 4.0, 13.75), the real
  doorway. Every shell passes the room contract.
- **P5-18 — EX50-011's service stair ended against a railing.** The
  stair released at G runs up to G's south edge, which carries a 1.1 m
  railing. So a body walked up it stopped on the top step
  (`pp_stair_before.log`: feet at z = -1.475, G starts at z = -1).
  The first version of the new check passed anyway: it tested only x
  and height, which the top step also satisfies, and its walker hopped
  whenever it stalled (the jump apex clears 1.1 m). The check now walks
  without ever jumping and requires the body on G, and it failed. The
  railing is now cut where the stair lands, and only once the stair
  exists, since before that the edge is a 4 m drop. Up and down both
  pass, and `next_final` walks it in the Zone.
- **P5-19 — a projectile's `apply_status_on_hit` was applied to no one.**
  `EchoRuntime._launch` handed a projectile its `knockback_target` and
  dropped every other modifier. So a rocket, a lob or a charge shot
  carrying a status did its damage and applied nothing, silently. Yet
  the schema pairs the modifier with any damage primitive, and the stage
  gate admitted it.
  - **Who it touched:** any projectile Action with a status, including
    an owned projectile weapon the fallback's "enhancement" reading
    gives a status.
  - **The fix:** the projectile carries the modifiers and applies them,
    through the target's own `StatusEffects.apply`, to what its direct
    hit lands on and to every enemy its blast reaches.
  - **Evidence:** `godot-verbs` fires a straight shot and a lob at real
    enemies. With the handoff removed, both checks fail with the enemy
    damaged and carrying no status.

