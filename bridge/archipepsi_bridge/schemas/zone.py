"""Archipepsi v0.7 — Zone contract.

This module IS the Zone specification. EPSILON_SPEC.md describes it; where
they disagree, this file wins.

Two layers, deliberately separated:

* Structural  — Pydantic. Shape, enums, bounds, per-chamber rules. Runs on
  parse AND on assignment, so a model cannot be mutated out of validity
  after construction.
* Semantic    — `validate_zone()`. Facts needing request context: which AP
  locations were allocated, which Echoes are owned. Returns error strings
  fed verbatim into the single repair request.
"""

from __future__ import annotations

from typing import Annotated, Literal, Union

from pydantic import (
    BaseModel, ConfigDict, Field, field_validator, model_validator)

try:  # works standalone and when copied into a package
    from . import constants as C
    from . import mechanics as M
    from .graph import (
        EDGE_ID_CHARSET, Capability, DoorAssignment, PlugAssignment,
        TopologyEdge, ZoneKeySpec)
    from .physics import STATE_VECTOR_BOUND, state_vector_product
except ImportError:  # pragma: no cover
    import constants as C
    import mechanics as M
    from graph import (
        EDGE_ID_CHARSET, Capability, DoorAssignment, PlugAssignment,
        TopologyEdge, ZoneKeySpec)
    from physics import STATE_VECTOR_BOUND, state_vector_product

#: Every joining socket name a procedural room can be given, matching
#: `chamber_builders.procedural_sockets`. An authored shell declares its
#: own set in the catalog; these are the ones the bridge can check
#: without one.
#:
#: **THE VOCABULARY, NOT THE CAPACITY.** Which of these a room can really
#: be joined through depends on its producer —
#: `C.PROCEDURAL_SOCKET_CAPACITY` says which, and
#: `procedural_sockets_for` is how to ask. This tuple stays the full set
#: because a SAVED Zone may name any of them: a campaign composed before
#: the capacity was measured holds `platform_path` rooms with side doors,
#: and refusing those names here would refuse to LOAD those saves.
PROCEDURAL_SOCKETS = ("entry", "exit", "side_left", "side_right")

def procedural_sockets_for(chamber_type: str) -> tuple[str, ...]:
    """The joining sockets a PROCEDURAL room of this type can hold.

    **THE ONE DECLARATION**, projected from
    `C.PROCEDURAL_SOCKET_CAPACITY` so the composer, this schema, the
    acceptance validator and the ENGINE cannot each have their own
    answer — the capacity is exported to `constants.gd`, which is what
    stops the builder and the planner drifting into different numbers of
    doors. Drift is exactly what the flat four-door advertisement was: a
    composer assigning a side door the engine would never cut.

    `chamber_builders.procedural_sockets` places a side socket at the
    middle of the side wall. That is the shape of a FLAT room and is
    false of the two producers that CLIMB — on a platform course the
    middle of the side wall is over the kill pit and below the walkway,
    and a tower's is behind its spiral. Both were measured at the site,
    one control per chamber type, and `zone_01`'s `c008` refused its
    layout for exactly that. Relocating the socket onto the start ledge
    was MEASURED and does not help: the branch then cannot be placed at
    all. So the honest repair is to stop OFFERING the doorway, not to
    move it.

    A statement about the PRESENT PROCEDURAL PRODUCERS. Not a rule
    against branching platform rooms, and nothing at all about an
    authored shell that shares the type: a shell declares its own
    openings and `topology._sockets_for` reads them instead of this.
    """
    return tuple(C.PROCEDURAL_SOCKET_CAPACITY.get(chamber_type,
                                                  PROCEDURAL_SOCKETS))

#: The per-room anchors the engine resolves, as `room:<room_id>:<kind>`.
#:
#: `arrival` is where a body entering the room stands — the room's own
#: `player_entry`, carried into world space by `zone_builder`.
#:
#: `return` is a spot RESERVED for a return device, reconciled against
#: the room's furniture, its reward pedestal and its key spots by the
#: builder that placed them (`ChamberBuilders._clear_spot`), and clear
#: of `arrival` by enough that a body standing at the arrival is not
#: inside the device's trigger volume.
#:
#: The two are separate because they were once the same, and a return
#: plug standing on the arrival fires the moment the player walks in:
#: the branch sent them home before they could use it. Found by the
#: engine lane in the integrated build.
ROOM_ANCHOR_KINDS = ("arrival", "return")

SCHEMA_VERSION = 7

Theme = Literal[
    "concrete_facility", "rusted_industrial", "neon_transit",
    "gothic_stone", "temple_ruin", "void_glitch",
]
Archetype = Literal["melee", "ranged", "brute"]

_ID = Field(min_length=1, max_length=24, pattern=r"^[a-z0-9_]+$")
_ECHO_ID = Annotated[str, Field(max_length=32, pattern=r"^echo_\d+$")]


class Strict(BaseModel):
    # extra="forbid" rejects invented fields outright rather than dropping
    # them silently, so a hallucinated mechanic fails loudly.
    # validate_assignment closes the v0.4 hole where post-parse mutation
    # walked straight through every bound.
    model_config = ConfigDict(extra="forbid", frozen=True)


#: ECHOES.md §13. Same seven tags the `affordance` component kind names —
#: one vocabulary, because a Zone feature and an owned capability tag are
#: the same concept seen from the two ends.
AffordanceTag = Literal[
    "grapple_anchor", "breakable_wall", "water_volume", "rail",
    "wind_volume", "bounce_pad", "moving_platform",
    # ENVIRONMENTAL AGENCY, and it is a feature for a reason.
    #
    # `powered_door` is a chain rather than an object: a crate the player
    # shoves with their own body, a plate that adds up what stands on it,
    # a live signal, and a door open exactly while the signal is high
    # (`06_THE_AMALGAM.md` §5.4a).
    #
    # It is declared HERE, in the optional-feature vocabulary, rather
    # than as a new kind of thing, because §13.2 already guarantees what
    # this most needs to be true: a feature may never lie on the
    # mandatory path, host an AP reward, an exit or an objective. A
    # player who cannot shove the crate therefore loses a note and
    # nothing else, and the chain cannot become an undeclared capability
    # gate by construction rather than by anyone remembering.
    "powered_door",
]


#: The activity vocabulary (CAMPAIGN_SCALE.md 9).
#:
#: Four composable families, not fifteen bespoke minigames. Each is a
#: system whose difficulty comes from BOUNDED COMPOSITION -- how many
#: elements, how generous the timing, how far apart -- rather than from a
#: separate hand-made puzzle per flavour.
#:
#: Every one is solvable with base movement and Static Pulse alone WHEN
#: IT ASKS FOR NOTHING ELSE -- a switch is touched, a target is shot, a
#: plate is stood on, a timed run is run.
#:
#: SUPERSEDED 2026-08-30 (owner ruling): this file used to end that
#: sentence "nothing here needs an Echo, and nothing may be added that
#: does". Activities MAY now require an Echo capability, through
#: `ActivityPrimitive.requires`, and the restriction that replaces it is
#: narrower and stronger: **no requirement before guarantee.** What a
#: capability is, is semantic -- "can the player grapple", never "does
#: the player hold the Grapple Echo" -- so an Echo the player built
#: themselves satisfies it identically.
#:
#: `switch_sequence`  N switches, optionally in a required order.
#: `timed_run`        activate, then reach the target before it lapses.
#: `target_challenge` shoot N targets, optionally against a clock.
#: `pressure_routing` hold plates / route power to open the way.
ActivityKind = Literal[
    "switch_sequence", "timed_run", "target_challenge", "pressure_routing",
]

#: The semantic capabilities an activity may require (owner ruling,
#: 2026-08-30). Spelled out as a Literal rather than derived from
#: `mechanics.ACTIVITY_CAPABILITIES` at import time, so the closure is
#: STRUCTURAL: `test_epsilon_vocabulary` proves a string field Epsilon
#: can fill is a closed vocabulary by reading the annotation, and a
#: vocabulary assembled at runtime is one it cannot see. The two are
#: pinned to each other by a test rather than by a comment.
ActivityCapability = Literal[
    "blink", "cross_long_gap", "grapple", "ranged_hit",
]


class ActivityPrimitive(Strict):
    """One instance of an activity family, with its difficulty dialled in.

    Epsilon picks the family and the numbers. It does not describe the
    puzzle in prose, because prose cannot be built and cannot be scored:
    an unimplemented tag counts for nothing (CAMPAIGN_SCALE.md 9), and
    the way to guarantee that is to have no field it could put prose in.
    """

    kind: ActivityKind

    #: Switches, targets or plates. The primary difficulty dial.
    element_count: int = Field(default=1, ge=1, le=8)

    #: Seconds allowed, or 0 for untimed. Bounded below so a timed run is
    #: never a reflex test the base kit cannot pass.
    time_limit: float = Field(default=0.0, ge=0.0, le=120.0)

    #: Whether the elements must be used in a specific order. Free on its
    #: own; expensive combined with a clock, which is the composition the
    #: difficulty is supposed to come from.
    ordered: bool = False

    #: SEMANTIC capability requirements (owner ruling, 2026-08-30). Names
    #: from `mechanics.ACTIVITY_CAPABILITIES`, every one of which is
    #: satisfied by ANY primitive in its family.
    #:
    #: Conjunctive: all of them, and each satisfied by any member. That
    #: is the shape that lets a Zone say "you need a way to grapple"
    #: without saying "you need the canonical Grapple Echo".
    #:
    #: What may NOT go here, and cannot, because the vocabulary has no
    #: word for it: raw damage, DPS, a health threshold, a crit figure.
    #: Numeric combat power is BALANCE. It is never LOGIC, so a Zone can
    #: never mean "enter only if your build does 400 DPS".
    #:
    #: Empty is the norm and stays the norm. `validate_zone` refuses any
    #: entry whose guarantee the generator cannot prove.
    requires: tuple[ActivityCapability, ...] = Field(
        default=(), max_length=2)

    @field_validator("requires")
    @classmethod
    def _no_capability_is_asked_for_twice(cls, value):
        if len(set(value)) != len(value):
            raise ValueError(f"duplicate capability in {list(value)}")
        return value

    @model_validator(mode="after")
    def _a_timed_puzzle_stays_base_kit_solvable(self):
        """Base-kit solvability is absolute (CAMPAIGN_SCALE.md 9).

        A clock is the one dial here that can make an activity
        IMPOSSIBLE rather than merely hard, so it is the one with a
        floor: each element needs time to reach at base movement speed.
        Without this a provider could ask for eight ordered switches in
        three seconds, which validates as a puzzle and plays as a wall.
        """
        if self.time_limit == 0.0:
            return self
        needed = self.element_count * C.SECONDS_PER_ACTIVITY_ELEMENT
        if self.ordered:
            needed *= C.ORDERED_ACTIVITY_TIME_MULTIPLIER
        if self.time_limit < needed:
            raise ValueError(
                f"a {self.kind} with {self.element_count} elements"
                f"{' in order' if self.ordered else ''} needs at least "
                f"{needed:.0f}s at base movement speed, not "
                f"{self.time_limit:.0f}s")
        return self


