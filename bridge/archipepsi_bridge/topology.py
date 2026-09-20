"""Producing the Zone graph, and proving you can get around it.

`09_ROOM_CONTRACT.md` Layer 2 production plus the logical half of §5.5.
Everything here is a graph question. **Nothing here touches geometry** —
whether a door is walkable, whether a key can physically be reached, and
where any room ends up are the engine's to measure and this module never
guesses at them.

Two halves:

* `compose_graph` turns a composed chamber list into edges, door
  assignments, keys and plugs.
* `reachability` answers the questions a composer has to answer before
  it may send a Zone: can the player reach the exit, every Check and
  every key, and is every key obtainable without passing its own lock.
"""

from __future__ import annotations

from dataclasses import dataclass, field

try:
    from .schemas.graph import (
        DoorAssignment, PlugAssignment, TopologyEdge, ZoneKeySpec)
    from .schemas import constants as C
    from .schemas import mechanics as M
    from .schemas.zone import Zone, procedural_sockets_for
except ImportError:  # pragma: no cover
    from schemas.graph import (
        DoorAssignment, PlugAssignment, TopologyEdge, ZoneKeySpec)
    from schemas import constants as C
    from schemas import mechanics as M
    from schemas.zone import Zone, procedural_sockets_for

#: What a chain needs from any room: a way in and a way out.
#:
#: Not a capacity claim — the capacity of an authored room comes from
#: its catalogue entry (`shells.joinable_sockets`). This is the pair the
#: SPINE uses, and it is named here because a room that cannot offer
#: both cannot sit on a chain at all.
SPINE_SOCKETS = ("entry", "exit")

#: The shortest spine worth branching off: a way in, something between,
#: a way out. Below this every room is load-bearing for the chain.
MIN_SPINE = 3

#: The distinct **locks** a Zone can hold, which is the key-colour
#: vocabulary and not a number chosen here. `KeyColour` has four values;
#: a fifth lock would reuse a colour, and two doors of one colour are
#: one lock rather than two decisions.
#:
#: This bounds how many branches are LOCKED. It does not bound how many
#: branches there are: it used to, because every branch got a lock, and
#: "every Zone gets four branches" was that recipe showing through
#: rather than anything about the shape of a Zone.
BRANCH_COLOURS: tuple[str, ...] = ("red", "blue", "green", "gold")

#: How much of the spare room budget may go onto branches.
#:
#: **Provisional tuning, and nothing more** (owner clarification,
#: 2026-09-12). Not a design law, not a physical cost, and **not a rule
#: against any particular shape.** A half share is where the dial
#: currently sits because it was the first value tried that produced a
#: distribution worth reading; it has no play evidence behind it yet,
#: and it keeps its place only if some arrives.
#:
#: An earlier note here reported "a three-room spine with five spokes
#: off it" as though the shape were the defect. **It is not.** A central
#: junction connecting many rooms is good dungeon design, and so are
#: deep branches, shallow ones, nested ones, spurs and dead ends. The
#: complaint this composer was built after was never about graph shape:
#: it was that rooms behaved like enlarged corridors, with little reason
#: to occupy or revisit them. That is a question about what is IN a
#: room, and no value of this constant answers it.
SPINE_SHARE = 0.5

#: How far off the spine a side path may run, counted in rooms.
#:
#: **Provisional tuning, and nothing more** (owner clarification,
#: 2026-09-12). Not a design law and not a physical cost.
#:
#: What it was introduced for was a MEASUREMENT defect, not a shape one:
#: the planner reported eight branches for what was one side chain eight
#: rooms deep, and `zone_shape.shape_of` is the fix for that — it counts
#: turnings rather than moved rooms, whatever this value is. With the
#: count honest, the depth itself is an open question. A long side path
#: is a legitimate thing for a Zone to have; so is a short one; so is a
#: junction with many rooms hanging off it.
#:
#: So this stays at 2 for now because it produces a distribution worth
#: reading, and it is a dial rather than a verdict. Raise it, remove it,
#: or keep it on play evidence — not to avoid a shape.
MAX_SIDE_DEPTH = 2

#: Wide enough to carry a side door without the opening landing on the
#: room's own furniture. Matches `Slice1Fixture.MIN_SPAN`, deliberately:
#: two lanes disagreeing about which rooms can branch is a defect that
#: only shows up as a wall in the wrong place.
MIN_JUNCTION_SPAN = 13.0


def _zone_limit(field: str) -> int:
    """A `Zone` collection bound, read from the schema that states it.

    Not copied here. `Zone.plugs` is capped at 8 and `Zone.edges` at 32,
    and a producer that quietly emitted 10 plugs would be refused by
    `accept_zone` with a pydantic error naming a tuple length — which is
    what happened, and is a worse way to learn the bound than asking for
    it. The alternative to reading it is a second spelling of a number
    that can then disagree.
    """
    for meta in Zone.model_fields[field].metadata:
        if hasattr(meta, "max_length"):
            return meta.max_length
    raise ValueError(f"`Zone.{field}` states no maximum length")


#: Why a composition failed, as a CODE rather than as a sentence.
#:
#: The refusal paths below used to say what was wrong in `notes` and
#: nothing else — and `apply` drops notes, `reachability` reads an
#: edge-less Zone as the legacy chain it cannot distinguish this from,
#: and `campaign._with_graph` handed the result back as a good Zone. The
#: only thing that caught it was the `Zone` schema refusing doors
#: without edges when `accept_zone` rebuilt the record: a pydantic
#: exception out of a background task, which protects the save and is
#: not a handled refusal.
#:
#: So the reason is a value the campaign reads. **Prose is for the log;
#: it is never control flow.**
REFUSAL_CODES = (
    "no_arrival",               # a room declares no `entry`
    "destination_is_an_end",    # a leaf is the Zone's first or last room
    "destination_unreachable",  # no room before a leaf can host it
    "destination_unhostable",   # a required leaf is a barred host
    "chain_unreachable",        # not even the plain chain gets around
)


@dataclass(frozen=True)
class GraphRefusal:
    """A composition that did not happen, and why."""

    code: str
    detail: str
    rooms: tuple[str, ...] = ()

    def __post_init__(self):
        if self.code not in REFUSAL_CODES:
            raise ValueError(
                f"'{self.code}' is not a refusal this composer declares; "
                f"the codes are {list(REFUSAL_CODES)}")


class GraphRefused(Exception):
    """Raised when a Zone cannot be composed at all.

    Carries the `GraphRefusal` so the caller decides what to do about it
    without reading a message.
    """

    def __init__(self, refusal: GraphRefusal):
        super().__init__(f"{refusal.code}: {refusal.detail}")
        self.refusal = refusal


@dataclass(frozen=True)
class GraphProduct:
    """What a composer hands the engine, minus the chambers themselves."""

    edges: tuple[TopologyEdge, ...]
    doors: dict[str, tuple[DoorAssignment, ...]]
    keys: dict[str, tuple[ZoneKeySpec, ...]]
    plugs: tuple[PlugAssignment, ...]
    #: What the producer did and why, for a log rather than for logic.
    notes: tuple[str, ...] = ()
    #: `room_id -> edge_id` for the edge the chain arrives by and the one
    #: it departs by (`09_ROOM_CONTRACT.md` §11.2). **Pointers into the
    #: door assignment, not a second topology**: every value names an
    #: edge that room's own door already carries, and `Chamber`'s
    #: validator refuses one that does not.
    arrivals: dict[str, str] = field(default_factory=dict)
    departures: dict[str, str] = field(default_factory=dict)

    #: Set when the Zone could not be composed at all. **Not the same as
    #: an empty product**: a Zone with nothing to branch composes as a
    #: plain chain and refuses nothing, and a Zone carrying no graph at
    #: all is the legacy shape that still loads. This says the composer
    #: was asked for something it could not build.
    refusal: GraphRefusal | None = None

    @property
    def refused(self) -> bool:
        return self.refusal is not None


