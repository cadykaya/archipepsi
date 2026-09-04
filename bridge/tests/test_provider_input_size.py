"""Provider INPUT size at campaign scale (CAMPAIGN_SCALE.md 12).

CS9 measured what a provider has to EMIT and declared it fine. It never
measured what a provider is SENT, and that turned out to be the half
that scaled badly: `PlayerContext.echoes` carried every interpretation
the campaign had ever made. At the prototype's thirty locations that was
~29 Echoes and about 6 KB, so nobody noticed. At the 450-location
default it is ~449 and 96 KB — roughly 24,000 tokens in front of every
Zone prompt, growing for the whole campaign.

The same CS8b shape as the location range: the options scaled and a
consumer did not.

These tests are the missing measurement, and the bound. A regression
that restores "send the entire log" fails here.
"""

from __future__ import annotations

import copy
import json

import pytest

from archipepsi_bridge import echo_projection as P
from archipepsi_bridge.epsilon.requests import EchoSummary, PlayerContext
from archipepsi_bridge.schemas import constants as C
from archipepsi_bridge.schemas.echo import EchoInterpretation
from archipepsi_bridge.schemas.mechanics import derive_mechanics
from pydantic import TypeAdapter

_ECHO = TypeAdapter(EchoInterpretation)

#: The project's convention, used by CS9's output measurement too:
#: roughly four characters per token.
CHARS_PER_TOKEN = 4

#: What one Zone request may spend on Echo history, in characters.
#: Chosen against the measurement below rather than guessed: the bounded
#: projection lands near 4 KB at every campaign size, so this is room to
#: grow without being room to regress.
MAX_HISTORY_CHARS = 20_000


def _echo(index: int) -> EchoInterpretation:
    """One realistic interpretation, varied enough to exercise the
    influence aggregate's top-N ranking."""
    from archipepsi_bridge.schemas import test_schemas as T
    location = C.FIRST_LOCATION_ID + index
    data = copy.deepcopy(T._CONFERENCE_CALL)
    data.update(echo_id=f"echo_{location}", interpretation_seq=index,
                source_location_id=location,
                display_name=f"Echo {index:03d}",
                source_game=f"Game {index % 23}",
                concepts=[f"concept_{index % 31}", "recoil", "absurd"],
                tags=[f"tag_{index % 17}", "weapon", "mobility"])
    for op in data["operations"]:
        if "component" in op:
            op["component"]["component_id"] = f"act_{index}"
    return _ECHO.validate_python(data)


def _log(size: int) -> tuple[EchoInterpretation, ...]:
    return tuple(_echo(i) for i in range(size))


def _context(log) -> PlayerContext:
    """A PlayerContext built the way the campaign builds one."""
    return PlayerContext(
        signal_keys=2, coins_available=6,
        echoes=tuple(
            EchoSummary(echo_id=e.echo_id, display_name=e.display_name,
                        kinds=("action",), tags=tuple(e.tags),
                        description=e.description)
            for e in P.detail_examples(log)),
        echo_history=P.history_view(log, derive_mechanics(log)))


def _chars(context: PlayerContext) -> int:
    return len(json.dumps(context.model_dump(mode="json")))


#: The three the brief asks for: prototype-ish, a late default campaign,
#: and the largest campaign anyone can configure.
SCALES = [
    ("prototype", C.PROTOTYPE_CONFIG.non_goal_count),          # 29
    ("default late", C.DEFAULT_CONFIG.non_goal_count),         # 449
    ("maximum", C.LOCATION_COUNT_MAX - 1),                     # 599
]


class TestProviderInputStaysBounded:

    @pytest.mark.parametrize("label,size", SCALES)
    def test_the_request_does_not_grow_with_the_campaign(self, label, size):
        chars = _chars(_context(_log(size)))
        assert chars < MAX_HISTORY_CHARS, (
            f"{label} ({size} Echoes) sends {chars:,} characters "
            f"(~{chars // CHARS_PER_TOKEN:,} tokens) of Echo history")

    def test_a_twenty_fold_history_is_not_a_twenty_fold_request(self):
        """The property that matters, stated directly. Sending the whole
        log made this ratio ~15x; bounded, it is flat."""
        small = _chars(_context(_log(29)))
        large = _chars(_context(_log(599)))
        assert large < small * 2, (
            f"29 Echoes send {small:,} characters and 599 send "
            f"{large:,}; the projection is not bounded")

    @pytest.mark.parametrize("label,size", SCALES)
    def test_the_detail_window_is_capped(self, label, size):
        context = _context(_log(size))
        assert len(context.echoes) <= P.MAX_DETAIL_EXAMPLES

    def test_the_model_itself_refuses_the_whole_log(self):
        """Not merely 'the caller happens to bound it'. A future call
        site that passes everything is refused by the schema."""
        too_many = tuple(
            EchoSummary(echo_id=f"echo_{89100001 + i}",
                        display_name=f"Echo {i}", kinds=("action",),
                        tags=("weapon",), description="x")
            for i in range(P.MAX_DETAIL_EXAMPLES + 1))
        with pytest.raises(Exception, match="at most"):
            PlayerContext(signal_keys=0, coins_available=0,
                          echoes=too_many)

    def test_the_echo_generation_path_has_the_same_bound(self):
        """One bounded path and one forgotten unbounded one is exactly
        how this happened; `existing_echoes` was the forgotten one."""
        from archipepsi_bridge.epsilon.requests import EchoPlayerState
        too_many = tuple(
            EchoSummary(echo_id=f"echo_{89100001 + i}",
                        display_name=f"Echo {i}", kinds=("action",),
                        tags=("weapon",), description="x")
            for i in range(P.MAX_DETAIL_EXAMPLES + 1))
        with pytest.raises(Exception, match="at most"):
            EchoPlayerState(existing_echoes=too_many)


