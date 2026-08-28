"""What Epsilon is allowed to name, and how it gets told (Tier 7).

The art lane has nineteen approved room shells. `zone.py` has carried
`shell_id` since D1, and `validate_zone` has refused one that was not
offered — but **nothing ever offered one**. `legal_shell_ids` was empty
everywhere in the live pipeline, so Epsilon was never told a shell
existed, and `content_instantiator.gd` mapped a chamber type straight to
its procedural id without reading what Epsilon had chosen.

Three gaps, one loop. These tests close it and keep it closed.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from archipepsi_bridge import shells
from archipepsi_bridge.schemas import constants as C
from archipepsi_bridge.schemas.content import ContentEntry

ROOT = Path(__file__).resolve().parents[2]
INSTANTIATOR_GD = (ROOT / "godot" / "scripts" / "content"
                   / "content_instantiator.gd")


def _entry(**over) -> ContentEntry:
    base = dict(id="shell_probe", level=3, category="room_shell",
                display_name="Probe", scene="res://content/probe.tscn",
                semantic_tags=("arena",),
                sockets=[{"name": "entry", "kind": "doorway",
                          "position": [0.0, 0.0, 0.0], "yaw": 180.0,
                          "width": 2.4, "height": 3.2},
                         {"name": "exit", "kind": "doorway",
                          "position": [0.0, 0.0, 16.0], "yaw": 0.0,
                          "width": 2.4, "height": 3.2}],
                size=[18.0, 6.0, 16.0])
    base.update(over)
    return ContentEntry.model_validate(base)


class TestOnlyShippableAuthoredShellsAreOffered:

    def test_a_pending_asset_is_never_offered(self):
        """A file existing in the tree is not approval, and offering a
        pending asset decides for whoever is still deciding."""
        assert shells.is_offerable(_entry(review="pass"))
        assert not shells.is_offerable(_entry(review="pending"))

    def test_a_procedural_entry_is_not_offered(self):
        """It is what the builder reaches by default. Naming it lets
        Epsilon 'choose' the thing it gets by choosing nothing."""
        procedural = dict(id="shell_probe_proc", level=3,
                          category="room_shell", display_name="Probe",
                          procedural_fallback=True,
                          semantic_tags=("arena",),
                          sockets=[{"name": "entry", "kind": "doorway",
                                    "position": [0.0, 0.0, 0.0],
                                    "yaw": 180.0, "width": 2.4,
                                    "height": 3.2},
                                   {"name": "exit", "kind": "doorway",
                                    "position": [0.0, 0.0, 16.0],
                                    "yaw": 0.0, "width": 2.4,
                                    "height": 3.2}],
                          size=[18.0, 6.0, 16.0])
        assert not shells.is_offerable(
            ContentEntry.model_validate(procedural))

    def test_only_room_shells_are_offered_as_shells(self):
        assert not shells.is_offerable(
            _entry(category="fixture", level=2, sockets=[], size=[1, 1, 1]))

    def test_the_committed_registry_offers_exactly_what_it_has(self):
        """Today: nothing, because every entry is procedural. That is the
        honest state, and this test says so rather than pretending."""
        registry = shells.load_registry()
        assert registry, "the registry did not load at all"
        offered = shells.shell_catalog(registry)
        procedural = [e for e in registry.values()
                      if e.category == "room_shell" and e.procedural_fallback]
        assert procedural, "the procedural shells vanished"
        assert offered == {}, (
            "the registry now carries authored shells; this test should "
            "start asserting they are offered rather than that none are")


class TestTheCatalogIsIdsAndNeverPaths:
    """Art requirement 1. An Epsilon that can name a resource path can
    name any file."""

    def test_no_scene_path_reaches_the_catalog(self):
        registry = {e.id: e for e in (
            _entry(id="shell_arena_hall", review="pass"),
            _entry(id="shell_arena_pit", review="pass",
                   scene="res://content/pit.tscn"))}
        catalog = shells.shell_catalog(registry)
        blob = json.dumps(catalog)
        assert "res://" not in blob
        assert ".tscn" not in blob
        assert catalog == {"arena": ["shell_arena_hall", "shell_arena_pit"]}

    def test_the_request_carries_ids_only(self):
        from .test_providers import zone_request
        blob = json.dumps(zone_request().catalog)
        assert "res://" not in blob and ".tscn" not in blob
        assert "room_shells" in zone_request().catalog


class TestTheOfferIsStableAndTyped:

    def test_shells_are_matched_by_semantic_tag(self):
        registry = {e.id: e for e in (
            _entry(id="shell_a", review="pass", semantic_tags=("arena",)),
            _entry(id="shell_b", review="pass",
                   semantic_tags=("corridor", "transit")))}
        assert shells.shells_for_type(registry, "arena") == ("shell_a",)
        assert shells.shells_for_type(registry, "corridor") == ("shell_b",)
        assert shells.shells_for_type(registry, "tower") == ()

    def test_the_same_registry_always_produces_the_same_offer(self):
        """A catalog that reshuffles makes two identical campaigns
        generate differently."""
        registry = {e.id: e for e in (
            _entry(id="shell_z", review="pass"),
            _entry(id="shell_a", review="pass"),
            _entry(id="shell_m", review="pass"))}
        first = shells.shell_catalog(registry)
        for _ in range(5):
            assert shells.shell_catalog(registry) == first
        assert first["arena"] == ["shell_a", "shell_m", "shell_z"]

    def test_a_type_with_no_shell_is_absent_rather_than_empty(self):
        registry = {e.id: e for e in (_entry(id="shell_a", review="pass"),)}
        catalog = shells.shell_catalog(registry)
        assert set(catalog) == {"arena"}
        for chamber_type in C.CHAMBER_TYPES:
            assert catalog.get(chamber_type) != []

    def test_every_catalog_key_is_a_real_chamber_type(self):
        registry = {e.id: e for e in (
            _entry(id="shell_a", review="pass",
                   semantic_tags=("arena", "brawl")),)}
        for chamber_type in shells.shell_catalog(registry):
            assert chamber_type in C.CHAMBER_TYPES


class TestTheLoopIsClosed:
    """Offered -> chosen -> validated -> instantiated. Each link tested,
    because the chain had three broken ones and every link's own test
    passed."""

    def test_the_acceptance_path_enforces_what_the_request_offered(self):
        from archipepsi_bridge.epsilon import base
        source = Path(base.__file__).read_text()
        assert "legal_shell_ids=" in source, (
            "generate_zone_validated does not pass legal_shell_ids; a "
            "Zone naming an unoffered shell would be accepted")
        assert 'request.catalog.get("room_shells"' in source, (
            "the bound is recomputed rather than taken from the request; "
            "what the provider was told is what it must be held to")

    def test_the_validator_still_refuses_an_unoffered_shell(self):
        from archipepsi_bridge.schemas.zone import Zone, validate_zone
        from pydantic import TypeAdapter
        zone = TypeAdapter(Zone).validate_python({
            "schema_version": 7, "zone_id": "zone_001",
            "display_name": "Relay", "target_game": "G",
            "theme": "void_glitch",
            "chambers": [
                {"id": "c1", "type": "corridor", "length": 12.0,
                 "width": 5.0},
                {"id": "c2", "type": "arena", "width": 18.0, "depth": 16.0,
                 "wall_height": 6.0, "objective": "kill_all",
                 "shell_id": "shell_not_offered",
                 "enemies": [{"archetype": "melee", "count": 2}],
                 "reward_location_id": 89100001}]})
        common = dict(expected_zone_id="zone_001",
                      allocated_location_ids=[89100001],
                      owned_echo_ids=[])
        assert validate_zone(zone, legal_shell_ids=(), **common)
        assert validate_zone(zone, legal_shell_ids=("shell_other",),
                             **common)
        assert validate_zone(zone, legal_shell_ids=("shell_not_offered",),
                             **common) == []

    def test_the_instantiator_reads_what_epsilon_chose(self):
        source = INSTANTIATOR_GD.read_text()
        assert 'chamber.get("shell_id", "")' in source, (
            "the instantiator ignores shell_id and maps the chamber type "
            "straight to its procedural shell; a Zone that named a shell "
            "would get the procedural one and no test would notice")
        assert "reg.has(chosen_by_epsilon)" in source
        # ...and an id the registry no longer carries is a downgrade, not
        # a crash: a saved Zone outlives a registry edit.
        assert "falling back" in source
