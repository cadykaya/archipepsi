"""H-QUALIFY at the grant (Dess's note D-5; Prod's half of D-02).

`schemas/featured.py` states what a featured Check's Echo must supply.
This is where the grant holds a real Echo to it, through the one pipeline
every Echo takes:

  told          the provider's request carries the function
                (`required_function`); no other Check's does;
  enforced      an Echo that misses it -- an enemy pull -- is refused,
                repaired once, then replaced by the requirement's own
                Echo, which supplies it;
  kept          a provider's Echo that supplies it is kept as written;
  either way    the same for the player's own original (D-01) and for a
                foreign one: the requirement is read off the Zone, never
                off the recipient;
  elsewhere     the same enemy pull on a Check no Zone features is
                accepted -- which is what makes the refusal above the
                featured check's, and not some other rule's.

The Zone is built through the real transitions and the Check is claimed
through the real transaction, so the grant is the one the game makes.
"""
from __future__ import annotations

import pytest

from archipepsi_bridge import topology, transactions
from archipepsi_bridge.epsilon.base import reading_errors
from archipepsi_bridge.schemas import featured as F
from archipepsi_bridge.schemas import transitions as T

from .conftest import Collector, connected_engine, drain, run
from .test_featured_acquisition import _arena, _featured, _zone

REQ = F.FEATURED_REQUIREMENTS["grapple"]

ENEMY_PULL = {"type": "grapple_pull_target", "range": 20.0,
              "pull_force": 18.0, "max_target_hp": 30.0}
DECK_GRAPPLE = {"type": "grapple_to_surface", "range": 22.0,
                "pull_force": 16.0}


def _answer(request, primitive: dict, name: str,
            component_id: str | None = None) -> dict:
    """A provider's Echo for this request: valid in every other respect,
    so the only thing that can refuse it is what it supplies."""
    cid = component_id or f"act_{name.lower()}_{request.source.location_id}"
    return {
        "echo_id": request.required_echo_id, "interpretation_seq": 0,
        "source_location_id": request.source.location_id,
        "source_item_name": request.source.item_name,
        "source_game": request.source.source_game,
        "source_recipient_name": request.source.recipient_name,
        "display_name": name, "description": "It reaches and pulls.",
        "concepts": ["reach", "pull"],
        "operations": [{"op": "create", "component": {
            "kind": "action", "component_id": cid,
            "display_name": name, "description": "It reaches and pulls.",
            "slot": "mobility", "cooldown": 1.5,
            "primitive": primitive, "modifiers": []}}]}


class AnsweringProvider:
    """Answers every Echo request with one primitive, and records what it
    was asked, including the repair round's errors."""

    name = "mock"

    def __init__(self, primitive: dict, answer_name: str,
                 component_id: str | None = None):
        self.primitive = primitive
        self.answer_name = answer_name
        self.component_id = component_id
        self.requests: list = []
        self.repairs: list = []

    async def generate_zone(self, request, *, repair_errors=None):
        return {}

    async def generate_echo(self, request, *, repair_errors=None):
        self.requests.append(request)
        if repair_errors is not None:
            self.repairs.append(tuple(repair_errors))
        return _answer(request, self.primitive, self.answer_name,
                       self.component_id)


async def _featured_campaign(tmp_path, own: bool, provider=None,
                             provider_name="mock"):
    """A new campaign whose first Zone features one of its Checks: the
    player's own (`own`) or a foreign one. Returns the engine, the Zone,
    the featured Check and two Checks in the same Zone that are not."""
    engine, _ = await connected_engine(tmp_path, provider=provider)
    engine.provider_name = provider_name
    goal = engine.config.goal_location_id
    scouts = engine.ap.scouts
    featured = min(l for l, s in scouts.items()
                   if s.recipient_is_self == own and l != goal)
    plain, other = sorted(l for l in scouts
                          if l not in (featured, goal))[:2]
    zone = _zone(_featured(location_id=featured),
                 chambers=[_arena("c001", plain), _arena("c002", other),
                           _arena("c005", featured)])
    built = topology.apply(zone, topology.compose_chain(list(zone.chambers)))
    save = T.start_generation(engine.save, zone_id=built.zone_id,
                              allocated_location_ids=(plain, other,
                                                      featured),
                              target_game=built.target_game)
    save = T.accept_zone(save, built)
    save = T.enter_zone(save, built.zone_id)
    engine._apply(T.commit_layout(save, built.zone_id,
                                  {"manifest_digest": "d0"}))
    return engine, built.zone_id, featured, plain, other


async def _claim(engine, zone_id, loc):
    log = engine.save.interpretations
    seq = engine.save.next_interpretation_seq
    await transactions.claim_check(engine, zone_id, loc)
    await drain()
    return log, seq, engine.save.interpretation_by_id(f"echo_{loc}")


def test_the_provider_is_told_the_function_and_only_for_that_check(tmp_path):
    async def go():
        provider = AnsweringProvider(DECK_GRAPPLE, "Longshot")
        engine, zone_id, featured, plain, _ = await _featured_campaign(
            tmp_path, own=False, provider=provider)
        await _claim(engine, zone_id, plain)
        await _claim(engine, zone_id, featured)
        told = {r.source.location_id: r.required_function
                for r in provider.requests}
        assert told == {plain: None, featured: REQ.describe()}, told
        # What the provider reads is the serialised request: the key is
        # absent from every other Check's, so its input is unchanged.
        dumped = {r.source.location_id: r.model_dump(mode="json")
                  for r in provider.requests}
        assert "required_function" not in dumped[plain]
        assert dumped[featured]["required_function"] == REQ.describe()
    run(go())


