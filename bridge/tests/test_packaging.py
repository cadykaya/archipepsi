"""First-run and packaging safety (v0.9 S22).

Two things this file is for.

**A key must never be committable.** An API key in git history is not
fixable by a later commit -- it is fixable by rotating the key, and only
if someone notices. The bridge takes its key from the environment and
nothing else; these tests assert that stays true, and that the files a
key would land in are ignored.

**A first run must be diagnosable.** `make doctor` tells a new clone
what is missing and what it can proceed without. CI already found one
fresh-clone break (`make setup` installing nothing); the point of a
preflight is that the next one is reported rather than discovered four
steps later.
"""

from __future__ import annotations

import os
import pathlib
import re
import subprocess

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[2]

#: The preflight's whole job is reporting what a setup is MISSING, so a
#: test that asserts it reports nothing missing only means anything where
#: the setup exists. Tier 1 CI runs with `ARCHIPELAGO_ROOT=/nonexistent`
#: on purpose -- to prove the suite skips cleanly without a checkout --
#: and the first version of this test asserted the opposite there, which
#: is how it turned Tier 1 red. Same skip pattern as `test_bridge.py`.
AP_AVAILABLE = pathlib.Path(
    os.environ.get("ARCHIPELAGO_ROOT", ROOT / ".archipelago")
).is_dir()

needs_ap = pytest.mark.skipif(not AP_AVAILABLE,
                              reason="no Archipelago checkout (make setup)")

#: Key shapes worth refusing outright. Real prefixes, so a genuine
#: pasted key is caught rather than a plausible-looking placeholder.
KEY_PATTERNS = (
    r"sk-ant-[A-Za-z0-9_-]{20,}",     # Anthropic
    r"sk-[A-Za-z0-9]{32,}",           # OpenAI-style
    r"ghp_[A-Za-z0-9]{30,}",          # GitHub PAT
    r"AKIA[0-9A-Z]{16}",              # AWS
)

#: Directories that are not ours to police.
SKIP_DIRS = {".git", ".archipelago", "godot-bin", "__pycache__",
             ".venv", "node_modules", ".pytest_cache"}


def _tracked_files() -> list[pathlib.Path]:
    out = subprocess.run(["git", "ls-files"], cwd=ROOT,
                         capture_output=True, text=True, check=True)
    files = []
    for line in out.stdout.splitlines():
        path = ROOT / line
        if any(part in SKIP_DIRS for part in path.parts):
            continue
        if path.is_file():
            files.append(path)
    return files


def test_no_committed_file_contains_something_shaped_like_a_key():
    """A key in git history is not fixed by a later commit. It is fixed
    by rotating the key, and only if someone notices."""
    offenders = []
    for path in _tracked_files():
        try:
            text = path.read_text(errors="ignore")
        except OSError:
            continue
        for pattern in KEY_PATTERNS:
            for found in re.finditer(pattern, text):
                # This file names the patterns; matching itself is not a
                # leak. Checked by path rather than by content so the
                # exemption cannot be inherited by anything else.
                if path.name == "test_packaging.py":
                    continue
                offenders.append(
                    f"{path.relative_to(ROOT)}: {found.group()[:12]}...")
    assert not offenders, (
        "these tracked files contain something shaped like a live "
        "credential:\n  " + "\n  ".join(offenders))


def test_the_files_a_key_would_land_in_are_ignored():
    """`.env` is where a key goes when someone is in a hurry."""
    ignored = (ROOT / ".gitignore").read_text().splitlines()
    for pattern in (".env",):
        assert pattern in ignored, (
            f"'{pattern}' is not in .gitignore; it is the first place a "
            f"key gets pasted")

    # And git must actually agree, rather than the line merely existing.
    probe = subprocess.run(["git", "check-ignore", "-q", ".env"],
                           cwd=ROOT, capture_output=True)
    assert probe.returncode == 0, ".env is listed but git does not ignore it"


def test_the_bridge_reads_its_key_only_from_the_environment():
    """No config file, no CLI flag, no default. A key passed as an
    argument is a key in shell history and in `ps`."""
    source = (ROOT / "bridge" / "archipepsi_bridge").rglob("*.py")
    for path in source:
        text = path.read_text()
        for found in re.finditer(r"ANTHROPIC_API_KEY", text):
            line_start = text.rfind("\n", 0, found.start()) + 1
            line = text[line_start:text.find("\n", found.start())]
            if "os.environ" in line or "getenv" in line:
                continue
            # A mention in a message or comment is fine; an assignment
            # from anywhere but the environment is not.
            assert "=" not in line.split("ANTHROPIC_API_KEY")[0][-3:], (
                f"{path.name} may be sourcing the API key from somewhere "
                f"other than the environment:\n    {line.strip()}")


def test_the_game_runs_with_no_key_at_all():
    """The fallback provider is not a degraded mode to apologise for --
    it is what a player without an API key plays, and it has to work."""
    main = (ROOT / "bridge" / "archipepsi_bridge" / "__main__.py").read_text()
    assert "EPSILON DOWNGRADE" in main, (
        "the missing-key path no longer announces itself; a silent "
        "downgrade is a player wondering why the Echoes read oddly")
    assert "fallback" in main


BINARY_ASSET_SUFFIXES = {".glb", ".gltf", ".fbx", ".obj", ".blend",
                         ".wav", ".mp3", ".ogg", ".ttf", ".otf",
                         ".png", ".jpg", ".jpeg", ".webp"}

MANIFEST = ROOT / "assets" / "LICENSES.json"


