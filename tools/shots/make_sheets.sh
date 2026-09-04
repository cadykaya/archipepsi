#!/usr/bin/env bash
# Phone-readable contact sheets for the room-library review packages.
#
#     bash tools/shots/make_sheets.sh
#
# WHY THIS FILE EXISTS. The Wave 1 sheets were made by hand with three
# `contact_sheet.py` invocations that were never written down anywhere,
# so when the Wave 1 views were re-rendered at `67add07` nothing knew how
# to rebuild the sheets from them -- exactly the shape of L-94, a derived
# artefact whose producer lives only in somebody's shell history. The
# commands live here now.
#
# Run it AFTER `tools/shoot.sh` has refreshed the views it stacks.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

W1=docs/art/review/wave1
mkdir -p "$W1/phone"

python3 tools/contact_sheet.py "$W1/phone/plenum_helix.png" \
  "SHELL_PLENUM_HELIX -- 20 x 72 x 20 m, A SHAFT" \
  "$W1"/A1_plenum_helix.png "$W1"/A2_plenum_helix.png \
  "$W1"/A3_plenum_helix.png "$W1"/A4_plenum_helix.png

python3 tools/contact_sheet.py "$W1/phone/yard_gantry.png" \
  "SHELL_YARD_GANTRY -- 84 x 16 x 52 m, A FIELD" \
  "$W1"/B1_yard_gantry.png "$W1"/B2_yard_gantry.png \
  "$W1"/B3_yard_gantry.png "$W1"/B4_yard_gantry.png

python3 tools/contact_sheet.py "$W1/phone/span_basin.png" \
  "SHELL_SPAN_BASIN -- 30 x 22 x 90 m, A SPAN" \
  "$W1"/C1_span_basin.png "$W1"/C2_span_basin.png \
  "$W1"/C3_span_basin.png "$W1"/C4_span_basin.png

# The hall's flight repair. Four views of the three staircases that
# `67add07` rebuilt, in one scroll.
H=docs/art/review/hall_67add07
mkdir -p "$H/phone"
python3 tools/contact_sheet.py "$H/phone/flights.png" \
  "SHELL_HALL_TRANSIT -- THE THREE FLIGHTS, AS BUILT" \
  "$H"/S1_ramp1_basin_to_gallery.png "$H"/S2_ramp2_gallery_to_landing.png \
  "$H"/S3_ramp3_gantry_to_exit.png "$H"/S4_ramp1_from_the_gallery.png

echo "[sheets] 4 contact sheet(s) rebuilt"
