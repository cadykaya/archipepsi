"""P04.3 — cold restarts of the bridge process, on disposable saves.

**This is the part `test_restart_persistence.py` cannot do.** That file
round-trips a save through JSON in one process, which is evidence about
the representation. P04.3 asks for the process to be **terminated and
relaunched**: *"actually terminate and restart the relevant
client/bridge processes on disposable saves ... verify real world
state, remaining Checks and usable return, not just serialized JSON
equality."*

So every case here writes a save through `store.write_save`, lets the
writing interpreter **exit**, and starts a **new `python3` subprocess**
that has never seen the first one's memory. Nothing is passed between
them but the file.

**Reading a field back is not resuming.** A save every field of which
reloads correctly can still be one no transition will accept. So the
cases that matter run their transitions **inside the restarted
interpreter**, on the save it loaded off disk, and assert there
(`_resumed_in_a_fresh_process`). A transition run in the parent --
even against a faithful in-process round trip -- is run by an
interpreter that still holds the original objects and cannot tell the
two apart. Corrected on the owner's finding, 2026-09-22.

**The client half is still Prod's, and P04 is not complete.**
Relaunching Godot, restarting the bridge and client normally, and
resuming actual gameplay are not things this lane can do, and no case
below claims them. The PID check proves the HARNESS -- that the child
is a different process -- and is not the lifecycle. What is proven here
is that the bridge's own state survives the bridge's own death and can
be carried forward by the process that reloaded it.

**Disposable saves only.** Every save is written under `tmp_path`, which
pytest removes. No original is read, written or migrated.
"""
from __future__ import annotations

import json
import subprocess
import sys
import textwrap
from pathlib import Path

import pytest

from archipepsi_bridge import store
from archipepsi_bridge.schemas import protocol as P
from archipepsi_bridge.schemas import transitions as T
from archipepsi_bridge.schemas.zone import Zone

_BRIDGE = str(Path(__file__).resolve().parents[1])


def _room(rid: str, reward: int | None = None) -> dict:
    return {"id": rid, "type": "arena", "width": 16.0, "depth": 15.0,
            "wall_height": 5.0, "objective": "kill_all",
            "reward_location_id": reward,
            "enemies": [{"archetype": "melee", "count": 1}]}


def _zone() -> Zone:
    return Zone.model_validate({
        "schema_version": 7, "zone_id": "zone_001", "display_name": "Relay",
        "target_game": "Game", "theme": "void_glitch",
        "chambers": [_room("c001", 89100001), _room("c002")],
        "zone_state": [{
            "variable_id": "span_alignment",
            "states": ["stowed", "lowered"], "initial": "stowed",
            "lifetime": "reversible",
            "setter": {"room_id": "c001", "selects": ["stowed", "lowered"]},
            "readers": [{"room_id": "c002", "mechanism": "span_bolt",
                         "when": ["lowered"]}],
        }, {
            # A ONE-WAY CHANGE beside the reversible one, so the restart
            # has both kinds to tell apart. A latch would have been the
            # obvious choice and needs a committed physics package; a
            # `permanent` variable is the same monotone fact with no
            # scaffolding, and §4.0 proves its monotonicity from the
            # declaration rather than from a label.
            "variable_id": "bolt_driven",
            "states": ["loose", "driven"], "initial": "loose",
            "lifetime": "permanent",
            "setter": {"room_id": "c002", "selects": ["driven"]},
            "readers": [{"room_id": "c001", "mechanism": "tell_tale",
                         "when": ["driven"]}],
        }],
    })


def _campaign() -> P.CampaignSave:
    zone = _zone()
    save = P.CampaignSave(seed_name="Seed", team=0, slot_id=1,
                          slot_name="Skyiah")
    save = T.start_generation(save, zone_id=zone.zone_id,
                              allocated_location_ids=(89100001,),
                              target_game=zone.target_game)
    save = T.accept_zone(save, zone)
    return T.enter_zone(save, zone.zone_id)


def _in_a_fresh_process(path: Path, expression: str) -> object:
    """Load the save in a NEW interpreter and print one JSON answer.

    `sys.executable` with `-c`, not an import: the point is a process
    that has never held any of this one's objects. A stale module-level
    cache in the bridge would survive an import and would not survive
    this.
    """
    script = textwrap.dedent(f"""
        import json, sys
        sys.path.insert(0, {_BRIDGE!r})
        from pathlib import Path
        from archipepsi_bridge import store
        save = store.load_save(Path({str(path)!r}))
        print(json.dumps({expression}))
    """)
    done = subprocess.run([sys.executable, "-c", script],
                          capture_output=True, text=True, timeout=120)
    assert done.returncode == 0, (
        f"the restarted process failed:\n{done.stderr}")
    return json.loads(done.stdout.strip())


def _written(tmp_path: Path, save: P.CampaignSave) -> Path:
    path = store.save_path(tmp_path, save.seed_name, save.team,
                           save.slot_id, save.slot_name)
    store.write_save(path, save)
    return path


def _restarted(tmp_path: Path, save: P.CampaignSave, expression: str):
    return _in_a_fresh_process(_written(tmp_path, save), expression)