#: How much clear air a player needs above a walkable surface. Below
#: this a "gallery" is a shelf you cannot stand on.
#:
#: Public because a generator has to know it BEFORE it proposes a band.
#: The fallback used to derive the same number itself, and the two
#: derivations disagreed by five millimetres of rounding -- which is one
#: more instance of the fact this whole batch has been about.
HEADROOM = C.PLAYER_HEIGHT + 0.6


def band_ramp_fits(band, width: float, depth: float) -> str:
    """Why this band's ramp does not fit this room, or "" when it does.

    A band is a deck plus the ramp that reaches it, and only the deck was
    ever bounded. The ramp runs `BAND_RAMP_RUN_FACTOR` metres per metre
    of rise back from the deck's inner edge, along DEPTH for a `back`
    band and along WIDTH for a `left` or `right` one, and in a shallow
    room that run leaves the room entirely -- through the entry wall,
    across the doorway and across the arrival at `(0, 0, 3)`.

    The bound is the same `BAND_DOOR_MARGIN` walkway `back` already
    leaves at the far wall, now required at the ramp's foot as well.
    Public because the fallback has to know it BEFORE it proposes a
    band, which is the same reason `HEADROOM` is public.
    """
    if band is None:
        return ""
    run = max(C.BAND_RAMP_MIN_RUN, abs(band.rise) * C.BAND_RAMP_RUN_FACTOR)
    if band.side == "back":
        deck = depth * band.coverage
        free = depth - deck - C.BAND_DOOR_MARGIN - run
        axis, span = "deep", depth
    else:
        deck = width * band.coverage
        free = width - deck - run
        axis, span = "wide", width
    if free < C.BAND_DOOR_MARGIN:
        return (f"a {band.rise:.2f}m {band.side} {band.kind} covering "
                f"{band.coverage:.2f} of a room {span:.1f}m {axis} needs "
                f"{run:.1f}m of ramp and leaves {free:.1f}m at its foot; "
                f"{C.BAND_DOOR_MARGIN:.1f}m is the walkway a doorway and "
                f"an arrival need")
    return ""


class ElevationBand(Strict):
    """A second walkable height inside an ORDINARY room (ROOM_GRAMMAR v0).

    The measured finding this exists for: a room's entire shape was three
    numbers. `ArenaChamber` was width, depth and wall_height, so every one
    of the twenty-three rooms in the played Zone was a flat rectangle and
    the twenty-eight ranged enemies in them had nowhere to be ranged
    FROM. Nothing was wrong with the generator; there was no field in
    which a raised area could be described.

    Deliberately ONE band, and deliberately not a `platform_path`. This
    is a property an ordinary room may have, not a room type -- the whole
    point is that verticality stops being a special minigame.

    Every field is a Literal or a bounded float so the vocabulary can
    GROW without becoming free-form: `kind` gains `catwalk` and `alcove`,
    `access` gains `drop` and `capability:<name>`, `side` gains `front`.
    A dead-end one-off would have been a boolean called `has_ledge`.
    """

    #: Raised shelf along a wall, or a sunken area in the floor.
    kind: Literal["gallery", "pit"]

    #: Metres above the floor (gallery) or below it (pit).
    #:
    #: Floored at `MAX_VERTICAL_STEP` so a band is never something you
    #: step onto by accident -- a 30 cm rise is a trip hazard, not a
    #: decision. Capped so a pit stays a place rather than a well.
    rise: float = Field(ge=C.MAX_VERTICAL_STEP, le=4.0)

    #: Fraction of the room's DEPTH the band spans.
    #:
    #: Bounded well under 1.0 on purpose: a band covering the whole room
    #: is a room at a different height, which is not a spatial decision.
    coverage: float = Field(ge=0.2, le=0.55)

    #: Which wall it hugs.
    side: Literal["left", "right", "back"]

    #: How the player gets on and off it. Both are base-kit traversal --
    #: NO REQUIREMENT BEFORE GUARANTEE applies to geometry exactly as it
    #: applies to activities, and a band holding anything required must
    #: be reachable by movement the campaign is guaranteed to have.
    access: Literal["ramp", "stair"] = "ramp"


class EnemyGroup(Strict):
    archetype: Archetype
    #: One group is one encounter, so this is the encounter cap rather
    #: than the room's: a room may hold two or three waves, but the
    #: player fights them one at a time.
    count: int = Field(ge=1, le=C.MAX_ENEMIES_PER_ENCOUNTER)


class AffordanceFeature(Strict):
    """One optional world feature a Zone may offer (ECHOES.md §13).

    Optional is the whole point. A feature may never lie on the mandatory
    path, host an AP reward, an exit or an objective — §13.2, enforced by
    `validate_zone` rather than by good intentions — so a Zone with every
    feature stripped out is still completable with the base kit. That is
    what makes affordances safe to generate against a campaign whose
    capabilities the generator cannot fully predict.
    """
    tag: AffordanceTag
    #: Where in the chamber, as a fraction of its extent. The builder owns
    #: metres; a generator that could name a coordinate could name one
    #: inside the exit lane.
    at: tuple[float, float] = ((0.5, 0.5))
    note: str | None = Field(default=None, max_length=C.MAX_TEXT_LEN)

    @model_validator(mode="after")
    def _inside_the_chamber(self):
        for value in self.at:
            if not 0.0 <= value <= 1.0:
                raise ValueError(
                    f"affordance position {self.at} is outside the chamber"
                )
        return self


