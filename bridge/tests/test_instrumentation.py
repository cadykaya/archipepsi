"""What a Zone actually cost, recorded locally (CAMPAIGN_SCALE.md 13).

The forty-minute Zone and the twenty-hour campaign are TARGETS. Nothing
in the codebase proves either, and this is the only thing that can: it
joins the clock, which only the running game has, to the content values
the engine computed for the same rooms.

Two properties matter as much as the arithmetic. It is LOCAL -- one file
under the player's own save directory, no network, no identifier they
have not already given Archipelago. And it is INERT -- no campaign state
depends on it, and a failure to write it must never cost the player the
Zone they just finished.
"""

from __future__ import annotations

import json
import pathlib

import pytest

from archipepsi_bridge import instrumentation as I
from archipepsi_bridge.schemas import constants as C
from archipepsi_bridge.schemas import protocol as P

from .conftest import Collector, drain, run
from .test_production_scale import PROD, _engine_at


def _timing(zone_id: str, **over) -> P.ZoneTiming:
    base = dict(type="zone_timing", zone_id=zone_id, elapsed_seconds=1834.0,
                deaths=2, checks_completed=15,
                dwell=(P.ChamberDwell(chamber_index=0, seconds=30.0),
                       P.ChamberDwell(chamber_index=1, seconds=210.0)),
                encounter_seconds=(14.5, 22.0), completed=True)
    base.update(over)
    return P.ZoneTiming(**base)


async def _engine_with_a_played_zone(tmp_path):
    engine, _ = await _engine_at(tmp_path, PROD)
    Collector(engine)
    await engine.handle_request_next_zone(False)
    await drain(400)
    record = engine.save.zones[-1]
    assert record.zone is not None
    return engine, record


class TestTheRecordJoinsBothHalves:

    def test_it_holds_the_clock_and_the_content_value(self, tmp_path):
        from archipepsi_bridge import content_value as V

        async def scenario():
            engine, record = await _engine_with_a_played_zone(tmp_path)
            engine.record_zone_timing(_timing(record.zone_id))
            rows = I.read_records(engine.save_dir)
            assert len(rows) == 1
            row = rows[0]
            # ...what it cost
            assert row["elapsed_seconds"] == 1834.0
            assert row["deaths"] == 2
            assert row["encounter_seconds"] == [14.5, 22.0]
            # ...and what it was worth, which only the bridge knows
            assert row["zone_value"] == V.zone_value(record.zone)
            assert row["chamber_count"] == len(record.zone.chambers)
            assert len(row["rooms"]) == len(record.zone.chambers)
            assert row["rooms"][1]["seconds"] == 210.0
            assert row["rooms"][0]["value"] == V.room_value(
                record.zone.chambers[0])
            # ...and the campaign it belongs to
            assert row["location_count"] == PROD.location_count
            assert row["zone_budget_asked_for"] == PROD.zone_budget
        run(scenario())

    def test_a_room_nobody_entered_reads_zero_rather_than_missing(
            self, tmp_path):
        """Every room appears, so "which rooms went unvisited" is a
        question the file can answer."""
        async def scenario():
            engine, record = await _engine_with_a_played_zone(tmp_path)
            engine.record_zone_timing(_timing(record.zone_id))
            rooms = I.read_records(engine.save_dir)[0]["rooms"]
            assert [r["index"] for r in rooms] == list(range(len(rooms)))
            assert any(r["seconds"] == 0.0 for r in rooms)
        run(scenario())

    def test_it_records_the_ratio_the_whole_redesign_bets_on(self, tmp_path):
        """Seconds per budget point. A 1000-point Zone that takes four
        minutes means the budget is wrong, and this is how anyone finds
        out."""
        async def scenario():
            engine, record = await _engine_with_a_played_zone(tmp_path)
            engine.record_zone_timing(_timing(record.zone_id))
            row = I.read_records(engine.save_dir)[0]
            assert row["seconds_per_budget_point"] == pytest.approx(
                1834.0 / PROD.zone_budget, abs=1e-4)
        run(scenario())

    def test_a_timing_for_a_zone_that_was_never_accepted_is_dropped(
            self, tmp_path):
        async def scenario():
            engine, _ = await _engine_at(tmp_path, PROD)
            engine.record_zone_timing(_timing("zone_999"))
            assert I.read_records(engine.save_dir) == []
        run(scenario())


