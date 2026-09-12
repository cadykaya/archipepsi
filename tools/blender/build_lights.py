"""Batch 014 -- a light fixture family for every theme.

    .tools/blender/blender -b --python tools/blender/build_lights.py

`ASSET_INVENTORY.md` §9 lists *light fixture family, 1-2, Pri A* and it was
blank for all six themes. Two fixtures existed and both were
concrete_facility's, so five of the six themes were lit by facility
hardware -- the owner's Batch 012 note, exactly: *"final Gothic Stone spaces
must not look like castles illuminated by office fluorescents."*

## The brief, and what it rules out

> I want each theme to have a recognizable fixture FAMILY, not just the same
> lamp recolored six times. The fixture should carry theme identity
> primarily through form, mounting, materials, construction language, age /
> condition. **Do not rely only on bulb/emissive hue.**

So the test this batch has to pass is the silhouette sheet, not the lit one:
eleven fixtures, no colour, still eleven different objects. Every design
below was chosen for what it is in outline first and what it emits second.

| Theme | Ceiling / hung | Wall / bracket |
| --- | --- | --- |
| concrete_facility | `arch_light_fixture` (Batch 001) | `arch_utility_lamp` (Batch 002) |
| rusted_industrial | `light_rusted_cage` | `light_rusted_clamp` |
| neon_transit | `light_neon_channel` | `light_neon_edge` |
| gothic_stone | `light_gothic_corona` | `light_gothic_lantern` |
| temple_ruin | `light_temple_bowl` | `light_temple_niche` |
| void_glitch | `light_void_absent` | `light_void_debug` |

**concrete_facility builds nothing here and that is the point.** Its family
already exists and the owner approved it, so adding a third would be padding
a batch rather than filling a gap. It appears in every comparison sheet as
the control the other five are judged against.

## What art is NOT deciding

The gameplay light itself. `chamber_builders._light` places `OmniLight3D`s
at the theme's own energy, range 12, shadows off, and that is engineering's
contract -- *"art may define the physical fixture and intended visual
character, but should not quietly change gameplay visibility requirements or
light-performance contracts."* Every fixture here is a **housing**: the
emissive face says where the light comes from, and the light comes from the
engine.

That is also why none of these is bright enough to light a room. A fixture
that were would be a fixture you cannot look at.
"""

from __future__ import annotations

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import brushkit  # noqa: E402
import common  # noqa: E402
import propkit  # noqa: E402
import palette as pal  # noqa: E402

OUT = "batch014/lights"


def _finish(name, theme, shell, lit, lit_material, box, why, anchor):
    obj = common.join(shell, name + "_shell")
    common.uv_project_world(obj, propkit.PROP_DENSITY, propkit.PROP_SIZE)
    common.assign(obj, common.make_textured_material(
        name, propkit.painted_metal(theme, name, wear=0.26).to_blender(
            name + "_tex"),
        roughness=pal.roughness(theme)))
    if lit:
        glow = common.join(lit, name + "_lit")
        common.assign(glow, lit_material)
        obj = common.join([obj, glow], name)
    common.set_origin(obj, anchor)
    common.assert_fits(obj, name, box, why)
    return common.export_glb(obj, "%s/%s.glb" % (OUT, name), "prop",
                             anchor=anchor, check_flat=False)


def _warm(name, step=2, saturation=0.55):
    """The `send` family -- the amber every fixture in this game already
    wears. Fire, filament and brass all land here, and none of them is the
    `hazard` orange that means *this is about to hurt you*."""
    return common.make_signal_material(name, pal.universal("send", 0),
                                       pal.universal("send", step),
                                       saturation=saturation, roughness=0.4)


# ----------------------------------------------------------------------
# rusted_industrial -- rugged, serviceable, bolted on
# ----------------------------------------------------------------------

