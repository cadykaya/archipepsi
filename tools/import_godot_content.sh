#!/usr/bin/env bash
# Run Godot's OWN importer over godot/content/, so the .import sidecars
# beside the pack are the engine's output and not a guess at its schema.
#
#   tools/import_godot_content.sh
#
# A .import file carries a `uid`, a destination path keyed by a hash of
# the source, and the source's md5. Hand-writing one means inventing all
# three, and the first time Godot disagreed it would silently reimport and
# the committed file would be wrong. So the engine writes them.
#
# Production's binding contract asks for mipmaps on, and for the textures
# not to fight the material's TEXTURE_FILTER_NEAREST. In Godot 4 filtering
# and repeat are sampler state on the material, not importer parameters --
# `BaseMaterial3D.texture_filter` / `texture_repeat` -- so there is nothing
# in the sidecar to set for those two and the binder sets them when it
# builds the material. `tools/content/verify_theme_export.py` asserts the
# part that IS in the sidecar: mipmaps, and lossless compression.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
[ -x "$GODOT" ] || { echo "no godot at $GODOT" >&2; exit 2; }

log="$(mktemp)"
set +e
xvfb-run -a timeout --kill-after=15s "${GODOT_IMPORT_TIMEOUT:-600}" \
  "$GODOT" --headless --path "$ROOT/godot" --import >"$log" 2>&1
status=$?
set -e
grep -E "SCRIPT ERROR|USER ERROR|Failed to load" "$log" | head -5 || true
if [ "$status" -ne 0 ]; then
  echo "import: the engine exited $status; full log at $log" >&2
  exit 1
fi
rm -f "$log"

# Godot's default is mipmaps OFF, and the binding contract asks for them
# on -- a 128 px tiling texture on a 90 m deck without mipmaps shimmers.
# Only the one documented parameter is set, in the [params] block the
# editor writes to; everything derived -- uid, dest hash, source md5 --
# stays Godot's, which is why the importer runs again afterwards.
python3 - "$ROOT" <<'EOF'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
changed = 0
for f in sorted((root / "godot/content/theme").glob("*.png.import")):
    text = f.read_text()
    fixed = re.sub(r"^mipmaps/generate=false$", "mipmaps/generate=true",
                   text, flags=re.M)
    if fixed != text:
        f.write_text(fixed)
        changed += 1
print("import: mipmaps turned on in %d sidecar(s)" % changed)
EOF

set +e
xvfb-run -a timeout --kill-after=15s "${GODOT_IMPORT_TIMEOUT:-600}"   "$GODOT" --headless --path "$ROOT/godot" --import >/dev/null 2>&1
status=$?
set -e
[ "$status" -eq 0 ] || { echo "import: the reimport exited $status" >&2; exit 1; }

count=$(find "$ROOT/godot/content/theme" -name "*.import" | wc -l)
echo "import: $count sidecar(s) under godot/content/theme/"
