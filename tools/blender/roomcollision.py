"""Derive a room shell's collision from the primitives that built it.

    tools/blender/roomcollision.py

Production integrated the eight shells at `eda4fd9` and measured them
NOT MEASURABLE: 625 findings across the eight, every one of the "nothing
is there" class, from one cause -- the imported shells carried no
collision at all. One MeshInstance3D, zero CollisionObject3D, zero
CollisionShape3D. A probe fired at a room with no colliders reports
nothing, and RoomAudit refuses to dress that up as a pass.

`docs/ART_ASSET_SPEC.md` section 3 is the standing rule and it is not new:
author collision, never auto-trimesh anything a player touches, walkable
surfaces get convex or box shapes, and the `-col` / `-convcol` / `-colonly`
name suffixes are the least error-prone route. This module is that rule
applied to room shells, in the one place where a ninth shell inherits it.

WHY THIS IS A DERIVATION AND NOT EIGHT HAND-BUILT COLLIDERS
-----------------------------------------------------------
Every piece of all eight shells is a `brushkit.block` -- an axis-aligned
or Z-rotated box with a known centre and size. Verified: the two shell
builders call no other brushkit primitive. So the collider for a piece is
a COPY OF THAT PIECE. Not an approximation of it, not a box fitted round
it: the same eight vertices, whose convex hull is therefore the piece
exactly. "Collision is simpler than the visual mesh, and never larger
than it" holds by construction rather than by tolerance.

WHAT DECIDES WHETHER A PIECE COLLIDES
-------------------------------------
`materials.paint` knows exactly four roles, and every part of every shell
is already painted with one of them. That choice is the author's own
statement about what a piece IS, made when the piece was placed:

    floor    walk on it        collides
    wall     stop at it        collides
    ceiling  do not pass it    collides
    trim     look at it        does NOT collide

Nothing new has to be declared per shell, and the rule cannot drift from
the geometry because it reads the same argument that chose the texture.

Skipping `trim` is not laziness, it is the spec's "never larger than the
visual mesh" clause doing work. The platform noses (`_pn_*`) are 0.14 m
wider than the slab they skirt and sit UNDER its top face; the deck nose
is the same, one lip below the deck. Colliding them would make every
platform 0.14 m wider than the `Surface` the manifest declares, which is
the exact failure mode S18 forbids -- a visual that changes a
reachability. The chamfers, skirtings, reveals, bands and capitals are
the same story at the walls.

WHICH SUFFIX, AND WHY THAT ONE
------------------------------
`-convcolonly`. Verified empirically against this repo's own Godot
(`.tools/godot`, 4.5.1) rather than from memory, by importing a probe
.glb carrying all four suffixes:

    -convcolonly -> StaticBody3D + CollisionShape3D(ConvexPolygonShape3D)
    -colonly     -> StaticBody3D + CollisionShape3D(ConcavePolygonShape3D)
    -col         -> MeshInstance3D + StaticBody3D + Concave...
    -convcol     -> MeshInstance3D + StaticBody3D + Convex...

Convex, because the spec allows trimesh only for decorative geometry the
player cannot stand on, and these are floors. `only`, for two reasons:
the collider must not render (the approved appearance of eight
owner-reviewed rooms may not change), and `-convcolonly` leaves NO
MeshInstance3D behind -- which matters, because `RoomAudit`'s envelope
check reads `ShellValidator.mesh_boxes`, i.e. MeshInstance3D nodes. A
collider that imported as a mesh would enter the envelope arithmetic and
could refuse a room for geometry nobody can see.

WHAT THIS IS NOT
----------------
It is not a verdict. `room_audit.gd` fires real probes at the
instantiated scene and remains the only physical authority on whether a
shell is walkable. This module makes the room MEASURABLE; Godot measures
it.
"""
from __future__ import annotations

import bpy

import roomcontract

#: The three roles that are structure, and the one that is decoration.
#: `materials.paint` raises on anything else, so this set is total.
SOLID_ROLES = frozenset({"floor", "wall", "ceiling"})
DECORATIVE_ROLES = frozenset({"trim"})
ROLES = SOLID_ROLES | DECORATIVE_ROLES

#: Godot's scene-importer name suffix. Confirmed against `.tools/godot`.
#: The shells' `.glb.import` files carry `nodes/use_name_suffixes=true`,
#: which is what makes it fire.
SUFFIX = "-convcolonly"

#: Where `paint_role` leaves the role. A Blender custom property rather
#: than a parsed material name, so the link is explicit.
ROLE_KEY = "arch_role"

