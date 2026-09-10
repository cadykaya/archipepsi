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
                # P1: an authored room shell says where its floor is.
                # These tests are about the OFFER, not about surfaces --
                # carrying one keeps them reaching the rule they are for.
                surfaces=[{"name": "floor", "center": [0.0, 0.0, 8.0],
                           "extent": [17.2, 15.2]}],
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
                          # P1: an authored room shell says where its floor is.
                # These tests are about the OFFER, not about surfaces --
                # carrying one keeps them reaching the rule they are for.
                surfaces=[{"name": "floor", "center": [0.0, 0.0, 8.0],
                           "extent": [17.2, 15.2]}],
                size=[18.0, 6.0, 16.0])
        assert not shells.is_offerable(
            ContentEntry.model_validate(procedural))

    def test_only_room_shells_are_offered_as_shells(self):
        assert not shells.is_offerable(
            _entry(category="fixture", level=2, sockets=[], size=[1, 1, 1]))

    def test_the_committed_registry_offers_exactly_what_it_has(self):
        """The owner passed the eight P2 shells, so they are offered.

        This test used to assert the catalog was EMPTY, and said in its
        own failure message that the day authored shells arrived it
        should start asserting they are offered rather than that none
        are. That day is 2026-09-02. What it asserts now is stricter
        than what it replaced: not merely that something is offered, but
        that the offered set is exactly the shippable authored shells --
        no procedural entry, no pending asset, nothing extra.
        """
        registry = shells.load_registry()
        assert registry, "the registry did not load at all"
        offered = shells.shell_catalog(registry)
        procedural = [e for e in registry.values()
                      if e.category == "room_shell" and e.procedural_fallback]
        assert procedural, "the procedural shells vanished"

        flat = {shell for ids in offered.values() for shell in ids}
        shippable = {
            e.id for e in registry.values()
            if e.category == "room_shell" and not e.procedural_fallback
            and shells.is_offerable(e)}
        assert flat == shippable, (
            "the catalog offers something other than exactly the "
            "shippable authored shells")
        assert flat, (
            "no authored shell is offered; if the pack went back to "
            "pending this should say so rather than pass empty")
        assert not any(e.procedural_fallback for e in registry.values()
                       if e.id in flat), (
            "a procedural entry is being offered; naming it lets Epsilon "
            "'choose' the thing it gets by choosing nothing")
        assert not any(registry[shell].review != "pass" for shell in flat), (
            "an unapproved asset is being offered, which decides for "
            "whoever is still deciding")


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


#: A syntactically valid Zone whose arena names a shell no request
#: offers. Used both against `validate_zone` directly and against the
#: whole acceptance path, so the two cannot disagree about it.
_UNOFFERED_ZONE = {
    "schema_version": 7, "zone_id": "zone_001",
    "display_name": "Relay", "target_game": "G", "theme": "void_glitch",
    "chambers": [
        {"id": "c1", "type": "corridor", "length": 12.0, "width": 5.0},
        {"id": "c2", "type": "arena", "width": 18.0, "depth": 16.0,
         "wall_height": 6.0, "objective": "kill_all",
         "shell_id": "shell_not_offered",
         "enemies": [{"archetype": "melee", "count": 2}],
         "reward_location_id": 89100001}]}


