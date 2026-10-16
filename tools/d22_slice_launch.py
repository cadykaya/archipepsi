"""THE D-22 SLICE LAUNCHER (`docs/D22_SLICE_BRIEF.md` §4, run configuration).

Starts the two halves the slice needs, the way the brief fixes them:

* the bridge: ``--ap=mock --mock-scale prototype --epsilon=fallback
  --d22-slice`` and its OWN save folder, ``saves-d22-slice`` at the top of
  the checkout. Never ``bridge/saves``: the player's campaign is not read,
  written or moved;
* Godot: ``-- --d22-slice``, which skips the menu and starts (or resumes)
  the mock campaign in that folder.

When Godot closes, the bridge is stopped. Nothing is deleted, ever:
``--fresh`` RENAMES an existing slice folder aside with a timestamp and
starts a new one.

Runs the same from a checkout and from the review build (an exported
executable beside `bridge/` and `tools/`).

Usage (the .bat / .sh wrappers call this):

    python tools/d22_slice_launch.py --godot PATH [--fresh] [--dry-run]
"""
from __future__ import annotations

import argparse
import socket
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SLICE_SAVES = ROOT / "saves-d22-slice"
BRIDGE_PORT = 38290
BRIDGE_ARGS = ["--ap=mock", "--mock-scale", "prototype",
               "--epsilon=fallback", "--d22-slice"]


def bridge_command(save_dir: Path) -> list[str]:
    return [sys.executable, "-m", "archipepsi_bridge", *BRIDGE_ARGS,
            "--save-dir", str(save_dir)]


def godot_command(godot: str) -> list[str]:
    # From a checkout, Godot runs the project folder; the review build's
    # exported executable carries its own pack and takes no `--path`.
    project = ROOT / "godot" / "project.godot"
    where = ["--path", str(project.parent)] if project.exists() else []
    return [godot, *where, "--", "--d22-slice"]


def port_in_use(port: int = BRIDGE_PORT) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.settimeout(0.5)
        return probe.connect_ex(("127.0.0.1", port)) == 0


def bridge_answers(port: int = BRIDGE_PORT) -> bool:
    """A real websocket handshake, opened and closed cleanly. A bare TCP
    probe works too, but the bridge logs it as a broken client with a
    traceback, and that is the first thing the player would read."""
    try:
        from websockets.sync.client import connect
    except ImportError:                      # an older websockets
        return port_in_use(port)
    try:
        with connect(f"ws://127.0.0.1:{port}", open_timeout=0.5):
            return True
    except OSError:
        return False
    except Exception:                        # handshake not ready yet
        return False


def rotate_aside(folder: Path) -> Path | None:
    """`--fresh`: the old slice folder is renamed, never removed."""
    if not folder.exists():
        return None
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    aside = folder.with_name(f"{folder.name}-{stamp}")
    folder.rename(aside)
    return aside


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--godot", required=True)
    parser.add_argument("--fresh", action="store_true",
                        help="rename the slice save folder aside first")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)

    print()
    print("  ARCHIPEPSI - D-22 SLICE (prototype loop, offline)")
    print("  =================================================")
    print("  Station 1 -> Forge -> Crossing 1 -> leave/resume -> untether")
    print("  -> station area 2 -> Forge -> Crossing 2 -> STOP")
    print()
    print(f"  saves   {SLICE_SAVES}   (bridge/saves is not touched)")
    print(f"  bridge  {' '.join(BRIDGE_ARGS)}")
    print(f"  godot   {args.godot}")
    print()
    if args.dry_run:
        print("  --dry-run: nothing started.")
        return 0
    if port_in_use():
        print("  Another bridge is already running on port 38290 (the "
              "ordinary game?).")
        print("  Close it first: the slice needs its own bridge and its "
              "own saves.")
        return 1
    if args.fresh:
        aside = rotate_aside(SLICE_SAVES)
        if aside is not None:
            print(f"  --fresh: the previous slice run was kept as {aside.name}")
    SLICE_SAVES.mkdir(exist_ok=True)

    bridge = subprocess.Popen(bridge_command(SLICE_SAVES),
                              cwd=ROOT / "bridge")
    try:
        for _ in range(100):
            if bridge_answers():
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
        print("  The slice has closed; its bridge is stopped.")


if __name__ == "__main__":
    sys.exit(main())
