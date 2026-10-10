#!/usr/bin/env python3
"""Import Condi's five-weapon SigmAudio handoff into the Godot project.

Source of truth: ``handoff/five_weapon_audio/`` (Condi's folder, byte for
byte from her handoff commit). This script never edits it. It:

1. checks every delivered WAV against her ``wav/SHA256SUMS.txt``;
2. copies the WAVs and ``events.json`` unchanged into
   ``godot/audio/sigmaudio/five_weapons/``;
3. writes each WAV's Godot import settings: uncompressed PCM (her samples
   play as delivered, not re-encoded), no trim, no normalise, and the loop
   points ``events.json`` gives;
4. writes ``PROVENANCE.json`` (source folder, handoff commit, hashes).

``--check`` changes nothing and fails if the Godot copy has drifted from
the handoff. Run Godot's ``--import`` afterwards to (re)build the import
cache; it adds a ``uid`` to each ``.import`` file, which this script keeps.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "handoff" / "five_weapon_audio"
DEST = ROOT / "godot" / "audio" / "sigmaudio" / "five_weapons"
HANDOFF_COMMIT = "63c78a9d"
RES_PREFIX = "res://audio/sigmaudio/five_weapons/"

IMPORT_TEMPLATE = """[remap]

importer="wav"
type="AudioStreamWAV"
{uid}path="res://.godot/imported/{name}-{md5}.sample"

[deps]

source_file="{res}"
dest_files=["res://.godot/imported/{name}-{md5}.sample"]

[params]

force/8_bit=false
force/mono=false
force/max_rate=false
force/max_rate_hz=44100
edit/trim=false
edit/normalize=false
edit/loop_mode={loop_mode}
edit/loop_begin={loop_begin}
edit/loop_end={loop_end}
compress/mode=0
"""


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sums() -> dict[str, str]:
    table = {}
    for line in (SOURCE / "wav" / "SHA256SUMS.txt").read_text().splitlines():
        if line.strip():
            digest, name = line.split(maxsplit=1)
            table[name.strip()] = digest
    return table


def loops(events: dict) -> dict[str, dict]:
    found = {}
    for event in events["events"]:
        if "loop" in event:
            found[event["file"]] = event["loop"]
    return found


def import_text(name: str, loop: dict | None, existing: Path) -> str:
    uid = ""
    if existing.is_file():
        for line in existing.read_text().splitlines():
            if line.startswith("uid="):
                uid = line + "\n"
    res = RES_PREFIX + name
    md5 = hashlib.md5(res.encode()).hexdigest()
    return IMPORT_TEMPLATE.format(
        uid=uid, name=name, md5=md5, res=res,
        loop_mode=1 if loop else 0,
        loop_begin=int(loop["begin_frame"]) if loop else 0,
        loop_end=int(loop["end_frame"]) if loop else -1)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true",
                        help="verify only; change nothing")
    args = parser.parse_args()

    table = sums()
    problems = []
    for name, digest in table.items():
        got = sha256(SOURCE / "wav" / name)
        if got != digest:
            problems.append(f"handoff {name}: {got} != SHA256SUMS {digest}")
    if problems:
        print("\n".join(problems), file=sys.stderr)
        return 1

    events = json.loads((SOURCE / "events.json").read_text())
    loop_for = loops(events)
    named = set()
    for event in events["events"]:
        files = event["file"] if isinstance(event["file"], list) else [event["file"]]
        named.update(files)
    missing = sorted(named - set(table))
    if missing:
        print("events.json names files the handoff lacks: "
              + ", ".join(missing), file=sys.stderr)
        return 1

    if args.check:
        for name, digest in table.items():
            copy = DEST / name
            if not copy.is_file() or sha256(copy) != digest:
                problems.append(f"{copy.relative_to(ROOT)} differs from the handoff")
            imp = DEST / (name + ".import")
            if not imp.is_file() or "compress/mode=0" not in imp.read_text():
                problems.append(f"{imp.relative_to(ROOT)} is not uncompressed PCM")
        if (DEST / "events.json").read_bytes() != (SOURCE / "events.json").read_bytes():
            problems.append("events.json differs from the handoff")
        if problems:
            print("\n".join(problems), file=sys.stderr)
            return 1
        print(f"ok: {len(table)} WAVs and events.json match handoff {HANDOFF_COMMIT}")
        return 0

    DEST.mkdir(parents=True, exist_ok=True)
    for name in sorted(table):
        shutil.copyfile(SOURCE / "wav" / name, DEST / name)
        imp = DEST / (name + ".import")
        imp.write_text(import_text(name, loop_for.get(name), imp))
    shutil.copyfile(SOURCE / "events.json", DEST / "events.json")
    provenance = {
        "about": "Condi's five-weapon SigmAudio set, copied unchanged by "
                 "tools/five_weapons/import_sigmaudio.py. Edit the handoff, "
                 "not these copies.",
        "source": "handoff/five_weapon_audio/",
        "handoff_commit": HANDOFF_COMMIT,
        "sha256": {name: table[name] for name in sorted(table)},
    }
    (DEST / "PROVENANCE.json").write_text(json.dumps(provenance, indent=2) + "\n")
    print(f"imported {len(table)} WAVs into {DEST.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
