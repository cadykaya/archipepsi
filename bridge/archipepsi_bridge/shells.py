"""Which room shells Epsilon is allowed to name (art requirement, Tier 7).

The art lane has nineteen approved room shells. `zone.py` has carried
`shell_id`, `size_class` and `intent` since D1, and `validate_zone` has
refused a `shell_id` that was not offered — but **nothing ever offered
one**. `legal_shell_ids` defaulted to empty everywhere in the live
pipeline, so Epsilon was never told a shell existed, and the
instantiator mapped a chamber type straight to its procedural id without
ever reading what Epsilon chose.

This closes that loop. It reads the same registry manifests Godot reads,
and answers one question: for this chamber type, which shell IDS may
Epsilon name?

**IDs, never paths.** An Epsilon that can name a resource path can name
any file (`AUTHORED_CONTENT.md`, and art requirement 1). What crosses to
the provider is a short id from a closed list; Godot resolves it. The
`ContentEntry` model this loads carries a `scene` field, and nothing
here returns it.
"""

from __future__ import annotations

import json
import logging
from pathlib import Path

from .schemas.content import ContentEntry, ContentManifest, build_registry

log = logging.getLogger("archipepsi.shells")

_REPO_ROOT = Path(__file__).resolve().parents[2]
REGISTRY_DIR = _REPO_ROOT / "godot" / "content" / "registry"

#: The chamber types a shell can be offered for. Read from the schema
#: rather than retyped -- a chamber type added to the vocabulary reaches
#: this without anybody remembering to list it.
from .schemas import constants as C  # noqa: E402

CHAMBER_TYPES = tuple(C.CHAMBER_TYPES)


def load_registry(directory: Path | None = None) -> dict[str, ContentEntry]:
    """Every registry entry, validated. Empty on any problem.

    Never raises into generation: a registry that will not load means the
    procedural builders, which is the state the game shipped in for
    months. A Zone that fails to generate because a manifest has a typo
    would be a worse trade than a Zone with no authored shells in it.
    """
    root = directory or REGISTRY_DIR
    try:
        manifests = [ContentManifest.model_validate(json.loads(p.read_text()))
                     for p in sorted(root.glob("*.json"))]
        return build_registry(manifests)
    except Exception as exc:                      # noqa: BLE001
        log.warning("could not load the content registry (%s); Epsilon "
                    "will be offered no authored shells", exc)
        return {}


def is_offerable(entry: ContentEntry) -> bool:
    """Whether this entry may be put in front of Epsilon at all.

    Three gates, and the middle one is the art lane's:

    * it is a room shell;
    * it is not `review: pending` -- a file existing in the tree is not
      approval, and offering a pending asset decides for whoever is
      still deciding;
    * it is authored. A procedural entry is the fallback the builder
      reaches anyway, so naming it explicitly buys nothing and would let
      Epsilon "choose" the thing it gets by choosing nothing.
    """
    if entry.category != "room_shell":
        return False
    if entry.review == "pending":
        return False
    return not entry.procedural_fallback


def shells_for_type(registry: dict[str, ContentEntry],
                    chamber_type: str) -> tuple[str, ...]:
    """Offerable shell ids for one chamber type, in a stable order.

    Matched on `semantic_tags`, which is how a shell says what it is.
    Sorted rather than left in manifest order so the same registry
    always produces the same offer -- a catalog that reshuffles makes
    two identical campaigns generate differently.
    """
    return tuple(sorted(
        entry.id for entry in registry.values()
        if is_offerable(entry) and chamber_type in entry.semantic_tags))


def shell_catalog(registry: dict[str, ContentEntry] | None = None,
                  ) -> dict[str, list[str]]:
    """`chamber_type -> [shell_id]`, for every type with an offer.

    A type with no authored shell is ABSENT rather than present-and-empty:
    the catalog is what Epsilon reads, and an empty list invites it to
    wonder what it did wrong.
    """
    reg = registry if registry is not None else load_registry()
    out: dict[str, list[str]] = {}
    for chamber_type in CHAMBER_TYPES:
        offered = shells_for_type(reg, chamber_type)
        if offered:
            out[chamber_type] = list(offered)
    return out


def all_legal_shell_ids(catalog: dict[str, list[str]] | None = None,
                        ) -> tuple[str, ...]:
    """Every id in the catalog, flattened, for `validate_zone`.

    The validator asks "was this offered", not "was this offered for
    this chamber type" -- a shell tagged for two types is legal in both,
    and the type-appropriateness of a choice is a composition question
    rather than a validity one.
    """
    entries = catalog if catalog is not None else shell_catalog()
    return tuple(sorted({i for ids in entries.values() for i in ids}))
