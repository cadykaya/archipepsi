#!/usr/bin/env bash
# Does the exported pack bind -- through PRODUCTION'S OWN CONSUMER?
#
# `ThemeMaterials` already asks `ThemePack` before falling back to
# `ProcTextures`, so there is no art-side binder here and must not be:
# a second one would be a second source of material behaviour. Their
# files are fetched READ-ONLY at run time into a harness deleted on exit,
# by the two mechanical moves this lane already documents.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
PROD="${PROD_REF:-origin/claude/archipepsi-echoes-continuation-b1adno}"
OUT="${1:-$ROOT/docs/art/review/theme_bind_2026-09-13}"
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
  | sed 's/^class_name .*$//' > "$H/prod_theme_pack.gd"

# THE ONLY EDIT: the cross-references. Stripping `class_name` from a file
# is what lets it be preloaded instead of registered globally, and it is
# also what breaks every `ThemePack.`/`ProcTextures.`/`Constants.` call
# in the file that uses them. Each is bound to the preloaded script, by
# name, at the top -- nothing is retyped and no behaviour is restated.
git -C "$ROOT" show "$PROD:godot/scripts/generation/theme_materials.gd" \
  | python3 -c '
import sys
s = sys.stdin.read()
s = s.replace("class_name ThemeMaterials\n", "")
for cls, name in (("ThemePack", "_PACK"), ("ProcTextures", "_PROC"),
                  ("Constants", "_CONST")):
    s = s.replace(cls + ".", name + ".")
# AFTER `extends`, never before it: GDScript requires `extends` to be the
# first statement, and a preload block above it is a parse error that
# cascades into every later call looking like a missing function.
lines = s.split("\n")
at = next(i for i, l in enumerate(lines) if l.startswith("extends ")) + 1
lines[at:at] = [
    "const _PACK := preload(\"res://_harness/prod_theme_pack.gd\")",
    "const _PROC := preload(\"res://_harness/prod_textures.gd\")",
    "const _CONST := preload(\"res://_harness/prod_constants.gd\")",
]
sys.stdout.write("\n".join(lines))
' > "$H/prod_theme_materials.gd"

cp "$ROOT/tools/content/theme_bind_proof.gd" "$H/bindproof.gd"
sed 's/^class_name ArtBench$//' "$ROOT/tools/artpreview/artbench.gd" \
  > "$H/artbench.gd"

run_godot bind-whole _harness/bindproof.gd "$OUT/binding_whole.json" whole
run_godot bind-control _harness/bindproof.gd \
  "$OUT/control_missing_required.json" missing_required
# THE FIX VERIFIED WHERE IT COUNTS. The gauge board's lettering, on a
# shell wearing materials `ThemeMaterials` built rather than the ones
# Blender baked -- different tiling, different filtering, triplanar on.
run_godot bind-render _harness/bindproof.gd \
  "$OUT/render.json" render \
  "$ROOT/assets/models/batch044/shells" shell_junction_cross \
  "$OUT/RUNTIME_BOUND_gauge_board.png"

echo "theme-bind: PASS -- Production's ThemeMaterials binds the exported"
echo "  pack's authored pixels, and the missing-row control falls back"
