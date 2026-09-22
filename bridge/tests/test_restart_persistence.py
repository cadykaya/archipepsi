"""P04 — what a candidate snapshot carries, and what it must never carry.

Overnight 04, package P04. The bridge's half of process-restart
persistence: the representation, its completeness, and the guard that
keeps it from quietly growing a field the design forbids.

**NOTHING HERE IS A COLD RESTART** (owner correction 3). Every case
below round-trips a save through JSON in one process. That is evidence
about the REPRESENTATION. P04.3 asks for the client and the bridge to be
terminated and relaunched on a disposable save, at five named points,
with real world state read afterwards -- the client half is Prod's and
the bridge harness does not exist. It is not started, and it is not
reported as anything else.
"""
from __future__ import annotations

import pytest

from archipepsi_bridge.schemas import protocol as P
from archipepsi_bridge.schemas import transitions as T


def _save() -> P.CampaignSave:
    return P.CampaignSave(seed_name="Seed", team=0, slot_id=1,
                          slot_name="Skyiah")


def _round_trip(save: P.CampaignSave) -> P.CampaignSave:
    """Serialize and re-parse. **NOT a process restart.**

    Owner correction 3, 2026-09-22: this used to be called `_restart`
    and the docstring said "a process restart: nothing survives but the
    serialised save". It is one process, nothing is terminated, and
    nothing is relaunched. **It is serialization evidence** -- the
    representation round-trips -- and P04.3 asks for something this
    cannot show: terminating the client and the bridge on a disposable
    save and reading real world state afterwards.

    Renamed so no reader has to take the docstring's word for what the
    call does.
    """
    return P.CampaignSave.model_validate_json(save.model_dump_json())


# --------------------------------------------------------------------------
# P04.1 — the snapshot is complete, and it is complete on purpose
# --------------------------------------------------------------------------

def test_every_persistent_lifetime_has_somewhere_to_live():
    """D-8 §3's five lifetimes, checked against the actual save surface.

    Three persist and have a field; two do not persist and must not have
    one. Enumerated rather than asserted one at a time, so a lifetime
    added later has to be placed deliberately.
    """
    fields = set(P.ZoneProgress.model_fields)
    assert "latched" in fields, "1: permanent accepted changes"
    assert "macro_state" in fields, "2: reversible Zone configuration"
    # 3 temporary timers/Statuses and 4 held inputs are EPHEMERAL (§5.1,
    # §5.4a) -- their absence is the representation.
    assert not {"statuses", "active_statuses", "timers", "held_inputs"} & fields
    # 5 transported objects: an explicit unfinished 0.4 row, and saying
    # so here is what stops a later reader assuming it is covered.
    assert not {"carried_objects", "transported"} & fields


def test_no_saved_field_holds_a_derived_live_signal_value():
    """§5.4a: *"Nothing serializes a signal node's current value."*

    **REPLACED, 2026-09-22 (owner correction 4).** The first version of
    this control scanned field NAMES for `transform`, `pose`,
    `position`, `velocity` and `elapsed` and failed on any of them. That
    generalised `rail_junction.gd`'s supported-dock policy into a
    universal ban on physical saved state, and it is wrong:
    **EX50-011 §9 explicitly requires the opposite** -- *"carrier poses,
    destinations and hold states are package-local. A stable save
    restores each at its saved pose before the player."* A runtime
    comment about one railway does not supersede a selected spec about
    another package.

    What §5.4a actually forbids is a **derived live value**: something
    the graph recomputes on restore. A save holding voltages could
    disagree with the graph that produced them. Physical state that a
    package's own contract requires is permitted, and must declare which
    §5.1 category it belongs to.

    So this checks the categories rather than the spelling.
    """
    # §5.1's five, and every persisted field has to be one of them.
    categories = {"EPHEMERAL", "PUZZLE_LOCAL", "ROOM_PERSISTENT",
                  "ZONE_PERSISTENT", "AP_PERSISTENT"}
    declared = P.SAVE_FIELD_CATEGORY

    persisted = set(P.ZoneProgress.model_fields)
    assert set(declared) == persisted, (
        f"undeclared: {sorted(persisted - set(declared))}; "
        f"declared but absent: {sorted(set(declared) - persisted)}")
    assert set(declared.values()) <= categories

    # EPHEMERAL is the one category that may not appear in a save at all
    # -- that is what EPHEMERAL MEANS.
    ephemeral = [f for f, c in declared.items() if c == "EPHEMERAL"]
    assert not ephemeral, (
        f"{ephemeral} are declared EPHEMERAL and are in the save; §5.1 "
        "says they are rebuilt, not restored")