class ChamberBase(Strict):
    id: str = _ID
    flavor: str | None = Field(default=None, max_length=C.MAX_TEXT_LEN)
    reward_location_id: int | None = Field(
        # The stable 600-id universe, not one campaign's range: a
        # Zone carries whichever Checks its own seed allocated, and
        # the campaign's range is checked where the scale is known
        # (CAMPAIGN_SCALE.md 3).
        default=None, ge=C.FIRST_LOCATION_ID, le=C.LAST_UNIVERSE_ID
    )
    #: S9. Additive and optional: a Zone generated before affordances
    #: existed is still a valid Zone, which is why `schema_version` stays
    #: 7 — bumping it would fail every Zone already inside a save for a
    #: change that requires nothing and removes nothing.
    features: tuple[AffordanceFeature, ...] = Field(default=(), max_length=3)

    #: Layer 2 of `09_ROOM_CONTRACT.md`: which joining socket of this
    #: room does what. Additive and optional for the same reason
    #: `features` was — a chamber carrying no doors is the two-door
    #: chamber that shipped before multi-door existed, and the engine
    #: falls back to its legacy socket pair when no assignment is
    #: present. That fallback is what keeps all twelve authored shells
    #: composing unchanged, by construction rather than by promise.
    doors: tuple[DoorAssignment, ...] = Field(default=(), max_length=8)

    #: Which edge the chain ARRIVES by and which it DEPARTS by.
    #:
    #: `09_ROOM_CONTRACT.md` §11.2. `content_instantiator.socket_for_edge`
    #: reads exactly these two names off the chamber and resolves each
    #: through `doors` to a socket, so `_entry_offset`/`_exit_offset` use
    #: the opening the composer assigned rather than the one that happens
    #: to be called `entry`. The engine's half has shipped; nothing wrote
    #: these, so every room fell through to the legacy name pair and an
    #: authored junction would have been entered through the wrong door.
    #:
    #: **They name an EDGE, never a socket.** Which socket serves that
    #: edge is already in `doors`, and saying it twice is how the two
    #: come to disagree. `_the_chain_names_edges_this_room_carries`
    #: below is what stops them being a second topology: each must name
    #: an edge one of this room's own non-`SEALED` doors carries.
    #:
    #: Additive and optional, for the third time and the same reason
    #: `features` and `doors` were: a chamber carrying neither is the
    #: chamber that shipped before multi-door existed, the engine's
    #: documented fallback applies, and `schema_version` stays 7.
    arrive_edge: str | None = Field(default=None, min_length=1,
                                    max_length=48, pattern=EDGE_ID_CHARSET)
    depart_edge: str | None = Field(default=None, min_length=1,
                                    max_length=48, pattern=EDGE_ID_CHARSET)

    #: Zone-local keys this room holds. Not Archipelago items: no
    #: location id, never scouted, never sent, gone when the Zone is.
    keys: tuple[ZoneKeySpec, ...] = Field(default=(), max_length=4)

    @model_validator(mode="after")
    def _the_chain_names_edges_this_room_carries(self):
        """A selector that names an edge no door of this room serves.

        The engine resolves `arrive_edge` by scanning `doors` for it and
        returns an empty socket when it finds none — which is the LEGACY
        FALLBACK, silently. So a selector naming an edge this room does
        not carry does not fail: it quietly places the room at its
        default opening, which is the defect this field exists to fix,
        with a value in it that looks like the fix was applied.
        """
        carried = {d.edge_id for d in self.doors
                   if d.edge_id and d.usage != "SEALED"}
        for name, edge in (("arrive_edge", self.arrive_edge),
                           ("depart_edge", self.depart_edge)):
            if edge is None:
                continue
            if edge not in carried:
                raise ValueError(
                    f"chamber '{self.id}' names '{edge}' as its {name} "
                    "and carries no open door onto it; the engine would "
                    "fall back to the legacy opening and nothing would "
                    "say so")
        if self.arrive_edge is not None \
                and self.arrive_edge == self.depart_edge:
            raise ValueError(
                f"chamber '{self.id}' arrives and departs by the same "
                f"edge '{self.arrive_edge}'; that is one opening asked "
                "to be both ends of the room")
        return self

    @model_validator(mode="after")
    def _no_socket_serves_twice(self):
        """Invariant 2: one socket, one job.

        A socket assigned twice is two doors in one opening, and whichever
        the engine carves last silently wins.
        """
        used = [d.socket_id for d in self.doors]
        twice = {s for s in used if used.count(s) > 1}
        if twice:
            raise ValueError(
                f"chamber '{self.id}' assigns socket(s) {sorted(twice)} "
                "more than once")
        return self

    @property
    def door_degree(self) -> int:
        """How many edges this room's doors carry.

        A room's door degree is its JOINED degree. A dead end with one
        door and one plug has door degree 1 — the plug consumes no
        socket.

        COUNTED BY THE EDGE, not by the hole. This read `usage !=
        "SEALED"`, which was the same number while every passable door
        carried an edge. `ZONE_EXIT` is passable and carries none — the
        room on its far side is the engine's appended exit room, which
        is in no `edges` list — so counting holes made the last room on
        every chain read as degree 2 and stopped this being a statement
        about the graph at all. `USED` and `LOCKED` always name an edge
        and `SEALED` never does, so nothing else moves.
        """
        return sum(1 for d in self.doors if d.edge_id is not None)

    #: CAMPAIGN_SCALE.md 7: a complex room may carry more than one Check.
    #:
    #: Additive for the same reason `features` was — Zones live inside
    #: saves, so a new REQUIRED field would fail every campaign in
    #: progress. `reward_location_id` keeps its meaning; this holds the
    #: rest. Nothing reads either directly: `reward_ids` below is the one
    #: canonical view, and a test asserts no consumer goes around it.
    #:
    #: Bounded low on purpose. Two or three Checks in a genuinely large
    #: room correspond to distinct activities; fifteen in one room is the
    #: warehouse of pedestals CAMPAIGN_SCALE.md 5 forbids, and this is
    #: the cheap structural half of preventing it.
    additional_reward_location_ids: tuple[int, ...] = Field(
        default=(), max_length=2)

    #: CAMPAIGN_SCALE.md 9. Additive and optional, like `features` before
    #: it: a Zone from before the vocabulary existed is still valid.
    activities: tuple[ActivityPrimitive, ...] = Field(
        default=(), max_length=3)

    #: D1: authored-shell selection. Epsilon names INTENT, and may pick a
    #: shell id out of the legal catalog it was handed. It never names
    #: metres for an authored shell, and it never names a path -- the
    #: charset here makes the second unspellable rather than merely
    #: discouraged (S19).
    #:
    #: All three are optional and additive. A chamber with none of them
    #: is the procedural path exactly as before, which is why the
    #: continuous `width`/`length`/`gap_size` fields below are untouched:
    #: D1 keeps the safe numeric generator for the fallback and layers
    #: semantic selection on top for authored content.
    shell_id: str | None = Field(
        default=None, max_length=48, pattern=r"^[a-z0-9_]+$")
    size_class: Literal["small", "medium", "large"] | None = None
    intent: tuple[Annotated[str, Field(
        min_length=1, max_length=24, pattern=r"^[a-z0-9_]+$")], ...] = Field(
        default=(), max_length=4)

    @property
    def reward_ids(self) -> tuple[int, ...]:
        """Every AP Check this chamber holds, in a stable order.

        THE canonical view. `reward_location_id` and
        `additional_reward_location_ids` are storage shapes kept apart so
        that saves written before multi-Check rooms still load; nothing
        outside this class should read either one.
        """
        first = () if self.reward_location_id is None \
            else (self.reward_location_id,)
        return first + tuple(self.additional_reward_location_ids)

    @model_validator(mode="after")
    def _each_check_is_its_own_check(self):
        """A Check must be earned once, by one thing.

        Two ids sharing a completion edge would send both the moment
        either was earned -- which is not a duplicate, it is Archipepsi
        telling the multiworld a player found an item they never reached.
        Distinctness is the cheap half; the expensive half is that each
        needs its own acquisition condition, which is the room builder's.
        """
        ids = self.reward_ids
        if len(set(ids)) != len(ids):
            raise ValueError(
                f"chamber '{self.id}' lists Check "
                f"{sorted(i for i in ids if ids.count(i) > 1)[0]} twice; "
                "two ids sharing one completion edge would send a Check "
                "the player never earned")
        if self.reward_location_id is None and \
                self.additional_reward_location_ids:
            raise ValueError(
                f"chamber '{self.id}' has additional Checks but no first "
                "one; `reward_location_id` is the primary, so extras "
                "without it would be invisible to anything reading only "
                "the original field")
        return self

    @model_validator(mode="after")
    def _features_sit_clear_of_the_walking_lane(self):
        """The geometric proof, now applied to EVERY chamber that can hold
        a feature rather than only to corridors.

        `FEATURE_MIN_WIDTH` is `2 * (lane + 2 * reach + wall clearance)`
        per tag: a width covering it is a width with somewhere to put the
        feature that is neither in the masonry nor across the route. That
        is the real statement of "an affordance is never on the mandatory
        path", and it used to run on corridors only -- so every other room
        type got a blanket ban instead (CAMPAIGN_SCALE.md 7).
        """
        width = getattr(self, "width", None)
        if width is None:
            width = getattr(self, "side", None)
        if width is None:
            return self
        # AND THE OTHER AXIS, which this rule never had.
        # `AffordanceFeatures.fits` asks about width AND depth, and only
        # the width half was written down -- so a `powered_door`, which
        # reaches 3.5 m along the run and needs 11.0 m of room, could be
        # declared on an 8.6 m corridor, pass here, and be DROPPED by the
        # builder. The engine then offers no certified package and
        # `layout.validate` refuses the Zone for a chain that was
        # declared and never built. Absent depth is not checked: a room
        # model that does not state one is not being asked to.
        depth = getattr(self, "length", None)
        if depth is None:
            depth = getattr(self, "depth", None)
        if depth is None:
            depth = getattr(self, "side", None)
        for feature in self.features:
            needed = C.FEATURE_MIN_WIDTH.get(
                feature.tag, C.MIN_FEATURE_CHAMBER_WIDTH)
            if width < needed:
                raise ValueError(
                    f"chamber '{self.id}' is {width}m wide and carries "
                    f"a '{feature.tag}', which needs {needed}m to sit clear "
                    "of the walking lane on both sides (ECHOES.md 13.2); "
                    "widen the room or offer a smaller feature"
                )
            if depth is None:
                continue
            # A SIDE DOORWAY IS CUT WHERE THE LANE RULE PUSHES A FEATURE.
            # `side_left` and `side_right` are declared at the middle of
            # the side wall, which is exactly where a feature pushed out
            # of the walking lane ends up -- so the run it needs is the
            # one that fits WHOLLY to one side of that opening. Measured
            # on `zone_02`'s `c013` and `zone_04`'s `c009`, both refused
            # on aperture polarity for their own `powered_door` leaf
            # standing in a door the composer declared USED.
            beside = any(
                d.socket_id in C.SIDE_SOCKETS and d.usage != "SEALED"
                for d in getattr(self, "doors", ()) or ())
            along = (
                C.FEATURE_MIN_DEPTH_BESIDE_DOOR.get(
                    feature.tag, C.MIN_FEATURE_CHAMBER_DEPTH_BESIDE_DOOR)
                if beside else
                C.FEATURE_MIN_DEPTH.get(
                    feature.tag, C.MIN_FEATURE_CHAMBER_DEPTH))
            if depth < along:
                raise ValueError(
                    f"chamber '{self.id}' is {depth}m long and carries "
                    f"a '{feature.tag}', which needs {along}m to clear "
                    + ("both thresholds and the side doorway cut into "
                       "the middle of its wall" if beside else
                       "both thresholds along the run")
                    + " (ECHOES.md 13.2); lengthen the room or offer a "
                    "shorter feature"
                )
        return self

    @property
    def enemy_total(self) -> int:
        return sum(g.count for g in getattr(self, "enemies", []))

    @property
    def brute_total(self) -> int:
        return sum(g.count for g in getattr(self, "enemies", [])
                   if g.archetype == "brute")


class _WithEnemies(ChamberBase):
    @model_validator(mode="after")
    def _chamber_enemy_budget(self):
        # v0.4 bounded each GROUP at 8 and allowed 4 groups, so a chamber
        # could legally hold 14 while the prose and the constraints sent to
        # Epsilon both said 8.
        if self.enemy_total > C.MAX_ENEMIES_PER_CHAMBER:
            raise ValueError(
                f"chamber '{self.id}' has {self.enemy_total} enemies, "
                f"limit is {C.MAX_ENEMIES_PER_CHAMBER}"
            )
        objective = getattr(self, "objective", None)
        if objective == "kill_all" and self.enemy_total == 0:
            raise ValueError(
                f"chamber '{self.id}': objective 'kill_all' needs at least one enemy"
            )
        return self


class CorridorChamber(_WithEnemies):
    """Connector. Has no objective, so enemies here gate nothing."""
    type: Literal["corridor"]
    length: float = Field(ge=6, le=30)
    width: float = Field(ge=4, le=10)
    enemies: tuple[EnemyGroup, ...] = Field(default=(), max_length=4)

    @model_validator(mode="after")
    def _reward_needs_a_gate(self):
        if self.reward_location_id is not None and self.enemy_total > 0:
            raise ValueError(
                f"chamber '{self.id}': a corridor has no objective, so its enemies "
                "cannot gate a reward. Use an arena with objective 'kill_all'."
            )
        return self

    @model_validator(mode="after")
    def _features_need_room_beside_the_path(self):
        """A corridor is the only chamber type that may carry a feature —
        every other type has either a Check or a gating objective — and it
        is also the narrowest. One barely wider than its door is entirely
        walking lane, so a feature in it would end up in the masonry or
        across the doorway. Refused here rather than dropped by the
        builder: a silently discarded feature is a Zone that reads richer
        than it plays, and a refusal is something the repair loop can fix.
        """
        return self


class ArenaChamber(_WithEnemies):
    """Rectangular combat room. A boss room is an arena holding one brute."""
    type: Literal["arena"]
    # THE FIELD IS A SANITY CEILING; the RANGE is enforced where it
    # means something. A chamber naming no shell is held to
    # `PROCEDURAL_ARENA_*` by `validate_zone`; one naming a shell is
    # held to that shell's declared footprint, which is an equality and
    # therefore tighter than any range. Widening the field alone would
    # let a procedural room be 90 m across, and it cannot -- see
    # `_a_procedural_room_stays_in_the_builder's_range` there.
    width: float = Field(ge=C.PROCEDURAL_ARENA_MIN_SPAN,
                         le=C.MAX_AUTHORED_SPAN)
    depth: float = Field(ge=C.PROCEDURAL_ARENA_MIN_SPAN,
                         le=C.MAX_AUTHORED_SPAN)
    wall_height: float = Field(ge=C.PROCEDURAL_ARENA_MIN_HEIGHT,
                               le=C.MAX_AUTHORED_HEIGHT)
    objective: Literal["kill_all", "reach_reward"]
    enemies: tuple[EnemyGroup, ...] = Field(default=(), max_length=4)

    #: ROOM_GRAMMAR v0. Additive and optional, for the reason `features`
    #: and `activities` were: a Zone inside a save that predates the
    #: grammar is still a valid Zone, and a new REQUIRED field would fail
    #: every campaign in progress.
    elevation: ElevationBand | None = None

    @model_validator(mode="after")
    def _a_band_leaves_room_to_stand(self):
        """A gallery you cannot stand up on is a shelf.

        Checked here rather than in the builder because it is a property
        of the DESCRIPTION -- a Zone naming a 4 m gallery under a 5 m
        ceiling is describing somewhere the player cannot go, and the
        engine should never be handed one to build.
        """
        if self.elevation is None:
            return self
        # AND ITS RAMP FITS IN THE ROOM, which is the same kind of claim
        # and was the missing half of it: a band the player cannot stand
        # on and a band whose only way up runs out through the front wall
        # are both rooms nobody can use, described rather than built.
        why = band_ramp_fits(self.elevation, self.width, self.depth)
        if why:
            raise ValueError(f"chamber '{self.id}': {why}")
        # AND IT DOES NOT HUG A WALL WITH A DOORWAY IN IT. A `left`
        # band's deck reaches the left wall at `rise`, so a doorway cut
        # into that wall has a floor slab across it at whatever height
        # the band sits -- a hole the engine carves and the deck closes.
        blocked = f"side_{self.elevation.side}"
        for door in self.doors:
            if door.socket_id == blocked and door.usage != "SEALED":
                raise ValueError(
                    f"chamber '{self.id}': a {self.elevation.side} "
                    f"{self.elevation.kind} hugs the wall its "
                    f"'{blocked}' door is cut into, so its deck stands "
                    f"in that doorway")
        if self.elevation.kind != "gallery":
            return self
        clear = self.wall_height - self.elevation.rise
        if clear < HEADROOM:
            raise ValueError(
                f"a {self.elevation.rise:.1f}m gallery under a "
                f"{self.wall_height:.1f}m ceiling leaves {clear:.1f}m of "
                f"headroom; a player needs {HEADROOM:.1f}m to stand")
        return self


