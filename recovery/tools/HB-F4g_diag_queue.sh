#!/bin/bash
# HB-F4g: the router's own account of the three failing Zones, on the
# pushed head, after bombs-live and before CK10. Seconds of Godot each.
S=/tmp/claude-0/-home-user-archipepsi/4fcd533d-0ce3-52dc-bbf4-13b00ca2dbdd/scratchpad
T=/home/user/archipepsi; E=$T/docs/ledgers/post_playtest_evidence; P=$S/hbf4g/diag/progress.txt; : > $P
until grep -q "^DONE" $S/hbo1/live/progress.txt 2>/dev/null; do sleep 10; done
echo "bombs-live finished; diag at $(git -C $T rev-parse --short HEAD)" >> $P
for z in zone_013_74495995ef07 zone_019_e0b4b081a704 zone_022_5d3385459fd6; do
  $S/hbf4g/diag.sh $T $E/HB-F4g_$z.json $S/hbf4g/diag/HB-F4g_diag_$z.log
  echo "$z: $(tail -1 $S/hbf4g/diag/HB-F4g_diag_$z.log)" >> $P
done
echo "tree after: $(git -C $T status --short | wc -l) changes" >> $P
echo DONE >> $P
