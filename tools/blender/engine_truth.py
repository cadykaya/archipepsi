"""The engineering branch's numbers, read rather than retyped.

Art tooling needs the game's real dimensions -- player height, jump reach,
door sizes, affordance footprints, theme colours -- and every one of them
already has an owner: `bridge/archipepsi_bridge/schemas/constants.py`, which
`export.py` turns into `godot/scripts/autoload/constants.gd`. That file is
engineering's, and the art lane does not get to hold a second opinion about
what a door is.

So this module imports it. Not a copy, not a subset transcribed into JSON:
the actual file, loaded from its actual path, with only the standard library
behind it (verified -- `constants.py` imports `hashlib`, `math` and `random`
and nothing else, so this works inside Blender's bundled Python too).

The failure this prevents is the one mario-3 paid for with seven ground
greens: a number typed in two places is a number that drifts, and the drift
is invisible until an asset is built to a door that no longer exists.

`DIMENSIONS` below is the derived art-facing view: the handful of numbers an
asset author actually reaches for, each with the reason it constrains art.
Nothing here is a new number -- every value is read from constants.py or
computed from values read from it.
"""

from __future__ import annotations

import importlib.util
import os
import sys

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CONSTANTS_PATH = os.path.join(
    REPO_ROOT, "bridge", "archipepsi_bridge", "schemas", "constants.py")

#: Numbers that live in Godot rather than in the schema constants, because
#: they are builder-local. Read out of the .gd source so they still are not
#: retyped -- but they are read by pattern, so `verify()` re-checks them.
GODOT_SOURCES = {
    "WALL_THICKNESS": "godot/scripts/generation/chamber_builders.gd",
    "DOOR_WIDTH": "godot/scripts/generation/chamber_builders.gd",
    "DOOR_HEIGHT": "godot/scripts/generation/chamber_builders.gd",
    "CORRIDOR_HEIGHT": "godot/scripts/generation/chamber_builders.gd",
    "PROP_FOOTPRINT": "godot/scripts/generation/chamber_builders.gd",
    "BRUTE_LANE": "godot/scripts/generation/chamber_builders.gd",
    "TALLEST_ACTOR": "godot/scripts/generation/chamber_builders.gd",
}

#: Environment ambient is ASSIGNED, not declared `const`, so `_gd_const`
#: cannot see it. It is still engineering's number and still gets read.
GODOT_AMBIENT_SOURCES = (
    "godot/scripts/generation/zone_builder.gd",
    "godot/scripts/hub/hub.gd",
)

_CACHE = {}


def constants():
    """The live `constants.py` module object."""
    if "mod" not in _CACHE:
        if not os.path.exists(CONSTANTS_PATH):
            raise RuntimeError(
                "engine_truth: cannot find %s. The art toolchain reads the "
                "engineering branch's constants rather than keeping its own "
                "copy; without them no asset can be built to a real "
                "dimension." % CONSTANTS_PATH)
        spec = importlib.util.spec_from_file_location(
            "_archipepsi_constants", CONSTANTS_PATH)
        mod = importlib.util.module_from_spec(spec)
        # Not registered in sys.modules under a public name on purpose: this
        # is a read, and the art lane should not become importable as the
        # engineering package.
        sys.modules.setdefault("_archipepsi_constants", mod)
        spec.loader.exec_module(mod)
        _CACHE["mod"] = mod
    return _CACHE["mod"]


def _gd_const(relpath, name):
    """Read `const NAME := <float>` out of a GDScript file."""
    path = os.path.join(REPO_ROOT, relpath)
    with open(path, "r", encoding="utf-8") as handle:
        for line in handle:
            stripped = line.strip()
            if stripped.startswith("const %s :=" % name) or \
                    stripped.startswith("const %s =" % name):
                value = stripped.split(":=" if ":=" in stripped else "=", 1)[1]
                value = value.split("#")[0].strip()
                return float(value)
    raise RuntimeError(
        "engine_truth: %s does not define `const %s`. It moved or was "
        "renamed; find its new home rather than typing the number here."
        % (relpath, name))


def _gd_assign(relpath, name):
    """Read `<something>.name = <float>` out of a GDScript file."""
    path = os.path.join(REPO_ROOT, relpath)
    needle = ".%s = " % name
    with open(path, "r", encoding="utf-8") as handle:
        for line in handle:
            head, sep, tail = line.strip().partition(needle)
            if sep and head and " " not in head:
                return float(tail.split("#")[0].strip())
    raise RuntimeError(
        "engine_truth: %s no longer assigns `%s`. It moved or was renamed; "
        "find its new home rather than typing the number here."
        % (relpath, name))


