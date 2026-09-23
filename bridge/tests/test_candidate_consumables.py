"""O05-11: the consumable slot, for the candidate profile only.

`capabilities.IMPLEMENTED_ACTION_SLOTS` withholds `consumable` (staged,
twice, for reasons its comment gives). The owner's O05-11.4 promotes it
for the explicit overnight candidate profile only: a request built under
the profile's `consumables` option advertises the slot, the acceptance
gate admits exactly what was advertised, and the deterministic provider
reads an item that is a consumable as one. Production is unchanged,
and the test that pins its staging (`test_s1_review_fixes`) is untouched.
"""
from __future__ import annotations

from pathlib import Path

import pytest

from archipepsi_bridge import candidate
from archipepsi_bridge import store
from archipepsi_bridge import transactions as TX
from archipepsi_bridge.campaign import CampaignEngine
from archipepsi_bridge.epsilon import capabilities as CAP
from archipepsi_bridge.epsilon.fallback import (
    FallbackEpsilonProvider, fallback_echo)
from archipepsi_bridge.epsilon.requests import (
    EchoGenerationRequest, EchoPlayerState, EchoSource, allowed_for)

from archipepsi_bridge.mock_ap import MockAPBackend
from archipepsi_bridge.schemas.echo import (
    EchoInterpretation, validate_interpretation)

from .conftest import drain, enter_zone, run


def _request(item: str, *, consumable: bool) -> EchoGenerationRequest:
    return EchoGenerationRequest(
        allowed=allowed_for(consumable=consumable),
        source=EchoSource(location_id=89100011, item_name=item,
                          source_game="A Link to the Past",
                          recipient_name="Skyiah", item_flags=1),
        player_state=EchoPlayerState(),
        required_echo_id="echo_89100011")


def _engine(path: Path, *profile: str) -> CampaignEngine:
    return CampaignEngine(provider=FallbackEpsilonProvider(),
                          provider_name="fallback", save_dir=path,
                          candidate_steps=tuple(profile))


# ------------------------------------------------------------ advertising

def test_production_still_withholds_the_consumable_slot():
    assert "consumable" not in allowed_for()["slots"]
    assert allowed_for()["slots"] == list(CAP.IMPLEMENTED_ACTION_SLOTS)
    assert EchoGenerationRequest.model_fields["allowed"].default_factory() \
        == allowed_for()


def test_the_candidate_option_advertises_all_five():
    assert allowed_for(consumable=True)["slots"] == list(
        CAP.CANDIDATE_ACTION_SLOTS)
    assert "consumable" in CAP.CANDIDATE_ACTION_SLOTS


def test_the_option_is_not_a_zone_step(tmp_path):
    """Every "is the profile on" test in the engine asks about Zone
    composition. An option alone must not switch those on."""
    engine = _engine(tmp_path, "consumables")
    assert engine.candidate_steps == ()
    assert engine.candidate_options == ("consumables",)
    engine = _engine(tmp_path, *candidate.parse("all"))
    assert engine.candidate_steps == candidate.STEPS
    assert engine.candidate_options == candidate.OPTIONS
    assert _engine(tmp_path).candidate_options == ()


# ------------------------------------------------------------ the gate

def _bomb(consumable: bool) -> EchoInterpretation:
    raw = fallback_echo(_request("Bomb Bag", consumable=consumable))
    return EchoInterpretation.model_validate(raw)


def test_the_gate_admits_exactly_what_was_advertised():
    bomb = _bomb(consumable=True)
    assert CAP.validate_stage_support(bomb) != [], (
        "production's gate admitted the consumable slot")
    assert CAP.validate_stage_support(
        bomb, slots=CAP.CANDIDATE_ACTION_SLOTS) == []


# ---------------------------------------------------- the provider's reading

def test_a_bomb_bag_is_a_weapon_unless_the_slot_is_offered():
    weapon = _bomb(consumable=False).operations[0].component
    assert weapon.slot == "echo_a" and weapon.charges is None
    assert weapon.primitive.type == "arc_lob"


def test_offered_the_slot_a_bomb_bag_is_three_bombs_that_stun():
    """O05-11.3: real damage and a supported Status, through the normal
    interpretation path -- the same lob and blast as the weapon reading,
    counted."""
    interpretation = _bomb(consumable=True)
    action = interpretation.operations[0].component
    assert action.slot == "consumable" and action.charges == 3
    assert action.primitive.type == "arc_lob"
    assert action.primitive.damage > 0
    [rider] = action.modifiers
    assert rider.type == "apply_status_on_hit" and rider.status == "stunned"
    assert validate_interpretation(
        interpretation, expected_source_location_id=89100011) == []
    weapon = _bomb(consumable=False).operations[0].component
    assert action.primitive == weapon.primitive


def test_nothing_else_changes_reading_when_the_slot_is_offered():
    for item in ("Spear of Justice", "Warp Whistle", "Hookshot Chain",
                 "Glider Cape", "Ember"):
        assert fallback_echo(_request(item, consumable=True))[
            "operations"] == fallback_echo(
                _request(item, consumable=False))["operations"], item


# --------------------------------------------- acquired, used, reloaded

async def _buy_a_stocked_bomb_bag(engine) -> int | None:
    """The Hub shop is where this campaign sells its Bomb Bag (§11): buy
    it with the campaign's own coins when it is stocked and affordable."""
    if engine.save is None or engine.save.shop is None:
        return None
    for stock in engine.save.shop.stock:
        loc = stock.location_id
        if engine.ap.scouts[loc].item_name != "Bomb Bag":
            continue
        try:
            await TX.buy_shop_stock(engine, loc)
        except Exception:                   # not affordable yet
            return None
        await drain()
        return loc
    return None


