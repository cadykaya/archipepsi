"""THE BRAIN: allocation, tiers, finale, shop, coins, snapshot.

All persistent change goes through `schemas/transitions.py` (plus the
bridge-local `set_creativity` below, which follows the same
rebuild-and-validate shape). The engine holds exactly one `CampaignSave`
value object and replaces it atomically; every replacement is persisted
before any network send that depends on it.
"""

from __future__ import annotations

import asyncio
import json
import logging
import uuid
from collections import defaultdict
from pathlib import Path
from pydantic import ValidationError

from .ap_backend import APBackend, APData, ScoutInfo
from .epsilon import (
    CampaignContext, EchoGenerationRequest, EchoSummary, PlayerContext,
    RequestLocation, ZoneGenerationRequest, ZoneSummary,
    generate_echo_validated, generate_zone_validated,
)
from .epsilon.requests import (
    EchoPlayerState, EchoSource, OwnedComponentSummary, OwnedLinkSummary,
    allowed_for)
from .schemas import constants as C
from .schemas import transitions as T
from .schemas.mechanics import (
    Mechanics, derive_mechanics, owned_affordance_tags, owned_capabilities)
from .epsilon.concepts import preferred_modes, read_concepts
from .schemas.echo import (
    COMPLEXITY_BUDGETS, over_soft_budget, upgradable_field_info)
from .schemas.protocol import (
    CampaignScale,
    BridgeError, CampaignSave, CampaignSnapshot, EarnedLocalReward, HubStatus,
    Notification, ScoutedLocation, ShopState, SlotAssignment, ZoneHandle,
    ZoneReady, ZoneRecord,
)
from .schemas import protocol as P
from .schemas.zone import Zone, validate_zone
from .echo_projection import detail_examples, history_view
from . import instrumentation
from . import layout as layout_check
from . import candidate, minor_hosting, quiet, shells
from . import store
from . import topology

log = logging.getLogger("archipepsi.campaign")

MAX_LAZY_ECHOES_PER_LOAD = 3


class IntentError(Exception):
    """A refused intent. Answered with a recoverable `error`, never a crash.

    `about` is the domain key of the thing that was refused, for the one
    kind of refusal a client cannot merely read and forget: one it is
    holding an operation open against. Empty everywhere else, and empty
    means "unchecked" rather than "not yours" — a client resolves a
    pending operation on an exact match and on nothing else.
    """

    def __init__(self, message: str, scope: str = "bridge",
                 about: str = ""):
        super().__init__(message)
        self.scope = scope
        self.about = about


def use_consumable_key(component_id: str, generation: int,
                       use_index: int) -> str:
    """The domain key of one consumable spend, for `BridgeError.about`.

    Built from the intent's own fields on both sides rather than from a
    token either side invented — the house rule wherever identity is
    echoed (`key_id`, `use_index`, `LatchFired.(package_id, latch_id)`).
    Two spends of the same component differ by index; the same index
    either side of a refill differs by generation; so an exact match is
    exactly one operation and can never resolve a different one.
    """
    return f"use_consumable:{component_id}:{generation}:{use_index}"


def set_creativity(save: CampaignSave, value: int) -> CampaignSave:
    """Bridge-local transition, same shape as `schemas/transitions.py`:
    build the complete next save and validate in one step."""
    return CampaignSave(**{**save.model_dump(), "epsilon_creativity": value})


def _component_detail(component) -> str:
    """One word for what a component IS, for the S6 request graph.

    A provider choosing what to upgrade needs to tell a grapple from a
    shotgun; the kind alone says "action" for both.
    """
    for attribute in ("primitive", "stat", "status", "event", "readout",
                      "tag", "palette_color"):
        value = getattr(component, attribute, None)
        if value is None:
            continue
        return str(getattr(value, "type", value))[:32]
    return ""


def _clamp_ap_string(text: str) -> str:
    """AP-sourced strings are untrusted: clamp and strip control chars."""
    cleaned = "".join(ch for ch in text if ch.isprintable())
    return cleaned[:C.MAX_AP_STRING_LEN] or "?"


def budget_headroom(mechanics) -> dict:
    """§16 in full: `{kind: [owned, soft, hard]}`.

    `over_soft_budget` answers "is this kind crowded"; a provider deciding
    whether one more resource is fine or is the sixteenth needs the
    numbers, and guessing wrong costs a repair round. `affordance` is
    counted in DISTINCT TAGS, matching the unit §16 states and the unit
    `budget_errors` refuses in — a steer measured differently from the
    refusal would fire at a size the refusal never agrees with.
    """
    out: dict = {}
    for kind, (soft, hard) in sorted(COMPLEXITY_BUDGETS.items()):
        if kind == "affordance":
            owned = len({o.component.tag for o in mechanics.owned
                         if o.component.kind == "affordance"})
        else:
            owned = len([o for o in mechanics.owned if o.kind == kind])
        out[kind] = [owned, soft, hard]
    return out


#: What a component counts AS, for §15's "don't make it gun four".
#:
#: By family rather than by exact primitive, which is the difference
#: between noticing the campaign §15 actually describes and noticing only
#: a campaign with three of the literally-same verb. A hitscan, a
#: burst-fire and a projectile are three guns to a player; keying on
#: `primitive.type` counted them as one each and said nothing.
_FAMILIES: dict[str, tuple[str, ...]] = {
    "guns": ("hitscan_damage", "projectile_damage", "burst_fire",
             "charge_shot", "arc_lob", "beam_sustained"),
    "melee": ("melee_swing", "melee_thrust", "slam_ground"),
    "dashes": ("dash", "air_dash", "blink"),
    "jumps": ("double_jump", "wall_kick", "hover", "glide"),
    "grapples": ("grapple_to_surface", "grapple_pull_target",
                 "grapple_swing"),
    "guards": ("shield", "block", "parry"),
    "sustain": ("heal_self", "cleanse", "restore_resource"),
}


def _family_of(component) -> str:
    """One word for what this component adds to the build, or "" if it
    adds nothing §15 would count."""
    primitive = getattr(component, "primitive", None)
    if primitive is not None:
        for family, verbs in _FAMILIES.items():
            if primitive.type in verbs:
                return family
        return str(primitive.type)
    # Traits and resources count too: a campaign with four damage traits
    # is as lopsided as one with four guns, and keying only on actions
    # meant the hint went quiet for exactly the builds it should notice.
    stat = getattr(component, "stat", None)
    if stat is not None:
        return f"{stat} traits"
    if component.kind == "resource":
        return "resources"
    return ""


def _relevance_hint(mechanics) -> str:
    """§15's rule, phrased against this campaign.

    "If you already own three guns, Master Sword should not be gun four."
    The request has carried the owned graph since S6, but a graph is a
    list — this is the sentence that says what to DO with it, which is the
    half §15 calls the prompt-level rule.

    Empty on a fresh campaign: with nothing owned there is nothing to
    relate to, and telling a provider to relate to nothing would push it
    toward a disposition that cannot validate.
    """
    if not mechanics.owned:
        return ""
    families: dict[str, int] = {}
    for owned in mechanics.owned:
        family = _family_of(owned.component)
        if family:
            families[family] = families.get(family, 0) + 1
    crowded = sorted((count, verb) for verb, count in families.items()
                     if count >= 2)
    # The specific half leads. `MAX_TEXT_LEN` is 160 characters, and the
    # generic sentence alone very nearly fills it — putting it first
    # truncated away the only part a provider could act on.
    parts: list[str] = []
    if crowded:
        worst = ", ".join(f"{verb} x{count}" for count, verb in
                          reversed(crowded[-3:]))
        parts.append(f"already well supplied: {worst}")
    parts.append("prefer a new relationship with what is owned over a "
                 "fourth of something")
    return "; ".join(parts)[:C.MAX_TEXT_LEN]