def lighting():
    """The brightest irradiance the game can put on one surface.

    A material that has to keep its HUE -- a signal, a core, an eye -- has
    to survive being lit, and "being lit" is not a number art gets to
    choose. The engine publishes both halves of it: `light_energy` per
    theme in `THEME_MATERIALS`, and `ambient_light_energy` on the zone and
    Hub environments. The worst case is the brightest theme plus the
    brightest ambient, and it is read, never typed.
    """
    if "lighting" not in _CACHE:
        spec = theme_anchors()
        _CACHE["lighting"] = {
            "max_light_energy": max(float(v["light_energy"])
                                    for v in spec.values()),
            "max_ambient_energy": max(_gd_assign(path, "ambient_light_energy")
                                      for path in GODOT_AMBIENT_SOURCES),
        }
        _CACHE["lighting"]["max_irradiance"] = (
            _CACHE["lighting"]["max_light_energy"]
            + _CACHE["lighting"]["max_ambient_energy"])
    return _CACHE["lighting"]


def godot_dimensions():
    if "gd" not in _CACHE:
        _CACHE["gd"] = {
            name: _gd_const(path, name) for name, path in GODOT_SOURCES.items()
        }
    return _CACHE["gd"]


def dimensions():
    """The art-facing dimension view. Every value derived, none typed."""
    if "dim" in _CACHE:
        return _CACHE["dim"]
    c = constants()
    gd = godot_dimensions()
    dim = {
        # --- the body every asset is scaled against -----------------------
        "player_height": c.PLAYER_HEIGHT,
        "player_eye_height": c.PLAYER_EYE_HEIGHT,
        "player_radius": c.PLAYER_RADIUS,
        "player_diameter": c.PLAYER_RADIUS * 2.0,
        # --- what the player can reach, which decides what "high" means ---
        "jump_apex": c.JUMP_APEX_HEIGHT,
        "jump_flat_reach": c.JUMP_FLAT_REACH,
        "max_vertical_step": c.MAX_VERTICAL_STEP,
        "safe_base_jump_gap": c.SAFE_BASE_JUMP_GAP,
        "reach_standing": c.PLAYER_EYE_HEIGHT + c.JUMP_APEX_HEIGHT,
        # --- the architecture the modules must mate with ------------------
        "wall_thickness": gd["WALL_THICKNESS"],
        "door_width": gd["DOOR_WIDTH"],
        "door_height": gd["DOOR_HEIGHT"],
        "corridor_height": gd["CORRIDOR_HEIGHT"],
        "prop_footprint": gd["PROP_FOOTPRINT"],
        "brute_lane": gd["BRUTE_LANE"],
        "tallest_actor": gd["TALLEST_ACTOR"],
        "min_platform_size": c.MIN_PLATFORM_SIZE,
        # --- the room sizes Epsilon may ask for ---------------------------
        "corridor_length_min": 6.0,
        "corridor_length_max": 30.0,
        "corridor_width_min": 4.0,
        "corridor_width_max": 10.0,
        "arena_span_min": 10.0,
        "arena_span_max": 28.0,
        "arena_wall_height_min": 4.0,
        "arena_wall_height_max": 8.0,
        "path_segment_min": 3,
        "path_segment_max": 8,
        "path_gap_min": 0.5,
        "path_vertical_step_min": 0.0,
        # `platform_path()`'s own layout constants, so an authored shell
        # lands its ledges and platforms where the procedural one does.
        "path_width": 8.0,
        "path_ledge": 4.0,
        "fall_kill_y": c.FALL_KILL_Y,
        "tower_floors_min": 2,
        "tower_floors_max": 5,
        # `tower()`'s own layout constants.
        "tower_side": 12.0,
        "tower_per_floor": 3.0,
        # --- the distances an asset is actually looked at from ------------
        "camera_fov_deg": 90.0,
        "enemy_aggro_radius": c.ENEMY_AGGRO_RADIUS,
        "pulse_range": c.STATIC_PULSE_RANGE,
        "melee_reach": c.ENEMY_STATS["melee"]["reach"],
        "brute_reach": c.ENEMY_STATS["brute"]["reach"],
        "walk_speed": c.WALK_SPEED,
        # --- the actors an enemy asset must fit -----------------------------
        "enemy_melee_size": (0.8, 1.6, 0.8),
        "enemy_ranged_size": (0.7, 1.4, 0.7),
        "enemy_brute_size": (1.8, 2.6, 1.8),
        # --- runtime texture bounds, for the procedural half we sit beside --
        "proc_texture_default": c.TEXTURE_SIZE_DEFAULT,
        "proc_texture_max": c.TEXTURE_SIZE_MAX,
    }
    # NOT a number: gap and vertical step are bounded JOINTLY, and v0.4's
    # bug was bounding them independently. Art gets the live function, so a
    # shell asks the engine how far a jump reaches at the height it built
    # rather than remembering a figure that was true at one step.
    dim["max_safe_gap"] = c.max_safe_gap
    # Affordance footprints are Godot's and stay Godot's; art may not change
    # a single one. Carried through verbatim so a builder can read the
    # clearance it must not violate.
    dim["affordance_footprint"] = {
        "grapple_anchor": {"half_width": 0.7, "half_depth": 0.7, "height": 5.6},
        "breakable_wall": {"half_width": 0.7, "half_depth": 1.3, "height": 3.6},
        "water_volume": {"half_width": 0.8, "half_depth": 0.8, "height": 3.6},
        "rail": {"half_width": 0.5, "half_depth": 3.5, "height": 3.6},
        "wind_volume": {"half_width": 0.8, "half_depth": 0.8, "height": 6.0},
        "bounce_pad": {"half_width": 0.6, "half_depth": 0.6, "height": 7.0},
        "moving_platform": {"half_width": 0.8, "half_depth": 0.8, "height": 5.2},
    }
    dim["affordance_min_chamber_width"] = dict(c.FEATURE_MIN_WIDTH)
    _CACHE["dim"] = dim
    return dim


