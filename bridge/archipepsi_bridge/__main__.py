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
from .server import BridgeServer


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

    provider_name = args.epsilon
    if provider_name == "claude" and not os.environ.get("ANTHROPIC_API_KEY"):
        logging.getLogger("archipepsi").warning(
            "EPSILON DOWNGRADE: --epsilon=claude but ANTHROPIC_API_KEY is "
            "absent; live campaigns will use the deterministic fallback")
        provider_name = "fallback"

    engine = CampaignEngine(
        provider=make_provider(provider_name),
        provider_name=provider_name,
        save_dir=args.save_dir,
        archive_dir=args.archive_dir)
    server = BridgeServer(engine, ap_default=args.ap,
                          **({} if args.port is None
                             else {"port": args.port}))
    asyncio.run(server.serve_forever())


if __name__ == "__main__":
    main()
