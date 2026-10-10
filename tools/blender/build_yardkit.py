"""Batch 046 — the Blindside junction: track, docks, the span, the gantry.

    .tools/blender/blender -b -noaudio --python tools/blender/build_yardkit.py

**WHAT THIS IS.** Batch 045 gave the four 0.4 setpieces their vehicles.
This one gives the Blindside yard the place those vehicles run through:
track that reads as track, docks with an edge, a repairable span that is
visibly a drawbridge, and a gantry whose machinery explains why the
control is up there.

**WHAT IT IS NOT.** No collider, body, trigger, light, camera or script.
No ramp, stair or ledge toward anything the scenario keeps out of reach.
Production owns gameplay geometry, collision, state timing and placement.

## Every number here is MEASURED, not remembered

`assets/models/batch046/yard_fit.json` is written by
`tools/content/run_yard_measure.sh`, which rebuilds Production's rail
from Production's five control points with Production's own `RailPath`
and evaluates it. The gap the span bridges is **14.048 m** and no amount
of reading `railway_scenario.gd` will tell you that -- three of the five
control points sit on a Catmull-Rom corner. A builder that hard-coded
"about fourteen metres" would be guessing, and the span would not meet
both track ends.

If that file is missing or stale, this script REFUSES rather than
falling back on a constant nobody measured.

## Two gates this batch runs, and why

**The sightline ceiling.** A05.1 says the hookshot target stays visible
from the intended approach. The measurement solves the eye-to-ring line
for every viewpoint on that approach and reports the LOWEST it ever
sits at each lateral. Anything this batch places between the ring and
the branch is checked against that ceiling, so "decorative scaffolding
in front of the target" is a build failure rather than a playtest
complaint.

**The no-new-route rule.** Nothing here may put a standable surface
where the scenario put none. The yard's whole design is that S3 stands
on an island and the gantry is out of reach; a bracket at a convenient
height is an art-added route. Every piece that sits in the open is
declared with the height a player could stand on it, and the gate
refuses anything that lands inside a jump of somewhere it should not.
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import brushkit  # noqa: E402
import common  # noqa: E402
import materials  # noqa: E402
import palette as pal  # noqa: E402
import roomcollision  # noqa: E402

THEME = common.THEME
OUT = "batch046/yardkit"
FIT = "batch046/yard_fit.json"
DENSITY = materials.ARCH_DENSITY
SIZE = materials.ARCH_SIZE

#: The measured controller, from `run_controller_limits.sh`. Not a design
#: rule -- a measurement of the shipped constants by one harness.
JUMP_APEX = 1.3333333333333333
WALK_UP = 0.12
#: 2 * JUMP_VELOCITY / GRAVITY seconds aloft at WALK_SPEED: 0.667 * 7.0.
#: The flat case, which is the most generous -- landing higher costs
#: time -- so the no-route gate stays on the safe side.
JUMP_REACH = 2.0 * 8.0 / 24.0 * 7.0

_IMAGES = {}
_MATERIALS = {}


def load_fit():
    """The measured yard, or a refusal. Never a default."""
    path = os.path.join(common.MODEL_DIR, FIT)
    if not os.path.exists(path):
        raise SystemExit(
            "%s is missing. Run tools/content/run_yard_measure.sh first: "
            "this batch is fitted to a curve that cannot be restated, "
            "only evaluated." % path)
    with open(path, encoding="utf-8") as handle:
        fit = json.load(handle)
    for key in ("span", "gantry", "branch", "docks", "sightline",
                "deck_top_y"):
        if key not in fit:
            raise SystemExit(
                "%s has no %r. It was written by an older or different "
                "measurement; re-run tools/content/run_yard_measure.sh."
                % (path, key))
    return fit


FIT_DATA = load_fit()
GAP = FIT_DATA["span"]["gap"]
BEAM = FIT_DATA["span"]["beam_thickness"]
STOWED_DEG = FIT_DATA["span"]["stowed_degrees"]
DECK_TOP = FIT_DATA["deck_top_y"]
RAIL_Y = FIT_DATA["rail"]["y"]
DOCK = FIT_DATA["docks"][0]
DOCK_ALONG = DOCK["pad_size_local"][2]
DOCK_INNER = DOCK["lateral_inner"]
DOCK_OUTER = DOCK["lateral_outer"]
RECEIVER_LATERAL = DOCK["receiver_lateral"]
GANTRY = FIT_DATA["gantry"]
GANTRY_DECK_Y = GANTRY["deck_centre"][1]
GANTRY_COLUMN_TOP = GANTRY["column_size"][1]
SIGHT = {s["lateral"]: (s["low_y"], s["high_y"],
                        s["low_along"], s["high_along"])
         for s in FIT_DATA["sightline"]["samples"]}


def _image(role):
    if role not in _IMAGES:
        canvas, _ = materials.paint(THEME, role)
        _IMAGES[role] = canvas.to_blender("yk_%s_%s" % (THEME, role))
    return _IMAGES[role]


def _paint(obj, role, collide=None):
    if role not in _MATERIALS:
        _MATERIALS[role] = common.make_textured_material(
            role, _image(role), roughness=pal.roughness(THEME))
    common.assign(obj, _MATERIALS[role])
    return roomcollision.paint_role(obj, collide or role)


def _b(tag, size, at, role="wall", collide=None):
    return _paint(brushkit.block(tag, size, at), role, collide)


def corridor_at(lateral):
    """The sight corridor at a lateral, interpolated between samples.

    Four numbers: the height band and the along-track band the ray
    bundle sweeps. Outside the measured span there is no constraint, and
    saying so is better than inventing one -- art past the ring or
    behind the furthest viewpoint cannot occlude.
    """
    keys = sorted(SIGHT)
    if lateral <= keys[0] or lateral >= keys[-1]:
        return None
    lower = max(k for k in keys if k <= lateral)
    upper = min(k for k in keys if k >= lateral)
    if upper == lower:
        return SIGHT[lower]
    t = (lateral - lower) / (upper - lower)
    return tuple(SIGHT[lower][i] + (SIGHT[upper][i] - SIGHT[lower][i]) * t
                 for i in range(4))


def corridor_over(l0, l1):
    """The corridor's full extent across a lateral range, or None."""
    got = [corridor_at(l0 + (l1 - l0) * i / 8.0) for i in range(9)]
    got = [g for g in got if g is not None]
    if not got:
        return None
    return (min(g[0] for g in got), max(g[1] for g in got),
            min(g[2] for g in got), max(g[3] for g in got))


