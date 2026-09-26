"""NO REQUIREMENT BEFORE GUARANTEE (owner ruling, 2026-08-30).

Content may require a capability. It may not require one the generator
cannot PROVE the player will be able to use. These tests are about the
proof, not about the activity: the runtime half lives in
`godot/tests/test_activities.gd`.

The distinction the owner drew, and the reason this file exists:

    Room 1: kill six enemies -> an ordinary shuffled Check -> assume it
    gives Grapple -> a mandatory grapple route.

Archipelago decides what is in that Check. Assuming is not proving, and
a validator that reasons from what would be convenient is a validator
that strands people.
"""
from __future__ import annotations

import typing
from pathlib import Path

import pytest
from pydantic import ValidationError

from archipepsi_bridge.schemas import constants as C
from archipepsi_bridge.schemas import echo as E
from archipepsi_bridge.schemas import mechanics as M
from archipepsi_bridge.schemas import zone as Z


def _primitive_payload(primitive: str) -> dict:
    """A minimal legal payload for any primitive, from its own model.

    Introspected rather than tabulated: a hand-written table of every
    primitive's fields is a second copy of the schema that goes stale
    silently, and this file only cares WHICH primitive it owns.
    """
    for candidate in typing.get_args(
            E.ActionComponent.model_fields["primitive"].annotation):
        fields = candidate.model_fields
        literal = typing.get_args(fields["type"].annotation)
        if not literal or literal[0] != primitive:
            continue
        payload: dict = {"type": primitive}
        for name, field in fields.items():
            if name == "type" or not field.is_required():
                continue
            low = next((m.ge for m in field.metadata
                        if getattr(m, "ge", None) is not None), None)
            high = next((m.le for m in field.metadata
                         if getattr(m, "le", None) is not None), None)
            if low is not None and high is not None:
                payload[name] = type(low)((low + high) / 2)
            else:
                payload[name] = low if low is not None else 1.0
        return payload
    raise AssertionError(f"no model for primitive '{primitive}'")


def _owning(primitive: str) -> M.Mechanics:
    """A campaign that owns exactly one Action, with this primitive.

    Built through the FOLD rather than by constructing `Mechanics`
    directly: a capability read off a hand-built object would prove the
    reader works and nothing about whether a campaign could ever contain
    one.
    """
    return M.derive_mechanics([E.EchoInterpretation.model_validate({
        "schema_version": 8, "echo_id": "echo_89100001",
        "interpretation_seq": 0, "source_location_id": 89100001,
        "source_item_name": "Conference Call", "source_game": "Borderlands 2",
        "source_recipient_name": "Player", "display_name": "Thing",
        "description": "A thing.",
        "operations": [{"op": "create", "component": {
            "kind": "action", "component_id": "act_1",
            "display_name": "Thing", "description": "A thing.",
            "slot": "mobility", "cooldown": 2.0,
            "primitive": _primitive_payload(primitive),
            "modifiers": []}}]})])


# --- the vocabulary is semantic, not an item list ------------------------

def test_grapple_is_satisfied_by_every_grapple_that_moves_the_player():
    """The owner's central point: different primitives, one capability,
    and no canonical Echo anywhere in the answer -- among the grapples
    that actually carry the player to an anchor."""
    for primitive in ("grapple_to_surface", "grapple_swing"):
        assert "grapple" in M.owned_capabilities(_owning(primitive)), primitive


def test_pulling_an_enemy_satisfies_no_traversal_requirement():
    """Owner ruling D-02 (DESS-26): "Moving an enemy does not prove that
    the player can perform the crossing." Same family, same name, and
    not the capability -- nor the anchor the capability uses."""
    mechanics = _owning("grapple_pull_target")
    owned = M.owned_capabilities(mechanics)
    for capability in M.TRAVERSAL_CAPABILITIES:
        assert capability not in owned, capability
    assert "grapple_anchor" not in M.owned_affordance_tags(mechanics)


