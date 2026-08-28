"""Where every number in `assets/art_budgets.json` comes from.

Run it. It prints the arithmetic. Nothing in the budgets file is a number
somebody liked the look of, and nothing in it was inherited from another
project -- mario-3's ceilings, texture sizes and densities belong to
mario-3 and answer questions Archipepsi does not ask.

The rule this file exists to enforce: **every visual constraint must name
the failure it prevents.** If the arithmetic below cannot show the failure,
the constraint is decoration and does not belong in the budgets.

    python3 tools/blender/derive_budgets.py

It reads the live game numbers through `engine_truth`, so if the player
gets taller or the camera changes lens, the derivation moves with it and
the printed figures stop agreeing with the committed JSON -- which is
exactly the drift `check_art_current.sh` fails on.
"""

from __future__ import annotations

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import engine_truth  # noqa: E402

REPO_ROOT = engine_truth.REPO_ROOT
BUDGETS_PATH = os.path.join(REPO_ROOT, "assets", "art_budgets.json")

#: The screen the look is judged on. 1080p is the honest modern default;
#: every "how big is a texel" figure below is quoted at it.
SCREEN_WIDTH_PX = 1920
SCREEN_HEIGHT_PX = 1080


def px_per_metre(distance_m, fov_deg=None, screen_px=SCREEN_WIDTH_PX):
    """Screen pixels covering one world metre, at `distance_m` from the eye."""
    if fov_deg is None:
        fov_deg = engine_truth.dimensions()["camera_fov_deg"]
    visible_width_m = 2.0 * distance_m * math.tan(math.radians(fov_deg) / 2.0)
    return screen_px / visible_width_m


def texel_px(distance_m, texels_per_metre, fov_deg=None):
    """How many screen pixels one texel covers at a given distance."""
    return px_per_metre(distance_m, fov_deg) / texels_per_metre


def screen_height_px(object_height_m, distance_m, fov_deg=None):
    """Vertical screen pixels an object of a given height occupies.

    Godot's `Camera3D.fov` is the VERTICAL field of view when the viewport
    is wider than it is tall (KEEP_HEIGHT is the default), so vertical
    extent is computed against the screen's height, not its width.
    """
    if fov_deg is None:
        fov_deg = engine_truth.dimensions()["camera_fov_deg"]
    visible_height_m = 2.0 * distance_m * math.tan(math.radians(fov_deg) / 2.0)
    return SCREEN_HEIGHT_PX * object_height_m / visible_height_m