def _shell_sockets() -> dict[str, tuple[str, ...]]:
    """`shell_id -> declared joinable sockets`, read once per compose."""
    from . import shells
    return shells.sockets_by_shell()


def _sockets_for(chamber, shell_sockets: dict[str, tuple[str, ...]]
                 ) -> tuple[str, ...]:
    """Which joining sockets this room actually declares.

    **Read, not assumed.** This returned a hardcoded `("entry", "exit")`
    for every authored shell, which was true of all twelve and is not a
    property of being authored. A shell declaring a third doorway would
    have been composed as a two-door room, its third opening never
    assigned and therefore SEALED by `_seal_the_rest` — the composer
    walling up geometry an artist had cut, with nothing anywhere saying
    so.

    A procedural room declares what its TYPE can hold:
    `procedural_sockets_for` is the one declaration — projected from
    `C.PROCEDURAL_SOCKET_CAPACITY`, shared with the Zone's own Invariant
    8 and with the ENGINE through `constants.gd`, so the planner, the
    validator and the builder cannot disagree about how many doors a
    room has. It was four for every type, so a branch was hung off a
    `platform_path`'s side, the engine raised a solid wall there, and
    the bridge refused the whole layout for a door this lane had
    assigned to an opening that does not exist.
    """
    if not chamber.shell_id:
        return procedural_sockets_for(chamber.type)
    declared = shell_sockets.get(chamber.shell_id)
    if declared is None:
        # BACKSTOP, unreachable through acceptance: `validate_zone`
        # refuses a `shell_id` outside `all_legal_shell_ids`, which is
        # derived from the same registry this map is. If that ever
        # loosens, the alternative to raising is inventing a socket
        # pair for a room nobody has measured — which is how a door
        # gets assigned to an opening that does not exist.
        raise ValueError(
            f"room '{chamber.id}' names shell '{chamber.shell_id}', "
            "which declares no sockets this composer can read; a shell "
            "with unknown openings cannot be given doors")
    return declared


def capacity_of(chamber, shell_sockets: dict[str, tuple[str, ...]]) -> int:
    """How many JOINED edges this room could carry.

    The count of what it declares, and nothing to do with whether it is
    authored. A plug consumes no socket (`Chamber.door_degree` counts
    JOINED edges only), so a return does not spend capacity and a
    dead end with a way home is still a dead end.
    """
    return len(_sockets_for(chamber, shell_sockets))


def _spare_sockets(chamber, shell_sockets: dict[str, tuple[str, ...]],
                   used: set[str]) -> tuple[str, ...]:
    """Declared sockets this room has not spent, in a stable order."""
    return tuple(s for s in _sockets_for(chamber, shell_sockets)
                 if s not in used)


def _seal_the_rest(chamber, used: dict[str, DoorAssignment],
                   shell_sockets: dict[str, tuple[str, ...]]
                   ) -> tuple[DoorAssignment, ...]:
    """Every socket this room declares, with the unused ones SEALED.

    An unmentioned socket is a contract violation, because "unmentioned"
    is exactly how an unaudited hole gets into a wall. A sealed door is
    measured with the expectation inverted, never skipped.
    """
    out = []
    for socket in _sockets_for(chamber, shell_sockets):
        if socket in used:
            out.append(used[socket])
        else:
            out.append(DoorAssignment(socket_id=socket, usage="SEALED"))
    return tuple(out)


def _reserve_the_zone_exit(chambers, doors, spine, shell_sockets) -> str:
    """Give the LAST room on the spine the Zone's own way out.

    A chain is written with `zip(spine, spine[1:])`, so the last room is
    assigned no `exit` and `_seal_the_rest` seals it. That is right as
    far as this graph goes — nothing here follows it — and it was wrong
    about the Zone, because the ENGINE appends an exit room and routes
    its approach out of exactly that face. The two lanes disagreed about
    a wall, and twenty of twenty default-scale Zones ended on a room the
    player could see the exit through and never reach.

    `ZONE_EXIT` is passable geometry that names no edge, because the
    room on its far side is the engine's and is in no `edges` list. It
    is assigned here, in the one place that decides which doors exist,
    rather than carved by the engine against this lane's own
    declaration.

    A room that declares no `exit` socket keeps none: inventing one
    would advertise a doorway its producer does not build, which is what
    `PROCEDURAL_SOCKET_CAPACITY` exists to stop. The engine refuses such
    a Zone and the campaign composes another.

    Returns the room it was given to, or "" if none could take it.
    """
    for rid in reversed(spine):
        chamber = next((c for c in chambers if c.id == rid), None)
        if chamber is None:
            continue
        if "exit" not in _sockets_for(chamber, shell_sockets):
            return ""
        if "exit" in doors.get(rid, {}):
            # Already spent on a real edge: this room is not the end of
            # the chain after all, so there is nothing to reserve.
            return ""
        doors.setdefault(rid, {})["exit"] = DoorAssignment(
            socket_id="exit", usage="ZONE_EXIT")
        return rid
    return ""


def compose_chain(chambers, shell_sockets=None) -> GraphProduct:
    """The graph the list order always meant, now said out loud.

    This is not new topology. It is the existing chain written as edges
    so that everything downstream — reachability, the manifest, the
    engine's socket resolution — reads one representation instead of
    inferring one from a list index.
    """
    caps = _shell_sockets() if shell_sockets is None else shell_sockets
    edges: list[TopologyEdge] = []
    doors: dict[str, dict[str, DoorAssignment]] = {c.id: {} for c in chambers}
    arrivals: dict[str, str] = {}
    departures: dict[str, str] = {}
    unfit = [c.id for c in chambers
             if not set(SPINE_SOCKETS) <= set(_sockets_for(c, caps))]
    if unfit:
        # A room that cannot offer a way in AND a way out cannot sit on
        # a chain. Said rather than worked around: the alternative is
        # assigning an edge to a socket the room never declared.
        return GraphProduct(
            edges=(), doors={c.id: _seal_the_rest(c, {}, caps)
                             for c in chambers},
            keys={}, plugs=(),
            notes=("no chain: room(s) %s declare no entry/exit pair"
                   % unfit,))
    for a, b in zip(chambers, chambers[1:]):
        edge = TopologyEdge(
            edge_id=f"e:{a.id}:{b.id}", room_a=a.id, room_b=b.id,
            direction="BIDIRECTIONAL", realization="JOINED")
        edges.append(edge)
        doors[a.id]["exit"] = DoorAssignment(
            socket_id="exit", usage="USED", edge_id=edge.edge_id)
        doors[b.id]["entry"] = DoorAssignment(
            socket_id="entry", usage="USED", edge_id=edge.edge_id)
        departures[a.id] = edge.edge_id
        arrivals[b.id] = edge.edge_id
    way_out = _reserve_the_zone_exit(
        chambers, doors, [c.id for c in chambers], caps)
    return GraphProduct(
        edges=tuple(edges),
        doors={c.id: _seal_the_rest(c, doors[c.id], caps) for c in chambers},
        keys={}, plugs=(),
        notes=("chain: %d rooms, %d edges" % (len(chambers), len(edges)),
               "zone exit: room '%s'" % way_out if way_out
               else "zone exit: no room on the chain declares an 'exit' "
                    "socket to leave through"),
        arrivals=arrivals, departures=departures)


