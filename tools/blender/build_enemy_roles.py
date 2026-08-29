"""Batch 030 -- the ten approved enemy roles, at their published envelopes.

VISUAL TREATMENT ONLY. Nothing invents an attack, an AI, health, a status
effect, boss behaviour or telegraph timing.

## The audit, read-only -- and it corrects the art lane's own frontier

`claude/archipepsi-echoes-continuation-b1adno`.

**Interface requirement 7 is RESOLVED.** The art frontier still says seven of
the ten roles "wait on colliders". They do not. `schemas/constants.py`
publishes `ENEMY_ENVELOPES` for all ten, with the reason stated in its own
comment: *"the envelope is the box the art lane declared for the role, so a
model and a collider cannot be built to different numbers."*

    melee     0.80 w  1.60 h  0.80 d
    ranged    0.70     1.40     0.70
    brute     1.80     2.60     1.80
    charger   0.90     1.05     1.90     <- long and low
    bulwark   1.45     2.05     0.85     <- wide and thin
    scuttler  1.30     0.62     1.20     <- flat
    artillery 1.25     1.55     1.25
    beacon    0.62     2.20     0.62     <- tall and narrow
    diver     0.70     0.50     1.20     hover 1.90
    drifter   1.35     0.95     1.35     hover 2.55

`hover_height` is the collider's CENTRE above the floor, and the docstring
says why: *"a flyer described by its base can be given a height that puts its
crown through a doorway, and the reader cannot tell which was meant."*

**Interface requirement 14 is RESOLVED too.** `godot/scripts/enemies/enemy.gd`
carries `signal telegraph_started(kind, duration)`,
`signal telegraph_finished(kind, completed)`, `telegraph_progress()` returning
0..1, and a named attachment point:

    var telegraph_origin: Marker3D   # at ENEMY_ENVELOPES[role].centre_y,
                                     # OUTSIDE `visual`

and a `visual: Node3D` container with a rule attached: *"EVERY mesh hangs off
this and nothing else does, so a hit flinch or a windup swell scales the LOOK
and can never move the collider -- which is what `scale` on the body did, and
it grew the brute's hitbox 12% for the half second it was winding up."*

**So this batch is not a proposal in the way 023-029 were.** It is authored
to numbers Production has already published, and every model here is built to
its role's exact envelope and asserts it. What remains missing is narrower
and is recorded as requirement 31: `ENEMY_ARCHETYPES` -- the set a Zone may
actually place -- is still `("melee", "ranged", "brute")`. Seven of the ten
have an agreed body and no way to be spawned.

## What "stronger visual treatment" means when the box is fixed

The envelope is not a suggestion, so silhouette variety has to come from
INSIDE a given box rather than from changing its size. That is the discipline
of this batch, and it is why the roles are built around the proportion the
envelope already implies:

| role | what the envelope already says | the treatment that follows |
|---|---|---|
| melee | human-ish, 1.6 m | upright, forward-weighted, arms as the threat |
| ranged | slighter, 1.4 m | upright but recessed; the emitter is the read |
| brute | 1.8 x 2.6 x 1.8 | mass over reach: a slab of shoulders, small head |
| charger | 1.9 m DEEP, 1.05 m tall | a battering ram -- the long axis IS the attack |
| bulwark | 1.45 wide, 0.85 thin | a wall that walks: broad face, no depth |
| scuttler | 1.3 x 0.62 x 1.2 | flat and splayed; legs out, body low |
| artillery | 1.25 cube-ish, 1.55 tall | a seated mortar: braced base, elevated barrel |
| beacon | 0.62 x 2.2 x 0.62 | a mast, not a creature. It is a fixture that took sides |
| diver | 1.2 m deep, 0.5 tall, hover 1.9 | a stooping shape, nose down |
| drifter | 1.35 cube, hover 2.55 | a hanging bell, slow, no front |

## Threat legibility without inventing behaviour

A player has to read DANGER FROM WHERE before an attack exists, and that is a
shape question, not an AI one:

- **the threat end is the heavy end.** Charger's mass is forward, artillery's
  is at the barrel, brute's is in the shoulders.
- **a telegraph needs somewhere to happen.** Every role carries a marked
  telegraph seat at `centre_y`, matching `telegraph_origin`. It is geometry
  reserved for a thing Production owns, not a telegraph.
- **flyers do not stand.** Both hover roles are modelled around their
  collider centre at the published `hover_height`, so a flyer's silhouette
  sits where the contract says it sits.

## Palette

Enemies wear `propkit.enemy_skin`, the approved family treatment. `hazard`
appears ONLY on the beacon, which is the one role whose envelope is a fixture
rather than a body -- and even there it is a marked band, never a wash. No
enemy takes `signal`, `identity` or `send`: a thing that hurts you is not a
thing you can use, is not Epsilon, and does not leave for the multiworld.
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
OUT = "batch030/enemies"

#: Read from Production, never redefined here. If these drift, the models
#: and the colliders drift with them and the whole point is lost.
ENVELOPES = {
    "melee":     (0.80, 1.60, 0.80, 0.0),
    "ranged":    (0.70, 1.40, 0.70, 0.0),
    "brute":     (1.80, 2.60, 1.80, 0.0),
    "charger":   (0.90, 1.05, 1.90, 0.0),
    "bulwark":   (1.45, 2.05, 0.85, 0.0),
    "scuttler":  (1.30, 0.62, 1.20, 0.0),
    "artillery": (1.25, 1.55, 1.25, 0.0),
    "beacon":    (0.62, 2.20, 0.62, 0.0),
    "diver":     (0.70, 0.50, 1.20, 1.90),
    "drifter":   (1.35, 0.95, 1.35, 2.55),
}

PLACEABLE = ("melee", "ranged", "brute")


def _tag(objs, role):
    return [(o, role) for o in (objs if isinstance(objs, list) else [objs])]


def _seat(z):
    """The telegraph seat, at the collider centre. Geometry RESERVED for a
    thing Production owns -- it is not a telegraph and does not animate."""
    return _tag(brushkit.tube("telegraph_seat", 0.13, 0.09, 0.05, 8,
                              (0.0, 0.0, z)), "mark")


def _melee(w, h, d):
    out = []
    out += _tag(brushkit.block("legs", (w * 0.62, d * 0.52, h * 0.42),
                               (0.0, 0.0, h * 0.21)), "body")
    out += _tag(brushkit.block("torso", (w * 0.86, d * 0.66, h * 0.36),
                               (0.0, -0.03, h * 0.60)), "body")
    # The threat is the arms, so they are forward and they are the mass.
    for sx in (-1.0, 1.0):
        out += _tag(brushkit.block("arm_%d" % int(sx),
                                   (w * 0.20, d * 0.80, h * 0.30),
                                   (sx * w * 0.39, -d * 0.16, h * 0.58)),
                    "plate")
    out += _tag(brushkit.block("head", (w * 0.40, d * 0.42, h * 0.14),
                               (0.0, -0.02, h * 0.90)), "plate")
    return out


def _ranged(w, h, d):
    out = []
    out += _tag(brushkit.block("legs", (w * 0.56, d * 0.50, h * 0.46),
                               (0.0, 0.0, h * 0.23)), "body")
    out += _tag(brushkit.block("torso", (w * 0.74, d * 0.60, h * 0.34),
                               (0.0, 0.04, h * 0.63)), "body")
    # Recessed body, and ONE emitter carried out front: the read is the
    # muzzle, because that is where the danger comes from.
    out += _tag(brushkit.block("arm", (w * 0.30, d * 0.78, h * 0.16),
                               (w * 0.28, -d * 0.20, h * 0.62)), "plate")
    out += _tag(brushkit.prism("emitter", w * 0.15, d * 0.34, 8,
                               (w * 0.28, -d * 0.36, h * 0.62)), "plate")
    emitter = out[-1][0]
    brushkit.spin(emitter, "x", 90.0)
    out += _tag(brushkit.block("head", (w * 0.34, d * 0.36, h * 0.12),
                               (0.0, 0.02, h * 0.92)), "plate")
    return out


def _brute(w, h, d):
    out = []
    # Mass over reach. Shoulders are the widest thing and the head is small,
    # so the silhouette says WEIGHT rather than span.
    out += _tag(brushkit.block("legs", (w * 0.70, d * 0.62, h * 0.38),
                               (0.0, 0.0, h * 0.19)), "body")
    out += _tag(brushkit.block("hips", (w * 0.78, d * 0.70, h * 0.14),
                               (0.0, 0.0, h * 0.44)), "body")
    out += _tag(brushkit.block("shoulders", (w, d * 0.86, h * 0.30),
                               (0.0, 0.0, h * 0.66)), "plate")
    for sx in (-1.0, 1.0):
        out += _tag(brushkit.block("fist_%d" % int(sx),
                                   (w * 0.28, d * 0.44, h * 0.26),
                                   (sx * w * 0.33, -d * 0.24, h * 0.40)),
                    "plate")
    out += _tag(brushkit.block("head", (w * 0.26, d * 0.28, h * 0.11),
                               (0.0, -0.06, h * 0.87)), "body")
    return out


def _charger(w, h, d):
    out = []
    # 1.9 m of DEPTH and 1.05 m of height: the long axis is the attack, so
    # the mass is at the front and the body tapers away behind it.
    out += _tag(brushkit.block("ram", (w, d * 0.22, h * 0.72),
                               (0.0, -d * 0.38, h * 0.44)), "plate")
    out += _tag(brushkit.wedge("prow", (w * 0.92, d * 0.24, h * 0.50),
                               (0.0, -d * 0.16, h * 0.36), axis="y"), "plate")
    out += _tag(brushkit.block("spine", (w * 0.66, d * 0.44, h * 0.44),
                               (0.0, d * 0.06, h * 0.42)), "body")
    out += _tag(brushkit.block("haunch", (w * 0.52, d * 0.24, h * 0.34),
                               (0.0, d * 0.36, h * 0.30)), "body")
    for sx in (-1.0, 1.0):
        for i, y in enumerate((-0.24, 0.10, 0.34)):
            out += _tag(brushkit.block("leg_%d_%d" % (int(sx), i),
                                       (w * 0.15, d * 0.10, h * 0.30),
                                       (sx * w * 0.40, d * y, h * 0.15)),
                        "body")
    return out


def _bulwark(w, h, d):
    out = []
    # A wall that walks: 1.45 wide and 0.85 thin. The face is the object.
    out += _tag(brushkit.block("shield", (w, d * 0.30, h * 0.70),
                               (0.0, -d * 0.32, h * 0.52)), "plate")
    for i in range(3):
        out += _tag(brushkit.block("rib_%d" % i, (w * 0.10, d * 0.16, h * 0.66),
                                   (-w * 0.30 + i * w * 0.30, -d * 0.44,
                                    h * 0.52)), "body")
    out += _tag(brushkit.block("body", (w * 0.52, d * 0.52, h * 0.54),
                               (0.0, d * 0.18, h * 0.44)), "body")
    for sx in (-1.0, 1.0):
        out += _tag(brushkit.block("foot_%d" % int(sx),
                                   (w * 0.20, d * 0.60, h * 0.20),
                                   (sx * w * 0.24, d * 0.10, h * 0.10)),
                    "body")
    out += _tag(brushkit.block("crown", (w * 0.88, d * 0.22, h * 0.10),
                               (0.0, -d * 0.30, h * 0.92)), "plate")
    return out


def _scuttler(w, h, d):
    out = []
    # Flat and splayed: 0.62 m tall over a 1.3 m span. Legs OUT, body low.
    out += _tag(brushkit.prism("carapace", w * 0.34, h * 0.52, 8,
                               (0.0, 0.0, h * 0.42), top_radius=w * 0.22,
                               organic=True), "plate")
    for i in range(6):
        a = -60.0 + i * 24.0
        sx = -1.0 if i % 2 == 0 else 1.0
        out += _tag(brushkit.block("leg_%d" % i,
                                   (w * 0.34, d * 0.10, h * 0.14),
                                   (sx * w * 0.30, d * (-0.30 + 0.12 * i),
                                    h * 0.20), rotation_z=a), "body")
    out += _tag(brushkit.block("maw", (w * 0.26, d * 0.20, h * 0.20),
                               (0.0, -d * 0.36, h * 0.24)), "body")
    return out


def _artillery(w, h, d):
    out = []
    # A seated mortar: braced base, elevated barrel. The threat end is the
    # muzzle and it is the heaviest thing on the model.
    out += _tag(brushkit.block("base", (w * 0.94, d * 0.94, h * 0.24),
                               (0.0, 0.0, h * 0.12)), "body")
    for i in range(4):
        out += _tag(brushkit.wedge("brace_%d" % i,
                                   (w * 0.28, d * 0.30, h * 0.22),
                                   (0.0, 0.0, h * 0.26), rotation_z=i * 90.0,
                                   axis="y"), "body")
    out += _tag(brushkit.prism("turret", w * 0.34, h * 0.34, 8,
                               (0.0, 0.0, h * 0.52)), "body")
    out += _tag(brushkit.block("barrel", (w * 0.28, d * 0.62, h * 0.28),
                               (0.0, -d * 0.16, h * 0.76)), "plate")
    out += _tag(brushkit.prism("muzzle", w * 0.20, d * 0.22, 8,
                               (0.0, -d * 0.42, h * 0.82)), "plate")
    muzzle = out[-1][0]
    brushkit.spin(muzzle, "x", 90.0)
    return out


def _beacon(w, h, d):
    out = []
    # A mast, not a creature: 0.62 square and 2.2 tall. This is the one role
    # whose envelope is a FIXTURE that took sides, and the only one that
    # wears a hazard band.
    out += _tag(brushkit.prism("foot", w * 0.46, h * 0.10, 8,
                               (0.0, 0.0, h * 0.05)), "body")
    out += _tag(brushkit.block("mast", (w * 0.30, d * 0.30, h * 0.74),
                               (0.0, 0.0, h * 0.46)), "body")
    for i, z in enumerate((0.30, 0.52, 0.74)):
        out += _tag(brushkit.block("collar_%d" % i,
                                   (w * 0.52, d * 0.52, h * 0.05),
                                   (0.0, 0.0, h * z)), "body")
    out += _tag(brushkit.prism("head", w * 0.44, h * 0.20, 8,
                               (0.0, 0.0, h * 0.90), organic=True), "plate")
    # The band. Marked, never a wash.
    out += _tag(brushkit.tube("band", w * 0.48, w * 0.40, h * 0.07, 8,
                              (0.0, 0.0, h * 0.80)), "warn")
    return out


def _diver(w, h, d):
    out = []
    # Nose down, 1.2 m deep over 0.5 m tall. A stooping shape, and it reads
    # as committed to a direction even at rest.
    out += _tag(brushkit.wedge("nose", (w, d * 0.46, h * 0.80),
                               (0.0, -d * 0.26, 0.0), axis="y"), "plate")
    out += _tag(brushkit.block("spine", (w * 0.60, d * 0.50, h * 0.56),
                               (0.0, d * 0.20, h * 0.06)), "body")
    for sx in (-1.0, 1.0):
        out += _tag(brushkit.block("fin_%d" % int(sx),
                                   (w * 0.28, d * 0.30, h * 0.16),
                                   (sx * w * 0.34, d * 0.28, h * 0.10)),
                    "body")
    return out


def _drifter(w, h, d):
    out = []
    # A hanging bell: 1.35 square, slow, and with NO front. It is the one
    # role whose silhouette deliberately gives away no facing.
    out += _tag(brushkit.prism("bell", w * 0.48, h * 0.62, 8,
                               (0.0, 0.0, h * 0.06), top_radius=w * 0.24,
                               organic=True), "plate")
    out += _tag(brushkit.tube("skirt", w * 0.50, w * 0.38, h * 0.20, 8,
                              (0.0, 0.0, -h * 0.28)), "body")
    for i in range(4):
        out += _tag(brushkit.block("tendril_%d" % i,
                                   (w * 0.07, d * 0.07, h * 0.30),
                                   (0.0, 0.0, -h * 0.30),
                                   rotation_z=45.0 + i * 90.0), "body")
    return out


ROLES = {
    "melee": (_melee, "upright, forward-weighted; the arms are the threat"),
    "ranged": (_ranged, "recessed body, one carried emitter -- read the muzzle"),
    "brute": (_brute, "mass over reach: a slab of shoulders, a small head"),
    "charger": (_charger, "a battering ram -- the long axis IS the attack"),
    "bulwark": (_bulwark, "a wall that walks: broad face, almost no depth"),
    "scuttler": (_scuttler, "flat and splayed, legs out, body low"),
    "artillery": (_artillery, "a seated mortar: braced base, elevated barrel"),
    "beacon": (_beacon, "a mast, not a creature -- a fixture that took sides"),
    "diver": (_diver, "nose down; committed to a direction even at rest"),
    "drifter": (_drifter, "a hanging bell -- deliberately gives away no facing"),
}


def main():
    report = {}
    for role, (builder, reads_as) in ROLES.items():
        common.reset_scene()
        w, h, d, hover = ENVELOPES[role]
        # `enemy_role_*`, NOT `enemy_*`. Batch 002 already owns
        # `enemy_scuttler`, `enemy_charger`, `enemy_bulwark`,
        # `enemy_artillery`, `enemy_beacon`, `enemy_drifter` and
        # `enemy_diver`, and those are PASS. Ids are the ledger's
        # key, so reusing one silently redefines approved work --
        # check_docs_metrics caught it reading THIS build's numbers
        # against Batch 002's approved rows.
        name = "enemy_role_%s" % role
        parts = builder(w, h, d)
        centre_z = hover if hover else h / 2.0
        parts += _seat(centre_z - (hover if hover else 0.0))

        buckets = {}
        for obj, r in parts:
            buckets.setdefault(r, []).append(obj)
        painted = []
        for r, marking in (("body", "dead"), ("plate", "dead"),
                           ("mark", "dead"), ("warn", "hazard")):
            got = buckets.get(r)
            if not got:
                continue
            obj = common.join(got, "%s_%s" % (name, r))
            common.uv_project_world(obj, propkit.PROP_DENSITY,
                                    propkit.PROP_SIZE)
            common.assign(obj, common.make_textured_material(
                "%s_%s" % (name, r),
                propkit.enemy_skin(THEME, "%s_%s" % (name, r),
                                   marking=marking).to_blender(
                    "%s_%s_t" % (name, r)),
                roughness=pal.roughness(THEME)))
            painted.append(obj)

        obj = common.join(painted, name)
        common.set_origin(obj, "floor")
        # The envelope is a CONTRACT, not a guide. A model that overruns it
        # is a model whose collider disagrees with it.
        common.assert_fits(obj, name, (w, d, h),
                           "ENEMY_ENVELOPES[%r] is %.2f x %.2f x %.2f m and "
                           "Production builds the collider from the same "
                           "numbers." % (role, w, h, d))
        record = common.export_glb(obj, "%s/%s.glb" % (OUT, name), "enemy",
                                   check_flat=False)
        record.update({
            "batch": "030",
            "kind": "enemy_role",
            "role": role,
            "reads_as": reads_as,
            "envelope_w_h_d_m": [w, h, d],
            "hover_height_m": hover,
            "is_flying": hover > 0.0,
            "envelope_source": "Constants.ENEMY_ENVELOPES -- read, never "
                               "redefined by art",
            "telegraph_seat_at_centre_y_m": centre_z,
            "telegraph_seat_is": "reserved geometry matching enemy.gd's "
                                 "telegraph_origin Marker3D. NOT a telegraph "
                                 "and it does not animate",
            "placeable_today": role in PLACEABLE,
            "placeable_source": "Constants.ENEMY_ARCHETYPES is still "
                                "('melee', 'ranged', 'brute')",
            "invents_no_behaviour": True,
            "integration_ready": False,
            "scale_basis": "authored to the published envelope",
        })
        report[name] = record

    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch030",
                       "enemies", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")
    common.log("[batch030] %d assets -> %s" % (len(report), OUT))


if __name__ == "__main__":
    main()
