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
    """Stripped stdout, or None when git could not answer.

    An EMPTY answer is not None. `git status --porcelain` returns nothing
    for a clean tree, and collapsing that into None made "clean"
    unreachable — every clean checkout reported its tree as `unknown`,
    including CI's.
    """
    try:
        out = subprocess.run(("git", *args), cwd=_ROOT, capture_output=True,
                             text=True, timeout=5)
    except (OSError, subprocess.SubprocessError):       # pragma: no cover
        return None
    if out.returncode != 0:
        return None
    return out.stdout.strip()


def build_metadata() -> dict[str, str]:
    """What this build IS. Every value is a string, and every one of them
    is present even when git is not — `"unknown"` is information, and a
    missing key is a caller crash."""
    commit = _git("rev-parse", "--short=12", "HEAD") or "unknown"
    branch = _git("rev-parse", "--abbrev-ref", "HEAD") or "unknown"
    # `--untracked-files=no` on purpose. The question this answers is
    # "does this build's code differ from the commit it claims", and an
    # untracked file does not change that. Without it an editable install
    # (`pip install -e`) leaves an `.egg-info` behind and every CI run
    # reported itself dirty.
    dirty = _git("status", "--porcelain", "--untracked-files=no")
    return {
        "bridge_version": BRIDGE_VERSION,
        "commit": commit,
        "branch": branch,
        # A build made from an edited tree is not the commit it claims,
        # and CI attaching "clean" to a dirty run would be a lie it told
        # every time someone reproduced a bug from an artifact.
        "tree": "unknown" if dirty is None else ("dirty" if dirty else "clean"),
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
