#!/usr/bin/env bash
# Track A2 -- the interactive prototype's SAMPLE DATA, taken from
# Production's own code over Production's own saves, never typed in.
#
#   tools/menu_proto/extract_sample.sh [production rev]
#
# Checks the Production revision out into a THROWAWAY worktree and:
#
#   extract/stress_equipment.py  folds the equipment fixture's own Echo log
#                                plus ONE authored layout-stress log through
#                                Production's model (its own generator's
#                                helpers), so every derived field is the
#                                model's
#   extract/extract_layout.gd    ZoneController.setup(candidate_zone.json)
#                                -> the committed geometry the map reads
#   extract/extract_proto.gd     EquipmentQuery over the fixture save and the
#                                stress save; MapFace and JournalQuery over
#                                the journal's own saves (walked, progressed,
#                                latched), each journal line matched to the
#                                connector, circuit or room it names
#
# The worktree is removed on exit: nothing is written to Production.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
REV="${1:-origin/claude/archipepsi-0-4-blindside}"
OUT="$ROOT/tools/menu_proto/sample"
WT="$(mktemp -d)/production"
cleanup() { git -C "$ROOT" worktree remove --force "$WT" 2>/dev/null || true; }
trap cleanup EXIT
git -C "$ROOT" worktree add --detach "$WT" "$REV" >/dev/null
SHA="$(git -C "$WT" rev-parse --short HEAD)"
mkdir -p "$WT/godot/_artlane" "$OUT"
cp "$ROOT/tools/menu_proto/extract/"*.gd "$WT/godot/_artlane/"
python3 "$ROOT/tools/menu_proto/extract/stress_equipment.py" "$WT" \
  "$WT/godot/_artlane/stress_equipment.json"
( cd "$WT/godot" && timeout 600 xvfb-run -a "$GODOT" --headless --path . --import \
    >/dev/null 2>&1 )
run() {  # <extractor> <out> [args...]
  local x="$1"; shift
  local log; log="$(mktemp)"
  timeout 300 xvfb-run -a "$GODOT" --path "$WT/godot" --rendering-driver opengl3 \
    -s "res://_artlane/$x.gd" -- "$@" >"$log" 2>&1 || true
  if grep -qE "SCRIPT ERROR|USER ERROR" "$log"; then
    grep -E "SCRIPT ERROR|USER ERROR" "$log" >&2
    echo "extract_sample: $x raised an error at $SHA" >&2
    exit 1
  fi
  grep -E "^\[extract\]" "$log" || { echo "extract_sample: $x said nothing" >&2; exit 1; }
}
run extract_layout "$OUT/layout.json" "$SHA"
run extract_proto "$OUT/sample.json" "$WT/godot/_artlane/stress_equipment.json" "$SHA"
python3 - "$OUT" "$SHA" "$REV" <<'PY'
import json, sys
out, sha, rev = sys.argv[1:]
json.dump({"production_rev": sha, "production_ref": rev,
           "note": "SAMPLE DATA: Production's own saves and fixtures, "
                   "answered by Production's own code, plus one authored "
                   "layout-stress Echo log folded by Production's model. "
                   "Regenerate; never edit."},
          open(out + "/SOURCE.json", "w"), indent=1)
PY
echo "extract_sample: Production $SHA -> $OUT"
