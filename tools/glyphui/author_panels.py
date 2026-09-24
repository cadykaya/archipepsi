#!/usr/bin/env python3
"""Track A, slice 2 -- the interface family's NINE-SLICE PANELS.

    GLYPH_ROOT=<checkout> python3 tools/glyphui/author_panels.py [out-dir]

## Why these three, and why so small

`04` section 9 asks for panel blocks, grids, frames and a selection
treatment. Those are all the same object: a rectangle with a border that
must not distort when the rectangle changes size. Three of them cover the
whole vocabulary an interface needs before it knows what it is showing:

  * `panel`    -- raised. A window, a header, a button at rest.
  * `well`     -- the same bevel inverted. A recess: a grid cell, a list
                  area, a slot, a pressed button.
  * `selected` -- a well's job with `signal` on its outline. The one cell
                  you are about to act on.

Ten pixels square with a three-pixel border. Small is the point: a
nine-slice's corners are drawn at their authored size at every panel
size, so every pixel in that border is visible forever and there is
nowhere to hide a soft edge.

## The colours are the project's, and the palette gets a veto

Every colour here is read out of `assets/art_palette.json` rather than
typed in, and the bevel is checked against the palette's OWN
`min_value_separation` before a pixel is drawn. That check earned itself
immediately: the first `selected` treatment took its shadow from the
`signal` ramp's darkest step, which separates from the face by 0.017 L*
against a required 0.10 -- an invisible bevel, and invisible in exactly
the way that survives review because the screenshot still looks fine.

## What is NOT decided here

The palette has six universal families and every one of them means
something specific -- `signal` is the only colour an interactable may be,
`hazard` is never decorative, `identity` is Epsilon alone. None of them
is "interface chrome". These panels use the `dead` ramp for chrome, which
is defensible (a frame is not for you; its contents are) and is also a
DECISION THE OWNER HAS NOT MADE. It is raised in the report as such. The
import behaviour this slice exists to establish does not depend on it:
the geometry is the same whatever the chrome ends up being.
"""

from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile

import glyphrun

REPO = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, "tools", "blender"))
import palette as art_palette  # noqa: E402  (after sys.path)

OWNER = "act_owner_arty"
ARTIST = "act_agent_arty"

#: Ten square, three-pixel border, four-pixel stretchable centre.
W = H = 10
BORDER = 3

#: Which of the four ring roles a pixel belongs to. `ring` counts inward
#: from the nearest edge, so ring 0 is the outline and anything at or
#: past BORDER is the centre.
#:
#: On ring 1 a pixel is LIT if it lies on the top or left edge and
#: SHADED on the bottom or right, with top/left winning the two corners
#: where both apply. That is the ordinary chiselled bevel: two L shapes,
#: light over dark.
def role_at(x, y):
    ring = min(x, y, W - 1 - x, H - 1 - y)
    if ring >= BORDER:
        return "face"
    if ring == 0:
        return "outline"
    if ring == BORDER - 1:
        return "face"
    if x == ring or y == ring:
        return "light"
    return "dark"


def ramps():
    p = art_palette.palette()
    return (p["universal"]["dead"]["ramp"], p["universal"]["signal"]["ramp"],
            p["min_value_separation"], p["min_interactable_separation"])


def treatments():
    dead, signal, _, _ = ramps()
    return {
        # A raised face: light over the top and left, shadow below and
        # right, hard outline all round.
        "panel": {"outline": dead[0], "light": dead[3],
                  "dark": dead[1], "face": dead[2]},
        # The same four colours, the bevel reversed. Nothing else changes
        # -- a recess and a relief differ only in where the light is, and
        # inventing a second face colour would make them two objects.
        "well": {"outline": dead[0], "light": dead[1],
                 "dark": dead[3], "face": dead[2]},
        # `signal` on the outline and the lit edge, because this is the
        # thing you can act on and signal is the only colour that may say
        # so. The SHADOW stays neutral: a shadow is absence of light, and
        # the signal ramp has no step dark enough to read against the
        # face anyway -- see the module docstring.
        "selected": {"outline": signal[2], "light": signal[3],
                     "dark": dead[0], "face": dead[2]},
    }


