"""D-8 -- the cross-room relationship, exercised rather than described.

**What this file is built on, and why it matters.** The 0.4 scope
clarification says the acceptance case must use *"distinct room IDs and
the actual Zone composition/build/state path"* and not *"one large
standalone scenario divided into labelled areas"*, because *"a reference
fixture is an intermediate test, not the final composition claim"*.

So every case below starts from `playtest.played_zone()` -- the Zone the
campaign engine really composes, 23 rooms and 30 edges, the same one the
baseline playtest walks -- and adds the declaration by **re-validating
it through the real schema**, not by `model_copy`, which would skip
every validator that is the point of the exercise.

**What that does and does not prove.** It proves these rules hold on a
really composed Zone with real, distinct room ids, through the real
validators and the real `reachability`. It does **not** prove the
composer emits a cross-room relationship: nothing does yet, exactly as
nothing composes a `featured_acquisition` yet. The engine half, the
player-performed interaction and the physical consequence in the other
room are Prod's, per `docs/D8_CROSS_ROOM_PROD.md` §5.
"""
import pytest
from pydantic import ValidationError

from archipepsi_bridge.schemas.protocol import ZoneProgress
from archipepsi_bridge.schemas.zone import Zone, ZoneStateVariable
from archipepsi_bridge.topology import reachability

_CACHE: list = []


def composed() -> Zone:
    """The really-composed Zone, built once -- it runs a campaign engine."""
    if not _CACHE:
        from archipepsi_bridge.playtest import played_zone
        zone = played_zone()
        assert zone is not None, "the composition path produced no Zone"
        _CACHE.append(zone)
    return _CACHE[0]


def declaring(zone: Zone, variables, gates=()) -> Zone:
    """Re-validate a composed Zone carrying a declaration.

    `Zone.model_validate` rather than `model_copy`: a copy skips every
    validator, and a test that skipped the validators would be testing
    that a dictionary can hold a key.
    """
    raw = zone.model_dump()
    raw["zone_state"] = list(variables)
    for edge_id, conditions in gates:
        hit = [e for e in raw["edges"] if e["edge_id"] == edge_id]
        assert hit, f"{edge_id} is not an edge of the composed Zone"
        hit[0]["requires_state"] = list(conditions)
    return Zone.model_validate(raw)


def variable(setter_room: str, reader_room: str, **over) -> dict:
    """The Blindside shape: a control in one room, a mechanism in another."""
    base = {
        "variable_id": "gantry",
        "states": ["stowed", "lowered"],
        "initial": "stowed",
        "lifetime": "reversible",
        "setter": {"room_id": setter_room, "selects": ["stowed", "lowered"]},
        "readers": [{"room_id": reader_room, "mechanism": "span_bolt",
                     "when": ["lowered"]}],
    }
    base.update(over)
    return base


# --------------------------------------------------------------------------
# The composition path itself -- the claim this file rests on
# --------------------------------------------------------------------------

def test_the_case_is_built_on_a_really_composed_zone():
    """If this Zone were hand-written, nothing below would mean anything."""
    zone = composed()
    assert len(zone.chambers) == 23
    assert len(zone.edges) == 30
    assert zone.zone_state == (), (
        "the composer does not emit cross-room relationships yet, and a "
        "test that found one here would be reading its own fixture back")


def test_a_composed_zone_survives_the_round_trip_unchanged():
    """`declaring(zone, [])` must be the identity, or every case below is
    measuring the round trip instead of the rule."""
    zone = composed()
    assert declaring(zone, []).model_dump() == zone.model_dump()


# --------------------------------------------------------------------------
# Requirement 1 -- a source interaction, and a consequence somewhere else
# --------------------------------------------------------------------------

def test_the_setter_and_the_consumer_are_distinct_real_rooms():
    zone = declaring(composed(), [variable("c002", "c010")])
    v = zone.zone_state[0]
    rooms = {c.id for c in zone.chambers}
    assert v.setter.room_id == "c002" and v.readers[0].room_id == "c010"
    assert {v.setter.room_id, v.readers[0].room_id} <= rooms
    assert v.setter.room_id != v.readers[0].room_id


def test_a_relationship_with_both_ends_in_one_room_is_refused():
    """The control that stops 'cross-room' from being a label.

    A setter and its reader in one room is a room-local mechanism with
    Zone-scope machinery around it, and an acceptance case built on one
    would prove nothing about crossing a boundary.
    """
    with pytest.raises(ValidationError, match="not a cross-room relationship"):
        declaring(composed(), [variable("c002", "c002")])


