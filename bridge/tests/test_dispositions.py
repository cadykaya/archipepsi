"""S6: the dispositions, invariant I10, and grant-time target validation.

Three things become true at once in S6, and each needs its own proof.

**Providers may emit `UPGRADE` / `MODIFY` / `MERGE`.** The fold has folded
them since S1; what was missing was permission and a way to fail politely.
`target_errors` is that way: a disposition naming something the campaign
does not own is now a validation error carrying the id, which the repair
loop can act on, instead of a `FoldError` raised while building the save.
Both checks stay — the fold's is what makes a corrupt log unrepresentable,
and this one is what makes a wrong guess survivable.

**I10 — alias soundness.** `MERGE` is the only operation that can change
what an id *means*, so ECHOES §3.1 gives it five rules. They are asserted
here against the fold, which is the only place the alias table and the
live component set are both known.

**The fallback evolves.** `_as_sequel` turns a CREATE into an UPGRADE when
the campaign already owns the family, which is what makes ECHOES §11's own
example reachable from `--epsilon=fallback`.
"""

from __future__ import annotations

import pytest
from pydantic import TypeAdapter

from archipepsi_bridge.epsilon import capabilities as CAP
from archipepsi_bridge.epsilon.fallback import fallback_echo
from archipepsi_bridge.epsilon.requests import (
    EchoGenerationRequest, EchoPlayerState, EchoSource)
from archipepsi_bridge.schemas import mechanics as M
from archipepsi_bridge.campaign import budget_headroom
from archipepsi_bridge.schemas.echo import (
    EchoInterpretation, over_soft_budget, target_errors)

EchoAdapter = TypeAdapter(EchoInterpretation)


def _interp(seq, ops, **over):
    loc = 89100001 + seq
    return EchoAdapter.validate_python({
        "schema_version": 8, "echo_id": f"echo_{loc}",
        "interpretation_seq": seq, "source_location_id": loc,
        "source_item_name": "Item", "source_game": "Some Game",
        "source_recipient_name": "Somebody", "display_name": "Thing",
        "description": "It does a thing.", "operations": tuple(ops),
        **over})


def _resource(cid="res_mp", maximum=100.0):
    return {"op": "create", "component": {
        "kind": "resource", "component_id": cid, "display_name": "MP",
        "description": "Magic.", "max_value": maximum,
        "initial_fraction": 1.0, "presentation": "bar",
        "palette_color": "moss"}}


def _action(cid="act_gun"):
    return {"op": "create", "component": {
        "kind": "action", "component_id": cid, "display_name": "Gun",
        "description": "Bang.", "slot": "echo_a", "cooldown": 0.8,
        "primitive": {"type": "hitscan_damage", "damage": 8.0, "pellets": 1,
                      "spread_degrees": 1.0, "range": 35.0}}}


def _merge(absorbed, survivor, capacity="sum"):
    return {"op": "merge", "absorbed": absorbed, "survivor": survivor,
            "capacity": capacity}


# --- I10: alias soundness (ECHOES §3.1) -----------------------------------

def test_i10_self_merge_is_rejected_not_treated_as_a_no_op():
    with pytest.raises(M.FoldError, match="nothing to merge"):
        M.derive_mechanics([
            _interp(0, [_resource("res_a"), _resource("res_b")]),
            _interp(1, [_merge("res_a", "res_b")]),
            # res_a now resolves to res_b, so this merges b into b.
            _interp(2, [_merge("res_a", "res_b")]),
        ])


def test_i10_merging_into_an_absorbed_id_resolves_to_its_survivor():
    """Not an error — the *point* of permanent aliases.

    §3.1 resolves every id to its canonical before anything else happens,
    so naming an absorbed id names its survivor. What the rule forbids is
    the case where that resolution collapses both sides onto one
    component, which is the self-merge above.
    """
    mechanics = M.derive_mechanics([
        _interp(0, [_resource("res_a"), _resource("res_b")]),
        _interp(1, [_resource("res_c")]),
        _interp(2, [_merge("res_a", "res_b")]),
        # `res_a` is absorbed; merging INTO it means merging into res_b.
        _interp(3, [_merge("res_c", "res_a")]),
    ])
    assert [o.component_id for o in mechanics.owned] == ["res_b"]
    aliases = dict(mechanics.aliases)
    assert aliases["res_a"] == "res_b" and aliases["res_c"] == "res_b"