class TestTheLoopIsClosed:
    """Offered -> chosen -> validated -> instantiated. Each link tested,
    because the chain had three broken ones and every link's own test
    passed."""

    def test_the_acceptance_path_enforces_what_the_request_offered(self):
        """Run the acceptance path; do not read it.

        This asserted that the string `legal_shell_ids=` appeared in
        `base.py`. A grep passes on a call site that spells the argument
        out and fails on one that spreads it, which is a fact about
        punctuation -- and it says nothing about a call site that spells
        it out and passes the wrong value.

        So the pipeline is RUN. The payload is the fallback's OWN output
        for this request, with one chamber's `shell_id` overwritten, so
        the shell is the only thing wrong with it: a first draft used a
        hand-written two-room Zone that was also under budget and also
        missing a reward chamber, and it was refused with the shell rule
        deleted. A refusal that would have happened anyway is not
        evidence. The control run, byte-identical but for that one
        field, must be ACCEPTED.
        """
        import copy

        from archipepsi_bridge.epsilon.base import generate_zone_validated
        from archipepsi_bridge.epsilon.fallback import fallback_zone

        from .conftest import ScriptedProvider, run
        from .test_providers import zone_request

        request = zone_request()
        offered = request.catalog.get("room_shells", {})
        assert offered, (
            "the request offers no shells at all, so this test could "
            "not tell an enforced bound from an absent one")

        good = fallback_zone(request)
        target = next(
            (c for c in good["chambers"] if c.get("shell_id")), None)
        assert target is not None, (
            "the fallback named no authored shell, so there is no "
            "accepted choice to corrupt")
        bad = copy.deepcopy(good)
        for chamber in bad["chambers"]:
            if chamber["id"] == target["id"]:
                chamber["shell_id"] = "shell_not_offered"

        def run_once(payload):
            provider = ScriptedProvider(
                zone_outputs=[copy.deepcopy(payload),
                              copy.deepcopy(payload)])

            async def scenario():
                return await generate_zone_validated(
                    provider, request,
                    allocated_location_ids=[89100001, 89100002],
                    owned_echo_ids=[])
            return provider, run(scenario())

        control, accepted = run_once(good)
        assert control.zone_repairs == 0 and not accepted.used_fallback, (
            "the control Zone was rejected for some reason of its own, "
            "so a rejection of the corrupted one proves nothing")

        provider, outcome = run_once(bad)
        assert provider.zone_repairs == 1, (
            "the Zone naming an unoffered shell was accepted without "
            "even a repair round")
        assert outcome.used_fallback is True, (
            "a Zone naming 'shell_not_offered' reached the player")

    def test_the_validator_still_refuses_an_unoffered_shell(self):
        from archipepsi_bridge.schemas.zone import Zone, validate_zone
        from pydantic import TypeAdapter
        zone = TypeAdapter(Zone).validate_python(_UNOFFERED_ZONE)
        common = dict(expected_zone_id="zone_001",
                      allocated_location_ids=[89100001],
                      owned_echo_ids=[])
        assert validate_zone(zone, legal_shell_ids=(), **common)
        assert validate_zone(zone, legal_shell_ids=("shell_other",),
                             **common)
        assert validate_zone(zone, legal_shell_ids=("shell_not_offered",),
                             **common) == []

    def test_the_production_prompt_tells_epsilon_the_catalog_exists(self):
        """The request has carried `room_shells` since Wave 1 and the
        system prompt never mentioned it, so the one provider that could
        have made a creative choice was never told there was one to make.

        Every clause `shells.rule_errors` enforces has to be stated, or
        the provider guesses and pays a repair round for a fact the
        registry already knew.
        """
        from archipepsi_bridge.epsilon.claude import ZONE_SYSTEM
        for phrase in ("catalog.room_shells", "catalog.room_shell_rules",
                       "shell_id", "fits_floors", "provides_elevation",
                       "size", "types"):
            assert phrase in ZONE_SYSTEM, (
                f"the production Zone prompt never mentions '{phrase}', "
                f"so a provider cannot choose validly")
        assert "null" in ZONE_SYSTEM, (
            "the prompt does not say what to do when nothing fits, and "
            "a provider with no legal option invents one")

    def test_the_instantiator_reads_what_epsilon_chose(self):
        source = INSTANTIATOR_GD.read_text()
        assert 'chamber.get("shell_id")' in source, (
            "the instantiator ignores shell_id and maps the chamber type "
            "straight to its procedural shell; a Zone that named a shell "
            "would get the procedural one and no test would notice")
        # ...and an id the registry no longer carries is a downgrade, not
        # a crash: a saved Zone outlives a registry edit.
        assert "falling back" in source

    def test_godot_judges_a_shell_on_every_field_python_does(self):
        """The two definitions of "does this shell fit this room".

        `shells.rule_errors` decides what may be SELECTED and
        `ContentInstantiator._misfit` decides what may be BUILT. A clause
        in one and not the other is a Zone that validates in Python and
        silently falls back to a procedural room at runtime -- which is
        the substitution 3B exists to remove, and which is exactly what
        happened: Godot checked only `fits_floors`, so an arena shell
        named for a treasure room was refused by Python and built by
        Godot.

        A NAME IS NOT A CONTRACT. The version of this that asserted the
        string `reg.has(chosen_by_epsilon)` failed on a rename and would
        have passed on a call site that read the wrong variable. What is
        checked instead is that every registry FIELD the Python rule
        consults is consulted on the Godot side too -- so a clause added
        to one and forgotten in the other fails here.
        """
        rule = (Path(shells.__file__).read_text())
        gd = INSTANTIATOR_GD.read_text()
        consulted = [f for f in ("semantic_tags", "fits_floors",
                                 "provides_elevation", "size")
                     if f in rule]
        assert len(consulted) == 4, (
            "the Python rule stopped consulting one of the registry "
            f"fields this test knows about: {consulted}")
        for name in consulted:
            assert name in gd, (
                f"`shells.rule_errors` judges a shell on '{name}' and "
                f"`ContentInstantiator` never reads it, so Python would "
                f"refuse a selection Godot accepts (or the reverse)")
