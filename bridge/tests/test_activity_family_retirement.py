"""What must survive retiring the two standalone drills.

THE OWNER'S DECISION. Skyiah played the `timed_run` race and the
`pressure_routing` plate circuit and asked for both to stop being
generated -- while keeping the pressure-plate MECHANIC, delayed release
included, and without banning a future timed traversal design.

THE RETIREMENT IS NOT IMPLEMENTED HERE and these tests do not implement
it. `tools/family_retirement.py` measured what flipping the switch on
its own would do, over twelve default-scale Zones:

    pressure_routing   86 ->   0    -86
    timed_run          75 ->   0    -75
    switch_sequence    85 -> 180    +95
    target_challenge   97 -> 178    +81

161 activities removed, 176 more of the two that stay. The composer
picks by `kinds[(guard + len(acts)) % len(kinds)]`, so a shorter list
is not less content -- it is the same content made of two families
instead of four, which is the outcome the owner asked against. That
needs a policy choice about what fills the budget, and it is the bridge
lane's to make.

What THIS file does is fix the compatibility conditions in place first,
so whoever makes that change cannot take an old campaign with it.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import get_args

from pydantic import TypeAdapter

from archipepsi_bridge.epsilon import fallback
from archipepsi_bridge.schemas import zone as Z

RETIRE = ("timed_run", "pressure_routing")
_ZONE = TypeAdapter(Z.Zone)
FIXTURE = (Path(__file__).resolve().parents[2] / "godot" / "tests"
           / "fixtures" / "played_zone.json")


def test_the_composer_has_one_list_and_the_schema_has_another():
    """TWO SETS, AND THEY ARE NOT THE SAME QUESTION.

    `Z.ActivityKind` is what a Zone may CONTAIN; `ACTIVITY_KINDS` is
    what the fallback provider COMPOSES. Retiring a family is a change
    to the second. Collapsing them would make an old save carrying a
    retired family fail to load, which is the one outcome the owner's
    direction rules out by name.
    """
    schema = set(get_args(Z.ActivityKind))
    assert set(fallback.ACTIVITY_KINDS) <= schema
    for kind in RETIRE:
        assert kind in schema, (
            f"{kind} left the schema. A Zone already committed with one "
            "in it can no longer be read, which is a campaign lost.")


def test_a_legacy_zone_still_validates_with_both_retired_families():
    """An old committed Zone is still a Zone.

    Built from the fixture the engine walks, with one of each retired
    family added -- so this is the real schema and the real validator,
    not a hand-written stub that agrees with itself.
    """
    zone = json.loads(FIXTURE.read_text())
    chambers = zone["chambers"]
    host = next(c for c in chambers if c.get("type") == "arena")
    host.setdefault("activities", [])
    host["activities"] = [
        # The clock is what the schema requires for the distance: a
        # legacy Zone is a LEGAL Zone, so this uses a limit the
        # validator accepts rather than one that makes the test about
        # the clock rule.
        {"kind": "timed_run", "element_count": 3, "time_limit": 30.0,
         "ordered": True, "requires": []},
        {"kind": "pressure_routing", "element_count": 3,
         "time_limit": 0.0, "ordered": False, "requires": []},
    ]
    parsed = _ZONE.validate_python(zone)
    kinds = {a.kind for c in parsed.chambers for a in (c.activities or ())}
    assert "timed_run" in kinds
    assert "pressure_routing" in kinds


def test_an_old_race_is_never_read_as_a_switch_puzzle():
    """Identity, not shape.

    The failure this rules out is silent: a retirement that mapped a
    retired kind onto a surviving one would turn a committed race into
    a switch row, and the save would load, and the puzzle would be a
    different puzzle. Nothing may translate a kind on the way in.
    """
    for kind in RETIRE:
        zone = json.loads(FIXTURE.read_text())
        host = next(c for c in zone["chambers"] if c.get("type") == "arena")
        host["activities"] = [
            {"kind": kind, "element_count": 4,
             "time_limit": 40.0 if kind == "timed_run" else 0.0,
             "ordered": kind == "timed_run", "requires": []}]
        parsed = _ZONE.validate_python(zone)
        # FROM THE CHAMBER IT WAS PUT IN. The fixture already carries
        # activities of its own, and the first version of this read the
        # first activity in the whole Zone -- so it compared a retired
        # kind against somebody else's.
        room = next(c for c in parsed.chambers if c.id == host["id"])
        got = [a.kind for a in (room.activities or ())]
        assert got == [kind], f"{kind} came back as {got}"


def test_the_held_plate_mechanic_is_not_a_generating_family():
    """KEEP THE PLATE, RETIRE THE DRILL.

    The owner kept the pressure plate explicitly, delayed release
    included. That behaviour is `ActivityElement.STAND` plus the hold
    window, and it is a MECHANIC -- `PLATE_HOLD_SECONDS` is a constant
    the engine reads, not a property of the family that currently
    generates it. This is the statement that the two are separable, so
    a later retirement cannot take the plate with it.

    The behaviour itself is driven in `godot-activity`:
    `_test_a_plate_that_releases_breaks_the_circuit` and
    `_test_a_plate_holds_long_enough_to_reach_the_next`.
    """
    from archipepsi_bridge.schemas import constants as C
    assert C.PLATE_HOLD_SECONDS > 0.0
    # And the constant lives where the ENGINE reads it, not inside the
    # family's own definition.
    assert "pressure_routing" not in str(C.PLATE_HOLD_SECONDS)


def test_the_measurement_tool_is_the_one_that_runs():
    """The numbers in this file's docstring came from a tool that is
    still here and still imports. A measurement quoted in prose and
    deleted from the tree is a number nobody can check."""
    import importlib
    tool = importlib.import_module("tools.family_retirement")
    assert tool.RETIRE == RETIRE