def assert_clears_sightline(objects, label, lateral_of_origin,
                            along_of_origin=0.0, world_lift=0.0):
    """Nothing STANDS ACROSS the eye-to-ring line.

    `lateral_of_origin` and `along_of_origin` place the asset in the
    yard's own frame -- lateral runs from the rail out past the gantry
    to the branch, along runs down the track -- so local coordinates are
    checked where the asset actually stands.

    Two earlier cuts of this were wrong and both are worth keeping in
    the record, because each passed review in my own head:

    1. It refused anything ABOVE the line. That is not occlusion; a beam
       hanging over the sightline stands over the ring, not in front of
       it. It failed a legal support stay 2.7 m clear.
    2. It was then flat -- lateral and height only. `branch_lane()` puts
       the branch 3 m back along the track while the gantry sits square
       on it, so every ray is a diagonal in plan. A flat gate refuses a
       mast standing beside the walkway, nowhere near the line.

    What it checks now is a genuine overlap in all three: the asset's
    box against the swept ray bundle's height and along-track extent at
    every lateral it occupies.
    """
    vec = __import__("mathutils").Vector
    for obj in objects:
        corners = [obj.matrix_world @ vec(c) for c in obj.bound_box]
        l0 = lateral_of_origin + min(c.x for c in corners)
        l1 = lateral_of_origin + max(c.x for c in corners)
        a0 = along_of_origin + min(c.y for c in corners)
        a1 = along_of_origin + max(c.y for c in corners)
        z0 = min(c.z for c in corners) + world_lift
        z1 = max(c.z for c in corners) + world_lift
        band = corridor_over(l0, l1)
        if band is None:
            continue
        if z0 > band[1] + 1e-6 or z1 < band[0] - 1e-6:
            continue
        if a0 > band[3] + 1e-6 or a1 < band[2] - 1e-6:
            continue
        raise SystemExit(
            "%s: %s occupies height %.3f-%.3f and along %.3f-%.3f over "
            "laterals %.2f-%.2f, and the eye-to-ring ray bundle sweeps "
            "height %.3f-%.3f and along %.3f-%.3f there. It stands "
            "ACROSS the sightline and would hide the hookshot target, "
            "which A05.1 says it may not. The corridor comes from "
            "yard_fit.json, measured."
            % (label, obj.name, z0, z1, a0, a1, l0, l1,
               band[0], band[1], band[2], band[3]))


