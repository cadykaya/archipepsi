"""D-22 slice: the Forge's two choices, and the Archipelago rules they keep.

`docs/D22_SLICE_BRIEF.md` §5 and §6.A items 1, 3 and 6, on the bridge:

* the Forge lists only signals with eligible Checks, and a chosen signal
  draws its Checks first, topping up exactly as today when it is short;
* a signal with nothing eligible (or no such signal) is refused;
* a REDRAW keeps the same `allocated_location_ids`, gives a different
  draft, re-proves it, stops at two, and is refused once the Crossing has
  been entered;
* a draft left open survives a restart unchanged;
* the cursor still advances only on completion.
"""
from __future__ import annotations

import pytest

from archipepsi_bridge.campaign import IntentError
from archipepsi_bridge.mock_ap import MockServerState
from archipepsi_bridge.schemas.protocol import MAX_REDRAWS
from archipepsi_bridge.schemas.zone import validate_zone

from .conftest import connected_engine as _connected_engine
from .conftest import drain, enter_zone, run


async def connected_engine(tmp_path, **kwargs):
    """A connected engine with the slice switched on (`--d22-slice`)."""
    engine, backend = await _connected_engine(tmp_path, **kwargs)
    engine.d22_slice = True
    return engine, backend


def _chambers(record) -> list[str]:
    """The draft's whole chamber list, as data: kinds, shells, sizes,
    enemies, activities and features all count as a different draft."""
    return [c.model_dump_json(exclude={"reward_location_id",
                                       "additional_reward_location_ids"})
            for c in record.zone.chambers]


async def _generated(engine):
    await engine._generation_task
    await drain()
    record = engine.save.active_zone
    assert record is not None and record.state == "GENERATED"
    return record


def test_the_forge_lists_only_signals_with_eligible_checks(tmp_path):
    async def scenario():
        engine, _ = await connected_engine(tmp_path)
        forge = engine.snapshot().forge
        by_track = engine._eligible_by_track()
        assert forge.signals, "no signal offered on a fresh campaign"
        assert {s.track for s in forge.signals} == {
            t for t, ids in by_track.items() if ids}
        for signal in forge.signals:
            assert signal.eligible == len(by_track[signal.track]) > 0
        # The cursor's own pick is pre-selected.
        _, cursor_pick = engine._select_zone_locations()
        assert forge.default_track == cursor_pick
    run(scenario())


def test_a_chosen_signal_draws_its_own_checks_first(tmp_path):
    async def scenario():
        engine, _ = await connected_engine(tmp_path)
        by_track = engine._eligible_by_track()
        cursor = engine.save.track_cursor
        _, default = engine._select_zone_locations()
        others = [t for t, ids in by_track.items() if ids and t != default]
        assert others, "the mock world offers only one signal"
        chosen = max(others, key=lambda t: len(by_track[t]))
        await engine.handle_request_next_zone(False, chosen)
        record = await _generated(engine)
        ids = list(record.allocated_location_ids)
        want = engine.save.scale.config().zone_target_checks
        if len(by_track[chosen]) >= want:
            assert set(ids) <= set(by_track[chosen])
        else:
            assert set(by_track[chosen]) <= set(ids)
        assert record.target_game == chosen
        # Allocation does not move the cursor; only completion does.
        assert engine.save.track_cursor == cursor
    run(scenario())


def test_a_short_signal_is_topped_up_exactly_as_today(tmp_path):
    async def scenario():
        engine, _ = await connected_engine(tmp_path)
        config = engine.save.scale.config()
        by_track = engine._eligible_by_track()
        short = [t for t, ids in by_track.items()
                 if 0 < len(ids) < config.zone_min_checks]
        if not short:
            pytest.skip("this mock world has no signal shorter than the "
                        "minimum, so nothing to top up")
        ids, target = engine._select_zone_locations(short[0])
        assert target == short[0]
        assert set(by_track[short[0]]) <= set(ids)
        assert len(ids) >= config.zone_min_checks
    run(scenario())


