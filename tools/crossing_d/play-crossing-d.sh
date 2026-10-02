#!/bin/sh
# Crossing D review build (Linux). `./play-crossing-d.sh` is the full
# Crossing; `./play-crossing-d.sh empty` is the same rooms, Yard empty.
cd "$(dirname "$0")" || exit 1
if [ "$1" = "empty" ]; then
	exec ./Archipepsi-Crossing-D.x86_64 -- --empty-yard
fi
exec ./Archipepsi-Crossing-D.x86_64
