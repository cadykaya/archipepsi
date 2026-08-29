"""Batch 022 -- PROPOSAL: the navigation language.

    .tools/blender/blender -b --python tools/blender/build_navigation.py

Not production. This proposes a language that does not exist yet, and it
stays PENDING until the owner rules on it.

## What the engine already does, which shrank this batch

`zone_controller._process` already answers which objective, how far, and
what state, in the HUD:

    hud.set_waypoint(pos,  "CHECK 042 - SENDING", Color(1.0, 0.9, 0.4))
    hud.set_waypoint(pos,  "CHECK 042 - READY",   Color(0.45, 1.0, 0.9))
    hud.set_waypoint(pos,  "CHECK 042",           Color(0.72, 0.78, 0.85))
    hud.set_waypoint(exit, "EXIT",                Color(0.5, 1.0, 0.6))
    hud.set_objective_text("CHECKS %d/%d CLAIMED")

It picks the nearest actionable Check, ranks available over locked, and
falls through to the exit portal once every Check is confirmed.

A world objective-marker system would be a second, worse copy of that.
What the HUD cannot answer is the two questions asked while walking:

    which way from HERE   a screen-space arrow points through walls and
                          cannot say which of the two doors ahead it means
    what IS this place    the HUD names the Check, never the room

Those two are the whole world-side gap. This batch is that and no more.

## Why the language carries no hue

Every saturated hue is already spoken for:

    HUD sending   amber   1.00, 0.90, 0.40
    HUD READY     cyan    0.45, 1.00, 0.90
    HUD locked    grey    0.72, 0.78, 0.85
    HUD EXIT      green   0.50, 1.00, 0.60
    hazard        orange  #e8541f   "this will hurt you"
    signal        teal    #39d7c8   "this is a capability"
    identity      green   #57ff1f   "Epsilon"
    send          amber   #ffd45c   "this leaves for the multiworld"

There is no hue left. That is arithmetic, not taste. So this family has
no colour of its own and reads by form, value, placement and
orientation. It is made of the theme's own trim, with one high-value
neutral face for runtime text to sit against.

The owner's rule is the test: a player must never have to tell Epsilon
green from EXIT green, or affordance cyan from READY cyan, by colour.
A sign that is only form cannot fail that test.

## One family, four configurations

Same 0.06 m plate, same chamfer, same bracket language, so a doorway and
a junction read as the same building's signage.

    nav_blade     perpendicular to the wall, read ALONG a corridor from
                  both directions. The junction piece.
    nav_panel     flush above a threshold. The destination piece: what is
                  through here.
    nav_chevron   direction as a folded fin. Not a painted arrow and not
                  a glowing one: it reads by the shadow in its own fold,
                  which survives six themes because it is a shape.
    nav_hanger    the ceiling-hung blade, for a junction with no wall
                  near enough to carry one.

## Runtime text, not baked text

Every face is a blank recessed field. `chamber_builders` already uses
`Label3D` in three places and `hub.gd` feeds the campaign board the same
way. Room names, a Zone number, a bearing: all runtime data. Baking it
into a mesh would make one sign that says one thing forever.
"""

from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import brushkit  # noqa: E402
import common  # noqa: E402
import materials  # noqa: E402
import palette as pal  # noqa: E402

#: A signage family that exists in one theme is not a six-theme system.
#: Every module is built once per theme and wears that theme's own trim,
#: which is the claim the review sheet has to be able to test.
THEMES = ("concrete_facility", "rusted_industrial", "neon_transit",
          "gothic_stone", "temple_ruin", "void_glitch")
OUT = "batch022/navigation"

#: Set per build pass. The module-level default keeps the helpers readable
#: and every builder below theme-agnostic.
THEME = THEMES[0]

DIM = common.DIM
DOOR_W = DIM["door_width"]
DOOR_H = DIM["door_height"]

