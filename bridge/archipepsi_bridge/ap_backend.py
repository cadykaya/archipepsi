"""The engine's view of Archipelago, real or mock.

The engine never touches `CommonContext` directly; it reads this normalized
state and calls the small async surface below. `RealAPBackend`
(`ap_client.py`) fills it from the pinned checkout's `CommonContext`;
`MockAPBackend` (`mock_ap.py`) fills it from the canonical fixture.

`APData` retains last-known values across disconnects on purpose:
`CommonContext.reset_server_state()` clears `items_received` and
`locations_info`, so a raw recount mid-outage reads zero for everything.
The bridge keeps the last normalized copy in memory — never on disk — and
flags `state_is_current=False` instead of regressing to zeros.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Protocol

from .schemas import constants as C


@dataclass
class ScoutInfo:
    """One scouted location, resolved in recipient-game context."""
    location_id: int
    item_id: int
    item_name: str
    recipient_player: int
    recipient_name: str
    recipient_game: str
    recipient_is_self: bool
    flags: int

    @property
    def track_key(self) -> str:
        # Self-recipient locations belong to the "Archipepsi" Track;
        # "Archipepsi / Glitch Track" is display text only.
        return self.recipient_game


@dataclass
class NormalizedItem:
    """One received item from the reconstructed authoritative list."""
    ordinal: int
    item_id: int
    item_name: str
    sender_player: int
    sender_name: str
    sender_game: str
    flags: int


@dataclass
class APData:
    """Last-known normalized Archipelago state. Never persisted."""
    connected: bool = False          # live socket, slot authenticated
    synced: bool = False             # post-Connected scout+items complete
    state_is_current: bool = False   # False during an outage; values retained
    race_mode: bool = False

    seed_name: str = ""
    team: int = 0
    slot_id: int = 0
    slot_name: str = ""

    checked: set[int] = field(default_factory=set)
    missing: set[int] = field(default_factory=set)
    scouts: dict[int, ScoutInfo] = field(default_factory=dict)
    received: list[NormalizedItem] = field(default_factory=list)

    # Recounted from `received` on every update; retained across outages.
    signal_keys: int = 0
    coins_received: int = 0
    static_received: int = 0

    def recount(self) -> None:
        by_id = {C.ITEM_ID_SIGNAL_KEY: 0, C.ITEM_ID_EPSILON_COIN: 0,
                 C.ITEM_ID_EPSILON_STATIC: 0}
        for item in self.received:
            if item.item_id in by_id:
                by_id[item.item_id] += 1
        self.signal_keys = by_id[C.ITEM_ID_SIGNAL_KEY]
        self.coins_received = by_id[C.ITEM_ID_EPSILON_COIN]
        self.static_received = by_id[C.ITEM_ID_EPSILON_STATIC]


class APBackend(Protocol):
    """The async surface the engine drives."""

    mode: str            # "real" | "mock"
    data: APData

    async def connect(self, server: str, slot_name: str, password: str) -> None: ...

    async def disconnect(self) -> None: ...

    async def check_locations(self, location_ids: list[int]) -> set[int]:
        """Send LocationChecks. Returns the set actually sent — empty when
        every id was filtered (already checked, or not this slot's)."""
        ...

    async def send_goal(self) -> None:
        """StatusUpdate CLIENT_GOAL. Idempotent; also sets finished_game."""
        ...
