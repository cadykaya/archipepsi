#!/usr/bin/env bash
# Track D -- the two packs' materials on one shell, as owner evidence.
#
#   tools/content/run_pack_material_views.sh [out dir]
#
# Not a gate. `run_pack_resolution.sh` is the gate; this is the review
# screen that gate's refusal makes room for.
#
# ## Why this stages Production's files again instead of sharing
# ## run_theme_bind.sh's staging
#
# That runner pins `PROD_REF` to an OLDER branch on purpose: it proves
# binding against the ref it was written for, and D-11's pack support
# does not exist there. Sharing one staging block would mean moving that
# gate's ref, which would quietly change what a passing gate means. Two
# refs, two stagings, and this comment instead.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
PROD="${PROD_04_REF:-origin/claude/archipepsi-0-4-blindside}"
OUT="${1:-$ROOT/docs/art/review/packs_2026-09-24}"
MODELS="${PACK_MODELS:-$ROOT/assets/models/batch044/shells}"
SHELL_NAME="${PACK_SHELL:-shell_junction_cross}"
H="$ROOT/godot/_harness"
[ -x "$GODOT" ] || { echo "no godot at $GODOT" >&2; exit 2; }
# shellcheck source=godot_run.sh
. "$ROOT/tools/content/godot_run.sh"
mkdir -p "$OUT"
cleanup() { rm -rf "$H"; }
trap cleanup EXIT
cleanup; mkdir -p "$H"

git -C "$ROOT" show "$PROD:godot/scripts/autoload/constants.gd" \
  | sed 's/^class_name .*$//' > "$H/prod_constants.gd"
git -C "$ROOT" show "$PROD:godot/scripts/generation/textures.gd" \
  | sed 's/^class_name .*$//' > "$H/prod_textures.gd"
git -C "$ROOT" show "$PROD:godot/scripts/generation/theme_pack.gd" \
  | sed 's/^class_name .*$//; s/\bConstants\./_PROD_CONST./g' \
  > "$H/prod_theme_pack.gd"
python3 - "$H/prod_theme_pack.gd" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
lines = p.read_text().split("\n")
at = next(i for i, l in enumerate(lines) if l.startswith("extends ")) + 1
lines[at:at] = ['const _PROD_CONST := preload('
                '"res://_harness/prod_constants.gd")']
p.write_text("\n".join(lines))
PY
git -C "$ROOT" show "$PROD:godot/scripts/generation/theme_materials.gd" \
  | python3 -c '
import sys
s = sys.stdin.read()
s = s.replace("class_name ThemeMaterials\n", "")
for cls, name in (("ThemePack", "_PACK"), ("ProcTextures", "_PROC"),
                  ("Constants", "_CONST")):
    s = s.replace(cls + ".", name + ".")
lines = s.split("\n")
at = next(i for i, l in enumerate(lines) if l.startswith("extends ")) + 1
lines[at:at] = [
    "const _PACK := preload(\"res://_harness/prod_theme_pack.gd\")",
    "const _PROC := preload(\"res://_harness/prod_textures.gd\")",
    "const _CONST := preload(\"res://_harness/prod_constants.gd\")",
]
sys.stdout.write("\n".join(lines))
' > "$H/prod_theme_materials.gd"
for f in prod_theme_pack prod_theme_materials; do
  grep -q "preload(\"res://_harness/prod_constants.gd\")" "$H/$f.gd" || {
    echo "run_pack_material_views: $f.gd did not get its Constants
  binding, so the staged file is not the one this runner thinks it is" >&2
    exit 1; }
done

sed 's/^class_name ArtBench$//' "$ROOT/tools/artpreview/artbench.gd" \
  > "$H/artbench.gd"
cp "$ROOT/tools/content/pack_material_views.gd" "$H/packview.gd"

run_godot packview _harness/packview.gd "$OUT" "$MODELS" "$SHELL_NAME"