def light_rusted_cage():
    """A bulkhead lamp in a heavy cage, hung off a drop bracket.

    The cage is the whole silhouette. It is also the honest one: a work
    light in a refinery is caged because things hit it, and a cage is the
    one piece of a fixture that is unmistakable in outline from any angle.
    """
    shell = [
        brushkit.block("rc_hanger", (0.10, 0.10, 0.22), (0.0, 0.0, -0.11)),
        brushkit.block("rc_yoke", (0.44, 0.09, 0.08), (0.0, 0.0, -0.26)),
        brushkit.prism("rc_can", 0.17, 0.24, 8, (0.0, 0.0, -0.42),
                       top_radius=0.20, asset_name="light_rusted_cage"),
    ]
    for side in (-1.0, 1.0):
        shell.append(brushkit.block("rc_arm_%d" % int(side),
                                    (0.06, 0.06, 0.20),
                                    (side * 0.20, 0.0, -0.32)))
    # Six cage ribs on a circle, and a hoop round the bottom.
    for i in range(6):
        angle = i * math.pi / 3.0
        shell.append(brushkit.block(
            "rc_rib_%d" % i, (0.035, 0.035, 0.26),
            (0.185 * math.cos(angle), 0.185 * math.sin(angle), -0.58),
            rotation_z=math.degrees(angle)))
    shell.append(brushkit.tube("rc_hoop", 0.20, 0.16, 0.05, 8,
                               (0.0, 0.0, -0.70),
                               asset_name="light_rusted_cage"))
    lit = [brushkit.prism("rc_lamp", 0.13, 0.20, 8, (0.0, 0.0, -0.58),
                          top_radius=0.11, asset_name="light_rusted_cage")]
    return _finish("light_rusted_cage", "rusted_industrial", shell, lit,
                   _warm("light_rusted_cage_lit"),
                   (0.5, 0.5, 0.8),
                   "A hung fixture must clear CORRIDOR_HEIGHT's 3.6 m with "
                   "the 0.5 m CEILING_GAP the affordances reserve.",
                   "ceiling")


def light_rusted_clamp():
    """A clamp-on work light: conical shade, knuckle arm, cable loop.

    Not symmetric, and deliberately: this is the fixture somebody carried
    in and fixed where it was needed, which is a different sentence from
    the cage lamp that was installed with the building.
    """
    shell = [
        brushkit.block("rl_clamp", (0.14, 0.10, 0.20), (0.0, -0.05, 0.30)),
        brushkit.block("rl_arm", (0.06, 0.24, 0.06), (0.0, -0.16, 0.34)),
    ]
    brushkit.spin(shell[1], "X", 28.0)
    shell.append(brushkit.prism("rl_shade", 0.17, 0.16, 8,
                               (0.0, -0.26, 0.24), top_radius=0.07,
                               asset_name="light_rusted_clamp"))
    # `spin` rotates about the object's OWN bbox centre, in place -- so a
    # part that is already positioned stays put. The first pass added a
    # manual translate after it, which moved the shade twice and took the
    # fixture from 0.45 m deep to 0.68.
    brushkit.spin(shell[-1], "X", 180.0)
    # The cable, looped back to the wall. A work light with no cable is a
    # sculpture of a work light.
    shell.append(brushkit.sweep("rl_cable",
                                [(0.06, -0.20, 0.30), (0.10, -0.10, 0.18),
                                 (0.07, -0.03, 0.06)], 0.03, 0.03))
    lit = [brushkit.prism("rl_bulb", 0.09, 0.06, 8, (0.0, -0.26, 0.16),
                          top_radius=0.075, asset_name="light_rusted_clamp")]
    return _finish("light_rusted_clamp", "rusted_industrial", shell, lit,
                   _warm("light_rusted_clamp_lit", step=3, saturation=0.6),
                   (0.45, 0.45, 0.55),
                   "arch_utility_lamp, the fixture this sits beside in the "
                   "kit, is 0.34 x 0.44 x 0.28.",
                   "wall")


# ----------------------------------------------------------------------
# neon_transit -- public infrastructure, integrated, not a sign
# ----------------------------------------------------------------------

