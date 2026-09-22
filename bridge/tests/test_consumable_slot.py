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
retire the Echo that earned it.

**WHICH entries count as a refill is THIS LANE'S PROPOSAL and not the
owner's ruling** -- the owner chose "on entering a Zone" and nothing
finer. The whole policy lives in `transitions._refill_is_due`, its
consequences are spelled out there, and `TestTheRefill` asserts what it
does rather than arguing that it is right. A reload does not hand
charges back; A -> B -> A does.
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


def _spend(save: P.CampaignSave, cid="act_nade") -> P.CampaignSave:
    """One ordinary use: the next index due against the CURRENT supply,
    which is what a client holding a current snapshot would send."""
    charges = save.derive().by_id(cid).component.charges
    return T.spend_charge(save, cid, charges - save.charges_left(cid) + 1,
                          save.consumable_generation)


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
        save = _spend(save)
        assert save.charges_left("act_nade") == 2

    def test_the_last_charge_leaves_it_equipped_at_zero(self):
        """A consumable is a permanently owned refillable supply. It
        stays selected at 0/max so the refill makes it usable again with
        no trip back to the inventory."""
        save = T.slot_action(_save(), "consumable", "act_nade")
        for _ in range(3):
            save = _spend(save)
        assert save.charges_left("act_nade") == 0
        assert save.slots.consumable == "act_nade"

    def test_it_refuses_rather_than_saturating(self):
        save = T.slot_action(_save(), "consumable", "act_nade")
        for _ in range(3):
            save = _spend(save)
        with pytest.raises(ValueError) as caught:
            _spend(save)
        assert "no charges left" in str(caught.value)

    def test_spending_something_that_is_not_a_consumable_is_refused(self):
        save = _save(_action(slot="echo_a", charges=None, cid="act_gun"))
        with pytest.raises(ValueError) as caught:
            T.spend_charge(save, "act_gun", 1,
                           save.consumable_generation)
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

    def test_exhausted_and_equipped_is_a_legal_save(self):
        """The inverse of the old rule, and the owner's correction:
        holding an empty supply is fine, USING one is not."""
        save = P.CampaignSave(**{
            **_save().model_dump(),
            "slots": {"consumable": "act_nade"},
            "consumable_uses": ({"component_id": "act_nade", "spent": 3},)})
        assert save.slots.consumable == "act_nade"
        assert save.charges_left("act_nade") == 0
        with pytest.raises(ValueError):
            _spend(save)

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
        save = _spend(save)
        save = _spend(save)
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


def _in_another_zone(save: P.CampaignSave,
                     rest: bool = False) -> P.CampaignSave:
    """A second, different deployment.

    `rest=True` FINISHES the first Zone instead of abandoning it, so it
    can be walked back into: an abandoned Zone is deliberately not
    re-enterable, and a Zone merely put down still holds its locations,
    which the one-Zone-at-a-time rule refuses to let a second Zone
    generate past. A completed one is revisitable, which is the route
    A -> B -> A actually takes in play.
    """
    zone = TypeAdapter(Zone).validate_python({
        "schema_version": 7, "zone_id": "zone_002", "display_name": "Span",
        "target_game": "Game", "theme": "void_glitch",
        "chambers": [_room("c001", 89100003), _room("c002")],
    })
    # The first Zone gives its locations back before a second can take
    # any; the point of the case is the deployment change, not the
    # accounting around it.
    if save.active_zone_id:
        save = (T.complete_zone(save, save.active_zone_id) if rest
                else T.abandon_zone(save, save.active_zone_id))
    save = T.start_generation(save, zone_id=zone.zone_id,
                              allocated_location_ids=(89100003,),
                              target_game=zone.target_game)
    return T.enter_zone(T.accept_zone(save, zone), zone.zone_id)


def _in_a_zone(save: P.CampaignSave) -> P.CampaignSave:
    zone = _zone()
    save = T.start_generation(save, zone_id=zone.zone_id,
                              allocated_location_ids=(89100002,),
                              target_game=zone.target_game)
    return T.enter_zone(T.accept_zone(save, zone), zone.zone_id)


