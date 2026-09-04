"""Local WebSocket server: Godot is the client, the bridge is authority.

Loopback only. JSON text frames; every message has a `type`; unparseable or
unknown input returns a recoverable `error` and never crashes the bridge.
Every state-changing intent is answered with a fresh full snapshot (the
engine broadcasts after each change).
"""

from __future__ import annotations

import asyncio
import logging

from pydantic import TypeAdapter, ValidationError
from websockets.asyncio.server import serve

from . import BRIDGE_VERSION, transactions
from .campaign import CampaignEngine, IntentError
from .mock_ap import MockAPBackend
from .schemas import constants as C
from .schemas.protocol import BridgeError, BridgeReady, ClientMessage

log = logging.getLogger("archipepsi.server")

_CLIENT_ADAPTER = TypeAdapter(ClientMessage)


class BridgeServer:
    def __init__(self, engine: CampaignEngine, *, ap_default: str = "real",
                 host: str = C.BRIDGE_HOST, port: int = C.BRIDGE_PORT,
                 mock_config: C.CampaignConfig | None = None):
        self.engine = engine
        self.ap_default = ap_default
        #: The scale a MOCK campaign is created at. `None` keeps the
        #: prototype's thirty locations, which is what every existing
        #: caller gets and what MOCK CAMPAIGN has always meant.
        #:
        #: Overridable because the pre-art playtest baseline is taken at
        #: the 450-location default, and a human pressing MOCK CAMPAIGN
        #: would otherwise walk a prototype Zone 1 and compare it to a
        #: baseline Zone 1 that does not exist in their campaign. Real AP
        #: is unaffected: there the seed decides, as it must.
        self.mock_config = mock_config
        # The generated constants stay the default, so nothing that does not
        # ask changes behaviour. Overridable because two Archipepsi slots in
        # one multiworld is a supported way to play, and on one development
        # machine that means two bridges, which cannot both hold 38290.
        self.host = host
        self.port = port
        self.clients: set = set()
        engine.emit = self.broadcast

    async def broadcast(self, message) -> None:
        if not self.clients:
            return
        payload = message.model_dump_json()
        await asyncio.gather(
            *(self._send_raw(ws, payload) for ws in list(self.clients)),
            return_exceptions=True)

    @staticmethod
    async def _send_raw(ws, payload: str) -> None:
        try:
            await ws.send(payload)
        except Exception:
            pass  # a dying client is handled by its own handler

    async def _send(self, ws, message) -> None:
        await self._send_raw(ws, message.model_dump_json())

    # ------------------------------------------------------------------

    async def handler(self, ws) -> None:
        self.clients.add(ws)
        log.info("client connected (%d total)", len(self.clients))
        try:
            await self._send(ws, BridgeReady(type="bridge_ready",
                                             bridge_version=BRIDGE_VERSION))
            # `engine.snapshot()` is always COMPLETE; only
            # `broadcast_snapshot()` elides the Echo log. That is the whole
            # correctness argument for eliding it: no client is ever joined
            # to the broadcast stream without a full log to cache first.
            await self._send(ws, self.engine.snapshot())
            async for raw in ws:
                await self.dispatch(ws, raw)
        except Exception:
            log.exception("client handler ended")
        finally:
            self.clients.discard(ws)
            log.info("client disconnected (%d left)", len(self.clients))

    async def dispatch(self, ws, raw) -> None:
        try:
            message = _CLIENT_ADAPTER.validate_json(raw)
        except ValidationError as exc:
            await self._send(ws, BridgeError(
                type="error", scope="protocol", recoverable=True,
                message=f"malformed message: {exc.errors()[0]['msg']}"
                [:C.MAX_TEXT_LEN]))
            return
        try:
            await self._route(ws, message)
        except IntentError as exc:
            await self._send(ws, BridgeError(
                type="error", scope=exc.scope, recoverable=True,
                message=str(exc)[:C.MAX_TEXT_LEN]))
        except Exception as exc:
            log.exception("intent %s failed", message.type)
            await self._send(ws, BridgeError(
                type="error", scope="bridge", recoverable=True,
                message=f"{type(exc).__name__}: {exc}"[:C.MAX_TEXT_LEN]))

    async def _route(self, ws, m) -> None:
        engine = self.engine
        if m.type == "hello":
            # Complete, as on connect: `hello` is how a client that lost
            # track of the Echo log asks for all of it again.
            await self._send(ws, engine.snapshot())
        elif m.type == "ap_connect":
            await self._connect_ap(m.server, m.slot_name, m.password)
        elif m.type == "ap_disconnect":
            if engine.backend is not None:
                await engine.backend.disconnect()
            await engine.broadcast_snapshot()
        elif m.type == "start_mock_campaign":
            await self._connect_mock()
        elif m.type == "request_next_zone":
            await engine.handle_request_next_zone(m.finale)
        elif m.type == "enter_zone":
            await engine.handle_enter_zone(m.zone_id)
        elif m.type == "leave_zone":
            await engine.handle_leave_zone(m.zone_id)
        elif m.type == "exit_zone":
            await engine.handle_exit_zone(m.zone_id)
        elif m.type == "abandon_zone":
            await engine.handle_abandon_zone(m.zone_id)
        elif m.type == "claim_check":
            await transactions.claim_check(engine, m.zone_id, m.location_id)
        elif m.type == "buy_shop_stock":
            await transactions.buy_shop_stock(engine, m.location_id)
        elif m.type == "slot_action":
            await engine.handle_slot_action(m.slot, m.component_id)
        elif m.type == "grant_local_reward":
            await engine.handle_grant_local_reward(m)
        elif m.type == "zone_timing":
            engine.record_zone_timing(m)
        elif m.type == "set_creativity":
            await engine.handle_set_creativity(m.value)
        elif m.type == "debug_command":
            await engine.handle_debug(m.command)
        else:  # unreachable: the adapter is a closed union
            raise IntentError(f"unknown intent '{m.type}'", scope="protocol")

    async def _connect_mock(self) -> None:
        """Reuse a live mock backend (its server truth must survive
        reconnects); disconnect any real backend so its events stop."""
        engine = self.engine
        if engine.backend is not None and engine.backend.mode != "mock":
            await engine.backend.disconnect()
            engine.backend = None
        if engine.backend is None:
            engine.backend = MockAPBackend(engine, config=self.mock_config)
        await engine.backend.connect("", "Skyiah", "")

    async def _connect_ap(self, server: str, slot_name: str,
                          password: str) -> None:
        engine = self.engine
        if self.ap_default == "mock":
            await self._connect_mock()
            return
        from .ap_client import RealAPBackend
        if engine.backend is not None and engine.backend.mode != "real":
            await engine.backend.disconnect()
            engine.backend = None
        if engine.backend is None:
            engine.backend = RealAPBackend(engine)
        await engine.backend.connect(server, slot_name, password)

    # ------------------------------------------------------------------

    async def serve_forever(self) -> None:
        async with serve(self.handler, self.host, self.port):
            log.info("bridge listening on ws://%s:%d", self.host, self.port)
            await asyncio.Future()
