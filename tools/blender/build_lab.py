"""Batch 004 -- the Echo Lab's fixtures.

    .tools/blender/blender -b --python tools/blender/build_lab.py

## Why the Lab is next

Tier 1 is "Hub / permanent spaces", and the Echo Lab is the other permanent
space: a 16 x 26 x 6 m annexe off the Hub's west wall that you reach by
walking, which is what makes "base movement can always leave the Lab"
structural rather than a rule to remember.

It is also the room in the game with the most untextured primitives in it.
Every fixture in `hub/lab_fixtures.gd` is a `BoxMesh` or `CapsuleMesh` with
a `glow_material` on it, and the height bands and runway ticks are boxes
with a glow and a `Label3D` beside them.

Nothing here establishes new visual DNA. It is the locked facility language
applied to test equipment, at envelopes read out of the engine.

## The Lab is a MEASURING ROOM, and that decides everything

The Hub is where you are; the Lab is where you find out what you can do.
Every fixture in it exists to answer a question about the player's own
movement, so the one thing that matters is that its numbers are **exactly**
the engine's:

| Fixture | Answers | Against |
| --- | --- | --- |
| height bands | how high did that send me | `jump_apex` 1.333 m, `max_vertical_step` 1.0 m |
| runway ticks | how far did that carry me | `jump_flat_reach` 4.667 m |
| the gap | can I cross this | the gap width is Godot's |

So the two graduated fixtures do not carry decorative marks. Every band and
every tick is a real measurement, the two that name a mechanic are called
out, and all of them come from `engine_truth` rather than from a designer's
memory of what the jump does.

## Where hazard orange actually belongs

`ART_BIBLE` reserves the hazard family for telegraphs -- what is about to
happen -- which is why it has no business on an enemy's body
(`ART_LESSONS.md` L-40). `lab_hazard` is the exception that proves the rule:
a fixture whose entire job is "this will hurt you" is the one object in the
game that is permanently a telegraph. It gets the stripes.

The training dummy deliberately does NOT get them, and does not get the
enemy skin either. A dummy that reads as an enemy is a dummy that teaches
the player to shoot the wrong silhouette.
"""

from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import brushkit  # noqa: E402
import common  # noqa: E402
import paintkit  # noqa: E402
import propkit  # noqa: E402
import palette as pal  # noqa: E402

THEME = "concrete_facility"

#: Read from `hub/echo_lab.gd` and `hub/lab_fixtures.gd`.
LAB_W, LAB_D, LAB_H = 16.0, 26.0, 6.0
DUMMY_H, DUMMY_R = 1.9, 0.45
TARGET = (0.9, 0.9, 1.6)      # Godot (x, z, y) -> Blender (x, y, z)
HAZARD = (1.4, 1.4, 1.6)
PAD = (1.6, 1.6, 0.6)

#: The three numbers the Lab exists to make visible. From the engine.
APEX = common.DIM["jump_apex"]              # 1.333 m
STEP = common.DIM["max_vertical_step"]      # 1.0 m
REACH = common.DIM["jump_flat_reach"]       # 4.667 m


