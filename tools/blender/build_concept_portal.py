"""Batch 001 C -- two portal-frame concepts.

    .tools/blender/blender -b --python tools/blender/build_concept_portal.py

The portal is where authored content meets generated content, literally: the
engine "automatically appends an exit portal after the final chamber"
(DESIGN 14.1), so this object always stands at the seam between a room
Epsilon composed and the Hub a human built. Both concepts are about that
seam.

**Silhouette and scale, not effects.** The brief says so and the engine
agrees -- `exit_portal.gd` already drives a core material through four
states and the art does not need to compete with it. What the frame has to
do is be recognisable as a way out from the far end of a 30 m corridor, and
be obviously more permanent than the room around it.

`exit_portal.gd` gives it a 3.0 x 4.0 x 1.0 m collision box and builds a
3.2 x 4.2 x 0.6 m frame. Those are Godot's.
"""

from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import brushkit  # noqa: E402
import common  # noqa: E402
import propkit  # noqa: E402
import palette as pal  # noqa: E402

THEME = "concrete_facility"
#: The binding width is NOT exit_portal.gd's 3.2 m frame -- an authored
#: portal replaces that frame, so it may be wider. It is the narrowest
#: corridor Epsilon may ask for: `zone.py` bounds corridor width at 4.0 m,
#: and a portal wider than 3.6 m leaves under 200 mm of wall each side and
#: clips through it. Height is bounded by CORRIDOR_HEIGHT, which is 3.6 m --
#: so a portal taller than that only fits an arena, and both concepts are
#: built under it plus the arena's headroom.
PORTAL_BOX = (3.6, 1.3, 4.6)
APERTURE = (2.4, 3.4)


def _emissive(name, family="identity", saturation=0.45):
    return common.make_signal_material(name, pal.universal(family, 0),
                                       pal.universal(family, 3),
                                       saturation=saturation, roughness=0.35)


def concept_a_blast():
    """A: BLAST FRAME.

    A manufactured pressure door surround: rams, a lintel beam, hazard
    trim. Its bet is that the exit is EQUIPMENT -- the most legible reading
    at distance, and the one that says most clearly "this was installed
    here", which is what a seam between authored and generated wants.
    """
    # 0.45, down from the 0.9-plus this was authored at.
    # `make_signal_material` solves so the AUTHORED sum stays under 1.0; the
    # renderer then tonemaps and sRGB-encodes on top of that, which lifts
    # everything. A five-bar sweep through the review bench put the clip
    # point between 0.40 and 0.60: above it the green channel pins at 255
    # and the hue walks toward yellow, which is the TELEGRAPH colour. A
    # green cue that renders orange inverts the rule the whole palette is
    # built on. See build_epsilon_installation.py for the sweep.
    width, height = APERTURE
    parts = [
        brushkit.frame("cpa_frame", (width + 0.72, height + 0.60), 0.36, 0.72,
                       (0.0, 0.0, (height + 0.60) / 2.0)),
        brushkit.block("cpa_lintel", (width + 0.94, 0.86, 0.36),
                       (0.0, 0.0, height + 0.72)),
        brushkit.wedge("cpa_hood", (width + 0.94, 0.60, 0.30),
                       (0.0, -0.16, height + 1.05), axis="y",
                       rotation_z=180.0),
        brushkit.block("cpa_sill", (width + 0.90, 0.90, 0.18),
                       (0.0, 0.0, 0.09)),
    ]
    # Rams: the parts that say this thing MOVES, which is what separates a
    # door from a hole.
    for side in (-1.0, 1.0):
        x = side * (width / 2.0 + 0.42)
        parts.append(brushkit.prism("cpa_ram_%d" % int(side), 0.15, 2.10, 8,
                                    (x, -0.40, 1.35),
                                    asset_name="portal_a"))
        parts.append(brushkit.prism("cpa_rod_%d" % int(side), 0.07, 0.90, 8,
                                    (x, -0.40, 2.85),
                                    asset_name="portal_a"))
        parts.append(brushkit.block("cpa_shoe_%d" % int(side),
                                    (0.30, 0.34, 0.22), (x, -0.40, 0.20)))
        parts.append(brushkit.block("cpa_yoke_%d" % int(side),
                                    (0.30, 0.50, 0.20), (x, -0.28, 3.32)))
    band = brushkit.block("cpa_band", (width + 0.60, 0.10, 0.16),
                          (0.0, -0.40, height + 0.36))
    return parts, band


