"""The diagnostic campaign: one entry point, one save folder, on purpose.

    python -m archipepsi_bridge.diagnostic [--slot NAME] [--new] [--list]

WHY THIS EXISTS. `Start Archipepsi (Windows).bat` starts the bridge with
the defaults -- `--mock-scale=prototype` and `bridge/saves` -- and the
owner double-clicked it meaning to resume a DEFAULT-scale diagnostic
campaign held somewhere else. Both halves of that are silent: a
prototype campaign looks exactly like a default one until Zone 4 turns
up with three Checks in it, and a save folder is only mentioned in a
banner line that has scrolled away by the time anyone is playing.

So this fixes the three things that run has to get right -- mock AP,
the deterministic Epsilon, and the DEFAULT scale -- and makes the save
folder the one thing you choose, by name, without editing a command.

WHAT IT DELIBERATELY DOES NOT DO. It never deletes, moves or truncates a
save; there is no reset switch here at all, and a slot that already has
a campaign in it is RESUMED and said so. It never writes to
`bridge/saves`, so an ordinary campaign cannot be caught by a diagnostic
run. It does not update, fetch, check out or reset the repository --
that is `Update Archipepsi`, and a launcher that also moved you between
commits would be a launcher nobody could trust with a bug report. And it
does not stop anything it finds on the port: a bridge already running is
reported, with what to do, and left alone.

The bridge's OWN parser and banner do the rest. This builds an argument
vector and calls `archipepsi_bridge.__main__.main()` in-process, so the
port-conflict message, the Epsilon downgrade warning, the resolved save
path and the scale line are all the real ones rather than a second
copy that drifts.
"""

from __future__ import annotations

import argparse
import socket
import sys
from pathlib import Path

from .version import build_metadata

#: Where the diagnostic slots live: beside the repository, one folder per
#: slot, and named so `.diagnostic-582e954` -- the folder the owner
#: already has -- is one of them rather than a special case.
SLOT_PREFIX = ".diagnostic-"

#: The slot a plain double-click resumes. A NAME rather than a revision:
#: the whole point is that the same folder comes back tomorrow, and a
#: default that moved with HEAD would start a new campaign every commit.
DEFAULT_SLOT = "current"

#: The slot the LOWER-BUDGET VARIANT resumes. A different name on
#: purpose: the two modes genuinely compose different Zones -- different
#: rooms, not the same rooms with two drills taken out -- so sharing one
#: folder would put both into a single campaign history and make the
#: comparison unreadable.
QUIET_DEFAULT_SLOT = "quiet"

#: Written into a slot the first time a quieter run starts in it, and
#: read on every later run. A slot REMEMBERS which mode made it, so
#: `--quiet` cannot be pointed at an ordinary campaign (the owner's
#: `.diagnostic-582e954` among them) and an ordinary run cannot be
#: pointed at a quieter one. Its content is the note, not a format.
QUIET_MARKER = ".quiet-generation"

#: The configuration this entry point exists to pin. Every one of these
#: was wrong or absent in the run that prompted it.
FIXED_ARGS = ("--ap=mock", "--epsilon=fallback", "--mock-scale=default")

#: Arguments the caller may not pass through, because this entry point is
#: the thing that decides them. Passing `--mock-scale=prototype` here
#: would reintroduce exactly the confusion it exists to remove.
RESERVED = ("--ap", "--epsilon", "--mock-scale", "--save-dir",
            "--quiet-generation")


def repo_root() -> Path:
    """The checkout this module was imported from.

    `parents[2]` from `bridge/archipepsi_bridge/diagnostic.py`, the same
    walk `version.py` does, so a launcher started from any directory
    resolves the same slots.
    """
    return Path(__file__).resolve().parents[2]


