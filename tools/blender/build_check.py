"""Batch 005 -- the Check, produced, and its four states.

    .tools/blender/blender -b --python tools/blender/build_check.py

## Why this is Tier 2's first batch

`ART_FRONTIER.md` opens Tier 2 with core interactables, and the Check is
the first row of `ASSET_INVENTORY.md` section 2 for the reason
`AUTHORED_CONTENT.md` gives: thirty of them across a campaign makes it the
single most repeated moment in the game. Batch 001 concepted three
silhouettes and the owner selected **A**, revised; Style Lock passed it.
What did not exist until now is the *produced* Check -- the approved
silhouette split along the boundaries the engine actually uses, plus the
four states `reward.gd` names.

## The split is the engine's, not a composition choice

`reward.gd` builds the Check out of five children and then moves and
repaints three of them every frame or every snapshot:

| Node | What the engine does to it |
| --- | --- |
| pedestal | static |
| `ItemVisual` | spins, bobs, and is repainted per STATE |
| `DestinationRing` | repainted per RECIPIENT WORLD |
| `StateLabel` | text, engineering's |
| `SendBeam` | spawned, scaled and faded on confirm |

Batch 001 exported one joined `.glb` because a review model only has to
stand still. A production Check cannot: a single mesh cannot be spun,
tinted per destination and tweened independently. So this batch exports
**eight files along those node boundaries**, and every dimension in them is
read out of `reward.gd` rather than chosen.

## Two kinds of variation, and why only one of them can be authored

The Check answers two questions at once, and `reward.gd` is explicit that
they are separate channels. They are also separate *kinds* of question:

* **State** is a CLOSED set of four -- locked, available, sending,
  confirmed. A closed set can be authored, so it is: four meshes, swapped.
  That keeps the authored surface in every state, which a runtime
  `material_override` would destroy, and it lets state differ in FORM as
  well as hue -- which matters for a player who cannot rely on hue.
* **Destination** is an OPEN set derived from the multiworld:
  `ThemeMaterials.color_for_game(game)` can return a colour for any game in
  the room. An open set cannot be authored. So the ring and the beam stay
  single-material and flat-overridable, and their FORM has to carry the
  read on its own.

If engineering keeps `material_override` on the item instead of swapping
meshes, nothing here breaks -- `check_item_available` is a perfectly good
single mesh to override. The batch is not blocked on the decision; it just
delivers more when the decision goes the other way.

## What reads at 39.6 m, and what does not

`derive_budgets.py` section 7: the largest arena diagonal is 39.6 m and the
Check is **35 px** at that range. That is the number the silhouette was
approved against. It also decides which channel can carry state:

| Part | Measured | Pixels at 39.6 m |
| --- | --- | --- |
| the mast | 2.22 m tall | 35 |
| the destination ring | 1.88 m across the flats | 30 |
| the item, in its cage | 0.28 m | 4 |

So **the ring is the distance channel and the item is the near one.**
`reward.gd` already uses the ring that way -- 0.35 emission energy when
locked, 1.5 otherwise -- so locked-versus-not reads across the room and the
other three states are a walk-up read. That division is the engine's, not
this batch's, and the review sheet asks the owner whether it is enough.

## The one paint change from the approved concept, stated plainly

The concept's base collar wore the `send` family, because in a single
joined review model it *was* the destination ring. It is not any more:
`reward.gd`'s `DestinationRing` has outer radius 1.02 -- **1.88 m across
the flats of the octagon it becomes, 2.04 across the points, so very close
to twice the collar's 0.96 / 1.04** -- and it lives on the floor, not on
the plinth. So the collar is repainted structural and the `send` channel moves
to the ring at the engine's own radii, where the engine puts it.

Silhouette, proportion and the lit band are untouched. This is the only
difference between the approved model and the produced one.
"""

from __future__ import annotations

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import brushkit  # noqa: E402
import common  # noqa: E402
import propkit  # noqa: E402
import palette as pal  # noqa: E402
from build_concept_check import concept_a_pedestal  # noqa: E402

THEME = "concrete_facility"
OUT = "batch005/check"

#: reward.gd: BoxShape3D 1.4 x 2.6 x 1.4, centred at y 1.3. Blender is Z-up.
CHECK_BOX = (1.4, 1.4, 2.6)