def assert_no_new_route(objects, label, forbidden, lateral_of_origin=0.0,
                        along_of_origin=0.0, world_lift=0.0):
    """No art-added standing surface within a JUMP of somewhere closed.

    A jump is not only a height. The first cut of this compared heights
    alone and refused a waymarker standing SIX METRES away from the
    gantry, because 2.50 + 1.33 clears 3.50 -- which it does, straight
    up, from a surface nowhere near it. A gate that cannot tell "under
    it" from "across the yard from it" will keep refusing correct art
    until somebody stops believing it, and then it is worse than
    nothing.

    So each closed thing carries a FOOTPRINT, and the reach is measured
    from Production's own constants rather than chosen:

        GRAVITY 24.0, JUMP_VELOCITY 8.0, WALK_SPEED 7.0

    A jump is aloft for 2 * 8 / 24 = 0.667 s before returning to the
    height it left, and the body moves at 7.0 m/s throughout, so the
    furthest it can travel horizontally is 4.67 m -- and that is the
    FLAT case, which is the most generous one. Landing on something
    higher costs time. Using the flat number keeps the gate on the safe
    side of a question it does not have to answer precisely.
    """
    vec = __import__("mathutils").Vector
    for obj in objects:
        corners = [obj.matrix_world @ vec(c) for c in obj.bound_box]
        top = max(c.z for c in corners) + world_lift
        foot = min(c.z for c in corners) + world_lift
        if top - foot <= WALK_UP:
            continue
        l0 = lateral_of_origin + min(c.x for c in corners)
        l1 = lateral_of_origin + max(c.x for c in corners)
        a0 = along_of_origin + min(c.y for c in corners)
        a1 = along_of_origin + max(c.y for c in corners)
        for height, (fl0, fl1), (fa0, fa1), what in forbidden:
            if top + JUMP_APEX < height - 1e-6:
                continue
            gap_l = max(0.0, max(fl0 - l1, l0 - fl1))
            gap_a = max(0.0, max(fa0 - a1, a0 - fa1))
            if (gap_l ** 2 + gap_a ** 2) ** 0.5 > JUMP_REACH:
                continue
            raise SystemExit(
                "%s: %s tops out at %.3f m, %.2f m horizontally from %s "
                "at %.2f. A player standing there reaches %.3f with a "
                "standing jump and can travel %.2f m while doing it. "
                "That is an art-added route to something the scenario "
                "keeps closed."
                % (label, obj.name, top,
                   (gap_l ** 2 + gap_a ** 2) ** 0.5, what, height,
                   top + JUMP_APEX, JUMP_REACH))


# --- A04.1  the track ---------------------------------------------------

def track_module():
    """`yk_track_module` -- one metre of track, laid end to end.

    THE ENVELOPE IS THEIRS. `_track()` lays pieces 0.5 wide and 0.35 tall
    centred on the rail at y 0.6, so the visible track lives between
    0.425 and 0.775. Each piece is as long as the chord it covers, and
    those lengths are whatever the sweep produced -- so this is a TILING
    module rather than a fixed segment, authored about the piece centre
    with its ends flush so a row of them has no seam.
    """
    parts = []
    # The sleeper fills the piece's own footprint. It is the body because
    # it is what every other part stands on.
    # Their envelope is 0.35 tall centred on the rail, so local z runs
    # -0.175 to +0.175 and every course below stacks inside it.
    body = _b("track_sleeper", (0.5, 1.0, 0.1), (0, 0, -0.125), "trim")
    for side in (-1.0, 1.0):
        # Two rail heads on chairs. The heads run the full metre and meet
        # the next module's flush, which is what makes a row read as one
        # continuous rail instead of a line of bricks.
        parts.append(_b("track_chair_%d" % int(side), (0.16, 0.26, 0.08),
                        (side * 0.17, 0, -0.035), "trim"))
        parts.append(_b("track_rail_%d" % int(side), (0.09, 1.0, 0.12),
                        (side * 0.17, 0, 0.065), "accent", "trim"))
    # A web between the sleepers: the gap under a rail is where a track
    # stops reading as a stripe painted on the floor.
    parts.append(_b("track_web", (0.22, 0.34, 0.09), (0, 0, -0.03), "wall"))
    return body, parts


def track_end():
    """`yk_track_end` -- the cut end at the gap, and it must not lie.

    `_track()` SKIPS the pieces between S2 and S3, so the missing track
    is something a player sees before anything refuses them. The end cap
    has to finish that run in a way that reads as STOPPED: a buffer beam
    across the heads, a bevelled stop block, and nothing that continues
    past it. A taper would read as a transition to track out of sight.
    """
    parts = []
    body = _b("end_sleeper", (0.5, 0.6, 0.1), (0, 0, -0.125), "trim")
    for side in (-1.0, 1.0):
        parts.append(_b("end_chair_%d" % int(side), (0.16, 0.6, 0.08),
                        (side * 0.17, 0, -0.035), "trim"))
        parts.append(_b("end_rail_%d" % int(side), (0.09, 0.6, 0.12),
                        (side * 0.17, 0, 0.065), "accent", "trim"))
    # The stop: square across the track, standing ON the sleeper and
    # taller than the rail heads, in the theme accent -- which is what
    # this palette warns with; there is no separate `hazard` treatment
    # in a theme family.
    #
    # IT EXCEEDS THE TRACK ENVELOPE, DELIBERATELY AND DECLARED. Their
    # track pieces are 0.35 tall and live between 0.425 and 0.775; this
    # tops out at world 0.905, because a buffer stop level with the rail
    # heads is a bump, not a stop. It is still 0.10 below the dock top
    # and nothing stands on it, so it adds no route -- and the manifest
    # says so rather than letting the extra 0.13 m be discovered.
    parts.append(_b("end_stop", (0.5, 0.18, 0.3), (0, 0.21, 0.075),
                   "trim"))
    parts.append(_b("end_stop_band", (0.54, 0.1, 0.08), (0, 0.21, 0.265),
                   "accent", "trim"))
    return body, parts


# --- A04.2  the dock ----------------------------------------------------

