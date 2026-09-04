"""Batch 003 -- the Hub's permanent furniture, and the 5 m wall course.

    .tools/blender/blender -b --python tools/blender/build_hub.py

## Why the Hub is first

Style Lock passed, and the owner's production order opens with

> Hub / permanent spaces and Epsilon installation

for the reason `AUTHORED_CONTENT.md` §2 already gives: the Hub is seen more
than any Zone, and its whole value is being the same every time. It is also
the room where the game currently looks most like a prototype -- every
fixture in it is an untextured `BoxMesh` or `PrismMesh` with a flat colour.

Nothing here establishes new visual DNA. Every piece is the locked facility
language applied to a fixture that already exists in `hub.gd`, and the two
architecture modules are more of an approved kit.

## The envelopes are Godot's, and they are not negotiable

Each fixture below replaces a specific object in `hub/hub.gd`, so its
envelope is read out of that file rather than chosen. Godot's `(x, y, z)`
with Y up becomes Blender's `(x, y, z)` with Z up, so a 2.4 x 1.4 x 1.0
station collider is a 2.4 x 1.0 x 1.4 block here.

| Asset | Replaces | Envelope (Godot) | Where |
| --- | --- | --- | --- |
| `hub_shop_counter` | shop `SimpleStation` | 2.4 x 1.4 x 1.0 | (-W/2+1.6, 0, D*0.45), yaw -90 |
| `hub_archive_terminal` | inventory `SimpleStation` | 2.4 x 1.4 x 1.0 | (W/2-1.6, 0, D*0.45), yaw +90 |
| `hub_abandon_station` | `AbandonConsole` | 1.0 x 1.3 x 1.0 | (-W/2+2.4, 0, D-2.4) |
| `hub_campaign_board` | `_build_campaign_board` | 0.12 x 2.6 x 5.2 | (-W/2+0.35, 2.3, D*0.62) |
| `hub_controls_board` | `_build_controls_board` | 0.12 x 2.4 x 4.0 | (W/2-0.35, 2.2, D*0.62) |
| `hub_lab_doorway` | `_cut_lab_doorway` | 3.0 w x 3.2 h opening | -X wall at z 6.0 |

The two boards are HOUSINGS only. Their contents are engineering's: the
campaign board's 30 cells carry `SourceIdentity` tints that are derived from
the multiworld, and the controls board carries text. An authored asset that
baked either would be an asset that lies the first time the data changes.

## The 5 m problem, and the answer

`hub.gd` builds a room 5.0 m tall. The approved architecture kit is a 4.0 m
module: `arch_wall_panel` is 4.00 x 0.40 x 4.00. Three ways to close a 1 m
gap, and only one of them is architecture:

* stretch the panel to 5 m -- breaks the 32 texels/m density that every
  other surface in the game is built to, on the largest surface in the room;
* add a 1 m panel -- a horizontal seam at 4 m with nothing happening at it,
  which reads as a mistake;
* **put the services band up there**, which is what a real facility does
  with the metre above a partition: ducts, conduit, cable tray, vents.

So `arch_wall_upper` is a 1 m course that belongs at 4 m, and the seam under
it is a structural line rather than an accident. It also gets the locked
language's own list -- "industrial corridors, pipes, vents, rails,
catwalks" -- into the part of the room nothing else was using.

`arch_pilaster` exists because 22 m is not a multiple of 4. Five panels
leave 2 m over; a pilaster at each corner and each panel joint absorbs the
remainder into structure instead of a visible half-module.
"""

from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import brushkit  # noqa: E402
import common  # noqa: E402
import propkit  # noqa: E402
import materials  # noqa: E402
import palette as pal  # noqa: E402

THEME = "concrete_facility"
ARCH_DENSITY = pal.budgets()["texel_density"]["architecture"]["target"]
ARCH_SIZE = 128

#: Read from `hub/hub.gd`, never chosen. Art does not get an opinion about
#: how big the Hub is.
HUB_W, HUB_D, HUB_H = 22.0, 16.0, 5.0
MODULE = 4.0
LAB_DOOR_W, LAB_DOOR_H = 3.0, 3.2


# ----------------------------------------------------------------------
# architecture: the two modules the Hub's height and width need
# ----------------------------------------------------------------------