#: What a room's declared openings say it can BE.
#:
#: `entry` and `exit` are not two names among many here. The contract
#: gives them one meaning each — the way the chain comes in and the way
#: it goes on — and the engine's `socket_by_id` aliases them to a
#: connector grammar's `end_a`/`end_b` for exactly that reason. So a
#: shell that declares `exit` is saying *the chain may continue through
#: me*, and one that declares an arrival and no `exit` is saying *the
#: chain arrives and stops*.
#:
#: That is a capacity fact, already on the wire, and it is the whole of
#: what the bridge needs. `shape_tags` ("destination", "dead_end") never
#: reaches this lane and is not consulted: a role read off authored
#: prose could disagree with the openings the room actually has.
ROLE_THROUGH = "through"        # entry and exit: may sit on the spine
ROLE_LEAF = "leaf"              # entry, no exit: a destination only
ROLE_UNJOINABLE = "unjoinable"  # no arrival: nothing can reach it


def _role(chamber, shell_sockets) -> str:
    """Which roles this room's own declaration permits.

    **Read before anything is composed.** `compose_with_branch` used to
    call `compose_chain` first, and `compose_chain` requires an
    entry/exit pair from every room — so a leaf-compatible room was
    refused as a through-room before it could ever be chosen as a leaf,
    and the Zone came back with no edges at all. A room whose intended
    role is "destination" cannot be asked for a departure first.
    """
    declared = set(_sockets_for(chamber, shell_sockets))
    if "entry" not in declared:
        return ROLE_UNJOINABLE
    if "exit" not in declared:
        return ROLE_LEAF
    return ROLE_THROUGH


def _roles(chambers, shell_sockets) -> dict[str, str]:
    return {c.id: _role(c, shell_sockets) for c in chambers}


def _role_refusal(chambers, roles: dict[str, str]) -> GraphRefusal | None:
    """Why this Zone's rooms cannot be given the roles it needs.

    Each of these is a REFUSAL, never a quiet linearisation. A Zone that
    cannot place a leaf is a Zone the composer must not send: dropping
    the graph would leave the leaf with every opening sealed and nothing
    saying so, which is what happened.
    """
    stranded = tuple(c.id for c in chambers
                     if roles[c.id] == ROLE_UNJOINABLE)
    if stranded:
        return GraphRefusal(
            "no_arrival",
            "room(s) %s declare no `entry`; nothing can reach them and "
            "the composer will not invent an opening" % list(stranded),
            stranded)
    first, last = chambers[0].id, chambers[-1].id
    for rid, what in ((first, "the room the player arrives in"),
                      (last, "the room the Zone leaves by")):
        if roles[rid] == ROLE_LEAF:
            return GraphRefusal(
                "destination_is_an_end",
                "room '%s' is %s and declares no `exit`; a destination "
                "cannot carry the chain and the composer will not "
                "fabricate a departure for it" % (rid, what),
                (rid,))
    return None


def _side_socket(chamber, spare: tuple[str, ...]) -> str | None:
    """Which spare socket a side door may use.

    For a procedural room this avoids the wall a raised deck hugs: a
    `left` band's deck reaches the left wall at `rise` — 1.79 m up for a
    2.19 m gallery, inside a standing capsule — so a doorway cut there
    has a floor slab across it at chest height. The engine carves the
    hole, the deck stands in it, and the layout is refused ("door
    'c009/side_left' is LOCKED and the engine measured it as solid").

    A `back` or `front` band blocks BOTH sides, and this used to block
    neither. Such a deck spans the room's WIDTH -- it is the full-width
    gallery the exit rule already knows about -- so it meets the left and
    the right wall alike, and `f"side_{band.side}"` spells `side_back`,
    which is not a socket and excludes nothing. Measured: `zone_10`'s
    `c005` is a 23.5 x 19.3 arena with a `back` gallery whose deck stands
    at room-local x -11.75..9.75, y 1.34..1.74, z 9.0..17.3 -- reaching
    the left wall exactly, at chest height, across a `side_left` the
    composer had declared USED. The layout was refused on aperture
    polarity.

    A ROOM'S OWN FEATURES BLOCK A SIDE WALL TOO, and for the same
    reason: `side_left` and `side_right` are cut at the MIDDLE of the
    wall, which is exactly where `resolve_position` puts a feature it has
    pushed out of the walking lane. `zone_02`'s `c013` is a 13.6 m
    corridor whose `powered_door` leaf stood at x -4.55..-2.45,
    z 7.55..7.75, through a wall whose opening is at (-3.95, 0, 6.8).
    `FEATURE_MIN_DEPTH_BESIDE_DOOR` is the run such a feature needs to
    sit wholly to one side of the opening; a room shorter than that
    cannot carry both, and the DOORWAY is the one to move, because the
    feature is already placed and the door is still being chosen.

    For an authored room there is nothing to avoid on the band's
    account: the artist placed the openings, and every one they declared
    is one they meant. The feature rule still applies -- a shell's
    doorway is as real as a carved one, and a note standing in it is as
    solid.
    """
    band = getattr(chamber, "elevation", None)
    blocked: set[str] = set()
    if band is not None:
        side = str(getattr(band, "side", ""))
        blocked = (set(C.SIDE_SOCKETS) if side in ("back", "front")
                   else {f"side_{side}"})
    if _features_need_the_side_walls(chamber):
        blocked |= set(C.SIDE_SOCKETS)
    for socket in spare:
        if socket not in blocked:
            return socket
    return None


def _features_need_the_side_walls(chamber) -> bool:
    """Would this room's own features stand in a side doorway?

    The room is measured against `FEATURE_MIN_DEPTH_BESIDE_DOOR`: the run
    a feature needs to sit wholly to one side of an opening cut at the
    middle of the wall. A room with no depth to judge is left alone --
    "we cannot tell" and "it is fine" must not produce the same answer,
    and the schema rule refuses the pairing either way if it is wrong.
    """
    features = getattr(chamber, "features", ()) or ()
    if not features:
        return False
    depth = getattr(chamber, "length", None)
    if depth is None:
        depth = getattr(chamber, "depth", None)
    if depth is None:
        depth = getattr(chamber, "side", None)
    if depth is None:
        return False
    return any(
        float(depth) < C.FEATURE_MIN_DEPTH_BESIDE_DOOR.get(
            f.tag, C.MIN_FEATURE_CHAMBER_DEPTH_BESIDE_DOOR)
        for f in features)


@dataclass(frozen=True)
class BranchLock:
    """How one lock and its key are identified and presented.

    Two spellings on purpose, because they answer different questions.
    `key_id` is the identity the runtime matches a picked-up key
    against; `colour` is what the player sees on the slab and on the key
    in their hand. They are kept one-to-one **within a Zone** — see
    `_lock_routes` — so that "the red door" names exactly one door. Two
    locks sharing a colour with different `key_id`s would be readable as
    one lock and behave as two, which is the confusion this class exists
    to make impossible to write by accident.
    """

    key_id: str
    colour: str


@dataclass(frozen=True)
class BranchRoute:
    """One route off the spine: where it starts, where it goes, and
    which of the junction's openings carries it.

    `lock` is deliberately a separate, optional field. Whether a route
    exists is a question about capacity and content; whether it is
    locked is a question about the local-key recipe. A route with
    `lock=None` is an ordinary branch — a side room the player can walk
    into, which is still a choice about where to go.
    """

    junction_id: str
    destination: object
    socket: str
    lock: BranchLock | None = None

    @property
    def locked(self) -> bool:
        return self.lock is not None


