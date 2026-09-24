"""Archipepsi v0.7 — bridge protocol and campaign state.

The bridge owns persistent campaign truth; Godot sends INTENTS and renders
the CAMPAIGN SNAPSHOT it gets back. Python owns allocation, tiers, coins,
shop, pending transactions, the Echo registry, save/reconcile. Godot owns
movement, player HP, living enemies, projectiles, and objective progress in
the current room — none of which survives leaving a Zone.

Every state-changing intent is answered with a fresh full snapshot.

---------------------------------------------------------------------------
THE ONE RULE THAT GOVERNS THIS FILE
---------------------------------------------------------------------------

**These models are validated VALUE OBJECTS, not live mutable state.**

Every model here is `frozen=True` and every collection is a tuple, so a model
cannot be changed after it is validated — not by assignment, not by appending
to a list, not by reaching into a nested model. This is deliberate and it
replaces v0.6's `validate_assignment=True`, which only ever re-validated
TOP-LEVEL assignment. Nested mutation and list mutation ran no validators at
all, so every cross-model invariant below was bypassable by exactly the
mutations a bridge naturally performs — and the save that resulted could not
be read back, which silently rolled the campaign back to `.bak`.

Persistent campaign changes therefore go through `transitions.py`, which
builds the complete new `CampaignSave` and validates it in one step. There is
no supported way to edit a campaign in place. If you find yourself wanting
one, you want a transition function.

Two consequences worth stating plainly, because the previous revision made
a claim it could not keep:

* An invariant here holds at CONSTRUCTION. That is now the only moment there
  is, which is why it is enough.
* `dict` and `list` are gone from the campaign models. Collections keyed by
  an id are tuples with a uniqueness rule and a lookup property, so a key can
  no longer disagree with the id inside its value.
"""

from __future__ import annotations

from typing import Annotated, Literal, Union, get_args

from pydantic import (
    BaseModel, ConfigDict, Field, computed_field, model_validator,
)

try:
    from . import constants as C
    from .echo import EchoInterpretation, SlotName
    from . import mechanics as M
    from .mechanics import Mechanics, derive_mechanics
    from .zone import ActivityCapability, ActivityKind, Zone
except ImportError:  # pragma: no cover
    import constants as C
    from echo import EchoInterpretation, SlotName
    import mechanics as M
    from mechanics import Mechanics, derive_mechanics
    from zone import ActivityCapability, ActivityKind, Zone

PROTOCOL_VERSION = 8

_ID = Field(min_length=1, max_length=24, pattern=r"^[a-z0-9_]+$")

#: Any Archipepsi location, goal included. Correct for the read-only mirrors
#: of Archipelago truth (checked/missing/scouted) and for notifications: to
#: Archipelago, the goal is an ordinary location.
#:
#: The bound is the STABLE UNIVERSE, not one campaign's range: location ids
#: mean the same Check in every campaign size, and a save has to be able to
#: hold whichever prefix its own seed was generated with
#: (CAMPAIGN_SCALE.md 3). Which of those ids this campaign actually has is
#: a per-campaign question, answered by `CampaignSave` below.
_LOC = Annotated[int, Field(ge=C.FIRST_LOCATION_ID, le=C.LAST_UNIVERSE_ID)]

#: Any location EXCEPT the goal. Required on every field that can RESERVE,
#: STOCK, PRICE or SELL a location — i.e. every acquisition path other than
#: the finale Zone.
#:
#: This USED to be a closed range ending one below the goal, because with a
#: single campaign size the goal was always id 89100030. It is now the same
#: range as `_LOC`, and the reservation is enforced by `CampaignSave`, which
#: is the smallest object that knows where this campaign's goal is. The
#: annotation is kept distinct because it still marks which fields the rule
#: applies to, and the rule is checked once per save rather than once per
#: field.
_NON_FINALE_LOC = _LOC

_AP_STR = Annotated[str, Field(max_length=C.MAX_AP_STRING_LEN)]


class Strict(BaseModel):
    """Frozen, closed, and validated once — see the module docstring."""
    model_config = ConfigDict(extra="forbid", frozen=True)


# ---------------------------------------------------------------------------
# Campaign state
# ---------------------------------------------------------------------------

#: v0.5 adds ABANDONED. Without it an unfinishable Zone blocked all further
#: generation forever, with clear_campaign the only escape.
ZoneState = Literal[
    "PENDING_GENERATION", "GENERATED", "ACTIVE", "DORMANT", "COMPLETE",
    "VISITING", "ABANDONED"
]

#: **Still reserves its AP locations, or not.** A COMPLETE Zone claimed
#: everything it held and an ABANDONED one released it, so neither
#: reserves anything — and neither does VISITING, which is a COMPLETE
#: Zone with a player standing in it. This drives allocation and the
#: one-holder-at-a-time invariant, and it is NOT a statement about
#: whether a player can walk back in.
#:
#: **Going back must not re-reserve.** Sending a revisit through ACTIVE
#: would make a finished Zone hold its old locations again, which both
#: collides with whatever Zone is genuinely in flight and re-opens
#: Checks the campaign already counted.
TERMINAL_ZONE_STATES = ("COMPLETE", "VISITING", "ABANDONED")

#: The player is standing in this Zone. Two states, because a Zone with
#: work outstanding and a Zone being revisited are the same experience
#: and different accounting.
OCCUPIED_ZONE_STATES = ("ACTIVE", "VISITING")

#: **Can a player walk back in?** A separate question from the one
#: above, and the 2026-09-12 ruling is why it had to become one:
#: claiming the final Check does not close the place. A player may come
#: back for a room, a route, a station or a plug they never used, and
#: "nothing remains" was only ever a claim about Checks.
#:
#: `ABANDONED` is the only state that is gone, and it is only ever
#: reached deliberately.
#:
#: `DORMANT` — left with Checks outstanding — still reserves its
#: locations, so it is NOT terminal above. That is what stops the
#: allocator from reissuing a Check the player walked away from and
#: means to come back for. One consequence, deliberately conservative
#: and worth an owner's eye: while a Zone is DORMANT it is the Zone
#: holding locations, so a new Zone cannot be generated until it is
#: finished or explicitly abandoned.
REVISITABLE_ZONE_STATES = ("GENERATED", "ACTIVE", "DORMANT", "COMPLETE",
                           "VISITING")


class ZoneProgress(Strict):
    """What the player DID to a Zone, as opposed to what the Zone is.

    **Progress is not layout.** The layout rebuilds from the manifest and
    is identical by construction; this is separate persistence, and
    conflating the two is how a catalog change would reach a player as a
    lost key.

    **Every set is monotone and only ever grows within a Zone's life.**
    That is not a convenience — it is what makes a resume safe. A
    monotone progress set is a latch, so a reload cannot regress a player
    behind a door they opened, and `R ⊆ E` holds across a resume for the
    same reason it holds within a run.
    """
    #: Zone-local keys collected. Never AP items.
    collected_keys: tuple[str, ...] = ()
    #: `room_id/socket_id` for each lock opened.
    opened_locks: tuple[str, ...] = ()
    #: Warp stations reached.
    reached_stations: tuple[str, ...] = ()
    #: Physics latches that have fired, as `package_id/latch_id`.
    #:
    #: Design 2 §5.7: once satisfied, never re-evaluated, never cleared
    #: by reset or death — and **quitting is a reset**, which is the
    #: whole reason this is persisted rather than held in the runtime.
    #: The engine's live `latch_fired` signal is not state; what becomes
    #: state is the APPROVED consequence, recorded only after the event
    #: has been checked against the packages the committed manifest
    #: accepted.
    #:
    #: Global identity, never a bare `latch_id`: two packages may both
    #: call a latch `bridge_down`. See `physics.latch_ref`.
    latched: tuple[str, ...] = Field(default=(), max_length=32)

    #: The station a re-entering player returns to. The one field that is
    #: a POSITION rather than progress: it is overwritten rather than
    #: accumulated, and losing it costs a walk rather than a run.
    resume_anchor: str | None = Field(default=None, max_length=64)

    #: D-8. The current state of each declared Zone-state variable, as
    #: `(variable_id, state)` pairs sorted by id -- §5.1's
    #: `ZoneState.macro`, restored at §5.6 step 4.
    #:
    #: **NOT `latched`, and the separation is the point.** A reversible
    #: variable's current state is not a monotone fact: `lowered` today
    #: may be `stowed` tomorrow because the player put it back, which is
    #: what `reversible` MEANS. Riding `latched` would either make the
    #: set non-monotone -- breaking the resume-safety argument in this
    #: class's own docstring -- or quietly convert every reversible
    #: relationship into a permanent one, which is the silent latch the
    #: 0.4 scope clarification forbids by name.
    #:
    #: So it joins `resume_anchor` as a field that is OVERWRITTEN rather
    #: than accumulated. A `permanent` variable is monotone by the
    #: declaration that `ZoneStateVariable` validates, not by the
    #: container it is stored in.
    #:
    #: **The name.** `ZoneState` in this module is the campaign
    #: lifecycle literal, so calling this `zone_state` would give one
    #: spelling two meanings. `macro_state` is the Amalgam's own word
    #: for the value; `Zone.zone_state` is the DECLARATION of which
    #: variables exist, and this is what they currently are.
    macro_state: tuple[tuple[str, str], ...] = Field(
        default=(), max_length=4)

    #: P16. Where each declared transported object currently is, as
    #: `(object_id, room_id)` pairs sorted by id. §10.5: a multi-room
    #: carryable is `ZONE_PERSISTENT`.
    #:
    #: **The ROOM, and nothing else about the object.** Its Statuses are
    #: `EPHEMERAL` by §5.1, so they are not written to the save -- a
    #: cell alight when the player quits is not alight when they load.
    #:
    #: **That is a statement about saves and not about doorways**
    #: (corrected 2026-09-22). Carrying the object between rooms during
    #: live play is not a reload: a Status on it follows its own
    #: duration and removal rules, and a doorway cleanse would be an
    #: invented mechanic. The union's example -- a `BURNING` power cell
    #: carried three rooms to a generator -- depends on it arriving
    #: still alight.
    #:
    #: Overwritten rather than accumulated, like `macro_state` and
    #: `resume_anchor`: an object carried back is not a replay to reject.
    object_rooms: tuple[tuple[str, str], ...] = Field(
        default=(), max_length=4)

    #: O05-03. Where a transported object CAME TO REST, per object:
    #: `(object_id, room_id, x, y, z, yaw)`, rounded to the millimetre.
    #: Amalgam §5.6 step 10 restores physical configurations "at saved
    #: transforms", and §30.6.1 keeps `PLACED` room-indexed because "a
    #: required cell dropped in room B stays in room B". The room alone
    #: put a restored object back at the room's arrival point, which is
    #: not where the player left it.
    #:
    #: **A pose is recorded only once the object has settled**, never
    #: mid-carry or mid-fall (§5.3's rule against saving a moving
    #: `PUZZLE_LOCAL` body). A pose in a room the object is no longer in
    #: is stale and is dropped by `with_object_in`, so the save can never
    #: say "in room C, at a point in room B".
    object_poses: tuple[tuple[str, str, float, float, float, float], ...] = \
        Field(default=(), max_length=4)

    #: O05-02. Objects a consumer has TAKEN (§30.6.1's `CONSUMED`), as
    #: `(object_id, mechanism_id)` rows sorted by object. Monotone: the
    #: declared consumers take and never give back. A consumed object is
    #: never rebuilt loose, so re-entering the room or restarting can
    #: never produce a second copy beside the installed one.
    #:
    #: **Which consumer took it is part of the fact.** Without it, a
    #: second consumer asking for an object already installed elsewhere
    #: looked exactly like the first one's delivery reported again, and a
    #: scenery consumer (whose consequence trivially "already holds")
    #: was absorbed as a repeat.
    consumed_objects: tuple[tuple[str, str], ...] = Field(default=(),
                                                          max_length=4)

    #: O05-06.2. Where each saved carrier CAME TO REST, as
    #: `(minor_<room>/<carrier>, t, destination, held)` rows sorted by
    #: ref: `t` the machine's own offset along its path in metres (to
    #: the millimetre), `destination` the stop it stands at or is bound
    #: for (empty when a hold has cleared its errand), `held` whether a
    #: STOP or a dwell holds it there.
    #:
    #: EX50-011 §9: "Carrier poses, destinations and hold states are
    #: package-local. A stable save restores each at its saved pose
    #: before the player." Amalgam §5.2 puts machinery `t` in
    #: `PUZZLE_LOCAL`, and §5.3 refuses a save while such a body moves,
    #: so **only a carrier at rest is recorded**: parked at a stop,
    #: held by a STOP, or pausing in a declared dwell. A carrier the
    #: player quits mid-travel comes back at its last rest.
    #:
    #: **A dwell comes back HELD** (§9: "a carrier in a dwell state can
    #: remain safely held until the player resumes"), so a restored lift
    #: never leaves from under a player because the application was
    #: closed for an hour.
    #:
    #: Overwritten rather than accumulated, like `macro_state`: a carrier
    #: sent back is not a replay to reject.
    carrier_states: tuple[tuple[str, float, str, bool], ...] = Field(
        default=(), max_length=8)

    #: H-RESUME-R (owner ruling D-06, 2026-09-24). The encounter members
    #: this player has DEFEATED here, as `room/archetype#n`: the n-th
    #: spawn of that archetype in that room's declared `enemies`, counted
    #: in declaration order -- the order every room builder lays them out
    #: in. Derived from the declaration alone: never an engine node path,
    #: and nothing about a live enemy (health, timers, position) is saved.
    #:
    #: **`None` is not "nobody".** It is a Zone whose save has no record
    #: -- one written before this field existed -- so its encounter state
    #: is UNKNOWN. The engine then builds every member (no cleared room is
    #: invented), restores the player at the resume room's arrival rather
    #: than among them (no ambush), and says so; the first defeat recorded
    #: after that makes this a tuple, which is the new persistence taking
    #: over "from that point onward". `()` would be "known, and nobody has
    #: fallen".
    #:
    #: **Monotone.** "Reloading is not an encounter-reset event": a member
    #: once defeated is never built again in this Zone, which is also what
    #: will make a later drop once-only. Checked against the declaration
    #: by `transitions.record_defeat`; the bridge's check is consistency
    #: evidence, and the engine's lifecycle is the evidence of the kill.
    defeated: tuple[str, ...] | None = Field(default=None, max_length=512)

    def with_key(self, key_id: str) -> "ZoneProgress":
        if key_id in self.collected_keys:
            return self
        return self.model_copy(update={
            "collected_keys": tuple(sorted({*self.collected_keys, key_id}))})

    def with_lock(self, room_id: str, socket_id: str) -> "ZoneProgress":
        ref = f"{room_id}/{socket_id}"
        if ref in self.opened_locks:
            return self
        return self.model_copy(update={
            "opened_locks": tuple(sorted({*self.opened_locks, ref}))})

    def with_latch(self, ref: str) -> "ZoneProgress":
        return self if ref in self.latched else self.model_copy(update={
            "latched": tuple(sorted({*self.latched, ref}))})

    def with_macro(self, variable_id: str, state: str) -> "ZoneProgress":
        """Set a Zone-state variable, replacing whatever it held.

        The replacement is the whole difference from `with_latch`: a
        latch that has fired stays fired, and a variable that has been
        set can be set again.
        """
        kept = {v: st for v, st in self.macro_state}
        if kept.get(variable_id) == state:
            return self
        kept[variable_id] = state
        return self.model_copy(update={
            "macro_state": tuple(sorted(kept.items()))})

    def macro(self, variable_id: str) -> str | None:
        """What that variable currently holds, or `None` if unset."""
        return dict(self.macro_state).get(variable_id)

    def with_object_in(self, object_id: str, room_id: str) -> "ZoneProgress":
        """Record where a transported object now is, replacing where it was.

        A TRANSFER, not a machine-layer write (D-8 §11.1): the object's
        owning room becomes its current room and no room's graph wrote
        anything to another room to make that happen. The player carried
        it, which is §19.7's "the player is the bridge" in its most
        literal form.
        """
        kept = {o: r for o, r in self.object_rooms}
        if kept.get(object_id) == room_id:
            return self
        kept[object_id] = room_id
        # A POSE IN THE ROOM IT LEFT IS STALE, and is dropped with the
        # move rather than left to contradict the room.
        poses = tuple(row for row in self.object_poses
                      if row[0] != object_id or row[1] == room_id)
        return self.model_copy(update={
            "object_rooms": tuple(sorted(kept.items())),
            "object_poses": poses})

    def with_object_pose(self, object_id: str, room_id: str,
                         position: tuple[float, float, float],
                         yaw: float) -> "ZoneProgress":
        """Record where an object came to rest (O05-03), in its room."""
        row = (object_id, room_id, round(float(position[0]), 3),
               round(float(position[1]), 3), round(float(position[2]), 3),
               round(float(yaw), 4))
        kept = {r[0]: r for r in self.object_poses}
        if kept.get(object_id) == row:
            return self
        kept[object_id] = row
        return self.with_object_in(object_id, room_id).model_copy(
            update={"object_poses": tuple(sorted(kept.values()))})

    def without_object_pose(self, object_id: str) -> "ZoneProgress":
        if not any(r[0] == object_id for r in self.object_poses):
            return self
        return self.model_copy(update={"object_poses": tuple(
            r for r in self.object_poses if r[0] != object_id)})

    def object_pose(self, object_id: str):
        """`(room_id, (x, y, z), yaw)` or `None`."""
        for row in self.object_poses:
            if row[0] == object_id:
                return row[1], (row[2], row[3], row[4]), row[5]
        return None

    def with_consumed(self, object_id: str,
                      mechanism_id: str) -> "ZoneProgress":
        """Installed in `mechanism_id`. Taking an object a DIFFERENT
        consumer already holds is a caller's error, raised rather than
        recorded, so the save can never name two homes for one object."""
        held = self.consumed_by(object_id)
        if held == mechanism_id:
            return self
        if held is not None:
            raise ValueError(
                f"'{object_id}' is already installed in '{held}'")
        return self.without_object_pose(object_id).model_copy(update={
            "consumed_objects": tuple(sorted(
                {*self.consumed_objects, (object_id, mechanism_id)}))})

    def with_carrier(self, ref: str, t: float, destination: str,
                     held: bool) -> "ZoneProgress":
        """Record where a carrier came to rest, replacing its last rest."""
        row = (ref, round(float(t), 3), destination, bool(held))
        kept = {r[0]: r for r in self.carrier_states}
        if kept.get(ref) == row:
            return self
        kept[ref] = row
        return self.model_copy(update={
            "carrier_states": tuple(sorted(kept.values()))})

    def carrier(self, ref: str):
        """`(t, destination, held)` for that carrier, or `None`."""
        for row in self.carrier_states:
            if row[0] == ref:
                return row[1], row[2], row[3]
        return None

    def consumed(self, object_id: str) -> bool:
        return self.consumed_by(object_id) is not None

    def consumed_by(self, object_id: str) -> str | None:
        """The consumer holding that object, or `None`."""
        for obj, mechanism in self.consumed_objects:
            if obj == object_id:
                return mechanism
        return None

    def object_room(self, object_id: str) -> str | None:
        """Which room that object is in, or `None` if it has not moved."""
        return dict(self.object_rooms).get(object_id)

    def with_station(self, station_id: str) -> "ZoneProgress":
        if station_id in self.reached_stations:
            return self
        return self.model_copy(update={
            "reached_stations": tuple(
                sorted({*self.reached_stations, station_id})),
            "resume_anchor": station_id})

    def with_defeated(self, member: str) -> "ZoneProgress":
        """A member defeated. From an unknown record (`None`), the first
        defeat starts the record: the engine built every member on that
        entry, so what falls from then on is exactly what is known."""
        known = self.defeated if self.defeated is not None else ()
        if self.defeated is not None and member in known:
            return self
        return self.model_copy(update={
            "defeated": tuple(sorted({*known, member}))})