# --- the cage the item lives in, measured off the approved mast ---------
# concept_a_pedestal builds `cpa_hood` 0.64 x 0.64 x 0.10 at z 1.68, four
# cage uprights 0.06 square at (+/-0.20, +/-0.20, 1.90) spanning 0.44, and
# `cpa_cap` at z 2.16 spanning 0.12. The interior those leave is:
CAGE_FLOOR = 1.73          # top of the hood
CAGE_CEIL = 2.10           # bottom of the cap
CAGE_CLEAR_R = 0.15        # uprights' inner faces are at 0.17; 20 mm clear
ITEM_MID = 1.90            # where the approved concept put its core

#: reward.gd: TorusMesh inner_radius 0.86, outer_radius 1.02, at y 0.05.
RING_INNER = 0.86
RING_OUTER = 1.02
RING_Z = 0.05

#: reward.gd: CylinderMesh top 0.18, bottom 0.40, height 40.0, at y 20.0.
BEAM_TOP_R = 0.18
BEAM_BOTTOM_R = 0.40
BEAM_H = 40.0


# ----------------------------------------------------------------------
# the mast
# ----------------------------------------------------------------------

def build_mast():
    """The approved A-R silhouette, minus the two nodes the engine drives.

    The geometry is IMPORTED from `build_concept_check` rather than copied.
    A copy is a second source for a shape the owner has already passed, and
    the two would drift the first time either was touched.
    """
    before = set(bpy.data.objects.keys())
    body, face, core, collar = concept_a_pedestal()
    # The core is now `check_item_*`, four separate meshes. Nothing here.
    bpy.data.objects.remove(core, do_unlink=True)
    # `concept_a_pedestal` builds four cage uprights on a circle, decides
    # they read as a crown rather than a cage, and drops them from its own
    # list with `body = body[:-4]`. The OBJECTS survive that slice. They
    # never reached the concept's export because it exports by selection,
    # but leaving four stray meshes in the scene between eight exports is
    # how a stray ends up joined into the wrong asset. Take them out.
    keep = set(o.name for o in body + [face, collar])
    for name in sorted(set(bpy.data.objects.keys()) - before - keep):
        bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True)

    shell = common.join(body + [collar], "check_mast_shell")
    common.uv_project_world(shell, propkit.HERO_DENSITY, propkit.HERO_SIZE)
    common.assign(shell, common.make_textured_material(
        "check_mast_shell",
        propkit.hero_shell(THEME, "check_mast", "signal",
                           label="chk").to_blender("check_mast_shell_tex"),
        roughness=pal.roughness(THEME)))

    common.uv_project_world(face, propkit.HERO_DENSITY, propkit.HERO_SIZE)
    common.assign(face, common.make_textured_material(
        "check_mast_face",
        propkit.hero_face(THEME, "check_mast", "signal",
                          "use").to_blender("check_mast_face_tex"),
        roughness=0.5))

    obj = common.join([shell, face], "check_mast")
    common.set_origin(obj, "floor")
    common.assert_fits(obj, "check_mast", CHECK_BOX,
                       "reward.gd gives the Check a 1.4 x 2.6 x 1.4 m "
                       "collision box.")
    return common.export_glb(obj, "%s/check_mast.glb" % OUT, "interactable",
                             check_flat=False)


# ----------------------------------------------------------------------
# the four states
# ----------------------------------------------------------------------
#
# Every state is built from the same two pieces so the family is obvious:
#
#   the CRADLE   an octagonal socket plate on the cage floor. Present in all
#                four -- it is the fixture, not the item, and a plate that
#                came and went would be noise between states.
#   the ITEM     what sits in the cradle, or does not.
#
# So the four silhouettes are: empty cradle / bright spindle / spindle
# stretched to the cap / small dark husk. That is a form difference, not
# only a hue one, which is the whole reason to author them as meshes.

CRADLE_R = 0.14
CRADLE_H = 0.04
CRADLE_Z = CAGE_FLOOR + CRADLE_H / 2.0     # 1.750, sitting on the hood


def _cradle(state):
    return brushkit.prism("chk_%s_cradle" % state, CRADLE_R, CRADLE_H, 8,
                          (0.0, 0.0, CRADLE_Z), top_radius=CRADLE_R * 0.86,
                          asset_name="check_item_%s" % state)