def _branch_routes(chambers, caps, required=(), barred=()
                   ) -> tuple[list[BranchRoute], tuple[str, ...]]:
    """Which rooms branch off which, and why the rest do not.

    **Topology only.** Nothing here decides whether a route is locked;
    `_lock_routes` does that, afterwards, from what this produced. The
    two were one function, and the join made the branch count a
    consequence of the key vocabulary — four colours meant four
    branches, in every Zone big enough, which read as a template.

    Derived from what the Zone already has rather than from a template.
    Three things bound it:

    * **The spine keeps its ends.** The first room is where the player
      arrives and the last is the exit; moving either onto a branch
      makes the exit a dead end behind a lock. A real cost.
    * **A destination must be spare.** Every room pulled off the spine
      shortens it. How many may be spared is *provisional tuning* — see
      `SPINE_SHARE` — not a design law and not a physical cost.
    * **A junction must have a socket to spare.** Capacity comes from
      the room's own declaration, so a two-door authored shell is never
      a junction and a four-socket procedural room can hold two
      branches. Nothing invents an opening. A real cost.
    """
    notes: list[str] = []
    order = [c.id for c in chambers]
    # A LEAF IS NOT A CHOICE. A room that declares no `exit` can only be
    # a destination, so it is placed before anything the budget picks and
    # it does not spend the budget: refusing to branch would leave it
    # with every opening sealed.
    must = [c for c in chambers if c.id in {r.id for r in required}]
    if len(chambers) < MIN_SPINE + 1 and not must:
        return [], ("no branch: %d rooms, a spine of %d needs every one"
                    % (len(chambers), MIN_SPINE),)

    # A destination has to be worth going to. An empty room that happens
    # to branch is a corridor with a lock on it.
    def worthwhile(c) -> bool:
        return bool(getattr(c, "reward_ids", ()) or getattr(c, "keys", ()))

    interior = [c for c in chambers[1:-1]]
    spare = max(0, len(chambers) - MIN_SPINE)
    budget = int(spare * SPINE_SHARE)
    # WHAT THE ZONE SCHEMA ALREADY ALLOWS, which is not tuning: a Zone
    # over either bound is refused by `accept_zone`, so a producer that
    # exceeds one here is producing something that cannot be accepted.
    # Each branch costs one plug. Its edge cost is ONE: the vault in and
    # the return are two new edges, but the room it moved off the spine
    # took a spine edge with it.
    by_plugs = _zone_limit("plugs")
    by_edges = max(0, _zone_limit("edges") - (len(chambers) - 1))
    affordable = min(budget, by_plugs, by_edges)
    if affordable < budget:
        notes.append(
            "branch budget %d cut to %d by the Zone schema: at most %d "
            "plugs and %d edges" % (budget, affordable, by_plugs,
                                    _zone_limit("edges")))
    if not affordable:
        return [], tuple(notes) + (
            "no branch: %d rooms leaves %d spare over a spine of %d, and a "
            "branch costs a room" % (len(chambers), spare, MIN_SPINE),)
    # FROM THE FAR END. Taking the earliest worthwhile rooms put every
    # junction near the entrance, which left nowhere ahead of it to put
    # the key — every key landed in the room the player spawns in, where
    # "is this key reachable before its lock" has no content. Branching
    # off the later spine leaves the early rooms to hold keys.
    # BARRED HOSTS ARE NOT CHOSEN, and this is the only thing that
    # keeps a Zone whose engine cannot stand a return in one room. A
    # destination is a dead end and a dead end takes a return device;
    # `layout.validate` names the rooms the engine measured and could
    # not stand one in, and they stop being offered a branch. Not a room
    # TYPE and not "it has a pit": these are the rooms the engine
    # actually refused, by name.
    barred_ids = set(barred)
    eligible = [c for c in interior
                if worthwhile(c) and c.id not in barred_ids]
    chosen = eligible[-affordable:]
    #: Worthwhile rooms the budget did not pick, far end first — the same
    #: preference `chosen` applies.
    #:
    #: A DESTINATION THAT CAN FIND NO JUNCTION IS REPLACED, NOT DROPPED.
    #: Which rooms are worth going to and which rooms can hold a doorway
    #: are different facts, and the budget was spent on the first without
    #: consulting the second: a destination whose every predecessor was
    #: full simply fell back onto the spine and the Zone came back with
    #: fewer branches than it could carry. Measured when `platform_path`
    #: stopped advertising side doorways it cannot hold — barring one
    #: room then cost a 23-room Zone up to five of its eight branches,
    #: none of them for want of a worthwhile room to go to.
    #:
    #: This spends no more budget: a replacement takes the failed
    #: destination's place, never an extra one.
    reserve = list(reversed(eligible[:max(0, len(eligible) - affordable)]))
    # Required leaves first, then the budget's picks, in Zone order so
    # the junction search below still walks backwards from each.
    taken_ids = {c.id for c in must}
    destinations = [c for c in chambers
                    if c.id in taken_ids
                    or c.id in {d.id for d in chosen} - taken_ids]
    if not destinations:
        # THE CHAIN, INTACT. Affording a branch is not a reason to make
        # one: a detour to an empty room is a lock the player opens to
        # find nothing. The note says which of the three costs was not
        # met, and this one is "nowhere worth going" rather than "not
        # enough rooms" — a different fact, and the two were once
        # reported by the same sentence.
        return [], tuple(notes) + (
            "no branch: %d interior room(s), room for %d, none carrying a "
            "Check or a key" % (len(interior), affordable),)

    # Junctions are chosen from what STAYS on the spine, so a room can
    # be a junction or a destination and never both.
    taken = {c.id for c in destinations}
    used: dict[str, set[str]] = {c.id: set(SPINE_SOCKETS) for c in chambers}
    #: How far off the spine each room sits. A spine room is 0; a branch
    #: destination is one further than its junction. Read by the
    #: candidate filter below, which applies `MAX_SIDE_DEPTH` — a dial,
    #: not a judgement about which shapes a Zone may have.
    depth: dict[str, int] = {c.id: 0 for c in chambers}
    routes: list[BranchRoute] = []

    #: Zone order, so each junction search still walks backwards from its
    #: destination. Replacements re-enter here and are re-sorted.
    pending = sorted(destinations, key=lambda c: order.index(c.id))
    required_ids = {c.id for c in must}

    def _replace(failed) -> bool:
        """Swap a destination that found no junction for one that might.

        A required leaf is never swapped: it declares no `exit`, so
        refusing to branch it leaves it with every opening sealed. That
        is a composition refusal for `compose_with_branch` to raise, not
        a branch to quietly move elsewhere.
        """
        if failed.id in required_ids:
            return False
        taken.discard(failed.id)
        while reserve:
            nxt = reserve.pop(0)
            if nxt.id in taken or nxt.id in {r.destination.id
                                             for r in routes}:
                continue
            taken.add(nxt.id)
            pending.append(nxt)
            pending.sort(key=lambda c: order.index(c.id))
            notes.append("room '%s' takes the branch room '%s' could not"
                         % (nxt.id, failed.id))
            return True
        return False

    while pending:
        destination = pending.pop(0)
        # NESTING: a junction may be a room already reached by a branch,
        # which is what makes a branch off a branch possible at all.
        # Ordered by position so the choice is stable, and restricted to
        # rooms the player reaches BEFORE the destination on the spine.
        reached = [c for c in chambers
                   if c.id not in taken or c.id in
                   {r.destination.id for r in routes}]
        candidates = [
            c for c in reached
            if order.index(c.id) < order.index(destination.id)
            and c.id != chambers[-1].id
            # NOT THE ROOM THE PLAYER ARRIVES IN. It has capacity — the
            # entry socket is the Zone's front door and its sides are
            # free — and a lock on it has nowhere its key could go but
            # the room the lock is in, which is a door and a key you
            # pick up in one breath. Found by a Zone of two-door
            # authored rooms branching anyway, off c001.
            and c.id != chambers[0].id
            and depth[c.id] < MAX_SIDE_DEPTH
            and _spare_sockets(c, caps, used[c.id])]
        if not candidates:
            notes.append("room '%s' stays on the spine: no room before "
                         "it has a socket to spare within %d of the spine"
                         % (destination.id, MAX_SIDE_DEPTH))
            _replace(destination)
            continue

        # THE NEAREST ROOM BEFORE IT, WALKING BACK. Nearest first is what
        # makes nesting happen where the shape already supports it: when
        # the previous destination sits immediately before this one and
        # still has a socket spare, the branch hangs off the branch.
        # Preferring the middle candidate instead produced zero nested
        # branches at every Zone size, because a spine room almost always
        # won.
        #
        # WALKING BACK matters as much. This used to take the nearest
        # candidate and give up on the whole destination if that one room
        # had only its elevated wall spare — so one procedural room with
        # a deck against its free side cost a 23-room Zone six of its
        # eight branches, every refusal naming the same junction. A
        # junction that cannot serve is a reason to ask the next room,
        # not a reason to stop.
        junction = socket = None
        for candidate in reversed(candidates):
            choice = _side_socket(candidate, _spare_sockets(
                candidate, caps, used[candidate.id]))
            if choice is not None:
                junction, socket = candidate, choice
                break
        if junction is None:
            notes.append("room '%s' stays on the spine: all %d room(s) "
                         "before it have only an elevated wall spare"
                         % (destination.id, len(candidates)))
            _replace(destination)
            continue
        used[junction.id].add(socket)
        depth[destination.id] = depth[junction.id] + 1
        routes.append(BranchRoute(junction.id, destination, socket))
    if not routes:
        notes.append("no branch: no junction had capacity")
    return routes, tuple(notes)


