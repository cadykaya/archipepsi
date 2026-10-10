"""Design pass 2: the five weapons in the HYBRID direction, at
mechanism-approval detail. EXPLORATION ONLY -- not models. (Arty,
2026-10-10.)

The owner chose the hybrid: station-built engineering, Epsilon technology
and foreign-world Echo cores. Here each weapon is a three-stage POWER
TRAIN, one stage per origin:

    Echo core  (the visiting world)  -> the SOURCE of the capability
    Epsilon    (the converter)       -> turns that into a form of energy
    station    (the mechanism)       -> stores it, delivers it, survives it

Every numbered part has an owner and a reason (PARTS). The drawings below
use `detail_kit`; the sheets come from `weapon_detail_sheets.py`.
"""

from __future__ import annotations

import math

import detail_kit as dk

# kind: why the part exists
KINDS = ("mechanical", "structural", "thermal", "energy", "mounting",
         "maintenance", "readout", "safety")


def _device(g, x, y, n=1):
    """The player's own device, its lit tip forward; two cam clamps."""
    g.poly([(x - 14, y - 8.6), (x + 9, y - 7.4), (x + 9, y - 2.8),
            (x - 14, y - 2.0)], "yours", lw=1.4, n=n)
    g.line([(x - 14, y - 5.3), (x + 9, y - 5.1)], (150, 160, 170), 0.4)
    g.rect(x + 9, y - 6.6, x + 11.2, y - 3.6, "white", lw=0.6)
    g.glow(x + 10.2, y - 5.1, 3.2, 0.5, (200, 230, 255))


def _clamps(g, xs, y, n=2):
    for i, bx in enumerate(xs):
        g.rect(bx - 1.2, y - 9.4, bx + 1.2, y - 1.0, "station_dark", lw=0.8,
               n=n if i == 0 else None)
        g.bar((bx + 1.2, y - 8.6), (bx + 3.6, y - 11.2), 0.9, "dark", lw=0.5)
        g.circle(bx + 3.6, y - 11.2, 0.8, "rubber", n_sides=10, lw=0.5)
        g.bolt(bx, y - 1.9, 0.55)


# ===================================================================
# FOUNDRY -- crucible and drop hammer
# ===================================================================

FOUNDRY_PARTS = [
    (1, "your device", "yours", "mounting",
     "the trigger and the power: every family is clamped to it"),
    (2, "cam clamps", "station", "mounting",
     "tool-free: the family comes off the device in one throw"),
    (3, "frame rail, lightened", "station", "structural",
     "carries the hammer's blow into the device mount; holes save weight"),
    (4, "hammer post and pivot pin", "station", "structural",
     "a forked post takes the hammer's reaction; castellated nut"),
    (5, "hammer, replaceable face", "station", "mechanical",
     "the blow that fires; the hardened face is the wear part"),
    (6, "re-cock gas strut", "station", "mechanical",
     "WHY THE HAMMER CLIMBS BACK BY ITSELF: no hand, so a strut"),
    (7, "latch pawl and solenoid", "station", "mechanical",
     "holds the hammer up; the device's trigger signal releases it"),
    (8, "anvil and striker", "station", "mechanical",
     "the hammer hits the anvil; the striker drives the ram"),
    (9, "slug magazine and feed", "station", "mechanical",
     "plain station blanks; one drops into the breech each cycle"),
    (10, "crucible casing, clamp bands", "station", "structural",
     "contains the heat and the pressure; bands carry the hoop load"),
    (11, "thermal-break spacers", "ceramic", "thermal",
     "why the frame (and the device) stay cool"),
    (12, "heat lattice", "epsilon", "energy",
     "EPSILON: turns the core's output into heat in the lining; "
     "burst through the station casing"),
    (13, "Echo core and cradle", "echo", "energy",
     "THE VISITING WORLD: the source. Swappable; its material and "
     "accent come from the source game"),
    (14, "mouth and cooling fins", "heat", "thermal",
     "the hottest part sheds heat where it is; heat-tinted steel"),
    (15, "quench vent", "station", "thermal",
     "purges steam after each shot: the residual smoke has a cause"),
    (16, "cable loom", "station", "energy",
     "trigger signal to the solenoid, power to the lattice; clipped"),
]


