#!/usr/bin/env bash
# Art's three projectiles through Production's own legibility rule.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
PROD="${PROD_04_REF:-origin/claude/archipepsi-0-4-blindside}"
OUT="${1:-$ROOT/docs/art/review/projectiles_2026-09-22}"
H="$ROOT/godot/_harness"
[ -x "$GODOT" ] || { echo "no godot at $GODOT" >&2; exit 2; }
# shellcheck source=godot_run.sh
. "$ROOT/tools/content/godot_run.sh"
mkdir -p "$OUT"
cleanup() { rm -rf "$H"; }
trap cleanup EXIT
cleanup; mkdir -p "$H"

# `build()` is the only thing in their file that touches ThemeMaterials
# and this harness never calls it -- but GDScript parses the whole file,
# so the name is bound to a stub that REFUSES. Same move as
# run_yard_measure.sh: a harness that measures must not be able to
# quietly construct.
cat > "$H/refuses.gd" <<'GD'
extends RefCounted
## Not ThemeMaterials. Deliberately.
static func glow_material(_tint, _energy) -> Material:
	push_error("projectile_legibility called ProjectileSilhouette."
		+ "build(), which constructs. This harness measures Art's "
		+ "authored meshes; it must not fall back to building "
		+ "Production's placeholder and then measure that.")
	return null
GD

git -C "$ROOT" show "$PROD:godot/scripts/content/projectile_silhouette.gd" \
  | sed 's/^class_name ProjectileSilhouette$//' \
  | python3 -c '
import sys
s = sys.stdin.read().replace("ThemeMaterials.", "_REFUSES.")
lines = s.split("\n")
at = next(i for i, l in enumerate(lines) if l.startswith("extends ")) + 1
lines[at:at] = ["const _REFUSES := preload(\"res://_harness/refuses.gd\")"]
sys.stdout.write("\n".join(lines))
' > "$H/prod_silhouette.gd"

cp "$ROOT/tools/content/projectile_legibility.gd" "$H/projleg.gd"
run_godot projleg _harness/projleg.gd "$ROOT/assets/models" \
  "$OUT/legibility.json"
