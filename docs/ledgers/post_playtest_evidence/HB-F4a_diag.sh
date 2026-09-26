#!/bin/bash
# HB-F4a: lay out one saved composition with --router-diag on a tree and
# keep what the router says about its last attempt.
#   diag.sh TREE ZONE.json OUT.log
S=/tmp/claude-0/-home-user-archipepsi/4fcd533d-0ce3-52dc-bbf4-13b00ca2dbdd/scratchpad
tree="$1"; zone="$2"; out="$3"
cp "$S/hb/layout_walk_tool.gd" "$tree/godot/layout_walk_tmp.gd"
cp "$S/hb/layout_walk_tmp.tscn" "$tree/godot/layout_walk_tmp.tscn"
"$tree/godot-bin/godot" --headless --path "$tree/godot" res://layout_walk_tmp.tscn \
  -- "$zone" "$S/hbf4a/layout_out.json" --router-diag > "$out" 2>&1
echo "godot exit $?" >> "$out"
rm -f "${tree:?}/godot/layout_walk_tmp.gd" "${tree:?}/godot/layout_walk_tmp.gd.uid" "${tree:?}/godot/layout_walk_tmp.tscn"
python3 -c "import json;d=json.load(open('$S/hbf4a/layout_out.json'));print('RESULT:', d.get('failed') or 'LAYOUT built')" >> "$out" 2>&1
