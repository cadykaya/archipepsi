"""The equipment face's fixture must still be what its generator produces.

`godot/tests/fixtures/equipment_snapshot.json` is generated from real
`CampaignSnapshot`s so the face (`equipment_face.gd`, H-INVENTORY) is
tested against the inventory Dess's projection actually emits. This is
the guard against the JSON drifting from the generator, and against the
generator drifting from what the bridge could really have granted.
"""

from __future__ import annotations

import json

from archipepsi_bridge.fixtures import make_equipment_snapshot as gen
from archipepsi_bridge.schemas import mechanics as M
from archipepsi_bridge.schemas.echo import target_errors


def test_the_committed_fixture_matches_its_generator():
    on_disk = gen.OUT.read_text(encoding="utf-8")
    assert on_disk == gen.render(), (
        "run `make equipment-fixture`; the JSON is generated, not edited")


def test_every_log_is_one_the_bridge_could_really_have_granted():
    for log in (gen.build_log(), gen.build_log(consumables=False),
                gen.build_log(acquired=True)):
        for index, interpretation in enumerate(log):
            so_far = M.derive_mechanics(log[:index])
            assert target_errors(interpretation, so_far) == [], (
                f"interpretation {index} could not have been granted")


def test_each_variant_is_the_state_it_is_named_for():
    """The face's consumable states are only tested if the variants hold
    them. A generator edit that quietly equipped the supply in
    `unequipped` would leave the face suite green and blind."""
    variants = json.loads(gen.render())

    def item(name, cid):
        return next(i for i in variants[name]["inventory"]["items"]
                    if i["component_id"] == cid)

    assert item("base", "act_cinder")["equipped_in"] == "consumable"
    assert item("base", "act_cinder")["charges_left"] == 2
    assert item("exhausted", "act_cinder")["equipped_in"] == "consumable"
    assert item("exhausted", "act_cinder")["charges_left"] == 0
    assert item("unequipped", "act_cinder")["equipped_in"] is None
    assert variants["unequipped"]["slots"]["consumable"] is None
    assert not [i for i in variants["none_owned"]["inventory"]["items"]
                if "consumable" in i["compatible_slots"]]
    added = ({i["component_id"]
              for i in variants["acquired"]["inventory"]["items"]}
             - {i["component_id"]
                for i in variants["base"]["inventory"]["items"]})
    assert added == {"act_glow"}
    assert item("swapped", "act_bolt")["equipped_in"] == "echo_a"
    assert item("swapped", "act_lash")["equipped_in"] is None
    assert item("spent_spare", "act_cinder")["equipped_in"] is None
    assert item("spent_spare", "act_cinder")["charges_left"] == 0
    assert item("spent_spare", "act_flask")["equipped_in"] == "consumable"
    # The upgrade-only Echo made nothing of its own.
    ids = [i["component_id"] for i in variants["base"]["inventory"]["items"]]
    assert len(ids) == len(set(ids))
    assert item("base", "act_lash")["siblings"] == ["trait_grip"]
