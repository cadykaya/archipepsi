"""What Epsilon is allowed to say (v0.9 S19).

`AUTHORED_CONTENT.md`: **Epsilon is a composer, never an asset
generator.** It may not generate textures, audio, shaders or particle
programs, place arbitrary lights, or supply resource paths.

Enforcing that by review does not survive contact with a schema that
grows. This file enforces it structurally: it walks every field of every
model Epsilon authors and requires each string-typed one to be either a
CLOSED VOCABULARY (a `Literal`, an `Enum`, or a constrained pattern) or
an explicitly allowlisted piece of free prose.

The allowlist is the point. A new free-text field added to Epsilon's
output fails this test until someone consciously adds it and says what
it is for -- which is exactly the moment to notice that the field is a
filesystem path.
"""

from __future__ import annotations

import enum
import re
import typing

import pytest
from pydantic import BaseModel

from archipepsi_bridge.schemas.echo import EchoInterpretation
from archipepsi_bridge.schemas.zone import Zone

#: The two roots a provider fills in. Everything Epsilon can say reaches
#: the game through one of them.
EPSILON_ROOTS = (EchoInterpretation, Zone)

#: Free-text fields, each with the reason it is allowed to be free.
#:
#: Every one of these is PROSE SHOWN TO A PLAYER. None is ever resolved
#: as a path, a resource, a shader, or a node name, and each is length
#: clamped by the model. Adding to this list means asserting the same of
#: a new field.
ALLOWED_FREE_TEXT = {
    # Prose shown to a player. Length-clamped by the model, never
    # resolved as a path, a resource, a shader or a node name.
    "display_name": "the Echo's name in the archive",
    "description": "flavour text under the name",
    "flavor": "a chamber's one-line mood",
    "note": "an affordance's hint line",
    "designer_note": "a Zone's stated intent, shown on load",

    # Archipelago's own strings, echoed back rather than invented. These
    # CANNOT be charset-constrained: real game names contain colons,
    # apostrophes and periods ("Super Mario World 2: Yoshi's Island"),
    # so a pattern strict enough to exclude a path would reject half the
    # multiworld. They are safe for a different reason -- they are
    # compared against what the bridge already knows, and displayed, not
    # resolved.
    "source_game": "the AP game the item came from",
    "source_item_name": "the AP item's own name, echoed back",
    "source_recipient_name": "the AP player it was destined for",
    "target_game": "the AP game a Zone is themed after",
}

#: Words that betray a field which resolves to a file or a program. Any
#: of these as a WORD in a field name is refused outright -- the whole
#: category is outside what a composer may say.
#:
#: Matched per underscore-separated segment, not as substrings: the first
#: version matched "script" inside "description" and refused five honest
#: prose fields.
FORBIDDEN_NAME_WORDS = frozenset({
    "path", "paths", "file", "files", "uri", "url",
    "shader", "shaders", "texture", "textures", "scene", "scenes",
    "asset", "assets", "particle", "particles", "stream", "script",
    "scripts", "program",
})
#: "resource" is deliberately NOT here. In this codebase a resource is a
#: gameplay meter -- ammo, momentum, battery -- and `ResourceCost.
#: resource_id` names one. Godot also calls a file on disk a Resource,
#: which is why the word looked dangerous; refusing it would have
#: flagged an honest field forever.


def _string_fields(model: type[BaseModel], seen: set | None = None,
                   prefix: str = "") -> list[tuple[str, str, object, type]]:
    """Every string-typed field reachable from `model`.

    Returns (path, field_name, annotation, owning_model). Recurses through nested
    models, tuples, unions and optionals, because a free string three
    levels down is exactly as free as one at the top.
    """
    seen = seen if seen is not None else set()
    if model in seen:
        return []
    seen.add(model)

    out: list[tuple[str, str, object, type]] = []
    for name, field in model.model_fields.items():
        here = f"{prefix}{model.__name__}.{name}"
        for annotation in _unwrap(field.annotation):
            if annotation is str:
                out.append((here, name, field.annotation, model))
            elif (isinstance(annotation, type)
                  and issubclass(annotation, BaseModel)):
                out += _string_fields(annotation, seen, prefix)
    return out


def _unwrap(annotation) -> list:
    """Flatten Optional/Union/tuple/list annotations to their leaves."""
    origin = typing.get_origin(annotation)
    if origin is None:
        return [annotation]
    out = []
    for arg in typing.get_args(annotation):
        if arg is type(None) or arg is Ellipsis:
            continue
        out += _unwrap(arg)
    return out


#: Characters that turn a string into a path, a URI or a resource
#: reference. A field whose pattern cannot admit any of them cannot name
#: a file, whatever else it says.
PATH_CHARACTERS = ":/\\."


def _is_path_proof(model: type[BaseModel], name: str) -> bool:
    """Whether the field's own pattern makes a path unspellable.

    The third safe shape, and the one most of Epsilon's strings actually
    are: not a closed vocabulary, but a charset that has no ':' in it.
    Checked by TESTING the pattern against real path fragments rather
    than by reading it, so a clever-looking regex cannot pass by being
    hard to read.
    """
    field = model.model_fields.get(name)
    if field is None:
        return False
    patterns = [m.pattern for m in field.metadata if hasattr(m, "pattern")]
    for annotation in typing.get_args(field.annotation) or ():
        for meta in getattr(annotation, "__metadata__", ()):  # Annotated
            patterns += [
                m.pattern for m in getattr(meta, "metadata", [])
                if hasattr(m, "pattern")]
            if hasattr(meta, "pattern") and meta.pattern:
                patterns.append(meta.pattern)
    if not patterns:
        return False
    probes = ["res://a.tscn", "../x", "/etc/passwd", "a.b", "C:\\x"]
    return all(
        not re.fullmatch(pattern, probe)
        for pattern in patterns for probe in probes)


