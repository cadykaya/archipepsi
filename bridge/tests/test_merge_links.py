"""A merge must move the edges, not just the name.

`MERGE` is the one operation that changes what an id MEANS, and §3.1 makes
that change permanent. The fold rewrote the alias table, the component set,
the provenance, the Mk levels and the channel order — and left `links`
pointing at a component it had just deleted.

The client is not equipped to notice. `echo_runtime.gd::_powers_link` says
in as many words that "the fold already resolved merge aliases, so ids here
are canonical", and every consumer downstream of it takes that at face
value: `_pay_powers_cost` spends from `link.source`, `_apply_fills` refills
`link.target`, `_gates_open` reads `link.source`, `stat_stack` keys a dict
on `link.target`. A bar that no longer exists reads as 0 of 0, so the spend
always refuses, the gate never opens, the fill writes into nothing and the
scale pins at zero. The Echo does not break loudly; it stops working, for
the rest of the campaign, because aliases are permanent.

The second half of this file is the shape that bug could take again. Two of
the four link kinds are read as at-most-one-per-target, and the fold used
to allow a second one — which the client then discarded silently, picking
by fold order.
"""

from __future__ import annotations

import pytest

from archipepsi_bridge.schemas import mechanics as M

from .test_dispositions import _action, _interp, _merge, _resource


def _trait(cid="trait_speed", stat="move_speed"):
    return {"op": "create", "component": {
        "kind": "trait", "component_id": cid, "display_name": "Quick",
        "description": "Faster.", "stat": stat, "multiplier": 1.2,
        "requires_equipped": None, "scaled_by": None}}


def _beam(cid="act_beam"):
    return {"op": "create", "component": {
        "kind": "action", "component_id": cid, "display_name": "Beam",
        "description": "Zap.", "slot": "echo_a", "cooldown": 0.5,
        "primitive": {"type": "beam_sustained", "damage_per_second": 12.0,
                      "range": 20.0, "drain_per_second": 8.0}}}


def _link(kind, source, target, strength=5.0):
    return {"op": "link", "link": kind, "source": source, "target": target,
            "strength": strength}


def _edges(mechanics, kind):
    return [l for l in mechanics.links if l.link == kind]


# --- the edges move ------------------------------------------------------

def test_a_powers_edge_follows_its_resource_through_a_merge():
    """The reviewer's reproduction: the Echo that could never fire again."""
    mechanics = M.derive_mechanics([
        _interp(0, [_resource("res_a"), _resource("res_b"), _beam()]),
        _interp(1, [_link("powers", "res_a", "act_beam")]),
        _interp(2, [_merge("res_a", "res_b")]),
    ])
    assert [o.component_id for o in mechanics.resources] == ["res_b"]
    powers = _edges(mechanics, "powers")
    assert len(powers) == 1
    assert powers[0].source == "res_b", (
        "the client spends from link.source and res_a is gone; a raw id "
        "here is an ability that can never be activated again")


@pytest.mark.parametrize("kind,source,target", [
    ("powers", "res_a", "act_beam"),
    ("gates", "res_a", "act_beam"),
    ("fills", "act_beam", "res_a"),
    ("scales", "res_a", "trait_speed"),
])
def test_every_link_kind_follows_the_merge(kind, source, target):
    """All four, because each fails differently and all four fail silently:
    a dead `gates` source closes the gate forever, a dead `fills` target
    refills a channel whose maximum reads 0, and a dead `scales` source
    pins the fraction at 0 and neutralises the trait."""
    mechanics = M.derive_mechanics([
        _interp(0, [_resource("res_a"), _resource("res_b"), _beam(),
                    _trait()]),
        _interp(1, [_link("powers", "res_b", "act_beam"),
                    _link(kind, source, target)]),
        _interp(2, [_merge("res_a", "res_b")]),
    ])
    moved = [l for l in mechanics.links if l.link == kind]
    live = {o.component_id for o in mechanics.owned}
    for edge in moved:
        assert edge.source in live, f"{kind}.source '{edge.source}' is dead"
        assert edge.target in live, f"{kind}.target '{edge.target}' is dead"


def test_no_edge_anywhere_names_a_component_the_fold_deleted():
    """The general form, over a campaign with all four kinds and a merge
    chain. Stated as an invariant rather than a case list so a fifth link
    kind is covered on the day it is added."""
    mechanics = M.derive_mechanics([
        _interp(0, [_resource("res_a"), _resource("res_b"),
                    _resource("res_c"), _beam()]),
        _interp(1, [_trait(), _link("powers", "res_a", "act_beam"),
                    _link("fills", "act_beam", "res_b"),
                    _link("scales", "res_c", "trait_speed")]),
        _interp(2, [_merge("res_a", "res_b")]),
        _interp(3, [_merge("res_b", "res_c")]),
    ])
    live = {o.component_id for o in mechanics.owned}
    dangling = [(l.link, l.source, l.target) for l in mechanics.links
                if l.source not in live or l.target not in live]
    assert dangling == []


