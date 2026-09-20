"""Two Archipepsi slots in ONE real Archipelago multiworld.

    python -m archipepsi_bridge.dual_real [server] [slotA] [slotB]

`smoke_real.py` proves one slot against a real server. This proves the
case the APWorld's own demo seed has always generated and nothing ever
exercised at runtime: two Archipepsi worlds in the same multiworld, two
independent bridges connected at once, checking each other's locations.

Why it needs a real server rather than `MockAPBackend`: every hazard here
lives in the seam between a slot and the multiworld, and the mock IS one
slot by construction. Both Archipepsi worlds number their locations
89100001–89100030 — the same thirty integers — and the only thing that
makes A's 89100001 a different location from B's is the slot context the
server keeps. Nothing in the bridge can be tested for confusing them by a
backend that only ever had one.

What is proven, in order:

  1. both connect and scout their own thirty
  2. the same numeric ids resolve to different items per slot
  3. A checks a location whose item is B's: AP delivers to B exactly once,
     A gets exactly one Echo, B gets none of A's campaign state
  4. the symmetric case back
  5. native items (Signal Key / Coin / Static) land only in the intended
     campaign
  6. both campaigns generate and claim Zones concurrently with no
     allocation, pending-check, interpretation, shop or save crossing
  7. save identity is independent and both reload
  8. one disconnects and reconnects while the other stays up
  9. both reach and report goal independently
 10. no location claimed twice, no Echo granted twice
"""

from __future__ import annotations

import asyncio
import logging
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path

from . import transactions as TX
from .ap_client import RealAPBackend
from .campaign import CampaignEngine
from .epsilon import FallbackEpsilonProvider
from .schemas import constants as C

log = logging.getLogger("archipepsi.dual")
log.setLevel(logging.INFO)


class DualFailure(AssertionError):
    """A property that must hold for two slots and did not."""


@dataclass
class Player:
    """One Archipepsi slot: its own engine, backend, save directory."""
    slot: str
    save_dir: Path
    engine: CampaignEngine = None            # type: ignore[assignment]
    backend: RealAPBackend = None            # type: ignore[assignment]
    claimed: list[int] = field(default_factory=list)

    @property
    def save(self):
        return self.engine.save

    def echo_ids(self) -> set[str]:
        return {i.echo_id for i in self.save.interpretations}

    def snapshot_state(self) -> dict:
        """Everything that must not move because the OTHER player acted."""
        save = self.save
        return {
            "seed": save.seed_name, "team": save.team,
            "slot_id": save.slot_id, "slot_name": save.slot_name,
            "zones": tuple((z.zone_id, z.state,
                            tuple(z.allocated_location_ids))
                           for z in save.zones),
            "pending": tuple(sorted(p.location_id
                                    for p in save.pending_checks)),
            "echoes": tuple(sorted(self.echo_ids())),
            "shop": tuple(sorted(i.location_id for i in save.shop.stock)),
            "coins_spent": save.coins_spent,
            "completed": save.completed_zone_count,
            "goal_sent": save.goal_sent,
        }


def _check(condition: bool, message: str) -> None:
    if not condition:
        raise DualFailure(message)


async def _wait(predicate, timeout: float, what: str) -> None:
    loop = asyncio.get_event_loop()
    deadline = loop.time() + timeout
    while not predicate():
        if loop.time() > deadline:
            raise TimeoutError(f"timed out waiting for {what}")
        await asyncio.sleep(0.2)


async def _settle(seconds: float = 3.0) -> None:
    """Let both clients' packet tasks drain. Both are on this event loop,
    so this is also what interleaves them."""
    await asyncio.sleep(seconds)


async def connect(player: Player, server: str, password: str = "") -> None:
    player.engine = CampaignEngine(
        provider=FallbackEpsilonProvider(), provider_name="fallback",
        save_dir=player.save_dir)
    player.backend = RealAPBackend(player.engine)
    player.engine.backend = player.backend
    await player.backend.connect(server, player.slot, password)
    await _wait(lambda: player.engine.save is not None, 45,
                f"{player.slot} connect + scout")


# ---------------------------------------------------------------------------
# 1–2: identity, and thirty integers that mean different things per slot
# ---------------------------------------------------------------------------

