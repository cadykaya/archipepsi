"""The maps' fixture must still be what its generator produces.

`godot/tests/fixtures/map_snapshot.json` is Dess's `map_view` of the
candidate Zone after real transitions, so the minimap (H-MINIMAP) is
tested against the map the snapshot actually carries. This guards the
JSON against drifting from the generator, and the variants against
quietly losing the states they are named for.
"""

from __future__ import annotations

import json

from archipepsi_bridge.fixtures import make_map_snapshot as gen


def test_the_committed_fixture_matches_its_generator():
    on_disk = gen.OUT.read_text(encoding="utf-8")
    assert on_disk == gen.render(), (
        "run `make map-fixture`; the JSON is generated, not edited")


def _gate(variants, name, edge_id):
    return next(c for c in variants[name]["zone_map"]["connectors"]
                if c["edge_id"] == edge_id)


def test_each_variant_is_the_state_it_is_named_for():
    """The minimap's cases are only tested if the variants hold them."""
    v = json.loads(gen.render())
    found = [r["room_id"] for r in v["start"]["zone_map"]["rooms"]
             if r["discovered"]]
    assert found == ["c001"]
    # The green circuit: carrying the cell is not powering the door.
    assert _gate(v, "carried", "e:c005:c006")["state"] == "blocked"
    assert _gate(v, "powered", "e:c005:c006")["state"] == "open"
    assert _gate(v, "powered", "e:c005:c006")["circuits"] \
        == ["state:cell_power"]
    # The span closes again when it is put back.
    assert _gate(v, "span_lowered", "e:c002:c003")["state"] == "open"
    assert _gate(v, "span_stowed", "e:c002:c003")["state"] == "blocked"
    rooms = v["all_rooms"]["zone_map"]["rooms"]
    assert all(r["discovered"] and r["name"] for r in rooms)
