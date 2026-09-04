"""The enemy physical envelope contract (art requirement 7).

The approved enemy production family is TEN roles. `enemy.gd` knew three,
and it knew their colliders as three magic vectors inside a `match kind:`
— while the art lane built models against boxes declared in its own
manifests. Two numbers for one thing, in two languages, on two branches.
Nothing would have caught the disagreement until a model clipped through
a door frame in front of a player.

So there is one table, in the file the art toolchain already imports, and
these tests are what stop it drifting: from the GDScript that builds the
collider, from the room dimensions the envelopes have to fit inside, and
from the behaviour tables that decide what may actually be placed.

An envelope is PHYSICAL ONLY. Giving a role a box is not giving it a
fight, and the separation is tested rather than trusted.
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest

from archipepsi_bridge.schemas import constants as C

ROOT = Path(__file__).resolve().parents[2]
ENEMY_GD = ROOT / "godot" / "scripts" / "enemies" / "enemy.gd"
BUILDERS_GD = ROOT / "godot" / "scripts" / "generation" / "chamber_builders.gd"
CONSTANTS_GD = ROOT / "godot" / "scripts" / "autoload" / "constants.gd"

#: The ten the owner approved, named here so shrinking the family back to
#: the prototype trio fails a test rather than passing quietly.
APPROVED_FAMILY = {
    "melee", "ranged", "brute", "charger", "bulwark", "scuttler",
    "artillery", "beacon", "diver", "drifter",
}


def _gd_const(path: Path, name: str) -> float:
    match = re.search(rf"const {name} := ([0-9.]+)", path.read_text())
    assert match, f"{name} not found in {path.name}"
    return float(match.group(1))


class TestTheFamilyIsTheApprovedTen:

    def test_every_approved_role_has_an_envelope(self):
        assert set(C.ENEMY_ROLES) == APPROVED_FAMILY

    def test_the_family_is_not_reduced_to_the_prototype_trio(self):
        """The Batch 002 review said so explicitly: *this roster is the
        first production family and must not be reduced back to melee /
        ranged / brute*."""
        assert len(C.ENEMY_ROLES) == 10
        assert APPROVED_FAMILY - set(C.ENEMY_ARCHETYPES) == {
            "charger", "bulwark", "scuttler", "artillery", "beacon",
            "diver", "drifter"}

    def test_asking_for_an_unknown_role_raises_rather_than_guessing(self):
        with pytest.raises(KeyError, match="no agreed physical envelope"):
            C.enemy_envelope("mimic")


class TestAnEnvelopeIsPhysicalOnly:
    """Giving a role a box is not giving it a fight."""

    def test_placeable_archetypes_are_a_subset_of_the_family(self):
        assert set(C.ENEMY_ARCHETYPES) <= set(C.ENEMY_ROLES)

    def test_every_placeable_archetype_has_both_a_box_and_behaviour(self):
        for archetype in C.ENEMY_ARCHETYPES:
            assert archetype in C.ENEMY_ENVELOPES
            assert archetype in C.ENEMY_STATS

    def test_a_role_with_an_envelope_and_no_stats_is_not_placeable(self):
        """The whole point of the separation. An art role becoming
        placeable is a combat decision, not a side effect of a model."""
        for role in C.ENEMY_ROLES:
            if role not in C.ENEMY_STATS:
                assert role not in C.ENEMY_ARCHETYPES, (
                    f"'{role}' can be placed in a Zone and has no stat "
                    "block; it would spawn with no behaviour")

    def test_the_content_value_table_scores_only_placeable_roles(self):
        from archipepsi_bridge import content_value as V
        assert set(V.ENEMY_VALUE) == set(C.ENEMY_ARCHETYPES)


class TestFloorAndFlyingAreExplicit:

    def test_the_two_flyers_are_the_two_flyers(self):
        assert set(C.FLYING_ENEMY_ROLES) == {"diver", "drifter"}
        assert set(C.GROUND_ENEMY_ROLES) | set(C.FLYING_ENEMY_ROLES) \
            == set(C.ENEMY_ROLES)
        assert not set(C.GROUND_ENEMY_ROLES) & set(C.FLYING_ENEMY_ROLES)

    def test_a_walker_sits_on_the_floor_and_a_flyer_holds_its_height(self):
        for role in C.GROUND_ENEMY_ROLES:
            envelope = C.enemy_envelope(role)
            assert envelope.hover_height == 0.0
            assert envelope.centre_y == pytest.approx(envelope.height / 2.0)
        for role in C.FLYING_ENEMY_ROLES:
            envelope = C.enemy_envelope(role)
            assert envelope.centre_y == envelope.hover_height
            assert envelope.centre_y > envelope.height / 2.0, (
                f"{role}'s centre is below its own half-height, so it is "
                "intersecting the floor rather than hovering")

    def test_a_hover_that_rests_on_the_floor_is_refused(self):
        """Including the exact boundary. A collider whose underside is at
        y=0 is standing, whatever the table calls it."""
        C.EnemyEnvelope(width=1.0, height=1.0, depth=1.0, hover_height=0.51)
        for resting in (0.5, 0.4):
            with pytest.raises(ValueError, match="resting on the floor"):
                C.EnemyEnvelope(width=1.0, height=1.0, depth=1.0,
                                hover_height=resting)

    def test_bottom_y_is_what_flying_means(self):
        for role in C.GROUND_ENEMY_ROLES:
            assert C.enemy_envelope(role).bottom_y == 0.0
        for role in C.FLYING_ENEMY_ROLES:
            assert C.enemy_envelope(role).bottom_y > 0.0

    def test_a_negative_hover_is_refused(self):
        with pytest.raises(ValueError, match="above the floor"):
            C.EnemyEnvelope(width=1.0, height=1.0, depth=1.0,
                            hover_height=-1.0)


class TestTheAxisOrderCannotBeSwapped:
    """The likeliest silent disagreement in the whole contract.

    Godot is Y-up and takes `Vector3(width, height, depth)`. The authoring
    tool is Z-up and writes `[width, depth, height]`. Same three numbers,
    different order, and a transposed height is a model that fits a
    doorway on one side of the seam and not the other.
    """

    def test_the_two_orders_are_derived_from_named_fields(self):
        envelope = C.EnemyEnvelope(width=1.0, height=2.0, depth=3.0)
        assert envelope.godot_size() == (1.0, 2.0, 3.0)
        assert envelope.authoring_size() == (1.0, 3.0, 2.0)

    @pytest.mark.parametrize("role,authoring", [
        # Exactly the `proposed_box_m` the art manifests declare, in the
        # order the manifests write them. A transposition here is the test
        # failing rather than a model being rebuilt.
        ("charger", (0.9, 1.9, 1.05)),
        ("bulwark", (1.45, 0.85, 2.05)),
        ("scuttler", (1.3, 1.2, 0.62)),
        ("artillery", (1.25, 1.25, 1.55)),
        ("beacon", (0.62, 0.62, 2.2)),
        ("diver", (0.7, 1.2, 0.5)),
        ("drifter", (1.35, 1.35, 0.95)),
    ])
    def test_the_contract_matches_the_declared_art_box(self, role, authoring):
        assert C.enemy_envelope(role).authoring_size() == authoring

    @pytest.mark.parametrize("role,hover", [("diver", 1.9), ("drifter", 2.55)])
    def test_the_proposed_hover_heights_are_honoured(self, role, hover):
        assert C.enemy_envelope(role).hover_height == hover


class TestTheEngineBuildsWhatTheContractSays:
    """Read out of the GDScript, so the two languages cannot drift."""

    def test_enemy_gd_reads_the_contract_rather_than_literals(self):
        source = ENEMY_GD.read_text()
        assert "Constants.ENEMY_ENVELOPES[kind]" in source
        for literal in ("Vector3(0.8, 1.6, 0.8)", "Vector3(0.7, 1.4, 0.7)",
                        "Vector3(1.8, 2.6, 1.8)"):
            assert literal not in source, (
                f"{literal} is back in enemy.gd; the collider is supposed "
                "to come from ENEMY_ENVELOPES")

    def test_the_collider_centre_is_taken_from_the_contract(self):
        source = ENEMY_GD.read_text()
        assert 'Vector3(0, float(envelope["centre_y"]), 0)' in source
        assert "shape.position = Vector3(0, size.y / 2.0, 0)" not in source, (
            "half-height is only correct for something standing on the "
            "floor; a flyer would be buried in it")

    @pytest.mark.parametrize("role", sorted(APPROVED_FAMILY))
    def test_the_exported_gdscript_carries_every_role(self, role):
        source = CONSTANTS_GD.read_text()
        envelope = C.enemy_envelope(role)
        expected = (
            f'"{role}": {{"size": Vector3{envelope.godot_size()}, '
            f'"centre_y": {envelope.centre_y!r}, '
            f'"bottom_y": {envelope.bottom_y!r}, '
            f'"top_y": {envelope.top_y!r}, '
            f'"lane_width": {envelope.lane_width!r}, '
            f'"hover_height": {envelope.hover_height!r}, '
            f'"flying": {"true" if envelope.is_flying else "false"}}}')
        assert expected in source, f"{role} is missing or stale in the export"


class TestEveryRoleFitsTheRoomsItWillStandIn:
    """A box nobody checked against a doorway is a box that wedges."""

    @pytest.mark.parametrize("role", sorted(APPROVED_FAMILY))
    def test_it_clears_the_door_and_the_corridor(self, role):
        envelope = C.enemy_envelope(role)
        door_height = _gd_const(BUILDERS_GD, "DOOR_HEIGHT")
        door_width = _gd_const(BUILDERS_GD, "DOOR_WIDTH")
        corridor = _gd_const(BUILDERS_GD, "CORRIDOR_HEIGHT")
        assert envelope.top_y <= door_height, (
            f"{role} is {envelope.top_y}m tall and a doorway is "
            f"{door_height}m")
        assert envelope.top_y <= corridor
        assert envelope.lane_width <= door_width, (
            f"{role} is {envelope.lane_width}m across a {door_width}m door")

    def test_no_role_is_wider_than_the_brute_lane_it_shares(self):
        lane = _gd_const(BUILDERS_GD, "BRUTE_LANE")
        for role in C.ENEMY_ROLES:
            assert C.enemy_envelope(role).lane_width <= lane

    def test_the_secret_ledge_clears_the_tallest_WALKER(self):
        """`SECRET_UNDERSIDE_MIN` exists so a slab is not a wall the brute
        walks into. Flyers are excluded on purpose: a flyer is steered and
        can descend, so a low soffit is a route it does not take."""
        assert C.TALLEST_GROUND_ACTOR == _gd_const(BUILDERS_GD,
                                                   "TALLEST_ACTOR")
        assert C.TALLEST_GROUND_ACTOR == C.enemy_envelope("brute").top_y

    def test_the_tallest_flyer_is_recorded_as_taller_and_kept_separate(self):
        """A real conflict, recorded rather than resolved by moving rooms.

        The drifter's crown is 3.025 m, above the 2.6 m every room was
        built around. Collapsing the two constants would move generated
        geometry for a role that has no behaviour yet, so they stay
        separate and the flyer ceiling question is explicit.
        """
        assert C.TALLEST_ACTOR_INCLUDING_FLYERS > C.TALLEST_GROUND_ACTOR
        assert C.TALLEST_ACTOR_INCLUDING_FLYERS == pytest.approx(3.025)
        assert C.TALLEST_ACTOR_INCLUDING_FLYERS <= _gd_const(
            BUILDERS_GD, "CORRIDOR_HEIGHT"), (
            "a flyer that cannot fit down a corridor cannot be placed at "
            "all; this is the bound that decides it")
