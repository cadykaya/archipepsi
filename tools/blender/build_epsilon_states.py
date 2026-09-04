"""Batch 024 -- PROPOSAL: Epsilon presentation states, and the presentation arc.

PRESENTATION ONLY. Nothing here invents a gameplay effect, a corruption
mechanic or a progression rule. What triggers a state, how long it holds and
what it costs are Production's, and this file does not guess at any of them.

## The runtime audit, read-only, before any modelling

Audited against `claude/archipepsi-echoes-continuation-b1adno`, which is the
current Production head -- NOT the art lane's base, which is where the Batch
023 audit went wrong (L-72).

`godot/scripts/ui/epsilon_voice.gd` is the only Epsilon presentation code
that exists. It is a BARK SELECTOR: 18 event kinds (`first_blood`,
`room_cleared`, `portal_open`, `hurt`, `died`, `revived`, `secret_found`,
`long_walk`, `finale_open`, `finale_brute`, `goal_sent`,
`campaign_complete`, and six `hub_*` kinds), a PRIORITY order, a 6 s
COOLDOWN, a 4 s DWELL and a 42 s hub idle interval.

    It answers WHAT EPSILON SAYS. It does not answer WHAT THE
    INSTALLATION LOOKS LIKE WHILE IT SAYS IT.

There is no presentation-state enum, no visual-state signal, and no binding
from a bark to any material. So the six states below are a PROPOSAL, and each
one records honestly whether a runtime signal for it already exists:

| state | runtime signal today |
|---|---|
| dormant / listening | ABSENCE of one. No bark airing, no request in flight. Derivable. |
| thinking / generating | Bridge-side only. `epsilon/requests.py` knows a request is out; nothing surfaces it to the scene. |
| speaking | EXISTS. `EpsilonVoice.tick()` holds a line for DWELL seconds. Bindable today. |
| successful interpretation | Bridge-side only. A validated provider result is not surfaced. |
| error / refusal | Bridge-side only. `epsilon/fallback.py` runs when a provider fails; the scene is never told. |
| player attention / focus | DOES NOT EXIST. No look-at or proximity test against the installation. |

One of six is bindable today. That is the seam, and it is recorded as
interface requirement 25 rather than worked around.

## The DNA this inherits, unchanged

Batch 002-R is PASS and is the alphabet here. Two of its rules are
load-bearing and are not reopened:

**Nothing on the human half glows.** Not a readout, not a status lamp, not a
specular highlight broad enough to read as a picture. Every state below is
carried by the INTRUSION. A state that lit the console would say the facility
came back on, which is a different sentence entirely.

**Emissive saturation 0.40 is the CEILING, not a midpoint.** 002-R swept
0.94 / 0.60 / 0.40 / 0.25 / 0.12 through the review bench and found the clip
point between 0.40 and 0.60: at 0.60 the green channel pins at 255 and the
core stops being a colour. So the six states modulate BELOW 0.40, and the
loudest of them sits exactly on it. A state language built by turning the
green up would have had two usable steps.

## Six states, and how they differ without a second colour

`identity` green is the only hue Epsilon gets -- "its presence, its terminal,
its voice surfaces and nothing else in the game". So the states cannot be
told apart by hue, and this is the same arithmetic Batch 022 ran for
navigation: the language has to be VALUE, EXTENT, RHYTHM, APERTURE and
ORIENTATION.

| state | emission | where the light is | aperture |
|---|---|---|---|
| dormant / listening | 0.10 | deep in the seams only | flush, closed |
| thinking / generating | 0.22 | interior veins, along the limb | closed, veins proud |
| speaking | 0.34 | out through opened seam faces | splayed toward the room |
| interpretation OK | 0.28 | a CLOSED circuit -- continuous, even | ring complete |
| error / refusal | 0.06 | asymmetric dropout; `dead` plating exposed | clamped shut |
| attention / focus | 0.34 | one narrow directed bore | iris, oriented |

Note what separates `speaking` from `focus` at the same 0.34: speaking is
BROAD and undirected, focus is a single narrow bore that points. And what
separates `interpretation OK` from both is not brightness but CLOSURE -- the
vein ring completes. A player learns "it finished" from a shape, not a level.

`error / refusal` is the only state that recruits a second family, and it
recruits `dead` -- "unpowered, locked, spent, offline" -- which is exactly
what a refusal is. It does NOT use `glitch`: glitch means Epsilon Static and
the missing-world checker, and a refusal is Epsilon declining, not Epsilon
corrupted.

## The arc: localized -> established -> proprietorial

Three dressings of the SAME bank, differing only in how much of the room the
intrusion owns. This is presentation, not progression: nothing here says when
a stage applies, what advances it, or that it advances at all.

| stage | what the intrusion has taken |
|---|---|
| EARLY -- localized, tentative | one wrecked bay. It has not left the cabinet line. |
| MIDDLE -- established, confident | the console's right third, and the cable tray it hijacked. This is the 002-R state. |
| LATE -- deeply embedded, proprietorial | floor, ceiling and the full bank front. The human machine is now substrate, not host. |

The read is EXTENT, not brightness -- a late stage is not a brighter early
stage, it is a larger one. Emission holds at the same 0.24 across all three
so the comparison cannot be won by turning the light up.
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
OUT = "batch024/epsilon"

#: The 002-R clip ceiling. Nothing in this batch exceeds it.
SAT_CEILING = 0.40

#: One console bay, at the heights 002-R established: desk 0.95, monitor at
#: eye + 0.45. The state module is ONE bay so the six are identical except
#: for state -- a comparison sheet whose panels differ in two ways proves
#: nothing about either.
BAY_W = 2.40
BAY_D = 0.90
BAY_H = 2.90

STATE_BOX = (3.2, 2.0, 3.4)
ARC_BOX = (6.4, 3.2, 4.6)


def _tag(objs, role):
    """Pair geometry with the material role it is painted from."""
    return [(o, role) for o in (objs if isinstance(objs, list) else [objs])]


# ----------------------------------------------------------------------
# The human half. Identical in all six states, and it never glows.
# ----------------------------------------------------------------------

def _console_bay():
    """One operator bay of the 002-R bank: cabinet, desk, footwell, raked
    panel, instrument strip, dead monitor. Nothing here emits."""
    out = []
    # Cabinet carcass, with the footwell cut by simply not filling it.
    out += _tag(brushkit.block("carcass_back", (BAY_W, 0.18, BAY_H),
                               (0.0, BAY_D / 2 - 0.09, BAY_H / 2)), "human")
    for sx in (-1.0, 1.0):
        out += _tag(brushkit.block("carcass_side", (0.14, BAY_D, BAY_H),
                                   (sx * (BAY_W / 2 - 0.07), 0.0, BAY_H / 2)),
                    "human")
    # Under-desk cabinet, stopping short of the floor so a foot goes in.
    out += _tag(brushkit.block("plinth", (BAY_W - 0.28, BAY_D - 0.30, 0.16),
                               (0.0, 0.15, 0.08)), "human")
    out += _tag(brushkit.block("footwell_back",
                               (BAY_W - 0.28, 0.16, 0.62),
                               (0.0, BAY_D / 2 - 0.26, 0.55)), "human")

    # The desk you stand at, and the raked panel your hands go on.
    out += _tag(brushkit.block("desk", (BAY_W - 0.20, 0.62, 0.07),
                               (0.0, -0.10, 0.95)), "control")
    out += _tag(brushkit.wedge("rake", (BAY_W - 0.34, 0.34, 0.16),
                               (0.0, 0.22, 1.03), axis="y"), "control")
    out += _tag(brushkit.block("instrument", (BAY_W - 0.40, 0.10, 0.22),
                               (0.0, 0.30, 1.30)), "control")

    # Monitor housing at eye + 0.45, and its dead glass.
    out += _tag(brushkit.block("hood", (BAY_W - 0.16, 0.52, 0.96),
                               (0.0, 0.10, 2.05)), "human")
    out += _tag(brushkit.block("glass", (BAY_W - 0.52, 0.05, 0.62),
                               (0.0, -0.14, 2.05)), "screen")

    # The worn steel plate somebody stood on for years.
    out += _tag(brushkit.block("floor_plate", (BAY_W - 0.30, 0.70, 0.03),
                               (0.0, -0.62, 0.015)), "human")

    # Cable tray along the top -- the run the intrusion later hijacks.
    out += _tag(brushkit.block("tray", (BAY_W, 0.16, 0.10),
                               (0.0, 0.24, BAY_H - 0.06)), "human")
    return out


# ----------------------------------------------------------------------
# The intrusion. This is the ONLY thing that changes between states.
# ----------------------------------------------------------------------

def _limb(name, points, width, thickness):
    return brushkit.sweep(name, points, width, thickness)


def _mass(open_aperture, splay, clamp):
    """The alien mass through the monitor's right side.

    `open_aperture` opens the seam faces outward, `splay` swings the shutter
    petals into the room, `clamp` pulls the whole mass in on itself. Three
    scalars, because the six states differ in ARTICULATION and a state
    language whose members differ in unrelated ways is six objects again.
    """
    out = []
    # The body, canted and unrepeating -- it does not share the bay's grid.
    out += _tag(brushkit.prism("mass_core", 0.42 - 0.06 * clamp, 0.88, 8,
                               (0.72, 0.02, 2.02), rotation_z=17.0,
                               top_radius=0.30, organic=True), "alien")
    out += _tag(brushkit.prism("mass_lobe", 0.30 - 0.05 * clamp, 0.52, 8,
                               (0.92, -0.18, 1.62), rotation_z=-24.0,
                               top_radius=0.34, organic=True), "alien")
    # The limb reaching back across the desk it wrecked.
    out += _tag(_limb("limb", [(0.86, 0.06, 1.86), (0.62, -0.10, 1.44),
                               (0.30, -0.16, 1.16), (0.02, -0.14, 1.02)],
                      0.17, 0.13), "alien")
    # Conduits running left along the hijacked tray.
    out += _tag(_limb("conduit", [(0.90, 0.22, BAY_H - 0.10),
                                  (0.20, 0.24, BAY_H - 0.08),
                                  (-0.70, 0.24, BAY_H - 0.06)],
                      0.09, 0.07), "alien")

    # Shutter petals: flush at 0, splayed into the room at 1.
    for i, rot in enumerate((-40.0, 8.0, 52.0)):
        depth = -0.10 - 0.30 * splay
        out += _tag(brushkit.block("petal_%d" % i,
                                   (0.30, 0.05 + 0.13 * splay, 0.34),
                                   (0.72 + 0.10 * (i - 1), depth,
                                    2.02 + 0.20 * (i - 1)),
                                   rotation_z=rot), "alien")

    # The aperture ring the light comes out of.
    ring_r = 0.24 + 0.10 * open_aperture
    out += _tag(brushkit.tube("aperture", ring_r, ring_r - 0.07, 0.10, 8,
                              (0.72, -0.20 - 0.06 * open_aperture, 2.02)),
                "alien")
    return out


def _cores(kind):
    """The emissive geometry. WHERE the light is, per state.

    Returns (parts, saturation). Nothing else in the batch emits.
    """
    out = []
    add = out.append
    if kind == "dormant":
        # Deep in the seams only: small, recessed, nothing on the surface.
        for i, z in enumerate((1.86, 2.06, 2.24)):
            add(brushkit.block("seed_%d" % i, (0.05, 0.05, 0.11),
                               (0.70 + 0.05 * i, 0.10, z)))
        return out, 0.10

    if kind == "thinking":
        # Interior veins along the limb: the work is happening inside.
        for i, p in enumerate([(0.80, 0.02, 1.80), (0.58, -0.08, 1.46),
                               (0.32, -0.14, 1.20), (0.06, -0.13, 1.04)]):
            add(brushkit.block("vein_%d" % i, (0.07, 0.07, 0.09), p))
        for i, z in enumerate((1.90, 2.10)):
            add(brushkit.block("pulse_%d" % i, (0.06, 0.06, 0.13),
                               (0.72, 0.06, z)))
        return out, 0.22

    if kind == "speaking":
        # Out through the opened faces: broad, undirected, toward the room.
        add(brushkit.prism("mouth", 0.19, 0.10, 8,
                           (0.72, -0.30, 2.02), organic=True))
        for i, rot in enumerate((-40.0, 8.0, 52.0)):
            add(brushkit.block("face_%d" % i, (0.22, 0.04, 0.26),
                               (0.72 + 0.10 * (i - 1), -0.42,
                                2.02 + 0.20 * (i - 1)), rotation_z=rot))
        return out, 0.34

    if kind == "interpreted":
        # CLOSURE, not brightness: the vein ring completes and holds even.
        # This is the only state whose emissive geometry is continuous.
        add(brushkit.tube("circuit", 0.27, 0.21, 0.06, 8,
                          (0.72, -0.22, 2.02)))
        for i, p in enumerate([(0.80, 0.02, 1.80), (0.58, -0.08, 1.46),
                               (0.32, -0.14, 1.20), (0.06, -0.13, 1.04)]):
            add(brushkit.block("run_%d" % i, (0.08, 0.08, 0.08), p))
        add(brushkit.block("run_close", (0.08, 0.08, 0.08),
                           (0.02, -0.13, 1.02)))
        return out, 0.28

    if kind == "refusal":
        # Asymmetric dropout. Two of five cores survive, and they are the
        # deepest ones -- the surface has gone dark and the dead plating
        # underneath is what the player is left looking at.
        add(brushkit.block("ember_a", (0.05, 0.05, 0.09),
                           (0.70, 0.12, 1.88)))
        add(brushkit.block("ember_b", (0.04, 0.04, 0.07),
                           (0.84, 0.10, 2.18)))
        return out, 0.06

    if kind == "focus":
        # ONE narrow bore, pointing. Same level as speaking; the difference
        # is that this one has a direction and that one does not.
        add(brushkit.prism("bore", 0.10, 0.26, 8,
                           (0.72, -0.34, 2.02), organic=True))
        add(brushkit.tube("iris", 0.17, 0.12, 0.05, 8,
                          (0.72, -0.44, 2.02)))
        return out, 0.34

    raise ValueError("unknown state %r" % kind)


#: state -> (aperture, splay, clamp, dead_plating)
STATE_POSE = {
    "dormant":      (0.0, 0.0, 0.15, False),
    "thinking":     (0.15, 0.0, 0.0, False),
    "speaking":     (1.0, 1.0, 0.0, False),
    "interpreted":  (0.55, 0.35, 0.0, False),
    "refusal":      (0.0, 0.0, 1.0, True),
    "focus":        (0.85, 0.15, 0.0, False),
}

STATE_MEANS = {
    "dormant": "listening. Present, weighted, not working.",
    "thinking": "generating. The work is interior; nothing has been said yet.",
    "speaking": "a line is airing. Broad and undirected, into the room.",
    "interpreted": "it finished, and it worked. Read from CLOSURE, not level.",
    "refusal": "it declined, or it could not. Dropout to `dead`, not to glitch.",
    "focus": "it is attending to YOU. One narrow bore, and it points.",
}


# ----------------------------------------------------------------------
# The arc: the same bank, at three extents of ownership.
# ----------------------------------------------------------------------

ARC_BAYS = 4


def _bank(wrecked=()):
    """Four bays of cabinet, the human substrate for all three stages.

    `wrecked` names the bays whose FRONTS ARE GONE. 002-R is explicit that
    the erupted bays are destroyed -- "fronts gone, structure bent, the alien
    mass in the void" -- and the first render of this batch proved why that
    is not a decorative detail: with a front on every bay, the EARLY stage's
    intrusion sat sealed behind 0.10 m of cabinet and the panel rendered as a
    plain wall. The one sheet whose entire job is to show extent showed no
    intrusion at all.

    So a wrecked bay loses its front and its louvre and keeps a bent stub of
    each, which is also what the DNA says it should look like.
    """
    out = []
    span = ARC_BAYS * 1.2
    out += _tag(brushkit.block("bank_back", (span, 0.18, BAY_H),
                               (0.0, 0.36, BAY_H / 2)), "human")
    for i in range(ARC_BAYS + 1):
        x = -span / 2 + i * 1.2
        out += _tag(brushkit.block("rib_%d" % i, (0.10, 0.86, BAY_H),
                                   (x, 0.0, BAY_H / 2)), "human")
    for i in range(ARC_BAYS):
        x = -span / 2 + 0.6 + i * 1.2
        if i in wrecked:
            # Bent stubs top and bottom -- the front was here and failed.
            out += _tag(brushkit.block("stub_top_%d" % i,
                                       (1.02, 0.09, 0.26),
                                       (x, -0.38, BAY_H - 0.30),
                                       rotation_z=3.0 + 2.0 * i), "human")
            out += _tag(brushkit.wedge("stub_low_%d" % i,
                                       (0.94, 0.30, 0.22),
                                       (x, -0.34, 0.14), axis="y"), "human")
            continue
        out += _tag(brushkit.block("front_%d" % i, (1.02, 0.10, BAY_H - 0.24),
                                   (x, -0.40, BAY_H / 2)), "human")
        out += _tag(brushkit.block("louvre_%d" % i, (0.86, 0.06, 0.30),
                                   (x, -0.46, 0.60)), "human")
    out += _tag(brushkit.block("bank_tray", (span, 0.16, 0.10),
                               (0.0, 0.24, BAY_H - 0.06)), "human")
    out += _tag(brushkit.block("bank_plate", (span, 0.80, 0.03),
                               (0.0, -0.85, 0.015)), "human")
    return out


def _arc_mass(stage):
    """How much of the room the intrusion owns. EXTENT is the whole read."""
    out = []
    cores = []
    span = ARC_BAYS * 1.2
    right = span / 2 - 0.6

    # Every stage has the origin bay. Only the reach differs.
    out += _tag(brushkit.prism("origin", 0.46, 1.10, 8,
                               (right, 0.0, 1.70), rotation_z=15.0,
                               top_radius=0.34, organic=True), "alien")
    cores.append(brushkit.block("origin_core", (0.10, 0.10, 0.34),
                                (right, -0.20, 1.72)))

    if stage == "early":
        # Localized, tentative: it has not left the cabinet line. One
        # conduit onto the tray, and it stops after half a bay.
        out += _tag(_limb("feeler", [(right, 0.20, BAY_H - 0.08),
                                     (right - 0.70, 0.22, BAY_H - 0.06)],
                          0.08, 0.06), "alien")
        return out, cores

    # Established: the console's right third, and the tray it hijacked.
    out += _tag(brushkit.prism("lobe", 0.32, 0.66, 8,
                               (right - 0.9, -0.16, 1.20),
                               rotation_z=-28.0, top_radius=0.36,
                               organic=True), "alien")
    out += _tag(_limb("run", [(right, 0.20, BAY_H - 0.08),
                              (right - 1.6, 0.22, BAY_H - 0.06),
                              (right - 2.8, 0.22, BAY_H - 0.04)],
                      0.10, 0.08), "alien")
    cores.append(brushkit.block("lobe_core", (0.08, 0.08, 0.22),
                                (right - 0.9, -0.34, 1.22)))

    if stage == "middle":
        return out, cores

    # Proprietorial: floor, ceiling and the whole bank front. The human
    # machine is substrate now. Note this is still EXTENT -- the emission
    # level is identical to early, and that is deliberate.
    out += _tag(_limb("floor_run", [(right, -0.90, 0.10),
                                    (right - 1.8, -1.10, 0.10),
                                    (right - 3.4, -0.80, 0.10),
                                    (-span / 2 - 0.4, -0.50, 0.10)],
                      0.22, 0.14), "alien")
    out += _tag(_limb("ceiling_run", [(right - 0.4, 0.10, BAY_H + 0.10),
                                      (right - 2.0, -0.30, BAY_H + 0.62),
                                      (right - 3.6, -0.10, BAY_H + 0.92)],
                      0.18, 0.14), "alien")
    for i in range(ARC_BAYS):
        x = -span / 2 + 0.6 + i * 1.2
        out += _tag(brushkit.prism("growth_%d" % i, 0.20 + 0.03 * i, 0.44, 8,
                                   (x, -0.52, 0.9 + 0.28 * i),
                                   rotation_z=20.0 * i, top_radius=0.24,
                                   organic=True), "alien")
        cores.append(brushkit.block("growth_core_%d" % i, (0.06, 0.06, 0.14),
                                    (x, -0.62, 0.9 + 0.28 * i)))
    cores.append(brushkit.block("floor_core", (0.10, 0.10, 0.06),
                                (right - 1.8, -1.10, 0.14)))
    return out, cores


ARC_MEANS = {
    "early": "localized, tentative -- it has not left the cabinet line",
    "middle": "established, confident -- it owns the console's right third",
    "late": "deeply embedded, proprietorial -- floor, ceiling, the whole front",
}


# ----------------------------------------------------------------------

def _finish(name, tagged, cores, saturation, box, why, entry):
    """Paint by role, join, export. The human roles never emit."""
    buckets = {}
    for obj, role in tagged:
        buckets.setdefault(role, []).append(obj)

    painted = []
    specs = [
        ("human", propkit.machine_bank(THEME, name + "_panel", "panel"),
         propkit.PROP_DENSITY, propkit.PROP_SIZE, None),
        ("control", propkit.machine_bank(THEME, name + "_console", "console"),
         propkit.PROP_DENSITY, propkit.PROP_SIZE, None),
        # Dead glass at 0.50, not 0.25 -- 002-R found a broad specular reads
        # as a picture just as completely as an emission does.
        ("screen", propkit.machine_bank(THEME, name + "_screen", "screen"),
         propkit.PROP_DENSITY, propkit.PROP_SIZE, 0.50),
        ("alien", propkit.alien_shell(THEME, name),
         propkit.HERO_DENSITY, propkit.HERO_SIZE, 0.55),
    ]
    for role, canvas, density, size, rough in specs:
        parts = buckets.get(role)
        if not parts:
            continue
        obj = common.join(parts, "%s_%s" % (name, role))
        common.uv_project_world(obj, density, size)
        common.assign(obj, common.make_textured_material(
            "%s_%s" % (name, role),
            canvas.to_blender("%s_%s_t" % (name, role)),
            roughness=pal.roughness(THEME) if rough is None else rough))
        painted.append(obj)

    assert saturation <= SAT_CEILING, (
        "%s asks for emissive saturation %.2f; 002-R measured the clip point "
        "between 0.40 and 0.60 and 0.40 is the ceiling" % (name, saturation))
    core_obj = common.join(cores, name + "_cores")
    common.assign(core_obj, common.make_signal_material(
        name + "_cores", pal.universal("identity", 0),
        pal.universal("identity", 3), saturation=saturation))
    painted.append(core_obj)

    obj = common.join(painted, name)
    common.set_origin(obj, "floor")
    common.assert_fits(obj, name, box, why)
    record = common.export_glb(obj, "%s/%s.glb" % (OUT, name), "landmark",
                               check_flat=False)
    record.update(entry)
    return record


def main():
    report = {}

    for state, (aperture, splay, clamp, dead_plating) in STATE_POSE.items():
        common.reset_scene()
        name = "eps_state_%s" % state
        tagged = _console_bay() + _mass(aperture, splay, clamp)
        cores, saturation = _cores(state)
        report[name] = _finish(
            name, tagged, cores, saturation, STATE_BOX,
            "A single console bay of the 002-R bank. It stands against a "
            "Hub wall and may not overrun its bay.",
            {
                "batch": "024",
                "kind": "epsilon_presentation_state",
                "state": state,
                "means": STATE_MEANS[state],
                "emissive_saturation": saturation,
                "emissive_ceiling": SAT_CEILING,
                "human_half_emits": False,
                "aperture": aperture,
                "petal_splay": splay,
                "clamp": clamp,
                "recruits_dead_family": dead_plating,
                "runtime_signal_exists": state == "speaking",
                "integration_ready": False,
                "scale_basis": "proposal scale",
            })

    for stage in ("early", "middle", "late"):
        common.reset_scene()
        name = "eps_arc_%s" % stage
        mass, cores = _arc_mass(stage)
        # Which fronts the intrusion has taken out. Bay 3 is the right-hand
        # end, where the eruption starts; bay 0 keeps its front even at LATE
        # so the human machine is still identifiable as one.
        wrecked = {"early": (3,), "middle": (2, 3), "late": (1, 2, 3)}[stage]
        tagged = _bank(wrecked) + mass
        # Held CONSTANT across the three. The arc is extent, not brightness.
        report[name] = _finish(
            name, tagged, cores, 0.24, ARC_BOX,
            "Four bays of the bank against a Hub wall, with the intrusion "
            "at one extent of ownership.",
            {
                "batch": "024",
                "kind": "epsilon_presentation_arc",
                "stage": stage,
                "means": ARC_MEANS[stage],
                "emissive_saturation": 0.24,
                "read_is": "extent, not brightness -- emission is identical "
                           "across all three stages",
                "human_half_emits": False,
                "integration_ready": False,
                "scale_basis": "proposal scale",
            })

    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch024",
                       "epsilon", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")
    common.log("[batch024] %d assets -> %s" % (len(report), OUT))


if __name__ == "__main__":
    main()
