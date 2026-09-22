"""A charge counted before the effect exists, and across a dead client.

The client's reserve/launch/report is an in-memory list. Retaining and
retransmitting it survives a dropped socket; it does not survive the
process. Launch an effect, lose the report, kill Godot, relaunch into
the same unrefilled deployment, and a bridge that only ever learned
about expenditure from a report still believes the charge is there —
and a cleared local dictionary is not reconciliation.

So `authorize_consumable` moves `spent` BEFORE the client launches, and
`ConsumableAuthorization` exists only so an attempt that never launched
can be cancelled. A crash between authorize and launch burns the
charge: the conservative direction, and the cost of authorizing first.

**WHAT IS PROVEN HERE AND WHAT IS NOT.** These are the bridge's
authoritative expenditure, including across a real process boundary on
this side. The client half — Godot calling `authorize` before it
launches anything, and its pending operations settling against these
records — is unwired, so END TO END THE BOUNDARY IS STILL OPEN. The two
halves are one integration obligation with two owners, and this file is
one of them, not the pair.
"""

from __future__ import annotations

import inspect
import json
import subprocess
import sys
import textwrap
from pathlib import Path

import pytest

from archipepsi_bridge import store
from archipepsi_bridge.schemas import protocol as P
from archipepsi_bridge.schemas import transitions as T

_BRIDGE = str(Path(__file__).resolve().parents[1])
CID = "act_nade"


def _save() -> P.CampaignSave:
    interp = {
        "schema_version": 8, "echo_id": "echo_89100001",
        "interpretation_seq": 0, "source_location_id": 89100001,
        "source_item_name": "Bomb", "source_recipient_name": "Skyiah",
        "source_game": "Archipepsi", "display_name": "Grenade",
        "description": "Boom.", "concepts": ["blast"], "mode": "literal",
        "operations": [{"op": "create", "component": {
            "kind": "action", "component_id": CID,
            "display_name": "Grenade", "description": "Boom.",
            "slot": "consumable", "cooldown": 1.0, "charges": 3,
            "primitive": {"type": "hitscan_damage", "damage": 8.0,
                          "pellets": 1, "spread_degrees": 1.0,
                          "range": 35.0}}}],
    }
    return P.CampaignSave(
        seed_name="Seed", team=0, slot_id=1, slot_name="Skyiah",
        interpretations=(interp,), next_interpretation_seq=1)


def _authorize(save, index, gen=None):
    return T.authorize_consumable(
        save, CID, use_index=index,
        generation=save.consumable_generation if gen is None else gen)


# --------------------------------------------------------------------------
# The charge moves at authorize time
# --------------------------------------------------------------------------

def test_authorizing_spends_the_charge_before_any_report():
    save = _save()
    assert save.charges_left(CID) == 3
    save = _authorize(save, 1)
    assert save.charges_left(CID) == 2, (
        "the charge is still there before the effect is reported, which "
        "is exactly the window a crash falls into")
    assert len(save.consumable_authorizations) == 1


def test_the_report_settles_the_authorization_rather_than_charging_again():
    """The opposite failure, and just as silent.

    `spend_charge` has to notice that this use is already counted. It
    also has to check that BEFORE the "next one due" test, because an
    authorization has already moved `spent` past its own index — so the
    index check would refuse the very report it is waiting for. That
    ordering bug was live until this test existed.
    """
    save = _authorize(_save(), 1)
    save = T.spend_charge(save, CID, 1, save.consumable_generation)
    assert save.charges_left(CID) == 2, "one effect, one charge"
    assert save.consumable_authorizations == (), "the record is settled"


def test_the_settle_branch_is_load_bearing():
    """Sabotage, with the target FUNCTION confirmed.

    Remove the settle and the authorize-then-report pair either
    double-charges or is refused outright. A green suite with the branch
    gone would mean nothing here reaches it.
    """
    src = inspect.getsource(T.spend_charge)
    assert "AN AUTHORIZED CHARGE IS ALREADY COUNTED" in src
    at_settle = src.index("AN AUTHORIZED CHARGE IS ALREADY COUNTED")
    assert at_settle < src.index("is not the next one due"), (
        "the settle runs after the index check, where an authorized use "
        "can never reach it")
    assert src.index("was minted against supply") < at_settle, (
        "a stale authorization must be reported as stale, not settled")


# --------------------------------------------------------------------------
# Two presses inside one cooldown
# --------------------------------------------------------------------------

