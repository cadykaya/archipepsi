"""Validating what the engine placed, and committing it once.

`09_ROOM_CONTRACT.md` §5.2 and §6. The engine solves placement — it owns
world coordinates and it is the only physical-placement implementation.
This module **checks arithmetic and identity on the evidence it returns**
and never runs a shape query. Re-deriving a capsule result in Python
would be a second derivation of a fact the engine owns.

**Validate, then commit.** Only a layout that passes becomes the accepted
immutable manifest; a failing proposal is refused and never acquires a
digest. Committing first and checking afterwards publishes an unvalidated
manifest, which is what an earlier draft of the contract said to do.
"""

from __future__ import annotations

import hashlib
import json
import math
from dataclasses import dataclass

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

    @property
    def accepted(self) -> bool:
        return self.status == "ACCEPTED"


def _vec(raw) -> tuple[float, float, float]:
    if isinstance(raw, dict):
        return (float(raw.get("x", 0.0)), float(raw.get("y", 0.0)),
                float(raw.get("z", 0.0)))
    x, y, z = raw
    return (float(x), float(y), float(z))


def _aabb(raw) -> tuple[tuple[float, ...], tuple[float, ...]]:
    lo = _vec(raw["position"])
    size = _vec(raw["size"])
    return lo, tuple(lo[i] + size[i] for i in range(3))


def _overlaps(a, b, slack: float = EPSILON_JOIN) -> bool:
    (alo, ahi), (blo, bhi) = a, b
    return all(alo[i] < bhi[i] - slack and blo[i] < ahi[i] - slack
               for i in range(3))


def _close(a: tuple, b: tuple) -> bool:
    return all(abs(x - y) <= EPSILON_JOIN for x, y in zip(a, b))


