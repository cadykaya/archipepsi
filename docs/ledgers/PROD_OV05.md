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
| `transport_route.py` (new) | P16 `TransportedObject`/`ObjectConsumer`; D-8 `permanent` lifetime; §0-bis (a declared gate is allowed, an undeclared one never is) | an explicit composer step in the same shape as `cross_room.py` and `latched_route.py`. It is never a default, so digests and comparisons do not move | O05-02 commit |

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

