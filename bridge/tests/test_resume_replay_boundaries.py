"""M-2 — replaying an unknown encounter duplicates nothing (Dess, H-RESUME-C).

The owner's ruling on the legacy-save decision (2026-09-24):

    "If an older save contains no evidence that an encounter member
    died, the current encounter is unknown: reconstruct it and resume
    the player from its safe arrival point rather than amid respawned
    enemies. However, replaying an unknown encounter must not duplicate
    any already-authorized one-shot AP Check, unique reward, key, or
    other monotone progression state."

The reconstruction itself -- every member built, the player at the
room's arrival -- is the engine's (`make godot-resume-live`). What these
hold is the other half: the authority a replayed room reaches through
again must answer "already done" instead of "done twice". Each case
drives the path the engine would actually take a second time, from a
Zone whose defeat record is unknown (`None`).

**Nothing here edits shared source.** These pin guards that already
exist, so a later change cannot quietly remove them.
"""

from __future__ import annotations

import pytest

from archipepsi_bridge import transactions
from archipepsi_bridge.schemas import constants as C
from archipepsi_bridge.schemas import protocol as P
from archipepsi_bridge.schemas import transitions as T

from .conftest import connected_engine, enter_zone, run


async def _in_a_zone(tmp_path):
    """A connected engine standing in the first Zone, layout accepted."""
    engine, backend = await connected_engine(tmp_path)
    await engine.handle_request_next_zone(False)
    from .conftest import drain
    await drain()
    zone_id = engine.save.active_zone_id
    await enter_zone(engine, zone_id)
    return engine, backend, zone_id


def _unknown(engine, zone_id) -> None:
    """Make this Zone's defeat record unknown, the way an older save is.

    Through the real rebuild primitive, so every validator runs: an
    older save IS a save whose record is `None`.
    """
    rec = engine.save.zone_by_id(zone_id)
    progress = rec.progress.model_copy(update={"defeated": None})
    engine.save = T._rebuild(engine.save, zones=T._replace_zone(
        engine.save, zone_id, progress=progress))
    assert engine.save.zone_by_id(zone_id).progress.defeated is None


def test_a_replayed_room_cannot_send_its_check_twice(tmp_path):
    """The room's Check was claimed and confirmed before the save. The
    reconstructed encounter is cleared again and the client claims
    again: nothing is sent, nothing new is pending, and nothing is
    delivered a second time."""
    async def go():
        engine, backend, zone_id = await _in_a_zone(tmp_path)
        loc = engine.save.zone_by_id(zone_id).allocated_location_ids[0]
        await transactions.claim_check(engine, zone_id, loc)
        assert loc in engine.ap.checked, "the first claim did not confirm"
        delivered = backend.server.delivered
        received = len(engine.ap.received)
        _unknown(engine, zone_id)

        sends = []
        real_send = backend.check_locations

        async def counted(ids):
            sends.append(list(ids))
            return await real_send(ids)
        backend.check_locations = counted

        await transactions.claim_check(engine, zone_id, loc)   # the replay
        assert sends == [], "an already-confirmed Check was sent again"
        assert all(p.location_id != loc for p in engine.save.pending_checks)
        assert backend.server.delivered == delivered
        assert len(engine.ap.received) == received
    run(go())


def test_a_replayed_room_cannot_collect_its_key_twice():
    """Keys are a one-way set on the Zone's progress, and `record_key`
    reaches the save only through it -- so the same key found again in
    a reconstructed room is the same key. Asserted on the set itself
    rather than on a generated Zone, because the first prototype Zone
    declares no key and a skipped case would prove nothing."""
    progress = P.ZoneProgress()
    once = progress.with_key("k_red")
    assert once.with_key("k_red") is once
    assert once.collected_keys == ("k_red",)


def test_a_replayed_room_cannot_grant_its_unique_reward_twice(tmp_path):
    async def go():
        engine, _, zone_id = await _in_a_zone(tmp_path)
        reward = P.EarnedLocalReward.model_validate({
            "reward_id": "note_replay", "kind": "epsilon_note",
            "display_name": "A note", "source_zone_id": zone_id})
        once = T.grant_local_reward(engine.save, reward)
        twice = T.grant_local_reward(once, reward)
        assert twice is once, "the same unique reward was granted twice"
    run(go())


def test_the_defeat_record_holds_the_largest_legal_roster():
    """A member defeated in the biggest legal Zone must still be
    recordable: forty rooms at the per-chamber cap. If either cap rises
    past the record's bound, a legitimate defeat would be refused on
    save -- which is a replay waiting to happen."""
    field = P.ZoneProgress.model_fields["defeated"]
    bound = next(m.max_length for m in field.metadata
                 if getattr(m, "max_length", None) is not None)
    roster = C.ZONE_MAX_CHAMBERS * C.MAX_ENEMIES_PER_CHAMBER
    assert roster <= bound, (
        f"a legal Zone can declare {roster} members and the record holds "
        f"{bound}")
