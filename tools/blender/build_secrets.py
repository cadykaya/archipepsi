"""Batch 029 -- PROPOSAL: the secret clue language.

VISUAL LANGUAGE ONLY. Nothing here decides what a secret contains, how it
opens, what it is worth, or where secrets are placed.

## The audit, read-only, against current Production

`claude/archipepsi-echoes-continuation-b1adno`. This batch has more contract
to work with than any other in the queue.

**`"secret"` is a real socket kind.** `bridge/archipepsi_bridge/schemas/content.py`:

    kind: Literal["doorway", "corridor_end", "affordance", "spawn",
                  "objective", "secret", "vista", "presentation"]

with a `position` and a `yaw`. So a room shell or content entry can already
declare WHERE a secret is, in a validated schema, today.

**Secrets are scored.** `content_value.py`: `SECRET_VALUE = 8`, commented
*"Per authored secret. Optional, findable, and the reason to look around."*

**And there is already an assist.** `secret_ping` is an Echo readout in
`schemas/echo.py`. That matters more than it looks: it means the game has a
mechanism for TELLING a player where a secret is, and therefore the visual
language must be the primary channel with the ping as an Echo-granted
assist -- not the other way round. A cue that only works once you have the
right Echo is not a cue.

**What is missing is narrow.** The socket says where a secret IS. Nothing
says what a secret LOOKS like: there is no cue vocabulary, no difficulty
grading, and no way for a shell to declare "this cue is a learning-tier one"
so a Zone can teach before it tests. Interface requirement 30.

## The one idea this batch rests on

    A SECRET CUE IS NOT A THING. IT IS A DEVIATION FROM A PATTERN.

Which has a hard consequence for how it can be built and shown: **a cue asset
on its own is meaningless.** "One panel sits 4 cm proud" only exists relative
to the eleven panels that do not. So every asset here is a whole wall or floor
section that contains BOTH the repeating baseline AND the single place it
fails -- and the review sheet is therefore a game. If the owner cannot find
the deviation in a panel, that panel's tier is wrong.

This is also why there is no secret COLOUR and no beacon. A colour would be a
label, and a label is the opposite of a thing you notice. The player is meant
to feel clever, and you cannot feel clever about reading a sign.

## Nine cues, and what each one deviates from

| cue | the pattern | the deviation |
|---|---|---|
| construction seam | joints run one way in every bay | in one bay they run the other way |
| displaced panel | panels sit flush | one sits proud |
| service access | blind panels, all identical | one is a real hatch, with real fixings |
| light leak | edges are dark | one edge is not |
| repeated motif | a motif repeats down the run | one repeat is wrong |
| partial sightline | a solid run | one gap you can see a sliver of depth through |
| wear and traffic | floor wear follows the route | a worn path leads somewhere the route does not go |
| broken construction | one construction throughout | one bay was built by someone else |
| visible unreachable space | enclosed volume | you can see a place you cannot get to |

## Three tiers, and they are a MAGNITUDE, not nine more cues

The same deviation, larger or smaller:

| tier | what it is for | this batch's magnitude |
|---|---|---|
| LEARNING | the first one a player meets. It is meant to be found | large, and lit so you cannot miss it |
| MEDIUM | the normal case, once the grammar is known | half |
| SUBTLE | the reward for looking | a quarter, and no help from the light |

Sheet B shows one cue at all three, because "subtle" is not a word that means
anything until you can see it beside the other two.

## Wear is the one cue that cannot be faked with geometry

A worn path is a TEXTURE story -- traffic polishes a floor -- so that cue is
carried by the surface treatment and its geometry is deliberately flat. It is
included precisely because it proves the language is not only "move a block".
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

OUT = "batch029/secrets"

BAYS = 6
BAY_W = 1.20
WALL_H = 3.20
WALL_T = 0.24
BOX = (8.4, 4.8, 4.2)

#: Tier -> how big the deviation is. One number, three cues' worth of
#: difficulty, and the reason tiers are not nine more assets.
TIER_SCALE = {"learning": 1.0, "medium": 0.5, "subtle": 0.25}


def _tag(objs, role):
    return [(o, role) for o in (objs if isinstance(objs, list) else [objs])]


def _bay_x(i):
    return -BAYS * BAY_W / 2.0 + BAY_W / 2.0 + i * BAY_W


def _baseline(odd_bay, cue, k):
    """The repeating run. `odd_bay` is the one that breaks it.

    Everything a cue needs to deviate FROM is built here, so the deviation
    is always a modification of the pattern rather than an addition beside
    it -- which is what makes it findable rather than merely present.
    """
    out = []
    cores = []
    out += _tag(brushkit.block("backing", (BAYS * BAY_W, WALL_T, WALL_H),
                               (0.0, 0.0, WALL_H / 2)), "wall")
    for i in range(BAYS):
        x = _bay_x(i)
        odd = (i == odd_bay)

        # --- the panel itself, and its seating -------------------------
        proud = 0.0
        if cue == "displaced_panel" and odd:
            proud = 0.14 * k
        out += _tag(brushkit.block("panel_%d" % i,
                                   (BAY_W - 0.10, 0.09, WALL_H - 0.44),
                                   (x, -0.11 - proud, WALL_H / 2 - 0.02)),
                    "panel" if not (cue == "broken_construction" and odd)
                    else "other")

        # --- seams: the joint direction of each bay --------------------
        if cue == "construction_seam" and odd:
            # Horizontal, where every other bay is vertical. The deviation
            # is the ORIENTATION, so it survives being small.
            for j in range(3):
                out += _tag(brushkit.block("seam_%d_%d" % (i, j),
                                           (BAY_W - 0.14, 0.03,
                                            0.03 + 0.02 * k),
                                           (x, -0.17,
                                            0.90 + j * 0.72)), "trim")
        else:
            for sx in (-1.0, 1.0):
                out += _tag(brushkit.block("seam_%d_%d" % (i, int(sx)),
                                           (0.04, 0.03, WALL_H - 0.52),
                                           (x + sx * (BAY_W / 2 - 0.06),
                                            -0.17, WALL_H / 2 - 0.02)),
                            "trim")

        # --- fixings: blind everywhere, real on the access bay ---------
        real = cue == "service_access" and odd
        for j, (fx, fz) in enumerate(((-0.34, 0.70), (0.34, 0.70),
                                      (-0.34, 2.42), (0.34, 2.42))):
            out += _tag(brushkit.block("fix_%d_%d" % (i, j),
                                       (0.09, 0.04 + (0.05 * k if real else 0),
                                        0.09),
                                       (x + fx, -0.17, fz)),
                        "trim" if not real else "other")
        if real:
            # A hatch has a HANDLE and a hinge line. Blind panels do not.
            out += _tag(brushkit.block("handle_%d" % i,
                                       (0.22, 0.06 + 0.05 * k, 0.07),
                                       (x + 0.30, -0.19, 1.56)), "other")
            out += _tag(brushkit.block("hinge_%d" % i,
                                       (0.05, 0.05, WALL_H - 0.60),
                                       (x - BAY_W / 2 + 0.10, -0.19,
                                        WALL_H / 2 - 0.02)), "other")

        # --- the repeated motif ----------------------------------------
        if cue == "repeated_motif":
            # Every bay carries a three-mark motif; the odd bay carries a
            # fourth mark. Counting is the least "artistic" cue in the set
            # and the most reliably learnable.
            marks = 4 if odd else 3
            for j in range(marks):
                h = 0.10 + (0.06 * k if (odd and j == 3) else 0.0)
                out += _tag(brushkit.block("mark_%d_%d" % (i, j),
                                           (0.10, 0.03, h),
                                           (x - 0.24 + j * 0.16, -0.17,
                                            2.06)), "trim")

        # --- light leak -------------------------------------------------
        if cue == "light_leak" and odd:
            cores.append(brushkit.block("leak_%d" % i,
                                        (0.025 + 0.05 * k, 0.02,
                                         WALL_H - 0.70),
                                        (x - BAY_W / 2 + 0.05, -0.165,
                                         WALL_H / 2 - 0.02)))

        # --- partial sightline ------------------------------------------
        if cue == "partial_sightline" and odd:
            # A real gap with depth behind it. The panel is split, and the
            # dark you can see is a place, not a shadow.
            out += _tag(brushkit.block("void_back_%d" % i,
                                       (BAY_W - 0.10, 0.05, WALL_H - 0.44),
                                       (x, 0.34, WALL_H / 2 - 0.02)), "other")
            out += _tag(brushkit.block("jamb_%d" % i,
                                       (0.06, 0.30, WALL_H - 0.44),
                                       (x - 0.20 - 0.10 * k, 0.05,
                                        WALL_H / 2 - 0.02)), "trim")

        # --- broken construction ----------------------------------------
        if cue == "broken_construction" and odd:
            # A different coursing, in a different material. Someone else
            # built this bay, and they did not match.
            for j in range(6):
                out += _tag(brushkit.block("course_%d_%d" % (i, j),
                                           (BAY_W - 0.14, 0.06,
                                            0.16 + 0.06 * k),
                                           (x, -0.16, 0.50 + j * 0.42)),
                            "other")

    return out, cores


def _floor(cue, k, odd_bay):
    """The floor in front of the wall. Only two cues need it, but both need
    it to be a real surface rather than a backdrop."""
    out = []
    cores = []
    out += _tag(brushkit.block("floor", (BAYS * BAY_W, 3.60, 0.20),
                               (0.0, -1.90, -0.10)), "wall")
    if cue == "wear_traffic":
        # The worn path. Its GEOMETRY is flat on purpose: traffic polishes
        # a floor, it does not emboss one, so this cue lives in the surface
        # treatment. It is in the set to prove the language is not only
        # "move a block".
        out += _tag(brushkit.block("route", (BAYS * BAY_W, 1.10, 0.012),
                                   (0.0, -2.60, 0.006)), "worn")
        out += _tag(brushkit.block("spur", (0.62 + 0.30 * k, 1.10, 0.012),
                                   (_bay_x(odd_bay), -1.50, 0.006)), "worn")
    if cue == "unreachable_space":
        # A ledge you can see the underside and the top of, and cannot get
        # to. The cue is the VISIBLE PLACE, not a marker on it.
        out += _tag(brushkit.block("ledge", (2.10, 0.90, 0.16),
                                   (_bay_x(odd_bay), 0.30, 2.62)), "other")
        out += _tag(brushkit.block("ledge_rail", (2.10, 0.06, 0.22),
                                   (_bay_x(odd_bay), -0.10, 2.81)), "trim")
        out += _tag(brushkit.block("ledge_back", (2.10, 0.10, 0.90),
                                   (_bay_x(odd_bay), 0.72, 3.15)), "other")
        cores.append(brushkit.block("ledge_hint",
                                    (0.10 + 0.10 * k, 0.06, 0.10),
                                    (_bay_x(odd_bay) + 0.70, -0.10, 2.90)))
    return out, cores


#: cue -> (theme, tier, what the pattern is, what deviates)
CUES = {
    "construction_seam": ("concrete_facility", "medium",
                          "joints run vertically in every bay",
                          "in one bay they run horizontally"),
    "displaced_panel": ("concrete_facility", "learning",
                        "panels sit flush in their frames",
                        "one sits proud of the others"),
    "service_access": ("rusted_industrial", "medium",
                       "blind panels with dummy fixings",
                       "one has real fixings, a handle and a hinge line"),
    "light_leak": ("gothic_stone", "learning",
                   "every panel edge is dark",
                   "one edge is not"),
    "repeated_motif": ("temple_ruin", "subtle",
                       "a three-mark motif repeats down the run",
                       "one bay carries a fourth mark"),
    "partial_sightline": ("neon_transit", "medium",
                          "a solid run of panels",
                          "one gap with real depth behind it"),
    "wear_traffic": ("concrete_facility", "subtle",
                     "floor wear follows the route",
                     "a worn spur leaves the route and stops at a wall"),
    "broken_construction": ("rusted_industrial", "learning",
                            "one coursing and one material throughout",
                            "one bay was built by someone else"),
    "unreachable_space": ("void_glitch", "subtle",
                          "an enclosed room",
                          "a ledge you can see and cannot reach"),
}


def _finish(name, tagged, cores, theme, entry):
    buckets = {}
    for obj, role in tagged:
        buckets.setdefault(role, []).append(obj)
    painted = []
    specs = [
        ("wall", propkit.facility_host(theme, name + "_wall")),
        ("panel", propkit.painted_metal(theme, name + "_panel", wear=0.20)),
        ("trim", propkit.bare_metal(theme, name + "_trim", wear=0.24)),
        # The bay that is not like the others: a different treatment, so
        # "someone else built this" is a material fact and not a tint.
        ("other", propkit.painted_metal(theme, name + "_other", wear=0.46)),
        # Polished by traffic: lower wear, lower roughness. The one cue
        # that is a surface story rather than a geometric one.
        ("worn", propkit.bare_metal(theme, name + "_worn", wear=0.05)),
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
            roughness=0.34 if role == "worn" else pal.roughness(theme)))
        painted.append(obj)

    if cores:
        core_obj = common.join(cores, name + "_cores")
        # NOT a secret colour. A leak is light from the other side and an
        # unreachable ledge borrows whatever lights it; both take the
        # THEME's own light hue, so neither becomes a label.
        common.assign(core_obj, common.make_signal_material(
            name + "_cores", pal.theme(theme, "base", 1),
            pal.light(theme)[0], saturation=0.34))
        painted.append(core_obj)

    obj = common.join(painted, name)
    common.set_origin(obj, "floor")
    common.assert_fits(obj, name, BOX,
                       "A wall section with the pattern and its one "
                       "deviation. It is a room's wall, not a prop.")
    record = common.export_glb(obj, "%s/%s.glb" % (OUT, name), "room",
                               check_flat=False)
    record.update(entry)
    return record


def _build(cue, tier, theme, name):
    common.reset_scene()
    k = TIER_SCALE[tier]
    # Bay 4 of 6, not bay 3. At the game's own 90 deg FOV a raking view
    # down a 7.2 m wall shrinks the middle bays hard, so a deviation
    # placed mid-run was being judged at a size no player would ever
    # judge it at. A player walks PAST every bay at close range; the
    # fair test is the deviation at the near end.
    odd = 4
    wall, wall_cores = _baseline(odd, cue, k)
    floor, floor_cores = _floor(cue, k, odd)
    pattern, deviation = CUES[cue][2], CUES[cue][3]
    return _finish(name, wall + floor, wall_cores + floor_cores, theme, {
        "batch": "029",
        "kind": "secret_cue",
        "cue": cue,
        "tier": tier,
        "tier_scale": k,
        "theme": theme,
        "the_pattern": pattern,
        "the_deviation": deviation,
        "deviant_bay": odd,
        "bays": BAYS,
        "uses_secret_colour": False,
        "uses_hud_beacon": False,
        "why_no_colour": "a colour is a label, and a label is the opposite "
                         "of a thing you notice",
        "runtime_socket_exists": True,
        "runtime_socket": "content.py Socket kind Literal includes 'secret' "
                          "with position and yaw; SECRET_VALUE = 8",
        "runtime_gap": "the socket says WHERE. Nothing says what a cue "
                       "looks like, and there is no tier a shell can "
                       "declare so a Zone teaches before it tests (req 30)",
        "note_secret_ping": "an Echo readout `secret_ping` already exists, "
                            "so this language must be the PRIMARY channel "
                            "and the ping an assist -- a cue that only "
                            "works with the right Echo is not a cue",
        "integration_ready": False,
        "scale_basis": "proposal scale",
    })


def main():
    report = {}
    for cue, (theme, tier, _p, _d) in CUES.items():
        report["secret_%s" % cue] = _build(cue, tier, theme,
                                           "secret_%s" % cue)
    # One cue at all three tiers, because "subtle" means nothing until you
    # can see it beside the other two.
    for tier in ("learning", "medium", "subtle"):
        name = "secret_tier_%s" % tier
        report[name] = _build("displaced_panel", tier,
                              "concrete_facility", name)

    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch029",
                       "secrets", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")
    common.log("[batch029] %d assets -> %s" % (len(report), OUT))


if __name__ == "__main__":
    main()
