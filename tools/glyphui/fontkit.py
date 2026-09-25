#!/usr/bin/env python3
"""Authoring a bitmap FACE in Glyph: the part every face does the same.

`author_numerals.py` proved the pipeline and `author_text.py` needs the
identical one with a different alphabet, so it lives here once. What is
face-specific stays in the calling script: the glyph rows, the cell, the
baseline, and which characters are in it.

The two process-lifetime rules that shape this are in `glyphrun.py`; the
one that shapes THIS file is the third: `export.define_preset`,
`x-glyph.check_font`, `x-glyph.bitmap_font` and `export.run` must be one
batch, because a preset dies with the server that declared it and all
three of the others consume it.
"""

from __future__ import annotations

import json
import os


def advance_of(rows):
    """The pen's travel: past the rightmost ink in ANY row.

    Ink starts at x = 1, so a glyph whose widest row's last `#` is at
    index `i` has ink out to x = i + 1 and the pen must reach i + 2. The
    blank column between two glyphs is the NEXT glyph's left bearing,
    which is why no second column is added.

    A blank glyph -- the space -- has no ink to measure, so it is given
    a width of its own by the caller through `blank_advance`.
    """
    widest = max((row.rindex("#") for row in rows if "#" in row), default=None)
    return None if widest is None else widest + 2


def runs_for(rows, baseline):
    """Contiguous ink runs as ((x0, y), (x1, y)), one draw call each.

    Per run rather than per pixel: a transaction per pixel is a minute
    of node startup for nothing.
    """
    out = []
    for dy, row in enumerate(rows):
        y = baseline - len(rows) + dy
        x = 1
        while x - 1 < len(row):
            if row[x - 1] == "#":
                start = x
                while x - 1 < len(row) and row[x - 1] == "#":
                    x += 1
                out.append(((start, y), (x - 1, y)))
            else:
                x += 1
    return out


def build_face(ses, work, face, variant_name, characters, glyphs,
               cell, baseline, advances, sheet=128, log=print):
    """Author one face and return (check, written, export_record).

    Raises SystemExit if `x-glyph.check_font` finds a fault: a font
    whose glyphs disagree with their own metrics is written anyway by
    `bitmap_font`, and shipping it would put the disagreement in the
    engine instead of in this output.
    """
    width, height = cell
    txn = ses.txn

    made = txn({"creates": ["asset", "palette", "variant"]}, [
        ("palette.create", {"entries": [
            {"name": "ink", "value": {"r": 232, "g": 238, "b": 246, "a": 255}},
        ]}),
        ("asset.create", {"name": face}),
    ], "the interface family's ink")
    palette = made[0]["palette"]["id"]
    entry = made[0]["palette"]["order"][0]
    asset = made[1]["asset"]["id"]

    made = txn({"creates": ["variant"]}, [
        ("variant.create", {"name": variant_name, "width": width,
                            "height": height, "color_mode": "indexed",
                            "palette": palette, "asset": asset,
                            "representation": "glyph"}),
    ], "the %s canvas" % variant_name)
    variant = made[0]["variant"]["id"]
    frames = list(made[0]["variant"]["frames"])
    cels = list(made[0]["variant"]["cels"])

    for i in range(1, len(characters)):
        made = txn({"variants": [variant]}, [
            ("frame.create", {"variant": variant, "position": i}),
        ], "frame %d" % i)
        frames.append(made[0]["frame"]["id"])
        cels.append(made[0]["cels"][0]["cel"])
    log("[ui] %d frame(s) for %d character(s)"
        % (len(frames), len(characters)))

    drawn = 0
    for i, ch in enumerate(characters):
        steps = [
            ("pixels.draw", {"cel": cels[i], "shape": "line",
                             "points": [list(a), list(b)],
                             "value": {"entry": entry}})
            for a, b in runs_for(glyphs[ch], baseline)
        ]
        if not steps:
            # A blank glyph still needs its frame and its advance; it
            # just has nothing to draw, and an empty transaction is
            # refused rather than being a no-op.
            continue
        txn({"cels": [cels[i]]}, steps, "glyph %r" % ch)
        drawn += 1
    log("[ui] %d glyph(s) drawn (%d blank)"
        % (drawn, len(characters) - drawn))

    for name, role, at in (
            ("baseline", "typography",
             {frames[i]: [0, baseline] for i in range(len(characters))}),
            ("advance", "typography",
             {frames[i]: [advances[c], 0]
              for i, c in enumerate(characters)})):
        txn({"variants": [variant], "semantics": True}, [
            ("anchor.set", {"variant": variant, "name": name,
                            "role": role, "positions": at}),
        ], "the %s" % name)
    log("[ui] baseline and advance declared on every glyph")

    preset_spec = ses.sheet_preset(face, [variant], sheet, sheet)
    font_args = {"preset": "$1.preset", "characters": characters,
                 "baseline_anchor": "baseline", "advance_anchor": "advance"}
    results = ses.batch([
        {"command": "export.define_preset", "input": preset_spec},
        {"command": "x-glyph.check_font", "input": font_args},
        {"command": "x-glyph.bitmap_font", "input": font_args},
        {"command": "export.run",
         "input": {"preset": "$1.preset", "destination": work}},
    ], label="font")
    check, written, exported = results[1], results[2], results[3]

    faults = check.get("faults", [])
    for f in faults:
        log("[ui] FONT FAULT: %s %r %s"
            % (f.get("kind"), f.get("character"), f.get("detail")))
    if faults:
        raise SystemExit("[ui] the alphabet disagrees with itself; "
                         "the .fnt was written anyway and must not ship")
    log("[ui] check_font: no faults across %d glyph(s)"
        % len(check.get("measures", [])))

    with open(os.path.join(work, "%s.fnt.json" % face), "w") as fh:
        json.dump(written, fh, indent=2, sort_keys=True)
    return check, written, exported


def write_files(ses, work, out_dir, written, record, label, log=print):
    """Write the sheet and the `.fnt`, and prove the page is there.

    `export.run` returns bytes and writes nothing, so the CLI's own
    `export` subcommand does the writing from the export record's
    `preset_declaration` -- the documented way to re-run a preset whose
    id died with its server.
    """
    ses.write_export(record, label=label)
    fnt = written["fnt"] if "fnt" in written else written["font"]["fnt"]
    with open(os.path.join(work, fnt["suggested_path"]), "w") as fh:
        fh.write(fnt["text"])
    page = os.path.basename(fnt["text"].split('file="', 1)[1].split('"', 1)[0])
    if not os.path.exists(os.path.join(work, page)):
        raise SystemExit("the .fnt cites page %r and no such file was "
                         "written; exported: %s"
                         % (page, sorted(os.listdir(work))))
    log("[ui] wrote %s and its page %s" % (fnt["suggested_path"], page))
    return fnt["suggested_path"], page