class PlatformPathChamber(_WithEnemies):
    """Base-movement platforming.

    `gap_size` and `vertical_step` are bounded JOINTLY: the reachable gap
    shrinks as the landing rises. v0.4 bounded them independently, so both
    could be maxed and the real margin was 1.17x rather than the 1.56x the
    flat-jump derivation advertised.
    """
    type: Literal["platform_path"]
    segment_count: int = Field(ge=3, le=8)
    gap_size: float = Field(ge=0.5, le=C.SAFE_BASE_JUMP_GAP)
    vertical_step: float = Field(ge=0.0, le=C.MAX_VERTICAL_STEP)
    objective: Literal["platform_to_goal"] = "platform_to_goal"
    enemies: tuple[EnemyGroup, ...] = Field(default=(), max_length=2)

    @model_validator(mode="after")
    def _gap_reachable_at_this_step(self):
        allowed = C.max_safe_gap(self.vertical_step)
        if self.gap_size > allowed:
            raise ValueError(
                f"chamber '{self.id}': gap_size {self.gap_size} exceeds {allowed}, "
                f"the furthest a base jump reaches landing {self.vertical_step}m "
                "higher. Lower gap_size or vertical_step."
            )
        return self


class TowerChamber(_WithEnemies):
    """Vertical traversal. The template always emits a base-movement route."""
    type: Literal["tower"]
    floors: int = Field(ge=C.TOWER_MIN_FLOORS, le=C.TOWER_MAX_FLOORS)
    objective: Literal["reach_reward", "kill_all"]
    enemies: tuple[EnemyGroup, ...] = Field(default=(), max_length=4)


class TreasureRoomChamber(ChamberBase):
    """Small safe reward room. Exactly one reward, never enemies."""
    type: Literal["treasure_room"]
    objective: Literal["reach_reward"] = "reach_reward"
    reward_location_id: int = Field(ge=C.FIRST_LOCATION_ID, le=C.LAST_UNIVERSE_ID)


Chamber = Annotated[
    Union[
        CorridorChamber, ArenaChamber, PlatformPathChamber,
        TowerChamber, TreasureRoomChamber,
    ],
    Field(discriminator="type"),
]


class FeaturedAcquisition(Strict):
    """D-1. The capability this Zone is built to hand the player, and the
    Check that hands it over.

    **This is a binding, not a subsystem.** Every part it joins already
    existed: AP allocates the location, `append_interpretation` folds the
    confirmed item into an Echo, `owned_capabilities` reads the fold, and
    `capability_guarantee` case C takes an `established_earlier` set that
    had no producer. This names which capability a Zone establishes so
    that set can be produced, and `established_in_zone` below produces it.

    **The foreign item is untouched.** Nothing here replaces, consumes or
    rewrites what Archipelago delivers: `EchoInterpretation` keeps
    `source_item_name`, `source_game` and `source_recipient_name`
    verbatim, and this only says which location the Zone is counting on.
    """
    #: What the player can DO afterwards. Same vocabulary an activity
    #: asks for, so a Zone cannot feature something no activity can want.
    capability: ActivityCapability
    #: The allocated Check that grants it. Must be one AP actually gave
    #: this Zone -- that is what makes the promise match a pre-seed
    #: guarantee rather than a local wish.
    location_id: int = Field(ge=C.FIRST_LOCATION_ID, le=C.LAST_UNIVERSE_ID)
    #: The room carrying that Check.
    room_id: str = _ID


def established_in_zone(zone) -> tuple[str, ...]:
    """D-2. The producer `capability_guarantee` case C never had.

    `mechanics.capability_guarantee` takes `established_earlier` and its
    own comment records that nothing produced that set, so case C could
    not fire and a Zone could never prove "you will have it because you
    get it here". This is that set, and it is deliberately narrow: a Zone
    establishes exactly what it features, never what it merely contains.
    """
    featured = getattr(zone, "featured_acquisition", None)
    return () if featured is None else (featured.capability,)


class RailDock(Strict):
    """A place the carrier can be parked, in a room that exists."""
    dock_id: str = _ID
    #: THE ZONE'S OWN ROOM-ID CONSTRAINT, not a looser one. Left as a
    #: free `max_length=64` string this is a field Epsilon can fill with
    #: anything, which `test_epsilon_vocabulary` refuses -- correctly:
    #: a room id that resolves to nothing is a dock nobody can reach.
    room_id: str = _ID


class RailSpan(Strict):
    """One link between two docks, and the control that commissions it.

    `latch_id` is the persistence handle: a commissioned span is the
    repair that survives leaving and coming back, and it is recorded
    through the same latch machinery a physics package already uses.
    """
    span_id: str = _ID
    from_dock: str = _ID
    to_dock: str = _ID
    #: The room holding the alignment control that commissions this span.
    #: `None` means the span ships commissioned and needs no control.
    control_room_id: str | None = Field(
        default=None, min_length=1, max_length=24, pattern=r"^[a-z0-9_]+$")
    latch_id: str = _ID
    #: Whether the player must cross this span to finish the Zone. THE
    #: REASON THIS IS NOT A FEATURE: §13.2 would forbid exactly this.
    mandatory: bool = False

    @model_validator(mode="after")
    def _a_span_joins_two_different_docks(self):
        if self.from_dock == self.to_dock:
            raise ValueError(
                f"span '{self.span_id}' leaves and arrives at "
                f"'{self.from_dock}'")
        return self


class RailNetwork(Strict):
    """The docks and spans of one railway inside one Zone.

    **`docks` is the ROUTE ORDER, not a collection** -- F-22 question 2.
    The engine reads the declaration order as the carrier's route order
    because it is the only ordering available, and nothing in the schema
    said so. It says so here, and `_a_span_joins_docks_the_route_visits
    _in_turn` below is defined against it: without a stated order,
    "consecutive" would not mean anything.
    """
    network_id: str = _ID
    docks: tuple[RailDock, ...] = Field(min_length=2, max_length=8)
    spans: tuple[RailSpan, ...] = Field(min_length=1, max_length=8)
    #: Where the carrier parks. `None` means the first dock, which is
    #: exactly what `RailJunction.park` already does -- F-22 question 3
    #: turns an engine assumption about a Zone's intent into a Zone's
    #: declaration, and keeps the behaviour it was assuming.
    home_dock: str | None = Field(
        default=None, min_length=1, max_length=24, pattern=r"^[a-z0-9_]+$")

    @model_validator(mode="after")
    def _every_span_joins_docks_this_network_declares(self):
        known = {d.dock_id for d in self.docks}
        if len(known) != len(self.docks):
            raise ValueError(f"network '{self.network_id}' repeats a dock id")
        for span in self.spans:
            missing = {span.from_dock, span.to_dock} - known
            if missing:
                raise ValueError(
                    f"span '{span.span_id}' names dock(s) "
                    f"{sorted(missing)} that network "
                    f"'{self.network_id}' does not declare")
        ids = [s.span_id for s in self.spans]
        if len(set(ids)) != len(ids):
            raise ValueError(f"network '{self.network_id}' repeats a span id")
        latches = [s.latch_id for s in self.spans]
        if len(set(latches)) != len(latches):
            raise ValueError(
                f"network '{self.network_id}' reuses a latch id; a latch is "
                "the handle a commissioned span persists under and two spans "
                "sharing one cannot be told apart on reload")
        if self.home_dock is not None and self.home_dock not in known:
            raise ValueError(
                f"network '{self.network_id}' parks at dock "
                f"'{self.home_dock}', which it does not declare")
        return self

    @model_validator(mode="after")
    def _a_span_joins_docks_the_route_visits_in_turn(self):
        """F-22 question 1, answered YES -- and the reason matters.

        The schema described a GRAPH: any two of up to eight docks.
        `RailCarrier` runs ONE ORDERED ROUTE, a link between each
        consecutive pair, so a span from the first dock to the third has
        no link to commission. The engine refuses it by name rather than
        routing through the dock in between, which would be the engine
        deciding what the Zone meant.

        **A schema that can express what no runtime can build hands the
        engine a decision it must not make.** So the restriction belongs
        here, where a Zone is refused before it is ever composed, and
        the engine's refusal becomes unreachable from a validated Zone
        while staying in place for a hand-built one.

        **THIS DESCRIBES THE IMPLEMENTATION, NOT THE DESIGN** (owner
        correction 3, 2026-09-22). It is an accurate statement of what
        `RailCarrier` runs today -- one ordered route, a link between
        each consecutive pair -- and it **does not retire branching or
        switchable railway configurations from the accepted design**.
        They remain accepted and unbuilt, which is a scoping fact rather
        than a decision against them.

        Two things make that distinction easy to lose, so both are
        written down. `RailJunction` is **not a track fork**: it is one
        railway's persistent machinery and the seam keeping four
        lifetimes apart, so a Zone naming a "junction" today is naming a
        control point, not a branch. And relaxing this rule later
        invalidates no Zone that ever satisfied it, which is why YES is
        the answer that can be taken back while NO would have left
        unbuildable Zones composable in the meantime.

        What Blindside's selected configuration needs is already served:
        S1-S2-S3 is a linear three-dock route, and its acquisition
        branch is **walked, not ridden** (`railway_scenario._branch`).
        `docs/ledgers/HUGE_BATCH_LEDGER.md` DESS-01 lists the support a
        branching or switchable configuration would still require.
        """
        order = [d.dock_id for d in self.docks]
        at = {dock_id: i for i, dock_id in enumerate(order)}
        seen_pairs: dict[tuple[str, str], str] = {}
        for span in self.spans:
            if span.from_dock not in at or span.to_dock not in at:
                continue         # already refused above, by name
            step = abs(at[span.from_dock] - at[span.to_dock])
            if step != 1:
                between = order[
                    min(at[span.from_dock], at[span.to_dock]) + 1:
                    max(at[span.from_dock], at[span.to_dock])]
                raise ValueError(
                    f"span '{span.span_id}' joins '{span.from_dock}' and "
                    f"'{span.to_dock}', which the route visits {step} docks "
                    f"apart with {sorted(between)} in between; the carrier "
                    "runs one ordered route with a link between each "
                    "consecutive pair, so this span has no link to "
                    "commission")
            pair = (span.from_dock, span.to_dock) if (
                at[span.from_dock] < at[span.to_dock]) else (
                span.to_dock, span.from_dock)
            if pair in seen_pairs:
                raise ValueError(
                    f"spans '{seen_pairs[pair]}' and '{span.span_id}' both "
                    f"join '{pair[0]}' and '{pair[1]}'; consecutive docks "
                    "have ONE link between them, so the second span has no "
                    "link of its own to commission")
            seen_pairs[pair] = span.span_id
        return self