def foundry(hammer=68.0, glow=1.0, labels=True):
    g = dk.D("Foundry")
    a = math.radians(hammer)
    # device and clamps under the frame
    _device(g, -2, 0)
    _clamps(g, (-10, 2), 0)
    # frame rail (C-channel, lightened)
    g.rect(-12, -2.6, 16, 4.6, "station", chamfer=0.8, lw=1.5, n=3)
    g.line([(-11.4, -1.4), (15.4, -1.4)], (110, 110, 108), 0.5)
    for x in (-6.5, -1.5, 3.5):
        g.circle(x, 1.0, 1.25, "dark", n_sides=14, lw=0.5)
    g.chips([(-11.6, 4.2), (15.6, 4.1), (15.5, -2.2)], 0.45, 3)
    # cable loom from the device's rear
    g.hose([(-14.5, -4), (-15.5, 3), (-13.2, 11), (-11.4, 12.5)], 0.7,
           "dark", ribs=False)
    g.hose([(-12, 5.5), (-4, 6.2), (12, 7.0)], 0.6, "dark", ribs=False)
    g.anchor(16, -15.2, 4)
    for x in (-8, 4):
        g.rect(x - 0.4, 5.5, x + 0.4, 6.9, "steel", lw=0.3)
    # slug magazine and feed tube to the breech
    g.rect(-3, 4.6, 3.5, 11.5, "station", chamfer=0.5, lw=1.0, n=9)
    g.rect(-1.8, 5.6, -0.4, 10.6, "dark", lw=0.4)
    for y in (6.2, 7.8, 9.4):
        g.rect(-1.6, y, -0.6, y + 1.1, "slug", lw=0.3)
    g.bar((3.5, 8.0), (10.6, 8.9), 1.8, "station_dark", lw=0.8)
    g.rect(5.5, 7.6, 8.5, 9.3, "dark", lw=0.4)
    g.rect(6.2, 7.9, 7.4, 9.0, "slug", lw=0.3)
    g.stencil(-2.7, 12.6, "SLUG 9", 0.9)
    # Echo core in its cradle, under the crucible
    g.rect(12, -12.6, 27, -5.0, "station_dark", chamfer=0.6, lw=1.0)
    g.rect(13, -11.4, 25, -6.2, "echo", chamfer=1.2, lw=1.2, n=13)
    g.rect(13, -11.4, 14.2, -6.2, "steel", lw=0.6)
    g.rect(23.8, -11.4, 25, -6.2, "steel", lw=0.6)
    g.rect(16, -9.4, 22, -8.2, "white", lw=0.3, alpha=150)
    g.bar((27, -6.0), (28.8, -9.6), 0.8, "dark", lw=0.5)
    g.bolt(12.8, -12.0, 0.5)
    g.bolt(26.2, -12.0, 0.5)
    # crucible casing
    g.poly([(10, -4.6), (36, -3.0), (37.6, 12.2), (11, 13.0)], "station",
           lw=1.6, n=10)
    # thermal-break spacers where the casing meets the rail
    g.rect(9.2, 3.2, 11.6, 5.6, "ceramic", lw=0.7, n=11)
    g.rect(9.2, -1.6, 11.6, 0.8, "ceramic", lw=0.7)
    # Epsilon heat lattice, burst through the lower casing
    lattice = [(12.4, -4.5), (35.2, -3.05), (35.8, 2.6), (32, 4.6),
               (29.5, 2.2), (25.5, 5.4), (22.0, 2.4), (17.5, 4.4),
               (14.0, 1.6), (12.4, 3.0)]
    g.poly(lattice, "epsilon", lw=1.3, n=12)
    g.seam([(14, -3.2), (18.5, 0.6), (22.5, -1.6), (27, 1.8), (31, -0.8),
            (34.4, 0.8)], 1.0)
    g.seam([(19.5, -4.0), (20.5, -1.0)], 0.6)
    g.seam([(28.5, -3.4), (29.4, -0.4)], 0.6)
    g.hose([(19.5, -5.0), (19.8, -4.4)], 1.6, "epsilon", ribs=False)
    # torn station plate where the lattice came through
    g.poly([(17.2, 4.6), (18.8, 6.2), (20.3, 4.5)], "station", lw=0.6)
    g.poly([(28.6, 2.6), (29.8, 4.9), (31.2, 4.0)], "station", lw=0.6)
    # clamp bands, tension bolts, inspection tag
    for x, top in ((17.4, 12.8), (29.2, 12.4)):
        g.rect(x - 1.1, -4.4 + (x - 10) * 0.06, x + 1.1, top + 0.6,
               "station_dark", lw=0.9)
        g.rect(x - 1.5, top + 0.2, x + 1.5, top + 1.8, "station_dark",
               lw=0.6)
        g.bolt(x, top + 1.0, 0.55)
    g.chips([(16.4, 12.9), (30.2, 12.6), (18.3, 6.0)], 0.4, 5)
    g.line([(29.2, -2.8), (29.6, -5.4)], (90, 90, 90), 0.3)
    g.rect(28.6, -7.8, 31.2, -5.4, "white", lw=0.4)
    g.stencil(28.8, -6.0, "OK", 0.7)
    g.stencil(19.5, 10.4, "HOT 1400C", 1.05)
    g.stencil(19.5, 8.6, "NO BARE HANDS", 0.75)
    # anvil and striker on the breech
    g.rect(9.6, 13.0, 17.8, 16.4, "steel", chamfer=0.6, lw=1.0, n=8)
    g.rect(12.2, 16.4, 14.8, 17.6, "dark", lw=0.6)
    g.spring((10.4, 16.4), (10.4, 13.2), 4, 0.5, 0.4)
    # quench vent and its flap
    g.rect(31.4, 12.3, 34.8, 14.6, "station_dark", lw=0.8, n=15)
    g.rect(31.0, 14.6, 35.0, 15.3, "steel", deg=-12, pivot=(31.0, 14.6),
           lw=0.5)
    # mouth, cooling fins, heat tint
    g.poly([(36.6, -0.8), (47.2, 0.2), (47.2, 9.4), (37.6, 10.6)], "heat",
           lw=1.5, n=14)
    g.fins(38.2, 45.6, -2.4, 12.2, 6, "steel")
    g.rect(46.8, 2.8, 47.6, 6.8, "dark", lw=0.5)
    g.glow(47.4, 4.8, 3.0 + 1.5 * glow, 0.25 + 0.75 * glow)
    # hammer post, pawl, solenoid
    g.poly([(-10.5, 4.6), (-3.4, 4.6), (-4.4, 17.8), (-9.6, 17.8)],
           "station", lw=1.5, n=4)
    g.rect(-13.4, 9.6, -10.4, 14.6, "dark", chamfer=0.5, lw=0.8, n=7)
    g.bar((-10.6, 13.8), (-8.0, 16.2), 0.8, "steel", lw=0.5)
    g.poly([(-9.2, 15.4), (-7.0, 17.2), (-6.6, 16.0)], "steel", lw=0.5)
    g.stencil(-9.8, 7.2, "LAB 7", 0.95)
    # the hammer: arm, head, replaceable face
    px, py = -6.8, 17.0
    hx, hy = px + 19.5 * math.cos(a), py + 19.5 * math.sin(a)
    g.bar((px, py), (hx, hy), 3.0, "steel", lw=1.4, n=5)
    g.line([(px + 3 * math.cos(a), py + 3 * math.sin(a)),
            (hx - 4 * math.cos(a), hy - 4 * math.sin(a))], (90, 92, 96),
           0.45)
    head = dk.rot([(hx - 4.0, hy - 3.6), (hx + 4.0, hy - 3.6),
                   (hx + 4.0, hy + 3.8), (hx - 4.0, hy + 3.8)], hx, hy,
                  math.degrees(a))
    g.poly(head, "steel", lw=1.5)
    face = dk.rot([(hx - 4.0, hy - 3.6), (hx + 4.0, hy - 3.6),
                   (hx + 4.0, hy - 2.2), (hx - 4.0, hy - 2.2)], hx, hy,
                  math.degrees(a))
    g.poly(face, "dark", lw=0.6)
    for k in (-2.2, 2.2):
        bx, by = dk.rot([(hx + k, hy + 1.4)], hx, hy, math.degrees(a))[0]
        g.bolt(bx, by, 0.5)
    # re-cock gas strut: frame to 9 cm along the arm
    sx, sy = px + 9 * math.cos(a), py + 9 * math.sin(a)
    g.strut((-1.0, 5.4), (sx, sy), 0.5, 0.95, 0.4, n=6)
    # pivot and castellated nut
    g.circle(px, py, 2.4, "steel", lw=1.0)
    g.bolt(px, py, 1.1)
    g.anchor(16, -15.3, 6.0)
    return g


def foundry_cutaway(glow=1.0):
    """The power train in section: core -> lattice -> lining -> slug."""
    g = dk.D("Foundry cutaway")
    g.poly([(10, -4.6), (36, -3.0), (37.6, 12.2), (11, 13.0)], "station",
           lw=1.6, hatch=True)
    g.poly([(13, -1.8), (34, -0.6), (35.2, 9.6), (13.6, 10.2)], "ceramic",
           lw=1.0, hatch=True)
    g.poly([(15.5, 1.2), (33.4, 2.2), (34.0, 7.4), (15.8, 7.6)], "dark",
           lw=0.8)
    g.glow(26, 4.6, 9, 0.9 * glow + 0.1)
    g.rect(24.0, 3.0, 31.0, 6.4, "slug", chamfer=0.8, lw=0.8)
    g.glow(28, 4.7, 3, 0.9 * glow)
    g.rect(9.6, 13.0, 17.8, 16.4, "steel", chamfer=0.6, lw=1.0)
    g.bar((15.0, 4.8), (23.6, 4.8), 1.6, "steel", lw=0.8)
    g.bar((13.4, 14.0), (15.0, 4.8), 1.4, "steel", lw=0.8)
    g.poly([(36.6, -0.8), (47.2, 0.2), (47.2, 9.4), (37.6, 10.6)], "heat",
           lw=1.4, hatch=True)
    g.rect(35.0, 3.0, 47.4, 6.6, "dark", lw=0.6)
    g.poly([(12.4, -4.5), (35.2, -3.05), (35.6, -1.0), (12.6, -2.2)],
           "epsilon", lw=1.0)
    g.seam([(14, -3.4), (34, -2.0)], 1.0)
    g.rect(13, -11.4, 25, -6.2, "echo", chamfer=1.2, lw=1.2)
    g.energy([(19.0, -6.4), (19.6, -3.0), (22, -0.9)], 1.2)
    g.energy([(24, -1.2), (26, 2.4)], 1.2)
    g.energy([(13.6, 15.2), (14.6, 9.4)], 1.0)
    g.energy([(31.4, 4.7), (46, 4.7)], 1.2)
    return g