#: §5.1's five persistence categories, and which one each saved field of
#: `ZoneProgress` belongs to.
#:
#: **This replaces a field-NAME scan** (owner correction, 2026-09-22).
#: The earlier guard failed on any field whose name contained `pose`,
#: `transform`, `velocity` or `elapsed`, which generalised
#: `rail_junction.gd`'s supported-dock policy into a universal ban on
#: physical saved state. EX50-011 §9 asks for the opposite in so many
#: words: *"carrier poses, destinations and hold states are
#: package-local. A stable save restores each at its saved pose before
#: the player."* A runtime comment about one railway does not supersede
#: a selected spec about another package.
#:
#: **The two contracts differ for a stateable reason.** A `RailSpan` is
#: COMMISSIONABLE: whether its link exists depends on a latch, so a
#: carrier restored to a transform may be standing on track this build
#: did not commission, and restoring it to a supported dock is the
#: safety rule. Passing Platforms' carriers run a fixed schedule on a
#: path that always exists, so there is nothing for a saved pose to
#: contradict. Conditional path, restore to a dock; unconditional path,
#: restore the pose.
SAVE_FIELD_CATEGORY: dict[str, str] = {
    "collected_keys": "ROOM_PERSISTENT",
    "opened_locks": "ROOM_PERSISTENT",
    "reached_stations": "ROOM_PERSISTENT",
    "latched": "ROOM_PERSISTENT",
    "resume_anchor": "ZONE_PERSISTENT",
    "macro_state": "ZONE_PERSISTENT",
    "object_rooms": "ZONE_PERSISTENT",
    # O05-02/03: a multi-room carryable is ZONE_PERSISTENT (Amalgam §10,
    # pinning Design 3 §10.5), and so is where it rests and whether a
    # consumer has taken it.
    "object_poses": "ZONE_PERSISTENT",
    "consumed_objects": "ZONE_PERSISTENT",
    # O05-06.2: machinery `t` is `PUZZLE_LOCAL` (Amalgam §5.2), and a
    # Passing Platforms carrier's rest is saved by its own package's
    # contract (EX50-011 §9) -- the unconditional-path case above.
    "carrier_states": "PUZZLE_LOCAL",
    # H-RESUME-R: which declared members of a room's encounter have
    # fallen is that room's own fact, kept like a lock opened.
    "defeated": "ROOM_PERSISTENT",
}


def categorise_save_field(name: str, category: str) -> str | None:
    """Is it legal to persist a field of this category? `None` if so.

    The rule §5.4a actually states, rather than a rule about spelling:
    a **derived live value** is never serialized, because a save holding
    one could disagree with the graph that recomputes it. `EPHEMERAL` is
    precisely the category of things rebuilt rather than restored, so a
    field in it has no business in a save; every other category is
    permitted and it is the package's own contract that decides which
    one applies.
    """
    known = {"EPHEMERAL", "PUZZLE_LOCAL", "ROOM_PERSISTENT",
             "ZONE_PERSISTENT", "AP_PERSISTENT"}
    if category not in known:
        return f"'{name}' declares category '{category}', which §5.1 has no row for"
    if category == "EPHEMERAL":
        return (f"'{name}' is declared EPHEMERAL and is in a save; §5.1 says "
                "EPHEMERAL state is rebuilt on restore, so persisting it "
                "would let the save disagree with what rebuilds it")
    return None


class ZoneRecord(Strict):
    """A Zone across its whole lifecycle.

    `allocated_location_ids` is populated at PENDING_GENERATION, before the
    provider is called, so a crash mid-generation is representable.

    `GENERATED` means accepted-but-not-yet-entered. In v0.4 that state had
    no Hub mode, no entering intent and no reconciliation clause, so a Zone
    generated and then abandoned at the loading screen orphaned its AP
    locations permanently. `active_zone_id` is set at GENERATED, not at
    entry, so the Zone is always visible and always resumable.
    """
    zone_id: str = _ID
    state: ZoneState
    #: What the player DID here. Survives death, Hub return and
    #: re-entry, because all three are the same question: is the Zone
    #: still the one you left?
    progress: ZoneProgress = Field(default_factory=lambda: ZoneProgress())
    #: THE COMMITTED LAYOUT, once validation accepted one. Solved by the
    #: engine, checked here, and replayed forever after: a later load
    #: lays the same pieces down rather than searching again.
    #:
    #: `None` until an accepted layout arrives, and for every Zone that
    #: predates the graph. A Zone with no manifest is not a broken Zone;
    #: it is one whose topology is still its chamber order.
    manifest: dict | None = None
    #: WHETHER THE LAYOUT WAS ACCEPTED, and therefore whether this Zone
    #: is safe to play.
    #:
    #: A refused layout used to change nothing: `handle_layout_result`
    #: logged, sent a notification, and left the Zone ACTIVE — so the
    #: client kept playing a Zone whose geometry the validator had just
    #: said does not hold together, and could claim its Checks.
    #:
    #: `UNCERTIFIED` is the honest state for a Zone with no graph: there
    #: are no edges for the evidence to be about, so it is neither
    #: accepted nor refused and it plays exactly as it always did.
    layout_state: Literal["UNCERTIFIED", "ACCEPTED", "REFUSED"] = \
        "UNCERTIFIED"
    #: How many layouts for this Zone the validator has rejected.
    #:
    #: A refusal sends the Zone back to be composed again against the
    #: SAME location ids -- the Checks are preserved and the campaign is
    #: not stuck -- but a Zone that cannot be composed soundly must stop
    #: trying, or a client that refuses every layout spins forever.
    layout_refusals: int = Field(default=0, ge=0, le=99)

    #: Rooms the engine measured and could not stand this Zone's
    #: required return device in.
    #:
    #: **The engine's verdict, accumulated.** A branch destination is a
    #: dead end and takes a return; whether a body can stand somewhere
    #: in that room, clear of the arrival, is physical and only the
    #: engine answers it. `played_zone`'s `c012` is a `platform_path`
    #: over a kill pit where four measured placements found nothing, and
    #: the whole Zone used to be discarded for it.
    #:
    #: Monotone, so the composer cannot be handed the same host twice
    #: and cannot oscillate between two of them — which is what makes
    #: re-selection terminate. Not a room type and not a flag the bridge
    #: sets: every id here was refused by a measurement.
    unhostable_rooms: tuple[str, ...] = Field(default=(), max_length=64)

    @property
    def layout_exhausted(self) -> bool:
        """Every layout attempt failed, and none was ever accepted.

        **Three existing facts, read together; no fourth field.** No
        manifest means nothing was ever committed. `REFUSED` means the
        last attempt was rejected rather than merely pending. The
        spent budget means the bridge has stopped composing it again.

        This is the state the Hub must not offer as a way back in, and
        it is deliberately NOT any of:

        * a **committed** Zone whose replay was later refused — that one
          has a manifest, keeps it, and stays re-enterable;
        * a Zone with attempts **still left**, which goes back to
          `PENDING_GENERATION` and is composed again;
        * a Zone **temporarily pending** a layout, which has refused
          nothing yet.
        """
        return (self.manifest is None
                and self.layout_state == "REFUSED"
                and self.layout_refusals >= MAX_LAYOUT_REFUSALS)
    #: `_LOC`, not `_NON_FINALE_LOC`: the finale Zone legitimately holds the
    #: goal. `_finale_owns_the_goal` below splits the two cases — this is the
    #: ONE model in the packet allowed to carry Check 030 on an
    #: acquisition path.
    #:
    #: This SHRINKS over the record's life. A location released because its
    #: check cannot be finalized leaves this tuple while the Zone plays on;
    #: v0.6 pinned it equal to the accepted Zone's rewards forever, so the
    #: only way to release one stuck location was to abandon the whole Zone
    #: and discard its other unclaimed Checks — the deadlock ABANDONED was
    #: added to break. Equality is checked once, at acceptance, by
    #: `zone.validate_zone()`, which is where an accept-time rule belongs.
    #: Bounded by the largest campaign anyone can configure, not by the
    #: prototype's three -- a save that cannot record a fifteen-Check
    #: Zone is a 450-location campaign that cannot start one.
    allocated_location_ids: tuple[_LOC, ...] = Field(
        min_length=1, max_length=C.ZONE_TARGET_CHECKS_MAX
    )
    target_game: _AP_STR
    is_finale: bool = False
    zone: Zone | None = None          # None iff PENDING_GENERATION or ABANDONED
    used_fallback: bool = False
    generation_index: int = Field(ge=0)

    @model_validator(mode="after")
    def _state_implies_content(self):
        if self.state == "PENDING_GENERATION" and self.zone is not None:
            raise ValueError(
                "PENDING_GENERATION means no accepted zone yet; accept the "
                "Zone and set state in one construction"
            )
        # ABANDONED is exempt: v0.5 required content in every non-pending
        # state, which made "the provider timed out, give the locations back"
        # unrepresentable — the exact deadlock ABANDONED was added to break.
        if self.state in ("GENERATED", "ACTIVE", "COMPLETE") and self.zone is None:
            raise ValueError(f"state {self.state} requires an accepted zone")
        if len(set(self.allocated_location_ids)) != len(self.allocated_location_ids):
            raise ValueError("duplicate allocated location id")
        if self.zone is not None:
            if self.zone.zone_id != self.zone_id:
                raise ValueError(
                    f"record '{self.zone_id}' wraps zone '{self.zone.zone_id}'"
                )
            extra = sorted(set(self.allocated_location_ids)
                           - set(self.zone.reward_location_ids))
            if extra:
                raise ValueError(
                    "allocated locations with no reward chamber in the "
                    f"accepted Zone: {extra}"
                )
        return self

    @model_validator(mode="after")
    def _a_finale_holds_one_location(self):
        """The scale-free half of the goal reservation.

        A record cannot know where its campaign's goal is -- that moved
        with `location_count` -- but it can know a finale holds exactly
        one Check, or none once released. `CampaignSave` pins that one to
        the campaign's own goal, and pins every other path off it.
        """
        if self.is_finale and len(self.allocated_location_ids) > 1:
            raise ValueError(
                "a finale Zone holds exactly one location: the goal, "
                f"not {list(self.allocated_location_ids)}"
            )
        return self

    @property
    def holds_locations(self) -> bool:
        """Whether this record still reserves its locations."""
        return self.state not in TERMINAL_ZONE_STATES