def test_every_traversal_capability_is_answered_by_moving_the_player():
    """The contract names the affordance a gate requires, and every
    primitive counted for a traversal capability moves the player."""
    assert set(M.CAPABILITY_AFFORDANCES) == set(M.ACTIVITY_CAPABILITIES)
    for capability in M.TRAVERSAL_CAPABILITIES:
        counted = set(M.ACTIVITY_CAPABILITIES[capability]["primitives"])
        assert counted <= set(M.PLAYER_TRAVERSAL_PRIMITIVES), capability
    assert "grapple_pull_target" not in M.PLAYER_TRAVERSAL_PRIMITIVES


def test_owning_the_wrong_thing_does_not_satisfy_it():
    assert "grapple" not in M.owned_capabilities(_owning("double_jump"))


# --- the four guarantee cases -------------------------------------------

def test_case_a_the_permanent_baseline_needs_nothing():
    """Static Pulse is the always-available ranged floor, so a campaign
    that owns nothing at all can still be asked to hit something."""
    guarantee = M.capability_guarantee("ranged_hit", M.Mechanics())
    assert guarantee.guaranteed
    assert guarantee.reason == "permanent_baseline"


def test_case_b_is_read_from_the_fold():
    guarantee = M.capability_guarantee("grapple", _owning("grapple_swing"))
    assert guarantee.guaranteed
    assert guarantee.reason == "already_possessed"


def test_case_c_is_a_seam_with_no_producer_yet():
    """Passing the set is how a future establishment point plugs in.
    Every caller passes nothing today, which is the honest answer: the
    Zone establishes nothing."""
    empty = M.Mechanics()
    assert not M.capability_guarantee("blink", empty).guaranteed
    established = M.capability_guarantee("blink", empty, ("blink",))
    assert established.guaranteed
    assert established.reason == "established_in_zone"


def test_case_d_the_forge_is_named_and_unreachable():
    """Deferred deliberately. The reason exists so the answer's SHAPE
    does not have to change the day the Forge lands."""
    assert "forge_constructible" in M.CapabilityGuarantee.model_fields[
        "reason"].annotation.__args__
    reasons = {M.capability_guarantee(c, _owning(p)).reason
               for c, p in (("grapple", "grapple_swing"),
                            ("blink", "blink"),
                            ("cross_long_gap", "dash"),
                            ("ranged_hit", "dash"))}
    assert "forge_constructible" not in reasons


# --- the negative controls ----------------------------------------------

def test_an_unknown_capability_is_refused_not_defaulted():
    """A typo that silently means "no requirement" is the exact failure
    this invariant exists to prevent."""
    guarantee = M.capability_guarantee("teleport", M.Mechanics())
    assert not guarantee.guaranteed
    assert guarantee.reason == "not_guaranteed"


def test_ownership_is_not_the_loadout():
    """You own the grapple whether or not it is slotted, and you can
    always slot it -- so generation asks what you OWN. A Zone whose
    contents depended on the loadout would lie the moment slots changed.
    """
    mechanics = _owning("grapple_swing")
    empty_slots = _Slots()
    assert "grapple" in M.owned_capabilities(mechanics)
    assert "grapple" not in M.available_capabilities(mechanics, empty_slots)


def test_available_is_what_makes_not_yet_a_real_state():
    """The gap between owned and available is not a bug: it is the only
    thing that makes a NOT YET gate reachable rather than dead code."""
    mechanics = _owning("grapple_swing")
    assert "grapple" in M.available_capabilities(mechanics, _Slots(
        mobility="act_1"))


def test_the_baseline_is_available_with_nothing_equipped():
    assert "ranged_hit" in M.available_capabilities(M.Mechanics(), _Slots())


class _Slots:
    """The four-field slot assignment, minimally. `available_capabilities`
    reads field names off the model, so this stands in for the real one
    without importing the protocol into a schema test."""

    model_fields = {"echo_a": None, "echo_b": None,
                    "mobility": None, "utility": None}

    def __init__(self, **over):
        for name in self.model_fields:
            setattr(self, name, over.get(name))


