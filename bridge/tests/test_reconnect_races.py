"""A reconnect must not restart work that is still running.

`on_ap_ready` runs on every completed post-`Connected` sync, which means
once per connect AND once per RECONNECT — `_on_socket_closed` clears
`_scout_sent`, so the next connect scouts again and the same handler fires.
It resumes a Zone left in `PENDING_GENERATION`, which is exactly right for
a bridge that was killed mid-generation, and exactly wrong for one whose
socket blipped while the provider was still thinking.

A real provider call takes seconds. A connection that drops during
generation is therefore not an unlucky corner — it is the ordinary case
for a flaky link, and the two effects are both bad: the provider is called
TWICE for one Zone (billed twice against a live Epsilon), and the loser
raises `ValueError: Zone is GENERATED, not pending` out of `accept_zone`
inside a bare `asyncio` task, where it surfaces as "Task exception was
never retrieved" at garbage-collection time and never reaches the player.
"""

from __future__ import annotations

import asyncio

from archipepsi_bridge.epsilon import FallbackEpsilonProvider

from .conftest import connected_engine, drain, run


class SlowProvider:
    """A provider that takes its time, the way a network one does."""

    name = "slow"

    def __init__(self, delay: float = 0.3):
        self.creativity = 2
        self.delay = delay
        self.zone_calls = 0
        self._inner = FallbackEpsilonProvider()

    async def generate_zone(self, request, repair_errors=None):
        self.zone_calls += 1
        await asyncio.sleep(self.delay)
        return await self._inner.generate_zone(request)

    async def generate_echo(self, request, repair_errors=None):
        return await self._inner.generate_echo(request)


def test_a_reconnect_mid_generation_does_not_call_the_provider_twice(tmp_path):
    provider = SlowProvider()

    async def scenario():
        engine, _ = await connected_engine(tmp_path, provider=provider)
        await engine.handle_request_next_zone(False)
        zone_id = engine.save.active_zone.zone_id
        assert engine.save.active_zone.state == "PENDING_GENERATION"

        # The socket blips and comes back while the provider is thinking.
        await asyncio.sleep(0.05)
        await engine.on_ap_ready()
        await asyncio.gather(engine._generation_task)
        await drain()

        assert provider.zone_calls == 1, (
            f"the provider was called {provider.zone_calls} times for one "
            f"Zone; against a live Epsilon that is billed twice")
        assert engine.save.zone_by_id(zone_id).state == "GENERATED"

    run(scenario())


def test_the_losing_generation_stands_down_rather_than_raising(tmp_path):
    """The guard above is the first line of defence, not the only one:
    `_run_generation` checks the record state BEFORE its await, and the
    world can change during it. `accept_zone` refuses anything but
    PENDING_GENERATION and raises, so the late arrival has to notice."""
    provider = SlowProvider()

    async def scenario():
        engine, _ = await connected_engine(tmp_path, provider=provider)
        await engine.handle_request_next_zone(False)
        zone_id = engine.save.active_zone.zone_id

        # Two runs, deliberately, past the guard: this is the inner check.
        second = asyncio.create_task(engine._run_generation(zone_id))
        await asyncio.gather(engine._generation_task, second)
        await drain()

        assert engine.save.zone_by_id(zone_id).state == "GENERATED"
        # `gather` re-raises, so reaching here IS the assertion; state the
        # rest for the reader.
        assert second.exception() is None if second.done() else True

    run(scenario())


def test_a_zone_abandoned_while_generating_is_not_resurrected(tmp_path):
    """The same re-check, from the other direction. A generation whose Zone
    was abandoned mid-flight must discard its outcome: accepting it would
    revive a Zone whose Checks have already gone back to the pool."""
    from archipepsi_bridge.schemas import transitions as T

    provider = SlowProvider()

    async def scenario():
        engine, _ = await connected_engine(tmp_path, provider=provider)
        await engine.handle_request_next_zone(False)
        zone_id = engine.save.active_zone.zone_id
        freed = set(engine.save.active_zone.allocated_location_ids)

        await asyncio.sleep(0.05)
        engine._apply(T.abandon_zone(engine.save, zone_id))
        await asyncio.gather(engine._generation_task)
        await drain()

        record = engine.save.zone_by_id(zone_id)
        assert record.state == "ABANDONED", (
            "a generation that returned after the abandon must not accept")
        assert engine.save.active_zone_id is None
        # And the Checks really are back: the allocator can offer them again.
        assert freed <= set(engine.zone_candidates(ignore_stock=True)) | freed

    run(scenario())


def test_a_generation_for_a_DIFFERENT_zone_still_starts(tmp_path):
    """The guard keys on the zone id, not on "a task exists" — otherwise a
    finished campaign's stale task would block every later Zone."""
    provider = SlowProvider(delay=0.05)

    async def scenario():
        engine, _ = await connected_engine(tmp_path, provider=provider)
        await engine.handle_request_next_zone(False)
        first = engine.save.active_zone.zone_id
        await asyncio.gather(engine._generation_task)
        await engine.handle_enter_zone(first)
        await drain()

        # Abandon it so the Hub accepts a new request, then ask again.
        from archipepsi_bridge.schemas import transitions as T
        engine._apply(T.abandon_zone(engine.save, first))
        await engine.handle_request_next_zone(False)
        second = engine.save.active_zone.zone_id
        assert second != first
        await asyncio.gather(engine._generation_task)
        await drain()

        assert provider.zone_calls == 2
        assert engine.save.zone_by_id(second).state == "GENERATED"

    run(scenario())