class TestTheRefill:
    """Bound to a deployment BEGINNING, not to every `enter_zone` call."""

    def test_deploying_into_a_new_zone_restocks(self):
        save = _in_a_zone(T.slot_action(_save(), "consumable", "act_nade"))
        save = _spend(save)
        save = _spend(save)
        assert save.charges_left("act_nade") == 1
        save = _in_another_zone(save)
        assert save.charges_left("act_nade") == 3

    def test_it_stays_equipped_across_the_refill(self):
        """"On refill the same equipped item becomes usable without
        requiring another inventory visit."""
        save = _in_a_zone(T.slot_action(_save(), "consumable", "act_nade"))
        for _ in range(3):
            save = _spend(save)
        assert save.slots.consumable == "act_nade"
        save = _in_another_zone(save)
        assert save.slots.consumable == "act_nade"
        assert save.charges_left("act_nade") == 3
        _spend(save)   # usable again, no visit needed

    def test_re_entering_the_same_zone_does_not_restock(self):
        """A repeated entry request is not a new deployment."""
        save = _in_a_zone(T.slot_action(_save(), "consumable", "act_nade"))
        save = _spend(save)
        again = T.enter_zone(save, "zone_001")
        assert again.charges_left("act_nade") == 2

    def test_a_hub_trip_and_back_to_the_same_zone_does_not_restock(self):
        """THE POLICY, stated as a test: the cheapest resupply must not
        be a round trip through the portal."""
        save = _in_a_zone(T.slot_action(_save(), "consumable", "act_nade"))
        save = _spend(save)
        save = T.rest_zone(save, "zone_001")       # back to the Hub
        save = T.enter_zone(save, "zone_001")      # and in again
        assert save.charges_left("act_nade") == 2

    def test_a_reload_mid_deployment_does_not_restock(self):
        save = _in_a_zone(T.slot_action(_save(), "consumable", "act_nade"))
        save = _spend(save)
        resumed = _restart(save)
        assert resumed.charges_left("act_nade") == 2
        assert T.enter_zone(resumed, "zone_001").charges_left("act_nade") == 2

    def test_a_b_a_refills_on_both_changes(self):
        """**WHAT THE PROPOSED RULE ACTUALLY DELIVERS**, recorded rather
        than assumed. `_refill_is_due` compares against ONE deployment
        id, so going A -> B -> A refills at both changes: coming back to
        A does not restore what A had left, it hands over a fresh supply.

        That makes Hub -> B -> A a working restock loop, at the price of
        one extra Zone — the same-Zone rule closes the cheap version of
        the loop without closing the loop. This is not per-Zone
        expenditure persistence, and the docstring on `_refill_is_due`
        says so. The case asserts the behaviour rather than endorsing it;
        if the owner rules for per-Zone records, this is the test that
        has to change, and it is meant to be easy to find.
        """
        save = _in_a_zone(T.slot_action(_save(), "consumable", "act_nade"))
        save = _spend(save)
        save = _spend(save)
        assert save.charges_left("act_nade") == 1
        # A -> B: a refill, as the rule intends.
        save = _in_another_zone(save, rest=True)
        assert save.charges_left("act_nade") == 3
        save = _spend(save)
        assert save.charges_left("act_nade") == 2
        # B -> A: a SECOND refill. A's remaining one charge is gone, and
        # so is B's remaining two; there is only ever one supply.
        save = T.complete_zone(save, "zone_002")
        save = T.enter_zone(save, "zone_001")     # revisited
        assert save.charges_left("act_nade") == 3

    def test_the_generation_only_moves_on_a_refill(self):
        """It is the identity of the SUPPLY, not a message counter. Every
        entry that is not a refill has to leave it alone, or a use in
        flight across an ordinary re-entry would be refused as stale."""
        save = _in_a_zone(T.slot_action(_save(), "consumable", "act_nade"))
        deployed = save.consumable_generation
        assert T.enter_zone(save, "zone_001").consumable_generation \
            == deployed
        save = _spend(save)
        assert save.consumable_generation == deployed
        save = T.slot_action(save, "consumable", None)
        assert save.consumable_generation == deployed
        assert _restart(save).consumable_generation == deployed
        assert _in_another_zone(save).consumable_generation > deployed

    def test_swapping_away_and_back_preserves_expenditure(self):
        """Tracked by component identity, so the slot is not a hiding
        place for a fresh supply."""
        save = _in_a_zone(T.slot_action(_save(), "consumable", "act_nade"))
        save = _spend(save)
        save = T.slot_action(save, "consumable", None)
        save = T.slot_action(save, "consumable", "act_nade")
        assert save.charges_left("act_nade") == 2


class TestTheSpendTransaction:
    """`use_index` is a compare-and-swap, and these are the races it
    exists for. The client mints an index from the snapshot it has; the
    engine accepts it only if it is the next one due."""

    def test_two_presses_on_the_last_charge_spend_once(self):
        """Both presses mint the same index because neither has seen a
        snapshot yet. At most one activation may succeed."""
        save = T.slot_action(_save(), "consumable", "act_nade")
        save = _spend(save)
        save = _spend(save)
        assert save.charges_left("act_nade") == 1
        save = T.spend_charge(save, "act_nade", 3,
                              save.consumable_generation)
        assert save.charges_left("act_nade") == 0
        with pytest.raises(ValueError) as caught:
            T.spend_charge(save, "act_nade", 3,
                           save.consumable_generation)
        assert "no charges left" in str(caught.value)

    def test_a_duplicate_message_does_not_spend_twice(self):
        save = T.slot_action(_save(), "consumable", "act_nade")
        save = T.spend_charge(save, "act_nade", 1,
                              save.consumable_generation)
        assert save.charges_left("act_nade") == 2
        with pytest.raises(ValueError) as caught:
            T.spend_charge(save, "act_nade", 1,
                           save.consumable_generation)
        assert "not the next one due" in str(caught.value)
        assert save.charges_left("act_nade") == 2

    def test_an_index_that_runs_ahead_is_refused(self):
        save = T.slot_action(_save(), "consumable", "act_nade")
        with pytest.raises(ValueError):
            T.spend_charge(save, "act_nade", 2,
                           save.consumable_generation)