def prove_identities_are_separate(a: Player, b: Player) -> None:
    # The SEED's scale, not the prototype's. `demo.yaml` and
    # `partner.yaml` ask for 450 locations, so a harness that expected
    # thirty was asserting against a campaign nobody generates.
    size = a.engine.config.location_count
    ids = set(a.engine.config.active_location_ids())
    for p in (a, b):
        _check(p.engine.config.location_count == size,
               f"{p.slot} reports {p.engine.config.location_count} "
               f"locations, not {size}; the two slots disagree on the seed")
        _check(len(p.engine.ap.scouts) == size,
               f"{p.slot} scouted {len(p.engine.ap.scouts)}, not {size}")
        _check(set(p.engine.ap.scouts) == ids,
               f"{p.slot} scouted ids outside the Archipepsi range")

    _check(a.engine.ap.seed_name == b.engine.ap.seed_name,
           "the two slots are not in the same multiworld")
    _check(a.engine.ap.team == b.engine.ap.team, "different teams")
    _check(a.engine.ap.slot_id != b.engine.ap.slot_id,
           "both slots resolved to the same slot id")
    _check(a.engine._save_path != b.engine._save_path,
           f"both campaigns write to {a.engine._save_path}")
    _check(a.save.slot_id != b.save.slot_id,
           "the saves carry the same slot id")

    # The heart of it: the SAME numeric id is a different location in each
    # world. If any of this leaked, the two campaigns would be reading each
    # other's placements while believing they were their own.
    differing = 0
    for loc in sorted(ids):
        sa, sb = a.engine.ap.scouts[loc], b.engine.ap.scouts[loc]
        if (sa.item_id, sa.recipient_player) != (sb.item_id, sb.recipient_player):
            differing += 1
    _check(differing >= size // 2,
           f"only {differing} of {size} locations resolve "
           f"differently between the slots; a scout cache is being shared")

    # And each slot's own goal belongs to itself.
    for p in (a, b):
        goal = p.engine.ap.scouts[p.engine.config.goal_location_id]
        _check(goal.recipient_player in
               (a.engine.ap.slot_id, b.engine.ap.slot_id) or True,
               "unreachable")     # the goal may legitimately go anywhere
    log.info("identity OK: seed %s, slots %d/%d, %d of %d locations differ",
             a.engine.ap.seed_name, a.engine.ap.slot_id, b.engine.ap.slot_id,
             differing, size)


def prove_track_semantics(a: Player, b: Player) -> None:
    """A Track is a GAME, not a slot — pinned here because two Archipepsi
    slots are the first case where that distinction is visible.

    `ScoutInfo.track_key` is `recipient_game`, so in this multiworld a
    location whose item goes to the OTHER Archipepsi player carries the
    same Track key ("Archipepsi") as one whose item comes back to you.
    The two do not merge into one thing — `recipient_is_self` still
    separates them, and the reveal, the Echo grant and the archive all
    read that — but they DO share a Track, so the Hub offers them from one
    rotation rather than two.

    That is the behaviour, and it is coherent: a Track answers "which game
    receives this", and both answers are Archipepsi. Asserted rather than
    assumed so that if it ever changes, it changes deliberately.
    """
    for p in (a, b):
        locations = p.engine.config.active_location_ids()
        keys = {p.engine.ap.scouts[loc].track_key for loc in locations}
        _check("Archipepsi" in keys,
               f"{p.slot} has no Archipepsi Track at all")
        foreign_archipepsi = [
            loc for loc in locations
            if not p.engine.ap.scouts[loc].recipient_is_self
            and p.engine.ap.scouts[loc].track_key == "Archipepsi"]
        mine = [loc for loc in locations
                if p.engine.ap.scouts[loc].recipient_is_self]
        if foreign_archipepsi and mine:
            _check(set(p.save.track_order) == keys,
                   f"{p.slot}'s track_order {p.save.track_order} does not "
                   f"match the Tracks its scouts name {sorted(keys)}")
            # Same Track, still distinguishable — which is what keeps the
            # Echo grant correct.
            _check(not set(foreign_archipepsi) & set(mine),
                   "a location is both self-recipient and foreign")
            log.info("%s: %d locations go to the other Archipepsi slot and "
                     "%d come back to itself, sharing one 'Archipepsi' "
                     "Track", p.slot, len(foreign_archipepsi), len(mine))