# --- the validator refuses what cannot be proven -------------------------

def _zone_with(activity: dict) -> Z.Zone:
    return Z.Zone.model_validate({
        "schema_version": 7, "zone_id": "zone_001", "display_name": "Relay",
        "target_game": "Game", "theme": "void_glitch",
        "chambers": [{
            "id": "c1", "type": "arena", "width": 20.0, "depth": 18.0,
            "wall_height": 6.0, "objective": "kill_all",
            "reward_location_id": 89100001,
            "enemies": [{"archetype": "melee", "count": 3}],
            "activities": [activity]}]})


def _errors(zone: Z.Zone, guaranteed: tuple[str, ...]) -> list[str]:
    return Z.validate_zone(
        zone, expected_zone_id="zone_001",
        allocated_location_ids=[89100001], owned_echo_ids=[],
        guaranteed_capabilities=guaranteed)


def test_a_requirement_that_is_guaranteed_is_accepted():
    zone = _zone_with({"kind": "target_challenge", "element_count": 3,
                       "requires": ["ranged_hit"]})
    assert not [e for e in _errors(zone, ("ranged_hit",)) if "requiring" in e]


def test_a_requirement_that_is_not_guaranteed_is_refused():
    zone = _zone_with({"kind": "switch_sequence", "element_count": 3,
                       "requires": ["grapple"]})
    refusals = [e for e in _errors(zone, ("ranged_hit",)) if "requiring" in e]
    assert refusals, "an unguaranteed requirement was let through"
    assert "grapple" in refusals[0]


def test_the_default_guarantee_set_refuses_rather_than_permits():
    """A caller that forgets the argument must refuse MORE than it
    should, never less. The default is the permanent baseline."""
    zone = _zone_with({"kind": "switch_sequence", "requires": ["blink"]})
    errors = Z.validate_zone(
        zone, expected_zone_id="zone_001",
        allocated_location_ids=[89100001], owned_echo_ids=[])
    assert [e for e in errors if "requiring" in e]


def test_no_requirement_at_all_is_the_ordinary_case():
    zone = _zone_with({"kind": "pressure_routing", "element_count": 2})
    assert not [e for e in _errors(zone, ()) if "requiring" in e]


@pytest.mark.parametrize("kind", ["switch_sequence", "timed_run",
                                  "target_challenge", "pressure_routing"])
def test_every_kind_can_carry_a_guaranteed_requirement(kind):
    zone = _zone_with({"kind": kind, "element_count": 2,
                       "requires": ["ranged_hit"]})
    assert not [e for e in _errors(zone, ("ranged_hit",)) if "requiring" in e]


# --- an activity can never become Archipelago's business -----------------

def test_an_activity_completion_cannot_reach_ap_truth():
    """The client sends `grant_local_reward` and nothing else.

    Structural, not behavioural: `EarnedLocalReward` has no field that
    could name a location, an item, a Check, a Coin or a Signal Key, so
    the intent an activity sends is INCAPABLE of touching AP truth rather
    than merely careful not to. The Godot half asserts that this is the
    only intent a completion sends.
    """
    from archipepsi_bridge.schemas import protocol as P

    fields = set(P.EarnedLocalReward.model_fields)
    forbidden = {"location_id", "location_ids", "item_name", "check",
                 "coins", "signal_keys", "ap_item", "location"}
    assert not fields & forbidden, sorted(fields & forbidden)


def test_solving_the_same_activity_twice_is_one_reward():
    """An activity is not a farm.

    The bridge half. The client derives `reward_id` from the activity's
    identity; `grant_local_reward` is idempotent by that id, so the
    second solve records nothing new.
    """
    from archipepsi_bridge.schemas import protocol as P
    from archipepsi_bridge.schemas import transitions as T

    save = P.CampaignSave(seed_name="s", slot_id=1, slot_name="P", team=0)
    reward = P.EarnedLocalReward(
        kind="flavor_log", reward_id="activity_c1_0",
        display_name="Switch sequence solved", description="Solved in c1.",
        source_zone_id="zone_001")
    once = T.grant_local_reward(save, reward)
    twice = T.grant_local_reward(once, reward)
    assert len(once.local_rewards) == 1
    assert len(twice.local_rewards) == 1


