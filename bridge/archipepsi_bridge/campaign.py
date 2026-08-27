"""THE BRAIN: allocation, tiers, finale, shop, coins, snapshot.

All persistent change goes through `schemas/transitions.py` (plus the
bridge-local `set_creativity` below, which follows the same
rebuild-and-validate shape). The engine holds exactly one `CampaignSave`
value object and replaces it atomically; every replacement is persisted
before any network send that depends on it.
"""

from __future__ import annotations

import asyncio
import logging
import uuid
from collections import defaultdict
from pathlib import Path

from .ap_backend import APBackend, APData, ScoutInfo
from .epsilon import (
    CampaignContext, EchoGenerationRequest, EchoSummary, PlayerContext,
    RequestLocation, ZoneGenerationRequest, ZoneSummary,
    generate_echo_validated, generate_zone_validated,
)
from .epsilon.requests import EchoPlayerState, EchoSource
from .schemas import constants as C
from .schemas import transitions as T
from .schemas.protocol import (
    CampaignSave, CampaignSnapshot, HubStatus, Notification, ScoutedLocation,
    ShopState, ZoneReady, ZoneRecord,
)
from . import store

log = logging.getLogger("archipepsi.campaign")

MAX_LAZY_ECHOES_PER_LOAD = 3


class IntentError(Exception):
    """A refused intent. Answered with a recoverable `error`, never a crash."""

    def __init__(self, message: str, scope: str = "bridge"):
        super().__init__(message)
        self.scope = scope


def set_creativity(save: CampaignSave, value: int) -> CampaignSave:
    """Bridge-local transition, same shape as `schemas/transitions.py`:
    build the complete next save and validate in one step."""
    return CampaignSave(**{**save.model_dump(), "epsilon_creativity": value})


def _clamp_ap_string(text: str) -> str:
    """AP-sourced strings are untrusted: clamp and strip control chars."""
    cleaned = "".join(ch for ch in text if ch.isprintable())
    return cleaned[:C.MAX_AP_STRING_LEN] or "?"


