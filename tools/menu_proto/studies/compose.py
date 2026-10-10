"""Track A2 -- the direction studies' review sheets, composed from the renders.

    python3 tools/menu_proto/studies/compose.py <render dir> <out dir> [dirs]

<render dir> is render.sh's output. For each direction this writes into
<out dir>:

* <d>_0_overview.png -- the four walls as ONE device: JOURNAL | MAP |
  EQUIPMENT | SETTINGS, as the eye meets them turning right, each cut to its
  page and butted at the corner posts, so the Journal's link reads across
  the seam where it rounds the post.
* <d>_6_motion.png -- the annotated motion frames: one press of DOWN
  (before, after), and two page turns (Journal -> Map half-way, which is
  where the link rounds the corner; Equipment -> Map a third of the way).

With all four: 00_compare_equipment.png (the four Equipment screens, the
same state in each) and 00_compare_overviews.png (the four overviews).

Everything drawn here -- titles, labels, arrows, boxes -- is a REVIEW MARK in
magenta on a band or over the picture, never part of a direction. The
pictures themselves are the renders, untouched.
"""

import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

MARK = (255, 61, 242)
INK = (232, 238, 246)
DIM = (155, 165, 182)
BAND = (11, 13, 16)
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

FILL = 0.86                 # Kit.FILL: the page's share of the screen
FOCAL = 360 / math.tan(math.radians(30))   # Kit.FOV 60, in screen px

TITLES = {
    "A": "PATCHBAY / SIGNAL BENCH",
    "B": "ROUTED HARNESS / CABLE LOOM",
    "C": "RELAY CABINET / BREAKER LOGIC",
    "D": "SALVAGED ECHO WORKBENCH / PROTOTYPE BOARD",
    "H": "THE HYBRID -- ORIGINAL STATION HARDWARE, KEPT ALIVE BY EPSILON",
}

# Where each direction's Journal link rounds the corner (page y), and what
# one press of DOWN moves: the moving part's page point before and after, and
# the part that re-reads in place (a page rect). From the directions' own
# constants.
LINK_Y = {"A": 176, "B": 36, "C": 70, "D": 42, "H": 16}
RIBBON_Y = 650      # the hybrid: the rack's ribbon, Equipment -> Settings
SELECT = {
    "A": {"from": (894, 169), "to": (894, 213), "side": -34,
          "reads": (308, 168, 540, 524),
          "text": ["(1) DOWN: the teal test lead lifts out of ARC BOLT's jack and drops into "
                   "HUNTER'S DRAW's; its slack follows.",
                   "(2) The readout hanging under the key's cord re-reads in place: words "
                   "are replaced, never slid, bent or squashed.",
                   "The key's cream cord and every other jack stay still."]},
    "B": {"from": (690, 246), "to": (690, 284), "side": 30,
          "reads": (730, 108, 510, 586),
          "text": ["(1) DOWN: the teal tap slides one module down the branch; the "
                   "breakout's clip slides with it along the tag's edge.",
                   "(2) The tag re-reads in place and never swings: its strings are still, "
                   "so its words never move.",
                   "The trunk, the key loom and the branch itself do not move."]},
    "C": {"from": (575, 451), "to": (575, 484), "side": -20,
          "reads": (40, 66, 1200, 272),
          "text": ["(1) DOWN: ARC BOLT's card slides home and HUNTER'S DRAW's is pulled -- "
                   "a short, detented travel.",
                   "(2) The window's shutter drops and rises over the change, so its words "
                   "are swapped while covered.",
                   "The selector, the flag windows and the seated card do not move: "
                   "they are states, not animation."]},
    "D": {"from": (1264, 164), "to": (1264, 208), "side": 0,
          "reads": (344, 82, 552, 560),
          "text": ["(1) DOWN: ARC BOLT drops back into its tray slot; HUNTER'S DRAW lifts "
                   "out of the next one.",
                   "(2) It floats to the same reading place, connector edge towards RMB; "
                   "its words ride the board rigidly.",
                   "The main board, the headers and the outline on RMB's place stay "
                   "still."]},
}
TURN_TEXT = {
    "A": ["(3) Half-way from the Journal to the Map: the cream cord leaves the focused "
          "finding, rounds the post and plugs",
          "into the Map's bezel; the guide stroke goes on to the passage. ENTER (SHOW ON "
          "THE MAP) is the follow -- the turn",
          "happens along the cord. Q / E are plain travel: the same turn, nothing "
          "followed. Reduced motion: a cut, same frame."],
    "B": ["(3) Half-way from the Journal to the Map: the trunk runs on round the post, "
          "and the ivory link rides above it.",
          "ENTER (SHOW ON THE MAP) is the follow: a pulse runs out along the link and "
          "down into the window before the",
          "view settles. Q / E are plain travel along the same trunk, with no pulse. "
          "Reduced motion: no pulse, a cut."],
    "C": ["(3) Half-way from the Journal to the Map: the brass rod leaves the lit "
          "condition window and rounds the post",
          "above the port. ENTER (SHOW ON THE MAP) is the follow: the rod's pointer arm "
          "drops into the port over the",
          "passage as the view arrives. Q / E are plain travel: the arm stays up. "
          "Reduced motion: the arm is simply down."],
    "D": ["(3) Half-way from the Journal to the Map: the ribbon leaves the lifted "
          "finding and rounds the post along",
          "the board tops. ENTER (SHOW ON THE MAP) is the follow: its connector seats on "
          "the Map's header over the passage",
          "as the view arrives. Q / E are plain travel: nothing seats. Reduced motion: "
          "seated at once, a cut."],
}
PAGES = ["journal", "map", "equipment", "settings"]


