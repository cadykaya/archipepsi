"""The lifetime Echo log stops riding in every snapshot (ES4).

The Echo log is complete local campaign truth and stays that way. What
changed is how often the bridge SENDS all of it. `broadcast_snapshot()`
fires on every state change — a Check, a Zone transition, a coin spent —
and each one carried the whole log again, for a list that only ever
grows at the end. Measured below, as a share of the whole message:

     29 Echoes  ->  23 KiB of a  48 KiB snapshot
    449         -> 356 KiB of a 626 KiB snapshot
    599         -> 475 KiB of a 833 KiB snapshot

At the 450-location default that is 57% of the message, re-sent to say
something the log had nothing to do with. The rest is `mechanics` — the
fold, which is current state rather than history and is deliberately
still sent whole; see `TestTheFoldIsStillSentWhole`.

So a broadcast may leave the log out and say so. These tests hold the
line on both halves at once: the log really does stop being re-sent, and
nothing that reads it can tell the difference.
"""

from __future__ import annotations

import copy
import json

import pytest

from archipepsi_bridge.schemas import constants as C
from archipepsi_bridge.schemas.echo import EchoInterpretation
from archipepsi_bridge.schemas.protocol import (CampaignSave,
                                                CampaignSnapshot, HubStatus)
from pydantic import TypeAdapter, ValidationError

from .conftest import Collector, connected_engine, drain, run

_ECHO = TypeAdapter(EchoInterpretation)

#: Same three the provider measurement uses: prototype-ish, a late
#: default campaign, and the largest campaign anyone can configure.
SCALES = [
    ("prototype", C.PROTOTYPE_CONFIG.non_goal_count),          # 29
    ("default late", C.DEFAULT_CONFIG.non_goal_count),         # 449
    ("maximum", C.LOCATION_COUNT_MAX - 1),                     # 599
]

#: What the Echo log may cost on a snapshot that is not carrying it.
#: Not a size for the whole message: `mechanics` is the other large
#: field and it is deliberately still sent whole (see
#: `TestTheFoldIsStillSentWhole`), so a total-size bound here would be
#: measuring a decision this change did not make.
MAX_ELIDED_LOG_CHARS = 40


def _echo(index: int) -> EchoInterpretation:
    from archipepsi_bridge.schemas import test_schemas as T
    location = C.FIRST_LOCATION_ID + index
    data = copy.deepcopy(T._CONFERENCE_CALL)
    data.update(echo_id=f"echo_{location}", interpretation_seq=index,
                source_location_id=location,
                display_name=f"Echo {index:03d}",
                source_game=f"Game {index % 23}")
    for op in data["operations"]:
        if "component" in op:
            op["component"]["component_id"] = f"act_{index}"
    return _ECHO.validate_python(data)


def _log(size: int) -> tuple[EchoInterpretation, ...]:
    return tuple(_echo(i) for i in range(size))


def _with_log(save: CampaignSave, log) -> CampaignSave:
    """A save carrying `log`, built by copy rather than by transition.

    The transitions build one interpretation at a time from a real
    provider result; these tests need 599 of them and care about the
    snapshot, not about how the log was written.
    """
    return save.model_copy(update={
        "interpretations": log, "next_interpretation_seq": len(log)})


def _chars(snap: CampaignSnapshot) -> int:
    return len(snap.model_dump_json())


def _part(wire: dict, field: str) -> int:
    """One field's share of the payload, measured the way pydantic
    serialises the whole thing — compact, no spaces — so the parts and
    the total are in the same units."""
    return len(json.dumps(wire[field], separators=(",", ":")))


async def _engine_with(tmp_path, size):
    engine, _ = await connected_engine(tmp_path)
    engine.save = _with_log(engine.save, _log(size))
    return engine


# ===========================================================================
# The measurement
# ===========================================================================