def test_an_empty_or_unknown_signal_is_refused(tmp_path):
    async def scenario():
        engine, _ = await connected_engine(tmp_path)
        with pytest.raises(IntentError):
            await engine.handle_request_next_zone(False, "No Such Game")
        assert engine.save.active_zone is None
        assert engine.hub_status().mode == "ZONE_AVAILABLE"
    run(scenario())


def test_a_redraw_keeps_the_checks_and_changes_the_draft(tmp_path):
    async def scenario():
        engine, _ = await connected_engine(tmp_path)
        await engine.handle_request_next_zone(False)
        first = await _generated(engine)
        ids = first.allocated_location_ids
        drafts = [_chambers(first)]
        assert engine.snapshot().forge.redraws_left == MAX_REDRAWS
        for n in range(1, MAX_REDRAWS + 1):
            await engine.handle_redraw_zone(first.zone_id)
            assert engine.save.active_zone.state == "PENDING_GENERATION"
            again = await _generated(engine)
            assert again.allocated_location_ids == ids, "a redraw moved a Check"
            assert again.redraw_count == n
            drafts.append(_chambers(again))
            # Re-proved: the stored Zone validates against the same ids.
            validate_zone(again.zone, expected_zone_id=again.zone_id,
                          allocated_location_ids=list(ids),
                          owned_echo_ids=[], owned_affordance_tags=[],
                          zone_budget=engine.save.scale.config()
                          .zone_budget_for(len(ids)))
            assert engine.snapshot().forge.redraws_left == MAX_REDRAWS - n
        assert len({tuple(d) for d in drafts}) == len(drafts), (
            "a redraw produced the same draft")
        with pytest.raises(IntentError):
            await engine.handle_redraw_zone(first.zone_id)
        assert engine.save.active_zone.redraw_count == MAX_REDRAWS
    run(scenario())


def test_a_redraw_after_the_first_entry_is_refused(tmp_path):
    async def scenario():
        engine, _ = await connected_engine(tmp_path)
        await engine.handle_request_next_zone(False)
        record = await _generated(engine)
        await enter_zone(engine, record.zone_id)
        await drain()
        with pytest.raises(IntentError):
            await engine.handle_redraw_zone(record.zone_id)
        # Left early, it is DORMANT, still holding its Checks, and still
        # cannot be redrawn.
        await engine.handle_exit_zone(record.zone_id)
        await drain()
        dormant = engine.save.zone_by_id(record.zone_id)
        assert dormant.state == "DORMANT"
        assert dormant.allocated_location_ids == record.allocated_location_ids
        assert engine.snapshot().forge.resume.zone_id == record.zone_id
        with pytest.raises(IntentError):
            await engine.handle_redraw_zone(record.zone_id)
    run(scenario())


def test_a_draft_left_open_is_the_same_draft_after_a_restart(tmp_path):
    async def scenario():
        state = MockServerState()
        engine, backend = await connected_engine(tmp_path,
                                                 server_state=state)
        await engine.handle_request_next_zone(False)
        await _generated(engine)
        await engine.handle_redraw_zone(engine.save.active_zone.zone_id)
        before = await _generated(engine)
        engine2, _ = await connected_engine(tmp_path, server_state=state)
        after = engine2.save.active_zone
        assert after.state == "GENERATED"
        assert after.redraw_count == 1
        assert _chambers(after) == _chambers(before)
        assert after.zone.display_name == before.zone.display_name
    run(scenario())


def test_without_the_slice_flag_nothing_changes(tmp_path):
    """No flag: no Forge view, no signal choice, no redraw, and a snapshot
    and a save that serialize exactly as before the slice existed."""
    async def scenario():
        engine, _ = await _connected_engine(tmp_path)
        assert engine.d22_slice is False
        snap = engine.snapshot()
        assert snap.forge is None
        assert '"forge"' not in snap.model_dump_json()
        with pytest.raises(IntentError):
            await engine.handle_request_next_zone(
                False, engine._select_zone_locations()[1])
        await engine.handle_request_next_zone(False)
        record = await _generated(engine)
        assert '"redraw_count"' not in record.model_dump_json()
        with pytest.raises(IntentError):
            await engine.handle_redraw_zone(record.zone_id)
    run(scenario())