def wall_upper():
    """The 1 m services band that takes a 4 m wall to the Hub's 5 m.

    Ducts and conduit on a bracket line, with a continuous tray under them.
    Deliberately BUSIER than the wall below it: the eye reads the band as
    the top of the room and then stops, which is what keeps a 5 m room from
    feeling like a 4 m room with a gap.
    """
    depth = 0.40
    parts = [
        # The backing course, flush with the wall panel below.
        brushkit.block("wu_back", (MODULE, depth, 1.0), (0.0, 0.0, 0.5)),
        # A cill at the seam, so the joint under this is a detail.
        brushkit.block("wu_cill", (MODULE, depth + 0.14, 0.12),
                       (0.0, -0.07, 0.06)),
        # The main duct, running the full module.
        brushkit.block("wu_duct", (MODULE, 0.34, 0.36),
                       (0.0, -(depth / 2.0 + 0.17), 0.62)),
        brushkit.block("wu_duct_cap", (MODULE, 0.40, 0.06),
                       (0.0, -(depth / 2.0 + 0.20), 0.83)),
    ]
    # Brackets under the duct, on the module's own bolt pitch.
    for i in range(5):
        x = -MODULE / 2.0 + 0.4 + i * 0.8
        parts.append(brushkit.wedge("wu_bracket_%d" % i, (0.10, 0.30, 0.26),
                                    (x, -(depth / 2.0 + 0.15), 0.31),
                                    axis="x"))
    # Two conduits above the duct, at different gauges.
    for j, (dz, r) in enumerate(((0.90, 0.05), (0.90, 0.04))):
        parts.append(brushkit.block("wu_conduit_%d" % j, (MODULE, r * 2, r * 2),
                                    (0.0, -(depth / 2.0 + 0.06 + j * 0.14),
                                     dz)))
    # A vent grille, off-centre so the module does not read as symmetric
    # when two of them sit side by side.
    parts.append(brushkit.grate("wu_vent", (0.90, 0.10, 0.44), 5, 0.05,
                                (MODULE * 0.24, -(depth / 2.0 + 0.05), 0.55),
                                axis="x"))
    return common.join(parts, "arch_wall_upper")


def pilaster():
    """A full-height rib at a panel joint. 22 m is not a multiple of 4.

    Also the piece that makes a corner: two panels meeting at 90 degrees
    leave a seam nothing resolves, and a pilaster is what a building puts
    there.
    """
    parts = [
        brushkit.block("pl_shaft", (0.44, 0.26, HUB_H), (0.0, 0.0, HUB_H / 2.0)),
        brushkit.block("pl_base", (0.60, 0.34, 0.34), (0.0, 0.0, 0.17)),
        brushkit.block("pl_cap", (0.60, 0.34, 0.22), (0.0, 0.0, HUB_H - 0.11)),
    ]
    # A recessed channel up the face, so it is not a plain post.
    for side in (-1.0, 1.0):
        parts.append(brushkit.block("pl_reed_%d" % int(side),
                                    (0.07, 0.06, HUB_H - 0.80),
                                    (side * 0.13, -0.15, HUB_H / 2.0)))
    return common.join(parts, "arch_pilaster")


# ----------------------------------------------------------------------
# the Hub's fixtures
# ----------------------------------------------------------------------

def _station_body(prefix, w, d, h):
    """The shared bones of a Hub station: a counter you stand at.

    ART_BIBLE 4d, applied at station scale. The desk height is the same
    0.95 m it is on the Epsilon console -- a facility does not build its
    counters at two different heights, and the player learns one.
    """
    top = 0.95
    parts = [
        brushkit.block(prefix + "_carcass", (w, d * 0.86, top - 0.12),
                       (0.0, 0.06, (top - 0.12) / 2.0)),
        brushkit.block(prefix + "_top", (w + 0.10, d, 0.10),
                       (0.0, 0.0, top - 0.05)),
        # A toe recess. The counter is something you walk up to.
        brushkit.block(prefix + "_kick", (w - 0.20, 0.10, 0.14),
                       (0.0, -(d * 0.43), 0.07)),
    ]
    for side in (-1.0, 1.0):
        parts.append(brushkit.block(prefix + "_leg_%d" % int(side),
                                    (0.14, d * 0.8, top - 0.12),
                                    (side * (w / 2.0 - 0.07), 0.06,
                                     (top - 0.12) / 2.0)))
    return parts, top


