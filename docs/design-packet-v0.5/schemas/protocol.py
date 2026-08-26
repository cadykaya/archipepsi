"""Archipepsi v0.5 — bridge protocol and campaign state.

The bridge owns persistent campaign truth; Godot sends INTENTS and renders
the CAMPAIGN SNAPSHOT it gets back. Python owns allocation, tiers, coins,
shop, pending transactions, the Echo registry, save/reconcile. Godot owns
movement, player HP, living enemies, projectiles, and objective progress in
the current room — none of which survives leaving a Zone.

Every state-changing intent is answered with a fresh full snapshot.
"""

from __future__ import annotations

from typing import Annotated, Literal, Union

from pydantic import BaseModel, ConfigDict, Field, model_validator

try:
    from . import constants as C
    from .echo import Echo
    from .zone import Zone
except ImportError:  # pragma: no cover
    import constants as C
    from echo import Echo
    from zone import Zone

PROTOCOL_VERSION = 5

_ID = Field(min_length=1, max_length=24, pattern=r"^[a-z0-9_]+$")
_LOC = Annotated[int, Field(ge=C.FIRST_LOCATION_ID, le=C.LAST_LOCATION_ID)]
_AP_STR = Annotated[str, Field(max_length=C.MAX_AP_STRING_LEN)]


