"""D-01 — what a local Echo may never be (Dess, H-SELF-ECHO).

The owner accepted that a self-addressed original may also yield a local
Echo. The contract is `docs/D14_SELF_ADDRESSED_ECHO_PROD.md`. It rests
on three facts that hold today, pinned here so the integration cannot
quietly lose them:

  no clone      granting an Echo moves no Archipelago state: nothing is
                sent, nothing is received, no key or coin is counted.
                The original reaches its recipient once, through AP.
  one per Check an Echo is keyed by the Check that released the
                original, so a retry, a reload or a second confirmation
                answers "already granted" and mints nothing.
  legacy stays  a campaign saved before the policy existed never grows
                an Echo for its own items -- not on load, not on a
                later sweep. No silent compatibility change.

**Nothing here edits shared source.**
"""
from __future__ import annotations

from archipepsi_bridge import transactions
from archipepsi_bridge.schemas import protocol as P
from archipepsi_bridge.schemas import transitions as T

from archipepsi_bridge.mock_ap import MockAPBackend

from .conftest import connected_engine, drain, enter_zone, make_engine, run

#: The contract's per-campaign field (D14 §3). A save without it is a
#: legacy campaign.
POLICY_FIELD = "self_addressed_echoes"


#: A mock seed whose first Zone holds one of this slot's own items
#: (89100006). The default seed's first Zone holds none.
SELF_SEED = "MockSeed-3"


async def _in_a_zone(tmp_path, seed: str | None = None):
    if seed is None:
        engine, backend = await connected_engine(tmp_path)
    else:
        engine = make_engine(tmp_path)
        backend = MockAPBackend(engine, seed_name=seed)
        engine.backend = backend
        await backend.connect("", "Skyiah", "")
        await drain()
    await engine.handle_request_next_zone(False)
    await drain()
    zone_id = engine.save.active_zone_id
    await enter_zone(engine, zone_id)
    return engine, backend, zone_id


def _split(engine, zone_id):
    locs = engine.save.zone_by_id(zone_id).allocated_location_ids
    mine = [l for l in locs if engine.ap.scouts[l].recipient_is_self]
    theirs = [l for l in locs if not engine.ap.scouts[l].recipient_is_self]
    return mine, theirs


def _ap_state(engine, backend):
    return (len(engine.ap.received), engine.ap.signal_keys,
            engine.ap.coins_received, frozenset(engine.ap.checked),
            backend.server.delivered)


def _without_echo(save, echo_id):
    """The save as it was if the process died before the append."""
    return T._rebuild(save, interpretations=tuple(
        i for i in save.interpretations if i.echo_id != echo_id))


def test_granting_an_echo_moves_no_archipelago_state(tmp_path):
    """The reload path: a confirmed Check whose Echo was never written.
    The sweep grants it, and AP sees nothing -- no send, no delivery,
    no key or coin counted."""
    async def go():
        engine, backend, zone_id = await _in_a_zone(tmp_path)
        _, theirs = _split(engine, zone_id)
        assert theirs, "the mock seed placed no foreign item in this Zone"
        loc = theirs[0]
        await transactions.claim_check(engine, zone_id, loc)
        echo_id = f"echo_{loc}"
        assert engine.save.interpretation_by_id(echo_id) is not None
        engine.save = _without_echo(engine.save, echo_id)
        before = _ap_state(engine, backend)
        sends = []
        real_send = backend.check_locations
        async def spy(locations):
            sends.append(tuple(locations))
            return await real_send(locations)
        backend.check_locations = spy
        await engine.echo_backlog_sweep()
        assert engine.save.interpretation_by_id(echo_id) is not None, \
            "the sweep did not resume the lost grant"
        assert sends == [], "granting an Echo sent something to AP"
        assert _ap_state(engine, backend) == before, \
            "granting an Echo moved Archipelago state"
    run(go())


def test_one_check_mints_one_echo_however_often_it_is_asked(tmp_path):
    async def go():
        engine, _, zone_id = await _in_a_zone(tmp_path)
        _, theirs = _split(engine, zone_id)
        loc = theirs[0]
        await transactions.claim_check(engine, zone_id, loc)
        echo_id = f"echo_{loc}"
        seq = engine.save.next_interpretation_seq
        assert await engine.grant_echo(loc) == echo_id
        await engine.echo_backlog_sweep()
        echo = engine.save.interpretation_by_id(echo_id)
        engine.save = T.append_interpretation(engine.save, echo)
        assert [i.echo_id for i in engine.save.interpretations].count(
            echo_id) == 1, "one Check minted two Echoes"
        assert engine.save.next_interpretation_seq == seq
    run(go())


def test_a_legacy_campaign_mints_nothing_for_its_own_item(tmp_path):
    """A campaign saved without the policy keeps its behaviour: its own
    item is delivered to it, and no Echo appears -- at confirmation, on
    reload, or on any later sweep."""
    async def go():
        engine, _, zone_id = await _in_a_zone(tmp_path, SELF_SEED)
        mine, _ = _split(engine, zone_id)
        assert mine, "the mock seed placed no self-addressed item here"
        loc = mine[0]
        await transactions.claim_check(engine, zone_id, loc)
        assert loc in engine.ap.checked
        raw = engine.save.model_dump(mode="json")
        assert POLICY_FIELD in raw, "the policy field is gone from the save"
        raw.pop(POLICY_FIELD)
        engine.save = P.CampaignSave.model_validate(raw)
        before = len(engine.save.interpretations)
        assert await engine.grant_echo(loc) is None
        await engine.echo_backlog_sweep()
        assert engine.save.interpretation_by_id(f"echo_{loc}") is None, \
            "a legacy campaign grew an Echo for its own item"
        assert len(engine.save.interpretations) == before
    run(go())


def test_a_save_written_before_the_policy_loads_with_it_off(tmp_path):
    """D14 §3: the default is the legacy behaviour, so no existing save
    changes by loading it; only creation can turn it on."""
    async def go():
        engine, _, _ = await _in_a_zone(tmp_path)
        raw = engine.save.model_dump(mode="json")
        raw.pop(POLICY_FIELD)
        assert P.CampaignSave.model_validate(raw).self_addressed_echoes \
            is False
        on = P.CampaignSave.model_validate({**raw, POLICY_FIELD: True})
        again = P.CampaignSave.model_validate_json(on.model_dump_json())
        assert again.self_addressed_echoes is True
    run(go())