def test_an_activity_reward_is_not_the_deferred_challenge_marker():
    """`challenge_marker` is the kind an activity completion most
    obviously wants, and it is deliberately without semantics. This
    batch does not resolve that decision as a side effect."""
    driver = (Path(__file__).resolve().parents[2] / "godot" / "scripts"
              / "gameplay" / "activity_runtime.gd").read_text()
    assert '"kind": "flavor_log"' in driver
    assert "challenge_marker" not in driver


def test_the_timing_record_cannot_carry_an_ap_id_through_an_activity():
    """The measurement path is the other way an activity could reach AP
    truth, and it is closed the same way: by having no field for it."""
    from archipepsi_bridge.schemas import protocol as P

    fields = set(P.ActivityOutcome.model_fields)
    assert not fields & {"location_id", "reward_location_id", "check",
                         "item_name", "coins"}, sorted(fields)


# --- identity is not qualification ----------------------------------------
#
# §29.3.1 separated these for `manipulate`: membership answers "is this a
# manipulation Ability", never "can this one move the crate". The same
# split is owed to movement. A weak dash is still a dash, and §0-bis is
# explicit that the movement floor keeps binding — "a declared Grapple
# gate is legal; an undeclared 3-metre jump is still a bug."

def _owning_dash(force: float) -> M.Mechanics:
    return M.derive_mechanics([E.EchoInterpretation.model_validate({
        "schema_version": 8, "echo_id": "echo_89100001",
        "interpretation_seq": 0, "source_location_id": 89100001,
        "source_item_name": "Conference Call", "source_game": "Borderlands 2",
        "source_recipient_name": "Player", "display_name": "Thing",
        "description": "A thing.",
        "operations": [{"op": "create", "component": {
            "kind": "action", "component_id": "act_1",
            "display_name": "Thing", "description": "A thing.",
            "slot": "mobility", "cooldown": 2.0,
            "primitive": {"type": "dash", "force": force}}}],
    })])


def test_the_weakest_and_strongest_dash_have_the_same_identity():
    """Identity is membership. It does not, and must not, know how far
    the thing goes — that is the question qualification asks."""
    weak, strong = _owning_dash(4.0), _owning_dash(20.0)
    assert "cross_long_gap" in M.owned_capabilities(weak)
    assert "cross_long_gap" in M.owned_capabilities(strong)


def test_a_gap_inside_the_base_kit_is_not_a_gate_at_all():
    """`max_safe_gap` is what the starting kit already covers, derived
    from the same constants the engine generates its own copy from. A
    crossing inside it needs no provider and gates nothing."""
    inside = C.max_safe_gap(0.0) - 0.1
    q = _qualify(M.EMPTY_MECHANICS, inside)
    assert q.qualifies and q.reason == "within_base_kit"


def test_owning_a_dash_does_not_certify_a_crossing():
    """**The repair.** Identity said `cross_long_gap`, so a route needing
    six metres was proved by a dash that might carry four. Qualification
    is a separate question and it is refused, with the reason, until a
    measured floor exists."""
    for force in (4.0, 20.0):
        q = M.qualifies_for_gap("cross_long_gap", _owning_dash(force), 6.0)
        assert not q.qualifies
        assert q.reason == "no_envelope_measured", q


def test_owning_nothing_in_the_family_says_so_distinctly():
    """A different fault from "owned but unmeasured", and the two must
    not be reported as one: the first is a Zone asking for a capability
    the campaign lacks, the second is a measurement nobody has taken."""
    q = _qualify(M.EMPTY_MECHANICS, 6.0)
    assert not q.qualifies and q.reason == "no_provider"


ACTIVITY_LONG_GAP = M.ACTIVITY_CAPABILITIES["cross_long_gap"]["primitives"]