def slot_dir(slot: str, root: Path | None = None) -> Path:
    """The folder for one slot, validated.

    A slot is a NAME, not a path. Rejecting separators here is what stops
    `--slot ../saves` from writing a diagnostic campaign into an ordinary
    one -- and stops `--slot ""` resolving to the repository root, which
    is the version of that mistake that would be hardest to notice.
    """
    if not slot or slot != slot.strip():
        raise ValueError("a slot name cannot be empty or padded")
    if any(c in slot for c in "/\\:"):
        raise ValueError(
            f"{slot!r} is a path, not a slot name. A slot is a single "
            "name such as 582e954; the folder is chosen for you.")
    if slot in (".", ".."):
        raise ValueError(f"{slot!r} is not a slot name")
    return (root or repo_root()) / f"{SLOT_PREFIX}{slot}"


def existing_slots(root: Path | None = None) -> list[tuple[str, Path]]:
    """Every diagnostic slot already on disk, oldest name first."""
    base = root or repo_root()
    found = []
    for path in sorted(base.glob(f"{SLOT_PREFIX}*")):
        if path.is_dir():
            found.append((path.name[len(SLOT_PREFIX):], path))
    return found


def slot_is_occupied(path: Path) -> bool:
    """Does this slot already hold a campaign?

    Any file at all. The question being asked is "would starting here
    continue something", and being wrong in the cautious direction costs
    one printed word.
    """
    return path.is_dir() and any(path.iterdir())


def slot_mode(path: Path) -> str:
    """What this slot was made as: `"quiet"` or `"normal"`.

    An EMPTY slot has no mode yet and answers `"normal"`, which is only
    ever compared against when the slot is occupied -- see
    `refuse_mode_mismatch`. A slot that predates the marker (every slot
    that exists today, the owner's included) therefore reads as the
    ordinary campaign it is.
    """
    return "quiet" if (path / QUIET_MARKER).exists() else "normal"


def refuse_mode_mismatch(path: Path, want_quiet: bool) -> None:
    """Refuse to continue a campaign in the other mode. Never converts.

    THE SAVE IS NOT TOUCHED EITHER WAY. This raises before anything is
    created, started or written, because the failure it prevents is the
    one that cannot be undone: a quieter run appending Zones to a
    campaign that was recorded as ordinary evidence.
    """
    if not slot_is_occupied(path):
        return
    have = slot_mode(path)
    want = "quiet" if want_quiet else "normal"
    if have == want:
        return
    other = "without --quiet" if have == "normal" else "with --quiet"
    raise ValueError(
        f"{path.name} already holds a {have.upper()} campaign and this "
        f"run is {want.upper()}.\n"
        f"  Nothing has been read, written or started.\n"
        f"  Resume it {other}, or choose another slot with --slot NAME.\n"
        f"  The two modes compose different Zones; mixing them into one "
        f"campaign is what this refuses.")


def mark_quiet(path: Path) -> None:
    """Record that this slot is the quieter one. Written once, on start."""
    marker = path / QUIET_MARKER
    if marker.exists():
        return
    marker.write_text(
        "This diagnostic slot holds a LOWER-BUDGET GENERATION VARIANT "
        "campaign (follow-up 02 item D).\n"
        "Zones composed here were offered fewer activity families AND "
        "built to a smaller band,\n"
        "which also gave them more rooms and more enemies than the "
        "baseline would have.\n"
        "They are not the baseline Zones with two drills removed.\n"
        "Resume it with the same launcher switch. Deleting this file "
        "does not convert the campaign;\n"
        "it only removes the guard that keeps the two modes apart.\n")


def fresh_slot_name(root: Path | None = None,
                    commit: str | None = None) -> str:
    """A slot name for `--new` that is not already taken.

    Named for the revision, because the one question asked of an old
    diagnostic folder is always "which build was this". A suffix is added
    rather than reusing the folder: `--new` promises a fresh campaign,
    and quietly resuming would be the opposite of what was asked.
    """
    base = commit or build_metadata()["commit"][:7]
    taken = {name for name, _ in existing_slots(root)}
    if base not in taken:
        return base
    for n in range(2, 100):
        candidate = f"{base}-{n}"
        if candidate not in taken:
            return candidate
    raise RuntimeError("99 slots already exist for this revision")