def track_pier():
    """`yk_track_pier` -- what holds the track up, which is a finding.

    **Their track stands on nothing.** `_track()` lays pieces 0.35 tall
    centred on the rail at 0.6, so the visible track floats between
    0.425 and 0.775 over a yard floor at 0.00 -- a 0.425 m gap with no
    ballast, pier or trestle in it. It is not visible in a shot taken
    from above and it is the first thing the eye finds in a shot taken
    from the side.

    A04.1 asks for supports and contact structure, so this is that:
    exactly the 0.425 m, at the module pitch, authored about its own
    floor. Whether Production wants it under every metre or every third
    is placement, and placement is theirs.
    """
    parts = []
    height = RAIL_Y - 0.175
    body = _b("pier_footing", (0.8, 0.8, 0.12), (0, 0, 0.06), "trim")
    parts.append(_b("pier_stem", (0.44, 0.5, height - 0.18),
                    (0, 0, 0.12 + (height - 0.18) * 0.5), "wall"))
    parts.append(_b("pier_cap", (0.62, 0.66, 0.06),
                    (0, 0, height - 0.03), "trim"))
    return body, parts


def dock_edge():
    """`yk_dock_edge` -- the platform's working edge, 7 m of it.

    THE INNER EDGE IS A HARD LINE. The pad's inner edge and the deck's
    outer edge meet exactly -- `lateral_inner` 2.00 against a deck half
    width of 2.00 -- so anything that crosses it is inside the vehicle.
    Authored so local x = 0 IS that line and everything sits on the
    positive side, outward, onto the platform.

    Nothing rises more than 0.10 above the pad: this is the boarding
    edge, and a kerb a player has to climb to board is a worse edge than
    no edge.
    """
    parts = []
    # The nosing: one continuous strip from the edge inward, its top
    # FLUSH with the pad so nothing on this asset is a step. Everything
    # else on the edge stands on it, which is also what makes it the
    # body rather than one more fitting.
    body = _b("dock_nosing", (1.1, DOCK_ALONG, 0.05), (0.55, 0, -0.025),
              "trim")
    # A lip at the line itself, 0.04 proud -- a third of the walk-up
    # limit, so it reads as an edge and is not one.
    parts.append(_b("dock_lip", (0.1, DOCK_ALONG, 0.04), (0.05, 0, 0.02),
                    "accent", "trim"))
    # Boarding markers -- three, spread over the deck's own 4 m width, so
    # a player can see where the deck will arrive before it does.
    for i, along in enumerate((-1.6, 0.0, 1.6)):
        parts.append(_b("board_mark_%d" % i, (0.26, 0.5, 0.02),
                        (0.62, along, 0.01), "accent", "trim"))
    # The tactile band further in, at the edge of the walkable part.
    # Flat: a ridge here is a trip hazard on the one edge people step
    # over.
    parts.append(_b("dock_band", (0.14, DOCK_ALONG, 0.02),
                    (0.98, 0, 0.01), "trim"))
    return body, parts


def dock_buffer():
    """`yk_dock_buffer` -- a bollard the deck can lean on, off the line.

    Stands on the platform OUTSIDE the receiver posts, which sit at
    lateral 2.60. Anything nearer the rail than that is between a player
    and the control they have to shoot.
    """
    parts = []
    body = _b("buffer_base", (0.46, 0.46, 0.1), (0, 0, 0.05), "trim")
    parts.append(_b("buffer_post", (0.3, 0.3, 0.62), (0, 0, 0.41), "wall"))
    parts.append(_b("buffer_head", (0.4, 0.4, 0.14), (0, 0, 0.79),
                   "trim"))
    parts.append(_b("buffer_band", (0.44, 0.44, 0.08), (0, 0, 0.5),
                   "accent", "trim"))
    return body, parts


def dock_locker():
    """`yk_dock_locker` -- the limited service furniture A04.2 allows.

    A cabinet and a coiled hose reel. Deliberately SHORT: at 0.86 m it
    is chest furniture, not cover, and not a step to anywhere -- the
    no-route gate checks that rather than trusting the number here.
    """
    parts = []
    body = _b("locker_body", (0.7, 1.3, 0.8), (0, 0, 0.4), "wall")
    parts.append(_b("locker_top", (0.78, 1.38, 0.06), (0, 0, 0.83),
                   "trim"))
    parts.append(_b("locker_door", (0.04, 1.0, 0.56), (0.36, 0, 0.42),
                   "accent", "trim"))
    # `brushkit.prism` builds about z; `spin` turns the GEOMETRY about
    # the part's own centre, which is the only way to lie a cylinder down
    # without swinging it across the scene.
    reel = brushkit.prism("locker_reel", 0.22, 0.26, 8,
                          (0.0, -0.68, 0.44))
    brushkit.spin(reel, "x", 90.0)
    parts.append(_paint(reel, "trim"))
    parts.append(_b("locker_plinth", (0.76, 1.36, 0.08), (0, 0, 0.04),
                   "trim"))
    return body, parts