class PendingCheck(Strict):
    """A Check sent to Archipelago and not yet confirmed back.

    This ledger is the single source of truth for an in-flight acquisition.
    A shop purchase leaves `ShopState.stock` and appears here in one
    transition; there is no second opinion about whether it is in flight.

    Source-aware because the two sources have different rights: a `zone`
    check may be the goal (the finale Zone is exactly how the goal is
    claimed) and never costs coins; a `shop` check always costs coins and
    may never be the goal.
    """
    transaction_id: str = Field(min_length=1, max_length=64)
    #: `_LOC`, because `source="zone"` covers the finale. The validator below
    #: narrows it to `_NON_FINALE_LOC` semantics for `source="shop"`.
    location_id: _LOC
    source: Literal["zone", "shop"]
    shop_cost: int = Field(default=0, ge=0)

    @model_validator(mode="after")
    def _source_bounds_what_may_be_claimed(self):
        # Which id is the goal is a per-campaign fact, so the "never the
        # goal" half of this rule lives on `CampaignSave`. What survives
        # here is what a record can check alone.
        if self.source == "shop":
            if self.shop_cost <= 0:
                raise ValueError("a shop purchase costs at least one coin")
        elif self.shop_cost != 0:
            # Otherwise a Zone claim could debit `coins_spent`, which is a
            # monotonic accumulator only the rollback path decrements.
            raise ValueError("a Zone check is never charged; shop_cost must be 0")
        return self


class ShopStockItem(Strict):
    """One location the shop is offering RIGHT NOW.

    v0.6 carried a `status` field so an in-flight purchase could be greyed
    out — a second opinion about the same fact as `pending_checks`, and the
    two could disagree in both directions. Stock now means purchasable and
    nothing else: buying removes the item from stock and creates the pending
    record atomically. Godot renders "SENDING…" from the ledger.
    """
    #: `_NON_FINALE_LOC`: the shop can never stock the goal, and cannot even
    #: describe stocking it. v0.5 relied on prose in five documents plus a
    #: procedure step, and the model accepted 89100030.
    location_id: _NON_FINALE_LOC
    #: ge=1, matching `PendingCheck.shop_cost`. Stock priced at zero would be
    #: a purchase that never debits coins; the price table is 6/4/2 anyway.
    cost: int = Field(ge=1)
    # Revealed because the player is being asked to pay for it.
    item_name: _AP_STR
    recipient_name: _AP_STR
    recipient_game: _AP_STR


class ShopState(Strict):
    """Currently purchasable offers only.

    Capped at `SHOP_STOCK_SIZE`. An in-flight purchase does NOT live here and
    does not count against the cap — v0.6 kept bought-but-unconfirmed items
    in `stock`, so a restock arriving while a purchase was still pending had
    no representable outcome except dropping the pending entry, whose cost
    was already in `coins_spent`.
    """
    stock: tuple[ShopStockItem, ...] = Field(
        default=(), max_length=C.SHOP_STOCK_SIZE
    )
    created_after_zone_count: int = Field(default=0, ge=0)

    @model_validator(mode="after")
    def _one_entry_per_location(self):
        ids = [i.location_id for i in self.stock]
        if len(set(ids)) != len(ids):
            raise ValueError("two stock entries for the same location")
        return self


# ---------------------------------------------------------------------------
# Invariants shared by the save and the snapshot
# ---------------------------------------------------------------------------
# v0.6 enforced these on `CampaignSave` and not on `CampaignSnapshot`, so the
# message Godot actually renders could carry a state the save had rejected —
# including a pending claim on the goal. They are functions rather than
# duplicated validator bodies so the two cannot drift apart.

def _reject_duplicate_pending(pending) -> None:
    seen = [p.location_id for p in pending]
    if len(set(seen)) != len(seen):
        raise ValueError("two pending checks for the same location")


def _reject_unbacked_pending(pending, zones) -> None:
    """Every in-flight Check must be backed by something that reserved it.

    A `zone` claim is backed by a Zone still holding that location; a `shop`
    purchase is backed by its own coin cost, having left the stock list at
    purchase time.

    This also subsumes the goal reservation on the save path — the only Zone
    that may hold Check 030 is the finale — so v0.6's separate goal check is
    gone rather than duplicated.
    """
    held = {i for z in zones if z.holds_locations
            for i in z.allocated_location_ids}
    stranded = sorted(p.location_id for p in pending
                      if p.source == "zone" and p.location_id not in held)
    if stranded:
        raise ValueError(
            "pending Zone checks backed by no Zone that still holds them: "
            + ", ".join(str(i) for i in stranded)
            + ". A pending check reserves a real Archipelago location; one "
            "with nothing behind it is either re-sent for free or stranded "
            "forever."
        )


def _reject_underfunded_ledger(coins_spent: int, pending) -> None:
    """`coins_spent` is documented as already inclusive of pending purchases.

    Unenforced, a purchase could be in flight with nothing debited — and the
    documented rollback (`coins_spent -= cost`) would then drive the field
    below zero and raise inside the error path.
    """
    owed = sum(p.shop_cost for p in pending if p.source == "shop")
    if coins_spent < owed:
        raise ValueError(
            f"coins_spent {coins_spent} is less than the {owed} coins already "
            "committed to pending purchases; the cost is persisted BEFORE the "
            "send, not after confirmation"
        )


class SlotAssignment(Strict):
    """Which owned Action sits in each of the five slots.

    Four named fields rather than a dict: the slot grammar belongs to the
    game, not to generation, so it is structural. Epsilon assigns an Action
    a slot *category*; the player chooses which owned Action fills it.
    LMB is not here at all — Static Pulse is never replaced.
    """
    echo_a: str | None = Field(default=None, max_length=32)
    echo_b: str | None = Field(default=None, max_length=32)
    mobility: str | None = Field(default=None, max_length=32)
    utility: str | None = Field(default=None, max_length=32)
    #: The one that runs out. Its occupant declares `charges`, and
    #: spending the last one does NOT clear this field: the supply is
    #: permanently owned, so an exhausted one stays selected at
    #: `0 / max`, says it is exhausted and says what refills it
    #: (`transitions.spend_charge`). This comment said the opposite,
    #: which was the behaviour before the owner's ruling of
    #: 2026-09-22 and never the behaviour after it.
    consumable: str | None = Field(default=None, max_length=32)

    def assigned(self) -> tuple[tuple[str, str], ...]:
        return tuple(
            (slot, value)
            for slot, value in (
                ("echo_a", self.echo_a), ("echo_b", self.echo_b),
                ("mobility", self.mobility), ("utility", self.utility),
                ("consumable", self.consumable),
            )
            if value is not None
        )

    def with_slot(self, slot: str, component_id: str | None) -> "SlotAssignment":
        # THE LIST IS THE EXPORTED ONE. Spelling it here again is how a
        # fifth slot gets added everywhere except the one place that
        # refuses it.
        if slot not in C.SLOT_NAMES:
            raise ValueError(f"unknown slot '{slot}'")
        return SlotAssignment.model_validate(
            {**self.model_dump(), slot: component_id}
        )


def _reject_unslottable(slots, mechanics) -> None:
    """A slot may only name an Action the campaign actually owns.

    Checked against the FOLD rather than against the log, because a merged
    or upgraded component is only knowable after folding — and because this
    is the one place that catches a slot pointing at a resource.
    """
    for slot, component_id in slots.assigned():
        owned = mechanics.by_id(component_id)
        if owned is None:
            raise ValueError(
                f"slot '{slot}' holds '{component_id}', which is not owned"
            )
        if owned.kind != "action":
            raise ValueError(
                f"slot '{slot}' holds '{component_id}', which is a "
                f"'{owned.kind}'; only actions occupy slots"
            )
        if owned.component.slot != slot:
            raise ValueError(
                f"'{component_id}' is a '{owned.component.slot}' action and "
                f"cannot be placed in slot '{slot}'"
            )


def _reject_impossible_charges(uses, mechanics) -> None:
    """A consumable cannot be spent past its charges.

    **Exhausted AND equipped is a legal state** (owner decision,
    2026-09-22). A consumable is a permanently owned refillable supply,
    not a thing you use up and lose: it stays selected at `0 / max` with
    exhausted feedback, and only an explicit equipment change replaces
    it. What is refused is USING one that is empty, which
    `transitions.spend_charge` does, and a count that has drifted past
    what the supply ever held, which is here.
    """
    seen: set[str] = set()
    for use in uses:
        if use.component_id in seen:
            raise ValueError(
                f"'{use.component_id}' has two use records; a consumable "
                f"has one count"
            )
        seen.add(use.component_id)
        owned = mechanics.by_id(use.component_id)
        if owned is None:
            raise ValueError(
                f"'{use.component_id}' has uses recorded but is not owned"
            )
        charges = getattr(owned.component, "charges", None)
        if owned.kind != "action" or charges is None:
            raise ValueError(
                f"'{use.component_id}' has uses recorded but is not a "
                f"consumable"
            )
        if use.spent > charges:
            raise ValueError(
                f"'{use.component_id}' has {use.spent} uses recorded "
                f"against {charges} charges"
            )


def _reject_nonmonotonic_seq(interpretations, next_seq: int) -> None:
    """`interpretation_seq` is assigned once and never reused.

    The counter is persisted rather than derived from the log, so a
    campaign that loses its last interpretation to a crash still never
    hands out a number it has already used.
    """
    seen = set()
    for entry in interpretations:
        if entry.interpretation_seq in seen:
            raise ValueError(
                f"duplicate interpretation_seq {entry.interpretation_seq}"
            )
        seen.add(entry.interpretation_seq)
        if entry.interpretation_seq >= next_seq:
            raise ValueError(
                f"interpretation_seq {entry.interpretation_seq} is at or "
                f"beyond next_interpretation_seq {next_seq}; the counter "
                f"must always be ahead of every number it has issued"
            )


def _reject_duplicate_ids(items, attr: str, label: str) -> None:
    ids = [getattr(i, attr) for i in items]
    if len(set(ids)) != len(ids):
        raise ValueError(f"duplicate {label}")


class ConsumableAuthorization(Strict):
    """A charge counted **before** the effect that spends it exists.

    **The hole this closes.** The client's reserve/launch/report is an
    in-memory list. Retaining and retransmitting it survives a dropped
    socket, and it does not survive the process: launch an effect, lose
    the report, kill Godot, relaunch into the same unrefilled
    deployment, and a bridge that only ever learned about expenditure
    from a report still believes the charge is there. Nothing in a
    cleared local dictionary is reconciliation.

    **So the charge is spent at AUTHORIZE time, not at report time.**
    `spent` moves the moment this record is written, and this record
    exists only to allow the one thing authorize-before-launch would
    otherwise lose: cancelling an attempt that never launched. A crash
    between authorize and launch therefore BURNS the charge. That is the
    cost of the chosen shape, it is the conservative direction — a lost
    report can never duplicate a charge, only forfeit one — and it is
    stated here rather than discovered by a player.

    **Keyed by the trio the design already uses.** `(component,
    generation, use_index)` is the same compare-and-swap identity
    `use_consumable` checks, so there is no second convention and no
    opaque id to mint, lose or forge. It is also why two presses during
    one cooldown cannot overwrite each other: they are different
    indices, so cancelling the second preserves the first.
    """
    component_id: str = Field(min_length=1, max_length=32)
    #: The supply it counts against, so an authorization outstanding
    #: across a refill is refused on identity like every other stale use.
    generation: int = Field(default=0, ge=0)
    use_index: int = Field(ge=1, le=C.CONSUMABLE_CHARGES_MAX)


class ConsumableUse(Strict):
    """How many of a consumable's charges have been spent.

    **Persisted, and deliberately not folded.** The fold is over the
    interpretation log, which says what the campaign was GIVEN; how many
    times the player has pressed a button is not in it and cannot be
    derived from it. So this is campaign state, it moves only through
    `transitions.spend_charge`, and it is stored the way
    `local_rewards` is -- a tuple of small records rather than a dict,
    because a dict key can disagree with the id inside its value.
    """
    component_id: str = Field(min_length=1, max_length=32)
    spent: int = Field(ge=1, le=C.CONSUMABLE_CHARGES_MAX)


class EarnedLocalReward(Strict):
    """A payoff that is not Archipelago's (ECHOES.md §14.2).

    Recorded in the save because it is *earned* — a note you found stays
    found — and worth exactly zero to Archipelago. The closed catalog is
    the enforcement: there is no shape here that could name an AP item, a
    location, a Check, a Coin, a Signal Key or an Echo, because the only
    fields are a kind from the catalog, a local id and where it was found.

    `source_zone_id` is a Zone id, never a location id. A local reward
    that could carry a location id would be a second, unvalidated path to
    AP truth, which is the one thing §14.2 exists to prevent.
    """
    kind: Literal[
        "epsilon_note", "challenge_marker", "cosmetic_grant",
        "hub_decoration", "lab_fixture", "flavor_log",
    ]
    #: Local identity, unique per campaign. Not an AP id in any namespace.
    reward_id: str = Field(min_length=1, max_length=48,
                           pattern=r"^[a-z0-9_]+$")
    display_name: str = Field(min_length=1, max_length=C.MAX_TEXT_LEN)
    description: str = Field(default="", max_length=C.MAX_TEXT_LEN)
    source_zone_id: str = Field(default="", max_length=24)
    #: For `challenge_marker`: the personal best, in seconds. Zero means
    #: "recorded, never beaten", which is a different thing from absent.
    best_seconds: float = Field(default=0.0, ge=0.0, le=36000.0)


