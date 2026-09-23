"""P5-14: the mock Archipelago room survives a bridge restart.

`MockServerState` said it was "truth that survives quit/reload/
reconnect" and it survived reconnects only: it lived in the bridge's
memory. So in a mock campaign -- which is what the diagnostic and
candidate launchers play -- quitting and relaunching made every
confirmed Check unchecked again: its pedestal was claimable, and
claiming it delivered its item a second time. The save deliberately
holds no copy of Archipelago's truth, so nothing else noticed.
`godot-candidate-live`'s `minor_restore` phase found it by asserting
that the minor's Check was still claimed after a restart.

The room is now kept beside the campaign's own save and resumed exactly
when that save is.
"""
from __future__ import annotations

from archipepsi_bridge.mock_ap import MockAPBackend, MockServerState
from archipepsi_bridge.schemas import constants as C

from .conftest import drain, make_engine, run


async def _bridge(save_dir):
    """What `server._connect_mock` does, in a fresh bridge process."""
    engine = make_engine(save_dir)
    backend = MockAPBackend.for_campaign(engine, config=C.DEFAULT_CONFIG)
    engine.backend = backend
    await backend.connect("", "Skyiah", "")
    await drain()
    return engine, backend


def _own_location(backend) -> int:
    return min(backend.placements)


def test_a_confirmed_check_is_still_confirmed_after_a_restart(tmp_path):
    async def go():
        engine, backend = await _bridge(tmp_path)
        loc = _own_location(backend)
        assert await backend.check_locations([loc]) == {loc}
        await drain()
        received = len(backend.data.received)
        assert loc in engine.ap.checked and received > 0
        # ...quit. Both processes new; only the save folder crosses.
        again, backend2 = await _bridge(tmp_path)
        assert loc in again.ap.checked, "the room forgot a confirmed Check"
        assert loc not in again.ap.missing
        assert len(backend2.data.received) == received
        return again, backend2, loc, received
    run(go())


def test_the_same_check_is_not_delivered_twice_after_a_restart(tmp_path):
    async def go():
        _engine, backend = await _bridge(tmp_path)
        loc = _own_location(backend)
        await backend.check_locations([loc])
        await drain()
        received = len(backend.data.received)
        _again, backend2 = await _bridge(tmp_path)
        # A second send of a checked location sends nothing and delivers
        # nothing -- the real room's already-checked answer.
        assert await backend2.check_locations([loc]) == set()
        await drain()
        assert len(backend2.data.received) == received
    run(go())


def test_a_new_campaign_never_inherits_an_old_room(tmp_path):
    """The room resumes only when its campaign's save does: a stale file
    beside no save is a fresh room."""
    async def go():
        engine, backend = await _bridge(tmp_path)
        loc = _own_location(backend)
        await backend.check_locations([loc])
        await drain()
        room = backend.server.path
        assert room is not None and room.is_file()
        for save in tmp_path.glob("*.json"):
            if save != room:
                save.unlink()
        fresh, _ = await _bridge(tmp_path)
        assert loc not in fresh.ap.checked
    run(go())


def test_an_unbound_room_is_still_memory_only(tmp_path):
    """Tests and harnesses that share a `MockServerState` in one process
    keep exactly the behaviour they had."""
    state = MockServerState(C.DEFAULT_CONFIG)
    state.checked.add(1)
    state.store()
    assert state.path is None and not list(tmp_path.iterdir())


def test_a_room_for_another_scale_is_not_resumed(tmp_path):
    path = tmp_path / "room.json"
    room = MockServerState.bound(path, C.DEFAULT_CONFIG, resume=False)
    room.checked.add(89100001)
    room.store()
    assert MockServerState.bound(path, C.DEFAULT_CONFIG,
                                 resume=True).checked == {89100001}
    assert MockServerState.bound(path, C.PROTOTYPE_CONFIG,
                                 resume=True).checked == set()
