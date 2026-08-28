"""The authored-content contract (v0.9 S12).

The registry is the alphabet `AUTHORED_CONTENT.md` says humans make. This
file holds it to three things:

1. **It describes reality.** The committed manifest validates, and every
   entry in it is either an authored scene or honestly marked as the
   procedural placeholder it currently is.
2. **It refuses what a consumer could not act on.** Unknown ids, a
   category at the wrong level, a room nothing can connect to, a fallback
   that does not exist, a chain that loops, a path escaping the content
   root.
3. **Both languages agree.** Godot is the physical authority and Python
   validates the shape; a rule enforced in one and not the other is a rule
   that fires on a developer's machine and not in the game, or the
   reverse. The GDScript is read and compared, the way
   `test_runner_coverage.py` pins the action catalog.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

import pytest
from pydantic import ValidationError

from archipepsi_bridge.schemas.content import (
    ContentEntry, ContentManifest, RegistryError, build_registry, resolve)

ROOT = Path(__file__).resolve().parents[2]
REGISTRY_DIR = ROOT / "godot" / "content" / "registry"
GDSCRIPT = ROOT / "godot" / "scripts" / "content" / "content_registry.gd"


def _manifests() -> list[ContentManifest]:
    return [ContentManifest.model_validate(json.loads(p.read_text()))
            for p in sorted(REGISTRY_DIR.glob("*.json"))]


def _entry(**over) -> dict:
    base = {
        "id": "shell_test", "level": 3, "category": "room_shell",
        "display_name": "Test", "procedural_fallback": True,
        "sockets": [
            {"name": "entry", "kind": "doorway",
             "position": [0.0, 0.0, 0.0], "width": 2.4, "height": 3.2},
        ],
    }
    base.update(over)
    return base


# --- 1: it describes reality ---------------------------------------------

def test_the_committed_registry_validates():
    registry = build_registry(_manifests())
    assert registry, "the registry is empty"


def test_every_entry_is_authored_or_honestly_marked():
    """The registry describes the game as it IS. Today that is entirely
    placeholders, and §6 of AUTHORED_CONTENT says so — an entry that
    claimed to be authored content when it is generated geometry would be
    the exact confusion that document exists to prevent."""
    for entry in build_registry(_manifests()).values():
        assert entry.procedural_fallback or entry.scene, (
            f"'{entry.id}' is neither an authored scene nor marked as the "
            f"placeholder it is")


def test_the_placeholders_cover_every_chamber_type_the_game_builds():
    """A registry that describes only some of the game is a registry a
    fallback chain can fall out of."""
    from archipepsi_bridge.schemas import constants as C

    registry = build_registry(_manifests())
    shells = {e.id for e in registry.values() if e.category == "room_shell"}
    for chamber in C.CHAMBER_TYPES:
        assert any(chamber in shell for shell in shells), (
            f"no room shell registered for chamber type '{chamber}'; "
            f"registered: {sorted(shells)}")


# --- 2: it refuses what a consumer could not act on -----------------------

def test_a_category_at_the_wrong_level_is_refused():
    with pytest.raises(ValidationError, match="that category is level"):
        ContentEntry.model_validate(_entry(level=1))


def test_a_room_nothing_can_connect_to_is_refused():
    with pytest.raises(ValidationError, match="nothing could ever connect"):
        ContentEntry.model_validate(_entry(sockets=[]))


def test_a_doorway_with_no_opening_is_refused():
    """Two openings cannot be checked for fit without dimensions, and the
    fit check is the whole point of a connector grammar."""
    with pytest.raises(ValidationError, match="must declare a width"):
        ContentEntry.model_validate(_entry(sockets=[
            {"name": "entry", "kind": "doorway",
             "position": [0.0, 0.0, 0.0]}]))


def test_an_entry_describing_nothing_is_refused():
    with pytest.raises(ValidationError, match="names no scene"):
        ContentEntry.model_validate(
            _entry(procedural_fallback=False, scene=""))


def test_a_scene_path_outside_the_content_root_is_refused():
    """The one field in the contract that can address the filesystem. It
    is Godot's and never a provider's, and it is still checked."""
    for bad in ("res://../secrets.tscn", "res://scripts/main.gd",
                "/etc/passwd", "res://content/../../x.tscn"):
        with pytest.raises(ValidationError):
            ContentEntry.model_validate(
                _entry(procedural_fallback=False, scene=bad))


def test_a_fallback_that_does_not_exist_is_refused():
    manifest = ContentManifest.model_validate({
        "pack": "test", "entries": [_entry(fallback="shell_nowhere")]})
    with pytest.raises(RegistryError, match="which no pack defines"):
        build_registry([manifest])


def test_a_fallback_chain_that_loops_is_refused():
    """A cycle turns "fall back to something that works" into a hang, at
    the exact moment something was already going wrong."""
    manifest = ContentManifest.model_validate({"pack": "test", "entries": [
        _entry(id="shell_a", fallback="shell_b"),
        _entry(id="shell_b", fallback="shell_a"),
    ]})
    with pytest.raises(RegistryError, match="fallback cycle"):
        build_registry([manifest])


def test_an_id_defined_twice_is_refused():
    a = ContentManifest.model_validate({"pack": "one", "entries": [_entry()]})
    b = ContentManifest.model_validate({"pack": "two", "entries": [_entry()]})
    with pytest.raises(RegistryError, match="defined in both"):
        build_registry([a, b])


def test_a_variant_of_a_different_category_is_refused():
    manifest = ContentManifest.model_validate({"pack": "test", "entries": [
        _entry(id="shell_a", variants=["prop_b"]),
        _entry(id="prop_b", level=0, category="prop", sockets=[]),
    ]})
    with pytest.raises(RegistryError, match="a variant is the same THING"):
        build_registry([manifest])


# --- the S13 selection rule ----------------------------------------------

def test_resolution_prefers_authored_and_falls_back_when_it_cannot():
    manifest = ContentManifest.model_validate({"pack": "test", "entries": [
        _entry(id="shell_authored", procedural_fallback=False,
               scene="res://content/shells/x.tscn", fallback="shell_proc"),
        _entry(id="shell_proc"),
    ]})
    registry = build_registry([manifest])

    everything = resolve(registry, "shell_authored", lambda e: True)
    assert everything.id == "shell_authored", "authored must win when present"

    only_procedural = resolve(registry, "shell_authored",
                              lambda e: e.procedural_fallback)
    assert only_procedural.id == "shell_proc", (
        "an unavailable authored scene must degrade to the placeholder, "
        "not fail")


def test_resolution_of_an_unknown_id_is_an_error_not_a_guess():
    registry = build_registry([ContentManifest.model_validate(
        {"pack": "test", "entries": [_entry()]})])
    with pytest.raises(RegistryError, match="unknown content id"):
        resolve(registry, "shell_nope", lambda e: True)


def test_resolution_says_so_when_nothing_in_the_chain_works():
    registry = build_registry([ContentManifest.model_validate(
        {"pack": "test", "entries": [_entry()]})])
    with pytest.raises(RegistryError, match="ends without anything"):
        resolve(registry, "shell_test", lambda e: False)


# --- 3: both languages agree ---------------------------------------------

def _gdscript_dict(name: str) -> dict[str, list[int]]:
    text = GDSCRIPT.read_text()
    block = re.search(rf"const {name} := \{{(.*?)^\}}", text,
                      re.S | re.M)
    assert block, f"{name} not found in {GDSCRIPT.name}"
    out: dict[str, list[int]] = {}
    for key, values in re.findall(r'"([a-z_]+)":\s*\[([0-9,\s]*)\]',
                                  block.group(1)):
        out[key] = [int(v) for v in values.replace(" ", "").split(",") if v]
    return out


def test_the_two_validators_allow_the_same_levels_per_category():
    """Python validates the manifest's shape and Godot is the physical
    authority. A level rule enforced in one and not the other fires on a
    developer's machine and not in the game, or the reverse."""
    from archipepsi_bridge.schemas.content import _LEVELS

    gd = _gdscript_dict("LEVELS")
    py = {k: sorted(v) for k, v in _LEVELS.items()}
    assert {k: sorted(v) for k, v in gd.items()} == py, (
        "the level rules have drifted between content.py and "
        "content_registry.gd")


