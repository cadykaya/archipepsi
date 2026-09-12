"""Validating what the engine placed, and committing it once.

`09_ROOM_CONTRACT.md` §5.2 and §6. The engine solves placement — it owns
world coordinates and it is the only physical-placement implementation.
This module **checks arithmetic and identity on the evidence it returns**
and never runs a shape query. Re-deriving a capsule result in Python
would be a second derivation of a fact the engine owns.

**Missing evidence is not passing evidence.** An earlier version of this
module skipped every check whose input was absent, so a layout with no
aperture measurements, no bounds and no arrival verdicts was ACCEPTED and
got a digest. That is the defect this repository keeps cataloguing — a
correct measurement that is never handed the case that fails it — built
here deliberately enough to have a comment explaining it. A graph Zone
now has to arrive with complete, well-typed evidence or it is refused.

**Validate, then commit.** Only a layout that passes becomes the accepted
immutable manifest; a failing proposal is refused and never acquires a
digest.
"""

from __future__ import annotations

import hashlib
import json
import math
from dataclasses import dataclass, field

#: Two things meet when they are this close. Metres, and radians.
EPSILON_JOIN = 0.001


@dataclass(frozen=True)
class Verdict:
    """What the bridge decided about a proposed layout."""

    status: str
    errors: tuple[str, ...] = ()
    manifest: dict | None = None
    #: Set when the engine reported a non-OK status; carried verbatim so
    #: a timeout stays a timeout all the way to whoever reads the log.
    engine: dict | None = None
    #: True when the Zone declares no graph. Such a Zone is the chain its
    #: list order describes; it is not certified here and gets no
    #: manifest, because "we did not check" and "we checked and it
    #: passed" must never produce the same artefact.
    legacy: bool = False

    @property
    def accepted(self) -> bool:
        return self.status == "ACCEPTED"


class _Bad(Exception):
    """Malformed evidence. Carries the sentence that says what."""


def _finite(x, what: str) -> float:
    # WELL-TYPED, not merely parseable. A JSON number arrives as int or
    # float; a string that happens to parse is evidence that something
    # upstream stringified a coordinate, and letting it through hides
    # that rather than fixing it.
    if isinstance(x, bool) or not isinstance(x, (int, float)):
        raise _Bad(f"{what} is {x!r}, not a number")
    try:
        v = float(x)
    except (TypeError, ValueError):
        raise _Bad(f"{what} is not a number")
    if not math.isfinite(v):
        raise _Bad(f"{what} is {x!r}, which is not a finite coordinate")
    return v


def _vec(raw, what: str) -> tuple[float, float, float]:
    if isinstance(raw, dict):
        got = [raw.get(k) for k in ("x", "y", "z")]
        if any(v is None for v in got):
            raise _Bad(f"{what} is missing a component")
    else:
        try:
            got = list(raw)
        except TypeError:
            raise _Bad(f"{what} is not a point")
        if len(got) != 3:
            raise _Bad(f"{what} has {len(got)} components, not 3")
    return tuple(_finite(v, f"{what}") for v in got)


def _aabb(raw, what: str) -> tuple[tuple[float, ...], tuple[float, ...]]:
    if not isinstance(raw, dict) or "position" not in raw \
            or "size" not in raw:
        raise _Bad(f"{what} is not a box with a position and a size")
    lo = _vec(raw["position"], f"{what} position")
    size = _vec(raw["size"], f"{what} size")
    if any(s < 0.0 for s in size):
        raise _Bad(f"{what} has a negative extent")
    return lo, tuple(lo[i] + size[i] for i in range(3))


def _overlaps(a, b, slack: float = EPSILON_JOIN) -> bool:
    (alo, ahi), (blo, bhi) = a, b
    return all(alo[i] < bhi[i] - slack and blo[i] < ahi[i] - slack
               for i in range(3))


def _apart(a: tuple, b: tuple) -> float:
    return max(abs(x - y) for x, y in zip(a, b))


@dataclass
class _Check:
    """One validation pass, collecting sentences rather than raising."""

    errors: list[str] = field(default_factory=list)

    def fail(self, msg: str) -> None:
        self.errors.append(msg)

    def read(self, fn, *args):
        """Run a parse, turning malformed evidence into one sentence."""
        try:
            return fn(*args)
        except _Bad as bad:
            self.errors.append(str(bad))
            return None