#: The signage is made of the building's trim, so it keeps the
#: architecture's 4 m tile and simply samples it twice as finely: same
#: world scale, prop tier. Changing the tile instead would break tiling
#: against the wall the sign is bolted to.
PROP_DENSITY = pal.budgets()["texel_density"]["prop"]["target"]
PROP_SIZE = 256
PROP_METRES = PROP_SIZE / float(PROP_DENSITY)

#: One plate thickness for all four configurations, so a blade and a
#: panel read as the same manufacturer.
PLATE = 0.06

#: The high-value neutral a runtime Label3D sits against. Deliberately
#: NOT a palette family: navigation carries no hue of its own, because
#: every saturated hue already means something else.
FACE_HEX = "#c9ced6"
FACE_ROUGH = 0.62

#: Recessed fields and the arrowhead sit on Blender +Y, which the glTF
#: export maps to Godot -Z -- the side a player approaches from. The first
#: pass put them on -Y and every inset field rendered on the BACK of its
#: own sign: the chevrons read as plain trim blocks in the room shots
#: because their pale ground and their glyph were both facing the wall.
#:
#: The ink. The runtime `Label3D` draws its text near-black on the pale
#: field, and the arrowhead is the same ink in three dimensions -- a glyph
#: that happens to be pressed rather than printed. Same contrast, same
#: rule, so a sign reading "STAIR C ->" is one typographic object and not
#: a plate with a lump on it.
INK_HEX = "#171a1f"

_IMAGES = {}


def _image(role):
    key = (THEME, role)
    if key not in _IMAGES:
        canvas, _ = materials.paint(THEME, role, size=PROP_SIZE,
                                    metres=PROP_METRES)
        _IMAGES[key] = canvas.to_blender("nav_%s_%s" % (THEME, role))
    return _IMAGES[key]


def _paint(obj, name, role):
    common.assign(obj, common.make_textured_material(
        "%s_%s_%s" % (name, THEME, role), _image(role),
        roughness=pal.roughness(THEME)))
    return obj


def _ink(obj, name):
    """The dark glyph value: arrowheads, and anything else that must read
    as MARKING rather than as structure."""
    common.assign(obj, common.make_material(
        "%s_%s_ink" % (name, THEME), INK_HEX, roughness=0.48))
    return obj


def _face(obj, name):
    """The blank field a runtime Label3D is drawn against.

    Flat, high-value, unlit, untextured. It is a surface for text to have
    contrast against and nothing else. A hue here would compete with four
    HUD colours and three universal families.
    """
    common.assign(obj, common.make_material(
        "%s_%s_face" % (name, THEME), FACE_HEX, roughness=FACE_ROUGH))
    return obj


def _arrow(name, at, span=0.52, thick=0.085, point=1.0):
    """The directional element: a real arrowhead, not a fold.

    The first pass built this as two wedges meeting in a shallow V, on the
    theory that the shadow in the fold would carry the direction. Rendered
    at eye height in a corridor it read as a peak -- a mountain, or the
    letter A -- and said nothing about which way to go. A thing that must
    mean "left" cannot be symmetrical about the axis it is describing.

    So it is an arrowhead on a short shaft: a three-sided prism laid into
    the vertical plane, apex along +/-X. That is a silhouette, which means
    it survives darkness, distance, a greyscale check and a player who
    cannot separate hues -- none of which a shadow in a fold survives.

    `point` is +1 for an arrow that points +X and -1 for -X.
    """
    head_r = span * 0.33
    head_x = at[0] + point * (span * 0.5 - head_r)
    head = brushkit.prism(
        "%s_head" % name, head_r, thick, 3,
        (head_x, at[1], at[2]),
        rotation_z=180.0 if point > 0.0 else 0.0,
        asset_name=name)
    # The prism extrudes along Z; the arrow has to live in the wall plane,
    # so lay it on its side and the extrusion becomes the thickness.
    brushkit.spin(head, "x", 90.0)
    shaft = brushkit.block(
        "%s_shaft" % name, (span * 0.42, thick, span * 0.20),
        (at[0] - point * (span * 0.29), at[1], at[2]))
    return [head, shaft]


