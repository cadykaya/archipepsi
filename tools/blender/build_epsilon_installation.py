"""Batch 002 -- Epsilon as a room-scale computer installation.

    .tools/blender/blender -b --python tools/blender/build_epsilon_installation.py

## What the Batch 001-R review changed

The revised B still read as a *pedestal / totem*, and the owner's
clarification of "bigass computer" is:

> a room-scale or wall-scale computer installation -- old research-facility
> supercomputer / control-bank energy, huge console / terminal / machine-bank
> presence, something you walk up to and feel is a major machine
> installation, not a prop.

And the alien core survives, but **as an intrusion into that**:

> the big old human computer exists first; the weird alien Epsilon thing is
> smashed into it, embedded into it, fused through it, growing through it,
> or inhabiting it.

So the object is now **7.2 m of abandoned facility mainframe** standing
against a Hub wall, with the alien mass having erupted through the middle of
it. That is roughly a third of the Hub's 22 m wall and 2.9 m of its 5 m
height: at 1.6 m eye height you cannot see past it, which is the difference
between an installation and a prop.

## The visual law, applied

| | Human computer | Epsilon intrusion |
| --- | --- | --- |
| Form | Rectilinear bays on a 1.2 m module, flat fronts, orderly | Asymmetric, canted, unrepeating |
| Surface | Bolted cabinet skin, louvres, switch banks, patch rows, dead CRT bays | Dense plating at a pitch the facility never uses, veined green |
| Light | **None.** Every monitor is dark glass | Green, from inside, out through the seams |
| Age | Old, cold, institutional, abandoned | Active, humming, wrong |

**Nothing on the human half glows.** That is the single most load-bearing
rule here: the moment a console has a lit readout, the installation reads as
powered and the intrusion stops being the only living thing in the room.

## The eruption

The bank is built as seven bays. Bays 3 and 4 are **destroyed** -- their
cabinet fronts are gone, the structure around them is bent and displaced,
and the alien mass occupies the void. Debris sits on the floor in front.
The eruption is off-centre (bay 3 of 7) because a centred one reads as a
designed feature rather than as damage.
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

#: 7.2 m of wall, 2.9 m tall, 1.2 m deep. Against the Hub's 22 x 16 x 5 m
#: room that is a third of one wall and well over head height -- an
#: installation you walk up to rather than an object you walk around.
#:
#: This REPLACES the 1.4 x 1.4 x 2.8 m envelope the earlier concepts were
#: built to, and it is now the largest single authored object in the project.
#: `hub.gd` has no contract for it; see ART_FRONTIER.md interface item 4.
BAY = 1.2
BAYS = 7
WIDTH = BAY * BAYS
HEIGHT = 2.9
DEPTH = 1.2
BOX = (WIDTH + 1.4, DEPTH + 1.6, HEIGHT + 1.3)

#: Bays 3 and 4 (0-indexed) are gone. Off-centre on purpose.
BREACH = (3, 4)


def _bay_x(i):
    return -WIDTH / 2.0 + BAY * (i + 0.5)


def build():
    """Returns (human, alien, cores, screens) -- four material groups."""
    human, alien, cores, screens = [], [], [], []

    # --- the plinth the whole bank stands on -------------------------------
    human.append(brushkit.block("mb_plinth", (WIDTH + 0.4, DEPTH + 0.3, 0.22),
                                (0.0, 0.0, 0.11)))
    # A floor cable tray running out of it toward the room.
    human.append(brushkit.block("mb_tray", (WIDTH * 0.7, 0.44, 0.10),
                                (-0.4, -(DEPTH / 2.0 + 0.45), 0.05)))
    for i in range(6):
        human.append(brushkit.block(
            "mb_trayrib_%d" % i, (0.06, 0.44, 0.13),
            (-WIDTH * 0.32 + i * WIDTH * 0.13,
             -(DEPTH / 2.0 + 0.45), 0.065)))

    for i in range(BAYS):
        x = _bay_x(i)
        if i in BREACH:
            # Destroyed. Only the wrecked structure survives.
            human.append(brushkit.block("mb_stub_%d" % i,
                                        (BAY * 0.94, DEPTH, 0.34),
                                        (x, 0.0, 0.22 + 0.17)))
            # Bent frame uprights, leaning away from the blast.
            for side in (-1.0, 1.0):
                up = brushkit.block("mb_bent_%d_%d" % (i, int(side)),
                                    (0.13, DEPTH * 0.8, HEIGHT * 0.72),
                                    (x + side * BAY * 0.44, 0.06,
                                     0.22 + HEIGHT * 0.36))
                human.append(brushkit.spin(up, "Y", side * 9.0))
            # A torn cabinet roof hanging over the void.
            human.append(brushkit.wedge("mb_torn_%d" % i,
                                        (BAY * 0.8, DEPTH * 0.7, 0.30),
                                        (x, 0.12, 0.22 + HEIGHT * 0.86),
                                        axis="y", rotation_z=180.0))
            continue

        # An intact bay: base cabinet, raked console, upper panel, cornice.
        human.append(brushkit.block("mb_cab_%d" % i,
                                    (BAY * 0.96, DEPTH, 1.02),
                                    (x, 0.0, 0.22 + 0.51)))
        human.append(brushkit.wedge("mb_desk_%d" % i,
                                    (BAY * 0.96, 0.46, 0.26),
                                    (x, -(DEPTH / 2.0 - 0.23), 0.22 + 1.15),
                                    axis="y", rotation_z=180.0))
        human.append(brushkit.block("mb_upper_%d" % i,
                                    (BAY * 0.96, DEPTH * 0.86, 1.34),
                                    (x, 0.06, 0.22 + 1.71)))
        human.append(brushkit.block("mb_cornice_%d" % i,
                                    (BAY, DEPTH + 0.12, 0.16),
                                    (x, 0.0, 0.22 + 2.46)))
        # A recessed monitor bay -- dark glass, set into a deep bezel.
        # A bezel of geometry, with the glass set BEHIND it. The recess is
        # what makes a monitor read as inset; painting one into the texture
        # put a bright bezel on whichever face the projection happened to
        # sample.
        human.append(brushkit.frame("mb_bezel_%d" % i,
                                    (BAY * 0.70, 0.62), 0.07, 0.10,
                                    (x, -(DEPTH * 0.43 + 0.03),
                                     0.22 + 1.86)))
        screens.append(brushkit.block("mb_screen_%d" % i,
                                      (BAY * 0.58, 0.05, 0.50),
                                      (x, -(DEPTH * 0.43 + 0.06),
                                       0.22 + 1.86)))
        # Conduit stubs rising into the ceiling from alternating bays.
        if i % 2 == 0:
            human.append(brushkit.prism("mb_conduit_%d" % i, 0.07, 0.42, 8,
                                        (x + BAY * 0.3, 0.30,
                                         0.22 + HEIGHT - 0.05),
                                        asset_name="epsilon_installation"))

    # A continuous cable run along the top of the intact bays.
    human.append(brushkit.block("mb_run", (WIDTH, 0.18, 0.13),
                                (0.0, 0.42, 0.22 + HEIGHT - 0.10)))

    # --- the alien mass, occupying the two dead bays -----------------------
    bx = (_bay_x(BREACH[0]) + _bay_x(BREACH[1])) / 2.0
    # The trunk RISES PAST the cornice. The first version stayed inside the
    # breach and read as a plant growing in a gap rather than as something
    # that came through the machine -- an eruption that respects the
    # silhouette of the thing it erupted from is not an eruption.
    trunk = brushkit.prism("ep_trunk", 0.66, HEIGHT * 1.06, 10,
                           (bx, 0.18, 0.22 + HEIGHT * 0.56), top_radius=0.40,
                           asset_name="epsilon_installation", organic=True)
    alien.append(brushkit.spin(trunk, "X", 6.0))
    # The BODY: a mass sitting in the torn opening at chest-to-head height.
    #
    # Without it the eruption was a stalk -- 0.66 m of trunk in a 2.4 m
    # hole, which reads as a plant growing in a gap rather than as the
    # thing that made the gap. What destroyed two bays of a mainframe has
    # to be bigger than the hole it left. These three overlapping blocks
    # are canted against each other so no two faces agree, which is the
    # alien half's whole rule: the human bank is a grid and this is not.
    for j, (dx, dz, w, d, h, rz, rx) in enumerate((
            (-0.10, 1.52, 1.42, 0.92, 1.16, 13.0, -7.0),
            (0.28, 2.02, 1.06, 0.78, 0.94, -29.0, 11.0),
            (-0.24, 2.36, 0.82, 0.66, 0.70, 41.0, -16.0))):
        body = brushkit.block("ep_body_%d" % j, (w, d, h),
                              (bx + dx, 0.10, 0.22 + dz))
        alien.append(brushkit.spin(brushkit.spin(body, "X", rx), "Z", rz))
    # A crown above the bank's top line: the part you see over the cabinets
    # from anywhere in the room.
    crown = brushkit.wedge("ep_crown", (0.94, 0.72, 0.54),
                           (bx + 0.10, 0.14, 0.22 + HEIGHT + 0.16), axis="y")
    alien.append(brushkit.spin(crown, "Z", 22.0))
    for j, (dx, dz, ln, ang) in enumerate(((-0.42, HEIGHT + 0.02, 0.46, -38.0),
                                           (0.50, HEIGHT + 0.24, 0.38, 27.0))):
        alien.append(brushkit.wedge("ep_spur_%d" % j, (0.16, ln, 0.22),
                                    (bx + dx, 0.12, 0.22 + dz), axis="y",
                                    rotation_z=ang))
    # A collar where it came through the cabinet line -- the wound.
    alien.append(brushkit.prism("ep_collar", 0.78, 0.26, 10,
                                (bx, 0.06, 0.22 + 1.16), top_radius=0.60,
                                asset_name="epsilon_installation",
                                organic=True))
    # Limbs gripping the intact bays either side. Unequal, and they reach
    # ACROSS the human structure, which is what makes it an infection rather
    # than a thing standing in a gap.
    for side, reach, z, lean in ((-1.0, 2.60, 1.95, 16.0),
                                 (1.0, 2.05, 2.34, -11.0)):
        limb = brushkit.block("ep_limb_%d" % int(side),
                              (reach, 0.24, 0.20),
                              (bx + side * reach / 2.0, -0.16, 0.22 + z))
        alien.append(brushkit.spin(limb, "Z", side * lean))
        for j in range(3):
            t = (j + 1) / 4.0
            alien.append(brushkit.block(
                "ep_claw_%d_%d" % (int(side), j), (0.20, 0.36, 0.42),
                (bx + side * reach * t, -0.30, 0.22 + z - 0.16)))
    # Spurs driven THROUGH the fronts of the surviving bays either side.
    # A wound in the bank, not a thing resting against it: each one starts
    # inside the cabinet and comes out past its face.
    for j, (bay, z, ln, ang) in enumerate(((2, 1.62, 0.86, -24.0),
                                           (5, 2.08, 0.72, 31.0),
                                           (1, 2.30, 0.58, -47.0),
                                           (6, 1.28, 0.50, 19.0))):
        spur = brushkit.block("ep_through_%d" % j, (0.22, ln, 0.26),
                              (_bay_x(bay), -(DEPTH / 2.0 - ln * 0.35),
                               0.22 + z))
        alien.append(brushkit.spin(spur, "X", ang))

    # Roots down into the plinth and out across the floor.
    for j, (dx, dy, rot, ln) in enumerate(((-1.3, -0.9, 28.0, 1.5),
                                           (0.9, -1.1, -41.0, 1.2),
                                           (2.1, -0.7, 63.0, 0.9))):
        alien.append(brushkit.block("ep_root_%d" % j, (0.17, ln, 0.13),
                                    (bx + dx, dy, 0.07), rotation_z=rot))
    # Fins off the trunk, breaking the bank's flat front at eye height.
    for j, (ang, z, ln) in enumerate(((-52.0, 1.30, 0.62), (37.0, 1.85, 0.50),
                                      (-21.0, 2.34, 0.42), (68.0, 2.70, 0.34))):
        alien.append(brushkit.wedge("ep_fin_%d" % j, (0.12, ln, 0.26),
                                    (bx, 0.10, 0.22 + z), axis="y",
                                    rotation_z=ang))
    # Debris on the floor: the cabinet fronts that used to be there.
    for j, (dx, dy, sz, rot) in enumerate(((-2.0, -1.0, 0.42, 31.0),
                                           (1.4, -1.2, 0.34, -57.0),
                                           (2.6, -0.8, 0.26, 14.0))):
        human.append(brushkit.block("mb_debris_%d" % j,
                                    (sz, sz * 0.75, sz * 0.55),
                                    (bx + dx, dy, sz * 0.28),
                                    rotation_z=rot))

    # --- the cores: hard shards, never tapered ----------------------------
    for j, (dx, dz, w, d, h, rx, ry, rz) in enumerate((
            (-0.06, 1.62, 0.44, 0.38, 0.50, 17.0, -13.0, 26.0),
            (0.16, 2.06, 0.32, 0.42, 0.36, -24.0, 31.0, -43.0),
            (-0.10, 2.44, 0.36, 0.26, 0.40, 39.0, -9.0, 61.0),
            (0.08, 1.24, 0.26, 0.30, 0.28, -12.0, 22.0, 11.0))):
        c = brushkit.block("ep_core_%d" % j, (w, d, h),
                           (bx + dx, 0.14, 0.22 + dz))
        brushkit.spin(brushkit.spin(brushkit.spin(c, "X", rx), "Y", ry),
                      "Z", rz)
        cores.append(c)
    # Veins running out along the intact bays: the infection is spreading.
    #
    # Each one was a single straight 1.1 m bar, and a straight bar of pure
    # emission across a cabinet front reads as a highlighter stroke, not as
    # something growing. A vein STEPS: it runs along a panel seam, drops or
    # climbs at one, and carries on shorter and thinner than before. The
    # runs are horizontal and vertical only, because they are following the
    # human structure -- that is what makes them look like they are using
    # the machine rather than lying on it.
    face_y = -(DEPTH / 2.0 + 0.02)
    for j, (bay, z, runs) in enumerate((
            (1, 1.95, ((0.62, 0.0), (0.0, -0.34), (0.44, 0.0), (0.0, 0.22))),
            (5, 2.24, ((0.50, 0.0), (0.0, 0.28), (0.38, 0.0))),
            (2, 1.05, ((0.44, 0.0), (0.0, 0.40), (0.30, 0.0), (0.0, -0.18))),
            (6, 1.60, ((0.36, 0.0), (0.0, -0.26), (0.26, 0.0))))):
        # Veins spread OUTWARD from the breach, so the sign follows which
        # side of it this bay is on.
        step = 1.0 if _bay_x(bay) > bx else -1.0
        x, zz = _bay_x(bay), 0.22 + z
        for k, (dx, dz) in enumerate(runs):
            gauge = 0.075 - 0.012 * k          # it thins as it travels
            if dx:
                cores.append(brushkit.block(
                    "ep_vein_%d_%d" % (j, k), (dx, 0.05, gauge),
                    (x + step * dx / 2.0, face_y, zz)))
                x += step * dx
            else:
                cores.append(brushkit.block(
                    "ep_vein_%d_%d" % (j, k), (gauge, 0.05, abs(dz)),
                    (x, face_y, zz + dz / 2.0)))
                zz += dz
    return human, alien, cores, screens


def main():
    common.reset_scene()
    name = "epsilon_installation"
    human_parts, alien_parts, core_parts, screen_parts = build()

    def group(parts, label, canvas, density, size, rough=None):
        obj = common.join(parts, "%s_%s" % (name, label))
        common.uv_project_world(obj, density, size)
        common.assign(obj, common.make_textured_material(
            "%s_%s" % (name, label), canvas.to_blender("%s_%s_t" % (name, label)),
            roughness=pal.roughness(THEME) if rough is None else rough))
        return obj

    human = group(human_parts, "human",
                  propkit.machine_bank(THEME, name + "_panel", "panel"),
                  propkit.PROP_DENSITY, propkit.PROP_SIZE)
    alien = group(alien_parts, "alien",
                  propkit.alien_shell(THEME, name),
                  propkit.HERO_DENSITY, propkit.HERO_SIZE, 0.55)
    # Dead glass. No emission anywhere on the human half.
    screens = group(screen_parts, "screens",
                    propkit.machine_bank(THEME, name + "_screen", "screen"),
                    propkit.PROP_DENSITY, propkit.PROP_SIZE, 0.25)
    cores = common.join(core_parts, name + "_cores")
    # 0.40, not the 0.94 this was built at.
    #
    # `make_signal_material` guarantees the AUTHORED sum stays under 1.0;
    # the renderer then tonemaps and sRGB-encodes on top of that, which
    # lifts everything and clips the top of the ramp. A sweep of five bars
    # at 0.94 / 0.60 / 0.40 / 0.25 / 0.12 through the review bench put the
    # clip point between 0.40 and 0.60: at 0.60 the green channel pins at
    # 255, at 0.40 the core renders (164, 255, 85) at its hottest and holds
    # its hue everywhere else. The core is the single most important colour
    # in the game and it does not get to be approximately green.
    common.assign(cores, common.make_signal_material(
        name + "_cores", pal.universal("identity", 0),
        pal.universal("identity", 3), saturation=0.40))

    obj = common.join([human, alien, screens, cores], name)
    common.set_origin(obj, "floor")
    common.assert_fits(obj, name, BOX,
                       "The installation stands against a Hub wall; the Hub "
                       "is 22 x 16 x 5 m and this may not overrun its bay.")
    report = {name: common.export_glb(
        obj, "batch002/epsilon/%s.glb" % name, "landmark", check_flat=False)}
    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch002",
                       "epsilon", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")


if __name__ == "__main__":
    main()
