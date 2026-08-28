"""The authored-content boundary, asserted rather than only written down.

`AUTHORED_CONTENT.md` is normative: humans make the alphabet, Godot
enforces the grammar, Epsilon writes sentences. A document alone cannot
stop the boundary eroding, and the way it would erode is specific —
someone adds a field to the Zone or Echo schema that lets a provider
describe geometry, a material, a mesh or a colour, and every validator
keeps passing because the schema now permits it.

So this checks the shape of what a provider is ALLOWED to say. It is
deliberately a vocabulary test rather than a behaviour test: behaviour
tests would pass right up until the day the vocabulary changed.
"""

from __future__ import annotations

from pathlib import Path

from archipepsi_bridge.schemas import echo as E
from archipepsi_bridge.schemas import zone as Z

PACKET = (Path(__file__).resolve().parents[2]
          / "docs" / "design-packet-v0.8")

#: Words that would mean a provider is describing an ASSET rather than
#: selecting one. `palette_color` and `theme` are the deliberate
#: exceptions and are named below.
_ASSET_WORDS = (
    "mesh", "model", "geometry", "vertex", "vertices", "polygon",
    "texture", "material", "shader", "sprite", "animation", "rig",
    "audio_file", "sound_file", "font", "asset_path", "file_path",
    "rgb", "hex_color", "hex_colour",
)

#: Selection, not authorship. A theme and a palette colour are choices
#: from a closed authored set — both are `Literal`s, which is what makes
#: them selection; the test below proves that rather than trusting it.
_SELECTORS = {"theme", "palette_color"}


def _fields_of(model) -> list[str]:
    return list(getattr(model, "model_fields", {}))


def _all_models(module):
    for name in dir(module):
        candidate = getattr(module, name)
        if hasattr(candidate, "model_fields"):
            yield name, candidate


def test_no_provider_field_lets_epsilon_describe_an_asset():
    """§2: materials, VFX, audio, props and meshes are authored. A schema
    field naming any of them would make Epsilon an asset generator without
    anyone deciding to."""
    offenders = []
    for module in (E, Z):
        for name, model in _all_models(module):
            for field in _fields_of(model):
                if field in _SELECTORS:
                    continue
                for word in _ASSET_WORDS:
                    if word in field.lower():
                        offenders.append(f"{name}.{field}")
    assert offenders == [], (
        f"these fields let a provider describe an asset rather than "
        f"select one: {offenders}. See AUTHORED_CONTENT.md §2 — if this "
        f"is deliberate, the document has to change first")


def test_the_selectors_really_are_closed_sets():
    """A selector is only selection while its values are a fixed list. The
    moment `theme` or `palette_color` becomes a free string, Epsilon is
    authoring a look rather than choosing one."""
    for kind, values in (("theme", Z.Zone.model_fields["theme"]),
                         ("palette_color",
                          E.ResourceComponent.model_fields["palette_color"])):
        annotation = values.annotation
        args = getattr(annotation, "__args__", ())
        assert args and all(isinstance(a, str) for a in args), (
            f"{kind} is no longer a closed Literal; a provider can now "
            f"author a value instead of choosing one")


def test_the_boundary_document_is_in_the_packet_and_authoritative():
    """It is normative, so it has to be findable and it has to say so."""
    doc = PACKET / "AUTHORED_CONTENT.md"
    assert doc.exists(), "AUTHORED_CONTENT.md is missing from the packet"
    text = doc.read_text(encoding="utf-8")
    assert "**Status: authoritative.**" in text
    assert "HUMANS MAKE THE ALPHABET" in text
    readme = (PACKET / "README.md").read_text(encoding="utf-8")
    assert "AUTHORED_CONTENT.md" in readme, (
        "the packet's README does not point at the boundary document, so "
        "nobody reading in order will find it")


def test_the_placeholder_debt_names_files_that_exist():
    """§6 lists the procedural placeholders as debt. A debt list that
    names a file which has been renamed or removed is worse than none:
    the next person reads it, finds nothing, and assumes the debt is
    paid."""
    root = PACKET.parents[1]
    text = (PACKET / "AUTHORED_CONTENT.md").read_text(encoding="utf-8")
    debt = text.split("The specific conflicts")[1]
    named = {token.strip("`")
             for token in debt.replace("|", " ").split()
             if token.startswith("`") and token.endswith(".gd`")}
    assert named, "the debt table names no files"
    missing = [n for n in sorted(named)
               if not (root / "godot" / "scripts" / n).exists()]
    assert missing == [], (
        f"the placeholder-debt table names files that do not exist: "
        f"{missing}")
