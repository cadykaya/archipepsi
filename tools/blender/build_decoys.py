"""Batch 035 -- interactable vs decorative readability.

VISUAL LANGUAGE ONLY. No mechanic is decided.

## What this batch actually is

Batch 028 built nine interaction primitives and proposed a grammar: *the
plate is the state, everything else is the verb.* That sheet showed the nine
ALONE, which is the easy case. This one builds what they have to survive:

    a room full of things that look like them and do nothing.

The failures named in the brief are all the same failure -- **one movable
crate among fifty identical immovable crates; one breakable wall identical to
every decorative wall; one usable switch among fake control panels;
operational doors indistinguishable from background bulkheads.** So the six
DECOYS here are deliberately built as near-misses, not as obviously different
objects. A decoy that is easy to reject proves nothing.

## The grammar being tested

Not colour. The brief is explicit that painting every interactable Epsilon
green is not the answer, and Batch 028 already refused that: `signal` cyan
says *you can use this*, which is a licensed semantic, but if it were the ONLY
tell then a player in a dark room or a player who cannot separate cyan from
the theme's own accent has nothing.

So the claim under test is that four **structural** tells carry it, and the
plate is the fifth and last:

| tell | interactable | decoy |
|---|---|---|
| **grip / handle** | sized for a hand, proud of the surface, worn | none, or moulded flush as a shape |
| **mounting hardware** | real fixings that could be undone | dummy bosses with no fastener |
| **mechanical joint** | a hinge line, a pivot, a track | a scribed seam that goes nowhere |
| **actuator construction** | something that could move it, and somewhere for it to go | solid behind |
| **state plate** | present | absent |

The last row is doing the least work on purpose. If the recognition sheet
only works because the reader spotted a cyan rectangle, the grammar has not
been demonstrated -- so the sheet is also shown with the plate channel
suppressed, and that second row is the real result.

## The decoys

Each is the nearest plausible non-functional twin of one of Batch 028's
primitives, built from the same kit at the same scale:

| decoy | shadows | why it is a fair test |
|---|---|---|
| `dec_crate_fixed` | `int_carryable` | same box, same ribs, NO grips -- the difference is one feature |
| `dec_panel_blind` | `int_breakable` | same framed panel, but coursed as one piece with no fracture grid |
| `dec_console_dead` | `int_wall_switch` | a control panel with mouldings where a lever would be |
| `dec_bulkhead` | `int_door_mechanism` | a door-sized recess with no jamb, no rack, no ram |
| `dec_hatch_welded` | `int_key_receiver` | a hatch outline with its fixings welded over |
| `dec_pipe_fixed` | `int_machinery` | machinery-scale plant with no travel, no carriage, no rail |

Nothing here is a straw man. Each shares its twin's silhouette family and
differs only in the tells above.
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
OUT = "batch035/decoys"
BOX = (2.6, 2.6, 2.8)


def _tag(objs, role):
    return [(o, role) for o in (objs if isinstance(objs, list) else [objs])]


def _crate_fixed():
    """`int_carryable` with no grips. One feature apart, and that feature is
    the entire affordance."""
    out = []
    out += _tag(brushkit.block("body", (0.52, 0.44, 0.42),
                               (0.0, 0.0, 0.21)), "body")
    for i in range(3):
        out += _tag(brushkit.block("rib_%d" % i, (0.54, 0.04, 0.04),
                                   (0.0, -0.22, 0.10 + i * 0.13)), "accent")
    # Moulded shapes where the grips would be: the SHAPE of a handle with
    # no gap behind it. This is the near-miss the brief is really about.
    for sx in (-1.0, 1.0):
        out += _tag(brushkit.block("moulding_%d" % int(sx),
                                   (0.03, 0.24, 0.05),
                                   (sx * 0.26, 0.0, 0.30)), "body")
    # Welded to the deck. A crate that could be carried does not have a
    # fillet round its base.
    out += _tag(brushkit.block("fillet", (0.58, 0.50, 0.04),
                               (0.0, 0.0, 0.02)), "body")
    return out


def _panel_blind():
    """`int_breakable`'s frame, coursed as ONE piece. No fracture grid."""
    out = []
    out += _tag(brushkit.block("frame_l", (0.10, 0.20, 1.90),
                               (-0.52, 0.0, 0.95)), "body")
    out += _tag(brushkit.block("frame_r", (0.10, 0.20, 1.90),
                               (0.52, 0.0, 0.95)), "body")
    out += _tag(brushkit.block("head", (1.14, 0.20, 0.12),
                               (0.0, 0.0, 1.84)), "body")
    out += _tag(brushkit.block("field", (0.96, 0.09, 1.66),
                               (0.0, 0.0, 0.90)), "accent")
    for i in range(3):
        out += _tag(brushkit.block("scribe_%d" % i, (0.96, 0.02, 0.02),
                                   (0.0, -0.05, 0.42 + i * 0.48)), "body")
    return out


def _console_dead():
    """A control panel with mouldings where a lever would be."""
    out = []
    out += _tag(brushkit.block("back", (0.34, 0.10, 0.46),
                               (0.0, 0.06, 1.28)), "body")
    for sx in (-1.0, 1.0):
        out += _tag(brushkit.block("guard_%d" % int(sx), (0.05, 0.20, 0.44),
                                   (sx * 0.17, -0.04, 1.28)), "body")
    out += _tag(brushkit.block("face", (0.26, 0.04, 0.38),
                               (0.0, -0.09, 1.28)), "accent")
    for i in range(4):
        out += _tag(brushkit.block("blank_%d" % i, (0.06, 0.03, 0.06),
                                   (-0.07 + (i % 2) * 0.14, -0.11,
                                    1.18 + int(i / 2) * 0.16)), "body")
    out += _tag(brushkit.block("post", (0.14, 0.14, 1.06),
                               (0.0, 0.06, 0.53)), "body")
    return out


