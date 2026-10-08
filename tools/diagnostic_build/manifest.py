#!/usr/bin/env python3
"""Write the package's `archipepsi-build.json` (schema `archipepsi-build/1`).

The standard is `docs/build-package-standard.md` on the build-package-
standard branch, and its own tool
(`tools/build_metadata/archipepsi_build.py`) stamps a package that one of
Prod's `package.sh` scripts produced. That tool is not on this branch, and
this build is not one of those packages: its modes start a STARTER, which
starts the bridge and then the game, so the fields are filled in here
rather than inferred from a game `.bat`.

Fields and spelling follow the standard exactly, so the launcher reads
this build through its manifest path and needs no change. Where the
launcher falls back to reading `.bat` files and `README.txt`, those are
present and correct too -- the two readings agree.
"""

from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import pathlib


def sha256(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("package", type=pathlib.Path)
    ap.add_argument("--branch", required=True)
    ap.add_argument("--commit", required=True)
    ap.add_argument("--zip", required=True)
    ap.add_argument("--built-at", required=True,
                    help="unix timestamp (the packaged commit's own, so "
                         "the manifest is reproducible)")
    args = ap.parse_args()

    pkg: pathlib.Path = args.package
    folder = pkg.name
    revision = folder.rsplit("-", 1)[1]
    product = folder[: -len(revision) - 1]
    exe = pkg / "Archipepsi-Diagnostic.exe"
    console = pkg / "Archipepsi-Diagnostic.console.exe"
    built_at = datetime.datetime.fromtimestamp(
        int(args.built_at), datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    manifest = {
        "schema": "archipepsi-build/1",
        "id": folder,
        "product": product,
        "title": "Diagnostic Campaign, private Windows build",
        "revision": revision,
        "source": {"branch": args.branch, "commit": args.commit},
        "built_at": built_at,
        "platform": "windows",
        "executable": exe.name,
        "console_executable": console.name,
        "modes": [
            {
                "id": "mock-campaign",
                "label": "Mock Campaign",
                "args": [],
                "launcher": "START HERE - Mock Campaign (Windows).bat",
                "description": "The deterministic offline campaign at "
                               "prototype scale. Press MOCK CAMPAIGN on the "
                               "title screen. The bridge starts with the "
                               "game and stops with it.",
            },
            {
                "id": "mock-campaign-log",
                "label": "Mock Campaign, with log window",
                "args": [],
                "launcher": "With log window - Mock Campaign (Windows).bat",
                "description": "The same campaign, with the bridge and the "
                               "game printing into one window.",
            },
        ],
        "recommended_mode": "mock-campaign",
        "description": "A private diagnostic build of the existing "
                       "prototype-scale campaign: the Godot game, the "
                       "bridge and a bundled Python in one folder, so "
                       "neither Godot nor Python needs installing. Not a "
                       "release and not a release candidate.",
        "limitations": [
            "Private diagnostic build for hands-on review. NOT a public "
            "release or release candidate.",
            "The real Archipelago connection is NOT included: the bundled "
            "bridge runs in mock mode only, so a server address typed into "
            "the game reaches the offline mock campaign, not a server. "
            "Real Archipelago play still needs the developer setup and is "
            "untested in this form.",
            "Built on Linux and exercised under Wine. Not yet run on "
            "native Windows.",
            "Not code-signed, so Windows SmartScreen may warn on first run.",
            "The prototype-scale campaign exactly as it is: no candidate "
            "generation profile, no review rooms, no music, no gameplay "
            "change.",
            "Saves live in %LOCALAPPDATA%\\Archipepsi\\Diagnostic "
            "Campaign, outside this folder; game settings stay in Godot's "
            "own user folder, shared with a checkout's runs.",
            "Refuses to start while another Archipepsi bridge is listening "
            "on the bridge port, rather than playing against its saves.",
        ],
        "readme": "README.txt",
        "integrity": {
            "sums_file": "SHA256SUMS.txt",
            "executable": {"size": exe.stat().st_size, "sha256": sha256(exe)},
        },
    }
    # Files SHA256SUMS.txt does not cover (per the standard's
    # `integrity.files`). There should be none: this build's sums list
    # covers every file except the list itself and this manifest.
    sums = {}
    for line in (pkg / "SHA256SUMS.txt").read_text().splitlines():
        if len(line) > 66:
            sums[line[66:]] = line[:64]
    uncovered = {
        str(p.relative_to(pkg)).replace("\\", "/"): sha256(p)
        for p in sorted(pkg.rglob("*"))
        if p.is_file()
        and str(p.relative_to(pkg)).replace("\\", "/") not in sums
        and p.name not in ("SHA256SUMS.txt", "archipepsi-build.json")
    }
    if uncovered:
        manifest["integrity"]["files"] = uncovered

    (pkg / "archipepsi-build.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("archipepsi-build.json: %s, %d modes, %s"
          % (folder, len(manifest["modes"]), args.zip))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
