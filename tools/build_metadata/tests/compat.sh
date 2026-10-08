#!/bin/sh
# Compatibility proof: runs Prod's OWN, unmodified package.sh scripts from
# the three review branches (Godot's export replaced by fake_godot.sh, so
# the game inside is random bytes but every other file is what the script
# really writes), validates their legacy output, stamps it with the
# matching example spec, and validates it again with --strict.
#
#   tools/build_metadata/tests/compat.sh [work folder]
#
# Needs git, zip and python3. Leaves the repository's checkout untouched:
# each branch is a temporary detached worktree.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
TOOL="$HERE/../archipepsi_build.py"
EX="$HERE/../examples"
REPO=$(cd "$HERE/../../.." && pwd)
WORK=${1:-$(mktemp -d)}
mkdir -p "$WORK"
STATUS=0
run() { # <branch> <script> <spec>
	BR=$1; WT="$WORK/wt-$(echo "$BR" | tr / -)"; OUT="$WORK/out-$(echo "$BR" | tr / -)"
	git -C "$REPO" worktree remove --force "$WT" 2>/dev/null || true
	git -C "$REPO" worktree add --detach "$WT" "origin/$BR" >/dev/null 2>&1
	echo "== $BR: $2 (unmodified)"
	sh "$WT/$2" "$OUT" "$HERE/fake_godot.sh" >/dev/null
	echo "-- legacy output, as delivered today:"
	python3 "$TOOL" validate -q "$OUT"/*.zip || STATUS=1
	python3 "$TOOL" stamp --spec "$EX/$3" --repo "$WT" --branch "$BR" "$OUT"
	echo "-- after stamping, --strict:"
	python3 "$TOOL" validate --strict "$OUT"/*.zip || STATUS=1
	git -C "$REPO" worktree remove --force "$WT"
}
run wip/crossing-d-review tools/crossing_d/package.sh crossing-d-review.json
run review/crossing-d-readability tools/crossing_d/package.sh crossing-d-readability.json
run review/impact-lab-g0 tools/impact_lab/package.sh impact-lab.json
exit $STATUS
