"""O05-05.1 finding P5-9: a composed railway's commissioned span could not
be saved.

`RailSpan.latch_id` is documented as "the persistence handle: a
commissioned span is the repair that survives leaving and coming back,
and it is recorded through the same latch machinery a physics package
already uses". The engine does report it -- `RailJunction.latch_fired`
-> `ZoneController.report_latch(network_id, latch_id)` -> `latch_fired`.
But `transitions.record_latch` accepted only P14's `graph_` latches and
physics packages from the committed manifest, and a railway is neither,
so every composed span a player commissioned was refused and forgotten
at the next load. `godot-rail-zone` never saw it: it fills
`latches_carried` directly.

The rail path is checked against its own evidence, like the graph path:
the ACCEPTED Zone declares the network and the span's latch, and the
committed layout placed every dock room the engine built it through.
"""
from __future__ import annotations

import pytest

from archipepsi_bridge.schemas import protocol as P
from archipepsi_bridge.schemas import transitions as T
from archipepsi_bridge.schemas.zone import Zone

NETWORK = "yard"


def _railed() -> Zone:
    from archipepsi_bridge.playtest import played_zone
    zone = played_zone()
    assert zone is not None
    spine = [c.id for c in zone.chambers]
    raw = zone.model_dump()
    raw["rail_networks"] = [{
        "network_id": NETWORK,
        "docks": [{"dock_id": "s1", "room_id": spine[3]},
                  {"dock_id": "s2", "room_id": spine[4]},
                  {"dock_id": "s3", "room_id": spine[5]}],
        "spans": [{"span_id": "s1_s2", "from_dock": "s1", "to_dock": "s2",
                   "control_room_id": None, "latch_id": "span_a"},
                  {"span_id": "s2_s3", "from_dock": "s2", "to_dock": "s3",
                   "control_room_id": spine[4], "latch_id": "span_b"}],
    }]
    return Zone.model_validate(raw)


def _save(zone: Zone, *, committed: bool = True,
          placed: tuple[str, ...] | None = None,
          packages: tuple[str, ...] = ()) -> P.CampaignSave:
    top = max(zone.reward_location_ids) - 89100000
    save = P.CampaignSave(
        seed_name="Seed", team=0, slot_id=1, slot_name="Skyiah",
        scale=P.CampaignScale(location_count=max(top + 1, 30),
                              zone_target_checks=15, zone_budget=1000))
    save = T.start_generation(
        save, zone_id=zone.zone_id,
        allocated_location_ids=tuple(zone.reward_location_ids),
        target_game=zone.target_game)
    save = T.enter_zone(T.accept_zone(save, zone), zone.zone_id)
    if committed:
        rooms = [c.id for c in zone.chambers] if placed is None else placed
        save = T.commit_layout(save, zone.zone_id, {
            "zone_id": zone.zone_id, "manifest_digest": "d" * 16,
            "rooms": {r: {} for r in rooms},
            "packages": [{"package_id": p, "package": {
                "package_id": p, "latch_conditions": []}}
                for p in packages]})
    return save


def _latched(save: P.CampaignSave, zone: Zone) -> tuple[str, ...]:
    rec = save.zone_by_id(zone.zone_id)
    return tuple(rec.progress.latched)


def test_a_commissioned_span_is_recorded_under_its_network():
    zone = _railed()
    save = T.record_latch(_save(zone), zone.zone_id, NETWORK, "span_b")
    assert f"{NETWORK}/span_b" in _latched(save, zone)


def test_it_survives_the_save_file():
    zone = _railed()
    save = T.record_latch(_save(zone), zone.zone_id, NETWORK, "span_b")
    loaded = P.CampaignSave.model_validate_json(save.model_dump_json())
    assert f"{NETWORK}/span_b" in _latched(loaded, zone)


def test_a_repeat_is_absorbed():
    zone = _railed()
    once = T.record_latch(_save(zone), zone.zone_id, NETWORK, "span_b")
    assert T.record_latch(once, zone.zone_id, NETWORK, "span_b") is once


def test_a_latch_the_network_does_not_declare_is_refused():
    zone = _railed()
    with pytest.raises(ValueError, match="declares no span latch 'span_z'"):
        T.record_latch(_save(zone), zone.zone_id, NETWORK, "span_z")


def test_a_network_the_zone_does_not_declare_is_still_refused():
    zone = _railed()
    with pytest.raises(ValueError, match="accepted no physics package"):
        T.record_latch(_save(zone), zone.zone_id, "other_yard", "span_b")


def test_nothing_latches_before_the_layout_is_committed():
    zone = _railed()
    with pytest.raises(ValueError, match="no committed layout"):
        T.record_latch(_save(zone, committed=False), zone.zone_id,
                       NETWORK, "span_b")


def test_a_network_through_a_room_the_layout_never_placed_is_refused():
    """The engine builds nothing for a network with a dock in a room it
    did not build (`RailNetworks._one`), so nothing there can latch."""
    zone = _railed()
    docks = {d.room_id for d in zone.rail_networks[0].docks}
    placed = tuple(c.id for c in zone.chambers
                   if c.id != sorted(docks)[-1])
    with pytest.raises(ValueError, match="placed no room"):
        T.record_latch(_save(zone, placed=placed), zone.zone_id,
                       NETWORK, "span_b")


def test_a_physics_package_sharing_the_name_is_ambiguous_and_refused():
    """`latched` is one set of `package/latch` strings, and a rail
    junction restores from it by that string. Two meanings for one name
    would let a physics latch commission a span, so neither is guessed."""
    zone = _railed()
    with pytest.raises(ValueError, match="both a physics package and a "
                                         "rail network"):
        T.record_latch(_save(zone, packages=(NETWORK,)), zone.zone_id,
                       NETWORK, "span_b")


def test_a_span_that_ships_commissioned_has_nothing_to_record():
    """No control, no lever (`RailNetworks._one` starts that link
    connected), so no player ever commissioned it."""
    zone = _railed()
    with pytest.raises(ValueError, match="declares no span latch 'span_a'"):
        T.record_latch(_save(zone), zone.zone_id, NETWORK, "span_a")