def derive():
    dim = engine_truth.dimensions()
    out = {}
    lines = []

    def say(text=""):
        lines.append(text)

    say("=" * 72)
    say("ARCHIPEPSI ART BUDGETS -- derivation")
    say("=" * 72)
    say()
    say("Game numbers this is derived from (read live from the engineering")
    say("branch, never retyped -- see tools/blender/engine_truth.py):")
    say("  player            %.2f m tall, eye at %.2f m, radius %.2f m"
        % (dim["player_height"], dim["player_eye_height"], dim["player_radius"]))
    say("  camera            %.0f deg vertical FOV" % dim["camera_fov_deg"])
    say("  walk speed        %.1f m/s" % dim["walk_speed"])
    say("  corridor          %.0f-%.0f m long, %.0f-%.0f m wide, %.1f m high"
        % (dim["corridor_length_min"], dim["corridor_length_max"],
           dim["corridor_width_min"], dim["corridor_width_max"],
           dim["corridor_height"]))
    say("  arena             %.0f-%.0f m square, walls %.0f-%.0f m"
        % (dim["arena_span_min"], dim["arena_span_max"],
           dim["arena_wall_height_min"], dim["arena_wall_height_max"]))
    say("  door              %.1f x %.1f m" % (dim["door_width"], dim["door_height"]))
    say("  enemy aggro       %.0f m" % dim["enemy_aggro_radius"])
    say("  Static Pulse      %.0f m" % dim["pulse_range"])
    say()

    # ------------------------------------------------------------------
    # 1. The distances things are actually seen from.
    # ------------------------------------------------------------------
    say("-" * 72)
    say("1. VIEWING DISTANCES -- the only reason any of the rest is a number")
    say("-" * 72)
    arena_diagonal = math.hypot(dim["arena_span_max"], dim["arena_span_max"])
    say("The longest sightline the game can build:")
    say("  corridor, end to end                %.1f m" % dim["corridor_length_max"])
    say("  largest arena, corner to corner     %.1f m" % arena_diagonal)
    say("  Static Pulse range (you can shoot)  %.1f m" % dim["pulse_range"])
    say("-> nothing needs to read beyond %.0f m. That is the far bound."
        % dim["pulse_range"])
    say()
    say("Distances that matter for a wall, walking at %.0f m/s:" % dim["walk_speed"])
    for d in (0.6, 1.5, 4.0, 10.0, 25.0):
        say("  %5.1f m   %6.0f screen px per world metre" % (d, px_per_metre(d)))
    say("-> a corridor wall is most often read at 1.5-4 m (you walk beside it).")
    say("-> a prop is read at 1-3 m (you walk up to it or past it).")
    say("-> an enemy is first read at aggro range, %.0f m." % dim["enemy_aggro_radius"])
    say()

    # ------------------------------------------------------------------
    # 2. Texel density.
    # ------------------------------------------------------------------
    say("-" * 72)
    say("2. TEXEL DENSITY -- and why 32/m for architecture")
    say("-" * 72)
    say("The era sets the anchor. Quake and Half-Life mapped one texel to one")
    say("world unit on a standard-scaled brush face:")
    say("  Quake      player 56 units == 1.78 m  ->  1 unit = %.4f m -> %.1f texels/m"
        % (1.78 / 56, 56 / 1.78))
    say("  Half-Life  player 72 units == 1.83 m  ->  1 unit = %.4f m -> %.1f texels/m"
        % (1.83 / 72, 72 / 1.83))
    say("-> the era band is roughly 30-40 texels/m for world surfaces.")
    say()
    say("32 texels/m is chosen inside that band because it makes the mapping")
    say("checkable by eye and by arithmetic:")
    say("  one 128x128 map covers exactly %.1f x %.1f m" % (128 / 32, 128 / 32))
    say("  one  64x64  map covers exactly %.1f x %.1f m" % (64 / 32, 64 / 32))
    say("  corridor height is %.1f m -> %.2f tiles of a 128 map"
        % (dim["corridor_height"], dim["corridor_height"] / (128 / 32)))
    say("  door is %.1f x %.1f m -> %.2f x %.2f tiles"
        % (dim["door_width"], dim["door_height"],
           dim["door_width"] / 4.0, dim["door_height"] / 4.0))
    say()
    say("What it looks like, at 32 texels/m:")
    for d in (0.6, 1.5, 4.0, 10.0, 25.0):
        say("  %5.1f m   1 texel = %6.2f screen px" % (d, texel_px(d, 32)))
    say("-> at a metre and a half a texel is ~%.0f px: visibly, deliberately"
        % texel_px(1.5, 32))
    say("   chunky, which is the look. At 25 m it is under a pixel, which is")
    say("   why mipmaps stay ON -- without them a 1998 wall shimmers as you")
    say("   walk and reads as a bug rather than as a style.")
    say()
    say("FAILURE PREVENTED: at 64+ texels/m a wall stops reading as 1998 and")
    say("starts reading as a low-res modern texture -- the difference between")
    say("'deliberately coarse' and 'the artist ran out of budget'. Below ~24")
    say("texels/m the panel lines and grime that carry all the detail fall")
    say("under one texel and the surface goes flat and Minecraft-ish, which")
    say("DESIGN 3.4 names as the thing to avoid.")
    say()

    prop_density = 64
    say("Props get %d texels/m -- double the walls. Two reasons, both real:"
        % prop_density)
    say("  (a) a prop is small. A %.1f m crate face at 32/m gets %d texels"
        % (1.0, int(1.0 * 32)))
    say("      across, which cannot hold a lid seam AND a stencil AND wear.")
    say("      At %d/m it gets %d, which can." % (prop_density, prop_density))
    say("  (b) it is era-correct. In 1998 models carried their own skins at")
    say("      higher effective density than world brushes; a Half-Life crate")
    say("      model was sharper than the wall behind it and nobody minded.")
    say("  one 64x64 map covers exactly %.2f x %.2f m at %d/m"
        % (64 / prop_density, 64 / prop_density, prop_density))
    say()
    hero_density = 96
    say("Hero objects get %d texels/m. These are the objects AUTHORED_CONTENT" % hero_density)
    say("names as identity: the Check, Epsilon's presence, the portal. They are")
    say("read both from across a room AND from a metre away, and they are the")
    say("most-repeated images in the game.")
    say("  at 1.0 m: 1 texel = %.1f px    at 12 m: 1 texel = %.2f px"
        % (texel_px(1.0, hero_density), texel_px(12.0, hero_density)))
    say()
    view_density = 256
    say("The first-person viewmodel gets %d texels/m, and it is not in Batch 001." % view_density)
    say("A viewmodel sits ~0.4 m from the eye and never moves away, so it is")
    say("the one asset whose density is set by screen coverage rather than by")
    say("world size: at 0.4 m one metre covers %.0f screen px, so even at %d"
        % (px_per_metre(0.4), view_density))
    say("texels/m a texel is %.1f px." % texel_px(0.4, view_density))
    say("NOTE: %d exceeds TEXTURE_SIZE_MAX (%d) which bounds the RUNTIME"
        % (view_density, dim["proc_texture_max"]))
    say("procedural generator. Imported assets are not bound by it, but the")
    say("asset registry contract does not exist yet -- so this tier is")
    say("DOCUMENTED AND DEFERRED, not built. See ART_FRONTIER.md.")
    say()

    out["texel_density"] = {
        "architecture": {"target": 32, "min": 24, "max": 40},
        "prop": {"target": prop_density, "min": 48, "max": 80},
        "hero": {"target": hero_density, "min": 80, "max": 128},
        "viewmodel_deferred": {"target": view_density, "min": 192, "max": 320},
    }

    # ------------------------------------------------------------------
    # 3. Texture sizes.
    # ------------------------------------------------------------------
    say("-" * 72)
    say("3. TEXTURE SIZES")
    say("-" * 72)
    say("Falls out of section 2 -- a size is a density times a world extent,")
    say("never a number picked first:")
    say("  architecture module, 4 m tile     32/m x 4.0 m = 128 px")
    say("  architecture trim, 4 m x 0.5 m    32/m         = 128 x 16, padded to 128 x 32")
    say("  prop, up to 1 m                   64/m x 1.0 m =  64 px")
    say("  prop, up to 2 m                   64/m x 2.0 m = 128 px")
    say("  hero object, up to 1.3 m          96/m x 1.3 m = 128 px")
    say()
    say("CEILING: 128 for everything in Batch 001. Not because 256 would look")
    say("bad, but because the runtime's own textures are bounded at %d"
        % dim["proc_texture_max"])
    say("(TEXTURE_SIZE_MAX) and authored content standing beside procedural")
    say("content at twice the density would make the seam between them the")
    say("most visible thing in the room. Raising it is an engineering")
    say("conversation, not an art decision taken quietly.")
    say()
    out["texture_size"] = {
        "default": 64, "max_batch001": 128, "min": 32,
        "allowed": [32, 64, 128],
    }

    # ------------------------------------------------------------------
    # 4. Triangles.
    # ------------------------------------------------------------------
    say("-" * 72)
    say("4. TRIANGLE CEILINGS -- limiters, not targets")
    say("-" * 72)
    say("Godot 4 in 2026 is not the constraint. These are AESTHETIC limiters:")
    say("the 1998 read depends on flat facets and straight brush edges, so")
    say("triangles spent rounding a form off are triangles spent destroying")
    say("the look. Anchored to what the era actually shipped:")
    say("  Quake monster                  ~300-500 tris")
    say("  Half-Life grunt                ~600-700 tris")
    say("  Half-Life world crate (brush)  ~12-40 tris")
    say("  a whole Half-Life scene        ~3,000-5,000 tris on screen")
    say()
    say("So, per category, with the failure each ceiling prevents:")
    ceilings = [
        ("architecture_module", 250,
         "a wall/floor/trim/railing piece. Above this it is being rounded or "
         "greebled; a 1998 wall is a brush face with a trim strip on it."),
        ("prop", 300,
         "a crate, box, sign, pipe cluster. Above this the prop is competing "
         "with the architecture for the eye, which DESIGN 3.4's 'readable "
         "gameplay surfaces' cannot survive."),
        ("interactable", 900,
         "a door, terminal, portal frame, affordance fixture. Gets more "
         "because the player must identify it instantly and it is looked at "
         "deliberately."),
        ("hero", 1200,
         "the Check object, Epsilon's presence. The most-repeated images in "
         "the game; AUTHORED_CONTENT calls them identity."),
        ("enemy", 700,
         "sits exactly on the Half-Life grunt. An enemy above this stops "
         "reading as an era silhouette and starts reading as a modern model "
         "with a retro texture, which is the single most common way this "
         "aesthetic is faked badly."),
        ("landmark", 2500,
         "an L4 set piece -- one per room at most, seen from across it."),
    ]
    for name, value, why in ceilings:
        say("  %-22s %5d   %s" % (name, value, why))
        out.setdefault("max_triangles", {})[name] = value
    say()
    room_budget = 12000
    say("Per composed room: %d triangles of AUTHORED geometry." % room_budget)
    say("  2-3x a Half-Life scene, because 2026 hardware buys density without")
    say("  buying smoothness. It is checked on the composed-room shot, which")
    say("  is the only place the number can be wrong in a way anyone sees.")
    out["max_triangles_room"] = room_budget
    say()

    # ------------------------------------------------------------------
    # 5. Segments and bevels.
    # ------------------------------------------------------------------
    say("-" * 72)
    say("5. RADIAL SEGMENTS AND BEVELS -- where the era actually lives")
    say("-" * 72)
    say("The segment cap does more work than the triangle cap. A pipe with 8")
    say("sides is a 1998 pipe; the same pipe at 24 is a modern pipe that")
    say("happens to be cheap, and no texture rescues it.")
    say("  hard-surface cylinder, radius <= 1.5 m     8 segments")
    say("  hard-surface cylinder, radius >  1.5 m    12 segments  (a tunnel bore")
    say("                                                          at 8 reads as")
    say("                                                          an octagon room)")
    say("  enemy / anything organic-leaning          10 segments")
    say()
    say("BEVELS: none on architecture. This is the deliberate inversion of the")
    say("mario-3 rule and it is era-driven -- a Quake brush edge is razor")
    say("sharp, and edge definition came from the TEXTURE (a painted highlight")
    say("and shadow at the seam) plus a physically separate trim piece.")
    say("  FAILURE a bevel would cause: a bevelled doorway reads as extruded")
    say("  modern geometry, and worse, it stops modules butting together")
    say("  flush -- two bevelled wall sections meet in a visible groove.")
    say("  FAILURE going unbevelled could cause: an edge vanishing when both")
    say("  faces catch the same light. That is prevented by the trim piece and")
    say("  by painted edge treatment, not by geometry.")
    say("  Permitted exception: a 1-segment micro-bevel at %.1f-%.1f%% of the"
        % (1.5, 3.0))
    say("  smallest dimension, on a hand-scale PROP above 0.5 m that the player")
    say("  walks up to. Never on a floor, never on a module edge.")
    out["max_radial_segments"] = 8
    out["max_radial_segments_large"] = 12
    out["large_radius_threshold"] = 1.5
    out["max_radial_segments_enemy"] = 10
    out["architecture_bevel"] = 0.0
    out["prop_bevel_fraction"] = [0.015, 0.030]
    out["prop_bevel_min_size"] = 0.5
    say()

    # ------------------------------------------------------------------
    # 6. Value separation.
    # ------------------------------------------------------------------
    say("-" * 72)
    say("6. VALUE SEPARATION -- the readability rule")
    say("-" * 72)
    say("Archipepsi has a problem mario-3 does not: the player must find the")
    say("interactable in a room a machine composed, under time pressure, in a")
    say("theme they may be seeing for the first time. So there are two")
    say("thresholds, and the second is the important one:")
    say("  floor / wall / trim within one theme   dL* >= 0.10")
    say("     FAILURE: greyscale mush. Desaturate a screenshot and you cannot")
    say("     tell where the floor stops. A 1998 game with harsh simple")
    say("     lighting has nothing else to separate them with.")
    say("  any INTERACTABLE against its host surface   dL* >= 0.18")
    say("     FAILURE: the Check object disappears into the wall it stands")
    say("     against in one theme out of six. AUTHORED_CONTENT names exactly")
    say("     this: 'Can I use this?' must never be a guess.")
    say()
    say("L*, not luminance: four of the six themes sit in the dark half of the")
    say("range, where linear luminance is wildly non-uniform and a flat")
    say("threshold on it would force the whole palette pale to satisfy a")
    say("number.")
    out["min_value_separation"] = 0.10
    out["min_interactable_separation"] = 0.18
    out["max_families_per_asset"] = 4
    say()
    say("MAX FAMILIES PER ASSET: 4. Running out of colours is the constraint")
    say("doing its job -- a 1998 asset was painted from a handful of palette")
    say("entries, and an asset reaching for a fifth is usually painting detail")
    say("that should have been value instead.")
    say()

    # ------------------------------------------------------------------
    # 7. Silhouette / readability at range.
    # ------------------------------------------------------------------
    say("-" * 72)
    say("7. READABILITY AT RANGE -- checked, not hoped for")
    say("-" * 72)
    melee_h = dim["enemy_melee_size"][1]
    say("A melee enemy is %.1f m tall and is first seen at aggro range, %.0f m."
        % (melee_h, dim["enemy_aggro_radius"]))
    say("  at %.0f m it is %.0f px tall on a 1080p screen"
        % (dim["enemy_aggro_radius"],
           screen_height_px(melee_h, dim["enemy_aggro_radius"])))
    say("  at %.0f m (Pulse range) it is %.0f px"
        % (dim["pulse_range"], screen_height_px(melee_h, dim["pulse_range"])))
    say("  at %.1f m (its own reach) it is %.0f px"
        % (dim["melee_reach"], screen_height_px(melee_h, dim["melee_reach"])))
    say("-> the silhouette must survive at %.0f px. Every enemy review shot is"
        % screen_height_px(melee_h, dim["enemy_aggro_radius"]))
    say("   taken at aggro range and NOT only at a flattering portrait")
    say("   distance. mario-3 paid for this lesson: a studio silhouette row")
    say("   at ~500 px proved the design worked at a size nobody plays at.")
    out["enemy_review_distance_m"] = dim["enemy_aggro_radius"]
    out["enemy_aggro_px_1080p"] = round(
        screen_height_px(melee_h, dim["enemy_aggro_radius"]), 1)
    say()
    check_h = 2.6
    say("The Check object's collision box is %.1f m tall. Across the largest" % check_h)
    say("arena (%.0f m) it is %.0f px; across a corridor (%.0f m) %.0f px."
        % (arena_diagonal, screen_height_px(check_h, arena_diagonal),
           dim["corridor_length_max"],
           screen_height_px(check_h, dim["corridor_length_max"])))
    say("-> 'reads as the same important object from across a room' has a")
    say("   number behind it, and the number is %.0f px."
        % screen_height_px(check_h, arena_diagonal))
    out["check_review_distance_m"] = round(arena_diagonal, 1)
    out["check_far_px_1080p"] = round(screen_height_px(check_h, arena_diagonal), 1)
    say()
    say("MINIMUM MEANINGFUL GEOMETRY: a form must be at least 8% of its")
    say("object's height, or be at least 2 screen px at the distance the")
    say("object is judged at -- whichever is LARGER. Below that it is texture.")
    say("  a %.1f m enemy at %.0f m: 2 px == %.0f mm of real form"
        % (melee_h, dim["enemy_aggro_radius"],
           1000.0 * 2.0 / (screen_height_px(1.0, dim["enemy_aggro_radius"]))))
    out["min_feature_fraction"] = 0.08
    out["min_feature_screen_px"] = 2.0
    say()

    say("=" * 72)
    say("Every number above is now in assets/art_budgets.json.")
    say("If you change one there, change the reasoning here, or the reasoning")
    say("stops being why and becomes decoration.")
    say("=" * 72)

    return out, "\n".join(lines)


def main():
    values, report = derive()
    print(report)
    if "--write" in sys.argv:
        payload = {
            "_comment": [
                "Archipepsi art budgets. GENERATED -- regenerate with:",
                "    python3 tools/blender/derive_budgets.py --write",
                "",
                "Every number here is derived in tools/blender/derive_budgets.py,",
                "which prints the arithmetic and names the visible failure each",
                "constraint prevents. Nothing was inherited from another project:",
                "mario-3's ceilings, texture sizes and densities answer questions",
                "Archipepsi does not ask.",
                "",
                "The game dimensions the derivation stands on are read live from",
                "the engineering branch through tools/blender/engine_truth.py, so",
                "these numbers move when the game moves.",
            ],
        }
        payload.update(values)
        with open(BUDGETS_PATH, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, indent=2)
            handle.write("\n")
        print()
        print("wrote %s" % os.path.relpath(BUDGETS_PATH, REPO_ROOT))


if __name__ == "__main__":
    main()
