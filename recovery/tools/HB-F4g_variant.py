"""HB-F4g: set how far ahead the way on is owed in TREE's zone_builder.gd,
starting from the candidate (OWED_WAY_ON_ROOMS := 2), or restore it.
    variant.py N|junction|restore TREE
N:        owe the next N spine rooms (1 is HB-F4a-3's reach).
junction: owe every spine room up to and including the next one that
          has branches of its own (the end of the spine if none does)."""
import sys
from pathlib import Path
kind, tree = sys.argv[1], Path(sys.argv[2])
zb = tree / "godot/scripts/generation/zone_builder.gd"
keep = Path(__file__).with_name("zone_builder.candidate.gd")
s = keep.read_text()
if kind == "restore":
    zb.write_text(s); print("restored the candidate"); sys.exit(0)
old = "const OWED_WAY_ON_ROOMS := 2\n"
assert s.count(old) == 1, "const anchor"
if kind == "junction":
    s = s.replace(old, "const OWED_WAY_ON_ROOMS := 1000\n")
    old2 = ('''		from_origin = room_origin
		from_yaw = room_yaw
	return out
''')
    new2 = ('''		from_origin = room_origin
		from_yaw = room_yaw
		if _has_branches_tmp(chamber):
			break
	return out
''')
    assert s.count(old2) == 1, "loop anchor"
    s = s.replace(old2, new2)
    s += '''

static func _has_branches_tmp(chamber: Dictionary) -> bool:
	for raw: Variant in chamber.get("doors", []):
		if typeof(raw) == TYPE_DICTIONARY and str((raw as Dictionary).get(
				"socket_id", "")).begins_with("side_") \\
				and str((raw as Dictionary).get("usage", "")) != "SEALED":
			return true
	return false
'''
else:
    s = s.replace(old, "const OWED_WAY_ON_ROOMS := %d\n" % int(kind))
zb.write_text(s); print("applied", kind)