def concept_b_collar():
    """B-R: THE BREACH. Selected as the direction at Batch 001, then revised.

    The review: B is the better foundation because it reads as heavier
    equipment integrated *around* an opening, and the concept should be
    pushed toward *"something has happened to / opened through the
    architecture"* rather than *"special doorway frame"*.

    It also has to carry the clarified Epsilon contrast: facility side is
    cold human structure, the active edge is an alien intrusion forcing
    itself into old infrastructure.

    So the object is now three materials rather than two, and the split is
    the concept:

    * **facility** -- the ragged stepped jambs and the spalled head. Cold
      grey, the theme's own paint, obviously the building.
    * **alien** -- an irregular collar that has grown around the aperture
      from the inside, plated at Epsilon's own tighter pitch and veined
      green. It is not fitted to the hole, it has taken it.
    * **cores** -- green shards embedded where the two meet, so the seam
      between them is where the light comes from.

    The dead-state requirement is met by geometry, not by effects: the
    ragged breach, the asymmetric collar and the four anchor spikes are all
    still there with every emissive surface off. The review was explicit
    that future particles must not be relied on for recognition.
    """
    width, height = APERTURE
    facility = []
    # Ragged structural jambs: no two steps the same thickness. This is the
    # building, broken.
    steps = ((0.46, 0.0, 0.9), (0.34, 0.9, 1.9), (0.50, 1.9, 2.7),
             (0.30, 2.7, 3.5), (0.44, 3.5, height + 0.5))
    for side in (-1.0, 1.0):
        for i, (thick, z0, z1) in enumerate(steps):
            # Stagger one side against the other: a breach is not symmetric.
            shift = 0.0 if side < 0 else 0.11
            facility.append(brushkit.block(
                "cpb_jamb_%d_%d" % (int(side), i),
                (thick, 1.00, (z1 - z0) + shift),
                (side * (width / 2.0 + thick / 2.0), 0.0,
                 (z0 + z1) / 2.0 + shift * 0.5)))
    facility.append(brushkit.block("cpb_head", (width + 1.10, 1.00, 0.62),
                                   (0.0, 0.0, height + 0.31)))
    facility.append(brushkit.wedge("cpb_spall", (width + 0.60, 0.70, 0.34),
                                   (0.0, -0.20, height + 0.79), axis="y"))
    facility.append(brushkit.block("cpb_step", (width + 0.20, 1.10, 0.16),
                                   (0.0, -0.20, 0.08)))
    # Rubble at the foot: material came OUT of this wall.
    for i, (dx, dy, sz, rot) in enumerate(
            ((-1.42, -0.52, 0.30, 24.0), (1.30, -0.44, 0.24, -51.0),
             (-1.05, -0.62, 0.19, 63.0), (1.55, -0.30, 0.16, 12.0))):
        facility.append(brushkit.block("cpb_rubble_%d" % i,
                                       (sz, sz * 0.8, sz * 0.7),
                                       (dx, dy, sz * 0.35), rotation_z=rot))

    # The alien collar. Irregular, uneven, gripping the opening.
    alien = []
    seg = ((0.28, 0.20), (0.19, 0.34), (0.31, 0.16), (0.22, 0.26))
    for side in (-1.0, 1.0):
        for i, (w, d) in enumerate(seg):
            z = 0.55 + i * (height / len(seg))
            alien.append(brushkit.block(
                "cpb_grip_%d_%d" % (int(side), i), (w, d, height / len(seg) * 0.82),
                (side * (width / 2.0 + 0.04), -0.36 - d / 2.0 + 0.10, z)))
    alien.append(brushkit.block("cpb_lintel_grip", (width * 0.72, 0.30, 0.26),
                                (-0.14, -0.40, height + 0.02)))
    alien.append(brushkit.wedge("cpb_tongue", (0.44, 0.52, 0.30),
                                (0.62, -0.44, height - 0.34), axis="y",
                                rotation_z=200.0))
    # Anchor spikes driven into the facility stone: it is holding on.
    for i, (sx, z, ln) in enumerate(((-1.0, 1.10, 0.40), (1.0, 2.30, 0.34),
                                     (-1.0, 3.05, 0.30), (1.0, 0.62, 0.28))):
        sp = brushkit.block("cpb_spike_%d" % i, (ln, 0.13, 0.13),
                            (sx * (width / 2.0 + 0.30), -0.38, z))
        alien.append(brushkit.spin(sp, "Y", sx * 14.0))

    # Green where the two materials meet.
    cores = []
    for i, (x, z, w, h, rz) in enumerate((
            (-width / 2.0 - 0.02, 1.55, 0.10, 0.62, 6.0),
            (width / 2.0 + 0.02, 2.40, 0.10, 0.48, -9.0),
            (-0.20, height + 0.05, 0.70, 0.11, 0.0),
            (width / 2.0 + 0.02, 0.95, 0.09, 0.34, 4.0))):
        c = brushkit.block("cpb_vein_%d" % i, (w, 0.09, h), (x, -0.44, z))
        cores.append(brushkit.spin(c, "Y", rz))
    return facility, alien, cores


