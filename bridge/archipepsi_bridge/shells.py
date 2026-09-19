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

#: A shell's envelope minus its interior: one wall on each side.
OUTER = 2.0 * WALL_THICKNESS

#: How far a declared dimension may sit from a shell's, in metres.
#: Manifests carry two decimals and floats round; this is a rounding
#: allowance and nothing else -- it is far below `MAX_VERTICAL_STEP`, so
#: no gap a player could notice can hide inside it.
SPAN_TOLERANCE = 0.005


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


def doorways_off_the_body(entry: ContentEntry) -> dict[str, float]:
    """`socket name -> metres adrift`, for doorways not on this shell.

    The Python half of `ContentInstantiator.doorways_outside_envelope`,
    measuring the same allowance against the same manifest so the two
    lanes cannot disagree about which shells are joinable.

    A shell's `size` IS ITS OUTER FACE, and that is measured rather than
    assumed: Arty's 2026-09-12 reply reports the wall at the exit of all
    three repaired shells running to exactly the declared depth
    (`hl_back_*` 59.40-60.00 against a depth of 60, and the same for
    Plenum and Span). Nine of the twelve put their doorways at or inside
    that face -- `shell_corner_left`'s exit sits on it exactly, at 3.4 of
    6.8. So the allowance here is the manifests' two-decimal ROUNDING and
    nothing more.

    NOT ONE WALL THICKNESS. This allowed `WALL_THICKNESS` at first, by
    analogy with `ChamberBuilders.corner`, which steps its exit a full
    thickness past its bounds on purpose. That analogy is wrong, and
    `layout.SOCKET_PROUD` is where it belongs: the engine's REPORTED
    bounds span its walls' centre planes, so a socket on the outer face
    is half a thickness outside them; a manifest's `size` is the outer
    face already. Two comparisons against two different things.
    Collapsing them cost a false negative -- `shell_yard_gantry` puts
    both its doorways 0.40 m past an envelope running -42.60..42.60, and
    a 0.405 allowance passed it by five millimetres. Arty measured it and
    said so.

    What it is not is a free coordinate. A socket past the body puts a
    corridor's mouth in open air with the room's wall behind it, and the
    composer's overlap test never considered that volume because the room
    does not claim it. This measures that distance and nothing else: it
    says nothing about whether the aperture is cut, whether a lock blocks
    it, or whether a body can stand at it -- those are three other
    measurements, taken in the engine, against real geometry.
    """
    out: dict[str, float] = {}
    w, h, d = (float(v) for v in entry.size)
    if w <= 0.0 or d <= 0.0:
        return out
    slack = SPAN_TOLERANCE
    lo = (-w / 2.0 - slack, -slack, -slack)
    hi = (w / 2.0 + slack, h + slack, d + slack)
    for socket in entry.sockets:
        if socket.kind != "doorway":
            continue
        worst = max(max(lo[i] - socket.position[i],
                        socket.position[i] - hi[i]) for i in range(3))
        if worst > 0.0:
            out[socket.name] = worst
    return out


