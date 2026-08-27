"""Archipepsi v0.4 — bridge protocol and campaign state.

v0.4 moves the campaign brain into Python (decision D2). That changes the
protocol's shape, not just its contents:

    v0.3   Godot owned campaign state; the bridge relayed AP packets.
    v0.4   The bridge owns campaign state; Godot sends INTENTS and renders
           the CAMPAIGN SNAPSHOT it gets back.

The division is "persistent campaign truth" vs "this frame of the
videogame". Python owns allocation, tiers, coins, shop, pending
transactions, Echo registry, save/reconcile. Godot owns movement, player
HP, living enemies, projectiles, objective progress in the current room —
none of which survives leaving a Zone anyway.

Every state-changing intent is answered by a fresh full snapshot. With 30
locations, a delta protocol would be complexity for nothing.
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

PROTOCOL_VERSION = 4


class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid")


# ---------------------------------------------------------------------------
# Campaign state (authoritative, lives in Python, persisted to disk)
# ---------------------------------------------------------------------------

ZoneState = Literal["PENDING_GENERATION", "GENERATED", "ACTIVE", "COMPLETE"]


class ZoneRecord(Strict):
    """A Zone across its whole lifecycle.

    v0.3 said "save the chosen location IDs before calling Epsilon" but had
    nowhere to put them, so a crash mid-generation was unrepresentable and
    the shop could re-sell locations already committed to a Zone that had
    not been saved yet. `allocated_location_ids` is populated at
    PENDING_GENERATION, before the provider is called.
    """
    zone_id: str
    state: ZoneState
    allocated_location_ids: list[int] = Field(min_length=1, max_length=3)
    target_game: str
    is_finale: bool = False
    zone: Zone | None = None          # None while PENDING_GENERATION
    used_fallback: bool = False
    generation_index: int


class PendingCheck(Strict):
    transaction_id: str
    location_id: int
    source: Literal["zone", "shop"]
    shop_cost: int = 0


class ShopStockItem(Strict):
    location_id: int
    cost: int
    # Revealed because the player is being asked to pay for it.
    item_name: str
    recipient_name: str
    recipient_game: str


class ShopState(Strict):
    stock: list[ShopStockItem] = Field(default_factory=list, max_length=2)
    created_after_zone_count: int = 0


class CampaignSave(Strict):
    """The on-disk campaign. Written atomically (temp file + os.replace).

    Owns generated content and local decisions ONLY. Never persists a second
    copy of AP truth: checked locations, missing locations and delivered
    items are re-read from the server every connection.
    """
    save_version: Literal[1] = 1
    schema_version: Literal[4] = 4

    seed_name: str
    team: int
    slot_id: int
    slot_name: str

    epsilon_creativity: Literal[0, 1, 2] = 1

    track_order: list[str] = Field(default_factory=list)
    track_cursor: int = 0
    generation_counter: int = 0

    coins_spent: int = 0
    pending_checks: list[PendingCheck] = Field(default_factory=list)

    echoes: dict[str, Echo] = Field(default_factory=dict)
    equipped_echo_id: str | None = None

    zones: dict[str, ZoneRecord] = Field(default_factory=dict)
    active_zone_id: str | None = None
    completed_zone_count: int = 0
    zone_history: list[str] = Field(default_factory=list)

    shop: ShopState = Field(default_factory=ShopState)
    goal_sent: bool = False

    @property
    def campaign_key(self) -> str:
        import hashlib
        raw = f"{self.seed_name}|{self.team}|{self.slot_id}"
        return hashlib.sha256(raw.encode("utf-8")).hexdigest()[:16]


# ---------------------------------------------------------------------------
# Normalized AP state
# ---------------------------------------------------------------------------

class ScoutedLocation(Strict):
    location_id: int
    location_name: str
    item_id: int
    item_name: str
    recipient_player: int
    recipient_name: str
    recipient_game: str
    flags: int


class ReceivedItem(Strict):
    ordinal: int          # position in the reconstructed list, not a wire field
    item_id: int
    item_name: str
    sender_player: int
    sender_name: str
    sender_game: str
    flags: int


# ---------------------------------------------------------------------------
# Hub state — what the portal is allowed to do right now
# ---------------------------------------------------------------------------

HubMode = Literal[
    "NO_CAMPAIGN",        # not connected / no save
    "ZONE_ACTIVE",        # a Zone is ACTIVE; portal resumes it
    "ZONE_AVAILABLE",     # portal generates a new normal Zone
    "FINALE_ONLY",        # nothing left but the finale
    "WAITING_FOR_AP",     # nothing eligible; other players hold your progression
    "CAMPAIGN_COMPLETE",  # goal sent
]


class HubStatus(Strict):
    """What the Hub portal may do right now.

    `mode` and `finale_available` are deliberately INDEPENDENT. Once the
    finale unlocks at 24 of 29 Checks there are still up to 5 ordinary
    Checks left, and collapsing both into one enum value would either hide
    the finale or strand that content permanently. The Hub offers whichever
    of the two are true, and the player chooses.

    `FINALE_ONLY` is the case where no ordinary Check remains.
    """
    mode: HubMode
    headline: str
    detail: str = ""
    portal_enabled: bool

    finale_available: bool = False
    finale_progress: int = 0          # non-goal checks confirmed
    finale_required: int = C.FINALE_REQUIRED_OTHER_CHECKS
    pepsi_keys_required: int = C.FINALE_REQUIRED_PEPSI_KEYS

    @model_validator(mode="after")
    def _finale_only_implies_available(self):
        if self.mode == "FINALE_ONLY" and not self.finale_available:
            raise ValueError("mode FINALE_ONLY requires finale_available=True")
        if self.mode == "WAITING_FOR_AP" and self.finale_available:
            raise ValueError(
                "not waiting on Archipelago if the finale is available; "
                "use FINALE_ONLY"
            )
        return self


# ---------------------------------------------------------------------------
# The snapshot Godot renders
# ---------------------------------------------------------------------------

class CampaignSnapshot(Strict):
    type: Literal["campaign_snapshot"] = "campaign_snapshot"
    protocol_version: Literal[4] = 4

    bridge_connected: bool
    ap_connected: bool
    ap_mode: Literal["real", "mock"]
    epsilon_provider: Literal["claude", "mock", "fallback"]
    race_mode: bool = False

    seed_name: str = ""
    slot_name: str = ""
    slot_id: int = 0
    team: int = 0

    checked_location_ids: list[int] = Field(default_factory=list)
    missing_location_ids: list[int] = Field(default_factory=list)
    scouted: dict[str, ScoutedLocation] = Field(default_factory=dict)

    pepsi_keys: int = 0
    unlocked_tier: int = 0
    coins_received: int = 0
    coins_spent: int = 0
    coins_available: int = 0
    static_received: int = 0
    static_glitch_units: int = 0

    echoes: list[Echo] = Field(default_factory=list)
    equipped_echo_id: str | None = None

    active_zone: ZoneRecord | None = None
    completed_zone_count: int = 0
    shop: ShopState = Field(default_factory=ShopState)
    pending_checks: list[PendingCheck] = Field(default_factory=list)

    hub: HubStatus
    last_generation_error: str | None = None


# ---------------------------------------------------------------------------
# Godot -> bridge intents
# ---------------------------------------------------------------------------

class Hello(Strict):
    type: Literal["hello"]
    client_version: str


class ApConnect(Strict):
    type: Literal["ap_connect"]
    server: str
    slot_name: str
    password: str = ""


class ApDisconnect(Strict):
    type: Literal["ap_disconnect"]


class StartMockCampaign(Strict):
    type: Literal["start_mock_campaign"]


class RequestNextZone(Strict):
    """Generate the next Zone.

    `finale` picks between an ordinary Zone and the reserved Check 030 Zone
    when both are offered. The bridge rejects finale=True unless
    HubStatus.finale_available.
    """
    type: Literal["request_next_zone"]
    finale: bool = False


class ResumeZone(Strict):
    type: Literal["resume_zone"]


class ClaimCheck(Strict):
    """Sent when the player interacts with an unlocked reward object.

    The bridge re-verifies that the chamber's objective was actually
    satisfiable and that the location belongs to the active Zone. Godot
    reporting objective completion is a claim, not an authority.
    """
    type: Literal["claim_check"]
    zone_id: str
    location_id: int


class BuyShopStock(Strict):
    type: Literal["buy_shop_stock"]
    location_id: int


class EquipEcho(Strict):
    type: Literal["equip_echo"]
    echo_id: str | None


class SetCreativity(Strict):
    type: Literal["set_creativity"]
    value: Literal[0, 1, 2]


class LeaveZone(Strict):
    """Pause-menu Return to Hub. Zone stays ACTIVE; transient state resets."""
    type: Literal["leave_zone"]


class ExitZone(Strict):
    """Exit portal. Valid only when every assigned Check is confirmed."""
    type: Literal["exit_zone"]
    zone_id: str


class DebugCommand(Strict):
    type: Literal["debug_command"]
    command: Literal[
        "resync", "print_snapshot", "force_fallback_zone",
        "grant_mock_coin", "grant_mock_pepsi_key", "clear_campaign",
    ]


ClientMessage = Annotated[
    Union[
        Hello, ApConnect, ApDisconnect, StartMockCampaign, RequestNextZone,
        ResumeZone, ClaimCheck, BuyShopStock, EquipEcho, SetCreativity,
        LeaveZone, ExitZone, DebugCommand,
    ],
    Field(discriminator="type"),
]


# ---------------------------------------------------------------------------
# bridge -> Godot
# ---------------------------------------------------------------------------

class BridgeReady(Strict):
    type: Literal["bridge_ready"]
    protocol_version: Literal[4] = 4
    bridge_version: str


class ZoneReady(Strict):
    type: Literal["zone_ready"]
    zone: Zone
    used_fallback: bool


NotificationKind = Literal[
    "check_confirmed", "echo_acquired", "coin_received", "pepsi_key_received",
    "static_received", "shop_purchased", "fallback_used", "goal_reached",
    "ap_offline", "sync_warning",
]


class Notification(Strict):
    """One-shot UI event. Never state: the snapshot is state."""
    type: Literal["notification"] = "notification"
    kind: NotificationKind
    title: str
    lines: list[str] = Field(default_factory=list, max_length=6)
    echo_id: str | None = None


class BridgeError(Strict):
    type: Literal["error"]
    scope: Literal["ap", "epsilon", "bridge", "protocol"]
    recoverable: bool
    message: str


ServerMessage = Annotated[
    Union[BridgeReady, CampaignSnapshot, ZoneReady, Notification, BridgeError],
    Field(discriminator="type"),
]
