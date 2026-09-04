"""One phone-readable PDF of the whole authored room library, annotated.

    python3 tools/shots/make_review_pdf.py [out.pdf]

WHY. The review packages are directories of 1920x1080 PNGs with a README
beside them. That is the right shape for a workstation and the wrong
shape for a phone, where the useful unit is ONE picture with the words
that explain it directly underneath, and a thumb to scroll with.

Every image here is an actual shipped render -- nothing is redrawn,
recomposed or cropped. The page is deliberately narrow so that a phone
fitting it to screen width shows each render at the largest size the
format allows; pinch to zoom for detail.

The numbers in the notes are read from the SHIPPED MANIFESTS at build
time, not typed in, so a note cannot quietly disagree with the room it
describes. The prose is authored.
"""

from __future__ import annotations

import json
import math
import os
import sys

from PIL import Image as PILImage
from reportlab.lib.colors import HexColor
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas as pdfcanvas
from reportlab.platypus import Paragraph

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HALL = os.path.join(ROOT, "docs/art/review/hall_67add07")
WAVE1 = os.path.join(ROOT, "docs/art/review/wave1")
CACHE = os.path.join(ROOT, ".pdfcache")

# --- page -----------------------------------------------------------
# 110 mm wide is close to a phone's own proportions, so a reader fitting
# the page to screen width wastes almost nothing on margins. Page HEIGHT
# is computed per page from the content (see `Book`). Images run edge to
# edge because on a fit-to-width reader the displayed size of a picture
# depends only on its share of the page WIDTH -- a margin beside a render
# is detail thrown away.
PW = 110 * mm
#: A floor, so a two-line page is not a stub, and the top inset used when
#: a page does not open with a full-bleed render.
PH_MIN = 120 * mm
TOP = 9 * mm
MARGIN = 8 * mm
COL = PW - 2 * MARGIN
IMG_H = PW * 9.0 / 16.0

BG = HexColor("#0e1013")
PANEL = HexColor("#171a20")
TEXT = HexColor("#d9dce1")
DIM = HexColor("#868c96")
AMBER = HexColor("#f0b429")
GREEN = HexColor("#86c46a")
ORANGE = HexColor("#e8894a")


def style(name, size, leading, colour, bold=False, space=0):
    return ParagraphStyle(
        name, fontName="Helvetica-Bold" if bold else "Helvetica",
        fontSize=size, leading=leading, textColor=colour, spaceAfter=space)


S_BODY = style("body", 8.4, 11.6, TEXT, space=1)
S_LABEL = style("label", 6.6, 8.6, AMBER, bold=True)
S_TITLE = style("title", 12.5, 15.0, TEXT, bold=True)
S_KICKER = style("kicker", 7.0, 9.0, DIM, bold=True)
S_BIG = style("big", 19.0, 22.0, TEXT, bold=True)
S_APPROVE = style("approve", 8.4, 11.6, GREEN)
S_CHANGE = style("change", 8.4, 11.6, ORANGE)


# --- facts, read from the shipped manifests --------------------------

def manifests():
    out = {}
    for batch in ("batch039", "batch040"):
        path = os.path.join(ROOT, "assets/models", batch, "shells/manifest.json")
        out.update(json.load(open(path)))
    return out


M = manifests()


def rail(cid):
    """(control points, baked-free length, low y, high y) for the rail."""
    for o in M[cid]["offers"]:
        if o["kind"] == "rail_route":
            p = o["points"]
            length = sum(math.dist(p[i], p[i + 1]) for i in range(len(p) - 1))
            return len(p), length, min(q[1] for q in p), max(q[1] for q in p)
    return None


def launch(cid):
    """Straight-line distance between the declared source and target."""
    src = [o for o in M[cid]["offers"] if o["kind"] == "launch_source"]
    if not src:
        return None
    tgt = [o for o in M[cid]["offers"] if o["name"] == src[0]["target"]][0]
    return math.dist(src[0]["position"], tgt["position"])


def grapples(cid):
    return [o for o in M[cid]["offers"] if o["kind"] == "grapple_point"]


def counts(cid):
    h = M[cid]
    return (len(h["surfaces"]), len(h["traversal"]), h["colliders"],
            sorted({t["kind"] for t in h["traversal"]}))


def facts(cid):
    """The one-line fact strip every room card carries."""
    surf, trav, col, kinds = counts(cid)
    n, length, lo, hi = rail(cid)
    g = len(grapples(cid))
    size = M[cid]["size"]
    return [
        ("SIZE", "%.1f x %.1f x %.1f m" % tuple(size)),
        ("DECLARED", "%d stand surfaces, %d route segments (%s), "
                     "%d collision pieces" % (surf, trav, "/".join(kinds), col)),
        ("RAIL", "%d control points, %.1f m, y %.1f to %.1f"
                 % (n, length, lo, hi)),
        ("LAUNCH", "one pair, %.1f m apart" % launch(cid)),
        ("GRAPPLE", ("%d anchor points" % g) if g else
                    "NONE DECLARED -- see my note"),
    ]


# --- drawing ---------------------------------------------------------

def prepared(path):
    """A phone-sized JPEG of a shipped render. Resized, never cropped."""
    os.makedirs(CACHE, exist_ok=True)
    out = os.path.join(CACHE, os.path.basename(path).replace(".png", ".jpg"))
    if not os.path.exists(out):
        im = PILImage.open(path).convert("RGB")
        im = im.resize((1400, int(1400 * im.height / im.width)),
                       PILImage.LANCZOS)
        im.save(out, "JPEG", quality=86, optimize=True)
    return out


