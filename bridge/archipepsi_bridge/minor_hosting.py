"""O05-06: the existing minors added to a composed Zone, or declined by name.

**The candidate profile's last step.** Handed a Zone the campaign really
composed -- graph proved, every earlier relationship already placed --
it looks for a dead end the minor can be built behind, and adds the
minor there as a room of its own. Nothing is loaded from a fixture and
no room is named here: the parent is derived from the Zone's own
structure, and when none qualifies the Zone comes back exactly as it
was, with the reason.

**ADDED, NOT SUBSTITUTED (P5-13).** The first version turned a dead-end
arena INTO the minor, and every Zone the fallback composes refused it:
the provider fills a Zone to within a few points of its content floor
(903 of a 900 minimum on the played Zone), `content_value.room_value`
has no row for a minor, so the replaced arena's enemies and activity
left the count and the Zone fell out of its band -- 0 of 12 in the
frozen sample. Valuing a minor is a row in that table, and the table is
Dess's (CAMPAIGN_SCALE.md 5). So nothing counted is removed: the parent
keeps its fight, its activity and its objective, and the minor is new
content behind it that the budget does not count.

**What moves is one Check, one room deeper.** The minor's objective
holds a Check, and it takes its parent's. "An AP Check is not content"
(`content_value`), so the Zone's value is unchanged; the Zone still
holds every Check it was allocated; and the Check's logic is the
parent's plus the minor's puzzle, which asks for the base kit and the
room's own `lightened` applicator and nothing an AP location would have
to declare. The parent's objective then gates nothing, which the engine
already handles (`ZoneController._push_objective_state`).

**A parent is a dead end.** One way in, on an ungated doorway, a free
joining socket to build the minor off, one Check and no Zone-local key,
and no other relationship's control. The minor's own far opening is
`SEALED`, so it leads nowhere: every other room, Check and key is
reached exactly as the proved graph said.

**Re-certified like every other step**, and reversible: the Zone goes
through the real schema and `topology.reachability` here, then the
campaign's `_candidate` holds it to `validate_zone` with the minor's
own shell rule added to the offer (`certify_offer`), and `candidate.
strip` takes it back out (`unhost`) when the graph is recomposed.
"""
from __future__ import annotations

import re
from dataclasses import dataclass

from . import shells
from .schemas.minors import CONTRACTS, MinorContract
from .schemas.zone import Zone, procedural_sockets_for
from .topology import reachability

#: The parent types a minor is built behind. An arena, because its
#: objective gates only its own reward (so giving the Check away changes
#: nothing else in it) and a flat room's far wall is a real doorway.
PARENT_TYPES = ("arena",)
#: Which of a parent's free sockets the minor may hang off, in order.
#:
#: SIDE SOCKETS ONLY, because of what the parent always is. A dead end
#: is never on the spine -- a spine room continues exit-to-entry, and the
#: last one holds the Zone's way out -- so it is a branch room, and the
#: engine's placement grammar hangs a branch off a SIDE socket: an
#: exit-to-entry edge is read as a spine link, and a room continuing a
#: branch through its `exit` is placed nowhere
#: (`zone_builder.placement_plan`: "in no spine and on no branch").
#: Measured: the first live run refused the layout for exactly that.
SOCKET_PREFERENCE = ("side_right", "side_left")


@dataclass(frozen=True)
class HostedMinor:
    zone: Zone
    #: The rooms the minors now are, in the contracts' order.
    rooms: tuple[str, ...]
    note: str

    @property
    def emitted(self) -> bool:
        return bool(self.rooms)

    @property
    def room_id(self) -> str | None:
        """The first minor's room, or None when nothing was emitted."""
        return self.rooms[0] if self.rooms else None