def _spine_of(chambers, routes) -> list[str]:
    """The rooms the chain still passes through, in order."""
    moved = {r.destination.id for r in routes}
    return [c.id for c in chambers if c.id not in moved]


def _key_homes(route, routes, spine: list[str]) -> list[str]:
    """Where this route's key may sit: the spine BEFORE its junction.

    For a NESTED junction — one that is itself a branch destination —
    that means the spine before its parent, walked up until a spine room
    is found. Anything later is a key behind the lock it opens, which
    `R ⊆ E` would catch and which should never be composed in the first
    place.

    The room the player arrives in is excluded. A key lying at the
    player's feet on the first frame is a lock that was never closed,
    and it makes "is this key reachable before its lock" a question with
    no content — the first room is reachable by definition. An empty
    result therefore means *this route cannot carry a lock*, which is
    now a reason to leave it open rather than a reason to put the key
    underfoot anyway.
    """
    parent_of = {r.destination.id: r.junction_id for r in routes}
    anchor, seen = route.junction_id, set()
    while anchor not in spine and anchor not in seen:
        seen.add(anchor)
        anchor = parent_of.get(anchor, spine[0])
    reach = list(spine[:spine.index(anchor)]) if anchor in spine else []
    return reach[1:]


def _lock_routes(chambers, routes) -> tuple[list[BranchRoute], tuple[str, ...]]:
    """Which of the existing routes receive a local lock.

    **A separate decision from whether the route exists.** A route is
    lockable when its key has somewhere to go that is not the room the
    player spawns in; the rest stay open, and an open branch to a room
    with a Check in it is still a choice about where to go.

    Two things bound the count, and only the first is a law:

    * **One colour, one lock.** `BRANCH_COLOURS` is the presentation
      vocabulary, so a Zone holds at most that many locks. A fifth lock
      would have to reuse a colour, and two red doors opened by
      different keys read as one lock and behave as two.
    * **Which lockable routes get the colours** is *provisional tuning*:
      the latest along the spine, so the Zone opens up before it asks
      the player to go looking, and so each lock has the widest choice
      of where its key sits. Stated here rather than implied by an
      index, because it is the kind of rule that turns into a template
      nobody remembers choosing.
    """
    notes: list[str] = []
    spine = _spine_of(chambers, routes)
    lockable = [r for r in routes if _key_homes(r, routes, spine)]
    order = [c.id for c in chambers]

    def depth(route) -> int:
        return order.index(route.destination.id)

    chosen = {id(r) for r in
              sorted(lockable, key=depth)[-len(BRANCH_COLOURS):]}
    out, colours = [], iter(BRANCH_COLOURS)
    for route in routes:
        if id(route) not in chosen:
            out.append(route)
            continue
        colour = next(colours)
        # ONE SPELLING, NOT TWO NAMES FOR ONE FACT: with at most one
        # lock per colour in a Zone, the colour IS the identity, and a
        # second independent identifier would be a thing that could
        # disagree with it. `BranchLock` keeps them separate fields
        # because the runtime matches one and the player reads the
        # other — not because they may differ.
        out.append(BranchRoute(route.junction_id, route.destination,
                               route.socket, BranchLock(colour, colour)))
    locked = sum(1 for r in out if r.locked)
    if locked < len(routes):
        notes.append(
            "%d of %d branch(es) locked; %d stay open (%d had nowhere to "
            "put a key before the lock, %d beyond the %d key colours)"
            % (locked, len(routes), len(routes) - locked,
               len(routes) - len(lockable),
               max(0, len(lockable) - len(BRANCH_COLOURS)),
               len(BRANCH_COLOURS)))
    return out, tuple(notes)


def _refused(refusal: GraphRefusal, notes: tuple[str, ...] = ()
             ) -> GraphProduct:
    """A composition that did not happen.

    **Carries no doors.** The refusal paths used to seal every socket and
    return that, which is a Zone with door assignments and no edges — a
    shape the `Zone` schema refuses, but only later, when `accept_zone`
    rebuilds the record, as a pydantic error out of a background task.
    Half-built output is what let the failure travel as far as it did;
    there is nothing here to mistake for a product.
    """
    return GraphProduct(edges=(), doors={}, keys={}, plugs=(),
                        notes=notes + (f"refused ({refusal.code}): "
                                       f"{refusal.detail}",),
                        refusal=refusal)