class CampaignScale(Strict):
    """The campaign's immutable scale, recorded in the save.

    Defaults to the PROTOTYPE, not the production default, and that is the
    whole point. A save written before these options existed has no scale
    block, so it loads as the 30-location / 3-Check campaign it actually
    was. Defaulting to 450 would invent 420 locations the seed never had
    and strand every item the multiworld placed on them.

    It also makes the failure direction safe: code that forgets to record
    the real scale produces a campaign that is too SMALL, which refuses
    allocations, rather than one that is too large, which hands out
    locations Archipelago has never heard of.

    Validated through `CampaignConfig`, so the save cannot hold a scale the
    rest of the system would refuse.
    """
    location_count: int = C.PROTOTYPE_CONFIG.location_count
    zone_target_checks: int = C.PROTOTYPE_CONFIG.zone_target_checks
    zone_budget: int = C.PROTOTYPE_CONFIG.zone_budget

    @model_validator(mode="after")
    def _within_the_tested_range(self) -> "CampaignScale":
        self.config()          # raises if any option is out of bounds
        return self

    def config(self) -> C.CampaignConfig:
        return C.CampaignConfig(
            location_count=self.location_count,
            zone_target_checks=self.zone_target_checks,
            zone_budget=self.zone_budget)


class CampaignSave(Strict):
    """The on-disk campaign. Written atomically (temp, fsync, os.replace).

    Owns generated content and local decisions ONLY. Never persists a second
    copy of AP truth.

    Immutable, like everything else here. Build the next one with
    `transitions.py`; never edit this one.
    """
    save_version: Literal[1] = 1
    schema_version: Literal[8] = 8

    seed_name: str = Field(min_length=1, max_length=128)
    team: int = Field(ge=0)
    slot_id: int = Field(ge=0)
    slot_name: _AP_STR

    epsilon_creativity: Literal[0, 1, 2] = 1

    #: Immutable campaign scale (CAMPAIGN_SCALE.md). Absent in every save
    #: written before the options existed, which is exactly how those
    #: campaigns keep their prototype shape.
    scale: CampaignScale = CampaignScale()

    track_order: tuple[_AP_STR, ...] = ()
    track_cursor: int = Field(default=0, ge=0)
    generation_counter: int = Field(default=0, ge=0)

    #: Monotonic accumulator, incremented at purchase time and already
    #: inclusive of pending purchases. Only the rollback path decrements it.
    coins_spent: int = Field(default=0, ge=0)
    pending_checks: tuple[PendingCheck, ...] = ()
    #: S9. Earned, local, and worth nothing to Archipelago (§14.2). In the
    #: save because finding a note twice should not be a thing that
    #: happens; never in the fold, because a local reward is not a
    #: mechanic and derives nothing.
    local_rewards: tuple[EarnedLocalReward, ...] = Field(
        default=(), max_length=C.MAX_LOCAL_REWARDS)

    #: Charges spent, per consumable. Absent for every campaign that has
    #: never held one, which is every campaign written before the slot
    #: existed -- so an old save loads unchanged rather than migrating.
    consumable_uses: tuple[ConsumableUse, ...] = ()
    #: Charges authorized and not yet reported as launched.
    #:
    #: **Already counted in `consumable_uses`** — an authorization moves
    #: `spent` when it is written, and this is the record that lets an
    #: UNLAUNCHED attempt be cancelled. So it is not a second ledger to
    #: add up; subtracting it again would double-charge.
    #:
    #: **Deliberately not mirrored on the snapshot.** Only the process
    #: that made an authorization knows whether the effect launched, and
    #: that is the one fact a release turns on. A fresh client is handed
    #: the reduced `charges_left` and nothing it could release — which
    #: is the point, because it cannot know what the dead process did.
    consumable_authorizations: tuple[ConsumableAuthorization, ...] = ()
    #: WHICH DEPLOYMENT THOSE USES BELONG TO — the `zone_id` the player
    #: was last sent into. Charges refill when a deployment BEGINS, and
    #: this is what tells one beginning from a repeat: `enter_zone` is
    #: called again on re-entry, on a generation retry and on a reconnect,
    #: and none of those is a new deployment.
    #:
    #: Empty for a campaign that has never deployed, which is also every
    #: save written before the field existed.
    consumable_deployment: str = Field(default="", max_length=64)
    #: WHICH SUPPLY THOSE USES BELONG TO. Monotonic, minted only by a
    #: refill, never reused — so a use minted against an old supply
    #: carries a number that no longer exists and is refused on identity
    #: rather than on arithmetic.
    #:
    #: `use_index` alone cannot do that job. An old use 1 arriving after
    #: a refill matches the first use due (`1 == 0 + 1`), and an old use
    #: 3 matches again once two legitimate new uses have brought the
    #: count to 2. Both eat a charge from the fresh supply. The Zone id
    #: is not enough either: it is reused every time you go back.
    #:
    #: Same shape as `proposal_id`/`attempt` — the server mints, the
    #: snapshot mirrors, the client captures at the moment it acts and
    #: echoes on the next intent. Zero for a campaign that has never
    #: deployed, which is also every save written before the field
    #: existed.
    consumable_generation: int = Field(default=0, ge=0)

    def charges_left(self, component_id: str) -> int:
        """Uses remaining on a consumable. Zero for anything that is not
        one, so a caller never has to ask twice.

        A read of the save rather than a transition: it returns a number,
        and `transitions.py`'s census is the list of things that return a
        `CampaignSave`.
        """
        owned = self.derive().by_id(component_id)
        if owned is None or owned.kind != "action":
            return 0
        charges = getattr(owned.component, "charges", None)
        if charges is None:
            return 0
        spent = next((u.spent for u in self.consumable_uses
                      if u.component_id == component_id), 0)
        return max(charges - spent, 0)

    #: The interpretation log: append-only, ordered by `interpretation_seq`,
    #: and the ONLY persisted form of what the player has earned. Live
    #: mechanics are a fold over it (`mechanics.derive_mechanics`) and are
    #: never written to disk.
    #:
    #: Tuples, not dicts. v0.6 keyed these by id, and nothing tied the key to
    #: the id inside the value — `{"totally_bogus": echo_89100002}` validated,
    #: defeating the dedupe key the design is built on. One representation,
    #: with `zone_by_id` / `interpretation_by_id` for lookup.
    interpretations: tuple[EchoInterpretation, ...] = ()
    #: Persisted, monotonic, always ahead of every number issued. Never
    #: derived from the log — see `_reject_nonmonotonic_seq`.
    next_interpretation_seq: int = Field(default=0, ge=0)
    slots: SlotAssignment = Field(default_factory=lambda: SlotAssignment())

    zones: tuple[ZoneRecord, ...] = ()
    active_zone_id: str | None = None
    completed_zone_count: int = Field(default=0, ge=0)
    zone_history: tuple[str, ...] = ()

    shop: ShopState = Field(default_factory=ShopState)
    goal_sent: bool = False

    @model_validator(mode="after")
    def _references_resolve(self):
        _reject_duplicate_ids(self.zones, "zone_id", "zone_id")
        _reject_duplicate_ids(self.interpretations, "echo_id", "echo_id")
        _reject_nonmonotonic_seq(
            self.interpretations, self.next_interpretation_seq
        )
        # Folding here means a corrupt log is unrepresentable rather than
        # merely detected later: a CampaignSave that cannot fold cannot be
        # constructed, so it can never be written to disk.
        _folded = derive_mechanics(self.interpretations)
        _reject_unslottable(self.slots, _folded)
        _reject_impossible_charges(self.consumable_uses, _folded)
        _reject_duplicate_pending(self.pending_checks)
        _reject_unbacked_pending(self.pending_checks, self.zones)
        _reject_underfunded_ledger(self.coins_spent, self.pending_checks)

        if self.active_zone_id and self.active_zone_id not in {
                z.zone_id for z in self.zones}:
            raise ValueError(f"active_zone_id '{self.active_zone_id}' has no record")

        # At most one Zone may hold locations. Without this the v0.4
        # orphan shape - several non-terminal Zones with active_zone_id on
        # one of them - stays representable.
        holding = [z for z in self.zones if z.holds_locations]
        if len(holding) > 1:
            raise ValueError(
                "more than one Zone holds locations: "
                + ", ".join(sorted(z.zone_id for z in holding))
            )

        # `active_zone_id` NAMES WHERE THE PLAYER IS, and failing that,
        # the Zone being prepared for them.
        #
        # It used to mean "the holder", which worked while leaving a Zone
        # meant finishing or abandoning it. Two states broke that:
        # DORMANT holds locations with nobody in it, and VISITING has
        # somebody in it holding nothing. Ordering the rule by occupancy
        # first covers both and says the thing a reader expects it to.
        occupied = [z for z in self.zones
                    if z.state in OCCUPIED_ZONE_STATES]
        if len(occupied) > 1:
            raise ValueError(
                "more than one Zone is occupied: "
                + ", ".join(sorted(z.zone_id for z in occupied))
            )
        waiting = [z for z in holding if z.state != "DORMANT"]
        expected = occupied[0].zone_id if occupied else (
            waiting[0].zone_id if waiting else None)
        if self.active_zone_id != expected:
            raise ValueError(
                f"active_zone_id is {self.active_zone_id!r} but the "
                f"player is in {expected!r}"
                if expected else
                "active_zone_id must be cleared when no Zone is occupied "
                "or waiting"
            )

        stocked = {i.location_id for i in self.shop.stock}
        reserved = {i for z in self.zones if z.holds_locations
                    for i in z.allocated_location_ids}
        clash = sorted(stocked & reserved)
        if clash:
            raise ValueError(
                "the shop is offering locations a live Zone already holds: "
                + ", ".join(str(i) for i in clash)
            )
        in_flight = {p.location_id for p in self.pending_checks}
        if stocked & in_flight:
            raise ValueError(
                "the shop is offering locations that are already in flight: "
                + ", ".join(str(i) for i in sorted(stocked & in_flight))
            )
        return self

    @model_validator(mode="after")
    def _every_location_belongs_to_this_campaign(self):
        """Ids are universal; a CAMPAIGN is a prefix of them.

        The models are bounded by the 600-id universe so that a save can
        hold whichever prefix its seed was generated with. That bound
        alone would let a 30-location campaign reserve Check 400, which
        Archipelago has never heard of -- so the campaign's own range is
        checked here, where the scale is known.
        """
        config = self.scale.config()
        active = range(config.first_location_id, config.last_location_id + 1)
        for label, ids in (
                ("a Zone", {i for z in self.zones
                            for i in z.allocated_location_ids}),
                ("the shop", {i.location_id for i in self.shop.stock}),
                ("a pending check",
                 {p.location_id for p in self.pending_checks})):
            outside = sorted(i for i in ids if i not in active)
            if outside:
                raise ValueError(
                    f"{label} holds locations this {config.location_count}"
                    "-location campaign does not have: "
                    + ", ".join(str(i) for i in outside))
        return self

    @model_validator(mode="after")
    def _the_goal_is_reserved_for_the_finale(self):
        """The whole goal reservation, in ONE place.

        v0.5 stated the rule in prose five times and enforced it on the
        Zone path only, so `6 coins -> buy Check 030 -> win` was a legal
        message sequence. v0.7 fixed that with a closed id range on every
        acquisition-capable field -- which worked because the goal was
        always the last of exactly thirty locations.

        It is now the last of however many this campaign has, so a static
        range cannot express it and this validator is the rule: the
        finale Zone holds the goal and nothing else, and no other path
        holds it at all.
        """
        goal = self.scale.config().goal_location_id
        for zone in self.zones:
            holds = goal in zone.allocated_location_ids
            if zone.is_finale and zone.allocated_location_ids not in (
                    (goal,), ()):
                raise ValueError(f"a finale Zone holds exactly [{goal}]")
            if holds and not zone.is_finale:
                raise ValueError(
                    f"{goal} is reserved for the finale Zone")
        if any(i.location_id == goal for i in self.shop.stock):
            raise ValueError(
                f"{goal} is reserved for the finale Zone and can never be "
                "purchased")
        for pending in self.pending_checks:
            if pending.location_id == goal and pending.source != "zone":
                raise ValueError(
                    f"{goal} is reserved for the finale Zone and can never "
                    "be purchased")
        return self

    def zone_by_id(self, zone_id: str) -> ZoneRecord | None:
        return next((z for z in self.zones if z.zone_id == zone_id), None)

    def interpretation_by_id(self, echo_id: str) -> EchoInterpretation | None:
        return next(
            (e for e in self.interpretations if e.echo_id == echo_id), None
        )

    def derive(self) -> Mechanics:
        """The live mechanics, and deliberately not cached on the model:
        a cached fold is a second source of truth waiting to go stale.

        This used to justify itself with "the log is at most 30
        entries", which was true of the prototype's thirty locations and
        is not true of a 450-location campaign — a full one accumulates
        ~449 interpretations, and the ceiling is ~599. The justification
        was re-EARNED rather than re-worded.

        Measured (`test_provider_input_size.py`): the fold is linear at
        roughly 8 microseconds per interpretation — about 0.2 ms at 30,
        3.5 ms at 449, 5.0 ms at 600 — on an event-driven path that runs
        per intent rather than per frame. Cheap enough to keep simple. A
        cache would buy single-digit milliseconds and cost invalidation
        correctness on the one value that must be identical everywhere,
        and the snapshot it rides in spends far more than that on
        serialisation.
        """
        return derive_mechanics(self.interpretations)

    @property
    def active_zone(self) -> ZoneRecord | None:
        return self.zone_by_id(self.active_zone_id) if self.active_zone_id else None

    @property
    def campaign_key(self) -> str:
        import hashlib
        raw = f"{self.seed_name}|{self.team}|{self.slot_id}"
        return hashlib.sha256(raw.encode("utf-8")).hexdigest()[:16]


# ---------------------------------------------------------------------------
# Normalized AP state
# ---------------------------------------------------------------------------

class ScoutedLocation(Strict):
    """One scouted location as Godot sees it.

    Item identity is omitted until revealed. v0.4 shipped every unrevealed
    item name to the client in every snapshot, which handed the client the
    answer to all 30 Checks before the player entered a Zone — and the
    reveal is the payoff moment the whole design is built around.
    """
    location_id: _LOC
    location_name: _AP_STR
    revealed: bool = False
    recipient_is_self: bool = False
    item_id: int | None = None
    item_name: _AP_STR | None = None
    recipient_player: int | None = None
    recipient_name: _AP_STR | None = None
    #: Recipient game is the one field revealed early by design: themes
    #: derive from it, so the player learns it the moment a Zone loads.
    recipient_game: _AP_STR | None = None
    flags: int | None = None

    @model_validator(mode="after")
    def _unrevealed_withholds_identity(self):
        # recipient_game is deliberately exempt: themes derive from it, so
        # the player learns it the moment a Zone loads. Everything else
        # identifies the item, item_id included.
        if not self.revealed:
            leaked = [n for n in ("item_id", "item_name", "recipient_player",
                                  "recipient_name", "flags")
                      if getattr(self, n) is not None]
            if leaked:
                raise ValueError(
                    f"unrevealed location must omit {', '.join(leaked)}"
                )
        return self


