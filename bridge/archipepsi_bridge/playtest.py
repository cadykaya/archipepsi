"""The playtest operator's tool. Two commands, no pytest, no JSON hunting.

    python -m archipepsi_bridge.playtest check
    python -m archipepsi_bridge.playtest report

`Playtest 2.5 (Windows).bat` runs `check` before it starts anything and
refuses on a non-zero exit; a person who has finished playing runs
`report`. Neither needs a development checkout beyond the two libraries
the bridge already installs.

WHY THIS EXISTS AND NOT A PYTEST INVOCATION. The guard has to run on a
player's machine, where pytest is not installed and a traceback is not an
error message. So the checks live here as one function returning plain
sentences, and `bridge/tests/test_playtest_baseline.py` drives THIS
function against its sabotages — the suite is the proof, this is the
implementation, and there is one of each.

WHAT `check` WILL NOT DO. It never writes the baseline. `make baseline`
regenerating the file is the developer's deliberate act; a launcher doing
it silently would repair the drift it exists to report and the playtest
after authored art would be compared against a baseline nobody walked.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from . import content_value as V
from .schemas import constants as C
from .schemas import zone as Z

ROOT = Path(__file__).resolve().parents[2]
BASELINE_PATH = ROOT / "docs" / "baselines" / "playtest_2_5.json"

#: The Zone a human is asked to play, and the one both halves of the
#: art A/B use. Zones 2 and 3 stay in the corpus for replay and for a
#: second structural sample if Zone 1 looks odd; neither is required.
REQUIRED_ZONE_INDEX = 1

#: The scale a baseline playtest is played at. The 450-location default,
#: which is what the corpus was recorded at -- and NOT what pressing
#: MOCK CAMPAIGN gives you by default, which is still the prototype's
#: thirty. `--mock-scale=default` is how the launcher asks for this.
PLAYTEST_CONFIG = C.DEFAULT_CONFIG


# ---------------------------------------------------------------------------
# Two different artifacts, and they are not the same Zone
# ---------------------------------------------------------------------------
#
# This surfaced while building the launcher and is worth stating plainly,
# because a launcher that got it wrong would print a confident, false
# claim on screen:
#
#   `docs/baselines/playtest_2_5.json` is a GENERATOR FINGERPRINT. Three
#   Zones built from three fixed synthetic requests. Its job is to fail
#   when the engine stops building the Zones it recorded. Nobody plays
#   it.
#
#   The PLAYED Zone is the mock campaign's Zone 1 at the default scale.
#   Its request comes from the mock seed's own item placements, so its
#   theme, its corridor widths and its affordance features differ from
#   the corpus. Measured: the same 23 rooms in the same order with the
#   same enemy counts, dressed for a different source world.
#
# The A/B rests on the PLAYED Zone being identical before and after art,
# which it is: the mock seed and the scale are both fixed, and two
# independent engines produce byte-identical Zones. The corpus is what
# says the generator underneath has not moved in between. Both are
# needed and neither substitutes for the other.


def played_zone():
    """The Zone a baseline playtest will actually walk.

    Built the way the game builds it -- a real engine, the mock backend
    at the playtest scale -- rather than by calling the fallback
    directly, because the request is a product of allocation and the
    point is to show what the human is about to get.
    """
    import asyncio
    import tempfile

    from .campaign import CampaignEngine
    from .epsilon import FallbackEpsilonProvider
    from .mock_ap import MockAPBackend

    async def build(save_dir: Path):
        engine = CampaignEngine(provider=FallbackEpsilonProvider(),
                                provider_name="fallback", save_dir=save_dir)
        engine.backend = MockAPBackend(engine, config=PLAYTEST_CONFIG)
        await engine.backend.connect("", "Skyiah", "")
        for _ in range(40):
            await asyncio.sleep(0)
        await engine.handle_request_next_zone(False)
        for _ in range(600):
            await asyncio.sleep(0)
            active = engine.save.active_zone if engine.save else None
            # `zone is not None` rather than a state name: what this
            # waits for is generation finishing, and GENERATED is
            # already that. Waiting for READY -- which needs the player
            # to walk through the portal -- would spin forever.
            if active is not None and active.zone is not None:
                return active.zone
        return None

    with tempfile.TemporaryDirectory() as scratch:
        return asyncio.run(build(Path(scratch)))


def played_zone_digest() -> dict:
    """What the played Zone IS, small enough to print and to compare.

    The digest is the comparison surface for the art A/B: the same
    sixteen characters before and after means the same level, whatever
    it now looks like.
    """
    import hashlib

    zone = played_zone()
    if zone is None:
        return {}
    raw = zone.model_dump_json()
    return {
        "rooms": len(zone.chambers),
        "value": round(V.zone_value(zone)),
        "enemies": sum(c.enemy_total for c in zone.chambers),
        "checks": sum(len(c.reward_ids) for c in zone.chambers),
        "theme": zone.theme,
        "target_game": zone.target_game,
        "digest": hashlib.sha256(raw.encode("utf-8")).hexdigest()[:16],
    }


# ---------------------------------------------------------------------------
# check
# ---------------------------------------------------------------------------

def preflight_problems() -> list[str]:
    """Everything wrong with running a baseline playtest right now.

    Empty means go. Each entry is a sentence for a person, not a
    traceback: this is read off a console window by whoever is about to
    spend an hour playing.
    """
    from pydantic import TypeAdapter, ValidationError

    from .epsilon.requests import ZoneGenerationRequest
    from .fixtures import make_playtest_baseline as B

    problems: list[str] = []
    if not BASELINE_PATH.exists():
        return [f"The baseline file is missing: {BASELINE_PATH}"]
    try:
        baseline = json.loads(BASELINE_PATH.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        return [f"The baseline file could not be read: {exc}"]

    # 1. Did anything move under it? Built in memory and compared --
    #    never written.
    try:
        current = json.loads(json.dumps(B.build()))
    except Exception as exc:                        # pragma: no cover
        return [f"The baseline generator itself failed: "
                f"{type(exc).__name__}: {exc}"]
    if current != baseline:
        problems.append(
            "The engine no longer builds the Zones this baseline "
            "recorded, so a playtest now could not be compared to one "
            "after authored art. Nothing has been changed. This is a "
            "developer's call, not yours: `make baseline` retakes it, "
            "and doing that means the earlier playtest's numbers stop "
            "applying.")
        problems.extend(_what_moved(baseline, current))

    # 2. The scale it was taken at, against the scale that would be
    #    played. Reported separately because it is the specific drift
    #    the owner asked to be refused loudly.
    config = C.DEFAULT_CONFIG
    live = {
        "location_count": config.location_count,
        "zone_target_checks": config.zone_target_checks,
        "zone_budget": config.zone_budget,
        "check_value": V.CHECK_VALUE,
        "finale_required_fraction": C.FINALE_REQUIRED_FRACTION,
        "finale_required_checks": config.finale_required_checks(),
        "max_enemies_spawned_cap": C.MAX_ENEMIES_SPAWNED_CAP,
    }
    for key, was in sorted(baseline.get("scale", {}).items()):
        now = live.get(key)
        if now != was:
            problems.append(
                f"The campaign scale moved: {key} was {was} when the "
                f"baseline was taken and is {now} now.")

    # 3. Does the required Zone still replay and still validate? A
    #    schema that moved under the corpus is the other way this stops
    #    being a baseline.
    entry = zone_entry(baseline, REQUIRED_ZONE_INDEX)
    if entry is None:
        problems.append(
            f"The baseline has no Zone {REQUIRED_ZONE_INDEX}, which is "
            "the one the playtest is of.")
        return problems
    try:
        request = ZoneGenerationRequest.model_validate(entry["request"])
        zone = TypeAdapter(Z.Zone).validate_python(entry["zone"])
    except ValidationError as exc:
        problems.append(
            f"Zone {REQUIRED_ZONE_INDEX} no longer parses against "
            f"today's schemas: {exc.errors()[0]['msg']}")
        return problems
    errors = Z.validate_zone(
        zone, expected_zone_id=request.zone_id,
        allocated_location_ids=[loc.location_id
                                for loc in request.locations],
        owned_echo_ids=[],
        owned_affordance_tags=request.unlocked_affordances,
        guaranteed_capabilities=request.guaranteed_capabilities,
        zone_budget=request.campaign.zone_budget)
    if errors:
        problems.append(
            f"Zone {REQUIRED_ZONE_INDEX} no longer passes validation: "
            + "; ".join(errors[:3]))
    return problems


def _what_moved(baseline: dict, current: dict) -> list[str]:
    """A short, human list of which recorded Zones changed."""
    out: list[str] = []
    for was, now in zip(baseline.get("zones", ()), current.get("zones", ())):
        if was.get("zone") != now.get("zone"):
            out.append(
                f"  Zone {was.get('zone_index')}: was "
                f"{was['measured']['chambers']} rooms / "
                f"{was['measured']['content_value']} points, now "
                f"{now['measured']['chambers']} / "
                f"{now['measured']['content_value']}")
    if baseline.get("echoes") != current.get("echoes"):
        out.append("  the recorded Echoes changed too")
    return out


def zone_entry(baseline: dict, index: int) -> dict | None:
    for entry in baseline.get("zones", ()):
        if entry.get("zone_index") == index:
            return entry
    return None


# ---------------------------------------------------------------------------
# report
# ---------------------------------------------------------------------------

def _rows(record: dict) -> list[str]:
    """One playtime record, as the measurements that were asked for.

    Reports. Does not judge, and does not tune: every number here is
    what happened, and what it MEANS is a conversation, not a threshold
    in a script.
    """
    rooms = record.get("rooms", [])
    elapsed = float(record.get("elapsed_seconds", 0.0))
    build = record.get("build", {})
    out = [
        f"  Zone            {record.get('zone_id', '?')}"
        f"  (generation {record.get('generation_index', '?')},"
        f" {'finale' if record.get('is_finale') else 'ordinary'})",
        f"  Played on       {build.get('commit', 'unknown')}"
        f" on {build.get('branch', 'unknown')}"
        f"{'  [TREE WAS DIRTY]' if build.get('tree') == 'dirty' else ''}",
        f"  Level id        {record.get('zone_digest', 'not recorded')}"
        f"   theme {record.get('theme', '?')}",
        "",
        f"  Elapsed         {_hms(elapsed)}"
        f"   ({elapsed:.0f} s)",
        f"  Rooms           {record.get('chamber_count', len(rooms))}",
        f"  Checks claimed  {record.get('checks_completed', 0)}"
        f" of {record.get('allocated_checks', 0)}"
        f"   ({'completed' if record.get('completed') else 'NOT completed'})",
        f"  Deaths          {record.get('deaths', 0)}",
        f"  Content value   {record.get('zone_value', 0)}"
        f"   (asked for {record.get('zone_budget_asked_for', 0)})",
        f"  Sec per point   {record.get('seconds_per_budget_point', 0.0)}",
    ]

    encounters = record.get("encounter_seconds", [])
    if encounters:
        out.append(
            f"  Encounters      {len(encounters)}"
            f"   total {sum(encounters):.0f} s"
            f"   longest {max(encounters):.0f} s"
            f"   median {sorted(encounters)[len(encounters) // 2]:.0f} s")
    else:
        out.append("  Encounters      none recorded")

    built = int(record.get("activities_built", 0) or 0)
    if built:
        out.append(
            f"  Activities      {built}"
            f"   noticed {record.get('activities_entered', 0)}"
            f"   tried {record.get('activities_attempted', 0)}"
            f"   solved {record.get('activities_completed', 0)}"
            f"   {float(record.get('activity_seconds', 0.0)):.0f} s")

    out += ["", "  Per-room dwell", "",
            "    #   type            value   seconds   check"]
    for room in rooms:
        out.append(
            f"    {room.get('index', 0):<3} {room.get('type', '?'):<15}"
            f" {room.get('value', 0):>5}   {room.get('seconds', 0.0):>7}"
            f"   {'yes' if room.get('holds_check') else '-'}")

    activities = record.get("activities", [])
    if activities:
        out += ["", "  Per-activity", "",
                "    room       kind              n   noticed  tries  "
                "solved  seconds  needs"]
        for activity in activities:
            needs = ", ".join(activity.get("requires", []) or [])
            if activity.get("not_yet"):
                needs = f"NOT YET ({needs})" if needs else "NOT YET"
            out.append(
                f"    {str(activity.get('room_id', '?')):<10}"
                f" {str(activity.get('kind', '?')):<17}"
                f" {activity.get('element_count', 0):>1}"
                f"   {'yes' if activity.get('entered') else '-':<7}"
                f"  {activity.get('attempts', 0):>5}"
                f"  {'yes' if activity.get('completed') else '-':>6}"
                f"  {float(activity.get('active_seconds', 0.0)):>7.1f}"
                f"  {needs}")
    return out


def _hms(seconds: float) -> str:
    minutes, secs = divmod(int(seconds), 60)
    hours, minutes = divmod(minutes, 60)
    return (f"{hours}h {minutes:02d}m {secs:02d}s" if hours
            else f"{minutes}m {secs:02d}s")


def anomalies(record: dict) -> list[str]:
    """Structural oddities worth LOOKING at, flagged and nothing more.

    These are not thresholds anything acts on. Each one describes a
    shape that would make the measurement misleading if nobody noticed
    it — a Zone left early, a room never entered, time in one room. What
    any of it means is decided afterwards, by a person.
    """
    out: list[str] = []
    rooms = record.get("rooms", [])
    elapsed = float(record.get("elapsed_seconds", 0.0))

    if not record.get("completed"):
        out.append("The Zone was left before it was finished, so the "
                   "elapsed time is not a Zone duration.")
    # Deaths inflate the clock, and the report said "nothing structurally
    # odd" about the baseline run with a death on it. Dying returns the
    # player to the Zone ENTRANCE, so every room between there and where
    # they fell is walked again: elapsed time is an UPPER BOUND on a clean
    # duration and per-room dwell double-counts every room re-crossed.
    # This was explained in conversation and not encoded, which is the
    # same failure as a comment that says a thing a test does not.
    deaths = int(record.get("deaths", 0))
    if deaths:
        out.append(
            f"{deaths} death{'' if deaths == 1 else 's'}: respawn is at "
            "the Zone entrance, so the elapsed time includes re-walking "
            "everything up to the fall. Treat it as an upper bound, and "
            "the dwell of re-crossed rooms as double-counted.")
    claimed = record.get("checks_completed", 0)
    allocated = record.get("allocated_checks", 0)
    if allocated and claimed < allocated:
        out.append(f"{allocated - claimed} of {allocated} Checks were not "
                   "claimed.")
    unvisited = [r for r in rooms if float(r.get("seconds", 0.0)) <= 0.0]
    if unvisited:
        out.append(
            f"{len(unvisited)} of {len(rooms)} rooms were never entered "
            f"(#{', #'.join(str(r.get('index')) for r in unvisited[:8])}"
            f"{'...' if len(unvisited) > 8 else ''}). Optional rooms are "
            "by design; all of them would mean the mandatory path is the "
            "whole Zone.")
    if rooms and elapsed > 0:
        worst = max(rooms, key=lambda r: float(r.get("seconds", 0.0)))
        share = float(worst.get("seconds", 0.0)) / elapsed
        if share > 0.4:
            out.append(
                f"Room #{worst.get('index')} ({worst.get('type')}) took "
                f"{share * 100:.0f}% of the Zone. One room carrying most "
                "of a Zone is worth a look.")
    # NOT "the fallback provider ran". `used_fallback` is set when a
    # provider CALL failed or produced something invalid and the
    # deterministic generator filled in -- so on a baseline run, where
    # the fallback IS the provider, it is false and that is correct.
    # True here means a live Epsilon was configured and it did not
    # deliver, which makes the Zone a different Zone from the one the
    # digest was taken of.
    if record.get("used_fallback"):
        out.append("A provider call failed during generation and the "
                   "deterministic generator filled in, so this Zone may "
                   "not be the one the preflight showed you.")
    if record.get("build", {}).get("tree") == "dirty":
        out.append("The checkout had uncommitted changes, so this "
                   "measurement cannot be placed against a commit.")
    return out


def report(save_dir: Path | None = None) -> int:
    from . import instrumentation as I
    from . import store

    directory = Path(save_dir) if save_dir else store.DEFAULT_SAVE_DIR
    records = I.read_records(directory)
    path = Path(directory) / I.PLAYTIME_FILENAME
    print()
    if not records:
        print(f"  No playtime records in {Path(directory).resolve()}")
        print()
        print("  A record is written when a Zone ENDS - walk back through")
        print("  the portal rather than closing the game, or the Zone has")
        print("  no end to time.")
        return 1

    print(f"  PLAYTIME  -  {len(records)} Zone"
          f"{'' if len(records) == 1 else 's'} recorded")
    print(f"  {path.resolve()}")
    for record in records:
        print()
        print("  " + "-" * 62)
        print()
        for line in _rows(record):
            print(line)
        flags = anomalies(record)
        print()
        if flags:
            print("  Worth looking at")
            print()
            for flag in flags:
                print(f"    - {flag}")
        else:
            print("  Nothing structurally odd.")
    print()
    print("  Nothing above has been tuned or acted on. What these numbers")
    print("  MEAN is the next conversation.")
    print()
    return 0


# ---------------------------------------------------------------------------

def _check(argv) -> int:
    problems = preflight_problems()
    print()
    if problems:
        print("  REFUSING TO START - this would not be a baseline playtest.")
        print()
        for problem in problems:
            print(f"    {problem}" if problem.startswith("  ")
                  else f"    - {problem}")
        print()
        print("  Nothing was changed. Send this to Claude.")
        print()
        return 1

    baseline = json.loads(BASELINE_PATH.read_text(encoding="utf-8"))
    scale = baseline["scale"]
    print("  BASELINE OK - the engine still builds the Zones the corpus")
    print("  recorded, and the campaign scale has not moved.")
    print()
    print(f"    campaign    {scale['location_count']} locations, "
          f"{scale['zone_target_checks']} Checks per Zone, "
          f"{scale['zone_budget']} budget")

    played = played_zone_digest()
    if not played:
        print()
        print("  Could not build the Zone you are about to play. Nothing")
        print("  was changed. Send this to Claude.")
        print()
        return 1
    print()
    print("  ZONE 1, which is the one you play:")
    print()
    print(f"    {played['rooms']} rooms, {played['checks']} Checks, "
          f"{played['enemies']} enemies, {played['value']} points")
    print(f"    themed {played['theme']} for {played['target_game']}")
    print(f"    id {played['digest']}")
    print()
    print("  That id is how the run after authored art is proved to be")
    print("  the SAME level. Write it down if you like; it is also in")
    print("  the playtime record.")
    print()
    return 0


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        prog="python -m archipepsi_bridge.playtest",
        description="Baseline playtest preflight and report.")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("check", help="refuse if the baseline has drifted")
    reporter = sub.add_parser("report", help="summarise what was played")
    reporter.add_argument("--save-dir", type=Path, default=None)
    args = parser.parse_args(argv)
    if args.command == "check":
        return _check(args)
    return report(args.save_dir)


if __name__ == "__main__":
    sys.exit(main())
