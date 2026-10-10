"""Bridge entry point.

    python -m archipepsi_bridge [--ap=real|mock] [--epsilon=claude|mock|fallback]

Two independent axes (TECHNICAL_ARCHITECTURE §10.3). Real AP + fallback
Epsilon is the most valuable test configuration in the project.
"""

from __future__ import annotations

import argparse
import asyncio
import logging
import os
from pathlib import Path

from .campaign import CampaignEngine
from .epsilon import make_provider
from . import BRIDGE_VERSION
from .server import BridgeServer


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
                          **({} if args.port is None
                             else {"port": args.port}))
    _announce(engine, server, provider_name, args)
    asyncio.run(server.serve_forever())


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
        f"    archipelago {'real server' if args.ap == 'real' else 'MOCK — offline fixture campaign'}\n"
        f"    epsilon     {epsilon}\n"
        f"    saves       {save_dir}\n",
        flush=True)
    if not save_dir.exists():
        print(f"    (no campaign there yet; it is created on first "
              f"connect)\n", flush=True)


if __name__ == "__main__":
    main()