class ReceivedItem(Strict):
    ordinal: int = Field(ge=0)   # position in the reconstructed list
    item_id: int
    item_name: _AP_STR
    sender_player: int
    sender_name: _AP_STR
    sender_game: _AP_STR
    flags: int


# ---------------------------------------------------------------------------
# Hub
# ---------------------------------------------------------------------------

HubMode = Literal[
    "NO_CAMPAIGN",       # not connected / no save
    "GENERATING",        # a Zone is PENDING_GENERATION; nothing to enter yet
    "ZONE_READY",        # a Zone is GENERATED but not yet entered
    "ZONE_ACTIVE",       # a Zone is ACTIVE; portal resumes it
    "ZONE_DORMANT",      # a Zone was left with work outstanding; portal returns
    "ZONE_FAILED",       # no layout was ever accepted; the offer is to discard
    "ZONE_AVAILABLE",    # portal generates a new ordinary Zone
    "FINALE_ONLY",       # finale unlocked and nothing ordinary remains
    "WAITING_FOR_AP",    # nothing eligible; other players hold progression
    "ALL_CHECKS_CLEARED",  # everything done; postgame, nothing left to play
]

#: How many refused layouts a Zone gets before it stops being composed
#: again. Three, because a second attempt is an ordinary bad roll and a
#: fourth is a defect nothing here can fix by trying harder.
#:
#: Defined here rather than in `transitions`, which imports it, because
#: `ZoneRecord.layout_exhausted` reads it too and a budget spelled twice
#: is a budget that can disagree with itself about being spent.
MAX_LAYOUT_REFUSALS = 3


#: Zone state -> Hub mode, **total over `ZoneState` by assertion**.
#:
#: This was three entries in a dict literal inside `hub_status`, and
#: adding `VISITING` to the lifecycle without adding it here made every
#: snapshot raise `KeyError: 'VISITING'` the moment a player walked back
#: into a finished Zone. A partial map over a closed vocabulary is a
#: crash waiting for the next member; the assertion below is what makes
#: adding one impossible to forget, and it fires at import rather than
#: in front of a player.
ZONE_STATE_HUB_MODE: dict[str, HubMode] = {
    "PENDING_GENERATION": "GENERATING",
    "GENERATED": "ZONE_READY",
    "ACTIVE": "ZONE_ACTIVE",
    "DORMANT": "ZONE_DORMANT",
    # A revisit is the same experience as a first visit: the player is
    # in a Zone. It differs in accounting, not in what the Hub should
    # say about where they are — the snapshot invariant already said so,
    # and `hub_status` raised KeyError instead of implementing it.
    "VISITING": "ZONE_ACTIVE",
    # Neither is a Zone the Hub is holding: COMPLETE and ABANDONED both
    # release the player back to the Hub, and a COMPLETE Zone is offered
    # through `revisitable` rather than as the one Zone in hand.
    "COMPLETE": "",
    "ABANDONED": "",
}


assert set(ZONE_STATE_HUB_MODE) == set(get_args(ZoneState)), (
    "every ZoneState needs a Hub mode or an explicit empty one; a state "
    "missing from this map raises KeyError on the next snapshot")


def hub_mode_for(record) -> str:
    """The Hub mode a held Zone shows. **The only place that decides.**

    `ZONE_STATE_HUB_MODE` answers "what does this state normally show",
    and one case needs more than the state: a Zone whose every layout
    attempt was refused and which never had a manifest is DORMANT like
    any other, and it must not be offered as a way back in.

    **Derived, never stored.** There is no `FAILED` `ZoneState` and
    there must not be: `state` plus `layout_state` plus "is there a
    manifest" already answer the question, and a fourth field recording
    the same fact is a fact that can disagree with itself.
    """
    if getattr(record, "layout_exhausted", False):
        return "ZONE_FAILED"
    return ZONE_STATE_HUB_MODE[record.state]


#: The only two modes in which a `request_next_zone` intent is legal. Every
#: other mode either already holds a Zone or has nothing to allocate. Both
#: kinds of generation — ordinary and finale — are covered: the finale is
#: requested from FINALE_ONLY, never from GENERATING or a Zone-in-hand mode.
ZONE_REQUEST_MODES = ("ZONE_AVAILABLE", "FINALE_ONLY")

#: Modes in which the campaign already has a Zone and must not start another.
#:
#: **`ZONE_DORMANT` belongs here and did not exist**, which is the whole
#: softlock: a Zone walked out of still reserves its Checks and still
#: blocks generation, but nothing said so, and the Hub fell through to
#: ZONE_AVAILABLE and offered to design a new one. The bridge then
#: refused with "still holds locations" and there was no way back in.
#: `ZONE_FAILED` is held too: the Zone still reserves its Checks, which
#: is exactly why discarding it is an explicit act with a cost rather
#: than something the bridge does on the player's behalf.
ZONE_HELD_MODES = ("GENERATING", "ZONE_READY", "ZONE_ACTIVE",
                   "ZONE_DORMANT", "ZONE_FAILED")

#: Modes in which the player is STANDING IN a Zone, so `active_zone` is
#: non-null. Not the same question as `ZONE_HELD_MODES`, and conflating
#: the two is what made a dormant Zone impossible to describe: it is
#: held and unoccupied at once, which the single list could not say.
ZONE_OCCUPIED_MODES = ("GENERATING", "ZONE_READY", "ZONE_ACTIVE")

#: **THE LIST `portal_enabled` READS, AND THEREFORE THE LIST THE GAME
#: OBEYS.** There is one, and this is it.
#:
#: Both lanes found the same defect independently, from opposite ends.
#: `ZONE_DORMANT` was added to one of two near-identically named
#: constants and `portal_enabled` read the other, so the portal went
#: dark over a Zone the Hub was naming: the mode said "your Zone is
#: waiting", `resume_zone_id` said which one, and the button was greyed
#: out. From the engine side it looked like a portal that showed the
#: mode's prompt and refused to fire. Neither half was wrong, which is
#: why nothing caught it.
#:
#: Two spellings of one fact is how the lanes come to disagree. The
#: proposed collapse was `ZONE_ENTERABLE_MODES = ZONE_ENTER_MODES`; an
#: alias is still two names, a reader who greps the other one finds a
#: definition and may add to it, and the aliasing only holds while
#: nobody rebinds either. So `ZONE_ENTER_MODES` is gone rather than kept
#: equal to this by hand, and the engine's `HubController` spells it the
#: same way.
#: **`ZONE_FAILED` is deliberately absent.** That is the whole of the
#: repair on this side: the Hub used to advertise RETURN TO ZONE over a
#: Zone whose geometry the validator had refused three times, the player
#: walked in, the layout was refused again, and it went dormant once
#: more. The only affordance on screen was the loop.
ZONE_ENTERABLE_MODES = ("ZONE_READY", "ZONE_ACTIVE", "ZONE_DORMANT")

assert set(ZONE_ENTERABLE_MODES) <= set(get_args(HubMode))
assert set(ZONE_HELD_MODES) <= set(get_args(HubMode))
assert "ZONE_FAILED" not in ZONE_ENTERABLE_MODES + ZONE_REQUEST_MODES, (
    "a Zone that never laid out is neither enterable nor a reason to "
    "start another; it is a Zone to discard")


class ZoneHandle(Strict):
    """Enough to offer a Zone and no more: what to send, what to show."""

    zone_id: str = Field(min_length=1, max_length=C.MAX_AP_STRING_LEN)
    display_name: str = Field(default="", max_length=C.MAX_TEXT_LEN)


class HubStatus(Strict):
    """What the Hub portal may do right now.

    **Campaign state and connectivity are orthogonal axes**, and v0.7 stops
    conflating them. `mode` describes the campaign; `ap_online` describes
    Archipelago. v0.6 forced `portal_enabled` from `mode` alone, which made
    "a campaign is loaded and Archipelago is down" impossible to describe:
    Test P requires the mode be unchanged across a drop and the design forbids
    flapping into `WAITING_FOR_AP`, so the Hub had to show a live "generate"
    portal at exactly the moment `reset_server_state()` had cleared the scout
    table that generation needs.

    Everything that used to be an independently-set boolean the bridge could
    get wrong is now DERIVED. Five fields became five computed properties, and
    five of v0.6's invariants disappeared with them — a rule you cannot state
    wrongly needs no validator. What is left below is the short list of facts
    that are genuinely independent.

    `finale_unlocked` in particular is computed from the two counters beside
    it, so the finale gate is executable rather than decorative: v0.6 carried
    `FINALE_REQUIRED_SIGNAL_KEYS` and `FINALE_REQUIRED_OTHER_CHECKS` as
    defaults that no validator ever read, and `FINALE_ONLY` at 0/24 with zero
    Signal Keys validated.
    """
    mode: HubMode
    headline: str = Field(max_length=C.MAX_TEXT_LEN)
    detail: str = Field(default="", max_length=C.MAX_TEXT_LEN)

    #: Connectivity, not campaign state. False during an Archipelago outage;
    #: the mode is deliberately left alone (`DESIGN.md` §13.4).
    ap_online: bool = True

    goal_sent: bool = False
    postgame: bool = False

    #: Whether the Zone currently held IS the finale. Checked against
    #: `active_zone.is_finale` on the snapshot.
    holding_finale: bool = False

    #: WHICH Zone the portal enters, when `mode` is one of
    #: `ZONE_ENTERABLE_MODES`. Empty otherwise.
    #:
    #: **The Hub could not name a dormant Zone before this existed.**
    #: `rest_zone` clears `active_zone_id` — nobody is standing in the
    #: Zone any more — so the consumer's `active_zone()` came back empty
    #: and the portal had nothing to send `enter_zone` about. The Hub
    #: then reported ZONE_AVAILABLE and offered to design a new Zone,
    #: which the bridge refused with "still holds locations": a softlock
    #: reachable by walking out of a Zone and restarting, with the only
    #: escape being to abandon it and lose the Checks and the progress.
    resume_zone_id: str = Field(default="", max_length=C.MAX_AP_STRING_LEN)
    resume_zone_name: str = Field(default="", max_length=C.MAX_TEXT_LEN)

    #: WHICH Zone the discard affordance acts on, in `ZONE_FAILED` only.
    #: Empty otherwise, and a non-empty value IS the offer — there is no
    #: separate boolean, for the same reason `revisitable` has none.
    #:
    #: **A separate name from `resume_zone_id`, deliberately.** This Zone
    #: must not be entered, and a single id field whose safety depended
    #: on the reader also checking the mode is precisely how the portal
    #: came to light up over a Zone it could not enter. A consumer
    #: holding `discard_zone_id` cannot accidentally resume with it.
    #:
    #: The Hub already has the control: `hub.gd`'s `AbandonConsole`,
    #: with its confirm step and "unclaimed Checks return to the pool".
    #: It reads `BridgeClient.active_zone()` for the id, which is empty
    #: for a Zone nobody is standing in — so this is what it needs.
    discard_zone_id: str = Field(default="", max_length=C.MAX_AP_STRING_LEN)
    discard_zone_name: str = Field(default="", max_length=C.MAX_TEXT_LEN)

    #: Finished Zones the player may walk back into, newest first.
    #:
    #: Separate from `resume_zone_id` because they are different offers:
    #: at most one Zone is unfinished and blocks generation, while any
    #: number of COMPLETE ones stay open and block nothing. A revisit
    #: reserves no locations and counts no completion twice.
    #: Uncapped, deliberately. `CampaignSave.zones` has no limit, and
    #: this is derived from it, so any bound here is an invented one: a
    #: campaign that finished 65 Zones had its whole snapshot REFUSED,
    #: which is a long game breaking on arithmetic nobody chose. A
    #: `ZoneHandle` is an id and a name, so even several hundred is
    #: noise beside the fold the same message already carries.
    revisitable: tuple[ZoneHandle, ...] = ()

    #: The two operands of the finale gate, and the two thresholds.
    signal_keys: int = Field(default=0, ge=0)
    finale_progress: int = Field(default=0, ge=0)
    #: Defaulted to the prototype's 24, and SET by the engine from the
    #: campaign's own config on every snapshot -- the Hub renders this
    #: number, so a 450-location campaign that shipped the default would
    #: tell the player it needs 24 of 449.
    finale_required: int = C.FINALE_REQUIRED_OTHER_CHECKS
    signal_keys_required: int = C.FINALE_REQUIRED_SIGNAL_KEYS

    @computed_field
    @property
    def finale_unlocked(self) -> bool:
        """Whether the finale threshold is MET. Never suppressed.

        v0.6's `finale_available` conflated "unlocked" with "offerable now"
        and its own docstring claimed the field was independent of `mode`
        while four validator branches constrained it. An implementer setting
        it to the honest threshold value raised on every snapshot from the
        moment the 24th Check confirmed while a Zone was still held.
        """
        return (self.finale_progress >= self.finale_required
                and self.signal_keys >= self.signal_keys_required)

    @computed_field
    @property
    def finale_offered(self) -> bool:
        """Whether the portal may start the finale right now.

        Suppressed while a Zone is held — taking it mid-Zone would strand
        that Zone's unclaimed Checks — and while Archipelago is down.
        """
        return self.finale_unlocked and self.accepts_zone_request

    @computed_field
    @property
    def portal_enabled(self) -> bool:
        """Both axes, which is the whole point.

        A Zone that already exists locally can be entered or resumed with
        Archipelago down; claiming its rewards still blocks until reconnect,
        as specified. Starting a NEW Zone needs the scout table, so it waits.
        """
        if self.mode in ZONE_ENTERABLE_MODES:
            return True
        if self.mode in ZONE_REQUEST_MODES:
            return self.ap_online
        return False

    @computed_field
    @property
    def accepts_zone_request(self) -> bool:
        """Whether `request_next_zone` is legal right now, finale or not.

        The bridge's one-Zone-at-a-time admission test. `RequestNextZone
        .finale` selects WHICH Zone, never WHETHER one may be started, so the
        ordinary and finale paths cannot answer this differently.
        """
        return self.mode in ZONE_REQUEST_MODES and self.ap_online

    @computed_field
    @property
    def generation_in_progress(self) -> bool:
        return self.mode == "GENERATING"

    @model_validator(mode="after")
    def _mode_is_consistent(self):
        if self.mode == "FINALE_ONLY" and not self.finale_unlocked:
            raise ValueError(
                "mode FINALE_ONLY requires the finale threshold to be met "
                f"({self.finale_progress}/{self.finale_required} Checks, "
                f"{self.signal_keys}/{self.signal_keys_required} Signal Keys)"
            )
        if self.mode == "WAITING_FOR_AP" and self.finale_unlocked:
            raise ValueError(
                "not waiting on Archipelago if the finale is unlocked; "
                "use FINALE_ONLY"
            )
        if self.holding_finale and self.mode not in ZONE_HELD_MODES:
            raise ValueError(
                f"mode {self.mode} holds no Zone, so holding_finale is false"
            )
        if self.postgame and not self.goal_sent:
            raise ValueError("postgame requires goal_sent")
        if self.mode == "ALL_CHECKS_CLEARED" and not self.goal_sent:
            raise ValueError("every Check cleared implies the goal was sent")
        # `discard_zone_id` IS `ZONE_FAILED` AND NOTHING ELSE, because
        # the Hub's abandon console resolves its target conditionally on
        # exactly that: a consumer that swapped its existing lookup for
        # this one unconditionally would show a prompt, arm a
        # confirmation and send nothing in the three modes it already
        # serves. Stated as an invariant rather than as a sentence in a
        # handoff, because the handoff said it and said it wrongly.
        #
        # `resume_zone_id` gets NO matching rule. It is legitimately set
        # in GENERATING — the Hub names the Zone being designed — which
        # is not in `ZONE_ENTERABLE_MODES`, so the symmetric-looking
        # invariant is simply false. Written here once, refused by 128
        # tests, and left as a note so nobody adds it again for the
        # pleasure of the symmetry.
        if bool(self.discard_zone_id) != (self.mode == "ZONE_FAILED"):
            raise ValueError(
                f"discard_zone_id is set in {self.mode}; it names the "
                "Zone the Hub offers to discard because it cannot be "
                "entered, which is ZONE_FAILED and nothing else")
        return self


