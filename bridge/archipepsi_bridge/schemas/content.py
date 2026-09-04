"""The authored-content contract (v0.9 S12).

`AUTHORED_CONTENT.md` says humans make the alphabet, Godot enforces the
grammar and Epsilon writes sentences. This module is the *dictionary* —
the list of letters that exist, what each one is, and what it needs to sit
next to. It is the thing Epsilon may name and the thing Godot may
instantiate.

Two readers, one file. The manifests live in the Godot project beside the
scenes they describe (`godot/content/registry/*.json`), which is what
makes adding an asset a matter of dropping in a scene and a manifest entry
rather than editing generator logic. Godot loads them as the physical
authority — it is the one that can check a scene actually exists and that
its collision is real. This module is the other half: it validates the
manifest's SHAPE, and it is what a provider's output is checked against,
because Epsilon's output is validated in Python long before Godot sees it.

**Epsilon references ids and tags. Never paths.** `scene` exists in the
manifest because Godot needs it; there is deliberately no path field
anywhere a provider can write, and `test_authored_boundary.py` enforces
that separately.
"""

from __future__ import annotations

import math

from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

try:
    from . import constants as C
except ImportError:  # pragma: no cover
    import constants as C


class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)


#: The five levels of `AUTHORED_CONTENT.md` §3. Stored as an int because
#: the document numbers them and a reader should not have to translate.
ContentLevel = Literal[0, 1, 2, 3, 4]

#: What a piece of content IS. The category decides which fields are
#: required, which is why it is closed rather than a free tag: a room
#: shell with no sockets is a room nothing can connect to, and that has to
#: be a validation error rather than a surprise at instantiation.
ContentCategory = Literal[
    "prop",             # L0
    "module",           # L1  architectural module
    "fixture",          # L2  composed alcove / station / perch
    "room_shell",       # L3
    "landmark",         # L4
    "connector",        # L1, but its own category: sockets on both ends
    "affordance_visual",  # L2, bound to a §13 tag
    "interactable",     # L0-L2, the repeatedly-seen objects of §2
    #: L2, a COMPOSED dressing or storytelling group that reads as one
    #: thing (art requirement 5). Its own category because it is the one
    #: that must declare a placement envelope: `PROP_FOOTPRINT` is 1.4 m,
    #: which is right for a crate and far too small for a station.
    "cluster",          # L2
    #: L0, one member of the closed projectile silhouette family (art
    #: requirement 13). Its own category rather than a prop because the
    #: id is not decorative: the engine picks it from a shot's flight
    #: fields, so a mesh registered here is answering a question the
    #: engine asked.
    "projectile_visual",  # L0
]

#: Which level each category may declare. A mismatch is a manifest that
#: has not decided what it is.
_LEVELS: dict[str, tuple[int, ...]] = {
    "prop": (0,),
    "module": (1,),
    "connector": (1,),
    "fixture": (2,),
    "affordance_visual": (2,),
    "interactable": (0, 1, 2),
    "projectile_visual": (0,),
    "room_shell": (3,),
    "landmark": (4,),
    "cluster": (2,),
}

#: Categories that must declare at least one socket, because something
#: has to be able to attach to them.
_NEEDS_SOCKETS = ("room_shell", "connector")

_ID = Annotated[str, Field(min_length=3, max_length=48,
                           pattern=r"^[a-z][a-z0-9_]*$")]
_TAG = Annotated[str, Field(min_length=2, max_length=32,
                            pattern=r"^[a-z][a-z0-9_]*$")]


#: Socket kinds that join to another socket -- the ways through. Mirrors
#: `ConnectorGrammar.JOINABLE` in GDScript.
JOINING_KINDS = ("doorway", "corridor_end")

#: Clearance beyond the player's own capsule, mirroring
#: `ConnectorGrammar.SIDE_CLEARANCE` / `HEAD_CLEARANCE`. A doorway exactly
#: one capsule wide is one the player scrapes through and, with any
#: lateral velocity, does not.
SIDE_CLEARANCE = 0.4
HEAD_CLEARANCE = 0.2