def dummy():
    """A training dummy: a plated post on a sprung base. 1.9 m, r 0.45.

    NOT an enemy, and built so it cannot be mistaken for one. It wears the
    facility's painted plate rather than `enemy_skin`, it has no optic, and
    its silhouette is a symmetrical post -- the one shape the whole enemy
    roster deliberately avoids, because every enemy in the family is
    asymmetric somewhere.

    A dummy that reads as an enemy teaches the player to shoot the wrong
    silhouette, which is worse than a dummy that reads as furniture.
    """
    parts = [
        # A weighted base and the spring above it: it takes a hit and rocks.
        # 8 segments, not 10: assert_segments caps a 0.43 m radius at 8,
        # and the cap is radius-dependent for a reason -- a small drum with
        # ten sides costs triangles nobody can see.
        brushkit.prism("ld_base", DUMMY_R * 0.95, 0.14, 8, (0.0, 0.0, 0.07),
                       top_radius=DUMMY_R * 0.80, asset_name="lab_dummy"),
        brushkit.prism("ld_spring", 0.10, 0.26, 8, (0.0, 0.0, 0.27),
                       top_radius=0.09, asset_name="lab_dummy"),
        # The body: a flat-fronted plate rather than a torso.
        brushkit.block("ld_post", (0.20, 0.20, DUMMY_H - 0.52),
                       (0.0, 0.06, 0.40 + (DUMMY_H - 0.52) / 2.0)),
        brushkit.block("ld_plate", (DUMMY_R * 1.9, 0.13, 1.02),
                       (0.0, -0.06, 1.12)),
        brushkit.block("ld_shoulder", (DUMMY_R * 2.0, 0.22, 0.12),
                       (0.0, 0.0, 1.70)),
    ]
    # Target rings on the plate, as geometry: a ring you can see the edge of
    # survives a bad texture window, which a printed one does not.
    for j, (r, dz) in enumerate(((0.34, 1.24), (0.21, 1.24), (0.10, 1.24))):
        parts.append(brushkit.tube("ld_ring_%d" % j, r, r - 0.045, 0.03, 8,
                                   (0.0, -0.13, dz), asset_name="lab_dummy"))
    for part in parts[-3:]:
        brushkit.spin(part, "X", 90.0)
    # Stabiliser feet.
    for j in range(3):
        parts.append(brushkit.block("ld_foot_%d" % j, (0.30, 0.11, 0.07),
                                    (0.0, 0.0, 0.035),
                                    rotation_z=60.0 + j * 120.0))
    return parts, None, (DUMMY_R * 2.0, DUMMY_R * 2.0, DUMMY_H), "light"


def height_bands():
    """The wall the Lab answers "how high did that send me" against.

    A 7.0 m graduated strip with a band at every metre to the room's 6 m,
    and TWO bands that are not decorative:

        1.000 m   MAX_VERTICAL_STEP -- what you can walk up
        1.333 m   JUMP_APEX -- what a jump gets you without a trait

    Those two are the ones the player is actually measuring against, so they
    are wider, they project further, and they are the only ones that get a
    stencilled label. Every other band is a plain tick. A wall where all the
    marks look equally important is a wall you have to count.
    """
    height = 7.0
    parts = [
        brushkit.block("hb_face", (0.16, height, LAB_H), (0.0, 0.0, LAB_H / 2.0)),
        brushkit.block("hb_kick", (0.24, height + 0.10, 0.22), (0.0, 0.0, 0.11)),
    ]
    lit = []
    for band in range(1, int(LAB_H)):
        z = float(band)
        # Plain metre ticks, in geometry, not paint.
        parts.append(brushkit.block("hb_tick_%d" % band,
                                    (0.10, height * 0.94, 0.05),
                                    (-0.13, 0.0, z)))
    for name, z, wide in (("step", STEP, 0.20), ("apex", APEX, 0.26)):
        parts.append(brushkit.block("hb_call_%s" % name,
                                    (0.22, height * 0.98, wide * 0.30),
                                    (-0.19, 0.0, z)))
        lit.append(brushkit.block("hb_lit_%s" % name,
                                  (0.06, height * 0.98, wide * 0.16),
                                  (-0.31, 0.0, z)))
    return parts, common.join(lit, "lab_height_markers_lit"), \
        (0.5, height + 0.2, LAB_H), "dark"


