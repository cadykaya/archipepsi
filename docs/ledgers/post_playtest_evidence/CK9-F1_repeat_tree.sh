#!/bin/bash
# Repeat `make godot-flyer-room` N times in TREE; one log per run, a summary line each.
TREE=$1; N=$2; TAG=$3
S=/tmp/claude-0/-home-user-archipepsi/4fcd533d-0ce3-52dc-bbf4-13b00ca2dbdd/scratchpad
OUT=$S/ck9_flyer/$TAG
mkdir -p $OUT; rm -f $OUT/*
cd "$TREE" || exit 1
echo "tree $TREE rev $(git rev-parse --short=12 HEAD) changes $(git status --short | grep -v '^?? \(godot-bin\|.archipelago\)$' | wc -l)" > $OUT/summary.txt
for i in $(seq 1 $N); do
  start=$(date +%s)
  timeout 600 make godot-flyer-room > $OUT/run_$i.log 2>&1
  rc=$?
  end=$(date +%s)
  line=$(grep -E "\[c011 / (jumping\] telegraphs|cleared)" $OUT/run_$i.log | tr '\n' ' ')
  echo "run $i exit $rc secs $((end-start)) $line" >> $OUT/summary.txt
done
echo "repeat done" >> $OUT/summary.txt
