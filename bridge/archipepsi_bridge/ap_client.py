"""Real Archipelago backend: a `CommonContext` subclass from the pinned
checkout. Never a second AP networking stack.

Import mechanics (TECHNICAL_ARCHITECTURE §4.3): SKIP_REQUIREMENTS_UPDATE is
set BEFORE importing CommonClient — its import runs ModuleUpdate.update(),
which blocks on a bare input() without it. The checkout root goes on
sys.path; importing CommonClient imports the whole `worlds` package, so the
first import takes a few seconds.

`on_package` is a plain def invoked synchronously after the built-in
handling (so `checked_locations` is already current when the hook runs);
async work is scheduled with create_task and the reference is kept.
"""

from __future__ import annotations

import asyncio
import logging
import os
import sys

from .ap_backend import APData, NormalizedItem, ScoutInfo
from .schemas import constants as C

log = logging.getLogger("archipepsi.ap")

_ap_imported = False


def _candidate_ap_roots() -> list[str]:
    if (env := os.environ.get("ARCHIPELAGO_ROOT")):
        return [os.path.abspath(env)]
    here = os.path.dirname(os.path.abspath(__file__))
    return [os.path.abspath(".archipelago"),
            os.path.abspath(os.path.join(here, "..", ".archipelago")),
            os.path.abspath(os.path.join(here, "..", "..", ".archipelago"))]


def ensure_ap_importable() -> None:
    global _ap_imported
    if _ap_imported:
        return
    os.environ["SKIP_REQUIREMENTS_UPDATE"] = "1"   # mandatory, not hygiene
    candidates = _candidate_ap_roots()
    ap_root = next((p for p in candidates
                    if os.path.isfile(os.path.join(p, "CommonClient.py"))),
                   None)
    if ap_root is None:
        raise RuntimeError(
            f"no Archipelago checkout at any of {candidates}; run "
            "`make setup` or set ARCHIPELAGO_ROOT")
    if ap_root not in sys.path:
        sys.path.insert(0, ap_root)
    import CommonClient  # noqa: F401  (slow first import: loads `worlds`)
    _ap_imported = True


ALL_LOCATION_IDS = tuple(range(C.FIRST_LOCATION_ID, C.LAST_LOCATION_ID + 1))


def scout_message() -> dict:
    """The bulk scout packet: all 30, create_as_hint MUST stay 0 — non-zero
    always creates persistent hints, even for already-found locations."""
    return {"cmd": "LocationScouts",
            "locations": list(ALL_LOCATION_IDS),
            "create_as_hint": 0}


def build_context_class(backend: "RealAPBackend", slot_name: str):
    """The `CommonContext` subclass, buildable without a live server so its
    connection configuration is testable."""
    ensure_ap_importable()
    from CommonClient import CommonContext

    class ArchipepsiContext(CommonContext):
        game = "Archipepsi"
        items_handling = 0b111       # remote + own-world + starting inv
        want_slot_data = True
        tags = {"AP"}

        async def server_auth(self, password_requested: bool = False):
            if password_requested and not self.password:
                log.warning("server requires a password and none was given")
            self.auth = slot_name
            await self.send_connect()

        def on_package(self, cmd: str, args: dict):
            # Plain def, called after built-in handling. Schedule async
            # work and keep the task reference (§5).
            backend._spawn(backend._on_package(cmd, args))

        async def connection_closed(self):
            await super().connection_closed()
            backend._on_socket_closed()

        def event_invalid_slot(self):
            backend._spawn(backend._emit_error(
                f"Archipelago refused slot '{slot_name}': invalid slot"))
            super().event_invalid_slot()

        def event_invalid_game(self):
            backend._spawn(backend._emit_error(
                "Archipelago refused the connection: this slot is not an "
                "Archipepsi slot"))
            super().event_invalid_game()

    return ArchipepsiContext


def _scale_from_slot_data(slot_data: dict) -> C.CampaignConfig | None:
    """The campaign scale the seed was generated with, or None.

    None means "this seed predates the options", which is the PROTOTYPE
    campaign -- not the current default. Returning the default here would
    quietly resize somebody's finished 30-location run to 450 the first
    time they reconnected with a newer build.

    A malformed block is also None rather than a guess: an unreadable
    scale is not a licence to invent one.
    """
    block = slot_data.get("campaign_scale")
    if not isinstance(block, dict):
        return None
    try:
        return C.CampaignConfig(
            location_count=int(block["location_count"]),
            zone_target_checks=int(block["zone_target_checks"]),
            zone_budget=int(block["zone_budget"]))
    except (KeyError, TypeError, ValueError) as exc:
        log.warning("slot data carried an unusable campaign_scale (%s); "
                    "treating this seed as a prototype campaign", exc)
        return None


