"""A room is offered only the doorways its producer actually builds.

**The defect this closes.** `PROCEDURAL_SOCKETS` named four openings for
every procedural room, so `compose_with_branch` hung a branch off a
`platform_path`'s `side_left` exactly as it would off an arena's — and
that producer raises a solid wall there, over its kill pit and below its
walkway. A door declared `USED` that the engine measures as solid
refuses the WHOLE layout (`AMALGAM_BRIDGE.md` §5.9 rule 5), which is why
a default-scale Zone could not be accepted at all.

The capacity is one declaration, `C.PROCEDURAL_SOCKET_CAPACITY`, read by
three paths that used to each have their own answer: the composer
(`topology._sockets_for`), this schema (`Zone`'s socket invariant) and
the engine (`ChamberBuilders.procedural_sockets`, via `constants.gd`).
Which rooms are in it is a MEASUREMENT, taken in `godot-zone-audit`, one
control per chamber type: a hole, and floor a metre inside it.

**It is a statement about today's producers.** A `platform_path` that
grows a side landing comes out of the map; nothing here is a rule about
what a platform room may be.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from archipepsi_bridge import topology
from archipepsi_bridge.schemas import constants as C
from archipepsi_bridge.schemas.zone import (PROCEDURAL_SOCKETS, Zone,
                                            procedural_sockets_for)
from .test_layout import _arena

SAMPLE = (Path(__file__).resolve().parents[2]
          / "godot" / "tests" / "fixtures" / "sample")

#: The two producers that CLIMB, measured solid on both sides.
CAPPED = ("platform_path", "tower")


def _path(rid: str) -> dict:
    return {"id": rid, "type": "platform_path", "segment_count": 4,
            "gap_size": 2.0, "vertical_step": 0.5}


def _composed(climbing_at: int | None = 3):
    """A real composed Zone, optionally with one room that climbs."""
    chambers = [_arena(f"c{i:03d}", reward=89100000 + i) for i in range(1, 9)]
    if climbing_at is not None:
        chambers[climbing_at] = _path(f"c{climbing_at + 1:03d}")
    z = Zone(zone_id="z1", display_name="T", target_game="T",
             theme="void_glitch", chambers=tuple(chambers))
    return topology.apply(z, topology.compose_with_branch(list(z.chambers)))


def _with_doors(zone, room_id: str, sockets):
    """The same Zone with one room's door list replaced.

    Reconstructed through `Zone(**...)` rather than `model_copy`, because
    a copy skips the validators and the validators are what is under
    test. The replacement keeps each door's existing edge where the
    socket still carries one, so only the SET of mentioned sockets
    changes.
    """
    dumped = zone.model_dump()
    for chamber in dumped["chambers"]:
        if chamber["id"] != room_id:
            continue
        was = {d["socket_id"]: d for d in chamber["doors"]}
        chamber["doors"] = [
            was.get(s, {"socket_id": s, "usage": "SEALED", "edge_id": None})
            for s in sockets]
    return Zone(**dumped)


# --- the declaration itself ----------------------------------------------

def test_the_capacity_is_one_declaration_three_paths_read():
    """A fix in the planner alone is the two-vocabulary defect again."""
    for kind in CAPPED:
        assert procedural_sockets_for(kind) == ("entry", "exit")
    assert procedural_sockets_for("arena") == PROCEDURAL_SOCKETS
    assert procedural_sockets_for("corridor") == PROCEDURAL_SOCKETS
    # The engine reads this same map out of `constants.gd`, which
    # `export.py` writes from here; `test_schemas.py` fails if that copy
    # goes stale.
    assert set(C.PROCEDURAL_SOCKET_CAPACITY) == set(CAPPED)


# --- composition ----------------------------------------------------------

def test_a_climbing_room_is_never_offered_a_side_branch():
    """The room stays in the Zone and stays on the spine; what it loses
    is the advertisement, not its place."""
    chambers = [_arena(f"c{i:03d}", reward=89100000 + i) for i in range(1, 9)]
    chambers[3] = _path("c004")
    z = Zone(zone_id="z1", display_name="T", target_game="T",
             theme="void_glitch", chambers=tuple(chambers))
    out = topology.apply(z, topology.compose_with_branch(list(z.chambers)))
    room = next(c for c in out.chambers if c.id == "c004")
    named = {d.socket_id for d in room.doors}
    assert named == {"entry", "exit"}, named
    assert all(d.usage != "SEALED" or d.socket_id in named
               for d in room.doors)
    assert "c004" in {c.id for c in out.chambers}


def test_the_composer_cannot_assign_a_door_the_producer_will_not_build():
    """`topology.apply`'s guard, sabotaged.

    True by construction — every assignment comes from `_sockets_for` —
    and asserted anyway, because "true by construction" is exactly what
    the flat socket table was while the wall stayed solid.
    """
    chambers = [_arena(f"c{i:03d}", reward=89100000 + i) for i in range(1, 9)]
    chambers[3] = _path("c004")
    z = Zone(zone_id="z1", display_name="T", target_game="T",
             theme="void_glitch", chambers=tuple(chambers))
    product = topology.compose_with_branch(list(z.chambers))
    door = type(product.doors["c001"][0])
    sabotaged = product.doors["c004"] + (
        door(socket_id="side_left", usage="USED", edge_id="e:c004:c009"),)
    bad = product.__class__(**{**product.__dict__,
                              "doors": {**product.doors, "c004": sabotaged}})
    with pytest.raises(ValueError, match="does not build"):
        topology.apply(z, bad)


def test_an_authored_shell_answers_for_itself():
    """A shell that shares a chamber type is NOT held to the procedural
    producer's limits: its openings are in its catalogue entry and
    `_sockets_for` reads them there."""
    chambers = [_arena(f"c{i:03d}", reward=89100000 + i) for i in range(1, 9)]
    shelled = chambers[3] | {"type": "platform_path", "shell_id": "x_shell"}
    z = Zone(zone_id="z1", display_name="T", target_game="T",
             theme="void_glitch",
             chambers=tuple(chambers[:3] + [_path("c004")] + chambers[4:]))
    caps = {"x_shell": ("entry", "exit", "side_left", "side_right")}
    room = next(c for c in z.chambers if c.id == "c004")
    assert topology._sockets_for(room, caps) == ("entry", "exit"), (
        "a procedural platform_path carries two")
    from types import SimpleNamespace
    as_shell = SimpleNamespace(id="c004", type="platform_path",
                               shell_id="x_shell")
    assert topology._sockets_for(as_shell, caps) == caps["x_shell"], (
        "and the same chamber type behind a shell carries what the "
        "shell declares, which is the whole point of reading it")
    assert shelled["type"] == "platform_path"


def test_a_zone_with_no_capable_junction_says_so_rather_than_pretending():
    """Silently becoming a chain is what must not happen.

    Every room here climbs, so nothing has a side to spare. The Zone is
    still composable — a chain is a legal topology and always was — and
    the product SAYS why it is one instead of leaving a reader to infer
    that branching quietly stopped working.
    """
    z = Zone(zone_id="z1", display_name="T", target_game="T",
             theme="void_glitch",
             chambers=tuple(_path(f"c{i:03d}") for i in range(1, 7)))
    product = topology.compose_with_branch(list(z.chambers))
    assert not product.plugs, "nothing here can host a branch"
    assert any("no junction" in n or "chain" in n for n in product.notes), (
        f"the composer must say why there is no branch: {product.notes}")


# --- compatibility --------------------------------------------------------

def test_a_saved_zone_that_names_the_old_four_sockets_still_loads():
    """OLD SAVES STAY READABLE, which is the reason the name vocabulary
    did not shrink with the capacity.

    A campaign composed before this was measured holds `platform_path`
    rooms with `side_left`/`side_right` in their door list. `ZoneRecord.
    zone` is a typed `Zone`, so a schema that refused those names would
    refuse to LOAD those campaigns. They load; what happens next is that
    their layout is refused on the aperture the engine no longer cuts,
    and the Zone is recomposed with the corrected capacity.
    """
    zone = _composed()
    old = _with_doors(zone, "c004", PROCEDURAL_SOCKETS)
    room = next(c for c in old.chambers if c.id == "c004")
    assert {d.socket_id for d in room.doors} == set(PROCEDURAL_SOCKETS)


def test_a_climbing_room_composed_today_mentions_only_its_two():
    """And the new shape is not read as an omission. The invariant asks
    for every socket the room CARRIES to be mentioned, not every name a
    procedural room can be given."""
    zone = _composed()
    room = next(c for c in zone.chambers if c.id == "c004")
    assert {d.socket_id for d in room.doors} == {"entry", "exit"}, (
        "the composer already produces the two-socket shape; this is "
        "the schema agreeing that it is complete")


def test_a_flat_room_still_owes_all_four():
    """The invariant did not simply get weaker: an arena that leaves a
    side unmentioned is still an unaudited hole waiting to happen."""
    zone = _composed()
    with pytest.raises(ValueError, match="unmentioned"):
        _with_doors(zone, "c002", ("entry", "exit"))


# --- the regenerated sample ----------------------------------------------

def test_the_sample_assigns_no_door_a_producer_cannot_build():
    """THE WIDER EVIDENCE, on the twenty Zones the sample declares.

    Regenerated from the same source inputs after the capacity was
    corrected; `godot/tests/fixtures/sample-before-capacity/` keeps what
    they were, so the change is comparable rather than replaced.
    """
    files = sorted(SAMPLE.glob("zone_*.json"))
    if not files:
        pytest.skip("run `make zone-sample` to regenerate the sample")
    assert len(files) == 20
    offenders = []
    joined = 0
    for path in files:
        zone = json.loads(path.read_text())
        for chamber in zone["chambers"]:
            if chamber.get("shell_id"):
                continue
            carried = set(procedural_sockets_for(chamber["type"]))
            for door in chamber.get("doors") or ():
                if door["usage"] == "SEALED":
                    continue
                joined += 1
                if door["socket_id"] not in carried:
                    offenders.append(
                        f"{path.name}:{chamber['id']}/{door['socket_id']} "
                        f"({chamber['type']})")
    assert joined > 100, f"only {joined} joined doors; the sample is thin"
    assert not offenders, offenders