def _bulkhead():
    """A door-sized recess with no jamb, no rack and no ram."""
    out = []
    out += _tag(brushkit.block("wall", (1.30, 0.24, 2.30),
                               (0.0, 0.10, 1.15)), "body")
    out += _tag(brushkit.block("recess", (0.92, 0.08, 2.02),
                               (0.0, -0.04, 1.05)), "accent")
    for i in range(4):
        out += _tag(brushkit.block("stud_%d" % i, (0.07, 0.04, 0.07),
                                   (-0.34 + (i % 2) * 0.68, -0.09,
                                    0.44 + int(i / 2) * 1.24)), "body")
    return out


def _hatch_welded():
    """A hatch outline whose fixings are welded over. It WAS an opening."""
    out = []
    out += _tag(brushkit.block("post", (0.16, 0.16, 0.94),
                               (0.0, 0.02, 0.47)), "body")
    out += _tag(brushkit.block("housing", (0.42, 0.26, 0.56),
                               (0.0, 0.0, 1.20)), "body")
    out += _tag(brushkit.block("outline", (0.30, 0.04, 0.40),
                               (0.0, -0.12, 1.22)), "accent")
    for i in range(4):
        out += _tag(brushkit.wedge("weld_%d" % i, (0.14, 0.06, 0.06),
                                   (-0.10 + (i % 2) * 0.20, -0.14,
                                    1.08 + int(i / 2) * 0.28), axis="y"),
                    "body")
    return out


def _pipe_fixed():
    """Machinery-scale plant with no travel, no carriage and no rail."""
    out = []
    out += _tag(brushkit.block("bed", (1.10, 0.60, 0.22),
                               (0.0, 0.0, 0.11)), "body")
    out += _tag(brushkit.prism("drum", 0.26, 0.52, 8, (0.28, 0.0, 0.48)),
                "accent")
    out += _tag(brushkit.block("housing", (0.44, 0.44, 0.62),
                               (-0.34, 0.0, 0.53)), "body")
    out += _tag(brushkit.block("pipe", (1.00, 0.10, 0.10),
                               (0.0, -0.31, 0.90)), "body")
    for sx in (-1.0, 1.0):
        out += _tag(brushkit.block("clamp_%d" % int(sx), (0.09, 0.14, 0.14),
                                   (sx * 0.40, -0.31, 0.90)), "body")
    return out


DECOYS = [
    ("dec_crate_fixed", _crate_fixed, "int_carryable",
     "same box and ribs, but the handles are MOULDINGS with no gap, and it "
     "is filleted to the deck"),
    ("dec_panel_blind", _panel_blind, "int_breakable",
     "the same framed panel, coursed as one piece; scribed lines instead of "
     "a fracture grid"),
    ("dec_console_dead", _console_dead, "int_wall_switch",
     "a control face with blanked bosses where a lever would be"),
    ("dec_bulkhead", _bulkhead, "int_door_mechanism",
     "a door-sized recess with no jamb, no rack, no ram"),
    ("dec_hatch_welded", _hatch_welded, "int_key_receiver",
     "a hatch outline with its fixings welded over"),
    ("dec_pipe_fixed", _pipe_fixed, "int_machinery",
     "machinery-scale plant with no travel, no carriage, no rail"),
]


def main():
    report = {}
    for name, builder, shadows, why in DECOYS:
        common.reset_scene()
        tagged = builder()
        buckets = {}
        for obj, role in tagged:
            buckets.setdefault(role, []).append(obj)
        painted = []
        for role, canvas in (
                ("body", propkit.painted_metal(THEME, name + "_body",
                                               wear=0.24)),
                ("accent", propkit.bare_metal(THEME, name + "_acc",
                                              wear=0.16))):
            parts = buckets.get(role)
            if not parts:
                continue
            obj = common.join(parts, "%s_%s" % (name, role))
            common.uv_project_world(obj, propkit.PROP_DENSITY,
                                    propkit.PROP_SIZE)
            common.assign(obj, common.make_textured_material(
                "%s_%s" % (name, role),
                canvas.to_blender("%s_%s_t" % (name, role)),
                roughness=pal.roughness(THEME)))
            painted.append(obj)
        obj = common.join(painted, name)
        common.set_origin(obj, "floor")
        common.assert_fits(obj, name, BOX,
                           "A decorative near-twin of an interaction "
                           "primitive; same scale as the thing it shadows.")
        record = common.export_glb(obj, "%s/%s.glb" % (OUT, name), "prop",
                                   check_flat=False)
        record.update({
            "batch": "035",
            "kind": "decorative_decoy",
            "shadows": shadows,
            "why_it_is_a_fair_test": why,
            # The point of the whole batch: NO decoy carries one.
            "carries_state_plate": False,
            "palette_family": "none -- a decoy may never wear `signal`",
            "integration_ready": False,
            "scale_basis": "proposal scale",
        })
        report[name] = record

    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch035",
                       "decoys", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")
    common.log("[batch035] %d assets -> %s" % (len(report), OUT))


if __name__ == "__main__":
    main()
