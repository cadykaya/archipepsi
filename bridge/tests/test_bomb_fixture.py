"""The Bomb Bag fixture must still be what its generator produces.

`godot/tests/fixtures/bomb_snapshots.json` is the candidate campaign the
owner played, played again to its first consumable (H-BOMBS, PT-09): the
Bomb Bag of Check 89100140, claimed, slotted, spent and refilled through
the engine's own handlers. `godot-bombs` reads it as "a Bomb Bag the
campaign made, not one given", and that claim is only as good as this
guard: the JSON is the generator's, and each variant is the state it is
named for.
"""

from __future__ import annotations

import json

import pytest

from archipepsi_bridge.fixtures import make_bomb_snapshots as gen


@pytest.fixture(scope="module")
def rendered() -> str:
    return gen.render()


def test_the_committed_fixture_matches_its_generator(rendered):
    assert gen.OUT.read_text(encoding="utf-8") == rendered, (
        "run `make bomb-fixture`; the JSON is generated, not edited")


def test_each_variant_is_the_state_it_is_named_for(rendered):
    variants = json.loads(rendered)
    meta = variants["meta"]
    cid = meta["component_id"]

    def consumables(name):
        return [o["component"]["component_id"]
                for o in variants[name]["mechanics"]["owned"]
                if o["component"].get("charges") is not None]

    def spent(name):
        return next((u["spent"] for u in variants[name]["consumable_uses"]
                     if u["component_id"] == cid), 0)

    # WHERE IT CAME FROM: created by the provider, from its own Check.
    assert (meta["item_name"], meta["location_id"], meta["zone_index"]) \
        == ("Bomb Bag", 89100140, 6)
    assert meta["echo_operations"] == ["CreateOperation"]
    assert consumables("none_owned") == []
    assert consumables("acquired") == [cid]
    # NOTHING PUTS IT ON A KEY FOR THE PLAYER; the slot action does.
    assert variants["acquired"]["slots"]["consumable"] is None
    assert variants["carried"]["slots"]["consumable"] == cid
    assert spent("carried") == 0
    assert spent("authorized") == 1
    assert spent("spent") == meta["charges"]
    # THE NEXT ZONE REFILLS IT, and it stays on the key.
    assert variants["refilled"]["consumable_generation"] \
        == meta["refilled_generation"] > meta["generation"]
    assert spent("refilled") == 0
    assert variants["refilled"]["slots"]["consumable"] == cid
    # THE REFUSAL IS THE REAL SERVER'S, for use 1 of the old supply.
    refused = variants["refused"]
    assert refused["type"] == "error"
    assert refused["about"] == f"use_consumable:{cid}:{meta['generation']}:1"
