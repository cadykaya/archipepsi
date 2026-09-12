"""The six-theme texture set, checked as a shippable thing.

    python3 tools/content/verify_theme_set.py [--write]

## Why this is separate from check_theme_roles.py

That one asks whether every material name on every shipped SHELL resolves
to a theme role, and whether the themes cover what those shells use. It is
a check about the shells. This is a check about the SET: is it complete
against the role authority in its own right, does its manifest agree with
the files on disk, and is there one description a binder could be written
against.

Theme-pack gap 3 is "the six-theme texture set ships nowhere". Where it
lands and how it binds are Production's to decide, and nothing here
decides either -- no destination is chosen, nothing is copied into
`godot/`. What this does is make the set describable and checkable now, so
the day a destination exists the only new work is the copy.

## What it asserts, and what it only reports

ASSERTED, because the authority says so:

  * every REQUIRED role (8.1) has a texture in every theme, or is a
    universal that no theme may paint;
  * no theme ships a texture for a universal role -- the owner's
    2026-09-10 ruling: a pack RESOLVES `hazard` to the shared material and
    must not re-tint it;
  * every optional role a theme does ship is shipped by ALL of them, so a
    binder cannot find a role present in five themes and missing in one;
  * the manifest names a file that exists, at the pixel size it claims,
    and every entry agrees on texel density;
  * `THEME_PACK.json` regenerates byte-identical from this file, the way
    `art_budgets.json` does from its derivation -- so the description
    cannot drift from the set it describes.

REPORTED, not asserted: the measured mean value of every texture. The
palette's `min_value_separation` governs ADJACENT STEPS WITHIN A RAMP, not
one role against another, so a rule about role-versus-role separation would
be one I invented rather than one the authority states. The numbers are in
the descriptor as data for whoever writes the binder.
"""
import hashlib
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import inspect_materials as mat                             # noqa: E402

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SET_DIR = os.path.join(REPO, "assets", "textures", "theme")
MANIFEST = os.path.join(SET_DIR, "manifest.json")
DESCRIPTOR = os.path.join(SET_DIR, "THEME_PACK.json")

#: WHICH ROLES NEED AUTHORED PIXELS, AND WHICH ARE ANSWERED ELSEWHERE.
#:
#: The descriptor used to emit `required_roles` straight from
#: `inspect_materials.REQUIRED_ROLES` -- floor, wall, trim, accent, hazard --
#: and separately reported that no theme ships a `hazard` texture, on the
#: owner's 2026-09-10 ruling. Production's clause 3 disqualifies a theme
#: missing a required role, so the two statements together disqualified all
#: six themes. Neither statement was wrong; together they were not a
#: contract.
#:
#: They are two different questions and the file now asks them separately:
#: §8.1's list is which roles a PACK MUST RESOLVE, and this is which of them
#: the pack resolves WITH ITS OWN PIXELS.
#:
#: Read from `godot/scripts/generation/theme_materials.gd` at Production
#: `7adc5e5`, which is the only thing in the engine that answers "what does
#: this theme look like":
#:
#:     floor_mat(theme)   _material(theme, "floor")
#:     wall_mat(theme)    _material(theme, "wall")
#:     accent_mat(theme)  _material(theme, "accent", "panel")
#:     trim_mat(theme)    _material(theme, "trim", "panel")
#:     hazard_mat(theme)  _material(theme, "accent", "hazard")
#:
#: HAZARD IS NOT A SHARED MATERIAL IN THE ENGINE, and an earlier version of
#: this file said it was. `hazard_mat` is theme-parameterised: it takes the
#: theme's own accent colour and overrides only the noise. What is true is
#: narrower and is what the ruling actually buys: **the pack supplies no
#: hazard pixels**, and the role keeps a supported implementation --
#: procedurally in the engine through `hazard_mat`, and on a shell through
#: the art lane's shared universal hazard ramp, which no theme may re-tint.
#:
#: So hazard is not removed from anything. It is a real runtime obligation
#: met somewhere other than the pack, and the descriptor now says which.
PIXELS_REQUIRED = ("floor", "wall", "trim", "accent")

#: Required by §8.1, resolved without pack pixels. Value: how.
RESOLVED_ELSEWHERE = {
    "hazard": "ThemeMaterials.hazard_mat(theme) -- procedural, the theme's "
              "own accent colour with the 'hazard' noise; and on a shell, "
              "the art lane's shared universal hazard ramp, which no theme "
              "may re-tint (owner, 2026-09-10). The pack paints none, and a "
              "theme that shipped one would be the finding.",
}

