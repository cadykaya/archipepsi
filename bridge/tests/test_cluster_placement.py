"""The authored-cluster placement contract (art requirement 5).

`PROP_FOOTPRINT` is 1.4 m. That is right for an L0 prop — a crate, a
sconce, a pipe stub — and far too small for an L2 station or a
storytelling cluster, which is a COMPOSED group of pieces that reads as
one thing. Art could not author one without guessing how much room the
runtime would give it, so it did not author one.

This is the legal envelope and the placement grammar, and deliberately
nothing else. It says how big a cluster may be, what it may hang off,
what it must leave clear, and how that is checked. It says nothing about
what a cluster CONTAINS.
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest

from archipepsi_bridge.schemas import constants as C

ROOT = Path(__file__).resolve().parents[2]
BUILDERS_GD = ROOT / "godot" / "scripts" / "generation" / "chamber_builders.gd"
REGISTRY_GD = ROOT / "godot" / "scripts" / "content" / "content_registry.gd"


def _gd_const(name: str) -> float:
    match = re.search(rf"const {name} := ([0-9.]+)", BUILDERS_GD.read_text())
    assert match, f"{name} not found"
    return float(match.group(1))


def _wall(**over) -> C.ClusterFootprint:
    base = dict(width=4.0, height=2.4, depth=1.2, anchor="floor_wall")
    base.update(over)
    return C.ClusterFootprint(**base)


class TestTheEnvelopeIsBiggerThanAProp:

    def test_a_cluster_may_be_larger_than_PROP_FOOTPRINT(self):
        """The whole reason the contract exists."""
        prop = _gd_const("PROP_FOOTPRINT")
        assert C.CLUSTER_MAX_WIDTH > prop
        assert C.CLUSTER_MAX_DEPTH > prop / 2.0

    def test_the_envelope_is_bounded_in_every_axis(self):
        for kwargs, field in (
                (dict(width=C.CLUSTER_MAX_WIDTH + 0.1), "width"),
                (dict(height=C.CLUSTER_MAX_HEIGHT + 0.1), "height"),
                (dict(depth=C.CLUSTER_MAX_DEPTH + 0.1), "depth")):
            with pytest.raises(ValueError, match=field):
                _wall(**kwargs)

    def test_a_cluster_cannot_quietly_become_a_room_shell(self):
        """Bounded so "cluster" stays a thing you put IN a room."""
        assert C.CLUSTER_MAX_WIDTH < 10.0
        assert C.CLUSTER_MAX_DEPTH < 4.0


class TestTheAnchorGrammar:

    def test_there_is_no_free_standing_floor_anchor(self):
        """I4: the mandatory path is independent of optional content. An
        island setpiece is either on the route or something to walk
        around, and neither is a thing to discover at runtime."""
        assert "floor" not in C.CLUSTER_ANCHORS
        assert set(C.CLUSTER_ANCHORS) == {
            "floor_wall", "floor_corner", "wall", "ceiling"}

    def test_an_unknown_anchor_is_refused(self):
        with pytest.raises(ValueError, match="not a cluster anchor"):
            _wall(anchor="floating")

    def test_a_floor_cluster_stands_on_the_floor(self):
        for anchor in C.CLUSTER_FLOOR_ANCHORS:
            assert _wall(anchor=anchor).stands_on_the_floor
            with pytest.raises(ValueError, match="stands on the floor"):
                _wall(anchor=anchor, mount_height=2.0)

    def test_a_mounted_cluster_must_say_where_it_hangs(self):
        for anchor in ("wall", "ceiling"):
            with pytest.raises(ValueError, match="must declare"):
                _wall(anchor=anchor)
            assert not _wall(anchor=anchor,
                             mount_height=3.0).stands_on_the_floor


class TestTheWalkingLaneIsNeverEaten:
    """The rule that actually decides whether a cluster fits."""

    def test_only_a_colliding_floor_cluster_costs_lane(self):
        assert _wall(collides=True).lane_cost == pytest.approx(1.6)
        assert _wall(collides=False).lane_cost == 0.0
        assert _wall(anchor="ceiling", mount_height=3.0,
                     collides=True).lane_cost == 0.0

    def test_a_cluster_that_would_pinch_the_lane_is_refused(self):
        lane = _gd_const("BRUTE_LANE")
        # 5 m corridor: 2.0 deep + 0.4 clearance leaves exactly the lane.
        assert C.cluster_placement_errors(
            _wall(depth=2.0), 12.0, 5.0, 3.6, lane) == []
        errors = C.cluster_placement_errors(
            _wall(depth=2.1), 12.0, 5.0, 3.6, lane)
        assert any("walking lane" in e for e in errors), errors

    def test_dressing_fits_where_a_solid_cluster_does_not(self):
        """The honest half: a cluster the player cannot walk into costs
        the lane nothing, and saying otherwise would refuse decoration
        for occupying space it does not occupy."""
        lane = _gd_const("BRUTE_LANE")
        solid = C.cluster_placement_errors(
            _wall(depth=2.4), 12.0, 5.0, 3.6, lane)
        dressing = C.cluster_placement_errors(
            _wall(depth=2.4, collides=False), 12.0, 5.0, 3.6, lane)
        assert solid and not dressing


class TestOrientationIsExplicit:
    """A cluster on a side wall runs along z and reaches along x; one on
    an end wall does the opposite. Two axis names would mean each caller
    deciding which was which, and half of them deciding wrong."""

    def test_width_is_checked_against_the_wall_it_hangs_on(self):
        lane = _gd_const("BRUTE_LANE")
        wide = _wall(width=5.0, depth=0.8)
        # A 12 m side wall takes it; a 5 m end wall does not.
        assert C.cluster_placement_errors(wide, 12.0, 5.0, 3.6, lane) == []
        errors = C.cluster_placement_errors(wide, 5.0, 12.0, 3.6, lane)
        assert any("along a 5.0m wall" in e for e in errors), errors

    def test_depth_is_checked_against_the_span_it_reaches_into(self):
        lane = _gd_const("BRUTE_LANE")
        errors = C.cluster_placement_errors(
            _wall(width=1.0, depth=2.4), 12.0, 2.0, 3.6, lane)
        assert any("does not fit into a 2.0m span" in e for e in errors)


class TestMountedClustersClearTheHeadroom:

    def test_a_cluster_hung_too_low_is_refused(self):
        with pytest.raises(ValueError, match="must declare"):
            _wall(anchor="ceiling", mount_height=0.0)
        errors = C.cluster_placement_errors(
            _wall(anchor="ceiling", height=0.5, mount_height=2.0),
            12.0, 8.0, 4.0, 2.6)
        assert any("pass under" in e for e in errors), errors

    def test_the_underside_clears_the_tallest_walker(self):
        assert C.CLUSTER_MOUNTED_UNDERSIDE_MIN > C.TALLEST_GROUND_ACTOR

    def test_a_cluster_cannot_reach_through_the_ceiling(self):
        errors = C.cluster_placement_errors(
            _wall(anchor="ceiling", height=1.2, mount_height=3.0),
            12.0, 8.0, 3.6, 2.6)
        assert any("reaches through" in e for e in errors), errors


class TestTheAnswerIsDeterministicAndTotal:

    def test_the_same_question_gets_the_same_answer(self):
        footprint = _wall(depth=2.3)
        first = C.cluster_placement_errors(footprint, 12.0, 5.0, 3.6, 2.6)
        for _ in range(5):
            assert C.cluster_placement_errors(
                footprint, 12.0, 5.0, 3.6, 2.6) == first

    def test_every_refusal_names_its_reason(self):
        errors = C.cluster_placement_errors(
            _wall(width=5.5, depth=2.4), 5.0, 3.0, 2.0, 2.6)
        assert len(errors) >= 2
        for message in errors:
            assert len(message) > 20, "a refusal art cannot act on"

    def test_an_ordinary_cluster_in_an_ordinary_arena_is_allowed(self):
        """A grammar that refuses everything is indistinguishable from a
        broken one."""
        for anchor in ("floor_wall", "floor_corner"):
            assert C.cluster_placement_errors(
                _wall(anchor=anchor), 18.0, 16.0, 6.0, 2.6) == []
        assert C.cluster_placement_errors(
            _wall(anchor="wall", height=1.5, mount_height=3.0),
            18.0, 16.0, 6.0, 2.6) == []


class TestGodotValidatesTheSameEnvelope:
    """Art declares a footprint in a manifest; the registry refuses an
    illegal one at LOAD, before anything tries to place it."""

    def test_the_registry_knows_the_cluster_category(self):
        source = REGISTRY_GD.read_text()
        assert '"cluster": [2]' in source
        assert 'const NEEDS_FOOTPRINT := ["cluster"]' in source

    def test_the_validator_reads_the_exported_numbers(self):
        source = REGISTRY_GD.read_text()
        for name in ("CLUSTER_ANCHORS", "CLUSTER_FLOOR_ANCHORS",
                     "CLUSTER_MAX_WIDTH", "CLUSTER_MAX_HEIGHT",
                     "CLUSTER_MAX_DEPTH",
                     "CLUSTER_MOUNTED_UNDERSIDE_MIN"):
            assert f"Constants.{name}" in source, (
                f"the registry does not read Constants.{name}; a second "
                "opinion about the envelope is how art and the runtime "
                "disagree")

    def test_the_numbers_reach_gdscript(self):
        source = (ROOT / "godot" / "scripts" / "autoload"
                  / "constants.gd").read_text()
        assert f"const CLUSTER_MAX_WIDTH = {C.CLUSTER_MAX_WIDTH!r}" in source
        assert f"const CLUSTER_CLEARANCE = {C.CLUSTER_CLEARANCE!r}" in source
        assert ('const CLUSTER_ANCHORS = '
                f'{list(C.CLUSTER_ANCHORS)!r}'.replace("'", '"')) in source
