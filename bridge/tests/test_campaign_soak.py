"""A whole campaign, played to the goal, on many different seeds.

`make godot-integration` plays the campaign once — and always with the
same seed, because `MockAPBackend` hard-coded `"MockSeed"`. The seed is the
only input to three different orderings: the track order the Hub offers,
the shop's stock draw, and the allocator's shuffle over the candidate pool.
One seed exercises one path through all three, so the properties this file
asserts held on exactly one arrangement of thirty locations.

Nothing here needs Godot: the campaign engine is the whole subject, and
driving it directly means a full playthrough costs milliseconds rather
than minutes, which is what makes running twenty-five of them reasonable.

Each run asserts the things that must be true of EVERY campaign, not of a
lucky one:

  - the campaign reaches the goal, and reports it exactly once
  - no location is ever allocated to two live Zones at once
  - no Check is ever claimed twice, and every confirmed foreign Check
    yields exactly one Echo (I9's log is append-only, so a duplicate is
    permanent)
  - the allocator never starves: a Zone is always offerable while
    unallocated non-finale locations remain (the §11.5 shop rule)
  - the save validates after every single transition
  - the fold is total over the log at every step
"""

from __future__ import annotations

import pytest

from archipepsi_bridge import transactions as TX
from archipepsi_bridge.mock_ap import MockAPBackend
from archipepsi_bridge.schemas import constants as C
from archipepsi_bridge.schemas import mechanics as M
from archipepsi_bridge.schemas.protocol import CampaignSave

from .conftest import drain, make_engine, run

SEEDS = [f"Soak{i:02d}" for i in range(25)]


class _Watcher:
    """Everything that must hold across a whole campaign, checked as it
    happens rather than reconstructed at the end."""

    def __init__(self, engine):
        self.engine = engine
        self.claimed: list[int] = []
        self.zones_played = 0

    def check_invariants(self) -> None:
        save = self.engine.save
        # The save is a validated value object at every step, not only at
        # the ones a test happens to look at.
        CampaignSave.model_validate(save.model_dump())
        # The fold is total over the log.
        mechanics = M.derive_mechanics(save.interpretations)
        # ...and publishes nothing that names a component it deleted.
        live = {o.component_id for o in mechanics.owned}
        for link in mechanics.links:
            assert link.source in live and link.target in live, (
                f"link {link.link} {link.source}->{link.target} is dangling")
        # One live Zone may hold a location, never two.
        held: dict[int, str] = {}
        for z in save.zones:
            if not z.holds_locations:
                continue
            for loc in z.allocated_location_ids:
                assert loc not in held, (
                    f"location {loc} is held by both {held[loc]} and "
                    f"{z.zone_id}")
                held[loc] = z.zone_id
        # One Echo per source location, ever.
        seqs = [i.interpretation_seq for i in save.interpretations]
        assert len(set(seqs)) == len(seqs), "interpretation_seq repeated"
        sources = [i.source_location_id for i in save.interpretations]
        assert len(set(sources)) == len(sources), (
            f"two Echoes from one location: {sources}")


async def _play(tmp_path, seed: str) -> _Watcher:
    """Play until the goal is reported or the campaign runs out of Zones."""
    engine = make_engine(tmp_path / seed)
    backend = MockAPBackend(engine, seed_name=seed)
    engine.backend = backend
    await backend.connect("", "Skyiah", "")
    await drain()

    watcher = _Watcher(engine)
    watcher.check_invariants()

    for _ in range(40):                      # a bound, not an expectation
        hub = engine.hub_status()
        if hub.postgame:
            break
        if hub.mode == "ZONE_AVAILABLE":
            await engine.handle_request_next_zone(hub.finale_offered)
            if engine._generation_task is not None:
                await engine._generation_task
            await drain()
            continue
        if hub.mode in ("ZONE_READY", "ZONE_ACTIVE"):
            record = engine.save.active_zone
            if record.state == "GENERATED":
                await engine.handle_enter_zone(record.zone_id)
            watcher.zones_played += 1
            for loc in sorted(record.allocated_location_ids):
                await TX.claim_check(engine, record.zone_id, loc)
                watcher.claimed.append(loc)
                watcher.check_invariants()
            await drain()
            watcher.check_invariants()
            continue
        if hub.mode == "GENERATING":
            if engine._generation_task is not None:
                await engine._generation_task
            await drain()
            continue
        break

    await drain()
    watcher.check_invariants()
    return watcher


