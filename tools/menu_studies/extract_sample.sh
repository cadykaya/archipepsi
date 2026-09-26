#!/usr/bin/env bash
# Track A2 -- the menu studies' SAMPLE DATA, taken from Production's own
# code over Production's own fixtures, never typed in.
#
#   tools/menu_studies/extract_sample.sh [production rev]
#
# Checks the Production revision out into a THROWAWAY worktree, drops the
# two extractors in `extract/` into it, imports the project, and runs them:
#
#   extract_layout.gd   ZoneController.setup(candidate_zone.json), then the
#                       committed geometry the maps read (room_bounds,
#                       room_places, room_joins, plug_positions)
#   extract_content.gd  EquipmentQuery on equipment_snapshot.json, MapFace
#                       bound to that Zone over map_snapshot.json and the
#                       journal's own saves, JournalQuery on
#                       journal_snapshot.json
#
# Every word a study shows is therefore Production's own answer, and the
# worktree is removed on exit: nothing is written to the Production branch.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
REV="${1:-origin/claude/archipepsi-0-4-blindside}"
OUT="$ROOT/tools/menu_studies/sample"
WT="$(mktemp -d)/production"
cleanup() { git -C "$ROOT" worktree remove --force "$WT" 2>/dev/null || true; }
trap cleanup EXIT
git -C "$ROOT" worktree add --detach "$WT" "$REV" >/dev/null
SHA="$(git -C "$WT" rev-parse --short HEAD)"
mkdir -p "$WT/godot/_artlane" "$OUT"
cp "$ROOT/tools/menu_studies/extract/"*.gd "$WT/godot/_artlane/"
( cd "$WT/godot" && timeout 600 xvfb-run -a "$GODOT" --headless --path . --import \
    >/dev/null 2>&1 )
for x in layout content; do
  log="$(mktemp)"
  timeout 300 xvfb-run -a "$GODOT" --path "$WT/godot" --rendering-driver opengl3 \
    -s "res://_artlane/extract_$x.gd" -- "$OUT/$x.json" >"$log" 2>&1
  if grep -qE "SCRIPT ERROR|USER ERROR" "$log"; then
    grep -E "SCRIPT ERROR|USER ERROR" "$log" >&2
    echo "extract_sample: the $x extractor raised an error at $SHA" >&2
    exit 1
  fi
  grep -E "^\[extract\]" "$log" || true
done
python3 - "$OUT" "$SHA" "$REV" <<'PY'
import json, sys
out, sha, rev = sys.argv[1:]
json.dump({"production_rev": sha, "production_ref": rev,
           "note": "SAMPLE DATA: Production's own fixtures, answered by "
                   "Production's own code. Regenerate; never edit."},
          open(out + "/SOURCE.json", "w"), indent=1)
PY
echo "extract_sample: Production $SHA -> $OUT"
