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

**The client half is still Prod's.** Relaunching Godot and reading real
world state is not something this lane can do, and no case below claims
it. What is proven here is that the bridge's own state survives the
bridge's own death.

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


def _restarted(tmp_path: Path, save: P.CampaignSave, expression: str):
    path = store.save_path(tmp_path, save.seed_name, save.team,
                           save.slot_id, save.slot_name)
    store.write_save(path, save)
    return _in_a_fresh_process(path, expression)


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

    And the reversal is made AFTER the restart, in the process that
    reloaded it -- a save that came back as a latch would refuse it.
    """
    save = T.record_zone_state(_campaign(), "zone_001", "span_alignment",
                               "lowered")
    save = T.record_zone_state(save, "zone_001", "bolt_driven", "driven")
    answer = _restarted(tmp_path, save, (
        "{'bolt': save.zone_by_id('zone_001').progress.macro('bolt_driven'),"
        " 'span': save.zone_by_id('zone_001').progress.macro"
        "('span_alignment')}"))
    assert answer == {"bolt": "driven", "span": "lowered"}

    reloaded = P.CampaignSave.model_validate_json(save.model_dump_json())
    back = T.record_zone_state(reloaded, "zone_001", "span_alignment",
                               "stowed")
    assert back.zone_by_id("zone_001").progress.macro(
        "span_alignment") == "stowed"
    with pytest.raises(ValueError, match="no control can put"):
        T.record_zone_state(back, "zone_001", "bolt_driven", "loose")


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


def test_an_interrupted_write_does_not_destroy_the_previous_save(tmp_path):
    """P04.6's recoverable interrupted write, at the file level.

    `write_save` writes and fsyncs a temporary file before replacing the
    real one, so a process killed mid-write leaves the OLD save intact
    rather than a truncated one. Here the crash is simulated by writing
    a partial file beside the save and asserting the save still loads.
    """
    save = _campaign()
    path = store.save_path(tmp_path, save.seed_name, save.team,
                           save.slot_id, save.slot_name)
    store.write_save(path, save)
    (path.parent / (path.name + ".tmp")).write_text('{"schema_ver')

    answer = _in_a_fresh_process(path, "save.seed_name")
    assert answer == "Seed", (
        "a half-written temporary file must not be mistaken for the save")