def font(size, bold=False):
    return ImageFont.truetype(BOLD if bold else FONT, size)


def rest(p):
    """A page point on the wall, where a straight-on still shows it."""
    return (640 + (p[0] - 640) * FILL, 360 + (p[1] - 360) * FILL)


def crop_page(im):
    """The page's own rectangle out of a straight-on still."""
    return im.crop((round(640 - 640 * FILL), round(360 - 360 * FILL),
                    round(640 + 640 * FILL), round(360 + 360 * FILL)))


def arrow(d, a, b, width=4):
    d.line([a, b], fill=MARK, width=width)
    ang = math.atan2(b[1] - a[1], b[0] - a[0])
    for s in (-1, 1):
        t = ang + math.pi + s * 0.5
        d.line([b, (b[0] + 14 * math.cos(t), b[1] + 14 * math.sin(t))], fill=MARK,
               width=width)


def label(d, at, words, size=18):
    f = font(size, True)
    x, y = at
    w = d.textlength(words, font=f)
    d.rectangle([x - 6, y - 4, x + w + 6, y + size + 6], fill=(20, 8, 20))
    d.text((x, y), words, font=f, fill=MARK)


def marker(d, at, n):
    """A numbered review marker; the caption says what the number means."""
    x, y = at
    d.ellipse([x - 13, y - 13, x + 13, y + 13], fill=(20, 8, 20), outline=MARK, width=3)
    f = font(15, True)
    w = d.textlength(str(n), font=f)
    d.text((x - w / 2, y - 10), str(n), font=f, fill=MARK)


def overview(render, d, out):
    faces = [crop_page(Image.open(os.path.join(render, "_bare", f"{d}_{p}.png"))
                       .convert("RGB")) for p in PAGES]
    fw = 470
    fh = round(faces[0].height * fw / faces[0].width)
    post = 8
    top, foot, side = 74, 64, 18
    W = side * 2 + fw * 4 + post * 3
    H = top + fh + foot
    sheet = Image.new("RGB", (W, H), BAND)
    dr = ImageDraw.Draw(sheet)
    dr.text((side, 14), f"DIRECTION {d} -- {TITLES[d]}", font=font(24, True), fill=INK)
    dr.text((side, 46), "The four walls as one device, as the eye meets them turning "
            "right. Each wall cut to its page and butted at the corner post.",
            font=font(16), fill=DIM)
    for i, (p, im) in enumerate(zip(PAGES, faces)):
        x = side + i * (fw + post)
        sheet.paste(im.resize((fw, fh), Image.LANCZOS), (x, top))
        dr.text((x + 4, top + fh + 8), p.upper(), font=font(16, True), fill=INK)
        if i < 3:
            dr.rectangle([x + fw, top, x + fw + post - 1, top + fh], fill=(5, 6, 8))
    # The Journal -> Map seam, where the link rounds the post.
    sx = side + fw + post * 0.5
    sy = top + LINK_Y[d] * fw / 1280
    dr.ellipse([sx - 30, sy - 22, sx + 30, sy + 22], outline=MARK, width=3)
    label(dr, (side + fw + post + 8, top + fh + 32),
          "the Journal's link rounds this corner, into the Map", 15)
    dr.line([(sx + 10, sy + 22), (side + fw + post + 40, top + fh + 30)], fill=MARK, width=2)
    sheet.save(os.path.join(out, f"{d}_0_overview.png"), optimize=True)


def corner_y(page_y):
    """Where page height `page_y` crosses the corner post, half-way through a
    turn: the corner stands 0.87 * sqrt(2) along the eye's line."""
    world = (360 - page_y) * (2 * math.tan(math.radians(30)) * FILL / 720)
    return 360 - world / (0.8727 * math.sqrt(2)) * FOCAL


