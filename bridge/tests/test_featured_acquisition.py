"""D-1 / D-2 — the acquisition binding, exercised.

`capability_guarantee` has had four cases since it was written, and case
C — `established_in_zone`, "you will be able to do this because you
acquire it HERE" — took a parameter nothing produced. The Zone could not
say which capability it was built to hand over, so the case could never
fire and the railway's featured Echo had to come from a pedestal.

`Zone.featured_acquisition` says it and `established_in_zone` produces
the set. Everything else in the chain already existed; what follows
exercises the join rather than the parts.

The five approved requirements, one section each. Nothing here is proved
by pointing at a sequence field: `next_interpretation_seq` and friends
are infrastructure this binding rides on, not evidence that the binding
is right.
"""

from __future__ import annotations

import pytest
from pydantic import TypeAdapter, ValidationError

from archipepsi_bridge import topology
from archipepsi_bridge.schemas import echo as E
from archipepsi_bridge.schemas import mechanics as M
from archipepsi_bridge.schemas import protocol as P
from archipepsi_bridge.schemas import transitions as T
from archipepsi_bridge.schemas import zone as Z

FEATURED_LOCATION = 89100005
CAPABILITY = "grapple"


def _arena(rid: str, reward: int | None = None) -> dict:
    return {"id": rid, "type": "arena", "width": 16.0, "depth": 15.0,
            "wall_height": 5.0, "objective": "kill_all",
            "reward_location_id": reward,
            "enemies": [{"archetype": "melee", "count": 1}]}


def _zone(featured: dict | None = None, **over) -> Z.Zone:
    body = {
        "schema_version": 7, "zone_id": "zone_001", "display_name": "Relay",
        "target_game": "Game", "theme": "void_glitch",
        "chambers": [_arena("c001", 89100001), _arena("c002"),
                     _arena("c005", FEATURED_LOCATION)],
    }
    if featured is not None:
        body["featured_acquisition"] = featured
    body.update(over)
    return TypeAdapter(Z.Zone).validate_python(body)


def _featured(**over) -> dict:
    base = {"capability": CAPABILITY, "location_id": FEATURED_LOCATION,
            "room_id": "c005"}
    base.update(over)
    return base


def _grapple_echo(seq: int = 0) -> E.EchoInterpretation:
    """A REAL qualifying Echo: an Action whose primitive satisfies
    `grapple` through `ACTIVITY_CAPABILITIES`, not a component named
    after the capability."""
    return E.EchoInterpretation.model_validate({
        "schema_version": 8, "echo_id": f"echo_{FEATURED_LOCATION}",
        "interpretation_seq": seq, "source_location_id": FEATURED_LOCATION,
        "source_item_name": "Hookshot", "source_game": "Ocarina of Time",
        "source_recipient_name": "OoTPlayer",
        "display_name": "Hookshot", "description": "It pulls.",
        "operations": [{"op": "create", "component": {
            "kind": "action", "component_id": "act_hook",
            "display_name": "Hookshot", "description": "It pulls.",
            "slot": "mobility", "cooldown": 3.0,
            "primitive": {"type": "grapple_to_surface",
                          "range": 20.0, "pull_force": 18.0},
            "modifiers": []}}]})


def _save(*interps) -> P.CampaignSave:
    save = P.CampaignSave(seed_name="Seed", team=0, slot_id=1,
                          slot_name="Skyiah")
    for interp in interps:
        save = T.append_interpretation(save, interp)
    return save


# --- 1. REACHABLE FEATURED ACQUISITION ------------------------------------

def test_the_featured_room_must_be_reachable_without_what_it_hands_over():
    """The circular proof, refused.

    Case C would otherwise hold for a room the player cannot enter
    without the very capability that room grants: the guarantee passes,
    the generator places content behind it, and the player is stopped at
    the door by the lack of what is on the far side of it.
    """
    zone = topology.apply(_zone(_featured()),
                          topology.compose_chain(list(_zone().chambers)))
    ok = topology.reachability(zone)
    assert ok.ok, ok.errors

    # Now hand the explorer the capability as if case C had been wired
    # into the declared set — the specific mistake the guard exists for.
    gated = topology.reachability(zone, declared_capabilities=(CAPABILITY,))
    assert gated.ok, "this control needs the ungated Zone to pass first"


def test_a_featured_room_behind_its_own_capability_is_refused():
    zone = topology.apply(_zone(_featured()),
                          topology.compose_chain(list(_zone().chambers)))
    # Put the featured capability on the edge into its own room.
    gated_edges = tuple(
        e.model_copy(update={"capability": CAPABILITY})
        if e.room_b == "c005" or e.room_a == "c005" else e
        for e in zone.edges)
    circular = zone.model_copy(update={"edges": gated_edges})
    reach = topology.reachability(
        circular, declared_capabilities=(CAPABILITY,))
    assert not reach.ok
    assert any("circular" in e for e in reach.errors), reach.errors


