"""Batch 028 -- PROPOSAL: the interaction primitive kit.

VISUAL LANGUAGE ONLY. Mechanics are Production's: nothing here decides what a
button triggers, how long a timer runs, what a launcher's arc is, how much
damage breaks an obstruction, or what a key opens.

## The audit, read-only, against current Production

`claude/archipepsi-echoes-continuation-b1adno`.

`godot/scripts/content/interactable_contract.gd` exists, and it is **about
the AP Check specifically**, not about interaction in general:

    const STATES := ["locked", "available", "sending", "confirmed"]
    const IDENTITY_VISIBLE_IN := "confirmed"
    const REQUIRED_PARTS := {
        "state_visual": "MeshInstance3D",
        "state_label": "Label3D",
    }

plus a `leak()` check that stops a label spoiling what a Check holds.

That state vocabulary fits **none** of the nine primitives below. A weight
button is not `locked / available / sending / confirmed`; neither is a door
ram, a fuse indicator or a breakable panel. So the nine have no runtime state
vocabulary at all today, and that is interface requirement 29.

**But `REQUIRED_PARTS` is real, and this kit is authored to it.** Every
primitive here carries one identifiable `state_visual` region and reserves a
place for a `state_label`. That is a contract art can honour today without
inventing anything, and it is the reason the grammar below is built the way
it is.

## The grammar: one plate, learned once

    THE PLATE IS THE STATE. EVERYTHING ELSE IS THE VERB.

Every primitive carries the same small recessed state plate, in `signal`
cyan, at the same relationship to its own affordance. Learn it once and every
object in the kit answers "what is this doing right now" in the same place.

That frees the rest of each object to be **entirely about what it does**, and
it is why the nine silhouettes below share nothing else at all.

`signal` is the licensed family here and this is the case it was written for:
*"you can use this -- the only colour an interactable prompt, rim or reveal
face is allowed to be."* These are the things you use. (Batch 026's
checkpoint deliberately does NOT take it, because a checkpoint is walked
onto rather than operated. The line between the two is exactly that verb.)

## Cause and effect, without drawing a wire

A switch and the thing it drives carry **the same plate**. When one changes,
the other does. A player who has learned the plate has learned causality
without a cable, a colour-coded pair, or a HUD line -- and it composes: one
plate on three doors says one switch drives three doors.

## Obvious affordance means the shape says the verb

| primitive | the verb its shape has to say |
|---|---|
| carryable | GRIP HERE -- recessed handles on two faces, at hand width |
| weight button | THIS GOES DOWN -- a visible travel gap and a compression skirt |
| wall switch | THROW THIS -- a lever proud of a guarded housing at hand height |
| door mechanism | THIS DRIVES THAT -- the ram and rack BESIDE a door, not the door |
| logic / timing | THIS IS COUNTING -- a column of segment cells that fill |
| launcher | THIS THROWS YOU, THAT WAY -- an angled sprung pad, plainly directional |
| breakable | THIS ONE FAILS -- a fracture grid and a weak seam the others do not have |
| key receiver | SOMETHING GOES IN HERE -- an empty keyway, shaped |
| machinery | IT IS PART WAY -- a travel indicator on a rail, showing extent |

## Not Portal, and not by accident

The brief forbids copying a reference game's recognisable objects. The two
that would drift there are the carryable and the weight button, so both are
deliberately built away from it: the carryable is a **handled industrial
crate**, rectangular and grip-first, not a cube with a symbol on each face;
the button is a **rectangular floor pad with a skirt**, not a round dish with
a beam over it. Nothing in the kit is round-and-glowing, nothing is a
companion, and no primitive is coloured as a pair.
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
OUT = "batch028/interaction"
BOX = (2.6, 2.6, 2.8)

#: The shared state plate. Same size, same inset, on every primitive --
#: it is the one thing the nine have in common.
PLATE_W, PLATE_H, PLATE_D = 0.20, 0.12, 0.03


def _tag(objs, role):
    return [(o, role) for o in (objs if isinstance(objs, list) else [objs])]


def _plate(at, rot=0.0):
    """The `state_visual`. One per primitive, always the same object."""
    out = []
    out += _tag(brushkit.block("plate_recess",
                               (PLATE_W + 0.05, PLATE_D + 0.02, PLATE_H + 0.05),
                               at, rotation_z=rot), "body")
    cores = [brushkit.block("plate", (PLATE_W, PLATE_D, PLATE_H),
                            (at[0], at[1] - 0.012, at[2]), rotation_z=rot)]
    return out, cores


def _carryable():
    """A handled industrial crate. Grip-first, and deliberately NOT a cube
    with a symbol on every face."""
    out = []
    out += _tag(brushkit.block("body", (0.52, 0.44, 0.42),
                               (0.0, 0.0, 0.21)), "body")
    # The handles are the whole affordance: recessed, hand width, on the two
    # faces you would actually pick it up by.
    for sx in (-1.0, 1.0):
        out += _tag(brushkit.block("grip_%d" % int(sx), (0.06, 0.26, 0.07),
                                   (sx * 0.29, 0.0, 0.30)), "accent")
        out += _tag(brushkit.block("grip_back_%d" % int(sx),
                                   (0.04, 0.30, 0.13),
                                   (sx * 0.25, 0.0, 0.30)), "body")
    for i in range(3):
        out += _tag(brushkit.block("rib_%d" % i, (0.54, 0.04, 0.04),
                                   (0.0, -0.22, 0.10 + i * 0.13)), "accent")
    p, cores = _plate((0.0, -0.225, 0.36))
    return out + p, cores


def _weight_button():
    """A rectangular floor pad with a VISIBLE travel gap. It has to say
    'this goes down' before anything stands on it."""
    out = []
    out += _tag(brushkit.block("frame", (0.96, 0.96, 0.10),
                               (0.0, 0.0, 0.05)), "body")
    # The gap is the affordance. A pad flush with its frame is a tile.
    out += _tag(brushkit.block("pad", (0.78, 0.78, 0.09),
                               (0.0, 0.0, 0.185)), "accent")
    for i in range(4):
        a = i * 90.0
        out += _tag(brushkit.block("skirt_%d" % i, (0.80, 0.05, 0.07),
                                   (0.0, 0.0, 0.115), rotation_z=a), "body")
    p, cores = _plate((0.0, -0.53, 0.09))
    return out + p, cores


def _wall_switch():
    """A lever proud of a guarded housing, at hand height."""
    out = []
    out += _tag(brushkit.block("back", (0.34, 0.10, 0.46),
                               (0.0, 0.06, 1.28)), "body")
    for sx in (-1.0, 1.0):
        out += _tag(brushkit.block("guard_%d" % int(sx), (0.05, 0.20, 0.44),
                                   (sx * 0.17, -0.04, 1.28)), "body")
    # A THROW handle, not a toggle. The first render read as a post with a
    # box on it: the lever was 0.07 m and vanished into its own housing at
    # any distance, so the one verb this object exists to say went unsaid.
    # It is now hand-sized, angled, and proud of the guard.
    out += _tag(brushkit.block("lever", (0.09, 0.34, 0.09),
                               (0.0, -0.19, 1.42), rotation_z=0.0), "accent")
    out += _tag(brushkit.wedge("lever_root", (0.14, 0.16, 0.16),
                               (0.0, -0.06, 1.34), axis="y"), "accent")
    out += _tag(brushkit.block("knob", (0.17, 0.15, 0.17),
                               (0.0, -0.34, 1.46)), "accent")
    out += _tag(brushkit.block("post", (0.14, 0.14, 1.06),
                               (0.0, 0.06, 0.53)), "body")
    p, cores = _plate((0.0, -0.06, 1.10))
    return out + p, cores


def _door_mechanism():
    """The RAM AND RACK beside a door, not the door. What drives it is the
    thing that has a state; the leaf is just a leaf."""
    out = []
    out += _tag(brushkit.block("jamb", (0.22, 0.30, 2.30),
                               (-0.62, 0.0, 1.15)), "body")
    out += _tag(brushkit.block("leaf", (0.90, 0.14, 2.10),
                               (0.0, 0.10, 1.05)), "body")
    # The mechanism: a rack up the jamb and a ram along it.
    out += _tag(brushkit.block("rack", (0.11, 0.13, 1.80),
                               (-0.62, -0.19, 1.30)), "accent")
    for i in range(9):
        out += _tag(brushkit.block("tooth_%d" % i, (0.14, 0.05, 0.06),
                                   (-0.62, -0.24, 0.52 + i * 0.19)), "body")
    out += _tag(brushkit.block("ram", (0.20, 0.20, 0.34),
                               (-0.62, -0.22, 1.66)), "accent")
    p, cores = _plate((-0.62, -0.34, 1.14))
    return out + p, cores


def _logic_indicator():
    """A column of segment cells that fill. It counts WITHOUT numerals, so
    it needs no font and works at any distance."""
    out = []
    out += _tag(brushkit.block("stem", (0.16, 0.16, 1.14),
                               (0.0, 0.0, 0.57)), "body")
    out += _tag(brushkit.block("head", (0.30, 0.18, 0.62),
                               (0.0, 0.0, 1.42)), "body")
    cores = []
    for i in range(5):
        out += _tag(brushkit.block("cell_%d" % i, (0.24, 0.06, 0.08),
                                   (0.0, -0.10, 1.18 + i * 0.12)), "accent")
        # Only the lower cells are lit: it is PART WAY, which is the state
        # a timing indicator has to be able to show.
        if i < 3:
            cores.append(brushkit.block("lit_%d" % i, (0.19, 0.03, 0.05),
                                        (0.0, -0.13, 1.18 + i * 0.12)))
    p, plate_cores = _plate((0.0, -0.10, 0.88))
    return out + p, cores + plate_cores


def _launcher():
    """An angled sprung pad. Plainly directional -- you can see which way
    it throws before you stand on it."""
    out = []
    out += _tag(brushkit.block("base", (0.90, 0.90, 0.14),
                               (0.0, 0.0, 0.07)), "body")
    out += _tag(brushkit.wedge("ramp", (0.80, 0.80, 0.46),
                               (0.0, 0.0, 0.30), axis="y"), "accent")
    # Springs, visible and compressed -- stored energy, not decoration.
    for sx in (-1.0, 1.0):
        for i in range(3):
            out += _tag(brushkit.block("coil_%d_%d" % (int(sx), i),
                                       (0.13, 0.13, 0.035),
                                       (sx * 0.26, 0.20, 0.17 + i * 0.06)),
                        "body")
    # Direction arrows on the deck: the vector, stated.
    for i in range(3):
        out += _tag(brushkit.wedge("arrow_%d" % i, (0.20, 0.16, 0.045),
                                   (0.0, -0.16 + i * 0.14, 0.40 + i * 0.10),
                                   axis="y"), "body")
    p, cores = _plate((0.0, -0.47, 0.10))
    return out + p, cores


def _breakable():
    """A panel that FAILS. It has to be visibly the weak one in a wall of
    otherwise identical panels, so it wears a fracture grid and a weak
    seam nothing else in the kit has."""
    out = []
    out += _tag(brushkit.block("frame_l", (0.10, 0.20, 1.90),
                               (-0.52, 0.0, 0.95)), "body")
    out += _tag(brushkit.block("frame_r", (0.10, 0.20, 1.90),
                               (0.52, 0.0, 0.95)), "body")
    out += _tag(brushkit.block("head", (1.14, 0.20, 0.12),
                               (0.0, 0.0, 1.84)), "body")
    # The fracture grid: shallow blocks with gaps, so it reads as ALREADY
    # divided into the pieces it will become.
    for r in range(4):
        for c in range(3):
            out += _tag(brushkit.block("shard_%d_%d" % (r, c),
                                       (0.30, 0.09, 0.40),
                                       (-0.32 + c * 0.32, 0.0,
                                        0.30 + r * 0.44)), "accent")
    p, cores = _plate((0.0, -0.10, 1.68))
    return out + p, cores


def _key_receiver():
    """An empty keyway, shaped. The hole says what fits before you have it."""
    out = []
    out += _tag(brushkit.block("housing", (0.42, 0.26, 0.56),
                               (0.0, 0.0, 1.20)), "body")
    out += _tag(brushkit.block("post", (0.16, 0.16, 0.94),
                               (0.0, 0.02, 0.47)), "body")
    # The keyway: a slot with a shoulder, so the shape is specific rather
    # than a generic hole. A player learns which key by its outline.
    out += _tag(brushkit.block("way_top", (0.09, 0.10, 0.16),
                               (0.0, -0.12, 1.30)), "accent")
    out += _tag(brushkit.block("way_bar", (0.22, 0.10, 0.07),
                               (0.0, -0.12, 1.16)), "accent")
    for sx in (-1.0, 1.0):
        out += _tag(brushkit.block("lug_%d" % int(sx), (0.05, 0.07, 0.05),
                                   (sx * 0.15, -0.13, 1.06)), "body")
    p, cores = _plate((0.0, -0.14, 0.90))
    return out + p, cores


def _machinery():
    """A driven rotor with a TRAVEL INDICATOR: it shows how far through it
    is, not merely that it is on."""
    out = []
    out += _tag(brushkit.block("bed", (1.10, 0.60, 0.22),
                               (0.0, 0.0, 0.11)), "body")
    out += _tag(brushkit.prism("rotor", 0.26, 0.52, 8, (0.28, 0.0, 0.48)),
                "accent")
    out += _tag(brushkit.block("housing", (0.44, 0.44, 0.62),
                               (-0.34, 0.0, 0.53)), "body")
    # The rail, and the carriage part-way along it. Extent, not on/off.
    # The travel indicator has to be the LOUDEST thing on the machine, not
    # a detail on it -- "it is part way" is the verb, and the first render
    # lost a 0.16 m carriage among rotor, housing and bed. Rail lifted
    # clear, carriage doubled, notches turned into a visible scale.
    out += _tag(brushkit.block("rail", (1.16, 0.10, 0.10),
                               (0.0, -0.38, 1.06)), "body")
    for sx in (-1.0, 1.0):
        out += _tag(brushkit.block("rail_post_%d" % int(sx),
                                   (0.08, 0.10, 0.24),
                                   (sx * 0.54, -0.38, 0.92)), "body")
    out += _tag(brushkit.block("carriage", (0.30, 0.20, 0.26),
                               (-0.20, -0.38, 1.12)), "accent")
    for i in range(6):
        out += _tag(brushkit.block("notch_%d" % i, (0.05, 0.12, 0.14),
                                   (-0.50 + i * 0.20, -0.38, 0.94)), "body")
    p, cores = _plate((-0.34, -0.24, 0.53))
    return out + p, cores


KIT = [
    ("int_carryable", _carryable, "carryable / movable object",
     "GRIP HERE", "recessed handles at hand width on two faces"),
    ("int_weight_button", _weight_button, "presence / weight button",
     "THIS GOES DOWN", "a visible travel gap and a compression skirt"),
    ("int_wall_switch", _wall_switch, "wall switch",
     "THROW THIS", "a lever proud of a guarded housing at hand height"),
    ("int_door_mechanism", _door_mechanism, "door mechanism",
     "THIS DRIVES THAT", "the ram and rack beside a door, not the door"),
    ("int_logic_indicator", _logic_indicator, "logic / timing indicator",
     "THIS IS COUNTING", "a column of segment cells, part filled"),
    ("int_launcher", _launcher, "launcher / bounce device",
     "IT THROWS YOU, THAT WAY", "an angled sprung pad with a stated vector"),
    ("int_breakable", _breakable, "breakable obstruction",
     "THIS ONE FAILS", "a fracture grid, already divided into its pieces"),
    ("int_key_receiver", _key_receiver, "local-key lock / receiver",
     "SOMETHING GOES IN HERE", "an empty shaped keyway with a shoulder"),
    ("int_machinery", _machinery, "machinery with obvious state change",
     "IT IS PART WAY", "a carriage part-way along a notched rail"),
]


def _finish(name, tagged, cores, entry):
    buckets = {}
    for obj, role in tagged:
        buckets.setdefault(role, []).append(obj)
    painted = []
    specs = [
        ("body", propkit.painted_metal(THEME, name + "_body", wear=0.24)),
        ("accent", propkit.bare_metal(THEME, name + "_acc", wear=0.16)),
    ]
    for role, canvas in specs:
        parts = buckets.get(role)
        if not parts:
            continue
        obj = common.join(parts, "%s_%s" % (name, role))
        common.uv_project_world(obj, propkit.PROP_DENSITY, propkit.PROP_SIZE)
        common.assign(obj, common.make_textured_material(
            "%s_%s" % (name, role),
            canvas.to_blender("%s_%s_t" % (name, role)),
            roughness=pal.roughness(THEME)))
        painted.append(obj)

    core_obj = common.join(cores, name + "_cores")
    # `signal` -- and this is the case that family was written for: "the
    # only colour an interactable prompt, rim or reveal face is allowed to
    # be." These are the things you use.
    common.assign(core_obj, common.make_signal_material(
        name + "_cores", pal.universal("signal", 0),
        pal.universal("signal", 3), saturation=0.30))
    painted.append(core_obj)

    obj = common.join(painted, name)
    common.set_origin(obj, "floor")
    common.assert_fits(obj, name, BOX,
                       "An interaction primitive stands in a room and may "
                       "not overrun a corridor's width.")
    record = common.export_glb(obj, "%s/%s.glb" % (OUT, name),
                               "interactable", check_flat=False)
    record.update(entry)
    return record


def main():
    report = {}
    for name, builder, label, verb, affordance in KIT:
        common.reset_scene()
        parts, cores = builder()
        report[name] = _finish(name, parts, cores, {
            "batch": "028",
            "kind": "interaction_primitive",
            "represents": label,
            "verb_the_shape_says": verb,
            "affordance": affordance,
            "carries_state_plate": True,
            "state_plate_is": "the `state_visual` of "
                              "interactable_contract.REQUIRED_PARTS",
            "palette_family": "signal",
            "palette_licence": "the only colour an interactable prompt, rim "
                               "or reveal face is allowed to be -- and these "
                               "are the things you use",
            "runtime_states_exist": False,
            "runtime_seam": "InteractableContract.STATES is the AP Check's "
                            "vocabulary (locked/available/sending/confirmed) "
                            "and fits none of these (req 29)",
            "integration_ready": False,
            "scale_basis": "proposal scale",
        })

    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch028",
                       "interaction", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")
    common.log("[batch028] %d assets -> %s" % (len(report), OUT))


if __name__ == "__main__":
    main()
