"""Local playtime records (CAMPAIGN_SCALE.md 13).

The 40-minute Zone and the 20-hour campaign are TARGETS, and this module
is the only thing that can turn either into a fact.

Two facts, in fact. A campaign has a length to its GOAL and a length to a
100% clear, and at the defaults those are 24 and 30 Zones -- four hours
apart at the 40-minute target. Which is why the record carries the
campaign config rather than a single duration: median Zone time from
here, Zone counts from `CampaignConfig`, and both numbers fall out.
That open pacing decision is CAMPAIGN_SCALE.md 3. It joins what only
the running game knows -- elapsed time, per-room dwell, deaths, how long
an encounter actually took -- to what only the bridge knows: the content
value the engine computed for the same rooms.

Local only, and deliberately so. Nothing here reaches the network: the
records are appended to one file under the player's save directory, in a
format they can read, delete or hand over as they choose. There is no
analytics service, no identifier beyond the seed and slot the player is
already playing, and no upload path to accidentally leave switched on.

One line of JSON per Zone, because a partial write costs one Zone rather
than the whole history, and because `jq` is a perfectly good analysis
tool for a file this size.
"""

from __future__ import annotations

import hashlib
import json
import logging
import time
from pathlib import Path

from . import content_value as V
from .schemas.protocol import CampaignSave, ZoneTiming

log = logging.getLogger("archipepsi.instrumentation")

#: One file per install, not per campaign: the question the record answers
#: -- how long is a Zone, really -- is asked across seeds.
PLAYTIME_FILENAME = "playtime.jsonl"

#: A generous ceiling on the history. Roughly a thousand Zones at the
#: sizes this records, which is far more than a calibration pass needs and
#: small enough that nobody has to think about it.
MAX_RECORDS = 2000


def playtime_path(save_dir: Path) -> Path:
    return Path(save_dir) / PLAYTIME_FILENAME


def build_record(save: CampaignSave, timing: ZoneTiming,
                 build: dict | None = None) -> dict | None:
    """The joined record, or None if the Zone is not one we can describe.

    Returns a plain dict rather than a model: this is a log line, not
    campaign truth. Nothing reads it back into the game, and giving it a
    schema would invite something to.
    """
    record = save.zone_by_id(timing.zone_id)
    if record is None or record.zone is None:
        log.info("timing for %s arrived with no accepted Zone behind it; "
                 "not recorded", timing.zone_id)
        return None

    config = save.scale.config()
    zone = record.zone
    dwell = {d.chamber_index: d.seconds for d in timing.dwell}
    rooms = [
        {
            "index": index,
            "type": chamber.type,
            "value": V.room_value(chamber),
            "seconds": round(dwell.get(index, 0.0), 2),
            "holds_check": bool(chamber.reward_ids),
        }
        for index, chamber in enumerate(zone.chambers)
    ]
    allocated = len(record.allocated_location_ids)
    asked_for = config.zone_budget_for(allocated)
    return {
        "recorded_at": round(time.time(), 3),
        # WHICH BUILD played this. The pre-art baseline
        # (`docs/baselines/playtest_2_5.json`) exists so a run after
        # authored art can be compared to one before it, and a line that
        # cannot say which side of that it is on cannot be compared to
        # anything.
        #
        # HANDED IN rather than looked up. `version.build_metadata()`
        # shells out to git, and this module's whole guarantee is that it
        # imports nothing that could reach anywhere and touches exactly
        # one file. The engine knows the build already.
        "build": dict(build or {}),
        "seed_name": save.seed_name,
        "slot_id": save.slot_id,
        "zone_id": timing.zone_id,
        "generation_index": record.generation_index,
        "is_finale": record.is_finale,
        "used_fallback": record.used_fallback,
        "target_game": zone.target_game,
        "theme": zone.theme,
        # What the campaign is configured for...
        "location_count": config.location_count,
        "zone_target_checks": config.zone_target_checks,
        "zone_budget_configured": config.zone_budget,
        "zone_budget_asked_for": asked_for,
        # ...what the Zone actually holds...
        "zone_value": V.zone_value(zone),
        # WHICH LEVEL this was, in sixteen characters. Two records
        # carrying the same id walked the same generated Zone, which is
        # the whole premise of the pre-art / post-art art comparison:
        # the level is the constant and the art is the variable.
        "zone_digest": hashlib.sha256(
            zone.model_dump_json().encode("utf-8")).hexdigest()[:16],
        "chamber_count": len(zone.chambers),
        "allocated_checks": allocated,
        "rooms": rooms,
        # ...and what it cost to play.
        "elapsed_seconds": round(timing.elapsed_seconds, 2),
        "deaths": timing.deaths,
        "checks_completed": timing.checks_completed,
        "encounter_seconds": [round(s, 2) for s in timing.encounter_seconds],
        "completed": timing.completed,
        # WHAT THE PLAYER ACTUALLY DID, per activity. The Zone that led
        # to this batch spent 531 of its 921 content points on activities
        # and could not say whether a single one had been touched,
        # because they could not be. `entered` and `attempts` are kept
        # apart so "walked past it" and "tried it and gave up" stay
        # different findings.
        "activities": [a.model_dump() for a in timing.activities],
        "activities_built": len(timing.activities),
        "activities_entered": sum(1 for a in timing.activities if a.entered),
        "activities_attempted": sum(
            1 for a in timing.activities if a.attempts > 0),
        "activities_completed": sum(
            1 for a in timing.activities if a.completed),
        "activity_seconds": round(
            sum(a.active_seconds for a in timing.activities), 2),
        # The number the whole redesign is a bet on. Recorded rather than
        # asserted: a Zone worth 1000 points that takes four minutes means
        # the budget is wrong, and that is exactly what this is for.
        "seconds_per_budget_point": (
            round(timing.elapsed_seconds / asked_for, 4) if asked_for else 0.0),
    }


