"""Batch 031 -- PROPOSAL: the local Zone key family.

VISUAL LANGUAGE ONLY. Nothing here decides how many keys a Zone has, whether
one is consumed or retained, how it persists, or anything about AP behaviour.

## What this has to be distinct from, and how

| must not be confused with | what separates them |
|---|---|
| **Signal Key** (an AP item, `SIGNAL_KEY_COUNT = 2`, campaign-wide) | scale and ceremony. A Signal Key is campaign progression and there are two in a whole run; a Zone key is local and disposable-feeling. **No Signal Key art exists yet** -- when it is built, this distinction is a constraint ON THAT BATCH, and it is recorded here so it is not discovered late. |
| **Epsilon Coin** | silhouette. The coin is a DISC ON EDGE in a cradle; the key is a flat shank lying along the mat. Nothing about them rhymes. |
| **AP Check** | scale and posture. A Check is a pedestal you approach; a key is a thing you pick up off the floor. |
| **health / ammo / resources** | Batch 027's silhouette test already separates those five, and the key joins the same test rather than dodging it. |

## The A-vs-B question, and the answer

The brief asks whether there should be
**(A)** one universal semantic key object with theme treatment, or
**(B)** theme-native key objects sharing one unmistakable semantic feature.

**Neither, exactly -- and the reason is the receiver.**

Batch 028 built `int_key_receiver` as *"an empty shaped keyway with a
shoulder"*. A key and its receiver are one system: the keyway is a picture of
the key, drawn in negative, and the player learns the key by seeing the hole
before they ever hold one. That forces the answer:

> **The part the receiver reads must be universal. Everything else may be
> themed.**

So the family splits into two zones, and the split is functional rather than
stylistic:

| zone | universal or themed | why |
|---|---|---|
| **the SHANK and its SHOULDER** -- the part that enters the keyway | **universal, identical everywhere** | it has to fit a hole whose shape the player already learned. A themed shank would mean six keyways, and six keyways means the hole teaches nothing |
| **the BIT** -- the coded lug array | **universal geometry, per-CHANNEL count** | this is what makes channels scalable |
| **the GRIP and its material** | **themed** | the part a hand holds is the part that can afford to belong to its Zone |

That is option A's semantic guarantee with option B's local flavour, and the
line between them is not a compromise -- it is drawn exactly where the
mechanism needs it.

## Channels are COUNTED, not coloured

The brief requires readability without colour and scalability to several
channels later. Both fall out of the same decision:

    channel N  =  N lugs on the bit, plus the shoulder notch rotated N steps

Counting is the most reliable discrimination this rendering language has --
Batch 029 found the opposite case, where a THREE-versus-FOUR mark count at
wall distance failed because the marks were fine surface detail. Here the
lugs are structural, at hand scale, and read against the mat's own edge. The
notch rotation is a second, redundant channel for the same information, so
the read does not depend on counting alone.

Three channels are built. The scheme extends to as many as the bit has room
for without changing anything else.

## Not a keycard and not a fantasy key

The brief forbids both, and the forms are chosen away from them:

- **Not a Doom keycard or skull key.** No flat coloured card, no icon plate,
  no colour-as-identity at all -- colour carries nothing here.
- **Not a fantasy key.** No bow-and-ward silhouette, no ornament, no bit
  cut from a wafer. This is a **machined interlock blank**: a shank, a
  shoulder collar that seats against a face, and a lug array that indexes.
  It looks like something a facility's stores would hold a hundred of.

## The mat is inherited on purpose

Every key sits on Batch 027's hexagonal pickup mat, unchanged. That grammar
already means *you can take this*; a key is a pickup, so it joins the family
rather than arguing for itself. It also puts the key into the same silhouette
comparison the five pickups already passed.
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

OUT = "batch031/keys"
#: Keys are hand props on a mat; receivers are wall fixtures at hand
#: height. One box cannot serve both, and pretending it can just moves
#: the failure to whichever one is measured second.
KEY_BOX = (1.4, 1.4, 0.6)
RECEIVER_BOX = (1.0, 0.8, 1.7)

#: Batch 027's mat, unchanged. A key is a pickup.
MAT_R = 0.30
MAT_H = 0.05

#: The universal shank. These four numbers are the contract between a key
#: and a receiver's keyway, and they do NOT vary by theme or by channel.
SHANK_L = 0.30
SHANK_W = 0.075
SHANK_T = 0.032
SHOULDER_R = 0.085

CHANNELS = (1, 2, 3)
THEMES = ("concrete_facility", "rusted_industrial", "void_glitch")


def _tag(objs, role):
    return [(o, role) for o in (objs if isinstance(objs, list) else [objs])]


def _mat():
    out = []
    out += _tag(brushkit.prism("mat", MAT_R, MAT_H, 8, (0.0, 0.0, MAT_H / 2)),
                "base")
    out += _tag(brushkit.tube("mat_rim", MAT_R + 0.02, MAT_R - 0.05, 0.03, 8,
                              (0.0, 0.0, MAT_H + 0.015)), "base")
    return out


def _key(channel):
    """One key. The shank is universal; the bit counts the channel."""
    out = []
    cores = []
    z = MAT_H + 0.06

    # A low cradle, so the key lies at a readable angle instead of flat.
    out += _tag(brushkit.wedge("rest", (0.20, 0.14, 0.06),
                               (-0.10, 0.0, MAT_H + 0.03), axis="y"), "base")

    # --- THE SHANK. Universal. This is what the keyway is a picture of.
    out += _tag(brushkit.block("shank", (SHANK_W, SHANK_L, SHANK_T),
                               (0.0, 0.02, z)), "steel")
    # The shoulder collar: what seats against the receiver's face, and the
    # feature that says "this goes IN something" rather than "this is a bar".
    out += _tag(brushkit.tube("shoulder", SHOULDER_R, SHOULDER_R - 0.022,
                              0.030, 8, (0.0, -0.10, z)), "steel")
    shoulder = out[-1][0]
    brushkit.spin(shoulder, "x", 90.0)
    # The shoulder NOTCH, rotated one step per channel. A second, redundant
    # carrier of the same information, so the read never depends on counting
    # alone -- the failure mode Batch 029 found for fine repeated marks.
    a = math.radians(90.0 + channel * 40.0)
    out += _tag(brushkit.block("notch", (0.030, 0.022, 0.030),
                               (SHOULDER_R * math.cos(a) * 0.85, -0.10,
                                z + SHOULDER_R * math.sin(a) * 0.85)),
                "steel")

    # --- THE BIT. Channel N carries N lugs, structural and at hand scale.
    for i in range(channel):
        out += _tag(brushkit.block("lug_%d" % i, (SHANK_W + 0.045, 0.030,
                                                  SHANK_T + 0.030),
                                   (0.0, 0.10 - i * 0.055, z)), "steel")

    # --- THE GRIP. The only themed part, and the only part a hand touches.
    out += _tag(brushkit.block("grip", (0.115, 0.105, 0.055),
                               (0.0, -0.19, z + 0.006)), "grip")
    out += _tag(brushkit.tube("grip_eye", 0.036, 0.020, 0.052, 8,
                              (0.0, -0.225, z + 0.006)), "grip")
    eye = out[-1][0]
    brushkit.spin(eye, "x", 90.0)
    # One small lit index on the grip. NOT the channel -- the channel is
    # geometry. This says only "this is live local progression", which is
    # what `signal` is licensed for: an interactable you can use.
    cores.append(brushkit.block("index", (0.042, 0.016, 0.014),
                                (0.0, -0.155, z + 0.036)))
    return out, cores


def _receiver(channel):
    """The mating half, rebuilt from Batch 028's receiver with THIS
    channel's keyway. The hole is a picture of the key."""
    out = []
    cores = []
    out += _tag(brushkit.block("housing", (0.42, 0.26, 0.56),
                               (0.0, 0.0, 1.20)), "base")
    out += _tag(brushkit.block("post", (0.16, 0.16, 0.94),
                               (0.0, 0.02, 0.47)), "base")
    # The keyway: shank slot, shoulder seat, and N lug reliefs. Same
    # numbers as the key, because a keyway that is not the key's negative
    # is decoration.
    out += _tag(brushkit.block("way_shank", (SHANK_W + 0.012, 0.10,
                                             SHANK_T + 0.012),
                               (0.0, -0.12, 1.26)), "steel")
    out += _tag(brushkit.tube("way_seat", SHOULDER_R + 0.010,
                              SHOULDER_R - 0.020, 0.030, 8,
                              (0.0, -0.14, 1.26)), "steel")
    seat = out[-1][0]
    brushkit.spin(seat, "x", 90.0)
    for i in range(channel):
        out += _tag(brushkit.block("relief_%d" % i,
                                   (SHANK_W + 0.055, 0.09, 0.028),
                                   (0.0, -0.12, 1.26 + 0.045 + i * 0.045)),
                    "steel")
    # Batch 028's shared state plate, unchanged. The receiver is an
    # interaction primitive and keeps that family's grammar.
    out += _tag(brushkit.block("plate_recess", (0.25, 0.05, 0.17),
                               (0.0, -0.14, 0.92)), "base")
    cores.append(brushkit.block("plate", (0.20, 0.03, 0.12),
                                (0.0, -0.152, 0.92)))
    return out, cores