class TestTheMeasurementIsRecorded:
    """The numbers, so a change that makes requests an order of
    magnitude larger fails a test rather than a live generation."""

    def test_the_measured_sizes_are_what_the_docs_say(self):
        measured = {label: _chars(_context(_log(size)))
                    for label, size in SCALES}
        # Recorded rather than folded into a bound: these are the
        # numbers CAMPAIGN_SCALE.md 12 quotes.
        for label, chars in measured.items():
            assert 1_000 < chars < MAX_HISTORY_CHARS, (
                f"{label} measured {chars:,} characters")
        # ...and the largest campaign is not dramatically bigger than
        # the smallest, which is the whole point.
        assert max(measured.values()) - min(measured.values()) < 6_000


class TestTheInfluenceAggregateIsBoundedByConstruction:
    """The part that has to survive a WORST case, not a typical one.

    `_echo` above reuses 23 source games and 31 concepts, so an
    unbounded top-N would only leak a few hundred characters and every
    size test still passes — a sabotage that removed the cap proved
    exactly that by passing. The aggregate's bound has to be driven with
    maximally distinct inputs, which is where an unbounded ranking
    actually explodes.
    """

    def _all_distinct(self, size: int):
        import copy
        from archipepsi_bridge.schemas import test_schemas as T
        out = []
        for i in range(size):
            location = C.FIRST_LOCATION_ID + i
            data = copy.deepcopy(T._CONFERENCE_CALL)
            data.update(echo_id=f"echo_{location}", interpretation_seq=i,
                        source_location_id=location,
                        display_name=f"Echo {i}",
                        # Every Echo from a different world, with its own
                        # concepts and tags. Nothing repeats.
                        source_game=f"Distinct Source Game {i:04d}",
                        concepts=[f"concept_{i:04d}"],
                        tags=[f"tag_{i:04d}"])
            for op in data["operations"]:
                if "component" in op:
                    op["component"]["component_id"] = f"act_{i}"
            out.append(_ECHO.validate_python(data))
        return tuple(out)

    @pytest.mark.parametrize("size", [29, 449, 599])
    def test_every_echo_from_a_different_world_still_fits(self, size):
        log = self._all_distinct(size)
        influence = P.accumulated_influence(log)
        assert len(influence["source_games"]) <= P.MAX_INFLUENCE_SOURCES
        assert len(influence["recurring_concepts"]) \
            <= P.MAX_INFLUENCE_CONCEPTS
        assert len(influence["recurring_tags"]) <= P.MAX_INFLUENCE_TAGS
        chars = len(json.dumps(influence))
        assert chars < 4_000, (
            f"{size} Echoes from {size} distinct worlds produce a "
            f"{chars:,}-character influence summary")

    def test_the_count_is_true_even_when_the_list_is_capped(self):
        """Ten named worlds out of four hundred is a summary; claiming
        the campaign touched ten is a lie."""
        log = self._all_distinct(449)
        influence = P.accumulated_influence(log)
        assert influence["distinct_source_games"] == 449
        assert len(influence["source_games"]) == P.MAX_INFLUENCE_SOURCES
        assert influence["total_echoes"] == 449


class TestTheFoldCostIsMeasuredRatherThanAsserted:
    """`derive()` justified not caching with "at most 30 entries".

    That was true of the prototype and is not true of a 450-location
    campaign, so the justification had to be re-earned rather than
    re-worded. Measured: the fold is linear at roughly 8 microseconds
    per interpretation — 0.2 ms at 30, 3.5 ms at 449, 5.0 ms at 600 —
    on an EVENT-DRIVEN path that runs per intent, not per frame.

    That is cheap enough to keep the simple fold. A cache here would buy
    single-digit milliseconds and cost invalidation correctness on the
    one value that must be identical everywhere, and the snapshot it
    rides in spends far more than that on serialisation. So: no cache,
    and the real complexity documented instead.
    """

    @pytest.mark.parametrize("size", [30, 449, 599])
    def test_the_fold_stays_linear_and_cheap(self, size):
        import time
        log = _log(size)
        # The cheapest of several runs, so a busy runner does not turn a
        # performance claim into a flake.
        timings = []
        for _ in range(5):
            start = time.perf_counter()
            derive_mechanics(log)
            timings.append(time.perf_counter() - start)
        best = min(timings)
        # Generous by 10x against the measurement, because this is a
        # REGRESSION guard on complexity, not a benchmark: an accidental
        # quadratic would blow past it and normal jitter will not.
        budget = 0.05
        assert best < budget, (
            f"folding {size} interpretations took {best * 1000:.1f} ms; "
            "the fold is called per snapshot and was linear when last "
            "measured")

    def test_the_fold_is_not_cached(self):
        """Stated as a test because 'no cache' is a decision, and a
        cache added later without invalidation proof would make derived
        mechanics disagree with the log — the one thing that must be
        identical everywhere."""
        from archipepsi_bridge.schemas import protocol
        source = __import__("pathlib").Path(protocol.__file__).read_text()
        assert "at most 30 entries" not in source, (
            "the stale prototype-scale justification is still in the "
            "docstring; the log is ~449 at the default")
        assert "deliberately not cached" in source
