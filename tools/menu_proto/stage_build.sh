#!/usr/bin/env bash
# Track A2 -- stage the interactive review build for the owner.
#
#   tools/menu_proto/stage_build.sh <out dir> [rev]      (rev: default HEAD)
#
# Writes <out>/menu_proto/: the prototype project exactly as committed at
# <rev> (git archive -- no editor cache, no local files), with the Glyph
# files it loads copied beside it into ui/ (the kit looks there first), and
# a RUN.md. Open it with Godot 4.5.x: `godot --path <out>/menu_proto`.
# The direction studies (studies/) are frozen checkpoints of their own, not
# part of the build, and are left out.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:?usage: stage_build.sh <out dir> [rev]}"
REV="${2:-HEAD}"
SHA="$(git -C "$ROOT" rev-parse --short "$REV")"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
rm -rf "$OUT/menu_proto"
tmp="$(mktemp -d)"
git -C "$ROOT" archive "$REV" tools/menu_proto | tar -x -C "$tmp"
mv "$tmp/tools/menu_proto" "$OUT/menu_proto"
rm -rf "$tmp" "$OUT/menu_proto/studies"
mkdir -p "$OUT/menu_proto/ui"
UI="$ROOT/assets/ui"
# Exactly what the kit loads: both faces and their pages, the keycap, and
# every symbol icons.json names.
cp "$UI/ui_text.fnt" "$UI/ui_text.png" "$UI/ui_numerals.fnt" \
   "$UI/ui_numerals.png" "$UI/panel_keycap.png" "$UI/icons.json" \
   "$OUT/menu_proto/ui/"
python3 - "$UI" "$OUT/menu_proto/ui" <<'PY'
import json, shutil, sys, os
ui, dst = sys.argv[1:]
meta = json.load(open(os.path.join(ui, "icons.json")))
for name, row in meta.items():
    if not name.startswith("_"):
        shutil.copy(os.path.join(ui, row["file"]), dst)
PY
cat > "$OUT/menu_proto/RUN.md" <<EOF
# Running the A2 review prototype: the interactive hybrid

*Arty*

Built from \`claude/archipepsi-art\` at \`$SHA\`. An art-lane review
prototype of the approved hybrid -- original station hardware, kept alive
by Epsilon -- and **not the game's menu**. It is for your hands-on review;
it is not approved for Production integration. The sample data is
Production's own, taken at CK9 \`a2b9df6\`, plus 11 layout-stress Echoes
tagged AUTHORED. Equipping is a local preview; nothing is sent.

**Needs Godot 4.5.x** (made with 4.5.1). Either open \`project.godot\` in
the editor and press Play, or run:

    godot --path menu_proto

Options go after \`--\`:

    godot --path menu_proto -- --reduced --text-prompts --save=latched

| Option | Values | Default |
|---|---|---|
| \`--reduced\` | reduced motion (Settings → MOTION: OFF) | full motion |
| \`--text-prompts\` | every symbol shown as its text fallback | symbols |
| \`--save=\` | \`walked\`, \`progressed\` or \`latched\` | \`walked\` |
| \`--equipment=\` | \`base\` (the fixture) or \`stress\` (plus the authored Echoes) | \`stress\` |
| \`--page=\` | open on \`equipment\`, \`map\`, \`journal\` or \`settings\` | \`equipment\` |

The REVIEW plate on the Settings wall changes the same things while it
runs.

**Sound.** The menu makes short cues:
- a tick when a selection moves;
- a detent when the key selector turns;
- a knock at the end of a list;
- a turn;
- a preview and its undo;
- a refusal;
- a value.

They play with reduced motion too. MASTER VOLUME on Settings sets them;
at 0 they are silent.

## Everywhere (Production's own bindings)

| Action | Keyboard and mouse | Pad |
|---|---|---|
| Open on Equipment / close there | Tab | Back |
| Open on Settings / close from any wall | Esc | Start |
| Turn left / right | Q / E, or click the edge arrows | LB / RB |

Each wall's prompt line shows its own controls, for the device you last
used.

## Equipment

| Action | Keyboard and mouse | Pad |
|---|---|---|
| Keys (the selector turns a detent a key) | ↑ ↓; click a key; the wheel over the selector | d-pad, left stick |
| Into the rack / back out to the keys | → / ← | d-pad → / ←, B |
| Items in the rack | ↑ ↓; click a module | d-pad, left stick |
| Scroll the rack, a row at a time | the wheel over the rack | right stick |
| Preview on the key (local, NOT SENT), or back to the save | Enter or Space; click the button | A |

## Settings

| Action | Keyboard and mouse | Pad |
|---|---|---|
| Rows | ↑ ↓; click | d-pad |
| A slider, in Production's steps (held: faster) | ← →; click or drag along it; the wheel over it | d-pad ← → |
| The switch | Enter; click | A |
| RESUME closes the menu. The game's other actions say they are not wired here. | Enter; click | A |
| The REVIEW plate (the prototype's, not the game's) | ← →, Enter; click a value | d-pad, A |

## Journal

| Action | Keyboard and mouse | Pad |
|---|---|---|
| Entries, columns | arrows; click | d-pad |
| SHOW ON THE MAP: frames the entry's passage or place, with a way back | Enter | A |
| Travel to the Map as it was left | E | RB |

## Map (MapFace's own controls)

| Action | Keyboard and mouse | Pad |
|---|---|---|
| Step place | \`[\` \`]\` | d-pad ← → |
| Detail | Enter | A |
| Overview | C, Home | Y |
| Orbit | arrows, left-drag | right stick |
| Pan | WASD, right-drag | left stick |
| Zoom | \`+\` \`-\`, wheel | triggers |
| Floors | PgUp, PgDn | d-pad ↑ ↓ |
| Back to your view (after SHOW ON THE MAP) | Backspace, or click the words on the glass | B |

## The checks

    godot --headless --path menu_proto --fixed-fps 60 -- --test=res://tapes/test_hybrid.json

The other test tapes are \`test_core\`, \`test_inputs\` and \`test_more\`.
They drive the real input path. They are scripted evidence, not hands-on
use.
EOF
echo "stage_build: $OUT/menu_proto (from $SHA, $(ls "$OUT/menu_proto/ui" | wc -l) Glyph files)"
