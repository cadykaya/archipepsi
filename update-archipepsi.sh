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
if ! git diff --quiet; then
	echo "  You have edited files in this folder. Updating could conflict"
	echo "  with your changes, so nothing has been done."
	echo
	echo "  Edited:"
	git diff --name-only
	echo
	exit 1
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