class TestTheSnapshotCostIsMeasured:

    @pytest.mark.parametrize("label,size", SCALES)
    def test_the_log_costs_nothing_on_a_snapshot_that_omits_it(
            self, tmp_path, label, size):
        """The bound is on the LOG's contribution, and it does not move
        between 29 Echoes and 599: `[]` costs what `[]` costs."""
        async def go():
            engine = await _engine_with(tmp_path, size)
            collector = Collector(engine)
            await engine.broadcast_snapshot()          # complete
            await engine.broadcast_snapshot()          # elided
            return collector.of_type("campaign_snapshot")

        first, second = run(go())
        assert first.interpretations_complete
        assert not second.interpretations_complete
        wire = json.loads(second.model_dump_json())
        assert wire["interpretations"] == []
        cost = _part(wire, "interpretations")
        assert cost < MAX_ELIDED_LOG_CHARS, (
            f"{label} ({size} Echoes) still spends {cost:,} characters on "
            "the Echo log of a snapshot that is not carrying it")
        # And the whole of it, and only it, came off the wire: what the
        # message shed is what the log weighed, to within the one
        # character `interpretations_complete` gains flipping to `false`.
        shed = _chars(first) - _chars(second)
        weighed = _part(json.loads(first.model_dump_json()),
                        "interpretations") - cost
        assert abs(shed - weighed) <= 8, (
            f"{label}: shed {shed:,} characters for a log weighing "
            f"{weighed:,} — something else changed between the two")

    def test_the_before_and_after_are_recorded(self, tmp_path):
        """The numbers in this file's docstring, re-derived. If the
        payload shape changes enough to move them, this fails and the
        prose gets corrected rather than quietly going stale."""
        async def go():
            out = {}
            for label, size in SCALES:
                engine = await _engine_with(tmp_path, size)
                collector = Collector(engine)
                await engine.broadcast_snapshot()
                await engine.broadcast_snapshot()
                full, elided = collector.of_type("campaign_snapshot")
                out[label] = (_chars(full), _chars(elided))
            return out

        sizes = run(go())
        print("\n  snapshot payload, complete -> elided")
        for label, size in SCALES:
            full, elided = sizes[label]
            print(f"  {label:<13} {size:>3} echoes  "
                  f"{full:>8,} -> {elided:>7,} chars  "
                  f"({full / max(elided, 1):.1f}x)")
        # The late-campaign case is the one the change exists for.
        full, elided = sizes["default late"]
        assert full > 600_000, "the problem stopped reproducing"
        assert full - elided > 350_000, (
            "a late-campaign snapshot only shed "
            f"{full - elided:,} characters")
        # The saving has to scale with the campaign, not be a constant:
        # 20x the history has to shed roughly 20x the bytes.
        shed = {label: sizes[label][0] - sizes[label][1]
                for label, _ in SCALES}
        assert shed["default late"] > shed["prototype"] * 10
        assert shed["maximum"] > shed["default late"]


class TestTheFoldIsStillSentWhole:
    """`mechanics` is the OTHER large field, and it stays.

    It grows with the campaign for the same reason the log does, and it
    changes exactly when the log changes — so the same key would elide
    it just as safely. It is deliberately not elided anyway:

    * it is CURRENT DERIVED STATE, not lifetime history. The log is the
      archive; the fold is what the game plays from, and the client
      re-reads all of it on every snapshot to draw the HUD.
    * `CampaignSnapshot` validates `slots` against the `mechanics` it is
      sending. v0.6 shipped without that check and let a snapshot carry
      a slotted Action the player did not own. Eliding the fold would
      turn that guard off for most snapshots.

    This test exists so the decision is visible and costed rather than
    forgotten. It records what the fold costs; it does not defend the
    number.

    **FROZEN FOR THE ART A/B.** Eliding this is a real option and a good
    one, and it is NOT to be taken until the post-art run of the same
    Zone 1 is complete (`docs/PLAYTEST_BASELINE.md`, "THE A/B FREEZE").
    The authored-art integration is the variable that comparison is of;
    a transport change landing in the middle of it makes the result
    measure two things at once and neither cleanly. Afterwards this
    returns to the frontier — take it then, and rewrite this docstring
    rather than deleting the test.
    """

    def test_the_remaining_cost_is_the_fold_and_it_is_recorded(
            self, tmp_path):
        async def go():
            out = {}
            for label, size in SCALES:
                engine = await _engine_with(tmp_path, size)
                collector = Collector(engine)
                await engine.broadcast_snapshot()
                await engine.broadcast_snapshot()
                _, elided = collector.of_type("campaign_snapshot")
                wire = json.loads(elided.model_dump_json())
                out[label] = (_chars(elided), _part(wire, "mechanics"))
            return out

        sizes = run(go())
        print("\n  snapshot with the log elided: total / of which fold")
        for label, size in SCALES:
            total, fold = sizes[label]
            print(f"  {label:<13} {size:>3} echoes  {total:>8,}"
                  f" / {fold:>8,} chars  ({100 * fold / total:.0f}%)")
        # Worth stating plainly: this fixture gives every Echo its own new
        # component, so the fold here is its worst case. A real campaign
        # spends many interpretations UPGRADING or MODIFYING what is
        # already owned, and folds smaller. The LOG measurement above has
        # no such caveat — one entry per Echo, always.
        for label, _ in SCALES:
            total, fold = sizes[label]
            assert fold > total * 0.5, (
                f"{label}: the fold is no longer what an elided snapshot "
                "is made of; this test's premise needs rewriting")


