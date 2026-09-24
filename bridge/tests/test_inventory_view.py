"""H-UI-DATA — the inventory view is a projection of the fold, nothing more.

Fixtures from C-INVENTORY's list: a mixed Echo, an upgrade-only event, a
refused placement, and a pending use. Compatibility is asserted against
the AUTHORITY's own equip transition, not against a restated rule, so the
view cannot drift from what the save will accept.
"""
from __future__ import annotations

import pytest

from archipepsi_bridge.inventory_view import inventory_view
from archipepsi_bridge.schemas import constants as C
from archipepsi_bridge.schemas import protocol as P
from archipepsi_bridge.schemas import transitions as T


def _interp(seq: int, loc: int, name: str, operations: list) -> dict:
    return {
        "schema_version": 8, "echo_id": f"echo_{loc}",
        "interpretation_seq": seq, "source_location_id": loc,
        "source_item_name": name, "source_recipient_name": "Skyiah",
        "source_game": "Archipepsi", "display_name": name,
        "description": "An Echo.", "concepts": ["test"], "mode": "literal",
        "operations": operations}


def _gun(slot="echo_a", cid="act_gun", charges=None) -> dict:
    return {"op": "create", "component": {
        "kind": "action", "component_id": cid, "display_name": "Gun",
        "description": "Bang.", "slot": slot, "cooldown": 1.0,
        **({"charges": charges} if charges is not None else {}),
        "primitive": {"type": "hitscan_damage", "damage": 8.0, "pellets": 1,
                      "spread_degrees": 1.0, "range": 35.0}}}


def _trait() -> dict:
    return {"op": "create", "component": {
        "kind": "trait", "component_id": "trait_swift",
        "display_name": "Swift", "description": "Faster.",
        "stat": "move_speed", "multiplier": 1.2}}


def _save(*interps, slots=None) -> P.CampaignSave:
    return P.CampaignSave(
        seed_name="Seed", team=0, slot_id=1, slot_name="Skyiah",
        interpretations=tuple(interps),
        next_interpretation_seq=len(interps),
        slots=slots or P.SlotAssignment())


def test_a_mixed_echo_shows_both_halves_and_names_each_other():
    view = inventory_view(_save(_interp(0, 89100001, "Kit",
                                        [_gun(), _trait()])))
    by = {i.component_id: i for i in view.items}
    assert set(by) == {"act_gun", "trait_swift"}
    assert by["act_gun"].siblings == ("trait_swift",)
    assert by["trait_swift"].siblings == ("act_gun",)
    assert by["trait_swift"].activation == "always_on"
    assert by["trait_swift"].compatible_slots == ()


def test_an_upgrade_is_history_on_the_item_not_a_second_item():
    save = _save(
        _interp(0, 89100001, "Pistol", [_gun()]),
        _interp(1, 89100002, "Scope", [{"op": "upgrade", "target": "act_gun",
                                         "field": "damage", "delta": 2.0}]))
    view = inventory_view(save)
    assert [i.component_id for i in view.items] == ["act_gun"]
    item = view.items[0]
    assert item.mk == 2
    assert [h.operation for h in item.history] == ["create", "upgrade"]
    assert [h.source_item_name for h in item.history] == ["Pistol", "Scope"]


def test_compatibility_is_exactly_what_the_authority_accepts():
    """For every item and every slot: offered iff the equip transition
    succeeds. So the menu never offers a placement it would be refused."""
    save = _save(_interp(0, 89100001, "Kit",
                         [_gun(), _gun(slot="mobility", cid="act_dash"),
                          _trait()]))
    view = inventory_view(save)
    for item in view.items:
        for slot in C.SLOT_NAMES:
            try:
                T.slot_action(save, slot, item.component_id)
                accepted = True
            except ValueError:
                accepted = False
            assert accepted == (slot in item.compatible_slots), (
                f"{item.component_id} in {slot}: authority says {accepted}")
    accepts = {s.slot: s.accepts for s in view.slots}
    assert accepts["echo_a"] == ("act_gun",)
    assert accepts["mobility"] == ("act_dash",)


def test_an_equipped_item_says_where_and_an_exhausted_one_stays_equipped():
    save = _save(_interp(0, 89100001, "Bombs",
                         [_gun(slot="consumable", cid="act_bomb", charges=1)]),
                 slots=P.SlotAssignment(consumable="act_bomb"))
    save = T.spend_charge(save, "act_bomb", 1, save.consumable_generation)
    item = inventory_view(save).items[0]
    assert item.equipped_in == "consumable"
    assert (item.charges_max, item.charges_left) == (1, 0)


def test_a_pending_use_is_already_counted_and_never_mirrored():
    """D-9: the authorized charge is already spent in the count, and the
    authorization itself is not in the view -- a relaunched client must
    not be handed a record it could mistake for its own."""
    save = _save(_interp(0, 89100001, "Bombs",
                         [_gun(slot="consumable", cid="act_bomb",
                               charges=3)]),
                 slots=P.SlotAssignment(consumable="act_bomb"))
    save = T.authorize_consumable(save, "act_bomb", use_index=1,
                                  generation=save.consumable_generation)
    view = inventory_view(save)
    assert view.items[0].charges_left == 2
    assert "authorization" not in view.model_dump_json()


def test_the_view_is_the_fold_and_adds_nothing():
    save = _save(_interp(0, 89100001, "Kit", [_gun(), _trait()]),
                 _interp(1, 89100002, "Scope", [
                     {"op": "upgrade", "target": "act_gun",
                      "field": "damage", "delta": 2.0}]))
    fold = save.derive()
    view = inventory_view(save)
    assert [i.component_id for i in view.items] == [
        o.component_id for o in fold.owned]
    for item, owned in zip(view.items, fold.owned):
        assert len(item.history) == len(owned.provenance)
        assert item.mk == owned.mk
