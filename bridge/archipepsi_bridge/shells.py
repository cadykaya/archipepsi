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

#: How thick a room's wall is. GDScript OWNS this number
#: (`ChamberBuilders.WALL_THICKNESS`); this is the Python mirror, and
#: `test_content_registry` asserts the two still agree. It lives here
#: rather than in `constants.py` because that module is the SOURCE the
#: GDScript constants are generated from -- putting it there would emit a
#: second definition of a number GDScript already declares.
WALL_THICKNESS = 0.4


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

def field(chamber, name: str):
    """One chamber field, whether it is still a dict or already a model.

    The fallback decides shells while its chambers are dictionaries; the
    validator decides after they are `Chamber` models. Both ask the same
    question of the same rule, so the rule reads them the same way rather
    than existing twice with a subtly different accessor each time.
    """
    if isinstance(chamber, dict):
        return chamber.get(name)
    return getattr(chamber, name, None)


def rule_of(entry: ContentEntry) -> dict:
    """The constraint row for one shell: what it is, and what it fits.

    This is the wire form -- what `shell_rules` hands a provider and what
    comes back through `validate_zone`. Deriving it here means the
    registry is read in exactly one place, so a provider is judged
    against the same row it was given.
    """
    rule: dict = {"types": sorted(
        t for t in CHAMBER_TYPES if t in entry.semantic_tags)}
    if entry.fits_floors:
        rule["fits_floors"] = sorted(entry.fits_floors)
    if entry.provides_elevation:
        rule["provides_elevation"] = sorted(entry.provides_elevation)
    if entry.size:
        rule["size"] = [float(v) for v in entry.size]
    return rule


def rule_errors(shell_id: str, rule: dict, chamber) -> list[str]:
    """Why this shell cannot build this chamber, or [] when it can.

    THE SHARED RULE, and the only copy of it in Python. The selector in
    the offline generator, `validate_zone`, and `compatible_shells` all
    call this; Godot's `ContentInstantiator._misfit` asks the same
    question of the same registry fields. A Python check that accepted
    what Godot then refused would produce a Zone that validates and falls
    back to procedural rooms at runtime, which is exactly the silent
    substitution 3B exists to remove.

    Two clauses, and both come from the registry row:

    * TYPE. A shell says what it is through `semantic_tags`, which reach
      the row as `types`; a chamber says what it needs through `type`.
      Being somewhere in the flattened offered list is not enough -- a
      treasure room is offered, and it is not an arena.
    * FIXED AUTHORED CONSTRAINTS. `fits_floors` is the one that exists:
      a tower shell built for 3 floors may not be used for 4. An empty
      `fits_floors`, or a chamber with no `floors`, declares no
      constraint -- the same two early returns Godot takes.

    An ABSENT OR EMPTY `types` constrains nothing by type -- the same
    early return `fits_floors` takes, and the same one Godot's `_misfit`
    takes. "Declares nothing" is not "fits nothing", and the distinction
    matters because Godot resolves ids from a registry that carries
    entries the catalog never offers. What keeps an untagged shell from
    being SELECTED is the offer, checked against the request's catalog
    one clause earlier.
    """
    out: list[str] = []
    wanted = str(field(chamber, "type") or "")
    types = rule.get("types")
    if wanted and types and wanted not in types:
        out.append(
            f"selects shell '{shell_id}', which is tagged "
            f"{sorted(types)} and this chamber is a '{wanted}'")
    allowed = rule.get("fits_floors")
    floors = field(chamber, "floors")
    if allowed and floors is not None and int(floors) not in allowed:
        out.append(
            f"selects shell '{shell_id}', which is built for "
            f"{sorted(allowed)} floors and this chamber has {floors}")

    # THE CHAMBER'S OWN CONTENT REQUIREMENTS, not just the shell's
    # dimensions. A chamber that declares an elevation band needs a
    # room with that band in it -- the procedural builder digs one where
    # the chamber says, and an authored shell's geometry was fixed
    # before the request existed. Naming one anyway produced five rooms
    # whose declared band had no `band_deck` socket at all.
    # DOES THE SHELL FIT THE ROOM IT IS BUILDING? The most basic fixed
    # authored constraint, and the one that was missing. Every offered
    # arena shell is a showpiece 31 to 85 m across; every arena the
    # generator asks for is 12 to 26 m. Naming one for the other does
    # not compose a room -- it substitutes a space five times the size,
    # and the Zone's budget, enemy counts, connector rhythm and layout
    # were all computed from the numbers the room then ignores. Measured
    # on the played Zone: rooms landed inside each other and a Check
    # ended up buried in the wall of a different chamber.
    #
    # The shell's `size` is its ENVELOPE, walls included; a chamber's
    # width and depth are its INTERIOR, so one wall on each side is the
    # allowance. Corridors say `length` where other rooms say `depth`.
    size = rule.get("size")
    outer = 2.0 * WALL_THICKNESS
    width = field(chamber, "width")
    along = field(chamber, "depth")
    if along is None:
        along = field(chamber, "length")
    if size and width is not None and along is not None:
        room = (float(width) + outer, float(along) + outer)
        if size[0] > room[0] or size[2] > room[1]:
            out.append(
                f"selects shell '{shell_id}', whose footprint is "
                f"{size[0]:.1f} x {size[2]:.1f} and this chamber is "
                f"{room[0]:.1f} x {room[1]:.1f} including walls")
        # ...AND NOT SMALLER, once the room has been sized to hold
        # something. The fallback WIDENS a corridor before hanging an
        # affordance on it, so a chamber carrying features is a room
        # whose dimensions were chosen for its contents. A 6.8 m corner
        # shell in a corridor widened to 7.9 x 14.4 is under half the
        # floor the features were placed against, and the measured
        # result was a Zone that offered two affordances and built
        # neither -- content dropped without a word, which is the one
        # thing a passing result may never be obtained by.
        elif field(chamber, "features") and (
                size[0] < room[0] or size[2] < room[1]):
            out.append(
                f"selects shell '{shell_id}', whose footprint is "
                f"{size[0]:.1f} x {size[2]:.1f} and this chamber was "
                f"sized {room[0]:.1f} x {room[1]:.1f} to hold "
                f"{len(field(chamber, 'features'))} feature(s)")

    band = field(chamber, "elevation")
    kind = (band.get("kind") if isinstance(band, dict)
            else getattr(band, "kind", None)) if band else None
    if kind and kind not in rule.get("provides_elevation", ()):
        out.append(
            f"selects shell '{shell_id}', which provides "
            f"{sorted(rule.get('provides_elevation', ())) or 'no'} "
            f"elevation band(s) and this chamber declares a '{kind}'")
    return out