#: `RoomAudit.EDGE_INSET`. A probe never fires at the very lip of a
#: surface, so the support check does not either.
EDGE_INSET = 0.15

#: `RoomAudit.HEIGHT_TOLERANCE`. How far a collider's top face may sit
#: from the height the manifest declares for that surface.
HEIGHT_TOLERANCE = 0.15

#: `RoomAudit.GROUND_REACH`, and the 0.4 m the probe starts above the
#: surface. Together they bound WHICH colliders a downward ray can see,
#: which is the difference between "something is under this point" and
#: "the thing under this point is the thing that was declared".
GROUND_REACH = 1.2
PROBE_LIFT = 0.4

#: Slack for the float32 round-trip through Blender's mesh storage.
#: Three orders of magnitude below `HEIGHT_TOLERANCE`, so it can widen a
#: window by a rounding error and never by anything that matters.
_EPS = 1e-4


def paint_role(obj, role):
    """Record what a part IS, at the moment its material says so."""
    if role not in ROLES:
        raise AssertionError(
            "roomcollision: '%s' is not one of the four painted roles %s. "
            "A new role has to decide whether it is structure or "
            "decoration before it can be built." % (role, sorted(ROLES)))
    obj[ROLE_KEY] = role
    return obj


def role_of(obj):
    role = obj.get(ROLE_KEY)
    if role is None:
        raise AssertionError(
            "roomcollision: '%s' was never painted through `_paint`, so "
            "nothing knows whether the player can stand on it. Every part "
            "of a shell goes through `_paint`." % obj.name)
    return role


def _world_box(obj):
    """(min_xyz, max_xyz) in world metres."""
    corners = [obj.matrix_world @ v.co for v in obj.data.vertices]
    return (
        tuple(min(c[i] for c in corners) for i in range(3)),
        tuple(max(c[i] for c in corners) for i in range(3)),
    )


def build(parts, name):
    """One collision-only twin per structural part. Returns the twins.

    Called BEFORE `common.join`, because the join destroys the individual
    objects and with them the one-box-per-piece structure that keeps each
    convex hull honest. A hull of the joined room would be a solid lump
    with the doorways filled in.
    """
    out = []
    for part in parts:
        if role_of(part) not in SOLID_ROLES:
            continue
        twin = part.copy()
        twin.data = part.data.copy()
        # A collider has no appearance. Dropping the material also keeps
        # the added glTF payload to geometry alone.
        twin.data.materials.clear()
        twin.name = "%s%s" % (part.name, SUFFIX)
        twin.data.name = twin.name
        twin[ROLE_KEY] = role_of(part)
        bpy.context.collection.objects.link(twin)
        out.append(twin)
    if not out:
        raise AssertionError(
            "%s: no structural parts, so the room would import with no "
            "collision -- the exact defect this module exists to fix"
            % name)
    return out


def assert_exact(name, parts, colliders):
    """Every collider is its part, and no part of trim became one.

    The spec's "simpler than the visual mesh, and never larger than it"
    is true by construction here; this refuses the construction quietly
    changing under someone.
    """
    by_name = {p.name: p for p in parts}
    solid = sum(1 for p in parts if role_of(p) in SOLID_ROLES)
    if len(colliders) != solid:
        raise AssertionError(
            "%s: %d structural parts but %d colliders"
            % (name, solid, len(colliders)))
    for twin in colliders:
        if not twin.name.endswith(SUFFIX):
            raise AssertionError(
                "%s: collider '%s' does not carry the import suffix '%s', "
                "so Godot will import it as a visible mesh"
                % (name, twin.name, SUFFIX))
        origin = by_name.get(twin.name[:-len(SUFFIX)])
        if origin is None:
            raise AssertionError(
                "%s: collider '%s' has no visual part behind it; a "
                "collider that is not a copy of something you can see is "
                "invisible collision" % (name, twin.name))
        if role_of(origin) not in SOLID_ROLES:
            raise AssertionError(
                "%s: '%s' is painted '%s' and must not collide"
                % (name, origin.name, role_of(origin)))
        lo_a, hi_a = _world_box(origin)
        lo_b, hi_b = _world_box(twin)
        for i, axis in enumerate("xyz"):
            if abs(lo_a[i] - lo_b[i]) > 1e-6 or abs(hi_a[i] - hi_b[i]) > 1e-6:
                raise AssertionError(
                    "%s: collider '%s' is not its part on %s (%.4f..%.4f "
                    "vs %.4f..%.4f)" % (name, twin.name, axis,
                                        lo_b[i], hi_b[i], lo_a[i], hi_a[i]))
    return len(colliders)