def foundry_exploded():
    """The hammer group, pulled apart along its pivot axis."""
    g = dk.D("Foundry hammer group, exploded")
    g.poly([(0, 0), (7, 0), (6, 13.2), (1, 13.2)], "station", lw=1.4)
    g.bar((14, 12), (32, 12), 3.0, "steel", lw=1.4)
    g.rect(32, 8.4, 40, 15.8, "steel", lw=1.4)
    g.rect(32, 6.4, 40, 7.8, "dark", lw=0.8)
    g.bolt(34, 14, 0.5)
    g.bolt(38, 14, 0.5)
    g.circle(14, 12, 2.4, "steel", lw=1.0)
    g.rect(-6, 11.4, 2.5, 12.6, "steel", lw=0.6)
    g.bolt(-7.6, 12, 1.1)
    g.strut((15, 0.5), (26, 6.5), 0.5, 0.95, 0.4)
    g.poly([(-4, 3), (-1.5, 5), (-1.2, 3.6)], "steel", lw=0.5)
    g.rect(-9, -1, -6, 4, "dark", lw=0.8)
    for a, b in (((2.5, 12), (11.6, 12)), ((-6, 12), (-7.6, 12)),
                 ((36, 7.8), (36, 6.4)), ((7, 4), (15, 0.5))):
        g.line([a, b], (120, 120, 120), 0.4, dash=True)
    g.stencil(-9.4, 6.2, "pawl + solenoid", 1.0)
    g.stencil(-9.6, 10.4, "pin + nut", 1.0)
    g.stencil(32.0, 4.9, "face (wear part)", 1.0)
    g.stencil(17.0, -1.2, "re-cock strut", 1.0)
    return g



# ===================================================================
# SIGHTLINE -- resonant tines
# ===================================================================

SIGHTLINE_PARTS = [
    (1, "your device", "yours", "mounting", "the trigger and the power"),
    (2, "cam clamps", "station", "mounting", "tool-free fit to the device"),
    (3, "chassis spine and brace", "station", "structural",
     "a slim, slotted spine; the brace steadies the long lever arm"),
    (4, "isolation mounts", "station", "mechanical",
     "rubber bushings: the tines ring, the gun doesn't. WHY ITS KICK IS "
     "SMALL"),
    (5, "resonator yoke", "station", "structural",
     "a machined block the tines root in; holds their spacing"),
    (6, "tension screws", "station", "maintenance",
     "micrometer adjusters with knurled caps: tuning the pair"),
    (7, "resonance drivers", "epsilon", "energy",
     "EPSILON: grip the tine roots and drive them; seams pulse with the "
     "ring"),
    (8, "Echo core (tuning seed)", "echo", "energy",
     "THE VISITING WORLD: sets the frequency; caged because it is "
     "brittle"),
    (9, "tines (spring steel)", "station", "mechanical",
     "side by side; tapered so they ring cleanly; you aim down the slot"),
    (10, "node damper pads", "station", "mechanical",
     "clamped at the vibration nodes; stop the ring in 0.4 s = the "
     "cadence"),
    (11, "bead feeder", "station", "mechanical",
     "tube and escapement under the yoke; one bead per cycle into the "
     "slot"),
    (12, "the bead", "energy", "readout",
     "the round; rides forward as the ring decays: ready when it's home"),
    (13, "front posts, windage screw", "station", "readout",
     "a sight at the tips; the rear notch is on the yoke"),
    (14, "tip guards", "station", "safety",
     "capped tips: a bent tine detunes the gun"),
    (15, "range scale", "station", "readout",
     "etched marks along the tine, 20 / 40 / 60 m (proposal)"),
    (16, "cable loom", "station", "energy", "device to the drivers"),
]


def sightline(bead=1.0, ring=0.0, labels=True):
    g = dk.D("Sightline")
    _device(g, -2, 0)
    _clamps(g, (-10, 2), 0)
    # cable loom first: it runs BEHIND the parts
    g.hose([(-14.5, -4), (-12.0, 2.0), (6.0, 2.6), (14.0, 6.0)], 0.6, "dark",
           ribs=False)
    g.anchor(16, -13.4, 2.2)
    # brace and spine
    g.poly([(-14, 0.5), (-22, -3.6), (-23.2, -9.6), (-20.4, -9.6),
            (-19.6, -5.0), (-14, -2.2)], "station_dark", lw=1.2)
    g.rect(-14, -2.4, 6, 3.2, "station", chamfer=0.6, lw=1.4, n=3)
    for x in (-10, -6, -2):
        g.rect(x - 1.2, -0.6, x + 1.2, 1.6, "dark", chamfer=0.4, lw=0.4)
    g.chips([(-13.6, 2.8), (5.6, 2.8)], 0.4, 7)
    # isolation mounts, yoke, tension screws
    g.rect(4.4, 3.2, 6.6, 5.0, "rubber", lw=0.6, n=4)
    g.rect(4.4, -2.0, 6.6, -0.2, "rubber", lw=0.6)
    g.rect(6.4, -3.4, 13.6, 10.4, "station_dark", chamfer=0.8, lw=1.5,
           n=5)
    for y in (2.0, 7.0):
        g.rect(3.0, y - 0.9, 6.4, y + 0.9, "steel", lw=0.6)
        g.rect(1.4, y - 1.2, 3.0, y + 1.2, "dark", lw=0.6,
               n=6 if y == 7.0 else None)
        for k in range(3):
            g.line([(1.8 + k * 0.5, y - 1.1), (1.8 + k * 0.5, y + 1.1)],
                   (150, 150, 150), 0.25)
    g.stencil(7.0, 1.0, "TUNE", 0.85)
    # rear notch on the yoke
    g.poly([(8.6, 10.4), (11.4, 10.4), (11.4, 12.0), (10.4, 12.0),
            (10.0, 11.0), (9.6, 12.0), (8.6, 12.0)], "steel", lw=0.6)
    # Echo core: a caged seed on the yoke
    g.poly([(7.2, 10.4), (8.2, 14.2), (7.6, 16.6), (6.6, 14.0)], "echo",
           lw=1.0, n=8)
    for x in (6.0, 8.8):
        g.rect(x - 0.3, 10.4, x + 0.3, 16.8, "steel", lw=0.3)
    g.rect(5.6, 16.6, 9.2, 17.2, "steel", lw=0.3)
    # tines: the far one hidden (dashed), the near one drawn
    amp = 1.2 * ring
    g.line([(13.6, 7.4), (74.0, 4.8 + amp * 0.6)], (110, 110, 110), 0.5,
           dash=True)
    for k, off in ((1, amp), (2, -amp)) if amp else ():
        g.poly([(13.6, 4.4), (74, 2.8 + off), (74, 3.8 + off),
                (13.6, 6.6)], "steel", lw=0.3, alpha=70)
    g.poly([(13.6, 4.4), (74, 2.8), (74, 3.8), (13.6, 6.6)], "steel",
           lw=1.3, n=9)
    for x, lab in ((30, "20"), (46, "40"), (62, "60")):
        yb = 4.4 - (x - 13.6) / 60.4 * 1.6
        g.line([(x, yb + 1.9), (x, yb + 2.5)], (60, 60, 60), 0.3)
        g.stencil(x - 0.6, yb + 4.0, lab, 0.7)
    g.anchor(15, 46, 5.8)
    # Epsilon drivers grip the roots
    g.poly([(13.4, 3.0), (19.6, 3.6), (21.2, 5.2), (20.0, 7.6), (16.8, 9.6),
            (13.4, 9.0)], "epsilon", lw=1.2, n=7)
    g.seam([(14.4, 4.0), (16.6, 6.0), (15.2, 8.2)], 0.9 if ring else 0.6)
    g.seam([(18.6, 4.4), (19.8, 6.0)], 0.6)
    # node dampers
    for x in (34.0, 54.0):
        yb = 4.4 - (x - 13.6) / 60.4 * 1.6
        g.rect(x - 1.1, yb - 1.2, x + 1.1, yb + 2.4, "rubber", lw=0.6,
               n=10 if x == 34.0 else None)
        g.bolt(x, yb + 0.6, 0.35)
    # front posts, tip guard
    g.rect(71.4, 3.8, 72.6, 6.6, "steel", lw=0.6, n=13)
    g.screw(72.0, 7.1, 0.45)
    g.rect(74.0, 2.4, 75.6, 4.2, "rubber", chamfer=0.4, lw=0.7, n=14)
    # bead feeder under the yoke
    g.rect(8.0, -7.2, 22.0, -3.6, "station", chamfer=0.6, lw=1.0, n=11)
    g.circle(19.0, -5.4, 1.4, "steel", n_sides=12, lw=0.5)
    for k in range(6):
        aa = 2 * math.pi * k / 6
        g.line([(19.0, -5.4), (19 + 1.4 * math.cos(aa),
                               -5.4 + 1.4 * math.sin(aa))], INK, 0.25)
    for x in (10.0, 12.2, 14.4):
        g.circle(x, -5.4, 0.8, "glass", n_sides=12, lw=0.4)
    g.bar((20.4, -4.0), (22.6, 3.6), 1.0, "station_dark", lw=0.5)
    # the bead in the slot
    if bead is not None and bead >= 0:
        bx = 22.0 + 49.0 * bead
        g.circle(bx, 4.2 - (bx - 13.6) / 60.4 * 1.0, 0.9, "glass",
                 n_sides=14, lw=0.5, n=12)
        g.glow(bx, 4.2 - (bx - 13.6) / 60.4 * 1.0, 2.6, 0.8,
               (210, 225, 255))
    if ring > 0.5:
        g.glow(74.6, 3.2, 4, 0.9, (225, 235, 255))
    return g