def _spindle(state, radius, height, mid, waist=0.46):
    """Two frusta back to back: the approved core, made rotationally safe.

    The concept's core was a 0.26 m block spun 45 degrees -- a diamond
    column. A diamond that SPINS sweeps its own diagonal, and 0.26 m of
    diagonal is 0.37 m, which does not fit between cage uprights 0.34 m
    apart. An eight-sided double frustum keeps the diamond read from every
    angle and sweeps a circle, so `_process`'s spin costs nothing.
    """
    half = height / 2.0
    lower = brushkit.prism("chk_%s_lo" % state, radius * waist, half, 8,
                           (0.0, 0.0, mid - half / 2.0), top_radius=radius,
                           asset_name="check_item_%s" % state)
    upper = brushkit.prism("chk_%s_hi" % state, radius, half, 8,
                           (0.0, 0.0, mid + half / 2.0),
                           top_radius=radius * waist,
                           asset_name="check_item_%s" % state)
    return [lower, upper]


def state_locked():
    """Nothing is here yet. An empty cradle in an empty cage.

    NOT an emitter, and that is measured rather than assumed. Run through
    `make_signal_material` at saturation 0.22 the cradle rendered
    (114, 120, 131) against a mast head of (68, 82, 101) -- the deadest
    thing on the object came out the BRIGHTEST, because that function's job
    is to make a glow survive being lit and it does that job at every
    saturation. `dead` states get albedo and nothing else.

    The "a Check must be visible at range" worry is answered by the mast,
    not the item: `hero_shell` paints a full-width `signal` band that is lit
    in all four states. The band says *there is a Check here*; the item says
    *which state*. Those were always two questions.
    """
    return [_cradle("locked")], "dead", 0, None, 0.0


def state_available():
    """Take it. The largest lit area of the four, and the only bright one.

    `signal` teal, because the palette says interactables wear signal and
    this is the one state where the Check IS an interactable. Full
    saturation: nothing else on the object competes with it.
    """
    parts = [_cradle("available")]
    parts += _spindle("available", CAGE_CLEAR_R, 0.22, ITEM_MID)
    # signal[2] `#39d7c8`, NOT signal[3]. The concept emitted step 3 and got
    # away with it on a core the size of a fist inside a cage; at the size
    # the state channel needs, `#85fff3` is a mint so pale -- R 0.52 against
    # G 1.00, B 0.95 -- that emitting it renders a white hexagon with no
    # teal left in it. The palette's brightest step is the brightest place
    # a TEXTURE may go, not the right place for an EMITTER to start from.
    return parts, "signal", 0, 2, 0.92


def state_sending():
    """It is leaving. The spindle has stretched up and out of its cradle.

    `send` amber -- the family that means "this goes to the multiworld",
    the same one the destination ring and the beam wear. The column stops
    at 2.04, 60 mm under the cap, so a bob the engine has not yet removed
    does not punch through the top of the cage.
    """
    parts = [_cradle("sending")]
    parts += _spindle("sending", CAGE_CLEAR_R * 0.78, 0.14, 1.855)
    column_top = 2.04
    column_base = 1.90
    parts.append(brushkit.prism(
        "chk_sending_column", 0.055, column_top - column_base, 8,
        (0.0, 0.0, (column_top + column_base) / 2.0), top_radius=0.028,
        asset_name="check_item_sending"))
    return parts, "send", 0, 3, 0.92


#: How far the collapsed husk spreads over the hood. The mast's hood is
#: 0.64 m across, so 0.88 overhangs it by 120 mm a side -- and that is the
#: number the whole revision turns on: it takes the HEAD's silhouette from
#: 10 px to 14 px at 39.6 m. Inside the cage there are only 5 px of height
#: to work with; outside it there is width, and width survives distance.
POOL_R = 0.42