#: The narrowest and lowest opening a player can actually use. Derived
#: from the real capsule so they cannot drift from what they protect.
MIN_PASSABLE_WIDTH = C.PLAYER_RADIUS * 2.0 + SIDE_CLEARANCE
MIN_PASSABLE_HEIGHT = C.PLAYER_HEIGHT + HEAD_CLEARANCE


class Surface(Strict):
    """A patch of floor the content VOUCHES you can stand on (P1).

    The room contract's `stand` socket, in manifest form. A procedural
    builder has always known which square metres of its room hold
    weight -- it just laid them -- and until P1 an authored shell had no
    way to say the same thing, so `Activities` flat-solved against its
    bounding box. That is the defect `552469d` closed for
    `platform_path`, waiting in the one path no Zone takes yet.

    `center` is a point on the TOP FACE, which is why `extent` is two
    numbers and not three: a walkable surface has no thickness, and a
    third number here would be one somebody eventually believed.

    Godot measures it. A surface with nothing under it, a surface that
    measures at a different height, or a surface with a slab over it is
    refused by `room_audit.gd` whatever this file says.
    """
    name: _TAG
    center: tuple[float, float, float]
    #: Footprint on the floor plane, (x, z) in metres.
    extent: tuple[float, float]

    @model_validator(mode="after")
    def _you_can_actually_stand_on_it(self):
        if any(e <= 0.0 for e in self.extent):
            raise ValueError(
                f"surface '{self.name}' has extent {self.extent}; a "
                f"walkable patch with no area is not one")
        # The player has to fit. A surface narrower than the capsule is a
        # ledge nobody can be on, and declaring it invites a composer to
        # put a Check there.
        span = C.PLAYER_RADIUS * 2.0
        if self.extent[0] < span or self.extent[1] < span:
            raise ValueError(
                f"surface '{self.name}' is {self.extent[0]:.2f} x "
                f"{self.extent[1]:.2f} m; the player's own capsule is "
                f"{span:.2f} m across")
        return self


class Socket(Strict):
    """A named attachment point in the content's own local space.

    Position is metres from the content's origin and `yaw` is degrees
    about +Y, which is the convention `ART_ASSET_SPEC.md` states and the
    importer relies on. Both are here rather than inferred from the scene
    because the validator has to answer "do these two fit together"
    without loading Godot.
    """
    name: _TAG
    #: P1: `cover`, `reactive` and `enemy_high` are PROMOTED from the
    #: runtime vocabulary the procedural builders already emit
    #: (`room_contract.gd`), because an authored shell that cannot say
    #: them is a room the composer can put nothing in. Each names a
    #: consumer that runs today -- DestructibleCover, ReactiveBarrel, and
    #: the ranged-enemy placement loop -- and a kind with no consumer is
    #: a kind nobody can be held to, so nothing speculative was added
    #: alongside them.
    kind: Literal["doorway", "corridor_end", "affordance", "spawn",
                  "objective", "secret", "vista", "presentation",
                  "cover", "reactive", "enemy_high"]
    position: tuple[float, float, float]
    yaw: float = Field(default=0.0, ge=-360.0, le=360.0)
    #: Clear opening, for the two kinds that join to another socket.
    width: float = Field(default=0.0, ge=0.0, le=32.0)
    height: float = Field(default=0.0, ge=0.0, le=32.0)
    #: Which declared `Surface` this one stands on, when it stands on
    #: one. Optional, and checked by measurement rather than believed:
    #: naming a surface is how an author says "this crate is on the
    #: balcony, not on the floor under it", and the audit rays down to
    #: find out whether that is where it landed.
    surface_id: str = Field(default="", max_length=48)

    @model_validator(mode="after")
    def _joining_sockets_have_an_opening(self):
        if self.kind in JOINING_KINDS:
            if self.width <= 0.0 or self.height <= 0.0:
                raise ValueError(
                    f"socket '{self.name}' is a {self.kind} and must "
                    f"declare a width and height; two openings cannot be "
                    f"checked for fit without them")
        return self

    @model_validator(mode="after")
    def _a_way_through_is_a_way_the_player_fits_through(self):
        """The S15 grammar's half of invariant I4.

        An opening narrower than the player is not a tight corridor, it
        is a wall the generator believes is a door. The seed passes every
        other check and then cannot be finished, and it fails in a zone
        the player is already standing in. Refusing it here costs a
        manifest edit; refusing it there costs a run.

        Bounds come from the player's real capsule (`constants.py`), so
        they cannot drift from the thing they are protecting.
        """
        if self.kind not in JOINING_KINDS:
            return self
        if self.width < MIN_PASSABLE_WIDTH:
            raise ValueError(
                f"socket '{self.name}' is {self.width:.2f} m wide; the "
                f"player needs {MIN_PASSABLE_WIDTH:.2f} m to walk "
                f"through, so nothing could ever use it")
        if self.height < MIN_PASSABLE_HEIGHT:
            raise ValueError(
                f"socket '{self.name}' is {self.height:.2f} m high; the "
                f"player needs {MIN_PASSABLE_HEIGHT:.2f} m of headroom, "
                f"so nothing could ever use it")
        return self


