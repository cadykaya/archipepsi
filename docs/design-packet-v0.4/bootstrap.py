#!/usr/bin/env python3
"""Obtain the pinned Archipelago checkout the bridge needs.

    python bootstrap.py [--root .archipelago] [--tag 0.6.7]

Resolves v0.4 decision D1. There is no pip-installable Archipelago
(`archipelago` on PyPI is an unrelated CGRA place-and-route tool), and
`CommonClient.py` imports `MultiServer`, `NetUtils`, `Utils` and `worlds`
at module load — so the bridge needs a real source tree on sys.path, not a
package.

Idempotent: safe to re-run. Honors ARCHIPELAGO_ROOT if the developer
already runs Archipelago from source.

Copy this into `bridge/` alongside the packet's `schemas/`.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

AP_REPO = "https://github.com/ArchipelagoMW/Archipelago"
AP_TAG = "0.6.7"
MIN_PY = (3, 11, 9)
MAX_PY = (3, 14)


def fail(msg: str) -> None:
    print(f"\n  bootstrap failed: {msg}\n", file=sys.stderr)
    raise SystemExit(1)


def run(cmd: list[str], cwd: Path | None = None) -> None:
    print(f"  $ {' '.join(cmd)}")
    result = subprocess.run(cmd, cwd=cwd)
    if result.returncode != 0:
        fail(f"command exited {result.returncode}")


def check_python() -> None:
    v = sys.version_info[:3]
    if not (MIN_PY <= v < MAX_PY):
        fail(
            f"Archipelago {AP_TAG} needs Python >= "
            f"{'.'.join(map(str, MIN_PY))} and < {'.'.join(map(str, MAX_PY))}; "
            f"this is {'.'.join(map(str, v))}"
        )
    print(f"  python {'.'.join(map(str, v))} ok")


def ensure_checkout(root: Path, tag: str) -> Path:
    if (env := os.environ.get("ARCHIPELAGO_ROOT")):
        existing = Path(env).expanduser().resolve()
        if not (existing / "CommonClient.py").is_file():
            fail(f"ARCHIPELAGO_ROOT={existing} has no CommonClient.py")
        print(f"  using ARCHIPELAGO_ROOT: {existing}")
        return existing

    if not shutil.which("git"):
        fail("git is required to clone Archipelago")

    if (root / "CommonClient.py").is_file():
        print(f"  reusing checkout at {root}")
        run(["git", "fetch", "--tags", "--depth", "1", "origin", tag], cwd=root)
        run(["git", "checkout", "--force", tag], cwd=root)
    else:
        print(f"  cloning Archipelago {tag} into {root}")
        root.parent.mkdir(parents=True, exist_ok=True)
        run(["git", "clone", "--depth", "1", "--branch", tag, AP_REPO, str(root)])

    return root.resolve()


def install_ap_requirements(ap_root: Path) -> None:
    # ModuleUpdate is Archipelago's own dependency installer. --yes skips its
    # interactive prompt, which would otherwise hang an unattended run.
    run([sys.executable, "ModuleUpdate.py", "--yes"], cwd=ap_root)


def verify(ap_root: Path) -> None:
    probe = (
        "import sys; sys.path.insert(0, r'%s');"
        "import CommonClient, Utils;"
        "print('  CommonContext ok, Archipelago', Utils.__version__)" % ap_root
    )
    result = subprocess.run([sys.executable, "-c", probe], capture_output=True, text=True)
    if result.returncode != 0:
        fail(
            "could not import CommonClient from the checkout:\n"
            + (result.stderr or "").strip()
        )
    print(result.stdout.rstrip())


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".archipelago", type=Path)
    parser.add_argument("--tag", default=AP_TAG)
    parser.add_argument(
        "--skip-requirements", action="store_true",
        help="skip ModuleUpdate.py (offline, or deps already installed)",
    )
    args = parser.parse_args()

    print(f"\nArchipepsi bootstrap - Archipelago {args.tag}\n")
    check_python()
    ap_root = ensure_checkout(args.root, args.tag)
    if not args.skip_requirements:
        install_ap_requirements(ap_root)
    verify(ap_root)

    print(
        f"\n  ready. Set ARCHIPELAGO_ROOT={ap_root} or leave the default,\n"
        f"  then run the bridge with `python -m archipepsi_bridge`.\n"
    )


if __name__ == "__main__":
    main()