def test_the_category_rule_admits_the_pose_ex50_011_asks_for():
    """The control that shows the replacement is not just a looser rule.

    A package-local carrier pose is `PUZZLE_LOCAL` -- §5.1's row for a
    `PhysicalConfiguration` that is `required` or constrained -- and the
    category check admits it while still refusing a live signal value.
    """
    assert P.categorise_save_field("carrier_pose", "PUZZLE_LOCAL") is None
    assert P.categorise_save_field("hold_state", "PUZZLE_LOCAL") is None
    problem = P.categorise_save_field("plate_signal", "EPHEMERAL")
    assert problem is not None and "EPHEMERAL" in problem


def test_manifest_provenance_survives_a_round_trip():
    """P04.1's "stable IDs and manifest provenance". The layout is
    solved once and replayed forever, so the digest has to come back."""
    from archipepsi_bridge.schemas.zone import Zone
    save = _save()
    save = T.start_generation(save, zone_id="zone_001",
                              allocated_location_ids=(89100001,),
                              target_game="Game")
    zone = Zone.model_validate({
        "schema_version": 7, "zone_id": "zone_001", "display_name": "R",
        "target_game": "Game", "theme": "void_glitch",
        "chambers": [{"id": "c001", "type": "arena", "width": 16.0,
                      "depth": 15.0, "wall_height": 5.0,
                      "objective": "kill_all",
                      "reward_location_id": 89100001,
                      "enemies": [{"archetype": "melee", "count": 1}]},
                     {"id": "c002", "type": "arena", "width": 16.0,
                      "depth": 15.0, "wall_height": 5.0,
                      "objective": "kill_all", "reward_location_id": None,
                      "enemies": [{"archetype": "melee", "count": 1}]}],
    })
    save = T.accept_zone(save, zone)
    save = T.enter_zone(save, "zone_001")
    save = T.commit_layout(save, "zone_001", {"manifest_digest": "abc123"})

    back = _round_trip(save)
    rec = back.zone_by_id("zone_001")
    assert rec.manifest["manifest_digest"] == "abc123"
    assert rec.layout_state == "ACCEPTED"


# --------------------------------------------------------------------------
# P04.3 — the same restart at points that are not the same state
# --------------------------------------------------------------------------

def _progressed(**kw) -> P.ZoneProgress:
    p = P.ZoneProgress()
    for key, state in kw.pop("macro", ()):
        p = p.with_macro(key, state)
    for ref in kw.pop("latched", ()):
        p = p.with_latch(ref)
    for k in kw.pop("keys", ()):
        p = p.with_key(k)
    return p


def test_the_points_a_restart_would_happen_at_are_distinguishable():
    """P04.3 asks for restarts at *meaningful points*, which is only
    meaningful if the points differ. Four states, each round-tripped,
    each still itself afterwards -- a save that dropped one of these
    would pass a single-point test.

    **This is the representation half only.** The restart itself is not
    here; see `_round_trip`.
    """
    points = {
        "before any grant": _progressed(),
        "after a span repair": _progressed(latched=("yard/span_one",)),
        "after a configuration change": _progressed(
            macro=(("span_alignment", "lowered"),)),
        "both, plus a key": _progressed(
            latched=("yard/span_one",),
            macro=(("span_alignment", "lowered"),), keys=("k_yard",)),
    }
    seen = set()
    for label, progress in points.items():
        blob = progress.model_dump_json()
        assert blob not in seen, f"{label} is not a distinct state"
        seen.add(blob)
        back = P.ZoneProgress.model_validate_json(blob)
        assert back == progress, label