def assert_supports(name, colliders, stones, heights, snames):
    """Every declared `Surface` has real collision under it.

    This is the check that would have caught `eda4fd9`'s 625 findings at
    the source. It walks the same 3 x 3 inset grid `RoomAudit` samples,
    in Blender coordinates, and asks whether SOME collider's top face is
    there. It is an ART-SIDE ARITHMETIC CHECK on boxes this script placed
    -- it does not instantiate anything, it cannot see the importer, and
    it is not a verdict. `RoomAudit` stays the physical authority.
    """
    tops = []
    for c in colliders:
        lo, hi = _world_box(c)
        tops.append((lo[0], hi[0], lo[1], hi[1], hi[2], c.name))
    missing = []
    for stone, z, sname in zip(stones, heights, snames):
        (cx, cy), (ex, ey) = stone
        hx = max(ex / 2.0 - EDGE_INSET, 0.0)
        hy = max(ey / 2.0 - EDGE_INSET, 0.0)
        for u in (-hx, 0.0, hx):
            for v in (-hy, 0.0, hy):
                px, py = cx + u, cy + v
                if not any(x0 - _EPS <= px <= x1 + _EPS
                           and y0 - _EPS <= py <= y1 + _EPS
                           and abs(top - z) <= HEIGHT_TOLERANCE
                           for x0, x1, y0, y1, top, _ in tops):
                    missing.append("%s at (%.2f, %.2f, %.2f)"
                                   % (sname, px, py, z))
    if missing:
        raise AssertionError(
            "%s: %d declared surface sample(s) have no collider top face "
            "under them, so the manifest claims a floor the room does not "
            "have: %s" % (name, len(missing), "; ".join(missing[:6])))
    return len(stones)


def measure_probe(colliders, stones, heights, snames):
    """What a downward ray would actually hit at each declared surface.

    `assert_supports` asks whether SOMETHING is under a sample point.
    This asks whether the thing under it is the thing that was declared,
    which is a different question and the one that catches a surface
    another surface is standing on.

    It mirrors `RoomAudit`'s probe rather than inventing a second one:
    the ray starts `PROBE_LIFT` above the declared height and reaches
    `GROUND_REACH` below it, so only collider top faces inside that
    window are visible to it, and the HIGHEST of them is what it hits. A
    tower's core rises 9 m through the middle of its ground floor and is
    correctly invisible here, because it is invisible to the real probe
    too -- its top face is nowhere near the window.

    Returns a list of findings. It does NOT raise: a surface measuring
    something other than what it declared is a design fact for the owner
    and for Production's audit, not something a build script should
    quietly correct or quietly hide.
    """
    tops = []
    for c in colliders:
        lo, hi = _world_box(c)
        tops.append((lo[0], hi[0], lo[1], hi[1], hi[2]))
    findings = []
    for stone, z, sname in zip(stones, heights, snames):
        (cx, cy), (ex, ey) = stone
        hits = {}
        for u in (0.2, 0.5, 0.8):
            for v in (0.2, 0.5, 0.8):
                px = cx + (u - 0.5) * ex
                py = cy + (v - 0.5) * ey
                # `_EPS` is not cosmetic. Blender stores coordinates as
                # float32, so a face built at exactly 0.80 reads back as
                # 0.80000001 -- just above the ray's start point at
                # `z + PROBE_LIFT`, which silently emptied this window
                # and reported the plinths clean while Godot's own probe
                # was finding all nine samples on them.
                seen = [top for x0, x1, y0, y1, top in tops
                        if x0 - _EPS <= px <= x1 + _EPS
                        and y0 - _EPS <= py <= y1 + _EPS
                        and z - GROUND_REACH - _EPS <= top
                        <= z + PROBE_LIFT + _EPS]
                if not seen:
                    continue
                measured = max(seen)
                if abs(measured - z) <= HEIGHT_TOLERANCE:
                    continue
                # GRAZING: the occluder's top face is level with the
                # point the ray starts from. Whether a real raycast
                # registers that contact is the engine's business and
                # not reproducible by arithmetic -- measured on this
                # project's own Godot, a treasure room's `floor` centre
                # sample grazes the plinth's lower step and does NOT
                # register, while `step_low` against the upper step, the
                # same relationship one tier up, DOES. So it is reported
                # and LABELLED rather than guessed at in either
                # direction. Over-reporting a grazing contact is the
                # safe way to be wrong here; under-reporting is what
                # left eight shells unmeasurable.
                key = (round(measured, 3),
                       measured > z + PROBE_LIFT - _EPS)
                hits[key] = hits.get(key, 0) + 1
        for (measured, grazing), count in sorted(hits.items()):
            finding = {"surface": sname, "declared": round(z, 3),
                       "measured": measured, "samples": count, "of": 9}
            if grazing:
                finding["grazing"] = True
            findings.append(finding)
    return findings