def test_the_consequence_is_real_a_gated_route_needs_the_state():
    """The remote consequence, as the bridge can measure it: an edge the
    player cannot cross until they have gone and operated the control.

    Both halves are asserted. A gate the search ignored would pass the
    first and fail the second; a gate nothing could open would pass the
    second and fail the first.
    """
    zone = declaring(composed(), [variable("c002", "c010")],
                     gates=[("e:c002:c003",
                             [{"variable_id": "gantry", "state": "lowered"}])])
    assert reachability(zone).ok, (
        "the player can reach c002, operate the control and cross")

    # The same Zone with the control moved BEYOND its own gate.
    stuck = declaring(composed(), [variable("c010", "c012")],
                      gates=[("e:c002:c003",
                              [{"variable_id": "gantry",
                                "state": "lowered"}])])
    assert not reachability(stuck).ok, (
        "c010 is past e:c002:c003, so the only control that opens the gate "
        "is behind the gate")


def test_an_edge_may_not_require_state_the_zone_does_not_declare():
    with pytest.raises(ValidationError, match="does not declare"):
        declaring(composed(), [],
                  gates=[("e:c002:c003",
                          [{"variable_id": "ghost", "state": "on"}])])


def test_an_edge_may_not_require_a_state_the_variable_does_not_have():
    with pytest.raises(ValidationError, match="does not have"):
        declaring(composed(), [variable("c002", "c010")],
                  gates=[("e:c002:c003",
                          [{"variable_id": "gantry", "state": "melted"}])])


# --------------------------------------------------------------------------
# Requirement 2 -- safe return, and no self-locking configuration
# --------------------------------------------------------------------------

def test_a_permanent_change_that_strands_the_player_is_refused():
    """SAFE RETURN, and it is `R subset E` doing the work.

    A one-way variable that shuts the spine behind the player is a
    reachable state the exit cannot be reached from. That shape has been
    refused since `R subset E` was written -- it simply had no macro
    component to see it in until now.
    """
    trap = variable("c002", "c010", variable_id="collapse",
                    states=["open", "sealed"], initial="open",
                    lifetime="permanent",
                    setter={"room_id": "c002", "selects": ["sealed"]},
                    readers=[{"room_id": "c010", "mechanism": "bulkhead",
                              "when": ["sealed"]}])
    zone = declaring(composed(), [trap],
                     gates=[("e:c002:c003",
                             [{"variable_id": "collapse", "state": "open"}])])
    bad = reachability(zone)
    assert not bad.ok
    assert any("R is not a subset of E" in e for e in bad.errors), bad.errors


def test_the_refusal_says_which_zone_state_stranded_the_player():
    """A refusal naming only the room sends whoever reads it back to
    work out which configuration it meant."""
    trap = variable("c002", "c010", variable_id="collapse",
                    states=["open", "sealed"], initial="open",
                    lifetime="permanent",
                    setter={"room_id": "c002", "selects": ["sealed"]},
                    readers=[{"room_id": "c010", "mechanism": "bulkhead",
                              "when": ["sealed"]}])
    zone = declaring(composed(), [trap],
                     gates=[("e:c002:c003",
                             [{"variable_id": "collapse", "state": "open"}])])
    joined = " ".join(reachability(zone).errors)
    assert "collapse=sealed" in joined, joined


def test_the_same_shape_made_reversible_is_accepted():
    """THE CONTROL THAT KEEPS THE RULE FROM REFUSING EVERYTHING.

    Identical geometry, identical gate -- the only change is that the
    player can put it back. If this failed too, the rule above would be
    refusing cross-room relationships rather than self-locking ones.
    """
    ok = variable("c002", "c010", variable_id="collapse",
                  states=["open", "sealed"], initial="open",
                  lifetime="reversible",
                  setter={"room_id": "c002", "selects": ["open", "sealed"]},
                  readers=[{"room_id": "c010", "mechanism": "bulkhead",
                            "when": ["sealed"]}])
    zone = declaring(composed(), [ok],
                     gates=[("e:c002:c003",
                             [{"variable_id": "collapse", "state": "open"}])])
    assert reachability(zone).ok


# --------------------------------------------------------------------------
# The owner's named rule -- no silent latch
# --------------------------------------------------------------------------

def test_a_permanent_variable_wearing_a_reversible_label_is_refused():
    """*"Do not silently replace a live requirement with a permanent
    latch."* The silent version is a setter that cannot return the
    variable to where it started, under a declaration that says it can.

    D-8 §4.0 makes the two differ in a field a validator reads instead
    of in an intention a reviewer has to notice.
    """
    with pytest.raises(ValidationError, match="silent latch"):
        declaring(composed(), [variable(
            "c002", "c010",
            setter={"room_id": "c002", "selects": ["lowered"]})])


def test_a_permanent_variable_must_actually_be_monotone():
    with pytest.raises(ValidationError, match="monotone"):
        declaring(composed(), [variable(
            "c002", "c010", lifetime="permanent",
            setter={"room_id": "c002", "selects": ["stowed", "lowered"]})])


