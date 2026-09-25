"""D-01 -- a local Echo from the player's own original (Prod's half).

The contract is `docs/D14_SELF_ADDRESSED_ECHO_PROD.md`; its §6 lists
what lands with the integration, and each test below is one of those
lines. What the policy must never do (clone an item, mint twice, change
a legacy save) is pinned separately in `test_self_echo_boundaries.py`,
which this file does not repeat.

  created on    a new campaign is created with the policy on, and a
                reload keeps it;
  self          an own Check yields one Echo, `echo_<location_id>`, and
                its original is counted once, by AP alone;
  the card      "Delivered to you", then "EPSILON ECHO ACQUIRED" with the
                Echo's name and description, carrying the Echo's id so
                the reveal shows its effects;
  foreign       unchanged, card and all;
  retry         a failing provider falls back under the same id;
  reload        a crash before the append is granted once; an Echo
                already written is never asked for again;
  budget        an own Check confirmed elsewhere waits in the foreign
                queue: at most 3 per load.

The mock seed `MockSeed-3` puts one of this slot's own items (an Epsilon
Coin) in the first Zone; the default seed's first Zone holds none.
"""
from __future__ import annotations

import json

from archipepsi_bridge import transactions
from archipepsi_bridge.campaign import MAX_LAZY_ECHOES_PER_LOAD
from archipepsi_bridge.epsilon import FallbackEpsilonProvider
from archipepsi_bridge.mock_ap import SELF_SLOT, MockAPBackend, MockServerState
from archipepsi_bridge.schemas import constants as C
from archipepsi_bridge.schemas import protocol as P
from archipepsi_bridge.schemas import transitions as T

from .conftest import (Collector, ScriptedProvider, drain, enter_zone,
                       make_engine, run)

SELF_SEED = "MockSeed-3"
POLICY_FIELD = "self_addressed_echoes"


class CountingProvider:
    """The deterministic fallback, counting the Echoes it is asked for.

    A regenerated fallback Echo is identical to the first, so comparing
    the Echo cannot see a reroll. Counting the requests can."""

    name = "fallback"

    def __init__(self):
        self._inner = FallbackEpsilonProvider()
        self.asked: list[int] = []

    async def generate_zone(self, request, *, repair_errors=None):
        return await self._inner.generate_zone(
            request, repair_errors=repair_errors)

    async def generate_echo(self, request, *, repair_errors=None):
        self.asked.append(request.source.location_id)
        return await self._inner.generate_echo(
            request, repair_errors=repair_errors)


async def _connect(tmp_path, state=None, provider=None,
                   provider_name="fallback", seed=SELF_SEED):
    engine = make_engine(tmp_path, provider=provider,
                         provider_name=provider_name)
    backend = MockAPBackend(engine, seed_name=seed, server_state=state)
    engine.backend = backend
    await backend.connect("", "Skyiah", "")
    await drain()
    return engine, backend


async def _in_a_zone(tmp_path, state=None, provider=None,
                     provider_name="fallback"):
    engine, backend = await _connect(tmp_path, state, provider,
                                     provider_name)
    await engine.handle_request_next_zone(False)
    await drain()
    zone_id = engine.save.active_zone_id
    await enter_zone(engine, zone_id)
    return engine, backend, zone_id


def _own(engine, zone_id) -> int:
    locs = engine.save.zone_by_id(zone_id).allocated_location_ids
    mine = [l for l in locs if engine.ap.scouts[l].recipient_is_self]
    assert mine, "the mock seed placed no own item in this Zone"
    return mine[0]


def _foreign(engine, zone_id) -> int:
    locs = engine.save.zone_by_id(zone_id).allocated_location_ids
    return next(l for l in locs if not engine.ap.scouts[l].recipient_is_self)


def _originals(engine, loc) -> list[int]:
    """This Check's original among ReceivedItems: sent by this slot. The
    mock also has another player find one of ours on every confirmation,
    so a bare count of received items would measure the wrong thing."""
    item = engine.ap.scouts[loc].item_id
    return [r.ordinal for r in engine.ap.received
            if r.sender_player == SELF_SLOT and r.item_id == item]


def _counted_from_ap_alone(engine) -> bool:
    """Keys and coins are counted from ReceivedItems and nothing else."""
    ids = [r.item_id for r in engine.ap.received]
    return (engine.ap.signal_keys == ids.count(C.ITEM_ID_SIGNAL_KEY)
            and engine.ap.coins_received
            == ids.count(C.ITEM_ID_EPSILON_COIN))


def _cards(seen, loc) -> list:
    return [n for n in seen.of_type("notification")
            if n.location_id == loc
            and n.kind in ("check_confirmed", "reveal")]