#: The quarter turns a room's exit may make (P2-B).
#:
#: NOT an arbitrary angle. `ZoneBuilder` chains rooms on a cursor-and-yaw
#: walk whose overlap guard, connector grammar and never-revisit proof
#: are all written for 90-degree turns; a 37-degree exit is a different
#: piece of engineering and arrives with the topology slice, not with a
#: corner shell. 180 is absent on purpose -- a room that exits back the
#: way it came walks the chain into its own previous arm.
EXIT_YAWS = (-90.0, 0.0, 90.0)


#: Semantic size, the vocabulary Epsilon uses instead of metres (D1).
#: Deliberately coarse: "large" is a design intent, and the shell decides
#: what that measures. NOT a mandatory triplication rule -- a family may
#: ship one size or five.
SizeClass = Literal["small", "medium", "large"]


#: What a LARGE authored room may OFFER a movement package (P3.0).
#:
#: Closed, and short, for the reason the socket vocabulary is: a kind
#: with no consumer is a kind nobody can be held to. `grapple_anchor`,
#: `platform_route` and `wind_column` are the named next arrivals and are
#: deliberately absent -- they arrive through this same field with the
#: packages that read them, needing no new grammar.
OFFER_KINDS = ("rail_route", "launch_source", "launch_target",
               "grapple_point")