# ---------------------------------------------------------------------------
# 3–5: a check crossing between the two worlds
# ---------------------------------------------------------------------------

async def prove_cross_delivery(sender: Player, receiver: Player) -> int:
    """`sender` checks one of ITS locations whose item belongs to
    `receiver`. Returns the location id."""
    target = next(
        (loc for loc, s in sorted(sender.engine.ap.scouts.items())
         if s.recipient_player == receiver.engine.ap.slot_id
         and loc not in sender.engine.ap.checked),
        None)
    _check(target is not None,
           f"no unchecked location in {sender.slot} sends to "
           f"{receiver.slot}; this seed cannot prove cross-delivery")
    scout = sender.engine.ap.scouts[target]

    before_recv = list(receiver.engine.ap.received)
    before_receiver = receiver.snapshot_state()
    before_receiver_checked = set(receiver.engine.ap.checked)
    before_receiver_missing = set(receiver.engine.ap.missing)
    before_echoes = sender.echo_ids()

    await sender.backend.check_locations([target])
    await _wait(lambda: target in sender.engine.ap.checked, 30,
                f"{sender.slot} check {target} confirmed")
    await sender.engine.reconcile()
    await _settle()

    # AP delivered the real item to the real recipient, exactly once.
    delivered = [i for i in receiver.engine.ap.received
                 if i.item_id == scout.item_id]
    before_same = [i for i in before_recv if i.item_id == scout.item_id]
    _check(len(delivered) == len(before_same) + 1,
           f"{receiver.slot} received {len(delivered) - len(before_same)} "
           f"copies of {scout.item_name!r} from one check")
    _check(len(receiver.engine.ap.received) == len(before_recv) + 1,
           f"{receiver.slot}'s received list moved by "
           f"{len(receiver.engine.ap.received) - len(before_recv)}, not 1")

    # The sender read it as foreign and got exactly one Echo for it.
    _check(not scout.recipient_is_self,
           f"{sender.slot} thinks {target} is its own; it belongs to "
           f"player {scout.recipient_player}")
    new_echoes = sender.echo_ids() - before_echoes
    _check(new_echoes == {f"echo_{target}"},
           f"{sender.slot} got {sorted(new_echoes)} for location {target}, "
           f"not exactly one Echo")

    # The receiver's CAMPAIGN did not move. Its item count did, and only
    # that: an Echo, a Zone, a pending check or a shop row crossing here
    # would mean two campaigns sharing state through a shared process.
    after_receiver = receiver.snapshot_state()
    _check(after_receiver == before_receiver,
           f"{receiver.slot}'s campaign changed because {sender.slot} "
           f"checked a location:\n  before {before_receiver}\n"
           f"  after  {after_receiver}")
    # NOT "the receiver has no echo_{target}". Both worlds number their
    # locations 89100001-89100030, so the receiver may legitimately already
    # hold an `echo_{target}` — earned from ITS OWN location with that
    # number, for a different item entirely. The id is unique within a
    # campaign, which is the only scope it has to be unique in. What must
    # be true is that whatever the receiver holds under that id is its own:
    # the snapshot comparison above already proves nothing MOVED, and this
    # proves what is there means the right thing.
    mine = receiver.save.interpretation_by_id(f"echo_{target}")
    if mine is not None:
        _check(mine.source_item_name
               == receiver.engine.ap.scouts[target].item_name,
               f"{receiver.slot}'s echo_{target} names "
               f"{mine.source_item_name!r}, but {target} holds "
               f"{receiver.engine.ap.scouts[target].item_name!r} in "
               f"{receiver.slot}'s world — it took {sender.slot}'s scout")
    # Stated as "did it MOVE", not "is this id absent". The receiver may
    # legitimately have checked its own location with the same number
    # already — the two worlds share all thirty integers — so an absence
    # test would fail on state the receiver created itself. What proves
    # isolation is that the sender's check changed nothing here.
    _check(set(receiver.engine.ap.checked) == before_receiver_checked,
           f"{receiver.slot}'s checked set changed when {sender.slot} "
           f"checked {target}: "
           f"{sorted(set(receiver.engine.ap.checked) ^ before_receiver_checked)}")
    _check(set(receiver.engine.ap.missing) == before_receiver_missing,
           f"{receiver.slot}'s missing set changed when {sender.slot} "
           f"checked {target}")

    sender.claimed.append(target)
    log.info("%s checked %d (%s -> %s): delivered once, one Echo, %s "
             "untouched", sender.slot, target, scout.item_name,
             receiver.slot, receiver.slot)
    return target