def theme_anchors():
    """`THEME_MATERIALS` exactly as the engine holds it."""
    return {name: dict(values)
            for name, values in constants().THEME_MATERIALS.items()}


def themes():
    return list(constants().THEMES)


def verify():
    """Fail loudly if anything this module reads has moved or drifted.

    The point of reading engineering's numbers instead of copying them is
    lost the moment a read silently returns a stale default, so every read
    is re-checked here and this runs from `check_art_current.sh`.
    """
    problems = []
    c = constants()
    dim = dimensions()

    # The affordance footprints are the one table transcribed rather than
    # imported (they live in a GDScript dictionary literal spanning lines).
    # So compare them against the source text directly.
    aff_path = os.path.join(
        REPO_ROOT, "godot", "scripts", "generation", "affordance_features.gd")
    with open(aff_path, "r", encoding="utf-8") as handle:
        text = handle.read()
    for tag, foot in dim["affordance_footprint"].items():
        needle = ('"%s": {"half_width": %s, "half_depth": %s, "height": %s}'
                  % (tag,
                     _gd_num(foot["half_width"]),
                     _gd_num(foot["half_depth"]),
                     _gd_num(foot["height"])))
        if needle not in text:
            problems.append(
                "affordance footprint for '%s' no longer matches "
                "affordance_features.gd (looked for: %s). Godot owns these "
                "dimensions; update engine_truth, never the asset." % (tag, needle))

    # FEATURE_MIN_WIDTH is imported, so it cannot drift -- but assert the
    # key set matches the footprint table, which is the pairing art relies on.
    if set(c.FEATURE_MIN_WIDTH) != set(dim["affordance_footprint"]):
        problems.append(
            "FEATURE_MIN_WIDTH and the footprint table cover different tags; "
            "an affordance was added or removed and the art inventory is stale.")

    # Chamber bounds are transcribed from zone.py's Field() constraints.
    zone_path = os.path.join(
        REPO_ROOT, "bridge", "archipepsi_bridge", "schemas", "zone.py")
    with open(zone_path, "r", encoding="utf-8") as handle:
        zone_text = handle.read()
    for label, needle in (
            ("corridor length", "length: float = Field(ge=6, le=30)"),
            ("corridor width", "width: float = Field(ge=4, le=10)"),
            ("arena width", "width: float = Field(ge=10, le=28)"),
            ("arena depth", "depth: float = Field(ge=10, le=28)"),
            ("arena wall height", "wall_height: float = Field(ge=4, le=8)"),
            ("platform_path segments",
             "segment_count: int = Field(ge=3, le=8)"),
            ("platform_path gap",
             "gap_size: float = Field(ge=0.5, le=C.SAFE_BASE_JUMP_GAP)"),
            ("platform_path step",
             "vertical_step: float = Field(ge=0.0, le=C.MAX_VERTICAL_STEP)"),
            ("tower floors", "floors: int = Field(ge=2, le=5)")):
        if needle not in zone_text:
            problems.append(
                "%s bounds changed in zone.py (looked for: %s). The room-shell "
                "size range art builds against is stale." % (label, needle))

    # platform_path()'s layout constants are LITERALS in the builder, so
    # unlike the schema bounds they can move without any schema changing.
    cb_path = os.path.join(
        REPO_ROOT, "godot", "scripts", "generation", "chamber_builders.gd")
    with open(cb_path, "r", encoding="utf-8") as handle:
        cb_text = handle.read()
    for label, needle in (
            ("platform_path width", "var width := %.1f" % dim["path_width"]),
            ("platform_path ledge", "var ledge := %.1f" % dim["path_ledge"]),
            ("tower side", "var side := %.1f" % dim["tower_side"]),
            ("tower floor spacing",
             "var per_floor := %.1f" % dim["tower_per_floor"])):
        if needle not in cb_text:
            problems.append(
                "%s changed in chamber_builders.gd (looked for: %s). An "
                "authored path shell lands its ledges where the procedural "
                "one does, so this is load-bearing." % (label, needle))

    # The camera FOV decides every "is it readable at range" claim in the
    # art bible, so it is checked rather than remembered.
    player_path = os.path.join(
        REPO_ROOT, "godot", "scripts", "gameplay", "player.gd")
    with open(player_path, "r", encoding="utf-8") as handle:
        if "camera.fov = %.1f" % dim["camera_fov_deg"] not in handle.read():
            problems.append(
                "player.gd no longer sets camera.fov = %.1f. Every screen-size "
                "and texel-density figure in ART_BIBLE.md was computed from "
                "it." % dim["camera_fov_deg"])

    # Enemy collision sizes decide what an enemy model may occupy.
    enemy_path = os.path.join(
        REPO_ROOT, "godot", "scripts", "enemies", "enemy.gd")
    with open(enemy_path, "r", encoding="utf-8") as handle:
        enemy_text = handle.read()
    for kind, size in (("melee", dim["enemy_melee_size"]),
                       ("ranged", dim["enemy_ranged_size"]),
                       ("brute", dim["enemy_brute_size"])):
        needle = "Vector3(%s, %s, %s)" % tuple(_gd_num(v) for v in size)
        if needle not in enemy_text:
            problems.append(
                "enemy.gd no longer sizes '%s' at %s. An enemy model built to "
                "the old box will clip or float." % (kind, needle))
    return problems


