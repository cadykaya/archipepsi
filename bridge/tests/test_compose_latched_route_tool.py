"""The replay tool's two forms (D-07, D13 1c).

`tools/compose_latched_route.py` seeds Prod's `godot-latched-route-live`:
it takes the latch step on a save the real path generated and refuses
unless the result is the fixture the standalone suite plays. `legacy`,
the default, is M-1's replay of the retired step-once plate; `lever` is
the production route, for when the live suite plays the lever as
composed; `held` is 1d's weight on a plate (Prod's N-8). Each form must
land on exactly its own fixture, and never on another's.
"""
from __future__ import annotations

import importlib
from pathlib import Path

import pytest

from archipepsi_bridge import store
from archipepsi_bridge.playtest import played_zone
from archipepsi_bridge.schemas import protocol as P
from archipepsi_bridge.schemas import transitions as T

FIXTURES = Path(__file__).resolve().parents[2] / "godot/tests/fixtures"
TOOL = importlib.import_module("tools.compose_latched_route")


def _generated_save(tmp_path: Path) -> Path:
    """A campaign whose Zone is generated and accepted, never entered --
    the state the live suite's seed phase leaves it in."""
    zone = played_zone()
    assert zone is not None
    top = max(zone.reward_location_ids) - 89100000
    save = P.CampaignSave(
        seed_name="Seed", team=0, slot_id=1, slot_name="Skyiah",
        scale=P.CampaignScale(location_count=max(top + 1, 30),
                              zone_target_checks=15, zone_budget=1000))
    save = T.start_generation(
        save, zone_id=zone.zone_id,
        allocated_location_ids=tuple(zone.reward_location_ids),
        target_game=zone.target_game)
    save = T.accept_zone(save, zone)
    path = tmp_path / "campaign.json"
    store.write_save(path, save)
    return path


@pytest.mark.parametrize("form, fixture, sensor", [
    (None, "latched_route_zone.json", "PRESSURE_PLATE"),
    ("lever", "lever_route_zone.json", "PULSE_BUTTON"),
    ("held", "held_route_zone.json", "PRESSURE_PLATE"),
])
def test_each_form_lands_on_exactly_its_own_fixture(tmp_path, form,
                                                    fixture, sensor):
    path = _generated_save(tmp_path)
    argv = [str(tmp_path), "--expect", str(FIXTURES / fixture)]
    if form:
        argv += ["--form", form]
    assert TOOL.main(argv) == 0
    zone = store.load_save(path).active_zone.zone
    assert [s.kind for s in zone.room_graphs[0].sensors] == [sensor]
    # The held form carries its weight into the save, where the bridge
    # keeps its pose across a restart.
    held_by = zone.room_graphs[0].sensors[0].held_by
    assert held_by == ("counterweight" if form == "held" else None)
    assert (held_by in {o.object_id for o in zone.transported_objects}) \
        == (form == "held")


@pytest.mark.parametrize("form, fixture", [
    (None, "lever_route_zone.json"),
    ("lever", "latched_route_zone.json"),
    ("held", "latched_route_zone.json"),
    (None, "held_route_zone.json"),
])
def test_a_form_never_passes_for_the_other_s_fixture(tmp_path, form,
                                                     fixture):
    """The comparison is the point: a lever seeded against the legacy
    fixture, or the reverse, is refused and the save is left alone."""
    path = _generated_save(tmp_path)
    before = path.read_bytes()
    argv = [str(tmp_path), "--expect", str(FIXTURES / fixture)]
    if form:
        argv += ["--form", form]
    assert TOOL.main(argv) == 1
    assert path.read_bytes() == before
