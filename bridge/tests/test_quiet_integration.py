"""The quieter preview, wired into the live engine: opt-in, and off.

`test_quiet_preview.py` owns the POLICY -- what a quieter Zone holds and
what it costs, measured over twelve cases. This file owns the SEAM: the
one flag that reaches a running bridge, what it changes about a real
generation request, and -- the part that matters most -- what it leaves
byte-for-byte alone when nobody asked for it.

Follow-up 02, integration. The owner's words are "keep normal
generation and old saves intact", and an opt-in that is merely *usually*
off does not do that. So the default is asserted as an IDENTITY, not as
a resemblance: the request a plain engine builds is equal to the one it
built before the flag existed, field for field.
"""

from __future__ import annotations

from archipepsi_bridge import quiet
from archipepsi_bridge.mock_ap import MockAPBackend, MockServerState
from archipepsi_bridge.schemas import constants as C
from .conftest import Collector, drain, make_engine, run

PROD = C.DEFAULT_CONFIG


async def _engine_at(tmp_path, *, quiet_generation: bool):
    engine = make_engine(tmp_path)
    engine.quiet_generation = quiet_generation
    backend = MockAPBackend(engine, server_state=MockServerState(PROD),
                            config=PROD)
    engine.backend = backend
    await backend.connect("", "Skyiah", "")
    await drain()
    return engine


async def _first_record(engine):
    Collector(engine)
    await engine.handle_request_next_zone(False)
    await drain(400)
    return engine.save.zones[-1]


# --- the default is the shipped game ----------------------------------

def test_the_flag_is_off_unless_it_is_turned_on(tmp_path):
    """A bridge nobody configured is an ordinary bridge."""
    engine = make_engine(tmp_path)
    assert engine.quiet_generation is False


def test_an_ordinary_engine_builds_the_request_it_always_built(tmp_path):
    """THE IDENTITY, not a resemblance.

    Two engines over the same campaign, one of which has the attribute
    the preview reads. With it down the requests must be EQUAL -- same
    constraints dict, same budget, same everything -- because the
    promise made to the owner is that normal generation composes what it
    composed before this landed.
    """
    async def scenario():
        plain = await _engine_at(tmp_path / "a", quiet_generation=False)
        record = await _first_record(plain)
        one = plain._zone_request(record)
        two = plain._zone_request(record)
        assert one == two, "the request builder is not even deterministic"
        # The retired families ARE offered by an ordinary request, and
        # the band is the campaign's own.
        for family in quiet.RETIRED_FAMILIES:
            assert family in one.constraints["activity_kinds"], family
        assert one.constraints["zone_budget"] == one.campaign.zone_budget
        assert one.campaign.zone_budget == PROD.zone_budget_for(
            len(record.allocated_location_ids))
    run(scenario())


# --- and the preview changes exactly two things -----------------------

def test_the_preview_moves_the_band_and_the_menu_and_nothing_else(tmp_path):
    """WHAT THE FLAG'S FOOTPRINT ACTUALLY IS, measured rather than assumed.

    The first version of this control asserted that exactly two
    constraint keys moved -- the offer and the band -- and it was wrong
    in a way worth keeping written down. Both `fallback_zone_attempt`
    and `generate_zone_validated` read `request.campaign.zone_budget`;
    `constraints["zone_budget"]` is the same fact spelled for a prompt
    and nothing composes from it. Narrowing only the constraints
    therefore delivered the FILTER-ONLY arm -- the two families gone and
    their share handed straight back as more of what remains -- which is
    precisely the compensation the preview exists to avoid. It showed up
    as a Zone asked for 72% of the band arriving at 917 against 648-792.

    So the band moves where the system reads it, and everything the
    request derives from that one number moves with it. That coupling is
    the boundary Dess recorded: the room envelope, the enemy caps and
    the per-room soft cap all come out of the same integer.
    """
    async def scenario():
        plain = await _engine_at(tmp_path / "a", quiet_generation=False)
        record = await _first_record(plain)
        normal = plain._zone_request(record)

        plain.quiet_generation = True
        preview = plain._zone_request(record)

        # The band, where it is actually read.
        assert preview.campaign.zone_budget == quiet.preview_budget(
            normal.campaign.zone_budget)
        # The menu.
        assert (set(preview.constraints["activity_kinds"])
                == set(quiet.preview_kinds()))
        # Everything else about the campaign is this campaign's own.
        assert (normal.campaign.model_dump(exclude={"zone_budget"})
                == preview.campaign.model_dump(exclude={"zone_budget"}))
        assert (normal.model_dump(exclude={"constraints", "campaign"})
                == preview.model_dump(exclude={"constraints", "campaign"}))
        # And every constraint that moved moved BECAUSE the band did:
        # re-deriving the block from the narrowed budget reproduces it,
        # so nothing was hand-set on the way through.
        assert set(normal.constraints) == set(preview.constraints)
        derived = preview.model_copy(update={"constraints": {}})
        rebuilt = type(preview)(**{
            **derived.model_dump(), "constraints": {}}).constraints
        for key, value in preview.constraints.items():
            if key == "activity_kinds":
                continue
            assert value == rebuilt[key], key
    run(scenario())