def test_the_two_validators_agree_on_which_categories_need_sockets():
    from archipepsi_bridge.schemas.content import _NEEDS_SOCKETS

    text = GDSCRIPT.read_text()
    block = re.search(r'const NEEDS_SOCKETS := \[(.*?)\]', text, re.S)
    assert block, "NEEDS_SOCKETS not found in the GDScript"
    gd = sorted(re.findall(r'"([a-z_]+)"', block.group(1)))
    assert gd == sorted(_NEEDS_SOCKETS), (
        "content.py and content_registry.gd disagree about which "
        "categories must be connectable")


def test_epsilon_has_no_way_to_name_a_scene():
    """The rule the whole contract rests on. `scene` exists for Godot;
    there must be no path-shaped field on anything a provider emits."""
    from archipepsi_bridge.epsilon import requests as R

    for name in dir(R):
        model = getattr(R, name)
        for field in getattr(model, "model_fields", {}):
            assert "scene" not in field.lower(), f"{name}.{field}"
            assert "path" not in field.lower(), f"{name}.{field}"
            assert "res://" not in field, f"{name}.{field}"


# --- 4: the contributor guide describes the game that exists --------------

SPEC = ROOT / "docs" / "ART_ASSET_SPEC.md"


def _spec_table() -> dict[str, str]:
    """Every `| `CONST` | value |` row in the spec's dimension tables."""
    return {m[1]: m[2].strip() for m in re.finditer(
        r"^\|\s*`([A-Z_]+)`\s*\|\s*([^|]+?)\s*\|", SPEC.read_text(), re.M)}


