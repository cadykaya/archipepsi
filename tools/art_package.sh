#!/usr/bin/env bash
# Build an art-lane delivery archive, and refuse to ship one that is
# missing its pictures.
#
#   tools/art_package.sh <slug> <review dir> <report.md> <README.md|-> \
#       [<extra dir>:<name in archive>]...
#
# Pass `-` for the README when there is not one. An empty argument used
# to be the way, and an empty string is still a positional argument --
# it fell through to the extra-directory loop and failed with "no
# directory at".
#
# ## Why this is a script and not care
#
# CLAUDE.md: *"the Markdown and the images go out together as a single
# .zip"*. The first Track D archive went out without the tile
# comparison its own report argues from -- not because the rule was
# unclear but because the archive was assembled by hand, and a hand
# forgets one file out of nine without noticing.
#
# So the archive is assembled from the WHOLE review directory, and then
# every image in that directory is checked against the zip's own
# listing. A missing picture fails the build instead of arriving as a
# report that refers to something nobody can see.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SLUG="${1:?usage: art_package.sh <slug> <review dir> <report.md> [readme] [dir:name]...}"
REVIEW="${2:?need a review directory}"
REPORT="${3:?need a report}"
README="${4:?need a README path or - for none}"
shift 4
[ "$README" = "-" ] && README=""
OUT="${ART_PACKAGE_OUT:-${TMPDIR:-/tmp}}/artpkg"
STAGE="$OUT/$SLUG"

REVIEW="${REVIEW%/}"
[ -d "$REVIEW" ] || { echo "no review dir at $REVIEW" >&2; exit 2; }
[ -f "$REPORT" ] || { echo "no report at $REPORT" >&2; exit 2; }

rm -rf "$STAGE" "$OUT/$SLUG.zip"
mkdir -p "$STAGE/review"
cp "$REPORT" "$STAGE/REPORT.md"
[ -n "$README" ] && cp "$README" "$STAGE/README.md"
cp -r "$REVIEW"/. "$STAGE/review/"

for pair in "$@"; do
  src="${pair%%:*}"
  name="${pair##*:}"
  [ -d "$src" ] || { echo "no directory at $src" >&2; exit 2; }
  mkdir -p "$STAGE/$name"
  cp "$src"/* "$STAGE/$name/" 2>/dev/null || true
done

( cd "$OUT" && zip -qr "$SLUG.zip" "$SLUG" )

# --- the check: every picture in the review dir is in the archive -----
listing="$(unzip -Z1 "$OUT/$SLUG.zip")"
# Via a temp file rather than a pipe into `while`: a pipe runs the loop
# in a SUBSHELL, so `missing` would be incremented in a process that
# then exits, and the count would always come back 0. A checker whose
# counter cannot rise is the exact failure this script exists to stop.
found="$(mktemp)"
# Moving captures count as pictures too: a review that argues from an
# MP4 or an animated WebP is as blind without it as without a PNG.
find "$REVIEW" -type f \( -name '*.png' -o -name '*.jpg' \
     -o -name '*.svg' -o -name '*.gif' -o -name '*.webp' \
     -o -name '*.mp4' \) > "$found"
missing=0
# By the path inside the review, not the basename: when several folders
# each hold a `motion.mp4` or a `stills/01_rest.png`, a basename match
# would let one folder's file stand in for another's missing one.
while IFS= read -r img; do
  rel="${img#"$REVIEW"/}"
  printf '%s\n' "$listing" | grep -qxF -- "$SLUG/review/$rel" || {
    echo "art-package: MISSING from the archive: $rel" >&2
    missing=$((missing + 1))
  }
done < "$found"
rm -f "$found"
if [ "$missing" -ne 0 ]; then
  echo "art-package: $missing image(s) in $REVIEW did not reach the
  archive. The report would have referred to pictures nobody can see." >&2
  exit 1
fi

count=$(printf '%s\n' "$listing" | grep -cE '\.(png|jpg|svg|gif|webp|mp4)$' || true)
echo "art-package: $OUT/$SLUG.zip -- $count image(s), all of $REVIEW's present"
