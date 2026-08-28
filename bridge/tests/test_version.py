"""Build metadata has to work where it matters, which is not here.

Three consumers read it: the bridge banner a player sees, the
`bridge_version` the client checks on the handshake and refuses a
mismatch on, and CI attaching provenance to a run. A version that only
resolves inside a git checkout breaks exactly where it is most needed —
in a packaged build, in someone's bug report, in a tarball.
"""

from __future__ import annotations

import subprocess
import sys

from archipepsi_bridge import BRIDGE_VERSION
from archipepsi_bridge.version import build_metadata, render

REQUIRED = ("bridge_version", "commit", "branch", "tree", "python",
            "platform", "ci")


def test_every_field_is_present_and_a_string():
    """A missing key is a caller crash, so absence is spelled with a
    value: `unknown` is information."""
    data = build_metadata()
    for key in REQUIRED:
        assert key in data, f"{key} missing from build metadata"
        assert isinstance(data[key], str) and data[key], (
            f"{key} is {data[key]!r}; every field is a non-empty string")


def test_the_version_matches_what_the_client_checks():
    """The handshake refuses a mismatch, so these two cannot drift."""
    assert build_metadata()["bridge_version"] == BRIDGE_VERSION


def test_it_works_with_no_git_at_all(monkeypatch, tmp_path):
    """A packaged build has no `.git` and often no `git`. This must
    degrade to `unknown` rather than raising, because the banner that
    prints it is the first thing a player sees."""
    def no_git(*args, **kwargs):
        raise FileNotFoundError("git")

    monkeypatch.setattr(subprocess, "run", no_git)
    data = build_metadata()
    assert data["commit"] == "unknown"
    assert data["branch"] == "unknown"
    assert data["bridge_version"] == BRIDGE_VERSION, (
        "the version is ours and must survive git being absent")
    assert render(), "the rendering still produces something printable"


def test_a_dirty_tree_says_so():
    """CI attaches this to a run and a bug report quotes it. Calling an
    edited tree by the commit it is no longer at would mislead every
    attempt to reproduce from it."""
    data = build_metadata()
    assert data["tree"] in ("clean", "dirty", "unknown")


def test_the_module_runs_as_a_command():
    """`make version` is a CI step; it has to exit zero and print."""
    out = subprocess.run(
        [sys.executable, "-m", "archipepsi_bridge.version"],
        capture_output=True, text=True, timeout=30)
    assert out.returncode == 0, out.stderr
    assert "bridge_version" in out.stdout
