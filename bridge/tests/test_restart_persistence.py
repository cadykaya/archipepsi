"""P04 — what a candidate snapshot carries, and what it must never carry.

Overnight 04, package P04. The bridge's half of process-restart
persistence: the representation, its completeness, and the guard that
keeps it from quietly growing a field the design forbids.

**The engine half is not here.** Actually terminating and restarting the
client (P04.3's "real world state, remaining Checks and usable return"),
machinery interrupted mid-motion (P04.5) and the user-facing failure
paths (P04.6) are Prod's, and a JSON round trip is deliberately not
reported as either.
"""
from __future__ import annotations

import pytest

from archipepsi_bridge.schemas import protocol as P
from archipepsi_bridge.schemas import transitions as T


def _save() -> P.CampaignSave:
    return P.CampaignSave(seed_name="Seed", team=0, slot_id=1,
                          slot_name="Skyiah")


def _restart(save: P.CampaignSave) -> P.CampaignSave:
    """A process restart: nothing survives but the serialised save."""
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


def test_the_save_never_grows_a_field_the_design_forbids():
    """§5.4a: *"Nothing serializes a signal node's current value."*

    And rail_junction.gd's own rule: a carrier is restored to a
    SUPPORTED DOCK, never to a saved transform -- a carrier resumed
    halfway across a link this build did not commission would be
    standing on track that is not there.

    So this is the case that fails if someone adds one. A save that
    stored voltages could disagree with the graph that produced them,
    and a save that stored poses could put the player on absent track.
    """
    forbidden = ("transform", "pose", "position", "rotation", "velocity",
                 "voltage", "signal_value", "node_value", "elapsed",
                 "remaining_seconds")
    surfaces = {
        "ZoneProgress": P.ZoneProgress.model_fields,
        "ZoneRecord": P.ZoneRecord.model_fields,
        "CampaignSave": P.CampaignSave.model_fields,
    }
    def scan(surface):
        return [f"{cls}.{name}" for cls, fields in surface.items()
                for name in fields
                for bad in forbidden if bad in name.lower()]

    # THE GUARD IS A NAME LINTER, so it is shown catching something
    # before it is trusted to report nothing. Without this the test
    # passes just as well with an empty `forbidden`.
    assert scan({"Fake": {"carrier_transform": None,
                          "signal_value": None}}) == [
        "Fake.carrier_transform", "Fake.signal_value"]

    offences = scan(surfaces)
    assert not offences, (
        f"{offences} look like live or physical state. §5.4a restores "
        "semantic state and recomputes everything else; if one of these "
        "is genuinely needed, it needs a ruling, not a field")


def test_manifest_provenance_survives_a_restart():
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

    back = _restart(save)
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


def test_restart_points_are_distinguishable_from_each_other():
    """P04.3 asks for restarts at *meaningful points*, which is only
    meaningful if the points differ. Four states, each round-tripped,
    each still itself afterwards -- a save that dropped one of these
    would pass a single-point test.
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
    assert _restart(refused).zone_by_id("zone_001").state \
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