#: The engine accessor each role is answered by, at Production `7adc5e5`.
#: `ceiling` has none: the pack ships one for all six themes and nothing in
#: the engine asks for it yet, which is worth Production knowing before the
#: binder decides what to do with those pixels.
ENGINE_ACCESSOR = {
    "floor": "ThemeMaterials.floor_mat",
    "wall": "ThemeMaterials.wall_mat",
    "accent": "ThemeMaterials.accent_mat",
    "trim": "ThemeMaterials.trim_mat",
    "hazard": "ThemeMaterials.hazard_mat",
    "ceiling": None,
}


def themes():
    with open(os.path.join(REPO, "assets", "art_palette.json"),
              "r", encoding="utf-8") as handle:
        return sorted(json.load(handle)["themes"])


def png_size(path):
    """(width, height) from the IHDR, without a PNG library."""
    with open(path, "rb") as handle:
        head = handle.read(24)
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return (int.from_bytes(head[16:20], "big"),
            int.from_bytes(head[20:24], "big"))


def mean_value(path):
    """Mean relative luminance of a texture, 0..1. Reported, not asserted."""
    try:
        from PIL import Image
    except ImportError:
        return None
    with Image.open(path) as image:
        # `getdata` is deprecated in Pillow 14 and its replacement returns
        # a different shape; the warning is silenced rather than guessed at,
        # because this number is reported and never gates anything.
        import warnings
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", DeprecationWarning)
            pixels = list(image.convert("RGB").getdata())
        n = len(pixels)
        total = 0.0
        for r, g, b in pixels:
            total += (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
    return round(total / n, 4)


def describe(problems):
    """The whole set, as one object a binder could be written against."""
    with open(MANIFEST, "r", encoding="utf-8") as handle:
        manifest = json.load(handle)

    shipped = {}
    for key, entry in manifest.items():
        theme, _, role = key.partition("/")
        shipped.setdefault(theme, {})[role] = entry

    all_themes = themes()
    for theme in all_themes:
        if theme not in shipped:
            problems.append("theme '%s' is in the palette and ships no "
                            "texture at all" % theme)

    # §8.1's roles, split by the question that actually matters: does the
    # PACK answer this one with pixels, or does something else answer it?
    for role in mat.REQUIRED_ROLES:
        if role in RESOLVED_ELSEWHERE:
            painted = [t for t in all_themes if role in shipped.get(t, {})]
            if painted:
                problems.append(
                    "%s ship a '%s' texture. The pack supplies no pixels "
                    "for it -- it is resolved by %s"
                    % (", ".join(painted), role, RESOLVED_ELSEWHERE[role]))
            continue
        if role not in PIXELS_REQUIRED:
            problems.append(
                "role '%s' is required by 8.1 and this file says neither "
                "that the pack paints it nor how else it is resolved. That "
                "is the gap that disqualified all six themes: add it to "
                "PIXELS_REQUIRED or to RESOLVED_ELSEWHERE." % role)
            continue
        missing = [t for t in all_themes if role not in shipped.get(t, {})]
        if missing:
            problems.append("role '%s' needs authored pixels and %s ship "
                            "none" % (role, ", ".join(missing)))
    for role in PIXELS_REQUIRED:
        if role not in mat.REQUIRED_ROLES:
            problems.append(
                "'%s' is listed as needing authored pixels and is not a "
                "required role (8.1); the two lists have drifted" % role)

    # Whatever else is shipped must be shipped by every theme, or a binder
    # finds a role in five packs and a hole in the sixth.
    extras = {}
    for theme in all_themes:
        for role in shipped.get(theme, {}):
            if role in mat.REQUIRED_ROLES:
                continue
            extras.setdefault(role, []).append(theme)
    partial = {r: t for r, t in extras.items() if len(t) != len(all_themes)}
    # A ROLE present in five themes and missing in the sixth is a hole a
    # binder falls into. A VARIANT is not a role -- `wall_ribbed` exists
    # for concrete_facility alone on purpose, and making it an obligation
    # would hand every future pack a seventh one for one theme's
    # convenience -- so it is reported and not refused.
    for role, has in sorted(partial.items()):
        if role in mat.VARIANTS:
            continue
        problems.append(
            "role '%s' is shipped by %s and by no other theme. A binder "
            "would find it in some packs and not others."
            % (role, ", ".join(sorted(has))))

    # Files, sizes, density.
    density = set()
    for key, entry in sorted(manifest.items()):
        path = os.path.join(REPO, "assets", "textures", entry["texture"])
        if not os.path.exists(path):
            problems.append("%s names %s, which is not there"
                            % (key, entry["texture"]))
            continue
        size = png_size(path)
        if size is None:
            problems.append("%s is not a PNG" % entry["texture"])
        elif size != (entry["size_px"], entry["size_px"]):
            problems.append("%s claims %d px and the file is %dx%d"
                            % (key, entry["size_px"], size[0], size[1]))
        density.add(entry["texels_per_metre"])
    if len(density) > 1:
        problems.append("the set mixes texel densities: %s. A binder that "
                        "swaps one theme for another would change the "
                        "texel density of the room." % sorted(density))

    roles = sorted({r for t in shipped.values() for r in t})
    out = {
        "_comment": "GENERATED by tools/content/verify_theme_set.py. The "
                    "six-theme texture set, described for a binder that "
                    "does not exist yet. No destination is chosen here.",
        "themes": all_themes,
        "roles_shipped": roles,
        # `required_roles` USED TO BE HERE and was the whole problem:
        # Production's clause 3 read it as "a theme missing one of these is
        # disqualified", and `hazard` is in it and shipped by nobody, so
        # every theme was disqualified. The list was not wrong; it answered
        # a different question -- which roles a pack must RESOLVE -- and
        # clause 3 needs the narrower one.
        "roles_requiring_authored_pixels": sorted(PIXELS_REQUIRED),
        "roles_resolved_without_pack_pixels": dict(RESOLVED_ELSEWHERE),
        "role_contract": {
            role: {
                "pack_pixels": ("required" if role in PIXELS_REQUIRED
                                else "none" if role in RESOLVED_ELSEWHERE
                                else "shipped"),
                "disqualifies_theme_if_missing": role in PIXELS_REQUIRED,
                "engine_accessor": ENGINE_ACCESSOR.get(role),
                "resolved_by": RESOLVED_ELSEWHERE.get(
                    role, "the pack, by (theme, role)"),
            }
            for role in sorted(set(mat.REQUIRED_ROLES) | set(roles))
        },
        "optional_role_fallbacks": dict(mat.OPTIONAL_ROLES),
        "variants": dict(mat.VARIANTS),
        "roles_not_shipped_by_every_theme": {r: sorted(t)
                                             for r, t in sorted(partial.items())},
        "texels_per_metre": sorted(density)[0] if density else None,
        "textures": {},
    }
    for key, entry in sorted(manifest.items()):
        path = os.path.join(REPO, "assets", "textures", entry["texture"])
        if not os.path.exists(path):
            continue
        with open(path, "rb") as handle:
            digest = hashlib.sha256(handle.read()).hexdigest()[:16]
        out["textures"][key] = {
            "texture": entry["texture"],
            "size_px": entry["size_px"],
            "covers_m": entry["covers_m"],
            "sha256_16": digest,
            "mean_value": mean_value(path),
        }
    return out


def main():
    if not os.path.exists(MANIFEST):
        print("verify-theme-set: FAIL -- no manifest at %s" % MANIFEST,
              file=sys.stderr)
        return 1

    problems = []
    described = describe(problems)
    text = json.dumps(described, indent=1, sort_keys=True) + "\n"

    if "--write" in sys.argv:
        with open(DESCRIPTOR, "w", encoding="utf-8") as handle:
            handle.write(text)
    else:
        current = ""
        if os.path.exists(DESCRIPTOR):
            with open(DESCRIPTOR, "r", encoding="utf-8") as handle:
                current = handle.read()
        if current != text:
            problems.append(
                "THEME_PACK.json no longer matches the set it describes. "
                "Regenerate it -- python3 tools/content/verify_theme_set.py "
                "--write -- rather than editing it; a description nobody "
                "regenerates is decoration.")

    for problem in problems:
        print("verify-theme-set: FAIL -- %s" % problem, file=sys.stderr)
    if problems:
        return 1
    print("verify-theme-set: %d theme(s), %d texture(s), %d role(s); the %d "
          "role(s) needing authored pixels present in every theme, %d "
          "resolved elsewhere, and the description matching."
          % (len(described["themes"]), len(described["textures"]),
             len(described["roles_shipped"]), len(PIXELS_REQUIRED),
             len(RESOLVED_ELSEWHERE)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
