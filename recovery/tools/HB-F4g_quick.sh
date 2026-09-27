#!/bin/bash
# HB-F4g: lay out the five compositions that decide the rule on TREE, one
# line each: the three HB-F4g Zones and both zone_008 compositions.
#   quick.sh TREE OUT.log
S=/tmp/claude-0/-home-user-archipepsi/4fcd533d-0ce3-52dc-bbf4-13b00ca2dbdd/scratchpad
tree="$1"; out="$2"; E=/home/user/archipepsi/docs/ledgers/post_playtest_evidence
F=/home/user/archipepsi/godot/tests/fixtures/router
cp "$S/hb/layout_walk_tool.gd" "$tree/godot/layout_walk_tmp.gd"
cp "$S/hb/layout_walk_tmp.tscn" "$tree/godot/layout_walk_tmp.tscn"
printf '# quick layouts on %s at %s (+ %s changed file(s) under godot/scripts), %s UTC\n' "$tree" \
  "$(git -C "$tree" rev-parse --short HEAD)" "$(git -C "$tree" status --short -- godot/scripts | wc -l)" "$(date -u +%H:%M)" > "$out"
for z in $E/HB-F4g_zone_013_74495995ef07.json $E/HB-F4g_zone_019_e0b4b081a704.json $E/HB-F4g_zone_022_5d3385459fd6.json $F/candidate_zone_008.json $F/candidate_zone_008b.json; do
  rm -f $S/hbf4g/quick_out.json
  "$tree/godot-bin/godot" --headless --path "$tree/godot" res://layout_walk_tmp.tscn -- "$z" "$S/hbf4g/quick_out.json" > /dev/null 2>&1
  printf '%s: %s\n' "$(basename $z)" "$(python3 -c "import json;d=json.load(open('$S/hbf4g/quick_out.json'));print('FAILED ('+str(d.get('ms'))+' ms): '+d['failed'] if 'failed' in d else 'LAYOUT built ('+str(d.get('ms'))+' ms)')" 2>&1)" >> "$out"
done
rm -f "${tree:?}/godot/layout_walk_tmp.gd" "${tree:?}/godot/layout_walk_tmp.gd.uid" "${tree:?}/godot/layout_walk_tmp.tscn"