class Offer(Strict):
    """A bounded region or route a movement package MAY build in (P3.0).

    AN OFFER IS NOT AN ORDER, and that is the whole point of the field.
    A shell declaring a `rail_route` has not built a rail; it has said a
    rail could run here. A package consumes the kinds it understands,
    validates whatever it builds, and may decline every one -- the same
    shell has to play as ordinary combat space with no traversal
    mechanic in it at all.

    WHY NOT A SOCKET. A socket answers "where may a thing be PUT" and
    carries a point and a rect. A rail is an ordered PATH, and no socket
    has ever been able to hold one. Overloading them would have made
    every socket consumer read a field that means nothing to it.

    Like every other authored claim, this is a CLAIM: `RailPath` decides
    whether a declared route is a shape a rider can hold, and `RoomAudit`
    decides whether the geometry is really there.
    """
    name: _TAG
    kind: Literal["rail_route", "launch_source", "launch_target",
                  "grapple_point"]
    #: A route's ordered control points, in the shell's local space.
    #: Empty for region offers.
    points: tuple[tuple[float, float, float], ...] = Field(
        default=(), max_length=64)
    #: A region's centre, and how far the consumer may work from it.
    #:
    #: WHAT `radius` MEANS FOR A LAUNCH PAIR (owner ruling, 2026-09-03),
    #: because the two ends do NOT mean the same thing and the ambiguity
    #: cost a real defect:
    #:
    #: * `launch_source.position` is THE canonical foot-contact centre
    #:   the constructed launch fires from -- one point, not a choice of
    #:   points. `launch_source.radius` is the region RESERVED for the
    #:   consuming movement package to build its mechanism in. It is not
    #:   a disc of ballistic starting positions, so Production validates
    #:   one trajectory rather than a family of them, and what must fit
    #:   inside the reservation is the pad's own footprint. A player who
    #:   enters the trigger off-centre is captured to the canonical
    #:   origin before launch, so the flight that happens is the flight
    #:   that was validated.
    #: * `launch_target.position` is the authored foot-contact AIM and
    #:   `launch_target.radius` is the acceptable LANDING region -- the
    #:   area a player can be trusted to hit.
    #:
    #: The asymmetry is deliberate: where you leave from is exact,
    #: where you arrive is a region.
    #:
    #: BOTH POSITIONS ARE CONTACT POINTS, AND THAT IS ENFORCED AS
    #: CONTACT. "Foot-contact centre" means the point lies ON the top
    #: face of the surface beneath it, not within reach of it: Production
    #: compares the declared world height with the height its downward
    #: probe actually hits and allows only `SpaceProbe.CONTACT_EPS`
    #: (0.001 m), the on-face allowance that makes an exact contact
    #: answer the same way twice. The gate used to ask for ground within
    #: `MAX_VERTICAL_STEP` -- a metre of permitted daylight under a point
    #: this text calls contact -- and one authored pad hovered 0.5 m over
    #: its floor through every check in the project as a result. A body
    #: pose is DERIVED from the contact point; it is never the authored
    #: value.
    position: tuple[float, float, float] | None = None
    radius: float = 0.0
    #: A `grapple_point` is a PLACE, not a mechanic: the shell says
    #: reaching up and across is spatially appropriate here, and Epsilon
    #: decides whether the generated game has a hookshot, a tether, a
    #: swing, or nothing that fits. It is never required for the room to
    #: work.
    #:
    #: A `launch_source` names the `launch_target` it is aimed at. The
    #: trajectory itself is SOLVED from the two, never authored: a
    #: literal velocity would be a second authoring of the destination
    #: that stops agreeing the first time either end moves.
    target: str | None = None

    @model_validator(mode="after")
    def _a_route_is_an_ordered_path(self) -> "Offer":
        if self.kind == "rail_route":
            if len(self.points) < 2:
                raise ValueError(
                    f"offer '{self.name}' is a route and declares "
                    f"{len(self.points)} point(s); a route needs at "
                    f"least two")
        elif self.points:
            raise ValueError(
                f"offer '{self.name}' is a region and carries points; "
                f"a region is a position and a radius")
        return self

    @model_validator(mode="after")
    def _a_region_reserves_something(self) -> "Offer":
        if self.kind in ("launch_source", "launch_target",
                         "grapple_point"):
            if self.position is None:
                raise ValueError(
                    f"offer '{self.name}' is a region and has no "
                    f"position")
            if self.radius <= 0.0:
                raise ValueError(
                    f"offer '{self.name}' reserves no region")
        return self

    @model_validator(mode="after")
    def _a_launch_is_aimed_somewhere(self) -> "Offer":
        if self.kind == "launch_source" and not self.target:
            raise ValueError(
                f"offer '{self.name}' fires at nothing; a launch pad's "
                f"destination is half its contract")
        return self