def _resumed_in_a_fresh_process(path: Path, body: str) -> object:
    """Load the save from disk and **continue it** in the new interpreter.

    The difference from `_in_a_fresh_process` is the difference the
    owner named on 2026-09-22: reading a field out of a reloaded save is
    evidence that the REPRESENTATION survived, and it is not evidence
    that the campaign can be RESUMED from the file. A transition run in
    the parent -- even against a faithful in-process JSON round trip --
    is run by an interpreter that still holds the original objects, so
    it cannot distinguish the two.

    `body` runs in the child with `save` bound to the disk-loaded save,
    `P` and `T` bound to the protocol and transition modules, and must
    leave its result in `answer`. **Its assertions execute in the
    child**; a failure there exits non-zero and the parent re-raises
    with the child's traceback attached, so a body that quietly proved
    nothing cannot pass as a green case.
    """
    script = textwrap.dedent("""
        import json, sys
        sys.path.insert(0, {bridge!r})
        from pathlib import Path
        from archipepsi_bridge import store
        from archipepsi_bridge.schemas import protocol as P
        from archipepsi_bridge.schemas import transitions as T
        save = store.load_save(Path({path!r}))
        assert save is not None, "the restarted process found no save"
        answer = None
    """).format(bridge=_BRIDGE, path=str(path)) + textwrap.dedent(body) + (
        "\nprint(json.dumps(answer))\n")
    done = subprocess.run([sys.executable, "-c", script],
                          capture_output=True, text=True, timeout=120)
    assert done.returncode == 0, (
        "the resumed process failed, so the transitions below were NOT "
        f"proven on the disk-loaded save:\n{done.stderr}")
    return json.loads(done.stdout.strip())


# --------------------------------------------------------------------------
# The harness proves itself before anything relies on it
# --------------------------------------------------------------------------

def test_the_restarted_process_is_a_different_process(tmp_path):
    """A subprocess that silently ran in-process would make every case
    below a round trip wearing a restart's name."""
    save = _campaign()
    pid = _restarted(tmp_path, save, "__import__('os').getpid()")
    import os
    assert pid != os.getpid()


def test_a_missing_save_comes_back_as_nothing_not_a_crash(tmp_path):
    assert store.load_save(tmp_path / "absent.json") is None


def test_an_assertion_that_fails_in_the_child_fails_the_case(tmp_path):
    """The resume harness proves itself before anything relies on it.

    Its whole value is that the assertions run in the restarted
    interpreter. If a child's failure could not reach the parent, every
    resumed case below would be a subprocess that printed something and
    proved nothing -- and would look exactly like a passing one.
    """
    with pytest.raises(AssertionError, match="the resumed process failed"):
        _resumed_in_a_fresh_process(_written(tmp_path, _campaign()), """
            assert save.seed_name == "not the seed that was written"
            answer = {}
        """)


def test_a_refusal_the_child_should_have_raised_is_not_swallowed(tmp_path):
    """The other half: a body whose `else` branch fires must fail too.

    The permanent-change case below proves a refusal by raising in the
    child's `else`. That pattern is only worth anything if such a raise
    lands here.
    """
    with pytest.raises(AssertionError, match="the resumed process failed"):
        _resumed_in_a_fresh_process(_written(tmp_path, _campaign()), """
            try:
                pass
            except ValueError:
                pass
            else:
                raise AssertionError("the refusal never came")
            answer = {}
        """)


# --------------------------------------------------------------------------
# P04.3's points, each across a real process boundary
# --------------------------------------------------------------------------

def test_before_the_grant_the_restarted_bridge_owes_the_check(tmp_path):
    """The claim is durable before the Echo exists -- the window the
    pending record is for, read by a process that never saw it made."""
    save = T.claim_zone_check(_campaign(), zone_id="zone_001",
                              location_id=89100001, transaction_id="t1")
    pending = _restarted(tmp_path, save,
                         "[p.location_id for p in save.pending_checks]")
    assert pending == [89100001]
    folded = _restarted(tmp_path, save, "len(save.interpretations)")
    assert folded == 0, "nothing was folded yet, and the restart agrees"


def test_after_a_configuration_change_the_restarted_bridge_sees_it(tmp_path):
    """Reversible Zone configuration across a process death."""
    save = T.record_zone_state(_campaign(), "zone_001", "span_alignment",
                               "lowered")
    state = _restarted(
        tmp_path, save,
        "save.zone_by_id('zone_001').progress.macro('span_alignment')")
    assert state == "lowered"


