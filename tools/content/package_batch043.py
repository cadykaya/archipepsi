"""Build Batch 043's two archives, and refuse to ship one that lies.

    python3 tools/content/package_batch043.py

REVIEW is for looking at. SOURCE is for rebuilding. They are separate because
Batch 042 shipped one archive whose README listed editable sources it did not
contain, and the owner found it before I did. So this script does two things
the last one did not:

  1. it builds each archive from an EXPLICIT list, and
  2. it then re-opens the archive and checks that every file path the
     archive's own index mentions is actually inside it.

A README that promises a file is a claim, and a claim gets checked.
"""

from __future__ import annotations

import os
import re
import sys
import zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "docs", "art", "packages")
STATUS = "docs/art/review/status_2026-09-11"
MACH = "docs/art/review/machinery_2026-09-11"
PROPS = "docs/art/review/props_2026-09-11"


def tree(rel, suffixes=None, skip=()):
    base = os.path.join(ROOT, rel)
    found = []
    for dirpath, _dirs, files in os.walk(base):
        for name in sorted(files):
            if any(s in dirpath for s in skip):
                continue
            if suffixes and not name.endswith(tuple(suffixes)):
                continue
            full = os.path.join(dirpath, name)
            found.append(os.path.relpath(full, ROOT))
    return sorted(found)


def uniq(items):
    """Order-preserving dedupe. `tree()` calls overlap by design -- the
    status directory's sheets and its `room/` frames are two separate lists
    over one tree -- and zipfile writes a duplicate member without complaint,
    which produces an archive with two of everything and no error."""
    seen, out = set(), []
    for i in items:
        if i not in seen:
            seen.add(i)
            out.append(i)
    return out


REVIEW = uniq(
    ["docs/art/reports/2026-09-11-batch043.md",
     "docs/art/BATCH_043_INVENTORY.md",
     "docs/art/BATCH_043_INTEGRATION.md",
     f"{STATUS}/README.md", f"{STATUS}/DECISIONS_FOR_OWNER.md",
     f"{MACH}/README.md",
     f"{PROPS}/README.md", f"{PROPS}/CLASS_MAP.md"]
    + tree(STATUS, [".png"], skip=("/glyph", "/png8x", "/png"))
    + tree(f"{STATUS}/room", [".png", ".gif"])
    + tree(MACH, [".png"], skip=("/glyph", "/png"))
    + tree(f"{MACH}/room", [".png", ".gif"])
    + tree(f"{PROPS}/room", [".png"])
)

SOURCE = uniq(
    [f"{STATUS}/status_bodies.mjs", f"{STATUS}/status_frames.mjs",
     f"{STATUS}/author_status_kit.mjs", f"{STATUS}/make_sheets.py",
     f"{STATUS}/status_kit.json", f"{STATUS}/atlas_markers.json",
     f"{MACH}/author_conduit_states.mjs", f"{MACH}/conduit_states.json",
     "tools/blender/build_machinery.py",
     "tools/blender/build_physics_props.py",
     "tools/blender/common.py",
     "tools/blender/brushkit.py", "tools/blender/propkit.py",
     "tools/blender/palette.py",
     "tools/content/status_preview.gd",
     "tools/content/machinery_preview.gd",
     "tools/content/props_preview.gd",
     "tools/content/run_status_preview.sh",
     "tools/content/run_machinery_preview.sh",
     "tools/content/run_props_preview.sh",
     "tools/content/inspect_glb_nodes.py",
     "tools/content/verify_exported_geometry.py",
     "tools/content/skin_compare.py",
     "tools/content/import_examples.gd",
     "tools/content/run_import_examples.sh",
     "tools/content/package_batch043.py",
     "tools/artpreview/artbench.gd",
     "assets/art_palette.json", "assets/art_budgets.json"]
    + tree(f"{STATUS}/glyph")
    + tree(f"{STATUS}/png", [".png"])
    + tree(f"{MACH}/glyph")
    + tree(f"{MACH}/png", [".png"])
    + tree("assets/models/batch043")
    + tree("assets/textures/batch043")
)


def write(name, members, index_text):
    path = os.path.join(OUT, name)
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        z.writestr("INDEX.md", index_text)
        missing = []
        for rel in members:
            full = os.path.join(ROOT, rel)
            if not os.path.exists(full):
                missing.append(rel)
                continue
            z.write(full, rel)
    if missing:
        raise SystemExit("%s: %d listed file(s) do not exist:\n  %s"
                         % (name, len(missing), "\n  ".join(missing)))
    return path