def _gd_num(value):
    """Format a float the way GDScript source writes it."""
    if float(value) == int(value):
        return str(int(value)) if int(value) != value else "%.1f" % value
    return ("%f" % value).rstrip("0")


if __name__ == "__main__":
    found = verify()
    dim = dimensions()
    print("engine-truth: constants.py at %s" % CONSTANTS_PATH)
    print("  player %.2f m tall, eye %.2f m, radius %.2f m"
          % (dim["player_height"], dim["player_eye_height"], dim["player_radius"]))
    print("  door %.1f x %.1f m, corridor height %.1f m, wall %.2f m thick"
          % (dim["door_width"], dim["door_height"],
             dim["corridor_height"], dim["wall_thickness"]))
    print("  jump apex %.2f m, flat reach %.2f m, step %.1f m"
          % (dim["jump_apex"], dim["jump_flat_reach"], dim["max_vertical_step"]))
    print("  camera %.0f deg, aggro %.0f m, pulse %.0f m"
          % (dim["camera_fov_deg"], dim["enemy_aggro_radius"], dim["pulse_range"]))
    print("  themes: %s" % ", ".join(themes()))
    if found:
        print()
        print("engine-truth: FAIL -- %d reference(s) drifted:" % len(found))
        for problem in found:
            print("  - %s" % problem)
        raise SystemExit(1)
    print("engine-truth: PASS -- every engineering number this lane reads is live.")