class TraversalSegment(Strict):
    """One movement the player makes inside an authored shell (D1).

    The shell declares these; **Godot measures whether they are true.**
    That order matters. An art asset is not trusted because its metadata
    says it is safe -- the metadata is a claim, and `shell_validator.gd`
    instantiates the scene and checks the claim against the real markers.

    A MANDATORY segment is one on the only route through. Those are held
    to `max_safe_gap(rise)`, the same bound `platform_path.gap_size` has
    always been held to, because the reason is the same: a base-kit
    player must be able to finish, and finding out otherwise happens in a
    zone they are already standing in.

    Optional segments -- a shortcut over a rail, a perch worth an Echo --
    are free to exceed it. That is what makes them optional.
    """
    name: _TAG
    kind: Literal["gap", "rise", "drop", "walk"]
    #: On the only route through. Optional segments may be anything.
    mandatory: bool = True
    #: Endpoints in the shell's local space, so the claim is checkable
    #: against the instantiated scene rather than merely plausible.
    start: tuple[float, float, float]
    end: tuple[float, float, float]

    @property
    def span(self) -> float:
        """Horizontal distance. The axis a jump has to cover."""
        return math.hypot(self.end[0] - self.start[0],
                          self.end[2] - self.start[2])

    @property
    def rise(self) -> float:
        """Vertical change; positive is up."""
        return self.end[1] - self.start[1]

    @model_validator(mode="after")
    def _a_mandatory_jump_stays_inside_the_base_kit(self):
        if not self.mandatory:
            return self
        if self.kind == "rise" and self.rise > C.MAX_VERTICAL_STEP:
            raise ValueError(
                f"traversal '{self.name}' rises {self.rise:.2f} m on the "
                f"mandatory route; the base kit tops out at "
                f"{C.MAX_VERTICAL_STEP:.2f} m")
        if self.kind in ("gap", "rise"):
            allowed = C.max_safe_gap(max(self.rise, 0.0))
            if self.span > allowed:
                raise ValueError(
                    f"traversal '{self.name}' asks for {self.span:.2f} m "
                    f"at a {self.rise:.2f} m rise; the base kit's safe "
                    f"reach there is {allowed:.2f} m. Mark it "
                    f"mandatory=false if it is meant to need an Echo")
        return self


class Volume(Strict):
    """An axis-aligned box in the content's local space, for the things
    Godot must place safely: where a player may arrive, where an enemy may
    spawn, where an objective may sit."""
    name: _TAG
    kind: Literal["player_entry", "enemy_spawn", "objective", "no_build"]
    center: tuple[float, float, float]
    size: tuple[float, float, float]

    @model_validator(mode="after")
    def _has_volume(self):
        if any(s <= 0.0 for s in self.size):
            raise ValueError(f"volume '{self.name}' has a zero or negative "
                             f"dimension: {self.size}")
        return self