def state_confirmed():
    """It was here and it is spent. The husk has collapsed out of the cage.

    ## 005-R: why this state got wider

    The owner's Batch 005 verdict passed the four-state vocabulary and
    required one targeted fix. The 39.6 m sheet had found that **locked and
    confirmed do not separate at distance** -- both are `dead`, both are a
    small dark thing in a cage -- and the instruction ruled out the easy
    answers:

    > Do NOT solve this solely by leaning on destination-ring brightness.
    > The MAST / HEAD ITSELF needs one additional non-hue state cue.
    > ... floor rings can be partially occluded ... brightness is weaker
    > than shape ... state recognition should not require colour
    > perception.

    The first attempt put a shutter inside the cage, and measuring it is
    what killed it: at 39.6 m the cage interior is **5 px tall**, so every
    cue that lives inside it is fighting for five pixels. Filling it moved
    the cage's background fraction from 58% to 48% -- real, and not enough
    to bet a state read on.

    So the cue moved OUTSIDE the cage, which is the owner's fourth option:

    > the spent husk occupies a deliberately larger / different
    > negative-space pattern

    The husk has slumped out of its cradle and pooled across the hood,
    0.88 m against the head's 0.64. The head's silhouette goes from 10 px
    wide to 14, and a 40% width change is legible where five pixels of
    interior are not. What is left inside the cage is a stub.

    It also says the right thing. Locked is a Check that has not happened
    yet: an empty cradle in an open cage. Confirmed is one that has: the
    thing in it has come apart and run out over the housing. Same family,
    same mast, same word the owner approved -- *a spent dark husk* -- and
    now unmistakably spent.

    Every part is rotationally symmetric, which is not decoration either:
    `reward.gd` spins `ItemVisual` only while locked or available and never
    resets the angle, so a confirmed item with a front would be left facing
    wherever the spin happened to stop.
    """
    parts = [_cradle("confirmed")]
    # A mass that has swelled to fill the cage and overflow it. Each stage
    # is wider than the uprights' nearest corner at 0.240, so the cage is
    # SWALLOWED rather than filled -- which is the point: locked is an open
    # lantern you can see daylight through, confirmed is a solid lump.
    for name, r_lo, r_hi, z0, z1 in (
            ("pool", POOL_R, POOL_R * 0.86, 1.730, 1.880),
            ("body", POOL_R * 0.86, POOL_R * 0.70, 1.880, 2.020),
            ("crown", POOL_R * 0.70, POOL_R * 0.42, 2.020, 2.080)):
        parts.append(brushkit.prism(
            "chk_confirmed_%s" % name, r_lo, z1 - z0, 8,
            (0.0, 0.0, (z0 + z1) / 2.0), top_radius=r_hi,
            asset_name="check_item_confirmed"))
    return parts, "dead", 0, None, 0.0


STATES = [
    ("locked", state_locked),
    ("available", state_available),
    ("sending", state_sending),
    ("confirmed", state_confirmed),
]


def build_state(state, builder):
    parts, family, dark, bright, saturation = builder()
    obj = common.join(parts, "check_item_%s" % state)
    name = "check_item_%s" % state
    if bright is None:
        # A dead state is dead metal, not a dim lamp. See `state_locked`.
        material = common.make_material(name, pal.universal(family, dark),
                                        roughness=0.6)
    else:
        material = common.make_signal_material(
            name, pal.universal(family, dark), pal.universal(family, bright),
            saturation=saturation)
    common.assign(obj, material)
    # module_floor, not floor: the item's HEIGHT inside the cage is what it
    # is. Re-basing it to its own lowest point is what would drop it on the
    # ground -- the same failure that put a pipe run on the floor in Batch
    # 001. Its origin stays at the mast's, so the engine adds it at zero.
    common.set_origin(obj, "module_floor")
    common.assert_fits(obj, "check_item_%s" % state, CHECK_BOX,
                       "the item lives inside the Check's own collision box.")
    # Height alone would not catch this: the item is authored at ABSOLUTE
    # height in the mast's own space, so what matters is where its top and
    # bottom actually land against the hood and the cap.
    zs = [(obj.matrix_world @ Vector(c)).z for c in obj.bound_box]
    if min(zs) < CAGE_FLOOR - 0.001 or max(zs) > CAGE_CEIL + 0.001:
        raise AssertionError(
            "check_item_%s spans z %.3f..%.3f and the mast's cage is "
            "%.3f..%.3f. An item outside its cage clips the hood or the cap."
            % (state, min(zs), max(zs), CAGE_FLOOR, CAGE_CEIL))
    return common.export_glb(obj, "%s/check_item_%s.glb" % (OUT, state),
                             "interactable", anchor="module_floor")


# ----------------------------------------------------------------------
# destination ring and send beam -- the two the engine tints
# ----------------------------------------------------------------------