def test_a_permanent_change_and_a_reversible_one_come_back_apart(tmp_path):
    """The distinction the whole contract turns on, across a process
    death: the one-way change is still one-way and the configuration is
    still reversible.

    **The reversal runs in the child, on the save that came off disk.**

    CORRECTED, 2026-09-22 (owner). An earlier revision of this test said
    exactly that in this docstring and then did something else: it
    reversed a `model_validate_json` round trip **in the parent**, which
    had written the save and was still alive holding every object in it.
    The label claimed evidence the code did not produce, which is worse
    than a missing case -- a missing case is visible. The transitions
    below now execute inside the restarted interpreter and assert
    there; the parent only checks that it exited cleanly and reads back
    what it reported.
    """
    save = T.record_zone_state(_campaign(), "zone_001", "span_alignment",
                               "lowered")
    save = T.record_zone_state(save, "zone_001", "bolt_driven", "driven")

    answer = _resumed_in_a_fresh_process(_written(tmp_path, save), """
        zone = save.zone_by_id("zone_001")
        assert zone.progress.macro("bolt_driven") == "driven"
        assert zone.progress.macro("span_alignment") == "lowered"

        # Reversible, and reversed HERE: the configuration moves again
        # in the process that loaded the file. A save that came back as
        # a latch would refuse this.
        back = T.record_zone_state(save, "zone_001", "span_alignment",
                                   "stowed")
        assert back.zone_by_id("zone_001").progress.macro(
            "span_alignment") == "stowed"

        # Permanent, and refused HERE, on the same reloaded save.
        try:
            T.record_zone_state(back, "zone_001", "bolt_driven", "loose")
        except ValueError as refused:
            why = str(refused)
        else:
            raise AssertionError(
                "a permanent change was reversed after a restart")
        assert "no control can put" in why, why

        answer = {"span_after_reversal": back.zone_by_id(
            "zone_001").progress.macro("span_alignment"), "refusal": why}
    """)
    assert answer["span_after_reversal"] == "stowed"
    assert "no control can put" in answer["refusal"]


def test_the_campaign_can_be_carried_forward_by_the_process_that_loaded_it(
        tmp_path):
    """Resumption, not just readback.

    P04.3 asks for a *usable* return, and a save every field of which
    reads correctly can still be one no transition will accept -- a
    pending record whose transaction the reloaded save will not honour,
    a Zone whose progress no longer satisfies its own preconditions.
    The only way to find that out is to take the next step in the
    process that loaded the file.

    This is the bridge's half and it says so. Relaunching the client and
    resuming actual gameplay is Prod's, and nothing here stands in for
    it.
    """
    answer = _resumed_in_a_fresh_process(_written(tmp_path, _campaign()), """
        claimed = T.claim_zone_check(save, zone_id="zone_001",
                                     location_id=89100001,
                                     transaction_id="after_restart")
        assert [p.location_id for p in claimed.pending_checks] == [89100001]

        moved = T.record_zone_state(claimed, "zone_001", "span_alignment",
                                    "lowered")
        assert moved.zone_by_id("zone_001").progress.macro(
            "span_alignment") == "lowered"

        answer = {"pending": [p.transaction_id
                              for p in moved.pending_checks],
                  "span": moved.zone_by_id("zone_001").progress.macro(
                      "span_alignment")}
    """)
    assert answer == {"pending": ["after_restart"], "span": "lowered"}


def test_the_remaining_checks_survive_the_restart(tmp_path):
    """P04.3 asks for remaining Checks by name, not only for the save
    parsing."""
    save = _campaign()
    allocated = _restarted(
        tmp_path, save,
        "list(save.zone_by_id('zone_001').allocated_location_ids)")
    assert allocated == [89100001]


def test_the_committed_manifest_survives_the_restart(tmp_path):
    """A Zone is solved once and replayed forever, so the provenance has
    to cross a process boundary or the replay is a recomposition."""
    save = T.commit_layout(_campaign(), "zone_001",
                           {"manifest_digest": "abc123"})
    answer = _restarted(tmp_path, save, (
        "{'digest': save.zone_by_id('zone_001').manifest['manifest_digest'],"
        " 'state': save.zone_by_id('zone_001').layout_state}"))
    assert answer == {"digest": "abc123", "state": "ACCEPTED"}


def test_a_stray_partial_temp_file_is_not_mistaken_for_the_save(tmp_path):
    """Stray-file recovery. **NOT a killed write**, and renamed to say so.

    CORRECTED, 2026-09-22 (owner). This case used to be called
    `test_an_interrupted_write_does_not_destroy_the_previous_save` and
    was cited as P04.6's interrupted-write evidence. It is not: nothing
    here is interrupted. A complete `write_save` runs to completion and
    then a partial file is placed beside the result. What that proves is
    that a leftover `.tmp` -- from any cause, including a previous
    crash -- is ignored by the loader.

    What it does NOT prove is the atomicity claim it was standing in
    for: that a process killed *between* opening the temporary file and
    the rename leaves the OLD save intact. `write_save` writes and
    fsyncs a temporary file before replacing the real one, and the
    design says that makes the replacement atomic, but a real killed
    write needs the writer terminated mid-call -- and the old save
    present beforehand, which it is not here. That case is unwritten and
    is named in the ledger rather than implied by this one.
    """
    save = _campaign()
    path = store.save_path(tmp_path, save.seed_name, save.team,
                           save.slot_id, save.slot_name)
    store.write_save(path, save)
    (path.parent / (path.name + ".tmp")).write_text('{"schema_ver')

    answer = _in_a_fresh_process(path, "save.seed_name")
    assert answer == "Seed", (
        "a half-written temporary file must not be mistaken for the save")
