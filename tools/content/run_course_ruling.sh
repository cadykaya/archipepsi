#!/usr/bin/env bash
# The owner's per-treatment course ruling, shown at the same scale.
#
#   tools/content/run_course_ruling.sh [before-ref] [out-dir]
#
# The owner ruled on the Batch 055 candidate PER TREATMENT on
# 2026-09-24: accepted for `concrete_facility` and `neon_transit`,
# refused for `gothic_stone` pending a 0.5 / 1.5 m bond comparison, and
# left `rusted_industrial`, `temple_ruin` and `void_glitch` pending for
# want of owner-facing visual evidence.
#
# So "before" is not a candidate directory any more -- it is what
# shipped before the ruling, which lives in git. This materialises that
# set from a ref into a scratch directory, renders the four accepted
# treatments against what ships now, and removes it again. The scratch
# set is NEVER committed: it is a rendering input reconstructed from
# history, and a second copy of shipped textures in the tree is a second
# thing to keep in step.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BEFORE_REF="${1:-4093ded}"
OUT="${2:-$ROOT/docs/art/review/course_ruling_2026-09-24}"
case "$OUT" in /*) ;; *) OUT="$(pwd)/$OUT" ;; esac
GODOT="${GODOT:-$ROOT/.tools/godot}"
H="$ROOT/godot/_harness"
SCRATCH="$ROOT/assets/textures/theme_pre_ruling"
[ -x "$GODOT" ] || { echo "no godot at $GODOT" >&2; exit 2; }
# shellcheck source=godot_run.sh
. "$ROOT/tools/content/godot_run.sh"
cleanup() { rm -rf "$H" "$SCRATCH"; }
trap cleanup EXIT
cleanup; mkdir -p "$H" "$OUT" "$SCRATCH"

git -C "$ROOT" ls-tree --name-only "$BEFORE_REF" assets/textures/theme/ \
  | grep '\.png$' | while read -r path; do
      git -C "$ROOT" show "$BEFORE_REF:$path" > "$SCRATCH/$(basename "$path")"
    done
echo "course-ruling: $(ls "$SCRATCH" | wc -l) texture(s) reconstructed from $BEFORE_REF"

cp "$ROOT/tools/content/course_candidate_view.gd" "$H/coursecand.gd"
sed 's/^class_name ArtBench$//' "$ROOT/tools/artpreview/artbench.gd" > "$H/artbench.gd"
run_godot cand _harness/coursecand.gd "$ROOT/assets" "$OUT" \
  theme_pre_ruling theme \
  "concrete_facility|wall|ACCEPTED 2026-09-24 -- panel courses 1.2 m -> 1.0 m" \
  "concrete_facility|wall_ribbed|ACCEPTED -- seam grime and bolts 1.2 -> 1.0 m" \
  "neon_transit|wall|ACCEPTED -- station tile 0.30 m -> 0.25 m" \
  "neon_transit|accent|ACCEPTED -- accent panel 0.40 m -> 0.50 m"
echo "course-ruling: $(ls "$OUT"/*.png | wc -l) captures in $OUT"