def motion(render, d, out):
    frames = [("BEFORE -- ARC BOLT inspected", f"{d}/{d}_1_equipment_normal.png"),
              ("AFTER ONE PRESS OF DOWN -- HUNTER'S DRAW inspected",
               f"{d}/{d}_m3_select_next.png"),
              ("TURN, JOURNAL -> MAP, HALF-WAY", f"{d}/{d}_m1_turn_journal_map.png"),
              ("TURN, EQUIPMENT -> MAP, A THIRD OF THE WAY",
               f"{d}/{d}_m2_turn_equipment_map.png")]
    fw, fh = 960, 540
    side, top, cap, gap = 18, 74, 118, 16
    W = side * 2 + fw * 2 + gap
    H = top + (30 + fh + cap) * 2
    sheet = Image.new("RGB", (W, H), BAND)
    dr = ImageDraw.Draw(sheet)
    dr.text((side, 14), f"DIRECTION {d} -- {TITLES[d]} -- MOTION FRAMES", font=font(24, True),
            fill=INK)
    dr.text((side, 46), "Stills of an isolated study scene. The magenta marks are review "
            "annotations, not part of the direction.", font=font(16), fill=DIM)
    k = fw / 1280
    sel = SELECT[d]
    for i, (name, path) in enumerate(frames):
        col, row = i % 2, i // 2
        x = side + col * (fw + gap)
        y = top + row * (30 + fh + cap)
        dr.text((x, y + 4), name, font=font(17, True), fill=INK)
        im = Image.open(os.path.join(render, path)).convert("RGB").resize((fw, fh),
                                                                          Image.LANCZOS)
        sheet.paste(im, (x, y + 30))
        o = (x, y + 30)
        if row == 0:
            r = sel["reads"]
            a = rest((r[0], r[1]))
            b = rest((r[0] + r[2], r[1] + r[3]))
            dr.rectangle([o[0] + a[0] * k - 4, o[1] + a[1] * k - 4, o[0] + b[0] * k + 4,
                          o[1] + b[1] * k + 4], outline=MARK, width=3)
            marker(dr, (o[0] + b[0] * k - 4, o[1] + b[1] * k - 4), 2)
            p0 = rest(sel["from"])
            p1 = rest(sel["to"])
            dx = sel["side"]
            if col == 0:
                arrow(dr, (o[0] + p0[0] * k + dx, o[1] + p0[1] * k),
                      (o[0] + p1[0] * k + dx, o[1] + p1[1] * k + 6))
                marker(dr, (o[0] + p0[0] * k + dx, o[1] + p0[1] * k - 20), 1)
        elif col == 0:
            cy = corner_y(LINK_Y[d]) * k
            dr.ellipse([o[0] + 480 - 60, o[1] + cy - 40, o[0] + 480 + 60, o[1] + cy + 40],
                       outline=MARK, width=3)
            marker(dr, (o[0] + 480 + 60, o[1] + cy - 40), 3)
    ty = top + 30 + fh + 10
    for j, line in enumerate(sel["text"]):
        dr.text((side, ty + j * 24), line, font=font(17), fill=INK)
    ty = top + (30 + fh + cap) + 30 + fh + 10
    for j, line in enumerate(TURN_TEXT[d]):
        dr.text((side, ty + j * 24), line, font=font(17), fill=INK)
    sheet.save(os.path.join(out, f"{d}_6_motion.png"), optimize=True)