# --------------------------------------------------------------------------
# Requirements 3, 4, 5 -- the save, and what a reload restores
# --------------------------------------------------------------------------

def _reload(progress: ZoneProgress) -> ZoneProgress:
    """Through JSON, because that is what a save actually is."""
    return ZoneProgress.model_validate_json(progress.model_dump_json())


def test_partial_progress_survives_a_reload():
    """One half of a two-variable relationship set, the other not."""
    mid = ZoneProgress().with_macro("gantry", "lowered")
    back = _reload(mid)
    assert back.macro("gantry") == "lowered"
    assert back.macro("collapse") is None, (
        "the unfinished half must come back unfinished")


def test_completed_progress_survives_a_reload_with_both_kinds_intact():
    done = (ZoneProgress()
            .with_macro("gantry", "lowered")
            .with_macro("collapse", "sealed")
            .with_latch("yard/span_one"))
    back = _reload(done)
    assert back.macro("gantry") == "lowered"
    assert back.macro("collapse") == "sealed"
    assert back.latched == ("yard/span_one",)


def test_a_reversible_variable_is_not_stored_as_a_latch():
    """Prod's §3 question 5, as a control rather than a promise.

    `latched` is monotone and its whole resume-safety argument depends
    on that. A reversible variable put back would either make the set
    non-monotone or silently stay set -- so it lives in its own field.
    """
    p = (ZoneProgress().with_latch("yard/span_one")
         .with_macro("gantry", "lowered")
         .with_macro("gantry", "stowed"))
    assert p.macro("gantry") == "stowed", "a reversible variable goes back"
    assert p.latched == ("yard/span_one",), "and the latch does not"
    assert not any("gantry" in ref for ref in p.latched)


def test_a_local_reset_loses_nothing_unrelated():
    """Requirement 5, in the form the bridge can actually settle.

    Nothing in `ZoneProgress` is keyed by a room or a node, so rebuilding
    a room cannot reach any of it. The case asserts the shape that makes
    that true rather than simulating a rebuild the bridge does not do:
    putting one variable back leaves every other kind of progress
    exactly where it was.
    """
    full = (ZoneProgress()
            .with_key("k_yard")
            .with_lock("c004", "door_n")
            .with_station("st_c002")
            .with_latch("yard/span_one")
            .with_macro("gantry", "lowered")
            .with_macro("collapse", "sealed"))
    after = full.with_macro("gantry", "stowed")
    assert after.macro("gantry") == "stowed"
    for kept in ("collected_keys", "opened_locks", "reached_stations",
                 "latched", "resume_anchor"):
        assert getattr(after, kept) == getattr(full, kept), kept
    assert after.macro("collapse") == "sealed", (
        "one variable going back must not disturb another")


# --------------------------------------------------------------------------
# The stale reference the clarification named
# --------------------------------------------------------------------------

def test_a_route_condition_cannot_name_a_source_node_at_all():
    """*"A rebuilt destination must not depend on a stale reference to a
    source node."*

    Not defended against -- unwritable. `StateCondition` has two fields
    and neither of them can hold a node: the handle is restored at §5.6
    step 4 and the setter's node is rebuilt at steps 9-10, so a
    condition naming the node would name something that does not exist
    when it is evaluated.
    """
    from archipepsi_bridge.schemas.graph import StateCondition
    assert set(StateCondition.model_fields) == {"variable_id", "state"}
    with pytest.raises(ValidationError):
        StateCondition.model_validate(
            {"variable_id": "gantry", "state": "lowered",
             "source_node": "c002/lever_a"})


def test_a_rebuilt_zone_resolves_the_same_condition():
    """The same claim from the other side: two independently validated
    Zone objects -- different Python objects, nothing shared -- resolve
    the condition identically, because it is resolved by id."""
    gates = [("e:c002:c003",
              [{"variable_id": "gantry", "state": "lowered"}])]
    first = declaring(composed(), [variable("c002", "c010")], gates=gates)
    rebuilt = declaring(composed(), [variable("c002", "c010")], gates=gates)
    assert first is not rebuilt
    a = [e for e in first.edges if e.edge_id == "e:c002:c003"][0]
    b = [e for e in rebuilt.edges if e.edge_id == "e:c002:c003"][0]
    assert a is not b
    assert a.requires_state == b.requires_state
    assert reachability(first).ok and reachability(rebuilt).ok


# --------------------------------------------------------------------------
# Epsilon's choice stays a choice
# --------------------------------------------------------------------------

def test_the_relationship_can_sit_between_different_pairs_of_rooms():
    """*"Do not hardcode one scenario and call cross-room composition
    complete."* The declaration carries the rooms, so the same
    relationship holds between other pairs of real rooms."""
    for setter, reader in (("c002", "c010"), ("c005", "c018"),
                           ("c012", "c003")):
        zone = declaring(composed(), [variable(setter, reader)])
        v = zone.zone_state[0]
        assert (v.setter.room_id, v.readers[0].room_id) == (setter, reader)
        assert reachability(zone).ok


