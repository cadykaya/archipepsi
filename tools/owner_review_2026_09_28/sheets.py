#!/usr/bin/env python3
"""Owner review, 2026-09-28 -- the sheet composer.

Isolated review helper. It reads existing images and writes new review
sheets. It never touches a source asset, a shared builder, a shipping
export or an approval flag.

A sheet is data: a title, the four statuses (kept apart on purpose),
rows of image panels with a caption and an evidence tag each, and the
decision box. Phone-first: 1400 px wide, body text at 24 px, two panels a
row at most.

    from sheets import Sheet
    s = Sheet("A1 -- held controls", "what the owner decides")
    s.statuses(visual="PENDING", compat="...", binding="none", play="no")
    s.row([Panel(path, "caption", tag="POSED")])
    s.decision(ask="...", recommend="...", risk="...", engineering="...")
    s.save(out_path)
"""
from __future__ import annotations

import os
import textwrap
from dataclasses import dataclass, field

from PIL import Image, ImageDraw, ImageFont

W = 1400
PAD = 28
GAP = 18
BG = (18, 20, 23)
CARD = (29, 32, 37)
INK = (236, 238, 240)
DIM = (170, 176, 184)
FAINT = (120, 126, 134)
RULE = (58, 63, 70)

FONT_DIR = "/usr/share/fonts/truetype/dejavu"


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    name = "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"
    return ImageFont.truetype(os.path.join(FONT_DIR, name), size)


F_TITLE = font(40, True)
F_SUB = font(24)
F_HEAD = font(26, True)
F_BODY = font(23)
F_SMALL = font(19)
F_TAG = font(17, True)

# The evidence tags. A posed reference is never passed off as a live
# test, and a render is never passed off as integrated gameplay.
TAGS = {
    "RUNTIME": ((46, 125, 84), "RUNTIME-DRIVEN · Production c12a72f"),
    "PLACEHOLDER": ((52, 92, 140), "CURRENT GAME PLACEHOLDER · Production c12a72f"),
    "POSED": ((150, 104, 28), "POSED REFERENCE STATE · not a live test"),
    "RENDER": ((92, 96, 104), "ART RENDER · review scene, not gameplay"),
    "PLAN": ((92, 96, 104), "PLAN / SECTION · from the manifest"),
    "NEW": ((118, 72, 146), "NEW REVIEW RENDER · 2026-09-28, review scene"),
}

# Status chips: the four statuses stay separate. Colour says how far
# along each is; the words say exactly what is true.
STATE_COL = {
    "yes": (46, 125, 84),
    "partial": (150, 104, 28),
    "pending": (150, 104, 28),
    "no": (120, 50, 50),
    "held": (120, 50, 50),
    "none": (70, 74, 80),
    "unknown": (70, 74, 80),
}
STATUS_NAMES = [
    ("visual", "VISUAL APPROVAL"),
    ("compat", "TECHNICAL COMPATIBILITY"),
    ("binding", "RUNTIME BINDING"),
    ("play", "IN NORMAL GAMEPLAY"),
]


def wrap(draw: ImageDraw.ImageDraw, text: str, f, width: int) -> list[str]:
    """Wrap by measured pixels, not characters."""
    out: list[str] = []
    for para in text.split("\n"):
        words = para.split(" ")
        line = ""
        for w in words:
            trial = (line + " " + w).strip()
            if draw.textlength(trial, font=f) <= width:
                line = trial
            else:
                if line:
                    out.append(line)
                line = w
        out.append(line)
    return out


@dataclass
class Panel:
    path: str
    caption: str = ""
    tag: str = "RENDER"
    crop: tuple | None = None       # (l, t, r, b) in source pixels
    note: str = ""                  # small grey line under the caption