def runway():
    """A 4 m graduated floor strip. One module of the Lab's distance lane.

    `echo_lab.gd` lays ticks every 2 m from 2 to 20. This is the authored
    module they become: a 4 m plate with ticks at each metre, a heavier one
    at the even metres, and the `JUMP_FLAT_REACH` mark -- 4.667 m, what a
    jump carries you without a trait -- called out where it falls.

    Anchored `module_floor` because the position of the reach mark WITHIN
    the module is the whole point: it is at 0.667 m into the second module,
    and a module that could be laid either way round would put it at 3.33.
    """
    length = 4.0
    width = 3.0
    parts = [
        brushkit.block("rw_plate", (width, length, 0.05), (0.0, 0.0, 0.025)),
        brushkit.block("rw_kerb_l", (0.12, length, 0.09), (-width / 2.0, 0.0, 0.045)),
        brushkit.block("rw_kerb_r", (0.12, length, 0.09), (width / 2.0, 0.0, 0.045)),
    ]
    for m in range(1, int(length) + 1):
        y = -length / 2.0 + m
        heavy = (m % 2 == 0)
        parts.append(brushkit.block("rw_tick_%d" % m,
                                    (width * (0.55 if heavy else 0.30), 0.10,
                                     0.07), (0.0, y, 0.035)))
    lit = []
    # The reach mark, if it falls inside this module. It does: 4.667 m is
    # 0.667 into the second one.
    within = REACH - length
    if 0.0 < within < length:
        lit.append(brushkit.block("rw_reach", (width * 0.8, 0.12, 0.08),
                                  (0.0, -length / 2.0 + within, 0.04)))
    return parts, common.join(lit, "lab_runway_measure_lit"), \
        (width + 0.3, length + 0.2, 0.2), "mid"


def hazard_skin(theme, name):
    """The hazard block's own skin: cabinet plate with a REAL striped band.

    The first version said "stripes on the sides" in its docstring and
    painted none -- the body took the plain `machine_bank` panel and the
    only orange on the object was its emitter, which rendered as a pale
    salmon slab. A docstring describing an asset that does not exist is the
    same failure as L-40, caught one batch later on the same day.

    `paintkit.hazard_stripes` snaps its diagonals to whole texels, because
    a smooth diagonal sampled at 64 texels/m is a blur rather than a
    stripe.
    """
    canvas = propkit.machine_bank(theme, name, "panel")
    surf = propkit.surface(theme, name)
    band = surf.texels(0.34)
    top = surf.texels(0.52)
    paintkit.hazard_stripes(canvas, 0, top, propkit.PROP_SIZE, band,
                            pal.universal("hazard", 0),
                            pal.universal("hazard", 2), pitch=5)
    # A dark keyline top and bottom, so the band is a fitted plate rather
    # than paint that ran off the edges.
    canvas.rect(0, top - 2, propkit.PROP_SIZE, 2, pal.grime(0))
    canvas.rect(0, top + band, propkit.PROP_SIZE, 2, pal.grime(0))
    paintkit.edge_wear(canvas, surf, pal.grime(0), surf.texels(0.05),
                       strength=0.7)
    return canvas


def hazard():
    """The one object in the game that is permanently a telegraph.

    1.4 x 1.6 x 1.4 m. `ART_BIBLE` reserves hazard orange for what is about
    to happen, which is why it has no business on an enemy's body -- and
    why it belongs here without reservation. A hazard block's entire job is
    to say "this will hurt you", continuously, before it does.

    Stripes on the sides, a cage over the emitter, and the emitter itself
    recessed: you should be able to see it is armed from across the room and
    still not be able to touch the hot part by accident.
    """
    w, d, h = HAZARD
    parts = [
        brushkit.block("hz_body", (w, d, h * 0.62), (0.0, 0.0, h * 0.31)),
        brushkit.block("hz_cap", (w + 0.10, d + 0.10, 0.12), (0.0, 0.0, h * 0.68)),
        brushkit.block("hz_plinth", (w + 0.14, d + 0.14, 0.10), (0.0, 0.0, 0.05)),
    ]
    for side in (-1.0, 1.0):
        parts.append(brushkit.block("hz_post_%d" % int(side),
                                    (0.10, 0.10, h * 0.30),
                                    (side * (w / 2.0 - 0.08), 0.0, h * 0.85)))
    parts.append(brushkit.grate("hz_cage", (w * 0.74, d * 0.74, 0.05), 5, 0.05,
                                (0.0, 0.0, h - 0.04), axis="z"))
    lit = brushkit.block("hz_emitter", (w * 0.54, d * 0.54, 0.10),
                         (0.0, 0.0, h * 0.76))
    return parts, lit, (w + 0.2, d + 0.2, h), "dark"


