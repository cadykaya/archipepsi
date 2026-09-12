"""Shared helpers for bridge tests. Async tests run via `run()` —
no pytest-asyncio dependency needed."""

from __future__ import annotations

import asyncio
import sys
from pathlib import Path

BRIDGE_ROOT = Path(__file__).resolve().parents[1]
if str(BRIDGE_ROOT) not in sys.path:
    sys.path.insert(0, str(BRIDGE_ROOT))

from archipepsi_bridge.campaign import CampaignEngine  # noqa: E402
from archipepsi_bridge.epsilon import FallbackEpsilonProvider  # noqa: E402
from archipepsi_bridge.mock_ap import MockAPBackend, MockServerState  # noqa: E402
from archipepsi_bridge import layout as _LAYOUT  # noqa: E402
from archipepsi_bridge.schemas import physics as _PHYS  # noqa: E402


def run(coro):
    return asyncio.run(coro)


async def drain(rounds: int = 25) -> None:
    """Let spawned confirm/notify/room-update tasks settle."""
    for _ in range(rounds):
        await asyncio.sleep(0)


def make_engine(tmp_path: Path, provider=None,
                provider_name: str = "fallback") -> CampaignEngine:
    return CampaignEngine(
        provider=provider or FallbackEpsilonProvider(),
        provider_name=provider_name, save_dir=Path(tmp_path))


async def connected_engine(tmp_path, *, provider=None, server_state=None,
                           confirm_delay: float = 0.0, config=None):
    """A connected engine. `config` defaults to the prototype's thirty
    locations, which is what the mock has always meant -- pass
    `C.DEFAULT_CONFIG` for the production scale a human actually plays."""
    engine = make_engine(tmp_path, provider=provider)
    backend = MockAPBackend(engine, server_state=server_state,
                            confirm_delay=confirm_delay, config=config)
    engine.backend = backend
    await backend.connect("", "Skyiah", "")
    await drain()
    return engine, backend


class Collector:
    """Captures everything the engine emits."""

    def __init__(self, engine):
        self.messages = []
        engine.emit = self

    async def __call__(self, message):
        self.messages.append(message)

    def of_type(self, type_name: str) -> list:
        return [m for m in self.messages
                if getattr(m, "type", None) == type_name]

    def notifications(self, kind: str) -> list:
        return [m for m in self.of_type("notification") if m.kind == kind]


class BlockedProvider:
    """Never returns; simulates a hung provider / crash mid-generation."""

    name = "mock"

    def __init__(self):
        self.event = asyncio.Event()

    async def generate_zone(self, request, *, repair_errors=None):
        await self.event.wait()
        return {}

    async def generate_echo(self, request, *, repair_errors=None):
        await self.event.wait()
        return {}


class ScriptedProvider:
    """Returns queued payloads; counts calls and repair attempts."""

    name = "mock"

    def __init__(self, zone_outputs=(), echo_outputs=(), delay: float = 0.0):
        self.zone_outputs = list(zone_outputs)
        self.echo_outputs = list(echo_outputs)
        self.delay = delay
        self.zone_calls = 0
        self.echo_calls = 0
        self.zone_repairs = 0
        self.echo_repairs = 0

    async def generate_zone(self, request, *, repair_errors=None):
        self.zone_calls += 1
        if repair_errors is not None:
            self.zone_repairs += 1
        if self.delay:
            await asyncio.sleep(self.delay)
        return self.zone_outputs.pop(0) if self.zone_outputs else {}

    async def generate_echo(self, request, *, repair_errors=None):
        self.echo_calls += 1
        if repair_errors is not None:
            self.echo_repairs += 1
        if self.delay:
            await asyncio.sleep(self.delay)
        return self.echo_outputs.pop(0) if self.echo_outputs else {}


# ---------------------------------------------------------------------------
# A SOUND LAYOUT, and entering a Zone the way a client does
#
# Lifted out of `test_amalgam_end_to_end` when `claim_zone_check` began
# requiring acceptance: every test that enters a graph Zone and then
# claims needs the layout exchange the real client performs, and one copy
# of it is better than a helper per file.
# ---------------------------------------------------------------------------

SPACING = 50.0
HALF_W = 9.0
DEPTH = 16.0
BRANCH_X = 90.0


