"""The consumable slot: charges, spending them, and getting them back.

The fifth Action slot, added after the owner played the Echo menu and
asked for "an equipable slot for each type ... consumables". The other
four hold a verb you always have; this one holds one that runs out.

**Charges are a field on the Action, not a zero-regen `Resource`.** A
Resource is a HUD channel with an economy -- eight palette colours, three
presentations, a regen curve -- and those exist for pools the player
manages. Three uses of one grenade has no decisions in it, and giving it
a channel would put an economy on the HUD for something that is just a
number going down.

**They refill on entering a Zone** (owner decision, 2026-09-22). Spent
for good would leave the slot dead weight for most of a long run and
retire the Echo that earned it; per-Zone keeps it a resource worth
spending deliberately. They persist WITHIN a Zone, so a reload does not
hand them back.
"""
from __future__ import annotations

import pytest

from archipepsi_bridge.schemas import protocol as P
from archipepsi_bridge.schemas import echo as E
from archipepsi_bridge.schemas import transitions as T
from archipepsi_bridge.schemas import constants as C
from archipepsi_bridge.schemas.zone import Zone
from pydantic import TypeAdapter


def _action(slot="consumable", charges=3, cid="act_nade"):
    return {"op": "create", "component": {
        "kind": "action", "component_id": cid, "display_name": "Grenade",
        "description": "Boom.", "slot": slot, "cooldown": 1.0,
        **({"charges": charges} if charges is not None else {}),
        "primitive": {"type": "hitscan_damage", "damage": 8.0, "pellets": 1,
                      "spread_degrees": 1.0, "range": 35.0}}}


def _save(*operations) -> P.CampaignSave:
    interp = {
        "schema_version": 8, "echo_id": "echo_89100001",
        "interpretation_seq": 0, "source_location_id": 89100001,
        "source_item_name": "Bomb", "source_recipient_name": "Skyiah",
        "source_game": "Archipepsi", "display_name": "Grenade",
        "description": "Boom.", "concepts": ["blast"], "mode": "literal",
        "operations": list(operations) or [_action()],
    }
    return P.CampaignSave(
        seed_name="Seed", team=0, slot_id=1, slot_name="Skyiah",
        interpretations=(interp,), next_interpretation_seq=1)


def _restart(save: P.CampaignSave) -> P.CampaignSave:
    """A process restart: nothing survives but the serialised save."""
    return P.CampaignSave.model_validate_json(save.model_dump_json())


class TestTheStructuralRule:
    """Slot and charges imply each other, in the schema rather than in a
    note. Either half alone has a plausible-looking reading, which is
    exactly the shape that rots."""

    def test_a_consumable_declares_its_charges(self):
        save = _save()
        assert save.charges_left("act_nade") == 3

    def test_charges_on_any_other_slot_are_refused(self):
        with pytest.raises(Exception) as caught:
            E.ActionComponent.model_validate(
                _action(slot="mobility")["component"])
        assert "exactly when" in str(caught.value)

    def test_a_consumable_without_charges_is_refused(self):
        with pytest.raises(Exception) as caught:
            E.ActionComponent.model_validate(
                _action(charges=None)["component"])
        assert "exactly when" in str(caught.value)

    def test_the_slot_is_one_of_the_five(self):
        assert "consumable" in C.SLOT_NAMES
        assert len(C.SLOT_NAMES) == 5


class TestSpending:
    def test_each_use_takes_one(self):
        save = T.slot_action(_save(), "consumable", "act_nade")
        assert save.charges_left("act_nade") == 3
        save = T.spend_charge(save, "act_nade")
        assert save.charges_left("act_nade") == 2

    def test_the_last_charge_empties_the_slot(self):
        """A consumable with nothing left sitting on its key is a control
        that looks live and does nothing."""
        save = T.slot_action(_save(), "consumable", "act_nade")
        for _ in range(3):
            save = T.spend_charge(save, "act_nade")
        assert save.charges_left("act_nade") == 0
        assert save.slots.consumable is None

    def test_it_refuses_rather_than_saturating(self):
        save = T.slot_action(_save(), "consumable", "act_nade")
        for _ in range(3):
            save = T.spend_charge(save, "act_nade")
        with pytest.raises(ValueError) as caught:
            T.spend_charge(save, "act_nade")
        assert "no charges left" in str(caught.value)

    def test_spending_something_that_is_not_a_consumable_is_refused(self):
        save = _save(_action(slot="echo_a", charges=None, cid="act_gun"))
        with pytest.raises(ValueError) as caught:
            T.spend_charge(save, "act_gun")
        assert "not a consumable" in str(caught.value)