def append_record(save_dir: Path, record: dict) -> None:
    """Append one line. Never raises into the game.

    A failed write loses a measurement. Losing the Zone the player just
    finished because a log file could not be opened would be a far worse
    trade, so every failure here is a log line and nothing more.
    """
    path = playtime_path(save_dir)
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        line = json.dumps(record, separators=(",", ":"), sort_keys=True)
        with path.open("a", encoding="utf-8") as handle:
            handle.write(line + "\n")
        _trim(path)
    except OSError as exc:
        log.warning("could not append a playtime record (%s); "
                    "the Zone is unaffected", exc)


def _trim(path: Path) -> None:
    """Keep the file bounded, oldest first."""
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return
    if len(lines) <= MAX_RECORDS:
        return
    keep = lines[-MAX_RECORDS:]
    tmp = path.with_suffix(".jsonl.tmp")
    try:
        tmp.write_text("\n".join(keep) + "\n", encoding="utf-8")
        tmp.replace(path)
    except OSError as exc:
        log.warning("could not trim the playtime log (%s)", exc)


def read_records(save_dir: Path) -> list[dict]:
    """Everything recorded so far. For the player and for calibration."""
    path = playtime_path(save_dir)
    if not path.exists():
        return []
    out = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            out.append(json.loads(line))
        except json.JSONDecodeError:
            # A torn last line from a hard kill. Skipped, not fatal.
            log.info("skipping an unreadable playtime record")
    return out


def summarise(records: list[dict]) -> dict:
    """What the records say about Zone length, stated plainly.

    Deliberately not a claim: `zones` of 3 means three Zones were timed,
    and the numbers are worth exactly that much.
    """
    played = [r for r in records if r.get("completed")]
    if not played:
        return {"zones": 0}
    seconds = sorted(r["elapsed_seconds"] for r in played)
    return {
        "zones": len(played),
        "median_seconds": seconds[len(seconds) // 2],
        "shortest_seconds": seconds[0],
        "longest_seconds": seconds[-1],
        "median_minutes": round(seconds[len(seconds) // 2] / 60.0, 1),
        "mean_seconds_per_budget_point": round(
            sum(r["seconds_per_budget_point"] for r in played) / len(played),
            4),
        "deaths": sum(r["deaths"] for r in played),
    }
