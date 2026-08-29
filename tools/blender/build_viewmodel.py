"""Batch 032 -- PROPOSAL: the baseline melee, and the Echo family seam.

VISUAL LANGUAGE ONLY. No damage, speed, combo, upgrade, hit detection or
animation timing is decided.

## Authored to a contract that already exists

`godot/scripts/gameplay/player.gd` builds `$Camera3D/Viewmodel` at
`(0.34, -0.3, -0.62)`, rotation `(0, 8, -4)`, with four NAMED children:

    Device    PrismMesh 0.14 x 0.16 x 0.40   the Static Pulse emitter, ALWAYS there
    Tip       Box 0.05 x 0.05 x 0.08         its emitter tip, glow 1.6
    EchoPart  Box 0.10 x 0.08 x 0.26         hidden until an Echo is equipped
    EchoTip   Box 0.05 x 0.04 x 0.05         the attachment's emitter tip

Everything here is built at those exact dimensions, because the seam is
named nodes and a proposal that ignores their sizes is a proposal Production
cannot drop in.

## Why the melee is the device, and not a weapon

The reasoning, stated as the brief asks:

- **a fantasy sword** has no business in an abandoned research facility;
- **a crowbar** is another game's recognisable object, which the brief forbids;
- **a military knife** says soldier, and the player is not one;
- **any separate tool** has to be carried, and there is no first-person body
  to carry it on -- there are no hands, no arms, and the device floats.

So the baseline melee is a **discharge fork that folds out of the Device**:
a facility instrument's two-tine grounding prong, the thing you would use to
short a capacitor bank safely, swung because it is what is in your hand.
Human-built, facility-plausible, and it earns its place by already being on
the object rather than appearing from nowhere.

**Epsilon has not modified it, deliberately.** The Static Pulse is the one
thing in this game that is yours. The intrusion DNA belongs on Epsilon's own
installations; putting it on the player's baseline would say the alien had
taken the last thing you owned, which is a story beat nobody has written.

`hazard` orange is not used: telegraph orange stays reserved for danger
directed AT the player.

## The Forge seam -- and this is the more important half

`EchoRuntime._refresh_viewmodel_attachment()` paints `EchoPart` with
`source_color()` -- the world the Echo came FROM -- and `EchoTip` with the
slot. Both are correct and both are already good. But between them they mean:

    a reforge from RANGED to GRAPPLE changes NOTHING on the viewmodel.

Same source item, so the same body colour. Same button, so the same tip. The
one operation the Forge exists to perform is invisible in the one view the
player spends the whole game looking at.

The fix is not hundreds of Echo weapons. It is **one node made swappable**:

    EchoPart  form   -> FAMILY   (seven forms, one per Forge dial position)
    EchoPart  colour -> SOURCE   (unchanged, already implemented)
    EchoTip   colour -> SLOT     (unchanged, already implemented)

Three channels, three meanings, no collisions -- and the seven forms are the
same seven families as Batch 025's selector dial, so the Forge's control and
its result speak the same vocabulary.

Three of the seven are built here as evidence that the forms separate at
viewmodel scale. The other four are deliberately not built: the point is the
seam, not the roster.
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
OUT = "batch032/viewmodel"

#: Read from player.gd. Not redefined, not rounded.
DEVICE = (0.14, 0.16, 0.40)
ECHOPART = (0.10, 0.08, 0.26)
BOX = (0.9, 0.9, 0.9)


def _tag(objs, role):
    return [(o, role) for o in (objs if isinstance(objs, list) else [objs])]


def _device(deployed):
    """The Static Pulse transmitter, with the discharge fork folded or out."""
    out, cores = [], []
    w, h, d = DEVICE
    out += _tag(brushkit.block("shell", (w, d, h), (0.0, 0.0, h / 2)),
                "shell")
    out += _tag(brushkit.block("grip_strap", (w + 0.012, d * 0.34, h * 0.30),
                               (0.0, d * 0.10, h * 0.34)), "grip")
    # The emitter tip, which is `Tip` in the contract and stays lit.
    out += _tag(brushkit.block("tip_housing", (w * 0.52, d * 0.34, h * 0.14),
                               (0.0, -d * 0.42, h * 0.86)), "shell")
    cores.append(brushkit.block("tip", (0.05, 0.05, 0.08),
                                (0.0, -d * 0.56, h * 0.86)))

    # THE FORK. A grounding prong: two tines and an insulated root. Folded
    # along the shell when stowed, swung forward when deployed.
    root_z = h * 0.62
    if deployed:
        for sx in (-1.0, 1.0):
            out += _tag(brushkit.block("tine_%d" % int(sx),
                                       (0.016, 0.20, 0.016),
                                       (sx * 0.030, -d * 0.95, root_z)),
                        "fork")
        out += _tag(brushkit.block("yoke", (0.086, 0.030, 0.022),
                                   (0.0, -d * 0.52, root_z)), "fork")
        out += _tag(brushkit.block("insulator", (0.052, 0.048, 0.034),
                                   (0.0, -d * 0.30, root_z)), "grip")
    else:
        for sx in (-1.0, 1.0):
            out += _tag(brushkit.block("tine_%d" % int(sx),
                                       (0.016, 0.016, 0.19),
                                       (sx * 0.030, d * 0.44, root_z - 0.05)),
                        "fork")
        out += _tag(brushkit.block("yoke", (0.086, 0.022, 0.030),
                                   (0.0, d * 0.44, root_z + 0.07)), "fork")
        out += _tag(brushkit.block("insulator", (0.052, 0.034, 0.048),
                                   (0.0, d * 0.36, root_z - 0.03)), "grip")
    return out, cores


def _echopart(family):
    """One EchoPart family form, at the contract's exact 0.10 x 0.08 x 0.26.

    The shapes are chosen so the three separate in SILHOUETTE at viewmodel
    scale, where an attachment occupies maybe sixty pixels.
    """
    out, cores = [], []
    w, d, h = ECHOPART[0], ECHOPART[1], ECHOPART[2]
    out += _tag(brushkit.block("mount", (w * 0.70, d * 0.80, h * 0.26),
                               (0.0, 0.0, h * 0.13)), "grip")

    if family == "ranged":
        # A barrel: long, closed, pointing away. The existing default.
        out += _tag(brushkit.block("body", (w, d, h * 0.66),
                                   (0.0, 0.0, h * 0.55)), "shell")
        out += _tag(brushkit.prism("bore", w * 0.30, h * 0.16, 8,
                                   (0.0, 0.0, h * 0.94)), "shell")
        cores.append(brushkit.block("muzzle", (0.05, 0.04, 0.05),
                                    (0.0, 0.0, h * 1.00)))
    elif family == "melee":
        # A blade-plane: flat, wide, edge forward. Nothing bores through it.
        out += _tag(brushkit.block("body", (w * 1.05, d * 0.42, h * 0.62),
                                   (0.0, 0.0, h * 0.53)), "shell")
        out += _tag(brushkit.wedge("edge", (w * 1.05, d * 0.34, h * 0.30),
                                   (0.0, -d * 0.22, h * 0.74), axis="y"),
                    "shell")
        cores.append(brushkit.block("edge_line", (w * 0.86, 0.014, 0.030),
                                    (0.0, -d * 0.36, h * 0.80)))
    elif family == "grapple":
        # An OPEN claw: the only one of the three with a hole in its
        # silhouette, which is what makes it readable at sixty pixels.
        for sx in (-1.0, 1.0):
            out += _tag(brushkit.block("jaw_%d" % int(sx),
                                       (w * 0.26, d * 0.36, h * 0.56),
                                       (sx * w * 0.36, 0.0, h * 0.50)),
                        "shell")
            out += _tag(brushkit.wedge("hook_%d" % int(sx),
                                       (w * 0.26, d * 0.34, h * 0.22),
                                       (sx * w * 0.30, -d * 0.10, h * 0.84),
                                       axis="y"), "shell")
        out += _tag(brushkit.block("spool", (w * 0.44, d * 0.44, h * 0.20),
                                   (0.0, 0.0, h * 0.34)), "grip")
        cores.append(brushkit.block("line", (0.016, 0.016, h * 0.30),
                                    (0.0, 0.0, h * 0.62)))
    return out, cores


FAMILIES = ("ranged", "melee", "grapple")


def _finish(name, tagged, cores, entry):
    buckets = {}
    for obj, role in tagged:
        buckets.setdefault(role, []).append(obj)
    painted = []
    for role, canvas, rough in (
            ("shell", propkit.machine_bank(THEME, name + "_sh", "panel"),
             None),
            ("grip", propkit.painted_metal(THEME, name + "_gr", wear=0.30),
             None),
            # The fork is bare conductor: bright, low wear, low roughness.
            ("fork", propkit.bare_metal(THEME, name + "_fk", wear=0.06),
             0.30)):
        parts = buckets.get(role)
        if not parts:
            continue
        obj = common.join(parts, "%s_%s" % (name, role))
        # Viewmodel tier: a thing held 0.6 m from the camera gets the
        # deferred viewmodel density, not the prop one.
        common.uv_project_world(obj, propkit.HERO_DENSITY, propkit.HERO_SIZE)
        common.assign(obj, common.make_textured_material(
            "%s_%s" % (name, role),
            canvas.to_blender("%s_%s_t" % (name, role)),
            roughness=pal.roughness(THEME) if rough is None else rough))
        painted.append(obj)
    core_obj = common.join(cores, name + "_cores")
    common.assign(core_obj, common.make_signal_material(
        name + "_cores", pal.universal("signal", 0),
        pal.universal("signal", 3), saturation=0.32))
    painted.append(core_obj)

    obj = common.join(painted, name)
    common.set_origin(obj, "floor")
    common.assert_fits(obj, name, BOX,
                       "A viewmodel part held at the camera. It is built to "
                       "player.gd's own node dimensions.")
    record = common.export_glb(obj, "%s/%s.glb" % (OUT, name), "prop",
                               check_flat=False)
    record.update(entry)
    return record


def main():
    report = {}
    for deployed in (False, True):
        common.reset_scene()
        name = "vm_device_melee" if deployed else "vm_device_stowed"
        parts, cores = _device(deployed)
        report[name] = _finish(name, parts, cores, {
            "batch": "032",
            "kind": "viewmodel_device",
            "state": "melee deployed" if deployed else "stowed",
            "binds_to": "$Camera3D/Viewmodel/Device",
            "device_contract_m": list(DEVICE),
            "what_it_is": "the Static Pulse transmitter's own discharge "
                          "fork -- a facility grounding prong, swung "
                          "because it is what is in your hand",
            "epsilon_modified": False,
            "epsilon_modified_why": "the Static Pulse is the one thing in "
                                    "the game that is yours",
            "uses_hazard": False,
            "invents_no_timing": True,
            "integration_ready": False,
            "scale_basis": "player.gd's own viewmodel dimensions",
        })

    for family in FAMILIES:
        common.reset_scene()
        name = "vm_echopart_%s" % family
        parts, cores = _echopart(family)
        report[name] = _finish(name, parts, cores, {
            "batch": "032",
            "kind": "viewmodel_echopart",
            "family": family,
            "binds_to": "$Camera3D/Viewmodel/EchoPart",
            "echopart_contract_m": list(ECHOPART),
            "channel_proposal": "FORM carries family; COLOUR still carries "
                                "source (unchanged); the tip still carries "
                                "the slot (unchanged)",
            "why": "a reforge from ranged to grapple currently changes "
                   "nothing on the viewmodel -- same source, same slot",
            "families_total": 7,
            "families_built_here": len(FAMILIES),
            "families_built_here_why": "the deliverable is the seam, not "
                                       "the roster",
            "integration_ready": False,
            "scale_basis": "player.gd's own EchoPart dimensions",
        })

    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch032",
                       "viewmodel", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")
    common.log("[batch032] %d assets -> %s" % (len(report), OUT))


if __name__ == "__main__":
    main()