def _occupied(zone: Zone) -> dict[str, str]:
    """Rooms another relationship already stands in, and which one."""
    out: dict[str, str] = {}
    for v in zone.zone_state:
        if v.setter is not None:
            out.setdefault(v.setter.room_id, f"the '{v.variable_id}' setter")
        for reader in v.readers:
            out.setdefault(reader.room_id, f"a '{v.variable_id}' reader")
    for o in zone.transported_objects:
        out.setdefault(o.home_room_id, f"'{o.object_id}''s home")
    for c in zone.object_consumers:
        out.setdefault(c.room_id, f"the '{c.mechanism_id}' socket")
    for g in zone.room_graphs:
        out.setdefault(g.room_id, "a signal graph")
    for n in zone.rail_networks:
        for dock in n.docks:
            out.setdefault(dock.room_id, f"railway '{n.network_id}'")
    if zone.featured_acquisition is not None:
        out.setdefault(zone.featured_acquisition.room_id,
                       "the featured acquisition")
    return out


def _free_sockets(chamber, registry) -> tuple[str, ...]:
    """The joining sockets this room can hold and has not assigned, in
    the order they are tried. Each is only a candidate: the Zone schema
    still judges the doorway (a gallery hugging that wall refuses it)."""
    if chamber.shell_id:
        entry = registry.get(chamber.shell_id)
        offered = shells.joinable_sockets(entry) if entry else ()
    else:
        offered = procedural_sockets_for(chamber.type)
    taken = {d.socket_id for d in chamber.doors if d.usage != "SEALED"}
    return tuple(s for s in SOCKET_PREFERENCE
                 if s in offered and s not in taken)


def parent_problem(zone: Zone, chamber, first: str,
                   occupied: dict[str, str], registry) -> str | None:
    """Why a minor cannot be built behind `chamber`, or None when it can."""
    if chamber.type not in PARENT_TYPES:
        return f"is a {chamber.type}"
    if getattr(chamber, "shell_id", None) in CONTRACTS:
        return "is itself a minor"
    if chamber.id == first:
        return "is where the Zone starts"
    if chamber.id in occupied:
        return f"already holds {occupied[chamber.id]}"
    if chamber.keys:
        return "holds a Zone-local key"
    if not chamber.reward_ids:
        return "carries no Check to hand the minor's objective"
    if len(chamber.reward_ids) > 1:
        return f"carries {len(chamber.reward_ids)} Checks"
    open_doors = [d for d in chamber.doors if d.usage != "SEALED"]
    if len(open_doors) != 1:
        return (f"has {len(open_doors)} open doorways; a minor is built "
                "behind a dead end")
    door = open_doors[0]
    if door.usage != "USED" or chamber.depart_edge is not None \
            or door.edge_id != chamber.arrive_edge:
        return "is not entered by its one open door"
    edge = next((e for e in zone.edges if e.edge_id == door.edge_id), None)
    if edge is None or edge.realization != "JOINED":
        return "is not entered through a doorway"
    if edge.capability or edge.requires_state or edge.opened_by:
        return f"is entered through a gated doorway ('{edge.edge_id}')"
    if not _free_sockets(chamber, registry):
        return "has no free joining socket to build the minor off"
    return None


def _next_room_id(zone: Zone) -> str:
    taken = {c.id for c in zone.chambers}
    numbers = [int(m.group(1)) for c in zone.chambers
               if (m := re.fullmatch(r"c(\d+)", c.id))]
    n = max(numbers, default=0) + 1
    while f"c{n:03d}" in taken:
        n += 1
    return f"c{n:03d}"


def _minor_room(room_id: str, edge_id: str, check: int,
                contract: MinorContract, rule: dict) -> dict:
    """The minor, as a chamber: its shell's size, one Check, one way in."""
    room = {
        "id": room_id, "type": contract.chamber_type,
        "shell_id": contract.shell_id,
        "reward_location_id": check, "objective": "reach_reward",
        "enemies": [{"archetype": archetype, "count": count}
                    for archetype, count in contract.enemies],
        "activities": [], "features": [],
        # `adopt` writes the shell's own size over these; they are only
        # here so it has keys to write.
        "width": 0.0, "depth": 0.0, "wall_height": 0.0,
        "doors": ([{"socket_id": contract.entry_socket, "usage": "USED",
                    "edge_id": edge_id}]
                  + [{"socket_id": s, "usage": "SEALED"}
                     for s in contract.sealed_sockets]),
        "arrive_edge": edge_id,
    }
    shells.adopt(room, rule)
    return room


