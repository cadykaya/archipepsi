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


def _emissive(name, family="identity", saturation=0.92):
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


CONCEPTS = [
    ("portal_a_blast", concept_a_blast),
    ("portal_b_collar", concept_b_collar),
]


def _tex(name, canvas, rough):
    return common.make_textured_material(
        name, canvas.to_blender(name + "_tex"), roughness=rough)


def build_one(name, builder):
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
    return common.export_glb(obj, "batch001/portal/%s.glb" % name,
                             "interactable", check_flat=False)


def main():
    common.reset_scene()
    report = {}
    for name, builder in CONCEPTS:
        report[name] = build_one(name, builder)
    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch001",
                       "portal", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")


if __name__ == "__main__":
    main()