def is_offerable(entry: ContentEntry) -> bool:
    """Whether this entry may be put in front of Epsilon at all.

    Four gates, and the middle two are the art lane's:

    * it is a room shell;
    * it is not `review: pending` -- a file existing in the tree is not
      approval, and offering a pending asset decides for whoever is
      still deciding;
    * every doorway it declares lies on its own body. `review: pass`
      approved how these three look, and nothing in that review
      measured where their doorways were: `shell_hall_transit`,
      `shell_plenum_helix` and `shell_span_basin` each put `exit` two
      metres past their own declared depth, so a Zone built with one
      has its wall at the depth and its corridor starting two metres
      further on, with nothing in between. That is the join the
      2026-09-11 playtest opened with ("the connecter isnt connected at
      all") and what the layout validator now refuses a generated Zone
      for, by name. Withheld rather than repaired: an authored
      coordinate is Art's, the repair is filed
      (`docs/art-requests/2026-09-11-doorways-outside-their-envelope.md`),
      and this gate lets the shell back in the moment it lands;
    * it is authored. A procedural entry is the fallback the builder
      reaches anyway, so naming it explicitly buys nothing and would let
      Epsilon "choose" the thing it gets by choosing nothing.
    """
    if entry.category != "room_shell":
        return False
    if entry.review == "pending":
        return False
    # NO LONGER A GATE, and the reason is measured.
    #
    # This refused a shell whose doorway stood proud of `size`. Two
    # measurements on 2026-09-12 killed the rule from both sides.
    # `shell_corner_left`'s exit sits exactly ON its envelope face and
    # 0.40 m past its own FLOOR, because the floor is inset by a wall;
    # `shell_yard_gantry`'s sits 0.40 m past the envelope. The step a
    # body walks over is the same 0.40 m in both, and the envelope
    # disagrees about which is which. And Arty's threshold repair carries
    # the yard's floor out as MESH -- not a declared surface, not in
    # `size` -- so no manifest rule can see the repair at all.
    #
    # THE AUTHORITY IS THE ASSEMBLED CROSSING, measured in the engine:
    # `room_contract_driver._test_every_shell_doorway_is_crossed_by_a_real_body`
    # builds each shell through the production importer, lays a connector
    # stub at each doorway the way `ZoneBuilder` does, and walks a real
    # `Player` out. All 24 authored doorways cross, 3.05-3.11 m past the
    # socket with 0.08 m of dip; a stub detached by 2.0 m drops the body
    # 5.87 m, which is what proves the measurement can fail.
    #
    # What stays here is the REPORT. A doorway metres off its body is
    # still worth saying out loud, and `doorways_off_the_body` still says
    # it -- it just no longer decides, because it cannot see floor.
    adrift = doorways_off_the_body(entry)
    if adrift:
        log.info("shell '%s' declares a doorway off its envelope: %s "
                 "(a report, not a refusal -- the crossing test decides)",
                 entry.id,
                 "; ".join(f"'{n}' by {m:.2f} m"
                           for n, m in sorted(adrift.items())))
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


#: Socket kinds a corridor may actually join to.
#:
#: The Python mirror of `connector_grammar.gd`'s `JOINABLE`. A shell's
#: CAPACITY is how many of these it declares, and it is read here rather
#: than assumed: `topology.AUTHORED_SOCKETS` used to hardcode
#: `("entry", "exit")` on the true-but-brittle ground that all twelve
#: authored shells declare exactly those two. True today; a three-door
#: shell would have been read as a two-door one, and no amount of
#: composer support would have made it usable.
JOINABLE_SOCKET_KINDS = ("doorway", "corridor_end")


def joinable_sockets(entry: ContentEntry) -> tuple[str, ...]:
    """The stable socket identities this content offers a corridor.

    Names, not a count: the composer assigns edges to named sockets and
    the engine resolves those names against the imported scene, so a
    capacity expressed as a number would leave the composer inventing
    which openings it meant. Sorted, so two runs assign the same way.
    """
    return tuple(sorted(s.name for s in entry.sockets
                        if s.kind in JOINABLE_SOCKET_KINDS))


def sockets_by_shell(registry: dict[str, ContentEntry] | None = None,
                     ) -> dict[str, tuple[str, ...]]:
    """`shell_id -> its joinable socket names`, for the composer."""
    reg = registry if registry is not None else load_registry()
    return {cid: joinable_sockets(entry) for cid, entry in reg.items()}


def declared_sockets(rule: dict) -> tuple[str, ...]:
    """The same thing off the WIRE rule, which is what a generator has.

    `offered_for` exists because a generator that reads the registry can
    name a shell the request never offered. Capacity has the same
    problem one level down: a generator choosing a shell for a room that
    will branch has to be able to see which shells can carry a branch,
    and until `rule_of` carried the names it could not.
    """
    return tuple(rule.get("joinable", ()))


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
    # CAPACITY, ON THE WIRE. Without it the offer says what a shell fits
    # and not how many ways out it has, so nothing choosing a shell can
    # choose one that branches -- and a composer taught about three-door
    # rooms would still never be handed one.
    joinable = joinable_sockets(entry)
    if joinable:
        rule["joinable"] = list(joinable)
    return rule


def feature_tags(chamber) -> tuple[str, ...]:
    """The affordance tags a chamber carries, dict or model."""
    out: list[str] = []
    for feature in field(chamber, "features") or ():
        tag = (feature.get("tag") if isinstance(feature, dict)
               else getattr(feature, "tag", None))
        if tag:
            out.append(str(tag))
    return tuple(out)


