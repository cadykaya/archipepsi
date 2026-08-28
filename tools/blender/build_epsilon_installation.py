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

## Batch 002-R: the operator console

The 002 review passed the scale and the idea and named one remaining
problem:

> Right now it reads more like "big server installation". I want it to also
> read like "a huge computer a researcher could physically walk up to and
> operate".

A wall of racks says *this facility had computers*. It does not say *a
person used this one*. So the middle three bays are now a **console**: an
oversized monitor above a control desk, at the heights a standing human
actually works at, with a footwell under the desk and a worn steel plate on
the floor where somebody stood for years.

Nothing here is decoration. Each part answers "how would you use it?":

| Part | What it says |
| --- | --- |
| Desk top at 0.95 m | You stand at this. It is not a shelf. |
| Footwell under it | Your feet go here, so you can get close. |
| Raked control panel | Your hands go here, angled toward you. |
| Monitor at eye + 0.45 m | You look UP at it slightly. Institutional, oversized. |
| Instrument strip between them | The row you read while your hands are busy. |
| Floor plate, worn | Somebody stood here. For a long time. |

## The eruption, and why it is at one end

Bays 5 and 6 are **destroyed** -- fronts gone, structure bent, the alien
mass in the void, debris on the floor. That is the right-hand end of the
bank, not its middle.

And the mass does not stay there. It reaches back **across the console it
wrecked**: a limb over the desk's right end, a spur through the right side
of the monitor housing, green conduits running left along the human cable
tray they hijacked. The console's right third is being taken; its left two
thirds are still a human machine somebody could use.

The visual sentence, in that order: **humans built this computer, then
something foreign took it over.**

## The one rule that survives the revision

**Nothing on the human half glows.** The monitor is dead glass -- except
where the alien has come THROUGH it, which is not the human machine powering
up. That is the review's "monitor behaving strangely", and it is the alien's
light arriving from inside the housing, not a console with the lights on.
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
#: Depth is 3.6 m, not 2.8. The console DESK projects forward of the rack
#: line, and it has to: a machine you cannot stand at is not a machine you
#: operate, and the whole point of this revision is that a person could.
#: Still a fraction of the Hub's 16 m.
BOX = (WIDTH + 1.4, DEPTH + 2.4, HEIGHT + 1.3)

#: The three bays that are the OPERATOR CONSOLE -- the face a researcher
#: stood at. Centre of the bank, because that is where the thing you use
#: goes; a console tucked into a corner is a detail rather than the point.
CONSOLE = (2, 3, 4)

#: The two bays that are DESTROYED. Bays 5 and 6, hard against the right-hand
#: end -- not the middle.
#:
#: The 002 review was exact about this: "move it OFF-CENTER and make it
#: visibly smash / fuse / grow into one side of that human console... DO NOT
#: make the alien intrusion symmetrical." A centred breach reads as a
#: designed feature. A breach at one end, with the mass leaning back across
#: the console it wrecked, reads as damage that came from somewhere.
BREACH = (5, 6)

#: Where the operator stands, and the heights that decide the console.
#: Read from engineering, never chosen -- a desk at the wrong height is the
#: fastest way to make a room-scale object read as a toy.
EYE = common.DIM["player_eye_height"]          # 1.6 m
DESK_TOP = 0.95                                # institutional desk height
MONITOR_MID = EYE + 0.45                       # a big display, above eyeline


def _bay_x(i):
    return -WIDTH / 2.0 + BAY * (i + 0.5)