#: The room the ENGINE appends after the last chamber, and the two key
#: prefixes under which it files approaches nothing declared.
#:
#: **Why the validator has to know these.** `zone_builder` appends an
#: exit room with a portal in it. No composer declares it: it has no
#: chamber, no `TopologyEdge` and no `DoorAssignment`, and it is still
#: real geometry a player walks through and a room the placement search
#: had to fit. A manifest that omitted it could rebuild the whole Zone
#: and then have to re-solve the last leg, which is the one thing Law 47c
#: says a replay never does.
#:
#: The same is true of the first room on the spine: nothing joins INTO
#: it, so no edge names the corridor that reaches it, and `r:<room_id>`
#: is where that corridor is filed.
#:
#: **Reserved, and checked as reserved.** These are allowed by name and
#: nothing else is: an unknown room or an unexplained join is still a
#: refusal, and `zone_builder` refuses a Zone that declares a chamber or
#: an edge using them, so the two lanes cannot both claim one.
ENGINE_EXIT_ROOM = "exit"
ENGINE_EXIT_EDGE = "e:__exit__"
ENGINE_ROOM_EDGE = "r:"



def _check_reserved_join(c: "_Check", eid: str, raw, boxes: dict) -> None:
    """The engine's own joins: the exit approach and `r:<room>`.

    **Reserved was buying a pass on everything.** These were skipped
    past the walk, so an exit approach whose corridor ended ten
    kilometres from the room was ACCEPTED — and the manifest replays
    exactly this, so a Zone would be rebuilt around a corridor reaching
    nowhere. That is the playtest's "the connecter isnt connected at
    all", one room further along.

    **What is checked here is deliberately less than for a JOINED
    edge, and the difference is not laziness.** A JOINED edge's
    `socket_a` and `socket_b` are two DOORWAYS, so the walk may demand
    they abut. A reserved join's endpoints are not doorways:
    `zone_builder` files `r:<room>` from the room's own `position` to
    its `arrival`, and the exit approach ends at the exit room's
    `position` — points several metres from any wall by construction.
    Demanding abutment there would refuse every real Zone, which is the
    other way to get a check wrong.

    So: the pieces are pieces, and the chain is continuous THROUGH
    ITSELF. Whether a reserved join's endpoints should abut a socket is
    a question for the engine lane, and is recorded as open in
    `AMALGAM_BRIDGE.md` §5.4 rather than guessed at here.
    """
    if not isinstance(raw, dict):
        c.fail(f"reserved join '{eid}' is not a join")
        return
    chain = raw.get("chain")
    if chain is None:
        c.fail(f"reserved join '{eid}' reports no chain; the engine "
               "files every approach it built, and a manifest missing "
               "one re-solves that leg on re-entry")
        return
    if not isinstance(chain, list):
        c.fail(f"reserved join '{eid}' chain is not a list of pieces")
        return
    cursor, where = None, None
    for n, piece in enumerate(chain):
        if not isinstance(piece, dict):
            c.fail(f"reserved join '{eid}' piece {n} is not a piece")
            return
        pe = c.read(_vec, piece.get("entry"), f"join '{eid}' piece {n} entry")
        px = c.read(_vec, piece.get("exit"), f"join '{eid}' piece {n} exit")
        if pe is None or px is None:
            return
        if cursor is not None:
            gap = _apart(cursor, pe)
            if gap > EPSILON_JOIN:
                c.fail(f"reserved join '{eid}' is broken between {where} "
                       f"and piece {n}: {gap:.3f} m apart")
                return
        cursor, where = px, f"piece {n}"
    # AND A ROOM IT NAMES IS A ROOM THAT WAS PLACED. An approach to a
    # room with no transform cannot be replayed at all.
    # `r:<room>` files `room_a` as the empty string on purpose — nothing
    # is on the far side of the first room's approach — so an empty name
    # is not a missing one.
    for rid in (raw.get("room_a"), raw.get("room_b")):
        if isinstance(rid, str) and rid and rid not in boxes:
            c.fail(f"reserved join '{eid}' approaches room '{rid}', "
                   "which the layout does not place")

