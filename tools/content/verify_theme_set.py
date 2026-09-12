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

#: Roles a pack resolves to a SHARED material and must never paint itself.
#: Mirrors check_theme_roles.UNIVERSAL_ROLES rather than restating it.
UNIVERSAL_ROLES = ("hazard",)


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

    # Required roles, and the universals no theme may paint.
    for role in mat.REQUIRED_ROLES:
        if role in UNIVERSAL_ROLES:
            painted = [t for t in all_themes if role in shipped.get(t, {})]
            if painted:
                problems.append(
                    "%s paint a '%s' texture. It is a UNIVERSAL role: a "
                    "pack resolves it to the shared material and must not "
                    "re-tint it (owner, 2026-09-10)."
                    % (", ".join(painted), role))
            continue
        missing = [t for t in all_themes if role not in shipped.get(t, {})]
        if missing:
            problems.append("required role '%s' (8.1) is missing from %s"
                            % (role, ", ".join(missing)))

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
        "required_roles": list(mat.REQUIRED_ROLES),
        "universal_roles": {r: "resolve to the shared universal material; "
                               "a pack must not paint its own"
                            for r in UNIVERSAL_ROLES},
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
    print("verify-theme-set: %d theme(s), %d texture(s), %d role(s); every "
          "required role present or universal, and the description matches."
          % (len(described["themes"]), len(described["textures"]),
             len(described["roles_shipped"])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