def compose_with_branch(chambers, shell_sockets=None,
                        barred=()) -> GraphProduct:
    """The chain, with every room a junction can afford moved onto a
    branch off it — locked where a lock has a key to go with it.

    **Capacity decides, not authorship.** This used to consider only
    procedural rooms wide enough for a side door, because authored
    shells were assumed to be two-door. A room is a junction candidate
    when its own declared sockets leave one spare — so the day a
    three-door shell is authored it becomes usable without a line
    changing here, and until then a Zone of authored rooms composes as a
    chain and SAYS SO in its notes rather than branching silently.

    **Three decisions, three stages.** `_branch_routes` says which
    routes exist; `_lock_routes` says which of them are locked;
    `BranchLock` says how a lock and its key are identified and
    presented. They were one loop, and the join made the branch count a
    consequence of the colour vocabulary.

    Returns the plain chain unchanged when nothing can be afforded, with
    a note naming which cost was not met.
    """
    caps = _shell_sockets() if shell_sockets is None else shell_sockets

    # ROLES FIRST, and this is the repair. `compose_chain` requires an
    # entry/exit pair from EVERY room, so calling it here as a
    # feasibility gate refused a leaf-compatible room as a through-room
    # before it could be chosen as a leaf — and the Zone came back with
    # no edges at all, every one of that room's openings SEALED, and
    # only a note to say so. A room whose declared role is "destination"
    # must not be asked for a departure first.
    roles = _roles(chambers, caps)
    blocked = _role_refusal(chambers, roles)
    if blocked is not None:
        return _refused(blocked)
    leaves = [c for c in chambers if roles[c.id] == ROLE_LEAF]

    if not leaves:
        base = compose_chain(chambers, caps)
        if not base.edges:
            return base
    else:
        # A Zone carrying a leaf has no plain-chain fallback: the chain
        # cannot pass through it. `compose_chain` is not consulted, and
        # its notes are replaced by one that says what this Zone is.
        base = GraphProduct(
            edges=(), doors={}, keys={}, plugs=(),
            notes=("chain: %d rooms, %d of them destinations that carry "
                   "no departure" % (len(chambers), len(leaves)),))

    # A BARRED LEAF IS STILL REQUIRED. A room that declares no `exit`
    # can only be a destination, so barring it does not make it a
    # through-room — it makes the Zone uncomposable, and that is the
    # refusal it already has rather than a silently dropped return.
    # A BARRED LEAF IS A REFUSAL, NOT A FILTER. `_branch_routes` drops
    # barred rooms from the destinations it CHOOSES and then adds the
    # required leaves separately, so a barred leaf sailed straight past
    # the bar and was assigned anyway. A room that declares no `exit`
    # can only be a destination, so barring it does not make it a
    # through-room — it makes the Zone uncomposable, and that is the
    # honest answer rather than reassigning the same host, dropping its
    # return, or inventing a departure.
    grounded = [c.id for c in leaves if c.id in set(barred)]
    if grounded:
        return _refused(GraphRefusal(
            "destination_unhostable",
            "room(s) %s can only be destinations — they declare no "
            "`exit` — and the engine found nowhere in them to stand the "
            "return this Zone requires" % grounded,
            tuple(grounded)))
    routes, why = _branch_routes(chambers, caps, required=leaves,
                                 barred=barred)
    unplaced = [c.id for c in leaves
                if c.id not in {r.destination.id for r in routes}]
    if unplaced:
        # REFUSED, never linearised. A leaf with no branch is a room the
        # chain cannot reach and cannot pass through, and composing the
        # Zone without it would seal it shut in silence.
        return _refused(GraphRefusal(
            "destination_unreachable",
            "destination room(s) %s declare no `exit` and no room before "
            "them had a socket to spare; the chain cannot reach them and "
            "cannot pass through them" % unplaced,
            tuple(unplaced)), notes=why)
    if not routes:
        return GraphProduct(
            *(base.edges, base.doors, base.keys, base.plugs),
            notes=base.notes + why)
    routes, lock_notes = _lock_routes(chambers, routes)
    why = why + lock_notes

    moved = {r.destination.id for r in routes}
    spine = _spine_of(chambers, routes)

    edges: list[TopologyEdge] = []
    doors: dict[str, dict[str, DoorAssignment]] = {c.id: {} for c in chambers}
    # §11.2. THE CHAIN through each room, as a pointer into the door
    # assignment below rather than as a second account of it.
    arrivals: dict[str, str] = {}
    departures: dict[str, str] = {}
    onward: dict[str, list[str]] = {}
    for a_id, b_id in zip(spine, spine[1:]):
        edge = TopologyEdge(
            edge_id=f"e:{a_id}:{b_id}", room_a=a_id, room_b=b_id,
            direction="BIDIRECTIONAL", realization="JOINED")
        edges.append(edge)
        doors[a_id]["exit"] = DoorAssignment(
            socket_id="exit", usage="USED", edge_id=edge.edge_id)
        doors[b_id]["entry"] = DoorAssignment(
            socket_id="entry", usage="USED", edge_id=edge.edge_id)
        departures[a_id] = edge.edge_id
        arrivals[b_id] = edge.edge_id

    plugs: list[PlugAssignment] = []
    keys: dict[str, tuple[ZoneKeySpec, ...]] = {}
    placed = 0
    for route in routes:
        destination = route.destination
        vault = TopologyEdge(
            edge_id=f"e:{route.junction_id}:{destination.id}",
            room_a=route.junction_id, room_b=destination.id,
            direction="BIDIRECTIONAL", realization="JOINED")
        edges.append(vault)
        # THE ONE PLACE THE LOCK DECISION IS READ. An open branch is a
        # USED door: the same edge, the same socket, the same way back,
        # and no key errand attached to it.
        doors[route.junction_id][route.socket] = DoorAssignment(
            socket_id=route.socket,
            usage="LOCKED" if route.locked else "USED",
            edge_id=vault.edge_id,
            key_id=route.lock.key_id if route.locked else None,
            colour=route.lock.colour if route.locked else None)
        doors[destination.id]["entry"] = DoorAssignment(
            socket_id="entry", usage="USED", edge_id=vault.edge_id)
        # The destination arrives by the vault. The JUNCTION does not
        # depart by it: a junction on the spine departs by the spine, and
        # a branch mouth is placed by the engine's own socket table
        # (§11.4), not by `_exit_offset`.
        arrivals[destination.id] = vault.edge_id
        onward.setdefault(route.junction_id, []).append(vault.edge_id)

        # The way back. A dead end that can only be left the way you came
        # is a dead end; one that carries a return is a place you chose
        # to visit. TRAVERSAL_ONLY, so it spends no socket and the room
        # keeps its JOINED degree of 1.
        #
        # IT STANDS AT `:return`, NOT AT `:arrival`. This named the
        # arrival, which is exactly where `zone_builder` puts a body
        # entering the room — so the plug's trigger volume was centred
        # on the player the instant they walked in and sent them home
        # before they could use the branch. The device was correct, the
        # edge was correct, and the anchor was the place the player is
        # standing. Found by the engine lane in the integrated build.
        #
        # The composer still names only an ANCHOR. Where `:return` is,
        # and how much clearance it has, is the engine's answer — see
        # `ROOM_ANCHOR_KINDS` and `layout.validate` rule 4b.
        plug_edge = TopologyEdge(
            edge_id=f"p:{destination.id}:start", room_a=destination.id,
            room_b=spine[0], direction="A_TO_B",
            realization="TRAVERSAL_ONLY")
        edges.append(plug_edge)
        plugs.append(PlugAssignment(
            edge_id=plug_edge.edge_id, room_id=destination.id,
            source_anchor=f"room:{destination.id}:return",
            destination="zone_start", device="pad"))

        if not route.locked:
            continue
        # The key goes in a room the player passes BEFORE the junction,
        # which is the ordering `R ⊆ E` then proves rather than assumes.
        # `_key_homes` is the same function `_lock_routes` used to decide
        # this route could be locked at all, so "there is a home for the
        # key" and "here is the home" cannot disagree.
        # Spread, not stacked: four keys in one room is four locks with
        # one errand. Deterministic, so two runs place them the same.
        homes = _key_homes(route, routes, spine)
        holder = homes[placed % len(homes)]
        placed += 1
        keys[holder] = keys.get(holder, ()) + (
            ZoneKeySpec(key_id=route.lock.key_id, colour=route.lock.colour),)

    # A NESTED junction has no spine to depart by, so its one onward
    # vault is the chain's continuation through it. With two children
    # there is no single continuation and the engine's documented
    # fallback is the honest answer — better an unset field than a
    # selector that picks one of two arbitrarily.
    for room_id, out_edges in onward.items():
        if room_id not in departures and len(out_edges) == 1:
            departures[room_id] = out_edges[0]

    nested = sum(1 for r in routes if r.junction_id in moved)
    # THE SPINE'S LAST ROOM, and only it. A branch destination is a dead
    # end with a plug, not the Zone's way out, and its sealed faces stay
    # sealed.
    way_out = _reserve_the_zone_exit(chambers, doors, spine, caps)
    return GraphProduct(
        edges=tuple(edges),
        doors={c.id: _seal_the_rest(c, doors[c.id], caps) for c in chambers},
        keys=keys, plugs=tuple(plugs),
        arrivals=arrivals, departures=departures,
        notes=base.notes + why + (
            "branches: %d off %d junction(s), %d nested, %d locked; "
            "spine %d rooms"
            % (len(routes), len({r.junction_id for r in routes}), nested,
               sum(1 for r in routes if r.locked), len(spine)),
            "zone exit: room '%s'" % way_out if way_out
            else "zone exit: no room on the spine declares an 'exit' "
                 "socket to leave through"))