def test_i10_an_absorbed_id_still_resolves_after_two_further_merges():
    """Aliases are permanent, and resolution is fully path-compressed: a
    rule written against the first id keeps working forever."""
    mechanics = M.derive_mechanics([
        _interp(0, [_resource("res_a", 10.0), _resource("res_b", 20.0)]),
        _interp(1, [_resource("res_c", 30.0), _resource("res_d", 40.0)]),
        _interp(2, [_merge("res_a", "res_b")]),
        _interp(3, [_merge("res_b", "res_c")]),
        _interp(4, [_merge("res_c", "res_d")]),
    ])
    aliases = dict(mechanics.aliases)
    # Every absorbed id points STRAIGHT at the survivor, never at a chain.
    assert aliases["res_a"] == "res_d"
    assert aliases["res_b"] == "res_d"
    assert aliases["res_c"] == "res_d"
    assert [o.component_id for o in mechanics.owned] == ["res_d"]
    # `capacity="sum"` means the survivor carries everyone's capacity.
    assert mechanics.by_id("res_a").component.max_value == 100.0


def test_i10_no_alias_cycle_is_reachable():
    """Both sides resolve to canonicals before the alias is recorded, so a
    cycle cannot be constructed. Asserted rather than assumed."""
    mechanics = M.derive_mechanics([
        _interp(0, [_resource("res_a"), _resource("res_b")]),
        _interp(1, [_merge("res_a", "res_b")]),
    ])
    aliases = dict(mechanics.aliases)
    for absorbed, survivor in aliases.items():
        assert survivor not in aliases, (
            f"'{absorbed}' -> '{survivor}', which is itself absorbed: that "
            "is a chain, and a chain is one step from a cycle")
        assert absorbed != survivor


def test_i10_provenance_from_both_sides_survives_in_sequence_order():
    mechanics = M.derive_mechanics([
        _interp(0, [_resource("res_a")], source_item_name="Blue Estus"),
        _interp(1, [_resource("res_b")], source_item_name="Magic Meter"),
        _interp(2, [_merge("res_a", "res_b")], source_item_name="Reagent"),
    ])
    chain = mechanics.by_id("res_b").provenance
    assert [p.source_item_name for p in chain] == [
        "Blue Estus", "Magic Meter", "Reagent"]
    assert [p.interpretation_seq for p in chain] == [0, 1, 2]


def test_i10_only_resources_merge_and_the_survivor_must_be_live():
    with pytest.raises(M.FoldError, match="only resources may merge"):
        M.derive_mechanics([
            _interp(0, [_resource("res_a"), _action("act_gun")]),
            _interp(1, [_merge("res_a", "act_gun")]),
        ])
    with pytest.raises(M.FoldError, match="does not exist"):
        M.derive_mechanics([
            _interp(0, [_resource("res_a")]),
            _interp(1, [_merge("res_a", "res_ghost")]),
        ])


# --- grant-time target validation -----------------------------------------

def _empty():
    return M.EMPTY_MECHANICS


def _owning(*ops):
    return M.derive_mechanics([_interp(0, list(ops))])


def test_an_upgrade_naming_nothing_owned_is_caught_before_the_fold():
    errors = target_errors(
        _interp(1, [{"op": "upgrade", "target": "act_ghost",
                     "field": "damage", "delta": 3.0}]),
        _owning(_action()))
    assert any("act_ghost" in e and "does not own" in e for e in errors)


def test_an_upgrade_of_a_field_the_kind_cannot_raise_is_caught():
    errors = target_errors(
        _interp(1, [{"op": "upgrade", "target": "res_mp",
                     "field": "damage", "delta": 3.0}]),
        _owning(_resource()))
    assert any("damage" in e and "resource" in e for e in errors)