def build_ring():
    """`DestinationRing`, at reward.gd's own radii.

    Eight sides, because `art_budgets.json` caps radial segments at 8 below
    a 1.5 m radius and this is 1.02. A smooth torus at this size would be
    the single most modern-looking object in the game.

    It measures 1.88 m across the flats and 2.04 across the points, and
    the Check's collider is 1.4, so the ring OVERHANGS its own collision
    box by 240 mm a side and 320 mm at the corners. That is reward.gd's
    radius, not a choice made here, and it is a placement constraint rather
    than a bug -- see interface requirement 11.
    """
    # EIGHT PADS AND A CURB, not a solid band. The first version was the
    # plain octagonal tube, and lit at the same saturation as the item it
    # came out the single brightest object in the frame -- a gold mat with
    # a Check standing on it. `hero_shell` states the rule it broke: if two
    # things compete for the eye at 35 px, neither wins, and the ring is
    # the DESTINATION channel, not the state one.
    #
    # Turning it down is only half a fix, because the engine overrides this
    # material per recipient world and can turn it back up. The half that
    # survives an override is FORM: eight pads with the floor showing
    # between them read as a marker ring at any tint, where a solid band
    # reads as a slab at most of them.
    mid = (RING_OUTER + RING_INNER) / 2.0
    apothem = mid * math.cos(math.pi / 8.0)
    edge = 2.0 * mid * math.sin(math.pi / 8.0)
    parts = []
    for i in range(8):
        angle = i * math.pi / 4.0
        parts.append(brushkit.block(
            "chk_ring_pad_%d" % i,
            (edge * 0.74, RING_OUTER - RING_INNER, 0.12),
            (apothem * math.cos(angle), apothem * math.sin(angle), RING_Z),
            rotation_z=math.degrees(angle) + 90.0))
    # A low continuous curb on the inside, so the eight pads are one object
    # rather than eight tiles somebody dropped.
    parts.append(brushkit.tube("chk_ring_curb", RING_INNER + 0.05,
                               RING_INNER, 0.06, 8,
                               (0.0, 0.0, RING_Z - 0.02)))
    obj = common.join(parts, "check_destination_ring")
    # ONE material, and a flat one: the engine overrides this per recipient
    # world and an override replaces every surface. Anything painted here
    # would survive exactly until the first snapshot.
    # Half the item's saturation: reward.gd runs the ring at 1.5 emission
    # energy against the available item's 1.8, and the authored pair should
    # not invert that.
    common.assign(obj, common.make_signal_material(
        "check_destination_ring", pal.universal("send", 0),
        pal.universal("send", 2), saturation=0.5))
    common.set_origin(obj, "module_floor")
    return common.export_glb(obj, "%s/check_destination_ring.glb" % OUT,
                             "interactable", anchor="module_floor")


def build_beam():
    """`SendBeam` -- 40 m of departing item, at reward.gd's own dimensions.

    Untextured on purpose. At the architecture density of 32 texels/m a
    40 m column would want a 1280-texel map, and the largest texture in the
    project is 128. A beam is a light, not a surface; it gets a material and
    no UVs.

    The engine tweens it to `scale(0.06, 1, 0.06)` while the emission fades,
    so the taper is what is seen for the first frames and the thin stem for
    the rest. It is built as an eight-sided frustum for the same reason
    everything else here is: a smooth 40 m cylinder is a 2010s cylinder.
    """
    obj = brushkit.prism("check_send_beam", BEAM_BOTTOM_R, BEAM_H, 8,
                         (0.0, 0.0, BEAM_H / 2.0), top_radius=BEAM_TOP_R,
                         asset_name="check_send_beam")
    common.assign(obj, common.make_signal_material(
        "check_send_beam", pal.universal("send", 0), pal.universal("send", 3),
        saturation=0.92))
    common.set_origin(obj, "module_floor")
    return common.export_glb(obj, "%s/check_send_beam.glb" % OUT,
                             "interactable", anchor="module_floor")


def main():
    common.reset_scene()
    report = {}
    report["check_mast"] = build_mast()
    for state, builder in STATES:
        report["check_item_%s" % state] = build_state(state, builder)
    report["check_destination_ring"] = build_ring()
    report["check_send_beam"] = build_beam()

    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch005",
                       "check", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")


if __name__ == "__main__":
    main()