def nav_blade():
    """A blade projecting across a corridor, read along the run both ways.

    The junction piece. A flush plate is invisible edge-on to someone
    walking toward it, which is exactly when a junction sign is needed,
    so the blade turns perpendicular to the wall and presents a face to
    each approach.

    The head sits at 2.60 m: clear of the tallest actor, and below
    `reach_standing` so it never reads as something to grab. The face is
    0.78 m, not the 1.30 m it started at: `corridor_width_min` is 4.0 m,
    and the first pass put two opposing blades 0.48 m apart -- narrower
    than `player_diameter`. A sign that only fits in wide corridors is not
    a system either.

    It carries NO arrow. The first pass baked one into the blade, and the
    junction render showed what that costs: a blade with an arrow in it is
    a blade that can only ever mean "right". Which way "STAIR C" lies
    depends on where the player is standing, so direction cannot be a fact
    about the mesh. `nav_chevron` carries it and is oriented at placement.
    """
    name = "nb"
    span, height = 0.78, 0.36
    head = 2.60
    mid = head - height / 2.0
    parts = [
        _face(brushkit.block("%s_face" % name, (span, PLATE, height),
                             (0.0, 0.0, mid)), name),
        _paint(brushkit.block("%s_cap" % name,
                              (span + 0.08, PLATE + 0.06, 0.07),
                              (0.0, 0.0, head - 0.035)), name, "trim"),
        _paint(brushkit.block("%s_sill" % name,
                              (span + 0.08, PLATE + 0.06, 0.07),
                              (0.0, 0.0, head - height + 0.035)),
               name, "trim"),
        _paint(brushkit.block("%s_arm" % name, (0.34, 0.16, 0.16),
                              (-(span / 2.0 + 0.17), 0.0, head + 0.08)),
               name, "trim"),
        _paint(brushkit.block("%s_boss" % name, (0.14, 0.30, 0.30),
                              (-(span / 2.0 + 0.28), 0.0, mid)),
               name, "trim"),
    ]
    return common.join(parts, "nav_blade")


def nav_panel():
    """A panel BESIDE a threshold: WHAT is through here.

    It was authored over the door first, and the manifest caught that:
    `door_height` 3.2 under `corridor_height` 3.6 leaves 0.40 m of wall
    above a doorway, and a legible panel is taller than that. A sign that
    only fits in rooms with unusually high ceilings is not a system.

    So it sits beside the jamb instead, centred just above eye height --
    which is where a real facility puts a room plate, and which asks the
    player to look FORWARD rather than up. That also widens the gap to the
    blade: overhead means "that way", at eye height means "this is here".
    """
    name = "np"
    width, height = 0.94, 0.42
    z = 1.78
    parts = [
        _paint(brushkit.block("%s_back" % name, (width, PLATE, height),
                              (0.0, 0.0, z)), name, "trim"),
        _face(brushkit.block("%s_field" % name,
                             (width - 0.13, 0.10, height - 0.13),
                             (0.0, PLATE / 2.0 + 0.05, z)), name),
    ]
    for side in (-1.0, 1.0):
        parts.append(_paint(brushkit.block(
            "%s_stile_%d" % (name, int(side)),
            (0.07, 0.13, height + 0.12),
            (side * (width / 2.0 - 0.035), 0.0, z)), name, "trim"))
    parts.append(_paint(brushkit.block(
        "%s_hood" % name, (width + 0.10, 0.19, 0.07),
        (0.0, 0.0, z + height / 2.0 + 0.035)), name, "trim"))
    return common.join(parts, "nav_panel")