def corridor_piece(a, b) -> dict:
    """One chain piece in the shape `zone_builder` emits one.

    Pose and kind as well as endpoints: the engine refuses to replay a
    committed chain whose pieces carry no `position`/`yaw` or an unknown
    `kind` (`malformed_pieces`), so a fixture without them stands in for
    a payload the engine could not rebuild.
    """
    return {"kind": "CONNECTOR", "position": list(a), "yaw": 0.0,
            "entry": list(a), "exit": list(b),
            "bounds": {"position": [min(a[0], b[0]) - 1.5, 0.0,
                                    min(a[2], b[2])],
                       "size": [3.0, 4.0, max(abs(b[2] - a[2]), 0.1)]}}


def place_layout(zone) -> dict:
    """A physically sound layout for this Zone, in the engine's shape.

    Stands in for `zone_builder.build()` until the engine serializes its
    result. The geometry is deliberately spread out — rooms 50 m apart
    with real connector chains between them — so that no join passes by
    happening to touch.
    """
    order = [c.id for c in zone.chambers]
    joined = [e for e in zone.edges if e.realization == "JOINED"]
    # A room reached only by the vault edge is the branch; it goes to one
    # side so it cannot overlap the spine.
    spine = [r for r in order]
    off_spine = {e.room_b for e in joined
                 if sum(1 for x in joined if e.room_b in x.rooms) == 1
                 and order.index(e.room_b) < order.index(e.room_a)}

    centre: dict[str, tuple[float, float]] = {}
    slot = 0
    for rid in spine:
        if rid in off_spine:
            continue
        centre[rid] = (0.0, slot * SPACING)
        slot += 1
    for rid in off_spine:
        centre[rid] = (BRANCH_X, order.index(rid) * SPACING)

    rooms, apertures, anchors, arrival_ok = {}, {}, {}, {}
    physics: list[dict] = []
    for ch in zone.chambers:
        x, z = centre[ch.id]
        rooms[ch.id] = {
            "position": [x, 0.0, z], "yaw": 0.0,
            "bounds": {"position": [x - HALF_W, 0.0, z - DEPTH / 2],
                       "size": [HALF_W * 2, 5.0, DEPTH]},
        }
        for d in ch.doors:
            # Every door reports exactly what its assignment declares,
            # the head's `entry` included: the player arrives 1.2 m
            # inside the first room, so its front wall is a wall.
            apertures[f"{ch.id}/{d.socket_id}"] = d.passable_geometry
        for i, f in enumerate(
                [f for f in ch.features
                 if f.tag in _LAYOUT.CERTIFIED_TAGS]):
            physics.append(certified_chain(ch.id, i, zone.zone_id))
        if any(d.usage != "SEALED" for d in ch.doors):
            a = f"room:{ch.id}:arrival"
            anchors[a] = [x, 0.0, z]
            arrival_ok[a] = True

    joins = {}
    for e in joined:
        ax, az = centre[e.room_a]
        bx, bz = centre[e.room_b]
        # Each socket sits on its own room's boundary, facing the other.
        sa = [ax, 0.0, az + (DEPTH / 2 if bz >= az else -DEPTH / 2)] \
            if abs(bx - ax) < 1e-6 else \
            [ax + (HALF_W if bx > ax else -HALF_W), 0.0, az]
        sb = [bx, 0.0, bz + (-DEPTH / 2 if bz >= az else DEPTH / 2)] \
            if abs(bx - ax) < 1e-6 else \
            [bx + (-HALF_W if bx > ax else HALF_W), 0.0, bz]
        joins[e.edge_id] = {
            "socket_a": sa, "socket_b": sb, "chain": [corridor_piece(sa, sb)]}

    stations = []
    for p in zone.plugs:
        anchors.setdefault(p.source_anchor, [0.0, 0.0, 1.0])
        anchors.setdefault(p.destination, [0.0, 0.0, 0.0])
        arrival_ok.setdefault(p.source_anchor, True)
        arrival_ok.setdefault(p.destination, True)

    # THE ENGINE'S OWN GEOMETRY, which every finished build appends: an
    # exit room with the portal in it, and the approach to it filed
    # under the reserved edge id. A payload without them is not one
    # `zone_builder` could have produced.
    far = max(z for _, z in centre.values()) + SPACING
    rooms["exit"] = {
        "position": [0.0, 0.0, far], "yaw": 0.0,
        "bounds": {"position": [-HALF_W, 0.0, far - DEPTH / 2],
                   "size": [HALF_W * 2, 5.0, DEPTH]}}
    tail = max((c.id for c in zone.chambers),
               key=lambda rid: centre[rid][1])
    tz = centre[tail][1] + DEPTH / 2
    joins["e:__exit__"] = {
        "room_a": tail, "room_b": "exit", "synthetic": True,
        "socket_a": [0.0, 0.0, tz], "socket_b": [0.0, 0.0, far],
        "chain": [corridor_piece([0.0, 0.0, tz], [0.0, 0.0, far])]}
    return {"status": "LAYOUT_OK", "rooms": rooms, "joins": joins,
            "anchors": anchors, "arrival_ok": arrival_ok,
            "apertures": apertures, "stations": stations,
            "packages": physics}