def build():
    """Returns (human, controls, alien, cores, screens) -- five groups."""
    human, controls, alien, cores, screens = [], [], [], [], []

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

        if i in CONSOLE:
            # The console's own bays: the racks BEHIND it, recessed, so the
            # console face sits in an alcove rather than bolted onto a flat
            # wall. The console itself is built once, below, because it
            # spans all three.
            human.append(brushkit.block("mb_back_%d" % i,
                                        (BAY * 0.96, DEPTH * 0.55, HEIGHT),
                                        (x, DEPTH * 0.22, 0.22 + HEIGHT / 2.0)))
            human.append(brushkit.block("mb_cornice_%d" % i,
                                        (BAY, DEPTH + 0.12, 0.16),
                                        (x, 0.0, 0.22 + HEIGHT - 0.08)))
            continue

        # An intact rack bay: base cabinet, raked shelf, upper panel, cornice.
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
        # A bezel of GEOMETRY, with the glass behind it: painting one into
        # the texture put a bright bezel on whichever face the world-planar
        # projection happened to sample.
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

    # A continuous cable run along the top of the bays.
    human.append(brushkit.block("mb_run", (WIDTH, 0.18, 0.13),
                                (0.0, 0.42, 0.22 + HEIGHT - 0.10)))

    # ------------------------------------------------------------------
    # THE OPERATOR CONSOLE -- the face a researcher stood at.
    # ------------------------------------------------------------------
    cx = _bay_x(CONSOLE[1])                  # 0.0, the middle console bay
    span = BAY * len(CONSOLE)                # 3.6 m of console
    front = -(DEPTH / 2.0)                   # the rack line

    # Pilasters framing the alcove, so the console reads as SET INTO the
    # bank rather than parked in front of it.
    for side in (-1.0, 1.0):
        human.append(brushkit.block(
            "cs_pilaster_%d" % int(side), (0.24, DEPTH, HEIGHT),
            (cx + side * (span / 2.0 + 0.12), 0.0, 0.22 + HEIGHT / 2.0)))
    # A lintel across the top of the alcove.
    human.append(brushkit.block("cs_lintel", (span + 0.48, DEPTH * 0.8, 0.30),
                                (cx, 0.06, 0.22 + HEIGHT - 0.31)))

    # The console is a COCKPIT, and it is built out from the rack line in
    # layers rather than flush with it. The first version put the desk, the
    # housing and the bezel all within 0.3 m of the same plane, and from
    # eight metres it read as a wall with a band on it: at that distance
    # depth is the only thing separating one part from another, because
    # every part is the same value. So each layer projects further than the
    # one behind it, and the whole thing self-shades.
    #
    #   -0.60  the rack line / alcove face
    #   -1.05  monitor bezel and glass
    #   -1.15  hood, over the top of it
    #   -1.45  raked control panel
    #   -1.75  desk front and the footwell under it
    #   -2.40  the floor plate you stand on

    # The DESK. Top at 0.95 m -- the height a standing person works at --
    # projecting well forward of the rack line so there is somewhere to be.
    desk_y = front - 0.72
    controls.append(brushkit.block("cs_desk", (span - 0.26, 1.10, 0.11),
                                (cx, desk_y, 0.22 + DESK_TOP - 0.055)))
    # A front apron, and a FOOTWELL under it: the apron stops well above the
    # plinth, which is what makes the desk something you stand AT rather
    # than a cabinet with a flat top.
    controls.append(brushkit.block("cs_apron", (span - 0.26, 0.12, 0.26),
                                (cx, desk_y - 0.49, 0.22 + DESK_TOP - 0.24)))
    for side in (-1.0, 1.0):
        human.append(brushkit.block(
            "cs_pedestal_%d" % int(side), (0.42, 1.00, DESK_TOP - 0.11),
            (cx + side * (span / 2.0 - 0.36), desk_y,
             0.22 + (DESK_TOP - 0.11) / 2.0)))
    # The plate on the floor where somebody stood. Worn, and the one piece
    # of this object that is about a person rather than a machine.
    # 0.70 m deep, not 0.86, and pulled in: the depth budget's back edge is
    # the alien TRUNK at +1.0, not the cornice at +0.66, so the floor plate
    # was the part paying for the eruption leaning backwards.
    human.append(brushkit.grate("cs_floorplate", (span - 0.50, 0.70, 0.06),
                                7, 0.05, (cx, desk_y - 0.84, 0.03),
                                axis="y"))

    # THE OPERATOR FACE WEARS A DIFFERENT SKIN.
    #
    # Desk, apron, monitor housing, hood, auxiliaries, raked panel and
    # instrument strip all take `machine_bank(..., "console")` -- switch
    # banks and patch rows -- while the racks either side keep the cabinet
    # map. With one skin over everything the console was a differently
    # shaped piece of the same wall: geometry said "console", surface said
    # "more cabinet", and at a pace back the surface won.
    #
    # The RAKED CONTROL PANEL: hands go here, angled toward the operator.
    controls.append(brushkit.wedge(
        "cs_panel", (span - 0.34, 0.52, 0.38),
        (cx, front - 0.62, 0.22 + DESK_TOP + 0.19), axis="y",
        rotation_z=180.0))
    # The instrument strip between the panel and the screen: the row you
    # read while your hands are busy.
    controls.append(brushkit.block("cs_instruments", (span - 0.44, 0.28, 0.34),
                                   (cx, front - 0.50, 0.22 + 1.52)))

    # The MONITOR. Oversized and slightly LEFT of centre -- the alien takes
    # the right-hand side, and a screen centred in a bank being eaten from
    # one end would put the takeover exactly on the mirror line.
    mon_z = 0.22 + MONITOR_MID
    mon_x = cx - 0.16
    # The three depths that make a monitor a monitor, written as FACES
    # rather than as centres.
    #
    # The first version gave the housing a 0.62 m depth centred 0.42 m
    # forward and the bezel a centre 0.74 m forward, which put the bezel
    # 10 mm in front of the housing's front face and the GLASS entirely
    # inside the housing box. From eight metres the whole console rendered
    # as one flat pale panel: there was no screen in it to see. A box that
    # swallows the thing it is meant to frame is invisible in exactly the
    # way that looks like a design choice.
    bezel_face = front - 1.38      # the ring, front-most
    glass_face = front - 1.30      # recessed 80 mm behind the ring
    housing_face = front - 1.26    # and the box behind that
    housing_back = front + 0.10    # buried into the alcove
    controls.append(brushkit.block(
        "cs_housing", (2.16, housing_back - housing_face, 1.46),
        (mon_x, (housing_face + housing_back) / 2.0, mon_z)))
    human.append(brushkit.frame("cs_bezel", (1.86, 1.16), 0.13, 0.14,
                                (mon_x, bezel_face + 0.07, mon_z)))
    screens.append(brushkit.block("cs_glass", (1.62, 0.06, 0.94),
                                  (mon_x, glass_face + 0.03, mon_z)))
    # A hood over it, projecting furthest of anything at that height: this
    # is the form that reads as "console" from across a room.
    controls.append(brushkit.wedge("cs_hood", (2.42, 0.64, 0.30),
                                (mon_x, bezel_face + 0.24, mon_z + 0.86),
                                axis="y"))
    # Two auxiliary screens flanking the main one, at slightly different
    # heights. A control room has more than one display and they are never
    # level with each other.
    for j, (dx, dz) in enumerate(((-1.52, -0.16), (1.54, 0.08))):
        controls.append(brushkit.block("cs_auxbox_%d" % j, (0.66, 0.52, 0.60),
                                    (cx + dx, front - 0.72, mon_z + dz)))
        human.append(brushkit.frame("cs_auxbezel_%d" % j, (0.56, 0.48),
                                    0.08, 0.12,
                                    (cx + dx, front - 1.02, mon_z + dz)))
        screens.append(brushkit.block("cs_auxglass_%d" % j, (0.40, 0.05, 0.32),
                                      (cx + dx, front - 0.97, mon_z + dz)))
    # Vent columns under the auxiliaries.
    for side in (-1.0, 1.0):
        human.append(brushkit.grate(
            "cs_vent_%d" % int(side), (0.22, 0.26, 0.62), 5, 0.04,
            (cx + side * (span / 2.0 - 0.24), front - 0.44, 0.22 + 1.52),
            axis="z"))

    # --- the alien mass, at the RIGHT-HAND end ----------------------------
    bx = (_bay_x(BREACH[0]) + _bay_x(BREACH[1])) / 2.0
    # The trunk rises past the cornice. An eruption that respects the
    # silhouette of the thing it erupted from is not an eruption.
    trunk = brushkit.prism("ep_trunk", 0.66, HEIGHT * 1.06, 10,
                           (bx, 0.18, 0.22 + HEIGHT * 0.56), top_radius=0.40,
                           asset_name="epsilon_installation", organic=True)
    alien.append(brushkit.spin(trunk, "X", 6.0))
    # The BODY: the mass that did the damage, canted so no two faces agree.
    for j, (dx, dz, w, d, h, rz, rx) in enumerate((
            (-0.10, 1.52, 1.42, 0.92, 1.16, 13.0, -7.0),
            (0.28, 2.02, 1.06, 0.78, 0.94, -29.0, 11.0),
            (-0.24, 2.36, 0.82, 0.66, 0.70, 41.0, -16.0))):
        body = brushkit.block("ep_body_%d" % j, (w, d, h),
                              (bx + dx, 0.10, 0.22 + dz))
        alien.append(brushkit.spin(brushkit.spin(body, "X", rx), "Z", rz))
    # A crown above the bank's top line.
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

    # ------------------------------------------------------------------
    # THE FUSION -- the mass reaching back INTO the console it wrecked.
    # This is the half of the object the 002 review actually asked for.
    # Everything below reaches LEFT, and nothing mirrors.
    # ------------------------------------------------------------------
    right = cx + span / 2.0            # the console's right-hand edge
    # A limb along the desk, ending ON it. It is using the desk.
    limb = brushkit.block("ep_overdesk", (1.90, 0.30, 0.22),
                          (right - 0.50, desk_y + 0.06,
                           0.22 + DESK_TOP + 0.16))
    alien.append(brushkit.spin(limb, "Z", -7.0))
    for j, (dx, dz) in enumerate(((0.10, -0.16), (0.72, -0.22), (1.30, -0.10))):
        alien.append(brushkit.block(
            "ep_grip_%d" % j, (0.16, 0.34, 0.40),
            (right - 0.50 - dx, desk_y - 0.16, 0.22 + DESK_TOP + dz)))
    # A spur THROUGH the monitor housing's right side. It does not stop at
    # the housing -- it comes out of the glass, which is the thing the
    # review called the monitor behaving strangely.
    thru = brushkit.block("ep_through_monitor", (1.15, 1.30, 0.30),
                          (right - 0.34, front - 0.62, mon_z - 0.10))
    alien.append(brushkit.spin(thru, "Z", 12.0))
    alien.append(brushkit.wedge("ep_snout", (0.34, 0.46, 0.28),
                                (right - 0.86, front - 1.42, mon_z - 0.16),
                                axis="y", rotation_z=200.0))
    # Panels REPLACED, not covered: alien plate where the console's own
    # right-hand skin used to be, flush with it and at a different pitch.
    for j, (dz, h, dy) in enumerate(((0.62, 0.52, 0.10), (1.30, 0.44, 0.60),
                                     (2.02, 0.66, 1.16))):
        alien.append(brushkit.block("ep_plate_%d" % j, (0.44, 0.22, h),
                                    (right - 0.24, front - dy, 0.22 + dz)))
    # Green conduits hijacking the human cable tray, running left along it.
    for j, (x0, ln, dz) in enumerate(((right - 1.10, 2.30, 0.02),
                                      (right - 0.40, 1.20, 0.10))):
        alien.append(brushkit.block("ep_conduit_%d" % j, (ln, 0.12, 0.10),
                                    (x0 - ln / 2.0, -(DEPTH / 2.0 + 0.45),
                                     0.22 + dz)))
    # Spurs driven THROUGH the fronts of the surviving rack bays.
    for j, (bay, z, ln, ang) in enumerate(((1, 1.62, 0.86, -24.0),
                                           (0, 2.30, 0.58, -47.0))):
        spur = brushkit.block("ep_thruback_%d" % j, (0.22, ln, 0.26),
                              (_bay_x(bay), -(DEPTH / 2.0 - ln * 0.35),
                               0.22 + z))
        alien.append(brushkit.spin(spur, "X", ang))
    # Roots down into the plinth and out across the floor.
    for j, (dx, dy, rot, ln) in enumerate(((-1.3, -0.9, 28.0, 1.5),
                                           (0.4, -1.2, -41.0, 1.2),
                                           (1.1, -0.7, 63.0, 0.9))):
        alien.append(brushkit.block("ep_root_%d" % j, (0.17, ln, 0.13),
                                    (bx + dx, dy, 0.07), rotation_z=rot))
    # Debris on the floor: the cabinet fronts that used to be there.
    for j, (dx, dy, sz, rot) in enumerate(((-1.6, -1.0, 0.42, 31.0),
                                           (-0.7, -1.2, 0.34, -57.0),
                                           (0.6, -0.8, 0.26, 14.0))):
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
    # Shards coming OUT OF THE SCREEN. The dead glass is unbroken on the
    # left two thirds; on the right the alien is through it, and the light
    # is arriving from inside the housing rather than from a console that
    # has been switched on.
    for j, (dx, dz, w, h, rz) in enumerate((
            (0.30, 0.10, 0.26, 0.30, 18.0),
            (0.62, -0.16, 0.18, 0.22, -34.0),
            (0.46, 0.34, 0.14, 0.17, 51.0))):
        g = brushkit.block("ep_screenshard_%d" % j, (w, 0.16, h),
                           (right - 0.90 + dx, front - 1.34, mon_z + dz))
        cores.append(brushkit.spin(g, "Y", rz))
    # A line of green along the console's right edge: the seam where the
    # human panel stops and the replacement starts.
    cores.append(brushkit.block("ep_seam", (0.08, 0.10, 2.10),
                                (right - 0.46, front - 0.68, 0.22 + 1.32)))
    # Buttons overtaken: green where the control panel's right end was.
    for j, (dx, dy) in enumerate(((0.16, 0.0), (0.40, 0.05), (0.62, -0.03))):
        cores.append(brushkit.block(
            "ep_key_%d" % j, (0.14, 0.20, 0.05),
            (right - 0.34 - dx, front - 0.78 + dy,
             0.22 + DESK_TOP + 0.30)))
    # Veins stepping out along the intact bays, LEFT, away from the breach.
    # A vein steps: it runs along a seam, turns at one, and carries on
    # thinner. Straight emissive bars read as highlighter strokes.
    face_y = -(DEPTH / 2.0 + 0.02)
    for j, (bay, z, runs) in enumerate((
            (1, 1.95, ((0.62, 0.0), (0.0, -0.34), (0.44, 0.0), (0.0, 0.22))),
            (0, 2.24, ((0.50, 0.0), (0.0, 0.28), (0.38, 0.0))),
            (1, 1.05, ((0.44, 0.0), (0.0, 0.40), (0.30, 0.0))))):
        x, zz = _bay_x(bay), 0.22 + z
        for k, (dx, dz) in enumerate(runs):
            gauge = 0.075 - 0.012 * k          # it thins as it travels
            if dx:
                cores.append(brushkit.block(
                    "ep_vein_%d_%d" % (j, k), (dx, 0.05, gauge),
                    (x - dx / 2.0, face_y, zz)))
                x -= dx
            else:
                cores.append(brushkit.block(
                    "ep_vein_%d_%d" % (j, k), (gauge, 0.05, abs(dz)),
                    (x, face_y, zz + dz / 2.0)))
                zz += dz
    return human, controls, alien, cores, screens


