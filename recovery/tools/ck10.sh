#!/bin/bash
# CK10: the full frontier on the pushed head, after the HB-F4g diagnosis.
S=/tmp/claude-0/-home-user-archipepsi/4fcd533d-0ce3-52dc-bbf4-13b00ca2dbdd/scratchpad
T=/home/user/archipepsi; P=$S/ck10/progress.txt; : > $P
until grep -q "^DONE" $S/hbf4g/diag/progress.txt 2>/dev/null; do sleep 10; done
echo "starting CK10 at $(git -C $T rev-parse --short HEAD), tree changes $(git -C $T status --short | wc -l), $(date -u +%H:%M)" >> $P
$S/frontier.sh $T $S/ck10/run
echo "frontier finished $(date -u +%H:%M): $(awk -F'\t' 'NF>=4 && $1 ~ /^[0-9]+$/' $S/ck10/run/summary.tsv | wc -l) steps, $(awk -F'\t' 'NF>=4 && $1 ~ /^[0-9]+$/ && $3!="0"' $S/ck10/run/summary.tsv | wc -l) red" >> $P
echo DONE >> $P