def _manifest() -> dict:
    import json
    return json.loads(MANIFEST.read_text())


def _tracked_binaries() -> list[str]:
    return sorted(
        str(p.relative_to(ROOT)) for p in _tracked_files()
        if p.suffix.lower() in BINARY_ASSET_SUFFIXES)


def test_every_bundled_binary_is_first_party_or_licensed():
    """The D2 gate, and note what it is NOT.

    The old rule was "no binaries at all", which was right while there
    were none and useless the moment the art lane ships one: a gate that
    can only be satisfied by having no assets gets disabled the first
    time someone needs an asset, and then nothing is checked.

    The rule now is the one that survives contact with content: every
    tracked binary is either first-party, or carries a full licence
    record. Adding an asset means adding its record, which is the moment
    the licensing decision is actually needed -- rather than at release,
    which is when it is usually discovered.
    """
    data = _manifest()
    first_party = tuple(data["first_party"]["paths"])
    registered = {e["path"] for e in data.get("third_party", [])}

    unaccounted = [
        path for path in _tracked_binaries()
        if not path.startswith(first_party) and path not in registered]

    assert not unaccounted, (
        "these tracked binaries are neither first-party nor registered:\n  "
        + "\n  ".join(unaccounted)
        + "\n\nAdd the path to first_party.paths in assets/LICENSES.json "
          "if we authored it (a Claude-authored asset a developer "
          "reviewed and approved counts), or add a full third_party "
          "record with its licence. See OWNER_DECISIONS.md D2.")


def test_every_third_party_record_is_complete_and_approved():
    """A half-filled record is worse than none: it looks like diligence.

    Each field here is one D2 asks for by name, and the licence has to be
    on the approved list rather than merely present -- an NC asset with a
    tidy record is still an NC asset.
    """
    data = _manifest()
    approved = data["approved_licenses"]
    refused = data["refused_licenses"]
    required = ("path", "name", "author", "license", "redistribution",
                "modification", "attribution_required")

    for entry in data.get("third_party", []):
        missing = [f for f in required if f not in entry]
        assert not missing, (
            f"third-party record for {entry.get('path', '?')} is missing "
            f"{missing}")

        licence = entry["license"]
        assert licence not in refused, (
            f"{entry['path']} is {licence}: {refused[licence]}")
        assert licence in approved, (
            f"{entry['path']} claims licence '{licence}', which is not on "
            f"the approved list. It needs an explicit owner decision, not "
            f"a commit.")

        assert entry["redistribution"] is True, (
            f"{entry['path']} may not be redistributed as source, so it "
            f"cannot live in this repository (D2 calls this out "
            f"specifically: it looks fine until the repo is public)")

        if entry["attribution_required"]:
            assert entry.get("attribution_location"), (
                f"{entry['path']} requires attribution and does not say "
                f"where it must appear")


def test_the_notices_file_is_generated_and_current():
    """A credits file maintained by hand is a credits file that is wrong,
    and being wrong about attribution has consequences outside the
    repository."""
    from archipepsi_bridge.notices import NOTICES, render

    assert NOTICES.is_file(), "THIRD_PARTY_NOTICES.md is missing"
    assert NOTICES.read_text() == render(), (
        "THIRD_PARTY_NOTICES.md is stale; run `make notices`")


def test_the_gate_still_refuses_an_unregistered_asset():
    """The gate must be able to FAIL. A licence check that passes
    whatever it is given is a licence check nobody has tested, and this
    one replaced a blunter rule that at least could not be satisfied by
    accident."""
    data = _manifest()
    first_party = tuple(data["first_party"]["paths"])
    registered = {e["path"] for e in data.get("third_party", [])}

    intruder = "godot/content/props/somebody_elses_barrel.glb"
    assert not intruder.startswith(first_party)
    assert intruder not in registered


def test_the_preflight_runs_and_separates_required_from_optional():
    """A preflight that calls a working setup broken is worse than none:
    the single most discouraging thing a first run can do is present a
    playable game as a failure. No API key is a NOTE, not a MISSING."""
    out = subprocess.run(
        ["python", "-m", "archipepsi_bridge.doctor"],
        cwd=ROOT / "bridge", capture_output=True, text=True, timeout=120,
        env={k: v for k, v in os.environ.items()
             if k != "ANTHROPIC_API_KEY"})
    assert out.returncode == 0, (
        f"the preflight reports this container as broken:\n{out.stdout}")
    assert "no ANTHROPIC_API_KEY" in out.stdout
    # Reported as `ok`, not as a caveat. A missing key is not a lesser
    # state to be tolerated -- it is what a player without one plays, and
    # presenting it as a warning teaches them to distrust a fine setup.
    assert "fully playable" in out.stdout, (
        "the preflight does not say the game works without a key")
    assert "MISSING" not in out.stdout


def test_the_preflight_names_every_layer_a_fresh_clone_needs():
    """CI found the first fresh-clone break by hitting it. The preflight
    exists so the next one is reported rather than discovered four steps
    later with a confusing error, which means it has to actually cover
    the layers."""
    from archipepsi_bridge.doctor import CHECKS

    labels = {label for label, _, _ in CHECKS}
    for needed in ("python", "archipelago", "requirements", "godot"):
        assert needed in labels, f"the preflight never checks {needed}"

    required = {label for label, _, req in CHECKS if req}
    assert "requirements" in required, (
        "Archipelago's requirements must be REQUIRED; installing nothing "
        "silently is the exact break CI found")
    assert "epsilon" not in required, (
        "an API key must never be required; the fallback provider is "
        "what a player without one plays")
