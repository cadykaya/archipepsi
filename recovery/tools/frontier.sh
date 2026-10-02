#!/bin/bash
# The full frontier: CK8's 92 steps (frontier_steps.txt, rebuilt from
# CK8_frontier_on_adfb76c.tsv), in order, one at a time, on one revision
# of one tree. One raw log per step; one TSV row per step:
#   step, command, exit code, seconds, summary (the last line naming a
#   pass -- OK, passed, prose matches -- or, for a failed step, the last
#   naming a failure; 60 characters).
#   frontier.sh TREE OUT_DIR
S=/tmp/claude-0/-home-user-archipepsi/4fcd533d-0ce3-52dc-bbf4-13b00ca2dbdd/scratchpad
T=$1; O=$2; STEPS=$S/frontier_steps.txt
mkdir -p $O/logs; rm -f $O/logs/*.log; F=$O/summary.tsv
cd $T || exit 1
{ echo "rev $(git rev-parse HEAD)"; echo "start $(date -u +%H:%M:%S)"
  echo "tree_at_start $(git status --short | wc -l)"; echo "first_step 1"; } > $F
i=0
while IFS= read -r cmd; do
  i=$((i+1))
  slug=$(printf '%s' "$cmd" | cut -c1-40 | tr -c 'A-Za-z0-9\n' '_' | sed 's/_*$//')
  L=$O/logs/$(printf '%02d' $i)_$slug.log
  t0=$(date +%s)
  timeout 2400 bash -c "$cmd" > $L 2>&1 < /dev/null
  rc=$?
  t1=$(date +%s)
  if [ $rc -eq 0 ]; then
    sum=$(grep -E "OK|passed|prose matches" $L | tail -1)
  else
    sum=$(grep -E "FAIL|[Ee]rror|failed" $L | tail -1)
  fi
  sum=$(printf '%s' "$sum" | sed -E 's/^[= ]+//' | cut -c1-60)
  printf '%s\t%s\t%s\t%s\t%s\n' $i "$cmd" $rc $((t1-t0)) "$sum" >> $F
done < $STEPS
{ echo "end $(date -u +%H:%M:%S)"; echo "tree_at_end $(git status --short | tr '\n' ' ')"; echo DONE; } >> $F
