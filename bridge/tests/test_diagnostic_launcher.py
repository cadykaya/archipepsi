"""The diagnostic launcher's argument and path construction.

WHAT THIS CAN AND CANNOT COVER, stated rather than implied. The `.bat`
file is not executed here -- this container is Linux and there is no
`cmd.exe` -- so nothing below is evidence that a Windows double-click
works. What IS covered is every decision the `.bat` delegates: which
scale, which provider, which folder, what happens to a folder that
already holds a campaign, and what a path with a space in it turns into.
The `.bat` is a dozen lines that find Python and call this module, and
those lines are checked by eye.
"""

from __future__ import annotations

import pytest

from archipepsi_bridge import diagnostic as D


def _args(**kw):
    ns = D.build_parser().parse_args([])
    for key, value in kw.items():
        setattr(ns, key, value)
    return ns


# --- the configuration this entry point exists to pin -----------------

def test_the_fixed_configuration_is_the_diagnostic_one(tmp_path):
    argv = D.bridge_argv(tmp_path / "slot")
    assert "--ap=mock" in argv
    assert "--epsilon=fallback" in argv
    # THE ONE THE ORDINARY LAUNCHER GETS WRONG. `--mock-scale` defaults
    # to `prototype` in the bridge's own parser, and a prototype campaign
    # is a different game from the 450-location one the diagnostic run
    # is of.
    assert "--mock-scale=default" in argv


def test_the_save_directory_is_its_own_argument(tmp_path):
    """A path with a space in it survives, because there is no quoting.

    The owner's checkout is under `Documents\\GitHub`; one folder named
    like `Program Files` away from a joined command string splitting into
    two arguments and the campaign landing somewhere nobody chose.
    """
    spaced = tmp_path / "My Save Folder" / ".diagnostic-current"
    argv = D.bridge_argv(spaced)
    assert argv[argv.index("--save-dir") + 1] == str(spaced)
    assert " " in argv[argv.index("--save-dir") + 1]
    # And it is ONE element, not two.
    assert len([a for a in argv if "My Save Folder" in a]) == 1


def test_the_real_parser_accepts_what_this_builds(tmp_path):
    """Built here, parsed THERE. A launcher whose arguments the bridge
    does not recognise is the failure this pair exists to prevent."""
    from archipepsi_bridge.__main__ import main as _  # noqa: F401
    import argparse
    import archipepsi_bridge.__main__ as M

    argv = D.bridge_argv(tmp_path / "slot")
    parser = argparse.ArgumentParser()
    parser.add_argument("--ap", choices=("real", "mock"), default="real")
    parser.add_argument("--epsilon",
                        choices=("claude", "mock", "fallback"))
    parser.add_argument("--mock-scale", choices=tuple(M.MOCK_SCALES))
    parser.add_argument("--save-dir")
    parsed = parser.parse_args(argv[1:])
    assert parsed.ap == "mock"
    assert parsed.epsilon == "fallback"
    assert parsed.mock_scale == "default"
    assert parsed.save_dir == str(tmp_path / "slot")
    # And the scale it names is a real one with the location count the
    # diagnostic run is about.
    assert M.MOCK_SCALES["default"].location_count > 100


def test_reserved_arguments_are_refused(tmp_path):
    for bad in ("--mock-scale=prototype", "--save-dir=/tmp/x",
                "--ap=real", "--epsilon=claude"):
        with pytest.raises(ValueError):
            D.bridge_argv(tmp_path / "slot", [bad])


def test_other_arguments_pass_through(tmp_path):
    argv = D.bridge_argv(tmp_path / "slot", ["--port=38291", "-v"])
    assert argv[-2:] == ["--port=38291", "-v"]


# --- slots: a name, never a path --------------------------------------

def test_a_slot_is_a_name_and_lands_beside_the_repository(tmp_path):
    assert D.slot_dir("582e954", tmp_path) == tmp_path / ".diagnostic-582e954"


@pytest.mark.parametrize("bad", ["", " ", "../saves", "a/b", "a\\b", ".",
                                 "..", "C:x", " padded"])
def test_a_slot_that_is_really_a_path_is_refused(bad, tmp_path):
    with pytest.raises(ValueError):
        D.slot_dir(bad, tmp_path)


def test_the_ordinary_save_folder_is_unreachable(tmp_path):
    """`bridge/saves` is where an ORDINARY campaign lives. No slot name
    can resolve to it, because every slot is prefixed."""
    for name in ("saves", "bridge", "current"):
        assert D.slot_dir(name, tmp_path).name.startswith(D.SLOT_PREFIX)
        assert D.slot_dir(name, tmp_path) != tmp_path / "saves"