def _with_graph(zone, barred=()):
    """A composed Zone, carrying the topology its chamber order implied.

    Branching when the Zone can carry it and a plain chain when it
    cannot: `compose_with_branch` returns the chain unchanged rather
    than forcing a junction into a Zone with nowhere to put one.

    **Refuses rather than ships a Zone you cannot get around.** The
    graph is proved here — the exit reachable, `R` a subset of `E`,
    every Check in a reachable room, every key obtainable without
    passing its own lock — because a Zone that fails this has no
    business reaching a save. A failure falls back to the chain, which
    is the topology that shipped before graphs existed and is reachable
    by construction.
    """
    product = topology.compose_with_branch(list(zone.chambers),
                                           barred=barred)
    # A COMPOSITION THAT DID NOT HAPPEN IS NOT A ZONE.
    #
    # This used to read the refusal paths as ordinary empty products and
    # hand the result back as a good Zone: `apply` drops `notes`,
    # `reachability` cannot tell an edge-less refusal from the legacy
    # chain it must keep accepting, and the only thing that noticed was
    # the `Zone` schema refusing doors-without-edges when `accept_zone`
    # rebuilt the record — a pydantic error out of a background task.
    # The reason is a code now, and it is read rather than logged.
    if product.refused:
        raise topology.GraphRefused(product.refusal)
    composed = topology.apply(zone, product)
    verdict = topology.reachability(composed)
    if verdict.ok:
        return composed
    log.warning("zone %s: branch graph refused (%s); composing the chain",
                zone.zone_id, "; ".join(verdict.errors[:2]))
    chain = topology.apply(zone, topology.compose_chain(list(zone.chambers)))
    chain_verdict = topology.reachability(chain)
    if chain_verdict.ok:
        return chain
    # EVEN THE CHAIN DOES NOT GET AROUND. A defect in the chambers, not
    # in the graph — and returning the ungraphed Zone made a failed NEW
    # composition indistinguishable from a genuine legacy save, which is
    # the one shape that must keep loading. Refused explicitly instead.
    raise topology.GraphRefused(topology.GraphRefusal(
        "chain_unreachable",
        "even the plain chain does not get around this Zone: "
        + "; ".join(chain_verdict.errors[:2])))