def _signboard(prefix):
    """The board hub.gd hangs its `Label3D` on: 2.2 x 0.5 at y 2.2.

    A BOARD, in a frame, under a lamp -- not a lit panel. Centred at
    2.06 rather than hub.gd's 2.20 so the hood above it is what tops the
    fixture out: the envelope is the sign's own reach, and a hood poking
    out of it is a hood the player's head passes through. The first version
    made the whole 2.2 x 0.5 m face emissive at the signal colour, and a
    square metre of pure teal is the brightest thing in the Hub by a wide
    margin: it out-reads the Epsilon installation across the room, which
    inverts what the room is about. The palette's `signal` family means
    "you can use this", and a station needs to say that at a glance, not
    from the other end of the building.

    So the face is dark, the frame is facility plate, and the only lit part
    is the strip under the lamp. See `_sign_lamp`.
    """
    return [
        brushkit.block(prefix + "_signface", (2.2, 0.06, 0.50),
                       (0.0, -0.16, 2.06)),
        brushkit.frame(prefix + "_signframe", (2.3, 0.60), 0.06, 0.12,
                       (0.0, -0.20, 2.06)),
        # A hood over it, so the light has somewhere to come from.
        brushkit.wedge(prefix + "_signhood", (2.36, 0.26, 0.12),
                       (0.0, -0.27, 2.39), axis="y"),
    ]


def _sign_lamp(prefix):
    """The strip under the sign hood. The only emissive part of a station."""
    return brushkit.block(prefix + "_signlamp", (2.06, 0.07, 0.05),
                          (0.0, -0.32, 2.31))


def shop_counter():
    """QUESTIONABLE GOODS. A counter with a shutter over it.

    The shop is the one fixture in the Hub that is somebody's business
    rather than the facility's, so it gets the one thing nothing else has:
    a roller shutter, half down, and a stack of stock behind the counter.
    It is still built out of the facility's own plate -- whoever runs it
    set up in a room they did not build.
    """
    w, d, h = 2.4, 1.0, 1.4
    parts, top = _station_body("sc", w, d, h)
    parts += [
        # The shutter head and a half-dropped shutter above the counter.
        brushkit.block("sc_head", (w + 0.20, 0.30, 0.26), (0.0, 0.10, 2.32)),
        brushkit.grate("sc_shutter", (w, 0.08, 0.62), 9, 0.05,
                       (0.0, 0.02, 1.88), axis="x"),
        # A back shelf with stock on it.
        brushkit.block("sc_backboard", (w, 0.16, 1.10), (0.0, 0.36, 1.50)),
        brushkit.block("sc_shelf", (w - 0.20, 0.30, 0.06), (0.0, 0.22, 1.32)),
    ]
    for j, (dx, bw, bh) in enumerate(((-0.72, 0.30, 0.26),
                                      (-0.30, 0.22, 0.34),
                                      (0.24, 0.34, 0.22),
                                      (0.78, 0.26, 0.30))):
        parts.append(brushkit.block("sc_stock_%d" % j, (bw, 0.22, bh),
                                    (dx, 0.22, 1.35 + bh / 2.0)))
    parts += _signboard("sc")
    return parts, _sign_lamp("sc"), (w + 0.24, d + 0.40, 2.46), "sc"


def archive_terminal():
    """ECHO ARCHIVE. A reading station, not a shop.

    Same counter bones so the two read as the same institution's furniture,
    and then everything above the counter is different: a raked reading
    surface, a card-index bank, and a screen. Where the shop has stock, this
    has records.
    """
    w, d, h = 2.4, 1.0, 1.4
    parts, top = _station_body("at", w, d, h)
    parts += [
        # A raked reading surface on the counter.
        brushkit.wedge("at_rake", (w - 0.30, 0.44, 0.22),
                       (0.0, -0.16, top + 0.11), axis="y", rotation_z=180.0),
        # The index bank behind it: drawers, in a grid, because an archive
        # is the most ordered object in the room.
        brushkit.block("at_bank", (w, 0.34, 1.16), (0.0, 0.28, 1.58)),
    ]
    for row in range(4):
        for col in range(6):
            parts.append(brushkit.block(
                "at_drawer_%d_%d" % (row, col), (0.32, 0.05, 0.20),
                (-w / 2.0 + 0.22 + col * 0.39, 0.10, 1.14 + row * 0.28)))
    parts.append(brushkit.block("at_hood", (w + 0.14, 0.42, 0.18),
                                (0.0, 0.22, 2.26)))
    parts += _signboard("at")
    return parts, _sign_lamp("at"), (w + 0.24, d + 0.40, 2.46), "at"