def test_a_setter_or_reader_in_a_room_that_does_not_exist_is_refused():
    with pytest.raises(ValidationError, match="which this Zone does not have"):
        declaring(composed(), [variable("c999", "c010")])
    with pytest.raises(ValidationError, match="which this Zone does not have"):
        declaring(composed(), [variable("c002", "c999")])


# --------------------------------------------------------------------------
# Owner corrections, 2026-09-22. Two of these are defects in the rules
# this file shipped, so each one gets the case that would have caught it.
# --------------------------------------------------------------------------

def _gantry(**over) -> dict:
    """Blindside's overhead gantry: a control you cannot reach on foot.

    4.6 m up, no mantle, no stairs -- deliberately, because a placeholder
    that lets you skip the loop is not a placeholder for the loop.
    """
    base = variable("c002", "c010")
    base["setter"] = {"room_id": "c002", "selects": ["stowed", "lowered"],
                      "capability": "grapple"}
    base.update(over)
    return base


def test_entering_the_gantrys_room_does_not_operate_the_gantry():
    """OWNER CORRECTION 2, and it was a real defect in the search.

    The first cut let the player set any variable whose setter's room
    they could stand in. Blindside's gantry then became operable the
    moment they walked in underneath it, grapple or no grapple -- the
    search granting itself a capability, which is the direction nothing
    ever fails in.
    """
    zone = declaring(composed(), [_gantry()],
                     gates=[("e:c002:c003",
                             [{"variable_id": "gantry", "state": "lowered"}])])
    # c002 is reachable on foot; the control in it is not operable.
    assert not reachability(zone).ok, (
        "walking into the room under the gantry is not reaching the gantry")


def test_the_same_gantry_is_operable_once_the_capability_is_declared():
    """The control that keeps the rule from refusing every gated setter."""
    zone = declaring(composed(), [_gantry()],
                     gates=[("e:c002:c003",
                             [{"variable_id": "gantry", "state": "lowered"}])])
    assert reachability(zone, declared_capabilities=["grapple"]).ok


def test_a_setter_capability_is_counted_as_a_gate_the_logic_must_declare():
    """No undeclared mandatory gate -- including this new kind of gate.

    A control you cannot operate without the grapple gates everything
    downstream of the state it sets. Collecting only edge capabilities
    would have left a hole in that protection in the same change that
    added a new way to make one.
    """
    zone = declaring(composed(), [_gantry()],
                     gates=[("e:c002:c003",
                             [{"variable_id": "gantry", "state": "lowered"}])])
    joined = " ".join(reachability(zone).errors)
    assert "grapple" in joined, (
        f"the refusal must name the undeclared gate; got: {joined}")


def test_selects_proves_an_operation_exists_not_a_reversal_you_can_reach():
    """OWNER CORRECTION 2's other half, and the claim I had to withdraw.

    `selects` containing the initial state says the control CAN put it
    back. It says nothing about whether the player can get back to the
    control and operate it. Here the reversal is declared and the
    capability to operate it is not held, so the operation exists and
    the reversal does not -- and only a search can tell them apart.
    """
    v = _gantry()
    assert "stowed" in v["setter"]["selects"], "the reversal is declared"
    zone = declaring(composed(), [v],
                     gates=[("e:c002:c003",
                             [{"variable_id": "gantry", "state": "lowered"}])])
    assert not reachability(zone).ok
    assert reachability(zone, declared_capabilities=["grapple"]).ok


def test_a_reader_may_also_sit_in_the_setters_room():
    """OWNER CORRECTION 4. A lever that visibly moves something beside
    it AND opens a way somewhere else is ordinary good design, and the
    first cut of the cross-room rule forbade it."""
    both = variable("c002", "c010")
    both["readers"] = [
        {"room_id": "c010", "mechanism": "span_bolt", "when": ["lowered"]},
        {"room_id": "c002", "mechanism": "ring_light", "when": ["lowered"]},
    ]
    zone = declaring(composed(), [both])
    assert {r.room_id for r in zone.zone_state[0].readers} == {"c002", "c010"}
    assert reachability(zone).ok


def test_every_reader_in_the_setters_room_is_still_refused():
    """What correction 4 did NOT relax: the relationship still has to
    have a consequence somewhere else, or it is room-local."""
    with pytest.raises(ValidationError, match="somewhere else"):
        local = variable("c002", "c010")
        local["readers"] = [
            {"room_id": "c002", "mechanism": "a", "when": ["lowered"]},
            {"room_id": "c002", "mechanism": "b", "when": ["lowered"]},
        ]
        declaring(composed(), [local])