class CampaignEngine:
    def __init__(self, *, provider, provider_name: str,
                 save_dir: Path | None = None,
                 archive_dir: Path | None = None):
        self.provider = provider
        self.provider_name = provider_name
        self.save_dir = save_dir or store.DEFAULT_SAVE_DIR
        self.archive_dir = archive_dir

        self.backend: APBackend | None = None
        self.save: CampaignSave | None = None
        self.last_generation_error: str | None = None
        self.force_fallback_once = False

        #: async callback set by the server; broadcasts one ServerMessage.
        self.emit = None

        self._save_path: Path | None = None
        self._lazy_echo_budget = MAX_LAZY_ECHOES_PER_LOAD
        self._echo_lock = asyncio.Lock()
        self._items_synced_once = False
        self._low_coin_warned = False
        self._reconcile_tasks: set[asyncio.Task] = set()
        self._generation_task: asyncio.Task | None = None

    # ------------------------------------------------------------------
    # Plumbing
    # ------------------------------------------------------------------

    @property
    def ap(self) -> APData:
        return self.backend.data if self.backend else APData()

    def _apply(self, new_save: CampaignSave) -> None:
        """Replace the campaign and persist atomically. The only write path."""
        self.save = new_save
        if self._save_path is not None:
            store.write_save(self._save_path, new_save)

    async def _emit(self, message) -> None:
        if self.emit is not None:
            await self.emit(message)

    async def broadcast_snapshot(self) -> None:
        await self._emit(self.snapshot())

    async def _notify(self, kind: str, title: str, lines=(),
                      location_id=None, echo_id=None) -> None:
        await self._emit(Notification(
            kind=kind, title=title[:C.MAX_TEXT_LEN],
            lines=tuple(str(l)[:C.MAX_TEXT_LEN] for l in lines)[:12],
            location_id=location_id, echo_id=echo_id))

    # ------------------------------------------------------------------
    # Eligibility and allocation
    # ------------------------------------------------------------------

    def _held_location_ids(self) -> set[int]:
        if self.save is None:
            return set()
        return {i for z in self.save.zones if z.holds_locations
                for i in z.allocated_location_ids}

    def _pending_location_ids(self) -> set[int]:
        if self.save is None:
            return set()
        return {p.location_id for p in self.save.pending_checks}

    def _stocked_location_ids(self) -> set[int]:
        if self.save is None:
            return set()
        return {i.location_id for i in self.save.shop.stock}

    def zone_candidates(self, *, ignore_stock: bool = False) -> set[int]:
        """§10.4: the ordinary-Zone candidate pool. Starts from
        `eligible_location_ids()` — the goal-free function — always."""
        pool = set(C.eligible_location_ids(self.ap.signal_keys))
        pool &= self.ap.missing
        pool -= self._held_location_ids()
        pool -= self._pending_location_ids()
        if not ignore_stock:
            pool -= self._stocked_location_ids()
        return pool

    def shop_candidates(self) -> set[int]:
        """§11.3: same source as the Zone allocator, minus self-recipient."""
        pool = self.zone_candidates()
        return {i for i in pool
                if (s := self.ap.scouts.get(i)) and not s.recipient_is_self}

    def _select_zone_locations(self) -> tuple[list[int], str]:
        """§10.5 steps 1–8. Never advances the cursor."""
        save = self.save
        pool = self.zone_candidates()
        if not pool:
            raise IntentError("nothing is eligible to allocate")

        by_track: dict[str, list[int]] = defaultdict(list)
        for loc in sorted(pool):
            scout = self.ap.scouts.get(loc)
            key = scout.track_key if scout else "Unknown"
            by_track[key].append(loc)

        order = list(save.track_order) or sorted(by_track)
        n = len(order)
        start = save.track_cursor % n
        scan = [order[(start + i) % n] for i in range(n)]
        target = next((t for t in scan if by_track.get(t)), None)
        if target is None:                       # scouts missing a track name
            target = sorted(by_track)[0]

        def shuffled(track: str) -> list[int]:
            return C.deterministic_shuffle(
                sorted(by_track.get(track, [])),
                *C.zone_selection_seed(save.seed_name, save.team,
                                       save.slot_id, save.generation_counter,
                                       track))

        picked = shuffled(target)[:C.ZONE_MAX_CHECKS]
        if len(picked) < C.ZONE_MIN_CHECKS:
            for track in scan:
                if track == target:
                    continue
                for loc in shuffled(track):
                    if loc not in picked:
                        picked.append(loc)
                    if len(picked) >= C.ZONE_MIN_CHECKS:
                        break
                if len(picked) >= C.ZONE_MIN_CHECKS:
                    break
        if len(picked) == 1 and len(pool) > 1:
            raise IntentError(
                "allocator bug: a 1-Check Zone with more eligible remaining")
        return picked, target

    # ------------------------------------------------------------------
    # Hub status and snapshot
    # ------------------------------------------------------------------

    def _finale_progress(self) -> int:
        return len(self.ap.checked
                   & set(range(C.FIRST_NON_FINALE_LOCATION_ID,
                               C.LAST_NON_FINALE_LOCATION_ID + 1)))

    def hub_status(self) -> HubStatus:
        ap = self.ap
        keys = ap.signal_keys
        progress = self._finale_progress()
        base = dict(ap_online=ap.connected and ap.synced,
                    goal_sent=bool(self.save and self.save.goal_sent),
                    postgame=bool(self.save and self.save.goal_sent),
                    signal_keys=keys, finale_progress=progress)

        if self.save is None:
            return HubStatus(mode="NO_CAMPAIGN", headline="NOT CONNECTED",
                             detail="Connect to Archipelago or start a mock campaign.",
                             ap_online=base["ap_online"], signal_keys=keys,
                             finale_progress=progress)

        az = self.save.active_zone
        if az is not None:
            mode = {"PENDING_GENERATION": "GENERATING",
                    "GENERATED": "ZONE_READY",
                    "ACTIVE": "ZONE_ACTIVE"}[az.state]
            headline, detail = {
                "GENERATING": ("EPSILON IS DESIGNING",
                               "A Zone is being generated. Hold."),
                "ZONE_READY": ("ZONE READY",
                               az.zone.display_name if az.zone else ""),
                "ZONE_ACTIVE": ("ZONE IN PROGRESS",
                                "Step back through the portal to resume."),
            }[mode]
            return HubStatus(mode=mode, headline=headline, detail=detail,
                             holding_finale=az.is_finale, **base)

        finale_unlocked = (progress >= C.FINALE_REQUIRED_OTHER_CHECKS
                          and keys >= C.FINALE_REQUIRED_SIGNAL_KEYS)
        goal_missing = C.GOAL_LOCATION_ID in ap.missing
        all_checked = len(ap.checked) >= C.LOCATION_COUNT

        if all_checked:
            return HubStatus(mode="ALL_CHECKS_CLEARED",
                             headline="ALL CHECKS CLEARED",
                             detail="Every transmission delivered. Thanks for playing.",
                             **base)

        offline_detail = ("ARCHIPELAGO OFFLINE — RECONNECT TO GENERATE"
                          if not base["ap_online"] else "")
        if self.zone_candidates():
            return HubStatus(mode="ZONE_AVAILABLE", headline="PORTAL READY",
                             detail=offline_detail or
                             "Epsilon is waiting to design your next Zone.",
                             **base)
        if finale_unlocked:
            detail = offline_detail or (
                "Nothing ordinary remains. The last transmission waits."
                if goal_missing else "The signal is settling.")
            return HubStatus(mode="FINALE_ONLY", headline="THE FINALE AWAITS",
                             detail=detail, **base)
        return HubStatus(
            mode="WAITING_FOR_AP", headline="WAITING FOR ARCHIPELAGO",
            detail="Your next progression is somewhere in the multiworld.",
            **base)

    def _scouted_for_snapshot(self) -> tuple[ScoutedLocation, ...]:
        out = []
        stocked = self._stocked_location_ids()
        for loc in sorted(self.ap.scouts):
            s = self.ap.scouts[loc]
            revealed = loc in self.ap.checked or loc in stocked
            name = f"Archipepsi Check {loc - C.LOCATION_ID_BASE:03d}"
            if revealed:
                out.append(ScoutedLocation(
                    location_id=loc, location_name=name, revealed=True,
                    recipient_is_self=s.recipient_is_self,
                    item_id=s.item_id,
                    item_name=_clamp_ap_string(s.item_name),
                    recipient_player=s.recipient_player,
                    recipient_name=_clamp_ap_string(s.recipient_name),
                    recipient_game=_clamp_ap_string(s.recipient_game),
                    flags=s.flags))
            else:
                out.append(ScoutedLocation(
                    location_id=loc, location_name=name, revealed=False,
                    recipient_is_self=s.recipient_is_self,
                    recipient_game=_clamp_ap_string(s.recipient_game)))
        return tuple(out)

    def snapshot(self) -> CampaignSnapshot:
        ap = self.ap
        save = self.save
        return CampaignSnapshot(
            bridge_connected=True,
            ap_connected=ap.connected,
            ap_mode=self.backend.mode if self.backend else "real",
            epsilon_provider=self.provider_name,
            race_mode=ap.race_mode,
            ap_state_is_current=ap.state_is_current,
            seed_name=ap.seed_name or (save.seed_name if save else ""),
            slot_name=_clamp_ap_string(ap.slot_name) if ap.slot_name
            else (save.slot_name if save else ""),
            slot_id=ap.slot_id or (save.slot_id if save else 0),
            team=ap.team or (save.team if save else 0),
            checked_location_ids=tuple(sorted(ap.checked)),
            missing_location_ids=tuple(sorted(ap.missing)),
            scouted=self._scouted_for_snapshot(),
            signal_keys=ap.signal_keys,
            unlocked_tier=min(ap.signal_keys, C.TIER_COUNT - 1),
            coins_received=ap.coins_received,
            coins_spent=save.coins_spent if save else 0,
            static_received=ap.static_received,
            static_glitch_units=ap.static_received
            * C.STATIC_GLITCH_UNITS_PER_ITEM,
            echoes=save.echoes if save else (),
            equipped_echo_id=save.equipped_echo_id if save else None,
            active_zone=save.active_zone if save else None,
            completed_zone_count=save.completed_zone_count if save else 0,
            shop=save.shop if save else ShopState(),
            pending_checks=save.pending_checks if save else (),
            hub=self.hub_status(),
            last_generation_error=self.last_generation_error,
        )

    # ------------------------------------------------------------------
    # Campaign lifecycle
    # ------------------------------------------------------------------

    async def on_ap_ready(self) -> None:
        """Connected, race-checked, scouted. Load or create the campaign."""
        ap = self.ap
        if self.save is not None and (
                self.save.seed_name != ap.seed_name
                or self.save.team != ap.team
                or self.save.slot_id != ap.slot_id):
            log.info("connected to a different run; switching campaigns")
            self.save = None
            self._items_synced_once = False
            self._lazy_echo_budget = MAX_LAZY_ECHOES_PER_LOAD
        self._save_path = store.save_path(
            self.save_dir, ap.seed_name, ap.team, ap.slot_id, ap.slot_name)
        existing = store.load_save(self._save_path)
        if existing is not None and (
                existing.seed_name != ap.seed_name
                or existing.team != ap.team
                or existing.slot_id != ap.slot_id):
            log.error("save identity mismatch at %s; starting fresh",
                      self._save_path)
            existing = None

        if existing is None and self.save is None:
            games = sorted({s.track_key for s in ap.scouts.values()})
            order = C.deterministic_shuffle(
                games, *C.track_order_seed(ap.seed_name, ap.team, ap.slot_id))
            fresh = CampaignSave(
                seed_name=ap.seed_name, team=ap.team, slot_id=ap.slot_id,
                slot_name=_clamp_ap_string(ap.slot_name),
                track_order=tuple(order))
            self._apply(fresh)
            log.info("created campaign %s (track order: %s)",
                     self._save_path.name, " → ".join(order))
        elif self.save is None:
            self.save = existing
            log.info("loaded campaign %s", self._save_path.name)

        self._low_coin_warned = False
        await self.on_items_updated(notify=False)
        await self.reconcile()

        if self.save.goal_sent:
            await self.backend.send_goal()

        # A Zone interrupted mid-generation re-runs against its committed ids.
        az = self.save.active_zone
        if az is not None and az.state == "PENDING_GENERATION":
            self._generation_task = asyncio.create_task(
                self._run_generation(az.zone_id))
        await self.broadcast_snapshot()

    async def on_ap_disconnected(self) -> None:
        await self._notify("ap_offline", "ARCHIPELAGO OFFLINE",
                           ("Reconnecting…",))
        await self.broadcast_snapshot()

    async def on_room_update(self) -> None:
        await self.on_items_updated()
        await self.reconcile()
        await self.broadcast_snapshot()

    async def on_items_updated(self, notify: bool = True) -> None:
        ap = self.ap
        before = (ap.signal_keys, ap.coins_received, ap.static_received)
        ap.recount()
        after = (ap.signal_keys, ap.coins_received, ap.static_received)
        if notify and self._items_synced_once and after != before:
            for kind, title, delta in (
                    ("signal_key_received", "SIGNAL KEY RECEIVED",
                     after[0] - before[0]),
                    ("coin_received", "EPSILON COIN RECEIVED",
                     after[1] - before[1]),
                    ("static_received", "EPSILON STATIC",
                     after[2] - before[2])):
                if delta > 0:
                    await self._notify(kind, title,
                                       (f"+{delta}",) if delta > 1 else ())
        self._items_synced_once = True

        if (self.save is not None and ap.synced
                and ap.coins_received < self.save.coins_spent
                and not self._low_coin_warned):
            self._low_coin_warned = True
            log.warning("server reports %d coins against %d spent; "
                        "clamping available to zero, preserving purchases",
                        ap.coins_received, self.save.coins_spent)
            await self._notify(
                "sync_warning", "COIN LEDGER SYNC WARNING",
                ("The server reports fewer coins than local spending "
                 "history.", "Purchases are preserved; balance clamped to 0."))

    # ------------------------------------------------------------------
    # Zone generation
    # ------------------------------------------------------------------

    def _zone_request(self, record: ZoneRecord) -> ZoneGenerationRequest:
        save = self.save
        ap = self.ap
        locations = []
        for loc in record.allocated_location_ids:
            s = ap.scouts.get(loc)
            if s is None:                 # should not happen after a scout
                s = ScoutInfo(loc, 0, f"Unknown item {loc}", 0, "Unknown",
                              "Unknown", False, 0)
            revealed = loc in ap.checked or loc in self._stocked_location_ids()
            locations.append(RequestLocation(
                location_id=loc,
                location_name=f"Archipepsi Check {loc - C.LOCATION_ID_BASE:03d}",
                item_name=_clamp_ap_string(s.item_name),
                recipient_name=_clamp_ap_string(s.recipient_name),
                recipient_game=_clamp_ap_string(s.recipient_game),
                item_flags=s.flags,
                item_name_may_appear_in_player_text=revealed))
        summaries = []
        for zid in save.zone_history:
            z = save.zone_by_id(zid)
            if z is not None and z.state == "COMPLETE" and z.zone is not None:
                summaries.append(ZoneSummary(
                    name=z.zone.display_name, theme=z.zone.theme,
                    target_game=z.target_game))
        echoes = tuple(
            EchoSummary(
                echo_id=e.echo_id, display_name=e.display_name,
                archetype=e.archetype, activation=e.activation,
                tags=tuple(e.tags), description=e.description)
            for e in save.echoes)
        return ZoneGenerationRequest(
            zone_id=record.zone_id,
            generation_id=(f"{save.seed_name}-{save.team}-{save.slot_id}-"
                           f"{record.zone_id}")[:160],
            campaign=CampaignContext(
                seed_name=save.seed_name, slot_name=save.slot_name,
                team=save.team, slot_id=save.slot_id,
                zone_index=record.generation_index + 1,
                target_game=_clamp_ap_string(record.target_game),
                is_finale=record.is_finale,
                static_glitch_units=ap.static_received,
                completed_zone_summaries=tuple(summaries[-6:])),
            player=PlayerContext(
                signal_keys=ap.signal_keys,
                coins_available=max(0, ap.coins_received - save.coins_spent),
                echoes=echoes),
            locations=tuple(locations))

    async def _run_generation(self, zone_id: str) -> None:
        """Provider call for an already-committed PENDING_GENERATION record."""
        record = self.save.zone_by_id(zone_id)
        if record is None or record.state != "PENDING_GENERATION":
            return
        provider = self.provider
        if self.force_fallback_once:
            from .epsilon import FallbackEpsilonProvider
            provider = FallbackEpsilonProvider()
            self.force_fallback_once = False
        # Creativity changes model instructions only (§11.4); providers
        # without the knob simply carry an unused attribute.
        provider.creativity = self.save.epsilon_creativity
        request = self._zone_request(record)
        try:
            outcome = await generate_zone_validated(
                provider, request,
                allocated_location_ids=list(record.allocated_location_ids),
                owned_echo_ids=[e.echo_id for e in self.save.echoes],
                archive_dir=self.archive_dir)
        except Exception:
            log.exception("generation failed past fallback for %s", zone_id)
            self.last_generation_error = "generation failed past fallback"
            self._apply(T.abandon_zone(self.save, zone_id))
            await self._notify("zone_abandoned", "GENERATION FAILED",
                               ("The Zone could not be built; its Checks "
                                "returned to the pool.",))
            await self.broadcast_snapshot()
            return

        self.last_generation_error = outcome.error
        self._apply(T.accept_zone(self.save, outcome.value,
                                  used_fallback=outcome.used_fallback))
        if outcome.used_fallback and self.provider_name != "fallback":
            await self._notify("fallback_used", "EPSILON OFFLINE — FALLBACK USED",
                               (outcome.error or "",))
        await self._emit(ZoneReady(type="zone_ready", zone=outcome.value,
                                   used_fallback=outcome.used_fallback))
        await self.broadcast_snapshot()

    async def handle_request_next_zone(self, finale: bool) -> None:
        if self.save is None:
            raise IntentError("no campaign loaded")
        hub = self.hub_status()
        if not hub.accepts_zone_request:
            raise IntentError(
                f"a Zone cannot be started right now (mode {hub.mode})")
        if finale:
            if not hub.finale_offered:
                raise IntentError("the finale is not offered right now")
            if C.GOAL_LOCATION_ID not in self.ap.missing:
                raise IntentError("the finale is already resolved")
            goal_scout = self.ap.scouts.get(C.GOAL_LOCATION_ID)
            target = goal_scout.track_key if goal_scout else "Archipepsi"
            ids: list[int] = [C.GOAL_LOCATION_ID]
        else:
            ids, target = self._select_zone_locations()
        zone_id = f"zone_{self.save.generation_counter + 1:03d}"
        self._apply(T.start_generation(
            self.save, zone_id=zone_id, allocated_location_ids=ids,
            target_game=_clamp_ap_string(target), is_finale=finale))
        await self.broadcast_snapshot()          # GENERATING is visible state
        self._generation_task = asyncio.create_task(
            self._run_generation(zone_id))

    # ------------------------------------------------------------------
    # Zone traversal intents
    # ------------------------------------------------------------------

    async def handle_enter_zone(self, zone_id: str) -> None:
        self._require_save()
        try:
            self._apply(T.enter_zone(self.save, zone_id))
        except ValueError as exc:
            raise IntentError(str(exc)) from exc
        await self.broadcast_snapshot()

    async def handle_leave_zone(self, zone_id: str) -> None:
        """Pause-menu Return to Hub. No persistent change; Godot resets
        transient state itself."""
        self._require_save()
        await self.broadcast_snapshot()

    async def handle_exit_zone(self, zone_id: str) -> None:
        """Pure travel. Completion is driven by Check confirmation."""
        self._require_save()
        await self.reconcile()
        await self.broadcast_snapshot()

    async def handle_abandon_zone(self, zone_id: str) -> None:
        self._require_save()
        try:
            self._apply(T.abandon_zone(self.save, zone_id))
        except ValueError as exc:
            raise IntentError(str(exc)) from exc
        await self._notify("zone_abandoned", "ZONE ABANDONED",
                           ("Its unclaimed Checks returned to the pool.",))
        await self.broadcast_snapshot()

    # ------------------------------------------------------------------
    # Small intents
    # ------------------------------------------------------------------

    async def handle_equip_echo(self, echo_id: str | None) -> None:
        self._require_save()
        try:
            self._apply(T.equip_echo(self.save, echo_id))
        except ValueError as exc:
            raise IntentError(str(exc)) from exc
        await self.broadcast_snapshot()

    async def handle_set_creativity(self, value: int) -> None:
        self._require_save()
        self._apply(set_creativity(self.save, value))
        await self.broadcast_snapshot()

    def _require_save(self) -> None:
        if self.save is None:
            raise IntentError("no campaign loaded")

    def _require_online(self) -> None:
        if self.backend is None or not self.ap.connected or not self.ap.synced:
            raise IntentError(
                "ARCHIPELAGO OFFLINE — RECONNECT TO SEND THIS CHECK",
                scope="ap")

    # ------------------------------------------------------------------
    # Shop cadence (restock logic; purchase flows live in transactions.py)
    # ------------------------------------------------------------------

    def _price_for(self, flags: int) -> int:
        if flags & C.FLAG_PROGRESSION:
            return C.SHOP_PRICE_PROGRESSION
        if flags & C.FLAG_USEFUL:
            return C.SHOP_PRICE_USEFUL
        return C.SHOP_PRICE_OTHER

    def apply_shop_cadence(self) -> None:
        """Run after a Zone completes. Restock at the cadence points; release
        unsold reservations otherwise. Never starves the allocator."""
        save = self.save
        count = save.completed_zone_count
        due = (count >= C.SHOP_FIRST_STOCK_AFTER_ZONES
               and (count - C.SHOP_FIRST_STOCK_AFTER_ZONES)
               % C.SHOP_RESTOCK_EVERY_ZONES == 0)
        if not due:
            if save.shop.stock:
                self._apply(T.restock_shop(save, []))
            return
        candidates = sorted(self.shop_candidates()
                            | self._stocked_location_ids())
        # Leave at least SHOP_MIN_REMAINING_AFTER_STOCK for the next Zone.
        zone_pool_size = len(self.zone_candidates(ignore_stock=True))
        n = min(C.SHOP_STOCK_SIZE, len(candidates),
                max(0, zone_pool_size - C.SHOP_MIN_REMAINING_AFTER_STOCK))
        shuffled = C.deterministic_shuffle(
            candidates, *C.shop_stock_seed(save.seed_name, save.team,
                                           save.slot_id, count))
        items = []
        for loc in shuffled[:n]:
            s = self.ap.scouts.get(loc)
            if s is None or s.recipient_is_self:
                continue
            items.append({
                "location_id": loc,
                "cost": self._price_for(s.flags),
                "item_name": _clamp_ap_string(s.item_name),
                "recipient_name": _clamp_ap_string(s.recipient_name),
                "recipient_game": _clamp_ap_string(s.recipient_game),
            })
        self._apply(T.restock_shop(save, items))

    def release_stock_before_waiting(self) -> None:
        """§11.5: a shop reservation must never be why a Zone cannot generate."""
        if (self.save is not None and self.save.shop.stock
                and not self.zone_candidates()
                and self.zone_candidates(ignore_stock=True)):
            self._apply(T.restock_shop(self.save, []))

    # ------------------------------------------------------------------
    # Echo generation
    # ------------------------------------------------------------------

    def _echo_request(self, location_id: int) -> EchoGenerationRequest:
        s = self.ap.scouts[location_id]
        save = self.save
        return EchoGenerationRequest(
            source=EchoSource(
                location_id=location_id,
                item_name=_clamp_ap_string(s.item_name),
                source_game=_clamp_ap_string(s.recipient_game),
                recipient_name=_clamp_ap_string(s.recipient_name),
                item_flags=s.flags),
            player_state=EchoPlayerState(
                existing_echoes=tuple(
                    EchoSummary(
                        echo_id=e.echo_id, display_name=e.display_name,
                        archetype=e.archetype, activation=e.activation,
                        tags=tuple(e.tags), description=e.description)
                    for e in save.echoes),
                signal_keys=self.ap.signal_keys,
                coins_available=max(
                    0, self.ap.coins_received - save.coins_spent)),
            required_echo_id=f"echo_{location_id}")

    async def grant_echo(self, location_id: int) -> str | None:
        """Generate and persist the Echo for a confirmed foreign location.
        Returns the echo_id, or None when no Echo applies. Idempotent."""
        save = self.save
        scout = self.ap.scouts.get(location_id)
        if scout is None or scout.recipient_is_self:
            return None
        echo_id = f"echo_{location_id}"
        if save.echo_by_id(echo_id) is not None:
            return echo_id
        async with self._echo_lock:              # one at a time
            if self.save.echo_by_id(echo_id) is not None:
                return echo_id
            self.provider.creativity = save.epsilon_creativity
            outcome = await generate_echo_validated(
                self.provider, self._echo_request(location_id),
                archive_dir=self.archive_dir)
            self._apply(T.add_echo(self.save, outcome.value))
            if outcome.used_fallback and self.provider_name != "fallback":
                await self._notify("fallback_used",
                                   "EPSILON OFFLINE — FALLBACK USED",
                                   (outcome.error or "",))
        return echo_id

    def _interacted_location_ids(self) -> set[int]:
        """Locations the player actually engaged: any Zone allocation past or
        present, current or pending shop stock, and pending checks."""
        save = self.save
        out: set[int] = set(self._pending_location_ids())
        out |= self._stocked_location_ids()
        for z in save.zones:
            out.update(z.allocated_location_ids)
            if z.zone is not None:
                out.update(z.zone.reward_location_ids)
        return out

    async def echo_backlog_sweep(self) -> None:
        """Foreign confirmed locations without an Echo. Interacted ones
        generate now; the rest lazily, at most 3 per load, one at a time."""
        save = self.save
        interacted = self._interacted_location_ids()
        for loc in sorted(self.ap.checked):
            scout = self.ap.scouts.get(loc)
            if scout is None or scout.recipient_is_self:
                continue
            if save.echo_by_id(f"echo_{loc}") is not None:
                continue
            if loc in interacted:
                echo_id = await self.grant_echo(loc)
                if echo_id:
                    echo = self.save.echo_by_id(echo_id)
                    await self._notify(
                        "echo_acquired", "EPSILON ECHO ACQUIRED",
                        (echo.display_name,), location_id=loc,
                        echo_id=echo_id)
            elif self._lazy_echo_budget > 0:
                self._lazy_echo_budget -= 1
                echo_id = await self.grant_echo(loc)
                if echo_id:
                    echo = self.save.echo_by_id(echo_id)
                    await self._notify(
                        "echo_acquired", "EPSILON ECHO ACQUIRED",
                        (echo.display_name,), location_id=loc,
                        echo_id=echo_id)

    # ------------------------------------------------------------------
    # Reconciliation — implemented in transactions.py, exposed here
    # ------------------------------------------------------------------

    async def reconcile(self) -> None:
        from . import transactions
        await transactions.reconcile(self)

    def schedule_reconcile_timers(self) -> None:
        """5s then 15s after a send (§5): re-examine, never event-wait."""
        async def later(delay: float) -> None:
            await asyncio.sleep(delay)
            await self.reconcile()
            await self.broadcast_snapshot()
        for delay in (5.0, 15.0):
            task = asyncio.create_task(later(delay))
            self._reconcile_tasks.add(task)
            task.add_done_callback(self._reconcile_tasks.discard)

    # ------------------------------------------------------------------
    # Debug
    # ------------------------------------------------------------------

    async def handle_debug(self, command: str) -> None:
        if command == "resync":
            await self.reconcile()
            await self.broadcast_snapshot()
        elif command == "print_snapshot":
            log.info("snapshot: %s", self.snapshot().model_dump_json())
            await self.broadcast_snapshot()
        elif command == "force_fallback_zone":
            self.force_fallback_once = True
            await self.handle_request_next_zone(False)
        elif command in ("grant_mock_coin", "grant_mock_signal_key"):
            if self.backend is None or self.backend.mode != "mock":
                raise IntentError(
                    f"{command} is mock-AP only", scope="protocol")
            item = (C.ITEM_ID_EPSILON_COIN if command == "grant_mock_coin"
                    else C.ITEM_ID_SIGNAL_KEY)
            self.backend.grant_item(item)
            await self.on_room_update()
        elif command == "clear_campaign":
            if self._save_path is not None and self._save_path.exists():
                self._save_path.unlink()
                bak = self._save_path.with_suffix(
                    self._save_path.suffix + ".bak")
                if bak.exists():
                    bak.unlink()
            self.save = None
            if self.backend is not None and self.ap.connected:
                await self.on_ap_ready()
            else:
                await self.broadcast_snapshot()