# --- owner ruling C(ii): a Surface is an OFFER --------------------------

#: `RoomAudit.STANCE` -- the box a standing player claims, their capsule
#: squared off -- and `RoomAudit.HEADROOM`, the volume they need above the
#: thing they stand on. Both come through `roomcontract`, which already
#: reads them from `art_budgets.json`, so no second copy of how big a
#: player is can drift from the first.
STANCE_XZ = roomcontract.MIN_SURFACE_SPAN
HEADROOM = roomcontract.HEADROOM

#: `Placement.GRID` and `Placement.LIFT`. Nine per axis, because that is
#: what the composer has always swept and the solver replaced that sweep
#: rather than adding a second one beside it.
GRID = 9
LIFT = 0.02


def _overlaps(a0, a1, b0, b1):
    """Do two intervals share more than a touching face?

    TOUCHING COUNTS AS OVERLAP. Godot's shape query reports a contact for
    exactly coincident faces -- measured, not assumed: the collapsed
    tower's `rubble_1_1` has one candidate whose footprint lands exactly
    in the 0.80 m slot between a floor slab and the deck, touching both,
    and Production's audit counted zero valid placements there. So this
    refuses the same spot rather than being one hair more generous than
    the authority it exists to predict.
    """
    return a0 < b1 + _EPS and a1 > b0 - _EPS


def measure_stances(colliders, stones, heights, snames):
    """Can each declared Surface keep its C(ii) promise?

    Production resolved the Surface contract at `1648fa9`: a `stand`
    Surface does not promise that every point of its rect is clear, only
    that a valid placement can be FOUND somewhere in it. A Surface with
    ZERO valid placements is still invalid.

    This mirrors `Placement.find` over `RoomAudit.player_stands_here` --
    the same 9 x 9 grid, the same rule that the whole 0.8 m footprint
    stays inside the region, the same clearance volume lifted `LIFT` off
    the surface and `HEADROOM` tall -- against the boxes this script
    placed rather than rays into a scene. It is a PREDICTION of the audit
    and never a verdict. What it buys is that a shell which cannot keep
    its promise fails at the BUILD, where the geometry that caused it is
    still a local variable.

    Everything here is Blender-ordered: a box is (x, y, z) with y the
    depth the room runs along and z the height.
    """
    boxes = [(lo[0], hi[0], lo[1], hi[1], lo[2], hi[2])
             for lo, hi in (_world_box(c) for c in colliders)]
    findings = []
    for stone, top_z, sname in zip(stones, heights, snames):
        (cx, cy), (ex, ey) = stone
        if ex < STANCE_XZ - _EPS or ey < STANCE_XZ - _EPS:
            findings.append({"surface": sname, "reason": "too_small",
                             "extent": [round(ex, 3), round(ey, 3)]})
            continue
        span_x = max(ex - STANCE_XZ, 0.0)
        span_y = max(ey - STANCE_XZ, 0.0)
        half = STANCE_XZ / 2.0
        usable = 0
        headroom = 0.0
        for xi in range(GRID):
            u = 0.5 if GRID < 2 else xi / float(GRID - 1)
            px = cx - span_x / 2.0 + span_x * u
            for yi in range(GRID):
                v = 0.5 if GRID < 2 else yi / float(GRID - 1)
                py = cy - span_y / 2.0 + span_y * v
                # 1. support at the declared height, by the same window
                #    the downward probe uses.
                seen = [z1 for x0, x1, y0, y1, _z0, z1 in boxes
                        if x0 - _EPS <= px <= x1 + _EPS
                        and y0 - _EPS <= py <= y1 + _EPS
                        and top_z - GROUND_REACH - _EPS <= z1
                        <= top_z + PROBE_LIFT + _EPS]
                if not seen or abs(max(seen) - top_z) > HEIGHT_TOLERANCE:
                    continue
                # 2. room to stand up on it.
                floor = top_z + LIFT
                ceiling = top_z + HEADROOM
                over = [z0 for x0, x1, y0, y1, z0, z1 in boxes
                        if _overlaps(px - half, px + half, x0, x1)
                        and _overlaps(py - half, py + half, y0, y1)
                        and _overlaps(floor, ceiling, z0, z1)]
                if over:
                    headroom = max(headroom, min(over) - top_z)
                    continue
                usable += 1
        if usable == 0:
            findings.append({"surface": sname, "reason": "occluded",
                             "declared": round(top_z, 3),
                             "best_headroom": round(headroom, 3),
                             "needs": HEADROOM, "of": GRID * GRID})
    return findings