def main():
    common.reset_scene()
    name = "epsilon_installation"
    (human_parts, control_parts, alien_parts, core_parts,
     screen_parts) = build()

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
    # The console's raked panel and instrument strip get the CONSOLE skin --
    # switch banks and patch rows, not cabinet louvres. A control surface
    # wearing the same map as the cabinet behind it is a cabinet with a
    # slope on it, and the whole revision is about the difference.
    controls = group(control_parts, "controls",
                     propkit.machine_bank(THEME, name + "_console", "console"),
                     propkit.PROP_DENSITY, propkit.PROP_SIZE)
    alien = group(alien_parts, "alien",
                  propkit.alien_shell(THEME, name),
                  propkit.HERO_DENSITY, propkit.HERO_SIZE, 0.55)
    # Dead glass. No emission anywhere on the human half.
    # Roughness 0.50, not 0.25.
    #
    # A dead CRT is glassy, and at 0.25 the 2.7 m-wide console screen caught
    # a broad specular off the key and rendered with a bright bloom across
    # its lower corner -- which reads as a monitor that is ON. Nothing on
    # the human half glows is not a rule about emission alone; a specular
    # highlight big enough to look like a picture breaks it just as
    # completely. Rougher glass still reads as glass and cannot be mistaken
    # for a display.
    screens = group(screen_parts, "screens",
                    propkit.machine_bank(THEME, name + "_screen", "screen"),
                    propkit.PROP_DENSITY, propkit.PROP_SIZE, 0.50)
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

    obj = common.join([human, controls, alien, screens, cores], name)
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
