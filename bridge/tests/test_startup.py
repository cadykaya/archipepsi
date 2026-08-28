"""What a human actually does on a fresh clone, in the order they do it.

Every other suite here tests a subsystem in isolation, which is the right
way to find a bug and the wrong way to find out that the game will not
start. This one walks the launch path: the bridge comes up, Godot's
protocol handshake succeeds, a campaign is created where the banner said
it would be, and the offline fixture campaign plays without a server.

The failures it exists to catch are the ones that cost a playtest session
rather than a debugging session — a bridge that binds nothing, a
handshake that changed shape, a save written somewhere nobody looks, a
provider that silently is not the one requested.
"""

from __future__ import annotations

import asyncio
import json
import tempfile
from pathlib import Path

import pytest
import websockets

from archipepsi_bridge import BRIDGE_VERSION
from archipepsi_bridge.campaign import CampaignEngine
from archipepsi_bridge.epsilon import make_provider
from archipepsi_bridge.schemas import constants as C
from archipepsi_bridge.server import BridgeServer
from archipepsi_bridge.store import DEFAULT_SAVE_DIR

from .conftest import run

#: Away from the real ports, so a developer with a bridge already running
#: does not get a confusing failure here.
TEST_PORT = C.BRIDGE_PORT + 40


def _engine(save_dir: Path, provider: str = "fallback") -> CampaignEngine:
    return CampaignEngine(provider=make_provider(provider),
                          provider_name=provider, save_dir=save_dir)


async def _serve(server: BridgeServer):
    task = asyncio.create_task(server.serve_forever())
    for _ in range(50):                       # up to 5s for the bind
        await asyncio.sleep(0.1)
        try:
            async with websockets.connect(
                    f"ws://127.0.0.1:{server.port}"):
                return task
        except OSError:
            continue
    task.cancel()
    raise AssertionError(f"bridge never accepted a connection on "
                         f"{server.port}")


def test_the_bridge_comes_up_and_greets_the_client(tmp_path):
    """The first thing that happens on launch, and the first thing that
    can go wrong: Godot connects and reads a `bridge_ready`."""
    async def scenario():
        server = BridgeServer(_engine(tmp_path), ap_default="mock",
                              port=TEST_PORT)
        task = await _serve(server)
        try:
            async with websockets.connect(
                    f"ws://127.0.0.1:{TEST_PORT}") as ws:
                hello = json.loads(await asyncio.wait_for(ws.recv(), 5))
            assert hello["type"] == "bridge_ready", hello
            assert hello["bridge_version"] == BRIDGE_VERSION, (
                "the client checks this; a mismatch is a refusal to play")
        finally:
            task.cancel()
    run(scenario())


def test_mock_campaign_plays_without_a_server(tmp_path):
    """The MOCK CAMPAIGN button, which is the path a human takes when
    they want to see the game and not set up Archipelago. It must need no
    network and no seed."""
    from archipepsi_bridge.mock_ap import MockAPBackend
    from archipepsi_bridge import transactions as TX

    async def scenario():
        engine = _engine(tmp_path)
        backend = MockAPBackend(engine)
        engine.backend = backend
        await backend.connect("", "Skyiah", "")
        for _ in range(30):
            await asyncio.sleep(0)

        assert engine.save is not None, "no campaign after MOCK CAMPAIGN"
        assert engine.hub_status().mode == "ZONE_AVAILABLE", (
            f"the Hub offers nothing to do: {engine.hub_status().mode}")

        # And one Zone actually plays, which is the whole point.
        await engine.handle_request_next_zone(False)
        if engine._generation_task is not None:
            await engine._generation_task
        zone = engine.save.active_zone
        assert zone is not None and zone.zone is not None, (
            "the mock campaign generated no Zone")
        await engine.handle_enter_zone(zone.zone_id)
        for loc in zone.allocated_location_ids:
            await TX.claim_check(engine, zone.zone_id, loc)
        for _ in range(40):
            await asyncio.sleep(0)
        assert engine.save.completed_zone_count >= 1
        assert engine.save.interpretations, (
            "a completed Zone granted no Echoes; the premise did not fire")
    run(scenario())


def test_the_campaign_lands_where_the_banner_says_it_will(tmp_path):
    """The save path a human is told about has to be the one used. This is
    the footgun the banner exists for: `DEFAULT_SAVE_DIR` is
    cwd-relative, so the same command from two directories is two
    campaigns."""
    from archipepsi_bridge.mock_ap import MockAPBackend

    async def scenario():
        engine = _engine(tmp_path)
        assert Path(engine.save_dir) == tmp_path
        backend = MockAPBackend(engine)
        engine.backend = backend
        await backend.connect("", "Skyiah", "")
        for _ in range(30):
            await asyncio.sleep(0)
        written = list(tmp_path.glob("*.json"))
        assert written, f"no save under {tmp_path}"
        assert engine._save_path in written
    run(scenario())


def test_the_default_save_directory_is_relative_to_where_you_start():
    """Pinned, not fixed. It is documented behaviour and the banner prints
    the resolved path every launch; this asserts the two agree so the
    banner cannot start lying."""
    import os
    assert DEFAULT_SAVE_DIR == Path(
        os.environ.get("ARCHIPEPSI_SAVE_DIR", Path.cwd() / "saves"))


@pytest.mark.parametrize("requested", ["fallback", "mock"])
def test_the_provider_you_ask_for_is_the_one_you_get(requested):
    """A provider that silently is not the one requested makes every Echo
    look like a bug in the Echo system."""
    engine = _engine(Path(tempfile.mkdtemp()), requested)
    assert engine.provider_name == requested
    assert engine.provider.name == requested


def test_asking_for_claude_without_a_key_downgrades_loudly(monkeypatch,
                                                          caplog):
    """The one configuration mistake most likely on a first run. It must
    not fail, and it must not be silent — a player whose Echoes all read
    flat has to be able to find out why."""
    import logging as _logging
    from archipepsi_bridge.__main__ import resolve_provider_name

    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    with caplog.at_level(_logging.WARNING):
        assert resolve_provider_name("claude") == "fallback"
    assert any("EPSILON DOWNGRADE" in r.message for r in caplog.records), (
        "the downgrade happened silently")

    monkeypatch.setenv("ANTHROPIC_API_KEY", "sk-test-not-a-real-key")
    assert resolve_provider_name("claude") == "claude", (
        "a key is present and claude was still refused")
    # The deterministic providers are never downgraded.
    assert resolve_provider_name("fallback") == "fallback"
    assert resolve_provider_name("mock") == "mock"


def test_a_missing_archipelago_checkout_says_what_to_run(monkeypatch):
    """`--ap=real` on a clone where `make setup` was never run. The player
    sees this message in the game, so it has to name the fix."""
    from archipepsi_bridge import ap_client

    monkeypatch.setattr(ap_client, "_ap_imported", False)
    monkeypatch.setattr(ap_client, "_candidate_ap_roots",
                        lambda: ["/nonexistent/archipelago"])
    with pytest.raises(RuntimeError) as caught:
        ap_client.ensure_ap_importable()
    message = str(caught.value)
    assert "make setup" in message, message
    assert "ARCHIPELAGO_ROOT" in message, message
