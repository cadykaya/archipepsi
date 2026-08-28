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

from typing import Annotated, Literal, Union

from pydantic import (
    BaseModel, ConfigDict, Field, computed_field, model_validator,
)

try:
    from . import constants as C
    from .echo import EchoInterpretation, SlotName
    from .mechanics import Mechanics, derive_mechanics
    from .zone import Zone
except ImportError:  # pragma: no cover
    import constants as C
    from echo import EchoInterpretation, SlotName
    from mechanics import Mechanics, derive_mechanics
    from zone import Zone

PROTOCOL_VERSION = 8

_ID = Field(min_length=1, max_length=24, pattern=r"^[a-z0-9_]+$")

#: Any Archipepsi location, goal included. Correct for the read-only mirrors
#: of Archipelago truth (checked/missing/scouted) and for notifications: to
#: Archipelago, Check 030 is an ordinary location.
_LOC = Annotated[int, Field(ge=C.FIRST_LOCATION_ID, le=C.LAST_LOCATION_ID)]

#: Any location EXCEPT the goal. Required on every field that can RESERVE,
#: STOCK, PRICE or SELL a location — i.e. every acquisition path other than
#: the finale Zone. Derived from constants, and a plain range rather than a
#: Python-only validator so the restriction survives into
#: `protocol.schema.json` and into the engine.
_NON_FINALE_LOC = Annotated[int, Field(
    ge=C.FIRST_NON_FINALE_LOCATION_ID, le=C.LAST_NON_FINALE_LOCATION_ID)]

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
    "PENDING_GENERATION", "GENERATED", "ACTIVE", "COMPLETE", "ABANDONED"
]
TERMINAL_ZONE_STATES = ("COMPLETE", "ABANDONED")


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
    allocated_location_ids: tuple[_LOC, ...] = Field(
        min_length=1, max_length=C.ZONE_MAX_CHECKS
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
    def _finale_owns_the_goal(self):
        """The Zone half of the goal reservation (`constants.GOAL_LOCATION_ID`).

        Both directions, because either one alone is a hole: the finale holds
        the goal and nothing else, and nothing that is not the finale holds
        the goal at all. Every other acquisition path uses `_NON_FINALE_LOC`
        and cannot express the goal in the first place.
        """
        holds_goal = any(C.is_goal_location(i)
                         for i in self.allocated_location_ids)
        if self.is_finale and tuple(self.allocated_location_ids) not in (
                (C.GOAL_LOCATION_ID,), ()):
            raise ValueError(
                f"a finale Zone holds exactly [{C.GOAL_LOCATION_ID}]"
            )
        if not self.is_finale and holds_goal:
            raise ValueError(
                f"{C.GOAL_LOCATION_ID} is reserved for the finale Zone"
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
        if self.source == "shop":
            if C.is_goal_location(self.location_id):
                raise ValueError(
                    f"{C.GOAL_LOCATION_ID} is reserved for the finale Zone "
                    "and can never be purchased"
                )
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
    """Which owned Action sits in each of the four slots.

    Four named fields rather than a dict: the slot grammar belongs to the
    game, not to generation, so it is structural. Epsilon assigns an Action
    a slot *category*; the player chooses which owned Action fills it.
    LMB is not here at all — Static Pulse is never replaced.
    """
    echo_a: str | None = Field(default=None, max_length=32)
    echo_b: str | None = Field(default=None, max_length=32)
    mobility: str | None = Field(default=None, max_length=32)
    utility: str | None = Field(default=None, max_length=32)

    def assigned(self) -> tuple[tuple[str, str], ...]:
        return tuple(
            (slot, value)
            for slot, value in (
                ("echo_a", self.echo_a), ("echo_b", self.echo_b),
                ("mobility", self.mobility), ("utility", self.utility),
            )
            if value is not None
        )

    def with_slot(self, slot: str, component_id: str | None) -> "SlotAssignment":
        if slot not in ("echo_a", "echo_b", "mobility", "utility"):
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
        _reject_unslottable(self.slots, derive_mechanics(self.interpretations))
        _reject_duplicate_pending(self.pending_checks)
        _reject_unbacked_pending(self.pending_checks, self.zones)
        _reject_underfunded_ledger(self.coins_spent, self.pending_checks)

        if self.active_zone_id and self.active_zone_id not in {
                z.zone_id for z in self.zones}:
            raise ValueError(f"active_zone_id '{self.active_zone_id}' has no record")

        # At most one Zone may hold locations, and active_zone_id must name
        # it. Without this the v0.4 orphan shape - several non-terminal
        # Zones with active_zone_id on one of them - stays representable.
        holding = [z for z in self.zones if z.holds_locations]
        if len(holding) > 1:
            raise ValueError(
                "more than one Zone holds locations: "
                + ", ".join(sorted(z.zone_id for z in holding))
            )
        if holding and self.active_zone_id != holding[0].zone_id:
            raise ValueError(
                f"active_zone_id must name the held Zone '{holding[0].zone_id}'"
            )
        if not holding and self.active_zone_id is not None:
            raise ValueError(
                "active_zone_id must be cleared when no Zone holds locations"
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

    def zone_by_id(self, zone_id: str) -> ZoneRecord | None:
        return next((z for z in self.zones if z.zone_id == zone_id), None)

    def interpretation_by_id(self, echo_id: str) -> EchoInterpretation | None:
        return next(
            (e for e in self.interpretations if e.echo_id == echo_id), None
        )

    def derive(self) -> Mechanics:
        """The live mechanics. Cheap enough to call freely (linear in the
        log, which is at most 30 entries), and deliberately not cached on
        the model: a cached fold is a second source of truth waiting to go
        stale."""
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
    "ZONE_AVAILABLE",    # portal generates a new ordinary Zone
    "FINALE_ONLY",       # finale unlocked and nothing ordinary remains
    "WAITING_FOR_AP",    # nothing eligible; other players hold progression
    "ALL_CHECKS_CLEARED",  # everything done; postgame, nothing left to play
]

#: The only two modes in which a `request_next_zone` intent is legal. Every
#: other mode either already holds a Zone or has nothing to allocate. Both
#: kinds of generation — ordinary and finale — are covered: the finale is
#: requested from FINALE_ONLY, never from GENERATING or a Zone-in-hand mode.
ZONE_REQUEST_MODES = ("ZONE_AVAILABLE", "FINALE_ONLY")

#: Modes in which the campaign already has a Zone and must not start another.
ZONE_HELD_MODES = ("GENERATING", "ZONE_READY", "ZONE_ACTIVE")

#: Modes with something the player can walk into right now. Entering one of
#: these needs no Archipelago round-trip: the Zone already exists locally.
ZONE_ENTERABLE_MODES = ("ZONE_READY", "ZONE_ACTIVE")


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

    #: The two operands of the finale gate, and the two thresholds.
    signal_keys: int = Field(default=0, ge=0)
    finale_progress: int = Field(default=0, ge=0)
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
    epsilon_provider: Literal["claude", "mock", "fallback"]
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
    interpretations: tuple[EchoInterpretation, ...] = ()
    mechanics: Mechanics = Field(default_factory=lambda: Mechanics())
    slots: SlotAssignment = Field(default_factory=lambda: SlotAssignment())
    #: What the player has found that Archipelago does not care about
    #: (§14.2). Mirrored from the save rather than folded: a local reward
    #: derives nothing and grants no mechanic, so it has no business in
    #: `mechanics` — but a note you found stays found, and the client is
    #: what has to stop drawing a pickup it already has.
    local_rewards: tuple[EarnedLocalReward, ...] = ()

    active_zone: ZoneRecord | None = None
    completed_zone_count: int = Field(default=0, ge=0)
    shop: ShopState = Field(default_factory=ShopState)
    pending_checks: tuple[PendingCheck, ...] = ()

    hub: HubStatus
    last_generation_error: str | None = Field(default=None, max_length=C.MAX_TEXT_LEN)

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
        if az is not None and az.state in TERMINAL_ZONE_STATES:
            raise ValueError(
                f"active_zone '{az.zone_id}' is {az.state}; a terminal Zone "
                "reserves nothing and must not be presented as active"
            )

        expected = {
            "PENDING_GENERATION": "GENERATING",
            "GENERATED": "ZONE_READY",
            "ACTIVE": "ZONE_ACTIVE",
        }
        if az is None:
            if self.hub.mode in ZONE_HELD_MODES:
                raise ValueError(
                    f"mode {self.hub.mode} claims a Zone but active_zone is null"
                )
        else:
            want = expected[az.state]
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
        SlotAction, GrantLocalReward, SetCreativity, DebugCommand,
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
    type: Literal["error"]
    scope: Literal["ap", "epsilon", "bridge", "protocol"]
    recoverable: bool
    message: str = Field(max_length=C.MAX_TEXT_LEN)


ServerMessage = Annotated[
    Union[BridgeReady, CampaignSnapshot, ZoneReady, Notification, BridgeError],
    Field(discriminator="type"),
]