def sightline_cutaway(ring=0.0):
    g = dk.D("Sightline yoke, in section")
    g.rect(6.4, -3.4, 13.6, 10.4, "station_dark", chamfer=0.8, lw=1.4,
           hatch=True)
    g.rect(8.0, 3.4, 13.8, 7.8, "steel", lw=0.8)
    g.poly([(13.4, 3.0), (19.6, 3.6), (21.2, 5.2), (20.0, 7.6), (16.8, 9.6),
            (13.4, 9.0)], "epsilon", lw=1.2)
    g.seam([(14.4, 4.0), (16.6, 6.0), (15.2, 8.2)], 1.0)
    g.poly([(7.2, 10.4), (8.2, 14.2), (7.6, 16.6), (6.6, 14.0)], "echo",
           lw=1.0)
    g.poly([(13.6, 4.4), (40, 3.7), (40, 4.7), (13.6, 6.6)], "steel",
           lw=1.2)
    g.rect(8.0, -7.2, 22.0, -3.6, "station", chamfer=0.6, lw=1.0,
           hatch=True)
    g.circle(19.0, -5.4, 1.4, "steel", n_sides=12, lw=0.5)
    g.circle(26, 4.4, 0.9, "glass", n_sides=14, lw=0.5)
    g.energy([(7.4, 13.0), (9.6, 9.4), (15.0, 6.4)], 1.1)
    g.energy([(17.5, 5.4), (30, 4.6), (39, 4.4)], 1.1)
    g.energy([(19.8, -3.6), (21.4, 2.6), (24.6, 4.3)], 0.9)
    return g


def sightline_exploded():
    g = dk.D("Sightline tine set, exploded")
    g.rect(0, 0, 7, 13.8, "station_dark", chamfer=0.8, lw=1.4)
    g.poly([(11, 2.2), (17, 2.8), (18.6, 4.4), (17.4, 6.8), (14.2, 8.8),
            (11, 8.2)], "epsilon", lw=1.2)
    g.seam([(12, 3.4), (14.2, 5.4), (12.8, 7.6)], 0.6)
    g.poly([(22, 3.6), (52, 2.8), (52, 3.8), (22, 5.8)], "steel", lw=1.2)
    for x in (32, 44):
        g.rect(x - 1.1, -1.4, x + 1.1, 1.4, "rubber", lw=0.6)
    g.rect(56, 2.6, 57.6, 4.4, "rubber", chamfer=0.4, lw=0.7)
    for a, b in (((7, 5), (11, 5)), ((18.6, 5), (22, 4.8)),
                 ((32, 1.4), (32, 3.3)), ((44, 1.4), (44, 3.0)),
                 ((52, 3.3), (56, 3.4))):
        g.line([a, b], (120, 120, 120), 0.4, dash=True)
    g.stencil(0.0, -2.0, "yoke", 1.0)
    g.stencil(11.0, -0.4, "driver", 1.0)
    g.stencil(30.0, -3.0, "node pads", 1.0)
    g.stencil(53.0, 6.6, "guard", 1.0)
    return g


# ===================================================================
# SWITCHBACK -- governor and shuttle
# ===================================================================

SWITCHBACK_PARTS = [
    (1, "your device", "yours", "mounting", "the trigger and the power"),
    (2, "cam clamps", "station", "mounting", "tool-free fit"),
    (3, "receiver", "station", "structural", "carries the motor, the "
     "shuttle and the forward housing"),
    (4, "motor", "epsilon", "energy",
     "EPSILON: turns the core's output into rotation; lit at its seams"),
    (5, "Echo core (rotor)", "echo", "energy",
     "THE VISITING WORLD: the rotor, seen through the motor's window"),
    (6, "flyball governor", "station", "readout",
     "spindle, arms, weighted balls: THE SPREAD YOU CAN SEE"),
    (7, "throttle linkage", "station", "mechanical",
     "the governor's sleeve pulls the motor's throttle: it really "
     "regulates"),
    (8, "shuttle, rails, buffers", "station", "mechanical",
     "switches back and forth; rubber buffers take each reversal"),
    (9, "feed rod and guide rollers", "station", "mechanical",
     "plain bar stock fed through the brace: no magazine, no reload"),
    (10, "cutter", "station", "mechanical",
     "chops a slug from the rod each stroke"),
    (11, "twin ports, perforated shrouds", "heat", "thermal",
     "the only weapon that runs hot under sustained fire: it breathes"),
    (12, "slotted flash hiders", "steel", "thermal",
     "break up the flash so held fire doesn't blind the player"),
    (13, "brace, detent holes", "station", "structural",
     "a short adjustable brace (D-21's stock)"),
    (14, "cable loom", "station", "energy", "device to the motor"),
]