class Book(object):
    """Pages built in two passes: measure the content, then size the page.

    EVERY PAGE IS EXACTLY AS TALL AS WHAT IS ON IT. A fixed page height
    would mean either clipping the long notes or scrolling through a
    hand's width of empty background after the short ones, and on a phone
    the second is nearly as annoying as the first. Since the page WIDTH
    is what a reader fits to the screen, varying the height costs the
    renders nothing: they are displayed at the same size on every page.
    """

    def __init__(self, path):
        self.c = pdfcanvas.Canvas(path, pagesize=(PW, PH_MIN))
        self.c.setTitle("Archipepsi -- the authored room library")
        self.c.setAuthor("Art lane")
        self.blocks = []

    # -- collecting ---------------------------------------------------

    def para(self, text, st, gap=3):
        self.blocks.append(("para", text, st, gap))

    def note(self, label, text, st=None):
        self.para(label, S_LABEL, gap=1.5)
        self.para(text, st or S_BODY, gap=5)

    def rule(self, colour=None, gap=6):
        self.blocks.append(("rule", None, colour or HexColor("#2a2f38"), gap))

    def image(self, path):
        self.blocks.append(("image", prepared(path), None, 7 * mm))

    # -- emitting -----------------------------------------------------

    def _height(self, block):
        kind, a, b, _gap = block
        if kind == "image":
            return IMG_H
        if kind == "rule":
            return 0.0
        return Paragraph(a, b).wrapOn(self.c, COL, 10000)[1]

    def flush(self):
        """Measure everything collected, size the page to it, draw it."""
        if not self.blocks:
            return
        content = sum(self._height(b) + b[3] for b in self.blocks)
        height = max(PH_MIN, content + MARGIN + TOP)
        self.c.setPageSize((PW, height))
        self.c.setFillColor(BG)
        self.c.rect(0, 0, PW, height, stroke=0, fill=1)
        y = height - (0.0 if self.blocks[0][0] == "image" else TOP)
        for kind, a, b, gap in self.blocks:
            if kind == "image":
                self.c.drawImage(a, 0, y - IMG_H, width=PW, height=IMG_H,
                                 preserveAspectRatio=False, mask=None)
                y -= IMG_H + gap
            elif kind == "rule":
                self.c.setStrokeColor(b)
                self.c.setLineWidth(0.6)
                self.c.line(MARGIN, y, PW - MARGIN, y)
                y -= gap
            else:
                p = Paragraph(a, b)
                _, h = p.wrapOn(self.c, COL, 10000)
                p.drawOn(self.c, MARGIN, y - h)
                y -= h + gap
        if y < MARGIN - 0.5:
            raise SystemExit(
                "[pdf] FAIL -- page %d overran its measured height by %.2f mm; "
                "the measure pass and the draw pass disagree"
                % (self.c.getPageNumber(), (MARGIN - y) / mm))
        self.c.showPage()
        self.blocks = []

    def save(self):
        self.flush()
        self.c.save()


def plate(book, image, title, kicker, notes):
    """One render, and the words that explain it, underneath."""
    book.flush()
    book.image(image)
    book.para(kicker, S_KICKER, gap=2)
    book.para(title, S_TITLE, gap=5)
    book.rule()
    for label, text in notes:
        st = S_BODY
        if label.startswith("MY CALL"):
            st = S_APPROVE if text.startswith("Approve") else S_CHANGE
        book.note(label, text, st)


def card(book, cid, title, subtitle, distinct, route, offers, verdict):
    book.flush()
    book.para(subtitle, S_KICKER, gap=3)
    book.para(title, S_BIG, gap=8)
    book.rule(AMBER, gap=8)
    for label, value in facts(cid):
        book.note(label, value)
    book.rule()
    book.note("WHAT MAKES THIS ROOM DIFFERENT", distinct)
    book.note("THE INTENDED ROUTE", route)
    book.note("RAIL, LAUNCH AND GRAPPLE", offers)
    book.note("WHAT I THINK WE SHOULD DO", verdict,
              S_APPROVE if verdict.startswith("Approve") else S_CHANGE)


sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from review_pdf_text import COVER, HOWTO, ROOMS, DECISIONS   # noqa: E402


def main(argv):
    out = argv[1] if len(argv) > 1 else os.path.join(
        ROOT, "docs/art/review/ROOM_LIBRARY_REVIEW.pdf")
    book = Book(out)

    # cover
    book.para(COVER["kicker"], S_KICKER, gap=4)
    book.para(COVER["title"], S_BIG, gap=8)
    book.rule(AMBER, gap=8)
    for label, text in COVER["notes"]:
        book.note(label, text)

    # how to read it, and the decision list up front
    book.flush()
    book.para(HOWTO["kicker"], S_KICKER, gap=3)
    book.para(HOWTO["title"], S_TITLE, gap=6)
    book.rule()
    for label, text in HOWTO["notes"]:
        book.note(label, text)

    for group in DECISIONS:
        book.flush()
        book.para(group["kicker"], S_KICKER, gap=3)
        book.para(group["title"], S_TITLE, gap=6)
        book.rule(AMBER)
        for kind, head, body in group["items"]:
            book.note(head, body, S_APPROVE if kind == "approve" else
                      (S_CHANGE if kind == "change" else S_BODY))

    for room in ROOMS:
        card(book, room["id"], room["title"], room["subtitle"],
             room["distinct"], room["route"], room["offers"], room["verdict"])
        for shot in room["shots"]:
            plate(book, os.path.join(ROOT, room["dir"], shot["file"]),
                  shot["title"], shot["kicker"], shot["notes"])

    book.save()
    pages = book.c.getPageNumber() - 1
    print("[pdf] %s  %d pages  %.1f MB"
          % (os.path.relpath(out, ROOT), pages,
             os.path.getsize(out) / 1e6))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
