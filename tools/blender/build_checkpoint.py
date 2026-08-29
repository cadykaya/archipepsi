"""Batch 026 -- PROPOSAL: the checkpoint / re-entry station.

VISUAL LANGUAGE ONLY. Nothing here decides spawn mechanics, healing amount,
fast-travel rules or save semantics. Those are Production's.

## The audit, read-only, against current Production

`claude/archipepsi-echoes-continuation-b1adno`.

The closest thing that exists is `godot/scripts/gameplay/player.gd`:

    var _spawn_transform: Transform3D
    func set_spawn(xform: Transform3D) -> void

plus `RESPAWN_DELAY = 1.5` and a HUD death overlay that reads SIGNAL LOST.

That is **one slot holding one transform, with no identity.** There is no
checkpoint entity, no checkpoint state, and nowhere to record WHICH station
is the current one -- so of the three states this batch proposes, exactly
zero have a runtime representation today. `set_spawn()` is the seam a station
would call, and it would need to carry an id before "current re-entry anchor"
could be a thing the world can show. Interface requirement 27.

## The colour problem, and why the answer is no colour

The brief says avoid confusion with AP Check cyan/white, Epsilon green and
hazard orange. Every saturated family in `art_palette.json` is already spoken
for:

| family | means |
|---|---|
| `signal` #39d7c8 | you can use this -- the ONLY colour an interactable prompt may be |
| `hazard` #e8541f | this will hurt you. Never decorative, in any theme |
| `identity` #57ff1f | Epsilon, and nothing else in the game |
| `send` #ffd45c | this leaves for the multiworld |
| `glitch` #ff00e6 | Epsilon Static and the missing-world checker |
| `dead` #4a4f57 | unpowered, locked, spent, offline |

There is no unspent hue, and Batch 022 already established that the answer to
that is not to spend one anyway. So:

    THE CHECKPOINT IS THE ONE IMPORTANT OBJECT IN THE ROOM
    THAT DOES NOT GLOW.

In a world where everything that matters emits -- Check cyan, Epsilon green,
hazard orange, send yellow -- a tall achromatic structure that reflects
instead of emitting is *more* distinctive than another lit thing would be,
not less. It cannot be confused with any of the three the brief names,
because it is not competing in their channel at all.

The station is read by SHAPE, POSTURE and VALUE:

| state | mast | bands | light |
|---|---|---|---|
| inactive | folded flat into the pad | dark (`dead` 0-1) | none |
| activated | raised, cross-arms out | bright (`dead` 1-3) | none |
| current re-entry anchor | raised + canopy ring deployed | bright | ONE small achromatic lamp |

One point of light in the whole family, on the one state that means *this is
where you come back*. Everything else is posture and value.

## Bands are horizontal, and that is a rule not a style

The marking is a survey-staff band: alternating high and low value, in
HORIZONTAL bars. `hazard` marking is DIAGONAL striping (`paintkit.hazard_stripes`).
The two must not be confusable at distance in a dark room, and the safest
guarantee is that they differ in geometry rather than only in hue -- a
grey-scaled hazard stripe and a grey-scaled survey band have to still be
different things.

## Why a folding mast

The three states need to be tellable apart from across a room, in
silhouette, before any surface detail resolves. A change of POSTURE does
that at any distance and in any lighting; a change of surface does not.
Folded, raised, and raised-with-canopy are three different shapes, which is
the same argument Batch 022 made for using form over hue in navigation.

It is also a plausible object. A survey mast that stows flat is what you
would actually build for a place that is packed up and redeployed, which is
what a composed Zone is.

## Universal, not themed

Like the Check, this is SYSTEM furniture rather than architecture: the same
object in all six themes, so "can I come back here?" is never a question
about which Zone you are standing in. It is rendered against three theme
grounds for evidence, but it is one asset family.
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
OUT = "batch026/checkpoint"

PAD_R = 1.30            # the arrival pad
MAST_H = 2.90           # raised height
BOX = (3.4, 3.4, 3.6)

STATES = ("inactive", "activated", "anchor")

MEANS = {
    "inactive": "not yet activated. Folded, dark, and it does not glow.",
    "activated": "activated. Raised, cross-arms out, bands at high value.",
    "anchor": "the current re-entry anchor. Canopy deployed, one lamp lit.",
}


def _tag(objs, role):
    return [(o, role) for o in (objs if isinstance(objs, list) else [objs])]


def _pad(state):
    """The arrival pad. Its rim rises with the state, so the footprint on
    the FLOOR changes too -- a player looking down still gets an answer."""
    out = []
    out += _tag(brushkit.prism("pad", PAD_R, 0.16, 8, (0.0, 0.0, 0.08)),
                "dark")
    rim_h = {"inactive": 0.05, "activated": 0.13, "anchor": 0.22}[state]
    out += _tag(brushkit.tube("rim", PAD_R + 0.06, PAD_R - 0.10, rim_h, 8,
                              (0.0, 0.0, 0.16 + rim_h / 2)),
                "dark" if state == "inactive" else "light")
    # The stow recess the mast folds into: present in every state, so the
    # folded state reads as STOWED rather than as a mast that is missing.
    out += _tag(brushkit.block("recess", (0.34, PAD_R * 1.5, 0.05),
                               (0.0, 0.0, 0.17)), "dark")
    return out


def _bands(name, x, y, z0, height, count, light_first):
    """A survey-staff band stack: alternating value, HORIZONTAL bars.

    Horizontal is a rule, not a style -- hazard marking is diagonal, and the
    two must stay different objects even in grey scale.
    """
    out = []
    step = height / count
    for i in range(count):
        role = ("light" if (i % 2 == 0) == light_first else "dark")
        out += _tag(brushkit.block("%s_%d" % (name, i),
                                   (0.19, 0.19, step * 0.92),
                                   (x, y, z0 + step * (i + 0.5))), role)
    return out


def _mast(state):
    out = []
    cores = []
    if state == "inactive":
        # FOLDED: the mast lies in its recess. Same parts, same bands, a
        # different posture -- which is the whole point of the language.
        out += _tag(brushkit.block("mast_stowed", (0.22, 2.20, 0.22),
                                   (0.0, 0.10, 0.30)), "dark")
        # Bands run along the stowed mast, so it is legibly the SAME object.
        step = 2.00 / 6
        for i in range(6):
            role = "light" if i % 2 else "dark"
            out += _tag(brushkit.block("stow_%d" % i,
                                       (0.23, step * 0.92, 0.23),
                                       (0.0, -0.90 + step * (i + 0.5), 0.30)),
                        role)
        out += _tag(brushkit.block("head_stowed", (0.30, 0.30, 0.16),
                                   (0.0, 1.02, 0.32)), "dark")
        return out, cores

    # RAISED.
    out += _bands("mast", 0.0, 0.0, 0.24, MAST_H - 0.24, 8, False)
    # Cross-arms: the horizontal statement that says RAISED at any angle.
    for i, (z, half) in enumerate(((1.62, 0.62), (2.34, 0.44))):
        out += _tag(brushkit.block("arm_%d" % i, (half * 2, 0.13, 0.11),
                                   (0.0, 0.0, z)), "light")
        for sx in (-1.0, 1.0):
            out += _tag(brushkit.block("arm_cap_%d_%d" % (i, int(sx)),
                                       (0.15, 0.17, 0.19),
                                       (sx * half, 0.0, z)), "dark")
    out += _tag(brushkit.block("head", (0.32, 0.32, 0.24),
                               (0.0, 0.0, MAST_H + 0.06)), "dark")
    # Stays down to the pad, so a raised mast looks braced rather than
    # balanced -- it is meant to survive being come back to.
    for sx in (-1.0, 1.0):
        out += _tag(brushkit.sweep("stay_%d" % int(sx),
                                   [(sx * 0.10, 0.0, 2.30),
                                    (sx * 0.70, 0.0, 0.30)],
                                   0.05, 0.05), "dark")

    if state == "anchor":
        # THE CANOPY. Only the current re-entry anchor deploys it, and it
        # marks a VOLUME rather than a point -- the place you arrive into.
        out += _tag(brushkit.tube("canopy", 1.02, 0.90, 0.09, 8,
                                  (0.0, 0.0, MAST_H - 0.30)), "light")
        for i in range(4):
            a = i * 90.0
            out += _tag(brushkit.block("spoke_%d" % i, (0.96, 0.08, 0.07),
                                       (0.0, 0.0, MAST_H - 0.30),
                                       rotation_z=a), "dark")
        # The one point of light in the entire family, hung UNDER the
        # canopy. Mounted on top of the head it was captioned "one lamp
        # lit" and then hidden behind the canopy in every view -- and a
        # canopy lamp lights the pad you arrive on, so under it is also
        # where the object would really put it.
        cores.append(brushkit.prism("lamp", 0.11, 0.14, 8,
                                    (0.0, 0.0, MAST_H - 0.48)))
    return out, cores


def _finish(name, tagged, cores, entry):
    buckets = {}
    for obj, role in tagged:
        buckets.setdefault(role, []).append(obj)

    painted = []
    specs = [
        # Both treatments come out of the `dead` ramp. `dead` means
        # unpowered / locked / spent / offline, and a station you have not
        # switched on yet is exactly that -- so the family is not borrowing
        # a meaning it has no right to.
        ("dark", propkit.painted_metal(THEME, name + "_dark", wear=0.30),
         propkit.PROP_DENSITY, propkit.PROP_SIZE),
        ("light", propkit.bare_metal(THEME, name + "_light", wear=0.12),
         propkit.PROP_DENSITY, propkit.PROP_SIZE),
    ]
    for role, canvas, density, size in specs:
        parts = buckets.get(role)
        if not parts:
            continue
        obj = common.join(parts, "%s_%s" % (name, role))
        common.uv_project_world(obj, density, size)
        common.assign(obj, common.make_textured_material(
            "%s_%s" % (name, role),
            canvas.to_blender("%s_%s_t" % (name, role)),
            roughness=pal.roughness(THEME)))
        painted.append(obj)

    if cores:
        core_obj = common.join(cores, name + "_cores")
        # ACHROMATIC emission. Deliberately not a palette family: the point
        # of this whole batch is that the station does not compete in the
        # channel Check cyan, Epsilon green and hazard orange live in.
        common.assign(core_obj, common.make_signal_material(
            name + "_cores", "#6a7078", "#e8edf3", saturation=0.22))
        painted.append(core_obj)

    obj = common.join(painted, name)
    common.set_origin(obj, "floor")
    common.assert_fits(obj, name, BOX,
                       "A re-entry station stands in a Zone room and may "
                       "not overrun a corridor's width.")
    # `interactable` (900), not `prop` (300). The station is something the
    # player activates, exactly like the Check, and the first build failed
    # the prop ceiling at 308. The rule is to delete geometry rather than
    # raise a ceiling -- but that applies to an asset in the RIGHT tier. A
    # 2.5 m station is not a hand prop, and cutting bands off a survey mast
    # to fit a hand-prop budget would have been solving a labelling mistake
    # with the wrong tool.
    record = common.export_glb(obj, "%s/%s.glb" % (OUT, name),
                               "interactable", check_flat=False)
    record.update(entry)
    return record


def main():
    report = {}
    for state in STATES:
        common.reset_scene()
        name = "checkpoint_%s" % state
        mast, cores = _mast(state)
        report[name] = _finish(name, _pad(state) + mast, cores, {
            "batch": "026",
            "kind": "checkpoint_station",
            "state": state,
            "means": MEANS[state],
            "emits": state == "anchor",
            "emissive_is": "achromatic -- deliberately not a palette family",
            "read_by": "posture, then value. Never hue.",
            "band_orientation": "horizontal",
            "band_orientation_why": "hazard marking is diagonal; the two "
                                    "must differ in GEOMETRY, not only hue, "
                                    "so they stay distinct in grey scale",
            "universal": True,
            "universal_why": "system furniture like the Check -- 'can I come "
                             "back here' must not depend on which Zone you "
                             "are standing in",
            "runtime_state_exists": False,
            "runtime_seam": "player.gd set_spawn(Transform3D) is one slot "
                            "with no identity; nothing records WHICH station "
                            "is current (req 27)",
            "integration_ready": False,
            "scale_basis": "proposal scale",
        })

    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch026",
                       "checkpoint", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")
    common.log("[batch026] %d assets -> %s" % (len(report), OUT))


if __name__ == "__main__":
    main()