@dataclass
class Sheet:
    title: str
    subtitle: str = ""
    blocks: list = field(default_factory=list)

    # ---- content
    def statuses(self, **kw) -> None:
        """kw: visual=(state, words), compat=..., binding=..., play=..."""
        self.blocks.append(("status", kw))

    def text(self, heading: str, body: str) -> None:
        self.blocks.append(("text", (heading, body)))

    def row(self, panels: list[Panel]) -> None:
        self.blocks.append(("row", panels))

    def decision(self, ask: str, recommend: str, risk: str,
                 engineering: str) -> None:
        self.blocks.append(("decision", (ask, recommend, risk, engineering)))

    def footer(self, text: str) -> None:
        self.blocks.append(("footer", text))

    # ---- layout
    def _measure(self) -> int:
        probe = ImageDraw.Draw(Image.new("RGB", (W, 10)))
        h = PAD + self._head_h(probe)
        for kind, data in self.blocks:
            h += self._block(kind, data, None, 0, probe) + GAP
        return h + PAD

    def _head_h(self, d) -> int:
        h = 52
        if self.subtitle:
            h += 34 * len(wrap(d, self.subtitle, F_SUB, W - 2 * PAD)) + 6
        return h + 12

    def save(self, out: str, quality: int = 90) -> str:
        H = self._measure()
        img = Image.new("RGB", (W, H), BG)
        d = ImageDraw.Draw(img)
        y = PAD
        d.text((PAD, y), self.title, fill=INK, font=F_TITLE)
        y += 52
        if self.subtitle:
            for line in wrap(d, self.subtitle, F_SUB, W - 2 * PAD):
                d.text((PAD, y), line, fill=DIM, font=F_SUB)
                y += 34
            y += 6
        y += 12
        for kind, data in self.blocks:
            y += self._block(kind, data, img, y, d) + GAP
        os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
        if out.lower().endswith(".jpg"):
            img.save(out, quality=quality, subsampling=0, optimize=True)
        else:
            img.save(out, optimize=True)
        return out

    def _block(self, kind, data, img, y, d) -> int:
        draw = img is not None
        x0, inner = PAD, W - 2 * PAD
        if kind == "status":
            cw = (inner - 3 * 12) // 4
            h = 0
            for i, (key, label) in enumerate(STATUS_NAMES):
                state, words = data.get(key, ("unknown", "not recorded"))
                lines = wrap(d, words, F_SMALL, cw - 24)
                bh = 16 + 24 + 8 + 25 * len(lines) + 14
                h = max(h, bh)
            if draw:
                for i, (key, label) in enumerate(STATUS_NAMES):
                    state, words = data.get(key, ("unknown", "not recorded"))
                    x = x0 + i * (cw + 12)
                    d.rounded_rectangle([x, y, x + cw, y + h], 10, fill=CARD)
                    d.rectangle([x, y, x + 8, y + h], fill=STATE_COL.get(state, STATE_COL["unknown"]))
                    d.text((x + 20, y + 14), label, fill=DIM, font=F_TAG)
                    yy = y + 14 + 24 + 8
                    for line in wrap(d, words, F_SMALL, cw - 24):
                        d.text((x + 20, yy), line, fill=INK, font=F_SMALL)
                        yy += 25
            return h
        if kind == "text":
            heading, body = data
            lines = wrap(d, body, F_BODY, inner)
            h = (36 if heading else 0) + 32 * len(lines)
            if draw:
                yy = y
                if heading:
                    d.text((x0, yy), heading, fill=INK, font=F_HEAD)
                    yy += 36
                for line in lines:
                    d.text((x0, yy), line, fill=DIM if heading else INK, font=F_BODY)
                    yy += 32
            return h
        if kind == "row":
            panels: list[Panel] = data
            n = len(panels)
            pw = (inner - (n - 1) * GAP) // n
            ims = []
            for p in panels:
                im = Image.open(p.path).convert("RGB")
                if p.crop:
                    im = im.crop(p.crop)
                ims.append(im.resize((pw, int(im.height * pw / im.width)), Image.LANCZOS))
            ih = max(im.height for im in ims)
            cap_h = 0
            for p in panels:
                c = 30 * len(wrap(d, p.caption, F_BODY, pw)) if p.caption else 0
                c += 26 * len(wrap(d, p.note, F_SMALL, pw)) if p.note else 0
                cap_h = max(cap_h, c)
            h = 28 + ih + 8 + cap_h
            if draw:
                for i, (p, im) in enumerate(zip(panels, ims)):
                    x = x0 + i * (pw + GAP)
                    col, words = TAGS.get(p.tag, TAGS["RENDER"])
                    d.rectangle([x, y, x + pw, y + 26], fill=col)
                    d.text((x + 10, y + 3), words, fill=INK, font=F_TAG)
                    img.paste(im, (x, y + 28))
                    yy = y + 28 + ih + 8
                    for line in wrap(d, p.caption, F_BODY, pw) if p.caption else []:
                        d.text((x, yy), line, fill=INK, font=F_BODY)
                        yy += 30
                    for line in wrap(d, p.note, F_SMALL, pw) if p.note else []:
                        d.text((x, yy), line, fill=FAINT, font=F_SMALL)
                        yy += 26
            return h
        if kind == "decision":
            ask, rec, risk, eng = data
            rows = [("DECISION", ask, (255, 216, 77)), ("RECOMMEND", rec, INK),
                    ("COST / RISK", risk, DIM), ("ENGINEERING AFTER", eng, DIM)]
            lab = 230
            h = 20
            for _, body, _ in rows:
                h += 31 * len(wrap(d, body, F_BODY, inner - lab - 40)) + 10
            h += 10
            if draw:
                d.rounded_rectangle([x0, y, x0 + inner, y + h], 12, fill=(38, 34, 20),
                                    outline=(255, 216, 77), width=2)
                yy = y + 20
                for label, body, col in rows:
                    d.text((x0 + 20, yy + 2), label, fill=(255, 216, 77), font=F_TAG)
                    for line in wrap(d, body, F_BODY, inner - lab - 40):
                        d.text((x0 + lab, yy), line, fill=col, font=F_BODY)
                        yy += 31
                    yy += 10
            return h
        if kind == "footer":
            lines = wrap(d, data, F_SMALL, inner)
            h = 10 + 25 * len(lines)
            if draw:
                d.line([x0, y, x0 + inner, y], fill=RULE, width=1)
                yy = y + 10
                for line in lines:
                    d.text((x0, yy), line, fill=FAINT, font=F_SMALL)
                    yy += 25
            return h
        raise ValueError(kind)