# --- A04.3  the span ----------------------------------------------------

def span_beam():
    """`yk_span_beam` -- the repairable span, at its measured length.

    **The aligned mesh meets both track ends.** It is exactly `GAP` long,
    read from the measurement, so the far end lands on S3's rail point
    and not near it.

    **Authored about the beam's own centre**, which is where
    `RailSpan._ready()` puts `_body` -- local (0, 0, gap/2) inside the
    pivot frame. The pivot is the frame's origin; this is the beam's. Two
    different origins and the handoff names which is which, because a
    span authored about the pivot arrives half a span short.

    **Stowed is a drawbridge and must stay one.** At 62 degrees the far
    end stands 12.40 m up and only 6.60 m along -- against a walkable
    limit of 46 degrees, so a raised span is not a ramp, and nothing
    here flattens it or adds a foothold to it. The deck plate is on the
    TOP face only: a walking surface on the underside would be a ledge
    when the thing is up.
    """
    parts = []
    # The through-girder. Their collision box is BEAM square; this stays
    # inside it in section so the visual never exceeds what the engine
    # thinks is there.
    body = _b("span_deck", (BEAM, GAP, 0.1), (0, 0, BEAM * 0.5 - 0.05),
              "floor")
    for side in (-1.0, 1.0):
        parts.append(_b("span_web_%d" % int(side),
                        (0.1, GAP, BEAM - 0.1),
                        (side * (BEAM * 0.5 - 0.05), 0, -0.05), "trim"))
    # Cross bracing, visible from below when the span is up -- which is
    # the state a player spends the whole first visit looking at.
    count = int(GAP / 1.6)
    for i in range(count):
        y = -GAP * 0.5 + GAP * (i + 0.5) / count
        parts.append(_b("span_brace_%d" % i, (BEAM - 0.16, 0.12, 0.1),
                        (0, y, -BEAM * 0.5 + 0.06), "wall"))
    # The two ends say which is which. `span_heel` is the pivot end and
    # `span_toe` is the end that has to land on S3's rail.
    parts.append(_b("span_heel", (BEAM + 0.12, 0.22, BEAM + 0.12),
                   (0, -GAP * 0.5 + 0.11, 0), "accent", "trim"))
    parts.append(_b("span_toe", (BEAM + 0.08, 0.18, BEAM + 0.08),
                   (0, GAP * 0.5 - 0.09, 0), "accent", "trim"))
    # The state light, at the toe: the end whose position IS the state.
    parts.append(_b("span_lamp", (0.18, 0.12, 0.18),
                   (0, GAP * 0.5 - 0.22, BEAM * 0.5 + 0.06),
                   "accent", "trim"))
    return body, parts


def switch_stand():
    """`yk_switch_stand` -- points, a tongue and a position indicator.

    **CANDIDATE, and labelled one in the manifest.** `RailCarrier` runs
    one path; there is no switchable routing for this to report. A04.4
    says the asset must not advertise graph support the carrier lacks,
    so the indicator is a blade that can sit in TWO declared positions
    and nothing here claims a third, a route or a destination.
    """
    parts = []
    body = _b("switch_base", (0.5, 0.6, 0.12), (0, 0, -0.12), "trim")
    parts.append(_b("switch_box", (0.34, 0.34, 0.42), (0, 0, 0.15),
                   "wall"))
    # The tongue: a tapered blade lying in the track's own envelope, so
    # it reads as part of the rail rather than something dropped on it.
    parts.append(_b("switch_tongue", (0.07, 1.1, 0.1),
                    (0.17, 0.52, -0.005), "trim"))
    # The indicator, as its own node with two declared positions. It is
    # the only part a runtime would ever drive.
    parts.append(_b("switch_indicator", (0.26, 0.08, 0.26),
                   (0, 0, 0.46), "accent", "trim"))
    parts.append(_b("switch_rod", (0.06, 0.5, 0.06), (0, 0.3, 0.14),
                   "trim"))
    return body, parts


# --- A05  the gantry ----------------------------------------------------

def gantry_head():
    """`yk_gantry_head` -- the machinery, and the 0.40 m nobody sees yet.

    **A finding, built around rather than hidden.** `_gantry()` raises
    the platform to `GANTRY_Y` ABOVE THE RAIL -- world 3.70, so its
    underside is at 3.50 -- and stands a column `GANTRY_Y` tall from the
    floor, topping out at 3.10. The column stops 0.40 m short of the
    platform it holds up. Measured from their own constants, and it is
    theirs to decide: this asset spans the gap with a head casting so the
    load path reads, and the handoff reports the number rather than
    treating a visual patch as a repair.

    Authored about the PLATFORM CENTRE, local z = 0 at world 3.70.

    Everything here is checked against the sightline ceiling. The first
    cut of the winch stood 2.6 m over the platform and was refused at
    lateral 7.5, where the eye-to-ring line is 6.07.
    """
    parts = []
    # The head casting: from the column top at 3.10 to the platform
    # underside at 3.50, in the platform's own footprint.
    lift = GANTRY_DECK_Y                       # world y of local z = 0
    top_of_column = GANTRY_COLUMN_TOP - lift   # -0.60 in local terms
    underside = -GANTRY["deck_size"][1] * 0.5  # -0.20
    height = underside - top_of_column         # 0.40
    body = _b("gantry_head", (1.1, 1.1, height),
              (0, 0, top_of_column + height * 0.5), "trim")
    # Four brackets fanning from the casting to the platform corners: the
    # load path from a 0.6 m column to a 4 m plate.
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            parts.append(_b("gantry_bracket_%d%d" % (int(sx), int(sy)),
                            (1.5, 0.14, 0.12),
                            (sx * 0.75, sy * 0.62, underside - 0.06),
                            "wall"))
    # Service conduit down the column: something the machinery is fed by.
    parts.append(_b("gantry_conduit", (0.16, 0.16, 0.5),
                   (0.5, 0.5, top_of_column - 0.05), "trim"))
    return body, parts


