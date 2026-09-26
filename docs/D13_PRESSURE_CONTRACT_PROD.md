# D-13 — held plates, permanent controls, and legacy step-once routes (H-PRESSURE-C)

**Dess → Prod, 2026-09-24.** The contract H-PRESSURE-R and H-CIRCUITS
consume.

**Rulings:** D-07 (pressure plates are held sensors) and M-1 (legacy
step-once Zones keep their saved behaviour, and new composition never
produces them). Both are verbatim in `docs/ledgers/DESS_POST_PLAYTEST.md`.

**Status (2026-09-25):**
- 1a and 1b landed at `d2ffea0`.
- 1d's bridge half landed: the rules at `bca85d4`, then the composer and
  the fixture `godot/tests/fixtures/held_route_zone.json`.
- 1c landed on your lever placement (`2346261`): the lever is a Zone
  sensor and a route sensor, the production composer emits
  `lever -> LATCH -> shutter`, and its fixture is
  `godot/tests/fixtures/lever_route_zone.json`. The candidate profile
  composes the lever route again (c009 across `e:c009:c010`).

Everything below names its file.

---

## 1. What changes, and where

**1a. Refusal at acceptance, not at load.**
- `validate_zone()`, the accept-time check that never runs on a save
  load, refuses a room graph in which a `PRESSURE_PLATE` reaches a
  `LATCH`'s set input, directly or through `NOT`/`OR`.
- The Zone **model** validators do not change, so every accepted Zone
  in every save still parses and behaves as saved (**M-1**). Nothing is
  reinterpreted as a held plate and nothing is opened by invented state.
- File: `schemas/zone.py`.

**1b. The composer stops emitting it, in the same commit.**
- `compose_latched_route` no longer produces plate → LATCH.
- It has to land in the same commit as 1a, because the candidate
  profile's re-certification discards a whole Zone that introduces a
  `validate_zone` error. A refusal landed alone would silently drop
  every candidate Zone's other steps.
- **Until you placed levers it declined, with its reason.** Since 1c it
  emits the lever form.
- The fixture regenerates.
- Files: `latched_route.py`, the fixtures.

**1c. The permanent route: a visibly permanent control.**
- `PULSE_BUTTON` (lever or bolt) → `LATCH` → shutter. Stepping on
  nothing latches anything; pulling the lever is the decision.
- Bridge half:
  - `PULSE_BUTTON` joins `ZONE_PLACEABLE_SENSOR_KINDS` and
    `ROUTE_SENSOR_KINDS`;
  - the route validator settles a pulse source the way it settles a
    plate: rest closed; pulled, so latched; open for good;
  - a lever needs no class or weight — it is base kit.
- **Corrected by Prod's N-4:** `RoomGraphs` did read the bridge's
  placeable list, and refused anything outside it. It now keeps its own
  list (`PLACEABLE_SENSOR_KINDS`: plate and lever), and
  `godot-signal-graph` asserts that whatever the bridge exports as
  placeable is in it. The order held either way: the bridge admitted
  the lever only after `RoomGraphs` could place one.

**1d. The live-pressure route: a plate held by a guaranteed weight.**

plate → shutter, with no latch, open only while pressed. It is legal
only if the plate names its weight: `SensorNode.held_by: <object_id>`.
The weight must be:
- a declared `TransportedObject` with `movement = hand_carried` (the
  existing §10.3 rule: `carriable`, ≤ 60 kg);
- of a class, `mass_class(mass_kg)`, at least the plate's;
- carried in a volume, `allowed_volume`, that includes the plate's room;
- **not** also the object of an `ObjectConsumer`, because it cannot
  hold a plate and be installed elsewhere;
- at home, `home_room_id`, somewhere reachable **without** the edge the
  plate opens — the route search models the edge as open once the
  weight can be fetched. Recovery returns it to that side.

**The player's own body never counts as this route's solution:** no one
can stand on the plate and walk through the door. `counts_player` may
still be true so standing on it gives feedback.

**Persistence comes free.** The weight's settled pose is already
`ZONE_PERSISTENT` (`object_poses`). A reload restores it on the plate,
the plate reads pressed, and the door opens. No plate state is saved.

**Runtime you already have:**
- `ClassPlate` reads object classes;
- ordinary hand carry is closed (O05-01).

So this route may be playable on the current runtime, subject to your
acceptance: the weight rests on the plate, the door stays open, and
lifting the weight while the player is in the doorway uses the closure
interlock.

Files: `schemas/signal_graph.py`, `schemas/zone.py`, `topology.py`.

**1e. Timed is its own mechanic.**
- `plate → TIMER` is already refused: TIMER reads a pulse, and a held
  plate is not one (`NODE_INPUT_FORMS`).
- A timed opening is a pulse source feeding a TIMER, **presented as a
  timer**. It is never a plate that "lingers".

## 2. What does not change

- The general `LATCH`, its `graph_` recording and its restore order.
- `counts_player`, and the distinction between class and kilograms.
- 60 kg hand carry versus 120 kg manipulation: no device is renamed to
  move a number.
- Every legacy Zone's saved behaviour (**M-1**).

## 3. Tests the bridge half lands with

- A legacy save containing plate → LATCH loads, keeps its graph, and
  its recorded `graph_…` latch restores.
- `validate_zone` refuses a new plate → LATCH (direct, through `NOT`,
  through `OR`).
- The composer never emits one (a sabotage run with the old emitter
  fails the test by name).
- **Held-weight:**
  - legal with a proper weight;
  - refused for an undeclared weight, a manipulable-only weight, a weight
    of too low a class, a weight outside the volume, a weight that a
    consumer also installs, and a weight whose home lies behind the
    gated edge;
  - route search: sabotage the modelling and the far-side case passes
    unnoticed.
- **Lever route** (landed with your placement): legal, open for good,
  recorded, restored.

## 4. What is yours

- **H-PRESSURE-R:**
  - replace the step-once passage with the lever form (1c has landed:
    play `lever_route_zone.json` as composed);
  - or build the held-weight arrangement (1d) where the local weight is
    solvable;
  - closure safety when the weight is lifted;
  - legacy Zones unchanged in play.
- **Lever placement** in `RoomGraphs`, landed with 1c.
- **Arty (H-CIRCUITS):** a held plate and a lever/bolt must look
  different, with pressure and state feedback.
