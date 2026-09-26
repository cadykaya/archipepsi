"""Apply one measured variant of HB-F4a-3 to zone_builder.gd, or restore.
    variant.py connsize|atstart|restore TREE
connsize: the next room owed at a connector's size where the corridor ends.
atstart:  the next room owed at its own size where the corridor starts."""
import sys
from pathlib import Path
kind, tree = sys.argv[1], Path(sys.argv[2])
zb = tree / "godot/scripts/generation/zone_builder.gd"
keep = Path(__file__).with_name("zone_builder.repaired.gd")
if kind == "restore":
    zb.write_bytes(keep.read_bytes()); print("restored"); sys.exit(0)
s = zb.read_text()
if kind == "connsize":
    old = '\tvar bounds: AABB = next.get("bounds", AABB())\n'
    new = '\tvar bounds: AABB = shape["bounds"] as AABB\n'
else:
    old = ('\tfor _k in RESERVED_CONNECTORS:\n'
           '\t\tat += _rot(turn, shape["exit_offset"] as Vector3)\n'
           '\tvar room_yaw := yaw + turn\n')
    new = '\tvar room_yaw := yaw + turn\n'
assert s.count(old) == 1, "anchor"
zb.write_text(s.replace(old, new)); print("applied", kind)