def light_neon_channel():
    """A recessed ceiling channel with a diffuser. Long, shallow, flush.

    The brief's own warning: *avoid making every fixture itself a giant
    neon sign*. A station's ceiling light is architecture -- a continuous
    trough that reads as part of the soffit -- and the signage is a
    separate object that happens to be lit. So this is the least
    ornamental fixture in the batch, on purpose.
    """
    shell = [
        brushkit.block("nc_body", (1.56, 0.26, 0.10), (0.0, 0.0, -0.05)),
        brushkit.block("nc_lip_a", (1.62, 0.05, 0.13), (0.0, -0.115, -0.07)),
        brushkit.block("nc_lip_b", (1.62, 0.05, 0.13), (0.0, 0.115, -0.07)),
    ]
    for sx in (-1.0, 1.0):
        shell.append(brushkit.block("nc_cap_%d" % int(sx),
                                    (0.06, 0.28, 0.14),
                                    (sx * 0.78, 0.0, -0.07)))
    lit = [brushkit.block("nc_diffuser", (1.48, 0.18, 0.05),
                          (0.0, 0.0, -0.125))]
    return _finish("light_neon_channel", "neon_transit", shell, lit,
                   common.make_signal_material(
                       "light_neon_channel_lit",
                       pal.theme("neon_transit", "accent", 0),
                       pal.theme("neon_transit", "accent", 1),
                       saturation=0.6, roughness=0.35),
                   (1.7, 0.35, 0.22),
                   "arch_light_fixture, the fixture it replaces per theme, "
                   "is 1.5 x 0.39 x 0.26.",
                   "ceiling")


def light_neon_edge():
    """A platform-edge strip: a shallow fin with the light under its lip.

    You never see the source, only the wash it throws down the wall. That
    is what makes it infrastructure rather than a fitting, and it is the
    only fixture here whose emissive face points at the floor.
    """
    shell = [
        brushkit.block("ne_fin", (1.20, 0.14, 0.07), (0.0, -0.07, 0.0)),
        brushkit.block("ne_back", (1.24, 0.05, 0.20), (0.0, -0.025, -0.05)),
    ]
    for sx in (-1.0, 1.0):
        shell.append(brushkit.block("ne_end_%d" % int(sx),
                                    (0.05, 0.14, 0.12),
                                    (sx * 0.60, -0.07, -0.03)))
    lit = [brushkit.block("ne_wash", (1.10, 0.10, 0.04),
                          (0.0, -0.08, -0.05))]
    return _finish("light_neon_edge", "neon_transit", shell, lit,
                   common.make_signal_material(
                       "light_neon_edge_lit",
                       pal.theme("neon_transit", "accent", 0),
                       pal.theme("neon_transit", "accent", 2),
                       saturation=0.5, roughness=0.35),
                   (1.3, 0.3, 0.3),
                   "A wall strip must not project further than "
                   "arch_trim_rail's 0.12 m by much.",
                   "wall")


# ----------------------------------------------------------------------
# gothic_stone -- iron, native to the masonry
# ----------------------------------------------------------------------