def _finish(name, tagged, cores, theme, entry, box, why):
    buckets = {}
    for obj, role in tagged:
        buckets.setdefault(role, []).append(obj)
    painted = []
    specs = [
        ("base", propkit.painted_metal(theme, name + "_base", wear=0.24)),
        # The universal half: bright machined steel, low wear, and the SAME
        # treatment in every theme. If the shank were themed the keyway
        # would have to be too, and then the hole teaches nothing.
        ("steel", propkit.bare_metal(theme, name + "_steel", wear=0.08)),
        # The only themed part.
        ("grip", propkit.painted_metal(theme, name + "_grip", wear=0.30)),
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
            roughness=0.34 if role == "steel" else pal.roughness(theme)))
        painted.append(obj)
    core_obj = common.join(cores, name + "_cores")
    common.assign(core_obj, common.make_signal_material(
        name + "_cores", pal.universal("signal", 0),
        pal.universal("signal", 3), saturation=0.28))
    painted.append(core_obj)

    obj = common.join(painted, name)
    common.set_origin(obj, "floor")
    common.assert_fits(obj, name, box, why)
    record = common.export_glb(obj, "%s/%s.glb" % (OUT, name),
                               "interactable", check_flat=False)
    record.update(entry)
    return record


def main():
    report = {}

    for channel in CHANNELS:
        common.reset_scene()
        name = "zkey_ch%d" % channel
        parts, cores = _key(channel)
        report[name] = _finish(name, _mat() + parts, cores,
                               "concrete_facility", {
            "batch": "031",
            "kind": "local_zone_key",
            "channel": channel,
            "theme": "concrete_facility",
            "code_is": "%d lug(s) on the bit, plus the shoulder notch "
                       "rotated %d step(s)" % (channel, channel),
            "reads_without_colour": True,
            "universal_parts": ["shank", "shoulder", "notch", "bit lugs"],
            "themed_parts": ["grip"],
            "shank_contract_m": {"length": SHANK_L, "width": SHANK_W,
                                 "thickness": SHANK_T,
                                 "shoulder_radius": SHOULDER_R},
            "shares_pickup_mat": True,
            "mates_with": "zkey_receiver_ch%d" % channel,
            "distinct_from": ["Signal Key (AP, campaign-wide, no art yet)",
                              "Epsilon Coin (disc on edge)",
                              "AP Check (pedestal)",
                              "health / ammo / resources"],
            "integration_ready": False,
            "scale_basis": "proposal scale",
        }, KEY_BOX,
           "A floor pickup a player walks over.")

    # The same channel in other themes: evidence that theming the grip does
    # not touch the part the receiver reads.
    for theme in THEMES[1:]:
        common.reset_scene()
        name = "zkey_ch1_%s" % theme
        parts, cores = _key(1)
        report[name] = _finish(name, _mat() + parts, cores, theme, {
            "batch": "031",
            "kind": "local_zone_key",
            "channel": 1,
            "theme": theme,
            "code_is": "1 lug on the bit, plus the shoulder notch rotated "
                       "1 step -- IDENTICAL to zkey_ch1",
            "reads_without_colour": True,
            "universal_parts": ["shank", "shoulder", "notch", "bit lugs"],
            "themed_parts": ["grip"],
            "shares_pickup_mat": True,
            "integration_ready": False,
            "scale_basis": "proposal scale",
        }, KEY_BOX,
           "A floor pickup a player walks over.")

    for channel in CHANNELS:
        common.reset_scene()
        name = "zkey_receiver_ch%d" % channel
        parts, cores = _receiver(channel)
        report[name] = _finish(name, parts, cores, "concrete_facility", {
            "batch": "031",
            "kind": "local_zone_key_receiver",
            "channel": channel,
            "theme": "concrete_facility",
            "keyway_is": "the negative of zkey_ch%d -- same shank, same "
                         "shoulder, %d lug relief(s)" % (channel, channel),
            "carries_028_state_plate": True,
            "mates_with": "zkey_ch%d" % channel,
            "integration_ready": False,
            "scale_basis": "proposal scale",
        }, RECEIVER_BOX,
           "A wall receiver at hand height beside a keyed door.")

    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch031",
                       "keys", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")
    common.log("[batch031] %d assets -> %s" % (len(report), OUT))


if __name__ == "__main__":
    main()
