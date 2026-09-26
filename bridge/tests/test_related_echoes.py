"""THE OWNER'S DIRECTION ON RELATED ECHOES (2026-09-23), in the providers.

    "Similar or similar-sounding source items are an opportunity for
    Epsilon to upgrade an existing item OR create a new one. Similarity
    does not force a merge, and sharing an Action primitive does not
    establish that two items are the same family. [...] An upgrade must
    produce a meaningful, visible change. Preserve the existing item's
    useful function; a substantial trade-off should normally be a
    separate item/variant rather than an involuntary replacement. [...]
    Preserve source provenance, original multiworld delivery, and
    consumable expenditure."

What the deterministic providers do with it (`fallback._as_sequel`): a
sequel needs the same verb -- so the upgrade has a field to land on --
AND the same reading of the two SOURCES, AND the same slot; then a change
of at least a quarter of the field (`_MEANINGFUL`). The reading is each
provider's own: the fallback's rule table, which is also what builds the
item, and mock's catalog concept. The owner's examples are not a keyword
mapping; these are how these two providers happen to read.
"""
from __future__ import annotations

import inspect
import re

import pytest

from archipepsi_bridge.campaign import (
    budget_headroom, over_soft_budget, owned_summaries)
from archipepsi_bridge.epsilon import capabilities as CAP
from archipepsi_bridge.epsilon import fallback as F
from archipepsi_bridge.epsilon.claude import ECHO_SYSTEM
from archipepsi_bridge.epsilon.fallback import fallback_echo, reading_of
from archipepsi_bridge.epsilon.mock import _mock_echo, mock_reading
from archipepsi_bridge.epsilon.requests import (
    EchoGenerationRequest, EchoPlayerState, EchoSource, allowed_for)
from archipepsi_bridge.schemas import mechanics as M
from archipepsi_bridge.schemas import transitions as T
from archipepsi_bridge.schemas.echo import (
    EchoInterpretation, target_errors, upgradable_field_info)
from archipepsi_bridge.schemas.protocol import CampaignSave

GAME = "Ocarina of Time"


def _request(index: int, name: str, mechanics, *,
             consumable: bool = False) -> EchoGenerationRequest:
    """A request as the campaign builds one: the owned graph through the
    campaign's own `owned_summaries`, not a copy of it."""
    return EchoGenerationRequest(
        allowed=allowed_for(consumable=consumable),
        source=EchoSource(location_id=89100001 + index, item_name=name,
                          source_game=GAME, recipient_name="p",
                          item_flags=0),
        player_state=EchoPlayerState(
            owned_components=(() if mechanics is None
                              else owned_summaries(mechanics)),
            aliases=() if mechanics is None else tuple(mechanics.aliases)),
        required_echo_id=f"echo_{89100001 + index}",
        over_soft_budget=(() if mechanics is None
                          else over_soft_budget(mechanics)),
        budget_headroom=({} if mechanics is None
                         else budget_headroom(mechanics)))


def _fallback(request):
    return fallback_echo(request)


def _campaign(items, provider=_fallback):
    """`items` are names, or `(name, consumable)` pairs. Every
    interpretation clears the gates a model's would, and is folded."""
    log: list[EchoInterpretation] = []
    mechanics = None
    for index, item in enumerate(items):
        name, consumable = item if isinstance(item, tuple) else (item, False)
        raw = provider(_request(index, name, mechanics,
                                consumable=consumable))
        raw["interpretation_seq"] = index
        echo = EchoInterpretation.model_validate(raw)
        slots = (CAP.CANDIDATE_ACTION_SLOTS if consumable
                 else CAP.IMPLEMENTED_ACTION_SLOTS)
        assert CAP.validate_stage_support(echo, slots=slots) == [], name
        assert target_errors(echo, mechanics or M.EMPTY_MECHANICS) == [], name
        log.append(echo)
        mechanics = M.derive_mechanics(log)
    return log, mechanics


def _ops(log) -> list[str]:
    return [op.op for echo in log for op in echo.operations]


# ------------------------------------------------ a verb is not a family