def switchback(spin=0.0, shuttle=0.0, labels=True):
    g = dk.D("Switchback")
    _device(g, 1, -2)
    _clamps(g, (-7, 5), -2)
    # cable loom first: it runs BEHIND the parts
    g.hose([(-12, -4.5), (-9, 6), (-4.5, 11.5)], 0.6, "dark", ribs=False)
    g.anchor(14, -10.6, 1.2)
    # brace with detent holes, feed rod and rollers
    g.poly([(-8, 6.5), (-22, 5.0), (-23, -6), (-19.6, -6), (-19, 2.0),
            (-8, 3.0)], "station_dark", lw=1.2, n=13)
    for x in (-17, -14, -11):
        g.circle(x, 4.6, 0.55, "dark", n_sides=10, lw=0.3)
    g.bar((-26, 0.4), (9.0, 0.4), 1.1, "steel", lw=0.7, n=9)
    for x in (-21, -12):
        g.circle(x, 1.6, 0.8, "dark", n_sides=10, lw=0.4)
        g.circle(x, -0.8, 0.8, "dark", n_sides=10, lw=0.4)
    # receiver
    g.rect(-8, -3.4, 24, 9.0, "station", chamfer=0.9, lw=1.6, n=3)
    g.chips([(-7.6, 8.6), (23.6, 8.6), (23.6, -3.0)], 0.45, 9)
    g.stencil(-6.6, -1.6, "SB-3  RATE 7/S", 0.9)
    # access panel over the cutter (maintenance), four screws
    g.rect(-5.0, 1.0, 5.4, 7.4, "station", chamfer=0.4, lw=0.6)
    for x, y in ((-4.2, 1.8), (4.6, 1.8), (-4.2, 6.6), (4.6, 6.6)):
        g.screw(x, y, 0.4)
    g.stencil(-3.8, 4.0, "ROD FEED >", 0.75)
    # shuttle rails and shuttle with buffers
    g.rect(8.0, 1.0, 22.0, 4.2, "dark", lw=0.7)
    g.line([(8.2, 1.6), (21.8, 1.6)], (140, 140, 140), 0.3)
    g.line([(8.2, 3.6), (21.8, 3.6)], (140, 140, 140), 0.3)
    for x in (8.0, 20.8):
        g.rect(x, 1.2, x + 1.2, 4.0, "rubber", lw=0.4)
    sx = 9.6 + 8.0 * shuttle
    g.rect(sx, 1.3, sx + 3.2, 3.9, "steel", chamfer=0.3, lw=0.8, n=8)
    g.travel_line((10.4, 5.0), (19.4, 5.0))
    g.rect(7.0, -0.6, 9.4, 2.0, "dark", chamfer=0.3, lw=0.6, n=10)
    # motor (Epsilon) with the core rotor in its window
    g.poly([(-6, 9.0), (8, 9.0), (9.4, 11.0), (8.4, 15.2), (2.4, 16.4),
            (-4.6, 15.0), (-6.4, 12.0)], "epsilon", lw=1.4, n=4)
    g.seam([(-5.2, 10.4), (-2.0, 14.6)], 0.6 + 0.4 * spin)
    g.seam([(6.6, 10.0), (7.8, 13.8)], 0.6 + 0.4 * spin)
    for x in (-4.6, 7.2):
        g.bolt(x, 9.8, 0.5)
    g.circle(1.2, 12.6, 2.6, "dark", n_sides=18, lw=0.8)
    g.circle(1.2, 12.6, 2.0, "echo", n_sides=18, lw=0.5, n=5)
    for k in range(4):
        aa = 2 * math.pi * k / 4 + spin * 2.0
        g.line([(1.2, 12.6), (1.2 + 1.8 * math.cos(aa),
                              12.6 + 1.8 * math.sin(aa))], INK, 0.3)
    # governor on top of the motor, linked to the throttle
    th = math.radians(14 + 58 * spin)
    top = (1.2, 32.0)
    g.bar((1.2, 16.4), top, 1.0, "steel", lw=0.7)
    g.circle(top[0], top[1] + 0.6, 1.2, "steel", n_sides=12, lw=0.6)
    sleeve = 20.0 + 5.0 * spin
    g.rect(0.0, sleeve - 0.9, 2.4, sleeve + 0.9, "dark", lw=0.6)
    for side in (-1, 1):
        bxp = top[0] + side * 13 * math.sin(th)
        byp = top[1] - 13 * math.cos(th)
        g.bar(top, (bxp, byp), 0.6, "steel", lw=0.5)
        mx = top[0] + side * 6.5 * math.sin(th)
        my = top[1] - 6.5 * math.cos(th)
        g.bar((1.2 + side * 1.1, sleeve), (mx, my), 0.4, "steel", lw=0.4)
        g.circle(bxp, byp, 2.3, "steel", n_sides=18, lw=1.1,
                 n=6 if side == 1 else None)
    if spin > 0.2:
        g.travel(top[0], top[1], 13.0, -90 + 14, -90 + 14 + 58 * spin)
    # throttle linkage: the sleeve's collar down to the motor's lever
    g.bar((2.4, sleeve), (6.0, sleeve - 1.0), 0.5, "station_dark", lw=0.4)
    g.bar((6.0, sleeve - 1.0), (7.6, 15.0), 0.5, "station_dark", lw=0.4,
          n=7)
    g.bar((7.6, 15.0), (9.8, 13.6), 0.6, "steel", lw=0.4)
    # forward housing: perforated shrouds, twin ports, flash hiders
    g.rect(24, -2.4, 36, 8.0, "heat", chamfer=0.6, lw=1.5, n=11)
    for x in (26, 28.5, 31, 33.5):
        for y in (-0.6, 2.6, 5.8):
            g.circle(x, y, 0.65, "dark", n_sides=10, lw=0.3)
    g.rect(36, 1.0, 43, 5.6, "steel", lw=1.2, n=12)
    for x in (37.5, 39.5, 41.5):
        g.rect(x - 0.4, 1.0, x + 0.4, 2.4, "dark", lw=0)
        g.rect(x - 0.4, 4.2, x + 0.4, 5.6, "dark", lw=0)
    g.glow(43.2, 3.3, 2.5, 0.2 + 0.6 * shuttle)
    return g


def switchback_cutaway(spin=1.0):
    g = dk.D("Switchback receiver, in section")
    g.rect(-8, -3.4, 24, 9.0, "station", chamfer=0.9, lw=1.4, hatch=True)
    g.poly([(-6, 9.0), (8, 9.0), (9.4, 11.0), (8.4, 15.2), (2.4, 16.4),
            (-4.6, 15.0), (-6.4, 12.0)], "epsilon", lw=1.4)
    g.circle(1.2, 12.6, 2.0, "echo", n_sides=18, lw=0.5)
    g.rect(-6, 3.0, 8, 7.0, "dark", lw=0.6)
    g.rect(3.0, 3.6, 7.0, 6.4, "steel", lw=0.5)
    g.bar((-8, 0.4), (9.0, 0.4), 1.1, "steel", lw=0.7)
    g.rect(7.0, -0.6, 9.4, 2.0, "dark", chamfer=0.3, lw=0.6)
    g.rect(14, 1.3, 17.2, 3.9, "steel", chamfer=0.3, lw=0.8)
    g.rect(24, -2.4, 36, 8.0, "heat", chamfer=0.6, lw=1.4, hatch=True)
    g.rect(24, 1.6, 43, 4.8, "dark", lw=0.6)
    g.energy([(1.2, 12.6), (5.0, 5.0)], 1.1)
    g.energy([(5.4, 5.0), (8.2, 1.4)], 1.0)
    g.energy([(9.4, 0.8), (14.6, 2.4)], 1.0)
    g.energy([(17.4, 3.0), (42.6, 3.2)], 1.1)
    g.energy([(-7.6, 0.4), (6.8, 0.4)], 0.8)
    return g


def switchback_exploded():
    g = dk.D("Switchback governor, exploded")
    g.bar((0, 0), (0, 22), 1.0, "steel", lw=0.7)
    g.circle(0, 23.2, 1.2, "steel", n_sides=12, lw=0.6)
    for side in (-1, 1):
        g.bar((side * 3, 22), (side * 12, 12), 0.6, "steel", lw=0.5)
        g.circle(side * 13, 11, 2.3, "steel", n_sides=18, lw=1.1)
        g.bar((side * 3, 6), (side * 7, 13), 0.4, "steel", lw=0.4)
    g.rect(-1.2, 3.6, 1.2, 5.4, "dark", lw=0.6)
    g.bar((6, 1), (10, 0), 0.5, "station_dark", lw=0.4)
    g.bar((10, 0), (11.6, -6), 0.5, "station_dark", lw=0.4)
    g.bar((11.6, -6), (14, -7.4), 0.6, "steel", lw=0.4)
    for a, b in (((0, 5.4), (0, 8)), ((1.2, 4.5), (6, 1.4))):
        g.line([a, b], (120, 120, 120), 0.4, dash=True)
    g.stencil(-12, 18.6, "arms + flyballs", 1.0)
    g.stencil(-11, 4.2, "sleeve", 1.0)
    g.stencil(4, -9.6, "to throttle", 1.0)
    return g