def abandon_station():
    """The only way out of GENERATING and ZONE_READY.

    `hub.gd` gives it a 1.0 x 1.3 x 1.0 box and a red glow, and the red is
    the point: this is the one control in the Hub that throws work away. It
    gets a HAZARD-striped body, a hinged cover over the switch, and nothing
    else -- a console with options on it would be a console you might press
    by accident.
    """
    w, d, h = 1.0, 1.0, 1.3
    parts = [
        brushkit.block("ab_body", (w, d * 0.9, 0.86), (0.0, 0.0, 0.43)),
        brushkit.wedge("ab_face", (w, 0.34, 0.30), (0.0, -0.26, 1.00),
                       axis="y", rotation_z=180.0),
        brushkit.block("ab_plinth", (w + 0.12, d, 0.10), (0.0, 0.0, 0.05)),
        # The cover, hinged up and back off the switch.
        # 1.09, not 1.16. hub.gd's collider is 1.0 x 1.3 x 1.0 and a
        # fixture taller than its own collider is one the player walks
        # through the top of.
        brushkit.block("ab_hinge", (0.44, 0.08, 0.08), (0.0, 0.02, 1.09)),
    ]
    cover = brushkit.block("ab_cover", (0.42, 0.30, 0.05), (0.0, -0.12, 1.14))
    parts.append(brushkit.spin(cover, "X", -52.0))
    # A guard rail either side of the switch face.
    for side in (-1.0, 1.0):
        parts.append(brushkit.block("ab_guard_%d" % int(side),
                                    (0.07, 0.26, 0.34),
                                    (side * (w / 2.0 - 0.06), -0.22, 1.05)))
    # The switch itself is the lit part.
    lit = brushkit.block("ab_switch", (0.26, 0.10, 0.12), (0.0, -0.34, 0.99))
    return parts, lit, (w + 0.12, d + 0.30, 1.30), "ab"


def _board(prefix, width, height, name):
    """A wall board: a frame and a recess, and nothing inside it.

    The contents belong to the game. The campaign board's cells carry
    `SourceIdentity` tints derived from the actual multiworld, and the
    controls board carries text that changes with the build. Baking either
    would produce an asset that is wrong the first time the data moves, and
    `AUTHORED_CONTENT.md` is explicit that derived state stays derived.
    """
    depth = 0.12
    parts = [
        brushkit.block(prefix + "_plate", (width, depth, height),
                       (0.0, 0.0, 0.0)),
        brushkit.frame(prefix + "_frame", (width, height), 0.10, 0.16,
                       (0.0, -(depth / 2.0 + 0.02), 0.0)),
        # A title rail above the opening: where hub.gd puts its Label3D.
        brushkit.block(prefix + "_rail", (width + 0.16, depth + 0.14, 0.22),
                       (0.0, -0.05, height / 2.0 + 0.18)),
        # A lamp hood over it. Boards in this facility are lit from above,
        # which is also why nothing on them needs to emit.
        brushkit.wedge(prefix + "_hood", (width * 0.8, 0.26, 0.14),
                       (0.0, -0.16, height / 2.0 + 0.36), axis="y"),
    ]
    for side in (-1.0, 1.0):
        parts.append(brushkit.block(prefix + "_stile_%d" % int(side),
                                    (0.14, depth + 0.10, height + 0.30),
                                    (side * (width / 2.0 + 0.07), -0.03, 0.0)))
    return common.join(parts, name)


def lab_doorway():
    """The opening in the -X wall the Echo Lab is through.

    `hub.gd` cuts a 3.0 x 3.2 m hole and hangs a sign by it. A hole in a
    wall is not a doorway; this is the lining, head and jambs that make it
    one, plus the deck nosing at the threshold.
    """
    w, h = LAB_DOOR_W, LAB_DOOR_H
    parts = [
        brushkit.block("ld_head", (w + 0.90, 0.62, 0.46), (0.0, 0.0, h + 0.23)),
        brushkit.block("ld_lintel", (w + 0.40, 0.74, 0.16), (0.0, 0.0, h + 0.08)),
        brushkit.block("ld_nosing", (w + 0.20, 0.70, 0.06), (0.0, 0.0, 0.03)),
    ]
    for side in (-1.0, 1.0):
        parts.append(brushkit.block("ld_jamb_%d" % int(side),
                                    (0.45, 0.62, h),
                                    (side * (w / 2.0 + 0.22), 0.0, h / 2.0)))
        # A rubbing strip at shoulder height: people carry things through.
        parts.append(brushkit.block("ld_strip_%d" % int(side),
                                    (0.50, 0.68, 0.10),
                                    (side * (w / 2.0 + 0.22), 0.0, 1.30)))
    return common.join(parts, "hub_lab_doorway")


# ----------------------------------------------------------------------
# build
# ----------------------------------------------------------------------

_IMAGES = {}


def _theme_image(role):
    """One shared image per role, painted once and reused. Same treatment
    the architecture kit uses, so a Hub wall and a Zone wall are the same
    surface rather than two paintings of the same idea."""
    if role not in _IMAGES:
        canvas, _ = materials.paint(THEME, role)
        _IMAGES[role] = canvas.to_blender("hub_%s_%s" % (THEME, role))
    return _IMAGES[role]