def compatibility_errors(entry: ContentEntry, chamber) -> list[str]:
    """`rule_errors` for a registry entry, for callers holding one."""
    return rule_errors(entry.id, rule_of(entry), chamber)


def offered_for(chamber, catalog: dict[str, list[str]] | None,
                rules: dict[str, dict] | None) -> tuple[str, ...]:
    """Which shells THIS REQUEST offered that could build this chamber.

    The selection question, answered from the wire form rather than from
    the registry. A generator that reads the registry directly can name a
    shell the request never offered -- it did, and it was invisible in
    production only because the live request happens to be built from the
    same registry. The offer is the contract: a request that offers
    nothing gets no authored shells, and a request that offers a treasure
    room does not thereby offer an arena.

    Sorted, so a generator picking from it deterministically picks the
    same way twice.
    """
    offered = (catalog or {}).get(str(field(chamber, "type") or ""), ())
    return tuple(sorted(
        shell_id for shell_id in offered
        if not rule_errors(shell_id, (rules or {}).get(shell_id, {}), chamber)))


def compatible_shells(registry: dict[str, ContentEntry],
                      chamber: dict) -> tuple[str, ...]:
    """Every offerable shell that could build this chamber, sorted.

    Sorted so a generator that picks from it deterministically picks the
    same way twice.
    """
    return tuple(sorted(
        entry.id for entry in registry.values()
        if is_offerable(entry) and not compatibility_errors(entry, chamber)))


def shell_rules(registry: dict[str, ContentEntry] | None = None,
                ) -> dict[str, dict]:
    """The constraints a provider needs to choose validly, per shell id.

    Handed to Epsilon alongside the catalog. Without it a provider can
    only guess which tower shell suits a four-floor tower, and a guess
    that lands wrong costs a repair round for a fact the registry already
    knew.

    Ids and constraints only: no scene, no path. What crosses to a
    provider stays a short id from a closed list (`AUTHORED_CONTENT.md`,
    art requirement 1).
    """
    reg = registry if registry is not None else load_registry()
    out: dict[str, dict] = {}
    for entry in reg.values():
        if not is_offerable(entry):
            continue
        out[entry.id] = rule_of(entry)
    return dict(sorted(out.items()))


def offer_of(request) -> dict:
    """The shell arguments `validate_zone` takes, read off a request.

    ONE DEFINITION, because four had already appeared: the shipping
    validator, the offline generator's own self-check, the baseline
    fixture and every test helper each spelled out how to unpack
    `request.catalog`, and the self-check spelled it out by leaving it
    out -- it validated its own valid choices against an empty offer,
    rejected them, and retried through every salt until the level it
    finally accepted had different content. A self-check held to
    different rules than the caller is not a self-check.

    Spread it: `validate_zone(zone, ..., **shells.offer_of(request))`.
    """
    catalog = request.catalog.get("room_shells", {})
    return {
        "legal_shell_ids": all_legal_shell_ids(catalog),
        "shell_catalog": catalog,
        "shell_rules": request.catalog.get("room_shell_rules", {}),
    }
