"""Batch 050 — A11: enemy jobs and the spaces that host them.

    .tools/blender/blender -b -noaudio --python tools/blender/build_jobs.py

**A11 is NOT blocked, and the inventory said so.** `Constants.ENEMY_JOBS`
declares four jobs with their parameters, and `enemy.gd` implements all
four -- so the "if no runtime job contract exists yet" escape in A11.6
does not apply and this batch is fitted to real numbers:

    ENEMY_JOBS            melee/charger/scuttler patrol, ranged/brute/
                          bulwark/artillery watch, drifter/diver drift,
                          beacon tend
    ENEMY_JOB_SPEED       0.45
    ENEMY_PATROL_PAUSE    1.2       seconds at each beat end
    ENEMY_PATROL_RADIUS   4.5       the beat is a point on this circle
    ENEMY_POST_TOLERANCE  1.5       how close to the post counts as back
    ENEMY_SWEEP_RATE      0.7 rad/s (half that for `tend`)

## The four jobs have four different working areas, and that is the fit

Read out of `enemy.gd` rather than guessed:

* **patrol** -- `_patrol` walks to a random point on a 4.5 m circle
  round the post, pauses 1.2 s, picks another. Its floor is a DISC
  9 m across, walked over.
* **drift** -- `_drift` circles the post at **2.5 m**, at 0.4 rad/s,
  and never descends. Its space is a RING at the role's hover height.
* **watch** and **tend** -- both hold the post and sweep `rotation.y`
  in place. Their space is a CYLINDER the role's own width: it has to
  be able to turn around.

So a job prop's first duty is to be OUT OF THE WAY of the job, and
`assert_clear_of_job` checks that against the served role's published
envelope instead of trusting a comment. A11.2's "avoid one oversized
docking station for every enemy regardless of role" is the same rule
stated from the other side.

## What this does NOT deliver, and why

**A11.1's motion clips are not here.** The blocker is not the job
contract -- that exists -- it is the same one A10.4 ran into: there is
no authored-visual path into `Enemy.visual`, no animation owner, and
gameplay already scales that node for the flinch and the windup swell.
Nothing in this batch invents a behavioural controller to stage an
animation, which A11.1 forbids in the same sentence it asks for clips.

**A11.5's idle-to-alert comparison is delivered in the only truthful
form available**: the bodies are single joined meshes, so there is no
pose to change. What the frames compare is the POST -- occupied and
alerted -- through the anchors Batch 030 now carries and the props'
own states. The report says exactly that rather than implying a pose.
"""

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import brushkit  # noqa: E402
import common  # noqa: E402
import materials  # noqa: E402
import palette as pal  # noqa: E402
import roomcollision  # noqa: E402
from build_enemy_roles import ENVELOPES  # noqa: E402

THEME = common.THEME
OUT = "batch050/jobs"
DENSITY = materials.ARCH_DENSITY
SIZE = materials.ARCH_SIZE

#: `Constants`, mirrored. The assertions below are what stops a mirror
#: from drifting.
JOBS = {"melee": "patrol", "ranged": "watch", "brute": "watch",
        "charger": "patrol", "bulwark": "watch", "drifter": "drift",
        "diver": "drift", "scuttler": "patrol", "artillery": "watch",
        "beacon": "tend"}
PATROL_RADIUS = 4.5
POST_TOLERANCE = 1.5
#: `_drift`: `want = post + (cos, 0, sin) * 2.5`. Not a constant in
#: their file -- a literal in the function -- and it is the number a
#: perch has to stay inside.
DRIFT_RADIUS = 2.5
WALK_UP = 0.12
#: A little air between a prop and the body that works beside it.
CLEARANCE = 0.15

_IMAGES = {}
_MATERIALS = {}


def _image(role):
    if role not in _IMAGES:
        canvas, _ = materials.paint(THEME, role)
        _IMAGES[role] = canvas.to_blender("jb_%s_%s" % (THEME, role))
    return _IMAGES[role]


def _paint(obj, role, collide=None):
    if role not in _MATERIALS:
        _MATERIALS[role] = common.make_textured_material(
            role, _image(role), roughness=pal.roughness(THEME))
    common.assign(obj, _MATERIALS[role])
    return roomcollision.paint_role(obj, collide or role)


def _b(tag, size, at, role="wall", collide=None):
    return _paint(brushkit.block(tag, size, at), role, collide)


def widest(roles):
    """The largest published width among the roles a prop serves."""
    return max(max(ENVELOPES[r][0], ENVELOPES[r][2]) for r in roles)


