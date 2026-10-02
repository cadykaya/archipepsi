#!/bin/bash
# HB-F4g: measure how far ahead the way on should be owed, on wt-hbf4g,
# one run at a time, after CK10. Variants: 1 (HB-F4a-3's reach, the
# reproduction), 2 (the candidate), 3, junction.
S=/tmp/claude-0/-home-user-archipepsi/4fcd533d-0ce3-52dc-bbf4-13b00ca2dbdd/scratchpad
W=$S/wt-hbf4g; O=$S/hbf4g/var; P=$O/progress.txt; E=/home/user/archipepsi/docs/ledgers/post_playtest_evidence
mkdir -p $O; : > $P
until grep -q "^DONE" $S/ck10/progress.txt 2>/dev/null; do sleep 10; done
echo "CK10 finished; measuring at $(date -u +%H:%M)" >> $P
(cd $W && timeout 600 make godot-import > /dev/null 2>&1); echo "import: exit $?" >> $P
for v in 1 2 3 junction; do
  python3 $S/hbf4g/variant.py $v $W >> $P
  $S/hbf4g/quick.sh $W $O/quick_$v.log
  echo "quick $v: $(grep -c 'LAYOUT built' $O/quick_$v.log) of 5 built" >> $P
done
walk () {  # log
  cp $E/HB-F4_layout_walk.py $W/bridge/layout_walk_tmp.py
  cp $E/HB-F4_layout_walk_tool.gd $W/godot/layout_walk_tmp.gd
  cp $E/HB-F4_layout_walk_tool.tscn $W/godot/layout_walk_tmp.tscn
  mkdir -p $1.dump; rm -f $1.dump/*.json
  (cd $W/bridge && HBF4_DUMP=$1.dump timeout 3600 python3 layout_walk_tmp.py 30 > $1 2>&1)
  rm -f $W/bridge/layout_walk_tmp.py $W/godot/layout_walk_tmp.gd $W/godot/layout_walk_tmp.tscn $W/godot/layout_walk_tmp.gd.uid
}
for v in 2 3 junction; do
  python3 $S/hbf4g/variant.py $v $W >> $P
  $S/hbf4a/census.sh $W $O/census_$v.log
  echo "census $v: $(grep -c ACCEPTED $O/census_$v.log) of 39 accepted; $(tail -1 $O/census_$v.log)" >> $P
  walk $O/walk30_$v.log
  echo "walk30 $v: $(grep -c ': ACCEPTED' $O/walk30_$v.log) accepted, $(grep -c 'ZONE_FAILED' $O/walk30_$v.log) failed" >> $P
done
python3 $S/hbf4g/variant.py restore $W >> $P
cmp $W/godot/scripts/generation/zone_builder.gd $S/hbf4g/zone_builder.candidate.gd && echo "zone_builder.gd is the candidate again" >> $P
echo DONE >> $P