def validate(zone, result: dict) -> Verdict:
    """Check a proposed layout against the Zone that asked for it.

    **An engine failure is passed through, not reinterpreted**: a
    `LAYOUT_TIMEOUT` stays a timeout, because saying "no layout exists"
    when the clock ran out lets a slow machine indict a sound design.
    """
    status = str(result.get("status", ""))
    if status != "LAYOUT_OK":
        if status in ("LAYOUT_TIMEOUT", "LAYOUT_INFEASIBLE",
                      "LAYOUT_REFUSED"):
            return Verdict(status=status, engine=result)
        return Verdict(status="LAYOUT_REFUSED",
                       errors=(f"unknown layout status '{status}'",),
                       engine=result)

    # A Zone with no graph is the chain its list order describes. It is
    # not certified here: the evidence below is about edges, and there
    # are none to be evidence about. Returning `legacy` rather than
    # ACCEPTED keeps an old save loading without letting it masquerade as
    # a newly certified layout.
    if not zone.edges:
        return Verdict(status="LEGACY_UNCERTIFIED", legacy=True,
                       engine=result)

    c = _Check()
    rooms = result.get("rooms") or {}
    joins = result.get("joins") or {}
    arrival_ok = result.get("arrival_ok") or {}
    apertures = result.get("apertures") or {}
    anchors = result.get("anchors") or {}

    declared = [ch.id for ch in zone.chambers]
    boxes: dict[str, tuple] = {}
    positions: dict[str, tuple] = {}

    # --- 1. every room placed, with finite numbers and a real box ------
    # THE ENGINE'S EXIT ROOM IS PARSED LIKE ANY OTHER, when it is there.
    #
    # Being reserved bought it a pass on everything: its transform was
    # never read, so it never entered `boxes`, so the overlap check could
    # not see it and neither could 1b. An exit room with no bounds at
    # all, and one sitting inside `c001`, were both ACCEPTED. It is real
    # geometry with a portal in it and a player walks through it —
    # "allowed by name" was never meant to mean "unchecked".
    #
    # Optional and not required: only a Zone the engine actually built
    # carries one, and `test_a_zone_with_no_graph_is_not_certified_here`
    # and every fixture predating the seam do not.
    inspect = list(declared)
    if isinstance(rooms.get(ENGINE_EXIT_ROOM), dict):
        inspect.append(ENGINE_EXIT_ROOM)
    for rid in inspect:
        entry = rooms.get(rid)
        if not isinstance(entry, dict):
            c.fail(f"room '{rid}' has no placement in the layout")
            continue
        pos = c.read(_vec, entry.get("position"), f"room '{rid}' position")
        if pos is not None:
            positions[rid] = pos
        if "yaw" not in entry:
            c.fail(f"room '{rid}' reports no yaw")
        else:
            c.read(_finite, entry["yaw"], f"room '{rid}' yaw")
        if "bounds" not in entry:
            c.fail(f"room '{rid}' reports no bounds; body overlap cannot "
                   "be checked without them")
        else:
            box = c.read(_aabb, entry["bounds"], f"room '{rid}' bounds")
            if box is not None:
                boxes[rid] = box
    for rid in rooms:
        if rid not in declared and rid != ENGINE_EXIT_ROOM:
            c.fail(f"the layout places unknown room '{rid}'")

    # --- 1b. a room's position, bounds and sockets describe ONE room ---
    #
    # Three pieces of evidence about the same object can drift apart, and
    # a layout where they have is not a layout. Moving a room without
    # moving its doorway is the case: the rooms still do not overlap and
    # every chain is still continuous, because none of those checks reads
    # the room's position at all.
    for rid, box in boxes.items():
        pos = positions.get(rid)
        if pos is None:
            continue
        lo, hi = box
        if any(pos[i] < lo[i] - EPSILON_JOIN
               or pos[i] > hi[i] + EPSILON_JOIN for i in range(3)):
            c.fail(f"room '{rid}' reports a position outside its own "
                   "bounds; the two describe different rooms")

    # --- 2. bodies do not interpenetrate -------------------------------
    ids = sorted(boxes)
    for i, a in enumerate(ids):
        for b in ids[i + 1:]:
            if _overlaps(boxes[a], boxes[b]):
                c.fail(f"rooms '{a}' and '{b}' overlap")

    # --- 3. every JOINED edge has a verified route ---------------------
    #
    # ABSOLUTE TRANSFORMS DO NOT PROVE A CONNECTED JOIN. One location per
    # room makes cycle CLOSURE free — there is no second opinion to
    # disagree with — and says nothing about whether the two assigned
    # sockets are actually connected. An earlier version checked that
    # each supplied piece had a position and called that continuity,
    # which accepted rooms 40 m apart joined by an empty chain.
    joined = [e for e in zone.edges if e.realization == "JOINED"]
    for e in joined:
        j = joins.get(e.edge_id)
        if not isinstance(j, dict):
            c.fail(f"JOINED edge '{e.edge_id}' has no join evidence; the "
                   "route between its two assigned sockets is unverified")
            continue
        a = c.read(_vec, j.get("socket_a"),
                   f"edge '{e.edge_id}' socket_a")
        b = c.read(_vec, j.get("socket_b"),
                   f"edge '{e.edge_id}' socket_b")
        if a is None or b is None:
            continue
        chain = j.get("chain")
        if chain is None:
            c.fail(f"edge '{e.edge_id}' reports no chain; a direct "
                   "abutment is an empty chain, never a missing one")
            continue
        if not isinstance(chain, list):
            c.fail(f"edge '{e.edge_id}' chain is not a list of pieces")
            continue
        # Walk it: socket_a -> piece.entry, piece.exit -> next.entry,
        # last.exit -> socket_b. An empty chain means the two sockets
        # meet each other directly, which is the special case.
        cursor, where = a, "socket_a"
        broken = False
        for n, raw in enumerate(chain):
            if not isinstance(raw, dict):
                c.fail(f"edge '{e.edge_id}' piece {n} is not a piece")
                broken = True
                break
            pe = c.read(_vec, raw.get("entry"),
                        f"edge '{e.edge_id}' piece {n} entry")
            px = c.read(_vec, raw.get("exit"),
                        f"edge '{e.edge_id}' piece {n} exit")
            if pe is None or px is None:
                broken = True
                break
            gap = _apart(cursor, pe)
            if gap > EPSILON_JOIN:
                c.fail(f"edge '{e.edge_id}' is broken between {where} and "
                       f"piece {n}: {gap:.3f} m apart")
                broken = True
                break
            cursor, where = px, f"piece {n}"
        if broken:
            continue
        gap = _apart(cursor, b)
        if gap > EPSILON_JOIN:
            c.fail(f"edge '{e.edge_id}' is broken between {where} and "
                   f"socket_b: {gap:.3f} m apart")
        # AND THE SOCKETS BELONG TO THE ROOMS THEY CLAIM. A doorway sits
        # on its room's surface; a socket floating away from the body it
        # is cut into means the chain was verified against a room that
        # is no longer there.
        for point, rid, side in ((a, e.room_a, "socket_a"),
                                 (b, e.room_b, "socket_b")):
            box = boxes.get(rid)
            if box is None:
                continue
            lo, hi = box
            if any(point[i] < lo[i] - EPSILON_JOIN
                   or point[i] > hi[i] + EPSILON_JOIN for i in range(3)):
                c.fail(f"edge '{e.edge_id}' {side} does not lie on room "
                       f"'{rid}'; the route and the room disagree about "
                       "where the doorway is")
    placeable = set(declared) | {ENGINE_EXIT_ROOM}
    for eid in joins:
        if eid in {e.edge_id for e in joined}:
            continue
        reserved = (eid == ENGINE_EXIT_EDGE
                    or (eid.startswith(ENGINE_ROOM_EDGE)
                        and eid[len(ENGINE_ROOM_EDGE):] in placeable))
        if not reserved:
            c.fail(f"the layout reports a join for '{eid}', which is not "
                   "a JOINED edge of this Zone")
            continue
        _check_reserved_join(c, eid, joins[eid], boxes)

    # --- 4. arrival is a MEASURED VERDICT, never a coordinate ----------
    #
    # A point is where a body would arrive. Whether a standing capsule
    # fits there is a physics query, and the engine is the only thing
    # that may answer it. Accepting the presence of a coordinate as the
    # answer is how an unreachable arrival passes.
    need_arrival: set[str] = set()
    for pl in zone.plugs:
        need_arrival.add(pl.source_anchor)
        need_arrival.add(pl.destination)
    for ch in zone.chambers:
        if any(d.usage != "SEALED" for d in ch.doors):
            need_arrival.add(f"room:{ch.id}:arrival")
    for anchor in sorted(need_arrival):
        if anchor not in anchors:
            c.fail(f"anchor '{anchor}' was not resolved by the engine")
        verdict = arrival_ok.get(anchor)
        if verdict is None:
            c.fail(f"anchor '{anchor}' carries no measured arrival "
                   "verdict; a coordinate is not evidence a body fits")
        elif not isinstance(verdict, bool):
            c.fail(f"anchor '{anchor}' arrival verdict is "
                   f"{verdict!r}, not a boolean")
        elif verdict is False:
            c.fail(f"the engine reports a standing capsule does not fit "
                   f"at '{anchor}'")

    # --- 5. aperture polarity, for every declared door -----------------
    #
    # THE FIRST ROOM'S `entry` IS THE ZONE'S FRONT DOOR. Nothing joins
    # into the head of the spine, so no `TopologyEdge` names its entry
    # and `_seal_the_rest` seals it by omission -- and the player walks
    # in through it from the Zone start, so the engine carves it and
    # measures it as the hole it is. Sealing the way in would seal the
    # player out of their own Zone.
    #
    # Named rather than tolerated: exactly the entry of exactly the room
    # with no inbound JOINED edge, and every other SEALED door is still
    # held to being solid.
    # Which room is the head is read off the DOOR ASSIGNMENTS, not the
    # edge directions: every spine edge is BIDIRECTIONAL, so direction
    # cannot say which end you arrive from. A room is entered from an
    # edge exactly when it assigns that edge to its `entry` socket, and
    # the head assigns none.
    entered = {ch.id for ch in zone.chambers
               if any(d.socket_id == "entry" and d.edge_id
                      for d in ch.doors)}
    head = next((ch.id for ch in zone.chambers
                 if ch.id not in entered), None)
    for ch in zone.chambers:
        for d in ch.doors:
            ref = f"{ch.id}/{d.socket_id}"
            expected = d.passable_geometry
            if ch.id == head and d.socket_id == "entry":
                expected = True
            measured = apertures.get(ref)
            if measured is None:
                c.fail(f"door '{ref}' is {d.usage} and carries no "
                       "measurement; the inverted probe cannot be "
                       "skipped for a door the layout never reports")
            elif not isinstance(measured, bool):
                c.fail(f"door '{ref}' measurement is {measured!r}, "
                       "not a boolean")
            elif measured != expected:
                if ch.id == head and d.socket_id == "entry":
                    c.fail(
                        f"door '{ref}' is the Zone's front door and the "
                        "engine measured it as solid; the player arrives "
                        "through it")
                else:
                    c.fail(
                        f"door '{ref}' is {d.usage} and the engine "
                        "measured it "
                        + ("as a hole" if measured else "as solid")
                        + "; the declaration and the geometry disagree")

    # --- 6. one chain per room, which is what makes room-keyed data
    # sound. It stops being sound the moment a room has two inbound
    # JOINED edges, so it is asserted rather than assumed.
    inbound: dict[str, int] = {}
    for e in joined:
        inbound[e.room_b] = inbound.get(e.room_b, 0) + 1
    doubled = sorted(r for r, n in inbound.items() if n > 1)
    if doubled:
        c.fail("room(s) " + str(doubled) + " have two inbound JOINED "
               "edges, so room-keyed evidence is ambiguous; the engine "
               "must key by edge_id before this Zone can be committed")

    if c.errors:
        return Verdict(status="LAYOUT_REFUSED", errors=tuple(c.errors),
                       engine=result)
    return Verdict(status="ACCEPTED",
                   manifest=_manifest(zone, result, positions))


def _manifest(zone, result: dict, positions: dict) -> dict:
    """The committed layout, and the digest that pins it.

    Solved once and replayed forever: every later load uses these
    transforms and these chains and never re-runs the search. That is
    Law 47c — byte-identical from the manifest — obtained without
    claiming two machines would independently rediscover the same layout.
    """
    body = {
        "zone_id": zone.zone_id,
        "rooms": result.get("rooms") or {},
        "joins": result.get("joins") or {},
        "anchors": result.get("anchors") or {},
        "stations": sorted(result.get("stations") or []),
        "edges": [e.model_dump() for e in zone.edges],
        "plugs": [p.model_dump() for p in zone.plugs],
    }
    blob = json.dumps(body, sort_keys=True, separators=(",", ":"),
                      default=str)
    body["manifest_digest"] = hashlib.sha256(
        blob.encode("utf-8")).hexdigest()[:16]
    return body


# There is no separate `commit`. `validate` builds the manifest ONLY on
# the accepted path, so a failing proposal has no digest for anything to
# store — the atomicity is in the fact that no other function can produce
# one. A `commit` that took a verdict and trusted it would be a second
# place to get the order wrong.