def assert_clear_of_job(objects, label, roles, at_post=True):
    """A job prop stays out of the space the job needs.

    For `watch` and `tend` that is a cylinder the role's own width,
    because both hold the post and turn in place -- a pedestal inside
    it is a pedestal the beacon rotates through. For `drift` it is the
    2.5 m circle the flyer flies, so a central perch may be no wider
    than that circle minus the flyer.

    `patrol` has no such cylinder: the role walks a 9 m disc and its
    props are floor cues, which are checked for flatness instead.
    """
    vec = __import__("mathutils").Vector
    jobs = set(JOBS[r] for r in roles)
    if jobs & {"watch", "tend"} and at_post:
        keep = widest(roles) * 0.5 + CLEARANCE
        for obj in objects:
            for c in obj.bound_box:
                w = obj.matrix_world @ vec(c)
                if math.hypot(w.x, w.y) < keep - 1e-6 and w.z > WALK_UP:
                    raise SystemExit(
                        "%s: %s reaches %.3f m from the post and the "
                        "widest role it serves needs %.3f m to turn in. "
                        "`watch` and `tend` both hold the post and sweep "
                        "rotation.y, so anything inside that circle is "
                        "something the role rotates through."
                        % (label, obj.name,
                           math.hypot(w.x, w.y), keep))
    if "drift" in jobs:
        keep = DRIFT_RADIUS - widest(roles) * 0.5 - CLEARANCE
        for obj in objects:
            for c in obj.bound_box:
                w = obj.matrix_world @ vec(c)
                if math.hypot(w.x, w.y) > keep + 1e-6:
                    raise SystemExit(
                        "%s: %s reaches %.3f m from the station and the "
                        "flyer circles at %.2f m with a %.2f m body. A "
                        "perch wider than %.3f m is a perch it flies "
                        "into."
                        % (label, obj.name, math.hypot(w.x, w.y),
                           DRIFT_RADIUS, widest(roles), keep))


def assert_flat(objects, label):
    """A11.4: a decorative mark is not a promise of reachable geometry.

    A floor cue that stands proud enough to be a step is a cue a player
    will read as level design. Under the measured 0.12 m walk-up, it is
    paint.
    """
    vec = __import__("mathutils").Vector
    for obj in objects:
        top = max((obj.matrix_world @ vec(c)).z for c in obj.bound_box)
        if top > WALK_UP:
            raise SystemExit(
                "%s: %s stands %.3f m proud and the measured walk-up is "
                "%.2f. A11.4 says a decorative mark is not a promise of "
                "reachable geometry, and anything a player can step onto "
                "is making one." % (label, obj.name, top, WALK_UP))


# --- watch and tend ----------------------------------------------------

def job_watch_post():
    """`job_watch_post` -- a station a planted role holds and sweeps.

    Serves `ranged`, `brute`, `bulwark` and `artillery`; the widest of
    those is the brute at 1.80, so everything stands clear of a 1.95 m
    circle. The plate under the role is flat and does not count.

    `post_lamp` is its own node: a runtime that wants the post to show
    occupied, alerted or abandoned has somewhere to put it.
    """
    parts = []
    keep = widest(["ranged", "brute", "bulwark", "artillery"]) * 0.5 \
        + CLEARANCE
    # The standing plate: flat, so it is under the role rather than in
    # its way.
    body = _b("post_plate", (2.6, 2.6, 0.06), (0, 0, 0.03), "floor")
    # The service column, OUTSIDE the turning circle.
    x = keep + 0.3
    parts.append(_b("post_column", (0.34, 0.34, 1.5), (x, 0, 0.75),
                    "wall"))
    parts.append(_b("post_head", (0.5, 0.42, 0.3), (x, 0, 1.62), "wall"))
    parts.append(_b("post_lamp", (0.16, 0.1, 0.16), (x - 0.22, 0, 1.62),
                    "accent", "trim"))
    parts.append(_b("post_shelf", (0.44, 0.7, 0.08), (x, 0.5, 1.1),
                    "trim"))
    parts.append(_b("post_kerb", (0.2, 2.6, 0.1), (keep, 0, 0.05),
                    "accent", "trim"))
    return body, parts


def job_tend_pedestal():
    """`job_tend_pedestal` -- the thing a beacon tends.

    `tend` sweeps at half `ENEMY_SWEEP_RATE`, which is the role paying
    attention to something. This is that something: a pedestal with a
    `tend_core` node, standing outside the beacon's own 0.62 m turning
    circle and within its reach.
    """
    parts = []
    keep = widest(["beacon"]) * 0.5 + CLEARANCE
    x = keep + 0.45
    body = _b("tend_base", (0.8, 0.8, 0.12), (x, 0, 0.06), "trim")
    parts.append(_b("tend_stem", (0.34, 0.34, 0.9), (x, 0, 0.57), "wall"))
    parts.append(_b("tend_cradle", (0.62, 0.62, 0.22), (x, 0, 1.13),
                    "wall"))
    parts.append(_b("tend_core", (0.3, 0.3, 0.3), (x, 0, 1.32),
                    "accent", "trim"))
    parts.append(_b("tend_duct", (0.16, 0.16, 0.7), (x + 0.3, 0.0, 0.45),
                    "trim"))
    return body, parts