def _primitive_model(primitive: str):
    """The model class for a primitive, off the union rather than a
    hand-kept table."""
    for candidate in typing.get_args(
            E.ActionComponent.model_fields["primitive"].annotation):
        literal = typing.get_args(candidate.model_fields["type"].annotation)
        if literal and literal[0] == primitive:
            return candidate
    raise AssertionError(f"no model for primitive {primitive!r}")


def _evidence(**over) -> M.CrossingEvidence:
    """Fixture evidence. The numbers say "if a crossing were measured
    like this", never "a crossing crosses this far" — the shipped table
    stays empty."""
    base = dict(primitive="dash", parameter="force",
                parameter_min=10.0, parameter_max=14.0,
                rise_min_m=-1.0, rise_max_m=1.5, reach_m=7.0,
                setup_digest="0123456789abcdef")
    base.update(over)
    return M.CrossingEvidence(**base)


SETUP = "0123456789abcdef"


def _qualify(mechanics, gap_m, rise_m=0.0, setup=SETUP):
    """Ask the real question: this provider, this crossing, this setup."""
    return M.qualifies_for_gap("cross_long_gap", mechanics, gap_m,
                               rise_m=rise_m, expected_setup=setup)


def test_a_measured_crossing_is_what_makes_qualification_possible(monkeypatch):
    """The accepted control. A check that refuses everything is as
    broken as one that refuses nothing, so the mechanism has to work
    when evidence covers the case AND is about this provider AND was
    measured against the setup being asked about."""
    monkeypatch.setitem(M.CROSSING_EVIDENCE, "dash", (_evidence(),))
    q = _qualify(_owning_dash(12.0), 6.0, rise_m=0.5)
    assert q.qualifies and q.reason == "meets_envelope"
    assert q.reach_m == 7.0 and q.rise_m == 0.5


def test_a_crossing_measured_flat_does_not_certify_a_landing_above_it(
        monkeypatch):
    """**The hole.** `rise_m` reached the base-kit comparison and stopped
    there, so a six-metre gap whose landing sat a hundred metres up was
    certified by evidence executed on level ground. Identical to the
    control in every other respect."""
    monkeypatch.setitem(M.CROSSING_EVIDENCE, "dash", (_evidence(),))
    flat = _qualify(_owning_dash(12.0), 6.0, rise_m=0.5)
    high = _qualify(_owning_dash(12.0), 6.0, rise_m=100.0)
    assert flat.qualifies, "the control still passes"
    assert not high.qualifies
    assert high.reason == "outside_measured_scope", high
    assert flat.gap_m == high.gap_m, "one variable changed: the landing"


def test_a_drop_below_the_measured_band_is_also_outside_it(monkeypatch):
    """Scope is a band, not a floor. Falling four metres while crossing
    is not the crossing that was measured either."""
    monkeypatch.setitem(M.CROSSING_EVIDENCE, "dash", (_evidence(),))
    q = _qualify(_owning_dash(12.0), 6.0, rise_m=-4.0)
    assert not q.qualifies and q.reason == "outside_measured_scope"


def test_a_stronger_provider_is_not_automatically_a_suitable_one(
        monkeypatch):
    """**The second hole.** A point measured at force 12 certified force
    14 and force 20, on the assumption that more impulse can only help.
    It can also overshoot the landing, clip a ceiling, or carry the body
    past the ledge it was meant to arrive on. Evidence certifies a
    stated RANGE and nothing outside it."""
    monkeypatch.setitem(M.CROSSING_EVIDENCE, "dash", (_evidence(),))
    inside = _qualify(_owning_dash(14.0), 6.0)
    beyond = _qualify(_owning_dash(20.0), 6.0)
    weaker = _qualify(_owning_dash(4.0), 6.0)
    assert inside.qualifies, "the top of the certified band still counts"
    assert not beyond.qualifies
    assert beyond.reason == "outside_measured_scope", beyond
    assert not weaker.qualifies
    assert weaker.reason == "outside_measured_scope", weaker


