"""Batch 034 -- PROPOSAL: hard progression gate readability.

VISUAL LANGUAGE ONLY. Production owns whether a gate is legal, what a
capability does, and every rule about acquisition.

## The problem, in one line

    "NOT YET" MUST LOOK INTENTIONAL.

A player who meets a route they cannot take should think *I know what kind of
thing belongs here, and I don't have it yet* -- never *Epsilon generated
broken geometry.* Those two readings sit very close together, and the whole
batch is about the distance between them.

## The finding: finish quality is the tell, not signage

The affordance signal ruling already gives the player "you could use a
capability here" (`AFFORDANCE_SIGNAL_HEX`, form for which, colour for
opportunity). It does NOT distinguish *unreachable because you lack
something* from *unreachable because the level is wrong*.

Adding a marker would be the obvious answer and it is the wrong one: a label
that says NOT YET is a label, and the player learns nothing they could have
worked out. What separates infrastructure from rubble is **how it is
finished**:

    BROKEN is ragged. INSTALLED is neat.

- a landing platform that is **railed, decked and lit**, with no way up to it
- an anchor on a **proper bracket with real fixings**, out of reach
- a rail beginning **on a complete pylon**, in mid-air
- a door whose **frame is intact** and whose panel is a different construction

Every one of those says *somebody meant you to arrive here*. None of them
needs a colour, a HUD element or a new semantic channel, and a player learns
the distinction in one Zone.

So each asset here is built TWICE, and the pair is the evidence:

    gate_*          the same route, finished  -> reads as intentional
    gate_*_ragged   the same route, unfinished -> reads as broken

If the two do not separate, the proposal fails, and the sheet says so.

## Blink / teleport has NO mechanical contract, and gets no production asset

`gate_blink_proposal` is exactly that -- a proposal. The visual idea is a
**matched pair of finished terminals with nothing between them**: two
identical, complete, obviously-installed fixtures facing each other across a
gap with no bridge and no debris. Symmetry is the signal, because broken
things are asymmetric and a *pair* asserts a relationship even when the
mechanism is invisible. Nothing here defines range, cost, cooldown or
legality, and the manifest marks it `has_mechanical_contract: false`.

## Palette

The affordance ruling is followed exactly: `signal` #39d7c8 marks the
capability opportunity and nothing else does. `hazard` appears nowhere -- a
gate is not a danger, and telegraph orange stays reserved. The "finished
versus ragged" read carries no colour at all, which is the point.
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
OUT = "batch034/gates"
BOX = (9.0, 6.0, 6.5)


def _tag(objs, role):
    return [(o, role) for o in (objs if isinstance(objs, list) else [objs])]


def _floor_and_wall():
    out = []
    out += _tag(brushkit.block("floor", (8.0, 5.0, 0.30),
                               (0.0, 0.0, -0.15)), "struct")
    out += _tag(brushkit.block("wall", (8.0, 0.30, 5.20),
                               (0.0, 2.10, 2.60)), "struct")
    return out


def _landing(z, finished):
    """The place you are meant to arrive at. Finished or ragged."""
    out = []
    out += _tag(brushkit.block("deck", (2.60, 1.50, 0.22),
                               (1.70, 1.10, z)), "struct")
    if finished:
        # Railed, kerbed, and with a light over it. Somebody meant you to
        # stand here.
        for spec in (((2.60, 0.10, 0.44), (1.70, 0.36, z + 0.33)),
                     ((0.10, 1.50, 0.44), (0.42, 1.10, z + 0.33)),
                     ((0.10, 1.50, 0.44), (2.98, 1.10, z + 0.33))):
            out += _tag(brushkit.block("rail", spec[0], spec[1]), "fitting")
        out += _tag(brushkit.block("kerb", (2.60, 1.50, 0.06),
                                   (1.70, 1.10, z + 0.14)), "fitting")
        out += _tag(brushkit.block("lamp", (0.34, 0.22, 0.14),
                                   (1.70, 1.86, z + 1.30)), "fitting")
    else:
        # The same deck, failed. Broken stubs, a dropped slab, no fittings.
        for i, sx in enumerate((-0.9, 0.1, 1.1)):
            out += _tag(brushkit.wedge("shard_%d" % i,
                                       (0.36, 0.50, 0.20 + 0.06 * i),
                                       (1.70 + sx, 0.42, z + 0.06),
                                       rotation_z=14.0 * i, axis="y"),
                        "struct")
        out += _tag(brushkit.block("fallen", (1.10, 0.80, 0.20),
                                   (0.40, -0.60, 0.20), rotation_z=23.0),
                    "struct")
    return out


def _grapple(finished):
    out, cores = [], []
    z = 3.40
    out += _landing(z, finished)
    if finished:
        # A bracket, real fixings, and the anchor on it. INSTALLED.
        out += _tag(brushkit.block("bracket", (0.44, 0.52, 0.16),
                                   (-1.30, 1.60, z + 1.05)), "fitting")
        for sx in (-1.0, 1.0):
            out += _tag(brushkit.block("fix_%d" % int(sx),
                                       (0.09, 0.09, 0.14),
                                       (-1.30 + sx * 0.15, 1.86, z + 1.05)),
                        "fitting")
        out += _tag(brushkit.tube("anchor", 0.26, 0.17, 0.12, 8,
                                  (-1.30, 1.52, z + 0.86)), "fitting")
        cores.append(brushkit.tube("anchor_ring", 0.20, 0.15, 0.05, 8,
                                   (-1.30, 1.46, z + 0.86)))
    else:
        # A torn fixing plate and nothing on it.
        out += _tag(brushkit.block("torn", (0.36, 0.14, 0.22),
                                   (-1.30, 1.94, z + 0.94),
                                   rotation_z=11.0), "struct")
    return out, cores


def _break(finished):
    out, cores = [], []
    out += _tag(brushkit.block("jamb_l", (0.24, 0.40, 2.60),
                               (-1.10, 1.86, 1.30)), "struct")
    out += _tag(brushkit.block("jamb_r", (0.24, 0.40, 2.60),
                               (1.10, 1.86, 1.30)), "struct")
    out += _tag(brushkit.block("lintel", (2.44, 0.40, 0.26),
                               (0.0, 1.86, 2.47)), "struct")
    if finished:
        # An INTACT frame with a panel of a different construction in it.
        # The frame says door; the panel says not by hand.
        out += _tag(brushkit.block("panel", (1.90, 0.16, 2.30),
                                   (0.0, 1.84, 1.15)), "fitting")
        for r in range(4):
            for c in range(3):
                out += _tag(brushkit.block("course_%d_%d" % (r, c),
                                           (0.58, 0.08, 0.48),
                                           (-0.62 + c * 0.62, 1.74,
                                            0.36 + r * 0.56)), "fitting")
        cores.append(brushkit.block("seam", (1.86, 0.03, 0.04),
                                    (0.0, 1.74, 2.26)))
    else:
        # A hole, with rubble. Nothing about it was ever a door.
        for i in range(5):
            out += _tag(brushkit.block("rubble_%d" % i,
                                       (0.40 + 0.08 * i, 0.34, 0.26),
                                       (-0.80 + i * 0.42, 1.30, 0.14),
                                       rotation_z=17.0 * i), "struct")
    return out, cores


def _launch(finished):
    out, cores = [], []
    z = 3.00
    out += _landing(z, finished)
    if finished:
        # A complete pad on a complete plinth, aimed at the landing.
        out += _tag(brushkit.block("plinth", (1.30, 1.30, 0.34),
                                   (-1.60, -0.40, 0.17)), "struct")
        out += _tag(brushkit.wedge("pad", (1.10, 1.10, 0.52),
                                   (-1.60, -0.40, 0.58), axis="y"),
                    "fitting")
        for sx in (-1.0, 1.0):
            out += _tag(brushkit.block("post_%d" % int(sx),
                                       (0.11, 0.11, 0.46),
                                       (-1.60 + sx * 0.62, -0.92, 0.55)),
                        "fitting")
        cores.append(brushkit.block("pad_face", (0.80, 0.60, 0.05),
                                    (-1.60, -0.52, 0.86)))
    else:
        # A plinth with nothing on it and a broken corner.
        out += _tag(brushkit.block("plinth", (1.30, 1.30, 0.34),
                                   (-1.60, -0.40, 0.17)), "struct")
        out += _tag(brushkit.wedge("broken", (0.60, 0.50, 0.28),
                                   (-2.05, -0.85, 0.24), rotation_z=28.0,
                                   axis="y"), "struct")
    return out, cores


def _blink(finished):
    """PROPOSAL ONLY -- blink has no mechanical contract."""
    out, cores = [], []
    if finished:
        # A MATCHED PAIR facing each other across a gap with no bridge and
        # no debris. Symmetry is the whole signal: broken things are
        # asymmetric, and a pair asserts a relationship.
        for sx in (-1.0, 1.0):
            x = sx * 2.30
            out += _tag(brushkit.block("plinth_%d" % int(sx),
                                       (1.00, 1.00, 0.36),
                                       (x, 0.30, 0.18)), "struct")
            out += _tag(brushkit.block("mast_%d" % int(sx),
                                       (0.26, 0.26, 2.10),
                                       (x, 0.30, 1.41)), "fitting")
            out += _tag(brushkit.tube("ring_%d" % int(sx), 0.46, 0.34, 0.14,
                                      8, (x, 0.30, 2.10)), "fitting")
            ring = out[-1][0]
            brushkit.spin(ring, "y", 90.0)
            cores.append(brushkit.tube("eye_%d" % int(sx), 0.30, 0.22, 0.06,
                                       8, (x - sx * 0.10, 0.30, 2.10)))
            eye = cores[-1]
            brushkit.spin(eye, "y", 90.0)
        # The gap is EMPTY. No bridge, no rubble, nothing fallen into it.
        out += _tag(brushkit.block("void_kerb_l", (0.20, 1.20, 0.10),
                                   (-1.60, 0.30, 0.05)), "fitting")
        out += _tag(brushkit.block("void_kerb_r", (0.20, 1.20, 0.10),
                                   (1.60, 0.30, 0.05)), "fitting")
    else:
        # One terminal, and wreckage where the other should be. The pair is
        # broken, and that is instantly a different sentence.
        out += _tag(brushkit.block("plinth", (1.00, 1.00, 0.36),
                                   (-2.30, 0.30, 0.18)), "struct")
        out += _tag(brushkit.block("mast", (0.26, 0.26, 1.40),
                                   (-2.30, 0.30, 1.06), rotation_z=9.0),
                    "struct")
        for i in range(4):
            out += _tag(brushkit.block("debris_%d" % i,
                                       (0.42, 0.34, 0.22),
                                       (1.60 + 0.30 * i, 0.10 * i, 0.11),
                                       rotation_z=21.0 * i), "struct")
    return out, cores


GATES = [
    ("gate_grapple", _grapple, "grapple_anchor", True,
     "a railed, decked, lit landing with an anchor on a fixed bracket, and "
     "no floor route to either"),
    ("gate_break", _break, "breakable_wall", True,
     "an intact frame with a panel of a different construction in it"),
    ("gate_launch", _launch, "bounce_pad", True,
     "a complete pad on a complete plinth, aimed at a finished landing"),
    ("gate_blink_proposal", _blink, None, False,
     "a matched pair of finished terminals with an empty gap between them"),
]


def main():
    report = {}
    for name, builder, family, contract, reads_as in GATES:
        for finished in (True, False):
            common.reset_scene()
            full = name if finished else "%s_ragged" % name
            parts, cores = builder(finished)
            tagged = _floor_and_wall() + parts
            buckets = {}
            for obj, role in tagged:
                buckets.setdefault(role, []).append(obj)
            painted = []
            for role, canvas in (
                    ("struct", propkit.facility_host(THEME, full + "_s")),
                    ("fitting", propkit.painted_metal(THEME, full + "_f",
                                                      wear=0.18))):
                got = buckets.get(role)
                if not got:
                    continue
                obj = common.join(got, "%s_%s" % (full, role))
                common.uv_project_world(obj, propkit.PROP_DENSITY,
                                        propkit.PROP_SIZE)
                common.assign(obj, common.make_textured_material(
                    "%s_%s" % (full, role),
                    canvas.to_blender("%s_%s_t" % (full, role)),
                    roughness=pal.roughness(THEME)))
                painted.append(obj)
            if cores:
                core_obj = common.join(cores, full + "_cores")
                # The affordance ruling, followed exactly: signal marks the
                # capability opportunity and nothing else does.
                common.assign(core_obj, common.make_signal_material(
                    full + "_cores", pal.universal("signal", 0),
                    pal.universal("signal", 3), saturation=0.30))
                painted.append(core_obj)

            obj = common.join(painted, full)
            common.set_origin(obj, "floor")
            common.assert_fits(obj, full, BOX,
                               "A room-scale route fragment showing one "
                               "gate, or the ragged non-gate it must not be "
                               "mistaken for.")
            record = common.export_glb(obj, "%s/%s.glb" % (OUT, full), "room",
                                       check_flat=False)
            record.update({
                "batch": "034",
                "kind": "progression_gate" if finished else "ragged_control",
                "capability_family": family,
                "has_mechanical_contract": contract,
                "finished": finished,
                "reads_as": reads_as if finished
                            else "the same route, unfinished -- the reading "
                                 "this must NOT be confused with",
                "the_tell": "finish quality. Broken is ragged; installed is "
                            "neat. No colour carries this read.",
                "uses_hazard": False,
                "integration_ready": False,
                "scale_basis": "proposal scale",
            })
            report[full] = record

    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch034",
                       "gates", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")
    common.log("[batch034] %d assets -> %s" % (len(report), OUT))


if __name__ == "__main__":
    main()