# ---------------------------------------------------------------------------
# Snapshot
# ---------------------------------------------------------------------------

class CampaignSnapshot(Strict):
    type: Literal["campaign_snapshot"] = "campaign_snapshot"
    protocol_version: Literal[8] = 8

    bridge_connected: bool
    ap_connected: bool
    ap_mode: Literal["real", "mock"]
    #: `sample` is a DIAGNOSTIC axis, not a shipping one: it serves one
    #: named proposal out of the declared sample so a case the offline
    #: census names can be put in front of a real client and a real
    #: bridge. Listed here because the snapshot is a closed vocabulary
    #: and an unlisted provider makes every snapshot unserialisable --
    #: which is how the first run of it failed, with the client unable to
    #: connect at all rather than with a word about the provider.
    epsilon_provider: Literal["claude", "mock", "fallback", "sample"]
    race_mode: bool = False

    #: AP-derived counters are meaningful only when this is true.
    #: CommonContext clears items_received and locations_info on every
    #: disconnect, so a raw recount mid-outage reads zero for all of them.
    #: The bridge retains its last-known values and sets this flag instead.
    ap_state_is_current: bool = False

    seed_name: str = Field(default="", max_length=128)
    slot_name: str = Field(default="", max_length=C.MAX_AP_STRING_LEN)
    slot_id: int = Field(default=0, ge=0)
    team: int = Field(default=0, ge=0)

    checked_location_ids: tuple[_LOC, ...] = ()
    missing_location_ids: tuple[_LOC, ...] = ()
    scouted: tuple[ScoutedLocation, ...] = ()

    signal_keys: int = Field(default=0, ge=0)
    unlocked_tier: int = Field(default=0, ge=0)
    coins_received: int = Field(default=0, ge=0)
    coins_spent: int = Field(default=0, ge=0)
    static_received: int = Field(default=0, ge=0)
    static_glitch_units: int = Field(default=0, ge=0)

    #: Both halves are sent. The log is what the archive shows — provenance,
    #: concepts, which item is responsible for what. `mechanics` is the
    #: FOLD, computed by the bridge, because re-implementing it in GDScript
    #: would be a second source of truth for the one thing that has to be
    #: identical everywhere.
    #:
    #: The log is LIFETIME history. At the prototype's thirty locations it
    #: was ~25 KiB; a 450-location campaign ends around 449 entries and
    #: ~390 KiB, and every one of the dozen-odd `broadcast_snapshot()`
    #: calls re-sent all of it, for a list that only ever grows at the
    #: end. So a snapshot MAY omit it — see `interpretations_complete`.
    interpretations: tuple[EchoInterpretation, ...] = ()
    #: True when `interpretations` above is the whole log. False when the
    #: sender elided it because the receiver already has this exact log,
    #: and the receiver should keep the last complete one it was given.
    #:
    #: BACK-COMPAT, deliberately: the default is True and an elided log is
    #: sent as the empty tuple, so a snapshot built without thinking about
    #: any of this — a test, a tool, `smoke.py` — means exactly what it
    #: always meant, and a client that ignores the flag entirely sees an
    #: empty archive rather than a wrong one. Every connect and every
    #: `hello` is answered with a complete snapshot, so no client can be
    #: joined to the stream without a full log to cache first.
    #:
    #: FROZEN FOR THE ART A/B: `mechanics` below could be elided on this
    #: same key and is ~97% of what remains, but no transport change
    #: lands between the pre-art and post-art runs of the same Zone 1.
    #: See `docs/PLAYTEST_BASELINE.md`, "THE A/B FREEZE".
    interpretations_complete: bool = True
    #: The lifetime length of the log, sent whether or not the log is, so
    #: a count-only consumer never has to know which kind it received.
    interpretation_count: int = Field(default=0, ge=0)
    mechanics: Mechanics = Field(default_factory=lambda: Mechanics())
    slots: SlotAssignment = Field(default_factory=lambda: SlotAssignment())
    #: What the player has found that Archipelago does not care about
    #: (§14.2). Mirrored from the save rather than folded: a local reward
    #: derives nothing and grants no mechanic, so it has no business in
    #: `mechanics` — but a note you found stays found, and the client is
    #: what has to stop drawing a pickup it already has.
    local_rewards: tuple[EarnedLocalReward, ...] = ()
    #: Charges spent, per consumable, so the client can show what is
    #: left. The component's `charges` is already in `mechanics`; this is
    #: the half that moves, and the client subtracts rather than counting
    #: its own button presses -- a second count is a second truth.
    consumable_uses: tuple[ConsumableUse, ...] = ()
    #: The supply those uses belong to, mirrored from the save for the
    #: client to capture and echo on `use_consumable`. It is also how the
    #: client knows a refill happened: a snapshot under a different
    #: generation retires every use it still had in flight, so a request
    #: from the old supply can never be subtracted from the new one.
    consumable_generation: int = Field(default=0, ge=0)

    active_zone: ZoneRecord | None = None
    #: The identity of the proposal `active_zone` holds, for the client
    #: to capture when it starts a build and echo on `layout_result`.
    #:
    #: **THE CARRIER THE GAME ACTUALLY READS.** `main.gd::_to_zone` is
    #: driven by the snapshot and builds from
    #: `BridgeClient.active_zone()["zone"]`; it never reads `zone_ready`,
    #: which nothing in the client is connected to. `zone_ready` carries
    #: the same identity for the offer, and there are paths where it is
    #: the only one that does not reach a build — a cold restart into a
    #: Zone that was generated but never committed gets a snapshot and
    #: no offer at all, and a client with nothing to bind would send
    #: nothing and be read as one that predates the field.
    #:
    #: Not two copies of a fact: both are `layout.proposal_digest` of the
    #: same record, derived on every send and stored nowhere, so they
    #: cannot disagree. `""` when no Zone is held.
    active_proposal_id: str = Field(default="", max_length=16)
    completed_zone_count: int = Field(default=0, ge=0)
    shop: ShopState = Field(default_factory=ShopState)
    pending_checks: tuple[PendingCheck, ...] = ()

    hub: HubStatus
    last_generation_error: str | None = Field(default=None, max_length=C.MAX_TEXT_LEN)

    @computed_field
    @property
    def available_capabilities(self) -> tuple[str, ...]:
        """What the player can do RIGHT NOW, over what is equipped.

        Derived here rather than in GDScript, for the reason the fold is:
        re-implementing "can this campaign grapple" in the client would
        be a second answer to a question that has exactly one.

        Distinct from the OWNED set generation reasons over. A Zone is
        built against what the campaign owns; the player walks into it
        with whatever they slotted, so the difference between the two is
        what a NOT YET gate is FOR — and it is why that gate is a
        reachable state rather than dead code.
        """
        return M.available_capabilities(self.mechanics, self.slots)

    @computed_field
    @property
    def coins_available(self) -> int:
        """Derived, never stored — `DESIGN.md` §12 said so and v0.6 shipped it
        as a free integer that could read 9999 against zero received."""
        return max(0, self.coins_received - self.coins_spent)

    @model_validator(mode="after")
    def _mirrors_are_consistent(self):
        """The same invariants the save enforces, on the message Godot reads.

        v0.6 closed these on `CampaignSave` only, so the snapshot could carry
        a pending claim on the goal, two pending checks for one location, or
        a slotted Action the player did not own.
        """
        _reject_duplicate_pending(self.pending_checks)
        _reject_unbacked_pending(
            self.pending_checks,
            (self.active_zone,) if self.active_zone else ())
        _reject_underfunded_ledger(self.coins_spent, self.pending_checks)
        _reject_duplicate_ids(self.interpretations, "echo_id", "echo_id")
        # An elided log is elided, not truncated. The two legal shapes are
        # the whole log with its own length, or nothing at all carrying the
        # length it would have had; a third shape -- SOME of the log -- is a
        # silently wrong archive, so it cannot be constructed at all.
        if self.interpretations_complete:
            if self.interpretation_count != len(self.interpretations):
                raise ValueError(
                    f"interpretation_count {self.interpretation_count} "
                    f"disagrees with the {len(self.interpretations)} "
                    "interpretations sent alongside it")
        elif self.interpretations:
            raise ValueError(
                f"{len(self.interpretations)} interpretations were sent "
                "with interpretations_complete=False; an elided log is sent "
                "empty, never partially")
        # Against the mechanics actually sent, not a re-fold: if the two
        # ever disagreed, the client would render one and validate the other.
        _reject_unslottable(self.slots, self.mechanics)

        both = sorted(set(self.checked_location_ids)
                      & set(self.missing_location_ids))
        if both:
            raise ValueError(
                "a location cannot be both checked and missing: "
                + ", ".join(str(i) for i in both)
            )
        if self.unlocked_tier > min(self.signal_keys, C.TIER_COUNT - 1):
            raise ValueError(
                f"unlocked_tier {self.unlocked_tier} exceeds what "
                f"{self.signal_keys} Signal Keys unlock"
            )
        if self.hub.signal_keys != self.signal_keys:
            raise ValueError("hub.signal_keys must mirror the campaign's count")
        return self

    @model_validator(mode="after")
    def _hub_agrees_with_the_zone(self):
        """One mapping from Zone state to Hub mode, in one place.

        v0.5 left `ZoneRecord.state` and `HubStatus.mode` as two independent
        descriptions of the same fact, related only by prose. Every D3
        symptom was a disagreement between them.
        """
        az = self.active_zone
        if az is not None and az.state in TERMINAL_ZONE_STATES \
                and az.state not in OCCUPIED_ZONE_STATES:
            raise ValueError(
                f"active_zone '{az.zone_id}' is {az.state}; a terminal Zone "
                "reserves nothing and must not be presented as active"
            )
        # DORMANT is the one non-terminal state that is never the active
        # Zone: it still reserves its Checks, and the player is in the
        # Hub. That half stands.
        #
        # **The other half of this comment was wrong and cost a
        # softlock.** It said DORMANT "pins NO hub mode" and that
        # "inventing a ZONE_DORMANT mode would put a Zone on screen that
        # nobody is standing in", with going back left as "a separate
        # affordance". No affordance was ever built. What shipped was a
        # Hub reporting ZONE_AVAILABLE over a Zone holding fifteen
        # Checks, a portal offering to design a new one, and a bridge
        # refusing that with "still holds locations" — reachable by
        # walking out of a Zone and restarting, escapable only by
        # abandoning it. ZONE_DORMANT does not put a Zone on screen;
        # it puts a DOOR on screen, which is what the player needs.
        if az is not None and az.state == "DORMANT":
            raise ValueError(
                f"active_zone '{az.zone_id}' is DORMANT; it is yours and "
                "you are not in it, so it is not the active Zone"
            )

        if az is None:
            if self.hub.mode in ZONE_OCCUPIED_MODES:
                raise ValueError(
                    f"mode {self.hub.mode} claims a Zone but active_zone is null"
                )
        else:
            want = ZONE_STATE_HUB_MODE[az.state]
            if self.hub.mode != want:
                raise ValueError(
                    f"active_zone is {az.state}, so mode must be {want}, "
                    f"not {self.hub.mode}"
                )

        # Ordinary vs finale, the paired path: `holding_finale` is not a
        # separate opinion about what is held.
        holding_finale = az is not None and az.is_finale
        if self.hub.holding_finale != holding_finale:
            raise ValueError(
                "holding_finale must describe active_zone.is_finale"
            )
        return self


# ---------------------------------------------------------------------------
# Godot -> bridge
# ---------------------------------------------------------------------------

class Hello(Strict):
    type: Literal["hello"]
    client_version: str = Field(max_length=32)


class ApConnect(Strict):
    type: Literal["ap_connect"]
    server: str = Field(max_length=256)
    slot_name: _AP_STR
    password: str = Field(default="", max_length=256)


class ApDisconnect(Strict):
    type: Literal["ap_disconnect"]


class StartMockCampaign(Strict):
    type: Literal["start_mock_campaign"]


class RequestNextZone(Strict):
    """Generate the next Zone.

    `finale` picks WHICH Zone — ordinary, or the reserved Check 030 Zone —
    and never whether one may be started. Admission is `HubStatus
    .accepts_zone_request` for both values, so the ordinary and finale paths
    cannot drift apart; `finale=True` additionally requires
    `HubStatus.finale_offered`.

    Concretely, the bridge refuses this intent whenever a Zone is held, and
    `GENERATING` counts as held. v0.5 only barred it for GENERATED and
    ACTIVE, so a second request arriving while the provider was still working
    started a second allocation against the same eligible pool.
    """
    type: Literal["request_next_zone"]
    finale: bool = False


