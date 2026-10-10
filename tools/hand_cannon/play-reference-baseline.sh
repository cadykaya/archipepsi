#!/bin/sh
# Hand-Cannon candidate (Linux), starting in the baseline (reference). Keys 1-5 switch in play.
cd "$(dirname "$0")" || exit 1
exec ./Archipepsi-Hand-Cannon.x86_64 -- --feel=baseline
