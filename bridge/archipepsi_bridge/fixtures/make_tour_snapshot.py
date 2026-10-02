"""Generate `godot/tests/fixtures/tour_snapshot.json`: the owner's own
candidate campaign, played into a Zone, for MENU-INT's tour.

MENU-INT's delivery asks for a short tour of the integrated menu "on real
campaign data" -- not the prototype's sample snapshot, and not the
equipment fixture, whose Echo log is written by hand. So the campaign the
owner played is played again, exactly as `make_bomb_snapshots.py` plays
it (mock AP, the deterministic fallback provider, DEFAULT scale, the
whole candidate profile), to the Zone after the one holding its first
consumable. Along the way a player's own choices are made through the
engine's own handlers:

- the first consumable goes on its key, as H-BOMBS puts it there;
- each empty key takes the first Action owned that goes on it (a player
  seven Zones in has a loadout, and the wall compares against it);

and in that Zone:

  before   the snapshot on arriving: what the wall is met with first, so
           what is claimed after it is new
  after    a player's first walk from the entrance (`_explore`), sent as
           Godot sends it, through the real server's `dispatch`: each
           room entered, each key in it taken, a control set where it
           opens the way on, a lock opened with a key held -- and two
           Checks claimed in rooms walked. The map knows those rooms, the
           journal what was done.

THE WALK IS ONE A PLAYER CAN MAKE. A way is walked only in the direction
it goes (a way back is a one-way device: it lands you at the entrance,
it does not take you from there), and never past a gate this does not
open: a capability the player does not hold, or an opener it does not
work. What it does open, it opens the way the game does, by the intent
the game sends.

Both are the engine's own `snapshot()` as the wire carries it, with the
scout table left out (`meta.omitted`: nothing on the menu reads it). The
Zone's document travels inside the snapshot (`active_zone.zone`), which
is what the tour builds the Zone from.

Deterministic: the mock's placements are a function of its config and
seed, and nothing else here is random. Run with `make tour-fixture` (it
plays several Zones, in seconds). The JSON is not to be edited;
`tests/test_tour_fixture.py` holds it to its generator and its walk to
the bridge's own map.
"""

from __future__ import annotations

import asyncio
import json
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "bridge"))

from archipepsi_bridge import candidate                     # noqa: E402
from archipepsi_bridge import transactions as TX            # noqa: E402
from archipepsi_bridge.campaign import CampaignEngine       # noqa: E402
from archipepsi_bridge.epsilon.fallback import (             # noqa: E402
    FallbackEpsilonProvider)
from archipepsi_bridge.fixtures.make_bomb_snapshots import (  # noqa: E402
    ZONE_LIMIT, _Socket, _consumable_of, _next_zone)
from archipepsi_bridge.mock_ap import MockAPBackend         # noqa: E402
from archipepsi_bridge.schemas import constants as C        # noqa: E402
from archipepsi_bridge.server import BridgeServer          # noqa: E402
from tests.conftest import drain, enter_zone                # noqa: E402

OUT = ROOT / "godot" / "tests" / "fixtures" / "tour_snapshot.json"
OMITTED = ("scouted",)
#: Rooms walked in the tour's Zone, at most, and Checks claimed there.
ROOMS = 6
CLAIMS = 2


def _wire(engine) -> dict:
    snap = json.loads(engine.snapshot().model_dump_json())
    for key in OMITTED:
        snap.pop(key, None)
    return snap


async def _loadout(engine) -> list[str]:
    """Each empty key takes the first owned Action that goes on it."""
    put: list[str] = []
    derived = engine.save.derive()
    slots = dict(engine.save.slots)
    for slot in ("echo_a", "echo_b", "mobility", "utility"):
        if slots.get(slot):
            continue
        for owned in derived.owned:
            component = owned.component
            if getattr(component, "kind", "") != "action" \
                    or str(getattr(component, "slot", "") or "") != slot \
                    or owned.component_id in slots.values():
                continue
            await engine.handle_slot_action(slot, owned.component_id)
            await drain()
            slots = dict(engine.save.slots)
            if slots.get(slot) == owned.component_id:
                put.append(f"{slot}={owned.component_id}")
            break
    return put