def concept_b2_wound():
    """B-2: THE BREACH, pushed. Batch 002 item 3.

    The 001-R review kept the direction and asked for one thing:

    > Continue pushing the same contrast: human architecture + alien
    > intrusion.

    B-R had the split as three materials on a broadly symmetric frame. Three
    things are different here, and each of them is the same idea applied
    harder:

    **The wall is present.** B-R showed a hole with jambs. You cannot see a
    breach without seeing what was breached, so B-2 stands in a piece of
    intact facility wall -- panels, a base course, a bolted architrave, a
    proper concrete lintel over the opening. The human half is now
    unmistakably a BUILDING rather than a frame, which is what gives the
    alien half something to have ruined.

    **The alien half is no longer polite.** In B-R the collar sat around the
    aperture at an even depth. Here the mass is lopsided: it piles up on one
    side to over half the aperture's width, crosses the lintel, spills onto
    the floor, and OCCLUDES part of the opening. A thing that fits neatly
    around a hole was invited; a thing that covers a third of it was not.

    **The values are inverted against the Epsilon installation, on
    purpose.** The bank in the Hub is a dark machine with a green intrusion.
    This is a PALE facility wall with a dark green-black intrusion. Both
    read the same way -- Epsilon is the thing that does not match -- and
    the difference is that a wall in this facility is pale and a mainframe
    left for decades is not. The intrusion never matches; what it fails to
    match changes.

    Dead-state still holds: with every emissive off, the wall, the ruined
    opening, the lopsided mass and the spill are all still there.
    """
    width, height = APERTURE
    facility = []
    # The wall the breach is IN. Two returns either side at full height,
    # panelled at the architecture pitch, with a base course.
    for side in (-1.0, 1.0):
        # 0.24 m out from the aperture edge, not 0.62. PORTAL_BOX caps the
        # whole object at 3.6 m across -- the narrowest corridor zone.py
        # permits is 4.0 m and a wider portal clips through its wall -- so
        # the wall returns are as wide as that budget leaves, which is what
        # decides how much building is visible either side.
        facility.append(brushkit.block(
            "cw_wall_%d" % int(side), (0.62, 0.44, height + 1.05),
            (side * (width / 2.0 + 0.24), 0.14, (height + 1.05) / 2.0)))
        facility.append(brushkit.block(
            "cw_base_%d" % int(side), (0.60, 0.52, 0.30),
            (side * (width / 2.0 + 0.24), 0.12, 0.15)))
    # A bolted architrave around the opening: the doorway that used to be
    # here, and the thing the breach tore through.
    for side in (-1.0, 1.0):
        facility.append(brushkit.block(
            "cw_arch_%d" % int(side), (0.24, 0.30, height + 0.10),
            (side * (width / 2.0 + 0.12), -0.06, (height + 0.10) / 2.0)))
    facility.append(brushkit.block("cw_lintel", (width + 0.72, 0.34, 0.34),
                                   (0.0, -0.06, height + 0.17)))
    facility.append(brushkit.block("cw_header", (width + 1.16, 0.44, 0.46),
                                   (0.0, 0.14, height + 0.62)))
    # Ragged jambs INSIDE the architrave -- the tear itself. Uneven, and
    # the left side has lost more than the right.
    steps = ((0.40, 0.0, 1.05, -1.0), (0.22, 1.05, 2.05, -1.0),
             (0.34, 2.05, 3.10, -1.0), (0.17, 3.10, height, -1.0),
             (0.26, 0.0, 0.80, 1.0), (0.38, 0.80, 2.20, 1.0),
             (0.20, 2.20, 3.35, 1.0), (0.31, 3.35, height, 1.0))
    for i, (thick, z0, z1, side) in enumerate(steps):
        facility.append(brushkit.block(
            "cw_jamb_%d" % i, (thick, 0.30, z1 - z0),
            (side * (width / 2.0 - thick / 2.0 + 0.02), -0.06,
             (z0 + z1) / 2.0)))
    facility.append(brushkit.wedge("cw_spall", (width * 0.70, 0.26, 0.30),
                                   (-0.30, -0.20, height - 0.06), axis="y",
                                   rotation_z=180.0))
    # Rubble, weighted to the side the mass came from.
    for i, (dx, dy, sz, rot) in enumerate(
            ((-1.60, -0.56, 0.34, 24.0), (-1.16, -0.66, 0.26, -51.0),
             (-0.74, -0.48, 0.19, 63.0), (1.44, -0.36, 0.17, 12.0),
             (0.96, -0.60, 0.14, -32.0))):
        facility.append(brushkit.block("cw_rubble_%d" % i,
                                       (sz, sz * 0.8, sz * 0.7),
                                       (dx, dy, sz * 0.35), rotation_z=rot))

    # The alien mass. Everything about it is lopsided.
    alien = []
    for i, (z0, z1, w, d, dx) in enumerate((
            (0.00, 1.15, 0.86, 0.62, -0.10),
            (1.15, 2.35, 0.66, 0.50, 0.06),
            (2.35, 3.30, 0.48, 0.42, -0.08),
            (3.30, height + 0.30, 0.34, 0.34, 0.04))):
        alien.append(brushkit.block(
            "cw_mass_%d" % i, (w, d, z1 - z0),
            (-width / 2.0 + w / 2.0 - 0.06 + dx, -0.34, (z0 + z1) / 2.0)))
    # It crosses the lintel and comes down the far side, but only part way:
    # the reach is unequal and that is the whole point.
    alien.append(brushkit.block("cw_span", (width * 0.86, 0.40, 0.34),
                                (-0.24, -0.36, height + 0.14)))
    alien.append(brushkit.block("cw_far", (0.32, 0.36, 1.30),
                                (width / 2.0 - 0.10, -0.34, height - 0.75)))
    # Occluding fingers ACROSS the opening. A doorway you have to step
    # around is a doorway something else owns.
    for i, (z, ln, ang) in enumerate(((1.05, 1.05, -18.0), (2.42, 0.78, 11.0),
                                      (3.20, 0.54, -27.0))):
        f = brushkit.block("cw_finger_%d" % i, (ln, 0.20, 0.18),
                           (-width / 2.0 + 0.20 + ln / 2.0, -0.40, z))
        alien.append(brushkit.spin(f, "Y", ang))
    # Spill onto the floor, out of the opening toward the player.
    for i, (dx, dy, w, d, h2, rot) in enumerate(
            # PORTAL_BOX also caps depth at 1.3 m, and a spill that runs
            # out into the corridor is the first thing to overrun it.
            ((-1.05, -0.50, 0.70, 0.62, 0.26, 17.0),
             (-0.42, -0.54, 0.50, 0.54, 0.17, -38.0),
             (-1.48, -0.50, 0.38, 0.40, 0.13, 54.0))):
        alien.append(brushkit.block("cw_spill_%d" % i, (w, d, h2),
                                    (dx, dy, h2 / 2.0), rotation_z=rot))
    # Spikes driven into the architrave: it is holding on to the building.
    for i, (sx, z, ln) in enumerate(((-1.0, 1.62, 0.46), (1.0, 2.62, 0.34),
                                     (-1.0, 3.42, 0.30), (1.0, 1.10, 0.26))):
        sp = brushkit.block("cw_spike_%d" % i, (ln, 0.14, 0.14),
                            (sx * (width / 2.0 + 0.16), -0.36, z))
        alien.append(brushkit.spin(sp, "Y", sx * 16.0))

    # Green ONLY where the two materials touch. Not on the alien mass, not
    # on the wall: on the join, which is where the story is.
    cores = []
    for i, (x, z, w, h2, rz) in enumerate((
            # Straddling the jamb line, not sitting on the mass: these two
            # were at +0.34 and +0.26 inside the aperture, which put them
            # on an alien-to-alien seam and made the claim above false.
            (-width / 2.0, 1.15, 0.34, 0.09, 0.0),
            (-width / 2.0, 2.35, 0.28, 0.09, 0.0),
            (-width / 2.0 - 0.14, 2.05, 0.09, 0.80, 5.0),
            (width / 2.0 - 0.06, 2.20, 0.09, 0.66, -7.0),
            (-0.24, height + 0.32, 0.90, 0.10, 0.0))):
        c = brushkit.block("cw_vein_%d" % i, (w, 0.09, h2), (x, -0.52, z))
        cores.append(brushkit.spin(c, "Y", rz))
    return facility, alien, cores