# ===========================================================================
# Eliding is not losing
# ===========================================================================

class TestElidingIsNotLosing:

    def test_a_client_replaying_the_stream_holds_the_whole_log(
            self, tmp_path):
        """The client-side contract, exercised the way the client runs
        it: one complete snapshot on connect, then whatever the
        broadcasts carry, and the archive is always the whole log."""
        async def go():
            engine, backend = await connected_engine(tmp_path)
            engine.save = _with_log(engine.save, _log(40))
            collector = Collector(engine)

            held = json.loads(engine.snapshot().model_dump_json())  # connect
            seen = []
            for extra in range(3):
                # Two broadcasts per appended Echo: the first carries the
                # new log, the second must not.
                await engine.broadcast_snapshot()
                await engine.broadcast_snapshot()
                engine.save = _with_log(engine.save, _log(41 + extra))
            await engine.broadcast_snapshot()

            for message in collector.of_type("campaign_snapshot"):
                wire = json.loads(message.model_dump_json())
                if not wire["interpretations_complete"]:
                    wire["interpretations"] = held["interpretations"]
                held = wire
                seen.append(len(held["interpretations"]))
            return seen, held

        seen, held = run(go())
        assert seen == [40, 40, 41, 41, 42, 42, 43], seen
        assert len(held["interpretations"]) == 43
        assert [e["interpretation_seq"]
                for e in held["interpretations"]] == list(range(43))

    def test_the_count_is_sent_whether_or_not_the_log_is(self, tmp_path):
        async def go():
            engine = await _engine_with(tmp_path, 40)
            collector = Collector(engine)
            await engine.broadcast_snapshot()
            await engine.broadcast_snapshot()
            return collector.of_type("campaign_snapshot")

        for message in run(go()):
            assert message.interpretation_count == 40

    def test_appending_an_echo_forces_the_whole_log_out_again(
            self, tmp_path):
        async def go():
            engine = await _engine_with(tmp_path, 10)
            collector = Collector(engine)
            await engine.broadcast_snapshot()
            await engine.broadcast_snapshot()
            engine.save = _with_log(engine.save, _log(11))
            await engine.broadcast_snapshot()
            return [m.interpretations_complete
                    for m in collector.of_type("campaign_snapshot")]

        assert run(go()) == [True, False, True]

    def test_a_different_campaign_forces_the_whole_log_out_again(
            self, tmp_path):
        """Length alone is not identity. Two campaigns can hold the same
        NUMBER of Echoes and not one of the same Echoes, so the key has
        to say which campaign as well as how far along it is."""
        async def go():
            engine = await _engine_with(tmp_path, 10)
            collector = Collector(engine)
            await engine.broadcast_snapshot()
            await engine.broadcast_snapshot()
            engine.save = engine.save.model_copy(
                update={"seed_name": "ADifferentSeed"})
            await engine.broadcast_snapshot()
            return [m.interpretations_complete
                    for m in collector.of_type("campaign_snapshot")]

        assert run(go()) == [True, False, True]

    def test_clearing_the_campaign_forces_the_whole_log_out_again(
            self, tmp_path):
        async def go():
            engine = await _engine_with(tmp_path, 10)
            collector = Collector(engine)
            await engine.broadcast_snapshot()
            await engine.broadcast_snapshot()
            engine.save = None
            await engine.broadcast_snapshot()          # empty, complete
            engine.save = (await _engine_with(tmp_path, 10)).save
            await engine.broadcast_snapshot()
            return [(m.interpretations_complete, m.interpretation_count)
                    for m in collector.of_type("campaign_snapshot")]

        assert run(go()) == [(True, 10), (False, 10), (True, 0), (True, 10)]


# ===========================================================================
# Nobody joins the stream without a full log
# ===========================================================================

class TestEveryClientStartsComplete:

    def test_snapshot_itself_is_always_complete(self, tmp_path):
        """`engine.snapshot()` is what `server.py` sends on connect and
        on `hello`. Only `broadcast_snapshot()` elides, and this is the
        whole correctness argument for letting it."""
        async def go():
            engine = await _engine_with(tmp_path, 25)
            await engine.broadcast_snapshot()
            await engine.broadcast_snapshot()          # now eliding
            return engine.snapshot()

        snap = run(go())
        assert snap.interpretations_complete
        assert len(snap.interpretations) == 25

    def test_the_server_answers_connect_and_hello_with_the_whole_log(self):
        """Pinned against the source, because the elision is only safe
        while both of these send a complete snapshot."""
        from pathlib import Path
        import archipepsi_bridge.server as server_mod
        src = Path(server_mod.__file__).read_text(encoding="utf-8")
        # The connect handler and the `hello` route, each sending the
        # engine's own snapshot rather than a broadcast.
        assert src.count("self._send(ws, self.engine.snapshot())") == 1
        assert src.count("self._send(ws, engine.snapshot())") == 1
        # Neither path may reach for the eliding one.
        handler = src.split("async def handler")[1].split("async def dispatch")[0]
        assert "await engine.broadcast_snapshot()" not in handler
        assert "await self.engine.broadcast_snapshot()" not in handler