def test_a_shared_primitive_is_not_a_family():
    """The case the direction settles. An Ocarina the fallback reads as
    nothing in particular -- its default, a thrown lob -- and then a Bomb
    Bag, also a lob. Keyed on the primitive alone (the rule before this),
    the Bomb Bag was the Ocarina's upgrade. They are a bomb and an
    ocarina."""
    assert reading_of("Ocarina") == "" and reading_of("Bomb Bag") == "explosive"
    log, mechanics = _campaign(["Ocarina", "Bomb Bag"])
    ocarina, bombs = (echo.operations[0].component for echo in log)
    assert ocarina.primitive.type == bombs.primitive.type == "arc_lob", (
        "the premise: one verb, two items")
    assert _ops(log) == ["create", "create"]
    kept = mechanics.by_id(ocarina.component_id)
    assert kept.mk == 1 and kept.component == ocarina


def test_two_items_nothing_reads_are_not_related():
    """"" is the fallback's default reading and names no kind of thing.
    With an Ocarina lob owned, a Gerudo Card read as the same default lob,
    in the same slot, is not its sequel. (A campaign seldom shows the pair
    by itself -- the default already steers a second item off a verb the
    player owns -- so it is set up directly and the rule is asked.)"""
    assert reading_of("Ocarina") == reading_of("Gerudo Card") == ""
    _, mechanics = _campaign(["Ocarina"])
    [ocarina] = mechanics.owned
    # The default is a hash of the item AND its location: at this one the
    # card is the same lob the Ocarina is.
    card = fallback_echo(_request(0, "Gerudo Card", None))
    [op] = card["operations"]
    assert op["component"]["primitive"]["type"] == "arc_lob" \
        == ocarina.component.primitive.type, "the premise: one verb"
    assert op["component"]["slot"] == ocarina.component.slot
    assert F._as_sequel(card, _request(0, "Gerudo Card", mechanics)) is None


# --------------------------------------------- related things do evolve

def test_a_related_item_upgrades_what_it_is_related_to():
    """The owner's example: bombs, then a Bomb Bag and a Bombchu that
    improve them. One thing at Mk III; what it was for is kept (the same
    verb, the same slot); every source is credited, each at the location
    it came from."""
    log, mechanics = _campaign(["Bombs", "Bomb Bag", "Bombchu"])
    assert _ops(log) == ["create", "upgrade", "upgrade"]
    [bombs] = mechanics.owned
    created = log[0].operations[0].component
    assert bombs.mk == 3
    assert bombs.component.primitive.type == created.primitive.type
    assert bombs.component.slot == created.slot
    assert [(p.source_item_name, p.source_location_id)
            for p in bombs.provenance] == [
        ("Bombs", 89100001), ("Bomb Bag", 89100002), ("Bombchu", 89100003)]
    assert all(echo.description.startswith("The same Bombs, ")
               for echo in log[1:])


def test_the_echoes_11_grapple_is_still_one_grapple():
    log, mechanics = _campaign(["Hookshot", "Longshot", "Clawshot"])
    assert _ops(log) == ["create", "upgrade", "upgrade"]
    assert len(mechanics.owned) == 1 and mechanics.owned[0].mk == 3


def test_a_consumable_does_not_upgrade_a_weapon_nor_the_reverse():
    """"Preserve the existing item's useful function": bombs you always
    have and a bag of three are two different things to hold, whatever
    they share. Each way round, the second is its own item; the same
    holding, and it is the first one's upgrade."""
    log, _ = _campaign(["Bombs", ("Bomb Bag", True)])
    assert _ops(log) == ["create", "create"]
    assert [e.operations[0].component.slot for e in log] == [
        "echo_a", "consumable"]
    log, _ = _campaign([("Bombs", True), "Bomb Bag"])
    assert _ops(log) == ["create", "create"]
    log, _ = _campaign([("Bombs", True), ("Bomb Bag", True)])
    assert _ops(log) == ["create", "upgrade"]


# ------------------------------------------------ meaningful and visible