def test_the_survivor_absorbs_a_duplicate_edge_rather_than_carrying_two():
    """Two `fills` edges that become the same edge are one edge. Without
    the collapse the survivor is refilled twice per use."""
    mechanics = M.derive_mechanics([
        _interp(0, [_resource("res_a"), _resource("res_b"), _beam()]),
        _interp(1, [_link("powers", "res_b", "act_beam"),
                    _link("fills", "act_beam", "res_a", 3.0),
                    _link("fills", "act_beam", "res_b", 3.0)]),
        _interp(2, [_merge("res_a", "res_b")]),
    ])
    fills = _edges(mechanics, "fills")
    assert len(fills) == 1 and fills[0].target == "res_b"


def test_edges_that_disagree_on_strength_are_not_silently_collapsed():
    """Only an EXACT duplicate is one edge asserted twice. Two `fills` of
    different sizes are two different promises, and picking one would be
    the same silent discard this file exists to prevent."""
    mechanics = M.derive_mechanics([
        _interp(0, [_resource("res_a"), _resource("res_b"), _beam()]),
        _interp(1, [_link("powers", "res_b", "act_beam"),
                    _link("fills", "act_beam", "res_a", 3.0),
                    _link("fills", "act_beam", "res_b", 7.0)]),
        _interp(2, [_merge("res_a", "res_b")]),
    ])
    assert sorted(l.strength for l in _edges(mechanics, "fills")) == [3.0, 7.0]


# --- the kinds the client reads as singular ------------------------------

def test_two_powers_links_on_one_action_are_refused():
    """`_powers_link` returns the first match and never looks again, so a
    second edge is not a second cost — it is an edge that does nothing,
    chosen by fold order."""
    with pytest.raises(M.FoldError, match="two 'powers' links"):
        M.derive_mechanics([
            _interp(0, [_resource("res_a"), _resource("res_b"), _beam()]),
            _interp(1, [_link("powers", "res_a", "act_beam"),
                        _link("powers", "res_b", "act_beam")]),
        ])


def test_two_scales_links_on_one_trait_are_refused():
    """`stat_stack.evaluate` keys `scales_by_target` by target, so the
    second write wins and the first link vanishes."""
    with pytest.raises(M.FoldError, match="two 'scales' links"):
        M.derive_mechanics([
            _interp(0, [_resource("res_a"), _resource("res_b"), _trait()]),
            _interp(1, [_link("scales", "res_a", "trait_speed"),
                        _link("scales", "res_b", "trait_speed")]),
        ])


def test_a_merge_that_would_collapse_two_singular_edges_is_refused():
    """Both edges were legal when written — they targeted the same action
    from two different bars, which is the shape above, so this reaches the
    fold by a merge rather than by a link. It has to be caught in both
    places, and this is the one that arrives later."""
    with pytest.raises(M.FoldError, match="two 'scales' links"):
        M.derive_mechanics([
            _interp(0, [_resource("res_a"), _resource("res_b"),
                        _trait("trait_x"), _trait("trait_y", "jump_height")]),
            _interp(1, [_link("scales", "res_a", "trait_x"),
                        _link("scales", "res_b", "trait_y")]),
            # Now tr_y is scaled by res_b and tr_x by res_b as well —
            # except they are different traits, so this is fine.
            _interp(2, [_merge("res_a", "res_b")]),
            _interp(3, [_link("scales", "res_b", "trait_x")]),
        ])


def test_fills_and_gates_stay_many_per_target():
    """The other two kinds are iterated by both clients, and the graph in
    ECHOES §4 is meant to express several actions feeding one bar."""
    mechanics = M.derive_mechanics([
        _interp(0, [_resource("res_a"), _beam(), _action("act_gun")]),
        _interp(1, [_link("powers", "res_a", "act_beam"),
                    _link("fills", "act_beam", "res_a"),
                    _link("fills", "act_gun", "res_a")]),
        _interp(2, [_link("gates", "res_a", "act_beam", 0.2),
                    _link("gates", "res_a", "act_gun", 0.4)]),
    ])
    assert len(_edges(mechanics, "fills")) == 2
    assert len(_edges(mechanics, "gates")) == 2