# ===================================================================
# BULKHEAD -- pressure hatch
# ===================================================================

BULKHEAD_PARTS = [
    (1, "your device", "yours", "mounting", "the trigger and the power"),
    (2, "cam clamps", "station", "mounting", "tool-free fit"),
    (3, "cradle and shock absorbers", "station", "structural",
     "the drum rides on two dampers: the heavy kick has a cause and a "
     "limit"),
    (4, "Echo core (pressure charge)", "echo", "energy",
     "THE VISITING WORLD: a canister in the rear cap, bayonet-locked"),
    (5, "compressor", "epsilon", "energy",
     "EPSILON: a membrane pump that turns the core's output into "
     "pressure"),
    (6, "charge hose", "station", "energy",
     "compressor to drum, braided, clamped"),
    (7, "pressure drum and hoops", "station", "structural",
     "a station vessel; the hoops carry the hoop stress"),
    (8, "relief valve", "station", "safety",
     "a sprung poppet: over-pressure vents up, never at the player"),
    (9, "gauge", "glass", "readout", "drum pressure: a second ready cue"),
    (10, "hatch flange", "station", "structural",
     "wider than the drum; seen from behind, it frames it"),
    (11, "eight nozzle inserts", "steel", "maintenance",
     "one per pellet; screw-in wear parts"),
    (12, "dogging lever and cam ring", "station", "mechanical",
     "the lever turns the ring; the ring drives the dogs. Swings up to "
     "vent"),
    (13, "four dogs", "steel", "mechanical",
     "lock the hatch against the drum's pressure"),
    (14, "hatch hinge", "station", "maintenance",
     "the hatch opens to change nozzles"),
    (15, "cable loom", "station", "energy", "device to the compressor"),
]


def bulkhead(lever=0.0, vent=0.0, labels=True):
    g = dk.D("Bulkhead")
    _device(g, 4, -8)
    _clamps(g, (-4, 8), -8)
    # cable loom first: it runs BEHIND the parts
    g.hose([(-7.0, -10.5), (-8.0, -6.6), (-1.2, -11.6), (1.6, -11.0)], 0.6,
           "dark", ribs=False)
    g.anchor(15, -7.6, -8.4)
    # cradle and shock absorbers from the device mount to the drum
    g.rect(-6, -9.0, 26, -7.0, "station_dark", lw=1.1, n=3)
    g.strut((-1, -7.2), (3, -5.2), 0.5, 0.8, 0.35)
    g.strut((19, -7.2), (23, -5.4), 0.5, 0.8, 0.35)
    # rear cap with the Echo canister
    g.rect(-6, -5.4, 2.4, 8.4, "station", chamfer=1.0, lw=1.5)
    g.rect(-9, -2.8, -4.8, 6.0, "echo", chamfer=1.2, lw=1.2, n=4)
    for y in (-1.6, 4.6):
        g.rect(-9.6, y - 0.6, -8.4, y + 0.6, "steel", lw=0.4)
    # drum and hoops
    g.poly([(2.4, -6.2), (30, -7.0), (30, 9.4), (2.4, 8.6)], "station",
           lw=1.7, n=7)
    for x in (8, 15, 22):
        g.rect(x - 0.9, -6.6 - x * 0.02, x + 0.9, 9.0 + x * 0.02,
               "station_dark", lw=0.8)
        g.bolt(x, -5.6, 0.4)
    g.chips([(2.8, 8.2), (29.6, 9.0), (8.8, 8.9), (22.8, 9.1)], 0.45, 11)
    g.stencil(9.6, 6.0, "MAX 40 BAR", 1.0)
    g.stencil(9.6, 4.2, "VENT FORWARD", 0.75)
    # gauge
    g.circle(18.4, 1.2, 2.6, "steel", n_sides=20, lw=0.9)
    g.circle(18.4, 1.2, 2.0, "glass", n_sides=20, lw=0.4, n=9)
    pa = math.radians(200 - 150 * (1.0 - vent))
    g.line([(18.4, 1.2), (18.4 + 1.7 * math.cos(pa),
                          1.2 + 1.7 * math.sin(pa))], (160, 40, 30), 0.4)
    # compressor (Epsilon) under the rear of the drum, and its hose
    g.poly([(1.0, -6.2), (13.0, -6.4), (14.6, -8.4), (12.2, -12.6),
            (3.4, -12.8), (0.4, -9.8)], "epsilon", lw=1.3, n=5)
    g.seam([(2.4, -8.0), (6.4, -11.4), (10.6, -8.4), (13.0, -10.6)],
           0.7 + 0.3 * vent)
    g.hose([(14.2, -9.4), (17.6, -9.0), (19.4, -6.4)], 1.1, "rubber")
    g.anchor(6, 16.4, -9.0)
    g.rect(18.8, -6.8, 20.4, -6.0, "steel", lw=0.4)
    # relief valve
    g.rect(25.2, 9.2, 27.0, 11.6, "steel", lw=0.6, n=8)
    g.spring((26.1, 11.6), (26.1, 13.2), 3, 0.6, 0.35)
    g.rect(25.0, 13.2, 27.2, 13.8, "steel", lw=0.4)
    # cam ring, hatch flange, dogs, nozzles, hinge
    g.rect(28.0, -7.4, 30.0, 9.8, "dark", lw=0.8)
    g.rect(30.0, -13, 34.0, 15.4, "station", chamfer=0.8, lw=1.7, n=10)
    for y in (-11.6, 14.0):
        g.rect(28.4, y - 0.9, 30.0, y + 0.9, "steel", lw=0.6,
               n=13 if y == 14.0 else None)
    for y in (-8.2, -2.2, 4.0, 10.2):
        g.rect(34.0, y - 0.9, 35.8, y + 0.9, "steel", lw=0.6,
               n=11 if y == 4.0 else None)
        g.rect(35.8, y - 0.5, 36.2, y + 0.5, "dark", lw=0)
    g.rect(30.4, 15.4, 33.6, 16.8, "station_dark", lw=0.6, n=14)
    g.circle(32.0, 16.1, 0.6, "steel", n_sides=10, lw=0.3)
    # the dogging lever on top, pivot on the cam ring
    la = math.radians(180 - lever)
    px, py = 29.0, 11.4
    ex, ey = px + 22 * math.cos(la), py + 22 * math.sin(la)
    g.bar((px, py), (ex, ey), 1.5, "steel", lw=1.0, n=12)
    g.circle(ex, ey, 1.4, "rubber", n_sides=12, lw=0.6)
    g.circle(px, py, 1.5, "dark", n_sides=12, lw=0.6)
    g.bolt(px, py, 0.6)
    if lever:
        g.travel(px, py, 18, 180 - lever, 180)
    if vent > 0:
        g.glow(36.2, 1.0, 5 + 8 * vent, vent)
    return g


def bulkhead_cutaway(vent=0.0):
    g = dk.D("Bulkhead drum, in section")
    g.poly([(2.4, -6.2), (30, -7.0), (30, 9.4), (2.4, 8.6)], "station",
           lw=1.6, hatch=True)
    g.poly([(4.0, -4.4), (28.4, -5.2), (28.4, 7.6), (4.0, 6.8)], "dark",
           lw=0.6)
    g.rect(-6, -5.4, 2.4, 8.4, "station", chamfer=1.0, lw=1.4, hatch=True)
    g.rect(-9, -2.8, -4.8, 6.0, "echo", chamfer=1.2, lw=1.2)
    g.poly([(1.0, -6.2), (13.0, -6.4), (14.6, -8.4), (12.2, -12.6),
            (3.4, -12.8), (0.4, -9.8)], "epsilon", lw=1.3)
    g.rect(30.0, -13, 34.0, 15.4, "station", chamfer=0.8, lw=1.6,
           hatch=True)
    for y in (-8.2, -2.2, 4.0, 10.2):
        g.rect(29.8, y - 0.7, 36.2, y + 0.7, "dark", lw=0.4)
    g.energy([(-6.8, -2.6), (-4, -8.0), (2.6, -9.6)], 1.1)
    g.energy([(13.2, -9.8), (18, -8.6), (19, -4.0)], 1.1)
    g.energy([(10, 1.0), (27, 1.0)], 1.2)
    for y in (-8.2, -2.2, 4.0, 10.2):
        g.energy([(34.6, y), (40, y + y * 0.15)], 0.8)
    return g


