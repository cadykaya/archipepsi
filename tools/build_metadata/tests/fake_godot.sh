#!/bin/sh
# Stand-in for Godot's exporter, for make_fixtures.sh: writes random bytes
# where the real export would write the game (and its .console.exe twin).
while [ $# -gt 0 ]; do
	case "$1" in
		--export-release) OUT="$3"; shift 3 ;;
		*) shift ;;
	esac
done
[ -z "$OUT" ] && exit 0
head -c 30000 /dev/urandom > "$OUT"
case "$OUT" in *.exe) head -c 2000 /dev/urandom > "${OUT%.exe}.console.exe" ;; esac