class TestStaleUsesAcrossARefill:
    """**THE INDEX ALONE CANNOT DO THIS JOB**, and the test that said it
    could passed for the wrong reason.

    The old case sent index 3 immediately after a refill and asserted a
    refusal. It got one — because 3 is not 1, which is arithmetic, and
    has nothing to do with the use being stale. It would have passed
    against an engine with no staleness rule at all, and it did.

    Both cases below are ones the index genuinely accepts. Each asserts
    the arithmetic that would have let it through FIRST, so the test
    cannot quietly stop being about staleness, and then asserts that the
    generation refuses it anyway.
    """

    def _two_deep_in_a_zone(self):
        """A deployment with two charges spent and a third in flight."""
        save = _in_a_zone(T.slot_action(_save(), "consumable", "act_nade"))
        save = _spend(save)
        save = _spend(save)
        return save, save.consumable_generation

    def test_an_old_use_1_cannot_eat_a_fresh_charge(self):
        """The case the old test never reached. A use minted at index 1
        before the refill arrives after it, when nothing has been spent
        — and index 1 IS the first index due. Accepted on arithmetic;
        refused on identity."""
        save = _in_a_zone(T.slot_action(_save(), "consumable", "act_nade"))
        stale = save.consumable_generation
        save = _in_another_zone(save)
        assert save.charges_left("act_nade") == 3
        # The arithmetic that would have accepted it:
        assert 1 == (3 - save.charges_left("act_nade")) + 1
        assert save.consumable_generation != stale
        with pytest.raises(ValueError) as caught:
            T.spend_charge(save, "act_nade", 1, stale)
        assert "minted against supply" in str(caught.value)
        assert save.charges_left("act_nade") == 3

    def test_an_old_index_is_refused_when_the_count_catches_up(self):
        """The slower version of the same hole. An old index 3 does not
        match immediately after a refill — but it matches again as soon
        as two legitimate new uses have been spent, and by then the
        refusal the old test relied on has evaporated."""
        save, stale = self._two_deep_in_a_zone()
        save = _in_another_zone(save)
        save = _spend(save)
        save = _spend(save)          # the new supply is now two deep too
        assert save.charges_left("act_nade") == 1
        # The arithmetic that would have accepted it:
        assert 3 == (3 - save.charges_left("act_nade")) + 1
        with pytest.raises(ValueError) as caught:
            T.spend_charge(save, "act_nade", 3, stale)
        assert "minted against supply" in str(caught.value)
        assert save.charges_left("act_nade") == 1

    def test_the_current_supply_still_spends(self):
        """The generation refuses stale uses and nothing else: the same
        index, against the supply it was minted for, goes through."""
        save, _ = self._two_deep_in_a_zone()
        save = _in_another_zone(save)
        save = _spend(save)
        save = _spend(save)
        save = T.spend_charge(save, "act_nade", 3,
                              save.consumable_generation)
        assert save.charges_left("act_nade") == 0

    def test_a_use_from_a_supply_that_does_not_exist_yet_is_refused(self):
        """Symmetry, and a client that has invented a number rather than
        echoed one. A generation ahead of the engine's is as wrong as one
        behind it, and is refused by the same equality."""
        save = _in_a_zone(T.slot_action(_save(), "consumable", "act_nade"))
        with pytest.raises(ValueError) as caught:
            T.spend_charge(save, "act_nade", 1,
                           save.consumable_generation + 1)
        assert "minted against supply" in str(caught.value)

    def test_the_zone_id_could_not_have_stood_in_for_it(self):
        """Why this is a generation and not the Zone id: the Zone id is
        reused on every return, so a use from the LAST visit to A names
        A just as correctly as one minted this visit. The generation is
        minted only by the refill, so the two visits differ."""
        save = _in_a_zone(T.slot_action(_save(), "consumable", "act_nade"))
        first_visit = save.consumable_generation
        save = _spend(save)
        save = _in_another_zone(save, rest=True)
        save = T.complete_zone(save, "zone_002")
        save = T.enter_zone(save, "zone_001")     # the same Zone id again
        assert save.consumable_deployment == "zone_001"   # unchanged
        assert save.consumable_generation != first_visit  # and yet: new
        with pytest.raises(ValueError):
            T.spend_charge(save, "act_nade", 1, first_visit)