# ===========================================================================
# The shape cannot lie
# ===========================================================================

def _snap(**over) -> CampaignSnapshot:
    base = dict(bridge_connected=True, ap_connected=True, ap_mode="mock",
                epsilon_provider="mock",
                hub=HubStatus(mode="NO_CAMPAIGN", headline="No campaign"))
    base.update(over)
    return CampaignSnapshot(**base)


class TestThePartialLogCannotBeConstructed:

    def test_an_elided_log_must_be_sent_empty(self):
        with pytest.raises(ValidationError, match="never partially"):
            _snap(interpretations=_log(3), interpretations_complete=False,
                  interpretation_count=9)

    def test_a_complete_log_must_agree_with_its_count(self):
        with pytest.raises(ValidationError, match="disagrees"):
            _snap(interpretations=_log(3), interpretation_count=9)

    def test_the_elided_message_is_a_shape_the_model_allows(self, tmp_path):
        """`broadcast_snapshot()` builds the elided message with
        `model_copy`, which does not re-validate. So the shape it
        produces is checked two ways: what actually goes on the wire,
        and the same combination built through the validator.
        """
        async def go():
            engine = await _engine_with(tmp_path, 30)
            collector = Collector(engine)
            await engine.broadcast_snapshot()
            await engine.broadcast_snapshot()
            return collector.of_type("campaign_snapshot")[1]

        wire = json.loads(run(go()).model_dump_json())
        assert wire["interpretations"] == []
        assert wire["interpretations_complete"] is False
        assert wire["interpretation_count"] == 30
        assert wire["protocol_version"] == 8
        # The validator agrees this is a legal snapshot.
        built = _snap(interpretations_complete=False, interpretation_count=30)
        assert built.interpretations == ()

    def test_a_snapshot_that_ignores_all_of_this_means_what_it_did(self):
        """Back-compat, stated as a test rather than as a promise: a
        snapshot built without either new field is a complete, empty
        log — exactly what it was before the fields existed."""
        snap = _snap()
        assert snap.interpretations_complete
        assert snap.interpretation_count == 0
        assert snap.interpretations == ()


# ===========================================================================
# The client half, pinned across the language boundary
# ===========================================================================

class TestTheClientRestoresWhatTheBridgeLeftOut:

    def _client(self) -> str:
        from pathlib import Path
        root = Path(__file__).resolve().parents[2]
        return (root / "godot/scripts/autoload/bridge_client.gd").read_text(
            encoding="utf-8")

    def test_the_client_reattaches_the_cached_log(self):
        src = self._client()
        assert '_reattach_echo_log(message)' in src
        # Defaulted TRUE on the client too: an older bridge that always
        # sends the log must not be read as eliding it.
        assert 'message.get("interpretations_complete", true)' in src
        assert 'message["interpretations"] = snapshot.get(' in src

    def test_the_client_reattaches_before_it_stores(self):
        """Order is the whole trick: `snapshot` is still the PREVIOUS
        snapshot at the moment the log is copied out of it."""
        src = self._client()
        assert src.index("_reattach_echo_log(message)") < \
            src.index("snapshot = message")

    def test_no_consumer_reads_the_raw_field_behind_the_accessor(self):
        """One Echo log on the client side. A UI that went back to
        `snapshot.get("interpretations")` would read an empty list on
        every elided snapshot and quietly render an empty archive.

        `godot/tests` is deliberately out of scope: the drivers build
        fake snapshots and assert on the raw field, which is the right
        thing for them to do.
        """
        from pathlib import Path
        root = Path(__file__).resolve().parents[2] / "godot/scripts"
        offenders = [
            str(p.relative_to(root))
            for p in root.rglob("*.gd")
            if p.name != "bridge_client.gd"
            and 'get("interpretations"' in p.read_text(encoding="utf-8")]
        assert offenders == [], (
            "these read the snapshot field directly instead of "
            f"BridgeClient.interpretations(): {offenders}")