class RealAPBackend:
    mode = "real"

    def __init__(self, engine):
        self.engine = engine
        self.data = APData()
        self.ctx = None
        self._tasks: set[asyncio.Task] = set()
        self._scout_sent = False
        self._refused_race = False

    # -- plumbing ----------------------------------------------------------

    def _spawn(self, coro) -> None:
        task = asyncio.create_task(coro)
        self._tasks.add(task)
        task.add_done_callback(self._tasks.discard)

    async def _emit_error(self, message: str) -> None:
        from .schemas.protocol import BridgeError
        await self.engine._emit(BridgeError(
            type="error", scope="ap", recoverable=True,
            message=message[:C.MAX_TEXT_LEN]))

    # -- APBackend surface -------------------------------------------------

    async def connect(self, server: str, slot_name: str,
                      password: str) -> None:
        ArchipepsiContext = build_context_class(self, slot_name)
        if self.ctx is not None:
            try:
                await self.ctx.shutdown()
            except Exception:
                log.exception("shutting down previous AP context")
        self.ctx = ArchipepsiContext(server, password)
        self._scout_sent = False
        self._refused_race = False
        await self.ctx.connect(server)

    async def disconnect(self) -> None:
        if self.ctx is not None:
            await self.ctx.disconnect(allow_autoreconnect=False)

    async def check_locations(self, location_ids: list[int]) -> set[int]:
        if self.ctx is None or not self.data.connected:
            return set()
        sent = await self.ctx.check_locations(location_ids)
        return set(sent)

    async def send_goal(self) -> None:
        if self.ctx is None or not self.data.connected:
            return
        from NetUtils import ClientStatus
        await self.ctx.send_msgs([{"cmd": "StatusUpdate",
                                   "status": ClientStatus.CLIENT_GOAL}])
        # AP's own reconnect path re-sends the goal only if finished_game is
        # set; a bridge that only tracks its own flag never re-sends.
        self.ctx.finished_game = True

    # -- event handling ----------------------------------------------------

    def _on_socket_closed(self) -> None:
        d = self.data
        was_connected = d.connected
        d.connected = False
        d.synced = False
        d.state_is_current = False
        self._scout_sent = False
        if was_connected:
            log.warning("Archipelago connection lost; last-known state kept")
            self._spawn(self.engine.on_ap_disconnected())

    def _sync_truth_sets(self) -> None:
        ctx = self.ctx
        ours = set(ALL_LOCATION_IDS)
        self.data.checked = set(ctx.checked_locations) & ours
        self.data.missing = set(ctx.missing_locations) & ours

    def _rebuild_received(self) -> None:
        ctx = self.ctx
        items = []
        for ordinal, ni in enumerate(ctx.items_received):
            sender = ni.player
            sender_name = ctx.player_names.get(sender, "Server")
            slot_info = ctx.slot_info.get(sender)
            sender_game = slot_info.game if slot_info else "Archipelago"
            items.append(NormalizedItem(
                ordinal=ordinal, item_id=ni.item,
                item_name=ctx.item_names.lookup_in_game(ni.item),
                sender_player=sender, sender_name=str(sender_name),
                sender_game=str(sender_game), flags=ni.flags))
        self.data.received = items

    def _resolve_scouts(self) -> None:
        ctx = self.ctx
        scouts: dict[int, ScoutInfo] = {}
        for loc in ALL_LOCATION_IDS:
            ni = ctx.locations_info.get(loc)
            if ni is None:
                continue
            recipient = ni.player
            slot_info = ctx.slot_info.get(recipient)
            if slot_info is not None:
                game = slot_info.game
                try:
                    item_name = ctx.item_names.lookup_in_slot(ni.item,
                                                              recipient)
                except Exception:
                    item_name = f"Unknown item {ni.item}"
            else:
                # Recipient game absent from the data package (§4.6).
                game = "Unknown"
                item_name = f"Unknown item {ni.item}"
            scouts[loc] = ScoutInfo(
                location_id=loc, item_id=ni.item, item_name=str(item_name),
                recipient_player=recipient,
                recipient_name=str(ctx.player_names.get(recipient,
                                                        f"Player {recipient}")),
                recipient_game=str(game),
                recipient_is_self=ctx.slot_concerns_self(recipient),
                flags=ni.flags)
        self.data.scouts = scouts

    async def _on_package(self, cmd: str, args: dict) -> None:
        d = self.data
        ctx = self.ctx
        if ctx is None:
            return
        if cmd == "RoomInfo":
            # CommonContext only COMPARES seed_name, it never stores it;
            # capture it ourselves (and hand it to ctx so AP's own
            # different-multiworld guard works on reconnect).
            seed = str(args.get("seed_name", "") or "")
            if seed:
                d.seed_name = seed
                ctx.seed_name = seed
        elif cmd == "Connected":
            d.connected = True
            d.seed_name = str(ctx.seed_name or d.seed_name or "")
            d.team = int(ctx.team or 0)
            d.slot_id = int(ctx.slot or 0)
            d.slot_name = str(ctx.auth or "")
            d.campaign_scale = _scale_from_slot_data(
                getattr(ctx, "slot_data", None) or {})
            self._sync_truth_sets()
            log.info("connected as slot %d '%s' (seed %s); awaiting race-mode "
                     "answer before scouting", d.slot_id, d.slot_name,
                     d.seed_name)
        elif cmd == "Retrieved":
            keys = args.get("keys", {})
            if "_read_race_mode" in keys and not self._scout_sent:
                race = bool(keys["_read_race_mode"])
                d.race_mode = race
                if race:
                    if not self._refused_race:
                        self._refused_race = True
                        log.error("race-mode room; refusing to scout")
                        await self._emit_error(
                            "Archipepsi POC does not support race-mode rooms "
                            "because it scouts its own location placements.")
                        await self.engine.broadcast_snapshot()
                    return
                self._scout_sent = True
                await ctx.send_msgs([scout_message()])
        elif cmd == "LocationInfo":
            self._resolve_scouts()
            if len(self.data.scouts) >= len(ALL_LOCATION_IDS):
                self._rebuild_received()
                self._sync_truth_sets()
                d.synced = True
                d.state_is_current = True
                await self.engine.on_ap_ready()
        elif cmd == "ReceivedItems":
            self._rebuild_received()
            if d.synced:
                await self.engine.on_room_update()
        elif cmd == "RoomUpdate":
            self._sync_truth_sets()
            if "checked_locations" in args or "missing_locations" in args:
                if d.synced:
                    await self.engine.on_room_update()
        elif cmd == "ConnectionRefused":
            errors = args.get("errors", [])
            await self._emit_error(
                "Archipelago refused the connection: "
                + (", ".join(str(e) for e in errors) or "unknown error"))