def check_separation(kit):
    """The palette's own rules, applied before anything is drawn.

    A bevel is two adjacent colours. If they do not separate they are one
    colour, and the panel has no bevel however carefully it was authored.
    """
    _, _, min_value, min_interactable = ramps()
    problems = []
    for name, roles in kit.items():
        for a, b in (("light", "face"), ("dark", "face"),
                     ("outline", "face"), ("outline", "light"),
                     ("outline", "dark")):
            sep = art_palette.separation(roles[a], roles[b])
            if sep < min_value:
                problems.append(
                    "%s: %s %s and %s %s separate by %.3f L*, under the "
                    "palette's min_value_separation of %.2f -- that edge "
                    "will not be visible"
                    % (name, a, roles[a], b, roles[b], sep, min_value))
        # `selected` is an interactable indicator, so it answers to the
        # stricter of the palette's two thresholds.
        if name == "selected":
            sep = art_palette.separation(roles["outline"], roles["face"])
            if sep < min_interactable:
                problems.append(
                    "selected: the signal outline separates from the face "
                    "by %.3f L*, under min_interactable_separation %.2f"
                    % (sep, min_interactable))
    return problems


def runs(roles):
    """Contiguous same-role horizontal runs, as ((x0, y), (x1, y), role).

    One `pixels.draw` per run rather than per pixel: a 10x10 panel is 100
    pixels and 30-odd runs, and a transaction per pixel is a minute of
    node startup for nothing.
    """
    out = []
    for y in range(H):
        x = 0
        while x < W:
            role = role_at(x, y)
            start = x
            while x < W and role_at(x, y) == role:
                x += 1
            out.append(((start, y), (x - 1, y), role))
    return out


ARTIFACTS = tuple("panel_%s.png" % n for n in ("panel", "well", "selected"))