class EnterZone(Strict):
    """Player walked into the portal. Moves GENERATED -> ACTIVE.

    v0.4 had no such intent, which is why GENERATED was unreachable and
    unrecoverable.
    """
    type: Literal["enter_zone"]
    zone_id: str = _ID


class LeaveZone(Strict):
    """Pause-menu Return to Hub. Zone stays ACTIVE; transient state resets."""
    type: Literal["leave_zone"]
    zone_id: str = _ID


class ExitZone(Strict):
    """Exit portal. Pure travel: completion is driven by Check confirmation,
    not by this intent, so it is a no-op-plus-snapshot on a finished Zone."""
    type: Literal["exit_zone"]
    zone_id: str = _ID


class AbandonZone(Strict):
    """Give up on a Zone that cannot be finished.

    Returns its unclaimed locations to the eligible pool and preserves any
    Checks already confirmed inside it. Without this, one enemy steered off
    a ledge blocks the campaign permanently.

    Offered from the pause menu AND from the Hub, because `GENERATING` and
    `ZONE_READY` are states where abandoning is the only exit and there is no
    pause menu to reach.
    """
    type: Literal["abandon_zone"]
    zone_id: str = _ID


class LayoutResult(Strict):
    """What the engine placed, offered to the bridge for validation.

    Nested rather than flattened: the payload is the engine's shape and
    it grows as the engine measures more, so carrying it whole keeps
    this message from needing a field per measurement. `layout.validate`
    is what types it, and it is strict about every part it reads.

    **Offered, not committed.** Only a layout that passes validation
    becomes a manifest; a failing one is refused and never acquires a
    digest.
    """
    type: Literal["layout_result"]
    zone_id: str = _ID
    layout: dict
    #: Which ATTEMPT this result is about, echoed from `ZoneReady`.
    #:
    #: `proposal_id` cannot answer this: two attempts at identical
    #: content carry the same digest, so a duplicate delivery of the
    #: first attempt's result -- a client retrying after a dropped
    #: connection, which the handler treats as the ordinary case --
    #: passes the content guard and is charged as a second failure.
    #: Measured: one real refusal became two, and three duplicates
    #: exhaust a Zone that never failed three times.
    #:
    #: WHERE THE CLIENT READS IT. `ZoneReady` carries it for the offer,
    #: but `main.gd::_to_zone` builds from
    #: `BridgeClient.active_zone()["zone"]` -- the campaign SNAPSHOT --
    #: and nothing in the client is connected to `zone_ready_received`.
    #: `ZoneRecord.layout_refusals` rides on that same record, so
    #: `ZoneController.setup` takes the ordinal and the proposal digest
    #: from one read of one message, at the moment the build starts, and
    #: `send_layout_result` echoes what was captured rather than what is
    #: current. A cold restart into a Zone that was generated and never
    #: committed gets a snapshot and no offer at all, which is the path
    #: an offer-only carrier would bind nothing on.
    #:
    #: Bounded by `MAX_LAYOUT_REFUSALS` because that is where the count
    #: saturates; past it the Zone is exhausted and no further attempt
    #: is offered.
    #:
    #: None means a client that does not send it, and behaves exactly as
    #: it does today. Absent is "cannot be checked", never "stale" --
    #: the same rule `proposal_id` follows.
    attempt: int | None = Field(default=None, ge=0,
                                le=MAX_LAYOUT_REFUSALS)
    #: Which PROPOSAL this result is about — `layout.proposal_digest` of
    #: the Zone as it was when the client started this build, echoed
    #: back from `ZoneReady`.
    #:
    #: A Zone can be replaced while a build is in flight: Epsilon
    #: composes new content after a refusal, and `reselect_hosts`
    #: regraphs the same content onto different hosts. A result that
    #: arrives afterwards is about a Zone that no longer exists, and
    #: without this it would spend the replacement's refusal budget, bar
    #: the replacement's rooms, or commit a layout of what it replaced.
    #:
    #: Optional, so a client that does not send one behaves exactly as
    #: it does today. Absent means "cannot be checked", never "stale".
    proposal_id: str | None = Field(default=None, min_length=16,
                                    max_length=16, pattern=r"^[0-9a-f]{16}$")


class BuildFailed(Strict):
    """The engine could not CONSTRUCT this proposal. There is no layout.

    **This is not a refused layout, and conflating the two would be a
    lie in both directions.** `LayoutResult` carries geometry the engine
    built and the bridge then judged; this says the engine never got
    that far -- `ZoneBuilder` could not route the rooms, so there is
    nothing to measure and nothing to validate. Sending an empty or
    part-built `layout` to borrow the refusal path would be fabricated
    evidence: the validator would report a geometry error for a
    geometry that was never laid down.

    **And it is not a generation-stage rejection either.** A proposal
    the bridge refuses before it is offered never reaches a client;
    `last_generation_error` is where that is reported. This one passed
    composition, was offered, was entered, and failed in the engine.

    **Why the bridge needs to hear it at all.** Without this message a
    failed build is silent: `ZoneController.setup` returns, no
    `layout_result` is ever sent, and the record sits ACTIVE waiting for
    a verdict that is not coming. The Hub stays in ZONE_ACTIVE, offering
    a way back into a Zone that cannot be built, and the campaign cannot
    move. What follows from this message is exactly what follows from a
    refusal -- `refuse_layout`, so the attempt is charged, a FRESH
    proposal is composed again inside the budget, a COMMITTED one is
    parked with its manifest intact, and past the budget the Zone goes
    DORMANT and the Hub offers ABANDON.

    `attempt` and `proposal_id` carry the same meaning and the same
    guards as on `LayoutResult`: which build this is the outcome of.
    They are what stop a late failure spending a replacement's budget.
    """
    type: Literal["build_failed"]
    zone_id: str = _ID
    #: The engine's own reason, as `ZoneBuilder` reported it.
    #:
    #: Bounded like every other text that reaches a snapshot. An
    #: over-long refusal string has already cost this project one hang:
    #: `CampaignSnapshot` raised on construction, which killed the
    #: generation task and the broadcast with it, and left the client in
    #: GENERATING forever. The client trims before sending and the
    #: bridge trims again before storing -- neither trusts the other.
    reason: str = Field(default="", max_length=C.MAX_TEXT_LEN)
    #: Which ATTEMPT failed, echoed from `ZoneReady`; see `LayoutResult`.
    attempt: int | None = Field(default=None, ge=0,
                                le=MAX_LAYOUT_REFUSALS)
    #: Which PROPOSAL failed, echoed from `ZoneReady`; see `LayoutResult`.
    proposal_id: str | None = Field(default=None, min_length=16,
                                    max_length=16, pattern=r"^[0-9a-f]{16}$")


class KeyCollected(Strict):
    """A Zone-local key picked up.

    **Idempotent by `key_id`, because the target set is monotone.** The
    same key twice is one key, a resend after a dropped connection is
    the normal case, and neither is an error. The engine already
    de-duplicates on its side; the bridge does so again rather than
    trusting it, because a set union is cheaper than a class of bug.

    Not an Archipelago item and never one: no location id, never
    scouted, never sent, gone when the Zone is.
    """
    type: Literal["key_collected"]
    zone_id: str = _ID
    key_id: str = Field(min_length=1, max_length=24,
                        pattern=r"^[a-z0-9_]+$")


class LatchFired(Strict):
    """A physics latch satisfied in the world.

    **Idempotent by `package_id/latch_id`, because a latch is monotone.**
    Design 2 §5.7 says a satisfied latch is never re-evaluated, so the
    same latch twice is one latch and a resend after a dropped
    connection is the normal case rather than an error.

    **Validated against the packages the manifest accepted, not against
    the message.** `record_key` once took any `key_id` the engine sent
    and wrote it into monotone save data; the identity of a latch is
    checked the same way a key's is now — against what the Zone's
    committed layout actually holds — because a latch nobody placed
    would otherwise become permanent state describing nothing.
    """
    type: Literal["latch_fired"]
    zone_id: str = _ID
    package_id: str = Field(min_length=1, max_length=32,
                            pattern=r"^[a-z0-9_]+$")
    latch_id: str = Field(min_length=1, max_length=32,
                          pattern=r"^[a-z0-9_]+$")


class ZoneStateSelected(Strict):
    """D-8. A player operated a setter and chose a Zone state.

    **P-3's gap, closed.** `ZoneProgress.with_macro` and
    `transitions.record_zone_state` both existed and there was no
    message that could reach them, so the engine had a selection it
    could not report. `ZoneState.as_reported()` was what it *would*
    send; this is the thing it sends.

    **Idempotent by `(variable_id, state)` and NOT monotone**, which is
    the difference from `LatchFired` and the reason this is its own
    intent rather than a field on that one. Selecting a state the
    variable already holds is absorbed; selecting a different one is a
    legitimate second event, because a reversible variable going back is
    the mechanic working rather than a replay to be rejected.

    **Validated against the accepted Zone**, like every sibling here:
    `record_zone_state` refuses a variable the Zone does not declare, a
    state it does not have, and -- the one a latch analogy misses -- a
    state no setter can select. §19.7 says nothing but a player
    operating a setter moves Zone state, so a state nothing selects is
    one nothing could have set.
    """
    type: Literal["zone_state_selected"]
    zone_id: str = _ID
    variable_id: str = Field(min_length=1, max_length=24,
                             pattern=r"^[a-z0-9_]+$")
    state: str = Field(min_length=1, max_length=24,
                       pattern=r"^[a-z0-9_]+$")


class ObjectTransported(Strict):
    """P16. A transported object arrived in a room.

    Idempotent by `(object_id, room_id)` and **not monotone**, same as
    `ZoneStateSelected` and for the same reason: carrying it back is the
    mechanic working, not a replay to reject.

    Validated against the accepted Zone: the object must be one the Zone
    declares and the room must be inside the `allowed_volume` §10.5 gave
    it. An object reported into a room it may not enter is refused
    rather than recorded -- a save that accepted it would describe a
    world the composer never allowed.
    """
    type: Literal["object_transported"]
    zone_id: str = _ID
    object_id: str = Field(min_length=1, max_length=24,
                           pattern=r"^[a-z0-9_]+$")
    room_id: str = Field(min_length=1, max_length=24,
                         pattern=r"^[a-z0-9_]+$")


class ObjectSettled(Strict):
    """O05-03. A transported object came to rest after the hand put it down.

    Validated like `ObjectTransported` (declared object, room inside its
    volume) and additionally refused for an object a consumer has taken.
    The pose is the engine's measurement; the bridge bounds it and
    stores it, and never invents one.
    """
    type: Literal["object_settled"]
    zone_id: str = _ID
    object_id: str = Field(min_length=1, max_length=24,
                           pattern=r"^[a-z0-9_]+$")
    room_id: str = Field(min_length=1, max_length=24,
                         pattern=r"^[a-z0-9_]+$")
    position: tuple[float, float, float]
    yaw: float = Field(ge=-7.0, le=7.0)


class ObjectConsumed(Strict):
    """O05-02. A declared consumer took the object it was waiting for.

    Names the MECHANISM, not the object: the consumer's declaration says
    which object it accepts and which state it sets, so a client cannot
    choose either. `record_object_consumed` refuses it unless the save
    already has that object in the consumer's own room.
    """
    type: Literal["object_consumed"]
    zone_id: str = _ID
    mechanism_id: str = Field(min_length=1, max_length=32,
                              pattern=r"^[a-z0-9_]+$")


class ObjectRecovered(Strict):
    """O05-03 / §10.5. A required object was lost and put back home.

    Recovery is a separate event from an arrival, so a correction is
    never silent. Refused for a consumed object: an installed object is
    not lost.
    """
    type: Literal["object_recovered"]
    zone_id: str = _ID
    object_id: str = Field(min_length=1, max_length=24,
                           pattern=r"^[a-z0-9_]+$")


class CarrierRested(Strict):
    """O05-06.2. A hosted minor's carrier came to rest.

    Sent only at rest -- parked at a stop, held by a STOP, or pausing in
    a declared dwell -- never mid-travel (Amalgam §5.3). The package is
    the minor's (`minor_<room>`); the bridge accepts it only for a
    carrier and stop the room's minor contract declares, and stores the
    offset the engine measured without inventing one.
    """
    type: Literal["carrier_rested"]
    zone_id: str = _ID
    package_id: str = Field(min_length=1, max_length=32,
                            pattern=r"^[a-z0-9_]+$")
    carrier_id: str = Field(min_length=1, max_length=32,
                            pattern=r"^[a-z0-9_]+$")
    t: float
    #: The stop it stands at or is bound for; empty only when held with
    #: no errand.
    destination: str = Field(default="", max_length=32,
                             pattern=r"^[A-Za-z0-9_]*$")
    held: bool = False


class LockOpened(Strict):
    """A locked door opened, identified by the door rather than the key.

    Idempotent by `(room_id, socket_id)`. One key may open several
    locks, so the key is not the identity of the event.
    """
    type: Literal["lock_opened"]
    zone_id: str = _ID
    room_id: str = Field(min_length=1, max_length=24,
                         pattern=r"^[a-z0-9_]+$")
    socket_id: str = Field(min_length=1, max_length=32,
                           pattern=r"^[a-z0-9_]+$")


class StationReached(Strict):
    """A warp station reached. Travel and save; never loadout editing.

    Idempotent by `station_id`.
    """
    type: Literal["station_reached"]
    zone_id: str = _ID
    station_id: str = Field(min_length=1, max_length=48,
                            pattern=r"^[a-z0-9_:]+$")


class EnemyDefeated(Strict):
    """An encounter member defeated (H-RESUME-R, D-06).

    Idempotent by `member`, because the target record is monotone: the
    same defeat twice is one defeat, and a resend after a dropped
    connection is the normal case. `member` is the declared identity
    `room/archetype#n` (see `ZoneProgress.defeated`), which the bridge
    checks against the Zone's own declaration before it is recorded.
    """
    type: Literal["enemy_defeated"]
    zone_id: str = _ID
    member: str = Field(min_length=5, max_length=64,
                        pattern=r"^[a-z0-9_]+/[a-z]+#[0-9]{1,3}$")


class ClaimCheck(Strict):
    """Sent when the player interacts with an unlocked reward object.

    The bridge re-verifies what it actually can: a campaign is loaded, the
    Zone is ACTIVE, the location is in that Zone's allocated_location_ids,
    it is not already confirmed, and no pending transaction exists for it.
    It cannot verify the chamber objective was satisfied — it does not
    simulate enemies. Objective gating is client-side.
    """
    type: Literal["claim_check"]
    zone_id: str = _ID
    location_id: _LOC