def test_the_art_spec_quotes_the_real_player_metrics():
    """An artist builds to the numbers in the guide. A guide that has
    drifted from the constants sends them to model a doorway the player
    cannot fit through, and they find out in Blender, days later."""
    from archipepsi_bridge.schemas import constants as C

    quoted = _spec_table()
    for name in ("PLAYER_HEIGHT", "PLAYER_RADIUS", "PLAYER_EYE_HEIGHT",
                 "WALK_SPEED", "SAFE_BASE_JUMP_GAP"):
        assert name in quoted, f"the art spec no longer quotes {name}"
        stated = float(re.search(r"[\d.]+", quoted[name]).group())
        assert stated == pytest.approx(getattr(C, name)), (
            f"ART_ASSET_SPEC says {name} is {stated}, the game says "
            f"{getattr(C, name)}")

    # The two the spec rounds deliberately ("~1.33 m") are still pinned,
    # just loosely: an artist needs the magnitude, not the repeating
    # decimal.
    for name in ("JUMP_APEX_HEIGHT", "JUMP_FLAT_REACH"):
        stated = float(re.search(r"[\d.]+", quoted[name]).group())
        assert stated == pytest.approx(getattr(C, name), abs=0.01), (
            f"ART_ASSET_SPEC says {name} is ~{stated}, the game says "
            f"{getattr(C, name)}")


def test_the_art_spec_quotes_the_real_architectural_dimensions():
    """These live in GDScript, so they are read the way the action catalog
    is: from the source, both ways."""
    builders = (ROOT / "godot" / "scripts" / "generation"
                / "chamber_builders.gd").read_text()
    zone = (ROOT / "godot" / "scripts" / "generation"
            / "zone_builder.gd").read_text()
    source = builders + zone

    quoted = _spec_table()
    for name in ("DOOR_WIDTH", "DOOR_HEIGHT", "CORRIDOR_HEIGHT",
                 "WALL_THICKNESS", "CONNECTOR_LENGTH", "CONNECTOR_WIDTH"):
        found = re.search(rf"^const {name} := ([\d.]+)", source, re.M)
        assert found, f"{name} is no longer a const in the generation code"
        stated = float(re.search(r"[\d.]+", quoted[name]).group())
        assert stated == pytest.approx(float(found.group(1))), (
            f"ART_ASSET_SPEC says {name} is {stated}, the code says "
            f"{found.group(1)}")


def test_the_art_spec_names_every_category_the_registry_accepts():
    """A category with no documented prefix is a category an artist has to
    guess an id for, and a guessed id is a permanent one."""
    from archipepsi_bridge.schemas.content import _LEVELS

    text = SPEC.read_text()
    for category in _LEVELS:
        assert f"`{category}`" in text, (
            f"the registry accepts category '{category}' and the art spec "
            f"never mentions it")


