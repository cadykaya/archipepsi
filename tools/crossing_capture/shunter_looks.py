"""The Shunter look sheet: capture specs, measures and sheets.
DISPOSABLE CONCEPT, REVIEW ONLY. (Arty, 2026-10-17.)

    python3 tools/crossing_capture/shunter_looks.py specs GLB_DIR SPEC_DIR
    python3 tools/crossing_capture/shunter_looks.py sheets SHOTS_DIR OUT_DIR

`specs` writes one `dcap.gd` spec per look and state
(`study_shunter_looks.py`'s 36 GLBs), plus `empty.json`, the same yard with
no Shunter, as the background the silhouettes are measured against.
Every pose stands alone at the 2026-10-09 pose study's spot in Crossing
D's empty yard, facing the player, and is photographed from that study's
cameras, at the game's own 90-degree view:

  F20  front, 20 m: where it notices you (the horn has to read here);
       1.2 m east of the pose study's spot, where a yard column hid half
       the pose
  F14  front, 14 m: the rush reach (the brace has to read here)
  S8   side, 8 m: the silhouette a flanking player sees
  R6   rear quarter, 6 m: where a sidestepped player stands (the vents)

`sheets` cuts every shot to the pose (the pose study's crops, enlarged
nearest-neighbour, so nothing is invented) and lays out one sheet per
camera: looks down, states across, the numbers beside each cell.

The numbers:
  * on WORK: the silhouette, the pixels that differ from the empty yard
    by more than 24 grey levels (how much Shunter there is to see);
  * on NOTICE, BRACE and RECOVER: the pixels that differ from the same
    look's WORK frame by more than 24 grey levels (how loudly the state
    reads). The BRACE is measured on a lane-less copy of the pose: the
    lit lane is the same in every look and would swamp the body's change;
    the sheets show it with the lane. 0 means the player cannot tell the state from work, in grey,
    from that spot.
Both are counted inside the crop, which holds the whole pose.
"""

from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

AT = (-4.0, 9.0, -34.0)     # the pose study's spot (yard floor y 9.0)
EYE = 1.6
LOOKS = ("C0", "L1", "L2", "L3", "L4", "L5", "L6", "L7", "R")
STATES = ("work", "notice", "brace", "recover")
LABELS = {
    "C0": ("C0  CONTROL", "pose-study B as it stands"),
    "L1": ("L1  plough shape", "a V-prow, two half-plates"),
    "L2": ("L2  plough lip", "a bright bare-steel band"),
    "L3": ("L3  lamps", "one 0.60 m bar for three"),
    "L4": ("L4  vent", "one stack, its cap lifts 0.25 m"),
    "L5": ("L5  hull", "8 cm lower, 20 cm longer"),
    "L6": ("L6  legs", "reverse-knee for pistons"),
    "L7": ("L7  livery", "two-tone, the lane number large"),
    "R": ("R  REFERENCE", "Prod's graybox (unified-1)"),
}
#: per camera: (crop w, h around the frame centre, enlargement), as the
#: pose study cut them
CROPS = {"F20": (100, 64, 5), "F14": (140, 90, 4), "S8": (260, 166, 2),
         "R6": (360, 230, 1.5)}
CAMERAS = {
    "F20": "front, 20 m: where it notices you; the HORN must read",
    "F14": "front, 14 m: the rush reach; the BRACE must read",
    "S8": "side, 8 m: the flanking player's silhouette",
    "R6": "rear quarter, 6 m: the sidestepped player; the VENTS must read",
}
THRESH = 24


def shots():
    x, y, z = AT
    look = [x, y + 0.5, z]
    e = y + EYE
    return [
        # 1.2 m east of the 2026-10-09 spot: there a yard column beside the
        # camera hid half the pose, in both studies
        {"name": "F20", "eye": [x + 1.2, e, z + 20.0], "look": look,
         "gray": True},
        {"name": "F14", "eye": [x, e, z + 14.0], "look": look, "gray": True},
        {"name": "S8", "eye": [x + 8.0, e, z], "look": look, "gray": True},
        {"name": "R6", "eye": [x - 3.5, e, z - 5.0], "look": [x, y + 0.4, z],
         "gray": True},
    ]