def moving_target():
    """A target on a track. 0.9 x 1.6 x 0.9 m.

    Announced by `VOCABULARY_FIXTURES`, so it appears when a mechanic that
    needs it does. A flat face on a carriage, with the face turned a few
    degrees off square: a target you can hit without leading is not a
    moving-target test.
    """
    w, d, h = TARGET
    parts = [
        brushkit.block("mt_carriage", (w, d * 0.7, 0.26), (0.0, 0.0, 0.13)),
        brushkit.block("mt_mast", (0.14, 0.14, h - 0.40), (0.0, 0.05, 0.20 + (h - 0.40) / 2.0)),
    ]
    face = brushkit.block("mt_face", (w * 0.94, 0.11, h * 0.52),
                          (0.0, -0.10, h * 0.62))
    parts.append(brushkit.spin(face, "Z", 8.0))
    for j, (r, dz) in enumerate(((0.26, h * 0.62), (0.14, h * 0.62))):
        ring = brushkit.tube("mt_ring_%d" % j, r, r - 0.04, 0.03, 8,
                             (0.0, -0.17, dz), asset_name="lab_moving_target")
        parts.append(brushkit.spin(ring, "X", 90.0))
    for side in (-1.0, 1.0):
        parts.append(brushkit.prism("mt_wheel_%d" % int(side), 0.09, 0.07, 8,
                                    (side * (w / 2.0 - 0.10), 0.0, 0.06),
                                    asset_name="lab_moving_target"))
    lit = brushkit.block("mt_pip", (0.09, 0.06, 0.09), (0.0, -0.19, h * 0.62))
    return parts, lit, (w + 0.1, d + 0.1, h), "mid"


def reset_pad():
    """RESET LAB. A pad you stand on. 1.6 x 0.6 x 1.6 m.

    Low, wide and obviously a floor object, because the one thing it must
    never be is something you walk into by accident while testing a dash.
    A recessed tread with a lit border: the light is at the EDGE, so the
    pad reads as an outline from above -- which is the angle you are at
    when you are looking for it.
    """
    w, d, h = PAD
    parts = [
        brushkit.block("rp_frame", (w, d, h * 0.5), (0.0, 0.0, h * 0.25)),
        brushkit.grate("rp_tread", (w - 0.28, d - 0.28, 0.06), 6, 0.05,
                       (0.0, 0.0, h * 0.52), axis="z"),
    ]
    # The approach ramps sit INSIDE the pad's footprint, not proud of it.
    # At d/2 - 0.06 with a 0.16 depth they overhung by 20 mm, and a pad you
    # can stub a foot on is a pad you notice for the wrong reason.
    for side in (-1.0, 1.0):
        parts.append(brushkit.block("rp_ramp_%d" % int(side),
                                    (w, 0.16, h * 0.22),
                                    (0.0, side * (d / 2.0 - 0.10), h * 0.11)))
    lit = []
    for j, (dx, dy, lw, ld) in enumerate(((0.0, d / 2.0 - 0.10, w - 0.30, 0.07),
                                          (0.0, -(d / 2.0 - 0.10), w - 0.30, 0.07),
                                          (w / 2.0 - 0.10, 0.0, 0.07, d - 0.30),
                                          (-(w / 2.0 - 0.10), 0.0, 0.07, d - 0.30))):
        lit.append(brushkit.block("rp_edge_%d" % j, (lw, ld, 0.05),
                                  (dx, dy, h * 0.56)))
    return parts, common.join(lit, "lab_reset_pad_lit"), (w, d, h), "mid"


