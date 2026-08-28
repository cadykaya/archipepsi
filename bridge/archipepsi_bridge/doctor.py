#!/usr/bin/env python3
"""Preflight for a fresh clone: what is missing, and what is optional.

    make doctor

CI found the first fresh-clone break (`make setup` silently installing
nothing, because the Makefile's `SKIP_REQUIREMENTS_UPDATE` reached the
installer). The point of a preflight is that the NEXT one gets reported
here rather than discovered four steps later with a confusing error.

Distinguishes REQUIRED from OPTIONAL deliberately. The single most
discouraging thing a first run can do is present a working setup as
broken -- Archipepsi plays perfectly well with no API key, on the
fallback provider, and saying so is part of the job.

Exit code is 1 only if something REQUIRED is missing.
"""

from __future__ import annotations

import os
import shutil
import socket
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

OK = "  ok      "
MISSING = "  MISSING "
NOTE = "  note    "


def _check_python() -> tuple[bool, str]:
    v = sys.version_info[:3]
    text = ".".join(map(str, v))
    if (3, 11, 9) <= v < (3, 14):
        return True, f"python {text}"
    return False, (f"python {text}; Archipelago 0.6.7 needs >= 3.11.9 "
                   f"and < 3.14")


def _check_archipelago() -> tuple[bool, str]:
    root = Path(os.environ.get("ARCHIPELAGO_ROOT", ROOT / ".archipelago"))
    if (root / "CommonClient.py").is_file():
        return True, f"Archipelago checkout at {root}"
    return False, (f"no Archipelago checkout at {root}; run `make setup`")


def _check_ap_requirements() -> tuple[bool, str]:
    root = Path(os.environ.get("ARCHIPELAGO_ROOT", ROOT / ".archipelago"))
    if not (root / "CommonClient.py").is_file():
        return False, "cannot check Archipelago's requirements without it"
    probe = subprocess.run(
        [sys.executable, "-c",
         f"import sys; sys.path.insert(0, r'{root}'); import CommonClient"],
        env={**os.environ, "SKIP_REQUIREMENTS_UPDATE": "1"},
        stdin=subprocess.DEVNULL, capture_output=True, text=True)
    if probe.returncode == 0:
        return True, "Archipelago's requirements are installed"
    missing = ""
    if "ModuleNotFoundError" in (probe.stderr or ""):
        missing = (probe.stderr.strip().splitlines() or [""])[-1]
    return False, (f"Archipelago will not import: {missing}\n"
                   f"            pip install -r {root}/requirements.txt")


def _check_godot() -> tuple[bool, str]:
    binary = ROOT / "godot-bin" / "godot"
    found = str(binary) if binary.is_file() else shutil.which("godot")
    if not found:
        return False, ("no Godot binary at godot-bin/godot or on PATH; "
                       "the bridge runs without it, the game does not")
    out = subprocess.run([found, "--version"], capture_output=True, text=True)
    version = (out.stdout or "").strip().splitlines()
    reported = version[0] if version else "?"
    if not reported.startswith("4.5.1"):
        return False, (f"Godot {reported}; the project pins 4.5.1 and the "
                       f"suites are written against it")
    return True, f"Godot {reported}"


def _check_port() -> tuple[bool, str]:
    from .schemas import constants as C
    with socket.socket() as probe:
        probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            probe.bind((C.BRIDGE_HOST, C.BRIDGE_PORT))
        except OSError:
            return False, (
                f"port {C.BRIDGE_PORT} is already in use; another bridge "
                f"is probably running. Two players on one machine each "
                f"need their own port (see `make dual-real`)")
    return True, f"port {C.BRIDGE_PORT} is free"


def _check_api_key() -> tuple[bool, str]:
    if os.environ.get("ANTHROPIC_API_KEY"):
        return True, "ANTHROPIC_API_KEY is set; Epsilon will use Claude"
    return True, ("no ANTHROPIC_API_KEY. This is fine: Epsilon falls back "
                  "to the built-in interpreter and the game is fully "
                  "playable. Set it for richer readings.")


#: (label, check, required)
CHECKS = (
    ("python", _check_python, True),
    ("archipelago", _check_archipelago, True),
    ("requirements", _check_ap_requirements, True),
    ("godot", _check_godot, False),
    ("port", _check_port, False),
    ("epsilon", _check_api_key, False),
)


def main() -> int:
    print("\nArchipepsi preflight\n")
    broken = 0
    for label, check, required in CHECKS:
        try:
            ok, message = check()
        except Exception as exc:                      # noqa: BLE001
            ok, message = False, f"check raised {exc!r}"
        if ok:
            print(f"{OK}{message}")
        elif required:
            broken += 1
            print(f"{MISSING}{message}")
        else:
            print(f"{NOTE}{message}")
    if broken:
        print(f"\n  {broken} required thing(s) missing. Start with "
              f"`make setup`.\n")
        return 1
    print("\n  ready.\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