def certified_chain(room_id: str, index: int = 0,
                    zone_id: str = "z1") -> dict:
    """What the engine sends for one `powered_door` chain it built.

    Fabricated here the way `apertures` is: the engine measures and
    replays the real thing, and a fixture that could not produce a
    complete payload would be testing a Zone no build sends.
    `ChainCertificate` in the Godot lane is what produces it for real.
    """
    package = {
        "package_id": f"{room_id}_pd{index}",
        "latch_conditions": [{"latch_id": "plate_loaded",
                              "kind": "WEIGHT_THRESHOLD",
                              "detail": "plate >= 36.0000"}],
        "vector_latches": [], "required_latches": [],
        "on_mandatory_route": False,
        "setup": {
            "bodies": [{"body_id": "crate", "mass_kg": 60.0,
                        "constrained": False}],
            "solver": {"iterations": 8, "fixed_step_hz": 60.0,
                       "settle_timeout_s": 0.75},
            "scene_digest": "0123456789abcdef"},
        "reference_solution": {
            "steps": ["push crate 0.0000 1.0000 0.8000", "settle"]},
    }
    digest = _PHYS.package_digest(_PHYS.PhysicsPackage(**package))
    package["evidence"] = {
        "package_id": package["package_id"],
        "content_digest": digest,
        "provider_force_n": _PHYS.ENVELOPE_FORCE_N,
        "provider_range_m": _PHYS.ENVELOPE_RANGE_M,
        "provider_mass_kg": _PHYS.ENVELOPE_MASS_KG,
        "per_run_latched": [["plate_loaded"]] * 3,
    }
    return {
        "package_id": package["package_id"],
        "zone_id": zone_id,
        "room_id": room_id,
        "content_ref": "feature:powered_door",
        "package": package,
    }



async def _branching_zone(engine):
    """Generate until one is big enough to carry a branch."""
    for _ in range(3):
        await engine.handle_request_next_zone(False)
        await drain()
        zid = engine.save.active_zone_id
        zone = engine.save.zone_by_id(zid).zone
        if zone.plugs and any(k for c in zone.chambers for k in c.keys):
            return zid, zone
        await engine.handle_enter_zone(zid)
        await engine.handle_abandon_zone(zid)
    pytest.skip("no branching Zone generated in three attempts")


async def enter_zone(engine, zone_id: str) -> None:
    """Walk in the way the game does: enter, then send the layout.

    A graph Zone is ACTIVE the moment it is entered and UNCERTIFIED until
    its layout comes back, and `claim_zone_check` refuses a claim in that
    window. A Zone with no `edges` sends no layout and needs none, which
    is the pre-graph shape and is exempt on both sides.
    """
    from pydantic import TypeAdapter
    from archipepsi_bridge.schemas.protocol import ClientMessage

    await engine.handle_enter_zone(zone_id)
    record = engine.save.zone_by_id(zone_id)
    if record is None or record.zone is None or not record.zone.edges:
        return
    await engine.handle_layout_result(
        TypeAdapter(ClientMessage).validate_python(
            {"type": "layout_result", "zone_id": zone_id,
             "layout": place_layout(record.zone)}))
