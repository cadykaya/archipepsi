"""Mock Archipelago backend built on the canonical fixture.

Simulates connecting, scouting, confirming checks, receiving items and
reconnecting with identical state — no server required. Checks confirm
immediately by default (`confirm_delay=0`); tests raise the delay or edit
`data` directly to exercise the reconcile paths.

Delivery model: our 30 native items exist in the mock multiworld. A few sit
on our own locations (self-recipient); the rest are "found by other
players" — one is delivered from a deterministic queue every time we check
one of our locations, so Signal Keys and Coins flow in at a believable rate.
"""

from __future__ import annotations

import asyncio
import logging

from .ap_backend import APData, NormalizedItem, ScoutInfo
from .schemas import constants as C

log = logging.getLogger("archipepsi.mock_ap")

SELF_SLOT = 1
_PLAYERS = {
    SELF_SLOT: ("Skyiah", "Archipepsi"),
    2: ("BL2Player", "Borderlands 2"),
    3: ("Sage", "Ocarina of Time"),
    4: ("Mario", "Super Mario 64"),
    5: ("Ashen", "Dark Souls III"),
    6: ("Faux", "Bomb Rush Cyberfunk"),
}

_PROG, _USEFUL, _FILLER = C.FLAG_PROGRESSION, C.FLAG_USEFUL, 0

#: The canonical fixture (IMPLEMENTATION_PLAN §3.1), then a deterministic
#: fill. (item_name, recipient_slot, flags); native self items carry their
#: real item ids.
_FIXTURE: dict[int, tuple[str, int, int]] = {
    1: ("Conference Call", 2, _PROG),
    2: ("Hookshot", 3, _PROG),
    3: ("Wing Cap", 4, _USEFUL),
    4: ("Estus Shard", 5, _USEFUL),
    5: ("REP", 6, _FILLER),
    6: ("Epsilon Coin", SELF_SLOT, _FILLER),
}

#: Cycled across the fill locations. The first ten are the original
#: roster and stay where they are; the rest were added so a mock campaign
#: actually EXERCISES the systems S2-S6 built, which is what EPSILON_SPEC
#: §12.2 asks of `--epsilon=mock`.
#:
#: Every name here is one the §15 reader already understands — none was
#: chosen and then taught to the lexicon, which would be bending the
#: reader to fit a fixture. Ten items across thirty locations meant a mock
#: campaign saw nine of the twenty-eight primitives, one of the four link
#: kinds and no Info readout; the reader was never the limit, the roster
#: was.
_FILL_CYCLE = [
    ("Boomerang", 3, _PROG),
    # Metal Cap pairs with the fixture's Wing Cap, and Fresh Rep with its
    # REP: two verb collisions, so a full campaign EVOLVES rather than only
    # accumulating. `integration_driver.gd` counts on both.
    ("Metal Cap", 4, _USEFUL),
    ("Unkempt Harold", 2, _USEFUL),
    ("Fresh Rep", 6, _FILLER),
    ("Bomb Bag", 3, _PROG),
    ("Power Star", 4, _PROG),
    ("Ember", 5, _FILLER),
    # -- held verbs and the bars they burn: the three POWERED_PRIMITIVES
    #    can only ever arrive as a multi-operation shape, which is why the
    #    fallback could never reach them.
    ("Ice Beam", 2, _PROG),
    ("Tower Shield", 4, _USEFUL),
    ("Restoration Wine", 5, _FILLER),
    # -- traversal
    ("Glider Cape", 3, _PROG),
    ("Warp Whistle", 6, _PROG),
    ("Wall Jump Boots", 4, _USEFUL),
    ("Cloud Boots", 2, _FILLER),
    ("Hookshot Chain", 5, _USEFUL),
    # -- close work
    ("Sledge Hammer", 3, _USEFUL),
    ("Spear of Justice", 6, _PROG),
    # -- the two link kinds with no other route into a campaign
    ("Seal of Authority", 5, _PROG),
    ("Momentum Core", 2, _USEFUL),
    # -- the §14.1 readouts, which only an Info component turns on
    ("Revelation Scroll", 3, _FILLER),
    ("Clarity Draught", 6, _FILLER),
]

