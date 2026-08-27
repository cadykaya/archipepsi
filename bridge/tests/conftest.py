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
                           confirm_delay: float = 0.0):
    engine = make_engine(tmp_path, provider=provider)
    backend = MockAPBackend(engine, server_state=server_state,
                            confirm_delay=confirm_delay)
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