#: One state name of a Zone-state variable. Same charset as every other
#: id here, for the same reason: a free string is a field Epsilon can
#: fill with anything.
_STATE_NAME = Annotated[str, Field(min_length=1, max_length=24,
                                   pattern=r"^[a-z0-9_]+$")]

#: A room id as a tuple ELEMENT. `_ID` is a `Field`, which annotates a
#: model attribute; a tuple's element type needs the `Annotated` form.
_ROOM_ID = Annotated[str, Field(min_length=1, max_length=24,
                                pattern=r"^[a-z0-9_]+$")]


class ZoneStateSetter(Strict):
    """Where the player performs the interaction, and what it may select.

    D-8 §4, answering Prod's §3 question 2. §19.7 is explicit that the
    crossing happens because **the player performs a setter package's
    interaction** -- so a setter has a room, and that room is the one
    the player has to be standing in.
    """
    room_id: str = _ID
    #: Which states this control can choose. A subset of the variable's
    #: `states`, and the field §4.0's lifetime rule is checked against.
    selects: tuple[_STATE_NAME, ...] = Field(min_length=1, max_length=4)
    #: What OPERATING this control requires, over and above standing in
    #: its room. `None` means reaching the room is enough.
    #:
    #: **OWNER CORRECTION 2, 2026-09-22, and it was a real defect.**
    #: The search granted a setter to anyone who could reach its room,
    #: so Blindside's overhead gantry -- a control at 4.6 m with no
    #: mantle and no stairs -- became operable in logic the moment the
    #: player walked in underneath it, grapple or no grapple. Room
    #: membership is not operability, and a search that assumes it is
    #: over-approximates in the player's favour, which is the direction
    #: nothing ever fails in.
    #:
    #: **What this field is and is not.** It is the DECLARATION of what
    #: operating the control costs, and `reachability` honours it. It is
    #: NOT evidence that the control really is out of reach: that the
    #: gantry stands at 4.6 m and a baseline jump tops out at 1.33 m is
    #: a physical measurement, and it belongs to the engine lane. The
    #: two are kept apart deliberately -- a declaration the world does
    #: not match is a lie in either direction.
    capability: Capability | None = None


class ZoneStateReader(Strict):
    """A room whose local mechanism responds to the variable.

    D-8 §4, answering Prod's §3 question 3. **The reader names the
    variable and never the setter's node**, which is what makes the
    stale reference the owner warned about impossible to write rather
    than merely discouraged -- see `Zone._a_reader_is_somewhere_else`.
    """
    room_id: str = _ID
    #: The local mechanism this variable drives, in that room. Room-layer
    #: per §19.7: the Zone state is read, the mechanism is local.
    mechanism: str = _ID
    #: The states in which the mechanism is driven.
    when: tuple[_STATE_NAME, ...] = Field(min_length=1, max_length=4)


class ZoneStateVariable(Strict):
    """One declared cross-room relationship: `ZoneState.macro`, named.

    The bridge has budgeted macro variables since `physics.py` was
    written -- `state_vector_product` multiplies a tuple of state counts
    against §4.10's bound -- and has never been able to NAME one. This
    is the declaration that arithmetic was waiting for.

    **The three-step crossing, as data** (D-8 §2, from §19.7): a player
    interaction in `setter.room_id` writes `variable_id`, and each
    reader's room graph reads it. Rooms never address each other at any
    step, which is why the forbidden global signal bus is not ruled out
    by a rule here -- it is unrepresentable.
    """
    variable_id: str = _ID
    #: 2 to 4, exactly §4.10's per-variable range as `state_vector_product`
    #: already assumes.
    states: tuple[_STATE_NAME, ...] = Field(min_length=2, max_length=4)
    initial: _STATE_NAME
    #: §4.0. NOT a label beside the declaration -- a claim about it, which
    #: `_the_lifetime_agrees_with_what_the_setter_can_do` checks.
    lifetime: Literal["reversible", "permanent"]
    setter: ZoneStateSetter
    readers: tuple[ZoneStateReader, ...] = Field(min_length=1, max_length=4)
    #: `RailSpan.mandatory`'s question, in its own words and for its own
    #: reason: §13.2 forbids a feature from lying on the mandatory path,
    #: so a mandatory cross-room relationship cannot be a `feature:` tag
    #: either. Hence first class, exactly as the railway is.
    mandatory: bool = False

    @model_validator(mode="after")
    def _states_are_distinct_and_contain_everything_named(self):
        if len(set(self.states)) != len(self.states):
            raise ValueError(
                f"variable '{self.variable_id}' repeats a state name; two "
                "states spelled the same cannot be told apart")
        known = set(self.states)
        if self.initial not in known:
            raise ValueError(
                f"variable '{self.variable_id}' starts in '{self.initial}', "
                f"which is not one of its states {sorted(known)}")
        stray = set(self.setter.selects) - known
        if stray:
            raise ValueError(
                f"variable '{self.variable_id}' has a setter selecting "
                f"{sorted(stray)}, which it does not declare")
        for r in self.readers:
            stray = set(r.when) - known
            if stray:
                raise ValueError(
                    f"variable '{self.variable_id}' has a reader in room "
                    f"'{r.room_id}' responding to {sorted(stray)}, which it "
                    "does not declare")
        return self

    @model_validator(mode="after")
    def _the_lifetime_agrees_with_what_the_setter_can_do(self):
        """D-8 §4.0 -- the rule that makes the silent latch unwritable.

        The clarification says: do not silently replace a live
        requirement with a permanent latch. A label saying `reversible`
        beside a setter that can only ever move one way IS that
        replacement, and nothing but a reviewer's attention would have
        caught it. So lifetime is proven from the declaration:

        - `permanent`  -- exactly one selectable state, and not the
          initial one. Monotone by construction, which is §5.5's latch
          DERIVED rather than asserted.
        - `reversible` -- the initial state is selectable, and at least
          one other, so a reversal OPERATION exists.

        **OWNER CORRECTION 2: an operation existing is not a reversal
        the player can reach.** An earlier revision of this docstring
        said "the player can always put it back, so a reversible
        variable cannot strand you". That is false and it was the
        dangerous direction of false. `selects` says the control CAN
        choose the initial state; whether the player can get back to
        that control and operate it is a question about the route and
        about `setter.capability`, and it is answered by
        `topology.reachability` -- which is why R-subset-E still has to
        run over the macro component instead of being argued away by
        this field.
        """
        selects = set(self.setter.selects)
        if self.lifetime == "permanent":
            if len(selects) != 1 or self.initial in selects:
                raise ValueError(
                    f"variable '{self.variable_id}' is declared permanent, "
                    f"but its setter selects {sorted(selects)}; a permanent "
                    "variable is monotone, so its setter chooses exactly one "
                    f"state and it is not the initial '{self.initial}'")
        else:
            if self.initial not in selects or len(selects) < 2:
                raise ValueError(
                    f"variable '{self.variable_id}' is declared reversible, "
                    f"but its setter selects {sorted(selects)} and cannot "
                    f"return it to '{self.initial}'; that is a permanent "
                    "variable wearing a reversible label, which is exactly "
                    "the silent latch this rule exists to refuse")
        return self

    @model_validator(mode="after")
    def _at_least_one_reader_is_somewhere_else(self):
        """What makes the relationship CROSS-room rather than merely declared.

        **OWNER CORRECTION 4, 2026-09-22.** The first cut of this rule
        refused *any* reader in the setter's room, which turned an
        acceptance-case requirement into a global content restriction:
        *"a cross-room relationship must demonstrate a remote
        consequence, but that does not require banning additional
        readers in its source room."*

        What must hold is the claim the declaration actually makes: a
        remote consequence EXISTS, so at least one reader is somewhere
        else. A lever that also drives something where the player is
        standing -- a local indicator, a hatch beside it, the gantry's
        own cradle -- is ordinary content, and it is the LEGIBLE kind: a
        control whose only visible effect is in a room you cannot see is
        worse to play, not better.

        *Both lanes wrote this rule independently and identically; the
        prose and the message below are the better halves of the two.*
        """
        if all(r.room_id == self.setter.room_id for r in self.readers):
            raise ValueError(
                f"variable '{self.variable_id}' has every reader in its "
                f"setter's room '{self.setter.room_id}'; that is a "
                "room-local mechanism with Zone-scope machinery wrapped "
                "around it, not a cross-room relationship. At least one "
                "reader must be somewhere else; others may be here")
        seen: set[tuple[str, str]] = set()
        for r in self.readers:
            if (r.room_id, r.mechanism) in seen:
                raise ValueError(
                    f"variable '{self.variable_id}' drives mechanism "
                    f"'{r.mechanism}' in room '{r.room_id}' twice")
            seen.add((r.room_id, r.mechanism))
        return self


class TransportedObject(Strict):
    """P16 / D-8 lifetime 5. An object the player carries between rooms.

    **Neither macro state nor a latch**, which is why §19.7 does not
    cover it: rooms may not write macro state, and an object is not
    monotone -- you can carry it back. Two settled rules meet here and
    only one of them needed an amendment:

    - **Persistence was already settled by §10.5.** `allowed_volume` is
      a list of rooms and a multi-room carryable is `ZONE_PERSISTENT`.
      No amendment, and the union's own example sentence is a `BURNING`
      power cell carried three rooms to a generator.
    - **Authority was not.** Prod's `D8_CROSS_ROOM_PROD` §4 question 1,
      accepted and narrowed in D-8 §11.1: a transported object is
      room-layer state **whose owning room is its current room**, and
      crossing a boundary is a TRANSFER rather than a write to the
      machine layer. §19.7 rule 2 stays intact.

    **What is NOT here, deliberately.** The object's Statuses. §5.1 puts
    every `ActiveStatus` in `EPHEMERAL`, so a `BURNING` cell that is
    carried three rooms arrives having been carried three rooms and not
    still burning -- unless something sets it alight again. Persisting
    the Status would make a temporary effect a permanent fact, which is
    §3.1's rule in the one place it is easiest to break by accident.
    """
    object_id: str = _ID
    #: §10.5's list of rooms. At least two, or it is not transported --
    #: an object that may only ever be in one room is room-local and
    #: needs none of this.
    allowed_volume: tuple[_ROOM_ID, ...] = Field(min_length=2, max_length=8)
    #: Where it starts, and where a recovery puts it back.
    home_room_id: str = _ID
    #: Whether a puzzle on the mandatory path needs it. §5.1: `required`
    #: or constrained configurations are `PUZZLE_LOCAL`, everything else
    #: is `EPHEMERAL` -- so this decides whether losing it matters.
    required: bool = False

    @model_validator(mode="after")
    def _home_is_inside_the_volume(self):
        if self.home_room_id not in self.allowed_volume:
            raise ValueError(
                f"object '{self.object_id}' comes home to "
                f"'{self.home_room_id}', which is not in the volume it is "
                f"allowed in ({sorted(self.allowed_volume)}); a recovery "
                "would put it somewhere it may not be")
        if len(set(self.allowed_volume)) != len(self.allowed_volume):
            raise ValueError(
                f"object '{self.object_id}' repeats a room in its volume")
        return self


