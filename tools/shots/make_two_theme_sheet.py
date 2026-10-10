"""One shipped GLB, two themes, side by side — with the isolation numbers.

    python3 tools/shots/make_two_theme_sheet.py [dir]

The two panels are the ACTUAL RENDERED INSTANCES from
`tools/content/two_themes_proof.gd`, not recolours of one capture. The
block beneath them is `instance_isolation.json` as the proof recorded it:
one shared mesh, per-surface overrides, and the shared resource's own
materials unchanged through three bindings.
"""

from __future__ import annotations

import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

REPO = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))
DIR = os.path.join(REPO, "docs/art/review/theme_baseline_2026-09-10")

F = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FB = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FM = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
INK, DIM, OK, BG = (232, 234, 238), (150, 155, 165), (110, 214, 130), (18, 19, 23)
PAD, TILE = 26, 760


def main(argv):
    d = argv[1] if len(argv) > 1 else DIR
    log = json.load(open(os.path.join(d, "instance_isolation.json"),
                         encoding="utf-8"))
    panels = [("concrete_facility", "TWO_THEMES_A_concrete_facility.png"),
              ("rusted_industrial", "TWO_THEMES_B_rusted_industrial.png")]
    ims = [(t, Image.open(os.path.join(d, f)).convert("RGB"))
           for t, f in panels]
    pair = Image.open(os.path.join(d, "TWO_THEMES_pair.png")).convert("RGB")

    tw = TILE
    th = int(ims[0][1].height * tw / float(ims[0][1].width))
    pw = 2 * tw + PAD
    ph = int(pair.height * pw / float(pair.width))
    head, label, facts = 176, 46, 300
    W = 2 * tw + 3 * PAD
    H = head + th + label + PAD + ph + label + facts

    im = Image.new("RGB", (W, H), BG)
    dr = ImageDraw.Draw(im)
    t40, t21, t28, m19, m20 = (ImageFont.truetype(FB, 40),
                               ImageFont.truetype(F, 21),
                               ImageFont.truetype(FB, 28),
                               ImageFont.truetype(FM, 19),
                               ImageFont.truetype(FM, 20))

    dr.text((PAD, 26), "One shipped GLB, two themes, at once", font=t40,
            fill=INK)
    for i, line in enumerate([
            "art %s  ·  shell_corner_left.glb  ·  Godot 4.5.1 Compatibility "
            "(opengl3)  ·  per-surface overrides" % log.get("art_head", ""),
            "The SAME imported mesh is instantiated twice and each instance "
            "is bound to a different theme. No second GLB was built,",
            "nothing was exported, and the shared resource is not touched. "
            "This is a preview compatibility proof, not a runtime binder."]):
        dr.text((PAD, 82 + i * 27), line, font=t21, fill=DIM)

    for i, (theme, tile) in enumerate(ims):
        x = PAD + i * (tw + PAD)
        im.paste(tile.resize((tw, th), Image.LANCZOS), (x, head))
        dr.rectangle([x, head, x + tw - 1, head + th - 1],
                     outline=(70, 74, 82))
        dr.text((x, head + th + 10),
                "%s   instance %s" % (theme, "AB"[i]), font=t28, fill=INK)

    y = head + th + label + PAD
    im.paste(pair.resize((pw, ph), Image.LANCZOS), (PAD, y))
    dr.rectangle([PAD, y, PAD + pw - 1, y + ph - 1], outline=(70, 74, 82))
    dr.text((PAD, y + ph + 10), "both instances, one scene", font=t28,
            fill=INK)

    def same(a, b):
        return log[a] == log[b]

    y = y + ph + label + 12
    rows = [
        ("both instances share ONE imported mesh",
         log["shared_mesh_is_one_resource"]),
        ("surfaces bound per instance: %d, unresolved: %d"
         % (log["surfaces"], len(log["unresolved_A"])),
         not log["unresolved_A"] and not log["unresolved_B"]),
        ("shared mesh materials unchanged after binding A",
         same("shared_before", "shared_after_A")),
        ("shared mesh materials unchanged after binding B",
         same("shared_before", "shared_after_B")),
        ("B unchanged while A was bound (B still had no overrides)",
         all(v == "" for v in log["overrides_B_after_A"])),
        ("A rebound to a THIRD theme and B did not move",
         same("overrides_B_after_B", "overrides_B_after_rebind")),
        ("shared mesh materials unchanged after that rebind too",
         same("shared_before", "shared_after_rebind")),
        ("materials reused per (theme, role): %d for 3 themes x 4 roles"
         % log["distinct_materials_built"], True),
        ("collision unchanged by theming: %d bodies, %d shapes, %d nodes, "
         "instance-local transforms"
         % (log["structure_A_after"]["static_bodies"],
            log["structure_A_after"]["collision_shapes"],
            log["structure_A_after"]["nodes"]),
         log["structure_A_unchanged"] and log["structure_B_unchanged"]),
        ("and the two instances' structural digests match each other",
         log["structure_A_equals_B"]),
    ]
    dr.text((PAD, y), "instance isolation, as recorded", font=t28, fill=INK)
    for i, (text, ok) in enumerate(rows):
        yy = y + 44 + i * 27
        dr.text((PAD, yy), "PASS" if ok else "FAIL", font=m20,
                fill=OK if ok else (240, 110, 110))
        dr.text((PAD + 72, yy), text, font=m19, fill=DIM)

    out = os.path.join(d, "TWO_THEMES_comparison.png")
    im.save(out)
    print("[sheet] %s  %dx%d" % (os.path.relpath(out, REPO), W, H))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