def nav_chevron():
    """Direction, as its own module.

    Proportioned to the blade face -- same height, same plate, same cap
    and sill -- so it butts against a blade end and the two read as one
    sign rather than as a sign with something stuck to it. That is what
    makes this a modular family instead of four unrelated objects:
    [<-][WEST WING] and [PUMP HALL][->] are the same two parts, ordered by
    which way the branch runs.

    The arrowhead is INK on the pale field, not trim on trim. The first
    pass painted it the same material as its own plate and the render was
    unambiguous: same value, same texture, so it read as a dark lump and
    carried no direction at all. Contrast is what makes a glyph a glyph.

    The second pass fixed the material and still read as a block, for a
    duller reason: a 0.20 m arrow on a 0.22 m field leaves a 10 mm pale
    margin, and at any real distance the margin disappears and the glyph
    becomes its own bounding box. A mark needs the ground around it as
    much as it needs contrast against it. The plate is wider now so the
    arrow can have air.

    It also stands alone, on a wall, where a corner needs only "that way".

    Not a glowing arrow. DESIGN 3.4 argues this is a 1998 building, and a
    1998 building signs a turn with a pressed piece of metal.
    """
    name = "nc"
    width, height = 0.44, 0.36
    parts = [
        _paint(brushkit.block("%s_plate" % name, (width, PLATE, height),
                              (0.0, 0.0, 0.0)), name, "trim"),
        _face(brushkit.block("%s_field" % name,
                             (width - 0.08, 0.09, height - 0.10),
                             (0.0, PLATE / 2.0 + 0.045, 0.0)), name),
        _paint(brushkit.block("%s_cap" % name,
                              (width + 0.07, PLATE + 0.05, 0.06),
                              (0.0, 0.0, height / 2.0 - 0.03)), name, "trim"),
        _paint(brushkit.block("%s_sill" % name,
                              (width + 0.07, PLATE + 0.05, 0.06),
                              (0.0, 0.0, -height / 2.0 + 0.03)), name, "trim"),
    ]
    parts += [_ink(p, name) for p in _arrow(
        "%s_ar" % name, (0.0, PLATE / 2.0 + 0.10, 0.0), span=0.22,
        thick=0.045)]
    return common.join(parts, "nav_chevron")


def nav_hanger():
    """The ceiling-hung blade, for a junction with no wall to carry one.

    Same face, same caps, same chevron as `nav_blade`, so it reads as the
    same asset. What changes is that it arrives from above on two drop
    rods.

    Hung above `reach_standing` so nothing the player does reaches it,
    and clear beneath the corridor ceiling.
    """
    name = "nh"
    span, height = 1.02, 0.36
    top = 2.93
    mid = top - height / 2.0
    parts = [
        _face(brushkit.block("%s_face" % name, (span, PLATE, height),
                             (0.0, 0.0, mid)), name),
        _paint(brushkit.block("%s_cap" % name,
                              (span + 0.08, PLATE + 0.06, 0.07),
                              (0.0, 0.0, top - 0.035)), name, "trim"),
        _paint(brushkit.block("%s_sill" % name,
                              (span + 0.08, PLATE + 0.06, 0.07),
                              (0.0, 0.0, top - height + 0.035)),
               name, "trim"),
    ]
    for side in (-1.0, 1.0):
        x = side * (span / 2.0 - 0.22)
        parts.append(_paint(brushkit.block(
            "%s_rod_%d" % (name, int(side)), (0.05, 0.05, 0.62),
            (x, 0.0, top + 0.31)), name, "trim"))
        parts.append(_paint(brushkit.block(
            "%s_boss_%d" % (name, int(side)), (0.13, 0.13, 0.10),
            (x, 0.0, top + 0.05)), name, "trim"))
    return common.join(parts, "nav_hanger")


#: Every configuration exports with `module_floor`, which centres X/Y and
#: LEAVES Z ALONE. That is deliberate. A sign's height is part of what the
#: sign IS -- a blade head at 2.60 m is a decision about where a reader's
#: eye goes, the same way `common.set_origin` keeps a pipe run at 2.55 m.
#: Re-basing to the lowest point would throw that away and put the whole
#: family on the floor.
#:
#: `mount` is the face that bolts to the building, which is NOT the same
#: for all four: a blade hangs off its bracket arm on -X, a panel and a
#: chevron sit flush on -Y, and a hanger arrives from above.
MODULES = [
    (nav_blade, "module_floor", "-x"),
    (nav_panel, "module_floor", "-y"),
    (nav_chevron, "module_floor", "-y"),
    (nav_hanger, "module_floor", "+z"),
]