# --- 5: the S15 connector grammar ----------------------------------------

GRAMMAR = ROOT / "godot" / "scripts" / "content" / "connector_grammar.gd"


def test_an_opening_the_player_cannot_fit_through_is_refused():
    """The grammar's half of I4. An opening narrower than the player is
    not a tight corridor, it is a wall the generator believes is a door:
    the seed passes every other check and then cannot be finished, in a
    zone the player is already standing in."""
    from archipepsi_bridge.schemas.content import (
        MIN_PASSABLE_HEIGHT, MIN_PASSABLE_WIDTH)

    with pytest.raises(ValidationError, match="to walk through"):
        ContentEntry.model_validate(_entry(sockets=[
            {"name": "entry", "kind": "doorway", "position": [0.0, 0.0, 0.0],
             "width": MIN_PASSABLE_WIDTH - 0.01, "height": 3.2}]))

    with pytest.raises(ValidationError, match="headroom"):
        ContentEntry.model_validate(_entry(sockets=[
            {"name": "entry", "kind": "doorway", "position": [0.0, 0.0, 0.0],
             "width": 2.4, "height": MIN_PASSABLE_HEIGHT - 0.01}]))


def test_the_passable_minimum_is_the_real_player_and_not_a_typed_number():
    """If these were literals they would survive a change to the player's
    capsule, and the first thing anyone would notice is a doorway that
    used to work."""
    from archipepsi_bridge.schemas import constants as C
    from archipepsi_bridge.schemas.content import (
        HEAD_CLEARANCE, MIN_PASSABLE_HEIGHT, MIN_PASSABLE_WIDTH,
        SIDE_CLEARANCE)

    assert MIN_PASSABLE_WIDTH == pytest.approx(
        C.PLAYER_RADIUS * 2.0 + SIDE_CLEARANCE)
    assert MIN_PASSABLE_HEIGHT == pytest.approx(
        C.PLAYER_HEIGHT + HEAD_CLEARANCE)
    # And the real doorways the game builds must clear them, or every
    # chamber the generator makes is refused by its own contract.
    builders = (ROOT / "godot" / "scripts" / "generation"
                / "chamber_builders.gd").read_text()
    door_w = float(re.search(r"const DOOR_WIDTH := ([\d.]+)", builders)[1])
    door_h = float(re.search(r"const DOOR_HEIGHT := ([\d.]+)", builders)[1])
    assert door_w >= MIN_PASSABLE_WIDTH
    assert door_h >= MIN_PASSABLE_HEIGHT


def test_both_grammars_agree_on_what_joins_and_on_the_clearances():
    """`test_runner_coverage.py`'s trick: read the GDScript and compare.
    A rule enforced in one language and not the other fires on a
    developer's machine and not in the game, or the reverse -- and this
    particular rule is the one standing between a seed and I4."""
    from archipepsi_bridge.schemas.content import (
        HEAD_CLEARANCE, JOINING_KINDS, SIDE_CLEARANCE)

    gd = GRAMMAR.read_text()

    joinable = set(re.findall(r'^\t"(\w+)": \[', gd, re.M))
    assert joinable == set(JOINING_KINDS), (
        f"GDScript joins {sorted(joinable)}, Python joins "
        f"{sorted(JOINING_KINDS)}")

    for name, value in (("SIDE_CLEARANCE", SIDE_CLEARANCE),
                        ("HEAD_CLEARANCE", HEAD_CLEARANCE)):
        found = re.search(rf"^const {name} := ([\d.]+)", gd, re.M)
        assert found, f"{name} is no longer a const in the grammar"
        assert float(found[1]) == pytest.approx(value), (
            f"GDScript {name} is {found[1]}, Python's is {value}")

    # Both must derive the minimum from the capsule rather than restate
    # it, which is the only reason the two stay equal under a change.
    assert "Constants.PLAYER_RADIUS * 2.0 + SIDE_CLEARANCE" in gd
    assert "Constants.PLAYER_HEIGHT + HEAD_CLEARANCE" in gd