class Zone(Strict):
    #: Still 7, and deliberately. The Zone contract did not change in v0.8 —
    #: Echoes 2.0 changes what an Echo means, not what a Zone is — and
    #: bumping a version to match its neighbours would say a change happened
    #: where none did.
    schema_version: Literal[7] = 7
    zone_id: str = _ID
    display_name: str = Field(min_length=1, max_length=C.MAX_TEXT_LEN)
    target_game: str = Field(min_length=1, max_length=C.MAX_AP_STRING_LEN)
    theme: Theme
    designer_note: str | None = Field(default=None, max_length=C.MAX_DESIGNER_NOTE_LEN)
    featured_echo_ids: tuple[_ECHO_ID, ...] = Field(default=(), max_length=4)
    chambers: tuple[Chamber, ...] = Field(
        min_length=C.ZONE_MIN_CHAMBERS, max_length=C.ZONE_MAX_CHAMBERS
    )

    #: THE TOPOLOGY, AS DATA. `chambers`'s list order used to be the
    #: graph, which is why nothing could express a junction: a list has
    #: no room for a third neighbour.
    #:
    #: Additive and optional. A Zone carrying no edges still means the
    #: chain its order describes, so every Zone already inside a save
    #: stays valid and `schema_version` stays 7.
    edges: tuple[TopologyEdge, ...] = Field(default=(), max_length=32)

    #: Return plugs. A TRAVERSAL_ONLY edge is carried here and never by
    #: a door, because a door assignment consumes a joining socket and a
    #: plug must not.
    plugs: tuple[PlugAssignment, ...] = Field(default=(), max_length=8)

    #: D-4. Rail content a composed Zone declares, so a junction can be
    #: ASKED FOR rather than invented.
    #:
    #: **Why this is not a `feature:` tag.** A physics package binds to
    #: `feature:<tag>` or `shell:<id>` (`layout._content_refs`), and
    #: §13.2 forbids a feature from lying on the mandatory path, hosting
    #: a reward, an exit or an objective. A rail span the player must
    #: cross is exactly a thing on the mandatory path, so declaring it as
    #: a feature would either break §13.2 or make the span optional --
    #: and an optional span is not a railway. Hence first class.
    #:
    #: Shaped after what `RailJunction` already runs, not after a new
    #: idea: docks it parks at, spans between them, one alignment control
    #: per span and a latch per span.
    rail_networks: tuple[RailNetwork, ...] = Field(default=(), max_length=2)

    #: D-1. The capability this Zone is built to grant, and where.
    #: Optional: a Zone that features nothing establishes nothing, which
    #: is every Zone composed before this.
    featured_acquisition: FeaturedAcquisition | None = None

    #: D-8. The cross-room relationships this Zone declares -- the
    #: `ZoneState.macro` of §5.1, which `physics.state_vector_product`
    #: has budgeted since before anything could name one.
    #:
    #: Additive and optional, so every Zone composed before this still
    #: means what it meant and `schema_version` stays 7. Four is the
    #: bound: four variables of four states is 256 configurations, which
    #: leaves §4.10's 4096 room for the latches that compete for the
    #: same budget rather than spending it all here.
    zone_state: tuple[ZoneStateVariable, ...] = Field(
        default=(), max_length=4)

    #: P16. Objects the player may carry from room to room. Additive and
    #: optional: a Zone declaring none behaves exactly as before.
    transported_objects: tuple[TransportedObject, ...] = Field(
        default=(), max_length=4)

    @model_validator(mode="after")
    def _zone_state_names_rooms_this_zone_has(self):
        """D-8 §5's generation constraints, the half a schema can settle.

        A setter in a room that does not exist is a control nobody can
        reach; a reader in one is a consequence nobody can see.
        """
        if not self.zone_state:
            return self
        rooms = {c.id for c in self.chambers}
        seen: set[str] = set()
        for v in self.zone_state:
            if v.variable_id in seen:
                raise ValueError(
                    f"two Zone-state variables are both called "
                    f"'{v.variable_id}'; the id is the handle a reader binds "
                    "to, so two of them cannot be told apart")
            seen.add(v.variable_id)
            if v.setter.room_id not in rooms:
                raise ValueError(
                    f"variable '{v.variable_id}' has its setter in room "
                    f"'{v.setter.room_id}', which this Zone does not have")
            for r in v.readers:
                if r.room_id not in rooms:
                    raise ValueError(
                        f"variable '{v.variable_id}' has a reader in room "
                        f"'{r.room_id}', which this Zone does not have")

        # §4.10's budget, through the function that has computed it all
        # along. Latches are counted where they are known; here the
        # claim is only that the declared variables alone do not spend
        # the whole vector.
        product = state_vector_product(
            macro_variables=tuple(len(v.states) for v in self.zone_state))
        if product > STATE_VECTOR_BOUND:
            raise ValueError(
                f"the declared Zone-state variables alone are {product} "
                f"configurations, past §4.10's {STATE_VECTOR_BOUND} bound")
        return self

    @model_validator(mode="after")
    def _transported_objects_name_rooms_this_zone_has(self):
        """An object allowed into a room that does not exist is a volume
        nobody can carry it through."""
        if not self.transported_objects:
            return self
        rooms = {c.id for c in self.chambers}
        seen: set[str] = set()
        for obj in self.transported_objects:
            if obj.object_id in seen:
                raise ValueError(
                    f"two transported objects are both called "
                    f"'{obj.object_id}'; the id is what a save records a "
                    "room against, so two of them cannot be told apart")
            seen.add(obj.object_id)
            missing = sorted(set(obj.allowed_volume) - rooms)
            if missing:
                raise ValueError(
                    f"object '{obj.object_id}' is allowed into {missing}, "
                    "which this Zone does not have")
        return self

    @model_validator(mode="after")
    def _route_conditions_name_state_this_zone_declares(self):
        """An edge gated on a variable nobody declares is a locked route
        with no key, and nothing in the search would ever open it.

        Checked even when `zone_state` is empty, which is the case that
        matters: an edge carrying a condition in a Zone that declares no
        variables is the whole failure in miniature.
        """
        by_id = {v.variable_id: v for v in self.zone_state}
        for e in self.edges:
            for c in e.requires_state:
                var = by_id.get(c.variable_id)
                if var is None:
                    raise ValueError(
                        f"edge '{e.edge_id}' requires Zone-state variable "
                        f"'{c.variable_id}', which this Zone does not declare")
                if c.state not in var.states:
                    raise ValueError(
                        f"edge '{e.edge_id}' requires '{c.variable_id}' in "
                        f"state '{c.state}', which that variable does not "
                        f"have; it has {sorted(var.states)}")
        return self

    @model_validator(mode="after")
    def _the_graph_and_the_assignments_agree(self):
        """Invariants 3, 4, 6 and 7 of `09_ROOM_CONTRACT.md` §3.3.

        These are the ones a schema can settle. Invariant 1 needs the
        shell catalog and invariant 5 needs a graph search, so both live
        with the code that has what they need.

        A Zone with no edges skips all of it: there is no graph to
        disagree with.
        """
        if not self.edges and not self.plugs:
            for c in self.chambers:
                if c.doors:
                    raise ValueError(
                        f"chamber '{c.id}' assigns doors but the Zone "
                        "declares no edges; an assignment with no graph "
                        "names routes that do not exist")
            return self

        rooms = {c.id for c in self.chambers}
        by_id: dict[str, TopologyEdge] = {}
        for e in self.edges:
            if e.edge_id in by_id:
                raise ValueError(f"duplicate edge_id '{e.edge_id}'")
            by_id[e.edge_id] = e
            missing = [r for r in e.rooms if r not in rooms]
            if missing:
                raise ValueError(
                    f"edge '{e.edge_id}' names unknown room(s) {missing}")

        # Which doors and plugs claim which edge.
        door_ends: dict[str, list[tuple[str, DoorAssignment]]] = {}
        for c in self.chambers:
            for d in c.doors:
                if d.edge_id is None:
                    continue
                if d.edge_id not in by_id:
                    raise ValueError(
                        f"chamber '{c.id}' door '{d.socket_id}' names "
                        f"unknown edge '{d.edge_id}'")
                door_ends.setdefault(d.edge_id, []).append((c.id, d))

        # ONE ZONE EXIT, ON THE ROOM THAT ACTUALLY ENDS THE CHAIN.
        #
        # `ZONE_EXIT` is passable geometry that names no edge, which
        # makes it the one door nothing else constrains -- so it is
        # constrained here, or it becomes a licence to open any wall.
        # The engine appends ONE exit room, off the LAST room on the
        # chain; a second way out is a hole onto nothing, and one on a
        # room the chain continues through is a hole into the next
        # room's approach.
        way_out = [(c.id, d) for c in self.chambers for d in c.doors
                   if d.usage == "ZONE_EXIT"]
        if len(way_out) > 1:
            raise ValueError(
                "%d doors are ZONE_EXIT (%s); the engine appends one "
                "exit room, so a Zone has one way out"
                % (len(way_out), ", ".join(
                    f"{r}/{d.socket_id}" for r, d in way_out)))
        if way_out:
            host = way_out[0][0]
            # A room the chain leaves by a JOINED edge is not the end of
            # it. `departures` is not on the wire, so this is read off
            # the edges themselves: any JOINED edge whose `room_a` is
            # this room and whose door there is the `exit` socket.
            onward = [e.edge_id for e in self.edges
                      if e.realization == "JOINED" and e.room_a == host
                      and any(d.socket_id == "exit" and d.edge_id
                              == e.edge_id
                              for c in self.chambers if c.id == host
                              for d in c.doors)]
            if onward:
                raise ValueError(
                    f"room '{host}' carries the ZONE_EXIT and also "
                    f"departs by edge(s) {onward}; the way out belongs "
                    "to the room the chain ENDS on")

        plug_of: dict[str, PlugAssignment] = {}
        for pl in self.plugs:
            if pl.edge_id in plug_of:
                raise ValueError(
                    f"edge '{pl.edge_id}' carries two plugs")
            if pl.edge_id not in by_id:
                raise ValueError(
                    f"plug names unknown edge '{pl.edge_id}'")
            if pl.room_id not in rooms:
                raise ValueError(
                    f"plug '{pl.edge_id}' stands in unknown room "
                    f"'{pl.room_id}'")
            plug_of[pl.edge_id] = pl

        for e in self.edges:
            ends = door_ends.get(e.edge_id, [])
            if e.realization == "JOINED":
                if e.edge_id in plug_of:
                    raise ValueError(
                        f"JOINED edge '{e.edge_id}' carries a plug; a "
                        "plug realizes no geometry and cannot serve one")
                if len(ends) != 2:
                    raise ValueError(
                        f"JOINED edge '{e.edge_id}' is named by "
                        f"{len(ends)} door(s), not 2")
                if {r for r, _ in ends} != set(e.rooms):
                    raise ValueError(
                        f"JOINED edge '{e.edge_id}' joins {e.rooms} but "
                        f"its doors sit in {sorted(r for r, _ in ends)}")
            else:  # TRAVERSAL_ONLY
                if ends:
                    raise ValueError(
                        f"TRAVERSAL_ONLY edge '{e.edge_id}' is named by a "
                        "door; a plug consumes no joining socket, and "
                        "carrying one on a door would cut an aperture "
                        "the room never asked for")
                if e.edge_id not in plug_of:
                    raise ValueError(
                        f"TRAVERSAL_ONLY edge '{e.edge_id}' has no plug; "
                        "nothing would carry the player across it")

        # §11.2: the chain's arrival is the room's INBOUND edge, and
        # §11.1/§6.5 say a room is the `room_b` of at most one JOINED
        # edge because the engine keys its route record by room. A
        # selector pointing the other way would have the engine place
        # the room by the opening it leaves through.
        for c in self.chambers:
            if c.arrive_edge is not None:
                e = by_id[c.arrive_edge]
                if e.realization != "JOINED":
                    # BACKSTOP, unreachable by construction: a selector
                    # must name an edge one of this room's open doors
                    # carries, and a door carrying a TRAVERSAL_ONLY edge
                    # is refused above. Kept because the two rules that
                    # make it unreachable live in different models.
                    raise ValueError(
                        f"chamber '{c.id}' arrives by '{e.edge_id}', "
                        f"which is {e.realization}; a plug carries no "
                        "geometry to arrive through")
                if e.room_b != c.id:
                    raise ValueError(
                        f"chamber '{c.id}' names '{e.edge_id}' as its "
                        f"arrival, but that edge runs {e.room_a} -> "
                        f"{e.room_b}; the arrival is the inbound edge")
            if c.depart_edge is not None:
                e = by_id[c.depart_edge]
                if e.realization != "JOINED":
                    raise ValueError(
                        f"chamber '{c.id}' departs by '{e.edge_id}', "
                        f"which is {e.realization}")
                if e.room_a != c.id:
                    raise ValueError(
                        f"chamber '{c.id}' names '{e.edge_id}' as its "
                        f"departure, but that edge runs {e.room_a} -> "
                        f"{e.room_b}; the departure is the outbound edge")

        # Invariant 7: anchors are names the engine can resolve. The
        # bridge checks the FORM and the room id; whether the anchor
        # exists in the built scene is the engine's answer, returned as
        # evidence.
        #
        # `:return` is ADDITIVE and `:arrival` is kept. Every save that
        # already holds a branched Zone names `:arrival` as its plug's
        # source, and `ZoneRecord.zone` is a typed `Zone` — so refusing
        # that spelling here would refuse to load those saves. The
        # placement defect it represents is caught where it can be
        # caught safely: `layout.validate`, which a committed manifest
        # never runs again.
        for pl in self.plugs:
            for anchor in (pl.source_anchor, pl.destination):
                if anchor in ("zone_start", "last_large_room"):
                    continue
                room_anchor = next(
                    (suffix for suffix in ROOM_ANCHOR_KINDS
                     if anchor.startswith("room:")
                     and anchor.endswith(f":{suffix}")), None)
                if room_anchor is not None:
                    rid = anchor[len("room:"):-len(f":{room_anchor}")]
                    if rid not in rooms:
                        raise ValueError(
                            f"plug '{pl.edge_id}' names anchor '{anchor}' "
                            f"in unknown room '{rid}'")
                    continue
                raise ValueError(
                    f"plug '{pl.edge_id}' names anchor '{anchor}', which "
                    "is not a form the engine resolves")

        # Invariant 6: a LOCKED door's key must exist somewhere in the
        # Zone. Whether it is REACHABLE before its own lock is a graph
        # question and lives in `reachability`.
        declared = {k.key_id for c in self.chambers for k in c.keys}
        for c in self.chambers:
            for d in c.doors:
                if d.key_id and d.key_id not in declared:
                    raise ValueError(
                        f"chamber '{c.id}' door '{d.socket_id}' is locked "
                        f"by key '{d.key_id}', which no room holds")

        # Invariant 8: a procedural room's unused joining sockets are
        # declared SEALED, never left unmentioned. "Unmentioned" is
        # exactly how an unaudited hole gets into a wall.
        #
        # TWO SETS, AND THEY ARE DIFFERENT SETS. The NAME must be one a
        # procedural room can be given — the full vocabulary, because a
        # Zone composed before the capacity was measured holds
        # `platform_path` rooms with side doors and those saves must
        # still load. What must be MENTIONED is only what the room's
        # producer can carry: a `platform_path` composed today names
        # `entry` and `exit`, and demanding two more from it would be
        # demanding it declare doors it cannot build.
        #
        # So this permits both shapes and neither is silence. What stops
        # a NEW proposal joining through a side the producer does not
        # build is `topology._sockets_for`, which never offers one, and
        # `_the_composer_assigns_only_what_a_room_carries` there, which
        # fails loudly if that ever drifts.
        for c in self.chambers:
            if not c.doors or getattr(c, "shell_id", None):
                continue
            named = {d.socket_id for d in c.doors}
            unknown = named - set(PROCEDURAL_SOCKETS)
            if unknown:
                raise ValueError(
                    f"chamber '{c.id}' assigns socket(s) {sorted(unknown)} "
                    "that a procedural room does not declare")
            # Audited against what this room's OWN TYPE can hold, not
            # against the four a flat room has, so a `platform_path`
            # owes a mention for `entry` and `exit` and nothing else.
            #
            # A socket the type cannot hold is NOT refused here, and
            # deliberately. This validator runs on load, and every Zone
            # composed before the capacity was corrected assigned side
            # doors to platform courses -- refusing them here would make
            # a save holding one unreadable rather than repairable. The
            # refusal belongs where a proposal is judged and repaired:
            # `validate_zone`, `_a_room_may_not_use_a_doorway_it_cannot_hold`.
            supported = procedural_sockets_for(c.type)
            silent = set(supported) - named
            if silent:
                raise ValueError(
                    f"chamber '{c.id}' leaves joining socket(s) "
                    f"{sorted(silent)} unmentioned; an unused socket is "
                    "declared SEALED so it is measured, never omitted")
        return self

    # NOTE: no `required_echo_ids`, and no field anywhere in this schema can
    # express a mandatory Echo requirement. Structural, not a rule.

    @model_validator(mode="after")
    def _the_featured_acquisition_is_somewhere_real(self):
        """A featured capability the Zone cannot actually hand over is a
        promise `capability_guarantee` would honour and the player would
        not receive.

        Two facts, both checkable here: the room exists, and it really
        carries that Check. `reward_ids` is the canonical view -- reading
        `reward_location_id` alone would miss a multi-Check room and call
        a true promise false.
        """
        featured = self.featured_acquisition
        if featured is None:
            return self
        room = next((c for c in self.chambers if c.id == featured.room_id),
                    None)
        if room is None:
            raise ValueError(
                f"featured acquisition names room '{featured.room_id}', "
                "which this Zone does not have")
        if featured.location_id not in room.reward_ids:
            raise ValueError(
                f"featured acquisition puts Check {featured.location_id} in "
                f"room '{featured.room_id}', which carries "
                f"{list(room.reward_ids)}")
        return self

    @model_validator(mode="after")
    def _rail_networks_name_rooms_this_zone_has(self):
        """A dock in a room that does not exist is a junction nobody can
        reach, and the engine must not invent the room to fix it."""
        rooms = {c.id for c in self.chambers}
        seen: set[str] = set()
        for net in self.rail_networks:
            if net.network_id in seen:
                raise ValueError(
                    f"two rail networks are both called '{net.network_id}'")
            seen.add(net.network_id)
            for dock in net.docks:
                if dock.room_id not in rooms:
                    raise ValueError(
                        f"rail dock '{dock.dock_id}' names room "
                        f"'{dock.room_id}', which this Zone does not have")
            for span in net.spans:
                if (span.control_room_id is not None
                        and span.control_room_id not in rooms):
                    raise ValueError(
                        f"span '{span.span_id}' puts its control in room "
                        f"'{span.control_room_id}', which this Zone does "
                        "not have")
        return self

    @model_validator(mode="after")
    def _zone_wide_limits(self):
        ids = [c.id for c in self.chambers]
        if len(set(ids)) != len(ids):
            raise ValueError("duplicate chamber id")

        # The PERFORMANCE ceiling only. How many enemies a Zone may hold
        # by DESIGN depends on its content budget, which is campaign
        # config and not visible from inside a model -- that check lives
        # in `validate_zone`, which has it.
        #
        # Splitting them this way is the point of CAMPAIGN_SCALE.md 8: a
        # design that wants more than the engine can hold is wrong about
        # the target machine and should fail here regardless of budget,
        # while a design that merely wants more than its Zone was paid
        # for is a budget question.
        total = sum(c.enemy_total for c in self.chambers)
        if total > C.MAX_ENEMIES_SPAWNED_CAP:
            raise ValueError(
                f"zone instantiates {total} enemies, past the engine cap "
                f"of {C.MAX_ENEMIES_SPAWNED_CAP}"
            )

        rewards = self.reward_location_ids
        if len(set(rewards)) != len(rewards):
            raise ValueError("duplicate reward_location_id")

        # §13.2 used to be enforced by keeping affordances and rewards in
        # SEPARATE ROOMS. That was the cheapest possible proof that no
        # feature sits between the player and a Check, and it made every
        # reward room sterile: no rails, no grapple, no bounce pad, in the
        # rooms most worth having them (CAMPAIGN_SCALE.md 7).
        #
        # The invariant is unchanged. The proof moved:
        #
        #   - `_features_sit_clear_of_the_walking_lane` (ChamberBase) is
        #     the geometric half, and now runs on every chamber type
        #     rather than only corridors.
        #   - the ownership half stays in `validate_zone`, which has the
        #     campaign and can ask what the player actually has.
        #   - the instantiated half is `godot-legible`, which walks the
        #     built room and checks the reward is reachable with base
        #     movement while the feature is not on the way.
        #
        # Optional capabilities may shortcut, flank and decorate. They may
        # never be REQUIRED for a Check, an objective or the exit.
        return self

    @property
    def reward_location_ids(self) -> list[int]:
        """Every Check in the Zone, across all its rooms."""
        return [rid for c in self.chambers for rid in c.reward_ids]