#: Label3D advance per character, as a fraction of `font_size * pixel_size`.
#: Measured from the review renders rather than assumed: it is what turns a
#: field width in metres into a character budget runtime can respect.
_CHAR_ADVANCE = 0.62


def _face_field(obj):
    """The pale field's extent, and the character budget it implies.

    Returned as manifest keys so neither a scene nor the runtime has to
    guess where a sign's text belongs or how long it may be.
    """
    face_slots = {i for i, m in enumerate(obj.data.materials)
                  if m is not None and m.name.endswith("_face")}
    if not face_slots:
        return {}
    xs, zs = [], []
    for poly in obj.data.polygons:
        if poly.material_index in face_slots:
            for vi in poly.vertices:
                co = obj.matrix_world @ obj.data.vertices[vi].co
                xs.append(co.x)
                zs.append(co.z)
    if not xs:
        return {}
    width = max(xs) - min(xs)
    # 88% of the field, so a glyph keeps the ground around it that L-65 was
    # written about. The same rule that applies to the arrowhead applies to
    # a word.
    usable = width * 0.88
    return {
        "face_centre_x_m": round((min(xs) + max(xs)) / 2.0, 3),
        "face_centre_z_m": round((min(zs) + max(zs)) / 2.0, 3),
        "face_width_m": round(width, 3),
        "face_height_m": round(max(zs) - min(zs), 3),
        "text_usable_width_m": round(usable, 3),
        # At the review sheets' 0.0032 m pixel size and font size 22.
        "text_max_chars_at_22px": int(
            usable / (22 * 0.0032 * _CHAR_ADVANCE)),
    }


def main():
    global THEME
    report = {}
    for theme in THEMES:
        THEME = theme
        # Per theme, not once: Blender dedupes object names against what is
        # already in the scene, so a second pass over the same four builders
        # exported nav_blade.001.glb ... nav_blade.005.glb. The image cache
        # holds datablocks the reset frees, so it goes with it.
        common.reset_scene()
        _IMAGES.clear()
        for builder, anchor, mount in MODULES:
            obj = builder()
            name = obj.name
            common.set_origin(obj, anchor)
            common.uv_project_world(obj, PROP_DENSITY, PROP_SIZE)
            entry = common.export_glb(
                obj, "%s/%s/%s.glb" % (OUT, theme, name), "prop",
                tier="prop", texture_size=PROP_SIZE, anchor=anchor,
                check_flat=False)
            # The chevron is the one configuration with no text field: it
            # is pure direction, so there is nothing for runtime to write.
            entry["carries_runtime_label"] = name != "nav_chevron"
            entry["face_hex"] = FACE_HEX
            entry["mount_face"] = mount
            entry["theme"] = theme
            # The authored height, so a scene places the sign by reading
            # this rather than repeating a number that lives in the builder.
            zs = [(obj.matrix_world @ v.co).z for v in obj.data.vertices]
            entry["authored_top_m"] = round(max(zs), 3)
            entry["authored_bottom_m"] = round(min(zs), 3)
            # Where the runtime text actually goes, and how much of it
            # fits. The blade's bracket hangs off -X, so its FACE centre
            # is not its MESH centre -- the first review sheets placed
            # text at the mesh centre and it sat 0.2 m left of the field
            # it was supposed to be inside, overrunning the frame. A
            # renderer cannot infer this; it belongs in the manifest,
            # the same way `authored_top_m` does.
            entry.update(_face_field(obj))
            # Keyed as a plain identifier, not "<theme>/<name>": the
            # docs-metrics checker matches manifest keys against ids
            # quoted in the owner's ledger, and a slash is not one.
            report["%s_%s" % (name, theme)] = entry
    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch022",
                       "navigation", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
    print("[art] batch022 manifest -> %s (%d entries)" % (out, len(report)))


if __name__ == "__main__":
    main()