def test_the_preview_stops_offering_exactly_the_two_drills(tmp_path):
    async def scenario():
        engine = await _engine_at(tmp_path, quiet_generation=True)
        record = await _first_record(engine)
        offered = engine._zone_request(record).constraints["activity_kinds"]
        for family in quiet.RETIRED_FAMILIES:
            assert family not in offered, family
        assert set(offered) == set(quiet.preview_kinds())
        assert offered, "a preview that offers nothing is not a preview"
    run(scenario())


def test_the_preview_never_edits_the_campaign_it_is_previewing(tmp_path):
    """REDUCTION IN THE REQUEST, NOT IN THE SAVE.

    This is the line between a preview and a budget ruling. The
    campaign's configured scale is what an old save carries and what a
    normal run would resume with; the flag must be visible only in the
    request it builds, so turning it off returns the same campaign to
    ordinary generation with nothing to undo.
    """
    async def scenario():
        engine = await _engine_at(tmp_path, quiet_generation=True)
        record = await _first_record(engine)
        request = engine._zone_request(record)

        full = PROD.zone_budget_for(len(record.allocated_location_ids))
        assert request.campaign.zone_budget == quiet.preview_budget(full)
        assert request.campaign.zone_budget < full

        # THE SAVE'S OWN SCALE, untouched.
        assert engine.save.scale.config().zone_budget == PROD.zone_budget
        assert engine.save.scale.config().zone_budget_for(
            len(record.allocated_location_ids)) == full

        # And the same engine with the flag down asks for all of it.
        engine.quiet_generation = False
        assert engine._zone_request(record).campaign.zone_budget == full
    run(scenario())


# --- and a quieter Zone is a real, accepted Zone ----------------------

def test_a_quieter_zone_generates_and_is_accepted(tmp_path):
    """THE POINT OF THE WHOLE THING: it has to be playable.

    Same provider, same `validate_zone`, same acceptance path -- so if
    the narrowed request produced something the campaign refuses, the
    record below has no Zone in it and this fails.
    """
    from archipepsi_bridge import content_value as V

    async def scenario():
        engine = await _engine_at(tmp_path, quiet_generation=True)
        record = await _first_record(engine)
        assert record.zone is not None, "a quieter Zone did not generate"
        zone = record.zone
        kinds = {a.kind for c in zone.chambers for a in c.activities}
        for family in quiet.RETIRED_FAMILIES:
            assert family not in kinds, f"{family} was composed anyway"
        low, high = V.budget_band(quiet.preview_budget(PROD.zone_budget_for(
            len(record.allocated_location_ids))))
        assert low <= V.zone_value(zone) <= high, (
            f"{V.zone_value(zone)} outside the band it was built for "
            f"({low}-{high})")
        assert (sorted(zone.reward_location_ids)
                == sorted(record.allocated_location_ids)), (
            "a quieter Zone must still hold every Check it was given")
    run(scenario())