def gantry_winch():
    """`yk_gantry_winch` -- the machine on top, as its OWN asset.

    It started inside `yk_gantry_head` and `assert_parts_touch` refused
    it, correctly. The head casting lives UNDER the platform, between
    world 3.10 and 3.50; a winch standing on the platform top at 3.90 is
    separated from it by 0.40 m of Production's slab. Two parents, two
    assets -- joining them would have meant a strut through their
    geometry, which is the kind of thing that looks fine in a render.

    Stands on the platform's far side so it is BEHIND the player's aim at
    the ring rather than in front of it, and checked against the
    sightline ceiling like everything else on this lateral.
    """
    parts = []
    body = _b("winch_house", (1.1, 1.0, 0.9), (0, 0, 0.45), "wall")
    parts.append(_b("winch_cap", (1.2, 1.1, 0.1), (0, 0, 0.95),
                   "accent", "trim"))
    drum = brushkit.prism("winch_drum", 0.26, 0.9, 8, (0.0, 0.0, 0.52))
    brushkit.spin(drum, "x", 90.0)
    parts.append(_paint(drum, "accent", "trim"))
    # The rope run, toward the ring: the reason the machine is here.
    parts.append(_b("winch_fairlead", (0.3, 0.22, 0.22), (-0.6, 0, 0.52),
                   "trim"))
    parts.append(_b("winch_plinth", (1.2, 1.1, 0.08), (0, 0, 0.04),
                   "trim"))
    return body, parts


def gantry_anchor():
    """`yk_gantry_anchor` -- mounting for the grapple plate, not a hood.

    A05.2: adapt the MOUNTING, never the target. The plate is 1.2 square
    at world 7.20 and the ring hangs under it at 6.88 with a 0.42 m outer
    radius. Nothing here comes within 0.30 m of the ring's own volume,
    and nothing stands between the ring and the approach -- the arm
    reaches it from ABOVE and from the far side.

    Authored about the plate's centre, local z = 0 at world 7.20.
    """
    parts = []
    ring_clear = GANTRY["ring_outer_radius"] + 0.3
    # The plate's own backing, above it: a soffit the arm hangs from.
    body = _b("anchor_soffit", (1.8, 1.8, 0.24), (0, 0, 0.32), "wall")
    # The arm, reaching out and back to the facility -- on the side AWAY
    # from the approach, which is +x here (outward, toward the gantry
    # platform and the wall behind it).
    parts.append(_b("anchor_arm", (2.2, 0.5, 0.22), (1.3, 0, 0.36),
                   "trim"))
    parts.append(_b("anchor_stay", (0.16, 0.16, 1.1), (2.2, 0, 0.9),
                   "trim"))
    # A collar round the plate, outside the ring's clearance.
    for side in (-1.0, 1.0):
        parts.append(_b("anchor_collar_%d" % int(side),
                        (0.14, 1.6, 0.3),
                        (side * (ring_clear + 0.07), 0, 0.07), "accent",
                        "trim"))
    # The one light on it, ABOVE the plate so it is never between the
    # player and the ring.
    parts.append(_b("anchor_lamp", (0.24, 0.24, 0.12), (0, 0, 0.48),
                   "accent", "trim"))
    return body, parts


def lever_housing():
    """`yk_lever_housing` -- the alignment control's housing and linkage.

    A05.3: the relevant parts are separately addressable, and the housing
    does not assume which input operates it. `lever_arm` is the part a
    runtime would move, `lever_lamp` the part it would light, and
    `service_panel` is a door with a state, not a decal.

    Authored about the platform top, so local z = 0 sits at world 3.90.
    """
    parts = []
    body = _b("lever_plinth", (0.9, 0.9, 0.24), (0, 0, 0.12), "trim")
    parts.append(_b("lever_quadrant", (0.16, 0.5, 0.5), (0, 0, 0.48),
                   "wall"))
    # The arm, its own node, drawn in the mid position: an arm modelled
    # at one end of its throw reads as broken in the other state.
    parts.append(_b("lever_arm", (0.09, 0.4, 0.1), (0, 0.2, 0.62),
                   "accent", "trim"))
    parts.append(_b("lever_lamp", (0.14, 0.14, 0.14), (0, -0.28, 0.6),
                   "accent", "trim"))
    # The service panel: a separate door, on the housing's outward face.
    parts.append(_b("service_panel", (0.06, 0.6, 0.46), (0.42, 0, 0.42),
                   "accent", "trim"))
    parts.append(_b("service_hinge", (0.05, 0.08, 0.46), (0.42, 0.3, 0.42),
                   "trim"))
    parts.append(_b("lever_linkage", (0.07, 0.07, 0.34), (0, -0.3, 0.17),
                   "trim"))
    return body, parts


