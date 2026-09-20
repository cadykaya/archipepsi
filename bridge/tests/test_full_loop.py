"""The whole campaign loop, with the layout CERTIFIED the way the game
certifies it.

**This coverage used to live in `archipepsi_bridge.smoke`, and could not
stay there.** `claim_zone_check` refuses a Check against geometry the
bridge has not validated — correctly; it is the rule that stops a client
playing a Zone whose layout the validator rejected. `smoke.py` is
bridge-only: no Godot, no client, so nothing ever sends a
`layout_result` and no Zone is ever certified. The smoke had asserted
claim, Echo, equip, reload-identity and a second generation, and every
one of those needs an accepted layout, so the command failed at its
first claim from the day that guard landed.

The answer is not to weaken the guard, and not to teach the shipped
package to fabricate geometry — validation must not construct gameplay
(F-4). It is to run this half where an accepted layout is available
through the REAL handler: `conftest.enter_zone` walks in the way the
game does, entering and then sending a layout that
`engine.handle_layout_result` validates like any other. What is asserted
below is what the smoke asserted, unchanged.

**WHAT THIS IS AND IS NOT, said plainly so nobody reads it as more.**
The HANDLER is real and the VALIDATOR is real — this layout goes through
`handle_layout_result` and `layout.validate`, and a manifest they would
refuse is refused here. The EVIDENCE is synthetic: `conftest.place_layout`
lays rooms 50 m apart with fabricated join chains and no physics behind
any of it, because a test process has no engine to measure geometry with.
So this covers the CAMPAIGN loop — claim, Echo, equip, persistence — over
a layout the bridge accepts. It covers nothing about whether real
geometry holds together.

**The physical and live half is `make godot-integration`**: a real Godot
client measuring real collision, certifying real chains, against a live
bridge, driven to `ALL_CHECKS_CLEARED`. Neither test substitutes for the
other, and a change that breaks geometry will pass here and fail there.

`smoke.py` keeps the half it can honestly do, and asserts the refusal
this file's certification avoids. The two are complements, and both say
so.
"""

from __future__ import annotations

import archipepsi_bridge.transactions as TX

from .conftest import connected_engine, drain, enter_zone, make_engine, run
from archipepsi_bridge.mock_ap import MockAPBackend, MockServerState


async def _generate_and_enter(engine):
    await engine.handle_request_next_zone(False)
    await engine._generation_task
    await drain()
    snap = engine.snapshot()
    assert snap.hub.mode == "ZONE_READY", snap.hub.mode
    zone = snap.active_zone
    await enter_zone(engine, zone.zone_id)
    await drain()
    assert engine.snapshot().hub.mode == "ZONE_ACTIVE"
    return zone


def test_the_full_loop_claims_echoes_equips_and_survives_a_reload(tmp_path):
    async def body():
        server_state = MockServerState()
        engine, backend = await connected_engine(
            tmp_path, server_state=server_state)

        snap = engine.snapshot()
        assert snap.ap_connected and len(snap.scouted) == 30, "scout failed"
        assert snap.hub.mode == "ZONE_AVAILABLE", snap.hub.mode

        zone = await _generate_and_enter(engine)

        # CLAIM EVERY CHECK. This is the line the smoke died on, and it
        # runs here because the layout above was validated rather than
        # skipped.
        for loc in zone.allocated_location_ids:
            await TX.claim_check(engine, zone.zone_id, loc)
            await drain()
        snap = engine.snapshot()
        assert not snap.pending_checks, "pending checks left over"
        assert snap.completed_zone_count == 1, "zone did not auto-complete"
        assert snap.hub.mode in ("ZONE_AVAILABLE", "WAITING_FOR_AP"), \
            snap.hub.mode

        # ONE ECHO PER FOREIGN CHECK, AND NOT ONE PER CHECK. A Check that
        # resolves to this slot's own item interprets nothing.
        foreign = [loc for loc in zone.allocated_location_ids
                   if not backend.data.scouts[loc].recipient_is_self]
        assert len(snap.interpretations) == len(foreign), (
            f"{len(foreign)} foreign checks but "
            f"{len(snap.interpretations)} interpretations")

        actions = snap.mechanics.actions
        if actions:
            first = actions[0]
            await engine.handle_slot_action(
                first.component.slot, first.component_id)
            assert dict(engine.snapshot().slots.assigned())[
                first.component.slot] == first.component_id

        before = engine.snapshot()

        # QUIT AND RELOAD: fresh engine, same save dir, same mock server
        # truth. Nothing may be counted twice on the way back in.
        engine2 = make_engine(tmp_path)
        backend2 = MockAPBackend(engine2, server_state=server_state)
        engine2.backend = backend2
        await backend2.connect("", "Skyiah", "")
        await drain()
        after = engine2.snapshot()

        assert after.coins_received == before.coins_received, \
            "coins duplicated"
        assert after.coins_spent == before.coins_spent
        assert len(after.interpretations) == len(before.interpretations), \
            "interpretations duplicated"
        assert after.slots == before.slots
        # The fold survives the round trip too: same log, same mechanics.
        assert after.mechanics == before.mechanics
        assert after.completed_zone_count == 1
        assert len(after.checked_location_ids) == \
            len(before.checked_location_ids)

        # AND THE LOOP CONTINUES AFTER THE RELOAD, with what the campaign
        # has already interpreted in the next request's context.
        await engine2.handle_request_next_zone(False)
        await engine2._generation_task
        await drain()
        snap = engine2.snapshot()
        assert snap.hub.mode == "ZONE_READY"
        assert len(snap.interpretations) == len(before.interpretations)

    run(body())