# ---------------------------------------------------------------------------
# Semantic validation
# ---------------------------------------------------------------------------

def validate_zone(
    zone: Zone,
    *,
    expected_zone_id: str,
    allocated_location_ids: list[int],
    owned_echo_ids: list[str],
    owned_affordance_tags: tuple[str, ...] = (),
    guaranteed_capabilities: tuple[str, ...] = M.BASELINE_CAPABILITIES,
    legal_shell_ids: tuple[str, ...] = (),
    shell_catalog: dict[str, list[str]] | None = None,
    shell_rules: dict[str, dict] | None = None,
    zone_budget: int | None = None,
) -> list[str]:
    """Check a structurally-valid Zone against its request.

    Returns [] if acceptable, else concise errors for the repair request.
    Never mutates: v0.5 rejects and repairs rather than clamping, so an
    accepted Zone is always something Epsilon actually chose.

    `zone_budget` is the content the campaign asked for
    (CAMPAIGN_SCALE.md 5). Pass None to skip the check -- which is what a
    campaign generated before budgets existed does, and NOT a way for a
    caller to opt out of it. The value scored is recomputed here from the
    accepted components; nothing the provider sent is read as a score.
    """
    errors: list[str] = []

    # A ROOM MAY NOT USE A DOORWAY ITS BUILD CANNOT HOLD.
    #
    # `procedural_sockets_for` is the one declaration; the composer
    # offers from it and this refuses a proposal that went around it. A
    # procedural `platform_path` that assigns `side_left` is asking for
    # a hole in a wall whose middle is over the kill pit -- the engine
    # measures that and refuses the whole layout, which costs a round
    # trip and reports the failure as a placement problem rather than as
    # the composition problem it is.
    #
    # Here and not in the Zone's own Invariant 8, because that validator
    # runs on LOAD: every Zone composed before the capacity was
    # corrected carries these doors, and a save holding one must stay
    # readable. A proposal, by contrast, is exactly the thing this
    # function exists to reject and repair.
    #
    # An AUTHORED shell is not asked. It declares its own openings in
    # the catalog and `shell_rules` audits those; sharing a chamber type
    # with a procedural room says nothing about what an artist cut.
    for chamber in zone.chambers:
        if getattr(chamber, "shell_id", None) or not chamber.doors:
            continue
        can_hold = procedural_sockets_for(chamber.type)
        overreach = sorted({d.socket_id for d in chamber.doors
                            if d.socket_id not in can_hold
                            and d.usage != "SEALED"})
        if overreach:
            errors.append(
                f"chamber '{chamber.id}' is a procedural '{chamber.type}' "
                f"and uses joining socket(s) {overreach} its build cannot "
                f"hold; it offers {list(can_hold)}")

    # Enemy counts scale with the Zone's content budget: a longer level
    # holds more enemies OVER TIME. `MAX_ENEMIES_ACTIVE` is what bounds
    # the moment, and it does not scale.
    #
    # No budget means a campaign generated before budgets existed, so it
    # gets the prototype's caps rather than none -- "optional" must not
    # be how a limit stops being enforced.
    combat_budget = (zone_budget if zone_budget is not None
                     else C.PROTOTYPE_CONFIG.zone_budget)
    enemy_cap = C.max_enemies_per_zone(combat_budget)
    total_enemies = sum(c.enemy_total for c in zone.chambers)
    if total_enemies > enemy_cap:
        errors.append(
            f"zone has {total_enemies} enemies, limit is {enemy_cap} for a "
            f"{combat_budget}-point Zone")
    brute_cap = C.max_brutes_per_zone(combat_budget)
    brutes = sum(c.brute_total for c in zone.chambers)
    if brutes > brute_cap:
        errors.append(
            f"zone has {brutes} brutes, limit is {brute_cap} for a "
            f"{combat_budget}-point Zone")

    if zone_budget is not None:
        from ..composition import composition_errors
        from ..content_value import budget_errors
        errors.extend(budget_errors(zone, zone_budget))
        # A Zone that holds enough content can still be a hundred
        # identical rooms (CAMPAIGN_SCALE.md 6). Budget is necessary and
        # not sufficient, so both run.
        errors.extend(composition_errors(zone, zone_budget))

    # D1: Epsilon may SELECT among the authored shells it was offered,
    # and only those. The catalog is handed to it in the request; a shell
    # id outside it is either a hallucination or a shell this campaign
    # cannot use, and both produce a zone that cannot be built. Selection
    # is real agency; invention is not.
    #
    # An empty catalog means the campaign offered no authored shells, so
    # naming any is wrong -- rather than meaning "anything goes", which
    # is the reading that would let a hallucinated id through on exactly
    # the runs where nothing was offered.
    # BEING IN THE FLATTENED LIST IS NOT ENOUGH (3B). A treasure room is
    # offered and it is not an arena, and a tower shell built for three
    # floors is not a four-floor tower. Both were legal under the
    # membership test alone, and both produce a Zone that validates here
    # and silently falls back to a procedural room at runtime -- which
    # is the substitution 3B exists to remove. So the offer is checked
    # per chamber TYPE, and the shell's own fixed constraints with it.
    for chamber in zone.chambers:
        if chamber.shell_id is None:
            # A ROOM THE BUILDER MAKES STAYS IN THE BUILDER'S RANGE.
            # `ArenaChamber`'s field bounds were widened so an authored
            # shell's fixed geometry could inform the chamber it builds
            # (owner ruling, 2026-09-11); widening them alone would have
            # let a PROCEDURAL arena be 90 m across, which no builder,
            # audit or layout path has ever been asked for. The range
            # that used to live on the field is enforced here instead,
            # on exactly the rooms it describes.
            if chamber.type == "arena":
                for name, low, high in (
                        ("width", C.PROCEDURAL_ARENA_MIN_SPAN,
                         C.PROCEDURAL_ARENA_MAX_SPAN),
                        ("depth", C.PROCEDURAL_ARENA_MIN_SPAN,
                         C.PROCEDURAL_ARENA_MAX_SPAN),
                        ("wall_height", C.PROCEDURAL_ARENA_MIN_HEIGHT,
                         C.PROCEDURAL_ARENA_MAX_HEIGHT)):
                    got = float(getattr(chamber, name))
                    if not low <= got <= high:
                        errors.append(
                            f"chamber '{chamber.id}' names no shell, so "
                            f"the builder makes it, and its {name} of "
                            f"{got:.1f} is outside the {low:.0f}-{high:.0f} "
                            f"the builder is designed for")
            continue
        if chamber.shell_id not in legal_shell_ids:
            errors.append(
                f"chamber '{chamber.id}' selects shell "
                f"'{chamber.shell_id}', which was not offered; choose "
                f"from {sorted(legal_shell_ids)}"
                + ("" if legal_shell_ids
                   else " (no authored shells were offered for this Zone)"))
            continue
        if shell_catalog is not None:
            for_type = shell_catalog.get(chamber.type, [])
            if chamber.shell_id not in for_type:
                errors.append(
                    f"chamber '{chamber.id}' is a '{chamber.type}' and "
                    f"selects shell '{chamber.shell_id}', which is not "
                    f"offered for that type; choose from "
                    f"{sorted(for_type)}"
                    + ("" if for_type
                       else f" (no authored shell is offered for "
                            f"'{chamber.type}')"))
                continue
        # The shell's own fixed constraints, judged by THE one rule --
        # `shells.rule_errors`, which the offline generator selects with
        # and Godot's `_misfit` mirrors. A second copy here is how a
        # validator comes to accept what the builder then refuses.
        from ..shells import rule_errors as _shell_rule_errors
        rule = (shell_rules or {}).get(chamber.shell_id, {})
        errors.extend(f"chamber '{chamber.id}' {why}" for why
                      in _shell_rule_errors(chamber.shell_id, rule, chamber))

    # I12: a feature the campaign cannot interact with is set dressing
    # that looks like content, which §13.1 says is worse than nothing.
    # Evaluated over OWNED capability, never equipped — you own the
    # grapple whether or not it is slotted, and you can always slot it.
    for chamber in zone.chambers:
        for feature in chamber.features:
            if feature.tag not in owned_affordance_tags:
                errors.append(
                    f"chamber '{chamber.id}' offers a '{feature.tag}', "
                    f"which this campaign has no capability to use; "
                    f"offer one of {sorted(owned_affordance_tags)} or none"
                )

    # NO REQUIREMENT BEFORE GUARANTEE (owner ruling, 2026-08-30).
    #
    # An activity may require a semantic capability. It may not require
    # one the generator cannot PROVE the player can get, because the
    # proof is the whole difference between a deliberate NOT YET and a
    # Zone that assumed an ordinary shuffled Check would contain a
    # grapple. Archipelago decides what is in that Check; this validator
    # reasons from guarantees and never from what would be convenient.
    #
    # `guaranteed_capabilities` defaults to the permanent baseline rather
    # than to the empty tuple: a caller that forgets to pass it then
    # refuses MORE than it should, never less.
    for chamber in zone.chambers:
        for activity in chamber.activities:
            missing = [c for c in activity.requires
                       if c not in guaranteed_capabilities]
            if missing:
                errors.append(
                    f"chamber '{chamber.id}' has a {activity.kind} requiring "
                    f"{missing}, which this campaign is not guaranteed to be "
                    f"able to do; guaranteed here is "
                    f"{sorted(guaranteed_capabilities)}")

    if zone.zone_id != expected_zone_id:
        errors.append(
            f"zone_id must be exactly '{expected_zone_id}', got '{zone.zone_id}'"
        )

    # Multiset comparison: v0.4 compared sets, so two allocated slots could
    # be satisfied by one chamber.
    got = sorted(zone.reward_location_ids)
    want = sorted(allocated_location_ids)
    if got != want:
        missing = sorted(set(want) - set(got))
        extra = sorted(set(got) - set(want))
        if missing:
            errors.append(
                "these allocated AP locations are missing a reward chamber: "
                + ", ".join(str(i) for i in missing)
            )
        if extra:
            errors.append(
                "these AP location ids were not allocated to this Zone and must "
                "not appear: " + ", ".join(str(i) for i in extra)
            )
        if not missing and not extra:
            errors.append(
                "each allocated AP location must appear exactly once; "
                f"expected {want}, got {got}"
            )

    unowned = [e for e in zone.featured_echo_ids if e not in owned_echo_ids]
    if unowned:
        errors.append(
            "featured_echo_ids must all be owned; unknown: " + ", ".join(unowned)
        )

    return errors
