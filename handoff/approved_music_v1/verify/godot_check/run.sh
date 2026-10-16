#!/usr/bin/env bash
# Headless check of this handoff in a throwaway Godot 4.5.1 project (not Archipepsi).
# usage: GODOT=/path/to/Godot_v4.5.1 ./run.sh [work-dir]
# It proves import + state sequencing only. It is not a listening test.
# The "leaked at exit" lines at the end are the test quitting mid-playback, not a fault.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; h="$here/../.."
work="${1:-$(mktemp -d)}"; mkdir -p "$work/music"
cp "$here"/{project.godot,main.tscn,main.gd,default_bus_layout.tres} "$work/"
cp -r "$h/station/sigmaudio_pack" "$work/music/station"
cp -r "$h/freight_bay/sigmaudio_pack" "$work/music/freight_bay"
mkdir -p "$work/music/freight_bay_stingers" "$work/music/shunter_horn"
cp "$h"/freight_bay/stingers/*.wav "$h"/freight_bay/stingers/*.wav.import "$work/music/freight_bay_stingers/"
cp "$h"/freight_bay/shunter_horn_reference/shunter-horn-tuned.wav* "$work/music/shunter_horn/"
"$GODOT" --headless --path "$work" --import >/dev/null 2>&1 || true
"$GODOT" --headless --audio-driver Dummy --path "$work"
