"""Build and version metadata, in one place, derivable without git.

Three consumers want slightly different things and used to each work it
out: the bridge banner prints a version, the client checks
`bridge_version` on the handshake and refuses a mismatch, and CI wants
something it can attach to a run. They now read one function.

Git is consulted when it is there and never required. A packaged build has
no `.git`, and a version that only works in a checkout is a version that
breaks exactly where it matters.
"""

from __future__ import annotations

import os
import platform
import subprocess
import sys
from pathlib import Path

from . import BRIDGE_VERSION

_ROOT = Path(__file__).resolve().parents[2]


def _git(*args: str) -> str | None:
    try:
        out = subprocess.run(("git", *args), cwd=_ROOT, capture_output=True,
                             text=True, timeout=5)
    except (OSError, subprocess.SubprocessError):       # pragma: no cover
        return None
    if out.returncode != 0:
        return None
    return out.stdout.strip() or None


def build_metadata() -> dict[str, str]:
    """What this build IS. Every value is a string, and every one of them
    is present even when git is not — `"unknown"` is information, and a
    missing key is a caller crash."""
    commit = _git("rev-parse", "--short=12", "HEAD") or "unknown"
    branch = _git("rev-parse", "--abbrev-ref", "HEAD") or "unknown"
    dirty = _git("status", "--porcelain")
    return {
        "bridge_version": BRIDGE_VERSION,
        "commit": commit,
        "branch": branch,
        # A build made from an edited tree is not the commit it claims,
        # and CI attaching "clean" to a dirty run would be a lie it told
        # every time someone reproduced a bug from an artifact.
        "tree": "dirty" if dirty else ("clean" if dirty == "" else "unknown"),
        "python": platform.python_version(),
        "platform": f"{platform.system()} {platform.machine()}",
        # Set by every CI provider worth the name; absent locally.
        "ci": os.environ.get("GITHUB_RUN_ID", "local"),
    }


def render() -> str:
    data = build_metadata()
    width = max(len(k) for k in data)
    return "\n".join(f"  {k.ljust(width)}  {v}" for k, v in data.items())


def main() -> None:
    print(render())
    if "--json" in sys.argv:
        import json
        print(json.dumps(build_metadata(), indent=2))


if __name__ == "__main__":
    main()
