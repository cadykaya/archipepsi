"""The charger, re-proposed as poses (Arty, 2026-10-08). A DRAWING, not a model.

    python3 tools/crossing_capture/charger_proposal.py OUT.png

Side-view silhouettes, each inside the charger's unchanged collider
envelope (Constants.ENEMY_ENVELOPES["charger"]: 1.9 m long, 1.05 m tall),
drawn dashed. Original shapes: a low "ram-sled" -- a shovel prow, a hull
that rises to a rear hump, four splayed legs, three dorsal vanes that
flare when it winds up, and a rear vent that opens while it recovers.
Deferred until Prod and Dess agree the charger's commit and recovery;
this is what the art would serve, not a build.
"""

import sys

from PIL import Image, ImageDraw, ImageFont

PX = 150                    # pixels per metre
ENV = (1.9, 1.05)           # the collider: length, height
INK = (24, 22, 28)
EYE = (255, 90, 40)
VENT = (255, 150, 60)


def pose(dx=0.0, lift_rear=0.0, lift_front=0.0, vanes=0.0, stretch=1.0,
         legs="stand", vent=False, eye=0.5):
    """Polygons in metres, x forward (right), y up, ground at 0."""
    def hull_y(x):
        # Front of the hull at x = 1.75, rear at 0.15 (in the envelope).
        t = (x - 0.15) / 1.6
        return lift_rear * (1 - t) + lift_front * t
    shapes = []
    hull = []
    for x, y in [(0.15, 0.42), (0.35, 0.86), (0.85, 0.92), (1.35, 0.72),
                 (1.80, 0.40), (1.86, 0.26), (1.55, 0.30), (0.20, 0.30)]:
        xs = 0.95 + (x - 0.95) * stretch + dx
        hull.append((xs, y + hull_y(x)))
    shapes.append(("hull", hull, INK))
    # The shovel prow.
    p = [(1.70, 0.36), (1.92, 0.10), (1.98, 0.12), (1.82, 0.44)]
    shapes.append(("prow", [(0.95 + (x - 0.95) * stretch + dx,
                             y + hull_y(1.8)) for x, y in p], INK))
    # Dorsal vanes: three plates, angle set by `vanes` (0 flat, 1 up).
    for i, x0 in enumerate((0.45, 0.70, 0.95)):
        h = 0.10 + 0.32 * vanes
        lean = 0.22 * (1 - vanes) + 0.05
        base_y = 0.86 - i * 0.03 + hull_y(x0)
        v = [(x0, base_y), (x0 + 0.16, base_y),
             (x0 - lean + 0.10, base_y + h), (x0 - lean, base_y + h * 0.8)]
        shapes.append(("vane", [(0.95 + (x - 0.95) * stretch + dx, y)
                                for x, y in v], INK))
    # Legs: pairs at 0.45 and 1.35; "stand", "bunch", "drive", "splay".
    feet = {"stand": [(0.35, 0.0), (1.45, 0.0)],
            "bunch": [(0.60, 0.0), (1.20, 0.0)],
            "drive": [(0.0, 0.05), (1.75, 0.0)],
            "splay": [(0.15, 0.0), (1.70, 0.0)]}[legs]
    for (hip_x, foot) in zip((0.45, 1.35), feet):
        hx = 0.95 + (hip_x - 0.95) * stretch + dx
        hy = 0.34 + hull_y(hip_x)
        fx, fy = foot[0] + dx, foot[1]
        knee = ((hx + fx) / 2 + (0.12 if hip_x < 1 else -0.12), hy + 0.06)
        for a, b in ((hx, hy), knee), (knee, (fx, fy)):
            shapes.append(("leg", [a, b], INK))
    eye_at = (0.95 + (1.62 - 0.95) * stretch + dx, 0.55 + hull_y(1.62))
    shapes.append(("eye", eye_at, tuple(int(40 + (c - 40) * eye)
                                        for c in EYE)))
    if vent:
        vx = 0.95 + (0.30 - 0.95) * stretch + dx
        shapes.append(("vent", [(vx, 0.48 + hull_y(0.3)),
                                (vx + 0.22, 0.62 + hull_y(0.3)),
                                (vx + 0.22, 0.72 + hull_y(0.3)),
                                (vx - 0.02, 0.62 + hull_y(0.3))], VENT))
    return shapes


POSES = [
    ("IDLE / PROWL", "level, vanes flat, nose low:\nsniffing the floor",
     pose()),
    ("WIND-UP 0.8 s", "rear up, legs bunched, vanes\nflared, eye bright: it WILL go",
     pose(lift_rear=0.08, lift_front=-0.06, vanes=1.0, legs="bunch", eye=1.0)),
    ("COMMIT (rush)", "stretched, legs driving, vanes\nswept back: it cannot turn",
     pose(stretch=1.04, dx=-0.02, lift_front=-0.04, vanes=0.0, legs="drive",
          eye=1.0)),
    ("RECOVER 1.2 s", "nose down, splayed, rear vent\nopen and hot: punish now",
     pose(lift_rear=0.05, lift_front=-0.08, vanes=0.2, legs="splay",
          vent=True, eye=0.2)),
]


def main(out):
    cell_w, cell_h = int(2.4 * PX), int(1.7 * PX) + 70
    sheet = Image.new("RGB", (cell_w * 4 + 40, cell_h + 120), (236, 236, 232))
    draw = ImageDraw.Draw(sheet)
    try:
        title = ImageFont.truetype("DejaVuSans-Bold.ttf", 20)
        font = ImageFont.truetype("DejaVuSans.ttf", 14)
    except OSError:
        title = font = ImageFont.load_default()
    draw.text((20, 14), "CHARGER, PROPOSED (deferred): one silhouette, four "
              "readable beats, same 1.9 x 1.05 m collider (dashed)",
              fill=INK, font=title)
    draw.text((20, 42), "Today: a riveted box on legs (Batch 030). Proposal: "
              "the shape tells you when to move. Drawing only -- no model "
              "until the encounter's commit and recovery are agreed.",
              fill=(70, 70, 76), font=font)
    for i, (name, note, shapes) in enumerate(POSES):
        ox, oy = 20 + i * (cell_w + 0), 90 + int(1.45 * PX)

        def P(x, y):
            return (ox + int((x + 0.15) * PX), oy - int(y * PX))

        # The envelope, dashed.
        x0, y0 = P(0.0, 0.0)
        x1, y1 = P(ENV[0], ENV[1])
        for x in range(x0, x1, 10):
            draw.line([(x, y0), (x + 5, y0)], fill=(150, 150, 160))
            draw.line([(x, y1), (x + 5, y1)], fill=(150, 150, 160))
        for y in range(y1, y0, 10):
            draw.line([(x0, y), (x0, y + 5)], fill=(150, 150, 160))
            draw.line([(x1, y), (x1, y + 5)], fill=(150, 150, 160))
        draw.line([P(-0.1, 0), P(2.05, 0)], fill=(120, 120, 128), width=2)
        for kind, data, colour in shapes:
            if kind == "leg":
                draw.line([P(*data[0]), P(*data[1])], fill=colour, width=9)
            elif kind == "eye":
                cx, cy = P(*data)
                draw.ellipse([cx - 7, cy - 4, cx + 7, cy + 4], fill=colour)
            else:
                draw.polygon([P(*v) for v in data], fill=colour)
        draw.text((ox + 4, oy + 12), name, fill=INK, font=title)
        draw.multiline_text((ox + 4, oy + 40), note, fill=(60, 60, 66),
                            font=font)
    sheet.save(out)
    print("[charger] %s" % out)


if __name__ == "__main__":
    main(sys.argv[1])