class ContentEntry(Strict):
    """One authored thing, by stable id.

    The id is the contract. A scene may be replaced, re-exported, split
    into variants or swapped from graybox to final art without the id
    changing, and nothing outside this manifest ever names the file.
    """
    id: _ID
    level: ContentLevel
    category: ContentCategory
    display_name: str = Field(min_length=1, max_length=C.MAX_TEXT_LEN)

    #: The Godot resource. Present for Godot and for nobody else — a
    #: provider never reads this and can never write one.
    scene: str = Field(default="", max_length=200)
    #: True while the entry describes the legacy procedural builder rather
    #: than an authored scene. Honest bookkeeping: it is what lets the
    #: registry describe the game as it is TODAY without pretending the
    #: placeholders are authored content.
    procedural_fallback: bool = False

    theme_tags: tuple[_TAG, ...] = ()
    semantic_tags: tuple[_TAG, ...] = ()

    #: Overall extent in metres (x, y, z). Godot re-derives this from the
    #: real scene and refuses a manifest that lies about it.
    size: tuple[float, float, float] = (0.0, 0.0, 0.0)
    #: Clearances this content REQUIRES around it, by name.
    clearances: dict[str, float] = Field(default_factory=dict)

    sockets: tuple[Socket, ...] = ()
    volumes: tuple[Volume, ...] = ()
    #: P1: where the floor is. See `Surface`.
    surfaces: tuple[Surface, ...] = Field(default=(), max_length=32)

    #: Art-lane review state. `pending` means someone is still deciding
    #: whether this asset is right, and shipping it would decide for
    #: them; the art lane is in STYLE LOCK 001-R and a file existing in
    #: the tree is not approval. Absent means the entry predates the gate
    #: -- those are the procedural placeholders, which are not art and
    #: were never art-reviewed.
    review: Literal["pending", "pass"] | None = None

    #: P2-B: how far the room turns the chain on its way out, in degrees
    #: about +Y. Zero -- the default, and what every room has always
    #: done -- is straight through.
    #:
    #: THE SIGN IS ESTABLISHED AND WAS EXPENSIVE. `ZoneBuilder` rotates
    #: by `Basis(Vector3.UP, yaw)` and adds the turn, so a shell whose
    #: exit leaves through its +X wall turns the chain by +90 and is the
    #: LEFT corner. An earlier version of the art builders had the two
    #: names swapped and it was caught by a render disagreeing with its
    #: own caption; do not re-derive it.
    exit_yaw: float = 0.0

    #: P2-C: the tower floor counts this shell is BUILT for. Empty means
    #: the shell does not depend on the parameter.
    #:
    #: An authored shell has fixed geometry. The art lane's three towers
    #: are 2, 3 and 5 floors, and the generator may ask for 4 -- so
    #: something has to say "there is no shell for that" rather than
    #: hand back a 3-floor tower and let the room be a floor short. It is
    #: NOT a licence to stretch: a shell either was built for the count
    #: or it was not, and when none was, the permanent procedural
    #: builder makes the room. That fallback is the design, not a
    #: degradation.
    fits_floors: tuple[int, ...] = Field(default=(), max_length=8)

    #: D1: the semantic size Epsilon asks for, when it asks at all.
    #: Optional -- a shell that is simply "the corridor" needs no class.
    size_class: SizeClass | None = None
    #: D1: every movement the shell claims the player makes. Mandatory
    #: ones are bounded by the base kit; Godot measures the claim.
    traversal: tuple[TraversalSegment, ...] = Field(default=(), max_length=32)
    #: What this shell offers a movement package (P3.0). Optional, and
    #: empty for every shell that ships today: the eight P2 rooms are
    #: small enclosed spaces with nothing to offer a rail.
    offers: tuple[Offer, ...] = Field(default=(), max_length=32)

    #: Action primitives or affordance tags a player must own for this
    #: content to be USABLE. Never a reason to place it on a mandatory
    #: path — that is I4, enforced elsewhere and not weakened here.
    requires_capabilities: tuple[_TAG, ...] = ()
    #: For `affordance_visual`, the §13 tag it renders.
    affordance_tag: str = Field(default="", max_length=32)

    #: Rough instantiation cost, for a per-Zone budget Godot enforces.
    cost: int = Field(default=1, ge=0, le=1000)
    variants: tuple[_ID, ...] = ()
    #: The id to use when this one cannot be instantiated. The migration
    #: shape of S13: authored scene if available, validated placeholder
    #: otherwise.
    fallback: str = Field(default="", max_length=48)

    @model_validator(mode="after")
    def _category_and_level_agree(self):
        allowed = _LEVELS[self.category]
        if self.level not in allowed:
            raise ValueError(
                f"'{self.id}' is a {self.category} at level {self.level}; "
                f"that category is level {' or '.join(map(str, allowed))}")
        return self

    @model_validator(mode="after")
    def _has_what_its_category_requires(self):
        if self.category in _NEEDS_SOCKETS:
            joins = [s for s in self.sockets
                     if s.kind in ("doorway", "corridor_end")]
            if not joins:
                raise ValueError(
                    f"'{self.id}' is a {self.category} and declares no "
                    f"doorway or corridor_end socket; nothing could ever "
                    f"connect to it")
        if self.category == "affordance_visual" and not self.affordance_tag:
            raise ValueError(
                f"'{self.id}' is an affordance_visual and names no "
                f"affordance_tag; it renders nothing in particular")
        return self

    @model_validator(mode="after")
    def _a_declared_floor_count_is_one_a_tower_can_have(self):
        # Bounds from `constants.py`, which is also where `TowerChamber`
        # reads them and where the exporter takes GDScript's copy from.
        # One source, three consumers, no drift.
        for floors in self.fits_floors:
            if not (C.TOWER_MIN_FLOORS <= floors <= C.TOWER_MAX_FLOORS):
                raise ValueError(
                    f"'{self.id}' says it fits a {floors}-floor tower; "
                    f"the schema builds {C.TOWER_MIN_FLOORS} to "
                    f"{C.TOWER_MAX_FLOORS}")
        return self

    @model_validator(mode="after")
    def _the_exit_turns_by_a_quarter_or_not_at_all(self):
        if self.exit_yaw not in EXIT_YAWS:
            raise ValueError(
                f"'{self.id}' declares exit_yaw {self.exit_yaw}; the "
                f"chain is built for quarter turns and accepts "
                f"{', '.join(f'{y:g}' for y in EXIT_YAWS)}")
        return self

    @model_validator(mode="after")
    def _an_authored_room_says_where_its_floor_is(self):
        """P1: parity is not optional for the producer that needs it.

        A procedural builder cannot omit this -- it lays the floor, so it
        knows. An authored shell can, and one that does hands the
        composer a room with nowhere to stand, which is how activity
        elements ended up over a kill pit in five `platform_path` rooms.

        Only real authored ROOM SHELLS are held to it. A
        `procedural_fallback` entry describes code that already answers
        the question, and a prop is not a room.
        """
        if self.category != "room_shell" or self.procedural_fallback:
            return self
        if not self.surfaces:
            raise ValueError(
                f"'{self.id}' is an authored room shell and declares no "
                f"surfaces; nothing downstream would know where its "
                f"floor is, and a composer would place against its "
                f"bounding box")
        return self

    @model_validator(mode="after")
    def _a_socket_stands_on_a_surface_that_exists(self):
        """A named surface that is not there is a claim about nothing.

        The audit measures whether the socket really landed on it. This
        only refuses the typo, which is cheaper to catch here.
        """
        known = {surface.name for surface in self.surfaces}
        for socket in self.sockets:
            if socket.surface_id and socket.surface_id not in known:
                raise ValueError(
                    f"socket '{socket.name}' of '{self.id}' stands on "
                    f"surface '{socket.surface_id}', which this entry "
                    f"does not declare")
        return self

    @model_validator(mode="after")
    def _surface_names_are_unique(self):
        seen: set[str] = set()
        for surface in self.surfaces:
            if surface.name in seen:
                raise ValueError(
                    f"'{self.id}' declares two surfaces named "
                    f"'{surface.name}'; a socket naming one could mean "
                    f"either")
            seen.add(surface.name)
        return self

    @model_validator(mode="after")
    def _is_either_authored_or_honest_about_not_being(self):
        if self.procedural_fallback:
            if self.scene:
                raise ValueError(
                    f"'{self.id}' is marked as a procedural fallback and "
                    f"also names a scene; it is one or the other")
        elif not self.scene:
            raise ValueError(
                f"'{self.id}' names no scene and is not marked "
                f"`procedural_fallback`. An entry describing nothing is "
                f"how the registry starts lying about what exists")
        return self

    @model_validator(mode="after")
    def _socket_names_are_unique(self):
        names = [s.name for s in self.sockets]
        if len(set(names)) != len(names):
            raise ValueError(f"'{self.id}' repeats a socket name: {names}")
        volumes = [v.name for v in self.volumes]
        if len(set(volumes)) != len(volumes):
            raise ValueError(f"'{self.id}' repeats a volume name: {volumes}")
        return self

    @model_validator(mode="after")
    def _the_scene_path_stays_inside_the_content_root(self):
        """A path is the one thing in this file that could reach outside
        the project. It is Godot's field, never a provider's, and it is
        still checked — an entry pointing at `res://../` or an absolute
        path is a manifest that can address anything on the disk."""
        if not self.scene:
            return self
        if not self.scene.startswith("res://content/"):
            raise ValueError(
                f"'{self.id}' points at {self.scene!r}; authored content "
                f"lives under res://content/ and nowhere else")
        if ".." in self.scene:
            raise ValueError(f"'{self.id}' path escapes: {self.scene!r}")
        return self