def test_measured_but_not_here_is_a_different_answer_from_never_measured(
        monkeypatch):
    """"Somebody should measure this" and "this was measured, just not
    for your case" send the engine lane to different work."""
    never = _qualify(_owning_dash(12.0), 6.0)
    assert never.reason == "no_envelope_measured"
    monkeypatch.setitem(M.CROSSING_EVIDENCE, "dash", (_evidence(),))
    elsewhere = _qualify(_owning_dash(20.0), 6.0)
    assert elsewhere.reason == "outside_measured_scope"


def test_a_provider_this_lane_cannot_qualify_says_so(monkeypatch):
    """`glide` satisfies `cross_long_gap` by identity and carries a fall
    -speed fraction; `hover` carries seconds. Neither is a thing this
    lane knows how to turn into metres, and a `force`-or-`range` shrug
    reported them as "no envelope measured" — which reads as work for
    the engine lane when the truth is that nobody has said what
    measuring them would mean."""
    q = _qualify(_owning("glide"), 6.0)
    assert not q.qualifies
    assert q.reason == "provider_not_qualifiable", q

    # And the table agrees for every member of the family that carries
    # neither of the two parameters qualification reads — `hover` needs
    # a resource link to fold at all, so it is asserted here rather than
    # built.
    for primitive in ACTIVITY_LONG_GAP:
        model = _primitive_model(primitive)
        readable = {"force", "range"} & set(model.model_fields)
        assert bool(readable) == (primitive in M.QUALIFIABLE_PARAMETER), (
            f"{primitive} carries {sorted(readable) or 'neither'} and "
            f"{'is' if primitive in M.QUALIFIABLE_PARAMETER else 'is not'} "
            "listed as qualifiable")


def test_evidence_names_the_parameter_it_certifies():
    """Evidence that certified `force` while qualification read `range`
    would be two lanes describing different numbers with one word."""
    for primitive, field in M.QUALIFIABLE_PARAMETER.items():
        assert field in ("force", "range")
        model = _primitive_model(primitive)
        assert field in model.model_fields, (
            f"{primitive} is qualified on '{field}' and has no such field")


def test_evidence_is_bound_to_the_setup_that_produced_it():
    """A controller change must invalidate a measurement rather than
    silently keep it, which is why `setup_digest` is required and shaped
    like `PhysicsSetup.scene_digest`."""
    with pytest.raises(ValidationError):
        M.CrossingEvidence(primitive="dash", parameter="force",
                           parameter_min=10.0, parameter_max=14.0,
                           rise_min_m=0.0, rise_max_m=1.0, reach_m=7.0,
                           setup_digest="not-a-digest")


def test_the_evidence_table_ships_empty_and_that_is_the_honest_state():
    """A gate with no measured crossing behind it is a route nobody has
    shown the player can make. Filling this is the engine lane's;
    inventing a number here would be this lane claiming a physical fact
    it cannot measure."""
    assert M.CROSSING_EVIDENCE == {}


def test_the_dash_parameter_is_a_speed_and_the_schema_says_so():
    """The trap the whole split exists to avoid: reading `force >= 8.0`
    as "eight metres". `Dash.force` is a velocity impulse, and
    `echo_runtime.gd::_dash` spends it as `player.velocity += dir *
    force`.

    An earlier version of this test asserted
    `"m/s" in (field.description or "") or True`, which cannot fail —
    a vacuous guard inside the test written to stop vacuous guarantees.
    This reads the bounds instead, which are speeds and are checked
    against the engine source that spends them.
    """
    field = E.Dash.model_fields["force"]
    lo = next(m.ge for m in field.metadata if getattr(m, "ge", None))
    hi = next(m.le for m in field.metadata if getattr(m, "le", None))
    assert (lo, hi) == (4, 20), (
        "these bounds are m/s. If they ever become metres the whole "
        "envelope contract changes shape and this test must say so")
    # A dash of 4–20 METRES would be inside or beyond the base kit's
    # own reach in a way that makes the envelope pointless; as speeds
    # they are not comparable to it at all, which is the point.
    assert C.max_safe_gap(0.0) < lo, (
        "if the bounds were distances, even the weakest dash would "
        "out-reach the base kit and no measurement would be needed")
    runtime = (Path(__file__).resolve().parents[2] / "godot" / "scripts"
               / "gameplay" / "echo_runtime.gd").read_text(encoding="utf-8")
    assert "player.velocity += dir * float(prim[\"force\"])" in runtime, (
        "the engine no longer spends `force` as a velocity impulse; the "
        "unit claim in QUALIFIABLE_PARAMETER and the envelope contract "
        "need re-reading against whatever it does now")
    assert M.MOBILITY_PARAMETER_UNITS["dash"] == "m/s"