@pytest.mark.parametrize("chain", [
    ["Hookshot", "Longshot", "Clawshot", "Hookshot", "Longshot"],
    ["Bombs", "Bomb Bag", "Bombchu", "Remote Bomb", "Bomb Flower"],
    ["Kokiri Sword", "Master Sword", "Biggoron Sword", "Razor Sword"],
    ["Pegasus Boots", "Hover Boots", "Iron Boots", "Speed Boots"],
])
def test_every_upgrade_the_fallback_makes_is_meaningful(chain):
    """"An upgrade must produce a meaningful, visible change": at least a
    quarter of the field's value, or the ladder's own step where that is
    larger, and inside the field's bounds. Measured against the value the
    field had BEFORE the upgrade, from the fold."""
    log, _ = _campaign(chain)
    ladder = dict(F._UPGRADE_LADDER)
    upgrades = 0
    for index, echo in enumerate(log):
        for op in echo.operations:
            if op.op != "upgrade":
                continue
            upgrades += 1
            before = M.derive_mechanics(log[:index]).by_id(op.target)
            [(current, low, high)] = [
                (c, lo, hi) for f, c, lo, hi
                in upgradable_field_info(before.component) if f == op.field]
            step = ladder[op.field]
            assert (op.delta > 0) == (step > 0), op
            assert abs(op.delta) >= max(abs(step), abs(current) * 0.25) \
                - 1e-6, (op.field, current, op.delta)
            assert low <= current + op.delta <= high
    assert upgrades >= 1, f"{chain} never evolved, so this proved nothing"


# ------------------------------------------- expenditure and provenance

def test_an_upgrade_leaves_consumable_expenditure_alone():
    """"Preserve ... consumable expenditure": a charge spent before the
    upgrade stays spent, and being upgraded refills nothing. Capacity
    itself is not something an upgrade can raise today (`charges` is not
    an upgradable field), so the bag's count is unchanged too."""
    save = CampaignSave(seed_name="S", team=0, slot_id=1, slot_name="p")
    cid = ""
    for index, name in enumerate(["Bombs", "Bomb Bag"]):
        live = save.derive()
        raw = fallback_echo(_request(index, name, live if index else None,
                                     consumable=True), mechanics=live)
        save = T.append_interpretation(
            save, EchoInterpretation.model_validate(raw))
        if index == 0:
            [bombs] = save.derive().owned
            cid = bombs.component_id
            save = T.spend_charge(save, cid, 1, save.consumable_generation)
            assert save.charges_left(cid) == 2
    [op] = save.interpretations[-1].operations
    assert op.op == "upgrade" and op.target == cid
    [bombs] = save.derive().owned
    assert bombs.component.charges == 3 and save.charges_left(cid) == 2
    assert bombs.provenance[-1].source_item_name == "Bomb Bag"
    assert bombs.provenance[-1].operation == "upgrade"


# ------------------------------------------------ one source of truth

def test_the_reading_is_the_rule_table_that_builds_the_item():
    """What builds an item and what says two items are one kind of thing
    read the same words: every keyword rule in the chain asks `reads(...)`
    of `_READINGS`, each once, and no rule keeps a private word list."""
    source = inspect.getsource(F._fallback_echo_create)
    used = re.findall(r'reads\("([a-z]+)"\)', source)
    assert sorted(used) == sorted(key for key, _, _ in F._READINGS)
    assert len(used) == len(set(used))
    assert "has(" not in source


# --------------------------------------------------- the other providers

def test_mock_judges_by_its_own_reading():
    """Mock reads items by its catalog concept; three it reads as
    `footing` are one thing to it, whatever their names share."""
    names = ["Hover Boots", "Iron Boots", "Pegasus Boots"]
    assert {mock_reading(name, GAME) for name in names} == {"mock:footing"}
    log, mechanics = _campaign(names, provider=_mock_echo)
    assert _ops(log) == ["create", "upgrade", "upgrade"]
    assert len(mechanics.owned) == 1 and mechanics.owned[0].mk == 3


def test_a_model_provider_is_told_the_same_rule():
    for phrase in ("similarity never forces a merge",
                   "Sharing an Action primitive does not make two items "
                   "the same family",
                   "`origin`", "`slot`", "meaningful, visible change",
                   "a substantial trade-off is a separate item"):
        assert phrase in ECHO_SYSTEM, phrase


def test_the_request_names_what_each_owned_thing_came_from():
    _, mechanics = _campaign(["Bombs", ("Bomb Bag", True)])
    summaries = {s.origin: s for s in owned_summaries(mechanics)}
    assert set(summaries) == {"Bombs", "Bomb Bag"}
    assert summaries["Bombs"].slot == "echo_a"
    assert summaries["Bomb Bag"].slot == "consumable"
    assert all(s.origin_game == GAME for s in summaries.values())