class ContentManifest(Strict):
    """One manifest file. Several may exist — one per content pack — and
    the registry is their union, so an artist adds a pack rather than
    editing a growing shared file."""
    schema_version: Literal[1] = 1
    pack: _TAG
    description: str = Field(default="", max_length=C.MAX_TEXT_LEN)
    entries: tuple[ContentEntry, ...] = Field(min_length=1)

    @model_validator(mode="after")
    def _ids_are_unique_within_the_pack(self):
        ids = [e.id for e in self.entries]
        if len(set(ids)) != len(ids):
            dupes = sorted({i for i in ids if ids.count(i) > 1})
            raise ValueError(f"pack '{self.pack}' repeats ids: {dupes}")
        return self


class RegistryError(ValueError):
    """A manifest set that does not describe a usable alphabet."""


def build_registry(manifests) -> dict[str, ContentEntry]:
    """Merge manifests into one id -> entry map, refusing anything a
    consumer could not act on.

    Cross-manifest checks live here rather than on the models because
    none of them can be answered by one entry alone: an id colliding
    across packs, a variant or fallback naming something that does not
    exist, a fallback chain that loops.
    """
    registry: dict[str, ContentEntry] = {}
    origin: dict[str, str] = {}
    for manifest in manifests:
        for entry in manifest.entries:
            if entry.id in registry:
                raise RegistryError(
                    f"id '{entry.id}' is defined in both "
                    f"'{origin[entry.id]}' and '{manifest.pack}'; ids are "
                    f"the contract and must be unique across every pack")
            registry[entry.id] = entry
            origin[entry.id] = manifest.pack

    for entry in registry.values():
        for variant in entry.variants:
            if variant not in registry:
                raise RegistryError(
                    f"'{entry.id}' lists variant '{variant}', which no "
                    f"pack defines")
            if registry[variant].category != entry.category:
                raise RegistryError(
                    f"'{entry.id}' lists '{variant}' as a variant, but it "
                    f"is a {registry[variant].category} and this is a "
                    f"{entry.category}; a variant is the same THING made "
                    f"differently")
        if entry.fallback:
            if entry.fallback not in registry:
                raise RegistryError(
                    f"'{entry.id}' falls back to '{entry.fallback}', which "
                    f"no pack defines. A fallback that does not exist is "
                    f"the failure the fallback was there to prevent")
            if registry[entry.fallback].category != entry.category:
                raise RegistryError(
                    f"'{entry.id}' falls back to '{entry.fallback}', a "
                    f"{registry[entry.fallback].category}; it must be a "
                    f"{entry.category}")

    _refuse_fallback_cycles(registry)
    return registry


def _refuse_fallback_cycles(registry: dict[str, ContentEntry]) -> None:
    """A fallback chain must terminate.

    S13's whole shape is "authored scene if available, validated
    placeholder otherwise", and a cycle turns the otherwise into a hang at
    the exact moment something was already going wrong.
    """
    for start in registry:
        seen = [start]
        current = registry[start].fallback
        while current:
            if current in seen:
                raise RegistryError(
                    f"fallback cycle: {' -> '.join(seen + [current])}. A "
                    f"chain has to end at something that always works")
            seen.append(current)
            current = registry[current].fallback


def resolve(registry: dict[str, ContentEntry], content_id: str,
            available) -> ContentEntry:
    """The S13 selection rule, decided here so both languages agree.

    `available` answers "can this entry actually be instantiated" — in
    Godot, whether the scene loads; in a test, whatever the test says. The
    first entry down the fallback chain that answers yes wins, and the
    chain is known to terminate.
    """
    if content_id not in registry:
        raise RegistryError(f"unknown content id '{content_id}'")
    current: str = content_id
    while current:
        entry = registry[current]
        if available(entry):
            return entry
        current = entry.fallback
    raise RegistryError(
        f"'{content_id}' is unavailable and its fallback chain ends "
        f"without anything that is")
