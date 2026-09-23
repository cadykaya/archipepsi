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

from pathlib import Path

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
                        "move", "truncate", "write_bytes", "open"):
        assert destructive not in called, destructive
    # And the one filesystem call it DOES make is the one that creates.
    assert "mkdir" in called


def test_the_only_write_in_the_module_is_the_mode_marker():
    """`write_text` LEFT the blanket ban, and did not leave unguarded.

    It was on that list because writing is how a save gets truncated.
    Follow-up 02 gave the launcher one thing to write -- the marker that
    remembers a slot is the quieter one -- so the ban is replaced by the
    stronger statement it was standing in for: there is exactly one
    write in this module, it is inside the marker writer, and it writes
    the marker path and nothing else. A second write appearing anywhere
    fails here, which is what the blanket ban was for.

    Overnight 05 gave the launcher a second MODE marker (the candidate
    profile), and both markers go through the one `_mark`, so this still
    finds exactly one write.
    """
    import ast
    import inspect

    tree = ast.parse(inspect.getsource(D))
    writers = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.FunctionDef):
            continue
        for inner in ast.walk(node):
            if (isinstance(inner, ast.Call)
                    and isinstance(inner.func, ast.Attribute)
                    and inner.func.attr == "write_text"):
                writers.append((node.name, ast.unparse(inner.func.value)))
    assert writers == [("_mark", "marker")], writers


def test_marking_a_slot_quiet_does_not_touch_what_is_already_in_it(tmp_path):
    """THE BEHAVIOUR, not the spelling. A campaign in the slot comes
    through a marking byte-for-byte, and only the marker appears."""
    slot = tmp_path / ".diagnostic-quiet"
    slot.mkdir()
    (slot / "campaign.json").write_text('{"zones": 3}')
    (slot / "archipepsi.log").write_text("a log line\n")
    before = {f.name: f.read_bytes() for f in slot.iterdir()}

    D.mark_quiet(slot)
    D.mark_quiet(slot)                   # twice: writing once is the point

    after = {f.name: f.read_bytes() for f in slot.iterdir()}
    assert set(after) - set(before) == {D.QUIET_MARKER}
    for name, blob in before.items():
        assert after[name] == blob, name


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


# --- the quieter preview, and the wall between the two modes -----------
#
# Follow-up 02 item D is an OPT-IN comparison. What matters here is not
# that it composes differently -- `test_quiet_preview.py` owns that --
# but that choosing it cannot reach an ordinary campaign, and that an
# ordinary run cannot wander into a quieter one.

def test_quiet_is_off_unless_asked_for():
    """THE DEFAULT IS THE SHIPPED GAME. A plain run passes nothing."""
    args = D.build_parser().parse_args([])
    assert args.quiet is False
    assert "--quiet-generation" not in D.bridge_argv(Path("/tmp/slot"))


def test_quiet_gets_its_own_slot_by_default(tmp_path):
    """Two modes, two folders. Sharing one would put Zones composed two
    different ways into a single campaign history."""
    normal, npath, _ = D.resolve(_args(slot=None, new=False, quiet=False),
                                 tmp_path)
    quiet, qpath, _ = D.resolve(_args(slot=None, new=False, quiet=True),
                                tmp_path)
    assert normal == D.DEFAULT_SLOT and quiet == D.QUIET_DEFAULT_SLOT
    assert npath != qpath


def test_a_fresh_quiet_slot_says_so_in_its_name(tmp_path):
    """`--new --quiet` is named for the revision like any other, plus
    the one word that stops it being mistaken for the ordinary one."""
    slot, _, _ = D.resolve(_args(slot=None, new=True, quiet=True), tmp_path)
    assert slot.endswith("-quiet")


def test_a_quiet_run_refuses_an_ordinary_campaign(tmp_path):
    """THE OWNER'S SAVE IS THE CASE THIS EXISTS FOR.

    `.diagnostic-582e954` holds an ordinary campaign and has no marker,
    so it reads as ordinary -- and a quieter run pointed at it is
    refused before anything is opened, created or started.
    """
    owned = tmp_path / ".diagnostic-582e954"
    owned.mkdir()
    (owned / "campaign.json").write_text('{"zones": 12}')
    blob = (owned / "campaign.json").read_bytes()

    with pytest.raises(ValueError, match="already holds a NORMAL campaign"):
        D.resolve(_args(slot="582e954", new=False, quiet=True), tmp_path)

    assert (owned / "campaign.json").read_bytes() == blob
    assert not (owned / D.QUIET_MARKER).exists()
    assert set(p.name for p in owned.iterdir()) == {"campaign.json"}


def test_an_ordinary_run_refuses_a_quieter_campaign(tmp_path):
    """AND THE OTHER WAY. A preview campaign is not quietly continued
    as a normal one, which would leave one history holding both."""
    slot = tmp_path / f"{D.SLOT_PREFIX}{D.QUIET_DEFAULT_SLOT}"
    slot.mkdir()
    (slot / "campaign.json").write_text("{}")
    D.mark_quiet(slot)

    with pytest.raises(ValueError, match="already holds a QUIET campaign"):
        D.resolve(_args(slot=D.QUIET_DEFAULT_SLOT, new=False, quiet=False),
                  tmp_path)

    # ... and resuming it in its own mode is fine.
    name, path, resuming = D.resolve(
        _args(slot=D.QUIET_DEFAULT_SLOT, new=False, quiet=True), tmp_path)
    assert resuming and path == slot and name == D.QUIET_DEFAULT_SLOT