class TestTheSaveRefusesImpossibleCounts:
    """The validator holds on every path that can build a save, not only
    through `spend_charge` -- so a hand-edited or corrupt save cannot be
    constructed at all."""

    def test_more_spent_than_it_ever_had(self):
        save = _save()
        with pytest.raises(Exception) as caught:
            P.CampaignSave(**{**save.model_dump(), "consumable_uses": (
                {"component_id": "act_nade", "spent": 9},)})
        assert "against 3 charges" in str(caught.value)

    def test_spent_out_and_still_slotted(self):
        save = _save()
        with pytest.raises(Exception) as caught:
            P.CampaignSave(**{
                **save.model_dump(),
                "slots": {"consumable": "act_nade"},
                "consumable_uses": ({"component_id": "act_nade",
                                     "spent": 3},)})
        assert "spent out and still slotted" in str(caught.value)

    def test_uses_recorded_against_something_unowned(self):
        save = _save()
        with pytest.raises(Exception) as caught:
            P.CampaignSave(**{**save.model_dump(), "consumable_uses": (
                {"component_id": "act_ghost", "spent": 1},)})
        assert "not owned" in str(caught.value)


class TestPersistence:
    def test_charges_survive_a_restart_mid_zone(self):
        """Reloading is not a refill. Otherwise the cheapest way to get a
        grenade back is to quit and come back."""
        save = T.slot_action(_save(), "consumable", "act_nade")
        save = T.spend_charge(save, "act_nade")
        save = T.spend_charge(save, "act_nade")
        assert _restart(save).charges_left("act_nade") == 1

    def test_a_save_that_never_held_one_loads_unchanged(self):
        """`consumable_uses` defaults empty, so every campaign written
        before the slot existed loads without a migration."""
        save = _save(_action(slot="echo_a", charges=None, cid="act_gun"))
        raw = save.model_dump()
        raw.pop("consumable_uses")
        assert P.CampaignSave(**raw).consumable_uses == ()


# --------------------------------------------------------------------------
# The refill, through a real Zone entry


def _room(rid: str, reward: int | None = None) -> dict:
    return {"id": rid, "type": "arena", "width": 16.0, "depth": 15.0,
            "wall_height": 5.0, "objective": "kill_all",
            "reward_location_id": reward,
            "enemies": [{"archetype": "melee", "count": 1}]}


def _zone() -> Zone:
    return TypeAdapter(Zone).validate_python({
        "schema_version": 7, "zone_id": "zone_001", "display_name": "Relay",
        "target_game": "Game", "theme": "void_glitch",
        "chambers": [_room("c001", 89100002), _room("c002")],
    })


def _in_a_zone(save: P.CampaignSave) -> P.CampaignSave:
    zone = _zone()
    save = T.start_generation(save, zone_id=zone.zone_id,
                              allocated_location_ids=(89100002,),
                              target_game=zone.target_game)
    return T.enter_zone(T.accept_zone(save, zone), zone.zone_id)


class TestTheRefill:
    def test_entering_a_zone_gives_the_charges_back(self):
        save = _in_a_zone(T.slot_action(_save(), "consumable", "act_nade"))
        save = T.spend_charge(save, "act_nade")
        save = T.spend_charge(save, "act_nade")
        assert save.charges_left("act_nade") == 1
        save = T.rest_zone(save, "zone_001")
        save = T.enter_zone(save, "zone_001")
        assert save.charges_left("act_nade") == 3

    def test_a_spent_out_consumable_comes_back_equippable(self):
        """The slot empties on the last charge; the refill is what makes
        that recoverable rather than the end of the Echo."""
        save = _in_a_zone(T.slot_action(_save(), "consumable", "act_nade"))
        for _ in range(3):
            save = T.spend_charge(save, "act_nade")
        assert save.slots.consumable is None
        save = T.rest_zone(save, "zone_001")
        save = T.enter_zone(save, "zone_001")
        assert save.charges_left("act_nade") == 3
        save = T.slot_action(save, "consumable", "act_nade")
        assert save.slots.consumable == "act_nade"