def verify(path):
    """Re-open the archive and check every path its INDEX mentions is in it.

    The check is deliberately naive about prose: it pulls anything that looks
    like a repo path out of the index and requires it to be a member. A false
    positive here costs a sentence rewrite; a false negative costs the owner
    an archive that promises files it does not have.
    """
    with zipfile.ZipFile(path) as z:
        members = set(z.namelist())
        index = z.read("INDEX.md").decode("utf-8")
    claimed = set(re.findall(r"`((?:docs|tools|assets)/[^`\s]+)`", index))
    absent = sorted(c for c in claimed
                    if c not in members
                    and not any(m.startswith(c.rstrip("/") + "/")
                                for m in members))
    if absent:
        raise SystemExit("%s: the index names %d path(s) the archive does not "
                         "contain:\n  %s"
                         % (os.path.basename(path), len(absent),
                            "\n  ".join(absent)))
    size = os.path.getsize(path) / 1024.0 / 1024.0
    print("%-44s %4d files  %5.1f MB  index verified"
          % (os.path.basename(path), len(members), size))


REVIEW_INDEX = """# Batch 043 — REVIEW

Arty, 2026-09-11. Everything here is a PROPOSAL: nothing is approved, nothing
is bound to runtime, no mechanic is implemented, and the playable build is
unchanged.

## Read in this order

1. `docs/art/reports/2026-09-11-batch043.md` — the report.
2. `docs/art/review/status_2026-09-11/DECISIONS_FOR_OWNER.md` — the five
   things that genuinely need you.
3. `docs/art/BATCH_043_INTEGRATION.md` — **the handoff for Production and
   Dess**, pinned to art `7ea95e2`: model paths, runtime dimensions,
   attachment frames, named moving parts, material controls, four runnable
   import examples with their measured output, and the open integration
   dependencies.
4. `docs/art/BATCH_043_INVENTORY.md` — what already existed, before anything
   new was made.

## The status kit

`docs/art/review/status_2026-09-11/README.md`, then:

| sheet | |
| --- | --- |
| `SHEET_markers.png` | all 21 markers on three grounds |
| `SHEET_markers_grayscale.png` | the same, hue removed |
| `SHEET_native_size.png` | 1:1 — the sheet that answers the actual question |
| `SHEET_pairs.png` | the six pairs that must not be confused |
| `SHEET_frames.png` | the four family frames and the compound frame |
| `SHEET_components.png` | duration, the player tick, the compound hint |

In the room, under the shipped light model, on bright concrete, dark derelict
and a visually busy background: `room/STATUS_individual_*`,
`room/STATUS_compound_*`, `room/STATUS_crowd_*`, grayscale companions, and
`room/SEQ_compound_forming.gif` with its twelve frames as stills.

## Machinery feedback

`docs/art/review/machinery_2026-09-11/README.md`, then `_look_states.png` for
the five states flat, `room/MACH_five_states.png` on a wall,
`room/MACH_close_inactive_vs_blocked.png` for the pair separated by
brightness **and** pattern, `room/MACHSEQ_motion.gif` for travel against
growth, `room/MACH_delay_*.png` for a labelled 4.0 s delay with both
endpoints, `room/MACH_hinge_sweep.png` and `.gif` for the lever's fixed
pintle, and `room/MACH_switch_*.png` for the setter and receiver.

**No audio exists in this kit** and no frame here demonstrates any — but the
filling band, not the audio, is §19.5's primary timing channel and it is
delivered.

## The physics props

`docs/art/review/props_2026-09-11/CLASS_MAP.md` — **all twelve** of Design 2
§10.1's classes, all built. `room/PROPS_lineup_bright.png` and `_dark.png`
are the family in three rows split at the 60 kg carry line, under both
lighting conditions; `room/PROPS_candidate_vs_decorative_*.png` settles the
`GENERIC` / `DRUM` question; `room/PROPS_fixed_vs_movable_*.png` shows
`ANCHOR_BLOCK` reading as `FIXED`; and there is one close frame per class.

## What these pictures do not show

Static frames and two short loops. They do not prove combat visibility, they
do not prove the markers are flicker-free in motion, and they do not prove
readability while the player is turning.

Editable sources, Glyph projects, Blender scripts, exported models and the
preview scripts are in the **SOURCE** archive, not this one.
"""