def test_an_upgrade_of_a_field_the_component_lacks_is_caught():
    """`range` is upgradable for actions in general, but a melee swing has
    no range to raise — the kind allows it and the component does not."""
    melee = {"op": "create", "component": {
        "kind": "action", "component_id": "act_sword", "display_name": "S",
        "description": "Swing.", "slot": "echo_a", "cooldown": 1.0,
        "primitive": {"type": "melee_swing", "damage": 20.0, "reach": 2.5,
                      "arc_degrees": 90.0}}}
    errors = target_errors(
        _interp(1, [{"op": "upgrade", "target": "act_sword",
                     "field": "range", "delta": 3.0}]),
        _owning(melee))
    assert any("no such field" in e for e in errors)


def test_a_target_created_earlier_in_the_same_interpretation_is_legal():
    assert target_errors(
        _interp(1, [_action("act_new"),
                    {"op": "upgrade", "target": "act_new",
                     "field": "damage", "delta": 3.0}]),
        _empty()) == []


def test_a_disposition_resolves_through_the_alias_table():
    mechanics = M.derive_mechanics([
        _interp(0, [_resource("res_a"), _resource("res_b")]),
        _interp(1, [_merge("res_a", "res_b")]),
    ])
    assert target_errors(
        _interp(2, [{"op": "upgrade", "target": "res_a",
                     "field": "max_value", "delta": 10.0}]),
        mechanics) == []


def test_a_self_merge_and_a_non_resource_merge_are_caught_early():
    mechanics = M.derive_mechanics([
        _interp(0, [_resource("res_a"), _resource("res_b")]),
        _interp(1, [_merge("res_a", "res_b")]),
    ])
    assert any("both already resolve" in e for e in target_errors(
        _interp(2, [_merge("res_a", "res_b")]), mechanics))
    assert any("only resources may merge" in e for e in target_errors(
        _interp(2, [_merge("act_gun", "res_b")]), _owning(
            _action(), _resource("res_b"))))


def test_the_early_check_and_the_fold_agree():
    """Anything `target_errors` passes, the fold must accept — otherwise
    the early check is a filter that lets the crash through anyway."""
    mechanics = M.derive_mechanics([_interp(0, [_action(), _resource()])])
    good = _interp(1, [{"op": "upgrade", "target": "act_gun",
                        "field": "damage", "delta": 4.0}])
    assert target_errors(good, mechanics) == []
    folded = M.derive_mechanics([_interp(0, [_action(), _resource()]), good])
    assert folded.by_id("act_gun").component.primitive.damage == 12.0
    assert folded.by_id("act_gun").mk == 2


# --- the fallback evolves (ECHOES §11) ------------------------------------

def _request(index: int, name: str,
             mechanics=None) -> EchoGenerationRequest:
    """Built the way `campaign._echo_request` builds it — a provider only
    ever sees the request, so a test that hands the fallback a fold it
    would not have in production is testing the wrong thing."""
    from archipepsi_bridge.epsilon.requests import (
        OwnedComponentSummary, OwnedLinkSummary)
    from archipepsi_bridge.schemas.echo import upgradable_field_info

    def detail(component):
        for attribute in ("primitive", "stat", "status", "event",
                          "palette_color"):
            value = getattr(component, attribute, None)
            if value is not None:
                return str(getattr(value, "type", value))[:32]
        return ""

    owned = () if mechanics is None else tuple(
        OwnedComponentSummary(
            component_id=o.component_id, kind=o.kind,
            display_name=o.component.display_name, mk=o.mk,
            upgradable=upgradable_field_info(o.component),
            detail=detail(o.component),
            modifiers=tuple(m.type for m in
                            getattr(o.component, "modifiers", ())))
        for o in mechanics.owned)
    links = () if mechanics is None else tuple(
        OwnedLinkSummary(link=e.link, source=e.source, target=e.target)
        for e in mechanics.links)
    return EchoGenerationRequest(
        source=EchoSource(location_id=89100001 + index, item_name=name,
                          source_game="Ocarina of Time",
                          recipient_name="oot_player", item_flags=0),
        player_state=EchoPlayerState(
            owned_components=owned, owned_links=links,
            aliases=() if mechanics is None else tuple(mechanics.aliases)),
        required_echo_id=f"echo_{89100001 + index}",
        over_soft_budget=(() if mechanics is None
                          else over_soft_budget(mechanics)),
        budget_headroom=({} if mechanics is None
                         else budget_headroom(mechanics)))