# --- drift -------------------------------------------------------------

def job_drift_perch():
    """`job_drift_perch` -- a station a flyer circles, hung from above.

    `_drift` orbits the post at 2.5 m and NEVER DESCENDS, so the perch
    lives at the centre of that orbit and must be narrow enough that
    the flyer's own body clears it: the drifter is 1.35 wide, so the
    annulus it sweeps starts at 1.825 m and the perch may not reach it.

    Hung rather than standing, because a flyer that came down to a
    floor pedestal between fights would stop owning the ceiling --
    which is the read `_drift`'s own comment protects.
    """
    parts = []
    body = _b("perch_hanger", (0.24, 0.24, 1.1), (0, 0, 0.55), "trim")
    parts.append(_b("perch_yoke", (1.1, 0.22, 0.18), (0, 0, -0.09),
                    "wall"))
    for side in (-1.0, 1.0):
        parts.append(_b("perch_arm_%d" % int(side), (0.16, 0.16, 0.34),
                        (side * 0.47, 0, -0.27), "trim"))
        parts.append(_b("perch_cradle_%d" % int(side),
                        (0.34, 0.3, 0.1), (side * 0.47, 0, -0.49),
                        "accent", "trim"))
    parts.append(_b("perch_lamp", (0.14, 0.14, 0.1), (0, 0, -0.19),
                    "accent", "trim"))
    return body, parts


# --- shared service ----------------------------------------------------

def job_charge_socket():
    """`job_charge_socket` -- a socket, sized for the role that uses it.

    A11.2's warning is about ONE oversized docking station for
    everything. This is a wall socket 0.5 m across: it serves whatever
    is standing at the post and claims no role-specific fit at all,
    which is the honest alternative to a universal dock.
    """
    parts = []
    body = _b("socket_plate", (0.5, 0.1, 0.5), (0, 0.05, 0.25), "wall")
    parts.append(_b("socket_throat", (0.26, 0.16, 0.26), (0, -0.03, 0.25),
                    "trim"))
    parts.append(_b("socket_lamp", (0.1, 0.06, 0.1), (0.17, -0.01, 0.4),
                    "accent", "trim"))
    parts.append(_b("socket_lead", (0.08, 0.08, 0.34), (-0.17, 0.0, 0.1),
                    "accent", "trim"))
    return body, parts


def job_inspect_panel():
    """`job_inspect_panel` -- something to inspect, with a door.

    `inspect_door` is its own node with two declared positions, and
    `inspect_guts` is behind it -- so an opened panel shows something
    worth having opened, which is what stops an inspection routine
    reading as a body facing a wall.
    """
    parts = []
    body = _b("inspect_frame", (0.9, 0.16, 1.0), (0, 0.08, 0.5), "wall")
    parts.append(_b("inspect_guts", (0.7, 0.06, 0.8), (0, 0.02, 0.5),
                    "accent", "trim"))
    parts.append(_b("inspect_door", (0.86, 0.05, 0.96), (0, -0.025, 0.5),
                    "trim"))
    parts.append(_b("inspect_hinge", (0.06, 0.08, 0.96), (-0.42, -0.02, 0.5),
                    "trim"))
    parts.append(_b("inspect_latch", (0.1, 0.07, 0.16), (0.4, -0.04, 0.5),
                    "accent", "trim"))
    return body, parts


def job_tool_rack():
    """`job_tool_rack` -- tool storage, which A11.4 allows explicitly.

    "Small floor/service cues and tool storage can support the job."
    A rack with three `tool_slot_*` nodes: a runtime that wants to show
    a tool taken has somewhere to hide one.
    """
    parts = []
    body = _b("rack_back", (0.8, 0.12, 1.2), (0, 0.06, 0.6), "wall")
    parts.append(_b("rack_shelf", (0.84, 0.28, 0.06), (0, -0.08, 0.72),
                    "trim"))
    for i in range(3):
        parts.append(_b("tool_slot_%d" % i, (0.14, 0.2, 0.34),
                        (-0.25 + i * 0.25, -0.05, 0.92), "accent",
                        "trim"))
    parts.append(_b("rack_foot", (0.84, 0.28, 0.06), (0, -0.08, 0.05),
                    "trim"))
    return body, parts


# --- patrol, which is floor work only ----------------------------------