def test_cancelling_the_second_press_preserves_the_first():
    """The defect a per-component reservation has and this does not.

    One entry per component is overwritten by the next press, so
    cancelling the second forgets the first — and the first launched.
    Keyed by `(component, generation, use_index)`, they are two records.
    """
    save = _authorize(_authorize(_save(), 1), 2)
    assert save.charges_left(CID) == 1
    save = T.release_consumable_authorization(
        save, CID, use_index=2, generation=save.consumable_generation)
    assert save.charges_left(CID) == 2, (
        "cancelling the unlaunched second attempt refunded the launched "
        "first one as well")
    assert [a.use_index for a in save.consumable_authorizations] == [1]


def test_only_the_newest_authorization_may_be_released():
    save = _authorize(_authorize(_save(), 1), 2)
    with pytest.raises(ValueError, match="is not the newest"):
        T.release_consumable_authorization(
            save, CID, use_index=1, generation=save.consumable_generation)


def test_releasing_something_never_authorized_is_refused():
    with pytest.raises(ValueError, match="no outstanding authorization"):
        T.release_consumable_authorization(
            _save(), CID, use_index=1, generation=0)


def test_an_authorization_against_a_retired_supply_is_refused():
    save = _authorize(_save(), 1)
    stale = save.consumable_generation
    save = save.model_copy(update={
        "consumable_generation": stale + 1,
        "consumable_authorizations": ()})
    with pytest.raises(ValueError, match="was minted against supply"):
        T.authorize_consumable(save, CID, use_index=1, generation=stale)


# --------------------------------------------------------------------------
# The process-lifetime case, across a real process boundary
# --------------------------------------------------------------------------

def _in_a_fresh_process(path: Path, body: str):
    """Load the save in a NEW interpreter and continue it there.

    `sys.executable -c`, not an import: the point is a process that has
    never held any of this one's objects — which is the whole difference
    between a lost socket and a lost client.
    """
    script = textwrap.dedent("""
        import json, sys
        sys.path.insert(0, {bridge!r})
        from pathlib import Path
        from archipepsi_bridge import store
        from archipepsi_bridge.schemas import transitions as T
        save = store.load_save(Path({path!r}))
        assert save is not None
        answer = None
    """).format(bridge=_BRIDGE, path=str(path)) + textwrap.dedent(body) + (
        "\nprint(json.dumps(answer))\n")
    done = subprocess.run([sys.executable, "-c", script],
                          capture_output=True, text=True, timeout=120)
    assert done.returncode == 0, (
        f"the relaunched client failed:\n{done.stderr}")
    return json.loads(done.stdout.strip())


def test_a_relaunched_client_cannot_reuse_an_authorized_charge(tmp_path):
    """Launch, lose the report, terminate, relaunch, press again.

    The authorized charge is gone and stays gone — and the rest of the
    supply still works, which is the part a bare refusal would get
    wrong. A client that could not spend anything afterwards would be
    safe and broken.
    """
    save = _authorize(_save(), 1)          # authorized, then the report
    path = store.save_path(tmp_path, save.seed_name, save.team,
                           save.slot_id, save.slot_name)
    store.write_save(path, save)           # is lost and the client dies

    answer = _in_a_fresh_process(path, """
        cid = "act_nade"
        before = save.charges_left(cid)
        assert before == 2, before

        # The relaunched client presses. It has never seen the dead
        # process's list; all it has is the snapshot's count.
        nxt = 3 - before + 1
        spent = T.spend_charge(save, cid, nxt, save.consumable_generation)
        answer = {"before": before, "index_pressed": nxt,
                  "after": spent.charges_left(cid),
                  "outstanding": len(spent.consumable_authorizations)}
    """)
    assert answer["before"] == 2, "the burned charge came back"
    assert answer["index_pressed"] == 2, (
        "the relaunched client tried to reuse the authorized index")
    assert answer["after"] == 1, (
        "the press either did nothing or spent a charge that was "
        "already gone")
    assert answer["outstanding"] == 1, (
        "the unsettled authorization vanished, which is the in-memory "
        "list's failure arriving in the save")


def test_a_relaunched_client_is_handed_nothing_it_could_release(tmp_path):
    """The snapshot carries the reduced count and not the records.

    Only the process that authorized knows whether the effect launched,
    and that is the one fact a release turns on. A fresh client must not
    be able to refund a charge whose effect it cannot know about.
    """
    save = _authorize(_save(), 1)
    payload = json.loads(save.model_dump_json())
    assert payload["consumable_authorizations"], "the SAVE holds them"

    fields = set(P.CampaignSnapshot.model_fields)
    assert "consumable_authorizations" not in fields, (
        "the snapshot mirrors the authorizations, so a relaunched client "
        "is handed records it has no way to judge")
    assert "consumable_uses" in fields, (
        "the client still needs the counts it is allowed to see")
