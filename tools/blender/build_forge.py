"""Batch 025 -- PROPOSAL: the Forge, and Questionable Goods.

PRESENTATION AND PHYSICAL IDENTITY ONLY. Nothing here designs the mechanical
implementation: not the cost, not the family rules, not what reinterpretation
does to an Echo, not whether a reforge can destroy a capability. Those are
Production's, and the research memo already has an open section on the last
one.

## The audit, read-only, against current Production

`claude/archipepsi-echoes-continuation-b1adno`.

**Questionable Goods HAS a home.** `godot/scripts/hub/hub_anchors.gd` lists
`"shop"` in `REQUIRED` -- commented `# QUESTIONABLE GOODS` -- at

    Vector3(-W / 2.0 + 1.6, 0, D * 0.15)   yaw -PI/2

which in the 22 x 16 x 5 m Hub is (-9.4, 0, 2.4), against the left wall,
facing across the room. The anchor carries a hard-won constraint in its own
comment: at `D * 0.45` the counter spanned z 6.0-8.4 while the Lab doorway
spans 4.5-7.5, so the shop stood in two thirds of the only way into the Echo
Lab and playtest 1 found the Lab unreachable. **So this asset is authored to
a real contract**: it is 3.0 m along the wall, centred on z = 2.4, spanning
z 0.9-3.9 -- clear of 4.5 with 0.6 m to spare.

**The Forge does NOT.** No anchor, no scene, no script, no constant. The only
mention anywhere in Production is `docs/design-packet-v0.10/RESEARCH_MEMO.md`
section 7, "The Forge, and the capability it might destroy", which is an open
design question rather than an implementation. So the Forge is authored at
proposal scale with no placement claim, and the missing anchor is recorded as
interface requirement 26 rather than invented here.

Note the Hub's left wall is already crowded: Epsilon's reserved bay sits at
the far end, the shop at z = 2.4, and the Lab doorway between them at
z 4.5-7.5. A Forge anchor is not a free choice and art is not making it.

**Epsilon Coins are SCARCE.** `EPSILON_COIN_COUNT = 10` in
`schemas/constants.py`: ten in an entire campaign. That is why the coin
receiver below is a single socket and not a hopper. A slot that looks like it
expects a handful would misprice the currency before the player spent one.

## The Forge is not a forge

The brief is explicit about what it must not be: not fantasy blacksmithing,
not a generic crafting table, not an MMO skill tree. What the operation
actually is:

    take a FOREIGN object, work out what it MEANS, take it apart,
    decide what it could mean instead within a requested family,
    and rebuild it as that.

So the machine is closer to an instrument than a workshop: an examination and
decomposition apparatus. And because the four verbs are SEQUENTIAL, the bench
is four stations in a line and the player can see where their object is.

| stage | what it looks like | why |
|---|---|---|
| ANALYSIS | a cradle under a scanning gantry; light points INWARD at the object | nothing is being changed yet, only read |
| DESTABILISATION | braced clamps, a containment ring, scorched plating | the one violent stage, and it looks like it |
| REINTERPRETATION | **a gap in the bench.** No mechanism at all -- only suspended light | the decision is Epsilon thinking, and Batch 024 already established that thinking is interior. A mechanism here would be a lie about where the work happens. |
| RECONSTRUCTION | a closing die and an output aperture | the new thing arrives, and it arrives from somewhere |

The empty third stage is the deliberate risk in this batch. It is also the
only honest answer: there is no machine that decides what something could
mean, and drawing one would make the Forge a factory.

## The selector is one dial, not a tree

Seven broad families -- ranged, melee, grapple, movement, defense, sustain,
utility -- and the player picks ONE before committing. Physically that is a
single seven-position rotary selector on the operator side, like the range
dial on a lab instrument. Seven detents, one pointer, one commit lever.

That is the opposite of a skill tree and it is period-correct: a 1998
facility instrument says "choose a range" with a dial, not a graph.

## Questionable Goods is the OPPOSITE KIND of object

Both are Epsilon-adjacent services in the same room, so they must coexist
without being confused. The distinction is not decoration, it is kind:

| | Forge | Questionable Goods |
|---|---|---|
| what it is | an apparatus | a counter |
| the process | **made visible** -- all four stages exposed | **made opaque** -- a shutter, a grille, stock you cannot inspect |
| what it works on | what you already own | what someone else has |
| its construction | fabricated for the job, coherent | improvised out of taken facility parts |
| its green | native -- it is Epsilon's own machine | hijacked -- borrowed light on scavenged hardware |

**Forge = process made visible. Questionable Goods = transaction made
opaque.** A player who learns that one sentence can tell them apart across a
dark room, from the silhouette alone, which is the actual requirement.
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

THEME = "concrete_facility"
OUT = "batch025/forge"

#: Inherited from 002-R and re-measured there: above this the green channel
#: pins and the core stops being a colour.
SAT_CEILING = 0.40

#: The Hub, from `hub_anchors.gd`. Read, never redefined.
HUB_W, HUB_D = 22.0, 16.0
SHOP_ANCHOR_Z = HUB_D * 0.15          # 2.4
LAB_DOOR_Z0, LAB_DOOR_Z1 = 4.5, 7.5   # the doorway the shop must not block

FORGE_BOX = (4.4, 2.2, 2.8)
QG_BOX = (3.4, 2.0, 3.0)

#: Seven broad families, in the order the owner named them. The dial has
#: seven detents because there are seven families, not because seven is a
#: nice number for a dial.
FAMILIES = ("ranged", "melee", "grapple", "movement",
            "defense", "sustain", "utility")


def _tag(objs, role):
    return [(o, role) for o in (objs if isinstance(objs, list) else [objs])]


# ----------------------------------------------------------------------
# The Forge
# ----------------------------------------------------------------------

BENCH_L = 3.60          # along X: the four stations run left to right
BENCH_D = 0.80
BENCH_H = 0.94          # the height you work at, matching 002-R's desk

#: Station centres along X. The gap at REINTERPRETATION is real geometry:
#: the bench top is absent there.
STATIONS = {
    "analysis": -1.35,
    "destabilisation": -0.45,
    "reinterpretation": 0.45,
    "reconstruction": 1.35,
}


def _forge_frame():
    """Bench, legs, and the spine the four stations hang off."""
    out = []
    # The top, in three pieces -- the reinterpretation station has NO top.
    # That gap is the point and it is built, not painted.
    for name, x0, x1 in (("top_a", -BENCH_L / 2, 0.0),
                         ("top_b", 0.90, BENCH_L / 2)):
        out += _tag(brushkit.block(name, (x1 - x0, BENCH_D, 0.08),
                                   ((x0 + x1) / 2, 0.0, BENCH_H)), "frame")
    for sx in (-1.0, 1.0):
        out += _tag(brushkit.block("leg_%d" % int(sx),
                                   (0.12, BENCH_D - 0.10, BENCH_H),
                                   (sx * (BENCH_L / 2 - 0.10), 0.0,
                                    BENCH_H / 2)), "frame")
    out += _tag(brushkit.block("kick", (BENCH_L, 0.10, 0.10),
                               (0.0, 0.30, 0.22)), "frame")
    # THE TRANSFER RAIL. The single thing that makes four fixtures read as
    # one process: a track the object travels along, entering at analysis
    # and leaving at reconstruction. Without it the bench is a table with
    # instruments on it, which is what the first render showed.
    #
    # It BRIDGES the reinterpretation gap on a pair of thin rails with no
    # bench under them, so the object crosses that station suspended --
    # which is the truest possible statement of what happens there.
    for sy in (-1.0, 1.0):
        out += _tag(brushkit.block("rail_%d" % int(sy),
                                   (BENCH_L + 0.24, 0.05, 0.05),
                                   (0.0, sy * 0.13, BENCH_H + 0.06)),
                    "instrument")
    for i in range(9):
        out += _tag(brushkit.block("tie_%d" % i, (0.05, 0.30, 0.03),
                                   (-BENCH_L / 2 + 0.10 + i * 0.45, 0.0,
                                    BENCH_H + 0.05)), "instrument")
    # Entry and exit mouths, so the run has a direction and an end.
    for sx, nm in ((-1.0, "entry"), (1.0, "exit")):
        out += _tag(brushkit.tube(nm, 0.20, 0.14, 0.10, 8,
                                  (sx * (BENCH_L / 2 + 0.14), 0.0,
                                   BENCH_H + 0.08)), "instrument")
    # The spine: a gantry beam over the whole run, so the four stations
    # read as ONE process rather than four unrelated fixtures.
    out += _tag(brushkit.block("spine", (BENCH_L + 0.30, 0.16, 0.14),
                               (0.0, 0.16, 2.12)), "frame")
    for sx in (-1.0, 1.0):
        out += _tag(brushkit.block("post_%d" % int(sx), (0.14, 0.16, 1.18),
                                   (sx * (BENCH_L / 2 + 0.08), 0.16,
                                    1.53)), "frame")
    return out


def _forge_stations(working):
    """The four stages. `working` puts an object mid-process."""
    out = []
    cores = []
    x = STATIONS["analysis"]
    # 1 -- ANALYSIS. A cradle, and a gantry that LOOKS at it. Two arcs, and
    # the light points inward at the object rather than out at the room.
    # The scanning head hangs from the SPINE and points DOWN at the rail.
    # The first pass used two closed rings at bench level, which looked
    # like the containment ring two stations along -- analysis and
    # destabilisation are opposite acts and must not share a silhouette.
    out += _tag(brushkit.block("head_mast", (0.10, 0.10, 0.62),
                               (x, 0.16, BENCH_H + 0.86)), "instrument")
    out += _tag(brushkit.block("head", (0.52, 0.34, 0.20),
                               (x, 0.02, BENCH_H + 0.52)), "instrument")
    out += _tag(brushkit.wedge("head_snout", (0.34, 0.24, 0.16),
                               (x, 0.0, BENCH_H + 0.36), axis="y"),
                "instrument")
    for i, sx in enumerate((-1.0, 1.0)):
        cores.append(brushkit.block("look_%d" % i, (0.035, 0.035, 0.04),
                                    (x + sx * 0.16, 0.0, BENCH_H + 0.32)))

    # 2 -- DESTABILISATION. Braced clamps and a containment ring. The one
    # violent station, and the only one with scorched plating.
    x = STATIONS["destabilisation"]
    for sy in (-1.0, 1.0):
        out += _tag(brushkit.wedge("clamp_%d" % int(sy), (0.30, 0.22, 0.30),
                                   (x, sy * 0.22, BENCH_H + 0.19),
                                   axis="y"), "scorched")
    out += _tag(brushkit.tube("containment", 0.30, 0.23, 0.16, 8,
                              (x, 0.0, BENCH_H + 0.46)), "scorched")
    for sx in (-1.0, 1.0):
        out += _tag(brushkit.block("brace_%d" % int(sx), (0.09, 0.09, 0.62),
                                   (x + sx * 0.34, 0.16,
                                    BENCH_H + 0.44)), "scorched")
    if working:
        cores.append(brushkit.prism("burst", 0.13, 0.20, 8,
                                    (x, 0.0, BENCH_H + 0.46), organic=True))

    # 3 -- REINTERPRETATION. NOTHING. The bench top is absent here and the
    # only thing in the gap is suspended light. Drawing a mechanism would
    # be a lie about where the decision happens.
    x = STATIONS["reinterpretation"]
    out += _tag(brushkit.tube("void_rim", 0.40, 0.34, 0.06, 8,
                              (x, 0.0, BENCH_H - 0.02)), "instrument")
    # A shaft under the gap. The first render could not tell the missing
    # bench top from a bench top in shadow, because absence photographs
    # exactly like darkness. A lined shaft you can see DOWN gives the hole
    # an inside, and an inside is what makes it read as a hole.
    for i, z in enumerate((0.22, 0.50)):
        out += _tag(brushkit.tube("shaft_%d" % i, 0.36 - 0.04 * i,
                                  0.30 - 0.04 * i, 0.16, 8,
                                  (x, 0.0, BENCH_H - z)), "instrument")
    if working:
        for i, z in enumerate((0.34, 0.52, 0.70)):
            cores.append(brushkit.block("suspended_%d" % i,
                                        (0.07, 0.07, 0.07),
                                        (x + 0.05 * (i - 1), 0.0,
                                         BENCH_H + z)))
    else:
        cores.append(brushkit.block("void_seed", (0.05, 0.05, 0.05),
                                    (x, 0.0, BENCH_H + 0.30)))

    # 4 -- RECONSTRUCTION. A closing die and the aperture the new thing
    # comes out of. It arrives from SOMEWHERE, which the output chute says.
    x = STATIONS["reconstruction"]
    for sy in (-1.0, 1.0):
        out += _tag(brushkit.block("die_%d" % int(sy), (0.42, 0.14, 0.34),
                                   (x, sy * (0.20 if working else 0.26),
                                    BENCH_H + 0.24)), "instrument")
    out += _tag(brushkit.tube("outlet", 0.24, 0.17, 0.20, 8,
                              (x, -0.30, BENCH_H + 0.24)), "instrument")
    out += _tag(brushkit.wedge("chute", (0.44, 0.34, 0.20),
                               (x, -0.44, BENCH_H - 0.06), axis="y"),
                "instrument")
    if working:
        cores.append(brushkit.block("formed", (0.10, 0.10, 0.12),
                                    (x, -0.30, BENCH_H + 0.24)))
    return out, cores


def _forge_controls(working):
    """The seven-position family selector, the coin socket, the lever.

    One dial. Seven detents because there are seven families. This is the
    whole control surface, and it is deliberately smaller than any one of
    the four stations -- the machine is mostly process, not interface.
    """
    out = []
    cores = []
    # Controls sit under ANALYSIS, not under reinterpretation. The first
    # pass centred them at x = 0.45, which put the raked operator plate
    # directly in front of the void -- hiding the one feature carrying
    # this batch's whole argument behind the one feature that is least
    # important. You set the dial before you commit, so the controls
    # belong at the ENTRY end anyway.
    cx, cy = -1.25, -0.52
    # The operator plate, raked toward the player.
    out += _tag(brushkit.wedge("plate", (1.30, 0.34, 0.14),
                               (cx + 0.10, cy, BENCH_H + 0.07), axis="y"),
                "instrument")
    # The dial: a drum with seven detent posts around it.
    out += _tag(brushkit.prism("dial", 0.17, 0.07, 8,
                               (cx, cy, BENCH_H + 0.17)), "instrument")
    for i in range(len(FAMILIES)):
        a = math.radians(-90.0 + i * (220.0 / (len(FAMILIES) - 1)))
        out += _tag(brushkit.block("detent_%d" % i, (0.035, 0.035, 0.05),
                                   (cx + 0.23 * math.cos(a),
                                    cy + 0.23 * math.sin(a),
                                    BENCH_H + 0.17)), "instrument")
    # The pointer, parked at detent 0 when idle and set when working.
    sel = 3 if working else 0
    a = math.radians(-90.0 + sel * (220.0 / (len(FAMILIES) - 1)))
    out += _tag(brushkit.block("pointer", (0.19, 0.04, 0.04),
                               (cx + 0.10 * math.cos(a),
                                cy + 0.10 * math.sin(a), BENCH_H + 0.22),
                               rotation_z=math.degrees(a)), "instrument")
    # ONE coin socket. Ten coins exist in a campaign; a hopper would
    # misprice the currency before the player spent one.
    out += _tag(brushkit.tube("coin_socket", 0.055, 0.032, 0.05, 8,
                              (cx - 0.52, cy, BENCH_H + 0.14)),
                "instrument")
    # Commit lever, thrown when working.
    out += _tag(brushkit.block("lever", (0.05, 0.05, 0.30),
                               (cx + 0.62, cy + 0.02, BENCH_H + 0.19)),
                "instrument")
    out += _tag(brushkit.block("lever_head", (0.09, 0.09, 0.07),
                               (cx + 0.62, cy + (0.20 if working else 0.02),
                                BENCH_H + (0.24 if working else 0.34))),
                "instrument")
    if working:
        cores.append(brushkit.block("armed", (0.05, 0.05, 0.03),
                                    (cx, cy, BENCH_H + 0.21)))
    return out, cores


# ----------------------------------------------------------------------
# Questionable Goods
# ----------------------------------------------------------------------

QG_L = 3.00     # along the wall (Hub z). Centred on the shop anchor at
                # z = 2.4 this spans 0.9-3.9, clear of the Lab doorway.
QG_D = 0.90
QG_H = 2.40


def _qg_counter():
    """A counter, not a machine. Improvised from taken facility parts.

    Everything here says TRANSACTION and nothing says PROCESS: a service
    hatch you are served through, a shutter that comes down, a grille you
    can see stock behind but not reach, and a stack of crates that arrived
    from somewhere and are not going to be explained.
    """
    out = []
    cores = []
    # The counter mass, and the worn top somebody leans on.
    out += _tag(brushkit.block("counter", (QG_L, QG_D, 1.02),
                               (0.0, 0.0, 0.51)), "scavenged")
    out += _tag(brushkit.block("counter_top", (QG_L + 0.14, QG_D + 0.12, 0.07),
                               (0.0, -0.04, 1.06)), "scavenged")
    # The back wall of the stall, and the shelf of stock behind mesh.
    # Backboard stops BELOW the shutter head, so the stall has a visible
    # opening rather than one continuous face.
    out += _tag(brushkit.block("backboard", (QG_L, 0.12, QG_H - 0.50),
                               (0.0, 0.40, (QG_H - 0.50) / 2)), "scavenged")
    out += _tag(brushkit.grate("mesh", (QG_L - 0.30, 0.05, 0.86), 9, 0.035,
                               (0.0, 0.30, 1.72), axis="x"), "shut")
    for i, x in enumerate((-0.90, -0.30, 0.34, 0.92)):
        out += _tag(brushkit.block("stock_%d" % i,
                                   (0.34, 0.22, 0.20 + 0.06 * (i % 3)),
                                   (x, 0.38, 1.44 + 0.02 * i)), "shut")
    # The SHUTTER -- half down. The single clearest statement that this is
    # a transaction you are admitted to rather than a process you watch.
    out += _tag(brushkit.block("shutter", (QG_L - 0.10, 0.06, 0.62),
                               (0.0, -0.14, QG_H - 0.31)), "shut")
    for i in range(5):
        out += _tag(brushkit.block("slat_%d" % i, (QG_L - 0.16, 0.08, 0.09),
                                   (0.0, -0.16, QG_H - 0.64 + 0.13 * i)),
                    "shut")
    # The service hatch you are actually served through: small, low, one
    # person wide. You do not get to see past it.
    out += _tag(brushkit.tube("hatch", 0.26, 0.20, 0.12, 8,
                              (0.62, -0.10, 1.42)), "shut")
    # Crates on the floor. Arrived from elsewhere; not explained.
    for i, (x, r) in enumerate(((-1.18, 12.0), (-0.86, -21.0), (1.24, 7.0))):
        out += _tag(brushkit.block("crate_%d" % i, (0.46, 0.44, 0.38),
                                   (x, -0.62, 0.19 + (0.38 if i == 1 else 0)),
                                   rotation_z=r), "scavenged")
    # HIJACKED light: a tapped conduit running in from off-stall, and two
    # small cores. Epsilon's green is here, but it was brought, not built.
    out += _tag(brushkit.sweep("tap", [(-QG_L / 2 - 0.30, 0.34, QG_H - 0.10),
                                       (-QG_L / 2 + 0.40, 0.32, QG_H - 0.22),
                                       (-0.20, 0.30, QG_H - 0.30)],
                               0.07, 0.06), "scavenged")
    cores.append(brushkit.block("tap_core", (0.05, 0.05, 0.12),
                                (-0.20, 0.26, QG_H - 0.30)))
    cores.append(brushkit.block("hatch_core", (0.04, 0.04, 0.04),
                                (0.62, -0.16, 1.42)))
    return out, cores


# ----------------------------------------------------------------------

def _finish(name, tagged, cores, saturation, box, why, entry):
    buckets = {}
    for obj, role in tagged:
        buckets.setdefault(role, []).append(obj)

    painted = []
    specs = [
        ("frame", propkit.machine_bank(THEME, name + "_frame", "panel"),
         propkit.PROP_DENSITY, propkit.PROP_SIZE, None),
        ("instrument", propkit.machine_bank(THEME, name + "_inst", "console"),
         propkit.PROP_DENSITY, propkit.PROP_SIZE, None),
        # The violent station wears the alien skin: destabilisation is the
        # stage Epsilon does TO the object, and it should not look like
        # facility hardware doing facility work.
        ("scorched", propkit.alien_shell(THEME, name + "_hot"),
         propkit.HERO_DENSITY, propkit.HERO_SIZE, 0.55),
        # `facility_host`, not painted metal. The first render came back as
        # clean pale sheet steel -- a NEW counter, which is the exact
        # opposite of a stall improvised out of parts taken from the
        # building. It also flattened the shutter, the mesh and the stock
        # into one bright slab, because everything shared one bright value.
        ("scavenged", propkit.bare_metal(THEME, name + "_scav", wear=0.46),
         propkit.PROP_DENSITY, propkit.PROP_SIZE, None),
        # The closed-off half gets its own darker treatment so the shutter,
        # the mesh and the stock behind it separate from the counter you
        # are actually served at. Opacity is the whole idea; it has to read.
        ("shut", propkit.machine_bank(THEME, name + "_shut", "panel"),
         propkit.PROP_DENSITY, propkit.PROP_SIZE, None),
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
        "%s asks %.2f; 0.40 is the measured ceiling" % (name, saturation))
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

    for working in (False, True):
        common.reset_scene()
        name = "forge_bench_working" if working else "forge_bench"
        stations, s_cores = _forge_stations(working)
        controls, c_cores = _forge_controls(working)
        tagged = _forge_frame() + stations + controls
        report[name] = _finish(
            name, tagged, s_cores + c_cores,
            0.30 if working else 0.12, FORGE_BOX,
            "A Hub-scale operator apparatus. Proposal scale: no Forge "
            "anchor exists (interface requirement 26).",
            {
                "batch": "025",
                "kind": "forge",
                "state": "working" if working else "idle",
                "stations": list(STATIONS),
                "station_x_m": STATIONS,
                "families": list(FAMILIES),
                "selector": "one seven-position rotary, not a tree",
                "coin_sockets": 1,
                "coin_sockets_why": "EPSILON_COIN_COUNT is 10 for a whole "
                                    "campaign; a hopper would misprice it",
                "reinterpretation_is_empty": True,
                "reinterpretation_why": "the decision is Epsilon thinking; "
                                        "a mechanism there would be a lie "
                                        "about where the work happens",
                "emissive_saturation": 0.30 if working else 0.12,
                "reads_as": "process made visible",
                "hub_anchor": None,
                "integration_ready": False,
                "scale_basis": "proposal scale",
            })

    common.reset_scene()
    qg, qg_cores = _qg_counter()
    report["qg_counter"] = _finish(
        "qg_counter", qg, qg_cores, 0.16, QG_BOX,
        "Stands on the Hub's `shop` anchor and must not reach the Lab "
        "doorway at z 4.5-7.5.",
        {
            "batch": "025",
            "kind": "questionable_goods",
            "reads_as": "transaction made opaque",
            "distinct_from_forge_by": "kind, not decoration -- a counter "
                                      "rather than an apparatus, with the "
                                      "process hidden rather than exposed",
            "green_is": "hijacked, not native -- tapped in on scavenged "
                        "hardware",
            "hub_anchor": "shop",
            "hub_anchor_pos_m": [-HUB_W / 2.0 + 1.6, 0.0, SHOP_ANCHOR_Z],
            "hub_anchor_yaw_deg": -90.0,
            "wall_run_m": QG_L,
            "occupies_hub_z_m": [SHOP_ANCHOR_Z - QG_L / 2.0,
                                 SHOP_ANCHOR_Z + QG_L / 2.0],
            "lab_doorway_z_m": [LAB_DOOR_Z0, LAB_DOOR_Z1],
            "clearance_to_lab_doorway_m": round(
                LAB_DOOR_Z0 - (SHOP_ANCHOR_Z + QG_L / 2.0), 2),
            "emissive_saturation": 0.16,
            "integration_ready": False,
            "scale_basis": "proposal scale",
        })

    # The constraint that cost a playtest. Asserted, not just documented.
    far = SHOP_ANCHOR_Z + QG_L / 2.0
    assert far < LAB_DOOR_Z0, (
        "qg_counter reaches z=%.2f and the Lab doorway starts at %.2f; this "
        "is exactly the overlap that made the Lab unreachable in playtest 1"
        % (far, LAB_DOOR_Z0))

    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch025",
                       "forge", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")
    common.log("[batch025] %d assets -> %s" % (len(report), OUT))


if __name__ == "__main__":
    main()