def test_a_new_campaign_is_created_with_the_policy_on(tmp_path):
    async def go():
        state = MockServerState()
        engine, _ = await _connect(tmp_path, state)
        assert engine.save.self_addressed_echoes is True
        written = json.loads(engine._save_path.read_text())
        assert written[POLICY_FIELD] is True, "the save on disk has it off"
        again, _ = await _connect(tmp_path, state)
        assert again.save.self_addressed_echoes is True, \
            "a reload turned the policy off"
    run(go())


def test_an_own_check_yields_one_echo_and_its_original_once(tmp_path):
    async def go():
        state = MockServerState()
        engine, _, zone_id = await _in_a_zone(tmp_path, state)
        loc = _own(engine, zone_id)
        echo_id = f"echo_{loc}"
        before = _originals(engine, loc)
        await transactions.claim_check(engine, zone_id, loc)
        await drain()
        echo = engine.save.interpretation_by_id(echo_id)
        assert echo is not None, "the own Check yielded no Echo"
        assert echo.source_location_id == loc
        # Asked again, every way it can be: one Echo, no new sequence.
        seq = engine.save.next_interpretation_seq
        assert await engine.grant_echo(loc) == echo_id
        await engine.echo_backlog_sweep()
        engine._apply(T.append_interpretation(engine.save, echo))
        await drain()
        ids = [i.echo_id for i in engine.save.interpretations]
        assert ids.count(echo_id) == 1, "one Check minted two Echoes"
        assert engine.save.next_interpretation_seq == seq
        # The original: once, through AP, and nothing else counted.
        after = _originals(engine, loc)
        assert len(after) == len(before) + 1, (before, after)
        assert _counted_from_ap_alone(engine), \
            "a key or coin was counted from somewhere other than AP"
        again, _ = await _connect(tmp_path, state)
        assert _originals(again, loc) == after, "counted again on reload"
        assert _counted_from_ap_alone(again)
        assert [i.echo_id for i in again.save.interpretations].count(
            echo_id) == 1
    run(go())


def test_the_card_says_delivered_to_you_then_the_echo(tmp_path):
    async def go():
        engine, _, zone_id = await _in_a_zone(tmp_path)
        loc = _own(engine, zone_id)
        seen = Collector(engine)
        await transactions.claim_check(engine, zone_id, loc)
        await drain()
        echo = engine.save.interpretation_by_id(f"echo_{loc}")
        cards = _cards(seen, loc)
        assert len(cards) == 1, [c.kind for c in cards]
        card = cards[0]
        assert (card.kind, card.title) == ("check_confirmed",
                                           "CHECK CONFIRMED")
        assert card.lines == (
            engine.ap.scouts[loc].item_name, "Delivered to you.", "",
            "EPSILON ECHO ACQUIRED", echo.display_name, echo.description)
        # The reveal reads the Echo by this id to show what it does.
        assert card.echo_id == f"echo_{loc}"
    run(go())


def test_a_foreign_check_is_unchanged(tmp_path):
    async def go():
        engine, _, zone_id = await _in_a_zone(tmp_path)
        loc = _foreign(engine, zone_id)
        scout = engine.ap.scouts[loc]
        seen = Collector(engine)
        await transactions.claim_check(engine, zone_id, loc)
        await drain()
        echo = engine.save.interpretation_by_id(f"echo_{loc}")
        cards = _cards(seen, loc)
        assert len(cards) == 1
        card = cards[0]
        assert (card.kind, card.title) == (
            "reveal", f"SENT TO {scout.recipient_name.upper()}")
        assert card.lines == (scout.item_name, scout.recipient_game, "",
                              "EPSILON ECHO ACQUIRED", echo.display_name,
                              echo.description)
        assert card.echo_id == f"echo_{loc}"
    run(go())


def test_a_legacy_card_is_delivered_to_you_and_nothing_more(tmp_path):
    """The legacy half of the card. The mint half is pinned in
    `test_self_echo_boundaries.py`."""
    async def go():
        engine, _, zone_id = await _in_a_zone(tmp_path)
        raw = engine.save.model_dump(mode="json")
        raw.pop(POLICY_FIELD)
        engine._apply(P.CampaignSave.model_validate(raw))
        loc = _own(engine, zone_id)
        seen = Collector(engine)
        await transactions.claim_check(engine, zone_id, loc)
        await drain()
        cards = _cards(seen, loc)
        assert len(cards) == 1
        assert (cards[0].kind, cards[0].title, cards[0].lines) == (
            "check_confirmed", "CHECK CONFIRMED",
            (engine.ap.scouts[loc].item_name, "Delivered to you."))
        assert cards[0].echo_id is None
        assert engine.save.interpretation_by_id(f"echo_{loc}") is None
    run(go())