def offer_order(zone_id: str) -> tuple[MinorContract, ...]:
    """The order a Zone offers the minors in: rotated by its ordinal.

    **A selection rule, this lane's, recorded for Dess.** Every Zone of
    the frozen sample has at most two dead ends a minor can be built
    behind, and there are three minors. In one fixed order the third
    never finds a host in any Zone -- EX50-011 was hosted in 0 of 12. So
    the order turns with the Zone's place in the campaign: `zone_001`
    offers the contracts as declared, `zone_002` from the second, and so
    on, and a campaign meets every minor. O05-06.5: "The composer does
    not need to place all three in every Zone."

    Deterministic by the Zone's own id, so a re-composition after host
    re-selection makes the same choice. An id without an ordinal takes
    the declared order.
    """
    contracts = tuple(CONTRACTS.values())
    found = re.fullmatch(r"zone_(\d+)", zone_id or "")
    turn = (int(found.group(1)) - 1) % len(contracts) if found else 0
    return contracts[turn:] + contracts[:turn]


def compose_minor(zone: Zone, registry=None) -> HostedMinor:
    """Build every contracted minor behind its own dead end of `zone`.

    In the Zone's offer order (`offer_order`), each on the Zone the
    previous one left: a parent that took a minor is no longer a dead
    end, and a minor is never a parent. A minor that finds no parent
    declines by name without stopping the others.
    """
    reg = registry if registry is not None else shells.load_registry()
    built: list[str] = []
    notes: list[str] = []
    for contract in offer_order(zone.zone_id):
        zone, room_id, note = _host_one(zone, contract, reg)
        if room_id is not None:
            built.append(room_id)
        notes.append(note)
    return HostedMinor(zone, tuple(built), "; ".join(notes))


def _host_one(zone: Zone, contract: MinorContract, reg):
    """`(zone, room_id, note)`: the minor built, or `(zone, None, why)`."""
    entry = reg.get(contract.shell_id)
    if entry is None:
        return zone, None, (f"{contract.catalogue_id}: the registry holds "
                            f"no '{contract.shell_id}'")
    already = [c.id for c in zone.chambers if c.shell_id == contract.shell_id]
    if already:
        return zone, None, (f"{contract.catalogue_id} is already hosted in "
                            f"{already}")
    first = zone.chambers[0].id if zone.chambers else ""
    occupied = _occupied(zone)
    rule = shells.rule_of(entry)
    room_id = _next_room_id(zone)
    problems: list[tuple[int, int, str]] = []
    base = zone.model_dump()
    for index, parent in enumerate(zone.chambers):
        if parent.type not in PARENT_TYPES:
            continue
        why = parent_problem(zone, parent, first, occupied, reg)
        if why:
            # THE DEAD ENDS' REASONS FIRST. They are the rooms that nearly
            # qualified, so a decline that is read only as far as its
            # first few reasons still says what decided it.
            dead_end = sum(d.usage != "SEALED" for d in parent.doors) == 1
            problems.append((0 if dead_end else 1, index,
                             f"'{parent.id}' {why}"))
            continue
        edge_id = f"e:{parent.id}:{room_id}"
        candidate, socket, refused = None, "", ""
        for socket in _free_sockets(parent, reg):
            raw = {**base, "chambers": list(base["chambers"]),
                   "edges": list(base["edges"])}
            parent_raw = dict(raw["chambers"][index])
            parent_raw["doors"] = [
                d for d in parent_raw["doors"] if d["socket_id"] != socket
            ] + [{"socket_id": socket, "usage": "USED", "edge_id": edge_id}]
            parent_raw["reward_location_id"] = None
            # The composer's own rule for a nested room with ONE onward
            # edge: that edge is the chain's continuation through it
            # (`topology.compose_with_branch`, "departures").
            parent_raw["depart_edge"] = edge_id
            raw["chambers"][index] = parent_raw
            raw["chambers"].append(_minor_room(
                room_id, edge_id, parent.reward_ids[0], contract, rule))
            raw["edges"].append({
                "edge_id": edge_id, "room_a": parent.id, "room_b": room_id,
                "direction": "BIDIRECTIONAL", "realization": "JOINED"})
            try:
                candidate = Zone.model_validate(raw)
                break
            except ValueError as exc:
                lines = str(exc).splitlines()
                refused = lines[-2].strip() if len(lines) > 1 else str(exc)
                candidate = None
        if candidate is None:
            problems.append((0, index, f"'{parent.id}': the Zone schema "
                                       f"refused every free doorway "
                                       f"({refused})"))
            continue
        verdict = reachability(candidate)
        if not verdict.ok:
            problems.append((0, index, f"'{parent.id}': "
                             + "; ".join(verdict.errors[:2])))
            continue
        latches = ", ".join(f"minor_{room_id}/{latch}"
                            for latch in contract.latches)
        return candidate, room_id, (
            f"{contract.catalogue_id} {contract.name} built as "
            f"'{room_id}' behind the dead end '{parent.id}' (its "
            f"'{socket}' doorway); '{parent.id}''s Check "
            f"{parent.reward_ids[0]} moved into the minor, at its "
            f"objective; it records {latches}")
    reasons = [why for _, _, why in sorted(problems)]
    return zone, None, (
        f"{contract.catalogue_id} declined: no dead end can take it"
        + (f" ({'; '.join(reasons[:4])}"
           + (f"; and {len(reasons) - 4} more" if len(reasons) > 4 else "")
           + ")" if reasons else " (the Zone has no arena)"))