def test_a_featured_acquisition_must_name_a_room_that_carries_the_check():
    with pytest.raises(ValidationError, match="which this Zone does not have"):
        _zone(_featured(room_id="c404"))
    with pytest.raises(ValidationError, match="which carries"):
        _zone(_featured(room_id="c002"))     # c002 holds no Check at all


# --- 2. A QUALIFYING LOCAL ECHO -------------------------------------------

def test_the_confirmed_check_yields_a_capability_the_player_really_has():
    """Not "a component arrived" — the capability the Zone featured is
    the one `owned_capabilities` reports afterwards."""
    before = M.derive_mechanics(_save().interpretations)
    assert CAPABILITY not in M.owned_capabilities(before)

    after = M.derive_mechanics(_save(_grapple_echo()).interpretations)
    assert CAPABILITY in M.owned_capabilities(after)


def test_an_echo_that_does_not_qualify_does_not_grant_the_capability():
    """The negative half, or the test above proves only that SOMETHING
    was folded."""
    dud = E.EchoInterpretation.model_validate({
        **_grapple_echo().model_dump(),
        "operations": [{"op": "create", "component": {
            "kind": "info", "component_id": "info_radar",
            "display_name": "Radar", "description": "It pings.",
            "readout": "enemy_radar"}}]})
    folded = M.derive_mechanics(_save(dud).interpretations)
    assert CAPABILITY not in M.owned_capabilities(folded)


# --- 3. THE FOREIGN ITEM IS DELIVERED UNCHANGED ---------------------------

def test_the_local_grant_does_not_touch_the_foreign_item():
    """The local Echo is made FROM the foreign item's reading; it does
    not consume, rename or stand in for the item itself."""
    save = _save(_grapple_echo())
    stored = save.interpretation_by_id(f"echo_{FEATURED_LOCATION}")
    assert stored.source_item_name == "Hookshot"
    assert stored.source_game == "Ocarina of Time"
    assert stored.source_recipient_name == "OoTPlayer"
    assert stored.source_location_id == FEATURED_LOCATION
    # and the capability the Zone features came from it all the same
    assert CAPABILITY in M.owned_capabilities(
        M.derive_mechanics(save.interpretations))


# --- 4. THE GUARANTEE MATCHES WHAT AP PROVED BEFORE THE SEED --------------

def test_case_c_fires_only_for_what_the_zone_features():
    """D-2. The producer case C never had."""
    zone = _zone(_featured())
    assert Z.established_in_zone(zone) == (CAPABILITY,)
    assert Z.established_in_zone(_zone()) == ()

    empty = M.derive_mechanics(_save().interpretations)
    before = M.capability_guarantee(
        CAPABILITY, empty, Z.established_in_zone(zone))
    assert before.guaranteed and before.reason == "established_in_zone"

    # A capability the Zone does NOT feature gets no free pass.
    other = M.capability_guarantee(
        "blink", empty, Z.established_in_zone(zone))
    assert not other.guaranteed and other.reason == "not_guaranteed"


def test_once_it_is_owned_the_cheaper_proof_is_reported():
    """Case B outranks case C: after the Check confirms the player HAS
    it, and the Zone no longer has to promise it."""
    owned = M.derive_mechanics(_save(_grapple_echo()).interpretations)
    got = M.capability_guarantee(
        CAPABILITY, owned, Z.established_in_zone(_zone(_featured())))
    assert got.guaranteed and got.reason == "already_possessed"


# --- 5. DUPLICATE, DELAYED, RELOAD ----------------------------------------

def test_the_same_check_confirmed_twice_mints_one_echo():
    once = _save(_grapple_echo())
    twice = T.append_interpretation(once, _grapple_echo(seq=99))
    assert len(twice.interpretations) == 1, "a second Echo was minted"
    assert twice.next_interpretation_seq == once.next_interpretation_seq
    assert twice.interpretations[0].interpretation_seq == 0, (
        "the duplicate renumbered the original")


def test_a_delayed_interpretation_grants_nothing_until_it_lands():
    """A fold that lags is the ordinary case, not an error — and until
    it lands the capability is NOT owned, so case C is still what
    carries the Zone."""
    pending = _save()
    assert CAPABILITY not in M.owned_capabilities(
        M.derive_mechanics(pending.interpretations))
    guarantee = M.capability_guarantee(
        CAPABILITY, M.derive_mechanics(pending.interpretations),
        Z.established_in_zone(_zone(_featured())))
    assert guarantee.reason == "established_in_zone", (
        "a Zone whose featured Echo has not folded yet lost its proof")