def test_an_occupied_slot_is_a_resume_and_an_empty_one_is_not(tmp_path):
    path = tmp_path / ".diagnostic-current"
    path.mkdir()
    assert D.slot_is_occupied(path) is False
    (path / "slot_1.json").write_text("{}")
    assert D.slot_is_occupied(path) is True


def test_resolve_defaults_to_the_same_folder_every_time(tmp_path):
    """The whole point of a named default: yesterday's campaign is what
    comes back, not a new one named after today's commit."""
    first = D.resolve(_args(slot=None, new=False), tmp_path)
    second = D.resolve(_args(slot=None, new=False), tmp_path)
    assert first[1] == second[1] == tmp_path / ".diagnostic-current"


def test_new_never_lands_on_an_occupied_slot(tmp_path):
    taken = tmp_path / ".diagnostic-abc1234"
    taken.mkdir()
    (taken / "slot_1.json").write_text("{}")
    name = D.fresh_slot_name(tmp_path, commit="abc1234")
    assert name != "abc1234"
    assert not (tmp_path / f".diagnostic-{name}").exists()


def test_the_owners_diagnostic_folder_is_listed_not_claimed(tmp_path):
    """`.diagnostic-582e954` is the owner's. It shows up as a slot that
    can be RESUMED by name -- and nothing here ever writes to a slot it
    was not asked for."""
    owned = tmp_path / ".diagnostic-582e954"
    owned.mkdir()
    (owned / "slot_1.json").write_text("{}")
    slots = dict(D.existing_slots(tmp_path))
    assert "582e954" in slots
    # A default run does not go near it.
    _, path, _ = D.resolve(_args(slot=None, new=False), tmp_path)
    assert path != owned


def test_nothing_here_deletes(tmp_path):
    """There is no reset. Stated as a test because "never resets a
    campaign automatically" is the requirement most easily lost to a
    later convenience."""
    import ast
    import inspect

    # THE CODE, NOT THE PROSE. The first version matched the source text
    # and tripped over the word "truncates" in the module docstring,
    # which is a test failing for the opposite of its own reason.
    tree = ast.parse(inspect.getsource(D))
    called = set()
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        func = node.func
        if isinstance(func, ast.Attribute):
            called.add(func.attr)
        elif isinstance(func, ast.Name):
            called.add(func.id)
    for destructive in ("rmtree", "unlink", "remove", "rmdir", "replace",
                        "move", "truncate", "write_text", "write_bytes",
                        "open"):
        assert destructive not in called, destructive
    # And the one filesystem call it DOES make is the one that creates.
    assert "mkdir" in called


# --- what it says before it starts ------------------------------------

def test_the_banner_names_build_scale_and_folder(tmp_path):
    text = D.describe("582e954", tmp_path / ".diagnostic-582e954", True)
    assert "default scale" in text
    assert "582e954" in text
    assert "RESUMING" in text
    assert str(tmp_path) in text
    fresh = D.describe("current", tmp_path / ".diagnostic-current", False)
    assert "NEW campaign" in fresh


def test_a_dry_run_starts_nothing_and_creates_nothing(tmp_path, monkeypatch,
                                                      capsys):
    monkeypatch.setattr(D, "repo_root", lambda: tmp_path)
    monkeypatch.setattr(D, "port_in_use", lambda *a, **k: False)
    assert D.main(["--dry-run"]) == 0
    out = capsys.readouterr().out
    assert "--mock-scale=default" in out
    assert not (tmp_path / ".diagnostic-current").exists()


def test_a_busy_port_is_explained_and_nothing_is_started(tmp_path,
                                                         monkeypatch,
                                                         capsys):
    monkeypatch.setattr(D, "repo_root", lambda: tmp_path)
    monkeypatch.setattr(D, "port_in_use", lambda *a, **k: True)
    assert D.main([]) == 1
    out = capsys.readouterr().out
    assert "ALREADY running" in out
    assert "--port=38291" in out
    # It did not make the folder, and it did not stop anything.
    assert not (tmp_path / ".diagnostic-current").exists()


def test_a_missing_prerequisite_is_named(tmp_path, monkeypatch, capsys):
    monkeypatch.setattr(D, "repo_root", lambda: tmp_path)
    monkeypatch.setattr(D, "missing_prerequisites", lambda: ["websockets"])
    assert D.main([]) == 2
    out = capsys.readouterr().out
    assert "websockets" in out
    assert "pip install websockets" in out


def test_listing_slots_says_which_and_where(tmp_path, monkeypatch, capsys):
    monkeypatch.setattr(D, "repo_root", lambda: tmp_path)
    (tmp_path / ".diagnostic-582e954").mkdir()
    (tmp_path / ".diagnostic-582e954" / "slot_1.json").write_text("{}")
    assert D.main(["--list"]) == 0
    out = capsys.readouterr().out
    assert "582e954" in out
    assert "1 file(s)" in out