def hosted(zone: Zone) -> dict[str, MinorContract]:
    """`room_id -> contract` for every room of `zone` that is a minor."""
    out: dict[str, MinorContract] = {}
    for chamber in zone.chambers:
        contract = CONTRACTS.get(getattr(chamber, "shell_id", None) or "")
        if contract is not None:
            out[chamber.id] = contract
    return out


def unhost(zone: Zone) -> Zone:
    """`zone` without its minors: each Check handed back to its parent.

    What `candidate.strip` needs before a graph is recomposed. The
    parent is the room on the minor's `arrive_edge`, and it held exactly
    this Check before the step moved it, so handing it back is exact.
    Doors, edges and plugs are left to the graph composer, which is
    about to replace all three.
    """
    minors = hosted(zone)
    if not minors:
        return zone
    parents: dict[str, int] = {}
    for chamber in zone.chambers:
        if chamber.id not in minors or chamber.arrive_edge is None:
            continue
        edge = next((e for e in zone.edges
                     if e.edge_id == chamber.arrive_edge), None)
        if edge is not None and len(chamber.reward_ids) == 1:
            parent = edge.room_a if edge.room_b == chamber.id else edge.room_b
            parents[parent] = chamber.reward_ids[0]

    def handed_back(chamber):
        data = chamber.model_dump()
        data["reward_location_id"] = parents[chamber.id]
        return type(chamber).model_validate(data)

    chambers = tuple(handed_back(c) if c.id in parents else c
                     for c in zone.chambers if c.id not in minors)
    return zone.model_copy(update={"chambers": chambers})


def certify_offer(offer: dict, registry=None) -> dict:
    """The provider's offer with every contracted minor's shell added.

    `validate_zone` refuses a shell the offer did not contain, and the
    provider's offer never contains a minor -- deliberately, because a
    minor is placed by this step and not chosen by a provider. So the
    candidate profile is certified against the provider's offer PLUS
    each minor's own registry rule, and against nothing looser: a Zone
    naming a minor in a room its rule does not fit is still refused.
    """
    reg = registry if registry is not None else shells.load_registry()
    catalog = {k: list(v) for k, v in
               (offer.get("shell_catalog") or {}).items()}
    rules = dict(offer.get("shell_rules") or {})
    legal = set(offer.get("legal_shell_ids") or ())
    for contract in CONTRACTS.values():
        entry = reg.get(contract.shell_id)
        if entry is None:
            continue
        rules[contract.shell_id] = shells.rule_of(entry)
        legal.add(contract.shell_id)
        ids = catalog.setdefault(contract.chamber_type, [])
        if contract.shell_id not in ids:
            ids.append(contract.shell_id)
    return {**offer, "legal_shell_ids": tuple(sorted(legal)),
            "shell_catalog": catalog, "shell_rules": rules}
