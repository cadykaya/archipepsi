"""THE UNIFIED INTEGRATION 1 LAUNCHER (owner, 2026-10-16).

The D-22 slice's launcher (`tools/d22_slice_launch.py`), reused rather
than copied: the same bridge with the same arguments (mock Archipelago,
prototype scale, Epsilon's offline fallback, `--d22-slice`), so the loop's
saves and progression are exactly the slice's. Three differences only:

* Godot gets `--unified` as well (the weapons, the Freight Bay, the music);
* its own save folder, ``saves-unified-1``, so neither the player's
  campaign (``bridge/saves``) nor a D-22 slice run is read or written;
* its own banner.

Usage (the .bat / .sh wrappers call this):

    python tools/unified_launch.py --godot PATH [--fresh] [--dry-run]
"""
from __future__ import annotations

import argparse
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import d22_slice_launch as slice_launch  # noqa: E402

ROOT = slice_launch.ROOT
SAVES = ROOT / "saves-unified-1"
GODOT_FLAG = "--unified"


def godot_command(godot: str) -> list[str]:
    return [*slice_launch.godot_command(godot), GODOT_FLAG]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--godot", required=True)
    parser.add_argument("--fresh", action="store_true",
                        help="rename the save folder aside first")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)

    print()
    print("  ARCHIPEPSI - UNIFIED INTEGRATION 1 (review build, offline)")
    print("  ===========================================================")
    print("  The D-22 loop, the five weapons on keys 1-5, the Freight Bay")
    print("  and its Shunter, and Condi's music. Nothing here is the campaign.")
    print()
    print(f"  saves   {SAVES}   (bridge/saves is not touched)")
    print(f"  bridge  {' '.join(slice_launch.BRIDGE_ARGS)}")
    print(f"  godot   {' '.join(godot_command(args.godot))}")
    print()
    if args.dry_run:
        print("  --dry-run: nothing started.")
        return 0
    if slice_launch.port_in_use():
        print("  Another bridge is already running on port 38290 (the "
              "ordinary game, or the D-22 slice?).")
        print("  Close it first: this build needs its own bridge and its "
              "own saves.")
        return 1
    if args.fresh:
        aside = slice_launch.rotate_aside(SAVES)
        if aside is not None:
            print(f"  --fresh: the previous run was kept as {aside.name}")
    SAVES.mkdir(exist_ok=True)

    bridge = subprocess.Popen(slice_launch.bridge_command(SAVES),
                              cwd=ROOT / "bridge")
    try:
        for _ in range(100):
            if slice_launch.bridge_answers():
                break
            if bridge.poll() is not None:
                print("  The bridge stopped while starting; its error is "
                      "above.")
                return 1
            time.sleep(0.1)
        print("  Bridge up. Starting the game...")
        return subprocess.call(godot_command(args.godot))
    finally:
        bridge.terminate()
        try:
            bridge.wait(timeout=5)
        except subprocess.TimeoutExpired:
            bridge.kill()
        print("  The game has closed; its bridge is stopped.")


if __name__ == "__main__":
    sys.exit(main())