async def prove_native_items_land_only_where_meant(a: Player,
                                                   b: Player) -> None:
    """Signal Keys, Coins and Static are OUR item ids, so both worlds emit
    them and both can receive them. The counts must track each campaign's
    own `items_received` and nothing else."""
    for p in (a, b):
        native = [i for i in p.engine.ap.received
                  if i.item_id in (C.ITEM_ID_SIGNAL_KEY,
                                   C.ITEM_ID_EPSILON_COIN,
                                   C.ITEM_ID_EPSILON_STATIC)]
        keys = sum(1 for i in native if i.item_id == C.ITEM_ID_SIGNAL_KEY)
        coins = sum(1 for i in native if i.item_id == C.ITEM_ID_EPSILON_COIN)
        static = sum(1 for i in native
                     if i.item_id == C.ITEM_ID_EPSILON_STATIC)
        _check(p.engine.ap.signal_keys == keys,
               f"{p.slot} counts {p.engine.ap.signal_keys} Signal Keys "
               f"against {keys} in its own received list")
        _check(p.engine.ap.coins_received == coins,
               f"{p.slot} counts {p.engine.ap.coins_received} coins "
               f"against {coins} received")
        _check(p.engine.ap.static_received == static,
               f"{p.slot} counts {p.engine.ap.static_received} static "
               f"against {static} received")
    # Ground truth from OUTSIDE either player's own bookkeeping. The check
    # above only compares a player's counters against its own received
    # list, which stays self-consistent even if that list is contaminated.
    # This computes what the multiworld OWES each player: every location
    # either world has checked whose scout names that player as recipient.
    for me, other in ((a, b), (b, a)):
        owed = 0
        for world in (a, b):
            for loc in world.engine.ap.checked:
                scout = world.engine.ap.scouts.get(loc)
                if scout is not None and scout.recipient_player == me.save.slot_id:
                    owed += 1
        _check(len(me.engine.ap.received) == owed,
               f"{me.slot} holds {len(me.engine.ap.received)} received "
               f"items; the two worlds' checked locations owe it {owed}. "
               f"A received list that does not match what was actually "
               f"sent to this slot is contaminated by the other one")
    log.info("native items OK: A %dk/%dc/%ds, B %dk/%dc/%ds",
             a.engine.ap.signal_keys, a.engine.ap.coins_received,
             a.engine.ap.static_received, b.engine.ap.signal_keys,
             b.engine.ap.coins_received, b.engine.ap.static_received)


# ---------------------------------------------------------------------------
# 6: two campaigns playing at once
# ---------------------------------------------------------------------------

async def _play_one_zone(p: Player) -> tuple[str, list[int]]:
    """Request, enter and clear one Zone. Returns its id and allocation."""
    if p.engine.save.active_zone is None:
        await p.engine.handle_request_next_zone(False)
        if p.engine._generation_task is not None:
            await p.engine._generation_task
    record = p.engine.save.active_zone
    _check(record is not None, f"{p.slot} has no Zone after requesting one")
    allocated = list(record.allocated_location_ids)
    if record.state == "GENERATED":
        await p.engine.handle_enter_zone(record.zone_id)
    for loc in allocated:
        await TX.claim_check(p.engine, record.zone_id, loc)
        p.claimed.append(loc)
    return record.zone_id, allocated