#: Locations 007–030 that hold OUR native items (self-recipient).
_LOCAL_NATIVES = {
    13: ("Epsilon Static", C.ITEM_ID_EPSILON_STATIC),
    20: ("Epsilon Static", C.ITEM_ID_EPSILON_STATIC),
    27: ("Epsilon Coin", C.ITEM_ID_EPSILON_COIN),
}

_NATIVE_IDS = {
    "Signal Key": C.ITEM_ID_SIGNAL_KEY,
    "Epsilon Coin": C.ITEM_ID_EPSILON_COIN,
    "Epsilon Static": C.ITEM_ID_EPSILON_STATIC,
}


def _build_placements(
        config: C.CampaignConfig = C.PROTOTYPE_CONFIG
) -> dict[int, tuple[str, int, int, int]]:
    """location_id -> (item_name, item_id, recipient_slot, flags).

    Sized by the CAMPAIGN, so a test can run the engine at the shape a
    player will actually be handed. The hand-written fixture covers the
    prototype's first thirty; beyond that the fill cycle carries on, which
    is what a real seed looks like anyway.
    """
    out: dict[int, tuple[str, int, int, int]] = {}
    cycle = 0
    for n in range(1, config.location_count + 1):
        loc = C.LOCATION_ID_BASE + n
        if n in _FIXTURE:
            name, slot, flags = _FIXTURE[n]
            item_id = _NATIVE_IDS.get(name, 77_000_000 + n)
            out[loc] = (name, item_id, slot, flags)
        elif n in _LOCAL_NATIVES:
            name, item_id = _LOCAL_NATIVES[n]
            out[loc] = (name, item_id, SELF_SLOT, _FILLER)
        else:
            name, slot, flags = _FILL_CYCLE[cycle % len(_FILL_CYCLE)]
            cycle += 1
            out[loc] = (name, 77_000_000 + n, slot, flags)
    return out


def _build_delivery_queue(
        config: C.CampaignConfig = C.PROTOTYPE_CONFIG) -> list[int]:
    """Our items in the wider multiworld: at the prototype's thirty that
    is 2 keys, 8 coins, 16 static (2 coins and 2 static sit on our own
    locations). Keys arrive early. Scaled by the campaign's own pool."""
    counts = config.item_counts()
    coins = counts[C.ITEM_NAME_EPSILON_COIN] - 2
    static = counts[C.ITEM_NAME_EPSILON_STATIC] - 2
    head = [C.ITEM_ID_EPSILON_COIN, C.ITEM_ID_EPSILON_STATIC,
            C.ITEM_ID_SIGNAL_KEY, C.ITEM_ID_EPSILON_STATIC,
            C.ITEM_ID_EPSILON_COIN, C.ITEM_ID_EPSILON_STATIC,
            C.ITEM_ID_SIGNAL_KEY, C.ITEM_ID_EPSILON_COIN]
    coins -= 3
    static -= 3
    tail: list[int] = []
    while coins or static:
        for _ in range(2):
            if static:
                tail.append(C.ITEM_ID_EPSILON_STATIC)
                static -= 1
        if coins:
            tail.append(C.ITEM_ID_EPSILON_COIN)
            coins -= 1
    return head + tail


_ITEM_NAMES = {v: k for k, v in _NATIVE_IDS.items()}
_FINDERS = [2, 3, 4, 5, 6]     # who "finds" our queued items, round-robin


class MockServerState:
    """The mock 'server side': truth that survives quit/reload/reconnect.
    Share one instance across backend instances to simulate a persistent
    room."""

    def __init__(self, config: C.CampaignConfig = C.PROTOTYPE_CONFIG):
        self.config = config
        self.checked: set[int] = set()
        self.received: list[NormalizedItem] = []
        self.delivery_queue: list[int] = _build_delivery_queue(config)
        self.delivered = 0
        self.goal_reports = 0


