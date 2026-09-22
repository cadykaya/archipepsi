"""The gates every theme pack is held to, in one place.

    import packgates
    packgates.assert_opening_clear(objects, name)

## Why a module and not a copy per pack

There are eighteen packs in the first wave and sixty-three behind them.
These three checks are the art lane's half of the load-bearing boundary
-- Production owns gameplay geometry, collision, state timing, placement
and routes, and these are what keep an authored pack from quietly taking
any of that. Copied into eighteen builders they would be eighteen places
for the next correction to miss.

They were written for Batch 054 (`build_forest_temple.py`) and every one
of them was **sabotage-tested, and two were wrong first**:

* `assert_opening_clear` caught a real defect -- a door boss centred on
  its jamb but 0.08 m wider, overhanging 0.04 m into the doorway. It
  also called a TANGENCY an intrusion, because a lintel authored at
  `door_height` exactly arrives as 3.1999999999999997; `GRAZE` is a
  millimetre and that is nothing beside a 3.2 m opening.
* `assert_no_footholds` exempted a 2.16 x 0.58 m shelf because a lintel
  three metres up overlapped it by two centimetres. "Covered from above"
  now means a standable 0.35 m patch does not survive, measured.
* `assert_no_emitters` has not been wrong yet, which is not the same as
  being right; it is the simplest of the three.

A fourth gate exists and is NOT here, because it cannot be: the
imported-geometry opening check in `tools/content/pack_views.gd`
runs in Godot, on the `.glb`, which is a different artefact from the
Blender scene these three measure.
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402

DIM = common.DIM
DOOR_W = DIM["door_width"]
DOOR_H = DIM["door_height"]
#: The measured walk-up. Below this nothing is a step.
WALK_UP = 0.12
JUMP_APEX = DIM["jump_apex"]
#: One millimetre. See assert_opening_clear.
GRAZE = 0.001


def assert_opening_clear(objects, label, width=DOOR_W, height=DOOR_H):
    """Nothing may narrow the engine's door opening. Not by a millimetre.

    The opening is `chamber_builders.gd`'s and the player walks through
    it. A surround is dressing around a hole; a surround that grows into
    the hole is a capability requirement the art lane invented.

    Measured against the geometry, not against the nominal numbers the
    builder used -- the same distinction `assert_parts_touch` exists for.
    """
    for obj in objects:
        lo, hi = common.world_box(obj)
        # Anything crossing the opening's own volume is refused. The
        # opening is centred on x=0 and rises from the floor.
        #
        # THE SAME MILLIMETRE AS THE HEIGHT TEST BELOW, and it took a
        # third asset to notice it was missing here. A roller shutter's
        # guide lip has its inner face ON the opening edge -- that is
        # what a guide is -- and `tp_br_shutter_head` authored it at
        # exactly 1.20 m. Blender's float32 delivered 1.1999999 and the
        # gate reported an intrusion "by 0.000 m", which is a refusal
        # of correct architecture and the fastest way to get a gate
        # switched off. A millimetre against a 2.4 m opening is nothing
        # beside the arithmetic; a 5 mm intrusion still fails, and that
        # is checked rather than assumed.
        if hi[0] <= -width / 2.0 + GRAZE or lo[0] >= width / 2.0 - GRAZE:
            continue
        # A TANGENCY IS NOT AN INTRUSION, and this gate made that
        # mistake on its first run. The lintel's underside is authored
        # AT `door_height` exactly; in floating point that arrives as
        # 3.1999999999999997 and a bare `>=` called it a 2.74 m
        # intrusion. `skiff_sweep` learned the same lesson in metres and
        # `manipulation_readiness` in newtons -- a millimetre here is
        # nothing beside a 3.2 m opening and far more than the
        # arithmetic.
        if lo[2] >= height - GRAZE:
            continue
        intrude = min(width / 2.0 - lo[0], hi[0] + width / 2.0)
        raise AssertionError(
            "%s: %s reaches into the %.2f x %.2f m door opening by %.3f m "
            "at height %.2f-%.2f. The opening is chamber_builders.gd's and "
            "the player walks through it; dress around it, never into it."
            % (label, obj.name, width, height, intrude, lo[2], hi[2]))


def assert_no_emitters(objects, label):
    """A housing, never a light.

    `export_content_pack.py` refuses an authored housing that carries its
    own `Light3D` -- illumination is engine-owned. This catches it at
    build time instead of at export, and it also refuses an emissive
    material, which is the same claim made a different way.
    """
    for obj in objects:
        if obj.type == "LIGHT":
            raise AssertionError(
                "%s: %s is a LIGHT. Illumination is engine-owned; this kit "
                "ships the housing a flame sits in and nothing that lights "
                "it." % (label, obj.name))
        for slot in obj.material_slots:
            mat = slot.material
            if mat is None or not mat.use_nodes:
                continue
            for node in mat.node_tree.nodes:
                if node.type == "EMISSION":
                    raise AssertionError(
                        "%s: %s carries an emission node. Same rule: the "
                        "housing is art, the light is the engine's."
                        % (label, obj.name))


def assert_no_footholds(objects, label):
    """No art-added route. Bounded above by the measured jump, because a
    rule with no upper bound refuses the top of a two-metre wall -- the
    correction Batch 049 made and Batch 048 inherited."""
    for obj in objects:
        lo, hi = common.world_box(obj)
        top = hi[2]
        if top <= WALK_UP + 1e-4 or top > JUMP_APEX:
            continue
        w = hi[0] - lo[0]
        d = hi[1] - lo[1]
        if w < 0.35 or d < 0.35:
            continue
        # A PLINTH IS NOT A ROUTE, and this is the refinement that
        # distinguishes them. The rule exists so art does not add a way
        # UP; a foothold with the asset's own body rising past the jump
        # directly above it leads nowhere -- you stand on a column base
        # and what you have reached is more column. Refusing that is
        # refusing correct architecture, and a gate that refuses correct
        # art is a gate that gets switched off.
        #
        # "Directly above" is measured, not assumed: another part of the
        # same asset must overlap this one in plan AND rise more than a
        # jump above its top.
        # ...AND "COVERED FROM ABOVE" MEANS COVERED, NOT GRAZED. The
        # first version of this exemption asked only whether some part
        # overlapped in plan and rose a jump above. Sabotage-tested with
        # a standalone ledge, it DID NOT FIRE: the lintel three metres up
        # overlapped the ledge by two centimetres, and two centimetres
        # bought a 2.16 x 0.58 m shelf an exemption.
        #
        # So the question is whether a STANDABLE PATCH SURVIVES. Subtract
        # the blocker's plan rectangle from the foothold's and look at
        # the four strips that are left; if any of them is still 0.35 m
        # square, the player can stand there and the exemption does not
        # apply.
        blocked = False
        for other in objects:
            if other is obj:
                continue
            olo, ohi = common.world_box(other)
            if ohi[0] <= lo[0] or olo[0] >= hi[0]:
                continue
            if ohi[1] <= lo[1] or olo[1] >= hi[1]:
                continue
            if ohi[2] <= top + JUMP_APEX:
                continue
            strips = (
                (olo[0] - lo[0], d),        # free to the left
                (hi[0] - ohi[0], d),        # free to the right
                (w, olo[1] - lo[1]),        # free in front
                (w, hi[1] - ohi[1]),        # free behind
            )
            if any(sw >= 0.35 and sd >= 0.35 for sw, sd in strips):
                continue                    # this one does not cover it
            blocked = True
            break
        if blocked:
            continue
        raise AssertionError(
            "%s: %s gives a %.2f x %.2f m upward face at %.2f m -- "
            "above the %.2f m walk-up and inside the %.2f m jump, so a "
            "player can stand on it. Art does not add routes."
            % (label, obj.name, w, d, top, WALK_UP, JUMP_APEX))