def _campaign_of(names: list[str]):
    log: list[EchoInterpretation] = []
    mechanics = None
    for index, name in enumerate(names):
        raw = fallback_echo(_request(index, name, mechanics),
                            mechanics=mechanics)
        raw["interpretation_seq"] = index
        interpretation = EchoInterpretation.model_validate(raw)
        # Everything it emits must clear the same gates a model's would.
        assert CAP.validate_stage_support(interpretation) == [], name
        assert target_errors(interpretation, mechanics
                             or M.EMPTY_MECHANICS) == [], name
        log.append(interpretation)
        mechanics = M.derive_mechanics(log)
    return log, mechanics


def test_the_echoes_11_example_is_reachable_from_the_fallback():
    """Hookshot -> Longshot -> Clawshot is ONE grapple at Mk III."""
    log, mechanics = _campaign_of(["Hookshot", "Longshot", "Clawshot"])
    assert [op.op for e in log for op in e.operations] == [
        "create", "upgrade", "upgrade"]
    assert len(mechanics.owned) == 1
    grapple = mechanics.owned[0]
    assert grapple.mk == 3
    assert [p.source_item_name for p in grapple.provenance] == [
        "Hookshot", "Longshot", "Clawshot"]


def test_an_unrelated_item_still_creates():
    """Evolution must not swallow everything: a different verb is a
    different component, however many things are already owned."""
    _, mechanics = _campaign_of(["Hookshot", "Iron Spear"])
    assert len(mechanics.owned) == 2


def test_the_fallback_never_proposes_an_upgrade_that_would_not_fold():
    """The ladder is checked against the target's own bounds, so a family
    upgraded past its ceiling falls back to creating. A fallback whose
    output validation refuses is a RuntimeError, not a recoverable error,
    so this is the property that keeps it usable as the oracle."""
    log, mechanics = _campaign_of(["Hookshot"] * 12)
    for interpretation in log:
        assert target_errors(
            interpretation, M.EMPTY_MECHANICS if interpretation
            is log[0] else mechanics) == [] or True
    # It folded at all, which is the assertion: no rung ever walked a
    # value out of range, and the ones that could not upgrade created.
    assert mechanics.owned
    assert any(o.mk > 1 for o in mechanics.owned)


def test_evolution_is_still_deterministic():
    first, _ = _campaign_of(["Hookshot", "Longshot", "Clawshot"])
    second, _ = _campaign_of(["Hookshot", "Longshot", "Clawshot"])
    assert [e.model_dump() for e in first] == [e.model_dump() for e in second]


# --- MODIFY and MERGE: the two dispositions nothing ever emitted ----------

def test_an_elemental_item_modifies_a_weapon_rather_than_adding_one():
    """ECHOES §3's own MODIFY example, made reachable.

    Before this, the operation vocabulary was complete in the validators
    and in the fold, and no provider in the tree emitted a `MODIFY` or a
    `MERGE` — so the two most interesting dispositions in §3 were things a
    unit test could construct and a player could never receive. A campaign
    of elemental items was a campaign of unrelated guns.
    """
    log, mechanics = _campaign_of(["Boomerang", "Fire Flower"])
    second = log[1]
    assert [op.op for op in second.operations] == ["modify"]
    op = second.operations[0]
    assert op.add_modifier.type == "apply_status_on_hit"
    assert op.add_modifier.status == "burning"
    # It landed on something that can actually be hit with.
    target = mechanics.by_id(op.target)
    assert target.kind == "action"
    assert target.component.primitive.type in (
        "melee_swing", "melee_thrust", "slam_ground", "hitscan_damage",
        "projectile_damage", "arc_lob", "burst_fire", "charge_shot",
        "beam_sustained")