SOURCE_INDEX = """# Batch 043 — SOURCE

Arty, 2026-09-11. Everything needed to rebuild the batch. Paths are
repository-relative; unzip over a checkout of the art branch at the revision
named in `PROVENANCE.txt` and the three commands below reproduce it.

## Rebuild

```
# 1. the status kit  (Glyph -> png/ -> SHEET_*.png)
GLYPH_ROOT=/path/to/ecms-glyph node \\
    docs/art/review/status_2026-09-11/author_status_kit.mjs
python3 docs/art/review/status_2026-09-11/make_sheets.py
tools/content/run_status_preview.sh

# 2. the machinery kit  (Glyph -> Blender -> Godot)
GLYPH_ROOT=/path/to/ecms-glyph node \\
    docs/art/review/machinery_2026-09-11/author_conduit_states.mjs
.tools/blender/blender -b --python tools/blender/build_machinery.py -- \\
    docs/art/review/machinery_2026-09-11
tools/content/run_machinery_preview.sh

# 3. the physics props  (Blender -> Godot)
.tools/blender/blender -b --python tools/blender/build_physics_props.py
tools/content/run_props_preview.sh
```

Every preview runner needs `xvfb-run` and the Compatibility renderer;
`--headless` gives the dummy driver and every capture comes back black.

## Dependencies inside this archive

The two Glyph authoring scripts import `@glyph/protocol` and
`@glyph/core` from an ECMS Glyph checkout at `GLYPH_ROOT`, which is **not**
in this archive — it is a separate repository. The revision used is in
`PROVENANCE.txt`.

`tools/blender/build_machinery.py` and `build_physics_props.py` import
`tools/blender/common.py`, `brushkit.py`, `propkit.py` and `palette.py`, all
four of which are here, and read `assets/art_palette.json` and
`assets/art_budgets.json`, which are here too.

The three preview scripts under `tools/content/` load
`tools/artpreview/artbench.gd`, which is
here, and read the shipped `shell_corner_left` scene and the Batch 042
derelict fields from the repository — those are NOT in this archive, because
they are existing approved content rather than anything this batch authored.

## What is here

| | |
| --- | --- |
| `docs/art/review/status_2026-09-11/status_bodies.mjs` | the 21 hand-drawn silhouettes — the file to edit |
| `docs/art/review/status_2026-09-11/status_frames.mjs` | the five frames and the depletion track |
| `docs/art/review/status_2026-09-11/author_status_kit.mjs` | authors every Glyph project, exports every PNG |
| `docs/art/review/status_2026-09-11/make_sheets.py` | regenerates every review sheet |
| `docs/art/review/status_2026-09-11/glyph/` | 70 editable Glyph projects |
| `docs/art/review/status_2026-09-11/png/` | 71 individual transparent exports |
| `docs/art/review/status_2026-09-11/status_kit.json` | ids, families, sentences, targets, durations, native sizes, depletion tracks |
| `docs/art/review/machinery_2026-09-11/author_conduit_states.mjs` | the channel and the five state bands |
| `docs/art/review/machinery_2026-09-11/glyph/` | 6 editable Glyph projects |
| `docs/art/review/machinery_2026-09-11/conduit_states.json` | per state: brightness, pattern, motion, and the audio still required |
| `tools/blender/build_machinery.py` | the three machinery pieces |
| `tools/blender/build_physics_props.py` | the four object classes |
| `tools/blender/common.py` | the exporter, including this batch's `parts=`, `set_origin_group` and `assert_budget_group` |
| `assets/models/batch043/` | the exported `.glb` files and both manifests |
| `assets/textures/batch043/` | the baked prop and machinery textures |
| `tools/content/inspect_glb_nodes.py` | what a `.glb` offers a runtime after import |
| `tools/content/package_batch043.py` | this archive's own build script |

## Asset metadata

`assets/models/batch043/physics/manifest.json` carries, per candidate: the
class, mass, derived `mass_class`, carriable and manipulable flags, exported
size, triangle count, texel density, anchor, orientation, material roles,
attachment-point positions and normals, and the statement that every
dimension is a proposed art dimension and no collision exists.

`assets/models/batch043/machinery/manifest.json` carries the band tile in
pixels and metres, the addressable part names per asset, and the
`how_to_drive` contract.
"""


def provenance():
    import subprocess
    def sha(path):
        try:
            return subprocess.check_output(
                ["git", "-C", path, "rev-parse", "HEAD"],
                text=True).strip()
        except Exception:
            return "unknown"
    return (
        "Batch 043 provenance\n"
        "====================\n\n"
        "Art branch      claude/archipepsi-art\n"
        "Art revision    %s\n"
        "Design read     a20bf55  docs/design-proposals/06_THE_AMALGAM.md\n"
        "                (branch claude/chatgpt-share-link-review-77kk2l)\n"
        "ECMS Glyph      %s  branch claude/archipepsi-glyph-tooling\n"
        "                UNCHANGED by this batch; draft PR #3\n"
        "Godot           4.5.1, Compatibility renderer via\n"
        "                xvfb-run --rendering-driver opengl3\n"
        "Blender         headless, .tools/blender/blender\n\n"
        "Every screenshot in the REVIEW archive was rendered from the art\n"
        "revision above. Nothing was hand-edited after rendering.\n"
        % (sha(ROOT), sha(os.environ.get("GLYPH_ROOT", "/home/user/ecms-glyph")))
    )


os.makedirs(OUT, exist_ok=True)
r = write("archipepsi-art-batch043-REVIEW.zip", REVIEW, REVIEW_INDEX)
with zipfile.ZipFile(r, "a", zipfile.ZIP_DEFLATED) as z:
    z.writestr("PROVENANCE.txt", provenance())
s = write("archipepsi-art-batch043-SOURCE.zip", SOURCE, SOURCE_INDEX)
with zipfile.ZipFile(s, "a", zipfile.ZIP_DEFLATED) as z:
    z.writestr("PROVENANCE.txt", provenance())
verify(r)
verify(s)
