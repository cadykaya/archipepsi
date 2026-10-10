#!/bin/sh
# Five Weapons (Linux), starting with Bulkhead Sweeper. Keys 1-5 switch weapons.
cd "$(dirname "$0")" || exit 1
exec ./Archipepsi-Five-Weapons.x86_64 -- --weapon=bulkhead --variant=sweeper