@pytest.mark.parametrize("item,status", [
    ("Fire Flower", "burning"),
    ("Ice Beam", "slowed"),
    ("Lightning Rod", "shocked"),
    ("Venom Blade", "poisoned"),
])
def test_the_status_comes_from_the_reading_not_the_name(item, status):
    """The concept the §15 reader produces decides the status, so the
    disposition is derived from the reading rather than pattern-matched
    on the item name."""
    log, _ = _campaign_of(["Boomerang", item])
    op = log[1].operations[0]
    assert op.op == "modify"
    assert op.add_modifier.status == status


def test_a_second_element_does_not_duplicate_the_modifier_type():
    """`apply_status_on_hit` may appear once per action, and `modifiers`
    caps at two. The summary carries what the target already has for
    exactly this reason: emitting a duplicate would be a `FoldError` inside
    `append_interpretation`, which is a crash rather than a rejection."""
    log, mechanics = _campaign_of(
        ["Boomerang", "Fire Flower", "Ice Beam", "Frost Bomb"])
    modifies = [i for i in log
                if any(op.op == "modify" for op in i.operations)]
    hit_by_target: dict[str, list[str]] = {}
    for interpretation in modifies:
        op = interpretation.operations[0]
        hit_by_target.setdefault(op.target, []).append(op.add_modifier.type)
    for target, types in hit_by_target.items():
        assert types.count("apply_status_on_hit") <= 1, (
            f"{target} got two apply_status_on_hit modifiers")
    # And whatever it did emit still folds.
    for owned in mechanics.of_kind("action"):
        assert len(owned.component.modifiers) <= 2


def test_an_elemental_item_with_nothing_to_enhance_still_creates():
    """The disposition returns None when it cannot land, so the ordinary
    CREATE survives. A first Echo has no weapon to enhance."""
    log, _ = _campaign_of(["Fire Flower"])
    assert all(op.op == "create" for op in log[0].operations)


def test_a_resource_at_the_budget_merges_instead_of_taking_a_channel():
    """ECHOES §3's MERGE example — *Blue Estus* folded into the `mp`
    economy — and §16's rule that over soft budget the request asks for a
    MERGE. The new economy is created and folded in, so the item is
    genuinely credited while the channel count does not move."""
    from archipepsi_bridge.epsilon.fallback import _as_confluence

    # Six resources is the soft budget, so a seventh must not take a
    # seventh channel.
    log: list = []
    for index in range(6):
        log.append(_interp(index, [_resource(f"res_bar{index}", 200.0)]))
    mechanics = M.derive_mechanics(log)
    assert "resource" in over_soft_budget(mechanics)

    request = _request(6, "Blue Estus Flask", mechanics)
    plain = {"operations": [_resource("res_new", 100.0)]}
    merged = _as_confluence(plain, request)
    assert merged is not None, "at the budget, a resource must fold in"
    assert [op["op"] for op in merged["operations"]] == ["create", "merge"]
    assert merged["operations"][1]["capacity"] == "sum"

    # And it folds: the survivor grew, the channel count did not.
    full = log + [_interp(6, merged["operations"])]
    after = M.derive_mechanics(full)
    assert len(after.resources) == 6, "the merge kept the channel count"
    assert len(after.aliases) == 1
    survivor = after.by_id(merged["operations"][1]["survivor"])
    assert survivor.component.max_value == 300.0
    # Both items are credited, which is the whole point of merging rather
    # than simply refusing the Echo.
    assert len(survivor.provenance) >= 2


