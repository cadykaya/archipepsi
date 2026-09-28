"""Batch 049 — A09: cross-room machinery communication and branch identity.

    .tools/blender/blender -b -noaudio --python tools/blender/build_connect.py

**Outcome A09 asks for:** the player can connect a source-room action
with a destination-room consequence. That is a visual LANGUAGE problem,
not a signal bus, and A09.1 says so explicitly: "Do not build a gameplay
signal bus; the model is a readable presentation of declared
relationships." Nothing here carries a signal, a state machine or a
script.

## It extends Batch 043 rather than replacing it

`mach_conduit_run` is a 2.00 x 0.50 m wall run, 0.14 deep, with a
separate `state_band` quad carrying the 64 x 16 state texture and a
`fill_band` that grows across it. **Every piece here keeps that face
height and that band convention**, so a run, an elbow and a tee show the
same band at the same pitch. `assert_band_face` refuses a piece whose
band face is not 0.50 m tall -- a corner whose band is a different width
from the run it turns is a corner that looks like a different system.

## THE THREE COMMITMENTS, WHICH IS A09.2'S REAL REQUIREMENT

> "Persistent configuration, a held input and a permanent repair must
> not share a misleading identical switch pose."

So they are three different MACHINES, not one machine in three colours:

* **`conn_set_dial`** -- persistent configuration. A detented rotary
  that stays where it is put. Its tell is the detent ring: something
  that holds a position.
* **`conn_hold_paddle`** -- a held input. A sprung paddle with a visible
  return spring and a stop. Its tell is that it obviously wants to come
  back.
* **`conn_repair_seal`** -- a permanent repair. A one-shot lever behind
  a frangible tab. Its tell is that using it BREAKS something, which is
  the only honest way to draw "this cannot be undone".

`assert_commitments_differ` compares the three across the batch and
refuses if any two share a silhouette within 5 cm on every axis. A
player who cannot tell them apart across a room has been lied to.

## What this deliberately does not do

No animation. A09.4 says the acknowledgments' motion must reflect real
accepted/refused/deferred state and must not "animate success ahead of
the authoritative result" -- so the moving parts are NODES with declared
positions, and what moves them is Production's.
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
OUT = "batch049/connect"
DENSITY = materials.ARCH_DENSITY
SIZE = materials.ARCH_SIZE

#: Batch 043's conduit, mirrored. A piece that does not match these is a
#: piece from a different system.
RUN_HEIGHT = 0.50
RUN_DEPTH = 0.14
BAND_PROUD = 0.016
WALK_UP = 0.12
JUMP_APEX = 1.3333333333333333

_IMAGES = {}
_MATERIALS = {}
_SILHOUETTES = {}


def _image(role):
    if role not in _IMAGES:
        canvas, _ = materials.paint(THEME, role)
        _IMAGES[role] = canvas.to_blender("cn_%s_%s" % (THEME, role))
    return _IMAGES[role]


def _paint(obj, role, collide=None):
    if role not in _MATERIALS:
        _MATERIALS[role] = common.make_textured_material(
            role, _image(role), roughness=pal.roughness(THEME))
    common.assign(obj, _MATERIALS[role])
    return roomcollision.paint_role(obj, collide or role)


def _b(tag, size, at, role="wall", collide=None):
    return _paint(brushkit.block(tag, size, at), role, collide)


def assert_band_face(objects, label):
    """Every band in this family is the run's own face height.

    Batch 043's `state_band` is 2.00 x 0.50 and its texture is authored
    to register with the channel. A corner or a tee whose band is a
    different width shows the same state at a different scale, which
    reads as a different system rather than the same run continuing.
    """
    vec = __import__("mathutils").Vector
    for obj in objects:
        if not obj.name.startswith("state_band"):
            continue
        corners = [obj.matrix_world @ vec(c) for c in obj.bound_box]
        height = max(c.z for c in corners) - min(c.z for c in corners)
        if abs(height - RUN_HEIGHT) > 0.001:
            raise SystemExit(
                "%s: %s is %.3f m tall and Batch 043's run face is "
                "%.2f. A band that changes width at a corner is a "
                "different system, not the same run turning."
                % (label, obj.name, height, RUN_HEIGHT))


def assert_no_footholds(objects, label):
    """A09.5: the relay and service assemblies are NONBLOCKING.

    Same rule as Batch 048, for the same reason: a service cabinet with
    a 0.4 m ledge on it is a step somebody will find, and "nonblocking"
    has to mean something checkable.
    """
    vec = __import__("mathutils").Vector
    for obj in objects:
        corners = [obj.matrix_world @ vec(c) for c in obj.bound_box]
        top = max(c.z for c in corners)
        if top <= WALK_UP:
            continue
        # BOUNDED ABOVE BY THE JUMP, and the first version was not.
        # A standing jump tops out at 1.333 m with no mantle, so a face
        # higher than that is not somewhere a player can get from the
        # floor -- and a rule that refuses the TOP of a two-metre
        # cabinet is a rule that will be switched off. It fired on
        # exactly that. What it is for is a ledge at knee or waist
        # height, and that is the band it checks.
        wide = max(c.x for c in corners) - min(c.x for c in corners)
        deep = max(c.y for c in corners) - min(c.y for c in corners)
        if wide >= 0.35 and deep >= 0.35 and top <= JUMP_APEX:
            raise SystemExit(
                "%s: %s presents a %.2f x %.2f m face %.3f m up. A09.5 "
                "says these assemblies are nonblocking, and a ledge is "
                "a step." % (label, obj.name, wide, deep, top))


def remember_silhouette(objects, label):
    vec = __import__("mathutils").Vector
    corners = [o.matrix_world @ vec(c) for o in objects for c in o.bound_box]
    _SILHOUETTES[label] = (
        max(c.x for c in corners) - min(c.x for c in corners),
        max(c.y for c in corners) - min(c.y for c in corners),
        max(c.z for c in corners) - min(c.z for c in corners))


def assert_commitments_differ():
    """The three control kinds must be tellable apart across a room.

    A09.2 in one line: a persistent setting, a held input and a
    permanent repair must not share a pose. Colour does not count --
    the themes recolour everything -- so the test is the silhouette.
    """
    kinds = ["conn_set_dial", "conn_hold_paddle", "conn_repair_seal"]
    for i, a in enumerate(kinds):
        for b in kinds[i + 1:]:
            if a not in _SILHOUETTES or b not in _SILHOUETTES:
                continue
            if all(abs(x - y) < 0.05
                   for x, y in zip(_SILHOUETTES[a], _SILHOUETTES[b])):
                raise SystemExit(
                    "%s and %s are within 5 cm on every axis (%s vs %s). "
                    "A09.2 says a persistent setting, a held input and a "
                    "permanent repair must not share a pose, and a "
                    "player cannot read a colour across a room."
                    % (a, b, _SILHOUETTES[a], _SILHOUETTES[b]))


# --- A09.1  the conduit family ----------------------------------------

def _band(tag, size, at):
    """A state band, in Batch 043's own convention: its own object, its
    own face, proud of the channel so it is never z-fighting with it."""
    return _b(tag, size, at, "accent", "trim")


def conn_run_elbow():
    """`conn_run_elbow` -- the run turns a corner and the band follows.

    A 90 degree corner in the wall plane. Two half-metre legs meeting at
    a mitred box, with a band on each leg so the state reads round the
    turn. Authored about the corner itself, so it drops onto an inside
    or outside corner without an offset.
    """
    parts = []
    leg = 0.6
    body = _b("elbow_back", (leg, RUN_DEPTH * 0.45, RUN_HEIGHT),
              (leg * 0.5 - 0.07, RUN_DEPTH * 0.28, RUN_HEIGHT * 0.5),
              "trim")
    parts.append(_b("elbow_back_b", (RUN_DEPTH * 0.45, leg, RUN_HEIGHT),
                    (RUN_DEPTH * 0.28, leg * 0.5 - 0.07, RUN_HEIGHT * 0.5),
                    "trim"))
    parts.append(_b("elbow_knuckle", (0.24, 0.24, RUN_HEIGHT + 0.06),
                    (0.06, 0.06, RUN_HEIGHT * 0.5), "wall"))
    for tag, size, at in (
            ("a", (leg - 0.14, RUN_DEPTH, 0.07),
             (leg * 0.5, 0.0, RUN_HEIGHT - 0.035)),
            ("b", (RUN_DEPTH, leg - 0.14, 0.07),
             (0.0, leg * 0.5, RUN_HEIGHT - 0.035))):
        parts.append(_b("elbow_rail_%s" % tag, size, at, "trim"))
    parts.append(_band("state_band_a", (leg - 0.14, BAND_PROUD, RUN_HEIGHT),
                       (leg * 0.5, -0.075, RUN_HEIGHT * 0.5)))
    parts.append(_band("state_band_b", (BAND_PROUD, leg - 0.14, RUN_HEIGHT),
                       (-0.075, leg * 0.5, RUN_HEIGHT * 0.5)))
    return body, parts


def conn_run_tee():
    """`conn_run_tee` -- one run becomes two, and the split is visible.

    The branch is where a relationship forks, so the piece says so: a
    swollen body with a separate `tee_branch_band`, which a runtime can
    light independently of the through run. Two declared bands, not one
    that covers both, because a fork whose halves cannot differ cannot
    show which way a thing went.
    """
    parts = []
    run = 1.0
    body = _b("tee_back", (run, RUN_DEPTH * 0.45, RUN_HEIGHT),
              (0.0, RUN_DEPTH * 0.28, RUN_HEIGHT * 0.5), "trim")
    parts.append(_b("tee_body", (0.34, 0.26, RUN_HEIGHT + 0.06),
                    (0.0, 0.03, RUN_HEIGHT * 0.5), "wall"))
    # The spur reaches BACK to the tee body. The first cut started it
    # at the wall's far face and left a 12 cm gap to the thing it
    # branches from -- a fork that touches nothing.
    parts.append(_b("tee_spur", (RUN_DEPTH * 0.45, 0.5, RUN_HEIGHT),
                    (0.0, 0.36, RUN_HEIGHT * 0.5), "trim"))
    for side in (-1.0, 1.0):
        parts.append(_b("tee_rail_%d" % int(side), (run * 0.5 - 0.17,
                        RUN_DEPTH, 0.07),
                        (side * (run * 0.25 + 0.085), 0.0,
                         RUN_HEIGHT - 0.035), "trim"))
    parts.append(_band("state_band", (run, BAND_PROUD, RUN_HEIGHT),
                       (0.0, -0.075, RUN_HEIGHT * 0.5)))
    parts.append(_band("tee_branch_band", (BAND_PROUD, 0.5, RUN_HEIGHT),
                       (-0.075, 0.36, RUN_HEIGHT * 0.5)))
    return body, parts


def conn_junction_box():
    """`conn_junction_box` -- where runs meet, and where a reader sits.

    A09.1's junction box. Four `port_*` nodes on the four faces a run
    can arrive at, a hinged `box_lid`, and `box_terminals` inside it --
    so an open box shows something worth having opened.
    """
    parts = []
    body = _b("box_shell", (0.8, 0.3, 0.8), (0, 0.15, 0.4), "wall")
    parts.append(_b("box_lid", (0.76, 0.05, 0.76), (0, -0.025, 0.4),
                    "trim"))
    parts.append(_b("box_terminals", (0.5, 0.06, 0.2), (0, 0.06, 0.4),
                    "accent", "trim"))
    for tag, size, at in (
            ("north", (0.2, 0.22, 0.12), (0.0, 0.15, 0.86)),
            ("south", (0.2, 0.22, 0.12), (0.0, 0.15, -0.06)),
            ("east", (0.12, 0.22, 0.2), (0.46, 0.15, 0.4)),
            ("west", (0.12, 0.22, 0.2), (-0.46, 0.15, 0.4))):
        parts.append(_b("port_%s" % tag, size, at, "trim"))
    return body, parts


def conn_wall_pass():
    """`conn_wall_pass` -- the run goes through, and you can see it did.

    A09.1's wall penetration. A collar on each face and a sleeve
    between: the piece that says two rooms are one installation, which
    is A09's whole outcome. Authored about the wall's centre plane, so
    `pass_collar_near` and `pass_collar_far` land on the two faces.
    """
    parts = []
    thickness = 0.6
    body = _b("pass_sleeve", (0.34, thickness, 0.34), (0, 0, 0.17),
              "trim")
    for tag, y in (("near", -thickness * 0.5 + 0.05),
                   ("far", thickness * 0.5 - 0.05)):
        parts.append(_b("pass_collar_%s" % tag, (0.52, 0.1, 0.52),
                        (0, y, 0.17), "wall"))
        parts.append(_b("pass_gland_%s" % tag, (0.38, 0.14, 0.38),
                        (0, y * 0.78, 0.17), "accent", "trim"))
    return body, parts


# --- A09.2  bezels and readers ----------------------------------------

def conn_reader_panel():
    """`conn_reader_panel` -- four appearances, and a label nobody baked.

    A09.2. `label_field` is a blank plate: the identifier is
    RUNTIME-POPULATED, so nothing here spells out a relationship the
    runtime might not have. The four appearances are four named nodes
    rather than four textures, so a runtime shows one by making it
    visible instead of by swapping a material on a merged mesh.
    """
    parts = []
    body = _b("reader_case", (0.7, 0.12, 0.5), (0, 0.06, 0.25), "wall")
    parts.append(_b("reader_bezel", (0.78, 0.06, 0.58), (0, 0.09, 0.25),
                    "trim"))
    parts.append(_b("label_field", (0.52, 0.03, 0.14), (0, -0.015, 0.36),
                    "accent", "trim"))
    for i, tag in enumerate(("selected", "unselected", "blocked",
                             "pending")):
        parts.append(_b("state_%s" % tag, (0.1, 0.03, 0.1),
                        (-0.21 + i * 0.14, -0.015, 0.15), "accent",
                        "trim"))
    return body, parts


def conn_set_dial():
    """`conn_set_dial` -- persistent configuration. It STAYS.

    Its tell is the detent ring: a toothed collar that holds a position.
    `dial_knob` is the part that turns and `dial_pointer` is where it
    points; both are nodes, neither animates.
    """
    parts = []
    body = _b("dial_plate", (0.34, 0.08, 0.34), (0, 0.04, 0.17), "wall")
    ring = brushkit.prism("dial_detent", 0.15, 0.05, 8, (0, 0, 0.17))
    brushkit.spin(ring, "x", 90.0)
    parts.append(_paint(ring, "trim"))
    for i in range(8):
        import math
        a = i * math.tau / 8.0
        parts.append(_b("dial_tooth_%d" % i, (0.03, 0.05, 0.03),
                        (math.cos(a) * 0.15, -0.015,
                         0.17 + math.sin(a) * 0.15), "trim"))
    knob = brushkit.prism("dial_knob", 0.08, 0.1, 8, (0, 0, 0.17))
    brushkit.spin(knob, "x", 90.0)
    parts.append(_paint(knob, "accent", "trim"))
    parts.append(_b("dial_pointer", (0.03, 0.06, 0.13), (0, -0.05, 0.23),
                    "accent", "trim"))
    return body, parts


def conn_hold_paddle():
    """`conn_hold_paddle` -- a held input. It obviously wants to return.

    Its tell is the SPRING: a visible coil behind the paddle and a stop
    it rests against. Tall and narrow where the dial is square and flat,
    so the two are tellable apart at a distance -- which
    `assert_commitments_differ` checks rather than takes on trust.
    """
    parts = []
    body = _b("paddle_mount", (0.2, 0.14, 0.9), (0, 0.07, 0.45), "wall")
    parts.append(_b("paddle_arm", (0.16, 0.3, 0.1), (0, -0.14, 0.72),
                    "accent", "trim"))
    parts.append(_b("paddle_grip", (0.26, 0.1, 0.18), (0, -0.26, 0.72),
                    "accent", "trim"))
    spring = brushkit.prism("paddle_spring", 0.05, 0.22, 8,
                            (0, -0.05, 0.55))
    brushkit.spin(spring, "x", 90.0)
    parts.append(_paint(spring, "trim"))
    parts.append(_b("paddle_stop", (0.22, 0.14, 0.06), (0, -0.03, 0.44),
                    "trim"))
    return body, parts


def conn_repair_seal():
    """`conn_repair_seal` -- a permanent repair. Using it BREAKS a thing.

    A09.2's third commitment, and the only honest way to draw "this
    cannot be undone" is a one-shot: a lever behind a frangible tab,
    with the tab's two halves as their own nodes so a runtime can show
    intact or broken. Wide and low, so it is neither the dial nor the
    paddle from across the room.
    """
    parts = []
    body = _b("seal_case", (0.9, 0.16, 0.34), (0, 0.08, 0.17), "wall")
    parts.append(_b("seal_frame", (0.98, 0.06, 0.42), (0, 0.11, 0.17),
                    "trim"))
    for side, tag in ((-1.0, "left"), (1.0, "right")):
        parts.append(_b("seal_tab_%s" % tag, (0.34, 0.03, 0.22),
                        (side * 0.19, -0.015, 0.17), "accent", "trim"))
    parts.append(_b("seal_lever", (0.12, 0.14, 0.24), (0, -0.04, 0.17),
                    "accent", "trim"))
    return body, parts


# --- A09.3  identity ---------------------------------------------------

def conn_id_plaque():
    """`conn_id_plaque` -- the SAME plaque at both ends.

    A09.3: the same identifier appears at source and destination, and
    the player should not be relying on a popup they never see. So this
    is one asset, mounted twice, with `plaque_id_field` blank for a
    runtime-populated identifier.

    The blade is the approved navigation family's shape and this does
    NOT rebuild it: `nav_blade` (Batch 022, PASS, six themes) mounts on
    `blade_seat`. Art is not making a second navigation language.
    """
    parts = []
    body = _b("plaque_back", (0.9, 0.08, 0.42), (0, 0.04, 0.21), "wall")
    parts.append(_b("plaque_frame", (0.98, 0.04, 0.5), (0, 0.06, 0.21),
                    "trim"))
    parts.append(_b("plaque_id_field", (0.66, 0.03, 0.2),
                    (0, -0.015, 0.25), "accent", "trim"))
    # Where the approved nav_blade bolts on. Not a blade.
    parts.append(_b("blade_seat", (0.22, 0.12, 0.12), (0, -0.02, 0.04),
                    "trim"))
    parts.append(_b("plaque_lug", (0.12, 0.12, 0.1), (0.39, 0.04, 0.04),
                    "trim"))
    return body, parts


# --- A09.4  acknowledgments --------------------------------------------

def conn_flag_ack():
    """`conn_flag_ack` -- a flag that is up or down, and nothing else.

    A09.4. Two declared positions, no third and no animation: A09.4 is
    explicit that art must not animate success ahead of the
    authoritative result, and a node with two positions cannot.
    """
    parts = []
    body = _b("flag_post", (0.1, 0.1, 0.62), (0, 0, 0.31), "trim")
    parts.append(_b("flag_pivot", (0.16, 0.16, 0.12), (0, 0, 0.62),
                    "wall"))
    parts.append(_b("flag_blade", (0.08, 0.3, 0.26), (0, 0.18, 0.66),
                    "accent", "trim"))
    parts.append(_b("flag_base", (0.26, 0.26, 0.06), (0, 0, 0.03),
                    "trim"))
    return body, parts


def conn_breaker():
    """`conn_breaker` -- a breaker you can see the position of.

    A09.4's "visible breaker". `breaker_handle` has a thrown and a
    closed position; `breaker_window` is where a runtime shows which.
    """
    parts = []
    body = _b("breaker_case", (0.4, 0.2, 0.56), (0, 0.1, 0.28), "wall")
    parts.append(_b("breaker_handle", (0.1, 0.16, 0.2), (0, -0.06, 0.38),
                    "accent", "trim"))
    parts.append(_b("breaker_window", (0.2, 0.04, 0.1), (0, -0.01, 0.16),
                    "accent", "trim"))
    parts.append(_b("breaker_bus", (0.44, 0.1, 0.08), (0, 0.1, 0.6),
                    "trim"))
    return body, parts


def conn_gauge():
    """`conn_gauge` -- a needle, and here that IS the right instrument.

    A09.4 lists a gauge needle among the local acknowledgments, and
    unlike A08.2's class plate this really is a continuous reading: how
    much of a deferred thing has happened. `gauge_needle` is the part
    that moves and `gauge_face` is what it moves over.
    """
    parts = []
    body = _b("gauge_case", (0.3, 0.14, 0.3), (0, 0.07, 0.15), "wall")
    face = brushkit.prism("gauge_face", 0.12, 0.04, 8, (0, 0.0, 0.15))
    brushkit.spin(face, "x", 90.0)
    parts.append(_paint(face, "trim"))
    parts.append(_b("gauge_needle", (0.02, 0.03, 0.1), (0, -0.02, 0.19),
                    "accent", "trim"))
    parts.append(_b("gauge_bezel", (0.3, 0.05, 0.3), (0, 0.0, 0.15),
                    "accent", "trim"))
    return body, parts


# --- A09.5  the installation -------------------------------------------

def conn_relay_cabinet():
    """`conn_relay_cabinet` -- why several rooms are one installation.

    A09.5, and the constraint is that it is NONBLOCKING and reused in
    the actual branch footprint rather than becoming a new hero room.
    So it is 0.9 m of floor and 2.2 m tall: a thing you walk past.

    `assert_no_footholds` keeps it from growing a ledge.
    """
    parts = []
    body = _b("relay_case", (0.9, 0.5, 2.0), (0, 0, 1.0), "wall")
    parts.append(_b("relay_cap", (0.98, 0.58, 0.14), (0, 0, 2.07),
                    "trim"))
    for i in range(3):
        parts.append(_b("relay_door_%d" % i, (0.28, 0.05, 1.5),
                        (-0.3 + i * 0.3, -0.27, 1.0), "accent", "trim"))
    parts.append(_b("relay_plinth", (0.98, 0.58, 0.1), (0, 0, 0.05),
                    "trim"))
    parts.append(_b("relay_vent", (0.7, 0.05, 0.24), (0, -0.27, 1.9),
                    "trim"))
    return body, parts


def conn_service_stack():
    """`conn_service_stack` -- the generator end of the same installation.

    A09.5's other half: a stack with a feed, tall and narrow so it reads
    from the far room. Nonblocking, same gate.
    """
    parts = []
    body = _b("stack_tank", (0.6, 0.6, 1.4), (0, 0, 0.7), "wall")
    column = brushkit.prism("stack_flue", 0.16, 1.0, 8, (0, 0, 1.85))
    parts.append(_paint(column, "trim"))
    parts.append(_b("stack_cowl", (0.44, 0.44, 0.12), (0, 0, 2.4),
                    "accent", "trim"))
    parts.append(_b("stack_feed", (0.16, 0.34, 0.16), (0, 0.4, 0.9),
                    "accent", "trim"))
    parts.append(_b("stack_foot", (0.72, 0.72, 0.1), (0, 0, 0.05),
                    "trim"))
    return body, parts


#: name, builder, checks
ASSETS = [
    ("conn_run_elbow", conn_run_elbow, ("band",)),
    ("conn_run_tee", conn_run_tee, ("band",)),
    ("conn_junction_box", conn_junction_box, ()),
    ("conn_wall_pass", conn_wall_pass, ()),
    ("conn_reader_panel", conn_reader_panel, ()),
    ("conn_set_dial", conn_set_dial, ("silhouette",)),
    ("conn_hold_paddle", conn_hold_paddle, ("silhouette",)),
    ("conn_repair_seal", conn_repair_seal, ("silhouette",)),
    ("conn_id_plaque", conn_id_plaque, ()),
    ("conn_flag_ack", conn_flag_ack, ()),
    ("conn_breaker", conn_breaker, ()),
    ("conn_gauge", conn_gauge, ()),
    ("conn_relay_cabinet", conn_relay_cabinet, ("nonblocking",)),
    ("conn_service_stack", conn_service_stack, ("nonblocking",)),
]

#: What each control COMMITS to, in A09.2's three kinds. Carried in the
#: manifest so the distinction is data a consumer can read, not a thing
#: a reviewer has to remember.
COMMITMENT = {
    "conn_set_dial": "persistent configuration -- stays where it is put",
    "conn_hold_paddle": "held input -- returns when released",
    "conn_repair_seal": "permanent repair -- one shot, breaks its tab",
}


def main():
    made = {}
    for name, build, checks in ASSETS:
        common.reset_scene()
        _IMAGES.clear()
        _MATERIALS.clear()
        body, parts = build()
        objects = [body] + parts
        if "band" in checks:
            assert_band_face(objects, name)
        if "nonblocking" in checks:
            assert_no_footholds(objects, name)
        if "silhouette" in checks:
            remember_silhouette(objects, name)
        for obj in objects:
            common.uv_project_world(obj, DENSITY, SIZE)
        common.assert_parts_touch(body, parts, name)
        entry = common.export_glb(body, "%s/%s.glb" % (OUT, name), "prop",
                                  tier="architecture", texture_size=SIZE,
                                  anchor="as-built", parts=parts)
        entry["parts"] = [p.name for p in parts]
        if name in COMMITMENT:
            entry["commitment"] = COMMITMENT[name]
        made[name] = entry
        print("[connect] %-20s %4d tris, %d part(s)"
              % (name, entry["triangles"], len(parts)))

    assert_commitments_differ()

    path = os.path.join(common.MODEL_DIR, OUT, "manifest.json")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    shared = {
        "batch": "049", "kind": "connection_visual",
        "status": "PROPOSAL -- visual only, review-pending, not a "
                  "production default",
        "carries": "mesh and named parts only. No collider, body, trigger, "
                   "light, camera, script or animation. NO SIGNAL BUS.",
        "extends": "batch043/machinery -- same 0.50 m run face, same "
                   "state_band convention",
        "texels_per_metre": DENSITY,
        "not_changed": ["collision", "any runtime state", "placement",
                        "the approved navigation family",
                        "any approved asset"],
    }
    with open(path, "w", encoding="utf-8") as handle:
        json.dump({k: dict(shared, **v) for k, v in made.items()},
                  handle, indent=2, sort_keys=True)
    common.log("manifest %s" % path)


if __name__ == "__main__":
    main()
