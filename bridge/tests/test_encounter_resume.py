"""An encounter resumes as it was left (H-RESUME-R, owner ruling D-06).

    "Going forward, ordinary quit/reload should preserve encounter state.
    Enemies I killed stay dead; a partially cleared encounter restores the
    enemies that were still alive. Reloading is not an encounter-reset
    event. For an older save that has no per-enemy persistence data, do
    not guess that enemies were killed [...] no fabricated cleared rooms,
    but also absolutely no legacy-save ambushes."

The bridge's half is the RECORD: which declared members the player has
defeated, by a stable identity, validated against the Zone's own
declaration, monotone and idempotent. What the engine does with it -- a
defeated member never built, the resumed player never put among the
living -- is proved through two real processes by `make
godot-resume-live`; these tests hold the record itself.

**What the identity is.** `room/archetype#n`: the n-th spawn of that
archetype in that room's declared `enemies`, counted in declaration
order, which is the order every room builder lays them out in. It is
derived from the declaration alone -- never an engine node path, and
nothing about a live enemy is saved.

**What `None` means.** Not "nobody". A Zone whose save predates this
record, and whose encounter state is therefore unknown.
"""

from __future__ import annotations

import json

import pytest
from pydantic import TypeAdapter, ValidationError

from archipepsi_bridge.schemas import constants as C
from archipepsi_bridge.schemas import protocol as P
from archipepsi_bridge.schemas import transitions as T
from archipepsi_bridge.schemas.protocol import ClientMessage, ZoneProgress

from .conftest import connected_engine, drain, enter_zone, run

_ADAPTER = TypeAdapter(ClientMessage)


def _members(zone) -> list[str]:
    """Every member THIS Zone declares, in the identity the engine sends.

    Read off the Zone rather than hardcoded: a test that invents an
    identity passes while recording something the Zone never had.
    """
    out = []
    for chamber in zone.chambers:
        seen: dict[str, int] = {}
        for group in chamber.enemies:
            for _ in range(group.count):
                n = seen.get(group.archetype, 0)
                seen[group.archetype] = n + 1
                out.append(f"{chamber.id}/{group.archetype}#{n}")
    return out


def _live(engine):
    return engine.save.zone_by_id(engine.save.active_zone_id)


async def _entered(tmp_path):
    engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
    await engine.handle_request_next_zone(False)
    await drain()
    zone_id = engine.save.active_zone_id
    await enter_zone(engine, zone_id)
    return engine, zone_id


def _defeat(zone_id: str, member: str):
    return _ADAPTER.validate_python(
        {"type": "enemy_defeated", "zone_id": zone_id, "member": member})


# --- the record ------------------------------------------------------------

def test_no_record_is_unknown_not_nobody():
    """A Zone with no record is UNKNOWN; `()` is "known, nobody fell"."""
    assert ZoneProgress().defeated is None
    first = ZoneProgress().with_defeated("c005/bulwark#0")
    assert first.defeated == ("c005/bulwark#0",)


def test_defeats_only_ever_grow_and_a_repeat_is_one_defeat():
    once = ZoneProgress().with_defeated("c005/bulwark#0") \
        .with_defeated("c011/diver#3")
    twice = once.with_defeated("c005/bulwark#0")
    assert once == twice, "the same defeat reported twice is one defeat"
    assert once.defeated == ("c005/bulwark#0", "c011/diver#3")


def test_an_older_save_without_the_record_loads_as_unknown():
    """The JSON an older bridge wrote has no `defeated` key at all."""
    old = ZoneProgress().model_dump(mode="json")
    del old["defeated"]
    assert ZoneProgress.model_validate(old).defeated is None
    kept = ZoneProgress().with_defeated("c005/bulwark#1")
    again = ZoneProgress.model_validate(json.loads(
        json.dumps(kept.model_dump(mode="json"))))
    assert again.defeated == ("c005/bulwark#1",)


def test_the_record_is_room_persistent():
    """§5.1: every saved field declares its category, and this one is the
    room's own fact, like a lock opened."""
    assert P.SAVE_FIELD_CATEGORY["defeated"] == "ROOM_PERSISTENT"


@pytest.mark.parametrize("bad", [
    "c005/bulwark",          # no ordinal
    "c005#0",                # no archetype
    "C005/bulwark#0",        # not the id alphabet
    "c005/bulwark#-1",
    "../bulwark#0",
    "c005/bulwark#0/extra",
])
def test_a_malformed_identity_never_parses(bad):
    with pytest.raises(ValidationError):
        _defeat("zone_001", bad)


# --- the real path, end to end ----------------------------------------------

def test_a_defeat_reaches_the_save_once(tmp_path):
    async def go():
        engine, zone_id = await _entered(tmp_path)
        members = _members(_live(engine).zone)
        assert members, "this Zone should hold an encounter"
        assert _live(engine).progress.defeated is None
        await engine.handle_progress(_defeat(zone_id, members[0]))
        assert _live(engine).progress.defeated == (members[0],)
        # A resend after a dropped connection is the normal case.
        await engine.handle_progress(_defeat(zone_id, members[0]))
        assert _live(engine).progress.defeated == (members[0],)
    run(go())


def test_an_undeclared_member_never_becomes_save_data(tmp_path):
    """Monotone means a wrong entry is permanent, so it is refused.

    Each of the three ways an identity can be wrong: a room the Zone does
    not have, an archetype the room does not declare, and an ordinal past
    the declared count.
    """
    async def go():
        engine, zone_id = await _entered(tmp_path)
        zone = _live(engine).zone
        room = next(c for c in zone.chambers if c.enemies)
        group = room.enemies[0]
        declared = sum(g.count for g in room.enemies
                       if g.archetype == group.archetype)
        other = next(a for a in C.ENEMY_STATS
                     if all(g.archetype != a for g in room.enemies))
        for member in (f"c999/{group.archetype}#0",
                       f"{room.id}/{other}#0",
                       f"{room.id}/{group.archetype}#{declared}"):
            with pytest.raises(Exception, match="declares no"):
                await engine.handle_progress(_defeat(zone_id, member))
        assert _live(engine).progress.defeated is None
    run(go())


def test_the_record_survives_a_restart_of_the_bridge(tmp_path):
    """Quitting is not an encounter reset: the save carries it back."""
    async def go():
        engine, zone_id = await _entered(tmp_path)
        members = _members(_live(engine).zone)
        await engine.handle_progress(_defeat(zone_id, members[0]))
        again, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        rec = again.save.zone_by_id(zone_id)
        assert rec.progress.defeated == (members[0],)
    run(go())


def test_defeats_are_counted_against_the_declaration_not_the_client(
        tmp_path):
    """Every declared member can be recorded, and not one more."""
    async def go():
        engine, zone_id = await _entered(tmp_path)
        members = _members(_live(engine).zone)
        for member in members:
            await engine.handle_progress(_defeat(zone_id, member))
        assert set(_live(engine).progress.defeated) == set(members)
        assert len(_live(engine).progress.defeated) == len(members)
    run(go())


def test_transition_refuses_a_zone_that_records_no_progress(tmp_path):
    async def go():
        engine, zone_id = await _entered(tmp_path)
        with pytest.raises(ValueError):
            T.record_defeat(engine.save, "zone_999", "c005/bulwark#0")
    run(go())