def _finish_arch(obj, name, role, anchor):
    common.uv_project_world(obj, ARCH_DENSITY, ARCH_SIZE)
    common.assign(obj, common.make_textured_material(
        name, _theme_image(role), roughness=pal.roughness(THEME)))
    common.set_origin(obj, anchor)
    return common.export_glb(obj, "batch003/architecture/%s.glb" % name,
                             "architecture_module", anchor=anchor)


def _finish_fixture(name, parts, lit, box, prefix, kind, lit_family,
                    saturation=0.45):
    body = common.join(parts, name + "_body")
    common.uv_project_world(body, propkit.PROP_DENSITY, propkit.PROP_SIZE)
    common.assign(body, common.make_textured_material(
        name + "_body",
        propkit.machine_bank(THEME, name, kind).to_blender(name + "_tex"),
        roughness=pal.roughness(THEME)))
    common.assign(lit, common.make_signal_material(
        name + "_lit", pal.universal(lit_family, 0),
        pal.universal(lit_family, 3), saturation=saturation))
    obj = common.join([body, lit], name)
    common.set_origin(obj, "floor")
    common.assert_fits(obj, name, box,
                       "hub.gd gives this fixture a %.2f x %.2f x %.2f m "
                       "envelope, and a fixture outside it blocks a route "
                       "the player is expected to walk." % box)
    return common.export_glb(obj, "batch003/hub/%s.glb" % name,
                             "interactable", check_flat=False)


def main():
    common.reset_scene()
    report = {}

    # --- architecture ---------------------------------------------------
    arch = {}
    # TRIM, not accent. Painted from the accent ramp the band came out as
    # a steel-blue stripe running round all four walls at the 4 m line --
    # a hundred square metres of the colour whose whole job is to mark a
    # thing as significant. That is the Batch 001 "accent carrying too
    # much" failure at room scale. Ducts and conduit are structure, and
    # structure wears trim.
    arch["arch_wall_upper"] = _finish_arch(
        wall_upper(), "arch_wall_upper", "trim", "floor")
    arch["arch_pilaster"] = _finish_arch(
        pilaster(), "arch_pilaster", "trim", "floor")

    # --- the two stations -----------------------------------------------
    # `signal` teal, because a station is an interactable and the palette
    # says interactables wear signal. The shop is not special-cased: a
    # yellow shop sign would be the `send` family, which means "this leaves
    # for the multiworld", and a shop is not that.
    parts, sign, box, prefix = shop_counter()
    report["hub_shop_counter"] = _finish_fixture(
        "hub_shop_counter", parts, sign, box, prefix, "rack", "signal")

    parts, sign, box, prefix = archive_terminal()
    report["hub_archive_terminal"] = _finish_fixture(
        "hub_archive_terminal", parts, sign, box, prefix, "console", "signal")

    # --- the abandon console --------------------------------------------
    # HAZARD, and the only place in the Hub that wears it. Orange is the
    # telegraph colour -- what is about to happen -- and throwing away a
    # generated Zone is the one thing in this room that is about to happen
    # to you rather than for you.
    parts, lit, box, prefix = abandon_station()
    report["hub_abandon_station"] = _finish_fixture(
        "hub_abandon_station", parts, lit, box, prefix, "panel", "hazard",
        saturation=0.55)

    # --- boards and doorway ---------------------------------------------
    for name, width, height, role in (
            ("hub_campaign_board", 5.2, 2.6, "trim"),
            ("hub_controls_board", 4.0, 2.4, "trim")):
        obj = _board(name.split("_")[1][:2], width, height, name)
        common.uv_project_world(obj, ARCH_DENSITY, ARCH_SIZE)
        common.assign(obj, common.make_textured_material(
            name, _theme_image(role), roughness=pal.roughness(THEME)))
        common.set_origin(obj, "centre")
        report[name] = common.export_glb(
            obj, "batch003/hub/%s.glb" % name, "architecture_module",
            anchor="centre")

    # Into the ARCHITECTURE manifest, because that is where its .glb goes.
    # It landed in the hub manifest first, which left a family listing an
    # asset stored in another family's directory -- a small lie, and exactly
    # the kind a checker cannot see because both files exist.
    arch["hub_lab_doorway"] = _finish_arch(
        lab_doorway(), "hub_lab_doorway", "wall", "floor")

    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch003",
                       "architecture", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(arch, handle, indent=2, sort_keys=True)
        handle.write("\n")
    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch003",
                       "hub", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")


if __name__ == "__main__":
    main()