def bridge_argv(save_dir: Path, extra: list[str] | None = None) -> list[str]:
    """The argument vector handed to the real bridge parser.

    ONE ELEMENT PER ARGUMENT, and that is the load-bearing property. A
    launcher that builds a command STRING has to quote the save path, and
    the owner's checkout lives under `C:\\Users\\...\\Documents\\GitHub`
    -- one `Program Files` away from a path with a space in it splitting
    into two arguments and the campaign landing in `C:\\Users\\Kaya`.
    `--save-dir` and its value stay separate so no quoting exists to get
    wrong.
    """
    argv = ["archipepsi_bridge", *FIXED_ARGS, "--save-dir", str(save_dir)]
    for arg in extra or []:
        head = arg.split("=", 1)[0]
        if head in RESERVED:
            raise ValueError(
                f"{head} is decided by the diagnostic launcher and cannot "
                "be passed to it. Use --slot to choose the save folder.")
        argv.append(arg)
    return argv


def port_in_use(port: int, host: str = "127.0.0.1") -> bool:
    """Is something already listening there?

    Asked BEFORE starting so the answer arrives as a sentence rather than
    as a bind error under fifteen frames of asyncio. Nothing is done
    about it either way -- the other bridge may be the one being played.
    """
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.settimeout(0.4)
        try:
            return probe.connect_ex((host, port)) == 0
        except OSError:                                  # pragma: no cover
            return False


def missing_prerequisites() -> list[str]:
    """The imports the bridge needs, checked by name rather than by
    crashing halfway through startup."""
    missing = []
    for module in ("pydantic", "websockets"):
        try:
            __import__(module)
        except ImportError:
            missing.append(module)
    return missing


def describe(slot: str, path: Path, resuming: bool,
             quiet_generation: bool = False) -> str:
    """The three facts the run that prompted this could not answer: which
    build, which scale, and which folder -- and, since follow-up 02, a
    fourth: whether this campaign is the quieter preview."""
    meta = build_metadata()
    state = "RESUMING an existing campaign" if resuming \
        else "NEW campaign (this folder is empty)"
    title = "DIAGNOSTIC CAMPAIGN (LOWER-BUDGET VARIANT)" \
        if quiet_generation else "DIAGNOSTIC CAMPAIGN"
    mode = ("    generation  LOWER-BUDGET VARIANT (opt-in preview)\n"
            "                two drill families not offered, their share "
            "not\n"
            "                spent elsewhere -- and a smaller band that "
            "also buys\n"
            "                MORE rooms, MORE enemies, and DIFFERENT "
            "rooms.\n"
            "                Not the same level with the drills removed.\n"
            if quiet_generation else "")
    return (
        f"\n  ARCHIPEPSI - {title}\n"
        "  " + "=" * (len(title) + 12) + "\n"
        f"    build       {meta['commit']} on {meta['branch']} "
        f"({meta['tree']} tree)\n"
        "    campaign    MOCK, default scale (450 locations)\n"
        "    epsilon     fallback (deterministic)\n"
        + mode +
        f"    slot        {slot}\n"
        f"    save folder {path}\n"
        f"    state       {state}\n")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="python -m archipepsi_bridge.diagnostic",
        description=__doc__.split("\n\n")[0])
    group = parser.add_mutually_exclusive_group()
    group.add_argument(
        "--slot", default=None,
        help=f"which diagnostic save folder to use (default: "
             f"{DEFAULT_SLOT}). An existing slot is RESUMED, never reset.")
    group.add_argument(
        "--new", action="store_true",
        help="start a campaign in a fresh slot named for this revision. "
             "Never reuses a slot that already has saves in it.")
    parser.add_argument(
        "--quiet", action="store_true",
        help="run the LOWER-BUDGET GENERATION VARIANT (follow-up 02 "
             f"item D) in its own slot, {QUIET_DEFAULT_SLOT!r} by "
             "default. New Zones are offered neither standalone drill "
             "family and are built to a smaller band. NOT the same "
             "level with the drills removed -- it also composes more "
             "rooms, more enemies and different rooms. A slot remembers "
             "which mode made it and this refuses to mix them, so an "
             "ordinary campaign cannot be continued here.")
    parser.add_argument(
        "--list", action="store_true",
        help="list the diagnostic slots on disk and exit")
    parser.add_argument(
        "--dry-run", action="store_true",
        help="print what would be started, and start nothing")
    parser.add_argument(
        "--port", type=int, default=None,
        help="passed through to the bridge; also the port checked for a "
             "bridge that is already running")
    return parser