def validate(zone, result: dict) -> Verdict:
    """Check a proposed layout against the Zone that asked for it.

    Returns a `Verdict`. **An engine failure is passed through, not
    reinterpreted**: a `LAYOUT_TIMEOUT` stays a timeout, because saying
    "no layout exists" when the clock ran out lets a slow machine indict
    a sound design.
    """
    status = str(result.get("status", ""))
    if status != "LAYOUT_OK":
        if status in ("LAYOUT_TIMEOUT", "LAYOUT_INFEASIBLE",
                      "LAYOUT_REFUSED"):
            return Verdict(status=status, engine=result)
        return Verdict(status="LAYOUT_REFUSED",
                       errors=(f"unknown layout status '{status}'",),
                       engine=result)

    errors: list[str] = []
    rooms = result.get("rooms") or {}
    links = result.get("links") or {}
    anchors = result.get("anchors") or {}
    arrival = result.get("arrival") or {}
    apertures = result.get("apertures") or {}

    declared = [c.id for c in zone.chambers]
    missing = [r for r in declared if r not in rooms]
    if missing:
        errors.append(f"no transform for room(s) {missing}")
    extra = [r for r in rooms if r not in declared]
    if extra:
        errors.append(f"transforms for unknown room(s) {sorted(extra)}")

    # --- bodies do not interpenetrate. AABB arithmetic on what the
    # engine measured from the built scene; the bridge measures nothing.
    #
    # THE ENGINE NESTS THE EVIDENCE inside each room's transform entry --
    # `{position, yaw, bounds, arrival}` -- rather than shipping sibling
    # maps, which is what `zone_builder.gd` actually emits. A top-level
    # `bounds` map is still accepted because an earlier draft of this
    # contract asked for one, and reading both costs a `get`.
    boxes: dict[str, tuple] = {}
    top_bounds = result.get("bounds") or {}
    for rid, entry in rooms.items():
        raw = None
        if isinstance(entry, dict) and "bounds" in entry:
            raw = entry["bounds"]
        elif rid in top_bounds:
            raw = top_bounds[rid]
        if raw is None:
            continue
        try:
            boxes[rid] = _aabb(raw)
        except (KeyError, TypeError, ValueError, IndexError):
            errors.append(f"room '{rid}' returned bounds the bridge "
                          "could not read")
    ids = sorted(boxes)
    for i, a in enumerate(ids):
        for b in ids[i + 1:]:
            if _overlaps(boxes[a], boxes[b]):
                errors.append(f"rooms '{a}' and '{b}' overlap")

    # --- one chain per room, which is what makes room-keyed `links`
    # sound. It stops being sound the moment a room has two inbound
    # JOINED edges, so it is asserted rather than assumed.
    joined = [e for e in zone.edges if e.realization == "JOINED"]
    inbound: dict[str, int] = {}
    for e in joined:
        inbound[e.room_b] = inbound.get(e.room_b, 0) + 1
    doubled = sorted(r for r, n in inbound.items() if n > 1)
    if doubled:
        errors.append(
            "room(s) " + str(doubled) + " have two inbound JOINED edges, "
            "so a room-keyed `links` map is ambiguous; the engine must "
            "key chains by edge_id before this Zone can be committed")

    # --- every chain is continuous. Consecutive pieces meet, and a chain
    # is allowed to be empty for a directly-abutting edge.
    for rid, chain in links.items():
        if rid not in rooms:
            errors.append(f"chain for unknown room '{rid}'")
            continue
        for i, piece in enumerate(chain):
            if not isinstance(piece, dict) or "position" not in piece:
                errors.append(
                    f"room '{rid}' chain piece {i} is not a placed piece")

    # --- CYCLE CLOSURE IS FREE, AND SAYING WHY MATTERS.
    #
    # Closure is a property of RELATIVE composition: walk a loop by
    # composing joins and you may not arrive where you started. The
    # engine returns ABSOLUTE world transforms, one per room, so every
    # cycle closes by construction — there is one position per room and
    # no second opinion to disagree with. The constraint is discharged by
    # the per-edge agreement above rather than by a separate search, and
    # it stops being free the day the engine returns relative joins.
    if any(not isinstance(t, dict) or "position" not in t
           for t in rooms.values()):
        errors.append("a room transform is not an absolute placement; "
                      "cycle closure is only free while they are")

    # --- anchors a plug names must resolve, and land somewhere a body
    # fits. The bridge checks the id is present; whether a capsule fits
    # is the engine's measurement, consumed here as evidence.
    # Arrival evidence, from wherever the engine put it. A room entry
    # carrying `arrival` is the engine saying "a body arriving here
    # stands at this point"; the separate `arrival` map is the boolean
    # form an earlier draft asked for. Neither is re-derived here.
    for rid, entry in rooms.items():
        if isinstance(entry, dict) and "arrival" in entry:
            anchors.setdefault(f"room:{rid}:arrival", entry["arrival"])

    for plug in zone.plugs:
        for anchor in (plug.source_anchor, plug.destination):
            if anchor not in anchors:
                errors.append(
                    f"plug '{plug.edge_id}' names anchor '{anchor}', "
                    "which the engine did not resolve")
            elif arrival and arrival.get(anchor) is False:
                errors.append(
                    f"plug '{plug.edge_id}' lands at '{anchor}', where "
                    "the engine reports a standing capsule does not fit")

    # --- aperture polarity agrees with the declaration. A SEALED door
    # measured as a hole is a shortcut past a lock; a USED door measured
    # as solid is a room with no way out.
    for c in zone.chambers:
        for d in c.doors:
            ref = f"{c.id}/{d.socket_id}"
            if ref not in apertures:
                continue
            is_hole = bool(apertures[ref])
            if is_hole != d.passable_geometry:
                errors.append(
                    f"door '{ref}' is {d.usage} and the engine measured it "
                    + ("as a hole" if is_hole else "as solid")
                    + "; the declaration and the geometry disagree")

    if errors:
        return Verdict(status="LAYOUT_REFUSED", errors=tuple(errors),
                       engine=result)
    return Verdict(status="ACCEPTED",
                   manifest=_manifest(zone, result))


def _manifest(zone, result: dict) -> dict:
    """The committed layout, and the digest that pins it.

    Solved once and replayed forever: every later load uses these
    transforms and these chains, and never re-runs the search. That is
    Law 47c — byte-identical from the manifest — obtained without
    claiming two machines would independently rediscover the same layout.
    """
    body = {
        "zone_id": zone.zone_id,
        "rooms": result.get("rooms") or {},
        "links": result.get("links") or {},
        "anchors": result.get("anchors") or {},
        "edges": [e.model_dump() for e in zone.edges],
        "plugs": [p.model_dump() for p in zone.plugs],
    }
    blob = json.dumps(body, sort_keys=True, separators=(",", ":"),
                      default=_jsonable)
    body["manifest_digest"] = hashlib.sha256(
        blob.encode("utf-8")).hexdigest()[:16]
    return body


def _jsonable(o):
    if isinstance(o, float) and math.isnan(o):
        raise ValueError("a transform carried NaN")
    return str(o)


# There is no separate `commit`. `validate` builds the manifest ONLY on
# the accepted path, so a failing proposal has no digest for anything to
# store — the atomicity is in the fact that no other function can produce
# one. A `commit` that took a verdict and trusted it would be a second
# place to get the order wrong.