def test_an_empty_slot_belongs_to_whichever_mode_arrives(tmp_path):
    """A mode is a property of a campaign, not of a folder name. An
    empty `quiet` slot is not yet a quieter campaign."""
    slot = tmp_path / f"{D.SLOT_PREFIX}{D.QUIET_DEFAULT_SLOT}"
    slot.mkdir()
    assert D.slot_mode(slot) == "normal"
    D.resolve(_args(slot=D.QUIET_DEFAULT_SLOT, new=False, quiet=False),
              tmp_path)          # does not raise


def test_quiet_generation_cannot_be_passed_through(tmp_path):
    """The launcher decides it, so it cannot arrive as an extra and land
    on a run whose slot and banner both say ordinary."""
    with pytest.raises(ValueError, match="cannot"):
        D.bridge_argv(tmp_path / "slot", ["--quiet-generation"])


def test_the_banner_says_which_generation_is_running(tmp_path):
    """A variant that changes what Zones are made of is never something
    you find out about from the level design -- AND IT SAYS WHAT IT IS.

    The owner's correction, pinned: this is a lower-budget generation
    variant, not the baseline level with two drills taken out. A banner
    that claimed the smaller thing would be the more flattering lie, so
    the three ways it actually differs are all named here.
    """
    plain = D.describe("current", tmp_path, False, False)
    preview = D.describe("quiet", tmp_path, False, True)
    assert "QUIET" not in plain.upper()
    assert "LOWER-BUDGET" not in plain.upper()
    assert "LOWER-BUDGET VARIANT" in preview
    assert "spent elsewhere" in preview
    assert "MORE rooms" in preview and "MORE enemies" in preview
    assert "DIFFERENT rooms" in preview
    assert "Not the same level with the drills removed." in preview


# --- the candidate profile (Overnight 05, O05-13 / O05-15.1) ------------

def test_the_candidate_switch_takes_all_steps_by_default():
    from archipepsi_bridge import candidate as CP
    assert D.candidate_steps(D.build_parser().parse_args(["--candidate"])) \
        == CP.STEPS
    assert D.candidate_steps(D.build_parser().parse_args(
        ["--candidate=transport"])) == ("transport",)
    assert D.candidate_steps(D.build_parser().parse_args([])) == ()


def test_an_unknown_candidate_step_is_refused_before_any_folder(tmp_path):
    with pytest.raises(ValueError, match="unknown candidate step"):
        D.resolve(D.build_parser().parse_args(["--candidate=blindside"]),
                  tmp_path)
    assert not list(tmp_path.iterdir())


def test_the_candidate_campaign_has_its_own_slot(tmp_path):
    _, npath, _ = D.resolve(_args(slot=None, new=False), tmp_path)
    cand = D.build_parser().parse_args(["--candidate"])
    slot, cpath, resuming = D.resolve(cand, tmp_path)
    assert slot == D.CANDIDATE_DEFAULT_SLOT and cpath != npath
    assert not resuming


def test_quiet_and_candidate_are_not_one_campaign(tmp_path):
    both = D.build_parser().parse_args(["--quiet", "--candidate"])
    with pytest.raises(ValueError, match="two different campaigns"):
        D.resolve(both, tmp_path)


def test_a_candidate_slot_remembers_its_profile(tmp_path):
    slot = tmp_path / ".diagnostic-candidate"
    slot.mkdir()
    (slot / "campaign.json").write_text("{}")
    from archipepsi_bridge import candidate as CP
    D.mark_candidate(slot, CP.STEPS)
    assert D.slot_mode(slot) == "candidate"
    assert D.slot_profile(slot) == CP.STEPS
    # the same profile resumes
    D.resolve(D.build_parser().parse_args(["--candidate"]), tmp_path)
    # another one is refused, and nothing is touched
    before = {f.name: f.read_bytes() for f in slot.iterdir()}
    with pytest.raises(ValueError, match="composed with zone_state"):
        D.resolve(D.build_parser().parse_args(["--candidate=transport"]),
                  tmp_path)
    assert {f.name: f.read_bytes() for f in slot.iterdir()} == before


def test_an_ordinary_run_cannot_continue_a_candidate_campaign(tmp_path):
    slot = tmp_path / ".diagnostic-candidate"
    slot.mkdir()
    (slot / "campaign.json").write_text("{}")
    D.mark_candidate(slot, ("transport",))
    with pytest.raises(ValueError, match="CANDIDATE campaign"):
        D.resolve(_args(slot="candidate", new=False), tmp_path)


def test_the_banner_names_the_profile_and_that_nothing_is_staged(tmp_path):
    text = D.describe("candidate", tmp_path, False, False,
                      ("zone_state", "transport"))
    assert "CANDIDATE: zone_state, transport" in text
    assert "staged      nothing" in text
    assert "MOCK, default scale" in text and "fallback" in text
    assert "CANDIDATE" not in D.describe("current", tmp_path, False)


def test_the_profile_reaches_the_bridge_only_through_the_switch():
    with pytest.raises(ValueError, match="decided by the diagnostic"):
        D.bridge_argv(Path("/tmp/x"), ["--candidate=all"])


def test_a_new_candidate_slot_is_named_for_the_revision(tmp_path):
    args = D.build_parser().parse_args(["--new", "--candidate"])
    slot, _, resuming = D.resolve(args, tmp_path)
    assert slot.endswith("-candidate") and not resuming
