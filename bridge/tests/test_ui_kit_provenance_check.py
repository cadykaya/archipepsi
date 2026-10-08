"""The optional UI-kit provenance check catches what it claims to.

`tools/check_ui_kit_provenance.py` compares `assets/ui` with the hashes in
`tools/ui_kit_provenance.json`, and rebuilds the kit only when GLYPH_ROOT
names a Glyph checkout. These tests drive the record half against a copy
of the kit and a copy of the record, so they say nothing about whether
the committed kit is current -- that stays the optional check's job, and
an art-lane change to the kit cannot turn this file red.
"""
from __future__ import annotations

import importlib.util
import json
import shutil
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
_spec = importlib.util.spec_from_file_location(
    "check_ui_kit_provenance", ROOT / "tools/check_ui_kit_provenance.py")
check = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(check)


@pytest.fixture
def kit(tmp_path, monkeypatch):
    """A copy of the kit, a matching record, and no Glyph checkout."""
    monkeypatch.delenv("GLYPH_ROOT", raising=False)
    copy = tmp_path / "ui"
    shutil.copytree(ROOT / "assets/ui", copy)
    record = json.loads((ROOT / "tools/ui_kit_provenance.json").read_text())
    record["files"] = check.kit_files(copy)
    path = tmp_path / "record.json"
    path.write_text(json.dumps(record))
    return copy, path


def _run(kit, record, *extra):
    return check.main(["--kit", str(kit), "--record", str(record), *extra])


def test_the_record_names_glyph_2e2115a():
    record = json.loads((ROOT / "tools/ui_kit_provenance.json").read_text())
    assert record["glyph"]["revision"].startswith("2e2115a")
    assert record["files"], "the record lists no files"


def test_a_matching_kit_passes_and_the_rebuild_is_skipped(kit, capsys):
    assert _run(*kit) == 0
    assert "SKIP rebuild" in capsys.readouterr().out


def test_a_changed_byte_fails(kit, capsys):
    copy, record = kit
    png = copy / "icon_exit.png"
    data = bytearray(png.read_bytes())
    data[-1] ^= 1
    png.write_bytes(bytes(data))
    assert _run(copy, record) == 1
    assert "icon_exit.png differs" in capsys.readouterr().out


def test_a_missing_and_an_extra_file_both_fail(kit, capsys):
    copy, record = kit
    (copy / "panels.json").unlink()
    (copy / "stray.png").write_bytes(b"x")
    assert _run(copy, record) == 1
    out = capsys.readouterr().out
    assert "panels.json is missing" in out
    assert "stray.png is not in the record" in out


def test_write_record_never_touches_the_kit(kit):
    copy, record = kit
    before = check.kit_files(copy)
    (copy / "stray.png").write_bytes(b"x")
    assert _run(copy, record, "--write-record") == 0
    after = check.kit_files(copy)
    assert after == {**before, "stray.png": check.kit_files(copy)["stray.png"]}
    assert json.loads(record.read_text())["files"] == after
    assert _run(copy, record) == 0


def test_a_glyph_root_without_a_built_cli_cannot_run(kit, tmp_path,
                                                     monkeypatch):
    monkeypatch.setenv("GLYPH_ROOT", str(tmp_path / "nowhere"))
    assert _run(*kit) == 2
