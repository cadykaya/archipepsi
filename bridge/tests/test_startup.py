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


def test_the_requirements_installer_is_not_silently_disabled(monkeypatch):
    """`make setup` was broken on every fresh clone and worked here.

    The Makefile exports `SKIP_REQUIREMENTS_UPDATE=1` globally, and
    correctly: importing `CommonClient` runs `ModuleUpdate.update()`,
    which drops into a bare `input()` on a missing requirement, so every
    other entry point needs it. Inherited by the INSTALLER it made the one
    command whose job is installing requirements install nothing, and
    `make setup` then died at its own verify step with
    `ModuleNotFoundError: No module named 'yaml'` on any machine that did
    not already have them.

    CI found this on its first run against a real fresh checkout. This
    machine had the requirements pre-installed and could not.
    """
    import subprocess as _subprocess
    import sys as _sys
    from pathlib import Path as _Path

    _sys.path.insert(0, str(_Path(__file__).resolve().parents[1]))
    import bootstrap

    monkeypatch.setenv("SKIP_REQUIREMENTS_UPDATE", "1")
    captured = {}

    class _Result:
        returncode = 0

    def fake_run(cmd, cwd=None, env=None, **kwargs):
        captured["env"] = env or {}
        return _Result()

    monkeypatch.setattr(bootstrap.subprocess, "run", fake_run)
    bootstrap.install_ap_requirements(_Path("/tmp/does-not-matter"))

    assert "env" in captured, "the installer was never invoked"
    assert "SKIP_REQUIREMENTS_UPDATE" not in captured["env"], (
        "the requirements installer inherits the flag that turns it into "
        "a no-op; `make setup` will install nothing and then fail")
    # And the rest of the environment survives — clearing one variable
    # must not hand the installer an empty env.
    assert captured["env"].get("PATH"), (
        "the installer lost PATH; it needs the real environment minus "
        "one variable, not a blank one")
    _ = _subprocess


def test_a_second_bridge_says_so_in_words_rather_than_a_traceback(tmp_path):
    """The most likely error a player will ever hit, and the one Python
    explains worst.

    Starting the bridge twice -- almost always because the first one is
    still running in a window they forgot behind the game -- used to end
    in `OSError: [Errno 98] error while attempting to bind on address
    ('127.0.0.1', 38290)` under fifteen frames of asyncio. The launcher
    scripts `pause` on exit specifically so errors do not vanish with the
    window, which means that wall of red text is what a player sits and
    reads. It looks like the game is broken; it means "you already have
    one running".
    """
    import subprocess
    import sys

    port = TEST_PORT + 1

    async def scenario():
        holder = BridgeServer(_engine(tmp_path), ap_default="mock",
                              port=port)
        task = await _serve(holder)
        try:
            return subprocess.run(
                [sys.executable, "-m", "archipepsi_bridge", "--ap=mock",
                 "--epsilon=fallback", f"--port={port}",
                 f"--save-dir={tmp_path / 'second'}"],
                cwd=Path(__file__).resolve().parents[1],
                capture_output=True, text=True, timeout=60)
        finally:
            task.cancel()

    done = run(scenario())
    output = done.stdout + done.stderr

    assert done.returncode != 0, (
        "the second bridge bound nothing and still reported success")
    assert "Traceback" not in output, (
        "a traceback is what this test exists to prevent:\n" + output)
    assert "Errno" not in output, (
        "Python's own wording for the error leaked through:\n" + output)
    assert str(port) in output, (
        "the message must name the port, or a player cannot tell which "
        "of two bridges is the problem:\n" + output)
    # The message has to say what to DO, not merely what happened.
    assert "already" in output.lower(), output
    assert "--port=" in output, (
        "no way out is offered for someone who genuinely wants two "
        "bridges:\n" + output)

import types


# --- the banner says WHICH LEVEL, on the window that stays open ---------

class _Args:
    def __init__(self, ap="mock", mock_scale="default", epsilon="fallback"):
        self.ap = ap
        self.mock_scale = mock_scale
        self.epsilon = epsilon


class _FakeServer:
    host = "127.0.0.1"
    port = 38290


def _banner(args, provider_name, capsys, tmp_path) -> str:
    """What the bridge window ACTUALLY prints."""
    from archipepsi_bridge.__main__ import _announce

    engine = types.SimpleNamespace(save_dir=tmp_path)
    _announce(engine, _FakeServer(), provider_name, args)
    return capsys.readouterr().out


def test_the_banner_carries_the_zone_id_for_a_baseline_run(capsys, tmp_path):
    """`playtest check` prints the id too, in the LAUNCHER window,
    thirty lines above the instructions -- so it has scrolled away by
    the time anyone is playing, which is when they want it. The bridge
    window is up for the whole run.

    Asserted against the PRINTED BANNER, not against `_zone_line`.
    Testing the helper would pass with the call deleted from the banner,
    which is the whole failure this file keeps finding elsewhere: a
    guard that checks the part rather than the thing anybody sees.
    """
    from archipepsi_bridge.playtest import played_zone_digest

    out = _banner(_Args(), "fallback", capsys, tmp_path)
    assert played_zone_digest()["digest"] in out, out


def test_the_zone_id_is_absent_from_the_banner_when_it_would_be_a_lie(
        capsys, tmp_path):
    """The same assertion from the other side, and also on the banner."""
    from archipepsi_bridge.playtest import played_zone_digest

    digest = played_zone_digest()["digest"]
    assert digest not in _banner(_Args(ap="real"), "fallback", capsys,
                                 tmp_path)
    assert digest not in _banner(_Args(), "claude", capsys, tmp_path)


def test_the_banner_stays_quiet_when_the_id_would_be_a_lie():
    """Against a real server the Zone is a function of the seed, and
    against a live Epsilon of what the model said. An id computed here
    would describe a Zone nobody is going to walk, and a confident wrong
    id is worse than no id."""
    from archipepsi_bridge.__main__ import _zone_line

    assert _zone_line(_Args(ap="real"), "fallback") == ""
    assert _zone_line(_Args(), "claude") == ""


def test_the_banner_never_stops_the_bridge_starting(monkeypatch):
    """A convenience on a banner that can refuse to start the bridge is
    a worse trade than a missing line."""
    from archipepsi_bridge import __main__ as M

    def boom():
        raise RuntimeError("generation exploded")

    monkeypatch.setattr("archipepsi_bridge.playtest.played_zone_digest", boom)
    assert M._zone_line(_Args(), "fallback") == ""
