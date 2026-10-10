#!/bin/sh
# Five Weapons (Linux), starting with Mass Driver. Keys 1-5 switch weapons.
cd "$(dirname "$0")" || exit 1
exec ./Archipepsi-Five-Weapons.x86_64 -- --weapon=driver
