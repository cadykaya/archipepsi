"""Bridge entry point.

    python -m archipepsi_bridge [--ap=real|mock] [--epsilon=claude|mock|fallback]

Two independent axes (TECHNICAL_ARCHITECTURE §10.3). Real AP + fallback
Epsilon is the most valuable test configuration in the project.
"""

from __future__ import annotations

import argparse
import asyncio
import errno
import logging
import os
from pathlib import Path

from .campaign import CampaignEngine
from .epsilon import make_provider
from . import BRIDGE_VERSION
from .schemas import constants as C
from .server import BridgeServer

#: Named scales a mock campaign can be created at. Named rather than
#: numeric on purpose: these are the two configurations the project
#: actually supports and tests, and a free `--locations=137` would invite
#: a campaign nothing has ever been measured at.
MOCK_SCALES = {
    "prototype": C.PROTOTYPE_CONFIG,
    "default": C.DEFAULT_CONFIG,
}


def resolve_provider_name(requested: str) -> str:
    """Which provider will actually run, given the environment.

    Its own function because asking for `claude` without a key is the
    single most likely first-run mistake, and the behaviour has to be
    exactly this: never fail, never fall back silently. A player whose
    Echoes all read flat needs to be able to find out why, and the answer
    is one line at startup rather than a debugging session.
    """
    if requested == "claude" and not os.environ.get("ANTHROPIC_API_KEY"):
        logging.getLogger("archipepsi").warning(
            "EPSILON DOWNGRADE: --epsilon=claude but ANTHROPIC_API_KEY is "
            "absent; live campaigns will use the deterministic fallback")
        return "fallback"
    return requested


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ap", choices=("real", "mock"), default="real")
    parser.add_argument(
        "--epsilon", choices=("claude", "mock", "fallback"),
        default=os.environ.get("EPSILON_PROVIDER", "fallback"))
    parser.add_argument(
        "--mock-scale", choices=tuple(MOCK_SCALES), default="prototype",
        help="the campaign scale a MOCK campaign is created at. The "
             "prototype's thirty locations by default, which is what "
             "MOCK CAMPAIGN has always meant. `default` is the "
             "450-location production scale, and is what the pre-art "
             "playtest baseline was taken at. Ignored for real AP, "
             "where the seed decides.")
    parser.add_argument("--save-dir", type=Path, default=None)
    parser.add_argument("--archive-dir", type=Path, default=None,
                        help="save every generation for the benchmark archive")
    parser.add_argument(
        "--port", type=int, default=None,
        help="WebSocket port for Godot to connect to (default: the "
             "generated BRIDGE_PORT). Two Archipepsi slots in one "
             "multiworld need two bridges, and on one machine they need "
             "two ports.")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s %(name)s %(levelname)s %(message)s")

    provider_name = resolve_provider_name(args.epsilon)

    engine = CampaignEngine(
        provider=make_provider(provider_name),
        provider_name=provider_name,
        save_dir=args.save_dir,
        archive_dir=args.archive_dir)
    server = BridgeServer(engine, ap_default=args.ap,
                          mock_config=MOCK_SCALES[args.mock_scale],
                          **({} if args.port is None
                             else {"port": args.port}))
    _announce(engine, server, provider_name, args)
    try:
        asyncio.run(server.serve_forever())
    except OSError as exc:
        if exc.errno not in (errno.EADDRINUSE, errno.EACCES):
            raise
        # The single most likely error a player will ever hit, and the
        # one a traceback explains worst: a bridge is ALREADY running,
        # usually in a window they forgot behind the game. Python's own
        # wording for it is "[Errno 98] error while attempting to bind on
        # address ('127.0.0.1', 38290)" under fifteen frames of asyncio,
        # which reads as a crash rather than as "you already have one".
        raise SystemExit(
            f"\n  Another program is already using port {server.port}.\n"
            "\n"
            "  This is almost always a bridge you started earlier and\n"
            "  left running -- check for another terminal window. That\n"
            "  one still works; you do not need this one.\n"
            "\n"
            "  If you would rather start fresh, close the other window\n"
            "  and run this again. To deliberately run a second bridge\n"
            "  (a second Archipepsi slot on this machine), give it its\n"
            f"  own port: --port={server.port + 1}\n") from None
    except KeyboardInterrupt:
        # Ctrl-C is how a player stops the bridge. It is the documented
        # way to quit, so it should not print a stack trace as though
        # something went wrong.
        raise SystemExit("\n  Bridge stopped.\n") from None