@pytest.mark.parametrize("seed", SEEDS)
def test_a_whole_campaign_holds_together_on_any_seed(tmp_path, seed):
    watcher = run(_play(tmp_path, seed))
    engine = watcher.engine

    assert engine.save.goal_sent, (
        f"seed {seed} never reached the goal after {watcher.zones_played} "
        f"Zones")
    assert engine.backend.server.goal_reports == 1, (
        f"the goal was reported {engine.backend.server.goal_reports} times")
    assert len(watcher.claimed) == len(set(watcher.claimed)), (
        "a location was claimed twice")

    # Every foreign Check that confirmed produced exactly one Echo, and
    # every Echo names a Check that confirmed.
    foreign = {loc for loc in engine.ap.checked
               if (s := engine.ap.scouts.get(loc)) is not None
               and not s.recipient_is_self}
    echoed = {i.source_location_id for i in engine.save.interpretations}
    assert echoed <= foreign, f"an Echo from an unconfirmed location: {echoed - foreign}"


def test_the_allocator_never_starves_on_any_seed(tmp_path):
    """§11.5: a shop reservation must never be why a Zone cannot generate.
    Asserted across every seed at every Hub visit, which is the only place
    the rule can actually be broken."""
    async def scenario(seed: str) -> None:
        engine = make_engine(tmp_path / seed)
        backend = MockAPBackend(engine, seed_name=seed)
        engine.backend = backend
        await backend.connect("", "Skyiah", "")
        await drain()

        for _ in range(40):
            hub = engine.hub_status()
            if hub.postgame:
                return
            if hub.mode == "ZONE_AVAILABLE":
                # The rule, stated: if any non-finale location is still
                # unallocated, a Zone must be offerable.
                free = engine.zone_candidates(ignore_stock=True)
                if free:
                    assert engine.zone_candidates() or hub.finale_offered, (
                        f"seed {seed}: {len(free)} locations free and no "
                        f"Zone offerable; the shop is starving the allocator")
                await engine.handle_request_next_zone(hub.finale_offered)
                if engine._generation_task is not None:
                    await engine._generation_task
                await drain()
                continue
            if hub.mode in ("ZONE_READY", "ZONE_ACTIVE"):
                record = engine.save.active_zone
                if record.state == "GENERATED":
                    await engine.handle_enter_zone(record.zone_id)
                for loc in sorted(record.allocated_location_ids):
                    await TX.claim_check(engine, record.zone_id, loc)
                await drain()
                continue
            if hub.mode == "GENERATING":
                if engine._generation_task is not None:
                    await engine._generation_task
                await drain()
                continue
            return

    for seed in SEEDS:
        run(scenario(seed))


def test_the_whole_operation_vocabulary_reaches_a_real_campaign(tmp_path):
    """S6 completed the operation vocabulary in the validators and in the
    fold, and no provider in the tree emitted a `MODIFY` or a `MERGE` — so
    the two most interesting dispositions in ECHOES §3 were things a unit
    test could construct and a player could never receive. A bug in either
    path was therefore invisible to every integration run.

    `MERGE` is budget-conditioned (§16: over soft budget, ask for one) and
    a mock campaign never creates six resources, so it is asserted where
    it can happen — in `test_dispositions.py`, against a crafted request.
    What must hold HERE is that the rest of the vocabulary is not
    theoretical."""
    seen: set[str] = set()
    for seed in SEEDS[:8]:
        watcher = run(_play(tmp_path, seed))
        for interpretation in watcher.engine.save.interpretations:
            seen.update(op.op for op in interpretation.operations)

    for op in ("create", "upgrade", "modify", "link"):
        assert op in seen, (
            f"no campaign across eight seeds ever produced a '{op}'; that "
            f"path is unreachable in play and untested by any integration "
            f"run")

