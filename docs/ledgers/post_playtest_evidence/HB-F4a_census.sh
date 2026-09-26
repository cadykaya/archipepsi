#!/bin/bash
# HB-F4a census: every composition in census/ laid out on TREE and judged
# by TREE's own bridge (`layout.validate`). One line per composition.
#   census.sh TREE OUT.log
S=/tmp/claude-0/-home-user-archipepsi/4fcd533d-0ce3-52dc-bbf4-13b00ca2dbdd/scratchpad
tree="$1"; out="$2"
cp "$S/hb/layout_walk_tool.gd" "$tree/godot/layout_walk_tmp.gd"
cp "$S/hb/layout_walk_tmp.tscn" "$tree/godot/layout_walk_tmp.tscn"
cp "$S/hbf4/remeasure.py" "$tree/bridge/remeasure_tmp.py"
printf '# census on %s at %s (+ working tree changes: %s), %s UTC\n' "$tree" \
  "$(git -C "$tree" rev-parse --short HEAD)" \
  "$(git -C "$tree" status --short -- godot/scripts | wc -l) file(s)" "$(date -u +%H:%M)" > "$out"
start=$(date +%s)
(cd "$tree/bridge" && python3 remeasure_tmp.py "$S"/hbf4a/census/*.json) >> "$out" 2>&1
echo "# $(( $(date +%s) - start )) s" >> "$out"
rm -f "${tree:?}/godot/layout_walk_tmp.gd" "${tree:?}/godot/layout_walk_tmp.gd.uid" "${tree:?}/godot/layout_walk_tmp.tscn" "${tree:?}/bridge/remeasure_tmp.py"