def resolve(args, root: Path | None = None) -> tuple[str, Path, bool]:
    """Slot name, folder and whether it is a resume.

    `--quiet` changes only the DEFAULT: an explicit `--slot` is still
    the slot you asked for, and `--new` still names itself for the
    revision. What keeps the two modes apart is the marker check below,
    not the name, because a name is advice and a marker is a fact.
    """
    want_quiet = getattr(args, "quiet", False)
    if args.new:
        slot = fresh_slot_name(root)
        if want_quiet:
            slot = f"{slot}-quiet"
    else:
        slot = args.slot or (QUIET_DEFAULT_SLOT if want_quiet
                             else DEFAULT_SLOT)
    path = slot_dir(slot, root)
    refuse_mode_mismatch(path, want_quiet)
    return slot, path, slot_is_occupied(path)


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)

    if args.list:
        slots = existing_slots()
        if not slots:
            print("  No diagnostic slots yet. One is made on first run.")
            return 0
        print("  Diagnostic slots:")
        for name, path in slots:
            files = len(list(path.glob("*"))) if path.is_dir() else 0
            print(f"    {name.ljust(24)} {files} file(s)   {path}")
        return 0

    missing = missing_prerequisites()
    if missing:
        print("\n  The bridge needs these and they are not installed:\n")
        for module in missing:
            print(f"    {module}")
        print("\n  Install them with:\n"
              f"    {Path(sys.executable).name} -m pip install "
              + " ".join(missing) + "\n")
        return 2

    try:
        slot, path, resuming = resolve(args)
    except (ValueError, RuntimeError) as exc:
        print(f"\n  {exc}\n")
        return 2

    print(describe(slot, path, resuming, args.quiet))

    from .schemas import constants as C
    port = args.port or C.BRIDGE_PORT
    if port_in_use(port):
        print(f"  A bridge is ALREADY running on port {port}.\n"
              "\n"
              "  That is usually a window left open behind the game, and\n"
              "  it still works -- you do not need this one. Nothing has\n"
              "  been started or changed here.\n"
              "\n"
              "  To run a second bridge on purpose, give it its own port:\n"
              f"    --port={port + 1}\n")
        return 1

    extra = [] if args.port is None else [f"--port={args.port}"]
    # THE LAUNCHER DECIDES THIS ONE. `--quiet-generation` is in
    # `RESERVED`, so it cannot arrive as a pass-through and end up on a
    # run whose slot and banner say ordinary; the only way to it is the
    # `--quiet` switch that also chose the slot and checked the marker.
    argv_out = bridge_argv(path, extra)
    if args.quiet:
        argv_out.append("--quiet-generation")
    if args.dry_run:
        print("  Would run:\n    " + " ".join(argv_out[1:]) + "\n")
        return 0

    # NOT created until we are actually going to start. A `--dry-run` or
    # a refused port that left an empty folder behind would turn the next
    # run's honest "NEW campaign" into a lie.
    path.mkdir(parents=True, exist_ok=True)
    if args.quiet:
        mark_quiet(path)

    from .__main__ import main as bridge_main
    sys.argv = argv_out
    bridge_main()
    return 0


if __name__ == "__main__":                               # pragma: no cover
    raise SystemExit(main())