def notice_board():
    """Where "NEW MECHANIC DETECTED" appears. A housing, not a message.

    `echo_lab.gd` puts a `Label3D` at (0, 3.4, 2.4) and turns it on when the
    Lab gains a fixture. The text is the game's; this is the board it is on
    -- and it is DARK, with a lamp over it, for the same reason every board
    in the Hub is: an authored asset that glows is an asset claiming to know
    when the message is showing.
    """
    w, h = 3.2, 1.1
    parts = [
        brushkit.block("nb_plate", (w, 0.10, h), (0.0, 0.0, 0.0)),
        brushkit.frame("nb_frame", (w + 0.12, h + 0.12), 0.09, 0.14,
                       (0.0, -0.08, 0.0)),
        brushkit.wedge("nb_hood", (w + 0.20, 0.30, 0.14),
                       (0.0, -0.16, h / 2.0 + 0.16), axis="y"),
    ]
    for side in (-1.0, 1.0):
        parts.append(brushkit.block("nb_lug_%d" % int(side), (0.14, 0.18, 0.24),
                                    (side * (w / 2.0 + 0.10), 0.0, 0.0)))
    lit = brushkit.block("nb_lamp", (w * 0.7, 0.07, 0.05),
                         (0.0, -0.26, h / 2.0 + 0.10))
    return parts, lit, (w + 0.4, 0.5, h + 0.5), "dark"


#: (id, builder, machine_bank kind, lit family, saturation, anchor)
FIXTURES = [
    ("lab_dummy", dummy, "panel", None, 0.0, "floor"),
    ("lab_height_markers", height_bands, "rack", "signal", 0.45, "floor"),
    ("lab_runway_measure", runway, "panel", "signal", 0.45, "module_floor"),
    ("lab_hazard", hazard, "panel", "hazard", 0.34, "floor"),
    ("lab_moving_target", moving_target, "panel", "signal", 0.45, "floor"),
    ("lab_reset_pad", reset_pad, "rack", "signal", 0.45, "floor"),
    ("lab_notice_board", notice_board, "panel", "signal", 0.40, "centre"),
]


def main():
    common.reset_scene()
    report = {}
    for name, builder, kind, family, saturation, anchor in FIXTURES:
        parts, lit, box, tone = builder()
        body = common.join(parts, name + "_body")
        common.uv_project_world(body, propkit.PROP_DENSITY, propkit.PROP_SIZE)
        if tone in ("light", "mid"):
            # Test EQUIPMENT, not machinery: the dummy and the moving target
            # are things a person set up, so they wear the prop skin the
            # crates and lockers wear rather than the machine-bank cabinet.
            canvas = propkit.painted_metal(THEME, name, tone=tone)
        elif name == "lab_hazard":
            canvas = hazard_skin(THEME, name)
        else:
            canvas = propkit.machine_bank(THEME, name, kind)
        common.assign(body, common.make_textured_material(
            name + "_body", canvas.to_blender(name + "_tex"),
            roughness=pal.roughness(THEME)))
        pieces = [body]
        if lit is not None:
            # hazard's bright step is `#ff9772`, a pale salmon that
            # renders as a peach slab once the solve and the tonemap have
            # both had it. The family's ORANGE is step 2, `#e8541f`, and
            # that is what "this will hurt you" is supposed to look like.
            bright = 2 if family == "hazard" else 3
            common.assign(lit, common.make_signal_material(
                name + "_lit", pal.universal(family, 0),
                pal.universal(family, bright), saturation=saturation))
            pieces.append(lit)
        obj = common.join(pieces, name)
        common.set_origin(obj, anchor)
        common.assert_fits(obj, name, box,
                           "echo_lab.gd and lab_fixtures.gd give this a "
                           "%.2f x %.2f x %.2f m envelope, and a fixture "
                           "outside it blocks a lane the player is meant to "
                           "run down." % box)
        report[name] = common.export_glb(obj, "batch004/lab/%s.glb" % name,
                                         "interactable", check_flat=False,
                                         anchor=anchor)
    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch004",
                       "lab", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")


if __name__ == "__main__":
    main()