def _refuse_doors_beyond_capacity(zone, product: GraphProduct) -> None:
    """No door this composer assigns may name a socket the room cannot
    carry.

    True by construction — every assignment comes from `_sockets_for` —
    and asserted anyway, because "true by construction" is what the flat
    socket table was for years while `platform_path` raised a solid wall
    where `side_left` was supposed to be. An authored shell is held to
    its OWN declarations, not to a procedural producer's limits.

    A `ValueError`, not a `GraphRefusal`: a refusal is an answer about a
    Zone, and this is a statement about this module. If it ever fires,
    the composer and the builder have drifted apart again and the right
    outcome is a stack trace rather than a recomposition that hides it.
    """
    for c in zone.chambers:
        if c.shell_id:
            # AN AUTHORED SHELL ANSWERS FOR ITSELF. Its openings are in
            # its catalogue entry, `_sockets_for` reads them there, and
            # holding it to a procedural producer's limits because it
            # shares a chamber type is the mistake this guard exists to
            # prevent in the other direction.
            continue
        supported = set(procedural_sockets_for(c.type))
        for door in product.doors.get(c.id, ()):
            if door.usage == "SEALED" or door.socket_id in supported:
                continue
            raise ValueError(
                f"composer assigned '{door.socket_id}' ({door.usage}) in "
                f"room '{c.id}', which carries {sorted(supported)}; a "
                "door on a socket the producer does not build is a hole "
                "the engine will measure as solid")


def apply(zone, product: GraphProduct):
    """Return `zone` carrying `product`. The input is never mutated."""
    _refuse_doors_beyond_capacity(zone, product)
    chambers = []
    for c in zone.chambers:
        chambers.append(c.model_copy(update={
            "doors": product.doors.get(c.id, ()),
            "keys": product.keys.get(c.id, ()),
            "arrive_edge": product.arrivals.get(c.id),
            "depart_edge": product.departures.get(c.id),
        }))
    return zone.model_copy(update={
        "chambers": tuple(chambers),
        "edges": product.edges,
        "plugs": product.plugs,
    })

# --------------------------------------------------------------------------
# Reachability — the logical half, and only the logical half.
# --------------------------------------------------------------------------
#
# `R ⊆ E` is a GRAPH property over edges the bridge believes exist. It
# cannot see that a key stands inside a crate, on a ledge with no ramp, or
# behind a trim lip. **It is necessary and it is not sufficient**, and a
# previous revision of the contract treated it as both. Physical
# reachability is the engine's to define and prove; this module states
# the logical obligation and nothing more.
#
# **ONE EXPLORATION, AND IT KNOWS WHAT THE PLAYER HAS.** A previous
# version asked about capability gates by removing one edge at a time
# while leaving every other gate passable, so two undeclared gates each
# validated the other: remove the grapple route and the blink shortcut
# covers it, remove the blink shortcut and the grapple route covers it,
# and a Zone whose exit needs one of two things nobody has passed. Gates
# the player cannot use are unavailable TOGETHER or the question is not
# being asked.


@dataclass(frozen=True)
class Reach:
    """What a graph search can establish, and the errors it found."""

    #: Every `(room, keys)` the player can get into.
    states: frozenset[tuple[str, frozenset[str]]]
    #: Every room appearing in any reachable state.
    rooms: frozenset[str]
    errors: tuple[str, ...] = ()

    @property
    def ok(self) -> bool:
        return not self.errors


def guaranteed_capabilities(declared=None) -> frozenset[str]:
    """What a player is certain to have on an AP-relevant route.

    `BASELINE_CAPABILITIES` is the existing guarantee: Static Pulse is
    permanent, so `ranged_hit` needs no Archipelago progression logic
    behind it and an edge requiring it is not a gate at all. Anything
    Archipelago declares as a prerequisite joins it.
    """
    return frozenset(M.BASELINE_CAPABILITIES) | frozenset(declared or ())


def _door_on(doors_by_room, room: str, edge_id: str):
    for d in doors_by_room.get(room, ()):
        if d.edge_id == edge_id:
            return d
    return None


def _passable(edge, frm: str, held: frozenset[str], doors_by_room,
              ignore_keys: frozenset[str], have: frozenset[str]) -> bool:
    """Can the player cross `edge` from `frm`, holding `held` and `have`?

    `ignore_keys` names keys treated as never held, which is how "is this
    key obtainable without passing its own lock" is asked.

    `have` is the capability set the question is being asked under. An
    edge requiring something outside it is impassable — not skipped, not
    assumed, impassable — which is what makes two undeclared gates fail
    together instead of covering for each other.
    """
    if not edge.traversable(frm):
        return False
    if edge.capability and edge.capability not in have:
        return False
    if edge.realization == "TRAVERSAL_ONLY":
        return True          # a plug binds no geometry and carries no lock
    for side in edge.rooms:
        door = _door_on(doors_by_room, side, edge.edge_id)
        if door is None:
            return False     # an edge with no door is not a way through
        if door.usage == "SEALED":
            return False
        if door.usage == "LOCKED":
            key = door.key_id
            if key in ignore_keys or key not in held:
                return False
    return True


def _explore(start: str, edges, doors_by_room, keys_by_room,
             have: frozenset[str],
             ignore_keys: frozenset[str] = frozenset(),
             start_held: frozenset[str] = frozenset()) -> Reach:
    """Every `(room, keys)` reachable from `start`, under `have`.

    One function for both questions a search here ever asks — from the
    entrance empty-handed, and from a room mid-run with keys already in
    hand — because two of them drifted apart once already.
    """
    incident: dict[str, list] = {}
    for e in edges:
        incident.setdefault(e.room_a, []).append(e)
        incident.setdefault(e.room_b, []).append(e)

    def collect(room: str, held: frozenset[str]) -> frozenset[str]:
        got = {k.key_id for k in keys_by_room.get(room, ())}
        return held | (got - ignore_keys)

    first = (start, collect(start, start_held))
    seen = {first}
    queue = [first]
    while queue:
        room, held = queue.pop()
        for e in incident.get(room, ()):
            if not _passable(e, room, held, doors_by_room, ignore_keys,
                             have):
                continue
            nxt_room = e.other(room)
            nxt = (nxt_room, collect(nxt_room, held))
            if nxt not in seen:
                seen.add(nxt)
                queue.append(nxt)
    return Reach(states=frozenset(seen),
                 rooms=frozenset(r for r, _ in seen))


def _key_graph_is_acyclic(zone, doors_by_room, keys_by_room,
                          have: frozenset[str]) -> list[str]:
    """SOLUTIONS_CATALOGUE §2 rule 2, asked directly.

    A key behind its own lock is caught by rule 1. A CHAIN is not the
    same shape: red behind the blue door and blue behind the red one
    leaves both rooms unreachable, and a search that only ever withholds
    one key at a time reports that as two unrelated failures rather than
    as the cycle it is.

    The graph here is `key -> the keys you must already hold to fetch
    it`, and a cycle in it is a Zone nobody can open.
    """
    where = {k.key_id: c.id for c in zone.chambers for k in c.keys}
    if len(where) < 2:
        return []          # one key cannot form a chain with itself
    entry = zone.chambers[0].id

    needs: dict[str, set[str]] = {}
    for key_id, room in where.items():
        blocking = set()
        for other in where:
            if other == key_id:
                continue
            got = _explore(entry, zone.edges, doors_by_room, keys_by_room,
                           have, ignore_keys=frozenset({other}))
            if room not in got.rooms:
                blocking.add(other)
        needs[key_id] = blocking

    out: list[str] = []
    seen: set[str] = set()
    for start in sorted(needs):
        stack = [(start, [start])]
        while stack:
            at, path = stack.pop()
            for nxt in sorted(needs.get(at, ())):
                if nxt == start:
                    loop = " -> ".join(path + [start])
                    if start not in seen:
                        seen.update(path)
                        out.append(
                            f"the key graph has a cycle: {loop}; no order "
                            "of collection opens it")
                elif nxt not in path:
                    stack.append((nxt, path + [nxt]))
    return out



