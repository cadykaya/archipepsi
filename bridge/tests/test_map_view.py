"""H-MAP-DATA — the map shows recorded consequences, and only what was found.

C-MAP, the four promises pinned here on the committed candidate Zone:

  possession    holding the red key or carrying the power cell opens
                nothing; opening the lock or installing the cell does;
  reversal      a reversible closure comes back when it is put back;
  permanence    a latched opening is still open after a reload (on
                M-1's legacy fixture: nothing composes one now);
  discovery     an undiscovered room gives away no name, and a gate's
                control is not placed on the map before its room is found.

No shared source is touched: this reads the save through transitions
that already exist.
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest

from archipepsi_bridge.schemas.map_view import derived_discovery, map_view, room_names
from archipepsi_bridge.schemas import echo as E
from archipepsi_bridge.schemas import protocol as P
from archipepsi_bridge.schemas import transitions as T
from archipepsi_bridge.schemas.zone import Zone

FIXTURE = (Path(__file__).resolve().parents[2]
           / "godot/tests/fixtures/candidate_zone.json")

RED_DOOR = "e:c011:c012"        # red lock at c011/side_right; key in c002
POWER_DOOR = "e:c005:c006"      # cell_power = powered; cell homed in c004
SPAN = "e:c002:c003"            # span_alignment = lowered, reversible
#: M-1's legacy fixture: a Zone composed with the retired step-once plate
#: (D-07), as a save made before the ruling holds it. The candidate no
#: longer composes one (D13 1b), so the machine-gate cases read this.
LEGACY = FIXTURE.parent / "latched_route_zone.json"
SHUTTER = "e:c002:c003"         # graph_c002: plate -> LATCH -> shutter
GAP = "e:c013:c016"             # given a grapple gate by the test below


def _zone() -> Zone:
    raw = json.loads(FIXTURE.read_text(encoding="utf-8"))
    return Zone.model_validate(raw.get("zone", raw))


def _save(zone: Zone) -> P.CampaignSave:
    top = max(zone.reward_location_ids) - 89100000
    save = P.CampaignSave(
        seed_name="Seed", team=0, slot_id=1, slot_name="Skyiah",
        scale=P.CampaignScale(location_count=max(top + 1, 30),
                              zone_target_checks=15, zone_budget=1000))
    save = T.start_generation(
        save, zone_id=zone.zone_id,
        allocated_location_ids=tuple(zone.reward_location_ids),
        target_game=zone.target_game)
    save = T.enter_zone(T.accept_zone(save, zone), zone.zone_id)
    return T.commit_layout(save, zone.zone_id, {
        "zone_id": zone.zone_id, "manifest_digest": "e" * 16,
        "rooms": {c.id: {} for c in zone.chambers}, "packages": []})


@pytest.fixture(scope="module")
def zone() -> Zone:
    return _zone()


@pytest.fixture(scope="module")
def legacy() -> Zone:
    raw = json.loads(LEGACY.read_text(encoding="utf-8"))
    return Zone.model_validate(raw.get("zone", raw))


@pytest.fixture()
def save(zone) -> P.CampaignSave:
    return _save(zone)


def _gate(save, zone, edge_id, visited=None):
    view = map_view(save, zone.zone_id,
                    visited=visited or {c.id for c in zone.chambers})
    return next(c for c in view.connectors if c.edge_id == edge_id)


# --- possession is not completion ------------------------------------------

def test_holding_the_key_leaves_its_door_blocked(zone, save):
    assert _gate(save, zone, RED_DOOR).state == "blocked"
    save = T.record_key(save, zone.zone_id, "red")
    held = _gate(save, zone, RED_DOOR)
    assert held.state == "blocked", "a held key opened its door by itself"
    assert "you hold it" in held.reason
    save = T.record_lock(save, zone.zone_id, "c011", "side_right")
    assert _gate(save, zone, RED_DOOR).state == "open"


def test_carrying_the_cell_leaves_the_powered_door_blocked(zone, save):
    save = T.record_object_transported(save, zone.zone_id, "power_cell",
                                       "c005")
    carried = _gate(save, zone, POWER_DOOR)
    assert carried.state == "blocked", "a carried cell powered the door"
    assert carried.gates == ("zone_state",)
    save = T.record_object_consumed(save, zone.zone_id, "cell_socket")
    installed = _gate(save, zone, POWER_DOOR)
    assert installed.state == "open"
    # Supply, receiver and door are one circuit, by the variable's id.
    view = map_view(save, zone.zone_id, visited={c.id for c in zone.chambers})
    (circuit,) = [c for c in view.circuits
                  if c.circuit_id == installed.circuits[0]]
    assert "power_cell" in circuit.objects and "c005" in circuit.rooms
    assert POWER_DOOR in circuit.connectors


# --- reversal and permanence ------------------------------------------------

def test_a_reversible_closure_comes_back(zone, save):
    assert _gate(save, zone, SPAN).state == "blocked"
    save = T.record_zone_state(save, zone.zone_id, "span_alignment",
                               "lowered")
    assert _gate(save, zone, SPAN).state == "open"
    save = T.record_zone_state(save, zone.zone_id, "span_alignment",
                               "stowed")
    assert _gate(save, zone, SPAN).state == "blocked", \
        "putting the span back left the map showing it open"


def test_a_latched_opening_survives_a_reload(legacy):
    """A legacy step-once route (M-1) reads as saved: shut until its
    latch is recorded, then open for good -- through a reload."""
    save = _save(legacy)
    assert _gate(save, legacy, SHUTTER).state == "blocked"
    save = T.record_latch(save, legacy.zone_id, "graph_c002", "held")
    save = P.CampaignSave.model_validate_json(save.model_dump_json())
    assert _gate(save, legacy, SHUTTER).state == "open"


def test_a_machine_gates_control_stays_unplaced_until_found(legacy):
    save = _save(legacy)
    view = map_view(save, legacy.zone_id, visited={"c003"})
    shutter = next(c for c in view.connectors if c.edge_id == SHUTTER)
    assert shutter.state == "blocked"
    assert "somewhere else" in shutter.reason, \
        "the map placed a control the player has not found"
    found = map_view(save, legacy.zone_id, visited={"c003", "c002"})
    shutter = next(c for c in found.connectors if c.edge_id == SHUTTER)
    assert room_names(legacy)["c002"] in shutter.reason


def _hookshot() -> E.EchoInterpretation:
    """A real grapple: an Action whose primitive satisfies `grapple`."""
    return E.EchoInterpretation.model_validate({
        "schema_version": 8, "echo_id": "echo_89100590",
        "interpretation_seq": 0, "source_location_id": 89100590,
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


def test_a_grapple_gate_is_not_yet_until_the_grapple_is_equipped():
    """Owning the grapple is not crossing with it: owned and unslotted
    is NOT YET, and says so; slotted is open."""
    raw = json.loads(FIXTURE.read_text(encoding="utf-8"))
    raw = raw.get("zone", raw)
    next(e for e in raw["edges"] if e["edge_id"] == GAP)["capability"] = \
        "grapple"
    zone = Zone.model_validate(raw)
    save = _save(zone)
    gap = _gate(save, zone, GAP)
    assert (gap.gates, gap.state, gap.reason) == (
        ("capability",), "blocked", "needs grapple")
    save = T.append_interpretation(save, _hookshot())
    owned = _gate(save, zone, GAP)
    assert owned.state == "blocked", "an unslotted grapple crossed the gap"
    assert "equip it" in owned.reason
    save = T.slot_action(save, "mobility", "act_hook")
    assert _gate(save, zone, GAP).state == "open"


# --- discovery ---------------------------------------------------------------

def test_an_undiscovered_room_gives_nothing_away(zone, save):
    view = map_view(save, zone.zone_id, visited={"c010"})
    assert [r.room_id for r in view.rooms if r.discovered] == ["c010"]
    assert all(r.name is None for r in view.rooms if not r.discovered)
    assert all("c010" in (c.room_a, c.room_b) for c in view.connectors)
    assert view.connectors, "nothing was drawn at all"
    dump = view.model_dump_json()
    for authored in ("Unweighted Switch", "Counterfire Arcade"):
        assert authored not in dump
    for circuit in view.circuits:
        assert set(circuit.rooms) <= {"c010"}


def test_a_one_way_return_shows_from_where_it_leaves(zone, save):
    """The entrance receives eight return plugs. Standing only there,
    none is on the map; finding c021 shows its own, one-way."""
    plugs = {e.edge_id for e in zone.edges if e.edge_id.startswith("p:")}
    assert len(plugs) == 8
    view = map_view(save, zone.zone_id, visited={"c001"})
    assert not plugs & {c.edge_id for c in view.connectors}, \
        "the map drew returns from rooms the player has not found"
    view = map_view(save, zone.zone_id, visited={"c001", "c021"})
    (plug,) = [c for c in view.connectors if c.edge_id in plugs]
    assert (plug.edge_id, plug.direction, plug.realization) == (
        "p:c021:start", "A_TO_B", "traversal_only")


def test_a_gates_supply_stays_off_the_map_until_found(zone, save):
    view = map_view(save, zone.zone_id, visited={"c006"})
    door = next(c for c in view.connectors if c.edge_id == POWER_DOOR)
    assert "somewhere else" in door.reason
    (circuit,) = [c for c in view.circuits
                  if c.circuit_id == door.circuits[0]]
    assert circuit.rooms == () and circuit.objects == (), \
        "the map placed a supply the player has not found"
    found = map_view(save, zone.zone_id, visited={"c006", "c005"})
    (circuit,) = [c for c in found.circuits
                  if c.circuit_id == door.circuits[0]]
    assert "c005" in circuit.rooms and "power_cell" in circuit.objects


def test_a_save_without_a_discovery_record_shows_only_what_it_proves(
        zone, save):
    """No discovery record: the entrance, and rooms a recorded fact
    names. An undercount, never a guess."""
    assert derived_discovery(zone, save.zone_by_id(zone.zone_id).progress) \
        == {"c001"}
    save = T.record_key(save, zone.zone_id, "red")
    save = T.record_lock(save, zone.zone_id, "c011", "side_right")
    seen = derived_discovery(zone, save.zone_by_id(zone.zone_id).progress)
    assert seen == {"c001", "c002", "c011"}
    view = map_view(save, zone.zone_id)
    assert {r.room_id for r in view.rooms if r.discovered} == seen


# --- names (M-3) -------------------------------------------------------------

def test_names_are_presentation_and_never_identity(zone, save):
    names = room_names(zone)
    assert names["c024"] == "Unweighted Switch"
    assert names["c025"] == "Counterfire Arcade"
    assert names["c001"] == "Corridor 1" and names["c002"] == "Arena 1"
    assert len(set(names.values())) == len(names), "two rooms read alike"
    view = map_view(save, zone.zone_id,
                    visited={c.id for c in zone.chambers})
    assert [r.room_id for r in view.rooms] == [c.id for c in zone.chambers]
    assert "Unweighted Switch" not in save.model_dump_json(), \
        "a presentation name reached the save"