def stance_spot(colliders, stone, top_z):
    """The safest point on this Surface where a player fits, or None.

    `Placement`'s candidate set in Blender coordinates, but NOT its
    verdict order. The solver returns the FIRST clear candidate because
    it wants any spot and wants it cheaply; a socket is written down
    once and read forever, so this returns the clear candidate NEAREST
    THE RECT CENTRE instead.

    Two reasons, and the first is the one that matters. A socket derived
    from the search order lands against a rect edge -- measured, on
    `shell_tower_collapsed`'s `high_3`, 0.03 m from the stone above it,
    which is inside the audit's tolerance but is not a margin. Nearest to
    centre puts it where there is room on every side. The second is
    stability: the centre is what the socket used to be, so every socket
    whose centre is already clear does not move at all, and the ones that
    do move are exactly the ones that were wrong.
    """
    (cx, cy), (ex, ey) = stone
    if ex < STANCE_XZ - _EPS or ey < STANCE_XZ - _EPS:
        return None
    boxes = [(lo[0], hi[0], lo[1], hi[1], lo[2], hi[2])
             for lo, hi in (_world_box(c) for c in colliders)]
    half = STANCE_XZ / 2.0

    def ok(px, py):
        seen = [z1 for x0, x1, y0, y1, _z0, z1 in boxes
                if x0 - _EPS <= px <= x1 + _EPS
                and y0 - _EPS <= py <= y1 + _EPS
                and top_z - GROUND_REACH - _EPS <= z1
                <= top_z + PROBE_LIFT + _EPS]
        if not seen or abs(max(seen) - top_z) > HEIGHT_TOLERANCE:
            return False
        return not any(
            _overlaps(px - half, px + half, x0, x1)
            and _overlaps(py - half, py + half, y0, y1)
            and _overlaps(top_z + LIFT, top_z + HEADROOM, z0, z1)
            for x0, x1, y0, y1, z0, z1 in boxes)

    if ok(cx, cy):
        return (cx, cy)
    span_x = max(ex - STANCE_XZ, 0.0)
    span_y = max(ey - STANCE_XZ, 0.0)
    best = None
    for xi in range(GRID):
        u = 0.5 if GRID < 2 else xi / float(GRID - 1)
        px = cx - span_x / 2.0 + span_x * u
        for yi in range(GRID):
            v = 0.5 if GRID < 2 else yi / float(GRID - 1)
            py = cy - span_y / 2.0 + span_y * v
            if not ok(px, py):
                continue
            # Row-major order breaks ties, so the answer is the same on
            # every machine and every run.
            far = (px - cx) ** 2 + (py - cy) ** 2
            if best is None or far < best[0] - _EPS:
                best = (far, px, py)
    return None if best is None else (best[1], best[2])


def assert_standable(name, colliders, stones, heights, snames):
    """Refuse a shell that declares a Surface nobody can stand on.

    The build gate for owner ruling C(ii). `measure_stances` reports;
    this refuses, because a Surface with zero valid placements is not a
    marginal room, it is a false statement in the manifest -- and
    Production's audit will say so with the shell already integrated.

    It reproduced all six of `1648fa9`'s surface findings before any of
    them was fixed, with the same numbers the engine measured (1.50,
    0.50, 1.50 m of headroom on the three towers; nothing at all on the
    three plinths). That is why it is trusted enough to stop a build --
    and it is still a PREDICTION. `room_audit.gd` measures the real
    thing, and remains the only physical authority.
    """
    findings = measure_stances(colliders, stones, heights, snames)
    if not findings:
        return len(stones)
    lines = []
    for f in findings:
        if f["reason"] == "too_small":
            lines.append("'%s' is %.2f x %.2f m and a player is %.2f across"
                         % (f["surface"], f["extent"][0], f["extent"][1],
                            STANCE_XZ))
        else:
            lines.append("'%s' declared at %.2f offers nowhere to stand: "
                         "the best of %d spots has %.2f m of headroom and "
                         "a player needs %.2f"
                         % (f["surface"], f["declared"], f["of"],
                            f["best_headroom"], f["needs"]))
    raise AssertionError(
        "%s: %d surface(s) cannot keep the promise a `stand` Surface "
        "makes -- %s" % (name, len(findings), "; ".join(lines)))