# --- evidence identity, not just evidence shape ---------------------------
#
# The shape checks passed and the bindings did not exist: a row naming
# `blink` certified a dash, a row naming `range` certified a `force`
# reading, and any well-formed digest passed because nothing compared
# it. Testing that `setup_digest` is sixteen hex characters proved the
# field was well formed and nothing about whether it was the right one.

def test_evidence_filed_under_the_wrong_primitive_is_refused(monkeypatch):
    """A row in the `dash` table that says it is about `blink`. It is
    perfectly well-formed and it is not about this provider."""
    monkeypatch.setitem(M.CROSSING_EVIDENCE, "dash",
                        (_evidence(primitive="blink"),))
    q = _qualify(_owning_dash(12.0), 6.0, rise_m=0.5)
    assert not q.qualifies
    assert q.reason == "evidence_misfiled", q


def test_evidence_about_a_different_parameter_is_refused(monkeypatch):
    """`dash` is qualified on `force`. A row certifying a band of
    `range` is a band of a number this provider does not carry, and
    reading it as a force band compares two different quantities."""
    monkeypatch.setitem(M.CROSSING_EVIDENCE, "dash",
                        (_evidence(parameter="range"),))
    q = _qualify(_owning_dash(12.0), 6.0, rise_m=0.5)
    assert not q.qualifies
    assert q.reason == "evidence_misfiled", q


def test_a_misfiled_row_is_not_reported_as_an_unmeasured_one(monkeypatch):
    """Different answers send someone to different work: "measure this"
    against "this was measured and filed wrong"."""
    monkeypatch.setitem(M.CROSSING_EVIDENCE, "dash",
                        (_evidence(primitive="blink"),))
    misfiled = _qualify(_owning_dash(12.0), 6.0, rise_m=0.5)
    monkeypatch.setitem(M.CROSSING_EVIDENCE, "dash", ())
    absent = _qualify(_owning_dash(12.0), 6.0, rise_m=0.5)
    assert misfiled.reason == "evidence_misfiled"
    assert absent.reason == "no_envelope_measured"


def test_a_well_formed_digest_from_another_setup_is_refused(monkeypatch):
    """Sixteen hex characters and the wrong sixteen. The control above
    differs from this in one value."""
    monkeypatch.setitem(M.CROSSING_EVIDENCE, "dash",
                        (_evidence(setup_digest="fedcba9876543210"),))
    q = _qualify(_owning_dash(12.0), 6.0, rise_m=0.5)
    assert not q.qualifies
    assert q.reason == "evidence_for_another_setup", q


def test_no_setup_identity_means_no_qualification(monkeypatch):
    """Refused rather than waved through. Evidence that might be about
    another build is not evidence about this one, and a caller with no
    setup identity to offer cannot be told the crossing is fine.

    This is also why the digest is **recorded provenance** today rather
    than working stale-evidence invalidation: the comparison is here,
    and where the expected identity comes from is not yet agreed —
    `AP_CAPABILITY_LOGIC.md` §8b.
    """
    monkeypatch.setitem(M.CROSSING_EVIDENCE, "dash", (_evidence(),))
    q = M.qualifies_for_gap("cross_long_gap", _owning_dash(12.0), 6.0,
                            rise_m=0.5)
    assert not q.qualifies
    assert q.reason == "setup_identity_unknown", q