def main():
    out_dir = os.path.abspath(sys.argv[1] if len(sys.argv) > 1
                              else os.path.join(REPO, "assets", "ui"))
    kit = treatments()
    problems = check_separation(kit)
    if problems:
        for p in problems:
            print("[panels] %s" % p)
        raise SystemExit("[panels] the palette refuses these colours; fix "
                         "the treatment, not the threshold")
    print("[panels] %d treatment(s) clear the palette's separation rules"
          % len(kit))

    os.makedirs(out_dir, exist_ok=True)
    work = tempfile.mkdtemp(prefix="glyphui_")
    ses = glyphrun.Session(
        os.environ.get("GLYPH_ROOT", "/home/user/glyph-trial"),
        work, "archipepsi_panels.glyph", OWNER, ARTIST)
    ses.create("the art lane draws the interface family's panels")

    # --- one palette for the whole set --------------------------------
    inks = []
    for roles in kit.values():
        for hexv in roles.values():
            if hexv not in inks:
                inks.append(hexv)
    entries = []
    for hexv in inks:
        r, g, b = art_palette.rgb(hexv)
        entries.append({"name": hexv.lstrip("#"),
                        "value": {"r": round(r * 255), "g": round(g * 255),
                                  "b": round(b * 255), "a": 255}})
    made = ses.txn({"creates": ["asset", "palette"]}, [
        ("palette.create", {"entries": entries}),
        ("asset.create", {"name": "ui_panels"}),
    ], "the interface family's chrome")
    entry_of = dict(zip(inks, made[0]["palette"]["order"]))
    pal, asset = made[0]["palette"]["id"], made[1]["asset"]["id"]
    print("[panels] %d ink(s) from the project palette" % len(inks))

    record = {}
    for name, roles in kit.items():
        made = ses.txn({"creates": ["variant"]}, [
            ("variant.create", {"name": name, "width": W, "height": H,
                                "color_mode": "indexed", "palette": pal,
                                "asset": asset}),
        ], "the %s canvas" % name)
        variant = made[0]["variant"]["id"]
        frame = made[0]["variant"]["frames"][0]
        cel = made[0]["variant"]["cels"][0]

        ses.txn({"cels": [cel]}, [
            ("pixels.draw", {"cel": cel, "shape": "line",
                             "points": [list(a), list(b)],
                             "value": {"entry": entry_of[roles[role]]}})
            for a, b, role in runs(roles)
        ], "the %s bevel" % name)

        # The stretchable centre, declared as an ordinary region so it is
        # revisioned and attributed like everything else. The insets
        # FOLLOW from it -- they are not declared twice.
        centre = [[x, y] for y in range(BORDER, H - BORDER)
                  for x in range(BORDER, W - BORDER)]
        ses.txn({"creates": ["region"], "variants": [variant]}, [
            ("region.create", {"variant": variant, "name": "nine_slice",
                               "extents": {frame: centre}}),
        ], "the %s stretchable centre" % name)

        # The checks and the export, in one process: the preset dies with
        # the server that declared it.
        # Where these WOULD live once Production takes them. Nothing
        # writes godot/content/ui/ yet, so the field says "proposed" --
        # a contract naming a path that does not exist is a small lie
        # that somebody eventually builds on.
        texture = "res://content/ui/panel_%s.png" % name
        results = ses.batch([
            {"command": "export.define_preset",
             "input": ses.sheet_preset("panel_%s" % name, [variant], W, H)},
            {"command": "x-glyph.nine_slice", "input": {"variant": variant}},
            {"command": "x-glyph.godot_nine_patch",
             "input": {"variant": variant, "texture": texture,
                       "insets": {"left": BORDER, "top": BORDER,
                                  "right": BORDER, "bottom": BORDER}}},
            {"command": "export.run",
             "input": {"preset": "$1.preset", "destination": work}},
        ], label=name)
        slice_, patch, exported = results[1], results[2], results[3]

        for fault in slice_.get("faults", []):
            print("[panels] %s FAULT: %s" % (name, json.dumps(fault)))
        if slice_.get("faults"):
            raise SystemExit("[panels] %s's nine-slice is not usable" % name)
        insets = slice_["insets"]
        if insets != {"left": BORDER, "top": BORDER,
                      "right": BORDER, "bottom": BORDER}:
            raise SystemExit(
                "[panels] %s: Glyph derived insets %s from the declared "
                "centre and this script drew a %d px border. Right and "
                "bottom are measured INWARD from those edges -- if they "
                "came back as coordinates, everything downstream is wrong"
                % (name, insets, BORDER))
        if patch["patch_margins"] != insets:
            raise SystemExit("[panels] %s: patch margins %s do not match "
                             "the insets %s"
                             % (name, patch["patch_margins"], insets))
        # The export names its own page, and guessing that name is how a
        # build silently ships the wrong file. So: whatever PNG appeared
        # that was not there before, and exactly one of them.
        before = set(f for f in os.listdir(work) if f.endswith(".png"))
        ses.write_export(exported["record"], label=name)
        fresh = sorted(set(f for f in os.listdir(work)
                           if f.endswith(".png")) - before)
        if len(fresh) != 1:
            raise SystemExit("[panels] %s's export wrote %d page(s) (%s); "
                             "one variant is one page"
                             % (name, len(fresh), fresh))
        shutil.move(os.path.join(work, fresh[0]),
                    os.path.join(work, "panel_%s.png" % name))
        record[name] = {
            "size": [W, H], "insets": insets,
            "patch_margins": patch["patch_margins"],
            "stretchable_centre": patch["stretchable_centre"],
            "colours": roles, "proposed_texture": texture,
        }
        print("[panels] %s: insets %s, centre %s"
              % (name, [insets[k] for k in ("left", "top", "right", "bottom")],
                 patch["stretchable_centre"]))
        record[name]["variant"] = variant

    # --- the three are one set ----------------------------------------
    same = ses.run("x-glyph.check_set",
                   {"variants": [record[n].pop("variant") for n in record],
                    "require_same_size": True})
    if same.get("faults"):
        for fault in same["faults"]:
            print("[panels] SET FAULT: %s" % json.dumps(fault))
        raise SystemExit("[panels] the three panels are not one set")
    print("[panels] check_set: one set, all %dx%d" % (W, H))

    for name in ARTIFACTS:
        shutil.copyfile(os.path.join(work, name),
                        os.path.join(out_dir, name))
    with open(os.path.join(out_dir, "panels.json"), "w") as fh:
        json.dump(record, fh, indent=2, sort_keys=True)
        fh.write("\n")
    print("[panels] %d artifact(s) + panels.json -> %s"
          % (len(ARTIFACTS), out_dir))
    if os.environ.get("GLYPH_KEEP_WORK"):
        print("[panels] project kept at %s" % ses.project)
    else:
        shutil.rmtree(work)


if __name__ == "__main__":
    main()