def _is_closed(annotation) -> bool:
    """A closed vocabulary: a Literal, or an Enum of strings."""
    for part in _unwrap_preserving_literals(annotation):
        if typing.get_origin(part) is typing.Literal:
            return True
        if isinstance(part, type) and issubclass(part, enum.Enum):
            return True
    return False


def _unwrap_preserving_literals(annotation) -> list:
    origin = typing.get_origin(annotation)
    if origin is None or origin is typing.Literal:
        return [annotation]
    out = []
    for arg in typing.get_args(annotation):
        if arg is type(None) or arg is Ellipsis:
            continue
        out += _unwrap_preserving_literals(arg)
    return out


def test_every_string_epsilon_can_say_is_closed_or_named_prose():
    """The S19 rule, structurally.

    A string field is fine if it is a closed vocabulary, and fine if it
    is prose someone has vouched for. Anything else is a field a
    provider can fill with whatever it likes, and the whole point of
    `AUTHORED_CONTENT.md` is that some things it might like are assets.
    """
    unaccounted = []
    for root in EPSILON_ROOTS:
        for path, name, annotation, owner in _string_fields(root):
            if (_is_closed(annotation) or _is_path_proof(owner, name)
                    or name in ALLOWED_FREE_TEXT):
                continue
            unaccounted.append(path)

    assert not unaccounted, (
        "these fields let Epsilon say an arbitrary string, and are "
        "neither a closed vocabulary nor allowlisted prose:\n  "
        + "\n  ".join(sorted(unaccounted))
        + "\n\nIf the field is prose shown to a player, add it to "
          "ALLOWED_FREE_TEXT with its reason. If it is anything that "
          "resolves to a file, a shader or a node, it does not belong "
          "in Epsilon's output at all.")


def test_no_field_epsilon_can_fill_is_named_like_a_path():
    """A field called `scene_path` would pass the test above the moment
    someone added it to the allowlist by reflex. This one cannot be
    satisfied that way: the whole CATEGORY is outside what a composer
    may say, so the name itself is refused."""
    offenders = []
    for root in EPSILON_ROOTS:
        for path, name, _, _owner in _string_fields(root):
            for word in name.lower().split("_"):
                if word in FORBIDDEN_NAME_WORDS:
                    offenders.append(f"{path} (the word '{word}')")
    assert not offenders, (
        "Epsilon must never supply a path, resource, shader or program:\n  "
        + "\n  ".join(sorted(offenders)))


def test_the_palette_is_a_closed_vocabulary_and_stays_one():
    """The one presentation vocabulary Epsilon already has. It is the
    shape every future one should copy: named roles, not values -- so a
    theme decides what `ember` looks like and Epsilon only decides that
    a resource feels like `ember`."""
    from archipepsi_bridge.schemas.echo import ResourceComponent

    annotation = ResourceComponent.model_fields["palette_color"].annotation
    assert typing.get_origin(annotation) is typing.Literal, (
        "palette_color stopped being a closed vocabulary; Epsilon can now "
        "name a colour the themes have never heard of")

    names = typing.get_args(annotation)
    assert len(names) >= 4, "the palette collapsed to almost nothing"
    for name in names:
        assert re.fullmatch(r"[a-z]+", name), (
            f"palette entry '{name}' is not a plain role name; a value "
            f"(a hex code, an rgb tuple) would let Epsilon pick the "
            f"colour instead of naming the feeling")


def test_the_allowlist_does_not_rot():
    """An allowlist that names fields which no longer exist is an
    allowlist nobody has read in a while, and the next person to add a
    field to it will trust it."""
    live = set()
    for root in EPSILON_ROOTS:
        for _, name, _, _owner in _string_fields(root):
            live.add(name)
    stale = sorted(set(ALLOWED_FREE_TEXT) - live)
    assert not stale, (
        f"ALLOWED_FREE_TEXT names fields that no longer exist: {stale}")


# --- S21: a preference is not campaign truth ------------------------------

def test_no_player_preference_is_part_of_campaign_truth():
    """A player's mouse sensitivity is not a fact about their multiworld.

    In the save it would make two players' saves differ for a reason no
    rule cares about, and would turn changing a preference into a state
    transition -- something the fold would then have to have an opinion
    about. Preferences live in `user://settings.cfg`; this asserts they
    stay out of everything the bridge persists or sends.

    Read from the GDScript so the two cannot drift: adding a preference
    there and a field of the same name here is exactly the mistake.
    """
    import pathlib
    import re as _re

    from archipepsi_bridge.schemas.protocol import (
        CampaignSave, CampaignSnapshot)

    settings = (pathlib.Path(__file__).resolve().parents[2] / "godot"
                / "scripts" / "autoload" / "player_settings.gd").read_text()

    # The RANGES and FLAGS blocks name every preference there is.
    names = set()
    for block in ("RANGES", "FLAGS"):
        body = settings.split(f"const {block} := {{", 1)[1].split("}", 1)[0]
        names |= set(_re.findall(r'^\t"(\w+)":', body, _re.M))
    names.add("bindings")
    assert len(names) >= 5, f"found only {names}; the parse has gone stale"

    for model in (CampaignSnapshot, CampaignSave):
        overlap = names & set(model.model_fields)
        assert not overlap, (
            f"{model.__name__} carries player preferences {sorted(overlap)}; "
            f"preferences belong in user://settings.cfg, never in campaign "
            f"truth")