def _zone_line(args, provider_name: str) -> str:
    """The id of the Zone this configuration builds, on the window that
    STAYS OPEN.

    `playtest check` already prints it, in the launcher window, thirty
    lines above the instructions -- so by the time anyone is playing it
    has scrolled away, which is exactly when they want it. The bridge
    window is up for the whole run and has room for one more line.

    Only for a MOCK campaign on the deterministic provider. Against a
    real server the Zone is a function of the seed, and against a live
    Epsilon it is a function of what the model said; in both cases an id
    computed here would describe a Zone nobody is going to walk.

    Never fatal. This is a convenience on a banner, and a banner that
    can stop the bridge starting is a worse trade than a missing line.
    """
    if args.ap == "real" or provider_name != "fallback":
        return ""
    try:
        from .playtest import played_zone_digest
        played = played_zone_digest()
    except Exception:                                    # pragma: no cover
        return ""
    if not played:
        return ""
    return (f"    zone 1      {played['digest']}"
            f"   ({played['rooms']} rooms, {played['checks']} Checks, "
            f"{played['value']} points)\n")


def _ap_line(args) -> str:
    """The AP line of the banner, with the mock's SCALE on it.

    A mock campaign at thirty locations and one at 450 are different
    games, and the difference is invisible until Zone 4 arrives with
    three Checks in it. The playtest baseline is taken at 450, so the
    one thing a playtester must be able to see at a glance is which of
    the two they are about to walk.
    """
    if args.ap == "real":
        return "real server"
    config = MOCK_SCALES[args.mock_scale]
    # ASCII: this prints into a console the launcher did not `chcp`,
    # because `start` gives the bridge a fresh window with the system
    # default code page.
    return (f"MOCK - offline fixture campaign, {args.mock_scale} scale "
            f"({config.location_count} locations, "
            f"{config.zone_target_checks} Checks per Zone)")


def _announce(engine, server, provider_name: str, args) -> None:
    """Four lines, before the event loop starts.

    A bridge that says only "listening on 38290" leaves a player with no
    way to answer the three questions they will actually have: which
    Epsilon is running (an Echo that reads flat is a provider question,
    not a bug), whether they are on a real multiworld or the offline
    fixture, and where the save is (to back it up, to delete it, or to
    understand why last night's campaign did not come back).

    That last one is the one worth printing every time. `DEFAULT_SAVE_DIR`
    is `Path.cwd() / "saves"` unless `ARCHIPEPSI_SAVE_DIR` says otherwise,
    so it depends on the directory the bridge was STARTED from: `make
    bridge` runs from `bridge/`, and the same command run from the repo
    root writes somewhere else. Both are correct and they are different
    campaigns; printing the resolved absolute path is what makes that
    visible rather than mysterious.
    """
    from .version import build_metadata
    build = build_metadata()
    save_dir = Path(engine.save_dir).resolve()
    epsilon = provider_name
    if args.epsilon == "claude" and provider_name != "claude":
        epsilon = "fallback (no ANTHROPIC_API_KEY)"
    print(
        f"\n  Archipepsi bridge v{BRIDGE_VERSION}"
        f"  ({build['commit']}{'*' if build['tree'] == 'dirty' else ''})\n"
        f"    listening   ws://{server.host}:{server.port}"
        f"   (Godot connects here)\n"
        f"    archipelago {_ap_line(args)}\n"
        f"    epsilon     {epsilon}\n"
        f"    saves       {save_dir}\n"
        f"{_zone_line(args, provider_name)}",
        flush=True)
    if not save_dir.exists():
        print(f"    (no campaign there yet; it is created on first "
              f"connect)\n", flush=True)


if __name__ == "__main__":
    main()