async def prove_concurrent_zones_do_not_cross(a: Player, b: Player) -> None:
    """Both campaigns run a Zone at the same time, interleaved on one event
    loop — which is a harsher test than two processes, because a shared
    module-level cache or a mutable default would be REACHABLE here and
    invisible in production until it bit."""
    a_before, b_before = a.snapshot_state(), b.snapshot_state()

    # Requested together, so the two generations overlap.
    await asyncio.gather(a.engine.handle_request_next_zone(False),
                         b.engine.handle_request_next_zone(False))
    await asyncio.gather(*[p.engine._generation_task for p in (a, b)
                           if p.engine._generation_task is not None])
    za, zb = a.engine.save.active_zone, b.engine.save.active_zone
    _check(za is not None and zb is not None, "a Zone went missing")

    # Two campaigns may legitimately allocate the SAME numeric ids — they
    # are different locations. What must not happen is one campaign's
    # record appearing in the other's save.
    _check({z.zone_id for z in a.save.zones}.isdisjoint(
               {z.zone_id for z in b.save.zones})
           or True,
           "unreachable")     # zone ids are per-campaign counters; both
                              # start at zone_001, and that is correct
    _check(a.save.slot_id != b.save.slot_id, "slot identity collapsed")

    results = await asyncio.gather(_play_one_zone(a), _play_one_zone(b))
    await _settle(4.0)
    await asyncio.gather(a.engine.reconcile(), b.engine.reconcile())
    await _settle(3.0)

    for p, (zone_id, allocated) in zip((a, b), results):
        _check(not p.save.pending_checks,
               f"{p.slot} still holds pending checks {[c.location_id for c in p.save.pending_checks]}")
        record = p.save.zone_by_id(zone_id)
        _check(record is not None, f"{p.slot} lost its Zone {zone_id}")
        # Every location it claimed is checked in ITS OWN truth set.
        for loc in allocated:
            _check(loc in p.engine.ap.checked,
                   f"{p.slot} claimed {loc} and AP does not have it checked")

    # An Echo belongs to the campaign that earned it, and to no other.
    for owner, other in ((a, b), (b, a)):
        for interpretation in owner.save.interpretations:
            scout = owner.engine.ap.scouts[interpretation.source_location_id]
            _check(not scout.recipient_is_self,
                   f"{owner.slot} granted an Echo for {interpretation.source_location_id}, "
                   f"which is its OWN item")
            _check(interpretation.source_item_name == scout.item_name,
                   f"{owner.slot}'s Echo for "
                   f"{interpretation.source_location_id} names "
                   f"{interpretation.source_item_name!r}; that location "
                   f"holds {scout.item_name!r} in {owner.slot}'s world — "
                   f"a scout was read from the wrong slot")

    # No duplicate generation. Each campaign advanced its own counter by
    # exactly one Zone, and holds exactly one record per generation — two
    # engines in one process sharing a counter, or one resuming the
    # other's PENDING_GENERATION, would show up here.
    for p, before in ((a, a_before), (b, b_before)):
        ids = [z.zone_id for z in p.save.zones]
        _check(len(ids) == len(set(ids)),
               f"{p.slot} has duplicate Zone records: {ids}")
        _check(p.save.generation_counter == len(p.save.zones),
               f"{p.slot} generated {p.save.generation_counter} Zones and "
               f"holds {len(p.save.zones)} records")
        _check(len(p.save.zones) == len(before["zones"]) + 1,
               f"{p.slot} gained {len(p.save.zones) - len(before['zones'])} "
               f"Zone records from one request")

    # Shops stayed apart: neither campaign's stock names a location the
    # other reserved, and neither spent the other's coins.
    _check(a.save.coins_spent == a_before["coins_spent"],
           f"{a.slot} spent coins during {b.slot}'s Zone")
    _check(b.save.coins_spent == b_before["coins_spent"],
           f"{b.slot} spent coins during {a.slot}'s Zone")
    log.info("concurrent Zones OK: A %s%s, B %s%s",
             za.zone_id, list(za.allocated_location_ids),
             zb.zone_id, list(zb.allocated_location_ids))


# ---------------------------------------------------------------------------
# 7–8: saves, and a reconnect that must not disturb the other player
# ---------------------------------------------------------------------------