async def _claim_the_bomb_bag(engine) -> int:
    """Play the campaign -- every allocated Check claimed, Zone after
    Zone -- until a Bomb Bag is acquired, from a Check or from the shop.
    Returns its location."""
    for _ in range(40):
        bought = await _buy_a_stocked_bomb_bag(engine)
        if bought is not None:
            return bought
        hub = engine.hub_status()
        if hub.postgame:
            break
        if hub.mode == "ZONE_AVAILABLE":
            await engine.handle_request_next_zone(hub.finale_offered)
            if engine._generation_task is not None:
                await engine._generation_task
            await drain()
            continue
        if hub.mode in ("ZONE_READY", "ZONE_ACTIVE"):
            record = engine.save.active_zone
            if record.state == "GENERATED":
                await enter_zone(engine, record.zone_id)
            for loc in sorted(record.allocated_location_ids):
                await TX.claim_check(engine, record.zone_id, loc)
                await drain()
                if engine.ap.scouts[loc].item_name == "Bomb Bag":
                    return loc
            continue
        if hub.mode == "GENERATING":
            if engine._generation_task is not None:
                await engine._generation_task
            await drain()
            continue
        break
    raise AssertionError("no Bomb Bag was reached")


#: The first Check the default mock seed's first Zone claims, and where
#: the one Bomb Bag of the prototype campaign sits.
_FIRST_CLAIM = 89100005
_BOMB_BAG = 89100011


async def _campaign(tmp_path, *profile: str, arrange: bool):
    engine = _engine(tmp_path, *profile)
    backend = MockAPBackend(engine)
    if arrange:
        # ARRANGED, AND SAID SO. In the mock's own campaigns every Bomb
        # Bag meets an owned lob first -- the fallback's default reading
        # of an unmatched item is a thrown `arc_lob` -- and the sequel
        # rule folds it into that weapon (the test below pins that, and
        # the ledger records the open question). So the first Check is
        # given the Bomb Bag's placement. Nothing after this line is
        # arranged: the claim, the reading, the validation, the fold, the
        # slot, the spend and the reload are the real ones. Only the NAME
        # moves: the location keeps its own item id, recipient and flags,
        # so the allocator places it exactly where it placed it before.
        _, item_id, slot, flags = backend.placements[_FIRST_CLAIM]
        backend.placements[_FIRST_CLAIM] = ("Bomb Bag", item_id, slot, flags)
    engine.backend = backend
    await backend.connect("", "Skyiah", "")
    await drain()
    loc = await _claim_the_bomb_bag(engine)
    return engine, loc


def test_the_candidate_acquires_uses_and_keeps_a_bomb_bag(tmp_path):
    """O05-11.3/.4 through the real engine: under the candidate option the
    Check holding a Bomb Bag is claimed, the fallback reads it as a
    consumable, the fold owns it, it is slotted, a use is authorised and
    settled, and the count survives a reload from disk."""
    engine, loc = run(_campaign(tmp_path, "consumables", arrange=True))
    assert loc == _FIRST_CLAIM
    owned = [o for o in engine.save.derive().owned
             if o.kind == "action" and o.component.slot == "consumable"]
    assert len(owned) == 1, "the Bomb Bag was not folded as a consumable"
    cid = owned[0].component_id
    assert cid.endswith(f"l{loc}")
    assert owned[0].component.charges == 3
    assert engine.save.charges_left(cid) == 3

    async def use():
        await engine.handle_slot_action("consumable", cid)
        generation = engine.save.consumable_generation
        await engine.handle_authorize_consumable(cid, 1, generation)
        await engine.handle_use_consumable(cid, 1, generation)
    run(use())
    assert engine.save.slots.consumable == cid
    assert engine.save.charges_left(cid) == 2

    reloaded = store.load_save(engine._save_path)
    assert reloaded is not None and reloaded.charges_left(cid) == 2
    assert reloaded.slots.consumable == cid


def test_production_reads_the_same_bomb_bag_as_a_weapon(tmp_path):
    """The same arranged campaign without the option: the slot is not
    offered, the Bomb Bag is the lob weapon it always was."""
    engine, loc = run(_campaign(tmp_path, arrange=True))
    [bomb] = [o for o in engine.save.derive().owned
              if o.component_id.endswith(f"l{loc}")]
    assert bomb.component.slot == "echo_a" and bomb.component.charges is None


def test_in_the_mock_s_own_campaign_the_sequel_rule_takes_it(tmp_path):
    """THE RECORDED BOUNDARY, pinned. Unarranged, the prototype campaign
    reaches its Bomb Bag in the Hub shop after it already owns a lob, and
    `_as_sequel` -- ECHOES §11, "a sequel when the campaign already owns
    the item's verb", with the family keyed on the primitive alone --
    turns the consumable CREATE into that weapon's UPGRADE. Whether a
    consumable shares a family with a verb you always have is not
    settled by any accepted source; this changes only on that decision."""
    engine, loc = run(_campaign(tmp_path, "consumables", arrange=False))
    assert loc == _BOMB_BAG
    [op] = engine.save.interpretations[-1].operations
    assert op.op == "upgrade"
    target = next(o for o in engine.save.derive().owned
                  if o.component_id == op.target)
    assert target.component.primitive.type == "arc_lob"
    assert target.component.slot != "consumable"
