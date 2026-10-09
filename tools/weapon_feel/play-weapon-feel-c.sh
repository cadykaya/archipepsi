#!/bin/sh
# Weapon Feel (Linux), starting in treatment C, Echo resonance. Keys 1-4 switch in play.
cd "$(dirname "$0")" || exit 1
exec ./Archipepsi-Weapon-Feel.x86_64 -- --feel=c