def _explore(zone, zone_id: str, held: set[str], limit: int):
    """A player's first walk from the entrance: the rooms in the order
    they are first come to, and the intents that walk sends, in order."""
    chambers = {c.id: c for c in zone.chambers}
    order = [zone.chambers[0].id] if zone.chambers else []
    intents: list[dict] = []
    keys: set[str] = set()
    states = {v.variable_id: v.initial for v in (zone.zone_state or ())}
    setters = {v.variable_id: v.setter for v in (zone.zone_state or ())}
    used: list = []                      # the ways walked

    def arrive(room: str) -> None:
        order.append(room)
        intents.append({"type": "room_entered", "zone_id": zone_id,
                        "room_id": room})
        take(room)

    def take(room: str) -> None:
        for key in chambers[room].keys:
            if key.key_id not in keys:
                keys.add(key.key_id)
                intents.append({"type": "key_collected", "zone_id": zone_id,
                                "key_id": key.key_id})

    def lock_of(edge):
        for room in (edge.room_a, edge.room_b):
            for door in chambers[room].doors:
                if door.edge_id == edge.edge_id and door.usage == "LOCKED":
                    return room, door
        return None

    def opens(edge) -> list[dict] | None:
        """The intents that open this way, [] if it is open, or None."""
        if edge.capability and edge.capability not in held:
            return None
        if edge.opened_by:
            return None                  # an opener this does not work
        out: list[dict] = []
        for need in edge.requires_state or ():
            want = need.variable_id, need.state
            if states.get(want[0]) == want[1]:
                continue
            setter = setters.get(want[0])
            if setter is None or setter.room_id not in order \
                    or (setter.capability and setter.capability not in held) \
                    or want[1] not in setter.selects \
                    or any(n.variable_id == want[0] and n.state != want[1]
                           for u in used for n in (u.requires_state or ())):
                return None
            out.append({"type": "zone_state_selected", "zone_id": zone_id,
                        "variable_id": want[0], "state": want[1]})
        lock = lock_of(edge)
        if lock is not None:
            room, door = lock
            if door.key_id not in keys:
                return None
            out.append({"type": "lock_opened", "zone_id": zone_id,
                        "room_id": room, "socket_id": door.socket_id})
        return out

    if order:
        intents.append({"type": "room_entered", "zone_id": zone_id,
                        "room_id": order[0]})
        take(order[0])
    at = 0
    while at < len(order) and len(order) < limit:
        here = order[at]
        for edge in zone.edges:
            if len(order) >= limit:
                break
            if edge.room_a == here and edge.direction in ("BIDIRECTIONAL",
                                                          "A_TO_B"):
                there = edge.room_b
            elif edge.room_b == here and edge.direction in ("BIDIRECTIONAL",
                                                            "B_TO_A"):
                there = edge.room_a
            else:
                continue
            if there in order:
                continue
            doing = opens(edge)
            if doing is None:
                continue
            for intent in doing:
                if intent["type"] == "zone_state_selected":
                    states[intent["variable_id"]] = intent["state"]
            intents.extend(doing)
            used.append(edge)
            arrive(there)
        at += 1
    return order, intents


def _checks_in(zone, rooms: list[str], allocated, count: int) -> list[int]:
    """The first Checks of the rooms walked, in the order they were."""
    chambers = {c.id: c for c in zone.chambers}
    out: list[int] = []
    for room in rooms:
        c = chambers[room]
        for loc in [c.reward_location_id, *(c.additional_reward_location_ids
                                            or ())]:
            if loc is not None and loc in allocated and loc not in out \
                    and len(out) < count:
                out.append(loc)
    return out


async def build() -> dict:
    with tempfile.TemporaryDirectory() as tmp:
        engine = CampaignEngine(
            provider=FallbackEpsilonProvider(), provider_name="fallback",
            save_dir=Path(tmp), candidate_steps=candidate.parse("all"))
        backend = MockAPBackend(engine, config=C.DEFAULT_CONFIG)
        engine.backend = backend
        await backend.connect("", "Skyiah", "")
        await drain()
        zones = 0
        for _ in range(ZONE_LIMIT * 6):
            hub = engine.hub_status()
            if hub.postgame:
                break
            if hub.mode == "ZONE_AVAILABLE":
                await engine.handle_request_next_zone(hub.finale_offered)
                if engine._generation_task is not None:
                    await engine._generation_task
                await drain()
                continue
            if hub.mode == "GENERATING":
                if engine._generation_task is not None:
                    await engine._generation_task
                await drain()
                continue
            if hub.mode not in ("ZONE_READY", "ZONE_ACTIVE"):
                break
            record = engine.save.active_zone
            zones += 1
            if zones > ZONE_LIMIT:
                break
            if record.state == "GENERATED":
                await enter_zone(engine, record.zone_id)
                await drain()
            consumable = ""
            for loc in sorted(record.allocated_location_ids):
                await TX.claim_check(engine, record.zone_id, loc)
                await drain()
                consumable = consumable or _consumable_of(engine, loc)
            if not consumable:
                await engine.handle_exit_zone(record.zone_id)
                await drain()
                continue
            await engine.handle_slot_action("consumable", consumable)
            await drain()
            loadout = await _loadout(engine)
            await _next_zone(engine, record.zone_id)
            here = engine.save.active_zone
            before = _wire(engine)
            server = BridgeServer(engine)
            held = set(engine.snapshot().available_capabilities)
            walked, intents = _explore(here.zone, here.zone_id, held, ROOMS)
            for intent in intents:
                await server.dispatch(_Socket(), json.dumps(intent))
                await drain()
            claimed = _checks_in(here.zone, walked,
                                 set(here.allocated_location_ids), CLAIMS)
            for loc in claimed:
                await TX.claim_check(engine, here.zone_id, loc)
                await drain()
            after = _wire(engine)
            return {
                "meta": {
                    "profile": "candidate all, mock AP, fallback, default scale",
                    "slot": "Skyiah",
                    "zone_index": zones + 1,
                    "zone_id": here.zone_id,
                    "consumable": consumable,
                    "loadout": loadout,
                    "walked": walked,
                    "did": [" ".join([i["type"]] + [
                        str(v) for k, v in i.items()
                        if k not in ("type", "zone_id")]) for i in intents],
                    "claimed": claimed,
                    "omitted": list(OMITTED),
                },
                "before": before,
                "after": after,
            }
        raise SystemExit(f"no consumable was reached in {zones} Zone(s)")


def render() -> str:
    """The fixture's text, exactly as `main` writes it."""
    return json.dumps(asyncio.run(build()), indent=1, sort_keys=True) + "\n"


def main() -> None:
    text = render()
    OUT.write_text(text, encoding="utf-8")
    meta = json.loads(text)["meta"]
    print(f"wrote {OUT}: {meta['zone_id']} (Zone {meta['zone_index']}), "
          f"rooms {meta['walked']}, Checks {meta['claimed']}, keys "
          f"{meta['loadout']} and consumable={meta['consumable']}")


if __name__ == "__main__":
    main()
