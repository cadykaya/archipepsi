"""Test 48: `.apworld` packaging via AP's own build component.

The artifact is produced by `make apworld` (AP's "Build APWorlds" Launcher
component — never a hand-rolled zip). This test validates the built zip and
skips when it has not been built yet.
"""

from __future__ import annotations

import json
import zipfile

import pytest

from .conftest import AP_ROOT

ARTIFACT = AP_ROOT / "build" / "apworlds" / "archipepsi.apworld"


@pytest.mark.skipif(not ARTIFACT.exists(),
                    reason="run `make apworld` first")
def test_48_apworld_package_and_manifest():
    with zipfile.ZipFile(ARTIFACT) as z:
        names = z.namelist()
        # The zip must contain a folder named identically to the zip.
        assert all(n.startswith("archipepsi/") for n in names)
        manifest = json.loads(z.read("archipepsi/archipelago.json"))
    assert manifest["game"] == "Archipepsi"
    assert manifest["world_version"] == "0.7.0"
    assert manifest["minimum_ap_version"] == "0.6.7"
    # Added by AP's build component; never hand-written.
    assert "version" in manifest and "compatible_version" in manifest