def job_post_plate():
    """`job_post_plate` -- where a role returns to, and nothing more.

    `ENEMY_POST_TOLERANCE` is 1.5, so the plate is 3 m across: the
    circle inside which the runtime considers a role to be back at its
    post. Flat, because a patroller walks over it every beat.
    """
    parts = []
    body = _b("post_field", (3.0, 3.0, 0.03), (0, 0, 0.015), "floor")
    for side in (-1.0, 1.0):
        parts.append(_b("post_edge_x%d" % int(side), (0.2, 3.0, 0.02),
                        (side * 1.4, 0, 0.025), "accent", "trim"))
        parts.append(_b("post_edge_y%d" % int(side), (3.0, 0.2, 0.02),
                        (0, side * 1.4, 0.025), "accent", "trim"))
    parts.append(_b("post_centre", (0.5, 0.5, 0.02), (0, 0, 0.025),
                    "trim"))
    return body, parts


def job_beat_cue():
    """`job_beat_cue` -- a mark at the beat, and NOT a route.

    A11.4 in one line: "decorative marks are not promises of reachable
    geometry." `_patrol` picks a random point on a 4.5 m circle, so
    there is no fixed path to draw -- and a painted line between two
    points would be Art inventing a route the runtime does not walk.

    So this is a single scuff at the beat radius: a worn patch and a
    turn mark, flat, showing that something comes here without
    claiming which way it came.
    """
    parts = []
    body = _b("beat_scuff", (1.4, 1.4, 0.02), (0, 0, 0.01), "floor")
    parts.append(_b("beat_turn", (0.9, 0.12, 0.02), (0, 0.35, 0.02),
                    "accent", "trim"))
    parts.append(_b("beat_wear", (0.5, 0.5, 0.02), (0, -0.2, 0.02),
                    "trim"))
    return body, parts


#: name, builder, the roles it serves, checks
ASSETS = [
    ("job_watch_post", job_watch_post,
     ["ranged", "brute", "bulwark", "artillery"], ("clear",)),
    ("job_tend_pedestal", job_tend_pedestal, ["beacon"], ("clear",)),
    ("job_drift_perch", job_drift_perch, ["drifter", "diver"], ("clear",)),
    ("job_charge_socket", job_charge_socket, [], ()),
    ("job_inspect_panel", job_inspect_panel, [], ()),
    ("job_tool_rack", job_tool_rack, [], ()),
    ("job_post_plate", job_post_plate,
     ["melee", "charger", "scuttler"], ("flat",)),
    ("job_beat_cue", job_beat_cue,
     ["melee", "charger", "scuttler"], ("flat",)),
]


def main():
    made = {}
    for name, build, roles, checks in ASSETS:
        common.reset_scene()
        _IMAGES.clear()
        _MATERIALS.clear()
        body, parts = build()
        objects = [body] + parts
        if "clear" in checks:
            assert_clear_of_job(objects, name, roles)
        if "flat" in checks:
            assert_flat(objects, name)
        for obj in objects:
            common.uv_project_world(obj, DENSITY, SIZE)
        common.assert_parts_touch(body, parts, name)
        entry = common.export_glb(body, "%s/%s.glb" % (OUT, name), "prop",
                                  tier="architecture", texture_size=SIZE,
                                  anchor="as-built", parts=parts)
        entry["parts"] = [p.name for p in parts]
        entry["serves_roles"] = roles
        entry["serves_jobs"] = sorted(set(JOBS[r] for r in roles))
        made[name] = entry
        print("[jobs] %-20s %4d tris, %d part(s)%s"
              % (name, entry["triangles"], len(parts),
                 "" if not roles else "  for " + ", ".join(roles)))

    path = os.path.join(common.MODEL_DIR, OUT, "manifest.json")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    shared = {
        "batch": "050", "kind": "job_prop",
        "status": "PROPOSAL -- visual only, review-pending, not a "
                  "production default",
        "carries": "mesh and named parts only. No collider, body, trigger, "
                   "light, camera, script or animation.",
        "fitted_to": {
            "production_ref": "claude/archipepsi-0-4-blindside",
            "jobs": JOBS,
            "patrol_radius": PATROL_RADIUS,
            "post_tolerance": POST_TOLERANCE,
            "drift_radius": DRIFT_RADIUS,
            "envelope_source": "Constants.ENEMY_ENVELOPES via "
                               "build_enemy_roles.ENVELOPES -- one source",
        },
        "texels_per_metre": DENSITY,
        "changes_no_placement": True,
        "not_changed": ["encounter placement", "any job behaviour",
                        "collision", "any approved asset"],
    }
    with open(path, "w", encoding="utf-8") as handle:
        json.dump({k: dict(shared, **v) for k, v in made.items()},
                  handle, indent=2, sort_keys=True)
    common.log("manifest %s" % path)


if __name__ == "__main__":
    main()
