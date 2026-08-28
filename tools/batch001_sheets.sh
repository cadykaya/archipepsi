#!/usr/bin/env sh
# Render every Style Lock Batch 001 review sheet.
#
#   tools/batch001_sheets.sh
#
# The judging distance for each family is not a free choice -- it is the
# distance the player genuinely reads that object from, and picking a
# flattering one is the single easiest way to make a review sheet lie:
#
#   enemy      18 m  ENEMY_AGGRO_RADIUS: where you first see one
#   Check      30 m  the longest corridor zone.py permits
#   portal     30 m  same; a portal is read from the far end of a corridor
#   Epsilon     6 m  a Hub conversation distance
#   anchor      5 m  it hangs at 5.1 m and you look up at it from the floor
#   module      4 m  one module width; you walk past a wall at this range
#   prop        3 m  you walk up to it
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/docs/art/review/batch001"
SHEET="$ROOT/tools/review_sheet.sh"
mkdir -p "$OUT"

sheet() { # <glb-relative> <out-name> <label> <dist>
  printf '  %-34s ' "$2"
  "$SHEET" "$1" "$OUT/$2.png" "$3" "$4" 2>&1 \
    | sed -n 's/^\[sheet\]   measured/    measured/p' || true
}

echo "A -- Epsilon presence (3 concepts, judged at 6 m)"
for n in a_lectern b_core c_aperture; do
  sheet "assets/models/batch001/epsilon/epsilon_$n.glb" "A_epsilon_$n" "epsilon $n" 6
done

echo "B -- Check object (3 concepts, judged at 30 m)"
for n in a_pedestal b_vault c_mast; do
  sheet "assets/models/batch001/check/check_$n.glb" "B_check_$n" "check $n" 30
done

echo "C -- Portal frame (2 concepts, judged at 30 m)"
for n in a_blast b_collar; do
  sheet "assets/models/batch001/portal/portal_$n.glb" "C_portal_$n" "portal $n" 30
done

echo "D -- Melee enemy (3 concepts, judged at 18 m = aggro range)"
for n in a_stooped b_tripod c_squat; do
  sheet "assets/models/batch001/enemy/enemy_melee_$n.glb" "D_enemy_melee_$n" \
    "melee $n" 18
done

echo "E -- Grapple anchor (2 concepts, judged at 5 m)"
for n in a_soffit b_jib; do
  sheet "assets/models/batch001/affordance/anchor_$n.glb" "E_anchor_$n" \
    "anchor $n" 5
done

echo "F -- Architecture mini-kit (judged at 4 m)"
for n in wall_panel floor_slab ceiling_beam doorway trim_rail railing \
         pipe_run light_fixture; do
  sheet "assets/models/batch001/architecture/arch_$n.glb" "F_arch_$n" \
    "arch $n" 4
done

echo "G -- Universal prop mini-kit (judged at 3 m)"
for n in crate utility_box terminal pipe_cluster machinery_unit debris \
         warning_sign; do
  sheet "assets/models/batch001/props/prop_$n.glb" "G_prop_$n" "prop $n" 3
done

echo
echo "H -- material probes: rebuild with tools/blender/build_materials.py"
echo "I -- composed room: tools/composed_room.sh"
echo
echo "sheets in docs/art/review/batch001/"
