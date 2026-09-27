#!/bin/bash
# CK9-F1 phase sweep: run godot-flyer-room with the flyers' circle shifted
# by 0..15 s (one period is 2*pi/0.4 = 15.7 s), with the diagnostic print
# of the clear:
#   1. every offset on the pre-fix revision (22fdbda's code, wt-hbf4a3);
#   2. the offsets that failed there, and offset 0, on CK8's revision
#      (3b96bc4, wt-ck8);
#   3. every offset on the repair (2643982, wt-rebuild).
# Both patches are diagnostic, never committed, and removed after.
S=/tmp/claude-0/-home-user-archipepsi/4fcd533d-0ce3-52dc-bbf4-13b00ca2dbdd/scratchpad
O=$S/ck9f1/sweep; P=$O/progress.txt; mkdir -p $O; rm -f $O/*.log; : > $P
until grep -q "^DONE" $S/ck10/progress.txt 2>/dev/null; do sleep 10; done
echo "CK10 finished; starting" >> $P
ALL="0 1000 2000 3000 4000 5000 6000 7000 8000 9000 10000 11000 12000 13000 14000 15000"
sweep () {  # tree, offsets
  local T=$1 W=$S/$1; shift
  python3 $S/ck9f1/drift_offset_patch.py $W >> $P
  python3 $S/ck9_flyer/diag_patch.py $W >> $P
  for off in "$@"; do
    L=$O/${T}_off$off.log
    (cd $W && CK9_DRIFT_OFFSET_MS=$off timeout 600 make godot-flyer-room > $L 2>&1); rc=$?
    echo "$T rev $(git -C $W rev-parse --short HEAD) offset $off ms: exit $rc | $(grep -o 'killed [0-9] of 5 in [0-9.]* s' $L) | f120 in $(grep -o "^DIAG f120 player [^)]*) room '[^']*'" $L | grep -o "room '[^']*'") | pad_entered $(grep -c '_on_pad_entered' $L)" >> $P
  done
  git -C $W checkout -- godot/scripts/enemies/enemy.gd godot/tests/transport_driver.gd
  echo "$T restored: $(git -C $W status --short -- godot | wc -l) changes" >> $P
}
sweep wt-hbf4a3 $ALL
FAILED=$(grep "^wt-hbf4a3 .*: exit [1-9]" $P | sed -E 's/.*offset ([0-9]+) ms.*/\1/' | tr '\n' ' ')
echo "failed on the pre-fix revision at: ${FAILED:-none}" >> $P
sweep wt-ck8 0 $FAILED
sweep wt-rebuild $ALL
echo DONE >> $P