class CampaignEngine:
    def __init__(self, *, provider, provider_name: str,
                 save_dir: Path | None = None,
                 archive_dir: Path | None = None,
                 quiet_generation: bool = False,
                 candidate_steps: tuple[str, ...] = ()):
        self.provider = provider
        self.provider_name = provider_name
        self.save_dir = save_dir or store.DEFAULT_SAVE_DIR
        self.archive_dir = archive_dir

        #: OPT-IN, AND OFF. The quieter-generation preview (`quiet.py`,
        #: follow-up 02 item D) narrows two keys of the request that
        #: every Zone already carries. Default `False` is the whole
        #: promise that normal generation composes what it always
        #: composed: with this flag down, `_zone_request` does not call
        #: into `quiet` at all and the request is byte-for-byte the one
        #: that shipped. It is a PREVIEW for review, not a budget
        #: ruling, and no campaign setting reads it.
        self.quiet_generation = quiet_generation
        #: O05-13: the CANDIDATE profile's steps, or `()` for off. Off is
        #: the default and the promise: with it off `candidate` is never
        #: called and every Zone is composed exactly as it always was.
        #: On, the named relationship composers run on each Zone after its
        #: graph is proved and before it is accepted (`candidate.py`).
        self.candidate_steps = candidate.steps_of(tuple(candidate_steps))
        #: O05-11: the profile's OPTIONS, kept apart from its Zone steps
        #: so every "is the profile on" test above still asks about Zone
        #: composition. `consumables` advertises the consumable slot in
        #: this campaign's Echo requests (`_echo_request`).
        self.candidate_options = candidate.options_of(
            tuple(candidate_steps))

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
        #: Which Zone `_generation_task` is building, so a resume can tell
        #: "already running" from "a different Zone".
        self._generating_zone_id: str | None = None
        #: Identity of the Echo log every connected client already holds,
        #: so a broadcast can elide a log nobody's copy of is stale for.
        #: See `_log_identity` for why it is a tuple and not a length.
        self._broadcast_log_identity: tuple | None = None

    # ------------------------------------------------------------------
    # Plumbing
    # ------------------------------------------------------------------

    @property
    def ap(self) -> APData:
        return self.backend.data if self.backend else APData()

    def _build_metadata(self) -> dict:
        """What this build is, resolved once per process.

        Stamped on every playtime record so a run before authored art and
        a run after it can be told apart -- which is the only thing that
        makes the pre-art baseline comparable to anything. Cached because
        it shells out to git and a Zone ending is not the moment for that.
        """
        if CampaignEngine._build_cache is None:
            from .version import build_metadata
            CampaignEngine._build_cache = build_metadata()
        return CampaignEngine._build_cache

    #: Process-wide: the build does not change while the bridge runs.
    _build_cache: dict | None = None

    @property
    def config(self) -> C.CampaignConfig:
        """This campaign's scale — the single place the engine asks.

        The SAVE wins, because a campaign in progress keeps the shape it
        was created with; a seed's scale is only consulted before there
        is a save. Neither means the current default: a run that predates
        the options is a prototype campaign, and reinterpreting it as a
        450-location one strands every Check it has (CAMPAIGN_SCALE.md 2).
        """
        if self.save is not None:
            return self.save.scale.config()
        return self.ap.campaign_scale or C.PROTOTYPE_CONFIG

    def _apply(self, new_save: CampaignSave) -> None:
        """Replace the campaign and persist atomically. The only write path.

        Persist BEFORE assigning. The other order looks equivalent and is
        not: a write that raises leaves the campaign running on state
        that was never saved, so memory and disk disagree until restart.

        Playtest 1 is what that costs. A Windows-only fsync error fired
        inside `start_generation`, so the mode advanced to GENERATING in
        memory, the save never landed, and the generation task after this
        call never launched -- leaving a Hub whose portal answered "a
        Zone cannot be started right now (mode GENERATING)" forever, for
        a generation that was not running and never would.

        Assigning last means a failed save is just a failed save: the
        campaign is exactly where it was, and the player can press the
        button again.
        """
        if self._save_path is not None:
            store.write_save(self._save_path, new_save)
        self.save = new_save

    async def _emit(self, message) -> None:
        if self.emit is not None:
            await self.emit(message)

    def _log_identity(self) -> tuple | None:
        """What identifies the Echo log a client is holding.

        Not its length: `self.save` is replaced wholesale — a different
        campaign, a reload, a switch to `None` — and two different logs
        can be the same length. The campaign key pins WHICH campaign and
        `next_interpretation_seq` pins how far it has been written, and
        that counter is monotone within a campaign and never reused, so
        equality here really does mean "the same log, unchanged".
        """
        save = self.save
        if save is None:
            return None
        return (save.seed_name, save.team, save.slot_id,
                save.next_interpretation_seq, len(save.interpretations))

    async def broadcast_snapshot(self) -> None:
        """One snapshot to every client, with the lifetime Echo log left
        out when it has not changed since the last one.

        A late campaign's log is ~390 KiB of a ~400 KiB snapshot, and a
        snapshot goes out on every state change — a Check, a Zone
        transition, a coin. The log only ever grows at the end, so re-
        sending all of it to say "a coin was spent" was the single
        largest thing on the wire and the least informative.

        Correctness rests on two facts and nothing else: every client is
        sent a COMPLETE snapshot the moment it connects (`server.py`) and
        again for every `hello`, and elision requires the log identity to
        be exactly equal to the one at the last complete broadcast. Any
        change at all — an appended Echo, a different campaign, a
        campaign cleared — is inequality, and inequality sends the log.
        """
        snap = self.snapshot()
        identity = self._log_identity()
        if identity is not None and identity == self._broadcast_log_identity:
            snap = snap.model_copy(update={
                "interpretations": (), "interpretations_complete": False})
        else:
            self._broadcast_log_identity = identity
        await self._emit(snap)

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
        pool = set(self.config.eligible_location_ids(self.ap.signal_keys))
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

        # This campaign's shape, not the prototype's. Allocating three
        # Checks in a campaign configured for fifteen is a 450-location
        # run played at prototype density (CAMPAIGN_SCALE.md 2, 4).
        config = save.scale.config()
        picked = shuffled(target)[:config.zone_target_checks]
        if len(picked) < config.zone_min_checks:
            for track in scan:
                if track == target:
                    continue
                for loc in shuffled(track):
                    if loc not in picked:
                        picked.append(loc)
                    if len(picked) >= config.zone_min_checks:
                        break
                if len(picked) >= config.zone_min_checks:
                    break
        if len(picked) == 1 and len(pool) > 1:
            raise IntentError(
                "allocator bug: a 1-Check Zone with more eligible remaining")
        return picked, target

    # ------------------------------------------------------------------
    # Hub status and snapshot
    # ------------------------------------------------------------------

    def _finale_progress(self) -> int:
        config = self.config
        return len(self.ap.checked
                   & set(range(config.first_location_id,
                               config.goal_location_id)))


    def _dormant_zone(self):
        """The Zone the player walked out of, if there is one.

        At most one Zone is unfinished at a time — it holds its Checks
        and blocks generation until it is finished or abandoned — so
        `next` is a choice between one candidate and none. Ordered by
        the save's own zone order so two calls never disagree.
        """
        return next((r for r in self.save.zones if r.state == "DORMANT"),
                    None)

    def hub_status(self) -> HubStatus:
        ap = self.ap
        keys = ap.signal_keys
        progress = self._finale_progress()
        base = dict(ap_online=ap.connected and ap.synced,
                    goal_sent=bool(self.save and self.save.goal_sent),
                    postgame=bool(self.save and self.save.goal_sent),
                    signal_keys=keys, finale_progress=progress,
                    # The Hub RENDERS this. Left at its default, a
                    # 450-location campaign told the player it needed 24
                    # of 449 while the gate actually wanted 360.
                    finale_required=self.config.finale_required_checks())

        if self.save is None:
            return HubStatus(mode="NO_CAMPAIGN", headline="NOT CONNECTED",
                             detail="Connect to Archipelago or start a mock campaign.",
                             ap_online=base["ap_online"], signal_keys=keys,
                             finale_progress=progress)

        # WHICH ZONE THE PORTAL IS HOLDING.
        #
        # `active_zone` is only the Zone the player is standing in, and
        # `rest_zone` clears it — so a Zone walked out of was invisible
        # here, the Hub reported ZONE_AVAILABLE, and the portal offered
        # to design a new one. The bridge then refused that with "still
        # holds locations". A player who walked out and restarted had no
        # way back in short of abandoning the Zone.
        az = self.save.active_zone
        held = az or self._dormant_zone()
        base["revisitable"] = tuple(
            ZoneHandle(zone_id=r.zone_id,
                       display_name=r.zone.display_name if r.zone else "")
            for r in reversed(self.save.zones)
            if r.state == "COMPLETE")
        if held is not None:
            mode = P.hub_mode_for(held)
            headline, detail = {
                "GENERATING": ("EPSILON IS DESIGNING",
                               "A Zone is being generated. Hold."),
                "ZONE_READY": ("ZONE READY",
                               held.zone.display_name if held.zone else ""),
                "ZONE_ACTIVE": ("ZONE IN PROGRESS",
                                "Step back through the portal to resume."),
                "ZONE_DORMANT": ("ZONE WAITING",
                                 f"{held.zone.display_name} — you left "
                                 "with work unfinished."
                                 if held.zone else
                                 "You left a Zone with work unfinished."),
                "ZONE_FAILED": ("ZONE FAILED TO BUILD",
                                "It could not be laid out. Discard it to "
                                "return its Checks to the pool."),
            }[mode]
            # THE OFFER IS TO DISCARD, NOT TO ENTER. `resume_zone_id`
            # stays empty for a Zone that cannot be entered: its whole
            # meaning is "which Zone the portal enters", and filling it
            # here is how the portal came to light up over a Zone it
            # could not open.
            failed = mode == "ZONE_FAILED"
            name = held.zone.display_name if held.zone else ""
            return HubStatus(mode=mode, headline=headline, detail=detail,
                             holding_finale=(az is not None
                                             and az.is_finale),
                             resume_zone_id="" if failed else held.zone_id,
                             resume_zone_name="" if failed else name,
                             discard_zone_id=held.zone_id if failed else "",
                             discard_zone_name=name if failed else "",
                             **base)

        finale_unlocked = (progress >= self.config.finale_required_checks()
                          and keys >= C.FINALE_REQUIRED_SIGNAL_KEYS)
        goal_missing = self.config.goal_location_id in ap.missing
        all_checked = len(ap.checked) >= self.config.location_count

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
            interpretations=save.interpretations if save else (),
            interpretation_count=len(save.interpretations) if save else 0,
            # Folded here, once, and sent. The client never folds: a second
            # implementation of this is a second source of truth for the one
            # thing that has to be identical everywhere.
            mechanics=save.derive() if save else Mechanics(),
            slots=save.slots if save else SlotAssignment(),
            local_rewards=save.local_rewards if save else (),
            consumable_uses=save.consumable_uses if save else (),
            consumable_generation=save.consumable_generation if save else 0,
            active_zone=save.active_zone if save else None,
            # Derived here on every send, from the record just above it,
            # so the identity and the content it identifies cannot come
            # apart in flight. See `CampaignSnapshot.active_proposal_id`.
            active_proposal_id=(
                layout_check.proposal_digest(save.active_zone.zone)
                if save and save.active_zone
                and save.active_zone.zone is not None else ""),
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
        try:
            existing = store.load_save(self._save_path)
        except store.SaveUnreadable as exc:
            # Files are there and none of them parsed. Starting fresh here
            # would create an empty campaign whose first write moves the
            # player's real save into the `.bak` slot — the whole thing
            # gone behind one logged line. Refuse instead: a save that
            # cannot be read is a problem to report.
            log.error("%s", exc)
            # A `BridgeError`, not a `Notification`: notifications are the
            # one-shot vocabulary of things that WENT WELL, and none of its
            # kinds means "stop". `recoverable=False` because retrying the
            # same connect reads the same unreadable files; a human has to
            # move them aside or restore a copy.
            await self._emit(BridgeError(
                type="error", scope="bridge", recoverable=False,
                message=f"{exc} Nothing has been overwritten."[
                    :C.MAX_TEXT_LEN]))
            raise IntentError(str(exc)) from exc
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
            # The scale the SEED was generated with. None means the seed
            # predates the options, which is the prototype campaign and
            # not the current default (CAMPAIGN_SCALE.md 2).
            scale = ap.campaign_scale or C.PROTOTYPE_CONFIG
            fresh = CampaignSave(
                seed_name=ap.seed_name, team=ap.team, slot_id=ap.slot_id,
                slot_name=_clamp_ap_string(ap.slot_name),
                track_order=tuple(order),
                scale=CampaignScale(
                    location_count=scale.location_count,
                    zone_target_checks=scale.zone_target_checks,
                    zone_budget=scale.zone_budget))
            self._apply(fresh)
            log.info("created campaign %s at %d locations / %d per Zone / "
                     "%d budget (track order: %s)",
                     self._save_path.name, scale.location_count,
                     scale.zone_target_checks, scale.zone_budget,
                     " → ".join(order))
        elif self.save is None:
            # A campaign in progress keeps the scale it was created with.
            # If the seed now reports a different one, the save and the
            # seed are describing different campaigns -- resizing a run
            # underneath a player would strand every Check outside the
            # new range, so this is reported and the SAVE wins.
            if (ap.campaign_scale is not None
                    and existing.scale.config() != ap.campaign_scale):
                log.error(
                    "campaign scale mismatch: the save is %d locations and "
                    "the seed says %d. Keeping the save's scale; this "
                    "campaign was generated against different options.",
                    existing.scale.location_count,
                    ap.campaign_scale.location_count)
            self.save = existing
            log.info("loaded campaign %s at %d locations",
                     self._save_path.name, existing.scale.location_count)

        self._low_coin_warned = False
        await self.on_items_updated(notify=False)
        await self.reconcile()

        if self.save.goal_sent:
            await self.backend.send_goal()

        # A Zone interrupted mid-generation re-runs against its committed ids.
        az = self.save.active_zone
        if az is not None and az.state == "PENDING_GENERATION":
            self._start_generation_task(az.zone_id)
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

    def _echo_summaries(self) -> tuple:
        """The BOUNDED detail examples, as `EchoSummary`.

        One helper, used by both provider paths. They used to build the
        same summary twice, over the whole log, in two places -- which is
        how one of them (`existing_echoes`) stayed unbounded after the
        other was noticed.
        """
        save = self.save
        return tuple(
            EchoSummary(
                echo_id=e.echo_id, display_name=e.display_name,
                kinds=tuple(sorted({op.component.kind for op in e.operations
                                    if op.op == "create"})),
                tags=tuple(e.tags), description=e.description)
            for e in detail_examples(save.interpretations))

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
        # BOUNDED. This used to be every interpretation: ~29 at the
        # prototype's thirty locations and ~449 at the 450 default, which
        # is 96 KB and roughly 24,000 tokens of Echo summaries in front
        # of every Zone prompt. The complete history still reaches the
        # provider -- as derived state and an accumulated-influence
        # aggregate, in `echo_history` below -- so nothing is forgotten;
        # only the DETAIL is a sample.
        echoes = self._echo_summaries()
        zone_budget = save.scale.config().zone_budget_for(
            len(record.allocated_location_ids))
        if self.quiet_generation:
            # NARROWED HERE, BEFORE THE REQUEST IS BUILT, because this
            # one number is the only budget the rest of the system
            # reads. `fallback_zone_attempt` composes from
            # `request.campaign.zone_budget` and `generate_zone_validated`
            # ACCEPTS against the same field -- so narrowing only
            # `constraints["zone_budget"]`, which is the same fact spelled
            # for a prompt, changes nothing at all and silently delivers
            # the filter-only arm: the families gone and their share
            # handed straight back as more of what remains. Measured: a
            # Zone asked for 72% of the band came out at 917 against a
            # 648-792 band, which is the baseline size.
            #
            # Setting it here instead lets the request's own validator
            # derive the WHOLE constraints block from the narrowed
            # number, so the room envelope, the enemy caps and the
            # per-room soft cap are internally consistent and a live
            # Epsilon is told the same budget it will be judged against.
            # That consistency is also what makes the preview +17 rooms
            # and +27 enemies (docs/reports/2026-09-13-quieter-
            # generation-preview.md): one number derives all three.
            # Reported, not compensated for -- decoupling them is a
            # change to the shipped composer that an experiment may not
            # make.
            asked = quiet.preview_budget(zone_budget)
            # AND THE CONTRACT'S OWN FLOOR IS STILL THE FLOOR.
            #
            # `CampaignContext.zone_budget` is bounded `ge=ZONE_BUDGET_MIN`,
            # and at the prototype's scale a Zone's budget IS that
            # minimum -- so 72% of it is 144 against a floor of 200 and
            # the request cannot be built at all. Unclamped, that was not
            # a refusal anyone could read: generation raised
            # `ValidationError` inside the generation task, the client
            # waited for a ZONE_READY that never came, and the whole run
            # ended in a timeout with the cause fifteen frames down a
            # bridge log.
            #
            # Clamped, and SAID OUT LOUD, because a clamp that bites is
            # the compensation arm wearing the variant's name: the
            # families are still narrowed but the band is not really
            # lower, which is exactly the comparison the owner rejected.
            # The fraction itself is not touched to make this pass.
            if asked < C.ZONE_BUDGET_MIN:
                log.warning(
                    "QUIET GENERATION: zone %s asked for %d, which is "
                    "below the contract floor of %d. Clamping to the "
                    "floor -- this Zone's band is %s the baseline's, so "
                    "it is %s, NOT the lower-budget variant. The "
                    "comparison wants a campaign at default scale.",
                    record.zone_id, asked, C.ZONE_BUDGET_MIN,
                    "equal to" if C.ZONE_BUDGET_MIN >= zone_budget
                    else "nearer",
                    "filter-only" if C.ZONE_BUDGET_MIN >= zone_budget
                    else "a partial reduction")
                asked = C.ZONE_BUDGET_MIN
            zone_budget = asked
        request = ZoneGenerationRequest(
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
                completed_zone_summaries=tuple(summaries[-6:]),
                # A Zone is built for the content its Checks are worth.
                # The last Zone of a campaign holds whatever divides out
                # -- often one Check -- and asking for a full-length
                # level around it would demand content the Zone has no
                # reason to contain (CAMPAIGN_SCALE.md 5).
                zone_budget=zone_budget),
            player=PlayerContext(
                signal_keys=ap.signal_keys,
                coins_available=max(0, ap.coins_received - save.coins_spent),
                echoes=echoes,
                # The whole history, bounded. `echoes` above is a dozen
                # examples; this is what stops a late Zone composing as
                # though the first four hundred never happened.
                echo_history=history_view(save.interpretations,
                                          save.derive())),
            locations=tuple(locations),
            # §13: only what this campaign can actually interact with.
            # Over OWNED mechanics, never the loadout — a Zone whose
            # contents depended on the slots at generation time would lie
            # about itself the moment the player changed them.
            unlocked_affordances=owned_affordance_tags(save.derive()),
            # NO REQUIREMENT BEFORE GUARANTEE (owner ruling 2026-08-30).
            # Computed here, from the fold, because this is where the
            # authoritative campaign state lives. Case C -- a capability
            # the Zone itself establishes before the requirement -- has
            # no producer yet, so nothing is passed for it and the
            # guarantee rests on the permanent baseline and what the
            # campaign already owns.
            guaranteed_capabilities=owned_capabilities(save.derive()))
        if not self.quiet_generation:
            return request
        # AND THE OTHER HALF: which families may be composed from. The
        # band above is a number the provider derives everything from;
        # this is an offer, and `fallback._build_to_budget` filters its
        # own cycle order by it. Same provider, same `validate_zone`,
        # same acceptance path -- a preview is an ordinary request with
        # a smaller band and a shorter menu.
        narrowed = dict(request.constraints)
        narrowed["activity_kinds"] = list(quiet.preview_kinds())
        log.info("QUIET GENERATION: zone %s asks for %d of the %d this "
                 "campaign would normally spend, and offers %s",
                 record.zone_id, zone_budget,
                 save.scale.config().zone_budget_for(
                     len(record.allocated_location_ids)),
                 ", ".join(quiet.preview_kinds()))
        return request.model_copy(update={"constraints": narrowed})

    def _start_generation_task(self, zone_id: str) -> None:
        """Start the provider call for `zone_id`, unless one is in flight.

        A reconnect re-runs `on_ap_ready`, which resumes a Zone still in
        `PENDING_GENERATION` — and a real provider call takes seconds, so a
        connection that drops during generation is exactly when the resume
        lands on top of the original. Unguarded, that called the provider
        TWICE for one Zone (billed twice, against a live Epsilon), and the
        loser then raised `ValueError: Zone is GENERATED, not pending`
        inside a bare task, where nothing surfaces it.
        """
        task = self._generation_task
        if (task is not None and not task.done()
                and self._generating_zone_id == zone_id):
            log.info("generation for %s is already running; not starting a "
                     "second", zone_id)
            return
        self._generating_zone_id = zone_id
        self._generation_task = asyncio.create_task(
            self._run_generation(zone_id))
        # A bare task swallows its exception until garbage collection, which
        # reports it as "Task exception was never retrieved" long after the
        # fact and never to the player.
        self._generation_task.add_done_callback(self._generation_finished)

    def _generation_finished(self, task: asyncio.Task) -> None:
        if task.cancelled():
            return
        exc = task.exception()
        if exc is not None:
            log.error("zone generation task failed", exc_info=exc)

    def _record_generation_error(self, error: str | None) -> None:
        """The reason a Zone was not built, trimmed to what can be sent.

        **A REFUSAL MUST NEVER BE ABLE TO BREAK THE SNAPSHOT THAT CARRIES
        IT.** `last_generation_error` is bounded at `MAX_TEXT_LEN`, and
        the strings written to it come from the validator and the shell
        selector, which have no such bound -- a chamber that fails its
        shell fit produces a sentence well past 160 characters. The
        snapshot then raised `ValidationError` on construction, which
        killed the generation task AND the broadcast, so the refusal
        never reached the client and the Hub sat in GENERATING forever.
        Measured live: a Zone whose rooms were inflated past what the
        router can place left the client waiting with no verdict at all.

        Trimmed here rather than widened in the schema, because widening
        moves the cliff instead of removing it: the next message is as
        long as whatever produced it. An ellipsis so a reader can tell a
        trimmed reason from a short one.
        """
        if error is not None and len(error) > C.MAX_TEXT_LEN:
            error = error[:C.MAX_TEXT_LEN - 1] + "\u2026"
        self.last_generation_error = error

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
                owned_echo_ids=[e.echo_id
                                for e in self.save.interpretations],
                archive_dir=self.archive_dir)
        except Exception:
            log.exception("generation failed past fallback for %s", zone_id)
            await self._generation_failed(
                zone_id, "generation failed past fallback",
                "The Zone could not be built; its Checks returned to the "
                "pool.")
            return

        self._record_generation_error(outcome.error)
        # Re-checked AFTER the await: the state guard at the top of this
        # method was true seconds ago, and a Zone can be abandoned (or
        # accepted by a duplicate run) while the provider is thinking.
        # `accept_zone` refuses anything but PENDING_GENERATION, and it
        # RAISES, so without this the loser dies rather than standing down.
        current = self.save.zone_by_id(zone_id)
        if current is None or current.state != "PENDING_GENERATION":
            log.info("zone %s is %s by the time generation returned; "
                     "discarding this outcome", zone_id,
                     current.state if current else "gone")
            return
        # THE GRAPH IS PRODUCED HERE, once, before the Zone is accepted.
        #
        # A composed Zone arrives with its chambers and no topology, so
        # this is where the list stops being the graph: `compose_*`
        # emits the edges, the door assignments, the keys and the plugs,
        # and `reachability` refuses a Zone the player could not get
        # around before anything is stored. Doing it after acceptance
        # would mean a Zone existed in a save with an unproved graph.
        try:
            composed = self._candidate(
                _with_graph(outcome.value),
                certify=lambda z: validate_zone(
                    z, expected_zone_id=request.zone_id,
                    allocated_location_ids=list(
                        record.allocated_location_ids),
                    owned_echo_ids=[e.echo_id
                                    for e in self.save.interpretations],
                    owned_affordance_tags=request.unlocked_affordances,
                    guaranteed_capabilities=(
                        request.guaranteed_capabilities),
                    # THE BUDGET THE PROVIDER WAS HELD TO (P5-12). Left
                    # out, `validate_zone` falls back to the prototype's
                    # 200 points and a default-scale Zone reads as 31
                    # enemies over a cap of 14 -- which the comparison
                    # below hid as "already failing" until a step
                    # changed the count.
                    zone_budget=request.campaign.zone_budget,
                    **self._certify_offer(shells.offer_of(request))))
        except topology.GraphRefused as exc:
            # THE SAME BOUNDED RECOVERY a failed generation already has,
            # because this IS a Zone that could not be built. Nothing is
            # accepted, no `zone_ready` is emitted, the locations go back
            # to the pool through `abandon_zone` and no other path, and
            # the Hub can ask for the next Zone.
            log.error("zone %s: composition refused (%s) %s", zone_id,
                      exc.refusal.code, exc.refusal.detail)
            await self._generation_failed(
                zone_id, f"composition refused: {exc.refusal.code}",
                "The Zone could not be assembled; its Checks returned to "
                "the pool.")
            return
        self._apply(T.accept_zone(self.save, composed,
                                  used_fallback=outcome.used_fallback))
        if outcome.used_fallback and self.provider_name != "fallback":
            await self._notify("fallback_used", "EPSILON OFFLINE — FALLBACK USED",
                               (outcome.error or "",))
        await self._emit(ZoneReady(
            type="zone_ready", zone=composed,
            proposal_id=layout_check.proposal_digest(composed),
            attempt=self.save.zone_by_id(composed.zone_id).layout_refusals,
            used_fallback=outcome.used_fallback))
        await self.broadcast_snapshot()

    async def _reselect_hosts(self, rec, rooms) -> bool:
        """Recompose this Zone's graph with `rooms` barred as hosts.

        Returns whether it was done. False falls through to the ordinary
        layout refusal — which is the honest answer when the rooms are
        ones this Zone has already been told about, or when the Zone
        cannot be composed at all without them.
        """
        barred = tuple(sorted(set(rec.unhostable_rooms) | set(rooms)))
        try:
            # A CANDIDATE ZONE IS RE-COMPOSED FROM A CLEAN ZONE: every
            # relationship the profile added is bound to the old graph's
            # edges, so it is stripped, the graph recomposed, and the
            # profile applied again to what came out.
            base = (candidate.strip(rec.zone) if self.candidate_steps
                    else rec.zone)
            regraphed = self._candidate(_with_graph(base, barred=barred))
        except topology.GraphRefused as exc:
            # Barring the room left a Zone that cannot be composed —
            # a leaf with nowhere to hang, most likely. That is the
            # composition refusal it already has, not this path.
            log.info("zone %s: barring %s leaves it uncomposable (%s)",
                     rec.zone_id, list(rooms), exc.refusal.code)
            return False
        # THE ARRANGEMENT IS PRESERVED OR THIS IS NOT THE REPAIR.
        #
        # Re-selection moves a branch to a supported host. Quietly
        # handing back a Zone with FEWER branches is a different thing —
        # branch removal to make a device requirement go away — and it
        # is not an approved outcome here. When no reassignment of the
        # same arrangement exists, this stands down and the ordinary
        # bounded layout refusal takes it, which is a distinct result
        # with its own recovery.
        want = len(rec.zone.plugs)
        if len(regraphed.plugs) != want:
            log.info("zone %s: barring %s leaves %d branch(es) of %d; "
                     "not re-selecting", rec.zone_id, list(rooms),
                     len(regraphed.plugs), want)
            return False
        try:
            self._apply(T.reselect_hosts(self.save, rec.zone_id, rooms,
                                         regraphed))
        except ValueError as exc:
            log.info("zone %s: not re-selecting (%s)", rec.zone_id, exc)
            return False
        log.info("zone %s: %s cannot host a return; recomposed with "
                 "%d branch(es)", rec.zone_id, list(rooms),
                 len(regraphed.plugs))
        await self._emit(ZoneReady(
            type="zone_ready", zone=regraphed,
            proposal_id=layout_check.proposal_digest(regraphed),
            attempt=self.save.zone_by_id(rec.zone_id).layout_refusals,
            used_fallback=self.save.zone_by_id(rec.zone_id).used_fallback))
        await self.broadcast_snapshot()
        return True

    def _certify_offer(self, offer: dict) -> dict:
        """The shell offer the candidate profile is certified against.

        The provider's own, unless the profile hosts minors: a minor is
        never offered to a provider, so `validate_zone` would refuse the
        step's shell for not having been offered. Then it is the
        provider's offer plus each minor's own registry rule, which is
        what the step placed it against (`minor_hosting.certify_offer`).
        """
        if "minors" not in self.candidate_steps:
            return offer
        return minor_hosting.certify_offer(offer)

    def _candidate(self, zone, certify=None):
        """The CANDIDATE profile on a proved Zone, or the Zone unchanged.

        Every step's outcome -- emitted or declined, and why -- goes to
        the log and to `<save dir>/candidate/<zone>.json`, a local record
        like the playtime file: nothing in the campaign reads it back.

        **RE-CERTIFIED, NOT TRUSTED (O05-13.3).** The provider's Zone went
        through `validate_zone` before the profile touched it, and
        acceptance does not validate again, so a step that broke a rule
        -- dropped an allocated Check, named an unoffered shell -- would
        otherwise reach a save unexamined. `certify` is the same
        `validate_zone`, with the same offer and allocation the provider
        was held to, and the whole Zone schema is re-run. A profile
        result that INTRODUCES an error is DISCARDED WHOLE: the Zone goes
        on exactly as the provider made it, and the record says which
        rule refused what.
        """
        if not self.candidate_steps:
            return zone
        applied = candidate.apply(zone, self.candidate_steps)
        refused: list[str] = []
        if certify is not None and applied.emitted:
            # WHAT THE PROFILE INTRODUCED, and only that. `validate_zone`
            # judges a provider's Zone BEFORE its graph is composed, and a
            # graphed Zone can already fail a rule the graph changed (the
            # enemy budget counts rooms the graph adds) -- so the profile
            # is refused for an error its own Zone has and the graphed
            # Zone it started from does not.
            already = set(certify(zone) or ())
            refused = [e for e in (certify(applied.zone) or ())
                       if e not in already]
            # AND THE SCHEMA, whole: a composer that built its Zone with
            # `model_copy` skipped every model validator.
            try:
                Zone.model_validate_json(applied.zone.model_dump_json())
            except ValueError as exc:
                refused.insert(0, f"the Zone schema refused it: {exc}")
        if refused:
            log.warning("zone %s: the candidate profile's Zone failed "
                        "validate_zone and is discarded: %s", zone.zone_id,
                        "; ".join(refused[:3]))
            applied = candidate.Applied(zone, tuple(
                (st, False, f"discarded with the whole profile: "
                            f"validate_zone refused it ({refused[0]})")
                for st, _em, _no in applied.steps))
        for step, emitted, note in applied.steps:
            log.info("zone %s: candidate %s %s: %s", zone.zone_id, step,
                     "EMITTED" if emitted else "declined", note)
        try:
            out = Path(self.save_dir) / "candidate"
            out.mkdir(parents=True, exist_ok=True)
            (out / f"{zone.zone_id}.json").write_text(json.dumps({
                "zone_id": zone.zone_id,
                "profile": list(self.candidate_steps),
                "provider": self.provider_name,
                "steps": [{"step": st, "emitted": em, "note": no}
                          for st, em, no in applied.steps],
                "proposal_digest": layout_check.proposal_digest(
                    applied.zone),
                "certified": not refused,
                "refused_by_validate_zone": refused[:8],
            }, indent=1), encoding="utf-8")
        except OSError as exc:                       # pragma: no cover
            log.warning("candidate record not written: %s", exc)
        return applied.zone

    async def _generation_failed(self, zone_id: str, error: str,
                                 detail: str) -> None:
        """A Zone that could not be built, handled the one supported way.

        One function rather than two copies, because the recovery is the
        same whether the provider failed or the composer refused: give
        the Checks back, say so, and leave the Hub able to ask for the
        next Zone. Accounting is `abandon_zone`'s and only its.
        """
        self._record_generation_error(error)
        self._apply(T.abandon_zone(self.save, zone_id))
        await self._notify("zone_abandoned", "GENERATION FAILED", (detail,))
        await self.broadcast_snapshot()

    # ------------------------------------------------------------------
    # Local instrumentation (CAMPAIGN_SCALE.md 13)
    # ------------------------------------------------------------------

    def record_zone_timing(self, timing) -> None:
        """Append what the Zone actually cost. Local file, never a request.

        Not a state transition: nothing in the campaign reads it back, no
        snapshot carries it and no rule depends on it. It exists so the
        40-minute Zone can stop being a target and start being a
        measurement -- and so a content budget that turns out to buy four
        minutes of play can be seen to.

        Deliberately silent about failure. A Zone the player just finished
        must not be lost because a log file could not be opened.
        """
        if self.save is None:
            return
        record = instrumentation.build_record(self.save, timing,
                                              self._build_metadata())
        if record is not None:
            instrumentation.append_record(self.save_dir, record)

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
            if self.config.goal_location_id not in self.ap.missing:
                raise IntentError("the finale is already resolved")
            goal_scout = self.ap.scouts.get(self.config.goal_location_id)
            target = goal_scout.track_key if goal_scout else "Archipepsi"
            ids: list[int] = [self.config.goal_location_id]
        else:
            ids, target = self._select_zone_locations()
        zone_id = f"zone_{self.save.generation_counter + 1:03d}"
        self._apply(T.start_generation(
            self.save, zone_id=zone_id, allocated_location_ids=ids,
            target_game=_clamp_ap_string(target), is_finale=finale))
        await self.broadcast_snapshot()          # GENERATING is visible state
        self._start_generation_task(zone_id)

    # ------------------------------------------------------------------
    # Zone traversal intents
    # ------------------------------------------------------------------

    async def handle_enter_zone(self, zone_id: str) -> None:
        """Walk in. A Zone that has been placed before is REPLAYED.

        Re-entry sends the committed manifest back down, so the engine
        lays the same pieces in the same places rather than searching
        again. That is where the determinism actually comes from: not
        from two machines rediscovering a layout, but from one machine
        writing it down once.
        """
        self._require_save()
        try:
            self._apply(T.enter_zone(self.save, zone_id))
        except ValueError as exc:
            raise IntentError(str(exc)) from exc
        rec = self.save.zone_by_id(zone_id)
        if rec is not None and rec.zone is not None \
                and rec.manifest is not None:
            # A REPLAY carries its identity too. The Zone is committed,
            # so a result about it takes the committed path either way —
            # but a re-entry that is about to rebuild should echo what
            # it rebuilt, not nothing.
            await self._emit(ZoneReady(
                type="zone_ready", zone=rec.zone,
                proposal_id=layout_check.proposal_digest(rec.zone),
                used_fallback=rec.used_fallback,
                manifest=rec.manifest))
        await self.broadcast_snapshot()

    async def _put_the_zone_down(self, zone_id: str) -> None:
        """Leave a Zone without finishing or abandoning it.

        The Zone keeps everything — its committed layout, its Check
        identities, which of them are claimed, and the player's
        progress. **Returning unclaimed Checks to the allocator is
        abandonment's behaviour and only abandonment's**; it is an
        explicit act with an explicit cost, never the consequence of
        walking out of a door.

        Reconciling afterwards is what keeps the relaxed exit honest: a
        Zone whose last Check confirms while the player is in the Hub
        still completes, so leaving early costs a walk back rather than
        the Check.
        """
        rec = self.save.zone_by_id(zone_id) if self.save else None
        if rec is not None and rec.state in ("ACTIVE", "VISITING"):
            try:
                self._apply(T.rest_zone(self.save, zone_id))
            except ValueError as exc:
                # Checks in flight: the Zone stays where it is and the
                # next reconcile pass settles it. Refusing the intent
                # would strand the player in a Zone they have left.
                log.info("zone %s stays active on leave: %s", zone_id, exc)

    async def handle_leave_zone(self, zone_id: str) -> None:
        """Pause-menu Return to Hub. The Zone goes dormant, not away."""
        self._require_save()
        await self._put_the_zone_down(zone_id)
        await self.reconcile()
        await self.broadcast_snapshot()

    async def handle_exit_zone(self, zone_id: str) -> None:
        """Out through the exit portal.

        **The exit does not require every Check.** Reaching it completes
        the route; the Zone goes dormant with whatever is outstanding
        still allocated to it, and the player can come back. That
        relaxation is only safe because re-entry works — shipping it
        without `DORMANT` would convert a forgone reward into a stranded
        one.
        """
        self._require_save()
        await self._put_the_zone_down(zone_id)
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

    async def handle_grant_local_reward(self, intent) -> None:
        """Record an earned local reward (§14.2). Never AP truth.

        The Zone the player is standing in is stamped on here rather than
        taken from the client: what the client knows is that it found a
        note, and where it was found is the campaign's own business.
        """
        if self.save is None:
            raise IntentError("no campaign loaded")
        active = self.save.active_zone_id or ""
        self._apply(T.grant_local_reward(self.save, EarnedLocalReward(
            kind=intent.kind, reward_id=intent.reward_id,
            display_name=_clamp_ap_string(intent.display_name),
            description=intent.description[:C.MAX_TEXT_LEN],
            source_zone_id=active,
            best_seconds=intent.best_seconds)))
        await self.broadcast_snapshot()

    async def handle_progress(self, intent) -> None:
        """Zone progress the engine reports: a key, a lock, a station.

        **Closing a path that was open and dropped.** The engine has been
        sending `key_collected` and `lock_opened` since the slice landed
        and nothing received them, so a key survived exactly as long as
        the process did.

        The Zone is taken from the intent rather than from
        `active_zone_id`: progress belongs to the place it happened in,
        and a player who left for the Hub mid-report should not have a
        key land in whichever Zone is current.

        **Idempotent, and quietly so.** The same event twice is one
        event, and a resend after a dropped connection is the normal
        case rather than an error.

        **But not every target is monotone any more** (D-8). The key,
        lock, station and latch sets only grow, so "the same event
        twice" and "a repeat is absorbed" mean the same thing for them.
        `zone_state_selected` writes `macro_state`, which is
        OVERWRITTEN: re-selecting the state a variable already holds is
        absorbed exactly as before, and selecting a DIFFERENT state is a
        legitimate second event rather than a replay -- a reversible
        variable going back is the mechanic working. The idempotence
        here is per `(variable, state)`, not per variable.
        """
        if self.save is None:
            raise IntentError("no campaign loaded")
        if self.save.zone_by_id(intent.zone_id) is None:
            raise IntentError(
                f"no Zone '{intent.zone_id}' in this campaign")
        before = self.save
        # AN UNKNOWN IDENTITY IS A REFUSED INTENT, NOT A CRASH. The
        # transitions raise `ValueError` for an illegal request, as their
        # module says; without this the generic arm in `server.py` caught
        # them, logged a traceback for every one, and answered
        # "ValueError: ..." — a refusal dressed as a bridge fault, which
        # is noise that hides the real ones. A `ValidationError` is NOT
        # translated: that one means this module built an invalid save
        # and is a bug rather than a bad message.
        try:
            if intent.type == "key_collected":
                nxt = T.record_key(self.save, intent.zone_id, intent.key_id)
            elif intent.type == "latch_fired":
                nxt = T.record_latch(self.save, intent.zone_id,
                                     intent.package_id, intent.latch_id)
            elif intent.type == "lock_opened":
                nxt = T.record_lock(self.save, intent.zone_id,
                                    intent.room_id, intent.socket_id)
            elif intent.type == "zone_state_selected":
                nxt = T.record_zone_state(self.save, intent.zone_id,
                                          intent.variable_id, intent.state)
            elif intent.type == "object_transported":
                nxt = T.record_object_transported(
                    self.save, intent.zone_id, intent.object_id,
                    intent.room_id)
            elif intent.type == "object_settled":
                nxt = T.record_object_settled(
                    self.save, intent.zone_id, intent.object_id,
                    intent.room_id, intent.position, intent.yaw)
            elif intent.type == "object_consumed":
                nxt = T.record_object_consumed(
                    self.save, intent.zone_id, intent.mechanism_id)
            elif intent.type == "object_recovered":
                nxt = T.recover_transported_object(
                    self.save, intent.zone_id, intent.object_id)
            elif intent.type == "carrier_rested":
                nxt = T.record_carrier_rested(
                    self.save, intent.zone_id, intent.package_id,
                    intent.carrier_id, intent.t, intent.destination,
                    intent.held)
            else:
                nxt = T.record_station(self.save, intent.zone_id,
                                       intent.station_id)
        except ValidationError:
            raise
        except ValueError as exc:
            raise IntentError(str(exc)) from exc
        if nxt is before:
            return          # already recorded; nothing to save or announce
        self._apply(nxt)
        await self.broadcast_snapshot()

    async def handle_layout_result(self, intent) -> None:
        """The engine placed a Zone; decide whether to commit it.

        **Validate, then commit.** A layout that passes becomes the
        accepted immutable manifest and is replayed forever after; one
        that fails is refused and never acquires a digest, so nothing
        downstream can mistake an unchecked layout for a checked one.

        A Zone whose topology is still its chamber order returns
        LEGACY_UNCERTIFIED and stores nothing — there are no edges for
        the evidence to be about, and pretending otherwise would let an
        old save look newly certified.
        """
        if self.save is None:
            raise IntentError("no campaign loaded")
        rec = self.save.zone_by_id(intent.zone_id)
        if rec is None or rec.zone is None:
            raise IntentError(
                f"no generated Zone '{intent.zone_id}' to place")
        # A RESULT FOR A PROPOSAL THAT NO LONGER EXISTS IS NOT ABOUT
        # THIS ZONE, and must touch nothing of the one that replaced it.
        #
        # The client captures `proposal_id` from `zone_ready` when it
        # STARTS a build and echoes it here, so an old build carries the
        # old id however long it takes to come back. Without this a late
        # result spends the replacement's refusal budget, bars the
        # replacement's rooms, or commits a layout of the Zone it
        # replaced. Ignored outright: nothing counted, nothing barred,
        # nothing committed, and the record left exactly as it is.
        #
        # A client that sends no id behaves as it does today. Absent
        # means "cannot be checked", never "stale".
        if intent.proposal_id is not None:
            current = layout_check.proposal_digest(rec.zone)
            if intent.proposal_id != current:
                log.info("zone %s: a layout_result for proposal %s "
                         "arrived after %s replaced it; ignored",
                         intent.zone_id, intent.proposal_id, current)
                return
        # AND WHICH ATTEMPT IT IS ABOUT, which the digest cannot say.
        #
        # `proposal_digest` is content identity and identical content
        # hashes identically — correct, and exactly why it cannot tell
        # two attempts apart. After a refusal the campaign asks the
        # provider again and a deterministic one returns the same Zone,
        # so the previous attempt's result matches the current proposal
        # and is charged as a fresh failure. Measured before this guard:
        # one real refusal became two, and the duplicate cost a third of
        # the Zone's whole recovery budget.
        #
        # The ordinal is read from `layout_refusals` at offer time, so
        # there is no second counter to keep in step and nothing is
        # folded into the digest. Absent behaves as today.
        #
        # MISMATCH IN EITHER DIRECTION, and not merely "behind". A
        # result from an attempt this Zone has moved past is stale; a
        # result claiming an attempt the bridge has not reached was
        # built against a state this bridge does not hold, and charging
        # a refusal against the wrong attempt is the harm either way.
        if intent.attempt is not None and intent.attempt != rec.layout_refusals:
            log.info("zone %s: a layout_result for attempt %d arrived "
                     "during attempt %d; ignored", intent.zone_id,
                     intent.attempt, rec.layout_refusals)
            return

        # A RESULT FOR A ZONE THAT ALREADY GAVE UP IS STALE, and stale is
        # not an error: a client retrying after a dropped connection is
        # the ordinary case. Nothing is composed again, nothing is
        # notified again, and the save does not move. Without this the
        # handler kept notifying LAYOUT REFUSED and kept asking the
        # provider for a Zone the bridge had already stopped composing.
        if rec.layout_exhausted:
            log.info("zone %s already exhausted its layout attempts; "
                     "ignoring a stale result", intent.zone_id)
            return
        verdict = layout_check.validate(rec.zone, intent.layout)
        if verdict.legacy:
            log.info("zone %s has no graph; layout not certified",
                     intent.zone_id)
            return
        if not verdict.accepted:
            log.warning("zone %s layout refused (%s): %s", intent.zone_id,
                        verdict.status, "; ".join(verdict.errors[:3]))
            # A HOST THE ENGINE CANNOT STAND THE RETURN IN IS NOT A LOST
            # ZONE. The engine measured and said "not in this room"; the
            # content and the Checks are fine, and only the choice of
            # destination was wrong. Recompose the GRAPH with that room
            # barred and send it back to be laid out.
            #
            # Fresh proposals only, and `reselect_hosts` enforces it: a
            # Zone holding a committed manifest is a solved Zone the
            # player may be part-way through, and it keeps what it has.
            # The three recoveries stay separate — this one, the
            # abandon-on-composition-refusal, and the held-Zone discard.
            if verdict.unhostable_rooms and rec.manifest is None:
                if await self._reselect_hosts(rec, verdict.unhostable_rooms):
                    return
            # A REFUSAL HAS TO CHANGE SOMETHING. This used to log, notify
            # and leave the Zone ACTIVE, so the client kept playing a
            # Zone the validator had just said does not hold together and
            # kept claiming its Checks against it. The Zone goes DORMANT
            # and stops being the active one; its allocated locations are
            # untouched, because giving them back is `abandon_zone`'s
            # behaviour and only its.
            self._apply(T.refuse_layout(self.save, intent.zone_id))
            await self._notify(
                "zone_abandoned", "LAYOUT REFUSED",
                tuple(verdict.errors[:3]) or (verdict.status,))
            # COMPOSE IT AGAIN, against the ids it already holds. This is
            # the same recovery a crash mid-generation gets, and it is
            # why a refusal costs the seed nothing: `refuse_layout` puts
            # the record back to PENDING_GENERATION and this runs the
            # provider for it. After MAX_LAYOUT_REFUSALS it stops asking
            # and the record is DORMANT instead.
            again = self.save.zone_by_id(intent.zone_id)
            if again is not None and again.state == "PENDING_GENERATION":
                self._start_generation_task(intent.zone_id)
            await self.broadcast_snapshot()
            return
        self._apply(T.commit_layout(self.save, intent.zone_id,
                                    verdict.manifest))
        log.info("zone %s layout committed (%s)", intent.zone_id,
                 verdict.manifest["manifest_digest"])
        await self.broadcast_snapshot()

    async def handle_build_failed(self, intent) -> None:
        """The engine could not construct this Zone. There is no layout.

        **A build that never happened is not a layout that was refused,
        and it is not a proposal that was rejected before it was
        offered.** This proposal passed composition, was offered, was
        entered, and `ZoneBuilder` could not route it -- so there is no
        geometry to validate and `layout.validate` is never called.
        Nothing synthesises one to borrow the refusal path: a fabricated
        layout would be reported as a geometry error for geometry that
        was never laid down.

        **What was actually broken is that nothing arrived at all.**
        `ZoneController.setup` returned on the failure and sent nothing,
        so the record stayed ACTIVE waiting for a verdict that was never
        coming: the Hub stayed ZONE_ACTIVE, offered a way back into a
        Zone that cannot be built, and the campaign could not move.

        **The consequence is the refusal ladder, because that ladder is
        already the right one.** `refuse_layout` charges the attempt,
        sends a FRESH proposal back to be composed again inside
        `MAX_LAYOUT_REFUSALS`, parks a COMMITTED one DORMANT with its
        manifest, content and progress intact, and past the budget makes
        the Zone DORMANT so `hub_mode_for` reports ZONE_FAILED and the
        Hub offers ABANDON. The Checks are untouched throughout --
        giving allocated locations back is `abandon_zone`'s act and only
        its.

        The guards are `handle_layout_result`'s, for the same reasons: a
        result about a proposal that has been replaced, or about an
        attempt this Zone has moved past, must not spend the current
        one's budget, and a Zone that has already given up treats a
        resend as the ordinary case rather than an error.
        """
        if self.save is None:
            raise IntentError("no campaign loaded")
        rec = self.save.zone_by_id(intent.zone_id)
        if rec is None:
            raise IntentError(
                f"no Zone '{intent.zone_id}' to report a build failure for")
        # `rec.zone is None` IS NOT AN ERROR HERE, and this is where it
        # differs from `handle_layout_result`. That handler needs the
        # content to validate against; this one does not validate
        # anything. A record whose content was already cleared -- the
        # recovery from the PREVIOUS attempt got there first -- is a
        # stale report, and stale is the ordinary case.
        if rec.zone is None:
            log.info("zone %s: a build failure arrived for content the "
                     "campaign no longer holds; ignored", intent.zone_id)
            return
        if intent.proposal_id is not None:
            current = layout_check.proposal_digest(rec.zone)
            if intent.proposal_id != current:
                log.info("zone %s: a build failure for proposal %s "
                         "arrived after %s replaced it; ignored",
                         intent.zone_id, intent.proposal_id, current)
                return
        if intent.attempt is not None and intent.attempt != rec.layout_refusals:
            log.info("zone %s: a build failure for attempt %d arrived "
                     "during attempt %d; ignored", intent.zone_id,
                     intent.attempt, rec.layout_refusals)
            return
        if rec.layout_exhausted:
            log.info("zone %s already exhausted its layout attempts; "
                     "ignoring a stale build failure", intent.zone_id)
            return
        reason = (intent.reason or "").strip()
        log.warning("zone %s could not be built by the engine: %s",
                    intent.zone_id, reason or "(no reason given)")
        # WHETHER THIS IS RECOVERABLE IS THE RECORD'S QUESTION, not this
        # handler's. `refuse_layout` is the one place that knows a
        # committed Zone is kept and a fresh one is recomposed, and
        # asking it here rather than branching is what keeps the two
        # recoveries from drifting apart.
        committed = rec.manifest is not None
        self._apply(T.refuse_layout(self.save, intent.zone_id))
        # `_notify` bounds the headline and every line it is given, so
        # the engine's reason cannot break the notice that carries it --
        # the same cliff `_record_generation_error` exists for, guarded
        # on this side as well as on the client's.
        await self._notify(
            "zone_abandoned",
            "BUILD FAILED (SAVED ZONE)" if committed else "BUILD FAILED",
            (reason,) if reason else ("the engine could not lay it out",))
        again = self.save.zone_by_id(intent.zone_id)
        if again is not None and again.state == "PENDING_GENERATION":
            self._start_generation_task(intent.zone_id)
        await self.broadcast_snapshot()

    async def handle_use_consumable(self, component_id: str,
                                     use_index: int,
                                     generation: int) -> None:
        """Spend one charge. It stays equipped when empty (§9).

        Refusals are the transition's, and they are reported rather than
        swallowed: a client that has lost count of its own charges is a
        client whose HUD is lying, and finding out here is the cheap way
        to learn it.

        **THE REFUSAL CARRIES THE KEY OF WHAT IT REFUSED.** The client is
        holding this spend in flight — subtracting it from the count it
        draws so a second press cannot spend the same charge — and a
        refusal it cannot attribute is one it can never release. The
        count would stay a charge short for the rest of the session, and
        after a refill it would be a charge short of the *new* supply.
        """
        self._require_save()
        try:
            self._apply(T.spend_charge(self.save, component_id,
                                       use_index, generation))
        except ValueError as exc:
            raise IntentError(
                str(exc),
                about=use_consumable_key(component_id, generation,
                                         use_index)) from exc
        await self.broadcast_snapshot()

    async def handle_authorize_consumable(self, component_id: str,
                                          use_index: int,
                                          generation: int) -> None:
        """Count the charge before the client launches anything.

        The refusal carries the same key as the spend's, because the
        client is holding this attempt open in exactly the same way --
        and an authorization it cannot attribute is one it can never
        release, which leaves the supply a charge short for the session.
        """
        self._require_save()
        try:
            self._apply(T.authorize_consumable(
                self.save, component_id, use_index=use_index,
                generation=generation))
        except ValueError as exc:
            raise IntentError(
                str(exc),
                about=use_consumable_key(component_id, generation,
                                         use_index)) from exc
        await self.broadcast_snapshot()

    async def handle_release_consumable_authorization(
            self, component_id: str, use_index: int,
            generation: int) -> None:
        """Give back a charge whose effect never launched."""
        self._require_save()
        try:
            self._apply(T.release_consumable_authorization(
                self.save, component_id, use_index=use_index,
                generation=generation))
        except ValueError as exc:
            raise IntentError(
                str(exc),
                about=use_consumable_key(component_id, generation,
                                         use_index)) from exc
        await self.broadcast_snapshot()

    async def handle_slot_action(
        self, slot: str, component_id: str | None
    ) -> None:
        self._require_save()
        try:
            self._apply(T.slot_action(self.save, slot, component_id))
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
        # Leave one Zone's worth of Checks for the next Zone -- this
        # campaign's Zone, not the prototype's three, or the shop can
        # strip a fifteen-Check Zone down to a fifth of its length.
        zone_pool_size = len(self.zone_candidates(ignore_stock=True))
        n = min(C.SHOP_STOCK_SIZE, len(candidates),
                max(0, zone_pool_size - save.scale.config().shop_reserve))
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
        mechanics = save.derive()
        return EchoGenerationRequest(
            allowed=allowed_for(
                consumable="consumables" in self.candidate_options),
            source=EchoSource(
                location_id=location_id,
                item_name=_clamp_ap_string(s.item_name),
                source_game=_clamp_ap_string(s.recipient_game),
                recipient_name=_clamp_ap_string(s.recipient_name),
                item_flags=s.flags),
            player_state=EchoPlayerState(
                # The SAME bounded projection the Zone path uses. Two
                # subtly different summaries is how one of them stays
                # unbounded after the other is fixed.
                existing_echoes=self._echo_summaries(),
                echo_history=history_view(save.interpretations, mechanics),
                signal_keys=self.ap.signal_keys,
                coins_available=max(
                    0, self.ap.coins_received - save.coins_spent),
                owned_components=tuple(
                    OwnedComponentSummary(
                        component_id=owned.component_id,
                        kind=owned.kind,
                        display_name=owned.component.display_name,
                        mk=owned.mk,
                        upgradable=upgradable_field_info(owned.component),
                        detail=_component_detail(owned.component),
                        modifiers=tuple(
                            m.type for m in
                            getattr(owned.component, "modifiers", ())))
                    for owned in mechanics.owned),
                owned_links=tuple(
                    OwnedLinkSummary(link=edge.link, source=edge.source,
                                     target=edge.target)
                    for edge in mechanics.links),
                aliases=tuple(mechanics.aliases)),
            required_echo_id=f"echo_{location_id}",
            over_soft_budget=over_soft_budget(mechanics),
            budget_headroom=budget_headroom(mechanics),
            suggested_concepts=read_concepts(
                _clamp_ap_string(s.item_name),
                _clamp_ap_string(s.recipient_game)),
            preferred_modes=preferred_modes(save.epsilon_creativity),
            relevance_hint=_relevance_hint(mechanics))

    async def grant_echo(self, location_id: int) -> str | None:
        """Generate and persist the Echo for a confirmed foreign location.
        Returns the echo_id, or None when no Echo applies. Idempotent."""
        save = self.save
        scout = self.ap.scouts.get(location_id)
        if scout is None or scout.recipient_is_self:
            return None
        echo_id = f"echo_{location_id}"
        if save.interpretation_by_id(echo_id) is not None:
            return echo_id
        async with self._echo_lock:              # one at a time
            if self.save.interpretation_by_id(echo_id) is not None:
                return echo_id
            self.provider.creativity = save.epsilon_creativity
            outcome = await generate_echo_validated(
                self.provider, self._echo_request(location_id),
                mechanics=derive_mechanics(self.save.interpretations),
                archive_dir=self.archive_dir)
            self._apply(T.append_interpretation(self.save, outcome.value))
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

        async def grant_and_announce(loc: int) -> None:
            echo_id = await self.grant_echo(loc)
            if echo_id:
                echo = self.save.interpretation_by_id(echo_id)
                await self._notify(
                    "echo_acquired", "EPSILON ECHO ACQUIRED",
                    (echo.display_name,), location_id=loc, echo_id=echo_id)

        for loc in sorted(self.ap.checked):
            scout = self.ap.scouts.get(loc)
            if scout is None or scout.recipient_is_self:
                continue
            if save.interpretation_by_id(f"echo_{loc}") is not None:
                continue
            if loc in interacted:
                await grant_and_announce(loc)
            elif self._lazy_echo_budget > 0:
                self._lazy_echo_budget -= 1
                await grant_and_announce(loc)

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