def rule_errors(shell_id: str, rule: dict, chamber) -> list[str]:
    """`rule_problems`, message only, for callers that just want the text."""
    return [why for _, why in rule_problems(shell_id, rule, chamber)]


def rule_problems(shell_id: str, rule: dict, chamber) -> list[tuple[str, str]]:
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

    Each problem comes back as `(clause, message)`. The clause names
    the COMPARISON that failed, and `godot/tests/fixtures/shell_rule_cases.json`
    is executed against it by both this and `ContentInstantiator._misfit`
    -- a parity test comparing field NAMES passed while the two sides
    compared those fields differently, which was the whole point of it.

    An ABSENT OR EMPTY `types` constrains nothing by type -- the same
    early return `fits_floors` takes, and the same one Godot's `_misfit`
    takes. "Declares nothing" is not "fits nothing", and the distinction
    matters because Godot resolves ids from a registry that carries
    entries the catalog never offers. What keeps an untagged shell from
    being SELECTED is the offer, checked against the request's catalog
    one clause earlier.
    """
    out: list[tuple[str, str]] = []
    wanted = str(field(chamber, "type") or "")
    types = rule.get("types")
    if wanted and types and wanted not in types:
        out.append(("type",
            f"selects shell '{shell_id}', which is tagged "
            f"{sorted(types)} and this chamber is a '{wanted}'"))
    allowed = rule.get("fits_floors")
    floors = field(chamber, "floors")
    if allowed and floors is not None and int(floors) not in allowed:
        out.append(("floors",
            f"selects shell '{shell_id}', which is built for "
            f"{sorted(allowed)} floors and this chamber has {floors}"))

    # THE CHAMBER'S OWN CONTENT REQUIREMENTS, not just the shell's
    # dimensions. A chamber that declares an elevation band needs a
    # room with that band in it -- the procedural builder digs one where
    # the chamber says, and an authored shell's geometry was fixed
    # before the request existed. Naming one anyway produced five rooms
    # whose declared band had no `band_deck` socket at all.
    # IS THE SHELL THE ROOM? Since the owner ruling of 2026-09-11 an
    # approved shell's fixed geometry informs the chamber it builds, so
    # the two are not merely compatible -- they are the same room, and
    # this is an EQUALITY rather than a range.
    #
    # The pair of one-sided clauses this replaces was the source of the
    # discrepancy with the production prompt, and worse, it could not
    # express what was wanted: "no bigger than the chamber" refused
    # every arena shell outright (they are 31 to 85 m and the builder's
    # arenas are 12 to 26), and "no smaller when the chamber carries
    # features" was a special case standing in for the general rule.
    # `_select_authored_shells` now DERIVES the chamber's dimensions
    # from the shell it picked, so the equality is what generation
    # produces and what a provider must reproduce.
    #
    # The shell's `size` is its ENVELOPE, walls included; a chamber's
    # width and depth are its INTERIOR, so one wall on each side is the
    # allowance. Corridors say `length` where other rooms say `depth`.
    size = rule.get("size")
    width = field(chamber, "width")
    along = field(chamber, "depth")
    if along is None:
        along = field(chamber, "length")
    if size and width is not None and along is not None:
        for axis, got, want in (("width", size[0], float(width) + OUTER),
                                ("depth", size[2], float(along) + OUTER)):
            if abs(float(got) - want) > SPAN_TOLERANCE:
                out.append(("footprint",
                    f"selects shell '{shell_id}', whose {axis} is "
                    f"{float(got):.2f} and this chamber declares "
                    f"{want:.2f} including walls"))
    tall = field(chamber, "wall_height")
    if size and tall is not None and abs(float(size[1]) - float(tall)) \
            > SPAN_TOLERANCE:
        out.append(("height",
            f"selects shell '{shell_id}', which is {float(size[1]):.2f} "
            f"tall and this chamber declares {float(tall):.2f}"))

    # ...AND CAN IT HOLD WHAT THE ROOM CARRIES? A feature needs somewhere
    # to sit that is neither in the masonry nor across the walking lane,
    # and `FEATURE_MIN_WIDTH` is that width per tag. The chamber model
    # refuses a room too narrow for its own features, so a shell narrower
    # than one would produce a Zone that cannot validate -- and the
    # measured version of getting this wrong was a Zone that offered two
    # affordances and BUILT NEITHER.
    if size:
        interior = float(size[0]) - OUTER
        # THE RUN AS WELL AS THE LANE. `fits` is two questions; this
        # asked one, so a shell long enough for its rooms but too short
        # for a `powered_door`'s 11.0 m run passed here and the builder
        # dropped the tag.
        run = float(size[2]) - OUTER if len(size) > 2 else None
        for tag in feature_tags(chamber):
            needed = C.FEATURE_MIN_WIDTH.get(tag, C.MIN_FEATURE_CHAMBER_WIDTH)
            if interior + SPAN_TOLERANCE < needed:
                out.append(("feature",
                    f"selects shell '{shell_id}', whose {interior:.2f}m "
                    f"interior cannot hold a '{tag}', which needs "
                    f"{needed}m to sit clear of the walking lane"))
            along = C.FEATURE_MIN_DEPTH.get(tag, C.MIN_FEATURE_CHAMBER_DEPTH)
            if run is not None and run + SPAN_TOLERANCE < along:
                out.append(("feature",
                    f"selects shell '{shell_id}', whose {run:.2f}m run "
                    f"cannot hold a '{tag}', which needs {along}m to "
                    "clear both thresholds along it"))

    band = field(chamber, "elevation")
    kind = (band.get("kind") if isinstance(band, dict)
            else getattr(band, "kind", None)) if band else None
    if kind and kind not in rule.get("provides_elevation", ()):
        out.append(("elevation",
            f"selects shell '{shell_id}', which provides "
            f"{sorted(rule.get('provides_elevation', ())) or 'no'} "
            f"elevation band(s) and this chamber declares a '{kind}'"))
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


def adoptable(chamber, catalog: dict[str, list[str]] | None,
              rules: dict[str, dict] | None) -> tuple[str, ...]:
    """Offered shells this chamber could BECOME, sorted.

    `offered_for` asks whether a shell fits a room that already has its
    dimensions. This asks the generator's question instead: which offered
    shells could this chamber adopt? Every clause of `rule_errors` still
    applies except the dimension equality, which adoption is about to
    satisfy by construction -- the shell's type, its floor count, the
    elevation band it does or does not provide, and whether its interior
    can hold the features the room already carries.

    THE SIZE STILL HAS A BOUND. `MAX_AUTHORED_SPAN` and
    `MAX_AUTHORED_HEIGHT` are the schema's ceilings; a shell above them
    could be adopted and then fail to validate, which is a worse trade
    than not offering it.
    """
    out: list[str] = []
    for shell_id in (catalog or {}).get(str(field(chamber, "type") or ""), ()):
        rule = (rules or {}).get(shell_id, {})
        size = rule.get("size")
        if size and (max(float(size[0]), float(size[2])) > C.MAX_AUTHORED_SPAN
                     or float(size[1]) > C.MAX_AUTHORED_HEIGHT):
            continue
        probe = dict(chamber)
        for key in ("width", "depth", "length", "wall_height"):
            probe.pop(key, None)
        if not rule_errors(shell_id, rule, probe):
            out.append(shell_id)
    return tuple(sorted(out))


def footprint_area(rule: dict) -> float:
    """The floor a shell would add to a Zone, in square metres."""
    size = rule.get("size")
    return 0.0 if not size else float(size[0]) * float(size[2])


def adopt(chamber: dict, rule: dict) -> None:
    """Write a shell's fixed geometry into the chamber it will build.

    THE OWNER RULING OF 2026-09-11, in one function: an approved shell's
    geometry informs the chamber being generated, rather than the shell
    having to fit dimensions a builder chose before it was consulted.
    Every arena shell the art lane approved is 31 to 85 m across and no
    arena the builder proposes is over 28, so under the old direction the
    twelve approved shells could never have composed an arena at all.

    NOT SCALING. Nothing here stretches, retimes or reinterprets the
    shell: the numbers are copied off the manifest, and what changes is
    the chamber's description of itself. `rule_errors` then holds the two
    to an equality, so a Zone whose declared size disagrees with its
    named shell is refused wherever it came from.
    """
    size = rule.get("size")
    if not size:
        return
    chamber["width"] = round(float(size[0]) - OUTER, 3)
    key = "length" if "length" in chamber else "depth"
    chamber[key] = round(float(size[2]) - OUTER, 3)
    if "wall_height" in chamber:
        chamber["wall_height"] = round(float(size[1]), 3)


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