class MockAPBackend:
    mode = "mock"

    def __init__(self, engine, *, confirm_delay: float = 0.0,
                 server_state: MockServerState | None = None,
                 seed_name: str = "MockSeed",
                 config: C.CampaignConfig | None = None):
        self.engine = engine
        self.data = APData()
        #: The scale this "seed" was generated at. A mock pinned to the
        #: prototype means the engine is only ever tested at thirty
        #: locations, which is where an allocator capped at three Checks
        #: per Zone survived the whole redesign unnoticed.
        self.config = config or (server_state.config if server_state
                                 else C.PROTOTYPE_CONFIG)
        self.confirm_delay = confirm_delay
        # The seed is the only input to track order, shop stock and the
        # allocator's shuffles, so a fixed one exercises exactly one path
        # through all three. Parameterised so a soak can walk many.
        self.seed_name = seed_name
        self.placements = _build_placements(self.config)
        self.server = server_state or MockServerState(self.config)
        self._tasks: set[asyncio.Task] = set()

    # -- helpers -----------------------------------------------------------

    def _spawn(self, coro) -> None:
        task = asyncio.create_task(coro)
        self._tasks.add(task)
        task.add_done_callback(self._tasks.discard)

    def _scout_table(self) -> dict[int, ScoutInfo]:
        out = {}
        for loc, (name, item_id, slot, flags) in self.placements.items():
            player_name, game = _PLAYERS[slot]
            out[loc] = ScoutInfo(
                location_id=loc, item_id=item_id, item_name=name,
                recipient_player=slot, recipient_name=player_name,
                recipient_game=game,
                recipient_is_self=(slot == SELF_SLOT), flags=flags)
        return out

    def _deliver(self, item_id: int, sender_slot: int) -> None:
        name, game = _PLAYERS[sender_slot]
        self.server.received.append(NormalizedItem(
            ordinal=len(self.server.received), item_id=item_id,
            item_name=_ITEM_NAMES.get(item_id, f"Unknown item {item_id}"),
            sender_player=sender_slot, sender_name=name, sender_game=game,
            flags=_FILLER))

    def grant_item(self, item_id: int) -> None:
        """Debug grant (mock only): another player finds one of our items."""
        finder = _FINDERS[self.server.delivered % len(_FINDERS)]
        self.server.delivered += 1
        self._deliver(item_id, finder)
        self._sync_from_server()
        self._spawn(self.engine.on_room_update())

    def _sync_from_server(self) -> None:
        d = self.data
        d.checked = set(self.server.checked)
        d.missing = set(self.placements) - self.server.checked
        d.received = list(self.server.received)

    # -- APBackend surface -------------------------------------------------

    async def connect(self, server: str = "", slot_name: str = "Skyiah",
                      password: str = "") -> None:
        d = self.data
        d.connected = True
        d.race_mode = False
        d.seed_name = self.seed_name
        d.team = 0
        d.slot_id = SELF_SLOT
        d.slot_name = slot_name or "Skyiah"
        d.scouts = self._scout_table()
        # A real seed reports its scale in slot data; the mock reports the
        # one it was built with. `None` is the prototype, exactly as a
        # pre-options seed is.
        d.campaign_scale = (None if self.config == C.PROTOTYPE_CONFIG
                            else self.config)
        self._sync_from_server()
        d.synced = True
        d.state_is_current = True
        log.info("mock AP connected: %d locations scouted",
                 self.config.location_count)
        await self.engine.on_ap_ready()

    async def disconnect(self) -> None:
        d = self.data
        d.connected = False
        d.synced = False
        d.state_is_current = False
        await self.engine.on_ap_disconnected()

    def _confirm_one(self, loc: int) -> None:
        if loc in self.server.checked:
            return
        self.server.checked.add(loc)
        _name, item_id, slot, _flags = self.placements[loc]
        if slot == SELF_SLOT:
            self._deliver(item_id, SELF_SLOT)
        if self.server.delivery_queue:
            finder = _FINDERS[self.server.delivered % len(_FINDERS)]
            self.server.delivered += 1
            self._deliver(self.server.delivery_queue.pop(0), finder)

    async def check_locations(self, location_ids: list[int]) -> set[int]:
        sent = {i for i in location_ids
                if i in self.data.missing and i in self.placements}
        if not sent:
            return set()

        async def confirm_later() -> None:
            await asyncio.sleep(self.confirm_delay)
            for loc in sorted(sent):
                self._confirm_one(loc)
            self._sync_from_server()
            await self.engine.on_room_update()

        if self.confirm_delay:
            self._spawn(confirm_later())
        else:
            # Immediate server confirm, synchronous state flip: the caller
            # sees the location in `checked` right after the send, which is
            # exactly the real already-checked fast path.
            for loc in sorted(sent):
                self._confirm_one(loc)
            self._sync_from_server()
            self._spawn(self.engine.on_room_update())
        return sent

    async def send_goal(self) -> None:
        self.server.goal_reports += 1
