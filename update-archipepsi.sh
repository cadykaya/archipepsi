#!/usr/bin/env bash
# Get the latest Archipepsi. The mac/linux twin of
# "Update Archipepsi (Windows).bat".
#
# This replaces downloading a zip and erasing the old folder. It fetches
# only what changed and leaves your saves in bridge/saves, your settings
# and Godot's import cache alone -- erasing the folder deletes all three.
set -uo pipefail
cd "$(dirname "$0")"

echo
echo "  Archipepsi - getting the latest version"
echo "  --------------------------------------"
echo

if ! command -v git >/dev/null 2>&1; then
	echo "  Git is not installed, so this script cannot update anything."
	echo "  On macOS, running 'git' once offers to install it for you."
	echo
	exit 1
fi

# A folder unpacked from a zip is not a repository -- there is no history
# to update against, so a pull cannot work.
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	echo "  This folder came from a zip, not from Git, so there is"
	echo "  nothing to update against. To switch over, clone it once:"
	echo
	echo "    git clone https://github.com/cadykaya/archipepsi.git"
	echo
	exit 1
fi

branch="$(git rev-parse --abbrev-ref HEAD)"
echo "  Branch: $branch"
echo

# Warn before pulling rather than after: a pull onto edited files stops
# halfway with a message about merging, which is hard to undo if you do
# not already know Git.
#
# But check for REAL edits first. Godot rewrites godot/project.godot every
# time it opens the project -- a version stamp, a feature list -- so
# treating that as "you edited files" would block every update you ever
# run, for a file you never touched.
if ! git diff --quiet -- . ':(exclude)godot/project.godot'; then
	echo "  Some files here differ from the version on GitHub, so nothing"
	echo "  has been done. If you did not edit these on purpose, tell"
	echo "  Claude what this says."
	echo
	git diff --stat -- . ':(exclude)godot/project.godot'
	echo
	exit 1
fi

# Only Godot's own churn is left, if anything. Reset it rather than
# stopping: the repository's copy is the real project definition, and your
# settings and key bindings are not kept in this file -- they live in
# Godot's user folder and are untouched by any of this.
if ! git diff --quiet -- godot/project.godot; then
	echo "  Godot rewrote godot/project.godot when it opened the project."
	echo "  That is normal and not something you did; resetting it."
	echo
	git checkout -- godot/project.godot
fi

if ! git pull --ff-only origin "$branch"; then
	echo
	echo "  The update did not go through. The usual cause is that the"
	echo "  branch history was rewritten, which a fast-forward refuses on"
	echo "  purpose rather than throwing your copy away."
	echo
	exit 1
fi

echo
echo "  Up to date. Your saves and settings were left alone."
echo
echo "  Now run ./start-archipepsi.sh, then open the project in Godot."
echo