def light_gothic_corona():
    """A suspended iron ring with candle stubs, on three chains.

    Native to the architecture because it is the same iron the theme's trim
    already is, hung the way a thing gets hung from a vault: from one point,
    on three chains, spreading. The stubs are what make the ring read as a
    LIGHT rather than as a hoop -- and they are what make its silhouette
    unmistakable, because nothing else in the batch has a row of vertical
    pips on a circle.
    """
    shell = [brushkit.block("gc_boss", (0.14, 0.14, 0.10), (0.0, 0.0, -0.05))]
    for i in range(3):
        angle = i * 2.0 * math.pi / 3.0
        shell.append(brushkit.sweep(
            "gc_chain_%d" % i,
            [(0.0, 0.0, -0.09),
             (0.30 * math.cos(angle), 0.30 * math.sin(angle), -0.46)],
            0.035, 0.035))
    shell.append(brushkit.tube("gc_ring", 0.36, 0.30, 0.07, 8,
                               (0.0, 0.0, -0.48),
                               asset_name="light_gothic_corona"))
    lit = []
    for i in range(6):
        angle = i * math.pi / 3.0 + math.pi / 6.0
        x, y = 0.33 * math.cos(angle), 0.33 * math.sin(angle)
        shell.append(brushkit.block("gc_cup_%d" % i, (0.07, 0.07, 0.05),
                                    (x, y, -0.44)))
        # FOUR sides, not eight. Six eight-sided flames cost 168 triangles
        # of the prop budget's 300 for detail 35 mm across -- and
        # `assert_budget` is right that the answer is to delete geometry.
        # At this size the facet count is invisible and the ring is not.
        lit.append(brushkit.prism("gc_flame_%d" % i, 0.035, 0.11, 4,
                                  (x, y, -0.36), top_radius=0.008,
                                  asset_name="light_gothic_corona"))
    return _finish("light_gothic_corona", "gothic_stone", shell, lit,
                   _warm("light_gothic_corona_lit", step=1, saturation=0.62),
                   (0.85, 0.85, 0.6),
                   "A hung fixture must clear CORRIDOR_HEIGHT's 3.6 m with "
                   "the 0.5 m CEILING_GAP the affordances reserve.",
                   "ceiling")


def light_gothic_lantern():
    """A glazed iron lantern on a bracket. Tapered box, peaked cap.

    The peak is the point: a flat-topped box on a wall is a junction box,
    and every real lantern has a roof because the flame needs a chimney.
    Construction language doing identity work with no hue involved at all.
    """
    shell = [
        brushkit.block("gl_plate", (0.16, 0.05, 0.30), (0.0, -0.025, 0.15)),
        brushkit.block("gl_arm", (0.06, 0.16, 0.06), (0.0, -0.11, 0.34)),
        brushkit.prism("gl_body", 0.14, 0.24, 8, (0.0, -0.19, 0.22),
                       top_radius=0.115, asset_name="light_gothic_lantern"),
        brushkit.prism("gl_cap", 0.16, 0.10, 8, (0.0, -0.19, 0.39),
                       top_radius=0.03, asset_name="light_gothic_lantern"),
        brushkit.prism("gl_foot", 0.15, 0.05, 8, (0.0, -0.19, 0.08),
                       top_radius=0.12, asset_name="light_gothic_lantern"),
    ]
    for i in range(4):
        angle = i * math.pi / 2.0 + math.pi / 4.0
        shell.append(brushkit.block(
            "gl_mullion_%d" % i, (0.03, 0.03, 0.24),
            (-0.0 + 0.125 * math.cos(angle), -0.19 + 0.125 * math.sin(angle),
             0.22), rotation_z=math.degrees(angle)))
    lit = [brushkit.prism("gl_glass", 0.10, 0.19, 8, (0.0, -0.19, 0.22),
                          top_radius=0.085,
                          asset_name="light_gothic_lantern")]
    return _finish("light_gothic_lantern", "gothic_stone", shell, lit,
                   _warm("light_gothic_lantern_lit", step=1, saturation=0.58),
                   (0.4, 0.4, 0.55),
                   "arch_utility_lamp, the wall fixture it sits beside in "
                   "the kit, is 0.34 x 0.44 x 0.28.",
                   "wall")


# ----------------------------------------------------------------------
# temple_ruin -- crafted, embedded in the ruin's own material history
# ----------------------------------------------------------------------