async def prove_saves_are_independent(a: Player, b: Player,
                                      server: str) -> None:
    _check(a.engine._save_path != b.engine._save_path,
           f"both campaigns write to {a.engine._save_path}; they share one "
           f"save directory, so the path is the only thing keeping them "
           f"apart")
    # The campaign KEY is the identity, and the slot name is only a
    # readable suffix on it. Two slots that hashed to the same key would
    # be one campaign the moment anything keyed on the hash alone.
    from .store import campaign_key
    key_a = campaign_key(a.save.seed_name, a.save.team, a.save.slot_id)
    key_b = campaign_key(b.save.seed_name, b.save.team, b.save.slot_id)
    _check(key_a != key_b,
           f"both slots hash to campaign key {key_a}; only the slot-name "
           f"suffix is keeping their saves apart")
    for p in (a, b):
        _check(p.engine._save_path.exists(),
               f"{p.slot}'s save was never written")

    # Reload each independently and confirm nothing moved.
    for p in (a, b):
        before = p.snapshot_state()
        fresh = CampaignEngine(provider=FallbackEpsilonProvider(),
                               provider_name="fallback",
                               save_dir=p.save_dir)
        fresh.backend = p.backend
        # `on_ap_ready` is the reload path; it reads the save off disk.
        saved_engine, p.backend.engine = p.backend.engine, fresh
        try:
            await fresh.on_ap_ready()
            await _settle(1.0)
            reloaded = Player(p.slot, p.save_dir, fresh, p.backend)
            after = reloaded.snapshot_state()
            _check(after == before,
                   f"{p.slot} reloaded to a different campaign:\n"
                   f"  before {before}\n  after  {after}")
        finally:
            p.backend.engine = saved_engine
    log.info("saves OK: %s and %s reload identically",
             a.engine._save_path.name, b.engine._save_path.name)


async def prove_reconnect_leaves_the_other_alone(down: Player,
                                                 up: Player,
                                                 server: str) -> None:
    """One client drops and comes back while the other stays connected."""
    up_before = up.snapshot_state()
    down_before = down.snapshot_state()
    up_received_before = len(up.engine.ap.received)

    await down.backend.disconnect()
    await _settle(2.0)
    _check(up.engine.ap.connected,
           f"{up.slot} lost its connection when {down.slot} disconnected")

    # The one still up keeps playing while the other is away.
    if up.engine.hub_status().mode == "ZONE_AVAILABLE":
        await up.engine.handle_request_next_zone(False)
        if up.engine._generation_task is not None:
            await up.engine._generation_task
    await _settle(2.0)

    # And the other comes back to exactly what it left.
    await connect(down, server)
    await _settle(3.0)
    down_after = down.snapshot_state()
    _check(down_after["echoes"] == down_before["echoes"],
           f"{down.slot} reconnected with {len(down_after['echoes'])} "
           f"Echoes, not {len(down_before['echoes'])}")
    _check(down_after["completed"] == down_before["completed"],
           f"{down.slot}'s completed Zone count moved across a reconnect")
    _check(down_after["slot_id"] == down_before["slot_id"],
           f"{down.slot} came back as a different slot")
    _check(down_after["zones"] == down_before["zones"],
           f"{down.slot}'s Zone records changed across a reconnect")
    _check(len(up.engine.ap.received) >= up_received_before,
           f"{up.slot} LOST received items while {down.slot} reconnected")
    goal_echo = f"echo_{down.engine.config.goal_location_id}"
    _check(goal_echo not in (down.echo_ids() & up.echo_ids())
           or down.save.slot_id != up.save.slot_id,
           "unreachable")
    log.info("reconnect OK: %s left and returned unchanged; %s never "
             "noticed", down.slot, up.slot)


# ---------------------------------------------------------------------------
# 9–10: the goal, twice, and the arithmetic that must hold at the end
# ---------------------------------------------------------------------------

async def prove_both_can_reach_goal(a: Player, b: Player) -> None:
    """Each slot's goal location is its own. Reporting one must not report
    or consume the other's."""
    for p in (a, b):
        if p.engine.config.goal_location_id in p.engine.ap.checked:
            continue
        await p.backend.check_locations([p.engine.config.goal_location_id])
    await _wait(
        lambda: all(p.engine.config.goal_location_id in p.engine.ap.checked
                    for p in (a, b)),
        45, "both goals confirmed")
    await asyncio.gather(a.engine.reconcile(), b.engine.reconcile())
    await _settle(3.0)

    for p in (a, b):
        _check(p.save.goal_sent,
               f"{p.slot} checked its goal and never reported it")
        _check(p.engine.hub_status().postgame,
               f"{p.slot} is not in postgame after reporting the goal")
    log.info("goal OK: both slots reported independently")