def compare(render, out):
    """The two sheets to choose from: the four Equipment screens side by side
    (the same state in each), and the four overviews one above the other."""
    fw, fh, side, top, gap = 960, 540, 18, 74, 44
    W = side * 2 + fw * 2 + 16
    H = top + (fh + gap) * 2
    sheet = Image.new("RGB", (W, H), BAND)
    dr = ImageDraw.Draw(sheet)
    dr.text((side, 14), "FOUR DIRECTIONS -- EQUIPMENT, THE SAME STATE IN EACH",
            font=font(24, True), fill=INK)
    dr.text((side, 46), "RMB focused, BRAIDED LASH on it, ARC BOLT inspected against it. "
            "Each screen at full size is in the package as <d>_1_equipment_normal.png.",
            font=font(16), fill=DIM)
    for i, d in enumerate("ABCD"):
        x = side + (i % 2) * (fw + 16)
        y = top + (i // 2) * (fh + gap)
        im = Image.open(os.path.join(render, d, f"{d}_1_equipment_normal.png")).convert("RGB")
        sheet.paste(im.resize((fw, fh), Image.LANCZOS), (x, y))
        dr.text((x, y + fh + 8), f"{d} -- {TITLES[d]}", font=font(18, True), fill=INK)
    sheet.save(os.path.join(out, "00_compare_equipment.png"), optimize=True)
    ims = [Image.open(os.path.join(out, f"{d}_0_overview.png")).convert("RGB") for d in "ABCD"]
    stack = Image.new("RGB", (max(i.width for i in ims), sum(i.height for i in ims)), BAND)
    y = 0
    for im in ims:
        stack.paste(im, (0, y))
        y += im.height
    stack.save(os.path.join(out, "00_compare_overviews.png"), optimize=True)


def hybrid_overview(render, out):
    """The hybrid's cross-wall overview: the four walls as one device, with
    both joins marked -- the Journal's link into the Map, and the rack's
    ribbon from Equipment into Settings -- and under it each join seen in
    3D, half-way through its own turn."""
    d = "H"
    faces = [crop_page(Image.open(os.path.join(render, "_bare", f"{d}_{p}.png"))
                       .convert("RGB")) for p in PAGES]
    fw = 470
    fh = round(faces[0].height * fw / faces[0].width)
    post, side, top = 8, 18, 74
    tw, th = 955, 537
    W = side * 2 + fw * 4 + post * 3
    H = top + fh + 44 + 30 + th + 64
    sheet = Image.new("RGB", (W, H), BAND)
    dr = ImageDraw.Draw(sheet)
    dr.text((side, 14), f"{TITLES[d]} -- ACROSS THE WALLS", font=font(24, True), fill=INK)
    dr.text((side, 46), "The four walls as one device, as the eye meets them turning right, "
            "each cut to its page and butted at the corner post. Below, the two joins in 3D.",
            font=font(16), fill=DIM)
    xs = []
    for i, (p, im) in enumerate(zip(PAGES, faces)):
        x = side + i * (fw + post)
        xs.append(x)
        sheet.paste(im.resize((fw, fh), Image.LANCZOS), (x, top))
        dr.text((x + 4, top + fh + 8), p.upper(), font=font(16, True), fill=INK)
        if i < 3:
            dr.rectangle([x + fw, top, x + fw + post - 1, top + fh], fill=(5, 6, 8))
    k = fw / 1280
    # 1: the Journal's link rounds the Journal | Map post
    sx = xs[1] - post * 0.5
    sy = top + LINK_Y[d] * k
    dr.ellipse([sx - 30, sy - 16, sx + 30, sy + 22], outline=MARK, width=3)
    marker(dr, (sx + 34, sy + 28), 1)
    # 2: the rack's ribbon rounds the Equipment | Settings post
    sx = xs[3] - post * 0.5
    sy = top + RIBBON_Y * k
    dr.ellipse([sx - 30, sy - 22, sx + 30, sy + 22], outline=MARK, width=3)
    marker(dr, (sx + 34, sy - 28), 2)
    y2 = top + fh + 44
    turns = [("1 -- JOURNAL -> MAP, HALF-WAY: the harness and the Journal's ivory link "
              "round the post", f"{d}/{d}_m1_turn_journal_map.png"),
             ("2 -- EQUIPMENT -> SETTINGS, HALF-WAY: the rack's ribbon rounds the post "
              "into Settings", f"{d}/{d}_m4_turn_equipment_settings.png")]
    for i, (name, path) in enumerate(turns):
        x = side + i * (tw + 20)
        dr.text((x, y2), name, font=font(15, True), fill=INK)
        im = Image.open(os.path.join(render, path)).convert("RGB").resize((tw, th),
                                                                          Image.LANCZOS)
        sheet.paste(im, (x, y2 + 26))
    dr.text((side, y2 + 26 + th + 12), "Stills of an isolated art-lane study scene. The "
            "magenta marks are review annotations, not part of the design.", font=font(15),
            fill=DIM)
    sheet.save(os.path.join(out, f"{d}_0_overview.png"), optimize=True)


def main():
    render, out = sys.argv[1], sys.argv[2]
    dirs = sys.argv[3] if len(sys.argv) > 3 else "ABCD"
    os.makedirs(out, exist_ok=True)
    for d in dirs:
        if d == "H":
            hybrid_overview(render, out)
            print(f"compose: H -> {out}/H_0_overview.png")
            continue
        overview(render, d, out)
        motion(render, d, out)
        print(f"compose: {d} -> {out}/{d}_0_overview.png, {d}_6_motion.png")
    if dirs == "ABCD":
        compare(render, out)
        print(f"compose: -> {out}/00_compare_equipment.png, 00_compare_overviews.png")


if __name__ == "__main__":
    main()