def spec(glb=None):
    x, y, z = AT
    s = {"settle_frames": 90, "hide_boxes_of": ["covers"],
         "lights": [{"at": [x, y + 3.5, z + 4.0], "color": "#ffffff",
                     "energy": 0.6, "range": 12}],
         "shots": shots(), "glbs": []}
    if glb:
        s["glbs"] = [{"path": glb, "origin": [x, y, z], "yaw_deg": 180.0}]
    return s


def write_specs(glb_dir, spec_dir):
    os.makedirs(spec_dir, exist_ok=True)
    n = 0
    for look in LOOKS:
        for state in STATES + ("brace_nolane",):
            glb = os.path.abspath(os.path.join(
                glb_dir, "shunter_%s_%s.glb" % (look, state)))
            with open(os.path.join(spec_dir, "%s_%s.json" % (look, state)),
                      "w", encoding="utf-8") as fh:
                json.dump(spec(glb), fh, indent=1)
            n += 1
    with open(os.path.join(spec_dir, "empty.json"), "w",
              encoding="utf-8") as fh:
        json.dump(spec(), fh, indent=1)
    print("[looks] %d specs and the empty yard in %s" % (n, spec_dir))


# ================================================================ sheets

def _crop(im, shot):
    w, h, _k = CROPS[shot]
    cx, cy = im.width // 2, im.height // 2
    return im.crop((cx - w // 2, cy - h // 2 - h // 8,
                    cx + w // 2, cy + h // 2 - h // 8))


def _grey(path, shot):
    import numpy as np
    from PIL import Image
    return np.asarray(_crop(Image.open(path).convert("L"), shot),
                      dtype=np.int16)


def measure(shots_dir):
    """Per look, camera and state: the silhouette (work) or the change
    from work (the other states)."""
    import numpy as np
    out = {}
    for look in LOOKS:
        out[look] = {}
        for shot in CROPS:
            row = {}
            work = _grey(os.path.join(shots_dir, "%s_work" % look,
                                      shot + "_gray.png"), shot)
            empty = _grey(os.path.join(shots_dir, "empty",
                                       shot + "_gray.png"), shot)
            row["silhouette_px"] = int((np.abs(work - empty) > THRESH).sum())
            for state in STATES[1:]:
                # the brace is measured without its floor lane, which is the
                # same in every look and would swamp the body's change
                src = "brace_nolane" if state == "brace" else state
                g = _grey(os.path.join(shots_dir, "%s_%s" % (look, src),
                                       shot + "_gray.png"), shot)
                row[state + "_changed_px"] = int(
                    (np.abs(g - work) > THRESH).sum())
            out[look][shot] = row
    return out


def sheet(shots_dir, shot, numbers, out):
    from PIL import Image, ImageDraw
    from foundry_study_sheets import ACCENT, BG, DIM, INK, font, title
    w, h, k = CROPS[shot]
    cw, ch = int(w * k), int(h * k)
    # cells no wider than 520 px, so four states and the labels fit 2400
    if cw > 520:
        ch = round(ch * 520 / cw)
        cw = 520
    lab_w = 300
    gap = 14
    W = lab_w + 4 * (cw + gap) + 30
    H = 170 + len(LOOKS) * (ch + 40) + 30
    s = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(s)
    title(d, 30, 24, "The Shunter's look: %s" % CAMERAS[shot],
          "One variable at a time against C0; the same poses (pose-study "
          "B, D-20 rev 2), body scale, yard, camera and 90-degree view. "
          "Disposable maquettes, not the model. Nothing approved. Arty, "
          "2026-10-17.")
    for j, state in enumerate(STATES):
        x = lab_w + j * (cw + gap)
        d.text((x, 120), state.upper(), font=font(22, True), fill=INK)
        d.text((x + 150, 126), "silhouette px" if state == "work"
               else "body px changed (lane excluded)" if state == "brace"
               else "px changed from work", font=font(15), fill=DIM)
    y = 165
    for look in LOOKS:
        name, what = LABELS[look]
        colour = ACCENT if look in ("C0", "R") else INK
        d.text((30, y + 10), name, font=font(21, True), fill=colour)
        d.text((30, y + 40), what, font=font(16), fill=DIM)
        for j, state in enumerate(STATES):
            from PIL import Image as _I
            p = os.path.join(shots_dir, "%s_%s" % (look, state),
                             shot + ".png")
            x = lab_w + j * (cw + gap)
            if os.path.exists(p):
                im = _crop(_I.open(p).convert("RGB"), shot).resize(
                    (cw, ch), _I.NEAREST)
                s.paste(im, (x, y))
            row = numbers[look][shot]
            v = row["silhouette_px"] if state == "work" \
                else row[state + "_changed_px"]
            base = numbers["C0"][shot]["silhouette_px" if state == "work"
                                       else state + "_changed_px"]
            txt = "%d px" % v
            if look not in ("C0",) and base:
                txt += "   (%+d%% vs C0)" % round(100.0 * (v - base) / base)
            d.text((x + 4, y + ch + 6), txt, font=font(16),
                   fill=INK if look != "R" else DIM)
        y += ch + 40
    s.save(out, quality=92, subsampling=0, optimize=True)


#: the overview: each camera's must-read moment
MOMENTS = (("F20", "notice", "notice_changed_px", "HORN at 20 m"),
           ("F14", "brace", "brace_changed_px", "BRACE at 14 m"),
           ("S8", "work", "silhouette_px", "SIDE at 8 m (silhouette)"),
           ("R6", "recover", "recover_changed_px", "VENTS from behind, 6 m"))


def overview(shots_dir, numbers, out):
    """One row per look: the four moments that must read, at the same
    enlargement as the camera sheets, the number under each."""
    from PIL import Image, ImageDraw
    from foundry_study_sheets import ACCENT, BG, DIM, INK, font, title
    cw, ch = 440, 282
    lab_w, gap = 300, 14
    W = lab_w + 4 * (cw + gap) + 30
    H = 170 + len(LOOKS) * (ch + 40) + 30
    s = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(s)
    title(d, 30, 24, "The Shunter's look: the four moments that must read",
          "Per look, the one state each camera must show. Numbers: pixels "
          "changed from work (the silhouette for SIDE), and the change "
          "against C0. Nothing approved. Arty, 2026-10-17.")
    for j, (shot, state, key, name) in enumerate(MOMENTS):
        d.text((lab_w + j * (cw + gap), 122), name, font=font(21, True),
               fill=INK)
    y = 165
    for look in LOOKS:
        lname, what = LABELS[look]
        d.text((30, y + 10), lname, font=font(21, True),
               fill=ACCENT if look in ("C0", "R") else INK)
        d.text((30, y + 40), what, font=font(16), fill=DIM)
        for j, (shot, state, key, _n) in enumerate(MOMENTS):
            x = lab_w + j * (cw + gap)
            p = os.path.join(shots_dir, "%s_%s" % (look, state),
                             shot + ".png")
            if os.path.exists(p):
                im = _crop(Image.open(p).convert("RGB"), shot)
                im = im.resize((cw, round(cw * im.height / im.width)),
                               Image.NEAREST)
                s.paste(im.crop((0, 0, cw, min(ch, im.height))), (x, y))
            v = numbers[look][shot][key]
            base = numbers["C0"][shot][key]
            txt = "%d px" % v
            if look != "C0" and base:
                txt += "   (%+d%% vs C0)" % round(100.0 * (v - base) / base)
            d.text((x + 4, y + ch + 6), txt, font=font(17),
                   fill=INK if look != "R" else DIM)
        y += ch + 40
    s.save(out, quality=92, subsampling=0, optimize=True)


def make_sheets(shots_dir, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    numbers = measure(shots_dir)
    names = {"F20": "SL1_front_20m", "F14": "SL2_front_14m",
             "S8": "SL3_side_8m", "R6": "SL4_rear_6m"}
    for shot, name in names.items():
        sheet(shots_dir, shot, numbers, os.path.join(out_dir, name + ".jpg"))
    overview(shots_dir, numbers, os.path.join(out_dir,
                                              "SL0_overview.jpg"))
    with open(os.path.join(out_dir, "shunter_look_numbers.json"), "w",
              encoding="utf-8") as fh:
        json.dump({"threshold_grey_levels": THRESH, "crops": CROPS,
                   "numbers": numbers}, fh, indent=1, sort_keys=True)
        fh.write("\n")
    print("[looks] sheets in %s" % out_dir)


if __name__ == "__main__":
    if sys.argv[1] == "specs":
        write_specs(sys.argv[2], sys.argv[3])
    else:
        make_sheets(sys.argv[2], sys.argv[3])
