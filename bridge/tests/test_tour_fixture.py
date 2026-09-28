"""The tour's fixture must still be what its generator produces, and the
walk in it one a player can make.

`godot/tests/fixtures/tour_snapshot.json` is MENU-INT's tour data: the
candidate campaign the owner played, played again by the bridge's engine
into its seventh Zone (`make_tour_snapshot.py`), and there a first walk
from the entrance, sent as Godot sends it. The tour's claim is "real
campaign data"; this is what holds it to that. The walk is judged here by
the bridge's own map, not by the walker that made it: each room is
entered from one walked before it, by a way that goes that way and that
the bridge's map calls open.
"""

from __future__ import annotations

import json

import pytest

from archipepsi_bridge.fixtures import make_tour_snapshot as gen


@pytest.fixture(scope="module")
def tour() -> dict:
    return json.loads(gen.render())


def test_the_committed_fixture_matches_its_generator(tour):
    assert json.loads(gen.OUT.read_text(encoding="utf-8")) == tour, (
        "run `make tour-fixture`; the JSON is generated, not edited")


def test_the_walk_is_one_a_player_can_make(tour):
    walked = tour["meta"]["walked"]
    edges = tour["after"]["active_zone"]["zone"]["edges"]
    open_ = {c["edge_id"] for c in tour["after"]["zone_map"]["connectors"]
             if c["state"] == "open"}
    assert len(walked) > 1
    for i, room in enumerate(walked[1:], 1):
        before = walked[:i]
        ways = [e["edge_id"] for e in edges
                if (e["room_b"] == room and e["room_a"] in before
                    and e["direction"] in ("BIDIRECTIONAL", "A_TO_B"))
                or (e["room_a"] == room and e["room_b"] in before
                    and e["direction"] in ("BIDIRECTIONAL", "B_TO_A"))]
        assert any(w in open_ for w in ways), (
            f"{room} is not reached on foot from {before}: {ways}")


def test_what_changed_between_arriving_and_the_tour(tour):
    meta = tour["meta"]

    def found(name):
        return sorted(r["room_id"] for r in tour[name]["zone_map"]["rooms"]
                      if r["discovered"])

    # MET ON ARRIVING: the entrance only; then the walk, and nothing else.
    assert found("before") == meta["walked"][:1]
    assert found("after") == sorted(meta["walked"])
    # THE CHECKS are claimed in rooms walked, and only after arriving.
    chambers = {c["id"]: c for c in
                tour["after"]["active_zone"]["zone"]["chambers"]}
    here = {loc for room in meta["walked"]
            for loc in [chambers[room]["reward_location_id"],
                        *chambers[room]["additional_reward_location_ids"]]}
    assert len(meta["claimed"]) == gen.CLAIMS
    assert set(meta["claimed"]) <= here
    for loc in meta["claimed"]:
        assert loc not in tour["before"]["checked_location_ids"]
        assert loc in tour["after"]["checked_location_ids"]
    # THE CAMPAIGN'S OWN KEYS: the consumable stays where it was put.
    for name in ("before", "after"):
        assert tour[name]["slots"]["consumable"] == meta["consumable"]
        assert tour[name]["active_zone"]["zone_id"] == meta["zone_id"]
