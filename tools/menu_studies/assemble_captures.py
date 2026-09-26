#!/usr/bin/env python3
"""Track A2 -- cut the review material from the studies' captured frames.

    assemble_captures.py FRAMES OUT study [study ...]

Reads FRAMES/<study>/<mode>/frame_NNNN.png and manifest.json, as
menu_studies.gd writes them (mode: motion, reduced), and writes, for each
study, into OUT/<study>/:

  motion.mp4, reduced.mp4  every frame, 30 fps, 1920 x 1080: the text at
                           the size the game draws it
  preview.webp             the motion run at half size and 15 fps, to see
                           inline (the text is NOT at gameplay size there)
  stills/NN_<step>.png     each settled step of the motion run, full size
  settled.png              each settled step, MOTION beside REDUCED MOTION
  filmstrip.png            what moves: the first 0.6 s after each step
  differs/NN_<step>.png    only where the two runs' settled frames
                           differ: WHERE, in red over the motion frame
  captures.json            both manifests, and how far the two runs'
                           settled frames differ below the caption band

Generated. Rerun tools/menu_studies/run_menu_studies.sh; never edit.
"""
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

FPS = 30
CAPTION_BAND = 100          # px: the harness's own caption, not the study
FILM_OFFSETS = (0, 4, 8, 12, 18)    # frames after a step: 0 .. 0.6 s
BG = (13, 15, 18)
INK = (232, 238, 246)
DIM = (155, 165, 182)
SIGNAL = (57, 215, 200)


def _font(size, mono=False):
    name = "DejaVuSansMono.ttf" if mono else "DejaVuSans.ttf"
    for d in ("/usr/share/fonts/truetype/dejavu",
              "/usr/share/fonts/dejavu"):
        p = Path(d) / name
        if p.exists():
            return ImageFont.truetype(str(p), size)
    return ImageFont.load_default()


def _ffmpeg():
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        return shutil.which("ffmpeg")


def _frame(run: Path, n: int) -> Path:
    return run / ("frame_%04d.png" % n)


def _step(caption: str) -> str:
    """The moment's name: the caption's first word ("select (mouse) -- ..."
    -> "select")."""
    return re.match(r"[a-z]+", caption.strip().lower()).group(0)


def _mp4(ffmpeg, run: Path, out: Path) -> dict:
    cmd = [ffmpeg, "-y", "-loglevel", "error", "-framerate", str(FPS),
           "-start_number", "0", "-i", str(run / "frame_%04d.png"),
           "-c:v", "libx264", "-preset", "slow", "-tune", "animation",
           "-crf", "18", "-pix_fmt", "yuv420p", "-movflags", "+faststart",
           str(out)]
    subprocess.run(cmd, check=True)
    return {"file": out.name, "bytes": out.stat().st_size}


def _preview(run: Path, frames: int, out: Path) -> dict:
    ims = [Image.open(_frame(run, n)).convert("RGB").resize(
        (960, 540), Image.LANCZOS) for n in range(0, frames, 2)]
    ims[0].save(out, save_all=True, append_images=ims[1:],
                duration=int(round(2000 / FPS)), loop=0, quality=72,
                method=4)
    return {"file": out.name, "bytes": out.stat().st_size,
            "note": "half size, 15 fps: for seeing the motion inline; "
                    "the text is not at gameplay size here -- the MP4 is"}