def _escapable(real: Reach, ways_out: frozenset[str], edges, doors_by_room,
               keys_by_room, have: frozenset[str]) -> tuple[str, ...]:
    """SOLUTIONS_CATALOGUE §0-bis condition 4, and **it never changes the
    verdict**. It says which KIND of failure a refused Zone has.

    **The correction.** An earlier version of this docstring, and the
    write-up that went with it, said condition 4 "had no rule" and that
    a one-way edge into a dead end "satisfied every check". Both were
    false, and the mistake is worth keeping written down because it is
    not a detail — it is a claim about what a new check bought, made
    without checking what the old ones already caught.

    `R ⊆ E` asks, of every reachable state, whether `exit ∈ onward`.
    This asks whether `{entry, exit} ∩ onward` is non-empty. The first
    condition IMPLIES the second, so **no Zone exists that this refuses
    and `R ⊆ E` accepts** — it is subsumed, by construction, not by
    coincidence. The fixture offered as proof was worse than redundant:
    it deleted two spine edges, so the exit was not merely unreachable
    from the trapped room, it was unreachable from anywhere, and three
    other rules fired first.

    **What it actually adds**, which is real and is why it stays: among
    the states `R ⊆ E` already refuses, it separates the two that matter
    to a player. "You cannot finish from here, and you can walk back to
    the entrance" is §0-bis's *NOT YET is good gameplay* — leave, find
    the capability, return. "You cannot finish and you cannot get back"
    is the dead run the catalogue warns about. `R ⊆ E` reports both with
    one sentence.

    **And it is a backstop.** §0-bis explicitly permits the Zone exit
    itself to sit behind a capability gate. The day `R ⊆ E` is relaxed
    to model a player who does not hold the item yet, this stops being
    subsumed and becomes the only thing between that player and a Zone
    they cannot leave. Deleting it now would delete the guard exactly
    when it is cheapest to keep.
    """
    trapped: dict[str, frozenset[str]] = {}
    memo: dict[tuple[str, frozenset[str]], bool] = {}
    for room, held in sorted(real.states, key=lambda st: (st[0], sorted(st[1]))):
        if room in ways_out:
            continue
        key = (room, held)
        if key not in memo:
            back = _explore(room, edges, doors_by_room, keys_by_room, have,
                            start_held=held)
            memo[key] = bool(back.rooms & ways_out)
        if not memo[key] and room not in trapped:
            trapped[room] = held
    if not trapped:
        return ()
    named = ", ".join(
        f"'{room}'" + (f" holding {sorted(held)}" if held else "")
        for room, held in sorted(trapped.items()))
    return (
        f"room(s) {named} can be entered and not left: no way back to "
        f"{sorted(ways_out)} from there. A capability gate the player "
        "cannot retreat past is not hard progression (§0-bis condition "
        "4); it is a Zone holding its Checks with the player stuck "
        "inside it",)

def reachability(zone, entry_id: str | None = None,
                 exit_id: str | None = None,
                 declared_capabilities=None) -> Reach:
    """Prove you can get around this Zone, or say exactly why not.

    Five properties, each an outcome rather than a method:

    1. **The exit is reachable**, with what the player is guaranteed.
    2. **`R ⊆ E`** — from every state the player can get into, the exit
       is still reachable. This is what rejects a Zone that strands.
    3. **Every allocated Check sits in a reachable room.**
    4. **Every key is obtainable without passing its own lock**, and the
       key graph is acyclic.
    4b. **Every room can be left again** — from any state the player can
       reach, the entrance or the exit is still reachable
       (SOLUTIONS_CATALOGUE §0-bis condition 4). A gate is allowed to
       stop you; it is not allowed to keep you.
    5. **Every capability gate on the way to any of the above is
       declared** in the matching Archipelago logic
       (SOLUTIONS_CATALOGUE §2 rule 3, `06` §29.5a, check 23).

    The fifth is not a separate pass. Everything above is searched with
    the capability set the player actually has, so an undeclared gate
    shows up as the thing it causes: an unreachable exit, a stranded
    Check, a key nobody can fetch. The diagnosis then says whether a gate
    was the reason, by asking the same question again with every gate
    open and reporting the difference.

    A Zone with no edges is the chain its list order describes and
    trivially satisfies all five; it is not searched.
    """
    if not zone.edges:
        return Reach(states=frozenset(), rooms=frozenset())

    chambers = list(zone.chambers)
    entry = entry_id or chambers[0].id
    exit_room = exit_id or chambers[-1].id
    doors_by_room = {c.id: c.doors for c in chambers}
    keys_by_room = {c.id: c.keys for c in chambers}

    have = guaranteed_capabilities(declared_capabilities)
    every = have | {e.capability for e in zone.edges if e.capability}
    undeclared = sorted(every - have)

    errors: list[str] = []
    real = _explore(entry, zone.edges, doors_by_room, keys_by_room, have)
    ideal = (real if not undeclared else
             _explore(entry, zone.edges, doors_by_room, keys_by_room,
                      every))

    def blame(what: str, rooms_needed) -> None:
        """Say what is unreachable, and whether a gate is why."""
        stranded = sorted(set(rooms_needed) - real.rooms)
        if not stranded:
            return
        by_gate = sorted(set(stranded) & ideal.rooms)
        if by_gate:
            errors.append(
                f"{what} {by_gate} are reachable only through capability "
                f"gate(s) {undeclared}, which the Archipelago logic does "
                "not declare; the physical graph and the logical graph "
                "would disagree about what is reachable")
        rest = sorted(set(stranded) - set(by_gate))
        if rest:
            errors.append(f"{what} {rest} are not reachable at all")

    blame("the exit", [exit_room])
    blame("Check-bearing room(s)",
          [c.id for c in chambers if c.reward_ids])
    blame("key-bearing room(s)", [c.id for c in chambers if c.keys])

    # §0-bis CONDITION 4. The catalogue calls this load-bearing and
    # nothing was enforcing it: every rule above asks whether the player
    # can get somewhere, and none asks whether they can get back. Both
    # the way in and the way out count as a way out — leaving by
    # finishing is still leaving.
    errors.extend(_escapable(real, frozenset({entry, exit_room}),
                             zone.edges, doors_by_room, keys_by_room,
                             have))

    # R subset E, over STATES rather than rooms: a room you can stand in
    # holding the wrong keys is a different situation from the same room
    # holding the right ones, and only the state form catches it.
    stranded = []
    for room, held in sorted(real.states):
        if room == exit_room:
            continue
        onward = _explore(room, zone.edges, doors_by_room, keys_by_room,
                          have, start_held=held)
        if exit_room not in onward.rooms:
            stranded.append(f"{room} holding {sorted(held) or 'nothing'}")
    if stranded:
        errors.append(
            "R is not a subset of E; the exit is unreachable from: "
            + "; ".join(stranded[:4])
            + (f" (+{len(stranded) - 4} more)" if len(stranded) > 4 else ""))

    for c in chambers:
        for k in c.keys:
            # THE CIRCULAR CASE, ASKED DIRECTLY. Withhold the key and see
            # whether its own room still comes up; grant it for free and
            # see whether that is what unlocks it. A key you can only
            # fetch by already holding it is the defect, and it is a
            # different fault from a room nothing reaches.
            without = _explore(entry, zone.edges, doors_by_room,
                               keys_by_room, have,
                               ignore_keys=frozenset({k.key_id}))
            if c.id in without.rooms:
                continue
            granted = _explore(entry, zone.edges, doors_by_room,
                               keys_by_room, have,
                               start_held=frozenset({k.key_id}))
            if c.id in granted.rooms:
                errors.append(
                    f"key '{k.key_id}' is behind a lock only it opens; "
                    f"room '{c.id}' is reachable holding it and not "
                    "reachable without it")

    errors.extend(_key_graph_is_acyclic(zone, doors_by_room, keys_by_room,
                                        have))
    return Reach(states=real.states, rooms=real.rooms,
                 errors=tuple(errors))