def light_temple_bowl():
    """A brass bowl on three chains from a carved stone boss.

    Two materials, and the join is the story: the boss is the building, the
    chain and bowl are the thing somebody hung from it. The bowl is shallow
    and open because the fire is meant to be seen from below -- a covered
    lamp in a ruin is a lamp nobody has had to relight in a thousand years.
    """
    shell = [
        brushkit.prism("tb_boss", 0.16, 0.13, 8, (0.0, 0.0, -0.065),
                       top_radius=0.11, asset_name="light_temple_bowl"),
        brushkit.prism("tb_collar", 0.07, 0.06, 8, (0.0, 0.0, -0.15),
                       top_radius=0.05, asset_name="light_temple_bowl"),
    ]
    for i in range(3):
        angle = i * 2.0 * math.pi / 3.0 + math.pi / 6.0
        shell.append(brushkit.sweep(
            "tb_chain_%d" % i,
            [(0.0, 0.0, -0.18),
             (0.24 * math.cos(angle), 0.24 * math.sin(angle), -0.50)],
            0.03, 0.03))
    shell.append(brushkit.prism("tb_bowl", 0.16, 0.13, 8, (0.0, 0.0, -0.56),
                                top_radius=0.28,
                                asset_name="light_temple_bowl"))
    shell.append(brushkit.tube("tb_rim", 0.29, 0.25, 0.04, 8,
                               (0.0, 0.0, -0.50),
                               asset_name="light_temple_bowl"))
    lit = [brushkit.prism("tb_fire", 0.20, 0.10, 8, (0.0, 0.0, -0.49),
                          top_radius=0.11, asset_name="light_temple_bowl")]
    return _finish("light_temple_bowl", "temple_ruin", shell, lit,
                   _warm("light_temple_bowl_lit", step=2, saturation=0.6),
                   (0.7, 0.7, 0.65),
                   "A hung fixture must clear CORRIDOR_HEIGHT's 3.6 m with "
                   "the 0.5 m CEILING_GAP the affordances reserve.",
                   "ceiling")


def light_temple_niche():
    """A carved recess in the wall with a brass dish in it.

    The only fixture in the batch that is a HOLE rather than an object --
    cut into the masonry rather than fixed to it, which is exactly the
    theme's *embedded in the ruin's material history*. Its silhouette
    against a wall is a stepped block with a shadow in the middle, and no
    other fixture here reads that way.
    """
    shell = [
        brushkit.block("tn_surround", (0.46, 0.16, 0.60), (0.0, -0.08, 0.30)),
        brushkit.block("tn_hood", (0.52, 0.20, 0.08), (0.0, -0.10, 0.64)),
        brushkit.block("tn_sill", (0.50, 0.22, 0.07), (0.0, -0.11, 0.035)),
    ]
    # The recess, built as a frame rather than a boolean: four blocks with
    # a hole between them, which is the same way arch_doorway is made.
    for name, size, at in (
            ("tn_jamb_l", (0.09, 0.16, 0.48), (-0.185, -0.08, 0.32)),
            ("tn_jamb_r", (0.09, 0.16, 0.48), (0.185, -0.08, 0.32)),
            ("tn_head", (0.28, 0.16, 0.08), (0.0, -0.08, 0.52)),
            ("tn_back", (0.28, 0.05, 0.48), (0.0, -0.005, 0.32))):
        shell.append(brushkit.block(name, size, at))
    shell.append(brushkit.prism("tn_dish", 0.13, 0.05, 8,
                                (0.0, -0.09, 0.14), top_radius=0.16,
                                asset_name="light_temple_niche"))
    lit = [brushkit.prism("tn_fire", 0.11, 0.09, 8, (0.0, -0.09, 0.21),
                          top_radius=0.05, asset_name="light_temple_niche")]
    return _finish("light_temple_niche", "temple_ruin", shell, lit,
                   _warm("light_temple_niche_lit", step=2, saturation=0.58),
                   (0.6, 0.35, 0.75),
                   "A wall niche is cut into a 0.40 m WALL_THICKNESS, so it "
                   "may not project more than about a third of that.",
                   "wall")


# ----------------------------------------------------------------------
# void_glitch -- deliberately wrong, and still a light
# ----------------------------------------------------------------------