def _diff(a: Path, b: Path, overlay: Path) -> dict:
    """How far two settled frames differ below the caption band. Where
    they differ at all, `overlay` shows WHERE: the motion frame dimmed,
    every pixel more than 8 levels apart in red. A number says how much;
    only the picture says what."""
    ia = Image.open(a).convert("RGB")
    ib = Image.open(b).convert("RGB")
    w, h = ia.size
    box = (0, CAPTION_BAND, w, h)
    d = ImageChops.difference(ia.crop(box), ib.crop(box)).convert("L")
    hist = d.histogram()
    total = sum(hist)
    mean = sum(i * c for i, c in enumerate(hist)) / total
    over = sum(hist[9:]) / total
    mask = d.point(lambda v: 255 if v > 8 else 0)
    bbox = mask.getbbox()
    out = {"mean_abs": round(mean, 3), "share_over_8": round(over, 5),
           "changed_box": None if bbox is None else
           [bbox[0], bbox[1] + CAPTION_BAND, bbox[2], bbox[3] + CAPTION_BAND],
           "overlay": None}
    if bbox is not None:
        full = Image.new("L", ia.size, 0)
        full.paste(mask, (0, CAPTION_BAND))
        pic = ia.point(lambda v: v // 3)
        pic.paste(Image.new("RGB", ia.size, (255, 40, 40)), (0, 0), full)
        overlay.parent.mkdir(parents=True, exist_ok=True)
        pic.save(overlay, optimize=True)
        out["overlay"] = "%s/%s" % (overlay.parent.name, overlay.name)
    return out


def _settled(study, stills, runs, out: Path):
    tw, th, head, gap = 960, 540, 34, 10
    top = 70
    sheet = Image.new("RGB", (2 * tw + 3 * gap,
                              top + len(stills) * (head + th + gap)), BG)
    dr = ImageDraw.Draw(sheet)
    dr.text((gap, 14), "%s -- every settled step, MOTION beside REDUCED "
            "MOTION (same steps, cut)" % study.upper(), font=_font(24),
            fill=INK)
    dr.text((gap, 44), "Half size here; the full-size stills and the MP4s "
            "carry the text at gameplay size.", font=_font(16), fill=DIM)
    for i, (t, caption) in enumerate(stills):
        n = int(round(t * FPS))
        y = top + i * (head + th + gap)
        dr.text((gap, y + 6), "%d  %s" % (i + 1, caption), font=_font(18),
                fill=SIGNAL if i == 0 else INK)
        for c, mode in enumerate(("motion", "reduced")):
            im = Image.open(_frame(runs[mode], n)).convert("RGB").resize(
                (tw, th), Image.LANCZOS)
            sheet.paste(im, (gap + c * (tw + gap), y + head))
    sheet.save(out, optimize=True)


def _filmstrip(study, marks, frames, run: Path, out: Path):
    steps = [m for m in marks if m["label"] != "rest"]
    tw, th, head, gap, left = 480, 270, 30, 8, 150
    sheet = Image.new("RGB", (left + len(FILM_OFFSETS) * (tw + gap),
                              70 + len(steps) * (head + th + gap)), BG)
    dr = ImageDraw.Draw(sheet)
    dr.text((gap, 14), "%s -- what moves: the first 0.6 s after each step "
            "(motion run)" % study.upper(), font=_font(24), fill=INK)
    for c, off in enumerate(FILM_OFFSETS):
        dr.text((left + c * (tw + gap), 46), "+%.2f s" % (off / FPS),
                font=_font(16, True), fill=DIM)
    for r, m in enumerate(steps):
        y = 70 + r * (head + th + gap)
        dr.text((gap, y + head + th // 2 - 10), m["label"].upper(),
                font=_font(18), fill=SIGNAL)
        for c, off in enumerate(FILM_OFFSETS):
            n = min(int(m["frame"]) + off, frames - 1)
            im = Image.open(_frame(run, n)).convert("RGB").resize(
                (tw, th), Image.LANCZOS)
            sheet.paste(im, (left + c * (tw + gap), y + head // 2))
    sheet.save(out, optimize=True)


def assemble(frames_dir: Path, out_dir: Path, study: str, ffmpeg) -> dict:
    runs = {m: frames_dir / study / m for m in ("motion", "reduced")}
    man = {m: json.loads((runs[m] / "manifest.json").read_text())
           for m in runs}
    for m in runs:
        n = int(man[m]["frames"])
        missing = [i for i in range(n) if not _frame(runs[m], i).exists()]
        if missing:
            raise SystemExit("%s/%s: %d frames missing (was it an ONLY_STILLS "
                             "run?)" % (study, m, len(missing)))
    if man["motion"]["stills"] != man["reduced"]["stills"]:
        raise SystemExit("%s: the two runs disagree on their stills" % study)
    out = out_dir / study
    if out.exists():
        shutil.rmtree(out)
    (out / "stills").mkdir(parents=True)
    stills = man["motion"]["stills"]
    record = {"study": study, "title": man["motion"]["title"],
              "source": man["motion"]["source"], "fps": FPS,
              "size": man["motion"]["size"], "runs": {}, "stills": []}
    for m in runs:
        run = {"frames": int(man[m]["frames"]),
               "seconds": round(int(man[m]["frames"]) / FPS, 2),
               "marks": man[m]["marks"]}
        if ffmpeg:
            run["video"] = _mp4(ffmpeg, runs[m], out / ("%s.mp4" % m))
        else:
            run["video"] = None
            print("assemble: no ffmpeg -- %s/%s has no MP4" % (study, m))
        record["runs"][m] = run
    record["preview"] = _preview(runs["motion"], int(man["motion"]["frames"]),
                                 out / "preview.webp")
    for i, (t, caption) in enumerate(stills):
        n = int(round(float(t) * FPS))
        name = "%02d_%s.png" % (i + 1, _step(caption))
        Image.open(_frame(runs["motion"], n)).save(out / "stills" / name,
                                                   optimize=True)
        record["stills"].append({
            "file": "stills/" + name, "t": t, "frame": n,
            "caption": caption,
            "motion_vs_reduced": _diff(_frame(runs["motion"], n),
                                       _frame(runs["reduced"], n),
                                       out / "differs" / name)})
    _settled(study, stills, runs, out / "settled.png")
    _filmstrip(study, man["motion"]["marks"], int(man["motion"]["frames"]),
               runs["motion"], out / "filmstrip.png")
    (out / "captures.json").write_text(json.dumps(record, indent=1) + "\n")
    return record


def main(argv):
    if len(argv) < 4:
        raise SystemExit(__doc__)
    frames_dir, out_dir = Path(argv[1]), Path(argv[2])
    ffmpeg = _ffmpeg()
    for study in argv[3:]:
        r = assemble(frames_dir, out_dir, study, ffmpeg)
        worst = max(s["motion_vs_reduced"]["mean_abs"] for s in r["stills"])
        print("assemble: %s -> %s (%d stills; settled motion vs reduced, "
              "worst mean |diff| %.3f)" % (study, out_dir / study,
                                           len(r["stills"]), worst))


if __name__ == "__main__":
    main(sys.argv)