def test_a_failing_provider_falls_back_under_the_same_id(tmp_path):
    async def go():
        provider = ScriptedProvider()      # answers {} to everything
        engine, _, zone_id = await _in_a_zone(
            tmp_path, provider=provider, provider_name="mock")
        loc = _own(engine, zone_id)
        seen = Collector(engine)
        await transactions.claim_check(engine, zone_id, loc)
        await drain()
        echo = engine.save.interpretation_by_id(f"echo_{loc}")
        assert echo is not None, "no Echo, fallback or otherwise"
        assert provider.echo_calls >= 1, "the provider was never asked"
        assert seen.notifications("fallback_used"), \
            "the fallback went unannounced"
        cards = _cards(seen, loc)
        assert len(cards) == 1 and cards[0].echo_id == f"echo_{loc}"
        assert cards[0].lines[-2:] == (echo.display_name, echo.description)
        # Asking again returns the fallback Echo; the provider is not
        # asked for another.
        calls = provider.echo_calls
        assert await engine.grant_echo(loc) == f"echo_{loc}"
        assert provider.echo_calls == calls
    run(go())


def test_a_crash_before_the_append_is_granted_once_on_reload(tmp_path):
    async def go():
        state = MockServerState()
        engine, _, zone_id = await _in_a_zone(tmp_path, state)
        loc = _own(engine, zone_id)
        echo_id = f"echo_{loc}"
        await transactions.claim_check(engine, zone_id, loc)
        await drain()
        # The save as it was had the process died before the append.
        engine._apply(T._rebuild(engine.save, interpretations=tuple(
            i for i in engine.save.interpretations if i.echo_id != echo_id)))
        assert engine.save.interpretation_by_id(echo_id) is None
        provider = CountingProvider()
        again = make_engine(tmp_path, provider=provider)
        seen = Collector(again)
        backend = MockAPBackend(again, seed_name=SELF_SEED,
                                server_state=state)
        again.backend = backend
        await backend.connect("", "Skyiah", "")
        await drain()
        ids = [i.echo_id for i in again.save.interpretations]
        assert ids.count(echo_id) == 1, f"minted {ids.count(echo_id)} times"
        assert provider.asked.count(loc) == 1
        assert [n.echo_id for n in seen.notifications("echo_acquired")
                if n.location_id == loc] == [echo_id], \
            "the grant on reload went unannounced"
    run(go())


def test_a_written_echo_is_never_asked_for_again(tmp_path):
    async def go():
        state = MockServerState()
        engine, _, zone_id = await _in_a_zone(tmp_path, state)
        loc = _own(engine, zone_id)
        await transactions.claim_check(engine, zone_id, loc)
        await drain()
        first = engine.save.interpretation_by_id(f"echo_{loc}")
        seq = engine.save.next_interpretation_seq
        assert first is not None
        provider = CountingProvider()
        again = make_engine(tmp_path, provider=provider)
        backend = MockAPBackend(again, seed_name=SELF_SEED,
                                server_state=state)
        again.backend = backend
        await backend.connect("", "Skyiah", "")
        await drain()
        assert loc not in provider.asked, "a written Echo was rerolled"
        assert again.save.interpretation_by_id(f"echo_{loc}") == first
        assert again.save.next_interpretation_seq == seq
    run(go())


def test_own_checks_confirmed_elsewhere_wait_in_the_foreign_queue(tmp_path):
    """D14 §4: "The budget is the foreign one: interacted Checks now,
    others at most 3 per load." Own Checks the player never touched
    (confirmed by a release or another client) are the "others"."""
    async def go():
        state = MockServerState()
        engine, backend = await _connect(tmp_path, state)
        goal = engine.config.goal_location_id
        touched = engine._interacted_location_ids()
        elsewhere = sorted(
            l for l, s in engine.ap.scouts.items()
            if s.recipient_is_self and l != goal and l not in touched)
        assert len(elsewhere) > MAX_LAZY_ECHOES_PER_LOAD, elsewhere
        batch = elsewhere[:MAX_LAZY_ECHOES_PER_LOAD + 2]
        state.checked.update(batch)
        backend._sync_from_server()
        await engine.reconcile()
        await drain()

        def granted(e):
            return [l for l in batch
                    if e.save.interpretation_by_id(f"echo_{l}") is not None]

        assert len(granted(engine)) == MAX_LAZY_ECHOES_PER_LOAD, \
            granted(engine)
        again, _ = await _connect(tmp_path, state)
        assert granted(again) == batch, "the next load did not catch up"
    run(go())
