"""Batch 027 -- PROPOSAL: pickups, loot and resource readability.

VISUAL PROPOSALS ONLY. No resource mechanic and no denomination is decided
here: not what health restores, not what a resource is spent on, not how much
of anything a pickup gives.

## The audit, read-only, against current Production

`claude/archipepsi-echoes-continuation-b1adno`. This one changes the shape of
the batch, so it comes first.

**Three of the five requested pickups are backed by a real item. Two are not
backed by anything at all.**

| requested | what exists in Production |
|---|---|
| Epsilon Coin | **REAL.** `ITEM_NAME_EPSILON_COIN`, `EPSILON_COIN_COUNT = 10` |
| special resource | **REAL.** `ITEM_NAME_EPSILON_STATIC`, `EPSILON_STATIC_COUNT = 18` |
| secret cache / loot container | **PARTLY.** `LocalReward` exists, but see below |
| health | **NOTHING.** `LOW_HEALTH_FRACTION = 0.33` says the player HAS health. No health item, no health pickup, no entity |
| generic combat resource / ammo | **NOTHING.** No item, no constant, no entity, no mention |

And `godot/scripts/gameplay/local_reward.gd` carries a CLOSED catalog:

    const KINDS := ["epsilon_note", "challenge_marker", "cosmetic_grant",
            "hub_decoration", "lab_fixture", "flavor_log"]

with the reason stated in its own comment: *"the client must not be able to
invent a seventh kind, and a wire-level rejection after the pickup has
already vanished is a worse failure than never offering it."*

So a loot CONTAINER is not a seventh kind art may add. None of the six is a
container, and the one place that could hold one is explicitly sealed.

**This is a design question before it is an art question**, and it is
recorded as interface requirement 28 rather than answered here. All five are
still built, because the brief asked for five -- but each records in its
manifest whether a real item backs it.

## Colour discipline: what is licensed, and what is not

`art_palette.json` says what each family means, and a pickup does not get to
borrow one because it would look good:

| family | may this batch use it? |
|---|---|
| `glitch` #ff00e6 | **YES, for Epsilon Static only.** The family is literally defined as "Epsilon Static and the missing-world checker" |
| `identity` #57ff1f | **as a MARK, not a material.** The coin is Epsilon's currency, so it carries Epsilon's mark. It is not MADE of Epsilon green -- that family is "its presence, its terminal, its voice surfaces and nothing else" |
| `send` #ffd45c | **NO.** It means "this leaves for the multiworld" -- a transmission beam and a destination ring. A coin is not a beam. The coin is warm MACHINED METAL, which is a value and a specular story, not an emissive one |
| `signal` #39d7c8 | **NO.** "The only colour an interactable PROMPT, rim or reveal face is allowed to be." A pickup is walked over, not operated |
| `hazard` #e8541f | **NO.** Never decorative, in any theme, for any reason |

Which leaves health and ammo with **no hue at all**, and that is correct
rather than a shortfall. They are told apart by silhouette, like every pickup
in every shooter of the period, and the batch's real test is the silhouette
sheet rather than the lit one.

## The shared grammar: a mat, and then a shape

Every pickup sits on the same small hexagonal floor mat. Learned once, it
says *this is a thing you can take* -- so the object above it is free to be
entirely about WHICH thing, and never has to also argue that it is a pickup.

    mat = "you can take this"          (identical on all five)
    object = "this is what it is"      (shares nothing between them)

The five silhouettes are deliberately unrelated: a disc on edge, a yoked
ampoule, a squat ribbed block, an irregular slug, and a closed box with a
lid. At 12 m in a dark room those are five different shapes before any
surface resolves.

## Why the Coin is built the way it is

Ten exist in an entire campaign and they fuel the Forge. So it cannot look
like small change, and it cannot get there by being brighter -- brightness is
how the Check, Epsilon and hazard already speak.

It gets there by being the only object in the game presented like it is worth
something: a thick milled disc, standing ON EDGE in a cradle rather than
lying flat, at the scale of a hand rather than a fingertip, with a milled rim
that catches a highlight all the way round. Value and presentation, not
saturation.
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
OUT = "batch027/pickups"
BOX = (1.4, 1.4, 1.4)

MAT_R = 0.30
MAT_H = 0.05


def _tag(objs, role):
    return [(o, role) for o in (objs if isinstance(objs, list) else [objs])]


def _mat():
    """The shared floor mat. Identical on all five, so the object above it
    never has to argue that it is a pickup."""
    out = []
    out += _tag(brushkit.prism("mat", MAT_R, MAT_H, 8, (0.0, 0.0, MAT_H / 2)),
                "base")
    out += _tag(brushkit.tube("mat_rim", MAT_R + 0.02, MAT_R - 0.05, 0.03, 8,
                              (0.0, 0.0, MAT_H + 0.015)), "base")
    return out


def _coin():
    """A thick milled disc, ON EDGE in a cradle. Ten exist in a campaign."""
    out, cores = [], []
    # The cradle: two uprights that hold it up like it matters.
    for sy in (-1.0, 1.0):
        out += _tag(brushkit.wedge("cradle_%d" % int(sy), (0.10, 0.13, 0.16),
                                   (0.0, sy * 0.11, 0.13), axis="y"), "base")
    # The disc: standing vertical, so the milled rim reads all the way round.
    out += _tag(brushkit.prism("disc", 0.19, 0.045, 8, (0.0, 0.0, 0.30),
                               organic=False), "precious")
    disc = out[-1][0]
    brushkit.spin(disc, "x", 90.0)
    # The milled rim, as real geometry: this is where the highlight lives.
    out += _tag(brushkit.tube("mill", 0.195, 0.165, 0.05, 8,
                              (0.0, 0.0, 0.30)), "precious")
    mill = out[-1][0]
    brushkit.spin(mill, "x", 90.0)
    # Epsilon's MARK -- not Epsilon's material. Whose coin it is, stamped
    # on, rather than a coin made out of the identity family.
    cores.append(brushkit.block("mark", (0.055, 0.055, 0.012),
                                (0.0, 0.0, 0.30)))
    return out, cores, 0.26


def _health():
    """A stubby ampoule in a steel yoke. No hue is spent on this."""
    out, cores = [], []
    out += _tag(brushkit.block("yoke_base", (0.24, 0.16, 0.05),
                               (0.0, 0.0, 0.08)), "base")
    for sx in (-1.0, 1.0):
        out += _tag(brushkit.block("yoke_%d" % int(sx), (0.04, 0.13, 0.22),
                                   (sx * 0.11, 0.0, 0.19)), "base")
    out += _tag(brushkit.prism("ampoule", 0.09, 0.24, 8, (0.0, 0.0, 0.22),
                               top_radius=0.055), "glass")
    out += _tag(brushkit.prism("collar", 0.055, 0.05, 8, (0.0, 0.0, 0.36)),
                "base")
    return out, cores, 0.0


def _resource():
    """A WIDE, LOW ribbed cell block: the common one, and the plainest.

    Deliberately pushed wide and flat. The silhouette sheet caught this and
    `pickup_special` reading as the same object -- two blocks of similar
    proportion on identical mats -- so the two are now separated on BOTH
    axes: this one is broader than it is tall, and the slug is the reverse.
    """
    out, cores = [], []
    out += _tag(brushkit.block("cell", (0.42, 0.22, 0.13),
                               (0.0, 0.0, 0.115)), "plain")
    for i in range(5):
        out += _tag(brushkit.block("rib_%d" % i, (0.035, 0.24, 0.15),
                                   (-0.16 + i * 0.08, 0.0, 0.115)), "base")
    out += _tag(brushkit.block("cap", (0.44, 0.07, 0.04),
                               (0.0, 0.0, 0.20)), "base")
    return out, cores, 0.0


def _special():
    """Epsilon Static: an irregular slug. `glitch` is licensed for exactly
    this and nothing else in the batch.

    TALL, NARROW and visibly ASYMMETRIC. The first pass was a tidy tapered
    block that read as the same object as the ribbed cell in silhouette --
    which is doubly wrong, because this is the corrupted one. Static should
    be the only pickup whose outline is not orderly.
    """
    out, cores = [], []
    out += _tag(brushkit.prism("slug_a", 0.095, 0.26, 8, (0.0, 0.0, 0.19),
                               rotation_z=14.0, top_radius=0.055,
                               organic=True), "static")
    out += _tag(brushkit.prism("slug_b", 0.062, 0.19, 8,
                               (0.075, -0.035, 0.38), rotation_z=-33.0,
                               top_radius=0.030, organic=True), "static")
    # A third lobe, off to the other side. Two lobes still read as a taper;
    # three at unrelated angles read as something that grew wrong.
    out += _tag(brushkit.prism("slug_c", 0.048, 0.14, 8,
                               (-0.085, 0.04, 0.30), rotation_z=52.0,
                               top_radius=0.024, organic=True), "static")
    cores.append(brushkit.block("static_core", (0.045, 0.045, 0.16),
                                (0.0, 0.0, 0.20)))
    return out, cores, 0.30


def _cache():
    """A closed container. Bigger than the others, and it reads SHUT."""
    out, cores = [], []
    out += _tag(brushkit.block("body", (0.62, 0.42, 0.34),
                               (0.0, 0.0, 0.22)), "plain")
    out += _tag(brushkit.wedge("lid", (0.64, 0.44, 0.16),
                               (0.0, 0.0, 0.47), axis="y"), "base")
    # The seam is the whole statement: it is CLOSED, and it opens there.
    out += _tag(brushkit.block("seam", (0.66, 0.45, 0.02),
                               (0.0, 0.0, 0.39)), "base")
    for sx in (-1.0, 1.0):
        out += _tag(brushkit.block("latch_%d" % int(sx), (0.06, 0.05, 0.11),
                                   (sx * 0.22, -0.22, 0.38)), "base")
    out += _tag(brushkit.block("hasp", (0.09, 0.06, 0.09),
                               (0.0, -0.23, 0.36)), "base")
    return out, cores, 0.0


PICKUPS = {
    # name             builder    backed by a real Production item?
    "pickup_coin":     (_coin, "Epsilon Coin", "ITEM_NAME_EPSILON_COIN, "
                        "EPSILON_COIN_COUNT = 10", True,
                        "a thick milled disc, on edge in a cradle"),
    "pickup_health":   (_health, "health", None, False,
                        "an ampoule in a steel yoke"),
    "pickup_resource": (_resource, "combat resource / ammo", None, False,
                        "a wide, low ribbed cell block"),
    "pickup_special":  (_special, "Epsilon Static", "ITEM_NAME_EPSILON_STATIC, "
                        "EPSILON_STATIC_COUNT = 18", True,
                        "a tall asymmetric three-lobed slug"),
    "pickup_cache":    (_cache, "secret cache / loot container",
                        "LocalReward exists, but its KINDS catalog is CLOSED "
                        "and holds no container kind", False,
                        "a closed box with a lid seam and a hasp"),
}


def _finish(name, tagged, cores, saturation, entry):
    buckets = {}
    for obj, role in tagged:
        buckets.setdefault(role, []).append(obj)

    painted = []
    specs = [
        ("base", propkit.painted_metal(THEME, name + "_base", wear=0.22),
         None),
        # The coin's own treatment: bright machined metal, low wear, low
        # roughness. Its desirability is a SPECULAR story, not an emissive
        # one -- brightness is how the Check, Epsilon and hazard speak.
        ("precious", propkit.bare_metal(THEME, name + "_prec", wear=0.06),
         0.28),
        ("glass", propkit.bare_metal(THEME, name + "_glass", wear=0.04),
         0.42),
        ("plain", propkit.painted_metal(THEME, name + "_plain", wear=0.36),
         None),
        ("static", propkit.alien_shell(THEME, name + "_static"), 0.55),
    ]
    for role, canvas, rough in specs:
        parts = buckets.get(role)
        if not parts:
            continue
        obj = common.join(parts, "%s_%s" % (name, role))
        common.uv_project_world(obj, propkit.PROP_DENSITY, propkit.PROP_SIZE)
        common.assign(obj, common.make_textured_material(
            "%s_%s" % (name, role),
            canvas.to_blender("%s_%s_t" % (name, role)),
            roughness=pal.roughness(THEME) if rough is None else rough))
        painted.append(obj)

    if cores:
        core_obj = common.join(cores, name + "_cores")
        family = "glitch" if name == "pickup_special" else "identity"
        common.assign(core_obj, common.make_signal_material(
            name + "_cores", pal.universal(family, 0),
            pal.universal(family, 3), saturation=saturation))
        painted.append(core_obj)

    obj = common.join(painted, name)
    common.set_origin(obj, "floor")
    common.assert_fits(obj, name, BOX,
                       "A floor pickup a player walks over; it may not "
                       "become an obstacle.")
    record = common.export_glb(obj, "%s/%s.glb" % (OUT, name), "prop",
                               check_flat=False)
    record.update(entry)
    return record


def main():
    report = {}
    for name, (builder, label, backing, real, silhouette) in PICKUPS.items():
        common.reset_scene()
        parts, cores, saturation = builder()
        report[name] = _finish(name, _mat() + parts, cores, saturation, {
            "batch": "027",
            "kind": "pickup",
            "represents": label,
            "silhouette": silhouette,
            "backed_by_production_item": real,
            "production_backing": backing,
            "palette_family": ("glitch" if name == "pickup_special"
                               else "identity mark only" if name == "pickup_coin"
                               else "none -- silhouette and value only"),
            "shares_mat_grammar": True,
            "integration_ready": False,
            "scale_basis": "proposal scale",
        })

    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch027",
                       "pickups", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")
    common.log("[batch027] %d assets -> %s" % (len(report), OUT))


if __name__ == "__main__":
    main()