def test_a_reversible_configuration_comes_back_reversible():
    """Not as a latch wearing the name: after the restart it can still
    be put back, and the monotone set is untouched by that."""
    before = _progressed(macro=(("span_alignment", "lowered"),),
                         latched=("yard/span_one",))
    back = P.ZoneProgress.model_validate_json(before.model_dump_json())
    undone = back.with_macro("span_alignment", "stowed")
    assert undone.macro("span_alignment") == "stowed"
    assert undone.latched == ("yard/span_one",)


# --------------------------------------------------------------------------
# P04.4 / P04.6 — recovery that does not cost the player anything
# --------------------------------------------------------------------------

def test_a_refused_layout_keeps_the_checks_and_the_campaign_moves():
    """P04.6's bounded failed build, through the real failure path.

    A refusal is a generation problem, not a decision the player made,
    so the Zone goes back to be composed again **against the ids it
    already holds**. Nothing is re-allocated and nothing is consumed.
    """
    from archipepsi_bridge.schemas.zone import Zone
    save = _save()
    save = T.start_generation(save, zone_id="zone_001",
                              allocated_location_ids=(89100001,),
                              target_game="Game")
    zone = Zone.model_validate({
        "schema_version": 7, "zone_id": "zone_001", "display_name": "R",
        "target_game": "Game", "theme": "void_glitch",
        "chambers": [{"id": "c001", "type": "arena", "width": 16.0,
                      "depth": 15.0, "wall_height": 5.0,
                      "objective": "kill_all",
                      "reward_location_id": 89100001,
                      "enemies": [{"archetype": "melee", "count": 1}]},
                     {"id": "c002", "type": "arena", "width": 16.0,
                      "depth": 15.0, "wall_height": 5.0,
                      "objective": "kill_all", "reward_location_id": None,
                      "enemies": [{"archetype": "melee", "count": 1}]}],
    })
    save = T.enter_zone(T.accept_zone(save, zone), "zone_001")
    held = save.zone_by_id("zone_001").allocated_location_ids

    refused = T.refuse_layout(save, "zone_001")
    rec = refused.zone_by_id("zone_001")
    assert rec.state == "PENDING_GENERATION"
    assert rec.allocated_location_ids == held, (
        "a refused layout must not give the player's locations back")
    assert _round_trip(refused).zone_by_id("zone_001").state \
        == "PENDING_GENERATION"


def test_nothing_in_zone_progress_is_keyed_by_a_room_or_a_package():
    """P04.4's bridge half, and it is a shape claim rather than a
    simulation: a package-scoped reset cannot reach Zone progress
    because none of it is addressed by package or by room.

    `opened_locks` is the near miss -- it holds `room_id/socket_id` --
    and it is the one that would break if a room reset ever cleared by
    prefix, so it is named rather than waved past.
    """
    p = (P.ZoneProgress().with_key("k")
         .with_lock("c004", "door_n")
         .with_latch("yard/span_one")
         .with_macro("span_alignment", "lowered")
         .with_station("st_c002"))
    assert p.opened_locks == ("c004/door_n",)
    # The identity is the DOOR, not the room, and a reset of room c004's
    # package state is not a reset of the fact that a door was opened.
    after = p.with_macro("span_alignment", "stowed")
    assert after.opened_locks == p.opened_locks
    assert after.collected_keys == p.collected_keys
    assert after.latched == p.latched
    assert after.reached_stations == p.reached_stations