class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid", validate_assignment=True)


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
    locations permanently. `active_zone_id` is now set at GENERATED, not at
    entry, so the Zone is always visible and always resumable.
    """
    zone_id: str = _ID
    state: ZoneState
    allocated_location_ids: list[_LOC] = Field(
        min_length=1, max_length=C.ZONE_MAX_CHECKS
    )
    target_game: _AP_STR
    is_finale: bool = False
    zone: Zone | None = None          # None only while PENDING_GENERATION
    used_fallback: bool = False
    generation_index: int = Field(ge=0)

    @model_validator(mode="after")
    def _state_implies_content(self):
        if self.state != "PENDING_GENERATION" and self.zone is None:
            raise ValueError(f"state {self.state} requires an accepted zone")
        if len(set(self.allocated_location_ids)) != len(self.allocated_location_ids):
            raise ValueError("duplicate allocated location id")
        if self.is_finale and self.allocated_location_ids != [C.GOAL_LOCATION_ID]:
            raise ValueError(
                f"a finale Zone holds exactly [{C.GOAL_LOCATION_ID}]"
            )
        if not self.is_finale and C.GOAL_LOCATION_ID in self.allocated_location_ids:
            raise ValueError(
                f"{C.GOAL_LOCATION_ID} is reserved for the finale Zone"
            )
        if self.zone is not None:
            if self.zone.zone_id != self.zone_id:
                raise ValueError(
                    f"record '{self.zone_id}' wraps zone '{self.zone.zone_id}'"
                )
            if sorted(self.zone.reward_location_ids) != sorted(
                    self.allocated_location_ids):
                raise ValueError(
                    "the accepted Zone's rewards must be exactly its "
                    "allocated_location_ids"
                )
        return self

    @property
    def holds_locations(self) -> bool:
        """Whether this record still reserves its locations."""
        return self.state not in TERMINAL_ZONE_STATES


class PendingCheck(Strict):
    transaction_id: str = Field(min_length=1, max_length=64)
    location_id: _LOC
    source: Literal["zone", "shop"]
    shop_cost: int = Field(default=0, ge=0)


ShopItemStatus = Literal["available", "pending", "purchased"]


class ShopStockItem(Strict):
    location_id: _LOC
    cost: int = Field(ge=0)
    #: v0.5: without a status the snapshot could not express an in-flight
    #: purchase, so Godot had nothing to disable and a second buy intent
    #: charged again.
    status: ShopItemStatus = "available"
    # Revealed because the player is being asked to pay for it.
    item_name: _AP_STR
    recipient_name: _AP_STR
    recipient_game: _AP_STR


class ShopState(Strict):
    stock: list[ShopStockItem] = Field(
        default_factory=list, max_length=C.SHOP_STOCK_SIZE
    )
    created_after_zone_count: int = Field(default=0, ge=0)

    @model_validator(mode="after")
    def _one_entry_per_location(self):
        ids = [i.location_id for i in self.stock]
        if len(set(ids)) != len(ids):
            raise ValueError("two stock entries for the same location")
        return self


class CampaignSave(Strict):
    """The on-disk campaign. Written atomically (temp, fsync, os.replace).

    Owns generated content and local decisions ONLY. Never persists a second
    copy of AP truth.
    """
    # extra="ignore" here specifically: a save written by a newer build must
    # remain loadable by an older one rather than hard-failing, and the .bak
    # would otherwise inherit the same problem.
    model_config = ConfigDict(extra="ignore", validate_assignment=True)

    save_version: Literal[1] = 1
    schema_version: Literal[5] = 5

    seed_name: str = Field(min_length=1, max_length=128)
    team: int = Field(ge=0)
    slot_id: int = Field(ge=0)
    slot_name: _AP_STR

    epsilon_creativity: Literal[0, 1, 2] = 1

    track_order: list[_AP_STR] = Field(default_factory=list)
    track_cursor: int = Field(default=0, ge=0)
    generation_counter: int = Field(default=0, ge=0)

    #: Monotonic accumulator, incremented at purchase time and already
    #: inclusive of pending purchases. Only the rollback path decrements it.
    coins_spent: int = Field(default=0, ge=0)
    pending_checks: list[PendingCheck] = Field(default_factory=list)

    echoes: dict[str, Echo] = Field(default_factory=dict)
    equipped_echo_id: str | None = None

    zones: dict[str, ZoneRecord] = Field(default_factory=dict)
    active_zone_id: str | None = None
    completed_zone_count: int = Field(default=0, ge=0)
    zone_history: list[str] = Field(default_factory=list)

    shop: ShopState = Field(default_factory=ShopState)
    goal_sent: bool = False

    @model_validator(mode="after")
    def _references_resolve(self):
        if self.active_zone_id and self.active_zone_id not in self.zones:
            raise ValueError(f"active_zone_id '{self.active_zone_id}' has no record")
        if self.equipped_echo_id and self.equipped_echo_id not in self.echoes:
            raise ValueError(f"equipped_echo_id '{self.equipped_echo_id}' not owned")
        seen = [p.location_id for p in self.pending_checks]
        if len(set(seen)) != len(seen):
            raise ValueError("two pending checks for the same location")

        # At most one Zone may hold locations, and active_zone_id must name
        # it. Without this the v0.4 orphan shape - several non-terminal
        # Zones with active_zone_id on one of them - stays representable.
        holding = [z for z in self.zones.values() if z.holds_locations]
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
        return self

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
    "ZONE_READY",        # a Zone is GENERATED but not yet entered
    "ZONE_ACTIVE",       # a Zone is ACTIVE; portal resumes it
    "ZONE_AVAILABLE",    # portal generates a new ordinary Zone
    "FINALE_ONLY",       # finale unlocked and nothing ordinary remains
    "WAITING_FOR_AP",    # nothing eligible; other players hold progression
    "ALL_CHECKS_CLEARED",  # everything done; postgame, nothing left to play
]


class HubStatus(Strict):
    """What the Hub portal may do right now.

    `mode` and `finale_available` are INDEPENDENT. The finale unlocks with
    up to 5 ordinary Checks still outstanding; collapsing both into one enum
    would either hide the finale or strand that content.

    v0.5 removes `CAMPAIGN_COMPLETE`. Sending the Archipelago goal no longer
    ends play — `goal_sent` becomes a banner, and the portal keeps working
    while real AP locations remain. Disabling play on goal would abandon up
    to 5 locations and the other players' items sitting on them.
    """
    mode: HubMode
    headline: str = Field(max_length=C.MAX_TEXT_LEN)
    detail: str = Field(default="", max_length=C.MAX_TEXT_LEN)
    portal_enabled: bool

    goal_sent: bool = False
    postgame: bool = False

    finale_available: bool = False
    holding_finale: bool = False
    finale_progress: int = Field(default=0, ge=0)
    finale_required: int = C.FINALE_REQUIRED_OTHER_CHECKS
    signal_keys_required: int = C.FINALE_REQUIRED_SIGNAL_KEYS

    generation_in_progress: bool = False

    @model_validator(mode="after")
    def _mode_is_consistent(self):
        if self.mode == "FINALE_ONLY" and not self.finale_available:
            raise ValueError("mode FINALE_ONLY requires finale_available=True")
        if self.mode == "WAITING_FOR_AP" and self.finale_available:
            raise ValueError(
                "not waiting on Archipelago if the finale is available; "
                "use FINALE_ONLY"
            )
        # A Zone in hand takes precedence: generating another would orphan
        # it. `holding_finale` exempts the finale Zone itself, which is
        # obviously allowed to be held while available.
        if (self.mode in ("ZONE_READY", "ZONE_ACTIVE")
                and self.finale_available and not self.holding_finale):
            raise ValueError(
                "finish or abandon the current Zone before the finale is "
                "offered; otherwise its unclaimed Checks are stranded"
            )
        if self.postgame and not self.goal_sent:
            raise ValueError("postgame requires goal_sent")

        # v0.4's stranding state was exactly "a playable mode with the portal
        # switched off". Tie them together so it cannot be described.
        playable = self.mode in (
            "ZONE_READY", "ZONE_ACTIVE", "ZONE_AVAILABLE", "FINALE_ONLY")
        if playable != self.portal_enabled:
            raise ValueError(
                f"mode {self.mode} requires portal_enabled="
                f"{str(playable).lower()}"
            )
        if self.mode == "ALL_CHECKS_CLEARED" and not self.goal_sent:
            raise ValueError("every Check cleared implies the goal was sent")
        return self


# ---------------------------------------------------------------------------
# Snapshot
# ---------------------------------------------------------------------------

class CampaignSnapshot(Strict):
    type: Literal["campaign_snapshot"] = "campaign_snapshot"
    protocol_version: Literal[5] = 5

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

    checked_location_ids: list[_LOC] = Field(default_factory=list)
    missing_location_ids: list[_LOC] = Field(default_factory=list)
    scouted: dict[str, ScoutedLocation] = Field(default_factory=dict)

    signal_keys: int = Field(default=0, ge=0)
    unlocked_tier: int = Field(default=0, ge=0)
    coins_received: int = Field(default=0, ge=0)
    coins_spent: int = Field(default=0, ge=0)
    coins_available: int = Field(default=0, ge=0)
    static_received: int = Field(default=0, ge=0)
    static_glitch_units: int = Field(default=0, ge=0)

    echoes: list[Echo] = Field(default_factory=list)
    equipped_echo_id: str | None = None

    active_zone: ZoneRecord | None = None
    completed_zone_count: int = Field(default=0, ge=0)
    shop: ShopState = Field(default_factory=ShopState)
    pending_checks: list[PendingCheck] = Field(default_factory=list)

    hub: HubStatus
    last_generation_error: str | None = Field(default=None, max_length=C.MAX_TEXT_LEN)


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

    `finale` picks between an ordinary Zone and the reserved Check 030 Zone
    when both are offered. The bridge rejects finale=True unless
    HubStatus.finale_available, and rejects either while a Zone is held.
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
    type: Literal["buy_shop_stock"]
    location_id: _LOC


class EquipEcho(Strict):
    type: Literal["equip_echo"]
    echo_id: str | None = Field(default=None, max_length=32)


class SetCreativity(Strict):
    type: Literal["set_creativity"]
    value: Literal[0, 1, 2]


class DebugCommand(Strict):
    type: Literal["debug_command"]
    command: Literal[
        "resync", "print_snapshot", "force_fallback_zone",
        "grant_mock_coin", "grant_mock_signal_key", "clear_campaign",
    ]


ClientMessage = Annotated[
    Union[
        Hello, ApConnect, ApDisconnect, StartMockCampaign, RequestNextZone,
        EnterZone, LeaveZone, ExitZone, AbandonZone, ClaimCheck, BuyShopStock,
        EquipEcho, SetCreativity, DebugCommand,
    ],
    Field(discriminator="type"),
]


# ---------------------------------------------------------------------------
# bridge -> Godot
# ---------------------------------------------------------------------------

class BridgeReady(Strict):
    type: Literal["bridge_ready"]
    protocol_version: Literal[5] = 5
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
    lines: list[Annotated[str, Field(max_length=C.MAX_TEXT_LEN)]] = Field(
        default_factory=list, max_length=12
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