CONCEPTS = [
    ("portal_a_blast", concept_a_blast),
    ("portal_b_collar", concept_b_collar),
]

#: Batch 002 revisions. Separate from CONCEPTS so the 001 outputs stay
#: byte-identical: nothing the owner has already reviewed is rebuilt here.
REVISIONS = [
    ("portal_b2_wound", concept_b2_wound),
]


def _tex(name, canvas, rough):
    return common.make_textured_material(
        name, canvas.to_blender(name + "_tex"), roughness=rough)


def build_one(name, builder, batch="batch001"):
    parts = builder()
    if len(parts) == 2:
        shell_parts, band = parts
        shell = common.join(shell_parts, name + "_shell")
        common.uv_project_world(shell, propkit.HERO_DENSITY, propkit.HERO_SIZE)
        common.assign(shell, _tex(
            name + "_shell",
            propkit.hero_shell(THEME, name, "signal", label="out",
                               lit_band=False), pal.roughness(THEME)))
        common.assign(band, _emissive(name + "_band"))
        obj = common.join([shell, band], name)
    else:
        # Facility, alien, and the green where they meet.
        fac_parts, alien_parts, core_parts = parts
        fac = common.join(fac_parts, name + "_fac")
        common.uv_project_world(fac, propkit.PROP_DENSITY, propkit.PROP_SIZE)
        common.assign(fac, _tex(name + "_fac",
                                propkit.facility_host(THEME, name),
                                pal.roughness(THEME)))
        alien = common.join(alien_parts, name + "_alien")
        common.uv_project_world(alien, propkit.HERO_DENSITY, propkit.HERO_SIZE)
        common.assign(alien, _tex(name + "_alien",
                                  propkit.alien_shell(THEME, name), 0.55))
        core = common.join(core_parts, name + "_core")
        common.assign(core, _emissive(name + "_core", family="identity"))
        obj = common.join([fac, alien, core], name)

    common.set_origin(obj, "floor")
    common.assert_fits(obj, name, PORTAL_BOX,
                       "A portal wider than 3.6 m clips the wall of the "
                       "narrowest corridor zone.py permits (4.0 m).")
    return common.export_glb(obj, "%s/portal/%s.glb" % (batch, name),
                             "interactable", check_flat=False)


def _write(report, batch):
    out = os.path.join(common.REPO_ROOT, "assets", "models", batch,
                       "portal", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")


def main():
    common.reset_scene()
    report = {}
    for name, builder in CONCEPTS:
        report[name] = build_one(name, builder)
    _write(report, "batch001")
    revised = {}
    for name, builder in REVISIONS:
        revised[name] = build_one(name, builder, batch="batch002")
    _write(revised, "batch002")


if __name__ == "__main__":
    main()