@pytest.mark.parametrize("own", [True, False], ids=["own", "foreign"])
def test_an_enemy_pull_is_replaced_by_the_requirements_own_echo(tmp_path,
                                                                 own):
    async def go():
        provider = AnsweringProvider(ENEMY_PULL, "Yank")
        engine, zone_id, featured, _, _ = await _featured_campaign(
            tmp_path, own=own, provider=provider)
        seen = Collector(engine)
        log, seq, echo = await _claim(engine, zone_id, featured)
        assert echo is not None, "the featured Check yielded no Echo"
        assert F.check(log, echo, REQ, seq) == [], \
            "the featured Echo does not supply the requirement"
        components = [op.component.component_id for op in echo.operations
                      if op.op == "create"]
        assert components == [f"act_featured_{featured}"], components
        assert len(provider.requests) == 2, "asked once, repaired once"
        assert any("must supply grapple_to_surface" in e
                   for e in provider.repairs[0]), provider.repairs
        assert seen.notifications("fallback_used"), \
            "the substitution went unannounced"
        assert echo.concepts, "the requirement's Echo reads as nothing"
    run(go())


@pytest.mark.parametrize("own", [True, False], ids=["own", "foreign"])
def test_an_echo_that_supplies_it_is_kept_as_written(tmp_path, own):
    async def go():
        provider = AnsweringProvider(DECK_GRAPPLE, "Longshot")
        engine, zone_id, featured, _, _ = await _featured_campaign(
            tmp_path, own=own, provider=provider)
        seen = Collector(engine)
        log, seq, echo = await _claim(engine, zone_id, featured)
        assert echo is not None and echo.display_name == "Longshot"
        assert F.check(log, echo, REQ, seq) == []
        assert len(provider.requests) == 1 and not provider.repairs
        assert not seen.notifications("fallback_used")
    run(go())


def test_the_same_enemy_pull_elsewhere_is_accepted(tmp_path):
    """The control: nothing else refuses this Echo."""
    async def go():
        provider = AnsweringProvider(ENEMY_PULL, "Yank")
        engine, zone_id, _, plain, _ = await _featured_campaign(
            tmp_path, own=False, provider=provider)
        _, _, echo = await _claim(engine, zone_id, plain)
        assert echo is not None and echo.display_name == "Yank"
        assert len(provider.requests) == 1 and not provider.repairs
    run(go())


@pytest.mark.parametrize("own", [True, False], ids=["own", "foreign"])
def test_the_fallback_provider_still_hands_over_a_working_grapple(tmp_path,
                                                                  own):
    """`--epsilon=fallback`: the item's own heuristics need not reach the
    deck, so the requirement's Echo takes their place."""
    async def go():
        engine, zone_id, featured, _, _ = await _featured_campaign(
            tmp_path, own=own, provider_name="fallback")
        log, seq, echo = await _claim(engine, zone_id, featured)
        assert echo is not None
        assert F.check(log, echo, REQ, seq) == []
    run(go())


def test_the_requirements_echo_reads_as_its_item(tmp_path):
    """D05-F1: `fallback_interpretation` carries no concepts, and the
    pipeline refuses an Echo without them -- so unlabelled, the one
    fallback that must always hold would raise. It is labelled as every
    deterministic Echo is."""
    from archipepsi_bridge.epsilon.fallback import featured_fallback

    async def go():
        engine, _, featured, _, _ = await _featured_campaign(
            tmp_path, own=True)
        request = engine._echo_request(featured,
                                       required_function=REQ.describe())
        bare = F.fallback_interpretation(
            REQ, location_id=featured,
            item_name=request.source.item_name,
            source_game=request.source.source_game,
            recipient_name=request.source.recipient_name)
        assert reading_errors(bare, request), \
            "the requirement's Echo now carries concepts; drop the label"
        labelled = F.EchoInterpretation.model_validate(
            featured_fallback(REQ, request))
        assert reading_errors(labelled, request) == []
        assert labelled.operations == bare.operations, \
            "labelling changed what the Echo does"
    run(go())


def test_an_echo_that_would_not_fold_is_repaired_never_appended(tmp_path):
    """D05-F2. The provider answers two Checks with one component id. The
    second Echo would not fold ("already exists"), and every other check
    passed it: the append raised mid-grant, leaving a confirmed Check
    with no Echo, again at every sweep. Now it is refused, repaired, and
    replaced by the fallback."""
    async def go():
        provider = AnsweringProvider(DECK_GRAPPLE, "Hook",
                                     component_id="act_hook")
        engine, zone_id, _, plain, other = await _featured_campaign(
            tmp_path, own=False, provider=provider)
        _, _, first = await _claim(engine, zone_id, plain)
        assert first is not None and first.display_name == "Hook"
        seen = Collector(engine)
        _, _, second = await _claim(engine, zone_id, other)
        assert second is not None, "the second Check yielded no Echo"
        assert second.display_name != "Hook", "the duplicate was appended"
        assert any("does not fold" in e for e in provider.repairs[0]), \
            provider.repairs
        assert seen.notifications("fallback_used")
        assert [i.echo_id for i in engine.save.interpretations] == [
            f"echo_{plain}", f"echo_{other}"]
    run(go())