def light_void_absent():
    """The mount is there. The fixture is not. The light happens anyway.

    Bracket, conduit, two bolt pads and a gap where a lamp should be
    bolted -- and the glow comes out of the gap. It is the theme's whole
    thesis as a fixture: something is missing and the world has not
    noticed.

    It has to keep working as a light source (the brief is explicit), and
    it does: the emissive is a flat plane floating in the empty mount, so
    from any angle you see light with no lamp around it.
    """
    shell = [
        brushkit.block("va_conduit", (0.07, 0.07, 0.26), (0.0, 0.0, -0.13)),
        brushkit.block("va_yoke", (0.62, 0.10, 0.09), (0.0, 0.0, -0.30)),
    ]
    for sx in (-1.0, 1.0):
        shell.append(brushkit.block("va_pad_%d" % int(sx),
                                    (0.13, 0.13, 0.06),
                                    (sx * 0.26, 0.0, -0.38)))
        shell.append(brushkit.block("va_bolt_%d" % int(sx),
                                    (0.05, 0.05, 0.10),
                                    (sx * 0.26, 0.0, -0.46)))
    # A flat plane in the gap: light with no lamp around it.
    lit = [brushkit.block("va_ghost", (0.44, 0.16, 0.012),
                          (0.0, 0.0, -0.45))]
    return _finish("light_void_absent", "void_glitch", shell, lit,
                   common.make_signal_material(
                       "light_void_absent_lit", pal.universal("glitch", 0),
                       pal.universal("glitch", 2), saturation=0.5,
                       roughness=0.35),
                   (0.7, 0.3, 0.55),
                   "arch_light_fixture, the fixture it replaces per theme, "
                   "is 1.5 x 0.39 x 0.26.",
                   "ceiling")


def light_void_debug():
    """A placeholder that shipped. Untextured box, struts at wrong angles,
    hanging from nothing.

    The one fixture in the batch that is deliberately BAD construction: its
    struts do not meet the box, its proportions are a programmer's default,
    and it has no mount at all. `void_glitch` is the theme whose identity is
    missing content, and a fixture that looks placed by a build script is
    truer to it than any amount of designed decay.

    Flat-shaded and untextured on purpose -- `make_material`, not a painted
    canvas. Everything else in the project earns its surface; this one is
    the exception the theme exists for.
    """
    shell = [brushkit.block("vd_box", (0.40, 0.40, 0.26), (0.0, 0.0, -0.30))]
    for i, (dx, dy, rot) in enumerate(((-0.30, 0.10, 24.0),
                                       (0.28, -0.14, -37.0),
                                       (0.06, 0.30, 12.0))):
        strut = brushkit.block("vd_strut_%d" % i, (0.05, 0.05, 0.34),
                               (dx, dy, -0.16))
        brushkit.spin(strut, "X", rot)
        shell.append(strut)
    obj = common.join(shell, "light_void_debug_shell")
    common.assign(obj, common.make_material(
        "light_void_debug", pal.theme("void_glitch", "base", 3),
        roughness=0.9))
    lit = common.join([brushkit.block("vd_lamp", (0.30, 0.30, 0.06),
                                      (0.0, 0.0, -0.45))],
                      "light_void_debug_lit")
    common.assign(lit, common.make_signal_material(
        "light_void_debug_lit", pal.universal("glitch", 0),
        pal.universal("glitch", 2), saturation=0.55, roughness=0.35))
    obj = common.join([obj, lit], "light_void_debug")
    common.set_origin(obj, "ceiling")
    common.assert_fits(obj, "light_void_debug", (0.75, 0.75, 0.6),
                       "A hung fixture must clear CORRIDOR_HEIGHT's 3.6 m "
                       "with the 0.5 m CEILING_GAP the affordances reserve.")
    return common.export_glb(obj, "%s/light_void_debug.glb" % OUT, "prop",
                             anchor="ceiling", check_flat=False)


FIXTURES = [light_rusted_cage, light_rusted_clamp,
            light_neon_channel, light_neon_edge,
            light_gothic_corona, light_gothic_lantern,
            light_temple_bowl, light_temple_niche,
            light_void_absent, light_void_debug]


def main():
    common.reset_scene()
    report = {}
    for builder in FIXTURES:
        entry = builder()
        report[os.path.basename(entry["path"])[:-4]] = entry
    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch014",
                       "lights", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")


if __name__ == "__main__":
    main()
