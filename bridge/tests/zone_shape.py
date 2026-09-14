"""The JOINED graph of an accepted Zone, measured rather than assumed.

**Rooms moved off the spine is not the number of choices a Zone offers.**
Four off-spine rooms can be one side chain four deep — one decision, taken
once — or four separate side destinations, which is four. Counting locked
doors is a third thing again, and since a branch need not be locked it is
now the smallest of the three. So this reads the graph the Zone actually
serialized.

Return plugs are excluded everywhere. A plug is `TRAVERSAL_ONLY`, spends no
socket, and a dead end that carries one is still a dead end.

**This measures the graph, and nothing else.** Bridge acceptance is not
Godot layout acceptance, and neither is a player walking it.
"""

from __future__ import annotations

from collections import deque
from dataclasses import dataclass


@dataclass(frozen=True)
class Shape:
    rooms: int
    #: The route from the Zone entrance to the Zone exit.
    spine: tuple[str, ...]
    #: Rooms with three or more distinct neighbouring rooms.
    junctions: tuple[str, ...]
    #: Degree-1 rooms that are not the Zone's own entrance or exit.
    side_dead_ends: tuple[str, ...]
    #: One entry per connected group of off-spine rooms: the rooms in it,
    #: and how many rooms deep it runs from the spine.
    side_paths: tuple[tuple[str, ...], ...]
    side_depths: tuple[int, ...]
    #: Junctions that sit inside a side path rather than on the spine.
    side_junctions: tuple[str, ...]
    locked_branch_edges: tuple[str, ...]
    open_branch_edges: tuple[str, ...]

    @property
    def choices(self) -> int:
        """Distinct side paths: how many times the Zone offers a turn."""
        return len(self.side_paths)


def _adjacency(zone) -> dict[str, set[str]]:
    adj: dict[str, set[str]] = {c.id: set() for c in zone.chambers}
    for e in zone.edges:
        if e.realization != "JOINED":
            continue
        adj[e.room_a].add(e.room_b)
        adj[e.room_b].add(e.room_a)
    return adj


def _route(adj, start: str, goal: str) -> tuple[str, ...]:
    prev, seen, q = {}, {start}, deque([start])
    while q:
        at = q.popleft()
        if at == goal:
            out = [at]
            while out[-1] != start:
                out.append(prev[out[-1]])
            return tuple(reversed(out))
        for nxt in sorted(adj[at]):
            if nxt not in seen:
                seen.add(nxt)
                prev[nxt] = at
                q.append(nxt)
    return ()


def shape_of(zone) -> Shape:
    adj = _adjacency(zone)
    entrance, exit_ = zone.chambers[0].id, zone.chambers[-1].id
    spine = _route(adj, entrance, exit_)
    on_spine = set(spine)

    off = [r for r in sorted(adj) if r not in on_spine]
    # A SIDE PATH is one connected group of off-spine rooms. Two rooms
    # reached through the same turning are one side path however many
    # rooms they are; two turnings are two, however few.
    groups, placed = [], set()
    for room in off:
        if room in placed:
            continue
        group, q = [], deque([room])
        placed.add(room)
        while q:
            at = q.popleft()
            group.append(at)
            for nxt in sorted(adj[at]):
                if nxt not in on_spine and nxt not in placed:
                    placed.add(nxt)
                    q.append(nxt)
        groups.append(tuple(sorted(group)))

    # DEPTH: hops from the spine, counted in rooms, so a single side
    # room is 1 and a room behind it is 2.
    depth = {r: 1 for r in off if adj[r] & on_spine}
    q = deque(depth.items())
    while q:
        at, d = q.popleft()
        for nxt in sorted(adj[at]):
            if nxt not in on_spine and nxt not in depth:
                depth[nxt] = d + 1
                q.append((nxt, d + 1))

    locked_by_edge = {d.edge_id: d.usage for c in zone.chambers
                      for d in c.doors if d.edge_id and d.usage == "LOCKED"}
    locked, open_ = [], []
    for e in zone.edges:
        if e.realization != "JOINED":
            continue
        if e.room_a in on_spine and e.room_b in on_spine:
            continue
        (locked if e.edge_id in locked_by_edge else open_).append(e.edge_id)

    return Shape(
        rooms=len(zone.chambers),
        spine=spine,
        junctions=tuple(sorted(r for r in adj if len(adj[r]) >= 3)),
        side_dead_ends=tuple(sorted(
            r for r in adj
            if len(adj[r]) == 1 and r not in (entrance, exit_))),
        side_paths=tuple(groups),
        side_depths=tuple(max((depth.get(r, 0) for r in g), default=0)
                          for g in groups),
        side_junctions=tuple(sorted(
            r for r in off if len(adj[r]) >= 3)),
        locked_branch_edges=tuple(sorted(locked)),
        open_branch_edges=tuple(sorted(open_)))