def bulkhead_exploded():
    g = dk.D("Bulkhead hatch group, exploded")
    g.rect(0, -13, 4, 15.4, "station", chamfer=0.8, lw=1.6)
    g.rect(-8, -7.4, -6, 9.8, "dark", lw=0.8)
    for y in (-11.6, 14.0):
        g.rect(-14, y - 0.9, -12.4, y + 0.9, "steel", lw=0.6)
    for y in (-8.2, -2.2, 4.0, 10.2):
        g.rect(9, y - 0.9, 10.8, y + 0.9, "steel", lw=0.6)
    g.bar((-7, 11.4), (-26, 11.4), 1.5, "steel", lw=1.0)
    g.circle(-26, 11.4, 1.4, "rubber", n_sides=12, lw=0.6)
    g.rect(0.4, 17.4, 3.6, 18.8, "station_dark", lw=0.6)
    for a, b in (((4, 1), (9, 1)), ((-6, 1), (0, 1)), ((-12.4, 14), (-8, 9)),
                 ((2, 15.4), (2, 17.4))):
        g.line([a, b], (120, 120, 120), 0.4, dash=True)
    g.stencil(-11, -9.6, "cam ring", 1.0)
    g.stencil(-17, 16.6, "dogs (4)", 1.0)
    g.stencil(8.4, -11.4, "nozzles (8)", 1.0)
    g.stencil(-25, 13.8, "dogging lever", 1.0)
    return g


# ===================================================================
# MASS DRIVER -- flywheel and clutch
# ===================================================================

MASSDRIVER_PARTS = [
    (1, "your device", "yours", "mounting", "the trigger and the power"),
    (2, "cam clamps", "station", "mounting", "tool-free fit"),
    (3, "gimbal mount", "station", "mechanical",
     "the flywheel group sits on a gimbal: it LEANS on its gyro, the aim "
     "doesn't"),
    (4, "flywheel, balance weights", "station", "mechanical",
     "the store: spokes, then blur, then solid = charge; balanced"),
    (5, "Echo core (hub)", "echo", "energy",
     "THE VISITING WORLD: the dense core at the hub, where the mass is"),
    (6, "field drive segments", "epsilon", "energy",
     "EPSILON: spins the wheel without touching it; set in the guard"),
    (7, "guard ring", "station", "safety",
     "a spinning wheel beside the player's head gets a guard"),
    (8, "dog clutch and fork", "station", "mechanical",
     "bangs in on release: the wheel stops dead, the slug goes"),
    (9, "clutch solenoid", "station", "mechanical",
     "the device's release signal throws the fork"),
    (10, "brake band and lever", "station", "safety",
     "power-down: bleeds the rest of the spin after a tap"),
    (11, "launch channel and rails", "station", "structural",
     "open on top so the slug is seen; reinforced at the mouth"),
    (12, "sabot slug", "steel", "mechanical",
     "plain station stock in a carrier that grips the rails"),
    (13, "hopper and gate", "station", "mechanical",
     "drops the next slug when the clutch resets"),
    (14, "cable loom", "station", "energy", "device to drive and solenoid"),
]


def massdriver(spin=0.0, slug=True, labels=True):
    g = dk.D("Mass Driver")
    _device(g, 4, -4)
    _clamps(g, (-4, 8), -4)
    # cable loom first: it runs BEHIND the parts
    g.hose([(-11.0, -6.0), (-12.5, 3.0), (-17.2, 9.0)], 0.6, "dark",
           ribs=False)
    g.hose([(1.0, -2.0), (8.0, 1.0), (12.4, 18.0)], 0.6, "dark",
           ribs=False)
    g.anchor(14, -12.4, 1.0)
    # frame and gimbal under the flywheel
    g.rect(-8, -5.2, 14, 1.6, "station", chamfer=0.8, lw=1.5)
    g.poly([(-6.2, 1.6), (0.2, 1.6), (-1.6, 5.4), (-4.4, 5.4)],
           "station_dark", lw=1.0, n=3)
    g.circle(-3.0, 5.4, 1.4, "steel", n_sides=12, lw=0.7)
    g.bolt(-3.0, 5.4, 0.6)
    # brake band and lever around the lower rim
    g.line(dk.arc_pts(-3.0, 9.0, 15.4, 200, 320, 14), (60, 62, 66), 1.0)
    g.bar((-15.6, 0.0), (-19.6, -5.4), 1.1, "steel", lw=0.6, n=10)
    g.circle(-19.6, -5.4, 1.0, "rubber", n_sides=10, lw=0.5)
    # guard ring (station) with the Epsilon field-drive segments
    g.circle(-3.0, 9.0, 15.0, "station_dark", n_sides=36, lw=1.5, n=7)
    g.circle(-3.0, 9.0, 13.6, "dark", n_sides=36, lw=0.6)
    for k, a0 in enumerate((20, 80, 140, 200, 260, 320)):
        seg = dk.arc_pts(-3.0, 9.0, 15.2, a0, a0 + 32, 6) + \
            list(reversed(dk.arc_pts(-3.0, 9.0, 13.4, a0, a0 + 32, 6)))
        g.poly(seg, "epsilon", lw=0.8, n=6 if k == 1 else None)
        mid = math.radians(a0 + 16)
        g.seam([(-3.0 + 13.8 * math.cos(mid - 0.12),
                 9.0 + 13.8 * math.sin(mid - 0.12)),
                (-3.0 + 14.6 * math.cos(mid + 0.12),
                 9.0 + 14.6 * math.sin(mid + 0.12))], 0.4 + 0.6 * spin)
    # flywheel: rim, web, spokes or blur, balance weights, core hub
    g.circle(-3.0, 9.0, 12.6, "steel", n_sides=36, lw=1.4, n=4)
    g.circle(-3.0, 9.0, 10.4, "station_dark" if spin < 0.85 else "steel",
             n_sides=36, lw=0.6)
    if spin < 0.85:
        for i in range(6):
            aa = 2 * math.pi * i / 6 + 0.4 + spin
            g.bar((-3.0, 9.0), (-3.0 + 10.4 * math.cos(aa),
                                9.0 + 10.4 * math.sin(aa)), 1.8,
                  "steel" if spin < 0.35 else "station_dark",
                  lw=0.6 if spin < 0.35 else 0.2, alpha=255 if spin < 0.35
                  else 120)
    if spin > 0.3:
        for rr in (6.0, 8.5):
            g.line(dk.arc_pts(-3.0, 9.0, rr, 30, 150, 12), (90, 90, 90), 0.4,
                   dash=True)
        g.travel(-3.0, 9.0, 11.6, 200, 330)
    for k in range(4):
        aa = 2 * math.pi * k / 4 + 0.8
        g.rect(-3.0 + 11.4 * math.cos(aa) - 0.6, 9.0 + 11.4 * math.sin(aa)
               - 0.6, -3.0 + 11.4 * math.cos(aa) + 0.6,
               9.0 + 11.4 * math.sin(aa) + 0.6, "dark", lw=0.3)
    g.circle(-3.0, 9.0, 3.4, "steel", n_sides=18, lw=1.0)
    g.circle(-3.0, 9.0, 2.6, "echo", n_sides=18, lw=0.8, n=5)
    g.circle(-3.0, 9.0, 0.7, "steel", n_sides=10, lw=0.4)
    # clutch, fork and solenoid between the hub and the channel
    g.rect(6.0, 2.0, 13.0, 13.0, "dark", chamfer=0.8, lw=1.3, n=8)
    for y in (4.0, 6.5, 9.0, 11.5):
        g.rect(12.0, y - 0.6, 13.6, y + 0.6, "steel", lw=0.3)
    g.bar((9.5, 13.0), (12.0, 17.6), 0.8, "steel", lw=0.5)
    g.rect(10.0, 17.0, 15.4, 20.0, "station_dark", chamfer=0.5, lw=0.8,
           n=9)
    # launch channel, rails, mouth collar
    g.rect(13.0, -1.6, 61.0, 7.0, "station", chamfer=0.8, lw=1.6, n=11)
    g.line([(13.6, 5.6), (60.4, 5.6)], (80, 80, 80), 0.8)
    g.line([(13.6, 0.0), (60.4, 0.0)], (80, 80, 80), 0.8)
    g.rect(56.0, -2.6, 61.6, 8.0, "steel", chamfer=0.6, lw=1.2)
    for x in (20, 30, 40, 50):
        g.bolt(x, 6.4, 0.45)
    g.chips([(13.4, 6.6), (60.6, 6.6), (30.4, -1.2)], 0.45, 13)
    g.stencil(26, 2.0, "KEEP CLEAR OF WHEEL", 1.0)
    # sabot slug in the cradle
    if slug:
        g.rect(14.6, 0.6, 21.6, 5.0, "steel", chamfer=0.6, lw=1.0, n=12)
        g.rect(15.2, 1.4, 21.0, 4.2, "slug", lw=0.4)
    # hopper and gate
    g.poly([(15.0, 7.0), (24.0, 7.0), (26.4, 16.6), (12.8, 16.6)],
           "station", lw=1.2, n=13)
    g.rect(15.4, 7.0, 23.6, 8.0, "steel", lw=0.5)
    for y in (10.0, 13.0):
        g.rect(16.0, y, 23.0, y + 2.4, "slug", chamfer=0.4, lw=0.4)
    return g


