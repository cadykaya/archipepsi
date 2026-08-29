"""The pre-art baseline is still the thing it claims to be.

`docs/baselines/playtest_2_5.json` exists so the playtest AFTER authored
art can be compared to the one before it. That comparison is only about
art if everything else held still — a Zone that changed shape, a budget
that moved, a schema the recorded Zone no longer satisfies, and the two
runs measured different games.

None of these tests tune anything. They are tripwires: each one names a
thing that would silently invalidate the baseline, and fails when it
moves so that re-baselining is a decision somebody made rather than a
thing that happened.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest
from pydantic import TypeAdapter

from archipepsi_bridge import content_value as V
from archipepsi_bridge.epsilon.fallback import fallback_echo, fallback_zone
from archipepsi_bridge.epsilon.requests import (EchoGenerationRequest,
                                                ZoneGenerationRequest)
from archipepsi_bridge.fixtures import make_playtest_baseline as B
from archipepsi_bridge.schemas import constants as C
from archipepsi_bridge.schemas import zone as Z
from archipepsi_bridge.schemas.echo import (EchoInterpretation,
                                            validate_interpretation)

_ZONE = TypeAdapter(Z.Zone)
_ECHO = TypeAdapter(EchoInterpretation)

BASELINE = Path(__file__).resolve().parents[2] / "docs/baselines/playtest_2_5.json"


@pytest.fixture(scope="module")
def baseline() -> dict:
    assert BASELINE.exists(), (
        f"{BASELINE} is missing; run `make baseline`")
    return json.loads(BASELINE.read_text())


def test_the_committed_baseline_matches_its_generator(baseline):
    """Generated, never hand-edited — the same rule the other fixtures
    live under. A failure here is not "fix the file": it means the
    engine builds a different Zone than the one anybody walked, so
    either that change was not meant to happen or the baseline needs
    retaking DELIBERATELY, with `make baseline`, in its own commit."""
    assert baseline == json.loads(json.dumps(B.build())), (
        "the baseline no longer matches what the engine builds; "
        "re-run `make baseline` only if the change was intended")


def test_the_baseline_replays_to_the_same_zone(baseline):
    """The whole point, stated directly: feed the recorded request back
    in and the same logical Zone comes out. This is what lets a later
    playtest walk the level this one walked."""
    for entry in baseline["zones"]:
        request = ZoneGenerationRequest.model_validate(entry["request"])
        again = json.loads(json.dumps(fallback_zone(request), default=str))
        assert again == entry["zone"], (
            f"zone {entry['zone_index']} no longer replays from its own "
            "recorded request")


def test_the_recorded_zones_still_validate(baseline):
    """A schema that moved under the baseline invalidates the corpus the
    same way it would invalidate the generation archive."""
    for entry in baseline["zones"]:
        request = ZoneGenerationRequest.model_validate(entry["request"])
        zone = _ZONE.validate_python(entry["zone"])
        errors = Z.validate_zone(
            zone, expected_zone_id=request.zone_id,
            allocated_location_ids=[loc.location_id
                                    for loc in request.locations],
            owned_echo_ids=[],
            owned_affordance_tags=request.unlocked_affordances,
            zone_budget=request.campaign.zone_budget)
        assert errors == [], (entry["zone_index"], errors)


def test_the_recorded_echoes_still_validate(baseline):
    for entry in baseline["echoes"]:
        request = EchoGenerationRequest.model_validate(entry["request"])
        echo = _ECHO.validate_python(entry["echo"])
        assert validate_interpretation(
            echo,
            expected_source_location_id=request.source.location_id) == []
        # Through JSON on both sides: the generator emits tuples and the
        # committed file holds lists, and that difference is the file
        # format rather than a change in the Echo.
        again = json.loads(json.dumps(fallback_echo(request), default=str))
        assert again == entry["echo"], (
            f"echo {entry['interpretation_seq']} no longer replays")


def test_the_measurements_are_derived_from_the_recorded_zone(baseline):
    """The summary cannot drift away from its own data. A hand-edited
    number here would be the one part of the baseline that is an
    opinion."""
    for entry in baseline["zones"]:
        zone = _ZONE.validate_python(entry["zone"])
        assert entry["measured"] == B._measure(zone)


# ---------------------------------------------------------------------------
# The tripwire the brief asked for by name


def test_nothing_was_retuned_under_the_baseline(baseline):
    """The scale the baseline was taken at is the scale it is valid at.

    The owner's instruction for Playtest 2.5 was explicit: do not retune
    the zone budget, the content-value weights, the location count, the
    Checks per Zone, the enemy budgets or the finale fraction —
    HUMAN MEASUREMENTS COME FIRST. This is that instruction as a test.

    It does not defend any of these numbers. It defends the COMPARISON:
    move one and the before-and-after stops being about art, so the
    baseline has to be retaken and the earlier playtest's numbers stop
    applying.
    """
    config = C.DEFAULT_CONFIG
    live = {
        "location_count": config.location_count,
        "zone_target_checks": config.zone_target_checks,
        "zone_budget": config.zone_budget,
        "check_value": V.CHECK_VALUE,
        "finale_required_fraction": C.FINALE_REQUIRED_FRACTION,
        "finale_required_checks": config.finale_required_checks(),
        "max_enemies_spawned_cap": C.MAX_ENEMIES_SPAWNED_CAP,
    }
    assert live == baseline["scale"], (
        "the campaign scale moved under the pre-art baseline; the "
        "playtest before and the playtest after are no longer measuring "
        "the same game")


def test_the_open_pacing_decision_has_not_been_quietly_acted_on(baseline):
    """`AGENT_FRONTIER.md` records this as OPEN and not to be changed
    until there is human evidence. The two numbers it is about are the
    finale gate and a full clear, and they are four hours apart at the
    unmeasured 40-minute target. Anyone closing that decision has to
    walk past this test to do it."""
    scale = baseline["scale"]
    zones_to_finale = scale["finale_required_checks"] \
        / scale["zone_target_checks"]
    zones_to_clear = scale["location_count"] / scale["zone_target_checks"]
    assert zones_to_finale == 24 and zones_to_clear == 30, (
        f"{zones_to_finale} Zones to the finale and {zones_to_clear} to a "
        "clear; the pacing decision this baseline was taken under has "
        "moved, and it was recorded as OPEN")


# ---------------------------------------------------------------------------
# The baseline is not itself a toy


def test_the_baseline_is_a_production_scale_campaign(baseline):
    """A baseline taken at prototype scale would be a baseline for a
    game nobody plays."""
    assert baseline["scale"]["location_count"] == 450
    assert baseline["provider"] == "fallback"
    for entry in baseline["zones"]:
        measured = entry["measured"]
        assert measured["checks"] == baseline["scale"]["zone_target_checks"]
        assert measured["chambers"] > 10
        assert measured["rooms_holding_no_check"] > 0, (
            "every room holds a Check, so this Zone is a Check corridor "
            "rather than a level")


def test_a_playtime_record_says_which_build_played_it(tmp_path):
    """A measurement that cannot say which side of authored art it is on
    cannot be compared to the baseline, which is the only reason the
    baseline exists.

    Also checks the module stayed narrow: `instrumentation` writes one
    local file and imports nothing that could reach anywhere, so the
    build is HANDED IN rather than looked up there.
    """
    import ast

    from archipepsi_bridge import instrumentation as I
    from archipepsi_bridge.version import build_metadata

    from .test_production_scale import PROD, _engine_at
    from .conftest import drain, run

    async def scenario():
        engine, _ = await _engine_at(tmp_path, PROD)
        return engine._build_metadata()

    build = run(scenario())
    assert build == build_metadata()
    for key in ("commit", "branch", "bridge_version", "tree"):
        assert key in build, key

    source = ast.parse(open(I.__file__, encoding="utf-8").read())
    imported = set()
    for node in ast.walk(source):
        if isinstance(node, ast.ImportFrom) and node.level:
            imported.add(node.module or "")
    assert "version" not in imported, (
        "instrumentation imports version, which shells out to git; the "
        "build is handed in so this module keeps touching one file")


def test_the_recorded_zones_are_not_the_same_zone(baseline):
    """Playtest 2 reported four Zones in a row playing identically. A
    baseline of three copies of one Zone would record the bug rather
    than the fix."""
    shapes = {json.dumps(e["zone"]["chambers"], sort_keys=True)
              for e in baseline["zones"]}
    assert len(shapes) == len(baseline["zones"])