class TestItIsLocalAndInert:

    def test_it_writes_one_file_under_the_save_directory_and_nothing_else(
            self, tmp_path):
        async def scenario():
            engine, record = await _engine_with_a_played_zone(tmp_path)
            before = {p.name for p in engine.save_dir.iterdir()}
            engine.record_zone_timing(_timing(record.zone_id))
            after = {p.name for p in engine.save_dir.iterdir()}
            assert after - before == {I.PLAYTIME_FILENAME}
        run(scenario())

    def test_the_module_has_no_network_of_any_kind(self):
        """Stated as a test because "no telemetry" is a promise, and a
        promise nobody checks is a promise that erodes.

        Read off the imports rather than grepped for words: the module's
        own prose says "no upload path", and a text scan would flag that
        sentence and miss `from x import post`.
        """
        import ast

        tree = ast.parse(open(I.__file__, encoding="utf-8").read())
        imported = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                imported.update(a.name.split(".")[0] for a in node.names)
            elif isinstance(node, ast.ImportFrom):
                imported.add((node.module or "").split(".")[0])
        networking = {"http", "socket", "ssl", "urllib", "requests",
                      "aiohttp", "websockets", "httpx", "smtplib", "ftplib",
                      "asyncio", "subprocess"}
        assert imported & networking == set(), (
            f"instrumentation.py imports {sorted(imported & networking)}; "
            "this module writes to one local file and does nothing else")
        # ...and it reaches exactly one place on disk.
        assert I.playtime_path(pathlib.Path("/somewhere")) == pathlib.Path(
            "/somewhere") / I.PLAYTIME_FILENAME

    def test_a_failed_write_never_costs_the_player_the_zone(self, tmp_path,
                                                            monkeypatch):
        async def scenario():
            engine, record = await _engine_with_a_played_zone(tmp_path)
            saved = engine.save

            def explode(*_args, **_kwargs):
                raise OSError("disk full")

            monkeypatch.setattr(I.Path, "open", explode)
            engine.record_zone_timing(_timing(record.zone_id))   # no raise
            assert engine.save is saved
            assert engine.save.zones[-1].zone is not None
        run(scenario())

    def test_nothing_in_the_campaign_reads_it_back(self, tmp_path):
        """Inert by construction: the snapshot must not carry it, or it
        becomes a second source of truth about the campaign."""
        async def scenario():
            engine, record = await _engine_with_a_played_zone(tmp_path)
            engine.record_zone_timing(_timing(record.zone_id))
            blob = json.dumps(engine.snapshot().model_dump(mode="json"))
            assert "elapsed_seconds" not in blob
            assert "playtime" not in blob
        run(scenario())


class TestTheFileStaysReadable:

    def test_it_survives_a_torn_last_line(self, tmp_path):
        path = I.playtime_path(tmp_path)
        path.write_text('{"zone_id":"a","completed":true,'
                        '"elapsed_seconds":1.0,"deaths":0,'
                        '"seconds_per_budget_point":0.01}\n{"zone_id":"b"',
                        encoding="utf-8")
        rows = I.read_records(tmp_path)
        assert [r["zone_id"] for r in rows] == ["a"]

    def test_it_is_bounded(self, tmp_path):
        for i in range(I.MAX_RECORDS + 25):
            I.append_record(tmp_path, {"zone_id": f"z{i}"})
        rows = I.read_records(tmp_path)
        assert len(rows) == I.MAX_RECORDS
        assert rows[-1]["zone_id"] == f"z{I.MAX_RECORDS + 24}"

    def test_the_summary_says_only_what_it_measured(self, tmp_path):
        assert I.summarise([]) == {"zones": 0}
        rows = [{"completed": True, "elapsed_seconds": s, "deaths": 1,
                 "seconds_per_budget_point": s / 1000.0}
                for s in (600.0, 1800.0, 2400.0)]
        # An abandoned Zone's elapsed time is not a Zone length.
        rows.append({"completed": False, "elapsed_seconds": 5.0, "deaths": 0,
                     "seconds_per_budget_point": 0.005})
        summary = I.summarise(rows)
        assert summary["zones"] == 3
        assert summary["median_seconds"] == 1800.0
        assert summary["median_minutes"] == 30.0
        assert summary["deaths"] == 3