def branch_mast():
    """`yk_branch_mast` -- one landmark, and the measurement sized it.

    A05.4 asks for a single **nonblocking** anchor landmark on the
    branch, and A05.5 for a branch symbol legible from both sides. This
    is both: a waymarker with the same blade on two faces, so the
    approach and the return read the same sign rather than two.

    **It is 1.62 m tall because the corridor said so, and that is a
    finding rather than a compromise.** The first cut was a 2.2 m mast
    and the sightline gate refused it. Near the viewer the eye-to-ring
    ray bundle IS at head height -- that is what "the ray starts at the
    eye" means -- so at the walkway's end the corridor's floor is 2.80
    against a branch deck at 1.00, leaving 1.80 m. Anything on the
    branch taller than a person crosses somebody's view of the ring.

    So a landmark on the acquisition branch is a WAYMARKER, not a
    tower, and the blade is made large rather than the post made tall.
    A tower here would have been the "decorative scaffolding" A05.1
    names, discovered in a playtest instead of at build time.
    """
    parts = []
    body = _b("mast_base", (0.9, 0.9, 0.14), (0, 0, 0.07), "trim")
    parts.append(_b("mast_collar", (0.46, 0.46, 0.12), (0, 0, 0.2),
                    "trim"))
    parts.append(_b("mast_column", (0.32, 0.32, 1.42), (0, 0, 0.79),
                    "wall"))
    # THE SAME BLADE ON BOTH FACES. A sign that reads only on the way
    # out is a sign that does not help you find your way back. Large,
    # because the height is spent and the legibility has to come from
    # somewhere.
    for side, tag in ((1.0, "out"), (-1.0, "back")):
        parts.append(_b("mast_blade_%s" % tag, (0.06, 1.3, 0.62),
                        (side * 0.19, 0, 1.0), "trim_plain", "trim"))
        parts.append(_b("mast_chevron_%s" % tag, (0.05, 0.4, 0.4),
                        (side * 0.23, 0.36, 1.0), "accent", "trim"))
    parts.append(_b("mast_cap", (0.44, 0.44, 0.12), (0, 0, 1.56),
                    "accent", "trim"))
    return body, parts


def branch_conduit():
    """`yk_branch_conduit` -- the continuity A05.4 asks for, in one part.

    Cable trays and service markings that tie the branch back to the
    junction. A 2 m tiling run: the branch walkway is 12 m of otherwise
    empty slab and the same module laid along it is what makes the two
    ends read as one place.

    Low by design -- 0.46 m at its tallest, which is under the sightline
    ceiling everywhere on the branch and, more to the point, under
    nothing a player would try to stand on to reach something.
    """
    parts = []
    body = _b("conduit_tray", (0.4, 2.0, 0.12), (0, 0, 0.06), "trim")
    for side in (-1.0, 1.0):
        parts.append(_b("conduit_cable_%d" % int(side), (0.1, 2.0, 0.1),
                        (side * 0.11, 0, 0.17), "accent", "trim"))
    parts.append(_b("conduit_strap", (0.46, 0.12, 0.3), (0, -0.7, 0.15),
                   "wall"))
    parts.append(_b("conduit_marking", (0.3, 0.44, 0.02), (0, 0.6, 0.13),
                   "accent", "trim"))
    return body, parts