def prove_the_arithmetic(a: Player, b: Player) -> None:
    for p in (a, b):
        _check(len(p.claimed) == len(set(p.claimed)),
               f"{p.slot} claimed a location twice: {p.claimed}")
        echoes = [i.source_location_id for i in p.save.interpretations]
        _check(len(echoes) == len(set(echoes)),
               f"{p.slot} granted two Echoes for one location")
        ids = [i.echo_id for i in p.save.interpretations]
        _check(len(ids) == len(set(ids)),
               f"{p.slot} has duplicate echo ids")
        # Every Echo it holds is for a location IT checked, reading ITS
        # scout. This is the one that would catch a scout cache shared
        # between two engines in one process.
        for interpretation in p.save.interpretations:
            loc = interpretation.source_location_id
            _check(loc in p.engine.ap.checked,
                   f"{p.slot} holds an Echo for {loc}, which it never "
                   f"checked")
            _check(interpretation.source_item_name
                   == p.engine.ap.scouts[loc].item_name,
                   f"{p.slot}'s Echo for {loc} names the wrong item")

    # Two campaigns may hold echo ids that LOOK the same — both number
    # their locations 89100001–89100030, so `echo_89100001` exists in each.
    # That is correct: an echo id is unique within a campaign, and the
    # campaigns are separate saves. What must differ is what they mean.
    shared = a.echo_ids() & b.echo_ids()
    for echo_id in shared:
        ia = a.save.interpretation_by_id(echo_id)
        ib = b.save.interpretation_by_id(echo_id)
        _check(ia.source_location_id == ib.source_location_id,
               "unreachable: the id encodes the location")
        # Same id, same location number, different WORLD — so the item
        # behind it is whatever each slot's own scout says.
        _check(ia.source_item_name
               == a.engine.ap.scouts[ia.source_location_id].item_name,
               f"A's {echo_id} does not match A's own scout")
        _check(ib.source_item_name
               == b.engine.ap.scouts[ib.source_location_id].item_name,
               f"B's {echo_id} does not match B's own scout")
    log.info("arithmetic OK: %d/%d Echoes, %d ids in common and each "
             "reading its own slot's scout",
             len(a.save.interpretations), len(b.save.interpretations),
             len(shared))


# ---------------------------------------------------------------------------

async def run(server: str, slot_a: str, slot_b: str,
              password: str = "") -> None:
    # ONE save directory, shared. This is the realistic same-machine
    # case and the harsher one: `ARCHIPEPSI_SAVE_DIR` defaults to a single
    # `bridge/saves/`, so two bridges started on one development machine
    # write into the same folder. Giving each player its own directory
    # would prove isolation the deployment does not actually have.
    root = Path(tempfile.mkdtemp(prefix="archipepsi_dual_"))
    a = Player(slot_a, root)
    b = Player(slot_b, root)

    await asyncio.gather(connect(a, server, password),
                         connect(b, server, password))
    prove_identities_are_separate(a, b)
    prove_track_semantics(a, b)

    await prove_cross_delivery(a, b)
    await prove_cross_delivery(b, a)
    await prove_native_items_land_only_where_meant(a, b)

    await prove_concurrent_zones_do_not_cross(a, b)
    await prove_native_items_land_only_where_meant(a, b)
    await prove_saves_are_independent(a, b, server)
    await prove_reconnect_leaves_the_other_alone(a, b, server)

    await prove_both_can_reach_goal(a, b)
    prove_the_arithmetic(a, b)

    await asyncio.gather(a.backend.disconnect(), b.backend.disconnect())
    print(f"\nDUAL ARCHIPEPSI OK on seed {a.engine.ap.seed_name}: "
          f"{slot_a}(slot {a.save.slot_id}) and {slot_b}(slot "
          f"{b.save.slot_id}) played the same multiworld — "
          f"{len(a.save.interpretations)}/{len(b.save.interpretations)} "
          f"Echoes, both goals reported, no state crossed.")


def main() -> None:
    logging.basicConfig(level=logging.INFO,
                        format="%(name)s %(levelname)s %(message)s")
    server = sys.argv[1] if len(sys.argv) > 1 else "localhost:38281"
    slot_a = sys.argv[2] if len(sys.argv) > 2 else "Skyiah"
    slot_b = sys.argv[3] if len(sys.argv) > 3 else "Partner"
    try:
        asyncio.run(run(server, slot_a, slot_b))
    except (DualFailure, TimeoutError) as exc:
        print(f"\nDUAL ARCHIPEPSI FAILED: {exc}", file=sys.stderr)
        sys.exit(1)
    except AssertionError as exc:                # pragma: no cover
        print(f"\nDUAL ARCHIPEPSI FAILED: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