def massdriver_cutaway(spin=1.0):
    g = dk.D("Mass Driver power train, in section")
    g.circle(-3.0, 9.0, 15.0, "station_dark", n_sides=36, lw=1.4,
             hatch=True)
    g.circle(-3.0, 9.0, 12.6, "steel", n_sides=36, lw=1.4)
    g.circle(-3.0, 9.0, 2.6, "echo", n_sides=18, lw=0.8)
    for a0 in (20, 80, 140, 200, 260, 320):
        seg = dk.arc_pts(-3.0, 9.0, 15.2, a0, a0 + 32, 6) + \
            list(reversed(dk.arc_pts(-3.0, 9.0, 13.4, a0, a0 + 32, 6)))
        g.poly(seg, "epsilon", lw=0.8)
    g.rect(6.0, 2.0, 13.0, 13.0, "dark", chamfer=0.8, lw=1.3, hatch=True)
    g.rect(13.0, -1.6, 61.0, 7.0, "station", chamfer=0.8, lw=1.4,
           hatch=True)
    g.rect(13.6, 0.6, 60.4, 5.0, "dark", lw=0.5)
    g.rect(30.0, 0.6, 37.0, 5.0, "steel", chamfer=0.6, lw=1.0)
    g.energy([(10.0, 22.0), (8.5, 22.0)], 1.0)
    g.energy(dk.arc_pts(-3.0, 9.0, 17.4, 60, 0, 8), 1.0)
    g.energy([(5.0, 7.6), (12.4, 7.6), (12.4, 3.0), (28.0, 2.8)], 1.1)
    g.energy([(37.6, 2.8), (60.0, 2.8)], 1.2)
    return g


def massdriver_exploded():
    g = dk.D("Mass Driver clutch, exploded")
    g.circle(0, 0, 3.4, "steel", n_sides=18, lw=1.0)
    g.circle(0, 0, 2.6, "echo", n_sides=18, lw=0.8)
    g.rect(6, -5, 9, 5, "dark", lw=1.0)
    for y in (-3.5, -1.2, 1.2, 3.5):
        g.rect(9, y - 0.5, 10.4, y + 0.5, "steel", lw=0.3)
    g.rect(14, -5, 17, 5, "dark", lw=1.0)
    for y in (-2.4, 0, 2.4):
        g.rect(12.6, y - 0.5, 14, y + 0.5, "steel", lw=0.3)
    g.bar((15.5, 5), (18, 11), 0.8, "steel", lw=0.5)
    g.rect(16.4, 11, 22, 14, "station_dark", chamfer=0.5, lw=0.8)
    for a, b in (((3.4, 0), (6, 0)), ((10.4, 0), (12.6, 0))):
        g.line([a, b], (120, 120, 120), 0.4, dash=True)
    g.stencil(-3.6, -6.2, "hub + core", 1.0)
    g.stencil(5.0, -7.4, "wheel-side dogs", 1.0)
    g.stencil(13.4, -9.0, "channel-side dogs", 1.0)
    g.stencil(17.0, 16.0, "fork + solenoid", 1.0)
    return g


INK = dk.INK

WEAPONS = {
    "foundry": {"name": "Foundry", "draw": foundry, "parts": FOUNDRY_PARTS,
                "cutaway": foundry_cutaway, "exploded": foundry_exploded,
                "states": [("ready: hammer up, the core feeding heat",
                            {"hammer": 68, "glow": 1.0}),
                           ("fire: the hammer falls on the anvil",
                            {"hammer": 2, "glow": 0.3}),
                           ("recover: the strut lifts it; the lining "
                            "re-glows", {"hammer": 34, "glow": 0.5})]},
    "sightline": {"name": "Sightline", "draw": sightline,
                  "parts": SIGHTLINE_PARTS, "cutaway": sightline_cutaway,
                  "exploded": sightline_exploded,
                  "states": [("ready: the bead home at the tips",
                              {"bead": 1.0}),
                             ("fire: the drivers snap; the tines ring",
                              {"bead": -1, "ring": 1.0}),
                             ("recover: the pads damp it; a bead rides "
                              "forward", {"bead": 0.45, "ring": 0.35})]},
    "switchback": {"name": "Switchback", "draw": switchback,
                   "parts": SWITCHBACK_PARTS, "cutaway": switchback_cutaway,
                   "exploded": switchback_exploded,
                   "states": [("idle: flyballs hang (tight spread)",
                               {"spin": 0.0}),
                              ("held: the motor runs up; balls climb",
                               {"spin": 0.5, "shuttle": 0.9}),
                              ("sustained: flung out = the widest spread",
                               {"spin": 1.0, "shuttle": 0.1})]},
    "bulkhead": {"name": "Bulkhead", "draw": bulkhead,
                 "parts": BULKHEAD_PARTS, "cutaway": bulkhead_cutaway,
                 "exploded": bulkhead_exploded,
                 "states": [("ready: dogged shut, gauge high", {}),
                            ("fire: eight nozzles vent at once",
                             {"vent": 1.0}),
                            ("recover: the lever swings up, the "
                             "compressor refills", {"lever": 70})]},
    "massdriver": {"name": "Mass Driver", "draw": massdriver,
                   "parts": MASSDRIVER_PARTS,
                   "cutaway": massdriver_cutaway,
                   "exploded": massdriver_exploded,
                   "states": [("idle: the wheel still, a slug loaded",
                               {"spin": 0.0}),
                              ("charging: the drive spins it up",
                               {"spin": 0.6}),
                              ("release: the clutch bangs; it stops dead",
                               {"spin": 0.0, "slug": False})]},
}