class BuyShopStock(Strict):
    """Buy one stocked location.

    `_NON_FINALE_LOC` makes `{"type":"buy_shop_stock","location_id":89100030}`
    an unparseable message rather than a message the bridge is trusted to
    refuse. The bridge still re-verifies stock membership and balance — this
    only removes the goal from the reachable input space.
    """
    type: Literal["buy_shop_stock"]
    location_id: _NON_FINALE_LOC


class SlotAction(Strict):
    """Put an owned Action in a slot, or clear the slot with a null id.

    Replaces v0.7's `equip_echo`: there are four slots now, and only Actions
    occupy them.
    """
    type: Literal["slot_action"]
    slot: SlotName
    component_id: str | None = Field(default=None, max_length=32)


class AuthorizeConsumable(Strict):
    """Ask the bridge to count a charge BEFORE launching the effect.

    **PROPOSED, NOT AGREED.** The client half is Prod's and is
    unwritten, so this is the bridge's side of a contract that has
    one owner per file and must have one shape. The proposal, the
    two boundaries it distinguishes and what it asks of the client
    are in `docs/D9_CONSUMABLE_ACCOUNTING_PROD.md`; if the engine
    lane prefers another accounting shape, this is the half that
    moves.

    Sent while the press is still cancellable and nothing irreversible
    has happened. The bridge writes the expenditure to the save and
    answers; only then may the client launch. A client that launches
    first and reports afterwards is relying on a report surviving the
    process, and it does not.

    The trio is `use_consumable`'s, unchanged, so the authorization and
    the report that settles it are the same compare-and-swap.
    """
    type: Literal["authorize_consumable"]
    component_id: str = Field(min_length=1, max_length=32)
    use_index: int = Field(ge=1, le=C.CONSUMABLE_CHARGES_MAX)
    generation: int = Field(ge=0)


class ReleaseConsumableAuthorization(Strict):
    """Cancel an authorized attempt that **never launched**.

    Only the process that authorized can know that, so the claim is the
    client's. What the bridge enforces is that the attempt being
    cancelled is the newest one — which is also why a client that has
    just relaunched cannot refund a dead process's expenditure.
    """
    type: Literal["release_consumable_authorization"]
    component_id: str = Field(min_length=1, max_length=32)
    use_index: int = Field(ge=1, le=C.CONSUMABLE_CHARGES_MAX)
    generation: int = Field(ge=0)


class UseConsumable(Strict):
    """Spend one charge of the Action in the consumable slot.

    Client-initiated because only the client knows the button was pressed
    and the Action actually fired. It names the component rather than the
    slot so a charge cannot be spent against whatever happens to be
    slotted by the time the message lands.
    """
    type: Literal["use_consumable"]
    component_id: str = Field(min_length=1, max_length=32)
    #: WHICH USE THIS IS MEANT TO BE — the first, the second. The engine
    #: accepts it only if it is the next one due, which is what makes a
    #: duplicate, a retry and a use minted before a refill all harmless
    #: without storing an identifier for any of them.
    use_index: int = Field(ge=1, le=C.CONSUMABLE_CHARGES_MAX)
    #: WHICH SUPPLY THAT INDEX COUNTS AGAINST — captured from the
    #: snapshot at the moment the button was pressed. `use_index` alone
    #: cannot reject a use minted before a refill: index 1 from the old
    #: supply is exactly the first index due after the refill, and an old
    #: index 3 matches again once two new uses have been spent. The
    #: generation makes both of those a mismatch.
    #:
    #: Required, unlike `proposal_id`, where absent legitimately means
    #: "this client never saw a proposal". Every snapshot carries a
    #: generation, so there is no honest reason to omit this one, and
    #: "unchecked" is the hole this field exists to close.
    generation: int = Field(ge=0)


class GrantLocalReward(Strict):
    """Record a local reward the player earned (ECHOES.md §14.2).

    Client-initiated because the world is where a note is found, and
    validated here because the save is where it is kept. There is no field
    that could name an AP item, location or Check — the intent is
    structurally incapable of the mistake §14.2 forbids, rather than
    trusted not to make it.
    """
    type: Literal["grant_local_reward"]
    kind: Literal[
        "epsilon_note", "challenge_marker", "cosmetic_grant",
        "hub_decoration", "lab_fixture", "flavor_log",
    ]
    reward_id: str = Field(min_length=1, max_length=48,
                           pattern=r"^[a-z0-9_]+$")
    display_name: str = Field(min_length=1, max_length=C.MAX_TEXT_LEN)
    description: str = Field(default="", max_length=C.MAX_TEXT_LEN)
    best_seconds: float = Field(default=0.0, ge=0.0, le=36000.0)


class ChamberDwell(Strict):
    """How long the player spent in one chamber. Seconds, one entry per
    chamber the Zone has, whether or not it was entered."""
    chamber_index: int = Field(ge=0, lt=C.ZONE_MAX_CHAMBERS)
    seconds: float = Field(ge=0.0, le=36000.0)


class ActivityOutcome(Strict):
    """What one activity did while the player was in the room with it.

    The questions the next playtest has to be able to answer, and the
    field that answers each:

      Did they notice it?      `entered`
      Did they try it?         `attempts`
      Did they understand it?  `attempts` against `completed`
      Did they finish it?      `completed`
      How long did it hold them? `active_seconds`
      Did a gate behave?       `not_yet`

    `entered` and `attempts` are deliberately separate. "Walked past it"
    and "had a go and gave up" are different findings, and a single
    engagement flag would have collapsed them into one number that could
    not distinguish a legibility problem from a difficulty one.
    """
    activity_id: str = Field(max_length=64)
    kind: ActivityKind
    room_id: str = Field(max_length=64)
    element_count: int = Field(ge=1, le=8)
    time_limit: float = Field(default=0.0, ge=0.0, le=120.0)
    ordered: bool = False
    #: The semantic capabilities it asked for, so a playtest can tell a
    #: gate that behaved from one nobody ever met.
    requires: tuple[ActivityCapability, ...] = Field(default=(),
                                                     max_length=2)
    #: The player came within reach of it at all.
    entered: bool = False
    #: Attempts started. Zero with `entered` true is "walked past it".
    attempts: int = Field(default=0, ge=0, le=9999)
    completed: bool = False
    #: Refused for a capability the player did not have equipped.
    not_yet: bool = False
    #: Seconds spent with an attempt actually running.
    active_seconds: float = Field(default=0.0, ge=0.0, le=36000.0)


class ZoneTiming(Strict):
    """What the Zone actually cost the player, measured (CAMPAIGN_SCALE.md 13).

    The 40-minute Zone and the 20-hour campaign are TARGETS. This is the
    only thing that can turn either into a fact, and it is the reason the
    engine's content budget can be calibrated against play rather than
    against a designer's guess.

    Godot owns the clock -- elapsed time, per-chamber dwell, deaths and
    encounter durations are things only the running game knows. The
    bridge joins them to the room and Zone VALUES it computed for the
    same Zone, so one local record holds both halves.

    Local only: the bridge appends it to a file under the save directory.
    Nothing is sent anywhere (CAMPAIGN_SCALE.md 13).
    """
    type: Literal["zone_timing"]
    zone_id: str = _ID
    #: Wall-clock inside the Zone, excluding time spent paused.
    elapsed_seconds: float = Field(ge=0.0, le=36000.0)
    deaths: int = Field(default=0, ge=0, le=9999)
    checks_completed: int = Field(default=0, ge=0,
                                  le=C.ZONE_TARGET_CHECKS_MAX)
    dwell: tuple[ChamberDwell, ...] = Field(default=(),
                                            max_length=C.ZONE_MAX_CHAMBERS)
    #: One entry per encounter the player finished, in seconds from the
    #: first shot to the last enemy dying. This is what
    #: `WORST_CASE_ENCOUNTER_TTK_BUDGET` was a guess about.
    encounter_seconds: tuple[float, ...] = Field(default=(), max_length=64)
    #: True when the player left through the portal rather than bailing
    #: to the Hub -- an abandoned Zone's elapsed time is not a Zone length.
    completed: bool = False
    #: One entry per activity the Zone built. Bounded by the most a Zone
    #: can hold: `ZONE_MAX_CHAMBERS` rooms times the schema's three
    #: activities each.
    activities: tuple[ActivityOutcome, ...] = Field(
        default=(), max_length=C.ZONE_MAX_CHAMBERS * 3)

    @model_validator(mode="after")
    def _one_entry_per_chamber(self):
        indices = [d.chamber_index for d in self.dwell]
        if len(set(indices)) != len(indices):
            raise ValueError("a chamber appears twice in the dwell record")
        ids = [a.activity_id for a in self.activities]
        if len(set(ids)) != len(ids):
            raise ValueError("an activity appears twice in the timing record")
        return self


class SetCreativity(Strict):
    type: Literal["set_creativity"]
    value: Literal[0, 1, 2]


class DebugCommand(Strict):
    """Debug overlay commands.

    `force_fallback_zone` is a Zone request like any other and goes through
    `HubStatus.accepts_zone_request`; it chooses the PROVIDER, not whether a
    Zone may be started. `grant_mock_*` are mock-AP only.
    """
    type: Literal["debug_command"]
    command: Literal[
        "resync", "print_snapshot", "force_fallback_zone",
        "grant_mock_coin", "grant_mock_signal_key", "clear_campaign",
    ]


ClientMessage = Annotated[
    Union[
        Hello, ApConnect, ApDisconnect, StartMockCampaign, RequestNextZone,
        EnterZone, LeaveZone, ExitZone, AbandonZone, ClaimCheck, BuyShopStock,
        SlotAction, AuthorizeConsumable,
        ReleaseConsumableAuthorization,
        UseConsumable, GrantLocalReward, SetCreativity,
        DebugCommand,
        ZoneTiming, KeyCollected, LockOpened, StationReached, LatchFired,
        ZoneStateSelected, ObjectTransported, ObjectSettled, ObjectConsumed,
        ObjectRecovered, CarrierRested, EnemyDefeated, LayoutResult,
        BuildFailed,
    ],
    Field(discriminator="type"),
]


# ---------------------------------------------------------------------------
# bridge -> Godot
# ---------------------------------------------------------------------------

class BridgeReady(Strict):
    type: Literal["bridge_ready"]
    protocol_version: Literal[8] = 8
    bridge_version: str = Field(max_length=32)


class ZoneReady(Strict):
    type: Literal["zone_ready"]
    zone: Zone
    used_fallback: bool
    #: The identity of THIS proposal, for the client to capture when it
    #: starts building and echo back on `layout_result`. See
    #: `LayoutResult.proposal_id`.
    proposal_id: str = Field(default="", max_length=16)
    #: WHICH ATTEMPT this offer is, for the client to capture beside
    #: `proposal_id` and echo on `layout_result`.
    #:
    #: `proposal_id` is CONTENT identity and stays that way: identical
    #: content hashes identically, which is correct and is what makes it
    #: useless for telling two attempts apart. After a refusal the
    #: campaign asks the provider again, and a deterministic provider
    #: hands back the same Zone -- same rooms, same graph, same digest.
    #: A result from the previous attempt then matches the current
    #: proposal exactly and is indistinguishable from a fresh failure.
    #:
    #: The ordinal is `ZoneRecord.layout_refusals` at the moment of the
    #: offer, so it is READ from the lifecycle rather than being a
    #: second counter to keep in step. It is not part of the digest and
    #: must never be folded into it.
    attempt: int = Field(default=0, ge=0, le=MAX_LAYOUT_REFUSALS)
    #: The committed layout, when this Zone already has one. Present on
    #: a re-entry and absent on a first generation, which is exactly the
    #: difference between replaying a layout and solving one.
    manifest: dict | None = None

    #: **Progress is NOT here, and that is deliberate.**
    #:
    #: It was, for one commit. `ZoneRecord.progress` already crosses in
    #: every snapshot, and `main.gd::_to_zone` — driven by `_on_snapshot`
    #: rather than by this message — reads it from
    #: `BridgeClient.active_zone()`. Adding it here made a second carrier
    #: for one fact on a different message, which is how two lanes come
    #: to disagree about what a player did. One carrier: the record.


NotificationKind = Literal[
    "check_confirmed", "echo_acquired", "reveal", "coin_received",
    "signal_key_received", "static_received", "shop_purchased",
    "fallback_used", "goal_reached", "ap_offline", "sync_warning",
    "zone_abandoned",
]


class Notification(Strict):
    """One-shot UI event. Never state: the snapshot is state."""
    type: Literal["notification"] = "notification"
    kind: NotificationKind
    title: str = Field(max_length=C.MAX_TEXT_LEN)
    lines: tuple[Annotated[str, Field(max_length=C.MAX_TEXT_LEN)], ...] = Field(
        default=(), max_length=12
    )
    location_id: _LOC | None = None
    echo_id: str | None = Field(default=None, max_length=32)


class BridgeError(Strict):
    """A refused or failed intent, reported rather than swallowed.

    **THE ONE SERVER MESSAGE WITH NO IDENTITY**, until `about`. `scope`,
    `recoverable` and `message` say what went wrong and nothing about
    what it went wrong ON, so two failed intents produce indistinguishable
    frames and a client can only toast the string. That is survivable for
    a refusal the player reads and forgets, and not survivable for one
    the client has to UNDO — a spend it is holding in flight stays held
    forever, subtracting from a count it will never be allowed to spend.
    """
    type: Literal["error"]
    scope: Literal["ap", "epsilon", "bridge", "protocol"]
    recoverable: bool
    message: str = Field(max_length=C.MAX_TEXT_LEN)
    #: WHAT THIS REFUSAL WAS ABOUT, as a domain key the refusing side
    #: builds from the intent — `use_consumable:<component>:<gen>:<index>`
    #: — never an opaque token the client made up. That is the house rule
    #: everywhere identity is echoed (`key_id`, `use_index`,
    #: `LatchFired.(package_id, latch_id)`): the name of the thing, so a
    #: replay or a stale frame names something that can be checked.
    #:
    #: Empty for every refusal that existed before this field, and empty
    #: means UNCHECKED, never "stale" — the `proposal_id` rule. A client
    #: resolves a pending operation on an exact match and on nothing else.
    about: str = Field(default="", max_length=C.MAX_TEXT_LEN)


ServerMessage = Annotated[
    Union[BridgeReady, CampaignSnapshot, ZoneReady, Notification, BridgeError],
    Field(discriminator="type"),
]