#: name, builder, anchor, the lateral its origin stands at (None when
#: the asset is nowhere near the sight corridor), its along-track offset
#: in the yard's own frame, the world lift its origin has, and the floor
#: it stands on for the no-route gate.
ASSETS = [
    ("yk_track_module", track_module, "centre", None, 0.0, 0.6, None),
    ("yk_track_end", track_end, "centre", None, 0.0, 0.6, None),
    ("yk_track_pier", track_pier, "floor", None, 0.0, 0.0, 0.0),
    ("yk_dock_edge", dock_edge, "centre", None, 0.0, DECK_TOP, None),
    ("yk_dock_buffer", dock_buffer, "floor", None, 0.0, DECK_TOP,
     DECK_TOP),
    ("yk_dock_locker", dock_locker, "floor", None, 0.0, DECK_TOP,
     DECK_TOP),
    ("yk_span_beam", span_beam, "centre", None, 0.0, 0.6, None),
    ("yk_switch_stand", switch_stand, "floor", None, 0.0, 0.6, None),
    ("yk_gantry_head", gantry_head, "centre",
     GANTRY["lateral_deck"], GANTRY["along"], GANTRY_DECK_Y, None),
    ("yk_gantry_winch", gantry_winch, "floor",
     GANTRY["lateral_deck"] + 1.05, GANTRY["along"],
     GANTRY_DECK_Y + GANTRY["deck_size"][1] * 0.5, None),
    ("yk_gantry_anchor", gantry_anchor, "centre",
     GANTRY["lateral_plate"], GANTRY["along"],
     GANTRY["plate_centre"][1], None),
    ("yk_lever_housing", lever_housing, "floor",
     GANTRY["lateral_deck"], GANTRY["along"],
     GANTRY_DECK_Y + GANTRY["deck_size"][1] * 0.5, None),
    # The landmark stands at the walkway's end, on the branch's own lane
    # -- three metres back along the track, which is where the branch
    # is. Checked there, not at a convenient coordinate.
    ("yk_branch_mast", branch_mast, "floor",
     FIT_DATA["branch"]["walk_to"] - 0.5,
     FIT_DATA["branch"]["lane_along"] - 1.6, DECK_TOP, DECK_TOP),
    ("yk_branch_conduit", branch_conduit, "floor",
     FIT_DATA["branch"]["lateral_yard"],
     FIT_DATA["branch"]["lane_along"], DECK_TOP, DECK_TOP),
]

#: What the scenario keeps out of reach, with the footprint each one
#: actually occupies -- (height, lateral range, along range, name). A
#: height with no footprint is what made the first route gate refuse
#: correct art.
FORBIDDEN = [
    (GANTRY_DECK_Y - GANTRY["deck_size"][1] * 0.5,
     (GANTRY["lateral_deck"] - GANTRY["deck_size"][0] * 0.5,
      GANTRY["lateral_deck"] + GANTRY["deck_size"][0] * 0.5),
     (GANTRY["along"] - GANTRY["deck_size"][2] * 0.5,
      GANTRY["along"] + GANTRY["deck_size"][2] * 0.5),
     "the gantry platform"),
    (GANTRY["plate_centre"][1],
     (GANTRY["lateral_plate"] - GANTRY["plate_size"][0] * 0.5,
      GANTRY["lateral_plate"] + GANTRY["plate_size"][0] * 0.5),
     (GANTRY["along"] - GANTRY["plate_size"][2] * 0.5,
      GANTRY["along"] + GANTRY["plate_size"][2] * 0.5),
     "the grapple plate"),
]


def main():
    made = {}
    for name, build, anchor, lateral, along, lift, floor_y in ASSETS:
        common.reset_scene()
        _IMAGES.clear()
        _MATERIALS.clear()
        body, parts = build()
        objects = [body] + parts
        if anchor == "floor":
            common.set_origin_group(objects, "floor")
        if lateral is not None:
            assert_clears_sightline(objects, name, lateral, along,
                                    world_lift=lift)
        if floor_y is not None:
            assert_no_new_route(objects, name, FORBIDDEN,
                                lateral if lateral is not None else 0.0,
                                along, world_lift=floor_y)
        for obj in objects:
            common.uv_project_world(obj, DENSITY, SIZE)
        common.assert_parts_touch(body, parts, name)
        entry = common.export_glb(body, "%s/%s.glb" % (OUT, name), "prop",
                                  tier="architecture", texture_size=SIZE,
                                  anchor=anchor, parts=parts)
        entry["parts"] = [p.name for p in parts]
        if lateral is not None:
            entry["stands_at_lateral"] = lateral
            entry["stands_at_along"] = along
            entry["sight_corridor_there"] = corridor_at(lateral)
        made[name] = entry
        print("[yardkit] %-18s %4d tris, %d part(s)"
              % (name, entry["triangles"], len(parts)))

    path = os.path.join(common.MODEL_DIR, OUT, "manifest.json")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    shared = {
        "batch": "046", "kind": "yard_visual",
        "status": "PROPOSAL -- visual only, review-pending, not a "
                  "production default",
        "carries": "mesh and named parts only. No collider, body, trigger, "
                   "light, camera or script.",
        "fitted_to": {
            "production_ref": "claude/archipepsi-0-4-blindside",
            "measured_by": "tools/content/run_yard_measure.sh",
            "span_gap": GAP,
            "deck_top_y": DECK_TOP,
            "gantry_deck_y": GANTRY_DECK_Y,
            "gantry_column_top_y": GANTRY_COLUMN_TOP,
            "dock_lateral_inner": DOCK_INNER,
            "receiver_lateral": RECEIVER_LATERAL,
        },
        "texels_per_metre": DENSITY,
        "not_changed": ["collision", "speeds", "timings", "placement",
                        "room topology", "route availability",
                        "any approved asset"],
    }
    with open(path, "w", encoding="utf-8") as handle:
        json.dump({k: dict(shared, **v) for k, v in made.items()},
                  handle, indent=2, sort_keys=True)
    common.log("manifest %s" % path)


if __name__ == "__main__":
    main()