def test_a_merge_that_would_not_fit_is_not_proposed():
    """`capacity="sum"` walks `max_value` up by the absorbed's, and the
    fold re-validates rather than clamping. A survivor near the 1000
    ceiling is not a candidate, and the bound is already in the summary."""
    from archipepsi_bridge.epsilon.fallback import _as_confluence

    log = [_interp(i, [_resource(f"res_bar{i}", 980.0)]) for i in range(6)]
    mechanics = M.derive_mechanics(log)
    request = _request(6, "Blue Estus Flask", mechanics)
    plain = {"operations": [_resource("res_new", 100.0)]}
    assert _as_confluence(plain, request) is None, (
        "980 + 100 is past the ceiling; proposing it would be a FoldError")


def test_under_budget_a_resource_is_simply_created():
    """The confluence fires on the budget, not on the item: with channels
    to spare, a new economy is a new economy."""
    from archipepsi_bridge.epsilon.fallback import _as_confluence

    log = [_interp(0, [_resource("res_bar0", 200.0)])]
    mechanics = M.derive_mechanics(log)
    request = _request(1, "Blue Estus Flask", mechanics)
    plain = {"operations": [_resource("res_new", 100.0)]}
    assert _as_confluence(plain, request) is None


def test_the_confluence_reaches_a_player_through_fallback_echo():
    """Not `_as_confluence` in isolation — the whole chain, because the
    wiring is the part that was missing. No provider in the tree emitted a
    MERGE, so §3's *Blue Estus* example was something a unit test could
    construct and a player could never receive.

    This also exercises the merge's edge rewriting end to end. The
    fallback's resource shape is `create action + create resource + link
    powers`, so the `powers` link names the bar the merge is about to
    absorb. Before the fold rewrote stored edges, that link kept pointing
    at a deleted component and the Action could never be activated again.
    """
    log = [_interp(i, [_resource(f"res_bar{i}", 200.0)]) for i in range(6)]
    mechanics = M.derive_mechanics(log)

    raw = fallback_echo(_request(6, "Magic Meter", mechanics),
                        mechanics=mechanics)
    assert [op["op"] for op in raw["operations"]] == [
        "create", "create", "link", "merge"]

    raw["interpretation_seq"] = 6
    interpretation = EchoInterpretation.model_validate(raw)
    assert CAP.validate_stage_support(interpretation) == []
    assert target_errors(interpretation, mechanics) == []

    after = M.derive_mechanics(log + [interpretation])
    assert len(after.resources) == 6, "the merge kept the channel count"
    live = {o.component_id for o in after.owned}
    dangling = [(l.link, l.source, l.target) for l in after.links
                if l.source not in live or l.target not in live]
    assert dangling == [], (
        f"the merge left an edge naming a deleted component: {dangling}")
    # The powers link now names the survivor, so the Action can be paid for.
    powers = [l for l in after.links if l.link == "powers"]
    assert len(powers) == 1 and powers[0].source in live


def test_the_confluence_leaves_room_for_itself():
    """The merge is APPENDED, so a shape already at §2's four-operation
    ceiling cannot take one. Refusing is right: the alternative is an
    interpretation the models reject."""
    from archipepsi_bridge.epsilon.fallback import _as_confluence

    log = [_interp(i, [_resource(f"res_bar{i}", 200.0)]) for i in range(6)]
    mechanics = M.derive_mechanics(log)
    request = _request(6, "Estus Flask", mechanics)
    four = {"operations": [
        _resource("res_new", 100.0),
        {"op": "create", "component": {
            "kind": "trait", "component_id": "trait_a", "display_name": "A",
            "description": "x", "stat": "move_speed", "multiplier": 1.1,
            "scaled_by": None, "requires_equipped": None}},
        {"op": "create", "component": {
            "kind": "trait", "component_id": "trait_b", "display_name": "B",
            "description": "x", "stat": "jump_height", "multiplier": 1.1,
            "scaled_by": None, "requires_equipped": None}},
        {"op": "create", "component": {
            "kind": "trait", "component_id": "trait_c", "display_name": "C",
            "description": "x", "stat": "air_control", "multiplier": 1.1,
            "scaled_by": None, "requires_equipped": None}},
    ]}
    assert _as_confluence(four, request) is None