def test_the_binding_survives_a_reload():
    """Round-tripped through the save's own serialisation, because the
    fold is recomputed on load and a capability that only exists in
    memory is not acquired."""
    save = _save(_grapple_echo())
    reloaded = P.CampaignSave.model_validate_json(save.model_dump_json())
    assert CAPABILITY in M.owned_capabilities(
        M.derive_mechanics(reloaded.interpretations))
    stored = reloaded.interpretation_by_id(f"echo_{FEATURED_LOCATION}")
    assert stored.source_item_name == "Hookshot"
    assert stored.interpretation_seq == 0


# --------------------------------------------------------------------------
# P02.1 / P02.4 — the acquisition model, CONNECTED.
#
# `established_in_zone` produced case C's set and nothing consumed it;
# `capability_guarantee` had no production caller at all. Two halves of a
# guarantee nobody was making. `topology._explore_acquiring` joins them,
# and the ordering is the whole point: not at the door, not on arrival,
# but after the claim.
# --------------------------------------------------------------------------

def _gated(order, gate_after: int, featured_room: str):
    """A chain Zone whose edge after `gate_after` needs the capability."""
    chambers = [_arena(rid, FEATURED_LOCATION if rid == featured_room
                       else (89100001 if i == 0 else None))
                for i, rid in enumerate(order)]
    zone = TypeAdapter(Z.Zone).validate_python({
        "schema_version": 7, "zone_id": "zone_001", "display_name": "Relay",
        "target_game": "Game", "theme": "void_glitch",
        "chambers": chambers,
        "featured_acquisition": {"capability": CAPABILITY,
                                 "location_id": FEATURED_LOCATION,
                                 "room_id": featured_room},
    })
    built = topology.apply(zone, topology.compose_chain(list(zone.chambers)))
    raw = built.model_dump()
    target = f"e:{order[gate_after]}:{order[gate_after + 1]}"
    hit = [e for e in raw["edges"] if e["edge_id"] == target]
    assert hit, f"{target} is not an edge of this chain"
    hit[0]["capability"] = CAPABILITY
    return TypeAdapter(Z.Zone).validate_python(raw)


def test_the_zone_grants_the_capability_and_the_route_past_it_opens():
    """Case C, actually firing. The gate sits AFTER the featured room, so
    the player claims the Echo and walks on."""
    order = ["c001", "c002", "c005", "c006"]
    zone = _gated(order, gate_after=2, featured_room="c005")
    assert topology.reachability(zone).ok


def test_the_capability_is_not_in_hand_at_the_zone_door():
    """*"Do not supply a promised tool at Zone entry."*

    Same Zone, gate moved to the FIRST edge -- before the featured room.
    If the acquisition were granted at entry this would pass, and the
    midpoint sequence would prove nothing.
    """
    order = ["c001", "c002", "c005", "c006"]
    zone = _gated(order, gate_after=0, featured_room="c005")
    bad = topology.reachability(zone)
    assert not bad.ok, (
        "the featured capability must not open a gate standing between "
        "the entrance and the room that hands it over")


def test_reaching_the_room_is_not_the_same_as_having_claimed_it():
    """*"Reaching the Check's room must not automatically grant its
    capability."*

    The gate is the edge the player arrives at the featured room
    THROUGH. Granting on arrival would open it from the wrong side;
    granting on the claim does not, because the claim happens in the
    room and the gate is behind them by then -- so this Zone is refused
    for the same reason the door case is.
    """
    order = ["c001", "c002", "c005", "c006"]
    zone = _gated(order, gate_after=1, featured_room="c005")
    assert not topology.reachability(zone).ok


def test_the_three_cases_differ_only_in_where_the_gate_stands():
    """Side by side, so none of them can pass for a reason that has
    nothing to do with the ordering."""
    order = ["c001", "c002", "c005", "c006"]
    verdicts = [topology.reachability(_gated(order, g, "c005")).ok
                for g in (0, 1, 2)]
    assert verdicts == [False, False, True], verdicts


def test_a_zone_that_features_nothing_is_unchanged():
    """Every Zone composed before this establishes nothing, and the
    ordered search must not invent a capability for it."""
    order = ["c001", "c002", "c005", "c006"]
    zone = _gated(order, gate_after=2, featured_room="c005")
    without = TypeAdapter(Z.Zone).validate_python(
        {**zone.model_dump(), "featured_acquisition": None})
    assert not topology.reachability(without).ok, (
        "with nothing granting the capability the gate is undeclared")
